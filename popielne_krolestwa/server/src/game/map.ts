/**
 * Mapa świata: deterministyczny generator + zapytania o kafelki.
 *
 * Mapa jest siatką znaków (kafelków 32x32 po stronie klienta). Klient dostaje ją
 * w całości przy logowaniu – w ETAPIE 1 świat jest mały (jedno miasto + zielona strefa).
 *
 * Legenda kafelków:
 *   .  trawa            ,  droga / most        s  piasek
 *   f  posadzka miasta  x  posadzka świątyni   a  popiół
 *   #  mur              T  drzewo              r  skała
 *   ~  woda             D  skrzynia depozytu (ETAP 2)
 */
import { SeededRng } from '../util/rng';

export interface TileInfo {
  walkable: boolean;
  /** Czy kafelek zasłania linię strzału (łuk, czary dystansowe). */
  blocksSight: boolean;
  /** Strefa ochronna – brak walki, potwory nie wchodzą. */
  protectionZone: boolean;
}

const TILE_INFO: Record<string, TileInfo> = {
  '.': { walkable: true, blocksSight: false, protectionZone: false },
  ',': { walkable: true, blocksSight: false, protectionZone: false },
  s: { walkable: true, blocksSight: false, protectionZone: false },
  a: { walkable: true, blocksSight: false, protectionZone: false },
  f: { walkable: true, blocksSight: false, protectionZone: true },
  x: { walkable: true, blocksSight: false, protectionZone: true },
  '#': { walkable: false, blocksSight: true, protectionZone: false },
  T: { walkable: false, blocksSight: true, protectionZone: false },
  r: { walkable: false, blocksSight: true, protectionZone: false },
  '~': { walkable: false, blocksSight: false, protectionZone: false },
  D: { walkable: false, blocksSight: false, protectionZone: true },
};

const OUTSIDE: TileInfo = { walkable: false, blocksSight: true, protectionZone: false };

export interface SpawnPoint {
  monster: string;
  x: number;
  y: number;
  /** Ile potworów utrzymuje ten punkt. */
  count: number;
}

export interface Point {
  x: number;
  y: number;
}

export class GameMap {
  readonly width: number;
  readonly height: number;
  private tiles: string[][];
  /** Miejsce odrodzenia graczy (świątynia). */
  readonly temple: Point;
  readonly spawns: SpawnPoint[] = [];

  constructor(width: number, height: number, tiles: string[][], temple: Point, spawns: SpawnPoint[]) {
    this.width = width;
    this.height = height;
    this.tiles = tiles;
    this.temple = temple;
    this.spawns = spawns;
  }

  tileAt(x: number, y: number): string {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return '#';
    return this.tiles[y][x];
  }

  info(x: number, y: number): TileInfo {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return OUTSIDE;
    return TILE_INFO[this.tiles[y][x]] ?? OUTSIDE;
  }

  isWalkable(x: number, y: number): boolean {
    return this.info(x, y).walkable;
  }

  isProtectionZone(x: number, y: number): boolean {
    return this.info(x, y).protectionZone;
  }

  /** Linia wzroku (algorytm Bresenhama) – kafelki pośrednie nie mogą zasłaniać. */
  hasLineOfSight(x0: number, y0: number, x1: number, y1: number): boolean {
    let dx = Math.abs(x1 - x0);
    let dy = -Math.abs(y1 - y0);
    const sx = x0 < x1 ? 1 : -1;
    const sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    let x = x0;
    let y = y0;
    while (!(x === x1 && y === y1)) {
      if (!(x === x0 && y === y0) && this.info(x, y).blocksSight) return false;
      const e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y += sy;
      }
    }
    return true;
  }

  /** Wiersze mapy jako stringi – format wysyłany do klienta. */
  toRows(): string[] {
    return this.tiles.map((row) => row.join(''));
  }
}

// ---------------------------------------------------------------------------
// Generator świata
// ---------------------------------------------------------------------------

const MAP_W = 96;
const MAP_H = 96;
const WORLD_SEED = 1337;

/** Prostokąt miasta Popielgród (mury włącznie). */
export const CITY = { x0: 38, y0: 40, x1: 58, y1: 56 };

export function generateWorld(): GameMap {
  const rng = new SeededRng(WORLD_SEED);
  const t: string[][] = [];
  for (let y = 0; y < MAP_H; y++) t.push(new Array<string>(MAP_W).fill('.'));

  const set = (x: number, y: number, c: string) => {
    if (x >= 0 && y >= 0 && x < MAP_W && y < MAP_H) t[y][x] = c;
  };
  const get = (x: number, y: number) => (x >= 0 && y >= 0 && x < MAP_W && y < MAP_H ? t[y][x] : '#');

  // 1. Rozproszone drzewa i kępy lasu.
  for (let y = 0; y < MAP_H; y++) for (let x = 0; x < MAP_W; x++) if (rng.next() < 0.04) set(x, y, 'T');
  for (let i = 0; i < 30; i++) {
    const cx = rng.int(4, MAP_W - 5);
    const cy = rng.int(4, MAP_H - 5);
    const r = rng.int(2, 5);
    for (let y = cy - r; y <= cy + r; y++)
      for (let x = cx - r; x <= cx + r; x++)
        if ((x - cx) ** 2 + (y - cy) ** 2 <= r * r && rng.next() < 0.55) set(x, y, 'T');
  }

  // 2. Jeziora otoczone piaskiem.
  const lakes = [
    { x: 22, y: 70, rx: 7, ry: 5 },
    { x: 72, y: 66, rx: 5, ry: 7 },
    { x: 20, y: 24, rx: 5, ry: 4 },
  ];
  for (const l of lakes) {
    for (let y = l.y - l.ry - 2; y <= l.y + l.ry + 2; y++)
      for (let x = l.x - l.rx - 2; x <= l.x + l.rx + 2; x++) {
        const d = ((x - l.x) / l.rx) ** 2 + ((y - l.y) / l.ry) ** 2;
        if (d <= 1) set(x, y, '~');
        else if (d <= 1.6) set(x, y, 's');
      }
  }

  // 3. Popielisko na północnym wschodzie – spalona ziemia i skały (szkielety).
  for (let y = 0; y < MAP_H; y++)
    for (let x = 0; x < MAP_W; x++) {
      const d = ((x - 78) / 17) ** 2 + ((y - 17) / 14) ** 2;
      if (d <= 1) set(x, y, rng.next() < 0.07 ? 'r' : 'a');
    }

  // 4. Granica świata – gęsty las.
  for (let y = 0; y < MAP_H; y++)
    for (let x = 0; x < MAP_W; x++)
      if (x < 2 || y < 2 || x >= MAP_W - 2 || y >= MAP_H - 2) set(x, y, 'T');

  // 5. Miasto: wolna przestrzeń wokół, mury, posadzka, bramy, świątynia, depozyt.
  const c = CITY;
  for (let y = c.y0 - 3; y <= c.y1 + 3; y++) for (let x = c.x0 - 3; x <= c.x1 + 3; x++) set(x, y, '.');
  for (let y = c.y0; y <= c.y1; y++)
    for (let x = c.x0; x <= c.x1; x++) {
      const edge = x === c.x0 || x === c.x1 || y === c.y0 || y === c.y1;
      set(x, y, edge ? '#' : 'f');
    }
  const midX = Math.floor((c.x0 + c.x1) / 2);
  const midY = Math.floor((c.y0 + c.y1) / 2);
  // Bramy (2 kafelki szerokości) na każdej ścianie.
  for (const dx of [0, 1]) {
    set(midX + dx, c.y0, 'f');
    set(midX + dx, c.y1, 'f');
  }
  for (const dy of [0, 1]) {
    set(c.x0, midY + dy, 'f');
    set(c.x1, midY + dy, 'f');
  }
  // Świątynia (miejsce odrodzenia).
  for (let y = midY - 3; y <= midY - 1; y++) for (let x = midX - 2; x <= midX + 3; x++) set(x, y, 'x');
  // Skrzynie depozytu (aktywne od ETAPU 2).
  for (let x = c.x0 + 2; x <= c.x0 + 5; x++) set(x, c.y0 + 2, 'D');
  // Kilka murków wewnątrz – domy.
  for (let x = c.x1 - 6; x <= c.x1 - 2; x++) set(x, c.y1 - 4, '#');
  for (let y = c.y1 - 4; y <= c.y1 - 1; y++) set(c.x1 - 6, y, '#');
  set(c.x1 - 6, c.y1 - 2, 'f');

  // 6. Drogi od bram do krańców strefy.
  const road = (x0: number, y0: number, dx: number, dy: number, len: number) => {
    for (let i = 1; i <= len; i++)
      for (const w of [0, 1]) {
        const x = x0 + dx * i + (dy !== 0 ? w : 0);
        const y = y0 + dy * i + (dx !== 0 ? w : 0);
        if (x > 1 && y > 1 && x < MAP_W - 2 && y < MAP_H - 2) set(x, y, ',');
      }
  };
  road(midX, c.y0, 0, -1, c.y0 - 3);
  road(midX, c.y1, 0, 1, MAP_H - c.y1 - 4);
  road(c.x0, midY, -1, 0, c.x0 - 3);
  road(c.x1, midY, 1, 0, MAP_W - c.x1 - 4);

  const temple: Point = { x: midX, y: midY - 2 };

  // 7. Punkty odradzania potworów.
  const spawns: SpawnPoint[] = [
    // Szczury – tuż za murami.
    { monster: 'rat', x: 30, y: 44, count: 3 },
    { monster: 'rat', x: 64, y: 50, count: 3 },
    { monster: 'rat', x: 46, y: 33, count: 3 },
    { monster: 'rat', x: 52, y: 63, count: 3 },
    { monster: 'rat', x: 32, y: 60, count: 2 },
    // Wilki – dalej, w lasach.
    { monster: 'wolf', x: 16, y: 44, count: 3 },
    { monster: 'wolf', x: 40, y: 80, count: 3 },
    { monster: 'wolf', x: 58, y: 84, count: 2 },
    { monster: 'wolf', x: 12, y: 12, count: 2 },
    { monster: 'wolf', x: 44, y: 14, count: 2 },
    // Popielne szkielety – Popielisko.
    { monster: 'skeleton', x: 74, y: 20, count: 3 },
    { monster: 'skeleton', x: 84, y: 12, count: 2 },
    { monster: 'skeleton', x: 86, y: 26, count: 2 },
  ];
  for (const s of spawns)
    for (let y = s.y - 1; y <= s.y + 1; y++)
      for (let x = s.x - 1; x <= s.x + 1; x++) {
        const cur = get(x, y);
        if (!TILE_INFO[cur]?.walkable) set(x, y, cur === 'r' || s.monster === 'skeleton' ? 'a' : '.');
      }

  // 8. Gwarancja osiągalności: od każdego spawnu kopiemy ścieżkę w stronę świątyni,
  //    aż trafimy na obszar już połączony z miastem.
  const reach = floodFill(t, temple);
  for (const s of spawns) {
    let x = s.x;
    let y = s.y;
    while (!reach[y][x]) {
      if (Math.abs(temple.x - x) > Math.abs(temple.y - y)) x += Math.sign(temple.x - x);
      else y += Math.sign(temple.y - y);
      const cur = get(x, y);
      if (cur === '~') set(x, y, ',');
      else if (!TILE_INFO[cur].walkable) set(x, y, cur === 'r' ? 'a' : '.');
    }
    // Aktualizacja zasięgu po wykopaniu ścieżki.
    const r2 = floodFill(t, temple);
    for (let yy = 0; yy < MAP_H; yy++) for (let xx = 0; xx < MAP_W; xx++) reach[yy][xx] = r2[yy][xx];
  }

  return new GameMap(MAP_W, MAP_H, t, temple, spawns);
}

function floodFill(t: string[][], start: Point): boolean[][] {
  const h = t.length;
  const w = t[0].length;
  const seen: boolean[][] = [];
  for (let y = 0; y < h; y++) seen.push(new Array<boolean>(w).fill(false));
  const stack: Point[] = [start];
  seen[start.y][start.x] = true;
  while (stack.length) {
    const p = stack.pop()!;
    for (const [dx, dy] of [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ]) {
      const nx = p.x + dx;
      const ny = p.y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h || seen[ny][nx]) continue;
      if (!TILE_INFO[t[ny][nx]]?.walkable) continue;
      seen[ny][nx] = true;
      stack.push({ x: nx, y: ny });
    }
  }
  return seen;
}
