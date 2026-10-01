/**
 * Definicje przedmiotów. Definicje są wysyłane do klienta przy logowaniu,
 * więc klient nie musi mieć ich „na sztywno” – zmiana balansu = zmiana tylko tutaj.
 *
 * Surowce i materiały przetworzone T1–T8, ekwipunek T1–T8 generowany
 * z szablonów (broń, trzy typy pancerzy jak w Albionie, tarcze, narzędzia).
 * Jakość (1–5) jest cechą konkretnego egzemplarza (ItemStack.q), nie definicji.
 */

export type EquipSlot = 'head' | 'body' | 'legs' | 'feet' | 'weapon' | 'shield';
export const EQUIP_SLOTS: EquipSlot[] = ['head', 'body', 'legs', 'feet', 'weapon', 'shield'];

/** Skille rozwijane przez używanie (jak w Tibii). */
export type SkillName = 'sword' | 'axe' | 'club' | 'distance' | 'magic' | 'shielding' | 'fishing';
export const SKILL_NAMES: SkillName[] = ['sword', 'axe', 'club', 'distance', 'magic', 'shielding', 'fishing'];

/** Rodzaje surowców (zbieractwo). */
export type ResourceKind = 'wood' | 'stone' | 'ore' | 'fiber' | 'hide';
export const RESOURCE_KINDS: ResourceKind[] = ['wood', 'stone', 'ore', 'fiber', 'hide'];

/** Narzędzia zbierackie: który surowiec wymaga którego narzędzia. */
export type ToolKind = 'woodaxe' | 'pickaxe' | 'sickle';
export const TOOL_FOR_RESOURCE: Record<ResourceKind, ToolKind | null> = {
  wood: 'woodaxe',
  stone: 'pickaxe',
  ore: 'pickaxe',
  fiber: 'sickle',
  hide: null, // skóry pochodzą z upolowanych zwierząt
};

export type ItemCategory = 'resource' | 'material' | 'weapon' | 'armor' | 'shield' | 'tool' | 'consumable' | 'mount' | 'misc';

export interface ItemDef {
  id: string;
  name: string;
  /** Klucz grafiki po stronie klienta (placeholder generowany proceduralnie). */
  icon: string;
  category: ItemCategory;
  /** Waga w oz. – liczy się do udźwigu. */
  weight: number;
  /** Bazowa wartość w złocie (NPC skupują za ułamek tej wartości). */
  value: number;
  stackable?: boolean;
  slot?: EquipSlot;
  /** Skill używany przez broń. */
  skill?: SkillName;
  attack?: number;
  defense?: number;
  armor?: number;
  hpBonus?: number;
  mpBonus?: number;
  /** Zasięg broni w kafelkach (1 = wręcz). */
  range?: number;
  twoHanded?: boolean;
  /** Minimalny poziom postaci do założenia. */
  minLevel?: number;
  /** Kostury: premia do siły czarów (ułamek, np. 0,3 = +30%). */
  spellPower?: number;
  /** Efekt użycia (mikstury, jedzenie). */
  use?: { heal?: number; mana?: number };
  /** Tier T1–T8. */
  tier?: number;
  /** Dla surowców/materiałów: rodzaj. */
  resource?: ResourceKind;
  /** Dla narzędzi: rodzaj. */
  tool?: ToolKind;
  /** Wierzchowiec: premia do szybkości (0.3 = +30%) i udźwigu. */
  mount?: { speed: number; cap?: number };
  description?: string;
}

export const MAX_TIER = 8;
export const TIERS = [1, 2, 3, 4, 5, 6, 7, 8];

/** Nazwy jakości (indeks = jakość 1–5) i mnożniki statystyk. */
export const QUALITY_NAMES = ['', 'Zwykły', 'Dobry', 'Wyjątkowy', 'Doskonały', 'Arcydzieło'];
export const QUALITY_MULT = [1, 1, 1.05, 1.1, 1.18, 1.3];

/** Mnożnik statystyk ekwipunku zależny od tieru. */
export function tierMult(tier: number): number {
  return 1 + 0.3 * (tier - 1);
}

/** Minimalny poziom postaci do założenia ekwipunku danego tieru. */
export const TIER_MIN_LEVEL = [0, 1, 6, 12, 20, 30, 42, 56, 72];

// ---------------------------------------------------------------------------
// Surowce i materiały
// ---------------------------------------------------------------------------

/** Nazwy surowców (indeks = tier). */
const RAW_NAMES: Record<ResourceKind, string[]> = {
  wood: ['', 'Kłody brzozowe', 'Kłody kasztanowe', 'Kłody sosnowe', 'Kłody cedrowe', 'Kłody dębowe', 'Kłody krwistego buku', 'Kłody widmowego jesionu', 'Kłody drzewa żaru'],
  stone: ['', 'Wapień', 'Piaskowiec', 'Trawertyn', 'Granit', 'Bazalt', 'Marmur', 'Obsydian', 'Kamień żaru'],
  ore: ['', 'Ruda miedzi', 'Ruda cyny', 'Ruda żelaza', 'Ruda tytanu', 'Ruda runitu', 'Ruda meteorytu', 'Ruda adamantytu', 'Ruda żarytu'],
  fiber: ['', 'Len', 'Konopie', 'Bawełna', 'Ognista pokrzywa', 'Niebokwiat', 'Bursztynolist', 'Słonecznolen', 'Widmowe konopie'],
  hide: ['', 'Surowa skóra szczurza', 'Surowa skóra dzika', 'Surowa skóra wilcza', 'Surowa skóra ogara', 'Surowa skóra niedźwiedzia', 'Surowa skóra yeti', 'Surowa skóra bazyliszka', 'Surowa skóra smocza'],
};

const REFINED_NAMES: Record<ResourceKind, string[]> = {
  wood: ['', 'Deski brzozowe', 'Deski kasztanowe', 'Deski sosnowe', 'Deski cedrowe', 'Deski dębowe', 'Deski krwistego buku', 'Deski widmowego jesionu', 'Deski drzewa żaru'],
  stone: ['', 'Bloki wapienne', 'Bloki piaskowca', 'Bloki trawertynu', 'Bloki granitu', 'Bloki bazaltu', 'Bloki marmuru', 'Bloki obsydianu', 'Bloki kamienia żaru'],
  ore: ['', 'Sztaby miedzi', 'Sztaby cyny', 'Sztaby żelaza', 'Sztaby tytanu', 'Sztaby runitu', 'Sztaby meteorytu', 'Sztaby adamantytu', 'Sztaby żarytu'],
  fiber: ['', 'Płótno lniane', 'Płótno konopne', 'Tkanina bawełniana', 'Tkanina ognista', 'Tkanina niebiańska', 'Tkanina bursztynowa', 'Tkanina słoneczna', 'Tkanina widmowa'],
  hide: ['', 'Skóra szczurza', 'Skóra dzika', 'Skóra wilcza', 'Skóra ogara', 'Skóra niedźwiedzia', 'Skóra yeti', 'Skóra bazyliszka', 'Skóra smocza'],
};

const REFINED_ICON: Record<ResourceKind, string> = {
  wood: 'planks',
  stone: 'blocks',
  ore: 'bars',
  fiber: 'cloth',
  hide: 'leather',
};

export const rawId = (kind: ResourceKind, tier: number) => `${kind}_t${tier}`;
export const refinedId = (kind: ResourceKind, tier: number) => `${REFINED_ICON[kind]}_t${tier}`;

function rawValue(tier: number) {
  return 2 * 3 ** (tier - 1);
}

/** Wartość materiału przetworzonego = koszt surowców receptury rafinacji × 1,1. */
function refinedValue(tier: number): number {
  if (tier === 1) return Math.round(rawValue(1) * 1.1);
  return Math.round((2 * rawValue(tier) + refinedValue(tier - 1)) * 1.1);
}

const defs: ItemDef[] = [];

for (const kind of ['wood', 'stone', 'ore', 'fiber', 'hide'] as ResourceKind[]) {
  for (const t of TIERS) {
    defs.push({
      id: rawId(kind, t),
      name: `${RAW_NAMES[kind][t]} (T${t})`,
      icon: kind === 'hide' ? 'hide' : kind,
      category: 'resource',
      resource: kind,
      tier: t,
      weight: 3,
      value: rawValue(t),
      stackable: true,
      description: 'Surowiec – przetwórz go w rafinerii.',
    });
    defs.push({
      id: refinedId(kind, t),
      name: `${REFINED_NAMES[kind][t]} (T${t})`,
      icon: REFINED_ICON[kind],
      category: 'material',
      resource: kind,
      tier: t,
      weight: 2,
      value: refinedValue(t),
      stackable: true,
      description: 'Materiał rzemieślniczy.',
    });
  }
}

// ---------------------------------------------------------------------------
// Ekwipunek z szablonów. Wartość liczona później z receptur (recipes.ts).
// ---------------------------------------------------------------------------

const TIER_WORD = ['', 'Nowicjusza', 'Czeladnika', 'Adepta', 'Eksperta', 'Mistrza', 'Arcymistrza', 'Legendy', 'Pradawnych'];

export interface GearTemplate {
  base: string;
  name: string;
  icon: string;
  category: ItemCategory;
  slot?: EquipSlot;
  weight: number;
  skill?: SkillName;
  attack?: number;
  defense?: number;
  armor?: number;
  hpBonus?: number;
  mpBonus?: number;
  range?: number;
  twoHanded?: boolean;
  tool?: ToolKind;
  /** Premia do czarów na T1 (rośnie o 0,05 na tier). */
  spellPower?: number;
}

export const GEAR_TEMPLATES: GearTemplate[] = [
  // Broń
  { base: 'sword', name: 'Miecz', icon: 'sword', category: 'weapon', slot: 'weapon', weight: 30, skill: 'sword', attack: 10, defense: 8, range: 1 },
  { base: 'axe', name: 'Topór', icon: 'axe', category: 'weapon', slot: 'weapon', weight: 35, skill: 'axe', attack: 12, defense: 5, range: 1 },
  { base: 'mace', name: 'Buława', icon: 'club', category: 'weapon', slot: 'weapon', weight: 35, skill: 'club', attack: 11, defense: 6, range: 1 },
  { base: 'staff', name: 'Kostur', icon: 'staff', category: 'weapon', slot: 'weapon', weight: 22, skill: 'magic', attack: 7, range: 4, twoHanded: true, mpBonus: 10, spellPower: 0.1 },
  { base: 'bow', name: 'Łuk', icon: 'bow', category: 'weapon', slot: 'weapon', weight: 20, skill: 'distance', attack: 13, range: 6, twoHanded: true },
  { base: 'shield', name: 'Tarcza', icon: 'shield', category: 'shield', slot: 'shield', weight: 40, defense: 14 },
  // Pancerz płytowy – najwyższy pancerz
  { base: 'plate_head', name: 'Hełm płytowy', icon: 'plate_head', category: 'armor', slot: 'head', weight: 35, armor: 2 },
  { base: 'plate_body', name: 'Zbroja płytowa', icon: 'plate_body', category: 'armor', slot: 'body', weight: 90, armor: 5 },
  { base: 'plate_legs', name: 'Nagolenniki płytowe', icon: 'plate_legs', category: 'armor', slot: 'legs', weight: 50, armor: 3 },
  { base: 'plate_feet', name: 'Buty płytowe', icon: 'plate_feet', category: 'armor', slot: 'feet', weight: 25, armor: 2 },
  // Pancerz skórzany – średni pancerz + zdrowie
  { base: 'leather_head', name: 'Kaptur skórzany', icon: 'leather_head', category: 'armor', slot: 'head', weight: 15, armor: 1, hpBonus: 5 },
  { base: 'leather_body', name: 'Kurtka skórzana', icon: 'leather_body', category: 'armor', slot: 'body', weight: 45, armor: 3, hpBonus: 15 },
  { base: 'leather_legs', name: 'Spodnie skórzane', icon: 'leather_legs', category: 'armor', slot: 'legs', weight: 20, armor: 2, hpBonus: 10 },
  { base: 'leather_feet', name: 'Buty skórzane', icon: 'leather_feet', category: 'armor', slot: 'feet', weight: 10, armor: 1, hpBonus: 5 },
  // Pancerz materiałowy – niski pancerz + mana
  { base: 'cloth_head', name: 'Kaptur z płótna', icon: 'cloth_head', category: 'armor', slot: 'head', weight: 8, armor: 0, mpBonus: 8 },
  { base: 'cloth_body', name: 'Szata', icon: 'cloth_body', category: 'armor', slot: 'body', weight: 20, armor: 1, mpBonus: 25 },
  { base: 'cloth_legs', name: 'Spodnie z płótna', icon: 'cloth_legs', category: 'armor', slot: 'legs', weight: 10, armor: 1, mpBonus: 15 },
  { base: 'cloth_feet', name: 'Sandały', icon: 'cloth_feet', category: 'armor', slot: 'feet', weight: 6, armor: 0, mpBonus: 8 },
  // Narzędzia zbierackie
  { base: 'woodaxe', name: 'Siekiera drwala', icon: 'woodaxe', category: 'tool', weight: 15, tool: 'woodaxe' },
  { base: 'pickaxe', name: 'Kilof', icon: 'pickaxe', category: 'tool', weight: 15, tool: 'pickaxe' },
  { base: 'sickle', name: 'Sierp', icon: 'sickle', category: 'tool', weight: 8, tool: 'sickle' },
];

export const gearId = (base: string, tier: number) => `${base}_t${tier}`;

for (const g of GEAR_TEMPLATES) {
  for (const t of TIERS) {
    const m = tierMult(t);
    const d: ItemDef = {
      id: gearId(g.base, t),
      name: `${g.name} ${TIER_WORD[t]} (T${t})`,
      icon: g.icon,
      category: g.category,
      tier: t,
      weight: g.weight,
      value: 0, // uzupełniane z receptur
    };
    if (g.slot) {
      d.slot = g.slot;
      d.minLevel = TIER_MIN_LEVEL[t];
    }
    if (g.skill) d.skill = g.skill;
    if (g.attack) d.attack = Math.round(g.attack * m);
    if (g.defense) d.defense = Math.round(g.defense * m);
    if (g.armor !== undefined) d.armor = Math.round(g.armor * m);
    if (g.hpBonus) d.hpBonus = Math.round(g.hpBonus * m);
    if (g.mpBonus) d.mpBonus = Math.round(g.mpBonus * m);
    if (g.range) d.range = g.range;
    if (g.twoHanded) d.twoHanded = true;
    if (g.spellPower) {
      d.spellPower = Math.round((g.spellPower + (t - 1) * 0.05) * 100) / 100;
      d.description = `Siła czarów +${Math.round(d.spellPower * 100)}%.`;
    }
    if (g.tool) {
      d.tool = g.tool;
      d.description = `Pozwala zbierać surowce do T${t}.`;
    }
    defs.push(d);
  }
}

// ---------------------------------------------------------------------------
// Pozostałe
// ---------------------------------------------------------------------------

defs.push(
  { id: 'gold', name: 'Złota moneta', icon: 'gold', category: 'misc', weight: 0.01, value: 1, stackable: true },
  { id: 'meat', name: 'Mięso', icon: 'meat', category: 'consumable', weight: 1, value: 2, stackable: true, use: { heal: 15 }, description: 'Przywraca trochę zdrowia.' },
  { id: 'bone', name: 'Popielna kość', icon: 'bone', category: 'misc', weight: 1, value: 4, stackable: true, description: 'Pachnie spalenizną. Kupcy za nią płacą.' },
  { id: 'hp_potion', name: 'Mikstura życia', icon: 'hp_potion', category: 'consumable', weight: 1.5, value: 30, stackable: true, use: { heal: 70 } },
  { id: 'mp_potion', name: 'Mikstura many', icon: 'mp_potion', category: 'consumable', weight: 1.5, value: 30, stackable: true, use: { mana: 60 } },
  { id: 'great_hp_potion', name: 'Wielka mikstura życia', icon: 'hp_potion', tier: 5, category: 'consumable', weight: 1.8, value: 120, stackable: true, use: { heal: 260 } },
  { id: 'great_mp_potion', name: 'Wielka mikstura many', icon: 'mp_potion', tier: 5, category: 'consumable', weight: 1.8, value: 130, stackable: true, use: { mana: 220 } },
  { id: 'dragon_scale', name: 'Łuska Żarogniewa', icon: 'hide', tier: 8, category: 'misc', weight: 2, value: 2500, stackable: true, description: 'Trofeum z Popielnego Smoka. Kolekcjonerzy płacą fortunę.' },
  { id: 'frost_crown', name: 'Korona Szronu', icon: 'plate_head', tier: 7, category: 'misc', weight: 5, value: 3000, description: 'Lodowa korona zdjęta z Króla Szronu.' },
  { id: 'worm_fang', name: 'Kieł Pustynnego Czerwia', icon: 'bone', tier: 7, category: 'misc', weight: 3, value: 2200, stackable: true, description: 'Trofeum z pustyni.' },
  { id: 'bog_heart', name: 'Serce Matki Moczarów', icon: 'meat', tier: 7, category: 'misc', weight: 2, value: 2400, description: 'Wciąż bije.' },
);

// ---------------------------------------------------------------------------
// Wierzchowce (trzymane w plecaku, przycisk „wierzchowiec” – wsiadanie / zsiadanie)
// ---------------------------------------------------------------------------

defs.push(
  { id: 'mount_horse', name: 'Koń wierzchowy', icon: 'mount_horse', tier: 3, category: 'mount', weight: 0, value: 900, minLevel: 5, mount: { speed: 0.3 }, description: 'Szybkość +30%.' },
  { id: 'mount_elk', name: 'Łoś szronowy', icon: 'mount_elk', tier: 4, category: 'mount', weight: 0, value: 3500, minLevel: 15, mount: { speed: 0.3, cap: 250 }, description: 'Szybkość +30%, udźwig +250.' },
  { id: 'mount_camel', name: 'Wielbłąd juczny', icon: 'mount_camel', tier: 4, category: 'mount', weight: 0, value: 3000, minLevel: 15, mount: { speed: 0.22, cap: 500 }, description: 'Szybkość +22%, udźwig +500.' },
  { id: 'mount_warwolf', name: 'Wilk bojowy', icon: 'mount_warwolf', tier: 5, category: 'mount', weight: 0, value: 9000, minLevel: 25, mount: { speed: 0.4 }, description: 'Szybkość +40%.' },
  { id: 'mount_drake', name: 'Popielny drake', icon: 'mount_drake', tier: 8, category: 'mount', weight: 0, value: 60000, minLevel: 40, mount: { speed: 0.5, cap: 200 }, description: 'Szybkość +50%, udźwig +200. Wykluty z jaja Żarogniewa.' },
);

export const ITEMS: Record<string, ItemDef> = Object.fromEntries(defs.map((d) => [d.id, d]));
export const ITEM_LIST: ItemDef[] = defs;

/**
 * Stare identyfikatory z ETAPU 1 -> nowe (migracja zapisanych postaci).
 * [nowe id, jakość]
 */
export const LEGACY_ITEMS: Record<string, [string, number]> = {
  rusty_sword: ['sword_t1', 1],
  hatchet: ['axe_t1', 1],
  club: ['mace_t1', 1],
  hunting_bow: ['bow_t1', 1],
  ash_sword: ['sword_t2', 3],
  wooden_shield: ['shield_t1', 1],
  leather_helmet: ['leather_head_t1', 1],
  leather_armor: ['leather_body_t1', 1],
  leather_legs: ['leather_legs_t1', 1],
  leather_boots: ['leather_feet_t1', 1],
  chain_armor: ['plate_body_t2', 1],
  wolf_pelt: ['hide_t3', 1],
};

export function getItem(id: string): ItemDef | undefined {
  return ITEMS[id];
}
