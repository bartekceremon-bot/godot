#!/usr/bin/env python3
"""
Logo „POPIELNE KRÓLESTWA” do ekranu tytułowego: złoto kute w ogniu – metaliczny gradient,
faza (bevel), ciemny kontur, żarząca się poświata, pęknięcia z żarem i ornament.
-> client/assets/ui/logo.png

Użycie: python3 tools/textures/gen_logo.py  (numpy, pillow; czcionka assets/fonts/CinzelDecorative-Bold.ttf)
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(__file__)
FONT = os.path.join(HERE, '..', '..', 'assets', 'fonts', 'CinzelDecorative-Bold.ttf')
OUT = os.path.join(HERE, '..', '..', 'assets', 'ui', 'logo.png')
W, H = 1000, 470


def text_mask(lines):
    m = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(m)
    boxes = []
    for text, size, y in lines:
        f = ImageFont.truetype(FONT, size)
        bb = d.textbbox((0, 0), text, font=f)
        x = (W - (bb[2] - bb[0])) / 2 - bb[0]
        d.text((x, y), text, font=f, fill=255)
        boxes.append(d.textbbox((x, y), text, font=f))
    return m, boxes


def main():
    lines = [('POPIELNE', 118, 40), ('KRÓLESTWA', 132, 190)]
    mask, boxes = text_mask(lines)
    a = np.asarray(mask, dtype=np.float32) / 255.0
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

    # t = położenie w wysokości wiersza liter (0 u góry, 1 u dołu).
    t = np.zeros((H, W), dtype=np.float32)
    for bb in boxes:
        top, bot = bb[1], bb[3]
        rows = (yy >= top - 20) & (yy <= bot + 20)
        t[rows] = np.clip((yy[rows] - top) / max(1, bot - top), 0, 1)
    # Kute złoto: kremowy szczyt, złoto, ostra linia horyzontu (refleks), brąz i żar u dołu.
    stops = [(0.0, (1.0, 0.97, 0.84)), (0.38, (0.98, 0.8, 0.42)), (0.5, (0.72, 0.42, 0.12)),
             (0.53, (1.0, 0.86, 0.55)), (0.8, (0.86, 0.46, 0.14)), (1.0, (0.6, 0.18, 0.05))]
    col = np.zeros((H, W, 3), dtype=np.float32)
    for (t0, c0), (t1, c1) in zip(stops[:-1], stops[1:]):
        k = np.clip((t - t0) / (t1 - t0), 0, 1)[..., None]
        seg = ((t >= t0) & (t <= t1))[..., None]
        col = np.where(seg, np.array(c0) + (np.array(c1) - np.array(c0)) * k, col)

    # Faza: oświetlenie z góry-lewej na podstawie gradientu rozmytej maski.
    blur = np.asarray(mask.filter(ImageFilter.GaussianBlur(3)), dtype=np.float32) / 255.0
    gy, gx = np.gradient(blur)
    light = np.clip((-gx * 0.6 - gy * 1.0) * 9.0, -1, 1)[..., None]
    col = np.clip(col + light * 0.35, 0, 1)

    # Pęknięcia z żarem (drobny szum w literach).
    rng = np.random.default_rng(7)
    crack = Image.new('L', (W, H), 0)
    cd = ImageDraw.Draw(crack)
    for _ in range(70):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        pts = [(x, y)]
        for _ in range(4):
            x += rng.uniform(-14, 14)
            y += rng.uniform(4, 14)
            pts.append((x, y))
        cd.line(pts, fill=255, width=2)
    ck = (np.asarray(crack, dtype=np.float32) / 255.0) * a * np.clip((t - 0.35) * 2.0, 0, 1)
    col = col * (1 - ck[..., None]) + np.array([1.0, 0.62, 0.2]) * ck[..., None]

    # Warstwy: poświata, kontur, litery.
    glow = mask.filter(ImageFilter.GaussianBlur(22))
    g = np.asarray(glow, dtype=np.float32) / 255.0
    outline = np.asarray(mask.filter(ImageFilter.MaxFilter(9)), dtype=np.float32) / 255.0

    rgba = np.zeros((H, W, 4), dtype=np.float32)
    rgba[..., :3] = np.array([1.0, 0.38, 0.08])
    rgba[..., 3] = np.clip(g * 1.6, 0, 1) * 0.85
    # Kontur.
    ol = outline * (1 - a)
    rgba[..., :3] = rgba[..., :3] * (1 - ol[..., None]) + np.array([0.12, 0.05, 0.03]) * ol[..., None]
    rgba[..., 3] = np.maximum(rgba[..., 3], ol)
    # Litery.
    rgba[..., :3] = rgba[..., :3] * (1 - a[..., None]) + col * a[..., None]
    rgba[..., 3] = np.maximum(rgba[..., 3], a)

    img = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), 'RGBA')

    # Ornament: linia z rombem między słowami i pod napisem.
    d = ImageDraw.Draw(img)
    for y, half in ((178, 330), (372, 250)):
        cx = W / 2
        for s, alpha in ((5, 70), (2, 255)):
            d.line([(cx - half, y), (cx - 26, y)], fill=(240, 190, 110, alpha), width=s)
            d.line([(cx + 26, y), (cx + half, y)], fill=(240, 190, 110, alpha), width=s)
        d.polygon([(cx, y - 13), (cx + 13, y), (cx, y + 13), (cx - 13, y)], fill=(255, 150, 60, 255), outline=(60, 20, 8, 255))
        for sx in (-1, 1):
            d.ellipse([cx + sx * half - 5, y - 5, cx + sx * half + 5, y + 5], fill=(240, 190, 110, 255))
    img.save(OUT, optimize=True)
    print('logo ->', os.path.abspath(OUT), img.size)


if __name__ == '__main__':
    main()
