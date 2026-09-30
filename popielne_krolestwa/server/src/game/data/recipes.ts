/**
 * Receptury rafinacji i rzemiosła. Stacje w mieście obsługują NPC:
 *  - refinery (Rafineria)  – surowiec -> materiał (jak w Albionie: T2+ wymaga materiału o tier niżej),
 *  - forge    (Kuźnia)     – broń metalowa, pancerz płytowy, tarcze, narzędzia,
 *  - workshop (Pracownia)  – łuki, pancerz skórzany i materiałowy.
 */
import {
  ITEMS,
  RESOURCE_KINDS,
  TIERS,
  ResourceKind,
  rawId,
  refinedId,
  gearId,
  GEAR_TEMPLATES,
} from './items';
import { SpecId } from '../specs';

export type Station = 'refinery' | 'forge' | 'workshop';

export const STATION_NAMES: Record<Station, string> = {
  refinery: 'Rafineria',
  forge: 'Kuźnia',
  workshop: 'Pracownia',
};

export interface Recipe {
  id: string;
  station: Station;
  output: string;
  count: number;
  inputs: { item: string; count: number }[];
  /** Specjalizacja rzemieślnicza rozwijana tą recepturą (i wymagana dla tieru). */
  spec: SpecId;
  tier: number;
}

const recipes: Recipe[] = [];

// Rafinacja: T1 = 1 surowiec; T2+ = 2 surowce + 1 materiał tieru niżej.
for (const kind of RESOURCE_KINDS) {
  for (const t of TIERS) {
    const inputs = [{ item: rawId(kind, t), count: t === 1 ? 1 : 2 }];
    if (t > 1) inputs.push({ item: refinedId(kind, t - 1), count: 1 });
    recipes.push({
      id: `refine_${kind}_t${t}`,
      station: 'refinery',
      output: refinedId(kind, t),
      count: 1,
      inputs,
      spec: 'refining',
      tier: t,
    });
  }
}

/** Materiały potrzebne do wykonania przedmiotu (tier materiałów = tier przedmiotu). */
const GEAR_RECIPES: Record<string, { station: Station; mats: [ResourceKind, number][] }> = {
  sword: { station: 'forge', mats: [['ore', 6], ['hide', 2]] },
  axe: { station: 'forge', mats: [['ore', 6], ['wood', 2]] },
  mace: { station: 'forge', mats: [['ore', 6], ['stone', 2]] },
  shield: { station: 'forge', mats: [['wood', 4], ['ore', 2]] },
  plate_head: { station: 'forge', mats: [['ore', 4]] },
  plate_body: { station: 'forge', mats: [['ore', 8]] },
  plate_legs: { station: 'forge', mats: [['ore', 6]] },
  plate_feet: { station: 'forge', mats: [['ore', 4]] },
  woodaxe: { station: 'forge', mats: [['ore', 2], ['wood', 2]] },
  pickaxe: { station: 'forge', mats: [['ore', 2], ['wood', 2]] },
  sickle: { station: 'forge', mats: [['ore', 2], ['wood', 1]] },
  bow: { station: 'workshop', mats: [['wood', 6], ['fiber', 2]] },
  staff: { station: 'workshop', mats: [['wood', 5], ['fiber', 3]] },
  leather_head: { station: 'workshop', mats: [['hide', 4]] },
  leather_body: { station: 'workshop', mats: [['hide', 8]] },
  leather_legs: { station: 'workshop', mats: [['hide', 6]] },
  leather_feet: { station: 'workshop', mats: [['hide', 4]] },
  cloth_head: { station: 'workshop', mats: [['fiber', 4]] },
  cloth_body: { station: 'workshop', mats: [['fiber', 8]] },
  cloth_legs: { station: 'workshop', mats: [['fiber', 6]] },
  cloth_feet: { station: 'workshop', mats: [['fiber', 4]] },
};

for (const g of GEAR_TEMPLATES) {
  const r = GEAR_RECIPES[g.base];
  for (const t of TIERS) {
    recipes.push({
      id: `craft_${g.base}_t${t}`,
      station: r.station,
      output: gearId(g.base, t),
      count: 1,
      inputs: r.mats.map(([kind, n]) => ({ item: refinedId(kind, t), count: n })),
      spec: r.station === 'forge' ? 'smithing' : 'craftsmanship',
      tier: t,
    });
  }
}

export const RECIPES: Record<string, Recipe> = Object.fromEntries(recipes.map((r) => [r.id, r]));
export const RECIPE_LIST = recipes;

// Wartość ekwipunku = koszt materiałów × 1,2 (używana przez NPC i jako orientacja cen).
for (const r of recipes) {
  const out = ITEMS[r.output];
  if (out.value === 0) {
    const cost = r.inputs.reduce((a, i) => a + ITEMS[i.item].value * i.count, 0);
    out.value = Math.round(cost * 1.2);
  }
}
