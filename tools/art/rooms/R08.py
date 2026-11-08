#!/usr/bin/env python3
"""R08 Machine Room painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R08/*.png:

  room, room_s3, room_s4, room_sever     stage plates (1448x1086 opaque): bands <=2, 3, 4-7 and
                                         ending A's released room in grey daylight
  belt{1,2,3}_{taut,slack}               full-frame registered belt sprites (RGBA)
  flywheel, pulley, crank_disc           rotating sprites (the view turns them)
  diaphragm, diaphragm_hollow, diaphragm_sheen, diaphragm_slack,
  diaphragm_in, diaphragm_out, diaphragm_gap, diaphragm_rim,
  diaphragm_reflect, diaphragm_reflect_now, a_surface_horizon_b6
                                         the breathing membrane and its layers (400x400, centre 200,200):
                                         fold plates the view crossfades with the breath (in: a pucker at
                                         the boss; out: a slack dome), the peak-inhale rim gap, the band 5+
                                         wet rim light (additive)
  lamp_ember                             the sconce burned down (band 6+)
  dust_lines, dust_streaks, dust_raked   floor overlays (RGBA): band 3-4 wedges, P11 drifts, band 5+ rake
  floor_front                            the pedestal and pump again, laid over the dust overlays
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

WALL = (120, 140, 131)      # riveted iron plates, a desaturated sea-glass a step below the office plaster
WALL_HI = (140, 160, 151)
WALL_DK = (97, 116, 108)
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
COLUMN = (548, 140, 144, 520)
NAMEPLATE = (554, 514, 132, 90)
NAIL = (652, 298)
BELT2 = (582, 658)          # belt 2's taut run: narrower than the column, so the plate ends and tags peek out
FLY = (860, 560)
FLY_R = 180
TOP_PULLEY = (860, 128)
PUMP_PULLEY = (1024, 884)   # left of the board: belt 1 never crosses a puzzle object
PULLEY_R = 44
PUMP = (1110, 812, 260, 120)
BOARD = (1090, 420, 300, 330)
SOCKETS = (1135, 1195, 1255, 1315)
SOCKET_Y = 560
LEVER_X = 1360
FRAME = (1090, 150, 300, 230)
FRAME_PAPER = (1100, 160, 280, 210)
INDEX_X = 1372
LAMP = (440, 140)
DADO_Y, FLOOR_Y = 640, 800
DUST_Y1 = H                 # one floor material: a dusty concrete plinth all the way down
VP = (290, 806)             # band 3's dust wedges converge here, under the ring at the wall base
BARE = (238, 236, 226)      # bright unweathered metal
BRUISE = (90, 66, 86)       # brown-violet: INDEX's later ink


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

    def wob_ell(self, cx, cy, rx, ry=None, col=INK, w=5.0, amp=0.9, n=144):
        """A hand-inked ellipse contour: the office's ~3 px line with a slight, slow wobble."""
        ry = rx if ry is None else ry
        ph = [self.rng.uniform(0, math.tau) for _ in range(3)]
        pts = []
        for i in range(n + 1):
            t = math.tau * i / n
            k = amp * (0.55 * math.sin(3 * t + ph[0]) + 0.3 * math.sin(7 * t + ph[1]) + 0.15 * math.sin(13 * t + ph[2]))
            pts.append((cx + (rx + k) * math.cos(t), cy + (ry + k) * math.sin(t)))
        self.line(pts, col, w)

    def wob_poly(self, pts, col=INK, w=5.0, amp=0.8, step=14.0):
        """A closed hand-inked contour along `pts`: subdivided, nudged along the normal."""
        ring = list(pts) + [pts[0]]
        out = []
        ph = self.rng.uniform(0, math.tau)
        acc = 0.0
        for a, b in zip(ring, ring[1:]):
            L = math.hypot(b[0] - a[0], b[1] - a[1]) or 1.0
            nx, ny = -(b[1] - a[1]) / L, (b[0] - a[0]) / L
            k = max(1, int(L / step))
            for i in range(k):
                t = i / k
                d = acc + L * t
                o = amp * (0.6 * math.sin(d / 37.0 + ph) + 0.4 * math.sin(d / 13.0 + 2 * ph))
                out.append((lerp(a[0], b[0], t) + nx * o, lerp(a[1], b[1], t) + ny * o))
            acc += L
        out.append(out[0])
        self.line(out, col, w)

    def wob_rect(self, x0, y0, x1, y1, col=INK, w=5.0, amp=0.8):
        self.wob_poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col, w, amp)

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
    # floor: one material, a dusty concrete plinth from the skirting to the bottom edge
    p.rect(-4, FLOOR_Y + 4, W + 4, H + 4, DECK, None)
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
    """The plinth under its even grey dust: cast slab joints showing through, a soft mottle,
    a darker toe where the plinth meets the screen edge. Every dust state is an overlay."""
    y0, y1 = FLOOR_Y + 4, H + 4
    p.rect(-4, y0, W + 4, y1, DUST, None)
    # slab joints: one long horizontal pour line and staggered verticals, all softened by dust
    for y in (938,):
        p.line([(-4, y), (W + 4, y)], DUST_LO, 2.4)
        p.line([(-4, y + 3), (W + 4, y + 3)], mix(DUST, DUST_HI, 0.5), 1.2)
    for x in range(150, W, 300):
        p.line([(x, y0 + 4), (x, 936)], DUST_LO, 2.2)
    for x in range(300, W, 300):
        p.line([(x, 942), (x, y1)], DUST_LO, 2.2)
    lay = p.layer()
    for _ in range(220):
        x, y = rng.uniform(-40, W + 40), rng.uniform(y0, y1)
        lay.ell(x, y, rng.uniform(20, 90), rng.uniform(3, 9), DUST_HI if rng.random() < 0.5 else DUST_LO, None)
    p.put_soft(lay, 4, 0.2)
    # a little scatter of grit, matte, never sparkling
    lay = p.layer()
    for _ in range(260):
        x, y = rng.uniform(0, W), rng.uniform(y0 + 6, y1)
        lay.ell(x, y, rng.uniform(0.8, 1.8), rng.uniform(0.6, 1.2), DUST_LO if rng.random() < 0.6 else DUST_HI, None)
    p.put(lay, 0.6)
    # the toe of the plinth: a gentle darkening toward the bottom edge, so the floor sits down
    lay = p.layer()
    lay.rect(-4, 1040, W + 4, y1, mix(DUST_LO, STORM, 0.35), None)
    p.put_soft(lay, 26, 0.45)
    p.line([(-4, y0), (W + 4, y0)], INK, 2.5)


# ----------------------------------------------------------------------------- the diaphragm ring

def ring(p, rng, stage):
    cx, cy = RING_C
    pushed = stage in ("s4", "sever")
    if pushed:
        # where the ring used to sit: a crescent of bright, never-painted metal on its lower left
        bare = p.layer()
        bare.ell(cx - 9, cy + 9, RING_R + 4, RING_R + 4, BARE, None)
        cut = p.layer()
        cut.ell(cx, cy, RING_R, RING_R, (255, 255, 255, 255), None)
        bare.im.putalpha(ImageChops.subtract(bare.im.getchannel("A"), cut.im.getchannel("A")))
        p.put(bare)
        p.wob_ell(cx - 9, cy + 9, RING_R + 4, None, mix(BARE, INK, 0.55), 2.0, 0.6)
        # paint flakes peeled off round the flange: bold flat chips, bare metal under navy-edged paint
    # drop shadow: larger once the ring stands proud of the wall
    sh = p.layer()
    if pushed:
        sh.ell(cx + 16, cy + 22, RING_R + 10, RING_R + 10, (10, 16, 22, 255), None)
        p.put_soft(sh, 14, 0.6)
    else:
        sh.ell(cx + 10, cy + 14, RING_R + 4, RING_R + 4, (10, 16, 22, 255), None)
        p.put_soft(sh, 12, 0.45)
    p.ell(cx, cy, RING_R, RING_R, IRON, None)
    p.ell(cx, cy, RING_R - 7, RING_R - 7, None, IRON_HI, 2)
    p.arc(cx, cy, RING_R - 4, RING_R - 4, 190, 290, mix(IRON_HI, WALL_HI, 0.55), 3.5)
    p.arc(cx, cy, RING_R - 4, RING_R - 4, 20, 110, IRON_LO, 3)
    p.ell(cx, cy, MEM_R + 6, MEM_R + 6, None, IRON_LO, 3)
    if pushed:
        # the flange's paint has burst off in flat flakes between the bolts: dull steel under a
        # dark edge, one curl of paint still lifting from each
        for k in range(8):
            a = 15 + k * 45 + rng.uniform(-6, 6)
            c0 = polar(RING_C, (MEM_R + 8 + RING_R) / 2 + rng.uniform(-2, 2), a)
            n = rng.randint(5, 7)
            pts = []
            for j in range(n):
                t = math.tau * j / n
                rr = rng.uniform(5, 9)
                pts.append((c0[0] + rr * 1.5 * math.cos(t + math.radians(a + 90)),
                            c0[1] + rr * 1.5 * math.sin(t + math.radians(a + 90)) * 0.7))
            p.poly(pts, mix(BARE, IRON_HI, 0.55), INK, 2)
            q = pts[0]
            p.poly([q, pts[1], polar(q, 7, a + 200)], mix(IRON_HI, WALL_HI, 0.3), INK, 1.4)
    p.wob_ell(cx, cy, RING_R, None, INK, 5.5, 1.0)
    # the recess the membrane sits in (the sprite covers it)
    p.ell(cx, cy, MEM_R, MEM_R, MEMBRANE, INK, 3.5)
    for i in range(12):
        a = i * 30
        seat = polar(RING_C, BOLT_R, a)
        hp = seat
        if pushed:
            # the witness stripe stays where it was painted, on the flange both sides of the seat
            p.line([polar(RING_C, BOLT_R - BOLT_HEAD - 3, a), polar(RING_C, BOLT_R + BOLT_HEAD + 4, a)], PAINT, 4)
            # backed out a finger's width: the head stands off its seat toward us (up-left in the
            # oblique), and a bright threaded shank shows between head and flange
            hp = (seat[0] - 7, seat[1] - 8)
            p.ell(seat[0] + 2, seat[1] + 3, 10, 10, (14, 20, 26), None)
            strap(p, [seat, hp], 17, BRASS_HI, INK, 1.8)
            p.ell(seat[0], seat[1], 8.5, 8.5, BRASS_HI, INK, 1.8)
            for t in (0.25, 0.5, 0.75):
                q = (lerp(seat[0], hp[0], t), lerp(seat[1], hp[1], t))
                p.line([polar(q, 8, -48 + 90), polar(q, 8, -48 - 90)], BRASS_LO, 1.6)
        hexa = [polar(hp, BOLT_HEAD, a + 30 + 60 * k) for k in range(6)]
        p.poly([(x + 2, y + 3) for x, y in hexa], (14, 20, 26), None)
        p.poly(hexa, IRON_HI, INK, 2.4)
        p.ell(hp[0], hp[1], 6.5, 6.5, None, IRON, 1.6)
        # one white radial paint stripe across head and flange
        inner = (BOLT_R - BOLT_HEAD - 3, BOLT_R)
        outer = (BOLT_R, BOLT_R + BOLT_HEAD + 4)
        if pushed:
            # the head's half of the stripe has moved with the head
            h0, h1 = polar(hp, -BOLT_HEAD + 1, a), polar(hp, BOLT_HEAD - 1, a)
            p.line([h0, h1], PAINT, 4)
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
    p.rect(x + 6, y, x + w - 6, y + h, IRON_HI, None)
    # a cylinder seen side-on: a lit band across its upper middle, darker toward both edges
    p.rect(x + 8, y + 6, x + w - 8, y + 14, mix(IRON_HI, WALL_HI, 0.45), None)
    p.rect(x + 8, y + h - 12, x + w - 8, y + h - 2, IRON_LO, None)
    p.wob_rect(x + 6, y, x + w - 6, y + h, INK, 3.5, 0.6)
    p.ell(x + 6, y + h / 2, 9, h / 2, IRON, INK, 3)
    p.ell(x + w - 6, y + h / 2, 9, h / 2, IRON, INK, 3)


def column(p, rng):
    x, y, w, h = COLUMN
    sh = p.layer()
    sh.rect(x + 8, y + 10, x + w + 10, y + h + 6, (10, 16, 22, 255), None)
    p.put_soft(sh, 8, 0.4)
    p.rect(x, y, x + w, y + h, IRON, None)
    p.rect(x + 8, y + 8, x + w - 8, y + h - 8, None, IRON_HI, 2)
    p.wob_rect(x, y, x + w, y + h, INK, 4.5, 0.7)
    for yy in range(y + 18, y + h - 10, 34):
        rivet(p, x + 15, yy, 2.4, IRON_HI)
        rivet(p, x + w - 15, yy, 2.4, IRON_HI)
    # the brass nameplate: plain tarnished brass, four rivets; the view engraves the words
    nx, ny, nw, nh = NAMEPLATE
    p.rect(nx + 3, ny + 4, nx + nw + 3, ny + nh + 4, (12, 18, 24), None, r=3)
    p.rect(nx, ny, nx + nw, ny + nh, mix(BRASS, BRASS_HI, 0.5), INK, 3, r=3)
    p.rect(nx + 6, ny + 6, nx + nw - 6, ny + nh - 6, None, BRASS_LO, 1.6, r=2)
    p.line([(nx + 5, ny + 3), (nx + nw - 5, ny + 3)], BRASS_HI, 1.4)
    for q in ((nx + 10, ny + 10), (nx + nw - 10, ny + 10), (nx + 10, ny + nh - 10), (nx + nw - 10, ny + nh - 10)):
        rivet(p, q[0], q[1], 3, BRASS_HI)
    # the nail and its ring of nine tarnished tags, fanned to the right: before P11 their edges
    # and the ring show past belt 2's right edge
    tx, ty = NAIL
    p.ell(tx, ty + 14, 12, 12, None, BRASS_LO, 3)
    for i in range(9):
        ang = -36 + 34 * i / 8 + rng.uniform(-1.5, 1.5)
        top = (tx, ty + 24)
        pts = rotated_rect(top[0], top[1], 22, 82, ang, r=4)
        tone = rng.uniform(0.0, 1.0)
        col = mix(mix((150, 132, 78), BRASS_DK, 0.5 * tone), SEAGLASS, 0.15 * (1 - tone))
        p.poly([(q[0] + 2, q[1] + 3) for q in pts], (12, 18, 24), None)
        p.poly(pts, col, INK, 2.2)
        edge = rotated_rect(top[0], top[1] + 3, 16, 76, ang, r=3)
        p.poly(edge, None, mix(col, BRASS_HI, 0.35), 1.2)
        hole = rot((top[0], top[1] + 8), top, ang)
        p.ell(hole[0], hole[1], 4.2, 4.2, mix(SEAGLASS_HI, SEAGLASS, 0.4), None)
        p.ell(hole[0], hole[1], 2.4, 2.4, IRON_LO, None)
    p.ell(tx, ty + 14, 12, 12, None, INK, 4.6)
    p.ell(tx, ty + 14, 12, 12, None, BRASS_HI, 2.4)
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
    p.rect(fx, fy, fx + fw, fy + fh, BRASS, None, r=3)
    p.wob_rect(fx, fy, fx + fw, fy + fh, INK, 4.5, 0.6)
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
    p.rect(x - 6, y - 6, x + w + 6, y + h + 6, BRASS_HI, None, r=7)
    p.wob_rect(x - 6, y - 6, x + w + 6, y + h + 6, INK, 5.0, 0.7)
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
    # gearbox on the bed, and the drive shaft out to the pulley stand on the left
    ax, ay = PUMP_PULLEY
    p.rect(x + 10, y + 30, x + 112, y + h - 16, IRON_HI, INK, 3, r=6)
    p.rect(ax, ay - 7, x + 12, ay + 7, IRON_HI, INK, 2.5)
    p.line([(ax + 4, ay - 3), (x + 8, ay - 3)], mix(IRON_HI, WALL_HI, 0.45), 1.4)
    # the pulley stand: a cast A-frame on its own foot
    foot_y = ay + 66
    p.poly([(ax - 40, foot_y), (ax - 24, foot_y), (ax + 6, ay + 6), (ax - 6, ay + 6)], IRON, INK, 3)
    p.poly([(ax + 24, foot_y), (ax + 40, foot_y), (ax + 6, ay + 6), (ax - 6, ay + 6)], IRON, INK, 3)
    p.rect(ax - 52, foot_y, ax + 52, foot_y + 14, IRON_HI, INK, 3)
    rivet(p, ax - 42, foot_y + 7, 2.6, IRON)
    rivet(p, ax + 42, foot_y + 7, 2.6, IRON)
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
        # slipped off the pump pulley: still round the flywheel's lower rim, the slack lying in
        # a loop on the plinth beside the pulley stand
        s1 = polar(FLY, FLY_R + 7, 22)
        s2 = polar(FLY, FLY_R + 7, 112)
        loop_c, rx, ry = (1000, 1004), 128, 10
        right = (loop_c[0] + rx, loop_c[1] - 2)
        left = (loop_c[0] - rx + 26, loop_c[1] - 6)
        lay = p.layer()
        pts = [(loop_c[0] + rx * math.cos(t * 2 * math.pi / 60), loop_c[1] + ry * math.sin(t * 2 * math.pi / 60))
               for t in range(61)]
        strap(lay, pts, 12, LEATHER_DK, INK, 2.2, hi=LEATHER)
        p.put(lay)
        wrap(p, FLY, FLY_R + 7, math.radians(22), math.radians(112))
        belt_strand_curve(p, bezier([s1, (s1[0] + 50, s1[1] + 150), (right[0] + 10, right[1] - 90), right]))
        belt_strand_curve(p, bezier([s2, (s2[0] + 10, s2[1] + 120), (left[0] - 30, left[1] - 50), left]))
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
        # gone slack: it still hangs from the top pulley, but its loop has slumped onto the
        # flywheel and lies over the top of the rim, the strands bowing out under their own weight
        cx, cy = TOP_PULLEY
        r = PULLEY_R + 7
        wrap(p, TOP_PULLEY, r, math.pi, 2 * math.pi)
        lft, rgt = (cx - r, cy), (cx + r, cy)
        rr = FLY_R + 9
        on_l, on_r = polar(FLY, rr, -128), polar(FLY, rr, -52)
        belt_strand_curve(p, bezier([lft, (cx - r - 30, 220), (on_l[0] - 26, on_l[1] - 70), on_l], 30))
        belt_strand_curve(p, bezier([rgt, (cx + r + 34, 230), (on_r[0] + 22, on_r[1] - 64), on_r], 30))
        belt_strand_curve(p, [polar(FLY, rr, a) for a in range(-128, -51, 3)])
        # the slack's spare length slumped down over the rim's left shoulder, a short fold
        fold = bezier([on_l, polar(FLY, rr + 16, -140), polar(FLY, rr + 10, -152), polar(FLY, rr - 6, -146)], 16)
        belt_strand_curve(p, fold)
    return p


def paint_belt2(rng, slack):
    p = Pen(W, H, rng)
    x0, x1 = 556, 684        # the slack fold keeps its own (approved) registration
    if not slack:
        bx0, bx1 = BELT2
        cxm = (bx0 + bx1) / 2
        t_top, t_bot = DRUM_TOP[1] - 4, DRUM_LOW[1] + DRUM_LOW[3] + 4
        sh = p.layer()
        sh.rect(bx0 + 6, t_top + 6, bx1 + 6, t_bot + 4, (10, 16, 22, 255), None)
        p.put_soft(sh, 6, 0.45)
        # the run: dark leather with a convex crown down its centre
        p.rect(bx0, t_top, bx1, t_bot, LEATHER_DK, None)
        crown = p.layer()
        crown.rect(cxm - 11, t_top, cxm + 11, t_bot, mix(LEATHER_DK, LEATHER, 0.6), None)
        p.put_soft(crown, 6, 0.9)
        crown = p.layer()
        crown.rect(cxm - 2, t_top, cxm + 2, t_bot, LEATHER_HI, None)
        p.put_soft(crown, 2, 0.6)
        for xe in (bx0 + 3, bx1 - 3):
            p.line([(xe, t_top), (xe, t_bot)], mix(LEATHER_DK, INK, 0.45), 3)
        # long wear streaks along the direction of travel
        lay = p.layer()
        for _ in range(9):
            xx = rng.uniform(bx0 + 10, bx1 - 10)
            yy = rng.uniform(t_top + 60, t_bot - 160)
            lay.line([(xx, yy), (xx + rng.uniform(-1, 1), yy + rng.uniform(60, 150))], LEATHER_HI, 1.2)
        p.put(lay, 0.3)
        # wrapped over the top drum and round the crank pulley at the bottom: where it lies on the
        # drum it takes the cylinder's light, and its ends roll away out of sight
        for (dy0, dy1, top) in ((DRUM_TOP[1], DRUM_TOP[1] + DRUM_TOP[3], True),
                                (DRUM_LOW[1], DRUM_LOW[1] + DRUM_LOW[3], False)):
            yy0, yy1 = (dy0 - 4, dy1) if top else (dy0, dy1 + 4)
            band = p.layer()
            band.rect(bx0, yy0, bx1, yy1, LEATHER, None)
            p.put(band, 1.0)
            # lit across the drum's lit band, darkening as it turns away
            p.rect(bx0 + 2, dy0 + 6, bx1 - 2, dy0 + 14, LEATHER_HI, None)
            p.rect(bx0 + 2, dy1 - 12, bx1 - 2, dy1 + (0 if top else 4), mix(LEATHER_DK, INK, 0.4), None)
            edge_y = yy0 if top else yy1
            p.line([(bx0, edge_y), (cxm, edge_y + (-3 if top else 3)), (bx1, edge_y)], INK, 3)
            p.line([(bx0, yy1 if top else yy0), (bx1, yy1 if top else yy0)], mix(LEATHER_DK, INK, 0.6), 2.2)
            p.line([(bx0, yy0), (bx0, yy1)], INK, 3)
            p.line([(bx1, yy0), (bx1, yy1)], INK, 3)
        p.line([(bx0, t_top), (bx0, t_bot)], INK, 3)
        p.line([(bx1, t_top), (bx1, t_bot)], INK, 3)
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
    p.ell(c[0], c[1], 156, 156, None, INK, 3.5)
    p.wob_ell(c[0], c[1], 180, None, INK, 5.5, 1.0)
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
    p.ell(50, 50, 34, 34, None, INK, 2.6)
    p.wob_ell(50, 50, 44, None, INK, 4.5, 0.6, 72)
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
    p.ell(200, 200, 192, 192, None, INK, 3)
    _boss(p, c)
    return p


def _boss(p, c, col=BRASS, hi=BRASS_HI):
    p.ell(c[0] + 1, c[1] + 3, 25, 25, (8, 10, 14), None)
    p.ell(c[0], c[1], 24, 24, col, INK, 2.5)
    p.ell(c[0], c[1], 15, 15, None, BRASS_LO, 2)
    p.ell(c[0] - 5, c[1] - 5, 6, 6, hi, None)
    for k in range(4):
        q = polar(c, 19, 45 + 90 * k)
        p.ell(q[0], q[1], 2.2, 2.2, BRASS_DK, None)


FOLD_HI = (58, 70, 86)      # a fold's lit ridge: the light comes from the sconce, upper right
FOLD_LO = (5, 7, 11)         # its crease


def paint_ribs(rng, mode):
    """The membrane's surface as flat fold plates the view crossfades with the breath.

    "in": full inhale. The skin is drawn into the ring: its ribs converge and tighten into a
    dark pucker of short hard folds round the boss (the sever sack's fold language, pulled taut).
    "out": exhale. The ribs relax and bow outward in long slack curves, a broad dull dome."""
    p = Pen(400, 400, rng)
    c = (200, 200)
    clip = circle_mask((400, 400), c, 189)
    lay = p.layer()
    n = 16
    if mode == "in":
        # drawn in: the skin pulled taut toward the boss. Long straight tension lines run in from
        # the rim and bunch into a dark star of hard gathers round the boss (the sever sack's
        # folds, pulled tight from the middle)
        well = p.layer()
        well.ell(200, 200, 84, 84, (0, 0, 0, 255), None)
        lay.put_soft(well, 12, 0.85)
        for k in range(n):
            a0 = k * 360 / n + rng.uniform(-5, 5)
            r_out = rng.uniform(150, 186)
            pts = [polar(c, r, a0) for r in (r_out, 100, 34)]
            lay.line(pts, FOLD_LO, 2.6)
            lay.line([polar(q, 2.4, a0 + 90) for q in pts], mix(FOLD_HI, MEMBRANE, 0.25), 1.4)
        # the star: fat, short, lit gathers, each a wedge from the boss out to r ~ 70-100
        for k in range(14):
            a0 = k * 360 / 14 + rng.uniform(-5, 5)
            r1 = rng.uniform(64, 98)
            tip = polar(c, r1, a0)
            b0, b1 = polar(c, 27, a0 - 12), polar(c, 27, a0 + 12)
            lay.poly([b0, tip, b1], FOLD_HI, None)
            lay.line([b1, tip], mix(FOLD_HI, PAPER, 0.2), 1.6)
            lay.line([b0, tip], FOLD_LO, 3)
    else:
        # let go: a slack dome. A broad dull highlight where it bulges at the light, and the
        # skin's weight sagging into three soft catenaries across its lower half
        dome = p.layer()
        dome.ell(232, 166, 132, 112, (44, 56, 70, 255), None)
        lay.put_soft(dome, 34, 0.9)
        for f in range(3):
            y = 262 + f * 30
            sag = 12 + f * 5
            pts = bezier([(14, y - 18), (200, y + sag), (386, y - 18)], 40)
            lay.line(pts, FOLD_LO, 3.2)
            lay.line(offset_line(pts, 3.2), mix(FOLD_HI, MEMBRANE, 0.15), 2)
    p.put(lay, 1.0, clip)
    # leave the brass boss clear: the view lays these over the base sprite's boss
    boss = p.layer()
    boss.ell(200, 200, 25.5, 25.5, (255, 255, 255, 255), None)
    p.im.putalpha(ImageChops.subtract(p.im.getchannel("A"), boss.im.getchannel("A")))
    return p


def paint_gap(rng):
    """Peak inhale: the membrane pulls off the ring on the side away from the light and a thin
    bright crescent of the wall-light behind opens between them."""
    p = Pen(400, 400, rng)
    lay = p.layer()
    lay.ell(200, 200, 192, 192, rgba(mix(PAPER_HI, SEAGLASS_HI, 0.35)), None)
    cut = p.layer()
    cut.ell(205, 195, 187, 187, (255, 255, 255, 255), None)
    lay.im.putalpha(ImageChops.subtract(lay.im.getchannel("A"), cut.im.getchannel("A")))
    fade = Image.new("L", lay.im.size, 0)
    ImageDraw.Draw(fade).pieslice((0, 0, 400 * SS, 400 * SS), 75, 215, fill=255)
    fade = fade.filter(ImageFilter.GaussianBlur(18 * SS))
    lay.im.putalpha(ImageChops.multiply(lay.im.getchannel("A"), fade))
    p.put(lay)
    # the membrane's own lip, inked, standing off the ring
    p.arc(205, 195, 187, 187, 95, 195, INK, 2.4)
    return p


def paint_rim(rng):
    """Band 5+: a cold wet rim light round the membrane's edge (drawn additively)."""
    im = Image.new("RGBA", (400, 400))
    px = []
    col = (70, 128, 112)
    for j in range(400):
        for i in range(400):
            dx, dy = i + 0.5 - 200, j + 0.5 - 200
            r = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            ring_k = math.exp(-((r - 184) / 5.5) ** 2) if r < 192 else math.exp(-((r - 184) / 2.2) ** 2)
            # wettest along the upper left and lower right, a cold glint not a halo
            lobe = 0.55 + 0.45 * abs(math.cos(ang - math.radians(-135)))
            k = ring_k * lobe
            px.append((col[0], col[1], col[2], int(min(255, 255 * k))))
    im.putdata(px)
    return im


def paint_lamp_ember(rng):
    """Band 6+: the sconce burned down to a dull ember (laid over the plate's lit glass)."""
    p = Pen(80, 80, rng)
    x, y = 40, 40
    p.ell(x, y, 18, 22, (92, 52, 34), INK, 2)
    p.ell(x + 2, y + 5, 9, 11, (150, 76, 40), None)
    for dx in (-9, 0, 9):
        hgt = 22 * math.sqrt(max(0, 1 - (dx / 18) ** 2))
        p.line([(x + dx, y - hgt), (x + dx, y + hgt)], INK, 2.4)
    p.line([(x - 18, y), (x + 18, y)], INK, 2.4)
    p.ell(x, y, 24, 28, None, INK, 3)
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


REFLECT_BAND = (210, 112, 18, 196)   # belt 2 in the reflection (sprite px): the view's ghost stripes


def dome(q, k=0.16):
    """Bend a sprite point as the membrane's dome would: pulled in toward the rim."""
    dx, dy = q[0] - 200, q[1] - 200
    f = 1 - k * (dx * dx + dy * dy) / (186.0 * 186.0)
    return (200 + dx * f, 200 + dy * f)


def _bent(pts, step=6.0):
    out = []
    ring = list(pts)
    for a, b in zip(ring, ring[1:]):
        n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / step))
        for i in range(n):
            out.append(dome((lerp(a[0], b[0], i / n), lerp(a[1], b[1], i / n))))
    out.append(dome(ring[-1]))
    return out


def _bent_rect(x0, y0, x1, y1):
    return _bent([(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)])


def _bent_circle(cx, cy, r, n=72):
    return [dome((cx + r * math.cos(math.tau * i / n), cy + r * math.sin(math.tau * i / n))) for i in range(n)]


def paint_reflect(rng, slack):
    """The room caught in the membrane: flat pale sea-glass shapes in the right half of the disc,
    facing the real flywheel and board, bent by the dome. The view lays it at ~50 %.

    `slack` False (band 7, late): belt 2 still taut in the reflection, though the real one hangs.
    `slack` True (continue): the same image, caught up: every belt slack."""
    p = Pen(400, 400, rng)
    lay = p.layer()
    col = rgba(mix(SEAGLASS_HI, PAPER_HI, 0.35))
    dim = rgba(mix(SEAGLASS_HI, MEMBRANE, 0.35))
    dark = rgba(MEMBRANE)
    # the wall's dado line and the floor edge, as two faint bands
    lay.poly(_bent_rect(150, 300, 400, 306), dim, None)
    lay.poly(_bent_rect(150, 344, 400, 350), dim, None)
    # the valve board, and the drawing frame above it
    lay.poly(_bent_rect(318, 124, 368, 166), col, None)
    lay.poly(_bent_rect(323, 129, 363, 161), dark, None)
    lay.line(_bent([(328, 152), (342, 152), (342, 138), (356, 138)], 3), col, 2)
    lay.poly(_bent_rect(314, 176, 372, 252), col, None)
    for k in range(4):
        q = dome((326 + k * 12, 202))
        lay.ell(q[0], q[1], 4, 4, dark, None)
        lay.line([q, dome((326 + k * 12, 192 if k != 3 else 212))], dark, 2.4)
    q = dome((334, 232))
    lay.ell(q[0], q[1], 8, 8, dark, None)
    # the flywheel: rim, six spokes, hub; turning or not, it reads by its silhouette
    fc = (262, 250)
    rim = _bent_circle(fc[0], fc[1], 58)
    inner = _bent_circle(fc[0], fc[1], 49)
    lay.poly(rim, col, None)
    lay.poly(inner, dark, None)
    for k in range(6):
        a = k * 60 + 10
        a0, a1 = polar(fc, 10, a), polar(fc, 50, a)
        lay.poly([dome(polar(a0, 4, a + 90)), dome(polar(a1, 2.6, a + 90)), dome(polar(a1, 2.6, a - 90)),
                  dome(polar(a0, 4, a - 90))], col, None)
    h = dome(fc)
    lay.ell(h[0], h[1], 11, 11, col, None)
    lay.ell(h[0], h[1], 4, 4, dark, None)
    lay.poly(_bent([(238, 300), (262, 252), (286, 300)]), col, None)
    # the top pulley above it
    tp = (262, 150)
    lay.poly(_bent_circle(tp[0], tp[1], 14), col, None)
    lay.poly(_bent_circle(tp[0], tp[1], 8), dark, None)
    bx, by, bw, bh = REFLECT_BAND
    if not slack:
        # belts 1 and 3 taut: straight strands
        for a, b in (((222, 236), (254, 156)), ((302, 236), (270, 156)), ((310, 262), (352, 302)),
                     ((276, 306), (346, 312))):
            lay.line(_bent([a, b], 4), col, 5)
        # belt 2 taut, running, wrapped top and bottom
        lay.poly(_bent_rect(bx, by, bx + bw, by + bh), col, None)
        lay.poly(_bent_rect(bx + 4, by + 4, bx + bw - 4, by + bh - 4), rgba(mix(col[:3], MEMBRANE, 0.25)), None)
    else:
        # caught up: belt 3 slumped over the rim's top, belt 1 lying in a loop, belt 2 a folded fall
        lay.line(_bent([(250, 150)] + [polar(fc, 62, a) for a in range(-128, -51, 6)] + [(274, 150)], 4), col, 5)
        lay.line(_bent(bezier([polar(fc, 62, 30), (330, 330), (300, 336), (262, 330)], 16), 4), col, 5)
        fold = [(bx, by), (bx + bw, by + 18), (bx, by + 40), (bx + bw, by + 62), (bx, by + 86), (bx + bw, by + 104),
                (bx + 2, by + 124)]
        lay.line(_bent(fold, 4), col, 7)
        q = dome((bx + 6, by + 136))
        lay.ell(q[0], q[1], 14, 9, col, None)
    # the sconce, a warm point
    lp = dome((236, 92))
    glow = p.layer()
    glow.ell(lp[0], lp[1], 12, 12, rgba(PAPER_HI), None)
    lay.put_soft(glow, 4, 0.8)
    lay.ell(lp[0], lp[1], 5, 5, rgba(PAPER_HI), None)
    p.put(lay, 1.0, circle_mask((400, 400), (200, 200), 186))
    return p


HORIZON_Y, HORIZON_SAG = 214, 26   # the far horizon in the membrane (sprite px): its crest, its fall at the rim
HORIZON_POINTS = 9


def horizon_y(x):
    """The far horizon's curve: a shallow arc, highest at the disc's centre line."""
    u = (x - 200) / 186.0
    return HORIZON_Y + HORIZON_SAG * u * u


def paint_surface_horizon(rng):
    """Band 6+: what the membrane holds instead of the room. Stark flat shapes only: one far
    horizon curve in storm navy, the far water under it a flat storm-navy field (translucent, so
    the breath's folds still read through it), and nine evenly spaced pale points along it.
    Masked inside the membrane, so the bolts stay in front. The view lays it at full opacity."""
    p = Pen(400, 400, rng)
    lay = p.layer()
    xs = [14 + 372 * i / 96 for i in range(97)]
    curve = [(x, horizon_y(x)) for x in xs]
    lay.poly(curve + [(386, 400), (14, 400)], rgba(STORM, 190), None)
    lay.line(curve, rgba(STORM_HI), 4.0)
    x0, x1 = 64, 336
    for i in range(HORIZON_POINTS):
        x = x0 + (x1 - x0) * i / (HORIZON_POINTS - 1)
        lay.ell(x, horizon_y(x) - 1, 5.2, 5.2, rgba(PAPER, 204), None)
    p.put(lay, 1.0, circle_mask((400, 400), (200, 200), 184))
    return p


# ----------------------------------------------------------------------------- dust overlays

def floor_mask():
    return rect_mask((W, H), [(-4, FLOOR_Y + 5, W + 4, H + 4)])


def paint_floor_front(rng):
    """What stands on the plinth (the flywheel pedestal, the pump and its pulley stand), painted
    again as one sprite the view lays over the dust overlays, so dust lies behind their feet."""
    p = Pen(W, H, rng)
    pedestal(p)
    pump(p)
    return p


def paint_dust_lines(rng):
    """Band 3-4: the dust swept into stark wedges that all point at the diaphragm. Each is fat at
    its far end and tapers to a vanishing point on the wall base under the ring; the plinth
    between them is swept clean and shows darker."""
    p = Pen(W, H, rng)
    clean = p.layer()
    clean.rect(-4, FLOOR_Y + 5, W + 4, H + 4, mix(DECK, INK, 0.12), None)
    p.put(clean, 0.55)
    ends = [(-300, 1060), (-60, 1066), (150, 1070), (380, 1066), (620, 1050), (860, 1010), (1080, 960),
            (1260, 912), (1400, 868), (1440, 834)]
    wedges = p.layer()
    for i, (ex, ey) in enumerate(ends):
        dx, dy = ex - VP[0], ey - VP[1]
        L = math.hypot(dx, dy)
        nx, ny = -dy / L, dx / L
        half = 16 + 0.035 * L + rng.uniform(-3, 4)
        tip = (VP[0] + dx * 0.03, VP[1] + dy * 0.03)
        # a drift: fat and rounded at the far end, drawn out to a point toward the ring
        wedges.poly([tip, (ex + nx * half, ey + ny * half), (ex - nx * half, ey - ny * half)],
                    rgba(mix(DUST, DUST_HI, 0.5)), None)
        wedges.ell(ex, ey, half, half * 0.8, rgba(mix(DUST, DUST_HI, 0.5)), None)
    p.put_soft(wedges, 1.2, 1.0)
    # a darker lip along each wedge's lower side, so the heaps read as heaps, not paint
    lips = p.layer()
    for i, (ex, ey) in enumerate(ends):
        dx, dy = ex - VP[0], ey - VP[1]
        L = math.hypot(dx, dy)
        nx, ny = -dy / L, dx / L
        half = 16 + 0.035 * L
        s_ = 1 if ny > 0 else -1
        lips.line([(VP[0] + dx * 0.06, VP[1] + dy * 0.06), (ex + s_ * nx * half * 0.9, ey + s_ * ny * half * 0.9)],
                  rgba(DUST_LO), 3)
    p.put_soft(lips, 1.0, 0.7)
    out = p.done()
    out.putalpha(ImageChops.multiply(out.getchannel("A"), floor_mask().resize((W, H), Image.LANCZOS)))
    return out


def paint_dust_streaks(rng):
    """After P11: one inhalation dragged the dust sideways into broad matte drifts toward the
    ring, fat where it piled up; the plinth it was pulled from lies dark and clean."""
    p = Pen(W, H, rng)
    clean = p.layer()
    clean.ell(980, 880, 300, 64, mix(DECK, INK, 0.15), None)
    p.put_soft(clean, 24, 0.75)
    drifts = p.layer()
    under = p.layer()
    for i in range(16):
        y = 818 + (944 - 818) * (i + 0.5) / 16 + rng.uniform(-3, 3)
        xs = rng.uniform(900, 1140)
        xe = rng.uniform(300, 470)
        wmax = rng.uniform(8, 14)
        n = 40
        top, bot = [], []
        for k in range(n + 1):
            t = k / n
            x = lerp(xs, xe, t)
            yy = y + 4 * math.sin(t * math.pi) * (1 if i % 2 else -1)
            wd = wmax * (0.25 + 0.75 * t ** 0.7)
            top.append((x, yy - wd / 2))
            bot.append((x, yy + wd / 2))
        drifts.poly(top + bot[::-1], rgba(mix(DUST, DUST_HI, 0.45)), None)
        drifts.ell(xe, y, wmax * 0.9, wmax * 0.6, rgba(mix(DUST, DUST_HI, 0.45)), None)
        under.line([(q[0], q[1] + 1.5) for q in bot], rgba(DUST_LO), 2.4)
    p.put_soft(under, 0.8, 0.8)
    p.put_soft(drifts, 1.0, 1.0)
    out = p.done()
    out.putalpha(ImageChops.multiply(out.getchannel("A"), floor_mask().resize((W, H), Image.LANCZOS)))
    return out


RAKE_FROM, RAKE_TO = (930, 1046), (468, 812)   # clear of the exit buttons


def rake_profile(t):
    """The breath as a profile along the rake (0..1): two short peaks, a pause, one long."""
    for t0, t1 in ((0.02, 0.17), (0.2, 0.35), (0.46, 0.96)):
        if t0 <= t <= t1:
            return math.sin(math.pi * (t - t0) / (t1 - t0)) ** 2
    return 0.0


def paint_dust_raked(rng):
    """Band 5+: Nora's breath raked into the dust: five tines of dark furrow, each with a pale
    ridge thrown up on one side, running from the floor's centre to the base of the ring wall."""
    p = Pen(W, H, rng)
    (x0, y0), (x1, y1) = RAKE_FROM, RAKE_TO
    L = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    nx, ny = -uy, ux
    amp = 40.0
    path = []
    for i in range(241):
        t = i / 240
        d = amp * rake_profile(t)
        path.append((x0 + ux * L * t + nx * d * -1, y0 + uy * L * t + ny * d * -1))
    # the scraped bed: the rake bit through the dust to the darker plinth
    bed = p.layer()
    strap(bed, path, 40, rgba(mix(DECK, INK, 0.2)), None, 0)
    p.put_soft(bed, 2.0, 0.85)
    for off in (-14, -7, 0, 7, 14):
        pts = offset_line(path, off)
        p.line(offset_line(pts, -2.6), rgba(mix(DUST_HI, PAPER_HI, 0.3)), 2.4)    # ridge, toward the light
        p.line(pts, rgba(mix(DUST_LO, INK, 0.55)), 3.4)                            # furrow
    # the dust shoved aside along both edges of the bed
    for side in (-1, 1):
        p.line(offset_line(path, side * 22), rgba(mix(DUST, DUST_HI, 0.6)), 5)
    out = p.done()
    out.putalpha(ImageChops.multiply(out.getchannel("A"), floor_mask().resize((W, H), Image.LANCZOS)))
    return out


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
    """The sconce's warm pool: a tight core at the lamp and a broad wash thrown across the ring's
    upper-right quadrant and the column. Kept off the membrane, so the black skin stays the
    darkest, largest shape on screen. (The view dims it to an ember from band 6.)"""
    im = Image.new("RGBA", (LW, LH))
    px = []
    for j in range(LH):
        for i in range(LW):
            x, y = (i + 0.5) * 4, (j + 0.5) * 4
            k = _gauss(x, y, LAMP[0], LAMP[1], 50, 50) * 0.95 + _gauss(x, y, 470, 300, 250, 190) * 0.85
            d = math.hypot(x - RING_C[0], y - RING_C[1])
            if d < MEM_R + 4:
                k *= 0.08 + 0.92 * max(0.0, (d - MEM_R + 30) / 34) ** 2 if d > MEM_R - 30 else 0.08
            px.append((int(min(255, 86 * k)), int(min(255, 58 * k)), int(min(255, 22 * k)), 255))
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
    grime(p, rng)
    return p


OIL = (10, 14, 18)
OIL_HI = (92, 104, 110)


def grime(p, rng):
    """The board is used: oil weeping from every toggle boss, a black thumb-worn patch where the
    PUMP handle is taken, and old grime gathered along the brass frame's lower lip."""
    for cx in C_SOCKETS:
        lay = p.layer()
        for k in range(rng.randint(2, 3)):
            x = cx + rng.uniform(-18, 18)
            y0 = C_SOCKET_Y + 24 + abs(x - cx) * 0.3
            L = rng.uniform(26, 64)
            w = rng.uniform(3.5, 6)
            lay.line([(x, y0), (x + rng.uniform(-1.5, 1.5), y0 + L)], rgba(OIL), w)
            lay.ell(x, y0 + L, w * 0.8, w * 1.05, rgba(OIL), None)
        lay.ell(cx + 2, C_SOCKET_Y + 6, 36, 34, rgba(OIL), None)
        p.put_soft(lay, 1.0, 0.55)
        hi = p.layer()
        for k in range(2):
            x = cx + rng.uniform(-14, 14)
            hi.line([(x - 1.5, C_SOCKET_Y + 34), (x - 1.5, C_SOCKET_Y + 34 + rng.uniform(10, 26))], rgba(OIL_HI), 1.4)
        p.put(hi, 0.6)
    # a dark worn patch beside the PUMP slot, where the hand braces
    lay = p.layer()
    lay.ell(1240, 700, 16, 22, rgba(OIL), None)
    lay.ell(1158, 690, 14, 20, rgba(OIL), None)
    p.put_soft(lay, 6, 0.4)
    # grime along the board's bottom rail
    lay = p.layer()
    lay.rect(176, 940, 1272, 966, rgba(OIL), None)
    p.put_soft(lay, 8, 0.35)


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


SEAL_AT = (880, 800)    # c_seal_cut's top-left relative to a socket at 875 (the view now hangs it off the first socket, 305: (310, 800))


def paint_seal_cut(rng):
    """INDEX's lead seal, cut: a grey lead disc dangling from a snipped twist of wire, the
    cutters' bright bite on both ends. The room's first tactile clue: big enough to see."""
    p = Pen(110, 130, rng)
    lug = (30, 8)           # the socket ring's lug (close-up 910, 808)
    disc = (52, 78)
    # the lug
    p.ell(lug[0], lug[1], 7, 7, BRASS, INK, 2)
    p.ell(lug[0], lug[1], 3, 3, GLASS_DK, None)
    # the twisted wire down to the seal
    wire = bezier([lug, (22, 30), (44, 46), (disc[0] - 4, disc[1] - 18)], 24)
    p.line(wire, INK, 4)
    p.line(wire, LEAD_HI, 2)
    for t in range(3, len(wire) - 2, 3):
        q = wire[t]
        p.line([(q[0] - 2.5, q[1] - 1), (q[0] + 2.5, q[1] + 1)], INK, 1.2)
    # the snipped end: a short stub kinked away from the disc, its cut bright
    stub = bezier([(disc[0] + 8, disc[1] - 16), (78, 50), (92, 44)], 12)
    p.line(stub, INK, 4)
    p.line(stub, LEAD_HI, 2)
    p.ell(92, 44, 3.4, 3.4, (236, 236, 228), INK, 1.4)
    # the lead disc, pressed: a raised rim and a crushed face with the die's ring in it
    p.ell(disc[0] + 2, disc[1] + 3, 14, 14, (12, 20, 28), None)
    p.ell(disc[0], disc[1], 14, 14, LEAD, INK, 2.5)
    p.ell(disc[0], disc[1], 9, 9, None, mix(LEAD, INK, 0.35), 1.6)
    p.arc(disc[0], disc[1], 12, 12, 200, 300, LEAD_HI, 2)
    p.ell(disc[0] - 4, disc[1] - 4, 2.6, 2.6, (200, 204, 206), None)
    p.poly([(disc[0] + 9, disc[1] - 6), (disc[0] + 15, disc[1] - 1), (disc[0] + 10, disc[1] + 3)], (40, 42, 46), INK, 1.2)
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
    # a grease thumb-smudge on the grip: a dull oval with the ghost of a whorl
    lay = p.layer()
    lay.ell(64, y - 1, 11, 8, rgba((40, 34, 24)), None)
    p.put_soft(lay, 1.6, 0.55)
    for k in range(3):
        p.arc(65, y, 8 - k * 2.4, 5.5 - k * 1.6, 200, 340, rgba((60, 50, 34, 150)), 1)
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
    """In close on the column behind the dropped belt: its dark iron face, the riveted edge of
    the frame on the right with the wall beyond, and the slack belt's folds entering from the
    left. The ring of tags hangs on its nail in the middle."""
    p = Pen(W, H, rng)
    # the wall beyond the column's right edge
    p.rect(-4, -4, W + 4, H + 4, WALL, None)
    for y in range(40, H, 52):
        rivet(p, 1400, y, 5)
    # the column face: dark iron, a raised inner border, rivets down both margins
    p.rect(-4, -4, 1340, H + 4, IRON, None)
    p.line([(1340, -4), (1340, H + 4)], INK, 6)
    p.rect(250, -10, 1300, H + 10, None, IRON_HI, 3)
    p.line([(1306, -4), (1306, H + 4)], mix(IRON_HI, WALL_HI, 0.4), 2)
    for y in range(36, H, 64):
        rivet(p, 1318, y, 5.5, IRON_HI)
    lay = p.layer()
    for _ in range(26):
        lay.ell(rng.uniform(260, 1300), rng.uniform(0, H), rng.uniform(60, 180), rng.uniform(30, 90),
                IRON_HI if rng.random() < 0.5 else IRON_LO, None)
    p.put_soft(lay, 40, 0.35)
    # oil and rust weep from the nail down the iron
    lay = p.layer()
    lay.line([(724, 186), (726, 620)], (60, 44, 30, 255), 10)
    p.put_soft(lay, 8, 0.35)
    # the slack belt entering from the left: the dropped strap folded on itself in flat panels,
    # each fold's crease a dark diagonal, the far edge stepping in and out as it zig-zags
    ys = [-20, 96, 178, 300, 384, 508, 590, 716, 800, 924, 1010, 1110]
    for i in range(len(ys) - 1):
        ya, yb = ys[i], ys[i + 1]
        out_a = 176 if i % 2 == 0 else 156
        out_b = 156 if i % 2 == 0 else 176
        col = LEATHER if i % 2 == 0 else LEATHER_DK
        pts = [(-10, ya + 14), (out_a, ya), (out_b, yb), (-10, yb + 14)]
        p.poly([(x + 10, y + 12) for x, y in pts], (10, 14, 18), None)
        p.poly(pts, col, INK, 4)
        if i % 2 == 0:
            p.line([(-10, ya + 26), (out_a - 10, ya + 12)], LEATHER_HI, 3)
        else:
            p.line([(-10, yb + 4), (out_b - 8, yb - 10)], mix(LEATHER_DK, INK, 0.5), 4)
    # its lacing: one old splice, a row of rawhide X-stitches across the strap
    for k in range(4):
        x0 = 10 + k * 38
        for y0 in (430, 446):
            p.line([(x0, y0), (x0 + 38, y0 + 12)], (184, 160, 116), 3)
            p.line([(x0, y0 + 12), (x0 + 38, y0)], (184, 160, 116), 3)
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
        col = mix(mix(OLIVE_BRASS, BRASS_DK, 0.5 * tone), SEAGLASS, 0.12 * (1 - tone))
        p.poly(pts, col, INK, 3)
        inner = tag_outline(724 - TAG_W * 0.48 + 10, 300 + 2 + abs(angs[i]) * 0.6, a, pivot, 0.96 - 20 / TAG_W)
        p.poly(inner, None, mix(col, BRASS_HI, 0.35), 1.8)
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


OLIVE_BRASS = (170, 156, 98)     # tarnished brass: brown-olive, light enough for INK at >= 4.5:1
VERDIGRIS = (104, 150, 128)


def paint_tag(rng, new):
    p = Pen(TAG_W, TAG_H, rng)
    pts = rotated_rect(300, 2, 596, 336, 0, r=34, n=10)
    clip = Image.new("L", p.im.size, 0)
    ImageDraw.Draw(clip).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    hx, hy = TAG_HOLE
    if new:
        # fresh brass: a warm face with a cross-grain of file marks, a bright machined chamfer
        base = (206, 172, 104)
        p.poly(pts, base, None)
        lay = p.layer()
        for k in range(44):
            y = 14 + k * 7.2
            lay.line([(14, y), (586, y + rng.uniform(-1, 1))], (232, 206, 146), 1)
        p.put(lay, 0.35, clip)
        sheen = p.layer()
        sheen.poly([(120, 0), (260, 0), (160, TAG_H), (20, TAG_H)], (246, 230, 186), None)
        p.put_soft(sheen, 30, 0.35, clip)
        # the chamfer: a bright machined band inside a crisp dark edge
        p.poly(rotated_rect(300, 7, 586, 326, 0, r=29, n=10), None, (250, 238, 204), 7)
        p.poly(rotated_rect(300, 12, 576, 316, 0, r=25, n=10), None, mix(base, BRASS_LO, 0.5), 1.6)
        p.poly(pts, None, INK, 4)
        p.ell(hx, hy, 19, 19, None, (250, 238, 204), 5)
        p.ell(hx, hy, 23, 23, None, mix(base, BRASS_LO, 0.5), 1.4)
    else:
        # tarnished brass: brown-olive, a darker oxidised edge, verdigris blooming at the hole,
        # a few bright rubs where fingers turned it; a stamped border still shows
        p.poly(pts, OLIVE_BRASS, None)
        rim = p.layer()
        rim.poly(pts, None, mix(BRASS_DK, (60, 56, 30), 0.5), 30)
        p.put_soft(rim, 9, 0.9, clip)
        lay = p.layer()
        for _ in range(18):
            lay.ell(rng.uniform(40, 560), rng.uniform(40, 300), rng.uniform(16, 46), rng.uniform(8, 22),
                    mix(BRASS_DK, (90, 84, 44), 0.5), None)
        p.put_soft(lay, 7, 0.2, clip)
        verd = p.layer()
        verd.ell(hx, hy + 6, 58, 40, VERDIGRIS, None)
        for _ in range(6):
            verd.ell(hx + rng.uniform(-70, 70), hy + rng.uniform(0, 44), rng.uniform(8, 18), rng.uniform(6, 12), VERDIGRIS, None)
        verd.ell(18, 306, 18, 18, VERDIGRIS, None)
        p.put_soft(verd, 9, 0.6, clip)
        rub = p.layer()
        rub.ell(300, 190, 230, 70, (206, 186, 120), None)
        p.put_soft(rub, 40, 0.3, clip)
        # metal, not card: a dull diagonal sheen across the face and fine brushing along it
        sheen = p.layer()
        sheen.poly([(150, 0), (250, 0), (150, TAG_H), (50, TAG_H)], (214, 200, 140), None)
        p.put_soft(sheen, 26, 0.35, clip)
        lay = p.layer()
        for k in range(30):
            y = 20 + k * 10
            lay.line([(20, y), (580, y + rng.uniform(-1.5, 1.5))], (196, 182, 120), 1)
        p.put(lay, 0.18, clip)
        # a metal tag's bevel: light along the top edge, dark along the bottom
        p.line([(40, 6), (560, 6)], (214, 196, 136), 2.4)
        p.line([(40, 330), (560, 330)], mix(BRASS_DK, INK, 0.4), 2.4)
        p.poly(rotated_rect(300, 16, 568, 308, 0, r=24, n=10), None, mix(OLIVE_BRASS, BRASS_DK, 0.45), 1.6)
        p.poly(pts, None, INK, 4)
        p.ell(hx, hy, 18, 18, None, mix(VERDIGRIS, BRASS_DK, 0.3), 4)
    # the punched hole
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
    ("diaphragm_in", 35, lambda r: paint_ribs(r, "in"), False, False),
    ("diaphragm_out", 36, lambda r: paint_ribs(r, "out"), False, False),
    ("diaphragm_gap", 37, paint_gap, False, False),
    ("diaphragm_rim", 38, paint_rim, False, False),
    ("lamp_ember", 39, paint_lamp_ember, False, False),
    ("dust_lines", 42, paint_dust_lines, False, False),
    ("floor_front", 43, paint_floor_front, False, False),
    ("dust_streaks", 40, paint_dust_streaks, False, False),
    ("dust_raked", 41, paint_dust_raked, False, False),
    ("a_surface_horizon_b6", 44, paint_surface_horizon, False, False),
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
