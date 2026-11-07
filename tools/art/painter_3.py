#!/usr/bin/env python3
"""Painter 3: stage-3 overlays for the Intake Office (The Ninth Tide).

Writes, and only writes:
    assets/stages/prints_door.png      second, wider four-toed trail: drawer -> corridor door
    assets/stages/chart_contours.png   seven graphite soundings round the jetty's seaward end
    assets/stages/away_mug.png         look-away 1: mug brimming with seawater
    assets/stages/away_stove.png       look-away 2: stove door open, full of standing water
    assets/stages/away_coat.png        look-away 3: oilskin hood raised, turned to the desk
    assets/stages/away_door.png        look-away 4: seawater seeping under the corridor door
    assets/stages/away_puddle.png      look-away 5: four-toed prints walking up the wall
    assets/stages/away_window.png      look-away 6: a fourth wiped hand, high on the upper sash

Every image is a 1448x1086 RGBA overlay, transparent except the change, registered
to assets/backgrounds/office_arrival.png (read only, for measurements and palette).

Python 3 + PIL only. Deterministic: one random.Random per asset, seeded from SEED and
the asset name; no wall clock, no PIL noise effects. A second run is byte-identical.

    python3 tools/art/painter_3.py            # paint all eight
    python3 tools/art/painter_3.py away_mug   # paint one
"""
import hashlib
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PLATE = os.path.join(ROOT, "assets", "backgrounds", "office_arrival.png")
OUT_DIR = os.path.join(ROOT, "assets", "stages")
W, H = 1448, 1086
SEED = 0x9D7E3
SS = 4  # supersampling for every painted shape

# Palette, sampled from the approved plates.
INK = (23, 43, 54)            # fine navy contour
WET = (15, 23, 31)            # Color(0.06, 0.09, 0.12): wet tone on wood and paint
SEA = (17, 34, 41)            # dark seawater, storm navy with a green cast
SEA_DEEP = (7, 14, 19)
SHEEN = (196, 212, 208)       # pale wet highlight, sea-glass tinted
RIM = (186, 198, 194)         # pale dried rim round a wet print
GRAPHITE = (64, 64, 71)       # Color(0.25, 0.25, 0.28)
GRAPHITE_DARK = (40, 40, 46)
COAT = (43, 51, 61)
COAT_LIT = (62, 71, 84)
IRON = (39, 47, 57)
IRON_LIT = (58, 66, 77)
FILM = (205, 214, 214)        # condensation on glass


# --------------------------------------------------------------------------- helpers

def rng_for(name):
    return random.Random("%d:%s" % (SEED, name))


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c0, c1, t):
    return tuple(int(round(lerp(a, b, t))) for a, b in zip(c0, c1))


def scale_l(mask, k):
    """Multiply an L image by a constant."""
    lut = [int(round(clamp(v * k / 255.0) * 255)) for v in range(256)]
    return mask.point(lut)


def ramp(mask, lo, hi):
    """Smooth threshold: 0 below lo, 255 above hi (antialiased union of blurred shapes)."""
    lut = []
    for v in range(256):
        t = clamp((v - lo) / float(max(1, hi - lo)))
        lut.append(int(round(t * t * (3 - 2 * t) * 255)))
    return mask.point(lut)


def blur(mask, px):
    return mask.filter(ImageFilter.GaussianBlur(px * SS)) if px > 0 else mask


def grow(mask, px):
    """Dilate by about px (1x units) via blur + low threshold."""
    return ramp(blur(mask, px * 0.6), 6, 40)


def shrink(mask, px):
    return ramp(blur(mask, px * 0.6), 215, 249)


def noise(rng, w, h, cell, lo=0.0, hi=1.0):
    """Smooth value noise in [lo, hi] as an L image (cell = feature size in px)."""
    sw, sh = max(2, int(w / cell) + 2), max(2, int(h / cell) + 2)
    raw = rng.randbytes(sw * sh)
    small = Image.frombytes("L", (sw, sh), raw)
    big = small.resize((w, h), Image.BICUBIC)
    lut = [int(round(lerp(lo, hi, v / 255.0) * 255)) for v in range(256)]
    return big.point(lut)


def capsule(p0, p1, r0, r1, n=10):
    """Tapered capsule from p0 (radius r0) to p1 (radius r1) as a polygon."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ang = math.atan2(dy, dx)
    pts = []
    for k in range(n + 1):  # cap round p1
        t = ang - math.pi / 2 + math.pi * k / n
        pts.append((p1[0] + r1 * math.cos(t), p1[1] + r1 * math.sin(t)))
    for k in range(n + 1):  # cap round p0
        t = ang + math.pi / 2 + math.pi * k / n
        pts.append((p0[0] + r0 * math.cos(t), p0[1] + r0 * math.sin(t)))
    return pts


def wobble_path(rng, pts, amp, waves=3.0):
    """Offset a polyline perpendicular to itself by a smooth seeded wobble."""
    ph = [rng.uniform(0, 2 * math.pi) for _ in range(3)]
    n = len(pts)
    out = []
    for i, (x, y) in enumerate(pts):
        a = pts[min(i + 1, n - 1)]
        b = pts[max(i - 1, 0)]
        dx, dy = a[0] - b[0], a[1] - b[1]
        d = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / d, dx / d
        t = i / max(1, n - 1)
        o = amp * (0.6 * math.sin(2 * math.pi * waves * t + ph[0])
                   + 0.3 * math.sin(2 * math.pi * waves * 2.3 * t + ph[1])
                   + 0.1 * math.sin(2 * math.pi * waves * 5.1 * t + ph[2]))
        out.append((x + nx * o, y + ny * o))
    return out


class Tile:
    """A local painting window: shapes are drawn into SS-scaled masks in canvas
    coordinates, then downsampled and composited as flat matte layers."""

    def __init__(self, x0, y0, x1, y1):
        self.x0, self.y0 = x0, y0
        self.w, self.h = x1 - x0, y1 - y0
        self.img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))

    def mask(self):
        return Image.new("L", (self.w * SS, self.h * SS), 0)

    def p(self, x, y):
        return ((x - self.x0) * SS, (y - self.y0) * SS)

    def poly(self, mask, pts, fill=255):
        ImageDraw.Draw(mask).polygon([self.p(x, y) for x, y in pts], fill=fill)

    def rect(self, mask, x0, y0, x1, y1, fill=255):
        ImageDraw.Draw(mask).rectangle([self.p(x0, y0), self.p(x1, y1)], fill=fill)

    def dot(self, mask, x, y, r, fill=255):
        (px, py) = self.p(x, y)
        ImageDraw.Draw(mask).ellipse([px - r * SS, py - r * SS, px + r * SS, py + r * SS], fill=fill)

    def line(self, mask, pts, width, fill=255, round_joins=True):
        d = ImageDraw.Draw(mask)
        sp = [self.p(x, y) for x, y in pts]
        d.line(sp, fill=fill, width=max(1, int(round(width * SS))))
        if round_joins:
            r = width * SS / 2.0
            for (x, y) in sp:
                d.ellipse([x - r, y - r, x + r, y + r], fill=fill)

    def stroke(self, mask, pts, width, alphas):
        """A polyline whose pressure varies per vertex (pencil, drips)."""
        d = ImageDraw.Draw(mask)
        sp = [self.p(x, y) for x, y in pts]
        wpx = max(1, int(round(width * SS)))
        r = width * SS / 2.0
        for i in range(len(sp) - 1):
            v = int(round(clamp(alphas[i]) * 255))
            d.line([sp[i], sp[i + 1]], fill=v, width=wpx)
            d.ellipse([sp[i][0] - r, sp[i][1] - r, sp[i][0] + r, sp[i][1] + r], fill=v)

    def down(self, mask):
        return mask.resize((self.w, self.h), Image.BOX)

    def paint(self, color, mask, alpha=1.0, hires=True):
        a = self.down(mask) if hires else mask
        if alpha != 1.0:
            a = scale_l(a, alpha)
        col = Image.new("RGB", (self.w, self.h), color) if isinstance(color, tuple) else color
        layer = col.convert("RGBA")
        layer.putalpha(a)
        self.img = Image.alpha_composite(self.img, layer)

    def gradient(self, c0, c1, y0, y1, horizontal=False):
        """A flat two-colour ramp in canvas coordinates (for water depth)."""
        g = Image.new("RGB", (self.w, self.h))
        px = g.load()
        for j in range(self.h if not horizontal else self.w):
            pos = (self.y0 + j) if not horizontal else (self.x0 + j)
            c = mix(c0, c1, clamp((pos - y0) / float(max(1, y1 - y0))))
            if horizontal:
                for i in range(self.h):
                    px[j, i] = c
            else:
                for i in range(self.w):
                    px[i, j] = c
        return g

    def grain(self, rng, amount):
        """Matte paper tooth: modulate alpha by fine seeded speckle (2-4%)."""
        r, g, b, a = self.img.split()
        n = noise(rng, self.w, self.h, 1.3, 1.0 - amount, 1.0)
        self.img = Image.merge("RGBA", (r, g, b, ImageChops.multiply(a, n)))

    def clip(self, mask_1x):
        r, g, b, a = self.img.split()
        self.img = Image.merge("RGBA", (r, g, b, ImageChops.multiply(a, mask_1x)))


def new_canvas():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def place(canvas, tile):
    canvas.alpha_composite(tile.img, dest=(tile.x0, tile.y0))


def save(canvas, name):
    os.makedirs(OUT_DIR, exist_ok=True)
    # Zero the colour of fully transparent pixels so the file is canonical.
    r, g, b, a = canvas.split()
    keep = a.point(lambda v: 255 if v else 0)
    blank = Image.new("L", canvas.size, 0)
    canvas = Image.merge("RGBA", (Image.composite(r, blank, keep), Image.composite(g, blank, keep),
                                  Image.composite(b, blank, keep), a))
    path = os.path.join(OUT_DIR, name + ".png")
    canvas.save(path, "PNG", optimize=False, compress_level=9)
    return path


# --------------------------------------------------------------------------- shared motifs

# One recipe for every wet mark on the floor and the walls (shared with prints_drawer):
# the surface beneath is multiplied by WET_MUL, done as pure black laid at 1 - WET_MUL
# alpha (black at alpha a is exactly a multiply by 1 - a, so the hue of the floor, the
# wainscot or the plaster is kept whatever plate and light it lands on). The edge is soft,
# there is no outline, and a single pale highlight sits on the side facing the window.
# Fading is carried by alpha alone, in the last prints of a trail only.
WET_MUL = 0.70
SHEEN_WET = (214, 222, 218)
LIGHT = (-1.0, -1.0)          # direction toward the window, screen space
FLOOR_SQUASH = 0.58           # the floor is seen steeply in the elevation (as prints_drawer)
TIDE_Y = 512.0                # the stage-3 tide line on the back wall (office_s3)


def foot_parts(cx, cy, ang, left, su=1.0, sv=1.0, squash=1.0):
    """A narrow bare sole with four long, splayed toes, heel-centre at (cx, cy), walking
    along `ang` in floor (or wall) coordinates, projected by `squash`. The toes grow out
    of the ball through a pad bridge, so the print is one wet shape, not a stamp.
    Returns (polygons, capsules) where capsules are (p0, p1, r0, r1)."""
    c, s = math.cos(ang), math.sin(ang)
    flip = 1.0 if left else -1.0

    def T(u, v):
        u *= su
        v *= sv * flip
        return (cx + u * c - v * s, cy + (u * s + v * c) * squash)

    sole = [(-15.5, 0.0), (-14.6, -3.4), (-11.0, -4.8), (-6.0, -3.9), (-1.0, -3.0), (4.0, -3.8),
            (10.0, -5.8), (14.5, -5.6), (17.0, -3.2), (17.5, 0.0), (17.0, 3.2), (14.5, 5.6),
            (10.0, 5.8), (4.0, 3.4), (-1.0, 2.4), (-6.0, 3.2), (-11.0, 4.6), (-14.6, 3.3)]
    polys = [[T(u, v) for (u, v) in sole]]
    # The bridge: a pad under the toe roots, a little proud of the ball.
    polys.append([T(u, v) for (u, v) in ((14.0, -6.6), (18.6, -6.2), (20.4, -2.0), (20.4, 2.0),
                                         (18.4, 6.0), (14.0, 6.0))])
    caps = []
    # Four toes, too long and fanned: (root u, root v, angle, length, root r, pad r).
    for (u0, v0, a, ln, r0, r1) in ((18.0, -4.6, -0.26, 6.6, 1.5, 1.9), (19.2, -1.5, -0.08, 7.6, 1.4, 1.75),
                                    (19.0, 1.6, 0.09, 7.0, 1.35, 1.65), (17.6, 4.6, 0.28, 5.6, 1.25, 1.55)):
        u1, v1 = u0 + math.cos(a) * ln, v0 + math.sin(a) * ln
        caps.append((T(u0, v0), T(u1, v1), r0 * sv, r1 * sv))
    return polys, caps


def foot_mask(tile, cx, cy, ang, left, su, sv, squash):
    m = tile.mask()
    polys, caps = foot_parts(cx, cy, ang, left, su, sv, squash)
    for pg in polys:
        tile.poly(m, pg)
    for (p0, p1, r0, r1) in caps:
        # flatten the capsule polygon the same way as the sole
        tile.poly(m, capsule(p0, p1, r0, r1, 8))
    return ramp(blur(m, 0.55), 100, 150)


def window_edge(mask, px=1.2, light=LIGHT):
    """The part of a shape's edge that faces the light."""
    sh = ImageChops.offset(mask, int(round(-light[0] * px * SS)), int(round(-light[1] * px * SS)))
    return ImageChops.subtract(mask, sh)


def paint_wet(tile, rng, body, gleam, mul=WET_MUL, hi=0.5, soft=0.6):
    """The shared wet recipe. `body` is an SS mask whose value is the wetness (0..255),
    `gleam` an SS mask of window-side highlight strength."""
    b = blur(body, soft)
    b = ImageChops.multiply(b, noise(rng, tile.w * SS, tile.h * SS, 1.4 * SS, 0.80, 1.0))
    tile.paint((0, 0, 0), b, 1.0 - mul)
    g = ImageChops.multiply(blur(gleam, 0.5), b)
    tile.paint(SHEEN_WET, g, hi)


def paint_feet(tile, feet, light=LIGHT):
    """feet: (cx, cy, ang, left, su, sv, squash, wet). Returns (body, gleam) SS masks."""
    body, gleam = tile.mask(), tile.mask()
    for (cx, cy, ang, left, su, sv, squash, wet) in feet:
        m = foot_mask(tile, cx, cy, ang, left, su, sv, squash)
        body = ImageChops.lighter(body, scale_l(m, wet))
        # one highlight per print: the ball's and toes' window-side edge
        e = window_edge(m, 1.0, light)
        gleam = ImageChops.lighter(gleam, scale_l(e, wet))
    return body, gleam


def hand_shapes(hx, hy, ang=-math.pi / 2, thumb_side=-1.0, rng=None, scale=1.0):
    """A hand pressed flat, heel at (hx, hy), fingers along `ang`; the fingers about 1.6x
    too long for the palm. Returns (pads, creases): pads are polygons that touched the
    glass; creases are polylines (and widths) where the skin did not."""
    fx, fy = math.cos(ang), math.sin(ang)
    sx, sy = -fy, fx

    def T(u, v):
        return (hx + (u * fx + v * sx) * scale, hy + (u * fy + v * sy) * scale)

    jit = (lambda a: rng.uniform(-a, a)) if rng else (lambda a: 0.0)
    pads, creases = [], []
    ts = thumb_side
    palm = [(3, -11.5), (0.5, -6), (0, 0), (1.5, 6), (5, 11.5), (13, 14.5), (24, 15.5), (30, 13.5),
            (32, 6), (32.5, -2), (31.5, -10), (27, -14.5), (14, -14), (7, -13.5)]
    pads.append([T(u, v * ts) for (u, v) in palm])
    # Heel split: the pads either side of the life line.
    creases.append(([T(u, v * ts) for (u, v) in ((4.0, 3.5), (10, 2.2), (17, 3.8), (22, 8.0))], 0.9))
    creases.append(([T(u, v * ts) for (u, v) in ((21, -13), (23.5, -5), (23.5, 3))], 0.8))
    # Fingers: little .. index (index on the thumb side).
    fingers = [(-11.0, 25.5, 35, 3.1, -0.11), (-3.8, 29.5, 46, 3.5, -0.035),
               (3.6, 30.5, 52, 3.6, 0.01), (10.6, 29.0, 46, 3.4, 0.065)]
    for (v0, u0, ln, r, spread) in fingers:
        v0 *= ts
        sp = (spread + jit(0.015)) * ts
        ln += jit(1.5)
        du, dv = math.cos(sp), math.sin(sp)
        segs = (0.0, 0.42, 0.74, 1.0)
        for i, (a, b) in enumerate(zip(segs, segs[1:])):
            p0 = (u0 + du * ln * a + (1.0 if i else 0.4), v0 + dv * ln * a)
            p1 = (u0 + du * ln * b - 1.0, v0 + dv * ln * b)
            rr = r * (1.0 - 0.13 * b)
            rr0 = r * (1.0 - 0.13 * a) * (1.05 if i == 0 else 1.0)
            pads.append([T(u, v) for (u, v) in capsule(p0, p1, rr0, rr, 8)])
            if i:   # the joint crease across the finger, fog left standing
                jc = (u0 + du * ln * a, v0 + dv * ln * a)
                creases.append(([T(jc[0] + dv * rr * 0.9, jc[1] - du * rr * 1.1),
                                 T(jc[0] - dv * rr * 0.9, jc[1] + du * rr * 1.1)], 0.9))
    # Thumb: low on the palm, angled out; two long segments.
    tb = (9.0, 12.5)
    tang = 0.66 + jit(0.04)
    tl = 26.0
    tm = (tb[0] + math.cos(tang) * tl * 0.52, tb[1] + math.sin(tang) * tl * 0.52)
    te = (tb[0] + math.cos(tang) * tl, tb[1] + math.sin(tang) * tl)
    pads.append([T(u, v * ts) for (u, v) in capsule(tb, (tm[0] - 0.6, tm[1] - 0.6), 5.2, 4.3, 8)])
    pads.append([T(u, v * ts) for (u, v) in capsule((tm[0] + 0.7, tm[1] + 0.7), te, 4.0, 3.5, 8)])
    return pads, creases


# --------------------------------------------------------------------------- assets

def chart_contours():
    """Seven hand-sounded graphite contours round the jetty's seaward end (the ninth piling)."""
    rng = rng_for("chart_contours")
    cx, cy = 333.0, 289.0                 # the bulb at the seaward end of the jetty on the chart
    paper = (149, 201, 368, 443)          # inside the chart's printed border
    t = Tile(140, 192, 378, 455)
    lines = t.mask()
    dots = t.mask()
    # A shared, slightly lopsided basin shape so the rings nest like real soundings.
    shared = [(rng.uniform(0.04, 0.07), rng.uniform(0, 2 * math.pi)),
              (rng.uniform(0.03, 0.05), rng.uniform(0, 2 * math.pi)),
              (rng.uniform(0.015, 0.03), rng.uniform(0, 2 * math.pi))]
    diam = [8 * (115 / 8.0) ** (k / 6.0) for k in range(7)]   # 8 .. 115, tightening inward
    for k, d in enumerate(diam):
        r0 = d / 2.0
        own = [(rng.uniform(0.01, 0.03), rng.uniform(0, 2 * math.pi), rng.choice((3, 4, 5)))
               for _ in range(2)]
        start = rng.uniform(0, 2 * math.pi)
        over = rng.uniform(0.18, 0.34)                         # pencil overshoot at the closure
        n = max(48, int(r0 * 4))
        pts, press = [], []
        for i in range(n + 1):
            th = start + (2 * math.pi + over) * i / n
            f = 1.0
            for j, (a, ph) in enumerate(shared):
                f += a * math.cos((j + 1) * th + ph)
            for (a, ph, m) in own:
                f += a * math.cos(m * th + ph)
            # the end of the line drifts out a hair: the ring did not quite close
            drift = 1.0 + 0.035 * max(0.0, (th - start - 2 * math.pi) / over) if over else 1.0
            r = max(r0 * f * drift, 3.2)
            pts.append((cx + r * math.cos(th), cy + r * 0.94 * math.sin(th)))
            p = 0.56 + 0.05 * math.sin(3.1 * th + k) + rng.uniform(-0.03, 0.03)
            if i < 4:
                p *= 0.6 + 0.1 * i                               # pencil set down
            if i > n - 5:
                p *= 0.55 + 0.09 * (n - i)                       # pencil lifted
            press.append(p)
        width = 1.5 + 0.08 * k + rng.uniform(0.0, 0.15)
        t.stroke(lines, pts, width, press)
        if k >= 4:                                              # sounding marks on the outer rings
            for _ in range(4 + k - 4):
                th = rng.uniform(0, 2 * math.pi)
                f = 1.0 + sum(a * math.cos((j + 1) * th + ph) for j, (a, ph) in enumerate(shared))
                t.dot(dots, cx + r0 * f * math.cos(th), cy + r0 * f * 0.94 * math.sin(th), 1.05, 150)
    # Graphite tooth: the stroke catches the paper grain.
    tooth = noise(rng, t.w * SS, t.h * SS, 1.2 * SS, 0.72, 1.0)
    lines = ImageChops.multiply(lines, tooth)
    # Lighter over the chart's own printed linework, so no printed mark is hidden.
    plate = Image.open(PLATE).convert("L").crop((t.x0, t.y0, t.x0 + t.w, t.y0 + t.h))
    printed = plate.point(lambda v: 255 if v < 110 else 0).filter(ImageFilter.MaxFilter(3))
    printed = printed.resize((t.w * SS, t.h * SS), Image.NEAREST)
    lines = ImageChops.subtract(lines, scale_l(ImageChops.multiply(lines, printed), 0.3))
    t.paint(GRAPHITE, lines)
    t.paint(GRAPHITE, dots, 0.8)
    # The centre, gone over again and again until the graphite burnished: a heavy dot
    # with a few tight overstrokes round it and a dull lead shine.
    centre = t.mask()
    t.dot(centre, cx, cy, 3.3)
    t.dot(centre, cx + 0.5, cy - 0.4, 2.4)
    for k in range(5):
        r = 3.6 + 0.35 * k
        ph = rng.uniform(0, 2 * math.pi)
        t.stroke(centre, [(cx + r * math.cos(ph + th) + 0.3 * k, cy + 0.94 * r * math.sin(ph + th))
                          for th in [j * 0.35 for j in range(12)]], 0.9, [0.55] * 12)
    t.paint((30, 30, 36), centre, 0.95)
    shine = t.mask()
    t.stroke(shine, [(cx - 2.0, cy - 0.6), (cx - 0.8, cy - 1.9), (cx + 0.8, cy - 2.2)], 0.8, [0.5, 0.9, 0.4])
    t.paint((128, 128, 138), blur(shine, 0.3), 0.55)
    clipm = Image.new("L", (t.w, t.h), 0)
    ImageDraw.Draw(clipm).rectangle([paper[0] - t.x0, paper[1] - t.y0, paper[2] - t.x0, paper[3] - t.y0], fill=255)
    t.clip(clipm)
    t.grain(rng, 0.04)
    c = new_canvas()
    place(c, t)
    return c


def prints_door():
    """Her own trail, a little wider than the drawer trail: from in front of the drawer
    (starting about 25 px clear of where that trail stops) to the corridor door sill.
    Same wet recipe as prints_drawer; only the last three prints fade, by alpha."""
    rng = rng_for("prints_door")
    t = Tile(960, 870, 1290, 1086)
    a, b = (1020.0, 1069.0), (1236.0, 905.0)
    n = 8
    walk = math.atan2((b[1] - a[1]) / FLOOR_SQUASH, b[0] - a[0])     # on the floor plane
    dx, dy = b[0] - a[0], b[1] - a[1]
    d = math.hypot(dx, dy)
    side = (-dy / d, dx / d)
    fade = {n - 3: 0.72, n - 2: 0.46, n - 1: 0.22}
    feet = []
    for i in range(n):
        k = i / (n - 1.0)
        left = (i % 2 == 0)
        off = (1.0 if left else -1.0) * 7.0
        x = lerp(a[0], b[0], k) + side[0] * off + rng.uniform(-1.2, 1.2)
        y = lerp(a[1], b[1], k) + side[1] * off + rng.uniform(-0.8, 0.8)
        ang = walk + rng.uniform(-0.06, 0.06) + (-0.06 if left else 0.06)
        feet.append((x, y, ang, left, 1.04, 1.18, FLOOR_SQUASH, fade.get(i, 1.0)))
    body, gleam = paint_feet(t, feet)
    # a few drops shaken off between the first, wettest steps
    for i in range(3):
        (ax, ay), (bx, by) = feet[i][:2], feet[i + 1][:2]
        for _ in range(2):
            u = rng.uniform(0.25, 0.75)
            r = rng.uniform(0.8, 1.5)
            px, py = lerp(ax, bx, u) + rng.uniform(-5, 5), lerp(ay, by, u) + rng.uniform(-3, 3)
            m = t.mask()
            t.poly(m, [(px + r * math.cos(th), py + r * 0.6 * math.sin(th))
                       for th in [2 * math.pi * j / 12 for j in range(12)]])
            body = ImageChops.lighter(body, scale_l(m, rng.uniform(0.55, 0.85)))
    paint_wet(t, rng, body, gleam)
    t.grain(rng, 0.03)
    c = new_canvas()
    place(c, t)
    return c


def away_mug():
    """The mug brimming with seawater: a thin dark meniscus barely proud of the rim,
    holding the window's green in its skin; one irregular sheet slipping over the front
    lip and down the enamel; a matte wet stain soaking into the desk."""
    rng = rng_for("away_mug")
    t = Tile(895, 655, 1025, 760)
    x0, x1, rim = 924.0, 972.5, 671.3        # the mug's outer walls and the top of its lip
    # Meniscus: convex, at most ~2.4 px above the lip, pinned at both walls.
    top = []
    for k in range(61):
        u = k / 60.0
        h = 3.1 * (1.0 - abs(2 * u - 1) ** 2.6) ** 0.5
        top.append((lerp(x0 - 0.5, x1 + 0.5, u), rim - h))
    m_men = t.mask()
    t.poly(m_men, top + [(x1 + 0.6, rim + 1.6), (x0 - 0.6, rim + 1.6)])
    # The sheet: one tongue over the front lip, left of centre, its edges wandering;
    # it necks under the lip, fattens over the belly, and frays out at the foot.
    left_edge, right_edge = [], []
    n = 40
    for i in range(n + 1):
        v = i / float(n)
        y = rim + 0.6 + v * (724.0 - rim - 0.6)
        cx = 937.5 + 2.2 * math.sin(v * 2.4 + 0.4) + 1.2 * v
        half = 5.2 - 2.4 * math.sin(math.pi * min(1.0, v * 3.2)) * (1 - v) + 3.4 * v ** 2.2
        left_edge.append((cx - half * (1.0 + 0.10 * math.sin(v * 13.0)), y))
        right_edge.append((cx + half * (1.0 + 0.12 * math.sin(v * 9.0 + 1.3)), y))
    sheet_pts = wobble_path(rng, left_edge, 0.45, 3.0) + wobble_path(rng, right_edge[::-1], 0.45, 2.6)
    m_sheet = t.mask()
    t.poly(m_sheet, sheet_pts)
    m_sheet = ramp(blur(m_sheet, 0.5), 90, 160)
    # A shorter, thinner lick further right, stopping half way down the belly.
    m_lick = t.mask()
    lick = wobble_path(rng, [(958.0 + 0.3 * math.sin(i * 0.7), rim + 0.8 + i * 1.55) for i in range(17)], 0.3, 1.1)
    for i in range(len(lick) - 1):
        r = 1.5 * (1.0 - 0.55 * i / len(lick))
        t.poly(m_lick, capsule(lick[i], lick[i + 1], r, r * 0.95, 6))
    # The lip is wet all round: water stood over it.
    m_lip = t.mask()
    t.rect(m_lip, x0, rim, x1, rim + 3.6)
    # On the desk: water out on the top board, soaked into the wood front, matte.
    m_desk = t.mask()
    t.poly(m_desk, wobble_path(rng, [(911, 725.0), (921, 723.8), (952, 723.6), (968, 724.2), (984, 725.2),
                                     (962, 726.6), (930, 726.6), (914, 726.3)], 0.3, 2))
    stain = [(906, 727.0), (921, 726.5), (948, 726.5), (967, 726.6), (986, 727.0), (984, 728.8),
             (975, 731.0), (966, 729.6), (957, 731.8), (950, 735.6), (945, 741.0), (941, 742.2),
             (938, 738.0), (933, 734.6), (926, 735.4), (919, 731.2), (911, 730.4)]
    m_stain = t.mask()
    t.poly(m_stain, wobble_path(rng, stain + stain[:1], 0.6, 4)[:-1])
    m_stain = ramp(blur(m_stain, 1.0), 70, 190)

    # Wetting first: everything wet is multiplied darker, as the floor prints are.
    wet = ImageChops.lighter(ImageChops.lighter(m_sheet, scale_l(m_lick, 0.85)), scale_l(m_lip, 0.7))
    t.paint((0, 0, 0), blur(wet, 0.4), 0.34)
    t.paint((0, 0, 0), m_stain, 0.40)
    t.paint((0, 0, 0), ImageChops.subtract(m_stain, shrink(m_stain, 1.4)), 0.10)  # a soft, dried margin
    # Water on the desk top: a dark film, its back edge catching the window.
    t.paint((14, 24, 28), m_desk, 0.62)
    # The sheet is water over green enamel: a cool, glassy darkening with depth.
    t.paint(t.gradient((30, 54, 52), (16, 28, 30), rim, 724), m_sheet, 0.50)
    t.paint((26, 44, 44), m_lick, 0.30)
    # The meniscus: almost black, the sea's own colour, lit from the window on its skin.
    t.paint(t.gradient((20, 36, 38), (5, 10, 13), rim - 3.1, rim + 1.6), m_men)
    t.paint(INK, ImageChops.subtract(grow(m_men, 0.6), m_men), 0.6)
    hi = t.mask()
    t.stroke(hi, [(x, y + 1.0) for (x, y) in top[4:46]], 1.15,
             [0.3 + 0.7 * math.sin(math.pi * k / 41.0) ** 0.6 for k in range(42)])
    t.paint((168, 216, 192), hi, 1.0)                  # the window, sea-glass, held in the water
    glint = t.mask()
    t.dot(glint, 936.0, rim - 1.3, 0.75)
    t.paint((214, 232, 222), glint, 0.9)
    # The sheet's lit (left) edge and one slow highlight down it; nothing beaded.
    edge = t.mask()
    t.stroke(edge, [(x + 0.9, y) for (x, y) in left_edge[3:34]], 0.7,
             [0.65 * (1 - 0.7 * i / 31.0) * (0.6 + 0.4 * math.sin(i * 0.9)) for i in range(31)])
    t.paint((176, 204, 192), blur(edge, 0.2), 0.75)
    strand = t.mask()
    mid = [((l[0] + r[0]) * 0.5 + 1.4, l[1]) for l, r in zip(left_edge[8:30], right_edge[8:30])]
    t.stroke(strand, mid, 0.6, [0.35 * math.sin(math.pi * i / 21.0) for i in range(22)])
    t.paint((150, 190, 176), blur(strand, 0.3), 0.6)
    t.stroke(hi, [(x, y + 0.1) for (x, y) in ((913, 724.0), (930, 723.7), (952, 723.6), (976, 724.6))], 0.6,
             [0.15, 0.45, 0.40, 0.10])
    t.paint((150, 190, 176), hi, 0.25)
    t.grain(rng, 0.025)
    c = new_canvas()
    place(c, t)
    return c


def arch(xl, xr, y_corner, y_top, y_bot, n=30):
    pts = [(xl, y_bot), (xl, y_corner)]
    for k in range(n + 1):
        u = k / float(n)
        pts.append((lerp(xl, xr, u), y_corner - (y_corner - y_top) * math.sin(math.pi * u) ** 0.55))
    pts += [(xr, y_corner), (xr, y_bot)]
    return pts


def away_stove():
    """The stove door swung open on its right hinges; the firebox is full of seawater
    standing level in the opening, a hand's breadth below the iron arch."""
    rng = rng_for("away_stove")
    t = Tile(30, 655, 190, 925)
    # Cover the old closed door with the stove's own front, then cut the opening.
    cover = t.mask()
    t.poly(cover, arch(45.5, 129.0, 683.5, 669.0, 806.5))
    t.paint(t.gradient(IRON_LIT, IRON, 660, 820), cover)
    tex = ImageChops.multiply(cover, noise(rng, t.w * SS, t.h * SS, 3 * SS, 0.0, 1.0))
    t.paint((26, 32, 40), ramp(tex, 140, 255), 0.35)
    opening = arch(53.0, 121.0, 687.0, 676.0, 799.0)
    m_open = t.mask()
    t.poly(m_open, opening)
    # Cast frame round the opening: a lit bevel on the window (left/top) side.
    frame = ImageChops.subtract(grow(m_open, 3.0), m_open)
    t.paint(IRON_LIT, frame, 0.95)
    t.paint((92, 100, 110), ImageChops.multiply(window_edge(grow(m_open, 3.0), 1.2), frame), 0.8)
    # Firebox interior above the water: sooty iron, the back wall lit a little at its top.
    t.paint(t.gradient((46, 44, 44), (20, 21, 24), 676, 692), m_open)
    back = t.mask()
    t.poly(back, arch(60.0, 114.0, 688.0, 681.5, 700.0))
    t.paint((58, 54, 50), blur(back, 0.8), 0.45)
    t.paint(INK, ImageChops.subtract(grow(back, 0.6), back), 0.5)
    # The water: a level top at y ~691, bulging up a little in the middle.
    wl = 691.0
    surf = []
    for k in range(41):
        u = k / 40.0
        x = lerp(53.0, 121.0, u)
        bulge = 1.6 * math.sin(math.pi * u) ** 1.5 - 1.2 * (max(0.0, 0.08 - u) + max(0.0, u - 0.92)) * 12
        surf.append((x, wl - bulge))
    m_water = t.mask()
    t.poly(m_water, surf + [(121.0, 799.0), (53.0, 799.0)])
    m_water = ImageChops.multiply(m_water, m_open)
    water = t.gradient((40, 70, 74), (8, 16, 21), wl, 795)
    t.paint(water, m_water)
    # Depth: the water face is not a screen. Uneven darker shoals, a few drifting motes,
    # and a soft lighter band just under the surface.
    sh = ImageChops.multiply(m_water, noise(rng, t.w * SS, t.h * SS, 9 * SS, 0.0, 1.0))
    t.paint((4, 9, 13), blur(ramp(sh, 110, 230), 2.0), 0.55)
    band = t.mask()
    t.poly(band, [(x, y + 1.5) for (x, y) in surf] + [(121, wl + 12), (53, wl + 12)])
    t.paint((70, 110, 108), ImageChops.multiply(blur(band, 3.0), m_water), 0.30)
    motes = t.mask()
    for _ in range(14):
        t.dot(motes, rng.uniform(58, 116), rng.uniform(wl + 10, 790), rng.uniform(0.4, 0.9), int(rng.uniform(90, 200)))
    t.paint((120, 150, 146), ImageChops.multiply(motes, m_water), 0.35)
    # Faint broken reflection of the window, tilted slightly as the outside is.
    refl = t.mask()
    t.rect(refl, 64, 702, 81, 726)
    bars = t.mask()
    t.rect(bars, 72, 702, 73.2, 726)
    t.rect(bars, 64, 713.5, 81, 714.7)
    refl = ImageChops.multiply(ImageChops.subtract(refl, bars), noise(rng, t.w * SS, t.h * SS, 2 * SS, 0.3, 1.0))
    t.paint((150, 172, 176), blur(refl, 0.6), 0.10)
    # The meniscus line, pale and level; its curl up at both walls.
    men = t.mask()
    t.stroke(men, surf, 1.3, [0.55 + 0.4 * math.sin(math.pi * k / 40.0) for k in range(41)])
    t.paint((214, 228, 222), men, 0.95)
    # Its shadow on the iron just above, where the water stands proud.
    t.paint(INK, ImageChops.multiply(ImageChops.subtract(grow(m_water, 1.2), m_water), m_open), 0.5)
    t.paint(INK, ImageChops.subtract(grow(m_open, 1.3), m_open), 0.95)
    t.paint(INK, ImageChops.subtract(grow(cover, 0.9), shrink(cover, 0.3)), 0.35)

    # The door, swung open ~110 degrees on its right hinges: its back face foreshortened,
    # with the cast front's ornamented edge turned toward us.
    door = arch(130.0, 158.0, 684.0, 672.0, 805.0, 14)
    m_door = t.mask()
    t.poly(m_door, door)
    t.paint(t.gradient((60, 66, 76), (36, 41, 49), 130, 160, horizontal=True), m_door)
    soot = ImageChops.multiply(m_door, noise(rng, t.w * SS, t.h * SS, 4 * SS, 0.0, 1.0))
    t.paint((20, 24, 30), ramp(soot, 120, 255), 0.35)
    # Cast ornament: a raised border and a row of beads, as on the plate's door front.
    border = t.mask()
    t.line(border, [(134.0, 798.0)] + [(x, y + 5.0) for (x, y) in arch(134.0, 154.0, 688.0, 677.0, 798.0, 12)[1:-1]]
           + [(154.0, 798.0)], 1.4, round_joins=False)
    t.paint((86, 94, 106), border, 0.85)
    t.paint(INK, ImageChops.subtract(grow(border, 0.7), border), 0.55)
    # Three cast bolts where the plate's door has them, not a row of rivets.
    bolts = t.mask()
    for (bx, by, br) in ((144.2, 699.0, 1.3), (143.6, 741.5, 1.1), (144.4, 787.0, 1.25)):
        t.dot(bolts, bx, by, br)
    t.paint((90, 98, 110), bolts, 0.75)
    t.paint(INK, ImageChops.subtract(grow(bolts, 0.6), bolts), 0.45)
    # The door's thickness, the cast lip seen on edge.
    edge = t.mask()
    t.poly(edge, arch(158.0, 162.5, 684.0, 682.0, 805.0, 4))
    t.paint((74, 82, 94), edge)
    knob = t.mask()
    t.poly(knob, capsule((162.0, 738.0), (168.0, 738.0), 2.8, 3.6, 8))
    t.paint((52, 58, 68), knob)
    outl = ImageChops.lighter(m_door, ImageChops.lighter(edge, knob))
    t.paint(INK, ImageChops.subtract(grow(outl, 1.0), outl), 0.9)
    # Wet runs on the door's back: it had been holding the sea shut.
    dd = t.mask()
    for x in (137.0, 149.5):
        ln = rng.uniform(40, 90)
        y0 = rng.uniform(694, 716)
        pts = wobble_path(rng, [(x, y0 + ln * i / 14.0) for i in range(15)], 0.4, 1.1)
        t.stroke(dd, pts, 1.2, [0.8 * (1 - 0.6 * i / 14.0) for i in range(15)])
    t.paint((0, 0, 0), dd, 0.40)

    # Over the lower lip: an uneven spill. A fat tongue left of centre, thin runs elsewhere.
    drips = t.mask()
    hi = t.mask()
    lip = t.mask()
    t.poly(lip, wobble_path(rng, [(55, 799), (119, 799), (118, 802.5), (100, 803.5), (84, 806.5),
                                  (72, 803.0), (57, 802.5)], 0.4, 3))
    # Lengths vary 3-4x and widths 1-3x; a run thickens where water gathers and only
    # the heaviest two hang a drop. Two runs reach the base and have pooled on the plate.
    for (x, ln, w, drop) in ((60.5, 6, 0.8, 0), (68.0, 21, 1.4, 0), (73.5, 49, 2.6, 1), (81.0, 12, 1.1, 0),
                             (91.5, 70, 1.8, 2), (101.0, 27, 1.0, 0), (112.5, 15, 1.9, 0), (117.0, 4, 0.7, 0)):
        n = 22
        pts = wobble_path(rng, [(x + 0.5 * math.sin(i * 0.45 + x), 802 + ln * i / n) for i in range(n + 1)],
                          0.35 + 0.02 * ln ** 0.5, 1.0 + rng.uniform(0, 0.8))
        bulge = rng.uniform(0.3, 0.8)
        press = [0.92 * (1 - 0.3 * i / n) for i in range(n + 1)]
        for i in range(n):
            u = i / float(n)
            r = w * (0.55 + 0.45 * math.exp(-((u - bulge) / 0.22) ** 2)) * (1.0 - 0.25 * u)
            t.poly(drips, capsule(pts[i], pts[i + 1], r, r, 6), fill=int(255 * press[i]))
        if drop:
            t.poly(drips, capsule((pts[-1][0], pts[-1][1] - 1.5), (pts[-1][0], pts[-1][1] + w * 0.9),
                                  w * 0.55, w * 0.95 + 0.4, 8), fill=230)
            t.dot(hi, pts[-1][0] - w * 0.35, pts[-1][1] + 0.2, 0.55, 200)
        t.stroke(hi, [(p[0] - w * 0.4, p[1]) for p in pts[1:-3]], 0.5,
                 [0.55 * (1 - i / (n - 3.0)) * (0.5 + 0.5 * math.sin(i * 0.7 + x)) for i in range(n - 3)])
    # Falling drops between the stove's belly and the plate, under the long run.
    for (x, y, r) in ((91.8, 851.0, 1.0), (92.3, 868.0, 0.8)):
        t.poly(drips, capsule((x, y - 2.2 * r), (x, y), r * 0.45, r, 8), fill=220)
    t.paint(SEA, ImageChops.lighter(drips, lip), 0.9)
    pud = t.mask()
    t.poly(pud, wobble_path(rng, [(78, 890.6), (88, 888.4), (101, 888.2), (110, 889.6), (104, 892.2),
                                  (90, 892.8), (80, 892.4)], 0.5, 2))
    t.poly(pud, wobble_path(rng, [(64, 890.4), (70, 889.2), (78, 889.6), (75, 891.4), (66, 891.6)], 0.3, 2))
    pud = ramp(blur(pud, 0.6), 90, 170)
    t.paint((0, 0, 0), pud, 1.0 - WET_MUL + 0.08)
    t.stroke(hi, [(81, 889.0), (93, 888.5), (106, 889.3)], 0.55, [0.25, 0.6, 0.25])
    t.stroke(hi, [(56, 799.6), (88, 799.3), (118, 799.6)], 0.7, [0.4, 0.8, 0.4])
    t.paint(SHEEN, hi, 0.8)
    t.grain(rng, 0.03)
    c = new_canvas()
    place(c, t)
    return c


def away_coat():
    """The oilskin's hood raised on its hook as if over a head: it holds a round shape,
    leans toward the desk, shows a sliver of its brown lining, and inside is a matte void.
    The hook's brass tip stays in sight above the crown."""
    rng = rng_for("away_coat")
    t = Tile(1025, 290, 1160, 445)
    tilt = math.radians(-11)      # the whole head leans toward the desk
    pivot = (1084.0, 392.0)

    def R(pts):
        ca, sa = math.cos(tilt), math.sin(tilt)
        return [(pivot[0] + (x - pivot[0]) * ca - (y - pivot[1]) * sa,
                 pivot[1] + (x - pivot[0]) * sa + (y - pivot[1]) * ca) for (x, y) in pts]

    # The crown is drawn up to a soft peak on the hook (just under the brass, y 306),
    # rounds out as if over a skull, pinches at a neck, then flares into the shoulders.
    outline = [(1083, 306.5), (1090, 309), (1100, 316), (1109, 328), (1114, 343), (1115, 360),
               (1112, 376), (1108, 388), (1112, 398), (1124, 408), (1132, 420),
               (1040, 420), (1046, 408), (1058, 398), (1061, 389), (1055, 376), (1052, 359),
               (1054, 341), (1060, 326), (1069, 314), (1077, 308.5)]
    hood = [outline[0]] + R(outline[1:10]) + outline[10:12] + R(outline[12:])
    m_hood = t.mask()
    t.poly(m_hood, wobble_path(rng, hood + hood[:1], 0.4, 3)[:-1])
    m_hood = ramp(blur(m_hood, 0.6), 100, 160)
    fade = Image.new("L", (t.w * SS, t.h * SS), 0)
    fd = ImageDraw.Draw(fade)
    for j in range(t.h * SS):
        y = t.y0 + j / float(SS)
        fd.line([(0, j), (t.w * SS, j)], fill=int(255 * clamp((428 - y) / 24.0)))
    m_body = ImageChops.multiply(m_hood, fade)
    t.paint(t.gradient(COAT_LIT, COAT, 306, 410), m_body)
    # Modelling: the far (right) side of the round in shadow, the crown catching light.
    shadow = t.mask()
    t.poly(shadow, R([(1098, 318), (1112, 335), (1115, 360), (1110, 385), (1100, 392), (1104, 360)]))
    t.paint((26, 32, 40), ImageChops.multiply(blur(shadow, 4.0), m_body), 0.6)
    # The opening, on the near side, facing the desk: an uneven, drooping almond,
    # its upper brim folded over. Not a hole: something fills it.
    outer = [(1071.5, 314), (1062.5, 326), (1056.5, 341), (1054.5, 359), (1057.5, 376), (1063.5, 388)]
    inner_arc = [(1065, 386), (1072.5, 372), (1074.5, 356), (1074.0, 338), (1076.5, 320)]
    mouth_pts = R(outer + inner_arc)
    m_mouth = t.mask()
    t.poly(m_mouth, wobble_path(rng, mouth_pts + mouth_pts[:1], 0.3, 3)[:-1])
    m_mouth = ImageChops.multiply(ramp(blur(m_mouth, 0.4), 100, 160), m_hood)
    # Lining: a sliver of brown flannel where the rim turns inward, upper part only.
    lin = t.mask()
    t.poly(lin, R([(1076.5, 320), (1074.0, 338), (1074.5, 356), (1073.5, 366),
                   (1071.0, 364), (1071.0, 352), (1071.0, 337), (1073.0, 322)]))
    lin = ImageChops.multiply(blur(lin, 0.4), m_hood)
    t.paint(t.gradient((116, 94, 68), (66, 52, 40), 320, 368), lin)
    # The opening holds nothing: a matte void, the coat's lining falling away into black.
    # No sheen, no form; it is darkest where a face would be.
    inner = ImageChops.subtract(m_mouth, lin)
    t.paint((14, 16, 19), inner)
    t.paint((2, 3, 4), ImageChops.multiply(blur(shrink(m_mouth, 1.6), 1.6), inner))
    # The folded brim above the opening, and the rolled lip.
    brim = t.mask()
    t.stroke(brim, R([(1062, 318), (1067, 313.5), (1073, 313), (1078, 316)]), 2.2, [0.5, 0.95, 0.9, 0.4])
    t.paint(COAT_LIT, ImageChops.multiply(brim, shrink(m_hood, 0.8)), 0.9)
    t.paint(INK, ImageChops.subtract(grow(m_mouth, 0.9), m_mouth), 0.85)
    # Folds and wet scratches, as on the plate's oilskin.
    folds = t.mask()
    for path, w in (([(1084, 309), (1098, 324), (1106, 345), (1108, 372)], 1.2),
                    ([(1080, 318), (1086, 340), (1090, 368), (1092, 388)], 0.9),
                    ([(1064, 394), (1076, 400), (1094, 401), (1106, 395)], 1.0),
                    ([(1060, 404), (1048, 414)], 0.9), ([(1112, 402), (1126, 414)], 0.9)):
        pts = []
        for p, q in zip(path, path[1:]):
            for k in range(6):
                pts.append((lerp(p[0], q[0], k / 6.0), lerp(p[1], q[1], k / 6.0)))
        pts.append(path[-1])
        pts = wobble_path(rng, R(pts), 0.4, 1.5)
        t.stroke(folds, pts, w, [0.75 * math.sin(math.pi * (0.1 + 0.8 * i / (len(pts) - 1)))
                                 for i in range(len(pts))])
    t.paint(INK, ImageChops.multiply(folds, m_body), 0.75)
    sc = t.mask()
    for _ in range(24):
        x, y = rng.uniform(1066, 1120), rng.uniform(318, 415)
        t.line(sc, [(x, y), (x + rng.uniform(-0.6, 0.6), y + rng.uniform(5, 15))], 0.55, int(rng.uniform(90, 200)))
    crown = t.mask()
    t.stroke(crown, R([(1070, 320), (1078, 312), (1088, 311), (1098, 317)]), 1.6, [0.2, 0.75, 0.8, 0.3])
    sc = ImageChops.subtract(ImageChops.multiply(ImageChops.lighter(sc, blur(crown, 0.6)), m_body), grow(m_mouth, 1.2))
    t.paint((150, 160, 168), sc, 0.35)
    ol = ImageChops.multiply(ImageChops.subtract(grow(m_hood, 1.0), m_hood), fade)
    t.paint(INK, ol, 0.95)
    t.grain(rng, 0.03)
    c = new_canvas()
    place(c, t)
    return c


def away_door():
    """Seawater coming in under the corridor door: a shallow lobed sheet along the sill
    that is still advancing. Its leading tongues carry a pale meniscus and hold a cold
    sea-glass reflection of the window; the longest reaches out toward the desk."""
    rng = rng_for("away_door")
    t = Tile(1150, 880, 1448, 960)
    sheet = t.mask()
    t.poly(sheet, [(1228, 894.0), (1442, 894.0), (1442, 900.0), (1228, 900.0)])
    x = 1226.0
    while x < 1440:
        rx = rng.uniform(10, 21)
        ry = rx * rng.uniform(0.34, 0.46)
        cy = 900.0 + rng.uniform(0.5, 4.0)
        t.poly(sheet, [(x + rx * math.cos(th), cy + ry * math.sin(th))
                       for th in [2 * math.pi * j / 28 for j in range(28)]])
        x += rx * rng.uniform(0.8, 1.2)
    # Tongues: (root, tip, root radius, tip radius). The first is the long one, low and
    # left toward the desk, passing between the coat's puddle and her trail.
    tongues = ((1306, 902, 1180, 922, 15.0, 4.2), (1356, 903, 1332, 918, 12.0, 6.0),
               (1408, 902, 1398, 911, 9.0, 5.0), (1262, 902, 1243, 912, 8.0, 4.4))
    tips = []
    for (sx, sy, ex, ey, r0, r1) in tongues:
        dx, dy = ex - sx, ey - sy
        n = int(math.hypot(dx, dy) / 1.5)
        d = math.hypot(dx, dy)
        nx, ny = -dy / d, dx / d
        for k in range(n + 1):
            u = k / float(n)
            sway = 2.2 * math.sin(u * 3.4 + sx) * u
            cx = lerp(sx, ex, u) + nx * sway
            cy = lerp(sy, ey, u) + ny * sway * 0.6
            rx = lerp(r0, r1, u ** 0.7) * (1.0 + 0.08 * math.sin(u * 17.0 + sy))
            t.poly(sheet, [(cx + rx * math.cos(th), cy + rx * 0.48 * math.sin(th))
                           for th in [2 * math.pi * j / 28 for j in range(28)]])
        tips.append((ex + dx / d * r1 * 0.8, ey + dy / d * r1 * 0.4))
    water = ramp(blur(sheet, 0.9), 90, 160)
    # 1. The wet recipe, laid heavier: standing water, not a damp mark.
    b = ImageChops.multiply(water, noise(rng, t.w * SS, t.h * SS, 3 * SS, 0.86, 1.0))
    t.paint((0, 0, 0), b, 0.40)
    # 2. Depth: deepest under the door, shallowing toward the tips.
    deep = t.mask()
    t.rect(deep, 1226, 893, 1444, 902)
    t.paint((6, 12, 16), ImageChops.multiply(blur(deep, 3.0), water), 0.30)
    # 3. The window, cold and broken, reflected in the sheet: sea-glass streaks lying
    #    along the water, stronger toward the open floor.
    refl = t.mask()
    for (x0, x1, y, w) in ((1196, 1262, 917.0, 1.6), (1210, 1278, 913.5, 1.1), (1318, 1350, 912.0, 1.4),
                           (1336, 1372, 908.5, 0.9), (1390, 1418, 906.0, 1.0), (1240, 1300, 906.5, 0.9)):
        pts = wobble_path(rng, [(lerp(x0, x1, k / 10.0), y + 0.25 * k) for k in range(11)], 0.3, 1.0)
        t.stroke(refl, pts, w, [0.9 * math.sin(math.pi * (0.1 + 0.8 * k / 10.0)) for k in range(11)])
    refl = ImageChops.multiply(blur(refl, 0.7), shrink(water, 1.5))
    t.paint((112, 168, 150), refl, 0.8)
    # 4. The meniscus: a thin pale lip along the leading (front and left) edge of every
    #    tongue, as water has where it is still moving onto dry wood.
    lead = window_edge(water, 1.3, (-0.6, 1.0))
    lead = ImageChops.multiply(lead, ramp(noise(rng, t.w * SS, t.h * SS, 7 * SS, 0.0, 1.0), 40, 170))
    t.paint((214, 226, 220), blur(lead, 0.5), 0.55)
    shadow = ImageChops.subtract(grow(water, 0.9), water)
    shadow = ImageChops.multiply(shadow, window_edge(grow(water, 0.9), 1.3, (-0.6, 1.0)))
    t.paint((0, 0, 0), shadow, 0.18)
    glint = t.mask()
    t.stroke(glint, [(1232, 895.6), (1300, 895.2), (1380, 895.6), (1436, 895.4)], 0.7, [0.4, 0.8, 0.6, 0.3])
    t.paint((226, 236, 230), glint, 0.8)
    # Damp wicking up the door's bottom rail: a soft uneven darkening, no line.
    wick = t.mask()
    top = [(x, 884.0 + 3.0 * math.sin(x * 0.06) + rng.uniform(-1.2, 1.2)) for x in range(1230, 1442, 6)]
    t.poly(wick, [(1230, 893.5)] + top + [(1440, 893.5)])
    t.paint((0, 0, 0), blur(wick, 1.5), 0.20)
    t.grain(rng, 0.03)
    c = new_canvas()
    place(c, t)
    return c


def coat_mask_1x(plate):
    """The oilskin's silhouette from the plate (the connected dark region round the
    coat's body, so ink lines and the rail are excluded), grown 3 px."""
    px = plate.load()
    m = Image.new("L", (W, H), 0)
    mp = m.load()
    for y in range(328, 900):
        for x in range(1015, 1186):
            r, g, b = px[x, y]
            if b - r < 28 and r + g + b < 200:
                mp[x, y] = 255
    m = m.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5))
    ImageDraw.floodfill(m, (1090, 500), 128)
    m = m.point(lambda v: 255 if v == 128 else 0)
    return m.filter(ImageFilter.MaxFilter(7))


def away_puddle():
    """Four-toed wet prints walking straight up the wall between the coat and the door
    frame, toes up, floor-print size, in the shared wet recipe. Each one is wet enough
    to run: a thin run falls from its heel, so 'up' cannot be mistaken."""
    rng = rng_for("away_puddle")
    plate = Image.open(PLATE).convert("RGB")
    coat = coat_mask_1x(plate)
    t = Tile(1130, 300, 1200, 905)
    door_x = 1189.0                       # the door casing's outer edge

    def coat_right(y0, y1):
        box = coat.crop((1100, int(y0), 1200, int(y1))).getbbox()
        return 1100 + box[2] if box else 1130

    feet, runs = [], []
    y = 872.0
    i = 0
    while y > 360:
        left = (i % 2 == 0)
        clear = coat_right(y - 30, y + 18) + 9.0
        mid = 0.5 * (clear + door_x)
        x = mid + (-6.5 if left else 6.5) + rng.uniform(-0.8, 0.8)
        x = max(clear, min(door_x - 9.0, x))
        k = clamp((872.0 - y) / 512.0)
        wet = lerp(1.0, 0.86, k)
        ang = -math.pi / 2 + rng.uniform(-0.06, 0.06) + (0.05 if left else -0.05)
        feet.append((x, y, ang, left, 0.92, 1.0, 1.0, wet))
        # a run from the heel: lengths vary 3-4x, widths too
        ln = rng.choice((10.0, 16.0, 24.0, 34.0)) * rng.uniform(0.85, 1.2)
        runs.append((x + rng.uniform(-1.5, 1.5), y + 12.5, ln, wet, rng.uniform(0.9, 1.7)))
        if rng.random() < 0.35:
            runs.append((x + rng.uniform(-4.0, 4.0), y + 9.0, ln * rng.uniform(0.3, 0.6), wet,
                         rng.uniform(0.6, 1.0)))
        y -= 38.0 + rng.uniform(-3.0, 4.0)
        i += 1
    body, gleam = paint_feet(t, feet)
    for (x, y0, ln, wet, w) in runs:
        n = max(6, int(ln / 1.5))
        pts = wobble_path(rng, [(x, y0 + ln * j / n) for j in range(n + 1)], 0.35, 0.9)
        m = t.mask()
        for j in range(n):
            u = j / float(n)
            r = w * (1.0 - 0.45 * u) * 0.5 + 0.35
            t.poly(m, capsule(pts[j], pts[j + 1], r, r, 6), fill=int(255 * (0.95 - 0.35 * u)))
        end = pts[-1]
        t.poly(m, capsule((end[0], end[1] - 1.2), (end[0], end[1] + w * 0.7), w * 0.35 + 0.3, w * 0.6 + 0.45, 8),
               fill=230)
        body = ImageChops.lighter(body, scale_l(m, wet))
        g = t.mask()
        t.stroke(g, [(p[0] - 0.5, p[1]) for p in pts[1:-2]], 0.45, [0.6 * wet * (1 - j / float(n)) for j in range(n - 2)])
        gleam = ImageChops.lighter(gleam, g)
    paint_wet(t, rng, body, gleam, hi=0.55)
    # Plaster drinks water: a faint damp halo round each print, wider than the print.
    halo = blur(body, 2.6)
    t.paint((0, 0, 0), ImageChops.subtract(halo, body), 0.08)
    t.clip(ImageChops.invert(coat.crop((t.x0, t.y0, t.x0 + t.w, t.y0 + t.h))))
    t.grain(rng, 0.03)
    c = new_canvas()
    place(c, t)
    return c


def away_window():
    """A fourth hand, wiped clear through condensation on the outside of the upper sash,
    high in the top-right pane, fingers up. The fog is not the whole sash: it is a bloom,
    as of breath, round the hand; the hand dragged down off the glass in one tapering mark."""
    rng = rng_for("away_window")
    panes = [(483, 144, 584, 252), (593, 144, 693, 252), (701, 144, 801, 252),
             (483, 262, 584, 355), (593, 262, 693, 355), (701, 262, 801, 355)]
    t = Tile(480, 140, 805, 360)
    clipm = Image.new("L", (t.w, t.h), 0)
    cd = ImageDraw.Draw(clipm)
    for (x0, y0, x1, y1) in panes:
        cd.rectangle([x0 - t.x0, y0 - t.y0, x1 - t.x0 - 1, y1 - t.y0 - 1], fill=255)
    hx, hy = 752.0, 238.0
    # The bloom: densest round the palm, thinning out raggedly, heavier at pane feet.
    film = Image.new("L", (t.w, t.h), 0)
    fp = film.load()
    for yy in range(t.h):
        y = t.y0 + yy
        for xx in range(t.w):
            x = t.x0 + xx
            d = math.hypot((x - hx) / 78.0, (y - (hy - 22)) / 104.0)
            fp[xx, yy] = int(round(255 * 0.40 * clamp(1.15 - d) ** 0.9))
    film = ImageChops.multiply(film, noise(rng, t.w, t.h, 16, 0.55, 1.0))
    film = ImageChops.multiply(film, noise(rng, t.w, t.h, 2.2, 0.82, 1.0))
    film_hi = film.resize((t.w * SS, t.h * SS), Image.BICUBIC)

    pads, creases = hand_shapes(hx, hy, -math.pi / 2 - 0.05, thumb_side=-1.0, rng=rng)
    m_hand = t.mask()
    for p in pads:
        t.poly(m_hand, p)
    m_hand = ramp(blur(m_hand, 0.45), 100, 170)
    # The drag: one mark, the width of the heel where it left the glass, narrowing as the
    # pressure went, bending a little, ragged at its edges, with faint finger-lines in it.
    drag = t.mask()
    n = 40
    spine = []
    for i in range(n + 1):
        u = i / float(n)
        spine.append((hx - 2.0 + 5.0 * u ** 1.6, hy - 4.0 + 96.0 * u))
    left_e, right_e = [], []
    for i, (x, y) in enumerate(spine):
        u = i / float(n)
        half = 15.5 * (1.0 - u) ** 0.85 + 0.6
        left_e.append((x - half * (1.0 + 0.07 * math.sin(u * 19.0)), y))
        right_e.append((x + half * (1.0 + 0.09 * math.sin(u * 13.0 + 1.0)), y))
    t.poly(drag, wobble_path(rng, left_e, 0.7, 4.0) + wobble_path(rng, right_e[::-1], 0.7, 3.5))
    press = Image.new("L", (t.w * SS, t.h * SS), 0)
    pd = ImageDraw.Draw(press)
    for j in range(t.h * SS):
        y = t.y0 + j / float(SS)
        pd.line([(0, j), (t.w * SS, j)], fill=int(255 * clamp(1.0 - 0.75 * ((y - hy) / 96.0)) if y > hy else 255))
    # Streaks run with the drag: noise stretched vertically, so the mark is combed, not speckled.
    sw, sh = int(t.w / 1.6) + 2, int(t.h / 16.0) + 2
    streaks = Image.frombytes("L", (sw, sh), rng.randbytes(sw * sh)).resize((t.w * SS, t.h * SS), Image.BICUBIC)
    streaks = ramp(streaks, 20, 150)
    lines = t.mask()
    for k in range(4):
        x = hx - 9.0 + 6.0 * k + rng.uniform(-1, 1)
        t.stroke(lines, wobble_path(rng, [(x + 3.0 * (i / 12.0) ** 1.6, hy + 2 + 70 * i / 12.0) for i in range(13)],
                                    0.4, 0.8), 1.0, [0.45 * (1 - i / 12.0) for i in range(13)])
    drag = ImageChops.multiply(ImageChops.multiply(blur(drag, 0.5), press), streaks)
    drag = ImageChops.subtract(drag, scale_l(lines, 0.6))
    # Drips: thin clear runs, varied widths, from two fingertips and the drag's end.
    drips = t.mask()
    for (x, y0, y1, w) in ((734.0, 197.0, 251.0, 0.8), (771.5, 188.0, 236.0, 1.3),
                           (754.5, 330.0, 353.0, 1.6), (745.0, 300.0, 342.0, 0.7)):
        k = 22
        pts = wobble_path(rng, [(x, y0 + (y1 - y0) * i / k) for i in range(k + 1)], 0.35, 1.0)
        for i in range(k):
            r = w * 0.5 * (1.0 + 0.35 * math.sin(i * 0.6 + x)) * (1.0 - 0.3 * i / k)
            t.poly(drips, capsule(pts[i], pts[i + 1], r, r, 6), fill=int(240 * (1.0 - 0.45 * i / k)))
    clear = ImageChops.lighter(ImageChops.lighter(m_hand, drag), drips)
    # Creases and finger joints: fog left standing where the skin did not touch. Faint.
    cm = t.mask()
    for pts, w in creases:
        t.line(cm, pts, w)
    cm = blur(cm, 0.45)
    clear = ImageChops.subtract(clear, scale_l(cm, 0.45))
    # Fog pushed aside banks up in a soft bright rim round the hand.
    bank = ImageChops.subtract(grow(m_hand, 1.4), m_hand)
    bank = ImageChops.multiply(blur(bank, 0.8), noise(rng, t.w * SS, t.h * SS, 4 * SS, 0.45, 1.0))
    bank = ImageChops.multiply(bank, scale_l(film_hi, 2.2))
    fog = ImageChops.subtract(film_hi, clear)
    t.paint((236, 241, 238), fog)
    t.paint((248, 250, 249), bank, 0.55)
    # The wiped glass is clean and a little darker than the fogged sky round it.
    t.paint((40, 58, 66), ImageChops.multiply(clear, ramp(film_hi, 4, 60)), 0.30)
    t.clip(clipm)
    t.grain(rng, 0.02)
    c = new_canvas()
    place(c, t)
    return c


ASSETS = [
    ("prints_door", prints_door),
    ("chart_contours", chart_contours),
    ("away_mug", away_mug),
    ("away_stove", away_stove),
    ("away_coat", away_coat),
    ("away_door", away_door),
    ("away_puddle", away_puddle),
    ("away_window", away_window),
]


def main(argv):
    only = set(argv[1:])
    for name, fn in ASSETS:
        if only and name not in only:
            continue
        canvas = fn()
        if name == "away_puddle":
            plate = Image.open(PLATE).convert("RGB")
            hit = ImageChops.multiply(canvas.split()[3], coat_mask_1x(plate)).getbbox()
            if hit:
                raise SystemExit("away_puddle: a print touches the coat at %s" % (hit,))
            if canvas.split()[3].crop((0, 0, W, 327)).getbbox():
                raise SystemExit("away_puddle: a print climbs onto the hook rail")
        path = save(canvas, name)
        with open(path, "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
        print("%s  %s" % (digest[:16], os.path.relpath(path, ROOT)))


if __name__ == "__main__":
    main(sys.argv)
