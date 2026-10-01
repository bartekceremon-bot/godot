/**
 * Terytoria gildii na Popielisku: sześć obelisków. Gildia, której członkowie utrzymają się
 * w promieniu 3 pól od obelisku przez CAPTURE_MS bez obecności innej gildii, przejmuje terytorium.
 * Premie właściciela w promieniu BONUS_RADIUS od obelisku: +25% doświadczenia i +25% szansy
 * na dodatkowy surowiec przy zbieraniu.
 */
import type { World } from '../world';
import type { Player } from '../entities';
import { allocEntityId } from '../entities';
import type { TerritorySpot } from '../map';

export const CAPTURE_RADIUS = 3;
export const CAPTURE_MS = 60_000;
export const BONUS_RADIUS = 14;
const STATE_KEY = 'territories';

export class Territory {
  readonly id = allocEntityId();
  owner = 0;
  /** Gildia przejmująca i postęp (ms). */
  capturer = 0;
  progress = 0;
  contested = false;
  lastAnnounce = 0;
  constructor(readonly spot: TerritorySpot) {}
}

export class TerritorySystem {
  readonly list: Territory[] = [];
  private lastTick = Date.now();

  constructor(private world: World) {
    let saved: Record<string, number> = {};
    try {
      saved = JSON.parse(world.db.loadWorldState(STATE_KEY) ?? '{}');
    } catch {
      saved = {};
    }
    for (const s of world.map.territories) {
      const t = new Territory(s);
      t.owner = Number(saved[s.id]) || 0;
      this.list.push(t);
    }
  }

  private save() {
    const out: Record<string, number> = {};
    for (const t of this.list) if (t.owner) out[t.spot.id] = t.owner;
    this.world.db.saveWorldState(STATE_KEY, JSON.stringify(out));
  }

  ownedBy(guildId: number): string[] {
    return this.list.filter((t) => t.owner === guildId).map((t) => t.spot.name);
  }

  releaseGuild(guildId: number) {
    for (const t of this.list) if (t.owner === guildId) t.owner = 0;
    this.save();
  }

  /** Czy gracz korzysta z premii terytorium w swoim miejscu? */
  hasBonus(p: Player): boolean {
    if (!p.guildId) return false;
    return this.list.some((t) => t.owner === p.guildId && Math.hypot(t.spot.x - p.x, t.spot.y - p.y) <= BONUS_RADIUS);
  }

  tick(now: number) {
    const dt = now - this.lastTick;
    if (dt < 1000) return;
    this.lastTick = now;
    for (const t of this.list) {
      const guilds = new Set<number>();
      for (const p of this.world.players.values())
        if (p.guildId && Math.max(Math.abs(p.x - t.spot.x), Math.abs(p.y - t.spot.y)) <= CAPTURE_RADIUS) guilds.add(p.guildId);
      t.contested = guilds.size > 1;
      if (guilds.size !== 1) {
        if (!guilds.size) t.progress = Math.max(0, t.progress - dt);
        continue;
      }
      const g = [...guilds][0];
      if (g === t.owner) {
        t.progress = 0;
        continue;
      }
      if (t.capturer !== g) {
        t.capturer = g;
        t.progress = 0;
      }
      t.progress += dt;
      const guild = this.world.guilds.get(g);
      if (!guild) continue;
      if (now - t.lastAnnounce > 20_000 && t.progress < CAPTURE_MS) {
        t.lastAnnounce = now;
        const prev = this.world.guilds.get(t.owner);
        if (prev) this.world.guilds.guildSystem(prev, `Gildia ${guild.name} [${guild.tag}] przejmuje wasz obelisk „${t.spot.name}”!`);
      }
      if (t.progress >= CAPTURE_MS) {
        const prev = this.world.guilds.get(t.owner);
        t.owner = g;
        t.progress = 0;
        t.capturer = 0;
        this.save();
        this.world.addFx({ x: t.spot.x, y: t.spot.y, k: 'levelup' });
        this.world.broadcastSystem(
          `Gildia ${guild.name} [${guild.tag}] przejęła terytorium „${t.spot.name}”${prev ? ` z rąk ${prev.name}` : ''}!`,
        );
      }
    }
  }

  /** Obeliski jako istoty w pakiecie „snap”: h = postęp przejmowania (%), o = skrót właściciela. */
  snapshot(t: Territory) {
    const owner = this.world.guilds.get(t.owner);
    const cap = this.world.guilds.get(t.capturer);
    return {
      i: t.id,
      k: 't',
      n: `${t.spot.name}${owner ? ` [${owner.tag}]` : ''}`,
      x: t.spot.x,
      y: t.spot.y,
      d: 2,
      h: Math.round((t.progress / CAPTURE_MS) * 100),
      l: 'obelisk',
      s: 0,
      o: owner?.tag ?? '',
      c: cap && t.progress > 0 ? cap.tag : '',
    };
  }
}
