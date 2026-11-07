#!/usr/bin/env python3
"""R08 sounds: the Machine Room (belts, valves, grease, the restrained diaphragm).

Standard library only, via tools/audio/common.py. One fixed seed per sound,
random.Random(1931_08_NN), so a rerun writes byte-identical 22050 Hz mono WAVs to
assets/audio/R08/. Loops are rendered one second long and closed with seamless(1.0), so the
file's last sample runs straight into its first.

Phase contract (shared with R08_view): every breath and cycle loop is exactly 8.000 s
(176400 samples). Each is rendered 9.0 s from a strictly 8 s-periodic score (envelopes are
evaluated at t mod 8, events are placed at t, t+8 and t-8), so after seamless() sample k is
phase k / SR. The view starts r08_cycle / r08_cycle_two and the breath loops together and reads
the r08_breath playback position as the breath phase; the envelopes below are the source of
truth for the diaphragm's motion.

Levels: loops are mastered to about -18 dBFS RMS, except r08_breath_even (-20, "softer") and
r08_late (-27: nine dB under r08_breath_nora, whose echo it is); one-shots peak at -3 dBFS. The
view sets the final level. The sudden one-shots (pump_engage, cycle_stop, fault_buzz,
pawl_lock, belt_drop) keep every transient's attack at 6 ms or longer, so the 12 dB
"Soften sudden sounds" cut is enough on its own.

No speech and no words anywhere: the breath is shaped noise through moving resonances.

    python3 tools/build_audio.py R08
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F401,F403  SR, TAU, lowpass, highpass, white, brown, ...
from common import SR, TAU, brown, highpass, lowpass, seamless, smooth_walk, white, write  # noqa: E402

OUT = room_out("R08")  # noqa: F405

LOOP_RMS_DB = -18.0
SHOT_PEAK = 10 ** (-3 / 20)   # -3 dBFS peak
SUDDEN_ATTACK = 0.008         # every sudden transient: an 8 ms raised-cosine rise (spec floor 6 ms)

PERIOD = 8.0                  # the breath / cycle phase period, seconds

# (time s, inhale amount 0..1); smooth cosine easing between knots. Shared with R08_view.
BREATH_CYCLE = [(0.0, 0.0), (3.6, 1.0), (4.0, 1.0), (6.4, 0.15), (7.6, 0.0), (8.0, 0.0)]
BREATH_NORA = [(0.0, 0.0), (0.7, 0.45), (1.1, 0.1), (1.8, 0.45), (2.2, 0.1), (3.8, 0.1),
               (6.6, 1.0), (8.0, 0.0)]
BREATH_EVEN = [(0.0, 0.0), (4.0, 0.8), (8.0, 0.0)]

HITCH = (6.4, 7.6)            # r08_cycle: the mechanism's pause
HOLD_FLOOR = 0.05             # breath level while the envelope is still (about -26 dB under the stroke)


def seed(nn: int) -> random.Random:
    return random.Random(int(f"193108{nn:02d}"))


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


def sweep_bp(xs: list[float], fcs: list[float], q: float) -> list[float]:
    """State-variable band-pass whose centre follows fcs sample by sample (stable for moving fc)."""
    low = bp = 0.0
    damp = 1 / q
    out = []
    for x, fc in zip(xs, fcs):
        f = 2 * math.sin(math.pi * min(fc, SR / 6) / SR)
        low += f * bp
        high = x - low - damp * bp
        bp += f * high
        out.append(bp)
    return out


def bandlimit(xs: list[float], lo: float, hi: float) -> list[float]:
    """Second-order-ish band limit: two one-pole high-passes at lo, two low-passes at hi."""
    return lowpass(lowpass(highpass(highpass(xs, lo), lo), hi), hi)


def mix(dst: list[float], src: list[float], at_s: float, gain: float = 1.0) -> list[float]:
    start = n_of(at_s)
    for i, x in enumerate(src):
        j = start + i
        if 0 <= j < len(dst):
            dst[j] += gain * x
    return dst


def mix_periodic(dst: list[float], src: list[float], at_s: float, period: float, gain: float = 1.0) -> list[float]:
    """Places src at at_s + k * period for every k that touches dst: the score stays periodic."""
    for k in (-1, 0, 1, 2):
        mix(dst, src, at_s + k * period, gain)
    return dst


def scale(xs: list[float], g: float) -> list[float]:
    return [x * g for x in xs]


def rms(xs: list[float]) -> float:
    return math.sqrt(sum(x * x for x in xs) / max(1, len(xs)))


def unit(xs: list[float]) -> list[float]:
    r = rms(xs)
    return [x / max(1e-12, r) for x in xs]


def peak_unit(xs: list[float]) -> list[float]:
    m = max(1e-12, max(abs(x) for x in xs))
    return [x / m for x in xs]


def fade_edges(xs: list[float], fin: float = 0.004, fout: float = 0.01) -> list[float]:
    a, b = max(1, n_of(fin)), max(1, n_of(fout))
    n = len(xs)
    for i in range(min(a, n)):
        xs[i] *= 0.5 - 0.5 * math.cos(math.pi * i / a)
    for i in range(min(b, n)):
        xs[n - 1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / b)
    return xs


def rc(i: int, a: int) -> float:
    """Raised-cosine attack gain for sample i of an a-sample rise."""
    return (0.5 - 0.5 * math.cos(math.pi * i / a)) if i < a else 1.0


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
        v = sum(amp * math.sin(TAU * f * t) * math.exp(-t / tau) for f, amp, tau in modes)
        v += noise * nz[i] * math.exp(-t / max(0.006, attack))
        out.append(rc(i, a) * v)
    return out


def thock(rnd: random.Random, length: float, f: float, tau: float, attack: float = 0.003,
          body_lp: float = 700) -> list[float]:
    """A dull low impact: a falling sine thump with a lowpassed noise body."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(white(n, rnd), body_lp)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ph += TAU * f * (1 + 0.4 * math.exp(-t / 0.01)) / SR
        out.append(rc(i, a) * math.exp(-t / tau) * (math.sin(ph) + 0.8 * nz[i]))
    return out


def noise_burst(rnd: random.Random, length: float, lo: float, hi: float, attack: float, tau: float) -> list[float]:
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = bandlimit(white(n, rnd), lo, hi)
    return [rc(i, a) * math.exp(-(i / SR) / tau) * x for i, x in enumerate(nz)]


def hum_tone(n: int, f: float, harmonics: list[float], t0: float = 0.0) -> list[float]:
    return [sum(a * math.sin(TAU * f * (k + 1) * (t0 + i / SR)) for k, a in enumerate(harmonics))
            for i in range(n)]


def creak(rnd: random.Random, f: float = 180.0, length: float = 0.22, slips: int = 6,
          attack: float = 0.003) -> list[float]:
    """Leathery creak: a stick-slip run of soft impulses ringing a 180 Hz resonance (and its
    third, for small speakers), with a little grain of hide noise on each slip."""
    n = n_of(length)
    exc = [0.0] * n
    a = max(2, n_of(attack))
    t = 0.004
    for k in range(slips):
        amp = (0.6 + 0.4 * rnd.random()) * math.sin(math.pi * (k + 0.5) / slips)
        j = n_of(t)
        for m in range(a * 2):
            if j + m < n:
                exc[j + m] += amp * math.sin(math.pi * m / (a * 2))
        t += rnd.uniform(0.012, 0.024)
    grain = bandlimit(white(n, rnd), 400, 1800)
    hide = lowpass([abs(x) for x in exc], 60)
    hp = max(1e-9, max(hide))
    low = biquad_bp(exc, f, 9)
    mid = biquad_bp(exc, f * 3, 7)
    out = [lo + 0.45 * mi + 0.25 * g * h / hp for lo, mi, g, h in zip(low, mid, grain, hide)]
    for i in range(n):  # rings out inside the window
        out[i] *= 1.0 if i < n - n_of(0.05) else 0.5 + 0.5 * math.cos(math.pi * (i - n + n_of(0.05)) / n_of(0.05))
    return peak_unit(out)


def drip(rnd: random.Random, f0: float = 620, thick: float = 1.0) -> list[float]:
    """Oil drip: a small rising plink with a soft low splat; 4 ms rise."""
    n = n_of(0.28)
    a = n_of(0.004)
    ph, out = 0.0, []
    nz = lowpass(white(n, rnd), 900)
    for i in range(n):
        t = i / SR
        f = f0 * (1 + 0.9 * (1 - math.exp(-t / 0.018)))
        ph += TAU * f / SR
        v = math.sin(ph) * math.exp(-t / (0.03 * thick))
        v += 0.35 * nz[i] * math.exp(-t / 0.012)
        out.append(rc(i, a) * v)
    return out


def metal_tick(rnd: random.Random) -> list[float]:
    """Cooling iron: a tiny dry tick with two high inharmonic modes."""
    f = rnd.uniform(2600, 4200)
    return click(rnd, 0.06, 0.0015, [(f, 1.0, 0.008), (f * 1.53, 0.4, 0.004)], noise=0.3)


def lacing_slap(rnd: random.Random, bright: float, body_f: float, attack: float = 0.002) -> list[float]:
    """A belt's laced joint passing the pulley: leather slap and a short low thump."""
    out = silence(0.12)
    mix(out, noise_burst(rnd, 0.06, 300, 1400 + 1800 * bright, attack, 0.012), 0.0)
    mix(out, thock(rnd, 0.11, body_f, 0.025, attack), 0.001, 0.6)
    return out


def crank_knock(rnd: random.Random) -> list[float]:
    out = silence(0.4)
    mix(out, thock(rnd, 0.4, 72, 0.09, 0.003, 500), 0.0)
    mix(out, click(rnd, 0.2, 0.002, [(640, 0.5, 0.05), (1310, 0.25, 0.03), (2150, 0.1, 0.015)], noise=0.4), 0.002, 0.6)
    return out


def pump_thump(rnd: random.Random, attack: float = 0.004) -> list[float]:
    """The pump's stroke: a deep sine thump, a valve chuff after it."""
    out = silence(0.5)
    mix(out, thock(rnd, 0.45, 56, 0.11, attack, 400), 0.0)
    mix(out, thock(rnd, 0.2, 170, 0.035, attack), 0.002, 0.35)
    mix(out, noise_burst(rnd, 0.22, 300, 2200, max(attack, 0.01), 0.05), 0.09, 0.35)
    return out


# ---------------------------------------------------------------- envelopes and the breath

def env_at(knots, t: float) -> tuple[float, float]:
    """(value, derivative per second) of a cosine-eased knot envelope at time t (clamped)."""
    if t <= knots[0][0]:
        return knots[0][1], 0.0
    for (t0, v0), (t1, v1) in zip(knots, knots[1:]):
        if t <= t1:
            x = (t - t0) / (t1 - t0)
            s = 0.5 - 0.5 * math.cos(math.pi * x)
            return v0 + (v1 - v0) * s, (v1 - v0) * 0.5 * math.pi * math.sin(math.pi * x) / (t1 - t0)
    return knots[-1][1], 0.0


def turnarounds(knots) -> list[float]:
    """Knot times where the motion changes direction (rise / hold / fall), the loop wrapped."""
    slopes = [(v1 > v0) - (v1 < v0) for (_, v0), (_, v1) in zip(knots, knots[1:])]
    out = []
    for k in range(len(slopes)):
        if slopes[k - 1] != slopes[k]:
            out.append(knots[k][0])
    return out


def breath(rnd: random.Random, knots, dur: float, offset: float = 0.0, periodic: bool = True,
           warm: bool = False, creak_gain: float = 0.9) -> list[float]:
    """The diaphragm: band-passed brown noise whose loudness follows the envelope's speed.
    Inhale 250-1400 Hz with its resonance rising as it fills; exhale 150-900 Hz falling as it
    empties; a sub body under both; a leathery 180 Hz creak at every turnaround."""
    n = n_of(dur)
    period = knots[-1][0]
    es, ds = [], []
    for i in range(n):
        t = i / SR - offset
        t = t % period if periodic else min(max(t, 0.0), period)
        e, d = env_at(knots, t)
        es.append(e)
        ds.append(d)
    dmax = max(1e-9, max(abs(d) for d in ds))
    ain = [(max(0.0, d) / dmax) ** 0.6 for d in ds]
    aout = [(max(0.0, -d) / dmax) ** 0.6 for d in ds]
    k = 0.72 if warm else 1.0
    src_in, src_out, src_body = unit(brown(n, rnd)), unit(brown(n, rnd)), unit(brown(n, rnd))
    inh = sweep_bp(src_in, [k * (380 + 820 * e) for e in es], 2.6)
    inh = unit(bandlimit(inh, 250, 1400 * k))
    exh = sweep_bp(src_out, [k * (190 + 520 * e) for e in es], 2.2)
    exh = unit(bandlimit(exh, 150, 900 * k))
    body = unit(bandlimit(src_body, 45, 160))
    flutter = smooth_walk(n, rnd, 0.06)      # hide and wet membrane: an uneven grain on the air
    swell = smooth_walk(n, rnd, 0.9)
    out = []
    for i in range(n):
        g = (0.78 + 0.44 * flutter[i]) * (0.9 + 0.1 * swell[i])
        a, b = ain[i], aout[i]
        v = 1.0 * a * inh[i] + 0.95 * b * exh[i] + (0.75 if warm else 0.55) * (a + b) * body[i]
        v += HOLD_FLOOR * (0.5 * inh[i] + body[i])   # a held breath is still air under strain, never a dropout
        out.append(g * v)
    if warm:
        out = lowpass(out, 1100)
    shift = offset if periodic else 0.0
    for tt in turnarounds(knots):
        c = creak(rnd, 180 * rnd.uniform(0.96, 1.04), slips=rnd.randint(4, 7))
        g = creak_gain * rnd.uniform(0.8, 1.0) * (0.6 if warm else 1.0)
        at = tt + shift - 0.03
        if periodic:
            mix_periodic(out, c, at, period, 2.2 * g)
        elif 0 < tt < period:
            mix(out, c, at, 2.2 * g)
    return out


# ---------------------------------------------------------------- loops

def write_loop(name: str, xs: list[float], rms_db: float = LOOP_RMS_DB, fade: float = 1.0) -> None:
    xs = seamless(xs, fade)
    r = rms(xs)
    m = max(abs(x) for x in xs)
    peak = min(0.98, 10 ** (rms_db / 20) * m / max(1e-9, r))
    write(OUT, name, xs, peak)


def r08_room() -> list[float]:
    rnd = seed(1)
    dur, period = 13.0, 12.0
    n = n_of(dur)
    bed = unit(highpass(lowpass(lowpass(brown(n, rnd), 380), 380), 25))
    air = unit(bandlimit(white(n, rnd), 300, 1200))
    walk = smooth_walk(n, rnd, 3.0)
    hum = unit(hum_tone(n, 55, [1.0, 0.55, 0.35, 0.18, 0.08]))   # 110/165/220 carry it on small speakers
    out = [b * (0.85 + 0.15 * w) + 0.10 * a + 0.55 * h for b, a, w, h in zip(bed, air, walk, hum)]
    room = [0.0] * n
    for at in (0.55, 3.6, 6.45, 9.5):   # oil from a sump seam, about every 3 s
        mix_periodic(room, drip(rnd, rnd.uniform(520, 680), 1.3), at + rnd.uniform(-0.15, 0.15), period,
                     rnd.uniform(1.4, 1.9))
    t = 0.3
    while t < period:                   # cooling iron, somewhere in the plates
        mix_periodic(room, metal_tick(rnd), t, period, rnd.uniform(0.25, 0.7))
        t += rnd.uniform(0.6, 2.2)
    room = lowpass(room, 5000)
    tail = [0.0] * n                    # a hard, small iron room: short early reflections
    for _ in range(10):
        d = n_of(rnd.uniform(0.012, 0.09))
        g = 0.35 * math.exp(-3 * d / (0.09 * SR)) * rnd.choice((-1, 1))
        for i in range(d, n):
            tail[i] += g * room[i - d]
    return [o + r + q for o, r, q in zip(out, room, tail)]


def hitch_gain(t: float) -> float:
    """r08_cycle's level: full, then down to -24 dB across 6.30-6.40, held to 7.60, back by 7.78."""
    floor = 10 ** (-24 / 20)
    t %= PERIOD
    a0, a1, b0, b1 = HITCH[0] - 0.10, HITCH[0], HITCH[1], HITCH[1] + 0.18
    if t < a0 or t >= b1:
        return 1.0
    if t < a1:
        x = (t - a0) / (a1 - a0)
        return floor + (1 - floor) * (0.5 + 0.5 * math.cos(math.pi * x))
    if t < b0:
        return floor
    x = (t - b0) / (b1 - b0)
    return floor + (1 - floor) * (0.5 - 0.5 * math.cos(math.pi * x))


def mechanism(rnd: random.Random, belts, crank: bool, pump: bool, skip=None,
              attack: float = 0.002) -> list[float]:
    """The drive, 9 s of an 8 s-periodic score. belts: (period s, brightness, body Hz)."""
    n = n_of(PERIOD + 1.0)
    out = [0.0] * n

    def blocked(t: float) -> bool:
        return skip is not None and skip[0] - 0.05 <= t % PERIOD < skip[1]

    for bi, (per, bright, body_f) in enumerate(belts):
        slap = lacing_slap(rnd, bright, body_f, attack)
        gains = [rnd.uniform(0.75, 1.0) for _ in range(int(round(PERIOD / per)))]
        phase = rnd.uniform(0.05, per * 0.9)
        for k, g in enumerate(gains):
            t = phase + k * per
            if not blocked(t):
                mix_periodic(out, slap, t, PERIOD, 0.9 * g)
    if crank:
        knock = crank_knock(rnd)
        for t in (0.0, 4.0):
            mix_periodic(out, knock, t, PERIOD, 1.6)
    if pump:
        thump = pump_thump(rnd)
        for t in (0.0, 2.0, 4.0, 6.0):
            mix_periodic(out, thump, t, PERIOD, 1.5)
    # flywheel: band noise swelling once a second, and the low gear drone it drives
    whoosh = unit(bandlimit(white(n, rnd), 180, 1100))
    drone = unit(hum_tone(n, 41, [0.6, 1.0, 0.45, 0.2]))
    rumble = unit(lowpass(lowpass(brown(n, rnd), 260), 260))
    for i in range(n):
        t = i / SR
        sw = (0.5 - 0.5 * math.cos(TAU * t / 1.0)) ** 2
        out[i] += 0.32 * (0.25 + 0.75 * sw) * whoosh[i] + 0.22 * drone[i] + 0.3 * rumble[i]
    return out


def r08_cycle() -> list[float]:
    rnd = seed(2)
    out = mechanism(rnd, [(0.5, 0.7, 150), (0.8, 0.4, 120), (1.0, 0.9, 175)], crank=True, pump=False,
                    skip=HITCH)
    out = [x * hitch_gain(i / SR) for i, x in enumerate(out)]
    # the take-up at the end of the pause: the slack belt snatches, a strained creak
    mix_periodic(out, lacing_slap(rnd, 0.6, 140), HITCH[1] + 0.03, PERIOD, 1.1)
    mix_periodic(out, creak(rnd, 150, 0.3, 7), HITCH[1] - 0.04, PERIOD, 0.5)
    return out


def r08_cycle_two() -> list[float]:
    rnd = seed(3)
    return mechanism(rnd, [(0.5, 0.7, 150), (1.0, 0.9, 175)], crank=False, pump=True)


def r08_breath() -> list[float]:
    return breath(seed(4), BREATH_CYCLE, PERIOD + 1.0)


def r08_breath_nora() -> list[float]:
    return breath(seed(5), BREATH_NORA, PERIOD + 1.0)


def r08_breath_even() -> list[float]:
    return breath(seed(6), BREATH_EVEN, PERIOD + 1.0, warm=True, creak_gain=0.6)


def r08_late() -> list[float]:
    """The late reflection: BREATH_NORA 0.6 s behind, through iron (low-passed at 500 Hz)."""
    rnd = seed(7)
    xs = breath(rnd, BREATH_NORA, PERIOD + 1.0, offset=0.6)
    return lowpass(lowpass(xs, 500), 500)


def r08_hold() -> list[float]:
    rnd = seed(8)
    dur, period = 5.0, 4.0
    n = n_of(dur)
    out = []
    for i in range(n):
        t = i / SR
        lean = 0.85 + 0.15 * math.cos(TAU * t / period)
        v = (math.sin(TAU * 40 * t) + 0.75 * math.sin(TAU * 50.25 * t) + 0.55 * math.sin(TAU * 60 * t)
             + 0.30 * math.sin(TAU * 120 * t) + 0.22 * math.sin(TAU * 150.75 * t)   # small speakers
             + 0.16 * math.sin(TAU * 180 * t) + 0.08 * math.sin(TAU * 240 * t))
        out.append(lean * v)
    out = unit(out)
    strain = unit(bandlimit(white(n, rnd), 200, 900))
    sw = smooth_walk(n, rnd, 0.5)
    out = [o + 0.05 * s * w for o, s, w in zip(out, strain, sw)]
    mix_periodic(out, creak(rnd, 170, 0.5, 9, 0.008), 1.7, period, 0.9)   # the membrane, taut
    return out


def r08_drip() -> list[float]:
    rnd = seed(9)
    dur, period = 7.0, 6.0
    n = n_of(dur)
    bed = unit(highpass(lowpass(lowpass(brown(n, rnd), 300), 300), 25))
    hum = unit(hum_tone(n, 55, [0.4, 0.3, 0.15]))
    out = [0.55 * b + 0.06 * h for b, h in zip(bed, hum)]   # still: the hum barely there
    room = [0.0] * n
    for at, f in ((0.8, 600), (3.3, 540), (4.7, 650)):
        mix_periodic(room, drip(rnd, f, 1.5), at, period, 3.2)
    tail = [0.0] * n
    for _ in range(14):
        d = n_of(rnd.uniform(0.015, 0.25))
        g = 0.3 * math.exp(-3 * d / (0.25 * SR)) * rnd.choice((-1, 1))
        for i in range(d, n):
            tail[i] += g * room[i - d]
    return [o + r + q for o, r, q in zip(out, room, tail)]


# ---------------------------------------------------------------- one-shots: the board

def toggle_open() -> list[float]:
    rnd = seed(20)
    out = silence(0.25)
    mix(out, click(rnd, 0.02, 0.002, [(1300, 0.4, 0.004)], noise=0.4), 0.006, 0.35)
    mix(out, click(rnd, 0.12, 0.0008, [(1700, 0.8, 0.01), (3100, 0.7, 0.006), (4600, 0.4, 0.004)], noise=0.7), 0.025)
    m = n_of(0.2)
    spring = [0.18 * math.sin(TAU * 2350 * i / SR) * math.exp(-i / n_of(0.045)) *
              (1 + 0.3 * math.sin(TAU * 31 * i / SR)) for i in range(m)]
    return mix(out, spring, 0.03)


def toggle_shut() -> list[float]:
    rnd = seed(21)
    out = silence(0.25)
    mix(out, click(rnd, 0.02, 0.002, [(900, 0.4, 0.004)], noise=0.3), 0.006, 0.3)
    mix(out, thock(rnd, 0.2, 145, 0.035), 0.025)
    return mix(out, click(rnd, 0.1, 0.0015, [(950, 0.7, 0.012), (1850, 0.35, 0.007)], noise=0.5), 0.026, 0.6)


def board_locked() -> list[float]:
    rnd = seed(22)
    out = silence(0.3)
    mix(out, thock(rnd, 0.25, 105, 0.03, 0.004, 400), 0.01)
    mix(out, click(rnd, 0.06, 0.003, [(620, 0.5, 0.008)], noise=0.4, noise_lp=1500), 0.011, 0.5)
    for k in range(3):  # the toggle shaft rattles in its bush
        mix(out, click(rnd, 0.02, 0.002, [(1900 + 200 * k, 0.4, 0.003)], noise=0.3), 0.05 + 0.022 * k, 0.25 - 0.06 * k)
    return out


def preview_key() -> list[float]:
    rnd = seed(23)
    out = silence(0.75)
    mix(out, click(rnd, 0.05, 0.0012, [(2300, 0.9, 0.006), (3600, 0.4, 0.004)], noise=0.6), 0.005)
    n = n_of(0.62)
    a = n_of(0.03)
    buzz = []
    for i in range(n):
        t = i / SR
        s = math.sin(TAU * 120 * t)
        buzz.append(rc(i, a) * math.exp(-t / 0.22) * (0.6 * math.tanh(3 * s) + 0.25 * math.sin(TAU * 360 * t)))
    return mix(out, bandlimit(buzz, 180, 3200), 0.04, 0.6)


def trace_tick() -> list[float]:
    rnd = seed(24)
    out = silence(1.2)
    for k in range(12):
        f = rnd.uniform(3600, 4800)
        mix(out, click(rnd, 0.03, 0.001, [(f, 0.6, 0.003), (f * 1.4, 0.3, 0.002)], noise=0.5, noise_lp=7000),
            0.02 + 0.1 * k, rnd.uniform(0.5, 0.8))
        mix(out, noise_burst(rnd, 0.06, 2500, 6000, 0.005, 0.02), 0.03 + 0.1 * k, 0.08)  # nib drag
    return out


def fault_buzz() -> list[float]:
    rnd = seed(25)
    out = silence(0.5)
    n = n_of(0.44)
    a, r = n_of(SUDDEN_ATTACK + 0.004), n_of(0.04)
    buzz = []
    for i in range(n):
        t = i / SR
        s = math.sin(TAU * 110 * t + 0.4 * math.sin(TAU * 6 * t))
        env = rc(i, a) * (1.0 if i < n - r else 0.5 + 0.5 * math.cos(math.pi * (i - n + r) / r))
        env *= 0.45 + 0.55 * math.exp(-t / 0.12)   # soft: it names the fault, then backs off
        buzz.append(env * (math.tanh(1.4 * s) + 0.25 * math.sin(TAU * 220 * t) + 0.08 * rnd.uniform(-1, 1)))
    return mix(out, lowpass(lowpass(buzz, 1800), 1800), 0.01)


# ---------------------------------------------------------------- one-shots: the lever and pump

def lever_spring() -> list[float]:
    rnd = seed(26)
    out = silence(0.6)
    mix(out, noise_burst(rnd, 0.2, 500, 2500, 0.03, 0.08), 0.0, 0.12)    # handle drawn through
    for k in range(5):                                                       # ratchet
        mix(out, click(rnd, 0.03, 0.0012, [(2100, 0.7, 0.004), (3400, 0.35, 0.003)], noise=0.5),
            0.02 + 0.04 * k, 0.7)
    m = n_of(0.35)                                                           # damped spring back
    spring = [0.5 * math.sin(TAU * 380 * (i / SR) * (1 - 0.08 * i / m)) * math.exp(-i / n_of(0.08)) *
              (1 - math.exp(-i / n_of(0.004))) for i in range(m)]
    mix(out, spring, 0.23)
    return mix(out, thock(rnd, 0.15, 180, 0.03), 0.3, 0.6)


def pawl_lock() -> list[float]:
    rnd = seed(27)
    out = silence(0.5)
    a = SUDDEN_ATTACK
    mix(out, click(rnd, 0.25, a, [(880, 1.0, 0.05), (2050, 0.6, 0.03), (3350, 0.3, 0.015)], noise=0.6), 0.004)
    mix(out, thock(rnd, 0.15, 160, 0.03, a), 0.004, 0.6)
    mix(out, creak(rnd, 290, 0.32, 9, a), 0.12, 0.45)      # the lever strains against it
    return out


def pump_engage() -> list[float]:
    rnd = seed(28)
    out = silence(1.0)
    a = SUDDEN_ATTACK
    mix(out, thock(rnd, 0.9, 48, 0.2, a, 300), 0.008, 1.2)
    mix(out, thock(rnd, 0.3, 120, 0.06, a), 0.009, 0.6)
    mix(out, click(rnd, 0.3, a, [(420, 0.6, 0.07), (980, 0.35, 0.04), (1720, 0.15, 0.02)], noise=0.4), 0.01, 0.8)
    mix(out, noise_burst(rnd, 0.35, 250, 2600, 0.015, 0.08), 0.13, 0.9)    # valve chuff
    mix(out, noise_burst(rnd, 0.25, 180, 900, 0.02, 0.07), 0.15, 0.3)
    return out


def pump_run_up() -> list[float]:
    rnd = seed(29)
    dur = 2.2
    n = n_of(dur)
    out = [0.0] * n
    ph = 0.0
    whine = []
    for i in range(n):
        x = i / n
        f = 70 + 75 * (1 - math.exp(-3.2 * x))
        ph += TAU * f / SR
        env = min(1.0, x / 0.25) * (1 if x < 0.92 else (1 - x) / 0.08)
        whine.append(0.22 * env * (math.sin(ph) + 0.6 * math.sin(2 * ph) + 0.35 * math.sin(3 * ph)))
    mix(out, whine, 0.0)
    t, gap = 0.05, 0.5
    while t < dur - 0.35:
        mix(out, pump_thump(rnd), t, 0.9)
        t += gap
        gap = max(0.26, gap * 0.8)
    return out


def gauge_rise() -> list[float]:
    rnd = seed(30)
    out = silence(1.2)
    k, t = 0, 0.02
    while t < 1.1:   # the needle crosses graduations: quick at first, easing to a stop
        mix(out, click(rnd, 0.025, 0.001, [(3000 + 150 * (k % 3), 0.6, 0.004)], noise=0.3), t, 0.9 - 0.5 * t / 1.1)
        t += 0.03 + 0.012 * k * k
        k += 1
    return mix(out, noise_burst(rnd, 1.0, 1500, 4000, 0.05, 0.4), 0.0, 0.03)


def belt_wind_down() -> list[float]:
    rnd = seed(31)
    dur = 3.0
    n = n_of(dur)
    out = [0.0] * n
    slap = lacing_slap(rnd, 0.4, 120)
    t, per = 0.0, 0.25
    while t < 2.7:
        g = max(0.0, 1 - t / 2.9)
        mix(out, slap, t, g)
        t += per
        per *= 1.22
    wh = bandlimit(white(n, rnd), 180, 1100)
    rw = rms(wh)
    for i in range(n):
        x = i / n
        out[i] += 0.25 * (1 - x) ** 2 * (0.4 + 0.6 * math.sin(TAU * (2.4 * x - 0.9 * x * x)) ** 2) * wh[i] / rw
    return out


def belt_drop() -> list[float]:
    rnd = seed(32)
    out = silence(0.6)
    a = SUDDEN_ATTACK
    mix(out, thock(rnd, 0.4, 85, 0.07, a, 900), 0.005)
    mix(out, noise_burst(rnd, 0.15, 200, 1600, a, 0.03), 0.006, 0.8)       # leather on iron
    mix(out, noise_burst(rnd, 0.12, 200, 1300, a, 0.025), 0.085, 0.45)     # the slack end flops after
    mix(out, thock(rnd, 0.2, 110, 0.04, a), 0.086, 0.35)
    return out


# ---------------------------------------------------------------- one-shots: the diaphragm

def breath_alone() -> list[float]:
    rnd = seed(33)
    xs = breath(rnd, [(0.0, 0.0), (2.75, 1.0), (3.0, 1.0)], 3.0, periodic=False)
    return xs


def dust_drag() -> list[float]:
    rnd = seed(34)
    dur = 2.4
    n = n_of(dur)
    hiss = unit(bandlimit(white(n, rnd), 1400, 6500))
    scrape = unit(bandlimit(white(n, rnd), 300, 900))
    grain = smooth_walk(n, rnd, 0.015)
    out = []
    for i in range(n):
        x = i / n
        sw = math.sin(math.pi / 2 * min(1.0, x / 0.7)) ** 2 * (1 if x < 0.85 else math.cos(math.pi / 2 * (x - 0.85) / 0.15))
        out.append(sw * (hiss[i] * (0.55 + 0.45 * grain[i]) + 0.3 * scrape[i] * grain[i]))
    return out


def cycle_stop() -> list[float]:
    rnd = seed(35)
    dur = 1.4
    n = n_of(dur)
    out = [0.0] * n
    stop = 0.42
    inh = breath(rnd, [(0.0, 0.0), (1.2, 1.0)], stop, periodic=False, creak_gain=0.0)
    r = n_of(0.006)
    m = len(inh)
    inh = [x * rc(i, n_of(0.08)) * (1.0 if i < m - r else 0.5 + 0.5 * math.cos(math.pi * (i - m + r) / r))
           for i, x in enumerate(inh)]
    mix(out, scale(peak_unit(inh), 0.8), 0.0)                        # stops dead
    mech = mechanism(rnd, [(0.5, 0.7, 150), (0.8, 0.4, 120)], crank=False, pump=False,
                     attack=SUDDEN_ATTACK)[: n_of(stop)]
    mm = len(mech)
    mech = [x * rc(i, n_of(0.05)) * (1.0 if i < mm - r else 0.5 + 0.5 * math.cos(math.pi * (i - mm + r) / r))
            for i, x in enumerate(mech)]
    mix(out, scale(peak_unit(mech), 0.45), 0.0)
    a = SUDDEN_ATTACK
    mix(out, thock(rnd, 0.9, 62, 0.16, a, 400), stop - 0.004, 1.0)    # the clank
    mix(out, click(rnd, 0.95, a, [(560, 0.7, 0.18), (1240, 0.45, 0.12), (2330, 0.2, 0.06)], noise=0.5),
        stop - 0.003, 0.8)
    return out


def cycle_resume() -> list[float]:
    rnd = seed(36)
    dur = 2.6
    n = n_of(dur)
    out = [0.0] * n
    exh = breath(rnd, [(0.0, 1.0), (1.6, 0.0)], 1.7, periodic=False, creak_gain=0.5)
    mix(out, scale(peak_unit(exh), 0.85), 0.0)
    mix(out, scale(crank_knock(rnd), 0.7), 1.62)
    t, per = 1.72, 0.3
    slap = lacing_slap(rnd, 0.6, 150)
    while t < dur - 0.1:
        mix(out, slap, t, 0.45)
        t += per
        per = max(0.12, per * 0.8)
    wh = bandlimit(white(n, rnd), 180, 1100)
    rw = rms(wh)
    for i in range(n_of(1.6), n):
        x = (i - n_of(1.6)) / (n - n_of(1.6))
        out[i] += 0.2 * x * wh[i] / rw
    return out


# ---------------------------------------------------------------- one-shots: tags, bolts, plate

def brass(rnd: random.Random, f: float, amp: float = 1.0, tau: float = 0.06) -> list[float]:
    return click(rnd, 0.18, 0.001, [(f, amp, tau), (f * 2.41, 0.4 * amp, tau * 0.5), (f * 3.87, 0.2 * amp, tau * 0.3)],
                 noise=0.15, noise_lp=8000)


def tag_lift() -> list[float]:
    rnd = seed(37)
    out = silence(0.6)
    t = 0.01
    for k in range(8):
        mix(out, brass(rnd, rnd.uniform(2300, 3600)), t, rnd.uniform(0.5, 1.0) * (1 - 0.06 * k))
        t += rnd.uniform(0.03, 0.06)
    return out


def tag_flip() -> list[float]:
    rnd = seed(38)
    out = silence(0.25)
    mix(out, brass(rnd, 2900, 1.0, 0.05), 0.01)
    return mix(out, brass(rnd, 3350, 0.6, 0.04), 0.035)


def tag_settle() -> list[float]:
    rnd = seed(39)
    out = silence(1.2)
    t, k = 0.02, 0
    while t < 1.0:
        mix(out, brass(rnd, rnd.uniform(2400, 3500), 1.0, 0.07), t, 0.6 * math.exp(-t / 0.4))
        t += 0.06 + 0.035 * k
        k += 1
    return out


def bolt_tap() -> list[float]:
    rnd = seed(40)
    out = silence(0.3)
    mix(out, thock(rnd, 0.25, 210, 0.025, 0.003, 900), 0.005)
    return mix(out, click(rnd, 0.2, 0.002, [(1150, 0.35, 0.03), (2600, 0.12, 0.015)], noise=0.2), 0.006, 0.6)


def nameplate_tap() -> list[float]:
    rnd = seed(41)
    out = silence(0.3)
    return mix(out, click(rnd, 0.28, 0.0012, [(1850, 0.8, 0.04), (4150, 0.5, 0.02), (6300, 0.25, 0.01)],
                          noise=0.4, noise_lp=7000), 0.005)


# ---------------------------------------------------------------- build

LOOPS = [
    ("r08_room", r08_room, LOOP_RMS_DB),
    ("r08_cycle", r08_cycle, LOOP_RMS_DB),
    ("r08_cycle_two", r08_cycle_two, LOOP_RMS_DB),
    ("r08_breath", r08_breath, LOOP_RMS_DB),
    ("r08_breath_nora", r08_breath_nora, LOOP_RMS_DB),
    ("r08_breath_even", r08_breath_even, LOOP_RMS_DB - 2.0),
    ("r08_late", r08_late, LOOP_RMS_DB - 9.0),
    ("r08_hold", r08_hold, LOOP_RMS_DB),
    ("r08_drip", r08_drip, LOOP_RMS_DB),
]

SHOTS = [
    ("toggle_open", toggle_open), ("toggle_shut", toggle_shut), ("board_locked", board_locked),
    ("preview_key", preview_key), ("trace_tick", trace_tick), ("fault_buzz", fault_buzz),
    ("lever_spring", lever_spring), ("pawl_lock", pawl_lock), ("pump_engage", pump_engage),
    ("pump_run_up", pump_run_up), ("gauge_rise", gauge_rise), ("belt_wind_down", belt_wind_down),
    ("belt_drop", belt_drop), ("breath_alone", breath_alone), ("dust_drag", dust_drag),
    ("cycle_stop", cycle_stop), ("cycle_resume", cycle_resume), ("tag_lift", tag_lift),
    ("tag_flip", tag_flip), ("tag_settle", tag_settle), ("bolt_tap", bolt_tap),
    ("nameplate_tap", nameplate_tap),
]

SUDDEN = {"pump_engage", "cycle_stop", "fault_buzz", "pawl_lock", "belt_drop"}


def main() -> None:
    print(f"Writing to {OUT}")
    for name, fn, db in LOOPS:
        write_loop(name, fn(), db)
    for name, fn in SHOTS:
        xs = fn()
        if name in SUDDEN:
            write(OUT, name, fade_edges(xs, SUDDEN_ATTACK, 0.02), SHOT_PEAK)
        elif name == "breath_alone":
            write(OUT, name, fade_edges(xs, 0.02, 0.12), SHOT_PEAK)
        else:
            write(OUT, name, fade_edges(xs, 0.004, 0.01), SHOT_PEAK)


if __name__ == "__main__":
    main()
