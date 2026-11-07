#!/usr/bin/env python3
"""R02 Intake Office room sounds: seeded, standard-library synthesis.

    python3 tools/build_audio.py R02

Writes assets/audio/R02/<id>.wav for every id in the R02 sfx contract. Each sound
draws from its own fixed seed, random.Random(1931_0200 + k), with k the sound's
position in the contract (clock = 0 ... photo_turn = 20), so reruns are
byte-identical and changing one sound never moves another.

Loops: noise beds are built one crossfade longer and folded with common.seamless;
timed events (ticks, slaps, calls) are then placed with wrap-around at their exact
loop times, so the clock's tick sits on 0.0 s and the late wave's transient on 3.6 s
without the crossfade smearing them. Tones are chosen to complete whole cycles in
the loop (or are phase-corrected), so nothing clicks at the seam.

The shared office set (assets/audio/*.wav) is never touched here.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import *  # noqa: E402,F401,F403  SR, TAU, lowpass, band, seamless, echo, write, ...
import math  # noqa: E402
import random  # noqa: E402

out = room_out("R02")

# Contract order: the seed of a sound is 1931_0200 + its index here.
CONTRACT = (
    "clock", "rain_glass", "whistle", "late_wave", "pressure", "gulls", "kitchen_air",
    "turn", "lock_turn", "pin", "unpin", "thread", "stamp", "stamp_dry", "seal",
    "oilskin", "pen_far", "baro_tap", "paper_lift", "clock_stop", "photo_turn",
)


def rng(name: str) -> random.Random:
    return random.Random(1931_0200 + CONTRACT.index(name))


# ---------------------------------------------------------------------------
# small local helpers (room-owned; common.py stays read-only)
# ---------------------------------------------------------------------------
def silence(seconds: float) -> list[float]:
    return [0.0] * int(round(seconds * SR))


def add_at(buf: list[float], t0: float, sig: list[float], gain: float = 1.0, wrap: bool = True) -> None:
    """Mix sig into buf from t0 s; with wrap the overhang folds to the loop start."""
    n, s = len(buf), int(round(t0 * SR))
    for j, x in enumerate(sig):
        i = s + j
        if i >= n:
            if not wrap:
                break
            i %= n
        buf[i] += x * gain


def bed(seconds: float, make, fade_s: float = 1.0) -> list[float]:
    """A seamless noise bed exactly `seconds` long: make(n) builds n + fade samples."""
    n, f = int(round(seconds * SR)), int(round(fade_s * SR))
    xs = seamless(make(n + f), fade_s)
    assert len(xs) == n, (len(xs), n)
    return xs


def resonator(xs: list[float], fc: float, tau: float) -> list[float]:
    """Two-pole resonance at fc Hz ringing with time constant tau s (unity-ish gain)."""
    r = math.exp(-1.0 / (tau * SR))
    c1, c2 = 2 * r * math.cos(TAU * fc / SR), -r * r
    g = 1 - r
    y1 = y2 = 0.0
    res = []
    for x in xs:
        y = g * x + c1 * y1 + c2 * y2
        res.append(y)
        y2, y1 = y1, y
    return res


def fade_edges(xs: list[float], fin_s: float = 0.0005, fout_s: float = 0.02) -> list[float]:
    """Short ramp in and out so no one-shot starts or ends on a step."""
    n = len(xs)
    a, b = max(1, int(fin_s * SR)), max(1, int(fout_s * SR))
    res = list(xs)
    for i in range(min(a, n)):
        res[i] *= i / a
    for i in range(min(b, n)):
        res[n - 1 - i] *= i / b
    return res


def fit(xs: list[float], seconds: float, fout_s: float = 0.03) -> list[float]:
    """Pad or trim to exactly `seconds`, fading the end."""
    n = int(round(seconds * SR))
    xs = (xs + [0.0] * n)[:n]
    return fade_edges(xs, 0.0, fout_s)


def click(n_s: float, rnd: random.Random, tau: float) -> list[float]:
    """A noise transient n_s long with exponential decay tau."""
    return [rnd.uniform(-1, 1) * decay(j / SR, tau) for j in range(int(n_s * SR))]


def partials(seconds: float, parts, tau: float, attack: float = 0.0005) -> list[float]:
    """Sum of decaying sines: parts = ((Hz, amp), ...)."""
    out_ = []
    for j in range(int(seconds * SR)):
        t = j / SR
        v = sum(a * math.sin(TAU * f * t) for f, a in parts)
        out_.append(v * decay(t, tau) * min(1.0, t / attack))
    return out_


def periodic_walk(n: int, rnd: random.Random, knots: int) -> list[float]:
    """Smooth random curve in [0,1] that wraps: value and slope match at the seam."""
    ks = [rnd.random() for _ in range(knots)]
    step = n / knots
    res = []
    for i in range(n):
        k, f = divmod(i / step, 1.0)
        k = int(k)
        t = (1 - math.cos(math.pi * f)) / 2
        res.append(ks[k % knots] * (1 - t) + ks[(k + 1) % knots] * t)
    return res


# ---------------------------------------------------------------------------
# clock voices (shared by the clock loop and clock_stop)
# ---------------------------------------------------------------------------
CLOCK_CASE_HZ = 900.0      # wooden case resonance under the tick
TOCK_RATIO = 0.82          # the tock sits a little lower
CLICK_S = 0.004            # brass click transient
CASE_TAU = 0.060 / 3       # 60 ms audible ring (-26 dB at 60 ms)


def clock_beat(rnd: random.Random, ratio: float, level: float, cut_s: float | None = None) -> list[float]:
    """One dry escapement beat: a 4 ms brass click plus a 60 ms case resonance.
    cut_s stops the beat partway (the half tock that never finishes)."""
    n = int(0.09 * SR)
    burst = [rnd.uniform(-1, 1) * (1 - j / (CLICK_S * SR)) if j < CLICK_S * SR else 0.0 for j in range(n)]
    brass = highpass(burst, 2200)
    fc = CLOCK_CASE_HZ * ratio
    case = partials(0.09, ((fc, 1.0), (fc * 1.53, 0.35), (fc * 0.5, 0.25)), CASE_TAU)
    knock = resonator(burst, fc, CASE_TAU)
    xs = [(0.9 * b + 0.55 * c + 0.4 * k * 30) * level for b, c, k in zip(brass, case, knock)]
    if cut_s is not None:
        m = int(cut_s * SR)
        damp = int(0.004 * SR)          # stopped dead by a finger, not clipped
        xs = [x * (1.0 if j < m else max(0.0, 1 - (j - m) / damp) * 0.3) for j, x in enumerate(xs)]
    return xs


# ---------------------------------------------------------------------------
# loops
# ---------------------------------------------------------------------------
def clock() -> list[float]:
    """2.0 s: tick at 0.0, slightly lower tock at 1.0, inside a dead-quiet case."""
    rnd = rng("clock")
    xs = bed(2.0, lambda n: [x * 0.003 for x in lowpass(white(n, rnd), 600)], 0.5)
    add_at(xs, 0.0, clock_beat(rnd, 1.0, 1.0))
    add_at(xs, 1.0, clock_beat(rnd, TOCK_RATIO, 0.6))
    return xs


def rain_glass() -> list[float]:
    """8 s: sparse bright drop ticks (2-6 kHz) on panes over a soft hiss. No thunder."""
    rnd = rng("rain_glass")
    xs = bed(8.0, lambda n: [x * 0.05 for x in band(white(n, rnd), 1500, 6000)])
    t = rnd.uniform(0.0, 0.2)
    while t < 8.0:
        f = rnd.uniform(2000, 6000)
        amp = rnd.uniform(0.25, 1.0) ** 1.5
        drop = [rnd.uniform(-1, 1) * decay(j / SR, 0.0007) * 0.6
                + math.sin(TAU * f * j / SR) * decay(j / SR, 0.004) * min(1.0, j / 4)
                for j in range(int(0.03 * SR))]
        add_at(xs, t, band(drop, 1800, 7000), amp)
        t += rnd.expovariate(6.0) + 0.02          # ~5 ticks a second, never machine-regular
    return xs


def whistle() -> list[float]:
    """10 s: a thin 1.1-1.4 kHz whistle through fittings, slow seeded pitch walk,
    breathy band noise, swelling twice per loop."""
    rnd = rng("whistle")
    n = int(10.0 * SR)
    walk = periodic_walk(n, rnd, 5)
    freq = [1100 + 300 * w for w in walk]
    phase, ph = 0.0, []
    for f in freq:
        ph.append(phase)
        phase += TAU * f / SR
    resid = phase - TAU * round(phase / TAU)          # close the phase on a whole cycle
    ph = [p - resid * i / n for i, p in enumerate(ph)]
    air = bed(10.0, lambda m: band(white(m, rnd), 900, 1900))
    hiss = bed(10.0, lambda m: band(white(m, rnd), 300, 900))
    res = []
    for i in range(n):
        t = i / SR
        swell = math.sin(TAU * t / 10.0) ** 2           # two swells per 10 s, zero at the seam
        amp = 0.15 + 0.85 * swell
        tone = math.sin(ph[i]) + 0.12 * math.sin(2 * ph[i])
        res.append(tone * 0.22 * amp * amp + air[i] * 0.35 * amp + hiss[i] * 0.12 * (0.4 + 0.6 * swell))
    return res


LATE_WAVE_HIT = 3.6     # transient time; the view draws the crest at 3.0 s


def late_wave() -> list[float]:
    """7.0 s: one muffled wave slap against the outer wall, transient at 3.6 s,
    and nothing else. A short rise into the slap, a low wash after it."""
    rnd = rng("late_wave")
    xs = bed(7.0, lambda n: [0.0] * n)          # silent bed: the slap is the whole loop
    rise_s, wash_s = 0.30, 1.9
    # rising water just before the hit (part of the same slap)
    m = int(rise_s * SR)
    rise = lowpass(white(m, rnd), 500)
    rise = [x * (j / m) ** 2.5 * 0.5 for j, x in enumerate(rise)]
    add_at(xs, LATE_WAVE_HIT - rise_s, rise, wrap=False)
    # the slap: a dull body thump and a low-passed burst through the wall
    k = int(wash_s * SR)
    burst = lowpass(white(k, rnd), 700)
    body = lowpass(brown(k, rnd), 300)
    mid = band(white(k, rnd), 250, 800)         # the wash small speakers carry
    slap = []
    for j in range(k):
        t = j / SR
        onset = min(1.0, t / 0.003)
        v = (burst[j] * 1.6 * decay(t, 0.05)
             + math.sin(TAU * 78 * t) * 0.9 * decay(t, 0.07)
             + math.sin(TAU * 190 * t) * 0.45 * decay(t, 0.04)
             + mid[j] * 0.8 * decay(t, 0.35) * min(1.0, t / 0.01)
             + body[j] * 1.2 * decay(t, 0.55) * min(1.0, t / 0.06))
        slap.append(v * onset)
    slap = lowpass(slap, 1100)
    add_at(xs, LATE_WAVE_HIT, fade_edges(slap, 0.0, 0.4), wrap=False)
    return xs


def pressure() -> list[float]:
    """12 s: 38 Hz beating against 38.25 Hz (a 4 s throb, three per loop), a 76 Hz
    harmonic at -12 dB for small speakers, faint 152/228 Hz overtones that follow the
    throb (so a laptop speaker still carries it), and ear-pressure low-passed noise.
    Every tone completes whole cycles in 12 s, so the seam is exact."""
    rnd = rng("pressure")
    n = int(12.0 * SR)
    ear = bed(12.0, lambda m: lowpass(lowpass(brown(m, rnd), 160), 160))
    h = 10 ** (-12 / 20)
    res = []
    for i in range(n):
        t = i / SR
        sub = 0.5 * math.sin(TAU * 38.0 * t) + 0.5 * math.sin(TAU * 38.25 * t)
        # 152/228 Hz overtones, felt more than heard, so laptops still carry the throb
        upper = (10 ** (-18 / 20) * math.sin(TAU * 152.0 * t)
                 + 10 ** (-24 / 20) * math.sin(TAU * 228.0 * t)) * (0.5 + 0.5 * sub)
        res.append(sub + h * math.sin(TAU * 76.0 * t) + upper + 0.08 * ear[i])
    return res


def gull_call(rnd: random.Random) -> list[float]:
    """One distant gull: two or three FM chirps gliding 2.6 -> 1.8 kHz."""
    xs: list[float] = []
    for _ in range(rnd.choice((2, 3))):
        d = rnd.uniform(0.18, 0.30)
        f_hi, f_lo = rnd.uniform(2350, 2600), rnd.uniform(1800, 1950)
        vib = rnd.uniform(18, 26)
        m = int(d * SR)
        ph = 0.0
        for j in range(m):
            u = j / m
            f = f_hi + (f_lo - f_hi) * u ** 0.7 + 40 * math.sin(TAU * vib * j / SR)
            ph += TAU * f / SR
            env = math.sin(math.pi * min(1.0, u * 1.3)) ** 2 if u < 0.77 else 0.0
            xs.append((math.sin(ph) + 0.3 * math.sin(2 * ph)) * env)
        xs += silence(rnd.uniform(0.05, 0.12))
    return echo(lowpass(xs, 3200), 0.11, 0.25, 3)


def gulls() -> list[float]:
    """12 s ending A daylight: a calm low sea wash (two slow waves) and three
    distant gull calls at seeded times."""
    rnd = rng("gulls")
    n = int(12.0 * SR)
    body = bed(12.0, lambda m: lowpass(brown(m, rnd), 380))
    wash = bed(12.0, lambda m: band(white(m, rnd), 400, 1300))
    xs = []
    for i in range(n):
        t = i / SR
        swell = math.sin(math.pi * t / 6.0) ** 2           # periodic in 12 s
        xs.append(body[i] * (0.4 + 0.6 * swell) + wash[i] * 0.9 * swell)
    times = sorted(rnd.uniform(0.0, 11.0) for _ in range(3))
    for k in (1, 2):                                       # keep the three calls apart
        times[k] = max(times[k], times[k - 1] + 2.5)
    for t in times:
        add_at(xs, t % 12.0, gull_call(rnd), rnd.uniform(0.10, 0.16))
    return xs


KITCHEN_LID_AT = 5.3


def kitchen_air() -> list[float]:
    """9 s: a faint simmer through the service door (low bubbling bursts on a thin
    steam hiss) and one soft pot-lid tick. Written at a low peak: very quiet."""
    rnd = rng("kitchen_air")
    xs = bed(9.0, lambda m: [x * 0.04 for x in band(white(m, rnd), 500, 2500)])
    t = rnd.uniform(0.0, 0.1)
    while t < 9.0:
        d = rnd.uniform(0.02, 0.06)
        f0 = rnd.uniform(180, 420)
        m = int(d * SR)
        blob = lowpass(white(m, rnd), 700)
        bub = [(math.sin(TAU * (f0 + 900 * j / SR / d * 0.5) * j / SR) * 0.6 + blob[j])
               * math.sin(math.pi * j / m) ** 2 for j in range(m)]
        add_at(xs, t, bub, rnd.uniform(0.15, 0.45))
        t += rnd.expovariate(9.0) + 0.015
    lid = [c * 0.7 for c in click(0.002, rnd, 0.0006)]
    lid += [0.0] * int(0.2 * SR)
    ring = partials(0.2 + 0.002, ((2310, 1.0), (3720, 0.5), (5150, 0.2)), 0.03)
    lid = lowpass([a + 0.4 * b for a, b in zip(lid, ring)], 5000)
    add_at(xs, KITCHEN_LID_AT, lid, 0.5)
    return xs


# ---------------------------------------------------------------------------
# one-shots
# ---------------------------------------------------------------------------
def creak(rnd: random.Random, seconds: float, rate0: float, rate1: float, modes, jitter: float = 0.25) -> list[float]:
    """Stick-slip creak: an impulse train (rate0 -> rate1 Hz) through wood modes."""
    n = int(seconds * SR)
    pulses = [0.0] * n
    t = 0.0
    while t < seconds:
        i = int(t * SR)
        if i < n:
            pulses[i] = rnd.uniform(0.6, 1.0)
        u = t / seconds
        rate = rate0 + (rate1 - rate0) * u
        t += (1.0 / rate) * rnd.uniform(1 - jitter, 1 + jitter)
    res = [0.0] * n
    for fc, tau, g in modes:
        for i, y in enumerate(resonator(pulses, fc, tau)):
            res[i] += y * g
    return res


def turn() -> list[float]:
    """0.6 s: a floorboard creak under her weight shifting, and coat cloth."""
    rnd = rng("turn")
    n = int(0.6 * SR)
    ck = creak(rnd, 0.42, 55, 95, ((310, 0.012, 40), (720, 0.008, 22), (1180, 0.004, 10)))
    env = [math.sin(math.pi * j / len(ck)) ** 1.5 for j in range(len(ck))]
    xs = [0.0] * n
    add_at(xs, 0.06, [c * e for c, e in zip(ck, env)], 1.0, wrap=False)
    cloth = band(white(n, rnd), 700, 3200)
    sw = smooth_walk(n, rnd, 0.05)
    for i in range(n):
        u = i / n
        xs[i] += cloth[i] * 0.55 * math.sin(math.pi * u) ** 2 * (0.4 + 0.6 * sw[i])
    return fit(xs, 0.6, 0.05)


def brass_click(rnd: random.Random, ring_hz: float) -> list[float]:
    m = int(0.06 * SR)
    hit = click(0.003, rnd, 0.0008) + [0.0] * (m - int(0.003 * SR))
    ring = partials(0.06, ((ring_hz, 1.0), (ring_hz * 1.62, 0.5)), 0.012)
    return [a + 0.5 * b for a, b in zip(highpass(hit, 1500), ring)]


def lock_turn() -> list[float]:
    """0.9 s: brass key in the service-door lock, two ratchet clicks then a heavy
    bolt clack. Sudden (SFX_SOFT)."""
    rnd = rng("lock_turn")
    xs = silence(0.9)
    # the key working against the wards before the first click
    grind = band(white(int(0.12 * SR), rnd), 900, 3500)
    add_at(xs, 0.02, [g * 0.12 * math.sin(math.pi * j / len(grind)) for j, g in enumerate(grind)], wrap=False)
    add_at(xs, 0.12, brass_click(rnd, 2450), 0.55, wrap=False)
    add_at(xs, 0.30, brass_click(rnd, 2300), 0.6, wrap=False)
    m = int(0.35 * SR)
    burst = lowpass(click(0.008, rnd, 0.003) + [0.0] * (m - int(0.008 * SR)), 2500)
    body = partials(0.35, ((175, 1.0), (330, 0.7), (1240, 0.3)), 0.05, 0.0008)
    bolt = [1.2 * b + 0.9 * c for b, c in zip(burst, body)]
    add_at(xs, 0.52, bolt, 1.0, wrap=False)
    xs = echo(xs, 0.03, 0.22, 3)
    return fit(xs, 0.9, 0.08)


def pin() -> list[float]:
    """0.15 s: a brass pin pushed into cork. Dull: a tiny prick, then a soft thump."""
    rnd = rng("pin")
    n = int(0.15 * SR)
    prick = highpass(click(0.0015, rnd, 0.0005), 2500)
    xs = [0.0] * n
    add_at(xs, 0.0, [p * 0.25 for p in prick], wrap=False)
    cork = lowpass(click(0.03, rnd, 0.008), 1400)
    thump = partials(0.12, ((410, 1.0), (690, 0.4)), 0.015, 0.001)
    add_at(xs, 0.004, [c * 0.9 for c in cork], wrap=False)
    add_at(xs, 0.004, [t * 0.6 for t in thump], wrap=False)
    return fit(xs, 0.15, 0.02)


def unpin() -> list[float]:
    """0.18 s: a pin pulled out of cork, a short friction drag and a tiny squeak."""
    rnd = rng("unpin")
    n = int(0.18 * SR)
    xs = [0.0] * n
    d = int(0.07 * SR)
    drag = band(white(d, rnd), 800, 2800)
    add_at(xs, 0.0, [x * 0.6 * math.sin(math.pi * j / d) for j, x in enumerate(drag)], wrap=False)
    m = int(0.055 * SR)
    sq, ph = [], 0.0
    for j in range(m):
        u = j / m
        ph += TAU * (2200 + 700 * u) / SR
        sq.append(math.sin(ph) * math.sin(math.pi * u) ** 2 * 0.35)
    add_at(xs, 0.05, sq, wrap=False)
    add_at(xs, 0.105, [c * 0.4 for c in lowpass(click(0.01, rnd, 0.002), 2000)], wrap=False)
    return fit(xs, 0.18, 0.03)


def thread() -> list[float]:
    """0.3 s: red thread drawn through the fingers and pulled taut with a faint twang."""
    rnd = rng("thread")
    n = int(0.3 * SR)
    xs = [0.0] * n
    d = int(0.2 * SR)
    hiss = band(white(d, rnd), 2000, 5500)
    add_at(xs, 0.0, [x * 0.45 * (j / d) ** 1.5 for j, x in enumerate(hiss)], wrap=False)
    twang = partials(0.1, ((340, 1.0), (680, 0.5), (1020, 0.3), (1360, 0.15)), 0.025, 0.001)
    add_at(xs, 0.19, [x * 0.5 for x in twang], wrap=False)
    add_at(xs, 0.19, [c * 0.3 for c in highpass(click(0.002, rnd, 0.0006), 1500)], wrap=False)
    return fit(xs, 0.3, 0.03)


def stamp_voice(rnd: random.Random, inked: bool) -> list[float]:
    """A rubber stamp landing: a 110 Hz body thump, rubber contact, a wooden handle
    knock and, when inked, the tacky peel as it lifts."""
    dur = 0.35 if inked else 0.25
    n = int(dur * SR)
    xs = [0.0] * n
    tau = 0.05 if inked else 0.03
    body = partials(0.25, ((110, 1.0), (165, 0.5), (240, 0.3)), tau, 0.0015)
    add_at(xs, 0.0, body, 1.0, wrap=False)
    contact = lowpass(click(0.03, rnd, 0.006 if inked else 0.003), 900 if inked else 1500)
    add_at(xs, 0.0, contact, 0.9, wrap=False)
    knock = partials(0.08, ((640, 1.0), (1050, 0.6), (1580, 0.2)), 0.012, 0.0008)
    add_at(xs, 0.006, knock, 0.55 if inked else 0.45, wrap=False)
    if inked:
        m = int(0.05 * SR)
        peel = band(white(m, rnd), 400, 1800)
        add_at(xs, 0.13, [p * 0.25 * math.sin(math.pi * j / m) ** 3 for j, p in enumerate(peel)], wrap=False)
        add_at(xs, 0.175, [c * 0.18 for c in highpass(click(0.002, rnd, 0.0007), 1200)], wrap=False)
    return fit(xs, dur, 0.04)


def stamp() -> list[float]:
    """0.35 s: the P20 commit. Inked rubber thump, handle knock, a clean lift."""
    return stamp_voice(rng("stamp"), True)


def stamp_dry() -> list[float]:
    """0.25 s: the refused stamp. The same thump, inkless, drier, quieter."""
    return stamp_voice(rng("stamp_dry"), False)


def seal() -> list[float]:
    """0.7 s: Venn's wax seal cracking (a snap and crumbs), then a paper fold opening.
    Sudden (SFX_SOFT)."""
    rnd = rng("seal")
    xs = silence(0.7)
    add_at(xs, 0.01, band(click(0.006, rnd, 0.0015), 900, 6000), 1.0, wrap=False)
    add_at(xs, 0.01, partials(0.04, ((1350, 1.0), (2100, 0.4)), 0.006), 0.4, wrap=False)
    t = 0.025
    while t < 0.2:
        add_at(xs, t, band(click(0.003, rnd, 0.0007), 1500, 7000), rnd.uniform(0.15, 0.5), wrap=False)
        t += rnd.uniform(0.008, 0.03)
    s, e = 0.24, 0.66
    m = int((e - s) * SR)
    fold = band(white(m, rnd), 900, 4200)
    sw = smooth_walk(m, rnd, 0.04)
    add_at(xs, s, [f * 0.5 * math.sin(math.pi * j / m) ** 2 * (0.5 + 0.5 * w)
                   for j, (f, w) in enumerate(zip(fold, sw))], wrap=False)
    t = s + 0.03
    while t < e - 0.05:
        add_at(xs, t, band(click(0.004, rnd, 0.001), 1200, 5000), rnd.uniform(0.08, 0.2), wrap=False)
        t += rnd.uniform(0.03, 0.07)
    return fit(xs, 0.7, 0.05)


def oilskin() -> list[float]:
    """1.4 s: a wet, heavy oilskin settling on hook 7, then a slow creak of the hook
    and coat as if weight had stepped into it. Low and close, not loud."""
    rnd = rng("oilskin")
    xs = silence(1.4)
    m = int(0.4 * SR)
    slump = lowpass(white(m, rnd), 420)
    add_at(xs, 0.0, [x * 1.1 * min(1.0, j / (0.03 * SR)) * decay(j / SR, 0.11) for j, x in enumerate(slump)], wrap=False)
    wet = band(white(m, rnd), 500, 1700)
    add_at(xs, 0.02, [x * 0.3 * math.sin(math.pi * j / m) ** 2 for j, x in enumerate(wet)], wrap=False)
    ck = creak(rnd, 0.95, 18, 34, ((150, 0.02, 38), (430, 0.01, 22), (980, 0.005, 8)), 0.35)
    k = len(ck)
    env = [math.sin(math.pi * min(1.0, j / (0.85 * k))) ** 1.2 for j in range(k)]
    add_at(xs, 0.34, [c * e * 0.9 for c, e in zip(ck, env)], wrap=False)
    hook = partials(0.3, ((620, 1.0), (1530, 0.3)), 0.06, 0.004)
    add_at(xs, 0.36, hook, 0.08, wrap=False)
    return fit(lowpass(xs, 2400), 1.4, 0.12)


def pen_far() -> list[float]:
    """2.6 s: a nib scratching across paper somewhere else in the office; no pen in
    sight. Low-passed at 3 kHz, with a -6 dB room reverb (common.echo, fb 0.5)."""
    rnd = rng("pen_far")
    n = int(2.2 * SR)
    xs = [x * 0.08 for x in band(white(n, rnd), 1000, 2800)]
    for i in range(n):
        xs[i] *= math.sin(math.pi * i / n) ** 0.5
    t = 0.05
    while t < 2.1:
        length = rnd.uniform(0.03, 0.07)
        s, m = int(t * SR), int(length * SR)
        if s + m >= n:
            break
        burst = band(white(m, rnd), 1600, 4500)
        amp = rnd.uniform(0.5, 1.0)
        for j, x in enumerate(burst):
            xs[s + j] += x * amp * min(1.0, j / 40) * decay(j / SR, 0.014)
        t += 0.15 * rnd.uniform(0.6, 1.5)
    xs = echo(lowpass(xs, 3000), 0.047, 0.5, 5)
    return fit(xs, 2.6, 0.25)


def baro_tap() -> list[float]:
    """0.4 s: a fingernail tap on barometer glass, and the needle's tiny tick after."""
    rnd = rng("baro_tap")
    xs = silence(0.4)
    add_at(xs, 0.0, highpass(click(0.0015, rnd, 0.0004), 2000), 0.6, wrap=False)
    add_at(xs, 0.0, partials(0.25, ((1620, 1.0), (3140, 0.45), (4710, 0.2)), 0.035), 0.55, wrap=False)
    add_at(xs, 0.0, partials(0.12, ((380, 1.0),), 0.02, 0.001), 0.4, wrap=False)
    add_at(xs, 0.13, partials(0.03, ((5200, 1.0), (7300, 0.3)), 0.004), 0.18, wrap=False)
    add_at(xs, 0.13, highpass(click(0.0008, rnd, 0.0003), 3000), 0.15, wrap=False)
    return fit(xs, 0.4, 0.05)


def paper_lift() -> list[float]:
    """0.4 s: a duty card peeled off the paper beneath it and lifted clear."""
    rnd = rng("paper_lift")
    xs = silence(0.4)
    m = int(0.14 * SR)
    peel = band(white(m, rnd), 500, 2600)
    add_at(xs, 0.0, [p * 0.35 * (j / m) ** 2 for j, p in enumerate(peel)], wrap=False)
    add_at(xs, 0.14, band(click(0.004, rnd, 0.001), 800, 4000), 0.45, wrap=False)
    k = int(0.24 * SR)
    air = band(white(k, rnd), 900, 4000)
    add_at(xs, 0.15, [a * 0.3 * math.sin(math.pi * j / k) ** 2 for j, a in enumerate(air)], wrap=False)
    return fit(xs, 0.4, 0.04)


def clock_stop() -> list[float]:
    """2.2 s: the barometer-case clock's last tick, half a tock cut off as if a
    finger stopped the pendulum, then a faint spring sigh as the mainspring lets go."""
    rnd = rng("clock_stop")
    xs = silence(2.2)
    add_at(xs, 0.05, clock_beat(rnd, 1.0, 1.0), wrap=False)
    add_at(xs, 1.05, clock_beat(rnd, TOCK_RATIO, 0.6, cut_s=0.012), wrap=False)
    s = 1.35
    m = int((2.2 - s) * SR)
    sigh = band(white(m, rnd), 500, 2200)
    ph, sp = 0.0, []
    for j in range(m):
        u = j / m
        ph += TAU * (1480 - 520 * u) / SR
        env = math.sin(math.pi * min(1.0, u / 0.95)) ** 2
        sp.append((sigh[j] * 0.12 + math.sin(ph) * 0.05 + math.sin(2.37 * ph) * 0.02) * env)
    add_at(xs, s, sp, wrap=False)
    return fit(xs, 2.2, 0.1)


def photo_turn() -> list[float]:
    """0.3 s: a stiff photograph flipped over: an edge flick, the air, a flat landing."""
    rnd = rng("photo_turn")
    xs = silence(0.3)
    add_at(xs, 0.0, band(click(0.004, rnd, 0.001), 1000, 5000), 0.6, wrap=False)
    add_at(xs, 0.0, partials(0.04, ((880, 1.0),), 0.008, 0.001), 0.2, wrap=False)
    k = int(0.15 * SR)
    air = band(white(k, rnd), 600, 3000)
    add_at(xs, 0.03, [a * 0.25 * math.sin(math.pi * j / k) ** 2 for j, a in enumerate(air)], wrap=False)
    m = int(0.08 * SR)
    land = lowpass(click(0.02, rnd, 0.005), 1800) + [0.0] * (m - int(0.02 * SR))
    body = partials(0.08, ((260, 1.0), (520, 0.3)), 0.015, 0.001)
    add_at(xs, 0.19, [a * 0.8 + b * 0.4 for a, b in zip(land, body)], wrap=False)
    return fit(xs, 0.3, 0.03)


# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------
# Output peak per sound. Loops that should sit low in the mix are written low; the
# integrator's SFX_DB sets one-shot levels on top of these.
PEAK = {"kitchen_air": 0.30, "gulls": 0.70, "rain_glass": 0.70, "whistle": 0.60,
        "pen_far": 0.70, "oilskin": 0.75, "stamp_dry": 0.60, "late_wave": 0.80}


def main() -> None:
    for name in CONTRACT:
        write(out, name, globals()[name](), PEAK.get(name, 0.85))


main()
