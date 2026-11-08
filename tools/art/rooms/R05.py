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

Repaint pass (art direction on db1d3a5): the plates carry the office's lighting grammar (an enamel
pendant over each room's centre, a warm pool that falls off to cooler, darker walls; off at band 7
and in the sever daylight), the office's ~3 px wobbling navy contour, paper mottle and plank grain,
cast shadows under the furniture, a hanging hem, the bench and its pads under the table, water under
place 9, and the band 4-7 tide line as one straight salt crest at the office's station height
(y 512). New sprites sit beside the first set (a_spoon_dark/_used, a_soup_ring, a_chair_pulled,
a_seat9/_wet, a_towel_wet, a_ring_amber/_wisp, a_wet_b2..b7, a_rain_still, b_board_back,
b_book_blank, c_*_damp); the first-set files the view no longer draws are still painted unchanged.

Fix pass w2 (new files only): a_place10 / c_place10 (P07's second blank place, at the rack end,
no spoon, no dent), c_door_edge (the kitchen doorway past the door end of the c_table plan),
a_wet_b2v2..b7v2 (the halo at his place becomes an irregular navy stain with a tide-ring edge and
two drip runs) and a_window_eye_b7v2 (the band-7 eye made stark: slit pupil, sea-glass iris,
paper-white sclera with a navy contour, glazing bars in front). Place 9 never had a painted
square: the old mark was code-drawn, so no erase patch is needed.

Fix pass p1 (new file only, outside the room folder): assets/stages/R05/p09_venn_rubbing.png, a
204x92 RGBA slip of thin paper pinned beside the c_board placard at (40, 898), left of it under the
tile rack: a graphite rubbing of Venn's seal, its three incised cuts left pale; the right half of the
slip is a blank field the view pencils the name into. ASSETS names it "stage:<stem>".

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
STAGE_OUT = os.path.join(ROOT, "assets", "stages", "R05")   # ASSETS names "stage:<stem>"
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


INK_GAIN = 1.2              # contour weight: 2.6 -> ~3.1 px native, the office's navy line


def wobble(pts, step=9.0, amp=0.75):
    """Subdivide a polyline and nudge it sideways by a smooth position-keyed field (no rng, so a
    shape lands identically on every stage plate)."""
    out = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        dx, dy = x1 - x0, y1 - y0
        ln = math.hypot(dx, dy)
        n = max(1, int(ln / step))
        nx, ny = (-dy / ln, dx / ln) if ln > 0 else (0.0, 0.0)
        for i in range(n):
            t = i / n
            x, y = x0 + dx * t, y0 + dy * t
            o = amp * (math.sin(x * 0.051 + y * 0.083 + 1.3) * 0.65 + math.sin(x * 0.137 - y * 0.061) * 0.35)
            if i == 0:
                o = 0.0 if not out else o
            out.append((x + nx * o, y + ny * o))
    out.append(pts[-1])
    return out


class Pen:
    """Draws in 1x logical coordinates on a supersampled RGBA canvas."""

    def __init__(self, w, h, rng, bg=None):
        self.w, self.h, self.rng = w, h, rng
        self.im = Image.new("RGBA", (w * SS, h * SS), rgba(bg) if bg else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def iw(self, w, key=(0.0, 0.0)):
        # slight width variation keyed to position, so stage plates stay identical under swaps.
        # Structural contours (>= 2 px) carry the office's heavier navy line (about 3 px native).
        j = ((int(key[0] * 7) * 7919 + int(key[1] * 7) * 104729) % 61) / 100.0 - 0.3
        if w >= 2.0:
            w *= INK_GAIN
        return max(1, int(round((w + j) * SS)))

    def _p(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def _ink(self, pts, col, w, closed=False):
        """A contour stroke. Heavy navy contours wobble slightly, like the office's hand line."""
        if closed:
            pts = list(pts) + [pts[0]]
        if col[:3] == INK and w >= 2.0 and len(pts) >= 2:
            pts = wobble(pts)
        self.d.line(self._p(pts), fill=rgba(col), width=self.iw(w, pts[0]), joint="curve")

    def poly(self, pts, fill=None, ink=INK, w=2.6):
        p = self._p(pts)
        if fill is not None:
            self.d.polygon(p, fill=rgba(fill))
        if ink is not None and w:
            self._ink(pts, ink, w, closed=True)

    def rect(self, x0, y0, x1, y1, fill=None, ink=INK, w=2.6, r=0):
        box = (x0 * SS, y0 * SS, x1 * SS, y1 * SS)
        width = self.iw(w, (x0, y0)) if (ink is not None and w) else 0
        if width and r <= 3 and ink[:3] == INK and w >= 2.0:
            # square-cornered navy boxes take the hand-drawn wobbling contour
            if fill is not None:
                self.d.rounded_rectangle(box, radius=r * SS, fill=rgba(fill))
            self._ink([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], ink, w, closed=True)
            return
        self.d.rounded_rectangle(box, radius=r * SS, fill=rgba(fill) if fill is not None else None,
                                 outline=rgba(ink) if width else None, width=width)

    def ell(self, cx, cy, rx, ry=None, fill=None, ink=INK, w=2.6):
        ry = rx if ry is None else ry
        box = ((cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS)
        width = self.iw(w, (cx, cy)) if (ink is not None and w) else 0
        self.d.ellipse(box, fill=rgba(fill) if fill is not None else None,
                       outline=rgba(ink) if width else None, width=width)

    def line(self, pts, col=INK, w=2.6):
        self._ink(pts, col, w)

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
    out = OUT
    if name.startswith("stage:"):
        out, name = STAGE_OUT, name[len("stage:"):]
    os.makedirs(out, exist_ok=True)
    if opaque:
        im = im.convert("RGB")
    else:
        im = im.convert("RGBA")
        a = im.getchannel("A")
        clear = a.point(lambda v: 255 if v == 0 else 0)
        im.paste((0, 0, 0, 0), mask=clear)
    path = os.path.join(out, name + ".png")
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


def drop_shadow(p, x0, y0, x1, y1, off=9, op=0.42, blur=7, r=6):
    """A soft shadow under a part, cast down and right (away from the key light)."""
    lay = p.layer()
    lay.rect(x0 + off * 0.6, y0 + off, x1 + off * 0.6, y1 + off, INK, None, r=r)
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


# ----------------------------------------------------------------------------- lighting (office grammar)

WALL_A = (124, 144, 140)        # upper wall: the office's grey-teal, ~15% darker than the old mint
WALL_A_SEAM = mix(WALL_A, INK, 0.3)
WALL_A_HI = (144, 162, 156)
WALL_B = (126, 146, 140)        # kitchen plaster, same family
STATION_Y = 512                 # the tide-line station height (office_s3, painter_3 TIDE_Y)
PENDANT_A = (730, 0, 326, 382)  # x, ceiling y, shade top, shade bottom (cord on the window mullion)
PENDANT_B = (720, 62, 214, 262)
WARM_POOL = (255, 226, 176)


def mottle(im, rng, box, amp=10, cell=90):
    """Broad seeded paper mottle inside `box`: soft blotches up to `amp` levels darker and lighter."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    n = value_noise(rng, w, h, cell).filter(ImageFilter.GaussianBlur(cell * 0.25))
    n2 = value_noise(rng, w, h, cell * 0.35)
    n = ImageChops.add(n.point(lambda v: v // 2), n2.point(lambda v: v // 2))
    pos = n.point(lambda v: max(0, v - 132) * amp // 60)
    neg = n.point(lambda v: max(0, 124 - v) * amp // 60)
    rgb = im.convert("RGB")
    reg = rgb.crop(box)
    reg = ImageChops.add(reg, Image.merge("RGB", [pos] * 3))
    reg = ImageChops.subtract(reg, Image.merge("RGB", [neg] * 3))
    rgb.paste(reg, box[:2])
    return rgb


def plank_grain(p, rng, x0, x1, y0, y1, pitch, col):
    """Long, faintly wandering grain lines down each vertical plank."""
    x = x0
    while x < x1:
        for _ in range(3):
            gx = x + rng.uniform(8, pitch - 8)
            ya = rng.uniform(y0, y0 + (y1 - y0) * 0.4)
            yb = ya + rng.uniform((y1 - y0) * 0.3, (y1 - y0) * 0.7)
            ph = rng.uniform(0, 6.3)
            pts = [(gx + 1.6 * math.sin(ph + k * 0.5), ya + (yb - ya) * k / 12) for k in range(13)]
            p.line(pts, col, 1.1)
        x += pitch


def key_light(im, pool, floor=0.72, warm=0.0, keep=None, core=None):
    """The office's lamp grammar baked into a plate: a soft pool that keeps the plate's own colour,
    falling off to a cooler, darker room; an optional warm lift in the pool's core."""
    cx, cy, rx, ry = pool
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(min(rx, ry) * 0.45))
    if keep is not None:
        m = ImageChops.lighter(m, keep)
    rgb = im.convert("RGB")
    cool = (int(255 * floor * 0.95), int(255 * floor * 0.99), min(255, int(255 * floor * 1.06)))
    out = Image.composite(rgb, ImageChops.multiply(rgb, Image.new("RGB", im.size, cool)), m)
    if warm > 0:
        ccx, ccy, crx, cry = core or (cx, cy, rx * 0.5, ry * 0.5)
        c = Image.new("L", im.size, 0)
        ImageDraw.Draw(c).ellipse((ccx - crx, ccy - cry, ccx + crx, ccy + cry), fill=int(255 * warm))
        c = c.filter(ImageFilter.GaussianBlur(min(crx, cry) * 0.5))
        lit = ImageChops.multiply(ImageChops.screen(out, Image.new("RGB", im.size, (64, 44, 14))),
                                  Image.new("RGB", im.size, WARM_POOL))
        out = Image.composite(lit, out, c)
    return out


def pendant(p, x, y_top, shade_top, shade_bot, on=True):
    """An enamel pendant on a cord: sea-glass cone, navy rim, the bulb under it."""
    p.line([(x, y_top), (x, shade_top - 14)], INK, 3.2)
    p.rect(x - 7, shade_top - 16, x + 7, shade_top + 2, BRASS_LO, INK, 2.2)          # cord grip
    p.line([(x - 4, shade_top - 12), (x - 4, shade_top - 2)], BRASS_HI, 1.2)
    h = shade_bot - shade_top
    cone = [(x - 20, shade_top), (x + 20, shade_top), (x + 58, shade_bot), (x - 58, shade_bot)]
    if on:
        glow = p.layer()
        glow.ell(x, shade_bot + 6, 48, 18, (255, 236, 190), None)
        p.put_soft(glow, 9, 0.85)
    bulb = (252, 236, 196) if on else (120, 124, 120)
    p.ell(x, shade_bot + 4, 15, 12, bulb, INK, 2.2)
    if on:
        p.ell(x - 4, shade_bot + 1, 5, 4, (255, 252, 236), None)
    p.poly(cone, SEAGLASS, INK, 2.8)
    p.poly([(x + 6, shade_top), (x + 20, shade_top), (x + 58, shade_bot), (x + 22, shade_bot)],
           SEAGLASS_DK, None)
    p.line([(x - 14, shade_top + 4), (x - 44, shade_bot - 6)], SEAGLASS_HI, 2.4)          # bevel
    p.poly(cone, None, INK, 2.8)
    p.rect(x - 60, shade_bot - 7, x + 60, shade_bot + 1, STORM, INK, 2.2)                # rim
    if on:   # the lit underside of the rim
        p.line([(x - 54, shade_bot + 2.5), (x + 54, shade_bot + 2.5)], (250, 226, 170), 1.6)
    del h


def hem_pts(x0, x1, base, legs, rng):
    """The cloth's hanging hem: a gentle wave, dropping a little at each leg and at the ends."""
    pts = []
    ph = [rng.uniform(0, 6.3) for _ in range(2)]
    x = x0
    while x <= x1 + 0.1:
        y = base + 2.2 * math.sin(x / 41 + ph[0]) + 1.4 * math.sin(x / 17 + ph[1])
        for lx in legs:
            y += 15 * math.exp(-((x - lx) / 46) ** 2)
        y += 12 * math.exp(-((x - x0) / 26) ** 2) + 12 * math.exp(-((x - x1) / 26) ** 2)
        pts.append((x, y))
        x += 8
    return pts


def cloth_fold(p, x, top, bot, w0=3, w1=16):
    """A soft fold falling to the hem: a shaded wedge with a lit edge beside it."""
    sh = p.layer()
    sh.poly([(x - w0, top), (x + w0, top), (x + w1, bot), (x - w1 * 0.4, bot)], LINEN_SH, None)
    p.put_soft(sh, 3, 0.9)
    p.line([(x - w0 - 2, top + 6), (x - w1 * 0.4 - 3, bot - 4)], (248, 244, 234), 1.4)
    p.line([(x + w0, top + 10), (x + w1 * 0.8, bot - 3)], mix(LINEN_SH, INK, 0.3), 1.2)


def bench_cushion(p, x):
    p.rect(x - 40, 748, x + 40, 760, TIMBER, INK, 2.4)                    # seat slab edge
    p.line([(x - 36, 750.5), (x + 36, 750.5)], TIMBER_HI, 1.4)
    p.poly([(x - 36, 748), (x - 32, 734), (x + 32, 734), (x + 36, 748)], SEAGLASS, INK, 2.2)  # folded pad
    p.line([(x - 30, 737), (x + 30, 737)], SEAGLASS_HI, 1.4)
    p.line([(x - 22, 741), (x + 22, 741)], SEAGLASS_DK, 1.2)


def puddle(p, cx, y, rx, op=1.0):
    """Flat dark water on the boards: a lobed shape with a pale lit lip."""
    lay = p.layer()
    pts = []
    for k in range(36):
        a = 2 * math.pi * k / 36
        r = 1 + 0.12 * math.sin(3 * a + 0.7) + 0.08 * math.sin(5 * a + 2.1)
        pts.append((cx + rx * r * math.cos(a), y + rx * 0.16 * r * math.sin(a)))
    lay.poly(pts, (30, 40, 46), None)
    p.put(lay, 0.82 * op)
    p.line(pts[20:31], (196, 210, 206), 1.6)


def salt_line(p, srng, x0, x1, y, floor_y, damp_op):
    """The office tide line: one straight crisp salt crest at the station height, damp darkening
    below it with a few runs, a faint crust above."""
    d = p.layer()
    d.rect(x0, y, x1, floor_y, TIMBER_XD, None)
    p.put(d, damp_op)
    runs = p.layer()
    for _ in range(int((x1 - x0) / 46)):
        x = srng.uniform(x0 + 4, x1 - 4)
        runs.line([(x, y + 4), (x + srng.uniform(-1, 1), y + srng.uniform(18, 70))], (196, 206, 200), 1.3)
    p.put(runs, 0.45)
    crust = p.layer()
    for _ in range(int((x1 - x0) / 5)):
        x = srng.uniform(x0, x1)
        crust.ell(x, y - srng.uniform(2, 9), srng.uniform(0.8, 1.6), srng.uniform(0.6, 1.2), (226, 230, 220), None)
    p.put(crust, 0.55)
    p.line([(x0, y + 3.5), (x1, y + 3.5)], INK, 3.2)
    p.line([(x0, y - 0.5), (x1, y - 0.5)], (240, 242, 234), 3.6)


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
        # Something pressed against the glass from outside, far too big for the window: an eye
        # opening sideways, its pale almond running in at one side of the frame and out of the
        # other, the iris and a slot pupil inside it. Stark flat shapes; the bars sit in front.
        lid_dark = (14, 22, 28)
        lay.rect(gx0, gy0, gx1, gy1, lid_dark, None)
        upper = bezier((gx0 - 160, 200), (730, 110), (gx1 + 160, 200), 40)
        lower = bezier((gx0 - 160, 200), (730, 330), (gx1 + 160, 200), 40)
        almond = upper + lower[::-1]
        lay.poly(almond, (150, 170, 160), None)
        eye = Pen(W, H, rng)
        eye.poly(almond, (255, 255, 255), None)
        iris = p.layer()
        iris.ell(786, 196, 66, 66, (40, 58, 60), None)
        iris.ell(786, 196, 66, 66, None, (98, 124, 116), 5)
        iris.ell(786, 196, 50, 50, None, (56, 76, 76), 2)
        iris.rect(738, 189, 834, 203, (6, 10, 12), None, r=7)              # a horizontal slot pupil
        lay.put(iris, 1.0, mask=eye.alpha())
        lay.line(lower, (204, 220, 210), 7)                                # the wet lower rim
        lay.line(lower, lid_dark, 2.4)
        lay.line(upper, lid_dark, 5)                                       # the upper lid's edge
        lay.line([(x, y - 9) for x, y in upper], (40, 54, 60), 2)          # its crease
        glass = Pen(W, H, rng)
        glass.rect(gx0, gy0, gx1, gy1, (255, 255, 255), None)
        clip = p.layer()
        clip.put(lay, 1.0, mask=glass.alpha())
        lay = clip
    p.put(lay)
    if stage != 7:
        gl = p.layer()  # two dry glints: glass, not paint
        for (x, y) in ((600, 140), (752, 228)):
            gl.line([(x, y + 26), (x + 26, y)], (226, 232, 228), 3)
            gl.line([(x + 10, y + 26), (x + 26, y + 10)], (226, 232, 228), 1.6)
        p.put(gl, 0.35)
    else:
        gl = p.layer()  # the pane in front of it: one faint reflected glint
        gl.line([(600, 166), (626, 140)], (190, 204, 200), 2)
        p.put(gl, 0.3)


def paint_view_a(rng, stage=0):
    p = Pen(W, H, rng, WALL_A)
    srng = rng_for(700)     # stage-only marks draw from their own stream: the base never shifts
    sever = stage == "sever"
    lamp_on = stage not in (7, "sever")
    chair_out = stage in (4, 6, 7)
    wet = stage in (2, 4, 6, 7)
    # wall: grey-teal tongue-and-groove from the ceiling to the dado, with long plank grain
    planks_v(p, rng, -4, W + 4, -4, 470, WALL_A, WALL_A_SEAM, WALL_A_HI)
    plank_grain(p, rng, -4, W + 4, 20, 466, 48, mix(WALL_A, INK, 0.12))
    p.rect(-4, -4, W + 4, 16, SEAGLASS_DK, INK, 2.4)              # ceiling batten
    # high window
    p.rect(548, 98, 912, 110, SEAGLASS_DK, INK, 2.6)              # head trim
    p.line([(552, 100.5), (908, 100.5)], SEAGLASS_HI, 1.4)
    p.rect(560, 110, 900, 300, STORM, INK, 3)                     # frame
    paint_window(p, rng_for(701), stage)
    p.rect(*GLASS, None, INK, 3)
    p.rect(MULL_X - 5, GLASS[1], MULL_X + 5, GLASS[3], STORM, INK, 2.2)
    p.rect(GLASS[0], MULL_Y - 5, GLASS[2], MULL_Y + 5, STORM, INK, 2.2)
    p.line([(566, 116), (894, 116)], STORM_HI, 1.6)
    p.rect(544, 296, 916, 312, SEAGLASS_DK, INK, 2.6)            # sill
    p.line([(548, 299), (912, 299)], SEAGLASS_HI, 1.6)
    p.rect(556, 312, 904, 318, mix(SEAGLASS, INK, 0.3), None)
    # damp (bands 2+): the patch under the sill keeps its tide edge; the dado only blooms, no line
    if wet:
        sill_len = {2: 46, 4: 76, 6: 104, 7: 112}[stage]
        stain(p, srng, 566, 894, 318 + sill_len * 0.4, 318, 6, mix(WALL_A, STORM, 0.35), 0.55,
              tongues=4, tongue_len=sill_len)
        bloom = p.layer()
        up = {2: 30, 4: 46, 6: 60, 7: 64}[stage]
        bloom.rect(-4, 470 - up, W + 4, 470, mix(WALL_A, STORM, 0.45), None)
        p.put_soft(bloom, 12, 0.5)
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
        soft_shadow(p, x + 28, 448, 18, 5, 0.25, 3)
        mug(p, x, 410)
        peg(p, x, 410)
    # the pendant over the table's centre; its cord runs down the window mullion
    pendant(p, PENDANT_A[0], PENDANT_A[1], PENDANT_A[2], PENDANT_A[3], lamp_on)
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
    plank_grain(p, rng, -4, W + 4, 512, 842, 60, mix(TIMBER, TIMBER_XD, 0.35))
    p.rect(-4, 852, W + 4, 882, TIMBER_DK, INK, 2.6)              # skirting
    p.line([(-4, 855), (W + 4, 855)], TIMBER, 1.4)
    floorboards(p, rng, 880)
    if stage in (4, 6, 7):
        # the tide line: one straight salt crest at the station height, as in the office
        salt_line(p, rng_for(703), -4, 1340, STATION_Y, 880, {4: 0.36, 6: 0.46, 7: 0.52}[stage])
    # kitchen doorway at the right edge
    p.rect(1340, 120, W + 4, 880, TIMBER_DK, INK, 3)
    p.rect(1374, 150, W + 4, 880, (30, 34, 38), INK, 2.6)
    p.rect(1374, 760, W + 4, 880, (40, 42, 44), None)             # the kitchen floor beyond
    p.line([(1374, 760), (W + 4, 760)], (52, 54, 54), 2)
    p.rect(1336, 112, W + 4, 150, TIMBER, INK, 2.6)              # lintel
    p.line([(1340, 115), (W + 4, 115)], TIMBER_HI, 1.4)
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
    soft_shadow(p, 92, 884, 84, 8, 0.45, 5)
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
    # under the table: the cloth's shadow on the panelling, the bench and its eight pads
    us = p.layer()
    us.rect(150, 700, 1350, 880, (20, 24, 28), None)
    p.put_soft(us, 14, 0.38)
    for x in (300, 724, 1150):                                    # bench legs
        p.rect(x - 7, 760, x + 7, 880, TIMBER_DK, INK, 2.2)
    p.rect(266, 748, 1176, 760, TIMBER, INK, 2.4)
    p.line([(270, 750.5), (1172, 750.5)], TIMBER_HI, 1.4)
    for x in PLACE_X[:8]:
        bench_cushion(p, x)
    # floor shadow under the table and benches
    soft_shadow(p, 750, 888, 640, 18, 0.55, 8)
    # water under place 9: it grows with the bands, out under his chair once it is pulled out
    if wet:
        pr = {2: 46, 4: 70, 6: 84, 7: 92}[stage]
        puddle(p, PLACE_X[8] + (14 if chair_out else 0), 900, pr)
        if chair_out:
            puddle(p, 1268, 912, 40, 0.9)
    # legs
    for x in (190, 760, 1310):
        p.rect(x - 14, 696, x + 14, 880, NAVY_BROWN, INK, 2.6)
        p.line([(x - 8, 700), (x - 8, 874)], (78, 74, 72), 1.6)
        p.line([(x + 9, 700), (x + 9, 874)], (34, 32, 34), 1.4)
    # the cloth: tabletop edge at y 590, a hanging hem with folds that drops at each leg
    hem = hem_pts(160, 1340, 702, (190, 760, 1310), rng)
    cloth = [(160, 586), (1340, 586)] + hem[::-1]
    p.poly(cloth, PAPER_HI, None)
    for fx in (236, 300, 420, 540, 640, 700, 830, 900, 1000, 1120, 1180, 1270):
        cloth_fold(p, fx + rng.uniform(-6, 6), 600, 702 + 15 * math.exp(-((fx - 760) / 46) ** 2), 2, 12)
    p.line([(164, 589.5), (1336, 589.5)], (248, 244, 234), 2)    # lit top edge
    p.poly(cloth, None, INK, 2.8)
    p.line([(x, y - 9) for x, y in hem[1:-1]], mix(LINEN_SH, INK, 0.25), 1.2)   # the hem stitch
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
            dent.poly([(1250, 586), (1290, 587.5), (1292, 588), (1300, 584), (1312, 588),
                       (1300, 594), (1290, 591), (1250, 590)], LINEN_SH, None)
            p.put(dent)
            p.line([(1250, 590.5), (1290, 591.5), (1300, 594.5), (1312, 588.5)], mix(LINEN_SH, INK, 0.35), 1.4)
            p.line([(1252, 586), (1290, 587), (1300, 583.5), (1310, 586.5)], (250, 248, 240), 1.2)
    # tally housing on the left drop
    soft_shadow(p, 224, 658, 46, 46, 0.3, 5)
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
    im = mottle(im, rng_for(704), (0, 0, W, 470), 6, 150)
    im = mottle(im, rng_for(705), (0, 488, W, 880), 5, 150)
    # light: the pendant's warm pool on the cloth, falling off to cooler walls and corners
    lit = [(150, 560, 1350, 720)] + ([(1160, 600, 1340, 905)] if chair_out else [])
    cloth_keep = rect_mask(im.size, lit, 255, 0, blur=24)
    if lamp_on:
        im = key_light(im, (740, 600, 700, 400), 0.6, 0.55, keep=cloth_keep.point(lambda v: v * 3 // 4),
                       core=(740, 640, 520, 150))
    elif not sever:
        # band 7: the pendant is dark; the cloth keeps its light, the warm strip is the only warmth
        im = key_light(im, (740, 640, 640, 260), 0.7, 0.0, keep=cloth_keep)
    # stage colour: colder each band; the table and cloth stay readable
    cloth = rect_mask(im.size, [(150, 500, 1350, 720)], 0, 255, blur=10)
    if stage == 2:
        im = tint(im, (204, 218, 232), 0.25)
    elif stage == 4:
        im = tint(im, (190, 208, 228), 0.4)
    elif stage == 6:
        im = tint(im, (176, 196, 222), 0.55, cloth.point(lambda v: max(v, 110)))
    elif stage == 7:
        keep = rect_mask(im.size, [(150, 500, 1350, 720), (1336, 112, W, 960)], 0, 255, blur=10)
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
    p = Pen(W, H, rng, WALL_B)
    srng = rng_for(702)     # stage-only marks draw from their own stream
    lamp_on = stage not in (7, "sever")
    plaster = WALL_B
    p.rect(-4, -4, W + 4, 560, plaster, None)
    lay = p.layer()     # trowel sweeps, faint
    for _ in range(26):
        x, y = rng.uniform(0, W), rng.uniform(40, 540)
        lay.arc(x, y, rng.uniform(60, 140), rng.uniform(8, 16), 200, 340, mix(WALL_B, PAPER_HI, 0.22), 3)
    p.put(lay, 0.45)
    p.rect(-4, -4, W + 4, 16, SEAGLASS_DK, INK, 2.4)
    p.rect(-4, 52, W + 4, 62, SEAGLASS_DK, INK, 2)                # picture rail
    p.line([(-4, 54.5), (W + 4, 54.5)], SEAGLASS_HI, 1.2)
    # damp on the plaster
    if stage in (2, 4, 6, 7):
        up = {2: 70, 4: 120, 6: 150, 7: 150}[stage]
        stain(p, srng, 1300, W + 4, 556 - up, 556, 8, mix(WALL_B, STORM, 0.4), 0.55, tongues=3,
              tongue_len=-up * 0.5)
        stain(p, srng, 620, 940, 60 + up * 0.5, 62, 6, mix(WALL_B, STORM, 0.35), 0.45, tongues=3,
              tongue_len=up * 0.6)
    if stage in (4, 6, 7):
        stain(p, srng, -4, 140, 300, 62, 7, mix(WALL_B, STORM, 0.35), 0.45, tongues=2, tongue_len=60)
        stain(p, srng, 600, 960, 470, 556, 6, mix(WALL_B, STORM, 0.35), 0.45, tongues=3, tongue_len=-50)
    if stage in (6, 7):
        stain(p, srng, -4, W + 4, 512, 556, 4, mix(WALL_B, STORM, 0.5), 0.6, tongues=8, tongue_len=-28)
    # the pendant over the lectern
    pendant(p, PENDANT_B[0], PENDANT_B[1], PENDANT_B[2], PENDANT_B[3], lamp_on)
    # dado and timber below
    p.rect(-4, 552, W + 4, 572, TIMBER, INK, 2.6)
    p.line([(-4, 555), (W + 4, 555)], BRASS_HI, 2)
    p.line([(-4, 569), (W + 4, 569)], BRASS, 2)
    planks_v(p, rng, -4, W + 4, 572, 880, TIMBER, TIMBER_XD, TIMBER_HI, 64)
    plank_grain(p, rng, -4, W + 4, 580, 846, 64, mix(TIMBER, TIMBER_XD, 0.35))
    p.rect(-4, 852, W + 4, 882, TIMBER_DK, INK, 2.6)
    floorboards(p, rng, 880)
    # cast shadows: the range, the lectern and the dresser stand on the boards
    soft_shadow(p, 372, 888, 236, 16, 0.6, 8)
    soft_shadow(p, 806, 884, 96, 10, 0.55, 6)
    soft_shadow(p, 1134, 886, 186, 14, 0.55, 8)
    wsh = p.layer()     # and on the wall behind them, falling right, away from the lamp
    wsh.rect(584, 450, 600, 860, (20, 24, 28), None)
    wsh.rect(842, 620, 860, 862, (20, 24, 28), None)
    p.put_soft(wsh, 8, 0.35)
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
    p.line([(176, 452), (564, 452)], SOOT_HI, 2)                  # bevel highlights
    p.line([(176, 452), (176, 852)], (58, 60, 62), 2)
    p.line([(164, 435), (576, 435)], (96, 98, 100), 1.4)
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
    p.line([(972, 600), (972, 856)], TIMBER_HI, 1.6)
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
    im = mottle(im, rng_for(706), (0, 0, W, 552), 6, 150)
    if lamp_on:
        im = key_light(im, (780, 600, 720, 470), 0.62, 0.5, core=(790, 590, 300, 190))
    elif stage == 7:
        rk = Image.new("L", im.size, 0)
        ImageDraw.Draw(rk).ellipse((60, 400, 700, 1060), fill=255)
        im = key_light(im, (800, 640, 560, 320), 0.74, 0.0, keep=rk.filter(ImageFilter.GaussianBlur(60)))
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
    drop_shadow(p, 100, 150, 1350, 580, 12, 0.45, 10)
    p.rect(100, 150, 1350, 580, PAPER_HI, INK, 3)
    lay = p.layer()     # linen weave, both ways, and a few slubs
    for y in range(156, 576, 5):
        lay.line([(104, y), (1346, y)], LINEN_SH, 1)
    for x in range(104, 1346, 5):
        lay.line([(x, 154), (x, 576)], mix(LINEN_SH, PAPER_HI, 0.4), 1)
    for _ in range(40):
        x, y = rng.uniform(110, 1330), rng.uniform(160, 570)
        lay.line([(x, y), (x + rng.uniform(12, 30), y)], mix(LINEN_SH, INK, 0.15), 1.2)
    p.put(lay, 0.5)
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
    drop_shadow(p, 100, 620, 1120, 810, 12, 0.5, 9)
    p.rect(100, 620, 1120, 810, TIMBER, INK, 3, r=6)
    p.line([(108, 626), (1112, 626)], TIMBER_HI, 1.8)
    for k in range(9):
        cx = 162 + 112 * k
        p.ell(cx, 715, 50, 50, TIMBER_HI, INK, 2.2)
        p.ell(cx, 715, 46, 46, TIMBER_XD, INK, 2.4)
        p.arc(cx, 715, 42, 42, 200, 340, (36, 32, 28), 5)
        p.ell(cx, 715, 22, 22, None, mix(TIMBER_XD, TIMBER, 0.4), 1.4)
    # tally housing
    drop_shadow(p, 1130, 600, 1300, 924, 12, 0.5, 9)
    drop_shadow(p, 1300, 600, 1430, 912, 12, 0.5, 9)
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
    drop_shadow(p, 40, 120, 270, 900, 12, 0.5, 9)
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
    drop_shadow(p, 300, 722, 1060, 834, 10, 0.5, 8)
    p.rect(300, 722, 1060, 834, SOOT, INK, 2.8, r=4)
    for (x0, x1) in ((320, 470), (490, 820), (840, 1050)):
        recess(p, x0, 730, x1, 826, 4, (30, 34, 38))
    # placard
    drop_shadow(p, 300, 850, 1060, 960, 10, 0.5, 8)
    p.rect(300, 850, 1060, 960, ENAMEL, INK, 2.8, r=6)
    p.rect(310, 860, 1050, 950, None, STORM, 2, r=4)
    for x in (318, 1042):
        rivet(p, x, 905, 3.4, BRASS_HI)
    # token socket
    drop_shadow(p, 1090, 120, 1420, 440, 12, 0.5, 9)
    drop_shadow(p, 1090, 470, 1420, 670, 12, 0.5, 9)
    drop_shadow(p, 1110, 676, 1400, 856, 12, 0.5, 9)
    drop_shadow(p, 1090, 870, 1420, 960, 10, 0.5, 8)
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
    clear = Image.new("L", p.im.size, 255)          # the initials' band in each well stays dry
    d = ImageDraw.Draw(clear)
    for (cx, cy) in BOWL_PLAN[:8]:
        d.rectangle(((cx - 44) * SS, (cy + 6) * SS, (cx + 44) * SS, (cy + 34) * SS), fill=0)
    p.im.putalpha(ImageChops.multiply(p.im.getchannel("A"), clear))
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


def paint_fog(rng, w, h, wipe=None, thin=False):
    p = Pen(w, h, rng)
    fog(p, rng, 2, 2, w - 2, h - 2, wipe)
    if thin:
        # breath on glass, not frosted glass: patchy, so the board's strips show through
        n = value_noise(rng_for(710), w * SS, h * SS, 46 * SS).filter(ImageFilter.GaussianBlur(10 * SS))
        n = n.point(lambda v: int(70 + 120 * max(0.0, min(1.0, (v - 70) / 120.0))))
        p.im.putalpha(ImageChops.multiply(p.im.getchannel("A"), n))
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


# ----------------------------------------------------------------------------- repaint-pass sprites

TARNISH = (70, 76, 78)
TARNISH_HI = (128, 136, 134)
SOUP_DK = (88, 64, 40)
WET = (60, 82, 88)


def paint_a_spoon2(rng, used=False):
    """His spoon, side-on, big and dark enough to read lifting: tarnished steel, 64 px long.
    Rests on y 22 of a 70x28 box. `used`: soup on its bowl."""
    p = Pen(70, 28, rng)
    x0, x1, yr = 2, 66, 22
    hx = x1 - 22
    p.poly([(x0, yr - 7), (x0 + 8, yr - 9), (hx, yr - 5), (hx, yr - 1), (x0 + 8, yr - 3.5), (x0, yr - 2)],
           TARNISH, INK, 2.2)
    p.poly(bezier((hx - 2, yr), (hx + 10, yr - 18), (x1, yr), 12), TARNISH, INK, 2.4)
    p.line([(x0 + 9, yr - 7), (hx - 4, yr - 4)], TARNISH_HI, 1.4)
    p.line([(hx + 5, yr - 8), (hx + 12, yr - 11)], (196, 204, 200), 2)
    if used:
        p.poly(bezier((hx + 2, yr - 1), (hx + 10, yr - 10), (x1 - 2, yr - 1), 10), SOUP_DK, None)
        p.ell(hx + 15, yr + 2, 2.6, 2.2, SOUP_DK, None)
    return p


def paint_a_soup2(rng):
    """The ninth bowl after band 3: a thick dark soup tide ring under the rim, one drip down the
    outside, over the tabletop edge and down the cloth. Bowl box at (0,0); 104x100."""
    p = Pen(104, 100, rng)
    m = Pen(104, 100, rng)
    m.poly(bezier((93, 16), (90, 50), (66, 55), 16) + bezier((30, 55), (6, 50), (3, 16), 16), (255, 255, 255), None)
    ring = p.layer()
    ring.rect(0, 18, 100, 28, SOUP_DK, None)
    ring.line([(0, 28.5), (100, 28.5)], mix(SOUP_DK, ENAMEL, 0.45), 2)
    ring.line([(0, 18), (100, 18)], (60, 42, 26), 1.6)
    p.put(ring, 1.0, mask=m.alpha())
    # the drip: over the lip, down the side, off the foot, down the cloth's drop
    drip = [(84, 15), (89, 26), (88, 38), (83, 49), (76, 56), (74, 62), (76, 66), (77, 78), (77, 86)]
    p.line(drip, SOUP_DK, 4.2)
    p.ell(77, 89, 3.6, 4.4, SOUP_DK, None)
    p.ell(72, 64.5, 9, 2.2, SOUP_DK, None)        # where it met the tabletop edge
    p.line([(86, 24), (85, 36)], mix(SOUP_DK, ENAMEL, 0.6), 1.2)
    return p


def paint_a_chair_out2(rng):
    """His chair, pulled straight back from place 9 and left standing, turned slightly toward
    the table. A stark flat silhouette with a wet seat. 170x292; seat top at y 150."""
    p = Pen(170, 292, rng)
    sh = p.layer()
    sh.ell(88, 284, 82, 7, INK, None)
    p.put_soft(sh, 4, 0.5)
    body = TIMBER_XD
    edge = TIMBER
    # rear leg + back post (right), front leg (left), stretchers
    p.poly([(132, 10), (148, 8), (154, 286), (140, 286)], body, INK, 2.8)
    p.rect(18, 166, 32, 286, body, INK, 2.8)
    p.rect(30, 226, 144, 236, body, INK, 2.2)
    # the back: the crest rail turned a little toward us, three spindles
    p.poly([(106, 6), (156, 2), (160, 28), (110, 32)], body, INK, 2.6)
    p.line([(112, 10), (152, 7)], edge, 1.6)
    for x in (118, 128, 138):
        p.rect(x, 30, x + 5, 150, body, INK, 1.8)
    p.rect(108, 86, 150, 94, body, INK, 1.8)
    # the seat: a thick edge with its top plane just visible, wet
    p.poly([(10, 146), (156, 140), (158, 150), (12, 156)], mix(body, (40, 48, 54), 0.5), INK, 2.2)
    p.rect(8, 152, 160, 170, body, INK, 2.8)
    p.line([(12, 155.5), (156, 155.5)], edge, 1.6)
    wet = p.layer()
    wet.poly([(26, 147), (138, 142), (140, 149), (28, 153)], (34, 46, 54), None)
    p.put(wet, 0.9)
    p.line([(40, 146.5), (110, 143.5)], (200, 214, 210), 1.6)            # a wet sheen on the seat
    for x, ln in ((36, 26), (70, 40), (118, 18)):                       # running off the front edge
        p.line([(x, 170), (x + 0.6, 170 + ln)], WET, 3.2)
        p.line([(x - 0.8, 172), (x - 0.4, 166 + ln)], (176, 196, 196), 1)
        p.ell(x + 0.6, 173 + ln, 3.2, 4, WET, None)
        p.ell(x - 0.4, 172 + ln, 1.1, 1.3, (214, 226, 224), None)
    p.line([(21, 172), (21, 280)], edge, 1.4)
    return p


def paint_a_seat9(rng, wet=False):
    """Under the table at place 9: his chair's seat, bare where the bench has pads. 100x142;
    seat top at y 8 (world 748)."""
    p = Pen(100, 142, rng)
    for x in (12, 80):
        p.rect(x, 18, x + 10, 140, TIMBER_XD, INK, 2.2)
    p.rect(12, 92, 90, 100, TIMBER_XD, INK, 1.8)
    p.rect(4, 8, 96, 20, mix(TIMBER, TIMBER_DK, 0.4), INK, 2.4)
    p.line([(8, 10.5), (92, 10.5)], TIMBER, 1.4)
    if wet:
        w = p.layer()
        w.rect(10, 7, 90, 19, (34, 46, 54), None)
        p.put(w, 0.9)
        p.line([(18, 9.5), (62, 9.5)], (196, 210, 206), 1.6)
        for x, ln in ((24, 30), (52, 52), (78, 22)):
            p.line([(x, 20), (x, 20 + ln)], WET, 3)
            p.ell(x, 23 + ln, 3, 3.8, WET, None)
            p.ell(x - 0.6, 22 + ln, 1, 1.2, (214, 226, 224), None)
    return p


def paint_a_towel_wet(rng):
    """Band 6: Nora's towel refolded the other way - in halves, its stripes now running along the
    folds (turned 90 degrees), wet through, with a drip line over the table edge. 84x100; the towel
    sits on the tabletop at y 68."""
    p = Pen(84, 100, rng)
    layers = [(40, 68), (12, 41)]
    for k, (y0, y1) in enumerate(layers):
        r = (y1 - y0) / 2
        p.rect(4, y0, 78 - r, y1, PAPER_HI, None)
        p.ell(78 - r, (y0 + y1) / 2, r, r, PAPER_HI, None)
        for yy in (y0 + 6, y0 + 10, y1 - 10, y1 - 6):                 # stripes along the fold
            p.line([(6, yy), (76 - r * 0.4, yy)], SEAGLASS, 2.2)
    m = p.layer()
    m.im.alpha_composite(p.im)
    wet = p.layer()
    for (x, y, rx, ry) in ((30, 52, 30, 16), (52, 30, 28, 14), (16, 26, 14, 10), (62, 58, 16, 12)):
        wet.ell(x, y, rx, ry, WET, None)
    wet.im = wet.im.filter(ImageFilter.GaussianBlur(2.5 * SS))
    p.put(wet, 0.88, mask=m.alpha())
    for k, (y0, y1) in enumerate(layers):
        r = (y1 - y0) / 2
        p.line([(4, y0), (78 - r, y0)], INK, 2.4)
        p.arc(78 - r, (y0 + y1) / 2, r, r, 270, 450, INK, 2.4)
        p.line([(78 - r, y1), (4, y1)], INK, 2.4)
        p.line([(4, y0), (4, y1)], INK, 1.6)
    p.line([(8, 14.5), (60, 14.5)], (246, 242, 230), 1.4)               # the dry top fold edge
    drip = [(60, 68), (61, 76), (60, 86), (60.5, 94)]
    p.line(drip, (176, 196, 196), 2.2)
    p.ell(60.5, 96, 2.4, 3, (176, 196, 196), None)
    return p


def paint_a_ring_amber(rng):
    """The continue ending: the ring where her cup stood, warm. 64x24; centre (32, 12)."""
    p = Pen(64, 24, rng)
    g = p.layer()
    g.ell(32, 12, 28, 9, AMBER, None)
    p.put_soft(g, 3, 0.75)
    p.ell(32, 12, 22, 6, None, mix(AMBER, (120, 60, 20), 0.35), 3.4)
    p.ell(32, 12, 22, 6, None, (238, 200, 130), 1.4)
    return p


def paint_a_ring_wisp(rng):
    """Motion off: the warm ring and its steam as one still ribbon, ~84 px tall. 64x112;
    the ring's centre at (32, 100)."""
    p = Pen(64, 112, rng)
    g = p.layer()
    g.ell(32, 100, 28, 9, AMBER, None)
    p.put_soft(g, 3, 0.75)
    p.ell(32, 100, 22, 6, None, mix(AMBER, (120, 60, 20), 0.35), 3.4)
    p.ell(32, 100, 22, 6, None, (238, 200, 130), 1.4)
    pts = [(32 + 9 * math.sin(i * 0.19) * (0.3 + i / 40), 96 - i * 2.1) for i in range(41)]
    for w, a in ((12, 0.14), (7, 0.22), (3.2, 0.42)):
        lay = p.layer()
        lay.line(pts, (240, 236, 226), w)
        lay.im = lay.im.filter(ImageFilter.GaussianBlur(1.2 * SS))
        fade = Image.linear_gradient("L").resize(lay.im.size).point(lambda v: min(255, int(v * 1.6)))
        p.put(lay, min(1.0, a * 2), mask=fade)
    return p


def paint_a_wet(rng, band):
    """Bands 2-7: the cloth darkening wet from places 1-8 toward place 9, growing each band and
    pooling round the square; beads gathered on the side of each bowl nearest him (kept above
    the initials). Full frame; the place patches stay dry so every mark reads."""
    f = (band - 1) / 6.0
    p = Pen(W, H, rng)
    x9 = PLACE_X[8]
    wet = p.layer()
    for i, x in enumerate(PLACE_X[:8]):
        x_a = x - 26
        x_b = x + 40 + f * (x9 - x - 40)
        th = 5 + 11 * f
        wet.poly([(x_a, 598 - th * 0.3), (x_b, 597), (x_b + 10, 600 + th * 0.4), (x_b, 602 + th * 0.6),
                  (x_a, 602 + th * 0.4)], (84, 104, 112), None)
    if f > 0.6:      # the streaks have run together into one wet band along the cloth
        wet.rect(PLACE_X[0], 596, x9, 606 + 8 * f, (84, 104, 112), None)
    rx, ry = 40 + 46 * f, 26 + 30 * f
    wet.ell(x9, 652, rx, ry, (94, 114, 120), None)
    if band >= 5:
        for dx in (-30, 6, 34):
            wet.line([(x9 + dx, 652 + ry * 0.6), (x9 + dx, 704 + 6 * f)], (94, 114, 120), 3)
    wet.im = wet.im.filter(ImageFilter.GaussianBlur(3 * SS))
    keep = Image.new("L", wet.im.size, 0)
    d = ImageDraw.Draw(keep)
    d.polygon([(160 * SS, 592 * SS), (1340 * SS, 592 * SS), (1340 * SS, 712 * SS), (160 * SS, 712 * SS)], fill=255)
    for x in PLACE_X:                                    # the patches stay dry
        d.rectangle(((x - 48) * SS, 614 * SS, (x + 48) * SS, 682 * SS), fill=0)
    p.put(wet, 0.55 + 0.3 * f, mask=keep)
    edge = p.layer()                                     # the pool's tide edge round the square
    edge.ell(x9, 652, rx, ry, None, (70, 90, 96), 1.6)
    p.put(edge, 0.6, mask=keep)
    beads = p.layer()
    for i, x in enumerate(PLACE_X[:8]):
        for _ in range(3 + int(round(5 * f))):
            bx = x + rng.uniform(8, 40)
            by = rng.uniform(528, 546)
            bead(beads, bx, by, rng.uniform(1.8, 2.8))
    p.put(beads)
    return p


def paint_rain_hang2(rng):
    """Bands 3-6: rain hanging on the glass and not falling. Few, fat, still drops."""
    p = Pen(340, 190, rng)
    gx0, gy0, gx1, gy1 = GLASS[0] - 560, GLASS[1] - 110, GLASS[2] - 560, GLASS[3] - 110
    mask = Pen(340, 190, rng)
    mask.rect(gx0, gy0, gx1, gy1, (255, 255, 255), None)
    lay = p.layer()

    def drop(x, y, s):
        pts = [(x, y)] + bezier((x + 0.2 * s, y + 0.5 * s), (x + 1.1 * s, y + 1.9 * s), (x, y + 2.2 * s), 10)[1:] + \
            bezier((x, y + 2.2 * s), (x - 1.1 * s, y + 1.9 * s), (x - 0.2 * s, y + 0.5 * s), 10)[1:]
        lay.poly(pts, (214, 228, 226), (36, 56, 64), 1.6)
        lay.ell(x - 0.3 * s, y + 1.45 * s, 0.22 * s, 0.3 * s, (255, 255, 255), None)
    for x in (34, 82, 128, 196, 246, 300):
        drop(x + rng.uniform(-6, 6), MULL_Y - 110 + 5, rng.uniform(7, 9))
    for x in (58, 150, 222, 282):
        drop(x + rng.uniform(-6, 6), gy1 - 1 - 18, rng.uniform(6, 8))
    for _ in range(4):
        drop(rng.uniform(gx0 + 20, gx1 - 20), rng.uniform(gy0 + 10, gy0 + 60), rng.uniform(5, 7))
    p.put(lay, 1.0, mask=mask.alpha())
    return p


def paint_b_board_back(rng):
    """After P09: the official board swung open on its right-hand hinge, its back to us, compressed
    as it stands out from the wall; the cavity's frame edge beside it. 180x400 at (782, 130)."""
    p = Pen(180, 400, rng)
    sh = p.layer()
    sh.rect(4, 20, 150, 396, INK, None)
    p.put_soft(sh, 8, 0.3)
    p.rect(10, 10, 162, 390, TIMBER_DK, INK, 2.8)
    for x in (48, 86, 124):
        p.line([(x, 14), (x, 386)], TIMBER_XD, 2.2)
        p.line([(x + 3, 14), (x + 3, 386)], TIMBER, 1.2)
    for y in (60, 330):                                    # battens
        p.rect(14, y - 12, 158, y + 12, TIMBER, INK, 2.2)
        p.line([(18, y - 9), (154, y - 9)], TIMBER_HI, 1.4)
    p.poly([(16, 330), (30, 330), (156, 70), (142, 60)], TIMBER, INK, 2)   # the brace
    for y in (40, 360):                                    # strap hinges to the frame
        p.rect(110, y - 7, 176, y + 7, SOOT_HI, INK, 2, r=2)
        p.ell(174, y, 5, 9, BRASS_LO, INK, 1.6)
    p.rect(162, 6, 176, 394, TIMBER, INK, 2.4)             # its edge, the board's thickness
    p.line([(165, 10), (165, 390)], TIMBER_HI, 1.4)
    return p


def paint_b_book_blank(rng):
    """Band 5+: Nora's book has turned itself to a fresh ruled page; one leaf still stands up off
    the spine. One pencil line. Drawn over the lectern book at (690, 468); 220x136."""
    p = Pen(220, 136, rng)
    ox, oy = 690, 468
    def T(pts):
        return [(x - ox, y - oy) for x, y in pts]
    lp = bezier((706, 590), (704, 530), (742, 528), 10) + bezier((742, 528), (780, 528), (800, 548), 10) + [(800, 590)]
    rp = [(800, 590), (800, 548)] + bezier((800, 548), (820, 528), (858, 528), 10) + bezier((858, 528), (896, 530), (894, 590), 10)
    p.poly(T(lp), PAPER_HI, INK, 2.2)
    p.poly(T(rp), PAPER_HI, INK, 2.2)
    rules = p.layer()
    for k in range(5):
        y = 548 + k * 9
        rules.line(T([(712, y + 4), (796, y)]), SEAGLASS_HI, 1.4)
        rules.line(T([(806, y), (888, y + 4)]), SEAGLASS_HI, 1.4)
    p.put(rules, 0.9)
    p.line(T([(812, 556), (852, 556.5)]), GRAPHITE, 1.8)                 # one pencil line
    leaf = bezier((800, 548), (790, 500), (806, 476), 12) + bezier((806, 476), (836, 488), (842, 540), 12)[1:] + [(800, 562)]
    p.poly(T(leaf), PAPER, INK, 2.2)
    p.line(T(bezier((804, 540), (800, 506), (810, 486), 8)), PAPER_LO, 1.2)
    p.poly(T([(796, 546), (804, 546), (806, 640 - 40), (800, 592), (794, 600)]), SEAGLASS, INK, 1.6)
    return p


def frame_dark(p, inner, op, blur=60):
    """Darken a close-up's surround: everything outside `inner` falls toward damp shadow."""
    lay = p.layer()
    lay.rect(-10, -10, p.w + 10, p.h + 10, (14, 18, 22), None)
    hole = p.layer()
    hole.rect(*inner, (255, 255, 255), None, r=30)
    hole.im = hole.im.filter(ImageFilter.GaussianBlur(blur * SS))
    a = ImageChops.subtract(lay.im.getchannel("A"), hole.im.getchannel("A"))
    lay.im.putalpha(a)
    p.put(lay, op)


def paint_c_table_damp(rng):
    p = Pen(W, H, rng)
    frame_dark(p, (130, 170, 1320, 940), 0.55)
    ring = p.layer()                                       # a water ring on the cloth at place 9
    ring.ell(1276, 352, 68, 64, None, (120, 132, 128), 6)
    ring.ell(1276, 352, 64, 60, None, (164, 170, 160), 2)
    p.put(ring, 0.8)
    st = p.layer()
    for _ in range(9):                                     # damp creeping in at the cloth's edge
        x = rng.uniform(110, 1340)
        st.ell(x, rng.choice((154, 576)), rng.uniform(30, 70), rng.uniform(8, 16), (120, 136, 136), None)
    st.im = st.im.filter(ImageFilter.GaussianBlur(5 * SS))
    p.put(st, 0.55)
    return p


def paint_c_ledger_damp(rng):
    p = Pen(W, H, rng)
    frame_dark(p, (120, 96, 1328, 916), 0.55)
    fox = p.layer()
    spots = []
    for _ in range(70):     # foxing on the outer margins and the head and foot, clear of the text
        side = rng.random()
        if side < 0.3:
            x, y = rng.uniform(152, 178), rng.uniform(112, 878)
        elif side < 0.6:
            x, y = rng.uniform(1272, 1296), rng.uniform(112, 878)
        elif side < 0.8:
            x, y = rng.uniform(152, 1296), rng.uniform(112, 150)
        else:
            x, y = rng.uniform(152, 1296), rng.uniform(866, 878)
        spots.append((x, y))
        fox.ell(x, y, rng.uniform(1.6, 4.6), rng.uniform(1.4, 3.8), (150, 112, 70), None)
    p.put(fox, 0.75)
    tide = p.layer()        # the page foot has taken water: a pale brown tide edge
    tide.rect(150, 862, 1298, 880, (170, 140, 96), None)
    tide.im = tide.im.filter(ImageFilter.GaussianBlur(3 * SS))
    p.put(tide, 0.45)
    return p


def paint_c_board_damp(rng):
    p = Pen(W, H, rng)
    frame_dark(p, (40, 100, 1420, 960), 0.5)
    st = p.layer()
    st.rect(0, 990, W, H, (20, 26, 30), None)
    for _ in range(12):
        x = rng.uniform(0, W)
        st.line([(x, 960), (x, rng.uniform(1000, 1086))], (20, 26, 30), rng.uniform(4, 10))
    st.im = st.im.filter(ImageFilter.GaussianBlur(6 * SS))
    p.put(st, 0.5)
    return p


# ----------------------------------------------------------------------------- registry


# ----------------------------------------------------------------------------- fix pass w2 (new files only)

PLACE10_A = (218, 772)          # view A: the stool seat's top centre at the rack end (place_10)
PLACE10_C = (186, 470)          # c_table: the place-10 mat's bowl centre, near side at the rack end


def paint_a_place10(rng):
    """View A, full frame: place_10, a second blank place at the rack end. A plain stool pulled
    up under the end of the cloth, a blank stitched napkin laid square on its seat: a place set
    for nobody, with no spoon and no dent. Seat top at PLACE10_A."""
    p = Pen(W, H, rng)
    cx, top = PLACE10_A
    sh = p.layer()
    sh.ell(cx, 884, 54, 6, INK, None)
    p.put_soft(sh, 4, 0.5)
    for x in (cx - 40, cx + 30):                                   # two legs, square, timber
        p.rect(x, top + 14, x + 10, 880, TIMBER_XD, INK, 2.4)
    p.rect(cx - 40, 838, cx + 40, 846, TIMBER_XD, INK, 1.8)        # stretcher
    p.rect(cx - 50, top, cx + 50, top + 16, mix(TIMBER, TIMBER_DK, 0.3), INK, 2.6)
    p.line([(cx - 46, top + 3), (cx + 46, top + 3)], TIMBER_HI, 1.4)
    # the napkin: linen laid flat on the seat and hanging over its front edge, a chain-stitched
    # blank field where initials would be
    nap = [(cx - 42, top - 2), (cx + 42, top - 2), (cx + 40, top + 44), (cx + 30, top + 48),
           (cx - 30, top + 48), (cx - 40, top + 44)]
    p.poly(nap, PAPER_HI, INK, 2.2)
    p.line([(cx - 38, top + 1), (cx + 38, top + 1)], (250, 248, 240), 1.4)
    p.rect(cx - 24, top + 14, cx + 24, top + 38, (242, 238, 226), None)
    chain_rect(p, cx - 24, top + 14, cx + 24, top + 38, INK, 7, 1.2)
    return p


def paint_c_place10(rng):
    """c_table, full frame: place_10 on the cloth's near side at the rack end. A laid mat with a
    blank stitched patch, no spoon, no dent; the cloth around it is undisturbed."""
    p = Pen(W, H, rng)
    cx, cy = PLACE10_C
    x0, y0, x1, y1 = cx - 66, 388, cx + 66, 564
    p.rect(x0, y0, x1, y1, (226, 218, 198), None)
    chain_rect(p, x0, y0, x1, y1, mix(INK, SEAGLASS, 0.2), 8, 1.4)
    p.rect(cx - 42, 516, cx + 42, 556, (242, 238, 226), None)
    chain_rect(p, cx - 42, 516, cx + 42, 556)
    return p


def paint_c_door_edge(rng):
    """c_table, full frame: the kitchen doorway past the door end of the cloth (right edge), so
    the plan says which blank place sits by the door. A timber jamb and the dark gap beyond."""
    p = Pen(W, H, rng)
    sh = p.layer()
    sh.rect(1356, 130, 1452, 594, INK, None)
    p.put_soft(sh, 8, 0.35)
    p.rect(1366, 130, 1452, 590, (30, 34, 38), INK, 2.6)           # the opening, seen from above
    p.rect(1362, 130, 1380, 590, TIMBER_DK, INK, 2.4)              # the jamb and threshold
    p.line([(1366, 134), (1366, 586)], TIMBER_HI, 1.4)
    p.rect(1380, 560, 1452, 590, (40, 42, 44), None)
    return p


def paint_a_wet_v2(rng, band):
    """Bands 2-7, full frame: as a_wet_b*, but the clean halo at his place becomes an irregular
    stain: storm navy at alpha 0.3, a darker tide-ring edge, and two drip runs down the hem."""
    f = (band - 1) / 6.0
    p = Pen(W, H, rng)
    x9 = PLACE_X[8]
    wet = p.layer()
    for i, x in enumerate(PLACE_X[:8]):
        x_a = x - 26
        x_b = x + 40 + f * (x9 - x - 40)
        th = 5 + 11 * f
        wet.poly([(x_a, 598 - th * 0.3), (x_b, 597), (x_b + 10, 600 + th * 0.4), (x_b, 602 + th * 0.6),
                  (x_a, 602 + th * 0.4)], (84, 104, 112), None)
    if f > 0.6:
        wet.rect(PLACE_X[0], 596, x9 - 40, 606 + 8 * f, (84, 104, 112), None)
    wet.im = wet.im.filter(ImageFilter.GaussianBlur(3 * SS))
    keep = Image.new("L", wet.im.size, 0)
    d = ImageDraw.Draw(keep)
    d.polygon([(160 * SS, 592 * SS), (1340 * SS, 592 * SS), (1340 * SS, 712 * SS), (160 * SS, 712 * SS)], fill=255)
    for x in PLACE_X[:8]:                                # the named patches stay dry
        d.rectangle(((x - 48) * SS, 614 * SS, (x + 48) * SS, 682 * SS), fill=0)
    p.put(wet, 0.55 + 0.3 * f, mask=keep)
    # his place: an irregular blot with lobes, not an ellipse
    srng = random.Random(SEED + 900 + band)
    rx, ry = 44 + 40 * f, 30 + 26 * f
    cy = 646
    pts = []
    n = 26
    for k in range(n):
        a = 2 * math.pi * k / n
        r = 1.0 + 0.16 * math.sin(3 * a + 0.7) + 0.1 * math.sin(5 * a + 2.1) + srng.uniform(-0.07, 0.07)
        pts.append((x9 + rx * r * math.cos(a), cy + ry * r * math.sin(a)))
    blot = p.layer()
    blot.poly(pts, STORM, None)
    p.put(blot, 0.3, mask=keep)
    ring = p.layer()                                     # the tide-ring: darker, a dried edge
    ring.poly(pts, None, mix(STORM, DARK, 0.5), 3.0)
    inner = [(x9 + (x - x9) * 0.62, cy + (y - cy) * 0.62 + 4) for x, y in pts]
    ring.poly(inner, None, mix(STORM, DARK, 0.3), 1.4)
    p.put(ring, 0.75, mask=keep)
    # two drip runs from the stain down over the hem, ending in beads
    runs = p.layer()
    for dx, ln in ((-0.55, 46 + 30 * f), (0.35, 70 + 40 * f)):
        x = x9 + dx * rx
        y0 = cy + ry * 0.7
        run = [(x + 1.6 * math.sin(t * 0.21), y0 + t) for t in range(0, int(ln), 3)]
        runs.line(run, STORM, 4.0)
        ex, ey = run[-1]
        runs.ell(ex, ey + 3, 4.2, 5.2, STORM, None)
    p.put(runs, 0.55)
    edge = p.layer()
    for dx, ln in ((-0.55, 46 + 30 * f), (0.35, 70 + 40 * f)):
        x = x9 + dx * rx
        y0 = cy + ry * 0.7
        edge.line([(x - 2.2, y0 + 4), (x - 2.0, y0 + ln - 4)], mix(STORM, DARK, 0.5), 1.2)
    p.put(edge, 0.6)
    beads = p.layer()
    for i, x in enumerate(PLACE_X[:8]):
        for _ in range(3 + int(round(5 * f))):
            bead(beads, x + rng.uniform(8, 40), rng.uniform(528, 546), rng.uniform(1.8, 2.8))
    p.put(beads)
    return p


def eye_lids():
    """The b7v2 eye's upper and lower lid curves (shared with R05_view.gd's lid drift)."""
    upper = bezier((GLASS[0] - 120, 214), (730, 96), (GLASS[2] + 120, 214), 40)
    lower = bezier((GLASS[0] - 120, 214), (730, 324), (GLASS[2] + 120, 214), 40)
    return upper, lower


def paint_a_window_eye_b7v2(rng):
    """Band 7, full frame over the window glass: the eye pressed against the pane, made stark.
    A paper-white sclera band with a navy contour, a sea-glass iris ring, a solid storm-navy
    vertical slit pupil, dark lids, and the glazing bars still drawn in front."""
    p = Pen(W, H, rng)
    gx0, gy0, gx1, gy1 = GLASS
    lid_dark = (14, 22, 28)
    lay = p.layer()
    lay.rect(gx0, gy0, gx1, gy1, lid_dark, None)
    upper, lower = eye_lids()
    almond = upper + lower[::-1]
    lay.poly(almond, ENAMEL, None)                                     # paper-white sclera
    clip = Pen(W, H, rng)
    clip.poly(almond, (255, 255, 255), None)
    iris = p.layer()
    cx, cy = 770, 210
    iris.ell(cx, cy, 74, 74, SEAGLASS, None)                           # sea-glass iris ring
    iris.ell(cx, cy, 74, 74, None, INK, 3)
    iris.ell(cx, cy, 52, 52, None, SEAGLASS_DK, 3)
    iris.ell(cx, cy, 30, 30, mix(SEAGLASS_DK, STORM, 0.5), None)
    iris.poly([(cx, cy - 66), (cx + 13, cy - 20), (cx + 14, cy + 20), (cx, cy + 66),
               (cx - 14, cy + 20), (cx - 13, cy - 20)], STORM_LO, None)  # vertical slit pupil
    iris.ell(cx - 30, cy - 28, 7, 5, (236, 244, 240), None)           # one wet highlight
    lay.put(iris, 1.0, mask=clip.alpha())
    lay.poly(almond, None, INK, 3.2)                                   # the sclera's navy contour
    lay.line(upper, lid_dark, 7)
    lay.line(lower, lid_dark, 5)
    lay.line([(x, y - 10) for x, y in upper], (40, 54, 60), 2)        # the lid crease
    glass = Pen(W, H, rng)
    glass.rect(gx0, gy0, gx1, gy1, (255, 255, 255), None)
    out = p.layer()
    out.put(lay, 1.0, mask=glass.alpha())
    p.put(out)
    # the glazing bars and the frame, in front of it (as the plate draws them)
    p.rect(*GLASS, None, INK, 3)
    p.rect(MULL_X - 5, GLASS[1], MULL_X + 5, GLASS[3], STORM, INK, 2.2)
    p.rect(GLASS[0], MULL_Y - 5, GLASS[2], MULL_Y + 5, STORM, INK, 2.2)
    gl = p.layer()
    gl.line([(600, 166), (626, 140)], (190, 204, 200), 2)
    p.put(gl, 0.3)
    return p


def paint_p09_venn_rubbing(rng):
    """Venn's seal, rubbed in graphite on a thin slip pinned to the board frame: a disc of soft
    hatching with a darker rim, and three vertical incised cuts that the graphite skips (pale).
    The slip hangs a degree off square from one brass tack; its lower edge is torn."""
    w, h = 204, 92
    p = Pen(w, h, rng)
    # the slip: torn lower edge, a little shadow on the board behind it
    torn = [(4, 6), (198, 4)]
    x = 198.0
    while x > 4:
        torn.append((x, 82 + rng.uniform(-3.0, 3.0)))
        x -= rng.uniform(7, 13)
    torn.append((4, 83))
    sh = p.layer()
    sh.poly([(px + 4, py + 5) for px, py in torn], fill=DARK, ink=None)
    p.put_soft(sh, 3, opacity=0.45)
    p.poly(torn, fill=PAPER_HI, ink=INK, w=2.2)
    # the rubbing: a hatched graphite disc, its density rising toward the rim
    cx, cy, rad = 50.0, 46.0, 31.0
    rub = p.layer()
    for _ in range(260):
        a = rng.uniform(0, math.tau)
        rr = rad * math.sqrt(rng.uniform(0.0, 1.0))
        x0, y0 = cx + rr * math.cos(a), cy + rr * math.sin(a)
        ln = rng.uniform(4, 9)
        rub.line([(x0 - ln * 0.7, y0 + ln * 0.7), (x0 + ln * 0.7, y0 - ln * 0.7)],
                 col=mix(GRAPHITE, INK, rng.uniform(0.1, 0.5)), w=rng.uniform(0.9, 1.6))
    rub.ell(cx, cy, rad, fill=None, ink=mix(GRAPHITE, INK, 0.55), w=4.0)
    rub.ell(cx, cy, rad - 6, fill=None, ink=mix(GRAPHITE, INK, 0.25), w=1.3)
    mask = Image.new("L", (w * SS, h * SS), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse(((cx - rad - 3) * SS, (cy - rad - 3) * SS, (cx + rad + 3) * SS, (cy + rad + 3) * SS), fill=255)
    # the three cuts: the graphite skips the incisions, so they read as pale paper strokes
    for k in range(3):
        x = cx - 12 + 12 * k + rng.uniform(-0.8, 0.8)
        md.rounded_rectangle(((x - 2.6) * SS, (cy - 18) * SS, (x + 2.6) * SS, (cy + 18) * SS), radius=2 * SS, fill=0)
    p.put(rub, opacity=0.9, mask=mask)
    for k in range(3):
        x = cx - 12 + 12 * k
        p.line([(x - 3.0, cy - 17), (x - 3.0, cy + 17)], col=mix(GRAPHITE, INK, 0.6), w=1.1)
    # the brass tack
    p.ell(102, 9, 5.5, fill=BRASS, ink=INK, w=1.8)
    p.ell(100.5, 7.5, 1.8, fill=BRASS_HI, ink=None)
    return p


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
    ("c_table", 2, lambda r: mottle(paint_c_table(r).done(), rng_for(707), (0, 0, W, H), 7, 120), True, True),
    ("c_ledger", 3, lambda r: mottle(paint_c_ledger(r).done(), rng_for(709), (0, 0, W, H), 5, 120), True, True),
    ("c_board", 4, lambda r: mottle(paint_c_board(r).done(), rng_for(708), (0, 0, W, H), 7, 120), True, True),
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
    ("b_fog", 31, lambda r: paint_fog(r, 340, 380, thin=True), False, False),
    ("b_fog_wiped", 31, lambda r: paint_fog(r, 340, 380, (300, 330), thin=True), False, False),
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
    # repaint pass (art direction on db1d3a5): new files beside the first set
    ("a_spoon_dark", 70, lambda r: paint_a_spoon2(r), False, False),
    ("a_spoon_used", 70, lambda r: paint_a_spoon2(r, True), False, False),
    ("a_soup_ring", 71, paint_a_soup2, False, False),
    ("a_chair_pulled", 72, paint_a_chair_out2, False, False),
    ("a_seat9", 73, lambda r: paint_a_seat9(r), False, False),
    ("a_seat9_wet", 73, lambda r: paint_a_seat9(r, True), False, False),
    ("a_towel_wet", 74, paint_a_towel_wet, False, False),
    ("a_ring_amber", 75, paint_a_ring_amber, False, False),
    ("a_ring_wisp", 76, paint_a_ring_wisp, False, False),
    ("a_wet_b2", 77, lambda r: paint_a_wet(r, 2), False, False),
    ("a_wet_b3", 77, lambda r: paint_a_wet(r, 3), False, False),
    ("a_wet_b4", 77, lambda r: paint_a_wet(r, 4), False, False),
    ("a_wet_b5", 77, lambda r: paint_a_wet(r, 5), False, False),
    ("a_wet_b6", 77, lambda r: paint_a_wet(r, 6), False, False),
    ("a_wet_b7", 77, lambda r: paint_a_wet(r, 7), False, False),
    ("a_rain_still", 78, paint_rain_hang2, False, False),
    ("b_board_back", 79, paint_b_board_back, False, False),
    ("b_book_blank", 80, paint_b_book_blank, False, False),
    ("c_table_damp", 81, paint_c_table_damp, False, False),
    ("c_ledger_damp", 82, paint_c_ledger_damp, False, False),
    ("c_board_damp", 83, paint_c_board_damp, False, False),
    # fix pass w2: P07's second blank place, the door edge, the late stain and the eye
    ("a_place10", 84, paint_a_place10, False, False),
    ("c_place10", 85, paint_c_place10, False, False),
    ("c_door_edge", 86, paint_c_door_edge, False, False),
    ("a_wet_b2v2", 87, lambda r: paint_a_wet_v2(r, 2), False, False),
    ("a_wet_b3v2", 87, lambda r: paint_a_wet_v2(r, 3), False, False),
    ("a_wet_b4v2", 87, lambda r: paint_a_wet_v2(r, 4), False, False),
    ("a_wet_b5v2", 87, lambda r: paint_a_wet_v2(r, 5), False, False),
    ("a_wet_b6v2", 87, lambda r: paint_a_wet_v2(r, 6), False, False),
    ("a_wet_b7v2", 87, lambda r: paint_a_wet_v2(r, 7), False, False),
    ("a_window_eye_b7v2", 88, paint_a_window_eye_b7v2, False, False),
    # fix pass p1: Venn's seal rubbing beside the P09 placard (assets/stages/R05/)
    ("stage:p09_venn_rubbing", 89, paint_p09_venn_rubbing, False, True),
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
