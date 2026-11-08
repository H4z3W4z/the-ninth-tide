#!/usr/bin/env python3
"""R05 sounds: the kitchen (bowl rack, COMPARE tally, spoon drawer, ledger lectern, the hatch).

Standard library only, via tools/audio/common.py. One fixed seed per sound,
random.Random(1931_05_NN), so a rerun writes byte-identical 22050 Hz mono WAVs to
assets/audio/R05/. Loop beds are rendered one second longer than the loop and closed with
seamless(1.0); timed events inside a loop (kettle ticks, creaks, coal settles) are mixed
circularly into the closed loop, so the last sample runs straight into the first and no event
is ever cut at the seam.

Levels: loops are mastered to about -18 dBFS RMS, one-shots peak at -3 dBFS; the view sets
the final level (SFX_DB, LoopMixer targets). Every transient in this room rises over at least
4 ms (sudden ones: 6 ms), so the 12 dB "Soften sudden sounds" cut is enough on its own. The
sudden set is compare_pull, drawer_unlatch, count_reset, socket_jam, stamp_thud, board_hinge
and hatch_unlatch.

Tone: no voices, no words. China is small and dry (a short filtered noise burst plus 2-3
decaying partials in 2.4-4.8 kHz). Brass mechanisms are mid-range clunks with a short ring.
The fog is a slow breathy hiss. spoon_china is the quietest one-shot by short-term loudness
(highest crest factor); hatch_unlatch is the loudest (two bolts, then a dense low gust).

r05_draught_breath is exactly 5.2 s: rises at 0.00-0.35 and 0.50-0.85, a pause, one long rise
1.60-3.60, then rest. The view syncs the work-card flutter to that cycle (BREATH_RISES below).

    python3 tools/build_audio.py R05
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F401,F403  SR, TAU, lowpass, highpass, white, brown, ...
from common import SR, TAU, brown, echo, highpass, lowpass, room_out, seamless, smooth_walk, white, write  # noqa: E402

OUT = room_out("R05")

LOOP_RMS = 10 ** (-18 / 20)   # about -18 dBFS RMS
SHOT_PEAK = 10 ** (-3 / 20)   # -3 dBFS peak
ATTACK = 0.004                # every transient rises over >= 4 ms
SUDDEN_ATTACK = 0.006         # the sudden set rises over 6 ms

BREATH_CYCLE = 5.2
BREATH_RISES = [(0.0, 0.35), (0.5, 0.85), (1.6, 3.6)]   # (start, end) s within the cycle


def seed(nn: int) -> random.Random:
    return random.Random(int(f"193105{nn:02d}"))


def n_of(seconds: float) -> int:
    return int(round(seconds * SR))


def zeros(seconds: float) -> list[float]:
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


def mix(dst: list[float], src: list[float], at_s: float, gain: float = 1.0) -> list[float]:
    start = n_of(at_s)
    for i, x in enumerate(src):
        j = start + i
        if 0 <= j < len(dst):
            dst[j] += gain * x
    return dst


def mix_wrap(dst: list[float], src: list[float], at_s: float, gain: float = 1.0) -> list[float]:
    """Mixes src into a closed loop, wrapping past the end back to the start."""
    n, start = len(dst), n_of(at_s)
    for i, x in enumerate(src):
        dst[(start + i) % n] += gain * x
    return dst


def add(a: list[float], b: list[float], gb: float = 1.0) -> list[float]:
    return [x + gb * y for x, y in zip(a, b)]


def scale(xs: list[float], g: float) -> list[float]:
    return [x * g for x in xs]


def rms(xs: list[float]) -> float:
    return math.sqrt(sum(x * x for x in xs) / max(1, len(xs)))


def unit(xs: list[float]) -> list[float]:
    """Scaled to unit RMS, so layers are balanced by explicit gains."""
    r = rms(xs)
    return [x / max(1e-12, r) for x in xs]


def fade_edges(xs: list[float], fin: float = ATTACK, fout: float = 0.01) -> list[float]:
    a, b = max(1, n_of(fin)), max(1, n_of(fout))
    n = len(xs)
    for i in range(min(a, n)):
        xs[i] *= 0.5 - 0.5 * math.cos(math.pi * i / a)
    for i in range(min(b, n)):
        xs[n - 1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / b)
    return xs


def rise(i: int, a: int) -> float:
    return (0.5 - 0.5 * math.cos(math.pi * i / a)) if i < a else 1.0


def shaped(xs: list[float], shape) -> list[float]:
    n = max(1, len(xs) - 1)
    return [x * shape(i / n) for i, x in enumerate(xs)]


def hump(x: float, up: float = 0.3) -> float:
    """0 -> 1 -> 0 over x in [0,1], peaking at `up`, raised-cosine both ways."""
    if x <= 0 or x >= 1:
        return 0.0
    if x < up:
        return 0.5 - 0.5 * math.cos(math.pi * x / up)
    return 0.5 + 0.5 * math.cos(math.pi * (x - up) / (1 - up))


# ---------------------------------------------------------------- small sources

def click(rnd: random.Random, length: float, modes: list[tuple[float, float, float]],
          noise: float = 0.3, noise_lp: float = 5000, noise_tau: float = 0.006,
          attack: float = ATTACK) -> list[float]:
    """A shaped mechanical transient: raised-cosine attack, decaying modal partials, noise."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(white(n, rnd), noise_lp)
    out = []
    for i in range(n):
        t = i / SR
        v = sum(amp * math.sin(TAU * f * t + ph) * math.exp(-t / tau) for f, amp, tau, ph in
                ((f, amp, tau, 0.0) for f, amp, tau in modes))
        v += noise * nz[i] * math.exp(-t / noise_tau)
        out.append(rise(i, a) * v)
    return out


def thock(rnd: random.Random, length: float, f: float, tau: float, body_lp: float = 700,
          attack: float = ATTACK) -> list[float]:
    """A dull low impact: a falling sine thump with a lowpassed noise body."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(white(n, rnd), body_lp)
    nz = scale(nz, 1 / max(1e-9, rms(nz)) * 0.35)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ph += TAU * f * (1 + 0.4 * math.exp(-t / 0.01)) / SR
        out.append(rise(i, a) * math.exp(-t / tau) * (math.sin(ph) + nz[i]))
    return out


def china(rnd: random.Random, length: float = 0.18, f0: float = 3100, tau: float = 0.035,
          burst: float = 0.5, damp: float = 1.0) -> list[float]:
    """Small dry china: a short band-filtered noise burst plus three decaying 2.4-4.8 kHz partials."""
    fs = [min(4800, max(2400, f0 * r)) for r in (1.0, 1.37 + rnd.uniform(-0.03, 0.03),
                                                   0.81 + rnd.uniform(-0.02, 0.02))]
    modes = [(fs[0], 1.0, tau * damp), (fs[1], 0.45, tau * 0.6 * damp), (fs[2], 0.3, tau * 0.8 * damp)]
    xs = click(rnd, length, modes, noise=0.0)
    n = len(xs)
    nz = bandlimit(white(n, rnd), 1800, 6000)
    a = n_of(ATTACK)
    return [x + burst * z * rise(i, a) * math.exp(-i / SR / 0.004) for i, (x, z) in enumerate(zip(xs, nz))]


def brass(rnd: random.Random, length: float, f: float = 520, ring_f: float = 2300, ring: float = 0.25,
          ring_tau: float = 0.06, body_tau: float = 0.03, attack: float = ATTACK) -> list[float]:
    """A mid-range brass clunk with a short ring."""
    modes = [(f, 1.0, body_tau), (f * 2.13, 0.55, body_tau * 0.7), (f * 3.4, 0.25, body_tau * 0.5),
             (ring_f, ring, ring_tau), (ring_f * 1.52, ring * 0.4, ring_tau * 0.6)]
    return click(rnd, length, modes, noise=0.5, noise_lp=2200, noise_tau=0.008, attack=attack)


def tick_metal(rnd: random.Random, strength: float = 1.0) -> list[float]:
    """A cooling-metal tick: a tight ping off thin steel, a little wobble of pitch per tick."""
    f = 3300 * rnd.uniform(0.94, 1.06)
    modes = [(f, 1.0, 0.012), (f * 1.71, 0.5, 0.007), (f * 0.37, 0.35, 0.018), (f * 2.43, 0.2, 0.004)]
    return scale(click(rnd, 0.09, modes, noise=0.25, noise_lp=7000, noise_tau=0.002), strength)


def stick_slip(rnd: random.Random, length: float, rate, res: list[tuple[float, float, float]],
               duty: float = 0.08, shape=None) -> list[float]:
    """Friction: slip pulses at a time-varying rate(x) through resonances (f, q, gain)."""
    n = n_of(length)
    ph, pulses = 0.0, []
    for i in range(n):
        x = i / max(1, n - 1)
        ph += rate(x) / SR
        if ph >= 1:
            ph -= 1
        g = (shape(x) if shape else 1.0)
        pulses.append(g * (rnd.uniform(0.6, 1.0) if ph < duty else 0.0))
    out = [0.0] * n
    for f, q, gain in res:
        out = add(out, biquad_bp(pulses, f, q), gain)
    return out


def swish(rnd: random.Random, length: float, lo: float, hi: float, shape) -> list[float]:
    n = n_of(length)
    nz = bandlimit(white(n, rnd), lo, hi)
    return shaped(nz, shape)


def grain(rnd: random.Random, length: float, rate: float, lo: float, hi: float, shape) -> list[float]:
    """Sparse seeded micro-impulses (paper fibres, graphite, dry runners), band-limited."""
    n = n_of(length)
    out = [0.0] * n
    p = rate / SR
    for i in range(n):
        if rnd.random() < p:
            out[i] += rnd.uniform(0.4, 1.0) * rnd.choice((-1, 1))   # bounded: no lone spike
    out = bandlimit(out, lo, hi)
    return shaped(out, shape)


def drops(n: int, rnd: random.Random, rate: float, f_lo: float, f_hi: float) -> list[float]:
    """Rain on glass: seeded tiny decaying pings at a mean rate per second, circular."""
    out = [0.0] * n
    count = int(rate * n / SR)
    for _ in range(count):
        at = rnd.randrange(n)
        f = rnd.uniform(f_lo, f_hi)
        tau = rnd.uniform(0.0015, 0.004)
        amp = rnd.expovariate(1.0)
        m = int(tau * SR * 5)
        a = n_of(0.0008)
        for k in range(m):
            t = k / SR
            out[(at + k) % n] += amp * rise(k, a) * math.sin(TAU * f * t) * math.exp(-t / tau)
    return out


# ---------------------------------------------------------------- loops

def closed_bed(seconds: float, fn) -> list[float]:
    """Renders fn(n) for seconds+1 and closes it with seamless(1.0): exactly `seconds` long."""
    return seamless(fn(n_of(seconds + 1.0)), 1.0)


def r05_room() -> list[float]:
    rnd = seed(1)

    def bed(n):
        low = unit(highpass(lowpass(lowpass(brown(n, rnd), 260), 260), 30))
        air = unit(bandlimit(white(n, rnd), 220, 800))
        walk = smooth_walk(n, rnd, 1.3)
        return [(b + 0.4 * a) * (0.85 + 0.15 * w) for b, a, w in zip(low, air, walk)]

    xs = closed_bed(4.0, bed)
    creak = stick_slip(rnd, 0.9, lambda x: 70 + 25 * x, [(310, 5, 1.0), (760, 7, 0.5)],
                       shape=lambda x: hump(x, 0.4))
    creak = lowpass(creak, 900)          # far off, through walls
    return mix_wrap(xs, unit(creak), 2.3, 0.35)


def r05_rain() -> list[float]:
    rnd = seed(2)

    def bed(n):
        hiss = unit(bandlimit(white(n, rnd), 1400, 6500))
        walk = smooth_walk(n, rnd, 0.9)
        return [h * (0.9 + 0.1 * w) for h, w in zip(hiss, walk)]

    xs = closed_bed(4.0, bed)
    d = unit(highpass(drops(len(xs), rnd, 140, 2200, 6500), 900))
    return add(scale(xs, 0.45), d, 1.0)


def r05_rain_heavy() -> list[float]:
    rnd = seed(3)

    def bed(n):
        sheet = unit(bandlimit(white(n, rnd), 500, 4200))
        run = unit(bandlimit(brown(n, rnd), 180, 900))
        walk = smooth_walk(n, rnd, 0.6)
        return [(s + 0.4 * r) * (0.75 + 0.25 * w) for s, r, w in zip(sheet, run, walk)]

    xs = closed_bed(4.0, bed)
    d = unit(highpass(drops(len(xs), rnd, 420, 1500, 5200), 600))
    return add(xs, d, 0.6)


def kettle_ticks(rnd: random.Random, total: float) -> list[tuple[float, float]]:
    """11-14 ticks in uneven groups, as metal contracting: (time, strength)."""
    count = rnd.randint(11, 14)
    sizes, left = [], count
    while left > 0:
        s = min(left, rnd.choice((1, 2, 2, 3, 4, 5)))
        sizes.append(s)
        left -= s
    # Uneven silences between groups: seeded weights spread the groups over the whole loop.
    weights = [rnd.uniform(0.4, 2.2) for _ in sizes]
    unit_s = total / sum(weights)
    out, t0 = [], rnd.uniform(0, total)
    for size, wgt in zip(sizes, weights):
        t = t0
        for k in range(size):
            out.append((t % total, rnd.uniform(0.45, 1.0) * (1.0 if k == 0 else 0.8)))
            t += rnd.uniform(0.09, 0.4) * (1 + 0.4 * k)
        t0 += wgt * unit_s
    out.sort()
    for i in range(1, len(out)):          # never two ticks on top of each other
        if out[i][0] - out[i - 1][0] < 0.08:
            out[i] = (out[i - 1][0] + rnd.uniform(0.08, 0.16), out[i][1])
    return [(t % total, g) for t, g in out]


def r05_kettle() -> list[float]:
    rnd = seed(4)

    def bed(n):
        hollow = unit(bandlimit(brown(n, rnd), 70, 450))
        shell = unit(biquad_bp(white(n, rnd), 1150, 10))      # the empty kettle's faint resonance
        return unit([h + 0.25 * s for h, s in zip(hollow, shell)])

    body = closed_bed(7.0, bed)
    ticks = [0.0] * len(body)
    for t, g in kettle_ticks(rnd, 7.0):
        mix_wrap(ticks, tick_metal(rnd), t, g)
    # Ticks sit at a fixed 0.85 peak; the cold-metal hollow under them takes up the rest of the
    # -18 dBFS RMS, so the loop reaches its level without crushing a single tick.
    ticks = scale(ticks, 0.85 / max(abs(x) for x in ticks))
    rt = rms(ticks)
    gb = math.sqrt(max(0.0, LOOP_RMS ** 2 - rt ** 2))
    return add(ticks, body, gb)


def r05_draught() -> list[float]:
    rnd = seed(5)

    def bed(n):
        low = unit(highpass(lowpass(lowpass(white(n, rnd), 320), 320), 50))
        slat = unit(biquad_bp(white(n, rnd), 430, 9))
        slat2 = unit(biquad_bp(white(n, rnd), 690, 11))
        walk = smooth_walk(n, rnd, 0.8)
        return [(a + 0.22 * s + 0.12 * s2) * (0.7 + 0.3 * w) for a, s, s2, w in zip(low, slat, slat2, walk)]

    return closed_bed(4.0, bed)


def breath_env(t: float) -> float:
    """Draught level in Nora's rhythm at t seconds (periodic, 5.2 s): floor 0.12, rises to 1."""
    t %= BREATH_CYCLE
    level = 0.0
    for (a, b), peak in zip(BREATH_RISES, (0.75, 0.8, 1.0)):
        if a <= t < b:
            level = max(level, peak * hump((t - a) / (b - a), 0.55))
    return 0.12 + 0.88 * level


def r05_draught_breath() -> list[float]:
    rnd = seed(6)

    def bed(n):
        low = unit(highpass(lowpass(lowpass(white(n, rnd), 380), 380), 60))
        slat = unit(biquad_bp(white(n, rnd), 450, 8))
        air = unit(bandlimit(white(n, rnd), 700, 2400))
        out = []
        for i, (a, s, h) in enumerate(zip(low, slat, air)):
            e = breath_env(i / SR)
            out.append(e * (a + 0.25 * s + 0.18 * e * h))   # the rises open up the top a little
        return out

    xs = closed_bed(BREATH_CYCLE, bed)
    assert len(xs) == n_of(BREATH_CYCLE)
    return xs


def r05_range() -> list[float]:
    rnd = seed(7)

    def bed(n):
        roar = unit(highpass(lowpass(lowpass(brown(n, rnd), 180), 180), 35))
        flue = unit(bandlimit(white(n, rnd), 90, 320))
        walk = smooth_walk(n, rnd, 0.7)
        return [(r + 0.6 * f * (0.6 + 0.4 * w)) for r, f, w in zip(roar, flue, walk)]

    xs = closed_bed(4.0, bed)
    pops = [0.0] * len(xs)
    for _ in range(rnd.randint(18, 26)):
        c = click(rnd, 0.03, [(rnd.uniform(900, 1800), 1.0, 0.004)], noise=0.8, noise_lp=2400)
        mix_wrap(pops, c, rnd.uniform(0, 4.0), rnd.uniform(0.2, 1.0))
    for at in (rnd.uniform(0.4, 1.6), rnd.uniform(2.4, 3.6)):   # coals settling
        settle = add(thock(rnd, 0.35, 95, 0.09, 500), lowpass(grain(rnd, 0.35, 700, 300, 1600,
                                                                    lambda x: hump(x, 0.2)), 1600), 0.6)
        mix_wrap(pops, unit(settle), at, 0.5)
    return add(xs, lowpass(pops, 2400), 1.1)


# ---------------------------------------------------------------- loops, round 2 (_r2)
# The 4-7 s beds above were audibly short loops. The _r2 beds are 20 s, closed with
# seamless(xs, 1.5), and ride a slow seeded level walk (0.75 + 0.25 * smooth_walk, knots
# every 2.7 s, 1.3 s for the heavy rain) so the bed breathes instead of repeating. Same seeds as
# the originals (the extra draws come after), same mastering; the originals stay untouched.

BED_R2 = 20.0
SEAM_R2 = 1.5


def closed_bed_r2(fn) -> list[float]:
    """Renders fn(n) for BED_R2 + SEAM_R2 and closes it with seamless(SEAM_R2): exactly BED_R2."""
    xs = seamless(fn(n_of(BED_R2 + SEAM_R2)), SEAM_R2)
    assert len(xs) == n_of(BED_R2)
    return xs


def level_walk(xs: list[float], rnd: random.Random, step_s: float = 2.7) -> list[float]:
    """xs * (0.75 + 0.25 * smooth_walk): the walk is itself closed with seamless(SEAM_R2), so the
    level at the loop point runs straight on and the seam never steps."""
    n = len(xs)
    walk = seamless(smooth_walk(n + n_of(SEAM_R2), rnd, step_s), SEAM_R2)
    return [x * (0.75 + 0.25 * w) for x, w in zip(xs, walk)]


def r05_room_r2() -> list[float]:
    rnd = seed(1)

    def bed(n):
        low = unit(highpass(lowpass(lowpass(brown(n, rnd), 260), 260), 30))
        air = unit(bandlimit(white(n, rnd), 220, 800))
        walk = smooth_walk(n, rnd, 1.3)
        return [(b + 0.4 * a) * (0.85 + 0.15 * w) for b, a, w in zip(low, air, walk)]

    xs = closed_bed_r2(bed)
    for at in (2.3, rnd.uniform(8.5, 10.5), rnd.uniform(15.0, 17.5)):   # three far creaks, uneven
        creak = stick_slip(rnd, rnd.uniform(0.8, 1.1), lambda x: 70 + 25 * x,
                           [(310, 5, 1.0), (760, 7, 0.5)], shape=lambda x: hump(x, 0.4))
        mix_wrap(xs, unit(lowpass(creak, 900)), at, rnd.uniform(0.25, 0.38))
    return level_walk(xs, rnd)


def r05_rain_r2() -> list[float]:
    rnd = seed(2)

    def bed(n):
        hiss = unit(bandlimit(white(n, rnd), 1400, 6500))
        walk = smooth_walk(n, rnd, 0.9)
        return [h * (0.9 + 0.1 * w) for h, w in zip(hiss, walk)]

    xs = closed_bed_r2(bed)
    d = unit(highpass(drops(len(xs), rnd, 140, 2200, 6500), 900))
    return level_walk(add(scale(xs, 0.45), d, 1.0), rnd)


def r05_rain_heavy_r2() -> list[float]:
    rnd = seed(3)

    def bed(n):
        sheet = unit(bandlimit(white(n, rnd), 500, 4200))
        run = unit(bandlimit(brown(n, rnd), 180, 900))
        walk = smooth_walk(n, rnd, 0.6)
        return [(s + 0.4 * r) * (0.75 + 0.25 * w) for s, r, w in zip(sheet, run, walk)]

    xs = closed_bed_r2(bed)
    d = unit(highpass(drops(len(xs), rnd, 420, 1500, 5200), 600))
    return level_walk(add(xs, d, 0.6), rnd, 1.3)


def r05_draught_r2() -> list[float]:
    rnd = seed(5)

    def bed(n):
        low = unit(highpass(lowpass(lowpass(white(n, rnd), 320), 320), 50))
        slat = unit(biquad_bp(white(n, rnd), 430, 9))
        slat2 = unit(biquad_bp(white(n, rnd), 690, 11))
        walk = smooth_walk(n, rnd, 0.8)
        return [(a + 0.22 * s + 0.12 * s2) * (0.7 + 0.3 * w) for a, s, s2, w in zip(low, slat, slat2, walk)]

    return level_walk(closed_bed_r2(bed), rnd)


def r05_range_r2() -> list[float]:
    rnd = seed(7)

    def bed(n):
        roar = unit(highpass(lowpass(lowpass(brown(n, rnd), 180), 180), 35))
        flue = unit(bandlimit(white(n, rnd), 90, 320))
        walk = smooth_walk(n, rnd, 0.7)
        return [(r + 0.6 * f * (0.6 + 0.4 * w)) for r, f, w in zip(roar, flue, walk)]

    xs = closed_bed_r2(bed)
    pops = [0.0] * len(xs)
    for _ in range(rnd.randint(90, 130)):                       # the same density, over 20 s
        c = click(rnd, 0.03, [(rnd.uniform(900, 1800), 1.0, 0.004)], noise=0.8, noise_lp=2400)
        mix_wrap(pops, c, rnd.uniform(0, BED_R2), rnd.uniform(0.2, 1.0))
    for k in range(5):                                          # coals settling, one per 4 s window
        at = 4.0 * k + rnd.uniform(0.4, 3.6)
        settle = add(thock(rnd, 0.35, 95, 0.09, 500), lowpass(grain(rnd, 0.35, 700, 300, 1600,
                                                                    lambda x: hump(x, 0.2)), 1600), 0.6)
        mix_wrap(pops, unit(settle), at, 0.5)
    return level_walk(add(xs, lowpass(pops, 2400), 1.1), rnd)


# ---------------------------------------------------------------- one-shots: bowls, tally, drawer

def bowl_lift() -> list[float]:
    rnd = seed(8)
    xs = zeros(0.45)
    mix(xs, unit(swish(rnd, 0.14, 300, 2200, lambda x: hump(x, 0.3))), 0.0, 0.25)
    mix(xs, unit(china(rnd, 0.3, 2650, 0.05, burst=0.3)), 0.11, 1.0)
    return xs


def bowl_set() -> list[float]:
    rnd = seed(9)
    xs = zeros(0.4)
    mix(xs, unit(thock(rnd, 0.12, 170, 0.025, 600)), 0.0, 0.7)
    mix(xs, unit(lowpass(china(rnd, 0.2, 2500, 0.02, burst=0.2, damp=0.6), 2600)), 0.004, 0.6)
    return xs


def bowl_rack() -> list[float]:
    rnd = seed(10)
    xs = zeros(0.55)
    mix(xs, unit(swish(rnd, 0.12, 400, 2500, lambda x: hump(x, 0.6))), 0.0, 0.25)
    knock = add(thock(rnd, 0.18, 240, 0.03, 900), biquad_bp(white(n_of(0.18), rnd), 950, 3), 0.0)
    mix(xs, unit(knock), 0.11, 0.8)
    mix(xs, unit(china(rnd, 0.25, 2800, 0.03, burst=0.25)), 0.115, 0.55)
    return xs


def tally_click() -> list[float]:
    rnd = seed(11)
    xs = zeros(0.25)
    mix(xs, unit(brass(rnd, 0.08, 1150, 2900, 0.15, 0.025, 0.008)), 0.0, 0.45)   # pawl lifts
    mix(xs, unit(brass(rnd, 0.2, 980, 2600, 0.3, 0.05, 0.012)), 0.045, 1.0)     # and drops
    return xs


def compare_pull() -> list[float]:
    rnd = seed(12)
    xs = zeros(1.0)
    travel = stick_slip(rnd, 0.38, lambda x: 38 + 30 * x, [(620, 6, 1.0), (1500, 8, 0.4)],
                        duty=0.2, shape=lambda x: hump(x, 0.5))
    mix(xs, unit(add(travel, swish(rnd, 0.38, 500, 2500, lambda x: hump(x, 0.5)), 0.5)), 0.0, 0.25)
    clack = brass(rnd, 0.6, 410, 2150, 0.35, 0.09, 0.04, attack=SUDDEN_ATTACK)
    mix(xs, unit(add(clack, thock(rnd, 0.6, 120, 0.05, attack=SUDDEN_ATTACK), 0.6)), 0.37, 1.0)
    return xs


def flag_flip() -> list[float]:
    rnd = seed(13)
    xs = zeros(0.45)
    for at, g in ((0.0, 1.0), (0.13, 0.85)):
        flip = add(click(rnd, 0.06, [(2100, 1.0, 0.008), (3600, 0.4, 0.005)], noise=0.5),
                   swish(rnd, 0.06, 1500, 5000, lambda x: hump(x, 0.2)), 0.3)
        mix(xs, unit(flip), at, g)
        mix(xs, unit(click(rnd, 0.05, [(1700, 1.0, 0.006)], noise=0.3)), at + 0.045, 0.5 * g)
    return xs


def drawer_unlatch() -> list[float]:
    rnd = seed(14)
    xs = zeros(0.8)
    latch = add(brass(rnd, 0.4, 480, 1900, 0.2, 0.05, 0.035, attack=SUDDEN_ATTACK),
                thock(rnd, 0.4, 110, 0.06, 400, attack=SUDDEN_ATTACK), 0.8)
    latch = lowpass(lowpass(latch, 1000), 1000)          # muffled through the wall
    mix(xs, unit(latch), 0.0, 1.0)
    xs = echo(xs, 0.045, 0.22, 3)[: n_of(0.8)]
    return xs


def drawer_slide() -> list[float]:
    rnd = seed(15)
    xs = zeros(1.0)
    shape = lambda x: hump(x, 0.25) * (0.7 + 0.3 * math.sin(TAU * 3.2 * x) ** 2)  # noqa: E731
    runners = add(grain(rnd, 0.8, 900, 400, 3200, shape),
                  stick_slip(rnd, 0.8, lambda x: 55 + 20 * math.sin(TAU * 1.3 * x),
                             [(520, 4, 1.0), (1250, 6, 0.4)], duty=0.25, shape=shape), 0.5)
    mix(xs, unit(runners), 0.0, 0.6)
    mix(xs, unit(thock(rnd, 0.18, 200, 0.03, 900)), 0.78, 0.7)     # runs out to its stop
    return xs


def spoon_lift() -> list[float]:
    rnd = seed(16)
    whisper = swish(rnd, 0.3, 1200, 5000, lambda x: hump(x, 0.45))
    fibres = grain(rnd, 0.3, 300, 1500, 6000, lambda x: hump(x, 0.45))
    return add(unit(whisper), unit(fibres), 0.5)


def spoon_china() -> list[float]:
    """The quietest one-shot: one tiny dry touch of metal on china, almost all transient."""
    rnd = seed(17)
    xs = china(rnd, 0.12, 3600, 0.007, burst=0.2, damp=0.8)
    return lowpass(xs, 5200)


# ---------------------------------------------------------------- ledger, tiles, tokens, sockets

def book_open() -> list[float]:
    rnd = seed(18)
    xs = zeros(1.3)
    spine = stick_slip(rnd, 0.6, lambda x: 60 + 40 * x - 25 * x * x, [(340, 5, 1.0), (880, 6, 0.45)],
                       duty=0.12, shape=lambda x: hump(x, 0.35))
    mix(xs, unit(spine), 0.0, 0.7)
    mix(xs, unit(swish(rnd, 0.7, 400, 3000, lambda x: hump(x, 0.7))), 0.2, 0.35)   # air under the cover
    mix(xs, unit(thock(rnd, 0.4, 120, 0.07, 700)), 0.82, 1.0)                       # cover lands
    mix(xs, unit(grain(rnd, 0.3, 400, 1000, 5000, lambda x: hump(x, 0.1))), 0.84, 0.25)
    return xs


def page_turn() -> list[float]:
    rnd = seed(19)
    xs = zeros(0.65)
    stiff = lambda x: hump(x, 0.6)  # noqa: E731
    mix(xs, unit(add(swish(rnd, 0.42, 900, 5200, stiff), grain(rnd, 0.42, 500, 1200, 6000, stiff), 0.6)),
        0.0, 0.7)
    mix(xs, unit(add(swish(rnd, 0.1, 500, 3000, lambda x: hump(x, 0.1)),
                     thock(rnd, 0.1, 260, 0.015, 1500), 0.3)), 0.4, 0.8)            # page settles
    return xs


def tile_flip() -> list[float]:
    rnd = seed(20)
    xs = zeros(0.28)
    mix(xs, unit(brass(rnd, 0.1, 1350, 3100, 0.2, 0.02, 0.008)), 0.0, 0.6)
    mix(xs, unit(brass(rnd, 0.2, 1200, 3000, 0.35, 0.05, 0.01)), 0.07, 1.0)
    return xs


def tile_seat() -> list[float]:
    rnd = seed(21)
    xs = zeros(0.4)
    mix(xs, unit(grain(rnd, 0.08, 1500, 1000, 4000, lambda x: hump(x, 0.7))), 0.0, 0.3)
    seat = add(brass(rnd, 0.3, 760, 2500, 0.25, 0.04, 0.02), thock(rnd, 0.3, 180, 0.03, 800), 0.6)
    mix(xs, unit(seat), 0.07, 1.0)
    return xs


def tile_lift() -> list[float]:
    rnd = seed(22)
    xs = zeros(0.32)
    mix(xs, unit(brass(rnd, 0.15, 900, 2700, 0.2, 0.03, 0.012)), 0.0, 1.0)
    mix(xs, unit(grain(rnd, 0.14, 1400, 1000, 4500, lambda x: hump(x, 0.2))), 0.03, 0.4)
    return xs


def count_reset() -> list[float]:
    rnd = seed(23)
    n = n_of(0.7)
    a = n_of(SUDDEN_ATTACK)
    twang, ph = [], 0.0
    for i in range(n):
        t = i / SR
        f = 520 * (1 + 0.035 * math.sin(TAU * 31 * t) * math.exp(-t / 0.12))
        ph += TAU * f / SR
        twang.append(rise(i, a) * math.exp(-t / 0.13) * (math.sin(ph) + 0.4 * math.sin(2.01 * ph)
                                                         + 0.2 * math.sin(3.03 * ph)))
    coil = shaped(biquad_bp(white(n, rnd), 1900, 5), lambda x: math.exp(-x * 14))
    snap = brass(rnd, 0.7, 700, 2600, 0.4, 0.05, 0.02, attack=SUDDEN_ATTACK)
    xs = add(unit(snap), unit(twang), 0.55)
    return add(xs, unit(coil), 0.2)


def token_seat() -> list[float]:
    rnd = seed(24)
    xs = zeros(0.55)
    mix(xs, unit(brass(rnd, 0.45, 600, 2800, 0.45, 0.09, 0.03)), 0.0, 1.0)
    mix(xs, unit(brass(rnd, 0.3, 640, 2850, 0.4, 0.06, 0.02)), 0.075, 0.35)     # one small bounce
    return xs


def token_pull() -> list[float]:
    rnd = seed(25)
    xs = zeros(0.5)
    pry = stick_slip(rnd, 0.28, lambda x: 90 + 70 * x, [(900, 6, 1.0), (2100, 8, 0.4)], duty=0.15,
                     shape=lambda x: hump(x, 0.8))
    mix(xs, unit(pry), 0.0, 0.5)
    mix(xs, unit(brass(rnd, 0.22, 820, 2700, 0.35, 0.05, 0.015)), 0.27, 1.0)
    return xs


def socket_turn() -> list[float]:
    rnd = seed(26)
    xs = zeros(0.85)
    grind = stick_slip(rnd, 0.38, lambda x: 45 + 25 * x, [(330, 4, 1.0), (760, 6, 0.6), (1600, 8, 0.25)],
                       duty=0.2, shape=lambda x: hump(x, 0.5))
    mix(xs, unit(grind), 0.0, 0.55)
    mix(xs, unit(brass(rnd, 0.45, 450, 2350, 0.35, 0.1, 0.035)), 0.37, 1.0)
    return xs


def socket_jam() -> list[float]:
    rnd = seed(27)
    xs = zeros(0.55)
    grind = stick_slip(rnd, 0.14, lambda x: 50 + 10 * x, [(320, 4, 1.0), (740, 6, 0.6)], duty=0.25,
                       shape=lambda x: hump(x, 0.8))
    mix(xs, unit(grind), 0.0, 0.45)
    stop = add(brass(rnd, 0.35, 380, 1800, 0.08, 0.02, 0.025, attack=SUDDEN_ATTACK),
               thock(rnd, 0.35, 90, 0.05, 500, attack=SUDDEN_ATTACK), 0.9)        # dead: no ring
    mix(xs, unit(stop), 0.13, 1.0)
    return xs


def seal_click() -> list[float]:
    rnd = seed(28)
    return brass(rnd, 0.16, 1500, 3300, 0.3, 0.03, 0.008)


def stamp_thud() -> list[float]:
    rnd = seed(29)
    xs = zeros(0.85)
    body = thock(rnd, 0.8, 85, 0.11, 400, attack=SUDDEN_ATTACK)
    board = biquad_bp(thock(rnd, 0.8, 260, 0.05, 1200, attack=SUDDEN_ATTACK), 300, 2)
    clank = brass(rnd, 0.5, 520, 2000, 0.2, 0.05, 0.03, attack=SUDDEN_ATTACK)
    mix(xs, add(add(unit(body), unit(board), 0.5), unit(clank), 0.45), 0.0, 1.0)
    return xs


def stamp_locked() -> list[float]:
    rnd = seed(30)
    stop = add(brass(rnd, 0.35, 340, 1700, 0.05, 0.02, 0.025), thock(rnd, 0.35, 130, 0.04, 500), 0.8)
    return lowpass(stop, 1800)


def reject_tape() -> list[float]:
    rnd = seed(31)
    xs = zeros(0.85)
    t, k = 0.0, 0
    while t < 0.62:
        g = rnd.uniform(0.55, 1.0) * (1.1 if k % 7 == 0 else 1.0)
        mix(xs, click(rnd, 0.025, [(1450, 1.0, 0.004), (2700, 0.5, 0.0025)], noise=0.7, noise_lp=4500), t, g)
        t += 1 / 26 * rnd.uniform(0.9, 1.1)
        k += 1
    feed = swish(rnd, 0.7, 2000, 6000, lambda x: hump(x, 0.1))
    xs = mix(xs, unit(feed), 0.0, 0.03)
    mix(xs, click(rnd, 0.08, [(900, 1.0, 0.015)], noise=0.4), 0.66, 0.7)   # tape cut
    return xs


def board_hinge() -> list[float]:
    rnd = seed(32)
    xs = zeros(2.2)
    wander = smooth_walk(n_of(1.9), rnd, 0.3)
    wn = len(wander) - 1
    groan = stick_slip(rnd, 1.9, lambda x: 85 + 70 * math.sin(math.pi * x) + 25 * wander[int(x * wn)],
                       [(560, 5, 1.0), (1320, 7, 0.55), (2400, 9, 0.2)], duty=0.1,
                       shape=lambda x: hump(x, 0.15) ** 0.6)
    mix(xs, fade_edges(unit(groan), SUDDEN_ATTACK, 0.02), 0.0, 1.0)
    mix(xs, unit(thock(rnd, 0.3, 150, 0.05, 700)), 1.86, 0.6)   # board meets the wall
    return xs


def pencil_copy() -> list[float]:
    rnd = seed(33)
    xs = zeros(2.8)
    for start, length in ((0.05, 1.05), (1.45, 1.2)):
        strokes = [rnd.uniform(0.3, 1.0) for _ in range(int(length * 9) + 2)]

        def shape(x, s=strokes, L=length):
            k = x * L * 9
            i = int(k)
            return hump(x, 0.05) * s[i] * (0.5 - 0.5 * math.cos(TAU * (k - i)))

        line = add(grain(rnd, length, 4000, 1800, 6500, shape), swish(rnd, length, 2500, 7000, shape), 0.3)
        mix(xs, unit(line), start, 1.0)
    return xs


def fog_creep() -> list[float]:
    rnd = seed(34)
    n = n_of(5.2)
    hiss = unit(bandlimit(white(n, rnd), 2200, 7500))
    breath = unit(bandlimit(white(n, rnd), 600, 2000))
    walk = smooth_walk(n, rnd, 0.6)
    out = []
    for i, (h, b, w) in enumerate(zip(hiss, breath, walk)):
        x = i / (n - 1)
        e = hump(x, 0.6) * (0.75 + 0.25 * w)
        out.append(e * (h + 0.3 * b))
    return out


def hatch_unlatch() -> list[float]:
    """The loudest event: two iron bolts draw back by themselves, then a low draught gust."""
    rnd = seed(35)
    xs = zeros(4.4)
    for at in (0.05, 0.72):
        draw = stick_slip(rnd, 0.24, lambda x: 60 + 50 * x, [(420, 4, 1.0), (980, 6, 0.6), (2100, 8, 0.2)],
                          duty=0.25, shape=lambda x: hump(x, 0.7))
        mix(xs, fade_edges(unit(draw), SUDDEN_ATTACK, 0.01), at, 0.5)
        bolt = add(brass(rnd, 0.5, 300, 1450, 0.3, 0.07, 0.04, attack=SUDDEN_ATTACK),
                   thock(rnd, 0.5, 75, 0.07, 450, attack=SUDDEN_ATTACK), 0.9)
        mix(xs, unit(bolt), at + 0.22, 1.0)
    n = n_of(3.0)
    gust = unit(highpass(lowpass(lowpass(white(n, rnd), 420), 420), 45))
    slat = unit(biquad_bp(white(n, rnd), 440, 6))
    walk = smooth_walk(n, rnd, 0.35)
    g = [(a + 0.3 * s) * hump(i / (n - 1), 0.3) ** 0.5 * (0.8 + 0.2 * w)
         for i, (a, s, w) in enumerate(zip(gust, slat, walk))]
    mix(xs, g, 1.25, 2.6)
    # Driven into a gentle saturation so the gust stays dense right up to the ceiling: at the
    # shared -3 dBFS peak this is the loudest thing the room ever does.
    m = max(abs(x) for x in xs)
    return [math.tanh(1.8 * x / m) for x in xs]


def kettle_tick() -> list[float]:
    rnd = seed(36)
    xs = zeros(1.6)
    for at, g in ((0.0, 1.0), (0.42, 0.7), (1.12, 0.85)):
        mix(xs, tick_metal(rnd), at, g)
    return xs


def card_flutter() -> list[float]:
    rnd = seed(37)
    xs = zeros(0.9)
    for k in range(5):
        at = 0.02 + k * 0.1 + rnd.uniform(-0.015, 0.015)
        mix(xs, unit(swish(rnd, 0.09, 900, 4500, lambda x: hump(x, 0.35))), at, 1.0 - 0.13 * k)
    mix(xs, unit(click(rnd, 0.06, [(1800, 1.0, 0.006), (950, 0.6, 0.01)], noise=0.4)), 0.6, 0.6)   # settles
    return xs


def steam_wisp() -> list[float]:
    rnd = seed(38)
    n = n_of(2.6)
    hiss = unit(bandlimit(white(n, rnd), 2800, 8500))
    tone = unit(biquad_bp(white(n, rnd), 1850, 14))      # a breathy throat, never a whistle
    walk = smooth_walk(n, rnd, 0.3)
    return [hump(i / (n - 1), 0.4) * (0.8 + 0.2 * w) * (h + 0.25 * t)
            for i, (h, t, w) in enumerate(zip(hiss, tone, walk))]


def chair_scrape() -> list[float]:
    """The silent chair notice: a short wooden drag over boards, low and dry, then a settle."""
    rnd = seed(39)
    xs = zeros(0.9)
    drag = stick_slip(rnd, 0.5, lambda x: 30 + 22 * x, [(210, 5, 1.0), (640, 7, 0.35)],
                      duty=0.3, shape=lambda x: hump(x, 0.4))
    mix(xs, unit(lowpass(drag, 1400)), 0.0, 0.8)
    mix(xs, unit(thock(rnd, 0.2, 140, 0.03, 500)), 0.52, 0.5)
    return xs


def towel_drip() -> list[float]:
    """The silent towel notice: two drops off damp cloth onto the boards, small and close."""
    rnd = seed(40)
    xs = zeros(1.0)
    for at, g in ((0.0, 1.0), (0.55, 0.7)):
        drop = add(click(rnd, 0.08, [(1450, 1.0, 0.012), (2900, 0.3, 0.006)], noise=0.15),
                   thock(rnd, 0.08, 260, 0.01, 900), 0.4)
        mix(xs, unit(lowpass(drop, 3200)), at, g)
    return xs


# ---------------------------------------------------------------- build

LOOPS = [("r05_room", r05_room), ("r05_rain", r05_rain), ("r05_rain_heavy", r05_rain_heavy),
         ("r05_kettle", r05_kettle), ("r05_draught", r05_draught),
         ("r05_draught_breath", r05_draught_breath), ("r05_range", r05_range)]
LOOPS_R2 = [("r05_room_r2", r05_room_r2), ("r05_rain_r2", r05_rain_r2),
            ("r05_rain_heavy_r2", r05_rain_heavy_r2), ("r05_draught_r2", r05_draught_r2),
            ("r05_range_r2", r05_range_r2)]

SHOTS = [("bowl_lift", bowl_lift), ("bowl_set", bowl_set), ("bowl_rack", bowl_rack),
         ("tally_click", tally_click), ("compare_pull", compare_pull), ("flag_flip", flag_flip),
         ("drawer_unlatch", drawer_unlatch), ("drawer_slide", drawer_slide),
         ("spoon_lift", spoon_lift), ("spoon_china", spoon_china), ("book_open", book_open),
         ("page_turn", page_turn), ("tile_flip", tile_flip), ("tile_seat", tile_seat),
         ("tile_lift", tile_lift), ("count_reset", count_reset), ("token_seat", token_seat),
         ("token_pull", token_pull), ("socket_turn", socket_turn), ("socket_jam", socket_jam),
         ("seal_click", seal_click), ("stamp_thud", stamp_thud), ("stamp_locked", stamp_locked),
         ("reject_tape", reject_tape), ("board_hinge", board_hinge), ("pencil_copy", pencil_copy),
         ("fog_creep", fog_creep), ("hatch_unlatch", hatch_unlatch), ("kettle_tick", kettle_tick),
         ("card_flutter", card_flutter), ("steam_wisp", steam_wisp),
         ("chair_scrape", chair_scrape), ("towel_drip", towel_drip)]

# Suggested view levels (R05_view.gd SFX_DB) so the room keeps its intended order with every
# file at the same -3 dBFS peak: spoon_china quietest, fog barely there, hatch_unlatch loudest.
VIEW_SFX_DB_HINT = {
    "spoon_china": -18.0, "spoon_lift": -17.0, "fog_creep": -16.0, "steam_wisp": -15.0,
    "pencil_copy": -13.0, "card_flutter": -12.0, "kettle_tick": -10.0, "flag_flip": -11.0,
    "tally_click": -11.0, "seal_click": -11.0, "tile_flip": -11.0, "tile_lift": -11.0,
    "tile_seat": -10.0, "bowl_lift": -11.0, "bowl_set": -11.0, "bowl_rack": -10.0,
    "page_turn": -11.0, "book_open": -9.0, "drawer_slide": -9.0, "drawer_unlatch": -8.0,
    "token_seat": -9.0, "token_pull": -10.0, "socket_turn": -8.0, "socket_jam": -7.0,
    "reject_tape": -11.0, "stamp_locked": -9.0, "compare_pull": -7.0, "count_reset": -7.0,
    "board_hinge": -8.0, "stamp_thud": -5.0, "hatch_unlatch": -2.0,
}

SUDDEN = {"compare_pull", "drawer_unlatch", "count_reset", "socket_jam", "stamp_thud",
          "board_hinge", "hatch_unlatch"}


def soft_limit(xs: list[float], ceiling: float = 0.9) -> list[float]:
    """Smooth tanh ceiling: transparent well below `ceiling`, rounds off lone drop peaks."""
    return [ceiling * math.tanh(x / ceiling) for x in xs]


def write_loop(name: str, xs: list[float]) -> None:
    """Masters to LOOP_RMS; a loop too peaky to get there under 0.9 is soft-limited first."""
    for _ in range(6):
        xs = scale(xs, LOOP_RMS / max(1e-12, rms(xs)))
        if max(abs(x) for x in xs) <= 0.9:
            break
        xs = soft_limit(xs)
    xs = scale(xs, LOOP_RMS / max(1e-12, rms(xs)))
    write(OUT, name, xs, max(abs(x) for x in xs))


def write_shot(name: str, xs: list[float]) -> None:
    fin = SUDDEN_ATTACK if name in SUDDEN else ATTACK
    write(OUT, name, fade_edges(xs, fin, 0.02), SHOT_PEAK)


def main() -> None:
    print(f"Writing to {OUT}")
    for name, fn in LOOPS + LOOPS_R2:
        write_loop(name, fn())
    for name, fn in SHOTS:
        write_shot(name, fn())


if __name__ == "__main__":
    main()
