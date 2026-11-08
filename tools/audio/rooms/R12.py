#!/usr/bin/env python3
"""R12 sounds: the Severance Chamber (Tide IX, P25-P27) and both endings.

Standard library only, via tools/audio/common.py. One fixed seed per sound,
random.Random(1931_12_00 + k) with k the sound's index in SOUNDS below, so a rerun writes
byte-identical 22050 Hz mono WAVs to assets/audio/R12/.

Levels: loops are mastered to about -18 dBFS RMS, one-shots peak at -3 dBFS; the view sets
the final level (SFX_DB, LoopMixer targets). The SFX_DB / SFX_SOFT tables for the view are
at the bottom of this file.

Tide IX has no startle sounds. Every transient here rises over at least 9 ms (raised cosine, 10-90 % in 5.3 ms),
heavy impacts over 8-12 ms; check_attacks() below fails the build if any file jumps from near
silence to near full scale in under 4 ms.

Loops: tonal carriers are quantized to whole cycles per loop (deviation under 0.03 Hz) so the
wrap is phase-coherent; each loop is rendered one second long and closed with seamless(1.0),
which makes the file's last sample run straight into its first. check_wrap() reports the
wrap step against the loop's median sample step.

Voices: no recorded speech, never words. Venn is a glottal pulse train near 105 Hz through three
moving resonators whose targets are pulled halfway toward a neutral vowel, so only cadence
survives; venn_last then goes through a small grille (a horn band-pass near 750 Hz, light hiss).

    python3 tools/build_audio.py R12
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F401,F403
from common import SR, TAU, band, brown, echo, env_ad, highpass, lowpass, seamless, smooth_walk, white, write  # noqa: E402

OUT = room_out("R12")  # noqa: F405

LOOP_RMS = 10 ** (-18 / 20)
SHOT_PEAK = 10 ** (-3 / 20)
ATTACK = 0.009        # every transient: raised-cosine rise over 9 ms (10-90 % in 5.3 ms)
SOFT_ATTACK = 0.012   # heavy, padded impacts

# Indicator hum notes, in panel order (also the line_out_1..8 order).
INDICATORS = [("ROOK", 110.0), ("BELL", 123.47), ("IVES", 130.81), ("LUSK", 146.83),
              ("PRYCE", 164.81), ("DOANE", 174.61), ("HART", 196.0), ("TULL", 207.65)]

VENN_F0 = 105.0
C4 = 261.63
C4_QFLAT = C4 * 2 ** (-0.5 / 12)   # the shared motif's quarter-tone-flat C
MOTIF = [293.66, 349.23, 440.00, 392.00, 349.23, 329.63, 293.66, 277.18]


def seed(k: int) -> random.Random:
    return random.Random(1931_12_00 + k)


def n_of(seconds: float) -> int:
    return int(round(seconds * SR))


def zeros(seconds: float) -> list[float]:
    return [0.0] * n_of(seconds)


def mix(dst: list[float], src: list[float], at_s: float, gain: float = 1.0) -> list[float]:
    start = n_of(at_s)
    for i, x in enumerate(src):
        j = start + i
        if 0 <= j < len(dst):
            dst[j] += gain * x
    return dst


def scale(xs: list[float], g: float) -> list[float]:
    return [x * g for x in xs]


def peak_of(xs: list[float]) -> float:
    return max(1e-12, max(abs(x) for x in xs))


def unit(xs: list[float]) -> list[float]:
    p = peak_of(xs)
    return [x / p for x in xs]


def rms(xs: list[float]) -> float:
    return math.sqrt(sum(x * x for x in xs) / max(1, len(xs)))


def rc(x: float) -> float:
    """Raised-cosine ramp 0..1 for x in 0..1 (clamped)."""
    x = min(1.0, max(0.0, x))
    return 0.5 - 0.5 * math.cos(math.pi * x)


def fade_edges(xs: list[float], fin: float = ATTACK, fout: float = 0.012) -> list[float]:
    a, b, n = max(1, n_of(fin)), max(1, n_of(fout)), len(xs)
    for i in range(min(a, n)):
        xs[i] *= rc(i / a)
    for i in range(min(b, n)):
        xs[n - 1 - i] *= rc(i / b)
    return xs


def shape(xs: list[float], fn) -> list[float]:
    """Multiplies xs by fn(t) with t in seconds."""
    return [x * fn(i / SR) for i, x in enumerate(xs)]


def window(t: float, t0: float, t1: float, fin: float, fout: float) -> float:
    """1 inside [t0, t1] with raised-cosine edges of fin / fout, 0 outside."""
    if t < t0 or t > t1:
        return 0.0
    g = 1.0
    if fin > 0 and t < t0 + fin:
        g = rc((t - t0) / fin)
    if fout > 0 and t > t1 - fout:
        g = min(g, rc((t1 - t) / fout))
    return g


# ---------------------------------------------------------------- filters

def biquad_bp(xs: list[float], fc: float, q: float) -> list[float]:
    """Two-pole resonant band-pass, 0 dB at the peak."""
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
    """Steeper band limit: two one-pole high-passes at lo, two one-pole low-passes at hi."""
    return lowpass(lowpass(highpass(highpass(xs, lo), lo), hi), hi)


def lowpass_sweep(xs: list[float], fc_of) -> list[float]:
    """One-pole low-pass whose cutoff follows fc_of(t) (updated every 16 samples)."""
    y, a, out = 0.0, 0.0, []
    for i, x in enumerate(xs):
        if i % 16 == 0:
            a = 1 - math.exp(-TAU * fc_of(i / SR) / SR)
        y += a * (x - y)
        out.append(y)
    return out


def bp_sweep(xs: list[float], fc_of, q: float) -> list[float]:
    """Resonant band-pass whose centre follows fc_of(t) (updated every 16 samples)."""
    x1 = x2 = y1 = y2 = 0.0
    b0 = b2 = a1 = a2 = 0.0
    out = []
    for i, x in enumerate(xs):
        if i % 16 == 0:
            w = TAU * fc_of(i / SR) / SR
            alpha = math.sin(w) / (2 * q)
            a0 = 1 + alpha
            b0, b2 = alpha / a0, -alpha / a0
            a1, a2 = -2 * math.cos(w) / a0, (1 - alpha) / a0
        y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def smear(xs: list[float], rnd: random.Random, span_s: float, taps: int, gain: float) -> list[float]:
    """Seeded early reflections spread over span_s: the size and dryness of a space."""
    out = list(xs)
    for _ in range(taps):
        d = n_of(rnd.uniform(0.008, span_s))
        g = gain * math.exp(-2.5 * d / (span_s * SR)) * rnd.choice((-1, 1))
        for i in range(d, len(out)):
            out[i] += g * xs[i - d]
    return out


# ---------------------------------------------------------------- loop-coherent tones

def loop_freq(f: float, loop_s: float) -> float:
    """f rounded to a whole number of cycles per loop, so the wrap is phase-coherent."""
    return round(f * loop_s) / loop_s


def tone(n: int, f: float, phase: float = 0.0) -> list[float]:
    w = TAU * f / SR
    return [math.sin(w * i + phase) for i in range(n)]


# ---------------------------------------------------------------- small sources

def click(rnd: random.Random, length: float, modes, attack: float = ATTACK, noise: float = 0.3,
          noise_lo: float = 600, noise_hi: float = 5000, noise_tau: float = 0.006) -> list[float]:
    """A mechanical contact: raised-cosine attack, decaying modal partials, a short noise body."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = bandlimit(white(n, rnd), noise_lo, noise_hi)
    out = []
    for i in range(n):
        t = i / SR
        td = max(0.0, t - attack)   # decay starts once the attack is complete
        v = sum(amp * math.sin(TAU * f * t) * math.exp(-td / tau) for f, amp, tau in modes)
        v += noise * nz[i] * 3 * math.exp(-td / noise_tau)
        out.append((rc(i / a) if i < a else 1.0) * v)
    return out


def thock(rnd: random.Random, length: float, f: float, tau: float, attack: float = SOFT_ATTACK,
          body_lp: float = 700, body: float = 0.8) -> list[float]:
    """A dull padded impact: a falling sine thump with a lowpassed noise body."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(white(n, rnd), body_lp)
    nzp = peak_of(nz)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ph += TAU * f * (1 + 0.35 * math.exp(-t / 0.012)) / SR
        env = rc(i / a) if i < a else 1.0
        td = max(0.0, t - attack)
        out.append(env * math.exp(-td / tau) * (math.sin(ph) + body * nz[i] / nzp))
    return out


def relay(rnd: random.Random, pitch: float = 1.0, length: float = 0.08) -> list[float]:
    """A small relay armature tick (soft, 5 ms rise)."""
    return click(rnd, length, [(1650 * pitch, 1.0, 0.009), (3900 * pitch, 0.35, 0.004),
                               (620 * pitch, 0.35, 0.016)], noise=0.22)


def noise_band(rnd: random.Random, seconds: float, lo: float, hi: float) -> list[float]:
    return unit(bandlimit(white(n_of(seconds), rnd), lo, hi))


def rough(rnd: random.Random, n: int, step_s: float, depth: float) -> list[float]:
    """A grain envelope (1 - depth .. 1): friction and paper texture."""
    w = smooth_walk(n, rnd, step_s)
    return [1 - depth + depth * x for x in w]


def slide(rnd: random.Random, seconds: float, lo: float, hi: float, fin: float, fout: float,
          grain_s: float = 0.012, grain: float = 0.6) -> list[float]:
    """Friction: band noise under a grain envelope, raised-cosine in and out."""
    n = n_of(seconds)
    nz = noise_band(rnd, seconds, lo, hi)
    g = rough(rnd, n, grain_s, grain)
    return [x * g[i] * window(i / SR, 0, seconds, fin, fout) for i, x in enumerate(nz)]


def buzz(n: int, f: float, attack: float, release: float, bright: float = 1800) -> list[float]:
    """A dim electromechanical buzz: a soft-clipped pulse at f, lowpassed, smooth envelope."""
    out = []
    for i in range(n):
        t = i / SR
        ph = (f * t) % 1.0
        v = math.tanh(3 * math.sin(TAU * ph)) + 0.25 * math.sin(TAU * 2 * f * t)
        out.append(v * window(t, 0, n / SR, attack, release))
    return lowpass(lowpass(out, bright), bright)


def felt_tone(f: float, seconds: float, tau: float, attack: float = 0.012,
              release: float = 0.3, partials=((1, 1.0), (2.0, 0.28), (3.01, 0.09), (4.03, 0.03))) -> list[float]:
    """A felt-hammer tone: near-harmonic partials, a soft rise, exponential decay."""
    n = n_of(seconds)
    out = []
    for i in range(n):
        t = i / SR
        v = sum(a * math.sin(TAU * f * k * t) * math.exp(-t * k / tau) for k, a in partials)
        out.append(v * window(t, 0, seconds, attack, release))
    return out


def pluck(rnd: random.Random, f: float, seconds: float, damp: float = 0.9985, bright: float = 2600,
          release: float = 0.4) -> list[float]:
    """Karplus-Strong string with an all-pass fractional delay, so the pitch is exact."""
    n = n_of(seconds)
    total = SR / f - 0.5            # the two-point average adds half a sample
    d = int(total)
    frac = total - d
    if frac < 0.15:
        d -= 1
        frac += 1
    c = (1 - frac) / (1 + frac)
    buf = lowpass(lowpass(white(d, rnd), bright), bright)
    p = peak_of(buf)
    buf = [x / p for x in buf]
    mean = sum(buf) / d
    buf = [x - mean for x in buf]
    ax1 = ay1 = 0.0
    out = []
    for i in range(n):
        k = i % d
        s = buf[k]
        avg = damp * 0.5 * (s + buf[(k + 1) % d])
        y = c * avg + ax1 - c * ay1
        ax1, ay1 = avg, y
        buf[k] = y
        out.append(s)
    out = highpass(out, 60)
    return [x * window(i / SR, 0, seconds, 0.006, release) for i, x in enumerate(out)]


def warm_note(rnd: random.Random, f: float, seconds: float, tau: float, release: float = 0.5) -> list[float]:
    """The human motif's voice: a plucked string doubled by a soft felt-hammer tone."""
    s = unit(pluck(rnd, f, seconds, release=release))
    h = unit(felt_tone(f, seconds, tau, release=release))
    return [0.62 * a + 0.38 * b for a, b in zip(s, h)]


def typestrike(rnd: random.Random, weight: float = 1.0) -> list[float]:
    """A felt-damped typewriter strike: type-bar swish, a muted platen thock, a dull tick."""
    out = zeros(0.16)
    sw = slide(rnd, 0.035, 1200, 4500, 0.012, 0.01, grain=0.3)
    mix(out, sw, 0.0, 0.18)
    mix(out, thock(rnd, 0.12, 165 * rnd.uniform(0.95, 1.05), 0.022, attack=ATTACK, body=1.1), 0.03, 0.8 * weight)
    mix(out, click(rnd, 0.06, [(1150 * rnd.uniform(0.96, 1.04), 0.6, 0.007), (2350, 0.3, 0.004)],
                   noise=0.35, noise_lo=800, noise_hi=3500, noise_tau=0.004), 0.03, 0.55 * weight)
    return out


def scribble(rnd: random.Random, seconds: float, lo: float, hi: float, stroke: tuple[float, float],
             gap: tuple[float, float], grain_s: float, grain: float) -> list[float]:
    """Writing: seeded strokes of grainy band noise with soft lifts between them."""
    n = n_of(seconds)
    nz = noise_band(rnd, seconds, lo, hi)
    body = noise_band(rnd, seconds, 300, 1200)
    g = rough(rnd, n, grain_s, grain)
    env = [0.0] * n
    t = 0.04
    while t < seconds - 0.08:
        d = min(rnd.uniform(*stroke), seconds - 0.04 - t)
        a = rnd.uniform(0.55, 1.0)
        for i in range(n_of(t), min(n, n_of(t + d))):
            env[i] = max(env[i], a * window(i / SR, t, t + d, 0.015, 0.025))
        t += d + rnd.uniform(*gap)
    return [env[i] * g[i] * (nz[i] + 0.35 * body[i]) for i in range(n)]


def gull_cry(rnd: random.Random, seconds: float = 0.55) -> list[float]:
    """One distant gull cry: a quick rise near 2.2 kHz, then a downward glide toward 1.3 kHz."""
    n = n_of(seconds)
    top = rnd.uniform(2100, 2400)
    low = rnd.uniform(1200, 1400)
    rise = rnd.uniform(0.05, 0.08)
    ph, out = 0.0, []
    for i in range(n):
        t = i / SR
        if t < rise:
            f = top * (0.9 + 0.1 * rc(t / rise))
        else:
            f = top + (low - top) * rc((t - rise) / (seconds - rise)) ** 0.8
        f *= 1 + 0.012 * math.sin(TAU * 31 * t)
        ph += TAU * f / SR
        v = math.sin(ph) + 0.3 * math.sin(2 * ph) + 0.12 * math.sin(3 * ph)
        am = 0.75 + 0.25 * math.sin(TAU * 23 * t)
        out.append(v * am * window(t, 0, seconds, 0.03, 0.18))
    return lowpass(lowpass(out, 3200), 3200)


def gull_call(rnd: random.Random, count: int) -> list[float]:
    out = zeros(0.6 * count + 0.8)
    t = 0.0
    for c in range(count):
        cry = gull_cry(rnd, rnd.uniform(0.38, 0.6))
        mix(out, cry, t, 1.0 if c == 0 else rnd.uniform(0.6, 0.85))
        t += len(cry) / SR + rnd.uniform(0.02, 0.1)
    return smear(out, rnd, 0.25, 6, 0.25)   # far off, over open water


def drip(rnd: random.Random) -> list[float]:
    n = n_of(0.12)
    a = n_of(ATTACK)
    ph, out = 0.0, []
    for i in range(n):
        t = i / SR
        f = 900 + 1100 * rc(t / 0.02)
        ph += TAU * f / SR
        out.append((rc(i / a) if i < a else 1.0) * math.sin(ph) * math.exp(-t / 0.02))
    return out


# ---------------------------------------------------------------- the voice

VOWELS = [(730, 1090, 2440), (270, 2290, 3010), (300, 870, 2240), (530, 1840, 2480),
          (570, 840, 2410), (440, 1020, 2240), (660, 1720, 2410), (490, 1350, 1690)]
NEUTRAL = (500, 1500, 2500)
PULL = 0.5   # halfway to neutral: cadence, never vowels


def syllables(rnd: random.Random, t0: float, t1: float, rate: float, last_long: float = 1.6):
    """Seeded syllables over [t0, t1]: (start, end, stress, formants). The last one is lengthened."""
    plan, t = [], t0
    while t < t1 - 0.12:
        d = rnd.uniform(0.75, 1.25) / rate
        stress = 1.0 if rnd.random() < 0.3 else rnd.uniform(0.55, 0.85)
        v = rnd.choice(VOWELS)
        v = tuple(NEUTRAL[j] + PULL * (v[j] - NEUTRAL[j]) for j in range(3))
        plan.append([t, t + d, stress, v])
        t += d + (rnd.uniform(0.04, 0.1) if rnd.random() < 0.35 else 0.0)
    # fit the plan to [t0, t1] with the last syllable last_long times longer than the rest
    durs = [s[1] - s[0] for s in plan]
    durs[-1] *= last_long
    gaps = [plan[i + 1][0] - plan[i][1] for i in range(len(plan) - 1)] + [0.0]
    k = (t1 - t0) / (sum(durs) + sum(gaps))
    t = t0
    for s, d, g in zip(plan, durs, gaps):
        s[0], s[1] = t, t + d * k
        t += (d + g) * k
    return plan


def voice_tracks(n: int, plan, fall: float = 0.2):
    """Amplitude, relative pitch, formant and 'thin' tracks for a syllable plan."""
    amp = [0.0] * n
    rel = [1.0] * n
    fm = [[NEUTRAL[j]] * n for j in range(3)]
    t0, t1 = plan[0][0], plan[-1][1]
    for i in range(n_of(t0), min(n, n_of(t1))):
        frac = (i / SR - t0) / (t1 - t0)
        rel[i] = 1.07 - fall * frac - (0.07 * (frac - 0.8) / 0.2 if frac > 0.8 else 0.0)
    for s0, s1, stress, _v in plan:
        b0, b1 = n_of(s0), min(n, n_of(s1))
        span = max(1, b1 - b0)
        for i in range(b0, b1):
            x = (i - b0) / span
            env = math.sin(math.pi * min(1.0, x / 0.5) / 2) if x < 0.5 else math.cos(math.pi / 2 * (x - 0.5) / 0.5) ** 0.9
            amp[i] = max(amp[i], stress * (0.18 + 0.82 * env))
            rel[i] *= 1 + 0.06 * (stress - 0.7) * math.sin(math.pi * x)
    centres = [((s[0] + s[1]) / 2, s[3]) for s in plan]
    for i in range(n_of(t0), min(n, n_of(t1))):
        t = i / SR
        k = 0
        while k < len(centres) - 1 and centres[k + 1][0] < t:
            k += 1
        if t <= centres[0][0] or k == len(centres) - 1:
            v = centres[k][1]
        else:
            (c0, v0), (c1, v1) = centres[k], centres[k + 1]
            u = rc((t - c0) / (c1 - c0))
            v = tuple(v0[j] + u * (v1[j] - v0[j]) for j in range(3))
        for j in range(3):
            fm[j][i] = v[j]
    # phrase edges: a 40 ms onset, a 90 ms release
    for i in range(n_of(t0), min(n, n_of(t1))):
        amp[i] *= window(i / SR, t0, t1, 0.04, 0.09)
    amp = lowpass(amp, 28)
    return amp, rel, fm


def glottis(rnd: random.Random, n: int, f0: float, amp, rel, open_q: float, breath, rough_amt: float = 0.0):
    """Differentiated Rosenberg pulse train with jitter, slow drift and aspiration.

    breath may be a float or a per-sample list (the thinning of a last syllable)."""
    drift = smooth_walk(n, rnd, 0.2)
    asp = white(n, rnd)
    shim = smooth_walk(n, rnd, 0.02)
    tp, tn = open_q * 0.66, open_q * 0.34
    ph, g_prev, jit = 0.0, 0.0, 1.0
    out = []
    for i in range(n):
        f = f0 * rel[i] * (1 + 0.045 * (drift[i] - 0.5)) * jit
        ph += f / SR
        if ph >= 1.0:
            ph -= 1.0
            jit = 1 + rnd.uniform(-0.009, 0.009)
        if ph < tp:
            g = 0.5 - 0.5 * math.cos(math.pi * ph / tp)
        elif ph < tp + tn:
            g = math.cos(math.pi / 2 * (ph - tp) / tn)
        else:
            g = 0.0
        d = (g - g_prev) * SR / (f0 * 8)
        g_prev = g
        b = breath[i] if isinstance(breath, list) else breath
        voiced = d * (1 - rough_amt + rough_amt * shim[i])
        out.append(amp[i] * ((1 - b) * voiced + b * asp[i] * (0.3 + g)))
    return out


def resonators(src, fm, gains=(1.0, 0.5, 0.25), bws=(85, 120, 170), widen=None):
    """Three moving band-pass resonators in parallel (coefficients every 8 samples)."""
    n = len(src)
    out = [0.0] * n
    for j in range(3):
        x1 = x2 = y1 = y2 = 0.0
        b0 = b2 = a1 = a2 = 0.0
        g = gains[j]
        for i in range(n):
            if i % 8 == 0:
                fc = fm[j][i]
                bw = bws[j] * (1 + (2.0 * widen[i] if widen else 0.0))
                w = TAU * fc / SR
                alpha = math.sin(w) * bw / (2 * fc)
                a0 = 1 + alpha
                b0, b2 = alpha / a0, -alpha / a0
                a1, a2 = -2 * math.cos(w) / a0, (1 - alpha) / a0
            x = src[i]
            y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, x, y1, y
            out[i] += g * y
    return out


def tilt(xs: list[float], k: float) -> list[float]:
    """First-difference pre-emphasis: lifts the formant region for small speakers."""
    prev, out = 0.0, []
    for x in xs:
        out.append(x - k * prev)
        prev = x
    return out


# ---------------------------------------------------------------- loops (k 0-6)

def r12_hum() -> list[float]:
    """Eight indicator hums, each with its own slow tremolo: quiet and unmistakably eight."""
    rnd = seed(0)
    L = 24.0
    n = n_of(L + 1)
    out = [0.0] * n
    for idx, (_name, f) in enumerate(INDICATORS):
        fq = loop_freq(f, L)
        f2 = loop_freq(2 * f, L)
        rate = 0.07 + 0.06 * idx / 7 + rnd.uniform(-0.004, 0.004)  # 0.07-0.13 Hz, all different
        rate = min(0.13, max(0.07, rate))
        tph = rnd.uniform(0, TAU)
        ph1, ph2 = rnd.uniform(0, TAU), rnd.uniform(0, TAU)
        amp = 1.0 / (1 + 0.12 * idx) ** 0.5
        # the 3rd and 5th harmonics, so eight notes near 110-210 Hz carry on a laptop speaker;
        # their phases follow ph1, so the seeded draws (and every other voice) stay as they were
        f3, f5 = loop_freq(3 * f, L), loop_freq(5 * f, L)
        w1, w2, wt = TAU * fq / SR, TAU * f2 / SR, TAU * rate / SR
        w3, w5 = TAU * f3 / SR, TAU * f5 / SR
        ph3, ph5 = 3 * ph1 + 0.7, 5 * ph1 + 1.9
        for i in range(n):
            trem = 1 - 0.3 * (0.5 + 0.5 * math.sin(wt * i + tph))
            out[i] += amp * trem * (math.sin(w1 * i + ph1) + 0.2 * math.sin(w2 * i + ph2)
                                    + 0.15 * math.sin(w3 * i + ph3) + 0.08 * math.sin(w5 * i + ph5))
    return out


def pressure(f1: float, f2: float, k: int) -> list[float]:
    """Sub drone + octave at 0.3, a 0.05 Hz swell, and a felt-like 30-90 Hz noise band."""
    rnd = seed(k)
    L = 20.0
    n = n_of(L + 1)
    a, b = loop_freq(f1, L), loop_freq(f2, L)
    felt = unit(bandlimit(brown(n, rnd), 30, 90))
    w1, w2, ws = TAU * a / SR, TAU * b / SR, TAU * 0.05 / SR
    out = []
    for i in range(n):
        swell = 0.72 + 0.28 * math.sin(ws * i - math.pi / 2)
        out.append(swell * (math.sin(w1 * i) + 0.3 * math.sin(w2 * i)) + 0.22 * felt[i])
    return out


def r12_pressure() -> list[float]:
    return pressure(41.2, 82.4, 1)


def r12_pressure_low() -> list[float]:
    return pressure(38.89, 77.78, 2)


def r12_surface() -> list[float]:
    """A broadband rumble below 140 Hz, with a band of noise at 380-620 Hz mixed in at 0.25 so it
    is heard on a laptop, both breathing together at 0.04 Hz (depth 0.5)."""
    rnd = seed(3)
    L = 30.0
    n = n_of(L + 1)
    nz = unit(lowpass(lowpass(lowpass(white(n, rnd), 140), 140), 140))
    mid = unit(bandlimit(white(n, rnd), 380, 620))
    wb = TAU * 0.04 / SR
    return [(x + 0.25 * m) * (1 - 0.5 * (0.5 + 0.5 * math.cos(wb * i))) for i, (x, m) in enumerate(zip(nz, mid))]


def r12_terminal() -> list[float]:
    """Lit witness terminal: soft 50 + 100 Hz mains hum, a 3.1 kHz whine 30 dB down."""
    rnd = seed(4)
    L = 12.0
    n = n_of(L + 1)
    flick = smooth_walk(n, rnd, 0.7)
    whine_amp = 10 ** (-30 / 20)
    w = TAU / SR
    out = []
    for i in range(n):
        hum = math.sin(w * 50 * i) + 0.4 * math.sin(w * 100 * i + 0.6)
        # a breath of the next harmonics so the hum is not lost on small speakers
        hum += 0.08 * math.sin(w * 150 * i + 1.1) + 0.06 * math.sin(w * 200 * i + 2.0)
        whine = whine_amp * (0.85 + 0.15 * flick[i]) * math.sin(w * 3100 * i)
        out.append(hum + whine)
    return out


def end_sea_day() -> list[float]:
    """An ordinary daylight sea: four surf washes 6-8 s apart, light wind, two or three gulls."""
    rnd = seed(5)
    L = 30.0
    n = n_of(L + 1)
    # four wash intervals in [6, 8] summing to the loop: the pattern repeats exactly at the wrap
    while True:
        iv = [rnd.uniform(6.0, 8.0) for _ in range(3)]
        last = L - sum(iv)
        if 6.0 <= last <= 8.0:
            iv.append(last)
            break
    starts, t = [], rnd.uniform(0.5, 2.0)
    for d in iv:
        starts.append(t)
        t += d
    washes = [(s, rnd.uniform(1.6, 2.4), rnd.uniform(3.0, 4.2), rnd.uniform(0.7, 1.0)) for s in starts]

    def surf_env(t: float) -> float:
        v = 0.0
        for s, up, down, a in washes:
            for shift in (-L, 0.0, L):
                x = t - (s + shift)
                if 0 <= x < up:
                    v = max(v, a * rc(x / up))
                elif up <= x < up + down:
                    v = max(v, a * (1 - rc((x - up) / down)) ** 1.3)
        return v

    env = [surf_env(i / SR) for i in range(n)]
    nz = white(n, rnd)
    surf = lowpass_sweep(nz, lambda t: 500 + 1300 * surf_env(t))
    surf = unit(highpass(highpass(surf, 200), 200))
    hiss = noise_band(rnd, L + 1, 1500, 5000)
    wind = noise_band(rnd, L + 1, 300, 1200)
    gust = smooth_walk(n, rnd, 2.5)
    bed = unit(lowpass(brown(n, rnd), 300))
    out = [(0.12 + env[i]) * (surf[i] + 0.25 * env[i] * hiss[i]) + 0.12 * (0.4 + 0.6 * gust[i]) * wind[i]
           + 0.1 * bed[i] for i in range(n)]
    for at in sorted(rnd.uniform(3.0, 26.0) for _ in range(3)):
        mix(out, gull_call(rnd, rnd.randint(1, 2)), at, 0.16)
    return out


def end_wide() -> list[float]:
    """Vast near-silence: soft wind over a large space, a 30 Hz bed, one barely-there swell."""
    rnd = seed(6)
    L = 30.0
    n = n_of(L + 1)
    wind = noise_band(rnd, L + 1, 120, 600)
    gust = smooth_walk(n, rnd, 3.5)
    w30 = TAU * 30 / SR
    out = []
    for i in range(n):
        t = i / SR
        tm = t % L
        swell = 0.25 * math.exp(-((tm - 15.0) / 4.5) ** 2)
        out.append((0.35 + 0.25 * gust[i] + swell) * wind[i] + 0.35 * math.sin(w30 * i))
    return smear(out, rnd, 0.6, 8, 0.2)


# ---------------------------------------------------------------- P25/P26/P27 one-shots

def card_lift(k: int, light: float = 1.0) -> list[float]:
    rnd = seed(k)
    out = zeros(0.25)
    mix(out, slide(rnd, 0.16, 1400 * light, 6000, 0.03, 0.05), 0.01, 0.55)
    mix(out, click(rnd, 0.06, [(2900 * light, 0.7, 0.006), (5200, 0.25, 0.003)], noise=0.15), 0.15, 0.7 / light)
    return out


def card_seat(k: int, light: float = 1.0) -> list[float]:
    rnd = seed(k)
    out = zeros(0.3)
    mix(out, slide(rnd, 0.07, 1500, 6000, 0.02, 0.02), 0.0, 0.35)
    mix(out, click(rnd, 0.08, [(2400 * light, 1.0, 0.012), (4700 * light, 0.3, 0.004)], noise=0.25), 0.07, 0.8)
    mix(out, thock(rnd, 0.16, 210 * light, 0.025, attack=ATTACK), 0.07, 0.6 / light)
    return out


def card_return(k: int, light: float = 1.0) -> list[float]:
    rnd = seed(k)
    out = zeros(0.25)
    mix(out, slide(rnd, 0.19, 1000 * light, 5000, 0.03, 0.08), 0.0, 0.6)
    mix(out, thock(rnd, 0.06, 380 * light, 0.012, attack=ATTACK, body=1.4), 0.17, 0.25)
    return out


def frame_lamp(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.6)
    mix(out, relay(rnd), 0.02)
    n = n_of(0.4)
    glow = [math.sin(TAU * 440 * i / SR) + 0.25 * math.sin(TAU * 880 * i / SR) for i in range(n)]
    glow = [x * window(i / SR, 0, 0.4, 0.06, 0.2) for i, x in enumerate(glow)]
    mix(out, glow, 0.08, 0.16)
    return out


def switch_throw(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.35)
    mix(out, click(rnd, 0.05, [(3200, 0.5, 0.004), (1900, 0.3, 0.006)], noise=0.2), 0.01, 0.35)  # guard up
    mix(out, slide(rnd, 0.06, 800, 3000, 0.02, 0.01), 0.09, 0.25)
    mix(out, thock(rnd, 0.16, 140, 0.03, attack=ATTACK), 0.15, 0.9)
    mix(out, click(rnd, 0.1, [(1300, 0.8, 0.012), (2750, 0.35, 0.005)], noise=0.3), 0.15, 0.7)
    mix(out, click(rnd, 0.06, [(3000, 0.35, 0.004), (1700, 0.2, 0.006)], noise=0.15), 0.27, 0.3)  # guard down
    return out


def strip_type(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(1.6)
    t = 0.05
    for s in range(6):
        mix(out, typestrike(rnd, rnd.uniform(0.8, 1.0)), t)
        t += rnd.uniform(0.22, 0.29)
    return out


def route_key(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.8)
    mix(out, slide(rnd, 0.6, 1500, 4500, 0.06, 0.08, grain_s=0.006), 0.04, 0.22)
    for at in (0.26, 0.58):
        mix(out, click(rnd, 0.1, [(1250, 1.0, 0.014), (3100, 0.4, 0.006), (560, 0.4, 0.02)], noise=0.3), at)
    return out


def route_refuse(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.4)
    mix(out, slide(rnd, 0.12, 1500, 4500, 0.03, 0.02, grain_s=0.006), 0.02, 0.22)
    mix(out, thock(rnd, 0.2, 260, 0.035, attack=ATTACK, body=1.2), 0.13, 0.9)
    mix(out, click(rnd, 0.08, [(900, 0.6, 0.01), (2100, 0.2, 0.004)], noise=0.25), 0.13, 0.45)
    return out


def frames_slide(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(2.2)
    for d, (lo, hi, at) in enumerate([(150, 1100, 0.0), (220, 1500, 0.06), (180, 1300, 0.12)]):
        mix(out, slide(rnd, 1.65, lo, hi, 0.35, 0.25, grain_s=0.03, grain=0.4), 0.05 + at, 0.45)
    for d, at in enumerate((1.74, 1.84, 1.95)):
        mix(out, thock(rnd, 0.24, 95 + 12 * d, 0.05, attack=0.011, body_lp=500), at, 0.75)
    return smear(out, rnd, 0.12, 5, 0.18)


def terminal_on(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(1.2)
    mix(out, relay(rnd, 0.85, 0.1), 0.03)
    n = n_of(1.1)
    w = TAU / SR
    hum = []
    for i in range(n):
        t = i / SR
        rise = rc(t / 0.9) ** 1.5
        f_shift = 1 - 0.04 * (1 - rise)     # a filament warming up
        v = math.sin(w * 50 * f_shift * i) + 0.4 * math.sin(w * 100 * f_shift * i + 0.6)
        v += 0.12 * math.sin(w * 150 * i) + 0.06 * math.sin(w * 200 * i)
        v += 0.04 * rise * math.sin(w * 3100 * i)
        hum.append(v * rise * window(t, 0, 1.1, 0.0, 0.12))
    mix(out, hum, 0.1, 0.5)
    return out


def venn_last(k: int) -> list[float]:
    """Venn's cadence through a small grille: close, dry, the last syllable thinning to breath."""
    rnd = seed(k)
    dur = 2.4
    n = n_of(dur)
    plan = syllables(rnd, 0.12, 2.25, 3.6, last_long=2.0)
    amp, rel, fm = voice_tracks(n, plan, fall=0.22)
    last0 = plan[-1][0]
    thin = [rc((i / SR - last0) / (dur - 0.15 - last0)) if i / SR > last0 else 0.0 for i in range(n)]
    breath = [0.05 + 0.55 * x for x in thin]
    amp = [a * (1 - 0.45 * x) for a, x in zip(amp, thin)]
    src = glottis(rnd, n, VENN_F0, amp, rel, 0.55, breath)
    v = tilt(resonators(src, fm, widen=thin), 0.9)
    v = unit(bandlimit(v, 220, 3400))
    horn = unit(biquad_bp(v, 750, 1.4))
    v = [0.55 * a + 0.6 * b for a, b in zip(v, horn)]
    v = smear(v, rnd, 0.03, 4, 0.12)       # a small grille, close and dry
    hiss = noise_band(rnd, dur, 1800, 5000)
    v = unit(v)
    return [x + 0.02 * h for x, h in zip(v, hiss)]


def shutters_open(k: int) -> list[float]:
    """A roller shutter rising far across the chamber: slat rattle, a motor murmur, distance."""
    rnd = seed(k)
    dur = 2.0
    n = n_of(dur)
    rattle = [0.0] * n
    t = 0.1
    while t < 1.85:
        tick = click(rnd, 0.03, [(rnd.uniform(1100, 1700), 0.6, 0.004)], noise=0.4, noise_lo=500, noise_hi=3000)
        mix(rattle, tick, t, rnd.uniform(0.5, 1.0))
        t += rnd.uniform(0.035, 0.055)
    motor = noise_band(rnd, dur, 80, 400)
    env = [window(i / SR, 0.05, 1.95, 0.6, 0.45) for i in range(n)]
    out = [env[i] * (0.6 * rattle[i] + 0.35 * motor[i]) for i in range(n)]
    out = lowpass(lowpass(out, 1600), 1600)
    return smear(out, rnd, 0.5, 10, 0.35)


def preview_key(k: int, pitch: float = 1.0) -> list[float]:
    rnd = seed(k)
    out = zeros(0.3)
    mix(out, click(rnd, 0.08, [(1700 * pitch, 0.9, 0.01), (3600 * pitch, 0.3, 0.004)], noise=0.25), 0.02)
    mix(out, thock(rnd, 0.1, 300 * pitch, 0.02, attack=ATTACK), 0.02, 0.4)
    mix(out, click(rnd, 0.06, [(2300 * pitch, 0.4, 0.006)], noise=0.12), 0.17, 0.35)  # spring return
    return out


def preview_out(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(5.0)
    for j in range(8):
        mix(out, relay(rnd, 1.25 * 2 ** (-j / 9)), 0.15 + 0.5 * j, 0.8)
    mix(out, relay(rnd, 0.6, 0.12), 4.2, 0.85)                     # the feed
    mix(out, thock(rnd, 0.18, 230, 0.03, attack=ATTACK), 4.62, 0.7)  # the small door latch
    mix(out, click(rnd, 0.1, [(1050, 0.6, 0.012), (2500, 0.25, 0.005)], noise=0.3), 4.62, 0.55)
    return out


def preview_move(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(4.0)
    mix(out, slide(rnd, 2.2, 700, 3200, 0.25, 0.2, grain_s=0.02, grain=0.35), 0.1, 0.4)
    mix(out, slide(rnd, 2.2, 120, 500, 0.25, 0.2, grain_s=0.05, grain=0.3), 0.1, 0.3)
    mix(out, thock(rnd, 0.2, 180, 0.03), 2.3, 0.6)
    mix(out, relay(rnd, 0.8), 2.95, 0.8)       # off: lower, duller
    mix(out, relay(rnd, 1.1), 3.45, 0.85)      # on
    return out


def confirm_refuse(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.4)
    mix(out, slide(rnd, 0.05, 900, 3000, 0.02, 0.015), 0.02, 0.2)
    mix(out, thock(rnd, 0.2, 200, 0.04, attack=ATTACK, body=1.0), 0.06, 1.0)
    mix(out, click(rnd, 0.05, [(1800, 0.2, 0.005)], noise=0.1), 0.28, 0.3)   # spring back, no contact
    return out


def mismatch_lamp(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.6)
    mix(out, relay(rnd, 0.95), 0.01)
    mix(out, buzz(n_of(0.5), 330, 0.04, 0.12, bright=1500), 0.08, 0.22)
    return out


def confirm_stamp(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(1.0)
    mix(out, slide(rnd, 0.06, 600, 2500, 0.02, 0.02), 0.02, 0.15)
    mix(out, thock(rnd, 0.6, 85, 0.11, attack=0.012, body=0.9, body_lp=400), 0.08, 1.0)
    mix(out, thock(rnd, 0.3, 175, 0.05, attack=SOFT_ATTACK), 0.08, 0.4)
    mix(out, click(rnd, 0.4, [(1180, 0.25, 0.08), (2950, 0.08, 0.04)], attack=SOFT_ATTACK, noise=0.1), 0.08, 0.35)  # enamel
    return smear(out, rnd, 0.15, 6, 0.15)


def slots_close(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(1.2)
    for j, at in enumerate((0.04, 0.6)):
        mix(out, slide(rnd, 0.32, 1500, 5000, 0.06, 0.05, grain_s=0.008), at, 0.35)
        mix(out, click(rnd, 0.16, [(1550 + 120 * j, 0.7, 0.03), (3900, 0.25, 0.01)], attack=ATTACK, noise=0.2),
            at + 0.33, 0.7)
        mix(out, thock(rnd, 0.12, 260, 0.02), at + 0.33, 0.35)
    return out


def surface_withdraw(k: int) -> list[float]:
    """A huge exhale going away: 60 -> 38 Hz with harmonics for small speakers, air noise, all slow."""
    rnd = seed(k)
    dur = 5.0
    n = n_of(dur)
    air = noise_band(rnd, dur, 150, 900)
    air_hi = noise_band(rnd, dur, 600, 2200)
    ph, out = 0.0, []
    for i in range(n):
        t = i / SR
        x = t / dur
        f = 60 * (38 / 60) ** rc(x)
        ph += TAU * f / SR
        env = rc(min(1.0, t / 1.8)) * (1 - rc(max(0.0, (t - 2.2) / 2.7)))
        tone_v = (math.sin(ph) + 0.5 * math.sin(2 * ph) + 0.28 * math.sin(3 * ph) + 0.14 * math.sin(4 * ph)
                  + 0.07 * math.sin(5 * ph))
        out.append(env * (tone_v + 0.5 * air[i] * (1 - 0.5 * x) + 0.12 * air_hi[i] * (1 - x)))
    return out


def yoke_lift(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.6)
    mix(out, slide(rnd, 0.35, 200, 1500, 0.08, 0.15, grain_s=0.02), 0.03, 0.6)
    mix(out, click(rnd, 0.5, [(420, 0.5, 0.12), (1130, 0.25, 0.06), (2380, 0.08, 0.03)],
                   attack=0.02, noise=0.05), 0.12, 0.35)
    return out


def yoke_fit(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.9)
    mix(out, slide(rnd, 0.25, 250, 1600, 0.06, 0.05), 0.02, 0.35)
    for j, at in enumerate((0.3, 0.43)):
        mix(out, thock(rnd, 0.4, 115 - 8 * j, 0.07, attack=0.011, body_lp=500), at, 1.0)
        mix(out, click(rnd, 0.4, [(610, 0.4, 0.08), (1560, 0.18, 0.04), (3200, 0.05, 0.02)],
                       attack=SOFT_ATTACK, noise=0.1), at, 0.4)
    return out


def yoke_return(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.6)
    mix(out, thock(rnd, 0.4, 130, 0.06, attack=0.012, body_lp=450), 0.12, 0.9)
    mix(out, slide(rnd, 0.35, 250, 1500, 0.04, 0.2, grain_s=0.02), 0.1, 0.4)
    mix(out, click(rnd, 0.35, [(420, 0.25, 0.08), (1130, 0.1, 0.04)], attack=0.015, noise=0.04), 0.12, 0.3)
    return out


def bridge_seat(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.5)
    mix(out, slide(rnd, 0.18, 2000, 6000, 0.05, 0.02, grain_s=0.004), 0.05, 0.3)
    mix(out, click(rnd, 0.12, [(2800, 0.9, 0.012), (5400, 0.3, 0.004), (1300, 0.3, 0.02)], noise=0.25), 0.23)
    mix(out, thock(rnd, 0.1, 330, 0.015, attack=ATTACK), 0.23, 0.3)
    return out


def bridge_lift(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.4)
    mix(out, click(rnd, 0.08, [(2300, 0.6, 0.008), (4800, 0.2, 0.003)], noise=0.2), 0.02, 0.7)
    mix(out, slide(rnd, 0.22, 1800, 5500, 0.02, 0.1, grain_s=0.004), 0.05, 0.4)
    return out


def button_refuse(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.5)
    mix(out, thock(rnd, 0.1, 240, 0.02, attack=ATTACK), 0.0, 0.3)
    bz = buzz(n_of(0.4), 180, 0.03, 0.15, bright=1100)
    bz = [x * (0.35 + 0.65 * math.exp(-i / (0.12 * SR))) for i, x in enumerate(bz)]   # a buzzer with no will
    mix(out, bz, 0.04, 0.35)
    return out


def one_or_other(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.5)
    for at in (0.06, 0.2):
        mix(out, thock(rnd, 0.12, 230, 0.02, attack=ATTACK, body=1.2), at, 0.8)
        mix(out, click(rnd, 0.05, [(1500, 0.3, 0.005)], noise=0.15), at, 0.35)
    return out


# ---------------------------------------------------------------- ending one-shots

def handle_pull(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(2.6)
    t, j = 0.08, 0
    while t < 2.0:
        p = rnd.uniform(0.95, 1.05)
        mix(out, click(rnd, 0.06, [(1350 * p, 0.7, 0.008), (2900 * p, 0.25, 0.003), (520, 0.3, 0.012)],
                       noise=0.3), t, 0.5 + 0.2 * rnd.random())
        t += 0.085 + 0.004 * j     # the ratchet slows under the load
        j += 1
    mix(out, slide(rnd, 2.0, 120, 600, 0.3, 0.2, grain_s=0.04, grain=0.3), 0.05, 0.25)  # the long throw
    mix(out, thock(rnd, 0.5, 80, 0.1, attack=0.012, body_lp=400), 2.1, 1.0)
    mix(out, click(rnd, 0.4, [(480, 0.35, 0.09), (1250, 0.12, 0.04)], attack=0.012, noise=0.06), 2.1, 0.4)
    return smear(out, rnd, 0.2, 6, 0.15)


def line_out(k: int, f: float) -> list[float]:
    """A relay lets go, and that indicator's own hum note dies away over about 1.2 s."""
    rnd = seed(k)
    out = zeros(1.4)
    mix(out, relay(rnd, 0.9), 0.02, 0.5)
    n = n_of(1.3)
    ph1 = rnd.uniform(0, TAU)
    note = []
    for i in range(n):
        t = i / SR
        env = rc(t / 0.03) * (1 - rc(t / 1.22)) ** 1.6
        note.append(env * (math.sin(TAU * f * t + ph1) + 0.2 * math.sin(TAU * 2 * f * t)))
    mix(out, note, 0.07, 0.55)
    return out


def funnel_stop(k: int) -> list[float]:
    """The funnel's hiss thins (its low end leaves first) and stops; then 0.6 s of the room."""
    rnd = seed(k)
    dur = 2.6
    n = n_of(dur)
    nz = white(n, rnd)

    def lo_of(t: float) -> float:
        return 500 + 2500 * rc(t / 2.0)

    hiss = [a - b for a, b in zip(lowpass(nz, 5000), lowpass_sweep(nz, lo_of))]
    hiss = unit(hiss)
    hum = [math.sin(TAU * 60 * i / SR) * 0.08 for i in range(n)]
    room = unit(lowpass(brown(n, rnd), 400))
    out = []
    for i in range(n):
        t = i / SR
        env = rc(t / 0.15) * (1 - rc(t / 2.0)) ** 1.2 if t < 2.0 else 0.0
        out.append(env * (hiss[i] + hum[i]) + 0.035 * room[i])
    return out


def throat(k: int) -> list[float]:
    """A small wordless human throat clearing: a breathy, rough 'hm-hm', warm and near."""
    rnd = seed(k)
    dur = 0.9
    n = n_of(dur)
    plan = [[0.08, 0.34, 0.85, (480, 1300, 2450)], [0.42, 0.78, 1.0, (450, 1200, 2400)]]
    amp, rel, fm = voice_tracks(n, plan, fall=0.25)
    src = glottis(rnd, n, 128.0, amp, rel, 0.7, 0.42, rough_amt=0.7)
    v = resonators(src, fm, gains=(1.0, 0.45, 0.2), bws=(150, 200, 260))
    v = tilt(v, 0.7)
    warm = lowpass(v, 450)
    v = unit([a + 0.5 * b for a, b in zip(v, warm)])
    # the rasp at each onset: a short low noise burst
    for s0, s1, _st, _v in plan:
        burst = slide(rnd, 0.1, 300, 1800, 0.012, 0.07, grain_s=0.004, grain=0.8)
        mix(v, burst, s0, 0.3)
    return smear(v, rnd, 0.04, 4, 0.1)


def breath_stop(k: int) -> list[float]:
    """A last long mechanical exhale pushing past bolts; it thins out and nothing follows."""
    rnd = seed(k)
    dur = 3.0
    n = n_of(dur)
    nz = white(n, rnd)
    body = unit(bp_sweep(nz, lambda t: 520 - 170 * rc(t / 2.6), 2.2))
    low = unit(bp_sweep(white(n, rnd), lambda t: 210 - 60 * rc(t / 2.6), 1.5))
    pipe = [math.sin(TAU * 72 * i / SR) for i in range(n)]
    rattle = [0.0] * n
    t = 0.3
    while t < 2.2:
        mix(rattle, click(rnd, 0.025, [(rnd.uniform(800, 1900), 0.5, 0.004)], noise=0.3), t,
            rnd.uniform(0.3, 1.0))
        t += rnd.uniform(0.03, 0.09)
    out = []
    for i in range(n):
        tt = i / SR
        env = rc(tt / 0.6) * (1 - rc((tt - 0.5) / 2.2)) ** 1.4 if tt < 2.7 else 0.0
        out.append(env * (body[i] + 0.6 * low[i] + 0.25 * pipe[i] + 0.25 * rattle[i] * env))
    return out


def jar_level(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(1.5)
    mix(out, click(rnd, 0.5, [(2650, 0.5, 0.06), (4130, 0.2, 0.03), (6020, 0.08, 0.015)],
                   attack=ATTACK, noise=0.08), 0.06, 0.6)
    n = n_of(1.2)
    sigh = bp_sweep(white(n, rnd), lambda t: 720 - 300 * rc(t / 1.2), 4.0)
    sigh = unit(sigh)
    sigh = [x * window(i / SR, 0, 1.2, 0.3, 0.6) for i, x in enumerate(sigh)]
    mix(out, sigh, 0.25, 0.6)
    return out


def spoon_settle(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.6)
    mix(out, click(rnd, 0.35, [(3180, 0.6, 0.05), (5120, 0.3, 0.025), (7330, 0.1, 0.012)],
                   attack=ATTACK, noise=0.05), 0.04)
    mix(out, click(rnd, 0.3, [(3240, 0.3, 0.035), (5180, 0.12, 0.02)], attack=ATTACK, noise=0.03), 0.17, 0.4)
    return out


def mattress_rise(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(1.0)
    mix(out, slide(rnd, 0.85, 400, 3000, 0.25, 0.35, grain_s=0.03, grain=0.5), 0.05, 0.5)
    for at in sorted(rnd.uniform(0.15, 0.6) for _ in range(3)):
        f = rnd.uniform(380, 650)
        n = n_of(0.25)
        spring = [math.sin(TAU * f * (i / SR) * (1 + 0.02 * math.sin(TAU * 9 * i / SR)))
                  * window(i / SR, 0, 0.25, 0.02, 0.18) for i in range(n)]
        mix(out, spring, at, 0.08)
    return out


def pen_lift(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(1.2)
    mix(out, scribble(rnd, 0.75, 2400, 8000, (0.12, 0.25), (0.03, 0.08), 0.005, 0.7), 0.05, 0.8)
    mix(out, click(rnd, 0.05, [(4100, 0.6, 0.005), (6300, 0.2, 0.003)], noise=0.15), 0.94, 0.5)
    return out


def venn_allright(k: int) -> list[float]:
    """Two calm syllables, Venn's own pitch, no horn and no hiss: close, quiet, settled."""
    rnd = seed(k)
    dur = 1.6
    n = n_of(dur)
    plan = [[0.18, 0.55, 0.8, (560, 1250, 2450)], [0.58, 1.38, 1.0, (520, 1450, 2480)]]
    amp, rel, fm = voice_tracks(n, plan, fall=0.18)
    src = glottis(rnd, n, VENN_F0, amp, rel, 0.6, 0.1)
    v = tilt(resonators(src, fm), 0.85)
    v = bandlimit(v, 90, 4200)
    warm = lowpass(v, 400)
    v = [a + 0.3 * b for a, b in zip(v, warm)]
    return smear(v, rnd, 0.05, 4, 0.08)


def record_lift(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.8)
    mix(out, slide(rnd, 0.25, 1500, 7000, 0.06, 0.08, grain_s=0.003, grain=0.8), 0.04, 0.45)  # the peel
    mix(out, slide(rnd, 0.4, 400, 3000, 0.1, 0.25), 0.22, 0.5)                               # the lift
    return out


def launch_engine(k: int) -> list[float]:
    """A small launch's engine coming in from far off: ~6 Hz putter over a low tone, fading in."""
    rnd = seed(k)
    dur = 7.0
    n = n_of(dur)
    putter = [0.0] * n
    t = 0.0
    while t < dur:
        pulse = thock(rnd, 0.1, rnd.uniform(85, 95), 0.025, attack=ATTACK, body=1.3, body_lp=900)
        mix(putter, pulse, t, rnd.uniform(0.8, 1.0))
        t += (1 / 6.0) * rnd.uniform(0.96, 1.04)
    w = TAU * 72 / SR
    lowtone = [math.sin(w * i) + 0.3 * math.sin(2 * w * i) for i in range(n)]
    water = noise_band(rnd, dur, 300, 1400)
    raw = [putter[i] + 0.35 * lowtone[i] for i in range(n)]
    raw = lowpass_sweep(raw, lambda tt: 350 + 1100 * rc(tt / dur))
    out = []
    for i in range(n):
        tt = i / SR
        env = rc(tt / dur) ** 1.4 * window(tt, 0, dur, 0.0, 0.5)
        out.append(env * (raw[i] + 0.15 * water[i]))
    return smear(out, rnd, 0.4, 8, 0.25)


def gulls(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(3.0)
    mix(out, gull_call(rnd, 1), 0.2)
    mix(out, gull_call(rnd, 2), 1.45, 0.8)
    return out


def inquiry_pen(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(2.2)
    mix(out, scribble(rnd, 2.0, 2200, 8000, (0.15, 0.4), (0.04, 0.12), 0.004, 0.75), 0.08)
    return out


def page_dry(k: int) -> list[float]:
    rnd = seed(k)
    dur = 1.0
    n = n_of(dur)
    sw = noise_band(rnd, dur, 600, 4000)
    out = []
    for i in range(n):
        t = i / SR
        flutter = 0.7 + 0.3 * math.sin(TAU * 11 * t)
        out.append(sw[i] * flutter * window(t, 0.05, 0.95, 0.35, 0.45))
    return out


def motif_human_a(k: int) -> list[float]:
    """Eight notes, then the ninth on true C4 over a fading open fifth: freedom with grief."""
    rnd = seed(k)
    dur = 11.0
    out = zeros(dur)
    times = [0.25, 1.05, 1.85, 2.7, 3.5, 4.35, 5.25, 6.2]
    for f, at in zip(MOTIF, times):
        mix(out, warm_note(rnd, f, 2.4, 1.1, release=0.6), at, 0.8)
    mix(out, warm_note(rnd, C4, 3.8, 2.2, release=1.2), 7.3, 0.95)
    fifth = [a + b for a, b in zip(felt_tone(130.81, 3.6, 2.5, attack=0.15, release=3.0),
                                   felt_tone(196.0, 3.6, 2.5, attack=0.15, release=3.0))]
    mix(out, fifth, 7.3, 0.3)
    out = smear(out, rnd, 0.18, 8, 0.12)
    return [x * window(i / SR, 0, dur, 0.0, 0.6) for i, x in enumerate(out)]


def motif_human_b(k: int) -> list[float]:
    """The same eight notes, the ninth a quarter-tone flat and held, then D4 rising, left ringing."""
    rnd = seed(k)
    dur = 12.0
    out = zeros(dur)
    times = [0.25, 1.05, 1.85, 2.7, 3.5, 4.35, 5.25, 6.2]
    for f, at in zip(MOTIF, times):
        mix(out, warm_note(rnd, f, 2.4, 1.1, release=0.6), at, 0.8)
    mix(out, warm_note(rnd, C4_QFLAT, 3.0, 2.2, release=0.9), 7.3, 0.95)
    mix(out, warm_note(rnd, 293.66, 2.6, 3.5, release=0.9), 9.4, 0.85)
    out = smear(out, rnd, 0.18, 8, 0.12)
    return [x * window(i / SR, 0, dur, 0.0, 0.8) for i, x in enumerate(out)]


def feed_move(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(2.4)
    mix(out, slide(rnd, 1.45, 700, 3200, 0.2, 0.15, grain_s=0.02, grain=0.35), 0.08, 0.4)
    mix(out, slide(rnd, 1.45, 120, 500, 0.2, 0.15, grain_s=0.05, grain=0.3), 0.08, 0.3)
    mix(out, thock(rnd, 0.2, 180, 0.03), 1.5, 0.55)
    mix(out, relay(rnd, 0.95), 1.85, 0.8)
    n = n_of(0.5)
    warm = [(math.sin(TAU * 100 * i / SR) + 0.3 * math.sin(TAU * 200 * i / SR)) * window(i / SR, 0, 0.5, 0.08, 0.3)
            for i in range(n)]
    mix(out, warm, 1.88, 0.25)
    return out


def coat_slump(k: int) -> list[float]:
    rnd = seed(k)
    dur = 1.4
    out = zeros(dur)
    n = n_of(0.8)
    cloth = bp_sweep(white(n, rnd), lambda t: 900 - 500 * rc(t / 0.8), 1.2)
    cloth = unit(cloth)
    g = rough(rnd, n, 0.015, 0.6)
    cloth = [x * g[i] * window(i / SR, 0, 0.8, 0.12, 0.45) for i, x in enumerate(cloth)]
    mix(out, cloth, 0.05, 0.8)
    mix(out, thock(rnd, 0.3, 110, 0.06, attack=0.02, body_lp=500), 0.25, 0.4)
    mix(out, drip(rnd), 1.15, 0.35)
    return out


def chair_sit(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(1.0)
    mix(out, thock(rnd, 0.35, 105, 0.07, attack=0.015, body_lp=500), 0.08, 0.7)
    # the creak: a stick-slip impulse train sliding from 140 to 85 Hz through wood resonances
    n = n_of(0.55)
    imp = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += (140 - 55 * rc(t / 0.55)) * (1 + 0.08 * (rnd.random() - 0.5)) / SR
        if ph >= 1.0:
            ph -= 1.0
            imp[i] = rnd.uniform(0.6, 1.0)
    creak = [a + 0.7 * b for a, b in zip(biquad_bp(imp, 720, 6), biquad_bp(imp, 1480, 8))]
    creak = unit(creak)
    creak = [x * window(i / SR, 0, 0.55, 0.06, 0.2) for i, x in enumerate(creak)]
    mix(out, creak, 0.22, 0.6)
    return out


def armature_settle(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(1.6)
    for j, at in enumerate((0.12, 0.38, 0.6, 0.88, 1.14)):
        p = rnd.uniform(0.94, 1.06)
        mix(out, click(rnd, 0.3, [(2050 * p, 0.6, 0.03), (4400 * p, 0.2, 0.012), (980 * p, 0.25, 0.04)],
                       attack=ATTACK, noise=0.12), at, 0.9 - 0.08 * j)
    return out


def typing(k: int, seconds: float, count: int, gap: tuple[float, float]) -> list[float]:
    rnd = seed(k)
    out = zeros(seconds)
    t = 0.06
    for _ in range(count):
        mix(out, typestrike(rnd, rnd.uniform(0.75, 1.0)), t)
        t += rnd.uniform(*gap)
    return out


def pencil_correct(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(2.4)
    mix(out, scribble(rnd, 2.25, 1600, 6000, (0.1, 0.3), (0.05, 0.15), 0.006, 0.6), 0.06)
    return out


def cup_warm(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(0.8)
    mix(out, click(rnd, 0.3, [(2930, 0.5, 0.025), (4720, 0.2, 0.012)], attack=ATTACK, noise=0.06), 0.15)
    mix(out, click(rnd, 0.25, [(3010, 0.2, 0.02)], attack=ATTACK, noise=0.04), 0.52, 0.5)
    return out


def paper_cover(k: int) -> list[float]:
    rnd = seed(k)
    out = zeros(1.2)
    n = n_of(0.75)
    air = lowpass_sweep(white(n, rnd), lambda t: 3500 - 2500 * rc(t / 0.75))
    air = unit(highpass(air, 300))
    air = [x * window(i / SR, 0, 0.75, 0.25, 0.2) for i, x in enumerate(air)]
    mix(out, air, 0.08, 0.5)
    mix(out, slide(rnd, 0.12, 200, 1500, 0.015, 0.08), 0.82, 0.7)   # the sheet lands flat
    return out


# ---------------------------------------------------------------- build

def r12_mid() -> list[float]:
    """The chamber's mid band, so the dread carries on a laptop: a beating sine pair at 311 and
    313.5 Hz (a 2.5 Hz beat) at -24 dBFS RMS, and brown noise band-passed to 400-1200 Hz at
    -28 dBFS RMS, both under one slow swell (0.07 Hz asked; 2 whole cycles per loop, 0.0645 Hz,
    so the wrap is coherent). 31 s. Written at these absolute levels (ABSOLUTE below), never
    re-mastered to LOOP_RMS."""
    rnd = seed(7)
    L = 31.0
    n = n_of(L + 1)
    fa, fb = loop_freq(311.0, L), loop_freq(313.5, L)
    sw = loop_freq(0.07, L)
    tone_amp = 10 ** (-24 / 20)            # the pair's RMS: two equal sines of amplitude a sum to RMS a
    noise = bandlimit(brown(n, rnd), 400, 1200)
    nr = rms(noise)
    noise = [x * (10 ** (-28 / 20)) / nr for x in noise]
    wa, wb, ws = TAU * fa / SR, TAU * fb / SR, TAU * sw / SR
    out = []
    for i in range(n):
        swell = 0.8 + 0.2 * math.sin(ws * i - math.pi / 2)      # 0.6 .. 1.0
        out.append(swell * (tone_amp * (math.sin(wa * i) + math.sin(wb * i + 0.4)) + noise[i]))
    return out


# Loops written at the level they were synthesized at (peak left as is), not LOOP_RMS.
ABSOLUTE = {"r12_mid"}

LOOPS = [("r12_hum", r12_hum), ("r12_pressure", r12_pressure), ("r12_pressure_low", r12_pressure_low),
         ("r12_surface", r12_surface), ("r12_terminal", r12_terminal), ("end_sea_day", end_sea_day),
         ("end_wide", end_wide), ("r12_mid", r12_mid)]

# (id, fn(k)); k for seeding is 10 + position, so the loops keep k 0-6.
SHOTS = [
    ("card_lift", card_lift), ("card_seat", card_seat), ("card_return", card_return),
    ("frame_lamp", frame_lamp), ("switch_throw", switch_throw), ("strip_type", strip_type),
    ("route_key", route_key), ("route_refuse", route_refuse), ("frames_slide", frames_slide),
    ("terminal_on", terminal_on), ("venn_last", venn_last), ("shutters_open", shutters_open),
    ("preview_key", preview_key), ("preview_out", preview_out), ("preview_move", preview_move),
    ("cc_lift", lambda k: card_lift(k, 1.3)), ("cc_seat", lambda k: card_seat(k, 1.25)),
    ("cc_return", lambda k: card_return(k, 1.3)),
    ("confirm_refuse", confirm_refuse), ("mismatch_lamp", mismatch_lamp), ("confirm_stamp", confirm_stamp),
    ("slots_close", slots_close), ("surface_withdraw", surface_withdraw), ("yoke_lift", yoke_lift),
    ("yoke_fit", yoke_fit), ("yoke_return", yoke_return), ("bridge_seat", bridge_seat),
    ("bridge_lift", bridge_lift), ("final_preview", lambda k: preview_key(k, 0.9)),
    ("button_refuse", button_refuse), ("one_or_other", one_or_other),
    ("handle_pull", handle_pull),
] + [(f"line_out_{j + 1}", (lambda f: (lambda k: line_out(k, f)))(f)) for j, (_nm, f) in enumerate(INDICATORS)] + [
    ("funnel_stop", funnel_stop), ("throat", throat), ("breath_stop", breath_stop),
    ("jar_level", jar_level), ("spoon_settle", spoon_settle), ("mattress_rise", mattress_rise),
    ("pen_lift", pen_lift), ("venn_allright", venn_allright), ("record_lift", record_lift),
    ("launch_engine", launch_engine), ("gulls", gulls), ("inquiry_pen", inquiry_pen),
    ("page_dry", page_dry), ("motif_human_a", motif_human_a), ("feed_move", feed_move),
    ("coat_slump", coat_slump), ("chair_sit", chair_sit), ("armature_settle", armature_settle),
    ("index_type", lambda k: typing(k, 2.2, 7, (0.26, 0.32))), ("pencil_correct", pencil_correct),
    ("cup_warm", cup_warm), ("counter_type", lambda k: typing(k, 2.6, 13, (0.16, 0.2))),
    ("paper_cover", paper_cover), ("motif_human_b", motif_human_b),
]

# For the R12 view (dB). SFX_SOFT: cut by "Soften sudden sounds".
SFX_DB = {
    "card_lift": -14, "card_seat": -12, "card_return": -14, "frame_lamp": -14, "switch_throw": -11,
    "strip_type": -13, "route_key": -10, "route_refuse": -12, "frames_slide": -9, "terminal_on": -12,
    "venn_last": -6, "shutters_open": -16, "preview_key": -13, "preview_out": -12, "preview_move": -12,
    "cc_lift": -14, "cc_seat": -12, "cc_return": -14, "confirm_refuse": -12, "mismatch_lamp": -13,
    "confirm_stamp": -8, "slots_close": -11, "surface_withdraw": -8, "yoke_lift": -12, "yoke_fit": -9,
    "yoke_return": -12, "bridge_seat": -11, "bridge_lift": -13, "final_preview": -13, "button_refuse": -14,
    "one_or_other": -14, "handle_pull": -7, **{f"line_out_{j}": -12 for j in range(1, 9)},
    "funnel_stop": -11, "throat": -14, "breath_stop": -10, "jar_level": -14, "spoon_settle": -16,
    "mattress_rise": -14, "pen_lift": -14, "venn_allright": -6, "record_lift": -13, "launch_engine": -10,
    "gulls": -14, "inquiry_pen": -12, "page_dry": -14, "motif_human_a": -8, "feed_move": -11,
    "coat_slump": -11, "chair_sit": -12, "armature_settle": -14, "index_type": -12, "pencil_correct": -12,
    "cup_warm": -16, "counter_type": -12, "paper_cover": -12, "motif_human_b": -8,
}
SFX_SOFT = ["handle_pull", "confirm_stamp", "frames_slide", "slots_close", "yoke_fit", "shutters_open",
            "launch_engine", "throat"]
SFX_SOFT_CUT = {"throat": 4}   # soft audio caps the throat in the silence at -18 dB


def check_attacks(name: str, xs: list[float]) -> None:
    """Fails if the 1 ms peak envelope climbs from under 10 % to over 90 % of full scale in < 4 ms."""
    p = peak_of(xs)
    w = n_of(0.001)
    blocks = [max(abs(x) for x in xs[i:i + w]) / p for i in range(0, len(xs) - w, w)]
    # a 10 ms peak-hold, so a steady pitched waveform reads as steady
    env = [max(blocks[max(0, i - 9):i + 1]) for i in range(len(blocks))]
    for i in range(4, len(env)):
        if env[i] > 0.9 and env[i - 4] < 0.1:
            raise SystemExit(f"{name}: transient rises faster than 4 ms at {i} ms")


def check_wrap(name: str, xs: list[float]) -> float:
    steps = sorted(abs(xs[i + 1] - xs[i]) for i in range(len(xs) - 1))
    med = max(1e-12, steps[len(steps) // 2])
    return abs(xs[0] - xs[-1]) / med


def main() -> None:
    print(f"Writing to {OUT}")
    for k, (name, fn) in enumerate(LOOPS):
        xs = seamless(fn(), 1.0)
        ratio = check_wrap(name, xs)
        if ratio > 4.0:
            raise SystemExit(f"{name}: wrap step {ratio:.1f}x the median step")
        peak = min(0.98, LOOP_RMS * peak_of(xs) / max(1e-12, rms(xs)))
        if name in ABSOLUTE:
            peak = peak_of(xs)
        write(OUT, name, xs, peak)
        print(f"    wrap step {ratio:.2f}x median")
    for j, (name, fn) in enumerate(SHOTS):
        xs = fade_edges(fn(10 + j))
        check_attacks(name, xs)
        write(OUT, name, xs, SHOT_PEAK)
    missing = set(SFX_DB) - {s for s, _ in SHOTS}
    if missing:
        raise SystemExit(f"SFX_DB names without a sound: {sorted(missing)}")


if __name__ == "__main__":
    main()
