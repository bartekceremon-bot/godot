/**
 * Definicje potworów ETAPU 1 (zielona strefa).
 */

export interface LootEntry {
  item: string;
  /** Szansa 0..1 */
  chance: number;
  min?: number;
  max?: number;
}

export interface MonsterDef {
  id: string;
  name: string;
  /** Klucz grafiki po stronie klienta. */
  look: string;
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
}

const defs: MonsterDef[] = [
  {
    id: 'rat',
    name: 'Szczur',
    look: 'rat',
    hp: 25,
    maxDamage: 8,
    armor: 1,
    defense: 2,
    stepMs: 550,
    attackMs: 2000,
    exp: 10,
    aggroRange: 5,
    respawnMs: 20_000,
    loot: [
      { item: 'gold', chance: 0.6, min: 1, max: 4 },
      { item: 'meat', chance: 0.25 },
    ],
    hideTier: 1,
  },
  {
    id: 'boar',
    name: 'Dzik',
    look: 'boar',
    hp: 45,
    maxDamage: 13,
    armor: 2,
    defense: 4,
    stepMs: 450,
    attackMs: 2000,
    exp: 20,
    aggroRange: 4,
    respawnMs: 25_000,
    loot: [
      { item: 'gold', chance: 0.5, min: 1, max: 6 },
      { item: 'meat', chance: 0.6, min: 1, max: 2 },
    ],
    hideTier: 2,
  },
  {
    id: 'wolf',
    name: 'Wilk',
    look: 'wolf',
    hp: 65,
    maxDamage: 18,
    armor: 3,
    defense: 5,
    stepMs: 380,
    attackMs: 2000,
    exp: 30,
    aggroRange: 6,
    respawnMs: 30_000,
    loot: [
      { item: 'gold', chance: 0.6, min: 2, max: 10 },
      { item: 'meat', chance: 0.4, min: 1, max: 2 },
    ],
    hideTier: 3,
  },
  {
    id: 'skeleton',
    name: 'Popielny szkielet',
    look: 'skeleton',
    hp: 130,
    maxDamage: 32,
    armor: 6,
    defense: 10,
    stepMs: 480,
    attackMs: 2000,
    exp: 75,
    aggroRange: 6,
    respawnMs: 45_000,
    loot: [
      { item: 'gold', chance: 0.85, min: 5, max: 25 },
      { item: 'bone', chance: 0.5, min: 1, max: 2 },
      { item: 'hp_potion', chance: 0.12 },
      { item: 'ore_t3', chance: 0.25, min: 1, max: 3 },
      { item: 'stone_t3', chance: 0.2, min: 1, max: 3 },
    ],
  },
  {
    id: 'hound',
    name: 'Żarowy ogar',
    look: 'hound',
    hp: 170,
    maxDamage: 38,
    armor: 7,
    defense: 8,
    stepMs: 330,
    attackMs: 2000,
    exp: 110,
    aggroRange: 7,
    respawnMs: 50_000,
    loot: [
      { item: 'gold', chance: 0.8, min: 8, max: 30 },
      { item: 'meat', chance: 0.5, min: 1, max: 3 },
      { item: 'mp_potion', chance: 0.1 },
    ],
    hideTier: 4,
  },
];

export const MONSTERS: Record<string, MonsterDef> = Object.fromEntries(defs.map((d) => [d.id, d]));
