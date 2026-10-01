/**
 * Trzy miasta startowe (jak w koncepcji świata) – każde w innej krainie i z inną premią rzemieślniczą.
 * Wszystkie budowane są z jednego szablonu (mury, bramy, świątynia, domy, stacje, NPC),
 * a klient 3D nadaje im wygląd zależny od krainy (śnieżne dachy, glinianie domy pustyni…).
 */
import type { Station } from './recipes';

export type Biome = 'meadow' | 'forest' | 'snow' | 'mountain' | 'desert' | 'swamp' | 'ash';

/** Kody krain wysyłane klientowi (jeden znak na kafelek). */
export const BIOME_CODE: Record<Biome, string> = {
  meadow: 'm',
  forest: 'f',
  snow: 's',
  mountain: 'r',
  desert: 'd',
  swamp: 'w',
  ash: 'a',
};

/** Szablon miasta 31×25. Cyfry = NPC (stoją na posadzce), U = fontanna, H = dom, T = drzewo. */
export const CITY_TEMPLATE = [
  '###############ff##############',
  '#fffffffffffffffffffffffffffff#',
  '#fDDDDffHHHHffffffffHHHfMMMMMf#',
  '#fff1fffHHHHffffffffHHHfff2fff#',
  '#fffffffffffffffffffffffffffff#',
  '#fHHHHHffffffxxxxxxfffffHHHHHf#',
  '#fHHHHHffffffxxxxxx7ffffHHHHHf#',
  '#fHHHHHffffffxxxxxxfffffHHHHHf#',
  '#fHHHHHfffffffffffffffffHHHHHf#',
  '#fffffffffffffffffffffffffffff#',
  '#ffffffffTfffffUUfffffTfff9fff#',
  '#ffffffffffffffUUfffffffffffff#',
  'fffffffffffffffffffffffffffffff',
  'fffffffffffffffffffffffffffffff',
  '#ffffffffTffffffffffffTfffffff#',
  '#fHHHHffffffffffffffffffHHHHHf#',
  '#fHHHHffffffffffffffffffHHHHHf#',
  '#fHHHHfffHHHHffffffHHHHfHHHHHf#',
  '#ffffffffHHHHffffffHHHHfffffff#',
  '#fPffffffHHHHffffffHHHHfffffff#',
  '#ff6ffffffffffffffffffffffffff#',
  '#ffff4fff5fff3ffffffffHHHHH8ff#',
  '#ffffKfffWffffffffffffHHHHHfff#',
  '#fffffffffffffffffffffffffffff#',
  '###############ff##############',
];
export const CITY_W = 31;
export const CITY_H = 25;
/** Miejsce odrodzenia (środek świątyni) względem lewego górnego rogu szablonu. */
export const CITY_TEMPLE = { x: 15, y: 6 };

/** Role NPC odpowiadające cyfrom w szablonie. */
export const NPC_ROLES = ['', 'banker', 'market', 'trader', 'smith', 'crafter', 'refiner', 'priest', 'stable', 'guild'] as const;
export type NpcRole = (typeof NPC_ROLES)[number];

export interface CityDef {
  id: string;
  name: string;
  biome: Biome;
  /** Lewy górny róg szablonu na mapie. */
  x0: number;
  y0: number;
  bonusText: string;
  /** Zwrot materiałów przy rafinacji (0..1). */
  refiningReturn: number;
  /** Zwrot materiałów przy rzemiośle – domyślny i dla wyróżnionej stacji. */
  craftingReturn: number;
  stationReturn?: Partial<Record<Station, number>>;
  /** Premia do jakości przy rzemiośle w wybranej stacji. */
  qualityBonusStation?: Station;
  qualityBonus: number;
  /** Podatek od sprzedaży na rynku (0..1). */
  marketTax: number;
  /** Imiona NPC wg roli. */
  npcNames: Record<Exclude<NpcRole, ''>, string>;
  /** Wierzchowce w stajni (id przedmiotu, cena). */
  mounts: { item: string; price: number }[];
}

export const CITY_LIST: CityDef[] = [
  {
    id: 'popielgrod',
    name: 'Popielgród',
    biome: 'meadow',
    x0: 97,
    y0: 184,
    bonusText: 'Rafineria Popielgrodu zwraca 25% materiałów (inne stacje 15%).',
    refiningReturn: 0.25,
    craftingReturn: 0.15,
    qualityBonus: 0,
    marketTax: 0.03,
    npcNames: {
      banker: 'Bankier Oskar',
      market: 'Rynkowa Wanda',
      trader: 'Kupiec Borys',
      smith: 'Kowal Gerwazy',
      crafter: 'Rzemieślniczka Jadwiga',
      refiner: 'Rafinator Zenon',
      priest: 'Kapłanka Wiesława',
      stable: 'Stajenny Maciej',
      guild: 'Mistrz gildii Zawisza',
    },
    mounts: [
      { item: 'mount_horse', price: 900 },
      { item: 'mount_warwolf', price: 9000 },
    ],
  },
  {
    id: 'szronogrod',
    name: 'Szronogród',
    biome: 'snow',
    x0: 29,
    y0: 44,
    bonusText: 'Kuźnia Szronogrodu zwraca 25% materiałów i częściej daje lepszą jakość.',
    refiningReturn: 0.15,
    craftingReturn: 0.15,
    stationReturn: { forge: 0.25 },
    qualityBonusStation: 'forge',
    qualityBonus: 4,
    marketTax: 0.04,
    npcNames: {
      banker: 'Bankier Ignacy',
      market: 'Rynkowa Halina',
      trader: 'Kupiec Stefan',
      smith: 'Kowal Bogdan',
      crafter: 'Rzemieślniczka Zofia',
      refiner: 'Rafinator Leon',
      priest: 'Kapłan Mieczysław',
      stable: 'Stajenny Olaf',
      guild: 'Mistrz gildii Wit',
    },
    mounts: [
      { item: 'mount_horse', price: 900 },
      { item: 'mount_elk', price: 3500 },
    ],
  },
  {
    id: 'zlotopiask',
    name: 'Złotopiask',
    biome: 'desert',
    x0: 165,
    y0: 44,
    bonusText: 'Pracownia Złotopiasku zwraca 25% materiałów i częściej daje lepszą jakość.',
    refiningReturn: 0.15,
    craftingReturn: 0.15,
    stationReturn: { workshop: 0.25 },
    qualityBonusStation: 'workshop',
    qualityBonus: 4,
    marketTax: 0.02,
    npcNames: {
      banker: 'Bankier Tadeusz',
      market: 'Rynkowa Jaśmina',
      trader: 'Kupiec Rustam',
      smith: 'Kowal Kazimierz',
      crafter: 'Rzemieślniczka Aniela',
      refiner: 'Rafinator Ziemowit',
      priest: 'Kapłanka Dobrosława',
      stable: 'Stajenny Radomir',
      guild: 'Mistrzyni gildii Jaga',
    },
    mounts: [
      { item: 'mount_horse', price: 900 },
      { item: 'mount_camel', price: 3000 },
    ],
  },
];

export const CITIES: Record<string, CityDef> = Object.fromEntries(CITY_LIST.map((c) => [c.id, c]));

/** Miasto startowe (nowe postacie). */
export const START_CITY = 'popielgrod';

/** Środek miasta (do liczenia stref). */
export function cityCenter(c: CityDef): { x: number; y: number } {
  return { x: c.x0 + 15, y: c.y0 + 12 };
}

export function cityTemple(c: CityDef): { x: number; y: number } {
  return { x: c.x0 + CITY_TEMPLE.x, y: c.y0 + CITY_TEMPLE.y };
}

/** Pozycje NPC miasta wg szablonu: rola -> [x, y]. */
export function cityNpcPositions(c: CityDef): Map<NpcRole, { x: number; y: number }> {
  const out = new Map<NpcRole, { x: number; y: number }>();
  CITY_TEMPLATE.forEach((row, y) => {
    for (let x = 0; x < row.length; x++) {
      const d = row.charCodeAt(x) - 48;
      if (d >= 1 && d <= 9) out.set(NPC_ROLES[d], { x: c.x0 + x, y: c.y0 + y });
    }
  });
  return out;
}

/** Zwrot materiałów dla stacji w mieście. */
export function cityReturn(c: CityDef, station: Station): number {
  if (station === 'refinery') return c.refiningReturn;
  return c.stationReturn?.[station] ?? c.craftingReturn;
}

/** Miasto, w którego obrębie (mury włącznie) leży punkt. */
export function cityAt(x: number, y: number): CityDef | undefined {
  return CITY_LIST.find((c) => x >= c.x0 && y >= c.y0 && x < c.x0 + CITY_W && y < c.y0 + CITY_H);
}
