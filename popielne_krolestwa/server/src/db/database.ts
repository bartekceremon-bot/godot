/**
 * Warstwa bazy danych (SQLite przez wbudowany moduł `node:sqlite`).
 *
 * Cały dostęp do bazy przechodzi przez repozytoria poniżej, a SQL jest
 * standardowy – migracja na PostgreSQL sprowadzi się do podmiany tej klasy.
 */
import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';

import type { AccountRow, CharacterRow, MarketOrderRow, GameDatabase } from './types';

export type { AccountRow, CharacterRow, MarketOrderRow, GameDatabase };

/** Kolejne migracje schematu – dopisujemy nowe na końcu, nigdy nie zmieniamy starych. */
const MIGRATIONS: string[] = [
  `CREATE TABLE accounts (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     name TEXT NOT NULL UNIQUE COLLATE NOCASE,
     pass_hash TEXT NOT NULL,
     created_at INTEGER NOT NULL
   );
   CREATE TABLE characters (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     account_id INTEGER NOT NULL REFERENCES accounts(id),
     name TEXT NOT NULL UNIQUE COLLATE NOCASE,
     x INTEGER NOT NULL,
     y INTEGER NOT NULL,
     level INTEGER NOT NULL DEFAULT 1,
     exp INTEGER NOT NULL DEFAULT 0,
     hp INTEGER NOT NULL,
     mp INTEGER NOT NULL,
     look INTEGER NOT NULL DEFAULT 0,
     skills TEXT NOT NULL,
     inventory TEXT NOT NULL,
     updated_at INTEGER NOT NULL
   );`,
  // ETAP 2: ekonomia – specjalizacje, depozyty, rynek.
  `ALTER TABLE characters ADD COLUMN specs TEXT NOT NULL DEFAULT '{}';
   CREATE TABLE depots (
     char_id INTEGER NOT NULL REFERENCES characters(id),
     city TEXT NOT NULL,
     items TEXT NOT NULL,
     PRIMARY KEY (char_id, city)
   );
   CREATE TABLE market_orders (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     city TEXT NOT NULL,
     char_id INTEGER NOT NULL REFERENCES characters(id),
     char_name TEXT NOT NULL,
     side TEXT NOT NULL CHECK (side IN ('buy', 'sell')),
     item TEXT NOT NULL,
     quality INTEGER NOT NULL,
     price INTEGER NOT NULL,
     amount INTEGER NOT NULL,
     created_at INTEGER NOT NULL
   );
   CREATE INDEX market_orders_city_item ON market_orders (city, item);`,
  // ETAP 3: PvP – czaszki, niesprawiedliwe zabójstwa, błogosławieństwa.
  `ALTER TABLE characters ADD COLUMN pvp TEXT NOT NULL DEFAULT '{}';`,
];

export class Database implements GameDatabase {
  private db: DatabaseSync;

  constructor(file: string) {
    if (file !== ':memory:') fs.mkdirSync(path.dirname(path.resolve(file)), { recursive: true });
    this.db = new DatabaseSync(file);
    this.db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');
    this.migrate();
  }

  private migrate() {
    this.db.exec('CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)');
    const row = this.db.prepare('SELECT version FROM schema_version').get() as { version: number } | undefined;
    let version = row?.version ?? 0;
    if (!row) this.db.prepare('INSERT INTO schema_version (version) VALUES (0)').run();
    while (version < MIGRATIONS.length) {
      this.db.exec('BEGIN');
      try {
        this.db.exec(MIGRATIONS[version]);
        version++;
        this.db.prepare('UPDATE schema_version SET version = ?').run(version);
        this.db.exec('COMMIT');
      } catch (e) {
        this.db.exec('ROLLBACK');
        throw e;
      }
    }
  }

  // --- Konta -----------------------------------------------------------------

  findAccount(name: string): AccountRow | undefined {
    return this.db.prepare('SELECT * FROM accounts WHERE name = ?').get(name) as AccountRow | undefined;
  }

  createAccount(name: string, passHash: string): number {
    const r = this.db
      .prepare('INSERT INTO accounts (name, pass_hash, created_at) VALUES (?, ?, ?)')
      .run(name, passHash, Date.now());
    return Number(r.lastInsertRowid);
  }

  // --- Postacie ---------------------------------------------------------------

  findCharacterByAccount(accountId: number): CharacterRow | undefined {
    return this.db.prepare('SELECT * FROM characters WHERE account_id = ? LIMIT 1').get(accountId) as
      | CharacterRow
      | undefined;
  }

  createCharacter(c: Omit<CharacterRow, 'id' | 'updated_at'>): number {
    const r = this.db
      .prepare(
        `INSERT INTO characters (account_id, name, x, y, level, exp, hp, mp, look, skills, inventory, specs, pvp, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(c.account_id, c.name, c.x, c.y, c.level, c.exp, c.hp, c.mp, c.look, c.skills, c.inventory, c.specs, c.pvp, Date.now());
    return Number(r.lastInsertRowid);
  }

  saveCharacter(c: Omit<CharacterRow, 'account_id' | 'name' | 'updated_at'>) {
    this.db
      .prepare(
        `UPDATE characters SET x = ?, y = ?, level = ?, exp = ?, hp = ?, mp = ?, look = ?,
           skills = ?, inventory = ?, specs = ?, pvp = ?, updated_at = ? WHERE id = ?`,
      )
      .run(c.x, c.y, c.level, c.exp, c.hp, c.mp, c.look, c.skills, c.inventory, c.specs, c.pvp, Date.now(), c.id);
  }

  // --- Transakcje ---------------------------------------------------------------

  /**
   * Wykonuje funkcję w jednej transakcji SQL. Handel zapisuje w niej zarówno
   * zmiany rynku/depozytu, jak i stan postaci – dzięki temu awaria serwera
   * nie może zduplikować przedmiotów.
   */
  transaction<T>(fn: () => T): T {
    this.db.exec('BEGIN');
    try {
      const r = fn();
      this.db.exec('COMMIT');
      return r;
    } catch (e) {
      this.db.exec('ROLLBACK');
      throw e;
    }
  }

  // --- Depozyty -----------------------------------------------------------------

  loadDepot(charId: number, city: string): string | undefined {
    const r = this.db.prepare('SELECT items FROM depots WHERE char_id = ? AND city = ?').get(charId, city) as
      | { items: string }
      | undefined;
    return r?.items;
  }

  saveDepot(charId: number, city: string, items: string) {
    this.db
      .prepare(
        `INSERT INTO depots (char_id, city, items) VALUES (?, ?, ?)
         ON CONFLICT (char_id, city) DO UPDATE SET items = excluded.items`,
      )
      .run(charId, city, items);
  }

  // --- Rynek --------------------------------------------------------------------

  loadMarketOrders(): MarketOrderRow[] {
    return this.db.prepare('SELECT * FROM market_orders WHERE amount > 0').all() as unknown as MarketOrderRow[];
  }

  insertMarketOrder(o: Omit<MarketOrderRow, 'id'>): number {
    const r = this.db
      .prepare(
        `INSERT INTO market_orders (city, char_id, char_name, side, item, quality, price, amount, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(o.city, o.char_id, o.char_name, o.side, o.item, o.quality, o.price, o.amount, o.created_at);
    return Number(r.lastInsertRowid);
  }

  updateMarketOrderAmount(id: number, amount: number) {
    if (amount <= 0) this.db.prepare('DELETE FROM market_orders WHERE id = ?').run(id);
    else this.db.prepare('UPDATE market_orders SET amount = ? WHERE id = ?').run(amount, id);
  }

  close() {
    this.db.close();
  }
}
