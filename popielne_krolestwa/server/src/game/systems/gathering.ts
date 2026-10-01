/**
 * Zbieractwo: gracz stoi obok złoża i co kilka sekund dostaje jednostkę surowca,
 * dopóki złoże się nie wyczerpie, nie zabraknie udźwigu albo gracz się nie ruszy.
 *
 * Wymagania: narzędzie odpowiedniego rodzaju o tierze >= tier złoża (w plecaku)
 * oraz poziom specjalizacji zbierackiej >= wymaganie tieru.
 */
import type { World } from '../world';
import { Player, ResourceNode } from '../entities';
import { rawId, TOOL_FOR_RESOURCE, getItem } from '../data/items';
import { nodeRespawnMs } from '../data/resources';
import { GATHER_SPEC, TIER_SPEC_REQ, addFame, bonusYieldChance, canUseTier, fameForTier, gatherTimeMs, SPEC_DEFS } from '../specs';
import { chebyshev } from '../combat';
import { chance } from '../../util/rng';

const TOOL_NAMES = { woodaxe: 'siekiery drwala', pickaxe: 'kilofa', sickle: 'sierpa' };

export class GatheringSystem {
  constructor(private world: World) {}

  /** Próba rozpoczęcia zbierania. */
  start(p: Player, nodeId: number, now: number) {
    const node = this.world.nodes.get(nodeId);
    if (!node || node.respawnAt) return;
    if (chebyshev(p.x, p.y, node.x, node.y) > 1) return this.world.sendSystem(p, 'Podejdź bliżej złoża.');
    const err = this.check(p, node);
    if (err) return this.world.sendSystem(p, err);
    p.targetId = 0;
    const spec = GATHER_SPEC[node.kind];
    p.gathering = { nodeId, nextAt: now + gatherTimeMs(p.specs[spec].level, node.tier) };
  }

  stop(p: Player) {
    p.gathering = null;
  }

  private check(p: Player, node: ResourceNode): string | null {
    const tool = TOOL_FOR_RESOURCE[node.kind]!;
    const toolTier = p.inventory.bestTool(tool);
    if (toolTier === 0) return `Potrzebujesz ${TOOL_NAMES[tool]}.`;
    if (toolTier < node.tier) return `Potrzebujesz ${TOOL_NAMES[tool]} T${node.tier} lub lepszego.`;
    const spec = GATHER_SPEC[node.kind];
    if (!canUseTier(p.specs, spec, node.tier)) {
      const name = SPEC_DEFS.find((d) => d.id === spec)!.name;
      return `Wymagany poziom specjalizacji ${name}: ${TIER_SPEC_REQ[node.tier]}.`;
    }
    if (p.canCarry(rawId(node.kind, node.tier)) < 1) return 'Nie uniesiesz więcej (udźwig lub plecak pełny).';
    return null;
  }

  /** Wywoływane co tick dla gracza, który zbiera. */
  tick(p: Player, now: number) {
    const g = p.gathering;
    if (!g || now < g.nextAt) return;
    const node = this.world.nodes.get(g.nodeId);
    if (!node || node.respawnAt || chebyshev(p.x, p.y, node.x, node.y) > 1) return this.stop(p);
    const err = this.check(p, node);
    if (err) {
      this.world.sendSystem(p, err);
      return this.stop(p);
    }
    const spec = GATHER_SPEC[node.kind];
    const level = p.specs[spec].level;
    const item = rawId(node.kind, node.tier);
    let amount = 1 + (chance(bonusYieldChance(level)) ? 1 : 0);
    amount = Math.min(amount, p.canCarry(item));
    p.inventory.add(item, amount);
    this.world.addFx({ x: node.x, y: node.y, k: 'gather', v: amount, item });
    if (addFame(p.specs, spec, fameForTier(node.tier) * amount)) this.announce(p, spec);

    node.charges--;
    if (node.charges <= 0) {
      node.respawnAt = now + nodeRespawnMs(node.tier);
      this.world.sendSystem(p, `${node.name} – złoże wyczerpane.`);
      return this.stop(p);
    }
    g.nextAt = now + gatherTimeMs(p.specs[spec].level, node.tier);
    if (amount > 1) this.world.sendSystem(p, `Premia specjalizacji: +1 ${getItem(item)!.name}.`);
  }

  /** Odnawianie wyczerpanych złóż. */
  tickNodes(now: number) {
    for (const n of this.world.nodes.values())
      if (n.respawnAt && now >= n.respawnAt) {
        n.respawnAt = 0;
        n.charges = n.maxCharges();
      }
  }

  announce(p: Player, spec: keyof typeof GATHER_SPEC | string) {
    const d = SPEC_DEFS.find((s) => s.id === spec);
    if (d) this.world.sendSystem(p, `Specjalizacja ${d.name} – poziom ${p.specs[d.id].level}!`);
  }
}
