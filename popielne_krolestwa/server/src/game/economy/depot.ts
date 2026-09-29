/**
 * Depozyty graczy – osobny w każdym mieście (jak w Tibii/Albionie).
 * Depozyt to lista pozycji {przedmiot, jakość, liczba} – te same przedmioty się łączą.
 * Zapisywany do bazy przy każdej zmianie.
 */
import { Database } from '../../db/database';
import { ItemStack, sanitizeStack } from '../inventory';
import { getItem } from '../data/items';

/** Maksymalna liczba różnych pozycji odkładanych ręcznie (dostawy z rynku zawsze wchodzą). */
export const DEPOT_ENTRIES = 100;
const MAX_ENTRY = 1_000_000_000;

export class DepotStore {
  private cache = new Map<string, ItemStack[]>();

  constructor(private db: Database) {}

  private key(charId: number, city: string) {
    return `${charId}:${city}`;
  }

  get(charId: number, city: string): ItemStack[] {
    const k = this.key(charId, city);
    let items = this.cache.get(k);
    if (!items) {
      items = [];
      const raw = this.db.loadDepot(charId, city);
      if (raw)
        for (const s of JSON.parse(raw) as ItemStack[]) {
          const clean = sanitizeStack(s, MAX_ENTRY, true);
          if (clean) items.push(clean);
        }
      this.cache.set(k, items);
    }
    return items;
  }

  /** Dodaje przedmioty. force = dostawa (ignoruje limit pozycji). Zwraca false, gdy brak miejsca. */
  add(charId: number, city: string, item: string, count: number, q = 1, force = false): boolean {
    if (count <= 0 || !getItem(item)) return false;
    const items = this.get(charId, city);
    const entry = items.find((s) => s.item === item && (s.q ?? 1) === q);
    if (entry) entry.count += count;
    else {
      if (!force && items.length >= DEPOT_ENTRIES) return false;
      items.push(q > 1 ? { item, count, q } : { item, count });
    }
    this.save(charId, city);
    return true;
  }

  /** Zabiera `count` sztuk z pozycji `index`. */
  take(charId: number, city: string, index: number, count: number): ItemStack | null {
    const items = this.get(charId, city);
    const s = items[index];
    if (!s || !Number.isInteger(index)) return null;
    const n = Math.max(1, Math.min(Math.floor(count) || 1, s.count));
    s.count -= n;
    if (s.count <= 0) items.splice(index, 1);
    this.save(charId, city);
    return { item: s.item, count: n, q: s.q ?? 1 };
  }

  save(charId: number, city: string) {
    this.db.saveDepot(charId, city, JSON.stringify(this.get(charId, city)));
  }
}
