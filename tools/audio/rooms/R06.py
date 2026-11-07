#!/usr/bin/env python3
"""R06 sounds: the Bunk Room, a small wooden dormitory under a tin-and-felt roof.

Standard library only, via tools/audio/common.py. One fixed seed per sound,
random.Random(1931_06_NN), so a rerun writes byte-identical 22050 Hz mono WAVs to
assets/audio/R06/. Loops are rendered one second long and closed with seamless(1.0), so the
file's last sample runs straight into its first. Anything periodic inside a loop (breaths,
the pressure sweep) is built on the loop length itself, so the crossfade only ever blends
noise against noise.

Character: wool blankets and mattress ticking soak up the highs, so everything is close, soft
and dry: a gentle top-end roll-off and very short room reflections (9-14 ms, low feedback).
The signature voice is the bed spring: a coiled-steel twang, a damped and slightly detuned
inharmonic cluster (about 380, 610, 1130, 1720 Hz) over a soft wooden frame creak. Creaks
vary by seed, never by clock.

Levels: loops are mastered to about -18 dBFS RMS, one-shots peak at -3 dBFS; the view sets
the final level. The sudden one-shots (spring_creak, compartment_drop, latch_small) keep every
transient's attack at 6 ms or longer, so the "Soften sudden sounds" cut is enough on its own.

No voices and no words anywhere. r06_beds_breath is unvoiced, lowpassed noise only.

    python3 tools/build_audio.py R06
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F401,F403  SR, TAU, lowpass, highpass, white, brown, ...
from common import SR, TAU, brown, highpass, lowpass, seamless, smooth_walk, white, write  # noqa: E402

OUT = room_out("R06")  # noqa: F405

LOOP_RMS = 10 ** (-18 / 20)   # about -18 dBFS RMS
SHOT_PEAK = 10 ** (-3 / 20)   # -3 dBFS peak
SUDDEN_ATTACK = 0.006         # every sudden transient rises over at least 6 ms
WOOL_LP = 4200                # what the blankets leave of the top end

SPRING_MODES = [  # (Hz, amplitude, decay tau s): coiled steel, high partials die first
    (380.0, 1.0, 0.42),
    (610.0, 0.72, 0.30),
    (1130.0, 0.40, 0.16),
    (1720.0, 0.24, 0.09),
]


def seed(nn: int) -> random.Random:
    return random.Random(int(f"193106{nn:02d}"))


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


def sweep_bp(xs: list[float], fcs: list[float], q: float, block: int = 32) -> list[float]:
    """Band-pass whose centre follows fcs (per sample), coefficients refreshed every block."""
    x1 = x2 = y1 = y2 = 0.0
    out = []
    b0 = b2 = a1 = a2 = 0.0
    for i, x in enumerate(xs):
        if i % block == 0:
            w = TAU * fcs[i] / SR
            alpha = math.sin(w) / (2 * q)
            a0 = 1 + alpha
            b0, b2 = alpha / a0, -alpha / a0
            a1, a2 = -2 * math.cos(w) / a0, (1 - alpha) / a0
        y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def bandlimit(xs: list[float], lo: float, hi: float) -> list[float]:
    """Two one-pole high-passes at lo, two low-passes at hi."""
    return lowpass(lowpass(highpass(highpass(xs, lo), lo), hi), hi)


def wool(xs: list[float], fc: float = WOOL_LP) -> list[float]:
    return lowpass(lowpass(xs, fc), fc)


def room(xs: list[float], rnd: random.Random, fb: float = 0.18, keep_len: bool = False) -> list[float]:
    """The dormitory's reflections: one short seeded echo (9-14 ms) at low feedback."""
    d = n_of(rnd.uniform(0.009, 0.014))
    out = list(xs) + ([] if keep_len else [0.0] * d * 4)
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


def rms(xs: list[float]) -> float:
    return math.sqrt(sum(x * x for x in xs) / max(1, len(xs)))


def unit(xs: list[float]) -> list[float]:
    r = rms(xs)
    return [x / max(1e-12, r) for x in xs]


def peak_unit(xs: list[float]) -> list[float]:
    m = max(1e-12, max(abs(x) for x in xs))
    return [x / m for x in xs]


def rise(i: int, a: int) -> float:
    return (0.5 - 0.5 * math.cos(math.pi * i / a)) if i < a else 1.0


def fade_edges(xs: list[float], fin: float = 0.004, fout: float = 0.01) -> list[float]:
    a, b = max(1, n_of(fin)), max(1, n_of(fout))
    n = len(xs)
    for i in range(min(a, n)):
        xs[i] *= 0.5 - 0.5 * math.cos(math.pi * i / a)
    for i in range(min(b, n)):
        xs[n - 1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / b)
    return xs


def fit(xs: list[float], seconds: float) -> list[float]:
    """Pads or trims to exactly `seconds` (the fade-out in write_shot closes a trimmed tail)."""
    n = n_of(seconds)
    return (xs + [0.0] * n)[:n]


# ---------------------------------------------------------------- small sources

def modal(rnd: random.Random, length: float, attack: float, modes, noise: float = 0.3,
          noise_lp: float = 4000, noise_tau: float = 0.006) -> list[float]:
    """A shaped transient: raised-cosine attack over decaying modal partials and a noise burst."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(white(n, rnd), noise_lp)
    phs = [rnd.uniform(0, TAU) for _ in modes]
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for (f, amp, tau), p in zip(modes, phs):
            v += amp * math.sin(TAU * f * t + p) * math.exp(-t / tau)
        v += noise * nz[i] * math.exp(-t / noise_tau)
        out.append(rise(i, a) * v)
    return out


def knock(rnd: random.Random, length: float, f: float, tau: float, attack: float = 0.003,
          body_lp: float = 900) -> list[float]:
    """A dull wooden impact: a slightly falling sine thump with a lowpassed noise body."""
    n = n_of(length)
    a = max(1, n_of(attack))
    nz = lowpass(lowpass(white(n, rnd), body_lp), body_lp)
    rn = max(1e-9, rms(nz[: max(1, n_of(0.02))]))
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ph += TAU * f * (1 + 0.3 * math.exp(-t / 0.012)) / SR
        out.append(rise(i, a) * math.exp(-t / tau) * (math.sin(ph) + 0.5 * nz[i] / rn * math.exp(-t / (tau * 0.5))))
    return out


def rustle(rnd: random.Random, length: float, lo: float, hi: float, grain_s: float = 0.03,
           shape=None) -> list[float]:
    """Cloth or felt: band-limited noise with a seeded grainy envelope under an overall shape."""
    n = n_of(length)
    nz = bandlimit(white(n, rnd), lo, hi)
    g = smooth_walk(n, rnd, grain_s)
    out = []
    for i in range(n):
        x = i / max(1, n - 1)
        s = shape(x) if shape else math.sin(math.pi * x)
        out.append(nz[i] * s * (0.35 + 0.65 * g[i] * g[i]))
    return out


def stick_slip(rnd: random.Random, length: float, f_lo: float, f_hi: float, bands,
               env_fn, glide: float = 0.0, step_s: float = 0.2) -> list[float]:
    """A groan: friction pulses at a seeded wandering rate, through resonances (fc, gain, q)."""
    n = n_of(length)
    wander = smooth_walk(n, rnd, step_s)
    ph, src = 0.0, []
    for i in range(n):
        x = i / n
        ph += (f_lo + (f_hi - f_lo) * wander[i]) * (1 + glide * x) / SR
        slip = 0.0
        if ph >= 1:
            ph -= 1
            slip = rnd.uniform(0.6, 1.0)
        src.append(env_fn(x) * slip)
    out = [0.0] * n
    for fc, g, q in bands:
        for i, y in enumerate(biquad_bp(src, fc, q)):
            out[i] += g * y
    return out


def wood_creak(rnd: random.Random, length: float, pitch: float = 1.0, glide: float = 0.0) -> list[float]:
    """The bed frame under the spring: a soft low wooden groan (felt, ticking, pine)."""
    base = rnd.uniform(70, 110) * pitch
    env = lambda x: math.sin(math.pi * min(1.0, x / 0.2) / 2) * math.cos(math.pi / 2 * max(0.0, x - 0.45) / 0.55)
    return stick_slip(rnd, length, base, base * 1.6,
                      [(rnd.uniform(240, 300), 1.0, 3.5), (rnd.uniform(560, 700), 0.55, 5.0)],
                      env, glide=glide, step_s=rnd.uniform(0.12, 0.3))


def spring(rnd: random.Random, length: float, pitch: float = 1.0, attack: float = 0.006,
           decay: float = 1.0, glide: float = 0.0, creak: float = 0.5, twang: float = 1.0,
           creak_glide: float = 0.0) -> list[float]:
    """The signature voice: a coiled-steel bed spring.

    Each partial of SPRING_MODES is seeded-detuned (about 1 %) and doubled by a near twin, so
    the coil shimmers; a short dispersive chirp at the onset is the twang; `glide` bends the
    whole cluster up (releasing) or down (settling). A soft wooden frame creak sits underneath.
    """
    n = n_of(length)
    a = max(1, n_of(attack))
    parts = []
    for f, amp, tau in SPRING_MODES:
        fd = f * pitch * (1 + rnd.uniform(-0.012, 0.012))
        parts.append((fd, amp, tau * decay, rnd.uniform(0, TAU)))
        parts.append((fd * (1 + rnd.uniform(0.003, 0.007)), amp * 0.45, tau * decay * 0.8, rnd.uniform(0, TAU)))
    phase = [p for _f, _a, _t, p in parts]
    out = []
    for i in range(n):
        t = i / SR
        bend = (1 + 0.07 * twang * math.exp(-t / 0.028)) * (1 + glide * (1 - math.exp(-t / 0.35)))
        v = 0.0
        for k, (f, amp, tau, _p) in enumerate(parts):
            phase[k] += TAU * f * bend / SR
            v += amp * math.sin(phase[k]) * math.exp(-t / tau)
        out.append(rise(i, a) * v)
    out = unit(out)
    if creak > 0:
        c = unit(wood_creak(rnd, length, glide=creak_glide))
        out = [s + creak * w for s, w in zip(out, c)]
    return wool(out)


# ---------------------------------------------------------------- loops

def soft_limit(xs: list[float], knee: float = 0.6, ceil: float = 0.97) -> list[float]:
    """Rounds off peaks above `knee` toward `ceil` (tanh), sample by sample: no lookahead or
    gain riding, so it is deterministic and adds no clock-like pumping."""
    span = ceil - knee
    out = []
    for x in xs:
        a = abs(x)
        if a > knee:
            a = knee + span * math.tanh((a - knee) / span)
            x = a if x > 0 else -a
        out.append(x)
    return out


def match_wrap(xs: list[float], seconds: float = 0.002) -> list[float]:
    """A raised-cosine match at the loop's wrap: over the last `seconds`, the tail is eased onto
    the sample that would come just before sample 0 (2*x[0] - x[1]), so the final sample blends
    into sample 0 with no step and no kink, whatever the crossfade left there."""
    m = max(2, int(seconds * SR))
    if len(xs) < m + 2:
        return xs
    out = list(xs)
    delta = (2.0 * out[0] - out[1]) - out[-1]
    n = len(out)
    for k in range(m):
        w = 0.5 - 0.5 * math.cos(math.pi * (k + 1) / m)
        out[n - m + k] += w * delta
    return out


def write_loop(name: str, xs: list[float]) -> None:
    """Masters to about -18 dBFS RMS. Peaky textures (raindrops, ring ticks) would hit full scale
    first, so they are rounded off by soft_limit and the level re-measured. Every loop's wrap
    gets a 2 ms raised-cosine match after seamless() (match_wrap)."""
    xs = match_wrap(seamless(xs, 1.0), 0.002)
    for _ in range(3):
        g = LOOP_RMS / max(1e-9, rms(xs))
        xs = soft_limit([x * g for x in xs])
    write(OUT, name, xs, max(abs(x) for x in xs))


def write_shot(name: str, xs: list[float], fin: float = 0.004, fout: float = 0.01) -> None:
    write(OUT, name, fade_edges(xs, fin, fout), SHOT_PEAK)


def tin_tick(rnd: random.Random, attack: float = 0.003) -> list[float]:
    """A locker's thin tin panel ticking as it cools or shifts."""
    f = rnd.uniform(1900, 2600)
    return modal(rnd, 0.09, attack, [(f, 1.0, 0.018), (f * 1.53, 0.5, 0.011), (f * 0.61, 0.35, 0.025)],
                 noise=0.25, noise_lp=3000)


def r06_room() -> list[float]:
    rnd = seed(1)
    n = n_of(9)  # 8 s after seamless(1.0)
    bed = highpass(lowpass(lowpass(brown(n, rnd), 300), 300), 22)
    air = bandlimit(white(n, rnd), 180, 600)
    walk = smooth_walk(n, rnd, 2.2)
    bed, air = unit(bed), unit(air)
    out = [(b + 0.1 * a) * (0.85 + 0.15 * w) for b, a, w in zip(bed, air, walk)]
    # two irregular tin ticks from the lockers, inside the body (not in the crossfaded tail)
    for at in (rnd.uniform(1.4, 3.6), rnd.uniform(4.6, 7.4)):
        mix(out, unit(tin_tick(rnd)), at, rnd.uniform(0.9, 1.4))
    return wool(room(out, rnd, 0.15, keep_len=True), 3500)


def drops(n: int, rnd: random.Random, rate: float) -> list[float]:
    """Seeded raindrop impulses on tin (sign and size random)."""
    out = [0.0] * n
    p = rate / SR
    for i in range(n):
        if rnd.random() < p:
            out[i] = rnd.expovariate(1.0) * rnd.choice((-1, 1))
    return out


def tin_resonate(xs: list[float]) -> list[float]:
    """Tin sheet panels: a few soft resonances, then the felt ceiling lowpass (~2.5 kHz)."""
    out = [0.0] * len(xs)
    for fc, g, q in ((1350, 0.8, 6), (2150, 1.0, 7), (3100, 0.6, 8), (700, 0.5, 3)):
        for i, y in enumerate(biquad_bp(xs, fc, q)):
            out[i] += g * y
    return lowpass(lowpass(out, 2500), 2500)


def r06_rain_roof() -> list[float]:
    rnd = seed(2)
    n = n_of(9)
    patter = unit(tin_resonate(drops(n, rnd, 1600)))
    bed = unit(bandlimit(white(n, rnd), 300, 2200))
    walk = smooth_walk(n, rnd, 1.8)
    out = [(p + 0.45 * b) * (0.8 + 0.2 * w) for p, b, w in zip(patter, bed, walk)]
    return room(out, rnd, 0.15, keep_len=True)


def r06_rain_heavy() -> list[float]:
    rnd = seed(3)
    n = n_of(9)
    sheets = unit(bandlimit(white(n, rnd), 350, 2400))
    gust = smooth_walk(n, rnd, 1.6)
    patter = unit(tin_resonate(drops(n, rnd, 3200)))
    rumble = unit(bandlimit(brown(n, rnd), 60, 400))  # the roof flexing under the weight
    out = []
    for s, g, p, r in zip(sheets, gust, patter, rumble):
        swell = 0.3 + 0.7 * g * g
        out.append(swell * (s + 0.4 * r) + (0.5 + 0.4 * swell) * 0.6 * p)
    return room(out, rnd, 0.15, keep_len=True)


def r06_wind_louvre() -> list[float]:
    rnd = seed(4)
    n = n_of(7)  # 6 s
    walk = smooth_walk(n, rnd, 0.9)
    drift = smooth_walk(n, rnd, 2.5)
    fcs = [900 + 300 * (0.65 * w + 0.35 * d) for w, d in zip(walk, drift)]
    whistle = sweep_bp(sweep_bp(white(n, rnd), fcs, 28), fcs, 28)
    air = bandlimit(white(n, rnd), 500, 1800)
    gust = smooth_walk(n, rnd, 1.2)
    whistle, air = unit(whistle), unit(air)
    out = [(0.35 + 0.65 * g) * (wv + 0.25 * a) for wv, a, g in zip(whistle, air, gust)]
    return room(out, rnd, 0.12, keep_len=True)


def ring_tick(rnd: random.Random, attack: float = 0.003) -> list[float]:
    """A brass curtain ring knocking its rail."""
    f = rnd.uniform(2600, 3300)
    return modal(rnd, 0.08, attack, [(f, 1.0, 0.012), (f * 1.62, 0.45, 0.007), (f * 0.48, 0.3, 0.02)],
                 noise=0.35, noise_lp=3500)


def r06_curtain_draught() -> list[float]:
    rnd = seed(5)
    n = n_of(7)
    hush = unit(bandlimit(white(n, rnd), 200, 1400))
    sway = smooth_walk(n, rnd, 1.1)
    out = [h * (0.3 + 0.7 * s * s) for h, s in zip(hush, sway)]
    for at in (rnd.uniform(1.2, 2.8), rnd.uniform(3.8, 5.6)):
        mix(out, unit(ring_tick(rnd)), at, rnd.uniform(0.6, 0.8))
    return wool(room(out, rnd, 0.15, keep_len=True), 3500)


def r06_beds_breath() -> list[float]:
    """Several sleepers nobody can see: unvoiced breath noise, out of phase, under blankets.

    Every breather's cycle divides the 10 s loop exactly, so the envelopes are periodic and the
    seamless crossfade only blends noise with noise. No breath dominates: depths are close.
    """
    rnd = seed(6)
    L = 10.0
    n = n_of(L + 1)
    out = [0.0] * n
    cycles = [3, 4, 3, 5, 4]  # breaths per loop for each sleeper
    for k, per_loop in enumerate(cycles):
        period = L / per_loop
        offset = rnd.uniform(0, period)
        depths = [rnd.uniform(0.8, 1.0) for _ in range(per_loop)]
        inhale = rnd.uniform(0.32, 0.42)
        nz = white(n, rnd)
        f1 = rnd.uniform(260, 380)
        src = []
        for i in range(n):
            t = ((i / SR) + offset) % L
            c, ph = divmod(t / period, 1.0)
            depth = depths[int(c) % per_loop]
            if ph < inhale:
                e = math.sin(math.pi * ph / inhale / 2) ** 2 * 0.7
            else:
                x = (ph - inhale) / (1 - inhale)
                e = math.cos(math.pi * min(1.0, x / 0.8) / 2) ** 1.5
            src.append(nz[i] * e * depth)
        body = biquad_bp(src, f1, 1.6)
        low = lowpass(lowpass(src, 500), 500)
        voice = unit([0.6 * b + l for b, l in zip(body, low)])
        for i in range(n):
            out[i] += voice[i]
    return highpass(lowpass(out, 520), 60)


def r06_pressure() -> list[float]:
    """Sub swell sweeping 32-40 Hz and back over exactly 10 s, breathing twice a loop."""
    L = 10.0
    n = n_of(L + 1)
    out = []
    for i in range(n):
        t = i / SR
        # f(t) = 36 - 4 cos(2 pi t / L): integral over L is a whole number of cycles (360)
        ph = TAU * (36 * t - 4 * L / TAU * math.sin(TAU * t / L))
        breath = 0.5 + 0.5 * (0.5 - 0.5 * math.cos(TAU * t / (L / 2)))
        v = math.sin(ph) + 0.22 * math.sin(2 * ph) + 0.12 * math.sin(3 * ph) + 0.05 * math.sin(4 * ph)
        out.append(breath * v)
    return out


def r06_cup_steam() -> list[float]:
    rnd = seed(8)
    n = n_of(5)  # 4 s
    hiss = highpass(highpass(white(n, rnd), 2800), 2800)
    hiss = lowpass(hiss, 7000)
    flutter = smooth_walk(n, rnd, 0.35)
    slow = smooth_walk(n, rnd, 1.3)
    return [h * (0.45 + 0.35 * f + 0.2 * s) for h, f, s in zip(hiss, flutter, slow)]


# ---------------------------------------------------------------- one-shots: springs

def springs_settle() -> list[float]:
    rnd = seed(9)
    s = spring(rnd, 1.4, pitch=rnd.uniform(0.93, 1.02), attack=0.04, decay=1.6, glide=-0.03,
               creak=0.75, twang=0.6)
    return fit(room(s, rnd), 1.4)


def spring_creak() -> list[float]:
    rnd = seed(10)
    s = spring(rnd, 0.9, pitch=rnd.uniform(1.04, 1.12), attack=SUDDEN_ATTACK + 0.006, decay=0.9,
               glide=-0.015, creak=0.55, twang=1.0)
    return fit(room(s, rnd), 0.9)


def springs_eight() -> list[float]:
    rnd = seed(11)
    out = silence(6.4)
    pitches = [0.84, 0.9, 0.96, 1.0, 1.05, 1.1, 1.16, 0.88]
    rnd.shuffle(pitches)
    for k in range(8):
        last = k == 7
        length = 1.45 if last else 0.9
        s = spring(rnd, length, pitch=pitches[k] * rnd.uniform(0.98, 1.02), attack=0.03,
                   decay=2.0 if last else 1.0, glide=-0.025, creak=0.7, twang=0.5)
        mix(out, peak_unit(s), 0.02 + 0.7 * k, 0.5 if last else rnd.uniform(0.85, 1.0))
    return fit(room(out, rnd), 6.4)


def dents_rise() -> list[float]:
    """The inverse of springs_eight: eight springs slowly let go, each bending upward."""
    rnd = seed(12)
    out = silence(10.5)
    for k in range(8):
        s = spring(rnd, 1.7, pitch=rnd.uniform(0.86, 1.06), attack=0.12, decay=1.7, glide=0.06,
                   creak=0.6, twang=0.0, creak_glide=0.5)
        mix(out, peak_unit(s), 0.15 + 1.2 * k, rnd.uniform(0.7, 0.85))
    return fit(room(out, rnd), 10.5)


# ---------------------------------------------------------------- one-shots: the room

def turn_step() -> list[float]:
    rnd = seed(13)
    out = silence(0.5)
    for at in (0.02, 0.24):
        step = knock(rnd, 0.16, rnd.uniform(95, 125), 0.035, attack=0.006, body_lp=700)
        board = bandlimit(white(n_of(0.1), rnd), 250, 1200)
        board = [b * math.exp(-i / n_of(0.02)) for i, b in enumerate(board)]
        mix(out, peak_unit(step), at, rnd.uniform(0.8, 1.0))
        mix(out, peak_unit(board), at + 0.004, 0.25)
    mix(out, peak_unit(rustle(rnd, 0.42, 300, 2600, 0.025)), 0.06, 0.35)
    return wool(room(fit(out, 0.5), rnd, 0.15, keep_len=True))


def locker_door() -> list[float]:
    rnd = seed(14)
    out = silence(0.7)
    env = lambda x: math.sin(math.pi * min(1.0, x / 0.25) / 2) * math.cos(math.pi / 2 * max(0.0, x - 0.55) / 0.45)
    creak = stick_slip(rnd, 0.55, 380, 520, [(1750, 1.0, 9), (2650, 0.6, 11), (900, 0.4, 5)], env, glide=-0.15,
                       step_s=0.08)
    mix(out, peak_unit(creak), 0.0, 0.8)
    for at in (0.5, 0.56, 0.6):  # the door swings to its stop and the tin rattles
        mix(out, peak_unit(tin_tick(rnd)), at + rnd.uniform(-0.01, 0.01), rnd.uniform(0.25, 0.45))
    return wool(room(out, rnd, keep_len=True))


def felt_puff(rnd: random.Random, length: float, scrape: float, down: bool) -> list[float]:
    n = n_of(length)
    puff = bandlimit(white(n, rnd), 120, 1100)
    shape = []
    for i in range(n):
        x = i / n
        if down:
            shape.append(rise(i, n_of(0.012)) * math.exp(-x * 9))
        else:
            shape.append(math.sin(math.pi * min(1.0, x / 0.35) / 2) * math.exp(-max(0.0, x - 0.35) * 7))
    out = [p * s for p, s in zip(peak_unit(puff), shape)]
    if scrape:
        sc = rustle(rnd, length * 0.6, 1200, 3800, 0.012)
        mix(out, peak_unit(sc), 0.02 if not down else 0.05, scrape)
    if down:
        mix(out, peak_unit(knock(rnd, 0.12, 150, 0.02, attack=0.008, body_lp=500)), 0.0, 0.4)
    return out


def belonging_lift() -> list[float]:
    rnd = seed(15)
    return wool(room(felt_puff(rnd, 0.3, 0.2, down=False), rnd, keep_len=True))


def belonging_set_down() -> list[float]:
    rnd = seed(16)
    return wool(room(felt_puff(rnd, 0.3, 0.08, down=True), rnd, keep_len=True))


def cup_set() -> list[float]:
    rnd = seed(17)
    out = silence(0.4)
    f = rnd.uniform(2700, 3000)
    china = modal(rnd, 0.38, 0.002, [(f, 1.0, 0.09), (f * 2.32, 0.35, 0.04), (f * 1.41, 0.3, 0.06)], noise=0.2)
    shelf = modal(rnd, 0.2, 0.002, [(820, 0.7, 0.03), (1340, 0.5, 0.02)], noise=0.4, noise_lp=2000)
    mix(out, peak_unit(shelf), 0.0, 0.6)
    mix(out, peak_unit(china), 0.002, 0.7)
    mix(out, peak_unit(china), 0.045, 0.18)  # a tiny rock back onto its foot
    return wool(room(out, rnd, keep_len=True), 5500)


def calipers_set() -> list[float]:
    rnd = seed(18)
    out = silence(0.4)
    for at, g in ((0.0, 1.0), (0.055, 0.55)):  # one leg, then the other
        f = rnd.uniform(3200, 3700)
        mix(out, peak_unit(modal(rnd, 0.3, 0.002, [(f, 1.0, 0.05), (f * 1.47, 0.6, 0.035), (f * 2.9, 0.2, 0.015)],
                                 noise=0.3)), at, g)
    mix(out, peak_unit(knock(rnd, 0.1, 180, 0.015, body_lp=600)), 0.0, 0.3)
    return wool(room(out, rnd, keep_len=True), 6000)


def pencils_set() -> list[float]:
    rnd = seed(19)
    out = silence(0.5)
    mix(out, peak_unit(modal(rnd, 0.25, 0.002, [(1150, 1.0, 0.04), (1780, 0.6, 0.03), (640, 0.5, 0.05)],
                             noise=0.5, noise_lp=2500)), 0.0, 0.8)
    t = 0.03
    for _ in range(4):  # four pencils settle against the tin
        t += rnd.uniform(0.025, 0.07)
        f = rnd.uniform(1500, 2500)
        mix(out, peak_unit(modal(rnd, 0.06, 0.001, [(f, 1.0, 0.008), (f * 1.8, 0.4, 0.005)], noise=0.4)),
            t, rnd.uniform(0.3, 0.55))
    return wool(room(out, rnd, keep_len=True))


def glove_set() -> list[float]:
    rnd = seed(20)
    out = silence(0.3)
    mix(out, peak_unit(knock(rnd, 0.2, 120, 0.03, attack=0.008, body_lp=450)), 0.0, 0.9)
    mix(out, peak_unit(rustle(rnd, 0.14, 250, 1600, 0.015, lambda x: math.exp(-x * 5))), 0.003, 0.35)
    return wool(room(out, rnd, keep_len=True), 3000)


def plate_click() -> list[float]:
    rnd = seed(21)
    out = silence(0.25)
    mix(out, peak_unit(modal(rnd, 0.2, 0.0015, [(3150, 1.0, 0.03), (4700, 0.5, 0.018), (2050, 0.4, 0.04)],
                             noise=0.5, noise_lp=6000)), 0.0, 1.0)
    mix(out, peak_unit(modal(rnd, 0.12, 0.001, [(3600, 1.0, 0.015), (5300, 0.4, 0.01)], noise=0.4)), 0.022, 0.5)
    return room(out, rnd, 0.12, keep_len=True)


def reject_set() -> list[float]:
    rnd = seed(22)
    out = silence(0.35)
    mix(out, peak_unit(knock(rnd, 0.3, 165, 0.05, attack=0.004, body_lp=600)), 0.0, 1.0)
    mix(out, peak_unit(felt_puff(rnd, 0.15, 0.0, down=True)), 0.0, 0.3)
    return wool(room(out, rnd, keep_len=True), 2500)


def compartment_drop() -> list[float]:
    """A panel falls inside a locker; the hollow behind it rings far longer than a locker could."""
    rnd = seed(23)
    out = silence(3.2)
    a = SUDDEN_ATTACK + 0.006
    panel = knock(rnd, 0.35, 140, 0.06, attack=a, body_lp=900)
    clack = modal(rnd, 0.15, a, [(620, 1.0, 0.03), (980, 0.6, 0.02), (1500, 0.3, 0.012)], noise=0.4, noise_lp=2000)
    mix(out, peak_unit(panel), 0.0, 1.0)
    mix(out, peak_unit(clack), 0.0, 0.5)
    mix(out, peak_unit(modal(rnd, 0.1, a, [(700, 1.0, 0.02), (1100, 0.5, 0.012)], noise=0.3, noise_lp=1800)),
        0.11, 0.3)  # a small bounce
    # the cavity: low wooden modes 70-110 Hz with a slow beat, about 2.6 s to near silence
    n = n_of(3.15)
    modes = [(rnd.uniform(72, 76), 1.0, 0.75), (rnd.uniform(89, 93), 0.75, 0.62),
             (rnd.uniform(104, 109), 0.5, 0.5), (rnd.uniform(146, 152), 0.3, 0.4)]  # 2nd: small speakers
    nz = lowpass(lowpass(white(n, rnd), 200), 200)
    ring = []
    aa = n_of(0.03)
    for i in range(n):
        t = i / SR
        v = sum(amp * math.sin(TAU * f * t * (1 - 0.004 * t)) * math.exp(-t / tau) for f, amp, tau in modes)
        v *= 1 + 0.25 * math.sin(TAU * 0.9 * t)
        v += 0.15 * nz[i] * math.exp(-t / 0.5)
        ring.append(rise(i, aa) * v)
    ring = peak_unit(ring)
    mix(out, ring, 0.04, 0.85)
    return lowpass(lowpass(room(out, rnd, 0.22, keep_len=True), 2400), 2400)


def latch_small() -> list[float]:
    rnd = seed(24)
    out = silence(0.4)
    a = SUDDEN_ATTACK + 0.006
    mix(out, peak_unit(modal(rnd, 0.2, a, [(2300, 1.0, 0.02), (3400, 0.5, 0.012), (1450, 0.4, 0.03)],
                             noise=0.4, noise_lp=2500)), 0.0, 1.0)
    mix(out, peak_unit(modal(rnd, 0.25, a, [(1650, 0.6, 0.06), (2620, 0.3, 0.04)], noise=0.1)), 0.035, 0.35)
    # distant: thinner, darker, and a touch more room than anything close
    return highpass(lowpass(lowpass(room(out, rnd, 0.25, keep_len=True), 2800), 2800), 300)


def paper_crackle(rnd: random.Random, length: float, rate: float, lo: float = 1200, hi: float = 5000,
                  shape=None) -> list[float]:
    n = n_of(length)
    out = [0.0] * n
    p = rate / SR
    for i in range(n):
        x = i / n
        dens = shape(x) if shape else 1.0
        if rnd.random() < p * dens:
            amp = rnd.expovariate(1.0) * rnd.choice((-1, 1))
            for k in range(rnd.randint(6, 30)):
                if i + k < n:
                    out[i + k] += amp * math.exp(-k / 6) * rnd.uniform(-1, 1)
    return bandlimit(out, lo, hi)


def letter_unfold() -> list[float]:
    rnd = seed(25)
    shape = lambda x: (0.4 + 0.6 * math.sin(math.pi * min(1.0, x / 0.3))) * (1.0 if x < 0.75 else (1 - x) / 0.25)
    cr = peak_unit(paper_crackle(rnd, 0.8, 140, shape=shape))
    rs = peak_unit(rustle(rnd, 0.8, 800, 4500, 0.04, lambda x: shape(x) * 0.8))
    out = [c + 0.5 * r for c, r in zip(cr, rs)]
    return wool(room(out, rnd, keep_len=True), 5000)


def calendar_page() -> list[float]:
    rnd = seed(26)
    out = silence(0.4)
    for at, g in ((0.0, 1.0), (0.12, 0.6)):
        mix(out, peak_unit(rustle(rnd, 0.1, 500, 3500, 0.01, lambda x: math.sin(math.pi * x) ** 2)), at, g)
        mix(out, peak_unit(knock(rnd, 0.06, 300, 0.008, body_lp=1500)), at + 0.08, 0.35 * g)
    f = rnd.uniform(2400, 2800)
    mix(out, peak_unit(modal(rnd, 0.1, 0.002, [(f, 1.0, 0.015), (f * 1.7, 0.4, 0.008)], noise=0.3)), 0.25, 0.25)
    return wool(room(out, rnd, keep_len=True))


def curtain_rings() -> list[float]:
    rnd = seed(27)
    out = silence(1.2)
    slide = rustle(rnd, 0.7, 1800, 4200, 0.01, lambda x: math.sin(math.pi * x) ** 1.5)
    mix(out, peak_unit(slide), 0.05, 0.35)
    t, gap = 0.08, 0.05
    for k in range(9):  # the rings ride along, bunch and settle
        mix(out, peak_unit(ring_tick(rnd)), t, rnd.uniform(0.4, 0.8) * (1 - k / 14))
        t += gap * rnd.uniform(0.8, 1.25)
        gap *= 1.22
    mix(out, peak_unit(rustle(rnd, 0.6, 200, 1200, 0.05)), 0.0, 0.3)  # the cloth itself
    return wool(room(out, rnd, keep_len=True))


def slope_lid() -> list[float]:
    rnd = seed(28)
    out = silence(0.6)
    env = lambda x: math.sin(math.pi * min(1.0, x / 0.2) / 2) * math.cos(math.pi / 2 * max(0.0, x - 0.6) / 0.4)
    hinge = stick_slip(rnd, 0.42, 520, 700, [(1420, 1.0, 12), (2380, 0.45, 12)], env, glide=0.12, step_s=0.07)
    mix(out, peak_unit(hinge), 0.02, 0.5)
    mix(out, peak_unit(wood_creak(rnd, 0.45, pitch=1.4)), 0.0, 0.5)
    mix(out, peak_unit(knock(rnd, 0.14, 210, 0.025, body_lp=900)), 0.45, 0.55)  # the lid rests open
    return wool(room(out, rnd, keep_len=True))


def baize_lay(nn: int, length: float, lo: float, hi: float, tap: float) -> list[float]:
    rnd = seed(nn)
    out = silence(length)
    mix(out, peak_unit(rustle(rnd, length * 0.55, lo, hi, 0.012, lambda x: math.sin(math.pi * x) * (1 - x))),
        0.0, 0.6)
    mix(out, peak_unit(knock(rnd, 0.1, 240, 0.012, body_lp=1100)), length * 0.4, tap)
    return wool(room(out, rnd, keep_len=True), 3800)


def card_lay() -> list[float]:
    return baize_lay(29, 0.3, 600, 3500, 0.5)


def sketch_lay() -> list[float]:
    return baize_lay(30, 0.35, 900, 4500, 0.25)


def wheel_step() -> list[float]:
    rnd = seed(31)
    out = silence(0.15)
    mix(out, peak_unit(modal(rnd, 0.12, 0.001, [(2650, 1.0, 0.012), (4100, 0.4, 0.007), (1300, 0.5, 0.018)],
                             noise=0.5, noise_lp=5000)), 0.0, 1.0)
    return wool(room(out, rnd, 0.1, keep_len=True), 5500)


def erase_refuse() -> list[float]:
    rnd = seed(32)
    out = silence(0.4)
    n = n_of(0.16)
    env = lambda x: math.sin(math.pi * min(1.0, x / 0.25) / 2)
    squeak = stick_slip(rnd, 0.16, 820, 980, [(1650, 1.0, 10), (2900, 0.4, 10), (900, 0.3, 6)], env, glide=0.25,
                        step_s=0.04)
    cut = n_of(0.008)  # cut short, but never a click
    for i in range(cut):
        squeak[n - 1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / cut)
    mix(out, peak_unit(squeak), 0.0, 0.8)
    mix(out, peak_unit(knock(rnd, 0.1, 260, 0.015, body_lp=1500)), 0.27, 0.6)    # the pencil set down
    mix(out, peak_unit(knock(rnd, 0.06, 300, 0.008, body_lp=1500)), 0.305, 0.25)  # and its roll
    return wool(room(out, rnd, keep_len=True))


def append_refuse() -> list[float]:
    rnd = seed(33)
    out = silence(0.25)
    for at in (0.01, 0.12):
        mix(out, peak_unit(knock(rnd, 0.1, rnd.uniform(240, 280), 0.015, body_lp=1300)), at, rnd.uniform(0.85, 1.0))
    return wool(room(out, rnd, keep_len=True), 3000)


def pencil_scratch() -> list[float]:
    """Graphite on card in word rhythm: a mechanical, even hand, but no letters are hearable."""
    rnd = seed(34)
    dur = 2.6
    n = n_of(dur)
    out = [0.0] * n
    nz = bandlimit(white(n, rnd), 1500, 6000)
    grain = smooth_walk(n, rnd, 0.008)
    t = 0.08
    while t < dur - 0.25:
        word = rnd.uniform(0.12, 0.34)
        strokes = max(2, int(word / 0.055))
        for s in range(strokes):  # each word is a run of strokes
            a, b = n_of(t + s * word / strokes), n_of(t + (s + 0.8) * word / strokes)
            g = rnd.uniform(0.6, 1.0)
            for i in range(a, min(n, b)):
                x = (i - a) / max(1, b - a)
                out[i] += g * nz[i] * math.sin(math.pi * x) * (0.4 + 0.6 * grain[i])
        t += word + rnd.uniform(0.08, 0.14)
    return wool(room(out, rnd, keep_len=True), 5500)


def cup_warm() -> list[float]:
    rnd = seed(35)
    out = silence(1.6)
    t = rnd.uniform(0.05, 0.15)
    for _ in range(3):  # the glaze crazing as it warms, far off
        f = rnd.uniform(3800, 5200)
        mix(out, peak_unit(modal(rnd, 0.05, 0.001, [(f, 1.0, 0.006), (f * 1.37, 0.4, 0.004)], noise=0.2)),
            t, rnd.uniform(0.35, 0.6))
        t += rnd.uniform(0.18, 0.32)
    steam = highpass(highpass(white(n_of(0.75), rnd), 2500), 2500)
    m = len(steam)
    steam = [s * math.sin(math.pi * i / m) ** 2 for i, s in enumerate(steam)]
    mix(out, peak_unit(steam), 0.82, 0.22)
    return lowpass(room(out, rnd, 0.2, keep_len=True), 6500)


# ---------------------------------------------------------------- build

LOOPS = [
    ("r06_room", r06_room), ("r06_rain_roof", r06_rain_roof), ("r06_rain_heavy", r06_rain_heavy),
    ("r06_wind_louvre", r06_wind_louvre), ("r06_curtain_draught", r06_curtain_draught),
    ("r06_beds_breath", r06_beds_breath), ("r06_pressure", r06_pressure), ("r06_cup_steam", r06_cup_steam),
]
SHOTS = [
    ("springs_settle", springs_settle), ("spring_creak", spring_creak), ("springs_eight", springs_eight),
    ("dents_rise", dents_rise), ("turn_step", turn_step), ("locker_door", locker_door),
    ("belonging_lift", belonging_lift), ("belonging_set_down", belonging_set_down), ("cup_set", cup_set),
    ("calipers_set", calipers_set), ("pencils_set", pencils_set), ("glove_set", glove_set),
    ("plate_click", plate_click), ("reject_set", reject_set), ("compartment_drop", compartment_drop),
    ("latch_small", latch_small), ("letter_unfold", letter_unfold), ("calendar_page", calendar_page),
    ("curtain_rings", curtain_rings), ("slope_lid", slope_lid), ("card_lay", card_lay),
    ("sketch_lay", sketch_lay), ("wheel_step", wheel_step), ("erase_refuse", erase_refuse),
    ("append_refuse", append_refuse), ("pencil_scratch", pencil_scratch), ("cup_warm", cup_warm),
]
SUDDEN = {"spring_creak", "compartment_drop", "latch_small"}


def main() -> None:
    print(f"Writing to {OUT}")
    for name, fn in LOOPS:
        write_loop(name, fn())
    for name, fn in SHOTS:
        xs = fn()
        if name in SUDDEN:
            write_shot(name, xs, SUDDEN_ATTACK, 0.02)
        else:
            write_shot(name, xs, 0.002, 0.02)


if __name__ == "__main__":
    main()
