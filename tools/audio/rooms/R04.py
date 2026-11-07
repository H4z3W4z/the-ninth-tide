#!/usr/bin/env python3
"""R04 sounds: the cork-lined recording room (wax cylinders, mixer, channel C, the funnel).

Standard library only, via tools/audio/common.py. One fixed seed per sound,
random.Random(1931_04_NN), so a rerun writes byte-identical 22050 Hz mono WAVs to
assets/audio/R04/. Loops are rendered one second long and closed with seamless(1.0), so the
file's last sample runs straight into its first.

Levels: loops are mastered to about -18 dBFS RMS, one-shots peak at -3 dBFS; the view sets
the final level (SFX_DB, LoopMixer targets). The sudden one-shots (needle_skip, reject_buzz,
relay_off, venn_funnel) keep every transient's attack at 4 ms or longer, so the 12 dB
"Soften sudden sounds" cut is enough on its own.

Voices: there is no recorded speech and there must never be words. A voice here is a pitched
glottal pulse train through three moving formant resonators driven by a seeded vowel walk at
about four syllables a second, compressed toward a neutral vowel so it only ever carries
cadence. The captions carry all the content; each phrase window below is the caption timing.

    python3 tools/build_audio.py R04
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F401,F403  SR, TAU, lowpass, highpass, white, brown, ...
from common import SR, TAU, brown, env_ad, highpass, lowpass, seamless, smooth_walk, white, write  # noqa: E402

OUT = room_out("R04")  # noqa: F405

LOOP_RMS = 10 ** (-18 / 20)   # about -18 dBFS RMS
SHOT_PEAK = 10 ** (-3 / 20)   # -3 dBFS peak
SUDDEN_ATTACK = 0.006         # every sudden transient rises over 6 ms (>= 4 ms)

VENN_F0 = 105.0
NORA_F0 = 190.0


def seed(nn: int) -> random.Random:
    return random.Random(int(f"193104{nn:02d}"))


def n_of(seconds: float) -> int:
    return int(round(seconds * SR))


def silence(seconds: float) -> list[float]:
    return [0.0] * n_of(seconds)


# ---------------------------------------------------------------- filters

def biquad_bp(xs: list[float], fc: float, q: float) -> list[float]:
    """Two-pole resonant band-pass (constant 0 dB peak)."""
    w = TAU * fc / SR
    alpha = math.sin(w) / (2 * q)
    a0 = 1 + alpha
    b0, b2 = alpha / a0, -alpha / a0
    a1, a2 = -2 * math.cos(w) / a0, (1 - alpha) / a0
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in xs:
        y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def bandlimit(xs: list[float], lo: float, hi: float) -> list[float]:
    """Second-order-ish band limit: two one-pole high-passes at lo, two low-passes at hi."""
    return lowpass(lowpass(highpass(highpass(xs, lo), lo), hi), hi)


def comb(xs: list[float], delay_s: float, fb: float) -> list[float]:
    d = max(1, int(round(delay_s * SR)))
    out = list(xs)
    for i in range(d, len(out)):
        out[i] += fb * out[i - d]
    return out


def smear(xs: list[float], rnd: random.Random, span_s: float, taps: int, gain: float) -> list[float]:
    """Early-reflection smear: seeded decaying taps spread over span_s."""
    out = list(xs)
    for _ in range(taps):
        d = n_of(rnd.uniform(0.012, span_s))
        g = gain * math.exp(-3 * d / (span_s * SR)) * rnd.choice((-1, 1))
        for i in range(d, len(out)):
            out[i] += g * xs[i - d]
    return out


def mix(dst: list[float], src: list[float], at_s: float, gain: float = 1.0) -> list[float]:
    start = n_of(at_s)
    for i, x in enumerate(src):
        j = start + i
        if 0 <= j < len(dst):
            dst[j] += gain * x
    return dst


def scale(xs: list[float], g: float) -> list[float]:
    return [x * g for x in xs]


def rms(xs: list[float]) -> float:
    return math.sqrt(sum(x * x for x in xs) / max(1, len(xs)))


def fade_edges(xs: list[float], fin: float = 0.004, fout: float = 0.01) -> list[float]:
    a, b = max(1, n_of(fin)), max(1, n_of(fout))
    n = len(xs)
    for i in range(min(a, n)):
        xs[i] *= 0.5 - 0.5 * math.cos(math.pi * i / a)
    for i in range(min(b, n)):
        xs[n - 1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / b)
    return xs


def gate(xs: list[float], t0: float, t1: float, fin: float, fout: float) -> list[float]:
    """Keeps xs only inside [t0, t1], with raised-cosine edges inside the window."""
    a, b = n_of(t0), n_of(t1)
    fa, fb = max(1, n_of(fin)), max(1, n_of(fout))
    out = []
    for i, x in enumerate(xs):
        if i < a or i >= b:
            out.append(0.0)
            continue
        g = 1.0
        if i - a < fa:
            g = 0.5 - 0.5 * math.cos(math.pi * (i - a) / fa)
        if b - 1 - i < fb:
            g = min(g, 0.5 - 0.5 * math.cos(math.pi * (b - 1 - i) / fb))
        out.append(x * g)
    return out


# ---------------------------------------------------------------- small sources

def click(rnd: random.Random, length: float, attack: float, modes: list[tuple[float, float, float]],
          noise: float = 0.3, noise_lp: float = 5000) -> list[float]:
    """A shaped mechanical transient: raised-cosine attack, decaying modal partials, noise."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(white(n, rnd), noise_lp)
    out = []
    for i in range(n):
        t = i / SR
        env = (0.5 - 0.5 * math.cos(math.pi * i / a)) if i < a else 1.0
        v = 0.0
        for f, amp, tau in modes:
            v += amp * math.sin(TAU * f * t) * math.exp(-t / tau)
        v += noise * nz[i] * math.exp(-t / 0.006)
        out.append(env * v)
    return out


def thock(rnd: random.Random, length: float, f: float, tau: float, attack: float = 0.003) -> list[float]:
    """A dull low impact: a falling sine thump with a lowpassed noise body."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(white(n, rnd), 700)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ph += TAU * f * (1 + 0.4 * math.exp(-t / 0.01)) / SR
        env = (0.5 - 0.5 * math.cos(math.pi * i / a)) if i < a else 1.0
        out.append(env * math.exp(-t / tau) * (math.sin(ph) + 0.8 * nz[i]))
    return out


def swish(rnd: random.Random, length: float, lo: float, hi: float, shape) -> list[float]:
    n = n_of(length)
    nz = bandlimit(white(n, rnd), lo, hi)
    return [x * shape(i / max(1, n - 1)) for i, x in enumerate(nz)]


def crackle(n: int, rnd: random.Random, rate: float, hiss: float = 0.05) -> list[float]:
    """Wax surface: sparse seeded impulses (each a tiny decaying pop), high-passed, over hiss."""
    out = [0.0] * n
    p = rate / SR
    for i in range(n):
        if rnd.random() < p:
            amp = rnd.expovariate(1.0) * rnd.choice((-1, 1))
            length = rnd.randint(3, 14)
            for k in range(length):
                if i + k < n:
                    out[i + k] += amp * math.exp(-k / 2.5) * (1 if k % 2 == 0 else -0.6)
    out = highpass(highpass(out, 900), 900)
    h = bandlimit(white(n, rnd), 1500, 5000)
    return [c + hiss * x for c, x in zip(out, h)]


def bell(rnd: random.Random, length: float = 0.6, f: float = 2100, tau: float = 0.4 / 3) -> list[float]:
    """A small session-mark bell: 2.1 kHz with two inharmonic partials, ~0.4 s to near silence."""
    return click(rnd, length, 0.002, [(f, 1.0, tau), (f * 2.76, 0.25, tau * 0.4),
                                       (f * 0.5, 0.12, tau * 0.6)], noise=0.08)


def hum_tone(n: int, f: float, harmonics: list[float]) -> list[float]:
    return [sum(a * math.sin(TAU * f * (k + 1) * i / SR) for k, a in enumerate(harmonics))
            for i in range(n)]


# ---------------------------------------------------------------- the voice

# Vowel formants (F1, F2, F3), then pulled 45 % toward a neutral vowel: enough movement to read
# as speech cadence through a horn, never enough contrast to hear vowels, let alone words.
VOWELS = [(730, 1090, 2440), (270, 2290, 3010), (300, 870, 2240), (530, 1840, 2480),
          (570, 840, 2410), (440, 1020, 2240), (660, 1720, 2410), (490, 1350, 1690)]
NEUTRAL = (500, 1450, 2500)
VOWEL_SPREAD = 0.55


def syllable_plan(rnd: random.Random, t0: float, t1: float, rate: float, slow_end: float = 1.0):
    """Seeded syllables filling [t0, t1]: list of (start, end, stress, vowel, word_end)."""
    sylls, t = [], t0
    in_word = 0
    word_len = rnd.randint(1, 4)
    while t < t1 - 0.08:
        frac = (t - t0) / max(1e-6, t1 - t0)
        r = rate * (1 - (1 - slow_end) * frac ** 1.5)
        d = rnd.uniform(0.7, 1.3) / r
        d = min(d, t1 - t)
        in_word += 1
        word_end = in_word >= word_len
        if word_end:
            in_word, word_len = 0, rnd.randint(1, 4)
        stress = 1.0 if rnd.random() < 0.3 else rnd.uniform(0.55, 0.85)
        v = rnd.choice(VOWELS)
        v = tuple(NEUTRAL[k] + VOWEL_SPREAD * (v[k] - NEUTRAL[k]) for k in range(3))
        sylls.append((t, t + d, stress, v, word_end))
        t += d + (rnd.uniform(0.05, 0.12) if word_end else 0.0)
    if sylls:  # phrase-final lengthening: stretch the last syllable to the phrase end
        s = sylls[-1]
        sylls[-1] = (s[0], t1, s[2] * 0.9, s[3], True)
    return sylls


def voice_tracks(n: int, rnd: random.Random, phrases, rate: float = 4.0, slow_end: float = 1.0,
                 cut_abrupt: bool = False, onset: float = 0.03, thin_last: bool = False):
    """Per-sample amplitude, relative pitch and formant tracks for a list of (t0, t1) phrases."""
    amp = [0.0] * n
    rel = [1.0] * n
    fm = [[NEUTRAL[k]] * n for k in range(3)]
    thin = [0.0] * n
    for pi, (t0, t1) in enumerate(phrases):
        last = pi == len(phrases) - 1
        sylls = syllable_plan(rnd, t0, t1, rate, slow_end if last else 1.0)
        a0, a1 = n_of(t0), min(n, n_of(t1))
        centers = [((s[0] + s[1]) / 2, s[3]) for s in sylls]
        for i in range(a0, a1):
            t = i / SR
            frac = (t - t0) / max(1e-6, t1 - t0)
            # pitch: declination, accents on stressed syllables, a phrase-final fall
            rel[i] = 1.08 - 0.2 * frac - (0.06 * ((frac - 0.85) / 0.15) if frac > 0.85 else 0.0)
            if thin_last and last:
                thin[i] = frac
        for (s0, s1, stress, _v, word_end) in sylls:
            b0, b1 = n_of(s0), min(n, n_of(s1))
            span = max(1, b1 - b0)
            floor = 0.0 if word_end else 0.25
            for i in range(b0, b1):
                x = (i - b0) / span
                # rise over the first 30 %, hold, sag toward the next syllable
                shape = math.sin(math.pi * min(1.0, x / 0.6) / 2) if x < 0.6 else \
                    floor + (1 - floor) * math.cos(math.pi / 2 * (x - 0.6) / 0.4) ** 1.2
                amp[i] = max(amp[i], stress * shape)
                rel[i] *= 1 + 0.07 * (stress - 0.7) * math.sin(math.pi * x)
        # formants: cosine glides between syllable centres
        for i in range(a0, a1):
            t = i / SR
            k = 0
            while k < len(centers) - 1 and centers[k + 1][0] < t:
                k += 1
            if t <= centers[0][0] or k == len(centers) - 1:
                v = centers[k][1] if t > centers[0][0] else centers[0][1]
            else:
                c0, v0 = centers[k]
                c1, v1 = centers[k + 1]
                u = (1 - math.cos(math.pi * (t - c0) / (c1 - c0))) / 2
                v = tuple(v0[j] * (1 - u) + v1[j] * u for j in range(3))
            for j in range(3):
                fm[j][i] = v[j]
        # phrase edges: a soft onset, and either a soft release or a 4 ms cut
        on, off = max(1, n_of(onset)), max(1, n_of(0.004 if cut_abrupt else 0.06))
        for i in range(a0, a1):
            g = 1.0
            if i - a0 < on:
                g = 0.5 - 0.5 * math.cos(math.pi * (i - a0) / on)
            if a1 - 1 - i < off:
                g = min(g, 0.5 - 0.5 * math.cos(math.pi * (a1 - 1 - i) / off))
            amp[i] *= g
    amp = lowpass(amp, 30)  # takes the corners off syllable envelopes, keeps 4 syll/s motion
    return amp, rel, fm, thin


def glottal(n: int, rnd: random.Random, f0: float, rel: list[float], amp: list[float],
            open_q: float, breath: float, wow: float = 0.0, thin=None) -> list[float]:
    """Pitched glottal pulse train (differentiated Rosenberg pulse) with slow jitter and aspiration."""
    drift = smooth_walk(n, rnd, 0.18)
    ph, g_prev = 0.0, 0.0
    jit = 1.0
    asp = white(n, rnd)
    out = []
    tp, tn = open_q * 0.66, open_q * 0.34
    for i in range(n):
        f = f0 * rel[i] * (1 + 0.05 * (drift[i] - 0.5)) * jit
        if wow:
            f *= 1 + wow * math.sin(TAU * 1.35 * i / SR)
        ph += f / SR
        if ph >= 1.0:
            ph -= 1.0
            jit = 1 + rnd.uniform(-0.008, 0.008)
        if ph < tp:
            g = 0.5 - 0.5 * math.cos(math.pi * ph / tp)
        elif ph < tp + tn:
            g = math.cos(math.pi / 2 * (ph - tp) / tn)
        else:
            g = 0.0
        d = (g - g_prev) * SR / (f0 * 8)
        g_prev = g
        b = breath + (0.5 * thin[i] if thin else 0.0)
        v = (1 - b) * d + b * asp[i] * (0.35 + g)
        out.append(amp[i] * v)
    return out


def formant_filter(src: list[float], fm, gains=(1.0, 0.55, 0.28), bws=(90, 130, 180),
                   thin=None) -> list[float]:
    """Three moving two-pole band-pass resonators in parallel, coefficients updated every 8 samples."""
    n = len(src)
    out = [0.0] * n
    for j in range(3):
        x1 = x2 = y1 = y2 = 0.0
        b0 = b2 = a1 = a2 = 0.0
        g = gains[j]
        for i in range(n):
            if i % 8 == 0:
                fc = fm[j][i]
                bw = bws[j] * (1 + (1.5 * thin[i] if thin else 0.0))
                w = TAU * fc / SR
                alpha = math.sin(w) * bw / (2 * fc)
                a0 = 1 + alpha
                b0, b2 = alpha / a0, -alpha / a0
                a1, a2 = -2 * math.cos(w) / a0, (1 - alpha) / a0
                if thin:
                    g = gains[j] * (1 - 0.6 * thin[i] * (j / 2))
            x = src[i]
            y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, x, y1, y
            out[i] += g * y
    return out


def voice(dur: float, rnd: random.Random, who: str, phrases, rate: float = 4.0, slow_end: float = 1.0,
          cut_abrupt: bool = False, onset: float = 0.03, wow: float = 0.0, thin_last: bool = False,
          tracks=None) -> list[float]:
    """Venn (105 Hz, drier, slow jitter) or Nora (190 Hz, warmer, low-shelf warmth) cadence."""
    n = n_of(dur)
    if tracks is None:
        tracks = voice_tracks(n, rnd, phrases, rate, slow_end, cut_abrupt, onset, thin_last)
    amp, rel, fm, thin = tracks
    if who == "venn":
        src = glottal(n, rnd, VENN_F0, rel, amp, 0.55, 0.06, wow, thin if thin_last else None)
        out = formant_filter(src, fm, thin=thin if thin_last else None)
    else:
        src = glottal(n, rnd, NORA_F0, rel, amp, 0.72, 0.09, wow)
        out = formant_filter(src, fm, gains=(1.0, 0.45, 0.2), bws=(110, 150, 220))
        out = emphasis(out, 0.8)
        warm = lowpass(out, 480)  # low shelf: the human-presence warmth
        return [x + 0.4 * w for x, w in zip(out, warm)]
    return emphasis(out, 0.92)


def emphasis(xs: list[float], k: float) -> list[float]:
    """First-difference pre-emphasis: puts the formants back where a horn and small speakers live."""
    prev, out = 0.0, []
    for x in xs:
        out.append(x - k * prev)
        prev = x
    return out


def wax(xs: list[float], rnd: random.Random, crackle_rate: float = 55, crackle_gain: float = 0.18,
        hiss: float = 0.05) -> list[float]:
    """Through the horn and wax: 300-3000 Hz band, crackle and surface hiss on top."""
    v = bandlimit(xs, 300, 3000)
    peak = max(1e-9, max(abs(x) for x in v))
    v = [x / peak for x in v]
    c = crackle(len(v), rnd, crackle_rate, hiss)
    cp = max(1e-9, max(abs(x) for x in c))
    return [x + crackle_gain * y / cp for x, y in zip(v, c)]


def line(xs: list[float], rnd: random.Random, lo: float = 300, hi: float = 3000,
         hiss: float = 0.012, hum: float = 0.01) -> list[float]:
    """Channel C: a line signal. Dry, band-limited, a whisper of line hiss and mains."""
    v = bandlimit(xs, lo, hi)
    peak = max(1e-9, max(abs(x) for x in v))
    n = len(v)
    h = bandlimit(white(n, rnd), 1500, 4000)
    m = hum_tone(n, 60, [0.3, 1.0, 0.5])
    return [x / peak + hiss * a + hum * b for x, a, b in zip(v, h, m)]


# ---------------------------------------------------------------- loops

def write_loop(name: str, xs: list[float]) -> None:
    xs = seamless(xs, 1.0)
    r = rms(xs)
    m = max(abs(x) for x in xs)
    peak = min(0.98, LOOP_RMS * m / max(1e-9, r))
    write(OUT, name, xs, peak)


def write_shot(name: str, xs: list[float], fin: float = 0.004, fout: float = 0.01) -> None:
    write(OUT, name, fade_edges(xs, fin, fout), SHOT_PEAK)


def r04_room() -> list[float]:
    rnd = seed(1)
    n = n_of(13)
    bed = highpass(lowpass(lowpass(brown(n, rnd), 400), 400), 25)
    air = bandlimit(white(n, rnd), 250, 900)
    walk = smooth_walk(n, rnd, 2.6)
    rb, ra = rms(bed), rms(air)
    hum = hum_tone(n, 60, [1.0, 0.7, 0.2])
    rh = rms(hum)
    k = 10 ** (-30 / 20)
    return [(b / rb + 0.12 * a / ra) * (0.82 + 0.18 * w) + k * h / rh
            for b, a, w, h in zip(bed, air, walk, hum)]


def r04_motor() -> list[float]:
    rnd = seed(2)
    n = n_of(7)
    out = [0.0] * n
    period = 1 / 23
    gains = [rnd.uniform(0.8, 1.0) for _ in range(6)]  # a six-tooth gear: the same each turn
    tick = click(rnd, 0.02, 0.0015, [(820, 1.0, 0.004), (1650, 0.5, 0.002), (2900, 0.2, 0.0015)],
                 noise=0.6, noise_lp=2500)
    k = 0
    while k * period < 7:
        mix(out, tick, k * period, gains[k % 6] * (1.15 if k % 6 == 0 else 1.0))
        k += 1
    out = lowpass(lowpass(out, 1200), 1200)
    whirr = hum_tone(n, 90, [1.0, 0.45, 0.25, 0.1])
    rot = [1 + 0.12 * math.sin(TAU * 1.5 * i / SR) for i in range(n)]
    hiss = lowpass(white(n, rnd), 600)
    rt, rw = rms(out), rms(whirr)
    return [(t / rt) + 0.55 * (w / rw) * r + 0.25 * s for t, w, r, s in zip(out, whirr, rot, hiss)]


def r04_leak_wind() -> list[float]:
    rnd = seed(3)
    n = n_of(11)
    nz = white(n, rnd)
    body = biquad_bp(biquad_bp(nz, 800, 2.2), 800, 2.2)
    gust = smooth_walk(n, rnd, 1.4)
    whistle = biquad_bp(biquad_bp(white(n, rnd), 1100, 45), 1100, 45)
    wob = smooth_walk(n, rnd, 0.6)
    rb, rw = rms(body), rms(whistle)
    out = []
    for i in range(n):
        g = 0.25 + 0.75 * gust[i]
        out.append(g * body[i] / rb + 0.35 * g * g * (0.6 + 0.4 * wob[i]) * whistle[i] / rw)
    out = comb(out, 0.0024, 0.35)          # a narrow pipe
    return lowpass(lowpass(out, 2400), 2400)  # heard through the wall


def r04_leak_rain() -> list[float]:
    rnd = seed(4)
    n = n_of(11)
    out = [0.0] * n
    rate = 380 / SR
    for i in range(n):
        if rnd.random() < rate:
            f = rnd.uniform(1600, 4200)
            a = rnd.expovariate(1.0)
            tau = rnd.uniform(0.002, 0.006)
            for k in range(n_of(tau * 4)):
                if i + k < n:
                    t = k / SR
                    out[i + k] += a * math.sin(TAU * f * t) * math.exp(-t / tau) * min(1.0, k / 8)
    bed = white(n, rnd)
    out = [x + 0.25 * b for x, b in zip(out, bed)]
    out = bandlimit(out, 1500, 4000)
    return comb(out, 0.005, 0.55)


def r04_c_tone() -> list[float]:
    rnd = seed(5)
    n = n_of(13)
    hiss = bandlimit(white(n, rnd), 2000, 6000)
    rumble = bandlimit(white(n, rnd), 120, 900)
    hum = hum_tone(n, 47, [1.0, 0.6, 0.35])
    rh, rr, rm = rms(hiss), rms(rumble), rms(hum)
    out = [h / rh + 0.35 * r / rr + 0.18 * m / rm for h, r, m in zip(hiss, rumble, hum)]
    for at in (2.4, 7.3, 11.9):  # fabric shifting, somewhere larger
        length = rnd.uniform(0.55, 0.8)
        m = n_of(length)
        grains = smooth_walk(m, rnd, 0.03)
        fab = bandlimit(white(m, rnd), 300, 2200)
        rf = rms(fab)
        fab = [1.2 * f / rf * g * g * math.sin(math.pi * i / m) for i, (f, g) in enumerate(zip(fab, grains))]
        mix(out, fab, at)
    return smear(out, rnd, 0.3, 14, 0.35)


def r04_pressure() -> list[float]:
    n = n_of(15)
    out = []
    for i in range(n):
        t = i / SR
        swell = 0.55 + 0.45 * (0.5 - 0.5 * math.cos(TAU * t / 14))  # one breath per loop
        beat = 0.5 + 0.5 * math.cos(TAU * t / 7)                    # two slow beats per loop
        v = (math.sin(TAU * 31 * t) + 0.8 * math.sin(TAU * (31 + 1 / 7) * t)
             + 0.6 * math.sin(TAU * 46.5 * t) * (0.6 + 0.4 * beat)
             + 0.12 * math.sin(TAU * 93 * t) + 0.08 * math.sin(TAU * 139.5 * t))  # small speakers
        out.append(swell * v)
    return out


# ---------------------------------------------------------------- one-shots: apparatus

def throat_burst(rnd: random.Random, length: float, f0: float, strength: float) -> list[float]:
    n = n_of(length)
    out = []
    ph = 0.0
    nz = white(n, rnd)
    for i in range(n):
        t = i / SR
        x = i / n
        env = math.sin(math.pi * min(1.0, x / 0.25) / 2) * (math.cos(math.pi / 2 * max(0.0, x - 0.25) / 0.75) ** 1.5)
        ph += f0 * (1 + 0.15 * rnd.uniform(-1, 1)) * (1 - 0.25 * x) / SR
        pulse = 1.0 if (ph % 1.0) < 0.12 else 0.0
        out.append(strength * env * (0.7 * pulse + 0.6 * nz[i]))
    return out


def throat_clear_raw(rnd: random.Random) -> list[float]:
    out = silence(1.2)
    mix(out, throat_burst(rnd, 0.24, 95, 0.7), 0.12)
    mix(out, throat_burst(rnd, 0.36, 85, 1.0), 0.48)
    f = biquad_bp(out, 420, 2.0)
    g = biquad_bp(out, 1300, 3.0)
    return [a + 0.4 * b for a, b in zip(f, g)]


def throat_clear() -> list[float]:
    rnd = seed(7)
    out = throat_clear_raw(rnd)
    out = comb(out, 0.0016, 0.45)  # a short brass tube
    return bandlimit(out, 250, 2500)


def motor_click() -> list[float]:
    rnd = seed(8)
    out = silence(0.25)
    mix(out, click(rnd, 0.05, 0.001, [(2200, 1.0, 0.006), (3500, 0.5, 0.004), (900, 0.3, 0.01)]), 0.005)
    n = n_of(0.18)
    ph, chirp = 0.0, []
    for i in range(n):
        x = i / n
        ph += TAU * (180 + 420 * x ** 0.7) / SR
        chirp.append(0.22 * math.sin(math.pi * x) * (math.sin(ph) + 0.4 * math.sin(2 * ph)))
    return mix(out, chirp, 0.04)


def band_seat() -> list[float]:
    rnd = seed(9)
    out = silence(0.35)
    mix(out, swish(rnd, 0.26, 900, 4000, lambda x: math.sin(math.pi * x) ** 1.5 * (0.5 + 0.5 * x)), 0.0, 0.45)
    return mix(out, thock(rnd, 0.09, 170, 0.025), 0.255)


def band_lift() -> list[float]:
    rnd = seed(10)
    out = silence(0.3)
    mix(out, swish(rnd, 0.2, 1200, 4500, lambda x: x ** 2.2 * math.cos(math.pi / 2 * max(0.0, x - 0.85) / 0.15)), 0.0, 0.5)
    tap = lowpass(thock(rnd, 0.07, 260, 0.012, 0.004), 900)
    return mix(out, tap, 0.215, 0.8)


def band_click() -> list[float]:
    rnd = seed(11)
    out = silence(0.12)
    mix(out, click(rnd, 0.02, 0.0008, [(4100, 0.5, 0.002), (1900, 0.4, 0.003)], noise=0.7), 0.004, 0.6)
    mix(out, click(rnd, 0.1, 0.0008, [(3200, 1.0, 0.03), (6100, 0.2, 0.01), (1900, 0.3, 0.004)], noise=0.6), 0.012)
    return out


def needle_down() -> list[float]:
    rnd = seed(12)
    out = silence(0.5)
    mix(out, thock(rnd, 0.14, 120, 0.035), 0.04, 0.9)
    mix(out, click(rnd, 0.05, 0.002, [(1400, 0.5, 0.008), (2600, 0.3, 0.005)]), 0.045, 0.5)
    n = n_of(0.28)
    cr = crackle(n, rnd, 220, 0.12)
    cp = max(abs(x) for x in cr)
    cr = [0.55 * x / cp * min(1.0, i / n_of(0.03)) * (1 - 0.4 * i / n) for i, x in enumerate(cr)]
    return mix(out, cr, 0.21)


def needle_skip() -> list[float]:
    rnd = seed(13)
    out = silence(0.4)
    a = n_of(SUDDEN_ATTACK)
    pop = click(rnd, 0.06, SUDDEN_ATTACK, [(1800, 0.8, 0.008), (700, 0.6, 0.012), (3600, 0.4, 0.004)], noise=1.2)
    mix(out, pop, 0.01)
    # scratch: a noise burst whose band sweeps down as the needle skids
    m = n_of(0.08)
    nz = white(m, rnd)
    scr, y, y2 = [], 0.0, 0.0
    for i in range(m):
        fc = 4200 - 3300 * i / m
        c = 1 - math.exp(-TAU * fc / SR)
        y += c * (nz[i] - y)
        y2 += c * (y - y2)
        env = (0.5 - 0.5 * math.cos(math.pi * i / a)) if i < a else math.exp(-(i - a) / n_of(0.03))
        scr.append(0.7 * env * (nz[i] - y2))
    mix(out, scr, 0.012)
    n = n_of(0.3)
    cr = crackle(n, rnd, 600, 0.1)
    cp = max(abs(x) for x in cr)
    cr = [0.5 * x / cp * (0.5 - 0.5 * math.cos(math.pi * min(1.0, i / n_of(0.02)))) * math.exp(-i / n_of(0.12))
          for i, x in enumerate(cr)]
    return mix(out, cr, 0.08)


def cylinder_coast() -> list[float]:
    rnd = seed(17)
    n = n_of(3.0)
    nz = lowpass(white(n, rnd), 1500)
    out, ph, rev = [], 0.0, 0.0
    end = 2.7
    for i in range(n):
        t = i / SR
        if t < end:
            f = 60 + 80 * math.exp(-t / 0.95)
            ph += TAU * f / SR
            rev += (f / 140) * 0.5 / SR * 1.25    # one revolution over the coast
            swirl = 0.75 + 0.25 * math.sin(TAU * rev)
            env = min(1.0, t / 0.08) * (1 - t / end) ** 0.6
            out.append(env * swirl * (math.sin(ph) + 0.35 * math.sin(2 * ph) + 0.3 * math.sin(3 * ph)
                                      + 0.25 * nz[i]))
        else:
            out.append(0.0)
    out = scale(out, 0.55)
    for at, g in ((0.62, 0.5), (1.72, 0.42)):  # the seam, each half-turn
        mix(out, click(rnd, 0.04, 0.002, [(2400, 1.0, 0.004), (1300, 0.6, 0.006)], noise=0.5), at, g)
    mix(out, click(rnd, 0.08, 0.002, [(1100, 0.8, 0.012), (2300, 0.5, 0.006)], noise=0.4), 2.74, 0.6)
    return mix(out, thock(rnd, 0.1, 140, 0.02), 2.745, 0.35)


def printer_chatter() -> list[float]:
    rnd = seed(18)
    out = silence(2.5)
    rate = smooth_walk(n_of(2.5), rnd, 0.4)
    t = 0.04
    end = 1.95
    while t < end:
        g = rnd.uniform(0.55, 1.0)
        f1 = rnd.uniform(1600, 2100)
        strike = click(rnd, 0.04, 0.0012, [(f1, 1.0, 0.006), (f1 * 1.7, 0.4, 0.004), (260, 0.6, 0.012)], noise=0.8)
        mix(out, strike, t, g)
        r = 8 + 6 * rate[min(len(rate) - 1, n_of(t))]
        t += rnd.expovariate(r) * 0.6 + 0.4 / r
    k = 0.3
    while k < end:  # platen ratchet
        for j in range(3):
            mix(out, click(rnd, 0.015, 0.0008, [(4300, 0.6, 0.002), (2800, 0.4, 0.002)], noise=0.5), k + j * 0.011, 0.35)
        k += 0.6
    # carriage return: a slide, then a bell-less stop
    mix(out, swish(rnd, 0.32, 500, 2500, lambda x: math.sin(math.pi * x) * (0.4 + 0.6 * x)), 2.0, 0.35)
    mix(out, thock(rnd, 0.12, 190, 0.03), 2.31, 0.8)
    return mix(out, click(rnd, 0.05, 0.001, [(1500, 0.6, 0.01), (3000, 0.3, 0.006)]), 2.312, 0.45)


def slider_step() -> list[float]:
    rnd = seed(19)
    out = silence(0.12)
    c = lowpass(click(rnd, 0.06, 0.004, [(1100, 0.8, 0.008), (2200, 0.3, 0.004)], noise=0.6), 1600)
    mix(out, c, 0.004)
    return mix(out, thock(rnd, 0.06, 220, 0.012, 0.004), 0.004, 0.5)


def toggle_channel() -> list[float]:
    rnd = seed(20)
    out = silence(0.15)
    mix(out, click(rnd, 0.02, 0.002, [(1200, 0.4, 0.004)], noise=0.4), 0.006, 0.35)
    return mix(out, click(rnd, 0.1, 0.0008, [(1500, 0.8, 0.01), (2800, 0.7, 0.006), (4200, 0.4, 0.004)], noise=0.7), 0.03)


def switch_motor() -> list[float]:
    rnd = seed(26)
    out = silence(0.9)
    mix(out, swish(rnd, 0.09, 600, 3000, lambda x: math.sin(math.pi * x)), 0.0, 0.25)  # blades scrape
    mix(out, thock(rnd, 0.2, 110, 0.05), 0.085)
    mix(out, click(rnd, 0.1, 0.0015, [(900, 0.7, 0.02), (1900, 0.6, 0.012), (3100, 0.3, 0.006)]), 0.086, 0.8)
    # the motor kicked: a surge, then a long pitch fall (reads as a change of state either way)
    n = n_of(0.75)
    ph, mot = 0.0, []
    nz = lowpass(white(n, rnd), 900)
    for i in range(n):
        x = i / n
        f = 110 + 60 * math.sin(math.pi * min(1.0, x / 0.2) / 2) - 85 * max(0.0, x - 0.2) ** 0.8
        ph += TAU * f / SR
        env = math.sin(math.pi * min(1.0, x / 0.15) / 2) * (1 - x) ** 1.3
        mot.append(0.35 * env * (math.sin(ph) + 0.5 * math.sin(2 * ph) + 0.3 * math.sin(3 * ph) + 0.3 * nz[i]))
    return mix(out, mot, 0.12)


def key_channel() -> list[float]:
    rnd = seed(27)
    out = silence(0.2)
    mix(out, click(rnd, 0.1, 0.001, [(2400, 1.0, 0.025), (3900, 0.5, 0.012), (5100, 0.3, 0.006)], noise=0.6), 0.004)
    n = n_of(0.08)
    buzz = [0.2 * math.sin(math.pi * i / n) * (1 if math.sin(TAU * 120 * i / SR) > 0 else -1) for i in range(n)]
    buzz = bandlimit(buzz, 300, 3000)
    return mix(out, buzz, 0.03)


def witness_key() -> list[float]:
    rnd = seed(28)
    out = silence(0.4)
    mix(out, thock(rnd, 0.2, 85, 0.07), 0.005)
    mix(out, thock(rnd, 0.12, 200, 0.03), 0.006, 0.5)
    n = n_of(0.3)
    spring = [0.12 * math.sin(TAU * 420 * (i / SR) * (1 + 0.01 * math.sin(TAU * 18 * i / SR))) * math.exp(-i / n_of(0.07))
              for i in range(n)]
    mix(out, spring, 0.01)
    mix(out, click(rnd, 0.05, 0.001, [(2000, 0.8, 0.006), (3300, 0.4, 0.004)]), 0.19, 0.6)
    m = n_of(0.09)
    hum = bandlimit([0.25 * math.sin(math.pi * i / m) * math.sin(TAU * 100 * i / SR) ** 3 for i in range(m)], 150, 3000)
    return mix(out, hum, 0.2)


def reject_buzz() -> list[float]:
    rnd = seed(29)
    out = silence(0.8)
    n = n_of(0.58)
    a = n_of(SUDDEN_ATTACK)
    buzz = []
    for i in range(n):
        t = i / SR
        s = math.sin(TAU * 180 * t)
        sq = math.tanh(4 * s)  # square-ish
        env = (0.5 - 0.5 * math.cos(math.pi * i / a)) if i < a else 1.0
        env *= 1.0 if i < n - n_of(0.02) else 0.5 + 0.5 * math.cos(math.pi * (i - n + n_of(0.02)) / n_of(0.02))
        buzz.append(0.6 * env * sq * (0.9 + 0.1 * math.sin(TAU * 7 * t)))
    mix(out, lowpass(buzz, 3500), 0.004)
    t = 0.006
    while t < 0.32:  # relay chatter
        mix(out, click(rnd, 0.015, SUDDEN_ATTACK * 0.7, [(2600, 0.6, 0.003), (4100, 0.3, 0.002)], noise=0.6), t, 0.4)
        t += rnd.uniform(0.018, 0.035)
    mix(out, thock(rnd, 0.15, 150, 0.035, SUDDEN_ATTACK), 0.62)  # the tape stamp
    return mix(out, click(rnd, 0.08, SUDDEN_ATTACK, [(1300, 0.7, 0.01), (2500, 0.4, 0.006)], noise=0.7), 0.621, 0.6)


def line_hum(n: int, rnd: random.Random) -> list[float]:
    h = hum_tone(n, 60, [0.5, 1.0, 0.6, 0.3])
    hiss = bandlimit(white(n, rnd), 800, 3500)
    return [0.5 * a + 0.12 * b for a, b in zip(h, hiss)]


def relay_on() -> list[float]:
    rnd = seed(30)
    out = silence(0.4)
    mix(out, click(rnd, 0.04, 0.0015, [(1900, 0.8, 0.005), (3000, 0.4, 0.003)], noise=0.5), 0.01, 0.8)
    n = n_of(0.34)
    hm = line_hum(n, rnd)
    hm = [x * (0.5 - 0.5 * math.cos(math.pi * min(1.0, i / n_of(0.25)))) for i, x in enumerate(hm)]
    return mix(out, hm, 0.05, 0.9)


def relay_off() -> list[float]:
    rnd = seed(31)
    out = silence(0.5)
    cut = 0.14
    n = n_of(cut)
    hm = line_hum(n, rnd)
    a, r = n_of(SUDDEN_ATTACK), n_of(0.004)
    hm = [x * (0.5 - 0.5 * math.cos(math.pi * min(1.0, i / a))) *
          (1.0 if i < n - r else 0.5 + 0.5 * math.cos(math.pi * (i - n + r) / r)) for i, x in enumerate(hm)]
    mix(out, hm, 0.0, 0.7)
    return mix(out, click(rnd, 0.05, SUDDEN_ATTACK, [(1700, 0.9, 0.006), (2900, 0.5, 0.004)], noise=0.6), cut - 0.002)


# ---------------------------------------------------------------- one-shots: voices

def wax_fragment(nn: int, dur: float, t0: float, t1: float) -> list[float]:
    rnd = seed(nn)
    v = voice(dur, rnd, "venn", [(t0, t1)], cut_abrupt=True, wow=0.006)
    out = wax(v, rnd)
    # the needle lifts at the cut: crackle and voice stop together within 4 ms
    c, r = n_of(t1), n_of(0.004)
    for i in range(len(out)):
        if i >= c:
            out[i] = 0.0
        elif i > c - r:
            out[i] *= (c - i) / r
    return out


def chair_creak(rnd: random.Random) -> list[float]:
    """A 1.2 s pitched wood groan: stick-slip pulses at a wandering pitch through two resonances."""
    n = n_of(1.2)
    wander = smooth_walk(n, rnd, 0.25)
    ph, out = 0.0, []
    for i in range(n):
        x = i / n
        ph += (150 + 60 * wander[i] - 30 * x) / SR
        if ph >= 1:
            ph -= 1
        slip = 1.0 if ph < 0.08 else 0.0
        env = math.sin(math.pi * min(1.0, x / 0.15) / 2) * math.cos(math.pi / 2 * max(0.0, x - 0.6) / 0.4)
        out.append(env * slip * rnd.uniform(0.7, 1.0))
    a = biquad_bp(out, 420, 4)
    b = biquad_bp(out, 980, 6)
    return [p + 0.6 * q for p, q in zip(a, b)]


def inhale(rnd: random.Random, length: float, rise: float, f1: float, f2: float) -> list[float]:
    """An inhale with no exhale: shaped noise through breath formants that open as the lungs fill."""
    n = n_of(length)
    nz = white(n, rnd)
    walk = smooth_walk(n, rnd, 0.3)
    env = []
    for i in range(n):
        x = i / n
        e = math.sin(math.pi / 2 * min(1.0, x / rise)) ** 1.6
        e *= 1.0 if x < 0.93 else math.cos(math.pi / 2 * (x - 0.93) / 0.07)  # stops; held
        env.append(e * (0.85 + 0.15 * walk[i]))
    src = [a * b for a, b in zip(nz, env)]
    out = [0.0] * n
    for fc, g, q in ((f1, 1.0, 2.5), (f2, 0.6, 4.0), (2600, 0.25, 5.0)):
        for i, y in enumerate(biquad_bp(src, fc, q)):
            out[i] += g * y
    return out


def recording_p02() -> list[float]:
    rnd = seed(16)
    dur = 16.0
    n = n_of(dur)
    v = voice(dur, rnd, "venn", [(0.6, 4.8), (5.4, 8.4), (11.8, 15.2)], wow=0.006)
    vp = max(abs(x) for x in v)
    v = [x / vp for x in v]
    mix(v, scale(chair_creak(rnd), 0.55), 9.0)
    tc = throat_clear_raw(rnd)
    tp = max(abs(x) for x in tc)
    mix(v, [0.6 * x / tp for x in tc], 9.8 - 0.12)  # the first burst lands at 9.8 s
    body = bandlimit(v, 300, 3000)
    bp = max(abs(x) for x in body)
    body = [x / bp for x in body]
    # the unattributed breath: smaller, closer, wider band, above the hiss as Venn never is
    br = bandlimit(inhale(rnd, 0.7, 0.6, 700, 1700), 220, 4200)
    brp = max(abs(x) for x in br)
    mix(body, [0.8 * x / brp for x in br], 10.8)
    c = crackle(n, rnd, 55, 0.05)
    cp = max(abs(x) for x in c)
    motor = hum_tone(n, 180, [1.0, 0.4, 0.2])
    stop = n_of(15.6)
    out = []
    for i in range(n):
        m = 1.0 if i < stop - n_of(0.03) else max(0.0, (stop - i) / n_of(0.03))
        out.append(body[i] + 0.18 * c[i] / cp + 0.035 * m * motor[i])
    # the hiss rides in and out with the needle at the file edges
    return fade_edges(out, 0.08, 0.2)


def cadence(dur: float, rnd: random.Random, who: str, t0: float, t1: float) -> list[float]:
    v = voice(dur, rnd, who, [(t0, t1)], wow=0.005)
    v = bandlimit(v, 300, 3000)
    p = max(abs(x) for x in v)
    return [x / p for x in v]


def session(dur: float, rnd: random.Random, parts, bells, crackle_gain: float = 0.12) -> list[float]:
    n = n_of(dur)
    out = [0.0] * n
    for part, g in parts:
        mix(out, part, 0.0, g)
    for at in bells:
        mix(out, bell(rnd), at, 0.55)
    c = crackle(n, rnd, 45, 0.05)
    cp = max(abs(x) for x in c)
    return [x + crackle_gain * y / cp for x, y in zip(out, c)]


def mix_overlap() -> list[float]:
    rnd = seed(21)
    venn = cadence(4.0, rnd, "venn", 0.6, 3.3)
    nora = cadence(4.0, rnd, "nora", 0.95, 3.65)
    return session(4.0, rnd, [(venn, 0.8), (nora, 0.75)], [0.5, 0.85])


def mix_combined() -> list[float]:
    rnd = seed(22)
    dur = 4.0
    n = n_of(dur)
    tracks = voice_tracks(n, rnd, [(0.3, 3.7)])  # one sentence: one cadence, two throats
    venn = voice(dur, rnd, "venn", [], tracks=tracks, wow=0.005)
    nora = voice(dur, rnd, "nora", [], tracks=tracks, wow=0.005)
    vp, np_ = max(abs(x) for x in venn), max(abs(x) for x in nora)
    j, w = n_of(2.0), n_of(0.04)
    joined = []
    for i in range(n):
        u = min(1.0, max(0.0, (i - j + w / 2) / w))
        u = 0.5 - 0.5 * math.cos(math.pi * u)
        joined.append((1 - u) * venn[i] / vp + u * nora[i] / np_)
    joined = bandlimit(joined, 300, 3000)
    p = max(abs(x) for x in joined)
    return session(dur, rnd, [([x / p for x in joined], 0.85)], [0.2])


def mix_venn() -> list[float]:
    rnd = seed(23)
    return session(2.8, rnd, [(cadence(2.8, rnd, "venn", 0.4, 2.6), 0.85)], [0.2])


def mix_nora() -> list[float]:
    rnd = seed(24)
    v = cadence(2.8, rnd, "nora", 0.4, 2.6)
    v = smear(v, rnd, 0.09, 8, 0.25)  # a tiny room bloom: she was somewhere with air
    v = bandlimit(v, 300, 3000)
    p = max(abs(x) for x in v)
    return session(2.8, rnd, [([x / p for x in v], 0.85)], [0.2])


def breath_c() -> list[float]:
    rnd = seed(25)
    n = n_of(2.2)
    out = [0.0] * n
    b = inhale(rnd, 1.95, 0.7, 650, 1600)
    mix(out, b, 0.1)
    return line(out, rnd, 200, 3500, hiss=0.02, hum=0.012)


def swallow(rnd: random.Random) -> list[float]:
    out = silence(0.3)
    mix(out, click(rnd, 0.03, 0.002, [(900, 0.5, 0.004)], noise=0.5, noise_lp=2500), 0.0, 0.5)
    n = n_of(0.12)
    ph, gulp = 0.0, []
    for i in range(n):
        x = i / n
        ph += TAU * (520 - 220 * x) / SR
        gulp.append(0.6 * math.sin(math.pi * x) ** 2 * math.sin(ph))
    mix(out, gulp, 0.06)
    return mix(out, thock(rnd, 0.08, 180, 0.02), 0.17, 0.4)


def venn_line(nn: int, dur: float, phrases, extra=None, slow_end: float = 1.0, thin_last: bool = False) -> list[float]:
    rnd = seed(nn)
    v = voice(dur, rnd, "venn", phrases, rate=3.2, slow_end=slow_end, thin_last=thin_last, onset=0.05)
    p = max(abs(x) for x in v)
    v = [x / p for x in v]
    if extra:
        extra(v, rnd)
    return line(v, rnd, hiss=0.015, hum=0.012)


def venn_answer_where() -> list[float]:
    return venn_line(32, 8.0, [(0.4, 4.6), (5.4, 7.6)])


def venn_answer_whole() -> list[float]:
    return venn_line(33, 8.0, [(0.4, 3.8), (5.0, 7.4)],
                     extra=lambda v, rnd: mix(v, swallow(rnd), 4.3, 0.7))


def venn_answer_need() -> list[float]:
    return venn_line(34, 11.0, [(0.4, 5.2), (6.0, 10.4)], slow_end=0.5, thin_last=True)


def venn_funnel() -> list[float]:
    rnd = seed(35)
    dur = 6.0
    v = voice(dur, rnd, "venn", [(0.2, 5.6)], rate=3.6, onset=SUDDEN_ATTACK + 0.004)
    p = max(abs(x) for x in v)
    v = [x / p for x in v]
    horn = biquad_bp(biquad_bp(v, 750, 2.4), 750, 2.4)
    hp = max(abs(x) for x in horn)
    out = [0.6 * x + 1.0 * h / hp for x, h in zip(v, horn)]
    out = comb(out, 1 / 750, 0.3)   # the bell of the horn reinforcing 750 Hz and its octave
    return highpass(out, 70)        # full band, dry, in the room: no crackle, hum or motor


# ---------------------------------------------------------------- build

def main() -> None:
    print(f"Writing to {OUT}")
    for name, fn in [("r04_room", r04_room), ("r04_motor", r04_motor), ("r04_leak_wind", r04_leak_wind),
                     ("r04_leak_rain", r04_leak_rain), ("r04_c_tone", r04_c_tone),
                     ("r04_pressure", r04_pressure)]:
        write_loop(name, fn())
    shots = [
        ("throat_clear", throat_clear), ("motor_click", motor_click), ("band_seat", band_seat),
        ("band_lift", band_lift), ("band_click", band_click), ("needle_down", needle_down),
        ("needle_skip", needle_skip),
        ("wax_fragment_1", lambda: wax_fragment(14, 1.0, 0.1, 0.9)),
        ("wax_fragment_2", lambda: wax_fragment(15, 2.4, 0.1, 2.3)),
        ("recording_p02", recording_p02), ("cylinder_coast", cylinder_coast),
        ("printer_chatter", printer_chatter), ("slider_step", slider_step),
        ("toggle_channel", toggle_channel), ("mix_overlap", mix_overlap),
        ("mix_combined", mix_combined), ("mix_venn", mix_venn), ("mix_nora", mix_nora),
        ("breath_c", breath_c), ("switch_motor", switch_motor), ("key_channel", key_channel),
        ("witness_key", witness_key), ("reject_buzz", reject_buzz), ("relay_on", relay_on),
        ("relay_off", relay_off), ("venn_answer_where", venn_answer_where),
        ("venn_answer_whole", venn_answer_whole), ("venn_answer_need", venn_answer_need),
        ("venn_funnel", venn_funnel),
    ]
    sudden = {"needle_skip", "reject_buzz", "relay_off", "venn_funnel"}
    for name, fn in shots:
        xs = fn()
        if name in ("wax_fragment_1", "wax_fragment_2"):
            write_shot(name, xs, 0.004, 0.001)  # the abrupt cut is the content
        elif name in sudden:
            write_shot(name, xs, SUDDEN_ATTACK, 0.01)
        else:
            write_shot(name, xs)


if __name__ == "__main__":
    main()
