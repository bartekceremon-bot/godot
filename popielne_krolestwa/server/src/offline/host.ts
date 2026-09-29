/**
 * Tryb offline: cały serwer gry działa w przeglądarce (wersja Web klienta).
 * Klient Godot (Net, gdy adres = "offline") wysyła JSON przez window.PK.send()
 * i co klatkę odbiera wiadomości przez window.PK.poll().
 *
 * Stan świata zapisywany jest w localStorage, a po mieście i okolicy krążą
 * boty-Popielnicy, żeby świat nie był pusty.
 */
import { World } from '../game/world';
import { MemoryDatabase } from '../db/memory_database';
import { Connection, Player, MOVE_VECTORS } from '../game/entities';
import { createAccountWithCharacter, playerFromRow } from '../game/session';
import { chebyshev } from '../game/combat';
import { validateName } from '../auth_rules';

const SAVE_KEY = 'popielne_krolestwa_offline_v1';

class QueueConnection implements Connection {
  queue: string[] = [];
  send(msg: object | string) {
    this.queue.push(typeof msg === 'string' ? msg : JSON.stringify(msg));
  }
  close() {}
}

/** Połączenie bota – wiadomości od serwera są ignorowane. */
class NullConnection implements Connection {
  send() {}
  close() {}
}

function storage(): Storage | null {
  try {
    return globalThis.localStorage ?? null;
  } catch {
    return null;
  }
}

const BOT_NAMES = ['Wędrowiec Jarek', 'Łowczyni Ola', 'Stary Bogumił', 'Zbieraczka Iga', 'Najemnik Radek'];
const BOT_CHAT = [
  'Ktoś widział wilki na zachodzie?',
  'Kupię deski kasztanowe, dobra cena!',
  'Szczury znowu podchodzą pod mury...',
  'Popielisko na północnym wschodzie – tam jest tytan.',
  'exura',
  'Kowal Gerwazy robi najlepsze miecze w Popielgrodzie.',
];

interface Bot {
  p: Player;
  home: { x: number; y: number };
  goal: { x: number; y: number };
  nextAct: number;
  nextChat: number;
}

export class OfflineHost {
  readonly world: World;
  private conn: QueueConnection | null = null;
  private player: Player | null = null;
  private bots: Bot[] = [];

  constructor() {
    const st = storage();
    let saved: string | null = null;
    try {
      saved = st?.getItem(SAVE_KEY) ?? null;
    } catch {
      saved = null;
    }
    let lastSave = 0;
    let pending: string | null = null;
    const db = new MemoryDatabase(saved, (json) => {
      // Zapis co najwyżej raz na 2 s (plus przy zamknięciu karty).
      pending = json;
      const now = Date.now();
      if (now - lastSave > 2000) {
        lastSave = now;
        try {
          st?.setItem(SAVE_KEY, json);
        } catch {
          /* brak miejsca / zablokowane */
        }
        pending = null;
      }
    });
    globalThis.addEventListener?.('pagehide', () => {
      this.world.saveAll();
      if (pending) {
        try {
          st?.setItem(SAVE_KEY, pending);
        } catch {
          /* ignoruj */
        }
      }
    });
    this.world = new World(db);
    this.world.start();
    this.spawnBots();
    setInterval(() => this.tickBots(Date.now()), 200);
  }

  /** Nowe „połączenie” (ekran logowania). */
  connect() {
    if (this.player) this.world.removePlayer(this.player);
    this.player = null;
    this.conn = new QueueConnection();
  }

  send(text: string) {
    if (!this.conn) this.connect();
    let msg: Record<string, unknown>;
    try {
      msg = JSON.parse(text);
    } catch {
      return;
    }
    if (msg.t === 'ping') return this.conn!.send({ t: 'pong', ts: msg.ts });
    if (!this.player) {
      if (msg.t === 'login' || msg.t === 'register') this.login(String(msg.name ?? '').trim());
      return;
    }
    this.world.handle(this.player, msg);
  }

  /** Wiadomości od serwera jako tablica JSON (pusty string, gdy brak). */
  poll(): string {
    if (!this.conn || this.conn.queue.length === 0) return '';
    const out = '[' + this.conn.queue.join(',') + ']';
    this.conn.queue = [];
    return out;
  }

  close() {
    if (this.player) this.world.removePlayer(this.player);
    this.player = null;
    this.conn = null;
  }

  /** W trybie offline nie ma haseł – nazwa wybiera postać (nową albo zapisaną). */
  private login(name: string) {
    const err = validateName(name);
    if (err) return this.conn!.send({ t: 'auth_error', text: err });
    const db = this.world.db;
    let account = db.findAccount(name);
    if (!account) {
      createAccountWithCharacter(db, name, '', this.world.map.temple);
      account = db.findAccount(name)!;
    }
    const row = db.findCharacterByAccount(account.id)!;
    this.player = playerFromRow(row, this.conn!);
    this.world.addPlayer(this.player);
  }

  // --- Boty -------------------------------------------------------------------

  private spawnBots() {
    const t = this.world.map.temple;
    const homes = [
      { x: t.x, y: t.y + 3 },
      { x: 30, y: 46 },
      { x: 62, y: 49 },
      { x: 48, y: 34 },
      { x: 49, y: 62 },
    ];
    BOT_NAMES.forEach((name, i) => {
      const db = this.world.db;
      let acc = db.findAccount(name);
      if (!acc) {
        createAccountWithCharacter(db, name, '', homes[i]);
        acc = db.findAccount(name)!;
      }
      const p = playerFromRow(db.findCharacterByAccount(acc.id)!, new NullConnection());
      p.x = homes[i].x;
      p.y = homes[i].y;
      // Boty noszą różny ekwipunek – widać różnorodność pancerzy.
      const gear = [
        ['plate_body_t2', 'plate_head_t2', 'plate_legs_t2', 'mace_t2'],
        ['leather_body_t2', 'leather_head_t1', 'leather_legs_t2', 'bow_t2'],
        ['cloth_body_t3', 'cloth_head_t3', 'cloth_legs_t2', 'cloth_feet_t2'],
        ['leather_body_t1', 'leather_feet_t1', 'axe_t1'],
        ['plate_body_t1', 'plate_feet_t1', 'sword_t2', 'shield_t2'],
      ][i];
      for (const g of gear) {
        const slot = p.inventory.bag.findIndex((s) => s === null);
        if (slot < 0) break;
        p.inventory.add(g);
        const idx = p.inventory.bag.findIndex((s) => s?.item === g);
        p.inventory.equipFromBag(idx);
      }
      this.world.players.set(p.id, p);
      this.bots.push({ p, home: homes[i], goal: homes[i], nextAct: 0, nextChat: Date.now() + 5000 + i * 7000 });
    });
  }

  private tickBots(now: number) {
    for (const b of this.bots) {
      const p = b.p;
      if (p.hp < p.maxHp() * 0.5) this.world.handle(p, { t: 'cast', spell: 'heal' });
      if (now >= b.nextChat) {
        b.nextChat = now + 25000 + Math.random() * 40000;
        p.lastChatAt = 0;
        this.world.handle(p, { t: 'say', text: BOT_CHAT[Math.floor(Math.random() * BOT_CHAT.length)] });
      }
      if (now < b.nextAct) continue;
      b.nextAct = now + p.stepMs() + 30;
      // Walka z pobliskim potworem.
      let target = 0;
      for (const m of this.world.monsters.values())
        if (chebyshev(m.x, m.y, p.x, p.y) <= 4 && chebyshev(m.x, m.y, b.home.x, b.home.y) <= 8) target = m.id;
      if (target) {
        if (p.targetId !== target) this.world.handle(p, { t: 'attack', id: target });
        const m = this.world.monsters.get(target)!;
        if (chebyshev(m.x, m.y, p.x, p.y) > 1) this.stepToward(p, m.x, m.y);
        continue;
      }
      if (p.x === b.goal.x && p.y === b.goal.y || Math.random() < 0.05) {
        b.goal = { x: b.home.x + Math.floor(Math.random() * 11) - 5, y: b.home.y + Math.floor(Math.random() * 9) - 4 };
        b.nextAct = now + 1500 + Math.random() * 3000;
        continue;
      }
      this.stepToward(p, b.goal.x, b.goal.y);
    }
  }

  private stepToward(p: Player, tx: number, ty: number) {
    const dx = Math.sign(tx - p.x);
    const dy = Math.sign(ty - p.y);
    const tries: [number, number][] = [[dx, dy], [dx, 0], [0, dy], [-dy, dx], [dy, -dx]];
    for (const [ax, ay] of tries) {
      if (ax === 0 && ay === 0) continue;
      if (!this.world.map.isWalkable(p.x + ax, p.y + ay)) continue;
      const d = MOVE_VECTORS.findIndex(([vx, vy]) => vx === ax && vy === ay);
      if (d < 0) continue;
      const before = p.x * 1000 + p.y;
      this.world.handle(p, { t: 'move', d });
      if (p.x * 1000 + p.y !== before) return;
    }
  }
}

// Punkt wejścia pakietu przeglądarkowego.
const g = globalThis as unknown as { PK?: unknown };
let host: OfflineHost | null = null;
g.PK = {
  connect() {
    host ??= new OfflineHost();
    host.connect();
  },
  send(text: string) {
    host?.send(text);
  },
  poll() {
    return host?.poll() ?? '';
  },
  close() {
    host?.close();
  },
};
