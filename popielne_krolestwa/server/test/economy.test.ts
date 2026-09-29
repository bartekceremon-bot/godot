/**
 * Testy ETAPU 2: zbieractwo, rafinacja, rzemiosło, sklep NPC, depozyt, rynek.
 * Świat działa na bazie w pamięci; gracze mają fałszywe połączenia zbierające wiadomości.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Database } from '../src/db/database';
import { World } from '../src/game/world';
import { Player, Connection } from '../src/game/entities';
import { Inventory } from '../src/game/inventory';
import { defaultSkills } from '../src/game/progression';
import { defaultSpecs } from '../src/game/specs';
import { ITEMS } from '../src/game/data/items';
import { RECIPES } from '../src/game/data/recipes';
import { NPCS } from '../src/game/data/npcs';

class FakeConn implements Connection {
  msgs: any[] = [];
  send(m: object | string) {
    this.msgs.push(typeof m === 'string' ? JSON.parse(m) : m);
  }
  close() {}
  sys() {
    return this.msgs.filter((m) => m.t === 'sys').map((m) => m.text as string);
  }
  last(t: string) {
    return [...this.msgs].reverse().find((m) => m.t === t);
  }
}

let nextChar = 1;
function makePlayer(world: World, name: string, x: number, y: number) {
  const db = world.db;
  const accountId = db.createAccount(name + nextChar++, 'x');
  const charId = db.createCharacter({
    account_id: accountId, name: name + accountId, x, y, level: 1, exp: 0, hp: 150, mp: 50, look: 0,
    skills: JSON.stringify(defaultSkills()), inventory: '{"bag":[],"equipment":{}}', specs: JSON.stringify(defaultSpecs()),
  });
  const conn = new FakeConn();
  const p = new Player({
    charId, name, conn, x, y, hp: 150, mp: 50, exp: 0, look: 0,
    skills: defaultSkills(), specs: defaultSpecs(), inventory: new Inventory(),
  });
  world.addPlayer(p);
  return { p, conn };
}

function npc(world: World, id: string) {
  return [...world.npcs.values()].find((n) => n.def.id === id)!;
}

/** Stawia gracza obok NPC. */
function nextTo(p: Player, world: World, id: string) {
  const n = npc(world, id);
  p.x = n.x;
  p.y = n.y + 1;
  return n;
}

test('dane: receptury T1–T4 i wartości przedmiotów', () => {
  assert.ok(RECIPES.refine_ore_t3);
  assert.deepEqual(RECIPES.refine_ore_t3.inputs, [{ item: 'ore_t3', count: 2 }, { item: 'bars_t2', count: 1 }]);
  assert.ok(RECIPES.craft_sword_t4);
  for (const it of Object.values(ITEMS)) assert.ok(it.value > 0, `wartość ${it.id}`);
  assert.ok(ITEMS.sword_t4.attack! > ITEMS.sword_t1.attack!);
  assert.equal(ITEMS.sword_t3.minLevel, 12);
  // NPC stoją na posadzce miasta.
  const w = new World(new Database(':memory:'));
  for (const n of NPCS) assert.ok(w.map.isWalkable(n.x, n.y), n.id);
});

test('zbieractwo: narzędzie, tier, specjalizacja, wyczerpanie złoża', () => {
  const world = new World(new Database(':memory:'));
  const { p, conn } = makePlayer(world, 'Drwal', 0, 0);
  const node = [...world.nodes.values()].find((n) => n.kind === 'wood' && n.tier === 1)!;
  p.x = node.x + 1;
  p.y = node.y;
  const t0 = 1_000_000;
  world.handle(p, { t: 'gather', id: node.id });
  assert.match(conn.sys().pop()!, /siekiery/);
  p.inventory.add('woodaxe_t1');
  world.handle(p, { t: 'gather', id: node.id });
  assert.ok(p.gathering);
  // Symulujemy upływ czasu aż złoże się wyczerpie.
  for (let t = Date.now(); t < Date.now() + 60_000 && p.gathering; t += 500) world.gathering.tick(p, t + 60_000);
  assert.ok(p.inventory.countOf('wood_t1') >= node.maxCharges());
  assert.ok(node.respawnAt > 0, 'złoże wyczerpane');
  assert.ok(p.specs.lumberjack.fame > 0 || p.specs.lumberjack.level > 1);
  // T3 wymaga wyższej specjalizacji.
  const t3 = [...world.nodes.values()].find((n) => n.kind === 'wood' && n.tier === 3)!;
  p.inventory.add('woodaxe_t3');
  p.x = t3.x + 1;
  p.y = t3.y;
  world.handle(p, { t: 'gather', id: t3.id });
  assert.match(conn.sys().pop()!, /specjalizacji Drwal: 6/);
  void t0;
});

test('rafinacja i rzemiosło przy NPC, jakość i zwrot materiałów', () => {
  const world = new World(new Database(':memory:'));
  const { p, conn } = makePlayer(world, 'Kowal', 0, 0);
  p.inventory.add('ore_t1', 40);
  world.handle(p, { t: 'craft', recipe: 'refine_ore_t1', count: 40 });
  assert.match(conn.sys().pop()!, /stacji/);
  nextTo(p, world, 'refiner');
  world.handle(p, { t: 'craft', recipe: 'refine_ore_t1', count: 40 });
  const bars = p.inventory.countOf('bars_t1');
  assert.ok(bars >= 40, `sztaby ${bars}`);
  // Zwrot 25% w Popielgrodzie – część rudy wraca i też jest przetwarzalna.
  assert.ok(p.inventory.countOf('ore_t1') > 0);
  p.inventory.add('hide_t1', 5);
  world.handle(p, { t: 'craft', recipe: 'refine_hide_t1', count: 5 });

  nextTo(p, world, 'smith');
  world.handle(p, { t: 'craft', recipe: 'craft_sword_t1', count: 1 });
  const sword = p.inventory.bag.find((s) => s?.item === 'sword_t1');
  assert.ok(sword, 'miecz wykuty');
  assert.ok((sword!.q ?? 1) >= 1 && (sword!.q ?? 1) <= 5);
  assert.ok(p.specs.smithing.fame > 0 || p.specs.smithing.level > 1);
  // T2 wymaga poziomu 3 kowalstwa.
  p.inventory.add('bars_t2', 10);
  p.inventory.add('leather_t2', 10);
  world.handle(p, { t: 'craft', recipe: 'craft_sword_t2', count: 1 });
  assert.match(conn.sys().pop()!, /Kowalstwo: 3/);
});

test('NPC: rozmowa słowami kluczowymi, sklep kupno/sprzedaż', () => {
  const world = new World(new Database(':memory:'));
  const { p, conn } = makePlayer(world, 'Klient', 0, 0);
  const trader = nextTo(p, world, 'trader');
  world.handle(p, { t: 'say', text: 'witaj' });
  assert.match(conn.last('npc_dialog').text, /Kupiec|narzędzia|handel/);
  p.lastChatAt = 0;
  world.handle(p, { t: 'say', text: 'handel' });
  assert.ok(conn.last('shop'));
  p.inventory.add('gold', 100);
  world.handle(p, { t: 'shop_buy', item: 'pickaxe_t1', count: 1 });
  assert.equal(p.inventory.countOf('pickaxe_t1'), 1);
  assert.equal(p.inventory.countOf('gold'), 70);
  p.inventory.add('bone', 10);
  world.handle(p, { t: 'shop_sell', slot: p.inventory.bag.findIndex((s) => s?.item === 'bone'), count: 10 });
  assert.equal(p.inventory.countOf('bone'), 0);
  assert.ok(p.inventory.countOf('gold') > 70);
  // Przedmiotu spoza oferty nie da się kupić.
  world.handle(p, { t: 'shop_buy', item: 'sword_t4', count: 1 });
  assert.equal(p.inventory.countOf('sword_t4'), 0);
  void trader;
});

test('depozyt: odkładanie i wyjmowanie, trwałość w bazie', () => {
  const db = new Database(':memory:');
  const world = new World(db);
  const { p } = makePlayer(world, 'Skarbnik', 0, 0);
  nextTo(p, world, 'banker');
  p.inventory.add('stone_t2', 50);
  p.inventory.add('sword_t1', 1, 4);
  world.handle(p, { t: 'depot_put', slot: 0, count: 20 });
  world.handle(p, { t: 'depot_put', slot: 1 });
  assert.equal(p.inventory.countOf('stone_t2'), 30);
  const dep = world.depots.get(p.charId, 'popielgrod');
  assert.deepEqual(dep, [{ item: 'stone_t2', count: 20 }, { item: 'sword_t1', count: 1, q: 4 }]);
  assert.ok(db.loadDepot(p.charId, 'popielgrod')!.includes('sword_t1'));
  world.handle(p, { t: 'depot_take', index: 1 });
  assert.equal(p.inventory.countOf('sword_t1', 4), 1);
  // Daleko od bankiera – brak dostępu.
  p.x = 10;
  world.handle(p, { t: 'depot_take', index: 0 });
  assert.equal(p.inventory.countOf('stone_t2'), 30);
});

test('rynek: zlecenia sprzedaży/kupna, dopasowanie, podatek, anulowanie', () => {
  const db = new Database(':memory:');
  const world = new World(db);
  const { p: seller } = makePlayer(world, 'Sprzedawca', 0, 0);
  const { p: buyer, conn: buyerConn } = makePlayer(world, 'Kupiec', 0, 0);
  nextTo(seller, world, 'market');
  nextTo(buyer, world, 'market');

  // Sprzedawca wystawia 10 desek po 20 zł.
  seller.inventory.add('planks_t1', 10);
  world.handle(seller, { t: 'market_order', side: 'sell', slot: 0, count: 10, price: 20 });
  assert.equal(seller.inventory.countOf('planks_t1'), 0);
  assert.equal(world.market.book('popielgrod').sells[0].amount, 10);

  // Kupujący kupuje natychmiast 4 sztuki.
  buyer.inventory.add('gold', 1000);
  world.handle(buyer, { t: 'market_buy', item: 'planks_t1', q: 1, price: 20, count: 4 });
  assert.equal(buyer.inventory.countOf('planks_t1'), 4);
  assert.equal(buyer.inventory.countOf('gold'), 920);
  // Sprzedawca dostaje złoto do depozytu minus 3% podatku.
  const dep = world.depots.get(seller.charId, 'popielgrod');
  assert.equal(dep.find((s) => s.item === 'gold')!.count, 80 - Math.floor(80 * 0.03));

  // Zlecenie kupna po 25 zł krzyżuje się z ofertą po 20 zł – kupno po 20, zwrot różnicy.
  world.handle(buyer, { t: 'market_order', side: 'buy', item: 'planks_t1', q: 1, count: 8, price: 25 });
  assert.equal(buyer.inventory.countOf('planks_t1'), 10, '6 dokupione od razu');
  // Escrow: 8*25=200, wydane 6*20=120, zwrot 6*5=30 -> 920-200+30 = 750; 2 szt. czekają w księdze.
  assert.equal(buyer.inventory.countOf('gold'), 750);
  assert.equal(world.market.book('popielgrod').buys[0].amount, 2);

  // Sprzedawca sprzedaje do zlecenia kupna – kupujący dostaje towar do depozytu.
  seller.inventory.add('planks_t1', 5);
  world.handle(seller, { t: 'market_sell', slot: 0, count: 5, price: 25 });
  assert.equal(seller.inventory.countOf('planks_t1'), 3);
  assert.equal(world.depots.get(buyer.charId, 'popielgrod').find((s) => s.item === 'planks_t1')!.count, 2);
  assert.ok(buyerConn.sys().some((t) => /Rynek: kupiono/.test(t)));

  // Anulowanie zlecenia zwraca escrow do depozytu.
  seller.inventory.add('bars_t1', 3);
  world.handle(seller, { t: 'market_order', side: 'sell', slot: seller.inventory.bag.findIndex((s) => s?.item === 'bars_t1'), count: 3, price: 50 });
  const order = world.market.mine(seller.charId)[0];
  world.handle(seller, { t: 'market_cancel', id: order.id });
  assert.equal(world.depots.get(seller.charId, 'popielgrod').find((s) => s.item === 'bars_t1')!.count, 3);
  assert.equal(world.market.mine(seller.charId).length, 0);

  // Zlecenia są trwałe – nowy świat na tej samej bazie je wczytuje.
  seller.inventory.add('fiber_t1', 7);
  world.handle(seller, { t: 'market_order', side: 'sell', slot: seller.inventory.bag.findIndex((s) => s?.item === 'fiber_t1'), count: 7, price: 3 });
  const world2 = new World(db);
  assert.equal(world2.market.book('popielgrod').sells.find((r) => r.item === 'fiber_t1')!.amount, 7);
});

test('udźwig: nie podniesiesz więcej niż pozwala capacity', () => {
  const world = new World(new Database(':memory:'));
  const { p } = makePlayer(world, 'Tragarz', 0, 0);
  assert.equal(p.capacity(), 400);
  const max = p.canCarry('stone_t1');
  assert.equal(max, Math.floor(400 / 3));
  p.inventory.add('stone_t1', max);
  assert.equal(p.canCarry('stone_t1'), 0);
});
