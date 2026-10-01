/**
 * Testy ETAPU 4: duży świat z trzema miastami, strefa czarna, tiery T1–T8, wierzchowce,
 * gildie, terytoria, bossowie świata i świątynia domowa.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Database } from '../src/db/database';
import { World, MAP_VERSION } from '../src/game/world';
import { Player, Connection, Monster } from '../src/game/entities';
import { Inventory } from '../src/game/inventory';
import { defaultSkills } from '../src/game/progression';
import { defaultSpecs } from '../src/game/specs';
import { MONSTERS, MONSTER_LIST } from '../src/game/data/monsters';
import { CITY_LIST, cityTemple } from '../src/game/data/cities';
import { ITEMS } from '../src/game/data/items';
import { RECIPES } from '../src/game/data/recipes';
import { CAPTURE_MS } from '../src/game/systems/territories';
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
function mk(world: World, name: string, x: number, y: number, level = 1) {
  const acc = world.db.createAccount(name + ++n, 'x');
  const charId = world.db.createCharacter({
    account_id: acc, name, x, y, level, exp: 0, hp: 150, mp: 50, look: 0,
    skills: JSON.stringify(defaultSkills()), inventory: '{"bag":[],"equipment":{}}', specs: JSON.stringify(defaultSpecs()), pvp: '{}',
  });
  const conn = new FakeConn();
  const p = new Player({ charId, name, conn, x, y, hp: 150, mp: 50, exp: 0, look: 0, skills: defaultSkills(), specs: defaultSpecs(), inventory: new Inventory() });
  p.pvp.mv = MAP_VERSION;
  world.addPlayer(p);
  return { p, conn };
}

const shared = new World(new Database(':memory:'));

test('świat: trzy miasta z kompletem NPC, strefy od zielonej do czarnej', () => {
  const w = shared;
  assert.equal(w.map.width, 224);
  assert.equal(w.map.cities.length, 3);
  for (const c of CITY_LIST) {
    const t = cityTemple(c);
    assert.ok(w.map.isProtectionZone(t.x, t.y), `świątynia ${c.name}`);
    const npcs = [...w.npcs.values()].filter((x) => x.def.city === c.id);
    assert.equal(npcs.length, 9, `NPC w ${c.name}`);
    for (const x of npcs) assert.ok(w.map.isWalkable(x.x, x.y));
  }
  const zones = new Set(w.map.zoneRows().join(''));
  for (const z of ['g', 'y', 'r', 'b']) assert.ok(zones.has(z), `strefa ${z}`);
  assert.equal(w.map.zoneAt(112, 112), 'black');
  assert.equal(w.map.territories.length, 6);
});

test('świat: złoża i potwory we wszystkich tierach T1–T8, bossowie świata', () => {
  const w = shared;
  const tiers = new Set(w.map.nodes.map((x) => x.tier));
  for (let t = 1; t <= 8; t++) assert.ok(tiers.has(t), `złoża T${t}`);
  const bosses = w.map.spawns.filter((s) => s.boss).map((s) => s.monster).sort();
  assert.deepEqual(bosses, ['ash_dragon', 'bog_mother', 'frost_king', 'sand_worm']);
  for (const s of w.map.spawns) assert.ok(MONSTERS[s.monster], s.monster);
  const mtiers = new Set(MONSTER_LIST.map((m) => m.tier));
  for (let t = 1; t <= 8; t++) assert.ok(mtiers.has(t));
  assert.ok(ITEMS.sword_t8 && ITEMS.bars_t8 && RECIPES.craft_plate_body_t8 && RECIPES.refine_ore_t8);
});

test('wierzchowiec: szybszy krok, zsiadanie przy trafieniu', () => {
  const w = new World(new Database(':memory:'));
  const G = zoneSpot(w, 'green');
  const { p, conn } = mk(w, 'Jezdziec', G.x, G.y);
  p.exp = 5000;
  p.level = 9;
  const base = p.stepMs();
  w.handle(p, { t: 'mount' });
  assert.ok(conn.sys().some((t) => /Nie masz wierzchowca/.test(t)));
  p.inventory.add('mount_horse');
  w.handle(p, { t: 'mount' });
  assert.equal(p.mounted, 'mount_horse');
  assert.ok(p.stepMs() < base * 0.8);
  w.applyDamage(p, 1, null);
  assert.equal(p.mounted, '');
});

test('gildie: założenie, zaproszenie, czat, brak ataku na swoich', () => {
  const w = new World(new Database(':memory:'));
  const t = w.map.temple;
  const { p: a, conn: ca } = mk(w, 'Zalozyciel', t.x, t.y);
  const { p: b, conn: cb } = mk(w, 'Rekrut', t.x + 1, t.y);
  a.inventory.add('gold', 6000);
  w.handle(a, { t: 'say', text: '/gildia załóż Strażnicy STR' });
  assert.equal(a.guildTag, 'STR');
  assert.equal(a.inventory.countOf('gold'), 1000);
  a.lastChatAt = 0;
  w.handle(a, { t: 'say', text: '/gildia zaproś Rekrut' });
  b.lastChatAt = 0;
  w.handle(b, { t: 'say', text: '/gildia dołącz' });
  assert.equal(b.guildId, a.guildId);
  a.lastChatAt = 0;
  w.handle(a, { t: 'say', text: '/g Zbiórka przy obelisku!' });
  assert.ok(cb.msgs.some((m) => m.t === 'chat' && m.ch === 'guild' && /Zbiórka/.test(m.text)));
  // W żółtej strefie członkowie gildii nie mogą się atakować.
  const Y = zoneSpot(w, 'yellow');
  a.x = Y.x;
  a.y = Y.y;
  b.x = Y.x + 1;
  b.y = Y.y;
  w.handle(a, { t: 'attack', id: b.id });
  assert.equal(a.targetId, 0);
  assert.ok(ca.sys().some((x) => /członka swojej gildii/.test(x)));
  // Gildia przetrwa restart (zapis w bazie).
  const w2 = new World(w.db);
  assert.equal(w2.guilds.list()[0].tag, 'STR');
});

test('terytoria: gildia przejmuje obelisk po minucie', () => {
  const w = new World(new Database(':memory:'));
  const t = w.map.temple;
  const { p } = mk(w, 'Zdobywca', t.x, t.y);
  p.inventory.add('gold', 5000);
  w.handle(p, { t: 'say', text: '/gildia załóż Ogniste Serca OGN' });
  const terr = w.territories.list[0];
  p.x = terr.spot.x + 2;
  p.y = terr.spot.y;
  const start = Date.now();
  for (let k = 1; k <= CAPTURE_MS / 1000 + 2; k++) w.territories.tick(start + k * 1000);
  assert.equal(terr.owner, p.guildId);
  assert.ok(w.territories.hasBonus(p));
  assert.deepEqual(w.territories.ownedBy(p.guildId), [terr.spot.name]);
});

test('boss: atak obszarowy rani graczy w promieniu, sługi znikają po śmierci bossa', () => {
  const w = new World(new Database(':memory:'));
  const spawnIdx = w.map.spawns.findIndex((s) => s.monster === 'frost_king');
  const boss = [...w.monsters.values()].find((m) => m.def.id === 'frost_king')!;
  assert.ok(boss, 'boss odrodzony przy starcie');
  const { p } = mk(w, 'Smialek', boss.x + 1, boss.y);
  p.hp = 5000;
  const hp = p.hp;
  const now = Date.now();
  (w as any).areaAttack(boss, now);
  assert.ok(p.hp < hp || p.status.slowUntil > now);
  (w as any).summon(boss);
  const minions = [...w.monsters.values()].filter((m) => m.summonerId === boss.id);
  assert.ok(minions.length > 0);
  w.applyDamage(boss, boss.hp + 1, p);
  assert.ok(![...w.monsters.values()].some((m) => m.summonerId === boss.id));
  assert.ok(spawnIdx >= 0);
});

test('świątynia domowa: wejście na posadzkę świątyni zmienia dom, śmierć odradza tam', () => {
  const w = new World(new Database(':memory:'));
  const S = CITY_LIST.find((c) => c.id === 'szronogrod')!;
  const t = cityTemple(S);
  const { p, conn } = mk(w, 'Wedrowiec', t.x, t.y + 1);
  w.handle(p, { t: 'move', d: 0 });
  assert.equal(p.pvp.home, 'szronogrod');
  assert.ok(conn.sys().some((x) => /Szronogród jest teraz twoim domem/.test(x)));
  const R = zoneSpot(w, 'red');
  p.x = R.x;
  p.y = R.y;
  w.applyDamage(p, p.hp + 10, null);
  assert.deepEqual({ x: p.x, y: p.y }, t);
});

test('potwory dystansowe i trucizna', () => {
  const w = new World(new Database(':memory:'));
  const G = zoneSpot(w, 'green');
  const { p } = mk(w, 'Cel', G.x, G.y);
  p.hp = 2000;
  const archer = new Monster({ ...MONSTERS.bandit_archer }, G.x + 3, G.y, 0);
  (w as any).addMonster(archer);
  (w as any).monsterRanged(archer, p, Date.now());
  const scorpion = new Monster({ ...MONSTERS.scorpion, maxDamage: 200 }, G.x + 1, G.y, 0);
  (w as any).monsterAttack(scorpion, p, Date.now());
  assert.ok(p.status.bleedUntil > Date.now(), 'trucizna działa');
});

test('dar bohatera: postać z listy dostaje poziom i komplet T8 tylko raz', () => {
  const w = new World(new Database(':memory:'));
  const t = w.map.temple;
  const { p, conn } = mk(w, 'Sazuqe', t.x, t.y);
  assert.ok(p.level >= 100);
  assert.equal(p.skills.sword.level, 90);
  assert.equal(p.inventory.equipment.weapon?.item, 'sword_t8');
  assert.equal(p.inventory.equipment.weapon?.q, 5);
  assert.equal(p.inventory.equipment.body?.item, 'plate_body_t8');
  assert.equal(p.pvp.blessings, 5);
  assert.equal(p.hp, p.maxHp());
  assert.ok(p.inventory.bag.some((s) => s?.item === 'mount_drake'));
  assert.ok(w.depots.get(p.charId, 'popielgrod').some((s) => s.item === 'gold' && s.count === 90000));
  assert.ok(conn.sys().some((s) => s.startsWith('Dar bohatera')));
  // Drugie logowanie – bez ponownego daru.
  const drakes = p.inventory.bag.filter((s) => s?.item === 'mount_drake').length;
  w.removePlayer(p);
  w.addPlayer(p);
  assert.equal(p.inventory.bag.filter((s) => s?.item === 'mount_drake').length, drakes);
  // Inne postacie nic nie dostają.
  const { p: other } = mk(w, 'Zwykly', t.x, t.y);
  assert.equal(other.level, 1);
  assert.equal(other.inventory.equipment.weapon, undefined);
});
