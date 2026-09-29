import { test } from 'node:test';
import assert from 'node:assert/strict';
import { expForLevel, levelForExp, defaultSkills, addSkillTries } from '../src/game/progression';
import { Inventory } from '../src/game/inventory';
import { generateWorld } from '../src/game/map';
import { hashPassword, verifyPassword, validateName } from '../src/auth';

test('krzywa doświadczenia jak w Tibii', () => {
  assert.equal(expForLevel(1), 0);
  assert.equal(expForLevel(2), 100);
  assert.equal(expForLevel(3), 200);
  assert.equal(expForLevel(8), 4200);
  assert.equal(levelForExp(99), 1);
  assert.equal(levelForExp(100), 2);
  assert.equal(levelForExp(4200), 8);
});

test('skille rosną od używania', () => {
  const s = defaultSkills();
  assert.equal(s.sword.level, 10);
  let advanced = false;
  for (let i = 0; i < 100 && !advanced; i++) advanced = addSkillTries(s, 'sword', 1);
  assert.ok(advanced);
  assert.equal(s.sword.level, 11);
});

test('plecak łączy stosy i zakłada/zdejmuje ekwipunek', () => {
  const inv = new Inventory();
  assert.equal(inv.add('gold', 150), 0);
  assert.equal(inv.countOf('gold'), 150);
  inv.add('bow_t1');
  inv.add('shield_t1', 1, 3);
  const bowSlot = inv.bag.findIndex((s) => s?.item === 'bow_t1');
  const shieldSlot = inv.bag.findIndex((s) => s?.item === 'shield_t1');
  assert.equal(inv.equipFromBag(shieldSlot), null);
  assert.equal(inv.equipment.shield?.item, 'shield_t1');
  assert.equal(inv.equipment.shield?.q, 3, 'jakość zachowana po założeniu');
  // Łuk jest dwuręczny – tarcza wraca do plecaka.
  assert.equal(inv.equipFromBag(bowSlot), null);
  assert.equal(inv.equipment.weapon?.item, 'bow_t1');
  assert.equal(inv.equipment.shield, undefined);
  assert.equal(inv.countOf('shield_t1', 3), 1);
  assert.equal(inv.unequip('weapon'), null);
  assert.equal(inv.countOf('bow_t1'), 1);
  // Wymagany poziom dla T3.
  inv.add('sword_t3');
  assert.match(inv.equipFromBag(inv.bag.findIndex((s) => s?.item === 'sword_t3'), 5)!, /poziom/);
  // Nie da się założyć mikstury.
  inv.add('hp_potion');
  assert.notEqual(inv.equipFromBag(inv.bag.findIndex((s) => s?.item === 'hp_potion')), null);
});

test('plecak odrzuca nieznane przedmioty z bazy i migruje stare z ETAPU 1', () => {
  const inv = new Inventory(
    [{ item: 'hack', count: 5 }, { item: 'gold', count: 99999 }, { item: 'ash_sword', count: 1 }],
    { weapon: { item: 'rusty_sword', count: 1 } },
  );
  assert.equal(inv.bag[0], null);
  assert.equal(inv.bag[1]?.count, 100);
  assert.deepEqual(inv.bag[2], { item: 'sword_t2', count: 1, q: 3 });
  assert.equal(inv.equipment.weapon?.item, 'sword_t1');
});

test('stosy o różnej jakości się nie łączą', () => {
  const inv = new Inventory();
  inv.add('bars_t1', 10);
  inv.add('bars_t1', 5);
  assert.equal(inv.bag.filter(Boolean).length, 1);
  inv.add('sword_t1', 1, 2);
  inv.add('sword_t1', 1, 2);
  assert.equal(inv.bag.filter(Boolean).length, 3, 'broń się nie łączy');
  assert.ok(inv.remove('bars_t1', 12));
  assert.equal(inv.countOf('bars_t1'), 3);
  assert.equal(inv.remove('bars_t1', 4), false);
});

test('mapa: świątynia jest w strefie ochronnej, spawny są osiągalne', () => {
  const map = generateWorld();
  assert.ok(map.isWalkable(map.temple.x, map.temple.y));
  assert.ok(map.isProtectionZone(map.temple.x, map.temple.y));
  for (const s of map.spawns) {
    assert.ok(map.isWalkable(s.x, s.y), `spawn ${s.monster} @${s.x},${s.y}`);
    assert.ok(!map.isProtectionZone(s.x, s.y));
  }
  // Mur zasłania linię strzału.
  assert.equal(map.hasLineOfSight(36, 42, 40, 42), false);
});

test('hasła: hash + weryfikacja, walidacja nazw', () => {
  const h = hashPassword('sekret');
  assert.ok(verifyPassword('sekret', h));
  assert.ok(!verifyPassword('zle', h));
  assert.equal(validateName('Żółw Bojowy'), null);
  assert.notEqual(validateName('ab'), null);
  assert.notEqual(validateName('<script>'), null);
});
