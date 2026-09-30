/**
 * „Dar bohatera” – jednorazowe wzmocnienie wybranych postaci (config.heroNames, zmienna HERO_NAMES).
 * Przy pierwszym logowaniu po włączeniu postać dostaje wysoki poziom, skille, specjalizacje,
 * błogosławieństwa i komplet najlepszego ekwipunku (T8, jakość „arcydzieło”).
 * Dotychczasowy ekwipunek trafia do plecaka, a to, co się nie mieści – do depozytu w mieście domowym.
 * Bohaterom przedmioty nie wypadają po śmierci (keepsItemsOnDeath).
 */
import { config } from '../config';
import { EQUIP_SLOTS, EquipSlot, gearId } from './data/items';
import { Player } from './entities';
import { expForLevel, levelForExp } from './progression';
import { SPEC_DEFS } from './specs';
import { SPELL_LIST } from './data/spells';

/** Podnieś, gdy dar ma zostać przyznany ponownie (np. po rozszerzeniu). */
export const HERO_VERSION = 3;
export const HERO_LEVEL = 100;
const HERO_SKILL = 90;
const HERO_MAGIC = 40;
const HERO_SPEC = 40;
const MASTERPIECE = 5;

const HERO_EQUIPMENT: Record<EquipSlot, string> = {
  head: gearId('plate_head', 8),
  body: gearId('plate_body', 8),
  legs: gearId('plate_legs', 8),
  feet: gearId('plate_feet', 8),
  weapon: gearId('sword', 8),
  shield: gearId('shield', 8),
};

/** Plecak: zapasowa broń każdego rodzaju, narzędzia T8, mikstury, wierzchowiec i złoto. */
const HERO_BAG: [string, number, number][] = [
  ['mount_drake', 1, 1],
  [gearId('axe', 8), 1, MASTERPIECE],
  [gearId('mace', 8), 1, MASTERPIECE],
  [gearId('bow', 8), 1, MASTERPIECE],
  [gearId('woodaxe', 8), 1, MASTERPIECE],
  [gearId('pickaxe', 8), 1, MASTERPIECE],
  [gearId('sickle', 8), 1, MASTERPIECE],
  ['great_hp_potion', 100, 1],
  ['great_mp_potion', 100, 1],
  ['gold', 10000, 1],
];
/** Reszta złota od razu do depozytu (w plecaku zajęłaby 9 kolejnych miejsc). */
const HERO_DEPOT_GOLD = 90000;

export function isHeroName(name: string): boolean {
  return config.heroNames.includes(name.toLowerCase());
}

/**
 * Przyznaje dar, jeśli postać jest na liście i jeszcze go nie dostała.
 * `stash` przyjmuje przedmioty, które nie zmieściły się w plecaku (depozyt).
 * Zwraca true, gdy dar został przyznany.
 */
export function grantHeroGift(p: Player, stash: (item: string, count: number, q: number) => void): boolean {
  if (!isHeroName(p.name) || (p.pvp.hero ?? 0) >= HERO_VERSION) return false;
  const inv = p.inventory;
  if ((p.pvp.hero ?? 0) >= 1) {
    // Wersja 3 daru: ponownie komplet przedmiotów (ekwipunek T8, plecak, kostur) i wszystkie czary.
    grantItems(p, stash);
    grantSpells(p);
    p.pvp.hero = HERO_VERSION;
    return true;
  }

  if (p.level < HERO_LEVEL) {
    p.exp = expForLevel(HERO_LEVEL);
    p.level = levelForExp(p.exp);
  }
  for (const [name, s] of Object.entries(p.skills)) {
    const target = name === 'magic' ? HERO_MAGIC : HERO_SKILL;
    if (s.level < target) {
      s.level = target;
      s.tries = 0;
    }
  }
  for (const d of SPEC_DEFS) {
    const st = p.specs[d.id];
    if (st.level < HERO_SPEC) {
      st.level = HERO_SPEC;
      st.fame = 0;
    }
  }
  p.pvp.blessings = 5;

  grantItems(p, stash);
  grantSpells(p);
  p.hp = p.maxHp();
  p.mp = p.maxMp();
  p.pvp.hero = HERO_VERSION;
  return true;
}

/** Komplet T8 na postać (stary ekwipunek do plecaka/depozytu), plecak bohatera, kostur i złoto. */
function grantItems(p: Player, stash: (item: string, count: number, q: number) => void) {
  const inv = p.inventory;
  for (const slot of EQUIP_SLOTS) {
    const old = inv.equipment[slot];
    if (old && old.item === HERO_EQUIPMENT[slot] && (old.q ?? 1) >= MASTERPIECE) continue;
    if (old) {
      const left = inv.add(old.item, old.count, old.q ?? 1);
      if (left > 0) stash(old.item, left, old.q ?? 1);
    }
    inv.equipment[slot] = { item: HERO_EQUIPMENT[slot], count: 1, q: MASTERPIECE };
  }
  for (const [item, count, q] of [...HERO_BAG, [gearId('staff', 8), 1, MASTERPIECE] as [string, number, number]]) {
    const left = inv.add(item, count, q);
    if (left > 0) stash(item, left, q);
  }
  stash('gold', HERO_DEPOT_GOLD, 1);
  inv.dirty = true;
}

function grantSpells(p: Player) {
  p.pvp.spells = SPELL_LIST.filter((s) => s.id !== 'heal').map((s) => s.id);
}

/** Bohaterowie (HERO_NAMES) nie tracą przedmiotów po śmierci – w żadnej strefie. */
export function keepsItemsOnDeath(p: Player): boolean {
  return isHeroName(p.name);
}
