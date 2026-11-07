#!/usr/bin/env python3
"""R08 Machine Room painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R08/*.png:

  room, room_s3, room_s4, room_sever     stage plates (1448x1086 opaque): bands <=2, 3, 4-7 and
                                         ending A's released room in grey daylight
  belt{1,2,3}_{taut,slack}               full-frame registered belt sprites (RGBA)
  flywheel, pulley, crank_disc           rotating sprites (the view turns them)
  diaphragm, diaphragm_hollow, diaphragm_sheen, diaphragm_slack,
  diaphragm_reflect, diaphragm_reflect_now
                                         the breathing membrane and its layers (400x400, centre 200,200)
  dust_streaks, dust_raked               floor overlays (RGBA)
  light_mul, light_add                   quarter-size light maps (362x272) the view stretches x4
  c_valves (+ c_toggle_open/shut, c_seal_cut, c_pump_up/down, c_preview_up/down, c_preview_lamp)
  c_tags (+ c_tag, c_tag_new)            close-up plates and their sprites

Flat front elevation, approved palette, navy ink contours, matte colour, a low seeded paper
grain. No text, numerals or diagrams: every label field is a blank enamel or brass plate and
the view writes every word (nameplate, toggle names, gauge marks, drawing, tag writing).
Registration follows the R08 art task; the hotspots in R08_view.gd are fixed to it.

Python 3 + PIL only. Deterministic: each asset has its own random.Random(SEED + k), there is
no clock and no PIL noise effect, so a rerun is byte-identical.

    python3 tools/art/rooms/R08.py              # paint everything
    python3 tools/art/rooms/R08.py room* belt*  # paint some (fnmatch patterns)
"""
import fnmatch
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "rooms", "R08")
W, H = 1448, 1086
LW, LH = 362, 272           # light maps: quarter size, stretched x4 by the view
SS = 2                      # supersampling for every painted shape
SEED = 1931_08_00

# ----------------------------------------------------------------------------- palette
INK = (23, 43, 54)          # #172B36 contours
PAPER = (216, 206, 181)     # #D8CEB5
PAPER_HI = (232, 225, 207)
ENAMEL = (226, 220, 202)    # blank label plates
SEAGLASS = (97, 125, 116)   # #617D74
SEAGLASS_HI = (150, 178, 166)
TIMBER = (103, 93, 81)      # #675D51
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
STORM_DK = (26, 43, 57)
VIOLET = (116, 101, 119)    # #746577

WALL = (134, 162, 148)      # riveted iron plates, painted sea-glass
WALL_HI = (156, 182, 168)
WALL_DK = (108, 134, 122)
IRON = (40, 48, 56)         # machinery iron
IRON_HI = (66, 78, 88)
IRON_LO = (30, 36, 43)
CEIL = (28, 44, 58)
DECK = (96, 98, 96)         # iron deck under the dust
DUST = (138, 138, 130)      # the dust layer: grey
DUST_HI = (186, 184, 172)   # combed / dragged dust: pale
DUST_LO = (112, 112, 106)
LEATHER = (104, 76, 54)     # restrained brown belts
LEATHER_HI = (128, 98, 72)
LEATHER_DK = (78, 56, 40)
MEMBRANE = (16, 21, 29)     # black-navy
MEMBRANE_HI = (34, 42, 54)
PAINT = (236, 234, 222)     # bolt witness stripes
LEAD = (118, 122, 126)
LEAD_HI = (156, 160, 164)
SALT = (214, 212, 200)
GLASS_DK = (18, 30, 36)

# ----------------------------------------------------------------------------- geometry (fixed)
RING_C = (290, 450)
RING_R, MEM_R = 226, 192
BOLT_R, BOLT_HEAD = 209, 13
SHAFT = (500, 120, 900, 136)
HANGERS = (520, 880)
DRUM_TOP = (540, 104, 160, 46)
DRUM_LOW = (540, 640, 160, 46)
CRANK = (528, 663)
COLUMN = (560, 140, 120, 520)
NAMEPLATE = (566, 520, 108, 84)
NAIL = (620, 300)
FLY = (860, 560)
FLY_R = 180
TOP_PULLEY = (860, 128)
PUMP_PULLEY = (1180, 880)
PULLEY_R = 44
PUMP = (1110, 790, 260, 120)
BOARD = (1090, 420, 300, 330)
SOCKETS = (1135, 1195, 1255, 1315)
SOCKET_Y = 560
LEVER_X = 1360
FRAME = (1090, 150, 300, 230)
FRAME_PAPER = (1100, 160, 280, 210)
INDEX_X = 1372
LAMP = (440, 140)
DADO_Y, FLOOR_Y, DUST_Y1 = 640, 800, 910


# ----------------------------------------------------------------------------- helpers

def rng_for(k):
    return random.Random(SEED + k)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c0, c1, t):
    return tuple(int(round(lerp(a, b, t))) for a, b in zip(c0, c1))


def rgba(c, a=255):
    return c if len(c) == 4 else (c[0], c[1], c[2], a)


def polar(c, r, deg):
    a = math.radians(deg)
    return (c[0] + r * math.cos(a), c[1] + r * math.sin(a))


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
        return max(1, int(round(w * SS)))

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
        # blur premultiplied, so transparent black never bleeds a dark fringe into the colour
        other.im = other.im.convert("RGBa").filter(ImageFilter.GaussianBlur(radius * SS)).convert("RGBA")
        self.put(other, opacity, mask)

    def done(self):
        return self.im.resize((self.w, self.h), Image.LANCZOS)


def circle_mask(size, c, r, ss=SS):
    m = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(m).ellipse(((c[0] - r) * ss, (c[1] - r) * ss, (c[0] + r) * ss, (c[1] + r) * ss), fill=255)
    return m


def rect_mask(size, boxes, ss=SS):
    m = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    d = ImageDraw.Draw(m)
    for x0, y0, x1, y1 in boxes:
        d.rectangle((x0 * ss, y0 * ss, x1 * ss, y1 * ss), fill=255)
    return m


def bezier(pts, n=40):
    """Bezier of any degree through De Casteljau."""
    out = []
    for i in range(n + 1):
        t = i / n
        q = list(pts)
        while len(q) > 1:
            q = [(lerp(a[0], b[0], t), lerp(a[1], b[1], t)) for a, b in zip(q, q[1:])]
        out.append(q[0])
    return out


def offset_line(pts, d):
    out = []
    for i, (x, y) in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        m = math.hypot(tx, ty) or 1.0
        out.append((x + ty / m * d, y - tx / m * d))
    return out


def strap(p, pts, width, fill, ink=INK, w=2.5, hi=None, lo=None):
    """A flat band of `width` along a polyline: filled, inked edges, one highlight line."""
    a = offset_line(pts, width / 2)
    b = offset_line(pts, -width / 2)
    p.poly(a + b[::-1], fill, None)
    if hi:
        p.line(offset_line(pts, width / 2 - 3), hi, 1.6)
    if lo:
        p.line(offset_line(pts, -width / 2 + 3), lo, 1.6)
    if ink:
        p.line(a, ink, w)
        p.line(b, ink, w)


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
        a = im.getchannel("A")
        im.paste((0, 0, 0, 0), mask=a.point(lambda v: 255 if v == 0 else 0))
    path = os.path.join(OUT, name + ".png")
    im.save(path, optimize=False, compress_level=9)
    print("  wrote", os.path.relpath(path, ROOT), im.size, im.mode)


def rivet(p, x, y, r=3.2, col=WALL_HI):
    p.ell(x, y, r, r, col, INK, 1.3)


def tangents(c1, r1, c2, r2):
    """External tangent points (on c1, on c2) for both strands, in screen coordinates."""
    dx, dy = c2[0] - c1[0], c2[1] - c1[1]
    d = math.hypot(dx, dy)
    th = math.atan2(dy, dx)
    al = math.acos((r1 - r2) / d)
    out = []
    for s in (1, -1):
        ph = th + s * al
        out.append(((c1[0] + r1 * math.cos(ph), c1[1] + r1 * math.sin(ph)),
                    (c2[0] + r2 * math.cos(ph), c2[1] + r2 * math.sin(ph)), ph))
    return out


def rotated_rect(cx, top, w, h, ang, r=0.0, n=6):
    """Corners of a (rounded) w x h rect hanging from (cx, top), rotated `ang` deg about that point."""
    pts = []
    x0, x1, y0, y1 = cx - w / 2, cx + w / 2, top, top + h
    if r <= 0:
        pts = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    else:
        for (ccx, ccy, a0) in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
            for k in range(n + 1):
                a = math.radians(a0 + 90 * k / n)
                pts.append((ccx + r * math.cos(a), ccy + r * math.sin(a)))
    return [rot(q, (cx, top), ang) for q in pts]


# ----------------------------------------------------------------------------- the room shell

def shell(p, rng, stage):
    # ceiling: a storm-navy deck head with one heavy beam
    p.rect(-4, -4, W + 4, 80, CEIL, None)
    p.rect(-4, 58, W + 4, 82, STORM, INK, 3)
    p.line([(-4, 64), (W + 4, 64)], STORM_HI, 2)
    for x in range(30, W, 96):
        rivet(p, x, 72, 2.6, STORM_HI)
    # riveted iron wall, painted sea-glass, rows of plates
    p.rect(-4, 82, W + 4, DADO_Y, WALL, None)
    rows = [82, 268, 454, DADO_Y]
    for j in range(3):
        y0, y1 = rows[j], rows[j + 1]
        off = 0 if j % 2 == 0 else 92
        xs = [-4] + [x for x in range(off + 184, W, 184)] + [W + 4]
        for x in xs[1:-1]:
            p.line([(x, y0 + 2), (x, y1 - 2)], WALL_DK, 3)
            p.line([(x + 3, y0 + 2), (x + 3, y1 - 2)], WALL_HI, 1.4)
            for y in range(int(y0) + 16, int(y1) - 6, 26):
                rivet(p, x - 8, y, 2.6)
                rivet(p, x + 11, y, 2.6)
        if j > 0:
            p.line([(-4, y0), (W + 4, y0)], WALL_DK, 3)
            p.line([(-4, y0 + 3), (W + 4, y0 + 3)], WALL_HI, 1.4)
            for x in range(10, W, 26):
                rivet(p, x, y0 - 9, 2.6)
                rivet(p, x + 13, y0 + 12, 2.6)
    # faint paint mottle on the plates: broad, low, matte
    lay = p.layer()
    for _ in range(26):
        x, y = rng.uniform(0, W), rng.uniform(100, DADO_Y - 20)
        lay.ell(x, y, rng.uniform(60, 160), rng.uniform(30, 80), WALL_DK, None)
    p.put_soft(lay, 30, 0.22)
    # storm-navy dado: iron sheet, its own seams, a moulded top rail
    p.rect(-4, DADO_Y, W + 4, FLOOR_Y, STORM, None)
    for x in range(118, W, 236):
        p.line([(x, DADO_Y + 12), (x, FLOOR_Y - 4)], STORM_DK, 3)
        p.line([(x + 3, DADO_Y + 12), (x + 3, FLOOR_Y - 4)], STORM_HI, 1.2)
        for y in range(DADO_Y + 30, FLOOR_Y - 10, 30):
            rivet(p, x - 8, y, 2.4, STORM_HI)
    if stage in ("s3", "s4"):
        damp(p, rng, wet=True)
    elif stage == "sever":
        damp(p, rng, wet=False)
    p.rect(-4, DADO_Y - 6, W + 4, DADO_Y + 10, STORM_HI, INK, 3)
    p.line([(-4, DADO_Y - 1), (W + 4, DADO_Y - 1)], mix(STORM_HI, WALL_HI, 0.5), 1.6)
    # skirting angle iron
    p.rect(-4, FLOOR_Y - 10, W + 4, FLOOR_Y + 4, IRON_HI, INK, 3)
    # floor: iron deck (the dust layer) then timber
    p.rect(-4, FLOOR_Y + 4, W + 4, DUST_Y1, DECK, None)
    p.rect(-4, DUST_Y1, W + 4, H + 4, TIMBER, None)
    p.line([(-4, DUST_Y1), (W + 4, DUST_Y1)], INK, 3)
    y, k = DUST_Y1, 0
    while y < H:
        hgt = 44 + k * 7
        p.line([(-4, y + 3), (W + 4, y + 3)], TIMBER_HI, 1.2)
        p.line([(-4, y + hgt), (W + 4, y + hgt)], TIMBER_DK, 2.5)
        x = rng.uniform(0, 300)
        while x < W:
            in_tabs = x < 545 and y + hgt > 915 and y < 992
            if not in_tabs:
                p.line([(x, y + 4), (x, y + hgt - 3)], TIMBER_DK, 2)
            x += rng.uniform(300, 520)
        y += hgt
        k += 1
    dust(p, rng, stage)


def damp(p, rng, wet):
    """The tide line on the dado's base, 40 px up from the floor; dried to salt for the sever."""
    pts = []
    x = -4
    while x <= W + 8:
        pts.append((x, FLOOR_Y - 40 + 5 * math.sin(x / 47.0) + rng.uniform(-2.2, 2.2)))
        x += 12
    if wet:
        p.poly(pts + [(W + 8, FLOOR_Y), (-4, FLOOR_Y)], mix(mix(SEAGLASS, STORM, 0.55), INK, 0.35), None)
        p.line([(q[0], q[1] + 7) for q in pts], mix(SEAGLASS, STORM, 0.4), 2)
        p.line(pts, INK, 2.6)
        p.line([(q[0], q[1] - 3) for q in pts], mix(SEAGLASS_HI, STORM, 0.3), 1.4)
        for _ in range(34):  # runs dropping down from the line
            x = rng.uniform(0, W)
            y0 = FLOOR_Y - 40 + 5 * math.sin(x / 47.0)
            p.line([(x, y0), (x, y0 + rng.uniform(8, 30))], INK, 1.4)
    else:
        p.line(pts, SALT, 3)
        p.line([(q[0], q[1] + 4) for q in pts], mix(SALT, STORM, 0.5), 1.4)


def dust(p, rng, stage):
    y0, y1 = FLOOR_Y + 4, DUST_Y1
    p.rect(-4, y0, W + 4, y1, DUST, None)
    # even dust: faint plate seams showing through, soft mottle
    for x in range(140, W, 280):
        p.line([(x, y0), (x, y1)], DUST_LO, 2)
    lay = p.layer()
    for _ in range(140):
        x, y = rng.uniform(0, W), rng.uniform(y0, y1)
        lay.ell(x, y, rng.uniform(16, 60), rng.uniform(2, 5), DUST_HI if rng.random() < 0.5 else DUST_LO, None)
    p.put_soft(lay, 3, 0.18)
    if stage in ("s3", "s4"):
        # combed into straight lines that all point at the diaphragm
        clip = rect_mask((W, H), [(-4, y0, W + 4, y1)])
        lay = p.layer()
        n = 28
        for i in range(n):
            xb = -60 + (W + 120) * (i + 0.5) / n          # where the line meets the bottom of the band
            dx, dy = xb - RING_C[0], y1 - RING_C[1]
            t0 = (y0 - RING_C[1]) / dy
            xt = RING_C[0] + dx * t0
            lay.line([(xt, y0), (xb, y1)], DUST_LO, 7)
            lay.line([(xt + 3, y0), (xb + 4, y1)], DUST_HI, 4)
        p.put(lay, 1.0, clip)
    p.line([(-4, y0), (W + 4, y0)], INK, 2.5)


# ----------------------------------------------------------------------------- the diaphragm ring

def ring(p, rng, stage):
    cx, cy = RING_C
    sh = p.layer()
    sh.ell(cx + 10, cy + 14, RING_R + 4, RING_R + 4, (10, 16, 22, 255), None)
    p.put_soft(sh, 12, 0.45)
    p.ell(cx, cy, RING_R, RING_R, IRON, INK, 4)
    p.ell(cx, cy, RING_R - 7, RING_R - 7, None, IRON_HI, 2)
    p.arc(cx, cy, RING_R - 4, RING_R - 4, 190, 290, mix(IRON_HI, WALL_HI, 0.45), 3)
    p.ell(cx, cy, MEM_R + 6, MEM_R + 6, None, IRON_LO, 3)
    # the recess the membrane sits in (the sprite covers it)
    p.ell(cx, cy, MEM_R, MEM_R, MEMBRANE, INK, 3.5)
    # cracks first, so the bolts sit on top
    if stage in ("s4", "sever"):
        for k in range(14):
            a = k * 360 / 14 + rng.uniform(-9, 9)
            r = RING_R + 2
            pts = [polar(RING_C, r, a)]
            L = rng.uniform(30, 60)
            aa = a
            while r < RING_R + L:
                r += rng.uniform(7, 12)
                aa += rng.uniform(-5, 5)
                pts.append(polar(RING_C, r, aa))
            p.line(pts, INK, 1.6)
            if rng.random() < 0.6:
                q = pts[len(pts) // 2]
                b = aa + rng.choice((-1, 1)) * rng.uniform(20, 35)
                p.line([q, polar(q, rng.uniform(10, 18), b)], INK, 1.2)
    for i in range(12):
        a = i * 30
        hp = polar(RING_C, BOLT_R, a)
        if stage == "s4":
            # bright threaded shank between head and flange: the bolt is backing out
            s0, s1 = polar(RING_C, BOLT_R + BOLT_HEAD - 2, a), polar(RING_C, BOLT_R + BOLT_HEAD + 12, a)
            strap(p, [s0, s1], 11, BRASS, INK, 1.6)
            for t in range(4):
                q = polar(RING_C, BOLT_R + BOLT_HEAD + 1 + t * 3, a)
                p.line([polar(q, 5, a + 90), polar(q, 5, a - 90)], BRASS_HI, 1.4)
        hexa = [polar(hp, BOLT_HEAD, a + 30 + 60 * k) for k in range(6)]
        p.poly([(x + 2, y + 3) for x, y in hexa], (14, 20, 26), None)
        p.poly(hexa, IRON_HI, INK, 2.2)
        p.ell(hp[0], hp[1], 6.5, 6.5, None, IRON, 1.6)
        # one white radial paint stripe across head and flange
        inner = (BOLT_R - BOLT_HEAD - 3, BOLT_R)
        outer = (BOLT_R, BOLT_R + BOLT_HEAD + 4)
        if stage in ("s4", "sever"):
            p.line([polar(RING_C, inner[0], a), polar(RING_C, inner[1] - 1, a)], PAINT, 4)
            o0, o1 = polar(RING_C, outer[0] + 1, a), polar(RING_C, outer[1], a)
            sx, sy = 4 * math.cos(math.radians(a + 90)), 4 * math.sin(math.radians(a + 90))
            p.line([(o0[0] + sx, o0[1] + sy), (o1[0] + sx, o1[1] + sy)], PAINT, 4)
            m = polar(RING_C, BOLT_R, a)
            p.line([polar(m, 4, a + 90), polar(m, 4, a - 90)], INK, 1.2)
        else:
            p.line([polar(RING_C, inner[0], a), polar(RING_C, outer[1], a)], PAINT, 4)


# ----------------------------------------------------------------------------- machinery

def lamp(p, lit):
    x, y = LAMP
    # wall bracket from the left
    p.rect(x - 64, y - 8, x - 18, y + 6, IRON, INK, 2.5)
    p.rect(x - 72, y - 22, x - 58, y + 20, IRON_HI, INK, 2.5, r=3)
    rivet(p, x - 65, y - 13, 2.4, IRON_HI)
    rivet(p, x - 65, y + 11, 2.4, IRON_HI)
    glass = (240, 204, 132) if lit else (150, 154, 150)
    p.ell(x, y, 24, 28, IRON, INK, 3)
    p.ell(x, y, 18, 22, glass, INK, 2)
    if lit:
        p.ell(x - 4, y - 6, 7, 9, (252, 236, 196), None)
    for dx in (-9, 0, 9):  # cage bars
        p.line([(x + dx, y - 22 * math.sqrt(max(0, 1 - (dx / 18) ** 2))), (x + dx, y + 22 * math.sqrt(max(0, 1 - (dx / 18) ** 2)))], INK, 2.4)
    p.line([(x - 18, y), (x + 18, y)], INK, 2.4)
    p.ell(x, y, 24, 28, None, INK, 3)


def shaft(p):
    for hx in HANGERS:  # ceiling hangers
        p.poly([(hx - 18, 80), (hx + 18, 80), (hx + 8, 118), (hx - 8, 118)], IRON, INK, 2.5)
        p.ell(hx, 128, 14, 14, IRON_HI, INK, 2.5)
    x0, y0, x1, y1 = SHAFT
    p.rect(x0, y0, x1, y1, IRON_HI, INK, 2.5, r=3)
    p.line([(x0 + 4, y0 + 4), (x1 - 4, y0 + 4)], mix(IRON_HI, WALL_HI, 0.45), 1.6)
    for hx in HANGERS:
        p.rect(hx - 12, y0 - 4, hx + 12, y1 + 4, IRON, INK, 2.5, r=3)
    # overhead pulley bracket and its small bevel box
    bx, by = TOP_PULLEY
    p.poly([(bx - 30, 80), (bx + 30, 80), (bx + 16, by - 22), (bx - 16, by - 22)], IRON, INK, 2.5)
    p.rect(bx - 26, by - 26, bx + 26, by + 26, IRON_HI, INK, 2.5, r=4)
    p.ell(bx, by, 12, 12, IRON, INK, 2)
    for q in ((bx - 20, by - 20), (bx + 20, by - 20), (bx - 20, by + 20), (bx + 20, by + 20)):
        rivet(p, q[0], q[1], 2.4, BRASS_HI)


def drum(p, box):
    x, y, w, h = box
    p.rect(x + 6, y, x + w - 6, y + h, IRON_HI, INK, 2.5)
    p.line([(x + 8, y + 9), (x + w - 8, y + 9)], mix(IRON_HI, WALL_HI, 0.5), 2)
    p.line([(x + 8, y + h - 9), (x + w - 8, y + h - 9)], IRON_LO, 2)
    p.ell(x + 6, y + h / 2, 9, h / 2, IRON, INK, 2.5)
    p.ell(x + w - 6, y + h / 2, 9, h / 2, IRON, INK, 2.5)


def column(p, rng):
    x, y, w, h = COLUMN
    sh = p.layer()
    sh.rect(x + 8, y + 10, x + w + 10, y + h + 6, (10, 16, 22, 255), None)
    p.put_soft(sh, 8, 0.4)
    p.rect(x, y, x + w, y + h, IRON, INK, 3)
    p.rect(x + 8, y + 8, x + w - 8, y + h - 8, None, IRON_HI, 2)
    for yy in range(y + 18, y + h - 10, 34):
        rivet(p, x + 15, yy, 2.4, IRON_HI)
        rivet(p, x + w - 15, yy, 2.4, IRON_HI)
    # blank brass nameplate, four rivets
    nx, ny, nw, nh = NAMEPLATE
    p.rect(nx, ny, nx + nw, ny + nh, BRASS, INK, 2.5, r=3)
    p.rect(nx + 7, ny + 7, nx + nw - 7, ny + nh - 7, None, BRASS_HI, 1.4, r=2)
    for q in ((nx + 9, ny + 9), (nx + nw - 9, ny + 9), (nx + 9, ny + nh - 9), (nx + nw - 9, ny + nh - 9)):
        rivet(p, q[0], q[1], 3, BRASS_HI)
    # the nail and its ring of nine tarnished tags
    tx, ty = NAIL
    p.ell(tx, ty + 14, 12, 12, None, BRASS_LO, 3)
    tags = list(range(9))
    for i in tags:
        ang = -24 + 48 * i / 8 + rng.uniform(-2, 2)
        top = (tx, ty + 24)
        pts = rotated_rect(top[0], top[1], 22, 82, ang, r=4)
        col = mix(BRASS_LO, BRASS_DK, rng.uniform(0.0, 0.5))
        p.poly(pts, col, INK, 2)
        hole = rot((top[0], top[1] + 8), top, ang)
        p.ell(hole[0], hole[1], 2.6, 2.6, IRON_LO, None)
    p.ell(tx, ty + 14, 12, 12, None, INK, 4.2)
    p.ell(tx, ty + 14, 12, 12, None, BRASS, 2.2)
    p.ell(tx, ty, 5, 5, IRON_HI, INK, 2)


def crank_mount(p):
    cx, cy = CRANK
    p.rect(cx - 24, cy - 24, cx + 14, cy + 30, IRON, INK, 2.5, r=3)
    p.rect(cx - 30, cy + 30, cx + 20, cy + 40, IRON_HI, INK, 2.5)
    p.ell(cx, cy, 9, 9, IRON_HI, INK, 2)


def pedestal(p):
    hx, hy = FLY
    sh = p.layer()
    sh.poly([(752, 742), (968, 742), (874, hy + 4), (846, hy + 4)], (10, 16, 22, 255), None)
    p.put_soft(sh, 8, 0.35)
    # A-frame: two cast legs and a web
    p.poly([(760, 740), (800, 740), (872, hy + 10), (848, hy + 10)], IRON, INK, 3)
    p.poly([(920, 740), (960, 740), (872, hy + 10), (848, hy + 10)], IRON, INK, 3)
    p.poly([(812, 690), (908, 690), (896, 706), (824, 706)], IRON_HI, INK, 2.5)
    p.ell(860, 660, 18, 18, IRON_LO, INK, 2.5)
    # foot plate bolted to the deck
    p.rect(740, 736, 980, 760, IRON_HI, INK, 3)
    for x in (756, 964):
        rivet(p, x, 748, 3, IRON)
    p.rect(750, 760, 970, 806, IRON, INK, 3)
    # bearing block at the hub
    p.rect(hx - 34, hy - 26, hx + 34, hy + 26, IRON_HI, INK, 3, r=4)
    p.ell(hx, hy, 16, 16, IRON, INK, 2.5)


def board(p, rng):
    x, y, w, h = BOARD
    # pipe stubs and the INDEX pipe first: they disappear behind the frame and the board
    for sx in SOCKETS[:3]:
        p.rect(sx - 8, FRAME[1] + FRAME[3] - 10, sx + 8, y + 4, IRON_HI, INK, 2.5)
        p.rect(sx - 13, y - 14, sx + 13, y - 4, IRON, INK, 2.2)
    ix = INDEX_X
    p.rect(ix - 9, 78, ix + 9, y + 4, IRON_HI, INK, 2.5)
    p.line([(ix - 4, 82), (ix - 4, y)], mix(IRON_HI, WALL_HI, 0.45), 1.4)
    sh = p.layer()
    sh.rect(x + 8, y + 10, x + w + 10, y + h + 8, (10, 16, 22, 255), None)
    sh.rect(FRAME[0] + 8, FRAME[1] + 10, FRAME[0] + FRAME[2] + 8, FRAME[1] + FRAME[3] + 8, (10, 16, 22, 255), None)
    p.put_soft(sh, 8, 0.38)
    # maintenance drawing frame: brass, blank cream paper (the view draws the circuit)
    fx, fy, fw, fh = FRAME
    p.rect(fx, fy, fx + fw, fy + fh, BRASS, INK, 3, r=3)
    p.rect(fx + 4, fy + 4, fx + fw - 4, fy + fh - 4, None, BRASS_HI, 1.4)
    px, py, pw, ph = FRAME_PAPER
    p.rect(px, py, px + pw, py + ph, PAPER_HI, INK, 2)
    p.rect(px + 8, py + 8, px + pw - 8, py + ph - 8, None, mix(PAPER, INK, 0.25), 1.2)
    # the INDEX cap flange, hatched, with its lead seal tab, sits over the frame's lower edge
    p.rect(ix - 16, 372, ix + 16, 388, IRON_HI, INK, 2.5)
    for k in range(6):
        hx0 = ix - 16 + k * 6
        p.line([(hx0, 386), (hx0 + 6, 374)], INK, 1.4)
    p.line([(ix + 14, 384), (ix + 22, 398)], LEAD_HI, 1.4)
    p.ell(ix + 24, 404, 7, 7, LEAD, INK, 2)
    p.ell(ix + 22, 402, 2.5, 2.5, LEAD_HI, None)
    # the enamel valve board
    p.rect(x - 6, y - 6, x + w + 6, y + h + 6, BRASS_HI, INK, 3, r=7)
    p.rect(x, y, x + w, y + h, STORM, INK, 2.5, r=4)
    p.rect(x + 10, y + 10, x + w - 10, y + h - 10, None, STORM_HI, 1.4, r=3)
    for q in ((x + 14, y + 14), (x + w - 14, y + 14), (x + 14, y + h - 14), (x + w - 14, y + h - 14)):
        rivet(p, q[0], q[1], 3, BRASS_HI)
    for sx in SOCKETS:
        p.rect(sx - 26, 470, sx + 26, 490, ENAMEL, INK, 2, r=2)   # blank label strip
        p.ell(sx, SOCKET_Y, 17, 17, BRASS_HI, INK, 2.5)
        p.ell(sx, SOCKET_Y, 9, 9, GLASS_DK, INK, 2)
        p.ell(sx, SOCKET_Y - 3, 4, 4, IRON_HI, None)
    # PUMP lever slot, with its blank plate
    p.rect(LEVER_X - 22, 494, LEVER_X + 22, 510, ENAMEL, INK, 2, r=2)
    p.rect(LEVER_X - 8, 520, LEVER_X + 8, 640, GLASS_DK, INK, 2.5, r=6)
    p.rect(LEVER_X - 14, 528, LEVER_X + 14, 548, BRASS, INK, 2.5, r=3)
    p.ell(LEVER_X, 538, 7, 7, BRASS_HI, INK, 1.8)
    # a blank gauge in the board's lower half, flanked by the pipe manifold
    p.ell(1170, 680, 34, 34, BRASS_HI, INK, 3)
    p.ell(1170, 680, 27, 27, PAPER_HI, INK, 2)
    p.line([(1170, 680), (1150, 666)], INK, 2.5)
    p.ell(1170, 680, 3.5, 3.5, INK, None)
    p.rect(1226, 664, 1330, 696, IRON_HI, INK, 2.5, r=4)
    for mx in (1242, 1278, 1314):
        p.ell(mx, 680, 8, 8, IRON, INK, 2)


def pump(p):
    x, y, w, h = PUMP
    sh = p.layer()
    sh.rect(x + 6, y + 10, x + w + 12, y + h + 4, (10, 16, 22, 255), None)
    p.put_soft(sh, 7, 0.4)
    # bed plate, the cylinder and its cap, a stout outlet pipe up into the dado
    p.rect(x - 8, y + h - 16, x + w + 8, y + h, IRON_HI, INK, 3)
    p.rect(x + w - 20, y + 14, W + 4, y + 34, IRON_HI, INK, 2.5)
    p.rect(x + w + 30, y + 8, x + w + 42, y + 40, IRON, INK, 2.2)
    p.rect(x + 120, y + 10, x + 250, y + h - 16, IRON, INK, 3, r=8)
    p.rect(x + 112, y - 4, x + 258, y + 14, IRON_HI, INK, 3, r=4)
    for k in range(5):
        rivet(p, x + 128 + k * 28, y + 5, 2.6, IRON)
    p.line([(x + 132, y + 22), (x + 132, y + h - 24)], mix(IRON_HI, WALL_HI, 0.35), 2)
    # pulley pedestal with the axle boss at (1180,880)
    ax, ay = PUMP_PULLEY
    p.poly([(x + 18, y + h - 16), (x + 120, y + h - 16), (ax + 18, ay - 10), (ax - 18, ay - 10)], IRON, INK, 3)
    p.ell(ax, ay, 22, 22, IRON_HI, INK, 3)
    p.ell(ax, ay, 9, 9, IRON, INK, 2)


def paint_room(rng, stage="base"):
    p = Pen(W, H, rng)
    shell(p, rng, stage)
    ring(p, rng, stage)
    lamp(p, lit=stage != "sever")
    pedestal(p)
    column(p, rng)
    drum(p, DRUM_TOP)
    drum(p, DRUM_LOW)
    crank_mount(p)
    shaft(p)
    board(p, rng)
    pump(p)
    im = p.done()
    if stage == "sever":
        im = daylight(im)
    return im


def daylight(im):
    """Ending A: the same room under flat cool grey daylight."""
    rgb = im.convert("RGB")
    g = ImageOps.grayscale(rgb)
    cool = Image.merge("RGB", [g.point(lambda v: int(v * 0.94 + 10)), g.point(lambda v: int(v * 0.98 + 12)),
                               g.point(lambda v: int(min(255, v * 1.04 + 16)))])
    out = Image.blend(rgb, cool, 0.55)
    return ImageEnhance.Brightness(out).enhance(1.08)


# ----------------------------------------------------------------------------- belts

def belt_strand(p, a, b, width=14):
    strap(p, [a, b], width, LEATHER, INK, 2.2, hi=LEATHER_HI)


def wrap(p, c, r, a0, a1, width=14, n=24):
    """A belt lying around a pulley from angle a0 to a1 (radians, a1 > a0)."""
    pts = [(c[0] + r * math.cos(lerp(a0, a1, i / n)), c[1] + r * math.sin(lerp(a0, a1, i / n))) for i in range(n + 1)]
    strap(p, pts, width, LEATHER, INK, 2.2, hi=LEATHER_HI)


def paint_belt1(rng, slack):
    p = Pen(W, H, rng)
    if not slack:
        (a1, a2, ph1), (b1, b2, ph2) = tangents(FLY, FLY_R + 7, PUMP_PULLEY, PULLEY_R + 7)
        lo, hi = sorted((ph1, ph2))
        wrap(p, PUMP_PULLEY, PULLEY_R + 7, lo, hi)
        belt_strand(p, a1, a2)
        belt_strand(p, b1, b2)
    else:
        # slipped off the pump: hanging from the flywheel's rim, the loop lying on the deck
        s1 = polar(FLY, FLY_R + 7, 22)
        s2 = polar(FLY, FLY_R + 7, 112)
        loop_c, rx, ry = (1090, 895), 150, 9
        right = (loop_c[0] + rx, loop_c[1] - 2)
        left = (loop_c[0] - rx + 30, loop_c[1] - 6)
        lay = p.layer()
        pts = [(loop_c[0] + rx * math.cos(t * 2 * math.pi / 60), loop_c[1] + ry * math.sin(t * 2 * math.pi / 60))
               for t in range(61)]
        strap(lay, pts, 12, LEATHER_DK, INK, 2.2, hi=LEATHER)
        p.put(lay)
        belt_strand_curve(p, bezier([s1, (s1[0] + 40, s1[1] + 160), (right[0], right[1] - 80), right]))
        belt_strand_curve(p, bezier([s2, (s2[0] + 10, s2[1] + 110), (left[0] - 30, left[1] - 40), left]))
    return p


def belt_strand_curve(p, pts, width=14):
    strap(p, pts, width, LEATHER, INK, 2.2, hi=LEATHER_HI)


def paint_belt3(rng, slack):
    p = Pen(W, H, rng)
    if not slack:
        (a1, a2, ph1), (b1, b2, ph2) = tangents(FLY, FLY_R + 7, TOP_PULLEY, PULLEY_R + 7)
        # wrap over the top pulley: the arc away from the flywheel (upward)
        lo, hi = sorted((ph1, ph2))
        wrap(p, TOP_PULLEY, PULLEY_R + 7, hi - 2 * math.pi, lo) if hi - lo > math.pi else wrap(p, TOP_PULLEY, PULLEY_R + 7, lo, hi)
        belt_strand(p, a1, a2)
        belt_strand(p, b1, b2)
    else:
        cx, cy = TOP_PULLEY
        r = PULLEY_R + 7
        wrap(p, TOP_PULLEY, r, math.pi, 2 * math.pi)
        lft, rgt = (cx - r, cy), (cx + r, cy)
        u = bezier([lft, (cx - r - 14, 330), (cx - 46, 470), (cx, 470)], 40) + \
            bezier([(cx, 470), (cx + 46, 470), (cx + r + 14, 330), rgt], 40)[1:]
        belt_strand_curve(p, u)
    return p


def paint_belt2(rng, slack):
    p = Pen(W, H, rng)
    x0, x1 = 556, 684
    if not slack:
        sh = p.layer()
        sh.rect(x0 + 6, 132, x1 + 6, 664, (10, 16, 22, 255), None)
        p.put_soft(sh, 6, 0.35)
        p.rect(x0, 128, x1, 664, LEATHER, INK, 3)
        p.line([(x0 + 6, 132), (x0 + 6, 660)], LEATHER_HI, 2)
        p.line([(x1 - 6, 132), (x1 - 6, 660)], LEATHER_DK, 2)
        # a laced splice, plain stitch holes only
        for y in (380, 396):
            p.line([(x0 + 2, y), (x1 - 2, y)], LEATHER_DK, 2.5)
        for k in range(9):
            xx = x0 + 14 + k * 12.5
            p.ell(xx, 388, 2.2, 2.2, INK, None)
        # scuffed wear along the band
        lay = p.layer()
        for _ in range(16):
            yy = rng.uniform(150, 640)
            lay.line([(rng.uniform(x0 + 12, x0 + 50), yy), (rng.uniform(x1 - 50, x1 - 12), yy + rng.uniform(-2, 2))],
                     LEATHER_HI, 1.4)
        p.put(lay, 0.45)
        # band over the drum faces at the top and bottom
        p.rect(x0, 128, x1, 140, LEATHER_DK, INK, 2)
        p.rect(x0, 652, x1, 664, LEATHER_DK, INK, 2)
    else:
        # slipped off the lower drum: over the top drum, folded down the left of the column
        p.poly([(x0 + 40, 100), (x1, 104), (x1 - 4, 116), (x0 + 30, 114)], LEATHER, INK, 2.5)
        top = [(x0 + 50, 106), (540, 100), (526, 128)]
        strap(p, bezier(top, 16), 14, LEATHER, INK, 2.2, hi=LEATHER_HI)
        # the hanging fold: a strip that zig-zags as it lies on itself
        lx, rx = 520, 556
        ys = [128, 196, 236, 318, 352, 430, 466, 540]
        for i in range(len(ys) - 1):
            ya, yb = ys[i], ys[i + 1]
            dx = 3 if i % 2 else -2
            col = LEATHER if i % 2 == 0 else LEATHER_DK
            p.poly([(lx + dx, ya), (rx + dx, ya), (rx - dx, yb), (lx - dx, yb)], col, INK, 2.5)
            if i % 2 == 0:
                p.line([(lx + dx + 6, ya + 4), (lx - dx + 6, yb - 4)], LEATHER_HI, 1.6)
        # the crumpled bottom loop
        p.poly([(lx - 4, 536), (rx + 2, 534), (560, 576), (548, 630), (520, 642), (492, 630), (486, 590)],
               LEATHER_DK, INK, 3)
        p.poly([(502, 566), (544, 556), (550, 594), (532, 622), (506, 616)], (40, 30, 24), INK, 2.2)
        p.line([(490, 590), (524, 578), (554, 586)], LEATHER, 2.4)
        p.line([(498, 612), (524, 604)], LEATHER_HI, 1.6)
    return p


# ----------------------------------------------------------------------------- rotating sprites

def paint_flywheel(rng):
    p = Pen(380, 380, rng)
    c = (190, 190)
    p.ell(c[0], c[1], 180, 180, IRON, INK, 4)
    p.ell(c[0], c[1], 156, 156, mix(IRON_LO, (0, 0, 0), 0.0), INK, 3)
    p.arc(c[0], c[1], 168, 168, 195, 285, mix(IRON_HI, WALL_HI, 0.35), 3)
    p.arc(c[0], c[1], 168, 168, 15, 105, IRON_LO, 3)
    # the void between spokes stays transparent: cut it out after
    hole = p.layer()
    hole.ell(c[0], c[1], 154, 154, (255, 255, 255, 255), None)
    mask = hole.im.getchannel("A")
    a = ImageChops.subtract(p.im.getchannel("A"), mask)
    p.im.putalpha(a)
    p.ell(c[0], c[1], 156, 156, None, INK, 3)
    for k in range(6):
        ang = k * 60
        a0 = polar(c, 30, ang)
        a1 = polar(c, 158, ang)
        pts = [polar(a0, 10, ang + 90), polar(a1, 6.5, ang + 90), polar(a1, 6.5, ang - 90), polar(a0, 10, ang - 90)]
        p.poly(pts, IRON_HI, INK, 2.5)
    p.ell(c[0], c[1], 36, 36, IRON_HI, INK, 3)
    p.ell(c[0], c[1], 20, 20, BRASS, INK, 2.5)
    p.ell(c[0], c[1], 7, 7, IRON_LO, INK, 1.6)
    # a white balance mark on the rim: lets the eye read the turn
    p.line([polar(c, 158, -40), polar(c, 179, -40)], PAINT, 6)
    return p


def paint_pulley(rng):
    p = Pen(100, 100, rng)
    c = (50, 50)
    p.ell(50, 50, 44, 44, IRON, INK, 3)
    hole = p.layer()
    hole.ell(50, 50, 33, 33, (255, 255, 255, 255), None)
    p.im.putalpha(ImageChops.subtract(p.im.getchannel("A"), hole.im.getchannel("A")))
    p.ell(50, 50, 34, 34, None, INK, 2.2)
    p.arc(50, 50, 39, 39, 200, 290, mix(IRON_HI, WALL_HI, 0.35), 2)
    for k in range(3):
        ang = -90 + k * 120
        a0, a1 = polar(c, 10, ang), polar(c, 35, ang)
        p.poly([polar(a0, 5, ang + 90), polar(a1, 3.5, ang + 90), polar(a1, 3.5, ang - 90), polar(a0, 5, ang - 90)],
               IRON_HI, INK, 2)
    p.ell(50, 50, 12, 12, BRASS, INK, 2.2)
    p.ell(50, 50, 4, 4, IRON_LO, None)
    p.line([polar(c, 34, 30), polar(c, 43, 30)], PAINT, 3.5)
    return p


def paint_crank(rng):
    p = Pen(72, 72, rng)
    c = (36, 36)
    p.ell(36, 36, 30, 30, IRON_HI, INK, 2.5)
    p.ell(36, 36, 22, 22, None, IRON, 1.6)
    p.ell(36, 36, 7, 7, IRON, INK, 1.8)
    pin = polar(c, 18, 0)
    p.ell(pin[0], pin[1], 7, 7, BRASS_HI, INK, 2)
    p.ell(pin[0] - 1.5, pin[1] - 1.5, 2.4, 2.4, (236, 214, 160), None)
    return p


# ----------------------------------------------------------------------------- diaphragm sprites

def paint_diaphragm(rng):
    p = Pen(400, 400, rng)
    c = (200, 200)
    p.ell(200, 200, 192, 192, MEMBRANE, None)
    lay = p.layer()
    for k in range(18):  # very subtle radial creases
        a = k * 20 + rng.uniform(-6, 6)
        r0, r1 = rng.uniform(34, 60), rng.uniform(150, 186)
        lay.line([polar(c, r0, a), polar(c, (r0 + r1) / 2, a + rng.uniform(-3, 3)), polar(c, r1, a)], MEMBRANE_HI, 2.2)
    p.put_soft(lay, 1.2, 0.5)
    p.ell(200, 200, 192, 192, None, INK, 3)
    # brass hub boss
    p.ell(201, 203, 25, 25, (8, 10, 14), None)
    p.ell(200, 200, 24, 24, BRASS, INK, 2.5)
    p.ell(200, 200, 15, 15, None, BRASS_LO, 2)
    p.ell(195, 195, 6, 6, BRASS_HI, None)
    for k in range(4):
        q = polar(c, 19, 45 + 90 * k)
        p.ell(q[0], q[1], 2.2, 2.2, BRASS_DK, None)
    return p


def paint_hollow(rng):
    im = Image.new("RGBA", (400, 400), (0, 0, 0, 0))
    px = []
    col = mix((10, 8, 16), VIOLET, 0.18)
    for j in range(400):
        for i in range(400):
            r = math.hypot(i + 0.5 - 200, j + 0.5 - 200)
            t = max(0.0, 1.0 - r / 192.0)
            a = 0.85 * (t ** 1.3) if r < 192 else 0.0
            px.append((col[0], col[1], col[2], int(round(255 * a))))
    im.putdata(px)
    return im


def paint_sheen(rng):
    p = Pen(400, 400, rng)
    lay = p.layer()
    lay.ell(200, 200, 186, 186, rgba(SEAGLASS_HI), None)
    cut = p.layer()
    cut.ell(222, 224, 180, 180, (255, 255, 255, 255), None)
    lay.im.putalpha(ImageChops.subtract(lay.im.getchannel("A"), cut.im.getchannel("A")))
    # only the upper-left: fade the crescent out toward its tips
    fade = Image.new("L", lay.im.size, 0)
    fd = ImageDraw.Draw(fade)
    fd.pieslice((0, 0, 400 * SS, 400 * SS), 150, 300, fill=255)
    fade = fade.filter(ImageFilter.GaussianBlur(26 * SS))
    lay.im.putalpha(ImageChops.multiply(lay.im.getchannel("A"), fade))
    p.put_soft(lay, 3, 0.5)
    return p


def paint_slack(rng):
    p = Pen(400, 400, rng)
    c = (200, 200)
    grey = (46, 48, 52)
    grey_hi = (74, 76, 80)
    grey_lo = (28, 30, 34)
    p.ell(200, 200, 192, 192, grey, None)
    clip = circle_mask((400, 400), c, 192)
    lay = p.layer()
    # upper membrane hangs from the ring in long slack creases toward the drooped hub
    hub = (200, 214)
    for k in range(13):
        a = 190 + k * 160 / 12
        lay.line(bezier([polar(c, 192, a), polar(c, 120, a + 4), hub], 20), grey_hi, 2)
    # lower third: five heavy folds, catenaries stacked down to the ring
    for f in range(5):
        y = 262 + f * 26
        sag = 16 + f * 3
        top = bezier([(-10, y - 6), (200, y + sag), (410, y - 6)], 40)
        bot = bezier([(-10, y + 14), (200, y + sag + 20), (410, y + 14)], 40)
        lay.poly(top + bot[::-1], grey_hi if f % 2 == 0 else grey_lo, None)
        lay.line(top, INK, 3)
        lay.line(offset_line(top, -4), mix(grey_hi, PAPER, 0.25), 1.6)
    p.put(lay, 1.0, clip)
    p.ell(200, 200, 192, 192, None, INK, 3)
    p.ell(hub[0] + 1, hub[1] + 4, 25, 23, (8, 10, 14), None)
    p.ell(hub[0], hub[1], 24, 22, mix(BRASS, grey, 0.35), INK, 2.5)
    p.ell(hub[0] - 5, hub[1] - 5, 5, 5, mix(BRASS_HI, grey, 0.3), None)
    return p


def reflect_xy(x, y):
    """Room point -> diaphragm sprite point: mirrored left-right, scaled 0.3 about the ring centre."""
    return (200 - 0.3 * (x - RING_C[0]), 200 + 0.3 * (y - RING_C[1]))


def paint_reflect(rng, slack):
    p = Pen(400, 400, rng)
    lay = p.layer()
    col = SEAGLASS_HI
    R = lambda pts: [reflect_xy(*q) for q in pts]
    # the line shaft, drums, column and flywheel pedestal: faint context
    x0, y0, x1, y1 = SHAFT
    lay.poly(R([(x0, y0), (x1, y0), (x1, y1), (x0, y1)]), None, col, 1.6)
    for bx in (DRUM_TOP, DRUM_LOW):
        lay.poly(R([(bx[0], bx[1]), (bx[0] + bx[2], bx[1]), (bx[0] + bx[2], bx[1] + bx[3]), (bx[0], bx[1] + bx[3])]),
                 None, col, 1.6)
    lay.line(R([(760, 740), (860, 560), (960, 740)]), col, 1.6)
    lay.line(R([(-10, FLOOR_Y), (W, FLOOR_Y)]), col, 1.4)
    lay.line(R([(-10, DADO_Y), (W, DADO_Y)]), col, 1.0)
    # the flywheel
    fc = reflect_xy(*FLY)
    lay.ell(fc[0], fc[1], 54, 54, None, col, 2.6)
    lay.ell(fc[0], fc[1], 47, 47, None, col, 1.4)
    for k in range(6):
        lay.line([polar(fc, 9, k * 60 + 15), polar(fc, 47, k * 60 + 15)], col, 1.6)
    tp = reflect_xy(*TOP_PULLEY)
    lay.ell(tp[0], tp[1], 13, 13, None, col, 1.8)
    # the belts
    if not slack:
        lay.rect(82, 103, 120, 264, rgba(col, 120), col, 1.8)
        for (a1, a2, _) in tangents(FLY, FLY_R + 7, TOP_PULLEY, PULLEY_R + 7) + \
                tangents(FLY, FLY_R + 7, PUMP_PULLEY, PULLEY_R + 7):
            lay.line(R([a1, a2]), col, 4)
    else:
        b2 = p.layer()
        paint_room_lines_belt2_slack(b2, R, col)
        lay.put(b2)
        cx, cy = TOP_PULLEY
        lay.line(R(bezier([(cx - 51, cy), (cx - 65, 330), (cx - 46, 470), (cx, 470), (cx + 46, 470),
                           (cx + 65, 330), (cx + 51, cy)], 50)), col, 4)
        s1, s2 = polar(FLY, FLY_R + 7, 22), polar(FLY, FLY_R + 7, 112)
        lay.line(R(bezier([s1, (s1[0] + 40, s1[1] + 160), (1240, 813), (1240, 893)], 30)), col, 4)
        lay.line(R(bezier([s2, (s2[0] + 10, s2[1] + 110), (940, 849), (970, 889)], 30)), col, 4)
    # the lamp, a spot of light
    lp = reflect_xy(*LAMP)
    glow = p.layer()
    glow.ell(lp[0], lp[1], 14, 14, rgba(PAPER_HI), None)
    lay.put_soft(glow, 4, 0.8)
    lay.ell(lp[0], lp[1], 6, 6, rgba(PAPER_HI), None)
    p.put(lay, 0.62, circle_mask((400, 400), (200, 200), 186))
    return p


def paint_room_lines_belt2_slack(lay, R, col):
    pts = [(526, 128), (520, 196), (556, 236), (520, 318), (556, 352), (520, 430), (556, 466), (520, 540),
           (556, 576), (520, 640), (486, 590)]
    lay.line(R(pts), col, 4)
    lay.line(R([(556, 106), (684, 106)]), col, 3)


# ----------------------------------------------------------------------------- dust overlays

def paint_dust_streaks(rng):
    p = Pen(W, H, rng)
    lay = p.layer()
    focus_y = 856
    for i in range(40):
        y = 802 + (903 - 802) * (i + 0.5) / 40 + rng.uniform(-1.5, 1.5)
        xs = rng.uniform(940, 1100)
        xe = rng.uniform(80, 500)
        ye = lerp(y, focus_y, 0.55)
        pts = bezier([(xs, y), (lerp(xs, xe, 0.5), y + (ye - y) * 0.2), (xe, ye)], 30)
        w0 = rng.uniform(2.2, 4.4)
        # taper: draw in segments, thinning toward the ring
        for k in range(len(pts) - 1):
            t = k / (len(pts) - 1)
            lay.line([pts[k], pts[k + 1]], rgba(DUST_HI), max(0.8, w0 * (1 - 0.7 * t)))
        lay.ell(xs, y, w0 * 1.6, w0 * 0.9, rgba(DUST_HI), None)
    sh = p.layer()
    sh.im = lay.im.copy()
    sh.im = Image.merge("RGBA", [Image.new("L", sh.im.size, v) for v in DUST_LO] + [sh.im.getchannel("A")])
    sh.im = ImageChops.offset(sh.im, 0, 3 * SS)
    p.put(sh, 0.6)
    p.put(lay, 0.95)
    return p


def rake_wave(x):
    """The breath as a profile across x 600-1060: two short humps, a flat pause, one long hump."""
    base, peak = 870.0, 830.0
    for x0, x1 in ((602, 666), (674, 738), (860, 1060)):   # 70, 70, then 200 px, each smooth at its feet
        if x0 <= x <= x1:
            t = (x - x0) / (x1 - x0)
            return base - (base - peak) * math.sin(math.pi * t) ** 2
    return base


def paint_dust_raked(rng):
    p = Pen(W, H, rng)
    xs = [600 + i * 2 for i in range(231)]
    # a broad scuffed track first, dark, then the tines in pale
    track = [(x, rake_wave(x)) for x in xs]
    strap(p, track, 34, rgba(mix(DUST_LO, INK, 0.35), 235), None, 0)
    for k, off in enumerate((-12, -6, 0, 6, 12)):
        pts = offset_line(track, off)
        p.line([(x, y + 2) for x, y in pts], rgba(mix(DUST_LO, INK, 0.6), 240), 2.4)
        p.line(pts, rgba((236, 234, 222), 255), 3.2)
    # the rake's ends: a lifted dot at the start and the end, like a pen put down
    p.ell(600, 870, 6, 6, rgba((226, 224, 212)), rgba(mix(DUST_LO, INK, 0.45)), 1.6)
    p.ell(1060, 870, 6, 6, rgba((226, 224, 212)), rgba(mix(DUST_LO, INK, 0.45)), 1.6)
    return p


# ----------------------------------------------------------------------------- light maps

HOTSPOT_BOXES = [  # where the multiply map may darken by at most 5%
    (64, 224, 516, 676), (540, 100, 700, 690), (680, 380, 1040, 800), (1080, 140, 1400, 760),
    (1100, 780, 1380, 930), (0, 800, W, 910),
]


def _gauss(x, y, cx, cy, sx, sy):
    return math.exp(-(((x - cx) / sx) ** 2 + ((y - cy) / sy) ** 2) / 2)


def paint_light_mul(rng):
    im = Image.new("RGBA", (LW, LH))
    px = []
    for j in range(LH):
        for i in range(LW):
            x, y = (i + 0.5) * 4, (j + 0.5) * 4
            dx, dy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
            d = min(1.0, math.sqrt(dx * dx + dy * dy) / math.sqrt(2))
            dark = 0.15 * max(0.0, (d - 0.45) / 0.55) ** 1.5
            if any(x0 <= x <= x1 and y0 <= y <= y1 for x0, y0, x1, y1 in HOTSPOT_BOXES):
                dark = min(dark, 0.05)
            v = int(round(255 * (1 - dark)))
            px.append((v, v, min(255, v + 2), 255))
    im.putdata(px)
    return im.filter(ImageFilter.GaussianBlur(1.2))


def paint_light_add(rng):
    im = Image.new("RGBA", (LW, LH))
    px = []
    for j in range(LH):
        for i in range(LW):
            x, y = (i + 0.5) * 4, (j + 0.5) * 4
            k = _gauss(x, y, LAMP[0], LAMP[1], 46, 46) * 0.9 + _gauss(x, y, 430, 290, 150, 150) * 0.55
            c = _gauss(x, y, 1240, 560, 110, 90) * 0.5
            r = 74 * k + 6 * c
            g = 50 * k + 20 * c
            b = 20 * k + 26 * c
            px.append((int(min(255, r)), int(min(255, g)), int(min(255, b)), 255))
    im.putdata(px)
    return im


# ----------------------------------------------------------------------------- close-up: valves

C_SOCKETS = (305, 495, 685, 875)
C_SOCKET_Y = 790


def paint_c_valves(rng):
    p = Pen(W, H, rng)
    # wall behind: the same painted iron, closer
    p.rect(-4, -4, W + 4, H + 4, WALL, None)
    for x in (120, 480, 840, 1200):
        p.line([(x, 0), (x, H)], WALL_DK, 4)
        p.line([(x + 4, 0), (x + 4, H)], WALL_HI, 1.6)
        for y in range(30, H, 44):
            rivet(p, x - 12, y, 4)
            rivet(p, x + 16, y, 4)
    sh = p.layer()
    sh.rect(170, 110, 1300, 574, (10, 16, 22, 255), None)
    sh.rect(178, 596, 1300, 990, (10, 16, 22, 255), None)
    p.put_soft(sh, 12, 0.4)
    # pipe stubs off the board's top edge, one above each socket
    for cx in C_SOCKETS:
        p.rect(cx - 14, 540, cx + 14, 584, IRON_HI, INK, 3)
        p.rect(cx - 22, 562, cx + 22, 572, IRON, INK, 2.5)
    # brass-framed drawing sheet
    p.rect(156, 86, 1292, 562, BRASS, INK, 4, r=5)
    p.rect(162, 92, 1286, 556, None, BRASS_HI, 2)
    p.rect(170, 100, 1278, 550, PAPER_HI, INK, 3)
    lay = p.layer()
    lay.rect(170, 100, 1278, 550, None, PAPER, 30)
    p.put_soft(lay, 14, 0.7, rect_mask((W, H), [(172, 102, 1276, 548)]))
    p.rect(190, 120, 1258, 530, None, mix(PAPER, INK, 0.3), 1.6)
    # blank enamel fault window
    p.rect(886, 136, 1254, 204, BRASS, INK, 2.5, r=4)
    p.rect(890, 140, 1250, 200, ENAMEL, INK, 2, r=3)
    # the storm-navy enamel board
    p.rect(164, 574, 1284, 976, BRASS_HI, INK, 3.5, r=9)
    p.rect(170, 580, 1278, 970, STORM, INK, 3, r=6)
    p.rect(186, 596, 1262, 954, None, STORM_HI, 2, r=4)
    for q in ((192, 602), (1256, 602), (192, 948), (1256, 948)):
        rivet(p, q[0], q[1], 5, BRASS_HI)
    for cx in C_SOCKETS:
        p.rect(cx - 69, 626, cx + 69, 668, BRASS, INK, 2.5, r=4)
        p.rect(cx - 65, 630, cx + 65, 664, ENAMEL, INK, 2, r=3)
        p.ell(cx + 3, C_SOCKET_Y + 4, 32, 32, (12, 20, 28), None)
        p.ell(cx, C_SOCKET_Y, 30, 30, BRASS_HI, INK, 3)
        p.ell(cx, C_SOCKET_Y, 22, 22, BRASS, INK, 2)
        p.ell(cx, C_SOCKET_Y, 12, 12, GLASS_DK, INK, 2)
        # OPEN / SHUT throw stops: plain brass pins above and below the socket
        p.ell(cx, C_SOCKET_Y - 104, 5, 5, BRASS_LO, INK, 1.6)
        p.ell(cx, C_SOCKET_Y + 104, 5, 5, BRASS_LO, INK, 1.6)
    # blank gauge
    p.ell(1063, 684, 56, 56, (12, 20, 28), None)
    p.ell(1060, 680, 58, 58, BRASS_HI, INK, 3)
    p.ell(1060, 680, 52, 52, PAPER_HI, INK, 2.5)
    p.ell(1060, 680, 44, 44, None, mix(PAPER, INK, 0.25), 1.4)
    p.ell(1060, 680, 5, 5, INK, None)
    # PREVIEW key housing, with its indicator jewel above (unlit)
    p.rect(996, 776, 1124, 894, BRASS, INK, 3, r=6)
    p.rect(1004, 784, 1116, 886, IRON, INK, 2.5, r=5)
    p.rect(1014, 794, 1106, 876, GLASS_DK, INK, 2, r=4)
    p.ell(1060, 770, 14, 14, BRASS_HI, INK, 2.5)
    p.ell(1060, 770, 9, 9, mix(AMBER, IRON, 0.6), INK, 1.6)
    # PUMP lever slot and its blank plate
    p.rect(1136, 602, 1264, 644, BRASS, INK, 2.5, r=4)
    p.rect(1140, 606, 1260, 640, ENAMEL, INK, 2, r=3)
    p.rect(1179, 646, 1221, 904, BRASS, INK, 3, r=10)
    p.rect(1185, 650, 1215, 900, GLASS_DK, INK, 2.5, r=8)
    return p


def paint_toggle(rng, up):
    p = Pen(80, 200, rng)
    s = -1 if up else 1
    # lever: tapered brass bar from the pivot to a ball knob
    tip = (40, 100 + s * 78)
    p.poly([(33, 100), (47, 100), (44, tip[1] - s * 8), (36, tip[1] - s * 8)], BRASS, INK, 2.5)
    p.line([(37, 100 + s * 6), (38, tip[1] - s * 12)], BRASS_HI, 2)
    p.ell(tip[0] + 2, tip[1] + 3, 15, 15, (12, 20, 28, 140), None)
    p.ell(tip[0], tip[1], 15, 15, BRASS_HI, INK, 2.5)
    p.ell(tip[0] - 5, tip[1] - 5, 4.5, 4.5, (240, 222, 172), None)
    # pivot nut
    hexa = [polar((40, 100), 17, 30 + 60 * k) for k in range(6)]
    p.poly(hexa, BRASS, INK, 2.5)
    p.ell(40, 100, 8, 8, BRASS_HI, INK, 1.8)
    return p


def paint_seal_cut(rng):
    p = Pen(90, 70, rng)
    # the lead disc, a nick from the cutters, two wire ends
    p.line(bezier([(45, 20), (30, 10), (14, 6), (6, 2)], 16), INK, 3.4)
    p.line(bezier([(45, 20), (30, 10), (14, 6), (6, 2)], 16), LEAD_HI, 1.6)
    p.line(bezier([(47, 40), (58, 54), (64, 62), (74, 66)], 16), INK, 3.4)
    p.line(bezier([(47, 40), (58, 54), (64, 62), (74, 66)], 16), LEAD_HI, 1.6)
    p.ell(6, 2, 3, 3, LEAD_HI, INK, 1.2)
    p.ell(74, 66, 3, 3, LEAD_HI, INK, 1.2)
    p.ell(46, 30, 15, 15, LEAD, INK, 2.5)
    p.ell(42, 26, 5, 5, LEAD_HI, None)
    p.poly([(56, 22), (62, 30), (55, 33)], (40, 42, 46), INK, 1.4)
    return p


def paint_pump_lever(rng, up):
    p = Pen(120, 330, rng)
    # sprite top-left (1140,600); the slot runs x 1185-1215 => sprite x 45-75, y 50-300
    y = 72 if up else 262
    p.rect(40, y - 18, 80, y + 18, BRASS, INK, 2.5, r=5)
    p.line([(46, y - 10), (74, y - 10)], BRASS_HI, 2)
    p.rect(14, y - 7, 106, y + 7, BRASS, INK, 2.5, r=6)
    p.ell(14, y, 13, 13, BRASS_HI, INK, 2.5)
    p.ell(106, y, 13, 13, BRASS_HI, INK, 2.5)
    p.ell(102, y - 4, 4, 4, (240, 222, 172), None)
    p.ell(10, y - 4, 4, 4, (240, 222, 172), None)
    return p


def paint_preview_key(rng, down):
    p = Pen(120, 110, rng)
    d = 10 if down else 0
    if not down:
        p.rect(22, 30, 98, 96, (12, 20, 28, 160), None, r=8)
    p.rect(20, 18 + d, 100, 90 + d * 0.4, BRASS if not down else BRASS_LO, INK, 3, r=8)
    p.rect(28, 24 + d, 92, 82 + d * 0.4, None, BRASS_HI if not down else BRASS, 1.8, r=6)
    p.rect(42, 46 + d, 78, 62 + d, ENAMEL if not down else mix(ENAMEL, BRASS_LO, 0.4), INK, 1.6, r=2)
    return p


def paint_preview_lamp(rng):
    im = Image.new("RGBA", (60, 60))
    px = []
    for j in range(60):
        for i in range(60):
            r = math.hypot(i + 0.5 - 30, j + 0.5 - 30) / 30.0
            k = max(0.0, 1 - r) ** 1.6
            core = 1.0 if r < 0.28 else 0.0
            a = min(1.0, k * 0.9 + core * 0.4)
            px.append((min(255, int(220 + 35 * core)), min(255, int(150 + 80 * core)), int(60 + 120 * core),
                       int(255 * a)))
    im.putdata(px)
    return im


# ----------------------------------------------------------------------------- close-up: tags

TAG_W, TAG_H, TAG_HOLE = 600, 340, (300, 34)


def tag_outline(ox, oy, ang=0.0, pivot=None, scale=1.0):
    r = 34 * scale
    pts = rotated_rect(ox + TAG_W * scale / 2, oy, TAG_W * scale, TAG_H * scale, 0, r=r, n=8)
    if pivot is not None:
        pts = [rot(q, pivot, ang) for q in pts]
    return pts


def paint_c_tags(rng):
    p = Pen(W, H, rng)
    # sea-glass belt-guard panel: one big riveted iron plate
    p.rect(-4, -4, W + 4, H + 4, mix(WALL, IRON, 0.18), None)
    p.rect(60, 40, W - 60, H - 40, WALL, INK, 4, r=10)
    p.rect(76, 56, W - 76, H - 56, None, WALL_HI, 2, r=8)
    for x in range(100, W - 80, 48):
        rivet(p, x, 76, 5)
        rivet(p, x, H - 76, 5)
    for y in range(124, H - 100, 48):
        rivet(p, 96, y, 5)
        rivet(p, W - 96, y, 5)
    # louvres in the guard: dark slots right and left, clear of the tag
    for k in range(7):
        y = 200 + k * 96
        for x0 in (140, 1160):
            p.rect(x0, y, x0 + 150, y + 22, IRON_LO, INK, 3, r=11)
            p.line([(x0 + 10, y + 5), (x0 + 140, y + 5)], IRON_HI, 1.6)
    lay = p.layer()
    for _ in range(20):
        lay.ell(rng.uniform(100, W - 100), rng.uniform(100, H - 100), rng.uniform(80, 200), rng.uniform(40, 100),
                WALL_DK, None)
    p.put_soft(lay, 40, 0.14)
    # the brass ring from the nail
    nx, ny = 724, 170
    rc, rr = (724, 216), 44
    # eight older tags fanned behind, hung from the ring's foot
    pivot = (724, 334)
    angs = [-15, -11, -7, -3, 3, 7, 11, 15]
    order = sorted(range(8), key=lambda i: -abs(angs[i]))
    for i in order:
        a = angs[i] + rng.uniform(-1.0, 1.0)
        pts = tag_outline(724 - TAG_W * 0.48, 300 - 8 + abs(angs[i]) * 0.6, a, pivot, 0.96)
        sh = [(x + 6, y + 8) for x, y in pts]
        p.poly(sh, mix(WALL_DK, INK, 0.5), None)
        tone = rng.uniform(0.0, 1.0)
        col = mix(mix(BRASS_LO, BRASS_DK, tone), SEAGLASS, 0.18 * (1 - tone))
        p.poly(pts, col, INK, 3)
        inner = tag_outline(724 - TAG_W * 0.48 + 10, 300 + 2 + abs(angs[i]) * 0.6, a, pivot, 0.96 - 20 / TAG_W)
        p.poly(inner, None, mix(col, BRASS_HI, 0.25), 1.6)
    # a twisted wire link from the ring's foot down into the hole of the front tag
    p.line([(724, 254), (724, 336)], INK, 7)
    p.line([(724, 254), (724, 336)], BRASS_LO, 3.5)
    for y in range(262, 334, 9):
        p.line([(720, y), (728, y + 5)], BRASS_HI, 1.4)
    # the nail, the ring through every hole
    p.ell(nx + 3, ny + 4, 13, 13, (12, 20, 28), None)
    p.ell(rc[0], rc[1], rr, rr, None, INK, 9)
    p.ell(rc[0], rc[1], rr, rr, None, BRASS, 5)
    p.arc(rc[0], rc[1], rr, rr, 200, 300, BRASS_HI, 2)
    p.ell(nx, ny, 12, 12, IRON_HI, INK, 3)
    p.ell(nx - 3, ny - 3, 3.5, 3.5, mix(IRON_HI, PAPER, 0.4), None)
    return p


def paint_tag(rng, new):
    p = Pen(TAG_W, TAG_H, rng)
    pts = rotated_rect(300, 2, 596, 336, 0, r=34, n=10)
    if new:
        base, edge, hi = (214, 182, 112), (180, 146, 80), (240, 218, 160)
    else:
        base, edge, hi = mix(BRASS, BRASS_LO, 0.35), BRASS_DK, mix(BRASS, BRASS_HI, 0.35)
    p.poly(pts, base, INK, 4)
    clip = Image.new("L", p.im.size, 0)
    ImageDraw.Draw(clip).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    if new:
        # a crisp fresh-cut bright edge and fine straight file marks
        p.poly(rotated_rect(300, 8, 584, 324, 0, r=28, n=10), None, hi, 3)
        lay = p.layer()
        for k in range(40):
            y = 20 + k * 7.6
            lay.line([(14, y), (586, y + rng.uniform(-1, 1))], hi, 1)
        p.put(lay, 0.25, clip)
        p.line([(30, 330), (570, 330)], (250, 236, 196), 2)
    else:
        # worn dark edges and broad tarnish blooms
        rim = p.layer()
        rim.poly(pts, None, edge, 26)
        p.put_soft(rim, 8, 0.85, clip)
        lay = p.layer()
        for _ in range(22):
            lay.ell(rng.uniform(30, 570), rng.uniform(30, 310), rng.uniform(14, 44), rng.uniform(8, 24),
                    mix(BRASS_DK, SEAGLASS, 0.45) if rng.random() < 0.4 else BRASS_DK, None)
        p.put_soft(lay, 6, 0.22, clip)
        lay = p.layer()
        for _ in range(26):
            x, y = rng.uniform(30, 570), rng.uniform(70, 310)
            lay.line([(x, y), (x + rng.uniform(20, 70), y + rng.uniform(-6, 6))], hi, 1.2)
        p.put(lay, 0.35, clip)
        p.poly(pts, None, INK, 4)
    # the hole, with a worn ring around it
    hx, hy = TAG_HOLE
    p.ell(hx, hy, 18, 18, None, edge if not new else hi, 4)
    p.ell(hx, hy, 12, 12, (0, 0, 0, 0), INK, 2.5)
    hole = p.layer()
    hole.ell(hx, hy, 11, 11, (255, 255, 255, 255), None)
    p.im.putalpha(ImageChops.subtract(p.im.getchannel("A"), hole.im.getchannel("A")))
    return p


# ----------------------------------------------------------------------------- registry

ASSETS = [  # name, seed index, painter, opaque, grain
    ("room", 0, lambda r: paint_room(r, "base"), True, True),
    ("room_s3", 0, lambda r: paint_room(r, "s3"), True, True),
    ("room_s4", 0, lambda r: paint_room(r, "s4"), True, True),
    ("room_sever", 0, lambda r: paint_room(r, "sever"), True, True),
    ("belt1_taut", 10, lambda r: paint_belt1(r, False), False, False),
    ("belt1_slack", 11, lambda r: paint_belt1(r, True), False, False),
    ("belt2_taut", 12, lambda r: paint_belt2(r, False), False, True),
    ("belt2_slack", 13, lambda r: paint_belt2(r, True), False, False),
    ("belt3_taut", 14, lambda r: paint_belt3(r, False), False, False),
    ("belt3_slack", 15, lambda r: paint_belt3(r, True), False, False),
    ("flywheel", 20, paint_flywheel, False, False),
    ("pulley", 21, paint_pulley, False, False),
    ("crank_disc", 22, paint_crank, False, False),
    ("diaphragm", 30, paint_diaphragm, False, False),
    ("diaphragm_hollow", 31, paint_hollow, False, False),
    ("diaphragm_sheen", 32, paint_sheen, False, False),
    ("diaphragm_slack", 33, paint_slack, False, False),
    ("diaphragm_reflect", 34, lambda r: paint_reflect(r, False), False, False),
    ("diaphragm_reflect_now", 34, lambda r: paint_reflect(r, True), False, False),
    ("dust_streaks", 40, paint_dust_streaks, False, False),
    ("dust_raked", 41, paint_dust_raked, False, False),
    ("light_mul", 50, paint_light_mul, False, False),
    ("light_add", 51, paint_light_add, False, False),
    ("c_valves", 60, paint_c_valves, True, True),
    ("c_toggle_open", 61, lambda r: paint_toggle(r, True), False, False),
    ("c_toggle_shut", 62, lambda r: paint_toggle(r, False), False, False),
    ("c_seal_cut", 63, paint_seal_cut, False, False),
    ("c_pump_up", 64, lambda r: paint_pump_lever(r, True), False, False),
    ("c_pump_down", 65, lambda r: paint_pump_lever(r, False), False, False),
    ("c_preview_up", 66, lambda r: paint_preview_key(r, False), False, False),
    ("c_preview_down", 67, lambda r: paint_preview_key(r, True), False, False),
    ("c_preview_lamp", 68, paint_preview_lamp, False, False),
    ("c_tags", 70, paint_c_tags, True, True),
    ("c_tag", 71, lambda r: paint_tag(r, False), False, True),
    ("c_tag_new", 72, lambda r: paint_tag(r, True), False, False),
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
