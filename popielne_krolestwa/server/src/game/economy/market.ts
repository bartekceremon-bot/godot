/**
 * Rynek miejski: księga zleceń kupna i sprzedaży (osobna w każdym mieście).
 *
 * - Zlecenie sprzedaży: przedmioty trafiają „w depozyt” rynku (escrow).
 * - Zlecenie kupna: złoto trafia do escrow.
 * - Nowe zlecenie najpierw realizuje się z istniejącymi (po cenie zlecenia czekającego),
 *   reszta czeka w księdze.
 * - Druga strona transakcji dostaje towar / złoto do depozytu w tym mieście.
 *
 * Klasa nie dotyka plecaków – robi to warstwa świata (EconomySystem), która
 * opakowuje całą operację w jedną transakcję bazy.
 */
import { Database, MarketOrderRow } from '../../db/database';

export type Order = MarketOrderRow;

export interface Fill {
  orderId: number;
  counterpartId: number;
  price: number;
  amount: number;
  /** Jakość przedmiotu, który zmienił właściciela. */
  q: number;
}

export interface MarketHooks {
  /** Dostawa przedmiotu do depozytu gracza w mieście. */
  deliverItem(charId: number, city: string, item: string, count: number, q: number): void;
  /** Dostawa złota do depozytu gracza w mieście. */
  deliverGold(charId: number, city: string, amount: number): void;
  /** Powiadomienie gracza (jeśli online). */
  notify(charId: number, text: string): void;
}

export interface BookRow {
  item: string;
  q: number;
  price: number;
  amount: number;
}

export const MAX_ORDERS_PER_PLAYER = 20;
export const MAX_PRICE = 10_000_000;

export class Market {
  readonly orders = new Map<number, Order>();

  constructor(
    private db: Database,
    private hooks: MarketHooks,
  ) {
    for (const o of db.loadMarketOrders()) this.orders.set(o.id, o);
  }

  /** Podatek od sprzedaży (zaokrąglany w dół, min. 0). */
  static tax(gross: number, rate: number) {
    return Math.floor(gross * rate);
  }

  private matching(city: string, side: 'buy' | 'sell', item: string, pred: (o: Order) => boolean): Order[] {
    const list = [...this.orders.values()].filter((o) => o.city === city && o.side === side && o.item === item && pred(o));
    // Najlepsza cena pierwsza; przy równej cenie – starsze zlecenie.
    list.sort((a, b) => (side === 'sell' ? a.price - b.price : b.price - a.price) || a.created_at - b.created_at);
    return list;
  }

  /** Podgląd: ile sztuk i za ile można kupić natychmiast (bez zmian). */
  previewBuy(city: string, item: string, minQ: number, maxPrice: number, count: number, buyerId: number) {
    let left = count;
    let cost = 0;
    for (const o of this.matching(city, 'sell', item, (o) => o.quality >= minQ && o.price <= maxPrice && o.char_id !== buyerId)) {
      if (left <= 0) break;
      const n = Math.min(left, o.amount);
      cost += n * o.price;
      left -= n;
    }
    return { amount: count - left, cost };
  }

  /** Podgląd natychmiastowej sprzedaży. */
  previewSell(city: string, item: string, q: number, minPrice: number, count: number, sellerId: number) {
    let left = count;
    let gross = 0;
    for (const o of this.matching(city, 'buy', item, (o) => o.quality <= q && o.price >= minPrice && o.char_id !== sellerId)) {
      if (left <= 0) break;
      const n = Math.min(left, o.amount);
      gross += n * o.price;
      left -= n;
    }
    return { amount: count - left, gross };
  }

  /**
   * Kupno z czekających zleceń sprzedaży. Sprzedający dostają złoto (minus podatek) do depozytu.
   * Zwraca realizacje – kupujący sam odbiera przedmioty i płaci.
   */
  executeBuy(city: string, item: string, minQ: number, maxPrice: number, count: number, buyerId: number, taxRate: number): Fill[] {
    const fills: Fill[] = [];
    let left = count;
    for (const o of this.matching(city, 'sell', item, (o) => o.quality >= minQ && o.price <= maxPrice && o.char_id !== buyerId)) {
      if (left <= 0) break;
      const n = Math.min(left, o.amount);
      this.reduce(o, n);
      const gross = n * o.price;
      this.hooks.deliverGold(o.char_id, city, gross - Market.tax(gross, taxRate));
      this.hooks.notify(o.char_id, `Rynek: sprzedano ${n} szt. za ${gross} zł (złoto w depozycie).`);
      fills.push({ orderId: o.id, counterpartId: o.char_id, price: o.price, amount: n, q: o.quality });
      left -= n;
    }
    return fills;
  }

  /**
   * Sprzedaż do czekających zleceń kupna. Kupujący dostają przedmioty do depozytu
   * (ich złoto było już w escrow). Sprzedający sam dostaje złoto.
   */
  executeSell(city: string, item: string, q: number, minPrice: number, count: number, sellerId: number): Fill[] {
    const fills: Fill[] = [];
    let left = count;
    for (const o of this.matching(city, 'buy', item, (o) => o.quality <= q && o.price >= minPrice && o.char_id !== sellerId)) {
      if (left <= 0) break;
      const n = Math.min(left, o.amount);
      this.reduce(o, n);
      this.hooks.deliverItem(o.char_id, city, item, n, q);
      this.hooks.notify(o.char_id, `Rynek: kupiono ${n} szt. (towar w depozycie).`);
      fills.push({ orderId: o.id, counterpartId: o.char_id, price: o.price, amount: n, q });
      left -= n;
    }
    return fills;
  }

  place(o: Omit<Order, 'id' | 'created_at'>): Order {
    const full = { ...o, created_at: Date.now() } as Order;
    full.id = this.db.insertMarketOrder(full);
    this.orders.set(full.id, full);
    return full;
  }

  /** Anuluje zlecenie gracza i zwraca je (wywołujący oddaje escrow). */
  cancel(id: number, charId: number): Order | null {
    const o = this.orders.get(id);
    if (!o || o.char_id !== charId) return null;
    this.orders.delete(id);
    this.db.updateMarketOrderAmount(id, 0);
    return o;
  }

  private reduce(o: Order, n: number) {
    o.amount -= n;
    this.db.updateMarketOrderAmount(o.id, o.amount);
    if (o.amount <= 0) this.orders.delete(o.id);
  }

  countFor(charId: number) {
    let n = 0;
    for (const o of this.orders.values()) if (o.char_id === charId) n++;
    return n;
  }

  /** Zagregowana księga zleceń miasta (bez nazw graczy). */
  book(city: string): { sells: BookRow[]; buys: BookRow[] } {
    const agg = (side: 'buy' | 'sell') => {
      const m = new Map<string, BookRow>();
      for (const o of this.orders.values()) {
        if (o.city !== city || o.side !== side) continue;
        const k = `${o.item}|${o.quality}|${o.price}`;
        const row = m.get(k);
        if (row) row.amount += o.amount;
        else m.set(k, { item: o.item, q: o.quality, price: o.price, amount: o.amount });
      }
      return [...m.values()].sort((a, b) => a.item.localeCompare(b.item) || (side === 'sell' ? a.price - b.price : b.price - a.price));
    };
    return { sells: agg('sell'), buys: agg('buy') };
  }

  mine(charId: number): Order[] {
    return [...this.orders.values()].filter((o) => o.char_id === charId).sort((a, b) => b.created_at - a.created_at);
  }
}
