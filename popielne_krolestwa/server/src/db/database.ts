/**
 * Warstwa bazy danych (SQLite przez wbudowany moduł `node:sqlite`).
 *
 * Cały dostęp do bazy przechodzi przez repozytoria poniżej, a SQL jest
 * standardowy – migracja na PostgreSQL sprowadzi się do podmiany tej klasy.
 */
import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';

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
  updated_at: number;
}

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
];

export class Database {
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
        `INSERT INTO characters (account_id, name, x, y, level, exp, hp, mp, look, skills, inventory, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(c.account_id, c.name, c.x, c.y, c.level, c.exp, c.hp, c.mp, c.look, c.skills, c.inventory, Date.now());
    return Number(r.lastInsertRowid);
  }

  saveCharacter(c: Omit<CharacterRow, 'account_id' | 'name' | 'updated_at'>) {
    this.db
      .prepare(
        `UPDATE characters SET x = ?, y = ?, level = ?, exp = ?, hp = ?, mp = ?, look = ?,
           skills = ?, inventory = ?, updated_at = ? WHERE id = ?`,
      )
      .run(c.x, c.y, c.level, c.exp, c.hp, c.mp, c.look, c.skills, c.inventory, Date.now(), c.id);
  }

  close() {
    this.db.close();
  }
}
