#!/usr/bin/env python3
"""R06 Bunk Room painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R06/*.png:

  view_a, view_a_s2, view_a_s3, view_a_s4, view_a_sever
                      men's side (1448x1086 opaque): lockers BELL/ROOK/VENN/IVES open, four locked
                      staff lockers whose tops are the belongings shelf, two double bunks, luggage,
                      the fanlight. s1 = band 1, s2 = bands 2-3, s3 = 4-5, s4 = 6-7, sever.
  view_b, view_b_s2, view_b_s3, view_b_s4, view_b_sever
                      curtain wall: drawn curtain, the night-watch calendar, wall table with the
                      writing slope and pigeonhole, bunks LUSK/DOANE and TULL/BELL, Venn's pencil
                      shelf, Bell's cup shelf with its old dry ring.
  a_top_*, a_in_*, a_cup_mark, a_venn_open, a_dry_ring, a_steam, a_dent_*,
  a_fan_{b1..b7,sever}, a_fan_rain_*, a_fan_frame,
  b_dent_*, b_curtain_shape, b_pigeonhole_open          overlays (RGBA, registered to the plate)
  c_lockers, c_slope                                    close-up plates (opaque)
  c_cup, c_calipers, c_pencils, c_glove, c_plate_down, c_venn_open, c_token_rubbing,
  c_cup_mark, c_card, c_sketch, c_key_down              close-up sprites / overlays

Flat front elevation, approved palette, navy ink contours, broad matte fills, low seeded paper
grain. No text, numerals or glyphs: every name plate, card, tag and calendar cell is a blank
enamel or paper field the view writes on. Label fields are graded far less than the room, so
they stay pale at every stage (owner rule: wall mean L* >= 45, labels legible).

Python 3 + PIL only. Deterministic: each asset has its own random.Random(SEED + k), there is
no clock and no PIL noise effect, so a rerun is byte-identical.

    python3 tools/art/rooms/R06.py              # paint everything
    python3 tools/art/rooms/R06.py view_a* c_*  # paint some (fnmatch patterns)
"""
import fnmatch
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "rooms", "R06")
W, H = 1448, 1086
SS = 2
SEED = 1931_06_00

# ----------------------------------------------------------------------------- palette
INK = (23, 43, 54)
PAPER = (216, 206, 181)
PAPER_HI = (232, 225, 207)
ENAMEL = (226, 220, 202)
CARD = (236, 228, 206)
SEAGLASS = (97, 125, 116)
SEAGLASS_HI = (150, 178, 166)
TIMBER = (103, 93, 81)
TIMBER_DK = (78, 70, 61)
TIMBER_HI = (126, 115, 100)
SOOT = (41, 41, 41)
BRASS = (156, 126, 70)
BRASS_HI = (201, 168, 105)
BRASS_LO = (116, 92, 50)
STORM = (34, 56, 74)
STORM_HI = (52, 80, 100)
VIOLET = (116, 101, 119)
BLANKET = (88, 104, 98)
BLANKET_HI = (110, 126, 118)
BLANKET_DK = (68, 82, 78)
LOCKER = (74, 96, 90)
LOCKER_HI = (96, 120, 112)
LOCKER_DK = (58, 76, 72)
LOCK_IN = (34, 46, 50)          # the inside of an open locker
LEATHER = (110, 84, 62)
LEATHER_DK = (86, 64, 47)
LEATHER_HI = (132, 104, 80)
FRAME = (44, 76, 96)            # painted joinery: fanlight frame, dado cap (the approved navy-blue)
FRAME_HI = (64, 100, 122)
WAINS = (46, 74, 92)
WAINS_DK = (36, 60, 76)
CHINA = (230, 226, 214)
CHINA_DK = (196, 194, 184)
STEEL = (158, 164, 160)
STEEL_HI = (204, 208, 202)
STEEL_DK = (106, 114, 112)
TIN = (124, 130, 126)
TIN_DK = (96, 102, 100)
WORN = (214, 196, 150)          # tin rubbed to bright metal
WOOD = (204, 180, 140)          # sharpened pencil wood
GRAPHITE = (62, 66, 72)
RED = (164, 48, 44)             # restitching thread (red, never orange)
GLOVE = (140, 128, 106)
GLOVE_DK = (112, 100, 82)
GLOVE_HI = (164, 152, 128)
BAIZE = (62, 92, 78)
BAIZE_DK = (48, 72, 62)
BAIZE_HI = (80, 112, 96)
WALNUT = (96, 78, 62)
WALNUT_DK = (74, 60, 48)
WALNUT_HI = (120, 100, 80)
NIGHT = (10, 16, 24)            # near-black navy
GLASS = (128, 132, 134)
PALE = (238, 236, 226)

# stage tables: wall, floor, grade target, grade amount, vignette depth
STAGE = {
    1: dict(wall=(150, 176, 164), floor=(114, 104, 92), tgt=(40, 62, 82), amt=0.00, vig=0.10),
    2: dict(wall=(138, 165, 158), floor=(98, 90, 82), tgt=(40, 62, 82), amt=0.05, vig=0.12),
    3: dict(wall=(128, 155, 154), floor=(88, 82, 76), tgt=(34, 56, 74), amt=0.10, vig=0.14),
    4: dict(wall=(124, 150, 156), floor=(82, 78, 76), tgt=(34, 56, 74), amt=0.17, vig=0.14),
    0: dict(wall=(160, 172, 160), floor=(120, 110, 98), tgt=(206, 200, 186), amt=0.07, vig=0.06),
}

# geometry: view A
OPEN_X = {"bell": 48, "rook": 148, "venn": 248, "ives": 348}
SHUT_X = {"lusk": 448, "doane": 512, "hart": 576, "tull": 640}
FAN_OUT = (812, 136, 1248, 256)
FAN_GLASS = (828, 150, 1232, 242)
FAN_BARS = (909, 990, 1071, 1152)
SHELF_Y = 560
UP = dict(pillow=(418, 446), matt=(440, 480), rail=(480, 502))
LO = dict(pillow=(666, 694), matt=(690, 730), rail=(730, 752))

# geometry: view B
CURTAIN_FOLDS = (36, 112, 178, 244, 310, 374, 430, 476)


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


def bezier(p0, p1, p2, n=28):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return out


class Pen:
    """Draws in 1x logical coordinates on a supersampled RGBA canvas."""

    def __init__(self, w, h, rng, bg=None):
        self.w, self.h, self.rng = w, h, rng
        self.im = Image.new("RGBA", (w * SS, h * SS), rgba(bg) if bg else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def iw(self, w):
        return max(1, int(round((w + self.rng.uniform(-0.3, 0.3)) * SS)))

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
            src = src.copy()
            src.putalpha(src.getchannel("A").point(lambda v: int(v * opacity)))
        if mask is not None:
            src = src.copy()
            src.putalpha(ImageChops.multiply(src.getchannel("A"), mask))
        self.im.alpha_composite(src)

    def put_soft(self, other, radius, opacity=1.0, mask=None):
        other.im = other.im.filter(ImageFilter.GaussianBlur(radius * SS))
        self.put(other, opacity, mask)

    def done(self):
        return self.im.resize((self.w, self.h), Image.LANCZOS)


def value_noise(rng, w, h, cell):
    sw, sh = max(2, int(w / cell) + 2), max(2, int(h / cell) + 2)
    small = Image.frombytes("L", (sw, sh), rng.randbytes(sw * sh))
    return small.resize((w, h), Image.BICUBIC)


def grain(im, rng, amp=5, mottle=5, speck=10):
    """Low-amplitude seeded paper grain (as R04): fine noise, broad mottle, sparse specks."""
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
        clear = im.getchannel("A").point(lambda v: 255 if v == 0 else 0)
        im.paste((0, 0, 0, 0), mask=clear)
    path = os.path.join(OUT, name + ".png")
    im.save(path, optimize=False, compress_level=9)
    print("  wrote", os.path.relpath(path, ROOT), im.size, im.mode)


def rect_mask(rects, size=(W, H)):
    """L mask (supersampled) that keeps only the given logical rects."""
    m = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    d = ImageDraw.Draw(m)
    for x0, y0, x1, y1 in rects:
        d.rectangle((x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1), fill=255)
    return m


class Box:
    """Maps unit (u, v) into a logical box, optionally rotated about a pivot."""

    def __init__(self, x0, y0, x1, y1, deg=0.0, pivot=None):
        self.x0, self.y0, self.w, self.h = x0, y0, x1 - x0, y1 - y0
        self.deg = deg
        self.pivot = pivot or ((x0 + x1) / 2, y1)

    def __call__(self, u, v):
        x, y = self.x0 + u * self.w, self.y0 + v * self.h
        if self.deg:
            a = math.radians(self.deg)
            cx, cy = self.pivot
            dx, dy = x - cx, y - cy
            x, y = cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a)
        return (x, y)

    def pts(self, uvs):
        return [self(u, v) for u, v in uvs]

    def quad(self, u0, v0, u1, v1):
        return self.pts([(u0, v0), (u1, v0), (u1, v1), (u0, v1)])

    def s(self, k):
        """A length of k box-heights in logical px."""
        return k * self.h


# ----------------------------------------------------------------------------- stage grading

def graded(p, st, labels):
    """Flatten a plate Pen: colder grade + soft vignette per stage; label fields graded a
    third as much and no vignette, so they always read pale."""
    im = p.done().convert("RGB")
    cfg = STAGE[st]
    crops = [(r, im.crop(r)) for r in labels]
    if cfg["amt"]:
        im = Image.blend(im, Image.new("RGB", im.size, cfg["tgt"]), cfg["amt"])
    # vignette: a soft multiply, deepest in the lower corners
    small = Image.new("L", (W // 8, H // 8), 255)
    px = small.load()
    for y in range(small.size[1]):
        for x in range(small.size[0]):
            dx = (x * 8 - W / 2) / (W / 2)
            dy = (y * 8 - H * 0.35) / (H * 0.65)
            d = min(1.0, (dx * dx * 0.7 + max(0.0, dy) ** 2 * 0.9))
            px[x, y] = int(255 * (1 - cfg["vig"] * d))
    vig = small.resize((W, H), Image.BICUBIC)
    im = ImageChops.multiply(im, Image.merge("RGB", [vig] * 3))
    for r, c in crops:
        if cfg["amt"]:
            c = Image.blend(c, Image.new("RGB", c.size, cfg["tgt"]), cfg["amt"] * 0.3)
        im.paste(c, r[:2])
    return im


# ----------------------------------------------------------------------------- room shell

def shell(p, rng, st):
    cfg = STAGE[st]
    wall = cfg["wall"]
    # ceiling strip and timber beam
    p.rect(-4, -4, W + 4, 80, mix(STORM, wall, 0.12), None)
    p.line([(-4, 60), (W + 4, 60)], mix(STORM_HI, wall, 0.1), 2)
    p.rect(-4, 80, W + 4, 128, TIMBER_DK, INK, 3)
    p.line([(-4, 88), (W + 4, 88)], TIMBER_HI, 2)
    p.line([(-4, 118), (W + 4, 118)], mix(TIMBER_DK, INK, 0.3), 2)
    for x in range(40, W, 236):  # beam joints and pegs
        xx = x + rng.uniform(-14, 14)
        p.line([(xx, 82), (xx, 126)], mix(TIMBER_DK, INK, 0.4), 2)
        p.ell(xx + 12, 104, 3, 3, TIMBER_HI, INK, 1.2)
    # upper wall
    p.rect(-4, 128, W + 4, 620, wall, None)
    p.line([(-4, 131), (W + 4, 131)], mix(wall, INK, 0.25), 2)
    # wainscot planks, cap rail, skirting
    p.rect(-4, 620, W + 4, 896, WAINS, None)
    for x in range(30, W, 48):
        p.line([(x, 628), (x, 894)], WAINS_DK, 3)
        p.line([(x + 3, 628), (x + 3, 894)], mix(WAINS, STORM_HI, 0.8), 1.2)
    p.rect(-4, 614, W + 4, 628, FRAME, INK, 3)
    p.line([(-4, 618), (W + 4, 618)], FRAME_HI, 1.5)
    p.rect(-4, 896, W + 4, 908, mix(FRAME, INK, 0.3), INK, 3)
    # floorboards
    fl = cfg["floor"]
    p.rect(-4, 908, W + 4, H + 4, fl, INK, 3)
    y, k = 908, 0
    while y < H:
        hgt = 40 + k * 7
        p.line([(-4, y + hgt), (W + 4, y + hgt)], mix(fl, INK, 0.3), 2.5)
        x = rng.uniform(0, 300)
        while x < W:
            p.line([(x, y + 4), (x, y + hgt - 3)], mix(fl, INK, 0.25), 2)
            x += rng.uniform(320, 520)
        p.line([(-4, y + 3), (W + 4, y + 3)], mix(fl, PAPER, 0.15), 1.2)
        y += hgt
        k += 1


def _profile(rng, x0, x1, step=6):
    """A wavering edge: a list of (x, depth 0..1) every band reuses, so stains only grow.
    Seeded sines (no random walk), tapered to nothing at both ends."""
    ph = [rng.uniform(0, 6.28) for _ in range(3)]
    fr = [rng.uniform(0.010, 0.016), rng.uniform(0.028, 0.040), rng.uniform(0.07, 0.09)]
    out, x = [], x0
    while x <= x1:
        d = 0.62 + 0.22 * math.sin(fr[0] * x + ph[0]) + 0.12 * math.sin(fr[1] * x + ph[1]) \
            + 0.04 * math.sin(fr[2] * x + ph[2])
        e = min(1.0, (x - x0) / 70.0, (x1 - x) / 70.0)
        e = e * e * (3 - 2 * e)
        out.append((x, max(0.0, d * e)))
        x += step
    return out


def _run(rng, rx, base, end, wd):
    """One damp run: narrowing as it falls, ending in a blunt round stop."""
    pts = []
    n = 10
    for k in range(n + 1):
        t = k / n
        pts.append((rx - wd * (1 - 0.35 * t) + 1.2 * math.sin(k * 1.7 + rx), lerp(base, end, t)))
    r = wd * 0.65
    for k in range(1, 12):
        a = math.pi - math.pi * k / 12
        pts.append((rx + r * math.cos(a), end + r * 0.8 * math.sin(a)))
    for k in range(n, -1, -1):
        t = k / n
        pts.append((rx + wd * (1 - 0.35 * t) + 1.2 * math.sin(k * 2.3 + rx), lerp(base, end, t)))
    return pts


def damp(p, st, view):
    """The damp. A: a tide-mark spreading under the fanlight. B: along the ceiling beam.
    Band 4+ grows vertical runs that stop dead mid-wall. Sever: the same, dried pale."""
    if st == 1:
        return
    rng = rng_for(500 if view == "a" else 501)
    wall = STAGE[st]["wall"]
    if view == "a":
        x0, x1, top, depth = 798, 1262, 266, {2: 58, 3: 92, 4: 116, 0: 92}[st]
        runs = [(846, 404, 10), (904, 382, 7), (968, 426, 12), (1040, 398, 8), (1110, 372, 9),
                (1192, 418, 11), (1250, 392, 7)]
    else:
        x0, x1, top, depth = 470, W + 70, 128, {2: 50, 3: 80, 4: 104, 0: 80}[st]
        runs = [(812, 400, 9), (884, 372, 7), (1012, 408, 11), (1066, 368, 7), (1214, 396, 10),
                (1298, 360, 8), (1404, 388, 9)]
    prof = _profile(rng, x0, x1)
    if st == 0:
        body, edge = mix(wall, PAPER_HI, 0.30), mix(wall, TIMBER, 0.40)
    else:
        body = mix(wall, STORM, {2: 0.18, 3: 0.24, 4: 0.28}[st])
        edge = mix(wall, INK, {2: 0.42, 3: 0.52, 4: 0.60}[st])
    outline = [(x, top + 2 + depth * dd) for x, dd in prof]
    inner = [(x, top + 2 + depth * dd * 0.55) for x, dd in prof]
    lay = p.layer()
    lay.poly([(x0, top)] + outline + [(x1, top)], body, None)
    run_pts = []
    if st in (3, 4, 0):
        grow = {3: 1.0, 4: 1.16, 0: 1.0}[st]
        for rx, ry, wd in runs:
            dd = dict(prof).get(min(dict(prof), key=lambda x: abs(x - rx)), 0.6)
            base = top + 2 + depth * dd - 6
            end = base + (ry - base) * grow
            pts = _run(rng, rx, base, end, wd)
            lay.poly(pts, body, None)
            run_pts.append(pts)
    p.put(lay, 0.94)
    # tide-marks: an older faint ring inside, the hard dark rim at the edge
    inner_col = mix(body, edge, 0.35)
    p.line(inner, inner_col, 1.6)
    if st in (3, 4):
        p.line([(x, top + 2 + (y - top - 2) * 0.8) for x, y in outline], inner_col, 1.4)
    p.line(outline, edge, 3.0)
    for pts in run_pts:
        n = len(pts)
        p.line(pts[2:n - 2], edge, 2.6)


def blisters(p, st, xs, y):
    """Band 6-7: a row of eight small paint blisters, evenly spaced, along the wainscot line."""
    wall = STAGE[st]["wall"]
    for x in xs:
        sh = p.layer()
        sh.ell(x + 2, y + 3, 10, 9, INK, None)
        p.put_soft(sh, 2.0, 0.45)
        p.ell(x, y, 9, 8, mix(wall, PALE, 0.22), INK, 2)
        p.arc(x - 1, y - 1, 6, 5, 200, 290, mix(wall, PALE, 0.7), 2)
        p.arc(x, y, 8, 7, 20, 110, mix(wall, INK, 0.45), 1.6)


# ----------------------------------------------------------------------------- lockers

def screw(p, x, y, r=2.5):
    p.ell(x, y, r, r, BRASS_HI, INK, 1.2)


def enamel_plate(p, x0, y0, x1, y1, w=2.4):
    p.rect(x0, y0, x1, y1, ENAMEL, INK, w, r=3)
    p.line([(x0 + 4, y0 + 3), (x1 - 4, y0 + 3)], PALE, 1.2)


def card_holder(p, x0, y0, x1, y1, inset=4, w=2.4):
    p.rect(x0, y0, x1, y1, BRASS, INK, w, r=2)
    p.line([(x0 + 3, y0 + 2), (x1 - 3, y0 + 2)], BRASS_HI, 1.4)
    p.rect(x0 + inset, y0 + inset, x1 - inset, y1 - inset, CARD, mix(BRASS_LO, INK, 0.3), 1.6)
    # the bent tabs that hold the card
    for x in (x0 + inset, x1 - inset):
        p.poly([(x - 1, y0 + inset), (x + (inset + 2) * (1 if x < x1 - inset else -1), y0 + inset),
                (x - 1, y0 + inset + inset + 2)], BRASS_HI, INK, 1.0)


def hanger(p, cx, y, half, drop):
    wire = mix(STEEL_DK, LOCK_IN, 0.2)
    p.arc(cx + 3, y + 3, 4, 5, 160, 400, wire, 2)
    p.line([(cx, y + 8), (cx, y + 12)], wire, 2)
    p.line([(cx - half, y + 12 + drop), (cx, y + 12), (cx + half, y + 12 + drop),
            (cx - half, y + 12 + drop)], wire, 2)


def open_locker(p, x, rng):
    """One open tin locker, x..x+100, y 250-896, plates blank."""
    p.rect(x, 250, x + 100, 896, LOCKER, INK, 3)
    p.line([(x + 4, 254), (x + 96, 254)], LOCKER_HI, 1.6)
    # top rail details
    p.line([(x + 3, 336), (x + 97, 336)], INK, 2.4)
    enamel_plate(p, x + 12, 262, x + 88, 290)
    screw(p, x + 16, 276, 2)
    screw(p, x + 84, 276, 2)
    card_holder(p, x + 10, 298, x + 90, 330, inset=4)
    # dark opening
    p.rect(x + 10, 340, x + 90, 886, LOCK_IN, INK, 2.6)
    # upper back: a faint lighter band where the fanlight's grey reaches in
    p.rect(x + 18, 344, x + 88, 352, mix(LOCK_IN, LOCKER, 0.35), None)
    # the door leaf seen on edge at the left of the opening
    p.rect(x + 10, 340, x + 16, 886, LOCKER_HI, INK, 1.6)
    # shelf plank, its brass plate
    sh = p.layer()
    sh.rect(x + 16, 572, x + 90, 586, NIGHT, None)
    p.put_soft(sh, 2, 0.6)
    p.rect(x + 16, 560, x + 90, 572, TIMBER, INK, 2)
    p.line([(x + 18, 562), (x + 88, 562)], TIMBER_HI, 1.4)
    p.rect(x + 42, 572, x + 58, 580, BRASS_HI, INK, 1.4)
    # hanger rod and the empty hanger
    p.line([(x + 16, 600), (x + 90, 600)], BRASS_LO, 3)
    hanger(p, x + 52, 594, 26, 18)
    # locker floor
    p.rect(x + 16, 878, x + 90, 886, mix(LOCK_IN, LOCKER_DK, 0.6), None)
    p.line([(x + 16, 880), (x + 90, 880)], mix(LOCKER, LOCK_IN, 0.4), 1.6)
    # side seam to the next locker
    p.line([(x + 100, 250), (x + 100, 896)], INK, 3)


def louvre(p, x0, x1, y0, y1):
    y = y0 + 4
    while y < y1 - 2:
        p.line([(x0, y), (x1, y)], NIGHT, 3)
        p.line([(x0, y + 3), (x1, y + 3)], LOCKER_HI, 1.4)
        y += 8


def shut_locker(p, x):
    p.rect(x, 250, x + 64, 896, LOCKER, INK, 3)
    p.line([(x + 4, 254), (x + 60, 254)], LOCKER_HI, 1.6)
    p.rect(x + 5, 294, x + 59, 888, mix(LOCKER, LOCKER_HI, 0.25), INK, 2)
    enamel_plate(p, x + 8, 262, x + 56, 286, 2.2)
    louvre(p, x + 12, x + 52, 300, 340)
    louvre(p, x + 12, x + 52, 800, 840)
    # keyhole escutcheon at y 470
    p.ell(x + 32, 470, 8, 10, BRASS, INK, 1.8)
    p.ell(x + 32, 467, 2.6, 2.6, NIGHT, None)
    p.poly([(x + 30.5, 468), (x + 33.5, 468), (x + 34.5, 476), (x + 29.5, 476)], NIGHT, None)
    # latch handle
    p.rect(x + 46, 448, x + 52, 492, BRASS_LO, INK, 1.6, r=2)


# ----------------------------------------------------------------------------- bunks

def mattress(p, x0, x1, y0, y1):
    p.rect(x0, y0, x1, y1, PAPER, INK, 2.6, r=6)
    for k, yy in enumerate(range(y0 + 7, y1 - 3, 7)):
        p.line([(x0 + 4, yy), (x1 - 4, yy)], mix(STORM, PAPER, 0.25 if k % 2 == 0 else 0.55), 1.6 if k % 2 == 0 else 1.0)


def pillow(p, x0, x1, y0, y1):
    sh = p.layer()
    sh.rect(x0 + 2, y1 - 6, x1 + 2, y1 + 3, INK, None, r=4)
    p.put_soft(sh, 2, 0.3)
    p.rect(x0, y0, x1, y1, PAPER_HI, INK, 2.6, r=10)
    p.line([(x0 + 10, y0 + 5), (x1 - 12, y0 + 5)], PALE, 1.4)
    p.line([(x0 + 8, y1 - 7), (x1 - 8, y1 - 7)], mix(PAPER_HI, STORM, 0.15), 1.2)


def tag(p, x0, y0, x1, y1):
    p.rect(x0, y0, x1, y1, ENAMEL, INK, 2.2, r=2)
    p.line([(x0 + 3, y0 + 3), (x1 - 3, y0 + 3)], PALE, 1.0)
    screw(p, x0 + 6, (y0 + y1) / 2, 1.8)
    screw(p, x1 - 6, (y0 + y1) / 2, 1.8)


def rail(p, x0, x1, y0, y1):
    p.rect(x0, y0, x1, y1, TIMBER, INK, 2.6)
    p.line([(x0 + 2, y0 + 3), (x1 - 2, y0 + 3)], TIMBER_HI, 1.4)


def post(p, x0, x1, y0=330, y1=896):
    p.rect(x0, y0 + 8, x1, y1, TIMBER_DK, INK, 3)
    p.line([(x0 + 5, y0 + 14), (x0 + 5, y1 - 4)], TIMBER_HI, 1.6)
    p.ell((x0 + x1) / 2, y0 + 6, (x1 - x0) / 2 + 2, 8, TIMBER, INK, 2.6)
    p.rect(x0 - 2, y1 - 10, x1 + 2, y1, mix(TIMBER_DK, INK, 0.3), INK, 2)


def blanket(p, x0, x1, y_top, y_bot):
    p.rect(x0, y_top, x1, y_bot, BLANKET, INK, 2.6, r=4)
    n = 3
    for k in range(1, n):
        y = y_top + (y_bot - y_top) * k / n
        p.line([(x0 + 3, y), (x1 - 3, y)], BLANKET_DK, 1.8)
    p.line([(x0 + 4, y_top + 3), (x1 - 4, y_top + 3)], BLANKET_HI, 1.4)


def bunk(p, x0, x1, posts, pillow_x, tag_x, foot_blanket=None):
    """Two-tier bunk. posts: list of (x0, x1); x0..x1 the mattress span between them."""
    # under-bunk soft shade on the wall
    sh = p.layer()
    sh.rect(x0, UP["rail"][1], x1, UP["rail"][1] + 46, INK, None)
    p.put_soft(sh, 10, 0.18)
    for lvl in (UP, LO):
        mattress(p, x0, x1, *lvl["matt"])
        pillow(p, pillow_x, pillow_x + 90, *lvl["pillow"])
        rail(p, x0 - 2, x1 + 2, *lvl["rail"])
        tag(p, tag_x, lvl["rail"][0], tag_x + 80, lvl["rail"][1])
    if foot_blanket:
        blanket(p, foot_blanket[0], foot_blanket[1], LO["matt"][0] - 26, LO["matt"][0] + 4)
    for a, b in posts:
        post(p, a, b)


def underbunk_shadow(p, st, x0, x1, pool=None):
    """Bands 4+: the shade under each lower bunk turns into a flat navy shape."""
    if st not in (3, 4):
        lay = p.layer()
        lay.rect(x0, 752, x1, 800, INK, None)
        p.put_soft(lay, 12, 0.22 if st != 0 else 0.14)
        return
    col = mix(STORM, NIGHT, 0.35 if st == 3 else 0.5)
    pts = [(x0, 752), (x1, 752), (x1, 772)]
    if pool:
        a, b = pool
        pts += [(b + 18, 772), (b + 6, 896), (a - 6, 896), (a - 18, 772)]
    pts += [(x0, 772)]
    p.poly(pts, col, None)


def suitcase(p, x0, y0, x1, y1):
    cx = (x0 + x1) / 2
    # handle
    p.arc(cx, y0 + 14, 18, 12, 180, 360, LEATHER_DK, 6)
    p.arc(cx, y0 + 14, 18, 12, 180, 360, INK, 1.4)
    p.rect(cx - 26, y0 + 9, cx - 16, y0 + 15, BRASS, INK, 1.2)
    p.rect(cx + 16, y0 + 9, cx + 26, y0 + 15, BRASS, INK, 1.2)
    top = y0 + 14
    p.rect(x0, top, x1, y1, LEATHER, INK, 3, r=7)
    p.line([(x0 + 6, top + 4), (x1 - 6, top + 4)], LEATHER_HI, 1.6)
    seam = top + (y1 - top) * 0.36
    p.line([(x0 + 3, seam), (x1 - 3, seam)], LEATHER_DK, 2.4)
    for t in (0.22, 0.78):
        sx = x0 + (x1 - x0) * t
        p.rect(sx - 6, top, sx + 6, y1, LEATHER_DK, INK, 1.8)
        p.rect(sx - 8, seam - 6, sx + 8, seam + 6, BRASS, INK, 1.8)
        p.rect(sx - 4, seam - 2, sx + 4, seam + 2, LEATHER_DK, None)
    for cx_, cy_ in ((x0, top), (x1, top), (x0, y1), (x1, y1)):
        p.ell(cx_ + (5 if cx_ == x0 else -5), cy_ + (5 if cy_ == top else -5), 4, 4, BRASS_LO, INK, 1.2)


# ----------------------------------------------------------------------------- the belongings
# Each draws into a Box (unit u, v); lw is the ink width; detail adds close-up-only marks.

def draw_cup(p, b, lw=2.0, detail=False):
    u0, u1 = 0.02, 0.72
    rim = 0.06
    # handle (behind the body's right edge)
    hx, hy = b(0.75, 0.42)
    rx, ry = b.w * 0.16, b.h * 0.24
    th = max(2.0, b.w * 0.06)
    e = lw * 0.7          # PIL arcs grow inward from their box: offset the ink outward
    p.arc(hx, hy, rx + e, ry + e, 262, 458, INK, th + 2 * e)
    p.arc(hx, hy, rx, ry, 262, 458, CHINA, th)
    # the crack across the handle's outer curve, and the brass staple bridging it
    sx, sy = hx + rx - th / 2, hy
    p.line([(sx - th * 0.9, sy), (sx + th * 0.9, sy + 0.6)], INK, max(1.0, lw * 0.6))
    sw, shh = max(2.2, th * 0.75), max(5.0, th * 2.6)
    p.rect(sx - sw / 2, sy - shh / 2, sx + sw / 2, sy + shh / 2, BRASS_HI, INK, max(1.0, lw * 0.55))
    for yy in (sy - shh / 2 + sw * 0.4, sy + shh / 2 - sw * 0.4):
        p.ell(sx, yy, sw * 0.22, sw * 0.22, BRASS_LO, None)
    # body: a bowl that narrows to the foot
    left = bezier(b(u0, rim), b(0.04, 0.70), b(0.20, 0.86))
    right = bezier(b(0.54, 0.86), b(0.70, 0.70), b(u1, rim))
    body = left + right
    p.poly(body, CHINA, INK, lw)
    shade = bezier(b(0.50, 0.12), b(0.62, 0.62), b(0.46, 0.84))
    p.poly(shade + [b(0.54, 0.84), b(0.68, 0.62), b(0.70, 0.12)], CHINA_DK, None)
    # the painted sea-glass band under the rim
    band = max(1.4, b.h * 0.035)
    p.line([b(0.04, 0.18), b(0.70, 0.18)], SEAGLASS, band)
    p.line([b(u0, rim), b(u1, rim)], INK, lw)
    p.line([b(0.06, rim + 0.03), b(0.66, rim + 0.03)], PALE, max(1.0, lw * 0.6))
    # foot rim
    p.poly(b.quad(0.18, 0.86, 0.56, 1.0), CHINA_DK, INK, lw)
    if detail:  # the scratches the foot carries
        for k in range(7):
            x = 0.22 + k * 0.045
            p.line([b(x, 0.90), b(x + 0.02, 0.97)], mix(CHINA_DK, INK, 0.5), 1.2)


def draw_calipers(p, b, lw=2.0, detail=False):
    """A slide caliper stood upright: beam, fixed jaw at the top, sliding jaw below it; the
    sliding jaw's tip filed short and square."""
    def q(u0, v0, u1, v1, fill, w=lw):
        p.poly(b.quad(u0, v0, u1, v1), fill, INK, w)
    q(0.30, 0.04, 0.46, 1.0, STEEL)                        # beam
    for k in range(14):                                    # graduations as plain ticks
        v = 0.48 + k * 0.035
        p.line([b(0.30, v), b(0.37 if k % 2 else 0.40, v)], STEEL_DK, max(1.0, lw * 0.5))
    # fixed jaw: out to the right, tip pointing down
    p.poly(b.pts([(0.30, 0.04), (0.88, 0.04), (0.96, 0.10), (0.92, 0.30), (0.86, 0.30), (0.82, 0.14),
                  (0.46, 0.14)]), STEEL, INK, lw)
    # inside jaw, small, to the left
    p.poly(b.pts([(0.30, 0.05), (0.10, 0.05), (0.06, 0.09), (0.30, 0.13)]), STEEL, INK, lw)
    # slider block with thumb screw
    q(0.24, 0.36, 0.52, 0.52, STEEL_HI)
    p.ell(*b(0.38, 0.33), max(2.5, b.w * 0.05), max(2.5, b.w * 0.05), BRASS, INK, max(1.0, lw * 0.7))
    # sliding jaw: up toward the fixed one, its tip filed flat
    p.poly(b.pts([(0.52, 0.38), (0.80, 0.38), (0.84, 0.34), (0.84, 0.26), (0.92, 0.26),
                  (0.92, 0.46), (0.52, 0.46)]), STEEL, INK, lw)
    # the filed facet: bright, cross-hatched
    p.poly(b.quad(0.84, 0.26, 0.92, 0.31), STEEL_HI, INK, max(1.0, lw * 0.7))
    if detail:
        for k in range(5):
            u = 0.845 + k * 0.016
            p.line([b(u, 0.262), b(u + 0.02, 0.305)], STEEL_DK, 1.2)
    else:
        p.line([b(0.85, 0.28), b(0.91, 0.28)], STEEL_DK, max(1.0, lw * 0.5))
    p.line([b(0.33, 0.06), b(0.33, 0.98)], STEEL_HI, max(1.0, lw * 0.6))


PENCIL_COLS = (mix(SEAGLASS, INK, 0.25), STORM_HI, mix(TIMBER, INK, 0.1), mix(BRASS_LO, INK, 0.15))


def draw_pencils(p, b, lw=2.0, detail=False):
    # four pencils up out of the tin, fanned a little
    for k, (u, lean) in enumerate(((0.28, -4.0), (0.43, -1.0), (0.58, 2.0), (0.73, 5.0))):
        bb = Box(b.x0, b.y0, b.x0 + b.w, b.y0 + b.h, lean, b(u, 0.62))
        wd = 0.065
        p.poly(bb.quad(u - wd, 0.14 + 0.03 * (k % 2), u + wd, 0.62), PENCIL_COLS[k], INK, lw)
        p.poly(bb.pts([(u - wd, 0.14 + 0.03 * (k % 2)), (u + wd, 0.14 + 0.03 * (k % 2)),
                       (u, 0.02 + 0.03 * (k % 2))]), WOOD, INK, lw * 0.9)
        p.poly(bb.pts([(u - wd * 0.35, 0.055 + 0.03 * (k % 2)), (u + wd * 0.35, 0.055 + 0.03 * (k % 2)),
                       (u, 0.02 + 0.03 * (k % 2))]), GRAPHITE, None)
        p.line(bb.pts([(u - wd * 0.2, 0.16 + 0.03 * (k % 2)), (u - wd * 0.2, 0.60)]),
               mix(PENCIL_COLS[k], PALE, 0.3), max(1.0, lw * 0.5))
    # tin cylinder
    p.poly(b.quad(0.10, 0.44, 0.90, 1.0), TIN, INK, lw)
    p.poly(b.quad(0.64, 0.48, 0.90, 0.98), TIN_DK, None)
    # left third worn bright
    p.poly(b.pts([(0.11, 0.48), (0.37, 0.48), (0.34, 0.97), (0.11, 0.97)]), WORN, None)
    for k in range(3 if not detail else 7):
        u = 0.14 + k * (0.18 / (2 if not detail else 6))
        p.line([b(u, 0.52), b(u + 0.01, 0.92)], mix(WORN, PALE, 0.5), max(1.0, lw * 0.5))
    p.line([b(0.37, 0.48), b(0.34, 0.97)], mix(WORN, TIN, 0.5), max(1.0, lw * 0.5))
    p.poly(b.quad(0.10, 0.44, 0.90, 1.0), None, INK, lw)
    # rolled rims
    p.poly(b.quad(0.07, 0.41, 0.93, 0.49), mix(TIN, PALE, 0.25), INK, lw)
    p.poly(b.quad(0.08, 0.94, 0.92, 1.0), TIN_DK, INK, lw)


def draw_glove(p, b, lw=2.0, detail=False):
    """A right glove seen back-of-hand, lying with the fingers to the right, cuff and thumb at
    the left. Red running stitch across the index and middle fingertips."""
    s = min(b.w, b.h)
    fingers = [  # (v centre, tip u, half thickness in box heights)
        (0.40, 0.95, 0.085),   # index
        (0.57, 1.00, 0.085),   # middle
        (0.73, 0.96, 0.08),    # ring
        (0.87, 0.86, 0.07),    # little
    ]
    for vc, tip, ht in reversed(fingers):
        r = b.h * ht
        p.poly(capsule(b(0.52, vc), (b(tip, vc)[0] - r, b(tip, vc)[1]), r, r), GLOVE, INK, lw)
    # thumb: broad, rooted in the back of the hand, up and to the right
    r = b.h * 0.11
    p.poly(capsule(b(0.36, 0.48), b(0.52, 0.12), r, r * 0.85), GLOVE_HI, INK, lw)
    # palm/back of hand
    palm = bezier(b(0.22, 0.30), b(0.40, 0.26), b(0.58, 0.32)) + \
        bezier(b(0.60, 0.40), b(0.62, 0.70), b(0.58, 0.96)) + \
        bezier(b(0.42, 1.0), b(0.30, 1.0), b(0.22, 0.96))
    p.poly(palm, GLOVE, INK, lw)
    # cuff
    p.poly(b.quad(0.0, 0.26, 0.25, 1.0), GLOVE_DK, INK, lw)
    for k in range(1, 4 if not detail else 6):
        u = 0.25 * k / (4 if not detail else 6)
        p.line([b(u, 0.30), b(u, 0.96)], mix(GLOVE_DK, INK, 0.35), max(1.0, lw * 0.5))
    # knuckle seams
    for vc, tip, ht in fingers[:3]:
        p.line([b(0.48, vc + ht * 1.0), b(0.58, vc + ht * 1.0)], GLOVE_DK, max(1.0, lw * 0.5))
    # red running stitch: across the index and middle fingertips
    for vc, tip, ht in fingers[:2]:
        x = b(tip, vc)[0] - b.h * ht * 1.8
        y0, y1 = b(0, vc - ht * 0.95)[1], b(0, vc + ht * 0.95)[1]
        n = 3 if not detail else 4
        dash = (y1 - y0) / (2 * n - 1)
        for k in range(n):
            yy = y0 + k * 2 * dash
            p.line([(x, yy), (x + 0.5, yy + dash)], RED, max(1.6, s * 0.06))


# ----------------------------------------------------------------------------- view A

LABELS_A = ([(x + 10, 260, x + 91, 333) for x in OPEN_X.values()]
            + [(x + 6, 260, x + 59, 289) for x in SHUT_X.values()]
            + [(880, 478, 961, 504), (880, 728, 961, 754), (1260, 478, 1341, 504), (1260, 728, 1341, 754)])


def fanlight(p):
    x0, y0, x1, y1 = FAN_OUT
    p.rect(x0 - 8, y1 - 2, x1 + 8, y1 + 10, FRAME, INK, 3)           # sill
    p.rect(x0, y0, x1, y1, FRAME, INK, 3)
    p.line([(x0 + 4, y0 + 4), (x1 - 4, y0 + 4)], FRAME_HI, 1.6)
    p.rect(x0 - 10, y0 - 10, x1 + 10, y0, FRAME, INK, 3)              # head moulding
    gx0, gy0, gx1, gy1 = FAN_GLASS
    p.rect(gx0, gy0, gx1, gy1, GLASS, INK, 2.6)


def paint_view_a(rng, st):
    p = Pen(W, H, rng)
    shell(p, rng, st)
    fanlight(p)
    damp(p, st, "a")
    # the locker bank
    p.rect(44, 244, 708, 252, LOCKER_DK, INK, 2.4)          # top cap over the whole bank
    for x in OPEN_X.values():
        open_locker(p, x, rng)
    for x in SHUT_X.values():
        shut_locker(p, x)
    p.rect(446, 246, 706, 252, mix(LOCKER_DK, LOCKER, 0.5), INK, 2)   # the belongings' shelf top
    # under-bunk shade (behind beds and luggage)
    underbunk_shadow(p, st, 748, 1080, pool=(770, 1060))
    underbunk_shadow(p, st, 1144, W + 4, pool=(1170, 1330))
    # luggage under the lower bunks, then the beds over the wall
    bunk(p, 748, 1080, [(724, 748), (1080, 1104)], 756, 880, foot_blanket=(990, 1074))
    bunk(p, 1144, W + 6, [(1120, 1144)], 1152, 1260)
    for box in ((770, 790, 900, 896), (920, 820, 1060, 896), (1170, 806, 1330, 896)):
        suitcase(p, *box)
    if st == 4:
        blisters(p, st, [1176 + 34 * k for k in range(8)], 604)
    return graded(p, st, LABELS_A)


# ----------------------------------------------------------------------------- view B

LABELS_B = [(504, 140, 777, 509), (990, 478, 1071, 504), (990, 728, 1071, 754),
            (1310, 478, 1391, 504), (1310, 728, 1391, 754)]


def curtain(p, rng):
    folds = CURTAIN_FOLDS
    # rail and rings
    for k, (a, b) in enumerate(zip(folds[:-1], folds[1:])):
        ridge = (a + b) / 2
        base = mix(BLANKET, BLANKET_HI, 0.15 if k % 2 else 0.0)
        pts = [(a, 126)]
        for j in range(9):
            t = j / 8
            x = lerp(a, b, t)
            pts.append((x, 880 + 12 * math.sin(math.pi * t)))
        pts.append((b, 126))
        p.poly(pts, base, None)
        if k == 0:
            # the broad flat left panel: no lines in the turn-arrow corner
            p.rect(a + 58, 126, a + 72, 770, mix(base, BLANKET_HI, 0.6), None)
            continue
        wdt = b - a
        p.poly([(a, 126), (a + wdt * 0.22, 126), (a + wdt * 0.18, 884), (a, 878)], BLANKET_DK, None)
        p.poly([(ridge - wdt * 0.06, 126), (ridge + wdt * 0.12, 126), (ridge + wdt * 0.10, 888),
                (ridge - wdt * 0.08, 888)], mix(BLANKET_HI, PAPER, 0.12), None)
        p.line([(a, 128), (a, 880)], mix(BLANKET_DK, INK, 0.5), 2.4)
    # hem band and lower scallop edge
    hem = []
    for k, (a, b) in enumerate(zip(folds[:-1], folds[1:])):
        for j in range(9):
            t = j / 8
            hem.append((lerp(a, b, t), 880 + 12 * math.sin(math.pi * t)))
    p.line([(x, y - 14) for x, y in hem], mix(BLANKET_DK, INK, 0.25), 2)
    p.line(hem, INK, 3)
    p.line([(folds[0], 126), (folds[0], 880)], INK, 3)
    p.line([(folds[-1], 126), (folds[-1], 880)], INK, 3)
    # heading: gathered pleats under the rings
    p.rect(folds[0], 120, folds[-1], 140, mix(BLANKET, BLANKET_HI, 0.35), INK, 2.4)
    p.rect(30, 112, 500, 120, BRASS_LO, INK, 2.2)
    p.line([(32, 114), (498, 114)], BRASS_HI, 1.2)
    for x in range(44, 476, 30):
        p.ell(x, 124, 7, 7, None, INK, 4.2)
        p.ell(x, 124, 7, 7, None, BRASS, 2.2)
    for x in (30, 500):
        p.rect(x - 6, 106, x + 6, 126, BRASS, INK, 2)


def calendar(p):
    # cord to the nail
    p.line([(560, 142), (640, 132), (720, 142)], mix(TIMBER_DK, INK, 0.3), 2)
    p.ell(640, 132, 3.5, 3.5, STEEL_DK, INK, 1.4)
    sh = p.layer()
    sh.rect(510, 148, 782, 516, INK, None)
    p.put_soft(sh, 5, 0.25)
    p.rect(504, 140, 776, 508, TIMBER, INK, 3, r=2)
    p.rect(508, 144, 772, 504, PAPER_HI, mix(TIMBER, INK, 0.4), 1.4)
    p.rect(514, 150, 766, 190, ENAMEL, INK, 2.2)
    for k in range(9):
        y = 196 + 38 * k
        p.line([(514, y), (766, y)], mix(PAPER, INK, 0.45 if k in (0, 8) else 0.3), 2 if k in (0, 8) else 1.4)
    for x in (514, 574, 584, 766):
        p.line([(x, 196), (x, 500)], mix(PAPER, INK, 0.4), 1.6)


def writing_table(p):
    # legs, apron, top
    for a in (504, 788):
        p.rect(a, 716, a + 16, 902, TIMBER_DK, INK, 2.6)
    p.rect(500, 716, 808, 732, TIMBER, INK, 2.4)
    p.rect(496, 700, 812, 716, TIMBER_HI, INK, 3)
    p.line([(500, 703), (808, 703)], mix(TIMBER_HI, PAPER, 0.3), 1.4)
    # writing slope: walnut box, green baize edge, brass corners
    p.rect(510, 606, 800, 700, WALNUT, INK, 3)
    p.rect(514, 610, 796, 630, BAIZE, INK, 2)
    p.line([(516, 613), (794, 613)], BAIZE_HI, 1.4)
    p.line([(514, 662), (796, 662)], WALNUT_DK, 2)
    p.ell(655, 680, 5, 5, BRASS, INK, 1.6)
    for cx, cy, sx, sy in ((510, 606, 1, 1), (800, 606, -1, 1), (510, 700, 1, -1), (800, 700, -1, -1)):
        p.poly([(cx, cy), (cx + 16 * sx, cy), (cx + 16 * sx, cy + 5 * sy), (cx + 5 * sx, cy + 5 * sy),
                (cx + 5 * sx, cy + 16 * sy), (cx, cy + 16 * sy)], BRASS_HI, INK, 1.4)
    pigeonhole(p, open_=False)


def pigeonhole(p, open_):
    x0, y0, x1, y1 = 712, 532, 796, 606
    p.rect(x0, y0, x1, y1, WALNUT_HI, INK, 2.6)
    p.line([(x0 + 3, y0 + 3), (x1 - 3, y0 + 3)], mix(WALNUT_HI, PAPER, 0.3), 1.2)
    if not open_:
        p.rect(x0 + 6, y0 + 10, x1 - 6, y1 - 6, WALNUT, INK, 2)
        p.ell((x0 + x1) / 2, y0 + 22, 4, 4, BRASS_HI, INK, 1.4)
        for x in (x0 + 18, x1 - 18):
            p.rect(x - 5, y1 - 8, x + 5, y1 - 4, BRASS, INK, 1)
        return
    # the opening, a folded letter leaning out, the flap dropped forward over the slope
    p.rect(x0 + 6, y0 + 10, x1 - 6, y1 - 6, NIGHT, INK, 2)
    p.poly([(x0 + 18, y1 - 6), (x0 + 22, y0 + 22), (x1 - 14, y0 + 16), (x1 - 12, y1 - 6)],
           PAPER_HI, INK, 2)
    p.line([(x0 + 20, y0 + 44), (x1 - 13, y0 + 40)], mix(PAPER, INK, 0.35), 1.6)
    p.line([(x0 + 22, y0 + 26), (x1 - 15, y0 + 20)], PALE, 1.2)
    p.poly([(x0 + 4, y1 - 6), (x1 - 4, y1 - 6), (x1 - 2, 640), (x0 + 2, 640)], WALNUT, INK, 2.4)
    p.line([(x0 + 6, 636), (x1 - 6, 636)], WALNUT_DK, 1.6)
    p.ell((x0 + x1) / 2, 628, 4, 4, BRASS_HI, INK, 1.4)
    for x in (x0 + 18, x1 - 18):
        p.rect(x - 5, y1 - 8, x + 5, y1 - 2, BRASS, INK, 1)


def pencil_shelf(p):
    # bracket off frame 3's head post
    p.poly([(856, 572), (900, 572), (856, 604)], TIMBER_DK, INK, 2.2)
    p.rect(860, 558, 990, 572, TIMBER, INK, 2.4)
    # the pencil lying in its groove, above the lip
    p.poly([(878, 547), (952, 547), (962, 550.5), (952, 554), (878, 554)], mix(SEAGLASS, INK, 0.2), INK, 1.6)
    p.poly([(952, 547), (962, 550.5), (952, 554)], WOOD, INK, 1.2)
    p.ell(962, 550.5, 1.6, 1.6, GRAPHITE, None)
    p.rect(860, 552, 990, 559, TIMBER_HI, INK, 1.8)            # lip
    p.line([(862, 562), (988, 562)], TIMBER_HI, 1.2)


def cup_shelf(p, st):
    p.poly([(1190, 598), (1232, 598), (1190, 630)], TIMBER_DK, INK, 2.2)
    p.rect(1196, 586, 1296, 598, TIMBER, INK, 2.4)
    p.line([(1198, 589), (1294, 589)], TIMBER_HI, 1.2)
    # the old dry ring on its top
    ring = mix(PAPER_HI, STAGE[st]["wall"], 0.25)
    p.ell(1236, 585, 14, 3.5, None, ring, 2.2)


def paint_view_b(rng, st):
    p = Pen(W, H, rng)
    shell(p, rng, st)
    damp(p, st, "b")
    calendar(p)
    writing_table(p)
    underbunk_shadow(p, st, 856, 1126)
    underbunk_shadow(p, st, 1190, W + 4)
    bunk(p, 856, 1126, [(832, 856), (1126, 1150)], 864, 990)
    bunk(p, 1190, W + 6, [(1166, 1190)], 1198, 1310)
    pencil_shelf(p)
    cup_shelf(p, st)
    curtain(p, rng)
    if st == 4:
        blisters(p, st, [878 + 34 * k for k in range(8)], 604)
    return graded(p, st, LABELS_B)


# ----------------------------------------------------------------------------- view A overlays

def paint_top(which):
    def fn(rng):
        p = Pen(W, H, rng)
        if which == "pencils":
            draw_pencils(p, Box(458, 190, 498, 250), 1.8)
        elif which == "glove":
            draw_glove(p, Box(516, 222, 574, 250), 1.6)
        elif which == "cup":
            draw_cup(p, Box(586, 210, 632, 250), 1.8)
        else:  # calipers stood on end, leaning on the wall
            draw_calipers(p, Box(654, 174, 690, 250, -8.0, (668, 250)), 1.6)
        sh = p.layer()
        sh.rect({"pencils": 456, "glove": 516, "cup": 586}.get(which, 646), 247,
                {"pencils": 500, "glove": 574, "cup": 632}.get(which, 700), 251, INK, None)
        p.put_soft(sh, 1.5, 0.35)
        return p
    return fn


def paint_in(which):
    def fn(rng):
        p = Pen(W, H, rng)
        if which == "cup":
            draw_cup(p, Box(70, 512, 126, 560), 2.0)
        elif which == "calipers":
            draw_calipers(p, Box(176, 470, 222, 560, -6.0, (199, 560)), 1.8)
        elif which == "pencils":
            draw_pencils(p, Box(274, 470, 322, 560), 2.0)
        else:
            draw_glove(p, Box(362, 520, 436, 560), 1.8)
        return p
    return fn


def paint_a_cup_mark(rng):
    p = Pen(W, H, rng)
    lead = mix(GRAPHITE, PAPER, 0.15)
    # the outline of the foot drawn round on the shelf, carried down over its front edge
    p.line([(70, 558), (72, 562), (124, 562), (126, 558)], lead, 1.6)
    p.line([(80, 557), (82, 566), (114, 566), (116, 557)], lead, 1.4)
    # the tick
    p.line([(114, 568), (119, 574), (130, 557)], lead, 2.0)
    return p


def nested(p, x0, y0, x1, y1, n, ins, start, end, nail):
    """Frames receding into the locker: each smaller, each darker, the last near-black."""
    rect = (x0, y0, x1, y1)
    for k in range(n + 1):
        t = k / n
        col = mix(start, end, t ** 0.8)
        a, b_, c, d = rect
        p.rect(a, b_, c, d, col, INK, 2.2 if k < n else 1.6)
        # lit lower lip on each step, shadow on its upper inside
        if k < n:
            p.line([(a + 3, d - 3), (c - 3, d - 3)], mix(col, PALE, 0.18), 1.4)
        rect = (a + ins[0], b_ + ins[1], c - ins[2], d - ins[3])
    nx, ny = nail
    p.ell(nx + 1, ny + 2, 3, 3, NIGHT, None)
    p.line([(nx, ny), (nx + 1, ny + 7)], STEEL_DK, 2)
    p.ell(nx, ny, 3, 3, STEEL_HI, INK, 1.2)


def paint_a_venn_open(rng):
    p = Pen(W, H, rng)
    nested(p, 258, 574, 338, 880, 7, (3.2, 3.6, 3.2, 28), LOCK_IN, NIGHT, (298, 610))
    return p


def paint_a_dry_ring(rng):
    p = Pen(W, H, rng)
    p.ell(98, 559, 32, 5, None, mix(PALE, PAPER, 0.3), 2.6)
    p.ell(98, 559, 26, 3.5, None, mix(PALE, PAPER, 0.5), 1.0)
    return p


def paint_a_steam(rng):
    p = Pen(40, 90, rng)
    lay = p.layer()
    pts = [(20 + 6 * math.sin(t * 0.11) * (1 - t / 100), 88 - t) for t in range(0, 82, 2)]
    lay.line(pts, PALE, 5)
    pts2 = [(22 - 5 * math.sin(t * 0.13 + 1) * (1 - t / 80), 80 - t) for t in range(0, 60, 2)]
    lay.line(pts2, PALE, 3)
    p.put_soft(lay, 2.0, 0.55)
    return p


def dent(x0, upper):
    """Replacement pillow sunk by a head that is not there; a body-length hollow along the
    mattress. x0 is the bed's dent box left edge (pillow at x0+6..x0+96)."""
    lvl = UP if upper else LO
    def fn(rng):
        p = Pen(W, H, rng)
        py0, py1 = lvl["pillow"]
        my0, my1 = lvl["matt"]
        px0, px1 = x0 + 6, x0 + 96
        # the hollow first (under the pillow's end)
        hx0, hx1 = px1 - 8, x0 + 246
        curve = [(lerp(hx0, hx1, t / 24), my0 + 1 + 13 * math.sin(math.pi * t / 24) ** 0.6) for t in range(25)]
        sh = p.layer()
        sh.poly([(hx0, my0 + 1)] + curve + [(hx1, my0 + 1)], mix(STORM, NIGHT, 0.4), None)
        p.put(sh, 0.88)
        band = p.layer()
        band.poly([(x, y - 2) for x, y in curve] + [(hx1, my0 + 20), (hx0, my0 + 20)], STORM, None)
        p.put_soft(band, 3, 0.55)
        p.line(curve, INK, 2.4)
        p.line([(x, y + 4) for x, y in curve[3:-3]], mix(PAPER, PALE, 0.6), 1.2)
        # the replacement pillow: sides puffed, a navy crescent where the head pressed in
        shp = p.layer()
        shp.rect(px0 + 2, py1 - 6, px1 + 2, py1 + 3, INK, None, r=4)
        p.put_soft(shp, 2, 0.3)
        p.rect(px0 - 1, py0 - 2, px1 + 1, py1, PAPER_HI, INK, 2.6, r=11)
        top = [(lerp(px0 + 8, px1 - 8, t / 24), py0 + 3 + 3 * math.sin(math.pi * t / 24)) for t in range(25)]
        lip = [(lerp(px1 - 8, px0 + 8, t / 24), py0 + 3 + 13 * math.sin(math.pi * t / 24)) for t in range(25)]
        p.poly(top + lip, mix(STORM, NIGHT, 0.3), None)
        p.line(lip, INK, 2.4)
        p.line([(x, y + 3) for x, y in lip[4:-4]], PALE, 1.4)
        p.line([(px0 + 8, py1 - 7), (px1 - 8, py1 - 7)], mix(PAPER_HI, STORM, 0.2), 1.2)
        return p
    return fn


# ----------------------------------------------------------------------------- fanlight

def clip_glass(p):
    """Return the Pen's image clipped to the fanlight glass."""
    m = rect_mask([FAN_GLASS])
    p.im.putalpha(ImageChops.multiply(p.im.getchannel("A"), m))
    return p


def scallops(p, y, x0, x1, r, col, rng, below=40):
    x = x0 - r
    while x < x1 + r:
        rr = r * rng.uniform(0.7, 1.15)
        p.ell(x, y, rr * 1.5, rr, col, None)
        x += rr * 1.9
    p.rect(x0 - 4, y, x1 + 4, y + below, col, None)


def sea(p, y0, col, rng, rows, lines=True):
    gx0, gy0, gx1, gy1 = FAN_GLASS
    p.rect(gx0 - 2, y0, gx1 + 2, gy1 + 2, col, None)
    p.line([(gx0, y0), (gx1, y0)], mix(col, INK, 0.4), 1.6)
    if lines:
        y = y0 + rows
        while y < gy1:
            x = gx0 + rng.uniform(0, 30)
            while x < gx1:
                L = rng.uniform(14, 34)
                p.arc(x + L / 2, y, L / 2, 3, 200, 340, mix(col, PALE, 0.22), 1.4)
                x += L + rng.uniform(10, 30)
            y += rows


def jetty(p, col, deck=208):
    for x in (1094, 1112, 1130, 1148, 1166):
        p.rect(x, deck - 4, x + 4, 242, col, None)
    p.rect(1088, deck - 6, 1176, deck - 1, col, None)
    p.rect(1150, deck - 18, 1166, deck - 6, col, None)


def paint_fan(band):
    def fn(rng):
        p = Pen(W, H, rng)
        gx0, gy0, gx1, gy1 = FAN_GLASS
        if band == 1:
            p.rect(gx0, gy0, gx1, gy1, (178, 184, 186), None)
            scallops(p, 176, gx0, gx1, 12, (196, 200, 200), rng)
            scallops(p, 204, gx0, gx1, 14, (160, 168, 172), rng)
            scallops(p, 228, gx0, gx1, 12, (144, 152, 158), rng)
        elif band == 2:
            p.rect(gx0, gy0, gx1, gy1, (150, 158, 162), None)
            scallops(p, 172, gx0, gx1, 14, (132, 140, 146), rng)
            scallops(p, 196, gx0, gx1, 12, (118, 126, 134), rng)
            sea(p, 214, (104, 114, 120), rng, 8)
            jetty(p, (70, 80, 88))
        elif band == 3:
            p.rect(gx0, gy0, gx1, gy1, (112, 120, 128), None)
            scallops(p, 166, gx0, gx1, 18, (94, 102, 112), rng)
            scallops(p, 192, gx0, gx1, 16, (80, 88, 98), rng)
            sea(p, 210, (76, 88, 96), rng, 6)
            jetty(p, (46, 56, 66), 204)
        elif band == 4:
            p.rect(gx0, gy0, gx1, gy1, (102, 110, 118), None)
            sea(p, 166, (68, 82, 92), rng, 4)
        elif band == 5:
            p.rect(gx0, gy0, gx1, gy1, (106, 112, 116), None)
            lay = p.layer()
            for k in range(6):
                lay.ell(rng.uniform(gx0, gx1), rng.uniform(gy0, gy1), rng.uniform(40, 90),
                        rng.uniform(10, 20), (114, 120, 124), None)
            p.put_soft(lay, 10, 0.6)
        elif band == 6:
            p.rect(gx0, gy0, gx1, gy1, (32, 46, 60), None)
            lay = p.layer()
            for k in range(4):
                lay.ell(rng.uniform(gx0, gx1), rng.uniform(gy0, gy1), rng.uniform(60, 120),
                        rng.uniform(14, 24), (40, 56, 70), None)
            p.put_soft(lay, 12, 0.5)
        elif band == 7:
            p.rect(gx0, gy0, gx1, gy1, (20, 30, 40), None)
            p.rect(gx0, 199, gx1, 202, (74, 92, 104), None)
        else:  # sever: pale ordinary daylight
            p.rect(gx0, gy0, gx1, gy1, (208, 210, 202), None)
            scallops(p, 182, gx0, gx1, 12, (224, 224, 216), rng)
            sea(p, 224, (176, 184, 182), rng, 9)
        return clip_glass(p)
    return fn


def paint_rain(kind):
    def fn(rng):
        p = Pen(W, H, rng)
        gx0, gy0, gx1, gy1 = FAN_GLASS
        lay = p.layer()
        if kind == "hang":
            for _ in range(30):
                x, y = rng.uniform(gx0 + 6, gx1 - 6), rng.uniform(gy0 + 6, gy1 - 14)
                L = rng.uniform(5, 11)
                lay.line([(x, y), (x, y + L)], (214, 222, 224), 1.6)
                lay.ell(x, y + L + 1.5, 2.4, 2.8, (226, 232, 232), None)
                lay.arc(x, y + L + 1.5, 2.4, 2.8, 20, 160, mix(INK, GLASS, 0.3), 1.0)
            p.put(lay, 0.8)
        else:
            heavy = kind.startswith("heavy")
            n = 90 if heavy else 36
            for _ in range(n):
                x, y = rng.uniform(gx0, gx1), rng.uniform(gy0 - 20, gy1)
                L = rng.uniform(18, 40) if heavy else rng.uniform(10, 22)
                lay.line([(x, y), (x - L * 0.12, y + L)], (214, 222, 226),
                         rng.uniform(1.2, 1.8) if heavy else rng.uniform(1.0, 1.4))
            p.put(lay, 0.55 if heavy else 0.45)
        return clip_glass(p)
    return fn


def paint_fan_frame(rng):
    p = Pen(W, H, rng)
    gx0, gy0, gx1, gy1 = FAN_GLASS
    # faint wired-glass diamond mesh
    mesh = p.layer()
    for k in range(-30, 60):
        x = gx0 + k * 14
        mesh.line([(x, gy0), (x + (gy1 - gy0), gy1)], (220, 226, 226), 1.0)
        mesh.line([(x, gy1), (x + (gy1 - gy0), gy0)], (220, 226, 226), 1.0)
    clip_glass(mesh)
    p.put(mesh, 0.10)
    # rebate shadow round the glass
    sh = p.layer()
    sh.rect(gx0, gy0, gx1, gy0 + 6, INK, None)
    sh.rect(gx0, gy0, gx0 + 5, gy1, INK, None)
    clip_glass(sh)
    p.put_soft(sh, 2, 0.4)
    for x in FAN_BARS:
        p.rect(x - 4, gy0, x + 4, gy1, FRAME, INK, 2)
        p.line([(x - 1, gy0 + 2), (x - 1, gy1 - 2)], FRAME_HI, 1.2)
    p.rect(gx0 - 1, gy0 - 1, gx1 + 1, gy1 + 1, None, INK, 2.6)
    return p


# ----------------------------------------------------------------------------- view B overlays

def paint_b_curtain_shape(rng):
    """Someone standing behind the cloth: a flat head-and-shoulders shape, taller than Ada,
    printed through the folds and bent by them, fading to nothing by y 700."""
    folds = CURTAIN_FOLDS
    cx = 256
    out = []
    # head (top 170), neck, shoulders at y 300, torso to 720
    for k in range(0, 31):
        a = -math.pi / 2 + (math.pi * 0.62) * k / 30
        out.append((cx + 37 * math.cos(a), 216 + 46 * math.sin(a)))
    out += bezier((cx + 21, 256), (cx + 20, 274), (cx + 34, 282), 8)[1:]
    out += bezier((cx + 34, 282), (cx + 104, 284), (cx + 110, 306), 14)[1:]
    out += bezier((cx + 110, 306), (cx + 118, 420), (cx + 120, 720), 20)[1:]
    right = out
    left = [(2 * cx - x, y) for x, y in reversed(right)]
    pts = right + [(cx - 120, 720)] + left[1:]

    def bend(x, y):
        for a, b in zip(folds[:-1], folds[1:]):
            if a <= x <= b:
                t = (x - a) / (b - a)
                return (x + 5 * math.sin(2 * math.pi * t), y - 7 * math.sin(math.pi * t))
        return (x, y)

    dense = []
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 4))
        for j in range(n):
            dense.append(bend(lerp(a[0], b[0], j / n), lerp(a[1], b[1], j / n)))
    p = Pen(W, H, rng)
    p.poly(dense, mix(VIOLET, INK, 0.45), None)
    # alpha: 0.55 to y 300, fading to zero by 700; a little darker in the fold valleys
    m = Image.new("L", (W, H), 0)
    px = m.load()
    for y in range(H):
        f = 1.0 if y < 300 else max(0.0, 1 - (y - 300) / 400)
        f = f ** 1.2
        for a, b in zip(folds[:-1], folds[1:]):
            for x in range(a, b):
                t = (x - a) / (b - a)
                v = 0.55 * f * (1.08 - 0.16 * math.sin(math.pi * t))
                px[x, y] = int(min(1.0, v) * 255)
    m = m.resize((W * SS, H * SS), Image.BILINEAR)
    p.im.putalpha(ImageChops.multiply(p.im.getchannel("A"), m))
    return p


def paint_b_pigeonhole_open(rng):
    p = Pen(W, H, rng)
    pigeonhole(p, open_=True)
    return p


# ----------------------------------------------------------------------------- close-up: lockers

CL_X = (74, 394, 714, 1034)


def paint_c_lockers(rng):
    wall = STAGE[1]["wall"]
    p = Pen(W, H, rng, bg=wall)
    p.rect(-4, -4, W + 4, 40, TIMBER_DK, INK, 3)
    # the bank behind the doors
    p.rect(54, 96, 1354, 834, LOCKER_DK, INK, 3)
    # wainscot below and the felt-lined tray plank
    p.rect(-4, 834, W + 4, H + 4, WAINS, None)
    for x in range(20, W, 64):
        p.line([(x, 840), (x, H)], WAINS_DK, 3)
        p.line([(x + 4, 840), (x + 4, H)], mix(WAINS, STORM_HI, 0.8), 1.4)
    p.rect(-4, 830, W + 4, 846, FRAME, INK, 3)
    for x in (200, 724, 1220):
        p.poly([(x - 10, 982), (x + 10, 982), (x + 10, 1040), (x - 10, 1010)], TIMBER_DK, INK, 2.4)
    sh = p.layer()
    sh.rect(124, 982, 1306, 1000, INK, None)
    p.put_soft(sh, 6, 0.4)
    p.rect(120, 960, 1300, 982, TIMBER, INK, 3)
    p.rect(124, 953, 1296, 962, BLANKET, INK, 2)
    p.line([(128, 956), (1292, 956)], BLANKET_HI, 1.4)
    p.line([(124, 968), (1296, 968)], TIMBER_HI, 1.6)
    for x in CL_X:
        p.rect(x, 110, x + 300, 800, LOCKER, INK, 3.4)
        p.line([(x + 6, 116), (x + 294, 116)], LOCKER_HI, 2)
        enamel_plate(p, x + 40, 126, x + 260, 176, 3)
        for sx in (x + 50, x + 250):
            screw(p, sx, 151, 4)
        card_holder(p, x + 20, 192, x + 280, 360, inset=10, w=3)
        p.line([(x + 4, 368), (x + 296, 368)], INK, 3)
        # opening
        p.rect(x + 10, 376, x + 290, 800, LOCK_IN, INK, 3)
        p.rect(x + 10, 376, x + 26, 800, LOCKER_HI, INK, 2.4)    # door edge
        p.line([(x + 30, 384), (x + 286, 384)], mix(LOCK_IN, LOCKER, 0.35), 3)
        # shelf
        sh = p.layer()
        sh.rect(x + 28, 584, x + 290, 612, NIGHT, None)
        p.put_soft(sh, 4, 0.6)
        p.rect(x + 26, 560, x + 290, 584, TIMBER, INK, 3)
        p.line([(x + 30, 565), (x + 286, 565)], TIMBER_HI, 2)
        # brass plate, up
        p.rect(x + 130, 586, x + 170, 606, BRASS_HI, INK, 2.4, r=2)
        p.line([(x + 134, 590), (x + 166, 590)], PALE, 1.4)
        p.ell(x + 150, 600, 3, 3, BRASS_LO, INK, 1.2)
        # rod and empty hanger
        p.line([(x + 28, 620), (x + 290, 620)], BRASS_LO, 5)
        p.line([(x + 28, 618), (x + 290, 618)], BRASS_HI, 1.4)
        hanger(p, x + 158, 612, 70, 40)
        p.rect(x + 28, 788, x + 290, 800, mix(LOCK_IN, LOCKER_DK, 0.6), None)
        p.line([(x + 28, 790), (x + 290, 790)], mix(LOCKER, LOCK_IN, 0.4), 2)
    return p


def paint_sprite(fn, w, h, box, lw):
    def go(rng):
        p = Pen(w, h, rng)
        fn(p, Box(*box), lw, True)
        return p
    return go


def paint_c_plate_down(rng):
    p = Pen(40, 20, rng)
    p.rect(1, 1, 39, 6, BRASS_HI, INK, 1.6, r=1)                 # the hinge edge, still bright
    p.rect(3, 5, 37, 19, BRASS_LO, INK, 1.8, r=2)                # the plate dropped, showing its back
    p.line([(6, 8), (34, 8)], BRASS, 1.2)
    p.ell(20, 14, 2.4, 2.4, BRASS_HI, INK, 1)
    return p


def paint_c_venn_open(rng):
    p = Pen(W, H, rng)
    nested(p, 724, 590, 1004, 800, 7, (14.5, 6, 14.5, 12), LOCK_IN, NIGHT, (864, 640))
    return p


def paint_c_token_rubbing(rng):
    p = Pen(200, 150, rng)
    # the rubbing, pinned beside the nail
    sh = p.layer()
    sh.rect(142, 20, 196, 112, INK, None)
    p.put_soft(sh, 3, 0.35)
    p.poly([(138, 14), (192, 16), (194, 108), (140, 106)], PAPER_HI, INK, 2)
    lay = p.layer()
    lay.ell(166, 60, 22, 32, GRAPHITE, None)
    p.put_soft(lay, 4, 0.45)
    for k in range(3):  # three dark cut strokes (the seal)
        x = 156 + k * 10
        p.line([(x, 42), (x + 4, 80)], NIGHT, 3.2)
    p.ell(165, 20, 3.4, 3.4, BRASS_HI, INK, 1.2)                  # the pin
    # the brass half-token hanging from the nail at (100, 20)
    cx, cy, r = 100, 60, 38
    pts = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(0, 181, 6)]
    # the straight broken edge along the top, notched
    notch = []
    for k in range(9):
        x = cx - r + (2 * r) * k / 8
        notch.append((x, cy - (6 if k % 2 else 0)))
    sh = p.layer()
    sh.poly([(x + 3, y + 3) for x, y in pts + notch], INK, None)
    p.put_soft(sh, 2, 0.4)
    p.poly(pts + notch, BRASS, INK, 2.4)
    p.arc(cx, cy, r - 7, r - 7, 20, 160, BRASS_LO, 2)
    p.arc(cx, cy, r - 3, r - 3, 30, 80, BRASS_HI, 2)
    # its hole, and the string up to the nail
    p.ell(cx, cy + 4, 5, 5, NIGHT, INK, 1.4)
    p.line([(cx - 3, cy + 1), (cx, 20), (cx + 3, cy + 1)], mix(PAPER, INK, 0.4), 1.6)
    p.ell(cx, 20, 3, 3, STEEL_HI, INK, 1.2)
    return p


def paint_c_cup_mark(rng):
    p = Pen(170, 40, rng)
    lead = mix(GRAPHITE, PAPER, 0.15)
    p.line([(20, 6), (24, 12), (124, 12), (128, 6)], lead, 2.2)
    p.line([(36, 5), (40, 17), (108, 17), (112, 5)], lead, 1.8)
    p.line([(134, 20), (142, 32), (162, 6)], lead, 3.0)
    return p


# ----------------------------------------------------------------------------- close-up: slope

def push_key(p, x0, y0, x1, y1, pressed=False):
    if not pressed:
        p.rect(x0 + 4, y1 - 20, x1 - 4, y1, BRASS_LO, INK, 2.6, r=6)      # the skirt
        p.rect(x0, y0, x1, y1 - 16, BRASS, INK, 3, r=12)
        p.line([(x0 + 14, y0 + 6), (x1 - 14, y0 + 6)], BRASS_HI, 3)
        p.rect(x0 + 40, y0 + 24, x1 - 40, y0 + 76, ENAMEL, INK, 2.6, r=4)
    else:
        p.rect(x0, y0 + 10, x1, y1, mix(BRASS, BRASS_LO, 0.5), INK, 3, r=12)
        p.line([(x0 + 14, y0 + 16), (x1 - 14, y0 + 16)], BRASS, 2)
        p.rect(x0 + 40, y0 + 34, x1 - 40, y0 + 86, mix(ENAMEL, PAPER, 0.4), INK, 2.6, r=4)


def stud(p, x0, x1, y0, y1, pointing):
    cx, cy, r = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2
    sh = p.layer()
    sh.ell(cx + 3, cy + 4, r, r, INK, None)
    p.put_soft(sh, 3, 0.4)
    p.ell(cx, cy, r, r, BRASS, INK, 3)
    p.ell(cx, cy, r - 7, r - 7, BRASS_HI, mix(BRASS_LO, INK, 0.2), 2)
    s = -1 if pointing == "left" else 1
    p.poly([(cx - 9 * s, cy - 14), (cx + 9 * s, cy), (cx - 9 * s, cy + 14), (cx - 3 * s, cy)], INK, None)


def paint_c_slope(rng):
    p = Pen(W, H, rng, bg=WALNUT)
    # walnut surround, grain lines
    for k in range(26):
        y = rng.uniform(0, H)
        p.line([(-4, y), (W + 4, y + rng.uniform(-8, 8))], mix(WALNUT, WALNUT_DK, 0.5), rng.uniform(1.2, 2.4))
    p.rect(-4, -4, W + 4, 60, WALNUT_DK, INK, 3)
    p.line([(-4, 52), (W + 4, 52)], BRASS_LO, 4)
    p.rect(110, 120, 1338, 650, BAIZE, INK, 3)
    p.line([(116, 126), (1332, 126)], BAIZE_HI, 2)
    for x0, lx in ((160, 300), (808, 948)):
        sh = p.layer()
        sh.rect(x0 + 6, 210, x0 + 486, 630, INK, None)
        p.put_soft(sh, 6, 0.35)
        p.rect(x0, 200, x0 + 480, 620, BAIZE_HI, INK, 3)
        p.rect(x0 + 10, 210, x0 + 470, 596, mix(BAIZE, BAIZE_HI, 0.55), mix(BAIZE_DK, INK, 0.3), 1.6)
        p.rect(x0, 598, x0 + 480, 620, BRASS, INK, 3, r=3)
        p.line([(x0 + 8, 602), (x0 + 472, 602)], BRASS_HI, 2)
        enamel_plate(p, lx, 160, lx + 200, 192, 2.6)
        screw(p, lx + 10, 176, 3)
        screw(p, lx + 190, 176, 3)
    # amendment strip: ruled paper in a brass frame, three blank wheel windows
    sh = p.layer()
    sh.rect(166, 668, 1296, 790, INK, None)
    p.put_soft(sh, 5, 0.35)
    p.rect(160, 660, 1288, 780, BRASS, INK, 3, r=4)
    p.rect(172, 670, 1276, 770, PAPER_HI, mix(BRASS_LO, INK, 0.3), 2)
    for y in range(684, 770, 14):
        p.line([(176, y), (1272, y)], mix(PAPER, STORM, 0.18), 1.2)
    for a, b in ((236, 448), (620, 832), (1004, 1216)):
        p.rect(a - 6, 684, b + 6, 756, BRASS_LO, INK, 2.6, r=3)
        p.rect(a, 690, b, 750, ENAMEL, INK, 2.4)
        lay = p.layer()
        lay.rect(a, 690, b, 702, INK, None)
        lay.rect(a, 738, b, 750, INK, None)
        p.put_soft(lay, 3, 0.25)
    for x0 in (160, 544, 928):
        stud(p, x0, x0 + 64, 688, 752, "left")
    for x0 in (456, 840, 1224):
        stud(p, x0, x0 + 64, 688, 752, "right")
    # keys and the pencil groove
    for x0 in (160, 1008):
        p.rect(x0 - 8, 812, x0 + 288, 948, WALNUT_DK, INK, 2.4, r=14)
        push_key(p, x0, 820, x0 + 280, 940)
    p.rect(512, 864, 908, 906, WALNUT_DK, INK, 2.6, r=14)
    p.rect(518, 880, 902, 900, mix(WALNUT_DK, NIGHT, 0.4), None, r=8)
    p.poly([(530, 872), (868, 872), (896, 885), (868, 898), (530, 898)], mix(SEAGLASS, INK, 0.2), INK, 2.4)
    p.poly([(868, 872), (896, 885), (868, 898)], WOOD, INK, 2)
    p.poly([(888, 881), (896, 885), (888, 889)], GRAPHITE, None)
    p.line([(534, 878), (864, 878)], mix(SEAGLASS, PALE, 0.3), 1.6)
    p.rect(526, 870, 540, 900, BRASS_LO, INK, 1.6)
    # the hinge along the bottom
    p.rect(-4, 1000, W + 4, 1012, BRASS_LO, INK, 2.6)
    return p


def paint_c_card(rng):
    p = Pen(400, 300, rng)
    sh = p.layer()
    sh.rect(10, 10, 398, 298, INK, None)
    p.put_soft(sh, 4, 0.35)
    p.rect(4, 4, 392, 292, CARD, INK, 2.6, r=4)
    p.line([(12, 70), (384, 70)], RED, 2.6)
    for y in range(102, 280, 26):
        p.line([(14, y), (382, y)], mix(CARD, STORM, 0.22), 1.2)
    p.rect(270, 16, 390, 60, None, mix(CARD, INK, 0.55), 1.6)
    p.ell(30, 36, 8, 8, mix(STORM, INK, 0.4), INK, 1.4)
    return p


def paint_c_sketch(rng):
    p = Pen(400, 300, rng)
    # torn top edge
    top = [(4, 18)]
    x = 4
    while x < 392:
        x += rng.uniform(8, 16)
        top.append((min(392, x), 14 + rng.uniform(-5, 5)))
    pts = top + [(392, 292), (4, 292)]
    sh = p.layer()
    sh.poly([(x + 5, y + 5) for x, y in pts], INK, None)
    p.put_soft(sh, 4, 0.35)
    p.poly(pts, PAPER_HI, INK, 2)
    for y in range(52, 290, 24):
        p.line([(10, y), (386, y)], mix(PAPER_HI, STORM, 0.15), 1.1)
    p.line([(46, 22), (46, 290)], mix(PAPER_HI, RED, 0.35), 1.2)
    lead = mix(GRAPHITE, PAPER, 0.1)
    # the cup, large, pencil line only (upper 70%)
    b = Box(110, 40, 300, 200)
    p.line([b(0.02, 0.06), b(0.72, 0.06)], lead, 2.2)
    p.line(bezier(b(0.02, 0.06), b(0.04, 0.70), b(0.20, 0.86)), lead, 2.2)
    p.line(bezier(b(0.54, 0.86), b(0.70, 0.70), b(0.72, 0.06)), lead, 2.2)
    p.line([b(0.18, 0.86), b(0.18, 1.0), b(0.56, 1.0), b(0.56, 0.86), b(0.18, 0.86)], lead, 2.0)
    hx, hy = b(0.75, 0.42)
    p.arc(hx, hy, b.w * 0.16, b.h * 0.24, 270, 450, lead, 2.2)
    p.arc(hx, hy, b.w * 0.09, b.h * 0.15, 270, 450, lead, 1.6)
    p.line([b(0.04, 0.18), b(0.70, 0.18)], lead, 1.2)
    # the staple, drawn over and over, and a little enlarged beside it
    sx, sy = b(0.91, 0.42)
    for k in range(3):
        p.rect(sx - 10 + k * 0.6, sy - 6 - k * 0.5, sx + 10, sy + 1, None, lead, 1.6)
    p.line([(sx - 12, sy + 4), (sx + 12, sy - 2)], lead, 1.2)
    p.ell(sx + 50, sy - 30, 26, 18, None, lead, 1.4)
    p.rect(sx + 34, sy - 36, sx + 66, sy - 24, None, lead, 2.0)
    p.line([(sx + 30, sy - 18), (sx + 14, sy - 4)], lead, 1.2)
    # hatching under the bowl
    for k in range(8):
        a = b(0.10 + k * 0.06, 0.78)
        p.line([a, (a[0] + 10, a[1] + 14)], mix(lead, PAPER_HI, 0.35), 1.1)
    return p


def paint_c_key_down(rng):
    p = Pen(280, 120, rng)
    p.rect(0, 0, 280, 120, WALNUT_DK, None)
    sh = p.layer()
    sh.rect(0, 0, 280, 16, INK, None)
    p.put_soft(sh, 4, 0.55)
    push_key(p, 0, 0, 280, 120, pressed=True)
    return p


# ----------------------------------------------------------------------------- registry

def _stage(fn, st):
    return lambda r: fn(r, st)


ASSETS = [  # name, seed index, painter, opaque, grain
    ("view_a", 0, _stage(paint_view_a, 1), True, True),
    ("view_a_s2", 0, _stage(paint_view_a, 2), True, True),
    ("view_a_s3", 0, _stage(paint_view_a, 3), True, True),
    ("view_a_s4", 0, _stage(paint_view_a, 4), True, True),
    ("view_a_sever", 0, _stage(paint_view_a, 0), True, True),
    ("view_b", 1, _stage(paint_view_b, 1), True, True),
    ("view_b_s2", 1, _stage(paint_view_b, 2), True, True),
    ("view_b_s3", 1, _stage(paint_view_b, 3), True, True),
    ("view_b_s4", 1, _stage(paint_view_b, 4), True, True),
    ("view_b_sever", 1, _stage(paint_view_b, 0), True, True),
    ("a_top_pencils", 10, paint_top("pencils"), False, False),
    ("a_top_glove", 11, paint_top("glove"), False, False),
    ("a_top_cup", 12, paint_top("cup"), False, False),
    ("a_top_calipers", 13, paint_top("calipers"), False, False),
    ("a_in_cup", 14, paint_in("cup"), False, False),
    ("a_in_calipers", 15, paint_in("calipers"), False, False),
    ("a_in_pencils", 16, paint_in("pencils"), False, False),
    ("a_in_glove", 17, paint_in("glove"), False, False),
    ("a_cup_mark", 18, paint_a_cup_mark, False, False),
    ("a_venn_open", 19, paint_a_venn_open, False, False),
    ("a_dry_ring", 20, paint_a_dry_ring, False, False),
    ("a_steam", 21, paint_a_steam, False, False),
    ("a_dent_venn", 22, dent(750, False), False, False),
    ("a_dent_rook", 23, dent(750, True), False, False),
    ("a_dent_hart", 24, dent(1146, True), False, False),
    ("a_dent_ives", 25, dent(1146, False), False, False),
    ("b_dent_doane", 26, dent(858, False), False, False),
    ("b_dent_lusk", 27, dent(858, True), False, False),
    ("b_dent_tull", 28, dent(1192, True), False, False),
    ("b_dent_bell", 29, dent(1192, False), False, False),
] + [(f"a_fan_b{b}", 30 + b, paint_fan(b), False, False) for b in range(1, 8)] + [
    ("a_fan_sever", 38, paint_fan(0), False, False),
    ("a_fan_rain_0", 39, paint_rain("light"), False, False),
    ("a_fan_rain_1", 40, paint_rain("light"), False, False),
    ("a_fan_rain_heavy_0", 41, paint_rain("heavy"), False, False),
    ("a_fan_rain_heavy_1", 42, paint_rain("heavy"), False, False),
    ("a_fan_rain_hang", 43, paint_rain("hang"), False, False),
    ("a_fan_frame", 44, paint_fan_frame, False, False),
    ("b_curtain_shape", 45, paint_b_curtain_shape, False, False),
    ("b_pigeonhole_open", 46, paint_b_pigeonhole_open, False, False),
    ("c_lockers", 50, paint_c_lockers, True, True),
    ("c_cup", 51, paint_sprite(draw_cup, 150, 120, (8, 6, 142, 118), 3.0), False, False),
    ("c_calipers", 52, paint_sprite(draw_calipers, 120, 200, (6, 4, 114, 198), 2.8), False, False),
    ("c_pencils", 53, paint_sprite(draw_pencils, 110, 170, (6, 4, 104, 168), 2.8), False, False),
    ("c_glove", 54, paint_sprite(draw_glove, 190, 120, (6, 6, 184, 118), 2.8), False, False),
    ("c_plate_down", 55, paint_c_plate_down, False, False),
    ("c_venn_open", 56, paint_c_venn_open, False, False),
    ("c_token_rubbing", 57, paint_c_token_rubbing, False, False),
    ("c_cup_mark", 58, paint_c_cup_mark, False, False),
    ("c_slope", 59, paint_c_slope, True, True),
    ("c_card", 60, paint_c_card, False, False),
    ("c_sketch", 61, paint_c_sketch, False, False),
    ("c_key_down", 62, paint_c_key_down, False, False),
]


def main(argv):
    pats = argv or ["*"]
    for name, k, fn, opaque, gr in ASSETS:
        if not any(fnmatch.fnmatch(name, pat) for pat in pats):
            continue
        rng = rng_for(k)
        res = fn(rng)
        im = res.done() if isinstance(res, Pen) else res
        if gr:
            im = grain(im, rng_for(1000 + k))
        save(im, name, opaque)


if __name__ == "__main__":
    main(sys.argv[1:])
