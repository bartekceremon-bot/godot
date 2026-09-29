/**
 * Plecak i ekwipunek gracza. Cała logika po stronie serwera – klient tylko prosi.
 * Stos przedmiotów ma jakość `q` (1–5); łączą się tylko stosy o tej samej jakości.
 */
import { EquipSlot, EQUIP_SLOTS, getItem, LEGACY_ITEMS, QUALITY_MULT, ToolKind } from './data/items';

export interface ItemStack {
  item: string;
  count: number;
  /** Jakość 1–5 (brak = 1). */
  q?: number;
}

export const BAG_SIZE = 20;
export const MAX_STACK = 100;

export type Equipment = Partial<Record<EquipSlot, ItemStack>>;

export class Inventory {
  /** Sloty plecaka; null = pusty slot. */
  bag: (ItemStack | null)[];
  equipment: Equipment;
  /** Ustawiane przy każdej zmianie – serwer wysyła wtedy stan do klienta. */
  dirty = true;

  constructor(bag?: (ItemStack | null)[], equipment?: Equipment) {
    this.bag = new Array(BAG_SIZE).fill(null);
    if (bag) for (let i = 0; i < Math.min(bag.length, BAG_SIZE); i++) this.bag[i] = sanitizeStack(bag[i]);
    this.equipment = {};
    if (equipment)
      for (const slot of EQUIP_SLOTS) {
        const s = sanitizeStack(equipment[slot] ?? null);
        if (s && getItem(s.item)?.slot === slot) this.equipment[slot] = s;
      }
  }

  /** Ile sztuk przedmiotu zmieści się w plecaku (ignorując udźwig). */
  spaceFor(itemId: string, q = 1): number {
    const def = getItem(itemId);
    if (!def) return 0;
    let n = 0;
    for (const s of this.bag) {
      if (s === null) n += def.stackable ? MAX_STACK : 1;
      else if (def.stackable && s.item === itemId && (s.q ?? 1) === q) n += MAX_STACK - s.count;
    }
    return n;
  }

  /**
   * Dodaje przedmiot do plecaka (łączy stosy). Zwraca liczbę sztuk, które się NIE zmieściły.
   */
  add(itemId: string, count = 1, q = 1): number {
    const def = getItem(itemId);
    if (!def || count <= 0) return count;
    let left = count;
    if (def.stackable) {
      for (const s of this.bag) {
        if (left <= 0) break;
        if (s && s.item === itemId && (s.q ?? 1) === q && s.count < MAX_STACK) {
          const n = Math.min(left, MAX_STACK - s.count);
          s.count += n;
          left -= n;
        }
      }
    }
    for (let i = 0; i < this.bag.length && left > 0; i++) {
      if (this.bag[i] === null) {
        const n = def.stackable ? Math.min(left, MAX_STACK) : 1;
        this.bag[i] = q > 1 ? { item: itemId, count: n, q } : { item: itemId, count: n };
        left -= n;
      }
    }
    if (left !== count) this.dirty = true;
    return left;
  }

  /** Zdejmuje `count` sztuk ze slotu plecaka. Zwraca zdjęty stos albo null. */
  takeFromBag(index: number, count?: number): ItemStack | null {
    if (!Number.isInteger(index) || index < 0 || index >= this.bag.length) return null;
    const s = this.bag[index];
    if (!s) return null;
    const n = Math.max(1, Math.min(Math.floor(count ?? s.count) || 1, s.count));
    s.count -= n;
    if (s.count <= 0) this.bag[index] = null;
    this.dirty = true;
    return { item: s.item, count: n, q: s.q ?? 1 };
  }

  /** Liczba sztuk przedmiotu w plecaku (o jakości >= minQ). */
  countOf(itemId: string, minQ = 1): number {
    return this.bag.reduce((a, s) => a + (s && s.item === itemId && (s.q ?? 1) >= minQ ? s.count : 0), 0);
  }

  /** Usuwa `count` sztuk przedmiotu z dowolnych stosów. Zwraca false (bez zmian), jeśli brakuje. */
  remove(itemId: string, count: number): boolean {
    if (this.countOf(itemId) < count) return false;
    let left = count;
    for (let i = 0; i < this.bag.length && left > 0; i++) {
      const s = this.bag[i];
      if (!s || s.item !== itemId) continue;
      const n = Math.min(left, s.count);
      s.count -= n;
      left -= n;
      if (s.count <= 0) this.bag[i] = null;
    }
    this.dirty = true;
    return true;
  }

  freeSlots(): number {
    return this.bag.filter((s) => s === null).length;
  }

  /** Najwyższy tier narzędzia danego rodzaju w plecaku (0 = brak). */
  bestTool(kind: ToolKind): number {
    let best = 0;
    for (const s of this.bag) {
      const d = s ? getItem(s.item) : undefined;
      if (d?.tool === kind && (d.tier ?? 0) > best) best = d.tier ?? 0;
    }
    return best;
  }

  /**
   * Zakłada przedmiot z plecaka. Zdjęty wcześniej przedmiot wraca do plecaka.
   * Zwraca komunikat błędu albo null przy sukcesie.
   */
  equipFromBag(index: number, level = Infinity): string | null {
    const s = this.bag[index];
    if (!s) return 'Pusty slot.';
    const def = getItem(s.item);
    if (!def?.slot) return 'Tego nie da się założyć.';
    if ((def.minLevel ?? 0) > level) return `Wymagany poziom ${def.minLevel}.`;
    const slot = def.slot;
    const toReturn: ItemStack[] = [];
    if (this.equipment[slot]) toReturn.push(this.equipment[slot]!);
    // Broń dwuręczna zdejmuje tarczę i odwrotnie.
    if (def.twoHanded && this.equipment.shield) toReturn.push(this.equipment.shield);
    if (slot === 'shield' && this.equipment.weapon && getItem(this.equipment.weapon.item)?.twoHanded)
      toReturn.push(this.equipment.weapon);
    // Po zdjęciu przedmiotu z plecaka zwalnia się 1 slot.
    if (toReturn.length > this.freeSlots() + 1) return 'Brak miejsca w plecaku.';

    this.bag[index] = null;
    for (const r of toReturn) {
      for (const k of EQUIP_SLOTS) if (this.equipment[k] === r) delete this.equipment[k];
      this.add(r.item, r.count, r.q ?? 1);
    }
    this.equipment[slot] = s.q && s.q > 1 ? { item: s.item, count: 1, q: s.q } : { item: s.item, count: 1 };
    this.dirty = true;
    return null;
  }

  unequip(slot: EquipSlot): string | null {
    const s = this.equipment[slot];
    if (!s) return 'Nic tu nie ma.';
    if (this.freeSlots() === 0) return 'Brak miejsca w plecaku.';
    delete this.equipment[slot];
    this.add(s.item, s.count, s.q ?? 1);
    this.dirty = true;
    return null;
  }

  /** Suma statystyki z założonych przedmiotów (z uwzględnieniem jakości). */
  equipmentStat(stat: 'armor' | 'hpBonus' | 'mpBonus'): number {
    let a = 0;
    for (const slot of EQUIP_SLOTS) {
      const s = this.equipment[slot];
      if (s) a += Math.round((getItem(s.item)?.[stat] ?? 0) * QUALITY_MULT[s.q ?? 1]);
    }
    return a;
  }

  totalArmor(): number {
    return this.equipmentStat('armor');
  }

  /** Łączna waga plecaka i ekwipunku (oz). */
  weight(): number {
    let w = 0;
    for (const s of this.bag) if (s) w += (getItem(s.item)?.weight ?? 0) * s.count;
    for (const slot of EQUIP_SLOTS) {
      const s = this.equipment[slot];
      if (s) w += getItem(s.item)?.weight ?? 0;
    }
    return Math.round(w * 10) / 10;
  }

  /** Wszystkie przedmioty (plecak + ekwipunek) – do zapisu. */
  toJSON() {
    return { bag: this.bag, equipment: this.equipment };
  }
}

/**
 * Walidacja stosu wczytanego z bazy / od klienta. Stare id z ETAPU 1 są mapowane
 * na nowe, nieznane przedmioty usuwane.
 */
export function sanitizeStack(
  s: ItemStack | null | undefined,
  maxCount = MAX_STACK,
  /** Depozyt przechowuje dowolną liczbę sztuk (także przedmiotów niełączących się). */
  anyCount = false,
): ItemStack | null {
  if (!s || typeof s.item !== 'string') return null;
  let item = s.item;
  let q = Math.max(1, Math.min(5, Math.floor(Number(s.q) || 1)));
  const legacy = LEGACY_ITEMS[item];
  if (legacy) {
    item = legacy[0];
    q = Math.max(q, legacy[1]);
  }
  const def = getItem(item);
  if (!def) return null;
  const cap = anyCount ? maxCount : def.stackable ? maxCount : 1;
  const count = Math.max(1, Math.min(cap, Math.floor(Number(s.count) || 1)));
  return q > 1 ? { item, count, q } : { item, count };
}
