/**
 * Złoża surowców (drzewa, skały, żyły rudy, włókna) rozmieszczone na mapie.
 * Skóry pochodzą z upolowanych zwierząt (patrz monsters.ts).
 */
import { ResourceKind } from './items';

export type NodeKind = Exclude<ResourceKind, 'hide'>;
export const NODE_KINDS: NodeKind[] = ['wood', 'stone', 'ore', 'fiber'];

export const NODE_NAMES: Record<NodeKind, string[]> = {
  wood: ['', 'Brzoza', 'Kasztanowiec', 'Sosna', 'Cedr', 'Dąb', 'Krwisty buk', 'Widmowy jesion', 'Drzewo żaru'],
  stone: ['', 'Głaz wapienny', 'Głaz piaskowca', 'Głaz trawertynu', 'Głaz granitu', 'Głaz bazaltu', 'Głaz marmuru', 'Blok obsydianu', 'Kamień żaru'],
  ore: ['', 'Żyła miedzi', 'Żyła cyny', 'Żyła żelaza', 'Żyła tytanu', 'Żyła runitu', 'Żyła meteorytu', 'Żyła adamantytu', 'Żyła żarytu'],
  fiber: ['', 'Len', 'Konopie', 'Bawełna', 'Ognista pokrzywa', 'Niebokwiat', 'Bursztynolist', 'Słonecznolen', 'Widmowe konopie'],
};

/** Liczba jednostek w złożu. */
export function nodeCharges(tier: number): number {
  return 4 + tier;
}

/** Czas odnowienia wyczerpanego złoża (ms). */
export function nodeRespawnMs(tier: number): number {
  return 45_000 + tier * 15_000;
}
