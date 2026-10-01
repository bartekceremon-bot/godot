"""Malowane tła krain (próbka stylu C): kompozycja warstwowa + filtr Kuwahary + pociągnięcia pędzla."""
import numpy as np, sys, os
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import uniform_filter, gaussian_filter, sobel

W, H = 2048, 1024
rng = np.random.default_rng(7)
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'style_lab')

def noise(scale, octaves=5, seed=0):
    r = np.random.default_rng(seed)
    acc = np.zeros((H, W)); amp = 1.0; tot = 0
    for o in range(octaves):
        s = max(2, int(scale / (2 ** o)))
        small = r.random((H // s + 2, W // s + 2))
        im = Image.fromarray((small * 255).astype(np.uint8)).resize((W + 2 * s, H + 2 * s), Image.BICUBIC)
        acc += np.asarray(im, float)[:H, :W] / 255 * amp; tot += amp; amp *= 0.5
    return acc / tot

def lerp(a, b, t):
    return a + (b - a) * t[..., None]

def ridge(y0, amp, scale, seed, x=np.arange(W)):
    r = np.random.default_rng(seed)
    n = np.zeros(W)
    for o in range(5):
        f = scale / 2 ** o
        ph = r.random() * 100
        n += np.sin(x / f + ph) * amp / 1.8 ** o + np.sin(x / (f * 0.37) + ph * 2) * amp * 0.3 / 1.8 ** o
    return y0 + n

def paint_layer(img, top, col, edge_noise=0.0, seed=0):
    yy = np.arange(H)[:, None]
    mask = yy >= top[None, :]
    if edge_noise:
        nn = noise(40, 3, seed) * edge_noise
        mask = yy + nn >= top[None, :]
    img[mask] = col if np.ndim(col) == 1 else col[mask]
    return mask

def kuwahara(img, r=5):
    out = np.zeros_like(img)
    lum = img @ np.array([0.3, 0.59, 0.11])
    best = np.full(lum.shape, 1e9)
    k = r + 1
    m = uniform_filter(lum, k); m2 = uniform_filter(lum ** 2, k); var = m2 - m ** 2
    mc = np.stack([uniform_filter(img[..., c], k) for c in range(3)], -1)
    for dy in (-r // 2, r // 2):
        for dx in (-r // 2, r // 2):
            v = np.roll(np.roll(var, dy, 0), dx, 1)
            mm = np.roll(np.roll(mc, dy, 0), dx, 1)
            sel = v < best
            best = np.where(sel, v, best)
            out[sel] = mm[sel]
    return out

def strokes(img, n=60000, length=14, width=4, seed=1):
    r = np.random.default_rng(seed)
    lum = gaussian_filter(img @ np.array([0.3, 0.59, 0.11]), 3)
    gx, gy = sobel(lum, 1), sobel(lum, 0)
    pil = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(pil, 'RGBA')
    blur = gaussian_filter(img, (2, 2, 0))
    for _ in range(n):
        x, y = r.integers(0, W), r.integers(0, H)
        ang = np.arctan2(gy[y, x], gx[y, x]) + np.pi / 2 + r.normal(0, 0.25)
        if abs(gx[y, x]) + abs(gy[y, x]) < 1e-3:
            ang = r.normal(0, 0.35)
        L = length * r.uniform(0.5, 1.3)
        c = np.clip(blur[y, x] * r.uniform(0.94, 1.06), 0, 1)
        dx, dy = np.cos(ang) * L / 2, np.sin(ang) * L / 2
        d.line([(x - dx, y - dy), (x + dx, y + dy)], fill=tuple(int(v * 255) for v in c) + (150,), width=int(width * r.uniform(0.7, 1.3)))
    return np.asarray(pil, float) / 255

def castle(img, cx, base, s, col):
    pil = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)); d = ImageDraw.Draw(pil)
    c = tuple(int(v * 255) for v in col); roof = tuple(int(v * 255 * 0.8) for v in col)
    d.rectangle([cx - 110 * s, base - 40 * s, cx + 110 * s, base], fill=c)
    for i in range(-110, 111, 14):
        d.rectangle([cx + i * s, base - 46 * s, cx + (i + 7) * s, base - 40 * s], fill=c)
    for tx, th, tw in [(-120, 95, 26), (-55, 70, 20), (0, 135, 32), (60, 80, 22), (125, 100, 26)]:
        x0 = cx + tx * s
        d.rectangle([x0 - tw * s / 2, base - th * s, x0 + tw * s / 2, base], fill=c)
        d.polygon([(x0 - tw * s * 0.65, base - th * s), (x0 + tw * s * 0.65, base - th * s), (x0, base - (th + tw * 1.6) * s)], fill=roof)
        d.rectangle([x0 - 2 * s, base - th * s * 0.7, x0 + 2 * s, base - th * s * 0.6], fill=(255, 190, 110))
        d.line([(x0, base - (th + tw * 1.6) * s), (x0, base - (th + tw * 1.6 + 18) * s)], fill=c, width=max(1, int(2 * s)))
        d.polygon([(x0, base - (th + tw * 1.6 + 18) * s), (x0 + 14 * s, base - (th + tw * 1.6 + 14) * s), (x0, base - (th + tw * 1.6 + 10) * s)], fill=(150, 40, 30))
    return np.asarray(pil, float) / 255

def trees(img, top, count, col, sizes, seed, kind='round'):
    r = np.random.default_rng(seed)
    pil = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)); d = ImageDraw.Draw(pil)
    for _ in range(count):
        x = r.integers(0, W); y = top[x] + r.uniform(-4, 20); s = r.uniform(*sizes)
        cc = tuple(int(np.clip(v * r.uniform(0.85, 1.12), 0, 1) * 255) for v in col)
        if kind == 'round':
            d.rectangle([x - s * 0.08, y - s * 0.6, x + s * 0.08, y + 4], fill=tuple(int(v * 0.6) for v in cc))
            for k in range(4):
                ox, oy = r.uniform(-0.35, 0.35) * s, r.uniform(-1.1, -0.55) * s
                rr = s * r.uniform(0.35, 0.55)
                d.ellipse([x + ox - rr, y + oy - rr, x + ox + rr, y + oy + rr], fill=cc)
        else:  # martwe drzewo bagienne
            d.line([(x, y), (x + r.uniform(-8, 8), y - s)], fill=cc, width=max(2, int(s * 0.07)))
            for k in range(5):
                by = y - s * r.uniform(0.35, 0.95); bl = s * r.uniform(0.2, 0.45); sg = r.choice([-1, 1])
                d.line([(x, by), (x + sg * bl, by - bl * r.uniform(0.3, 0.8))], fill=cc, width=max(1, int(s * 0.03)))
    return np.asarray(pil, float) / 255

def meadow():
    yy = (np.arange(H)[:, None] / H) * np.ones((1, W))
    sky = lerp(np.array([0.30, 0.47, 0.78]), np.array([1.0, 0.78, 0.5]), np.clip(yy / 0.58, 0, 1) ** 1.6)
    # słońce
    xx = np.arange(W)[None, :]; sun = np.exp(-(((xx - 1450) / 260) ** 2 + ((yy * H - 470) / 160) ** 2))
    sky = sky + sun[..., None] * np.array([0.5, 0.35, 0.15])
    cl = noise(260, 6, 3); cl = np.clip((cl - 0.52) * 4, 0, 1) * np.clip(1 - yy / 0.5, 0, 1)
    sky = lerp(sky, np.array([1.0, 0.93, 0.85]), cl * 0.75)
    img = sky.copy()
    m1 = ridge(470, 70, 160, 1); paint_layer(img, m1, None if False else np.array([0.47, 0.55, 0.72]), 8, 1)
    m2 = ridge(540, 45, 120, 2); paint_layer(img, m2, np.array([0.38, 0.5, 0.55]), 6, 2)
    img = castle(img, 1180, 600, 1.15, np.array([0.42, 0.44, 0.52]))
    h1 = ridge(600, 30, 140, 3); paint_layer(img, h1, np.array([0.42, 0.58, 0.32]), 6, 3)
    img = trees(img, h1, 70, np.array([0.25, 0.42, 0.22]), (18, 34), 4)
    h2 = ridge(680, 25, 200, 5); g = lerp(np.array([0.48, 0.66, 0.28]), np.array([0.36, 0.52, 0.2]), np.clip((yy - 0.66) * 3, 0, 1)); paint_layer(img, h2, g, 5, 5)
    img = trees(img, h2, 30, np.array([0.2, 0.36, 0.16]), (34, 60), 6)
    return img

def swamp():
    yy = (np.arange(H)[:, None] / H) * np.ones((1, W))
    sky = lerp(np.array([0.16, 0.22, 0.24]), np.array([0.62, 0.66, 0.55]), np.clip(yy / 0.6, 0, 1) ** 1.3)
    cl = noise(300, 6, 9); sky = lerp(sky, np.array([0.5, 0.55, 0.5]), np.clip((cl - 0.45) * 2.5, 0, 1) * 0.6)
    img = sky.copy()
    m1 = ridge(520, 40, 200, 11); paint_layer(img, m1, np.array([0.36, 0.43, 0.4]), 10, 11)
    img = trees(img, m1, 60, np.array([0.28, 0.34, 0.31]), (40, 90), 12, 'dead')
    fog = noise(200, 5, 13); band = np.exp(-((yy * H - 590) / 70) ** 2)
    img = lerp(img, np.array([0.7, 0.74, 0.66]), band * (0.45 + fog * 0.4))
    h1 = ridge(630, 18, 150, 14); paint_layer(img, h1, np.array([0.2, 0.27, 0.2]), 6, 14)
    img = trees(img, h1, 26, np.array([0.12, 0.16, 0.13]), (90, 170), 15, 'dead')
    # woda z odbiciem nieba
    wm = (np.arange(H)[:, None] > 700) & (noise(90, 3, 16) > 0.42)
    img[wm] = img[wm] * 0.4 + np.array([0.45, 0.5, 0.42]) * 0.6
    return img

def ash():
    yy = (np.arange(H)[:, None] / H) * np.ones((1, W))
    sky = lerp(np.array([0.12, 0.05, 0.05]), np.array([0.85, 0.34, 0.12]), np.clip(yy / 0.62, 0, 1) ** 1.5)
    cl = noise(240, 6, 21); sky = lerp(sky, np.array([0.22, 0.12, 0.1]), np.clip((cl - 0.45) * 2.2, 0, 1) * np.clip(1 - yy / 0.55, 0, 1) * 0.85)
    img = sky.copy()
    # wulkan z łuną
    x = np.arange(W); vol = 560 - np.clip(260 - np.abs(x - 700) * 0.55, 0, None); vol = np.where(np.abs(x - 700) < 60, 560 - 230, vol)
    paint_layer(img, vol.astype(float), np.array([0.2, 0.1, 0.09]), 6, 22)
    xx = np.arange(W)[None, :]; glow = np.exp(-(((xx - 700) / 90) ** 2 + ((yy * H - 330) / 60) ** 2))
    img = img + glow[..., None] * np.array([1.0, 0.45, 0.1]) * 0.9
    lava = np.exp(-(((xx - 700 - (yy * H - 330) * 0.15) / 14) ** 2)) * (yy * H > 330) * (yy * H < 560)
    img = img + lava[..., None] * np.array([1.0, 0.5, 0.1]) * 0.8
    m2 = ridge(600, 30, 150, 23); paint_layer(img, m2, np.array([0.16, 0.09, 0.08]), 6, 23)
    img = castle(img, 1500, 615, 1.0, np.array([0.11, 0.07, 0.07]))
    img = trees(img, m2, 30, np.array([0.08, 0.05, 0.05]), (40, 80), 24, 'dead')
    h1 = ridge(680, 20, 120, 25); paint_layer(img, h1, np.array([0.13, 0.08, 0.07]), 5, 25)
    # żarzące się szczeliny
    cr = (noise(30, 3, 26) > 0.66) & (np.arange(H)[:, None] > 700)
    img[cr] = img[cr] * 0.3 + np.array([1.0, 0.4, 0.1]) * 0.7
    return img

def finish(img, name):
    img = np.clip(img, 0, 1)
    img = kuwahara(img, 6)
    img = strokes(img, 70000, 16, 4, 1)
    img = kuwahara(img, 3)
    # lekkie ziarno płótna
    img = img * (0.96 + noise(6, 2, 99)[..., None] * 0.08)
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, f'backdrop_{name}.png'))
    print('ok', name)

os.makedirs(OUT, exist_ok=True)
only = sys.argv[1:] or ['meadow', 'swamp', 'ash']
for nm in only:
    finish(globals()[nm](), nm)
