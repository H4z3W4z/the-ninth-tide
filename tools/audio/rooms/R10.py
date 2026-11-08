#!/usr/bin/env python3
"""R10 sounds: the Records Vault (shelves, hanging index cards, lightbox, folders, the Index model,
the STAFF drawer and its aperture).

Standard library only, via tools/audio/common.py. One fixed seed per sound,
random.Random(1931_10_NN), so a rerun writes byte-identical 22050 Hz mono WAVs to
assets/audio/R10/. Loops are rendered one second longer than their length and closed with
seamless(1.0), so the file's last sample runs straight into its first.

Levels: loops are mastered to about -18 dBFS RMS, one-shots peak at -3 dBFS; the view sets
the final level (SFX_DB, LoopMixer targets).

Transients: no loop has a rise faster than LOOP_ATTACK (16 ms): paper crackle is noise under a
smooth walk with knots at least 18 ms apart, and every irregular loop event (wood tick, rustle,
relay chatter) is placed by a seeded walk and kept out of the crossfade window, so the seam is
never heard and nothing ticks like a metronome. The sudden one-shots (clip_snap, stamp_closed,
drawer_locked, staff_slam) keep every attack at SUDDEN_ATTACK (10 ms, >= 6 ms measured onset-to-peak), so the
12 dB "Soften sudden sounds" cut is enough on its own.

Character (GDD 12): the vault is DRY. Paper, card, oak, brass, felt. The only water is the band-4
sea through the wall (r10_sea_wall). No stingers, no musical hits. Dread is small and close.

Far versus near is the room's clue. r10_paper_far and paper_settle are paper settling further off
than the room can hold: long pre-delay (first tap 180-260 ms, five taps), weak direct sound,
heavy lowpass at 1.2 kHz. At band 7 the view swaps r10_paper_far for r10_aperture: the same
paper material (paper_grains, sheet_slide), close, dry and very quiet, swelling in a slow
inhale/exhale (4.5-6 s, seeded jitter) that never lines up with anything else in the game. The
breath is filtered noise only: no pitch, no voice, no words.

    python3 tools/build_audio.py R10
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F401,F403  SR, TAU, lowpass, highpass, white, brown, ...
from common import (SR, TAU, brown, echo, highpass, lowpass, room_out, seamless,  # noqa: E402
                    smooth_walk, white, write)

OUT = room_out("R10")

LOOP_RMS = 10 ** (-18 / 20)   # about -18 dBFS RMS
SHOT_PEAK = 10 ** (-3 / 20)   # -3 dBFS peak
LOOP_ATTACK = 0.016           # no loop transient rises faster than 16 ms
SUDDEN_ATTACK = 0.010         # every sudden transient rises over 10 ms (>= 6 ms)
FADE = 1.0                    # seamless() crossfade, seconds

AIR_HUM = 50.0      # the vault's air handler: a 50 Hz-ish hum, not the station's 60 Hz mains
MODEL_HUM = 100.0   # the Index model's open terminals
FAR_LP = 1200.0     # the far paper's heavy lowpass
AIR_MIX = 0.70      # r10_room: the dry air hush against the brown bed (unit RMS each)

# r10_paper_tick: the sparse card ticks.
TICK_SEED = 1001
TICK_GAP = (1.7, 4.1)
TICK_COUNT = 8
TICK_DECAY = 0.030
TICK_RISE = 0.001

# The bed as the view mixes it (R10_view.gd STAGE_DB, dB per weather band 0..7; None = off).
# Kept in step with the view by tests/rooms/R10_test.gd. The bed must survive a laptop speaker:
# hi_share(mix, 150) >= BED_HI_SHARE_MIN at every band.
STAGE_DB = {
    "r10_room": [-6.0] * 7 + [-5.0],
    "r10_paper_far": [None, None, -14.0, -14.0, -14.0, -14.0, -14.0, None],
    "r10_paper_tick": [-16.0] * 8,
    "r10_sea_wall": [None, None, None, None, -12.0, None, None, None],
}
BED_HI_SHARE_MIN = 0.4

# r10_aperture: breath periods, seconds (seeded jitter about 4.5-6 s; they sum to the 16 s loop).
APERTURE_LEN = 16.0


def seed(nn: int) -> random.Random:
    return random.Random(int(f"193110{nn:02d}"))


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
    """Two one-pole high-passes at lo, two low-passes at hi."""
    return lowpass(lowpass(highpass(highpass(xs, lo), lo), hi), hi)


def moving_lp(xs: list[float], fcs: list[float]) -> list[float]:
    """One-pole lowpass with a per-sample cutoff: a filter that opens and closes, no resonance."""
    y, out = 0.0, []
    for x, fc in zip(xs, fcs):
        y += (1 - math.exp(-TAU * fc / SR)) * (x - y)
        out.append(y)
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


def unit(xs: list[float]) -> list[float]:
    """Scaled to unit RMS, so beds mix by intent rather than by filter gain."""
    r = rms(xs)
    return [x / r for x in xs] if r > 0 else xs


def peak1(xs: list[float]) -> list[float]:
    p = max(1e-9, max(abs(x) for x in xs))
    return [x / p for x in xs]


def rc(i: int, a: int) -> float:
    """Raised-cosine rise over a samples."""
    return 0.5 - 0.5 * math.cos(math.pi * min(1.0, i / max(1, a)))


def fade_edges(xs: list[float], fin: float = 0.004, fout: float = 0.01) -> list[float]:
    a, b = max(1, n_of(fin)), max(1, n_of(fout))
    n = len(xs)
    for i in range(min(a, n)):
        xs[i] *= rc(i, a)
    for i in range(min(b, n)):
        xs[n - 1 - i] *= rc(i, b)
    return xs


def fit(xs: list[float], seconds: float) -> list[float]:
    """Trimmed or padded to exactly `seconds`."""
    n = n_of(seconds)
    return (xs + [0.0] * n)[:n]


# ---------------------------------------------------------------- small sources

def click(rnd: random.Random, length: float, attack: float, modes: list[tuple[float, float, float]],
          noise: float = 0.3, noise_lp: float = 5000, noise_tau: float = 0.006) -> list[float]:
    """A shaped mechanical transient: raised-cosine attack, decaying modal partials, noise."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(white(n, rnd), noise_lp)
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for f, amp, tau in modes:
            v += amp * math.sin(TAU * f * t) * math.exp(-t / tau)
        v += noise * nz[i] * math.exp(-t / noise_tau)
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


def swish(rnd: random.Random, length: float, lo: float, hi: float, shape) -> list[float]:
    n = n_of(length)
    nz = bandlimit(white(n, rnd), lo, hi)
    return [x * shape(i / max(1, n - 1)) for i, x in enumerate(nz)]


def stick_slip(rnd: random.Random, length: float, f_of, amp_of, jitter: float = 0.15) -> list[float]:
    """Friction: a train of tiny pulses whose rate is f_of(x), x in [0,1]: creaks and rasps."""
    n = n_of(length)
    out = [0.0] * n
    t = 0.0
    while t < length:
        x = t / length
        f = max(20.0, f_of(x))
        i = n_of(t)
        if i < n:
            out[i] += amp_of(x) * rnd.uniform(0.6, 1.0)
        t += (1 / f) * (1 + jitter * rnd.uniform(-1, 1))
    return out


def body(src: list[float], modes: list[tuple[float, float, float]]) -> list[float]:
    out = [0.0] * len(src)
    for fc, g, q in modes:
        for i, y in enumerate(biquad_bp(src, fc, q)):
            out[i] += g * y
    return out


def hum_tone(n: int, f: float, harmonics: list[float], start: int = 0) -> list[float]:
    return [sum(a * math.sin(TAU * f * (k + 1) * (i + start) / SR) for k, a in enumerate(harmonics))
            for i in range(n)]


def sine_shape(p: float = 1.0):
    return lambda x: math.sin(math.pi * x) ** p


# ---------------------------------------------------------------- the vault's paper

def paper_grains(rnd: random.Random, length: float, lo: float, hi: float, grain_s: float = 0.018,
                 crisp: float = 3.0) -> list[float]:
    """Dry paper crackle: band-limited noise under a smooth walk of `grain_s` knots, raised to
    `crisp` so it comes in small separate crinkles. Never rises faster than grain_s."""
    n = n_of(length)
    nz = bandlimit(white(n, rnd), lo, hi)
    walk = smooth_walk(n, rnd, grain_s)
    return [z * w ** crisp for z, w in zip(nz, walk)]


def rustle(rnd: random.Random, length: float, lo: float = 600, hi: float = 4200,
           grain_s: float = 0.018) -> list[float]:
    """A handful of sheets shifting: crackle plus the soft hush of paper moving on paper."""
    n = n_of(length)
    shape = [math.sin(math.pi * min(1.0, i / n)) ** 1.3 for i in range(n)]
    crk = peak1(paper_grains(rnd, length, lo, hi, grain_s))
    hush = peak1(bandlimit(white(n, rnd), lo * 0.8, hi * 0.6))
    return [s * (c + 0.35 * h) for s, c, h in zip(shape, crk, hush)]


def sheet_slide(rnd: random.Random, length: float, lo: float = 700, hi: float = 3600) -> list[float]:
    """A single sheet sliding off a stack: a smooth hiss that thins as it goes, a slump at the end."""
    n = n_of(length)
    nz = bandlimit(white(n, rnd), lo, hi)
    walk = smooth_walk(n, rnd, 0.03)
    out = []
    for i, (z, w) in enumerate(zip(nz, walk)):
        x = i / n
        env = math.sin(math.pi / 2 * min(1.0, x / 0.25)) ** 2 * (1 - x) ** 1.4
        out.append(z * env * (0.7 + 0.3 * w))
    slump = lowpass(lowpass(white(n_of(0.12), rnd), 500), 500)
    slump = [v * math.sin(math.pi * i / len(slump)) ** 2 for i, v in enumerate(slump)]
    return mix(out, scale(peak1(slump), 0.5 * max(abs(v) for v in out)), length * 0.78)


def far(rnd: random.Random, xs: list[float]) -> list[float]:
    """Further than the room: weak direct sound, a long pre-delay to the first of five taps,
    and a heavy lowpass at FAR_LP. The output is longer than the input by the echo train."""
    d = rnd.uniform(0.18, 0.26)
    dry = lowpass(lowpass(xs, FAR_LP * 1.6), FAR_LP * 1.6)
    wet = echo(xs, d, 0.62, 5)
    wet = [w - x for w, x in zip(wet, xs + [0.0] * (len(wet) - len(xs)))]   # taps only
    wet = lowpass(lowpass(lowpass(wet, FAR_LP), FAR_LP), FAR_LP * 0.8)
    out = [0.0] * len(wet)
    mix(out, dry, 0.0, 0.32)
    return mix(out, wet, 0.0, 1.0)


# ---------------------------------------------------------------- loops

def write_loop(name: str, xs: list[float]) -> list[float]:
    """Writes the loop and returns it as written (closed and normalized), for the bed check."""
    xs = seamless(xs, FADE)
    r = rms(xs)
    m = max(abs(x) for x in xs)
    peak = min(0.98, LOOP_RMS * m / max(1e-9, r))
    write(OUT, name, xs, peak)
    return normalize(xs, peak)


def write_shot(name: str, xs: list[float], fin: float = 0.004, fout: float = 0.01) -> None:
    write(OUT, name, fade_edges(xs, fin, fout), SHOT_PEAK)


def walk_times(rnd: random.Random, loop_s: float, count: int, gap_lo: float, gap_hi: float,
               first: float, tail: float) -> list[float]:
    """Seeded event times for a loop of loop_s seconds, wrapping: `count` gaps in [gap_lo, gap_hi]
    that sum to loop_s, the first event at `first` (after the crossfade window) and the last ring
    `tail` seconds clear of the loop end. Gap sizes follow a seeded smooth walk, never a grid."""
    walk = smooth_walk(4096, rnd, 64 / SR)
    for _ in range(4000):
        us = [walk[rnd.randrange(len(walk))] * 0.6 + 0.4 * rnd.random() for _ in range(count)]
        extra = loop_s - gap_lo * count
        gaps = [gap_lo + extra * u / sum(us) for u in us]
        times = [first]
        for g in gaps[:-1]:
            times.append(times[-1] + g)
        if all(gap_lo <= g <= gap_hi for g in gaps) and times[-1] + tail <= loop_s:
            return times
    raise RuntimeError("walk_times: no arrangement fits")


def wood_tick(rnd: random.Random) -> list[float]:
    """Oak shelving settling under its load: a dry soft-edged tick (LOOP_ATTACK), a small creak."""
    f = rnd.uniform(620, 980)
    c = click(rnd, 0.14, LOOP_ATTACK, [(f, 1.0, 0.016), (f * 1.83, 0.45, 0.009), (f * 0.47, 0.5, 0.03)],
              noise=0.45, noise_lp=2400, noise_tau=0.012)
    return lowpass(c, 2600)


def r10_room() -> list[float]:
    """Dry archive room tone: brown noise at 220 Hz under a dry air hush loud enough to survive a
    laptop speaker (AIR_MIX), a faint 50 Hz-ish air hum, very rare wood ticks. 12 s."""
    rnd = seed(1)
    dur = 12.0
    n = n_of(dur + FADE)
    bed = unit(highpass(lowpass(lowpass(brown(n, rnd), 220), 220), 22))
    air = unit(bandlimit(white(n, rnd), 350, 1600))     # dry still air, a hush you only notice when it stops
    walk = smooth_walk(n, rnd, 2.7)
    f = AIR_HUM * 1.004                                  # "-ish": the fan runs a little fast
    hum = unit(hum_tone(n, f, [0.55, 1.0, 0.5, 0.32, 0.16, 0.08]))
    sway = smooth_walk(n, rnd, 3.1)
    out = [b * (0.86 + 0.14 * k) + AIR_MIX * a + 0.07 * h * (0.85 + 0.15 * s)
           for b, a, k, h, s in zip(bed, air, walk, hum, sway)]
    for t in walk_times(rnd, dur, 2, 4.4, 7.6, FADE + rnd.uniform(0.6, 1.8), 0.5):
        tk = wood_tick(rnd)
        mix(out, tk, t, 0.8 * rnd.uniform(0.6, 1.0) / max(abs(x) for x in tk))
        if rnd.random() < 0.5:   # the next upright answers, quieter
            tk2 = lowpass(wood_tick(rnd), 1400)
            mix(out, tk2, t + rnd.uniform(0.11, 0.24), 0.3 / max(abs(x) for x in tk2))
    return out


def far_event(rnd: random.Random) -> list[float]:
    """One far paper event: a rustle or a single-sheet slide, put further than the room."""
    if rnd.random() < 0.55:
        src = rustle(rnd, rnd.uniform(0.35, 0.8))
    else:
        src = sheet_slide(rnd, rnd.uniform(0.5, 0.9))
    return far(rnd, peak1(src))


def r10_paper_far() -> list[float]:
    """Paper settling a long way off: sparse rustles and slides, long pre-delay, heavy lowpass. 14 s."""
    rnd = seed(2)
    dur = 14.0
    n = n_of(dur + FADE)
    room = unit(lowpass(lowpass(brown(n, rnd), 300), 300))
    distance = unit(bandlimit(white(n, rnd), 250, 900))   # the air of a space bigger than this one
    walk = smooth_walk(n, rnd, 2.2)
    out = [0.05 * r + 0.035 * d * (0.6 + 0.4 * w) for r, d, w in zip(room, distance, walk)]
    for t in walk_times(rnd, dur, 4, 2.4, 4.6, FADE + rnd.uniform(0.1, 0.6), 2.6):
        ev = far_event(rnd)
        mix(out, ev, t, rnd.uniform(0.55, 1.0) / max(abs(x) for x in ev))
    return out


def r10_paper_tick() -> list[float]:
    """Somewhere in the stacks a card drops onto a card: a sparse, seeded click train, one tick
    every 1.7-4.1 s (random.Random(1001)), each a burst of band(white, 1500, 5000) under a 30 ms
    decay, normalized. The loop is exactly the sum of its gaps, so the seam is one more gap.

    The one loop exempt from LOOP_ATTACK: a tick is a tick. Each rises over TICK_RISE (1 ms) so
    it never clicks digitally, and sits at -16 dB in the bed (R10_view STAGE_DB)."""
    rnd = random.Random(TICK_SEED)
    gaps = [rnd.uniform(TICK_GAP[0], TICK_GAP[1]) for _ in range(TICK_COUNT)]
    dur = sum(gaps)
    out = [0.0] * n_of(dur + FADE)
    t = FADE + 0.1                         # clear of the crossfade window; the last gap wraps to it
    a = max(1, n_of(TICK_RISE))
    for g in gaps:
        ln = n_of(TICK_DECAY * 6)
        src = band(white(ln, rnd), 1500, 5000)
        tk = [x * rc(i, a) * math.exp(-i / (TICK_DECAY * SR)) for i, x in enumerate(src)]
        mix(out, peak1(tk), t, rnd.uniform(0.55, 1.0))
        t += g
    return out


def r10_sea_wall() -> list[float]:
    """The sea through a thick wall: very low surf swells, about 6-8 s apart (seeded). 12 s."""
    rnd = seed(3)
    dur = 12.0
    n = n_of(dur + FADE)
    # two swells a loop, 5.4-6.6 s apart, each 6-7.5 s wide: periodic in `dur`, so the seam agrees
    c0 = rnd.uniform(1.5, 3.0)
    c1 = c0 + rnd.uniform(5.4, 6.6)
    swells = [(c0, rnd.uniform(6.0, 7.5), rnd.uniform(0.75, 1.0)),
              (c1, rnd.uniform(6.0, 7.5), rnd.uniform(0.6, 0.9))]
    env = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for c, w, g in swells:
            d = (t - c + dur / 2) % dur - dur / 2      # wrapped distance to the swell's crest
            # a quicker build and a longer drag back: the wave runs up, the shingle lets it go
            x = d / (w / 2)
            if -0.8 <= x < 0:
                v += g * math.cos(math.pi / 2 * x / 0.8) ** 2
            elif 0 <= x < 1:
                v += g * math.cos(math.pi / 2 * x) ** 1.4
        env.append(0.12 + 0.88 * min(1.0, v))
    rumble = unit(lowpass(lowpass(brown(n, rnd), 140), 140))
    wash = unit(lowpass(lowpass(highpass(white(n, rnd), 90), 380), 380))   # what survives the stone
    drag = unit(bandlimit(white(n, rnd), 200, 520))
    grit = smooth_walk(n, rnd, 0.05)
    return [e * (r + 0.55 * w + 0.25 * d * g * e) for e, r, w, d, g in zip(env, rumble, wash, drag, grit)]


def breath_env(rnd: random.Random, dur: float) -> list[float]:
    """The aperture's breath: periods 4.5-6 s with seeded jitter, summing to `dur`; each one a
    slower inhale (rising) and a longer exhale (sighing out), never quite to stillness."""
    periods = walk_times(rnd, dur, 3, 4.5, 6.0, 0.0, 0.0)
    starts = list(periods)
    lens = [b - a for a, b in zip(starts, starts[1:] + [dur])]
    offset = rnd.uniform(1.2, 2.4)
    shapes = [(rnd.uniform(0.36, 0.46), rnd.uniform(0.04, 0.1), rnd.uniform(0.75, 1.0)) for _ in lens]
    n = n_of(dur + FADE)
    env = []
    for i in range(n):
        t = (i / SR - offset) % dur
        k = 0
        while k + 1 < len(starts) and t >= starts[k + 1]:
            k += 1
        x = (t - starts[k]) / lens[k]
        inh, hold, g = shapes[k]
        if x < inh:
            v = math.sin(math.pi / 2 * x / inh) ** 2
        elif x < inh + hold:
            v = 1.0
        else:
            v = math.cos(math.pi / 2 * min(1.0, (x - inh - hold) / (0.96 - inh - hold))) ** 2
        env.append(0.08 + 0.92 * g * v)
    return env


def r10_aperture() -> list[float]:
    """The STAFF aperture's paper breath: close, dry rustle swelling in and sighing out, no pitch. 16 s."""
    rnd = seed(4)
    dur = APERTURE_LEN
    n = n_of(dur + FADE)
    env = breath_env(rnd, dur)
    # the same material as the far paper, but close: crackle from many tabs and a dry hush
    crk = unit(paper_grains(rnd, dur + FADE, 700, 5200, grain_s=0.02, crisp=1.8))
    hush = unit(bandlimit(white(n, rnd), 400, 3800))
    slide = unit(bandlimit(white(n, rnd), 900, 3000))
    drift = smooth_walk(n, rnd, 0.6)
    # the filter opens on the inhale and closes on the exhale: a throat with no voice in it
    src = [e * (0.75 * c + 0.55 * h * e + 0.25 * s * d) for e, c, h, s, d in zip(env, crk, hush, slide, drift)]
    fcs = [1400 + 3200 * e * (0.85 + 0.15 * d) for e, d in zip(env, drift)]
    out = moving_lp(src, fcs)
    return highpass(out, 300)


def relay_chatter(rnd: random.Random) -> list[float]:
    """A tiny relay chatter: three to five soft ticks, each rising over LOOP_ATTACK."""
    out = silence(0.36)
    t = 0.0
    for _ in range(rnd.randint(3, 5)):
        f = rnd.uniform(2100, 3300)
        mix(out, click(rnd, 0.08, LOOP_ATTACK, [(f, 1.0, 0.014), (f * 1.6, 0.4, 0.009)], noise=0.5,
                       noise_lp=4500, noise_tau=0.014), t, rnd.uniform(0.5, 1.0))
        t += rnd.uniform(0.028, 0.05)
    return out


def r10_model_hum() -> list[float]:
    """The Index model's open terminals: 100 Hz and soft harmonics, slow beating, relay chatter. 8 s."""
    rnd = seed(5)
    dur = 8.0
    n = n_of(dur + FADE)
    f0, f1 = MODEL_HUM, MODEL_HUM + 0.25          # 800 and 802 cycles a loop: two slow beats
    harm = [1.0, 0.55, 0.42, 0.22, 0.14, 0.07]
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for k, a in enumerate(harm):
            v += a * (math.sin(TAU * f0 * (k + 1) * t) + 0.6 * math.sin(TAU * f1 * (k + 1) * t + 0.7 * k))
        out.append(v)
    out = unit(out)
    fizz = unit(bandlimit(white(n, rnd), 2400, 5200))   # the terminals: an exposed, dry fizz
    walk = smooth_walk(n, rnd, 0.9)
    out = [h + 0.06 * z * (0.4 + 0.6 * w) for h, z, w in zip(out, fizz, walk)]
    for t in walk_times(rnd, dur, 2, 3.0, 5.0, FADE + rnd.uniform(0.2, 0.9), 0.5):
        ch = relay_chatter(rnd)
        mix(out, ch, t, 0.5 / max(abs(x) for x in ch))
    return out


# ---------------------------------------------------------------- one-shots: lightbox and panels

def paper_settle() -> list[float]:
    """First arrival: one far paper slump, the same distant treatment as r10_paper_far. 1.4 s."""
    rnd = seed(6)
    src = peak1(rustle(rnd, 0.32, 500, 3600))
    mix(src, scale(peak1(sheet_slide(rnd, 0.3)), 0.7), 0.05)
    out = far(rnd, src + [0.0] * n_of(0.1))
    out = fit(out, 1.4)
    return fade_edges(out, 0.004, 0.25)


def panel_pick() -> list[float]:
    """A stiff photographic panel lifted off felt: a short card scrape and a light tap. 0.3 s."""
    rnd = seed(7)
    out = silence(0.3)
    mix(out, swish(rnd, 0.15, 700, 3800, lambda x: math.sin(math.pi * x) ** 0.9 * (1 - 0.4 * x)), 0.0, 0.6)
    mix(out, swish(rnd, 0.08, 250, 900, sine_shape(2)), 0.11, 0.35)          # felt letting go
    return mix(out, click(rnd, 0.08, 0.0015, [(1650, 0.8, 0.008), (2700, 0.4, 0.005), (420, 0.5, 0.014)],
                          noise=0.5, noise_lp=4000), 0.19, 0.7)


def panel_place() -> list[float]:
    """A panel seated in a lightbox slot: a glass-backed card click. 0.25 s."""
    rnd = seed(8)
    out = silence(0.25)
    mix(out, swish(rnd, 0.05, 1200, 4500, lambda x: x ** 1.5), 0.0, 0.3)
    mix(out, click(rnd, 0.14, 0.0012, [(2380, 1.0, 0.012), (3960, 0.5, 0.009), (5650, 0.2, 0.004)],
                   noise=0.55), 0.045)                                           # card edge on glass
    return mix(out, thock(rnd, 0.08, 330, 0.014, 0.002, 1200), 0.046, 0.4)      # the box behind it


def edge_refuse() -> list[float]:
    """The clamp rail refusing a broken edge: a dull brass thunk that does not latch. Not sudden. 0.35 s."""
    rnd = seed(9)
    out = silence(0.35)
    mix(out, thock(rnd, 0.22, 150, 0.045, 0.012, 600), 0.0, 0.9)
    mix(out, click(rnd, 0.12, 0.012, [(880, 0.6, 0.02), (1490, 0.3, 0.012)], noise=0.3, noise_lp=1800), 0.002, 0.5)
    mix(out, thock(rnd, 0.1, 120, 0.03, 0.012, 500), 0.13, 0.3)          # it rides back off the rail
    return lowpass(out, 2600)


def snap(rnd: random.Random) -> list[float]:
    """One sprung brass chart clip shutting: every part rises over SUDDEN_ATTACK."""
    f = rnd.uniform(2700, 3100)
    out = click(rnd, 0.24, SUDDEN_ATTACK, [(f, 1.0, 0.05), (f * 1.41, 0.45, 0.03), (f * 2.07, 0.2, 0.014),
                                           (1240, 0.5, 0.02)], noise=0.7, noise_lp=6000, noise_tau=0.008)
    return mix(out, thock(rnd, 0.06, 420, 0.012, SUDDEN_ATTACK, 1500), 0.0, 0.35)


def clip_snap() -> list[float]:
    """The chart clips snapping shut along the edge: crisp sprung brass, a short ring. SUDDEN. 0.4 s."""
    rnd = seed(10)
    out = silence(0.4)
    mix(out, snap(rnd), 0.0, 1.0)
    mix(out, snap(rnd), rnd.uniform(0.045, 0.06), 0.6)
    return mix(out, snap(rnd), rnd.uniform(0.1, 0.12), 0.4)


def cover_slide() -> list[float]:
    """The registration cover drawn off across glass: a long smooth paper slide, a soft tab flick. 1.2 s."""
    rnd = seed(11)
    out = silence(1.2)
    n = n_of(1.05)
    nz = bandlimit(white(n, rnd), 650, 4200)
    glass = bandlimit(white(n, rnd), 3000, 6500)
    fr = smooth_walk(n, rnd, 0.06)
    sl = []
    for i in range(n):
        x = i / n
        env = math.sin(math.pi / 2 * min(1.0, x / 0.18)) ** 2 * (1 - max(0.0, (x - 0.7) / 0.3)) ** 1.5
        sl.append(env * (nz[i] * (0.8 + 0.2 * fr[i]) + 0.25 * glass[i]))
    mix(out, sl, 0.0, 1.0)
    mix(out, swish(rnd, 0.05, 1800, 5000, sine_shape()), 1.04, 0.35)          # the tab comes off the edge
    return mix(out, click(rnd, 0.06, 0.002, [(2300, 0.5, 0.006), (1300, 0.3, 0.01)], noise=0.6), 1.08, 0.3)


def blank_turn() -> list[float]:
    """The last blank turning: almost nothing. A slow faint emulsion creak, close. 2.4 s."""
    rnd = seed(12)
    dur = 2.4
    out = silence(dur)
    src = stick_slip(rnd, 2.1, lambda x: 18 + 55 * math.sin(math.pi * x) ** 2,
                     lambda x: math.sin(math.pi * x) ** 1.5, jitter=0.45)
    cr = bandlimit(src, 900, 3400)                          # no resonance: a dry flex, no pitch
    mix(out, cr, 0.15, 1.0 / max(1e-9, max(abs(x) for x in cr)))
    hush = swish(rnd, 2.0, 600, 2400, lambda x: math.sin(math.pi * x) ** 2.5)
    mix(out, hush, 0.2, 0.25)
    return lowpass(out, 3800)


def sheet_take() -> list[float]:
    """Lifting the assembled contact sheet: a stiff card lift and a short rustle. 0.5 s."""
    rnd = seed(13)
    out = silence(0.5)
    mix(out, thock(rnd, 0.08, 260, 0.018, 0.004, 900), 0.0, 0.35)              # unsticking from the felt
    mix(out, click(rnd, 0.05, 0.002, [(1900, 0.5, 0.006)], noise=0.6), 0.01, 0.4)
    return mix(out, peak1(rustle(rnd, 0.36, 800, 5000)), 0.08, 0.7)


# ---------------------------------------------------------------- one-shots: folders and the Index

def folder_file() -> list[float]:
    """A record slid into a folder pocket: card into manila. 0.4 s."""
    rnd = seed(14)
    out = silence(0.4)
    mix(out, swish(rnd, 0.3, 600, 3600, lambda x: math.sin(math.pi / 2 * min(1.0, x / 0.3)) ** 2 * (0.6 + 0.4 * x)),
        0.0, 0.6)
    return mix(out, thock(rnd, 0.1, 230, 0.02, 0.004, 900), 0.29, 0.45)          # it bottoms in the pocket


def folder_return() -> list[float]:
    """A record pulled back out of a pocket: the reverse slide. 0.35 s."""
    rnd = seed(15)
    out = silence(0.35)
    mix(out, thock(rnd, 0.06, 210, 0.015, 0.004, 800), 0.0, 0.3)
    mix(out, swish(rnd, 0.26, 700, 3800, lambda x: math.sin(math.pi * x) ** 0.8 * (1 - 0.5 * x)), 0.02, 0.6)
    return mix(out, click(rnd, 0.04, 0.0015, [(2500, 0.5, 0.004)], noise=0.6), 0.27, 0.35)   # free


def wheel_click() -> list[float]:
    """Date dial wheel detent: a small knurled brass click. 0.08 s."""
    rnd = seed(16)
    out = silence(0.08)
    mix(out, click(rnd, 0.012, 0.001, [(5200, 0.3, 0.002)], noise=0.5, noise_lp=7000), 0.0, 0.35)   # the knurl
    return mix(out, click(rnd, 0.07, 0.0012, [(3150, 1.0, 0.006), (5050, 0.45, 0.003), (1900, 0.4, 0.008)],
                          noise=0.5), 0.008)


def compare_key() -> list[float]:
    """The COMPARE key: heavy brass going down, a mechanism thunk under the bench. 0.4 s."""
    rnd = seed(17)
    out = silence(0.4)
    mix(out, click(rnd, 0.1, 0.0015, [(1480, 1.0, 0.014), (2620, 0.5, 0.008), (3900, 0.2, 0.004)], noise=0.6), 0.0, 0.7)
    mix(out, thock(rnd, 0.1, 210, 0.02), 0.002, 0.5)
    mix(out, thock(rnd, 0.25, 92, 0.06, 0.004, 500), 0.11, 0.9)                   # linkage below
    mix(out, click(rnd, 0.08, 0.002, [(760, 0.5, 0.02), (1300, 0.3, 0.01)], noise=0.4, noise_lp=2000), 0.112, 0.4)
    return lowpass(out, 5000)


def compare_refuse() -> list[float]:
    """A wrong compare: a dry mechanical clack and a short bell-less ratchet. Not sudden. 0.5 s."""
    rnd = seed(18)
    out = silence(0.5)
    mix(out, click(rnd, 0.1, 0.006, [(1180, 1.0, 0.012), (2050, 0.5, 0.008)], noise=0.5, noise_lp=3000), 0.0, 0.8)
    mix(out, thock(rnd, 0.1, 160, 0.02, 0.006, 700), 0.0, 0.4)
    t = 0.11
    for k in range(6):            # the carriage runs back: a ratchet, no bell
        mix(out, click(rnd, 0.03, 0.002, [(2300 - 90 * k, 0.6, 0.004), (1350, 0.3, 0.006)], noise=0.5,
                       noise_lp=3500), t, 0.6 * (1 - 0.1 * k))
        t += 0.032 + 0.006 * k + rnd.uniform(-0.003, 0.003)
    return lowpass(out, 3800)


def strip_print() -> list[float]:
    """A small strip printer typing one line: 11 quick type-bar strikes and a paper advance. 0.9 s."""
    rnd = seed(19)
    out = silence(0.9)
    t = 0.02
    for _ in range(11):
        f1 = rnd.uniform(1700, 2300)
        mix(out, click(rnd, 0.04, 0.0012, [(f1, 1.0, 0.006), (f1 * 1.7, 0.4, 0.004), (290, 0.6, 0.012)], noise=0.8),
            t, rnd.uniform(0.55, 1.0))
        t += rnd.uniform(0.048, 0.064)
    mix(out, swish(rnd, 0.16, 600, 2600, sine_shape()), t + 0.04, 0.25)          # the feed
    for j in range(3):
        mix(out, click(rnd, 0.015, 0.0008, [(4300, 0.6, 0.002), (2800, 0.4, 0.002)], noise=0.5), t + 0.05 + j * 0.045, 0.3)
    return out


def index_close() -> list[float]:
    """The model Index closing round Nora's records: a long papery breath of shuffling card grains,
    swelling and sighing out, ending in a soft felt thump. Quiet and close. 3.2 s."""
    rnd = seed(20)
    dur = 3.2
    n = n_of(dur)
    out = [0.0] * n

    def swell(x: float) -> float:            # in to 1.55 s, then a long sigh to 2.9 s
        if x < 1.55:
            return math.sin(math.pi / 2 * x / 1.55) ** 2
        return math.cos(math.pi / 2 * min(1.0, (x - 1.55) / 1.35)) ** 1.6

    t = 0.03
    while t < 2.85:          # card grains: each a short soft-edged flick of band-limited noise
        d = swell(t)
        if rnd.random() < 0.15 + 0.85 * d:
            ln = rnd.uniform(0.02, 0.07)
            lo = rnd.uniform(300, 900)
            g = swish(rnd, ln, lo, rnd.uniform(1800, 3000),
                      lambda x: math.sin(math.pi / 2 * min(1.0, x / 0.3)) ** 2 * (1 - x) ** 2)
            mix(out, g, t, rnd.uniform(0.4, 1.0) * (0.3 + 0.7 * d))
        t += rnd.uniform(0.006, 0.018) / (0.25 + 0.75 * d) * 0.4
    breath = bandlimit(white(n, rnd), 350, 2600)               # the hush of the cards moving together
    for i in range(n):
        out[i] = out[i] + 0.12 * breath[i] * swell(i / SR)
    out = bandlimit(out, 300, 3000)
    out = scale(peak1(out), 0.85)
    felt = thock(rnd, 0.3, 82, 0.05, 0.008, 400)                # the felt-lined case shutting
    mix(out, scale(lowpass(felt, 500), 0.55 / max(abs(x) for x in felt)), 2.86)
    return fade_edges(out, 0.02, 0.05)


def tabs_riffle() -> list[float]:
    """Every tab in the STAFF aperture moving at once: one fast flurry of 22 tiny card ticks. 0.6 s."""
    rnd = seed(21)
    out = silence(0.6)
    count = 22
    t = 0.02
    for k in range(count):
        x = k / (count - 1)
        f = rnd.uniform(2200, 4200)
        mix(out, click(rnd, 0.025, 0.0012, [(f, 0.6, 0.003), (f * 0.62, 0.3, 0.004)], noise=0.8, noise_lp=6500,
                       noise_tau=0.003), t, rnd.uniform(0.45, 1.0) * (0.55 + 0.45 * math.sin(math.pi * x)))
        t += 0.012 + 0.022 * (2 * x - 1) ** 2 + rnd.uniform(-0.003, 0.003)   # quick in the middle
    mix(out, swish(rnd, t, 1200, 4500, sine_shape(1.5)), 0.02, 0.18)            # the thumb across them
    return lowpass(out, 6000)


def release_lever() -> list[float]:
    """The TRAINING RELEASE lever: a brass ratchet, then a spring release clunk. 0.7 s."""
    rnd = seed(22)
    out = silence(0.7)
    t = 0.02
    for k in range(7):
        mix(out, click(rnd, 0.04, 0.0015, [(2600 + rnd.uniform(-120, 120), 0.7, 0.005), (1500, 0.4, 0.008)],
                       noise=0.6), t, 0.55 + 0.05 * k)
        t += 0.045 + 0.008 * k
    mix(out, swish(rnd, 0.42, 300, 1200, lambda x: 0.6 * math.sin(math.pi * x)), 0.02, 0.15)    # the pivot
    mix(out, thock(rnd, 0.24, 118, 0.05), 0.47)
    mix(out, click(rnd, 0.2, 0.002, [(1240, 0.8, 0.03), (2150, 0.4, 0.02)], noise=0.4), 0.471, 0.55)
    spring = swish(rnd, 0.12, 900, 2600, lambda x: (1 - x) ** 3)                  # the spring giving it up
    return mix(out, spring, 0.472, 0.3)


def records_return() -> list[float]:
    """The three records sliding back out of the folders: three soft card slides. 0.8 s."""
    rnd = seed(23)
    out = silence(0.8)
    for k, t in enumerate((0.0, 0.24 + rnd.uniform(-0.02, 0.02), 0.5 + rnd.uniform(-0.02, 0.02))):
        mix(out, swish(rnd, 0.22, 650, 3600, lambda x: math.sin(math.pi * x) ** 0.9 * (1 - 0.4 * x)), t,
            0.7 * (1 - 0.12 * k))
        mix(out, click(rnd, 0.03, 0.002, [(2300, 0.4, 0.004)], noise=0.5), t + 0.2, 0.25)
    return out


# ---------------------------------------------------------------- one-shots: drawers and the aperture

def oak_slide(rnd: random.Random, length: float, rate: float = 70.0) -> list[float]:
    """Oak on oak runners: low friction noise and a slow stick-slip judder."""
    n = n_of(length)
    rub = bandlimit(white(n, rnd), 160, 1500)
    grain = smooth_walk(n, rnd, 0.025)
    src = stick_slip(rnd, length, lambda x: rate * (0.8 + 0.4 * x), lambda x: 1.0, jitter=0.35)
    jud = body(src, [(240, 1.0, 2.5), (520, 0.5, 3.0)])
    jud = scale(jud, 1.0 / max(1e-9, max(abs(x) for x in jud)))
    rubs = scale(rub, 1.0 / max(1e-9, max(abs(x) for x in rub)))
    return [math.sin(math.pi * min(1.0, i / n)) ** 0.7 * (0.6 * r * (0.6 + 0.4 * g) + 0.5 * j)
            for i, (r, g, j) in enumerate(zip(rubs, grain, jud))]


def drawer_self() -> list[float]:
    """Venn's drawer opening by itself across the room: a slow oak slide, slightly far. 1.3 s."""
    rnd = seed(24)
    out = silence(1.3)
    mix(out, oak_slide(rnd, 1.0, 55), 0.02, 0.8)
    mix(out, thock(rnd, 0.2, 140, 0.04, 0.008, 500), 1.0, 0.6)                    # it stops
    out = echo(out, 0.06, 0.3, 4)                                                   # across the room
    return fit(lowpass(lowpass(out, 2000), 2000), 1.3)


def letters_take() -> list[float]:
    """Gathering a bundle of letters and a clipping: a soft paper bundle rustle. 0.7 s."""
    rnd = seed(25)
    out = silence(0.7)
    mix(out, peak1(rustle(rnd, 0.55, 600, 4800, 0.012)), 0.0, 0.8)
    mix(out, peak1(sheet_slide(rnd, 0.3, 900, 4500)), 0.32, 0.45)                 # the clipping, thinner
    return mix(out, thock(rnd, 0.08, 240, 0.018, 0.004, 900), 0.6, 0.25)        # squared on the desk


def staff_open() -> list[float]:
    """The STAFF drawer pulled: an oak slide that stops short and hollow, as if the box goes nowhere. 0.9 s."""
    rnd = seed(26)
    out = silence(0.9)
    mix(out, oak_slide(rnd, 0.42, 80), 0.0, 0.8)
    stop = thock(rnd, 0.4, 105, 0.05, 0.004, 450)
    mix(out, stop, 0.4, 0.9)
    # hollow: the stop rings down a cavity much deeper than the drawer. Broad modes, no tone.
    hollow = body(stop, [(170, 1.0, 3.0), (310, 0.6, 3.5)])
    hollow = lowpass(echo(hollow, 0.071, 0.45, 6), 900)
    mix(out, hollow, 0.405, 0.6 / max(1e-9, max(abs(x) for x in hollow)))
    return fit(out, 0.9)


def staff_slam() -> list[float]:
    """The copy closes the record and every STAFF drawer slams shut at once: one hard oak slam made
    of many fronts landing within 25 ms of each other, a dry clatter of card ends inside, and the
    hollow ring of the deep cavity, cut short. SUDDEN. 0.9 s."""
    rnd = seed(40)
    out = silence(0.9)
    for k in range(7):                     # seven fronts, not quite together
        t = rnd.uniform(0.0, 0.025)
        mix(out, thock(rnd, 0.3, rnd.uniform(88, 128), 0.05, SUDDEN_ATTACK, 650), t, rnd.uniform(0.5, 0.8))
        mix(out, click(rnd, 0.08, SUDDEN_ATTACK, [(rnd.uniform(1100, 1500), 0.5, 0.012)], noise=0.5,
                       noise_lp=3800), t + 0.002, 0.25)
    t = 0.03
    while t < 0.22:                        # the cards inside, thrown against the fronts
        g = swish(rnd, 0.03, 1500, 5200, lambda x: rc(n_of(0.03 * x), n_of(SUDDEN_ATTACK)) * (1 - x) ** 2)
        mix(out, g, t, rnd.uniform(0.1, 0.3))
        t += rnd.uniform(0.008, 0.03)
    ring = body(lowpass(out[: n_of(0.12)], 600), [(150, 1.0, 3.5), (290, 0.5, 4.0)])
    ring = lowpass(echo(ring, 0.083, 0.4, 4), 800)
    mix(out, ring, 0.01, 0.45 / max(1e-9, max(abs(x) for x in ring)))
    return fit(lowpass(out, 4200), 0.9)


def staff_settle() -> list[float]:
    """The aperture widening off-screen: one faint dry paper settle, close. 1.0 s."""
    rnd = seed(27)
    out = silence(1.0)
    mix(out, peak1(rustle(rnd, 0.45, 700, 5000, 0.02)), 0.05, 0.8)
    mix(out, peak1(sheet_slide(rnd, 0.45, 800, 3800)), 0.32, 0.5)
    return lowpass(out, 4500)


def rattle(rnd: random.Random) -> list[float]:
    """A brass bolt hitting its keeper: every part rises over SUDDEN_ATTACK."""
    out = thock(rnd, 0.12, 185, 0.025, SUDDEN_ATTACK, 900)
    return mix(out, click(rnd, 0.1, SUDDEN_ATTACK, [(1120, 0.9, 0.018), (1930, 0.5, 0.01), (3050, 0.2, 0.005)],
                          noise=0.5, noise_lp=3500), 0.0, 0.8)


def drawer_locked() -> list[float]:
    """Venn's locked drawer: a short brass lock rattle against its keeper. SUDDEN. 0.3 s."""
    rnd = seed(28)
    out = silence(0.3)
    t = 0.0
    for g in (1.0, 0.65, 0.4):
        mix(out, rattle(rnd), t, g)
        t += rnd.uniform(0.055, 0.075)
    return lowpass(out, 4000)


def card_flip() -> list[float]:
    """Thumbing the hanging index cards: four card flicks. 0.5 s."""
    rnd = seed(29)
    out = silence(0.5)
    t = 0.01
    for k in range(4):
        mix(out, swish(rnd, 0.05, 1800, 5800, lambda x: math.sin(math.pi * x) * (1 - 0.6 * x)), t, 0.5)
        mix(out, click(rnd, 0.03, 0.001, [(rnd.uniform(2400, 3200), 0.6, 0.004)], noise=0.6), t + 0.045,
            0.5 * (1 - 0.12 * k))
        t += rnd.uniform(0.09, 0.13)
    return out


def clock_tap() -> list[float]:
    """A knuckle on the stopped clock's glass: a dull glass tap, then deliberate silence. 0.6 s."""
    rnd = seed(30)
    out = silence(0.6)
    mix(out, thock(rnd, 0.06, 300, 0.012, 0.0015, 1200), 0.0, 0.7)               # the knuckle
    mix(out, click(rnd, 0.12, 0.0015, [(1870, 1.0, 0.018), (2960, 0.4, 0.01), (4400, 0.15, 0.005)],
                   noise=0.4, noise_lp=3500), 0.0, 0.6)
    # where the tick should answer: the case's faint movement, then nothing at all
    return mix(lowpass(out, 3500), click(rnd, 0.05, 0.004, [(620, 0.15, 0.01)], noise=0.1, noise_lp=1000), 0.09, 0.4)


def string_untie() -> list[float]:
    """A loose knot pulled free: a short string rasp. 0.4 s."""
    rnd = seed(31)
    out = silence(0.4)
    src = stick_slip(rnd, 0.26, lambda x: 260 + 380 * x, lambda x: math.sin(math.pi * x) ** 0.7, jitter=0.5)
    mix(out, bandlimit(src, 900, 4200), 0.02, 3.0)
    mix(out, swish(rnd, 0.24, 1500, 5000, sine_shape(1.2)), 0.02, 0.3)
    return mix(out, click(rnd, 0.03, 0.0015, [(2100, 0.4, 0.004)], noise=0.6), 0.29, 0.4)    # free


def paper_unwrap() -> list[float]:
    """Brown paper folded back off a photograph: a crisp unfold in three gestures. 1.0 s."""
    rnd = seed(32)
    out = silence(1.0)
    for t, ln, g in ((0.0, 0.32, 1.0), (0.3, 0.28, 0.75), (0.56, 0.38, 0.9)):
        mix(out, peak1(rustle(rnd, ln, 900, 6500, 0.008)), t + rnd.uniform(0, 0.02), g)
    return mix(out, swish(rnd, 0.2, 400, 1600, sine_shape(2)), 0.78, 0.25)      # laid flat


def lead_plug() -> list[float]:
    """A plug seated in a brass terminal: a firm metallic push-click. 0.2 s."""
    rnd = seed(33)
    out = silence(0.2)
    mix(out, swish(rnd, 0.06, 2000, 6000, lambda x: x), 0.0, 0.25)               # the sleeve going in
    mix(out, click(rnd, 0.12, 0.0012, [(2450, 1.0, 0.012), (3720, 0.5, 0.008), (5300, 0.2, 0.004)],
                   noise=0.6), 0.055)
    return mix(out, thock(rnd, 0.06, 380, 0.012, 0.002, 1400), 0.056, 0.4)


def lead_unplug() -> list[float]:
    """A plug pulled from a terminal: a short metallic pull. 0.18 s."""
    rnd = seed(34)
    out = silence(0.18)
    mix(out, click(rnd, 0.08, 0.0015, [(2200, 0.6, 0.008), (3500, 0.3, 0.005)], noise=0.5), 0.0, 0.7)
    return mix(out, swish(rnd, 0.1, 1800, 5500, lambda x: (1 - x) ** 2), 0.012, 0.35)


def test_key() -> list[float]:
    """TEST AMENDMENT key down: a brass key thunk with a relay pick-up. 0.4 s."""
    rnd = seed(35)
    out = silence(0.4)
    mix(out, click(rnd, 0.09, 0.0015, [(1560, 0.9, 0.012), (2750, 0.4, 0.007)], noise=0.6), 0.0, 0.7)
    mix(out, thock(rnd, 0.16, 140, 0.035), 0.002, 0.7)
    mix(out, click(rnd, 0.05, 0.0012, [(3900, 0.6, 0.004), (2700, 0.4, 0.005)], noise=0.5), 0.15, 0.45)  # relay
    hum = [math.sin(TAU * MODEL_HUM * 2 * i / SR) * math.exp(-i / (0.03 * SR)) for i in range(n_of(0.12))]
    return mix(out, fade_edges(hum, 0.004, 0.02), 0.152, 0.12)                       # the coil picks up


def stamp_closed() -> list[float]:
    """The model stamping CLOSED: a hard rubber-and-steel strike on paper. SUDDEN. 0.3 s."""
    rnd = seed(36)
    out = silence(0.3)
    mix(out, thock(rnd, 0.2, 96, 0.045, SUDDEN_ATTACK, 800), 0.0, 0.8)
    # the steel face and the paper land a beat after the rubber starts to give: still 10 ms rises
    mix(out, click(rnd, 0.12, SUDDEN_ATTACK, [(1620, 0.7, 0.014), (2740, 0.35, 0.008)], noise=0.4,
                   noise_lp=3500), 0.005, 0.8)
    slap = swish(rnd, 0.06, 800, 4000, lambda x: rc(n_of(0.06 * x), n_of(SUDDEN_ATTACK)) * (1 - x) ** 3)
    mix(out, slap, 0.005, 0.5)
    return lowpass(out, 4200)


def stamp_open() -> list[float]:
    """The model stamping OPEN: a softer strike. Not sudden. 0.3 s."""
    rnd = seed(37)
    out = silence(0.3)
    mix(out, thock(rnd, 0.18, 140, 0.03, 0.006, 700), 0.0, 0.8)
    mix(out, swish(rnd, 0.05, 700, 2800, lambda x: rc(n_of(0.05 * x), n_of(0.006)) * (1 - x) ** 3), 0.0, 0.3)
    return lowpass(out, 2400)


def reset_key() -> list[float]:
    """RESET: a small key and a quick clockwork rewind whirr. 0.5 s."""
    rnd = seed(38)
    out = silence(0.5)
    mix(out, click(rnd, 0.06, 0.0012, [(2900, 0.8, 0.006), (1700, 0.4, 0.008)], noise=0.6), 0.0, 0.7)
    src = stick_slip(rnd, 0.32, lambda x: 160 + 200 * x, lambda x: math.sin(math.pi * x) ** 0.6, jitter=0.08)
    wh = bandlimit(src, 1400, 5200)
    mix(out, wh, 0.07, 0.6 / max(1e-9, max(abs(x) for x in wh)))
    return mix(out, click(rnd, 0.05, 0.0012, [(2400, 0.5, 0.005)], noise=0.5), 0.4, 0.4)    # spent


def bridge_lift() -> list[float]:
    """The witness bridge coming free and lifted out: a soft brass release and slide. 0.5 s."""
    rnd = seed(39)
    out = silence(0.5)
    mix(out, click(rnd, 0.14, 0.003, [(1320, 0.8, 0.02), (2240, 0.4, 0.012)], noise=0.4, noise_lp=3000), 0.0, 0.6)
    mix(out, thock(rnd, 0.08, 260, 0.018, 0.003, 900), 0.001, 0.3)
    return mix(out, swish(rnd, 0.32, 1500, 5200, lambda x: math.sin(math.pi * x) ** 1.2 * (1 - 0.4 * x)), 0.1, 0.4)


# ---------------------------------------------------------------- build

LOOPS = [("r10_room", r10_room), ("r10_paper_far", r10_paper_far), ("r10_paper_tick", r10_paper_tick),
         ("r10_sea_wall", r10_sea_wall), ("r10_aperture", r10_aperture), ("r10_model_hum", r10_model_hum)]
SHOTS = [
    ("paper_settle", paper_settle), ("panel_pick", panel_pick), ("panel_place", panel_place),
    ("edge_refuse", edge_refuse), ("clip_snap", clip_snap), ("cover_slide", cover_slide),
    ("blank_turn", blank_turn), ("sheet_take", sheet_take), ("folder_file", folder_file),
    ("folder_return", folder_return), ("wheel_click", wheel_click), ("compare_key", compare_key),
    ("compare_refuse", compare_refuse), ("strip_print", strip_print), ("index_close", index_close),
    ("tabs_riffle", tabs_riffle), ("release_lever", release_lever), ("records_return", records_return),
    ("drawer_self", drawer_self), ("letters_take", letters_take), ("staff_open", staff_open),
    ("staff_settle", staff_settle), ("drawer_locked", drawer_locked), ("card_flip", card_flip),
    ("clock_tap", clock_tap), ("string_untie", string_untie), ("paper_unwrap", paper_unwrap),
    ("lead_plug", lead_plug), ("lead_unplug", lead_unplug), ("test_key", test_key),
    ("stamp_closed", stamp_closed), ("stamp_open", stamp_open), ("reset_key", reset_key),
    ("bridge_lift", bridge_lift), ("staff_slam", staff_slam),
]
SUDDEN = {"clip_snap", "stamp_closed", "drawer_locked", "staff_slam"}


def bed_mix(loops: dict[str, list[float]], b: int, seconds: float = 12.0) -> list[float]:
    """The band-`b` bed as the view plays it in view A: every STAGE_DB loop at its level, each
    looped to `seconds`."""
    n = n_of(seconds)
    out = [0.0] * n
    for name, levels in STAGE_DB.items():
        db = levels[b]
        if db is None:
            continue
        g = 10 ** (db / 20)
        xs = loops[name]
        for i in range(n):
            out[i] += g * xs[i % len(xs)]
    return out


def check_bed(loops: dict[str, list[float]]) -> None:
    for b in range(8):
        xs = bed_mix(loops, b)
        share = hi_share(xs, 150)
        level = 20 * math.log10(max(1e-9, rms(xs)))
        print(f"  bed band {b}: {level:6.1f} dBFS RMS  hi_share(150)={share:.1%}")
        assert share >= BED_HI_SHARE_MIN, f"R10 bed band {b}: hi_share(150) {share:.1%} < {BED_HI_SHARE_MIN:.0%}"


def main() -> None:
    print(f"Writing to {OUT}")
    loops = {}
    for name, fn in LOOPS:
        loops[name] = write_loop(name, fn())
    check_bed(loops)
    for name, fn in SHOTS:
        xs = fn()
        if name in SUDDEN:
            write_shot(name, xs, SUDDEN_ATTACK, 0.01)
        else:
            write_shot(name, xs)


if __name__ == "__main__":
    main()
