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
      { item: 'wolf_pelt', chance: 0.35 },
      { item: 'meat', chance: 0.4, min: 1, max: 2 },
    ],
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
      { item: 'bone', chance: 0.5 },
      { item: 'hp_potion', chance: 0.12 },
      { item: 'hatchet', chance: 0.07 },
      { item: 'club', chance: 0.07 },
      { item: 'leather_helmet', chance: 0.08 },
      { item: 'leather_legs', chance: 0.08 },
      { item: 'leather_boots', chance: 0.08 },
      { item: 'chain_armor', chance: 0.04 },
      { item: 'ash_sword', chance: 0.03 },
    ],
  },
];

export const MONSTERS: Record<string, MonsterDef> = Object.fromEntries(defs.map((d) => [d.id, d]));
