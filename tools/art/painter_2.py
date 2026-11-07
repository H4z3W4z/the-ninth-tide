#!/usr/bin/env python3
"""Painter 2: seeded, deterministic plates for The Ninth Tide (PIL only, no numpy).

Writes ONLY these files (all new, under assets/stages/):
    threshold_figure.png   1448x1086 RGBA  pale too-tall figure in the 7th-8th corridor casing
    photo_drawer.png        528x620  RGB   night photo: Ada's back, a pale figure between her and the glass
    photo_drawer_hand.png   528x620  RGB   as above, its long hand resting on her chair rail
    photo_after.png         528x620  RGB   Ada gone; the figure sits in her chair, head up in the sash
    photo_turned.png        528x620  RGB   Ada turned to face the camera: a blank pale oval, hands on the sill
    palms_glass.png        1448x1086 RGBA  condensation on the lower pane, three long hands wiped clear
    prints_drawer.png      1448x1086 RGBA  narrow four-toed wet prints, puddle to the right pedestal

Every asset is one function with its own random.Random, seeded from SEED and the asset name,
so a second run is byte-identical. Run:  python3 tools/art/painter_2.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SEED = 20261106
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "stages"
CANVAS = (1448, 1086)
NAVY_INK = (23, 43, 54)


def rng_for(name: str) -> random.Random:
    return random.Random(f"{SEED}:{name}")   # str seeds hash via sha512: stable across runs


# ---------------------------------------------------------------------------
# shared helpers (luminance painting)
# ---------------------------------------------------------------------------
def lut(fn):
    return [max(0, min(255, int(round(fn(v))))) for v in range(256)]


def solid(size, value, mode="L"):
    return Image.new(mode, size, value)


def radial(size, center, rx, ry, inner, outer, gamma=1.0):
    """L image: `inner` at center easing to `outer` at the ellipse (rx, ry) and beyond."""
    g = Image.radial_gradient("L").resize((max(2, int(2 * rx)), max(2, int(2 * ry))), Image.BILINEAR)
    canvas = Image.new("L", size, 255)
    canvas.paste(g, (int(center[0] - rx), int(center[1] - ry)))
    return canvas.point(lut(lambda v: outer + (inner - outer) * (1.0 - v / 255.0) ** gamma))


def vgrad(size, top, bottom):
    g = Image.linear_gradient("L").resize(size, Image.BILINEAR)
    return g.point(lut(lambda v: top + (bottom - top) * v / 255.0))


def hgrad(size, left, right):
    return vgrad((size[1], size[0]), left, right).transpose(Image.Transpose.ROTATE_90).transpose(
        Image.Transpose.FLIP_TOP_BOTTOM)


def scale_alpha(mask, a):
    return mask.point(lut(lambda v: v * a)) if a < 1.0 else mask


def smooth_closed(pts, steps=8):
    """Catmull-Rom through a closed list of points: rounded, organic outlines."""
    out = []
    n = len(pts)
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t
                                    + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    return out


def smooth_open(pts, steps=8):
    pts = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t
                                    + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    out.append(pts[-2])
    return out


def ellipse_pts(cx, cy, rx, ry, n=48, rot=0.0):
    c, s = math.cos(rot), math.sin(rot)
    return [(cx + rx * math.cos(2 * math.pi * k / n) * c - ry * math.sin(2 * math.pi * k / n) * s,
             cy + rx * math.cos(2 * math.pi * k / n) * s + ry * math.sin(2 * math.pi * k / n) * c)
            for k in range(n)]


def taper(draw, P, scale, pts, w0, w1, fill=255):
    """A stroke that thins from w0 to w1 along a smooth path: fingers, limbs, drips."""
    path = smooth_open(pts, 10)
    total = sum(math.dist(a, b) for a, b in zip(path, path[1:])) or 1.0
    run = 0.0
    prev = path[0]
    for q in path:
        run += math.dist(prev, q)
        prev = q
        n = max(1, int(math.dist(prev, q) * 2))
        r = (w0 + (w1 - w0) * run / total) / 2.0
        (x, y), = P([q])
        draw.ellipse([x - r * scale, y - r * scale, x + r * scale, y + r * scale], fill=fill)
    # fill gaps between samples
    for a, b in zip(path, path[1:]):
        t = path.index(a) / max(1, len(path) - 1)
        draw.line(P([a, b]), fill=fill, width=max(1, int((w0 + (w1 - w0) * t) * scale)))


class Lum:
    """A luminance canvas painted at S x supersampling in 1x coordinates."""

    def __init__(self, size, s, value=0):
        self.size1 = size
        self.s = s
        self.size = (size[0] * s, size[1] * s)
        self.img = Image.new("L", self.size, value)

    def P(self, pts):
        return [(x * self.s, y * self.s) for x, y in pts]

    def mask(self):
        return Image.new("L", self.size, 0)

    def poly_mask(self, pts, blur=0.0):
        m = self.mask()
        ImageDraw.Draw(m).polygon(self.P(pts), fill=255)
        return m.filter(ImageFilter.GaussianBlur(blur * self.s)) if blur else m

    def rect_mask(self, x0, y0, x1, y1, blur=0.0):
        return self.poly_mask([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], blur)

    def ellipse_mask(self, cx, cy, rx, ry, blur=0.0):
        m = self.mask()
        s = self.s
        ImageDraw.Draw(m).ellipse([(cx - rx) * s, (cy - ry) * s, (cx + rx) * s, (cy + ry) * s], fill=255)
        return m.filter(ImageFilter.GaussianBlur(blur * s)) if blur else m

    def line_mask(self, pts, width, blur=0.0):
        m = self.mask()
        ImageDraw.Draw(m).line(self.P(pts), fill=255, width=max(1, int(round(width * self.s))), joint="curve")
        return m.filter(ImageFilter.GaussianBlur(blur * self.s)) if blur else m

    def put(self, mask, value, alpha=1.0):
        src = value if isinstance(value, Image.Image) else solid(self.size, value)
        self.img = Image.composite(src, self.img, scale_alpha(mask, alpha))

    def add(self, mask, amount):
        self.img = ImageChops.add(self.img, mask.point(lut(lambda v: v * amount / 255.0)))

    def mul(self, img):
        self.img = ImageChops.multiply(self.img, img)


# ---------------------------------------------------------------------------
# photographs: the window from the sea side, at night (silver gelatin)
# ---------------------------------------------------------------------------
PW, PH = 528, 620
PS = 4                                   # supersample
SASH = (92, 72, 436, 468)                # outer edge of the sash frame
UP_COLS = [(100, 204), (212, 316), (324, 428)]
UP_ROWS = [(80, 155), (163, 238)]
LOWER = (100, 262, 428, 452)             # the big lower pane
DESK_Y = 430                             # desk edge, inside, along the pane's bottom
WATER_Y = 574
LAMP = (146, 334)                        # lamp glow centre, inside the lower pane
ADA_X = 236
FIG_X = 318

# silver-gelatin tone: green-black shadows, olive mids, warm cream lights
TONE = [(0, (9, 12, 11)), (40, (36, 42, 36)), (110, (98, 99, 82)), (180, (172, 164, 136)),
        (255, (240, 232, 208))]
# where the pale thing stands the toning goes cold: same values, no warmth in them
TONE_COOL = [(0, (8, 11, 13)), (40, (33, 40, 42)), (110, (90, 97, 98)), (180, (156, 163, 162)),
             (255, (228, 234, 232))]


def tone(img_l, stops=TONE):
    chans = []
    for c in range(3):
        table = []
        for v in range(256):
            for (a, ca), (b, cb) in zip(stops, stops[1:]):
                if a <= v <= b:
                    t = (v - a) / (b - a)
                    table.append(int(round(ca[c] + (cb[c] - ca[c]) * t)))
                    break
        chans.append(img_l.point(table))
    return Image.merge("RGB", chans)


def clumped_grain(img_l, rng, strength):
    """Silver grain: clumps of several sizes, monochrome, strongest in the mid-tones and
    nearly absent in the blacks (unexposed emulsion) and the blown lamp (fully exposed)."""
    w, h = img_l.size
    acc = Image.new("L", (w, h), 128)
    # clumps 1.5-5 px across (the plate is shown at half size, so single-pixel hiss would vanish
    # into an even grey): coarse octaves weigh most, the finest barely at all
    for k, weight in ((1.5, 0.22), (2.6, 0.42), (4.6, 0.40)):
        sw, sh = max(2, int(w / k)), max(2, int(h / k))
        n = Image.frombytes("L", (sw, sh), rng.randbytes(sw * sh))
        n = n.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(0.5))
        n = n.point(lut(lambda v, wt=weight: 128 + (v - 128) * 0.62 * wt))
        acc = ImageChops.add(acc, n, offset=-128)
    # clumping: threshold-ish contrast, so grains bunch into specks with clean gaps between
    acc = acc.point(lut(lambda v: 128 + math.copysign(abs(v - 128) ** 1.45, v - 128) * 0.30))
    # mid-tones only: unexposed blacks and the blown lamp carry almost no grain
    amp = img_l.point(lut(lambda v: 255 * strength * (4.0 * (v / 255.0) * (1 - v / 255.0)) ** 2.4))
    pos = ImageChops.multiply(acc.point(lut(lambda v: max(0, v - 128) * 2)), amp)
    neg = ImageChops.multiply(acc.point(lut(lambda v: max(0, 128 - v) * 2)), amp)
    return ImageChops.subtract(ImageChops.add(img_l, pos), neg)


def mottle(size, rng, amp):
    """Low-frequency unevenness of a hand-developed print."""
    small = Image.frombytes("L", (14, 17), rng.randbytes(14 * 17))
    big = small.resize(size, Image.BICUBIC).filter(ImageFilter.GaussianBlur(size[0] / 30))
    return big.point(lut(lambda v: 128 + (v - 128) * amp / 64.0))


def paint_exterior(c: Lum, rng: random.Random):
    """Weatherboards, the window's casing and sill, the sea. Everything outside the glass."""
    S = c.s
    w, h = c.size
    boards = Image.new("L", c.size, 0)
    d = ImageDraw.Draw(boards)
    y0 = 24
    while y0 < WATER_Y + 4:
        y1 = y0 + 21
        for yy in range(y0 * S, y1 * S):
            t = (yy - y0 * S) / (21 * S)
            d.line([(0, yy), (w, yy)], fill=int(92 - 34 * t))
        d.rectangle([0, (y1 - 2) * S, w, y1 * S], fill=12)
        for _ in range(rng.randint(1, 2)):
            x = rng.uniform(10, PW - 10)
            d.line([(x * S, y0 * S), (x * S, (y1 - 2) * S)], fill=30, width=S)
        for _ in range(26):
            x = rng.uniform(-20, PW)
            yy = rng.uniform(y0 + 2, y1 - 3)
            ln = rng.uniform(20, 90)
            d.line([(x * S, yy * S), ((x + ln) * S, yy * S)], fill=int(rng.uniform(50, 100)), width=S // 2)
        y0 = y1
    boards = boards.filter(ImageFilter.GaussianBlur(0.5 * S))
    spill = radial(c.size, (264 * S, 360 * S), 340 * S, 310 * S, 215, 40, 1.5)
    shade = c.rect_mask(40, 486, 490, 520, blur=10)
    spill = Image.composite(solid(c.size, 30), spill, scale_alpha(shade, 0.7))
    wet = vgrad(c.size, 255, 255)
    wet_band = c.rect_mask(0, 520, PW, WATER_Y, blur=14)
    wet = Image.composite(solid(c.size, 150), wet, wet_band)
    c.img = ImageChops.multiply(ImageChops.multiply(boards, spill), wet)
    c.put(c.rect_mask(-5, -5, PW + 5, 22), 4)
    c.put(c.rect_mask(-5, 18, PW + 5, 26, blur=1.2), 13)
    trim_val = radial(c.size, (264 * S, 330 * S), 300 * S, 300 * S, 112, 34, 1.3)
    c.put(c.poly_mask([(60, 40), (468, 40), (468, 52), (60, 52)]), trim_val)
    c.put(c.rect_mask(54, 36, 474, 42), 20)
    c.put(c.rect_mask(70, 52, 458, 470), trim_val)
    c.put(c.rect_mask(70, 52, 458, 56, blur=1.5), 18, 0.8)
    # weathered paint: blistered patches on the casing, a few runs of rust from the nails
    for _ in range(22):
        px, py = rng.uniform(74, 454), rng.uniform(58, 466)
        if SASH[0] - 4 < px < SASH[2] + 4 and SASH[1] - 4 < py < SASH[3] + 4:
            continue
        c.put(c.ellipse_mask(px, py, rng.uniform(2, 7), rng.uniform(1.5, 5), blur=1.2), 22, 0.35)
    c.put(c.rect_mask(SASH[0] - 2, SASH[1] - 2, SASH[2] + 2, SASH[3]), 10)
    c.put(c.rect_mask(*SASH), 36)
    sill_top = radial(c.size, (264 * S, 470 * S), 210 * S, 40 * S, 150, 52, 1.2)
    c.put(c.poly_mask([(SASH[0] - 4, 468), (SASH[2] + 4, 468), (466, 478), (62, 478)]), sill_top)
    c.put(c.rect_mask(60, 478, 468, 490), 24)
    c.put(c.rect_mask(64, 490, 464, 500, blur=3), 6, 0.85)
    c.put(c.rect_mask(-5, WATER_Y - 3, PW + 5, WATER_Y + 1, blur=1), 8)
    c.put(c.rect_mask(-5, WATER_Y, PW + 5, PH + 5), 3)
    refl = Image.new("L", c.size, 0)
    d = ImageDraw.Draw(refl)
    y = WATER_Y + 3
    while y < PH:
        k = (y - WATER_Y) / (PH - WATER_Y)
        for _ in range(9):
            x = rng.gauss(258, 70)
            ln = rng.uniform(8, 46) * (1.0 - 0.5 * k)
            v = int(rng.uniform(70, 190) * (1.0 - 0.55 * k) * math.exp(-((x - 258) / 150) ** 2))
            d.line([((x - ln / 2) * S, y * S), ((x + ln / 2) * S, y * S)], fill=v, width=int(1.3 * S))
        y += rng.uniform(2.2, 4.0)
    c.add(refl.filter(ImageFilter.GaussianBlur(0.6 * S)), 255)


def paint_interior(rng, variant):
    """What is seen through the glass, on its own canvas. Returns (canvas, cool mask): the cool
    mask marks where the pale figure is, so the print's toning can go cold there."""
    c = Lum((PW, PH), PS, 0)
    cool = c.mask()
    S = PS
    wall = radial(c.size, (LAMP[0] * S, LAMP[1] * S), 360 * S, 250 * S, 236, 70, 1.1)
    # plaster is not a gradient: a faint uneven bloom over it
    wall = ImageChops.add(wall, mottle(c.size, rng, 7), offset=-128)
    c.img = wall
    c.put(c.rect_mask(LOWER[0], 392, LOWER[2], LOWER[3]), ImageChops.multiply(wall, solid(c.size, 200)))
    c.put(c.rect_mask(LOWER[0], 388, LOWER[2], 393, blur=0.6), ImageChops.multiply(wall, solid(c.size, 140)))
    c.put(c.rect_mask(LOWER[0], 386, LOWER[2], 388, blur=0.4), ImageChops.multiply(wall, solid(c.size, 255)))
    for x in range(118, 428, 26):
        c.put(c.line_mask([(x, 394), (x, 452)], 1.0, blur=0.4), ImageChops.multiply(wall, solid(c.size, 160)))
    for (y0, y1), vals in zip(UP_ROWS, [(8, 14), (30, 72)]):
        for i, (x0, x1) in enumerate(UP_COLS):
            lift = [1.0, 0.78, 0.6][i]
            g = vgrad(c.size, 0, 0)
            g.paste(vgrad(((x1 - x0) * S, (y1 - y0) * S), int(vals[0] * lift), int(vals[1] * lift)), (x0 * S, y0 * S))
            c.put(c.rect_mask(x0, y0, x1, y1), g)
    # Lamp: the articulated brass lamp, a tilted bell shade, its mouth blazing. Drawn a touch
    # unsteadily: the long exposure and the old lens do not give clean geometry.
    c.put(c.ellipse_mask(122, 429, 13, 3.5, blur=0.8), 24)
    c.put(c.line_mask(smooth_open([(122, 428), (114, 400), (112, 378), (122, 352), (134, 330)], 6), 3.0,
                      blur=0.7), 26)
    c.put(c.ellipse_mask(112, 378, 3.5, 3.5, blur=0.6), 24)
    bell = smooth_closed([(128, 331), (133, 319), (147, 313), (161, 322), (168, 341), (147, 346),
                          (130, 345)], 6)
    c.put(c.poly_mask(bell, blur=1.0), 32)
    mouth = ellipse_pts(150, 343, 19, 4.4, 40, rot=-0.18)
    c.put(c.poly_mask(mouth, blur=1.1), 254)
    c.add(c.line_mask(smooth_open([(132, 326), (140, 317), (150, 315)], 6), 1.1, blur=0.6), 70)
    c.add(c.ellipse_mask(156, 384, 66, 58, blur=26), 70)
    # the bulb blooms in the emulsion: a tight halo round the shade's mouth only
    c.add(c.ellipse_mask(151, 345, 16, 6, blur=5), 120)
    c.add(c.ellipse_mask(151, 348, 30, 14, blur=12), 50)
    if variant in ("drawer", "drawer_hand", "turned"):
        paint_ada(c, variant)
    if variant in ("drawer", "drawer_hand"):
        paint_standing_figure(c, cool, hand=variant == "drawer_hand")
    if variant == "after":
        paint_chair(c, empty=True)
        paint_seated_figure(c, cool)
    edge = hgrad(c.size, 120, 40)
    c.put(c.rect_mask(LOWER[0], DESK_Y, LOWER[2], LOWER[3] + 2), 15)
    c.put(c.rect_mask(LOWER[0], DESK_Y - 1, LOWER[2], DESK_Y + 2.2, blur=0.5), edge)
    if variant != "turned":
        c.put(c.rect_mask(352, 418, 406, DESK_Y, blur=0.5), 22)
        c.put(c.rect_mask(352, 417, 406, 419, blur=0.4), 70)
        c.put(c.rect_mask(410, 414, 422, DESK_Y, blur=0.5), 18)
    if variant == "turned":
        paint_turned_hands(c)
    if variant == "drawer_hand":
        paint_rail_hand(c, cool)                     # in front of the chair, over the desk's edge
    return c, cool


def paint_ada(c: Lum, variant):
    x = ADA_X
    coat = 13
    if variant == "turned":
        # Turned round to face the glass. Coat, collar, hair pinned up, a face with nothing in it.
        body = smooth_closed([(x - 18, 372), (x - 58, 388), (x - 70, 412), (x - 72, DESK_Y + 4),
                              (x + 72, DESK_Y + 4), (x + 70, 412), (x + 58, 388), (x + 18, 372)], 6)
        c.put(c.poly_mask(body, blur=0.8), coat)
        # coat front: lapels, a row of buttons, the sleeves' seams picked out by the lamp at her right
        c.put(c.poly_mask([(x - 20, 374), (x - 6, 418), (x, 430), (x + 6, 418), (x + 20, 374), (x, 392)],
                          blur=0.8), 22)
        c.add(c.line_mask(smooth_open([(x - 20, 374), (x - 9, 404), (x, 428)], 6), 1.0, blur=0.5), 26)
        for by in (404, 420):
            c.add(c.ellipse_mask(x + 9, by, 1.6, 1.6, blur=0.4), 34)
        for sgn, k in ((-1, 1.0), (1, 0.45)):
            c.add(c.line_mask(smooth_open([(x + sgn * 58, 390), (x + sgn * 66, 404), (x + sgn * 70, 426)], 6),
                              1.6, blur=0.7), int(110 * k))                                   # shoulder/sleeve
            c.add(c.line_mask(smooth_open([(x + sgn * 52, 400), (x + sgn * 54, 416), (x + sgn * 50, 430)], 6),
                              1.0, blur=0.6), int(40 * k))                                     # sleeve seam
        c.put(c.rect_mask(x - 8.5, 360, x + 8.5, 378, blur=0.9), 70)                          # throat
        c.put(c.rect_mask(x + 2, 362, x + 9, 378, blur=1.6), 44, 0.8)                         # its shadow side
        collar = [(x - 22, 371), (x - 6, 393), (x, 381), (x + 6, 393), (x + 22, 371), (x + 15, 366),
                  (x, 377), (x - 15, 366)]
        c.put(c.poly_mask(collar, blur=0.6), 26)
        c.add(c.line_mask(smooth_open([(x - 22, 371), (x - 15, 366), (x - 3, 376)], 5), 1.2, blur=0.4), 80)
        # Hair pulled tight back from the face and pinned in a knot behind: from the front, a dark
        # cap close over the crown, swept back at the temples, the bun showing above it.
        c.put(c.ellipse_mask(x + 1.5, 304, 11.5, 9.5, blur=0.8), 10)                          # the bun
        c.add(c.line_mask(smooth_open([(x - 8, 302), (x - 4, 296.5), (x + 4, 296)], 5), 1.2, blur=0.4), 70)
        cap = smooth_closed([(x - 20, 346), (x - 21.5, 330), (x - 17, 316), (x - 7, 309), (x + 1, 308),
                             (x + 10, 309), (x + 19, 316), (x + 23, 330), (x + 22, 346), (x + 18, 336),
                             (x + 10, 327), (x + 1, 324), (x - 8, 327), (x - 16, 336)], 6)
        c.put(c.poly_mask(cap, blur=0.7), 14)
        for k in range(5):                                                                     # combed back
            xx = x - 12 + k * 6
            c.add(c.line_mask(smooth_open([(xx * 0.9 + x * 0.1, 326), (xx, 317), (x + (xx - x) * 0.6, 310)], 5),
                              0.6, blur=0.3), 18)
        c.add(c.line_mask(smooth_open([(x - 20, 343), (x - 21, 329), (x - 15, 316), (x - 6, 310)], 6), 1.5,
                          blur=0.6), 80)                                                       # lamp on her hair
        for sgn, v in ((-1, 120), (1, 70)):                                                    # ears, no more
            c.put(c.ellipse_mask(x + sgn * 19.5, 347, 2.6, 5.5, blur=0.8), v)
        # The face. Lit from her right (the lamp), modelled like a face, with nothing in it.
        fx, fy, frx, fry = x + 1, 344, 17.5, 23.5
        face = hgrad(c.size, 206, 150)
        fm = c.ellipse_mask(fx, fy, frx, fry, blur=1.0)
        c.put(fm, face)
        sh = c.mask()
        sd = ImageDraw.Draw(sh)
        P = c.P
        sd.polygon(P(smooth_closed([(fx - 15, fy - 10), (fx, fy - 13), (fx + 15, fy - 10), (fx + 14, fy - 5),
                                    (fx, fy - 7), (fx - 14, fy - 5)], 5)), fill=150)            # under the brow
        sd.polygon(P(smooth_closed([(fx + 6, fy + 1), (fx + 16, fy - 2), (fx + 17, fy + 14), (fx + 8, fy + 19),
                                    (fx + 5, fy + 10)], 5)), fill=170)                           # far cheek
        sd.polygon(P(smooth_closed([(fx - 15, fy + 2), (fx - 10, fy + 4), (fx - 12, fy + 14),
                                    (fx - 16, fy + 10)], 5)), fill=70)                           # near cheek
        sd.polygon(P(smooth_closed([(fx - 9, fy + 16), (fx + 9, fy + 16), (fx + 6, fy + 22), (fx - 6, fy + 22)],
                                   5)), fill=120)                                                # under the jaw
        sd.polygon(P(smooth_closed([(fx - 2, fy - 3), (fx + 3, fy - 3), (fx + 4, fy + 8), (fx - 1, fy + 8)], 4)),
                   fill=40)                                                                      # where a nose is not
        sh = ImageChops.multiply(sh.filter(ImageFilter.GaussianBlur(3.2 * c.s)), fm)
        c.img = ImageChops.subtract(c.img, sh.point(lut(lambda v: v * 0.30)))
        c.put(c.ellipse_mask(fx, fy - fry + 4, frx * 0.92, 6, blur=1.5), 14, 0.55)            # hairline shadow
        c.add(c.line_mask(smooth_open([(x - 66, 420), (x - 62, 396), (x - 48, 386), (x - 22, 376)], 6), 1.4,
                          blur=0.8), 70)
        for px in (x - 54, x + 48):
            c.put(c.rect_mask(px, 384, px + 6, DESK_Y, blur=0.5), 34)
        return
    # Back to the camera: coat, collar turned up, the nape pale under hair pinned into a knot.
    body = smooth_closed([(x - 16, 374), (x - 56, 388), (x - 66, 410), (x - 68, DESK_Y + 4),
                          (x + 68, DESK_Y + 4), (x + 66, 410), (x + 56, 388), (x + 16, 374)], 6)
    c.put(c.poly_mask(body, blur=0.8), coat)
    # the back seam and the shoulder seams, barely there
    c.add(c.line_mask([(x, 384), (x + 1, DESK_Y)], 1.0, blur=0.6), 10)
    c.put(c.rect_mask(x - 8, 361, x + 8, 378, blur=0.9), 96)                              # nape
    c.put(c.rect_mask(x + 1, 362, x + 8, 378, blur=1.6), 40, 0.7)                         # its far side shaded
    c.put(c.poly_mask([(x - 20, 375), (x - 15, 363), (x + 15, 363), (x + 20, 375), (x, 381)], blur=0.6), 24)
    c.add(c.line_mask(smooth_open([(x - 20, 375), (x - 15, 363), (x - 2, 364)], 5), 1.3, blur=0.4), 100)
    c.put(c.ellipse_mask(x, 343, 21, 25, blur=0.9), 17)                                   # head
    c.put(c.ellipse_mask(x + 1, 322, 12.5, 9.5, blur=0.7), 9)                             # the knot
    c.add(c.line_mask(smooth_open([(x - 12, 324), (x - 8, 315), (x + 2, 312.5), (x + 10, 316)], 6), 1.3,
                      blur=0.4), 110)                                                      # lamp on the knot
    c.add(c.line_mask(smooth_open([(x - 6, 328), (x + 2, 324), (x + 9, 327)], 6), 0.8, blur=0.3), 30)
    for k in range(4):                                                                     # pinned hair, combed up
        xx = x - 14 + k * 4
        c.add(c.line_mask(smooth_open([(xx, 358), (xx + 1, 346), (xx + 4, 334)], 5), 0.6, blur=0.3), 16)
    c.add(c.line_mask(smooth_open([(x - 13, 362), (x - 20, 349), (x - 21, 335), (x - 13, 324)], 6), 1.8,
                      blur=0.8), 150)                                                      # lamp rims her hair
    c.add(c.line_mask([(x - 8, 363), (x - 8, 376)], 1.4, blur=0.6), 70)                   # and her neck
    c.add(c.line_mask(smooth_open([(x - 66, 424), (x - 63, 400), (x - 50, 388), (x - 20, 376)], 6), 1.8,
                      blur=0.8), 130)
    paint_chair(c, empty=False)


def paint_chair(c: Lum, empty: bool):
    """Spindle back between her and the glass. Lit along its top from the lamp side."""
    x = ADA_X
    l, r = x - 50, x + 50
    rail_y = 398
    tone_ = 24 if empty else 46
    for px in (l, r - 7):
        c.put(c.rect_mask(px, rail_y - 4, px + 7, DESK_Y, blur=0.5), tone_)
    for sx in (x - 26, x - 2, x + 22):
        c.put(c.rect_mask(sx, rail_y, sx + 4, DESK_Y, blur=0.5), tone_)
    rail = smooth_closed([(l - 3, rail_y - 2), (x, rail_y - 7), (r + 3, rail_y - 2), (r + 3, rail_y + 6),
                          (x, rail_y + 2), (l - 3, rail_y + 6)], 6)
    c.put(c.poly_mask(rail, blur=0.5), tone_ + 6)
    hl = hgrad(c.size, 150, 60)
    c.put(c.line_mask(smooth_open([(l - 2, rail_y - 2), (x, rail_y - 6.5), (r + 2, rail_y - 2)], 8), 1.4,
                      blur=0.5), hl)


# The pale thing. Seen from behind, narrow (no wider at the shoulder than she is), far too long.
# It is painted pale and translucent: the wall and her coat show through it, its back modelled
# in planes (trapezius, shoulder blades, the groove of the spine), rimmed by the lamp behind it.
FIG_VALUE = (204, 182)          # top -> waist, before translucency


def back_outline(cx, neck_y, sh_y, half, waist_y, waist_half, bottom, neck_half=15):
    """A gaunt back: a thick neck flaring into sloped trapezius, rounded deltoids no wider than
    hers, lats, a long narrow waist. No square 'hanger' shoulders anywhere."""
    pts = [(cx - neck_half, neck_y), (cx + neck_half, neck_y),
           (cx + neck_half + 2, sh_y - 16), (cx + half * 0.62, sh_y - 7), (cx + half - 3, sh_y - 1),
           (cx + half + 1, sh_y + 9), (cx + half - 6, sh_y + 28), (cx + half - 8, sh_y + 56),
           (cx + waist_half + 3, waist_y - 30), (cx + waist_half, waist_y), (cx + waist_half + 9, bottom - 22),
           (cx + waist_half + 12, bottom), (cx - waist_half - 12, bottom), (cx - waist_half - 9, bottom - 22),
           (cx - waist_half, waist_y), (cx - waist_half - 3, waist_y - 30),
           (cx - half + 8, sh_y + 56), (cx - half + 6, sh_y + 28), (cx - half - 1, sh_y + 9),
           (cx - half + 3, sh_y - 1), (cx - half * 0.62, sh_y - 7), (cx - neck_half - 2, sh_y - 16)]
    return smooth_closed(pts, 8)


def limb(c: Lum, m, pts, w0, w1):
    taper(ImageDraw.Draw(m), c.P, c.s, pts, w0, w1)


def pale_figure(c: Lum, cool, m, opacity, cx, sh_y, half, planes=True, rim_left=150, rim_right=40, lumbar=False):
    """Lay the translucent pale body down and model it."""
    S = c.s
    body = vgrad(c.size, FIG_VALUE[0], FIG_VALUE[1])
    c.put(m, body, opacity)
    core = m.filter(ImageFilter.MinFilter(int(3 * S) | 1)).filter(ImageFilter.GaussianBlur(3.5 * S))
    # the side turned from the lamp falls away (cold, not grey: the toning keeps it pale)
    far = Image.new("L", c.size, 0)
    far.paste(hgrad((int(2.4 * half) * S, PH * S), 0, 255), (int(cx - 0.6 * half) * S, 0))
    far.paste(255, (int(cx + 1.8 * half) * S, 0, c.size[0], c.size[1]))
    c.img = ImageChops.subtract(c.img, ImageChops.multiply(far, core).point(lut(lambda v: v * 0.20 * opacity)))
    if planes:
        dark = c.mask()
        lift = c.mask()
        dd, ld = ImageDraw.Draw(dark), ImageDraw.Draw(lift)
        P = c.P
        # the groove of the spine, deepest between the blades
        dd.line(P(smooth_open([(cx, sh_y - 14), (cx + 0.6, sh_y + 30), (cx + 0.2, sh_y + 80),
                               (cx + 1.4, sh_y + 150)], 8)), fill=200, width=int(3.2 * S))
        for sgn in (-1, 1):
            # each shoulder blade: a shallow crescent of shadow on its inner/lower edge
            blade = [(cx + sgn * 10, sh_y + 6), (cx + sgn * 13, sh_y + 26), (cx + sgn * 20, sh_y + 44),
                     (cx + sgn * 32, sh_y + 50), (cx + sgn * 40, sh_y + 40)]
            dd.line(P(smooth_open(blade, 8)), fill=170, width=int(3.6 * S))
            # its plate catches the light above that
            ld.ellipse(P([(cx + sgn * 30 - 9, sh_y + 10), (cx + sgn * 30 + 9, sh_y + 34)]), fill=90)
            # the trapezius ridge from neck to shoulder
            ld.line(P(smooth_open([(cx + sgn * 12, sh_y - 14), (cx + sgn * 26, sh_y - 8),
                                   (cx + sgn * (half - 6), sh_y + 1)], 8)), fill=200, width=int(2.4 * S))
            # the deltoid's lower edge, the arm hanging from it
            dd.line(P(smooth_open([(cx + sgn * (half - 3), sh_y + 20), (cx + sgn * (half - 9), sh_y + 34)], 6)),
                    fill=120, width=int(2.4 * S))
            # lower ribs: two faint bars where the back narrows to the waist
            for k, yy in enumerate((sh_y + 70, sh_y + 86)):
                dd.line(P(smooth_open([(cx + sgn * 8, yy), (cx + sgn * 22, yy + 3), (cx + sgn * (half - 14), yy + 9)],
                                      6)), fill=60 - 15 * k, width=int(2.2 * S))
        if lumbar:
            # the long lower back: two columns of muscle beside the spine, catching light
            for sgn in (-1, 1):
                ld.line(P(smooth_open([(cx + sgn * 9, sh_y + 96), (cx + sgn * 10, sh_y + 140),
                                       (cx + sgn * 8, sh_y + 200)], 8)), fill=150, width=int(7 * S))
            # the lowest rib's edge, where the back pinches into a waist too long for it
            for sgn in (-1, 1):
                dd.line(P(smooth_open([(cx + sgn * 16, sh_y + 128), (cx + sgn * 26, sh_y + 136),
                                       (cx + sgn * (half - 18), sh_y + 150)], 6)), fill=90, width=int(2.4 * S))
        dark = ImageChops.multiply(dark.filter(ImageFilter.GaussianBlur(2.6 * S)), core)
        lift = ImageChops.multiply(lift.filter(ImageFilter.GaussianBlur(3.0 * S)), core)
        c.img = ImageChops.subtract(c.img, dark.point(lut(lambda v: v * 0.30 * opacity)))
        c.add(lift, int(46 * opacity))
    # rim: the lamp behind it wraps the near edge; a cold hairline on the far edge
    inner = m.filter(ImageFilter.MinFilter(int(3 * S) | 1))
    band = ImageChops.subtract(m, inner).filter(ImageFilter.GaussianBlur(0.8 * S))
    c.add(ImageChops.multiply(band, hgrad(c.size, rim_left, rim_right)), 255)
    outer = ImageChops.subtract(m.filter(ImageFilter.MaxFilter(int(5 * S) | 1)), m)
    c.add(ImageChops.multiply(outer.filter(ImageFilter.GaussianBlur(2.2 * S)), hgrad(c.size, 90, 10)), 40)
    cool.paste(ImageChops.lighter(cool, core.point(lut(lambda v: v * 0.9))))


def neck_into_sash(c: Lum, cool, cx, half_w, y_top, y_bot, value, opacity):
    """Above the meeting rail the neck goes on, up into the dim middle panes, and is lost there."""
    m = c.poly_mask([(cx - half_w, y_bot), (cx + half_w, y_bot), (cx + half_w * 0.9, y_top),
                     (cx - half_w * 0.9, y_top)], blur=1.6)
    fade = Image.new("L", c.size, 0)
    fade.paste(vgrad((c.size[0], int((y_bot - y_top) * c.s)), 0, 255), (0, int(y_top * c.s)))
    fade.paste(255, (0, int(y_bot * c.s), c.size[0], c.size[1]))
    m = ImageChops.multiply(m, fade)
    c.put(m, value, opacity)
    c.add(ImageChops.multiply(ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(int(2 * c.s) | 1))),
                              hgrad(c.size, 120, 20)), 90)
    cool.paste(ImageChops.lighter(cool, m))


FIG_SH_Y = 206                       # its shoulders: up behind the meeting rail, in the dim sash
FIG_HALF = 54                        # half its shoulder span: Ada's is about 56


def dim_above(c: Lum, before, y, k):
    """Up in the unlit sash the pale thing is only half there."""
    m = c.rect_mask(-4, -4, PW + 4, y, blur=6)
    c.img = Image.composite(Image.blend(before, c.img, k), c.img, m)


def paint_standing_figure(c: Lum, cool, hand: bool):
    """Narrow, and twice as tall as she would stand: it stands between her chair and the glass, so
    nearer the camera than she is, over her right shoulder and the chair's right post. The lit pane
    shows it from the lower ribs down; its shoulders are up in the dim sash, and its head is above
    the window altogether. Seated, she comes up to its waist."""
    x, sy, hw = FIG_X, FIG_SH_Y, FIG_HALF
    before = c.img.copy()
    m = c.poly_mask(back_outline(x, 20, sy, hw, 380, 25, DESK_Y + 30, neck_half=17))
    # arms: slack, hanging a little off the body, wrists somewhere below the desk's edge
    limb(c, m, [(x + hw - 5, sy + 8), (x + hw - 2, sy + 70), (x + hw - 3, 336), (x + hw + 1, 380),
                (x + hw + 3, DESK_Y + 30)], 15, 10)
    creases = [[(x + hw - 13, 262), (x + hw - 16, 300), (x + 27, 350), (x + 26, 400)]]
    if hand:
        # its left arm comes straight down past her shoulder and turns its hand onto the rail
        limb(c, m, [(x - hw + 4, sy + 8), (x - hw - 1, sy + 80), (x - hw - 2, 340), (x - hw + 2, 370),
                    (ADA_X + 40, 383)], 15, 11)
    else:
        limb(c, m, [(x - hw + 5, sy + 8), (x - hw + 2, sy + 70), (x - hw + 3, 336), (x - hw - 1, 380),
                    (x - hw - 3, DESK_Y + 30)], 15, 10)
        creases.append([(x - hw + 13, 262), (x - hw + 16, 300), (x - 27, 350), (x - 26, 400)])
    m = m.filter(ImageFilter.GaussianBlur(1.0 * c.s))
    # long exposure: a fainter ghost a hair to the right, as if it had leaned in toward her
    echo = m.transform(m.size, Image.AFFINE, (1, 0, -3 * c.s, 0, 1, 0)).filter(ImageFilter.GaussianBlur(2.5 * c.s))
    c.put(echo, 170, 0.08)
    pale_figure(c, cool, m, 0.58, x, sy, hw, lumbar=True, rim_left=46, rim_right=8)
    # where each arm hangs against its side: a soft crease of shadow, and the elbow's knob
    cr = c.mask()
    for pts in creases:
        ImageDraw.Draw(cr).line(c.P(smooth_open(pts, 8)), fill=255, width=int(2.4 * c.s))
    c.img = ImageChops.subtract(c.img, cr.filter(ImageFilter.GaussianBlur(1.6 * c.s)).point(lut(lambda v: v * 0.22)))
    for sgn in ((1, -1) if not hand else (1,)):
        c.add(c.ellipse_mask(x + sgn * (hw - 3), 338, 5, 7, blur=2.5), 16)
    dim_above(c, before, LOWER[1] - 6, 0.42)


def paint_rail_hand(c: Lum, cool):
    """A long hand laid on the chair's top rail beside her neck. Its weight on the rail, knuckles
    up; four fingers, half as long again as fingers are, curl over the rail and hang down the
    spindles after the line of her back. Soft: it moved a little during the exposure."""
    S = c.s
    P = c.P
    m = c.mask()
    d = ImageDraw.Draw(m)
    wrist = (ADA_X + 40, 381)
    # the back of the hand, foreshortened along the rail, its heel pressed on the rail's top
    knuckles = [(ADA_X + 9, 389.0), (ADA_X + 16, 390.5), (ADA_X + 23, 392.5), (ADA_X + 30, 395.0)]
    d.polygon(P(smooth_closed([(ADA_X + 44, 378), (ADA_X + 46, 390), (ADA_X + 34, 400), (ADA_X + 20, 398),
                               (ADA_X + 6, 393), (ADA_X + 10, 384), (ADA_X + 26, 378)], 6)), fill=255)
    fingers = []
    for i, (kx, ky) in enumerate(knuckles):
        ln = [1.0, 1.1, 1.04, 0.88][i]
        # over the rail's edge, down the spindles, the tips drawn in toward her spine
        f = [(kx, ky), (kx - 1.5, ky + 13 * ln), (kx - 4 - 1.0 * i, ky + 26 * ln), (kx - 8 - 1.8 * i, ky + 37 * ln)]
        taper(d, P, S, f, 7.4, 5.0)
        for jp in f[1:3]:
            (jx, jy), = P([jp])
            r = 3.3 * S
            d.ellipse([jx - r, jy - r, jx + r, jy + r], fill=255)
        fingers.append(f)
    taper(d, P, S, [(ADA_X + 38, 385), (ADA_X + 30, 384), (ADA_X + 20, 384.5), (ADA_X + 13, 386)], 5.6, 4.0)
    m = m.filter(ImageFilter.GaussianBlur(1.05 * S))
    # weight: a soft contact shadow round where the palm presses on the rail
    c.put(c.ellipse_mask(ADA_X + 24, 401, 26, 5, blur=2.4), 8, 0.6)
    c.put(m, vgrad(c.size, 222, 168), 0.86)
    # lamp from the upper left: a rim along the top edge, the knuckles' crowns, each joint
    up = m.transform(m.size, Image.AFFINE, (1, 0, -1.4 * S, 0, 1, 1.8 * S))
    c.add(ImageChops.subtract(m, up).filter(ImageFilter.GaussianBlur(0.6 * S)), 110)
    hi = c.mask()
    hd = ImageDraw.Draw(hi)
    for (kx, ky) in knuckles:
        hd.ellipse(P([(kx - 3.0, ky - 3.0), (kx + 2.0, ky + 1.6)]), fill=255)
    for f in fingers:
        for jx, jy in f[1:3]:
            hd.ellipse(P([(jx - 2.4, jy - 1.8), (jx + 1.2, jy + 1.2)]), fill=190)
    c.add(ImageChops.multiply(hi.filter(ImageFilter.GaussianBlur(1.0 * S)), m), 46)
    # tendons fanning from the wrist to the knuckles, faint furrows between them
    fur = c.mask()
    fd = ImageDraw.Draw(fur)
    for (kx, ky) in knuckles[:-1]:
        fd.line(P([(ADA_X + 38, 383), (kx + 3.5, ky + 1)]), fill=255, width=int(1.4 * S))
    for f, g in zip(fingers, fingers[1:]):            # the seams between fingers lying together
        fd.line(P(smooth_open([((a[0] + b[0]) / 2 + 0.4, (a[1] + b[1]) / 2) for a, b in zip(f, g)], 6)),
                fill=255, width=int(1.3 * S))
    c.img = ImageChops.subtract(c.img, ImageChops.multiply(fur.filter(ImageFilter.GaussianBlur(0.8 * S)), m)
                                .point(lut(lambda v: v * 0.30)))
    # the fingers' undersides, away from the lamp, go cool and dim
    low = m.transform(m.size, Image.AFFINE, (1, 0, 1.6 * S, 0, 1, -1.2 * S))
    c.img = ImageChops.subtract(c.img, ImageChops.subtract(m, low).filter(
        ImageFilter.GaussianBlur(1.0 * S)).point(lut(lambda v: v * 0.16)))
    cool.paste(ImageChops.lighter(cool, m.filter(ImageFilter.MinFilter(int(1.5 * S) | 1))))


def paint_seated_figure(c: Lum, cool):
    """Where she sat. Narrow as she was, but too long even seated: its neck goes up through the
    meeting rail and the head sits in the dark middle pane, the palest thing in the sash."""
    x = ADA_X
    sy, hw = 300, 52
    m = c.poly_mask(back_outline(x, LOWER[1] - 8, sy, hw, 404, 30, DESK_Y + 30, neck_half=13))
    for sgn in (-1, 1):
        # long arms hanging clear of its sides, the hands down past the seat, fingers slack
        limb(c, m, [(x + sgn * (hw - 5), sy + 8), (x + sgn * (hw + 2), sy + 50), (x + sgn * (hw + 6), 360),
                    (x + sgn * (hw + 8), 398)], 14.5, 9.5)
        limb(c, m, [(x + sgn * (hw + 8), 396), (x + sgn * (hw + 9), 408), (x + sgn * (hw + 9), 414)], 9.5, 10.5)
        for k in range(4):
            fx = x + sgn * (hw + 5.5 + k * 2.4)
            limb(c, m, [(fx, 410), (fx + sgn * 0.4, 422), (fx + sgn * 0.2 * k, 436 - (3 if k in (0, 3) else 0))],
                 2.6, 1.9)
    m = m.filter(ImageFilter.GaussianBlur(1.0 * c.s))
    pale_figure(c, cool, m, 0.60, x, sy, hw, rim_left=60, rim_right=10, lumbar=True)
    cr = c.mask()
    for sgn in (-1, 1):
        ImageDraw.Draw(cr).line(c.P(smooth_open([(x + sgn * (hw - 13), sy + 20), (x + sgn * (hw - 15), sy + 50),
                                                 (x + sgn * 36, 372), (x + sgn * 40, DESK_Y)], 8)),
                                fill=255, width=int(2.4 * c.s))
        c.add(c.ellipse_mask(x + sgn * (hw + 4), 352, 5, 7, blur=2.5), 14)
    c.img = ImageChops.subtract(c.img, cr.filter(ImageFilter.GaussianBlur(1.6 * c.s)).point(lut(lambda v: v * 0.24)))
    # above the rail: the neck, long, and a small head with nothing on it
    neck_into_sash(c, cool, x, 10, 206, 240, 150, 0.85)
    head = c.ellipse_mask(x, 190, 14.5, 27, blur=1.2)
    c.put(head, vgrad(c.size, 164, 120), 0.85)
    c.add(ImageChops.multiply(ImageChops.subtract(head, head.filter(ImageFilter.MinFilter(int(2 * c.s) | 1))),
                              hgrad(c.size, 140, 20)), 120)
    c.img = ImageChops.subtract(c.img, ImageChops.multiply(head, c.ellipse_mask(x + 7, 196, 9, 24, blur=5))
                                .point(lut(lambda v: v * 0.22)))
    cool.paste(ImageChops.lighter(cool, head))
    # her chair, in front of it
    rail_y = 398
    l, r = x - 50, x + 50
    c.put(c.poly_mask(smooth_closed([(l - 3, rail_y - 2), (x, rail_y - 7), (r + 3, rail_y - 2),
                                     (r + 3, rail_y + 6), (x, rail_y + 2), (l - 3, rail_y + 6)], 6),
                      blur=0.5), 40)
    for sx in (x - 26, x - 2, x + 22):
        c.put(c.rect_mask(sx, rail_y, sx + 4, DESK_Y, blur=0.5), 46)
    for px in (l, r - 7):
        c.put(c.rect_mask(px, rail_y - 4, px + 7, DESK_Y, blur=0.5), 40)
    c.put(c.line_mask(smooth_open([(l - 2, rail_y - 2), (x, rail_y - 6.5), (r + 2, rail_y - 2)], 8), 1.4,
                      blur=0.5), hgrad(c.size, 150, 60))


TINY = (364, 276, 420, 342)               # the window that should not be on the far wall


def paint_tiny_window(c: Lum, photo_l):
    """On the far wall at right, a window that is not there by day: a hole of night in the plaster,
    with its own casing, and in it, small and far off, this same window, lit, with the thing in its
    chair. `photo_l` is the photograph itself (supersampled L), so the picture holds itself."""
    S = c.s
    x0, y0, x1, y1 = TINY
    cx0, cy0, cx1, cy1 = 22, 0, 506, 560
    src = photo_l.crop((cx0 * S, cy0 * S, cx1 * S, cy1 * S)).resize(((x1 - x0) * S, (y1 - y0) * S), Image.LANCZOS)
    kx, ky = (x1 - x0) / (cx1 - cx0), (y1 - y0) / (cy1 - cy0)
    # the casing: flat trim in the wall's own plaster value, an inner reveal falling into shadow
    trim = ImageChops.multiply(c.img, solid(c.size, 205))
    c.put(c.rect_mask(x0 - 6, y0 - 7, x1 + 6, y1 + 9, blur=0.6), trim)
    c.put(c.rect_mask(x0 - 8, y1 + 4, x1 + 8, y1 + 9, blur=0.5), ImageChops.multiply(c.img, solid(c.size, 150)))
    c.add(c.line_mask([(x0 - 6, y0 - 6.5), (x1 + 6, y0 - 6.5)], 1.0, blur=0.4), 30)
    c.img.paste(src, (x0 * S, y0 * S))
    c.put(c.rect_mask(x0, y0, x1, y0 + 3, blur=1.0), 0, 0.8)              # the head of the reveal
    c.put(c.rect_mask(x1 - 3, y0, x1, y1, blur=1.0), 0, 0.6)
    # only its lit pane halates, faintly, in the black round it
    lx0, ly0 = x0 + (100 - cx0) * kx, y0 + (262 - cy0) * ky
    lx1, ly1 = x0 + (428 - cx0) * kx, y0 + (452 - cy0) * ky
    c.add(c.rect_mask(lx0, ly0, lx1, ly1, blur=4), 26)
    c.add(c.rect_mask(lx0 + 1, ly0 + 1, lx1 - 1, ly1 - 1, blur=1), 18)


def paint_turned_hands(c: Lum):
    """Both hands flat on the inside sill, fingers spread and over its edge toward the glass."""
    S = c.s
    for hx, mirror in ((ADA_X - 46, 1), (ADA_X + 46, -1)):
        # sleeve reaching down and forward to the sill, its cuff caught by the lamp on her right
        sleeve = smooth_closed([(hx - 18 * mirror - 8, 398), (hx - 18 * mirror + 10, 392),
                                (hx + 12, 432), (hx - 11, 436)], 6)
        c.put(c.poly_mask(sleeve, blur=0.7), 13)
        lit = 1.0 if mirror == 1 else 0.45
        c.add(c.line_mask(smooth_open([(hx - 18 * mirror - 8, 400), (hx - 6 * mirror - 4, 418),
                                       (hx - 11 * mirror, 434)], 5), 1.3, blur=0.6), int(90 * lit))
        c.add(c.line_mask([(hx - 11, 434), (hx + 12, 432)], 1.0, blur=0.5), int(60 * lit))     # cuff
        m = c.mask()
        d = ImageDraw.Draw(m)
        # back of the hand, flat, foreshortened on the sill; the fingers spread wide, over the edge
        d.polygon(c.P(smooth_closed([(hx - 15, 438), (hx - 8, 433), (hx + 8, 433), (hx + 15, 438),
                                     (hx + 16, 443), (hx - 16, 443)], 6)), fill=255)
        for i, (fx, ln) in enumerate([(-12.5, 11), (-4.4, 14), (3.8, 13.5), (11.5, 10.5)]):
            spread = fx * 0.42
            taper(d, c.P, S, [(hx + fx * 0.85, 440), (hx + fx + spread * 0.4, 441 + ln * 0.5),
                              (hx + fx + spread, 441 + ln)], 3.4, 2.3)
        taper(d, c.P, S, [(hx + 13 * mirror, 437), (hx + 20 * mirror, 440), (hx + 25 * mirror, 444)], 3.6, 2.5)
        m = m.filter(ImageFilter.GaussianBlur(0.6 * S))
        # shadows first: under each fingertip on the sill, and the hand's own shadow
        c.put(c.ellipse_mask(hx + 1, 455, 22, 3.0, blur=1.6), 6, 0.7)
        for fx, ln in [(-12.5, 11), (-4.4, 14), (3.8, 13.5), (11.5, 10.5)]:
            tx = hx + fx + fx * 0.42
            c.put(c.ellipse_mask(tx + 1, 441 + ln + 2.2, 2.6, 1.3, blur=0.6), 4, 0.8)
        c.put(m, hgrad(c.size, 150, 108) if mirror == 1 else hgrad(c.size, 132, 96), 1.0)
        # knuckle line, very soft
        c.add(c.line_mask([(hx - 12, 440), (hx + 12, 440)], 1.0, blur=0.6), 14)


def pane_mask(c: Lum):
    m = c.mask()
    d = ImageDraw.Draw(m)
    S = c.s
    for (y0, y1) in UP_ROWS:
        for (x0, x1) in UP_COLS:
            d.rectangle([x0 * S, y0 * S, x1 * S - 1, y1 * S - 1], fill=255)
    d.rectangle([LOWER[0] * S, LOWER[1] * S, LOWER[2] * S - 1, LOWER[3] * S - 1], fill=255)
    return m


def photo(name: str, variant: str):
    rng = rng_for(name)
    c = Lum((PW, PH), PS, 0)
    paint_exterior(c, rng)
    inside, cool = paint_interior(rng, variant)
    panes = pane_mask(c)
    if variant == "after":
        first = Image.composite(inside.img, c.img, panes)
        paint_tiny_window(inside, first)
    c.img = Image.composite(inside.img, c.img, panes)
    cool = ImageChops.multiply(cool, panes)
    glow_edge = c.mask()
    d = ImageDraw.Draw(glow_edge)
    S = PS
    x0, y0, x1, y1 = LOWER
    d.rectangle([(x0 - 3) * S, (y0 - 3) * S, (x1 + 3) * S, (y1 + 3) * S], outline=255, width=2 * S)
    c.add(glow_edge.filter(ImageFilter.GaussianBlur(1.5 * S)), 40)
    sheen = c.poly_mask([(120, 80), (150, 80), (90, 160), (60, 160)], blur=8)
    c.add(ImageChops.multiply(sheen, panes), 9)
    # Halation: the lit pane bleeds into the bars, and the lamp's mouth blooms in the emulsion.
    bright = c.img.point(lut(lambda v: max(0.0, v - 205) * 4.0))
    c.add(bright.filter(ImageFilter.GaussianBlur(9 * S)), 110)
    c.add(bright.filter(ImageFilter.GaussianBlur(2.5 * S)), 50)
    img = c.img.filter(ImageFilter.GaussianBlur(0.6 * S)).resize((PW, PH), Image.LANCZOS)
    cool = cool.resize((PW, PH), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.0))
    # Lens: sharp in the middle, softening toward the corners.
    soft = img.filter(ImageFilter.GaussianBlur(1.8))
    corner = radial((PW, PH), (PW / 2, PH * 0.46), PW * 0.62, PH * 0.6, 0, 255, 2.2)
    img = Image.composite(soft, img, corner)
    img = ImageChops.add(img, mottle((PW, PH), rng, 5), offset=-128)
    vig = radial((PW, PH), (PW / 2, PH * 0.47), PW * 0.78, PH * 0.72, 255, 120, 1.6)
    img = ImageChops.multiply(img, vig)
    img = clumped_grain(img, rng, 0.11)
    warm, cold = tone(img), tone(img, TONE_COOL)
    Image.composite(cold, warm, cool.point(lut(lambda v: v * 0.8))).save(OUT / f"{name}.png", optimize=False)
# ---------------------------------------------------------------------------
# full-canvas RGBA overlays, painted in a supersampled local box
# ---------------------------------------------------------------------------
class Box:
    """An RGBA overlay painted at SS x inside bbox, then placed on a transparent 1448x1086 canvas."""

    def __init__(self, bbox, ss=4):
        self.x0, self.y0, self.x1, self.y1 = bbox
        self.ss = ss
        self.size = ((self.x1 - self.x0) * ss, (self.y1 - self.y0) * ss)

    def P(self, pts):
        return [((x - self.x0) * self.ss, (y - self.y0) * self.ss) for x, y in pts]

    def mask(self):
        return Image.new("L", self.size, 0)

    def finish(self, rgb_layers):
        """rgb_layers: list of (colour, alpha mask at ss) composited bottom-up, 'over'."""
        w, h = self.size
        out_rgb = Image.new("RGB", (w, h), (0, 0, 0))
        out_a = Image.new("L", (w, h), 0)
        for colour, m in rgb_layers:
            # over: rgb = c*a + rgb*(1-a)*A/..., do it in premultiplied form
            src = colour if isinstance(colour, Image.Image) else Image.new("RGB", (w, h), colour)
            out_rgb = Image.composite(src, out_rgb, m)
            inv = ImageChops.invert(m)
            out_a = ImageChops.add(m, ImageChops.multiply(out_a, inv))
        # Downsample premultiplied so edges do not go dark.
        pre = ImageChops.multiply(out_rgb, Image.merge("RGB", (out_a, out_a, out_a)))
        small = (self.x1 - self.x0, self.y1 - self.y0)
        pre = pre.resize(small, Image.BOX)
        a = out_a.resize(small, Image.BOX)
        r, g, b = pre.split()
        unp = [unpremultiply(ch, a) for ch in (r, g, b)]
        tile = Image.merge("RGBA", (*unp, a))
        canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        canvas.paste(tile, (self.x0, self.y0))
        # fully transparent pixels: zero RGB so the file is clean and deterministic
        r, g, b, a = canvas.split()
        zero = a.point(lambda v: 255 if v else 0)
        r, g, b = (ImageChops.multiply(ch, zero) for ch in (r, g, b))
        return Image.merge("RGBA", (r, g, b, a))


def unpremultiply(ch, a):
    w, h = ch.size
    cd, ad = ch.tobytes(), a.tobytes()
    out = bytes(min(255, (cv * 255 + av // 2) // av) if av else 0 for cv, av in zip(cd, ad))
    return Image.frombytes("L", (w, h), out)


def noise_mask(size, rng, blur, lo, hi):
    w, h = size
    n = Image.frombytes("L", (w, h), rng.randbytes(w * h)).filter(ImageFilter.GaussianBlur(blur))
    n = n.point(lut(lambda v: 128 + (v - 128) * 6))
    return n.point(lut(lambda v: lo + (hi - lo) * v / 255.0))


def wobbly(rng, pts, amp):
    return [(x + rng.uniform(-amp, amp), y + rng.uniform(-amp, amp)) for x, y in pts]


def ink_edge(m, rng, ss, width, lo=0.55, hi=1.0, blur=0.35):
    """A hand-inked contour round a mask: outside the shape, its weight swelling and thinning."""
    def k(r):
        return 2 * max(1, int(round(r * ss))) + 1
    core = m.filter(ImageFilter.MinFilter(k(width * 0.5)))                 # the line straddles the edge
    thin = ImageChops.subtract(m.filter(ImageFilter.MaxFilter(k(width * 0.2))), core)
    thick = ImageChops.subtract(m.filter(ImageFilter.MaxFilter(k(width * 0.6))), core)
    pressure = noise_mask(m.size, rng, 7 * ss, 0, 255)
    line = Image.composite(thick, thin, pressure)
    var = noise_mask(m.size, rng, 4 * ss, int(lo * 255), int(hi * 255))
    return ImageChops.multiply(line, var).filter(ImageFilter.GaussianBlur(blur * ss))


# ---------------------------------------------------------------------------
# threshold_figure
# ---------------------------------------------------------------------------
# Painter 1's corridor casings (threshold_corridor.png), mirrored here so the figure stays registered:
# casing i: scale 0.86**i toward CORRIDOR_VP, its lintel a further TALL**i too high.
CORRIDOR_SLAB = (1228, 168, 206, 736)
CORRIDOR_TW = 10.0
GAME_VP = (1316.0, 548.0)        # the game swells the corridor about this point on each exhale
PEAK_SWELL = 1.022               # ~1 + 0.025*env where the figure shows (env 0.85-1): register to it


def _painter1_constants():
    """Painter 1 owns the corridor; read its VP and lintel climb so this layer stays registered to
    whatever it last painted. Plain text parse (no import, no execution); fixed fallbacks."""
    import re
    vp, climb = (1300.0, 440.0), 1.06
    try:
        src = (Path(__file__).resolve().parent / "painter_1.py").read_text()
        mv = re.search(r"^VP\s*=\s*\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)", src, re.M)
        mc = re.search(r"^CLIMB\s*=\s*([\d.]+)", src, re.M)
        if mv:
            vp = (float(mv.group(1)), float(mv.group(2)))
        if mc:
            climb = float(mc.group(1))
    except OSError:
        pass
    return vp, climb


CORRIDOR_VP, CORRIDOR_TALL = _painter1_constants()


def corridor_casing(i):
    sx, sy, sw, sh = CORRIDOR_SLAB
    r0 = (sx + 4.0, sy + 6.0, sx + sw - 4.0, sy + sh)
    s = 0.86 ** i
    x0 = CORRIDOR_VP[0] + (r0[0] - CORRIDOR_VP[0]) * s
    x1 = CORRIDOR_VP[0] + (r0[2] - CORRIDOR_VP[0]) * s
    y1 = CORRIDOR_VP[1] + (r0[3] - CORRIDOR_VP[1]) * s
    y0 = max(sy + 2.0, y1 - (r0[3] - r0[1]) * s * CORRIDOR_TALL ** i)
    return x0, y0, x1, y1, s


def threshold_figure():
    """Stands just behind the 7th casing, between it and the 8th. Its neck runs up behind the 7th
    lintel: the head is never in the picture. Mid grey-green, darker toward the water it stands in."""
    rng = rng_for("threshold_figure")
    c7, c8 = corridor_casing(6), corridor_casing(7)
    lintel = c7[1] + CORRIDOR_TW * c7[4]                    # underside of the 7th head casing
    feet = c7[3] - (c7[3] - c8[3]) * 0.45                   # standing between the two sills
    cx = (c7[0] + c7[2]) / 2 + 2.0
    b = Box((int(cx - 60), int(lintel - 14), int(cx + 60), int(feet + 70)), ss=4)
    S = b.ss
    sh_y = lintel + 16                                      # shoulders, just under the lintel
    H = feet - sh_y
    half = 18.5

    def Y(f):
        return sh_y + H * f

    # trunk and legs: high square shoulders, no chest, a narrow waist, legs a little too long
    body = smooth_closed(wobbly(rng, [
        (cx - 4.5, lintel - 8), (cx + 4.5, lintel - 8), (cx + 5, sh_y - 7), (cx + half - 4, sh_y - 3),
        (cx + half, sh_y + 6), (cx + 13, Y(0.16)), (cx + 10, Y(0.36)), (cx + 11, Y(0.46)),
        (cx + 9.5, Y(0.70)), (cx + 7.5, feet - 6), (cx + 9, feet), (cx + 2.2, feet), (cx + 1.6, Y(0.55)),
        (cx - 1.6, Y(0.55)), (cx - 2.2, feet), (cx - 9, feet), (cx - 7.5, feet - 6), (cx - 9.5, Y(0.70)),
        (cx - 11, Y(0.46)), (cx - 10, Y(0.36)), (cx - 13, Y(0.16)), (cx - half, sh_y + 6),
        (cx - half + 4, sh_y - 3), (cx - 5, sh_y - 7)], 0.5), 5)
    m = b.mask()
    d = ImageDraw.Draw(m)
    d.polygon(b.P(body), fill=255)
    # arms: tapered, hanging a little apart; wrists low at the thigh, long hands past the knee
    hands_at = []
    for sgn in (-1, 1):
        sx0 = cx + sgn * (half - 2.5)
        elbow = (cx + sgn * (half + 1.6), Y(0.34))
        wrist = (cx + sgn * (half + 1.4), Y(0.62))
        taper(d, b.P, S, [(sx0, sh_y + 5), (cx + sgn * (half + 0.6), Y(0.14)), elbow,
                          (cx + sgn * (half + 1.8), Y(0.48)), wrist], 8.2, 4.4)
        # the hand: a narrow palm, then four long fingers hanging slack, slightly apart
        palm_end = (wrist[0] + sgn * 0.6, wrist[1] + 13)
        taper(d, b.P, S, [wrist, ((wrist[0] + palm_end[0]) / 2 + sgn * 0.8, wrist[1] + 6.5), palm_end], 3.8, 4.4)
        for k, (dx, ln) in enumerate(((-1.6, 22), (-0.5, 27), (0.6, 26), (1.6, 20))):
            fx = palm_end[0] + dx * sgn
            taper(d, b.P, S, [(fx, palm_end[1] - 1), (fx + dx * 0.35 * sgn, palm_end[1] + ln * 0.45),
                              (fx + dx * 0.7 * sgn + rng.uniform(-0.4, 0.4), palm_end[1] + ln)], 1.5, 0.9)
        # the thumb, on the inside, short against the rest
        taper(d, b.P, S, [(wrist[0] - sgn * 1.8, wrist[1] + 6), (wrist[0] - sgn * 2.6, wrist[1] + 14),
                          (wrist[0] - sgn * 2.4, wrist[1] + 19)], 1.7, 1.0)
        hands_at.append(palm_end)
    m = m.filter(ImageFilter.GaussianBlur(0.35 * S))
    cut = int((lintel - b.y0) * S)
    ImageDraw.Draw(m).rectangle([0, 0, b.size[0], cut], fill=0)
    # the lintel's shadow on its neck and shoulders, and the feet going into the water
    span = b.y1 - b.y0
    yy = Image.linear_gradient("L").resize(b.size)

    def rows(fn):
        return yy.point(lut(lambda v: 255 * fn(b.y0 + v / 255.0 * span)))

    # Pale. It must lift off the black at a quarter opacity, so the value stays high everywhere and
    # the form is turned by temperature: warm bone-white on the side toward the room, a cold
    # blue-grey on the far side, and only the last stretch of the shins going down into the dark.
    value = rows(lambda y: max(0.0, min(1.0, (y - (feet - 0.22 * H)) / (0.22 * H))))
    lit = Image.new("RGB", b.size, (214, 218, 208))
    cold = Image.new("RGB", b.size, (150, 163, 170))
    side = hgrad(b.size, 0, 255).point(lut(lambda v: 255 * max(0.0, min(1.0, (v / 255.0 - 0.38) / 0.40))))
    fill_rgb = Image.composite(cold, lit, side)
    fill_rgb = Image.composite(Image.new("RGB", b.size, (92, 104, 108)), fill_rgb,
                               value.point(lut(lambda v: v * 0.85)))
    # planes: the collarbones' shelf, the hollow under the ribs, the narrow hips, the knees;
    # painted as cool shadow shapes, soft-edged, inside the figure only
    pl = b.mask()
    pd = ImageDraw.Draw(pl)
    for sgn in (-1, 1):
        pd.line(b.P(smooth_open([(cx + sgn * 2, sh_y + 4), (cx + sgn * 8, sh_y + 6), (cx + sgn * (half - 4), sh_y + 4)],
                                6)), fill=200, width=int(1.3 * S))                        # under the collarbone
        pd.polygon(b.P(smooth_closed([(cx + sgn * 3, Y(0.17)), (cx + sgn * 11, Y(0.15)), (cx + sgn * 12, Y(0.22)),
                                      (cx + sgn * 4, Y(0.24))], 5)), fill=150)            # under the ribcage
        pd.line(b.P(smooth_open([(cx + sgn * 10, Y(0.33)), (cx + sgn * 6, Y(0.40)), (cx + sgn * 2.5, Y(0.45))], 5)),
                fill=150, width=int(1.4 * S))                                            # the hip's crease
        pd.ellipse(b.P([(cx + sgn * 5.5 - 3, Y(0.71) - 2), (cx + sgn * 5.5 + 3, Y(0.71) + 4)]), fill=140)  # knee
        for k in range(3):                                                               # ribs, barely
            ry = Y(0.06 + 0.03 * k)
            pd.line(b.P(smooth_open([(cx + sgn * 3, ry), (cx + sgn * 9, ry + 1.5), (cx + sgn * 13, ry + 4)], 4)),
                    fill=90, width=int(0.9 * S))
    pd.line(b.P([(cx, sh_y + 8), (cx, Y(0.30))]), fill=110, width=int(1.2 * S))           # the sternum's line
    planes = pl.filter(ImageFilter.GaussianBlur(1.1 * S))
    fill_rgb = Image.composite(Image.new("RGB", b.size, (118, 132, 140)), fill_rgb, planes.point(lut(lambda v: v * 0.55)))
    # wet sheen: a few long pale runs down the room side, as if it had just stood up out of the water
    sheen = b.mask()
    sd = ImageDraw.Draw(sheen)
    for k in range(5):
        xx = cx - half * 0.45 + k * 2.6 + rng.uniform(-0.8, 0.8)
        y_a = sh_y + rng.uniform(4, 30)
        y_b = y_a + rng.uniform(60, 190)
        sd.line(b.P([(xx, y_a), (xx + rng.uniform(-1, 1), y_b)]), fill=int(rng.uniform(120, 230)), width=int(0.8 * S))
    fill_rgb = Image.composite(Image.new("RGB", b.size, (238, 242, 236)), fill_rgb,
                               sheen.filter(ImageFilter.GaussianBlur(0.5 * S)).point(lut(lambda v: v * 0.6)))
    # paper grain in the matte paint
    grain_ = noise_mask(b.size, rng, 0.9 * S, 0, 255)
    fill_rgb = ImageChops.add(fill_rgb, Image.merge("RGB", [grain_.point(lut(lambda v: 124 + v * 8 / 255))] * 3),
                              offset=-128)
    under = rows(lambda y: 1.0 if y < feet - 4 else max(0.0, 1.0 - (y - (feet - 4)) / 6.0))
    body_a = ImageChops.multiply(m, under)
    # a faint rim from the room side (the left, where the door stands open): the edge, only above the knee
    inner = body_a.filter(ImageFilter.MinFilter(int(1.6 * S) | 1))
    rim = ImageChops.subtract(body_a, inner)
    rim = ImageChops.multiply(rim, hgrad(b.size, 255, 60))
    rim = ImageChops.multiply(rim, rows(lambda y: max(0.0, 1.0 - (y - sh_y) / (H * 0.75))))
    rim = scale_alpha(rim.filter(ImageFilter.GaussianBlur(0.5 * S)), 0.7)
    shade = rows(lambda y: max(0.0, 1.0 - (y - lintel) / 22.0) ** 1.4)
    shade = scale_alpha(ImageChops.multiply(shade, body_a), 0.55)
    ink = ink_edge(body_a, rng, S, 1.9, 0.6, 1.0)
    ImageDraw.Draw(ink).rectangle([0, 0, b.size[0], cut], fill=0)
    # its reflection: upside down in the standing water, dark, broken into level slivers
    refl = m.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    off = (2 * feet - b.y0 - b.y1) * S
    refl = refl.transform(b.size, Image.AFFINE, (1, 0, 0, 0, 1, -off))
    ripple = Image.new("L", b.size, 0)
    rd = ImageDraw.Draw(ripple)
    y = feet + 0.5
    while y < b.y1:
        shift = rng.uniform(-1.5, 1.5) * S
        rd.rectangle([shift, (y - b.y0) * S, b.size[0] + shift, (y - b.y0 + rng.uniform(1.8, 3.4)) * S],
                     fill=int(rng.uniform(150, 255)))
        y += rng.uniform(2.6, 4.2)
    ripple = ripple.filter(ImageFilter.GaussianBlur(0.9 * S))
    depth = rows(lambda y: 0.0 if y < feet else max(0.0, 1.0 - (y - feet) / 64.0) ** 1.1)
    refl = ImageChops.multiply(ImageChops.multiply(refl, ripple), depth)
    refl = scale_alpha(refl.filter(ImageFilter.GaussianBlur(1.0 * S)), 0.6)
    waterline = b.mask()
    ImageDraw.Draw(waterline).line(b.P([(cx - 14, feet + 0.6), (cx + 14, feet + 0.6)]), fill=200, width=int(0.9 * S))
    waterline = ImageChops.multiply(waterline, m.filter(ImageFilter.MaxFilter(int(6 * S) | 1)).transform(
        b.size, Image.AFFINE, (1, 0, 0, 0, 1, -2 * S)))
    img = b.finish([((128, 140, 142), refl), (fill_rgb, body_a), ((40, 52, 62), shade), ((240, 244, 238), rim),
                    (NAVY_INK, ink), ((150, 166, 166), scale_alpha(waterline.filter(ImageFilter.GaussianBlur(0.4 * S)),
                                                                   0.6))])
    # registered to the corridor as the game shows it at the top of the breath (swelled about GAME_VP)
    k = 1.0 / PEAK_SWELL
    img = img.transform(CANVAS, Image.AFFINE, (k, 0, GAME_VP[0] * (1 - k), 0, k, GAME_VP[1] * (1 - k)),
                        resample=Image.BICUBIC)
    r_, g_, b_, a_ = img.split()
    zero = a_.point(lambda v: 255 if v else 0)
    img = Image.merge("RGBA", [ImageChops.multiply(ch, zero) for ch in (r_, g_, b_)] + [a_])
    img.save(OUT / "threshold_figure.png", optimize=False)


# ---------------------------------------------------------------------------
# palms_glass
# ---------------------------------------------------------------------------
PANE = (483, 368, 800, 545)


def hand_shape(heel, lean, mirror, scale=1.0):
    """A hand pressed flat, fingers up, the fingers 1.6x too long for the palm.
    Returns (palm polygon, fingers [(pts, half-width, joints)], thumb)."""
    hx, hy = heel
    c, s = math.cos(lean), math.sin(lean)

    def T(px, py):
        px *= mirror * scale
        py *= scale
        return (hx + px * c - py * s, hy + px * s + py * c)

    palm = [T(*p) for p in smooth_closed([(-11, 0), (-15, -10), (-15.5, -24), (-12, -31), (0, -33),
                                         (12, -31), (14.5, -24), (14, -10), (9, 0)], 6)]
    fingers = []
    # fingers 1.8x the palm's length: three phalanges each, the joints a hair crooked
    for fx, ln, tilt in [(-10.8, 50, -0.12), (-3.7, 60, -0.035), (3.5, 57, 0.035), (10.2, 45, 0.12)]:
        pts, a, px, py = [], tilt, fx, -29.0
        pts.append(T(px, py))
        joints = []
        for frac, bend in ((0.44, 0.03), (0.31, -0.05), (0.25, 0.04)):
            px, py = px + math.sin(a) * ln * frac, py - math.cos(a) * ln * frac
            a += bend
            pts.append(T(px, py))
            joints.append(T(px, py))
        fingers.append((pts, 3.0 * scale, joints[:2], tilt + lean))
    thumb = ([T(-14, -9), T(-21, -17), T(-27, -28), T(-31, -40)], 3.5 * scale, [T(-21, -17), T(-27, -28)],
             lean - 0.9 * mirror)
    return palm, fingers, thumb


def palms_glass():
    """Condensation on the outside of the lower pane, three hands wiped clear through it, each
    higher than the last. The fog is a matte veil; the wiped glass is clear and cool, haloed by
    the film it pushed aside, and each wipe dragged down before it lifted."""
    rng = rng_for("palms_glass")
    x0, y0, x1, y1 = PANE
    b = Box((x0, y0, x1, y1), ss=4)
    S = b.ss
    # the film: a matte veil, alpha ~0.12-0.18, heavier toward the bottom where it pools
    film = noise_mask(b.size, rng, 6 * S, 50, 68)
    film = ImageChops.add(film, vgrad(b.size, 0, 12))
    beads = Image.new("L", b.size, 0)
    bd = ImageDraw.Draw(beads)
    for _ in range(1400):
        bx, by = rng.uniform(0, b.size[0]), rng.uniform(0, b.size[1])
        r = rng.uniform(0.3, 1.0) * S
        bd.ellipse([bx - r, by - r, bx + r, by + r], fill=int(rng.uniform(40, 90)))
    film = ImageChops.lighter(film, beads.filter(ImageFilter.GaussianBlur(0.35 * S)))
    wiped = b.mask()                  # fully cleared glass
    wd = ImageDraw.Draw(wiped)
    partial = b.mask()                # smeared: thinned film
    pd = ImageDraw.Draw(partial)
    creases = b.mask()                # film left across each finger at the joints
    cd = ImageDraw.Draw(creases)
    tracks = b.mask()                 # drip tracks cut through the fog
    td = ImageDraw.Draw(tracks)
    glints = b.mask()
    gd = ImageDraw.Draw(glints)
    # each higher than the last; the third well right of the rings, over the pier's dark
    hands = [((515, 541), -0.10, 1, 0.80), ((545, 499), 0.05, -1, 0.84), ((752, 459), 0.10, 1, 0.82)]
    for (hx, hy), lean, mirror, sc in hands:
        palm, fingers, thumb = hand_shape((hx, hy), lean, mirror, sc)
        wd.polygon(b.P(palm), fill=255)
        for pts, hw, joints, ang in fingers + [thumb]:
            sm = smooth_open(pts, 6)
            taper(wd, b.P, S, sm, hw * 2.1, hw * 1.65)
            for jx, jy in joints:                      # knuckle pads press wider than the joints
                r = hw * 1.12 * S
                (qx, qy), = b.P([(jx, jy)])
                wd.ellipse([qx - r, qy - r, qx + r, qy + r], fill=255)
            tx, ty = sm[-1]
            r = hw * 0.85 * S
            px_, py_ = b.P([(tx, ty)])[0]
            wd.ellipse([px_ - r, py_ - r, px_ + r, py_ + r], fill=255)
            # a thin bridge of film left in the crease at each joint
            for jx, jy in joints:
                nx, ny = math.cos(ang) * hw * 1.05, math.sin(ang) * hw * 1.05
                cd.line(b.P([(jx - nx, jy - ny), (jx + nx, jy + ny)]), fill=150, width=max(1, int(0.7 * S)))
            # each fingertip dragged a little way down before the hand lifted: a thinned streak
            drag = rng.uniform(2.0, 7.0)
            pd.line(b.P([(tx, ty), (tx + rng.uniform(-0.6, 0.6), ty + drag)]), fill=int(rng.uniform(120, 200)),
                    width=max(1, int(hw * rng.uniform(1.0, 1.7) * S)))
        # the heel slid DOWN: a broad smear below it, thinning, ragged at its end
        smear_len = rng.uniform(9, 17)
        smear = smooth_closed([(hx - 12 * sc, hy - 16), (hx + 10 * sc, hy - 16), (hx + 8, hy + smear_len * 0.55),
                               (hx + 3, hy + smear_len), (hx - 3, hy + smear_len * 0.8), (hx - 9, hy + 3)], 6)
        pd.polygon(b.P(smear), fill=210)
        for _ in range(5):                      # streaks in the smear where the skin's ridges dragged
            sx = hx + rng.uniform(-9, 7)
            pd.line(b.P([(sx, hy - 4), (sx + rng.uniform(-1, 1), hy + smear_len * rng.uniform(0.7, 1.3))]),
                    fill=255, width=max(1, int(rng.uniform(0.6, 1.6) * S)))
        # drips: two or three, each its own length and weight; a clear track, a bead at its head
        for k in range(rng.choice((2, 3, 3))):
            sx = hx + rng.uniform(-9, 8)
            sy = hy + smear_len * rng.uniform(0.4, 0.9)
            end = sy + (y1 - sy) * (1.0 if k == 0 else rng.uniform(0.25, 0.8))
            w0 = [rng.uniform(2.8, 4.2), rng.uniform(1.0, 1.8), rng.uniform(1.6, 2.6)][k]
            pts, xx, yy = [(sx, sy)], sx, sy
            while yy < end:
                yy = min(end, yy + rng.uniform(3, 8))
                xx += rng.uniform(-0.7, 0.7)
                pts.append((xx, yy))
            n = max(1, len(pts) - 1)
            for i, ((ax, ay), (bx2, by2)) in enumerate(zip(pts, pts[1:])):
                t = i / n
                wdt = w0 * (1.0 - 0.6 * t) * (1.0 + 0.35 * math.sin(i * 1.7 + w0 * 3.1) ** 8)
                td.line(b.P([(ax, ay), (bx2, by2)]), fill=255, width=max(1, int(wdt * S)))
                gd.line(b.P([(ax + wdt * 0.3, ay), (bx2 + wdt * 0.3, by2)]),
                        fill=int(255 * 0.5 * (1.0 - t) ** 0.8), width=max(1, int(0.8 * S)))
            ex, ey = pts[-1]
            r = w0 * 0.75
            td.ellipse(b.P([(ex - r, ey - r * 0.6), (ex + r, ey + r * 1.4)]), fill=255)
            gd.ellipse(b.P([(ex - r * 0.6, ey - r * 0.3), (ex + r * 0.3, ey + r * 0.9)]), fill=150)
    wiped = wiped.filter(ImageFilter.GaussianBlur(0.5 * S))
    creases = creases.filter(ImageFilter.GaussianBlur(0.35 * S))
    wiped = ImageChops.subtract(wiped, creases.point(lut(lambda v: v * 0.75)))
    partial = partial.filter(ImageFilter.GaussianBlur(0.8 * S))
    tracks = tracks.filter(ImageFilter.GaussianBlur(0.3 * S))
    cleared = ImageChops.lighter(wiped, ImageChops.lighter(partial.point(lut(lambda v: v * 0.7)), tracks))
    film_a = ImageChops.multiply(film, ImageChops.invert(cleared))
    # the halo: film pushed aside piles up at the wipe's edge, bright and matte
    halo = ImageChops.subtract(wiped.filter(ImageFilter.MaxFilter(int(2.6 * S) | 1)), wiped)
    halo = ImageChops.lighter(halo, ImageChops.subtract(tracks.filter(ImageFilter.MaxFilter(int(1.5 * S) | 1)),
                                                        tracks).point(lut(lambda v: v * 0.6)))
    halo = ImageChops.multiply(halo.filter(ImageFilter.GaussianBlur(0.5 * S)), noise_mask(b.size, rng, 2.5 * S, 70, 165))
    # clean glass: a touch darker and cooler than the fogged glass round it
    clean = scale_alpha(ImageChops.lighter(wiped, tracks), 0.42)
    img = b.finish([((222, 230, 230), film_a), ((14, 26, 34), clean), ((236, 242, 240), halo),
                    ((228, 238, 238), glints.filter(ImageFilter.GaussianBlur(0.35 * S)))])
    img.save(OUT / "palms_glass.png", optimize=False)


# ---------------------------------------------------------------------------
# prints_drawer
# ---------------------------------------------------------------------------
FLOOR_SQUASH = 0.58          # the floor is seen steeply in the elevation: prints foreshorten
PLATE = ROOT / "assets" / "backgrounds" / "office_arrival.png"
# The shared wet-mark recipe (also asked of prints_door, away_puddle, away_door): darken the
# surface underneath by multiply ~0.7, soft edge, one pale highlight on the window side, no rim.
WET_MULTIPLY = 0.70


def foot(heel_mid, direction, left, scale=1.0):
    """A narrow bare sole with FOUR long, splayed toes, in floor coordinates, projected to the
    elevation. `direction` is the walking angle on the floor (0 = toward +x)."""
    cx, cy = heel_mid
    c, s = math.cos(direction), math.sin(direction)
    flip = 1 if left else -1

    def T(u, v):
        fx = u * c - v * flip * s
        fy = u * s + v * flip * c
        return (cx + fx * scale, cy + fy * scale * FLOOR_SQUASH)

    # one continuous print: heel, a narrow arch, the ball, and a toe pad the toes grow out of, so the
    # toes are joined to the sole by a web of wet and only their tips stand apart
    sole = [T(*p) for p in smooth_closed([(-15, 0), (-13, -4.4), (-4, -3.0), (4, -3.6), (11, -6.2),
                                         (17.5, -7.4), (20.5, -4.0), (21.0, 0.0), (20.5, 4.0), (17.5, 7.2),
                                         (11, 6.0), (4, 3.2), (-4, 2.4), (-13, 4.0)], 6)]
    toes = []
    # four toes, longer than toes are and fanned wide, their roots buried in the pad
    for (u0, v0, ang, ln, w) in [(17.0, -5.4, -0.32, 6.0, 3.3), (18.4, -1.9, -0.10, 7.0, 3.1),
                                 (18.2, 1.9, 0.10, 6.5, 2.9), (16.6, 5.4, 0.34, 5.2, 2.7)]:
        u1, v1 = u0 + math.cos(ang) * ln, v0 + math.sin(ang) * ln
        toes.append(([T(u0, v0), T((u0 + u1) / 2, (v0 + v1) / 2), T(u1, v1)], w * scale))
    return sole, toes


def prints_drawer():
    rng = rng_for("prints_drawer")
    b = Box((930, 900, 1150, 1086), ss=4)
    S = b.ss
    start = (1100.0, 945.0)
    end = (972.0, 1046.0)            # stops ~20 px short of where the second trail (to the door) begins
    dx, dy = end[0] - start[0], (end[1] - start[1]) / FLOOR_SQUASH
    walk = math.atan2(dy, dx)
    length = math.hypot(end[0] - start[0], end[1] - start[1])
    n = int(length // 38) + 1
    sx, sy = (end[0] - start[0]) / length, (end[1] - start[1]) / length
    side = (-sy, sx)
    steps = []
    for i in range(n):
        p = (start[0] + sx * 38 * i, start[1] + sy * 38 * i)
        left = i % 2 == 0
        off = 6.5 if left else -6.5
        steps.append(((p[0] + side[0] * off, p[1] + side[1] * off), walk + rng.uniform(-0.06, 0.06), left, 1.0))
    # It stopped in front of the drawer and turned to face it: both feet, toes to the pedestal.
    up = -math.pi / 2
    steps.append(((956.0, 1056.0), up - 0.14, True, 1.0))
    steps.append(((983.0, 1052.0), up + 0.10, False, 1.0))
    # the shared recipe: full strength, and the fade carried by alpha in the last three prints only
    for j, k in zip((-3, -2, -1), (0.86, 0.74, 0.64)):
        pos, ang, left, _ = steps[j]
        steps[j] = (pos, ang, left, k)
    wet = b.mask()
    wdraw = ImageDraw.Draw(wet)
    hl = b.mask()
    hdraw = ImageDraw.Draw(hl)
    for pos, ang, left, k in steps:
        sole, toes = foot(pos, ang, left, 1.0)
        a = int(255 * k)
        wdraw.polygon(b.P(sole), fill=a)
        for pts, w in toes:
            taper(wdraw, b.P, S, pts, w * 1.0, w * 0.8, fill=a)
            (tx, ty), = b.P([pts[-1]])                          # a rounded pad at each tip
            r = w * 0.5 * S
            wdraw.ellipse([tx - r, ty - r * FLOOR_SQUASH * 1.2, tx + r, ty + r * FLOOR_SQUASH * 1.2], fill=a)
        # one pale highlight per print, on the window side (up and to the left): the ball's edge
        hx = pos[0] + math.cos(ang) * 7 - 3.0
        hy = pos[1] + math.sin(ang) * 7 * FLOOR_SQUASH - 1.6
        hdraw.line(b.P(smooth_open([(hx - 3.5, hy + 0.6), (hx, hy - 0.4), (hx + 3.0, hy + 0.2)], 4)),
                   fill=int(255 * k), width=max(1, int(1.0 * S)))
    # drops shaken off between steps
    for i in range(len(steps) - 2):
        (ax, ay), (cx2, cy2) = steps[i][0], steps[i + 1][0]
        for _ in range(2):
            t = rng.uniform(0.2, 0.8)
            px, py = ax + (cx2 - ax) * t + rng.uniform(-6, 6), ay + (cy2 - ay) * t + rng.uniform(-3, 3)
            r = rng.uniform(0.9, 1.7)
            wdraw.ellipse(b.P([(px - r, py - r * 0.6), (px + r, py + r * 0.6)]), fill=int(rng.uniform(140, 210)))
    wet = wet.filter(ImageFilter.GaussianBlur(0.7 * S))            # soft wet edge, no outline
    # wetness is uneven: the floorboard grain shows through a little
    wet = ImageChops.multiply(wet, noise_mask(b.size, rng, 1.4 * S, 205, 255))
    # multiply the floor: overlay colour = floor x 0.45, alpha 0.545 -> floor x 0.70
    k_col = 0.45
    a_full = (1.0 - WET_MULTIPLY) / (1.0 - k_col)
    plate = Image.open(PLATE).convert("RGB").crop((b.x0, b.y0, b.x1, b.y1)).resize(b.size, Image.BICUBIC)
    under = plate.point(lut(lambda v: v * k_col) * 3)
    hl = ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(0.6 * S)), wet)
    img = b.finish([(under, scale_alpha(wet, a_full)), ((214, 222, 218), scale_alpha(hl, 0.55))])
    img.save(OUT / "prints_drawer.png", optimize=False)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    photo("photo_drawer", "drawer")
    photo("photo_drawer_hand", "drawer_hand")
    photo("photo_after", "after")
    photo("photo_turned", "turned")
    threshold_figure()
    palms_glass()
    prints_drawer()
    for name in ("threshold_figure", "photo_drawer", "photo_drawer_hand", "photo_after", "photo_turned",
                 "palms_glass", "prints_drawer"):
        p = OUT / f"{name}.png"
        print(f"{p.relative_to(ROOT)}  {Image.open(p).size}")


if __name__ == "__main__":
    import sys
    only = set(sys.argv[1:])
    if only:
        OUT.mkdir(parents=True, exist_ok=True)
        jobs = {"photo_drawer": lambda: photo("photo_drawer", "drawer"),
                "photo_drawer_hand": lambda: photo("photo_drawer_hand", "drawer_hand"),
                "photo_after": lambda: photo("photo_after", "after"),
                "photo_turned": lambda: photo("photo_turned", "turned"),
                "threshold_figure": threshold_figure, "palms_glass": palms_glass, "prints_drawer": prints_drawer}
        for k in sorted(only):
            jobs[k]()
    else:
        main()
