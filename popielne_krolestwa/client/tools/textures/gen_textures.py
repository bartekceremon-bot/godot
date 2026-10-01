#!/usr/bin/env python3
"""
Generator tekstur Popielnych Królestw (proceduralnie, bez zewnętrznych zasobów).
Wszystkie tekstury są bezszwowe (kafelkują się) i mają mapę wysokości -> mapę normalnych.

Wynik (client/assets/textures/):
  terrain_albedo.png  – pas N warstw 512x512 (import jako Texture2DArray), A = wysokość
  terrain_normal.png  – pas N warstw z normalnymi (RG = XZ nachylenia)
  bark.png, leaves.png, grass.png, stone_wall.png, roof_tiles.png, wood.png, plaster.png

Użycie:  python3 tools/textures/gen_textures.py   (wymaga numpy i pillow)
"""
import os
import numpy as np
from PIL import Image

S = 512
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'textures')
rng = np.random.default_rng(1337)

# Kolejność warstw terenu – musi zgadzać się z WorldBuilder.GROUND_LAYERS.
LAYERS = ['grass', 'forest', 'dirt', 'sand', 'snow', 'rock', 'cobble', 'slab', 'mud', 'ash', 'obsidian', 'ice', 'pebbles', 'field']


# ---------------------------------------------------------------------------
# Szum bezszwowy
# ---------------------------------------------------------------------------

def value_noise(size, cells, seed):
    r = np.random.default_rng(seed)
    grid = r.random((cells, cells))
    t = np.arange(size) * cells / size
    i0 = np.floor(t).astype(int)
    f = t - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    a = grid[np.ix_(i0, i0)]
    b = grid[np.ix_(i0, i1)]
    c = grid[np.ix_(i1, i0)]
    d = grid[np.ix_(i1, i1)]
    fy = f[:, None]
    fx = f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size, base, octaves, seed, gain=0.5):
    v = np.zeros((size, size))
    amp = 1.0
    tot = 0.0
    cells = base
    for o in range(octaves):
        if cells > size:
            break
        v += value_noise(size, cells, seed + o * 17) * amp
        tot += amp
        amp *= gain
        cells *= 2
    return v / tot


def voronoi(size, n, seed, jitter=1.0):
    """Zwraca (f1, f2, id) – odległość do najbliższego i drugiego punktu (w pikselach), id komórki."""
    r = np.random.default_rng(seed)
    g = int(np.sqrt(n))
    pts = []
    for y in range(g):
        for x in range(g):
            pts.append(((x + 0.5 + (r.random() - 0.5) * jitter) / g, (y + 0.5 + (r.random() - 0.5) * jitter) / g))
    pts = np.array(pts) * size
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    f1 = np.full((size, size), 1e9, np.float32)
    f2 = np.full((size, size), 1e9, np.float32)
    ids = np.zeros((size, size), np.int64)
    for k, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dx = np.minimum(dx, size - dx)
        dy = np.abs(yy - py)
        dy = np.minimum(dy, size - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        ids = np.where(closer, k, ids)
        f1 = np.where(closer, d, f1)
    return f1, f2, ids


def blades(size, count, seed, length=(6, 16), width=1.0):
    """Mapa źdźbeł: jasne kreski w losowych kierunkach (bliskie pionu) – trawa widziana z góry."""
    r = np.random.default_rng(seed)
    img = np.zeros((size, size), np.float32)
    for _ in range(count):
        x = r.random() * size
        y = r.random() * size
        a = r.normal(0, 0.9)
        ln = r.uniform(*length)
        val = r.uniform(0.4, 1.0)
        steps = int(ln * 2)
        for s in range(steps):
            t = s / steps
            px = int(x + np.sin(a) * ln * t) % size
            py = int(y - np.cos(a) * ln * t) % size
            img[py, px] = max(img[py, px], val * (1 - t * 0.6))
            if width > 1:
                img[py, (px + 1) % size] = max(img[py, (px + 1) % size], val * 0.6 * (1 - t))
    return img


def blur(a, r=1):
    out = a.copy()
    for _ in range(r):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5
    return out


def lerp(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


def col(c):
    return np.array(c, np.float32)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack([-dx, -dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n


def shade(albedo, h, amount=0.35):
    """Delikatne „zapieczone” cieniowanie wgłębień (AO z wysokości)."""
    ao = h - blur(h, 6)
    return np.clip(albedo * (1 + ao[..., None] * amount * 4), 0, 1)


# ---------------------------------------------------------------------------
# Warstwy terenu (kolor 0..1, wysokość 0..1)
# ---------------------------------------------------------------------------

def t_grass(seed=1):
    base = fbm(S, 4, 6, seed)
    bl = blades(S, 26000, seed + 1)
    bl2 = blades(S, 9000, seed + 2, (4, 9))
    h = np.clip(base * 0.35 + blur(bl, 1) * 0.8 + bl2 * 0.3, 0, 1)
    c = lerp(col([0.16, 0.3, 0.09]), col([0.33, 0.5, 0.16]), h)
    c = lerp(c, col([0.42, 0.46, 0.2]), np.clip(fbm(S, 3, 4, seed + 5) - 0.55, 0, 1) * 2)
    return shade(c, h), h


def t_forest(seed=11):
    base = fbm(S, 6, 6, seed)
    f1, f2, ids = voronoi(S, 900, seed + 3)
    leaves = np.clip(1 - f1 / 9.0, 0, 1) * ((ids * 7919 % 13) / 13.0 > 0.35)
    moss = fbm(S, 5, 5, seed + 9)
    h = np.clip(base * 0.5 + leaves * 0.5, 0, 1)
    c = lerp(col([0.18, 0.14, 0.08]), col([0.36, 0.27, 0.14]), leaves * ((ids * 31 % 7) / 7.0))
    c = lerp(c, col([0.16, 0.3, 0.1]), np.clip(moss - 0.45, 0, 1) * 2.2)
    return shade(c, h), h


def t_dirt(seed=21):
    base = fbm(S, 5, 7, seed)
    f1, f2, ids = voronoi(S, 1600, seed + 1)
    peb = np.clip(1 - f1 / 4.5, 0, 1) * (((ids * 2654435761) % 100) / 100 > 0.7)
    h = np.clip(base * 0.7 + peb * 0.5, 0, 1)
    c = lerp(col([0.28, 0.2, 0.13]), col([0.5, 0.38, 0.25]), base)
    c = lerp(c, col([0.55, 0.52, 0.48]), peb * 0.8)
    return shade(c, h), h


def t_sand(seed=31):
    base = fbm(S, 6, 7, seed)
    yy, xx = np.mgrid[0:S, 0:S] / S
    warp = fbm(S, 3, 3, seed + 4)
    rip = (np.sin((yy * 18 + warp * 3.0) * 2 * np.pi) * 0.5 + 0.5)
    grain = np.random.default_rng(seed).random((S, S))
    h = np.clip(rip * 0.45 + base * 0.4 + grain * 0.15, 0, 1)
    c = lerp(col([0.74, 0.6, 0.4]), col([0.93, 0.82, 0.6]), h)
    return shade(c, h, 0.2), h


def t_snow(seed=41):
    base = fbm(S, 3, 6, seed)
    grain = np.random.default_rng(seed).random((S, S))
    h = np.clip(base * 0.85 + grain * 0.15, 0, 1)
    c = lerp(col([0.72, 0.78, 0.88]), col([0.97, 0.98, 1.0]), h)
    sparkle = (grain > 0.995)[..., None] * 0.2
    return np.clip(shade(c, h, 0.25) + sparkle, 0, 1), h


def t_rock(seed=51):
    base = fbm(S, 4, 8, seed)
    ridged = 1 - np.abs(fbm(S, 3, 7, seed + 4) * 2 - 1)
    f1, f2, ids = voronoi(S, 25, seed + 2, 1.0)
    cracks = np.clip((f2 - f1) / 10.0, 0, 1) ** 0.5
    strata = np.sin((np.mgrid[0:S, 0:S][0] / S * 11 + fbm(S, 3, 4, seed + 7) * 4) * 2 * np.pi) * 0.5 + 0.5
    h = np.clip(base * 0.45 + ridged * 0.35 + cracks * 0.2, 0, 1)
    c = lerp(col([0.3, 0.29, 0.27]), col([0.6, 0.58, 0.54]), np.clip(base * 0.7 + ridged * 0.4 - 0.1, 0, 1))
    c = lerp(c, col([0.5, 0.45, 0.38]), strata * 0.18)
    c = c * (0.7 + 0.3 * cracks[..., None])
    lichen = np.clip((fbm(S, 6, 5, seed + 11) - 0.62) * 5, 0, 1)
    c = lerp(c, col([0.45, 0.48, 0.3]), lichen * 0.5)
    return shade(c, h, 0.6), h


def t_cobble(seed=61):
    f1, f2, ids = voronoi(S, 144, seed, 0.75)
    edge = np.clip((f2 - f1) / 7.0, 0, 1)
    stone = np.sqrt(edge)
    tint = ((ids * 2654435761) % 1000) / 1000.0
    base = fbm(S, 8, 6, seed + 3)
    h = np.clip(stone * 0.85 + base * 0.15, 0, 1)
    c = lerp(col([0.38, 0.36, 0.33]), col([0.62, 0.6, 0.56]), tint)
    c = c * (0.85 + base[..., None] * 0.3)
    mortar = col([0.2, 0.19, 0.17])
    c = lerp(mortar, c, np.clip(edge * 3, 0, 1))
    return shade(c, h, 0.5), h


def t_slab(seed=71):
    yy, xx = np.mgrid[0:S, 0:S]
    n = 4
    gx = (xx % (S // n)) / (S / n)
    gy = (yy % (S // n)) / (S / n)
    edge = np.minimum(np.minimum(gx, 1 - gx), np.minimum(gy, 1 - gy))
    groove = np.clip(edge * 60, 0, 1)
    vein = np.abs(np.sin((fbm(S, 4, 6, seed) * 10 + xx / S * 3) * np.pi))
    vein = np.clip(1 - vein * 8, 0, 1) * 0.35
    base = fbm(S, 8, 5, seed + 1)
    h = groove * (0.8 + base * 0.2)
    c = lerp(col([0.72, 0.68, 0.6]), col([0.9, 0.87, 0.8]), base) - vein[..., None] * 0.35
    c = c * (0.55 + 0.45 * groove[..., None])
    return shade(np.clip(c, 0, 1), h, 0.3), h


def t_mud(seed=81):
    base = fbm(S, 4, 7, seed)
    wet = np.clip((fbm(S, 3, 5, seed + 2) - 0.5) * 4, 0, 1)
    h = np.clip(base * (1 - wet * 0.7), 0, 1)
    c = lerp(col([0.2, 0.17, 0.1]), col([0.36, 0.3, 0.18]), base)
    c = lerp(c, col([0.12, 0.13, 0.08]), wet)
    return shade(c, h), h


def t_ash(seed=91):
    base = fbm(S, 5, 7, seed)
    f1, f2, ids = voronoi(S, 100, seed + 1)
    cracks = np.clip(1 - (f2 - f1) / 3.0, 0, 1)
    h = np.clip(base * 0.8 - cracks * 0.3 + 0.2, 0, 1)
    c = lerp(col([0.12, 0.11, 0.11]), col([0.36, 0.33, 0.31]), base)
    c = lerp(c, col([0.05, 0.04, 0.04]), cracks * 0.8)
    return shade(c, h), h


def t_obsidian(seed=101):
    f1, f2, ids = voronoi(S, 49, seed, 1.0)
    edge = np.clip((f2 - f1) / 3.0, 0, 1)
    base = fbm(S, 6, 5, seed + 2)
    h = np.clip(edge * 0.7 + base * 0.3, 0, 1)
    c = lerp(col([0.05, 0.04, 0.07]), col([0.18, 0.14, 0.24]), base * edge)
    return c, h


def t_ice(seed=111):
    base = fbm(S, 3, 6, seed)
    f1, f2, ids = voronoi(S, 36, seed + 5)
    cracks = np.clip(1 - (f2 - f1) / 2.0, 0, 1)
    h = np.clip(base * 0.5 + 0.4 - cracks * 0.2, 0, 1)
    c = lerp(col([0.55, 0.72, 0.85]), col([0.82, 0.92, 0.98]), base)
    c = lerp(c, col([0.97, 1.0, 1.0]), cracks * 0.7)
    return c, h


def t_pebbles(seed=121):
    f1, f2, ids = voronoi(S, 900, seed, 1.0)
    edge = np.clip((f2 - f1) / 4.0, 0, 1)
    tint = ((ids * 2654435761) % 1000) / 1000.0
    h = np.sqrt(edge)
    c = lerp(col([0.32, 0.3, 0.26]), col([0.62, 0.58, 0.52]), tint)
    c = lerp(col([0.2, 0.18, 0.14]), c, np.clip(edge * 3, 0, 1))
    return shade(c, h, 0.5), h


def t_field(seed=131):
    yy, xx = np.mgrid[0:S, 0:S]
    rows = (np.sin(xx / S * 16 * 2 * np.pi) * 0.5 + 0.5)
    base = fbm(S, 6, 6, seed)
    bl = blades(S, 12000, seed + 1, (5, 12))
    h = np.clip(rows * 0.5 + bl * 0.4 + base * 0.2, 0, 1)
    c = lerp(col([0.35, 0.25, 0.14]), col([0.56, 0.52, 0.22]), np.clip(rows * 0.6 + bl * 0.6, 0, 1))
    return shade(c, h), h


GEN = {
    'grass': t_grass, 'forest': t_forest, 'dirt': t_dirt, 'sand': t_sand, 'snow': t_snow, 'rock': t_rock,
    'cobble': t_cobble, 'slab': t_slab, 'mud': t_mud, 'ash': t_ash, 'obsidian': t_obsidian, 'ice': t_ice,
    'pebbles': t_pebbles, 'field': t_field,
}
NORMAL_STRENGTH = {'grass': 2.0, 'forest': 3.0, 'dirt': 3.0, 'sand': 2.0, 'snow': 1.5, 'rock': 5.0, 'cobble': 6.0,
                   'slab': 5.0, 'mud': 2.0, 'ash': 3.0, 'obsidian': 4.0, 'ice': 2.0, 'pebbles': 6.0, 'field': 3.0}


# ---------------------------------------------------------------------------
# Tekstury obiektów
# ---------------------------------------------------------------------------

def bark(seed=201):
    W = 256
    yy, xx = np.mgrid[0:W, 0:W] / W
    warp = fbm(W, 4, 5, seed)
    ridges = np.abs(np.sin((xx * 9 + warp * 1.5) * 2 * np.pi))
    base = fbm(W, 8, 6, seed + 1)
    h = np.clip(ridges * 0.7 + base * 0.3, 0, 1)
    c = lerp(col([0.16, 0.11, 0.07]), col([0.42, 0.32, 0.22]), h)
    return shade(c, h, 0.5), h


def leaves(seed=301):
    """Karta liści: gęsta kępa liści z przezroczystością (RGBA)."""
    W = 512
    r = np.random.default_rng(seed)
    img = np.zeros((W, W, 4), np.float32)
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
    cx, cy = W / 2, W / 2
    for _ in range(2600):
        a = r.random() * 2 * np.pi
        d = np.sqrt(r.random()) ** 0.8 * W * 0.46
        px, py = cx + np.cos(a) * d, cy + np.sin(a) * d
        ang = r.random() * np.pi
        ln = r.uniform(18, 32)
        wd = ln * r.uniform(0.35, 0.5)
        x0, x1 = int(max(px - ln, 0)), int(min(px + ln, W))
        y0, y1 = int(max(py - ln, 0)), int(min(py + ln, W))
        if x1 <= x0 or y1 <= y0:
            continue
        lx = xx[y0:y1, x0:x1] - px
        ly = yy[y0:y1, x0:x1] - py
        u = lx * np.cos(ang) + ly * np.sin(ang)
        v = -lx * np.sin(ang) + ly * np.cos(ang)
        inside = (u / ln) ** 2 + (v / wd) ** 2 < 0.25
        shade_v = 0.45 + 0.55 * (1 - d / (W * 0.46)) + r.uniform(-0.18, 0.18)
        vein = np.abs(v) < 1.0
        g = np.array([0.3, 0.52, 0.17]) * shade_v
        light = 1 + 0.25 * (u / ln)
        patch = img[y0:y1, x0:x1]
        for ch in range(3):
            val = np.where(vein, g[ch] * 1.25, g[ch]) * light
            patch[..., ch] = np.where(inside, val, patch[..., ch])
        patch[..., 3] = np.where(inside, 1.0, patch[..., 3])
    img[..., :3] = np.clip(img[..., :3], 0, 1)
    return img


def pine_branch(seed=351):
    """Gałąź świerka widziana z góry: oś od dołu karty do góry, igły na boki (RGBA)."""
    W, H = 256, 512
    r = np.random.default_rng(seed)
    img = np.zeros((H, W, 4), np.float32)

    def stroke(x0, y0, x1, y1, w, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n):
            t = i / n
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            xa, xb = int(max(x - w, 0)), int(min(x + w + 1, W))
            ya, yb = int(max(y - w, 0)), int(min(y + w + 1, H))
            if xb > xa and yb > ya:
                img[ya:yb, xa:xb, :3] = c
                img[ya:yb, xa:xb, 3] = 1.0

    cx = W / 2
    # Boczne gałązki z igłami.
    for k in range(26):
        y = H - 20 - k * (H - 40) / 26
        for side in (-1, 1):
            ln = (W * 0.46) * (0.35 + 0.65 * (y / H)) * r.uniform(0.8, 1.05)
            ex = cx + side * ln
            ey = y - ln * 0.35
            for j in range(34):
                t = j / 34
                px = cx + (ex - cx) * t
                py = y + (ey - y) * t
                for s2 in (-1, 1):
                    nl = r.uniform(14, 26) * (1 - t * 0.45)
                    g = np.array([0.1, 0.27, 0.14]) * r.uniform(0.7, 1.35)
                    stroke(px, py, px + s2 * nl * 0.45, py - nl * 0.9, 1.1, g)
            stroke(cx, y, ex, ey, 1.2, np.array([0.25, 0.17, 0.1]))
    stroke(cx, H - 1, cx, 10, 2.5, np.array([0.3, 0.2, 0.12]))
    return img


def palm_frond(seed=361):
    """Liść palmy: środkowy nerw i listki na boki (RGBA), oś wzdłuż karty."""
    W, H = 256, 512
    r = np.random.default_rng(seed)
    img = np.zeros((H, W, 4), np.float32)
    cx = W / 2
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    for k in range(40):
        y = H - 10 - k * (H - 20) / 40
        t = k / 40
        ln = W * 0.48 * np.sin((t * 0.9 + 0.08) * np.pi) * r.uniform(0.85, 1.0)
        for side in (-1, 1):
            # Listek jako wąska elipsa od osi na zewnątrz, lekko w górę karty.
            ang = side * 1.25
            mx = cx + side * ln * 0.5
            my = y - ln * 0.25
            u = (xx - mx) * np.cos(ang) + (yy - my) * np.sin(ang)
            v = -(xx - mx) * np.sin(ang) + (yy - my) * np.cos(ang)
            inside = (u / (ln * 0.55 + 1)) ** 2 + (v / 5.0) ** 2 < 1.0
            g = np.array([0.24, 0.42, 0.14]) * r.uniform(0.8, 1.2)
            for ch in range(3):
                img[..., ch] = np.where(inside, g[ch] * (0.7 + 0.3 * np.clip(1 - np.abs(v) / 5, 0, 1)), img[..., ch])
            img[..., 3] = np.where(inside, 1.0, img[..., 3])
    rib = np.abs(xx - cx) < 3
    img[..., 0] = np.where(rib, 0.4, img[..., 0])
    img[..., 1] = np.where(rib, 0.45, img[..., 1])
    img[..., 2] = np.where(rib, 0.2, img[..., 2])
    img[..., 3] = np.where(rib, 1.0, img[..., 3])
    return img


def grass_card(seed=401):
    """Kępa trawy do instancji MultiMesh: źdźbła od dołu karty, przezroczyste tło (RGBA)."""
    W, H = 256, 256
    r = np.random.default_rng(seed)
    img = np.zeros((H, W, 4), np.float32)
    for _ in range(70):
        x = r.uniform(20, W - 20)
        hgt = r.uniform(0.45, 0.95) * H
        bend = r.normal(0, 25)
        wid = r.uniform(3, 6)
        g = np.array([0.2, 0.42, 0.12]) * r.uniform(0.8, 1.25)
        steps = int(hgt)
        for s in range(steps):
            t = s / steps
            px = x + bend * t * t
            py = H - 1 - s
            w = wid * (1 - t) + 0.5
            x0, x1 = int(max(px - w, 0)), int(min(px + w + 1, W))
            if x1 <= x0 or py < 0:
                continue
            shade_v = 0.5 + 0.7 * t
            img[py, x0:x1, :3] = np.clip(g * shade_v, 0, 1)
            img[py, x0:x1, 3] = 1.0
    return img


def stone_wall(seed=501):
    W = 512
    yy, xx = np.mgrid[0:W, 0:W]
    rows = 8
    rh = W // rows
    row = yy // rh
    off = (row % 2) * (rh)
    bw = rh * 2
    bx = ((xx + off) % bw) / bw
    by = (yy % rh) / rh
    edge = np.minimum(np.minimum(bx, 1 - bx) * 2, np.minimum(by, 1 - by))
    groove = np.clip(edge * 14, 0, 1)
    idn = (((xx + off) // bw) * 7 + row * 13) % 17 / 17.0
    base = fbm(W, 8, 6, seed)
    h = groove * (0.7 + base * 0.3)
    c = lerp(col([0.42, 0.4, 0.37]), col([0.66, 0.63, 0.58]), idn * 0.6 + base * 0.4)
    c = lerp(col([0.25, 0.24, 0.22]), c, groove)
    return shade(c, h, 0.45), h


def roof_tiles(seed=601):
    W = 512
    yy, xx = np.mgrid[0:W, 0:W]
    rows = 16
    rh = W // rows
    row = yy // rh
    tw = rh * 1.2
    off = (row % 2) * tw / 2
    bx = ((xx + off) % tw) / tw
    by = (yy % rh) / rh
    curve = np.sin(bx * np.pi)
    h = np.clip(curve * 0.7 + (1 - by) * 0.3, 0, 1)
    base = fbm(W, 8, 5, seed)
    shadow = np.clip(by * 4, 0, 1)
    c = lerp(col([0.45, 0.14, 0.08]), col([0.72, 0.3, 0.18]), curve * 0.7 + base * 0.3)
    c = c * (0.5 + 0.5 * shadow[..., None])
    return c, h


def wood(seed=701):
    W = 256
    yy, xx = np.mgrid[0:W, 0:W] / W
    planks = 4
    px = (xx * planks) % 1.0
    gap = np.clip(np.minimum(px, 1 - px) * 60, 0, 1)
    warp = fbm(W, 4, 5, seed)
    grain = np.sin((yy * 30 + warp * 4 + np.floor(xx * planks) * 3) * 2 * np.pi) * 0.5 + 0.5
    h = gap * (0.6 + grain * 0.4)
    c = lerp(col([0.28, 0.18, 0.1]), col([0.52, 0.36, 0.22]), grain * 0.6 + warp * 0.4)
    c = c * (0.4 + 0.6 * gap[..., None])
    return c, h


def plaster(seed=801):
    W = 256
    base = fbm(W, 6, 7, seed)
    h = base
    c = lerp(col([0.78, 0.74, 0.66]), col([0.94, 0.91, 0.84]), base)
    return shade(c, h, 0.3), h


# ---------------------------------------------------------------------------

def save_rgb(path, rgb, alpha=None):
    a = (np.clip(rgb, 0, 1) * 255).astype(np.uint8)
    if alpha is not None:
        al = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
        Image.fromarray(np.dstack([a, al]), 'RGBA').save(path, optimize=True)
    else:
        Image.fromarray(a, 'RGB').save(path, optimize=True)


def save_normal(path, h, strength):
    n = normal_from_height(h, strength)
    save_rgb(path, n * 0.5 + 0.5)


def main():
    os.makedirs(OUT, exist_ok=True)
    albedo = []
    normals = []
    means = []
    for name in LAYERS:
        c, h = GEN[name]()
        albedo.append(np.dstack([np.clip(c, 0, 1), h]))
        normals.append(normal_from_height(h, NORMAL_STRENGTH[name]) * 0.5 + 0.5)
        means.append(np.clip(c, 0, 1).reshape(-1, 3).mean(0))
        print('warstwa', name)
    strip = np.concatenate(albedo, axis=1)
    # 384 px na warstwę – mniejszy APK (limit wysyłki), różnica z bliska ledwo widoczna.
    aimg = Image.fromarray((strip * 255).astype(np.uint8), 'RGBA')
    aimg = aimg.resize((aimg.width * 3 // 4, aimg.height * 3 // 4), Image.LANCZOS)
    aimg.save(os.path.join(OUT, 'terrain_albedo.png'), optimize=True)
    nstrip = np.concatenate(normals, axis=1)
    nimg = Image.fromarray((nstrip * 255).astype(np.uint8), 'RGB')
    nimg = nimg.resize((nimg.width // 2, nimg.height // 2), Image.LANCZOS)
    nimg.save(os.path.join(OUT, 'terrain_normal.png'), optimize=True)
    # Średnie kolory warstw (do barwienia kolorem krainy w shaderze).
    with open(os.path.join(OUT, 'terrain_means.txt'), 'w') as f:
        for name, m in zip(LAYERS, means):
            f.write('%s %.4f %.4f %.4f\n' % (name, m[0], m[1], m[2]))
    for name, fn, strength in [('bark', bark, 4.0), ('stone_wall', stone_wall, 5.0), ('roof_tiles', roof_tiles, 4.0),
                               ('wood', wood, 3.0), ('plaster', plaster, 2.0)]:
        c, h = fn()
        save_rgb(os.path.join(OUT, name + '.png'), c)
        save_normal(os.path.join(OUT, name + '_n.png'), h, strength)
        print('obiekt', name)
    lv = leaves()
    save_rgb(os.path.join(OUT, 'leaves.png'), lv[..., :3], lv[..., 3])
    pb = pine_branch()
    save_rgb(os.path.join(OUT, 'pine_branch.png'), pb[..., :3], pb[..., 3])
    pf = palm_frond()
    save_rgb(os.path.join(OUT, 'palm_frond.png'), pf[..., :3], pf[..., 3])
    gc = grass_card()
    save_rgb(os.path.join(OUT, 'grass.png'), gc[..., :3], gc[..., 3])
    print('gotowe ->', os.path.abspath(OUT))


if __name__ == '__main__':
    main()
