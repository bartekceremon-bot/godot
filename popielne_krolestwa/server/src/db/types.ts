/**
 * Typy warstwy danych. Świat gry korzysta wyłącznie z interfejsu GameDatabase,
 * więc może działać na SQLite (serwer), PostgreSQL (w przyszłości)
 * albo w pamięci przeglądarki (tryb offline, MemoryDatabase).
 */

export interface AccountRow {
  id: number;
  name: string;
  pass_hash: string;
  created_at: number;
}

export interface CharacterRow {
  id: number;
  account_id: number;
  name: string;
  x: number;
  y: number;
  level: number;
  exp: number;
  hp: number;
  mp: number;
  look: number;
  /** JSON: Skills */
  skills: string;
  /** JSON: { bag, equipment } */
  inventory: string;
  /** JSON: Specs (drzewko specjalizacji) */
  specs: string;
  /** JSON: PvpState (czaszka, zabójstwa, błogosławieństwa) */
  pvp: string;
  updated_at: number;
}

export interface MarketOrderRow {
  id: number;
  city: string;
  char_id: number;
  char_name: string;
  side: 'buy' | 'sell';
  item: string;
  /** Sprzedaż: jakość przedmiotu; kupno: minimalna akceptowana jakość. */
  quality: number;
  price: number;
  amount: number;
  created_at: number;
}

export interface GameDatabase {
  findAccount(name: string): AccountRow | undefined;
  createAccount(name: string, passHash: string): number;
  findCharacterByAccount(accountId: number): CharacterRow | undefined;
  createCharacter(c: Omit<CharacterRow, 'id' | 'updated_at'>): number;
  saveCharacter(c: Omit<CharacterRow, 'account_id' | 'name' | 'updated_at'>): void;
  transaction<T>(fn: () => T): T;
  loadDepot(charId: number, city: string): string | undefined;
  saveDepot(charId: number, city: string, items: string): void;
  loadMarketOrders(): MarketOrderRow[];
  insertMarketOrder(o: Omit<MarketOrderRow, 'id'>): number;
  updateMarketOrderAmount(id: number, amount: number): void;
  close(): void;
}
