/**
 * PvP: kto kogo może atakować, czaszki, blokada strefy ochronnej, kara za śmierć
 * (strata doświadczenia, skilli i przedmiotów zależnie od strefy) oraz błogosławieństwa.
 *
 * Reguły (w duchu Tibii + strefy ryzyka z Albionu):
 *  - zielona strefa: brak PvP; śmierć = −5% doświadczenia, przedmioty zostają,
 *  - żółta: PvP; atak na niewinnego = biała czaszka, 3 niesprawiedliwe zabójstwa w 24 h = czerwona;
 *    śmierć = −7% doświadczenia i utrata ok. 30% stosów z plecaka (5 błogosławieństw chroni plecak),
 *  - czerwona: pełne PvP bez czaszek; śmierć = −10% doświadczenia i FULL LOOT (plecak + ekwipunek),
 *  - czerwona czaszka: po śmierci tracisz wszystko w każdej strefie.
 * Każde błogosławieństwo zmniejsza stratę doświadczenia i skilli o 16%; zużywają się po śmierci poza zieloną strefą.
 */
import type { World } from '../world';
import { Player, Skull } from '../entities';
import { ItemStack } from '../inventory';
import { EQUIP_SLOTS, SKILL_NAMES } from '../data/items';
import { triesForNextSkill } from '../progression';
import type { Zone } from '../map';

export const PZ_LOCK_MS = 60_000;
export const AGGRESSION_MS = 60_000;
export const WHITE_SKULL_MS = 15 * 60_000;
export const RED_SKULL_MS = 2 * 60 * 60_000;
export const RED_SKULL_KILLS = 3;
export const UNJUST_WINDOW_MS = 24 * 60 * 60_000;
export const MAX_BLESSINGS = 5;

const ZONE_NAMES: Record<Zone, string> = { green: 'zielonej', yellow: 'żółtej', red: 'czerwonej' };

export interface DeathResult {
  expLost: number;
  dropped: ItemStack[];
  blessingsUsed: number;
}

export class PvpSystem {
  constructor(private world: World) {}

  zoneOf(p: { x: number; y: number }): Zone {
    return this.world.map.zoneAt(p.x, p.y);
  }

  /** Czy `a` może zaatakować gracza `b`? Zwraca komunikat błędu albo null. */
  canAttack(a: Player, b: Player): string | null {
    if (a === b) return 'Nie możesz zaatakować samego siebie.';
    const map = this.world.map;
    if (map.isProtectionZone(a.x, a.y) || map.isProtectionZone(b.x, b.y)) return 'W strefie ochronnej nie można walczyć.';
    if (this.zoneOf(a) === 'green' || this.zoneOf(b) === 'green') return 'W zielonej strefie nie ma walk między graczami.';
    return null;
  }

  /** Atak jest usprawiedliwiony, gdy cel ma czaszkę albo sam niedawno nas zaatakował. */
  isJustified(a: Player, b: Player, now: number): boolean {
    return b.pvp.skull !== '' || (a.aggressors.get(b.id) ?? 0) > now;
  }

  private setSkull(p: Player, skull: Skull, until: number) {
    const was = p.pvp.skull;
    p.pvp.skull = skull;
    p.pvp.skullUntil = Math.max(p.pvp.skullUntil, until);
    if (was !== skull)
      this.world.sendSystem(
        p,
        skull === 'red'
          ? 'Otrzymujesz CZERWONĄ CZASZKĘ! Po śmierci stracisz cały ekwipunek.'
          : 'Otrzymujesz białą czaszkę za atak na niewinnego gracza. Inni mogą cię bezkarnie zaatakować.',
      );
  }

  /** Wywoływane przy każdym trafieniu gracza przez gracza. */
  onAttack(a: Player, b: Player, now: number) {
    a.pzLockUntil = now + PZ_LOCK_MS;
    a.lastCombatAt = now;
    b.lastCombatAt = now;
    if (this.zoneOf(a) === 'yellow' && !this.isJustified(a, b, now) && a.pvp.skull !== 'red')
      this.setSkull(a, 'white', now + WHITE_SKULL_MS);
    b.aggressors.set(a.id, now + AGGRESSION_MS);
  }

  /** Zabójstwo gracza przez gracza (wywoływane przed nałożeniem kary na ofiarę). */
  onKill(killer: Player, victim: Player, justified: boolean, zone: Zone, now: number) {
    this.world.broadcastSystem(`${killer.name} zabił gracza ${victim.name} w ${ZONE_NAMES[zone]} strefie.`);
    if (zone !== 'yellow' || justified) return;
    const k = killer.pvp;
    k.unjustKills = k.unjustKills.filter((t) => now - t < UNJUST_WINDOW_MS);
    k.unjustKills.push(now);
    if (k.unjustKills.length >= RED_SKULL_KILLS) this.setSkull(killer, 'red', now + RED_SKULL_MS);
    else {
      this.setSkull(killer, 'white', now + WHITE_SKULL_MS);
      this.world.sendSystem(killer, `Niesprawiedliwe zabójstwa (24 h): ${k.unjustKills.length}/${RED_SKULL_KILLS}.`);
    }
  }

  /** Kara za śmierć: doświadczenie, skille, przedmioty. Przedmioty trafiają do zwłok na ziemi. */
  applyDeath(victim: Player, zone: Zone): DeathResult {
    const bless = victim.pvp.blessings;
    const redSkull = victim.pvp.skull === 'red';
    let expPct = zone === 'red' ? 0.1 : zone === 'yellow' ? 0.07 : 0.05;
    if (redSkull) expPct = 0.1;
    expPct *= 1 - 0.16 * bless;

    const expLost = Math.floor(victim.exp * expPct);
    victim.exp -= expLost;
    // Skille: część postępu do następnego poziomu przepada.
    for (const n of SKILL_NAMES) {
      const s = victim.skills[n];
      s.tries = Math.max(0, s.tries - Math.floor(triesForNextSkill(n, s.level) * expPct * 2));
    }

    const dropped: ItemStack[] = [];
    const inv = victim.inventory;
    const dropAll = redSkull || zone === 'red';
    if (dropAll) {
      for (let i = 0; i < inv.bag.length; i++) {
        const s = inv.takeFromBag(i);
        if (s) dropped.push(s);
      }
      for (const slot of EQUIP_SLOTS) {
        const s = inv.equipment[slot];
        if (s) {
          dropped.push({ item: s.item, count: s.count, q: s.q ?? 1 });
          delete inv.equipment[slot];
        }
      }
      inv.dirty = true;
    } else if (zone === 'yellow' && bless < MAX_BLESSINGS) {
      for (let i = 0; i < inv.bag.length; i++) {
        if (inv.bag[i] && Math.random() < 0.3) {
          const s = inv.takeFromBag(i);
          if (s) dropped.push(s);
        }
      }
    }
    const used = zone !== 'green' ? bless : 0;
    if (used) victim.pvp.blessings = 0;
    // Śmierć zdejmuje białą czaszkę (czerwona zostaje do wygaśnięcia).
    if (victim.pvp.skull === 'white') {
      victim.pvp.skull = '';
      victim.pvp.skullUntil = 0;
    }
    return { expLost, dropped, blessingsUsed: used };
  }

  /** Wygasanie czaszek (co tick gracza). */
  tick(p: Player, now: number) {
    if (p.pvp.skull && now > p.pvp.skullUntil) {
      p.pvp.skull = '';
      this.world.sendSystem(p, 'Twoja czaszka wygasła.');
    }
    for (const [id, until] of p.aggressors) if (until <= now) p.aggressors.delete(id);
  }

  /** Cena kolejnego błogosławieństwa rośnie z poziomem. */
  static blessingPrice(level: number): number {
    return 100 + level * 20;
  }

  buyBlessing(p: Player): string {
    if (p.pvp.blessings >= MAX_BLESSINGS) return 'Masz już wszystkie pięć błogosławieństw.';
    const price = PvpSystem.blessingPrice(p.level);
    if (p.inventory.countOf('gold') < price) return `Błogosławieństwo kosztuje ${price} zł – nie masz tyle złota.`;
    p.inventory.remove('gold', price);
    p.pvp.blessings++;
    this.world.addFx({ x: p.x, y: p.y, k: 'heal' });
    return `Otrzymujesz błogosławieństwo (${p.pvp.blessings}/${MAX_BLESSINGS}) za ${price} zł. Śmierć będzie mniej bolesna.`;
  }
}
