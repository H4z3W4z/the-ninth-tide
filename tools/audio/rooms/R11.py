#!/usr/bin/env python3
"""R11 sounds: the Dry Stair (a stair through standing water, a bell with no clapper).

Standard library only, via tools/audio/common.py. One fixed seed per sound,
random.Random(1931_11_00 + k), so a rerun writes byte-identical 22050 Hz mono WAVs to
assets/audio/R11/. Structure follows R08.py: seed(), n_of(), write_loop().

Character: R11 is defined by ABSENCE. No sound here drips, sloshes or moves like water, though
the stair is full of it. The bed is dry, close stairwell air. Water exists only as pressure and
glass: low flex, thick-pane resonance, a rim being rubbed.

The bell has no clapper, so no toll ever has a strike transient: each is a 0.6 s swell from
silence into an inharmonic partial stack (196 Hz x 1, 2.0, 2.76, 5.4, 8.9), then a long
exponential decay that reaches silence by about 10 s after the swell begins.

Loop contract (shared with R11_view):
  * every loop is rendered one second long from a strictly periodic score and closed with
    seamless(1.0), so sample k is phase k / SR and the last sample runs into the first;
  * r11_bell_above and r11_bell_below are exactly 16.000 s (352800 samples). The toll swell
    begins at t = TOLL_AT (0.5 s), peaks at 1.1 s, and the file is digital silence from
    TOLL_SILENT (10.9 s) to the end. The view keys dust and latch motion to playback position.
  * r11_line_pulse is 12 s on the R08 breath cadence (LINE_CYCLE below);
  * r11_glass carries a sub flex every 6 s (at 1.0, 7.0, 13.0 s);
  * r11_pressure crests at 6 s and 18 s (masonry creak at each crest).

Levels: loops are mastered to about LOOP_RMS_DB (-18 dBFS RMS); the "very low"/"faint" beds
(line_pulse, glass) sit 4 dB under, and the bell loops are mastered so the toll itself (0.5 to
10.9 s) sits at LOOP_RMS_DB. One-shots peak at -3 dBFS; the view sets final level. The sudden
one-shots (SUDDEN below, matching SFX_SOFT) keep every transient's attack at 8 ms or longer.

    python3 tools/build_audio.py R11
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F401,F403
from common import SR, TAU, brown, highpass, lowpass, room_out, seamless, smooth_walk, white, write  # noqa: E402

OUT = room_out("R11")

LOOP_RMS_DB = -18.0
SHOT_PEAK = 10 ** (-3 / 20)   # -3 dBFS peak
SUDDEN_ATTACK = 0.008         # every sudden transient: an 8 ms raised-cosine rise

BELL_F0 = 196.0
BELL_PARTIALS = [            # (ratio, amplitude, decay tau s): no strike, so no noise, no click
    (1.0, 1.00, 2.30),
    (2.0, 0.62, 1.80),
    (2.76, 0.46, 1.40),
    (5.4, 0.26, 0.95),
    (8.9, 0.13, 0.65),
]
BELL_ATTACK = 0.6
BELL_LOOP = 16.0
TOLL_AT = 0.5
TOLL_SILENT = 10.9            # bell loops are exactly zero from here to the end
TOLL_LEN = TOLL_SILENT - TOLL_AT

# (time s, inhale 0..1), cosine-eased: the R08 breath cadence (swell 4 s, hold, release).
LINE_CYCLE = [(0.0, 0.0), (4.0, 1.0), (5.6, 1.0), (9.4, 0.12), (11.2, 0.0), (12.0, 0.0)]


def seed(k: int) -> random.Random:
    return random.Random(1931_11_00 + k)


def n_of(seconds: float) -> int:
    return int(round(seconds * SR))


def silence(seconds: float) -> list[float]:
    return [0.0] * n_of(seconds)


# ---------------------------------------------------------------- filters and mixing

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
    return lowpass(lowpass(highpass(highpass(xs, lo), lo), hi), hi)


def lp2(xs: list[float], fc: float) -> list[float]:
    return lowpass(lowpass(xs, fc), fc)


def mix(dst: list[float], src: list[float], at_s: float, gain: float = 1.0) -> list[float]:
    start = n_of(at_s)
    for i, x in enumerate(src):
        j = start + i
        if 0 <= j < len(dst):
            dst[j] += gain * x
    return dst


def mix_periodic(dst: list[float], src: list[float], at_s: float, period: float, gain: float = 1.0) -> list[float]:
    for k in (-1, 0, 1, 2):
        mix(dst, src, at_s + k * period, gain)
    return dst


def rms(xs: list[float]) -> float:
    return math.sqrt(sum(x * x for x in xs) / max(1, len(xs)))


def unit(xs: list[float]) -> list[float]:
    r = rms(xs)
    return [x / max(1e-12, r) for x in xs]


def peak_unit(xs: list[float]) -> list[float]:
    m = max(1e-12, max(abs(x) for x in xs))
    return [x / m for x in xs]


def rc(i: int, a: int) -> float:
    return (0.5 - 0.5 * math.cos(math.pi * i / a)) if i < a else 1.0


def fade_edges(xs: list[float], fin: float = 0.004, fout: float = 0.01) -> list[float]:
    a, b = max(1, n_of(fin)), max(1, n_of(fout))
    n = len(xs)
    for i in range(min(a, n)):
        xs[i] *= 0.5 - 0.5 * math.cos(math.pi * i / a)
    for i in range(min(b, n)):
        xs[n - 1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / b)
    return xs


def env_at(knots, t: float) -> float:
    if t <= knots[0][0]:
        return knots[0][1]
    for (t0, v0), (t1, v1) in zip(knots, knots[1:]):
        if t <= t1:
            x = (t - t0) / (t1 - t0)
            return v0 + (v1 - v0) * (0.5 - 0.5 * math.cos(math.pi * x))
    return knots[-1][1]


# ---------------------------------------------------------------- small sources

def click(rnd: random.Random, length: float, attack: float, modes, noise: float = 0.3,
          noise_lp: float = 5000) -> list[float]:
    """A shaped mechanical transient: raised-cosine attack, decaying modal partials, noise."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(white(n, rnd), noise_lp)
    out = []
    for i in range(n):
        t = i / SR
        v = sum(amp * math.sin(TAU * f * t) * math.exp(-t / tau) for f, amp, tau in modes)
        v += noise * nz[i] * math.exp(-t / max(0.006, attack))
        out.append(rc(i, a) * v)
    return out


def thock(rnd: random.Random, length: float, f: float, tau: float, attack: float = 0.003,
          body_lp: float = 700, body: float = 0.8) -> list[float]:
    """A dull low impact: a slightly falling sine thump with a lowpassed noise body."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(white(n, rnd), body_lp)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ph += TAU * f * (1 + 0.4 * math.exp(-t / 0.01)) / SR
        out.append(rc(i, a) * math.exp(-t / tau) * (math.sin(ph) + body * nz[i]))
    return out


def noise_burst(rnd: random.Random, length: float, lo: float, hi: float, attack: float, tau: float) -> list[float]:
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = bandlimit(white(n, rnd), lo, hi)
    return [rc(i, a) * math.exp(-(i / SR) / tau) * x for i, x in enumerate(nz)]


def swish(rnd: random.Random, length: float, lo: float, hi: float, shape=(0.3, 0.7)) -> list[float]:
    """Friction: band noise under a sine-hump envelope peaking at shape[0], with grain."""
    n = n_of(length)
    nz = bandlimit(white(n, rnd), lo, hi)
    grain = smooth_walk(n, rnd, 0.008)
    pk = shape[0]
    out = []
    for i in range(n):
        x = i / n
        e = math.sin(0.5 * math.pi * x / pk) if x < pk else math.cos(0.5 * math.pi * (x - pk) / (1 - pk))
        out.append(e * e * (shape[1] + (1 - shape[1]) * grain[i]) * nz[i])
    return out


def ratchet(rnd: random.Random, attack: float = 0.0012, ring: float = 1.0) -> list[float]:
    """One pawl over one tooth: a tiny lift tick, then the crisp drop."""
    out = silence(0.16)
    mix(out, click(rnd, 0.03, 0.001, [(4100, 0.5, 0.003), (6200, 0.25, 0.002)], noise=0.2), 0.0, 0.35)
    mix(out, click(rnd, 0.14, attack, [(2350, 1.0, 0.012 * ring), (3620, 0.6, 0.008 * ring),
                                       (5150, 0.35, 0.005 * ring), (1180, 0.4, 0.02 * ring)],
                   noise=0.45, noise_lp=7000), 0.018)
    return out


def brass_stop(rnd: random.Random, f_body: float, f_ring: float, weight: float = 1.0,
               attack: float = 0.002) -> list[float]:
    out = silence(0.45)
    mix(out, thock(rnd, 0.4, f_body, 0.06 * weight, attack, 600), 0.0, 0.9)
    mix(out, click(rnd, 0.35, attack, [(f_ring, 0.55, 0.07), (f_ring * 2.27, 0.25, 0.035),
                                       (f_ring * 3.9, 0.1, 0.015)], noise=0.35), 0.001, 0.7)
    return out


def creak(rnd: random.Random, f: float, length: float, rate0: float, rate1: float,
          attack: float = 0.003, drift: float = 0.0) -> list[float]:
    """Iron stick-slip: soft impulses at a drifting rate ringing a low resonance and its third.
    The resonances are swept by `drift` (fraction) over the length."""
    n = n_of(length)
    exc = [0.0] * n
    a = max(2, n_of(attack))
    t = 0.004
    while t < length - 0.02:
        x = t / length
        amp = (0.55 + 0.45 * rnd.random()) * math.sin(math.pi * min(1.0, x * 1.15)) ** 0.6
        j = n_of(t)
        for m in range(a * 2):
            if j + m < n:
                exc[j + m] += amp * math.sin(math.pi * m / (a * 2))
        rate = rate0 + (rate1 - rate0) * x
        t += (1 / rate) * rnd.uniform(0.75, 1.25)
    # a slowly drifting resonance, done as three fixed bands crossfaded along the length
    outs = []
    for k, d in enumerate((0.0, 0.5, 1.0)):
        fc = f * (1 + drift * d)
        outs.append([lo + 0.45 * mi for lo, mi in zip(biquad_bp(exc, fc, 10), biquad_bp(exc, fc * 3.1, 8))])
    out = []
    for i in range(n):
        x = 2 * i / n
        if x < 1:
            out.append(outs[0][i] * (1 - x) + outs[1][i] * x)
        else:
            out.append(outs[1][i] * (2 - x) + outs[2][i] * (x - 1))
    return peak_unit(out)


# ---------------------------------------------------------------- the bell

def toll(rnd: random.Random, length: float = TOLL_LEN, glide_cents: float = 0.0, sag: float = 0.0,
         cutoff: float | None = None) -> tuple[list[float], list[float]]:
    """One clapperless toll, starting from exact silence at t = 0.

    Returns (signal, envelope). Each partial is a close pair (a slow warble), swells in over
    BELL_ATTACK with a raised-cosine-squared rise (no transient, no noise), then decays at its
    own tau. glide_cents bends all partials upward over the length; sag (fraction) bends them
    downward as the toll decays. A cosine release closes everything to zero by `length`.
    """
    n = n_of(length)
    a = n_of(BELL_ATTACK)
    rel = n_of(1.6)
    beats = [rnd.uniform(0.35, 1.1) for _ in BELL_PARTIALS]
    lags = [0.04 * k for k in range(len(BELL_PARTIALS))]   # upper partials bloom a little later
    phases = [[rnd.uniform(0, TAU), rnd.uniform(0, TAU)] for _ in BELL_PARTIALS]
    out, envs = [], []
    for i in range(n):
        t = i / SR
        mult = 1.0
        if glide_cents:
            mult *= 2 ** (glide_cents / 1200 * min(1.0, t / length))
        if sag:
            mult *= 1 - sag * (1 - math.exp(-t / 3.2))
        tail = 1.0 if i < n - rel else 0.5 + 0.5 * math.cos(math.pi * (i - (n - rel)) / rel)
        v = 0.0
        e_main = 0.0
        for k, (r, amp, tau) in enumerate(BELL_PARTIALS):
            f = BELL_F0 * r * mult
            tl = t - lags[k]
            if tl <= 0:
                rise = 0.0
            elif tl < BELL_ATTACK:
                rise = (0.5 - 0.5 * math.cos(math.pi * tl / BELL_ATTACK)) ** 1.5
            else:
                rise = 1.0
            dec = math.exp(-max(0.0, tl - BELL_ATTACK) / tau) if tl > 0 else 0.0
            g = amp * rise * dec
            ph = phases[k]
            ph[0] += TAU * f / SR
            ph[1] += TAU * (f + beats[k]) / SR
            v += g * (0.6 * math.sin(ph[0]) + 0.4 * math.sin(ph[1]))
            if k == 0:
                e_main = rise * dec
        out.append(v * tail)
        envs.append(e_main * tail)
    del a
    if cutoff:
        out = lp2(out, cutoff)
    return out, envs


def bell_through(rnd: random.Random, below: bool) -> list[float]:
    """The toll as heard through floorboards (above) or iron and depth (below)."""
    if below:
        sig, env = toll(rnd, sag=0.03)
        sig = lp2(sig, 450)
        boom = []                       # one octave down, damp, at 30 %, sagging with the toll
        ph = 0.0
        for i, e in enumerate(env):
            t = i / SR
            ph += TAU * (BELL_F0 / 2) * (1 - 0.03 * (1 - math.exp(-t / 3.2))) / SR
            boom.append(e ** 1.4 * (math.sin(ph) + 0.25 * math.sin(2 * ph + 0.7)))
        boom = lowpass(boom, 260)
        s_peak = max(abs(x) for x in sig)
        b_peak = max(1e-9, max(abs(x) for x in boom))
        out = [s + 0.30 * s_peak * b / b_peak for s, b in zip(sig, boom)]
        return out
    sig, env = toll(rnd)
    sig = lp2(sig, 900)
    n = len(sig)
    # woody box: the floor's cavity at 120 Hz, excited by the toll and a breath of board noise
    nz = lowpass(white(n, rnd), 400)
    drive = [e * z for e, z in zip(env, nz)]    # the boards answer the toll's energy, not its pitch
    box = biquad_bp(biquad_bp(drive, 120, 8), 120, 8)
    box2 = biquad_bp(drive, 240, 7)     # its second mode carries the wood on small speakers
    s_peak = max(abs(x) for x in sig)
    b_peak = max(1e-9, max(abs(x) for x in box))
    return [s + 0.22 * s_peak * (b + 0.5 * c) / b_peak for s, b, c in zip(sig, box, box2)]


def bell_loop(rnd: random.Random, below: bool) -> list[float]:
    """17 s of a 16 s-periodic score: the toll at TOLL_AT (and TOLL_AT + 16, so seamless()
    crossfades identical material). Silent outside [TOLL_AT, TOLL_SILENT]."""
    t = bell_through(rnd, below)
    out = silence(BELL_LOOP + 1.0)
    mix_periodic(out, t, TOLL_AT, BELL_LOOP)
    return out


# ---------------------------------------------------------------- loops

def r11_air() -> list[float]:
    rnd = seed(1)
    dur, period = 21.0, 20.0
    n = n_of(dur)
    bed = unit(highpass(lp2(brown(n, rnd), 380), 28))
    close = unit(bandlimit(white(n, rnd), 160, 400))   # the stair's own small air, still under 400 Hz
    walk = smooth_walk(n, rnd, 4.0)
    out = []
    for i in range(n):
        t = i / SR
        # 41 Hz pressure presence; 2 cycles per 20 s of slow breathing in its level, periodic
        pres = math.sin(TAU * 41.0 * t) * (0.8 + 0.2 * math.sin(TAU * t / period * 2))
        pres += 0.18 * math.sin(TAU * 82.0 * t + 0.4)
        out.append(bed[i] * (0.88 + 0.12 * walk[i]) + 0.22 * close[i] + 0.16 * pres)
    return lowpass(out, 400)


def r11_line_pulse() -> list[float]:
    rnd = seed(2)
    period = LINE_CYCLE[-1][0]
    n = n_of(period + 1.0)
    src = unit(brown(n, rnd))
    pipe = unit([a + 0.6 * b for a, b in zip(biquad_bp(src, 88, 3.5), biquad_bp(src, 176, 5))])
    hiss = unit(bandlimit(white(n, rnd), 220, 700))
    out = []
    for i in range(n):
        t = i / SR
        e = env_at(LINE_CYCLE, t % period)
        tone = math.sin(TAU * 44.0 * t) + 0.5 * math.sin(TAU * 132.0 * t)   # periodic over 12 s
        out.append((0.12 + 0.88 * e) * (pipe[i] + 0.25 * tone) + 0.18 * e * e * hiss[i])
    return lowpass(out, 900)


def r11_glass() -> list[float]:
    rnd = seed(3)
    period = 18.0
    n = n_of(period + 1.0)
    beat = 1.0 / 18.0                  # integer cycles per loop keeps the singing periodic
    rub = unit(biquad_bp(white(n, rnd), 1100, 30))
    walk = smooth_walk(n, rnd, 1.5)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        b = 0.5 + 0.5 * math.cos(TAU * beat * t)
        b2 = 0.5 + 0.5 * math.cos(TAU * 2 * beat * t + 1.1)
        v = (0.35 + 0.65 * b) * (math.sin(TAU * 1100.0 * t) + math.sin(TAU * (1100.0 + beat) * t + 0.3))
        v += 0.55 * (0.35 + 0.65 * b2) * math.sin(TAU * 1650.0 * t + 0.8)
        v += 0.12 * rub[i] * (0.6 + 0.4 * walk[i])
        out[i] = 0.30 * v
    for at in (1.0, 7.0, 13.0):        # soft sub flex every 6 s
        mix_periodic(out, flex(rnd, 1.8, 0.0, gain_shimmer=0.0), at, period, 1.35)
    return out


def r11_pressure() -> list[float]:
    rnd = seed(4)
    period = 24.0
    n = n_of(period + 1.0)
    rumble = unit(bandlimit(brown(n, rnd), 60, 220))
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        s = 0.5 - 0.5 * math.cos(TAU * t / 12.0)          # 0 at 0, 12, 24; crest at 6, 18
        f = 30.0 + 15.0 * s                              # 30 -> 45 -> 30 Hz; integral = 900 cycles / 24 s
        ph += TAU * f / SR
        tone = math.sin(ph) + 0.45 * math.sin(2 * ph + 0.5) + 0.22 * math.sin(3 * ph + 1.3)
        lvl = 0.18 + 0.82 * s ** 1.6
        out[i] = lvl * tone + 0.6 * lvl * lvl * rumble[i]   # the rumble carries it on small speakers
    for at, g in ((5.85, 1.0), (17.9, 0.8)):            # masonry creak at each crest
        c = creak(rnd, rnd.uniform(210, 250), 0.7, 28, 14, attack=0.004, drift=-0.06)
        c = [x * (0.5 - 0.5 * math.cos(TAU * i / len(c))) for i, x in enumerate(c)]
        mix_periodic(out, lowpass(c, 1400), at, period, 0.38 * g)
    return out


# ---------------------------------------------------------------- glass

def flex(rnd: random.Random, length: float, shimmer_at: float, gain_shimmer: float = 1.0,
         f_lo: float = 60.0, f_hi: float = 90.0) -> list[float]:
    """The pane bending: a 60-90 Hz wobble swelling in and out (no transient), its harmonics for
    small speakers, and a faint glassy shimmer on top. No splash, no drip."""
    n = n_of(length)
    walk = smooth_walk(n, rnd, 0.12)
    out, ph = [], 0.0
    sh = [rnd.uniform(0, TAU) for _ in range(3)]
    for i in range(n):
        x = i / n
        env = math.sin(math.pi * x) ** 2
        bend = 0.5 - 0.5 * math.cos(TAU * 1.5 * x)          # down-up-down across the length
        f = f_lo + (f_hi - f_lo) * bend
        ph += TAU * f / SR
        v = math.sin(ph) + 0.5 * math.sin(2 * ph + 0.3) + 0.25 * math.sin(3 * ph + 0.9)
        v *= env * (0.85 + 0.3 * walk[i])
        if gain_shimmer:
            t = i / SR
            se = max(0.0, math.sin(math.pi * min(1.0, max(0.0, (x - shimmer_at) / (1 - shimmer_at))))) ** 2
            v += gain_shimmer * 0.06 * se * (math.sin(TAU * 1100 * t + sh[0]) +
                                             0.7 * math.sin(TAU * 1652 * t + sh[1]) +
                                             0.35 * math.sin(TAU * 2470 * t + sh[2]))
        out.append(v)
    return out


# ---------------------------------------------------------------- one-shots

def r11_wheel_click() -> list[float]:
    rnd = seed(20)
    out = silence(0.4)
    mix(out, ratchet(rnd), 0.004)
    mix(out, thock(rnd, 0.25, 140, 0.05, 0.004, 500), 0.05, 0.5)     # line pressure answering
    mix(out, click(rnd, 0.2, 0.002, [(910, 0.4, 0.06), (1840, 0.15, 0.03)], noise=0.1), 0.052, 0.3)
    return out


def r11_wheel_dead() -> list[float]:
    rnd = seed(20)                      # deliberately wheel_click's seed: the very same ratchet ...
    out = silence(0.3)
    r = ratchet(rnd, ring=0.6)
    r = highpass(r, 700)                # ... dry, nothing behind it
    hollow = biquad_bp(r, 460, 12)      # and a hollow empty housing
    mix(out, [a + 0.6 * b for a, b in zip(r, peak_unit(hollow))], 0.004)
    return out


def r11_plate_pick() -> list[float]:
    rnd = seed(21)
    out = silence(0.45)
    mix(out, swish(rnd, 0.17, 1500, 5200, (0.4, 0.5)), 0.0, 0.5)
    mix(out, click(rnd, 0.25, 0.002, [(2620, 0.4, 0.06), (4310, 0.2, 0.03)], noise=0.15), 0.16, 0.5)
    return out


def r11_plate_set() -> list[float]:
    rnd = seed(22)
    out = silence(0.35)
    mix(out, swish(rnd, 0.06, 1500, 4000), 0.0, 0.25)
    mix(out, click(rnd, 0.25, 0.0015, [(1820, 0.8, 0.03), (3940, 0.4, 0.015), (6100, 0.2, 0.008)],
                   noise=0.4, noise_lp=6000), 0.055)
    mix(out, thock(rnd, 0.2, 260, 0.025, 0.002), 0.056, 0.6)
    return out


def r11_lever_pull() -> list[float]:
    rnd = seed(23)
    out = silence(0.75)
    mix(out, swish(rnd, 0.3, 500, 2800, (0.6, 0.6)), 0.0, 0.35)
    for k, at in enumerate((0.06, 0.15, 0.23)):     # detents along the quadrant
        mix(out, click(rnd, 0.05, 0.001, [(3100 + 200 * k, 0.5, 0.006)], noise=0.2), at, 0.25)
    mix(out, brass_stop(rnd, 150, 1240), 0.3)
    return out


def r11_lever_refuse() -> list[float]:
    rnd = seed(24)
    out = silence(0.6)
    mix(out, swish(rnd, 0.06, 500, 2000), 0.0, 0.2)
    mix(out, thock(rnd, 0.3, 118, 0.045, 0.003, 450, body=1.0), 0.05)      # the dull jolt
    mix(out, click(rnd, 0.1, 0.002, [(980, 0.3, 0.02)], noise=0.3, noise_lp=2500), 0.051, 0.4)
    mix(out, swish(rnd, 0.14, 400, 1600, (0.2, 0.6)), 0.12, 0.15)          # spring back
    mix(out, click(rnd, 0.06, 0.002, [(1400, 0.3, 0.01)], noise=0.2, noise_lp=3000), 0.27, 0.25)
    return lowpass(out, 3500)


def flag_clack(rnd: random.Random) -> list[float]:
    out = silence(0.25)
    mix(out, click(rnd, 0.2, 0.0015, [(1520, 0.8, 0.025), (3330, 0.45, 0.012), (5200, 0.2, 0.006)],
                   noise=0.45, noise_lp=6500), 0.0)
    mix(out, thock(rnd, 0.12, 310, 0.018, 0.002), 0.001, 0.5)
    return out


def r11_flags() -> list[float]:
    rnd = seed(25)
    out = silence(0.45)
    mix(out, flag_clack(rnd), 0.005)
    mix(out, flag_clack(rnd), 0.125, 0.9)
    return out


def heavy_bolt(rnd: random.Random, slide: float, f: float, attack: float) -> list[float]:
    """An iron bolt drawn back: a heavy grinding slide, then the clunk at the end of its travel."""
    out = silence(slide + 0.5)
    sl = swish(rnd, slide, 180, 1600, (0.55, 0.45))
    body = lowpass([abs(x) for x in sl], 40)
    grind = [x * (1 + 2.5 * math.sin(TAU * 34 * i / SR) ** 2) for i, x in enumerate(sl)]
    mix(out, [g + 0.4 * b * math.sin(TAU * f * 1.6 * i / SR) for i, (g, b) in enumerate(zip(grind, body))],
        0.0, 0.55)
    mix(out, thock(rnd, 0.45, f, 0.09, attack, 500, body=1.0), slide - 0.01)
    mix(out, click(rnd, 0.3, attack, [(720, 0.5, 0.05), (1530, 0.3, 0.03), (2900, 0.12, 0.012)],
                   noise=0.4, noise_lp=4000), slide - 0.008, 0.55)
    return [rc(i, n_of(attack)) * x for i, x in enumerate(out)]


def r11_bolts_draw() -> list[float]:
    rnd = seed(26)
    out = silence(3.3)
    for k, at in enumerate((0.0, 0.4, 0.8)):            # three bolts, 1.1 s from first to last clunk
        mix(out, heavy_bolt(rnd, 0.3, 92 - 6 * k, SUDDEN_ATTACK), at, 1.0 - 0.06 * k)
    # the grille rising in its iron guides: a ticking roll, then the top stop
    g0, glen = 1.35, 1.3
    roll = swish(rnd, glen, 250, 2200, (0.5, 0.55))
    mix(out, roll, g0, 0.35)
    t = 0.0
    while t < glen - 0.05:
        mix(out, click(rnd, 0.06, SUDDEN_ATTACK, [(1250 + rnd.uniform(-90, 90), 0.4, 0.015),
                                                   (2650, 0.15, 0.008)], noise=0.2), g0 + t, 0.22)
        t += rnd.uniform(0.07, 0.11)
    mix(out, brass_stop(rnd, 110, 860, 1.4, SUDDEN_ATTACK), g0 + glen, 0.75)
    return out


def r11_glass_flex() -> list[float]:
    rnd = seed(27)
    return flex(rnd, 2.4, 0.25)


def r11_glass_pass() -> list[float]:
    rnd = seed(28)
    return lowpass(flex(rnd, 0.6, 0.3, 0.4, 66, 84), 700)


def r11_bell_up() -> list[float]:
    rnd = seed(29)
    sig, _ = toll(rnd, length=9.8, glide_cents=6.0)
    return sig


def r11_port_open() -> list[float]:
    rnd = seed(30)
    n = n_of(0.34)
    nz = bandlimit(white(n, rnd), 1200, 6000)
    out = []
    for i in range(n):
        t = i / SR
        x = t / 0.3
        e = math.sin(math.pi * min(1.0, x)) ** 0.7 if x < 1 else 0.0
        teeth = 0.35 + 0.65 * (0.5 + 0.5 * math.cos(TAU * (70 + 40 * x) * t)) ** 3   # leaf-over-leaf rasp
        out.append(e * teeth * nz[i])
    res = silence(0.45)
    mix(res, out, 0.0, 0.8)
    mix(res, click(rnd, 0.1, 0.0015, [(2850, 0.5, 0.012), (4700, 0.2, 0.006)], noise=0.3), 0.3, 0.6)
    return res


def r11_false_water() -> list[float]:
    rnd = seed(31)
    out = silence(4.2)
    mix(out, thock(rnd, 0.9, 46, 0.28, 0.016, 220, body=0.6), 0.0)
    mix(out, thock(rnd, 0.5, 92, 0.12, 0.016, 300, body=0.4), 0.0, 0.45)   # carries it on small speakers
    n = n_of(4.0)
    tail = bandlimit(brown(n, rnd), 35, 260)
    tail = unit(tail)
    mix(out, [x * 0.09 * (1 - math.exp(-(i / SR) / 0.08)) * math.exp(-(i / SR) / 1.4) for i, x in enumerate(tail)],
        0.05)
    return lowpass(out, 600)       # airless: nothing above the thud survives


def r11_plane_touch() -> list[float]:
    rnd = seed(32)
    out = silence(0.3)
    mix(out, thock(rnd, 0.25, 175, 0.03, 0.004, 450, body=1.1), 0.0)
    mix(out, thock(rnd, 0.2, 340, 0.015, 0.004, 600, body=0.5), 0.0, 0.3)
    return lowpass(lowpass(out, 900), 900)


def r11_salt_tick() -> list[float]:
    rnd = seed(33)
    out = silence(1.0)
    t = 0.02
    for k in range(rnd.randint(4, 6)):
        f = rnd.uniform(5200, 7600)
        mix(out, click(rnd, 0.03, 0.0008, [(f, 1.0, 0.003), (f * 1.41, 0.4, 0.002)], noise=0.5, noise_lp=9000),
            t, rnd.uniform(0.4, 1.0) * (1 - 0.1 * k))
        t += rnd.uniform(0.06, 0.2)
    return out


def r11_shelf_hush() -> list[float]:
    rnd = seed(34)
    dur = 2.4
    out = silence(dur)
    t = 0.05
    while t < 2.0:                      # paper leaves settling, softly, in clusters
        x = t / 2.0
        g = math.sin(math.pi * x) ** 0.7 * rnd.uniform(0.3, 1.0)
        mix(out, noise_burst(rnd, 0.08, 900, 5000, 0.006, rnd.uniform(0.01, 0.03)), t, g)
        t += rnd.uniform(0.02, 0.09)
    out = lp2(out, 700)                 # as if through water
    out = [x + 0.25 * y for x, y in zip(out, [0.0] * n_of(0.05) + out)]   # one distant reflection
    return out


def shoe_heel(rnd: random.Random) -> list[float]:
    out = silence(0.4)
    mix(out, thock(rnd, 0.35, 108, 0.05, SUDDEN_ATTACK, 500, body=0.9), 0.0)
    mix(out, thock(rnd, 0.25, 285, 0.025, SUDDEN_ATTACK, 900, body=0.6), 0.002, 0.45)   # the board
    return out


def r11_shoe_set() -> list[float]:
    rnd = seed(35)
    out = silence(0.75)
    mix(out, shoe_heel(rnd), 0.0)
    mix(out, shoe_heel(rnd), 0.2, 0.85)
    return lp2(out, 900)                # through the floor above


def clip_click(rnd: random.Random, f: float) -> list[float]:
    return click(rnd, 0.12, 0.0012, [(f, 0.7, 0.02), (f * 1.62, 0.35, 0.012), (f * 2.9, 0.15, 0.006)],
                 noise=0.35, noise_lp=7000)


def glass_slide(rnd: random.Random, length: float) -> list[float]:
    sl = swish(rnd, length, 1800, 6500, (0.5, 0.7))
    return [x + 0.2 * abs(x) * math.sin(TAU * 3300 * i / SR) for i, x in enumerate(sl)]


def r11_frame_mount() -> list[float]:
    rnd = seed(36)
    out = silence(0.8)
    mix(out, glass_slide(rnd, 0.36), 0.0, 0.55)
    mix(out, click(rnd, 0.2, 0.002, [(3300, 0.4, 0.05), (5050, 0.15, 0.03)], noise=0.1), 0.35, 0.4)  # glass seat
    mix(out, clip_click(rnd, 2450), 0.46)
    mix(out, clip_click(rnd, 2580), 0.55, 0.9)
    return out


def r11_frame_unmount() -> list[float]:
    rnd = seed(37)
    out = silence(0.8)
    mix(out, clip_click(rnd, 2700), 0.0, 0.9)
    mix(out, clip_click(rnd, 2560), 0.08, 0.85)
    mix(out, glass_slide(rnd, 0.4), 0.2, 0.55)
    return out


def r11_bridge_seat() -> list[float]:
    rnd = seed(38)
    out = silence(0.4)
    mix(out, swish(rnd, 0.08, 1200, 4000, (0.7, 0.6)), 0.0, 0.25)   # pins entering
    felt = lowpass(click(rnd, 0.15, 0.002, [(1950, 0.6, 0.012), (3100, 0.25, 0.006)], noise=0.3, noise_lp=3000),
                   3000)
    mix(out, felt, 0.075)
    mix(out, thock(rnd, 0.15, 410, 0.016, 0.002, 800, body=0.5), 0.076, 0.7)
    return out


def r11_copy_snap() -> list[float]:
    rnd = seed(39)
    out = silence(0.5)
    mix(out, click(rnd, 0.3, SUDDEN_ATTACK, [(3250, 0.9, 0.02), (5600, 0.55, 0.012), (7200, 0.3, 0.006),
                                              (1450, 0.4, 0.03)], noise=0.6, noise_lp=9000), 0.0)
    mix(out, thock(rnd, 0.2, 230, 0.03, SUDDEN_ATTACK), 0.0, 0.6)
    n = n_of(0.22)                      # the shutter spring humming out
    mix(out, [rc(i, n_of(SUDDEN_ATTACK)) * 0.18 * math.exp(-(i / SR) / 0.05) *
              math.sin(TAU * 920 * (i / SR) + 0.6 * math.sin(TAU * 31 * i / SR)) for i in range(n)], 0.004)
    return out


def r11_preview_print() -> list[float]:
    rnd = seed(40)
    count = rnd.randint(6, 9)
    out = silence(0.12 + count * 0.085 + 0.25)
    t = 0.01
    for k in range(count):
        mix(out, click(rnd, 0.12, 0.0012, [(1700 + rnd.uniform(-120, 120), 0.7, 0.018), (3900, 0.35, 0.008)],
                       noise=0.4), t, rnd.uniform(0.75, 1.0))
        mix(out, thock(rnd, 0.1, 340, 0.016, 0.0015), t + 0.001, 0.45)
        t += rnd.uniform(0.065, 0.095)
    return out


def r11_access_lever() -> list[float]:
    rnd = seed(41)
    out = silence(0.95)
    mix(out, swish(rnd, 0.42, 250, 1800, (0.65, 0.5)), 0.0, 0.4)
    for k, at in enumerate((0.1, 0.22, 0.33)):
        mix(out, click(rnd, 0.06, 0.0015, [(1900 + 150 * k, 0.5, 0.01), (720, 0.3, 0.02)], noise=0.25), at, 0.3)
    mix(out, brass_stop(rnd, 92, 760, 1.6), 0.42, 1.1)
    return out


def r11_door_bolts() -> list[float]:
    rnd = seed(42)
    out = silence(2.0)
    for at, slide, f in ((0.0, 0.55, 68), (0.74, 0.66, 62)):   # two deep bolts; the last lands at 1.39 s
        mix(out, heavy_bolt(rnd, slide, f, SUDDEN_ATTACK), at, 1.0)
    mix(out, thock(rnd, 0.6, 52, 0.16, SUDDEN_ATTACK, 300, body=0.7), 1.43, 0.6)  # the door relaxing
    return lowpass(out, 3200)


def r11_bridge_eject() -> list[float]:
    rnd = seed(43)
    out = silence(0.6)
    n = n_of(0.35)
    ping = [rc(i, n_of(0.0015)) * math.exp(-(i / SR) / 0.08) *
            (math.sin(TAU * 1480 * (i / SR) * (1 - 0.03 * (i / n))) + 0.3 * math.sin(TAU * 3720 * i / SR))
            for i in range(n)]
    mix(out, ping, 0.0, 0.7)
    mix(out, click(rnd, 0.05, 0.0012, [(2600, 0.5, 0.008)], noise=0.3), 0.0, 0.4)
    mix(out, thock(rnd, 0.2, 165, 0.03, 0.006, 600, body=1.2), 0.14, 0.6)   # caught in a palm
    return out


def r11_door_swing() -> list[float]:
    rnd = seed(44)
    out = silence(3.3)
    c = creak(rnd, 132, 2.5, 18, 9, attack=0.004, drift=-0.12)
    env = [math.sin(math.pi * min(1.0, i / len(c) * 1.05)) ** 0.5 for i in range(len(c))]
    sh = smooth_walk(len(c), rnd, 0.25)
    mix(out, [x * e * (0.7 + 0.3 * s) for x, e, s in zip(c, env, sh)], 0.0)
    mix(out, swish(rnd, 2.4, 120, 500, (0.5, 0.4)), 0.05, 0.12)               # the door's weight in the air
    mix(out, thock(rnd, 0.7, 76, 0.13, 0.012, 300, body=0.9), 2.5, 0.65)      # soft settle on the wall
    mix(out, thock(rnd, 0.4, 150, 0.05, 0.012, 400), 2.5, 0.25)
    return lowpass(out, 2600)


# ---------------------------------------------------------------- build

def write_loop(name: str, xs: list[float], rms_db: float = LOOP_RMS_DB, fade: float = 1.0,
               window: tuple[float, float] | None = None) -> None:
    """Closes the loop with seamless(fade) and masters it to rms_db (measured over `window`
    seconds when given: the bell loops are mostly, and deliberately, silence)."""
    xs = seamless(xs, fade)
    seg = xs if window is None else xs[n_of(window[0]):n_of(window[1])]
    r = rms(seg)
    m = max(abs(x) for x in xs)
    peak = min(0.95, 10 ** (rms_db / 20) * m / max(1e-9, r))
    write(OUT, name, xs, peak)


LOOPS = [
    ("r11_air", r11_air, LOOP_RMS_DB, None),
    ("r11_line_pulse", r11_line_pulse, LOOP_RMS_DB - 4.0, None),
    ("r11_glass", r11_glass, LOOP_RMS_DB - 4.0, None),
    ("r11_bell_above", lambda: bell_loop(seed(5), False), LOOP_RMS_DB, (TOLL_AT, TOLL_SILENT)),
    ("r11_bell_below", lambda: bell_loop(seed(6), True), LOOP_RMS_DB, (TOLL_AT, TOLL_SILENT)),
    ("r11_pressure", r11_pressure, LOOP_RMS_DB, None),
]

SHOTS = [
    ("r11_wheel_click", r11_wheel_click), ("r11_wheel_dead", r11_wheel_dead),
    ("r11_plate_pick", r11_plate_pick), ("r11_plate_set", r11_plate_set),
    ("r11_lever_pull", r11_lever_pull), ("r11_lever_refuse", r11_lever_refuse),
    ("r11_flags", r11_flags), ("r11_bolts_draw", r11_bolts_draw),
    ("r11_glass_flex", r11_glass_flex), ("r11_glass_pass", r11_glass_pass),
    ("r11_bell_up", r11_bell_up), ("r11_port_open", r11_port_open),
    ("r11_false_water", r11_false_water), ("r11_plane_touch", r11_plane_touch),
    ("r11_salt_tick", r11_salt_tick), ("r11_shelf_hush", r11_shelf_hush),
    ("r11_shoe_set", r11_shoe_set), ("r11_frame_mount", r11_frame_mount),
    ("r11_frame_unmount", r11_frame_unmount), ("r11_bridge_seat", r11_bridge_seat),
    ("r11_copy_snap", r11_copy_snap), ("r11_preview_print", r11_preview_print),
    ("r11_access_lever", r11_access_lever), ("r11_door_bolts", r11_door_bolts),
    ("r11_bridge_eject", r11_bridge_eject), ("r11_door_swing", r11_door_swing),
]

SUDDEN = {"r11_bolts_draw", "r11_bell_up", "r11_shoe_set", "r11_copy_snap", "r11_door_bolts"}
SWELLS = {"r11_bell_up", "r11_glass_flex", "r11_glass_pass", "r11_false_water", "r11_shelf_hush",
          "r11_door_swing"}


def main() -> None:
    print(f"Writing to {OUT}")
    for name, fn, db, window in LOOPS:
        write_loop(name, fn(), db, window=window)
    for name, fn in SHOTS:
        xs = fn()
        if name in SWELLS:
            xs = fade_edges(xs, 0.02, 0.12)
        elif name in SUDDEN:
            xs = fade_edges(xs, SUDDEN_ATTACK, 0.02)
        else:
            xs = fade_edges(xs, 0.004, 0.01)
        write(OUT, name, xs, SHOT_PEAK)


if __name__ == "__main__":
    main()
