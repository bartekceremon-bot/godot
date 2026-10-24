#!/usr/bin/env python3
"""Syntezator dźwięków i muzyki dla „Strażników Iskry”.

Wszystkie dźwięki powstają matematycznie (sinusy, szum, obwiednie) —
nie korzystamy z cudzych nagrań. Wynik:
  godot/assets/audio/sfx/*.wav   (krótkie efekty, 22 050 Hz mono)
  godot/assets/audio/music/*.ogg (pętle muzyczne, Vorbis)
Użycie: python3 tools/generate_audio.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "audio")
SR = 22050
rng = np.random.default_rng(7)


def t_axis(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def env(n, a=0.005, d=0.1, s=0.0, r=0.1, sr=SR):
    """Obwiednia ADSR o długości n próbek."""
    a_n, d_n, r_n = int(a * sr), int(d * sr), int(r * sr)
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, max(1, a_n)),
        np.linspace(1, s, max(1, d_n)),
        np.full(s_n, s),
        np.linspace(s, 0, max(1, r_n)),
    ])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def tone(freq, dur, kind="sine", sr=SR):
    t = t_axis(dur, sr)
    if callable(freq):
        phase = 2 * np.pi * np.cumsum(freq(t)) / sr
    else:
        phase = 2 * np.pi * freq * t
    if kind == "sine":
        return np.sin(phase)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    if kind == "square":
        return np.tanh(np.sin(phase) * 4) * 0.6
    if kind == "saw":
        return 2 * (phase / (2 * np.pi) % 1) - 1
    raise ValueError(kind)


def noise(dur, sr=SR):
    return rng.uniform(-1, 1, int(dur * sr))


def lowpass(x, a=0.2):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def write_wav(name, x, sr=SR):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * 0.85
    data = (x * 32767).astype(np.int16)
    path = os.path.join(ROOT, "sfx", name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def mix(*arrs):
    """Sumuje sygnały o różnych długościach."""
    n = max(len(a) for a in arrs)
    out = np.zeros(n)
    for a in arrs:
        out[:len(a)] += a
    return out


def chime(freqs, dur=0.5, spacing=0.06, kind="sine"):
    total = dur + spacing * len(freqs)
    out = np.zeros(int(total * SR))
    for i, f in enumerate(freqs):
        s = tone(f, dur, kind) * env(int(dur * SR), 0.004, dur * 0.9, 0, 0.05)
        s += 0.3 * tone(f * 2, dur) * env(int(dur * SR), 0.002, dur * 0.5, 0, 0.02)
        st = int(i * spacing * SR)
        out[st:st + len(s)] += s
    return out


def sfx():
    os.makedirs(os.path.join(ROOT, "sfx"), exist_ok=True)
    n = lambda d: int(d * SR)
    write_wav("click", tone(1400, 0.04) * env(n(0.04), 0.001, 0.03, 0, 0.005))
    write_wav("start", chime([523, 659, 784, 1046], 0.6, 0.07))
    write_wav("open", chime([440, 660], 0.25, 0.04, "tri"))
    write_wav("error", tone(lambda t: 300 - 80 * t / 0.25, 0.25, "tri") * env(n(0.25), 0.01, 0.2, 0, 0.04))
    write_wav("success", chime([523, 659, 784, 988, 1175], 0.7, 0.08))
    write_wav("quest", chime([392, 523, 659, 784, 1046], 0.9, 0.1))
    write_wav("levelup", chime([523, 659, 784, 1046, 1318, 1568], 1.0, 0.07))
    write_wav("fragment", chime([659, 880, 1108, 1318, 1760], 1.4, 0.12) + 0.0)
    write_wav("chest", np.concatenate([lowpass(noise(0.08), 0.3) * env(n(0.08), 0.001, 0.07, 0, 0.01), chime([784, 988, 1318], 0.5, 0.05)]))
    write_wav("checkpoint", chime([392, 587, 784], 0.8, 0.09, "tri"))
    write_wav("portal", tone(lambda t: 200 + 600 * t / 0.7, 0.7, "sine") * env(n(0.7), 0.05, 0.5, 0.3, 0.15) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t_axis(0.7))))
    planks = np.zeros(n(1.6))
    for i in range(8):
        s = lowpass(noise(0.06), 0.25) * env(n(0.06), 0.001, 0.05, 0, 0.01) + 0.5 * tone(180 + i * 15, 0.06, "tri") * env(n(0.06), 0.001, 0.05, 0, 0.01)
        st = n(i * 0.19)
        planks[st:st + len(s)] += s
    write_wav("bridge", planks)
    write_wav("unlock", chime([330, 494, 659, 988], 0.6, 0.06, "tri"))
    write_wav("water", lowpass(noise(1.2), 0.08) * env(n(1.2), 0.2, 0.6, 0.4, 0.4) * (0.7 + 0.3 * np.sin(2 * np.pi * 3 * t_axis(1.2))))
    write_wav("heal", chime([659, 784, 988], 0.5, 0.05))
    write_wav("pickup", tone(lambda t: 900 + 900 * t / 0.1, 0.1) * env(n(0.1), 0.002, 0.09, 0, 0.01))
    write_wav("hurt", tone(lambda t: 260 - 120 * t / 0.2, 0.2, "square") * env(n(0.2), 0.002, 0.18, 0, 0.02) + 0.4 * lowpass(noise(0.2), 0.4) * env(n(0.2), 0.001, 0.1, 0, 0.01))
    write_wav("death", tone(lambda t: 400 - 300 * t / 1.0, 1.0, "tri") * env(n(1.0), 0.01, 0.9, 0, 0.1))
    write_wav("dodge", lowpass(noise(0.18), 0.5) * env(n(0.18), 0.01, 0.16, 0, 0.02) * np.linspace(0.3, 1, n(0.18)))
    write_wav("hit", lowpass(noise(0.07), 0.5) * env(n(0.07), 0.001, 0.06, 0, 0.01) + 0.6 * tone(220, 0.07, "tri") * env(n(0.07), 0.001, 0.06, 0, 0.01))
    write_wav("enemy_die", tone(lambda t: 700 - 500 * t / 0.35, 0.35, "sine") * env(n(0.35), 0.005, 0.3, 0, 0.05) + 0.4 * lowpass(noise(0.35), 0.15) * env(n(0.35), 0.005, 0.3, 0, 0.05))
    write_wav("enemy_shot", tone(lambda t: 500 - 200 * t / 0.25, 0.25, "tri") * env(n(0.25), 0.01, 0.22, 0, 0.03))
    write_wav("lunge", lowpass(noise(0.2), 0.35) * env(n(0.2), 0.02, 0.17, 0, 0.02))
    write_wav("slam", lowpass(noise(0.45), 0.06) * env(n(0.45), 0.002, 0.4, 0, 0.05) + tone(lambda t: 90 - 40 * t / 0.45, 0.45) * env(n(0.45), 0.002, 0.4, 0, 0.05))
    write_wav("rune", tone(lambda t: 880 + 300 * np.sin(t * 60), 0.16, "sine") * env(n(0.16), 0.003, 0.14, 0, 0.02))
    write_wav("wrench", tone(lambda t: 300 + 500 * t / 0.18, 0.18, "saw") * 0.4 * env(n(0.18), 0.002, 0.16, 0, 0.02) + 0.5 * tone(1200, 0.18) * env(n(0.18), 0.001, 0.05, 0, 0.01))
    write_wav("arrow", lowpass(noise(0.14), 0.6) * env(n(0.14), 0.002, 0.12, 0, 0.02) + 0.3 * tone(lambda t: 1500 - 800 * t / 0.14, 0.14) * env(n(0.14), 0.002, 0.12, 0, 0.02))
    write_wav("hammer", lowpass(noise(0.2), 0.2) * env(n(0.2), 0.001, 0.18, 0, 0.02) + tone(120, 0.2) * env(n(0.2), 0.001, 0.18, 0, 0.02))
    write_wav("swing", lowpass(noise(0.16), 0.4) * env(n(0.16), 0.03, 0.12, 0, 0.02))
    write_wav("bolt", tone(lambda t: 1300 - 600 * t / 0.08, 0.08, "square") * 0.5 * env(n(0.08), 0.001, 0.07, 0, 0.01))
    write_wav("skill", chime([587, 880, 1175], 0.35, 0.03))
    write_wav("blik", mix(tone(lambda t: 1200 + 400 * np.sin(t * 50), 0.12) * env(n(0.12), 0.003, 0.1, 0, 0.02), 0.6 * np.concatenate([np.zeros(n(0.05)), tone(1600, 0.07) * env(n(0.07), 0.002, 0.06, 0, 0.01)])))
    write_wav("talk", tone(lambda t: 500 + 80 * np.sin(t * 30), 0.08, "tri") * env(n(0.08), 0.005, 0.07, 0, 0.01))
    write_wav("illusion", tone(lambda t: 300 + 200 * np.sin(t * 8), 1.0) * env(n(1.0), 0.1, 0.8, 0.2, 0.1) * (0.6 + 0.4 * np.sin(2 * np.pi * 12 * t_axis(1.0))))
    write_wav("illusion_pop", lowpass(noise(0.3), 0.3) * env(n(0.3), 0.002, 0.25, 0, 0.05) + tone(lambda t: 900 - 600 * t / 0.3, 0.3) * env(n(0.3), 0.002, 0.25, 0, 0.05))
    write_wav("reveal", chime([392, 494, 587, 784], 0.6, 0.05, "tri"))
    write_wav("boss_die", np.concatenate([lowpass(noise(0.6), 0.1) * env(n(0.6), 0.01, 0.55, 0, 0.05), chime([523, 659, 784, 1046, 1318], 1.2, 0.1)]))


# --- Muzyka -----------------------------------------------------------------

MSR = 32000
NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def hz(name):
    """'A4' -> 440 Hz."""
    n, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[n] + (o - 4) * 12 - 9) / 12)


def mtone(f, dur, kind="sine", a=0.01, r=0.2, sus=0.6):
    t = np.arange(int(dur * MSR)) / MSR
    if kind == "pad":
        x = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.003 * t) + 0.25 * np.sin(2 * np.pi * f * 2 * t))
    elif kind == "pluck":
        x = np.sin(2 * np.pi * f * t) * np.exp(-t * 5) + 0.3 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 9)
    elif kind == "bell":
        x = np.sin(2 * np.pi * f * t) * np.exp(-t * 3) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 6)
    elif kind == "bass":
        x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2 * t)
    else:
        x = np.sin(2 * np.pi * f * t)
    n = len(x)
    e = np.ones(n)
    an, rn = int(a * MSR), int(r * MSR)
    e[:an] = np.linspace(0, 1, an)
    if kind in ("pad", "bass"):
        e[an:] = sus
        e[-rn:] *= np.linspace(1, 0, rn)
    return x * e


def place(buf, x, start_s):
    st = int(start_s * MSR)
    end = min(len(buf), st + len(x))
    buf[st:end] += x[:end - st]
    # Zawijanie ogona na początek, żeby pętla była płynna.
    if st + len(x) > len(buf):
        rest = x[end - st:]
        buf[:len(rest)] += rest


def echo(x, delay=0.33, fb=0.35, mix=0.35):
    d = int(delay * MSR)
    y = x.copy()
    for k in range(1, 5):
        shifted = np.roll(x, d * k) * (fb ** k)
        y += shifted * mix
    return y


def song(name, bpm, chords, melody, arp_kind="pluck", lead_kind="bell", bars_per_chord=1, density=1.0, bass=True):
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * bars_per_chord * len(chords)
    buf = np.zeros(int(total * MSR))
    for ci, chord in enumerate(chords):
        t0 = ci * bar * bars_per_chord
        freqs = [hz(n) for n in chord]
        for f in freqs:
            place(buf, 0.12 * mtone(f, bar * bars_per_chord, "pad", a=0.4, r=0.6, sus=0.7), t0)
        if bass:
            for b in range(bars_per_chord * 2):
                place(buf, 0.16 * mtone(freqs[0] / 2, beat * 2, "bass", a=0.02, r=0.3, sus=0.8), t0 + b * beat * 2)
        steps = int(8 * bars_per_chord * density)
        for s in range(steps):
            f = freqs[s % len(freqs)] * (2 if (s // len(freqs)) % 2 else 1)
            place(buf, 0.07 * mtone(f, beat, arp_kind), t0 + s * (bar * bars_per_chord / steps))
    for (note, start, dur) in melody:
        if note:
            place(buf, 0.10 * mtone(hz(note), dur * beat * 1.5, lead_kind), start * beat)
    buf = echo(buf)
    buf = np.tanh(buf * 1.4)
    peak = np.max(np.abs(buf)) or 1
    buf = buf / peak * 0.8
    stereo = np.stack([buf, np.roll(buf, int(0.012 * MSR))], axis=1)
    data = (stereo * 32767).astype(np.int16)
    os.makedirs(os.path.join(ROOT, "music"), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, name + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(MSR)
            w.writeframes(data.tobytes())
        out = os.path.join(ROOT, "music", name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "2", out], check=True)


def mel(seq, step=1.0):
    out, t = [], 0.0
    for n in seq:
        if n == "-":
            t += step
            continue
        dur = step
        out.append((n, t, dur))
        t += step
    return out


def music():
    # Ekran tytułowy i scenki: spokojnie, z nutą tajemnicy (D-dur / h-moll).
    song("title", 72, [["D3", "F#3", "A3"], ["B2", "D3", "F#3"], ["G2", "B2", "D3"], ["A2", "C#3", "E3"]],
         mel(["F#5", "-", "A5", "-", "B5", "A5", "F#5", "-", "D5", "-", "E5", "F#5", "E5", "-", "-", "-"], 2.0), bars_per_chord=2)
    # Baza: ciepło i bezpiecznie.
    song("hub", 84, [["C3", "E3", "G3"], ["A2", "C3", "E3"], ["F2", "A2", "C3"], ["G2", "B2", "D3"]],
         mel(["E5", "G5", "A5", "G5", "E5", "-", "D5", "C5", "D5", "E5", "G5", "-", "A5", "G5", "E5", "-"], 1.0) +
         [(n, s + 16, d) for (n, s, d) in mel(["C5", "D5", "E5", "G5", "E5", "D5", "C5", "-", "A4", "C5", "D5", "-", "C5", "-", "-", "-"], 1.0)], bars_per_chord=2)
    # Eksploracja: żwawiej, z przygodą.
    song("explore", 100, [["A2", "C3", "E3"], ["F2", "A2", "C3"], ["C3", "E3", "G3"], ["G2", "B2", "D3"]],
         mel(["A4", "C5", "E5", "-", "D5", "C5", "A4", "-", "F4", "A4", "C5", "-", "E5", "D5", "C5", "-",
              "E5", "G5", "E5", "D5", "C5", "-", "D5", "E5", "D5", "-", "B4", "-", "C5", "-", "-", "-"], 1.0), bars_per_chord=2, density=1.5)
    # Archiwum: zagadkowo (e-moll).
    song("archive", 80, [["E3", "G3", "B3"], ["C3", "E3", "G3"], ["A2", "C3", "E3"], ["B2", "D#3", "F#3"]],
         mel(["B4", "-", "E5", "-", "G5", "F#5", "E5", "-", "C5", "-", "E5", "-", "B4", "-", "-", "-",
              "A4", "-", "C5", "E5", "D#5", "-", "F#5", "-", "E5", "-", "-", "-", "-", "-", "-", "-"], 1.0), arp_kind="bell", lead_kind="pluck", bars_per_chord=2)
    # Boss: napięcie, ale bez agresji.
    song("boss", 128, [["D3", "F3", "A3"], ["A#2", "D3", "F3"], ["C3", "E3", "G3"], ["A2", "C#3", "E3"]],
         mel(["D5", "F5", "A5", "F5", "D5", "-", "A4", "-", "A#4", "D5", "F5", "D5", "C5", "E5", "G5", "-",
              "A5", "G5", "F5", "E5", "D5", "-", "C#5", "-", "E5", "-", "A4", "-", "-", "-", "-", "-"], 0.5), bars_per_chord=1, density=2.0)
    # Finał: triumf (G-dur).
    song("finale", 76, [["G2", "B2", "D3"], ["E2", "G2", "B2"], ["C3", "E3", "G3"], ["D3", "F#3", "A3"]],
         mel(["B4", "D5", "G5", "-", "F#5", "E5", "D5", "-", "E5", "G5", "C6", "-", "B5", "A5", "D5", "-"], 2.0), bars_per_chord=2)


if __name__ == "__main__":
    sfx()
    music()
    print("Wygenerowano dźwięki w", os.path.abspath(ROOT))
