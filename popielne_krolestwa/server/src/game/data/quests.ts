/**
 * Zadania (questy). Dają je NPC w miastach po słowie „zadanie”:
 *  - mistrz gildii – zlecenia łowieckie (zabij N potworów),
 *  - rzemieślnik – zbieranie surowców (oddaje się je przy odbiorze nagrody),
 *  - kapłan – wyprawy (odwiedź miejsce, pokonaj bossa, zanieś wieść do innego miasta).
 * Cele „place” wskazują miejsca świata: `city:<id>`, `fire_temple`, `obelisk:<n>`, `boss:<id>`.
 */

export type QuestGoal =
  | { kind: 'kill'; monster: string; count: number; label: string }
  | { kind: 'gather'; item: string; count: number; label: string }
  | { kind: 'visit'; place: string; radius: number; label: string };

export interface QuestDef {
  id: string;
  name: string;
  city: string;
  /** Rola NPC, który daje zadanie. */
  giver: 'guild' | 'crafter' | 'priest';
  minLevel: number;
  text: string;
  goals: QuestGoal[];
  reward: { exp: number; gold: number; items?: [string, number][] };
  /** Zadanie powtarzalne (po oddaniu można je wziąć ponownie). */
  repeatable?: boolean;
  /** Wymagane wcześniej ukończone zadanie. */
  after?: string;
}

const Q: QuestDef[] = [
  // --- Popielgród ---------------------------------------------------------
  { id: 'pop_rats', name: 'Szczury pod murami', city: 'popielgrod', giver: 'guild', minLevel: 1, text: 'Szczury podgryzają worki w spichrzach. Ubij dziesięć i wróć po zapłatę.',
    goals: [{ kind: 'kill', monster: 'rat', count: 10, label: 'Zabij szczury' }], reward: { exp: 300, gold: 150, items: [['hp_potion', 3]] } },
  { id: 'pop_wolves', name: 'Wilcza zaraza', city: 'popielgrod', giver: 'guild', minLevel: 5, after: 'pop_rats', text: 'Wilki napadają na karawany na zachodnim trakcie. Pozbądź się watahy.',
    goals: [{ kind: 'kill', monster: 'wolf', count: 12, label: 'Zabij wilki' }], reward: { exp: 1500, gold: 500, items: [['hp_potion', 5]] } },
  { id: 'pop_bandits', name: 'Obóz bandytów', city: 'popielgrod', giver: 'guild', minLevel: 12, after: 'pop_wolves', text: 'Bandyci rozbili obóz w lasach. Rozgoń ich – łucznicy liczą się podwójnie w moim sercu.',
    goals: [{ kind: 'kill', monster: 'bandit', count: 8, label: 'Pokonaj bandytów' }, { kind: 'kill', monster: 'bandit_archer', count: 4, label: 'Pokonaj łuczników' }],
    reward: { exp: 5000, gold: 1500 } },
  { id: 'pop_orcs', name: 'Orkowie u bram', city: 'popielgrod', giver: 'guild', minLevel: 20, after: 'pop_bandits', text: 'Orkowie i ich szamani palą wioski. Złam ich siłę.',
    goals: [{ kind: 'kill', monster: 'orc', count: 15, label: 'Zabij orków' }, { kind: 'kill', monster: 'orc_shaman', count: 5, label: 'Zabij szamanów' }],
    reward: { exp: 14000, gold: 3500, items: [['great_hp_potion', 10]] } },
  { id: 'pop_hunt', name: 'Zlecenie łowieckie', city: 'popielgrod', giver: 'guild', minLevel: 8, repeatable: true, text: 'Gildia zawsze płaci za dziki. Dwadzieścia sztuk – i wracaj po kolejne zlecenie.',
    goals: [{ kind: 'kill', monster: 'boar', count: 20, label: 'Upoluj dziki' }], reward: { exp: 2500, gold: 700 } },
  { id: 'pop_wood', name: 'Drewno na palisadę', city: 'popielgrod', giver: 'crafter', minLevel: 1, text: 'Palisada wokół wsi się sypie. Przynieś dwadzieścia polan drewna T2.',
    goals: [{ kind: 'gather', item: 'wood_t2', count: 20, label: 'Przynieś drewno T2' }], reward: { exp: 900, gold: 400 } },
  { id: 'pop_ore', name: 'Ruda dla kuźni', city: 'popielgrod', giver: 'crafter', minLevel: 6, after: 'pop_wood', text: 'Kowal potrzebuje rudy T3 na nowe miecze dla straży.',
    goals: [{ kind: 'gather', item: 'ore_t3', count: 25, label: 'Przynieś rudę T3' }], reward: { exp: 3000, gold: 1200 } },
  { id: 'pop_messenger', name: 'Posłaniec do Szronogrodu', city: 'popielgrod', giver: 'priest', minLevel: 10, text: 'Zanieś wieść do świątyni Szronogrodu na północnym zachodzie. Droga jest długa i mroźna.',
    goals: [{ kind: 'visit', place: 'city:szronogrod', radius: 4, label: 'Dotrzyj do świątyni Szronogrodu' }], reward: { exp: 4000, gold: 900 } },
  { id: 'pop_fire_temple', name: 'Serce Popieliska', city: 'popielgrod', giver: 'priest', minLevel: 40, text: 'W sercu Popieliska stoi Świątynia Ognia upadłego boga. Zobacz ją na własne oczy i przeżyj.',
    goals: [{ kind: 'visit', place: 'fire_temple', radius: 5, label: 'Dotrzyj do Świątyni Ognia' }], reward: { exp: 40000, gold: 8000 } },
  { id: 'pop_dragon', name: 'Żarogniew', city: 'popielgrod', giver: 'priest', minLevel: 60, after: 'pop_fire_temple', text: 'Popielny Smok Żarogniew strzeże Świątyni Ognia. Zgładź go – i wróć, jeśli zdołasz.',
    goals: [{ kind: 'kill', monster: 'ash_dragon', count: 1, label: 'Pokonaj Popielnego Smoka' }], reward: { exp: 250000, gold: 50000 } },
  // --- Szronogród ---------------------------------------------------------
  { id: 'szr_foxes', name: 'Futra na zimę', city: 'szronogrod', giver: 'guild', minLevel: 1, text: 'Kuśnierze płacą za lisie futra. Upoluj dziesięć śnieżnych lisów.',
    goals: [{ kind: 'kill', monster: 'snow_fox', count: 10, label: 'Upoluj śnieżne lisy' }], reward: { exp: 400, gold: 200 } },
  { id: 'szr_wolves', name: 'Wycie w zamieci', city: 'szronogrod', giver: 'guild', minLevel: 8, after: 'szr_foxes', text: 'Śnieżne wilki podchodzą pod bramy nocą. Przerzedź watahę.',
    goals: [{ kind: 'kill', monster: 'snow_wolf', count: 12, label: 'Zabij śnieżne wilki' }], reward: { exp: 3500, gold: 900 } },
  { id: 'szr_yeti', name: 'Łowcy yeti', city: 'szronogrod', giver: 'guild', minLevel: 28, after: 'szr_wolves', text: 'Yeti zeszły z gór. Nikt nie wraca z przełęczy – zmień to.',
    goals: [{ kind: 'kill', monster: 'yeti', count: 8, label: 'Pokonaj yeti' }], reward: { exp: 22000, gold: 5000 } },
  { id: 'szr_wraiths', name: 'Lodowe upiory', city: 'szronogrod', giver: 'priest', minLevel: 35, text: 'Upiory lodu to dusze zamarzniętych wędrowców. Uwolnij je.',
    goals: [{ kind: 'kill', monster: 'ice_wraith', count: 10, label: 'Uwolnij lodowe upiory' }], reward: { exp: 35000, gold: 7000 } },
  { id: 'szr_king', name: 'Korona Szronu', city: 'szronogrod', giver: 'priest', minLevel: 50, after: 'szr_wraiths', text: 'Król Szronu siedzi na lodowym tronie w najdalszym zakątku śniegów. Zdejmij mu koronę.',
    goals: [{ kind: 'kill', monster: 'frost_king', count: 1, label: 'Pokonaj Króla Szronu' }], reward: { exp: 150000, gold: 30000 } },
  { id: 'szr_stone', name: 'Kamień na mury', city: 'szronogrod', giver: 'crafter', minLevel: 4, text: 'Mróz kruszy mury. Przynieś kamień T2.',
    goals: [{ kind: 'gather', item: 'stone_t2', count: 20, label: 'Przynieś kamień T2' }], reward: { exp: 900, gold: 400 } },
  // --- Złotopiask ---------------------------------------------------------
  { id: 'zlo_scarabs', name: 'Skarabeusze w studniach', city: 'zlotopiask', giver: 'guild', minLevel: 1, text: 'Skarabeusze zatruwają studnie. Wytęp dziesięć.',
    goals: [{ kind: 'kill', monster: 'scarab', count: 10, label: 'Wytęp skarabeusze' }], reward: { exp: 400, gold: 200 } },
  { id: 'zlo_scorpions', name: 'Żądła pustyni', city: 'zlotopiask', giver: 'guild', minLevel: 6, after: 'zlo_scarabs', text: 'Skorpiony kąsają wielbłądy karawan. Zabij piętnaście.',
    goals: [{ kind: 'kill', monster: 'scorpion', count: 15, label: 'Zabij skorpiony' }], reward: { exp: 2500, gold: 800 } },
  { id: 'zlo_mummies', name: 'Klątwa grobowców', city: 'zlotopiask', giver: 'priest', minLevel: 25, text: 'Mumie wyszły z grobowców. Odeślij je do snu.',
    goals: [{ kind: 'kill', monster: 'mummy', count: 12, label: 'Pokonaj mumie' }], reward: { exp: 18000, gold: 4500 } },
  { id: 'zlo_worm', name: 'Pan wydm', city: 'zlotopiask', giver: 'priest', minLevel: 50, after: 'zlo_mummies', text: 'Pustynny Czerw pożera całe karawany. Znajdź go w głębi pustyni.',
    goals: [{ kind: 'kill', monster: 'sand_worm', count: 1, label: 'Pokonaj Pustynnego Czerwia' }], reward: { exp: 150000, gold: 30000 } },
  { id: 'zlo_fiber', name: 'Włókno na żagle', city: 'zlotopiask', giver: 'crafter', minLevel: 4, text: 'Tkacze potrzebują włókna T2 na płótno namiotów.',
    goals: [{ kind: 'gather', item: 'fiber_t2', count: 20, label: 'Przynieś włókno T2' }], reward: { exp: 900, gold: 400 } },
  { id: 'zlo_obelisk', name: 'Obeliski Popieliska', city: 'zlotopiask', giver: 'priest', minLevel: 45, text: 'Na Popielisku stoją obeliski władzy. Dotknij jednego i wróć z opowieścią.',
    goals: [{ kind: 'visit', place: 'obelisk:0', radius: 3, label: 'Dotrzyj do obelisku' }], reward: { exp: 30000, gold: 6000 } },
];

export const QUESTS: Record<string, QuestDef> = Object.fromEntries(Q.map((q) => [q.id, q]));
export const QUEST_LIST = Q;

export interface QuestState {
  /** id -> postęp każdego celu. */
  active: Record<string, number[]>;
  done: string[];
}

export function loadQuests(v: unknown): QuestState {
  const q: QuestState = { active: {}, done: [] };
  if (!v || typeof v !== 'object') return q;
  const o = v as Record<string, unknown>;
  if (o.active && typeof o.active === 'object')
    for (const [id, prog] of Object.entries(o.active as Record<string, unknown>))
      if (QUESTS[id] && Array.isArray(prog)) q.active[id] = prog.map((n) => Math.max(0, Math.floor(Number(n) || 0)));
  if (Array.isArray(o.done)) q.done = o.done.filter((id) => typeof id === 'string' && QUESTS[id]);
  return q;
}

