/**
 * Tworzenie nowych postaci i odtwarzanie postaci z bazy – wspólne dla serwera
 * WebSocket (net/server.ts) i trybu offline w przeglądarce (offline/host.ts).
 */
import { Player, Connection } from './entities';
import { Inventory } from './inventory';
import { defaultSkills, maxHpForLevel, maxMpForLevel, Skills } from './progression';
import { defaultSpecs, loadSpecs } from './specs';
import { randInt } from '../util/rng';
import type { CharacterRow, GameDatabase } from '../db/types';
import type { Point } from './map';

/**
 * Ekwipunek startowy nowej postaci – broń wręcz i łuk (oba style walki)
 * oraz narzędzia T1, żeby od razu zacząć zbieractwo.
 */
export function starterInventory(): Inventory {
  const inv = new Inventory([], {
    weapon: { item: 'sword_t1', count: 1 },
    shield: { item: 'shield_t1', count: 1 },
    body: { item: 'leather_body_t1', count: 1 },
  });
  inv.add('bow_t1');
  inv.add('woodaxe_t1');
  inv.add('pickaxe_t1');
  inv.add('sickle_t1');
  inv.add('hp_potion', 3);
  inv.add('mp_potion', 2);
  inv.add('gold', 30);
  return inv;
}

/** Zakłada konto z postacią (hasło już zahashowane albo puste w trybie offline). */
export function createAccountWithCharacter(db: GameDatabase, name: string, passHash: string, start: Point): number {
  const accountId = db.createAccount(name, passHash);
  db.createCharacter({
    account_id: accountId,
    name,
    x: start.x,
    y: start.y,
    level: 1,
    exp: 0,
    hp: maxHpForLevel(1),
    mp: maxMpForLevel(1),
    look: randInt(0, 7),
    skills: JSON.stringify(defaultSkills()),
    inventory: JSON.stringify(starterInventory().toJSON()),
    specs: JSON.stringify(defaultSpecs()),
  });
  return accountId;
}

/** Postać z wiersza bazy -> obiekt gracza w świecie. */
export function playerFromRow(row: CharacterRow, conn: Connection): Player {
  const inv = JSON.parse(row.inventory);
  const skills = { ...defaultSkills(), ...(JSON.parse(row.skills) as Skills) };
  const inventory = new Inventory(inv.bag, inv.equipment);
  // Postać z ETAPU 1 (brak specjalizacji) dostaje jednorazowo narzędzia T1 do zbieractwa.
  if (!row.specs || row.specs === '{}') for (const tool of ['woodaxe_t1', 'pickaxe_t1', 'sickle_t1']) inventory.add(tool);
  return new Player({
    charId: row.id,
    name: row.name,
    conn,
    x: row.x,
    y: row.y,
    hp: row.hp,
    mp: row.mp,
    exp: row.exp,
    look: row.look,
    skills,
    specs: loadSpecs(JSON.parse(row.specs || '{}')),
    inventory,
  });
}
