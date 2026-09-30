/**
 * Świat gry – autorytatywna symulacja. Tu dzieje się cała logika:
 * ruch, walka, AI potworów, loot, doświadczenie, czat.
 *
 * Klient wysyła jedynie INTENCJE (idź w lewo, atakuj potwora #12, rzuć „exura”),
 * serwer sprawdza czy są dozwolone i rozsyła wynik.
 */
import { config } from '../config';
import type { GameDatabase } from '../db/types';
import { GameMap, generateWorld } from './map';
import { MONSTERS } from './data/monsters';
import { ITEM_LIST, getItem, EquipSlot, EQUIP_SLOTS, SkillName, rawId, QUALITY_NAMES } from './data/items';
import { SPELLS, SPELL_LIST, findSpellByWords, healAmount } from './data/spells';
import { RECIPE_LIST, STATION_NAMES } from './data/recipes';
import { NPCS } from './data/npcs';
import { Player, Monster, GroundItem, MOVE_VECTORS, allocEntityId, dirFromDelta, Npc, ResourceNode } from './entities';
import { DepotStore } from './economy/depot';
import { Market } from './economy/market';
import { GatheringSystem } from './systems/gathering';
import { EconomySystem } from './systems/economy';
import { SPEC_DEFS, TIER_SPEC_REQ, addFame, bonusYieldChance, fameForTier } from './specs';
import { PvpSystem } from './systems/pvp';
import { AbilitySystem } from './systems/abilities';
import { ABILITY_LIST } from './data/abilities';
import { GuildSystem } from './systems/guilds';
import { TerritorySystem } from './systems/territories';
import { CITIES, cityAt, cityTemple } from './data/cities';

/** Cel ataku: potwór albo gracz. */
export type Target = Monster | Player;

/** Po śmierci w PvP przedmioty leżą dłużej (zwłoki do ograbienia). */
const CORPSE_TTL_MS = 5 * 60_000;
const FRENZY_ATTACK_MS = 1200;
const SLOW_FACTOR = 1.6;
import { addSkillTries, levelForExp } from './progression';
import { playerMaxDamage, rollDamage, distanceHitChance, playerDefense, chebyshev, FIST_ATTACK } from './combat';
import { randInt, chance } from '../util/rng';

/** Polskie nazwy skilli do komunikatów. */
const SKILL_LABELS: Record<SkillName, string> = {
  sword: 'Walka mieczem',
  axe: 'Walka toporem',
  club: 'Walka maczugą',
  distance: 'Walka na dystans',
  magic: 'Poziom magii',
  shielding: 'Obrona tarczą',
  fishing: 'Wędkarstwo',
};

const ATTACK_INTERVAL_MS = 2000;
const REGEN_INTERVAL_MS = 2000;
const GROUND_ITEM_TTL_MS = 120_000;
// Tolerancja na jitter sieci. Ruch jest „budżetowany” (nextMoveAt rośnie o pełny krok),
// więc tolerancja nie daje trwałego przyspieszenia – tylko jednorazowy zapas.
const MOVE_TOLERANCE_MS = 150;
const CHAT_INTERVAL_MS = 400;
const MONSTER_LEASH = 14;
/** Potwory dalej niż tyle pól od każdego gracza „śpią” (oszczędność CPU na dużej mapie). */
const DORMANT_RANGE = 22;
/** Wersja mapy – zmiana świata przenosi zapisane postacie do świątyni. */
export const MAP_VERSION = 2;

interface SpawnState {
  alive: Set<number>;
  /** Czasy, w których mają się odrodzić brakujące potwory. */
  pending: number[];
}

/** Efekt wizualny rozsyłany do graczy w pobliżu. */
type Fx = { x: number; y: number; [k: string]: unknown };

export class World {
  readonly map: GameMap;
  readonly db: GameDatabase;
  readonly players = new Map<number, Player>();
  readonly monsters = new Map<number, Monster>();
  readonly groundItems = new Map<number, GroundItem>();
  readonly npcs = new Map<number, Npc>();
  readonly nodes = new Map<number, ResourceNode>();
  readonly depots: DepotStore;
  readonly market: Market;
  readonly gathering = new GatheringSystem(this);
  readonly economy = new EconomySystem(this);
  readonly pvp = new PvpSystem(this);
  readonly abilities = new AbilitySystem(this);
  readonly guilds: GuildSystem;
  readonly territories: TerritorySystem;
  /** Zajętość pól przez potwory (id potwora, 0 = wolne) – szybkie sprawdzanie kolizji. */
  private occ: Int32Array;
  private spawnStates: SpawnState[] = [];
  private fxQueue: Fx[] = [];
  private timer: NodeJS.Timeout | null = null;
  private lastAutosave = Date.now();

  constructor(db: GameDatabase, map: GameMap = generateWorld()) {
    this.db = db;
    this.map = map;
    this.occ = new Int32Array(map.width * map.height);
    this.guilds = new GuildSystem(this);
    this.territories = new TerritorySystem(this);
    this.depots = new DepotStore(db);
    this.market = new Market(db, {
      deliverItem: (charId, city, item, count, q) => this.deliver(charId, city, item, count, q),
      deliverGold: (charId, city, amount) => this.deliver(charId, city, 'gold', amount, 1),
      notify: (charId, text) => {
        const p = this.findPlayerByCharId(charId);
        if (p) this.sendSystem(p, text);
      },
    });
    for (const def of NPCS) {
      const n = new Npc(def);
      this.npcs.set(n.id, n);
    }
    for (const ns of map.nodes) {
      const n = new ResourceNode(ns.kind, ns.tier, ns.x, ns.y);
      this.nodes.set(n.id, n);
    }
    this.map.spawns.forEach((s, i) => {
      const st: SpawnState = { alive: new Set(), pending: [] };
      this.spawnStates.push(st);
      for (let k = 0; k < s.count; k++) this.spawnMonster(i, true);
    });
  }

  start() {
    this.timer = setInterval(() => this.tick(Date.now()), config.tickMs);
  }

  stop() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    this.saveAll();
  }

  // =========================================================================
  // Gracze: wejście / wyjście / zapis
  // =========================================================================

  addPlayer(p: Player) {
    // Postać z poprzedniej wersji świata albo w złym miejscu – przenieś do świątyni domowej.
    if (p.pvp.mv !== MAP_VERSION || !this.map.isWalkable(p.x, p.y)) {
      const t = this.homeTemple(p);
      p.x = t.x;
      p.y = t.y;
      p.pvp.mv = MAP_VERSION;
    }
    this.guilds.attach(p);
    this.players.set(p.id, p);
    p.send({
      t: 'welcome',
      protocol: config.protocolVersion,
      id: p.id,
      name: p.name,
      map: { w: this.map.width, h: this.map.height, rows: this.map.toRows() },
      items: ITEM_LIST,
      spells: SPELL_LIST,
      recipes: RECIPE_LIST,
      stations: STATION_NAMES,
      specs: SPEC_DEFS,
      tierSpecReq: TIER_SPEC_REQ,
      qualities: QUALITY_NAMES,
      abilities: ABILITY_LIST,
      zones: this.map.zoneRows(),
      biomes: this.map.biomeRows(),
      cities: this.map.cities,
      territories: this.map.territories,
    });
    p.send({ t: 'pos', x: p.x, y: p.y, d: p.dir });
    p.inventory.dirty = true;
    this.sendSystem(p, `Witaj w Popielnych Królestwach, ${p.name}! Online: ${this.players.size}.`);
    this.broadcastSystem(`${p.name} wchodzi do gry.`, p.id);
  }

  removePlayer(p: Player) {
    if (!this.players.has(p.id)) return;
    this.savePlayer(p);
    this.players.delete(p.id);
    for (const m of this.monsters.values()) if (m.targetId === p.id) m.targetId = 0;
    this.broadcastSystem(`${p.name} opuszcza grę.`);
  }

  /** Świątynia miasta domowego gracza (domyślnie miasto startowe). */
  homeTemple(p: Player): { x: number; y: number } {
    const c = CITIES[p.pvp.home ?? ''];
    return c ? cityTemple(c) : this.map.temple;
  }

  findPlayerByCharId(charId: number): Player | undefined {
    for (const p of this.players.values()) if (p.charId === charId) return p;
    return undefined;
  }

  savePlayer(p: Player) {
    this.db.saveCharacter({
      id: p.charId,
      x: p.x,
      y: p.y,
      level: p.level,
      exp: p.exp,
      hp: p.hp,
      mp: p.mp,
      look: p.look,
      skills: JSON.stringify(p.skills),
      inventory: JSON.stringify(p.inventory.toJSON()),
      specs: JSON.stringify(p.specs),
      pvp: JSON.stringify(p.pvp),
    });
  }

  saveAll() {
    for (const p of this.players.values()) this.savePlayer(p);
  }

  // =========================================================================
  // Obsługa wiadomości od klienta
  // =========================================================================

  handle(p: Player, msg: Record<string, unknown>) {
    const now = Date.now();
    switch (msg.t) {
      case 'move':
        return this.handleMove(p, Number(msg.d), now);
      case 'attack':
        return this.handleAttack(p, Number(msg.id));
      case 'cast':
        return this.castSpell(p, String(msg.spell ?? ''), now);
      case 'say':
        return this.handleSay(p, String(msg.text ?? ''), now);
      case 'pickup':
        return this.handlePickup(p, Number(msg.id));
      case 'equip':
        return this.reportError(p, p.inventory.equipFromBag(Number(msg.slot), p.level));
      case 'unequip':
        if (!EQUIP_SLOTS.includes(msg.slot as EquipSlot)) return;
        return this.reportError(p, p.inventory.unequip(msg.slot as EquipSlot));
      case 'use':
        return this.handleUse(p, Number(msg.slot));
      case 'drop':
        return this.handleDrop(p, Number(msg.slot), msg.count === undefined ? undefined : Number(msg.count));
      case 'who':
        return p.send({ t: 'online', list: [...this.players.values()].map((o) => ({ n: o.name, l: o.level })) });
      // --- ETAP 2: ekonomia ---
      case 'gather':
        return this.gathering.start(p, Number(msg.id), now);
      case 'ability':
        return this.abilities.use(p, Number(msg.slot), now);
      case 'mount':
        return this.toggleMount(p, now);
      case 'npc':
        return this.economy.talk(p, Number(msg.id), String(msg.word ?? ''));
      case 'close':
        p.openWindow = '';
        return;
      case 'shop_buy':
        return this.economy.shopBuy(p, String(msg.item ?? ''), msg.count);
      case 'shop_sell':
        return this.economy.shopSell(p, msg.slot, msg.count);
      case 'depot_put':
        return this.economy.depotPut(p, msg.slot, msg.count);
      case 'depot_take':
        return this.economy.depotTake(p, msg.index, msg.count);
      case 'market_buy':
        return this.economy.marketBuy(p, msg);
      case 'market_sell':
        return this.economy.marketSell(p, msg);
      case 'market_order':
        return this.economy.marketOrder(p, msg);
      case 'market_cancel':
        return this.economy.marketCancel(p, msg.id);
      case 'craft':
        return this.economy.craft(p, String(msg.recipe ?? ''), msg.count);
    }
  }

  /** Dostawa do depozytu (rynek) – także dla graczy offline. */
  private deliver(charId: number, city: string, item: string, count: number, q: number) {
    if (count <= 0) return;
    this.depots.add(charId, city, item, count, q, true);
    const p = this.findPlayerByCharId(charId);
    if (p && p.openWindow === 'depot') this.economy.sendDepot(p, city);
  }

  addFx(f: Fx) {
    this.fxQueue.push(f);
  }

  private reportError(p: Player, err: string | null) {
    if (err) this.sendSystem(p, err);
  }

  private handleMove(p: Player, d: number, now: number) {
    if (!Number.isInteger(d) || d < 0 || d > 7) return;
    const [dx, dy] = MOVE_VECTORS[d];
    const nx = p.x + dx;
    const ny = p.y + dy;
    // Za szybko (speedhack / lag), ogłuszenie albo pole zajęte → korekta pozycji u klienta.
    const pzLocked = now < p.pzLockUntil && this.map.isProtectionZone(nx, ny) && !this.map.isProtectionZone(p.x, p.y);
    if (now < p.nextMoveAt - MOVE_TOLERANCE_MS || p.status.stunned(now) || pzLocked || !this.canPlayerStep(nx, ny)) {
      if (pzLocked) this.sendSystem(p, `Po walce z graczem nie możesz wejść do strefy ochronnej jeszcze przez ${Math.ceil((p.pzLockUntil - now) / 1000)} s.`);
      p.send({ t: 'pos', x: p.x, y: p.y, d: p.dir });
      return;
    }
    const diagonal = dx !== 0 && dy !== 0;
    const step = Math.round(p.stepMs() * (diagonal ? 1.4 : 1) * (p.status.slowed(now) ? SLOW_FACTOR : 1));
    p.gathering = null;
    p.talkingTo = 0;
    p.x = nx;
    p.y = ny;
    p.dir = dirFromDelta(dx, dy, p.dir);
    p.lastStepMs = step;
    p.nextMoveAt = Math.max(now, p.nextMoveAt) + step;
    // Posadzka świątyni ustawia miasto domowe (odrodzenie po śmierci).
    if (this.map.tileAt(nx, ny) === 'x') {
      const c = cityAt(nx, ny);
      if (c && p.pvp.home !== c.id) {
        p.pvp.home = c.id;
        this.sendSystem(p, `${c.name} jest teraz twoim domem – tu odrodzisz się po śmierci.`);
      }
    }
  }

  /** Wsiadanie / zsiadanie z wierzchowca (pierwszy wierzchowiec z plecaka). */
  toggleMount(p: Player, now: number) {
    if (p.mounted) return this.dismount(p, 'Zsiadasz z wierzchowca.');
    if (now - p.lastCombatAt < 5000) return this.sendSystem(p, 'Nie możesz dosiąść wierzchowca w trakcie walki.');
    const s = p.inventory.bag.find((b) => b && getItem(b.item)?.mount);
    if (!s) return this.sendSystem(p, 'Nie masz wierzchowca. Kupisz go u stajennego w każdym mieście.');
    const def = getItem(s.item)!;
    if (p.level < (def.minLevel ?? 0)) return this.sendSystem(p, `${def.name} wymaga poziomu ${def.minLevel}.`);
    p.mounted = s.item;
    p.gathering = null;
    this.fxQueue.push({ x: p.x, y: p.y, k: 'puff' });
    this.sendSystem(p, `Dosiadasz: ${def.name}. ${def.description ?? ''}`);
  }

  dismount(p: Player, text?: string) {
    if (!p.mounted) return;
    p.mounted = '';
    if (text) this.sendSystem(p, text);
  }

  private canPlayerStep(x: number, y: number): boolean {
    if (!this.map.isWalkable(x, y)) return false;
    // Gracze nie blokują się nawzajem (zapobiega blokowaniu bram), potwory i NPC tak.
    if (this.occ[y * this.map.width + x]) return false;
    for (const n of this.npcs.values()) if (n.x === x && n.y === y) return false;
    return true;
  }

  private handleAttack(p: Player, id: number) {
    if (!id) {
      p.targetId = 0;
      return;
    }
    const t = this.getTarget(id);
    if (!t) return;
    if (this.map.isProtectionZone(p.x, p.y)) {
      this.sendSystem(p, 'Nie możesz walczyć w strefie ochronnej.');
      return;
    }
    if (t instanceof Player) {
      if (this.guilds.sameGuild(p, t)) return this.sendSystem(p, 'Nie możesz atakować członka swojej gildii.');
      const err = this.pvp.canAttack(p, t);
      if (err) return this.sendSystem(p, err);
      if (!this.pvp.isJustified(p, t, Date.now()) && this.pvp.zoneOf(p) === 'yellow' && p.pvp.skull === '')
        this.sendSystem(p, `Uwaga: atak na ${t.name} da ci białą czaszkę.`);
    }
    p.gathering = null;
    p.targetId = id;
  }

  private handleSay(p: Player, raw: string, now: number) {
    const text = raw.replace(/[\u0000-\u001f]/g, '').trim().slice(0, 200);
    if (!text) return;
    // Formuły czarów mają własny cooldown – nie podlegają limitowi czatu.
    const spell = findSpellByWords(text);
    if (spell) return this.castSpell(p, spell.id, now);

    if (now - p.lastChatAt < CHAT_INTERVAL_MS) return;
    p.lastChatAt = now;

    // Słowa kluczowe NPC (Tibia): „witaj”, „handel”… przy NPC trafiają do niego.
    if (!text.startsWith('/') && this.economy.handleChat(p, text)) return;

    if (text.startsWith('/') && this.guilds.command(p, text)) return;
    if (text.startsWith('/')) {
      const cmd = text.slice(1).split(' ')[0].toLowerCase();
      if (cmd === 'online' || cmd === 'who') {
        const names = [...this.players.values()].map((o) => `${o.name} (${o.level})`);
        this.sendSystem(p, `Online (${names.length}): ${names.join(', ')}`);
      } else if (cmd === 'pomoc' || cmd === 'help') {
        this.sendSystem(p, 'Komendy: /online, /pomoc, /gildia, /g tekst (czat gildii), /dom. Czar leczący: exura.');
      } else if (cmd === 'dom') {
        const c = CITIES[p.pvp.home ?? ''];
        this.sendSystem(p, `Twój dom: ${c ? c.name : CITIES.popielgrod.name}. Stań na posadzce świątyni innego miasta, by go zmienić.`);
      } else {
        this.sendSystem(p, 'Nieznana komenda. Wpisz /pomoc.');
      }
      return;
    }
    const chat = { t: 'chat', from: p.name, id: p.id, text, x: p.x, y: p.y };
    for (const o of this.players.values()) o.send(chat);
  }

  private handlePickup(p: Player, id: number) {
    const g = this.groundItems.get(id);
    if (!g || chebyshev(p.x, p.y, g.x, g.y) > 1) return;
    const canTake = Math.min(g.count, p.canCarry(g.item, g.q));
    const left = g.count - canTake + p.inventory.add(g.item, canTake, g.q);
    const taken = g.count - left;
    if (taken === 0) {
      this.sendSystem(p, 'Nie uniesiesz tego (udźwig lub plecak pełny).');
      return;
    }
    if (left > 0) g.count = left;
    else this.groundItems.delete(id);
    const def = getItem(g.item)!;
    this.sendSystem(p, `Podnosisz: ${def.name}${taken > 1 ? ` x${taken}` : ''}.`);
    p.send({ t: 'sfx', k: 'pickup' });
  }

  private handleUse(p: Player, slot: number) {
    const s = p.inventory.bag[slot];
    if (!s) return;
    const def = getItem(s.item);
    if (def?.mount) return this.toggleMount(p, Date.now());
    if (!def?.use) {
      if (def?.slot) this.reportError(p, p.inventory.equipFromBag(slot));
      return;
    }
    p.inventory.takeFromBag(slot, 1);
    if (def.use.heal) this.healPlayer(p, def.use.heal);
    if (def.use.mana) {
      const before = p.mp;
      p.mp = Math.min(p.maxMp(), p.mp + def.use.mana);
      this.fxQueue.push({ x: p.x, y: p.y, k: 'num', v: p.mp - before, c: 'mana' });
    }
    p.send({ t: 'sfx', k: 'drink' });
  }

  private handleDrop(p: Player, slot: number, count?: number) {
    if (!Number.isInteger(slot) || slot < 0 || slot >= p.inventory.bag.length) return;
    const s = p.inventory.takeFromBag(slot, count);
    if (!s) return;
    this.addGroundItem(p.x, p.y, s.item, s.count, s.q ?? 1);
  }

  // =========================================================================
  // Czary
  // =========================================================================

  castSpell(p: Player, spellId: string, now: number) {
    const spell = SPELLS[spellId];
    if (!spell) return;
    if ((p.spellCooldowns[spell.id] ?? 0) > now) return;
    if (p.level < spell.minLevel) return this.sendSystem(p, `Potrzebujesz poziomu ${spell.minLevel}.`);
    if (p.mp < spell.mana) {
      this.fxQueue.push({ x: p.x, y: p.y, k: 'puff' });
      return this.sendSystem(p, 'Za mało many.');
    }
    p.mp -= spell.mana;
    p.spellCooldowns[spell.id] = now + spell.cooldownMs;
    if (addSkillTries(p.skills, 'magic', spell.mana)) this.announceSkill(p, 'magic');

    if (spell.id === 'heal') {
      const { min, max } = healAmount(p.level, p.skills.magic.level);
      this.healPlayer(p, randInt(min, max));
      this.fxQueue.push({ x: p.x, y: p.y, k: 'heal' });
    }
    // Formuła „wypowiadana” nad głową jak w Tibii.
    this.fxQueue.push({ x: p.x, y: p.y, k: 'words', id: p.id, text: spell.words });
  }

  private healPlayer(p: Player, amount: number) {
    const before = p.hp;
    p.hp = Math.min(p.maxHp(), p.hp + amount);
    this.fxQueue.push({ x: p.x, y: p.y, k: 'num', v: p.hp - before, c: 'heal' });
  }

  // =========================================================================
  // Pętla gry
  // =========================================================================

  tick(now: number) {
    this.tickSpawns(now);
    this.gathering.tickNodes(now);
    this.territories.tick(now);
    for (const m of this.monsters.values()) this.tickBleed(m, now);
    for (const p of this.players.values()) this.tickBleed(p, now);
    const active = [...this.players.values()];
    for (const m of this.monsters.values()) this.tickMonster(m, now, active);
    for (const p of this.players.values()) this.tickPlayer(p, now);
    for (const [id, g] of this.groundItems) if (g.expiresAt <= now) this.groundItems.delete(id);
    this.flush();
    if (now - this.lastAutosave > config.autosaveMs) {
      this.lastAutosave = now;
      this.saveAll();
    }
  }

  private tickPlayer(p: Player, now: number) {
    // Regeneracja
    if (now >= p.nextRegenAt) {
      p.nextRegenAt = now + REGEN_INTERVAL_MS;
      p.hp = Math.min(p.maxHp(), p.hp + 1 + Math.floor(p.level / 3));
      p.mp = Math.min(p.maxMp(), p.mp + 2 + Math.floor(p.level / 3));
    }
    // Zdjęcie ekwipunku z premią do HP/many może obniżyć maksimum.
    if (p.hp > p.maxHp()) p.hp = p.maxHp();
    if (p.mp > p.maxMp()) p.mp = p.maxMp();
    if (p.gathering) this.gathering.tick(p, now);
    this.pvp.tick(p, now);
    // Automatyczny atak celu (potwór albo gracz).
    if (!p.targetId) return;
    const t = this.getTarget(p.targetId);
    if (!t || t === p || chebyshev(p.x, p.y, t.x, t.y) > 9) {
      p.targetId = 0;
      return;
    }
    if (t instanceof Player && this.pvp.canAttack(p, t)) {
      p.targetId = 0;
      return;
    }
    if (now < p.nextAttackAt || this.map.isProtectionZone(p.x, p.y) || p.status.stunned(now)) return;
    const { maxDmg, skill, range } = this.playerAttack(p);
    const dist = chebyshev(p.x, p.y, t.x, t.y);
    if (dist > range) return;
    if (range > 1 && !this.map.hasLineOfSight(p.x, p.y, t.x, t.y)) return;

    p.nextAttackAt = now + (now < p.status.frenzyUntil ? FRENZY_ATTACK_MS : ATTACK_INTERVAL_MS);
    p.lastCombatAt = now;
    this.dismount(p, 'Zsiadasz z wierzchowca do walki.');
    p.dir = dirFromDelta(t.x - p.x, t.y - p.y, p.dir);
    if (addSkillTries(p.skills, skill, 1)) this.announceSkill(p, skill);

    if (range > 1) {
      this.fxQueue.push({ x: p.x, y: p.y, k: 'shot', tx: t.x, ty: t.y });
      if (!chance(distanceHitChance(p.skills[skill].level, dist))) {
        this.fxQueue.push({ x: t.x, y: t.y, k: 'miss' });
        return;
      }
    }
    this.hit(p, t, maxDmg, { ranged: range > 1 });
  }

  getTarget(id: number): Target | undefined {
    return this.monsters.get(id) ?? this.players.get(id);
  }

  /** Parametry zwykłego ataku gracza bronią w ręku. */
  playerAttack(p: Player): { maxDmg: number; skill: SkillName; range: number } {
    const weapon = p.weapon();
    const skill: SkillName = weapon?.skill ?? 'club';
    const attack = weapon?.attack ? weapon.attack * p.qualityMult('weapon') : FIST_ATTACK;
    return { maxDmg: playerMaxDamage(attack, p.skills[skill].level, p.level), skill, range: weapon?.range ?? 1 };
  }

  /** Pancerz i obrona celu (z efektami umiejętności). */
  defenseOf(t: Target, now: number): { armor: number; defense: number } {
    if (t instanceof Monster) return { armor: t.def.armor, defense: t.def.defense };
    const shield = t.shield();
    const weapon = t.weapon();
    const defense = playerDefense(
      (shield?.defense ?? 0) * t.qualityMult('shield'),
      (weapon?.defense ?? 0) * t.qualityMult('weapon'),
      t.skills.shielding.level,
    );
    const armor = t.inventory.totalArmor() + (now < t.status.ironskinUntil ? t.status.ironskinArmor : 0);
    return { armor, defense };
  }

  /** Trafienie celu przez gracza (zwykły atak lub umiejętność). */
  hit(attacker: Player, t: Target, maxDmg: number, opts: { ranged?: boolean; ignoreArmor?: boolean }) {
    const now = Date.now();
    const d = this.defenseOf(t, now);
    let dmg = rollDamage(Math.round(maxDmg), opts.ignoreArmor ? 0 : d.armor, d.defense);
    if (t instanceof Player) {
      if (this.guilds.sameGuild(attacker, t)) return;
      if (!opts.ranged && now < t.status.parryUntil) dmg = Math.floor(dmg / 2);
      this.pvp.onAttack(attacker, t, now);
    } else if (!t.targetId) {
      t.targetId = attacker.id;
    }
    this.applyDamage(t, dmg, attacker);
  }

  /** Zadaje obrażenia (efekty, śmierć). source = kto zadał (zasługa za zabójstwo). */
  applyDamage(t: Target, dmg: number, source: Player | Monster | null) {
    if (dmg <= 0) {
      this.fxQueue.push({ x: t.x, y: t.y, k: 'block' });
      return;
    }
    t.hp -= dmg;
    this.fxQueue.push({ x: t.x, y: t.y, k: 'num', v: dmg, c: 'dmg' });
    if (t instanceof Player) {
      t.lastCombatAt = Date.now();
      this.dismount(t, 'Spadasz z wierzchowca!');
    }
    if (t.hp > 0) return;
    if (t instanceof Monster) this.killMonster(t, source instanceof Player ? source : null);
    else this.killPlayer(t, source);
  }

  /** Krwawienie – obrażenia co sekundę. */
  private tickBleed(t: Target, now: number) {
    const st = t.status;
    if (!st.bleedUntil || now < st.bleedNextAt) return;
    if (now > st.bleedUntil) {
      st.bleedUntil = 0;
      return;
    }
    st.bleedNextAt = now + 1000;
    const src = this.players.get(st.bleedSource) ?? null;
    if (t instanceof Monster ? this.monsters.has(t.id) : this.players.has(t.id)) this.applyDamage(t, st.bleedDamage, src);
  }

  private killMonster(m: Monster, killer: Player | null) {
    this.monsters.delete(m.id);
    this.occ[m.y * this.map.width + m.x] = 0;
    const st = this.spawnStates[m.spawnIndex];
    if (st) {
      st.alive.delete(m.id);
      st.pending.push(Date.now() + m.def.respawnMs * (m.def.boss ? config.bossRespawnScale : 1));
    }
    this.fxQueue.push({ x: m.x, y: m.y, k: 'death', look: m.def.look, boss: m.def.boss ? 1 : 0 });
    for (const p of this.players.values()) if (p.targetId === m.id) p.targetId = 0;
    // Sługi przywołującego znikają razem z nim.
    for (const s of [...this.monsters.values()])
      if (s.summonerId === m.id) {
        this.monsters.delete(s.id);
        this.occ[s.y * this.map.width + s.x] = 0;
        this.fxQueue.push({ x: s.x, y: s.y, k: 'puff' });
      }
    if (m.def.boss)
      this.broadcastSystem(`${m.name} ${killer ? `pokonany przez ${killer.name}` : 'pokonany'}! Łup czeka na ziemi – spieszcie się.`);

    // Loot ląduje na ziemi – trzeba go podnieść (dotknij przedmiotu).
    for (const l of m.def.loot) {
      if (!chance(l.chance)) continue;
      this.addGroundItem(m.x, m.y, l.item, randInt(l.min ?? 1, l.max ?? 1), 1, m.def.boss ? CORPSE_TTL_MS : GROUND_ITEM_TTL_MS);
    }
    // Oskórowanie zwierzęcia – skóra zależna od tieru zwierzęcia i specjalizacji zabójcy.
    if (m.def.hideTier && killer && m.summonerId === 0) {
      const t = m.def.hideTier;
      const spec = killer.specs.skinner;
      if (spec.level >= TIER_SPEC_REQ[t]) {
        const n = 1 + (chance(bonusYieldChance(spec.level)) ? 1 : 0);
        this.addGroundItem(m.x, m.y, rawId('hide', t), n);
        if (addFame(killer.specs, 'skinner', fameForTier(t) * n))
          this.sendSystem(killer, `Specjalizacja Oskórowywacz – poziom ${spec.level}!`);
      } else {
        this.sendSystem(killer, `Za mało doświadczenia, by oskórować (Oskórowywacz ${TIER_SPEC_REQ[t]}).`);
      }
    }
    if (!killer) return;
    const bonus = this.territories.hasBonus(killer) ? 1.25 : 1;
    const exp = Math.round(m.def.exp * bonus * (m.summonerId ? 0.3 : 1));
    this.giveExp(killer, exp);
    this.sendSystem(killer, `Pokonałeś: ${m.name}. +${exp} doświadczenia${bonus > 1 ? ' (premia terytorium)' : ''}.`);
  }

  giveExp(p: Player, amount: number) {
    p.exp += amount;
    const newLevel = levelForExp(p.exp);
    if (newLevel > p.level) {
      const oldMaxHp = p.maxHp();
      const oldMaxMp = p.maxMp();
      p.level = newLevel;
      p.hp += p.maxHp() - oldMaxHp;
      p.mp += p.maxMp() - oldMaxMp;
      this.fxQueue.push({ x: p.x, y: p.y, k: 'levelup' });
      this.sendSystem(p, `Awansowałeś na poziom ${newLevel}!`);
    }
  }

  announceSkill(p: Player, skill: SkillName) {
    this.sendSystem(p, `Awans: ${SKILL_LABELS[skill]} – poziom ${p.skills[skill].level}.`);
  }

  private addGroundItem(x: number, y: number, item: string, count: number, q = 1, ttl = GROUND_ITEM_TTL_MS) {
    // Stos tego samego przedmiotu na tym samym polu łączymy.
    const def = getItem(item);
    if (def?.stackable)
      for (const g of this.groundItems.values())
        if (g.x === x && g.y === y && g.item === item && g.q === q) {
          g.count += count;
          g.expiresAt = Date.now() + ttl;
          return;
        }
    const id = allocEntityId();
    this.groundItems.set(id, { id, x, y, item, count, q, expiresAt: Date.now() + ttl });
  }

  // =========================================================================
  // Potwory
  // =========================================================================

  private spawnMonster(spawnIndex: number, initial = false): boolean {
    const s = this.map.spawns[spawnIndex];
    const def = MONSTERS[s.monster];
    for (let attempt = 0; attempt < 12; attempt++) {
      const x = s.x + (attempt === 0 && s.boss ? 0 : randInt(-2, 2));
      const y = s.y + (attempt === 0 && s.boss ? 0 : randInt(-2, 2));
      if (!this.canMonsterStep(x, y)) continue;
      // Nie odradzamy potwora na oczach gracza stojącego tuż obok.
      let near = false;
      for (const p of this.players.values()) if (chebyshev(p.x, p.y, x, y) <= 2) near = true;
      if (near) continue;
      const m = new Monster(def, x, y, spawnIndex);
      m.homeX = s.x;
      m.homeY = s.y;
      this.addMonster(m);
      this.spawnStates[spawnIndex].alive.add(m.id);
      if (def.boss && !initial) this.broadcastSystem(`Ziemia drży! ${def.name} pojawia się w świecie.`);
      return true;
    }
    return false;
  }

  private addMonster(m: Monster) {
    this.monsters.set(m.id, m);
    this.occ[m.y * this.map.width + m.x] = m.id;
  }

  private tickSpawns(now: number) {
    this.spawnStates.forEach((st, i) => {
      if (!st.pending.length) return;
      const due = st.pending.filter((t) => t <= now);
      if (!due.length) return;
      st.pending = st.pending.filter((t) => t > now);
      for (const _ of due) if (!this.spawnMonster(i)) st.pending.push(now + 5000);
    });
  }

  private canMonsterStep(x: number, y: number): boolean {
    if (!this.map.isWalkable(x, y) || this.map.isProtectionZone(x, y)) return false;
    if (this.occ[y * this.map.width + x]) return false;
    for (const p of this.players.values()) if (p.x === x && p.y === y) return false;
    for (const n of this.npcs.values()) if (n.x === x && n.y === y) return false;
    return true;
  }

  private tickMonster(m: Monster, now: number, active: Player[]) {
    if (m.status.stunned(now)) return;
    // Uśpienie: nikogo w pobliżu, potwór w domu – nic nie liczymy.
    let awake = false;
    for (const p of active)
      if (Math.abs(p.x - m.x) <= DORMANT_RANGE && Math.abs(p.y - m.y) <= DORMANT_RANGE) {
        awake = true;
        break;
      }
    if (!awake && !m.targetId && chebyshev(m.x, m.y, m.homeX, m.homeY) <= 4) return;
    const leash = m.def.boss ? 10 : MONSTER_LEASH;
    // Wybór / weryfikacja celu
    let target = m.targetId ? this.players.get(m.targetId) : undefined;
    if (
      target &&
      (chebyshev(target.x, target.y, m.x, m.y) > 10 ||
        this.map.isProtectionZone(target.x, target.y) ||
        chebyshev(m.x, m.y, m.homeX, m.homeY) > leash)
    ) {
      target = undefined;
      m.targetId = 0;
    }
    if (!target) {
      let best = Infinity;
      for (const p of active) {
        const d = chebyshev(p.x, p.y, m.x, m.y);
        if (d <= m.def.aggroRange && d < best && !this.map.isProtectionZone(p.x, p.y)) {
          best = d;
          target = p;
        }
      }
      m.targetId = target?.id ?? 0;
    }

    if (target) {
      const dist = chebyshev(target.x, target.y, m.x, m.y);
      // Atak obszarowy i przywoływanie (bossowie, demony).
      if (m.def.area && now >= m.nextAreaAt && dist <= m.def.area.radius + 2) {
        m.nextAreaAt = now + m.def.area.everyMs;
        this.areaAttack(m, now);
      }
      if (m.def.summon && now >= m.nextSummonAt) {
        m.nextSummonAt = now + m.def.summon.everyMs;
        this.summon(m);
      }
      const r = m.def.ranged;
      if (r && dist <= r.range && dist > 1 && this.map.hasLineOfSight(m.x, m.y, target.x, target.y)) {
        if (now >= m.nextAttackAt) {
          m.nextAttackAt = now + m.def.attackMs;
          m.dir = dirFromDelta(target.x - m.x, target.y - m.y, m.dir);
          this.monsterRanged(m, target, now);
        }
        // Dystansowiec trzyma odległość – nie podchodzi bliżej niż 2 pola.
        if (dist >= 3 || now < m.nextMoveAt) return;
      }
      if (dist <= 1) {
        if (now >= m.nextAttackAt) {
          m.nextAttackAt = now + m.def.attackMs;
          m.dir = dirFromDelta(target.x - m.x, target.y - m.y, m.dir);
          this.monsterAttack(m, target, now);
        }
        return;
      }
      if (now >= m.nextMoveAt) this.stepToward(m, target.x, target.y, now);
      return;
    }

    // Bez celu: wraca na spawn albo spaceruje w okolicy.
    if (now < m.nextMoveAt) return;
    if (chebyshev(m.x, m.y, m.homeX, m.homeY) > 4) {
      this.stepToward(m, m.homeX, m.homeY, now);
    } else if (chance(0.25)) {
      const [dx, dy] = MOVE_VECTORS[randInt(0, 3)];
      this.tryMonsterStep(m, dx, dy, now);
    } else {
      m.nextMoveAt = now + m.def.stepMs;
    }
  }

  /** Zachłanny krok w stronę celu z alternatywami, gdy droga zablokowana. */
  private stepToward(m: Monster, tx: number, ty: number, now: number) {
    const options: [number, number][] = [];
    for (const [dx, dy] of MOVE_VECTORS) options.push([dx, dy]);
    options.sort(
      (a, b) =>
        chebyshev(m.x + a[0], m.y + a[1], tx, ty) +
        (Math.abs(m.x + a[0] - tx) + Math.abs(m.y + a[1] - ty)) * 0.01 -
        (chebyshev(m.x + b[0], m.y + b[1], tx, ty) + (Math.abs(m.x + b[0] - tx) + Math.abs(m.y + b[1] - ty)) * 0.01),
    );
    const curDist = chebyshev(m.x, m.y, tx, ty);
    for (const [dx, dy] of options) {
      if (chebyshev(m.x + dx, m.y + dy, tx, ty) > curDist) break;
      if (this.tryMonsterStep(m, dx, dy, now)) return;
    }
    m.nextMoveAt = now + m.def.stepMs;
  }

  private tryMonsterStep(m: Monster, dx: number, dy: number, now: number): boolean {
    const nx = m.x + dx;
    const ny = m.y + dy;
    if (!this.canMonsterStep(nx, ny)) return false;
    const step = Math.round(m.def.stepMs * (dx !== 0 && dy !== 0 ? 1.4 : 1) * (m.status.slowed(now) ? SLOW_FACTOR : 1));
    const w = this.map.width;
    this.occ[m.y * w + m.x] = 0;
    m.x = nx;
    m.y = ny;
    this.occ[ny * w + nx] = m.id;
    m.dir = dirFromDelta(dx, dy, m.dir);
    m.lastStepMs = step;
    m.nextMoveAt = now + step;
    return true;
  }

  private monsterAttack(m: Monster, p: Player, now: number) {
    p.lastCombatAt = now;
    if (p.shield() && addSkillTries(p.skills, 'shielding', 1)) this.announceSkill(p, 'shielding');
    const d = this.defenseOf(p, now);
    let dmg = rollDamage(m.def.maxDamage, d.armor, d.defense);
    if (now < p.status.parryUntil) dmg = Math.floor(dmg / 2);
    this.applyDamage(p, dmg, m);
    if (m.def.poison && dmg > 0 && this.players.has(p.id)) this.poison(p, m.def.poison, now);
  }

  /** Trucizna: obrażenia co sekundę przez 5 s (jak krwawienie). */
  private poison(p: Player, dmg: number, now: number) {
    const st = p.status;
    st.bleedUntil = now + 5000;
    st.bleedNextAt = now + 1000;
    st.bleedDamage = dmg;
    st.bleedSource = 0;
    this.fxQueue.push({ x: p.x, y: p.y, k: 'poison' });
  }

  private monsterRanged(m: Monster, p: Player, now: number) {
    const r = m.def.ranged!;
    p.lastCombatAt = now;
    this.fxQueue.push({ x: m.x, y: m.y, k: r.fx, tx: p.x, ty: p.y, col: r.color ?? '' });
    const d = this.defenseOf(p, now);
    const dmg = rollDamage(r.maxDamage, r.fx === 'bolt' ? Math.floor(d.armor / 2) : d.armor, r.fx === 'bolt' ? 0 : d.defense);
    this.applyDamage(p, dmg, m);
    if (r.slowMs && dmg > 0) p.status.slowUntil = now + r.slowMs;
  }

  private areaAttack(m: Monster, now: number) {
    const a = m.def.area!;
    this.fxQueue.push({ x: m.x, y: m.y, k: 'aoe', kind: a.fx, r: a.radius });
    if (a.shout) this.fxQueue.push({ x: m.x, y: m.y, k: 'words', id: m.id, text: a.shout });
    for (const p of [...this.players.values()]) {
      if (chebyshev(p.x, p.y, m.x, m.y) > a.radius || this.map.isProtectionZone(p.x, p.y)) continue;
      const d = this.defenseOf(p, now);
      const dmg = rollDamage(a.maxDamage, Math.floor(d.armor / 2), 0);
      this.applyDamage(p, dmg, m);
      if (a.slowMs && this.players.has(p.id)) p.status.slowUntil = now + a.slowMs;
    }
  }

  private summon(m: Monster) {
    const s = m.def.summon!;
    let alive = 0;
    for (const o of this.monsters.values()) if (o.summonerId === m.id) alive++;
    const def = MONSTERS[s.monster];
    for (let k = alive; k < s.count; k++) {
      for (let attempt = 0; attempt < 8; attempt++) {
        const x = m.x + randInt(-2, 2);
        const y = m.y + randInt(-2, 2);
        if (!this.canMonsterStep(x, y)) continue;
        const o = new Monster(def, x, y, -1);
        o.summonerId = m.id;
        o.homeX = m.homeX;
        o.homeY = m.homeY;
        o.targetId = m.targetId;
        this.addMonster(o);
        this.fxQueue.push({ x, y, k: 'puff' });
        break;
      }
    }
  }

  private killPlayer(p: Player, killer: Player | Monster | null) {
    const now = Date.now();
    const zone = this.pvp.zoneOf(p);
    this.fxQueue.push({ x: p.x, y: p.y, k: 'death', look: 'player' });
    // Zabójstwo przez gracza: czaszki, komunikat, nagroda (przed karą ofiary).
    if (killer instanceof Player && killer !== p) {
      this.pvp.onKill(killer, p, this.pvp.isJustified(killer, p, now), zone, now);
      this.giveExp(killer, p.level * 15);
    }
    const res = this.pvp.applyDeath(p, zone);
    // Zwłoki: utracone przedmioty leżą na miejscu śmierci (każdy może je ograbić).
    for (const s of res.dropped) this.addGroundItem(p.x, p.y, s.item, s.count, s.q ?? 1, CORPSE_TTL_MS);
    p.level = levelForExp(p.exp);
    p.hp = p.maxHp();
    p.mp = p.maxMp();
    p.targetId = 0;
    p.gathering = null;
    p.status.bleedUntil = 0;
    p.status.stunUntil = 0;
    p.status.slowUntil = 0;
    p.aggressors.clear();
    p.pzLockUntil = 0;
    p.mounted = '';
    const home = this.homeTemple(p);
    p.x = home.x;
    p.y = home.y;
    p.nextMoveAt = 0;
    for (const m of this.monsters.values()) if (m.targetId === p.id) m.targetId = 0;
    for (const o of this.players.values()) if (o.targetId === p.id) o.targetId = 0;
    const by = killer ? killer.name : 'krwawienie';
    p.send({ t: 'pos', x: p.x, y: p.y, d: p.dir });
    p.send({ t: 'died', by, lost: res.expLost, zone, items: res.dropped.length, bless: res.blessingsUsed });
    this.sendSystem(p, `Zginąłeś! Zabójca: ${by}. Straciłeś ${res.expLost} doświadczenia` +
      (res.dropped.length ? ` i ${res.dropped.length} przedmiotów (leżą w miejscu śmierci).` : '.') +
      (res.blessingsUsed ? ` Zużyto błogosławieństwa: ${res.blessingsUsed}.` : ''));
    p.inventory.dirty = true;
    this.savePlayer(p);
  }

  // =========================================================================
  // Wysyłanie stanu do klientów
  // =========================================================================

  private inView(p: Player, x: number, y: number) {
    return Math.abs(p.x - x) <= config.viewRadiusX && Math.abs(p.y - y) <= config.viewRadiusY;
  }

  /** Rozsyła zmiany stanu (tylko gdy coś się zmieniło) i efekty z bieżącego ticka. */
  private flush() {
    const fx = this.fxQueue;
    this.fxQueue = [];
    for (const p of this.players.values()) {
      const ents: object[] = [];
      for (const o of this.players.values())
        if (this.inView(p, o.x, o.y))
          ents.push({ i: o.id, k: 'p', n: o.name, x: o.x, y: o.y, d: o.dir, h: hpPct(o.hp, o.maxHp()), l: o.look, s: o.lastStepMs, eq: equipLook(o), sk: o.pvp.skull, mt: o.mounted, gt: o.guildTag });
      for (const m of this.monsters.values())
        if (this.inView(p, m.x, m.y))
          ents.push({ i: m.id, k: 'm', n: m.name, x: m.x, y: m.y, d: m.dir, h: hpPct(m.hp, m.maxHp()), l: m.def.look, s: m.lastStepMs, b: m.def.boss ? 1 : 0 });
      for (const t of this.territories.list) if (this.inView(p, t.spot.x, t.spot.y)) ents.push(this.territories.snapshot(t));
      for (const n of this.npcs.values())
        if (this.inView(p, n.x, n.y)) ents.push({ i: n.id, k: 'n', n: n.def.name, x: n.x, y: n.y, d: n.dir, h: 100, l: n.def.look, s: 0 });
      for (const r of this.nodes.values())
        if (!r.respawnAt && this.inView(p, r.x, r.y))
          ents.push({ i: r.id, k: 'r', n: r.name, x: r.x, y: r.y, d: 2, h: hpPct(r.charges, r.maxCharges()), l: `node_${r.kind}_${r.tier}`, s: 0 });
      const ground: object[] = [];
      for (const g of this.groundItems.values())
        if (this.inView(p, g.x, g.y)) ground.push({ i: g.id, x: g.x, y: g.y, it: g.item, c: g.count, q: g.q });

      const snap = JSON.stringify({ t: 'snap', e: ents, g: ground });
      if (snap !== p.lastSnapshot) {
        p.lastSnapshot = snap;
        p.conn.send(snap);
      }
      const stats = JSON.stringify(p.statsPayload());
      if (stats !== p.lastStats) {
        p.lastStats = stats;
        p.conn.send(stats);
      }
      if (p.inventory.dirty) {
        p.inventory.dirty = false;
        p.send({ t: 'inv', bag: p.inventory.bag, eq: p.inventory.equipment });
      }
      const visibleFx = fx.filter((f) => this.inView(p, f.x, f.y));
      if (visibleFx.length) p.send({ t: 'fx', l: visibleFx });
    }
  }

  sendSystem(p: Player, text: string) {
    p.send({ t: 'sys', text });
  }

  broadcastSystem(text: string, exceptId = 0) {
    for (const p of this.players.values()) if (p.id !== exceptId) this.sendSystem(p, text);
  }
}

/** Wygląd ekwipunku (id przedmiotów) – klient rysuje go na postaci: „jesteś tym, co nosisz”. */
function equipLook(p: Player): string[] {
  return EQUIP_SLOTS.map((slot) => p.inventory.equipment[slot]?.item ?? '');
}

function hpPct(hp: number, max: number) {
  return Math.max(0, Math.min(100, Math.round((hp / max) * 100)));
}
