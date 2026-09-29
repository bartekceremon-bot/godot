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
const DEATH_EXP_LOSS = 0.05;
const MONSTER_LEASH = 14;

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
  private spawnStates: SpawnState[] = [];
  private fxQueue: Fx[] = [];
  private timer: NodeJS.Timeout | null = null;
  private lastAutosave = Date.now();

  constructor(db: GameDatabase, map: GameMap = generateWorld()) {
    this.db = db;
    this.map = map;
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
      for (let k = 0; k < s.count; k++) this.spawnMonster(i);
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
    // Jeśli postać jest w złym miejscu (np. zmiana mapy) – przenieś do świątyni.
    if (!this.map.isWalkable(p.x, p.y)) {
      p.x = this.map.temple.x;
      p.y = this.map.temple.y;
    }
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
    // Za szybko (speedhack / lag) albo pole zajęte → korekta pozycji u klienta.
    if (now < p.nextMoveAt - MOVE_TOLERANCE_MS || !this.canPlayerStep(nx, ny)) {
      p.send({ t: 'pos', x: p.x, y: p.y, d: p.dir });
      return;
    }
    const diagonal = dx !== 0 && dy !== 0;
    const step = Math.round(p.stepMs() * (diagonal ? 1.4 : 1));
    p.gathering = null;
    p.talkingTo = 0;
    p.x = nx;
    p.y = ny;
    p.dir = dirFromDelta(dx, dy, p.dir);
    p.lastStepMs = step;
    p.nextMoveAt = Math.max(now, p.nextMoveAt) + step;
  }

  private canPlayerStep(x: number, y: number): boolean {
    if (!this.map.isWalkable(x, y)) return false;
    // Gracze nie blokują się nawzajem (zapobiega blokowaniu bram), potwory i NPC tak.
    for (const m of this.monsters.values()) if (m.x === x && m.y === y) return false;
    for (const n of this.npcs.values()) if (n.x === x && n.y === y) return false;
    return true;
  }

  private handleAttack(p: Player, id: number) {
    if (!id) {
      p.targetId = 0;
      return;
    }
    const m = this.monsters.get(id);
    if (!m) return;
    if (this.map.isProtectionZone(p.x, p.y)) {
      this.sendSystem(p, 'Nie możesz walczyć w strefie ochronnej.');
      return;
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

    if (text.startsWith('/')) {
      const cmd = text.slice(1).split(' ')[0].toLowerCase();
      if (cmd === 'online' || cmd === 'who') {
        const names = [...this.players.values()].map((o) => `${o.name} (${o.level})`);
        this.sendSystem(p, `Online (${names.length}): ${names.join(', ')}`);
      } else if (cmd === 'pomoc' || cmd === 'help') {
        this.sendSystem(p, 'Komendy: /online, /pomoc. Czar leczący: exura.');
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
    for (const m of this.monsters.values()) this.tickMonster(m, now);
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
    // Automatyczny atak celu
    if (!p.targetId) return;
    const m = this.monsters.get(p.targetId);
    if (!m || chebyshev(p.x, p.y, m.x, m.y) > 9) {
      p.targetId = 0;
      return;
    }
    if (now < p.nextAttackAt || this.map.isProtectionZone(p.x, p.y)) return;
    const weapon = p.weapon();
    const range = weapon?.range ?? 1;
    const dist = chebyshev(p.x, p.y, m.x, m.y);
    if (dist > range) return;
    if (range > 1 && !this.map.hasLineOfSight(p.x, p.y, m.x, m.y)) return;

    p.nextAttackAt = now + ATTACK_INTERVAL_MS;
    p.lastCombatAt = now;
    p.dir = dirFromDelta(m.x - p.x, m.y - p.y, p.dir);
    if (!m.targetId) m.targetId = p.id;

    const skillName: SkillName = weapon?.skill ?? 'club';
    const skill = p.skills[skillName].level;
    if (addSkillTries(p.skills, skillName, 1)) this.announceSkill(p, skillName);

    if (range > 1) {
      this.fxQueue.push({ x: p.x, y: p.y, k: 'shot', tx: m.x, ty: m.y });
      if (!chance(distanceHitChance(skill, dist))) {
        this.fxQueue.push({ x: m.x, y: m.y, k: 'miss' });
        return;
      }
    }
    const attack = weapon?.attack ? weapon.attack * p.qualityMult('weapon') : FIST_ATTACK;
    const maxDmg = playerMaxDamage(attack, skill, p.level);
    const dmg = rollDamage(maxDmg, m.def.armor, m.def.defense);
    this.damageMonster(m, dmg, p);
  }

  private damageMonster(m: Monster, dmg: number, attacker: Player) {
    if (dmg <= 0) {
      this.fxQueue.push({ x: m.x, y: m.y, k: 'block' });
      return;
    }
    m.hp -= dmg;
    this.fxQueue.push({ x: m.x, y: m.y, k: 'num', v: dmg, c: 'dmg' });
    if (m.hp <= 0) this.killMonster(m, attacker);
  }

  private killMonster(m: Monster, killer: Player) {
    this.monsters.delete(m.id);
    const st = this.spawnStates[m.spawnIndex];
    st.alive.delete(m.id);
    st.pending.push(Date.now() + m.def.respawnMs);
    this.fxQueue.push({ x: m.x, y: m.y, k: 'death', look: m.def.look });
    for (const p of this.players.values()) if (p.targetId === m.id) p.targetId = 0;

    // Loot ląduje na ziemi – trzeba go podnieść (dotknij przedmiotu).
    for (const l of m.def.loot) {
      if (!chance(l.chance)) continue;
      this.addGroundItem(m.x, m.y, l.item, randInt(l.min ?? 1, l.max ?? 1));
    }
    // Oskórowanie zwierzęcia – skóra zależna od tieru zwierzęcia i specjalizacji zabójcy.
    if (m.def.hideTier) {
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
    this.giveExp(killer, m.def.exp);
    this.sendSystem(killer, `Pokonałeś: ${m.name}. +${m.def.exp} doświadczenia.`);
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

  private announceSkill(p: Player, skill: SkillName) {
    this.sendSystem(p, `Awans: ${SKILL_LABELS[skill]} – poziom ${p.skills[skill].level}.`);
  }

  private addGroundItem(x: number, y: number, item: string, count: number, q = 1) {
    // Stos tego samego przedmiotu na tym samym polu łączymy.
    const def = getItem(item);
    if (def?.stackable)
      for (const g of this.groundItems.values())
        if (g.x === x && g.y === y && g.item === item && g.q === q) {
          g.count += count;
          g.expiresAt = Date.now() + GROUND_ITEM_TTL_MS;
          return;
        }
    const id = allocEntityId();
    this.groundItems.set(id, { id, x, y, item, count, q, expiresAt: Date.now() + GROUND_ITEM_TTL_MS });
  }

  // =========================================================================
  // Potwory
  // =========================================================================

  private spawnMonster(spawnIndex: number): boolean {
    const s = this.map.spawns[spawnIndex];
    const def = MONSTERS[s.monster];
    for (let attempt = 0; attempt < 10; attempt++) {
      const x = s.x + randInt(-2, 2);
      const y = s.y + randInt(-2, 2);
      if (!this.canMonsterStep(x, y)) continue;
      // Nie odradzamy potwora na oczach gracza stojącego tuż obok.
      let near = false;
      for (const p of this.players.values()) if (chebyshev(p.x, p.y, x, y) <= 2) near = true;
      if (near) continue;
      const m = new Monster(def, x, y, spawnIndex);
      this.monsters.set(m.id, m);
      this.spawnStates[spawnIndex].alive.add(m.id);
      return true;
    }
    return false;
  }

  private tickSpawns(now: number) {
    this.spawnStates.forEach((st, i) => {
      const due = st.pending.filter((t) => t <= now);
      if (!due.length) return;
      st.pending = st.pending.filter((t) => t > now);
      for (const _ of due) if (!this.spawnMonster(i)) st.pending.push(now + 5000);
    });
  }

  private canMonsterStep(x: number, y: number): boolean {
    if (!this.map.isWalkable(x, y) || this.map.isProtectionZone(x, y)) return false;
    for (const m of this.monsters.values()) if (m.x === x && m.y === y) return false;
    for (const p of this.players.values()) if (p.x === x && p.y === y) return false;
    return true;
  }

  private tickMonster(m: Monster, now: number) {
    const spawn = this.map.spawns[m.spawnIndex];
    // Wybór / weryfikacja celu
    let target = m.targetId ? this.players.get(m.targetId) : undefined;
    if (
      target &&
      (chebyshev(target.x, target.y, m.x, m.y) > 10 ||
        this.map.isProtectionZone(target.x, target.y) ||
        chebyshev(m.x, m.y, spawn.x, spawn.y) > MONSTER_LEASH)
    ) {
      target = undefined;
      m.targetId = 0;
    }
    if (!target) {
      let best = Infinity;
      for (const p of this.players.values()) {
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
    if (chebyshev(m.x, m.y, spawn.x, spawn.y) > 4) {
      this.stepToward(m, spawn.x, spawn.y, now);
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
    const step = Math.round(m.def.stepMs * (dx !== 0 && dy !== 0 ? 1.4 : 1));
    m.x = nx;
    m.y = ny;
    m.dir = dirFromDelta(dx, dy, m.dir);
    m.lastStepMs = step;
    m.nextMoveAt = now + step;
    return true;
  }

  private monsterAttack(m: Monster, p: Player, now: number) {
    p.lastCombatAt = now;
    const shield = p.shield();
    const weapon = p.weapon();
    if (shield && addSkillTries(p.skills, 'shielding', 1)) this.announceSkill(p, 'shielding');
    const def = playerDefense(
      (shield?.defense ?? 0) * p.qualityMult('shield'),
      (weapon?.defense ?? 0) * p.qualityMult('weapon'),
      p.skills.shielding.level,
    );
    const dmg = rollDamage(m.def.maxDamage, p.inventory.totalArmor(), def);
    if (dmg <= 0) {
      this.fxQueue.push({ x: p.x, y: p.y, k: 'block' });
      return;
    }
    p.hp -= dmg;
    this.fxQueue.push({ x: p.x, y: p.y, k: 'num', v: dmg, c: 'dmg' });
    if (p.hp <= 0) this.killPlayer(p, m);
  }

  private killPlayer(p: Player, killer: Monster) {
    this.fxQueue.push({ x: p.x, y: p.y, k: 'death', look: 'player' });
    // Kara za śmierć (ETAP 1 – prosta; pełny system z błogosławieństwami w ETAPIE 3).
    const lost = Math.floor(p.exp * DEATH_EXP_LOSS);
    p.exp -= lost;
    p.level = levelForExp(p.exp);
    p.hp = p.maxHp();
    p.mp = p.maxMp();
    p.targetId = 0;
    p.x = this.map.temple.x;
    p.y = this.map.temple.y;
    p.nextMoveAt = 0;
    for (const m of this.monsters.values()) if (m.targetId === p.id) m.targetId = 0;
    p.send({ t: 'pos', x: p.x, y: p.y, d: p.dir });
    p.send({ t: 'died', by: killer.name, lost });
    this.sendSystem(p, `Zginąłeś! Zabójca: ${killer.name}. Straciłeś ${lost} doświadczenia.`);
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
          ents.push({ i: o.id, k: 'p', n: o.name, x: o.x, y: o.y, d: o.dir, h: hpPct(o.hp, o.maxHp()), l: o.look, s: o.lastStepMs, eq: equipLook(o) });
      for (const m of this.monsters.values())
        if (this.inView(p, m.x, m.y))
          ents.push({ i: m.id, k: 'm', n: m.name, x: m.x, y: m.y, d: m.dir, h: hpPct(m.hp, m.maxHp()), l: m.def.look, s: m.lastStepMs });
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
