/**
 * NPC trzech miast. NPC rozmawiają przez słowa kluczowe (jak w Tibii) – gracz może je
 * wpisać w czacie („witaj”, „handel”…) albo dotknąć przycisku w oknie dialogu.
 * Pozycje wynikają z szablonu miasta (cities.ts), więc każde miasto ma komplet usług.
 */
import { Station } from './recipes';
import { CITY_LIST, CITIES, CityDef, NpcRole, cityNpcPositions } from './cities';

export { CITIES };
export type { CityDef };

export type NpcAction = 'shop' | 'depot' | 'market' | 'craft' | 'bless' | 'guild';

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

/** Wygląd NPC wg roli – w Szronogrodzie i Złotopiasku z przyrostkiem krainy (inne stroje). */
const LOOKS: Record<Exclude<NpcRole, ''>, string> = {
  banker: 'npc_banker',
  market: 'npc_market',
  trader: 'npc_trader',
  smith: 'npc_smith',
  crafter: 'npc_crafter',
  refiner: 'npc_refiner',
  priest: 'npc_priest',
  stable: 'npc_stable',
  guild: 'npc_guild',
};

function npcFor(city: CityDef, role: Exclude<NpcRole, ''>, x: number, y: number): NpcDef {
  const name = city.npcNames[role];
  const id = city.id === 'popielgrod' ? role : `${city.id}_${role}`;
  const base = { id, name, look: LOOKS[role] + (city.biome === 'meadow' ? '' : `_${city.biome}`), city: city.id, x, y };
  const others = CITY_LIST.filter((c) => c.id !== city.id).map((c) => c.name).join(' i ');
  switch (role) {
    case 'banker':
      return {
        ...base,
        greeting: `Witaj, {name}. Skrzynie depozytu ${city.name} są bezpieczne nawet gdy świat płonie. Powiedz „depozyt”.`,
        keywords: {
          depozyt: { text: 'Oto twoja skrzynia. Każde miasto ma osobny depozyt.', action: 'depot' },
          złoto: { text: 'Złoto z rynku trafia do twojego depozytu w tym mieście.' },
          żegnaj: BYE,
        },
      };
    case 'market':
      return {
        ...base,
        greeting: `Witaj, {name}! Tu gracze handlują z graczami. Powiedz „rynek”.`,
        keywords: {
          rynek: { text: `Proszę, oto oferty – ${city.name}.`, action: 'market' },
          podatek: { text: `Od każdej sprzedaży pobieram ${Math.round(city.marketTax * 100)}% podatku dla miasta.` },
          transport: { text: `Każde miasto ma własny rynek. Towar tańszy tutaj bywa droższy w ${others} – ale drogi są niebezpieczne.` },
          żegnaj: BYE,
        },
      };
    case 'trader':
      return {
        ...base,
        greeting: 'Witaj, {name}. Sprzedam narzędzia i mikstury, kupię każdy złom. Powiedz „handel”.',
        keywords: {
          handel: { text: 'Zobacz, co mam.', action: 'shop' },
          narzędzia: { text: 'Narzędzia T1 mam zawsze. Lepsze wykują ci kowale – albo kupisz od graczy na rynku.' },
          miasta: { text: `Poza nami są jeszcze ${others}. Drogi łączą wszystkie miasta, ale wiodą obok Popieliska.` },
          żegnaj: BYE,
        },
        sells: [
          { item: 'woodaxe_t1', price: 30 },
          { item: 'pickaxe_t1', price: 30 },
          { item: 'sickle_t1', price: 25 },
          { item: 'hp_potion', price: 40 },
          { item: 'mp_potion', price: 45 },
          { item: 'great_hp_potion', price: 160 },
          { item: 'great_mp_potion', price: 170 },
          { item: 'meat', price: 4 },
        ],
        buys: true,
      };
    case 'smith':
      return {
        ...base,
        greeting: 'Hej, {name}! Przynieś sztaby, deski i skóry – wykujesz broń i zbroję. Powiedz „kuźnia”.',
        keywords: {
          kuźnia: { text: 'Kowadło twoje.', action: 'craft' },
          tiery: { text: 'Od T1 do T8. Wyższy tier wymaga wyższego poziomu kowalstwa i materiałów z dalszych, groźniejszych krain.' },
          jakość: { text: 'Im lepszy z ciebie kowal, tym częściej wyjdzie coś wyjątkowego, a czasem nawet arcydzieło.' },
          żegnaj: BYE,
        },
        station: 'forge',
      };
    case 'crafter':
      return {
        ...base,
        greeting: 'Dzień dobry, {name}. Łuki, skóry, szaty – wszystko tu uszyjesz. Powiedz „pracownia”.',
        keywords: {
          pracownia: { text: 'Stół jest wolny.', action: 'craft' },
          pancerze: { text: 'Płyta chroni najlepiej, skóra dodaje życia, a płótno – many.' },
          żegnaj: BYE,
        },
        station: 'workshop',
      };
    case 'refiner':
      return {
        ...base,
        greeting: 'Witaj, {name}. Z kłód zrobię deski, z rudy sztaby. Powiedz „rafineria”.',
        keywords: {
          rafineria: { text: 'Piece rozpalone.', action: 'craft' },
          rafinacja: { text: 'T1: 1 surowiec. Wyższe tiery: 2 surowce i 1 materiał tieru niżej.' },
          premia: { text: city.bonusText },
          żegnaj: BYE,
        },
        station: 'refinery',
      };
    case 'priest':
      return {
        ...base,
        greeting: 'Niech popiół cię nie pochłonie, {name}. Powiedz „błogosławieństwo”, a zmniejszę karę za twoją śmierć.',
        keywords: {
          błogosławieństwo: { text: 'Przyjmij łaskę.', action: 'bless' },
          śmierć: {
            text: 'Śmierć odbiera doświadczenie i część umiejętności. W żółtej strefie tracisz część plecaka, w czerwonej i czarnej – wszystko, co masz przy sobie. Każde z pięciu błogosławieństw zmniejsza karę; pięć chroni plecak w żółtej strefie.',
          },
          strefy: { text: 'Wokół miast jest zielona strefa – bezpieczna. Dalej żółta, gdzie gracze mogą walczyć, jeszcze dalej czerwona z pełnym łupem, a w sercu świata – Czarna Strefa, Popielisko.' },
          czaszki: { text: 'Kto w żółtej strefie zaatakuje niewinnego, dostaje białą czaszkę. Trzy niesprawiedliwe zabójstwa w ciągu doby – czerwoną. Czerwona czaszka traci wszystko po śmierci.' },
          świątynia: { text: `Stań na posadzce świątyni, a ${city.name} stanie się twoim domem – tu odrodzisz się po śmierci.` },
          żegnaj: BYE,
        },
      };
    case 'stable':
      return {
        ...base,
        greeting: 'Witaj, {name}! Wierzchowiec skróci każdą drogę. Powiedz „handel”.',
        keywords: {
          handel: { text: 'Oto moje zwierzęta.', action: 'shop' },
          jazda: { text: 'Wierzchowca trzymasz w plecaku. Dotknij przycisku wierzchowca, by wsiąść. Zsiadasz, gdy walczysz.' },
          żegnaj: BYE,
        },
        sells: city.mounts,
      };
    case 'guild':
      return {
        ...base,
        greeting: 'Witaj, {name}. Razem łatwiej przetrwać. Powiedz „gildia”.',
        keywords: {
          gildia: {
            text: 'Załóż gildię (5000 złota): /gildia załóż Nazwa TAG. Zaproś: /gildia zaproś Imię. Dołącz: /gildia dołącz. Czat gildii: /g tekst.',
            action: 'guild',
          },
          terytoria: { text: 'Na Popielisku stoi sześć obelisków. Gildia, która utrzyma się przy obelisku przez minutę, przejmuje terytorium: więcej doświadczenia i surowców w jego pobliżu.' },
          żegnaj: BYE,
        },
      };
  }
}

export const NPCS: NpcDef[] = [];
for (const city of CITY_LIST)
  for (const [role, pos] of cityNpcPositions(city)) if (role) NPCS.push(npcFor(city, role, pos.x, pos.y));

/** Słowa powitania rozpoczynające rozmowę. */
export const GREETINGS = ['witaj', 'hi', 'hello', 'cześć', 'czesc', 'dzień dobry'];
