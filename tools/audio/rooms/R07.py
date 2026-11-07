#!/usr/bin/env python3
"""R07 sounds: the Wet Laboratory (sealed jars, brass test rack, balance, flotation tank, cards).

Standard library only, via tools/audio/common.py. One fixed seed per sound,
random.Random(1931_07_NN), so a rerun writes byte-identical 22050 Hz mono WAVs to
assets/audio/R07/. Loops are rendered one second longer than their length and closed with
seamless(1.0), so the file's last sample runs straight into its first.

Levels: loops are mastered to about -18 dBFS RMS, one-shots peak at -3 dBFS; the view sets
the final level (SFX_DB, LoopMixer targets).

Transients: no loop has a rise faster than LOOP_ATTACK (16 ms), and every irregular loop event
(drip, tick, swell) is placed by a seeded walk and kept out of the crossfade window, so the
seam is never heard and the loop never ticks like a metronome. The sudden one-shots
(socket_refuse, key_refuse, door_rattle, breath_hiss) keep every attack at SUDDEN_ATTACK
(10 ms, >= 6 ms even measured onset-to-peak), so the 12 dB "Soften sudden sounds" cut is enough on its own.

Dread (GDD 12): water_lean, felt_press, breath_hiss, r07_undertow and r07_glass_sing are quiet,
close and dry. No stingers. What is wrong is small: water that moves without a slosh, a felt
pad that sinks as if leaned on, a jar that breathes in a person's rhythm. breath_hiss is
filtered noise through moving formant-like bands; it has no pitch, no voice and no words. Its
windows (BREATH_WINDOWS) are the timing the view syncs the jar fog to.

    python3 tools/build_audio.py R07
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F401,F403  SR, TAU, lowpass, highpass, white, brown, ...
from common import (SR, TAU, band, brown, echo, highpass, lowpass, room_out, seamless,  # noqa: E402
                    smooth_walk, white, write)

OUT = room_out("R07")

LOOP_RMS = 10 ** (-18 / 20)   # about -18 dBFS RMS
SHOT_PEAK = 10 ** (-3 / 20)   # -3 dBFS peak
LOOP_ATTACK = 0.016           # no loop transient rises faster than 10 ms
SUDDEN_ATTACK = 0.010         # every sudden transient rises over 10 ms (>= 6 ms)
FADE = 1.0                    # seamless() crossfade, seconds

# breath_hiss: (start, end) of each breath, seconds. The view's fog follows these exactly.
BREATH_WINDOWS = ((0.00, 0.35), (0.55, 0.90), (1.80, 3.20))
BREATH_LEN = 3.4

MAINS = 60.0  # the station's mains, as in the office and R04


def seed(nn: int) -> random.Random:
    return random.Random(int(f"193107{nn:02d}"))


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


def svf_bp(xs: list[float], fcs: list[float], q: float) -> list[float]:
    """Chamberlin state-variable band-pass with a per-sample centre: stable while it moves."""
    low = bp = 0.0
    damp = 1 / q
    out = []
    for x, fc in zip(xs, fcs):
        f = 2 * math.sin(math.pi * min(fc, SR / 6) / SR)
        low += f * bp
        hp = x - low - damp * bp
        bp += f * hp
        out.append(bp * damp)
    return out


def bandlimit(xs: list[float], lo: float, hi: float) -> list[float]:
    """Two one-pole high-passes at lo, two low-passes at hi."""
    return lowpass(lowpass(highpass(highpass(xs, lo), lo), hi), hi)


def comb(xs: list[float], delay_s: float, fb: float) -> list[float]:
    d = max(1, int(round(delay_s * SR)))
    out = list(xs)
    for i in range(d, len(out)):
        out[i] += fb * out[i - d]
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


def hum_tone(n: int, f: float, harmonics: list[float], start: int = 0) -> list[float]:
    return [sum(a * math.sin(TAU * f * (k + 1) * (i + start) / SR) for k, a in enumerate(harmonics))
            for i in range(n)]


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


def bubble(rnd: random.Random, f: float, tau: float, attack: float, rise: float = 0.6) -> list[float]:
    """A small water resonance: a sine whose pitch rises as the cavity closes (Minnaert)."""
    n = n_of(tau * 5 + attack)
    a = max(1, n_of(attack))
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ph += TAU * f * (1 + rise * t / (tau * 5)) / SR
        env = rc(i, a) * (math.exp(-(t - attack) / tau) if t > attack else 1.0)
        out.append(env * math.sin(ph))
    return out


def stick_slip(rnd: random.Random, length: float, f_of, amp_of, jitter: float = 0.15) -> list[float]:
    """Friction: a train of tiny pulses whose rate is f_of(x), x in [0,1]: squeaks and creaks."""
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


def creak_body(src: list[float], modes: list[tuple[float, float, float]]) -> list[float]:
    out = [0.0] * len(src)
    for fc, g, q in modes:
        for i, y in enumerate(biquad_bp(src, fc, q)):
            out[i] += g * y
    return out


def water_grains(rnd: random.Random, length: float, density_of, f_lo: float, f_hi: float,
                 attack: float = 0.002, tau_lo: float = 0.004, tau_hi: float = 0.014) -> list[float]:
    """Many small bubbles at a density (per second) shaped by density_of(x): sloshing water."""
    n = n_of(length)
    out = [0.0] * n
    for i in range(n):
        x = i / n
        if rnd.random() < density_of(x) / SR:
            f = math.exp(rnd.uniform(math.log(f_lo), math.log(f_hi)))
            b = bubble(rnd, f, rnd.uniform(tau_lo, tau_hi), attack)
            g = rnd.expovariate(1.0) * 0.5
            for k, v in enumerate(b):
                if i + k < n:
                    out[i + k] += g * v
    return out


def env_curve(n: int, shape) -> list[float]:
    return [shape(i / max(1, n - 1)) for i in range(n)]


# ---------------------------------------------------------------- loops

def write_loop(name: str, xs: list[float]) -> None:
    xs = seamless(xs, FADE)
    r = rms(xs)
    m = max(abs(x) for x in xs)
    peak = min(0.98, LOOP_RMS * m / max(1e-9, r))
    write(OUT, name, xs, peak)


def write_shot(name: str, xs: list[float], fin: float = 0.004, fout: float = 0.01) -> None:
    write(OUT, name, fade_edges(xs, fin, fout), SHOT_PEAK)


def walk_times(rnd: random.Random, loop_s: float, count: int, gap_lo: float, gap_hi: float,
               first: float, tail: float) -> list[float]:
    """Seeded event times for a loop of loop_s seconds, wrapping: `count` gaps in [gap_lo, gap_hi]
    that sum to loop_s, the first event at `first` (after the crossfade window) and the last ring
    `tail` seconds clear of the loop end. Gap sizes follow a seeded smooth walk, never a grid."""
    walk = smooth_walk(4096, rnd, 64 / SR)
    for _ in range(2000):
        us = [walk[rnd.randrange(len(walk))] * 0.6 + 0.4 * rnd.random() for _ in range(count)]
        extra = loop_s - gap_lo * count
        gaps = [gap_lo + extra * u / sum(us) for u in us]
        times = [first]
        for g in gaps[:-1]:
            times.append(times[-1] + g)
        if all(gap_lo <= g <= gap_hi for g in gaps) and times[-1] + tail <= loop_s:
            return times
    raise RuntimeError("walk_times: no arrangement fits")


def pipe_tick(rnd: random.Random) -> list[float]:
    """A distant pipe tick: thermal, muffled through the wall, soft-edged (LOOP_ATTACK)."""
    f = rnd.uniform(380, 620)
    c = click(rnd, 0.16, LOOP_ATTACK, [(f, 1.0, 0.025), (f * 2.3, 0.35, 0.012), (f * 0.5, 0.4, 0.04)],
              noise=0.3, noise_lp=1500, noise_tau=0.01)
    return lowpass(lowpass(c, 1400), 1400)


def r07_room() -> list[float]:
    """Damp still air, faint mains buzz, distant pipe ticks. 10 s."""
    rnd = seed(1)
    dur = 10.0
    n = n_of(dur + FADE)
    bed = unit(highpass(lowpass(lowpass(brown(n, rnd), 380), 380), 25))
    air = unit(bandlimit(white(n, rnd), 300, 1400))       # damp air: a soft, close hush
    wet = unit(bandlimit(white(n, rnd), 2200, 5200))     # condensation fizz, barely
    walk = smooth_walk(n, rnd, 2.3)
    buzz = unit(hum_tone(n, MAINS, [0.5, 1.0, 0.55, 0.35, 0.22, 0.12, 0.07]))  # a ballast buzz
    out = [(b + 0.16 * a + 0.03 * w) * (0.84 + 0.16 * k) + 0.09 * z
           for b, a, w, k, z in zip(bed, air, wet, walk, buzz)]
    for t in walk_times(rnd, dur, 3, 2.1, 4.6, FADE + rnd.uniform(0.3, 1.2), 0.4):
        tk = pipe_tick(rnd)
        mix(out, tk, t, 0.9 * rnd.uniform(0.6, 1.0) / max(abs(x) for x in tk))
        if rnd.random() < 0.6:   # a pipe often ticks twice, the second further down the line
            mix(out, lowpass(pipe_tick(rnd), 900), t + rnd.uniform(0.09, 0.18), 0.35)
    return out


def r07_tank_hum() -> list[float]:
    """Pump hum about 55 Hz with 2nd/3rd harmonics, and a soft aerator bubble bed. 8 s."""
    rnd = seed(2)
    dur = 8.0
    n = n_of(dur + FADE)
    f0 = 55.0   # 55 * 8 = 440 whole cycles a loop
    out = []
    for i in range(n):
        t = i / SR
        rot = 1 + 0.08 * math.sin(TAU * 1.25 * t)    # a slow impeller lobe: 10 per loop
        v = (math.sin(TAU * f0 * t) + 0.7 * math.sin(TAU * 2 * f0 * t + 0.4)
             + 0.45 * math.sin(TAU * 3 * f0 * t + 1.1) + 0.16 * math.sin(TAU * 4 * f0 * t)
             + 0.08 * math.sin(TAU * 6 * f0 * t))   # the upper partials carry it on small speakers
        out.append(rot * v)
    out = unit(out)
    motor = unit(bandlimit(white(n, rnd), 150, 600))
    # the aerator: a dense bed of tiny bubbles, each rising over LOOP_ATTACK, so no clicks
    bub = water_grains(rnd, dur + FADE, lambda x: 38, 700, 2100, attack=LOOP_ATTACK, tau_lo=0.008, tau_hi=0.02)
    bub = unit(lowpass(bub, 2600))
    walk = smooth_walk(n, rnd, 0.9)
    return [h + 0.18 * m + 0.32 * b * (0.65 + 0.35 * w) for h, m, b, w in zip(out, motor, bub, walk)]


def plink(rnd: random.Random) -> list[float]:
    """A drop into the basin pool: a small rising water resonance, its entry splash, tile echo."""
    f = rnd.uniform(820, 1250)
    b = bubble(rnd, f, rnd.uniform(0.045, 0.065), LOOP_ATTACK, rise=0.5)
    sp = swish(rnd, 0.05, 1800, 5000, lambda x: math.sin(math.pi / 2 * min(1.0, x / 0.24)) ** 2 * (1 - x) ** 2)
    out = [0.0] * (len(b) + n_of(0.05))
    mix(out, b, 0.0, 1.0)
    mix(out, sp, 0.0, 0.25)
    out = echo(out, rnd.uniform(0.038, 0.047), 0.42, 8)  # white tile and enamel, close
    return lowpass(out, 4200)


def r07_drip() -> list[float]:
    """Slow irregular drips (one every 1.6-3.2 s, seeded) into the basin pool. 12 s."""
    rnd = seed(3)
    dur = 12.0
    n = n_of(dur + FADE)
    pool = unit(bandlimit(white(n, rnd), 200, 900))       # still water, a whisper
    walk = smooth_walk(n, rnd, 3.0)
    out = [0.09 * p * (0.7 + 0.3 * w) for p, w in zip(pool, walk)]
    times = walk_times(rnd, dur, 5, 1.6, 3.2, FADE + 0.1, 0.8)
    for t in times:
        pl = plink(rnd)
        g = rnd.uniform(0.7, 1.0) / max(abs(x) for x in pl)
        mix(out, pl, t, g)
        if rnd.random() < 0.45:   # the surface rings once more as the rebound falls back
            mix(out, scale(bubble(rnd, rnd.uniform(1400, 1900), 0.012, LOOP_ATTACK), 0.18), t + rnd.uniform(0.07, 0.11))
    return out


def r07_trickle() -> list[float]:
    """A thin steady stream from the basin tap into the pool. 8 s."""
    rnd = seed(4)
    dur = 8.0
    n = n_of(dur + FADE)
    stream = unit(bandlimit(white(n, rnd), 1300, 4200))
    flutter = smooth_walk(n, rnd, 0.022)        # the stream breaking up: 22 ms knots, no clicks
    slow = smooth_walk(n, rnd, 1.1)
    fcs = [1500 + 900 * a + 400 * b for a, b in zip(smooth_walk(n, rnd, 0.06), slow)]
    gurgle = unit(svf_bp(white(n, rnd), fcs, 9.0))   # the moving pool cavity under the stream
    bub = unit(lowpass(water_grains(rnd, dur + FADE, lambda x: 60, 600, 1800, attack=LOOP_ATTACK,
                                    tau_lo=0.008, tau_hi=0.018), 2400))
    body = unit(bandlimit(white(n, rnd), 180, 700))
    return [s * (0.55 + 0.45 * f) + 0.55 * g * (0.5 + 0.5 * f) + 0.4 * b + 0.25 * d * (0.8 + 0.2 * w)
            for s, f, g, b, d, w in zip(stream, flutter, gurgle, bub, body, slow)]


def r07_glass_sing() -> list[float]:
    """Very faint wet-rim tones from several jars, pure partials 700-1400 Hz, slow beating. 10 s."""
    rnd = seed(5)
    dur = 10.0
    n = n_of(dur + FADE)
    # each jar: a pair of near-unison partials beating at a rate that divides the loop
    jars = []
    for base in (742.0, 911.0, 1058.0, 1263.0, 1388.0):
        beat = rnd.choice((0.1, 0.2, 0.3))
        jars.append((base + rnd.uniform(-6, 6), beat, rnd.uniform(0.5, 1.0), rnd.uniform(0, TAU)))
    swells = [smooth_walk(n, rnd, rnd.uniform(1.6, 2.6)) for _ in jars]   # a finger never there
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for (f, beat, g, ph), sw in zip(jars, swells):
            e = g * (0.25 + 0.75 * sw[i] ** 2)
            v += e * (math.sin(TAU * f * t + ph) + 0.85 * math.sin(TAU * (f + beat) * t + ph))
        out.append(v)
    air = unit(bandlimit(white(n, rnd), 600, 1600))   # the damp air the rims stand in
    return [o + 0.12 * a for o, a in zip(unit(out), air)]


def r07_undertow() -> list[float]:
    """Sub-bass pressure swells, period 9 s, felt more than heard: something presses the wall. 9 s."""
    rnd = seed(6)
    dur = 9.0
    n = n_of(dur + FADE)
    press = unit(bandlimit(white(n, rnd), 60, 240))   # the wall taking load: a dull band
    out = []
    for i in range(n):
        t = i / SR
        x = (t % 9.0) / 9.0
        swell = math.sin(math.pi * x) ** 2.2    # one press a loop; 9 s is its period
        swell = 0.2 + 0.8 * swell
        v = (math.sin(TAU * 31 * t) + 0.7 * math.sin(TAU * (31 + 1 / 9) * t)   # 279 / 280 cycles
             + 0.5 * math.sin(TAU * 46.0 * t) * (0.4 + 0.6 * swell)
             + 0.16 * math.sin(TAU * 93 * t) + 0.1 * math.sin(TAU * 124 * t)    # small speakers
             + 0.06 * math.sin(TAU * 186 * t))
        out.append(swell * (v + 0.22 * press[i] * swell))
    return out


# ---------------------------------------------------------------- one-shots: jars and rack

def jar_slide() -> list[float]:
    """Glass jar lifted and slid across a brass cradle: soft clink, a small slosh. 0.5 s."""
    rnd = seed(7)
    out = silence(0.5)
    mix(out, click(rnd, 0.18, 0.002, [(2350, 1.0, 0.03), (3720, 0.5, 0.018), (1460, 0.35, 0.04)], noise=0.4), 0.01, 0.6)
    mix(out, swish(rnd, 0.24, 1600, 5200, lambda x: math.sin(math.pi * x) ** 1.4), 0.08, 0.22)  # glass on brass
    sl = water_grains(rnd, 0.32, lambda x: 900 * math.sin(math.pi * x) ** 2, 400, 1500)
    mix(out, lowpass(sl, 2600), 0.12, 0.7)
    return mix(out, click(rnd, 0.12, 0.002, [(2620, 0.7, 0.025), (1180, 0.5, 0.03)], noise=0.3), 0.33, 0.35)


def cradle_clamp() -> list[float]:
    """Brass clamp arms closing on the jar, a mild snap. 0.25 s."""
    rnd = seed(8)
    out = silence(0.25)
    mix(out, swish(rnd, 0.05, 900, 3000, lambda x: x), 0.0, 0.15)
    mix(out, click(rnd, 0.16, 0.0015, [(1870, 1.0, 0.02), (3120, 0.6, 0.012), (4800, 0.25, 0.006)], noise=0.6), 0.045)
    return mix(out, click(rnd, 0.12, 0.0015, [(1950, 0.6, 0.018), (3260, 0.4, 0.01)], noise=0.4), 0.058, 0.6)


def detent(rnd: random.Random) -> list[float]:
    return click(rnd, 0.06, 0.0012, [(2900, 0.8, 0.006), (4600, 0.4, 0.003), (1300, 0.5, 0.01)], noise=0.6)


def rack_tip() -> list[float]:
    """The cradle ratcheting a quarter-turn and back: 6 detent clicks over 1.2 s, a pause, a return
    clunk at 2.0 s. 2.4 s."""
    rnd = seed(9)
    out = silence(2.4)
    for k in range(6):
        t = 0.03 + k * 0.226 + rnd.uniform(-0.012, 0.012)   # last at about 1.16 s
        mix(out, detent(rnd), t, rnd.uniform(0.7, 0.9))
    mix(out, swish(rnd, 1.2, 300, 1100, lambda x: 0.6 * math.sin(math.pi * x)), 0.02, 0.18)  # pivot grind
    mix(out, swish(rnd, 0.2, 400, 1600, lambda x: x ** 2), 1.81, 0.3)    # the pawl released, it swings back
    mix(out, thock(rnd, 0.3, 120, 0.07), 2.0)
    return mix(out, click(rnd, 0.2, 0.002, [(1250, 0.8, 0.03), (2140, 0.5, 0.02), (3400, 0.2, 0.008)], noise=0.4), 2.002, 0.6)


def slosh_a() -> list[float]:
    """Ordinary water sloshing as jar A tips (gravity). 1.0 s."""
    rnd = seed(10)
    n = n_of(1.0)
    dens = lambda x: 1500 * (math.sin(math.pi * min(1.0, x / 0.45)) ** 2 + 0.55 * math.exp(-((x - 0.62) / 0.12) ** 2))
    gr = lowpass(water_grains(rnd, 1.0, dens, 300, 1600), 3000)
    fcs = [420 + 500 * math.sin(math.pi * min(1.0, i / n / 0.5)) for i in range(n)]
    body = svf_bp(white(n, rnd), fcs, 3.0)
    env = env_curve(n, lambda x: math.sin(math.pi * min(1.0, x / 0.5)) ** 1.5 + 0.5 * math.exp(-((x - 0.62) / 0.12) ** 2))
    out = [g + 0.5 * b * e for g, b, e in zip(peak1(gr), peak1(body), env)]
    return [x * (1 - max(0.0, (i / n - 0.85) / 0.15)) for i, x in enumerate(out)]


def glass_creak_b() -> list[float]:
    """Jar B tipping with NO slosh, only a dry glass creak: its water moves with the jar. 0.8 s."""
    rnd = seed(11)
    src = stick_slip(rnd, 0.8, lambda x: 90 + 150 * x + 60 * math.sin(TAU * 1.3 * x),
                     lambda x: math.sin(math.pi * min(1.0, x / 0.85)) ** 0.8 * (0.6 + 0.4 * math.sin(TAU * 3.1 * x) ** 2))
    body = creak_body(src, [(1180, 1.0, 14), (2440, 0.6, 16), (3810, 0.3, 18), (620, 0.4, 8)])
    return [x * (1 - max(0.0, (i / len(body) - 0.9) / 0.1)) for i, x in enumerate(body)]


def slosh_c() -> list[float]:
    """Jar C's water settling slowly and viscously, too smooth: one low swirl, no bubbles. 1.4 s."""
    rnd = seed(12)
    n = n_of(1.4)
    nz = white(n, rnd)
    fcs = [180 + 260 * math.sin(math.pi * (i / n)) ** 1.5 for i in range(n)]   # one swirl, round
    sw = svf_bp(nz, fcs, 6.0)
    sw = lowpass(lowpass(sw, 700), 700)
    env = env_curve(n, lambda x: math.sin(math.pi * min(1.0, x / 0.95)) ** 2 if x < 0.95 else 0.0)
    tone = [0.25 * math.sin(TAU * (95 + 25 * math.sin(math.pi * i / n)) * i / SR) for i in range(n)]
    return [(s / max(1e-9, max(abs(v) for v in sw)) + t) * e for s, t, e in zip(sw, tone, env)]


def test_pen() -> list[float]:
    """The test card's pen scratching a single line. 0.6 s."""
    rnd = seed(13)
    n = n_of(0.6)
    grit = smooth_walk(n, rnd, 0.004)
    nz = bandlimit(white(n, rnd), 1800, 6500)
    env = env_curve(n, lambda x: rc(int(x * 1000), 40) * (1 - max(0.0, (x - 0.8) / 0.2)) ** 1.5 if x < 0.92 else 0.0)
    out = [z * e * (0.4 + 0.6 * g * g) for z, e, g in zip(nz, env, grit)]
    return mix(out, click(rnd, 0.03, 0.001, [(3200, 0.4, 0.003)], noise=0.4), 0.005, 0.5)


def relay_hum(n: int, rnd: random.Random) -> list[float]:
    h = hum_tone(n, MAINS, [0.4, 1.0, 0.6, 0.3])
    hiss = bandlimit(white(n, rnd), 800, 3500)
    return [0.5 * a + 0.1 * b for a, b in zip(h, hiss)]


def socket_refuse() -> list[float]:
    """The socket's pawl refusing the jar: a dull brass clunk and a short spring buzz. Sudden. 0.5 s."""
    rnd = seed(14)
    out = silence(0.5)
    mix(out, thock(rnd, 0.22, 140, 0.05, SUDDEN_ATTACK), 0.01)
    mix(out, click(rnd, 0.16, SUDDEN_ATTACK, [(980, 0.7, 0.03), (1730, 0.4, 0.018), (2650, 0.2, 0.008)], noise=0.4), 0.011, 0.6)
    n = n_of(0.3)
    a = n_of(SUDDEN_ATTACK)
    spring = [rc(i, a) * math.exp(-i / n_of(0.08)) *
              math.sin(TAU * 310 * (i / SR) + 0.6 * math.sin(TAU * 37 * i / SR)) * (1 + 0.5 * math.sin(TAU * 74 * i / SR))
              for i in range(n)]
    return mix(out, bandlimit(spring, 150, 3000), 0.03, 0.35)


def socket_click() -> list[float]:
    """Mechanical confirmation: the jar seats, a clear brass click and a relay closing. 0.6 s."""
    rnd = seed(15)
    out = silence(0.6)
    mix(out, thock(rnd, 0.12, 190, 0.025), 0.01, 0.5)
    mix(out, click(rnd, 0.2, 0.001, [(2480, 1.0, 0.04), (3960, 0.5, 0.02), (5900, 0.2, 0.008)], noise=0.5), 0.012)
    mix(out, click(rnd, 0.05, 0.0012, [(1900, 0.8, 0.005), (3000, 0.4, 0.003)], noise=0.5), 0.2, 0.6)  # relay
    n = n_of(0.33)
    hm = relay_hum(n, rnd)
    hm = [x * rc(i, n_of(0.04)) * (1 - i / n) ** 1.2 for i, x in enumerate(hm)]
    return mix(out, hm, 0.21, 0.45)


def tag_drop() -> list[float]:
    """A printed card tag pushed out of the slot: printer tick, paper flutter, a soft settle. 0.9 s."""
    rnd = seed(16)
    out = silence(0.9)
    mix(out, click(rnd, 0.04, 0.001, [(2100, 0.9, 0.005), (3500, 0.4, 0.003), (300, 0.5, 0.01)], noise=0.8), 0.01)
    mix(out, swish(rnd, 0.16, 1200, 4500, lambda x: math.sin(math.pi * x)), 0.05, 0.4)   # pushed out
    n = n_of(0.34)
    fl = smooth_walk(n, rnd, 0.018)
    fz = bandlimit(white(n, rnd), 900, 4000)
    flutter = [z * f ** 3 * math.sin(math.pi * i / n) for i, (z, f) in enumerate(zip(fz, fl))]
    mix(out, flutter, 0.24, 0.9)
    mix(out, swish(rnd, 0.12, 300, 1800, lambda x: math.sin(math.pi * x) * (1 - x)), 0.6, 0.45)   # settles
    return mix(out, thock(rnd, 0.1, 210, 0.02, 0.004, 1200), 0.66, 0.15)


def water_lean() -> list[float]:
    """The lean: a slow, intimate wet creep up one side of a glass and back, like a held breath let
    go. Quiet. 2.2 s."""
    rnd = seed(17)
    dur = 2.2
    n = n_of(dur)
    # the meniscus climbing: a narrow wet band rising, then falling back further than it rose
    def lean(x: float) -> float:
        if x < 0.55:
            return math.sin(math.pi / 2 * x / 0.55) ** 2
        return math.cos(math.pi / 2 * min(1.0, (x - 0.55) / 0.4)) ** 1.5
    curve = [lean(i / n) for i in range(n)]
    fcs = [520 + 900 * c for c in curve]
    wet = svf_bp(white(n, rnd), fcs, 7.0)
    wp = max(abs(x) for x in wet)
    cling = water_grains(rnd, dur, lambda x: 160 * lean(x) ** 2, 1600, 3200, attack=0.006, tau_lo=0.003, tau_hi=0.006)
    cp = max(1e-9, max(abs(x) for x in cling))
    ring = [math.sin(TAU * (880 + 70 * c) * i / SR) for i, c in enumerate(curve)]   # the glass, faintly
    # the let-go: a long low exhale of the water settling flat, only after the climb ends
    exhale = lowpass(lowpass(white(n, rnd), 500), 500)
    ep = max(abs(x) for x in exhale)
    out = []
    for i in range(n):
        x = i / n
        c = curve[i]
        let_go = math.sin(math.pi * min(1.0, max(0.0, (x - 0.55) / 0.42))) ** 1.2
        out.append(0.8 * c * wet[i] / wp + 0.25 * cling[i] / cp + 0.05 * c * c * ring[i]
                   + 0.5 * let_go * exhale[i] / ep)
    return lowpass(out, 3800)   # close and dry: nothing bright


def door_rattle() -> list[float]:
    """A locked iron door rattled in its frame against the bolt. Sudden. 0.7 s."""
    rnd = seed(18)
    out = silence(0.7)
    t = 0.01
    for k in range(5):
        g = (1.0, 0.75, 0.85, 0.55, 0.4)[k]
        mix(out, thock(rnd, 0.16, rnd.uniform(95, 130), 0.04, SUDDEN_ATTACK, 900), t, g)
        mix(out, click(rnd, 0.14, SUDDEN_ATTACK, [(rnd.uniform(620, 700), 0.7, 0.035), (1420, 0.4, 0.02),
                                                   (2310, 0.25, 0.01)], noise=0.5, noise_lp=3000), t + 0.001, 0.55 * g)
        t += rnd.uniform(0.085, 0.13)
    # the bolt chattering in its keep between the knocks
    for _ in range(8):
        mix(out, click(rnd, 0.03, SUDDEN_ATTACK, [(3100, 0.4, 0.004), (1800, 0.3, 0.006)], noise=0.5),
            rnd.uniform(0.03, 0.55), 0.18)
    return lowpass(out, 4500)


def vault_settle() -> list[float]:
    """Distant heavy door settling a few centimetres on its hinge: low groan. 1.8 s."""
    rnd = seed(19)
    src = stick_slip(rnd, 1.55, lambda x: 38 + 30 * math.sin(math.pi * x) + 10 * math.sin(TAU * 2.3 * x),
                     lambda x: math.sin(math.pi * x) ** 1.2, jitter=0.25)
    body = creak_body(src, [(180, 1.0, 6), (310, 0.7, 8), (520, 0.35, 9), (95, 0.6, 4)])
    out = silence(1.8)
    mix(out, body, 0.02)
    mix(out, thock(rnd, 0.3, 58, 0.09, 0.006, 300), 1.55, 0.5 * max(abs(x) for x in body))  # it stops
    out = lowpass(lowpass(out, 900), 900)    # through the vault wall
    return echo(out, 0.11, 0.22, 4)[: n_of(1.8)]


def glass_tap() -> list[float]:
    """Knuckle on thick tank glass: dull tock and a short low ring. 0.6 s."""
    rnd = seed(20)
    out = silence(0.6)
    mix(out, thock(rnd, 0.1, 240, 0.018, 0.002, 1600), 0.005)
    return mix(out, click(rnd, 0.55, 0.002, [(412, 0.55, 0.11), (1040, 0.35, 0.05), (1730, 0.15, 0.025)],
                          noise=0.2, noise_lp=1500), 0.006, 0.7)


def tap_turn() -> list[float]:
    """An old brass tap squeaking a half turn. 0.4 s."""
    rnd = seed(21)
    src = stick_slip(rnd, 0.36, lambda x: 520 + 380 * math.sin(math.pi * x) ** 0.7,
                     lambda x: math.sin(math.pi * x) ** 0.6 * (0.6 + 0.4 * math.sin(TAU * 4 * x) ** 2), jitter=0.04)
    body = creak_body(src, [(1650, 1.0, 10), (2900, 0.5, 12), (900, 0.4, 6)])
    out = silence(0.4)
    mix(out, body, 0.01)
    return mix(out, click(rnd, 0.04, 0.002, [(1400, 0.4, 0.008)], noise=0.3), 0.36, 0.3 * max(abs(x) for x in body))


def pan_place() -> list[float]:
    """A sample set on or lifted off the brass pan: porcelain-on-brass tick and a faint chain jingle. 0.4 s."""
    rnd = seed(22)
    out = silence(0.4)
    mix(out, click(rnd, 0.12, 0.001, [(3350, 0.9, 0.012), (1920, 0.6, 0.03), (5100, 0.3, 0.006)], noise=0.5), 0.008)
    for _ in range(5):
        f = rnd.uniform(4200, 6800)
        mix(out, click(rnd, 0.06, 0.001, [(f, 0.5, 0.01), (f * 1.41, 0.2, 0.006)], noise=0.1),
            rnd.uniform(0.04, 0.26), 0.25)
    return out


def beam_swing() -> list[float]:
    """The balance beam swinging on its knife edge: a fine squeak and a damped tick. 0.9 s."""
    rnd = seed(23)
    src = stick_slip(rnd, 0.6, lambda x: 1100 + 500 * math.sin(TAU * 0.9 * x),
                     lambda x: math.sin(math.pi * x) ** 2 * (0.5 + 0.5 * math.cos(TAU * 1.8 * x) ** 2), jitter=0.03)
    body = creak_body(src, [(3400, 1.0, 18), (5200, 0.4, 20)])
    out = silence(0.9)
    mix(out, body, 0.02, 0.6 / max(1e-9, max(abs(x) for x in body)))
    mix(out, click(rnd, 0.1, 0.0015, [(2050, 0.6, 0.008), (900, 0.4, 0.012)], noise=0.4), 0.68, 0.7)  # the stop
    return mix(out, click(rnd, 0.06, 0.0015, [(2100, 0.25, 0.006)], noise=0.2), 0.76, 0.5)


def key_press() -> list[float]:
    """A brass instrument key pressed and released: firm clack. 0.25 s."""
    rnd = seed(24)
    out = silence(0.25)
    mix(out, thock(rnd, 0.06, 260, 0.012), 0.004, 0.5)
    mix(out, click(rnd, 0.08, 0.0012, [(1720, 1.0, 0.012), (2980, 0.6, 0.007), (4400, 0.25, 0.004)], noise=0.7), 0.005)
    return mix(out, click(rnd, 0.06, 0.0012, [(1880, 0.5, 0.008), (3200, 0.3, 0.005)], noise=0.5), 0.13, 0.55)


def key_refuse() -> list[float]:
    """A key stopped by a lock: short blocked thunk. Sudden. 0.3 s."""
    rnd = seed(25)
    out = silence(0.3)
    mix(out, thock(rnd, 0.18, 105, 0.04, SUDDEN_ATTACK, 600), 0.01)
    mix(out, click(rnd, 0.1, SUDDEN_ATTACK, [(760, 0.6, 0.02), (1340, 0.3, 0.012)], noise=0.4, noise_lp=2000), 0.011, 0.45)
    return lowpass(out, 3000)


def strip_print() -> list[float]:
    """A small strip printer chattering one cell: 5 quick type hits and a paper advance. 0.7 s."""
    rnd = seed(26)
    out = silence(0.7)
    t = 0.02
    for _ in range(5):
        f1 = rnd.uniform(1700, 2200)
        mix(out, click(rnd, 0.04, 0.0012, [(f1, 1.0, 0.006), (f1 * 1.7, 0.4, 0.004), (280, 0.6, 0.012)], noise=0.8),
            t, rnd.uniform(0.6, 1.0))
        t += rnd.uniform(0.055, 0.075)
    mix(out, swish(rnd, 0.18, 600, 2600, lambda x: math.sin(math.pi * x)), 0.42, 0.25)   # the feed
    for j in range(3):
        mix(out, click(rnd, 0.015, 0.0008, [(4300, 0.6, 0.002), (2800, 0.4, 0.002)], noise=0.5), 0.43 + j * 0.05, 0.3)
    return out


def card_flick() -> list[float]:
    """A stiff register card drawn from the drawer and slotted into a brass holder. 0.4 s."""
    rnd = seed(27)
    out = silence(0.4)
    mix(out, swish(rnd, 0.17, 1500, 5500, lambda x: math.sin(math.pi * x) ** 1.2 * (1 - 0.5 * x)), 0.0, 0.45)
    mix(out, click(rnd, 0.03, 0.001, [(2600, 0.5, 0.004)], noise=0.6), 0.17, 0.4)   # the card's end flicks free
    mix(out, swish(rnd, 0.1, 2000, 6000, lambda x: x ** 1.5), 0.22, 0.3)            # into the slot
    return mix(out, click(rnd, 0.1, 0.0012, [(3100, 0.7, 0.015), (1850, 0.4, 0.02)], noise=0.4), 0.32, 0.7)


def felt_press() -> list[float]:
    """The thumbprint: a very soft felt compression and a tiny tray creak, as if leaned on. 0.8 s."""
    rnd = seed(28)
    n = n_of(0.8)
    nz = lowpass(lowpass(white(n, rnd), 900), 900)
    press = [math.sin(math.pi * min(1.0, max(0.0, i / n - 0.03) / 0.55)) ** 1.8 for i in range(n)]
    fibre = smooth_walk(n, rnd, 0.008)
    felt = [z * p * (0.6 + 0.4 * f) for z, p, f in zip(nz, press, fibre)]
    out = scale(peak1(felt), 0.8)
    # the tray answers late, under a weight that is still increasing after the thumb is still
    src = stick_slip(rnd, 0.16, lambda x: 160 + 60 * x, lambda x: math.sin(math.pi * x), jitter=0.2)
    cr = creak_body(src, [(870, 1.0, 9), (1630, 0.4, 10)])
    mix(out, cr, 0.47, 0.35 / max(1e-9, max(abs(x) for x in cr)))
    return lowpass(out, 2500)


def section_slide() -> list[float]:
    """A card trace section slid into or out of a brass slot. 0.3 s."""
    rnd = seed(29)
    out = silence(0.3)
    mix(out, swish(rnd, 0.2, 1400, 5000, lambda x: math.sin(math.pi * x) ** 0.8 * (0.6 + 0.4 * x)), 0.01, 0.6)
    return mix(out, click(rnd, 0.07, 0.0012, [(2750, 0.7, 0.01), (1600, 0.4, 0.012)], noise=0.4), 0.21, 0.6)


def name_write() -> list[float]:
    """Pencil lettering a short name on a tab: 7 nib strokes. 1.2 s."""
    rnd = seed(30)
    out = silence(1.2)
    t = 0.03
    for k in range(7):
        length = rnd.uniform(0.07, 0.13)
        m = n_of(length)
        grit = smooth_walk(m, rnd, 0.003)
        nz = bandlimit(white(m, rnd), 1500, 5500)
        bend = rnd.uniform(0.3, 0.7)
        stroke = [z * (0.4 + 0.6 * g * g) * math.sin(math.pi * i / m) ** 0.7 *
                  (1 + 0.5 * math.exp(-((i / m - bend) / 0.15) ** 2)) for i, (z, g) in enumerate(zip(nz, grit))]
        mix(out, stroke, t, rnd.uniform(0.6, 1.0))
        t += length + rnd.uniform(0.03, 0.08) + (0.05 if k == 3 else 0.0)  # a lift between letters
    return mix(out, click(rnd, 0.03, 0.001, [(2900, 0.3, 0.004)], noise=0.5), t, 0.3)   # the pencil lifts


def strip_clip() -> list[float]:
    """A spring clip snapping onto paper. 0.25 s."""
    rnd = seed(31)
    out = silence(0.25)
    mix(out, click(rnd, 0.1, 0.0008, [(3600, 1.0, 0.012), (5400, 0.4, 0.006), (2100, 0.5, 0.008)], noise=0.8), 0.006)
    mix(out, swish(rnd, 0.04, 1500, 5000, lambda x: 1 - x), 0.008, 0.25)   # the paper caught
    n = n_of(0.12)
    ring = [0.12 * math.sin(TAU * 1240 * i / SR) * math.exp(-i / n_of(0.025)) for i in range(n)]
    return mix(out, ring, 0.008)


def frame_seal() -> list[float]:
    """Mechanical confirmation: the frame's glass cover closing with a soft click and a latch. 0.6 s."""
    rnd = seed(32)
    out = silence(0.6)
    mix(out, swish(rnd, 0.14, 500, 2200, lambda x: x ** 1.5), 0.0, 0.25)   # the cover's air
    mix(out, click(rnd, 0.2, 0.0015, [(2240, 0.8, 0.03), (3550, 0.4, 0.015), (1180, 0.4, 0.03)], noise=0.4), 0.14)
    mix(out, thock(rnd, 0.08, 230, 0.015), 0.141, 0.3)
    mix(out, click(rnd, 0.12, 0.001, [(1680, 0.9, 0.012), (2900, 0.6, 0.008), (4300, 0.25, 0.004)], noise=0.6), 0.36)  # latch
    return mix(out, click(rnd, 0.06, 0.001, [(1740, 0.4, 0.008)], noise=0.4), 0.385, 0.6)


def breath_hiss() -> list[float]:
    """Breath fogging the inside of the sealed jar in Nora's rhythm (BREATH_WINDOWS): close,
    filtered, no voice. Sudden list. 3.4 s."""
    rnd = seed(33)
    n = n_of(BREATH_LEN)
    a = n_of(SUDDEN_ATTACK)
    env = [0.0] * n
    for k, (t0, t1) in enumerate(BREATH_WINDOWS):
        i0, i1 = n_of(t0), n_of(t1)
        m = i1 - i0
        long = k == 2
        rise = n_of(0.09 if long else 0.05)
        fall = n_of(0.5 if long else 0.14)
        for j in range(m):
            e = rc(j, a) * (0.55 + 0.45 * rc(j, rise))     # soft 10 ms onset, then the breath fills
            if j > m - fall:
                e *= rc(m - j, fall)                        # tapering to nothing by t1
            if long:
                e *= 1.0 - 0.25 * (j / m)                   # the long one runs out of air
            env[i0 + j] = e * (0.75 if k == 1 else 1.0)
    # the formant-like bands: each breath shapes the mouth differently, and the long one slowly
    # closes, as if the jar were the throat. Moving resonances, no pitch underneath.
    f1 = [0.0] * n
    f2 = [0.0] * n
    drift = smooth_walk(n, rnd, 0.12)
    for i in range(n):
        t = i / SR
        if t < 1.0:
            p1, p2 = 650 + 120 * math.sin(TAU * t / 0.35), 1550
        else:
            x = min(1.0, max(0.0, (t - 1.8) / 1.4))
            p1, p2 = 720 - 260 * x, 1700 - 600 * x
        f1[i] = p1 * (0.93 + 0.14 * drift[i])
        f2[i] = p2 * (0.95 + 0.1 * drift[i])
    src = [e * w for e, w in zip(env, white(n, rnd))]
    out = [0.0] * n
    for fcs, g, q in ((f1, 1.0, 3.0), (f2, 0.6, 4.5)):
        for i, y in enumerate(svf_bp(src, fcs, q)):
            out[i] += g * y
    hiss = bandlimit(src, 2400, 6000)     # the breath's air on the glass
    out = [o + 0.35 * h for o, h in zip(out, hiss)]
    out = comb(out, 1 / 1830, 0.25)        # inside a jar: a faint glass cavity on every breath
    return lowpass(out, 5500)   # 3.20-3.40 s: only the jar's ring dying; no new breath


# ---------------------------------------------------------------- build

LOOPS = [("r07_room", r07_room), ("r07_tank_hum", r07_tank_hum), ("r07_drip", r07_drip),
         ("r07_trickle", r07_trickle), ("r07_glass_sing", r07_glass_sing), ("r07_undertow", r07_undertow)]
SHOTS = [
    ("jar_slide", jar_slide), ("cradle_clamp", cradle_clamp), ("rack_tip", rack_tip),
    ("slosh_a", slosh_a), ("glass_creak_b", glass_creak_b), ("slosh_c", slosh_c),
    ("test_pen", test_pen), ("socket_refuse", socket_refuse), ("socket_click", socket_click),
    ("tag_drop", tag_drop), ("water_lean", water_lean), ("door_rattle", door_rattle),
    ("vault_settle", vault_settle), ("glass_tap", glass_tap), ("tap_turn", tap_turn),
    ("pan_place", pan_place), ("beam_swing", beam_swing), ("key_press", key_press),
    ("key_refuse", key_refuse), ("strip_print", strip_print), ("card_flick", card_flick),
    ("felt_press", felt_press), ("section_slide", section_slide), ("name_write", name_write),
    ("strip_clip", strip_clip), ("frame_seal", frame_seal), ("breath_hiss", breath_hiss),
]
SUDDEN = {"socket_refuse", "key_refuse", "door_rattle", "breath_hiss"}


def main() -> None:
    print(f"Writing to {OUT}")
    for name, fn in LOOPS:
        write_loop(name, fn())
    for name, fn in SHOTS:
        xs = fn()
        if name in SUDDEN:
            write_shot(name, xs, SUDDEN_ATTACK, 0.01)
        else:
            write_shot(name, xs)


if __name__ == "__main__":
    main()
