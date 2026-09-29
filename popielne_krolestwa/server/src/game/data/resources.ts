/**
 * Złoża surowców (drzewa, skały, żyły rudy, włókna) rozmieszczone na mapie.
 * Skóry pochodzą z upolowanych zwierząt (patrz monsters.ts).
 */
import { ResourceKind } from './items';

export type NodeKind = Exclude<ResourceKind, 'hide'>;
export const NODE_KINDS: NodeKind[] = ['wood', 'stone', 'ore', 'fiber'];

export const NODE_NAMES: Record<NodeKind, string[]> = {
  wood: ['', 'Brzoza', 'Kasztanowiec', 'Sosna', 'Cedr'],
  stone: ['', 'Głaz wapienny', 'Głaz piaskowca', 'Głaz trawertynu', 'Głaz granitu'],
  ore: ['', 'Żyła miedzi', 'Żyła cyny', 'Żyła żelaza', 'Żyła tytanu'],
  fiber: ['', 'Len', 'Konopie', 'Bawełna', 'Ognista pokrzywa'],
};

/** Liczba jednostek w złożu. */
export function nodeCharges(tier: number): number {
  return 4 + tier;
}

/** Czas odnowienia wyczerpanego złoża (ms). */
export function nodeRespawnMs(tier: number): number {
  return 45_000 + tier * 15_000;
}
