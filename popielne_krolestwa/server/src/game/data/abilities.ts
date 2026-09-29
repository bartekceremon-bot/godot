/**
 * Umiejętności broni (jak w Albionie: brak klas – to broń w ręku daje 3 aktywne umiejętności).
 * Klient pokazuje na pasku akcji umiejętności założonej broni; serwer liczy wszystko sam.
 */

export type WeaponKind = 'sword' | 'axe' | 'mace' | 'bow';

export type AbilityEffect =
  | 'strike' // mocniejszy cios w cel
  | 'bleed' // cios + krwawienie (obrażenia co sekundę)
  | 'parry' // obrona: połowa obrażeń wręcz przez czas trwania
  | 'whirl' // cios we wszystkich wrogów wokół
  | 'frenzy' // szybsze ataki przez czas trwania
  | 'stun' // cios + ogłuszenie (cel nie rusza się i nie atakuje)
  | 'crush' // cios ignorujący pancerz
  | 'ironskin' // premia do pancerza przez czas trwania
  | 'slow' // cios + spowolnienie celu
  | 'volley'; // obrażenia w celu i polach wokół niego

export interface AbilityDef {
  id: string;
  name: string;
  weapon: WeaponKind;
  /** Pozycja na pasku (1–3). */
  slot: number;
  effect: AbilityEffect;
  mana: number;
  cooldownMs: number;
  /** Zasięg w kafelkach (0 = na siebie). */
  range: number;
  /** Mnożnik obrażeń względem zwykłego ataku. */
  power: number;
  /** Czas trwania efektu (ms). */
  durationMs?: number;
  /** Klucz ikony po stronie klienta. */
  icon: string;
  description: string;
}

const defs: AbilityDef[] = [
  // Miecz – wszechstronny: mocny cios, krwawienie, parowanie.
  { id: 'sword_cleave', name: 'Potężne cięcie', weapon: 'sword', slot: 1, effect: 'strike', mana: 10, cooldownMs: 6000, range: 1, power: 1.8, icon: 'sword', description: 'Cios za 180% obrażeń.' },
  { id: 'sword_rend', name: 'Rozpłatanie', weapon: 'sword', slot: 2, effect: 'bleed', mana: 12, cooldownMs: 10000, range: 1, power: 1.0, durationMs: 5000, icon: 'sword', description: 'Cios i krwawienie przez 5 s.' },
  { id: 'sword_parry', name: 'Parowanie', weapon: 'sword', slot: 3, effect: 'parry', mana: 8, cooldownMs: 12000, range: 0, power: 0, durationMs: 4000, icon: 'shield', description: 'Przez 4 s otrzymujesz połowę obrażeń wręcz.' },
  // Topór – obrażenia: potężne rąbnięcie, wir, szał.
  { id: 'axe_chop', name: 'Rąbnięcie', weapon: 'axe', slot: 1, effect: 'strike', mana: 12, cooldownMs: 8000, range: 1, power: 2.2, icon: 'axe', description: 'Cios za 220% obrażeń.' },
  { id: 'axe_whirl', name: 'Wir', weapon: 'axe', slot: 2, effect: 'whirl', mana: 15, cooldownMs: 10000, range: 1, power: 1.2, icon: 'axe', description: 'Trafia wszystkich wrogów wokół (120%).' },
  { id: 'axe_frenzy', name: 'Szał', weapon: 'axe', slot: 3, effect: 'frenzy', mana: 12, cooldownMs: 18000, range: 0, power: 0, durationMs: 6000, icon: 'axe', description: 'Przez 6 s atakujesz znacznie szybciej.' },
  // Buława – kontrola: ogłuszenie, miażdżenie pancerza, żelazna skóra.
  { id: 'mace_stun', name: 'Ogłuszenie', weapon: 'mace', slot: 1, effect: 'stun', mana: 14, cooldownMs: 12000, range: 1, power: 1.0, durationMs: 1500, icon: 'club', description: 'Cios i ogłuszenie na 1,5 s.' },
  { id: 'mace_crush', name: 'Miażdżenie', weapon: 'mace', slot: 2, effect: 'crush', mana: 10, cooldownMs: 7000, range: 1, power: 1.5, icon: 'club', description: 'Cios za 150% ignorujący pancerz.' },
  { id: 'mace_ironskin', name: 'Żelazna skóra', weapon: 'mace', slot: 3, effect: 'ironskin', mana: 10, cooldownMs: 16000, range: 0, power: 6, durationMs: 8000, icon: 'plate_body', description: 'Przez 8 s +6 pancerza.' },
  // Łuk – dystans: celny strzał, spowolnienie, deszcz strzał.
  { id: 'bow_aimed', name: 'Celny strzał', weapon: 'bow', slot: 1, effect: 'strike', mana: 10, cooldownMs: 7000, range: 7, power: 2.0, icon: 'bow', description: 'Strzał za 200% obrażeń (zasięg 7).' },
  { id: 'bow_slow', name: 'Strzała spowalniająca', weapon: 'bow', slot: 2, effect: 'slow', mana: 10, cooldownMs: 10000, range: 6, power: 1.0, durationMs: 5000, icon: 'bow', description: 'Strzał i spowolnienie celu na 5 s.' },
  { id: 'bow_volley', name: 'Deszcz strzał', weapon: 'bow', slot: 3, effect: 'volley', mana: 16, cooldownMs: 12000, range: 6, power: 1.0, icon: 'bow', description: 'Obrażenia w celu i wszystkich wokół niego.' },
];

export const ABILITIES: Record<string, AbilityDef> = Object.fromEntries(defs.map((d) => [d.id, d]));
export const ABILITY_LIST = defs;

/** Rodzaj broni z id przedmiotu (np. "sword_t3" -> "sword"). */
export function weaponKind(itemId: string | undefined): WeaponKind | null {
  if (!itemId) return null;
  const k = itemId.split('_')[0];
  return k === 'sword' || k === 'axe' || k === 'mace' || k === 'bow' ? k : null;
}

export function abilityFor(kind: WeaponKind, slot: number): AbilityDef | undefined {
  return defs.find((d) => d.weapon === kind && d.slot === slot);
}
