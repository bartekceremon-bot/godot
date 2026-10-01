#!/usr/bin/env python3
"""Ikony wydarzeń (4.6, assets/ui/modes/*.png, 128 px): Płomyk Dusz (Noc Dusz)."""
from gen_mode_icons import Icon, poly, ell, multi, P, W


def soul_flame():
    ic = Icon()
    # świeca-dynia z upiornym płomieniem
    ic.shape(multi(ell(0.16, 0.5, 0.56, 0.92), ell(0.44, 0.5, 0.84, 0.92), ell(0.3, 0.46, 0.7, 0.94)), (255, 170, 70), (190, 80, 20), shine=0.6)
    ic.shape(poly([(0.46, 0.5), (0.5, 0.38), (0.56, 0.4), (0.54, 0.5)]), (120, 170, 80), (50, 90, 30), ow=1.5)
    ic.shape(multi(poly([(0.3, 0.64), (0.4, 0.6), (0.38, 0.7)]), poly([(0.6, 0.6), (0.7, 0.64), (0.62, 0.7)]),
                   poly([(0.32, 0.78), (0.68, 0.78), (0.6, 0.84), (0.5, 0.8), (0.4, 0.84)])), (255, 250, 200), (255, 200, 80), outline=None, glow=(255, 200, 80))
    ic.shape(poly([(0.5, 0.04), (0.64, 0.22), (0.6, 0.36), (0.5, 0.42), (0.4, 0.36), (0.36, 0.22), (0.46, 0.14)]), (200, 240, 255), (110, 80, 255), outline=None, glow=(150, 120, 255))
    ic.save('soul_flame')


if __name__ == '__main__':
    soul_flame()
