#!/usr/bin/env python3
"""Ikony trybów 3.2 (assets/ui/modes/*.png, 128 px): Lochy, Arena, Relikwie, klucz, odznaka
chwały, odłamek relikwii i 12 relikwii. Kształty wektorowe z gradientem, konturem, połyskiem
i poświatą – rysowane w 4× rozdzielczości i zmniejszane."""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'ui', 'modes')
S = 4
W = 128 * S


def P(pts):
    return [(x * W, y * W) for x, y in pts]


class Icon:
    def __init__(self):
        self.img = Image.new('RGBA', (W, W), (0, 0, 0, 0))

    def shape(self, draw_fn, top, bottom, outline=(25, 15, 10), ow=3.5, shine=0.35, glow=None):
        """draw_fn(d, fill) rysuje kształt na masce; gradient pionowy top→bottom."""
        m = Image.new('L', (W, W), 0)
        draw_fn(ImageDraw.Draw(m), 255)
        mask = np.asarray(m, np.float32) / 255
        if mask.max() == 0:
            return
        ys = np.nonzero(mask.max(1))[0]
        y0, y1 = ys.min(), ys.max() + 1
        t = np.clip((np.arange(W)[:, None] - y0) / max(1, y1 - y0), 0, 1)
        col = np.array(top, np.float32) * (1 - t[..., None]) + np.array(bottom, np.float32) * t[..., None]
        # połysk: jaśniejszy lewy-górny brzeg kształtu
        blur = np.asarray(m.filter(ImageFilter.GaussianBlur(S * 5)), np.float32) / 255
        gy, gx = np.gradient(blur)
        light = np.clip(-gx * 22 - gy * 26, -0.6, 1.0)
        col = col * (1 + light[..., None] * shine)
        layer = np.dstack([np.clip(col, 0, 255), mask * 255]).astype(np.uint8)
        L = Image.fromarray(layer, 'RGBA')
        if glow:
            g = m.filter(ImageFilter.GaussianBlur(S * 7))
            ga = np.asarray(g, np.float32) / 255 * 0.85
            gl = Image.fromarray(np.dstack([np.full((W, W, 3), glow, np.float32), ga * 255]).astype(np.uint8), 'RGBA')
            self.img = Image.alpha_composite(self.img, gl)
        if outline and int(ow * S) > 0:
            dil = m.filter(ImageFilter.MaxFilter(int(ow * S) * 2 + 1))
            oa = np.asarray(dil, np.float32) / 255
            ol = Image.fromarray(np.dstack([np.full((W, W, 3), outline, np.float32), oa * 255]).astype(np.uint8), 'RGBA')
            self.img = Image.alpha_composite(self.img, ol)
        self.img = Image.alpha_composite(self.img, L)

    def save(self, name):
        os.makedirs(OUT, exist_ok=True)
        # cień pod ikoną
        a = self.img.split()[3].filter(ImageFilter.GaussianBlur(S * 3))
        sh = Image.new('RGBA', (W, W), (0, 0, 0, 0))
        sh.putalpha(a.point(lambda v: int(v * 0.45)))
        base = Image.new('RGBA', (W, W), (0, 0, 0, 0))
        base.paste(sh, (S * 2, S * 4), sh)
        out = Image.alpha_composite(base, self.img).resize((128, 128), Image.LANCZOS)
        out.save(os.path.join(OUT, name + '.png'))
        print(name)


GOLD = ((255, 226, 120), (176, 104, 28))
SILVER = ((235, 240, 248), (110, 118, 132))
IRON = ((150, 150, 160), (60, 60, 70))
STONE = ((150, 140, 130), (70, 62, 58))
WOOD = ((150, 96, 52), (78, 44, 22))
RED = ((255, 110, 90), (150, 20, 25))
BLUE = ((150, 230, 255), (30, 90, 200))
PURPLE = ((230, 160, 255), (100, 40, 170))
GREEN = ((170, 255, 160), (30, 130, 60))
BONE = ((255, 250, 235), (190, 176, 140))
EMBER = ((255, 230, 140), (255, 90, 20))


def poly(pts):
    return lambda d, f: d.polygon(P(pts), fill=f)


def ell(x0, y0, x1, y1):
    return lambda d, f: d.ellipse(P([(x0, y0), (x1, y1)]), fill=f)


def rect(x0, y0, x1, y1, r=0.0):
    return lambda d, f: d.rounded_rectangle(P([(x0, y0), (x1, y1)]), radius=r * W, fill=f)


def multi(*fns):
    def f(d, fill):
        for fn in fns:
            fn(d, fill)
    return f


def gem(ic, cx, cy, r, col):
    ic.shape(poly([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]), col[0], col[1], ow=2, shine=0.8, glow=col[1])


# --- tryby ------------------------------------------------------------------------

def dungeon():
    ic = Icon()
    # kamienny łuk z bramą
    ic.shape(multi(rect(0.14, 0.3, 0.86, 0.92, 0.02), ell(0.14, 0.1, 0.86, 0.6)), *STONE)
    ic.shape(multi(rect(0.3, 0.42, 0.7, 0.92), ell(0.3, 0.24, 0.7, 0.62)), (255, 200, 90), (200, 60, 10), outline=None, glow=(255, 120, 30))
    for x in (0.36, 0.45, 0.55, 0.64):
        ic.shape(rect(x - 0.018, 0.26 if 0.4 < x < 0.6 else 0.32, x + 0.018, 0.92), *IRON, ow=1.5)
    ic.shape(rect(0.29, 0.55, 0.71, 0.59), *IRON, ow=1.5)
    # cegły
    for (x, y) in [(0.16, 0.5), (0.16, 0.7), (0.74, 0.6), (0.74, 0.8)]:
        ic.shape(rect(x, y, x + 0.1, y + 0.08, 0.01), (120, 110, 100), (80, 72, 66), ow=1.2, shine=0.1)
    ic.save('dungeon')


def arena():
    ic = Icon()
    ic.shape(ell(0.22, 0.24, 0.78, 0.8), *RED)
    ic.shape(ell(0.3, 0.32, 0.7, 0.72), (190, 40, 40), (110, 15, 20), ow=0)
    ic.shape(ell(0.42, 0.44, 0.58, 0.6), *GOLD)
    for flip in (1, -1):
        def blade(d, f, flip=flip):
            pts = [(0.14, 0.18), (0.22, 0.14), (0.78, 0.7), (0.72, 0.76)]
            if flip < 0:
                pts = [(1 - x, y) for x, y in pts]
            d.polygon(P(pts), fill=f)
        ic.shape(blade, *SILVER, ow=2.5, shine=0.6)
        gx = [(0.66, 0.84), (0.84, 0.66)]
        if flip < 0:
            gx = [(1 - x, y) for x, y in gx]
        ic.shape(lambda d, f, gx=gx: d.line(P(gx), fill=f, width=int(0.06 * W)), *GOLD, ow=2)
        hx = (0.82, 0.82) if flip > 0 else (0.18, 0.82)
        ic.shape(ell(hx[0] - 0.05, hx[1] - 0.05, hx[0] + 0.05, hx[1] + 0.05), *WOOD, ow=2)
    ic.save('arena')


def crown_shape(x0=0.16, x1=0.84, y0=0.24, y1=0.74):
    w = x1 - x0
    pts = [(x0, y1), (x0, y0 + 0.14), (x0 + w * 0.22, y0 + 0.3), (x0 + w * 0.5, y0), (x0 + w * 0.78, y0 + 0.3), (x1, y0 + 0.14), (x1, y1)]
    return poly(pts)


def relics_icon():
    ic = Icon()
    ic.shape(crown_shape(), *GOLD, shine=0.6, glow=(255, 180, 60))
    ic.shape(rect(0.16, 0.66, 0.84, 0.78, 0.02), (255, 210, 110), (150, 90, 20))
    gem(ic, 0.5, 0.52, 0.07, RED)
    gem(ic, 0.3, 0.6, 0.05, BLUE)
    gem(ic, 0.7, 0.6, 0.05, GREEN)
    ic.save('relics')


def key():
    ic = Icon()
    ic.shape(multi(ell(0.14, 0.14, 0.46, 0.46), lambda d, f: d.line(P([(0.36, 0.36), (0.84, 0.84)]), fill=f, width=int(0.09 * W)),
                   lambda d, f: d.line(P([(0.66, 0.66), (0.78, 0.54)]), fill=f, width=int(0.08 * W)),
                   lambda d, f: d.line(P([(0.76, 0.76), (0.88, 0.64)]), fill=f, width=int(0.08 * W))), *GOLD, shine=0.6)
    ic.shape(ell(0.23, 0.23, 0.37, 0.37), (60, 40, 20), (30, 20, 10), ow=0)
    ic.save('key')


def badge():
    ic = Icon()
    ic.shape(poly([(0.3, 0.06), (0.44, 0.06), (0.5, 0.36), (0.56, 0.06), (0.7, 0.06), (0.6, 0.4), (0.4, 0.4)]), *RED, ow=2)
    ic.shape(ell(0.2, 0.3, 0.8, 0.9), *SILVER, shine=0.6)
    ic.shape(ell(0.3, 0.4, 0.7, 0.8), (210, 216, 228), (130, 136, 150), ow=1.5)
    ic.shape(poly([(0.5, 0.45), (0.555, 0.565), (0.68, 0.575), (0.585, 0.655), (0.615, 0.78), (0.5, 0.71), (0.385, 0.78), (0.415, 0.655), (0.32, 0.575), (0.445, 0.565)]), *GOLD, ow=1.5, shine=0.7)
    ic.save('badge')


def shard():
    ic = Icon()
    ic.shape(poly([(0.5, 0.06), (0.7, 0.36), (0.6, 0.94), (0.36, 0.7), (0.3, 0.3)]), *PURPLE, shine=0.9, glow=(170, 80, 255))
    ic.shape(poly([(0.5, 0.06), (0.52, 0.5), (0.36, 0.7), (0.3, 0.3)]), (250, 220, 255), (170, 110, 230), ow=0, shine=0.4)
    ic.save('shard')


# --- relikwie -----------------------------------------------------------------------

def r_crown():
    ic = Icon()
    ic.shape(crown_shape(0.12, 0.88, 0.2, 0.76), *GOLD, shine=0.6, glow=(255, 200, 80))
    for i, c in enumerate([RED, BLUE, GREEN, PURPLE, RED]):
        gem(ic, 0.2 + i * 0.15, 0.66, 0.045, c)
    ic.save('relic_crown')


def r_scepter():
    ic = Icon()
    ic.shape(lambda d, f: d.line(P([(0.25, 0.85), (0.62, 0.38)]), fill=f, width=int(0.07 * W)), *GOLD)
    ic.shape(ell(0.52, 0.14, 0.86, 0.48), *RED, shine=0.8, glow=(255, 60, 40))
    ic.shape(poly([(0.5, 0.42), (0.6, 0.32), (0.68, 0.4), (0.58, 0.5)]), *GOLD)
    ic.save('relic_scepter')


def r_signet():
    ic = Icon()
    ic.shape(ell(0.16, 0.3, 0.84, 0.92), *GOLD, shine=0.5)
    ic.shape(ell(0.28, 0.42, 0.72, 0.84), (40, 26, 12), (20, 12, 6), outline=None)
    ic.shape(ell(0.3, 0.08, 0.7, 0.44), *GOLD)
    ic.shape(ell(0.36, 0.14, 0.64, 0.38), *PURPLE, ow=1.5, glow=(170, 90, 255))
    ic.save('relic_signet')


def r_fang():
    ic = Icon()
    ic.shape(poly([(0.3, 0.12), (0.72, 0.14), (0.62, 0.5), (0.44, 0.92), (0.4, 0.5)]), *BONE, shine=0.6)
    ic.shape(poly([(0.42, 0.55), (0.62, 0.52), (0.44, 0.92)]), (255, 200, 120), (255, 90, 30), ow=0, glow=(255, 120, 30))
    ic.save('relic_fang')


def r_scale():
    ic = Icon()
    ic.shape(poly([(0.5, 0.08), (0.86, 0.3), (0.78, 0.72), (0.5, 0.94), (0.22, 0.72), (0.14, 0.3)]), (255, 120, 60), (120, 20, 15), shine=0.6, glow=(255, 80, 30))
    for y in (0.36, 0.56):
        ic.shape(lambda d, f, y=y: d.arc(P([(0.28, y - 0.12), (0.72, y + 0.12)]), 20, 160, fill=f, width=int(0.035 * W)), (255, 200, 120), (200, 100, 40), ow=1)
    ic.save('relic_scale')


def r_eye():
    ic = Icon()
    ic.shape(poly([(0.06, 0.5), (0.3, 0.28), (0.7, 0.28), (0.94, 0.5), (0.7, 0.72), (0.3, 0.72)]), *EMBER, shine=0.5, glow=(255, 120, 30))
    ic.shape(ell(0.36, 0.3, 0.64, 0.7), (255, 240, 120), (240, 120, 20), ow=1.5)
    ic.shape(rect(0.47, 0.32, 0.53, 0.68, 0.03), (20, 10, 5), (10, 5, 0), outline=None)
    ic.save('relic_eye')


def r_compass():
    ic = Icon()
    ic.shape(ell(0.14, 0.14, 0.86, 0.86), *GOLD)
    ic.shape(ell(0.22, 0.22, 0.78, 0.78), (250, 240, 215), (200, 186, 150), ow=1.5)
    ic.shape(poly([(0.5, 0.24), (0.57, 0.5), (0.5, 0.5)]), *RED, ow=1)
    ic.shape(poly([(0.5, 0.24), (0.43, 0.5), (0.5, 0.5)]), (200, 40, 40), (120, 10, 10), ow=1)
    ic.shape(poly([(0.5, 0.76), (0.57, 0.5), (0.43, 0.5)]), *IRON, ow=1)
    ic.save('relic_compass')


def r_hourglass():
    ic = Icon()
    ic.shape(rect(0.22, 0.1, 0.78, 0.18, 0.02), *WOOD)
    ic.shape(rect(0.22, 0.82, 0.78, 0.9, 0.02), *WOOD)
    ic.shape(poly([(0.28, 0.18), (0.72, 0.18), (0.54, 0.5), (0.72, 0.82), (0.28, 0.82), (0.46, 0.5)]), (220, 245, 255), (140, 190, 220), ow=2, shine=0.7)
    ic.shape(poly([(0.36, 0.82), (0.64, 0.82), (0.5, 0.64)]), *GOLD, ow=0, glow=(255, 200, 80))
    ic.shape(poly([(0.36, 0.26), (0.64, 0.26), (0.5, 0.45)]), *GOLD, ow=0)
    ic.save('relic_hourglass')


def r_lantern():
    ic = Icon()
    ic.shape(lambda d, f: d.arc(P([(0.36, 0.04), (0.64, 0.3)]), 180, 360, fill=f, width=int(0.04 * W)), *IRON, ow=1.5)
    ic.shape(rect(0.28, 0.2, 0.72, 0.28, 0.02), *IRON)
    ic.shape(rect(0.3, 0.28, 0.7, 0.8, 0.04), (255, 240, 160), (255, 140, 30), glow=(255, 180, 60))
    ic.shape(ell(0.42, 0.42, 0.58, 0.66), (255, 255, 230), (255, 200, 80), outline=None)
    ic.shape(rect(0.26, 0.8, 0.74, 0.9, 0.02), *IRON)
    for x in (0.3, 0.68):
        ic.shape(rect(x, 0.28, x + 0.03, 0.8), *IRON, ow=1)
    ic.save('relic_lantern')


def r_tear():
    ic = Icon()
    ic.shape(multi(ell(0.24, 0.36, 0.76, 0.9), poly([(0.5, 0.06), (0.74, 0.56), (0.26, 0.56)])), *BLUE, shine=0.9, glow=(80, 180, 255))
    ic.shape(ell(0.34, 0.5, 0.46, 0.66), (255, 255, 255), (200, 240, 255), outline=None)
    ic.save('relic_tear')


def r_horn():
    ic = Icon()
    ic.shape(lambda d, f: d.pieslice(P([(0.1, 0.12), (0.9, 0.92)]), 200, 340, fill=f), (0, 0, 0), (0, 0, 0), outline=None, shine=0)
    ic.img = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    ic.shape(poly([(0.12, 0.3), (0.24, 0.2), (0.6, 0.48), (0.86, 0.6), (0.9, 0.82), (0.66, 0.84), (0.46, 0.62)]), *BONE, shine=0.5)
    ic.shape(poly([(0.66, 0.84), (0.9, 0.82), (0.86, 0.6)]), *BLUE, ow=2, glow=(120, 200, 255))
    for t in (0.35, 0.55):
        x, y = 0.12 + t * 0.7, 0.25 + t * 0.55
        ic.shape(lambda d, f, x=x, y=y: d.line(P([(x - 0.06, y + 0.07), (x + 0.07, y - 0.06)]), fill=f, width=int(0.04 * W)), *SILVER, ow=1)
    ic.save('relic_horn')


def r_heart():
    ic = Icon()
    ic.shape(multi(ell(0.14, 0.18, 0.52, 0.56), ell(0.48, 0.18, 0.86, 0.56), poly([(0.16, 0.44), (0.84, 0.44), (0.5, 0.9)])), (210, 245, 255), (60, 130, 220), shine=0.9, glow=(120, 200, 255))
    ic.shape(poly([(0.32, 0.3), (0.42, 0.26), (0.38, 0.44)]), (255, 255, 255), (220, 240, 255), outline=None)
    ic.save('relic_heart')


if __name__ == '__main__':
    for fn in (dungeon, arena, relics_icon, key, badge, shard, r_crown, r_scepter, r_signet, r_fang, r_scale, r_eye,
               r_compass, r_hourglass, r_lantern, r_tear, r_horn, r_heart):
        fn()
