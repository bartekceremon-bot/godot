/**
 * Formuły walki (uproszczone, w duchu Tibii). Wszystkie liczone na serwerze.
 */
import { randInt, chance } from '../util/rng';

/**
 * Maksymalne obrażenia ataku gracza bronią.
 * Rosną z atakiem broni, poziomem skilla i poziomem postaci.
 */
export function playerMaxDamage(weaponAttack: number, skill: number, level: number): number {
  return Math.floor(weaponAttack * (0.6 + skill * 0.06) + level / 4);
}

/** Obrażenia ataku bez broni (pięści). */
export const FIST_ATTACK = 5;

/**
 * Wynik trafienia po uwzględnieniu obrony i pancerza celu.
 * Zwraca 0 gdy atak zablokowany.
 */
export function rollDamage(maxDamage: number, armor: number, defense: number): number {
  let dmg = randInt(Math.floor(maxDamage * 0.3), maxDamage);
  // Obrona: szansa na zablokowanie części ciosu.
  if (defense > 0 && chance(0.3)) dmg -= randInt(0, defense);
  // Pancerz: zawsze redukuje część obrażeń.
  if (armor > 0) dmg -= randInt(Math.floor(armor / 2), armor);
  return Math.max(0, dmg);
}

/** Szansa trafienia z łuku maleje z odległością i rośnie ze skillem. */
export function distanceHitChance(skill: number, distance: number): number {
  return Math.min(0.95, 0.55 + skill * 0.015 - distance * 0.03);
}

/** Obrona gracza: tarcza + broń, skalowane skillem tarczy. */
export function playerDefense(shieldDefense: number, weaponDefense: number, shielding: number): number {
  const base = shieldDefense > 0 ? shieldDefense : weaponDefense * 0.5;
  return Math.floor(base * (0.4 + shielding * 0.03));
}

/** Odległość „szachowa” (Czebyszewa) – tak liczy się zasięg na siatce. */
export function chebyshev(ax: number, ay: number, bx: number, by: number): number {
  return Math.max(Math.abs(ax - bx), Math.abs(ay - by));
}
