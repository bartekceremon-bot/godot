#!/usr/bin/env python3
"""
Oprawa „Popiół i żar” (ekran walki idle): kamień, kute żelazo, żarzące się krawędzie.
Grafiki 9-patch -> client/assets/ui/ash/:
  stone_panel.png   – ciemna płyta kamienna (górny pasek, panele)       margines 26
  stone_button.png  – jasna płyta z fazą i pomarańczową poświatą (ATAK!) margines 44
  slot.png          – ciemny kafel z wewnętrznym cieniem (ikony, czary)  margines 18
  bar_frame.png     – żelazna rama paska z grotami i żarem na końcach    margines 46 poziomo, 20 pionowo
  badge.png         – sześciokątna plakietka (LVL, XP)                   margines 22
  tile_on.png       – płyta aktywnej zakładki (żarząca się krawędź)      margines 26
  sheet.png         – panel wysuwany zakładek (kamień z żarzącą krawędzią u góry) margines 30

Użycie: python3 tools/textures/gen_ui_ash.py  (numpy, pillow)
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'ui', 'ash')
SS = 3  # nadpróbkowanie (gładkie krawędzie)


def fbm(w, h, seed, octaves=5, base=8):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = base * 2 ** o
        g = rng.random((n + 1, n + 1)).astype(np.float32)
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += np.asarray(img, np.float32) / 255.0 * amp
        tot += amp
        amp *= 0.55
    return out / tot


def rrect(w, h, inset, r):
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([inset, inset, w - 1 - inset, h - 1 - inset], r, fill=255)
    return np.asarray(m, np.float32) / 255.0


def poly(w, h, pts):
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return np.asarray(m, np.float32) / 255.0


def blur(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0


def bevel(mask, r, strength):
    """Oświetlenie fazy z góry-lewej: + na jasnej krawędzi, - na ciemnej."""
    b = blur(mask, r)
    gy, gx = np.gradient(b)
    return np.clip((-gx * 0.7 - gy * 1.0) * strength, -1, 1)


def cracks(w, h, seed, n, width):
    rng = np.random.default_rng(seed)
    m = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(m)
    for _ in range(n):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        pts = [(x, y)]
        for _ in range(rng.integers(3, 7)):
            x += rng.uniform(-w * 0.08, w * 0.08)
            y += rng.uniform(-h * 0.15, h * 0.15)
            pts.append((x, y))
        d.line(pts, fill=255, width=width)
    return np.asarray(m, np.float32) / 255.0


def compose(w, h, layers):
    """layers: [(maska, kolor RGB (tablica HxWx3 albo krotka), krycie)] – od spodu."""
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    for mask, col, op in layers:
        m = np.clip(mask * op, 0, 1)
        c = np.broadcast_to(np.array(col, np.float32), (h, w, 3)) if not isinstance(col, np.ndarray) else col
        rgb = rgb * (1 - m[..., None]) + c * m[..., None]
        a = a + m * (1 - a)
    rgb = np.where(a[..., None] > 0, rgb, 0)
    return rgb, a


def save(name, rgb, a, size):
    img = Image.fromarray((np.clip(np.dstack([rgb, a]), 0, 1) * 255).astype(np.uint8), 'RGBA')
    img = img.resize(size, Image.LANCZOS)
    img.save(os.path.join(OUT, name), optimize=True)
    print(name, size)


def stone_texture(w, h, seed, base, var=0.18):
    n = fbm(w, h, seed)
    n2 = fbm(w, h, seed + 1, 3, 24)
    v = base * (1 - var + var * 2 * n) * (0.92 + 0.16 * n2)
    return np.dstack([v * 1.0, v * 0.98, v * 1.02])


def stone_panel(name='stone_panel.png', ember=False):
    W, H = 128 * SS, 128 * SS
    body = rrect(W, H, 4 * SS, 10 * SS)
    tex = stone_texture(W, H, 3, 0.2)
    bv = bevel(body, 5 * SS, 60)
    tex = tex * (1 + bv[..., None] * 0.35)
    inner = rrect(W, H, 12 * SS, 6 * SS) - rrect(W, H, 13 * SS, 5 * SS)
    shadow = blur(rrect(W, H, 0, 12 * SS), 4 * SS)
    rgb, a = compose(W, H, [(shadow, (0, 0, 0), 0.7), (body, tex, 1.0), (np.clip(inner, 0, 1), (0.45, 0.42, 0.4), 0.35),
                            (body - rrect(W, H, 6 * SS, 9 * SS), (0.06, 0.055, 0.06), 0.85)]
                    + ([(np.clip(body - rrect(W, H, 7 * SS, 8 * SS), 0, 1), (1.0, 0.55, 0.18), 1.0),
                        (np.clip(blur(body - rrect(W, H, 8 * SS, 8 * SS), 5 * SS) * 1.6 * body, 0, 1), (1.0, 0.45, 0.1), 0.45)] if ember else []))
    save(name, rgb, a, (128, 128))


def stone_button():
    W, H = 256 * SS, 128 * SS
    g = 18 * SS
    glow = blur(rrect(W, H, g - 6 * SS, 14 * SS), 9 * SS) * 1.4
    body = rrect(W, H, g, 12 * SS)
    tex = stone_texture(W, H, 11, 0.36, 0.22)
    bv = bevel(body, 6 * SS, 70)
    ck = cracks(W, H, 5, 9, 2 * SS) * body
    tex = tex * (1 + bv[..., None] * 0.45) * (1 - ck[..., None] * 0.2)
    face = rrect(W, H, g + 14 * SS, 8 * SS)
    face_tex = stone_texture(W, H, 12, 0.3, 0.12) * (1 - ck[..., None] * 0.18)
    rim = body - rrect(W, H, g + 3 * SS, 10 * SS)
    rgb, a = compose(W, H, [(np.clip(glow, 0, 1), (1.0, 0.42, 0.08), 0.95), (body, tex, 1.0), (face, face_tex, 0.85),
                            (np.clip(rim, 0, 1), (1.0, 0.55, 0.2), 0.75),
                            (np.clip(face - rrect(W, H, g + 16 * SS, 7 * SS), 0, 1), (0.08, 0.07, 0.07), 0.8)])
    save('stone_button.png', rgb, a, (256, 128))


def slot():
    W, H = 96 * SS, 96 * SS
    body = rrect(W, H, 3 * SS, 6 * SS)
    tex = stone_texture(W, H, 21, 0.14, 0.12)
    inner_shadow = 1 - blur(rrect(W, H, 12 * SS, 6 * SS), 6 * SS)
    tex = tex * (1 - inner_shadow[..., None] * 0.6 * body[..., None])
    border = body - rrect(W, H, 6 * SS, 5 * SS)
    hi = np.clip(bevel(body, 3 * SS, 50), 0, 1)
    rgb, a = compose(W, H, [(body, tex, 1.0), (np.clip(border, 0, 1), (0.32, 0.3, 0.3), 0.9), (hi * border, (0.6, 0.57, 0.55), 0.6),
                            (np.clip(rrect(W, H, 6 * SS, 5 * SS) - rrect(W, H, 7 * SS, 4 * SS), 0, 1), (0.02, 0.02, 0.02), 0.9)])
    save('slot.png', rgb, a, (96, 96))


def bar_frame():
    W, H = 256 * SS, 64 * SS
    m = 10 * SS
    pts = [(0, H / 2), (m * 2.5, m), (W - m * 2.5, m), (W, H / 2), (W - m * 2.5, H - m), (m * 2.5, H - m)]
    outer = poly(W, H, pts)
    inner_pts = [(m * 3.2, m + 5 * SS), (W - m * 3.2, m + 5 * SS), (W - m * 3.2, H - m - 5 * SS), (m * 3.2, H - m - 5 * SS)]
    inner = poly(W, H, inner_pts)
    tex = stone_texture(W, H, 31, 0.3, 0.15) * np.array([0.9, 0.92, 1.0])
    bv = bevel(outer, 3 * SS, 60)
    tex = tex * (1 + bv[..., None] * 0.6)
    tips = np.zeros((H, W), np.float32)
    for x in (m * 1.2, W - m * 1.2):
        yy, xx = np.mgrid[0:H, 0:W]
        tips += np.exp(-(((xx - x) / (7 * SS)) ** 2 + ((yy - H / 2) / (7 * SS)) ** 2))
    frame = np.clip(outer - inner, 0, 1)
    rgb, a = compose(W, H, [(blur(outer, 3 * SS), (0, 0, 0), 0.6), (frame, tex, 1.0),
                            (np.clip(tips, 0, 1), (1.0, 0.55, 0.15), 1.0), (np.clip(tips * 0.6, 0, 1), (1.0, 0.95, 0.7), 0.8)])
    save('bar_frame.png', rgb, a, (256, 64))


def badge():
    W, H = 128 * SS, 48 * SS
    c = 14 * SS
    pts = [(0, H / 2), (c, 2 * SS), (W - c, 2 * SS), (W, H / 2), (W - c, H - 2 * SS), (c, H - 2 * SS)]
    body = poly(W, H, pts)
    inner = poly(W, H, [(4 * SS, H / 2), (c + 2 * SS, 5 * SS), (W - c - 2 * SS, 5 * SS), (W - 4 * SS, H / 2), (W - c - 2 * SS, H - 5 * SS), (c + 2 * SS, H - 5 * SS)])
    tex = stone_texture(W, H, 41, 0.12, 0.1)
    rgb, a = compose(W, H, [(body, (0.42, 0.38, 0.35), 1.0), (inner, tex, 1.0)])
    save('badge.png', rgb, a, (128, 48))


def sheet():
    W, H = 160 * SS, 160 * SS
    body = rrect(W, H, 2 * SS, 16 * SS)
    tex = stone_texture(W, H, 51, 0.11, 0.12)
    yy = np.mgrid[0:H, 0:W][0] / H
    edge = np.clip(1 - yy * 14, 0, 1) * body
    rgb, a = compose(W, H, [(body, tex, 0.97), (edge, (1.0, 0.5, 0.15), 0.55),
                            (np.clip(body - rrect(W, H, 4 * SS, 14 * SS), 0, 1), (0.5, 0.35, 0.22), 0.8)])
    save('sheet.png', rgb, a, (160, 160))


def main():
    os.makedirs(OUT, exist_ok=True)
    stone_panel()
    stone_panel('tile_on.png', True)
    stone_button()
    slot()
    bar_frame()
    badge()
    sheet()


if __name__ == '__main__':
    main()
