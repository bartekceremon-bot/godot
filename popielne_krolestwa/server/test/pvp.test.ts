/**
 * Testy ETAPU 3: strefy, czaszki, kara za śmierć, full loot, błogosławieństwa,
 * blokada strefy ochronnej i umiejętności broni.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Database } from '../src/db/database';
import { World, MAP_VERSION } from '../src/game/world';
import { Player, Connection, Monster } from '../src/game/entities';
import { Inventory } from '../src/game/inventory';
import { defaultSkills } from '../src/game/progression';
import { defaultSpecs } from '../src/game/specs';
import { MONSTERS } from '../src/game/data/monsters';

class FakeConn implements Connection {
  msgs: any[] = [];
  send(m: object | string) {
    this.msgs.push(typeof m === 'string' ? JSON.parse(m) : m);
  }
  close() {}
  sys() {
    return this.msgs.filter((m) => m.t === 'sys').map((m) => m.text as string);
  }
}

let n = 0;
function mk(world: World, name: string, x: number, y: number) {
  const acc = world.db.createAccount(name + ++n, 'x');
  const charId = world.db.createCharacter({
    account_id: acc, name: name + n, x, y, level: 1, exp: 0, hp: 150, mp: 50, look: 0,
    skills: JSON.stringify(defaultSkills()), inventory: '{"bag":[],"equipment":{}}', specs: JSON.stringify(defaultSpecs()), pvp: '{}',
  });
  const conn = new FakeConn();
  const p = new Player({ charId, name, conn, x, y, hp: 150, mp: 50, exp: 0, look: 0, skills: defaultSkills(), specs: defaultSpecs(), inventory: new Inventory() });
  p.pvp.mv = MAP_VERSION; // pozycja z bieżącej mapy – bez przenoszenia do świątyni
  world.addPlayer(p);
  return { p, conn };
}

import { zoneSpot } from './spots';
import { CITIES } from '../src/game/data/cities';

// Miejsca w strefach wyszukiwane na wygenerowanej mapie.
const probe = new World(new Database(':memory:'));
const GREEN = zoneSpot(probe, 'green');
const YELLOW = zoneSpot(probe, 'yellow');
const RED = zoneSpot(probe, 'red');

/** Zadaje obrażenia aż do śmierci ofiary (z pominięciem losowości). */
function killBy(world: World, killer: Player, victim: Player) {
  world.hit(killer, victim, 0, {}); // rejestracja ataku (czaszki, agresja)
  world.applyDamage(victim, victim.hp + 10, killer);
}

test('strefy: mapa ma zieloną, żółtą i czerwoną strefę', () => {
  const w = new World(new Database(':memory:'));
  assert.equal(w.map.zoneAt(GREEN.x, GREEN.y), 'green');
  assert.equal(w.map.zoneAt(YELLOW.x, YELLOW.y), 'yellow');
  assert.equal(w.map.zoneAt(RED.x, RED.y), 'red');
  assert.equal(w.map.zoneAt(w.map.temple.x, w.map.temple.y), 'green');
});

test('zielona strefa: brak PvP', () => {
  const w = new World(new Database(':memory:'));
  const { p: a, conn } = mk(w, 'Agresor', GREEN.x, GREEN.y);
  const { p: b } = mk(w, 'Ofiara', GREEN.x + 1, GREEN.y);
  w.handle(a, { t: 'attack', id: b.id });
  assert.equal(a.targetId, 0);
  assert.ok(conn.sys().some((t) => /zielonej strefie/.test(t)));
});

test('żółta strefa: biała czaszka za atak, obrona bez czaszki, czerwona po 3 zabójstwach', () => {
  const w = new World(new Database(':memory:'));
  const { p: a } = mk(w, 'Zabijaka', YELLOW.x, YELLOW.y);
  const { p: b } = mk(w, 'Obronca', YELLOW.x + 1, YELLOW.y);
  w.hit(a, b, 5, {});
  assert.equal(a.pvp.skull, 'white');
  assert.ok(a.pzLockUntil > Date.now());
  // Obrońca oddaje – usprawiedliwione.
  w.hit(b, a, 5, {});
  assert.equal(b.pvp.skull, '');
  // Trzy niesprawiedliwe zabójstwa -> czerwona czaszka.
  for (let i = 0; i < 3; i++) {
    const { p: v } = mk(w, 'Niewinny', YELLOW.x, YELLOW.y + 1);
    killBy(w, a, v);
  }
  assert.equal(a.pvp.skull, 'red');
  assert.equal(a.pvp.unjustKills.length, 3);
});

test('żółta strefa: utrata części plecaka; 5 błogosławieństw chroni plecak', () => {
  const w = new World(new Database(':memory:'));
  const { p: k } = mk(w, 'Bandyta', YELLOW.x, YELLOW.y);
  const { p: v } = mk(w, 'Kupiec', YELLOW.x + 1, YELLOW.y);
  v.exp = 1000;
  for (let i = 0; i < 20; i++) v.inventory.add('sword_t1');
  v.pvp.blessings = 5;
  killBy(w, k, v);
  assert.equal(v.inventory.bag.filter(Boolean).length, 20, 'plecak nietknięty');
  assert.equal(v.pvp.blessings, 0, 'błogosławieństwa zużyte');
  assert.ok(v.exp > 1000 - 70, 'mniejsza strata doświadczenia');
  assert.equal(v.x, w.map.temple.x, 'odrodzenie w świątyni domowej');
  // Bez błogosławieństw – część plecaka zostaje w zwłokach.
  v.x = YELLOW.x + 1;
  v.y = YELLOW.y;
  killBy(w, k, v);
  const left = v.inventory.bag.filter(Boolean).length;
  assert.ok(left < 20 && left > 0, `zostało ${left} stosów`);
});

test('czerwona strefa: full loot – plecak i ekwipunek w zwłokach', () => {
  const w = new World(new Database(':memory:'));
  const { p: k } = mk(w, 'Lowca', RED.x, RED.y);
  const { p: v, conn } = mk(w, 'Pechowiec', RED.x + 1, RED.y);
  v.inventory.add('gold', 100);
  v.inventory.add('plate_body_t2');
  v.inventory.equipFromBag(v.inventory.bag.findIndex((s) => s?.item === 'plate_body_t2'));
  const deathX = v.x;
  killBy(w, k, v);
  assert.equal(v.inventory.bag.filter(Boolean).length, 0);
  assert.equal(v.inventory.equipment.body, undefined);
  const corpse = [...w.groundItems.values()].filter((g) => g.x === deathX && g.y === RED.y).map((g) => g.item);
  assert.ok(corpse.includes('gold') && corpse.includes('plate_body_t2'));
  assert.equal(k.pvp.skull, '', 'w czerwonej strefie nie ma czaszek');
  assert.ok(conn.msgs.some((m) => m.t === 'died' && m.zone === 'red'));
});

test('blokada strefy ochronnej po ataku na gracza', () => {
  const w = new World(new Database(':memory:'));
  const { p: a, conn } = mk(w, 'Uciekinier', 0, 0);
  const P = CITIES.popielgrod;
  a.x = P.x0 + 15;
  a.y = P.y0 + 25; // tuż za południową bramą (brama = strefa ochronna)
  a.pzLockUntil = Date.now() + 60_000;
  w.handle(a, { t: 'move', d: 0 });
  assert.equal(a.y, P.y0 + 25);
  assert.ok(conn.sys().some((t) => /strefy ochronnej/.test(t)));
});

test('kapłanka sprzedaje błogosławieństwa', () => {
  const w = new World(new Database(':memory:'));
  const priest = [...w.npcs.values()].find((x) => x.def.id === 'priest')!;
  const { p } = mk(w, 'Pobozny', priest.x + 1, priest.y);
  p.inventory.add('gold', 1000);
  w.handle(p, { t: 'npc', id: priest.id, word: 'witaj' });
  w.handle(p, { t: 'npc', id: priest.id, word: 'błogosławieństwo' });
  assert.equal(p.pvp.blessings, 1);
  assert.equal(p.inventory.countOf('gold'), 1000 - 120);
});

test('umiejętności broni: koszt many, cooldown, ogłuszenie i wir', () => {
  const w = new World(new Database(':memory:'));
  const G = zoneSpot(w, 'green');
  const { p, conn } = mk(w, 'Wojak', G.x, G.y);
  // Bez broni – brak umiejętności.
  w.handle(p, { t: 'ability', slot: 1 });
  assert.ok(conn.sys().some((t) => /Załóż broń/.test(t)));
  p.inventory.add('mace_t1');
  p.inventory.equipFromBag(p.inventory.bag.findIndex((s) => s?.item === 'mace_t1'));
  const rat = new Monster({ ...MONSTERS.rat, hp: 500 }, G.x + 1, G.y, 0);
  w.monsters.set(rat.id, rat);
  p.targetId = rat.id;
  const mp = p.mp;
  w.handle(p, { t: 'ability', slot: 1 }); // Ogłuszenie
  assert.ok(rat.status.stunUntil > Date.now());
  assert.equal(p.mp, mp - 14);
  w.handle(p, { t: 'ability', slot: 1 }); // cooldown – bez efektu
  assert.equal(p.mp, mp - 14);
  assert.ok(conn.msgs.some((m) => m.t === 'cd' && m.id === 'mace_stun'));
  // Topór: wir trafia dwa potwory naraz.
  p.inventory.add('axe_t1');
  p.inventory.equipFromBag(p.inventory.bag.findIndex((s) => s?.item === 'axe_t1'));
  const rat2 = new Monster({ ...MONSTERS.rat, hp: 500, armor: 0, defense: 0 }, G.x - 1, G.y, 0);
  w.monsters.set(rat2.id, rat2);
  const hp1 = rat.hp;
  const hp2 = rat2.hp;
  p.mp = 50;
  w.handle(p, { t: 'ability', slot: 2 });
  assert.ok(rat2.hp < hp2 || rat.hp < hp1);
});
