/**
 * Czary. Wywoływane przyciskiem z paska szybkiego dostępu albo formułą wpisaną w czacie.
 */
export interface SpellDef {
  id: string;
  name: string;
  /** Formuła wpisywana w czacie (jak w Tibii). */
  words: string;
  mana: number;
  cooldownMs: number;
  minLevel: number;
  /** Klucz ikony po stronie klienta. */
  icon: string;
}

const defs: SpellDef[] = [
  { id: 'heal', name: 'Leczenie', words: 'exura', mana: 20, cooldownMs: 1000, minLevel: 1, icon: 'spell_heal' },
];

export const SPELLS: Record<string, SpellDef> = Object.fromEntries(defs.map((d) => [d.id, d]));
export const SPELL_LIST = defs;

export function findSpellByWords(text: string): SpellDef | undefined {
  const w = text.trim().toLowerCase();
  return defs.find((s) => s.words === w);
}

/** Ile HP przywraca „exura” – rośnie z poziomem i poziomem magii. */
export function healAmount(level: number, magicLevel: number): { min: number; max: number } {
  const base = level * 0.2 + magicLevel * 3;
  return { min: Math.floor(base + 20), max: Math.floor(base * 1.5 + 40) };
}
