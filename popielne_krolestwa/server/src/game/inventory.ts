/**
 * Plecak i ekwipunek gracza. Cała logika po stronie serwera – klient tylko prosi.
 */
import { EquipSlot, EQUIP_SLOTS, getItem } from './data/items';

export interface ItemStack {
  item: string;
  count: number;
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
    if (bag) for (let i = 0; i < Math.min(bag.length, BAG_SIZE); i++) this.bag[i] = sanitize(bag[i]);
    this.equipment = {};
    if (equipment)
      for (const slot of EQUIP_SLOTS) {
        const s = sanitize(equipment[slot] ?? null);
        if (s && getItem(s.item)?.slot === slot) this.equipment[slot] = s;
      }
  }

  /**
   * Dodaje przedmiot do plecaka (łączy stosy). Zwraca liczbę sztuk, które się NIE zmieściły.
   */
  add(itemId: string, count = 1): number {
    const def = getItem(itemId);
    if (!def || count <= 0) return count;
    let left = count;
    if (def.stackable) {
      for (const s of this.bag) {
        if (left <= 0) break;
        if (s && s.item === itemId && s.count < MAX_STACK) {
          const n = Math.min(left, MAX_STACK - s.count);
          s.count += n;
          left -= n;
        }
      }
    }
    for (let i = 0; i < this.bag.length && left > 0; i++) {
      if (this.bag[i] === null) {
        const n = def.stackable ? Math.min(left, MAX_STACK) : 1;
        this.bag[i] = { item: itemId, count: n };
        left -= n;
      }
    }
    if (left !== count) this.dirty = true;
    return left;
  }

  /** Zdejmuje `count` sztuk ze slotu plecaka. Zwraca zdjęty stos albo null. */
  takeFromBag(index: number, count?: number): ItemStack | null {
    const s = this.bag[index];
    if (!s) return null;
    const n = Math.max(1, Math.min(count ?? s.count, s.count));
    s.count -= n;
    if (s.count <= 0) this.bag[index] = null;
    this.dirty = true;
    return { item: s.item, count: n };
  }

  countOf(itemId: string): number {
    return this.bag.reduce((a, s) => a + (s && s.item === itemId ? s.count : 0), 0);
  }

  freeSlots(): number {
    return this.bag.filter((s) => s === null).length;
  }

  /**
   * Zakłada przedmiot z plecaka. Zdjęty wcześniej przedmiot wraca do plecaka.
   * Zwraca komunikat błędu albo null przy sukcesie.
   */
  equipFromBag(index: number): string | null {
    const s = this.bag[index];
    if (!s) return 'Pusty slot.';
    const def = getItem(s.item);
    if (!def?.slot) return 'Tego nie da się założyć.';
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
      this.add(r.item, r.count);
    }
    this.equipment[slot] = { item: s.item, count: 1 };
    this.dirty = true;
    return null;
  }

  unequip(slot: EquipSlot): string | null {
    const s = this.equipment[slot];
    if (!s) return 'Nic tu nie ma.';
    if (this.freeSlots() === 0) return 'Brak miejsca w plecaku.';
    delete this.equipment[slot];
    this.add(s.item, s.count);
    this.dirty = true;
    return null;
  }

  /** Suma pancerza z założonych przedmiotów. */
  totalArmor(): number {
    let a = 0;
    for (const slot of EQUIP_SLOTS) {
      const s = this.equipment[slot];
      if (s) a += getItem(s.item)?.armor ?? 0;
    }
    return a;
  }

  /** Wszystkie przedmioty (plecak + ekwipunek) – do zapisu. */
  toJSON() {
    return { bag: this.bag, equipment: this.equipment };
  }
}

function sanitize(s: ItemStack | null | undefined): ItemStack | null {
  if (!s || typeof s.item !== 'string' || !getItem(s.item)) return null;
  const count = Math.max(1, Math.min(MAX_STACK, Math.floor(Number(s.count) || 1)));
  return { item: s.item, count };
}
