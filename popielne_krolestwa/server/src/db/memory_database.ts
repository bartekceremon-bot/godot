/**
 * Baza danych w pamięci – tryb offline (serwer gry uruchomiony w przeglądarce).
 * Opcjonalnie zapisuje cały stan przez `persist` (np. do localStorage),
 * żeby postać przetrwała odświeżenie strony.
 */
import type { AccountRow, CharacterRow, MarketOrderRow, GameDatabase } from './types';

interface State {
  accounts: AccountRow[];
  characters: CharacterRow[];
  depots: Record<string, string>;
  orders: MarketOrderRow[];
  world?: Record<string, string>;
  nextId: number;
}

export class MemoryDatabase implements GameDatabase {
  private s: State;

  constructor(
    saved?: string | null,
    private persist?: (json: string) => void,
  ) {
    let parsed: State | null = null;
    try {
      parsed = saved ? (JSON.parse(saved) as State) : null;
    } catch {
      parsed = null;
    }
    this.s = parsed ?? { accounts: [], characters: [], depots: {}, orders: [], nextId: 1 };
  }

  private save() {
    this.persist?.(JSON.stringify(this.s));
  }

  private id() {
    return this.s.nextId++;
  }

  findAccount(name: string) {
    return this.s.accounts.find((a) => a.name.toLowerCase() === name.toLowerCase());
  }

  createAccount(name: string, passHash: string) {
    const id = this.id();
    this.s.accounts.push({ id, name, pass_hash: passHash, created_at: Date.now() });
    this.save();
    return id;
  }

  findCharacterByAccount(accountId: number) {
    return this.s.characters.find((c) => c.account_id === accountId);
  }

  createCharacter(c: Omit<CharacterRow, 'id' | 'updated_at'>) {
    const id = this.id();
    this.s.characters.push({ ...c, id, updated_at: Date.now() });
    this.save();
    return id;
  }

  saveCharacter(c: Omit<CharacterRow, 'account_id' | 'name' | 'updated_at'>) {
    const row = this.s.characters.find((r) => r.id === c.id);
    if (row) Object.assign(row, c, { updated_at: Date.now() });
    this.save();
  }

  transaction<T>(fn: () => T): T {
    return fn();
  }

  loadDepot(charId: number, city: string) {
    return this.s.depots[`${charId}:${city}`];
  }

  saveDepot(charId: number, city: string, items: string) {
    this.s.depots[`${charId}:${city}`] = items;
    this.save();
  }

  loadMarketOrders() {
    return this.s.orders.filter((o) => o.amount > 0).map((o) => ({ ...o }));
  }

  insertMarketOrder(o: Omit<MarketOrderRow, 'id'>) {
    const id = this.id();
    this.s.orders.push({ ...o, id });
    this.save();
    return id;
  }

  updateMarketOrderAmount(id: number, amount: number) {
    if (amount <= 0) this.s.orders = this.s.orders.filter((o) => o.id !== id);
    else {
      const o = this.s.orders.find((r) => r.id === id);
      if (o) o.amount = amount;
    }
    this.save();
  }

  loadWorldState(key: string) {
    return this.s.world?.[key];
  }

  saveWorldState(key: string, value: string) {
    this.s.world = this.s.world ?? {};
    this.s.world[key] = value;
    this.save();
  }

  close() {
    this.save();
  }
}
