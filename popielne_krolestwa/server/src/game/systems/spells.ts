/**
 * Magia: rzucanie czarów pięciu szkół, efekty obszarowe i opóźnione (meteor, nawałnica, obłok),
 * nauka czarów u kapłanów (słowo „czary”). Wszystko liczy serwer – klient pokazuje efekty
 * (fx `sp` z id czaru, celem i trafionymi polami).
 */
import type { World, Target } from '../world';
import { Monster, Player } from '../entities';
import { SPELLS, SpellDef, CITY_SCHOOLS, SCHOOL_NAMES, healAmount, spellDamage, UNDEAD } from '../data/spells';
import { addSkillTries } from '../progression';
import { chebyshev } from '../combat';
import { QUALITY_MULT, getItem } from '../data/items';
import { randInt } from '../../util/rng';

interface Pending {
  at: number;
  run: () => void;
}

export class SpellSystem {
  private pending: Pending[] = [];

  constructor(private world: World) {}

  static knows(p: Player, id: string): boolean {
    return id === 'heal' || (p.pvp.spells ?? []).includes(id);
  }

  /** Mnożnik czarów z kostura w ręku (z jakością). */
  static staffPower(p: Player): number {
    const w = p.inventory.equipment.weapon;
    const def = w ? getItem(w.item) : undefined;
    return 1 + (def?.spellPower ?? 0) * QUALITY_MULT[w?.q ?? 1];
  }

  cast(p: Player, spellId: string, now: number) {
    const w = this.world;
    const spell = SPELLS[spellId];
    if (!spell) return;
    if (!SpellSystem.knows(p, spell.id)) return w.sendSystem(p, `Nie znasz czaru „${spell.name}”. Naucz się go u kapłana.`);
    if ((p.spellCooldowns[spell.id] ?? 0) > now) return;
    if (p.status.stunned(now)) return w.sendSystem(p, 'Jesteś ogłuszony!');
    if (p.level < spell.minLevel) return w.sendSystem(p, `Potrzebujesz poziomu ${spell.minLevel}.`);
    if (p.skills.magic.level < spell.minMagic) return w.sendSystem(p, `Potrzebujesz poziomu magii ${spell.minMagic}.`);
    const offensive = !['heal', 'heal_area', 'purify', 'shield', 'haste'].includes(spell.effect);
    if (offensive && w.map.isProtectionZone(p.x, p.y)) return w.sendSystem(p, 'W strefie ochronnej nie można walczyć.');

    let target: Target | undefined;
    if (spell.range > 0) {
      target = w.getTarget(p.targetId);
      if (!target || target === p) return w.sendSystem(p, 'Najpierw wybierz cel (dotknij potwora lub gracza).');
      if (chebyshev(p.x, p.y, target.x, target.y) > spell.range) return w.sendSystem(p, 'Cel jest za daleko.');
      if (!w.map.hasLineOfSight(p.x, p.y, target.x, target.y)) return w.sendSystem(p, 'Nie widzisz celu.');
      if (target instanceof Player) {
        const err = w.pvp.canAttack(p, target);
        if (err) return w.sendSystem(p, err);
      }
    }
    if (p.mp < spell.mana) {
      w.addFx({ x: p.x, y: p.y, k: 'puff' });
      return w.sendSystem(p, 'Za mało many.');
    }
    p.mp -= spell.mana;
    p.spellCooldowns[spell.id] = now + spell.cooldownMs;
    p.send({ t: 'cd', id: spell.id, ms: spell.cooldownMs });
    if (addSkillTries(p.skills, 'magic', spell.mana)) w.announceSkill(p, 'magic');
    if (offensive) p.lastCombatAt = now;
    w.addFx({ x: p.x, y: p.y, k: 'words', id: p.id, text: spell.words });
    this.apply(p, spell, target, now);
  }

  private maxDamage(p: Player, spell: SpellDef): number {
    return spellDamage(p.level, p.skills.magic.level) * spell.power * SpellSystem.staffPower(p);
  }

  private apply(p: Player, spell: SpellDef, target: Target | undefined, now: number) {
    const w = this.world;
    const fx = (extra: Record<string, unknown>) => w.addFx({ x: p.x, y: p.y, k: 'sp', s: spell.id, id: p.id, ...extra });
    const max = this.maxDamage(p, spell);
    const dur = spell.durationMs ?? 0;
    switch (spell.effect) {
      case 'heal': {
        const { min, max: hmax } = healAmount(p.level, p.skills.magic.level);
        const k = spell.power * SpellSystem.staffPower(p);
        this.heal(p, randInt(Math.round(min * k), Math.round(hmax * k)));
        w.addFx({ x: p.x, y: p.y, k: 'heal' });
        break;
      }
      case 'heal_area': {
        const { min, max: hmax } = healAmount(p.level, p.skills.magic.level);
        const k = spell.power * SpellSystem.staffPower(p);
        for (const o of w.players.values())
          // Sojusznicy: rzucający, gildia i gracze, których nie wolno tu zaatakować.
          if (chebyshev(o.x, o.y, p.x, p.y) <= (spell.radius ?? 3) && (o === p || w.guilds.sameGuild(p, o) || !!w.pvp.canAttack(p, o)))
            this.heal(o, randInt(Math.round(min * k), Math.round(hmax * k)));
        fx({ r: spell.radius });
        break;
      }
      case 'purify': {
        const st = p.status;
        st.bleedUntil = 0;
        st.slowUntil = 0;
        st.cursedUntil = 0;
        fx({});
        break;
      }
      case 'bolt': {
        let dmg = max;
        if (spell.id === 'holy' && target instanceof Monster && UNDEAD.has(target.def.id)) dmg *= 2;
        fx({ tx: target!.x, ty: target!.y });
        this.magicHit(p, target!, dmg);
        break;
      }
      case 'burn':
        fx({ tx: target!.x, ty: target!.y });
        this.magicHit(p, target!, max);
        this.dot(p, target!, Math.max(1, Math.round(max * 0.18)), dur, now);
        break;
      case 'chill':
        fx({ tx: target!.x, ty: target!.y });
        this.magicHit(p, target!, max);
        target!.status.slowUntil = now + dur;
        break;
      case 'drain': {
        fx({ tx: target!.x, ty: target!.y });
        const dealt = this.magicHit(p, target!, max);
        if (dealt > 0) this.heal(p, Math.round(dealt / 2));
        break;
      }
      case 'curse':
        fx({ tx: target!.x, ty: target!.y });
        target!.status.cursedUntil = now + dur;
        this.dot(p, target!, Math.max(1, Math.round(this.maxDamage(p, SPELLS.drain) * 0.12)), dur, now);
        break;
      case 'chain': {
        const hit: Target[] = [target!];
        let from: Target = target!;
        for (let i = 0; i < 2; i++) {
          const next = this.enemiesAround(p, from.x, from.y, spell.radius ?? 3).find((t) => !hit.includes(t));
          if (!next) break;
          hit.push(next);
          from = next;
        }
        fx({ chain: hit.map((t) => [t.x, t.y]) });
        for (const t of hit) this.magicHit(p, t, max);
        break;
      }
      case 'area': {
        const tx = target!.x;
        const ty = target!.y;
        fx({ tx, ty, r: spell.radius });
        for (const t of this.enemiesAround(p, tx, ty, spell.radius ?? 2)) this.magicHit(p, t, max);
        break;
      }
      case 'nova':
        fx({ r: spell.radius });
        for (const t of this.enemiesAround(p, p.x, p.y, spell.radius ?? 2)) {
          this.magicHit(p, t, max);
          t.status.stunUntil = now + dur;
        }
        break;
      case 'meteor': {
        const tx = target!.x;
        const ty = target!.y;
        fx({ tx, ty, r: spell.radius });
        this.later(now + 1100, () => {
          if (!w.players.has(p.id)) return;
          for (const t of this.enemiesAround(p, tx, ty, spell.radius ?? 3)) this.magicHit(p, t, max);
        });
        break;
      }
      case 'storm': {
        const tx = target!.x;
        const ty = target!.y;
        fx({ tx, ty, r: spell.radius, ms: dur });
        for (let i = 0; i < 5; i++)
          this.later(now + 300 + i * 800, () => {
            if (!w.players.has(p.id)) return;
            const list = this.enemiesAround(p, tx, ty, spell.radius ?? 2);
            if (list.length === 0) return;
            const t = list[randInt(0, list.length - 1)];
            w.addFx({ x: t.x, y: t.y, k: 'sp', s: 'storm_hit', id: p.id });
            this.magicHit(p, t, max);
          });
        break;
      }
      case 'cloud': {
        const tx = target!.x;
        const ty = target!.y;
        fx({ tx, ty, r: spell.radius, ms: dur });
        const per = Math.max(1, Math.round(max));
        for (let i = 1; i <= Math.round(dur / 1000); i++)
          this.later(now + i * 1000, () => {
            if (!w.players.has(p.id)) return;
            for (const t of this.enemiesAround(p, tx, ty, spell.radius ?? 2)) this.magicHit(p, t, per, true);
          });
        break;
      }
      case 'shield':
        p.status.shieldUntil = now + dur;
        p.status.shieldHp = Math.round((p.skills.magic.level * 8 + p.level * 2 + 40) * SpellSystem.staffPower(p));
        fx({});
        break;
      case 'haste':
        p.status.hasteUntil = now + dur;
        p.status.haste = spell.power;
        fx({});
        break;
    }
  }

  /** Obrażenia magiczne (pomijają pancerz i obronę, rozrzut 55–100%). Zwraca zadane obrażenia. */
  private magicHit(p: Player, t: Target, max: number, quiet = false): number {
    const w = this.world;
    if (!(t instanceof Monster ? w.monsters.has(t.id) : w.players.has(t.id))) return 0;
    const now = Date.now();
    if (t instanceof Player) {
      if (t === p || w.guilds.sameGuild(p, t) || w.pvp.canAttack(p, t)) return 0;
      w.pvp.onAttack(p, t, now);
    } else if (!t.targetId) {
      t.targetId = p.id;
    }
    const dmg = randInt(Math.round(max * 0.55), Math.max(1, Math.round(max)));
    if (!quiet) w.addFx({ x: t.x, y: t.y, k: 'sp', s: 'impact', id: p.id });
    return w.applyDamage(t, dmg, p);
  }

  /** Podpalenie / klątwa – obrażenia co sekundę (mechanika krwawienia). */
  private dot(p: Player, t: Target, perSecond: number, dur: number, now: number) {
    const st = t.status;
    st.bleedUntil = now + dur;
    st.bleedNextAt = now + 1000;
    st.bleedDamage = perSecond;
    st.bleedSource = p.id;
  }

  private heal(p: Player, amount: number) {
    const before = p.hp;
    p.hp = Math.min(p.maxHp(), p.hp + amount);
    this.world.addFx({ x: p.x, y: p.y, k: 'num', v: p.hp - before, c: 'heal' });
  }

  private later(at: number, run: () => void) {
    this.pending.push({ at, run });
  }

  tick(now: number) {
    if (this.pending.length === 0) return;
    const due = this.pending.filter((e) => e.at <= now);
    if (due.length === 0) return;
    this.pending = this.pending.filter((e) => e.at > now);
    for (const e of due) e.run();
  }

  /** Wrogowie wokół punktu: potwory oraz gracze, których wolno zaatakować. */
  private enemiesAround(p: Player, x: number, y: number, r: number): Target[] {
    const out: Target[] = [];
    for (const m of this.world.monsters.values()) if (chebyshev(m.x, m.y, x, y) <= r) out.push(m);
    for (const o of this.world.players.values())
      if (o !== p && chebyshev(o.x, o.y, x, y) <= r && !this.world.pvp.canAttack(p, o) && !this.world.guilds.sameGuild(p, o)) out.push(o);
    return out;
  }

  // =========================================================================
  // Nauka czarów u kapłana
  // =========================================================================

  /** Lista czarów nauczanych w mieście (okno Księgi czarów z przyciskami nauki). */
  offer(p: Player, city: string) {
    const schools = CITY_SCHOOLS[city] ?? [];
    const spells = Object.values(SPELLS)
      .filter((s) => schools.includes(s.school) && s.price > 0)
      .map((s) => ({ id: s.id, price: s.price, known: SpellSystem.knows(p, s.id) }));
    p.send({ t: 'spell_shop', city, schools: schools.map((s) => SCHOOL_NAMES[s]), spells });
  }

  learn(p: Player, spellId: string, city: string) {
    const w = this.world;
    const s = SPELLS[spellId];
    if (!s || !(CITY_SCHOOLS[city] ?? []).includes(s.school) || s.price <= 0) return w.sendSystem(p, 'Tego czaru nie nauczysz się w tym mieście.');
    if (SpellSystem.knows(p, s.id)) return w.sendSystem(p, 'Znasz już ten czar.');
    if (p.level < s.minLevel) return w.sendSystem(p, `Ten czar wymaga poziomu ${s.minLevel}.`);
    if (p.inventory.countOf('gold') < s.price) return w.sendSystem(p, `Nauka kosztuje ${s.price} zł – masz za mało złota.`);
    p.inventory.remove('gold', s.price);
    p.pvp.spells = [...(p.pvp.spells ?? []), s.id];
    w.addFx({ x: p.x, y: p.y, k: 'levelup' });
    w.sendSystem(p, `Nauczyłeś się czaru „${s.name}” (${s.words}). Znajdziesz go w Księdze czarów.`);
    this.offer(p, city);
  }
}
