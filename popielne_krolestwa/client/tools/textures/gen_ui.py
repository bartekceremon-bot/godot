#!/usr/bin/env python3
"""
Grafiki interfejsu w stylu dark fantasy (wygładzane, 9-patch):
  panel.png (128, margines 32), button_*.png (64, margines 20), slot.png (64, margines 16),
  bar_*.png (48x24, margines 8), frame_round.png (ramka minimapy/portretu), hotbar.png,
  icon_*.png (ikony HUD 96x96), joystick_base.png, joystick_knob.png
-> client/assets/ui/

Użycie:  python3 tools/textures/gen_ui.py   (wymaga numpy i pillow; korzysta z gen_icons.py)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
import gen_icons as gi  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'ui')
GOLD_HI = np.array([0.98, 0.84, 0.5])
GOLD = np.array([0.78, 0.58, 0.28])
GOLD_LO = np.array([0.36, 0.24, 0.1])
BG_TOP = np.array([0.1, 0.105, 0.13])
BG_BOT = np.array([0.045, 0.05, 0.065])


def noise(w, h, scale, seed):
    r = np.random.default_rng(seed)
    n = r.random((int(h / scale) + 2, int(w / scale) + 2)).astype(np.float32)
    im = Image.fromarray((n * 255).astype(np.uint8), 'L').resize((w, h), Image.BICUBIC)
    return np.asarray(im, np.float32) / 255


def rrect_mask(w, h, inset, radius, ss=4):
    im = Image.new('L', (w * ss, h * ss), 0)
    ImageDraw.Draw(im).rounded_rectangle([inset * ss, inset * ss, (w - inset) * ss - 1, (h - inset) * ss - 1], radius=radius * ss, fill=255)
    return np.asarray(im.resize((w, h), Image.LANCZOS), np.float32) / 255


def compose(layers, w, h):
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    for mask, col in layers:
        m = np.clip(mask, 0, 1)
        c = col if col.ndim == 3 else np.broadcast_to(col, (h, w, 3))
        rgb = rgb * (1 - m[..., None]) + c * m[..., None]
        a = a + m * (1 - a)
    return Image.fromarray((np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)]) * 255).astype(np.uint8), 'RGBA')


def vgrad(h, w, top, bot):
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    return np.broadcast_to(top * (1 - t) + bot * t, (h, w, 3)).astype(np.float32)


def bevel_color(h, w, hi, mid, lo):
    """Złoty bevel: jaśniejszy u góry/lewej, ciemniejszy u dołu/prawej."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip((xx / w + yy / h) / 2, 0, 1)[..., None]
    c = np.where(t < 0.5, hi * (1 - t * 2) + mid * t * 2, mid * (1 - (t - 0.5) * 2) + lo * (t - 0.5) * 2)
    return c.astype(np.float32)


def frame_layers(w, h, radius, border, bg_top, bg_bot, gold_scale=1.0, seed=1, inner_line=True):
    outer = rrect_mask(w, h, 0, radius)
    gold_m = rrect_mask(w, h, 1, radius)
    dark_m = rrect_mask(w, h, 1 + border, max(radius - border, 1))
    inner = rrect_mask(w, h, 2 + border, max(radius - border - 1, 1))
    n = noise(w, h, 6, seed)
    bg = vgrad(h, w, bg_top, bg_bot) * (0.9 + n[..., None] * 0.2)
    layers = [
        (outer, np.array([0.02, 0.02, 0.03])),
        (gold_m, bevel_color(h, w, GOLD_HI * gold_scale, GOLD * gold_scale, GOLD_LO * gold_scale)),
        (dark_m, np.array([0.03, 0.03, 0.04])),
        (inner, bg),
    ]
    if inner_line:
        li = rrect_mask(w, h, border + 5, max(radius - border - 4, 1)) - rrect_mask(w, h, border + 6, max(radius - border - 5, 1))
        layers.append((np.clip(li, 0, 1) * 0.55, GOLD * 0.9))
    # Delikatny połysk u góry.
    yy = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    shine = inner * np.clip(1 - yy / 0.3, 0, 1) * 0.08
    layers.append((shine, np.array([1.0, 1.0, 1.0])))
    return layers


def corner_ornaments(img, size, col=(236, 196, 120, 255)):
    """Złote narożniki z rombem (w rogach panelu)."""
    ss = 4
    w, h = img.size
    over = Image.new('RGBA', (w * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for cx, cy, sx, sy in [(0, 0, 1, 1), (w, 0, -1, 1), (0, h, 1, -1), (w, h, -1, -1)]:
        x, y = cx * ss, cy * ss
        s = size * ss
        d.line([(x + sx * 6 * ss, y + sy * (s)), (x + sx * 6 * ss, y + sy * 6 * ss), (x + sx * s, y + sy * 6 * ss)], fill=col, width=3 * ss)
        r = 5 * ss
        px, py = x + sx * 6 * ss, y + sy * 6 * ss
        d.polygon([(px, py - r), (px + r, py), (px, py + r), (px - r, py)], fill=col, outline=(40, 25, 10, 255))
    over = over.resize((w, h), Image.LANCZOS)
    img.alpha_composite(over)
    return img


def panel():
    w = h = 128
    img = compose(frame_layers(w, h, 10, 4, BG_TOP, BG_BOT, seed=3), w, h)
    return corner_ornaments(img, 26)


def button(state):
    w = h = 64
    if state == 'normal':
        top, bot, g = np.array([0.19, 0.2, 0.24]), np.array([0.08, 0.085, 0.1]), 0.85
    elif state == 'hover':
        top, bot, g = np.array([0.26, 0.27, 0.32]), np.array([0.11, 0.115, 0.14]), 1.1
    elif state == 'pressed':
        top, bot, g = np.array([0.06, 0.065, 0.08]), np.array([0.16, 0.17, 0.2]), 1.15
    else:
        top, bot, g = np.array([0.13, 0.13, 0.14]), np.array([0.08, 0.08, 0.09]), 0.45
    return compose(frame_layers(w, h, 8, 3, top, bot, gold_scale=g, seed=5, inner_line=False), w, h)


def slot():
    w = h = 64
    outer = rrect_mask(w, h, 0, 6)
    ring = rrect_mask(w, h, 1, 6)
    inner = rrect_mask(w, h, 3, 4)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) / w
    d = np.minimum(np.minimum(xx, 1 - xx), np.minimum(yy, 1 - yy))
    shadow = np.clip(1 - d / 0.18, 0, 1)
    bg = np.broadcast_to(np.array([0.05, 0.055, 0.07]), (h, w, 3)) * (1 - shadow[..., None] * 0.6) + np.array([0.0, 0.0, 0.0]) * shadow[..., None] * 0.6
    layers = [(outer, np.array([0.01, 0.01, 0.02])), (ring, bevel_color(h, w, np.array([0.5, 0.52, 0.58]), np.array([0.3, 0.31, 0.36]), np.array([0.14, 0.15, 0.18]))),
              (inner, bg.astype(np.float32))]
    return compose(layers, w, h)


def bar(kind):
    w, h = 48, 24
    outer = rrect_mask(w, h, 0, 6)
    inner = rrect_mask(w, h, 2, 4)
    if kind == 'bg':
        return compose([(outer, np.array([0.02, 0.02, 0.03])), (rrect_mask(w, h, 1, 5), np.array([0.25, 0.2, 0.12])),
                        (inner, vgrad(h, w, np.array([0.03, 0.03, 0.04]), np.array([0.09, 0.09, 0.11])))], w, h)
    cols = {'hp': ([0.95, 0.3, 0.25], [0.7, 0.08, 0.06], [0.35, 0.02, 0.02]), 'mp': ([0.45, 0.65, 1.0], [0.12, 0.3, 0.85], [0.04, 0.1, 0.4]),
            'exp': ([1.0, 0.9, 0.5], [0.85, 0.62, 0.18], [0.45, 0.28, 0.05])}[kind]
    t = np.linspace(0, 1, h, dtype=np.float32)
    c = np.array(cols[0]) * np.clip(1 - t * 3, 0, 1)[:, None] + np.array(cols[1]) * np.clip(1 - np.abs(t - 0.4) * 3, 0, 1)[:, None] + np.array(cols[2]) * np.clip((t - 0.4) * 2, 0, 1)[:, None]
    grad_img = np.broadcast_to(c[:, None, :], (h, w, 3)).astype(np.float32)
    shine = np.clip(1 - np.abs(t - 0.22) * 8, 0, 1)[:, None] * inner * 0.35
    return compose([(inner, grad_img), (shine, np.array([1.0, 1.0, 1.0]))], w, h)


def frame_round(size=160):
    """Okrągła złota ramka (minimapa, portret): przezroczysty środek."""
    ss = 4
    s = size * ss
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, s - 1, s - 1], fill=(10, 8, 6, 255))
    d.ellipse([2 * ss, 2 * ss, s - 2 * ss, s - 2 * ss], fill=(200, 155, 80, 255))
    d.ellipse([7 * ss, 7 * ss, s - 7 * ss, s - 7 * ss], fill=(60, 40, 18, 255))
    d.ellipse([9 * ss, 9 * ss, s - 9 * ss, s - 9 * ss], fill=(0, 0, 0, 0))
    # Nity na obręczy.
    for k in range(12):
        a = k / 12 * math.tau
        cx = s / 2 + math.cos(a) * (s / 2 - 4.5 * ss)
        cy = s / 2 + math.sin(a) * (s / 2 - 4.5 * ss)
        r = 2.2 * ss
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(250, 220, 150, 255), outline=(60, 40, 15, 255))
    im = im.resize((size, size), Image.LANCZOS)
    # Bevel: jaśniejsza lewa-górna część obręczy.
    a = np.asarray(im).astype(np.float32) / 255
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    light = 1.25 - (xx + yy) * 0.5
    a[..., :3] = np.clip(a[..., :3] * light[..., None], 0, 1)
    return Image.fromarray((a * 255).astype(np.uint8), 'RGBA')


def hotbar():
    w, h = 128, 64
    img = compose(frame_layers(w, h, 12, 4, np.array([0.08, 0.085, 0.1]), np.array([0.03, 0.035, 0.045]), seed=9), w, h)
    return corner_ornaments(img, 18)


def joystick_base():
    s = 256
    ss = 2
    im = Image.new('RGBA', (s * ss, s * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    S = s * ss
    d.ellipse([4, 4, S - 4, S - 4], fill=(8, 9, 12, 150), outline=(200, 155, 80, 220), width=6 * ss)
    d.ellipse([22 * ss, 22 * ss, S - 22 * ss, S - 22 * ss], outline=(200, 155, 80, 90), width=2 * ss)
    for k in range(4):
        a = k * math.pi / 2
        cx, cy = S / 2 + math.cos(a) * S * 0.38, S / 2 + math.sin(a) * S * 0.38
        r = 10 * ss
        pts = [(cx + math.cos(a) * r, cy + math.sin(a) * r), (cx + math.cos(a + 2.3) * r, cy + math.sin(a + 2.3) * r), (cx + math.cos(a - 2.3) * r, cy + math.sin(a - 2.3) * r)]
        d.polygon(pts, fill=(230, 190, 110, 230))
    return im.resize((s, s), Image.LANCZOS)


def joystick_knob():
    s = 128
    cv = np.zeros((s, s, 4), np.float32)
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32) / s
    d = np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2)
    m = np.clip((0.47 - d) * s / 2, 0, 1)
    ring = np.clip((0.47 - d) * s / 2, 0, 1) - np.clip((0.4 - d) * s / 2, 0, 1)
    g = np.clip(1.2 - (xx + yy) * 0.7, 0.3, 1.2)
    base = np.array([0.18, 0.19, 0.23]) * g[..., None]
    col = base * (1 - ring[..., None]) + np.array([0.85, 0.66, 0.34]) * g[..., None] * ring[..., None]
    cv[..., :3] = col
    cv[..., 3] = m * 0.92
    return Image.fromarray((np.clip(cv, 0, 1) * 255).astype(np.uint8), 'RGBA')


# ---------------------------------------------------------------------------
# Ikony HUD (rysowane tą samą techniką co ikony przedmiotów)
# ---------------------------------------------------------------------------

def hud_icon(name):
    cv = gi.Canvas()
    C = gi.C
    if name == 'bag':
        body = gi.rect(0.22, 0.3, 0.78, 0.88, 0.12)
        gi.solid(cv, body, (0.5, 0.34, 0.18), tex=gi.noise(gi.W / 24, 1))
        flap = gi.rect(0.22, 0.28, 0.78, 0.5, 0.1)
        gi.solid(cv, flap, (0.42, 0.28, 0.14))
        gi.solid(cv, gi.line([(0.36, 0.3), (0.4, 0.14), (0.6, 0.14), (0.64, 0.3)], 0.05), (0.3, 0.2, 0.1))
        gi.metal(cv, gi.rect(0.45, 0.44, 0.55, 0.56, 0.02), gi.METAL[5])
    elif name == 'character':
        gi.i_plate_head(cv, 1)
    elif name == 'specs':
        gi.solid(cv, gi.line([(0.2, 0.85), (0.62, 0.35)], 0.06), (0.45, 0.3, 0.16))
        gi.metal(cv, gi.rect(0.5, 0.14, 0.86, 0.34, 0.03), gi.METAL[1])
        gi.solid(cv, gi.line([(0.8, 0.85), (0.38, 0.35)], 0.06), (0.45, 0.3, 0.16))
        gi.metal(cv, gi.line([(0.18, 0.3), (0.34, 0.2), (0.52, 0.22)], 0.05), gi.METAL[3])
    elif name == 'people':
        for cx, s in [(0.36, 1.0), (0.64, 0.9)]:
            gi.solid(cv, gi.ellipse(cx, 0.34, 0.12 * s, 0.13 * s), (0.9, 0.75, 0.6))
            gi.solid(cv, gi.ellipse(cx, 0.78, 0.2 * s, 0.2 * s) * (gi.YY < 0.86), (0.3, 0.4, 0.62) if cx < 0.5 else (0.55, 0.25, 0.2))
    elif name == 'menu':
        g = gi.ellipse(0.5, 0.5, 0.3, 0.3)
        for k in range(8):
            a = k * math.pi / 4
            g = np.clip(g + gi.rect(0.5 + math.cos(a) * 0.33 - 0.07, 0.5 + math.sin(a) * 0.33 - 0.07, 0.5 + math.cos(a) * 0.33 + 0.07, 0.5 + math.sin(a) * 0.33 + 0.07, 0.02), 0, 1)
        g = np.clip(g - gi.ellipse(0.5, 0.5, 0.12, 0.12), 0, 1)
        gi.metal(cv, g, gi.METAL[1])
    elif name == 'chat':
        b = np.clip(gi.rect(0.14, 0.2, 0.86, 0.66, 0.12) + gi.poly([(0.3, 0.6), (0.24, 0.84), (0.46, 0.64)]), 0, 1)
        gi.solid(cv, b, (0.85, 0.82, 0.74))
        for k in range(3):
            cv.paint(gi.ellipse(0.34 + k * 0.16, 0.43, 0.04, 0.04), C((0.25, 0.2, 0.15)))
    elif name == 'attack':
        for flip in (0, 1):
            pts = [(0.18, 0.18), (0.82, 0.82)] if flip else [(0.82, 0.18), (0.18, 0.82)]
            blade = gi.line([pts[0], (pts[0][0] + (pts[1][0] - pts[0][0]) * 0.72, pts[0][1] + (pts[1][1] - pts[0][1]) * 0.72)], 0.07)
            gi.metal(cv, blade, gi.METAL[3])
        for c in [(0.3, 0.7), (0.7, 0.7)]:
            gi.metal(cv, gi.ellipse(c[0], c[1], 0.07, 0.07), gi.METAL[5])
    elif name == 'heal':
        gi.glow(cv, 6, 0.5, 0.5, 0.45)
        cross = np.clip(gi.rect(0.4, 0.16, 0.6, 0.84, 0.04) + gi.rect(0.16, 0.4, 0.84, 0.6, 0.04), 0, 1)
        gi.solid(cv, cross, (0.3, 0.9, 0.35), spec=0.5)
    elif name in ('skull_white', 'skull_red'):
        col = (0.95, 0.93, 0.88) if name == 'skull_white' else (0.9, 0.2, 0.15)
        sk = np.clip(gi.ellipse(0.5, 0.42, 0.3, 0.28) + gi.rect(0.34, 0.5, 0.66, 0.8, 0.06), 0, 1)
        gi.solid(cv, sk, col)
        for x in (0.38, 0.62):
            cv.paint(gi.ellipse(x, 0.46, 0.08, 0.09), C((0.05, 0.03, 0.03)))
        cv.paint(gi.poly([(0.5, 0.56), (0.46, 0.64), (0.54, 0.64)]), C((0.05, 0.03, 0.03)))
    elif name == 'book':
        gi.solid(cv, gi.rect(0.18, 0.14, 0.82, 0.86, 0.04), (0.45, 0.14, 0.12), tex=gi.noise(gi.W / 24, 3))
        gi.solid(cv, gi.rect(0.22, 0.18, 0.78, 0.82, 0.03), (0.92, 0.88, 0.76))
        gi.solid(cv, gi.rect(0.18, 0.14, 0.3, 0.86, 0.02), (0.35, 0.1, 0.08))
        gi.metal(cv, gi.ellipse(0.55, 0.5, 0.12, 0.12), gi.METAL[5])
        gi.glow(cv, 6, 0.55, 0.5, 0.25)
        cv.paint(gi.ellipse(0.55, 0.5, 0.05, 0.05), C((1, 0.6, 0.2)))
    elif name.startswith('spell_'):
        spell_icon(cv, name[6:])
    return cv.image()


def spell_icon(cv, kind):
    C = gi.C
    col = {'fire': (1.0, 0.45, 0.1), 'meteor': (1.0, 0.35, 0.08), 'ice': (0.55, 0.85, 1.0), 'shield': (0.55, 0.85, 1.0),
           'lightning': (0.75, 0.7, 1.0), 'storm': (0.6, 0.6, 0.95), 'haste': (1.0, 0.92, 0.4), 'death': (0.6, 0.2, 0.75),
           'curse': (0.55, 0.15, 0.6), 'holy': (1.0, 0.9, 0.5), 'purify': (0.9, 0.95, 1.0)}[kind]
    # Tło: ciemny medalion z poświatą szkoły.
    disc = gi.ellipse(0.5, 0.5, 0.46, 0.46)
    cv.paint(disc, gi.grad((0.12, 0.12, 0.16), (0.03, 0.03, 0.05), 0))
    d = np.sqrt((gi.XX - 0.5) ** 2 + (gi.YY - 0.5) ** 2) / 0.46
    cv.paint(disc * np.clip(1 - d, 0, 1) ** 1.5 * 0.8, C(col))
    if kind in ('fire', 'meteor'):
        flame = gi.poly([(0.5, 0.12), (0.7, 0.42), (0.72, 0.62), (0.6, 0.8), (0.4, 0.8), (0.28, 0.62), (0.32, 0.42), (0.44, 0.5)])
        cv.paint(gi.blur(flame, 6), C(col))
        cv.paint(flame, gi.grad((1, 0.95, 0.5), col, 0, 0.3, 0.9))
        cv.paint(gi.poly([(0.5, 0.42), (0.6, 0.62), (0.5, 0.76), (0.4, 0.62)]), C((1, 1, 0.8)))
        if kind == 'meteor':
            gi.solid(cv, gi.ellipse(0.62, 0.66, 0.14, 0.13), (0.35, 0.15, 0.08))
    elif kind in ('ice', 'shield'):
        for a in range(6):
            ang = a * math.pi / 3
            sp = gi.line([(0.5, 0.5), (0.5 + math.cos(ang) * 0.34, 0.5 + math.sin(ang) * 0.34)], 0.06)
            cv.paint(gi.blur(sp, 4), C(col))
            cv.paint(sp, C((0.9, 0.97, 1.0)))
        if kind == 'shield':
            sh = gi.poly([(0.3, 0.26), (0.7, 0.26), (0.7, 0.52), (0.5, 0.8), (0.3, 0.52)])
            gi.metal(cv, sh, (0.6, 0.8, 0.95))
    elif kind in ('lightning', 'storm'):
        if kind == 'storm':
            gi.solid(cv, np.clip(gi.ellipse(0.4, 0.34, 0.18, 0.12) + gi.ellipse(0.6, 0.32, 0.2, 0.14), 0, 1), (0.35, 0.36, 0.45))
        bolt = gi.poly([(0.56, 0.18), (0.36, 0.52), (0.5, 0.52), (0.42, 0.84), (0.66, 0.44), (0.52, 0.44), (0.62, 0.18)])
        cv.paint(gi.blur(bolt, 8), C(col))
        cv.paint(bolt, C((1, 1, 1)))
    elif kind == 'haste':
        for i in range(3):
            cv.paint(gi.line([(0.24 + i * 0.05, 0.3 + i * 0.2), (0.62 + i * 0.05, 0.3 + i * 0.2)], 0.035), C(col))
        gi.solid(cv, gi.poly([(0.6, 0.24), (0.8, 0.5), (0.6, 0.76)]), col)
    elif kind in ('death', 'curse'):
        sk = np.clip(gi.ellipse(0.5, 0.44, 0.22, 0.2) + gi.rect(0.38, 0.5, 0.62, 0.72, 0.04), 0, 1)
        cv.paint(gi.blur(sk, 6), C(col))
        gi.solid(cv, sk, (0.85, 0.82, 0.9) if kind == 'death' else (0.6, 0.3, 0.7))
        for x in (0.42, 0.58):
            cv.paint(gi.ellipse(x, 0.46, 0.05, 0.06), C((0.3, 1.0, 0.4) if kind == 'death' else (1, 0.2, 0.2)))
    elif kind in ('holy', 'purify'):
        for a in range(12):
            ang = a * math.pi / 6
            cv.paint(gi.line([(0.5, 0.5), (0.5 + math.cos(ang) * 0.36, 0.5 + math.sin(ang) * 0.36)], 0.025), C(col))
        cv.paint(gi.blur(gi.ellipse(0.5, 0.5, 0.16, 0.16), 6), C((1, 1, 0.9)))
        cv.paint(gi.ellipse(0.5, 0.5, 0.12, 0.12), C((1, 1, 0.95)))
    ring = disc - gi.ellipse(0.5, 0.5, 0.42, 0.42)
    gi.metal(cv, np.clip(ring, 0, 1), (0.78, 0.6, 0.3))


def main():
    os.makedirs(OUT, exist_ok=True)
    panel().save(os.path.join(OUT, 'panel.png'))
    for s in ['normal', 'hover', 'pressed', 'disabled']:
        button(s).save(os.path.join(OUT, 'button_%s.png' % s))
    slot().save(os.path.join(OUT, 'slot.png'))
    for b in ['hp', 'mp', 'exp', 'bg']:
        bar(b).save(os.path.join(OUT, 'bar_%s.png' % b))
    frame_round().save(os.path.join(OUT, 'frame_round.png'))
    hotbar().save(os.path.join(OUT, 'hotbar.png'))
    joystick_base().save(os.path.join(OUT, 'joystick_base.png'))
    joystick_knob().save(os.path.join(OUT, 'joystick_knob.png'))
    for n in ['bag', 'character', 'specs', 'people', 'menu', 'chat', 'attack', 'heal', 'skull_white', 'skull_red', 'book',
              'spell_fire', 'spell_meteor', 'spell_ice', 'spell_shield', 'spell_lightning', 'spell_storm', 'spell_haste',
              'spell_death', 'spell_curse', 'spell_holy', 'spell_purify']:
        hud_icon(n).save(os.path.join(OUT, 'icon_%s.png' % n))
        print('ikona HUD', n)
    print('gotowe ->', os.path.abspath(OUT))


if __name__ == '__main__':
    main()
