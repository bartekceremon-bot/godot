/**
 * Miasta i NPC. NPC rozmawiają przez słowa kluczowe (jak w Tibii) – gracz może je
 * wpisać w czacie („witaj”, „handel”…) albo dotknąć przycisku w oknie dialogu.
 */
import { Station } from './recipes';

export interface CityDef {
  id: string;
  name: string;
  /** Premia miasta do rzemiosła (każde z 3 miast będzie miało inną). */
  bonusText: string;
  /** Zwrot materiałów przy rafinacji / rzemiośle (0..1). */
  refiningReturn: number;
  craftingReturn: number;
  /** Premia do jakości przy rzemiośle w wybranej stacji. */
  qualityBonusStation?: Station;
  qualityBonus: number;
  /** Podatek od sprzedaży na rynku (0..1). */
  marketTax: number;
}

export const CITIES: Record<string, CityDef> = {
  popielgrod: {
    id: 'popielgrod',
    name: 'Popielgród',
    bonusText: 'Rafineria Popielgrodu zwraca 25% materiałów (inne stacje 15%).',
    refiningReturn: 0.25,
    craftingReturn: 0.15,
    qualityBonus: 0,
    marketTax: 0.03,
  },
};

export type NpcAction = 'shop' | 'depot' | 'market' | 'craft';

export interface NpcKeyword {
  text: string;
  action?: NpcAction;
}

export interface NpcDef {
  id: string;
  name: string;
  /** Wygląd (klucz grafiki klienta). */
  look: string;
  city: string;
  x: number;
  y: number;
  greeting: string;
  /** Słowa kluczowe -> odpowiedź (i ewentualnie akcja otwierająca okno). */
  keywords: Record<string, NpcKeyword>;
  /** Co NPC sprzedaje (przedmiot, cena). */
  sells?: { item: string; price: number }[];
  /** Czy NPC skupuje przedmioty (za ułamek wartości). */
  buys?: boolean;
  station?: Station;
}

/** Jaki ułamek wartości płaci NPC przy skupie. */
export const NPC_BUY_RATIO = 0.2;

/** Maksymalna odległość rozmowy z NPC (kafelki). */
export const NPC_RANGE = 3;

const BYE: NpcKeyword = { text: 'Bywaj, Popielniku.' };

export const NPCS: NpcDef[] = [
  {
    id: 'banker',
    name: 'Bankier Oskar',
    look: 'npc_banker',
    city: 'popielgrod',
    x: 44,
    y: 43,
    greeting: 'Witaj, {name}. Skrzynie depozytu są bezpieczne nawet gdy świat płonie. Powiedz „depozyt”.',
    keywords: {
      depozyt: { text: 'Oto twoja skrzynia. Każde miasto ma osobny depozyt.', action: 'depot' },
      złoto: { text: 'Złoto z rynku trafia do twojego depozytu w tym mieście.' },
      żegnaj: BYE,
    },
  },
  {
    id: 'market',
    name: 'Rynkowa Wanda',
    look: 'npc_market',
    city: 'popielgrod',
    x: 54,
    y: 43,
    greeting: 'Witaj, {name}! Tu gracze handlują z graczami. Powiedz „rynek”.',
    keywords: {
      rynek: { text: 'Proszę, oto oferty Popielgrodu.', action: 'market' },
      podatek: { text: 'Od każdej sprzedaży pobieram 3% podatku dla miasta.' },
      transport: { text: 'Każde miasto ma własny rynek. Kto przewiezie towar, ten zarobi – ale drogi są niebezpieczne.' },
      żegnaj: BYE,
    },
  },
  {
    id: 'trader',
    name: 'Kupiec Borys',
    look: 'npc_trader',
    city: 'popielgrod',
    x: 40,
    y: 53,
    greeting: 'Witaj, {name}. Sprzedam narzędzia i mikstury, kupię każdy złom. Powiedz „handel”.',
    keywords: {
      handel: { text: 'Zobacz, co mam.', action: 'shop' },
      narzędzia: { text: 'Narzędzia T1 mam zawsze. Lepsze wykują ci kowale – albo kupisz od graczy na rynku.' },
      żegnaj: BYE,
    },
    sells: [
      { item: 'woodaxe_t1', price: 30 },
      { item: 'pickaxe_t1', price: 30 },
      { item: 'sickle_t1', price: 25 },
      { item: 'hp_potion', price: 40 },
      { item: 'mp_potion', price: 45 },
      { item: 'meat', price: 4 },
    ],
    buys: true,
  },
  {
    id: 'smith',
    name: 'Kowal Gerwazy',
    look: 'npc_smith',
    city: 'popielgrod',
    x: 43,
    y: 53,
    greeting: 'Hej, {name}! Przynieś sztaby, deski i skóry – wykujesz broń i zbroję. Powiedz „kuźnia”.',
    keywords: {
      kuźnia: { text: 'Kowadło twoje.', action: 'craft' },
      tiery: { text: 'T1 to podstawy. Wyższy tier wymaga wyższego poziomu kowalstwa i lepszych materiałów.' },
      jakość: { text: 'Im lepszy z ciebie kowal, tym częściej wyjdzie coś wyjątkowego, a czasem nawet arcydzieło.' },
      żegnaj: BYE,
    },
    station: 'forge',
  },
  {
    id: 'crafter',
    name: 'Rzemieślniczka Jadwiga',
    look: 'npc_crafter',
    city: 'popielgrod',
    x: 46,
    y: 53,
    greeting: 'Dzień dobry, {name}. Łuki, skóry, szaty – wszystko tu uszyjesz. Powiedz „pracownia”.',
    keywords: {
      pracownia: { text: 'Stół jest wolny.', action: 'craft' },
      pancerze: { text: 'Płyta chroni najlepiej, skóra dodaje życia, a płótno – many.' },
      żegnaj: BYE,
    },
    station: 'workshop',
  },
  {
    id: 'refiner',
    name: 'Rafinator Zenon',
    look: 'npc_refiner',
    city: 'popielgrod',
    x: 41,
    y: 50,
    greeting: 'Witaj, {name}. Z kłód zrobię deski, z rudy sztaby. Powiedz „rafineria”.',
    keywords: {
      rafineria: { text: 'Piece rozpalone.', action: 'craft' },
      rafinacja: { text: 'T1: 1 surowiec. Wyższe tiery: 2 surowce i 1 materiał tieru niżej. Popielgród zwraca 25% materiałów!' },
      żegnaj: BYE,
    },
    station: 'refinery',
  },
];

/** Słowa powitania rozpoczynające rozmowę. */
export const GREETINGS = ['witaj', 'hi', 'hello', 'cześć', 'czesc', 'dzień dobry'];
