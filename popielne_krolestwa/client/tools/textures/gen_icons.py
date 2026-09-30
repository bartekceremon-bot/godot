#!/usr/bin/env python3
"""
Malowane ikony przedmiotów Popielnych Królestw (96x96, wygładzane nadpróbkowaniem 4x).

Każda ikona ma 9 wariantów tieru (0..8): materiał (żelazo, brąz, stal, fiolet, złoto, żar,
mithril, obsydian), poświatę tła od T4 i znaczek tieru. Wynik:
  client/assets/items/items.png  – atlas: kolumna = tier, wiersz = ikona
  client/assets/atlas_index.json – klucz "items" (pozycje) i "tile" (rozmiar komórki)

Użycie:  python3 tools/textures/gen_icons.py   (wymaga numpy i pillow)
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

T = 96          # rozmiar ikony
SS = 4          # nadpróbkowanie
W = T * SS
ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'

ICONS = ["wood", "stone", "ore", "fiber", "hide", "planks", "blocks", "bars", "cloth", "leather",
         "sword", "axe", "club", "bow", "shield", "woodaxe", "pickaxe", "sickle",
         "plate_head", "plate_body", "plate_legs", "plate_feet", "leather_head", "leather_body",
         "leather_legs", "leather_feet", "cloth_head", "cloth_body", "cloth_legs", "cloth_feet",
         "gold", "meat", "bone", "hp_potion", "mp_potion", "mount_horse", "mount_elk", "mount_camel",
         "mount_warwolf", "mount_drake", "unknown"]

# Materiały tierów: metal (jasny, ciemny), skóra, płótno, drewno, akcent (klejnoty, poświata).
METAL = [(0.62, 0.62, 0.64), (0.6, 0.6, 0.62), (0.78, 0.52, 0.3), (0.62, 0.72, 0.86), (0.48, 0.38, 0.62),
         (0.95, 0.76, 0.3), (0.86, 0.34, 0.16), (0.9, 0.93, 0.98), (0.34, 0.3, 0.38)]
LEATHER = [(0.56, 0.37, 0.2), (0.56, 0.37, 0.2), (0.45, 0.3, 0.17), (0.35, 0.26, 0.22), (0.2, 0.15, 0.17),
           (0.55, 0.3, 0.15), (0.45, 0.14, 0.1), (0.8, 0.76, 0.7), (0.12, 0.1, 0.12)]
CLOTH = [(0.84, 0.78, 0.62), (0.84, 0.78, 0.62), (0.28, 0.52, 0.33), (0.24, 0.36, 0.68), (0.44, 0.18, 0.52),
         (0.75, 0.6, 0.2), (0.62, 0.12, 0.1), (0.92, 0.92, 0.96), (0.1, 0.08, 0.12)]
WOOD = [(0.5, 0.33, 0.18), (0.5, 0.33, 0.18), (0.45, 0.28, 0.15), (0.35, 0.25, 0.2), (0.25, 0.16, 0.2),
        (0.4, 0.22, 0.1), (0.3, 0.1, 0.06), (0.85, 0.82, 0.75), (0.1, 0.08, 0.1)]
ACCENT = [(0.9, 0.8, 0.5), (0.8, 0.8, 0.8), (0.4, 0.85, 0.35), (0.35, 0.6, 1.0), (0.75, 0.35, 1.0),
          (1.0, 0.8, 0.25), (1.0, 0.4, 0.1), (0.6, 0.95, 1.0), (1.0, 0.15, 0.1)]
TIER_BADGE = [None, (0.55, 0.55, 0.55), (0.31, 0.6, 0.24), (0.25, 0.44, 0.75), (0.6, 0.28, 0.72),
              (0.78, 0.63, 0.19), (0.75, 0.31, 0.16), (0.85, 0.85, 0.85), (0.15, 0.15, 0.15)]
ROMAN = ['', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII']


# ---------------------------------------------------------------------------
# Warstwy i kształty
# ---------------------------------------------------------------------------

class Canvas:
    def __init__(self):
        self.rgb = np.zeros((W, W, 3), np.float32)
        self.a = np.zeros((W, W), np.float32)

    def paint(self, mask, color, alpha=1.0):
        m = np.clip(mask, 0, 1) * alpha
        if color.ndim == 1:
            color = np.broadcast_to(color, (W, W, 3))
        self.rgb = self.rgb * (1 - m[..., None]) + color * m[..., None]
        self.a = self.a + m * (1 - self.a)

    def image(self):
        img = np.dstack([np.clip(self.rgb, 0, 1), np.clip(self.a, 0, 1)])
        im = Image.fromarray((img * 255).astype(np.uint8), 'RGBA')
        return im.resize((T, T), Image.LANCZOS)


YY, XX = np.mgrid[0:W, 0:W].astype(np.float32) / W


def P(pts):
    return [(x * W, y * W) for x, y in pts]


def poly(pts):
    im = Image.new('L', (W, W), 0)
    ImageDraw.Draw(im).polygon(P(pts), fill=255)
    return np.asarray(im, np.float32) / 255


def ellipse(cx, cy, rx, ry):
    im = Image.new('L', (W, W), 0)
    ImageDraw.Draw(im).ellipse([(cx - rx) * W, (cy - ry) * W, (cx + rx) * W, (cy + ry) * W], fill=255)
    return np.asarray(im, np.float32) / 255


def line(pts, width):
    im = Image.new('L', (W, W), 0)
    ImageDraw.Draw(im).line(P(pts), fill=255, width=int(width * W), joint='curve')
    for p in pts:
        r = width * W / 2
        ImageDraw.Draw(im).ellipse([p[0] * W - r, p[1] * W - r, p[0] * W + r, p[1] * W + r], fill=255)
    return np.asarray(im, np.float32) / 255


def rect(x0, y0, x1, y1, radius=0.0):
    im = Image.new('L', (W, W), 0)
    ImageDraw.Draw(im).rounded_rectangle([x0 * W, y0 * W, x1 * W, y1 * W], radius=radius * W, fill=255)
    return np.asarray(im, np.float32) / 255


def grow(mask, px):
    im = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8), 'L')
    im = im.filter(ImageFilter.MaxFilter(int(px * 2 + 1) | 1))
    return np.asarray(im, np.float32) / 255


def blur(mask, px):
    im = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8), 'L')
    return np.asarray(im.filter(ImageFilter.GaussianBlur(px)), np.float32) / 255


def C(c):
    return np.array(c, np.float32)


def grad(c0, c1, angle=0.0, lo=0.0, hi=1.0):
    """Gradient liniowy przez cały obraz (kąt w stopniach: 0 = góra->dół)."""
    a = math.radians(angle)
    t = (XX - 0.5) * math.sin(a) + (YY - 0.5) * math.cos(a) + 0.5
    t = np.clip((t - lo) / max(hi - lo, 1e-3), 0, 1)
    return C(c0) * (1 - t[..., None]) + C(c1) * t[..., None]


def shade(c, k):
    return tuple(min(1.0, max(0.0, v * k)) for v in c)


def mix(a, b, t):
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


def noise(scale, seed):
    r = np.random.default_rng(seed)
    n = r.random((int(W / scale) + 2, int(W / scale) + 2)).astype(np.float32)
    im = Image.fromarray((n * 255).astype(np.uint8), 'L').resize((W, W), Image.BICUBIC)
    return np.asarray(im, np.float32) / 255


def solid(cv, mask, base, light_angle=-35.0, contrast=0.45, outline=0.03, spec=0.0, tex=None):
    """Bryła: ciemny kontur, gradient światła, faktura, połysk."""
    if outline > 0:
        cv.paint(grow(mask, outline * W) * (1 - mask), C((0.07, 0.05, 0.05)))
    lit = grad(shade(base, 1 + contrast), shade(base, 1 - contrast), light_angle, 0.15, 0.85)
    if tex is not None:
        lit = lit * (0.82 + tex[..., None] * 0.36)
    cv.paint(mask, lit)
    if spec > 0:
        edge = mask - blur(mask, 5)
        hl = np.clip(edge, 0, 1) * np.clip(1.2 - (XX + YY), 0, 1)
        cv.paint(hl, C((1, 1, 1)), spec)


def metal(cv, mask, base, spec=0.8):
    """Metal: mocny gradient, pas refleksu, jasna krawędź."""
    cv.paint(grow(mask, 0.028 * W) * (1 - mask), C((0.06, 0.05, 0.06)))
    g = grad(shade(base, 1.5), shade(base, 0.45), -30, 0.1, 0.9)
    cv.paint(mask, g)
    band = np.clip(1 - np.abs((XX - YY) * 3.2 + 0.2), 0, 1) ** 3
    cv.paint(mask * band, C((1, 1, 1)), 0.35 * spec)
    edge = np.clip(mask - blur(mask, 4) * 1.0, 0, 1)
    cv.paint(edge * np.clip(1.3 - (XX + YY), 0, 1), C((1, 1, 0.95)), 0.8 * spec)


def gem(cv, cx, cy, r, color):
    m = ellipse(cx, cy, r, r)
    cv.paint(grow(m, 0.02 * W) * (1 - m), C((0.1, 0.08, 0.05)))
    cv.paint(m, grad(shade(color, 1.4), shade(color, 0.5), -30, 0.35, 0.65))
    cv.paint(ellipse(cx - r * 0.35, cy - r * 0.35, r * 0.3, r * 0.25), C((1, 1, 1)), 0.85)


def glow(cv, tier, cx=0.5, cy=0.5, r=0.42):
    """Poświata tła dla wysokich tierów."""
    if tier < 4:
        return
    d = np.sqrt((XX - cx) ** 2 + (YY - cy) ** 2) / r
    m = np.clip(1 - d, 0, 1) ** 2 * (0.25 + (tier - 4) * 0.1)
    cv.paint(m, C(ACCENT[tier]))


def runes(cv, mask, tier):
    """Świecące runy na ostrzu od T6."""
    if tier < 6:
        return
    n = noise(W / 24, tier * 7)
    r = ((np.sin(YY * 70) > 0.6) & (n > 0.55)).astype(np.float32) * mask
    cv.paint(blur(r, 3), C(ACCENT[tier]), 0.9)
    cv.paint(r, C((1, 1, 0.9)), 0.8)


# ---------------------------------------------------------------------------
# Ikony
# ---------------------------------------------------------------------------

def i_sword(cv, t):
    glow(cv, t)
    m = METAL[t]
    blade = poly([(0.73, 0.14), (0.8, 0.2), (0.4, 0.62), (0.33, 0.55)])
    tip = poly([(0.73, 0.14), (0.86, 0.1), (0.8, 0.2)])
    metal(cv, np.clip(blade + tip, 0, 1), m)
    fuller = line([(0.72, 0.19), (0.4, 0.55)], 0.018)
    cv.paint(fuller, C(shade(m, 0.55)), 0.7)
    runes(cv, blade, t)
    guard = line([(0.24, 0.5), (0.47, 0.73)], 0.06)
    metal(cv, guard, METAL[5] if t >= 3 else shade(m, 0.8))
    grip = line([(0.35, 0.65), (0.2, 0.8)], 0.055)
    solid(cv, grip, LEATHER[t], tex=noise(W / 40, 3))
    for i in range(4):
        p = 0.35 - i * 0.04
        cv.paint(line([(p - 0.02, 0.63 + i * 0.04), (p + 0.02, 0.67 + i * 0.04)], 0.012), C((0.1, 0.07, 0.05)), 0.7)
    pom = ellipse(0.17, 0.83, 0.045, 0.045)
    metal(cv, pom, METAL[5] if t >= 3 else m)
    if t >= 4:
        gem(cv, 0.355, 0.615, 0.03, ACCENT[t])
        gem(cv, 0.17, 0.83, 0.022, ACCENT[t])


def i_axe(cv, t):
    glow(cv, t)
    handle = line([(0.28, 0.88), (0.64, 0.2)], 0.06)
    solid(cv, handle, WOOD[t], tex=noise(W / 20, 5))
    head = poly([(0.52, 0.16), (0.62, 0.12), (0.88, 0.1), (0.94, 0.3), (0.86, 0.5), (0.66, 0.42), (0.56, 0.36)])
    metal(cv, head, METAL[t])
    edge = line([(0.88, 0.12), (0.93, 0.3), (0.86, 0.48)], 0.02)
    cv.paint(edge, C((1, 1, 1)), 0.5)
    runes(cv, head, t)
    if t >= 3:
        band = line([(0.55, 0.3), (0.63, 0.34)], 0.05)
        metal(cv, band, METAL[5])
    if t >= 5:
        gem(cv, 0.72, 0.28, 0.035, ACCENT[t])


def i_club(cv, t):
    glow(cv, t)
    handle = line([(0.25, 0.88), (0.58, 0.36)], 0.065)
    solid(cv, handle, WOOD[t], tex=noise(W / 20, 7))
    head = ellipse(0.66, 0.26, 0.17, 0.17)
    metal(cv, head, METAL[t])
    for a in range(8):
        ang = a * math.pi / 4 + 0.3
        cx, cy = 0.66 + math.cos(ang) * 0.17, 0.26 + math.sin(ang) * 0.17
        sp = poly([(cx + math.cos(ang) * 0.09, cy + math.sin(ang) * 0.09), (cx + math.cos(ang + 1.6) * 0.04, cy + math.sin(ang + 1.6) * 0.04),
                   (cx + math.cos(ang - 1.6) * 0.04, cy + math.sin(ang - 1.6) * 0.04)])
        metal(cv, sp, shade(METAL[t], 0.9))
    if t >= 4:
        gem(cv, 0.66, 0.26, 0.05, ACCENT[t])


def i_bow(cv, t):
    glow(cv, t)
    arc = np.zeros((W, W), np.float32)
    pts = [(0.22 + 0.58 * math.sin(a) ** 1.0 * 0.0 + 0.0, 0.0) for a in range(1)]
    pts = []
    for i in range(21):
        s = i / 20
        ang = -1.2 + s * 2.4
        pts.append((0.3 + math.cos(ang) * 0.42, 0.5 + math.sin(ang) * 0.42))
    arc = line(pts, 0.05)
    solid(cv, arc, WOOD[t], tex=noise(W / 16, 9), spec=0.3)
    string = line([pts[0], pts[-1]], 0.008)
    cv.paint(string, C((0.9, 0.88, 0.8)), 0.9)
    grip = line([(0.72, 0.44), (0.72, 0.56)], 0.07)
    solid(cv, grip, LEATHER[t])
    for e in (pts[0], pts[-1]):
        metal(cv, ellipse(e[0], e[1], 0.035, 0.035), METAL[5] if t >= 3 else METAL[t])
    arrow = line([(0.2, 0.5), (0.7, 0.5)], 0.012)
    cv.paint(arrow, C((0.4, 0.3, 0.2)))
    metal(cv, poly([(0.14, 0.5), (0.21, 0.47), (0.21, 0.53)]), METAL[t])
    cv.paint(poly([(0.66, 0.5), (0.72, 0.44), (0.76, 0.44), (0.7, 0.5), (0.76, 0.56), (0.72, 0.56)]), C(ACCENT[t] if t >= 4 else (0.85, 0.2, 0.15)))


def i_shield(cv, t):
    glow(cv, t)
    body = poly([(0.18, 0.14), (0.82, 0.14), (0.82, 0.48), (0.5, 0.92), (0.18, 0.48)])
    body = np.clip(body + ellipse(0.5, 0.48, 0.32, 0.12) * (YY > 0.4) * 0, 0, 1)
    rim = body - np.clip(blur(body, 1) - (grow(1 - body, 0.05 * W)), 0, 1)
    face_col = CLOTH[t] if t > 0 else (0.55, 0.2, 0.15)
    solid(cv, body, face_col, contrast=0.35)
    inner = poly([(0.24, 0.2), (0.76, 0.2), (0.76, 0.47), (0.5, 0.84), (0.24, 0.47)])
    ring = np.clip(body - inner, 0, 1)
    metal(cv, ring, METAL[t])
    # Herb: krzyż/gwiazda.
    cross = np.clip(rect(0.46, 0.26, 0.54, 0.7) + rect(0.32, 0.36, 0.68, 0.44), 0, 1)
    metal(cv, cross, METAL[5] if t >= 3 else shade(METAL[t], 1.1))
    boss = ellipse(0.5, 0.4, 0.07, 0.07)
    metal(cv, boss, METAL[t])
    if t >= 4:
        gem(cv, 0.5, 0.4, 0.04, ACCENT[t])


def i_woodaxe(cv, t):
    handle = line([(0.25, 0.88), (0.62, 0.22)], 0.055)
    solid(cv, handle, WOOD[t], tex=noise(W / 20, 11))
    head = poly([(0.52, 0.2), (0.78, 0.12), (0.84, 0.26), (0.8, 0.4), (0.6, 0.34)])
    metal(cv, head, METAL[t])


def i_pickaxe(cv, t):
    handle = line([(0.22, 0.88), (0.6, 0.3)], 0.055)
    solid(cv, handle, WOOD[t], tex=noise(W / 20, 13))
    head = line([(0.24, 0.3), (0.45, 0.18), (0.7, 0.16), (0.9, 0.3)], 0.05)
    metal(cv, head, METAL[t])


def i_sickle(cv, t):
    handle = line([(0.28, 0.9), (0.4, 0.62)], 0.06)
    solid(cv, handle, WOOD[t])
    pts = []
    for i in range(18):
        a = math.pi * 1.05 + i / 17 * math.pi * 1.1
        pts.append((0.56 + math.cos(a) * 0.26, 0.4 + math.sin(a) * 0.26))
    blade = line(pts, 0.05)
    metal(cv, blade, METAL[t])


def i_plate_head(cv, t):
    glow(cv, t)
    m = METAL[t]
    helm = np.clip(ellipse(0.5, 0.45, 0.3, 0.32) + rect(0.2, 0.45, 0.8, 0.8, 0.08), 0, 1)
    metal(cv, helm, m)
    visor = rect(0.28, 0.46, 0.72, 0.52, 0.02)
    cv.paint(visor, C((0.04, 0.04, 0.05)))
    nasal = rect(0.475, 0.5, 0.525, 0.72)
    metal(cv, nasal, shade(m, 1.1))
    for i in range(5):
        cv.paint(ellipse(0.34 + i * 0.08, 0.63, 0.012, 0.012), C((0.05, 0.05, 0.05)), 0.8)
    if t >= 3:
        crest = rect(0.47, 0.1, 0.53, 0.34, 0.02)
        metal(cv, crest, METAL[5])
    if t >= 5:
        plume = poly([(0.5, 0.12), (0.6, 0.02), (0.82, 0.06), (0.9, 0.2), (0.7, 0.16)])
        solid(cv, plume, (0.75, 0.12, 0.1), tex=noise(W / 30, 21))
    if t >= 4:
        gem(cv, 0.5, 0.36, 0.035, ACCENT[t])


def i_plate_body(cv, t):
    glow(cv, t)
    m = METAL[t]
    body = poly([(0.3, 0.16), (0.7, 0.16), (0.82, 0.3), (0.76, 0.86), (0.24, 0.86), (0.18, 0.3)])
    metal(cv, body, m)
    for side in (-1, 1):
        pad = ellipse(0.5 + side * 0.3, 0.26, 0.16, 0.12)
        metal(cv, pad, shade(m, 1.05))
    ridge = line([(0.5, 0.2), (0.5, 0.82)], 0.02)
    cv.paint(ridge, C(shade(m, 1.6)), 0.6)
    for i in range(3):
        cv.paint(line([(0.28, 0.66 + i * 0.07), (0.72, 0.66 + i * 0.07)], 0.012), C((0.05, 0.05, 0.05)), 0.6)
    neck = ellipse(0.5, 0.16, 0.12, 0.05)
    cv.paint(neck, C((0.05, 0.04, 0.05)))
    if t >= 3:
        cv.paint(line([(0.3, 0.2), (0.5, 0.32), (0.7, 0.2)], 0.025), C(METAL[5]), 0.9)
    if t >= 4:
        gem(cv, 0.5, 0.42, 0.045, ACCENT[t])


def i_plate_legs(cv, t):
    glow(cv, t)
    m = METAL[t]
    belt = rect(0.24, 0.12, 0.76, 0.26, 0.03)
    metal(cv, belt, shade(m, 0.9))
    for side in (-1, 1):
        leg = poly([(0.5 + side * 0.02, 0.24), (0.5 + side * 0.26, 0.24), (0.5 + side * 0.22, 0.9), (0.5 + side * 0.06, 0.9)])
        metal(cv, leg, m)
        knee = ellipse(0.5 + side * 0.14, 0.56, 0.07, 0.06)
        metal(cv, knee, shade(m, 1.15))
    if t >= 4:
        gem(cv, 0.5, 0.19, 0.03, ACCENT[t])


def i_plate_feet(cv, t):
    glow(cv, t)
    m = METAL[t]
    for dx in (-0.2, 0.18):
        boot = np.clip(rect(0.36 + dx, 0.2, 0.56 + dx, 0.7, 0.04) + ellipse(0.58 + dx, 0.74, 0.2, 0.1), 0, 1)
        metal(cv, boot, m)
        cv.paint(line([(0.38 + dx, 0.45), (0.56 + dx, 0.45)], 0.012), C((0.05, 0.05, 0.05)), 0.6)


def i_leather_head(cv, t):
    l = LEATHER[t]
    hood = np.clip(ellipse(0.5, 0.45, 0.32, 0.34) + poly([(0.2, 0.5), (0.8, 0.5), (0.86, 0.9), (0.14, 0.9)]), 0, 1)
    solid(cv, hood, l, tex=noise(W / 30, 31))
    face = ellipse(0.5, 0.55, 0.18, 0.22)
    cv.paint(face, grad((0.05, 0.04, 0.04), (0.2, 0.15, 0.12), 0))
    cv.paint(line([(0.3, 0.3), (0.7, 0.3)], 0.012), C(shade(l, 0.6)), 0.7)


def i_leather_body(cv, t):
    l = LEATHER[t]
    body = poly([(0.26, 0.14), (0.74, 0.14), (0.9, 0.3), (0.8, 0.44), (0.76, 0.88), (0.24, 0.88), (0.2, 0.44), (0.1, 0.3)])
    solid(cv, body, l, tex=noise(W / 30, 33))
    cv.paint(line([(0.5, 0.18), (0.5, 0.86)], 0.012), C(shade(l, 0.5)), 0.8)
    for i in range(5):
        cv.paint(ellipse(0.46, 0.25 + i * 0.12, 0.012, 0.012), C((0.85, 0.75, 0.5)))
    belt = rect(0.22, 0.6, 0.78, 0.67)
    solid(cv, belt, (0.2, 0.13, 0.08))
    metal(cv, rect(0.46, 0.595, 0.54, 0.675, 0.01), METAL[5])


def i_leather_legs(cv, t):
    l = shade(LEATHER[t], 0.9)
    for side in (-1, 1):
        leg = poly([(0.5 + side * 0.01, 0.2), (0.5 + side * 0.26, 0.2), (0.5 + side * 0.22, 0.9), (0.5 + side * 0.06, 0.9)])
        solid(cv, leg, l, tex=noise(W / 30, 35))
    solid(cv, rect(0.24, 0.14, 0.76, 0.24, 0.02), (0.22, 0.14, 0.08))


def i_leather_feet(cv, t):
    l = shade(LEATHER[t], 0.8)
    for dx in (-0.2, 0.18):
        boot = np.clip(rect(0.36 + dx, 0.2, 0.56 + dx, 0.7, 0.05) + ellipse(0.56 + dx, 0.74, 0.18, 0.1), 0, 1)
        solid(cv, boot, l, tex=noise(W / 30, 37))
        cv.paint(rect(0.34 + dx, 0.2, 0.58 + dx, 0.27, 0.02), C(shade(l, 1.3)))


def i_cloth_head(cv, t):
    c = CLOTH[t]
    hat = poly([(0.5, 0.06), (0.72, 0.62), (0.28, 0.62)])
    solid(cv, hat, c, tex=noise(W / 30, 41))
    brim = ellipse(0.5, 0.66, 0.4, 0.1)
    solid(cv, brim, shade(c, 0.85))
    band = rect(0.3, 0.55, 0.7, 0.61)
    cv.paint(band, C(ACCENT[t] if t >= 2 else (0.5, 0.35, 0.2)))
    if t >= 4:
        gem(cv, 0.5, 0.58, 0.03, ACCENT[t])


def i_cloth_body(cv, t):
    c = CLOTH[t]
    robe = poly([(0.34, 0.1), (0.66, 0.1), (0.84, 0.3), (0.74, 0.36), (0.84, 0.92), (0.16, 0.92), (0.26, 0.36), (0.16, 0.3)])
    solid(cv, robe, c, tex=noise(W / 30, 43))
    trim = ACCENT[t] if t >= 2 else shade(c, 0.7)
    cv.paint(line([(0.5, 0.12), (0.5, 0.9)], 0.03), C(trim))
    cv.paint(line([(0.17, 0.9), (0.83, 0.9)], 0.035), C(trim))
    if t >= 4:
        gem(cv, 0.5, 0.3, 0.035, ACCENT[t])


def i_cloth_legs(cv, t):
    c = shade(CLOTH[t], 0.9)
    for side in (-1, 1):
        leg = poly([(0.5 + side * 0.01, 0.2), (0.5 + side * 0.26, 0.2), (0.5 + side * 0.24, 0.9), (0.5 + side * 0.05, 0.9)])
        solid(cv, leg, c, tex=noise(W / 30, 45))
    cv.paint(rect(0.24, 0.14, 0.76, 0.22, 0.02), C(ACCENT[t] if t >= 2 else shade(c, 0.7)))


def i_cloth_feet(cv, t):
    for dx in (-0.2, 0.18):
        sole = ellipse(0.5 + dx, 0.6, 0.12, 0.26)
        solid(cv, sole, (0.55, 0.38, 0.22))
        for i in range(3):
            cv.paint(line([(0.4 + dx, 0.45 + i * 0.1), (0.6 + dx, 0.45 + i * 0.1)], 0.02), C(CLOTH[t]))


def i_wood(cv, t):
    for i, (cx, cy) in enumerate([(0.34, 0.62), (0.62, 0.62), (0.48, 0.4)]):
        log = rect(cx - 0.3, cy - 0.1, cx + 0.14, cy + 0.1, 0.1)
        solid(cv, log, WOOD[t], tex=noise(W / 14, 51 + i))
        end = ellipse(cx + 0.14, cy, 0.08, 0.1)
        solid(cv, end, shade(WOOD[t], 1.5), outline=0.02)
        for r in (0.05, 0.025):
            cv.paint(ellipse(cx + 0.14, cy, r * 0.8, r) - ellipse(cx + 0.14, cy, r * 0.8 - 0.006, r - 0.006), C(shade(WOOD[t], 0.8)), 0.8)


def i_stone(cv, t):
    for i, (cx, cy, r) in enumerate([(0.36, 0.62, 0.2), (0.64, 0.6, 0.18), (0.5, 0.38, 0.17)]):
        pts = []
        for k in range(7):
            a = k / 7 * math.tau + i
            rr = r * (0.8 + 0.25 * math.sin(k * 2.3 + i))
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.8))
        solid(cv, poly(pts), (0.55, 0.53, 0.5), tex=noise(W / 18, 61 + i))


def i_ore(cv, t):
    pts = [(0.2, 0.7), (0.24, 0.4), (0.44, 0.22), (0.72, 0.26), (0.84, 0.5), (0.76, 0.78), (0.4, 0.84)]
    rock = poly(pts)
    solid(cv, rock, (0.42, 0.4, 0.38), tex=noise(W / 18, 71))
    vein = METAL[t] if t != 1 else (0.7, 0.7, 0.72)
    for k in range(6):
        cx, cy = 0.35 + (k * 0.13) % 0.4, 0.38 + (k * 0.21) % 0.36
        metal(cv, ellipse(cx, cy, 0.05, 0.04) * rock, vein)


def i_fiber(cv, t):
    col = (0.75, 0.68, 0.4) if t < 5 else CLOTH[t]
    for i in range(9):
        x = 0.3 + i * 0.05
        cv.paint(line([(x, 0.14), (0.5 + (x - 0.5) * 0.3, 0.52), (x + 0.04, 0.9)], 0.022), C(shade(col, 0.8 + (i % 3) * 0.15)))
    solid(cv, rect(0.3, 0.46, 0.72, 0.56, 0.02), (0.45, 0.3, 0.15))


def i_hide(cv, t):
    pts = [(0.2, 0.2), (0.4, 0.26), (0.6, 0.2), (0.82, 0.24), (0.76, 0.5), (0.86, 0.8), (0.6, 0.76), (0.4, 0.84), (0.16, 0.8), (0.24, 0.5)]
    solid(cv, poly(pts), LEATHER[t], tex=noise(W / 20, 81))


def i_planks(cv, t):
    for i in range(3):
        y = 0.3 + i * 0.16
        solid(cv, rect(0.14, y, 0.86, y + 0.13, 0.015), shade(WOOD[t], 1.1 - i * 0.08), tex=noise(W / 10, 91 + i))
        cv.paint(line([(0.16, y + 0.065), (0.84, y + 0.065)], 0.004), C(shade(WOOD[t], 0.6)), 0.5)


def i_blocks(cv, t):
    for (x, y) in [(0.14, 0.5), (0.5, 0.5), (0.32, 0.22)]:
        solid(cv, rect(x, y, x + 0.35, y + 0.3, 0.02), (0.62, 0.6, 0.56), tex=noise(W / 18, int(x * 100)))


def i_bars(cv, t):
    m = METAL[t]
    for (x, y) in [(0.12, 0.56), (0.5, 0.56), (0.31, 0.32)]:
        bar = poly([(x + 0.04, y), (x + 0.34, y), (x + 0.38, y + 0.2), (x, y + 0.2)])
        metal(cv, bar, m)


def i_cloth(cv, t):
    c = CLOTH[t]
    roll = rect(0.16, 0.3, 0.84, 0.7, 0.18)
    solid(cv, roll, c, tex=noise(W / 24, 101))
    for i in range(4):
        cv.paint(line([(0.28 + i * 0.14, 0.32), (0.28 + i * 0.14, 0.68)], 0.01), C(shade(c, 0.75)), 0.7)
    end = ellipse(0.8, 0.5, 0.07, 0.2)
    solid(cv, end, shade(c, 1.25))


def i_leather(cv, t):
    l = LEATHER[t]
    roll = rect(0.16, 0.3, 0.84, 0.7, 0.18)
    solid(cv, roll, l, tex=noise(W / 24, 103))
    solid(cv, rect(0.46, 0.28, 0.54, 0.72), (0.2, 0.12, 0.07))


def i_gold(cv, t):
    for i, (cx, cy) in enumerate([(0.36, 0.66), (0.62, 0.68), (0.5, 0.5), (0.4, 0.4), (0.62, 0.38), (0.5, 0.26)]):
        coin = ellipse(cx, cy, 0.14, 0.1)
        metal(cv, coin, (0.95, 0.76, 0.3))
        cv.paint(ellipse(cx, cy, 0.09, 0.06) - ellipse(cx, cy, 0.075, 0.045), C((0.6, 0.42, 0.1)), 0.7)


def i_meat(cv, t):
    m = ellipse(0.46, 0.46, 0.28, 0.22)
    solid(cv, m, (0.75, 0.25, 0.2), tex=noise(W / 20, 111))
    cv.paint(ellipse(0.42, 0.42, 0.14, 0.1), C((0.95, 0.8, 0.75)), 0.35)
    bone = line([(0.66, 0.62), (0.86, 0.84)], 0.06)
    solid(cv, bone, (0.95, 0.92, 0.84))


def i_bone(cv, t):
    b = line([(0.26, 0.74), (0.74, 0.26)], 0.08)
    for (x, y) in [(0.22, 0.72), (0.28, 0.8), (0.72, 0.2), (0.8, 0.28)]:
        b = np.clip(b + ellipse(x, y, 0.07, 0.07), 0, 1)
    solid(cv, b, (0.9, 0.87, 0.78))


def _potion(cv, t, col):
    glow(cv, 5, 0.5, 0.6, 0.35)
    body = ellipse(0.5, 0.62, 0.26, 0.26)
    neck = rect(0.42, 0.18, 0.58, 0.42, 0.02)
    glass = np.clip(body + neck, 0, 1)
    cv.paint(grow(glass, 0.025 * W) * (1 - glass), C((0.1, 0.08, 0.1)))
    cv.paint(glass, C((0.8, 0.85, 0.9)), 0.35)
    liquid = body * (YY > 0.5)
    cv.paint(liquid, grad(shade(col, 1.4), shade(col, 0.6), 0, 0.45, 0.9))
    cv.paint(ellipse(0.4, 0.55, 0.06, 0.12), C((1, 1, 1)), 0.6)
    solid(cv, rect(0.4, 0.1, 0.6, 0.2, 0.02), (0.55, 0.38, 0.22))


def i_hp_potion(cv, t):
    _potion(cv, t, (0.9, 0.12, 0.1))


def i_mp_potion(cv, t):
    _potion(cv, t, (0.2, 0.4, 1.0))


def _animal_head(cv, col, ears, horns=None, snout=0.3, mane=None):
    head = poly([(0.3, 0.2), (0.5, 0.18), (0.62, 0.32), (0.86, 0.66), (0.8, 0.82), (0.62, 0.78), (0.4, 0.62), (0.26, 0.84), (0.2, 0.5)])
    solid(cv, head, col, tex=noise(W / 20, 121))
    if mane:
        solid(cv, poly([(0.3, 0.2), (0.16, 0.3), (0.12, 0.7), (0.26, 0.84), (0.22, 0.46)]), mane)
    for e in ears:
        solid(cv, poly(e), shade(col, 0.9))
    if horns:
        for h in horns:
            solid(cv, line(h, 0.03), (0.85, 0.8, 0.7))
    cv.paint(ellipse(0.5, 0.38, 0.03, 0.03), C((0.05, 0.03, 0.03)))
    cv.paint(ellipse(0.8, 0.72, 0.025, 0.02), C((0.1, 0.05, 0.05)))
    solid(cv, line([(0.34, 0.58), (0.7, 0.8)], 0.02), (0.4, 0.25, 0.12))


def i_mount_horse(cv, t):
    _animal_head(cv, (0.5, 0.32, 0.18), [[(0.36, 0.22), (0.4, 0.06), (0.46, 0.2)]], mane=(0.2, 0.12, 0.08))


def i_mount_elk(cv, t):
    _animal_head(cv, (0.55, 0.42, 0.3), [[(0.4, 0.22), (0.3, 0.14), (0.42, 0.18)]],
                 horns=[[(0.4, 0.2), (0.3, 0.06), (0.16, 0.04)], [(0.34, 0.12), (0.4, 0.02)], [(0.46, 0.18), (0.6, 0.04), (0.74, 0.06)], [(0.6, 0.06), (0.62, 0.0)]])


def i_mount_camel(cv, t):
    _animal_head(cv, (0.8, 0.66, 0.44), [[(0.4, 0.22), (0.36, 0.14), (0.44, 0.2)]])


def i_mount_warwolf(cv, t):
    head = poly([(0.24, 0.24), (0.5, 0.3), (0.86, 0.56), (0.84, 0.66), (0.56, 0.7), (0.3, 0.8), (0.2, 0.5)])
    solid(cv, head, (0.45, 0.44, 0.46), tex=noise(W / 20, 131))
    for e in [[(0.26, 0.26), (0.3, 0.06), (0.42, 0.28)], [(0.4, 0.3), (0.5, 0.12), (0.54, 0.34)]]:
        solid(cv, poly(e), (0.35, 0.34, 0.36))
    cv.paint(ellipse(0.5, 0.44, 0.03, 0.02), C((1, 0.8, 0.2)))
    cv.paint(ellipse(0.84, 0.6, 0.03, 0.025), C((0.05, 0.05, 0.05)))
    cv.paint(poly([(0.62, 0.66), (0.66, 0.74), (0.7, 0.66)]), C((1, 1, 1)))


def i_mount_drake(cv, t):
    glow(cv, 6)
    head = poly([(0.2, 0.3), (0.5, 0.3), (0.9, 0.52), (0.86, 0.64), (0.5, 0.66), (0.26, 0.8), (0.16, 0.5)])
    solid(cv, head, (0.6, 0.16, 0.1), tex=noise(W / 16, 141))
    for h in [[(0.26, 0.3), (0.1, 0.1)], [(0.36, 0.3), (0.3, 0.08)]]:
        solid(cv, line(h, 0.035), (0.2, 0.15, 0.12))
    cv.paint(blur(ellipse(0.48, 0.42, 0.04, 0.025), 3), C((1, 0.8, 0.2)))
    cv.paint(ellipse(0.48, 0.42, 0.025, 0.018), C((1, 0.95, 0.5)))
    for i in range(4):
        cv.paint(poly([(0.56 + i * 0.07, 0.62), (0.59 + i * 0.07, 0.7), (0.62 + i * 0.07, 0.62)]), C((1, 1, 0.9)))


def i_unknown(cv, t):
    solid(cv, ellipse(0.5, 0.5, 0.3, 0.3), (0.4, 0.35, 0.3))
    im = Image.new('L', (W, W), 0)
    ImageDraw.Draw(im).text((W * 0.5, W * 0.5), '?', fill=255, font=ImageFont.truetype(FONT, int(W * 0.4)), anchor='mm')
    cv.paint(np.asarray(im, np.float32) / 255, C((0.95, 0.9, 0.8)))


def badge(img, t):
    """Znaczek tieru w lewym górnym rogu (cyfry rzymskie na tarczce w kolorze tieru)."""
    if t == 0:
        return img
    d = ImageDraw.Draw(img)
    col = tuple(int(v * 255) for v in TIER_BADGE[t])
    txt = ROMAN[t]
    f = ImageFont.truetype(FONT, 14)
    w = max(20, int(d.textlength(txt, font=f)) + 12)
    d.rounded_rectangle([2, 2, 2 + w, 20], radius=5, fill=col + (235,), outline=(20, 15, 10, 255), width=2)
    d.text((2 + w / 2, 11), txt, fill=(255, 250, 235, 255), font=f, anchor='mm', stroke_width=2, stroke_fill=(0, 0, 0, 200))
    return img


def make(name, t):
    cv = Canvas()
    globals()['i_' + name](cv, t)
    img = cv.image()
    # Cień pod przedmiotem.
    a = np.asarray(img)[..., 3].astype(np.float32) / 255
    sh = Image.fromarray((np.clip(a, 0, 1) * 150).astype(np.uint8), 'L').filter(ImageFilter.GaussianBlur(3))
    shadow = Image.new('RGBA', (T, T), (0, 0, 0, 0))
    shadow.putalpha(sh)
    base = Image.new('RGBA', (T, T), (0, 0, 0, 0))
    base.alpha_composite(shadow, (3, 4))
    base.alpha_composite(img)
    return badge(base, t)


def main():
    atlas = Image.new('RGBA', (9 * T, len(ICONS) * T), (0, 0, 0, 0))
    items = {}
    for i, name in enumerate(ICONS):
        for t in range(9):
            atlas.paste(make(name, t), (t * T, i * T))
            items['%s_%d' % (name, t)] = [t * T, i * T]
        print('ikona', name)
    atlas.save(os.path.join(ROOT, 'assets', 'items', 'items.png'), optimize=True)
    idx_path = os.path.join(ROOT, 'assets', 'atlas_index.json')
    idx = json.load(open(idx_path)) if os.path.exists(idx_path) else {}
    idx['items'] = items
    idx['tile'] = T
    json.dump(idx, open(idx_path, 'w'), indent='\t')


if __name__ == '__main__':
    main()
