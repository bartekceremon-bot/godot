/**
 * Testy zadań: oferta u NPC, przyjęcie, postęp zabójstw i zbierania, odwiedzenie miejsca,
 * oddanie z nagrodą, kolejność (after), zapis stanu.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Database } from '../src/db/database';
import { World, MAP_VERSION } from '../src/game/world';
import { Player, Connection, Monster, loadPvp } from '../src/game/entities';
import { Inventory } from '../src/game/inventory';
import { defaultSkills } from '../src/game/progression';
import { defaultSpecs } from '../src/game/specs';
import { MONSTERS } from '../src/game/data/monsters';
import { QUESTS, QUEST_LIST } from '../src/game/data/quests';
import { ITEMS } from '../src/game/data/items';
import { CITY_LIST, cityTemple } from '../src/game/data/cities';

class FakeConn implements Connection {
  msgs: any[] = [];
  send(m: object | string) {
    this.msgs.push(typeof m === 'string' ? JSON.parse(m) : m);
  }
  close() {}
  last(t: string) {
    return [...this.msgs].reverse().find((m) => m.t === t);
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
  return { p, conn };
}

function npc(w: World, city: string, role: string) {
  return [...w.npcs.values()].find((x) => x.def.city === city && (x.def.id === role || x.def.id === `${city}_${role}`))!;
}

test('dane zadań: potwory i przedmioty istnieją, każde miasto ma zadania', () => {
  for (const q of QUEST_LIST)
    for (const g of q.goals) {
      if (g.kind === 'kill') assert.ok(MONSTERS[g.monster], `${q.id}: ${g.monster}`);
      if (g.kind === 'gather') assert.ok(ITEMS[g.item], `${q.id}: ${g.item}`);
      if (q.after) assert.ok(QUESTS[q.after]);
    }
  for (const c of CITY_LIST) assert.ok(QUEST_LIST.filter((q) => q.city === c.id).length >= 5);
});

test('zadanie łowieckie: oferta, przyjęcie, zabójstwa, nagroda i kolejne w łańcuchu', () => {
  const w = new World(new Database(':memory:'));
  const g = npc(w, 'popielgrod', 'guild');
  const { p, conn } = mk(w, 'Łowca', g.x, g.y + 1);
  w.handle(p, { t: 'npc', id: g.id, word: 'zadanie' });
  const offer = conn.last('quests');
  assert.ok(offer.list.some((q: any) => q.id === 'pop_rats' && q.state === 'available'));
  assert.ok(offer.list.some((q: any) => q.id === 'pop_wolves' && q.state === 'locked'));
  w.quests.accept(p, 'pop_rats');
  assert.ok(conn.last('qlog').list.some((q: any) => q.id === 'pop_rats'));
  for (let i = 0; i < 10; i++) {
    const rat = new Monster({ ...MONSTERS.rat }, g.x + 3, g.y + 3, 0);
    w.monsters.set(rat.id, rat);
    w.applyDamage(rat, 9999, p);
  }
  assert.equal(conn.last('qlog').list[0].ready, true);
  const exp = p.exp;
  w.quests.turnIn(p, 'pop_rats');
  assert.ok(p.exp > exp);
  assert.equal(p.inventory.countOf('gold'), 150);
  assert.ok(p.pvp.quests!.done.includes('pop_rats'));
  p.level = 6;
  w.quests.accept(p, 'pop_wolves');
  assert.ok(p.pvp.quests!.active.pop_wolves, 'odblokowane kolejne zadanie');
  // Zapis i odczyt stanu.
  const loaded = loadPvp(JSON.stringify(p.pvp));
  assert.deepEqual(loaded.quests!.done, ['pop_rats']);
});

test('zadanie zbierackie i wyprawa do innego miasta', () => {
  const w = new World(new Database(':memory:'));
  const c = npc(w, 'popielgrod', 'crafter');
  const { p } = mk(w, 'Zbieracz', c.x, c.y - 1);
  w.quests.accept(p, 'pop_wood');
  p.inventory.add('wood_t2', 20);
  w.quests.turnIn(p, 'pop_wood');
  assert.equal(p.inventory.countOf('wood_t2'), 0, 'surowce oddane');
  assert.ok(p.pvp.quests!.done.includes('pop_wood'));
  const pr = npc(w, 'popielgrod', 'priest');
  p.x = pr.x;
  p.y = pr.y + 1;
  p.level = 10;
  w.quests.accept(p, 'pop_messenger');
  const t = cityTemple(CITY_LIST.find((x) => x.id === 'szronogrod')!);
  p.x = t.x;
  p.y = t.y;
  w.quests.tick(Date.now() + 5000);
  const prog = p.pvp.quests!.active.pop_messenger;
  assert.equal(prog[0], 1, 'miejsce odwiedzone');
  w.quests.turnIn(p, 'pop_messenger');
  assert.ok(p.pvp.quests!.active.pop_messenger, 'nagrodę odbiera się u zleceniodawcy');
  p.x = pr.x;
  p.y = pr.y + 1;
  w.quests.turnIn(p, 'pop_messenger');
  assert.ok(p.pvp.quests!.done.includes('pop_messenger'));
});
