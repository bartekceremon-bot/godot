#!/usr/bin/env node
/**
 * Eksport contentu Popielnych Królestw (dane serwera MMO) do plików JSON dla wersji idle/clicker.
 * Źródło prawdy o przedmiotach, potworach, czarach, recepturach, zadaniach, NPC i miastach
 * pozostaje w server/src/game/data – ten skrypt tylko je zrzuca (po `npm run build` w server/).
 *
 * Użycie: node tools/export_idle_data.js   ->   client/data/content/*.json
 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const dist = path.join(root, 'server', 'dist', 'src', 'game', 'data');
const out = path.join(root, 'client', 'data', 'content');
fs.mkdirSync(out, { recursive: true });

const items = require(path.join(dist, 'items.js'));
require(path.join(dist, 'recipes.js')); // uzupełnia wartości ekwipunku z receptur
const recipes = require(path.join(dist, 'recipes.js'));
const monsters = require(path.join(dist, 'monsters.js'));
const spells = require(path.join(dist, 'spells.js'));
const quests = require(path.join(dist, 'quests.js'));
const npcs = require(path.join(dist, 'npcs.js'));
const cities = require(path.join(dist, 'cities.js'));

function write(name, data) {
  fs.writeFileSync(path.join(out, name), JSON.stringify(data, null, 1) + '\n');
  console.log(`${name}: ${Array.isArray(data) ? data.length : Object.keys(data).length}`);
}

write('items.json', items.ITEM_LIST);
write('recipes.json', { stations: recipes.STATION_NAMES, list: recipes.RECIPE_LIST });
write('monsters.json', monsters.MONSTER_LIST.map((m) => ({
  id: m.id, name: m.name, look: m.look, tier: m.tier, hp: m.hp, maxDamage: m.maxDamage, exp: m.exp,
  boss: !!m.boss, biomes: m.biomes ?? [], loot: m.loot, poison: m.poison ?? 0, ranged: !!m.ranged,
})));
write('spells.json', { schools: spells.SCHOOL_NAMES, undead: [...spells.UNDEAD], list: spells.SPELL_LIST });
write('quests.json', quests.QUEST_LIST);
write('npcs.json', npcs.NPCS.map((n) => ({ id: n.id, name: n.name, look: n.look, city: n.city, sells: n.sells ?? [], station: n.station ?? '' })));
write('cities.json', cities.CITY_LIST.map((c) => ({ id: c.id, name: c.name, biome: c.biome, bonusText: c.bonusText, npcNames: c.npcNames, mounts: c.mounts })));
