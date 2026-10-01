#!/usr/bin/env python3
"""Ikony Twierdzy Popielników (4.4, assets/ui/modes/*.png, 128 px): twierdza i 6 budynków."""
from gen_mode_icons import Icon, poly, ell, rect, multi, P, W, GOLD, STONE, WOOD, IRON, RED, BLUE, PURPLE, EMBER

ROOF = ((200, 70, 50), (110, 25, 20))
ROOF_BLUE = ((110, 140, 230), (40, 50, 140))


def line(x0, y0, x1, y1, w):
    return lambda d, f: d.line(P([(x0, y0), (x1, y1)]), fill=f, width=int(w * W))


def crenels(ic, x0, x1, y, n, h=0.06):
    w = (x1 - x0) / (2 * n - 1)
    for k in range(n):
        x = x0 + 2 * k * w
        ic.shape(rect(x, y - h, x + w, y + 0.01), *STONE, ow=1.5, shine=0.2)


def door(ic, x, y, w, h):
    ic.shape(multi(rect(x - w / 2, y - h + w / 2, x + w / 2, y), ell(x - w / 2, y - h, x + w / 2, y - h + w)), *WOOD, ow=1.5)


def stronghold():
    ic = Icon()
    ic.shape(rect(0.1, 0.4, 0.3, 0.92), *STONE)
    ic.shape(rect(0.7, 0.4, 0.9, 0.92), *STONE)
    ic.shape(rect(0.26, 0.5, 0.74, 0.92), *STONE)
    crenels(ic, 0.1, 0.3, 0.4, 3)
    crenels(ic, 0.7, 0.9, 0.4, 3)
    crenels(ic, 0.26, 0.74, 0.5, 5)
    door(ic, 0.5, 0.92, 0.2, 0.26)
    ic.shape(line(0.5, 0.5, 0.5, 0.14, 0.02), *IRON, ow=1)
    ic.shape(poly([(0.51, 0.14), (0.74, 0.2), (0.51, 0.27)]), *EMBER, ow=1.5, glow=(255, 130, 40))
    ic.save('stronghold')


def treasury():
    ic = Icon()
    ic.shape(rect(0.16, 0.42, 0.84, 0.9, 0.03), *STONE)
    ic.shape(poly([(0.1, 0.44), (0.5, 0.14), (0.9, 0.44)]), *ROOF)
    for x in (0.26, 0.42, 0.58, 0.74):
        ic.shape(rect(x - 0.03, 0.48, x + 0.03, 0.86), (230, 225, 215), (150, 140, 130), ow=1.2)
    for (x, y) in [(0.3, 0.86), (0.5, 0.82), (0.7, 0.86), (0.4, 0.78), (0.6, 0.78)]:
        ic.shape(ell(x - 0.08, y - 0.04, x + 0.08, y + 0.04), *GOLD, ow=1.5, glow=(255, 200, 80))
    ic.save('sh_treasury')


def barracks():
    ic = Icon()
    ic.shape(rect(0.14, 0.46, 0.86, 0.9), *WOOD)
    ic.shape(poly([(0.08, 0.5), (0.5, 0.22), (0.92, 0.5)]), *ROOF)
    door(ic, 0.5, 0.9, 0.18, 0.26)
    # skrzyżowane miecze
    ic.shape(line(0.2, 0.08, 0.44, 0.34, 0.04), (230, 235, 245), (120, 130, 150), ow=1.2)
    ic.shape(line(0.8, 0.08, 0.56, 0.34, 0.04), (230, 235, 245), (120, 130, 150), ow=1.2)
    ic.shape(rect(0.17, 0.62, 0.3, 0.74), (255, 210, 120), (200, 140, 50), ow=1.2, glow=(255, 180, 60))
    ic.shape(rect(0.7, 0.62, 0.83, 0.74), (255, 210, 120), (200, 140, 50), ow=1.2, glow=(255, 180, 60))
    ic.save('sh_barracks')


def forge():
    ic = Icon()
    ic.shape(rect(0.12, 0.4, 0.88, 0.9, 0.03), *STONE)
    ic.shape(rect(0.62, 0.12, 0.78, 0.42), *STONE)
    ic.shape(ell(0.6, 0.02, 0.8, 0.14), (120, 120, 120), (60, 60, 60), outline=None, shine=0)
    ic.shape(multi(rect(0.24, 0.58, 0.56, 0.9), ell(0.24, 0.48, 0.56, 0.68)), (255, 200, 90), (220, 70, 10), outline=(40, 20, 10), glow=(255, 120, 30))
    # kowadło
    ic.shape(poly([(0.56, 0.7), (0.9, 0.7), (0.86, 0.76), (0.78, 0.76), (0.78, 0.86), (0.84, 0.9), (0.62, 0.9), (0.68, 0.86), (0.68, 0.76), (0.6, 0.76)]), *IRON, ow=1.5)
    ic.save('sh_forge')


def library():
    ic = Icon()
    ic.shape(rect(0.14, 0.4, 0.86, 0.9, 0.03), (225, 215, 195), (150, 135, 110))
    ic.shape(poly([(0.08, 0.42), (0.5, 0.12), (0.92, 0.42)]), *ROOF_BLUE)
    for i, col in enumerate([RED, BLUE, GOLD, PURPLE, ((150, 230, 140), (40, 120, 50))]):
        x = 0.24 + i * 0.11
        ic.shape(rect(x, 0.52 + (i % 2) * 0.04, x + 0.08, 0.86), *col, ow=1.2)
    ic.save('sh_library')


def mage_tower():
    ic = Icon()
    ic.shape(poly([(0.32, 0.92), (0.38, 0.36), (0.62, 0.36), (0.68, 0.92)]), (170, 160, 200), (80, 70, 110))
    ic.shape(poly([(0.28, 0.4), (0.5, 0.04), (0.72, 0.4)]), *ROOF_BLUE)
    ic.shape(ell(0.43, 0.48, 0.57, 0.62), (200, 240, 255), (80, 150, 255), ow=1.5, glow=(120, 180, 255))
    door(ic, 0.5, 0.92, 0.14, 0.18)
    for (x, y, r) in [(0.18, 0.2, 0.035), (0.82, 0.26, 0.03), (0.76, 0.1, 0.025)]:
        ic.shape(ell(x - r, y - r, x + r, y + r), (230, 220, 255), (150, 120, 255), outline=None, glow=(180, 150, 255))
    ic.save('sh_mage_tower')


def watchtower():
    ic = Icon()
    ic.shape(poly([(0.3, 0.92), (0.36, 0.34), (0.64, 0.34), (0.7, 0.92)]), *STONE)
    ic.shape(rect(0.26, 0.26, 0.74, 0.36), *STONE)
    crenels(ic, 0.26, 0.74, 0.26, 4)
    ic.shape(rect(0.45, 0.46, 0.55, 0.58, 0.02), (40, 30, 30), (20, 15, 15), ow=1)
    ic.shape(ell(0.4, 0.06, 0.6, 0.2), *EMBER, glow=(255, 150, 50))
    ic.shape(line(0.5, 0.2, 0.5, 0.26, 0.02), *IRON, ow=1)
    ic.save('sh_watchtower')


if __name__ == '__main__':
    stronghold()
    treasury()
    barracks()
    forge()
    library()
    mage_tower()
    watchtower()
