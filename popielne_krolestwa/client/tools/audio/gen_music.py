#!/usr/bin/env python3
"""
Muzyka Popielnych Królestw – syntezowana w całości (bez cudzych próbek), pętle bez szwów.
  menu.wav   – spokojny temat tytułowy (lutnia, pady, dzwony), 76 BPM
  walka.wav  – temat walki w krainach (bęben ramowy, lutnia, smyczki), 100 BPM
  boss.wav   – walka z bossem / Wieża Popiołu (taiko, chór, ostre akordy), 132 BPM
Instrumenty: pad (rozstrojone piły + filtr), lutnia (Karplus-Strong), dzwony (FM),
bębny (opadająca sinusoida + szum), chór (pad z formantem i vibrato), pogłos (splot z IR).
Użycie: python3 tools/audio/gen_music.py   (numpy, scipy)
"""
import os
import wave

import numpy as np
from scipy import signal

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'music')
rng = np.random.default_rng(7)

# D-moll naturalna: numery MIDI stopni od D3.
SCALE = [0, 2, 3, 5, 7, 8, 10]


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def env(n, a, d, s, r, sr=SR):
    a, d, r = int(a * sr), int(d * sr), int(r * sr)
    s_len = max(0, n - a - d - r)
    e = np.concatenate([np.linspace(0, 1, max(a, 1)), np.linspace(1, s, max(d, 1)), np.full(s_len, s), np.linspace(s, 0, max(r, 1))])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def saw(f, t, phase=0.0):
    return 2.0 * ((f * t + phase) % 1.0) - 1.0


def lowpass(x, fc, order=2):
    b, a = signal.butter(order, min(fc / (SR / 2), 0.99))
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], btype='band')
    return signal.lfilter(b, a, x)


def pad(m, dur, bright=1400.0, amp=0.18):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = mtof(m)
    x = sum(saw(f * d, t, rng.random()) for d in (0.996, 1.0, 1.004))
    x = lowpass(x, bright) * env(n, dur * 0.3, 0.2, 0.85, dur * 0.35)
    return x * amp


def choir(m, dur, amp=0.16):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = mtof(m) * (1 + 0.006 * np.sin(2 * np.pi * 5.2 * t))
    ph = np.cumsum(f) / SR
    x = sum(2.0 * ((ph * d + rng.random()) % 1.0) - 1.0 for d in (0.995, 1.0, 1.005))
    x = bandpass(x, 350, 1100) * 0.7 + bandpass(x, 2200, 2800) * 0.15
    return x * env(n, dur * 0.35, 0.2, 0.9, dur * 0.3) * amp


def pluck(m, dur, amp=0.35, damp=0.996):
    """Lutnia: Karplus-Strong jako filtr IIR (szybko w scipy)."""
    n = int(dur * SR)
    f = mtof(m)
    N = int(SR / f)
    burst = np.zeros(n)
    burst[:N] = lowpass(rng.uniform(-1, 1, N), 5000)
    a = np.zeros(N + 2)
    a[0] = 1.0
    a[N] = -damp * 0.5
    a[N + 1] = -damp * 0.5
    y = signal.lfilter([1.0], a, burst)
    return y * env(n, 0.002, 0.05, 0.9, 0.08) * amp


def bell(m, dur, amp=0.12):
    n = int(dur * SR)
    t = np.arange(n) / SR
    fc = mtof(m)
    x = np.sin(2 * np.pi * fc * t + 2.2 * np.exp(-t * 3) * np.sin(2 * np.pi * fc * 1.41 * t))
    return x * np.exp(-t * 2.2) * amp


def kick(amp=0.8, dur=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 45 + 80 * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7) * amp


def taiko(amp=0.9, dur=0.8):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 60 + 50 * np.exp(-t * 18)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5)
    skin = bandpass(rng.uniform(-1, 1, n), 120, 900) * np.exp(-t * 22)
    return (body + skin * 0.8) * amp


def frame_drum(amp=0.4, dur=0.3):
    n = int(dur * SR)
    t = np.arange(n) / SR
    return (bandpass(rng.uniform(-1, 1, n), 200, 2500) * np.exp(-t * 30) + np.sin(2 * np.pi * 110 * t) * np.exp(-t * 20) * 0.5) * amp


def shaker(amp=0.08, dur=0.08):
    n = int(dur * SR)
    t = np.arange(n) / SR
    return bandpass(rng.uniform(-1, 1, n), 4000, 12000) * np.exp(-t * 60) * amp


def reverb_ir(sec=2.6, seed=1):
    r = np.random.default_rng(seed)
    n = int(sec * SR)
    t = np.arange(n) / SR
    ir = r.uniform(-1, 1, n) * np.exp(-t * 3.0 / sec * 2.3)
    ir = lowpass(ir, 6000)
    ir[0] = 1.0
    return ir / np.sqrt(np.sum(ir ** 2)) * 0.9


class Track:
    def __init__(self, bpm, bars, beats=4):
        self.spb = 60.0 / bpm
        self.len_s = bars * beats * self.spb
        self.n = int(self.len_s * SR)
        tail = int(4.0 * SR)
        self.buf = np.zeros(self.n + tail)

    def add(self, x, at_beat, gain=1.0):
        i = int(at_beat * self.spb * SR)
        j = min(len(self.buf), i + len(x))
        self.buf[i:j] += x[:j - i] * gain

    def render(self, name, wet=0.35):
        dry = self.buf
        out = []
        for seed in (1, 2):
            w = signal.fftconvolve(dry, reverb_ir(seed=seed))[:len(dry)]
            out.append(dry * (1 - wet * 0.5) + w * wet)
        st = np.stack(out, axis=1)
        # Pętla bez szwu: ogon (pogłos, wybrzmienia) wraca na początek.
        loop = st[:self.n].copy()
        tail = st[self.n:]
        loop[:len(tail)] += tail[:self.n]
        loop /= max(1e-6, np.max(np.abs(loop))) / 0.89
        # Łagodna kompresja szczytów.
        loop = np.tanh(loop * 1.1) / np.tanh(1.1)
        pcm = (loop * 32767).astype(np.int16)
        path = os.path.join(OUT, name)
        with wave.open(path, 'wb') as wf:
            wf.setnchannels(2)
            wf.setsampwidth(2)
            wf.setframerate(SR)
            wf.writeframes(pcm.tobytes())
        print(name, '%.1f s' % self.len_s)


def chord_notes(root_deg, octave=50, size=3):
    """Akord ze stopni skali (tercje), MIDI."""
    out = []
    for k in range(size):
        d = root_deg + 2 * k
        out.append(octave + SCALE[d % 7] + 12 * (d // 7))
    return out


def melody(progression, bars_motif, rng_seed, octave=62, beats=4):
    """Fraza: motyw A (2 takty) powtarzany z wariacją, B, A' – nuty ze skali, akcenty na dźwiękach akordu."""
    r = np.random.default_rng(rng_seed)
    rhythms = [[1, 1, 1, 1], [1.5, 0.5, 1, 1], [2, 1, 1], [1, 0.5, 0.5, 2], [0.5, 0.5, 1, 2], [3, 1]]
    def phrase(chords):
        notes = []
        deg = 4
        for bar, root in enumerate(chords):
            rh = rhythms[r.integers(len(rhythms))]
            beat = 0.0
            for k, dur in enumerate(rh):
                if k == 0:
                    target = [root, root + 2, root + 4]
                    deg = min(target, key=lambda x: abs(x - deg)) if r.random() < 0.8 else deg
                else:
                    deg += int(r.choice([-2, -1, -1, 1, 1, 2]))
                deg = int(np.clip(deg, -2, 9))
                notes.append((bar * beats + beat, dur, octave + SCALE[deg % 7] + 12 * (deg // 7)))
                beat += dur
        return notes
    a = phrase(progression[:bars_motif])
    b = phrase(progression[bars_motif:bars_motif * 2])
    off = bars_motif * beats
    out = list(a) + [(t + off, d, m) for t, d, m in a[:-2]] + phrase_shift(b, off * 2) + [(t + off * 3, d, m) for t, d, m in a]
    return out


def phrase_shift(notes, off):
    return [(t + off, d, m) for t, d, m in notes]


def menu():
    tr = Track(76, 16)
    prog = [0, 5, 2, 6] * 4  # Dm Bb F C
    for bar, root in enumerate(prog):
        b0 = bar * 4
        for m in chord_notes(root, 50):
            tr.add(pad(m, tr.spb * 4.4, 1100, 0.11), b0)
        tr.add(pad(38 + SCALE[root % 7] - (12 if SCALE[root % 7] > 5 else 0), tr.spb * 4.4, 500, 0.16), b0)
        # Arpeggio lutni.
        arp = chord_notes(root, 62) + [chord_notes(root, 74)[0]]
        for k, step in enumerate([0, 1, 2, 3, 2, 1, 2, 3]):
            tr.add(pluck(arp[step], 1.6, 0.22), b0 + k * 0.5)
        if bar % 4 == 3:
            tr.add(bell(chord_notes(root, 86)[0], 3.0, 0.08), b0 + 3)
    for t, d, m in melody(prog, 4, 11, 74):
        if t >= 32:
            tr.add(pluck(m, d * tr.spb + 0.8, 0.28), t)
    tr.render('menu.wav', 0.42)


def walka():
    tr = Track(100, 16)
    prog = [0, 6, 5, 4, 0, 3, 5, 4] * 2  # Dm C Bb A(m) Dm Gm Bb A
    for bar, root in enumerate(prog):
        b0 = bar * 4
        for m in chord_notes(root, 50):
            tr.add(pad(m, tr.spb * 4.2, 1600, 0.09), b0)
        tr.add(pluck(38 + SCALE[root % 7], tr.spb * 2, 0.4, 0.993), b0)
        tr.add(pluck(38 + SCALE[root % 7], tr.spb * 2, 0.3, 0.993), b0 + 2.5)
        for k in range(8):
            tr.add(shaker(0.06 if k % 2 else 0.09), b0 + k * 0.5)
        tr.add(frame_drum(0.55), b0)
        tr.add(frame_drum(0.3), b0 + 1.5)
        tr.add(frame_drum(0.45), b0 + 2)
        tr.add(frame_drum(0.25), b0 + 3.5 if bar % 2 else b0 + 3)
        tr.add(kick(0.5), b0)
        tr.add(kick(0.35), b0 + 2)
    for t, d, m in melody(prog, 4, 23, 70):
        tr.add(pluck(m, d * tr.spb + 0.5, 0.3, 0.995), t)
        tr.add(pad(m, d * tr.spb, 2400, 0.04), t)
    tr.render('walka.wav', 0.3)


def boss():
    tr = Track(132, 16)
    prog = [0, 0, 1, 0, 5, 5, 6, 4] * 2  # frygijskie Dm–Eb (b2) – groźnie
    flat2 = lambda root: chord_notes(root, 50) if root != 1 else [51, 55, 58]  # Eb-dur
    for bar, root in enumerate(prog):
        b0 = bar * 4
        for m in flat2(root):
            tr.add(choir(m + 12, tr.spb * 4.3, 0.1), b0)
        bass = 38 + (SCALE[root % 7] if root != 1 else 1)
        for k in range(8):
            tr.add(pluck(bass if k % 4 != 3 else bass + 12, tr.spb * 0.6, 0.35 if k % 2 == 0 else 0.22, 0.99), b0 + k * 0.5)
        for k in [0, 1.5, 2, 3, 3.5] if bar % 2 else [0, 0.75, 1.5, 2, 3]:
            tr.add(taiko(0.7 if k in (0, 2) else 0.45), b0 + k)
        tr.add(kick(0.6), b0)
        tr.add(kick(0.6), b0 + 2)
        for k in range(16):
            tr.add(shaker(0.05), b0 + k * 0.25)
        # Ostre akordy „dęte” na początku co drugiego taktu.
        if bar % 2 == 0:
            for m in flat2(root):
                n = int(tr.spb * 0.9 * SR)
                t = np.arange(n) / SR
                x = lowpass(saw(mtof(m), t) + saw(mtof(m) * 1.005, t), 2500) * env(n, 0.01, 0.15, 0.5, 0.2) * 0.1
                tr.add(x, b0)
    for t, d, m in melody(prog, 4, 41, 74):
        if t >= 16:
            tr.add(bell(m, 1.4, 0.06), t)
    tr.render('boss.wav', 0.25)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    menu()
    walka()
    boss()
