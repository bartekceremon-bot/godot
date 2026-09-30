/**
 * Pomocnicze wyszukiwanie miejsc na wygenerowanej mapie (testy nie zależą od współrzędnych).
 */
import type { World } from '../src/game/world';
import type { Zone } from '../src/game/map';

/** Pole w danej strefie z wolnym otoczeniem 3×3 (poza strefą ochronną, bez potworów w pobliżu). */
export function zoneSpot(world: World, zone: Zone): { x: number; y: number } {
  const map = world.map;
  const t = map.temple;
  for (let r = 2; r < 200; r++)
    for (let dy = -r; dy <= r; dy++)
      for (let dx = -r; dx <= r; dx++) {
        if (Math.max(Math.abs(dx), Math.abs(dy)) !== r) continue;
        const x = t.x + dx;
        const y = t.y + dy;
        if (map.zoneAt(x, y) !== zone) continue;
        let ok = true;
        for (let yy = y - 1; yy <= y + 2 && ok; yy++)
          for (let xx = x - 1; xx <= x + 2 && ok; xx++)
            if (!map.isWalkable(xx, yy) || map.isProtectionZone(xx, yy) || map.zoneAt(xx, yy) !== zone) ok = false;
        if (!ok) continue;
        for (const m of world.monsters.values()) if (Math.abs(m.x - x) <= 10 && Math.abs(m.y - y) <= 10) ok = false;
        if (ok) return { x, y };
      }
  throw new Error(`Brak miejsca w strefie ${zone}`);
}
