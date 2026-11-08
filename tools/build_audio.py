#!/usr/bin/env python3
"""Synthesize the Intake Office soundscape into assets/audio/*.wav, then every room's.

Standard library only, fixed seeds: the same script always produces the same
bytes, so the WAVs are reproducible build outputs rather than opaque assets.
Loops are made seamless by crossfading their tail into their head.

    python3 tools/build_audio.py           # the office set, then every room
    python3 tools/build_audio.py R05       # one room's sounds only

Room sounds: each tools/audio/rooms/<rid>.py writes assets/audio/<rid>/*.wav, using the
shared helpers in tools/audio/common.py. Discovered by file name: adding a room's script
never edits this file. The office set below is unchanged from the slice (byte-identical).
"""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SR = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
TAU = 2 * math.pi


def lp_coef(fc: float) -> float:
    return 1 - math.exp(-TAU * fc / SR)


def lowpass(xs: list[float], fc: float) -> list[float]:
    a, y, out = lp_coef(fc), 0.0, []
    for x in xs:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(xs: list[float], fc: float) -> list[float]:
    low = lowpass(xs, fc)
    return [x - l for x, l in zip(xs, low)]


def white(n: int, rnd: random.Random) -> list[float]:
    return [rnd.uniform(-1, 1) for _ in range(n)]


def brown(n: int, rnd: random.Random) -> list[float]:
    b, out = 0.0, []
    for _ in range(n):
        b = (b + 0.02 * rnd.uniform(-1, 1)) / 1.02
        out.append(b * 3.5)
    return out


def smooth_walk(n: int, rnd: random.Random, step_s: float) -> list[float]:
    """Slow random envelope in [0,1], cosine-interpolated between random knots."""
    step = max(1, int(step_s * SR))
    knots = [rnd.random() for _ in range(n // step + 2)]
    out = []
    for i in range(n):
        k, f = divmod(i, step)
        t = (1 - math.cos(math.pi * f / step)) / 2
        out.append(knots[k] * (1 - t) + knots[k + 1] * t)
    return out


def seamless(xs: list[float], fade_s: float = 1.0) -> list[float]:
    """Crossfade the last fade_s seconds into the start; returns len(xs)-fade."""
    f = int(fade_s * SR)
    body = xs[: len(xs) - f]
    tail = xs[len(xs) - f:]
    for i in range(f):
        t = i / f
        body[i] = body[i] * t + tail[i] * (1 - t)
    return body


def normalize(xs: list[float], peak: float = 0.85) -> list[float]:
    m = max(1e-9, max(abs(x) for x in xs))
    return [x * peak / m for x in xs]


def env_ad(n: int, attack: float, decay: float) -> list[float]:
    a = max(1, int(attack * SR))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            out.append(math.exp(-(i - a) / (decay * SR)))
    return out


def echo(xs: list[float], delay_s: float, fb: float, taps: int = 6) -> list[float]:
    d = int(delay_s * SR)
    out = xs + [0.0] * d * taps
    for i in range(d, len(out)):
        out[i] += out[i - d] * fb
    return out


def band(xs: list[float], lo: float, hi: float) -> list[float]:
    """Crude band-pass: lowpass(hi) minus lowpass(lo)."""
    return [a - b for a, b in zip(lowpass(xs, hi), lowpass(xs, lo))]


def energy(xs: list[float]) -> float:
    return sum(x * x for x in xs)


def hi_share(xs: list[float], fc: float = 180) -> float:
    """Fraction of energy above fc: what survives a laptop or phone speaker."""
    return energy(highpass(xs, fc)) / max(1e-12, energy(xs))


def decay(t: float, tau: float) -> float:
    return math.exp(-t / tau)


# Beds re-voiced for small speakers; write() reports how much of them is audible.
HI_SHARE_REPORT = ("drone", "heartbeat", "sting", "breath", "knock_glass", "sea", "deep", "exhale_near")


def write(name: str, xs: list[float], peak: float = 0.85) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    xs = normalize(xs, peak)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x)) * 32767)) for x in xs))
    note = f"  hi_share(180)={hi_share(xs):.1%}" if name in HI_SHARE_REPORT else ""
    print(f"  {name}.wav  {len(xs) / SR:5.2f}s{note}")


# ---------------------------------------------------------------------------
# loops
# ---------------------------------------------------------------------------
# 500-1600 Hz wash riding the swell: the spec 0.22 on the raw band, scaled (as the
# drone upper chord is) to the level that puts >= 40% of the sea above 180 Hz.
SEA_WASH_GAIN = 0.22 * 4.2
SEA_HISS_CREST = 0.20   # spray at the top of each wave (was 0.08)


def sea() -> list[float]:
    """13 s seamless surf: a brown-noise body swelling every 6 s, a mid wash so
    the sea (and its later silence) reads on small speakers, spray on the crest."""
    rnd = random.Random(11)
    n = int(13 * SR)
    body = lowpass(brown(n, rnd), 420)
    hiss = highpass(white(n, rnd), 2500)
    # Drawn after the original voices so body and hiss keep their exact samples.
    wash = band(white(n, rnd), 500, 1600)   # the mid band small speakers can carry
    out = []
    for i in range(n):
        t = i / SR
        swell = math.sin(math.pi * t / 6.0) ** 2           # a wave every 6 s
        crest = max(0.0, swell - 0.7) / 0.3
        out.append(body[i] * (0.35 + 0.65 * swell) + wash[i] * SEA_WASH_GAIN * swell
                   + hiss[i] * SEA_HISS_CREST * crest)
    return seamless(out)


def wind() -> list[float]:
    rnd = random.Random(12)
    n = int(15 * SR)
    w = white(n, rnd)
    band = [a - b for a, b in zip(lowpass(w, 700), lowpass(w, 180))]
    gust = smooth_walk(n, rnd, 2.3)
    whistle = [math.sin(TAU * (520 + 60 * g) * i / SR) * 0.03 * g * g for i, g in enumerate(gust)]
    return seamless([b * (0.25 + 0.75 * g) + s for b, g, s in zip(band, gust, whistle)], 1.5)


def room() -> list[float]:
    rnd = random.Random(13)
    n = int(9 * SR)
    b = lowpass(brown(n, rnd), 140)
    return seamless([x + 0.04 * math.sin(TAU * 50 * i / SR) for i, x in enumerate(b)])


def drip() -> list[float]:
    rnd = random.Random(14)
    n = int(7 * SR)
    out = [0.0] * n
    for start_s in (0.4, 1.9, 2.7, 4.5, 5.1, 6.3):
        s = int(start_s * SR)
        f0 = rnd.uniform(800, 1100)
        for j in range(int(0.09 * SR)):
            if s + j >= n:
                break
            t = j / SR
            f = f0 + 900 * t / 0.09
            out[s + j] += math.sin(TAU * f * t) * math.exp(-t / 0.018) * 0.8
            out[s + j] += rnd.uniform(-1, 1) * math.exp(-t / 0.006) * 0.25
    return out


def hum() -> list[float]:
    n = 4 * SR  # whole number of 100 Hz cycles: loops cleanly
    return [
        (math.sin(TAU * 100 * i / SR) + 0.45 * math.sin(TAU * 200 * i / SR)
         + 0.2 * math.sin(TAU * 300 * i / SR)) * (0.85 + 0.15 * math.sin(TAU * 0.5 * i / SR))
        for i in range(n)
    ]


# Upper partials of the drone (4th/6th/8th harmonics of 41.2 Hz): they carry the
# bed on speakers that cannot reproduce 41 Hz, so the fundamental is implied.
DRONE_UPPER = ((164.8, 0.18, 0.0), (247.2, 0.12, 0.9), (329.6, 0.07, 1.8))  # Hz, amp, AM phase
DRONE_UPPER_GAIN = 4.5   # scales the upper chord (ratios kept)
# The random 250-900 Hz breath band is gone (gain 0). Its 4.7 s random swell sat
# exactly in the band of the 11.0 s tide breath and masked it: the room could not
# be heard breathing in time. Its noise is still drawn, so every other voice keeps
# its exact samples; the drone's small-speaker presence now comes from a steady
# air band that never swells, so nothing in the drone competes with the breath.
DRONE_BREATH_GAIN = 0.0
DRONE_AIR_BAND = (300, 600)   # Hz: steady, fixed-level, lowpassed air
DRONE_AIR_GAIN = 0.6          # on a unit-RMS band: the level that keeps >= 35% above 180 Hz
DRONE_HI_SHARE_MIN = 0.35


def drone() -> list[float]:
    """The 'reciprocal observation' bed: beating low fifths with a tritone ghost,
    a slowly pulsing upper chord and a band of breath that comes and goes."""
    rnd = random.Random(15)
    n = int(17 * SR)
    swell = smooth_walk(n, rnd, 3.1)
    air = lowpass(white(n, rnd), 300)
    w = white(n, rnd)
    breath = band(w, 250, 900)
    breath_rms = (energy(breath) / n) ** 0.5
    breath = [x / breath_rms for x in breath]   # unit RMS, so 0.25 means 0.25 of the bed
    breath_env = smooth_walk(n, rnd, 4.7)
    # Drawn last, so the voices above keep their exact samples.
    steady = lowpass(band(white(n, rnd), *DRONE_AIR_BAND), DRONE_AIR_BAND[1])
    steady_rms = (energy(steady) / n) ** 0.5
    steady = [x / steady_rms for x in steady]
    out = []
    for i in range(n):
        t = i / SR
        v = (math.sin(TAU * 41.2 * t) + 0.8 * math.sin(TAU * 41.55 * t)
             + 0.5 * math.sin(TAU * 61.7 * t) + 0.22 * math.sin(TAU * 58.3 * t + 1.3)
             + 0.12 * math.sin(TAU * 87.3 * t))
        upper = sum(a * (0.5 + 0.5 * math.sin(TAU * 0.13 * t + ph)) * math.sin(TAU * f * t)
                    for f, a, ph in DRONE_UPPER)
        out.append(v * (0.55 + 0.45 * swell[i]) + air[i] * 0.6
                   + upper * DRONE_UPPER_GAIN + breath[i] * breath_env[i] * DRONE_BREATH_GAIN
                   + steady[i] * DRONE_AIR_GAIN)
    out = seamless(out, 2.0)
    share = hi_share(out)
    assert share >= DRONE_HI_SHARE_MIN, f"drone hi_share {share:.1%} < {DRONE_HI_SHARE_MIN:.0%}"
    return out


HEART_BODY_GAIN = 1.0    # 110 Hz body at the spec 0.5
HEART_CLICK_GAIN = 3.3   # click level that gives >= 20% above 180 Hz


def heartbeat() -> list[float]:
    """Very low double pulse, ~52 bpm, with a valve click and a 110 Hz body so
    it still reads on small speakers. Mixed in under the drone at the end."""
    rnd = random.Random(16)
    n = int(round(60 / 52 * 4 * SR))
    out = [0.0] * n
    beat = int(60 / 52 * SR)
    click_n = int(0.012 * SR)
    for k in range(4):
        for off, amp in ((0, 1.0), (int(0.22 * SR), 0.6)):
            s = k * beat + off
            # 12 ms of noise under a sine window, low-passed: a soft valve tick, not a snap
            click = lowpass([rnd.uniform(-1, 1) * math.sin(math.pi * j / click_n) for j in range(click_n)], 1200)
            for j in range(int(0.25 * SR)):
                if s + j < n:
                    t = j / SR
                    v = math.sin(TAU * 48 * t) * decay(t, 0.06)
                    v += HEART_BODY_GAIN * 0.5 * math.sin(TAU * 110 * t) * decay(t, 0.03)
                    if j < click_n:
                        v += HEART_CLICK_GAIN * click[j]
                    out[s + j] += v * amp
    return out


# ---------------------------------------------------------------------------
# one-shots
# ---------------------------------------------------------------------------
def switch() -> list[float]:
    rnd = random.Random(21)
    n = int(0.25 * SR)
    return [
        rnd.uniform(-1, 1) * math.exp(-i / (0.003 * SR))
        + 0.6 * math.sin(TAU * 140 * i / SR) * math.exp(-i / (0.04 * SR))
        for i in range(n)
    ]


def seat() -> list[float]:
    rnd = random.Random(22)
    n = int(0.6 * SR)
    out = []
    for i in range(n):
        t = i / SR
        ring = sum(a * math.sin(TAU * f * t) for f, a in ((840, 1), (1313, 0.6), (2207, 0.35)))
        out.append(ring * math.exp(-t / 0.12) * 0.5 + rnd.uniform(-1, 1) * math.exp(-t / 0.004))
    return out


def clink() -> list[float]:
    n = int(0.4 * SR)
    return [sum(math.sin(TAU * f * i / SR) for f in (1900, 2870)) * math.exp(-i / (0.05 * SR)) for i in range(n)]


def spark() -> list[float]:
    rnd = random.Random(23)
    n = int(0.7 * SR)
    hiss = highpass(white(n, rnd), 3000)
    out = []
    for i in range(n):
        t = i / SR
        crack = rnd.uniform(-1, 1) if rnd.random() < 0.06 * math.exp(-t / 0.15) else 0.0
        out.append(hiss[i] * math.exp(-t / 0.08) * 0.6 + crack
                   + 0.5 * math.sin(TAU * 60 * t) * math.exp(-t / 0.2))
    return out


def page() -> list[float]:
    rnd = random.Random(24)
    n = int(0.45 * SR)
    w = white(n, rnd)
    band = [a - b for a, b in zip(lowpass(w, 4000), lowpass(w, 900))]
    return [b * math.sin(math.pi * i / n) ** 2 for i, b in enumerate(band)]


def latch(far: bool) -> list[float]:
    rnd = random.Random(25 if far else 26)
    n = int(0.12 * SR)
    one = [rnd.uniform(-1, 1) * math.exp(-i / (0.01 * SR))
           + 0.7 * math.sin(TAU * 310 * i / SR) * math.exp(-i / (0.03 * SR)) for i in range(n)]
    gap = int(0.38 * SR)
    xs = one + [0.0] * gap + [x * 0.8 for x in one] if far else one + [0.0] * int(0.05 * SR)
    if far:
        xs = lowpass(xs, 900)
        xs = echo(xs, 0.09, 0.42)
    else:
        xs = echo(xs, 0.035, 0.25, 4)
    return xs + [0.0] * int(0.3 * SR)


def door() -> list[float]:
    rnd = random.Random(27)
    n = int(2.2 * SR)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = 180 + 70 * math.sin(TAU * 0.6 * t) + rnd.uniform(-8, 8)
        phase += TAU * f / SR
        creak = (math.sin(phase) + 0.4 * math.sin(2.01 * phase)) * math.sin(math.pi * min(1, t / 1.6)) * 0.4
        out.append(creak if t < 1.6 else creak * math.exp(-(t - 1.6) / 0.15))
    return lowpass(out, 1800)


STING_CLUSTER = (220.0, 233.1, 311.1)   # minor second + tritone above A3: a held, wrong chord
STING_CLUSTER_GAIN = 1.7               # scales the 0.35-per-tone cluster to reach >= 25% above 180 Hz


def sting() -> list[float]:
    """Slow, low swell. Dread, not a jump: 5.5 s with a 3 s rise. A close
    cluster enters at 1.5 s and fades in over 1 s, riding the same envelope."""
    rnd = random.Random(28)
    n = int(5.5 * SR)
    air = lowpass(white(n, rnd), 500)
    out = []
    for i in range(n):
        t = i / SR
        e = (t / 3.0) ** 2 if t < 3.0 else math.exp(-(t - 3.0) / 0.9)
        v = (math.sin(TAU * 36.7 * t) + 0.7 * math.sin(TAU * 51.9 * t)
             + 0.4 * math.sin(TAU * 73.4 * t * (1 + 0.004 * t)) + air[i] * 0.8)
        if t >= 1.5:
            fade = math.sin(math.pi / 2 * min(1.0, (t - 1.5) / 1.0)) ** 2
            v += STING_CLUSTER_GAIN * 0.35 * fade * sum(math.sin(TAU * f * t) for f in STING_CLUSTER)
        out.append(v * e)
    return out


# ---------------------------------------------------------------------------
# new loops
# ---------------------------------------------------------------------------
# The tide-breath contract. The view mirrors these exact constants (BREATH_PERIOD,
# BREATH_IN, BREATH_OUT_END, peak) to drive the room swell and the threshold
# phase-lock; change them here and the room stops breathing in time.
BREATH_PERIOD = 11.0
BREATH_IN = 4.0
BREATH_OUT_END = 8.8
BREATH_PEAK = 1.1
BREATH_THROAT_IN = 0.15    # throat weight on the inhale
BREATH_THROAT_OUT = 0.22   # ...and on the exhale: it breathes out wetter
BREATH_SUB = 0.08          # 40 Hz swell under the chest, so it is large on headphones


def breath_env(t: float) -> float:
    """Envelope at phase t in [0, BREATH_PERIOD): inhale, exhale, then stillness."""
    if t < BREATH_IN:
        return math.sin(math.pi / 2 * t / BREATH_IN) ** 2
    if t < BREATH_OUT_END:
        return BREATH_PEAK * math.cos(math.pi / 2 * (t - BREATH_IN) / (BREATH_OUT_END - BREATH_IN)) ** 2
    return 0.0


def breath() -> list[float]:
    """Something vast breathing at tide rate, exactly one breath per 11.0 s:
    inhale 0-4.0 s (sin^2), exhale 4.0-8.8 s (1.1 x cos^2), still 8.8-11.0 s.
    Two identical-envelope cycles, 22.0 s. Voices: a chest of brown noise
    (120-700 Hz), a throat of white noise (900-1800 Hz) with a slow gurgle that
    is wetter on the exhale, and a faint 40 Hz sub-swell.

    The room has been playing this exact loop since the game started; it was
    only ever too faint to notice. The envelope is 0 at both file ends, so the
    loop needs no crossfade."""
    rnd = random.Random(31)
    n = int(2 * BREATH_PERIOD * SR)
    chest = band(brown(n, rnd), 120, 700)
    throat = band(white(n, rnd), 900, 1800)
    wet = smooth_walk(n, rnd, 0.11)           # slow gurgle on the throat band
    rc = (energy(chest) / n) ** 0.5
    rt = (energy(throat) / n) ** 0.5
    out = []
    for i in range(n):
        t = (i / SR) % BREATH_PERIOD
        e = breath_env(t)
        tw = BREATH_THROAT_IN if t < BREATH_IN else BREATH_THROAT_OUT
        out.append(e * (chest[i] / rc + tw * (0.4 + 0.6 * wet[i]) * throat[i] / rt
                        + BREATH_SUB * math.sin(TAU * 40 * i / SR)))
    return out


RING_PAIR = (1900.0, 1903.5)   # main beating pair: 3.5 Hz, 28 whole beats in 8 s
RING_GHOST = (2847.0, 0.3)      # the old ring, kept as a soft upper partial
RING_DRIFT_HZ = 0.125           # slow amplitude drift; see ring()
RING_DRIFT_DEPTH = 0.3


def ring() -> list[float]:
    """'Audible silence', re-voiced for small speakers: a 1900 / 1903.5 Hz pair
    beating at 3.5 Hz, a soft 2847 Hz partial (the old, sharper ring, now a
    ghost above it) and a thin band of air, all under a slow amplitude drift.

    Every tone completes whole cycles in the 8.0 s loop (15200, 15228, 22776),
    so the loop is exact. The drift was asked for at 0.07 Hz, but only whole
    multiples of 1/8 Hz close an 8 s loop; 0.125 Hz (one swell per loop) is the
    slowest drift that stays seamless at this length."""
    rnd = random.Random(30)
    n = int(8.0 * SR)
    pad = int(0.3 * SR)
    air = seamless(band(white(n + pad, rnd), 3000, 6000), 0.3)   # exactly n samples
    f1, f2 = RING_PAIR
    fg, ag = RING_GHOST
    out = []
    for i in range(n):
        t = i / SR
        drift = 1 - RING_DRIFT_DEPTH * (0.5 - 0.5 * math.cos(TAU * RING_DRIFT_HZ * t))
        tone = 0.5 * math.sin(TAU * f1 * t) + 0.5 * math.sin(TAU * f2 * t) + ag * math.sin(TAU * fg * t)
        out.append(tone * drift + 0.08 * air[i])
    return out


def pen() -> list[float]:
    """A nib scratching on paper, ~6 strokes/s, over a faint paper-friction bed.
    The bed is crossfaded into a loop first; no stroke crosses the loop end."""
    rnd = random.Random(29)
    n = int(3.0 * SR)
    pad = int(0.3 * SR)
    out = [x * 0.08 for x in seamless(band(white(n + pad, rnd), 1200, 3000), 0.3)]
    t = 0.04
    while True:
        length = rnd.uniform(0.025, 0.060)
        amp = rnd.uniform(0.5, 1.0)
        s, m = int(t * SR), int(length * SR)
        if s + m >= n:
            break
        burst = band(white(m, rnd), 1800, 4800)
        for j, x in enumerate(burst):
            out[s + j] += x * amp * decay(j / SR, 0.012)
        t += 0.16 * rnd.uniform(0.6, 1.4)
    return out


# ---------------------------------------------------------------------------
# new one-shots
# ---------------------------------------------------------------------------
KNOCK_TAPS = ((0.00, 1.0), (0.42, 0.85), (0.95, 0.7))   # onset s, level; the third is late
KNOCK_BODY = ((420, 1.0), (640, 0.7))                   # hollow knuckle-on-frame pair, Hz / amp
KNOCK_SLIDE_DELAY = 0.6    # after the third tap
KNOCK_SLIDE_LEN = 0.35
KNOCK_SLIDE_GAIN = 0.6


def knock_glass() -> list[float]:
    """Three soft knuckle taps on second-floor glass, heard from inside, then a
    palm drawn slowly down the pane. Each tap is a glass ring, a hollow 420/640 Hz
    body (the wooden frame answering, which carries on laptop speakers) and a
    180 Hz thump, behind a 2 ms onset ramp. Low-passed at 2600 Hz with a short
    room echo, so nothing in it is ever sharp."""
    rnd = random.Random(32)
    n = int(2.0 * SR)
    out = [0.0] * n
    for onset, level in KNOCK_TAPS:
        s = int(onset * SR)
        for j in range(int(0.5 * SR)):
            if s + j >= n:
                break
            t = j / SR
            glass = sum(a * math.sin(TAU * f * t) for f, a in ((1180, 1.0), (2310, 0.5), (3470, 0.25)))
            body = sum(a * math.sin(TAU * f * t) for f, a in KNOCK_BODY)
            v = (glass * decay(t, 0.05) + body * decay(t, 0.04)
                 + 1.0 * math.sin(TAU * 180 * t) * decay(t, 0.03))
            if t < 0.003:
                v += rnd.uniform(-1, 1) * (1 - t / 0.003)
            soft = min(1.0, t / 0.002)       # 2 ms onset ramp: a knuckle, not a click
            out[s + j] += v * level * soft
    # The wet slide: drawn after the taps so the taps keep their exact samples.
    s = int((KNOCK_TAPS[-1][0] + KNOCK_SLIDE_DELAY) * SR)
    m = int(KNOCK_SLIDE_LEN * SR)
    slide = band(white(m, rnd), 700, 2000)
    for j, x in enumerate(slide):
        out[s + j] += x * KNOCK_SLIDE_GAIN * math.sin(math.pi * j / m) ** 2
    xs = echo(lowpass(out, 2600), 0.07, 0.2, 3)[:n]
    tail = int(0.03 * SR)                    # the echo of the slide is cut at 2.0 s: fade it out
    for j in range(tail):
        xs[n - tail + j] *= 1 - j / tail
    return xs


def dial() -> list[float]:
    """Brass detent click: a 4 ms burst of noise and a small 2100 Hz ping."""
    rnd = random.Random(33)
    n = int(0.12 * SR)
    burst = int(0.004 * SR)
    return [(rnd.uniform(-1, 1) * (1 - i / burst) if i < burst else 0.0)
            + 0.5 * math.sin(TAU * 2100 * i / SR) * decay(i / SR, 0.015) for i in range(n)]


def clunk() -> list[float]:
    """A locked wooden drawer refusing: a dull double-body thud."""
    rnd = random.Random(34)
    n = int(0.5 * SR)
    knock = lowpass([rnd.uniform(-1, 1) * decay(i / SR, 0.02) for i in range(n)], 900)
    return [(math.sin(TAU * 95 * i / SR) + math.sin(TAU * 140 * i / SR)) * decay(i / SR, 0.06) + knock[i]
            for i in range(n)]


def drawer() -> list[float]:
    """A wooden drawer sliding open: stick-slip friction from 0.05 to 0.95 s,
    then a soft 110 Hz bump at 1.0 s as it reaches its stop."""
    rnd = random.Random(35)
    n = int(1.4 * SR)
    fric = lowpass(white(n, rnd), 1200)
    a, b = int(0.05 * SR), int(0.95 * SR)
    grains = [0.0] * n
    t = 0.05
    while t < 0.95:
        s = int(t * SR)
        g = rnd.uniform(0.5, 1.0)
        for j in range(int(0.06 * SR)):           # each slip: quick catch, slower release
            if s + j < n:
                u = j / SR
                grains[s + j] += g * min(1.0, u / 0.004) * decay(u, 0.018)
        t += 1.0 / rnd.uniform(9, 14)
    out = [0.0] * n
    for i in range(a, b):
        edge = min(1.0, (i - a) / (0.03 * SR), (b - i) / (0.03 * SR))
        out[i] = fric[i] * (0.25 + grains[i]) * edge
    s = int(1.0 * SR)
    for j in range(n - s):
        u = j / SR
        out[s + j] += 0.8 * math.sin(TAU * 110 * u) * decay(u, 0.05) * min(1.0, u / 0.002)
    return out


# ---------------------------------------------------------------------------
# closure report
# ---------------------------------------------------------------------------
def nib() -> list[float]:
    """One dry pencil tick as a report field changes: 0.18 s of 1.8-5 kHz grit
    under a 4 ms attack / 60 ms decay, with a tiny 900 Hz tap of the lead
    meeting paper. Made to sit under dialogue (the view plays it at -14 dB)."""
    rnd = random.Random(41)
    n = int(0.18 * SR)
    grit = band(white(n, rnd), 1800, 5000)
    env = env_ad(n, 0.004, 0.060)
    tail = int(0.02 * SR)
    out = []
    for i in range(n):
        t = i / SR
        tap = 0.3 * math.sin(TAU * 900 * t) * min(1.0, t / 0.002) * decay(max(0.0, t - 0.002), 0.002)
        v = grit[i] * env[i] + tap
        if i >= n - tail:
            v *= (n - i) / tail              # no cut at the end of the file
        out.append(v)
    return out


SIGN_STROKES = (0.00, 0.22, 0.41, 0.70, 0.98)   # onset s
SIGN_RAMP = 0.008       # soft stroke edges
SIGN_FLICK = 0.080      # the last stroke lifts off over 80 ms
SIGN_RUB = 0.15


def sign() -> list[float]:
    """A pen signature, 1.3 s: five strokes of scratchy nib noise (2-6 kHz,
    amplitude-modulated by a 30 ms smooth walk, so the pressure wavers) with
    8 ms ramps, over a soft paper rub (300-900 Hz brown) that follows the
    hand. The last stroke is a flick that decays over 80 ms. No attack is
    shorter than 8 ms."""
    rnd = random.Random(42)
    n = int(1.3 * SR)
    scratch = band(white(n, rnd), 2000, 6000)
    press = smooth_walk(n, rnd, 0.03)
    rub = band(brown(n, rnd), 300, 900)
    rs = (energy(scratch) / n) ** 0.5
    rr = (energy(rub) / n) ** 0.5
    gate = [0.0] * n
    ramp = int(SIGN_RAMP * SR)
    for k, onset in enumerate(SIGN_STROKES):
        s = int(onset * SR)
        m = int(rnd.uniform(0.12, 0.24) * SR)
        last = k == len(SIGN_STROKES) - 1
        release = int(SIGN_FLICK * SR) if last else ramp
        level = rnd.uniform(0.75, 1.0)
        for j in range(m):
            if s + j >= n:
                break
            a = math.sin(math.pi / 2 * min(1.0, j / ramp)) ** 2
            r = min(1.0, (m - j) / release)
            if last and m - j < release:
                r = math.exp(-3.0 * (1 - (m - j) / release)) * (m - j) / release   # flick: fast fall, clean end
            gate[s + j] = max(gate[s + j], level * a * r)
    hand = lowpass(lowpass(gate, 8), 8)    # the paper rub lags the nib: the hand resting on the sheet
    hp = max(1e-9, max(hand))
    out = []
    for i in range(n):
        v = scratch[i] / rs * gate[i] * (0.35 + 0.65 * press[i])
        v += SIGN_RUB * rub[i] / rr * hand[i] / hp
        out.append(v)
    tail = int(0.03 * SR)
    for j in range(tail):
        out[n - tail + j] *= 1 - j / tail
    return out


# ---------------------------------------------------------------------------
# round 3: what is under the floor, and what is behind her
# ---------------------------------------------------------------------------
DEEP_LEN = 14.0
DEEP_GLIDE = (58.0, 43.0, 10.0)   # carrier Hz from, to, over seconds (exponential)
DEEP_MOD_RATIO = 1.41             # inharmonic: no note the ear can settle on
DEEP_INDEX = (2.5, 0.8)           # FM index from start to end
DEEP_PARTIALS = ((2.0, 0.5), (3.0, 0.3), (4.5, 0.2))   # ratio to carrier, amp
DEEP_FORMANT = (300, 700, 0.25)   # brown-noise band Hz, level on a unit-RMS band
# The spec levels alone leave only ~22% above 180 Hz (the 3x partial sits at
# 129-174 Hz). Scaled, as the drone and sea are, to clear 30% on small speakers:
DEEP_PARTIAL_GAIN = 1.5           # on the partials (ratios kept)
DEEP_FORMANT_GAIN = 2.6           # on the formant: the moan's breath is what a laptop hears
DEEP_LOWPASS = 900                # heard through boards
DEEP_HI_SHARE_MIN = 0.30


def deep() -> list[float]:
    """The thing beneath the floor: a 14 s FM moan. The carrier sinks 58 -> 43 Hz
    along an exponential glide over the first 10 s, then holds; the modulator
    rides 1.41 x the carrier, so the sidebands never form a chord, and the index
    relaxes 2.5 -> 0.8, so it starts as a throat and ends as a hum. Partials at
    2x, 3x and 4.5x the carrier and a 300-700 Hz brown-noise formant carry it on
    small speakers. One sin^2 envelope over the whole length (no onset at all),
    then a 900 Hz lowpass so it arrives through the floorboards."""
    rnd = random.Random(43)
    n = int(DEEP_LEN * SR)
    f0, f1, glide = DEEP_GLIDE
    lo, hi, fgain = DEEP_FORMANT
    formant = band(brown(n, rnd), lo, hi)
    fr = (energy(formant) / n) ** 0.5
    pc = pm = 0.0
    out = []
    for i in range(n):
        t = i / SR
        fc = f0 * (f1 / f0) ** (min(t, glide) / glide)
        pc += TAU * fc / SR
        pm += TAU * fc * DEEP_MOD_RATIO / SR
        index = DEEP_INDEX[0] + (DEEP_INDEX[1] - DEEP_INDEX[0]) * t / DEEP_LEN
        v = math.sin(pc + index * math.sin(pm))
        v += DEEP_PARTIAL_GAIN * sum(a * math.sin(r * pc) for r, a in DEEP_PARTIALS)
        v += DEEP_FORMANT_GAIN * fgain * formant[i] / fr
        out.append(v * math.sin(math.pi * t / DEEP_LEN) ** 2)
    out = lowpass(out, DEEP_LOWPASS)
    share = hi_share(out)
    assert share >= DEEP_HI_SHARE_MIN, f"deep hi_share {share:.1%} < {DEEP_HI_SHARE_MIN:.0%}"
    return out


# The leitmotif. Eight honest notes, then a ninth that is a quarter-tone wrong:
# the tune resolves to somewhere that is not quite C.
MOTIF_NOTES = (293.66, 349.23, 440.00, 392.00, 349.23, 329.63, 293.66, 277.18,
               261.63 * 2 ** (-0.5 / 12))
MOTIF_STEP = 0.85
MOTIF_ATTACK = 0.25
MOTIF_TAU = 0.9
MOTIF_PARTIALS = ((1.0, 1.0), (2.0, 0.45), (3.0, 0.25), (4.1, 0.12))   # stretched 4th: glassy reed
MOTIF_VIBRATO = (4.5, 3.0)        # Hz, cents
MOTIF_REED_AIR = 0.025            # faint bellows air under each note, on its envelope
MOTIF_ECHO = (0.11, 0.45, 6)
MOTIF_LOWPASS = 3500
MOTIF_TAIL = 1.5


def motif_render(notes: tuple[float, ...], seed: int = 44) -> list[float]:
    """A slow harmonium line, one note every 0.85 s: 0.25 s sin^2 swell, then an
    exponential decay (tau 0.9 s); partials 1/2/3/4.1 under a 4.5 Hz, 3-cent
    vibrato, with a breath of reed air. Then a short room echo, a 3.5 kHz lowpass
    and a 1.5 s tail that fades to nothing."""
    rnd = random.Random(seed)
    d, fb, taps = MOTIF_ECHO
    last = (len(notes) - 1) * MOTIF_STEP
    n = int((last + MOTIF_ATTACK + MOTIF_TAIL) * SR)
    total = n + int(d * SR) * taps
    a = int(MOTIF_ATTACK * SR)
    vib_hz, vib_cents = MOTIF_VIBRATO
    out = [0.0] * total
    for k, f in enumerate(notes):
        s = int(k * MOTIF_STEP * SR)
        air = band(white(total - s, rnd), 600, 2400)
        ar = (energy(air) / len(air)) ** 0.5
        ph = 0.0
        for j in range(total - s):
            t = j / SR
            e = math.sin(math.pi / 2 * j / a) ** 2 if j < a else decay(t - MOTIF_ATTACK, MOTIF_TAU)
            if e < 1e-4 and j > a:
                break
            ph += TAU * f * 2 ** (vib_cents / 1200 * math.sin(TAU * vib_hz * t)) / SR
            v = sum(amp * math.sin(r * ph) for r, amp in MOTIF_PARTIALS)
            out[s + j] += e * (v + MOTIF_REED_AIR * air[j] / ar)
    xs = lowpass(echo(out, d, fb, taps)[:total], MOTIF_LOWPASS)
    fade = int(0.6 * SR)                     # the last of the echo leaves; no cut at the end
    for j in range(fade):
        xs[total - fade + j] *= math.cos(math.pi / 2 * j / fade) ** 2
    return xs


def motif() -> list[float]:
    return motif_render(MOTIF_NOTES)


def motif_short() -> list[float]:
    """The motif's last three notes (D4, C#4, the flat C4): the wrong ending alone."""
    return motif_render(MOTIF_NOTES[-3:])


EXHALE_LEN = 1.8
EXHALE_ATTACK = 0.3
EXHALE_PLATEAU_END = 0.9
EXHALE_THROAT = (450, 750, 0.3)   # formant around 600 Hz
EXHALE_CHEST = (90.0, 0.1)


def exhale_near() -> list[float]:
    """One slow, close, wet exhale just behind her shoulder. Breath noise
    band-passed 300-2500 Hz, a throat formant around 600 Hz that gurgles on a
    40 ms smooth walk (the wet part), and a faint 90 Hz chest. Envelope: 0.3 s
    raised-cosine attack, plateau to 0.9 s, cos^2 decay to silence at 1.8 s,
    with the breath darkening as it runs out of air."""
    rnd = random.Random(45)
    n = int(EXHALE_LEN * SR)
    air = band(white(n, rnd), 300, 2500)
    lo, hi, tg = EXHALE_THROAT
    throat = band(white(n, rnd), lo, hi)
    wet = smooth_walk(n, rnd, 0.04)
    ra = (energy(air) / n) ** 0.5
    rt = (energy(throat) / n) ** 0.5
    cf, ca = EXHALE_CHEST
    out = []
    for i in range(n):
        t = i / SR
        if t < EXHALE_ATTACK:
            e = 0.5 - 0.5 * math.cos(math.pi * t / EXHALE_ATTACK)
        elif t < EXHALE_PLATEAU_END:
            e = 1.0
        else:
            e = math.cos(math.pi / 2 * (t - EXHALE_PLATEAU_END) / (EXHALE_LEN - EXHALE_PLATEAU_END)) ** 2
        v = air[i] / ra + tg * (0.3 + 0.7 * wet[i]) * throat[i] / rt + ca * math.sin(TAU * cf * t)
        out.append(v * e)
    # The breath darkens as the lungs empty: a lowpass that closes from 4 kHz to 1.2 kHz.
    y, dark = 0.0, []
    for i, x in enumerate(out):
        y += lp_coef(4000 - 2800 * i / n) * (x - y)
        dark.append(y)
    return dark


ECHO_STEP_LEN = 0.5
ECHO_STEP_HEELS = ((0.03, 132.0), (0.31, 96.0))   # (onset s, thud Hz): two heel strikes 0.28 s apart
ECHO_STEP_PEAK = 10 ** (-6 / 20)                    # -6 dBFS


def echo_step() -> list[float]:
    """Two soft heel strikes on boards, somewhere off to one side (the core's echo_trace).
    Each strike is a damped 90-140 Hz thud with a pitch drop, a dull board knock, and a
    short lowpassed noise scuff as the heel lands. 0.5 s, seeded 'echo_step'."""
    rnd = random.Random("echo_step")
    n = int(ECHO_STEP_LEN * SR)
    out = [0.0] * n
    for onset, hz in ECHO_STEP_HEELS:
        s = int(onset * SR)
        scuff = lowpass(white(int(0.05 * SR), rnd), 1800)
        for j in range(n - s):
            t = j / SR
            f = hz * (1.0 + 0.25 * math.exp(-t / 0.01))     # the board gives under the heel
            v = math.sin(TAU * f * t) * math.exp(-t / 0.045)
            v += 0.35 * math.sin(TAU * 2.6 * hz * t) * math.exp(-t / 0.018)
            if j < len(scuff):
                v += 0.5 * scuff[j] * math.exp(-t / 0.012)
            out[s + j] += v
    return lowpass(out, 2400)


# Core one-shots added after the slice set: written by a full run, or alone with
#   python3 tools/build_audio.py --core-added
# so adding one never rewrites the approved WAVs above.
CORE_ADDED = [("echo_step", echo_step, ECHO_STEP_PEAK)]


def core_added() -> None:
    for name, fn, peak in CORE_ADDED:
        write(name, fn(), peak)


def main() -> None:
    print(f"Writing to {OUT}")
    for name, fn in [
        ("sea", sea), ("wind", wind), ("room", room), ("drip", drip), ("hum", hum),
        ("drone", drone), ("heartbeat", heartbeat), ("switch", switch), ("seat", seat),
        ("clink", clink), ("spark", spark), ("page", page),
        ("latch_far", lambda: latch(True)), ("latch_near", lambda: latch(False)),
        ("door", door), ("sting", sting),
        ("breath", breath), ("ring", ring), ("pen", pen),
        ("knock_glass", knock_glass), ("dial", dial), ("clunk", clunk), ("drawer", drawer),
        ("nib", nib), ("sign", sign),
    ]:
        write(name, fn())
    for name, fn, peak in [
        ("deep", deep, 0.8), ("motif", motif, 0.7), ("motif_short", motif_short, 0.7),
        ("exhale_near", exhale_near, 0.6),
    ]:
        write(name, fn(), peak)
    core_added()


def rooms(only: list[str]) -> None:
    import subprocess
    import sys
    here = Path(__file__).resolve().parent
    for script in sorted((here / "audio" / "rooms").glob("R[0-9][0-9].py")):
        if only and script.stem not in only:
            continue
        print(f"== {script.relative_to(here.parent)}", flush=True)
        subprocess.run([sys.executable, str(script)], cwd=here.parent, check=True)


if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["--core-added"]:
        core_added()
    else:
        if len(sys.argv) == 1:
            main()
        rooms(sys.argv[1:])
