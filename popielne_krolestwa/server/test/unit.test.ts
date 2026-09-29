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
  inv.add('hunting_bow');
  inv.add('wooden_shield');
  const bowSlot = inv.bag.findIndex((s) => s?.item === 'hunting_bow');
  const shieldSlot = inv.bag.findIndex((s) => s?.item === 'wooden_shield');
  assert.equal(inv.equipFromBag(shieldSlot), null);
  assert.equal(inv.equipment.shield?.item, 'wooden_shield');
  // Łuk jest dwuręczny – tarcza wraca do plecaka.
  assert.equal(inv.equipFromBag(bowSlot), null);
  assert.equal(inv.equipment.weapon?.item, 'hunting_bow');
  assert.equal(inv.equipment.shield, undefined);
  assert.equal(inv.countOf('wooden_shield'), 1);
  assert.equal(inv.unequip('weapon'), null);
  assert.equal(inv.countOf('hunting_bow'), 1);
  // Nie da się założyć mikstury.
  inv.add('hp_potion');
  assert.notEqual(inv.equipFromBag(inv.bag.findIndex((s) => s?.item === 'hp_potion')), null);
});

test('plecak odrzuca nieznane przedmioty z bazy', () => {
  const inv = new Inventory([{ item: 'hack', count: 5 }, { item: 'gold', count: 99999 }]);
  assert.equal(inv.bag[0], null);
  assert.equal(inv.bag[1]?.count, 100);
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
