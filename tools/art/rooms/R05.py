#!/usr/bin/env python3
"""R05 Kitchen and Mess painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R05/*.png:

  view_a, view_a_b2, view_a_b4, view_a_b6, view_a_b7, view_a_sever
                                         mess plates (1448x1086 opaque): bands 0-1, 2-3, 4-5, 6, 7
                                         and the sever ending's grey daylight
  view_b, view_b_b2, view_b_b4, view_b_b6, view_b_b7, view_b_sever
                                         kitchen plates (opaque), same band split
  c_table, c_ledger, c_board             close-up plates (opaque): c_table and c_ledger are
                                         straight-down plans, c_board a flat elevation
  a_*, b_*, c_*                          sprites and overlays (RGBA, transparent)

Flat front elevation, approved palette, navy ink contours, matte colour and a low seeded paper
grain. No text, numerals or letters anywhere: every label, initial, numeral and document line is a
blank field the view writes. The only graphic marks are the square repair patch, the seal cuts
|, ||, ||| and rivets.

Registration (R05_view.gd draws on these; hotspots never move between stage plates):
  view A  places x_i = 330 + 112*(i-1), i = 1..9; bowls bottom-centre at (x_i, 590); hem patches
          Rect(x_i-44, 618, 88, 60); tally housing Rect(176,608,88,88), numeral window
          Rect(196,630,48,40); window glass Rect(560,110,340,190) (rain sprites drawn there);
          trolley top shelf y 660 (stack rims 20 px pitch upward from it).
  view B  as the task card: nails (95,306)/(95,506), lectern book Rect(700,520,200,80), shift board
          x960-1300 y140-520 (header y150-190, eight strips y 200+34k..228+34k at x976-1196,
          PRESENT tile Rect(1206,432,60,34), amendment slot y480-515), drawer Rect(990,600,290,110),
          hatch x1316-1436 y560-880 (label strip y580-610).
  c_table plan bowls (104x104 sprite) centre on BOWL_PLAN[k]: mats 1-8 at (x_k+48, 258) with
          x_k = 130 + 136*(k-1); place 9 at (1282, 340). Rack recesses (162+112k, 715) r46.

Python 3 + PIL only. Deterministic: each asset has its own random.Random(SEED + k), there is no
clock and no PIL noise effect, so a rerun is byte-identical.

    python3 tools/art/rooms/R05.py              # paint everything
    python3 tools/art/rooms/R05.py view_a* c_*  # paint some (fnmatch patterns)
"""
import fnmatch
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "rooms", "R05")
W, H = 1448, 1086
SS = 2                      # supersampling for every painted shape
SEED = 1931_05_00

# ----------------------------------------------------------------------------- palette
INK = (23, 43, 54)          # #172B36 contours
PAPER = (216, 206, 181)     # #D8CEB5
PAPER_HI = (232, 225, 207)  # #E8E1CF linen
PAPER_LO = (196, 186, 160)
LINEN_SH = (204, 197, 178)
ENAMEL = (236, 232, 220)
SEAGLASS = (97, 125, 116)   # #617D74
SEAGLASS_HI = (150, 178, 166)  # #96B2A6
SEAGLASS_DK = (78, 104, 97)
TIMBER = (103, 93, 81)      # #675D51
TIMBER_DK = (78, 70, 61)    # #4E463D
TIMBER_HI = (126, 115, 100)
TIMBER_XD = (58, 52, 46)
FLOOR = (112, 98, 82)       # restrained brown
FLOOR_DK = (88, 76, 64)
FLOOR_HI = (130, 116, 98)
SOOT = (41, 41, 41)         # #292929 range iron
SOOT_HI = (64, 66, 68)
BRASS = (156, 126, 70)      # #9C7E46
BRASS_HI = (201, 168, 105)  # #C9A869
BRASS_LO = (116, 92, 50)    # #745C32
STORM = (34, 56, 74)        # #22384A
STORM_HI = (52, 80, 100)
STORM_LO = (24, 40, 54)
AMBER = (195, 153, 89)      # #C39959 band-7 range glow and the continue ring only
VIOLET = (116, 101, 119)    # #746577 only paired with shape
STEEL = (178, 186, 182)
STEEL_DK = (128, 138, 136)
NAVY_BROWN = (48, 46, 48)   # table legs
SOUP = (118, 104, 82)
BEAD = (236, 244, 240)
FOG = (200, 216, 208)
DARK = (16, 24, 30)
GRAPHITE = (92, 96, 100)

PLACE_X = [330 + 112 * i for i in range(9)]          # x_1..x_9
MAT_X = [130 + 136 * i for i in range(8)]
BOWL_PLAN = [(x + 48, 258) for x in MAT_X] + [(1282, 340)]


# ----------------------------------------------------------------------------- helpers

def rng_for(k):
    return random.Random(SEED + k)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c0, c1, t):
    return tuple(int(round(lerp(a, b, t))) for a, b in zip(c0, c1))


def rgba(c, a=255):
    return c if len(c) == 4 else (c[0], c[1], c[2], a)


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

    def iw(self, w, key=(0.0, 0.0)):
        # slight width variation keyed to position, so stage plates stay identical under swaps
        j = ((int(key[0] * 7) * 7919 + int(key[1] * 7) * 104729) % 61) / 100.0 - 0.3
        return max(1, int(round((w + j) * SS)))

    def _p(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def poly(self, pts, fill=None, ink=INK, w=2.6):
        p = self._p(pts)
        if fill is not None:
            self.d.polygon(p, fill=rgba(fill))
        if ink is not None and w:
            self.d.line(p + [p[0]], fill=rgba(ink), width=self.iw(w, pts[0]), joint="curve")

    def rect(self, x0, y0, x1, y1, fill=None, ink=INK, w=2.6, r=0):
        box = (x0 * SS, y0 * SS, x1 * SS, y1 * SS)
        width = self.iw(w, (x0, y0)) if (ink is not None and w) else 0
        self.d.rounded_rectangle(box, radius=r * SS, fill=rgba(fill) if fill is not None else None,
                                 outline=rgba(ink) if width else None, width=width)

    def ell(self, cx, cy, rx, ry=None, fill=None, ink=INK, w=2.6):
        ry = rx if ry is None else ry
        box = ((cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS)
        width = self.iw(w, (cx, cy)) if (ink is not None and w) else 0
        self.d.ellipse(box, fill=rgba(fill) if fill is not None else None,
                       outline=rgba(ink) if width else None, width=width)

    def line(self, pts, col=INK, w=2.6):
        self.d.line(self._p(pts), fill=rgba(col), width=self.iw(w, pts[0]), joint="curve")

    def arc(self, cx, cy, rx, ry, a0, a1, col=INK, w=2.6):
        box = ((cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS)
        self.d.arc(box, a0, a1, fill=rgba(col), width=self.iw(w, (cx, cy)))

    def layer(self):
        return Pen(self.w, self.h, self.rng)

    def put(self, other, opacity=1.0, mask=None):
        src = other.im
        if opacity < 1.0 or mask is not None:
            src = src.copy()
            a = src.getchannel("A")
            if opacity < 1.0:
                a = a.point(lambda v: int(v * opacity))
            if mask is not None:
                a = ImageChops.multiply(a, mask)
            src.putalpha(a)
        self.im.alpha_composite(src)

    def put_soft(self, other, radius, opacity=1.0, mask=None):
        other.im = other.im.filter(ImageFilter.GaussianBlur(radius * SS))
        self.put(other, opacity, mask)

    def alpha(self):
        return self.im.getchannel("A")

    def done(self):
        return self.im.resize((self.w, self.h), Image.LANCZOS)


def bezier(p0, p1, p2, n=28):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return out


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
        clear = a.point(lambda v: 255 if v == 0 else 0)
        im.paste((0, 0, 0, 0), mask=clear)
    path = os.path.join(OUT, name + ".png")
    im.save(path, optimize=False, compress_level=9)
    print("  wrote", os.path.relpath(path, ROOT), im.size, im.mode)


# ----------------------------------------------------------------------------- shared marks

def wavy(rng, x0, x1, y, amp, step=10, tongues=0, tongue_len=40):
    """A tide-mark edge: smooth summed sines plus a few hanging tongues (positive = down)."""
    ph = [rng.uniform(0, 6.3) for _ in range(3)]
    tg = [(rng.uniform(x0 + 20, x1 - 20), rng.uniform(0.45, 1.0) * tongue_len, rng.uniform(26, 58))
          for _ in range(tongues)]
    pts = []
    x = x0
    while x <= x1 + 0.1:
        v = (math.sin(x / 37 + ph[0]) * 0.5 + math.sin(x / 13 + ph[1]) * 0.3
             + math.sin(x / 71 + ph[2]) * 0.6) * amp
        for tx, tl, tw in tg:
            v += tl * math.exp(-((x - tx) / tw) ** 2)
        pts.append((x, y + v))
        x += step
    return pts


def stain(p, rng, x0, x1, edge_y, far_y, amp, body, op, tongues=0, tongue_len=40, edge=None):
    """A flat damp stain between a straight far side and a wavy tide-mark edge."""
    sign = 1 if far_y < edge_y else -1
    edge_pts = wavy(rng, x0, x1, edge_y, amp, tongues=tongues, tongue_len=tongue_len * sign)
    # ends inside the frame round off into the wall instead of stopping on a hard vertical
    span = max(1.0, x1 - x0)
    taper = min(span * 0.3, 120.0)
    out = []
    for x, y in edge_pts:
        e = 1.0
        if x0 > 0:
            e = min(e, (x - x0) / taper)
        if x1 < W:
            e = min(e, (x1 - x) / taper)
        e = math.sin(max(0.0, min(1.0, e)) * math.pi / 2) ** 0.7
        out.append((x, far_y + (y - far_y) * e))
    edge_pts = out
    lay = p.layer()
    lay.poly(edge_pts + [(x1, far_y), (x0, far_y)], body, None)
    p.put(lay, op)
    ln = p.layer()
    ln.line(edge_pts, edge or mix(body, INK, 0.4), 2.2)
    salt = [(x, y + 4 * sign) for x, y in edge_pts]
    ln.line(salt, PAPER_HI, 1.2)
    p.put(ln, min(1.0, op + 0.25))


def chain_h(p, x0, x1, y, col=INK, pitch=8.0, w=1.5):
    x = x0 + pitch / 2
    while x < x1 - pitch / 2 + 0.1:
        p.ell(x, y, pitch * 0.58, 2.4, None, col, w)
        x += pitch


def chain_v(p, x, y0, y1, col=INK, pitch=8.0, w=1.5):
    y = y0 + pitch / 2
    while y < y1 - pitch / 2 + 0.1:
        p.ell(x, y, 2.4, pitch * 0.58, None, col, w)
        y += pitch


def chain_rect(p, x0, y0, x1, y1, col=INK, pitch=8.0, w=1.5):
    chain_h(p, x0, x1, y0, col, pitch, w)
    chain_h(p, x0, x1, y1, col, pitch, w)
    chain_v(p, x0, y0 + 4, y1 - 4, col, pitch, w)
    chain_v(p, x1, y0 + 4, y1 - 4, col, pitch, w)


def rivet(p, x, y, r=3.2, col=BRASS_HI):
    p.ell(x, y, r, r, col, INK, 1.4)


def brass_plate(p, x0, y0, x1, y1, fill=BRASS, r=6, rivets=True, w=2.6):
    p.rect(x0, y0, x1, y1, fill, INK, w, r=r)
    p.line([(x0 + 5, y0 + 4), (x1 - 5, y0 + 4)], BRASS_HI, 2)
    p.line([(x0 + 5, y1 - 4), (x1 - 5, y1 - 4)], BRASS_LO, 2)
    if rivets:
        for x, y in ((x0 + 9, y0 + 9), (x1 - 9, y0 + 9), (x0 + 9, y1 - 9), (x1 - 9, y1 - 9)):
            rivet(p, x, y)


def blank_field(p, x0, y0, x1, y1, fill=ENAMEL, r=3, w=2.2):
    """A blank enamel label plate: the view writes on it."""
    p.rect(x0, y0, x1, y1, fill, INK, w, r=r)
    p.line([(x0 + 4, y1 - 3), (x1 - 4, y1 - 3)], mix(fill, INK, 0.18), 1.4)


def recess(p, x0, y0, x1, y1, r=4, fill=DARK):
    p.rect(x0, y0, x1, y1, fill, INK, 2.4, r=r)
    p.line([(x0 + 3, y0 + 4), (x1 - 3, y0 + 4)], mix(fill, (0, 0, 0), 0.4), 3)
    p.line([(x0 + 4, y1 - 2), (x1 - 4, y1 - 2)], mix(fill, PAPER, 0.25), 1.4)


def soft_shadow(p, cx, cy, rx, ry, op=0.35, blur=6):
    lay = p.layer()
    lay.ell(cx, cy, rx, ry, INK, None)
    p.put_soft(lay, blur, op)


def planks_v(p, rng, x0, x1, y0, y1, fill, seam, hi, pitch=48):
    p.rect(x0, y0, x1, y1, fill, None)
    x = x0
    while x < x1:
        p.line([(x, y0), (x, y1)], seam, 2.4)
        p.line([(x + 3, y0), (x + 3, y1)], hi, 1.2)
        for _ in range(2):  # a few knots and grain flecks, sparse
            if rng.random() < 0.35:
                yy = rng.uniform(y0 + 10, y1 - 10)
                p.line([(x + 14, yy), (x + 14, yy + rng.uniform(16, 40))], mix(fill, seam, 0.45), 1.2)
        x += pitch


def floorboards(p, rng, y0):
    p.rect(-4, y0, W + 4, H + 4, FLOOR, INK, 3)
    y, k = y0, 0
    while y < H:
        hgt = 38 + k * 7
        p.line([(-4, y + hgt), (W + 4, y + hgt)], FLOOR_DK, 2.4)
        x = rng.uniform(0, 300)
        while x < W:
            p.line([(x, y + 3), (x, y + hgt - 3)], FLOOR_DK, 2)
            x += rng.uniform(320, 520)
        p.line([(-4, y + 3), (W + 4, y + 3)], FLOOR_HI, 1.2)
        y += hgt
        k += 1


def tint(im, col, t, mask=None):
    """Blend toward a multiplied colour cast (the room getting colder) - optionally masked."""
    if t <= 0:
        return im
    im = im.convert("RGB")
    cast = ImageChops.multiply(im, Image.new("RGB", im.size, col))
    out = Image.blend(im, cast, t)
    if mask is not None:
        out = Image.composite(out, im, mask)
    return out


def greyday(im, t=0.45, lift=0.06):
    im = im.convert("RGB")
    g = im.convert("L").convert("RGB")
    g = ImageChops.multiply(g, Image.new("RGB", im.size, (244, 246, 246)))
    out = Image.blend(im, g, t)
    return Image.blend(out, Image.new("RGB", im.size, (226, 228, 226)), lift)


def rect_mask(size, rects, inside=255, outside=0, blur=0):
    m = Image.new("L", size, outside)
    d = ImageDraw.Draw(m)
    for r in rects:
        d.rectangle(r, fill=inside)
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    return m


# ----------------------------------------------------------------------------- props (shared)

def bowl_side(p, ox, oy, band=True, square=False):
    """Enamel bowl in side elevation inside a 96x64 box at (ox, oy); bottom-centre (ox+48, oy+64)."""
    def body_pts():
        right = bezier((ox + 93, oy + 16), (ox + 90, oy + 50), (ox + 66, oy + 55), 16)
        left = bezier((ox + 30, oy + 55), (ox + 6, oy + 50), (ox + 3, oy + 16), 16)
        return right + left
    pts = body_pts()
    # foot ring
    p.rect(ox + 30, oy + 52, ox + 66, oy + 62, PAPER_LO, INK, 2.2, r=2)
    p.poly(pts, ENAMEL, None)
    # flat shade band down the right side
    m = p.layer()
    m.poly(pts, (255, 255, 255), None)
    sh = p.layer()
    sh.poly([(ox + 64, oy + 14), (ox + 98, oy + 14), (ox + 98, oy + 64), (ox + 58, oy + 64)],
            mix(ENAMEL, SEAGLASS, 0.35), None)
    if band:
        sh.rect(ox, oy + 18, ox + 96, oy + 31, STORM, None)
        sh.line([(ox, oy + 31), (ox + 96, oy + 31)], INK, 1.6)
    p.put(sh, 1.0, mask=m.alpha())
    p.poly(pts, None, INK, 2.6)
    # rim lip
    p.rect(ox + 1, oy + 11, ox + 95, oy + 18, ENAMEL, INK, 2.4, r=3)
    p.line([(ox + 6, oy + 13.5), (ox + 60, oy + 13.5)], (250, 250, 246), 1.4)
    # two enamel chips on the lip
    p.ell(ox + 74, oy + 15, 2.2, 1.6, INK, None)
    p.ell(ox + 20, oy + 16, 1.6, 1.2, INK, None)
    if square:
        sx, sy = ox + 50, oy + 26
        p.rect(sx, sy, sx + 20, sy + 20, BRASS, INK, 2.2)
        p.line([(sx + 3, sy + 3), (sx + 17, sy + 3)], BRASS_HI, 1.4)
        for x, y in ((sx + 4, sy + 4), (sx + 16, sy + 4), (sx + 4, sy + 16), (sx + 16, sy + 16)):
            p.ell(x, y, 1.9, 1.9, BRASS_HI, INK, 1.1)


def spoon_side(p, x0, y_rest, length=54, col=STEEL_DK):
    """Side-on spoon lying flat: handle at left, bowl dome at the right; rests on y_rest."""
    x1 = x0 + length
    hx = x1 - 18
    p.poly([(x0, y_rest - 4.5), (x0 + 6, y_rest - 6), (hx, y_rest - 3), (hx, y_rest - 0.5),
            (x0 + 6, y_rest - 2.5), (x0, y_rest - 1.5)], col, INK, 1.6)
    p.poly(bezier((hx - 1, y_rest), (hx + 8, y_rest - 12), (x1, y_rest), 10), col, INK, 2)
    p.line([(x0 + 8, y_rest - 4.6), (hx - 4, y_rest - 2.6)], STEEL, 1.2)
    p.line([(hx + 4, y_rest - 6), (hx + 10, y_rest - 8)], (232, 236, 232), 1.4)


def mug(p, x, y):
    """Plain enamel mug hung by its handle from a peg at (x, y)."""
    p.arc(x + 9, y + 12, 10, 12, 90, 300, INK, 7)
    p.arc(x + 9, y + 12, 10, 12, 90, 300, ENAMEL, 3)
    p.rect(x + 9, y + 4, x + 43, y + 42, ENAMEL, INK, 2.6, r=2)
    p.rect(x + 9, y + 4, x + 43, y + 10, STORM, INK, 1.8)
    p.rect(x + 33, y + 10, x + 43, y + 42, mix(ENAMEL, SEAGLASS, 0.35), None)
    p.rect(x + 9, y + 4, x + 43, y + 42, None, INK, 2.6, r=2)
    p.line([(x + 10, y + 37), (x + 42, y + 37)], STORM, 1.8)


def peg(p, x, y):
    p.rect(x - 4, y - 5, x + 4, y + 5, TIMBER_DK, INK, 1.6, r=2)
    p.ell(x + 6, y, 5, 5, TIMBER_HI, INK, 1.8)


# ----------------------------------------------------------------------------- view A: the mess

GLASS = (576, 126, 884, 292)
MULL_X, MULL_Y = 730, 209


def paint_window(p, rng, stage):
    gx0, gy0, gx1, gy1 = GLASS
    lay = p.layer()
    if stage == "sever":
        lay.rect(gx0, gy0, gx1, gy1, (178, 184, 184), None)
        lay.rect(gx0, 226, gx1, 252, (196, 200, 198), None)
        lay.rect(gx0, 256, gx1, gy1, (128, 138, 140), None)
        lay.line([(gx0, 256), (gx1, 256)], (106, 116, 120), 2)
        for k in range(10):
            x = rng.uniform(gx0 + 10, gx1 - 40)
            y = rng.uniform(264, 288)
            lay.line([(x, y), (x + rng.uniform(14, 30), y)], (150, 158, 160), 1.6)
    elif stage in (0, 2):
        sky = (98, 118, 128)
        lay.rect(gx0, gy0, gx1, gy1, sky, None)
        lay.rect(gx0, gy0, gx1, 160, mix(sky, STORM, 0.35), None)
        for (yb, h, col) in ((196, 20, (138, 152, 156)), (228, 16, (122, 138, 144))):
            pts = [(gx0, yb + h)]
            x = gx0
            while x <= gx1:
                pts.append((x, yb + rng.uniform(-4, 3)))
                x += rng.uniform(24, 40)
            pts += [(gx1, yb), (gx1, yb + h)]
            lay.poly(pts, col, None)
        lay.rect(gx0, 262, gx1, gy1, STORM_HI, None)
        lay.line([(gx0, 262), (gx1, 262)], STORM, 2)
        for k in range(14):
            x = rng.uniform(gx0 + 6, gx1 - 30)
            y = rng.uniform(268, 290)
            lay.line([(x, y), (x + rng.uniform(10, 24), y - 1)], (84, 110, 124), 1.6)
    elif stage == 4:
        sky = (76, 94, 106)
        lay.rect(gx0, gy0, gx1, gy1, sky, None)
        lay.rect(gx0, 196, gx1, 212, (98, 112, 120), None)
        # the horizon pressed flat and too close: one hard flat sea band
        lay.rect(gx0, 230, gx1, gy1, STORM, None)
        lay.line([(gx0, 230), (gx1, 230)], DARK, 3)
    elif stage == 6:
        lay.rect(gx0, gy0, gx1, gy1, (44, 64, 80), None)
        lay.line([(gx0, 214), (gx1, 214)], (50, 72, 88), 1.4)
    elif stage == 7:
        # a dark near-flat surface pressed right against the panes, one slow pale arc across it
        lay.rect(gx0, gy0, gx1, gy1, (18, 28, 36), None)
        lay.rect(gx0, gy0, gx1, gy1, None, (12, 18, 24), 6)
        lay.arc(742, 372, 230, 190, 222, 318, (150, 176, 168), 4)
        lay.arc(742, 372, 230, 190, 226, 314, (88, 112, 112), 1.4)
    p.put(lay)
    if stage != 7:
        gl = p.layer()  # two dry glints: glass, not paint
        for (x, y) in ((600, 140), (752, 228)):
            gl.line([(x, y + 26), (x + 26, y)], (226, 232, 228), 3)
            gl.line([(x + 10, y + 26), (x + 26, y + 10)], (226, 232, 228), 1.6)
        p.put(gl, 0.35)


def paint_view_a(rng, stage=0):
    p = Pen(W, H, rng, SEAGLASS_HI)
    srng = rng_for(700)     # stage-only marks draw from their own stream: the base never shifts
    sever = stage == "sever"
    # wall: sea-glass tongue-and-groove from the ceiling to the dado
    planks_v(p, rng, -4, W + 4, -4, 470, SEAGLASS_HI, mix(SEAGLASS, INK, 0.25), (176, 198, 188))
    p.rect(-4, -4, W + 4, 16, SEAGLASS, INK, 2.4)                 # ceiling batten
    # high window
    p.rect(548, 98, 912, 110, SEAGLASS, INK, 2.6)                 # head trim
    p.rect(560, 110, 900, 300, STORM, INK, 3)                     # frame
    paint_window(p, rng_for(701), stage)
    p.rect(*GLASS, None, INK, 3)
    p.rect(MULL_X - 5, GLASS[1], MULL_X + 5, GLASS[3], STORM, INK, 2.2)
    p.rect(GLASS[0], MULL_Y - 5, GLASS[2], MULL_Y + 5, STORM, INK, 2.2)
    p.line([(566, 116), (894, 116)], STORM_HI, 1.6)
    p.rect(544, 296, 916, 312, SEAGLASS, INK, 2.6)               # sill
    p.line([(548, 299), (912, 299)], (176, 198, 188), 1.6)
    p.rect(556, 312, 904, 318, mix(SEAGLASS, INK, 0.3), None)
    # damp (bands 2+): under the sill and along the dado
    if stage in (2, 4, 6, 7):
        sill_len = {2: 46, 4: 76, 6: 104, 7: 112}[stage]
        stain(p, srng, 566, 894, 318 + sill_len * 0.4, 318, 6, mix(SEAGLASS, STORM, 0.35), 0.55,
              tongues=4, tongue_len=sill_len)
        dado_up = {2: 22, 4: 34, 6: 48, 7: 52}[stage]
        stain(p, srng, -4, W + 4, 470 - dado_up, 470, 5, mix(SEAGLASS, STORM, 0.35), 0.45,
              tongues=6, tongue_len=-dado_up * 0.8)
    # mug rail: nine pegs, the ninth bare
    p.rect(270, 398, 1286, 414, TIMBER, INK, 2.4)
    p.line([(274, 401), (1282, 401)], TIMBER_HI, 1.4)
    for i, x in enumerate(PLACE_X):
        if i == 8:
            ghost = p.layer()   # the paler unfaded shape where a ninth mug hung for years
            ghost.rect(x + 9, 414, x + 43, 452, (184, 206, 196), None, r=2)
            ghost.arc(x + 9, 422, 10, 12, 90, 300, (184, 206, 196), 7)
            p.put(ghost, 0.8)
            peg(p, x, 410)
            continue
        mug(p, x, 410)
        peg(p, x, 410)
    # dado rail, brass-edged
    p.rect(-4, 468, W + 4, 488, TIMBER, INK, 2.6)
    p.line([(-4, 471), (W + 4, 471)], BRASS_HI, 2.2)
    p.line([(-4, 485), (W + 4, 485)], BRASS, 2.2)
    # damp timber panelling
    p.rect(-4, 488, W + 4, 880, TIMBER, None)
    x = -4
    while x < W:
        p.rect(x + 12, 508, x + 168, 846, mix(TIMBER, TIMBER_DK, 0.35), INK, 2.2, r=2)
        p.line([(x + 16, 512), (x + 164, 512)], TIMBER_HI, 1.4)
        p.line([(x + 16, 512), (x + 16, 842)], TIMBER_HI, 1.4)
        x += 180
    p.rect(-4, 852, W + 4, 882, TIMBER_DK, INK, 2.6)              # skirting
    floorboards(p, rng, 880)
    if stage in (4, 6, 7):
        up = {4: 120, 6: 150, 7: 160}[stage]
        stain(p, srng, -4, W + 4, 880 - up, 880, 10, TIMBER_XD, 0.5, tongues=7, tongue_len=-40)
    if stage in (6, 7):
        # the tide-line: one dark hard line across the panelling at y 760
        tl = p.layer()
        pts = wavy(srng, -4, W + 4, 760, 2.2, step=14)
        tl.poly(pts + [(W + 4, 880), (-4, 880)], TIMBER_XD, None)
        p.put(tl, 0.35)
        p.line(pts, mix(INK, TIMBER_XD, 0.3), 4.2)
        p.line([(x, y - 5) for x, y in pts], (176, 170, 150), 1.6)
    # kitchen doorway at the right edge
    p.rect(1340, 120, W + 4, 880, TIMBER_DK, INK, 3)
    p.rect(1374, 150, W + 4, 880, (30, 34, 38), INK, 2.6)
    p.rect(1374, 760, W + 4, 880, (40, 42, 44), None)             # the kitchen floor beyond
    p.line([(1374, 760), (W + 4, 760)], (52, 54, 54), 2)
    p.rect(1336, 112, W + 4, 150, TIMBER, INK, 2.6)              # lintel
    p.line([(1346, 160), (1346, 876)], TIMBER_HI, 1.6)
    p.line([(1366, 160), (1366, 876)], TIMBER_XD, 1.6)
    if stage == 7:
        warm = p.layer()   # the range seen from the next room: a faint warm stripe
        warm.rect(1384, 300, 1430, 880, mix((30, 34, 38), AMBER, 0.55), None)
        warm.rect(1366, 300, 1374, 880, mix(TIMBER_DK, AMBER, 0.5), None)
        p.put_soft(warm, 7, 0.55)
        w2 = p.layer()
        w2.poly([(1374, 880), (W + 4, 880), (W + 4, 940), (1300, 940)], mix(FLOOR, AMBER, 0.35), None)
        p.put_soft(w2, 10, 0.5)
    # bowl trolley at far left: two timber shelves
    p.rect(26, 470, 40, 872, TIMBER_DK, INK, 2.4)
    p.rect(144, 470, 158, 872, TIMBER_DK, INK, 2.4)
    p.rect(22, 464, 162, 476, TIMBER, INK, 2.4)
    p.rect(20, 660, 164, 676, TIMBER, INK, 2.6)                  # top shelf: the stack sits on y 660
    p.line([(24, 663), (160, 663)], TIMBER_HI, 1.4)
    p.rect(20, 816, 164, 832, TIMBER, INK, 2.6)
    p.line([(24, 819), (160, 819)], TIMBER_HI, 1.4)
    for x in (33, 151):
        p.ell(x, 876, 7, 7, SOOT, INK, 2)
        p.ell(x, 876, 2.4, 2.4, BRASS, None)
    # bench back behind places 1-8
    p.rect(270, 520, 1172, 600, TIMBER_DK, INK, 2.6)
    p.rect(266, 516, 1176, 532, TIMBER, INK, 2.6)
    p.line([(270, 519), (1172, 519)], TIMBER_HI, 1.4)
    for x in range(300, 1160, 56):
        p.line([(x, 534), (x, 600)], TIMBER_XD, 2.2)
    # floor shadow under the table
    soft_shadow(p, 750, 886, 620, 14, 0.4, 6)
    # legs
    for x in (190, 760, 1310):
        p.rect(x - 14, 696, x + 14, 880, NAVY_BROWN, INK, 2.6)
        p.line([(x - 8, 700), (x - 8, 874)], (70, 66, 66), 1.4)
    # the cloth: tabletop edge at y 590, drop to y 700
    p.rect(160, 586, 1340, 700, PAPER_HI, INK, 2.8, r=2)
    p.line([(164, 589.5), (1336, 589.5)], (244, 240, 228), 1.6)
    for fx in (300, 520, 760, 980, 1200):   # soft fold lines in the drop
        p.line([(fx + rng.uniform(-8, 8), 600), (fx + rng.uniform(-8, 8), 696)], LINEN_SH, 2)
    chain_h(p, 168, 1332, 690)
    chain_h(p, 168, 1332, 597, mix(INK, SEAGLASS, 0.3), 9, 1.2)
    for x in PLACE_X:
        p.rect(x - 44, 618, x + 44, 678, (240, 235, 220), None)
        chain_rect(p, x - 44, 618, x + 44, 678)
    # spoons laid side-on on the tabletop for places 1-8; place 9 only a dent
    for i, x in enumerate(PLACE_X):
        if i < 8:
            spoon_side(p, x + 30, 590, 54)
        else:
            dent = p.layer()
            dent.poly([(1256, 586), (1290, 587.5), (1292, 588), (1300, 584), (1310, 588),
                       (1300, 593), (1290, 591), (1256, 590)], LINEN_SH, None)
            p.put(dent)
            p.line([(1256, 590.5), (1290, 591.5), (1300, 593.5), (1310, 588.5)], mix(LINEN_SH, INK, 0.35), 1.4)
            p.line([(1258, 586), (1290, 587), (1300, 583.5), (1308, 586.5)], (250, 248, 240), 1.2)
    # tally housing on the left drop
    p.ell(220, 652, 44, 44, BRASS, INK, 2.8)
    p.ell(220, 652, 38, 38, None, BRASS_LO, 2)
    for k in range(13):     # 13 tick notches (0-12), no numerals
        a = math.radians(-90 + k * 360 / 13)
        p.line([(220 + 40 * math.cos(a), 652 + 40 * math.sin(a)),
                (220 + 34 * math.cos(a), 652 + 34 * math.sin(a))], INK, 1.6)
    p.arc(220, 652, 41, 41, 200, 260, BRASS_HI, 2)
    blank_field(p, 196, 630, 244, 670)
    p.rect(256, 682, 270, 694, BRASS_HI, INK, 2, r=3)            # lever nub
    p.ell(263, 680, 4, 4, BRASS_LO, INK, 1.4)
    im = p.done()
    # stage colour: colder each band; the table and cloth stay readable
    cloth = rect_mask(im.size, [(150, 500, 1350, 710)], 0, 255, blur=10)
    if stage == 2:
        im = tint(im, (204, 218, 232), 0.25)
    elif stage == 4:
        im = tint(im, (190, 208, 228), 0.4)
    elif stage == 6:
        im = tint(im, (176, 196, 222), 0.55, cloth.point(lambda v: max(v, 110)))
    elif stage == 7:
        keep = rect_mask(im.size, [(150, 500, 1350, 710), (1336, 112, W, 960)], 0, 255, blur=10)
        im = tint(im, (164, 186, 214), 0.6, keep.point(lambda v: max(v, 70)))
    elif sever:
        im = greyday(im)
    return im


# ----------------------------------------------------------------------------- view B: the kitchen

def kettle(p, x0, y0):
    """Sea-glass enamel kettle, 110x110 box, sitting on y0+110."""
    cx = x0 + 58
    p.line([(cx - 30, y0 + 46), (cx - 26, y0 + 8), (cx + 26, y0 + 8), (cx + 30, y0 + 46)], INK, 7)
    p.line([(cx - 30, y0 + 46), (cx - 26, y0 + 8), (cx + 26, y0 + 8), (cx + 30, y0 + 46)], SOOT_HI, 3)
    body = bezier((cx - 50, y0 + 108), (cx - 52, y0 + 38), (cx, y0 + 36), 16) + \
        bezier((cx, y0 + 36), (cx + 52, y0 + 38), (cx + 50, y0 + 108), 16)
    spout = [(cx - 40, y0 + 80), (x0 - 2, y0 + 50), (x0 + 2, y0 + 46), (cx - 34, y0 + 66)]
    p.poly(spout, SEAGLASS, INK, 2.4)
    p.poly(body, SEAGLASS, INK, 2.8)
    p.poly(bezier((cx + 18, y0 + 40), (cx + 46, y0 + 44), (cx + 48, y0 + 106), 10) +
           [(cx + 30, y0 + 106)], SEAGLASS_DK, None)
    p.poly(body, None, INK, 2.8)
    p.line(bezier((cx - 36, y0 + 92), (cx - 38, y0 + 52), (cx - 10, y0 + 46), 10), SEAGLASS_HI, 3)
    p.ell(cx, y0 + 36, 22, 6, SEAGLASS, INK, 2.2)
    p.ell(cx, y0 + 28, 6, 6, SOOT, INK, 2)
    p.rect(cx - 52, y0 + 104, cx + 52, y0 + 110, SEAGLASS_DK, INK, 2)


def paint_view_b(rng, stage=0):
    p = Pen(W, H, rng, SEAGLASS_HI)
    srng = rng_for(702)     # stage-only marks draw from their own stream
    plaster = (156, 182, 170)
    p.rect(-4, -4, W + 4, 560, plaster, None)
    lay = p.layer()     # trowel sweeps, faint
    for _ in range(26):
        x, y = rng.uniform(0, W), rng.uniform(40, 540)
        lay.arc(x, y, rng.uniform(60, 140), rng.uniform(8, 16), 200, 340, (176, 198, 188), 3)
    p.put(lay, 0.45)
    p.rect(-4, -4, W + 4, 16, SEAGLASS, INK, 2.4)
    p.rect(-4, 52, W + 4, 62, SEAGLASS, INK, 2)                   # picture rail
    # damp on the plaster
    if stage in (2, 4, 6, 7):
        up = {2: 70, 4: 120, 6: 150, 7: 150}[stage]
        stain(p, srng, 1300, W + 4, 556 - up, 556, 8, mix(SEAGLASS, STORM, 0.4), 0.55, tongues=3,
              tongue_len=-up * 0.5)
        stain(p, srng, 620, 940, 60 + up * 0.5, 62, 6, mix(SEAGLASS, STORM, 0.35), 0.45, tongues=3,
              tongue_len=up * 0.6)
    if stage in (4, 6, 7):
        stain(p, srng, -4, 140, 300, 62, 7, mix(SEAGLASS, STORM, 0.35), 0.45, tongues=2, tongue_len=60)
        stain(p, srng, 600, 960, 470, 556, 6, mix(SEAGLASS, STORM, 0.35), 0.45, tongues=3, tongue_len=-50)
    if stage in (6, 7):
        stain(p, srng, -4, W + 4, 512, 556, 4, mix(SEAGLASS, STORM, 0.5), 0.6, tongues=8, tongue_len=-28)
    # dado and timber below
    p.rect(-4, 552, W + 4, 572, TIMBER, INK, 2.6)
    p.line([(-4, 555), (W + 4, 555)], BRASS_HI, 2)
    p.line([(-4, 569), (W + 4, 569)], BRASS, 2)
    planks_v(p, rng, -4, W + 4, 572, 880, TIMBER, TIMBER_XD, TIMBER_HI, 64)
    p.rect(-4, 852, W + 4, 882, TIMBER_DK, INK, 2.6)
    floorboards(p, rng, 880)
    # splashback: storm-navy glazed tiles
    p.rect(140, 160, 600, 440, STORM, INK, 3)
    for y in range(160, 440, 40):
        p.line([(140, y), (600, y)], STORM_HI, 2)
    for row, y in enumerate(range(160, 440, 40)):
        off = 0 if row % 2 == 0 else 23
        for x in range(140 + off, 600, 46):
            p.line([(x, y), (x, min(440, y + 40))], STORM_HI, 2)
            p.line([(x + 8, y + 30), (x + 18, y + 8)], (70, 98, 116), 1.6)
    p.rect(140, 160, 600, 440, None, INK, 3)
    # menu sheet on the lower nail; the upper nail bare
    for (nx, ny) in ((95, 306), (95, 506)):
        p.ell(nx, ny, 4.5, 4.5, SOOT_HI, INK, 1.8)
    sheet = [(40, 510), (150, 506), (148, 640), (42, 638)]
    soft_shadow(p, 98, 578, 52, 66, 0.25, 4)
    p.poly(sheet, PAPER, INK, 2.2)
    p.ell(95, 512, 3, 3, DARK, None)
    for k in range(9):     # typed grey dashes
        y = 528 + k * 11
        x = 52
        while x < 136:
            ln = rng.uniform(6, 16)
            p.line([(x, y), (min(138, x + ln), y)], (128, 126, 118), 1.6)
            x += ln + rng.uniform(3, 6)
    for k in range(4):     # pencil scrawl strokes
        y = rng.uniform(560, 630)
        x = rng.uniform(56, 100)
        pts = [(x + j * 4, y + math.sin(j * 1.3 + k) * 3) for j in range(9)]
        p.line(pts, GRAPHITE, 1.2)
    # range: black iron, cold
    p.rect(160, 432, 580, 446, SOOT_HI, INK, 2.6)                 # cooktop lip
    p.rect(170, 446, 570, 860, SOOT, INK, 3)
    for x in (210, 330, 450):                                     # hob plates
        p.rect(x, 434, x + 80, 440, (70, 72, 74), None)
    # oven doors and firebox
    p.rect(214, 524, 346, 656, (52, 52, 54), INK, 2.6, r=4)        # firebox door
    lit = stage == 7
    for k in range(5):
        sx = 238 + k * 19
        p.rect(sx, 564, sx + 10, 636, AMBER if lit else DARK, INK, 1.8, r=2)
    p.rect(230, 556, 330, 644, None, BRASS, 3, r=3)
    p.rect(226, 552, 334, 648, None, INK, 1.6, r=4)
    p.rect(326, 584, 340, 596, BRASS_HI, INK, 1.6, r=2)
    p.rect(372, 524, 552, 656, (52, 52, 54), INK, 2.6, r=4)        # upper oven door
    p.rect(390, 584, 534, 596, BRASS, INK, 1.8, r=3)
    p.rect(192, 676, 552, 836, (52, 52, 54), INK, 2.6, r=4)        # lower oven door
    p.rect(330, 692, 414, 704, BRASS, INK, 1.8, r=3)
    for (x, y) in ((206, 690), (538, 690), (206, 822), (538, 822)):
        rivet(p, x, y, 3, SOOT_HI)
    p.rect(176, 860, 196, 880, SOOT, INK, 2)
    p.rect(544, 860, 564, 880, SOOT, INK, 2)
    # brass rail at y 470
    p.rect(176, 462, 188, 480, SOOT_HI, INK, 1.6)
    p.rect(552, 462, 564, 480, SOOT_HI, INK, 1.6)
    p.rect(160, 466, 580, 476, BRASS, INK, 2.2, r=4)
    p.line([(166, 468.5), (574, 468.5)], BRASS_HI, 1.4)
    # shelf over the range with the kettle on it (not on the range)
    for x in (226, 534):
        p.poly([(x - 6, 414), (x + 6, 414), (x + 6, 438), (x - 6, 418)], TIMBER_DK, INK, 1.8)
    kettle(p, 258, 300)
    p.rect(200, 410, 560, 422, TIMBER, INK, 2.6)
    p.line([(204, 413), (556, 413)], TIMBER_HI, 1.4)
    # low pass door back to the mess, lower left
    p.rect(-4, 690, 132, 880, TIMBER_DK, INK, 2.6)
    p.rect(-4, 702, 118, 880, (30, 34, 38), INK, 2.4)
    p.rect(-4, 818, 118, 880, (44, 44, 44), None)
    p.line([(-4, 818), (118, 818)], (60, 60, 58), 2)
    # lectern
    p.rect(730, 862, 870, 880, TIMBER_DK, INK, 2.6, r=3)
    p.rect(760, 610, 840, 864, TIMBER, INK, 2.6)
    p.line([(766, 616), (766, 858)], TIMBER_HI, 1.6)
    if lit:
        warmface = p.layer()
        warmface.rect(760, 610, 784, 864, mix(TIMBER, AMBER, 0.55), None)
        p.put(warmface, 0.85)
        p.rect(760, 610, 840, 864, None, INK, 2.6)
    p.rect(688, 596, 912, 614, TIMBER_DK, INK, 2.6)
    # open book, front elevation
    p.rect(700, 588, 900, 600, STORM, INK, 2.2, r=2)
    lp = bezier((706, 590), (704, 530), (742, 528), 10) + bezier((742, 528), (780, 528), (800, 548), 10) + [(800, 590)]
    rp = [(800, 590), (800, 548)] + bezier((800, 548), (820, 528), (858, 528), 10) + bezier((858, 528), (896, 530), (894, 590), 10)
    p.poly(lp, PAPER_HI, INK, 2.2)
    p.poly(rp, PAPER_HI, INK, 2.2)
    for k in range(3):
        y = 560 + k * 9
        p.line([(712, y + 4), (796, y)], PAPER_LO, 1.2)
        p.line([(804, y), (888, y + 4)], PAPER_LO, 1.2)
    p.poly([(796, 546), (804, 546), (806, 640), (800, 632), (794, 640)], SEAGLASS, INK, 1.6)
    # shift board
    p.rect(960, 140, 1300, 520, TIMBER, INK, 3)
    p.rect(976, 150, 1268, 515, STORM_LO, INK, 2.2)
    p.line([(964, 144), (1296, 144)], TIMBER_HI, 1.6)
    blank_field(p, 980, 152, 1264, 190)
    for k in range(8):
        y = 200 + 34 * k
        blank_field(p, 980, y, 1196, y + 28)
        p.ell(1204, y + 14, 2.6, 2.6, BRASS_HI, INK, 1)
    blank_field(p, 1206, 432, 1264, 466, (226, 220, 200))
    recess(p, 980, 480, 1264, 512, 3, (20, 28, 34))
    for x in (1066, 1180):
        p.line([(x, 482), (x, 510)], BRASS, 2)
    p.ell(1284, 252, 10, 10, BRASS, INK, 2)                      # tiny socket
    p.line([(1279, 252), (1289, 252)], DARK, 2.4)
    p.ell(1284, 320, 8, 8, BRASS_LO, INK, 1.8)                   # selector
    p.line([(1284, 320), (1290, 308)], BRASS_HI, 2.4)
    for a in (-60, 0, 60):
        aa = math.radians(a - 90)
        p.line([(1284 + 12 * math.cos(aa), 320 + 12 * math.sin(aa)),
                (1284 + 15 * math.cos(aa), 320 + 15 * math.sin(aa))], INK, 1.4)
    # dresser with the service drawer
    p.rect(966, 596, 1294, 860, TIMBER, INK, 2.8)
    p.rect(950, 578, 1310, 596, TIMBER_DK, INK, 2.8)
    p.line([(954, 581), (1306, 581)], TIMBER_HI, 1.6)
    p.rect(990, 600, 1280, 710, mix(TIMBER, TIMBER_HI, 0.3), INK, 2.6, r=2)
    p.rect(1104, 646, 1166, 664, BRASS, INK, 2.2, r=7)
    p.line([(1110, 650), (1160, 650)], BRASS_HI, 1.4)
    p.rect(982, 724, 1126, 846, mix(TIMBER, TIMBER_DK, 0.3), INK, 2.4, r=2)
    p.rect(1134, 724, 1278, 846, mix(TIMBER, TIMBER_DK, 0.3), INK, 2.4, r=2)
    for x in (1114, 1146):
        p.ell(x, 786, 4, 4, BRASS_HI, INK, 1.4)
    p.rect(960, 846, 1300, 880, TIMBER_DK, INK, 2.6)
    # brass rod out of the dresser's left side into the wall
    p.rect(936, 646, 966, 654, BRASS, INK, 1.8, r=3)
    p.ell(938, 650, 7, 10, BRASS_LO, INK, 1.8)
    # service hatch, bolted
    p.rect(1310, 552, 1442, 880, TIMBER_DK, INK, 2.8)
    p.rect(1316, 560, 1436, 880, TIMBER, INK, 2.4)
    for x in (1346, 1376, 1406):
        p.line([(x, 616), (x, 876)], TIMBER_XD, 2)
    blank_field(p, 1330, 580, 1422, 610, (226, 220, 200))
    for y in (660, 800):
        p.rect(1358, y - 8, 1426, y + 8, SOOT_HI, INK, 2, r=2)
        p.rect(1394, y - 4, 1442, y + 4, SOOT, INK, 1.8)
        p.rect(1376, y - 18, 1384, y - 6, SOOT, INK, 1.6)
        rivet(p, 1364, y, 2.4, SOOT_HI)
    if lit:
        pool = p.layer()
        pool.ell(380, 900, 260, 40, mix(FLOOR, AMBER, 0.7), None)
        pool.ell(280, 600, 110, 90, AMBER, None)
        p.put_soft(pool, 24, 0.55)
        vg = p.layer()
        for k in range(5):
            sx = 238 + k * 19
            vg.rect(sx, 564, sx + 10, 636, (232, 196, 130), None)
        p.put_soft(vg, 3, 0.7)
    im = p.done()
    if stage == 2:
        im = tint(im, (204, 218, 232), 0.25)
    elif stage == 4:
        im = tint(im, (190, 208, 228), 0.4)
    elif stage == 6:
        dark = rect_mask(im.size, [(0, 0, W, 560)], 255, 170, blur=8)
        im = tint(im, (164, 186, 214), 0.6, dark)
    elif stage == 7:
        keep = Image.new("L", im.size, 255)
        d = ImageDraw.Draw(keep)
        d.ellipse((90, 440, 680, 1040), fill=40)
        d.rectangle((740, 600, 800, 880), fill=60)
        keep = keep.filter(ImageFilter.GaussianBlur(40))
        im = tint(im, (164, 186, 214), 0.55, keep)
    elif stage == "sever":
        im = greyday(im)
    return im


# ----------------------------------------------------------------------------- close-ups

def timber_ground(p, rng, fill=TIMBER_DK, seam=TIMBER_XD, hi=TIMBER, pitch=92, vertical=False):
    p.rect(-4, -4, p.w + 4, p.h + 4, fill, None)
    k = 0
    pos = -4
    while pos < (p.w if vertical else p.h):
        if vertical:
            p.line([(pos, -4), (pos, p.h + 4)], seam, 2.4)
            p.line([(pos + 3, -4), (pos + 3, p.h + 4)], hi, 1.2)
        else:
            p.line([(-4, pos), (p.w + 4, pos)], seam, 2.4)
            p.line([(-4, pos + 3), (p.w + 4, pos + 3)], hi, 1.2)
        for _ in range(3):
            if vertical:
                y = rng.uniform(0, p.h)
                p.line([(pos + 30, y), (pos + 30, y + rng.uniform(40, 120))], mix(fill, seam, 0.5), 1.4)
            else:
                x = rng.uniform(0, p.w)
                p.line([(x, pos + 30), (x + rng.uniform(40, 120), pos + 30)], mix(fill, seam, 0.5), 1.4)
        pos += pitch + rng.uniform(-6, 6)
        k += 1


def spoon_plan(p, cx, y0, col=STEEL):
    """Plan-view spoon in a 34x96 box centred on cx: bowl at top."""
    p.rect(cx - 4, y0 + 36, cx + 4, y0 + 86, col, INK, 1.8, r=4)
    p.ell(cx, y0 + 86, 7, 8, col, INK, 1.8)
    p.rect(cx - 3, y0 + 36, cx + 3, y0 + 84, col, None)
    p.ell(cx, y0 + 21, 14, 20, col, INK, 2)
    p.ell(cx - 3, y0 + 16, 5, 9, (226, 232, 228), None)
    p.line([(cx - 1, y0 + 46), (cx - 1, y0 + 80)], (226, 232, 228), 1.2)


def spoon_dent(p, cx, y0, y1):
    """An empty spoon-shaped hollow pressed into linen, plan view."""
    lay = p.layer()
    L = y1 - y0
    lay.ell(cx, y0 + L * 0.21, 15, L * 0.21, LINEN_SH, None)
    lay.rect(cx - 5, y0 + L * 0.36, cx + 5, y1 - 8, LINEN_SH, None, r=4)
    lay.ell(cx, y1 - 8, 8, 8, LINEN_SH, None)
    p.put(lay)
    p.arc(cx, y0 + L * 0.21, 15, L * 0.21, 150, 330, mix(LINEN_SH, INK, 0.4), 1.6)
    p.arc(cx, y0 + L * 0.21, 15, L * 0.21, -30, 150, (250, 248, 240), 1.4)
    p.line([(cx - 5, y0 + L * 0.4), (cx - 5, y1 - 14)], mix(LINEN_SH, INK, 0.4), 1.4)
    p.line([(cx + 5, y0 + L * 0.4), (cx + 5, y1 - 14)], (250, 248, 240), 1.2)


def step_button(p, x0, y0, x1, y1, left):
    p.rect(x0, y0, x1, y1, BRASS, INK, 2.6, r=10)
    p.rect(x0 + 6, y0 + 6, x1 - 6, y1 - 6, BRASS_LO, INK, 1.6, r=8)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    s = min(x1 - x0, y1 - y0) * 0.24
    if left:
        tri = [(cx - s, cy), (cx + s * 0.8, cy - s), (cx + s * 0.8, cy + s)]
    else:
        tri = [(cx + s, cy), (cx - s * 0.8, cy - s), (cx - s * 0.8, cy + s)]
    p.poly(tri, BRASS_HI, INK, 2)


def paint_c_table(rng):
    p = Pen(W, H, rng)
    timber_ground(p, rng, TIMBER_DK, TIMBER_XD, TIMBER, 110)
    soft_shadow(p, 730, 372, 640, 230, 0.4, 10)
    # the cloth
    p.rect(100, 150, 1350, 580, PAPER_HI, INK, 3)
    lay = p.layer()     # faint weave
    for y in range(156, 576, 6):
        lay.line([(104, y), (1346, y)], LINEN_SH, 1)
    p.put(lay, 0.35)
    chain_rect(p, 112, 160, 1338, 570)
    for i, x in enumerate(MAT_X):
        p.rect(x, 170, x + 124, 370, (226, 218, 198), None)
        chain_rect(p, x, 170, x + 124, 370, mix(INK, SEAGLASS, 0.2), 8, 1.4)
        p.rect(x + 20, 318, x + 104, 362, (242, 238, 226), None)
        chain_rect(p, x + 20, 318, x + 104, 362)
        soft_shadow(p, x + 106, 254, 10, 50, 0.25, 3)
        spoon_plan(p, x + 104, 202)
    # place 9: a vertical end mat with an empty spoon dent
    p.rect(1226, 200, 1338, 480, (226, 218, 198), None)
    chain_rect(p, 1226, 200, 1338, 480, mix(INK, SEAGLASS, 0.2), 8, 1.4)
    p.rect(1240, 400, 1324, 444, (242, 238, 226), None)
    chain_rect(p, 1240, 400, 1324, 444)
    spoon_dent(p, 1282, 230, 330)
    # timber rack with nine recesses
    p.rect(100, 620, 1120, 810, TIMBER, INK, 3, r=6)
    p.line([(108, 626), (1112, 626)], TIMBER_HI, 1.8)
    for k in range(9):
        cx = 162 + 112 * k
        p.ell(cx, 715, 50, 50, TIMBER_HI, INK, 2.2)
        p.ell(cx, 715, 46, 46, TIMBER_XD, INK, 2.4)
        p.arc(cx, 715, 42, 42, 200, 340, (36, 32, 28), 5)
        p.ell(cx, 715, 22, 22, None, mix(TIMBER_XD, TIMBER, 0.4), 1.4)
    # tally housing
    brass_plate(p, 1130, 600, 1300, 820)
    recess(p, 1146, 616, 1284, 720, 6, (24, 30, 34))
    blank_field(p, 1150, 620, 1280, 716, (232, 226, 210), 4)
    step_button(p, 1140, 740, 1212, 804, True)
    step_button(p, 1218, 740, 1290, 804, False)
    # result flag windows
    p.rect(1130, 812, 1300, 924, TIMBER_DK, INK, 2.4, r=4)
    recess(p, 1140, 820, 1290, 864, 4, (26, 34, 40))
    recess(p, 1140, 870, 1290, 914, 4, (26, 34, 40))
    # register plate and COMPARE lever slot
    brass_plate(p, 1300, 600, 1430, 700, BRASS_LO)
    p.rect(1314, 620, 1416, 680, BRASS, INK, 2, r=3)
    brass_plate(p, 1310, 712, 1430, 912)
    recess(p, 1356, 728, 1384, 896, 12)
    for y in (746, 878):
        p.line([(1340, y), (1350, y)], INK, 2)
        p.line([(1390, y), (1400, y)], INK, 2)
    return p


def paint_c_ledger(rng):
    p = Pen(W, H, rng)
    timber_ground(p, rng, TIMBER, TIMBER_DK, TIMBER_HI, 120)
    soft_shadow(p, 724, 520, 620, 420, 0.45, 14)
    p.rect(120, 96, 1328, 916, STORM, INK, 3.2, r=8)              # cloth cover
    for (x, y) in ((120, 96), (1328, 96), (120, 916), (1328, 916)):
        sx = 1 if x < 700 else -1
        sy = 1 if y < 500 else -1
        p.poly([(x, y), (x + 56 * sx, y), (x, y + 56 * sy)], BRASS, INK, 2.4)
    # page stack edges
    for k in range(4):
        p.rect(146 - k * 2, 108 + k * 2, 712, 884 - k * 2, mix(PAPER, PAPER_LO, 0.5), INK, 1.4)
        p.rect(736, 108 + k * 2, 1302 + k * 2, 884 - k * 2, mix(PAPER, PAPER_LO, 0.5), INK, 1.4)
    p.rect(150, 110, 710, 880, PAPER, INK, 2.4)
    p.rect(738, 110, 1298, 880, PAPER, INK, 2.4)
    rules = p.layer()
    for y in range(200, 880, 44):
        rules.line([(176, y), (690, y)], SEAGLASS_HI, 1.6)
        rules.line([(758, y), (1272, y)], SEAGLASS_HI, 1.6)
    p.put(rules, 0.7)
    gut = p.layer()
    gut.rect(690, 110, 758, 880, mix(PAPER_LO, TIMBER, 0.4), None)
    p.put_soft(gut, 16, 0.6)
    p.line([(724, 104), (724, 886)], INK, 2.4)
    # ribbon from the top centre
    rib = [(714, 96), (734, 96), (760, 540), (752, 548), (746, 534), (738, 552), (740, 112)]
    soft_shadow(p, 742, 330, 14, 220, 0.25, 4)
    p.poly([(716, 96), (734, 96), (762, 540), (750, 528), (742, 552), (742, 300), (722, 120)],
           SEAGLASS, INK, 2.2)
    p.line([(724, 106), (746, 470)], SEAGLASS_HI, 1.4)
    del rib
    # lectern ledge and page-turn tabs
    p.rect(80, 890, 1368, 980, TIMBER_DK, INK, 3, r=4)
    p.line([(86, 894), (1362, 894)], TIMBER_HI, 1.8)
    for x0 in (150, 1148):
        brass_plate(p, x0, 900, x0 + 150, 972, BRASS, 10, rivets=False)
        p.rect(x0 + 50, 926, x0 + 100, 946, BRASS_LO, INK, 1.6, r=8)
    return p


def half_token_pts(left=True, ox=0, oy=0):
    """Half-moon token with a zig-zag cut edge, in a 140x190 box."""
    cx, cy, rx, ry = 132, 95, 126, 89
    arc = []
    for i in range(41):
        t = math.radians(90 + 180 * i / 40)
        arc.append((cx + rx * math.cos(t), cy + ry * math.sin(t)))
    zz = []
    n = 9
    for i in range(n + 1):
        y = cy - ry + 2 * ry * i / n
        zz.append((cx + (6 if i % 2 else -4), y))
    pts = arc + zz
    if not left:
        pts = [(140 - x, y) for x, y in pts]
    return [(x + ox, y + oy) for x, y in pts]


def paint_c_board(rng):
    p = Pen(W, H, rng)
    timber_ground(p, rng, TIMBER, TIMBER_DK, TIMBER_HI, 96, vertical=True)
    # tile rack
    p.rect(40, 120, 270, 900, TIMBER_DK, INK, 3, r=4)
    for k in range(10):
        recess(p, 50, 140 + 76 * k, 260, 206 + 76 * k, 4, (40, 36, 32))
    # the board
    soft_shadow(p, 690, 410, 390, 310, 0.4, 10)
    p.rect(300, 100, 1060, 700, TIMBER_DK, INK, 3.2, r=4)
    p.rect(312, 108, 1048, 692, STORM_LO, INK, 2.2)
    blank_field(p, 320, 116, 1040, 166)
    for k in range(8):
        y = 180 + 50 * k
        blank_field(p, 320, y, 1040, y + 42)
        for x in (330, 1030):
            p.ell(x, y + 21, 3, 3, BRASS_HI, INK, 1.2)
    blank_field(p, 320, 604, 680, 688, (226, 220, 200), 4)
    step_button(p, 700, 616, 772, 684, True)
    recess(p, 788, 604, 888, 694, 4, (24, 30, 34))
    step_button(p, 904, 616, 976, 684, False)
    for y in (140, 660):
        for x in (296, 1064):
            p.rect(x - 6, y - 26, x + 6, y + 26, BRASS, INK, 2, r=3)
    # amendment slot
    p.rect(300, 722, 1060, 834, SOOT, INK, 2.8, r=4)
    for (x0, x1) in ((320, 470), (490, 820), (840, 1050)):
        recess(p, x0, 730, x1, 826, 4, (30, 34, 38))
    # placard
    p.rect(300, 850, 1060, 960, ENAMEL, INK, 2.8, r=6)
    p.rect(310, 860, 1050, 950, None, STORM, 2, r=4)
    for x in (318, 1042):
        rivet(p, x, 905, 3.4, BRASS_HI)
    # token socket
    brass_plate(p, 1090, 120, 1420, 440, BRASS_LO)
    for left, ox in ((True, 1110), (False, 1260)):
        pts = half_token_pts(left, ox, 140)
        p.poly(pts, (30, 26, 20), INK, 2.6)
        inner = [(x + (4 if left else -4), y + 4) for x, y in pts]
        lay = p.layer()
        lay.poly(inner, (14, 12, 10), None)
        p.put(lay, 0.6)
    p.line([(1255, 140), (1255, 330)], INK, 2)
    zz = [(1255 + (6 if i % 2 else -6), 140 + 190 * i / 9) for i in range(10)]
    p.line(zz, BRASS_HI, 2)
    p.ell(1255, 385, 46, 42, BRASS, INK, 2.6)
    p.ell(1255, 385, 36, 33, (30, 26, 20), INK, 2.2)
    # seal selector
    brass_plate(p, 1090, 470, 1420, 670)
    for n, x in enumerate((1148, 1250, 1352), 1):
        p.ell(x, 530, 32, 32, BRASS_HI, INK, 2.6)
        p.ell(x, 530, 27, 27, BRASS, None)
        span = (n - 1) * 10
        for j in range(n):
            bx = x - span / 2 + j * 10
            p.poly([(bx - 0.6, 514), (bx + 3.6, 514), (bx + 0.6, 546), (bx - 3.6, 546)], INK, None)
            p.line([(bx + 4.4, 516), (bx + 1.6, 544)], BRASS_HI, 1.2)
        blank_field(p, x - 48, 612, x + 48, 660, ENAMEL)
    # stamp housing
    p.rect(1110, 676, 1400, 856, SOOT, INK, 3, r=6)
    p.rect(1124, 690, 1386, 842, (52, 52, 54), INK, 1.8, r=4)
    p.rect(1170, 824, 1300, 842, (36, 30, 34), INK, 1.6)            # ink pad
    # paper tape window
    p.rect(1090, 870, 1420, 960, SOOT, INK, 2.8, r=6)
    recess(p, 1100, 880, 1410, 950, 4, (24, 30, 34))
    p.rect(1100, 896, 1410, 934, PAPER, INK, 1.8)
    return p


# ----------------------------------------------------------------------------- sprites: view A

def paint_a_bowl(rng, square=False):
    p = Pen(96, 64, rng)
    bowl_side(p, 0, 0, band=not square, square=square)
    return p


def paint_a_stack_rim(rng):
    p = Pen(104, 22, rng)
    p.poly([(6, 9), (98, 9), (93, 21), (11, 21)], ENAMEL, INK, 2.2)
    p.poly([(70, 9), (98, 9), (93, 21), (66, 21)], mix(ENAMEL, SEAGLASS, 0.35), None)
    p.rect(8, 12, 96, 17, STORM, None)
    p.poly([(6, 9), (98, 9), (93, 21), (11, 21)], None, INK, 2.2)
    p.rect(2, 3, 102, 10, ENAMEL, INK, 2.2, r=3)
    p.line([(8, 5.5), (64, 5.5)], (250, 250, 246), 1.2)
    return p


def paint_a_spoon(rng):
    p = Pen(56, 16, rng)
    spoon_side(p, 1, 12, 54)
    return p


def chair_back(p, ox, oy):
    for x in (ox + 6, ox + 92):
        p.rect(x, oy + 6, x + 12, oy + 140, TIMBER_DK, INK, 2.4, r=2)
        p.ell(x + 6, oy + 6, 7, 6, TIMBER, INK, 2)
    p.poly(bezier((ox + 10, oy + 22), (ox + 55, oy + 4), (ox + 100, oy + 22), 14) +
           bezier((ox + 100, oy + 42), (ox + 55, oy + 26), (ox + 10, oy + 42), 14), TIMBER, INK, 2.4)
    p.line(bezier((ox + 16, oy + 26), (ox + 55, oy + 12), (ox + 94, oy + 26), 14), TIMBER_HI, 1.4)
    p.rect(ox + 14, oy + 92, ox + 96, oy + 102, TIMBER, INK, 2.2)
    for x in (ox + 34, ox + 52, ox + 70):
        p.rect(x, oy + 38, x + 7, oy + 94, TIMBER_DK, INK, 1.8)


def paint_a_chair_tucked(rng):
    p = Pen(110, 140, rng)
    chair_back(p, 0, 0)
    return p


def paint_a_chair_out(rng):
    lay = Pen(150, 300, rng)
    # side profile of the same chair, pulled clear of the table and left standing
    lay.rect(112, 168, 126, 290, TIMBER_DK, INK, 2.6)                # front leg
    lay.rect(58, 238, 118, 248, TIMBER_DK, INK, 2)                   # stretcher
    lay.poly([(34, 14), (52, 12), (64, 290), (48, 290)], TIMBER_DK, INK, 2.6)  # back post + rear leg
    lay.poly([(26, 4), (60, 2), (62, 22), (30, 26)], TIMBER, INK, 2.4)        # crest rail end
    lay.line([(32, 8), (56, 6)], TIMBER_HI, 1.4)
    lay.rect(40, 88, 56, 100, TIMBER, INK, 1.8)                      # mid rail end
    lay.rect(42, 158, 140, 178, TIMBER, INK, 2.8, r=3)               # seat edge
    lay.line([(46, 161), (136, 161)], TIMBER_HI, 1.6)
    out = Pen(150, 300, rng)
    sh = Pen(150, 300, rng)
    sh.ell(88, 292, 60, 5, INK, None)
    out.put_soft(sh, 3, 0.35)
    out.im.alpha_composite(lay.im.rotate(-4, resample=Image.BICUBIC, center=(88 * SS, 290 * SS)))
    return out


def towel_layer(p, y0, y1, fold_left, damp=False, rng=None):
    x0, x1 = 2, 70
    r = (y1 - y0) / 2
    if fold_left:
        p.rect(x0 + r, y0, x1, y1, PAPER_HI, None)
        p.ell(x0 + r, (y0 + y1) / 2, r, r, PAPER_HI, None)
        p.line([(x1, y0), (x0 + r, y0)], INK, 2)
        p.arc(x0 + r, (y0 + y1) / 2, r, r, 90, 270, INK, 2)
        p.line([(x0 + r, y1), (x1, y1)], INK, 2)
        p.line([(x1, y0), (x1, y1)], INK, 1.4)
    else:
        p.rect(x0, y0, x1 - r, y1, PAPER_HI, None)
        p.ell(x1 - r, (y0 + y1) / 2, r, r, PAPER_HI, None)
        p.line([(x0, y0), (x1 - r, y0)], INK, 2)
        p.arc(x1 - r, (y0 + y1) / 2, r, r, 270, 450, INK, 2)
        p.line([(x1 - r, y1), (x0, y1)], INK, 2)
        p.line([(x0, y0), (x0, y1)], INK, 1.4)
    # sea-glass stripes near each end
    for sx in (14, 20, 52, 58):
        p.line([(sx, y0 + 2), (sx, y1 - 2)], SEAGLASS, 2.2)


def paint_a_towel(rng, refolded=False):
    if not refolded:
        p = Pen(72, 40, rng)
        towel_layer(p, 26, 39, True)
        towel_layer(p, 14, 27, False)
        towel_layer(p, 2, 15, True)
        return p
    p = Pen(72, 44, rng)
    towel_layer(p, 22, 43, False)
    towel_layer(p, 2, 23, False)
    m = p.layer()
    m.im.alpha_composite(p.im)
    damp = p.layer()
    for (x, y, rx, ry) in ((24, 30, 14, 8), (48, 12, 12, 7), (60, 34, 9, 6), (14, 10, 7, 5)):
        damp.ell(x, y, rx, ry, mix(SEAGLASS, STORM, 0.5), None)
    damp.im = damp.im.filter(ImageFilter.GaussianBlur(2 * SS))
    p.put(damp, 0.6, mask=m.alpha())
    return p


def paint_a_ring(rng):
    p = Pen(40, 12, rng)
    p.ell(20, 6, 17, 4, None, mix(SOUP, TIMBER, 0.3), 2.2)
    lay = p.layer()
    lay.arc(20, 6, 17, 4, 20, 160, TIMBER_DK, 2.6)
    p.put(lay, 0.5)
    return p


def paint_a_ring_warm(rng):
    p = Pen(40, 60, rng)
    p.ell(20, 54, 17, 4, None, mix(AMBER, TIMBER, 0.25), 2.4)
    wisp = p.layer()
    pts = [(20 + 6 * math.sin(i * 0.32) * (1 - i / 34), 52 - i * 1.45) for i in range(34)]
    for j in range(len(pts) - 1):
        w = 3.4 * (1 - j / 34) + 0.8
        wisp.line([pts[j], pts[j + 1]], (236, 232, 220), w)
    p.put(wisp, 0.75)
    return p


def paint_a_soup(rng):
    p = Pen(96, 64, rng)
    # a fresh tide line just under the rim, one dribble down the side
    m = Pen(96, 64, rng)
    m.poly(bezier((93, 16), (90, 50), (66, 55), 16) + bezier((30, 55), (6, 50), (3, 16), 16), (255, 255, 255), None)
    lay = p.layer()
    lay.line(wavy(rng, 2, 94, 35, 1.0, step=6), SOUP, 3)
    lay.line(wavy(rng, 2, 94, 38, 0.8, step=6), mix(SOUP, ENAMEL, 0.5), 1.4)
    lay.line([(60, 36), (61, 44), (60, 50)], SOUP, 2.6)
    lay.ell(60, 51, 2.6, 3, SOUP, None)
    p.put(lay, 1.0, mask=m.alpha())
    return p


def bead(p, x, y, r, trail_to=None, length=0):
    if trail_to is not None and length > 0:
        dx, dy = trail_to[0] - x, trail_to[1] - y
        m = math.hypot(dx, dy) or 1
        ux, uy = dx / m, dy / m
        # the trail runs behind the bead toward place 9
        p.line([(x - ux * length, y - uy * length), (x, y)], (214, 230, 224, 170), max(1.0, r * 0.8))
    p.ell(x + 0.6, y + 0.8, r, r, (40, 60, 66, 120), None)
    p.ell(x, y, r, r, (232, 242, 238, 230), None)
    p.ell(x - r * 0.35, y - r * 0.35, r * 0.35, r * 0.35, (255, 255, 255, 255), None)


def paint_a_condensation(rng):
    p = Pen(W, H, rng)
    aim = (1226, 560)
    for i, x in enumerate(PLACE_X):
        for _ in range(9 if i < 8 else 5):
            yy = rng.uniform(546, 582)
            half = 44 - (yy - 540) * 0.45
            xx = x + rng.uniform(-half, half)
            if i == 8:     # on the ninth bowl the beads gather to its middle
                tgt = (x, 562)
                ln = rng.uniform(3, 7)
            else:
                tgt = (aim[0], yy + (aim[1] - yy) * 0.15)
                ln = rng.uniform(7, 15)
            bead(p, xx, yy, rng.uniform(1.6, 2.6), tgt, ln)
    return p


def paint_c_condense_plan(rng):
    p = Pen(W, H, rng)
    aim = BOWL_PLAN[8]
    for k, (cx, cy) in enumerate(BOWL_PLAN):
        for _ in range(12 if k < 8 else 7):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(26, 46)
            x, y = cx + r * math.cos(a), cy + r * math.sin(a)
            tgt = (cx, cy) if k == 8 else aim
            bead(p, x, y, rng.uniform(2.2, 3.4), tgt, rng.uniform(8, 18) if k < 8 else 5)
    return p


def paint_rain(rng, kind):
    p = Pen(340, 190, rng)
    gx0, gy0, gx1, gy1 = GLASS[0] - 560, GLASS[1] - 110, GLASS[2] - 560, GLASS[3] - 110
    mask = Pen(340, 190, rng)
    mask.rect(gx0, gy0, gx1, gy1, (255, 255, 255), None)
    mask.rect(MULL_X - 560 - 5, gy0, MULL_X - 560 + 5, gy1, (0, 0, 0, 0), None)
    mask.rect(gx0, MULL_Y - 110 - 5, gx1, MULL_Y - 110 + 5, (0, 0, 0, 0), None)
    lay = p.layer()
    if kind == "light":
        for _ in range(46):
            x, y = rng.uniform(gx0, gx1), rng.uniform(gy0, gy1)
            L = rng.uniform(8, 22)
            lay.line([(x, y), (x + L * 0.14, y + L)], (214, 226, 224, 150), 1.4)
    elif kind == "heavy":
        for _ in range(130):
            x, y = rng.uniform(gx0, gx1), rng.uniform(gy0 - 10, gy1)
            L = rng.uniform(16, 44)
            lay.line([(x, y), (x + L * 0.16, y + L)], (220, 232, 230, 170), rng.choice((1.4, 1.8, 2.2)))
        for _ in range(7):   # running rivulets
            x = rng.uniform(gx0 + 6, gx1 - 6)
            pts = [(x + math.sin(j * 0.7 + x) * 2.2, gy0 + j * 8) for j in range(21)]
            lay.line(pts, (226, 236, 234, 190), 2.4)
    else:
        for _ in range(22):   # beads that hang under the bars and the frame
            bar = rng.choice((MULL_Y - 110 + 6, gy1 - 1))
            x = rng.uniform(gx0 + 6, gx1 - 6)
            L = rng.uniform(4, 14)
            lay.line([(x, bar), (x, bar + L)], (220, 232, 230, 200), 2)
            bead(lay, x, bar + L + 2.5, rng.uniform(2.6, 3.6))
        for _ in range(16):
            bead(lay, rng.uniform(gx0, gx1), rng.uniform(gy0, gy1), rng.uniform(1.8, 2.8))
    p.put(lay, 1.0, mask=mask.alpha())
    return p


def paint_a_warm_b7(rng):
    p = Pen(W, H, rng)
    lay = p.layer()
    lay.poly([(1374, 150), (W + 4, 150), (W + 4, 880), (1374, 880)], AMBER, None)
    lay.poly([(1374, 880), (W + 4, 880), (W + 4, 1000), (1220, 1000), (1280, 930)], AMBER, None)
    lay.rect(1340, 160, 1374, 880, mix(AMBER, (0, 0, 0), 0.4), None)
    p.put_soft(lay, 26, 0.45)
    return p


# ----------------------------------------------------------------------------- sprites: view B

def duplicate_board(p, x0, y0, x1, y1, header, strips, msg, slab_w):
    """The board behind the board: older, the same hand; every strip blank for the view."""
    p.rect(0, 0, p.w, p.h, None, None)
    p.rect(x0 - 6, y0 - 6, x1 + 6, y1 + 6, (14, 18, 22), INK, 2.6)       # the wall cavity
    p.rect(x0, y0, x1, y1, TIMBER_XD, INK, 2.6)
    p.rect(x0 + 8, y0 + 8, x1 - 8, y1 - 8, (28, 34, 38), INK, 1.8)
    old = (204, 196, 172)
    blank_field(p, header[0], header[1], header[2], header[3], old)
    for (a, b, c, d) in strips:
        blank_field(p, a, b, c, d, old)
    blank_field(p, msg[0], msg[1], msg[2], msg[3], (220, 214, 194))
    # the swung board edge-on at the left hinge
    p.rect(0, 0, slab_w, p.h, TIMBER, INK, 2.8)
    p.line([(6, 4), (6, p.h - 4)], TIMBER_HI, 1.6)
    p.line([(slab_w - 6, 4), (slab_w - 6, p.h - 4)], TIMBER_XD, 2)
    for y in (p.h * 0.15, p.h * 0.85):
        p.rect(slab_w - 6, y - 18, slab_w + 6, y + 18, BRASS, INK, 2, r=3)
        p.line([(slab_w, y - 18), (slab_w, y + 18)], BRASS_LO, 1.4)


def paint_b_board_swung(rng):
    p = Pen(380, 400, rng)
    strips = [(54, 70 + 34 * k, 296, 96 + 34 * k) for k in range(6)]
    duplicate_board(p, 44, 12, 354, 392, (54, 20, 344, 60), strips, (54, 310, 344, 340), 40)
    return p


def fog(p, rng, x0, y0, x1, y1, wipe=None):
    lay = p.layer()
    lay.rect(x0, y0, x1, y1, FOG + (205,), None, r=6)
    for _ in range(int((x1 - x0) * (y1 - y0) / 1400)):
        x, y = rng.uniform(x0 + 4, x1 - 4), rng.uniform(y0 + 4, y1 - 4)
        r = rng.uniform(1.4, 3.2)
        lay.ell(x + 0.6, y + 0.8, r, r, (120, 146, 140, 120), None)
        lay.ell(x, y, r, r, (238, 246, 242, 230), None)
    for _ in range(int((x1 - x0) / 40)):   # a few drips running down
        x = rng.uniform(x0 + 8, x1 - 8)
        ya = rng.uniform(y0 + 10, y1 - 60)
        yb = ya + rng.uniform(30, 90)
        lay.line([(x, ya), (x + 1, min(yb, y1 - 4))], (150, 176, 168, 200), 2.4)
    if wipe:
        wa, wb = wipe
        cut = Image.new("L", lay.im.size, 255)
        d = ImageDraw.Draw(cut)
        pts = [(x0 * SS, (wa + 2) * SS)]
        x = x0
        while x <= x1:
            pts.append((x * SS, (wa + rng.uniform(-3, 3)) * SS))
            x += 14
        x = x1
        while x >= x0:
            pts.append((x * SS, (wb + rng.uniform(-3, 3)) * SS))
            x -= 14
        d.polygon(pts, fill=0)
        a = ImageChops.multiply(lay.im.getchannel("A"), cut)
        lay.im.putalpha(a)
        for _ in range(int((x1 - x0) / 24)):   # beads gathered along the wiped edge
            x = rng.uniform(x0 + 4, x1 - 4)
            bead(lay, x, wb + rng.uniform(0, 5), rng.uniform(2, 3.4))
    p.put(lay)


def paint_fog(rng, w, h, wipe=None):
    p = Pen(w, h, rng)
    fog(p, rng, 2, 2, w - 2, h - 2, wipe)
    return p


def paint_b_hatch_open(rng):
    p = Pen(120, 320, rng)
    p.rect(0, 0, 120, 320, DARK, INK, 2.4)
    for k in range(6):     # stair nosings going down into the dark
        y = 120 + k * 34
        c = mix((60, 70, 72), DARK, k / 6)
        p.rect(24, y, 120, y + 6, c, None)
    p.line([(30, 80), (118, 300)], mix(BRASS_LO, DARK, 0.4), 3)
    p.line([(30, 80), (30, 110)], mix(BRASS_LO, DARK, 0.4), 2.4)
    p.rect(0, 0, 18, 320, TIMBER_DK, INK, 2.4)        # the hatch swung inward, edge-on
    p.line([(4, 4), (4, 316)], TIMBER, 1.4)
    p.rect(0, 0, 120, 320, None, INK, 2.4)
    return p


def paint_b_drawer_open(rng):
    p = Pen(300, 150, rng)
    p.rect(8, 4, 292, 60, (24, 22, 20), INK, 2.4)
    p.poly([(8, 4), (30, 18), (270, 18), (292, 4)], (40, 36, 32), None)
    # blank note slip
    p.poly([(40, 24), (132, 20), (136, 50), (44, 54)], PAPER_HI, INK, 1.8)
    # empty half-token recess with its zig-zag edge
    pts = half_token_pts(True)
    pts = [(170 + x * 0.36, 18 + y * 0.2) for x, y in pts]
    p.poly(pts, (10, 9, 8), mix(BRASS_LO, DARK, 0.3), 1.8)
    # the pulled drawer front, a touch nearer
    p.rect(2, 56, 298, 148, mix(TIMBER, TIMBER_HI, 0.3), INK, 2.8, r=2)
    p.line([(6, 60), (294, 60)], TIMBER_HI, 1.6)
    p.rect(118, 94, 182, 112, BRASS, INK, 2.2, r=7)
    p.line([(124, 98), (176, 98)], BRASS_HI, 1.4)
    return p


def paint_b_work_card(rng):
    p = Pen(110, 150, rng)
    p.poly([(2, 0), (108, 1), (107, 148), (3, 147)], PAPER, INK, 2)
    grid = p.layer()
    for y in range(30, 140, 10):
        grid.line([(10, y), (100, y)], SEAGLASS_HI, 1)
    for x in range(10, 101, 10):
        grid.line([(x, 30), (x, 138)], SEAGLASS_HI, 1)
    p.put(grid, 0.55)
    p.rect(10, 14, 100, 24, (226, 218, 196), None)      # blank heading field
    p.ell(55, 6, 3.2, 3.2, DARK, None)
    p.poly([(96, 147), (107, 136), (107, 148)], PAPER_LO, INK, 1.2)   # dog-eared corner
    return p


def paint_b_range_glow(rng):
    p = Pen(W, H, rng)
    lay = p.layer()
    lay.ell(280, 600, 90, 70, AMBER, None)
    lay.ell(380, 920, 270, 46, AMBER, None)
    lay.rect(760, 610, 790, 864, AMBER, None)
    p.put_soft(lay, 28, 0.42)
    vs = p.layer()
    for k in range(5):
        sx = 238 + k * 19
        vs.rect(sx, 564, sx + 10, 636, AMBER, None)
    p.put_soft(vs, 4, 0.6)
    return p


# ----------------------------------------------------------------------------- sprites: close-ups

def paint_c_bowl(rng, square=False):
    p = Pen(104, 104, rng)
    c = 52
    p.ell(c, c, 50, 50, ENAMEL, INK, 2.6)
    if not square:
        p.ell(c, c, 47, 47, STORM, None)
        p.ell(c, c, 35, 35, ENAMEL, INK, 2)
    else:
        p.ell(c, c, 46, 46, None, STORM, 1.6)
        p.ell(c, c, 38, 38, None, mix(ENAMEL, SEAGLASS, 0.4), 1.4)
    sh = p.layer()
    sh.ell(c + 7, c + 7, 30, 30, mix(ENAMEL, SEAGLASS, 0.3), None)
    m = p.layer()
    m.ell(c, c, 34 if not square else 44, 34 if not square else 44, (255, 255, 255), None)
    p.put(sh, 1.0, mask=m.alpha())
    p.ell(c, c, 16, 16, None, mix(ENAMEL, SEAGLASS, 0.45), 1.4)
    p.ell(c - 18, c - 34 if square else c - 41, 2.2, 1.6, INK, None)   # an enamel chip on the rim
    if square:
        sx, sy = 60, 58
        p.rect(sx, sy, sx + 22, sy + 22, BRASS, INK, 2.2)
        p.line([(sx + 3, sy + 3), (sx + 19, sy + 3)], BRASS_HI, 1.4)
        for x, y in ((sx + 4, sy + 4), (sx + 18, sy + 4), (sx + 4, sy + 18), (sx + 18, sy + 18)):
            p.ell(x, y, 2, 2, BRASS_HI, INK, 1.1)
    return p


def paint_c_spoon(rng):
    p = Pen(34, 96, rng)
    spoon_plan(p, 17, 0)
    return p


def paint_c_soup(rng):
    p = Pen(104, 104, rng)
    lay = p.layer()
    lay.ell(52, 52, 30, 30, None, SOUP, 3)
    lay.ell(52, 52, 27, 27, None, mix(SOUP, ENAMEL, 0.5), 1.4)
    lay.ell(60, 60, 18, 14, SOUP + (70,), None)
    p.put(lay)
    return p


def paint_c_shadow(rng):
    p = Pen(120, 120, rng)
    lay = p.layer()
    lay.ell(60, 62, 44, 40, INK, None)
    p.put_soft(lay, 8, 0.45)
    return p


def paint_c_lever(rng, up):
    p = Pen(120, 200, rng)
    piv = (60, 112)
    knob = (60, 34) if up else (60, 176)
    r = 20 if up else 24
    p.ell(piv[0], piv[1], 14, 14, SOOT, INK, 2.2)
    p.line([piv, knob], INK, 12)
    p.line([piv, knob], BRASS, 8)
    p.line([(piv[0] - 2, piv[1]), (knob[0] - 2, knob[1])], BRASS_HI, 2)
    p.ell(knob[0], knob[1], r, r, SOOT, INK, 2.6)
    p.ell(knob[0] - r * 0.3, knob[1] - r * 0.3, r * 0.3, r * 0.3, SOOT_HI, None)
    p.ell(piv[0], piv[1], 5, 5, BRASS_HI, INK, 1.4)
    return p


def paint_c_tally_wheel(rng):
    p = Pen(130, 96, rng)
    bands = [(0, 10, BRASS_LO), (10, 30, BRASS), (66, 86, BRASS), (86, 96, BRASS_LO)]
    for y0, y1, c in bands:
        p.rect(0, y0, 130, y1, c, None)
    for x in range(8, 126, 12):
        p.line([(x, 4), (x, 24)], INK, 1.8)
        p.line([(x, 72), (x, 92)], INK, 1.8)
    p.rect(2, 30, 128, 66, ENAMEL, INK, 2.2)
    p.line([(4, 33), (126, 33)], (250, 248, 240), 1.4)
    p.rect(0, 0, 130, 96, None, INK, 2.6, r=4)
    return p


def paint_c_flag(rng, agree):
    p = Pen(150, 44, rng)
    lay = p.layer()
    if agree:
        lay.rect(8, 13, 142, 31, SEAGLASS_HI, INK, 2.4, r=4)
        lay.ell(14, 22, 6, 6, BRASS_HI, INK, 1.6)
        lay.ell(136, 22, 6, 6, BRASS_HI, INK, 1.6)
        p.put(lay)
    else:
        lay.rect(10, 13, 140, 31, VIOLET, INK, 2.4, r=4)
        lay.ell(16, 22, 6, 6, BRASS_HI, INK, 1.6)
        p.put(lay)
        p.im = p.im.rotate(11, resample=Image.BICUBIC, center=(75 * SS, 22 * SS))
        p.d = ImageDraw.Draw(p.im)
    return p


def paint_c_sketch(rng, cup):
    p = Pen(300, 200, rng)
    g = GRAPHITE + (210,)
    gl = GRAPHITE + (120,)

    def sk(pts, col=g, w=1.6, jit=0.8):
        p.line([(x + rng.uniform(-jit, jit), y + rng.uniform(-jit, jit)) for x, y in pts], col, w)

    if not cup:
        for _ in range(2):
            sk(bezier((50, 70), (150, 54), (250, 70), 20))
            sk(bezier((50, 70), (60, 150), (120, 160), 20) + [(180, 160)] + bezier((180, 160), (240, 150), (250, 70), 20)[1:])
            sk(bezier((50, 70), (150, 86), (250, 70), 20), gl, 1.2)
        sk([(110, 168), (190, 168)], g, 1.4)
        for x0 in (140, 141):
            sk([(x0, 96), (x0 + 36, 96), (x0 + 36, 130), (x0, 130), (x0, 96)], g, 1.8)
        for (x, y) in ((146, 102), (170, 102), (146, 124), (170, 124)):
            p.ell(x, y, 2.4, 2.4, g, None)
        for k in range(12):   # hatching on the shaded side
            x = 200 + k * 4
            sk([(x, 80 + k * 2), (x - 14, 140)], gl, 1.1, 0.4)
    else:
        for _ in range(2):
            sk([(90, 50), (92, 160), (180, 162), (182, 50)])
            sk(bezier((90, 50), (136, 40), (182, 50), 12), gl, 1.2)
            sk(bezier((90, 50), (136, 60), (182, 50), 12))
            sk(bezier((182, 70), (240, 70), (236, 110), 12) + bezier((236, 110), (232, 146), (182, 140), 12)[1:])
            sk(bezier((182, 84), (220, 84), (218, 110), 12) + bezier((218, 110), (216, 132), (182, 128), 12)[1:], gl, 1.2)
        # the brass staple through the handle
        sk([(214, 96), (240, 92), (242, 100), (216, 104), (214, 96)], g, 2)
        p.ell(216, 100, 2.4, 2.4, g, None)
        p.ell(240, 96, 2.4, 2.4, g, None)
        for k in range(10):
            x = 150 + k * 3
            sk([(x, 60 + k), (x - 12, 156)], gl, 1.1, 0.4)
    return p


def paint_c_token(rng, left):
    p = Pen(140, 190, rng)
    pts = half_token_pts(left)
    p.poly(pts, BRASS, INK, 2.8)
    m = p.layer()
    m.poly(pts, (255, 255, 255), None)
    hi = p.layer()
    cx = 132 if left else 8
    hi.ell(cx + (-14 if left else 14), 82, 104, 74, None, BRASS_HI, 3)
    hi.ell(cx, 95, 70, 50, None, BRASS_LO, 2.4)
    hi.ell(cx + (-40 if left else 40), 95, 7, 7, (30, 26, 20), INK, 1.6)
    p.put(hi, 1.0, mask=m.alpha())
    p.poly(pts, None, INK, 2.8)
    return p


def paint_c_knob(rng, turned):
    p = Pen(100, 90, rng)
    p.ell(50, 45, 38, 38, BRASS, INK, 2.6)
    p.ell(50, 45, 30, 30, None, BRASS_LO, 2)
    if turned:
        p.rect(42, 10, 58, 80, BRASS_HI, INK, 2.4, r=6)
        p.line([(50, 14), (50, 26)], INK, 2.4)
    else:
        p.rect(14, 37, 86, 53, BRASS_HI, INK, 2.4, r=6)
        p.line([(18, 45), (30, 45)], INK, 2.4)
    return p


def paint_c_seal_marker(rng):
    p = Pen(96, 40, rng)
    p.rect(14, 2, 82, 14, BRASS, INK, 2.2, r=4)
    p.poly([(36, 12), (60, 12), (48, 38)], BRASS_HI, INK, 2.2)
    p.line([(48, 16), (48, 30)], BRASS_LO, 1.6)
    return p


def paint_c_tile(rng, kind):
    w, h = (140, 86) if kind == "small" else (210, 66)
    p = Pen(w, h, rng)
    base = BRASS_HI if kind == "new" else mix(BRASS, BRASS_LO, 0.4)
    p.rect(2, 2, w - 2, h - 2, base, INK, 2.6, r=5)
    p.line([(8, 7), (w - 8, 7)], (232, 206, 150) if kind == "new" else BRASS, 2)
    p.line([(8, h - 7), (w - 8, h - 7)], BRASS_LO if kind == "new" else mix(BRASS_LO, INK, 0.3), 2)
    if kind != "new":
        tar = p.layer()
        m = p.layer()
        m.rect(4, 4, w - 4, h - 4, (255, 255, 255), None, r=4)
        for _ in range(4):     # broad dull clouding
            tar.ell(rng.uniform(20, w - 20), rng.uniform(10, h - 10), rng.uniform(24, 46), rng.uniform(12, 22),
                    mix(BRASS_LO, INK, 0.2), None)
        for x in (12, w - 12):  # verdigris where the screws hold the damp
            tar.ell(x, h / 2, 10, 8, SEAGLASS, None)
        tar.im = tar.im.filter(ImageFilter.GaussianBlur(6 * SS))
        p.put(tar, 0.5, mask=m.alpha())
        for _ in range(5):
            p.ell(rng.uniform(16, w - 16), rng.uniform(10, h - 10), 1.2, 1.0, BRASS_LO, None)
    for x in (12, w - 12):
        p.ell(x, h / 2, 3.4, 3.4, BRASS_LO, INK, 1.4)
    return p


def paint_c_stamp(rng, up):
    p = Pen(290, 180, rng)
    piv = (232, 44)
    hand = (38, 8) if up else (38, 84)
    head_y = 64 if up else 112
    p.rect(224, 30, 244, 150, SOOT_HI, INK, 2.2)                     # standard
    p.rect(126, head_y - 40, 142, head_y, BRASS_LO, INK, 2)          # ram
    p.rect(96, head_y, 172, head_y + 30, BRASS, INK, 2.6, r=3)       # stamp head
    p.rect(100, head_y + 30, 168, head_y + 36, (36, 30, 34), INK, 1.6)
    p.line([hand, piv], INK, 13)
    p.line([hand, piv], SOOT_HI, 9)
    p.line([(hand[0], hand[1] - 2), (piv[0], piv[1] - 2)], (96, 98, 100), 2)
    p.ell(hand[0], hand[1], 16, 12, (34, 32, 30), INK, 2.4)
    p.ell(piv[0], piv[1], 10, 10, BRASS, INK, 2.2)
    p.ell(piv[0], piv[1], 3.4, 3.4, INK, None)
    return p


def paint_c_board_swung(rng):
    p = Pen(760, 620, rng)
    strips = [(76, 80 + 50 * k, 736, 120 + 50 * k) for k in range(8)]
    duplicate_board(p, 54, 6, 754, 596, (76, 18, 736, 64), strips, (76, 484, 736, 528), 50)
    return p


# ----------------------------------------------------------------------------- registry

ASSETS = [  # name, seed index, painter, opaque, grain
    ("view_a", 0, lambda r: paint_view_a(r, 0), True, True),
    ("view_a_b2", 0, lambda r: paint_view_a(r, 2), True, True),
    ("view_a_b4", 0, lambda r: paint_view_a(r, 4), True, True),
    ("view_a_b6", 0, lambda r: paint_view_a(r, 6), True, True),
    ("view_a_b7", 0, lambda r: paint_view_a(r, 7), True, True),
    ("view_a_sever", 0, lambda r: paint_view_a(r, "sever"), True, True),
    ("view_b", 1, lambda r: paint_view_b(r, 0), True, True),
    ("view_b_b2", 1, lambda r: paint_view_b(r, 2), True, True),
    ("view_b_b4", 1, lambda r: paint_view_b(r, 4), True, True),
    ("view_b_b6", 1, lambda r: paint_view_b(r, 6), True, True),
    ("view_b_b7", 1, lambda r: paint_view_b(r, 7), True, True),
    ("view_b_sever", 1, lambda r: paint_view_b(r, "sever"), True, True),
    ("c_table", 2, paint_c_table, True, True),
    ("c_ledger", 3, paint_c_ledger, True, True),
    ("c_board", 4, paint_c_board, True, True),
    ("a_bowl", 10, paint_a_bowl, False, False),
    ("a_bowl_sq", 11, lambda r: paint_a_bowl(r, True), False, False),
    ("a_stack_rim", 12, paint_a_stack_rim, False, False),
    ("a_spoon", 13, paint_a_spoon, False, False),
    ("a_chair_tucked", 14, paint_a_chair_tucked, False, False),
    ("a_chair_out", 15, paint_a_chair_out, False, False),
    ("a_towel", 16, paint_a_towel, False, False),
    ("a_towel_refolded", 17, lambda r: paint_a_towel(r, True), False, False),
    ("a_ring", 18, paint_a_ring, False, False),
    ("a_ring_warm", 19, paint_a_ring_warm, False, False),
    ("a_soup", 20, paint_a_soup, False, False),
    ("a_condensation", 21, paint_a_condensation, False, False),
    ("a_rain_1", 22, lambda r: paint_rain(r, "light"), False, False),
    ("a_rain_2", 23, lambda r: paint_rain(r, "heavy"), False, False),
    ("a_rain_hang", 24, lambda r: paint_rain(r, "hang"), False, False),
    ("a_warm_b7", 25, paint_a_warm_b7, False, False),
    ("b_board_swung", 30, paint_b_board_swung, False, False),
    ("b_fog", 31, lambda r: paint_fog(r, 340, 380), False, False),
    ("b_fog_wiped", 31, lambda r: paint_fog(r, 340, 380, (300, 330)), False, False),
    ("b_hatch_open", 32, paint_b_hatch_open, False, False),
    ("b_drawer_open", 33, paint_b_drawer_open, False, False),
    ("b_work_card", 34, paint_b_work_card, False, False),
    ("b_range_glow", 35, paint_b_range_glow, False, False),
    ("c_bowl", 40, paint_c_bowl, False, False),
    ("c_bowl_sq", 41, lambda r: paint_c_bowl(r, True), False, False),
    ("c_spoon", 42, paint_c_spoon, False, False),
    ("c_soup", 43, paint_c_soup, False, False),
    ("c_shadow", 44, paint_c_shadow, False, False),
    ("c_condense_plan", 45, paint_c_condense_plan, False, False),
    ("c_lever_up", 46, lambda r: paint_c_lever(r, True), False, False),
    ("c_lever_down", 47, lambda r: paint_c_lever(r, False), False, False),
    ("c_tally_wheel", 48, paint_c_tally_wheel, False, False),
    ("c_flag_agree", 49, lambda r: paint_c_flag(r, True), False, False),
    ("c_flag_disagree", 50, lambda r: paint_c_flag(r, False), False, False),
    ("c_sketch_bowl", 51, lambda r: paint_c_sketch(r, False), False, False),
    ("c_sketch_cup", 52, lambda r: paint_c_sketch(r, True), False, False),
    ("c_token_pantry", 53, lambda r: paint_c_token(r, True), False, False),
    ("c_token_bunk", 54, lambda r: paint_c_token(r, False), False, False),
    ("c_knob", 55, lambda r: paint_c_knob(r, False), False, False),
    ("c_knob_turned", 56, lambda r: paint_c_knob(r, True), False, False),
    ("c_seal_marker", 57, paint_c_seal_marker, False, False),
    ("c_tile", 58, lambda r: paint_c_tile(r, "old"), False, False),
    ("c_tile_new", 59, lambda r: paint_c_tile(r, "new"), False, False),
    ("c_tile_small", 60, lambda r: paint_c_tile(r, "small"), False, False),
    ("c_stamp_up", 61, lambda r: paint_c_stamp(r, True), False, False),
    ("c_stamp_down", 62, lambda r: paint_c_stamp(r, False), False, False),
    ("c_board_swung", 63, paint_c_board_swung, False, False),
    ("c_fog", 64, lambda r: paint_fog(r, 720, 620), False, False),
    ("c_fog_wiped", 64, lambda r: paint_fog(r, 720, 620, (480, 530)), False, False),
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
