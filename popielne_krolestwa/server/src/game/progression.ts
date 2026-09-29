/**
 * Formuły rozwoju postaci: doświadczenie, poziomy, skille.
 * Wzorowane na Tibii, uproszczone.
 */
import { SkillName, SKILL_NAMES } from './data/items';

/** Całkowite doświadczenie potrzebne do osiągnięcia poziomu `level` (formuła z Tibii). */
export function expForLevel(level: number): number {
  if (level <= 1) return 0;
  const l = level;
  return Math.round((50 / 3) * (l ** 3 - 6 * l ** 2 + 17 * l - 12));
}

export function levelForExp(exp: number): number {
  let level = 1;
  while (exp >= expForLevel(level + 1)) level++;
  return level;
}

export function maxHpForLevel(level: number): number {
  return 150 + (level - 1) * 12;
}

export function maxMpForLevel(level: number): number {
  return 50 + (level - 1) * 8;
}

/** Prędkość: czas jednego kroku w ms (szybsza z poziomem, jak w Tibii). */
export function stepMsForLevel(level: number): number {
  return Math.max(170, 300 - (level - 1) * 3);
}

export interface SkillState {
  level: number;
  /** Postęp do następnego poziomu skilla. */
  tries: number;
}

export type Skills = Record<SkillName, SkillState>;

export function defaultSkills(): Skills {
  const s = {} as Skills;
  for (const n of SKILL_NAMES) s[n] = { level: n === 'magic' ? 0 : 10, tries: 0 };
  return s;
}

/** Ile „prób” trzeba do następnego poziomu skilla. */
export function triesForNextSkill(name: SkillName, level: number): number {
  if (name === 'magic') return Math.round(60 * 1.3 ** level); // magia – mana wydana
  return Math.round(30 * 1.12 ** (level - 10));
}

/**
 * Dodaje próby do skilla. Zwraca true, jeśli skill awansował.
 */
export function addSkillTries(skills: Skills, name: SkillName, amount: number): boolean {
  const s = skills[name];
  s.tries += amount;
  let advanced = false;
  while (s.tries >= triesForNextSkill(name, s.level)) {
    s.tries -= triesForNextSkill(name, s.level);
    s.level++;
    advanced = true;
  }
  return advanced;
}

/** Procent postępu skilla (do wyświetlenia w kliencie). */
export function skillPercent(name: SkillName, s: SkillState): number {
  return Math.floor((s.tries / triesForNextSkill(name, s.level)) * 100);
}
