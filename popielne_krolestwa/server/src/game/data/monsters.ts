/**
 * Bestiariusz: potwory T1–T8 przypisane do krain (biomów) i czterech bossów świata.
 * Statystyki wynikają z tieru (tabele poniżej) i mnożników konkretnego potwora.
 */
import type { Biome } from './cities';

export interface LootEntry {
  item: string;
  /** Szansa 0..1 */
  chance: number;
  min?: number;
  max?: number;
}

/** Atak dystansowy (łucznik, czarownik, żywiołak). */
export interface RangedAttack {
  range: number;
  maxDamage: number;
  /** Efekt po stronie klienta: 'shot' (strzała), 'bolt' (pocisk magiczny). */
  fx: 'shot' | 'bolt';
  color?: string;
  /** Spowolnienie celu (ms). */
  slowMs?: number;
}

/** Atak obszarowy (bossowie, demony): co everyMs wokół potwora. */
export interface AreaAttack {
  radius: number;
  maxDamage: number;
  everyMs: number;
  /** Nazwa efektu klienta (fire, frost, sand, poison). */
  fx: string;
  slowMs?: number;
  /** Tekst okrzyku nad głową. */
  shout?: string;
}

export interface MonsterDef {
  id: string;
  name: string;
  /** Klucz modelu po stronie klienta. */
  look: string;
  tier: number;
  hp: number;
  /** Maksymalne obrażenia jednego ataku wręcz. */
  maxDamage: number;
  armor: number;
  /** Obrona (szansa na zablokowanie części obrażeń gracza). */
  defense: number;
  /** Czas jednego kroku w ms (mniej = szybszy). */
  stepMs: number;
  attackMs: number;
  exp: number;
  /** Z jakiej odległości zauważa gracza. */
  aggroRange: number;
  /** Czas odrodzenia w ms. */
  respawnMs: number;
  loot: LootEntry[];
  /** Zwierzęta: tier skóry zdobywanej przy oskórowaniu (specjalizacja Oskórowywacz). */
  hideTier?: number;
  /** Trucizna / krwawienie po trafieniu (obrażenia co sekundę przez 5 s). */
  poison?: number;
  ranged?: RangedAttack;
  area?: AreaAttack;
  /** Przywoływanie sług. */
  summon?: { monster: string; count: number; everyMs: number };
  /** Boss świata: komunikaty dla wszystkich, długi respawn, wielki łup. */
  boss?: boolean;
  /** Krainy, w których występuje (puste = każda). */
  biomes?: Biome[];
}

const T_HP = [0, 30, 55, 90, 160, 260, 400, 580, 820];
const T_DMG = [0, 9, 14, 20, 30, 45, 62, 82, 105];
const T_ARMOR = [0, 1, 2, 3, 6, 10, 15, 21, 28];
const T_DEF = [0, 2, 4, 6, 9, 13, 17, 22, 28];
const T_EXP = [0, 10, 20, 32, 70, 130, 220, 340, 520];
const T_GOLD = [0, 4, 6, 10, 25, 45, 80, 130, 200];

interface Spec {
  id: string;
  name: string;
  look?: string;
  tier: number;
  hp?: number;
  dmg?: number;
  armor?: number;
  exp?: number;
  step: number;
  aggro?: number;
  biomes?: Biome[];
  hide?: number;
  loot?: LootEntry[];
  poison?: number;
  ranged?: RangedAttack;
  area?: AreaAttack;
  noGold?: boolean;
}

/** Łup typowy dla tieru: złoto, mikstury, czasem surowce. */
function tierLoot(t: number, extra: LootEntry[] = [], noGold = false): LootEntry[] {
  const out: LootEntry[] = [];
  if (!noGold) out.push({ item: 'gold', chance: 0.75, min: Math.ceil(T_GOLD[t] / 3), max: T_GOLD[t] });
  if (t >= 3) out.push({ item: t >= 5 ? 'great_hp_potion' : 'hp_potion', chance: 0.06 + t * 0.01 });
  if (t >= 4) out.push({ item: t >= 5 ? 'great_mp_potion' : 'mp_potion', chance: 0.05 + t * 0.01 });
  return out.concat(extra);
}

function make(s: Spec): MonsterDef {
  const t = s.tier;
  return {
    id: s.id,
    name: s.name,
    look: s.look ?? s.id,
    tier: t,
    hp: Math.round(T_HP[t] * (s.hp ?? 1)),
    maxDamage: Math.round(T_DMG[t] * (s.dmg ?? 1)),
    armor: Math.round(T_ARMOR[t] * (s.armor ?? 1)),
    defense: T_DEF[t],
    stepMs: s.step,
    attackMs: 2000,
    exp: Math.round(T_EXP[t] * (s.exp ?? 1)),
    aggroRange: s.aggro ?? 6,
    respawnMs: 18_000 + t * 5_000,
    loot: tierLoot(t, s.loot, s.noGold),
    hideTier: s.hide,
    poison: s.poison,
    ranged: s.ranged,
    area: s.area,
    biomes: s.biomes,
  };
}

const MEADOWISH: Biome[] = ['meadow', 'forest', 'mountain'];

const defs: MonsterDef[] = [
  // --- T1–T3: zwierzęta ---
  make({ id: 'rat', name: 'Szczur', tier: 1, hp: 0.85, dmg: 0.9, step: 550, aggro: 5, biomes: ['meadow', 'forest', 'swamp', 'mountain'], hide: 1, loot: [{ item: 'meat', chance: 0.25 }] }),
  make({ id: 'snow_fox', name: 'Śnieżny lis', tier: 1, step: 420, aggro: 5, biomes: ['snow'], hide: 1, loot: [{ item: 'meat', chance: 0.3 }] }),
  make({ id: 'scarab', name: 'Skarabeusz', tier: 1, hp: 1.1, armor: 2, step: 600, aggro: 4, biomes: ['desert'], loot: [{ item: 'stone_t1', chance: 0.3 }] }),
  make({ id: 'boar', name: 'Dzik', tier: 2, hp: 0.85, dmg: 0.95, step: 450, aggro: 4, biomes: MEADOWISH, hide: 2, loot: [{ item: 'meat', chance: 0.6, min: 1, max: 2 }] }),
  make({ id: 'toad', name: 'Ropucha błotna', tier: 2, step: 520, aggro: 4, biomes: ['swamp'], hide: 2, poison: 2, loot: [{ item: 'fiber_t2', chance: 0.3 }] }),
  make({ id: 'scorpion', name: 'Skorpion', tier: 3, dmg: 0.9, armor: 1.4, step: 420, biomes: ['desert'], poison: 3, loot: [{ item: 'ore_t3', chance: 0.2 }] }),
  make({ id: 'wolf', name: 'Wilk', tier: 3, hp: 0.75, dmg: 0.9, step: 380, biomes: MEADOWISH, hide: 3, loot: [{ item: 'meat', chance: 0.4, min: 1, max: 2 }] }),
  make({ id: 'snow_wolf', name: 'Szronowy wilk', tier: 3, step: 360, biomes: ['snow'], hide: 3, loot: [{ item: 'meat', chance: 0.4, min: 1, max: 2 }] }),
  make({ id: 'spider', name: 'Olbrzymi pająk', tier: 3, dmg: 0.85, step: 400, biomes: ['forest', 'swamp'], poison: 3, loot: [{ item: 'fiber_t3', chance: 0.35, min: 1, max: 2 }] }),
  // --- T4–T5 ---
  make({ id: 'bandit', name: 'Rozbójnik', tier: 4, step: 380, biomes: MEADOWISH, loot: [{ item: 'hide_t3', chance: 0.2 }, { item: 'leather_body_t3', chance: 0.03 }] }),
  make({ id: 'bandit_archer', name: 'Łucznik rozbójników', look: 'bandit_archer', tier: 4, hp: 0.8, dmg: 0.6, step: 400, biomes: MEADOWISH, ranged: { range: 5, maxDamage: T_DMG[4], fx: 'shot' }, loot: [{ item: 'wood_t4', chance: 0.25 }, { item: 'bow_t3', chance: 0.03 }] }),
  make({ id: 'bear', name: 'Niedźwiedź', tier: 4, hp: 1.3, dmg: 1.1, step: 460, biomes: ['forest', 'snow', 'mountain'], hide: 5, loot: [{ item: 'meat', chance: 0.8, min: 2, max: 4 }] }),
  make({ id: 'lizard', name: 'Jaszczuroczłek', tier: 4, step: 390, biomes: ['swamp', 'desert'], hide: 4, loot: [{ item: 'fiber_t4', chance: 0.25 }] }),
  make({ id: 'skeleton', name: 'Popielny szkielet', tier: 4, step: 480, biomes: ['ash', 'mountain', 'desert'], noGold: false, loot: [{ item: 'bone', chance: 0.5, min: 1, max: 2 }, { item: 'ore_t4', chance: 0.25, min: 1, max: 2 }] }),
  make({ id: 'orc', name: 'Ork wojownik', tier: 5, step: 400, biomes: MEADOWISH, loot: [{ item: 'ore_t5', chance: 0.25, min: 1, max: 2 }, { item: 'axe_t4', chance: 0.02 }] }),
  make({ id: 'orc_shaman', name: 'Ork szaman', look: 'orc_shaman', tier: 5, hp: 0.8, dmg: 0.5, step: 440, biomes: ['forest', 'mountain'], ranged: { range: 5, maxDamage: T_DMG[5], fx: 'bolt', color: '#7cff5a' }, loot: [{ item: 'fiber_t5', chance: 0.3 }] }),
  make({ id: 'mummy', name: 'Mumia', tier: 5, hp: 1.2, step: 520, biomes: ['desert'], poison: 6, loot: [{ item: 'fiber_t5', chance: 0.35, min: 1, max: 2 }, { item: 'bone', chance: 0.4 }] }),
  make({ id: 'zombie', name: 'Topielec', tier: 5, hp: 1.3, dmg: 0.9, step: 560, biomes: ['swamp'], poison: 5, loot: [{ item: 'wood_t5', chance: 0.3 }] }),
  make({ id: 'troll', name: 'Troll górski', tier: 5, hp: 1.4, dmg: 1.1, step: 470, biomes: ['mountain', 'snow'], loot: [{ item: 'stone_t5', chance: 0.4, min: 1, max: 3 }] }),
  // --- T6–T7 ---
  make({ id: 'hound', name: 'Żarowy ogar', tier: 6, hp: 0.85, step: 330, aggro: 7, biomes: ['ash', 'desert', 'mountain'], hide: 4, loot: [{ item: 'meat', chance: 0.5, min: 1, max: 3 }] }),
  make({ id: 'yeti', name: 'Yeti', tier: 6, hp: 1.3, dmg: 1.1, step: 430, biomes: ['snow'], hide: 6, loot: [{ item: 'meat', chance: 0.7, min: 2, max: 4 }] }),
  make({ id: 'treant', name: 'Pradawny drzewiec', tier: 6, hp: 1.5, armor: 1.3, step: 650, biomes: ['forest', 'swamp'], loot: [{ item: 'wood_t6', chance: 0.5, min: 1, max: 3 }] }),
  make({ id: 'golem', name: 'Kamienny golem', tier: 6, hp: 1.4, armor: 1.5, step: 620, biomes: ['mountain', 'desert'], loot: [{ item: 'stone_t6', chance: 0.5, min: 1, max: 3 }, { item: 'ore_t6', chance: 0.3, min: 1, max: 2 }] }),
  make({ id: 'ice_wraith', name: 'Lodowa zjawa', tier: 7, hp: 0.8, dmg: 0.7, step: 420, biomes: ['snow', 'mountain'], ranged: { range: 5, maxDamage: T_DMG[7], fx: 'bolt', color: '#9fe8ff', slowMs: 2500 }, noGold: false, loot: [{ item: 'fiber_t7', chance: 0.35 }] }),
  make({ id: 'basilisk', name: 'Bazyliszek', tier: 7, hp: 1.2, step: 450, biomes: ['desert', 'swamp'], hide: 7, poison: 10, loot: [] }),
  make({ id: 'fire_elemental', name: 'Żywiołak ognia', tier: 7, hp: 0.9, dmg: 0.6, step: 400, biomes: ['ash'], ranged: { range: 5, maxDamage: T_DMG[7], fx: 'bolt', color: '#ff7a2a' }, loot: [{ item: 'stone_t7', chance: 0.35 }] }),
  make({ id: 'ash_knight', name: 'Popielny rycerz', tier: 7, hp: 1.2, armor: 1.3, step: 440, biomes: ['ash'], loot: [{ item: 'ore_t7', chance: 0.4, min: 1, max: 2 }, { item: 'plate_body_t6', chance: 0.02 }] }),
  // --- T8: Czarna Strefa ---
  make({ id: 'demon', name: 'Demon żaru', tier: 8, hp: 1.3, step: 400, aggro: 7, biomes: ['ash'], area: { radius: 2, maxDamage: 70, everyMs: 7000, fx: 'fire' }, loot: [{ item: 'ore_t8', chance: 0.35, min: 1, max: 2 }, { item: 'stone_t8', chance: 0.3 }] }),
  make({ id: 'ash_champion', name: 'Czempion Popiołu', look: 'ash_knight', tier: 8, armor: 1.3, step: 420, biomes: ['ash'], loot: [{ item: 'wood_t8', chance: 0.3 }, { item: 'fiber_t8', chance: 0.3 }] }),
];

// --- Bossowie świata ---
defs.push(
  {
    id: 'frost_king', name: 'Król Szronu', look: 'frost_king', tier: 7, hp: 12000, maxDamage: 150, armor: 30, defense: 30,
    stepMs: 480, attackMs: 2000, exp: 9000, aggroRange: 8, respawnMs: 30 * 60_000, boss: true, biomes: ['snow'],
    area: { radius: 4, maxDamage: 110, everyMs: 6000, fx: 'frost', slowMs: 3000, shout: 'ZAMARZNIJCIE!' },
    summon: { monster: 'snow_wolf', count: 3, everyMs: 20000 },
    loot: [
      { item: 'gold', chance: 1, min: 2000, max: 4000 }, { item: 'frost_crown', chance: 0.5 },
      { item: 'hide_t6', chance: 1, min: 4, max: 8 }, { item: 'ore_t7', chance: 0.8, min: 3, max: 6 },
      { item: 'plate_head_t7', chance: 0.25 }, { item: 'mount_elk', chance: 0.2 },
    ],
  },
  {
    id: 'sand_worm', name: 'Pustynny Czerw', look: 'sand_worm', tier: 7, hp: 11000, maxDamage: 160, armor: 26, defense: 20,
    stepMs: 500, attackMs: 2000, exp: 8500, aggroRange: 8, respawnMs: 30 * 60_000, boss: true, biomes: ['desert'],
    area: { radius: 3, maxDamage: 120, everyMs: 5500, fx: 'sand', shout: 'Ziemia drży pod stopami!' },
    loot: [
      { item: 'gold', chance: 1, min: 2000, max: 4000 }, { item: 'worm_fang', chance: 1, min: 1, max: 2 },
      { item: 'hide_t7', chance: 1, min: 3, max: 6 }, { item: 'stone_t7', chance: 0.8, min: 3, max: 6 },
      { item: 'bow_t7', chance: 0.2 }, { item: 'mount_camel', chance: 0.2 },
    ],
  },
  {
    id: 'bog_mother', name: 'Matka Moczarów', look: 'bog_mother', tier: 7, hp: 10000, maxDamage: 140, armor: 22, defense: 22,
    stepMs: 560, attackMs: 2000, exp: 8000, aggroRange: 8, respawnMs: 30 * 60_000, boss: true, biomes: ['swamp'], poison: 25,
    area: { radius: 3, maxDamage: 90, everyMs: 6000, fx: 'poison', shout: 'Zgnijcie w bagnie!' },
    summon: { monster: 'toad', count: 4, everyMs: 18000 },
    loot: [
      { item: 'gold', chance: 1, min: 2000, max: 3500 }, { item: 'bog_heart', chance: 0.6 },
      { item: 'fiber_t7', chance: 1, min: 4, max: 8 }, { item: 'wood_t7', chance: 0.8, min: 3, max: 6 },
      { item: 'cloth_body_t7', chance: 0.2 },
    ],
  },
  {
    id: 'ash_dragon', name: 'Żarogniew, Popielny Smok', look: 'ash_dragon', tier: 8, hp: 30000, maxDamage: 200, armor: 36, defense: 34,
    stepMs: 450, attackMs: 2000, exp: 30000, aggroRange: 9, respawnMs: 45 * 60_000, boss: true, biomes: ['ash'],
    area: { radius: 5, maxDamage: 160, everyMs: 5000, fx: 'fire', shout: 'SPŁOŃCIE JAK WASZ ŚWIAT!' },
    summon: { monster: 'fire_elemental', count: 2, everyMs: 25000 },
    loot: [
      { item: 'gold', chance: 1, min: 6000, max: 12000 }, { item: 'dragon_scale', chance: 1, min: 2, max: 5 },
      { item: 'hide_t8', chance: 1, min: 5, max: 10 }, { item: 'ore_t8', chance: 1, min: 4, max: 8 },
      { item: 'sword_t8', chance: 0.15 }, { item: 'plate_body_t8', chance: 0.12 }, { item: 'mount_drake', chance: 0.15 },
    ],
  },
);

export const MONSTERS: Record<string, MonsterDef> = Object.fromEntries(defs.map((d) => [d.id, d]));
export const MONSTER_LIST = defs;

/** Zwykłe potwory pasujące do krainy i tieru (bez bossów). */
export function monstersFor(biome: Biome, tier: number): MonsterDef[] {
  const exact = defs.filter((d) => !d.boss && d.tier === tier && (!d.biomes || d.biomes.includes(biome)));
  if (exact.length) return exact;
  // Brak potwora dokładnie tego tieru w krainie – najbliższy tier.
  for (let dt = 1; dt <= 3; dt++) {
    const near = defs.filter((d) => !d.boss && Math.abs(d.tier - tier) === dt && (!d.biomes || d.biomes.includes(biome)));
    if (near.length) return near;
  }
  return [MONSTERS.rat];
}
