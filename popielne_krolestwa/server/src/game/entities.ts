/**
 * Obiekty żyjące w świecie: gracze, potwory, przedmioty na ziemi.
 */
import { MonsterDef } from './data/monsters';
import { getItem, QUALITY_MULT } from './data/items';
import { NpcDef } from './data/npcs';
import { NodeKind, NODE_NAMES, nodeCharges } from './data/resources';
import { Specs, SPEC_DEFS, fameForNextLevel, TIER_SPEC_REQ } from './specs';
import { Inventory } from './inventory';
import { Skills, maxHpForLevel, maxMpForLevel, stepMsForLevel, levelForExp, expForLevel, skillPercent } from './progression';
import { SKILL_NAMES } from './data/items';

/** Kierunki: 0=N, 1=E, 2=S, 3=W. */
export type Dir = 0 | 1 | 2 | 3;

/** Wektory 8 kierunków ruchu (indeks = kod z protokołu). */
export const MOVE_VECTORS: [number, number][] = [
  [0, -1], // 0 N
  [1, 0], // 1 E
  [0, 1], // 2 S
  [-1, 0], // 3 W
  [1, -1], // 4 NE
  [1, 1], // 5 SE
  [-1, 1], // 6 SW
  [-1, -1], // 7 NW
];

export function dirFromDelta(dx: number, dy: number, fallback: Dir): Dir {
  if (Math.abs(dx) > Math.abs(dy)) return dx > 0 ? 1 : 3;
  if (dy !== 0) return dy > 0 ? 2 : 0;
  return fallback;
}

/** Interfejs połączenia sieciowego (pozwala testować świat bez WebSocketów). */
export interface Connection {
  /** Wysyła obiekt (serializowany do JSON) lub gotowy string JSON. */
  send(msg: object | string): void;
  close(reason?: string): void;
}

let nextEntityId = 1;
export function allocEntityId(): number {
  return nextEntityId++;
}

export interface Creature {
  id: number;
  name: string;
  x: number;
  y: number;
  dir: Dir;
  hp: number;
  maxHp(): number;
}

export class Player implements Creature {
  readonly id = allocEntityId();
  readonly charId: number;
  readonly name: string;
  conn: Connection;
  x: number;
  y: number;
  dir: Dir = 2;
  hp: number;
  mp: number;
  exp: number;
  level: number;
  /** Wariant wyglądu (kolor stroju) – losowany przy tworzeniu postaci. */
  look: number;
  skills: Skills;
  specs: Specs;
  inventory: Inventory;

  /** Zbieranie w toku: złoże i czas ukończenia kolejnej jednostki. */
  gathering: { nodeId: number; nextAt: number } | null = null;
  /** NPC, z którym gracz aktualnie rozmawia (0 = brak). */
  talkingTo = 0;
  /** Otwarte okno ekonomii w kliencie – do odświeżania po dostawach. */
  openWindow: '' | 'depot' | 'market' | 'shop' | 'craft' = '';

  /** Id atakowanego potwora (0 = brak celu). */
  targetId = 0;
  nextMoveAt = 0;
  lastStepMs = 0;
  nextAttackAt = 0;
  nextRegenAt = 0;
  lastChatAt = 0;
  spellCooldowns: Record<string, number> = {};
  /** Czas ostatniej walki – blokuje wylogowanie „w walce” w kolejnych etapach. */
  lastCombatAt = 0;

  /** Cache ostatnio wysłanych pakietów – wysyłamy tylko zmiany. */
  lastSnapshot = '';
  lastStats = '';

  constructor(opts: {
    charId: number;
    name: string;
    conn: Connection;
    x: number;
    y: number;
    hp: number;
    mp: number;
    exp: number;
    look: number;
    skills: Skills;
    specs: Specs;
    inventory: Inventory;
  }) {
    this.charId = opts.charId;
    this.name = opts.name;
    this.conn = opts.conn;
    this.x = opts.x;
    this.y = opts.y;
    this.exp = opts.exp;
    this.level = levelForExp(opts.exp);
    this.look = opts.look;
    this.skills = opts.skills;
    this.specs = opts.specs;
    this.inventory = opts.inventory;
    this.hp = Math.min(opts.hp, this.maxHp());
    this.mp = Math.min(opts.mp, this.maxMp());
  }

  maxHp() {
    return maxHpForLevel(this.level) + this.inventory.equipmentStat('hpBonus');
  }

  maxMp() {
    return maxMpForLevel(this.level) + this.inventory.equipmentStat('mpBonus');
  }

  /** Udźwig w oz. (ETAP 4: wierzchowce zwiększą go dodatkowo). */
  capacity() {
    return 400 + (this.level - 1) * 20;
  }

  /** Ile jeszcze sztuk przedmiotu zmieści się w plecaku z uwzględnieniem udźwigu. */
  canCarry(itemId: string, q = 1): number {
    const w = getItem(itemId)?.weight ?? 0;
    const byWeight = w > 0 ? Math.floor((this.capacity() - this.inventory.weight()) / w + 1e-9) : Infinity;
    return Math.max(0, Math.min(byWeight, this.inventory.spaceFor(itemId, q)));
  }

  stepMs() {
    return stepMsForLevel(this.level);
  }

  weapon() {
    const w = this.inventory.equipment.weapon;
    return w ? getItem(w.item) : undefined;
  }

  shield() {
    const s = this.inventory.equipment.shield;
    return s ? getItem(s.item) : undefined;
  }

  /** Mnożnik jakości założonego przedmiotu w slocie. */
  qualityMult(slot: 'weapon' | 'shield') {
    return QUALITY_MULT[this.inventory.equipment[slot]?.q ?? 1];
  }

  send(msg: object) {
    this.conn.send(msg);
  }

  /** Statystyki wysyłane do właściciela postaci. */
  statsPayload() {
    const skills: Record<string, [number, number]> = {};
    for (const n of SKILL_NAMES) skills[n] = [this.skills[n].level, skillPercent(n, this.skills[n])];
    return {
      t: 'stats',
      hp: this.hp,
      mhp: this.maxHp(),
      mp: this.mp,
      mmp: this.maxMp(),
      lvl: this.level,
      exp: this.exp,
      expCur: expForLevel(this.level),
      expNext: expForLevel(this.level + 1),
      step: this.stepMs(),
      target: this.targetId,
      skills,
      cap: this.capacity(),
      weight: this.inventory.weight(),
      specs: SPEC_DEFS.map((d) => {
        const st = this.specs[d.id];
        return [d.id, st.level, Math.floor((st.fame / fameForNextLevel(st.level)) * 100)];
      }),
      gather: this.gathering?.nodeId ?? 0,
    };
  }
}

/** NPC stojący w mieście. */
export class Npc {
  readonly id = allocEntityId();
  readonly def: NpcDef;
  readonly x: number;
  readonly y: number;
  dir: Dir = 2;

  constructor(def: NpcDef) {
    this.def = def;
    this.x = def.x;
    this.y = def.y;
  }
}

/** Złoże surowca. */
export class ResourceNode {
  readonly id = allocEntityId();
  readonly kind: NodeKind;
  readonly tier: number;
  readonly x: number;
  readonly y: number;
  readonly name: string;
  charges: number;
  /** Kiedy złoże się odnowi (0 = aktywne). */
  respawnAt = 0;

  constructor(kind: NodeKind, tier: number, x: number, y: number) {
    this.kind = kind;
    this.tier = tier;
    this.x = x;
    this.y = y;
    this.name = `${NODE_NAMES[kind][tier]} (T${tier})`;
    this.charges = nodeCharges(tier);
  }

  maxCharges() {
    return nodeCharges(this.tier);
  }

  /** Wymagany poziom specjalizacji zbierackiej. */
  specReq() {
    return TIER_SPEC_REQ[this.tier];
  }
}

export class Monster implements Creature {
  readonly id = allocEntityId();
  readonly def: MonsterDef;
  readonly spawnIndex: number;
  readonly name: string;
  x: number;
  y: number;
  dir: Dir = 2;
  hp: number;
  targetId = 0;
  nextMoveAt = 0;
  nextAttackAt = 0;
  lastStepMs = 0;

  constructor(def: MonsterDef, x: number, y: number, spawnIndex: number) {
    this.def = def;
    this.name = def.name;
    this.x = x;
    this.y = y;
    this.hp = def.hp;
    this.spawnIndex = spawnIndex;
  }

  maxHp() {
    return this.def.hp;
  }
}

export interface GroundItem {
  id: number;
  x: number;
  y: number;
  item: string;
  count: number;
  /** Jakość (1–5). */
  q: number;
  expiresAt: number;
}
