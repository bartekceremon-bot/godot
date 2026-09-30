/**
 * Czary: pięć szkół magii. Rzucane przyciskiem z paska czarów, z Księgi czarów albo formułą
 * wpisaną w czacie (jak w Tibii). Czarów uczą kapłani w miastach (słowo „czary”) – każde miasto
 * ma swoje szkoły. „exura” zna każdy od początku.
 */

export type SpellSchool = 'light' | 'fire' | 'ice' | 'lightning' | 'death';

export type SpellEffect =
  | 'heal' // leczenie siebie
  | 'heal_area' // leczenie siebie i graczy wokół
  | 'purify' // zdjęcie trucizny, krwawienia, spowolnienia
  | 'bolt' // pocisk w cel
  | 'burn' // pocisk + podpalenie (obrażenia co sekundę)
  | 'chill' // pocisk + spowolnienie
  | 'drain' // pocisk wysysający życie
  | 'curse' // cel otrzymuje więcej obrażeń + słabe obrażenia co sekundę
  | 'chain' // piorun przeskakujący na kolejne cele
  | 'area' // obrażenia w promieniu wokół celu
  | 'nova' // obrażenia i zamrożenie wokół rzucającego
  | 'meteor' // opóźnione, potężne obrażenia w promieniu wokół celu
  | 'storm' // seria uderzeń w losowych wrogów w obszarze
  | 'cloud' // trujący obłok – obrażenia co sekundę w obszarze
  | 'shield' // lodowa zbroja pochłaniająca obrażenia
  | 'haste'; // przyspieszenie

export interface SpellDef {
  id: string;
  name: string;
  school: SpellSchool;
  /** Formuła wpisywana w czacie (jak w Tibii). */
  words: string;
  mana: number;
  cooldownMs: number;
  minLevel: number;
  /** Wymagany poziom magii. */
  minMagic: number;
  effect: SpellEffect;
  /** Zasięg w kafelkach (0 = na siebie). */
  range: number;
  /** Promień obszaru (czary obszarowe). */
  radius?: number;
  /** Siła względem bazowych obrażeń / leczenia magią. */
  power: number;
  durationMs?: number;
  /** Cena nauki u kapłana (0 = znany od początku). */
  price: number;
  /** Klucz ikony po stronie klienta. */
  icon: string;
  description: string;
}

export const SCHOOL_NAMES: Record<SpellSchool, string> = {
  light: 'Światło',
  fire: 'Ogień',
  ice: 'Lód',
  lightning: 'Błyskawica',
  death: 'Nekromancja',
};

/** Szkoły nauczane w miastach (kapłani). */
export const CITY_SCHOOLS: Record<string, SpellSchool[]> = {
  popielgrod: ['light', 'fire'],
  szronogrod: ['ice', 'death'],
  zlotopiask: ['lightning', 'light'],
};

const defs: SpellDef[] = [
  // Światło
  { id: 'heal', name: 'Leczenie', school: 'light', words: 'exura', mana: 20, cooldownMs: 1000, minLevel: 1, minMagic: 0, effect: 'heal', range: 0, power: 1, price: 0, icon: 'spell_heal', description: 'Leczy rany rzucającego.' },
  { id: 'heal_great', name: 'Wielkie leczenie', school: 'light', words: 'exura gran', mana: 70, cooldownMs: 1500, minLevel: 12, minMagic: 3, effect: 'heal', range: 0, power: 2.6, price: 1500, icon: 'spell_heal', description: 'Potężnie leczy rany rzucającego.' },
  { id: 'heal_area', name: 'Krąg światła', school: 'light', words: 'exura mas', mana: 120, cooldownMs: 4000, minLevel: 25, minMagic: 8, effect: 'heal_area', range: 0, radius: 3, power: 1.4, price: 5000, icon: 'spell_heal', description: 'Leczy rzucającego i sojuszników w promieniu 3 pól.' },
  { id: 'purify', name: 'Oczyszczenie', school: 'light', words: 'exana pox', mana: 30, cooldownMs: 3000, minLevel: 8, minMagic: 1, effect: 'purify', range: 0, power: 0, price: 800, icon: 'spell_purify', description: 'Zdejmuje truciznę, krwawienie, podpalenie i spowolnienie.' },
  { id: 'holy', name: 'Święty pocisk', school: 'light', words: 'exori san', mana: 45, cooldownMs: 2000, minLevel: 15, minMagic: 5, effect: 'bolt', range: 6, power: 1.1, price: 2500, icon: 'spell_holy', description: 'Pocisk światła. Podwójne obrażenia nieumarłym i demonom.' },
  // Ogień
  { id: 'fireball', name: 'Kula ognia', school: 'fire', words: 'exori flam', mana: 25, cooldownMs: 2000, minLevel: 5, minMagic: 0, effect: 'burn', range: 6, power: 1.0, durationMs: 4000, price: 500, icon: 'spell_fire', description: 'Pocisk ognia, który podpala cel na 4 s.' },
  { id: 'firestorm', name: 'Burza ognia', school: 'fire', words: 'exevo gran mas flam', mana: 110, cooldownMs: 6000, minLevel: 30, minMagic: 10, effect: 'area', range: 6, radius: 2, power: 1.3, price: 7000, icon: 'spell_fire', description: 'Płomienie spadają na cel i wszystko wokół niego (promień 2).' },
  { id: 'meteor', name: 'Meteor', school: 'fire', words: 'exevo flam hur', mana: 200, cooldownMs: 20000, minLevel: 45, minMagic: 16, effect: 'meteor', range: 7, radius: 3, power: 2.4, price: 18000, icon: 'spell_meteor', description: 'Po chwili z nieba spada meteor – ogromne obrażenia w promieniu 3.' },
  // Lód
  { id: 'icebolt', name: 'Lodowy pocisk', school: 'ice', words: 'exori frigo', mana: 30, cooldownMs: 2000, minLevel: 8, minMagic: 1, effect: 'chill', range: 6, power: 0.9, durationMs: 3000, price: 700, icon: 'spell_ice', description: 'Pocisk lodu, który spowalnia cel na 3 s.' },
  { id: 'frost_nova', name: 'Mroźna nova', school: 'ice', words: 'exevo frigo', mana: 90, cooldownMs: 8000, minLevel: 22, minMagic: 7, effect: 'nova', range: 0, radius: 2, power: 0.8, durationMs: 1500, price: 4500, icon: 'spell_ice', description: 'Fala mrozu wokół rzucającego: obrażenia i zamrożenie na 1,5 s.' },
  { id: 'ice_armor', name: 'Lodowa zbroja', school: 'ice', words: 'utamo frigo', mana: 80, cooldownMs: 15000, minLevel: 18, minMagic: 6, effect: 'shield', range: 0, power: 1.0, durationMs: 10000, price: 3500, icon: 'spell_shield', description: 'Lodowa tarcza pochłania obrażenia przez 10 s.' },
  // Błyskawica
  { id: 'lightning', name: 'Błyskawica', school: 'lightning', words: 'exori vis', mana: 35, cooldownMs: 2000, minLevel: 10, minMagic: 2, effect: 'bolt', range: 6, power: 1.15, price: 1000, icon: 'spell_lightning', description: 'Piorun uderza w cel.' },
  { id: 'chain', name: 'Łańcuch piorunów', school: 'lightning', words: 'exori gran vis', mana: 95, cooldownMs: 5000, minLevel: 28, minMagic: 9, effect: 'chain', range: 6, radius: 3, power: 0.85, price: 6500, icon: 'spell_lightning', description: 'Piorun przeskakuje z celu na dwóch kolejnych wrogów.' },
  { id: 'storm', name: 'Nawałnica', school: 'lightning', words: 'exevo gran vis hur', mana: 220, cooldownMs: 22000, minLevel: 50, minMagic: 18, effect: 'storm', range: 7, radius: 2, power: 0.75, durationMs: 4000, price: 20000, icon: 'spell_storm', description: 'Przez 4 s pioruny biją we wrogów wokół celu.' },
  { id: 'haste', name: 'Przyspieszenie', school: 'lightning', words: 'utani hur', mana: 60, cooldownMs: 20000, minLevel: 14, minMagic: 3, effect: 'haste', range: 0, power: 0.35, durationMs: 10000, price: 2000, icon: 'spell_haste', description: 'Przez 10 s poruszasz się o 35% szybciej.' },
  // Nekromancja
  { id: 'drain', name: 'Wyssanie życia', school: 'death', words: 'exori mort', mana: 40, cooldownMs: 2500, minLevel: 12, minMagic: 3, effect: 'drain', range: 5, power: 0.9, price: 1500, icon: 'spell_death', description: 'Wysysa życie celu – połowa obrażeń leczy rzucającego.' },
  { id: 'curse', name: 'Klątwa', school: 'death', words: 'utori mort', mana: 50, cooldownMs: 10000, minLevel: 20, minMagic: 6, effect: 'curse', range: 5, power: 0.25, durationMs: 8000, price: 3500, icon: 'spell_curse', description: 'Przez 8 s cel otrzymuje o 25% więcej obrażeń i traci życie.' },
  { id: 'poison_cloud', name: 'Trujący obłok', school: 'death', words: 'exevo gran mort', mana: 130, cooldownMs: 12000, minLevel: 35, minMagic: 12, effect: 'cloud', range: 6, radius: 2, power: 0.3, durationMs: 6000, price: 9000, icon: 'spell_death', description: 'Obłok trucizny wokół celu: wrogowie tracą życie przez 6 s.' },
];

export const SPELLS: Record<string, SpellDef> = Object.fromEntries(defs.map((d) => [d.id, d]));
export const SPELL_LIST = defs;

export function findSpellByWords(text: string): SpellDef | undefined {
  const w = text.trim().toLowerCase();
  return defs.find((s) => s.words === w);
}

/** Ile HP przywraca „exura” – rośnie z poziomem i poziomem magii. */
export function healAmount(level: number, magicLevel: number): { min: number; max: number } {
  const base = level * 0.2 + magicLevel * 3;
  return { min: Math.floor(base + 20), max: Math.floor(base * 1.5 + 40) };
}

/** Bazowe maksymalne obrażenia czarów (przed mnożnikiem czaru i kostura). */
export function spellDamage(level: number, magicLevel: number): number {
  return level * 0.35 + magicLevel * 4 + 14;
}

/** Istoty podatne na światło (podwójne obrażenia „exori san”). */
export const UNDEAD = new Set(['skeleton', 'zombie', 'mummy', 'ice_wraith', 'demon', 'ash_knight', 'ash_champion', 'frost_king']);
