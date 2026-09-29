/**
 * Definicje przedmiotów. Definicje są wysyłane do klienta przy logowaniu,
 * więc klient nie musi mieć ich „na sztywno” – zmiana balansu = zmiana tylko tutaj.
 */

export type EquipSlot = 'head' | 'body' | 'legs' | 'feet' | 'weapon' | 'shield';
export const EQUIP_SLOTS: EquipSlot[] = ['head', 'body', 'legs', 'feet', 'weapon', 'shield'];

/** Skille rozwijane przez używanie (jak w Tibii). */
export type SkillName = 'sword' | 'axe' | 'club' | 'distance' | 'magic' | 'shielding' | 'fishing';
export const SKILL_NAMES: SkillName[] = ['sword', 'axe', 'club', 'distance', 'magic', 'shielding', 'fishing'];

export interface ItemDef {
  id: string;
  name: string;
  /** Klucz grafiki po stronie klienta (placeholder generowany proceduralnie). */
  icon: string;
  /** Waga w oz. – udźwig zostanie wykorzystany w ETAPIE 2. */
  weight: number;
  stackable?: boolean;
  slot?: EquipSlot;
  /** Skill używany przez broń. */
  skill?: SkillName;
  attack?: number;
  defense?: number;
  armor?: number;
  /** Zasięg broni w kafelkach (1 = wręcz). */
  range?: number;
  twoHanded?: boolean;
  /** Efekt użycia (mikstury, jedzenie). */
  use?: { heal?: number; mana?: number };
  /** Tier (T1–T8) – w ETAPIE 1 wszystko to T1. */
  tier?: number;
  description?: string;
}

const defs: ItemDef[] = [
  // Waluta i materiały
  { id: 'gold', name: 'Złota moneta', icon: 'gold', weight: 0.1, stackable: true },
  { id: 'meat', name: 'Mięso', icon: 'meat', weight: 1, stackable: true, use: { heal: 15 }, description: 'Przywraca trochę zdrowia.' },
  { id: 'wolf_pelt', name: 'Wilcza skóra', icon: 'pelt', weight: 2, stackable: true, description: 'Surowiec – przyda się rzemieślnikom.' },
  { id: 'bone', name: 'Popielna kość', icon: 'bone', weight: 1, stackable: true, description: 'Pachnie spalenizną.' },
  // Mikstury
  { id: 'hp_potion', name: 'Mikstura życia', icon: 'hp_potion', weight: 1.5, stackable: true, use: { heal: 70 } },
  { id: 'mp_potion', name: 'Mikstura many', icon: 'mp_potion', weight: 1.5, stackable: true, use: { mana: 60 } },
  // Bronie
  { id: 'rusty_sword', name: 'Zardzewiały miecz', icon: 'sword', weight: 25, slot: 'weapon', skill: 'sword', attack: 10, defense: 8, range: 1, tier: 1 },
  { id: 'hatchet', name: 'Toporek', icon: 'axe', weight: 30, slot: 'weapon', skill: 'axe', attack: 12, defense: 5, range: 1, tier: 1 },
  { id: 'club', name: 'Pałka', icon: 'club', weight: 25, slot: 'weapon', skill: 'club', attack: 11, defense: 6, range: 1, tier: 1 },
  { id: 'hunting_bow', name: 'Łuk myśliwski', icon: 'bow', weight: 20, slot: 'weapon', skill: 'distance', attack: 13, range: 6, twoHanded: true, tier: 1 },
  { id: 'ash_sword', name: 'Miecz Popielny', icon: 'ash_sword', weight: 35, slot: 'weapon', skill: 'sword', attack: 18, defense: 12, range: 1, tier: 2 },
  // Pancerze
  { id: 'wooden_shield', name: 'Drewniana tarcza', icon: 'shield', weight: 40, slot: 'shield', defense: 14, tier: 1 },
  { id: 'leather_helmet', name: 'Skórzany hełm', icon: 'helmet', weight: 20, slot: 'head', armor: 1, tier: 1 },
  { id: 'leather_armor', name: 'Skórzana zbroja', icon: 'armor', weight: 60, slot: 'body', armor: 3, tier: 1 },
  { id: 'leather_legs', name: 'Skórzane spodnie', icon: 'legs', weight: 18, slot: 'legs', armor: 1, tier: 1 },
  { id: 'leather_boots', name: 'Skórzane buty', icon: 'boots', weight: 9, slot: 'feet', armor: 1, tier: 1 },
  { id: 'chain_armor', name: 'Kolczuga', icon: 'chain_armor', weight: 100, slot: 'body', armor: 6, tier: 2 },
];

export const ITEMS: Record<string, ItemDef> = Object.fromEntries(defs.map((d) => [d.id, d]));
export const ITEM_LIST: ItemDef[] = defs;

export function getItem(id: string): ItemDef | undefined {
  return ITEMS[id];
}
