/**
 * Zadania: przyjmowanie u NPC, postęp (zabójstwa, odwiedzone miejsca, surowce w plecaku),
 * oddawanie z nagrodą. Stan w zapisie postaci (pvp.quests). Klient dostaje:
 *  - `quests`  – oferta NPC (okno zadań),
 *  - `qlog`    – dziennik aktywnych zadań (panel „Aktualne zadania”).
 */
import type { World } from '../world';
import { Npc, Player } from '../entities';
import { QUESTS, QUEST_LIST, QuestDef, QuestGoal, QuestState } from '../data/quests';
import { chebyshev } from '../combat';
import { NPC_RANGE } from '../data/npcs';
import { cityTemple, CITY_LIST } from '../data/cities';
import { CENTER } from '../map';
import { getItem } from '../data/items';

/** Ile trzeba zrobić dla celu (odwiedzenie miejsca = 1). */
function need(g: QuestGoal): number {
  return g.kind === 'visit' ? 1 : g.count;
}

export class QuestSystem {
  private nextVisitCheck = 0;

  constructor(private world: World) {}

  private state(p: Player): QuestState {
    if (!p.pvp.quests) p.pvp.quests = { active: {}, done: [] };
    return p.pvp.quests;
  }

  /** Rola NPC z identyfikatora („guild”, „szronogrod_guild” -> „guild”). */
  static roleOf(n: Npc): string {
    return n.def.id.split('_').pop() ?? '';
  }

  /** Pozycja miejsca z celu „visit”. */
  place(key: string): { x: number; y: number } | null {
    const [kind, arg] = key.split(':');
    if (kind === 'city') {
      const c = CITY_LIST.find((x) => x.id === arg);
      return c ? cityTemple(c) : null;
    }
    if (kind === 'fire_temple') return CENTER;
    if (kind === 'obelisk') return this.world.map.territories[Number(arg) || 0] ?? null;
    return null;
  }

  private status(p: Player, q: QuestDef): 'available' | 'active' | 'ready' | 'done' | 'locked' {
    const st = this.state(p);
    if (st.active[q.id]) return this.complete(p, q) ? 'ready' : 'active';
    if (st.done.includes(q.id) && !q.repeatable) return 'done';
    if (p.level < q.minLevel || (q.after && !st.done.includes(q.after))) return 'locked';
    return 'available';
  }

  private progress(p: Player, q: QuestDef): number[] {
    const prog = this.state(p).active[q.id] ?? q.goals.map(() => 0);
    return q.goals.map((g, i) => (g.kind === 'gather' ? Math.min(g.count, p.inventory.countOf(g.item)) : Math.min(need(g), prog[i] ?? 0)));
  }

  private complete(p: Player, q: QuestDef): boolean {
    const prog = this.progress(p, q);
    return q.goals.every((g, i) => prog[i] >= need(g));
  }

  private describe(p: Player, q: QuestDef) {
    const prog = this.progress(p, q);
    const items = (q.reward.items ?? []).map(([id, n]) => `${n}× ${getItem(id)?.name ?? id}`);
    return {
      id: q.id,
      name: q.name,
      text: q.text,
      level: q.minLevel,
      state: this.status(p, q),
      goals: q.goals.map((g, i) => [g.label, prog[i], need(g)]),
      reward: [`${q.reward.exp} doświadczenia`, `${q.reward.gold} zł`, ...items].join(', '),
    };
  }

  /** Okno zadań NPC. */
  offer(p: Player, n: Npc) {
    const role = QuestSystem.roleOf(n);
    const list = QUEST_LIST.filter((q) => q.city === n.def.city && q.giver === role)
      .map((q) => this.describe(p, q))
      .filter((d) => d.state !== 'locked' || d.level <= p.level + 10);
    p.send({ t: 'quests', npc: n.def.name, list });
  }

  private giverNear(p: Player, q: QuestDef): Npc | null {
    for (const n of this.world.npcs.values())
      if (n.def.city === q.city && QuestSystem.roleOf(n) === q.giver && chebyshev(p.x, p.y, n.x, n.y) <= NPC_RANGE) return n;
    return null;
  }

  accept(p: Player, id: string) {
    const w = this.world;
    const q = QUESTS[id];
    if (!q) return;
    const n = this.giverNear(p, q);
    if (!n) return w.sendSystem(p, 'Musisz stać przy NPC, który daje to zadanie.');
    if (this.status(p, q) !== 'available') return;
    if (Object.keys(this.state(p).active).length >= 10) return w.sendSystem(p, 'Masz już 10 zadań. Ukończ któreś.');
    this.state(p).active[q.id] = q.goals.map(() => 0);
    w.sendSystem(p, `Nowe zadanie: „${q.name}”.`);
    this.offer(p, n);
    this.sendLog(p);
  }

  turnIn(p: Player, id: string) {
    const w = this.world;
    const q = QUESTS[id];
    if (!q) return;
    const n = this.giverNear(p, q);
    if (!n) return w.sendSystem(p, 'Nagrodę odbierzesz u NPC, który dał zadanie.');
    if (this.status(p, q) !== 'ready') return w.sendSystem(p, 'Zadanie nie jest jeszcze ukończone.');
    for (const g of q.goals) if (g.kind === 'gather') p.inventory.remove(g.item, g.count);
    const st = this.state(p);
    delete st.active[q.id];
    if (!st.done.includes(q.id)) st.done.push(q.id);
    w.giveExp(p, q.reward.exp);
    p.inventory.add('gold', q.reward.gold);
    for (const [item, count] of q.reward.items ?? []) {
      const left = p.inventory.add(item, count);
      if (left > 0) w.depots.add(p.charId, q.city, item, left, 1, true);
    }
    p.inventory.dirty = true;
    w.addFx({ x: p.x, y: p.y, k: 'levelup' });
    w.sendSystem(p, `Zadanie „${q.name}” ukończone! Nagroda: ${this.describe(p, q).reward}.`);
    this.offer(p, n);
    this.sendLog(p);
  }

  abandon(p: Player, id: string) {
    if (!this.state(p).active[id]) return;
    delete this.state(p).active[id];
    this.world.sendSystem(p, `Porzucono zadanie „${QUESTS[id]?.name ?? id}”.`);
    this.sendLog(p);
  }

  onKill(p: Player, monsterId: string) {
    const st = this.state(p);
    let changed = false;
    for (const [id, prog] of Object.entries(st.active)) {
      const q = QUESTS[id];
      q.goals.forEach((g, i) => {
        if (g.kind === 'kill' && g.monster === monsterId && (prog[i] ?? 0) < g.count) {
          prog[i] = (prog[i] ?? 0) + 1;
          changed = true;
          if (prog[i] === g.count) this.world.sendSystem(p, `„${q.name}”: ${g.label} – wykonane!`);
        }
      });
    }
    if (changed) this.sendLog(p);
  }

  /** Cele „odwiedź miejsce” – sprawdzane co sekundę. */
  tick(now: number) {
    if (now < this.nextVisitCheck) return;
    this.nextVisitCheck = now + 1000;
    for (const p of this.world.players.values()) {
      const st = p.pvp.quests;
      if (!st) continue;
      let changed = false;
      for (const [id, prog] of Object.entries(st.active)) {
        const q = QUESTS[id];
        q.goals.forEach((g, i) => {
          if (g.kind !== 'visit' || (prog[i] ?? 0) >= 1) return;
          const pos = this.place(g.place);
          if (pos && chebyshev(p.x, p.y, pos.x, pos.y) <= g.radius) {
            prog[i] = 1;
            changed = true;
            this.world.sendSystem(p, `„${q.name}”: ${g.label} – wykonane! Wróć po nagrodę.`);
          }
        });
      }
      if (changed) this.sendLog(p);
    }
  }

  /** Dziennik zadań do panelu „Aktualne zadania” (też po zmianie plecaka dla zadań zbierackich). */
  sendLog(p: Player) {
    const st = this.state(p);
    const list = Object.keys(st.active).map((id) => {
      const q = QUESTS[id];
      const d = this.describe(p, q);
      const place = q.goals.find((g) => g.kind === 'visit');
      const pos = place && place.kind === 'visit' ? this.place(place.place) : null;
      return { id, name: q.name, goals: d.goals, ready: d.state === 'ready', city: q.city, ...(pos ? { px: pos.x, py: pos.y } : {}) };
    });
    const json = JSON.stringify(list);
    if (json === p.lastQuestLog) return;
    p.lastQuestLog = json;
    p.send({ t: 'qlog', list });
  }
}
