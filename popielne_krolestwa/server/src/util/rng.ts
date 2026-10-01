/**
 * Proste narzędzia losowe. `SeededRng` jest deterministyczny (mulberry32) –
 * używany do generowania mapy, żeby każdy start serwera dawał ten sam świat.
 */
export class SeededRng {
  private state: number;

  constructor(seed: number) {
    this.state = seed >>> 0;
  }

  /** Liczba z przedziału [0, 1). */
  next(): number {
    let t = (this.state += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  /** Liczba całkowita z przedziału [min, max] (włącznie). */
  int(min: number, max: number): number {
    return min + Math.floor(this.next() * (max - min + 1));
  }
}

/** Losowa liczba całkowita [min, max] (niedeterministyczna – do walki i lootu). */
export function randInt(min: number, max: number): number {
  return min + Math.floor(Math.random() * (max - min + 1));
}

/** Zwraca true z prawdopodobieństwem `p` (0..1). */
export function chance(p: number): boolean {
  return Math.random() < p;
}

export function clamp(v: number, min: number, max: number): number {
  return v < min ? min : v > max ? max : v;
}
