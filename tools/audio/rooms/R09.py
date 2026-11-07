#!/usr/bin/env python3
"""R09 sounds: the Lantern Gallery (aperture selector, iris housing, specimen clamp, bearing key,
STATION 3 eyepiece, the lantern glass, the boxwood rule).

Standard library only, via tools/audio/common.py. One fixed seed per sound,
random.Random(1931_09_NN), so a rerun writes byte-identical 22050 Hz mono WAVs to
assets/audio/R09/. Loops are rendered one second longer than their length and closed with
seamless(1.0), so the file's last sample runs straight into its first.

Levels: loops are mastered to about -18 dBFS RMS, one-shots peak at -3 dBFS; the view sets
the final level (SFX_DB, LoopMixer targets). The one exception is lid_pass, written at
LID_PASS_PEAK (-9 dBFS), so it sits 6 dB under deep_tone at equal view gain; the view also ducks
deep_tone 8 dB while it plays, so it is heard.

Transients: no loop has a rise faster than LOOP_ATTACK (16 ms), and every irregular loop event
(escapement tick, rain tick) is placed by a seeded walk and kept out of the crossfade window,
so the seam is never heard and the loop never ticks like a metronome. The sudden one-shots
(key_refuse, mount_tap, glass_tap) keep every attack at SUDDEN_ATTACK (10 ms), so the 12 dB
"Soften sudden sounds" cut is enough on its own. glass_tap_dead uses the same strike.

Dread (GDD 12): no stingers, no voices. The horror in this room is subtraction. r09_sea_far is
simply absent from band 4 on; r09_wind and r09_rain_glass stop at band 5 while the rain is
still seen on the glass; glass_tap_dead is a knuckle on something that is not glass (the
strike with its ring removed). deep_tone is the card's one very low tone, built on 55 Hz so a
laptop can carry it (110 / 165 / 220 Hz partials, nothing pitched above 400 Hz); lid_pass is a
hush that slides down past the gallery, quiet but heard. The view syncs the reveal to
deep_tone at 0.4 s and lid_pass at 7.0 s, so their lengths are fixed: DEEP_TONE_LEN and
LID_PASS_LEN.

    python3 tools/build_audio.py R09
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

OUT = room_out("R09")

LOOP_RMS = 10 ** (-18 / 20)        # about -18 dBFS RMS
SHOT_PEAK = 10 ** (-3 / 20)        # -3 dBFS peak
LID_PASS_PEAK = 10 ** (-9 / 20)    # 6 dB under deep_tone's -3 dBFS peak
LOOP_ATTACK = 0.016                # no loop transient rises faster than 16 ms
SUDDEN_ATTACK = 0.010              # every sudden transient rises over 10 ms
FADE = 1.0                         # seamless() crossfade, seconds

DEEP_TONE_LEN = 9.0                # 2.5 s swell, 4.0 s hold, 2.5 s decay
DEEP_SWELL, DEEP_HOLD, DEEP_DECAY = 2.5, 4.0, 2.5
LID_PASS_LEN = 6.0
STRIP_FEED_LEN = 1.4
CLOCK_MEAN_GAP = 1.4               # escapement ticks, mean spacing in seconds


def seed(nn: int) -> random.Random:
    return random.Random(int(f"193109{nn:02d}"))


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


def env_curve(n: int, shape) -> list[float]:
    return [shape(i / max(1, n - 1)) for i in range(n)]


def tones(n: int, partials: list[tuple[float, float, float]]) -> list[float]:
    """Sum of sines (freq, amp, phase) from sample 0."""
    return [sum(a * math.sin(TAU * f * i / SR + p) for f, a, p in partials) for i in range(n)]


# ---------------------------------------------------------------- small sources

def click(rnd: random.Random, length: float, attack: float, modes: list[tuple[float, float, float]],
          noise: float = 0.3, noise_lp: float = 5000, noise_tau: float = 0.006) -> list[float]:
    """A shaped mechanical transient: raised-cosine attack, then decaying modal partials and noise.
    The decays start when the attack ends, so onset-to-peak is the attack itself, never shorter."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(white(n, rnd), noise_lp)
    out = []
    for i in range(n):
        t = i / SR
        td = max(0.0, t - a / SR)
        v = 0.0
        for f, amp, tau in modes:
            v += amp * math.sin(TAU * f * t) * math.exp(-td / tau)
        v += noise * nz[i] * math.exp(-td / noise_tau)
        out.append(rc(i, a) * v)
    return out


def thock(rnd: random.Random, length: float, f: float, tau: float, attack: float = 0.003,
          body_lp: float = 700) -> list[float]:
    """A dull low impact: a falling sine thump with a lowpassed noise body; decay after the attack."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(white(n, rnd), body_lp)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ph += TAU * f * (1 + 0.4 * math.exp(-t / 0.01)) / SR
        out.append(rc(i, a) * math.exp(-max(0.0, t - a / SR) / tau) * (math.sin(ph) + 0.8 * nz[i]))
    return out


def swish(rnd: random.Random, length: float, lo: float, hi: float, shape) -> list[float]:
    n = n_of(length)
    nz = bandlimit(white(n, rnd), lo, hi)
    return [x * shape(i / max(1, n - 1)) for i, x in enumerate(nz)]


def stick_slip(rnd: random.Random, length: float, f_of, amp_of, jitter: float = 0.15) -> list[float]:
    """Friction: a train of tiny pulses whose rate is f_of(x), x in [0,1]: rasps and creaks."""
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


def resonate(src: list[float], modes: list[tuple[float, float, float]]) -> list[float]:
    out = [0.0] * len(src)
    for fc, g, q in modes:
        for i, y in enumerate(biquad_bp(src, fc, q)):
            out[i] += g * y
    return out


def tail_off(xs: list[float], start: float = 0.9) -> list[float]:
    """Linear fade over the last (1 - start) of the sound."""
    n = len(xs)
    return [x * (1 - max(0.0, (i / n - start) / (1 - start))) for i, x in enumerate(xs)]


# ---------------------------------------------------------------- loops

def write_loop(name: str, xs: list[float]) -> None:
    xs = seamless(xs, FADE)
    r = rms(xs)
    m = max(abs(x) for x in xs)
    peak = min(0.98, LOOP_RMS * m / max(1e-9, r))
    write(OUT, name, xs, peak)


def write_shot(name: str, xs: list[float], fin: float = 0.004, fout: float = 0.01,
               peak: float = SHOT_PEAK) -> None:
    write(OUT, name, fade_edges(xs, fin, fout), peak)


def walk_times(rnd: random.Random, loop_s: float, count: int, gap_lo: float, gap_hi: float,
               first: float, tail: float) -> list[float]:
    """Seeded event times for a loop of loop_s seconds, wrapping: `count` gaps in [gap_lo, gap_hi]
    that sum to loop_s (so the mean gap is loop_s / count), the first event at `first` (after the
    crossfade window) and the last one `tail` seconds clear of the loop end. Gap sizes follow a
    seeded smooth walk, never a grid."""
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


def escapement(rnd: random.Random, heavy: bool) -> list[float]:
    """One beat of the lantern clockwork: a brass pallet tick inside the drum, soft-edged."""
    f = rnd.uniform(1450, 1750) * (0.86 if heavy else 1.0)
    c = click(rnd, 0.14, LOOP_ATTACK, [(f, 1.0, 0.018), (f * 1.62, 0.45, 0.01), (f * 0.38, 0.5, 0.03)],
              noise=0.35, noise_lp=3500, noise_tau=0.008)
    return lowpass(echo(c, 0.011, 0.3, 4), 4200)   # inside the clock case


def r09_clockwork() -> list[float]:
    """Uneven lantern-rotation clockwork: escapement ticks placed by a seeded walk, gaps 0.85-2.1 s.
    A loop must hold a whole number of ticks, so 12 s carries round(12 / CLOCK_MEAN_GAP) = 9 at a
    1.33 s mean, the nearest count to 1.4 s. A slow drive whir and the drum's load underneath. 12 s."""
    rnd = seed(1)
    dur = 12.0
    n = n_of(dur + FADE)
    walk = smooth_walk(n, rnd, 1.7)
    whir = unit(bandlimit(white(n, rnd), 260, 900))          # the drive train turning
    gear = [math.sin(TAU * 3.0 * i / SR) for i in range(n)]    # 3 Hz tooth mesh, 36 per loop
    grind = [w * (0.75 + 0.25 * g) for w, g in zip(whir, gear)]
    drum = unit(lowpass(lowpass(brown(n, rnd), 240), 240))  # the lantern's weight on its race
    out = [0.17 * g * (0.7 + 0.3 * k) + 0.13 * d for g, k, d in zip(grind, walk, drum)]
    count = round(dur / CLOCK_MEAN_GAP)   # 9
    times = walk_times(rnd, dur, count, 0.85, 2.1, FADE + 0.06, 0.45)  # tick, release, echo all end by dur
    for k, t in enumerate(times):
        tk = escapement(rnd, heavy=(k % 3 == 1))
        mix(out, tk, t, rnd.uniform(0.55, 1.0) / max(abs(x) for x in tk))
        if rnd.random() < 0.5:   # the pallet's second, fainter release
            tk2 = escapement(rnd, heavy=False)
            mix(out, lowpass(tk2, 2200), t + rnd.uniform(0.07, 0.13), 0.3 / max(abs(x) for x in tk2))
    return out


def r09_wind() -> list[float]:
    """Gusting wind round the glazed lantern; a faint whistle through the fittings near 1.9 kHz,
    wandering slowly, only on the gusts. 16 s."""
    rnd = seed(2)
    dur = 16.0
    n = n_of(dur + FADE)
    gust = smooth_walk(n, rnd, 2.4)
    flutter = smooth_walk(n, rnd, 0.18)
    fcs = [380 + 520 * g + 140 * f for g, f in zip(gust, flutter)]
    body = unit(svf_bp(white(n, rnd), fcs, 1.6))              # air pushing round the panes
    low = unit(lowpass(lowpass(brown(n, rnd), 300), 300))    # the gallery rail's buffeting
    hiss = unit(bandlimit(white(n, rnd), 1200, 4500))        # air on glass edges
    wander = smooth_walk(n, rnd, 3.1)
    wcs = [1860 + 90 * w for w in wander]
    whistle = unit(svf_bp(white(n, rnd), wcs, 70.0))          # a narrow band, not a tone
    out = []
    for i in range(n):
        g = 0.3 + 0.7 * gust[i]
        wl = max(0.0, gust[i] - 0.45) / 0.55                  # only the stronger gusts sing
        out.append(g * (body[i] + 0.55 * low[i] + 0.12 * hiss[i] * g) + 0.16 * whistle[i] * wl * wl)
    return out


def r09_sea_far() -> list[float]:
    """Distant surf under the cliff, everything below 600 Hz: three slow breaks a loop. 14 s."""
    rnd = seed(3)
    dur = 14.0
    n = n_of(dur + FADE)
    wash = unit(lowpass(lowpass(highpass(white(n, rnd), 70), 560), 560))
    roar = unit(lowpass(lowpass(brown(n, rnd), 220), 220))
    drift = smooth_walk(n, rnd, 1.3)
    period = dur / 3   # 4.67 s per break, phase-continuous across the seam
    out = []
    for i in range(n):
        x = ((i / SR) % period) / period
        brk = math.sin(math.pi * min(1.0, x / 0.45)) ** 2 if x < 0.45 else math.exp(-(x - 0.45) / 0.25)
        e = 0.35 + 0.65 * brk * (0.8 + 0.2 * drift[i])
        out.append(e * (wash[i] * (0.4 + 0.6 * brk) + 0.8 * roar[i]))
    return lowpass(out, 600)


def rain_tick(rnd: random.Random) -> list[float]:
    """A single drop on the lantern glass: small, soft-edged (LOOP_ATTACK), a hint of ring."""
    f = rnd.uniform(2600, 3900)
    c = click(rnd, 0.09, LOOP_ATTACK, [(f, 0.8, 0.012), (f * 1.47, 0.4, 0.007), (f * 0.52, 0.35, 0.016)],
              noise=0.5, noise_lp=6000, noise_tau=0.01)
    return highpass(c, 900)


def r09_rain_glass() -> list[float]:
    """Sparse slow rain on the glazing: 14 ticks a loop, 0.5-1.4 s apart, a faint run-off. 12 s."""
    rnd = seed(4)
    dur = 12.0
    n = n_of(dur + FADE)
    run = unit(bandlimit(white(n, rnd), 900, 3200))   # water sheeting down the pane, barely
    walk = smooth_walk(n, rnd, 2.2)
    out = [0.11 * r * (0.6 + 0.4 * w) for r, w in zip(run, walk)]
    for t in walk_times(rnd, dur, 14, 0.42, 1.5, FADE + 0.08, 0.15):
        tk = rain_tick(rnd)
        mix(out, tk, t, rnd.uniform(0.3, 0.75) / max(abs(x) for x in tk))
    return out


def r09_surface() -> list[float]:
    """Near-subsonic bed: 55 Hz and 82.5 Hz, breathing at 0.08 Hz, a little upper body so small
    speakers can find it. 20 s (1100 and 1650 whole cycles)."""
    rnd = seed(5)
    dur = 20.0
    n = n_of(dur + FADE)
    swell = smooth_walk(n, rnd, 4.0)
    rumble = unit(lowpass(lowpass(brown(n, rnd), 110), 110))
    out = []
    for i in range(n):
        t = i / SR
        breath = 0.55 + 0.45 * math.sin(TAU * 0.08 * t - math.pi / 2)
        v = (math.sin(TAU * 55.0 * t) + 0.75 * math.sin(TAU * 82.5 * t + 0.7)
             + 0.28 * math.sin(TAU * 110.0 * t + 1.3) + 0.32 * math.sin(TAU * 165.0 * t + 0.2)
             + 0.18 * math.sin(TAU * 247.5 * t + 2.1) + 0.08 * math.sin(TAU * 330.0 * t + 0.6))
        out.append(breath * (v + 0.25 * rumble[i] * (0.6 + 0.4 * swell[i])))
    return out


def r09_pressure() -> list[float]:
    """Ear-fullness: lowpassed brown noise under 120 Hz and a 49 Hz hum (with 98 / 147 / 196 Hz for
    small speakers), swelling at 0.05 Hz. 18 s (882 whole cycles of 49 Hz)."""
    rnd = seed(6)
    dur = 18.0
    n = n_of(dur + FADE)
    bed = unit(highpass(lowpass(lowpass(lowpass(brown(n, rnd), 120), 120), 120), 20))
    drift = smooth_walk(n, rnd, 3.0)
    out = []
    for i in range(n):
        t = i / SR
        sw = 0.5 + 0.5 * math.sin(TAU * 0.05 * t - math.pi / 2)
        hum = (math.sin(TAU * 49.0 * t) + 0.45 * math.sin(TAU * 98.0 * t + 0.5)
               + 0.22 * math.sin(TAU * 147.0 * t + 1.9) + 0.12 * math.sin(TAU * 196.0 * t + 0.3))
        out.append((0.45 + 0.55 * sw) * (bed[i] * (0.8 + 0.2 * drift[i]) + 0.9 * hum))
    return out


def r09_room() -> list[float]:
    """Lantern room tone: the brass enclosure ringing faintly about 210 Hz, still air. 15 s."""
    rnd = seed(7)
    dur = 15.0
    n = n_of(dur + FADE)
    air = unit(bandlimit(white(n, rnd), 350, 2600))
    bed = unit(highpass(lowpass(lowpass(brown(n, rnd), 300), 300), 30))
    ring = unit(biquad_bp(white(n, rnd), 210.0, 30.0))      # the enclosure excited by the air
    walk = smooth_walk(n, rnd, 2.6)
    shimmer = smooth_walk(n, rnd, 1.1)
    out = []
    for i in range(n):
        t = i / SR
        tone = math.sin(TAU * 210.0 * t) + 0.3 * math.sin(TAU * 420.0 * t + 0.9)  # 3150 cycles a loop
        out.append(bed[i] * (0.85 + 0.15 * walk[i]) + 0.32 * air[i]
                   + 0.10 * ring[i] * (0.5 + 0.5 * shimmer[i]) + 0.035 * tone)
    return out


def r09_flap() -> list[float]:
    """A wool pennant flapping in real wind (sever only): a soft, heavy flutter whose rate follows
    the gusts, 4-9 flaps a second, each rising well over LOOP_ATTACK; its own wind behind it. 10 s."""
    rnd = seed(8)
    dur = 10.0
    n = n_of(dur + FADE)
    gust = smooth_walk(n, rnd, 1.6)
    jit = smooth_walk(n, rnd, 0.21)
    cloth = unit(bandlimit(white(n, rnd), 140, 1600))
    snap = unit(bandlimit(white(n, rnd), 900, 3200))
    wind = unit(svf_bp(white(n, rnd), [420 + 380 * g for g in gust], 1.4))
    out, ph = [], 0.0
    for i in range(n):
        g = gust[i]
        ph += TAU * (4.0 + 5.0 * g + 0.8 * (jit[i] - 0.5)) / SR
        m = (0.5 + 0.5 * math.sin(ph)) ** 3                  # a flap: soft rise, soft fall
        a = 0.3 + 0.7 * g
        out.append(a * m * (cloth[i] + 0.25 * snap[i] * g) + 0.5 * a * wind[i])
    return lowpass(out, 3000)   # wool, not nylon


# ---------------------------------------------------------------- one-shots: aperture and clamp

def sel_click() -> list[float]:
    """Aperture selector lever dropping into a detent: a dry brass clunk. 0.25 s."""
    rnd = seed(10)
    out = silence(0.25)
    mix(out, swish(rnd, 0.04, 600, 2400, lambda x: x * x), 0.0, 0.15)
    mix(out, thock(rnd, 0.12, 170, 0.022, 0.0015, 900), 0.035, 0.7)
    mix(out, click(rnd, 0.12, 0.0012, [(1380, 1.0, 0.016), (2260, 0.5, 0.009), (3640, 0.2, 0.004)], noise=0.5), 0.036)
    return mix(out, click(rnd, 0.05, 0.0012, [(1520, 0.4, 0.006)], noise=0.4, noise_lp=2500), 0.07, 0.35)


def iris_turn() -> list[float]:
    """Nine-blade iris opening while the old one closes: two overlapping dry brass rasps, nine
    blade edges catching, a settle. 0.5 s."""
    rnd = seed(11)
    out = silence(0.5)
    for k, (t0, ln, f0, g) in enumerate(((0.0, 0.38, 240, 1.0), (0.05, 0.34, 330, 0.7))):
        src = stick_slip(rnd, ln, lambda x, f0=f0: f0 + 120 * math.sin(math.pi * x),
                         lambda x: math.sin(math.pi * x) ** 0.7, jitter=0.25)
        body = resonate(src, [(2350 + 180 * k, 1.0, 12), (3900, 0.5, 14), (1250, 0.5, 8)])
        mix(out, tail_off(body, 0.8), t0, g)
    for j in range(9):   # the blade edges
        t = 0.03 + j * 0.036 + rnd.uniform(-0.005, 0.005)
        mix(out, click(rnd, 0.02, 0.0008, [(rnd.uniform(3000, 4200), 0.5, 0.003)], noise=0.5), t, 0.25)
    return mix(out, click(rnd, 0.1, 0.0012, [(1720, 0.7, 0.014), (2810, 0.35, 0.007)], noise=0.4), 0.41, 0.5)


def scope_creak() -> list[float]:
    """Brass scope arm swung into use: a low short creak in the pivot. 0.6 s."""
    rnd = seed(12)
    src = stick_slip(rnd, 0.56, lambda x: 70 + 55 * math.sin(math.pi * x) ** 0.8 + 20 * x,
                     lambda x: math.sin(math.pi * min(1.0, x / 0.9)) ** 0.6 * (0.6 + 0.4 * math.sin(TAU * 2.2 * x) ** 2),
                     jitter=0.1)
    body = resonate(src, [(420, 1.0, 6), (880, 0.7, 9), (1610, 0.35, 12), (2500, 0.15, 14)])
    out = silence(0.6)
    mix(out, tail_off(body, 0.85), 0.01)
    return lowpass(out, 4000)


def mount_clamp() -> list[float]:
    """Specimen frame seating in the clamp: a slide, then the lock. 0.5 s."""
    rnd = seed(13)
    out = silence(0.5)
    mix(out, swish(rnd, 0.16, 900, 3800, lambda x: math.sin(math.pi * x) ** 1.2), 0.0, 0.3)   # frame in the guides
    mix(out, click(rnd, 0.1, 0.0012, [(2100, 0.7, 0.01), (3300, 0.35, 0.006)], noise=0.5), 0.15, 0.6)   # stage one
    mix(out, thock(rnd, 0.1, 210, 0.02, 0.0015), 0.31, 0.45)
    mix(out, click(rnd, 0.16, 0.0012, [(1640, 1.0, 0.02), (2780, 0.55, 0.011), (4300, 0.2, 0.005)], noise=0.6), 0.311)  # lock
    return mix(out, click(rnd, 0.05, 0.0012, [(1700, 0.35, 0.006)], noise=0.4), 0.338, 0.5)


def clamp_release() -> list[float]:
    """Clamp jaws springing open and the frame lifting out. 0.4 s."""
    rnd = seed(14)
    out = silence(0.4)
    mix(out, click(rnd, 0.12, 0.0012, [(1840, 0.9, 0.015), (3010, 0.5, 0.008)], noise=0.5), 0.005)
    n = n_of(0.16)
    spring = [math.exp(-i / n_of(0.035)) * math.sin(TAU * 640 * i / SR + 0.5 * math.sin(TAU * 52 * i / SR))
              for i in range(n)]
    mix(out, bandlimit(spring, 300, 4000), 0.008, 0.35)
    return mix(out, swish(rnd, 0.2, 800, 3400, lambda x: math.sin(math.pi * x) * (1 - 0.5 * x)), 0.15, 0.3)  # lifted out


def mount_tap() -> list[float]:
    """Fingers on the empty clamp jaws: a small metallic tap. Sudden. 0.25 s."""
    rnd = seed(15)
    out = silence(0.25)
    mix(out, thock(rnd, 0.06, 280, 0.01, SUDDEN_ATTACK, 1400), 0.004, 0.35)
    mix(out, click(rnd, 0.22, SUDDEN_ATTACK, [(2640, 0.8, 0.03), (4110, 0.35, 0.016), (1530, 0.3, 0.02)],
                   noise=0.3, noise_lp=3500), 0.005)
    return mix(out, click(rnd, 0.1, SUDDEN_ATTACK, [(2710, 0.3, 0.02)], noise=0.2), 0.06, 0.3)   # the second finger


# ---------------------------------------------------------------- one-shots: bearing key and strip

def record_key() -> list[float]:
    """RECORD BEARING key pressed home: a heavy mechanical key and its latch catch. 0.4 s."""
    rnd = seed(16)
    out = silence(0.4)
    mix(out, swish(rnd, 0.05, 500, 2000, lambda x: x), 0.0, 0.15)
    mix(out, thock(rnd, 0.16, 150, 0.035, 0.002, 800), 0.045, 0.8)
    mix(out, click(rnd, 0.12, 0.0012, [(1260, 1.0, 0.018), (2130, 0.5, 0.01), (3380, 0.2, 0.005)], noise=0.6), 0.046)
    mix(out, click(rnd, 0.08, 0.001, [(2480, 0.8, 0.008), (3920, 0.4, 0.004)], noise=0.6), 0.22, 0.6)   # the latch catch
    return mix(out, thock(rnd, 0.06, 240, 0.012, 0.0015), 0.221, 0.25)


def key_refuse() -> list[float]:
    """The key stopping dead against its interlock: a short blunt thunk. Sudden. 0.3 s."""
    rnd = seed(17)
    out = silence(0.3)
    mix(out, thock(rnd, 0.2, 98, 0.045, SUDDEN_ATTACK, 550), 0.01)
    mix(out, click(rnd, 0.1, SUDDEN_ATTACK, [(720, 0.6, 0.02), (1290, 0.3, 0.011)], noise=0.4, noise_lp=1800), 0.011, 0.45)
    return lowpass(out, 2800)


def ratchet(rnd: random.Random) -> list[float]:
    return click(rnd, 0.03, 0.0008, [(rnd.uniform(3300, 3900), 0.6, 0.003), (1900, 0.4, 0.004)], noise=0.6)


def strip_feed() -> list[float]:
    """The paper bearing strip feeding out of the slot: a ratchet tick per step, the strip's hiss,
    a small tear at 1.24 s and nothing after. Exactly 1.4 s."""
    rnd = seed(18)
    out = silence(STRIP_FEED_LEN)
    mix(out, swish(rnd, 1.12, 900, 4200, lambda x: math.sin(math.pi * min(1.0, x / 0.12)) ** 2 * 0.8
                   if x < 0.92 else (1 - x) / 0.08 * 0.8), 0.04, 0.22)
    t = 0.05
    while t < 1.12:
        mix(out, ratchet(rnd), t, rnd.uniform(0.45, 0.65))
        t += rnd.uniform(0.072, 0.088)
    # the tear: a short crackle of fibres parting, falling in pitch
    tear = stick_slip(rnd, 0.11, lambda x: 900 - 500 * x, lambda x: math.sin(math.pi * x) ** 0.5, jitter=0.6)
    tear = bandlimit(tear, 1000, 6000)
    mix(out, tear, 1.24, 2.2)
    return mix(out, swish(rnd, 0.06, 1500, 5500, lambda x: math.sin(math.pi * x)), 1.25, 0.25)


def nosubject_print() -> list[float]:
    """NO SUBJECT ON BEARING: three quick type strikes and a short advance. 0.6 s."""
    rnd = seed(19)
    out = silence(0.6)
    t = 0.02
    for _ in range(3):
        f1 = rnd.uniform(1800, 2200)
        mix(out, click(rnd, 0.05, 0.0012, [(f1, 1.0, 0.007), (f1 * 1.7, 0.4, 0.004), (290, 0.6, 0.014)], noise=0.8),
            t, rnd.uniform(0.75, 1.0))
        t += rnd.uniform(0.085, 0.11)
    mix(out, swish(rnd, 0.16, 700, 2800, lambda x: math.sin(math.pi * x)), 0.36, 0.25)
    for j in range(2):
        mix(out, ratchet(rnd), 0.37 + j * 0.07, 0.3)
    return out


# ---------------------------------------------------------------- one-shots: lens, glass, rule

def lens_slide() -> list[float]:
    """Inspection lens laid against the eyepiece: soft glass on brass. 0.3 s."""
    rnd = seed(20)
    out = silence(0.3)
    mix(out, swish(rnd, 0.2, 1400, 5200, lambda x: math.sin(math.pi * x) ** 1.3 * (1 - 0.4 * x)), 0.0, 0.35)
    return mix(out, click(rnd, 0.12, 0.002, [(3180, 0.5, 0.025), (4870, 0.25, 0.012), (2050, 0.3, 0.02)],
                          noise=0.25, noise_lp=4000), 0.17, 0.6)


def knuckle(rnd: random.Random) -> list[float]:
    """The knuckle itself: the strike both glass taps share. Sudden attack, dull body."""
    return thock(rnd, 0.1, 230, 0.016, SUDDEN_ATTACK, 1500)


def glass_tap() -> list[float]:
    """Knuckle on the lantern glass with a short ring (bands 3-4 and sever). Sudden. 0.6 s."""
    rnd = seed(21)
    out = silence(0.6)
    mix(out, knuckle(rnd), 0.005)
    return mix(out, click(rnd, 0.55, SUDDEN_ATTACK, [(1180, 0.5, 0.09), (2640, 0.35, 0.05), (4090, 0.15, 0.025)],
                          noise=0.15, noise_lp=2500), 0.006, 0.6)


def glass_tap_dead() -> list[float]:
    """The same knuckle strike with no ring at all (band 5+): something that is not glass. Down
    40 dB inside 40 ms of its peak, lowpassed. 0.12 s."""
    rnd = seed(22)
    out = silence(0.12)
    k = thock(rnd, 0.09, 230, 0.0062, SUDDEN_ATTACK, 1500)
    mix(out, k, 0.005)
    return lowpass(lowpass(out, 1100), 1100)


def lens_touch() -> list[float]:
    """Hand on the cold signal lens: a very quiet glass hum that is cut short. 0.5 s."""
    rnd = seed(23)
    n = n_of(0.5)
    cut = n_of(0.3)
    hum = tones(n, [(742.0, 1.0, 0.0), (746.5, 0.7, 1.1), (1113.0, 0.25, 0.4)])
    a = n_of(0.06)
    env = [rc(i, a) * (1.0 if i < cut else max(0.0, 1 - (i - cut) / n_of(0.025))) for i in range(n)]
    out = [h * e * 0.5 for h, e in zip(hum, env)]
    skin = swish(rnd, 0.3, 500, 2500, lambda x: math.sin(math.pi * x) ** 2)   # the palm laid flat
    return mix(out, skin, 0.0, 0.18)


def glass_hum() -> list[float]:
    """First look through STATION 3: one pane faintly singing, a soft sine cluster about 620 Hz,
    a swell and fade over 3 s."""
    rnd = seed(24)
    n = n_of(3.0)
    cl = [(620.0, 1.0, 0.0), (617.4, 0.6, rnd.uniform(0, TAU)), (623.1, 0.55, rnd.uniform(0, TAU)),
          (1240.0, 0.08, rnd.uniform(0, TAU))]
    hum = tones(n, cl)
    env = env_curve(n, lambda x: math.sin(math.pi * x) ** 2)
    air = bandlimit(white(n, rnd), 500, 1500)
    return [h * e + 0.04 * a * e for h, e, a in zip(hum, env, air)]


def deep_tone() -> list[float]:
    """The reveal's one very low tone: 55 Hz with 110 / 165 / 220 Hz partials so small speakers carry
    it (and 275 / 330 Hz, faintly), a 0.3 Hz beat (55 against 55.3), 2.5 s swell, 4 s hold, 2.5 s decay. Nothing pitched above
    400 Hz. Exactly DEEP_TONE_LEN."""
    rnd = seed(25)
    n = n_of(DEEP_TONE_LEN)
    sw, hd = n_of(DEEP_SWELL), n_of(DEEP_SWELL + DEEP_HOLD)
    dc = n - hd
    under = unit(lowpass(lowpass(lowpass(brown(n, rnd), 160), 160), 160))   # a faint pressure under it
    out = []
    for i in range(n):
        t = i / SR
        if i < sw:
            e = rc(i, sw)
        elif i < hd:
            e = 1.0
        else:
            e = 1.0 - rc(i - hd, dc)
        beat = 0.82 + 0.18 * math.cos(TAU * 0.3 * t)          # the slow beat in the upper partials
        v = (math.sin(TAU * 55.0 * t) + 0.65 * math.sin(TAU * 55.3 * t + 0.4)
             + beat * (0.75 * math.sin(TAU * 110.0 * t + 0.3) + 0.8 * math.sin(TAU * 165.0 * t + 1.2)
                       + 0.4 * math.sin(TAU * 220.0 * t + 2.0) + 0.16 * math.sin(TAU * 275.0 * t + 0.8)
                       + 0.08 * math.sin(TAU * 330.0 * t + 2.6)))
        out.append(e * (v + 0.08 * under[i]))
    return out


def lid_pass() -> list[float]:
    """The lid line passing: band-limited hush whose centre slides from 900 Hz to 200 Hz over 6 s,
    quiet but heard; written at LID_PASS_PEAK (-9 dBFS). Exactly LID_PASS_LEN."""
    rnd = seed(26)
    n = n_of(LID_PASS_LEN)
    fcs = [900.0 * (200.0 / 900.0) ** (i / (n - 1)) for i in range(n)]
    hush = svf_bp(white(n, rnd), fcs, 2.2)
    hush = lowpass(hush, 1400)
    walk = smooth_walk(n, rnd, 0.6)
    env = env_curve(n, lambda x: math.sin(math.pi * min(1.0, x / 0.85)) ** 2 if x < 0.85 else 0.0)
    return [h * e * (0.85 + 0.15 * w) for h, e, w in zip(hush, env, walk)]


def loupe_step() -> list[float]:
    """Lens stepped closer over the ruler: a small glass-and-wood tick. 0.2 s."""
    rnd = seed(27)
    out = silence(0.2)
    mix(out, click(rnd, 0.08, 0.0012, [(960, 0.8, 0.008), (1780, 0.5, 0.005)], noise=0.6, noise_lp=3000), 0.005)  # wood
    return mix(out, click(rnd, 0.12, 0.0015, [(3420, 0.45, 0.02), (5150, 0.18, 0.01)], noise=0.1), 0.008, 0.5)  # glass


def ruler_lift() -> list[float]:
    """Boxwood rule picked up off the sill: a small wood tock and a light scrape. 0.4 s."""
    rnd = seed(28)
    out = silence(0.4)
    n = n_of(0.3)
    grit = smooth_walk(n, rnd, 0.006)
    nz = bandlimit(white(n, rnd), 700, 3600)
    scrape = [z * math.sin(math.pi * i / n) ** 1.2 * (0.35 + 0.65 * g * g) for i, (z, g) in enumerate(zip(nz, grit))]
    mix(out, click(rnd, 0.06, 0.0015, [(820, 0.7, 0.01), (1510, 0.4, 0.006)], noise=0.5, noise_lp=2500), 0.005, 0.7)
    mix(out, scrape, 0.03, 0.8)
    return mix(out, swish(rnd, 0.08, 400, 1600, lambda x: math.sin(math.pi * x)), 0.31, 0.2)   # off the sill


# ---------------------------------------------------------------- build

LOOPS = [("r09_room", r09_room), ("r09_clockwork", r09_clockwork), ("r09_wind", r09_wind),
         ("r09_sea_far", r09_sea_far), ("r09_rain_glass", r09_rain_glass), ("r09_surface", r09_surface),
         ("r09_pressure", r09_pressure), ("r09_flap", r09_flap)]
SHOTS = [
    ("sel_click", sel_click), ("iris_turn", iris_turn), ("scope_creak", scope_creak),
    ("mount_clamp", mount_clamp), ("clamp_release", clamp_release), ("mount_tap", mount_tap),
    ("record_key", record_key), ("key_refuse", key_refuse), ("strip_feed", strip_feed),
    ("nosubject_print", nosubject_print), ("lens_slide", lens_slide), ("glass_tap", glass_tap),
    ("glass_tap_dead", glass_tap_dead), ("lens_touch", lens_touch), ("glass_hum", glass_hum),
    ("deep_tone", deep_tone), ("lid_pass", lid_pass), ("loupe_step", loupe_step), ("ruler_lift", ruler_lift),
]
SUDDEN = {"key_refuse", "mount_tap", "glass_tap", "glass_tap_dead"}
PEAKS = {"lid_pass": LID_PASS_PEAK}


def main() -> None:
    print(f"Writing to {OUT}")
    for name, fn in LOOPS:
        write_loop(name, fn())
    for name, fn in SHOTS:
        xs = fn()
        fin = SUDDEN_ATTACK if name in SUDDEN else 0.004
        write_shot(name, xs, fin, 0.01, PEAKS.get(name, SHOT_PEAK))


if __name__ == "__main__":
    main()
