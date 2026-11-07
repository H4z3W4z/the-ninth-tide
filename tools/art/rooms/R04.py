#!/usr/bin/env python3
"""R04 Listening Room painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R04/*.png:

  view_a.png, view_a_turned.png          funnel wall plates (1448x1086 opaque)
  a_condensation, a_seat_rings, a_bulge, a_mounted, a_transcript   view A overlays (RGBA)
  a_tag5.png                             funnel 5's paper tag sprite (pivot 6,24)
  view_b.png                             channel board plate (opaque)
  b_motor_off, b_spool, b_mixer_aligned, b_condensation, b_speaker_wet, b_bulge   overlays
  b_lamp_lit, b_needle, b_key_open, b_key_closed                       sprites
  c_spindle, c_mixer, c_channels         close-up plates (opaque)
  c_band, c_needle_arm, c_lever_up, c_lever_down, c_lamp_lit, c_witness_down   sprites

Flat front elevation, approved palette, navy ink contours, matte colour and a low seeded
paper grain. No text, numerals, glyphs or waveforms except the one plain graphic the
contract asks for (b_mixer_aligned): every label field is a blank plate the view writes on.
Registration follows the R04 art task; the hotspots in R04_view.gd are fixed to it.

Python 3 + PIL only. Deterministic: each asset has its own random.Random(SEED + k), there is
no clock and no PIL noise effect, so a rerun is byte-identical.

    python3 tools/art/rooms/R04.py              # paint everything
    python3 tools/art/rooms/R04.py view_a b_*   # paint some (fnmatch patterns)
"""
import fnmatch
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "rooms", "R04")
W, H = 1448, 1086
SS = 2                      # supersampling for every painted shape
SEED = 1931_04_00

# ----------------------------------------------------------------------------- palette
INK = (23, 43, 54)          # #172B36 contours
PAPER = (216, 206, 181)     # #D8CEB5
PAPER_HI = (232, 225, 207)
ENAMEL = (226, 220, 202)    # blank label plates
SEAGLASS = (97, 125, 116)   # #617D74
SEAGLASS_HI = (150, 178, 166)
TIMBER = (103, 93, 81)      # #675D51 damp timber
TIMBER_DK = (78, 70, 61)
TIMBER_HI = (126, 115, 100)
SOOT = (41, 41, 41)         # #292929
AMBER = (195, 153, 89)      # #C39959
BRASS = (156, 126, 70)      # #9C7E46
BRASS_HI = (201, 168, 105)  # #C9A869
BRASS_LO = (116, 92, 50)
BRASS_DK = (84, 66, 36)
STORM = (34, 56, 74)        # #22384A
STORM_HI = (52, 80, 100)
VIOLET = (116, 101, 119)    # #746577
CORK = (164, 128, 90)
CORK_DK = (132, 100, 68)
CORK_HI = (184, 150, 110)
PLASTER = (214, 207, 188)
PLASTER_DK = (186, 177, 156)
PLASTER_HI = (232, 227, 212)
WAINSCOT = (40, 64, 82)
WAINSCOT_DK = (30, 50, 66)
POLISH = (168, 114, 74)     # the seat, polished by use
POLISH_HI = (204, 152, 106)
POLISH_DK = (138, 92, 58)
CABINET = (158, 120, 86)
CABINET_DK = (128, 96, 68)
CABINET_HI = (182, 146, 108)
PANEL = (44, 66, 84)        # enamelled instrument plates
PANEL_DK = (32, 50, 64)
IRON = (38, 46, 54)
GLASS_DK = (18, 30, 36)
THROAT = (14, 22, 28)
WAX = (204, 192, 166)
EBONY = (34, 32, 30)
FOG = (196, 220, 210)
BEAD = (236, 244, 240)
DUST = (238, 232, 216)

SEAT = (270, 700)
BELLS = {1: (300, 215), 2: (500, 205), 3: (700, 215), 4: (300, 370), 5: (500, 380), 6: (700, 370)}
BELL_R = 62
ROOTS = {1: (236, 140), 2: (500, 116), 3: (764, 140), 4: (236, 296), 6: (764, 296), 5: (500, 380)}
TAG5 = (548, 352)
CHANNELS = (505, 675, 845)


# ----------------------------------------------------------------------------- helpers

def rng_for(k):
    return random.Random(SEED + k)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c0, c1, t):
    return tuple(int(round(lerp(a, b, t))) for a, b in zip(c0, c1))


def rgba(c, a=255):
    return c if len(c) == 4 else (c[0], c[1], c[2], a)


def capsule(p0, p1, r0, r1, n=12):
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ang = math.atan2(dy, dx)
    pts = []
    for k in range(n + 1):
        t = ang - math.pi / 2 + math.pi * k / n
        pts.append((p1[0] + r1 * math.cos(t), p1[1] + r1 * math.sin(t)))
    for k in range(n + 1):
        t = ang + math.pi / 2 + math.pi * k / n
        pts.append((p0[0] + r0 * math.cos(t), p0[1] + r0 * math.sin(t)))
    return pts


def rot(p, c, deg):
    a = math.radians(deg)
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a))


class Pen:
    """Draws in 1x logical coordinates on a supersampled RGBA canvas."""

    def __init__(self, w, h, rng, bg=None):
        self.w, self.h, self.rng = w, h, rng
        self.im = Image.new("RGBA", (w * SS, h * SS), rgba(bg) if bg else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def iw(self, w):
        return max(1, int(round((w + self.rng.uniform(-0.4, 0.4)) * SS)))

    def _p(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def poly(self, pts, fill=None, ink=INK, w=3.0):
        p = self._p(pts)
        if fill is not None:
            self.d.polygon(p, fill=rgba(fill))
        if ink is not None and w:
            self.d.line(p + [p[0]], fill=rgba(ink), width=self.iw(w), joint="curve")

    def rect(self, x0, y0, x1, y1, fill=None, ink=INK, w=3.0, r=0):
        box = (x0 * SS, y0 * SS, x1 * SS, y1 * SS)
        width = self.iw(w) if (ink is not None and w) else 0
        self.d.rounded_rectangle(box, radius=r * SS, fill=rgba(fill) if fill is not None else None,
                                 outline=rgba(ink) if width else None, width=width)

    def ell(self, cx, cy, rx, ry=None, fill=None, ink=INK, w=3.0):
        ry = rx if ry is None else ry
        box = ((cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS)
        width = self.iw(w) if (ink is not None and w) else 0
        self.d.ellipse(box, fill=rgba(fill) if fill is not None else None,
                       outline=rgba(ink) if width else None, width=width)

    def oval(self, cx, cy, rx, ry, ang=0.0, fill=None, ink=INK, w=3.0, n=96):
        if abs(rx - ry) < 0.01:
            return self.ell(cx, cy, rx, ry, fill, ink, w)
        ca, sa = math.cos(ang), math.sin(ang)
        pts = []
        for i in range(n):
            t = 2 * math.pi * i / n
            x, y = rx * math.cos(t), ry * math.sin(t)
            pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
        self.poly(pts, fill, ink, w)

    def line(self, pts, col=INK, w=3.0):
        self.d.line(self._p(pts), fill=rgba(col), width=self.iw(w), joint="curve")

    def arc(self, cx, cy, rx, ry, a0, a1, col, w=3.0):
        box = ((cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS)
        self.d.arc(box, a0, a1, fill=rgba(col), width=self.iw(w))

    def layer(self):
        return Pen(self.w, self.h, self.rng)

    def put(self, other, opacity=1.0, mask=None):
        src = other.im
        if opacity < 1.0:
            a = src.getchannel("A").point(lambda v: int(v * opacity))
            src = src.copy()
            src.putalpha(a)
        if mask is not None:
            src = src.copy()
            src.putalpha(ImageChops.multiply(src.getchannel("A"), mask))
        self.im.alpha_composite(src)

    def done(self):
        return self.im.resize((self.w, self.h), Image.LANCZOS)


def value_noise(rng, w, h, cell):
    sw, sh = max(2, int(w / cell) + 2), max(2, int(h / cell) + 2)
    small = Image.frombytes("L", (sw, sh), rng.randbytes(sw * sh))
    return small.resize((w, h), Image.BICUBIC)


def grain(im, rng, amp=5, mottle=5, speck=10):
    """Low-amplitude seeded paper grain: fine noise, broad mottle and sparse specks."""
    w, h = im.size
    fine = Image.frombytes("L", (w, h), rng.randbytes(w * h))
    broad = value_noise(rng, w, h, 70)
    pos = ImageChops.add(fine.point(lambda v: max(0, v - 128) * amp // 128),
                         broad.point(lambda v: max(0, v - 128) * mottle // 128))
    neg = ImageChops.add(fine.point(lambda v: max(0, 127 - v) * amp // 128),
                         broad.point(lambda v: max(0, 127 - v) * mottle // 128))
    sp = Image.frombytes("L", (w, h), rng.randbytes(w * h))
    pos = ImageChops.add(pos, sp.point(lambda v: speck if v > 253 else 0))
    neg = ImageChops.add(neg, sp.point(lambda v: speck if v < 2 else 0))
    rgb = im.convert("RGB")
    rgb = ImageChops.add(rgb, Image.merge("RGB", [pos] * 3))
    rgb = ImageChops.subtract(rgb, Image.merge("RGB", [neg] * 3))
    if im.mode == "RGBA":
        rgb.putalpha(im.getchannel("A"))
    return rgb


def save(im, name, opaque):
    os.makedirs(OUT, exist_ok=True)
    if opaque:
        im = im.convert("RGB")
    else:
        im = im.convert("RGBA")
        # Zero the colour of fully transparent pixels so files stay small and stable.
        a = im.getchannel("A")
        clear = a.point(lambda v: 255 if v == 0 else 0)
        im.paste((0, 0, 0, 0), mask=clear)
    path = os.path.join(OUT, name + ".png")
    im.save(path, optimize=False, compress_level=9)
    print("  wrote", os.path.relpath(path, ROOT), im.size, im.mode)


# ----------------------------------------------------------------------------- shared room parts

def room_shell(p, rng, plaster_ceiling=False):
    """Ceiling band, cork wall panels, dado rail, navy wainscot and floor."""
    if plaster_ceiling:
        p.rect(-4, -4, W + 4, 118, PLASTER, None)
        lay = p.layer()
        for k in range(7):  # faint trowel sweeps
            x = rng.uniform(0, W)
            y = rng.uniform(20, 96)
            lay.arc(x, y, rng.uniform(80, 160), rng.uniform(14, 22), 205, 335, PLASTER_DK, 4)
        p.put(lay, 0.4)
        p.rect(-4, 112, W + 4, 130, STORM, INK, 3)
        p.line([(-4, 124), (W + 4, 124)], STORM_HI, 2)
        top = 130
    else:
        p.rect(-4, -4, W + 4, 66, STORM, None)
        p.line([(-4, 52), (W + 4, 52)], STORM_HI, 2)
        p.rect(-4, 60, W + 4, 74, STORM, INK, 3)
        top = 74
    # cork wall
    p.rect(-4, top, W + 4, 578, CORK, None)
    seams = [-4] + [int(i * 181 + rng.uniform(-4, 4)) for i in range(1, 8)] + [W + 4]
    for x in seams[1:-1]:
        p.line([(x, top), (x, 578)], CORK_DK, 2.5)
        p.line([(x + 2, top), (x + 2, 578)], CORK_HI, 1.2)
    for _ in range(2600):  # cork crumbs
        x, y = rng.uniform(0, W), rng.uniform(top + 2, 576)
        r = rng.choice((1.0, 1.2, 1.5, 2.0, 2.4))
        c = CORK_DK if rng.random() < 0.62 else CORK_HI
        p.ell(x, y, r, r * rng.uniform(0.6, 1.0), c, None)
    # dado rail
    p.rect(-4, 572, W + 4, 598, TIMBER, INK, 3)
    p.line([(-4, 580), (W + 4, 580)], TIMBER_HI, 2)
    # wainscot boards
    p.rect(-4, 598, W + 4, 912, WAINSCOT, None)
    for x in range(36, W, 52):
        p.line([(x, 600), (x, 908)], WAINSCOT_DK, 3)
        p.line([(x + 3, 600), (x + 3, 908)], STORM_HI, 1.2)
    p.rect(-4, 888, W + 4, 912, STORM, INK, 3)  # skirting
    # floor planks
    p.rect(-4, 910, W + 4, H + 4, TIMBER, INK, 3)
    y = 910
    k = 0
    while y < H:
        hgt = 40 + k * 6
        p.line([(-4, y + hgt), (W + 4, y + hgt)], TIMBER_DK, 2.5)
        off = rng.uniform(0, 300)
        x = off
        while x < W:
            p.line([(x, y + 3), (x, y + hgt - 3)], TIMBER_DK, 2)
            x += rng.uniform(320, 520)
        p.line([(-4, y + 3), (W + 4, y + 3)], TIMBER_HI, 1.2)
        y += hgt
        k += 1


def door_opening(p, x0, x1, side):
    """A dark doorway on a room edge; side 'right' or 'left' says where the room is."""
    p.rect(x0, 232, x1, 912, SEAGLASS, INK, 3.5)
    if side == "right":
        ox0, ox1 = x0 + 20, W + 6
    else:
        ox0, ox1 = -6, x1 - 20
    p.rect(ox0, 252, ox1, 914, (16, 24, 30), INK, 3)
    # the far room's floor and a dim brass glint: depth without perspective
    p.rect(ox0, 880, ox1, 914, (34, 40, 44), INK, 2)
    gx = (ox0 + ox1) / 2
    p.rect(gx - 18, 700, gx + 18, 708, (78, 66, 42), None)


def bolt(p, x, y, r=4):
    p.ell(x, y, r, r, BRASS_HI, INK, 1.5)


def bezel(p, x0, y0, x1, y1, r=8, m=6):
    """Brass frame round an instrument plate: separates it from the damp timber."""
    p.rect(x0 - m, y0 - m, x1 + m, y1 + m, BRASS_HI, INK, 3, r=r + m // 2)


# ----------------------------------------------------------------------------- view A parts

def plaster_panel(p, rng):
    p.rect(78, 84, 922, 528, STORM, INK, 4)
    p.line([(84, 90), (916, 90)], STORM_HI, 2)
    p.rect(90, 96, 910, 516, PLASTER, INK, 3)
    lay = p.layer()
    for _ in range(12):  # broad, faint trowel sweeps
        x, y = rng.uniform(130, 870), rng.uniform(120, 490)
        rx, ry = rng.uniform(60, 120), rng.uniform(14, 26)
        c = PLASTER_HI if rng.random() < 0.5 else PLASTER_DK
        lay.arc(x, y, rx, ry, rng.uniform(200, 220), rng.uniform(320, 340), c, 5)
    p.put(lay, 0.45)
    # two old hairline cracks at the corners, far from the pipe roots
    for start in ((92, 470), (906, 120)):
        x, y = start
        pts = [(x, y)]
        for _ in range(5):
            x += rng.uniform(10, 22) * (1 if start[0] < 400 else -1)
            y += rng.uniform(-10, 12)
            pts.append((x, y))
        p.line(pts, mix(INK, PLASTER, 0.45), 1.6)
    p.line([(92, 514), (908, 514)], PLASTER_DK, 3)  # bottom shadow lip


def neck_and_collar(p, c, root, r):
    ang = math.atan2(root[1] - c[1], root[0] - c[0])
    start = (c[0] + math.cos(ang) * r * 0.45, c[1] + math.sin(ang) * r * 0.45)
    # wall flange where the pipe vanishes into the plaster
    p.ell(root[0], root[1], 17, 17, BRASS_LO, INK, 3)
    p.ell(root[0], root[1], 11, 11, BRASS_DK, None)
    for k in range(3):
        a = ang + math.pi + (k - 1) * 1.6
        bolt(p, root[0] + math.cos(a) * 14, root[1] + math.sin(a) * 14, 2.6)
    p.poly(capsule(start, root, 19, 10), BRASS, INK, 3)
    nx, ny = -math.sin(ang), math.cos(ang)
    hi0 = (start[0] + nx * 9, start[1] + ny * 9)
    hi1 = (root[0] + nx * 4, root[1] + ny * 4)
    p.line([hi0, hi1], BRASS_HI, 3)
    # band where the neck meets the pipe
    mid = (lerp(start[0], root[0], 0.72), lerp(start[1], root[1], 0.72))
    p.line([(mid[0] - nx * 13, mid[1] - ny * 13), (mid[0] + nx * 13, mid[1] + ny * 13)], INK, 2.5)


def bell(p, c, look=(0.0, 0.0), r=BELL_R, plate=True):
    """A face-on ear-trumpet bell. A non-zero look turns its mouth: the throat slides toward
    the look direction and the rim foreshortens along it, so the bell visibly faces somewhere."""
    cx, cy = c
    lm = math.hypot(*look)
    ang = math.atan2(look[1], look[0]) if lm else 0.0
    k = 1.0 - 0.16 * min(1.0, lm / 24.0)     # foreshortening along the look axis

    def ov(x, y, rr, fill=None, ink=None, w=0):
        p.oval(x, y, rr * k, rr, ang, fill, ink, w)
    if plate:  # blank enamel number tab hanging under the rim
        p.rect(cx - 17, cy + r - 6, cx + 17, cy + r + 18, ENAMEL, INK, 2.5, r=4)
    ov(cx, cy, r + 3, None, INK, 3.5)
    ov(cx, cy, r, BRASS, INK, 3.5)
    steps = 12
    for i in range(steps):
        t = i / (steps - 1)
        rr = lerp(r - 8, 13, t)
        col = mix(BRASS_LO, THROAT, t ** 1.1)
        ov(cx + look[0] * t, cy + look[1] * t, rr, col)
    ov(cx, cy, r - 8, None, INK, 2)
    ov(cx + look[0] * 0.45, cy + look[1] * 0.45, lerp(r - 8, 13, 0.45), None, mix(INK, BRASS_LO, 0.4), 1.5)
    ov(cx + look[0], cy + look[1], 13, THROAT, INK, 2.5)
    if lm:
        # the far inner wall catches light: a bright crescent opposite the throat
        ux, uy = -look[0] / lm, -look[1] / lm
        p.oval(cx + ux * (r - 22), cy + uy * (r - 22), 7 * k, 26, ang, BRASS_HI, None)
    else:
        p.arc(cx, cy, r - 4, r - 4, 195, 285, BRASS_HI, 3.5)
        p.arc(cx, cy, r - 4, r - 4, 20, 70, BRASS_DK, 2.5)


def reversed_bell(p, c, look=(0.0, 0.0), r=BELL_R):
    """Funnel 5: the bell sits flush on the plaster, the narrow end points at the viewer."""
    cx, cy = c
    p.rect(cx - 17, cy + r - 6, cx + 17, cy + r + 18, ENAMEL, INK, 2.5, r=4)
    p.ell(cx + 3, cy + 4, r + 8, r + 8, PLASTER_DK, None)          # the rim's shadow on plaster
    p.ell(cx, cy, r, r, BRASS_DK, INK, 3.5)
    steps = 12
    for i in range(steps):
        t = i / (steps - 1)
        rr = lerp(r - 5, 14, t)
        col = mix(BRASS_DK, BRASS_HI, t ** 0.9)
        p.ell(cx + look[0] * t, cy + look[1] * t, rr, rr, col, None)
    for t in (0.3, 0.62):
        rr = lerp(r - 5, 14, t)
        p.ell(cx + look[0] * t, cy + look[1] * t, rr, rr, None, mix(INK, BRASS_LO, 0.35), 1.6)
    p.ell(cx + look[0], cy + look[1], 15, 15, BRASS_HI, INK, 3)
    p.ell(cx + look[0], cy + look[1], 7, 7, THROAT, INK, 1.5)
    p.ell(TAG5[0], TAG5[1], 4.5, 4.5, BRASS_HI, INK, 2)           # eyelet for the tag string


def funnel_geometry(turned, rng):
    """Bell centres, roots and throat offsets; turned swings each bell toward the seat."""
    out = {}
    for n, c in BELLS.items():
        root = ROOTS[n]
        centre = c
        look = (0.0, 0.0)
        if turned:
            if n != 5:
                deg = 4.0 + rng.random() * 4.0
                cands = [rot(c, root, deg), rot(c, root, -deg)]
                centre = min(cands, key=lambda q: math.hypot(q[0] - SEAT[0], q[1] - SEAT[1]))
            dx, dy = SEAT[0] - centre[0], SEAT[1] - centre[1]
            d = math.hypot(dx, dy)
            look = (dx / d * 26, dy / d * 26)
        out[n] = (centre, root, look)
    return out


def funnels(p, geo):
    for n in (1, 2, 3, 4, 6):
        c, root, _ = geo[n]
        neck_and_collar(p, c, root, BELL_R)
    for n in (1, 2, 3, 4, 6):
        c, _, look = geo[n]
        bell(p, c, look)
    c, _, look = geo[5]
    reversed_bell(p, c, look)


def fog_and_beads(p, rng, c, look, r, n_beads, reversed_=False, fog_a=92, bead=(3.2, 6.0)):
    lay = p.layer()
    cx, cy = c
    rr = r - 9
    lay.ell(cx, cy, rr, rr, FOG + (fog_a,), None)
    lay.ell(cx + look[0] * 0.5, cy + look[1] * 0.5, rr * 0.55, rr * 0.55, FOG + (fog_a // 2,), None)
    p.put(lay)
    placed = []
    tries = 0
    while len(placed) < n_beads and tries < 400:
        tries += 1
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.25, 0.85) * rr
        x, y = cx + math.cos(a) * d, cy + math.sin(a) * d
        if reversed_ and math.hypot(x - cx - look[0], y - cy - look[1]) < 20:
            continue
        b = rng.uniform(*bead)
        if any(math.hypot(x - qx, y - qy) < b + qb + 4 for qx, qy, qb in placed):
            continue
        placed.append((x, y, b))
    for x, y, b in placed:
        p.ell(x, y + 1.2, b, b * 1.12, BEAD, INK, 1.3)
        p.ell(x - b * 0.3, y - b * 0.3, b * 0.32, b * 0.32, (255, 255, 255), None)


def seat(p):
    cx, cy = SEAT
    p.rect(226, 772, 314, 834, TIMBER, INK, 3, r=4)                 # wall bracket plate
    bolt(p, 236, 784)
    bolt(p, 304, 784)
    p.rect(260, 812, 280, 902, BRASS_LO, INK, 3)                   # single post
    p.line([(265, 816), (265, 898)], BRASS_HI, 2.5)
    p.rect(234, 896, 306, 912, BRASS_LO, INK, 3, r=3)              # foot
    p.ell(cx, cy, 100, 100, POLISH_DK, INK, 4)                     # the seat disc, folded up
    p.ell(cx, cy, 86, 86, POLISH, INK, 2)                          # its flat face
    grain_l = p.layer()
    rg = random.Random(SEED + 501)
    for k in range(-5, 6):
        y = cy + k * 15 + rg.uniform(-3, 3)
        pts = [(cx - 90 + i * 12, y + 4 * math.sin(i * 0.5 + k)) for i in range(16)]
        grain_l.line(pts, POLISH_DK + (255,), 1.6)
    disc = Image.new("L", p.im.size, 0)
    ImageDraw.Draw(disc).ellipse(((cx - 84) * SS, (cy - 84) * SS, (cx + 84) * SS, (cy + 84) * SS), fill=255)
    p.put(grain_l, 0.55, mask=disc)
    lay = p.layer()
    lay.ell(cx, cy + 8, 54, 46, POLISH_HI + (90,), None)            # worn smooth where people sat
    p.put(lay)
    p.arc(cx, cy, 93, 93, 200, 290, POLISH_HI, 5)                  # turned rim catching light
    p.arc(cx, cy, 93, 93, 20, 110, mix(POLISH_DK, INK, 0.3), 4)
    p.rect(240, 794, 300, 816, BRASS, INK, 3, r=5)                 # hinge knuckle
    p.line([(250, 805), (290, 805)], BRASS_DK, 2)


def cabinet(p):
    p.rect(906, 432, 1354, 446, TIMBER, INK, 3, r=2)                # gallery rail
    p.rect(914, 444, 1346, 600, STORM, INK, 3.5)                   # dark upstand behind the top
    p.line([(920, 452), (1340, 452)], STORM_HI, 2)
    p.rect(924, 618, 1336, 888, CABINET, INK, 4)
    for x0 in (944, 1136):
        p.rect(x0, 638, x0 + 180, 868, CABINET_DK, INK, 3)
        p.rect(x0 + 16, 654, x0 + 164, 852, CABINET, INK, 2.5)
        p.line([(x0 + 20, 658), (x0 + 160, 658)], CABINET_HI, 2)
    p.ell(1114, 754, 8, 8, BRASS_HI, INK, 2.5)
    p.ell(1146, 754, 8, 8, BRASS_HI, INK, 2.5)
    p.rect(912, 598, 1348, 622, CABINET_HI, INK, 4)                # top slab
    p.line([(916, 604), (1344, 604)], (222, 182, 132), 2)
    p.rect(918, 886, 1342, 902, CABINET_DK, INK, 3)                # plinth
    p.rect(930, 900, 972, 912, CABINET_DK, INK, 3)
    p.rect(1288, 900, 1330, 912, CABINET_DK, INK, 3)


SPINDLE_PARTS = [  # solids of the bare spindle (used to mask the transcript strip)
    (946, 562, 1219, 584), (956, 582, 1210, 600), (956, 486, 1002, 566),
    (1188, 500, 1214, 566), (998, 516, 1192, 538),
]


def spindle(p):
    p.rect(956, 582, 1210, 600, TIMBER_DK, INK, 3)                 # plinth on the cabinet
    p.rect(946, 562, 1219, 584, BRASS_LO, INK, 3.5, r=3)           # bed
    p.line([(952, 568), (1213, 568)], BRASS_HI, 2)
    p.rect(998, 516, 1192, 538, BRASS, INK, 3, r=9)                # bare mandrel
    p.line([(1004, 522), (1186, 522)], BRASS_HI, 3)
    p.line([(1004, 533), (1186, 533)], BRASS_DK, 2)
    p.rect(956, 486, 1002, 566, BRASS, INK, 3.5, r=4)              # left standard
    p.rect(962, 496, 996, 542, BRASS_HI, INK, 2.5, r=2)            # blank arrow field
    p.rect(966, 500, 992, 538, None, BRASS_LO, 1.5, r=1)
    bolt(p, 979, 554, 4)
    p.rect(1188, 500, 1214, 566, BRASS, INK, 3.5, r=4)             # right standard
    p.ell(1201, 527, 7, 7, BRASS_HI, INK, 2)
    bolt(p, 1201, 554, 3.5)


TRAY = (1232, 522, 1338, 590)
TRAY_BANDS = [(1240, (150, 128, 98)), (1272, (190, 172, 140)), (1304, (224, 210, 182))]  # C, A, B


def tray(p, bands=True):
    x0, y0, x1, y1 = TRAY
    p.rect(1242, 588, 1252, 600, TIMBER_DK, INK, 2)
    p.rect(1318, 588, 1328, 600, TIMBER_DK, INK, 2)
    p.rect(x0, y0, x1, y1, TIMBER, INK, 3.5, r=3)
    p.rect(x0 + 6, y0 + 6, x1 - 6, y1 - 6, SEAGLASS, INK, 2)
    p.line([(x0 + 9, y0 + 10), (x1 - 9, y0 + 10)], mix(SEAGLASS, INK, 0.3), 2)
    if bands:
        for bx, col in TRAY_BANDS:
            p.rect(bx, 532, bx + 26, 578, col, INK, 2.5, r=7)
            p.line([(bx + 6, 538), (bx + 6, 572)], mix(col, (255, 255, 255), 0.35), 2.5)
            p.line([(bx + 2, 540), (bx + 24, 540)], mix(col, BRASS_LO, 0.5), 1.5)
            p.line([(bx + 2, 570), (bx + 24, 570)], mix(col, BRASS_LO, 0.5), 1.5)
    p.rect(x0, 566, x1, y1, TIMBER, INK, 3, r=2)                   # front lip
    p.line([(x0 + 4, 571), (x1 - 4, 571)], TIMBER_HI, 1.6)


def printer(p):
    p.rect(1016, 296, 1030, 384, BRASS_LO, INK, 2.5)
    p.rect(1250, 296, 1264, 384, BRASS_LO, INK, 2.5)
    p.rect(1026, 262, 1254, 404, IRON, INK, 4, r=8)
    p.rect(1026, 262, 1254, 278, BRASS, INK, 3, r=4)
    p.line([(1032, 267), (1248, 267)], BRASS_HI, 2)
    p.rect(1062, 296, 1218, 348, (58, 70, 80), INK, 2.5, r=4)      # inspection glass
    p.line([(1070, 340), (1104, 304)], (92, 108, 118), 3)
    p.rect(1104, 358, 1176, 374, ENAMEL, INK, 2, r=2)              # blank maker's plate
    p.rect(1052, 384, 1228, 394, THROAT, INK, 2)                   # paper slot
    p.rect(1068, 390, 1212, 412, PAPER, INK, 2.5)                  # a short blank lip
    p.line([(1072, 396), (1208, 396)], PAPER_HI, 1.5)
    # blank roll on top
    p.ell(1048, 242, 10, 20, BRASS, INK, 2.5)
    p.ell(1232, 242, 10, 20, BRASS, INK, 2.5)
    p.rect(1050, 222, 1230, 262, PAPER, INK, 3, r=6)
    p.line([(1056, 230), (1224, 230)], PAPER_HI, 3)
    p.line([(1056, 254), (1224, 254)], PAPER_DK_LINE, 2)


PAPER_DK_LINE = (186, 175, 150)


def cable(p):
    pts = [(1238, 400), (1243, 440), (1246, 470), (1247, 530)]  # drops behind the tray
    p.line(pts, INK, 9)
    p.line(pts, (70, 62, 54), 5)
    for y in (446, 494):
        p.rect(1236, y - 4, 1256, y + 4, BRASS_LO, INK, 1.6, r=2)


def paint_view_a(rng, turned):
    p = Pen(W, H, rng, CORK)
    room_shell(p, rng)
    plaster_panel(p, rng)
    # Separate streams so view_a and view_a_turned match everywhere but the funnels.
    geo = funnel_geometry(turned, rng_for(1))
    p.rng = rng_for(21)
    funnels(p, geo)
    if turned:
        fog = rng_for(8)
        for n, (c, _, look) in geo.items():
            fog_and_beads(p, fog, c, look, BELL_R, 8, reversed_=(n == 5), fog_a=64, bead=(2.6, 4.4))
    p.rng = rng_for(9)
    seat(p)
    cabinet(p)
    spindle(p)
    cable(p)
    tray(p)
    printer(p)
    door_opening(p, 1340, W + 6, "right")
    return p, geo


# ----------------------------------------------------------------------------- view B parts

def speaker(p, rng):
    cx, cy, r = 725, 215, 100
    p.ell(cx, cy, 124, 124, STORM, INK, 3.5)                      # dark mounting baffle
    p.ell(cx, cy, 118, 118, None, STORM_HI, 2)
    for k in range(6):
        a = math.radians(30 + k * 60)
        bolt(p, cx + math.cos(a) * 113, cy + math.sin(a) * 113, 3.5)
    p.rect(684, 98, 766, 114, BRASS_LO, INK, 3, r=3)              # ceiling flange
    bolt(p, 694, 106, 3)
    bolt(p, 756, 106, 3)
    p.rect(705, 108, 745, 150, BRASS, INK, 3)                     # pipe down from the ceiling
    p.line([(712, 112), (712, 148)], BRASS_HI, 3)
    p.ell(cx, cy, r + 4, r + 4, None, INK, 4)
    p.ell(cx, cy, r, r, BRASS, INK, 4)
    for i in range(14):
        t = i / 13
        rr = lerp(r - 12, 18, t)
        p.ell(cx, cy, rr, rr, mix(BRASS_LO, THROAT, t ** 1.1), None)
    p.ell(cx, cy, r - 12, r - 12, None, INK, 2.5)
    p.ell(cx, cy, 52, 52, None, mix(INK, BRASS_LO, 0.4), 1.6)
    p.ell(cx, cy, 18, 18, THROAT, INK, 3)
    p.arc(cx, cy, r - 6, r - 6, 195, 285, BRASS_HI, 5)
    p.arc(cx, cy, r - 6, r - 6, 20, 75, BRASS_DK, 3)


def motor(p, down):
    x0, y0, x1, y1 = 220, 400, 390, 630
    bezel(p, x0 + 6, y0 + 6, x1 - 6, y1 - 6, r=6)
    p.rect(x0 + 6, y0 + 6, x1 - 6, y1 - 6, PANEL, INK, 3.5, r=6)
    for bx, by in ((236, 444), (374, 444), (236, 612), (374, 612)):
        bolt(p, bx, by, 4)
    p.rect(246, 414, 364, 434, ENAMEL, INK, 2.5, r=3)              # blank label plate
    p.rect(294, 444, 316, 618, THROAT, INK, 2.5, r=6)              # lever slot
    px, py = 305, 530
    hy = 448 if not down else 612
    p.rect(px - 9, min(py, hy), px + 9, max(py, hy), BRASS, INK, 3)
    p.line([(px - 4, min(py, hy) + 4), (px - 4, max(py, hy) - 4)], BRASS_HI, 2.5)
    p.rect(px - 30, hy - 15, px + 30, hy + 15, EBONY, INK, 3, r=12)  # handle
    p.line([(px - 22, hy - 8), (px + 18, hy - 8)], (80, 76, 70), 2)
    p.rect(px - 32, hy + (16 if not down else -22), px + 32, hy + (22 if not down else -16), BRASS_HI, INK, 2)
    p.ell(px, py, 17, 17, BRASS_HI, INK, 3)
    p.ell(px, py, 6, 6, BRASS_DK, INK, 1.5)


def lamp_unlit(p, cx, cy, r=26):
    p.ell(cx, cy, r + 5, r + 5, BRASS, INK, 3)
    p.ell(cx, cy, r, r, (52, 76, 72), INK, 2.5)
    p.ell(cx, cy, r * 0.62, r * 0.62, (44, 64, 62), None)
    p.arc(cx, cy, r - 6, r - 6, 200, 260, (130, 160, 150), 3)


def channel(p, c):
    bezel(p, c - 72, 384, c + 72, 650, r=6, m=5)
    p.rect(c - 72, 384, c + 72, 650, PANEL, INK, 3.5, r=6)
    p.rect(c - 56, 394, c + 56, 420, ENAMEL, INK, 2.5, r=3)        # blank cut-label plate
    lamp_unlit(p, c, 440)
    p.rect(c - 66, 466, c + 66, 554, BRASS, INK, 3, r=6)           # gauge bezel
    p.rect(c - 60, 470, c + 60, 550, ENAMEL, INK, 2)               # blank gauge face
    p.arc(c, 548, 50, 50, 205, 335, mix(ENAMEL, INK, 0.25), 2)     # plain arc, no ticks
    p.line([(c - 56, 476), (c - 20, 476)], (244, 240, 230), 2)
    p.ell(c, 548, 6, 6, THROAT, INK, 1.5)                          # needle pivot socket
    p.rect(c - 36, 566, c + 36, 636, BRASS, INK, 3, r=6)           # key escutcheon
    p.rect(c - 8, 576, c + 8, 626, THROAT, INK, 2, r=4)            # empty key slot
    bolt(p, c - 26, 576, 3)
    bolt(p, c + 26, 626, 3)


def witness_key(p, ox, oy, sc, pressed, frame=False):
    """Large brass push-key. (ox, oy) is the top-left of its box; sc scales from the 180x170 base."""
    def X(v):
        return ox + v * sc

    def Y(v):
        return oy + v * sc
    if frame:
        bezel(p, X(4), Y(4), X(176), Y(166), r=10, m=5)
    p.rect(X(4), Y(4), X(176), Y(166), PANEL, INK, 3.5, r=10 * sc)
    for bx, by in ((16, 16), (164, 16), (16, 154), (164, 154)):
        bolt(p, X(bx), Y(by), 4)
    p.rect(X(30), Y(136), X(150), Y(160), BRASS_HI, INK, 2.5, r=3)  # blank engraving plate
    p.rect(X(36), Y(141), X(144), Y(155), None, BRASS_LO, 1.2, r=2)
    cx, cy = X(90), Y(68)
    p.ell(cx, cy, 60 * sc, 60 * sc, BRASS_LO, INK, 3.5)             # collar
    p.ell(cx, cy, 52 * sc, 52 * sc, BRASS_DK, None)
    dy = 18 if pressed else 0
    if pressed:
        p.ell(cx, cy + dy * 0.5, 54 * sc, 54 * sc, THROAT, None)    # the shadow ring
    else:
        p.ell(cx, cy + 8 * sc, 48 * sc, 48 * sc, BRASS_DK, None)    # cap's skirt
    rcap = (44 if pressed else 48) * sc
    p.ell(cx, cy + dy, rcap, rcap, BRASS if pressed else BRASS_HI, INK, 4)
    p.ell(cx - 10 * sc, cy + dy - 12 * sc, rcap * 0.55, rcap * 0.42, mix(BRASS_HI, (255, 240, 200), 0.3 if not pressed else 0.0), None)
    p.ell(cx, cy + dy, rcap * 0.78, rcap * 0.78, None, mix(INK, BRASS, 0.4), 1.6)


def hub(p, cx, cy):
    p.ell(cx, cy, 46, 46, PANEL_DK, INK, 3)
    p.ell(cx, cy, 24, 24, BRASS, INK, 3)
    for k in range(3):
        a = math.radians(90 + k * 120)
        p.ell(cx + math.cos(a) * 13, cy - math.sin(a) * 13, 5, 5, PANEL_DK, INK, 1.2)
    p.ell(cx, cy, 6, 6, BRASS_HI, INK, 2)


def mixer(p):
    bezel(p, 420, 670, 1040, 870, r=10, m=5)
    p.rect(420, 670, 1040, 870, IRON, INK, 4, r=10)
    p.rect(430, 680, 1030, 860, None, BRASS_LO, 2.5, r=8)
    p.rect(462, 684, 998, 776, BRASS, INK, 3, r=6)                 # window bezel
    p.rect(470, 690, 990, 770, GLASS_DK, INK, 2)
    lay = p.layer()
    lay.poly([(520, 692), (560, 692), (520, 768), (480, 768)], (120, 150, 150, 46), None)
    p.put(lay)
    hub(p, 560, 820)
    hub(p, 900, 820)
    for bx in (660, 730, 800):  # fixed head block between the hubs
        pass
    p.rect(690, 798, 770, 842, PANEL, INK, 3, r=4)
    p.rect(708, 808, 752, 816, THROAT, None)


def board(p):
    p.rect(198, 878, 242, 912, TIMBER_DK, INK, 3)
    p.rect(1208, 878, 1252, 912, TIMBER_DK, INK, 3)
    p.rect(180, 340, 1270, 880, TIMBER, INK, 4.5)
    for y in range(392, 880, 58):  # planking
        p.line([(186, y), (1264, y)], TIMBER_DK, 2)
    p.rect(176, 334, 1274, 352, BRASS, INK, 3.5, r=3)              # brass top rail
    p.line([(182, 339), (1268, 339)], BRASS_HI, 2)
    p.rect(190, 360, 1260, 870, None, BRASS_LO, 3)                 # brass trim
    for bx, by in ((200, 370), (1250, 370), (200, 860), (1250, 860)):
        bolt(p, bx, by, 4)


def paint_view_b(rng):
    p = Pen(W, H, rng, CORK)
    room_shell(p, rng, plaster_ceiling=True)
    door_opening(p, -6, 110, "left")
    speaker(p, rng)
    board(p)
    motor(p, down=False)
    for c in CHANNELS:
        channel(p, c)
    witness_key(p, 960, 430, 1.0, pressed=False, frame=True)
    mixer(p)
    return p


# ----------------------------------------------------------------------------- overlays: view A

def cracks(p, rng, cx, cy, rx, ry, n, lo=30, hi=60):
    """Navy crack contours radiating 30-60 px from an elliptical edge."""
    for k in range(n):
        a = 2 * math.pi * (k + rng.uniform(-0.3, 0.3)) / n
        x, y = cx + math.cos(a) * rx * 0.95, cy + math.sin(a) * ry * 0.95
        length = rng.uniform(lo, hi)
        pts = [(x, y)]
        for s in range(4):
            aa = a + rng.uniform(-0.35, 0.35)
            x += math.cos(aa) * length / 4
            y += math.sin(aa) * length / 4
            pts.append((x, y))
        p.line(pts, INK, 2.8 - 0.0)
        if rng.random() < 0.5:  # a short fork
            fx, fy = pts[2]
            aa = a + rng.choice((-0.8, 0.8))
            p.line([(fx, fy), (fx + math.cos(aa) * 14, fy + math.sin(aa) * 14)], INK, 1.8)


def mound(p, cx, cy, rx, ry):
    """A flat, lighter plaster swelling: lit upper-left, shadowed lower-right, no gore."""
    lay = p.layer()
    lay.ell(cx + 5, cy + 7, rx + 4, ry + 4, PLASTER_DK + (170,), None)   # cast shadow
    p.put(lay)
    p.ell(cx, cy, rx, ry, PLASTER_HI, None)
    p.ell(cx - rx * 0.2, cy - ry * 0.24, rx * 0.6, ry * 0.52, (242, 238, 227), None)
    p.arc(cx, cy, rx - 3, ry - 3, 15, 165, PLASTER_DK, 5)
    p.arc(cx, cy, rx, ry, 10, 170, mix(INK, PLASTER_DK, 0.25), 2.4)      # contour on the shadow side


def clip_mask(size, keep_rects=(), holes=()):
    m = Image.new("L", size, 0 if keep_rects else 255)
    d = ImageDraw.Draw(m)
    for x0, y0, x1, y1 in keep_rects:
        d.rectangle((x0 * SS, y0 * SS, x1 * SS, y1 * SS), fill=255)
    for cx, cy, r in holes:
        d.ellipse(((cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS), fill=0)
    return m


def paint_a_condensation(rng):
    p = Pen(W, H, rng)
    for n, c in BELLS.items():
        fog_and_beads(p, rng, c, (0, 0), BELL_R, rng.randint(6, 10), reversed_=(n == 5))
    return p


def paint_a_seat_rings(rng):
    p = Pen(W, H, rng)
    cx, cy = SEAT[0], SEAT[1] + 20
    for k, r in enumerate((14, 28, 42, 56, 70)):
        pts = []
        ph = rng.uniform(0, 6.28)
        for i in range(73):
            a = 2 * math.pi * i / 72
            rr = r + 0.7 * math.sin(2 * a + ph)
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.98))
        p.line(pts, DUST, 4.2 - k * 0.25)
    # a faint drift of wax dust under the post
    lay = p.layer()
    lay.poly([(214, 912), (236, 900), (304, 900), (330, 912)], DUST + (190,), None)
    for _ in range(40):
        x, y = rng.uniform(220, 322), rng.uniform(902, 914)
        lay.ell(x, y, rng.uniform(1, 2.4), None, DUST + (220,), None)
    p.put(lay)
    return p


def paint_a_bulge(rng):
    p = Pen(W, H, rng)
    geo = funnel_geometry(True, rng_for(1))       # registered to view_a_turned
    sw = p.layer()
    for n in (1, 2, 3, 4, 6):
        rx, ry = ROOTS[n]
        mound(sw, rx, ry, 40, 34)
    # funnel 5 is flush to the wall: the plaster swells round its whole rim
    cx, cy = BELLS[5]
    mound(sw, cx, cy, 94, 94)
    for n in (1, 2, 3, 4, 6):
        rx, ry = ROOTS[n]
        cracks(sw, rng, rx, ry, 40, 34, rng.randint(6, 8))
    cracks(sw, rng, cx, cy, 94, 94, 10, 30, 55)
    bells = [(c[0], c[1], BELL_R + 5) for c, _, _ in geo.values()]
    plaster = clip_mask(p.im.size, [(92, 98, 908, 514)], bells)
    p.put(sw, mask=plaster)
    # the pipes stay in front of the swelling
    necks = p.layer()
    for n in (1, 2, 3, 4, 6):
        c, root, _ = geo[n]
        neck_and_collar(necks, c, root, BELL_R)
    near_roots = Image.new("L", p.im.size, 0)
    d = ImageDraw.Draw(near_roots)
    for n in (1, 2, 3, 4, 6):
        r = ROOTS[n]
        d.ellipse(((r[0] - 64) * SS, (r[1] - 64) * SS, (r[0] + 64) * SS, (r[1] + 64) * SS), fill=255)
    p.put(necks, mask=ImageChops.multiply(near_roots, clip_mask(p.im.size, (), bells)))
    return p


MOUNT_WAX = (190, 166, 124)
MOUNT_BANDS = [(1006, 1058), (1068, 1120), (1130, 1182)]


def paint_a_mounted(rng):
    p = Pen(W, H, rng)
    for x0, x1 in MOUNT_BANDS:
        p.rect(x0, 496, x1, 558, MOUNT_WAX, INK, 3, r=6)
        p.rect(x0 + 2, 498, x1 - 2, 506, mix(MOUNT_WAX, INK, 0.25), None)
        p.rect(x0 + 2, 544, x1 - 2, 556, mix(MOUNT_WAX, INK, 0.3), None)
        p.line([(x0 + 4, 512), (x1 - 4, 512)], (236, 222, 190), 3.5)
        p.rect(x0, 496, x1, 558, None, INK, 3, r=6)
        p.rect(x0 - 2, 494, x0 + 5, 560, BRASS, INK, 2, r=2)
        p.rect(x1 - 5, 494, x1 + 2, 560, BRASS, INK, 2, r=2)
    # needle arm resting up at the right end
    p.ell(1201, 494, 9, 9, BRASS_HI, INK, 2.5)
    p.poly(capsule((1201, 494), (1146, 484), 6, 4), BRASS, INK, 2.5)
    p.rect(1132, 478, 1152, 492, EBONY, INK, 2, r=3)
    p.line([(1140, 492), (1140, 500)], INK, 2)
    # emptied felt tray
    x0, y0, x1, y1 = TRAY
    p.rect(x0 + 6, y0 + 6, x1 - 6, 566, SEAGLASS, INK, 2)
    p.line([(x0 + 9, y0 + 10), (x1 - 9, y0 + 10)], mix(SEAGLASS, INK, 0.3), 2)
    for bx, _ in TRAY_BANDS:  # pressed felt where each band stood
        p.rect(bx + 2, 556, bx + 24, 566, mix(SEAGLASS, INK, 0.22), None)
    return p


def paint_a_transcript(rng):
    p = Pen(W, H, rng)
    x0, x1 = 1100, 1176
    pts_l = [(x0, 396), (x0 + 1, 470), (x0 - 2, 530), (x0 + 6, 552)]
    pts_r = [(x1, 396), (x1 + 2, 470), (x1 + 6, 528), (x1 + 2, 548)]
    poly = pts_l + list(reversed(pts_r))
    p.poly(poly, PAPER, INK, 2.5)
    p.poly([(x0 + 6, 552), (x1 + 2, 548), (x1 - 4, 560), (x0 + 12, 560)], PAPER_DK_LINE, INK, 2)  # curl
    y = 412
    while y < 540:
        x = x0 + 10
        while x < x1 - 12:
            wlen = rng.uniform(8, 22)
            wlen = min(wlen, x1 - 10 - x)
            p.line([(x, y), (x + wlen, y)], (120, 120, 116), 3)
            x += wlen + rng.uniform(4, 7)
        y += 11
    # the strip hangs on the wall behind the spindle: mask out the mechanism and bands
    m = Image.new("L", p.im.size, 255)
    md = ImageDraw.Draw(m)
    for bx0, by0, bx1, by1 in SPINDLE_PARTS:
        md.rectangle((bx0 * SS, by0 * SS, bx1 * SS, by1 * SS), fill=0)
    for bx0, bx1 in MOUNT_BANDS:
        md.rectangle(((bx0 - 3) * SS, 492 * SS, (bx1 + 3) * SS, 562 * SS), fill=0)
    p.im.putalpha(ImageChops.multiply(p.im.getchannel("A"), m))
    return p


def paint_a_tag5(rng):
    p = Pen(96, 48, rng)
    p.line([(6, 24), (14, 22), (22, 24)], INK, 2)
    p.ell(6, 24, 3, 3, BRASS_HI, INK, 1.2)
    p.poly([(18, 14), (26, 8), (90, 8), (90, 40), (26, 40), (18, 34)], PAPER_HI, INK, 2.5)
    p.ell(26, 24, 3.5, 3.5, (0, 0, 0, 0), INK, 1.5)
    p.line([(32, 12), (86, 12)], (244, 240, 230), 1.5)
    return p


# ----------------------------------------------------------------------------- overlays: view B

def paint_b_motor_off(rng):
    p = Pen(W, H, rng)
    lay = p.layer()
    motor(lay, down=True)
    p.put(lay, mask=clip_mask(p.im.size, [(220, 400, 390, 630)]))
    return p


def paint_lamp_lit(rng, size, r):
    p = Pen(size, size, rng)
    c = size / 2
    lay = p.layer()
    for k in range(6):
        rr = c - 1 - k * (c - r - 4) / 6
        lay.ell(c, c, rr, rr, AMBER + (22 + k * 10,), None)
    p.put(lay)
    p.ell(c, c, r + 5, r + 5, BRASS_HI, INK, 3)
    p.ell(c, c, r, r, AMBER, INK, 2.5)
    p.ell(c, c, r * 0.68, r * 0.68, (230, 196, 128), None)
    # filament: a bright zigzag between two posts, a shape the unlit glass never shows
    s = r / 26.0
    p.line([(c - 13 * s, c + 2 * s), (c - 13 * s, c + 16 * s)], INK, 2)   # support posts
    p.line([(c + 13 * s, c + 2 * s), (c + 13 * s, c + 16 * s)], INK, 2)
    lay = p.layer()
    lay.ell(c, c + 1 * s, 15 * s, 8 * s, (255, 250, 226, 150), None)       # hot core glow
    p.put(lay)
    for i in range(5):                                                     # coiled filament
        x = c - 10 * s + i * 5 * s
        p.ell(x, c + 1 * s, 3.4 * s, 5 * s, None, (255, 250, 230), 2.2 * s)
    p.line([(c - 13 * s, c + 2 * s), (c + 13 * s, c + 2 * s)], (255, 246, 214), 1.4)
    p.arc(c, c, r - 5, r - 5, 200, 260, (255, 236, 196), 3)
    return p


def paint_b_needle(rng):
    p = Pen(10, 76, rng)
    p.poly([(3.2, 70), (6.8, 70), (5.4, 2), (4.6, 2)], (16, 16, 18), INK, 0.8)
    p.ell(5, 72, 3.8, 3.8, BRASS_HI, INK, 1.2)
    return p


def paint_key(rng, up):
    p = Pen(110, 90, rng)
    p.rect(19, 11, 91, 81, BRASS, INK, 2.5, r=6)
    p.rect(47, 21, 63, 71, THROAT, INK, 1.5, r=4)
    if up:
        px, py, ky = 55, 52, 12
        p.rect(6, 66, 104, 87, ENAMEL, INK, 2.2, r=3)
    else:
        px, py, ky = 55, 38, 78
        p.rect(6, 3, 104, 24, ENAMEL, INK, 2.2, r=3)
    p.rect(px - 5, min(py, ky), px + 5, max(py, ky), BRASS_HI, INK, 2)
    p.rect(px - 16, ky - 8, px + 16, ky + 8, EBONY, INK, 2.2, r=7)
    p.line([(px - 10, ky - 3), (px + 8, ky - 3)], (86, 80, 72), 1.6)
    p.ell(px, py, 8, 8, BRASS_HI, INK, 2)
    return p


def paint_b_spool(rng):
    p = Pen(W, H, rng)
    for cx in (560, 900):
        p.ell(cx, 820, 44, 44, (30, 28, 30), INK, 3)
        for rr in (36, 30, 24):
            p.ell(cx, 820, rr, rr, None, (56, 52, 52), 1.4)
        p.arc(cx, 820, 40, 40, 200, 250, (92, 88, 86), 2.5)
        p.ell(cx, 820, 15, 15, BRASS, INK, 2.5)
        p.ell(cx, 820, 5, 5, BRASS_HI, INK, 1.5)
    # tape threaded under the head block between the reels
    p.line([(560, 864), (690, 846), (770, 846), (900, 864)], (30, 28, 30), 5)
    p.line([(560, 864), (690, 846), (770, 846), (900, 864)], INK, 1.2)
    p.rect(532, 780, 588, 798, PAPER_HI, INK, 2, r=2)              # blank paper label
    return p


def paint_b_mixer_aligned(rng):
    p = Pen(W, H, rng)
    gx = 730
    for y in range(692, 770, 8):
        p.line([(gx, y), (gx, y + 4)], AMBER, 2)
    trace = (176, 214, 198)
    for base, top in ((718, 696), (756, 734)):
        pts = []
        x = 474
        while x <= 986:
            if abs(x - gx) < 12:
                pts.append((gx - 10, base))
                pts.append((gx, top))
                pts.append((gx + 10, base))
                x = gx + 14
                continue
            pts.append((x, base + rng.uniform(-2.5, 2.5)))
            x += 6
        p.line(pts, trace, 2.4)
    p.line([(472, 737), (988, 737)], (60, 84, 86), 1.5)             # lane divider
    return p


def paint_b_condensation(rng):
    p = Pen(W, H, rng)
    cx, cy, r = 725, 215, 100
    lay = p.layer()
    lay.ell(cx, cy, r - 12, r - 12, FOG + (115,), None)
    lay.ell(cx, cy, 52, 52, FOG + (60,), None)
    p.put(lay)
    placed = []
    tries = 0
    while len(placed) < 14 and tries < 600:
        tries += 1
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(26, 82)
        x, y = cx + math.cos(a) * d, cy + math.sin(a) * d
        b = rng.uniform(4, 7.5)
        if any(math.hypot(x - qx, y - qy) < b + qb + 5 for qx, qy, qb in placed):
            continue
        placed.append((x, y, b))
    for x, y, b in placed:
        p.ell(x, y + 1.5, b, b * 1.12, BEAD, INK, 1.4)
        p.ell(x - b * 0.3, y - b * 0.3, b * 0.32, b * 0.32, (255, 255, 255), None)
    return p


def paint_b_speaker_wet(rng):
    p = Pen(W, H, rng)
    cx, cy, r = 725, 215, 100
    wet = (40, 74, 68)
    p.ell(cx, cy, r - 8, r - 8, None, wet, 9)
    p.ell(cx, cy, r - 13, r - 13, None, INK, 1.5)
    p.arc(cx, cy, r - 8, r - 8, 200, 250, (210, 232, 222), 3)
    p.arc(cx, cy, r - 8, r - 8, 70, 110, (36, 60, 56), 6)
    for (dx, dy, s) in ((725, 312, 1.9), (742, 309, 1.5)):
        pts = []
        for i in range(37):
            t = i / 36 * 2 * math.pi   # teardrop: point on the rim, round belly below
            pts.append((dx + 7 * s * math.sin(t) * math.sin(t / 2), dy + 16 * s * (1 - math.cos(t)) / 2))
        p.poly(pts, (66, 108, 98), INK, 2.2)
        p.ell(dx - 2 * s, dy + 9 * s, 2 * s, 2 * s, (220, 238, 230), None)
    # a small wet stain on the board's top rail below
    p.ell(725, 344, 34, 8, (52, 70, 62), INK, 2)
    p.ell(716, 342, 12, 3, (160, 190, 178), None)
    return p


def paint_b_bulge(rng):
    p = Pen(W, H, rng)
    cx, cy = 725, 112
    sw = p.layer()
    mound(sw, cx, cy, 78, 26)          # pushes down through the cornice round the pipe
    cracks(sw, rng, cx, cy, 78, 26, 9, 30, 50)
    p.put(sw, mask=clip_mask(p.im.size, [(0, 82, W, 131)]))
    # redraw the flange and pipe so the swelling sits behind them
    p.rect(684, 98, 766, 114, BRASS_LO, INK, 3, r=3)
    bolt(p, 694, 106, 3)
    bolt(p, 756, 106, 3)
    p.rect(705, 113, 745, 131, BRASS, INK, 3)
    p.line([(712, 116), (712, 131)], BRASS_HI, 3)
    p.im.putalpha(ImageChops.multiply(p.im.getchannel("A"), clip_mask(p.im.size, [(0, 82, W, 131)])))
    return p


# ----------------------------------------------------------------------------- close-ups

def timber_board(p, rng, top=0):
    p.rect(-4, top - 4, W + 4, H + 4, TIMBER, None)
    y = top
    while y < H:
        y += rng.randint(64, 96)
        p.line([(-4, y), (W + 4, y)], TIMBER_DK, 2.5)
        p.line([(-4, y + 3), (W + 4, y + 3)], TIMBER_HI, 1.2)
    for _ in range(60):  # long grain streaks
        x, y = rng.uniform(0, W), rng.uniform(top, H)
        p.line([(x, y), (x + rng.uniform(80, 260), y + rng.uniform(-2, 2))], mix(TIMBER, TIMBER_DK, 0.6), 1.4)


def paint_c_spindle(rng):
    p = Pen(W, H, rng, CORK)
    p.rect(-4, -4, W + 4, 352, CORK, None)
    for _ in range(1500):
        x, y = rng.uniform(0, W), rng.uniform(0, 350)
        r = rng.choice((1.2, 1.6, 2.2, 2.8))
        p.ell(x, y, r, r * 0.8, CORK_DK if rng.random() < 0.62 else CORK_HI, None)
    timber_board(p, rng, top=700)
    p.rect(-4, 690, W + 4, 712, CABINET_HI, INK, 3.5)
    # transcript card, pinned
    lay = p.layer()
    lay.rect(268, 120, 1250, 350, (60, 40, 20, 70), None)
    p.put(lay)
    p.rect(260, 110, 1240, 340, PAPER_HI, INK, 3)
    p.line([(270, 122), (1230, 122)], (244, 240, 230), 2)
    for x in (290, 1210):
        p.ell(x, 128, 9, 9, BRASS_HI, INK, 2.5)
    # spindle bed
    p.rect(190, 352, 1250, 612, BRASS_LO, INK, 4.5, r=8)
    p.line([(198, 362), (1242, 362)], BRASS_HI, 3)
    p.rect(200, 395, 250, 445, BRASS_HI, INK, 3, r=3)              # blank arrow field
    p.rect(206, 401, 244, 439, None, BRASS_LO, 1.6, r=2)
    p.rect(204, 470, 1250, 494, BRASS, INK, 3, r=11)               # mandrel along the bed
    for x0 in (260, 590, 920):
        p.rect(x0, 370, x0 + 320, 590, (44, 44, 42), INK, 3.5, r=6)
        p.rect(x0 + 10, 380, x0 + 310, 580, (52, 54, 50), None, r=4)
        p.rect(x0 - 2, 470, x0 + 322, 494, BRASS, INK, 3, r=11)
        p.line([(x0 + 4, 476), (x0 + 316, 476)], BRASS_HI, 3)
        for sx in (x0 + 6, x0 + 296):  # seating saddles
            p.poly([(sx, 446), (sx + 18, 446), (sx + 18, 518), (sx, 518)], BRASS, INK, 2.5)
            p.line([(sx + 4, 452), (sx + 4, 512)], BRASS_HI, 2)
        cx = x0 + 160
        for bx in (cx - 58, cx + 58):  # blank turn buttons
            p.ell(bx, 645, 32, 32, BRASS, INK, 3.5)
            p.ell(bx, 645, 22, 22, BRASS_HI, INK, 1.6)
            p.ell(bx - 6, 637, 8, 6, (236, 214, 160), None)
    p.rect(196, 612, 1244, 690, TIMBER_DK, INK, 3.5)               # apron behind buttons
    for x0 in (260, 590, 920):
        cx = x0 + 160
        for bx in (cx - 58, cx + 58):
            p.ell(bx, 645, 32, 32, BRASS, INK, 3.5)
            p.ell(bx, 645, 22, 22, BRASS_HI, INK, 1.6)
            p.ell(bx - 6, 637, 8, 6, (236, 214, 160), None)
    # needle-arm lever
    p.rect(1340, 582, 1432, 606, BRASS_LO, INK, 3, r=3)
    p.rect(1384, 400, 1416, 590, BRASS, INK, 3.5, r=4)
    p.line([(1391, 410), (1391, 584)], BRASS_HI, 3)
    p.rect(1300, 520, 1388, 536, BRASS, INK, 3, r=4)
    p.rect(1262, 506, 1308, 550, EBONY, INK, 3, r=12)              # finger lift
    p.line([(1270, 516), (1300, 516)], (86, 80, 72), 2)
    p.ell(1400, 400, 22, 22, BRASS_HI, INK, 3.5)
    p.ell(1400, 400, 8, 8, BRASS_DK, INK, 2)
    # felt tray with three compartments
    p.rect(280, 724, 1170, 926, TIMBER, INK, 4, r=6)
    for x0, x1 in ((300, 550), (600, 850), (900, 1150)):
        p.rect(x0, 740, x1, 910, SEAGLASS, INK, 3, r=4)
        p.line([(x0 + 6, 750), (x1 - 6, 750)], mix(SEAGLASS, INK, 0.3), 3)
        p.line([(x0 + 6, 900), (x1 - 6, 900)], SEAGLASS_HI, 2)
    return p


def paint_c_band(rng):
    p = Pen(320, 220, rng)
    p.rect(14, 10, 306, 210, WAX, INK, 3.5, r=10)
    lay = p.layer()  # rounded shading along the band's curve (top and bottom roll away)
    for k in range(10):
        a = 120 - k * 11
        lay.rect(16, 12 + k * 4, 304, 14 + k * 4, (70, 56, 40, a // 3), None)
        lay.rect(16, 206 - k * 4, 304, 208 - k * 4, (70, 56, 40, a // 2), None)
    lay.rect(18, 60, 302, 72, (255, 250, 236, 90), None)
    p.put(lay)
    for x0, x1 in ((2, 30), (290, 318)):
        p.rect(x0, 4, x1, 216, BRASS, INK, 3, r=6)
        p.line([(x0 + 6, 12), (x0 + 6, 208)], BRASS_HI, 2.5)
        for ty in (60, 110, 160):  # three blank engraving ticks per edge
            p.line([(x0 + 9, ty), (x1 - 9, ty)], BRASS_DK, 2.5)
    return p


def paint_c_needle_arm(rng):
    p = Pen(260, 120, rng)
    p.poly(capsule((240, 20), (56, 46), 12, 7), BRASS, INK, 3)
    p.line([(232, 13), (60, 39)], BRASS_HI, 3)
    p.rect(20, 34, 70, 66, BRASS_LO, INK, 3, r=6)                  # reproducer head
    p.ell(45, 50, 10, 10, BRASS_HI, INK, 2)
    p.poly([(38, 66), (52, 66), (46, 102)], (24, 24, 26), INK, 2)  # stylus
    p.ell(46, 104, 2.5, 2.5, (230, 230, 225), INK, 1)
    p.ell(240, 20, 17, 17, BRASS_HI, INK, 3)
    p.ell(240, 20, 6, 6, BRASS_DK, INK, 1.5)
    return p


def paint_c_mixer(rng):
    p = Pen(W, H, rng, TIMBER)
    timber_board(p, rng)
    p.rect(150, 100, 1300, 590, IRON, INK, 4, r=12)
    p.rect(186, 126, 1264, 574, BRASS, INK, 4, r=8)
    p.line([(194, 133), (1256, 133)], BRASS_HI, 3)
    p.rect(200, 140, 1250, 560, GLASS_DK, INK, 3)
    for y0, y1 in ((180, 340), (370, 530)):
        p.rect(210, y0, 1240, y1, (26, 42, 48), mix(INK, GLASS_DK, 0.2), 2)
    p.line([(723, 146), (723, 554)], (8, 14, 18), 4)               # engraved centre guide
    p.line([(727, 146), (727, 554)], (96, 124, 118), 2)
    lay = p.layer()
    lay.poly([(300, 142), (380, 142), (250, 558), (170, 558)], (150, 180, 176, 26), None)
    p.put(lay)
    # slider track with seven plain detent notches
    p.rect(380, 610, 1070, 700, BRASS, INK, 4, r=10)
    p.line([(390, 618), (1060, 618)], BRASS_HI, 3)
    p.rect(404, 648, 1046, 662, THROAT, INK, 2, r=6)
    for i in range(7):
        x = 412 + i * 104.5
        p.rect(x - 3, 626, x + 3, 642, BRASS_DK, INK, 1.2)
        p.rect(x - 3, 668, x + 3, 684, BRASS_DK, INK, 1.2)
    # step buttons
    for x0 in (240, 1090):
        p.rect(x0, 600, x0 + 120, 710, IRON, INK, 3.5, r=10)
        p.ell(x0 + 60, 655, 42, 42, BRASS, INK, 3.5)
        p.ell(x0 + 60, 655, 32, 32, BRASS_HI, INK, 1.6)
        p.ell(x0 + 50, 644, 12, 9, (236, 214, 160), None)
    # toggle keys with blank plates
    for x0 in (260, 540):
        p.rect(x0, 770, x0 + 240, 900, PANEL, INK, 3.5, r=8)
        p.rect(x0 + 20, 860, x0 + 220, 890, ENAMEL, INK, 2.5, r=3)
        cx = x0 + 120
        p.ell(cx, 812, 32, 32, BRASS_LO, INK, 3)
        p.ell(cx, 812, 12, 12, BRASS_DK, INK, 2)
    # PLAY key
    p.rect(1010, 770, 1250, 900, PANEL, INK, 3.5, r=8)
    p.rect(1030, 784, 1230, 842, BRASS_HI, INK, 3.5, r=8)
    p.line([(1040, 792), (1220, 792)], (236, 214, 160), 2.5)
    p.rect(1040, 856, 1220, 888, ENAMEL, INK, 2.5, r=3)
    # session-log card holder
    p.rect(1270, 140, 1430, 560, BRASS, INK, 4, r=6)
    p.rect(1282, 160, 1418, 548, PAPER_HI, INK, 2.5)
    p.rect(1300, 146, 1400, 166, BRASS_HI, INK, 2.5, r=4)
    # clip for the contact-sheet scrap
    p.rect(830, 790, 970, 896, TIMBER_DK, INK, 3, r=4)
    p.rect(860, 772, 940, 808, IRON, INK, 3, r=6)
    p.line([(866, 780), (934, 780)], (80, 90, 100), 2)
    p.arc(900, 772, 22, 12, 180, 360, BRASS_HI, 3)
    return p


def lever(p, cx, cy, up):
    """Knife lever, pivot at (cx, cy); handle 120 px above or below."""
    hy = cy - 120 if up else cy + 120
    y0, y1 = min(cy, hy), max(cy, hy)
    p.rect(cx - 9, y0, cx + 9, y1, BRASS, INK, 3)
    p.line([(cx - 4, y0 + 6), (cx - 4, y1 - 6)], BRASS_HI, 3)
    p.rect(cx - 44, hy - 18, cx + 44, hy + 18, EBONY, INK, 3.5, r=16)
    p.line([(cx - 34, hy - 9), (cx + 26, hy - 9)], (86, 80, 72), 2.5)
    fy = hy + 22 if up else hy - 22
    p.rect(cx - 46, fy - 4, cx + 46, fy + 4, BRASS_HI, INK, 2)
    p.ell(cx, cy, 24, 24, BRASS_HI, INK, 3.5)
    p.ell(cx, cy, 9, 9, BRASS_DK, INK, 2)


def paint_c_channels(rng):
    p = Pen(W, H, rng, TIMBER)
    timber_board(p, rng)
    p.rect(-4, -4, W + 4, 26, BRASS, INK, 3)
    # MOTOR housing
    p.rect(150, 250, 340, 630, PANEL, INK, 4, r=10)
    p.rect(165, 260, 325, 300, ENAMEL, INK, 2.5, r=4)
    p.rect(233, 372, 257, 628 - 2, THROAT, INK, 2.5, r=8)
    for cx in (515, 745, 975):
        p.rect(cx - 95, 250, cx + 95, 630, PANEL, INK, 4, r=10)
        p.rect(cx - 80, 260, cx + 80, 300, ENAMEL, INK, 2.5, r=4)
        p.rect(cx - 12, 372, cx + 12, 626, THROAT, INK, 2.5, r=8)
        lamp_unlit(p, cx, 330, 26)
    for x0, x1 in ((150, 340), (420, 610), (650, 840), (880, 1070)):
        bolt(p, x0 + 14, 616, 4)
        bolt(p, x1 - 14, 616, 4)
    witness_key(p, 1120, 300, 220 / 180.0, pressed=False)
    # status tape window
    p.rect(1120, 580, 1340, 670, BRASS, INK, 3.5, r=6)
    p.rect(1132, 594, 1328, 656, GLASS_DK, INK, 2)
    p.rect(1132, 608, 1328, 642, PAPER, INK, 1.6)
    # procedure placard
    p.rect(150, 660, 1090, 780, PAPER_HI, INK, 3.5, r=4)
    p.rect(160, 670, 1080, 770, None, mix(INK, PAPER, 0.55), 1.5, r=2)
    for bx in (166, 1074):
        bolt(p, bx, 676, 5)
        bolt(p, bx, 764, 5)
    # three empty question-card slots
    for x0, x1 in ((150, 520), (540, 910), (930, 1300)):
        p.rect(x0, 820, x1, 940, BRASS, INK, 4, r=6)
        p.rect(x0 + 14, 834, x1 - 14, 926, (30, 38, 44), INK, 2.5, r=3)
        p.rect(x0 + 14, 834, x1 - 14, 846, (16, 22, 26), None)
        p.line([(x0 + 6, 826), (x1 - 6, 826)], BRASS_HI, 2.5)
    return p


def paint_c_lever(rng, up):
    p = Pen(150, 300, rng)
    lever(p, 75, 150, up)
    return p


def paint_c_witness_down(rng):
    p = Pen(220, 260, rng)
    witness_key(p, 0, 0, 220 / 180.0, pressed=True)
    return p


# ----------------------------------------------------------------------------- registry

def _view_a(rng):
    return paint_view_a(rng, False)[0]


def _view_a_turned(rng):
    return paint_view_a(rng, True)[0]


ASSETS = [  # name, seed index, painter, opaque, grain
    ("view_a", 0, _view_a, True, True),
    ("view_a_turned", 0, _view_a_turned, True, True),
    ("a_condensation", 2, paint_a_condensation, False, False),
    ("a_seat_rings", 3, paint_a_seat_rings, False, False),
    ("a_bulge", 4, paint_a_bulge, False, True),
    ("a_mounted", 5, paint_a_mounted, False, True),
    ("a_transcript", 6, paint_a_transcript, False, True),
    ("a_tag5", 7, paint_a_tag5, False, False),
    ("view_b", 10, paint_view_b, True, True),
    ("b_motor_off", 11, paint_b_motor_off, False, True),
    ("b_lamp_lit", 12, lambda r: paint_lamp_lit(r, 72, 26), False, False),
    ("b_needle", 13, paint_b_needle, False, False),
    ("b_key_open", 14, lambda r: paint_key(r, True), False, False),
    ("b_key_closed", 15, lambda r: paint_key(r, False), False, False),
    ("b_spool", 16, paint_b_spool, False, True),
    ("b_mixer_aligned", 17, paint_b_mixer_aligned, False, False),
    ("b_condensation", 18, paint_b_condensation, False, False),
    ("b_speaker_wet", 19, paint_b_speaker_wet, False, False),
    ("b_bulge", 20, paint_b_bulge, False, True),
    ("c_spindle", 30, paint_c_spindle, True, True),
    ("c_band", 31, paint_c_band, False, True),
    ("c_needle_arm", 32, paint_c_needle_arm, False, False),
    ("c_mixer", 33, paint_c_mixer, True, True),
    ("c_channels", 34, paint_c_channels, True, True),
    ("c_lever_up", 35, lambda r: paint_c_lever(r, True), False, False),
    ("c_lever_down", 36, lambda r: paint_c_lever(r, False), False, False),
    ("c_lamp_lit", 37, lambda r: paint_lamp_lit(r, 96, 30), False, False),
    ("c_witness_down", 38, paint_c_witness_down, False, False),
]


def main(argv):
    pats = argv or ["*"]
    for name, k, fn, opaque, gr in ASSETS:
        if not any(fnmatch.fnmatch(name, pat) for pat in pats):
            continue
        rng = rng_for(k)
        im = fn(rng).done()
        if gr:
            im = grain(im, rng_for(1000 + k))
        save(im, name, opaque)


if __name__ == "__main__":
    main(sys.argv[1:])
