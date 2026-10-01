#!/usr/bin/env python3
"""Ikony smoczego towarzysza (4.3, assets/ui/modes/*.png, 128 px): jajo Żarogniewa i smok."""
from gen_mode_icons import Icon, poly, ell, rect, multi, P, W, EMBER, RED, GOLD

SCALE_TOP = (255, 150, 90)
SCALE_BOT = (150, 30, 20)


def line(x0, y0, x1, y1, w):
    return lambda d, f: d.line(P([(x0, y0), (x1, y1)]), fill=f, width=int(w * W))


def egg():
    ic = Icon()
    ic.shape(ell(0.22, 0.1, 0.78, 0.92), (120, 60, 50), (40, 18, 16), shine=0.7, glow=(255, 110, 40))
    # łuski i pęknięcia żaru
    for (x, y) in [(0.35, 0.35), (0.55, 0.3), (0.45, 0.55), (0.62, 0.6), (0.33, 0.72)]:
        ic.shape(ell(x - 0.06, y - 0.04, x + 0.06, y + 0.04), (170, 90, 70), (90, 40, 30), ow=1.5, shine=0.4)
    ic.shape(poly([(0.42, 0.2), (0.47, 0.34), (0.41, 0.46), (0.5, 0.6), (0.46, 0.64), (0.36, 0.47), (0.42, 0.34), (0.38, 0.22)]), *EMBER, outline=None, glow=(255, 140, 40))
    ic.shape(poly([(0.6, 0.62), (0.66, 0.74), (0.6, 0.86), (0.57, 0.85), (0.62, 0.74), (0.57, 0.64)]), *EMBER, outline=None, glow=(255, 140, 40))
    ic.save('dragon_egg')


def dragon():
    ic = Icon()
    # skrzydło
    ic.shape(poly([(0.5, 0.42), (0.92, 0.1), (0.86, 0.36), (0.96, 0.4), (0.82, 0.56), (0.58, 0.6)]), (200, 80, 60), (90, 20, 20), shine=0.4)
    # szyja i głowa
    ic.shape(poly([(0.3, 0.92), (0.44, 0.52), (0.36, 0.3), (0.5, 0.2), (0.6, 0.34), (0.6, 0.6), (0.52, 0.92)]), SCALE_TOP, SCALE_BOT, shine=0.6)
    ic.shape(poly([(0.36, 0.3), (0.12, 0.36), (0.08, 0.46), (0.3, 0.46), (0.44, 0.4)]), SCALE_TOP, SCALE_BOT, shine=0.6)
    # rogi
    ic.shape(poly([(0.44, 0.22), (0.52, 0.04), (0.52, 0.22)]), (255, 240, 210), (170, 150, 120), ow=2)
    ic.shape(poly([(0.52, 0.24), (0.66, 0.08), (0.6, 0.28)]), (255, 240, 210), (170, 150, 120), ow=2)
    # oko
    ic.shape(ell(0.35, 0.3, 0.43, 0.36), (255, 250, 150), (255, 170, 30), ow=1.5, glow=(255, 200, 60))
    # płomień z pyska
    ic.shape(poly([(0.1, 0.42), (0.02, 0.56), (0.12, 0.52), (0.06, 0.7), (0.2, 0.52), (0.16, 0.46)]), *EMBER, outline=None, glow=(255, 120, 30))
    # brzuch
    ic.shape(poly([(0.46, 0.6), (0.56, 0.6), (0.5, 0.92), (0.4, 0.92)]), (255, 220, 150), (210, 150, 80), ow=1.5)
    ic.save('dragon')


if __name__ == '__main__':
    egg()
    dragon()
