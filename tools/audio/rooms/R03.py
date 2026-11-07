#!/usr/bin/env python3
"""R03 Chart Room soundscape: seeded, standard-library synthesis -> assets/audio/R03/*.wav.

The chart room is DRY: paper, brass and a thin clockwork, the opposite of R02's breath.
Its dread is made of absences (a hatch with no water behind it, a drum that stops while the
nib keeps scratching) and one pressure layer at band 7. No stingers.

    python3 tools/build_audio.py R03        # or: python3 tools/audio/rooms/R03.py

Every id seeds random.Random(f"19311017:{id}"); nothing reads the clock, so reruns are
byte-identical. Loops are rendered over length + crossfade with their rhythmic events laid
out with the loop's period, then passed through seamless(): the tail that is folded into the
head carries the same ticks at the same places, so the wrap has no click and no doubled tick.

Loop levels for the view (linear LoopMixer targets; the view owns the mix):
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import (  # noqa: E402
    SR, TAU, band, brown, echo, env_ad, highpass, lowpass, lp_coef, room_out, seamless,
    smooth_walk, white, write,
)

SEED = "19311017"

# Linear targets the R03 view is expected to feed LoopMixer.tick() (suggested; the view owns it).
LOOP_LEVELS = {
    "r03_room": 0.30,       # always on
    "r03_sea": 0.34,        # bands 0-4 (falling: 0.34, 0.30, 0.24, 0.17, 0.10), 0 from band 5; 0 on wall C after P04
    "r03_rain": 0.26,       # bands 1-4; playback rate ~0.75 at bands 3-4
    "r03_scratch": 0.32,    # before P04, and again from band 5
    "r03_drum": 0.30,       # after P04 until band 5
    "r03_pressure": 0.55,   # band 7 only
    "r03_stair_air": 0.14,  # wall C after P04, very quiet
}
# The sudden one-shots (SFX_SOFT): their peak sits in the first few milliseconds.
SUDDEN = ("hatch_open", "relay_clack", "lever_refuse", "glass_press")

__doc__ += "".join(f"    {k:<14} {v:.2f}\n" for k, v in LOOP_LEVELS.items())


def rng(sid: str) -> random.Random:
    return random.Random(f"{SEED}:{sid}")


def silence(seconds: float) -> list[float]:
    return [0.0] * int(round(seconds * SR))


def add(out: list[float], xs: list[float], at_s: float, gain: float = 1.0) -> None:
    """Mixes xs into out starting at at_s seconds; anything past the end is dropped."""
    s = int(round(at_s * SR))
    for j, x in enumerate(xs):
        k = s + j
        if 0 <= k < len(out):
            out[k] += x * gain


def resonator(xs: list[float], f0: float, q: float) -> list[float]:
    """RBJ constant-peak band-pass biquad: a hollow, pitched resonance."""
    w0 = TAU * f0 / SR
    alpha = math.sin(w0) / (2 * q)
    a0 = 1 + alpha
    b0, b2 = alpha / a0, -alpha / a0
    a1, a2 = -2 * math.cos(w0) / a0, (1 - alpha) / a0
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in xs:
        y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def rms(xs: list[float]) -> float:
    return (sum(x * x for x in xs) / max(1, len(xs))) ** 0.5


def unit(xs: list[float]) -> list[float]:
    r = max(1e-12, rms(xs))
    return [x / r for x in xs]


def fade_edges(xs: list[float], fin: float = 0.002, fout: float = 0.01) -> list[float]:
    n, a, b = len(xs), max(1, int(fin * SR)), max(1, int(fout * SR))
    return [x * min(1.0, i / a) * min(1.0, (n - 1 - i) / b) for i, x in enumerate(xs)]


def fit(xs: list[float], seconds: float, fout: float = 0.05) -> list[float]:
    """Exactly `seconds` long: pads or trims, with a short fade so nothing is cut mid-ring."""
    n = int(round(seconds * SR))
    xs = (xs + [0.0] * n)[:n]
    return fade_edges(xs, 0.0005, fout)


def periodic(out: list[float], period_s: float, times: list[float], make) -> None:
    """Places make(i) at each time and again one period later (the seamless() tail)."""
    for i, t in enumerate(times):
        xs = make(i)
        add(out, xs, t)
        add(out, xs, t + period_s)


# ---------------------------------------------------------------------------
# sound atoms
# ---------------------------------------------------------------------------
def tick(rnd: random.Random, f: float = 2600, tau: float = 0.004, n_s: float = 0.03,
         noise: float = 0.6, body: float = 0.0, body_f: float = 300) -> list[float]:
    """A small hard click: a noise impulse plus a short metallic ring (and optional body)."""
    n = int(n_s * SR)
    out = []
    for j in range(n):
        t = j / SR
        v = noise * rnd.uniform(-1, 1) * math.exp(-t / 0.0012)
        v += math.sin(TAU * f * t) * math.exp(-t / tau) + 0.4 * math.sin(TAU * f * 1.53 * t) * math.exp(-t / (tau * 0.6))
        if body:
            v += body * math.sin(TAU * body_f * t) * math.exp(-t / 0.02)
        out.append(v)
    return out


def typebar(rnd: random.Random, gain: float = 1.0) -> list[float]:
    """One typebar striking ribbon and platen: a hard crack, a short steel ring, a rubbery thump."""
    n = int(0.07 * SR)
    f1, f2 = rnd.uniform(1050, 1250), rnd.uniform(1800, 2150)
    out = []
    for j in range(n):
        t = j / SR
        v = rnd.uniform(-1, 1) * math.exp(-t / 0.0015)
        v += 0.55 * math.sin(TAU * f1 * t) * math.exp(-t / 0.012)
        v += 0.35 * math.sin(TAU * f2 * t) * math.exp(-t / 0.008)
        v += 0.6 * math.sin(TAU * 165 * t) * math.exp(-t / 0.018)
        out.append(v * gain)
    return out


def paper_advance(rnd: random.Random, length_s: float = 0.18) -> list[float]:
    """The platen ratcheting the strip up one line: fast fine clicks over a short paper drag."""
    n = int(length_s * SR)
    drag = band(white(n, rnd), 900, 3500)
    out = [drag[j] * 0.25 * math.sin(math.pi * j / n) for j in range(n)]
    for k in range(5):
        add(out, tick(rnd, 3100, 0.003, 0.02, 0.5), k * length_s / 5.5, 0.35)
    add(out, tick(rnd, 900, 0.01, 0.05, 0.6, 0.8, 140), length_s * 0.92, 0.5)
    return out


def scrape(rnd: random.Random, length_s: float, lo: float, hi: float, rough: float = 0.5) -> list[float]:
    n = int(length_s * SR)
    w = band(white(n, rnd), lo, hi)
    grit = smooth_walk(n, rnd, 0.012)
    return [x * (1 - rough + rough * g) * math.sin(math.pi * j / n) for j, (x, g) in enumerate(zip(w, grit))]


def thunk(rnd: random.Random, f: float = 90, tau: float = 0.06, n_s: float = 0.25) -> list[float]:
    n = int(n_s * SR)
    knock = lowpass(white(n, rnd), 1200)
    return [math.sin(TAU * f * j / SR) * math.exp(-j / (tau * SR))
            + 0.6 * math.sin(TAU * f * 2.3 * j / SR) * math.exp(-j / (tau * 0.5 * SR))
            + knock[j] * 2.0 * math.exp(-j / (0.006 * SR)) for j in range(n)]


def clank(rnd: random.Random, n_s: float = 0.35, base: float = 410, tau: float = 0.09) -> list[float]:
    """Heavy iron-on-brass: an instant impact with inharmonic plate partials."""
    n = int(n_s * SR)
    parts = ((base, 1.0), (base * 2.41, 0.7), (base * 3.87, 0.45), (base * 5.3, 0.3))
    out = []
    for j in range(n):
        t = j / SR
        v = 1.4 * rnd.uniform(-1, 1) * math.exp(-t / 0.003)
        v += sum(a * math.sin(TAU * f * t) * math.exp(-t / (tau / (1 + k * 0.6))) for k, (f, a) in enumerate(parts))
        v += 0.9 * math.sin(TAU * 95 * t) * math.exp(-t / 0.05)
        out.append(v)
    return out


# ---------------------------------------------------------------------------
# loops
# ---------------------------------------------------------------------------
def r03_room() -> list[float]:
    """12 s dry room tone: brown bed under 300 Hz and a faint jittered escapement at ~2.3 Hz."""
    rnd = rng("r03_room")
    L, F = 12.0, 1.0
    n = int((L + F) * SR)
    bed = unit(lowpass(lowpass(brown(n, rnd), 300), 300))
    out = [b * 0.5 for b in bed]
    times, t = [], 0.05
    while t < L - 0.05:
        times.append(t)
        t += (1 / 2.3) * (1 + rnd.uniform(-0.08, 0.08))
    # Tick/tock alternate a little in pitch, as an escapement does.
    periodic(out, L, times, lambda i: tick(rnd, 2900 if i % 2 else 2450, 0.003, 0.025, 0.45))
    return seamless(out, F)


def r03_sea() -> list[float]:
    """16 s sea through glass: slow 5-7 s swells, 80-900 Hz, no hiss, distant."""
    rnd = rng("r03_sea")
    L, F = 16.0, 2.0
    n = int((L + F) * SR)
    body = unit(band(lowpass(brown(n, rnd), 900), 80, 900))
    wash = unit(band(white(n, rnd), 250, 900))
    swell = smooth_walk(n, rnd, rnd.uniform(5.0, 7.0))
    slow = smooth_walk(n, rnd, 2.7)
    out = []
    for i in range(n):
        s = swell[i] ** 1.5
        out.append(body[i] * (0.3 + 0.7 * s) + wash[i] * 0.35 * s * (0.6 + 0.4 * slow[i]))
    return seamless(lowpass(out, 900), F)  # the pane: nothing above 900 Hz gets through


def r03_rain() -> list[float]:
    """10 s rain on a pane: dense seeded tiny ticks in 2-6 kHz over a soft wash."""
    rnd = rng("r03_rain")
    L, F = 10.0, 1.0
    n = int((L + F) * SR)
    imp = [0.0] * n
    for i in range(n):
        if rnd.random() < 0.012:
            imp[i] = rnd.uniform(-1, 1) * (0.3 + 0.7 * rnd.random() ** 3)
    drops = unit(band(imp, 2000, 6000))
    wash = unit(band(white(n, rnd), 700, 3000))
    density = smooth_walk(n, rnd, 1.6)
    return seamless([d * (0.75 + 0.25 * k) + w * 0.18 for d, w, k in zip(drops, wash, density)], F)


def r03_scratch() -> list[float]:
    """9 s steel nib stuck on one spot: short 1.5-5 kHz strokes, irregular, no paper drag."""
    rnd = rng("r03_scratch")
    L, F = 9.0, 1.0
    n = int((L + F) * SR)
    out = [0.0] * n
    times, t = [], 0.1
    while t < L - 0.2:
        times.append(t)
        # back-and-forth pairs, then an irregular hesitation
        t += rnd.uniform(0.07, 0.13) if len(times) % 2 else rnd.uniform(0.12, 0.45)

    def stroke(i: int) -> list[float]:
        ln = rnd.uniform(0.045, 0.1)
        m = int(ln * SR)
        lo, hi = (1500, 4200) if i % 2 else (1900, 5000)  # up-stroke and down-stroke differ
        w = band(white(m, rnd), lo, hi)
        g = smooth_walk(m, rnd, 0.004)  # the nib catching on the fibre
        amp = rnd.uniform(0.6, 1.0)
        return [x * amp * (0.4 + 0.6 * gg) * math.sin(math.pi * j / m) ** 0.7 for j, (x, gg) in enumerate(zip(w, g))]

    periodic(out, L, times, stroke)
    return seamless(out, F)


def r03_drum() -> list[float]:
    """8 s the drum turning: 4 Hz fine tick, continuous paper drag, a steady pen line."""
    rnd = rng("r03_drum")
    L, F = 8.0, 1.0
    n = int((L + F) * SR)
    drag = unit(band(white(n, rnd), 600, 2500))
    pen = unit(band(white(n, rnd), 2800, 4500))
    gear = unit(lowpass(white(n, rnd), 180))
    out = [d * 0.22 + p * 0.10 + g * 0.06 for d, p, g in zip(drag, pen, gear)]
    periodic(out, L, [k * 0.25 + 0.02 for k in range(int(L * 4))],
             lambda i: tick(rnd, 3300 if i % 4 else 2700, 0.0025, 0.02, 0.4))
    return seamless(out, F)


PRESSURE_UPPER_GAIN = 5.5   # the level that puts >= 30% of the hum above 180 Hz


def r03_pressure() -> list[float]:
    """10 s pressure hum: 38-55 Hz beating sines, 0.1 Hz swell, faint glass-stress creak."""
    rnd = rng("r03_pressure")
    L, F = 10.0, 1.0
    n = int((L + F) * SR)
    creak_imp = [0.0] * n
    for i in range(n):
        if rnd.random() < 0.0016:
            creak_imp[i] = rnd.uniform(-1, 1)
    creak = unit(resonator(resonator(creak_imp, 310, 12), 310, 12))
    creak_env = smooth_walk(n, rnd, 1.3)
    out = []
    for i in range(n):
        t = i / SR
        swell = 0.55 + 0.45 * math.sin(TAU * 0.1 * t - math.pi / 2)  # period 10 s: loops exactly
        low = (math.sin(TAU * 38.0 * t) + 0.9 * math.sin(TAU * 38.6 * t)
               + 0.7 * math.sin(TAU * 55.0 * t) + 0.6 * math.sin(TAU * 54.7 * t + 1.1))
        # Harmonics so a laptop speaker hears the beating it cannot reproduce at 38 Hz.
        upper = (0.35 * math.sin(TAU * 114.0 * t) + 0.3 * math.sin(TAU * 115.8 * t)
                 + 0.22 * math.sin(TAU * 165.0 * t) + 0.18 * math.sin(TAU * 164.1 * t))
        out.append((low + PRESSURE_UPPER_GAIN * upper) * swell + creak[i] * 0.2 * creak_env[i] ** 2)
    return seamless(out, F)


def r03_stair_air() -> list[float]:
    """12 s dry draught up an empty stair: soft airflow, hollow resonance near 220 Hz, no water."""
    rnd = rng("r03_stair_air")
    L, F = 12.0, 1.5
    n = int((L + F) * SR)
    w = white(n, rnd)
    flow = unit(lowpass(lowpass(w, 600), 600))
    hollow = unit(resonator(w, 220, 18))
    hollow2 = unit(resonator(w, 447, 22))  # the stair's second mode, slightly sharp of 2x
    gust = smooth_walk(n, rnd, 3.3)
    return seamless([(f * 0.6 + h * 0.5 + h2 * 0.15) * (0.55 + 0.45 * g)
                     for f, h, h2, g in zip(flow, hollow, hollow2, gust)], F)


# ---------------------------------------------------------------------------
# one-shots
# ---------------------------------------------------------------------------
def turn() -> list[float]:
    rnd = rng("turn")
    out = silence(0.5)
    for at, g in ((0.02, 1.0), (0.24, 0.8)):
        add(out, scrape(rnd, 0.13, 300, 2200, 0.7), at, g)
        add(out, thunk(rnd, 110, 0.03, 0.12), at + 0.01, 0.35 * g)
    return fit(out, 0.5)


def sheet_slide() -> list[float]:
    rnd = rng("sheet_slide")
    n = int(0.6 * SR)
    w = white(n, rnd)
    y, out = 0.0, []
    for j, x in enumerate(w):
        p = j / n
        y += lp_coef(1400 + 3600 * p) * (x - y)
        out.append(y)
    out = highpass(out, 500)
    return fit([x * math.sin(math.pi * j / n) ** 1.5 for j, x in enumerate(out)], 0.6)


def sheet_rotate() -> list[float]:
    rnd = rng("sheet_rotate")
    n = int(0.4 * SR)
    crackle = [0.0] * n
    for j in range(n):
        if rnd.random() < 0.02:
            crackle[j] = rnd.uniform(-1, 1)
    crackle = band(crackle, 1500, 6000)
    swish = band(white(n, rnd), 800, 3000)
    out = []
    for j in range(n):
        p = j / n
        out.append(crackle[j] * 2.5 + swish[j] * 0.6 * math.sin(math.pi * p) ** 2)
    return fit(out, 0.4)


def cross_snap() -> list[float]:
    rnd = rng("cross_snap")
    out = silence(0.15)
    add(out, tick(rnd, 3200, 0.03, 0.14, 0.9), 0.003)
    return fit(out, 0.15, 0.02)


def clip_snap() -> list[float]:
    rnd = rng("clip_snap")
    out = silence(0.35)
    add(out, tick(rnd, 2400, 0.004, 0.03, 0.4), 0.0, 0.3)          # the spring taking up
    add(out, clank(rnd, 0.3, 1150, 0.05), 0.045, 0.8)              # the snap home
    add(out, thunk(rnd, 180, 0.03, 0.15), 0.045, 0.5)
    return fit(out, 0.35)


def clip_refuse() -> list[float]:
    rnd = rng("clip_refuse")
    out = silence(0.4)
    add(out, scrape(rnd, 0.16, 400, 1600, 0.6), 0.0, 0.8)
    m = int(0.25 * SR)
    twang = [math.sin(TAU * (520 + 18 * math.sin(TAU * 7 * j / SR)) * j / SR) * math.exp(-j / (0.07 * SR)) for j in range(m)]
    add(out, lowpass(twang, 1500), 0.13, 0.6)
    return fit(out, 0.4)


def tin_open() -> list[float]:
    rnd = rng("tin_open")
    out = silence(0.8)
    add(out, scrape(rnd, 0.2, 700, 2600, 0.8), 0.0, 0.5)      # the lid edge levering
    add(out, clank(rnd, 0.2, 1320, 0.03), 0.2, 0.6)           # the pop
    t = 0.3
    while t < 0.72:                                            # clips settling in the tin
        add(out, tick(rnd, rnd.uniform(2600, 4200), 0.008, 0.04, 0.3), t, rnd.uniform(0.15, 0.4) * (1.1 - t))
        t += rnd.uniform(0.012, 0.05)
    return fit(out, 0.8)


def wheel_click() -> list[float]:
    rnd = rng("wheel_click")
    out = silence(0.12)
    add(out, tick(rnd, 1650, 0.012, 0.1, 0.8, 0.7, 210), 0.002)
    return fit(out, 0.12, 0.02)


def lever_pull() -> list[float]:
    rnd = rng("lever_pull")
    out = silence(0.5)
    add(out, lowpass(scrape(rnd, 0.34, 200, 1400, 0.8), 1600), 0.0, 0.6)  # linkage travel
    for k in range(4):
        add(out, tick(rnd, 1400, 0.006, 0.03, 0.4, 0.3, 160), 0.04 + k * 0.075, 0.25)
    add(out, thunk(rnd, 78, 0.07, 0.15), 0.35, 1.0)
    add(out, clank(rnd, 0.14, 330, 0.04), 0.35, 0.35)
    return fit(out, 0.5)


def lever_refuse() -> list[float]:
    """Sudden: the hard clank is the first thing heard, then two gauge needles flutter."""
    rnd = rng("lever_refuse")
    out = silence(0.5)
    add(out, clank(rnd, 0.4, 370, 0.08), 0.0, 1.0)
    add(out, thunk(rnd, 95, 0.05, 0.2), 0.0, 0.6)
    for at in (0.17, 0.29):
        m = int(0.07 * SR)
        fl = [math.sin(TAU * 2700 * j / SR) * (0.5 + 0.5 * math.sin(TAU * 38 * j / SR)) ** 2
              * math.exp(-j / (0.03 * SR)) for j in range(m)]
        add(out, fl, at, 0.22)
    return fit(out, 0.5)


def calibrate_ratchet() -> list[float]:
    rnd = rng("calibrate_ratchet")
    out = silence(1.0)
    for k in range(8):                                  # a clean, even run of eight
        add(out, tick(rnd, 2100, 0.008, 0.05, 0.6, 0.5, 240), 0.02 + k * 0.07, 0.8)
    add(out, thunk(rnd, 120, 0.05, 0.2), 0.58, 0.7)      # settled into place
    add(out, tick(rnd, 1700, 0.02, 0.1, 0.4), 0.58, 0.5)
    m = int(0.36 * SR)
    hum = lowpass(white(m, rnd), 400)
    whirr = [(0.4 * math.sin(TAU * 64 * j / SR) + 0.25 * math.sin(TAU * 192 * j / SR) + hum[j] * 0.8)
             * math.sin(math.pi * j / m) for j in range(m)]
    add(out, whirr, 0.63, 0.35)
    return fit(out, 1.0)


def hatch_open() -> list[float]:
    """Sudden: the hand-wheel grabbed and spun, the latch drops, the hinge groans, and then
    nothing: no water at all, only dry hollow air from below."""
    rnd = rng("hatch_open")
    out = silence(2.2)
    add(out, clank(rnd, 0.3, 300, 0.07), 0.0, 1.0)              # the wheel grabbed: honest attack
    t, gap = 0.08, 0.06
    while t < 0.6:                                                # the wheel spinning, accelerating
        add(out, tick(rnd, 1300, 0.01, 0.05, 0.5, 0.4, 150), t, 0.35)
        t += gap
        gap = max(0.022, gap * 0.88)
    add(out, lowpass(scrape(rnd, 0.5, 120, 900, 0.5), 900), 0.08, 0.3)
    add(out, clank(rnd, 0.3, 260, 0.08), 0.64, 0.75)              # the latch drops
    add(out, thunk(rnd, 70, 0.08, 0.3), 0.64, 0.6)
    m = int(1.0 * SR)                                             # the long low hinge groan
    phase, groan = 0.0, []
    for j in range(m):
        tt = j / SR
        f = 78 + 26 * math.sin(TAU * 0.7 * tt) + rnd.uniform(-5, 5)
        phase += TAU * f / SR
        stick = 0.6 + 0.4 * (math.sin(TAU * 17 * tt) > 0.3)       # stick-slip
        groan.append((math.sin(phase) + 0.5 * math.sin(2.02 * phase) + 0.3 * math.sin(3.05 * phase))
                     * stick * math.sin(math.pi * tt / 1.0) ** 0.8)
    add(out, lowpass(groan, 1100), 0.76, 0.45)
    m = int(0.75 * SR)                                            # the dry hollow tail: air, no water
    w = white(m, rnd)
    air = [a * 0.6 + b * 0.5 for a, b in zip(unit(lowpass(w, 500)), unit(resonator(w, 220, 16)))]
    add(out, [x * math.sin(math.pi * min(1.0, j / (0.25 * SR)) / 2) * math.exp(-max(0, j - 0.25 * SR) / (0.22 * SR))
              for j, x in enumerate(air)], 1.42, 0.14)
    return fit(out, 2.2, 0.08)


def plate_pick() -> list[float]:
    rnd = rng("plate_pick")
    out = silence(0.2)
    add(out, scrape(rnd, 0.12, 300, 1500, 0.5), 0.0, 0.5)
    add(out, tick(rnd, 3400, 0.01, 0.05, 0.3), 0.11, 0.5)
    return fit(out, 0.2, 0.03)


def plate_set() -> list[float]:
    rnd = rng("plate_set")
    out = silence(0.25)
    add(out, tick(rnd, 980, 0.012, 0.08, 0.7, 1.1, 230), 0.004, 1.0)
    add(out, thunk(rnd, 140, 0.03, 0.15), 0.004, 0.5)
    return fit(out, 0.25)


def record_key() -> list[float]:
    rnd = rng("record_key")
    out = silence(0.3)
    add(out, clank(rnd, 0.1, 760, 0.02), 0.004, 0.7)
    add(out, thunk(rnd, 130, 0.03, 0.12), 0.004, 0.6)
    m = int(0.15 * SR)
    spring = [math.sin(TAU * (690 + 40 * math.exp(-j / (0.02 * SR))) * j / SR) * math.exp(-j / (0.04 * SR)) for j in range(m)]
    add(out, spring, 0.12, 0.3)
    add(out, tick(rnd, 1500, 0.006, 0.03, 0.4), 0.12, 0.3)
    return fit(out, 0.3)


def record_refuse() -> list[float]:
    rnd = rng("record_refuse")
    out = silence(0.6)
    for k in range(3):
        add(out, typebar(rnd), 0.01 + k * 0.085)
    m = int(0.27 * SR)
    buzz = []
    for j in range(m):
        t = j / SR
        sq = 1.0 if math.sin(TAU * 110 * t) >= 0 else -1.0
        buzz.append(sq * min(1.0, j / (0.006 * SR)) * min(1.0, (m - j) / (0.02 * SR)))
    add(out, lowpass(lowpass(buzz, 1400), 2500), 0.29, 0.45)
    return fit(out, 0.6)


def relay_clack() -> list[float]:
    """Sudden: the armature slams over, bounces once, rings."""
    rnd = rng("relay_clack")
    out = silence(0.4)
    add(out, clank(rnd, 0.35, 1800, 0.06), 0.0, 1.0)
    add(out, clank(rnd, 0.3, 1860, 0.05), 0.034, 0.65)
    add(out, thunk(rnd, 200, 0.02, 0.1), 0.0, 0.4)
    return fit(out, 0.4)


def far_bell() -> list[float]:
    """A single distant bell answering from across water: base 392 Hz, inharmonic partials,
    heavily low-passed and echoed, with a long tail."""
    rnd = rng("far_bell")
    n = int(5.0 * SR)
    # (ratio, amp, decay s): hum, prime, minor third, fifth, nominal, then inharmonic upper partials
    parts = ((0.5, 0.5, 3.2), (1.0, 1.0, 2.6), (1.19, 0.55, 1.9), (1.51, 0.35, 1.5),
             (2.0, 0.45, 1.2), (2.74, 0.25, 0.8), (3.31, 0.15, 0.55))
    detune = [rnd.uniform(-0.6, 0.6) for _ in parts]
    xs = []
    for j in range(n):
        t = j / SR
        a = min(1.0, t / 0.012)           # distance blunts the strike
        xs.append(a * sum(amp * math.sin(TAU * (392 * r + d) * t) * math.exp(-t / tau)
                          for (r, amp, tau), d in zip(parts, detune)))
    xs = lowpass(lowpass(xs, 1100), 1400)
    xs = echo(xs, 0.37, 0.38, 5)
    xs = lowpass(xs, 1000)
    return fit(xs, 5.0, 0.6)


def _print_line(out: list[float], rnd: random.Random, start: float, strikes: int, rate: float) -> float:
    for k in range(strikes):
        add(out, typebar(rnd, rnd.uniform(0.75, 1.0)), start + k / rate)
    end = start + strikes / rate
    add(out, paper_advance(rnd, 0.18), end, 0.6)
    return end + 0.2


def strip_print() -> list[float]:
    rnd = rng("strip_print")
    out = silence(3.6)
    t = 0.02
    for strikes in (8, 9, 8):          # three lines at ~9 strikes per second
        t = _print_line(out, rnd, t, strikes, 9.0) + 0.06
    return fit(out, 3.6)


def strip_print_last() -> list[float]:
    rnd = rng("strip_print_last")
    out = silence(1.6)
    _print_line(out, rnd, 0.02, 7, 6.0)   # the fourth line, slower
    return fit(out, 1.6)


def tile() -> list[float]:
    rnd = rng("tile")
    n = int(0.2 * SR)
    xs = [(math.sin(TAU * 1380 * j / SR) + 0.5 * math.sin(TAU * 2310 * j / SR)) * math.exp(-j / (0.018 * SR))
          + 0.8 * math.sin(TAU * 240 * j / SR) * math.exp(-j / (0.015 * SR))
          + 0.5 * rnd.uniform(-1, 1) * math.exp(-j / (0.001 * SR)) for j in range(n)]
    return fit(lowpass(xs, 3000), 0.2, 0.03)  # felt under the paper damps it


def fix_pin() -> list[float]:
    rnd = rng("fix_pin")
    out = silence(0.4)
    m = int(0.2 * SR)
    pierce = band(white(m, rnd), 1200, 4500)
    add(out, [x * (j / m) ** 2 for j, x in enumerate(pierce)], 0.02, 0.5)   # pressing through
    add(out, tick(rnd, 1250, 0.012, 0.08, 0.6, 0.9, 190), 0.22, 1.0)          # seated
    add(out, thunk(rnd, 120, 0.03, 0.12), 0.22, 0.4)
    return fit(out, 0.4)


def plan_resolve() -> list[float]:
    """No attack: a slow low swell under paper drawn tight."""
    rnd = rng("plan_resolve")
    n = int(4.5 * SR)
    grains = [0.0] * n
    for j in range(n):
        if rnd.random() < 0.004:
            grains[j] = rnd.uniform(-1, 1)
    creak = unit(band(grains, 400, 2500))
    creak_env = smooth_walk(n, rnd, 0.35)
    out = []
    for j in range(n):
        t = j / SR
        e = (0.5 - 0.5 * math.cos(math.pi * t / 2.2)) if t < 2.2 else math.cos(math.pi / 2 * (t - 2.2) / 2.3) ** 2
        f = 55 + 3 * (t / 4.5)          # the sheet tightening
        v = (math.sin(TAU * f * t) + 0.9 * math.sin(TAU * 2 * f * t) + 0.35 * math.sin(TAU * 1.5 * f * t)
             + 0.6 * math.sin(TAU * 3 * f * t) + 0.35 * math.sin(TAU * 4 * f * t))
        out.append(v * e + creak[j] * 0.3 * creak_env[j] * e)
    return fit(out, 4.5, 0.1)


def name_print() -> list[float]:
    """Exactly 10 strikes at 0.16 s: A D A (space) M E R C E R, then a bell-less return."""
    rnd = rng("name_print")
    out = silence(1.9)
    for k, ch in enumerate("ADA MERCER"):
        at = 0.02 + k * 0.16
        if ch == " ":
            add(out, tick(rnd, 2600, 0.003, 0.02, 0.4), at, 0.25)   # the space: a carriage tick
        else:
            add(out, typebar(rnd), at)
    add(out, paper_advance(rnd, 0.3), 1.52, 0.7)                    # the return, no bell
    return fit(out, 1.9)


def glass_press() -> list[float]:
    """Sudden band-7 notice: the outer window taking load. A stress pop, then a low slow creak."""
    rnd = rng("glass_press")
    out = silence(1.2)
    add(out, thunk(rnd, 62, 0.12, 0.4), 0.0, 1.0)
    add(out, tick(rnd, 1900, 0.02, 0.1, 0.8), 0.0, 0.5)   # the glass itself, not breaking
    m = int(1.1 * SR)
    imp, t = [0.0] * m, 0.0
    while t < 1.05:
        imp[int(t * SR)] = 1.0
        t += 1 / (22 + 14 * math.sin(math.pi * t / 1.05)) * rnd.uniform(0.85, 1.15)  # slow stick-slip
    creak = [a * 0.7 + b * 0.5 for a, b in zip(resonator(imp, 140, 9), resonator(imp, 330, 12))]
    env = [math.sin(math.pi * j / m) for j in range(m)]
    add(out, [c * e for c, e in zip(unit(creak), env)], 0.1, 0.35)
    return fit(out, 1.2, 0.1)


LOOPS = (r03_room, r03_sea, r03_rain, r03_scratch, r03_drum, r03_pressure, r03_stair_air)
ONESHOTS = (turn, sheet_slide, sheet_rotate, cross_snap, clip_snap, clip_refuse, tin_open, wheel_click,
            lever_pull, lever_refuse, calibrate_ratchet, hatch_open, plate_pick, plate_set, record_key,
            record_refuse, relay_clack, far_bell, strip_print, strip_print_last, tile, fix_pin,
            plan_resolve, name_print, glass_press)


def main() -> None:
    out = room_out("R03")
    for fn in LOOPS + ONESHOTS:
        write(out, fn.__name__, fn())


if __name__ == "__main__":
    main()
