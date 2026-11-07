"""Shared, seeded, standard-library synthesis helpers for room sound scripts.

Read-only for room teams. A room script (tools/audio/rooms/<rid>.py) does:

    import sys; from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from common import *            # SR, TAU, lowpass, white, seamless, normalize, env_ad, ...
    out = room_out("R05")           # assets/audio/R05/
    rnd = random.Random(1931_05)    # one fixed seed per sound
    write(out, "spoon_lift", xs)

Copied from tools/build_audio.py (the office set) so the office WAVs never change when a
helper here does. Everything is deterministic: same script, same bytes.
"""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SR = 22050
TAU = 2 * math.pi
ROOT = Path(__file__).resolve().parents[2]


def room_out(rid: str) -> Path:
    """The output folder for a room's sounds: assets/audio/<rid>/."""
    out = ROOT / "assets" / "audio" / rid
    out.mkdir(parents=True, exist_ok=True)
    return out


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


def write(out: Path, name: str, xs: list[float], peak: float = 0.85) -> None:
    """Writes a 16-bit mono WAV at SR, normalized to `peak`."""
    out.mkdir(parents=True, exist_ok=True)
    xs = normalize(xs, peak)
    with wave.open(str(out / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x)) * 32767)) for x in xs))
    print(f"  {out.name}/{name}.wav  {len(xs) / SR:5.2f}s  hi_share(180)={hi_share(xs):.1%}")
