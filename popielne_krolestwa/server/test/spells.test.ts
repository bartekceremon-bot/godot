/**
 * Testy magii: nauka czarów u kapłana, czary ofensywne (pocisk, podpalenie, obszar, meteor),
 * zamrożenie, lodowa zbroja, klątwa, przyspieszenie, kostur.
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
import { SPELLS, findSpellByWords } from '../src/game/data/spells';
import { ITEMS } from '../src/game/data/items';
import { SpellSystem } from '../src/game/systems/spells';
import { zoneSpot } from './spots';

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
    account_id: acc, name, x, y, level: 1, exp: 0, hp: 150, mp: 50, look: 0,
    skills: JSON.stringify(defaultSkills()), inventory: '{"bag":[],"equipment":{}}', specs: JSON.stringify(defaultSpecs()), pvp: '{}',
  });
  const conn = new FakeConn();
  const p = new Player({ charId, name, conn, x, y, hp: 150, mp: 50, exp: 0, look: 0, skills: defaultSkills(), specs: defaultSpecs(), inventory: new Inventory() });
  p.pvp.mv = MAP_VERSION;
  world.addPlayer(p);
  // Silny mag do testów.
  p.level = 60;
  p.skills.magic.level = 25;
  p.mp = 5000;
  return { p, conn };
}

function dummy(w: World, x: number, y: number, hp = 100000) {
  const m = new Monster({ ...MONSTERS.wolf, hp, armor: 50, defense: 50 }, x, y, 0);
  (w as any).addMonster(m);
  return m;
}

test('czary: 17 czarów w 5 szkołach, formuły rozpoznawane', () => {
  assert.equal(Object.keys(SPELLS).length, 18);
  assert.equal(findSpellByWords('EXORI FLAM')?.id, 'fireball');
  assert.ok(ITEMS.staff_t8.spellPower! > ITEMS.staff_t1.spellPower!);
});

test('nauka czaru u kapłana: złoto, poziom, szkoły miasta', () => {
  const w = new World(new Database(':memory:'));
  const priest = [...w.npcs.values()].find((x) => x.def.city === 'popielgrod' && x.def.id === 'priest')!;
  const { p, conn } = mk(w, 'Uczen', priest.x, priest.y + 1);
  w.spells.cast(p, 'fireball', Date.now());
  assert.ok(conn.sys().some((s) => s.includes('Nie znasz')));
  w.economy.learnSpell(p, 'fireball');
  assert.ok(conn.sys().some((s) => s.includes('za mało złota')));
  p.inventory.add('gold', 5000);
  w.economy.learnSpell(p, 'fireball');
  assert.ok(SpellSystem.knows(p, 'fireball'));
  assert.equal(p.inventory.countOf('gold'), 4500);
  // Lód uczy tylko Szronogród.
  w.economy.learnSpell(p, 'icebolt');
  assert.ok(!SpellSystem.knows(p, 'icebolt'));
  assert.ok(conn.msgs.some((m) => m.t === 'spell_shop'));
});

test('czary ofensywne: kula ognia podpala, obszar trafia kilku, meteor spada z opóźnieniem', () => {
  const w = new World(new Database(':memory:'));
  const G = zoneSpot(w, 'green');
  const { p } = mk(w, 'Mag', G.x, G.y);
  p.pvp.spells = ['fireball', 'firestorm', 'meteor'];
  const a = dummy(w, G.x + 2, G.y);
  const b = dummy(w, G.x + 2, G.y + 1);
  const now = Date.now();
  p.targetId = a.id;
  w.spells.cast(p, 'fireball', now);
  assert.ok(a.hp < 100000, 'pocisk trafił');
  assert.ok(a.status.bleedUntil > now, 'podpalenie');
  const bBefore = b.hp;
  w.spells.cast(p, 'firestorm', now);
  assert.ok(b.hp < bBefore, 'obszar trafił drugiego');
  const aBefore = a.hp;
  w.spells.cast(p, 'meteor', now);
  assert.equal(a.hp, aBefore, 'meteor jeszcze nie spadł');
  w.spells.tick(now + 1200);
  assert.ok(a.hp < aBefore, 'meteor spadł');
});

test('lód i nekromancja: zamrożenie, lodowa zbroja, klątwa, wyssanie życia; przyspieszenie', () => {
  const w = new World(new Database(':memory:'));
  const G = zoneSpot(w, 'green');
  const { p } = mk(w, 'Lodowy', G.x, G.y);
  p.pvp.spells = ['frost_nova', 'ice_armor', 'curse', 'drain', 'haste'];
  const m = dummy(w, G.x + 1, G.y);
  const now = Date.now();
  w.spells.cast(p, 'frost_nova', now);
  assert.ok(m.status.stunUntil > now, 'zamrożony');
  w.spells.cast(p, 'ice_armor', now);
  assert.ok(p.status.shieldHp > 0);
  const hp = p.hp;
  w.applyDamage(p, 50, m);
  assert.equal(p.hp, hp, 'tarcza pochłonęła obrażenia');
  p.targetId = m.id;
  w.spells.cast(p, 'curse', now);
  assert.ok(m.status.cursedUntil > now);
  p.hp = 100;
  w.spells.cast(p, 'drain', now + 3000);
  assert.ok(p.hp > 100, 'wyssanie leczy');
  const step = p.stepMs();
  w.spells.cast(p, 'haste', now);
  assert.ok(p.stepMs() < step, 'szybszy krok');
});

test('kostur zwiększa siłę czarów; brak czarów ofensywnych w strefie ochronnej', () => {
  const w = new World(new Database(':memory:'));
  const t = w.map.temple;
  const { p, conn } = mk(w, 'Kapłan', t.x, t.y);
  const base = SpellSystem.staffPower(p);
  p.inventory.equipment.weapon = { item: 'staff_t8', count: 1, q: 5 };
  assert.ok(SpellSystem.staffPower(p) > base + 0.5);
  p.pvp.spells = ['fireball'];
  const m = dummy(w, t.x + 1, t.y);
  p.targetId = m.id;
  w.spells.cast(p, 'fireball', Date.now());
  assert.ok(conn.sys().some((s) => s.includes('strefie ochronnej')));
});
