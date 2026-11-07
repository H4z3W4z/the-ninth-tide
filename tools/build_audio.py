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


def write(name: str, xs: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    xs = normalize(xs)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x)) * 32767)) for x in xs))
    print(f"  {name}.wav  {len(xs) / SR:5.2f}s")


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


def drone() -> list[float]:
    """The 'reciprocal observation' bed: beating low fifths with a tritone ghost."""
    rnd = random.Random(15)
    n = int(17 * SR)
    swell = smooth_walk(n, rnd, 3.1)
    air = lowpass(white(n, rnd), 300)
    out = []
    for i in range(n):
        t = i / SR
        v = (math.sin(TAU * 41.2 * t) + 0.8 * math.sin(TAU * 41.55 * t)
             + 0.5 * math.sin(TAU * 61.7 * t) + 0.22 * math.sin(TAU * 58.3 * t + 1.3)
             + 0.12 * math.sin(TAU * 87.3 * t))
        out.append(v * (0.55 + 0.45 * swell[i]) + air[i] * 0.6)
    return seamless(out, 2.0)


def heartbeat() -> list[float]:
    """Very low double pulse, ~52 bpm. Mixed in under the drone at the end."""
    n = int(round(60 / 52 * 4 * SR))
    out = [0.0] * n
    beat = int(60 / 52 * SR)
    for k in range(4):
        for off, amp in ((0, 1.0), (int(0.22 * SR), 0.6)):
            s = k * beat + off
            for j in range(int(0.25 * SR)):
                if s + j < n:
                    t = j / SR
                    out[s + j] += math.sin(TAU * 48 * t) * math.exp(-t / 0.06) * amp
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


def sting() -> list[float]:
    """Slow, low swell. Dread, not a jump: 5 s with a 3 s rise."""
    rnd = random.Random(28)
    n = int(5.5 * SR)
    air = lowpass(white(n, rnd), 500)
    out = []
    for i in range(n):
        t = i / SR
        e = (t / 3.0) ** 2 if t < 3.0 else math.exp(-(t - 3.0) / 0.9)
        v = (math.sin(TAU * 36.7 * t) + 0.7 * math.sin(TAU * 51.9 * t)
             + 0.4 * math.sin(TAU * 73.4 * t * (1 + 0.004 * t)) + air[i] * 0.8)
        out.append(v * e)
    return out


def main() -> None:
    print(f"Writing to {OUT}")
    for name, fn in [
        ("sea", sea), ("wind", wind), ("room", room), ("drip", drip), ("hum", hum),
        ("drone", drone), ("heartbeat", heartbeat), ("switch", switch), ("seat", seat),
        ("clink", clink), ("spark", spark), ("page", page),
        ("latch_far", lambda: latch(True)), ("latch_near", lambda: latch(False)),
        ("door", door), ("sting", sting),
    ]:
        write(name, fn())


if __name__ == "__main__":
    main()
