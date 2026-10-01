/**
 * Drzewko specjalizacji (w stylu „destiny board” z Albionu, uproszczone).
 *
 * Każda specjalizacja ma poziom rosnący od sławy (fame) zdobywanej przez
 * zbieranie lub wytwarzanie. Poziom:
 *  - odblokowuje kolejne tiery (T2 od poz. 3, T3 od 6, T4 od 10 … T8 od 36),
 *  - zbieractwo: szansa na dodatkową sztukę i szybsze zbieranie,
 *  - rzemiosło: wyższa szansa na lepszą jakość przedmiotu.
 */
import { ResourceKind, QUALITY_NAMES } from './data/items';
import { chance } from '../util/rng';

export type SpecId =
  | 'lumberjack'
  | 'quarrier'
  | 'miner'
  | 'harvester'
  | 'skinner'
  | 'refining'
  | 'smithing'
  | 'craftsmanship';

export interface SpecDef {
  id: SpecId;
  name: string;
  group: 'gathering' | 'crafting';
  description: string;
}

export const SPEC_DEFS: SpecDef[] = [
  { id: 'lumberjack', name: 'Drwal', group: 'gathering', description: 'Ścinanie drzew (siekiera drwala).' },
  { id: 'quarrier', name: 'Kamieniarz', group: 'gathering', description: 'Wydobywanie kamienia (kilof).' },
  { id: 'miner', name: 'Górnik', group: 'gathering', description: 'Wydobywanie rudy (kilof).' },
  { id: 'harvester', name: 'Zbieracz', group: 'gathering', description: 'Zbieranie włókien (sierp).' },
  { id: 'skinner', name: 'Oskórowywacz', group: 'gathering', description: 'Skóry z upolowanych zwierząt.' },
  { id: 'refining', name: 'Rafinacja', group: 'crafting', description: 'Przetwarzanie surowców w materiały.' },
  { id: 'smithing', name: 'Kowalstwo', group: 'crafting', description: 'Broń, zbroje płytowe, tarcze, narzędzia.' },
  { id: 'craftsmanship', name: 'Rzemiosło', group: 'crafting', description: 'Łuki, pancerze skórzane i materiałowe.' },
];

export const GATHER_SPEC: Record<ResourceKind, SpecId> = {
  wood: 'lumberjack',
  stone: 'quarrier',
  ore: 'miner',
  fiber: 'harvester',
  hide: 'skinner',
};

/** Wymagany poziom specjalizacji dla tieru (indeks = tier). */
export const TIER_SPEC_REQ = [0, 1, 3, 6, 10, 15, 21, 28, 36];

export interface SpecState {
  level: number;
  fame: number;
}

export type Specs = Record<SpecId, SpecState>;

export function defaultSpecs(): Specs {
  const s = {} as Specs;
  for (const d of SPEC_DEFS) s[d.id] = { level: 1, fame: 0 };
  return s;
}

/** Wczytanie z bazy – brakujące specjalizacje uzupełniane domyślnymi. */
export function loadSpecs(json: unknown): Specs {
  const s = defaultSpecs();
  if (json && typeof json === 'object')
    for (const d of SPEC_DEFS) {
      const v = (json as Record<string, SpecState>)[d.id];
      if (v && Number.isFinite(v.level) && Number.isFinite(v.fame))
        s[d.id] = { level: Math.max(1, Math.floor(v.level)), fame: Math.max(0, Math.floor(v.fame)) };
    }
  return s;
}

export function fameForNextLevel(level: number): number {
  return Math.round(40 * 1.35 ** (level - 1));
}

/** Sława za jedną jednostkę surowca/materiału danego tieru. */
export function fameForTier(tier: number): number {
  return 4 * 2 ** (tier - 1);
}

/** Dodaje sławę. Zwraca true, jeśli poziom wzrósł. */
export function addFame(specs: Specs, id: SpecId, fame: number): boolean {
  const s = specs[id];
  s.fame += fame;
  let up = false;
  while (s.fame >= fameForNextLevel(s.level)) {
    s.fame -= fameForNextLevel(s.level);
    s.level++;
    up = true;
  }
  return up;
}

export function canUseTier(specs: Specs, id: SpecId, tier: number): boolean {
  return specs[id].level >= TIER_SPEC_REQ[tier];
}

/** Czas zbierania jednej jednostki (ms) – krótszy z poziomem. */
export function gatherTimeMs(level: number, tier: number): number {
  return Math.max(900, 1600 + tier * 200 - level * 40);
}

/** Szansa na dodatkową jednostkę przy zbieraniu. */
export function bonusYieldChance(level: number): number {
  return Math.min(0.5, level * 0.02);
}

/**
 * Losowanie jakości wytworzonego przedmiotu (1–5).
 * bonus = o ile poziom specjalizacji przewyższa wymaganie tieru (+ premia miasta).
 */
export function rollQuality(bonus: number): number {
  const b = Math.max(0, bonus);
  const p5 = Math.min(0.05, 0.005 + 0.001 * b);
  const p4 = Math.min(0.12, 0.025 + 0.004 * b);
  const p3 = Math.min(0.2, 0.07 + 0.01 * b);
  const p2 = Math.min(0.35, 0.2 + 0.015 * b);
  const r = Math.random();
  if (r < p5) return 5;
  if (r < p5 + p4) return 4;
  if (r < p5 + p4 + p3) return 3;
  if (r < p5 + p4 + p3 + p2) return 2;
  return 1;
}

export function qualityName(q: number): string {
  return QUALITY_NAMES[q] ?? '';
}

/** Zwrot części materiałów (jak „resource return rate” w Albionie). */
export function returnedAmount(used: number, rate: number): number {
  let n = Math.floor(used * rate);
  if (chance(used * rate - n)) n++;
  return n;
}
