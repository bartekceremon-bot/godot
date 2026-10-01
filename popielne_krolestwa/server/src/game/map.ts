/**
 * Mapa świata: deterministyczny generator + zapytania o kafelki.
 *
 * Świat 224×224: trzy miasta w różnych krainach (Popielgród – łąki na południu, Szronogród – śniegi
 * na północnym zachodzie, Złotopiask – pustynia na północnym wschodzie), między nimi puszcza, góry
 * i moczary, a w sercu świata Czarna Strefa – Popielisko ze świątynią boga ognia, lawą i obeliskami.
 * Strefy ryzyka rosną od miast ku środkowi: zielona → żółta → czerwona → czarna.
 *
 * Legenda kafelków (klient dostaje mapę w całości przy logowaniu):
 *   .  trawa / ziemia       ,  droga               s  piasek brzegu     n  śnieg
 *   d  wydmy                a  popiół              o  obsydian          p  posadzka ruin
 *   i  lód (zamarznięte jezioro)                   =  most              c  pole uprawne
 *   f  posadzka miasta      x  posadzka świątyni   (obie – strefa ochronna)
 *   #  mur                  H  dom                 T  drzewo            r  skała
 *   ^  góry / urwisko       ~  woda                l  lawa              F  płot
 *   u  kolumna ruin         U  fontanna / studnia  O  obelisk terytorium
 *   D  skrzynia depozytu    M  stragan             K  kowadło           W  stół    P  piec
 */
import { SeededRng } from '../util/rng';
import { NodeKind } from './data/resources';
import { NPCS } from './data/npcs';
import {
  CITY_LIST,
  CITY_TEMPLATE,
  CITY_W,
  CITY_H,
  Biome,
  BIOME_CODE,
  CityDef,
  START_CITY,
  CITIES,
  cityTemple,
  cityCenter,
} from './data/cities';
import { monstersFor, MONSTERS } from './data/monsters';

export interface TileInfo {
  walkable: boolean;
  /** Czy kafelek zasłania linię strzału (łuk, czary dystansowe). */
  blocksSight: boolean;
  /** Strefa ochronna – brak walki, potwory nie wchodzą. */
  protectionZone: boolean;
}

const W_ = (blocksSight = false, pz = false): TileInfo => ({ walkable: true, blocksSight, protectionZone: pz });
const B_ = (blocksSight: boolean, pz = false): TileInfo => ({ walkable: false, blocksSight, protectionZone: pz });

const TILE_INFO: Record<string, TileInfo> = {
  '.': W_(), ',': W_(), s: W_(), a: W_(), n: W_(), d: W_(), o: W_(), p: W_(), i: W_(), '=': W_(), c: W_(),
  f: W_(false, true), x: W_(false, true),
  '#': B_(true), H: B_(true), T: B_(true), r: B_(true), '^': B_(true), u: B_(true), O: B_(true),
  '~': B_(false), l: B_(false), F: B_(false), U: B_(false, true),
  D: B_(false, true), M: B_(false, true), K: B_(false, true), W: B_(false, true), P: B_(false, true),
};

const OUTSIDE: TileInfo = { walkable: false, blocksSight: true, protectionZone: false };

export interface SpawnPoint {
  monster: string;
  x: number;
  y: number;
  /** Ile potworów utrzymuje ten punkt. */
  count: number;
  /** Boss świata (rozgłaszane pojawienie się i śmierć). */
  boss?: boolean;
}

/** Złoże surowca w świecie (drzewo, głaz, żyła rudy, włókna). */
export interface NodeSpawn {
  kind: NodeKind;
  tier: number;
  x: number;
  y: number;
}

export interface Point {
  x: number;
  y: number;
}

/** Obelisk terytorium w Czarnej Strefie. */
export interface TerritorySpot {
  id: string;
  name: string;
  x: number;
  y: number;
}

/**
 * Strefy ryzyka:
 *  - green  – bez PvP, śmierć kosztuje tylko trochę doświadczenia,
 *  - yellow – PvP z czaszkami, po śmierci tracisz część plecaka,
 *  - red    – pełne PvP i full loot,
 *  - black  – Popielisko: jak czerwona + terytoria gildii, T8 i Popielny Smok.
 */
export type Zone = 'green' | 'yellow' | 'red' | 'black';
export const ZONE_CODE: Record<Zone, string> = { green: 'g', yellow: 'y', red: 'r', black: 'b' };

export const MAP_W = 224;
export const MAP_H = 224;
export const CENTER: Point = { x: 112, y: 112 };
/** Promienie stref od środka świata (Popielisko) i od miast. */
export const BLACK_R = 30;
export const RED_R = 48;
export const YELLOW_R = 58;
export const CITY_GREEN = 38;
export const CITY_YELLOW = 64;
const WORLD_SEED = 1337;

const ZONE_RANK: Record<Zone, number> = { green: 0, yellow: 1, red: 2, black: 3 };

/** Informacje o mieście na mapie (wysyłane klientowi do mapy świata). */
export interface CityInfo {
  id: string;
  name: string;
  biome: Biome;
  x0: number;
  y0: number;
  w: number;
  h: number;
  temple: Point;
}

export class GameMap {
  readonly width: number;
  readonly height: number;
  private tiles: string[][];
  /** Miejsce odrodzenia nowych graczy (świątynia miasta startowego). */
  readonly temple: Point;
  readonly spawns: SpawnPoint[] = [];
  readonly nodes: NodeSpawn[] = [];
  readonly territories: TerritorySpot[] = [];
  readonly cities: CityInfo[] = [];
  private zones: Zone[][];
  private biomes: Biome[][];

  constructor(
    width: number,
    height: number,
    tiles: string[][],
    temple: Point,
    spawns: SpawnPoint[],
    nodes: NodeSpawn[] = [],
    opts: { zones?: Zone[][]; biomes?: Biome[][]; territories?: TerritorySpot[]; cities?: CityInfo[] } = {},
  ) {
    this.width = width;
    this.height = height;
    this.tiles = tiles;
    this.temple = temple;
    this.spawns = spawns;
    this.nodes = nodes;
    this.territories = opts.territories ?? [];
    this.cities = opts.cities ?? [];
    this.biomes = opts.biomes ?? tiles.map((row) => row.map(() => 'meadow' as Biome));
    this.zones =
      opts.zones ??
      tiles.map((row, y) =>
        row.map((c, x) => {
          if (TILE_INFO[c]?.protectionZone) return 'green';
          const d = Math.max(Math.abs(x - temple.x), Math.abs(y - temple.y));
          return d > 34 ? 'red' : d > 22 ? 'yellow' : 'green';
        }),
      );
  }

  zoneAt(x: number, y: number): Zone {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return 'red';
    return this.zones[y][x];
  }

  biomeAt(x: number, y: number): Biome {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return 'meadow';
    return this.biomes[y][x];
  }

  /** Strefy jako wiersze znaków g/y/r/b – wysyłane klientowi (minimapa, oznaczenia). */
  zoneRows(): string[] {
    return this.zones.map((row) => row.map((z) => ZONE_CODE[z]).join(''));
  }

  /** Krainy jako wiersze znaków (m, f, s, r, d, w, a) – klient dobiera wygląd terenu. */
  biomeRows(): string[] {
    return this.biomes.map((row) => row.map((b) => BIOME_CODE[b]).join(''));
  }

  tileAt(x: number, y: number): string {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return '^';
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

  /** Najbliższe miasto (do odrodzenia po śmierci bez ustawionego domu). */
  nearestCity(x: number, y: number): CityInfo {
    let best = this.cities[0];
    let bd = Infinity;
    for (const c of this.cities) {
      const d = Math.hypot(c.temple.x - x, c.temple.y - y);
      if (d < bd) {
        bd = d;
        best = c;
      }
    }
    return best;
  }
}

// ---------------------------------------------------------------------------
// Szum (deterministyczny) do kształtowania krain
// ---------------------------------------------------------------------------

function hash2(x: number, y: number, seed: number): number {
  let h = Math.imul(x, 374761393) + Math.imul(y, 668265263) + Math.imul(seed, 982451653);
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}

function vnoise(x: number, y: number, seed: number): number {
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  const xf = x - xi;
  const yf = y - yi;
  const sx = xf * xf * (3 - 2 * xf);
  const sy = yf * yf * (3 - 2 * yf);
  const a = hash2(xi, yi, seed);
  const b = hash2(xi + 1, yi, seed);
  const c = hash2(xi, yi + 1, seed);
  const d = hash2(xi + 1, yi + 1, seed);
  return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy;
}

/** Szum fraktalny 0..1. */
export function fbm(x: number, y: number, seed: number, octaves = 4): number {
  let amp = 0.5;
  let freq = 1;
  let sum = 0;
  let norm = 0;
  for (let i = 0; i < octaves; i++) {
    sum += vnoise(x * freq, y * freq, seed + i * 101) * amp;
    norm += amp;
    amp *= 0.5;
    freq *= 2;
  }
  return sum / norm;
}

// ---------------------------------------------------------------------------
// Generator świata
// ---------------------------------------------------------------------------

type Grid = string[][];

const GROUND: Record<Biome, string> = {
  meadow: '.',
  forest: '.',
  snow: 'n',
  mountain: '.',
  desert: 'd',
  swamp: '.',
  ash: 'a',
};

const GROUND_TILES = new Set(['.', 'n', 'd', 'a', 's', 'o']);

/** Kraina wg kąta od środka świata (z zaburzeniem szumem). */
function sectorBiome(x: number, y: number): Biome {
  let ang = (Math.atan2(y - CENTER.y, x - CENTER.x) * 180) / Math.PI + (fbm(x * 0.03, y * 0.03, 23) - 0.5) * 50;
  if (ang > 180) ang -= 360;
  if (ang <= -180) ang += 360;
  if (ang >= 45 && ang < 135) return 'meadow';
  if (ang >= 135 || ang < -160) return 'forest';
  if (ang < -110) return 'snow';
  if (ang < -70) return 'mountain';
  if (ang < -20) return 'desert';
  return 'swamp';
}

/** Tier terenu (złoża, potwory) wg strefy i odległości. */
export function tierAt(zone: Zone, cityDist: number, centerDist: number): number {
  switch (zone) {
    case 'black':
      return 8;
    case 'red':
      return centerDist < 42 ? 7 : 6;
    case 'yellow':
      return centerDist < 54 || cityDist > 52 ? 5 : 4;
    default:
      return cityDist < 23 ? 1 : cityDist < 30 ? 2 : 3;
  }
}

export function generateWorld(): GameMap {
  const rng = new SeededRng(WORLD_SEED);
  const W = MAP_W;
  const H = MAP_H;
  const t: Grid = [];
  const biome: Biome[][] = [];
  for (let y = 0; y < H; y++) {
    t.push(new Array<string>(W).fill('.'));
    biome.push(new Array<Biome>(W).fill('meadow'));
  }
  const inside = (x: number, y: number) => x >= 0 && y >= 0 && x < W && y < H;
  const set = (x: number, y: number, c: string) => {
    if (inside(x, y)) t[y][x] = c;
  };
  const get = (x: number, y: number) => (inside(x, y) ? t[y][x] : '^');
  const centers = CITY_LIST.map((c) => cityCenter(c));
  const cityDist = (x: number, y: number) => Math.min(...centers.map((c) => Math.hypot(x - c.x, y - c.y)));
  const centerDist = (x: number, y: number) => Math.hypot(x - CENTER.x, y - CENTER.y);
  /** Strefa wokół miasta, gdzie nie stawiamy przeszkód (mury + przedpole). */
  const nearCity = (x: number, y: number, m: number) =>
    CITY_LIST.some((c) => x >= c.x0 - m && y >= c.y0 - m && x < c.x0 + CITY_W + m && y < c.y0 + CITY_H + m);

  // 1. Krainy i grunt.
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      const dc = centerDist(x, y);
      let b: Biome;
      if (dc < BLACK_R + (fbm(x * 0.06, y * 0.06, 11) - 0.5) * 8) b = 'ash';
      else {
        b = sectorBiome(x, y);
        for (let i = 0; i < CITY_LIST.length; i++)
          if (Math.hypot(x - centers[i].x, y - centers[i].y) < 30 + (fbm(x * 0.07, y * 0.07, 13) - 0.5) * 16) b = CITY_LIST[i].biome;
      }
      biome[y][x] = b;
      t[y][x] = GROUND[b];
      // Wypalony pierścień wokół Popieliska – plamy popiołu.
      if (b !== 'ash' && dc < BLACK_R + 10 && hash2(x, y, 5) < (BLACK_R + 10 - dc) / 14) t[y][x] = 'a';
    }

  // 2. Góry (grzbiety szumu), mesy pustyni, iglice obsydianu na Popielisku.
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      const b = biome[y][x];
      const m = fbm(x * 0.05, y * 0.05, 31);
      const th = b === 'mountain' ? 0.56 : b === 'snow' ? 0.64 : b === 'desert' ? 0.66 : b === 'ash' ? 2 : 0.7;
      if (m > th) t[y][x] = '^';
      if (b === 'ash' && hash2(x, y, 9) > 0.985) t[y][x] = '^';
      if (x < 3 || y < 3 || x >= W - 3 || y >= H - 3) t[y][x] = '^';
    }

  // 3. Jeziora (w śniegach zamarznięte, na pustyni oazy z palmami).
  let lakes = 0;
  for (let attempt = 0; attempt < 400 && lakes < 18; attempt++) {
    const cx = rng.int(12, W - 13);
    const cy = rng.int(12, H - 13);
    const b = biome[cy][cx];
    if (b === 'ash' || b === 'swamp' || nearCity(cx, cy, 10) || centerDist(cx, cy) < BLACK_R + 8) continue;
    const oasis = b === 'desert';
    const rx = oasis ? rng.int(2, 4) : rng.int(3, 7);
    const ry = oasis ? rng.int(2, 3) : rng.int(3, 6);
    for (let y = cy - ry - 3; y <= cy + ry + 3; y++)
      for (let x = cx - rx - 3; x <= cx + rx + 3; x++) {
        if (!inside(x, y) || x < 4 || y < 4 || x >= W - 4 || y >= H - 4) continue;
        const wob = (fbm(x * 0.3, y * 0.3, 71) - 0.5) * 0.5;
        const d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + wob;
        if (d <= 1) set(x, y, b === 'snow' ? 'i' : '~');
        else if (d <= 1.7 && get(x, y) !== '~' && get(x, y) !== 'i') {
          if (b === 'snow') set(x, y, 'n');
          else if (oasis && hash2(x, y, 13) < 0.45) set(x, y, 'T');
          else set(x, y, 's');
        }
      }
    lakes++;
  }

  // 4. Stawy moczarów.
  for (let y = 4; y < H - 4; y++)
    for (let x = 4; x < W - 4; x++)
      if (biome[y][x] === 'swamp' && !nearCity(x, y, 6) && fbm(x * 0.14, y * 0.14, 41) > 0.63) set(x, y, '~');

  // 5. Rzeki: meandrujące od gór ku krawędziom świata.
  const river = (sx: number, sy: number, tx: number, ty: number, seed: number) => {
    let x = sx;
    let y = sy;
    for (let i = 0; i < 900; i++) {
      const base = Math.atan2(ty - y, tx - x);
      const ang = base + (fbm(i * 0.035, 0, seed) - 0.5) * 2.4;
      x += Math.cos(ang) * 0.7;
      y += Math.sin(ang) * 0.7;
      if (Math.hypot(tx - x, ty - y) < 2 || !inside(Math.round(x), Math.round(y))) break;
      const r = 1.3 + fbm(i * 0.02, 5, seed) * 0.9;
      for (let yy = Math.floor(y - r); yy <= Math.ceil(y + r); yy++)
        for (let xx = Math.floor(x - r); xx <= Math.ceil(x + r); xx++) {
          if (Math.hypot(xx - x, yy - y) > r || nearCity(xx, yy, 3) || !inside(xx, yy)) continue;
          if (centerDist(xx, yy) < BLACK_R + 4) continue;
          set(xx, yy, biome[yy]?.[xx] === 'snow' && hash2(xx, yy, 3) < 0.25 ? 'i' : '~');
        }
    }
  };
  river(108, 4, 4, 120, 81);
  river(220, 90, 150, 220, 82);
  river(60, 220, 4, 180, 83);

  // 6. Drzewa i skały zależne od krainy.
  for (let y = 3; y < H - 3; y++)
    for (let x = 3; x < W - 3; x++) {
      const c = t[y][x];
      if (!GROUND_TILES.has(c) || c === 's' || c === 'o') continue;
      const b = biome[y][x];
      const cl = fbm(x * 0.08, y * 0.08, 51);
      let p = 0;
      switch (b) {
        case 'meadow': p = 0.03 + Math.max(0, cl - 0.55) * 0.9; break;
        case 'forest': p = 0.12 + Math.max(0, cl - 0.4) * 1.1; break;
        case 'snow': p = 0.05 + Math.max(0, cl - 0.5) * 0.8; break;
        case 'mountain': p = 0.05 + Math.max(0, cl - 0.55) * 0.5; break;
        case 'desert': p = 0.012; break;
        case 'swamp': p = 0.08 + Math.max(0, cl - 0.5) * 0.6; break;
        case 'ash': p = 0.015; break;
      }
      const r = hash2(x, y, 17);
      if (r < p) t[y][x] = 'T';
      else if (r < p + (b === 'mountain' ? 0.05 : b === 'desert' ? 0.025 : b === 'snow' || b === 'ash' ? 0.02 : 0.008)) t[y][x] = 'r';
    }

  // 7. Serce Popieliska: świątynia boga ognia na obsydianowej wyspie otoczonej lawą.
  for (let y = CENTER.y - 40; y <= CENTER.y + 40; y++)
    for (let x = CENTER.x - 40; x <= CENTER.x + 40; x++) {
      if (!inside(x, y) || biome[y][x] !== 'ash') continue;
      const dc = centerDist(x, y);
      if (dc > 13 && fbm(x * 0.12, y * 0.12, 61) > 0.68) set(x, y, 'l');
      else if (dc > 13 && fbm(x * 0.1, y * 0.1, 62) > 0.66) set(x, y, 'o');
    }
  // Rzeki lawy od świątyni.
  for (let k = 0; k < 5; k++) {
    const a0 = (k * 72 + 36) * (Math.PI / 180);
    for (let r = 12; r < BLACK_R - 2; r += 0.5) {
      const a = a0 + (fbm(r * 0.08, k, 91) - 0.5) * 0.9;
      const x = Math.round(CENTER.x + Math.cos(a) * r);
      const y = Math.round(CENTER.y + Math.sin(a) * r);
      set(x, y, 'l');
      set(x + 1, y, 'l');
    }
  }
  for (let y = CENTER.y - 14; y <= CENTER.y + 14; y++)
    for (let x = CENTER.x - 14; x <= CENTER.x + 14; x++) {
      const dc = centerDist(x, y);
      if (dc <= 8.5) set(x, y, 'o');
      else if (dc <= 11.5) set(x, y, 'l');
      else if (dc <= 13) set(x, y, 'a');
    }
  for (let k = 0; k < 12; k++) {
    const a = (k * 30 + 15) * (Math.PI / 180);
    set(Math.round(CENTER.x + Math.cos(a) * 6.5), Math.round(CENTER.y + Math.sin(a) * 6.5), 'u');
  }
  // Mosty nad fosą lawy (N, S, E, W).
  for (let r = 8; r <= 13; r++)
    for (const w of [0, 1]) {
      set(CENTER.x + w, CENTER.y - r, r <= 12 ? '=' : 'a');
      set(CENTER.x + w, CENTER.y + r, r <= 12 ? '=' : 'a');
      set(CENTER.x - r, CENTER.y + w, r <= 12 ? '=' : 'a');
      set(CENTER.x + r, CENTER.y + w, r <= 12 ? '=' : 'a');
    }

  // 8. Obeliski terytoriów (6 wokół świątyni).
  const TERRITORY_NAMES = ['Żarowa Brama', 'Szklane Pole', 'Kocioł Iskier', 'Grań Popiołów', 'Krwawy Bród', 'Wzgórze Pogorzelców'];
  const territories: TerritorySpot[] = [];
  for (let k = 0; k < 6; k++) {
    const a = (k * 60 + 30) * (Math.PI / 180);
    const x = Math.round(CENTER.x + Math.cos(a) * 20);
    const y = Math.round(CENTER.y + Math.sin(a) * 20);
    for (let yy = y - 3; yy <= y + 3; yy++)
      for (let xx = x - 3; xx <= x + 3; xx++) if (Math.hypot(xx - x, yy - y) <= 3.2) set(xx, yy, Math.hypot(xx - x, yy - y) <= 2 ? 'o' : 'a');
    set(x, y, 'O');
    territories.push({ id: `terr_${k + 1}`, name: TERRITORY_NAMES[k], x, y });
  }

  // 9. Miasta: przedpole bez przeszkód i szablon.
  for (const c of CITY_LIST) {
    for (let y = c.y0 - 5; y < c.y0 + CITY_H + 5; y++)
      for (let x = c.x0 - 5; x < c.x0 + CITY_W + 5; x++) if (inside(x, y)) t[y][x] = GROUND[c.biome];
    CITY_TEMPLATE.forEach((row, dy) => {
      for (let dx = 0; dx < row.length; dx++) {
        const ch = row[dx];
        set(c.x0 + dx, c.y0 + dy, ch >= '1' && ch <= '9' ? 'f' : ch);
      }
    });
  }

  // 10. Drogi łączące miasta i świątynię Popieliska (A* po koszcie terenu, mosty nad wodą i lawą).
  const gate = (c: CityDef, side: 'n' | 's' | 'w' | 'e'): Point => {
    switch (side) {
      case 'n': return { x: c.x0 + 15, y: c.y0 - 1 };
      case 's': return { x: c.x0 + 15, y: c.y0 + CITY_H };
      case 'w': return { x: c.x0 - 1, y: c.y0 + 12 };
      default: return { x: c.x0 + CITY_W, y: c.y0 + 12 };
    }
  };
  const P = CITIES.popielgrod;
  const S = CITIES.szronogrod;
  const Z = CITIES.zlotopiask;
  const roads: [Point, Point][] = [
    [gate(P, 'w'), gate(S, 's')],
    [gate(P, 'e'), gate(Z, 's')],
    [gate(S, 'e'), gate(Z, 'w')],
    [gate(P, 'n'), { x: CENTER.x, y: CENTER.y + 13 }],
    [gate(S, 'e'), { x: CENTER.x - 13, y: CENTER.y }],
    [gate(Z, 'w'), { x: CENTER.x + 13, y: CENTER.y }],
    [gate(S, 'n'), { x: S.x0 + 15, y: 8 }],
    [gate(S, 'w'), { x: 8, y: S.y0 + 12 }],
    [gate(Z, 'n'), { x: Z.x0 + 15, y: 8 }],
    [gate(Z, 'e'), { x: W - 9, y: Z.y0 + 12 }],
    [gate(P, 's'), { x: P.x0 + 15, y: H - 7 }],
    [{ x: CENTER.x, y: CENTER.y - 13 }, { x: CENTER.x, y: 30 }],
  ];
  const roadTiles: Point[] = [];
  for (const [a, b] of roads) {
    const path = roadPath(t, a, b);
    for (let i = 0; i < path.length; i++) {
      const p = path[i];
      const next = path[Math.min(i + 1, path.length - 1)];
      const horiz = Math.abs(next.x - p.x) >= Math.abs(next.y - p.y);
      for (const q of [p, horiz ? { x: p.x, y: p.y + 1 } : { x: p.x + 1, y: p.y }]) {
        const cur = get(q.x, q.y);
        if ('fx#HDMKWPUO'.includes(cur) || q.x < 3 || q.y < 3 || q.x >= W - 3 || q.y >= H - 3) continue;
        set(q.x, q.y, cur === '~' || cur === 'l' || cur === 'i' || cur === '=' ? '=' : ',');
        roadTiles.push(q);
      }
    }
  }

  // 11. Wioski przy drogach w zielonej strefie: domy, pola uprawne z płotami, studnia.
  const villages: Point[] = [];
  for (let attempt = 0; attempt < 3000 && villages.length < 9; attempt++) {
    const r = roadTiles[rng.int(0, roadTiles.length - 1)];
    const d = cityDist(r.x, r.y);
    if (d < 20 || d > 34 || centerDist(r.x, r.y) < YELLOW_R + 4) continue;
    if (villages.some((v) => Math.hypot(v.x - r.x, v.y - r.y) < 22)) continue;
    const side = rng.next() < 0.5 ? -1 : 1;
    const horizRoad = get(r.x + 1, r.y) === ',' && get(r.x - 1, r.y) === ',';
    const vx = r.x + (horizRoad ? 0 : side * 10);
    const vy = r.y + (horizRoad ? side * 10 : 0);
    if (!placeVillage(t, biome, vx, vy, rng)) continue;
    villages.push({ x: vx, y: vy });
  }

  // 12. Ruiny strażnic w dziczy (żółta i czerwona strefa).
  let ruins = 0;
  for (let attempt = 0; attempt < 2000 && ruins < 14; attempt++) {
    const x = rng.int(10, W - 11);
    const y = rng.int(10, H - 11);
    const dc = centerDist(x, y);
    if (dc < BLACK_R + 4 || cityDist(x, y) < 30) continue;
    let ok = true;
    for (let yy = y - 4; yy <= y + 4 && ok; yy++)
      for (let xx = x - 4; xx <= x + 4; xx++) if (!GROUND_TILES.has(get(xx, yy)) && get(xx, yy) !== 'T' && get(xx, yy) !== 'r') ok = false;
    if (!ok) continue;
    for (let yy = y - 4; yy <= y + 4; yy++)
      for (let xx = x - 4; xx <= x + 4; xx++) {
        const d = Math.hypot(xx - x, yy - y);
        if (d <= 3.4) set(xx, yy, 'p');
        else if (d <= 4.4 && get(xx, yy) === 'T') set(xx, yy, GROUND[biome[yy][xx]]);
      }
    for (let k = 0; k < 10; k++) {
      if (hash2(x, k, 7) < 0.3) continue;
      const a = (k * 36 * Math.PI) / 180;
      set(Math.round(x + Math.cos(a) * 3.4), Math.round(y + Math.sin(a) * 3.4), 'u');
    }
    ruins++;
  }

  // 13. Strefy.
  const zones: Zone[][] = [];
  for (let y = 0; y < H; y++) {
    const row: Zone[] = [];
    for (let x = 0; x < W; x++) {
      const c = t[y][x];
      if (TILE_INFO[c]?.protectionZone) {
        row.push('green');
        continue;
      }
      const dc = centerDist(x, y);
      const cd = cityDist(x, y);
      const byCenter: Zone = dc < BLACK_R || biome[y][x] === 'ash' ? 'black' : dc < RED_R ? 'red' : dc < YELLOW_R ? 'yellow' : 'green';
      const byCity: Zone = cd <= CITY_GREEN ? 'green' : cd <= CITY_YELLOW ? 'yellow' : 'red';
      row.push(ZONE_RANK[byCenter] >= ZONE_RANK[byCity] ? byCenter : byCity);
    }
    zones.push(row);
  }

  // 14. Łączność: odcięte obszary przekopujemy do obszaru połączonego z miastem startowym.
  const start = cityTemple(CITIES[START_CITY]);
  connectRegions(t, start);

  // 15. Bossowie świata – w najdalszych, czerwonych zakątkach swoich krain; smok w świątyni.
  const spawns: SpawnPoint[] = [];
  const bossSpot = (b: Biome): Point | null => {
    let best: Point | null = null;
    let bd = -1;
    for (let y = 8; y < H - 8; y += 2)
      for (let x = 8; x < W - 8; x += 2) {
        if (biome[y][x] !== b || zones[y][x] !== 'red') continue;
        const score = cityDist(x, y) - Math.abs(centerDist(x, y) - (BLACK_R + 12)) * 0.5;
        if (score > bd) {
          bd = score;
          best = { x, y };
        }
      }
    return best;
  };
  for (const [monster, b] of [['frost_king', 'snow'], ['sand_worm', 'desert'], ['bog_mother', 'swamp']] as [string, Biome][]) {
    const p = bossSpot(b);
    if (!p) continue;
    for (let yy = p.y - 3; yy <= p.y + 3; yy++)
      for (let xx = p.x - 3; xx <= p.x + 3; xx++) if (Math.hypot(xx - p.x, yy - p.y) <= 3.3) set(xx, yy, GROUND[b] === 'n' ? 'n' : GROUND[b]);
    spawns.push({ monster, x: p.x, y: p.y, count: 1, boss: true });
  }
  spawns.push({ monster: 'ash_dragon', x: CENTER.x, y: CENTER.y - 3, count: 1, boss: true });
  connectRegions(t, start);

  // 16. Zwykłe punkty odradzania potworów – siatka z losowym przesunięciem.
  const reach = floodFill(t, start);
  for (let gy = 6; gy < H - 6; gy += 11)
    for (let gx = 6; gx < W - 6; gx += 11) {
      if (rng.next() < 0.28) continue;
      let x = gx + rng.int(-3, 3);
      let y = gy + rng.int(-3, 3);
      // Kafelek zajęty (drzewo, woda)? Szukamy wolnego w pobliżu.
      for (let k = 0; k < 12 && !(inside(x, y) && reach[y][x]); k++) {
        x = gx + rng.int(-4, 4);
        y = gy + rng.int(-4, 4);
      }
      if (!inside(x, y) || !reach[y][x] || TILE_INFO[t[y][x]].protectionZone) continue;
      const cd = cityDist(x, y);
      if (cd < 18 || t[y][x] === ',' || t[y][x] === '=') continue;
      if (spawns.some((s) => s.boss && Math.hypot(s.x - x, s.y - y) < 8)) continue;
      const zone = zones[y][x];
      const tier = tierAt(zone, cd, centerDist(x, y));
      const opts = monstersFor(biome[y][x], tier);
      const def = opts[rng.int(0, opts.length - 1)];
      spawns.push({ monster: def.id, x, y, count: tier >= 7 ? 2 : rng.int(2, 3) });
    }

  const nodes = placeNodes(t, biome, zones, rng, spawns, reach, cityDist, centerDist);
  const cities: CityInfo[] = CITY_LIST.map((c) => ({
    id: c.id,
    name: c.name,
    biome: c.biome,
    x0: c.x0,
    y0: c.y0,
    w: CITY_W,
    h: CITY_H,
    temple: cityTemple(c),
  }));
  return new GameMap(W, H, t, start, spawns, nodes, { zones, biomes: biome, territories, cities });
}

/** Wioska: 3–4 domy, pole z płotem, studnia. Zwraca false, gdy teren nie pasuje. */
function placeVillage(t: Grid, biome: Biome[][], vx: number, vy: number, rng: SeededRng): boolean {
  const H = t.length;
  const W = t[0].length;
  for (let y = vy - 7; y <= vy + 7; y++)
    for (let x = vx - 7; x <= vx + 7; x++) {
      if (x < 4 || y < 4 || x >= W - 4 || y >= H - 4) return false;
      const c = t[y][x];
      if (!(GROUND_TILES.has(c) || c === 'T' || c === 'r') || c === 'o') return false;
    }
  const g = GROUND[biome[vy][vx]];
  for (let y = vy - 7; y <= vy + 7; y++) for (let x = vx - 7; x <= vx + 7; x++) t[y][x] = g;
  const houses: [number, number, number, number][] = [
    [-6, -6, 4, 3],
    [2, -6, 3, 3],
    [-6, 2, 3, 3],
  ];
  if (rng.next() < 0.6) houses.push([3, 3, 4, 3]);
  for (const [hx, hy, hw, hh] of houses)
    for (let y = 0; y < hh; y++) for (let x = 0; x < hw; x++) t[vy + hy + y][vx + hx + x] = 'H';
  // Pole uprawne w płocie (z furtką).
  const fx0 = vx - 1;
  const fy0 = vy + 2;
  const fw = 3;
  const fh = 4;
  if (!(houses.length === 4)) {
    for (let y = fy0 - 1; y <= fy0 + fh; y++)
      for (let x = fx0 - 1; x <= fx0 + fw; x++) {
        const edge = y === fy0 - 1 || y === fy0 + fh || x === fx0 - 1 || x === fx0 + fw;
        t[y][x] = edge ? (x === fx0 + 1 && y === fy0 - 1 ? g : 'F') : 'c';
      }
  } else {
    for (let y = fy0; y < fy0 + 3; y++) for (let x = fx0 - 1; x < fx0 + 2; x++) t[y][x] = 'c';
  }
  t[vy - 1][vx] = 'U';
  return true;
}

/** Ścieżka drogi – A* po koszcie terenu (omija góry i wodę, gdy się da). */
function roadPath(t: Grid, from: Point, to: Point): Point[] {
  const H = t.length;
  const W = t[0].length;
  const cost = (c: string): number => {
    switch (c) {
      case ',':
      case '=':
        return 0.6;
      case '.':
      case 'n':
      case 'd':
      case 'a':
      case 's':
      case 'o':
      case 'p':
      case 'c':
        return 1;
      case 'T':
        return 2.5;
      case 'r':
        return 3;
      case 'i':
      case '~':
        return 7;
      case 'l':
        return 12;
      case '^':
        return 14;
      default:
        return Infinity;
    }
  };
  const idx = (x: number, y: number) => y * W + x;
  const g = new Float64Array(W * H).fill(Infinity);
  const came = new Int32Array(W * H).fill(-1);
  const heap = new MinHeap();
  g[idx(from.x, from.y)] = 0;
  heap.push(0, idx(from.x, from.y));
  const goal = idx(to.x, to.y);
  const dirs = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];
  while (heap.size) {
    const cur = heap.pop();
    if (cur === goal) break;
    const cx = cur % W;
    const cy = (cur - cx) / W;
    for (const [dx, dy] of dirs) {
      const nx = cx + dx;
      const ny = cy + dy;
      if (nx < 1 || ny < 1 || nx >= W - 1 || ny >= H - 1) continue;
      const c = cost(t[ny][nx]);
      if (!Number.isFinite(c)) continue;
      // Kara za zakręt w pobliżu – drogi są prostsze.
      const ng = g[cur] + c + (fbm(nx * 0.2, ny * 0.2, 97) * 0.4);
      const ni = idx(nx, ny);
      if (ng < g[ni]) {
        g[ni] = ng;
        came[ni] = cur;
        heap.push(ng + (Math.abs(to.x - nx) + Math.abs(to.y - ny)) * 0.6, ni);
      }
    }
  }
  const path: Point[] = [];
  let c = goal;
  if (came[c] === -1 && c !== idx(from.x, from.y)) return path;
  while (c !== -1) {
    path.push({ x: c % W, y: Math.floor(c / W) });
    c = came[c];
  }
  return path.reverse();
}

class MinHeap {
  private k: number[] = [];
  private v: number[] = [];
  get size() {
    return this.k.length;
  }
  push(key: number, val: number) {
    this.k.push(key);
    this.v.push(val);
    let i = this.k.length - 1;
    while (i > 0) {
      const p = (i - 1) >> 1;
      if (this.k[p] <= this.k[i]) break;
      [this.k[p], this.k[i]] = [this.k[i], this.k[p]];
      [this.v[p], this.v[i]] = [this.v[i], this.v[p]];
      i = p;
    }
  }
  pop(): number {
    const top = this.v[0];
    const lk = this.k.pop()!;
    const lv = this.v.pop()!;
    if (this.k.length) {
      this.k[0] = lk;
      this.v[0] = lv;
      let i = 0;
      for (;;) {
        const l = i * 2 + 1;
        const r = l + 1;
        let m = i;
        if (l < this.k.length && this.k[l] < this.k[m]) m = l;
        if (r < this.k.length && this.k[r] < this.k[m]) m = r;
        if (m === i) break;
        [this.k[m], this.k[i]] = [this.k[i], this.k[m]];
        [this.v[m], this.v[i]] = [this.v[i], this.v[m]];
        i = m;
      }
    }
    return top;
  }
}

/**
 * Łączy odcięte obszary z obszarem miasta startowego: dla każdego większego odciętego regionu
 * szuka najtańszej drogi (0–1 BFS: przejście przez przeszkodę kosztuje 1) i przekopuje przeszkody.
 */
function connectRegions(t: Grid, start: Point) {
  const H = t.length;
  const W = t[0].length;
  for (let round = 0; round < 60; round++) {
    const reach = floodFill(t, start);
    // Znajdź największy nieosiągalny region chodliwy.
    const seen: boolean[][] = reach.map((r) => r.slice());
    let target: Point | null = null;
    let size = 0;
    for (let y = 3; y < H - 3 && !target; y++)
      for (let x = 3; x < W - 3; x++) {
        if (seen[y][x] || !TILE_INFO[t[y][x]]?.walkable) continue;
        const reg = floodFillFrom(t, { x, y }, seen);
        if (reg >= 25) {
          target = { x, y };
          size = reg;
          break;
        }
      }
    if (!target) return;
    // 0–1 BFS od regionu do obszaru osiągalnego.
    const dist = new Int32Array(W * H).fill(1 << 30);
    const prev = new Int32Array(W * H).fill(-1);
    const dq: number[] = [];
    const si = target.y * W + target.x;
    dist[si] = 0;
    dq.push(si);
    let found = -1;
    let head = 0;
    const front: number[] = [];
    while (head < dq.length || front.length) {
      const cur = front.length ? front.pop()! : dq[head++];
      const cx = cur % W;
      const cy = (cur - cx) / W;
      if (reach[cy][cx]) {
        found = cur;
        break;
      }
      for (const [dx, dy] of [
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ]) {
        const nx = cx + dx;
        const ny = cy + dy;
        if (nx < 3 || ny < 3 || nx >= W - 3 || ny >= H - 3) continue;
        const c = t[ny][nx];
        if ('#HfxDMKWPUO'.includes(c)) continue;
        const w = TILE_INFO[c]?.walkable ? 0 : 1;
        const ni = ny * W + nx;
        if (dist[cur] + w < dist[ni]) {
          dist[ni] = dist[cur] + w;
          prev[ni] = cur;
          if (w === 0) front.push(ni);
          else dq.push(ni);
        }
      }
    }
    if (found < 0) return;
    for (let c = found; c !== -1; c = prev[c]) {
      const x = c % W;
      const y = (c - x) / W;
      const ch = t[y][x];
      if (TILE_INFO[ch]?.walkable) continue;
      t[y][x] = ch === '~' || ch === 'l' ? '=' : ch === '^' || ch === 'r' || ch === 'u' ? 'p' : '.';
    }
    if (size < 0) return;
  }
}

function floodFillFrom(t: Grid, start: Point, seen: boolean[][]): number {
  const h = t.length;
  const w = t[0].length;
  const stack: Point[] = [start];
  seen[start.y][start.x] = true;
  let n = 0;
  while (stack.length) {
    const p = stack.pop()!;
    n++;
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
  return n;
}

/**
 * Rozmieszcza złoża surowców. Tier zależy od strefy (zielona T1–T3, żółta T4–T5, czerwona T6–T7,
 * czarna T8), a rodzaj od krainy (puszcza – drewno, góry – ruda i kamień, moczary – włókna…).
 */
function placeNodes(
  t: Grid,
  biome: Biome[][],
  zones: Zone[][],
  rng: SeededRng,
  spawns: SpawnPoint[],
  reach: boolean[][],
  cityDist: (x: number, y: number) => number,
  centerDist: (x: number, y: number) => number,
): NodeSpawn[] {
  const H = t.length;
  const W = t[0].length;
  const nodes: NodeSpawn[] = [];
  const taken = new Set<string>();
  for (const n of NPCS) taken.add(`${n.x},${n.y}`);
  for (const s of spawns) taken.add(`${s.x},${s.y}`);
  const WEIGHTS: Record<Biome, [NodeKind, number][]> = {
    meadow: [['wood', 3], ['stone', 2], ['ore', 2], ['fiber', 3]],
    forest: [['wood', 6], ['fiber', 3], ['stone', 1], ['ore', 1]],
    snow: [['wood', 3], ['ore', 3], ['stone', 2], ['fiber', 1]],
    mountain: [['ore', 5], ['stone', 5], ['wood', 1]],
    desert: [['stone', 5], ['ore', 2], ['fiber', 3]],
    swamp: [['fiber', 6], ['wood', 3], ['stone', 1]],
    ash: [['ore', 4], ['stone', 4], ['wood', 1], ['fiber', 1]],
  };
  const target = 760;
  for (let attempt = 0; attempt < 60000 && nodes.length < target; attempt++) {
    const x = rng.int(4, W - 5);
    const y = rng.int(4, H - 5);
    const tile = t[y][x];
    if (!GROUND_TILES.has(tile) || !reach[y][x] || taken.has(`${x},${y}`)) continue;
    const cd = cityDist(x, y);
    if (cd < 16) continue;
    let free = 0;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) if (TILE_INFO[t[y + dy][x + dx]]?.walkable) free++;
    if (free < 8) continue;
    const b = biome[y][x];
    const tier = tierAt(zones[y][x], cd, centerDist(x, y));
    const ws = WEIGHTS[b];
    let r = rng.next() * ws.reduce((a, [, w]) => a + w, 0);
    let kind: NodeKind = ws[0][0];
    for (const [k, w] of ws) {
      r -= w;
      if (r <= 0) {
        kind = k;
        break;
      }
    }
    for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) taken.add(`${x + dx},${y + dy}`);
    nodes.push({ kind, tier, x, y });
  }
  return nodes;
}

export function floodFill(t: string[][], start: Point): boolean[][] {
  const h = t.length;
  const w = t[0].length;
  const seen: boolean[][] = [];
  for (let y = 0; y < h; y++) seen.push(new Array<boolean>(w).fill(false));
  floodFillFrom(t, start, seen);
  return seen;
}

/** Czy potwór o tym id jest bossem (używane przy rozgłaszaniu). */
export function isBoss(id: string): boolean {
  return !!MONSTERS[id]?.boss;
}
