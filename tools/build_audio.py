#!/usr/bin/env python3
"""Synthesize the Intake Office soundscape into assets/audio/*.wav.

Standard library only, fixed seeds: the same script always produces the same
bytes, so the WAVs are reproducible build outputs rather than opaque assets.
Loops are made seamless by crossfading their tail into their head.

    python3 tools/build_audio.py
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
HI_SHARE_REPORT = ("drone", "heartbeat", "sting")


def write(name: str, xs: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    xs = normalize(xs)
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
def sea() -> list[float]:
    rnd = random.Random(11)
    n = int(13 * SR)
    body = lowpass(brown(n, rnd), 420)
    hiss = highpass(white(n, rnd), 2500)
    out = []
    for i in range(n):
        t = i / SR
        swell = math.sin(math.pi * t / 6.0) ** 2           # a wave every 6 s
        crest = max(0.0, swell - 0.7) / 0.3
        out.append(body[i] * (0.35 + 0.65 * swell) + hiss[i] * 0.08 * crest)
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
DRONE_UPPER_GAIN = 4.5   # scales the upper chord (ratios kept); with the breath band this gives >= 35% above 180 Hz
DRONE_BREATH_GAIN = 0.25 * 4.5   # on a unit-RMS band


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
    out = []
    for i in range(n):
        t = i / SR
        v = (math.sin(TAU * 41.2 * t) + 0.8 * math.sin(TAU * 41.55 * t)
             + 0.5 * math.sin(TAU * 61.7 * t) + 0.22 * math.sin(TAU * 58.3 * t + 1.3)
             + 0.12 * math.sin(TAU * 87.3 * t))
        upper = sum(a * (0.5 + 0.5 * math.sin(TAU * 0.13 * t + ph)) * math.sin(TAU * f * t)
                    for f, a, ph in DRONE_UPPER)
        out.append(v * (0.55 + 0.45 * swell[i]) + air[i] * 0.6
                   + upper * DRONE_UPPER_GAIN + breath[i] * breath_env[i] * DRONE_BREATH_GAIN)
    return seamless(out, 2.0)


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
def breath() -> list[float]:
    """Something vast breathing at tide rate: two 8 s breaths of wet low-band
    noise. Inhale 3.0 s (sin^2 rise), exhale 3.6 s (falling, x1.15), 1.4 s still.
    The envelope is 0 at both ends, so the loop needs no crossfade."""
    rnd = random.Random(31)
    n = int(16.0 * SR)
    chest = band(brown(n, rnd), 120, 700)
    throat = band(white(n, rnd), 900, 1800)
    wet = smooth_walk(n, rnd, 0.11)           # slow gurgle on the throat band
    rc = (energy(chest) / n) ** 0.5
    rt = (energy(throat) / n) ** 0.5
    out = []
    for i in range(n):
        t = (i / SR) % 8.0
        if t < 3.0:
            e = math.sin(math.pi / 2 * t / 3.0) ** 2
        elif t < 6.6:
            e = 1.15 * math.cos(math.pi / 2 * (t - 3.0) / 3.6) ** 2
        else:
            e = 0.0
        out.append(e * (chest[i] / rc + 0.15 * (0.4 + 0.6 * wet[i]) * throat[i] / rt))
    return out


def ring() -> list[float]:
    """'Audible silence': 2847 + 2851 Hz beating at 4 Hz (whole cycles in 8 s,
    so the tones loop exactly) over a thin band of air."""
    rnd = random.Random(30)
    n = int(8.0 * SR)
    pad = int(0.3 * SR)
    air = seamless(band(white(n + pad, rnd), 3000, 6000), 0.3)   # exactly n samples
    return [0.5 * math.sin(TAU * 2847 * i / SR) + 0.5 * math.sin(TAU * 2851 * i / SR) + 0.08 * air[i]
            for i in range(n)]


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
def knock_glass() -> list[float]:
    """Three soft knuckle taps on the window pane, heard from inside; the third
    is late. Low-passed and given a short room echo so it is never sharp."""
    rnd = random.Random(32)
    n = int(2.0 * SR)
    out = [0.0] * n
    for onset, level in ((0.00, 1.0), (0.42, 0.85), (0.95, 0.7)):
        s = int(onset * SR)
        for j in range(int(0.5 * SR)):
            if s + j >= n:
                break
            t = j / SR
            glass = sum(a * math.sin(TAU * f * t) for f, a in ((1180, 1.0), (2310, 0.5), (3470, 0.25)))
            v = glass * decay(t, 0.05) + 0.8 * math.sin(TAU * 180 * t) * decay(t, 0.03)
            if t < 0.003:
                v += rnd.uniform(-1, 1) * (1 - t / 0.003)
            soft = min(1.0, t / 0.002)       # 2 ms onset ramp: a knuckle, not a click
            out[s + j] += v * level * soft
    return echo(lowpass(out, 2600), 0.07, 0.2, 3)[:n]


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
    ]:
        write(name, fn())


if __name__ == "__main__":
    main()
