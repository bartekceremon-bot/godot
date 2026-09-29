/**
 * Test integracyjny: prawdziwy serwer WebSocket + baza w pamięci + dwóch klientów.
 */
import { test, after, before } from 'node:test';
import assert from 'node:assert/strict';
import WebSocket from 'ws';
import { Database } from '../src/db/database';
import { World } from '../src/game/world';
import { GameServer } from '../src/net/server';
import { Monster } from '../src/game/entities';
import { MONSTERS } from '../src/game/data/monsters';

type Msg = Record<string, any>;

class TestClient {
  ws: WebSocket;
  inbox: Msg[] = [];
  private waiters: { pred: (m: Msg) => boolean; resolve: (m: Msg) => void }[] = [];

  constructor(port: number) {
    this.ws = new WebSocket(`ws://127.0.0.1:${port}`);
    this.ws.on('message', (d) => {
      const m = JSON.parse(d.toString());
      this.inbox.push(m);
      this.waiters = this.waiters.filter((w) => {
        if (w.pred(m)) {
          w.resolve(m);
          return false;
        }
        return true;
      });
    });
  }

  open() {
    return new Promise<void>((r) => this.ws.once('open', () => r()));
  }

  send(m: Msg) {
    this.ws.send(JSON.stringify(m));
  }

  /** Czeka na wiadomość spełniającą warunek (także już odebraną). */
  wait(pred: (m: Msg) => boolean, timeoutMs = 3000): Promise<Msg> {
    const found = this.inbox.find(pred);
    if (found) return Promise.resolve(found);
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error('timeout: ' + pred.toString())), timeoutMs);
      this.waiters.push({ pred, resolve: (m) => (clearTimeout(t), resolve(m)) });
    });
  }

  close() {
    this.ws.close();
  }
}

let db: Database;
let world: World;
let server: GameServer;
let port: number;

before(async () => {
  db = new Database(':memory:');
  world = new World(db);
  server = new GameServer(world);
  port = await server.listen(0, '127.0.0.1');
  world.start();
});

after(async () => {
  await server.close();
  world.stop();
  db.close();
});

test('rejestracja, logowanie, ruch, czat, widoczność innych graczy', async () => {
  const a = new TestClient(port);
  await a.open();
  a.send({ t: 'register', v: 2, name: 'Ala', pass: 'tajne1' });
  const welcome = await a.wait((m) => m.t === 'welcome');
  assert.equal(welcome.name, 'Ala');
  assert.equal(welcome.map.rows.length, welcome.map.h);
  assert.ok(welcome.items.length > 5);
  const pos = await a.wait((m) => m.t === 'pos');
  const inv = await a.wait((m) => m.t === 'inv');
  assert.equal(inv.eq.weapon.item, 'sword_t1');

  // Druga rejestracja tej samej nazwy musi się nie udać.
  const dup = new TestClient(port);
  await dup.open();
  dup.send({ t: 'register', v: 2, name: 'ala', pass: 'xxxx' });
  assert.match((await dup.wait((m) => m.t === 'auth_error')).text, /zajęta/);
  dup.close();

  // Drugi gracz widzi pierwszego.
  const b = new TestClient(port);
  await b.open();
  b.send({ t: 'register', v: 2, name: 'Bartek', pass: 'tajne2' });
  await b.wait((m) => m.t === 'welcome');
  await b.wait((m) => m.t === 'snap' && m.e.some((e: Msg) => e.n === 'Ala'));

  // Ruch na południe (świątynia -> posadzka).
  a.send({ t: 'move', d: 2 });
  await a.wait((m) => m.t === 'snap' && m.e.some((e: Msg) => e.n === 'Ala' && e.y === pos.y + 1));
  const player = [...world.players.values()].find((p) => p.name === 'Ala')!;
  assert.equal(player.y, pos.y + 1);

  // Zbyt szybki drugi krok zostaje odrzucony (anty-speedhack).
  a.send({ t: 'move', d: 2 });
  await a.wait((m) => m.t === 'pos' && m.y === pos.y + 1);

  // Czat dociera do drugiego gracza.
  a.send({ t: 'say', text: 'Cześć!' });
  const chat = await b.wait((m) => m.t === 'chat');
  assert.equal(chat.from, 'Ala');
  assert.equal(chat.text, 'Cześć!');

  // Czar leczący zużywa manę.
  player.hp = 50;
  a.send({ t: 'say', text: 'exura' });
  await a.wait((m) => m.t === 'fx' && m.l.some((f: Msg) => f.k === 'heal'));
  assert.ok(player.hp > 50);
  assert.ok(player.mp < player.maxMp());

  // Wylogowanie zapisuje pozycję; ponowne logowanie ją przywraca.
  a.close();
  await new Promise((r) => setTimeout(r, 200));
  const a2 = new TestClient(port);
  await a2.open();
  a2.send({ t: 'login', v: 2, name: 'Ala', pass: 'zle' });
  await a2.wait((m) => m.t === 'auth_error');
  a2.send({ t: 'login', v: 2, name: 'Ala', pass: 'tajne1' });
  const pos2 = await a2.wait((m) => m.t === 'pos');
  assert.equal(pos2.y, pos.y + 1);
  a2.close();
  b.close();
});

test('walka: zabicie potwora daje doświadczenie i loot, podniesienie lootu', async () => {
  const c = new TestClient(port);
  await c.open();
  c.send({ t: 'register', v: 2, name: 'Wojownik', pass: 'haslo' });
  await c.wait((m) => m.t === 'welcome');
  const p = [...world.players.values()].find((x) => x.name === 'Wojownik')!;

  // Teleportujemy gracza poza miasto i stawiamy obok niego szczura z 1 HP.
  p.x = 30;
  p.y = 48;
  const rat = new Monster({ ...MONSTERS.rat, loot: [{ item: 'gold', chance: 1, min: 5, max: 5 }], armor: 0, defense: 0 }, 31, 48, 0);
  rat.hp = 1;
  world.monsters.set(rat.id, rat);
  c.send({ t: 'attack', id: rat.id });
  await c.wait((m) => m.t === 'fx' && m.l.some((f: Msg) => f.k === 'death'));
  assert.ok(!world.monsters.has(rat.id));
  assert.equal(p.exp, MONSTERS.rat.exp);

  const snap = await c.wait((m) => m.t === 'snap' && m.g.some((g: Msg) => g.it === 'gold'));
  const gold = snap.g.find((g: Msg) => g.it === 'gold');
  const before = p.inventory.countOf('gold');
  c.send({ t: 'pickup', id: gold.i });
  await c.wait((m) => m.t === 'sys' && /Podnosisz/.test(m.text));
  assert.equal(p.inventory.countOf('gold'), before + 5);
  c.close();
});
