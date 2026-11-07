#!/usr/bin/env python3
"""R01 The Jetty: seeded, standard-library synthesis into assets/audio/R01/<id>.wav.

    python3 tools/audio/rooms/R01.py        (or: python3 tools/build_audio.py R01)

Every sound has its own random.Random(fixed seed); no wall clock, so reruns are
byte-identical. Loops are crossfaded through common.seamless() and are gapless at the seam.
Peaks: loops 0.6, one-shots 0.8, bells (station_bell_*, bell_low) 0.7.

SYNC: sea_slap.wav is exactly 8.0 s = 176400 samples at 22050 Hz. Its five piling slaps
start at sample-accurate onsets:

    slap   time    sample
     1     0.0 s        0
     2     1.6 s    35280
     3     3.2 s    70560
     4     4.8 s   105840
     5     6.4 s   141120

Each slap rises from its onset sample (3 ms attack). The bed is made seamless first and the
slaps are added afterwards with wrap-around, so the tail of slap 5 rings into the loop head
and the onsets are never moved or smeared by the crossfade. The R01 view leads its visual
chop by 0.45 s against this loop (band 3: the sound arrives a beat late).

BELLS: station_bell_1..4 share bell_strike(): partials f, 2.76f, 5.40f, 8.93f with
exponential decays (partials above 0.45*SR are dropped to avoid aliasing; that only removes
8.93f of bell 1). Then a jetty echo (0.21 s, feedback 0.25), cut to 2.5 s.
station_bell_2_dead is the same bell-2 strike for 0.18 s (before the first echo at 0.21 s,
so its samples equal station_bell_2's), a 40 ms fade to silence, then nothing to 1.4 s.
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import (SR, TAU, band, brown, echo, env_ad, highpass, lowpass, room_out,  # noqa: E402
                    seamless, smooth_walk, white, write)

OUT = room_out("R01")
LOOP_PEAK, ONESHOT_PEAK, BELL_PEAK = 0.6, 0.8, 0.7

SLAP_ONSETS_S = (0.0, 1.6, 3.2, 4.8, 6.4)
SEA_SLAP_S = 8.0

BELL_RATIOS = (1.0, 2.76, 5.40, 8.93)
BELL_DECAYS = (0.85, 0.42, 0.20, 0.09)   # seconds, per partial
BELL_AMPS = (1.0, 0.55, 0.32, 0.18)
BELL_F = {1: 1320.0, 2: 1100.0, 3: 925.0, 4: 780.0}
BELL_S, BELL_ECHO_S, BELL_ECHO_FB = 2.5, 0.21, 0.25
DEAD_CUT_S, DEAD_FADE_S, DEAD_FILE_S = 0.18, 0.040, 1.4


# ---- small local helpers (common.py is read-only) ------------------------------------

def n_of(s: float) -> int:
    return int(round(s * SR))


def zeros(s: float) -> list[float]:
    return [0.0] * n_of(s)


def add(dst: list[float], src: list[float], at: int, gain: float = 1.0, wrap: bool = False) -> None:
    """Mixes src into dst starting at sample `at`; with wrap, overflow wraps to the start."""
    n = len(dst)
    for j, x in enumerate(src):
        k = at + j
        if k >= n:
            if not wrap:
                break
            k %= n
        dst[k] += x * gain


def fit(xs: list[float], s: float, fade_s: float = 0.05) -> list[float]:
    """Pads or cuts to exactly s seconds, with a short cosine fade-out at the end."""
    n = n_of(s)
    xs = (xs + [0.0] * n)[:n]
    f = n_of(fade_s)
    for i in range(f):
        xs[n - f + i] *= 0.5 * (1 + math.cos(math.pi * (i + 1) / f))
    return xs


def resonator(xs: list[float], freqs, q: float) -> list[float]:
    """Two-pole band-pass (constant peak gain); freqs is a float or a per-sample list."""
    y1 = y2 = 0.0
    out = []
    for i, x in enumerate(xs):
        f = freqs[i] if isinstance(freqs, list) else freqs
        w = TAU * f / SR
        r = math.exp(-w / (2 * q))
        y = (1 - r) * x + 2 * r * math.cos(w) * y1 - r * r * y2
        y2, y1 = y1, y
        out.append(y)
    return out


def modes(n: int, parts, t0: int = 0) -> list[float]:
    """Sum of decaying sines (freq, amp, decay_s) from sample t0."""
    out = [0.0] * n
    for f, a, d in parts:
        if f >= 0.45 * SR:
            continue
        for i in range(t0, n):
            t = (i - t0) / SR
            out[i] += a * math.sin(TAU * f * t) * math.exp(-t / d)
    return out


def burst(n: int, rnd: random.Random, lo: float, hi: float, tau: float, attack: float = 0.0005) -> list[float]:
    """A short band-limited noise click."""
    env = env_ad(n, attack, tau)
    return [b * e for b, e in zip(band(white(n, rnd), lo, hi), env)]


def knock(rnd: random.Random, parts, noise=(400, 3000), noise_tau=0.004, s: float = 0.25) -> list[float]:
    n = n_of(s)
    body = modes(n, parts)
    click = burst(n, rnd, *noise, noise_tau)
    return [a + 0.8 * b for a, b in zip(body, click)]


def soft_sat(xs: list[float], drive: float) -> list[float]:
    """tanh warmth: adds harmonics so low tones survive small speakers."""
    return [math.tanh(drive * x) for x in xs]


# ---- loops ---------------------------------------------------------------------------

def sea_bed(n: int, rnd: random.Random, swell_step: float = 2.7) -> list[float]:
    """Brown swell lowpassed at 600 Hz with a slow smooth_walk, plus a mid wash."""
    body = lowpass(brown(n, rnd), 600)
    wash = band(white(n, rnd), 450, 1500)
    swell = smooth_walk(n, rnd, swell_step)
    return [b * (0.35 + 0.65 * s) + 0.5 * w * s for b, w, s in zip(body, wash, swell)]


def piling_slap(rnd: random.Random, gain: float = 1.0) -> list[float]:
    """Water slapping a timber piling: a hollow low thump and a wet slap of noise."""
    n = n_of(0.9)
    wet = burst(n, rnd, 250, 1800, 0.07, 0.003)
    spray = burst(n, rnd, 1800, 5000, 0.03, 0.006)
    thump = modes(n, ((150 + rnd.uniform(-10, 10), 0.6, 0.12), (330, 0.25, 0.06)))
    for i in range(min(n, n_of(0.003))):           # 3 ms rise from the onset sample
        thump[i] *= i / n_of(0.003)
    return [gain * (1.4 * a + 0.35 * b + c) for a, b, c in zip(wet, spray, thump)]


def sea_jetty() -> list[float]:
    rnd = random.Random(1_01_001)
    n = n_of(13.0)
    xs = sea_bed(n, rnd)
    t = 0.7
    while t < 11.6:                                  # irregular soft slaps, none in the seam
        add(xs, piling_slap(rnd, rnd.uniform(0.18, 0.35)), n_of(t))
        t += rnd.uniform(1.1, 2.9)
    return seamless(xs, 1.0)


def sea_slap() -> list[float]:
    rnd = random.Random(1_01_002)
    bed = seamless(sea_bed(n_of(SEA_SLAP_S + 1.0), rnd, 1.6), 1.0)
    bed = [x * 0.55 for x in bed]
    assert len(bed) == n_of(SEA_SLAP_S)
    for k, t in enumerate(SLAP_ONSETS_S):
        add(bed, piling_slap(rnd, (0.85, 1.0, 0.9, 0.95, 0.88)[k]), n_of(t), wrap=True)
    return bed


def sea_thin() -> list[float]:
    """No low end at all: highpassed (>700 Hz) hiss in thin, separate wave crests over a
    near-silent floor, about 40% of the jetty sea's energy (measured RMS, not just peak)."""
    rnd = random.Random(1_01_003)
    n = n_of(11.0)
    hiss = lowpass(highpass(highpass(white(n, rnd), 900), 700), 5200)
    env = [0.06] * n
    t = 0.2
    while t < 11.0:                              # a thin wave every 2-3 s, about 1 s long
        length = rnd.uniform(0.8, 1.2)
        amp = rnd.uniform(0.55, 1.0)
        s0, m = n_of(t), n_of(length)
        for j in range(min(m, n - s0)):
            u = j / m
            env[s0 + j] = max(env[s0 + j], amp * math.sin(math.pi * u ** 0.6) ** 2)
        t += rnd.uniform(2.0, 3.0)
    return seamless([h * e for h, e in zip(hiss, env)], 1.0)


def wind_jetty() -> list[float]:
    rnd = random.Random(1_01_004)
    n = n_of(15.5)
    w = band(white(n, rnd), 200, 900)
    gust = smooth_walk(n, rnd, 1.9)
    slow = smooth_walk(n, rnd, 5.0)
    return seamless([x * (0.15 + 0.85 * g * (0.5 + 0.5 * s)) for x, g, s in zip(w, gust, slow)], 1.5)


def wind_whistle() -> list[float]:
    """A narrow resonance near 1150 Hz wandering about +-60 Hz: wind through the bell post."""
    rnd = random.Random(1_01_005)
    n = n_of(10.0)
    wander = [1150 + 120 * (g - 0.5) for g in smooth_walk(n, rnd, 1.3)]
    amp = smooth_walk(n, rnd, 1.7)
    tone = resonator(white(n, rnd), wander, 90)
    air = band(white(n, rnd), 900, 1500)
    return seamless([t * a * a + 0.004 * b for t, a, b in zip(tone, amp, air)], 1.0)


def rain_planks() -> list[float]:
    """Dense, bright rain ticks on oak planking over a faint wet hiss."""
    rnd = random.Random(1_01_006)
    n = n_of(11.0)
    xs = [0.012 * h for h in highpass(white(n, rnd), 3000)]
    tick_n = n_of(0.03)
    t = 0.0
    while t < 11.0:
        f = rnd.uniform(1500, 3800)
        tick = modes(tick_n, ((f, 1.0, 0.004), (f * 1.62, 0.5, 0.0025)))
        add(xs, tick, n_of(t), rnd.uniform(0.04, 0.16))
        t += rnd.expovariate(70.0)
    return seamless(xs, 1.0)


def pressure_hum() -> list[float]:
    """38 Hz and 57 Hz, each beating against a near twin, with a pressure flutter; no noise.
    Every frequency is a whole number of cycles in 12 s (38, 38+1/6, 57, 57+1/12 Hz, flutter
    0.25 Hz), so the crossfade joins in phase. Soft saturation lends small speakers harmonics."""
    rnd = random.Random(1_01_007)
    n = n_of(13.0)
    ph = rnd.random() * TAU
    out = []
    for i in range(n):
        t = i / SR
        flutter = 1 + 0.12 * math.sin(TAU * 0.25 * t + ph)
        x = (0.55 * math.sin(TAU * 38 * t) + 0.35 * math.sin(TAU * (38 + 1 / 6) * t)
             + 0.45 * math.sin(TAU * 57 * t) + 0.30 * math.sin(TAU * (57 + 1 / 12) * t + ph))
        # Harmonics at 114, 171 and 228 Hz carry the hum onto laptop and phone speakers.
        x += (0.50 * math.sin(TAU * 114 * t) + 0.38 * math.sin(TAU * 171 * t + ph)
              + 0.20 * math.sin(TAU * 228 * t))
        out.append(x * flutter)
    return seamless(soft_sat(out, 1.6), 1.0)


def gull_call(rnd: random.Random) -> list[float]:
    """One distant gull: two or three descending FM chirps, 2.4 down to 1.6 kHz."""
    out: list[float] = []
    for _ in range(rnd.choice((2, 3, 3))):
        dur = rnd.uniform(0.16, 0.26)
        m = n_of(dur)
        ph = 0.0
        hi, lo = rnd.uniform(2200, 2400), rnd.uniform(1600, 1750)
        for i in range(m):
            u = i / m
            f = hi - (hi - lo) * u ** 0.7 + 90 * math.sin(TAU * 26 * i / SR)
            ph += TAU * f / SR
            env = math.sin(math.pi * min(1.0, u * 1.3)) ** 1.5 if u < 0.77 else 0.0
            out.append(env * (math.sin(ph) + 0.35 * math.sin(2 * ph) + 0.15 * math.sin(3 * ph)))
        out += [0.0] * n_of(rnd.uniform(0.07, 0.14))
    return lowpass(out, 3500)


def gulls() -> list[float]:
    rnd = random.Random(1_01_008)
    xs = zeros(17.0)
    for t, g in ((2.1, 0.8), (7.4, 1.0), (12.9, 0.7)):
        add(xs, gull_call(rnd), n_of(t), g)
    xs = seamless(xs, 1.0)                           # nothing sounds in the last 2 s
    return xs


def engine_idle() -> list[float]:
    """A launch two-stroke idling: 7.5 Hz exhaust pulses on a warm 70 Hz body.
    6 s holds 45 pulses and 420 body cycles exactly, so the loop joins on the beat."""
    rnd = random.Random(1_01_009)
    n = n_of(7.0)
    out = []
    for i in range(n):
        t = i / SR
        out.append(0.35 * math.sin(TAU * 70 * t) + 0.16 * math.sin(TAU * 140 * t) + 0.07 * math.sin(TAU * 210 * t))
    noise = lowpass(white(n, rnd), 900)
    period = SR / 7.5
    for k in range(int(7.0 * 7.5) + 1):
        s = int(round(k * period))
        g = rnd.uniform(0.8, 1.0)
        for j in range(min(int(period), n - s)):
            u = j / SR
            env = math.exp(-u / 0.035) * min(1.0, u / 0.002)
            out[s + j] += g * env * (1.2 * math.sin(TAU * 105 * u) + 0.5 * math.sin(TAU * 315 * u) + 2.6 * noise[s + j])
    pulse_bed = [x * (0.55 + 0.45 * math.sin(TAU * 7.5 * i / SR) ** 2) for i, x in enumerate(out)]
    return seamless(lowpass(soft_sat(pulse_bed, 1.2), 1800), 1.0)


# ---- one-shots -----------------------------------------------------------------------

def tally_flip() -> list[float]:
    rnd = random.Random(1_01_101)
    xs = zeros(0.35)
    wood = ((520, 0.8, 0.025), (910, 0.4, 0.015))
    enamel = ((2650, 0.5, 0.03), (3720, 0.35, 0.02), (5100, 0.2, 0.012))
    add(xs, knock(rnd, wood + enamel, (500, 4000), 0.003, 0.2), 0)
    add(xs, knock(rnd, wood + enamel, (500, 4000), 0.002, 0.2), n_of(0.085), 0.55)   # settles on the pin
    return fit(xs, 0.35, 0.03)


def tally_reset() -> list[float]:
    rnd = random.Random(1_01_102)
    n = n_of(0.5)
    snap = knock(rnd, ((610, 1.0, 0.02), (2900, 0.7, 0.03), (4300, 0.4, 0.015)), (600, 6000), 0.004, 0.5)
    spring = []
    for i in range(n):
        t = i / SR
        f = 230 * (1 + 0.08 * math.exp(-t / 0.05) * math.sin(TAU * 31 * t))
        spring.append(math.sin(TAU * f * t) * math.exp(-t / 0.11) * 0.45
                      + 0.2 * math.sin(TAU * 1380 * t) * math.exp(-t / 0.07))
    return fit([a + b for a, b in zip(snap, spring)], 0.5, 0.04)


def bell_pull() -> list[float]:
    """Wire hissing through a pulley as the T-handle comes down, then a short ratchet."""
    rnd = random.Random(1_01_103)
    n = n_of(0.6)
    run = band(white(n, rnd), 900, 3200)
    whine = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += TAU * (640 + 900 * t) / SR
        env = math.sin(math.pi * min(1.0, t / 0.38)) ** 2 if t < 0.38 else 0.0
        whine.append(env * (0.25 * run[i] * 3 + 0.05 * math.sin(ph)))
    xs = whine
    for k, t in enumerate((0.34, 0.39, 0.43, 0.465, 0.495)):
        tick = knock(rnd, ((1800, 0.5, 0.008), (3100, 0.4, 0.006)), (1500, 6000), 0.002, 0.05)
        add(xs, tick, n_of(t), 0.9 - 0.1 * k)
    return fit(xs, 0.6, 0.03)


def bell_strike(f: float, rnd: random.Random) -> list[float]:
    """A small hand-bell: inharmonic partials with exponential decays and a clapper tick."""
    n = n_of(BELL_S)
    parts = [(f * r, a, d) for r, a, d in zip(BELL_RATIOS, BELL_AMPS, BELL_DECAYS)]
    xs = modes(n, parts)
    tick = burst(n_of(0.01), rnd, 2000, 7000, 0.0015)
    add(xs, tick, 0, 0.35)
    return xs


def station_bell(k: int) -> list[float]:
    dry = bell_strike(BELL_F[k], random.Random(1_01_200 + k))
    return fit(echo(dry, BELL_ECHO_S, BELL_ECHO_FB), BELL_S, 0.15)


def station_bell_2_dead() -> list[float]:
    dry = bell_strike(BELL_F[2], random.Random(1_01_202))   # the same strike as station_bell_2
    cut, fade = n_of(DEAD_CUT_S), n_of(DEAD_FADE_S)
    xs = dry[:cut]
    for i in range(fade):
        xs.append(dry[cut + i] * (1 - (i + 1) / fade))
    return xs + [0.0] * (n_of(DEAD_FILE_S) - len(xs))


def bell_low() -> list[float]:
    """The mooring bell from under the water: ~110 Hz with inharmonic partials, lowpassed at
    900 Hz, swelling in over 0.4 s with no strike transient, a slow underwater waver."""
    rnd = random.Random(1_01_210)
    n = n_of(5.0)
    f = 110.0
    parts = ((0.5, 0.35, 2.4), (1.0, 1.0, 2.0), (1.19, 0.45, 1.5), (1.83, 0.55, 1.1),
             (2.76, 0.40, 0.8), (4.07, 0.25, 0.5))
    ph = rnd.random() * TAU
    out = []
    for i in range(n):
        t = i / SR
        wav = 1 + 0.004 * math.sin(TAU * 0.7 * t + ph)
        x = sum(a * math.sin(TAU * f * r * wav * t) * math.exp(-t / d) for r, a, d in parts)
        swell = 0.5 * (1 - math.cos(math.pi * t / 0.4)) if t < 0.4 else 1.0
        out.append(x * swell * (1 + 0.15 * math.sin(TAU * 2.3 * t + ph)))
    xs = lowpass(lowpass(soft_sat(out, 1.3), 900), 900)
    return fit(xs, 5.0, 0.4)


def lens_click() -> list[float]:
    rnd = random.Random(1_01_104)
    n = n_of(0.3)
    grind = band(white(n, rnd), 2500, 7000)
    xs = [g * 0.12 * math.sin(math.pi * min(1.0, i / n_of(0.17))) if i < n_of(0.17) else 0.0
          for i, g in enumerate(grind)]
    add(xs, knock(rnd, ((2300, 0.9, 0.02), (3650, 0.6, 0.014), (5900, 0.3, 0.008)),
                  (2000, 8000), 0.0015, 0.12), n_of(0.165))
    return fit(xs, 0.3, 0.03)


def pen_near() -> list[float]:
    """Pencil on paper, beside her ear: dry graphite grain in strokes, a slight high boost."""
    rnd = random.Random(1_01_105)
    n = n_of(2.2)
    grain = band(white(n, rnd), 1400, 6500)
    grit = [x if rnd.random() < 0.35 else x * 0.3 for x in grain]
    env = [0.0] * n
    t = 0.05
    while t < 2.05:
        length = rnd.uniform(0.09, 0.26)
        amp = rnd.uniform(0.55, 1.0)
        s, m = n_of(t), n_of(length)
        for j in range(m):
            if s + j < n:
                u = j / m
                env[s + j] = max(env[s + j], amp * math.sin(math.pi * u) ** 0.6 * (1 + 0.3 * math.sin(TAU * 38 * j / SR)))
        t += length + rnd.uniform(0.03, 0.12)
    xs = [g * e for g, e in zip(grit, env)]
    hi = highpass(xs, 3500)
    xs = [x + 0.6 * h for x, h in zip(xs, hi)]       # the slight high boost: close, no room
    return fit(xs, 2.2, 0.05)


def plank_step(rnd: random.Random, gain: float) -> list[float]:
    n = n_of(0.4)
    body = modes(n, ((92, 1.0, 0.08), (214, 0.6, 0.06), (407, 0.35, 0.04), (690, 0.15, 0.025)))
    heel = burst(n, rnd, 200, 1800, 0.012, 0.002)
    scuff = burst(n, rnd, 1200, 4500, 0.03, 0.01)
    return [gain * (a + 0.9 * b + 0.12 * c) for a, b, c in zip(body, heel, scuff)]


def gangway_step() -> list[float]:
    rnd = random.Random(1_01_106)
    xs = zeros(0.9)
    add(xs, plank_step(rnd, 1.0), n_of(0.03))
    add(xs, plank_step(rnd, 0.85), n_of(0.47))
    return fit(xs, 0.9, 0.05)


def door_shed() -> list[float]:
    rnd = random.Random(1_01_107)
    n = n_of(0.8)
    xs = [0.0] * n
    add(xs, knock(rnd, ((1450, 0.7, 0.02), (2900, 0.5, 0.012), (380, 0.5, 0.03)), (800, 6000), 0.003, 0.15), 0)
    ph = 0.0
    creak = []
    for i in range(n_of(0.5)):
        t = i / SR
        f = 410 + 160 * math.sin(math.pi * t / 0.5) + rnd.uniform(-15, 15)
        ph += TAU * f / SR
        stick = 0.6 + 0.4 * math.sin(TAU * 23 * t)              # stick-slip in the hinge
        env = math.sin(math.pi * t / 0.5)
        creak.append(env * stick * (math.sin(ph) + 0.5 * math.sin(2.02 * ph) + 0.25 * math.sin(3.1 * ph)))
    add(xs, lowpass(creak, 2600), n_of(0.09), 0.35)
    add(xs, knock(rnd, ((150, 0.8, 0.06), (330, 0.4, 0.04)), (200, 1500), 0.008, 0.2), n_of(0.6), 0.6)
    return fit(xs, 0.8, 0.04)


def water_close() -> list[float]:
    """Water closing over the place the hull sat: a soft, deep gulp and a little wash."""
    rnd = random.Random(1_01_108)
    n = n_of(1.6)
    body = lowpass(white(n, rnd), 320)
    gulp = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += TAU * (60 + 130 * math.exp(-t / 0.12)) / SR
        gulp.append(math.sin(ph) * math.exp(-t / 0.22) * min(1.0, t / 0.012))
    env = env_ad(n, 0.015, 0.3)
    wash = band(white(n, rnd), 400, 1600)
    wenv = [math.exp(-max(0.0, t / SR - 0.08) / 0.4) * min(1.0, t / SR / 0.08) for t in range(n)]
    xs = [0.9 * g + 2.2 * b * e + 0.06 * w * we for g, b, e, w, we in zip(gulp, body, env, wash, wenv)]
    return fit(soft_sat(xs, 1.4), 1.6, 0.2)


def capsule_rise() -> list[float]:
    """Wet line hauled over the cleat: ratchet ticks, slow then quicker, then they stop."""
    rnd = random.Random(1_01_109)
    n = n_of(3.0)
    wet = band(white(n, rnd), 700, 2400)
    stop = 2.55
    xs = [w * 0.05 * (min(1.0, i / SR / 0.3)) * (1.0 if i / SR < stop else math.exp(-(i / SR - stop) / 0.03))
          for i, w in enumerate(wet)]
    t, gap = 0.12, 0.34
    while t < stop:
        tick = knock(rnd, ((1650, 0.6, 0.01), (2780, 0.4, 0.007), (520, 0.4, 0.015)), (1000, 5000), 0.002, 0.06)
        add(xs, tick, n_of(t), rnd.uniform(0.75, 1.0))
        t += gap
        gap = max(0.055, gap * 0.86)
    return fit(xs, 3.0, 0.05)


def capsule_knock() -> list[float]:
    rnd = random.Random(1_01_110)
    xs = zeros(0.4)
    brass = ((640, 0.8, 0.06), (1710, 0.7, 0.05), (3120, 0.45, 0.03), (4480, 0.25, 0.02))
    add(xs, knock(rnd, brass + ((180, 0.6, 0.03),), (300, 4000), 0.004, 0.4), 0)
    add(xs, knock(rnd, brass, (300, 4000), 0.003, 0.3), n_of(0.11), 0.35)   # a small bounce
    return fit(xs, 0.4, 0.04)


def cap_unscrew() -> list[float]:
    """A fine brass thread turning: micro-clicks, grit, and a faint squeal mid-turn."""
    rnd = random.Random(1_01_111)
    n = n_of(1.2)
    turn = [math.sin(math.pi * min(1.0, i / n_of(1.05))) ** 0.8 if i < n_of(1.05) else 0.0 for i in range(n)]
    grit = band(white(n, rnd), 1800, 6000)
    xs = [g * 0.15 * e for g, e in zip(grit, turn)]
    t = 0.03
    while t < 1.02:
        add(xs, burst(n_of(0.006), rnd, 3000, 8000, 0.0012), n_of(t), 0.5 * turn[n_of(t)])
        t += rnd.uniform(0.018, 0.034)
    ph = 0.0
    for i in range(n_of(0.35), n_of(0.8)):
        u = (i - n_of(0.35)) / n_of(0.45)
        ph += TAU * (2750 + 60 * math.sin(TAU * 7 * i / SR)) / SR
        xs[i] += 0.06 * math.sin(math.pi * u) ** 2 * math.sin(ph)
    return fit(xs, 1.2, 0.08)


def key_take() -> list[float]:
    rnd = random.Random(1_01_112)
    xs = zeros(0.4)
    for t, g in ((0.0, 1.0), (0.07, 0.6), (0.16, 0.35)):
        f = rnd.uniform(3000, 3400)
        add(xs, modes(n_of(0.2), ((f, 1.0, 0.04), (f * 1.51, 0.6, 0.03), (f * 2.17, 0.3, 0.02))), n_of(t), g)
        add(xs, burst(n_of(0.01), rnd, 2000, 8000, 0.0015), n_of(t), 0.4 * g)
    return fit(xs, 0.4, 0.04)


def note_unfold() -> list[float]:
    """Stiff dry paper: a broad swish with a scatter of crackles as the fold gives."""
    rnd = random.Random(1_01_113)
    n = n_of(0.8)
    swish = band(white(n, rnd), 900, 4500)
    xs = [s * 0.18 * math.sin(math.pi * i / n) ** 2 for i, s in enumerate(swish)]
    for _ in range(26):
        t = rnd.uniform(0.04, 0.7)
        add(xs, burst(n_of(0.012), rnd, 1500, 7000, rnd.uniform(0.001, 0.003)), n_of(t), rnd.uniform(0.2, 0.9))
    return fit(xs, 0.8, 0.05)


LOOPS = [
    ("sea_jetty", sea_jetty), ("sea_slap", sea_slap), ("sea_thin", sea_thin),
    ("wind_jetty", wind_jetty), ("wind_whistle", wind_whistle), ("rain_planks", rain_planks),
    ("pressure_hum", pressure_hum), ("gulls", gulls), ("engine_idle", engine_idle),
]
ONESHOTS = [
    ("tally_flip", tally_flip), ("tally_reset", tally_reset), ("bell_pull", bell_pull),
    ("lens_click", lens_click), ("pen_near", pen_near), ("gangway_step", gangway_step),
    ("door_shed", door_shed), ("water_close", water_close), ("capsule_rise", capsule_rise),
    ("capsule_knock", capsule_knock), ("cap_unscrew", cap_unscrew), ("key_take", key_take),
    ("note_unfold", note_unfold),
]
BELLS = [(f"station_bell_{k}", (lambda k=k: station_bell(k))) for k in (1, 2, 3, 4)] + [
    ("station_bell_2_dead", station_bell_2_dead), ("bell_low", bell_low),
]


def main() -> None:
    for group, peak in ((LOOPS, LOOP_PEAK), (ONESHOTS, ONESHOT_PEAK), (BELLS, BELL_PEAK)):
        for name, fn in group:
            write(OUT, name, fn(), peak)


if __name__ == "__main__":
    main()
