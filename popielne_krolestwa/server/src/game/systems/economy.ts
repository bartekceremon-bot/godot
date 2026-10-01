/**
 * Ekonomia miasta: rozmowy z NPC, sklep NPC, depozyt, rynek graczy, rafinacja i rzemiosło.
 *
 * Każda operacja wymaga stania przy odpowiednim NPC. Operacje przenoszące przedmioty
 * między graczami / depozytami są wykonywane w jednej transakcji bazy razem z zapisem
 * postaci (brak duplikacji przy awarii serwera).
 */
import type { World } from '../world';
import { Player, Npc } from '../entities';
import { CITIES, GREETINGS, NPC_BUY_RATIO, NPC_RANGE, NpcAction } from '../data/npcs';
import { cityReturn } from '../data/cities';
import { getItem, QUALITY_NAMES } from '../data/items';
import { RECIPES, STATION_NAMES } from '../data/recipes';
import { MAX_ORDERS_PER_PLAYER, MAX_PRICE, Market } from '../economy/market';
import { addFame, canUseTier, fameForTier, returnedAmount, rollQuality, SPEC_DEFS, TIER_SPEC_REQ } from '../specs';
import { chebyshev } from '../combat';

const MAX_AMOUNT = 10_000;

function int(v: unknown): number {
  const n = Number(v);
  return Number.isFinite(n) ? Math.floor(n) : NaN;
}

export class EconomySystem {
  constructor(private world: World) {}

  // =========================================================================
  // Pomocnicze
  // =========================================================================

  /** NPC w zasięgu rozmowy, który obsługuje daną akcję. */
  private npcFor(p: Player, action: NpcAction): Npc | null {
    for (const n of this.world.npcs.values())
      if (chebyshev(p.x, p.y, n.x, n.y) <= NPC_RANGE && Object.values(n.def.keywords).some((k) => k.action === action))
        return n;
    return null;
  }

  private require(p: Player, action: NpcAction): Npc | null {
    const n = this.npcFor(p, action);
    if (!n) this.world.sendSystem(p, 'Musisz stać przy odpowiednim NPC w mieście.');
    return n;
  }

  /** Nauka czaru u kapłana w zasięgu (miasto kapłana decyduje o szkołach). */
  learnSpell(p: Player, spellId: string) {
    const n = this.require(p, 'spells');
    if (n) this.world.spells.learn(p, spellId, n.def.city);
  }

  private gold(p: Player) {
    return p.inventory.countOf('gold');
  }

  /** Daje przedmiot do plecaka; nadwyżka (brak miejsca/udźwigu) trafia do depozytu miasta. */
  private giveOrDeposit(p: Player, city: string, item: string, count: number, q = 1): number {
    const toBag = Math.min(count, p.canCarry(item, q));
    if (toBag > 0) p.inventory.add(item, toBag, q);
    const rest = count - toBag;
    if (rest > 0) {
      this.world.depots.add(p.charId, city, item, rest, q, true);
      this.world.sendSystem(p, `Brak miejsca – ${rest} szt. trafiło do depozytu.`);
      this.sendDepotIfOpen(p, city);
    }
    return rest;
  }

  private sendDepotIfOpen(p: Player, city: string) {
    if (p.openWindow === 'depot') this.sendDepot(p, city);
  }

  // =========================================================================
  // Rozmowa z NPC (słowa kluczowe)
  // =========================================================================

  /** Dotknięcie NPC w kliencie lub słowo wpisane w czat. */
  talk(p: Player, npcId: number, word: string) {
    const n = this.world.npcs.get(npcId);
    if (!n) return;
    if (chebyshev(p.x, p.y, n.x, n.y) > NPC_RANGE) return this.world.sendSystem(p, `${n.def.name} jest za daleko.`);
    const w = word.trim().toLowerCase();
    let text: string;
    if (!w || GREETINGS.includes(w) || p.talkingTo !== n.id) {
      p.talkingTo = n.id;
      text = n.def.greeting.replace('{name}', p.name);
      // Powitanie połączone ze słowem kluczowym („witaj handel”) – od razu obsłuż słowo.
      if (w && !GREETINGS.includes(w) && n.def.keywords[w]) return this.keyword(p, n, w);
    } else if (n.def.keywords[w]) {
      return this.keyword(p, n, w);
    } else {
      text = 'Nie rozumiem. Zapytaj o coś z listy.';
    }
    this.sendDialog(p, n, text);
  }

  private keyword(p: Player, n: Npc, w: string) {
    const kw = n.def.keywords[w];
    this.sendDialog(p, n, kw.text);
    if (w === 'żegnaj') p.talkingTo = 0;
    switch (kw.action) {
      case 'shop':
        return this.sendShop(p, n);
      case 'depot':
        return this.sendDepot(p, n.def.city);
      case 'market':
        return this.sendMarket(p, n.def.city);
      case 'bless':
        return this.sendDialog(p, n, this.world.pvp.buyBlessing(p));
      case 'spells':
        return this.world.spells.offer(p, n.def.city);
      case 'quests':
        return this.world.quests.offer(p, n);
      case 'guild':
        return this.world.guilds.info(p);
      case 'craft':
        if (n.def.station) {
          p.openWindow = 'craft';
          p.send({ t: 'craft_open', station: n.def.station, name: STATION_NAMES[n.def.station], city: CITIES[n.def.city].bonusText });
        }
    }
  }

  private sendDialog(p: Player, n: Npc, text: string) {
    p.send({ t: 'npc_dialog', id: n.id, name: n.def.name, text, keywords: Object.keys(n.def.keywords) });
  }

  /** Czat: jeśli gracz rozmawia z NPC w pobliżu (albo wita się), słowo trafia do NPC. Zwraca true, gdy obsłużone. */
  handleChat(p: Player, text: string): boolean {
    const w = text.trim().toLowerCase();
    let best: Npc | null = null;
    for (const n of this.world.npcs.values()) {
      if (chebyshev(p.x, p.y, n.x, n.y) > NPC_RANGE) continue;
      if (p.talkingTo === n.id) best = n;
      else if (!best && (GREETINGS.includes(w) || GREETINGS.some((g) => w.startsWith(g + ' ')))) best = n;
    }
    if (!best) return false;
    const word = GREETINGS.find((g) => w.startsWith(g + ' ')) ? w.split(' ').slice(1).join(' ') : w;
    this.talk(p, best.id, word);
    return true;
  }

  // =========================================================================
  // Sklep NPC
  // =========================================================================

  static npcBuyPrice(item: string): number {
    const d = getItem(item);
    if (!d || item === 'gold') return 0;
    return Math.max(1, Math.floor(d.value * NPC_BUY_RATIO));
  }

  private sendShop(p: Player, n: Npc) {
    p.openWindow = 'shop';
    p.send({
      t: 'shop',
      npc: n.id,
      name: n.def.name,
      sells: n.def.sells ?? [],
      buys: n.def.buys ?? false,
      buyRatio: NPC_BUY_RATIO,
    });
  }

  shopBuy(p: Player, itemId: string, countRaw: unknown) {
    const n = this.require(p, 'shop');
    if (!n) return;
    const offer = n.def.sells?.find((s) => s.item === itemId);
    const count = int(countRaw);
    if (!offer || !(count >= 1 && count <= 100)) return;
    const cost = offer.price * count;
    if (this.gold(p) < cost) return this.world.sendSystem(p, `Potrzebujesz ${cost} zł.`);
    if (p.canCarry(itemId) < count) return this.world.sendSystem(p, 'Nie uniesiesz tego (udźwig lub plecak).');
    p.inventory.remove('gold', cost);
    p.inventory.add(itemId, count);
    this.world.sendSystem(p, `Kupujesz ${count}× ${getItem(itemId)!.name} za ${cost} zł.`);
    p.send({ t: 'sfx', k: 'pickup' });
  }

  shopSell(p: Player, slot: unknown, countRaw: unknown) {
    const n = this.require(p, 'shop');
    if (!n || !n.def.buys) return;
    const idx = int(slot);
    const s = p.inventory.bag[idx];
    if (!s || s.item === 'gold') return;
    const count = Math.min(s.count, int(countRaw) || 1);
    const price = EconomySystem.npcBuyPrice(s.item) * count;
    p.inventory.takeFromBag(idx, count);
    p.inventory.add('gold', price);
    this.world.sendSystem(p, `Sprzedajesz ${count}× ${getItem(s.item)!.name} za ${price} zł.`);
    p.send({ t: 'sfx', k: 'pickup' });
  }

  // =========================================================================
  // Depozyt
  // =========================================================================

  sendDepot(p: Player, city: string) {
    p.openWindow = 'depot';
    p.send({ t: 'depot', city, cityName: CITIES[city].name, items: this.world.depots.get(p.charId, city) });
  }

  depotPut(p: Player, slot: unknown, countRaw: unknown) {
    const n = this.require(p, 'depot');
    if (!n) return;
    const city = n.def.city;
    const idx = int(slot);
    const s = p.inventory.bag[idx];
    if (!s) return;
    const count = Math.min(s.count, int(countRaw) || s.count);
    this.world.db.transaction(() => {
      if (!this.world.depots.add(p.charId, city, s.item, count, s.q ?? 1)) {
        this.world.sendSystem(p, 'Depozyt jest pełny.');
        return;
      }
      p.inventory.takeFromBag(idx, count);
      this.world.savePlayer(p);
    });
    this.sendDepot(p, city);
  }

  depotTake(p: Player, index: unknown, countRaw: unknown) {
    const n = this.require(p, 'depot');
    if (!n) return;
    const city = n.def.city;
    const items = this.world.depots.get(p.charId, city);
    const idx = int(index);
    const s = items[idx];
    if (!s) return;
    const want = Math.min(s.count, int(countRaw) || s.count);
    const count = Math.min(want, p.canCarry(s.item, s.q ?? 1));
    if (count <= 0) return this.world.sendSystem(p, 'Nie uniesiesz więcej (udźwig lub plecak).');
    this.world.db.transaction(() => {
      const taken = this.world.depots.take(p.charId, city, idx, count)!;
      p.inventory.add(taken.item, taken.count, taken.q ?? 1);
      this.world.savePlayer(p);
    });
    this.sendDepot(p, city);
  }

  // =========================================================================
  // Rynek
  // =========================================================================

  sendMarket(p: Player, city: string) {
    p.openWindow = 'market';
    const book = this.world.market.book(city);
    p.send({
      t: 'market',
      city,
      cityName: CITIES[city].name,
      tax: CITIES[city].marketTax,
      sells: book.sells,
      buys: book.buys,
      mine: this.world.market.mine(p.charId).map((o) => ({
        id: o.id,
        side: o.side,
        item: o.item,
        q: o.quality,
        price: o.price,
        amount: o.amount,
        city: o.city,
      })),
    });
  }

  private validPrice(v: unknown) {
    const n = int(v);
    return n >= 1 && n <= MAX_PRICE ? n : 0;
  }

  /** Natychmiastowy zakup z najtańszych ofert (do ceny maksymalnej). */
  marketBuy(p: Player, msg: Record<string, unknown>) {
    const n = this.require(p, 'market');
    if (!n) return;
    const city = n.def.city;
    const item = String(msg.item ?? '');
    const q = Math.max(1, Math.min(5, int(msg.q) || 1));
    const maxPrice = this.validPrice(msg.price);
    const count = int(msg.count);
    if (!getItem(item) || !maxPrice || !(count >= 1 && count <= MAX_AMOUNT)) return;
    const preview = this.world.market.previewBuy(city, item, q, maxPrice, count, p.charId);
    if (preview.amount === 0) return this.world.sendSystem(p, 'Brak ofert w tej cenie.');
    if (this.gold(p) < preview.cost) return this.world.sendSystem(p, `Potrzebujesz ${preview.cost} zł w plecaku.`);
    this.world.db.transaction(() => {
      const fills = this.world.market.executeBuy(city, item, q, maxPrice, count, p.charId, CITIES[city].marketTax);
      let cost = 0;
      for (const f of fills) {
        cost += f.price * f.amount;
        this.giveOrDeposit(p, city, item, f.amount, f.q);
      }
      p.inventory.remove('gold', cost);
      this.world.savePlayer(p);
      this.world.sendSystem(p, `Kupiono ${preview.amount}× ${getItem(item)!.name} za ${cost} zł.`);
    });
    this.sendMarket(p, city);
  }

  /** Natychmiastowa sprzedaż do najlepszych zleceń kupna (od ceny minimalnej). */
  marketSell(p: Player, msg: Record<string, unknown>) {
    const n = this.require(p, 'market');
    if (!n) return;
    const city = n.def.city;
    const idx = int(msg.slot);
    const s = p.inventory.bag[idx];
    const minPrice = this.validPrice(msg.price);
    if (!s || s.item === 'gold' || !minPrice) return;
    const count = Math.min(s.count, int(msg.count) || 1);
    const q = s.q ?? 1;
    const preview = this.world.market.previewSell(city, s.item, q, minPrice, count, p.charId);
    if (preview.amount === 0) return this.world.sendSystem(p, 'Nikt nie kupuje w tej cenie.');
    this.world.db.transaction(() => {
      p.inventory.takeFromBag(idx, preview.amount);
      const fills = this.world.market.executeSell(city, s.item, q, minPrice, preview.amount, p.charId);
      this.paySeller(p, city, fills.reduce((a, f) => a + f.price * f.amount, 0));
      this.world.savePlayer(p);
    });
    this.sendMarket(p, city);
  }

  /** Wypłata dla sprzedającego (minus podatek) – do plecaka, a nadmiar do depozytu. */
  private paySeller(p: Player, city: string, gross: number) {
    const tax = Market.tax(gross, CITIES[city].marketTax);
    this.giveOrDeposit(p, city, 'gold', gross - tax);
    this.world.sendSystem(p, `Sprzedano za ${gross} zł (podatek ${tax} zł).`);
  }

  /** Nowe zlecenie kupna lub sprzedaży (najpierw realizowane z istniejącymi zleceniami). */
  marketOrder(p: Player, msg: Record<string, unknown>) {
    const n = this.require(p, 'market');
    if (!n) return;
    const city = n.def.city;
    const price = this.validPrice(msg.price);
    if (!price) return this.world.sendSystem(p, 'Nieprawidłowa cena.');
    if (this.world.market.countFor(p.charId) >= MAX_ORDERS_PER_PLAYER)
      return this.world.sendSystem(p, `Możesz mieć najwyżej ${MAX_ORDERS_PER_PLAYER} zleceń.`);
    const market = this.world.market;

    if (msg.side === 'sell') {
      const idx = int(msg.slot);
      const s = p.inventory.bag[idx];
      if (!s || s.item === 'gold') return;
      const count = Math.min(s.count, int(msg.count) || 1);
      const q = s.q ?? 1;
      this.world.db.transaction(() => {
        p.inventory.takeFromBag(idx, count);
        const fills = market.executeSell(city, s.item, q, price, count, p.charId);
        const filled = fills.reduce((a, f) => a + f.amount, 0);
        if (filled > 0) this.paySeller(p, city, fills.reduce((a, f) => a + f.price * f.amount, 0));
        if (count - filled > 0) {
          market.place({ city, char_id: p.charId, char_name: p.name, side: 'sell', item: s.item, quality: q, price, amount: count - filled });
          this.world.sendSystem(p, `Wystawiono ${count - filled}× ${getItem(s.item)!.name} po ${price} zł.`);
        }
        this.world.savePlayer(p);
      });
    } else if (msg.side === 'buy') {
      const item = String(msg.item ?? '');
      const q = Math.max(1, Math.min(5, int(msg.q) || 1));
      const count = int(msg.count);
      if (!getItem(item) || item === 'gold' || !(count >= 1 && count <= MAX_AMOUNT)) return;
      const escrow = price * count;
      if (this.gold(p) < escrow) return this.world.sendSystem(p, `Potrzebujesz ${escrow} zł w plecaku.`);
      this.world.db.transaction(() => {
        p.inventory.remove('gold', escrow);
        const fills = market.executeBuy(city, item, q, price, count, p.charId, CITIES[city].marketTax);
        let filled = 0;
        let spent = 0;
        for (const f of fills) {
          filled += f.amount;
          spent += f.amount * f.price;
          this.giveOrDeposit(p, city, item, f.amount, f.q);
        }
        // Zwrot różnicy między ceną zlecenia a faktyczną ceną zakupu.
        const refund = filled * price - spent;
        if (refund > 0) this.giveOrDeposit(p, city, 'gold', refund);
        if (filled > 0) this.world.sendSystem(p, `Od razu kupiono ${filled} szt. za ${spent} zł.`);
        if (count - filled > 0) {
          market.place({ city, char_id: p.charId, char_name: p.name, side: 'buy', item, quality: q, price, amount: count - filled });
          this.world.sendSystem(p, `Zlecenie kupna: ${count - filled}× ${getItem(item)!.name} po ${price} zł.`);
        }
        this.world.savePlayer(p);
      });
    }
    this.sendMarket(p, city);
  }

  /** Anulowanie zlecenia – escrow wraca do depozytu miasta zlecenia. */
  marketCancel(p: Player, id: unknown) {
    const n = this.require(p, 'market');
    if (!n) return;
    this.world.db.transaction(() => {
      const o = this.world.market.cancel(int(id), p.charId);
      if (!o) return;
      if (o.side === 'sell') this.world.depots.add(p.charId, o.city, o.item, o.amount, o.quality, true);
      else this.world.depots.add(p.charId, o.city, 'gold', o.amount * o.price, 1, true);
      this.world.sendSystem(p, 'Zlecenie anulowane – zwrot trafił do depozytu.');
    });
    this.sendMarket(p, n.def.city);
  }

  // =========================================================================
  // Rafinacja i rzemiosło
  // =========================================================================

  craft(p: Player, recipeId: string, countRaw: unknown) {
    const r = RECIPES[recipeId];
    if (!r) return;
    let station: Npc | null = null;
    for (const n of this.world.npcs.values())
      if (n.def.station === r.station && chebyshev(p.x, p.y, n.x, n.y) <= NPC_RANGE) station = n;
    if (!station) return this.world.sendSystem(p, `Musisz być przy stacji: ${STATION_NAMES[r.station]}.`);
    const city = CITIES[station.def.city];
    if (!canUseTier(p.specs, r.spec, r.tier)) {
      const name = SPEC_DEFS.find((d) => d.id === r.spec)!.name;
      return this.world.sendSystem(p, `Wymagany poziom specjalizacji ${name}: ${TIER_SPEC_REQ[r.tier]}.`);
    }
    const want = Math.max(1, Math.min(100, int(countRaw) || 1));
    const out = getItem(r.output)!;
    const returnRate = cityReturn(city, r.station);
    const used: Record<string, number> = {};
    const qualities = [0, 0, 0, 0, 0, 0];
    let made = 0;
    for (let i = 0; i < want; i++) {
      if (!r.inputs.every((inp) => p.inventory.countOf(inp.item) >= inp.count)) break;
      // Przedmioty z jakością zajmują osobny slot – sprawdzamy miejsce przed wytworzeniem.
      const q = out.stackable ? 1 : rollQuality(p.specs[r.spec].level - TIER_SPEC_REQ[r.tier] + (city.qualityBonusStation === r.station ? city.qualityBonus : 0));
      if (p.inventory.spaceFor(r.output, q) < r.count) break;
      for (const inp of r.inputs) {
        p.inventory.remove(inp.item, inp.count);
        used[inp.item] = (used[inp.item] ?? 0) + inp.count;
      }
      p.inventory.add(r.output, r.count, q);
      qualities[q]++;
      made++;
    }
    if (made === 0) return this.world.sendSystem(p, 'Brak materiałów lub miejsca w plecaku.');

    // Sława dla specjalizacji i zwrot części materiałów (premia miasta).
    let fame = 0;
    const returned: string[] = [];
    for (const [item, n] of Object.entries(used)) {
      fame += fameForTier(getItem(item)!.tier ?? 1) * n;
      const back = returnedAmount(n, returnRate);
      if (back > 0) {
        this.giveOrDeposit(p, station.def.city, item, back);
        returned.push(`${back}× ${getItem(item)!.name}`);
      }
    }
    if (addFame(p.specs, r.spec, fame)) {
      const d = SPEC_DEFS.find((s) => s.id === r.spec)!;
      this.world.sendSystem(p, `Specjalizacja ${d.name} – poziom ${p.specs[r.spec].level}!`);
    }
    const qText = out.stackable
      ? ''
      : ' (' + qualities.map((c, q) => (c ? `${QUALITY_NAMES[q]}: ${c}` : '')).filter(Boolean).join(', ') + ')';
    this.world.sendSystem(p, `Wytworzono ${made * r.count}× ${out.name}${qText}.`);
    if (returned.length) this.world.sendSystem(p, `Zwrot materiałów: ${returned.join(', ')}.`);
    this.world.addFx({ x: p.x, y: p.y, k: 'craft' });
    p.send({ t: 'sfx', k: 'craft' });
  }
}
