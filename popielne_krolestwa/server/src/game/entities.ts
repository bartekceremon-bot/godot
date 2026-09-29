/**
 * Obiekty żyjące w świecie: gracze, potwory, przedmioty na ziemi.
 */
import { MonsterDef } from './data/monsters';
import { getItem } from './data/items';
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
  inventory: Inventory;

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
    this.inventory = opts.inventory;
    this.hp = Math.min(opts.hp, this.maxHp());
    this.mp = Math.min(opts.mp, this.maxMp());
  }

  maxHp() {
    return maxHpForLevel(this.level);
  }

  maxMp() {
    return maxMpForLevel(this.level);
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
    };
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
  expiresAt: number;
}
