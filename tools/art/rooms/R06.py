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
BAIZE = (62, 92, 78)
BAIZE_DK = (48, 72, 62)
BAIZE_HI = (80, 112, 96)
WALNUT = (96, 78, 62)
WALNUT_DK = (74, 60, 48)
WALNUT_HI = (120, 100, 80)
NIGHT = (10, 16, 24)            # near-black navy
GLASS = (128, 132, 134)
PALE = (238, 236, 226)

# repaint (art direction pass 2): darker leather glove, wool blankets, sheets, floorboards
GLOVE = (104, 80, 58)
GLOVE_DK = (78, 58, 42)
GLOVE_HI = (130, 102, 76)
NAVY_WOOL = (50, 68, 86)
NAVY_WOOL_DK = (38, 52, 68)
NAVY_WOOL_HI = (68, 88, 106)
SEA_WOOL = (82, 108, 100)
SEA_WOOL_DK = (64, 86, 80)
SEA_WOOL_HI = (104, 128, 118)
SHEET = (212, 206, 188)
SHEET_DK = (180, 176, 162)
ERASER = (170, 112, 102)        # a worn red rubber cap (red mixed into paper, never orange)
TIDE = (98, 86, 72)             # brown-grey tide stain
TIDE_DK = (70, 60, 50)

# stage tables: wall, floor boards, grade target and amount, vignette depth, ambient multiply
# (the room's base light), and the motivated sources (see light_shapes()).
STAGE = {
    1: dict(wall=(122, 142, 132), floor=(104, 82, 66), tgt=(40, 62, 82), amt=0.00, vig=0.18, amb=(0.74, 0.76, 0.80)),
    2: dict(wall=(112, 134, 128), floor=(98, 78, 64), tgt=(40, 62, 82), amt=0.05, vig=0.22, amb=(0.66, 0.69, 0.75)),
    3: dict(wall=(104, 126, 125), floor=(90, 74, 62), tgt=(34, 56, 74), amt=0.10, vig=0.26, amb=(0.62, 0.65, 0.71)),
    4: dict(wall=(100, 121, 126), floor=(82, 69, 60), tgt=(34, 56, 74), amt=0.16, vig=0.30, amb=(0.52, 0.56, 0.63)),
    0: dict(wall=(150, 160, 148), floor=(112, 92, 74), tgt=(206, 200, 186), amt=0.07, vig=0.08, amb=(0.92, 0.92, 0.92)),
}

# geometry: view A
OPEN_X = {"bell": 48, "rook": 148, "venn": 248, "ives": 348}
SHUT_X = {"lusk": 448, "doane": 512, "hart": 576, "tull": 640}
FAN_GLASS = (747, 154, 1313, 282)                 # 1.4x the first pass: it carries the weather
FAN_OUT = (FAN_GLASS[0] - 16, FAN_GLASS[1] - 14, FAN_GLASS[2] + 16, FAN_GLASS[3] + 14)
FAN_BARS = tuple(int(round(FAN_GLASS[0] + (FAN_GLASS[2] - FAN_GLASS[0]) * k / 5)) for k in range(1, 5))
SHELF_Y = 560
UP = dict(pillow=(418, 446), matt=(440, 480), rail=(480, 502))
LO = dict(pillow=(666, 694), matt=(690, 730), rail=(730, 752))

# The bunks: [mattress x0, x1, posts, tag x, (upper bed, lower bed)]. Both frames sit inside the
# picture (the right post 40 px from the edge), so nothing reads as an accidental crop.
BUNKS_A = [
    (748, 1048, [(724, 748), (1048, 1072)], 858, ("rook", "venn")),
    (1108, 1384, [(1084, 1108), (1384, 1408)], 1206, ("hart", "ives")),
]
BUNKS_B = [
    (856, 1092, [(832, 856), (1092, 1116)], 934, ("lusk", "doane")),
    (1148, 1384, [(1124, 1148), (1384, 1408)], 1226, ("tull", "bell")),
]
# wool per bed: navy or sea-glass; Venn's lower bunk is a tight sheet with the blanket folded
# square at its foot (as his bunk line says)
WOOL = {"rook": "navy", "venn": "sheet", "hart": "sea", "ives": "navy",
        "lusk": "sea", "doane": "navy", "tull": "navy", "bell": "sea"}
# hollow depth: Venn's (the P08 notice) is the deepest and freshest
HOLLOW = {"venn": 1.35, "doane": 1.1, "bell": 1.0, "ives": 1.0, "rook": 0.95, "lusk": 0.95, "hart": 0.9, "tull": 0.9}

# geometry: view B
CURTAIN_FOLDS = (36, 112, 178, 244, 310, 374, 430, 476)
LAMP_B = (640, 82)                                 # the caged bulkhead lamp on the beam over the calendar


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


# ----------------------------------------------------------------------------- stage grading + light

def _falloff(src, radius, power=1.0, floor=0.0):
    """L image (logical size): 255 at `src`, falling to `floor` at `radius`."""
    small = Image.new("L", (W // 8, H // 8), 0)
    px = small.load()
    for y in range(small.size[1]):
        for x in range(small.size[0]):
            d = math.hypot(x * 8 - src[0], y * 8 - src[1]) / radius
            v = max(0.0, 1.0 - d) ** power
            px[x, y] = int(255 * (floor + (1 - floor) * v))
    return small.resize((W, H), Image.BICUBIC)


def light_shapes(st, view):
    """The one motivated source per wall, as (polygon, falloff source, radius, strength, tint, glow).
    A: cold daylight from the fanlight, falling down-left over the locker tops and the top bunks;
       from band 6 (s4) it falls straight down onto the bunks, onto the hollows.
    B: the caged bulkhead lamp over the calendar: a pool over the calendar and the writing slope,
       warm brass to band 3, cold sea-glass from band 4 (s3). Sever: ordinary pale daylight."""
    gx0, gy0, gx1, gy1 = FAN_GLASS
    out = []
    if view == "a":
        day = ((222, 240, 248), (22, 32, 38))
        if st == 4:
            poly = [(gx0 + 30, gy1), (gx1 - 10, gy1), (1430, 800), (1300, 905), (760, 905), (700, 760)]
            out.append((poly, ((gx0 + gx1) / 2, gy1), 760, 1.0, (190, 222, 214), (0, 14, 12)))
        else:
            poly = [(gx0, gy0 + 10), (gx1, gy1), (1130, 760), (720, 700), (430, 330), (430, 226)]
            out.append((poly, (gx1 - 120, gy0 + 40), 980, 0.95 if st else 1.0, *day))
    else:
        lx, ly = LAMP_B
        if st == 0:
            poly = [(470, 120), (1448, 120), (1448, 900), (470, 900)]
            out.append((poly, (1100, 140), 1300, 0.5, (238, 238, 230), (6, 6, 4)))
        else:
            cold = st in (3, 4)
            tint, glow = ((196, 232, 220), (0, 12, 10)) if cold else ((255, 232, 192), (20, 12, 0))
            poly = [(lx - 40, ly + 30), (lx + 40, ly + 30), (860, 724), (440, 724)]
            out.append((poly, (lx, ly + 40), 720, 1.0, tint, glow))
    return out


def lighting(im, st, view):
    cfg = STAGE[st]
    amb = tuple(int(255 * a) for a in cfg["amb"])
    out = ImageChops.multiply(im, Image.new("RGB", im.size, amb))
    for poly, src, radius, strength, tint, glow in light_shapes(st, view):
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).polygon(poly, fill=255)
        m = m.filter(ImageFilter.GaussianBlur(5))
        m = ImageChops.multiply(m, _falloff(src, radius, 0.8, 0.25))
        if strength < 1.0:
            m = m.point(lambda v: int(v * strength))
        lit = ImageChops.multiply(im, Image.new("RGB", im.size, tint))
        lit = ImageChops.add(lit, Image.new("RGB", im.size, glow))
        out = Image.composite(lit, out, m)
    return out


def graded(p, st, labels, view="a"):
    """Flatten a plate Pen: colder grade, the room's ambient and its one light, soft vignette.
    Label fields take a third of the room's change, so they always read pale."""
    im = p.done().convert("RGB")
    cfg = STAGE[st]
    crops = [(r, im.crop(r)) for r in labels]
    if cfg["amt"]:
        im = Image.blend(im, Image.new("RGB", im.size, cfg["tgt"]), cfg["amt"])
    im = lighting(im, st, view)
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
        c = Image.blend(c, im.crop(r), 0.3)
        im.paste(c, r[:2])
    return im


def contact(p, pts, a=0.3):
    """A flat, hard-edged contact shadow (INK at a), offset down-right by the caller."""
    lay = p.layer()
    lay.poly(pts, INK, None)
    p.put(lay, a)


def contact_rect(p, x0, y0, x1, y1, a=0.3):
    contact(p, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], a)


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
    # wainscot planks, cap rail
    p.rect(-4, 620, W + 4, 896, WAINS, None)
    for x in range(30, W, 48):
        p.line([(x, 628), (x, 894)], WAINS_DK, 3)
        p.line([(x + 3, 628), (x + 3, 894)], mix(WAINS, STORM_HI, 0.8), 1.2)
    p.rect(-4, 614, W + 4, 628, FRAME, INK, 3)
    p.line([(-4, 618), (W + 4, 618)], FRAME_HI, 1.5)
    # skirting: a dark timber board where the wall meets the floor
    p.rect(-4, 884, W + 4, 908, mix(TIMBER_DK, INK, 0.45), INK, 3)
    p.line([(-4, 888), (W + 4, 888)], mix(TIMBER_DK, PAPER, 0.08), 1.4)
    # floorboards: restrained-brown timber, seams level at the office's spacing, butt joints
    # staggered, a little grain
    fl = cfg["floor"]
    p.rect(-4, 908, W + 4, H + 4, fl, None)
    y, k = 908, 0
    while y < H:
        hgt = 42
        tone = mix(fl, TIMBER_DK if k % 2 else TIMBER_HI, 0.10)
        p.rect(-4, y, W + 4, y + hgt, tone, None)
        for g in range(3):
            gy = y + 9 + g * 11 + rng.uniform(-2, 2)
            gx = rng.uniform(-40, W)
            gl = rng.uniform(140, 420)
            pts = [(gx + t * gl / 8, gy + 1.4 * math.sin(t * 0.9 + gx)) for t in range(9)]
            p.line(pts, mix(tone, INK, 0.16), 1.0)
        x = rng.uniform(40, 360)
        while x < W:
            p.line([(x, y + 2), (x, y + hgt - 2)], mix(fl, INK, 0.45), 2)
            p.line([(x + 2, y + 3), (x + 2, y + hgt - 3)], mix(fl, PAPER, 0.10), 1.0)
            x += rng.uniform(380, 560)
        p.line([(-4, y + hgt), (W + 4, y + hgt)], mix(fl, INK, 0.5), 2.4)
        p.line([(-4, y + 2), (W + 4, y + 2)], mix(fl, PAPER, 0.12), 1.2)
        y += hgt
        k += 1
    p.line([(-4, 908), (W + 4, 908)], INK, 3)


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
    """The damp. A: a tide stain spreading under the fanlight. B: along the ceiling beam.
    Band 4+ grows runs that stop dead mid-wall. Brown-grey water stains, darker at the bottom
    edge with a hard tidemark; on the sever plates the same shapes, dry and only a little
    lighter than the wall (never white)."""
    if st == 1:
        return
    rng = rng_for(500 if view == "a" else 501)
    wall = STAGE[st]["wall"]
    if view == "a":
        x0, x1, top, depth = FAN_OUT[0] - 10, FAN_OUT[2] + 10, FAN_OUT[3] + 12, {2: 34, 3: 52, 4: 66, 0: 52}[st]
        runs = [(780, 384, 9), (846, 370, 7), (930, 396, 11), (1012, 378, 8), (1104, 362, 9),
                (1196, 392, 10), (1290, 376, 7)]
    else:
        x0, x1, top, depth = 470, W + 70, 128, {2: 50, 3: 80, 4: 104, 0: 80}[st]
        runs = [(812, 400, 9), (884, 372, 7), (1012, 408, 11), (1066, 368, 7), (1214, 396, 10),
                (1298, 360, 8), (1404, 388, 9)]
    prof = _profile(rng, x0, x1)
    if st == 0:
        body, edge, lip = mix(wall, TIDE, 0.16), mix(wall, TIDE, 0.34), mix(wall, TIDE, 0.24)
    else:
        k = {2: 0.0, 3: 0.12, 4: 0.22}[st]
        body = mix(wall, TIDE, 0.30 + k)
        edge = mix(TIDE_DK, INK, 0.15 + k)
        lip = mix(wall, TIDE_DK, 0.55 + k * 0.5)
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
            run_pts.append((pts, rx, end, wd))
    p.put(lay, 0.94)
    # darker towards the bottom edge: a band of the darker stain inside the rim
    band = p.layer()
    band.poly(outline + [(x, y - 7) for x, y in reversed(outline)], lip, None)
    for pts, rx, end, wd in run_pts:
        band.ell(rx, end - 2, wd * 0.8, wd * 0.9, lip, None)
    p.put(band, 0.8)
    # tidemarks: an older faint line inside, the hard dark rim at the edge
    inner_col = mix(body, edge, 0.35)
    p.line(inner, inner_col, 1.6)
    if st in (3, 4):
        p.line([(x, top + 2 + (y - top - 2) * 0.8) for x, y in outline], inner_col, 1.4)
    p.line(outline, edge, 2.6 if st else 1.8)
    for pts, rx, end, wd in run_pts:
        n = len(pts)
        p.line(pts[2:n - 2], edge, 2.2 if st else 1.4)


def blisters(p, st, xs, y):
    """Band 6-7: eight damp patches the size of a hand, evenly spaced along the wainscot cap,
    flat and low in contrast: wet coming through the paint from behind, each with a tidemark."""
    wall = STAGE[st]["wall"]
    for i, x in enumerate(xs):
        rng = rng_for(600 + i)
        pts = []
        for k in range(18):
            a = k / 18 * math.tau
            rr = 1.0 + 0.16 * math.sin(3 * a + rng.uniform(0, 6.28)) + rng.uniform(-0.06, 0.06)
            pts.append((x + 11 * rr * math.cos(a), y + 2 + 14 * rr * math.sin(a)))
        lay = p.layer()
        lay.poly(pts, mix(wall, TIDE_DK, 0.26), None)
        lay.poly([(x + (px - x) * 0.6, y + 4 + (py - y - 2) * 0.6) for px, py in pts], mix(wall, TIDE_DK, 0.38), None)
        p.put(lay, 0.85)
        p.line(pts + [pts[0]], mix(wall, TIDE_DK, 0.55), 1.2)


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


BACK = (44, 62, 60)              # a locker's back wall: dark sea-glass planks
BACK_DK = (32, 46, 46)
DUST = (150, 140, 120)


def locker_back(p, x0, y0, x1, y1, plank=18, lw=1.6):
    p.rect(x0, y0, x1, y1, BACK, None)
    x = x0 + plank * 0.6
    while x < x1 - 3:
        p.line([(x, y0 + 2), (x, y1 - 2)], BACK_DK, lw * 1.4)
        p.line([(x + lw * 1.2, y0 + 2), (x + lw * 1.2, y1 - 2)], mix(BACK, SEAGLASS, 0.35), lw * 0.6)
        x += plank
    # the top of the cavity in its own shadow
    sh = p.layer()
    sh.rect(x0, y0, x1, y0 + (y1 - y0) * 0.06, NIGHT, None)
    p.put(sh, 0.45)


def coat_hook(p, x, y, s=1.0):
    """A brass coat hook on the back wall, with its flat shadow."""
    sh = p.layer()
    sh.poly([(x - 3 * s + 3 * s, y + 3 * s), (x + 3 * s + 3 * s, y + 3 * s), (x + 3 * s + 3 * s, y + 18 * s),
             (x + 10 * s + 3 * s, y + 22 * s), (x + 3 * s, y + 24 * s)], INK, None)
    p.put(sh, 0.4)
    p.rect(x - 4 * s, y - 2 * s, x + 4 * s, y + 5 * s, BRASS_LO, INK, 1.0 * s)
    p.line([(x, y + 3 * s), (x, y + 16 * s), (x + 3 * s, y + 20 * s), (x + 8 * s, y + 18 * s)], INK, 4.2 * s)
    p.line([(x, y + 3 * s), (x, y + 16 * s), (x + 3 * s, y + 20 * s), (x + 8 * s, y + 18 * s)], BRASS, 2.2 * s)


def dusty_shelf(p, x0, x1, y, cx, sq, h=12, lw=2.0):
    """A shelf plank: a film of dust along its top and a clean square where something stood,
    with its flat contact shadow on the back wall below."""
    contact_rect(p, x0 + 4, y + h, x1, y + h + h * 0.9, 0.45)
    p.rect(x0, y, x1, y + h, TIMBER, INK, lw)
    p.line([(x0 + 2, y + h * 0.25), (x1 - 2, y + h * 0.25)], TIMBER_HI, lw * 0.7)
    film = p.layer()
    film.rect(x0 + lw, y + lw * 0.5, x1 - lw, y + h * 0.42, DUST, None)
    film.rect(cx - sq / 2, y + lw * 0.5, cx + sq / 2, y + h * 0.42, TIMBER_DK, None)
    p.put(film, 0.85)
    p.line([(cx - sq / 2, y + lw * 0.5), (cx - sq / 2, y + h * 0.42)], mix(DUST, PALE, 0.4), lw * 0.5)
    p.line([(cx + sq / 2, y + lw * 0.5), (cx + sq / 2, y + h * 0.42)], mix(DUST, PALE, 0.4), lw * 0.5)


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
    # the opening: back planks, its top in shadow
    p.rect(x + 10, 340, x + 90, 886, LOCK_IN, INK, 2.6)
    locker_back(p, x + 16, 343, x + 88, 884, plank=14, lw=1.2)
    # the door leaf seen on edge at the left of the opening, its shadow on the back
    contact_rect(p, x + 16, 343, x + 22, 884, 0.4)
    p.rect(x + 10, 340, x + 16, 886, LOCKER_HI, INK, 1.6)
    coat_hook(p, x + 34, 372, 0.8)
    coat_hook(p, x + 70, 372, 0.8)
    # shelf plank with its dust square, its brass plate
    dusty_shelf(p, x + 16, x + 90, 560, x + 52, 30, 12, 2.0)
    p.rect(x + 42, 572, x + 58, 580, BRASS_HI, INK, 1.4)
    # hanger rod and the empty hanger
    contact_rect(p, x + 18, 602, x + 90, 605, 0.4)
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

def wool(style):
    if style == "navy":
        return NAVY_WOOL, NAVY_WOOL_DK, NAVY_WOOL_HI
    if style == "sea":
        return SEA_WOOL, SEA_WOOL_DK, SEA_WOOL_HI
    return SHEET, SHEET_DK, PAPER_HI


def sack(p, x0, x1, y0, y1, lw=2.4, fill=PAPER_HI):
    """A pillow: a soft flattened sack with pinched corners, an ink contour and one crease."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    pts = [(x0 + 1, y0 + 2)]
    pts += bezier((x0 + 6, y0 + 5), (cx, y0 - 3), (x1 - 6, y0 + 5), 16)
    pts += [(x1 - 1, y0 + 2)]
    pts += bezier((x1 - 4, y0 + 6), (x1 + 3, cy + 2), (x1 - 2, y1), 10)
    pts += bezier((x1 - 2, y1), (cx, y1 + 2), (x0 + 2, y1), 12)
    pts += bezier((x0 + 2, y1), (x0 - 3, cy + 2), (x0 + 4, y0 + 6), 10)
    p.poly(pts, fill, INK, lw)
    # underside in shade, the crease, the seam's light
    p.line(bezier((x0 + 8, y1 - 4), (cx, y1 - 2), (x1 - 8, y1 - 4), 12), mix(fill, STORM, 0.22), 1.4)
    p.line(bezier((x1 - 34, y0 + 7), (x1 - 24, y0 + 12), (x1 - 12, y0 + 11), 8), mix(fill, STORM, 0.35), 1.4)
    p.line(bezier((x0 + 10, y0 + 4), (cx - 10, y0 + 1), (cx + 6, y0 + 3), 8), PALE, 1.2)


def _trough(t, D):
    """Depth (px) of a body's impression at t (0 at the shoulders .. 1 at the heels): the
    shoulders' width, a waist, the hip dip (deepest), the legs shallowing, two heel dents."""
    def ss(e0, e1, x):
        x = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
        return x * x * (3 - 2 * x)
    def bump(c, w):
        return math.exp(-((t - c) / w) ** 2)
    if t <= 0.0 or t >= 1.0:
        return 0.0
    d = 0.85 * ss(0.0, 0.07, t) - 0.12 * bump(0.30, 0.06) + 0.22 * bump(0.45, 0.08)
    d -= 0.45 * ss(0.52, 0.72, t) + 0.18 * ss(0.78, 0.88, t)
    d *= 1.0 - ss(0.88, 0.91, t)
    d += 0.55 * bump(0.935, 0.012) + 0.55 * bump(0.968, 0.012)    # two heel dents
    return D * max(0.0, d) * (1.0 - ss(0.985, 1.0, t))


def bed(p, x0, x1, lvl, style, hollow=0.0):
    """One bunk level, made tight: mattress, a matte wool blanket with a folded-back sheet band
    at the head and a visible fold-and-tuck at the foot, the pillow sack on top. With `hollow`
    (depth scale) a body has lain here and is not here: a head cupped into the pillow, and a
    trough down the blanket (shoulders, a hip dip, two heel dents) with the stripes pulled into it."""
    py0, py1 = lvl["pillow"]
    my0, my1 = lvl["matt"]
    col, dk, hi = wool(style)
    # mattress ticking, only seen as an edge under the blanket
    p.rect(x0, my0, x1, my1, mix(PAPER, STORM, 0.12), INK, 2.6, r=5)
    bot = my1 - 3
    p.rect(x0, my0, x1, bot, col, INK, 2.4, r=3)
    bx0, bx1 = x0 + 118, x1 - 10
    D = 16.0 * hollow

    def yoff(x, k=1.0):
        if not hollow or x <= bx0 or x >= bx1:
            return 0.0
        return _trough((x - bx0) / (bx1 - bx0), D) * k

    xs = [x0 + 3 + i * (x1 - x0 - 6) / 90 for i in range(91)]
    seg = [x for x in xs if bx0 <= x <= bx1]
    if hollow:
        # the trough: two value steps darker, deepest shade on its upper inside, a lit lower lip
        top = [(x, my0 + 1.4) for x in seg]
        low = [(x, my0 + 1.4 + yoff(x, 1.0)) for x in seg]
        p.poly(top + list(reversed(low)), mix(col, INK, 0.36 if style != "sheet" else 0.30), None)
        upper = [(x, my0 + 1.4 + yoff(x, 0.45)) for x in seg]
        p.poly(top + list(reversed(upper)), mix(col, INK, 0.52 if style != "sheet" else 0.44), None)
        p.line(low, mix(col, PAPER_HI, 0.30), 1.3)
    # two lengthwise stripes near the top (army-blanket bands), pulled down into any trough
    stripe = mix(col, PAPER, 0.30) if style != "sheet" else mix(SHEET, STORM, 0.16)
    for sy, w, k in ((my0 + 13, 2.0, 0.85), (my0 + 18, 1.2, 0.65)):
        p.line([(x, sy + yoff(x, k)) for x in xs], stripe, w)
    if style == "sheet":
        p.line(bezier((x0 + 150, my0 + 28), (x0 + 200, my0 + 31), (x0 + 250, my0 + 27), 10), SHEET_DK, 1.2)
    p.line([(x0 + 4, my0 + 2.5), (x0 + 4 + (bx0 - x0 - 4), my0 + 2.5)], hi, 1.0)
    # folded-back sheet band at the head
    sb0, sb1 = x0 + 100, x0 + 116
    if style != "sheet":
        p.rect(sb0, my0, sb1, bot, mix(SHEET, col, 0.30), INK, 1.6)
        p.line([(sb0 + 4, my0 + 3), (sb0 + 4, bot - 3)], mix(SHEET_DK, col, 0.3), 1.0)
    else:
        p.line([(sb0 + 6, my0 + 1), (sb0 + 6, bot - 1)], SHEET_DK, 1.6)
    # foot: the folded corner and the tuck under the mattress
    fx = x1 - 26
    p.poly([(fx, my0 + 1), (x1 - 1, my0 + 1), (x1 - 1, my0 + 22)], mix(col, INK, 0.22), INK, 1.4)
    p.line([(fx + 4, bot - 2), (x1 - 4, bot - 2)], mix(col, INK, 0.6), 1.4)
    p.line([(x0 + 1, my0), (x1 - 1, my0)], INK, 2.4)
    # the pillow sack
    px0, px1 = x0 + 8, x0 + 96
    sack(p, px0, px1, py0, py1)
    if hollow:
        # a head-shaped impression cupped into the pillow: one step darker, its upper inner
        # edge in shadow, a paper-hi rim on its lower lip, no black core
        cx, cy = (px0 + px1) / 2 + 5, py0 + 12
        rx, ry = 21 + 2.5 * hollow, 6.0 + 2.4 * hollow
        egg = [(cx + rx * math.cos(a / 24 * math.tau) * (1.0 - 0.10 * math.cos(a / 24 * math.tau)),
                cy + ry * math.sin(a / 24 * math.tau)) for a in range(24)]
        p.poly(egg, mix(PAPER_HI, STORM, 0.16 + 0.04 * hollow), None)
        sh = p.layer()
        sh.poly(egg, INK, None)
        sh.poly([(x, y + ry * 0.75) for x, y in egg], (0, 0, 0, 0), None)
        p.put(sh, 0.26 + 0.08 * hollow)
        p.line([pt for pt in egg if pt[1] > cy + ry * 0.55], mix(PALE, PAPER_HI, 0.1), 1.8)
        # the pillowcase drawn in toward it
        p.line([(cx - rx - 12, py0 + 5), (cx - rx + 1, cy - 1)], mix(PAPER_HI, STORM, 0.28), 1.1)
        p.line([(cx + rx + 10, py0 + 5), (cx + rx - 1, cy - 1)], mix(PAPER_HI, STORM, 0.28), 1.1)
    if style == "sheet":
        # Venn's blanket, folded square at the foot
        fb0, fb1 = x1 - 96, x1 - 10
        contact_rect(p, fb0 + 5, my0 - 4, fb1 + 5, my0 + 4, 0.3)
        p.rect(fb0, my0 - 28, fb1, my0 + 2, NAVY_WOOL, INK, 2.4, r=3)
        for k in (1, 2):
            yy = my0 - 28 + 10 * k
            p.line([(fb0 + 3, yy), (fb1 - 3, yy)], NAVY_WOOL_DK, 1.6)
        p.line([(fb0 + 4, my0 - 25), (fb1 - 4, my0 - 25)], NAVY_WOOL_HI, 1.2)


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


def bunk(p, spec, hollows=(), view="a"):
    """Two-tier bunk from a BUNKS_* spec. Contact shadows first (they lie on the wall behind),
    then each level; a hollow is painted with its own pen, so the plate around it is unchanged
    and the hollow overlays can be cut out as exact differences."""
    x0, x1, posts, tag_x, (upper, lower) = spec
    sh = p.layer()
    sh.rect(x0, UP["rail"][1], x1, UP["rail"][1] + 46, INK, None)
    p.put_soft(sh, 10, 0.18)
    for lvl in (UP, LO):
        contact_rect(p, x0 + 8, lvl["matt"][0] + 10, x1 + 9, lvl["rail"][1] + 9, 0.3)
    for a, b in posts:
        contact_rect(p, b, 346, b + 8, 896, 0.28)
        contact_rect(p, a + 4, 896, b + 10, 903, 0.35)
    for lvl, name in ((UP, upper), (LO, lower)):
        bed(p, x0, x1, lvl, WOOL[name])
        if name in hollows:
            hp = Pen(W, H, rng_for(9000 + R06_BEDS.index(name)))
            bed(hp, x0, x1, lvl, WOOL[name], HOLLOW[name])
            p.put(hp)
        rail(p, x0 - 2, x1 + 2, *lvl["rail"])
        tag(p, tag_x, lvl["rail"][0], tag_x + 80, lvl["rail"][1])
    for a, b in posts:
        post(p, a, b)


R06_BEDS = ["venn", "rook", "hart", "ives", "doane", "lusk", "tull", "bell"]


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
    contact(p, [(x1, y0 + 24), (x1 + 9, y0 + 30), (x1 + 9, y1), (x1, y1)], 0.3)
    contact_rect(p, x0 + 6, y1, x1 + 12, y1 + 7, 0.38)
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
    """A slide caliper stood upright: a long graduated beam, a thin fixed jaw at the top, the
    sliding jaw below it on its slider; the sliding jaw visibly filed shorter, its filed face
    bright brass."""
    def q(u0, v0, u1, v1, fill, w=lw):
        p.poly(b.quad(u0, v0, u1, v1), fill, INK, w)
    q(0.30, 0.02, 0.42, 1.0, BRASS)                         # the beam
    p.line([b(0.33, 0.05), b(0.33, 0.97)], BRASS_HI, max(1.0, lw * 0.5))
    n = 40 if detail else 18                                 # fine graduations down its length
    for k in range(n):
        v = 0.20 + k * (0.76 / n)
        long = k % 5 == 0
        p.line([b(0.42, v), b(0.37 if long else 0.395, v)], INK, max(0.8, lw * (0.45 if long else 0.32)))
    # the fixed jaw: thin, straight out to the right, a fine point at its tip
    p.poly(b.pts([(0.30, 0.02), (0.96, 0.02), (1.00, 0.06), (0.96, 0.10), (0.42, 0.10)]), BRASS, INK, lw)
    p.poly(b.pts([(0.30, 0.03), (0.10, 0.03), (0.06, 0.06), (0.30, 0.09)]), BRASS, INK, lw * 0.8)
    # the slider block and its thumb screw
    q(0.24, 0.13, 0.48, 0.24, BRASS_LO)
    p.ell(*b(0.21, 0.185), max(2.0, b.w * 0.05), max(2.0, b.w * 0.05), BRASS_HI, INK, max(1.0, lw * 0.6))
    # the sliding jaw: as thin as the fixed one, but filed short and square
    p.poly(b.pts([(0.48, 0.13), (0.74, 0.13), (0.74, 0.21), (0.48, 0.21)]), BRASS, INK, lw)
    p.poly(b.quad(0.70, 0.13, 0.76, 0.21), (232, 206, 140), INK, max(1.0, lw * 0.6))   # bright filed face
    if detail:
        for k in range(4):
            v = 0.14 + k * 0.018
            p.line([b(0.705, v), b(0.755, v + 0.006)], BRASS_LO, 1.0)
        p.line([b(0.80, 0.17), b(0.95, 0.17)], mix(BRASS_LO, INK, 0.3), 1.0)    # where the tip was
    p.line([b(0.30, 0.10), b(0.30, 1.0)], INK, max(1.0, lw * 0.5))


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
    """A right work glove seen back-of-hand, fingers to the right, a flared gauntlet cuff at the
    left with its seam and a thumb gusset; red cross-stitch repairs across two fingertips."""
    s = min(b.w, b.h)
    fingers = [  # (v centre, tip u, half thickness in box heights)
        (0.40, 0.95, 0.085),   # index
        (0.57, 1.00, 0.085),   # middle
        (0.73, 0.96, 0.08),    # ring
        (0.87, 0.86, 0.07),    # little
    ]
    for vc, tip, ht in reversed(fingers):
        r = b.h * ht
        p.poly(capsule(b(0.50, vc), (b(tip, vc)[0] - r, b(tip, vc)[1]), r, r), GLOVE, INK, lw)
    # thumb, rooted in a gusset
    r = b.h * 0.11
    p.poly(capsule(b(0.38, 0.46), b(0.54, 0.12), r, r * 0.85), GLOVE, INK, lw)
    # back of the hand
    palm = bezier(b(0.26, 0.30), b(0.40, 0.26), b(0.56, 0.32)) + \
        bezier(b(0.58, 0.40), b(0.60, 0.70), b(0.56, 0.96)) + \
        bezier(b(0.42, 1.0), b(0.32, 1.0), b(0.26, 0.96))
    p.poly(palm, GLOVE, INK, lw)
    # thumb gusset: a diamond inset where the thumb joins
    p.poly(b.pts([(0.36, 0.40), (0.44, 0.30), (0.50, 0.40), (0.44, 0.50)]), GLOVE_HI, INK, max(1.0, lw * 0.6))
    # the gauntlet: flared, stiffer, darker; seam at the wrist and a seam down its length
    p.poly(b.pts([(0.0, 0.08), (0.27, 0.28), (0.27, 0.98), (0.0, 1.0)]), GLOVE_DK, INK, lw)
    p.line([b(0.27, 0.30), b(0.27, 0.97)], mix(GLOVE_DK, INK, 0.5), max(1.0, lw * 0.9))
    for k in range(5 if not detail else 9):                                  # the wrist seam stitches
        v = 0.33 + k * (0.6 / (4 if not detail else 8))
        p.line([b(0.245, v), b(0.255, v + 0.03)], mix(GLOVE_HI, PAPER, 0.3), max(0.8, lw * 0.35))
    p.line([b(0.04, 0.12), b(0.12, 0.98)], mix(GLOVE_DK, INK, 0.45), max(1.0, lw * 0.5))
    p.line([b(0.01, 0.10), b(0.27, 0.29)], mix(GLOVE_HI, GLOVE_DK, 0.3), max(1.0, lw * 0.5))
    # knuckle seams
    for vc, tip, ht in fingers[:3]:
        p.line([b(0.47, vc + ht * 1.0), b(0.57, vc + ht * 1.0)], GLOVE_DK, max(1.0, lw * 0.5))
    # red restitching: a seam of small cross-stitches across the index and middle fingertips
    for vc, tip, ht in fingers[:2]:
        x = b(tip, vc)[0] - b.h * ht * 1.7
        n = 2 if not detail else 3
        hh = b.h * ht * 1.5 / n
        w = max(0.9, s * 0.022)
        p.line([(x, b(0, vc - ht * 0.85)[1]), (x, b(0, vc + ht * 0.85)[1])], mix(GLOVE_DK, INK, 0.3), w)
        for k in range(n):
            cy = b(0, vc - ht * 0.75)[1] + (k + 0.5) * hh
            d = hh * 0.42
            p.line([(x - d, cy - d), (x + d, cy + d)], RED, w)
            p.line([(x - d, cy + d), (x + d, cy - d)], RED, w)


def with_cast(p, draw, off=(5, 3), a=0.34):
    """Draw an object with its flat cast shadow on the wall behind it (the object's own
    silhouette, offset down-right, INK at a)."""
    obj = p.layer()
    draw(obj)
    sil = ImageChops.offset(obj.im.getchannel("A"), int(off[0] * SS), int(off[1] * SS))
    sh = Image.new("RGBA", obj.im.size, rgba(INK))
    sh.putalpha(sil.point(lambda v: int(v * a)))
    p.im.alpha_composite(sh)
    p.im.alpha_composite(obj.im)


# ----------------------------------------------------------------------------- view A

LABELS_A = ([(x + 10, 260, x + 91, 333) for x in OPEN_X.values()]
            + [(x + 6, 260, x + 59, 289) for x in SHUT_X.values()]
            + [(b[3], y, b[3] + 81, y + 26) for b in BUNKS_A for y in (478, 728)])


def fanlight(p):
    x0, y0, x1, y1 = FAN_OUT
    contact_rect(p, x0 - 2, y1 + 10, x1 + 16, y1 + 18, 0.3)
    contact_rect(p, x1 + 10, y0 - 2, x1 + 18, y1 + 10, 0.3)
    p.rect(x0 - 8, y1 - 2, x1 + 8, y1 + 10, FRAME, INK, 3)           # sill
    p.rect(x0, y0, x1, y1, FRAME, INK, 3)
    p.line([(x0 + 4, y0 + 4), (x1 - 4, y0 + 4)], FRAME_HI, 1.6)
    p.rect(x0 - 10, y0 - 10, x1 + 10, y0, FRAME, INK, 3)              # head moulding
    gx0, gy0, gx1, gy1 = FAN_GLASS
    p.rect(gx0, gy0, gx1, gy1, GLASS, INK, 2.6)


def paint_view_a(rng, st, hollows=()):
    p = Pen(W, H, rng)
    shell(p, rng, st)
    fanlight(p)
    damp(p, st, "a")
    # the locker bank, its flat shadow on the wall and on the floor
    contact_rect(p, 708, 254, 718, 896, 0.3)
    contact_rect(p, 50, 896, 718, 905, 0.38)
    p.rect(44, 244, 708, 252, LOCKER_DK, INK, 2.4)          # top cap over the whole bank
    for x in OPEN_X.values():
        open_locker(p, x, rng)
    for x in SHUT_X.values():
        shut_locker(p, x)
    p.rect(446, 246, 706, 252, mix(LOCKER_DK, LOCKER, 0.5), INK, 2)   # the belongings' shelf top
    p.rect(44, 886, 708, 896, mix(LOCKER_DK, INK, 0.3), INK, 2)       # plinth
    # under-bunk shade (behind beds and luggage)
    underbunk_shadow(p, st, 748, 1048, pool=(770, 1030))
    underbunk_shadow(p, st, 1108, 1384, pool=(1150, 1310))
    for spec in BUNKS_A:
        bunk(p, spec, hollows)
    for box in ((770, 790, 900, 896), (912, 820, 1030, 896), (1150, 806, 1310, 896)):
        suitcase(p, *box)
    if st == 4:
        blisters(p, st, [1128 + 35 * k for k in range(8)], 590)
    return graded(p, st, LABELS_A, "a")


# ----------------------------------------------------------------------------- view B

LABELS_B = [(504, 140, 777, 509)] + [(b[3], y, b[3] + 81, y + 26) for b in BUNKS_B for y in (478, 728)]


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


FIGURE_X = 256


def figure_poly():
    """Someone standing on the front of the cloth: a stark flat silhouette, full length to the
    hem, the neck a little too long and the shoulders too narrow."""
    cx = FIGURE_X
    right = []
    for k in range(0, 25):
        a = -math.pi / 2 + (math.pi * 0.56) * k / 24
        right.append((cx + 29 * math.cos(a), 236 + 40 * math.sin(a)))
    right += bezier((cx + 13, 272), (cx + 12, 300), (cx + 14, 326), 8)[1:]          # the long neck
    right += bezier((cx + 14, 326), (cx + 52, 330), (cx + 64, 352), 10)[1:]         # narrow shoulders
    right += bezier((cx + 64, 352), (cx + 72, 560), (cx + 66, 893), 18)[1:]
    left = [(2 * cx - x, y) for x, y in reversed(right)]
    return right + left[1:]


def paint_figure(rng):
    """The figure, as its own pen: two boot toe-caps under the hem pointing at her, then the
    curtain painted INK-dark (its pleats still running over it) through the silhouette."""
    fp = Pen(W, H, rng)
    for tx in (FIGURE_X - 27, FIGURE_X + 27):
        contact_rect(fp, tx - 18, 912, tx + 34, 920, 0.5)
        pts = bezier((tx - 23, 916), (tx - 23, 884), (tx, 884), 10) + bezier((tx, 884), (tx + 23, 884), (tx + 23, 916), 10)
        fp.poly(pts, mix(LEATHER, INK, 0.35), INK, 2.8)
        fp.arc(tx - 3, 900, 15, 11, 205, 285, mix(LEATHER_HI, PAPER, 0.45), 2.6)
        fp.line([(tx - 21, 909), (tx + 21, 909)], mix(LEATHER_DK, INK, 0.7), 2.0)
    dk = Pen(W, H, rng)
    curtain(dk, rng)
    a = dk.im.getchannel("A")
    dk.im = Image.blend(dk.im.convert("RGB"), Image.new("RGB", dk.im.size, INK), 0.6).convert("RGBA")
    dk.im.putalpha(a)
    m = Image.new("L", (W * SS, H * SS), 0)
    ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in figure_poly()], fill=255)
    fp.put(dk, 1.0, m)
    return fp


def calendar(p):
    # cord to the nail
    p.line([(560, 142), (640, 132), (720, 142)], mix(TIMBER_DK, INK, 0.3), 2)
    p.ell(640, 132, 3.5, 3.5, STEEL_DK, INK, 1.4)
    contact_rect(p, 512, 150, 786, 518, 0.32)
    p.rect(504, 140, 776, 508, TIMBER, INK, 3, r=2)
    p.rect(508, 144, 772, 504, PAPER_HI, mix(TIMBER, INK, 0.4), 1.4)
    p.rect(514, 150, 766, 190, ENAMEL, INK, 2.2)
    for k in range(9):
        y = 196 + 38 * k
        p.line([(514, y), (766, y)], mix(PAPER, INK, 0.45 if k in (0, 8) else 0.3), 2 if k in (0, 8) else 1.4)
    for x in (514, 574, 584, 766):
        p.line([(x, 196), (x, 500)], mix(PAPER, INK, 0.4), 1.6)


def bulkhead_lamp(p, st):
    """A small caged bulkhead lamp, brass, on the beam over the calendar."""
    lx, ly = LAMP_B
    bulb = {1: (244, 220, 168), 2: (240, 212, 156), 3: (200, 234, 218), 4: (186, 228, 210), 0: GLASS}[st]
    if st:
        glow = p.layer()
        glow.ell(lx, ly + 30, 46, 40, bulb, None)
        p.put_soft(glow, 14, 0.45)
    contact_rect(p, lx - 12, ly + 6, lx + 26, ly + 52, 0.3)
    p.rect(lx - 20, ly + 2, lx + 20, ly + 10, BRASS, INK, 2)              # base plate on the beam
    p.rect(lx - 12, ly + 10, lx + 12, ly + 16, BRASS_LO, INK, 1.8)
    p.ell(lx, ly + 31, 13, 16, bulb, INK, 2)                              # the glass
    if st:
        p.ell(lx - 4, ly + 26, 4, 6, PALE, None)
    for dx in (-9, 0, 9):                                                  # the cage
        p.line([(lx + dx * 1.25, ly + 16), (lx + dx * 1.45, ly + 31), (lx + dx * 1.2, ly + 46)], BRASS, 2.2)
    p.arc(lx, ly + 31, 15, 4, 0, 360, BRASS, 2)
    p.ell(lx, ly + 48, 7, 3.5, BRASS_LO, INK, 1.6)


def writing_table(p):
    # shadows, legs, apron, top
    contact_rect(p, 504, 716, 822, 726, 0.3)
    contact_rect(p, 514, 610, 810, 708, 0.28)
    contact_rect(p, 720, 538, 804, 610, 0.28)
    for a in (504, 788):
        contact_rect(p, a + 16, 726, a + 24, 902, 0.28)
        contact_rect(p, a + 2, 896, a + 26, 904, 0.38)
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


def paint_view_b(rng, st, hollows=(), figure=False):
    p = Pen(W, H, rng)
    shell(p, rng, st)
    damp(p, st, "b")
    bulkhead_lamp(p, st)
    calendar(p)
    writing_table(p)
    underbunk_shadow(p, st, 856, 1092)
    underbunk_shadow(p, st, 1148, 1384)
    for spec in BUNKS_B:
        bunk(p, spec, hollows, "b")
    pencil_shelf(p)
    cup_shelf(p, st)
    contact_rect(p, 476, 140, 486, 884, 0.3)
    curtain(p, rng)
    if figure:
        p.put(paint_figure(rng_for(8800)))
    if st == 4:
        blisters(p, st, [870 + 30 * k for k in range(8)], 590)
    return graded(p, st, LABELS_B, "b")


# ----------------------------------------------------------------------------- view A overlays

TOP_SPAN = {"pencils": (456, 500), "glove": (514, 576), "cup": (586, 632), "calipers": (650, 690)}


def paint_top(which):
    def fn(rng):
        p = Pen(W, H, rng)
        x0, x1 = TOP_SPAN[which]
        contact_rect(p, x0 + 3, 246, x1 + 7, 251, 0.45)
        if which == "pencils":
            with_cast(p, lambda q: draw_pencils(q, Box(458, 190, 498, 250), 2.0))
        elif which == "glove":
            with_cast(p, lambda q: draw_glove(q, Box(514, 220, 576, 250), 1.8))
        elif which == "cup":
            with_cast(p, lambda q: draw_cup(q, Box(586, 210, 632, 250), 2.0))
        else:  # calipers stood on end, leaning on the wall
            with_cast(p, lambda q: draw_calipers(q, Box(654, 168, 688, 250, -8.0, (668, 250)), 1.7))
        return p
    return fn


def paint_in(which):
    def fn(rng):
        p = Pen(W, H, rng)
        if which == "cup":
            with_cast(p, lambda q: draw_cup(q, Box(70, 512, 126, 560), 2.0), (4, 2), 0.4)
        elif which == "calipers":
            with_cast(p, lambda q: draw_calipers(q, Box(178, 466, 220, 560, -6.0, (199, 560)), 1.8), (4, 2), 0.4)
        elif which == "pencils":
            with_cast(p, lambda q: draw_pencils(q, Box(274, 470, 322, 560), 2.0), (4, 2), 0.4)
        else:
            with_cast(p, lambda q: draw_glove(q, Box(360, 520, 438, 560), 1.8), (4, 2), 0.4)
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


def recess(p, x0, y0, x1, y1, n, ins, nail, detail=1.0):
    """Venn's impossible compartment: the locker's own back panel repeated in recession. Each
    step a smaller panel with its planks, its hook and its dust square, the light falling off
    step by step, ending in a flat INK rectangle that is too deep."""
    rect = (x0, y0, x1, y1)
    for k in range(n + 1):
        a, b_, c, d = rect
        if k == n:
            p.rect(a, b_, c, d, INK, INK, 1.2)
            break
        t = (k / n) ** 0.85
        fill = mix(BACK, NIGHT, t)
        p.rect(a, b_, c, d, fill, INK, max(1.0, 2.2 * detail * (1 - 0.5 * t)))
        w = c - a
        plank = max(4.0, w / 6)
        xx = a + plank
        while xx < c - plank * 0.5:
            p.line([(xx, b_ + 2), (xx, d - 2)], mix(fill, NIGHT, 0.5), max(0.8, 1.4 * detail * (1 - 0.5 * t)))
            xx += plank
        # the top of each step in shadow, its lower lip lit faintly
        sh = p.layer()
        sh.rect(a, b_, c, b_ + (d - b_) * 0.08, NIGHT, None)
        p.put(sh, 0.5)
        p.line([(a + 2, d - 2), (c - 2, d - 2)], mix(fill, PALE, 0.16 * (1 - t)), max(0.8, 1.2 * detail))
        # its dust square: a strip of dust along the foot with a clean square in it
        sy = d - max(2.0, (d - b_) * 0.10)
        film = p.layer()
        film.rect(a + 2, sy, c - 2, d - 2.5, mix(DUST, fill, 0.62 + 0.33 * t), None)
        film.rect((a + c) / 2 - w * 0.14, sy, (a + c) / 2 + w * 0.14, d - 2.5, fill, None)
        p.put(film, 0.9)
        if k:
            hx, hy = (a + c) / 2, b_ + (d - b_) * 0.18
            hs = max(0.25, 0.9 * detail * w / (x1 - x0))
            coat_hook(p, hx, hy, hs)
        rect = (a + ins[0], b_ + ins[1], c - ins[2], d - ins[3])
    nx, ny = nail
    p.ell(nx + 1, ny + 2, 3, 3, NIGHT, None)
    p.line([(nx, ny), (nx + 1, ny + 7)], STEEL_DK, 2)
    p.ell(nx, ny, 3, 3, STEEL_HI, INK, 1.2)


def paint_a_venn_open(rng):
    p = Pen(W, H, rng)
    recess(p, 258, 574, 338, 880, 7, (3.2, 3.6, 3.2, 28), (298, 610), 0.6)
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


# ----------------------------------------------------------------------------- fanlight

def clip_glass(p):
    """Return the Pen's image clipped to the fanlight glass."""
    m = rect_mask([FAN_GLASS])
    p.im.putalpha(ImageChops.multiply(p.im.getchannel("A"), m))
    return p


GX0, GY0, GX1, GY1 = FAN_GLASS
GW, GH = GX1 - GX0, GY1 - GY0
FS = GH / 92.0                                     # the first pass's glass was 92 px tall


def fy(y_old):
    """A height in the first pass's fanlight (glass 150..242) mapped into this one."""
    return GY0 + (y_old - 150) * FS


def fx(x_old):
    return GX0 + (x_old - 828) * GW / 404.0


def scallops(p, y, x0, x1, r, col, rng, below=40):
    r *= FS
    x = x0 - r
    while x < x1 + r:
        rr = r * rng.uniform(0.7, 1.15)
        p.ell(x, y, rr * 1.5, rr, col, None)
        x += rr * 1.9
    p.rect(x0 - 4, y, x1 + 4, y + below * FS, col, None)


def sea(p, y0, col, rng, rows, lines=True):
    rows *= FS
    p.rect(GX0 - 2, y0, GX1 + 2, GY1 + 2, col, None)
    p.line([(GX0, y0), (GX1, y0)], mix(col, INK, 0.4), 1.6)
    if lines:
        y = y0 + rows
        while y < GY1:
            x = GX0 + rng.uniform(0, 30)
            while x < GX1:
                L = rng.uniform(14, 34) * FS
                p.arc(x + L / 2, y, L / 2, 3, 200, 340, mix(col, PALE, 0.22), 1.4)
                x += L + rng.uniform(10, 30) * FS
            y += rows


def jetty(p, col, deck=208):
    deck = fy(deck)
    for x in (1094, 1112, 1130, 1148, 1166):
        p.rect(fx(x), deck - 4 * FS, fx(x) + 5, GY1, col, None)
    p.rect(fx(1088), deck - 6 * FS, fx(1176), deck - 1, col, None)
    p.rect(fx(1150), deck - 18 * FS, fx(1166), deck - 6 * FS, col, None)


def paint_fan(band):
    def fn(rng):
        p = Pen(W, H, rng)
        gx0, gy0, gx1, gy1 = FAN_GLASS
        if band == 1:
            p.rect(gx0, gy0, gx1, gy1, (178, 184, 186), None)
            scallops(p, fy(176), gx0, gx1, 12, (196, 200, 200), rng)
            scallops(p, fy(204), gx0, gx1, 14, (160, 168, 172), rng)
            scallops(p, fy(228), gx0, gx1, 12, (144, 152, 158), rng)
        elif band == 2:
            p.rect(gx0, gy0, gx1, gy1, (150, 158, 162), None)
            scallops(p, fy(172), gx0, gx1, 14, (132, 140, 146), rng)
            scallops(p, fy(196), gx0, gx1, 12, (118, 126, 134), rng)
            sea(p, fy(214), (104, 114, 120), rng, 8)
            jetty(p, (70, 80, 88))
        elif band == 3:
            p.rect(gx0, gy0, gx1, gy1, (112, 120, 128), None)
            scallops(p, fy(166), gx0, gx1, 18, (94, 102, 112), rng)
            scallops(p, fy(192), gx0, gx1, 16, (80, 88, 98), rng)
            sea(p, fy(210), (76, 88, 96), rng, 6)
            jetty(p, (46, 56, 66), 204)
        elif band == 4:
            p.rect(gx0, gy0, gx1, gy1, (102, 110, 118), None)
            sea(p, fy(166), (68, 82, 92), rng, 4)
        elif band == 5:
            p.rect(gx0, gy0, gx1, gy1, (106, 112, 116), None)
            lay = p.layer()
            for k in range(6):
                lay.ell(rng.uniform(gx0, gx1), rng.uniform(gy0, gy1), rng.uniform(40, 90) * FS,
                        rng.uniform(10, 20) * FS, (114, 120, 124), None)
            p.put_soft(lay, 10, 0.6)
        elif band == 6:
            p.rect(gx0, gy0, gx1, gy1, (32, 46, 60), None)
            lay = p.layer()
            for k in range(4):
                lay.ell(rng.uniform(gx0, gx1), rng.uniform(gy0, gy1), rng.uniform(60, 120) * FS,
                        rng.uniform(14, 24) * FS, (40, 56, 70), None)
            p.put_soft(lay, 12, 0.5)
        elif band == 7:
            # nothing out there but a line, and one small upright thing standing on it
            p.rect(gx0, gy0, gx1, gy1, (18, 28, 38), None)
            hy = gy0 + GH * 0.55
            p.rect(gx0, hy - 4, gx1, hy + 4, (112, 146, 136), None)
            p.line([(gx0, hy - 4), (gx1, hy - 4)], (150, 180, 168), 1.2)
            sx = gx0 + GW * 0.63
            p.rect(sx - 2.2, hy - 20, sx + 2.2, hy - 3, NIGHT, None)
            p.ell(sx, hy - 21, 2.8, 2.8, NIGHT, None)
        else:  # sever: pale ordinary daylight
            p.rect(gx0, gy0, gx1, gy1, (208, 210, 202), None)
            scallops(p, fy(182), gx0, gx1, 12, (224, 224, 216), rng)
            sea(p, fy(224), (176, 184, 182), rng, 9)
        return clip_glass(p)
    return fn


def paint_rain(kind):
    def fn(rng):
        p = Pen(W, H, rng)
        gx0, gy0, gx1, gy1 = FAN_GLASS
        lay = p.layer()
        if kind == "hang":
            # beads standing on the glass: round, a dark meniscus under each, no tails
            for _ in range(38):
                x, y = rng.uniform(gx0 + 8, gx1 - 8), rng.uniform(gy0 + 8, gy1 - 8)
                r = rng.uniform(2.6, 4.2)
                lay.ell(x, y, r, r, (156, 168, 172), None)
                lay.arc(x, y, r, r, 25, 155, mix(INK, GLASS, 0.15), 1.5)
                lay.ell(x - r * 0.35, y - r * 0.35, r * 0.3, r * 0.3, (238, 242, 240), None)
            p.put(lay, 0.7)
        else:
            heavy = kind.startswith("heavy")
            n = 120 if heavy else 50
            for _ in range(n):
                x, y = rng.uniform(gx0, gx1), rng.uniform(gy0 - 20, gy1)
                L = (rng.uniform(18, 40) if heavy else rng.uniform(10, 22)) * FS
                lay.line([(x, y), (x - L * 0.12, y + L)], (214, 222, 226),
                         rng.uniform(1.2, 1.8) if heavy else rng.uniform(1.0, 1.4))
            p.put(lay, 0.55 if heavy else 0.45)
        return clip_glass(p)
    return fn


def paint_fan_frame(rng):
    p = Pen(W, H, rng)
    gx0, gy0, gx1, gy1 = FAN_GLASS
    # rebate shadow round the glass (no wired mesh: at game size it read as a vent grille)
    sh = p.layer()
    sh.rect(gx0, gy0, gx1, gy0 + 7, INK, None)
    sh.rect(gx0, gy0, gx0 + 6, gy1, INK, None)
    clip_glass(sh)
    p.put(sh, 0.4)
    for x in FAN_BARS:
        p.rect(x - 5, gy0, x + 5, gy1, FRAME, INK, 2.2)
        p.line([(x - 2, gy0 + 2), (x - 2, gy1 - 2)], FRAME_HI, 1.2)
    p.rect(gx0 - 1, gy0 - 1, gx1 + 1, gy1 + 1, None, INK, 2.6)
    return p


# ----------------------------------------------------------------------------- view B overlays

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
        # opening: back planks in dark sea-glass, the door leaf's shadow, two hooks
        p.rect(x + 10, 376, x + 290, 800, LOCK_IN, INK, 3)
        locker_back(p, x + 26, 379, x + 288, 798, plank=38, lw=2.2)
        contact_rect(p, x + 26, 379, x + 40, 798, 0.4)
        p.rect(x + 10, 376, x + 26, 800, LOCKER_HI, INK, 2.4)    # door edge
        coat_hook(p, x + 80, 410, 2.0)
        coat_hook(p, x + 236, 410, 2.0)
        # shelf: dust along its top and the clean square where the object stood
        dusty_shelf(p, x + 26, x + 290, 560, x + 150, 84, 24, 3.0)
        # brass plate, up
        p.rect(x + 130, 586, x + 170, 606, BRASS_HI, INK, 2.4, r=2)
        p.line([(x + 134, 590), (x + 166, 590)], PALE, 1.4)
        p.ell(x + 150, 600, 3, 3, BRASS_LO, INK, 1.2)
        # rod and empty hanger, with their shadows
        contact_rect(p, x + 32, 624, x + 290, 630, 0.4)
        p.line([(x + 28, 620), (x + 290, 620)], BRASS_LO, 5)
        p.line([(x + 28, 618), (x + 290, 618)], BRASS_HI, 1.4)
        sh = p.layer()
        hanger(sh, x + 164, 618, 70, 40)
        p.put(sh, 0.35)
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


SPRITES = {
    "cup": (draw_cup, 150, 120, (8, 6, 142, 118), 3.0),
    "calipers": (draw_calipers, 120, 200, (6, 4, 114, 198), 2.8),
    "pencils": (draw_pencils, 110, 170, (6, 4, 104, 168), 2.8),
    "glove": (draw_glove, 190, 120, (6, 6, 184, 118), 2.8),
}


def paint_halo(fn, w, h, box, lw, grow=3):
    """A thin paper-hi outline for a lifted belonging: its silhouette grown by `grow` px,
    drawn under the sprite (same size, same anchor)."""
    def go(rng):
        im = paint_sprite(fn, w, h, box, lw)(rng_for(0)).done()
        a = im.getchannel("A").point(lambda v: 255 if v > 40 else 0).filter(ImageFilter.MaxFilter(2 * grow + 1))
        out = Image.new("RGBA", (w, h), rgba(PAPER_HI))
        out.putalpha(a.filter(ImageFilter.GaussianBlur(0.6)))
        return out
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
    recess(p, 724, 590, 1004, 800, 7, (12, 3.6, 12, 18), (864, 640), 1.0)
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

DRUMS = ((230, 450), (614, 834), (998, 1218))       # wheel windows (the finding wheel 24 px wider)
DRUM_Y = (672, 776)


def eraser_knob(p, x0, pressed=False):
    """ERASE: a brass ferrule holding a worn rubber cap, pushed in to rub out."""
    y0, y1 = 838, 902
    cy = (y0 + y1) / 2
    push = 22 if pressed else 0
    contact_rect(p, x0 + 46, y0 + 8, x0 + 254 - push, y1 + 8, 0.35)
    # the ferrule, crimped
    p.rect(x0 + 40, y0 + 4, x0 + 170, y1 - 4, BRASS, INK, 3, r=4)
    p.line([(x0 + 44, y0 + 10), (x0 + 166, y0 + 10)], BRASS_HI, 2.4)
    for k in range(4):
        xx = x0 + 70 + k * 24
        p.line([(xx, y0 + 6), (xx, y1 - 6)], BRASS_LO, 3)
        p.line([(xx + 3, y0 + 6), (xx + 3, y1 - 6)], BRASS_HI, 1.2)
    # the rubber cap
    cap = capsule((x0 + 168, cy), (x0 + 236 - push, cy), (y1 - y0) / 2, (y1 - y0) / 2)
    p.poly([pt for pt in cap if pt[0] >= x0 + 166] + [(x0 + 166, y1), (x0 + 166, y0)], ERASER, INK, 3)
    p.line(bezier((x0 + 178, y0 + 9), (x0 + 220 - push, y0 + 6), (x0 + 246 - push, cy - 8), 10),
           mix(ERASER, PALE, 0.45), 2.4)
    p.line(bezier((x0 + 196 - push, y1 - 8), (x0 + 230 - push, y1 - 10), (x0 + 252 - push, cy + 6), 8),
           mix(ERASER, INK, 0.3), 2)
    # its guide plate on the walnut
    p.rect(x0 + 14, y0 - 4, x0 + 40, y1 + 4, BRASS_LO, INK, 2.4, r=3)
    for yy in (y0 + 6, y1 - 6):
        screw(p, x0 + 27, yy, 3.4)


def nib_lever(p, x0, pressed=False):
    """APPEND: a lever on a brass pivot ending in a steel pen nib; pressed, the nib dips."""
    px_, py_ = x0 + 52, 868
    ang = math.radians(9 if pressed else -4)

    def rot(x, y):
        dx, dy = x - px_, y - py_
        return (px_ + dx * math.cos(ang) - dy * math.sin(ang), py_ + dx * math.sin(ang) + dy * math.cos(ang))

    contact(p, [(x[0] + 8, x[1] + 10) for x in (rot(px_, py_ - 12), rot(x0 + 190, py_ - 9), rot(x0 + 268, py_ + 2),
                                                rot(x0 + 190, py_ + 11), rot(px_, py_ + 12))], 0.35)
    # the arm
    p.poly([rot(px_, py_ - 12), rot(x0 + 190, py_ - 9), rot(x0 + 190, py_ + 9), rot(px_, py_ + 12)], WALNUT_HI, INK, 3)
    p.line([rot(px_ + 8, py_ - 6), rot(x0 + 186, py_ - 4)], mix(WALNUT_HI, PAPER, 0.3), 1.6)
    # the brass holder band
    p.poly([rot(x0 + 176, py_ - 13), rot(x0 + 200, py_ - 13), rot(x0 + 200, py_ + 13), rot(x0 + 176, py_ + 13)],
           BRASS, INK, 2.4)
    # the nib: shoulders, a breather hole, the slit to a point
    nib = [rot(x0 + 200, py_ - 12), rot(x0 + 232, py_ - 10), rot(x0 + 268, py_ + 2), rot(x0 + 232, py_ + 12),
           rot(x0 + 200, py_ + 12)]
    p.poly(nib, STEEL, INK, 2.6)
    p.poly([rot(x0 + 200, py_ - 12), rot(x0 + 232, py_ - 10), rot(x0 + 250, py_ - 2), rot(x0 + 200, py_ - 2)],
           STEEL_HI, None)
    hx, hy = rot(x0 + 226, py_ + 1)
    p.ell(hx, hy, 3.6, 3.6, NIGHT, INK, 1.2)
    p.line([rot(x0 + 229, py_ + 1), rot(x0 + 267, py_ + 2)], INK, 1.6)
    p.poly(nib, None, INK, 2.6)
    # the pivot boss
    p.ell(px_, py_, 20, 20, BRASS, INK, 3)
    p.ell(px_, py_, 11, 11, BRASS_HI, INK, 2)
    p.line([(px_ - 6, py_ - 6), (px_ + 6, py_ + 6)], BRASS_LO, 2.4)
    # the ink-stained rest the nib comes down onto
    p.rect(x0 + 216, 900, x0 + 284, 910, WALNUT_DK, INK, 2, r=3)
    p.ell(x0 + 262, 902, 10, 2.6, mix(INK_BLUE, INK, 0.3), None)


INK_BLUE = (31, 63, 138)


def label_plate(p, cx, y, w=150):
    p.rect(cx - w / 2, y, cx + w / 2, y + 30, BRASS, INK, 2.4, r=3)
    p.line([(cx - w / 2 + 5, y + 4), (cx + w / 2 - 5, y + 4)], BRASS_HI, 1.4)
    for xx in (cx - w / 2 + 9, cx + w / 2 - 9):
        screw(p, xx, y + 15, 2.6)


def drum(p, a, b):
    """An engraved brass drum behind its window; words are cut in by the view."""
    y0, y1 = DRUM_Y
    contact_rect(p, a - 2, y0 + 4, b + 14, y1 + 10, 0.35)
    p.rect(a - 8, y0 - 8, b + 8, y1 + 8, WALNUT_DK, INK, 2.6, r=5)
    n = 16
    for k in range(n):                      # the cylinder: bright across the middle, dark at the rims
        t = (k + 0.5) / n
        v = math.sin(math.pi * t) ** 0.7
        p.rect(a, y0 + (y1 - y0) * k / n, b, y0 + (y1 - y0) * (k + 1) / n + 1, mix(BRASS_LO, BRASS_HI, v * 0.85), None)
    p.rect(a, y0, b, y1, None, INK, 2.6)
    for xx in (a + 6, b - 6):
        p.line([(xx, y0 + 2), (xx, y1 - 2)], mix(BRASS_LO, INK, 0.3), 1.4)


def paint_drum_shade(rng):
    """Drawn over the neighbour words: the drum's curvature closing over them, top and bottom."""
    p = Pen(W, H, rng)
    y0, y1 = DRUM_Y
    for a, b in DRUMS:
        lay = p.layer()
        for k in range(14):
            al = int(255 * (1 - k / 14) ** 1.3)
            lay.rect(a + 1, y0 + 1 + k * 1.8, b - 1, y0 + 1 + (k + 1) * 1.8, (*mix(BRASS_LO, INK, 0.45), al), None)
            lay.rect(a + 1, y1 - 1 - (k + 1) * 1.8, b - 1, y1 - 1 - k * 1.8, (*mix(BRASS_LO, INK, 0.45), al), None)
        p.put(lay)
        p.rect(a, y0, b, y1, None, INK, 2.6)
        # the reading line: two hairlines either side of the word
        p.line([(a + 3, (y0 + y1) / 2 - 20), (b - 3, (y0 + y1) / 2 - 20)], mix(BRASS_LO, INK, 0.3), 1.2)
        p.line([(a + 3, (y0 + y1) / 2 + 16), (b - 3, (y0 + y1) / 2 + 16)], mix(BRASS_LO, INK, 0.3), 1.2)
    return p


def stud(p, x0, x1, y0, y1, pointing):
    cx, cy, r = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2
    contact(p, [(cx + 6 + r * math.cos(a / 8 * math.pi), cy + 6 + r * math.sin(a / 8 * math.pi)) for a in range(16)], 0.35)
    p.ell(cx, cy, r, r, BRASS, INK, 3)
    p.ell(cx, cy, r - 7, r - 7, BRASS_HI, mix(BRASS_LO, INK, 0.2), 2)
    for k in range(12):                     # milled edge
        a = k * math.pi / 6
        p.line([(cx + (r - 2) * math.cos(a), cy + (r - 2) * math.sin(a)),
                (cx + (r - 6) * math.cos(a), cy + (r - 6) * math.sin(a))], BRASS_LO, 1.6)
    s = -1 if pointing == "left" else 1
    p.poly([(cx - 9 * s, cy - 14), (cx + 9 * s, cy), (cx - 9 * s, cy + 14), (cx - 3 * s, cy)], INK, None)


def paint_c_slope(rng, pressed=None):
    p = Pen(W, H, rng, bg=WALNUT)
    # walnut: grain that runs the length of the box, a few figured knots
    for k in range(34):
        y = rng.uniform(0, H)
        amp, ph = rng.uniform(2, 7), rng.uniform(0, 6.28)
        pts = [(x, y + amp * math.sin(x * 0.006 + ph)) for x in range(-10, W + 20, 40)]
        p.line(pts, mix(WALNUT, WALNUT_DK, rng.uniform(0.35, 0.8)), rng.uniform(1.0, 2.4))
    # the box: lid hinge strip at the top, a bevelled inner frame, brass corners
    p.rect(-4, -4, W + 4, 60, WALNUT_DK, INK, 3)
    p.line([(-4, 52), (W + 4, 52)], BRASS_LO, 4)
    for x in (300, 1148):
        p.rect(x - 60, 40, x + 60, 64, BRASS, INK, 2.4)
        for xx in (x - 44, x, x + 44):
            screw(p, xx, 52, 3)
    contact_rect(p, 116, 126, 1346, 658, 0.35)
    p.rect(104, 114, 1344, 656, WALNUT_DK, INK, 3, r=4)
    p.rect(110, 120, 1338, 650, BAIZE, INK, 3)
    for k in range(60):                     # baize nap
        y = 124 + rng.uniform(0, 522)
        x = 114 + rng.uniform(0, 1200)
        p.line([(x, y), (x + rng.uniform(8, 20), y)], mix(BAIZE, BAIZE_HI, 0.5), 1)
    p.line([(116, 126), (1332, 126)], BAIZE_HI, 2)
    for cx, cy, sx, sy in ((104, 114, 1, 1), (1344, 114, -1, 1), (104, 656, 1, -1), (1344, 656, -1, -1)):
        p.poly([(cx, cy), (cx + 28 * sx, cy), (cx + 28 * sx, cy + 8 * sy), (cx + 8 * sx, cy + 8 * sy),
                (cx + 8 * sx, cy + 28 * sy), (cx, cy + 28 * sy)], BRASS_HI, INK, 2)
    for x0, lx in ((160, 300), (808, 948)):
        contact_rect(p, x0 + 8, 208, x0 + 490, 628, 0.35)
        p.rect(x0, 200, x0 + 480, 620, BAIZE_HI, INK, 3)
        p.rect(x0 + 10, 210, x0 + 470, 596, mix(BAIZE, BAIZE_HI, 0.55), mix(BAIZE_DK, INK, 0.3), 1.6)
        # the ledge the card stands on
        p.rect(x0, 598, x0 + 480, 620, BRASS, INK, 3, r=3)
        p.line([(x0 + 8, 602), (x0 + 472, 602)], BRASS_HI, 2)
        enamel_plate(p, lx, 160, lx + 200, 192, 2.6)
        screw(p, lx + 10, 176, 3)
        screw(p, lx + 190, 176, 3)
    # the amendment strip: three engraved drums between milled studs
    contact_rect(p, 168, 664, 1300, 792, 0.3)
    p.rect(156, 656, 1292, 786, WALNUT_HI, INK, 3, r=6)
    p.line([(164, 662), (1284, 662)], mix(WALNUT_HI, PAPER, 0.25), 1.6)
    for a, b in DRUMS:
        drum(p, a, b)
    for x0 in (160, 544, 928):
        stud(p, x0, x0 + 64, 688, 752, "left")
    for x0 in (456, 840, 1224):
        stud(p, x0, x0 + 64, 688, 752, "right")
    # ERASE and APPEND: the contraption's two controls, each with an engraved plate
    for x0 in (160, 1008):
        contact_rect(p, x0 + 2, 820, x0 + 292, 954, 0.3)
        p.rect(x0 - 8, 812, x0 + 288, 948, WALNUT_DK, INK, 2.4, r=14)
        label_plate(p, x0 + 140, 910, 150)
    eraser_knob(p, 160, pressed == "erase")
    nib_lever(p, 1008, pressed == "append")
    # the pencil in its carved groove: hexagonal, a brass ferrule, a sharpened cone
    p.rect(520, 860, 900, 910, WALNUT_DK, INK, 2.6, r=20)
    p.rect(530, 876, 890, 902, mix(WALNUT_DK, NIGHT, 0.45), None, r=10)
    contact_rect(p, 584, 888, 846, 900, 0.45)
    body = mix(SEAGLASS, INK, 0.2)
    p.poly([(580, 872), (790, 872), (790, 896), (580, 896)], body, INK, 2.4)
    p.line([(582, 880), (788, 880)], mix(SEAGLASS, PALE, 0.35), 1.6)
    p.line([(582, 889), (788, 889)], mix(body, INK, 0.35), 1.4)
    p.poly([(790, 872), (832, 884), (790, 896)], WOOD, INK, 2.2)
    p.poly([(820, 880.5), (834, 884), (820, 887.5)], GRAPHITE, None)
    p.rect(556, 871, 582, 897, BRASS, INK, 2)
    for xx in (563, 569, 575):
        p.line([(xx, 873), (xx, 895)], BRASS_LO, 1.4)
    p.rect(542, 873, 557, 895, ERASER, INK, 2, r=4)
    # the hinge along the bottom
    p.rect(-4, 1000, W + 4, 1012, BRASS_LO, INK, 2.6)
    return p


def paint_c_slope_clips(rng):
    """Brass card clips at the top of each rest, drawn over whatever card stands there."""
    p = Pen(W, H, rng)
    for cx in (290, 510, 938, 1158):
        contact_rect(p, cx - 12, 246, cx + 22, 290, 0.35)
        p.rect(cx - 16, 238, cx + 16, 248, BRASS_LO, INK, 2)
        p.poly([(cx - 14, 246), (cx + 14, 246), (cx + 10, 284), (cx - 10, 284)], BRASS, INK, 2.4)
        p.line([(cx - 8, 252), (cx - 6, 278)], BRASS_HI, 1.8)
        p.ell(cx, 243, 4, 3, BRASS_HI, INK, 1.2)
    return p


def paint_key_down(which):
    """The pressed control, cut from the slope painted pressed (grain and all)."""
    x0 = 160 if which == "erase" else 1008

    def fn(rng):
        im = grain(paint_c_slope(rng_for(59), which).done(), rng_for(1000 + 59))
        return im.crop((x0, 820, x0 + 280, 940))
    return fn


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


# ----------------------------------------------------------------------------- registry

SUFFIX = {1: "", 2: "_s2", 3: "_s3", 4: "_s4", 0: "_sever"}
_PLATES = {}


def plate_img(view, st, hollows=(), figure=False):
    """A finished plate (painted, lit, graded, grained). The hollow and figure variants differ
    from the clean plate only where they are painted: they use their own pens and the same
    seeds, so a difference of the two is exactly the overlay."""
    key = (view, st, tuple(hollows), figure)
    if key not in _PLATES:
        k = 0 if view == "a" else 1
        if view == "a":
            im = paint_view_a(rng_for(k), st, hollows)
        else:
            im = paint_view_b(rng_for(k), st, hollows, figure)
        _PLATES[key] = grain(im, rng_for(1000 + k))
    return _PLATES[key]


def diff_overlay(view, st, **kw):
    def fn(rng):
        base, alt = plate_img(view, st), plate_img(view, st, **kw)
        m = ImageChops.difference(base, alt).convert("L").point(lambda v: 255 if v > 0 else 0)
        m = m.filter(ImageFilter.MaxFilter(5))
        out = alt.convert("RGBA")
        out.putalpha(m)
        return out
    return fn


def _plate(view, st):
    return lambda r: plate_img(view, st)


A_BEDS = ("venn", "rook", "hart", "ives")
B_BEDS = ("doane", "lusk", "tull", "bell")

ASSETS = [  # name, seed index, painter, opaque, grain
    (f"view_{v}{'' if st == 1 else SUFFIX[st]}", 0, _plate(v, st), True, False)
    for v in ("a", "b") for st in (1, 2, 3, 4, 0)
] + [
    (f"{v}_dent_{bed}{SUFFIX[st]}", 0, diff_overlay(v, st, hollows=(bed,)), False, False)
    for v, beds in (("a", A_BEDS), ("b", B_BEDS)) for bed in beds for st in (1, 2, 3, 4, 0)
] + [
    (f"b_curtain_shape{SUFFIX[st]}", 0, diff_overlay("b", st, figure=True), False, False) for st in (1, 2, 3, 4)
] + [
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
] + [(f"a_fan_b{b}", 30 + b, paint_fan(b), False, False) for b in range(1, 8)] + [
    ("a_fan_sever", 38, paint_fan(0), False, False),
    ("a_fan_rain_0", 39, paint_rain("light"), False, False),
    ("a_fan_rain_1", 40, paint_rain("light"), False, False),
    ("a_fan_rain_heavy_0", 41, paint_rain("heavy"), False, False),
    ("a_fan_rain_heavy_1", 42, paint_rain("heavy"), False, False),
    ("a_fan_rain_hang", 43, paint_rain("hang"), False, False),
    ("a_fan_frame", 44, paint_fan_frame, False, False),
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
    ("c_slope_clips", 63, paint_c_slope_clips, False, False),
    ("c_slope_drums", 64, paint_drum_shade, False, False),
    ("c_card", 60, paint_c_card, False, False),
    ("c_sketch", 61, paint_c_sketch, False, False),
    ("c_erase_down", 0, paint_key_down("erase"), True, False),
    ("c_append_down", 0, paint_key_down("append"), True, False),
] + [(f"c_{o}_halo", 70 + i, paint_halo(*SPRITES[o]), False, False) for i, o in enumerate(SPRITES)]


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
