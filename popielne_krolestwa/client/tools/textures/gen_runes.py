#!/usr/bin/env python3
"""Ikony run (assets/ui/runes/<rodzaj>.png, 128 px): kamienna tabliczka z żarzącym się znakiem."""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'ui', 'runes')
S = 3
W = 128 * S
# Znaki w stylu futharku: odcinki w układzie 0..1.
GLYPHS = {
    'fire': [((0.72, 0.15), (0.3, 0.5)), ((0.3, 0.5), (0.72, 0.85)), ((0.5, 0.5), (0.72, 0.5))],
    'blood': [((0.5, 0.15), (0.5, 0.85)), ((0.5, 0.45), (0.25, 0.2)), ((0.5, 0.45), (0.75, 0.2))],
    'ember': [((0.3, 0.15), (0.6, 0.4)), ((0.6, 0.4), (0.35, 0.6)), ((0.35, 0.6), (0.7, 0.85))],
    'gold': [((0.38, 0.15), (0.38, 0.85)), ((0.38, 0.35), (0.7, 0.2)), ((0.38, 0.55), (0.7, 0.4))],
    'mind': [((0.3, 0.15), (0.3, 0.85)), ((0.7, 0.15), (0.7, 0.85)), ((0.3, 0.2), (0.7, 0.55)), ((0.7, 0.2), (0.3, 0.55))],
    'wind': [((0.5, 0.12), (0.5, 0.88)), ((0.5, 0.12), (0.72, 0.32)), ((0.5, 0.88), (0.28, 0.68))],
}
COLORS = {'fire': (255, 110, 40), 'blood': (230, 30, 50), 'ember': (255, 180, 50), 'gold': (255, 220, 80), 'mind': (160, 120, 255), 'wind': (110, 230, 255)}


def stone():
    rng = np.random.default_rng(3)
    m = Image.new('L', (W, W), 0)
    d = ImageDraw.Draw(m)
    d.polygon([(W * 0.2, W * 0.08), (W * 0.8, W * 0.06), (W * 0.9, W * 0.5), (W * 0.82, W * 0.93), (W * 0.18, W * 0.95), (W * 0.1, W * 0.5)], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(S * 1.5))
    noise = np.asarray(Image.fromarray((rng.random((32, 32)) * 255).astype(np.uint8)).resize((W, W), Image.BICUBIC), np.float32) / 255
    g = 0.28 + noise * 0.12
    ma = np.asarray(m, np.float32) / 255
    gy, gx = np.gradient(np.asarray(m.filter(ImageFilter.GaussianBlur(S * 4)), np.float32) / 255)
    g = g * (1 + np.clip(-gx * 10 - gy * 14, -0.5, 0.6))
    return np.dstack([g * 0.95, g * 0.93, g * 1.0]), ma


def main():
    os.makedirs(OUT, exist_ok=True)
    base, alpha = stone()
    for name, segs in GLYPHS.items():
        col = np.array(COLORS[name], np.float32) / 255
        line = Image.new('L', (W, W), 0)
        d = ImageDraw.Draw(line)
        for (a, b) in segs:
            d.line([(a[0] * W * 0.7 + W * 0.15, a[1] * W * 0.7 + W * 0.15), (b[0] * W * 0.7 + W * 0.15, b[1] * W * 0.7 + W * 0.15)], fill=255, width=7 * S)
        core = np.asarray(line, np.float32) / 255
        glow = np.asarray(line.filter(ImageFilter.GaussianBlur(9 * S)), np.float32) / 255
        rgb = base.copy()
        rgb = rgb * (1 - np.clip(glow * 1.5, 0, 0.8)[..., None]) + col * np.clip(glow * 1.6, 0, 1)[..., None] * 0.9
        rgb = rgb * (1 - core[..., None]) + (col * 0.5 + 0.5) * core[..., None]
        a = np.clip(alpha + glow * 0.0, 0, 1)
        img = Image.fromarray((np.clip(np.dstack([rgb, a]), 0, 1) * 255).astype(np.uint8), 'RGBA').resize((128, 128), Image.LANCZOS)
        img.save(os.path.join(OUT, name + '.png'))
        print(name)


if __name__ == '__main__':
    main()
