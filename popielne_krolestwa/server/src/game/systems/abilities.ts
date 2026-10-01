/**
 * Aktywne umiejętności broni (3 na rodzaj broni). Wywoływane przyciskami paska akcji
 * (wiadomość { t: 'ability', slot: 1–3 }). Cel = aktualny cel ataku gracza.
 */
import type { World, Target } from '../world';
import { Player } from '../entities';
import { abilityFor, weaponKind } from '../data/abilities';
import { addSkillTries } from '../progression';
import { chebyshev } from '../combat';
import type { SkillName } from '../data/items';

export class AbilitySystem {
  constructor(private world: World) {}

  use(p: Player, slot: number, now: number) {
    const w = this.world;
    const kind = weaponKind(p.inventory.equipment.weapon?.item);
    if (!kind) return w.sendSystem(p, 'Załóż broń, aby używać umiejętności.');
    const def = abilityFor(kind, slot);
    if (!def) return;
    if (p.status.stunned(now)) return w.sendSystem(p, 'Jesteś ogłuszony!');
    if ((p.spellCooldowns[def.id] ?? 0) > now) return;
    if (p.mp < def.mana) {
      w.addFx({ x: p.x, y: p.y, k: 'puff' });
      return w.sendSystem(p, 'Za mało many.');
    }
    if (w.map.isProtectionZone(p.x, p.y) && def.range > 0) return w.sendSystem(p, 'W strefie ochronnej nie można walczyć.');

    let target: Target | undefined;
    if (def.range > 0) {
      target = w.getTarget(p.targetId);
      if (!target) return w.sendSystem(p, 'Najpierw wybierz cel (dotknij potwora lub gracza).');
      const dist = chebyshev(p.x, p.y, target.x, target.y);
      if (dist > def.range) return w.sendSystem(p, 'Cel jest za daleko.');
      if (def.range > 1 && !w.map.hasLineOfSight(p.x, p.y, target.x, target.y)) return w.sendSystem(p, 'Nie widzisz celu.');
      if (target instanceof Player) {
        const err = w.pvp.canAttack(p, target);
        if (err) return w.sendSystem(p, err);
      }
    }

    p.mp -= def.mana;
    p.spellCooldowns[def.id] = now + def.cooldownMs;
    p.lastCombatAt = now;
    p.send({ t: 'cd', id: def.id, ms: def.cooldownMs });
    w.addFx({ x: p.x, y: p.y, k: 'words', id: p.id, text: def.name });
    const { maxDmg, skill } = w.playerAttack(p);
    if (addSkillTries(p.skills, skill as SkillName, 2)) w.announceSkill(p, skill as SkillName);
    const ranged = kind === 'bow';

    switch (def.effect) {
      case 'strike':
        if (ranged) w.addFx({ x: p.x, y: p.y, k: 'shot', tx: target!.x, ty: target!.y });
        w.hit(p, target!, maxDmg * def.power, { ranged });
        break;
      case 'crush':
        w.hit(p, target!, maxDmg * def.power, { ignoreArmor: true });
        break;
      case 'bleed':
        w.hit(p, target!, maxDmg * def.power, {});
        target!.status.bleedUntil = now + (def.durationMs ?? 5000);
        target!.status.bleedNextAt = now + 1000;
        target!.status.bleedDamage = Math.max(1, Math.round(maxDmg * 0.25));
        target!.status.bleedSource = p.id;
        break;
      case 'stun':
        w.hit(p, target!, maxDmg * def.power, {});
        target!.status.stunUntil = now + (def.durationMs ?? 1500);
        w.addFx({ x: target!.x, y: target!.y, k: 'stun' });
        break;
      case 'slow':
        w.addFx({ x: p.x, y: p.y, k: 'shot', tx: target!.x, ty: target!.y });
        w.hit(p, target!, maxDmg * def.power, { ranged: true });
        target!.status.slowUntil = now + (def.durationMs ?? 5000);
        break;
      case 'whirl':
        for (const t of this.enemiesAround(p, p.x, p.y, 1)) w.hit(p, t, maxDmg * def.power, {});
        w.addFx({ x: p.x, y: p.y, k: 'whirl' });
        break;
      case 'volley':
        w.addFx({ x: p.x, y: p.y, k: 'shot', tx: target!.x, ty: target!.y });
        for (const t of this.enemiesAround(p, target!.x, target!.y, 1)) w.hit(p, t, maxDmg * def.power, { ranged: true });
        w.addFx({ x: target!.x, y: target!.y, k: 'volley' });
        break;
      case 'parry':
        p.status.parryUntil = now + (def.durationMs ?? 4000);
        w.addFx({ x: p.x, y: p.y, k: 'block' });
        break;
      case 'frenzy':
        p.status.frenzyUntil = now + (def.durationMs ?? 6000);
        w.addFx({ x: p.x, y: p.y, k: 'frenzy' });
        break;
      case 'ironskin':
        p.status.ironskinUntil = now + (def.durationMs ?? 8000);
        p.status.ironskinArmor = def.power;
        w.addFx({ x: p.x, y: p.y, k: 'ironskin' });
        break;
    }
  }

  /** Wrogowie wokół punktu: potwory oraz gracze, których wolno zaatakować. */
  private enemiesAround(p: Player, x: number, y: number, r: number): Target[] {
    const out: Target[] = [];
    for (const m of this.world.monsters.values()) if (chebyshev(m.x, m.y, x, y) <= r) out.push(m);
    for (const o of this.world.players.values())
      if (o !== p && chebyshev(o.x, o.y, x, y) <= r && !this.world.pvp.canAttack(p, o)) out.push(o);
    return out;
  }
}
