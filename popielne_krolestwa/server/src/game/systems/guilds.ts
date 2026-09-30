/**
 * Gildie (jak w Albionie): założenie za złoto, zaproszenia, czat gildii, skrót [TAG] nad głową,
 * członkowie nie mogą się atakować. Gildie przejmują terytoria na Popielisku (territories.ts).
 *
 * Komendy czatu:
 *   /gildia                       – informacje (członkowie, terytoria)
 *   /gildia załóż Nazwa TAG       – założenie (5000 złota, w mieście)
 *   /gildia zaproś Imię           – zaproszenie (tylko przywódca)
 *   /gildia dołącz                – przyjęcie zaproszenia
 *   /gildia wyrzuć Imię           – usunięcie członka (przywódca)
 *   /gildia opuść                 – odejście (przywódca rozwiązuje gildię, gdy jest sam)
 *   /g tekst                      – czat gildii
 */
import type { World } from '../world';
import type { Player } from '../entities';

export const GUILD_PRICE = 5000;

export interface GuildMember {
  charId: number;
  name: string;
  rank: 'leader' | 'member';
}

export interface Guild {
  id: number;
  name: string;
  tag: string;
  members: GuildMember[];
  createdAt: number;
}

const STATE_KEY = 'guilds';

export class GuildSystem {
  private guilds = new Map<number, Guild>();
  private nextId = 1;

  constructor(private world: World) {
    try {
      const raw = world.db.loadWorldState(STATE_KEY);
      if (raw) {
        const data = JSON.parse(raw) as { nextId: number; guilds: Guild[] };
        this.nextId = data.nextId;
        for (const g of data.guilds) this.guilds.set(g.id, g);
      }
    } catch {
      /* uszkodzony zapis – zaczynamy od zera */
    }
  }

  private save() {
    this.world.db.saveWorldState(STATE_KEY, JSON.stringify({ nextId: this.nextId, guilds: [...this.guilds.values()] }));
  }

  get(id: number): Guild | undefined {
    return this.guilds.get(id);
  }

  list(): Guild[] {
    return [...this.guilds.values()];
  }

  /** Przy wejściu do gry: przypisanie gildii graczowi. */
  attach(p: Player) {
    for (const g of this.guilds.values()) {
      const m = g.members.find((x) => x.charId === p.charId);
      if (m) {
        p.guildId = g.id;
        p.guildTag = g.tag;
        p.guildRank = m.rank;
        return;
      }
    }
    p.guildId = 0;
    p.guildTag = '';
    p.guildRank = '';
  }

  sameGuild(a: Player, b: Player): boolean {
    return a.guildId !== 0 && a.guildId === b.guildId;
  }

  /** Obsługa komend czatu. Zwraca true, gdy tekst był komendą gildii. */
  command(p: Player, text: string): boolean {
    const [cmd, ...args] = text.slice(1).trim().split(/\s+/);
    const c = cmd.toLowerCase();
    if (c === 'g') {
      this.chat(p, args.join(' '));
      return true;
    }
    if (c !== 'gildia' && c !== 'guild') return false;
    const sub = (args[0] ?? '').toLowerCase();
    switch (sub) {
      case 'załóż':
      case 'zaloz':
        // Nazwa może mieć kilka słów – skrót to ostatnie słowo.
        this.create(p, args.slice(1, -1).join(' '), args.length > 2 ? args[args.length - 1] : '');
        break;
      case 'zaproś':
      case 'zapros':
        this.invite(p, args.slice(1).join(' '));
        break;
      case 'dołącz':
      case 'dolacz':
        this.join(p);
        break;
      case 'wyrzuć':
      case 'wyrzuc':
        this.kick(p, args.slice(1).join(' '));
        break;
      case 'opuść':
      case 'opusc':
        this.leave(p);
        break;
      default:
        this.info(p);
    }
    return true;
  }

  info(p: Player) {
    const g = this.guilds.get(p.guildId);
    if (!g) {
      this.world.sendSystem(
        p,
        `Nie należysz do gildii. Załóż własną: /gildia załóż Nazwa TAG (${GUILD_PRICE} zł, w mieście) albo poproś przywódcę o zaproszenie.`,
      );
      return;
    }
    const online = new Set([...this.world.players.values()].map((o) => o.charId));
    const members = g.members.map((m) => `${m.name}${m.rank === 'leader' ? ' (przywódca)' : ''}${online.has(m.charId) ? ' •' : ''}`);
    const terr = this.world.territories.ownedBy(g.id);
    this.world.sendSystem(p, `Gildia ${g.name} [${g.tag}] – członkowie (${g.members.length}): ${members.join(', ')}.`);
    this.world.sendSystem(p, terr.length ? `Terytoria: ${terr.join(', ')}.` : 'Gildia nie ma jeszcze terytoriów na Popielisku.');
    p.send({ t: 'guild', name: g.name, tag: g.tag, members: g.members.map((m) => ({ n: m.name, r: m.rank, on: online.has(m.charId) })), territories: terr });
  }

  private create(p: Player, name: string, tag: string) {
    if (p.guildId) return this.world.sendSystem(p, 'Należysz już do gildii.');
    if (!this.world.map.isProtectionZone(p.x, p.y)) return this.world.sendSystem(p, 'Gildię zakłada się w mieście (u Mistrza gildii).');
    if (!/^[\p{L}][\p{L}\d ]{2,19}$/u.test(name)) return this.world.sendSystem(p, 'Nazwa gildii: 3–20 liter (np. /gildia załóż Strażnicy STR).');
    tag = tag.toUpperCase();
    if (!/^[\p{Lu}\d]{2,4}$/u.test(tag)) return this.world.sendSystem(p, 'Skrót gildii: 2–4 wielkie litery lub cyfry.');
    for (const g of this.guilds.values())
      if (g.name.toLowerCase() === name.toLowerCase() || g.tag === tag) return this.world.sendSystem(p, 'Taka gildia (nazwa lub skrót) już istnieje.');
    if (p.inventory.countOf('gold') < GUILD_PRICE) return this.world.sendSystem(p, `Założenie gildii kosztuje ${GUILD_PRICE} zł.`);
    p.inventory.remove('gold', GUILD_PRICE);
    const g: Guild = { id: this.nextId++, name, tag, members: [{ charId: p.charId, name: p.name, rank: 'leader' }], createdAt: Date.now() };
    this.guilds.set(g.id, g);
    this.save();
    this.attach(p);
    this.world.broadcastSystem(`Powstała nowa gildia: ${name} [${tag}] – przywódca ${p.name}.`);
    this.world.addFx({ x: p.x, y: p.y, k: 'levelup' });
  }

  private invite(p: Player, name: string) {
    const g = this.guilds.get(p.guildId);
    if (!g || p.guildRank !== 'leader') return this.world.sendSystem(p, 'Tylko przywódca gildii może zapraszać.');
    const o = [...this.world.players.values()].find((x) => x.name.toLowerCase() === name.toLowerCase());
    if (!o) return this.world.sendSystem(p, `Gracz ${name} nie jest w grze.`);
    if (o.guildId) return this.world.sendSystem(p, `${o.name} należy już do gildii.`);
    o.guildInvite = g.id;
    this.world.sendSystem(o, `${p.name} zaprasza cię do gildii ${g.name} [${g.tag}]. Wpisz /gildia dołącz.`);
    this.world.sendSystem(p, `Zaproszenie wysłane do: ${o.name}.`);
  }

  private join(p: Player) {
    const g = this.guilds.get(p.guildInvite);
    if (!g) return this.world.sendSystem(p, 'Nie masz zaproszenia do gildii.');
    if (p.guildId) return this.world.sendSystem(p, 'Należysz już do gildii.');
    g.members.push({ charId: p.charId, name: p.name, rank: 'member' });
    p.guildInvite = 0;
    this.save();
    this.attach(p);
    this.guildSystem(g, `${p.name} dołącza do gildii!`);
  }

  private kick(p: Player, name: string) {
    const g = this.guilds.get(p.guildId);
    if (!g || p.guildRank !== 'leader') return this.world.sendSystem(p, 'Tylko przywódca może usuwać członków.');
    const m = g.members.find((x) => x.name.toLowerCase() === name.toLowerCase() && x.rank !== 'leader');
    if (!m) return this.world.sendSystem(p, `W gildii nie ma gracza ${name}.`);
    g.members = g.members.filter((x) => x !== m);
    this.save();
    this.guildSystem(g, `${m.name} został usunięty z gildii.`);
    const o = this.world.findPlayerByCharId(m.charId);
    if (o) {
      this.attach(o);
      this.world.sendSystem(o, `Zostałeś usunięty z gildii ${g.name}.`);
    }
  }

  private leave(p: Player) {
    const g = this.guilds.get(p.guildId);
    if (!g) return this.world.sendSystem(p, 'Nie należysz do gildii.');
    if (p.guildRank === 'leader' && g.members.length > 1)
      return this.world.sendSystem(p, 'Przywódca nie może odejść, dopóki w gildii są inni członkowie (użyj /gildia wyrzuć).');
    g.members = g.members.filter((x) => x.charId !== p.charId);
    if (!g.members.length) {
      this.guilds.delete(g.id);
      this.world.territories.releaseGuild(g.id);
      this.world.broadcastSystem(`Gildia ${g.name} [${g.tag}] została rozwiązana.`);
    } else this.guildSystem(g, `${p.name} opuszcza gildię.`);
    this.save();
    this.attach(p);
    this.world.sendSystem(p, `Opuszczasz gildię ${g.name}.`);
  }

  private chat(p: Player, text: string) {
    const g = this.guilds.get(p.guildId);
    if (!g) return this.world.sendSystem(p, 'Nie należysz do gildii.');
    const clean = text.replace(/[\u0000-\u001f]/g, '').trim().slice(0, 200);
    if (!clean) return;
    for (const o of this.world.players.values())
      if (o.guildId === g.id) o.send({ t: 'chat', from: `[${g.tag}] ${p.name}`, id: p.id, text: clean, x: p.x, y: p.y, ch: 'guild' });
  }

  /** Komunikat do wszystkich członków gildii online. */
  guildSystem(g: Guild, text: string) {
    for (const o of this.world.players.values()) if (o.guildId === g.id) this.world.sendSystem(o, `[${g.tag}] ${text}`);
  }
}
