#!/usr/bin/env python3
"""Ikony Ogrodu Alchemika (4.0, assets/ui/modes/*.png, 128 px): ogród, kocioł, grządka,
5 ziół i 5 eliksirów. Korzysta z rysowania kształtów z gen_mode_icons."""
import math

from PIL import Image

from gen_mode_icons import (Icon, poly, ell, rect, multi, P, W, GOLD, WOOD, STONE, IRON, GREEN, RED, BLUE, EMBER)

LEAF = ((150, 235, 110), (30, 110, 40))
SOIL = ((120, 80, 50), (55, 34, 20))
GLASS = ((235, 245, 255), (150, 170, 190))


def line(x0, y0, x1, y1, w):
    return lambda d, f: d.line(P([(x0, y0), (x1, y1)]), fill=f, width=int(w * W))


def leaf(ic, x, y, ang, ln=0.22, wd=0.09, col=LEAF):
    """Liść od (x, y) w kierunku ang (stopnie)."""
    a = math.radians(ang)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    tip = (x + dx * ln, y + dy * ln)
    mid = (x + dx * ln * 0.5, y + dy * ln * 0.5)
    ic.shape(poly([(x, y), (mid[0] + nx * wd, mid[1] + ny * wd), tip, (mid[0] - nx * wd, mid[1] - ny * wd)]), *col, ow=2, shine=0.5)


def garden():
    ic = Icon()
    ic.shape(rect(0.08, 0.62, 0.92, 0.9, 0.06), *SOIL)
    for x in (0.2, 0.5, 0.8):
        ic.shape(line(x, 0.66, x, 0.36, 0.035), *LEAF, ow=1.5)
        leaf(ic, x, 0.52, -140, 0.18)
        leaf(ic, x, 0.48, -40, 0.18)
    ic.shape(ell(0.12, 0.2, 0.3, 0.38), *EMBER, glow=(255, 140, 40))
    ic.shape(ell(0.42, 0.14, 0.58, 0.3), (255, 240, 150), (230, 170, 30), glow=(255, 210, 80))
    ic.shape(ell(0.71, 0.2, 0.89, 0.38), (190, 220, 255), (80, 110, 220), glow=(120, 160, 255))
    ic.save('garden')


def cauldron():
    ic = Icon()
    ic.shape(multi(rect(0.2, 0.84, 0.3, 0.94), rect(0.7, 0.84, 0.8, 0.94)), *IRON, ow=1.5)
    ic.shape(ell(0.12, 0.36, 0.88, 0.92), (90, 90, 100), (25, 25, 32), shine=0.6)
    ic.shape(ell(0.14, 0.32, 0.86, 0.48), (160, 255, 140), (40, 170, 60), glow=(120, 255, 120))
    for (x, y, r) in [(0.36, 0.22, 0.05), (0.56, 0.14, 0.04), (0.62, 0.26, 0.03)]:
        ic.shape(ell(x - r, y - r, x + r, y + r), (200, 255, 190), (80, 200, 90), ow=1.2, glow=(140, 255, 140))
    ic.shape(rect(0.1, 0.34, 0.9, 0.4, 0.03), *IRON, ow=1.5)
    ic.save('cauldron')


def h_ember_root():
    ic = Icon()
    ic.shape(poly([(0.5, 0.94), (0.36, 0.5), (0.5, 0.4), (0.64, 0.5)]), *EMBER, glow=(255, 120, 30))
    ic.shape(line(0.42, 0.62, 0.3, 0.8, 0.025), *EMBER, ow=1)
    ic.shape(line(0.58, 0.66, 0.7, 0.82, 0.025), *EMBER, ow=1)
    for a in (-120, -90, -60):
        leaf(ic, 0.5, 0.42, a, 0.3, 0.07)
    ic.save('herb_ember_root')


def h_moon_sage():
    ic = Icon()
    ic.shape(line(0.5, 0.92, 0.5, 0.2, 0.035), *LEAF, ow=1.5)
    col = ((210, 225, 255), (90, 110, 200))
    for i, y in enumerate((0.78, 0.62, 0.46, 0.3)):
        leaf(ic, 0.5, y, -160 if i % 2 else -20, 0.26 - i * 0.03, 0.08, col)
        leaf(ic, 0.5, y - 0.06, -20 if i % 2 else -160, 0.22 - i * 0.03, 0.07, col)
    ic.shape(ell(0.42, 0.08, 0.58, 0.24), (255, 255, 230), (190, 200, 255), glow=(180, 200, 255))
    ic.save('herb_moon_sage')


def h_goldbloom():
    ic = Icon()
    ic.shape(line(0.5, 0.94, 0.5, 0.5, 0.035), *LEAF, ow=1.5)
    leaf(ic, 0.5, 0.78, -150, 0.22)
    leaf(ic, 0.5, 0.72, -30, 0.22)
    for k in range(8):
        a = k * math.pi / 4
        cx, cy = 0.5 + math.cos(a) * 0.17, 0.36 + math.sin(a) * 0.17
        ic.shape(ell(cx - 0.1, cy - 0.1, cx + 0.1, cy + 0.1), *GOLD, ow=2)
    ic.shape(ell(0.4, 0.26, 0.6, 0.46), (255, 150, 60), (180, 70, 20), glow=(255, 200, 80))
    ic.save('herb_goldbloom')


def h_frost_lily():
    ic = Icon()
    ic.shape(line(0.5, 0.94, 0.5, 0.56, 0.035), *LEAF, ow=1.5)
    leaf(ic, 0.5, 0.86, -160, 0.26, 0.08)
    col = ((240, 252, 255), (110, 190, 240))
    for (x, y) in [(0.24, 0.24), (0.5, 0.12), (0.76, 0.24)]:
        ic.shape(poly([(0.5, 0.58), (x - 0.08, y + 0.06), (x, y), (x + 0.08, y + 0.06)]), *col, ow=2, shine=0.8, glow=(150, 220, 255))
    ic.shape(ell(0.44, 0.44, 0.56, 0.56), (255, 255, 220), (200, 230, 255))
    ic.save('herb_frost_lily')


def h_dragon_pepper():
    ic = Icon()
    ic.shape(poly([(0.42, 0.26), (0.6, 0.28), (0.66, 0.5), (0.56, 0.78), (0.36, 0.94), (0.4, 0.7), (0.36, 0.46)]), *RED, shine=0.8, glow=(255, 80, 40))
    ic.shape(poly([(0.4, 0.3), (0.62, 0.3), (0.58, 0.2), (0.44, 0.2)]), *LEAF, ow=2)
    ic.shape(line(0.5, 0.21, 0.6, 0.08, 0.03), *LEAF, ow=1)
    ic.shape(poly([(0.44, 0.38), (0.5, 0.36), (0.46, 0.56)]), (255, 230, 210), (255, 160, 140), outline=None)
    ic.save('herb_dragon_pepper')


def potion(name, liquid, glow):
    ic = Icon()
    ic.shape(multi(ell(0.2, 0.36, 0.8, 0.94), rect(0.4, 0.12, 0.6, 0.44)), *GLASS, shine=0.7)
    ic.shape(multi(ell(0.25, 0.48, 0.75, 0.9), rect(0.26, 0.56, 0.74, 0.7)), *liquid, outline=None, glow=glow)
    ic.shape(rect(0.36, 0.06, 0.64, 0.16, 0.02), *WOOD, ow=2)
    ic.shape(ell(0.3, 0.52, 0.42, 0.64), (255, 255, 255), (220, 230, 240), outline=None)
    ic.save('elixir_' + name)


if __name__ == '__main__':
    garden()
    cauldron()
    h_ember_root()
    h_moon_sage()
    h_goldbloom()
    h_frost_lily()
    h_dragon_pepper()
    potion('might', ((255, 140, 90), (190, 40, 20)), (255, 90, 40))
    potion('wisdom', ((200, 210, 255), (80, 90, 220)), (130, 150, 255))
    potion('wealth', ((255, 235, 130), (210, 150, 20)), (255, 210, 80))
    potion('strike', ((170, 245, 255), (30, 150, 210)), (100, 210, 255))
    potion('dragon', ((255, 120, 200), (150, 20, 120)), (255, 80, 160))
