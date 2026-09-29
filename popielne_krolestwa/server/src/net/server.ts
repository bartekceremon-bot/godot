/**
 * Serwer WebSocket: przyjmuje połączenia, obsługuje logowanie/rejestrację
 * i przekazuje wiadomości zalogowanych graczy do świata.
 *
 * Protokół: każda wiadomość to obiekt JSON z polem `t` (typ).
 * Opis wszystkich wiadomości: popielne_krolestwa/PROTOKOL.md
 */
import { WebSocketServer, WebSocket } from 'ws';
import type { IncomingMessage } from 'node:http';
import { config } from '../config';
import { World } from '../game/world';
import { Player, Connection } from '../game/entities';
import { Inventory } from '../game/inventory';
import { defaultSkills, maxHpForLevel, maxMpForLevel, Skills } from '../game/progression';
import { hashPassword, verifyPassword, validateName, validatePassword } from '../auth';
import { randInt } from '../util/rng';

/** Ekwipunek startowy nowej postaci – broń wręcz i łuk, żeby przetestować oba style walki. */
function starterInventory(): Inventory {
  const inv = new Inventory([], {
    weapon: { item: 'rusty_sword', count: 1 },
    shield: { item: 'wooden_shield', count: 1 },
    body: { item: 'leather_armor', count: 1 },
  });
  inv.add('hunting_bow');
  inv.add('hp_potion', 3);
  inv.add('mp_potion', 2);
  inv.add('gold', 20);
  return inv;
}

class WsConnection implements Connection {
  constructor(private ws: WebSocket) {}
  send(msg: object | string) {
    if (this.ws.readyState === WebSocket.OPEN) this.ws.send(typeof msg === 'string' ? msg : JSON.stringify(msg));
  }
  close(reason?: string) {
    this.ws.close(1000, reason);
  }
}

export class GameServer {
  private wss: WebSocketServer | null = null;

  constructor(private world: World) {}

  /** Uruchamia nasłuch. Zwraca faktyczny port (przydatne w testach z portem 0). */
  listen(port = config.port, host = config.host): Promise<number> {
    return new Promise((resolve) => {
      this.wss = new WebSocketServer({ port, host, maxPayload: 8 * 1024 });
      this.wss.on('connection', (ws, req) => this.onConnection(ws, req));
      this.wss.on('listening', () => {
        const addr = this.wss!.address();
        resolve(addr && typeof addr === 'object' ? addr.port : port);
      });
    });
  }

  /** Zamyka serwer i czeka, aż wszyscy gracze zostaną wylogowani (i zapisani). */
  async close(): Promise<void> {
    const wss = this.wss;
    if (!wss) return;
    const closed = [...wss.clients].map((c) => new Promise<void>((r) => c.once('close', () => r())));
    for (const c of wss.clients) c.terminate();
    await Promise.all(closed);
    await new Promise<void>((r) => wss.close(() => r()));
    this.wss = null;
  }

  private onConnection(ws: WebSocket, req: IncomingMessage) {
    const conn = new WsConnection(ws);
    let player: Player | null = null;
    let msgCount = 0;
    let windowStart = Date.now();
    const ip = req.socket.remoteAddress ?? '?';

    ws.on('message', (data) => {
      // Ochrona przed floodem.
      const now = Date.now();
      if (now - windowStart > 1000) {
        windowStart = now;
        msgCount = 0;
      }
      if (++msgCount > config.maxMessagesPerSecond) {
        console.warn(`[net] flood z ${ip} – rozłączam`);
        ws.close(1008, 'flood');
        return;
      }

      let msg: Record<string, unknown>;
      try {
        msg = JSON.parse(data.toString());
      } catch {
        return;
      }
      if (typeof msg !== 'object' || msg === null || typeof msg.t !== 'string') return;

      if (msg.t === 'ping') {
        conn.send({ t: 'pong', ts: msg.ts });
        return;
      }
      if (!player) {
        if (msg.t === 'login' || msg.t === 'register') {
          player = this.authenticate(conn, msg);
          if (player) {
            console.log(`[auth] ${player.name} zalogowany (${ip})`);
            this.world.addPlayer(player);
          }
        }
        return;
      }
      try {
        this.world.handle(player, msg);
      } catch (e) {
        console.error('[world] błąd obsługi wiadomości', msg.t, e);
      }
    });

    ws.on('close', () => {
      if (player) {
        console.log(`[auth] ${player.name} wylogowany`);
        // Postać mogła zostać już przejęta przez nowe logowanie.
        if (this.world.players.get(player.id) === player) this.world.removePlayer(player);
      }
    });
    ws.on('error', () => {});
  }

  /** Logowanie lub rejestracja. Zwraca gracza albo null (błąd wysłany do klienta). */
  private authenticate(conn: Connection, msg: Record<string, unknown>): Player | null {
    const fail = (text: string) => {
      conn.send({ t: 'auth_error', text });
      return null;
    };
    if (Number(msg.v) !== config.protocolVersion)
      return fail('Nieaktualna wersja klienta – zaktualizuj grę.');
    const name = typeof msg.name === 'string' ? msg.name.trim() : '';
    const pass = msg.pass;
    const nameErr = validateName(name);
    if (nameErr) return fail(nameErr);
    const passErr = validatePassword(pass);
    if (passErr) return fail(passErr);
    const db = this.world.db;

    let account = db.findAccount(name);
    if (msg.t === 'register') {
      if (account) return fail('Ta nazwa jest już zajęta.');
      const accountId = db.createAccount(name, hashPassword(pass as string));
      const t = this.world.map.temple;
      db.createCharacter({
        account_id: accountId,
        name,
        x: t.x,
        y: t.y,
        level: 1,
        exp: 0,
        hp: maxHpForLevel(1),
        mp: maxMpForLevel(1),
        look: randInt(0, 7),
        skills: JSON.stringify(defaultSkills()),
        inventory: JSON.stringify(starterInventory().toJSON()),
      });
      account = db.findAccount(name)!;
      console.log(`[auth] nowe konto: ${name}`);
    } else if (!account || !verifyPassword(pass as string, account.pass_hash)) {
      return fail('Błędna nazwa lub hasło.');
    }

    const row = db.findCharacterByAccount(account.id);
    if (!row) return fail('Brak postaci na koncie.');

    // Podwójne logowanie – wyrzucamy starą sesję.
    const existing = this.world.findPlayerByCharId(row.id);
    if (existing) {
      this.world.sendSystem(existing, 'Zalogowano z innego urządzenia.');
      this.world.removePlayer(existing);
      existing.conn.close('relog');
    }

    const inv = JSON.parse(row.inventory);
    const skills = { ...defaultSkills(), ...(JSON.parse(row.skills) as Skills) };
    return new Player({
      charId: row.id,
      name: row.name,
      conn,
      x: row.x,
      y: row.y,
      hp: row.hp,
      mp: row.mp,
      exp: row.exp,
      look: row.look,
      skills,
      inventory: new Inventory(inv.bag, inv.equipment),
    });
  }
}
