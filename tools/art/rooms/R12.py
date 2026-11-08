#!/usr/bin/env python3
"""R12 Observation Chamber painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R12/*.png:

  view_a                                  the chair, the instrument column, the window, the gauge (opaque)
  a_surface, a_surface_withdrawn,         window-interior overlays: the edgeless surface (S0/S1), the surface
  a_daylight, a_morning                   pulled back from the glass (P26), ending A's grey sea, ending B's dawn
  a_arm_rest, a_arm_low                   the three brass armatures at rest / lowered to Ada's height (P25)
  a_cushion_dent, a_ada_seated            the seat pressed as if just sat in; Ada in the chair (ending B)
  a_lid_line, a_gauge_needle              sprites: the lid band (448x22, bent along the lid curve by
                                          the view), the gauge needle (pivot 6,54)
  a_surface_lid                           the lid at rest over the iris (after the third window look)
  a_arm_ready                             S2: every armature fitting opened and turned to the viewer
  a_stain_1, a_stain_2, a_gauge_pinned    S1/S2 tide line on the wainscot; S2 bowed gauge bezel
  view_b (+ b_terminal_lit, b_shutters_turned, b_copy_uncapped, b_frames_filled, b_indicators_dark)
  view_c (+ c_shutters_closed, c_lamps_ready, c_yoke_fitted, c_tray_empty, c_bridge_seated, c_handle_pulled)
  c_frames (+ c_frames_back, c_frames_lit, card, switch_witness, switch_copy, route_key, route_key_turned)
  c_routing (+ c_routing_closed, cc_card, lamp_on, lamp_off)
  c_final (+ yoke, bridge)
  end_card (+ the eighteen m_* room fragments, 1288x760, shown in its brass frame at M_AT)
  end_a_record, end_a_jetty, end_a_inquiry, end_a_page, end_b_terminal, end_b_wide, end_b_cover
  cover_sheet
  a_surface_wide                          wave 3: the surface across the whole back wall (the view's GLASS)
  end_b_field                             wave 3: CONTINUE at night, the kitchen among countless dark stations

Flat front elevation, approved palette, navy ink contours, matte colour, a low seeded paper
grain. No text, numerals or diagrams: every label field is a blank enamel or brass plate and
the view writes every word.

State overlays of a base plate are made by painting the base twice (once plain, once in the
new state) with the same seeds and keeping only the pixels that changed, so every overlay is
registered to the pixel; an overlay that must also cancel another overlay (the dead lamps of
ending A over the lit terminal) adds that area to its mask.

Python 3 + PIL only. Deterministic: each asset has its own random.Random(SEED + k), there is
no clock and no PIL noise effect, so a rerun is byte-identical.

    python3 tools/art/rooms/R12.py              # paint everything
    python3 tools/art/rooms/R12.py view_a a_*   # paint some (fnmatch patterns)
"""
import fnmatch
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "rooms", "R12")
STAGES_OUT = os.path.join(ROOT, "assets", "stages", "R12")
W, H = 1448, 1086
SS = 2
SEED = 1931_12_00

# ----------------------------------------------------------------------------- palette
INK = (23, 43, 54)          # #172B36
PAPER = (216, 206, 181)     # #D8CEB5
PAPER_HI = (232, 225, 207)
PAPER_LO = (190, 180, 156)
ENAMEL = (222, 216, 198)
ENAMEL_LO = (196, 190, 172)
SEAGLASS = (97, 125, 116)   # #617D74
SEAGLASS_HI = (150, 178, 166)  # #96B2A6
TIMBER = (103, 93, 81)      # #675D51
TIMBER_DK = (80, 72, 63)
TIMBER_HI = (126, 115, 100)
SOOT = (41, 41, 41)         # #292929
AMBER = (195, 153, 89)      # #C39959
AMBER_HI = (236, 206, 140)
BRASS = (176, 138, 74)      # #B08A4A
BRASS_HI = (212, 178, 112)
BRASS_LO = (138, 106, 56)
BRASS_DK = (96, 74, 40)
BARE = (238, 226, 190)      # fresh-cut brass
STORM = (34, 48, 58)        # #22303A
BLACK = (7, 11, 15)         # #070B0F
VIOLET = (116, 101, 119)    # #746577

BULK = (52, 70, 82)         # the chamber bulkhead: storm navy lifted to read at band 7
BULK_HI = (72, 92, 104)
BULK_DK = (38, 52, 62)
IRON = (46, 56, 64)
IRON_HI = (72, 86, 96)
IRON_LO = (32, 40, 47)
LEATHER = (96, 66, 50)
LEATHER_HI = (122, 88, 68)
LEATHER_DK = (72, 48, 36)
VERD = (128, 132, 96)       # tarnished brass, half way to sea-glass
SLATE = (62, 68, 72)
SLATE_HI = (82, 90, 94)
FELT = (48, 70, 64)
FELT_DK = (36, 54, 50)
GLASS_DEAD = (88, 94, 96)
SURFACE = (11, 20, 27)      # #0B141B
WIN_FLAT = (14, 24, 32)     # #0E1820
SKY = (185, 194, 192)       # #B9C2C0
SEA = (127, 149, 144)       # #7F9590


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
    """Draws in logical coordinates on a supersampled RGBA canvas.

    `w`, `h` are the output size in pixels. A scaled pen (the ending plates) maps logical point
    (x, y) to output pixel ((x - ox) * scale, (y - oy) * scale), so an old drawing can be shown
    larger without redrawing it; every plate in the room uses scale 1 and origin (0, 0)."""

    def __init__(self, w, h, rng, bg=None, scale=1.0, origin=(0.0, 0.0)):
        self.w, self.h, self.rng = w, h, rng
        self.scale, self.origin = scale, origin
        self.ss = SS * scale
        self.im = Image.new("RGBA", (w * SS, h * SS), rgba(bg) if bg else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def iw(self, w):
        return max(1, int(round(w * self.ss)))

    def tx(self, x):
        return (x - self.origin[0]) * self.ss

    def ty(self, y):
        return (y - self.origin[1]) * self.ss

    def _p(self, pts):
        return [(self.tx(x), self.ty(y)) for x, y in pts]

    def _box(self, x0, y0, x1, y1):
        return (self.tx(x0), self.ty(y0), self.tx(x1), self.ty(y1))

    def poly(self, pts, fill=None, ink=INK, w=2.6):
        p = self._p(pts)
        if fill is not None:
            self.d.polygon(p, fill=rgba(fill))
        if ink is not None and w:
            self.d.line(p + [p[0]], fill=rgba(ink), width=self.iw(w), joint="curve")

    def rect(self, x0, y0, x1, y1, fill=None, ink=INK, w=2.6, r=0):
        x0, x1 = min(x0, x1), max(x0, x1)
        y0, y1 = min(y0, y1), max(y0, y1)
        r = max(0, min(r, (x1 - x0) / 2 - 1, (y1 - y0) / 2 - 1))
        width = self.iw(w) if (ink is not None and w) else 0
        self.d.rounded_rectangle(self._box(x0, y0, x1, y1), radius=r * self.ss,
                                 fill=rgba(fill) if fill is not None else None,
                                 outline=rgba(ink) if width else None, width=width)

    def ell(self, cx, cy, rx, ry=None, fill=None, ink=INK, w=2.6):
        ry = rx if ry is None else ry
        width = self.iw(w) if (ink is not None and w) else 0
        self.d.ellipse(self._box(cx - rx, cy - ry, cx + rx, cy + ry), fill=rgba(fill) if fill is not None else None,
                       outline=rgba(ink) if width else None, width=width)

    def line(self, pts, col=INK, w=2.6):
        self.d.line(self._p(pts), fill=rgba(col), width=self.iw(w), joint="curve")

    def arc(self, cx, cy, rx, ry, a0, a1, col=INK, w=2.6):
        self.d.arc(self._box(cx - rx, cy - ry, cx + rx, cy + ry), a0, a1, fill=rgba(col), width=self.iw(w))

    def pie(self, cx, cy, r, a0, a1, fill):
        self.d.pieslice(self._box(cx - r, cy - r, cx + r, cy + r), a0, a1, fill=rgba(fill))

    def mask_poly(self, pts):
        m = Image.new("L", self.im.size, 0)
        ImageDraw.Draw(m).polygon(self._p(pts), fill=255)
        return m

    def mask_circle(self, c, r):
        m = Image.new("L", self.im.size, 0)
        ImageDraw.Draw(m).ellipse(self._box(c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill=255)
        return m

    def vgrad(self, x0, y0, x1, y1, c0, c1, mask=None):
        """A flat vertical blend from c0 at y0 to c1 at y1 (1 px steps at output scale)."""
        lay = self.layer()
        n = max(2, int(abs(self.ty(y1) - self.ty(y0)) / SS))
        for i in range(n):
            t = i / (n - 1)
            ya = lerp(y0, y1, i / n)
            yb = lerp(y0, y1, (i + 1) / n) + 0.6 / self.scale
            lay.rect(x0, ya, x1, yb, mix(c0, c1, t), None)
        self.put(lay, mask=mask)

    def wob_poly(self, pts, col=INK, w=2.8, amp=0.6, step=14.0, closed=True):
        """A hand-inked contour along `pts`: subdivided, nudged along the normal (2-3 px, varied)."""
        ring = list(pts) + ([pts[0]] if closed else [])
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
        out.append(out[0] if closed else ring[-1])
        self.line(out, col, w)

    def wob_rect(self, x0, y0, x1, y1, col=INK, w=2.8, amp=0.6):
        self.wob_poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col, w, amp)

    def layer(self):
        return Pen(self.w, self.h, self.rng, None, self.scale, self.origin)

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
        other.im = other.im.convert("RGBa").filter(ImageFilter.GaussianBlur(radius * self.ss)).convert("RGBA")
        self.put(other, opacity, mask)

    def done(self):
        return self.im.resize((self.w, self.h), Image.LANCZOS)


def poly_mask(size, pts, ss=SS):
    m = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(m).polygon([(x * ss, y * ss) for x, y in pts], fill=255)
    return m


def circle_mask(size, c, r, ss=SS):
    m = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(m).ellipse(((c[0] - r) * ss, (c[1] - r) * ss, (c[0] + r) * ss, (c[1] + r) * ss), fill=255)
    return m


def bezier(pts, n=40):
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


def strap(p, pts, width, fill, ink=INK, w=2.4, hi=None, lo=None):
    """A flat band of `width` along a polyline: filled, inked edges, one highlight line."""
    a = offset_line(pts, width / 2)
    b = offset_line(pts, -width / 2)
    p.poly(a + b[::-1], fill, None)
    if hi:
        p.line(offset_line(pts, width / 2 - 2.5), hi, 1.6)
    if lo:
        p.line(offset_line(pts, -width / 2 + 2.5), lo, 1.6)
    if ink:
        p.line(a, ink, w)
        p.line(b, ink, w)
        p.line([a[0], b[0]], ink, w)
        p.line([a[-1], b[-1]], ink, w)


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
    if name.startswith("stages/"):   # ending pages: assets/stages/R12/<name>.png (new files only)
        path = os.path.join(STAGES_OUT, name[len("stages/"):] + ".png")
        os.makedirs(STAGES_OUT, exist_ok=True)
    im.save(path, optimize=False, compress_level=9)
    print("  wrote", os.path.relpath(path, ROOT), im.size, im.mode)


def diff_overlay(base, variant, extra=None, grow=1):
    """The variant's pixels wherever it differs from the base (plus `extra`, an L mask at 1x)."""
    a = base.convert("RGB")
    b = variant.convert("RGB")
    d = ImageChops.difference(a, b).convert("L").point(lambda v: 255 if v > 0 else 0)
    if grow:
        d = d.filter(ImageFilter.MaxFilter(2 * grow + 1))
    if extra is not None:
        d = ImageChops.lighter(d, extra)
    out = b.convert("RGBA")
    out.putalpha(d)
    return out


def mask1x(pen_mask):
    return pen_mask.resize((W, H), Image.LANCZOS)


def rivet(p, x, y, r=3.0, col=BULK_HI):
    p.ell(x, y, r, r, col, INK, 1.2)


def screw(p, x, y, r=4.0, col=BRASS_LO):
    p.ell(x, y, r, r, col, INK, 1.2)
    p.line([(x - r * 0.7, y + r * 0.3), (x + r * 0.7, y - r * 0.3)], INK, 1.1)


def brass_plate(p, x0, y0, x1, y1, fill=BRASS, screws=True, w=2.4, r=3, bevel=True):
    p.rect(x0, y0, x1, y1, fill, INK, w, r)
    if bevel:
        p.line([(x0 + 3, y1 - 3), (x0 + 3, y0 + 3), (x1 - 3, y0 + 3)], mix(fill, BRASS_HI, 0.7), 1.6)
        p.line([(x0 + 4, y1 - 3), (x1 - 3, y1 - 3), (x1 - 3, y0 + 4)], mix(fill, BRASS_DK, 0.6), 1.6)
    if screws and (x1 - x0) > 40 and (y1 - y0) > 18:
        m = 8 if (y1 - y0) > 30 else 6
        for sx in (x0 + m, x1 - m):
            screw(p, sx, (y0 + y1) / 2, 2.6 if (y1 - y0) < 34 else 3.4)


def enamel_plate(p, x0, y0, x1, y1, fill=ENAMEL, rim=BRASS):
    p.rect(x0 - 3, y0 - 3, x1 + 3, y1 + 3, rim, INK, 2.2, 3)
    p.rect(x0, y0, x1, y1, fill, INK, 1.4, 2)
    p.line([(x0 + 3, y1 - 2), (x1 - 3, y1 - 2)], mix(fill, INK, 0.12), 1.4)


def bulkhead(p, rng, x0, y0, x1, y1, seams, step=120):
    """Storm-navy riveted bulkhead plates with vertical seams at `seams`."""
    p.rect(x0, y0, x1, y1, BULK, None)
    lay = p.layer()
    for _ in range(int((x1 - x0) * (y1 - y0) / 30000) + 4):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        lay.ell(x, y, rng.uniform(60, 180), rng.uniform(30, 90), BULK_DK if rng.random() < 0.6 else BULK_HI, None)
    p.put_soft(lay, 34, 0.35)
    for x in seams:
        p.line([(x, y0), (x, y1)], BULK_DK, 4)
        p.line([(x + 3, y0), (x + 3, y1)], BULK_HI, 1.4)
        p.line([(x - 2, y0), (x - 2, y1)], INK, 1.4)
        for y in range(int(y0) + 60, int(y1) - 10, step):
            rivet(p, x - 12, y)
            rivet(p, x + 14, y)


def floor_band(p, rng, y0, y1=H):
    """Soot over timber: plank strips widening toward the viewer."""
    base = mix(TIMBER, SOOT, 0.45)
    p.rect(-4, y0, W + 4, y1 + 4, base, None)
    y, hgt = y0, 22
    while y < y1:
        p.line([(-4, y), (W + 4, y)], mix(base, INK, 0.55), 2.0)
        p.line([(-4, y + 2), (W + 4, y + 2)], mix(base, TIMBER_HI, 0.35), 1.2)
        off = rng.uniform(0, 300)
        for x in range(int(off), W, int(rng.uniform(260, 420))):
            p.line([(x, y + 2), (x, y + hgt)], mix(base, INK, 0.45), 1.4)
        y += hgt
        hgt = int(hgt * 1.22)
    lay = p.layer()
    for _ in range(18):
        lay.ell(rng.uniform(0, W), rng.uniform(y0 + 20, y1), rng.uniform(80, 220), rng.uniform(10, 30), SOOT, None)
    p.put_soft(lay, 18, 0.35)
    p.line([(-4, y0), (W + 4, y0)], INK, 3)


def glow(p, cx, cy, r, col=AMBER_HI, opacity=0.6):
    lay = p.layer()
    lay.ell(cx, cy, r * 0.55, r * 0.55, col, None)
    p.put_soft(lay, r * 0.45, opacity)


def lamp_socket(p, cx, cy, r, lit=False, dead=False):
    p.ell(cx, cy, r + 5, r + 5, BRASS, INK, 2.2)
    p.arc(cx, cy, r + 3, r + 3, 200, 320, BRASS_HI, 1.4)
    if lit:
        glow(p, cx, cy, r * 3.2, AMBER_HI, 0.55)
        p.ell(cx, cy, r, r, AMBER, INK, 1.8)
        p.ell(cx - r * 0.15, cy - r * 0.15, r * 0.62, r * 0.62, AMBER_HI, None)
        p.ell(cx - r * 0.3, cy - r * 0.35, r * 0.22, r * 0.18, (250, 236, 200), None)
    else:
        g = GLASS_DEAD if dead else mix(IRON, SEAGLASS, 0.2)
        p.ell(cx, cy, r, r, g, INK, 1.8)
        p.arc(cx, cy, r * 0.62, r * 0.62, 200, 260, mix(g, PAPER, 0.35), 1.6)


# ============================================================================ VIEW A: the chair
WIN_C = (724, 346)
WIN_R = 250
WIN_RI = 224
WIN_BOT = 380


def window_interior():
    pts = [(WIN_C[0] + WIN_RI * math.cos(math.radians(a)), WIN_C[1] + WIN_RI * math.sin(math.radians(a)))
           for a in [180 + i * 1.5 for i in range(121)]]
    return pts + [(WIN_C[0] + WIN_RI, WIN_BOT), (WIN_C[0] - WIN_RI, WIN_BOT)]


def arch_pts(cx, top, x0, x1, ybot, n=60):
    r = (x1 - x0) / 2
    cy = top + r
    pts = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
           for a in [180 + i * 180 / n for i in range(n + 1)]]
    return [(x0, ybot)] + pts + [(x1, ybot)]


def side_arch(p, rng, x0, x1, y0, y1, side):
    cx = (x0 + x1) / 2
    outer = arch_pts(cx, y0, x0, x1, y1)
    inner = arch_pts(cx, y0 + 16, x0 + 16, x1 - 16, y1)
    p.poly(outer, IRON, INK, 3)
    p.poly(inner, mix(BULK_DK, BLACK, 0.25), None)
    m = poly_mask((W, H), inner)
    # beyond: the next wall of the chamber, a step darker, its nearest fittings showing
    lay = p.layer()
    if side == "left":
        lay.rect(x0 + 40, y0 + 40, x1 + 10, y1, mix(BULK, BULK_DK, 0.5), None)
        lay.line([(x0 + 40, y0 + 40), (x0 + 40, y1)], INK, 2)
        # the edge of the frames wall: one brass frame's corner and a shuttered lamp
        lay.rect(x0 + 88, y0 + 200, x1 + 30, y0 + 380, BRASS_LO, INK, 2.4, 2)
        lay.rect(x0 + 102, y0 + 236, x1 + 30, y0 + 330, mix(BRASS_DK, BLACK, 0.3), INK, 1.8)
        lay.rect(x0 + 108, y0 + 230, x0 + 122, y0 + 246, BRASS_HI, INK, 1.2)
        lay.ell(x0 + 112, y0 + 110, 26, 26, BRASS_LO, INK, 2.2)
        lay.ell(x0 + 112, y0 + 110, 21, 21, IRON, INK, 1.4)
        lay.line([(x0 + 112, y0 + 89), (x0 + 112, y0 + 131)], INK, 1.6)
    else:
        lay.rect(x0 - 10, y0 + 40, x1 - 40, y1, mix(BULK, BULK_DK, 0.5), None)
        lay.line([(x1 - 40, y0 + 40), (x1 - 40, y1)], INK, 2)
        # the edge of the routing wall: a plate's edge under its shutter slats, the handle housing
        lay.rect(x0 - 30, y0 + 70, x0 + 60, y0 + 250, BRASS_LO, INK, 2.4, 2)
        for y in range(int(y0) + 82, int(y0) + 246, 14):
            lay.line([(x0 - 30, y), (x0 + 58, y)], BRASS_DK, 1.6)
        lay.rect(x0 + 30, y0 + 290, x0 + 96, y1 - 10, IRON_HI, INK, 2.2, 2)
        lay.rect(x0 + 58, y0 + 300, x0 + 68, y0 + 380, BLACK, INK, 1.2)
    lay.rect(x0, y1 - 30, x1, y1, mix(BULK_DK, SOOT, 0.4), None)
    p.put(lay, mask=m)
    # a little shadow under the arch head, from our side
    sh = p.layer()
    sh.poly(arch_pts(cx, y0 + 16, x0 + 16, x1 - 16, y0 + 140), BLACK, None)
    p.put_soft(sh, 14, 0.35, mask=m)
    p.wob_poly(inner[1:-1], INK, 2.4, closed=False)
    for i in range(0, 61, 10):
        a = math.radians(180 + i * 3)
        r = (x1 - x0) / 2 - 8
        rivet(p, cx + r * math.cos(a), y0 + (x1 - x0) / 2 + r * math.sin(a), 2.6, IRON_HI)
    for y in range(int(y0 + (x1 - x0) / 2) + 40, int(y1) - 10, 60):
        rivet(p, x0 + 8, y, 2.6, IRON_HI)
        rivet(p, x1 - 8, y, 2.6, IRON_HI)


def stair_door(p, rng):
    x0, y0, x1, y1 = 40, 740, 250, 920
    # the floor is cut for the steps down: a dark well under the door
    p.rect(x0 - 10, 896, x1 + 10, 930, mix(SOOT, BLACK, 0.4), INK, 2.4)
    p.rect(x0 - 14, y0 - 14, x1 + 14, y1, IRON, INK, 3, 4)
    p.rect(x0, y0, x1, y1, mix(STORM, BULK, 0.6), INK, 2.6, 3)
    for y in (y0 + 56, y0 + 120):
        p.line([(x0 + 8, y), (x1 - 8, y)], INK, 2)
        p.line([(x0 + 8, y + 3), (x1 - 8, y + 3)], BULK_HI, 1.2)
    for x in range(int(x0) + 14, int(x1), 24):
        rivet(p, x, y0 + 10, 2.4)
        rivet(p, x, y1 - 10, 2.4)
    for y in (y0 + 34, y1 - 40):
        p.rect(x0 - 6, y - 8, x0 + 46, y + 8, BRASS_LO, INK, 2, 3)
        screw(p, x0 + 34, y, 3)
    p.ell(x1 - 34, y0 + 88, 13, 13, BRASS, INK, 2.2)
    p.ell(x1 - 34, y0 + 88, 5, 5, BRASS_DK, INK, 1.2)
    # the first two steps, in the light that falls through
    p.rect(x0 + 6, y1 - 24, x1 - 6, y1 - 2, mix(TIMBER, SOOT, 0.5), INK, 1.6)


def chair(p, rng):
    wood, wood_hi = mix(TIMBER_DK, SOOT, 0.25), TIMBER
    # shadow on the floor
    sh = p.layer()
    sh.ell(520, 904, 190, 12, BLACK, None)
    p.put_soft(sh, 8, 0.45)
    # rear leg / back post x 380-420, y 470-900
    p.rect(380, 470, 420, 900, wood, INK, 2.8, 6)
    p.line([(386, 480), (386, 892)], wood_hi, 1.6)
    # stretcher between the legs
    p.rect(420, 812, 610, 828, mix(TIMBER_DK, SOOT, 0.4), INK, 2.2, 3)
    # front legs x 610-640
    p.rect(610, 712, 640, 900, wood, INK, 2.8, 4)
    p.line([(615, 720), (615, 892)], wood_hi, 1.4)
    # floor bolts: iron shoes bolted down
    for (x0, x1) in ((370, 430), (600, 650)):
        p.rect(x0, 888, x1, 902, IRON, INK, 2.2, 2)
        for bx in (x0 + 9, x1 - 9):
            p.ell(bx, 891, 4.4, 3.2, BRASS, INK, 1.2)
    # back cushion on the post front, 560-690
    p.rect(412, 552, 456, 696, LEATHER, INK, 2.6, 14)
    p.line([(446, 566), (446, 682)], LEATHER_HI, 2)
    p.line([(418, 566), (418, 682)], LEATHER_DK, 2)
    for y in (580, 624, 668):
        p.ell(434, y, 3.4, 3.4, BRASS, INK, 1.1)
        p.line([(426, y - 6), (434, y), (426, y + 6)], LEATHER_DK, 1.4)
    # headrest pad
    p.rect(396, 470, 446, 546, LEATHER, INK, 2.8, 18)
    p.line([(436, 486), (436, 532)], LEATHER_HI, 2)
    p.line([(404, 486), (404, 532)], LEATHER_DK, 2)
    p.ell(420, 508, 3.4, 3.4, BRASS, INK, 1.1)
    # a brass collar where the headrest clamps the post: an instrument fitting, not furniture
    p.rect(374, 540, 426, 556, BRASS_LO, INK, 2.2, 3)
    screw(p, 400, 548, 3)
    # seat: top y 690, x 380-640, 30 px
    seat(p, dent=False)
    # armrest y 610, x 420-620, with its front support
    p.rect(598, 612, 612, 692, wood, INK, 2.4, 3)
    p.rect(418, 602, 626, 618, wood, INK, 2.6, 6)
    p.rect(450, 596, 612, 606, LEATHER, INK, 2.0, 5)
    p.line([(458, 599), (604, 599)], LEATHER_HI, 1.2)
    # brass corner fittings: survey kit, not furniture
    for (x, y) in ((400, 704), (625, 704), (400, 610), (605, 610)):
        p.ell(x, y, 4.2, 4.2, BRASS, INK, 1.2)


def seat(p, dent):
    # the frame rail
    p.rect(380, 704, 640, 720, mix(TIMBER_DK, SOOT, 0.25), INK, 2.6, 3)
    if not dent:
        p.rect(380, 688, 640, 708, LEATHER, INK, 2.6, 8)
        p.line([(392, 692), (630, 692)], LEATHER_HI, 2)
        p.line([(392, 703), (630, 703)], LEATHER_DK, 1.6)
    else:
        # a deep, body-shaped hollow: dark inside, a pale rim where the leather is stretched
        top = [(380 + 8, 688)]
        for i in range(41):
            x = 420 + 200 * i / 40
            t = i / 40
            prof = 0.85 * math.sin(math.pi * t) ** 0.9 + 0.25 * math.exp(-((t - 0.28) / 0.12) ** 2)
            top.append((x, 688 + 16 * min(1.0, prof)))
        top += [(632, 688)]
        body = [(380, 696)] + top + [(640, 696), (640, 708), (380, 708)]
        p.poly(body, LEATHER, None)
        hollow = top[1:-1] + [(x, 688) for x, _ in top[-2:0:-1]]
        p.poly(hollow, mix(LEATHER_DK, BLACK, 0.4), None)
        p.line([(380, 696), (388, 688)] + top[1:] + [(640, 696)], INK, 2.6)
        p.line([(380, 708), (640, 708)], INK, 2.0)
        p.line([(x, 688) for x, _ in top[1:-1]], mix(LEATHER_HI, PAPER, 0.5), 2.4)
        sheen = [(x, y + 3) for (x, y) in top[8:-8]]
        p.line(sheen, mix(LEATHER, LEATHER_DK, 0.5), 1.6)


def column(p, rng):
    x0, x1, y0, y1 = 900, 1060, 400, 900
    # conduit up to the deckhead
    p.rect(966, -4, 994, y0, IRON, INK, 2.4)
    p.line([(972, 0), (972, y0)], IRON_HI, 1.4)
    for y in (90, 230, 360):
        p.rect(958, y, 1002, y + 14, BRASS_LO, INK, 2, 2)
    # capital and plinth
    body = mix(BRASS, BULK, 0.32)       # tarnished: the brass has gone dull in the dark
    p.rect(x0 - 14, y0, x1 + 14, y0 + 30, mix(BRASS, BULK, 0.15), INK, 2.8, 3)
    p.rect(x0 - 18, y1 - 32, x1 + 18, y1, mix(BRASS_LO, BULK, 0.25), INK, 2.8, 3)
    p.rect(x0, y0 + 30, x1, y1 - 32, body, INK, 2.8)
    # cylinder shading: matte bands, not a gradient
    p.rect(x0 + 14, y0 + 32, x0 + 34, y1 - 34, mix(BRASS, BRASS_HI, 0.3), None)
    p.rect(x0 + 4, y0 + 32, x0 + 14, y1 - 34, mix(BRASS, BULK, 0.15), None)
    p.rect(x1 - 46, y0 + 32, x1 - 2, y1 - 34, mix(BRASS_LO, BULK, 0.4), None)
    p.rect(x1 - 18, y0 + 32, x1 - 2, y1 - 34, mix(BRASS_DK, BULK, 0.4), None)
    # tarnish: verdigris runs down from every band
    lay = p.layer()
    for _ in range(18):
        x = rng.uniform(x0 + 6, x1 - 10)
        y = rng.uniform(y0 + 40, y1 - 120)
        lay.rect(x, y, x + rng.uniform(3, 7), y + rng.uniform(40, 120), VERD, None, r=2)
    p.put_soft(lay, 1.2, 0.5, mask=poly_mask((W, H), [(x0, y0 + 30), (x1, y0 + 30), (x1, y1 - 32), (x0, y1 - 32)]))
    for y in range(int(y0) + 120, int(y1) - 40, 140):
        p.rect(x0 - 4, y, x1 + 4, y + 14, mix(BRASS_LO, BULK, 0.2), INK, 2.2)
        p.line([(x0, y + 3), (x1, y + 3)], BRASS, 1.2)
        for x in range(int(x0) + 14, int(x1), 26):
            p.ell(x, y + 7, 2.6, 2.6, BRASS_HI, INK, 1)
    p.line([(x0, y0 + 30), (x0, y1 - 32)], INK, 3)
    p.line([(x1, y0 + 30), (x1, y1 - 32)], INK, 3)
    for x in range(int(x0) + 10, int(x1), 22):
        p.ell(x, y0 + 15, 2.6, 2.6, BRASS_HI, INK, 1)
        p.ell(x, y1 - 16, 2.6, 2.6, BRASS_HI, INK, 1)
    # the arm roots: three empty sockets on the left face
    for (rx, ry) in ((900, 440), (900, 600), (900, 860)):
        p.rect(rx - 6, ry - 20, rx + 22, ry + 20, BRASS_LO, INK, 2.4, 4)
        p.ell(rx - 4, ry, 15, 15, BRASS, INK, 2.4)
        p.ell(rx - 4, ry, 7, 7, mix(BRASS_DK, BLACK, 0.4), INK, 1.4)
    # pipe to the gauge
    p.rect(x1 + 14, 482, 1118, 498, IRON, INK, 2.2)
    p.line([(x1 + 16, 486), (1116, 486)], IRON_HI, 1.2)
    p.rect(1090, 476, 1100, 504, BRASS_LO, INK, 1.6)


def gauge(p, cx=1170, cy=490, r=56):
    sh = p.layer()
    sh.ell(cx + 4, cy + 6, r, r, BLACK, None)
    p.put_soft(sh, 6, 0.4)
    p.ell(cx, cy, r, r, BRASS, INK, 2.8)
    p.arc(cx, cy, r - 4, r - 4, 190, 300, BRASS_HI, 2)
    p.arc(cx, cy, r - 4, r - 4, 10, 120, BRASS_DK, 2)
    p.ell(cx, cy, r - 10, r - 10, PAPER, INK, 2.2)
    p.arc(cx, cy, r - 14, r - 14, 200, 250, PAPER_HI, 1.4)
    for a in range(0, 360, 60):
        x = cx + (r - 5) * math.cos(math.radians(a + 30))
        y = cy + (r - 5) * math.sin(math.radians(a + 30))
        p.ell(x, y, 2.2, 2.2, BRASS_HI, INK, 0.9)


def window(p, rng):
    outer = arch_pts(724, 96, 474, 974, 386)
    p.poly(outer, IRON, INK, 3)
    mid = arch_pts(724, 108, 486, 962, 386)
    p.poly(mid, BRASS_LO, INK, 2)
    p.poly(window_interior(), WIN_FLAT, INK, 2.6)
    # rivets round the frame
    for i in range(0, 181, 9):
        a = math.radians(180 + i)
        x = WIN_C[0] + 237 * math.cos(a)
        y = WIN_C[1] + 237 * math.sin(a)
        if y < WIN_C[1] + 4:
            rivet(p, x, y, 2.4, IRON_HI)
    for y in (360, 376):
        rivet(p, 480 + 1, y, 2.2, IRON_HI)
        rivet(p, 968 - 1, y, 2.2, IRON_HI)
    # inner bead highlight on the brass, lower-right in shadow
    p.arc(WIN_C[0], WIN_C[1], 232, 232, 185, 300, BRASS_HI, 1.6)
    # brass sill 386-400
    p.rect(460, 384, 988, 400, BRASS, INK, 2.6, 2)
    p.line([(464, 387), (984, 387)], BRASS_HI, 1.4)
    sh = p.layer()
    sh.rect(470, 400, 978, 418, BLACK, None)
    p.put_soft(sh, 6, 0.35)


def pipe_run(p, y, x0=-4, x1=W + 4):
    p.rect(x0, y - 9, x1, y + 9, IRON, INK, 2.4)
    p.line([(x0, y - 4), (x1, y - 4)], IRON_HI, 1.4)
    for x in range(int(x0) + 90, int(x1), 240):
        p.rect(x - 8, y - 13, x + 8, y + 13, mix(BRASS_LO, BULK, 0.3), INK, 2, 2)
        p.rect(x - 3, y - 30, x + 3, y - 13, IRON_LO, INK, 1.4)


def caged_lamp(p, x, y):
    """A small caged bulkhead lamp hanging from the deckhead, burning low."""
    p.line([(x, y), (x, y + 70)], INK, 2.4)
    glow(p, x, y + 96, 180, AMBER, 0.22)
    p.rect(x - 16, y + 66, x + 16, y + 76, BRASS_LO, INK, 2, 2)
    p.ell(x, y + 96, 16, 20, mix(AMBER, BULK, 0.25), INK, 2)
    p.ell(x - 4, y + 90, 6, 8, mix(AMBER_HI, AMBER, 0.5), None)
    for dx in (-12, 0, 12):
        p.line([(x + dx * 0.7, y + 76), (x + dx, y + 96), (x + dx * 0.7, y + 116)], INK, 1.8)
    p.ell(x, y + 96, 18, 22, None, INK, 2)
    p.rect(x - 10, y + 114, x + 10, y + 120, BRASS_LO, INK, 1.6, 2)


def wainscot(p):
    """The lower bulkhead: a darker riveted wainscot under a rail, plates seamed every 182 px."""
    y0, y1 = 700, 866
    p.rect(-4, y0, W + 4, y1, mix(BULK, STORM, 0.42), None)
    for x in range(91, W, 182):
        p.line([(x, y0 + 12), (x, y1)], mix(BULK_DK, INK, 0.3), 3)
        p.line([(x + 3, y0 + 12), (x + 3, y1)], mix(BULK, BULK_HI, 0.4), 1.2)
        for y in range(y0 + 36, y1 - 6, 44):
            rivet(p, x - 11, y, 2.6)
            rivet(p, x + 13, y, 2.6)
    p.rect(-4, y0, W + 4, y0 + 12, mix(BULK_HI, BRASS_LO, 0.18), INK, 2.4)
    p.line([(-4, y0 + 3), (W + 4, y0 + 3)], mix(BULK_HI, PAPER, 0.18), 1.2)
    for x in range(30, W, 60):
        rivet(p, x, y0 + 6, 2.2)
    sh = p.layer()
    sh.rect(-4, y0 + 12, W + 4, y0 + 22, BLACK, None)
    p.put_soft(sh, 4, 0.3)


STAIN_TOP = {1: 800, 2: 736}


def tide_stain(p, level):
    """Condensation and a tide line on the lower bulkhead, rising with the stage (as the office's
    water band does): a flat sea-glass wash, a hard pale line with ink under it, short drips.
    Its own Random, so the room's other plates paint identically with or without it."""
    r = random.Random(SEED + 9100)          # the same drips at both levels, so S2 is S1 grown
    top = STAIN_TOP[level]
    lay = p.layer()
    lay.rect(-4, top, W + 4, 866, mix(SEAGLASS, BULK, 0.42), None)
    p.put(lay, 0.62)
    if level >= 2:
        # the S1 line is still there, lower down: an older mark
        old = STAIN_TOP[1]
        p.line([(-4, old), (W + 4, old)], mix(SEAGLASS, BULK, 0.25), 2.0)
    drips = p.layer()
    for _ in range(60):
        x = r.uniform(0, W)
        L = r.uniform(14, 70) * (1.35 if level >= 2 else 1.0)
        drips.rect(x, top + 2, x + r.uniform(2.5, 4.5), top + L, mix(SEAGLASS, INK, 0.35), None, r=2)
    p.put(drips, 0.7)
    p.line([(-4, top + 3), (W + 4, top + 3)], INK, 2.6)
    p.line([(-4, top), (W + 4, top)], mix(SEAGLASS_HI, PAPER, 0.25), 3.0)
    # beads of condensation above the line
    beads = p.layer()
    for _ in range(70):
        x = r.uniform(0, W)
        y = top - r.uniform(4, 60)
        beads.ell(x, y, 1.4, 2.0, mix(SEAGLASS_HI, PAPER, 0.3), None)
    p.put(beads, 0.3)


def paint_view_a(rng, dent=False, stain=0, pinned=False):
    p = Pen(W, H, rng, BULK)
    bulkhead(p, rng, -4, -4, W + 4, 900, [362, 1086])
    # deckhead coaming and skirting, riveted every 120 px
    p.rect(-4, -4, W + 4, 36, mix(STORM, BULK, 0.4), INK, 2.6)
    wainscot(p)
    if stain:
        tide_stain(p, stain)
    p.rect(-4, 866, W + 4, 900, mix(STORM, BULK_DK, 0.5), INK, 2.6)
    for x in range(60, W, 120):
        rivet(p, x, 18, 2.8)
        rivet(p, x, 883, 2.8)
    # a dim, even light from somewhere above the chair: keeps band 7 mid-dark, never black
    lay = p.layer()
    lay.ell(640, 600, 520, 340, BULK_HI, None)
    p.put_soft(lay, 120, 0.45)
    floor_band(p, rng, 900)
    pipe_run(p, 64)
    caged_lamp(p, 250, 36)
    window(p, rng)
    side_arch(p, rng, 30, 180, 300, 720, "left")
    side_arch(p, rng, 1268, 1418, 300, 720, "right")
    stair_door(p, rng)
    column(p, rng)
    gauge(p)
    if pinned:
        gauge_pinned(p)
    chair(p, rng)
    if dent:
        seat(p, True)
        # the back cushion and the headrest pressed hollow where a back and a head have been
        for (cx, cy, rx, ry) in ((436, 626, 9, 44), (422, 508, 10, 22)):
            p.ell(cx, cy, rx, ry, mix(LEATHER_DK, BLACK, 0.35), INK, 1.8)
            p.arc(cx, cy, rx + 1.5, ry + 1.5, 290, 70, mix(LEATHER_HI, PAPER, 0.45), 2.0)
    return p


def gauge_pinned(p, cx=1170, cy=490, r=56):
    """S2: the needle is hard against IX and the bezel has bowed out there; the glass is crazed."""
    lay = p.layer()
    pts_out, pts_in = [], []
    for i in range(41):
        a = 10 + 70 * i / 40
        bow = 11 * math.sin(math.pi * i / 40) ** 1.2
        pts_out.append((cx + (r + bow) * math.cos(math.radians(a)), cy + (r + bow) * math.sin(math.radians(a))))
        pts_in.append((cx + (r - 2) * math.cos(math.radians(a)), cy + (r - 2) * math.sin(math.radians(a))))
    lay.poly(pts_out + pts_in[::-1], BRASS, None)
    lay.line(pts_out, INK, 2.8)
    lay.line(offset_line(pts_out, 3), BRASS_HI, 1.4)
    p.put(lay)
    # the crazing: four ink cracks out of the point the needle presses on
    hit = (cx + (r - 14) * math.cos(math.radians(45)), cy + (r - 14) * math.sin(math.radians(45)))
    for a, L in ((200, 34), (235, 40), (262, 26), (300, 30), (170, 22)):
        q = (hit[0] + L * math.cos(math.radians(a)), hit[1] + L * math.sin(math.radians(a)))
        mid = (lerp(hit[0], q[0], 0.5) + 3, lerp(hit[1], q[1], 0.5) - 2)
        p.line([hit, mid, q], INK, 1.5)
    # the stop pin at IX
    p.ell(hit[0] + 6, hit[1] + 6, 3.2, 3.2, BRASS_DK, INK, 1.2)


def view_a_final(rng, dent=False, stain=0, pinned=False):
    im = paint_view_a(rng, dent, stain, pinned).done()
    return grain(im, rng_for(1000))


def paint_view_a_base(rng):
    return view_a_final(rng_for(0))


def paint_cushion_dent(rng):
    base = view_a_final(rng_for(0))
    var = view_a_final(rng_for(0), dent=True)
    return diff_overlay(base, var)


def a_overlay(**kw):
    return lambda rng: diff_overlay(view_a_final(rng_for(0)), view_a_final(rng_for(0), **kw))


def interior_mask():
    return mask1x(poly_mask((W, H), window_interior()))


# --- the surface beyond the glass
# The same standing plane the lantern gallery (R09) shows -- storm navy at the top blending down to
# sea-glass, crossed by the immense pale arc of something with no edge -- now so close that the arc
# is two lid-folds across the top of the arch and, low and centred, one huge flat iris whose pupil
# sits off-centre toward the chair. Mid value (about 90-140), flat shapes, navy ink contours.
SURF_TOP = mix(BULK_HI, SEAGLASS, 0.45)            # ~ (85,108,109)
SURF_BOT = mix(SEAGLASS, SEAGLASS_HI, 0.30)        # ~ (113,141,131)
SURF_FOLD = mix(SURF_TOP, SEAGLASS_HI, 0.30)
SURF_RIM = mix(SEAGLASS_HI, PAPER_HI, 0.45)        # the pale bone of the rims
SURF_IRIS = mix(SEAGLASS, STORM, 0.32)
SURF_IRIS_RING = mix(SEAGLASS, SEAGLASS_HI, 0.55)
SURF_PUPIL = mix(STORM, BULK_DK, 0.35)
SURF_LID = mix(STORM, BULK, 0.55)                  # the resting lid: storm navy, ~55
SURF_MARGIN = mix(STORM, BULK_DK, 0.5)             # the withdrawn margin of darker water
FOLD_C = (724, 1100)                               # the lid-folds' centre, far below the floor
FOLD_R = (950, 904)
IRIS_C, IRIS_R = (712, 318), 136                   # 272 px across: ~60% of the 448 px arch
PUPIL_C, PUPIL_R = (642, 352), 40                  # toward the chair (down and left)
# the resting lid line: apex at LID_REST at the arch sides, sagging LID_SAG at the centre; the
# view draws the a_lid_line band along the same curve (R12_view.gd LID_* constants)
LID_REST, LID_SAG, LID_THICK = 226, 44, 22
LID_HW = 224


def lid_curve_y(x, y_edge):
    dx = (x - WIN_C[0]) / LID_HW
    return y_edge + LID_SAG * max(0.0, 1 - dx * dx)


def fold_arcs(p, base, opacity=1.0):
    """The two lid-folds: bands of immense circles whose ends run off both sides of the arch."""
    cx, cy = FOLD_C
    lay = p.layer()
    lay.ell(cx, cy, FOLD_R[0], FOLD_R[0], SURF_FOLD, None)
    lay.ell(cx, cy, FOLD_R[1], FOLD_R[1], base, None)
    for r, w_ink, w_rim in ((FOLD_R[0], 3.0, 4.0), (FOLD_R[1], 2.6, 3.0)):
        lay.arc(cx, cy, r + 2.5, r + 2.5, 240, 300, INK, w_ink)
        lay.arc(cx, cy, r - 2.0, r - 2.0, 240, 300, SURF_RIM, w_rim)
    p.put(lay, opacity, mask=interior_mask_ss())


def iris(p, c, r, pupil_c, pupil_r, rings=5):
    """A pale bone ring, a flat iris field, eccentric rings drawing in toward an off-centre pupil."""
    m = interior_mask_ss()
    lay = p.layer()
    lay.ell(c[0], c[1], r + 10, r + 10, SURF_RIM, INK, 3.2)
    lay.ell(c[0], c[1], r - 8, r - 8, SURF_IRIS, INK, 2.6)
    for k in range(1, rings + 1):
        t = k / (rings + 1)
        rr = lerp(r - 8, pupil_r + 6, t)
        cc = (lerp(c[0], pupil_c[0], t), lerp(c[1], pupil_c[1], t))
        lay.ell(cc[0], cc[1], rr, rr, None, mix(SURF_IRIS, SURF_IRIS_RING, 1 - 0.5 * t), 2.4 if k % 2 else 1.6)
    lay.ell(pupil_c[0], pupil_c[1], pupil_r + 7, pupil_r + 7, mix(SURF_IRIS, STORM, 0.5), None)
    lay.ell(pupil_c[0], pupil_c[1], pupil_r, pupil_r, SURF_PUPIL, INK, 3.0)
    p.put(lay, mask=m)


def interior_mask_ss():
    return poly_mask((W, H), window_interior())


def surface_pen(rng, iris_r=IRIS_R, iris_c=IRIS_C, pupil_c=PUPIL_C, pupil_r=PUPIL_R, folds=True):
    p = Pen(W, H, rng)
    m = interior_mask_ss()
    top = WIN_C[1] - WIN_RI
    p.vgrad(470, top - 4, 980, WIN_BOT + 4, SURF_TOP, SURF_BOT, mask=m)
    # a broad flat sheen band at mid height, as on R09's standing plane
    sheen = p.layer()
    sheen.rect(470, 268, 980, 300, mix(SURF_BOT, PAPER_HI, 0.25), None)
    p.put_soft(sheen, 18, 0.25, mask=m)
    if folds:
        fold_arcs(p, SURF_TOP)
    iris(p, iris_c, iris_r, pupil_c, pupil_r)
    return p


def surface_final(pen, k):
    im = pen.done()
    return grain(im, rng_for(k), amp=4, mottle=4, speck=6)


def paint_surface(rng):
    return surface_final(surface_pen(rng), 2010)


def lid_region_pts(y_edge, step=4):
    """The arch interior above the resting lid curve (polygon, 1x)."""
    top = WIN_C[1] - WIN_RI - 6
    pts = [(470, top)]
    for x in range(470, 981, step):
        pts.append((x, lid_curve_y(x, y_edge)))
    pts.append((980, top))
    return pts


def paint_surface_lid(rng):
    """After the third look: the lid has come down and rests, half over the iris. Persistent."""
    p = Pen(W, H, rng)
    m = ImageChops.multiply(interior_mask_ss(), poly_mask((W, H), lid_region_pts(LID_REST + LID_THICK / 2)))
    lay = p.layer()
    lay.rect(460, 80, 990, 400, SURF_LID, None)
    # the fold of the lid itself: two flat creases parallel to its edge
    for dy, col, w in ((-34, mix(SURF_LID, SEAGLASS, 0.35), 3.0), (-70, mix(SURF_LID, SEAGLASS, 0.22), 2.4)):
        pts = [(x, lid_curve_y(x, LID_REST + dy)) for x in range(470, 981, 6)]
        lay.line([(x, y + 2.5) for x, y in pts], INK, w * 0.8)
        lay.line(pts, col, w)
    p.put(lay, mask=m)
    # the iris below the lid falls into the lid's shadow: a darker crescent just under the edge
    sh = p.layer()
    sh.poly(lid_region_pts(LID_REST + LID_THICK / 2 + 18), STORM, None)
    p.put_soft(sh, 8, 0.35, mask=interior_mask_ss())
    return grain(p.done(), rng_for(2011), amp=4, mottle=4, speck=6)


def withdrawn_inner_pts(inset_side=50, inset_bot=30):
    r = WIN_RI - inset_side
    pts = [(WIN_C[0] + r * math.cos(math.radians(a)), WIN_C[1] + r * math.sin(math.radians(a)))
           for a in [180 + i * 1.5 for i in range(121)]]
    return pts + [(WIN_C[0] + r, WIN_BOT - inset_bot), (WIN_C[0] - r, WIN_BOT - inset_bot)]


def withdrawn_pen(rng):
    """P26: it drew back from the glass. A broad margin of darker water; a lighter field inside,
    the iris smaller and further off -- and still turned toward the chair."""
    p = Pen(W, H, rng)
    m = interior_mask_ss()
    lay = p.layer()
    lay.rect(460, 80, 990, 400, SURF_MARGIN, None)
    p.put(lay, mask=m)
    inner = withdrawn_inner_pts()
    mi = poly_mask((W, H), inner)
    top = WIN_C[1] - (WIN_RI - 50)
    p.vgrad(470, top - 4, 980, WIN_BOT, mix(SURF_BOT, SEAGLASS_HI, 0.35), mix(SEAGLASS_HI, PAPER_HI, 0.30), mask=mi)
    # the folds, seen further off: smaller, tighter, the same pale bone
    lay = p.layer()
    for r, w_ink, w_rim in ((FOLD_R[0] - 70, 2.6, 3.4), (FOLD_R[1] - 70, 2.2, 2.6)):
        lay.arc(FOLD_C[0], FOLD_C[1], r + 2.5, r + 2.5, 240, 300, INK, w_ink)
        lay.arc(FOLD_C[0], FOLD_C[1], r - 2.0, r - 2.0, 240, 300, SURF_RIM, w_rim)
    p.put(lay, mask=mi)
    il = p.layer()
    ic, ir = (716, 300), 92
    pc, pr = (688, 316), 28
    il.ell(ic[0], ic[1], ir + 8, ir + 8, SURF_RIM, INK, 3.0)
    il.ell(ic[0], ic[1], ir - 6, ir - 6, mix(SURF_IRIS, SEAGLASS, 0.3), INK, 2.4)
    for k in range(1, 4):
        t = k / 4
        rr = lerp(ir - 6, pr + 5, t)
        cc = (lerp(ic[0], pc[0], t), lerp(ic[1], pc[1], t))
        il.ell(cc[0], cc[1], rr, rr, None, mix(SURF_IRIS, SURF_IRIS_RING, 1 - 0.4 * t), 2.0)
    il.ell(pc[0], pc[1], pr, pr, SURF_PUPIL, INK, 2.8)
    p.put(il, mask=mi)
    # the edge of the drawn-back water: a hard ink line with a pale lip on the inside
    p.line(inner[:-2], INK, 3.4)
    p.line([inner[-2], inner[-1], inner[0]], INK, 3.4)
    p.line([inner[-2], inner[-2 - 0]], INK, 3.4)
    p.line(withdrawn_inner_pts(54, 34)[:-2], SURF_RIM, 2.0)
    # ripples of the margin: three flat lines following the arch, darker on darker
    for d in (14, 28):
        p.line(withdrawn_inner_pts(50 - d, 30 - d * 0.6)[:-2], mix(SURF_MARGIN, SEAGLASS, 0.35), 1.8)
    return p


def paint_surface_withdrawn(rng):
    return surface_final(withdrawn_pen(rng_for(20)), 2012)


def paint_daylight(rng):
    p = Pen(W, H, rng)
    m = poly_mask((W, H), window_interior())
    lay = p.layer()
    lay.rect(470, 90, 980, 300, SKY, None)
    for _ in range(5):
        x, y = rng.uniform(500, 940), rng.uniform(130, 270)
        lay.ell(x, y, rng.uniform(90, 180), rng.uniform(10, 22), mix(SKY, PAPER_HI, 0.4), None)
    lay2 = p.layer()
    lay2.rect(470, 300, 980, 400, SEA, None)
    sky = p.layer()
    sky.rect(470, 90, 980, 300, SKY, None)
    p.put(sky, mask=m)
    p.put_soft(lay, 10, 0.5, mask=m)
    p.put(lay2, mask=m)
    w = p.layer()
    for i in range(14):
        x = rng.uniform(500, 920)
        y = rng.uniform(312, 372)
        L = rng.uniform(26, 70)
        w.line([(x, y), (x + L * 0.5, y - 3), (x + L, y)], mix(SEA, INK, 0.45), 2)
        w.line([(x + 4, y + 3), (x + L * 0.6, y + 1)], mix(SEA, PAPER, 0.4), 1.4)
    w.line([(470, 300), (980, 300)], mix(SEA, INK, 0.5), 2)
    p.put(w, mask=m)
    return p


def paint_morning(rng):
    p = withdrawn_pen(rng_for(20))
    m = poly_mask((W, H), window_interior())
    top = WIN_C[1] - WIN_RI
    lay = p.layer()
    for i in range(84):
        y = top + i
        a = 1.0 if i < 24 else max(0.0, 1 - (i - 24) / 60) ** 1.3
        lay.rect(470, y, 980, y + 1, rgba(AMBER, int(255 * a)), None)
    p.put(lay, 0.85, mask=m)
    return surface_final(p, 2013)


# --- armatures
ARM_ROOTS = ((900, 440), (900, 600), (900, 860))


def knuckle(p, x, y, r=9):
    p.ell(x, y, r, r, BRASS, INK, 2.2)
    p.ell(x, y, r * 0.4, r * 0.4, BRASS_DK, None)
    p.arc(x, y, r - 2, r - 2, 200, 290, BRASS_HI, 1.2)


def arm_rod(p, pts, width=10):
    strap(p, pts, width, BRASS, INK, 2.2, hi=BRASS_HI, lo=BRASS_DK)


def paint_arms(rng, low):
    """The three armatures. `low` False: at rest (S0); True: lowered to Ada's height (P25, S1);
    "ready" (S2): lower still, every fitting opened and turned out toward the viewer, waiting."""
    ready = low == "ready"
    p = Pen(W, H, rng)
    cup = (440, 534) if ready else ((440, 520) if low else (440, 480))
    cuff = (566, 626) if ready else ((560, 612) if low else (560, 598))
    plate = (622, 890) if ready else ((610, 884) if low else (600, 876))
    sh = p.layer()
    head = bezier([(892, 440), (780, 396), (600, 404), (cup[0] + 70, cup[1] - 30), (cup[0] + 36, cup[1])], 48)
    hand = bezier([(892, 600), (800, 636), (680, 628), (cuff[0] + 30, cuff[1])], 40)
    foot = bezier([(892, 860), (800, 884), (700, plate[1] - 6), (plate[0] + 40, plate[1])], 40)
    for path in (head, hand, foot):
        sh.line([(x + 6, y + 10) for x, y in path], BLACK, 10)
    p.put_soft(sh, 6, 0.35)
    arm_rod(p, head, 11)
    if ready:
        # the head cup hinged open into two jaws, the inner faces bright
        for side, off in ((-1, -10), (1, 10)):
            a0, a1 = (100, 260) if side < 0 else (280, 440)
            cx = cup[0] + off
            p.arc(cx, cup[1], 39, 39, a0, a1, INK, 13)
            p.arc(cx, cup[1], 34, 34, a0 + 2, a1 - 2, BRASS, 9)
            p.arc(cx, cup[1], 29, 29, a0 + 4, a1 - 4, BARE, 2.4)
            for a in (a0, a1):
                x = cx + 34 * math.cos(math.radians(a))
                y = cup[1] + 34 * math.sin(math.radians(a))
                p.ell(x, y, 5, 5, BRASS, INK, 1.6)
        p.ell(cup[0] + 10, cup[1] - 36, 6, 6, BRASS_LO, INK, 1.6)      # the hinge
    else:
        p.ell(cup[0], cup[1], 34, 34, None, BRASS, 10)
        p.ell(cup[0], cup[1], 39, 39, None, INK, 2.4)
        p.ell(cup[0], cup[1], 29, 29, None, INK, 2.0)
        p.arc(cup[0], cup[1], 35, 35, 200, 290, BRASS_HI, 1.6)
        p.arc(cup[0], cup[1], 33, 33, 20, 120, BRASS_DK, 1.6)
        for a in (90, 210, 330):
            x = cup[0] + 34 * math.cos(math.radians(a))
            y = cup[1] + 34 * math.sin(math.radians(a))
            p.ell(x, y, 3.2, 3.2, BRASS_DK, INK, 1)
    knuckle(p, *head[16])
    knuckle(p, *head[34], r=8)
    # hand: an open cuff, the gap at the top for a wrist; at S2 it gapes, turned to the viewer
    arm_rod(p, hand, 9)
    rc = 34 if ready else (30 if low else 26)
    gap = 150 if ready else (70 if low else 46)
    face = 235 if ready else 270
    a0, a1 = face + gap / 2, face - gap / 2 + 360
    p.arc(cuff[0], cuff[1], rc, rc, a0, a1, INK, 11.5)
    p.arc(cuff[0], cuff[1], rc, rc, a0 + 1.5, a1 - 1.5, BRASS, 7)
    p.arc(cuff[0], cuff[1], rc + 1, rc + 1, 120, 200, BRASS_HI, 1.4)
    if ready:
        p.arc(cuff[0], cuff[1], rc - 4, rc - 4, a0 + 4, a1 - 4, BARE, 2.0)
    for a in (a0, a1):
        x = cuff[0] + rc * math.cos(math.radians(a))
        y = cuff[1] + rc * math.sin(math.radians(a))
        p.ell(x, y, 5.5, 5.5, BRASS, INK, 1.8)
    knuckle(p, *hand[20])
    # foot: a plate on a stirrup
    arm_rod(p, foot, 10)
    fx0, fx1 = plate[0] - 40, plate[0] + 40
    p.rect(fx0, plate[1] - 7, fx1, plate[1] + 7, BRASS, INK, 2.4, 2)
    p.line([(fx0 + 3, plate[1] - 4), (fx1 - 3, plate[1] - 4)], BRASS_HI, 1.4)
    for x in range(int(fx0) + 10, int(fx1) - 4, 14):
        p.line([(x, plate[1] - 2), (x + 6, plate[1] - 2)], BRASS_DK, 1.4)
    if low:
        # two heel-shaped dents pressed into the plate's top edge, bright where the metal stretched
        for dx in (-18, 16):
            cx = plate[0] + dx
            p.ell(cx, plate[1] - 7, 11, 6, mix(BRASS_DK, BLACK, 0.3), INK, 1.6)
            p.arc(cx, plate[1] - 7, 12, 7, 20, 160, BARE, 1.8)
    if ready:
        # the stirrup straps stand open above the plate
        for dx in (-30, 30):
            x = plate[0] + dx
            p.line([(x, plate[1] - 7), (x + dx * 0.4, plate[1] - 46)], INK, 7)
            p.line([(x, plate[1] - 7), (x + dx * 0.4, plate[1] - 46)], BRASS, 3.6)
            p.ell(x + dx * 0.4, plate[1] - 48, 4.5, 4.5, BRASS, INK, 1.6)
    knuckle(p, *foot[18])
    for (rx, ry) in ARM_ROOTS:
        p.rect(rx - 14, ry - 11, rx + 4, ry + 11, BRASS_LO, INK, 2.2, 3)
        p.line([(rx - 10, ry - 8), (rx - 10, ry + 8)], BRASS_HI, 1.2)
    return p


def ada_mask(ss=SS):
    """Ada seated in profile facing right, sized to the lowered armatures."""
    m = Image.new("L", (W * ss, H * ss), 0)
    d = ImageDraw.Draw(m)

    def P(pts):
        d.polygon([(x * ss, y * ss) for x, y in pts], fill=255)

    def E(cx, cy, rx, ry):
        d.ellipse(((cx - rx) * ss, (cy - ry) * ss, (cx + rx) * ss, (cy + ry) * ss), fill=255)

    def L(pts, w):
        d.line([(x * ss, y * ss) for x, y in pts], fill=255, width=int(w * ss), joint="curve")
        for x, y in (pts[0], pts[-1]):
            E(x, y, w / 2, w / 2)

    # head: under the cup, the face toward the instrument
    E(444, 520, 27, 31)
    P([(462, 506), (472, 516), (474, 528), (468, 532), (470, 540), (462, 548), (452, 552)])  # brow, nose, chin
    E(414, 510, 15, 13)                                    # hair pinned at the nape
    E(426, 494, 22, 15)                                    # hair over the crown
    # neck and shoulders, back against the cushion
    P([(432, 540), (456, 544), (460, 572), (430, 572)])
    P([(426, 566), (470, 566), (486, 590), (490, 640), (482, 690), (432, 692), (424, 640)])
    # upper arm to the elbow at the armrest, forearm to the cuff
    L([(470, 580), (476, 612), (488, 612)], 22)
    L([(488, 610), (566, 612)], 16)
    E(574, 612, 12, 9)                                     # hand in the cuff
    # lap and thighs along the seat, the skirt draped over the knee to mid-calf
    P([(430, 646)] + bezier([(470, 640), (560, 646), (622, 648), (644, 664)], 16)
      + bezier([(644, 664), (650, 720), (652, 770), (658, 800)], 12)
      + [(600, 804)] + bezier([(600, 804), (604, 760), (600, 712), (560, 692)], 12) + [(430, 692)])
    # calves and ankles under the hem, a little apart
    L([(616, 796), (614, 868)], 19)
    L([(634, 796), (630, 868)], 15)
    # feet on the plates, toes to the right
    P([(600, 862), (640, 862), (658, 872), (660, 880), (600, 881)])
    return m


def paint_ada(rng):
    p = Pen(W, H, rng)
    m = ada_mask()
    sil = Image.new("RGBA", m.size, rgba(BLACK))
    sil.putalpha(m)
    p.im.alpha_composite(sil)
    # a 2 px sea-glass rim on the window side (upper right)
    shifted = ImageChops.offset(m, -2 * SS, 2 * SS)
    rim = ImageChops.subtract(m, shifted)
    rl = Image.new("RGBA", m.size, rgba(SEAGLASS_HI))
    rl.putalpha(rim.point(lambda v: v * 200 // 255))
    p.im.alpha_composite(rl)
    return p


def paint_lid_line(rng):
    """The lid: a thick pale bone / sea-glass band with navy ink edges, 448 x 22 (the view bends it
    along the lid curve and clips it to the arch)."""
    w, h = 2 * LID_HW, LID_THICK
    p = Pen(w, h, rng)
    p.rect(-4, 0, w + 4, h, mix(SURF_RIM, SEAGLASS_HI, 0.25), None)
    p.rect(-4, 4, w + 4, 9, mix(SURF_RIM, PAPER_HI, 0.55), None)
    p.rect(-4, h - 7, w + 4, h - 3.5, mix(SURF_RIM, SEAGLASS, 0.45), None)
    p.rect(-4, 0, w + 4, 2.6, INK, None)
    p.rect(-4, h - 2.6, w + 4, h, INK, None)
    return grain(p.done(), rng_for(2014), amp=4, mottle=3, speck=4)


def paint_needle(rng):
    p = Pen(12, 60, rng)
    p.poly([(6, 3), (8.2, 46), (8.2, 58), (3.8, 58), (3.8, 46)], BRASS_DK, INK, 1.0)
    p.line([(6, 8), (6, 50)], BRASS_LO, 0.8)
    p.ell(6, 54, 4.6, 4.6, BRASS_DK, INK, 1.0)
    p.ell(6, 54, 1.4, 1.4, BRASS_HI, None)
    return p


# ============================================================================ VIEW B: the record wall
LAMPS_B = [(214 + 146 * i, 160) for i in range(8)]
FRAMES_B = (130, 554, 978)
TERM_LAMP = (420, 780)
SLOT_B = (260, 790, 396, 806)   # the strip slot; its right end stops short of the lamp bezel
TURN_ANG = (-14, -27, -19, -33, -9, -24, -30, -17)     # each shutter turned its own way at P25
SLACK_ANG = (104, 71, 118, 86, 128, 64, 97, 112)       # and each needle hanging slack at its own angle


def shutter(p, cx, cy, r, ang=0.0, mode="closed", slack=None):
    """A round shuttered lamp: brass bezel and two half-disc iron leaves meeting at a seam."""
    p.ell(cx, cy, r, r, BRASS, INK, 2.8)
    p.arc(cx, cy, r - 3, r - 3, 195, 300, BRASS_HI, 1.8)
    p.arc(cx, cy, r - 3, r - 3, 15, 120, BRASS_DK, 1.8)
    ri = r - 6
    p.ell(cx, cy, ri, ri, BLACK, INK, 1.6)
    if mode == "open":
        # leaves folded back to slivers; a dead lens on empty black
        p.ell(cx, cy, ri - 6, ri - 6, BLACK, None)
        p.ell(cx, cy, ri - 10, ri - 10, None, GLASS_DEAD, 2.2)
        p.arc(cx, cy, ri - 14, ri - 14, 200, 250, mix(GLASS_DEAD, PAPER, 0.3), 1.6)
        for s in (-1, 1):
            p.pie(cx, cy, ri, 90 - s * 90 - 18, 90 - s * 90 + 18, IRON)
        p.ell(cx, cy, ri, ri, None, INK, 1.6)
        return
    gap = 0.0 if mode == "closed" else 3.6
    if mode == "turned":
        # behind the parted leaves: dull dead glass, not a lit lens
        p.ell(cx, cy, ri, ri, mix(GLASS_DEAD, BULK_DK, 0.35), None)
    for s in (-1, 1):
        lay = p.layer()
        # leaf: half disc, rotated about the centre
        a0 = 90 + ang if s < 0 else -90 + ang
        pts = [(cx, cy)] + [(cx + ri * math.cos(math.radians(a0 + i * 6)), cy + ri * math.sin(math.radians(a0 + i * 6)))
                            for i in range(31)]
        ox = gap * s * math.cos(math.radians(ang))
        oy = gap * s * math.sin(math.radians(ang))
        pts = [(x + ox, y + oy) for x, y in pts]
        lay.poly(pts, IRON if s < 0 else IRON_LO, None)
        hl = [rot((cx - s * ri * 0.45 + ox, cy - ri * 0.55 + oy), (cx + ox, cy + oy), ang),
              rot((cx - s * ri * 0.45 + ox, cy + ri * 0.55 + oy), (cx + ox, cy + oy), ang)]
        lay.line(hl, IRON_HI, 1.6)
        p.put(lay, mask=circle_mask((W, H), (cx, cy), ri))
    s0 = rot((cx, cy - ri), (cx, cy), ang)
    s1 = rot((cx, cy + ri), (cx, cy), ang)
    if mode == "closed":
        p.line([s0, s1], INK, 2.8)
        p.line([(s0[0] + 2.5, s0[1] + 3), (s1[0] + 2.5, s1[1] - 3)], IRON_HI, 1.2)
    else:
        p.line([s0, s1], INK, 1.2)
    if slack is not None:
        # a dead subject's needle: slack, hanging off true, each at its own angle
        tip = (cx + (ri - 5) * math.cos(math.radians(slack)), cy + (ri - 5) * math.sin(math.radians(slack)))
        p.line([(cx, cy), tip], INK, 4.2)
        p.line([(cx, cy), tip], mix(BRASS_LO, PAPER, 0.25), 2.0)
    p.ell(cx, cy, 4, 4, BRASS_LO, INK, 1.2)
    p.ell(cx, cy, ri, ri, None, INK, 1.6)


def frame_b(p, rng, fx, deep=False, image=None):
    x0, y0, x1, y1 = fx, 330, fx + 340, 710
    sh = p.layer()
    sh.rect(x0 + 8, y0 + 10, x1 + 8, y1 + 12, BLACK, None)
    p.put_soft(sh, 8, 0.35)
    p.rect(x0, y0, x1, y1, BRASS, INK, 3, 4)
    p.rect(x0 + 10, y0 + 10, x1 - 10, y1 - 10, BRASS_LO, INK, 1.8, 2)
    p.line([(x0 + 4, y1 - 4), (x0 + 4, y0 + 4), (x1 - 4, y0 + 4)], BRASS_HI, 2)
    lay = p.layer()
    for _ in range(8):
        x = rng.uniform(x0 + 14, x1 - 20)
        lay.rect(x, rng.uniform(y0 + 20, y1 - 80), x + rng.uniform(4, 8), y1 - 20, VERD, None, r=3)
    p.put_soft(lay, 3, 0.35, mask=poly_mask((W, H), [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]))
    # recessed card window 300x200 centred at (fx+170, 470)
    wx0, wy0, wx1, wy1 = fx + 20, 370, fx + 320, 570
    p.rect(wx0 - 8, wy0 - 8, wx1 + 8, wy1 + 8, BRASS_DK, INK, 2.4, 2)
    back = mix(BULK_DK, BLACK, 0.45) if deep else mix(BULK_DK, BLACK, 0.15)
    p.rect(wx0, wy0, wx1, wy1, back, INK, 2.2)
    shade = p.layer()
    d = 24 if deep else 12
    shade.poly([(wx0, wy0), (wx1, wy0), (wx1 - d, wy0 + d), (wx0 + d, wy0 + d), (wx0 + d, wy1 - d), (wx0, wy1)], BLACK, None)
    p.put(shade, 0.45)
    p.line([(wx0 + d, wy0 + d), (wx1 - d, wy0 + d), (wx1 - d, wy1 - d), (wx0 + d, wy1 - d), (wx0 + d, wy0 + d)],
           mix(back, BULK_HI, 0.4), 1.2)
    if deep:
        cd = 14
        card = (wx0 + cd + 6, wy0 + cd + 10, wx1 - cd - 6, wy1 - cd - 6)
        p.rect(*card, PAPER, INK, 2.4)
        p.rect(card[0] + 7, card[1] + 7, card[2] - 7, card[3] - 7, None, mix(PAPER, INK, 0.4), 1.2)
        if image:
            record_image(p, image, card)
        shd = p.layer()
        shd.rect(wx0, wy0, wx1, wy0 + cd + 24, BLACK, None)
        p.put_soft(shd, 10, 0.3, mask=poly_mask((W, H), [(wx0, wy0), (wx1, wy0), (wx1, wy1), (wx0, wy1)]))
    # spring clips, top and bottom
    for cx in (fx + 120, fx + 220):
        p.rect(cx - 9, wy0 - 12, cx + 9, wy0 + 12, BRASS_HI, INK, 1.8, 2)
        p.line([(cx - 5, wy0 + 6), (cx + 5, wy0 + 6)], BRASS_DK, 1.4)
        p.rect(cx - 9, wy1 - 12, cx + 9, wy1 + 12, BRASS_HI, INK, 1.8, 2)
        p.line([(cx - 5, wy1 - 6), (cx + 5, wy1 - 6)], BRASS_DK, 1.4)
    for (sx, sy) in ((x0 + 16, y0 + 16), (x1 - 16, y0 + 16), (x0 + 16, y1 - 16), (x1 - 16, y1 - 16)):
        screw(p, sx, sy, 4)
    enamel_plate(p, fx + 40, 650, fx + 300, 690)


def record_image(p, kind, card):
    """The record of Ada, in the record-card style: flat navy on cream, ink contours.
    BODY: her, seated, from behind -- she has not yet looked behind her. PLACE: the station on
    its piles with a dot at its centre. NAME: a typed-name field (the view types ADA MERCER)."""
    x0, y0, x1, y1 = card
    cx = (x0 + x1) / 2
    navy = mix(STORM, BULK_DK, 0.3)
    if kind == "body":
        # Ada seated, seen from behind: head bowed a little, shoulders, the chair's back below them
        back = ([(cx - 70, y1 - 8)] + bezier([(cx - 70, y0 + 120), (cx - 72, y0 + 84), (cx - 40, y0 + 78), (cx - 12, y0 + 76)], 12)
                + bezier([(cx + 12, y0 + 76), (cx + 40, y0 + 78), (cx + 72, y0 + 84), (cx + 70, y0 + 120)], 12) + [(cx + 70, y1 - 8)])
        p.poly(back, navy, INK, 2.4)
        p.rect(cx - 11, y0 + 60, cx + 11, y0 + 82, navy, INK, 2.2)
        p.ell(cx, y0 + 40, 28, 31, navy, INK, 2.4)
        p.ell(cx, y0 + 56, 14, 10, mix(navy, INK, 0.45), INK, 1.8)       # hair pinned at the nape
        p.line([(cx - 10, y0 + 54), (cx + 10, y0 + 58)], mix(navy, PAPER, 0.35), 1.4)   # the pin
        wood = mix(TIMBER_DK, SOOT, 0.2)
        for dx in (-84, 72):
            p.rect(cx + dx, y0 + 108, cx + dx + 12, y1 - 6, wood, INK, 2.2, 3)
        p.rect(cx - 88, y0 + 120, cx + 88, y0 + 132, wood, INK, 2.2, 3)
    elif kind == "place":
        base = y1 - 26
        p.line([(x0 + 10, base), (x1 - 10, base)], INK, 2.2)
        for k in range(6):
            x = x0 + 22 + k * 40
            p.line([(x, base + 6), (x + 14, base + 3), (x + 28, base + 6)], INK, 1.6)
        bx0, bx1 = cx - 70, cx + 70
        for x in range(int(bx0) + 8, int(bx1), 26):
            p.line([(x, base - 2), (x, y0 + 106)], INK, 2.4)              # piles
        p.line([(bx0 - 14, y0 + 106), (bx1 + 14, y0 + 106)], INK, 2.6)  # deck
        p.rect(bx0, y0 + 54, bx1, y0 + 106, None, INK, 2.6)              # station house
        p.poly([(bx0 - 8, y0 + 56), (cx, y0 + 26), (bx1 + 8, y0 + 56)], None, INK, 2.6)
        p.rect(cx + 34, y0 + 14, cx + 52, y0 + 40, None, INK, 2.2)       # lantern
        for wx in (bx0 + 16, bx1 - 34):
            p.rect(wx, y0 + 70, wx + 18, y0 + 86, None, INK, 1.8)
        p.ell(cx, y0 + 80, 11, 11, None, INK, 2.2)                        # you are here
        p.ell(cx, y0 + 80, 6, 6, mix(VIOLET, INK, 0.35), None)
    else:
        p.rect(x0 + 22, y0 + 38, x1 - 22, y1 - 46, mix(PAPER, PAPER_HI, 0.5), INK, 1.6)
        p.line([(x0 + 30, y1 - 58), (x1 - 30, y1 - 58)], mix(PAPER, INK, 0.5), 1.4)
        p.line([(x0 + 26, y0 + 22), (x0 + 96, y0 + 22)], mix(PAPER, INK, 0.45), 2.0)
        p.line([(x1 - 96, y1 - 24), (x1 - 26, y1 - 24)], mix(PAPER, INK, 0.45), 2.0)


def terminal_b(p, rng, lit=False, dark=False):
    x0, y0, x1, y1 = 130, 740, 470, 910
    p.rect(x0, y0, x1, y1, IRON, INK, 3, 6)
    p.rect(x0 + 8, y0 + 8, x1 - 8, y1 - 8, mix(IRON, BULK, 0.5), INK, 1.6, 4)
    p.line([(x0 + 10, y0 + 11), (x1 - 10, y0 + 11)], IRON_HI, 1.4)
    for (sx, sy) in ((x0 + 16, y0 + 16), (x1 - 16, y0 + 16), (x0 + 16, y1 - 16), (x1 - 16, y1 - 16)):
        screw(p, sx, sy, 3.4)
    # the round grille
    gx, gy, gr = 220, 825, 50
    p.ell(gx, gy, gr + 6, gr + 6, BRASS, INK, 2.6)
    p.ell(gx, gy, gr, gr, BLACK, INK, 1.8)
    gl = p.layer()
    for y in range(gy - gr + 8, gy + gr - 4, 10):
        gl.rect(gx - gr, y, gx + gr, y + 5, BRASS_LO, INK, 1.2)
    p.put(gl, mask=circle_mask((W, H), (gx, gy), gr - 2))
    if lit:
        # a faint warm light behind the grille, as if something in there were listening
        g2 = p.layer()
        g2.ell(gx, gy, gr * 0.7, gr * 0.7, AMBER_HI, None)
        p.put_soft(g2, 14, 0.5, mask=circle_mask((W, H), (gx, gy), gr - 2))
    p.ell(gx, gy, gr, gr, None, INK, 2)
    # strip slot
    sx0, sy0, sx1, sy1 = SLOT_B
    p.rect(sx0 - 8, sy0 - 8, sx1 + 8, sy1 + 8, BRASS, INK, 2.2, 3)
    p.rect(sx0, sy0, sx1, sy1, BLACK, INK, 1.6)
    if lit:
        p.rect(sx0 + 12, sy0 + 6, sx1 - 12, sy1 + 60, PAPER, INK, 2.0)
        p.line([(sx0 + 14, sy1 + 2), (sx1 - 14, sy1 + 2)], mix(PAPER, INK, 0.3), 1.4)
        p.line([(sx0 + 12, sy1 + 60), (sx0 + 30, sy1 + 57), (sx0 + 60, sy1 + 61), (sx0 + 100, sy1 + 58), (sx1 - 12, sy1 + 60)], INK, 1.6)
    # lamp socket
    lamp_socket(p, TERM_LAMP[0], TERM_LAMP[1], 12, lit=lit, dead=dark)
    # enamel field above the grille
    enamel_plate(p, 160, 756, 250, 768)


def rack_b(p, rng, cards=True):
    x0, y0, x1, y1 = 554, 740, 894, 910
    p.rect(x0, y0, x1, y1, TIMBER, INK, 3, 4)
    p.line([(x0 + 6, y0 + 6), (x1 - 6, y0 + 6)], TIMBER_HI, 1.6)
    for i in range(3):
        px0 = x0 + 18 + i * 108
        if cards:
            off = (-6, 4, -2)[i]
            p.rect(px0 + 8, y0 + 30 + off, px0 + 92, y0 + 90, PAPER, INK, 2, 1)
            p.ell(px0 + 50, y0 + 40 + off, 4, 4, mix(TIMBER_DK, BLACK, 0.3), INK, 1)
        p.rect(px0, y0 + 60, px0 + 100, y1 - 16, TIMBER_DK, INK, 2.4, 3)
        p.line([(px0 + 4, y0 + 64), (px0 + 96, y0 + 64)], TIMBER_HI, 1.4)
        p.rect(px0 + 24, y0 + 96, px0 + 76, y0 + 112, BRASS, INK, 1.6, 2)
    for x in (x0 + 12, x1 - 12):
        screw(p, x, y1 - 10, 3.4)


def copy_port(p, rng, open_=False):
    x0, y0, x1, y1 = 978, 740, 1178, 910
    cx, cy, r = 1078, 815, 34
    p.rect(x0, y0, x1, y1, IRON, INK, 3, 6)
    p.rect(x0 + 8, y0 + 8, x1 - 8, y1 - 8, mix(IRON, BULK, 0.5), INK, 1.6, 4)
    enamel_plate(p, x0 + 40, y0 + 18, x1 - 40, y0 + 34)
    p.ell(cx, cy, r + 10, r + 10, BRASS, INK, 2.6)
    p.arc(cx, cy, r + 7, r + 7, 200, 300, BRASS_HI, 1.6)
    # chain anchor at the lower right
    ax, ay = 1150, 860
    p.ell(ax, ay, 5, 5, BRASS_LO, INK, 1.4)
    if not open_:
        p.ell(cx, cy, r, r, BLACK, INK, 1.8)
        sh = p.layer()
        sh.ell(cx + 3, cy + 5, r + 4, r + 4, BLACK, None)
        p.put_soft(sh, 4, 0.4)
        p.ell(cx, cy, r + 4, r + 4, BRASS, INK, 2.4)
        p.ell(cx, cy, r - 6, r - 6, BRASS_LO, INK, 1.4)
        p.arc(cx, cy, r, r, 200, 290, BRASS_HI, 1.8)
        p.rect(cx - 10, cy - 3, cx + 10, cy + 3, BRASS_DK, INK, 1.2)
        chain(p, [(cx + r * 0.7, cy + r * 0.7), (cx + 46, cy + 52), (ax, ay)])
    else:
        p.ell(cx, cy, r, r, BLACK, INK, 2.0)
        p.ell(cx, cy, r - 8, r - 8, None, mix(BLACK, IRON, 0.35), 1.6)
        hx, hy = 1130, 870
        chain(p, [(ax, ay), (1150, 846), (hx + 6, hy - 22)])
        sh = p.layer()
        sh.ell(hx + 3, hy + 6, 32, 24, BLACK, None)
        p.put_soft(sh, 4, 0.4)
        # the cap hanging face-out, a little turned
        p.ell(hx, hy, 30, 24, BRASS, INK, 2.4)
        p.ell(hx, hy, 20, 15, BRASS_LO, INK, 1.4)
        p.arc(hx, hy, 27, 21, 200, 300, BRASS_HI, 1.6)
        p.rect(hx - 9, hy - 3, hx + 9, hy + 3, BRASS_DK, INK, 1.2)


def chain(p, pts):
    path = []
    for a, b in zip(pts, pts[1:]):
        for i in range(10):
            t = i / 10
            path.append((lerp(a[0], b[0], t), lerp(a[1], b[1], t) + 4 * math.sin(math.pi * t)))
    path.append(pts[-1])
    for i, (x, y) in enumerate(path):
        if i % 2 == 0:
            p.ell(x, y, 3.2, 2.2, BRASS_LO, INK, 1.0)
        else:
            p.ell(x, y, 1.8, 3.0, BRASS, INK, 1.0)


def name_plate(p, rng):
    x0, y0, x1, y1 = 474, 250, 974, 316
    p.rect(x0, y0, x1, y1, BRASS, INK, 3, 2)
    # fresh-cut edges: bright, unweathered metal at the bevel
    p.rect(x0 + 3, y0 + 3, x1 - 3, y0 + 7, BARE, None)
    p.rect(x0 + 3, y0 + 3, x0 + 7, y1 - 3, BARE, None)
    p.line([(x0 + 3, y1 - 4), (x1 - 4, y1 - 4), (x1 - 4, y0 + 3)], BARE, 2)
    p.rect(x0, y0, x1, y1, None, INK, 3, 2)
    for x in (x0 + 14, x1 - 14):
        screw(p, x, (y0 + y1) / 2, 4.2, BARE)
    # filings: a bright scatter on the frame below and stuck to the wall
    fr = random.Random(SEED + 777)
    for _ in range(90):
        x = fr.gauss(724, 90)
        if not (560 < x < 888):
            continue
        y = 328 - abs(fr.gauss(0, 2.2))
        L = fr.uniform(2, 5)
        a = fr.uniform(0, math.pi)
        p.line([(x, y), (x + L * math.cos(a), y - L * math.sin(a) * 0.4)], BARE if fr.random() < 0.6 else BRASS_HI, 1.2)
    for _ in range(40):
        x = fr.gauss(724, 110)
        y = fr.uniform(318, 326)
        p.ell(x, y, 0.9, 0.9, BARE, None)


def paint_view_b(rng, state=()):
    p = Pen(W, H, rng, BULK)
    bulkhead(p, rng, -4, -4, W + 4, 930, [362, 1086])
    p.rect(-4, -4, W + 4, 30, mix(STORM, BULK, 0.4), INK, 2.6)
    for x in range(60, W, 120):
        rivet(p, x, 15, 2.8)
    lay = p.layer()
    lay.ell(724, 520, 700, 420, BULK_HI, None)
    p.put_soft(lay, 140, 0.4)
    floor_band(p, rng, 930)
    # the console shelf the three units stand on
    p.rect(110, 910, 1198, 932, IRON, INK, 2.6, 2)
    p.line([(114, 914), (1194, 914)], IRON_HI, 1.4)
    for x in (150, 660, 1160):
        p.poly([(x - 10, 932), (x + 10, 932), (x + 4, 960), (x - 4, 960)], IRON_LO, INK, 2)
    # staff indicator rail
    p.rect(150, 104, 1300, 112, BRASS_LO, INK, 2, 2)
    for i, (cx, cy) in enumerate(LAMPS_B):
        p.line([(cx, 112), (cx, 120)], INK, 2)
        if "dark" in state:
            shutter(p, cx, cy, 40, mode="open")
        elif "turned" in state:
            shutter(p, cx, cy, 40, ang=TURN_ANG[i], mode="turned", slack=SLACK_ANG[i])
        else:
            shutter(p, cx, cy, 40)
        enamel_plate(p, 159 + 146 * i, 206, 269 + 146 * i, 232)
    name_plate(p, rng)
    for fx, image in zip(FRAMES_B, ("body", "place", "name")):
        frame_b(p, rng, fx, deep=("filled" in state), image=image)
    terminal_b(p, rng, lit=("lit" in state), dark=("dark" in state))
    rack_b(p, rng)
    copy_port(p, rng, open_=("uncapped" in state))
    # cable from the terminal up into the indicator rail
    p.rect(470, 800, 554, 812, IRON, INK, 2)
    p.rect(110, 120, 122, 740, IRON, INK, 2)
    p.line([(112, 124), (112, 738)], IRON_HI, 1.2)
    return p


def view_b_final(state=()):
    return grain(paint_view_b(rng_for(100), state).done(), rng_for(1100))


def b_overlay(state, extra=None):
    return lambda rng: diff_overlay(view_b_final(), view_b_final(state), extra)


def dark_extra():
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    for cx, cy in LAMPS_B:
        d.ellipse((cx - 44, cy - 44, cx + 44, cy + 44), fill=255)
    d.ellipse((TERM_LAMP[0] - 46, TERM_LAMP[1] - 46, TERM_LAMP[0] + 46, TERM_LAMP[1] + 46), fill=255)
    return m


# ============================================================================ VIEW C: the routing wall
STUDS_C = ((550, 820), (720, 820))
RECESS_C = (840, 770, 1080, 830)   # 240x60 centred on (960,800)
LAMPS_C = ((600, 760), (1150, 790))
LEVER_PIVOT = (1315, 730)


def roller_shutter(p, x0, y0, x1, y1):
    p.rect(x0 - 6, y0 - 22, x1 + 6, y0 + 4, BRASS_LO, INK, 2.6, 4)
    p.line([(x0, y0 - 16), (x1, y0 - 16)], BRASS_HI, 1.4)
    box = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    m = poly_mask((W, H), box)
    # tarnish: bright brass at the head where hands have rubbed it, going to verdigris at the foot
    p.vgrad(x0, y0, x1, y1, mix(BRASS, BRASS_HI, 0.2), mix(BRASS_DK, VERD, 0.55), mask=m)
    y = y0 + 4
    while y < y1 - 4:
        # each slat: a bevelled face, an ink seam, a shadow cast on the slat below
        sh = p.layer()
        sh.rect(x0, y + 14, x1, y + 19, BLACK, None)
        p.put(sh, 0.28, mask=m)
        p.line([(x0 + 2, y + 13), (x1 - 2, y + 13)], INK, 2.0)
        p.line([(x0 + 2, y + 3), (x1 - 2, y + 3)], mix(mix(BRASS_HI, PAPER, 0.15), VERD, 0.6 * (y - y0) / (y1 - y0)), 1.4)
        y += 16
    streaks = p.layer()
    r = random.Random(SEED + int(x0) * 7 + int(y0))
    for _ in range(int((x1 - x0) / 40)):
        x = r.uniform(x0 + 8, x1 - 14)
        yy = r.uniform(y0 + 40, y1 - 120)
        streaks.rect(x, yy, x + r.uniform(3, 7), yy + r.uniform(60, 160), mix(VERD, SEAGLASS, 0.3), None, r=2)
    p.put_soft(streaks, 1.2, 0.45, mask=m)
    p.rect(x0, y0, x1, y1, None, INK, 2.6)
    p.rect(x0 - 2, y1 - 14, x1 + 2, y1 + 2, BRASS, INK, 2.4, 2)
    p.line([(x0 + 2, y1 - 11), (x1 - 2, y1 - 11)], BRASS_HI, 1.4)
    for gx in (x0 + 2, x1 - 10):
        p.rect(gx - 4, y0, gx + 8, y1, IRON, INK, 1.8)
        p.line([(gx - 1, y0 + 2), (gx - 1, y1 - 2)], IRON_HI, 1.2)
    # padlock through the bottom rail: a shackle with a highlight, a body with a shadow under it
    cx = (x0 + x1) / 2
    sh = p.layer()
    sh.rect(cx - 18, y1 + 12, cx + 24, y1 + 46, BLACK, None, r=5)
    p.put_soft(sh, 3, 0.4)
    p.arc(cx, y1 + 6, 13, 15, 180, 360, INK, 7)
    p.arc(cx, y1 + 6, 13, 15, 180, 360, IRON_HI, 3)
    p.rect(cx - 20, y1 + 6, cx + 20, y1 + 40, mix(BRASS_LO, SOOT, 0.45), INK, 2.4, 4)
    p.line([(cx - 16, y1 + 10), (cx + 16, y1 + 10)], mix(BRASS, PAPER, 0.1), 1.4)
    p.rect(cx + 12, y1 + 10, cx + 17, y1 + 37, mix(SOOT, BLACK, 0.4), None, r=2)
    p.ell(cx, y1 + 20, 3.2, 3.2, BLACK, None)
    p.line([(cx, y1 + 20), (cx, y1 + 30)], BLACK, 2.4)


def yoke_shape(p, x0, ytop, span=230, depth=72, bar=16):
    """A U yoke opening downward: bar on top, two legs ending in contact shoes."""
    xa, xb = x0, x0 + span
    # legs
    for x in (xa, xb):
        p.rect(x - 9, ytop + bar / 2, x + 9, ytop + depth, BRASS, INK, 2.4, 3)
        p.line([(x - 5, ytop + bar), (x - 5, ytop + depth - 4)], BRASS_HI, 1.4)
        p.rect(x - 15, ytop + depth - 6, x + 15, ytop + depth + 6, BRASS_LO, INK, 2.4, 3)
    p.rect(xa - 12, ytop - bar / 2, xb + 12, ytop + bar / 2, BRASS, INK, 2.6, 8)
    p.line([(xa - 6, ytop - bar / 2 + 3), (xb + 6, ytop - bar / 2 + 3)], BRASS_HI, 1.6)
    # black insulated grips on the bar
    for gx in (xa + span * 0.27, xb - span * 0.27):
        p.rect(gx - 30, ytop - bar / 2 - 5, gx + 30, ytop + bar / 2 + 5, SOOT, INK, 2.4, 7)
        for k in range(-24, 25, 8):
            p.line([(gx + k, ytop - bar / 2 - 3), (gx + k, ytop + bar / 2 + 3)], BLACK, 1.4)
        p.line([(gx - 26, ytop - bar / 2 - 2), (gx + 26, ytop - bar / 2 - 2)], mix(SOOT, PAPER, 0.25), 1.2)


def lever(p, pulled):
    px, py = LEVER_PIVOT
    if not pulled:
        tip = (px, 586)
    else:
        tip = (px, 876)
    p.rect(px - 6, min(py, tip[1]), px + 6, max(py, tip[1]), BRASS_LO, INK, 2.2)
    p.line([(px - 2, min(py, tip[1]) + 4), (px - 2, max(py, tip[1]) - 4)], BRASS_HI, 1.2)
    # black grip crossbar
    p.rect(px - 40, tip[1] - 10, px + 40, tip[1] + 10, SOOT, INK, 2.6, 9)
    p.line([(px - 32, tip[1] - 5), (px + 32, tip[1] - 5)], mix(SOOT, PAPER, 0.3), 1.4)
    p.ell(px, py, 14, 14, BRASS, INK, 2.4)
    p.ell(px, py, 5, 5, BRASS_DK, INK, 1.2)


def handle_housing(p, pulled):
    x0, y0, x1, y1 = 1240, 560, 1390, 900
    p.rect(x0, y0, x1, y1, IRON, INK, 3, 6)
    p.rect(x0 + 8, y0 + 8, x1 - 8, y1 - 8, mix(IRON, BULK, 0.4), INK, 1.6, 4)
    p.rect(x0 + 10, y0 + 10, x1 - 10, y0 + 12, IRON_HI, None)
    for (sx, sy) in ((x0 + 16, y0 + 16), (x1 - 16, y0 + 16), (x0 + 16, y1 - 16), (x1 - 16, y1 - 16)):
        screw(p, sx, sy, 3.6)
    # travel slot
    p.rect(1305, 576, 1325, 886, BLACK, INK, 2, 6)
    # lock tongue: a brass bolt across the slot above the pivot; withdrawn into its keeper when pulled
    p.rect(1336, 664, 1380, 692, BRASS_LO, INK, 2.2, 3)   # keeper
    if not pulled:
        p.rect(1296, 670, 1350, 686, BRASS, INK, 2.2, 2)
        p.line([(1300, 673), (1346, 673)], BRASS_HI, 1.2)
    else:
        p.rect(1342, 670, 1378, 686, BRASS_DK, INK, 1.8, 2)
        p.rect(1326, 670, 1340, 686, mix(IRON, BULK, 0.4), None)
    lever(p, pulled)


def plate_c(p, rng, x0, y0, w=540, h=400):
    x1, y1 = x0 + w, y0 + h
    sh = p.layer()
    sh.rect(x0 + 8, y0 + 10, x1 + 8, y1 + 12, BLACK, None)
    p.put_soft(sh, 8, 0.35)
    p.rect(x0, y0, x1, y1, BRASS, INK, 3, 4)
    p.line([(x0 + 4, y1 - 4), (x0 + 4, y0 + 4), (x1 - 4, y0 + 4)], BRASS_HI, 2)
    p.line([(x0 + 5, y1 - 4), (x1 - 4, y1 - 4), (x1 - 4, y0 + 5)], BRASS_DK, 2)
    lay = p.layer()
    for _ in range(10):
        x = rng.uniform(x0 + 14, x1 - 20)
        lay.rect(x, rng.uniform(y0 + 20, y1 - 80), x + rng.uniform(4, 9), y1 - 10, VERD, None, r=3)
    p.put_soft(lay, 3, 0.35, mask=poly_mask((W, H), [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]))
    # schematic panel 480x250
    enamel_plate(p, x0 + 30, y0 + 30, x0 + 30 + 480, y0 + 30 + 250)
    # PREVIEW key: round brass push-key at the bottom centre
    kx, ky = x0 + w / 2, y0 + 340
    p.ell(kx, ky, 34, 34, BRASS_LO, INK, 2.6)
    p.ell(kx, ky, 24, 24, BRASS, INK, 2.2)
    p.arc(kx, ky, 20, 20, 200, 290, BRASS_HI, 2)
    p.ell(kx, ky, 8, 8, BRASS_DK, None)
    for (sx, sy) in ((x0 + 14, y0 + 14), (x1 - 14, y0 + 14), (x0 + 14, y1 - 14), (x1 - 14, y1 - 14)):
        screw(p, sx, sy, 4)


def card_holder(p, rng):
    x0, y0, x1, y1 = 474, 540, 974, 690
    p.rect(x0, y0, x1, y1, BRASS, INK, 3, 4)
    p.line([(x0 + 4, y1 - 4), (x0 + 4, y0 + 4), (x1 - 4, y0 + 4)], BRASS_HI, 2)
    for i in range(4):
        sx = x0 + 22 + i * 120
        p.rect(sx, y0 + 26, sx + 96, y1 - 26, mix(BRASS_DK, BLACK, 0.35), INK, 2.2, 2)
        p.rect(sx - 4, y0 + 20, sx + 100, y0 + 30, BRASS_HI, INK, 1.8, 2)
        p.line([(sx + 4, y0 + 36), (sx + 92, y0 + 36)], BLACK, 3)


def feed_contacts(p, rng):
    x0, y0, x1, y1 = 470, 740, 800, 900
    p.rect(x0, y0, x1, y1, SLATE, INK, 3, 4)
    p.line([(x0 + 6, y0 + 6), (x1 - 6, y0 + 6)], SLATE_HI, 1.6)
    lay = p.layer()
    for _ in range(14):
        lay.line([(rng.uniform(x0, x1), rng.uniform(y0, y1)), (rng.uniform(x0, x1), rng.uniform(y0, y1))], SLATE_HI, 1)
    p.put(lay, 0.25, mask=poly_mask((W, H), [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]))
    for (cx, cy) in STUDS_C:
        p.ell(cx, cy, 40, 40, mix(SLATE, BLACK, 0.3), None)
        p.ell(cx, cy, 34, 34, BRASS, INK, 2.8)
        p.ell(cx, cy, 24, 24, BRASS_LO, INK, 1.8)
        p.arc(cx, cy, 30, 30, 200, 300, BRASS_HI, 2)
        p.ell(cx, cy, 9, 9, BRASS_HI, INK, 1.4)
        enamel_plate(p, cx - 40, 868, cx + 40, 886)
    lamp_socket(p, LAMPS_C[0][0], LAMPS_C[0][1], 10)
    for (sx, sy) in ((x0 + 12, y0 + 12), (x1 - 12, y0 + 12), (x0 + 12, y1 - 12), (x1 - 12, y1 - 12)):
        screw(p, sx, sy, 3.2)


def ada_terminal_c(p, rng, bridge=False):
    x0, y0, x1, y1 = 830, 740, 1210, 900
    p.rect(x0, y0, x1, y1, IRON, INK, 3, 6)
    p.rect(x0 + 8, y0 + 8, x1 - 8, y1 - 8, mix(IRON, BULK, 0.45), INK, 1.6, 4)
    p.line([(x0 + 10, y0 + 11), (x1 - 10, y0 + 11)], IRON_HI, 1.4)
    rx0, ry0, rx1, ry1 = RECESS_C
    # the recess has the bridge's outline: a bar slot and two prong holes
    p.rect(rx0 - 6, ry0 - 6, rx1 + 6, ry1 + 6, BRASS_LO, INK, 2.4, 4)
    p.rect(rx0, ry0, rx1, ry0 + 26, BLACK, INK, 1.8, 3)
    for px in (rx0 + 48, rx1 - 48):
        p.rect(px - 9, ry0 + 26, px + 9, ry1, BLACK, INK, 1.8, 2)
    p.rect(rx0 + 2, ry0 + 2, rx1 - 2, ry0 + 6, mix(IRON, BLACK, 0.6), None)
    lamp_socket(p, LAMPS_C[1][0], LAMPS_C[1][1], 10, lit=bridge)
    enamel_plate(p, 1110, 830, 1190, 846)
    for (sx, sy) in ((x0 + 16, y0 + 16), (x1 - 16, y0 + 16), (x0 + 16, y1 - 16), (x1 - 16, y1 - 16)):
        screw(p, sx, sy, 3.4)
    if bridge:
        sh = p.layer()
        sh.rect(rx0 + 6, ry0 + 4, rx1 + 6, ry1 + 6, BLACK, None)
        p.put_soft(sh, 4, 0.4)
        bridge_shape(p, (rx0 + rx1) / 2, ry0 - 4, inset=True)


def bridge_shape(p, cx, top, inset=False):
    """The witness bridge: a brass bar, two downward prongs, a small blank cream enamel plate."""
    bw, bh = 236, 30
    x0, x1 = cx - bw / 2, cx + bw / 2
    for px in (x0 + 48, x1 - 48):
        p.rect(px - 8, top + bh - 4, px + 8, top + (60 if inset else 96), BRASS_LO, INK, 2.2, 2)
        p.line([(px - 4, top + bh), (px - 4, top + (56 if inset else 90))], BRASS_HI, 1.2)
        if not inset:
            p.poly([(px - 8, top + 96), (px + 8, top + 96), (px, top + 106)], BRASS_LO, INK, 2)
    p.rect(x0, top, x1, top + bh, BRASS, INK, 2.6, 5)
    p.line([(x0 + 6, top + 4), (x1 - 6, top + 4)], BRASS_HI, 1.6)
    p.line([(x0 + 6, top + bh - 4), (x1 - 6, top + bh - 4)], BRASS_DK, 1.4)
    p.rect(cx - 44, top + 6, cx + 44, top + bh - 6, (232, 222, 196), INK, 1.6, 2)
    for sx in (x0 + 14, x1 - 14):
        screw(p, sx, top + bh / 2, 3.4, BRASS_LO)


def yoke_tray(p, rng, empty=False):
    x0, y0, x1, y1 = 110, 740, 440, 900
    p.rect(x0, y0, x1, y1, BRASS_LO, INK, 3, 6)
    p.rect(x0 + 12, y0 + 12, x1 - 12, y1 - 12, FELT, INK, 2, 4)
    lay = p.layer()
    for _ in range(300):
        x, y = rng.uniform(x0 + 14, x1 - 14), rng.uniform(y0 + 14, y1 - 14)
        lay.line([(x, y), (x + rng.uniform(-3, 3), y + rng.uniform(-3, 3))], FELT_DK, 1)
    p.put(lay, 0.6)
    # the yoke's shape is pressed into the felt
    p.rect(150, 772, 400, 794, FELT_DK, None, r=8)
    for x in (165, 385):
        p.rect(x - 11, 780, x + 11, 860, FELT_DK, None, r=4)
    p.line([(x0 + 14, y0 + 16), (x1 - 14, y0 + 16)], BLACK, 2)
    if not empty:
        sh = p.layer()
        sh.rect(150, 776, 404, 800, BLACK, None, r=8)
        for x in (165, 385):
            sh.rect(x - 9, 790, x + 13, 866, BLACK, None)
        p.put_soft(sh, 4, 0.45)
        yoke_shape(p, 165, 782, span=220, depth=72)


def paint_view_c(rng, state=()):
    p = Pen(W, H, rng, BULK)
    bulkhead(p, rng, -4, -4, W + 4, 920, [362, 1086])
    p.rect(-4, -4, W + 4, 30, mix(STORM, BULK, 0.4), INK, 2.6)
    for x in range(60, W, 120):
        rivet(p, x, 15, 2.8)
    lay = p.layer()
    lay.ell(724, 520, 700, 420, BULK_HI, None)
    p.put_soft(lay, 140, 0.4)
    floor_band(p, rng, 920)
    p.rect(96, 900, 1220, 922, IRON, INK, 2.6, 2)
    p.line([(100, 904), (1216, 904)], IRON_HI, 1.4)
    plate_c(p, rng, 110, 110)
    plate_c(p, rng, 798, 110)
    card_holder(p, rng)
    handle_housing(p, pulled=("pulled" in state))
    yoke_tray(p, rng, empty=("tray_empty" in state))
    feed_contacts(p, rng)
    ada_terminal_c(p, rng, bridge=("bridge" in state))
    if "lamps" in state:
        for (cx, cy) in LAMPS_C:
            lamp_socket(p, cx, cy, 10, lit=True)
    if "yoke" in state:
        sh = p.layer()
        sh.rect(STUDS_C[0][0] - 16, 734, STUDS_C[1][0] + 20, 750, BLACK, None, r=8)
        for x in (STUDS_C[0][0], STUDS_C[1][0]):
            sh.rect(x - 6, 740, x + 14, 826, BLACK, None)
        p.put_soft(sh, 5, 0.4)
        lamp_socket(p, LAMPS_C[0][0], LAMPS_C[0][1], 10, lit=("lamps" in state))
        yoke_shape(p, STUDS_C[0][0], 728, span=STUDS_C[1][0] - STUDS_C[0][0], depth=92)
    if "shutters" in state:
        roller_shutter(p, 110, 110, 650, 510)
        roller_shutter(p, 798, 110, 1338, 510)
        roller_shutter(p, 474, 540, 974, 690)
    return p


def view_c_final(state=()):
    return grain(paint_view_c(rng_for(200), state).done(), rng_for(1200))


def c_overlay(state):
    return lambda rng: diff_overlay(view_c_final(), view_c_final(state))


# ============================================================================ close-up P25: c_frames
def closeup_ground(p, rng):
    p.rect(-4, -4, W + 4, H + 4, BULK, None)
    lay = p.layer()
    for _ in range(40):
        lay.ell(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(80, 220), rng.uniform(40, 120),
                BULK_DK if rng.random() < 0.6 else BULK_HI, None)
    p.put_soft(lay, 40, 0.35)
    for x in (60, 1400):
        for y in range(40, H, 120):
            rivet(p, x, y)


def big_frame(p, rng, fx, back=False):
    x0, y0, x1, y1 = fx, 110, fx + 340, 530
    sh = p.layer()
    sh.rect(x0 + 10, y0 + 12, x1 + 10, y1 + 14, BLACK, None)
    p.put_soft(sh, 10, 0.4)
    p.rect(x0, y0, x1, y1, BRASS, INK, 3.2, 5)
    p.rect(x0 + 12, y0 + 12, x1 - 12, y1 - 12, BRASS_LO, INK, 2, 3)
    p.line([(x0 + 5, y1 - 5), (x0 + 5, y0 + 5), (x1 - 5, y0 + 5)], BRASS_HI, 2.4)
    lay = p.layer()
    for _ in range(10):
        x = rng.uniform(x0 + 16, x1 - 20)
        lay.rect(x, rng.uniform(y0 + 20, y1 - 100), x + rng.uniform(5, 10), y1 - 16, VERD, None, r=3)
    p.put_soft(lay, 3, 0.35, mask=poly_mask((W, H), [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]))
    wx0, wy0, wx1, wy1 = fx + 20, 200, fx + 320, 400
    p.rect(wx0 - 10, wy0 - 10, wx1 + 10, wy1 + 10, BRASS_DK, INK, 2.6, 2)
    back_col = mix(BULK_DK, BLACK, 0.5) if back else mix(BULK_DK, BLACK, 0.15)
    p.rect(wx0, wy0, wx1, wy1, back_col, INK, 2.4)
    d = 30 if back else 14
    shade = p.layer()
    shade.poly([(wx0, wy0), (wx1, wy0), (wx1 - d, wy0 + d), (wx0 + d, wy0 + d), (wx0 + d, wy1 - d), (wx0, wy1)], BLACK, None)
    p.put(shade, 0.5)
    p.line([(wx0 + d, wy0 + d), (wx1 - d, wy0 + d), (wx1 - d, wy1 - d), (wx0 + d, wy1 - d), (wx0 + d, wy0 + d)],
           mix(back_col, BULK_HI, 0.5), 1.4)
    if back:
        shd = p.layer()
        shd.rect(wx0, wy0, wx1, wy0 + 60, BLACK, None)
        p.put_soft(shd, 14, 0.4, mask=poly_mask((W, H), [(wx0, wy0), (wx1, wy0), (wx1, wy1), (wx0, wy1)]))
    for cx in (fx + 110, fx + 230):
        p.rect(cx - 12, wy0 - 16, cx + 12, wy0 + 14, BRASS_HI, INK, 2, 3)
        p.line([(cx - 7, wy0 + 6), (cx + 7, wy0 + 6)], BRASS_DK, 1.6)
        p.rect(cx - 12, wy1 - 14, cx + 12, wy1 + 16, BRASS_HI, INK, 2, 3)
        p.line([(cx - 7, wy1 - 6), (cx + 7, wy1 - 6)], BRASS_DK, 1.6)
    for (sx, sy) in ((x0 + 22, y0 + 22), (x1 - 22, y0 + 22), (x0 + 22, y1 - 22), (x1 - 22, y1 - 22)):
        screw(p, sx, sy, 5)
    # the category plate hangs below on two short links
    for lx in (fx + 70, fx + 270):
        p.rect(lx - 3, y1 - 4, lx + 3, 544, BRASS_LO, INK, 1.4)
    enamel_plate(p, fx + 40, 540, fx + 300, 604)


def right_column(p, state):
    """Strip window, switch housing, ROUTE keyhole."""
    x0 = 1110
    p.rect(x0 - 14, 586, x0 + 314, 984, IRON, INK, 3, 6)
    p.rect(x0 - 6, 594, x0 + 306, 976, mix(IRON, BULK, 0.4), INK, 1.6, 4)
    # strip window 300x80 at (1110,600) with its lamp socket at (1380,620)
    p.rect(x0, 600, x0 + 300, 680, BRASS, INK, 2.6, 3)
    p.rect(x0 + 12, 612, x0 + 248, 668, mix(PAPER, BULK_DK, 0.55), INK, 2)
    p.line([(x0 + 14, 616), (x0 + 246, 616)], BLACK, 3)
    lit = "lit" in state
    if lit:
        g = p.layer()
        g.rect(x0 - 10, 590, x0 + 310, 690, AMBER_HI, None, r=12)
        p.put_soft(g, 16, 0.45)
        p.rect(x0, 600, x0 + 300, 680, BRASS, INK, 2.6, 3)
        p.rect(x0 + 12, 612, x0 + 248, 668, mix(PAPER, AMBER_HI, 0.35), INK, 2)
        p.line([(x0 + 14, 616), (x0 + 246, 616)], mix(AMBER, INK, 0.4), 2)
    lamp_socket(p, 1380, 620, 11, lit=lit)
    # switch housing 300x120 with a hinged guard raised at the top
    p.rect(x0, 700, x0 + 300, 820, IRON_LO, INK, 2.6, 4)
    p.rect(x0 + 8, 708, x0 + 292, 812, BLACK, INK, 1.6, 3)
    p.rect(x0 + 10, 690, x0 + 290, 704, BRASS_LO, INK, 2.2, 3)
    for hx in (x0 + 40, x0 + 260):
        p.ell(hx, 697, 6, 6, BRASS, INK, 1.6)
    # ROUTE keyhole plate 300x130
    p.rect(x0, 840, x0 + 300, 970, BRASS, INK, 2.8, 4)
    p.line([(x0 + 4, 966), (x0 + 4, 844), (x0 + 296, 844)], BRASS_HI, 2)
    p.ell(x0 + 150, 905, 40, 40, BRASS_LO, INK, 2.4)
    p.ell(x0 + 150, 898, 10, 10, BLACK, None)
    p.poly([(x0 + 144, 900), (x0 + 156, 900), (x0 + 160, 926), (x0 + 140, 926)], BLACK, None)
    for (sx, sy) in ((x0 + 14, 854), (x0 + 286, 854), (x0 + 14, 956), (x0 + 286, 956)):
        screw(p, sx, sy, 4)


def paint_c_frames(rng, state=()):
    p = Pen(W, H, rng)
    closeup_ground(p, rng)
    right_column(p, state)
    for fx in (140, 554, 968):
        big_frame(p, rng, fx, back=("back" in state))
    # rack pockets
    p.rect(90, 640, 1070, 880, TIMBER, INK, 3, 5)
    p.line([(96, 646), (1064, 646)], TIMBER_HI, 1.8)
    for px in (110, 430, 750):
        p.rect(px, 660, px + 300, 860, TIMBER_DK, INK, 2.6, 4)
        # felt lining, as in the yoke tray
        p.rect(px + 10, 672, px + 290, 850, FELT, INK, 1.8, 3)
        lay = p.layer()
        for _ in range(160):
            x, y = rng.uniform(px + 12, px + 288), rng.uniform(676, 846)
            lay.line([(x, y), (x + rng.uniform(-3, 3), y + rng.uniform(-3, 3))], FELT_DK, 1)
        p.put(lay, 0.6)
        p.rect(px + 10, 672, px + 290, 684, mix(FELT_DK, BLACK, 0.4), None)
        p.line([(px + 4, 664), (px + 296, 664)], TIMBER_HI, 1.4)
    for x in (100, 1060):
        screw(p, x, 860, 4)
    return p


def c_frames_final(state=()):
    return grain(paint_c_frames(rng_for(300), state).done(), rng_for(1300))


def paint_card(rng, w=300, h=200, hole=True):
    p = Pen(w, h, rng)
    p.rect(2, 2, w - 2, h - 2, PAPER, INK, 2.4, 3)
    p.rect(10, 10, w - 10, h - 10, None, mix(PAPER, INK, 0.45), 1.4, 1)
    p.line([(4, h - 5), (w - 5, h - 5), (w - 5, 4)], PAPER_LO, 1.6)
    lay = p.layer()
    for _ in range(14):
        lay.ell(rng.uniform(10, w - 10), rng.uniform(10, h - 10), rng.uniform(6, 26), rng.uniform(4, 14), PAPER_LO, None)
    p.put_soft(lay, 10, 0.16, mask=poly_mask((w, h), [(4, 4), (w - 4, 4), (w - 4, h - 4), (4, h - 4)]))
    if hole:
        p.ell(w / 2, 22, 6, 6, (0, 0, 0, 0), INK, 1.6)
        p.d.ellipse(((w / 2 - 5) * SS, 17 * SS, (w / 2 + 5) * SS, 27 * SS), fill=(0, 0, 0, 0))
        p.ell(w / 2, 22, 6, 6, None, INK, 1.6)
    out = p.done()
    return grain(out, rng_for(5000 + w + h), amp=4, mottle=4, speck=8)


def paint_switch(rng, side):
    w, h = 300, 120
    p = Pen(w, h, rng)
    p.rect(2, 2, w - 2, h - 2, IRON, INK, 2.6, 5)
    p.rect(8, 8, w - 8, h - 8, mix(IRON, BULK, 0.35), INK, 1.4, 3)
    enamel_plate(p, 22, 22, 104, 44)
    enamel_plate(p, 196, 22, 278, 44)
    # the lever's quadrant
    p.arc(150, 98, 70, 70, 200, 340, BRASS_LO, 6)
    p.arc(150, 98, 70, 70, 200, 340, INK, 1.4)
    ang = -140 if side == "left" else -40
    tip = (150 + 76 * math.cos(math.radians(ang)), 98 + 76 * math.sin(math.radians(ang)))
    p.line([(150, 98), tip], INK, 12)
    p.line([(150, 98), tip], BRASS, 7.5)
    p.ell(tip[0], tip[1], 13, 13, SOOT, INK, 2.2)
    p.ell(tip[0] - 3, tip[1] - 4, 4, 3, mix(SOOT, PAPER, 0.35), None)
    p.ell(150, 98, 15, 15, BRASS, INK, 2.2)
    p.ell(150, 98, 5, 5, BRASS_DK, None)
    for x in (16, w - 16):
        screw(p, x, h - 16, 3.4)
    return p


def paint_route_key(rng, turned):
    w, h = 300, 130
    p = Pen(w, h, rng)
    p.rect(2, 2, w - 2, h - 2, BRASS, INK, 2.6, 4)
    p.line([(6, h - 6), (6, 6), (w - 6, 6)], BRASS_HI, 2)
    for (sx, sy) in ((14, 14), (w - 14, 14), (14, h - 14), (w - 14, h - 14)):
        screw(p, sx, sy, 4)
    cx, cy = 150, 65
    p.ell(cx, cy, 40, 40, BRASS_LO, INK, 2.4)
    p.ell(cx, cy, 12, 12, BLACK, None)
    # a stubby bow key: the bow is the part the hand turns
    ang = 0 if not turned else 90
    shaft = [rot(q, (cx, cy), ang) for q in [(cx - 5, cy - 8), (cx + 5, cy - 8), (cx + 5, cy - 46), (cx - 5, cy - 46)]]
    p.poly(shaft, BRASS_DK, INK, 2)
    bow_c = rot((cx, cy - 46), (cx, cy), ang)
    bw = (34, 18) if not turned else (18, 34)
    p.ell(bow_c[0], bow_c[1], bw[0], bw[1], BRASS, INK, 2.6)
    p.ell(bow_c[0], bow_c[1], bw[0] * 0.42, bw[1] * 0.42, BRASS_LO, INK, 1.6)
    p.arc(bow_c[0], bow_c[1], bw[0] - 3, bw[1] - 3, 200, 290, BRASS_HI, 1.6)
    p.ell(cx, cy, 14, 14, BRASS, INK, 2.2)
    p.ell(cx, cy, 5, 5, BRASS_DK, None)
    # an indicator notch on the escutcheon tells the turn without a word
    p.poly([(cx - 5, cy - 40), (cx + 5, cy - 40), (cx, cy - 32)], INK, None)
    p.poly([(cx + 40, cy - 5), (cx + 40, cy + 5), (cx + 32, cy)], INK, None)
    return p


# ============================================================================ close-up P26: c_routing
def paint_c_routing(rng, closed=False):
    p = Pen(W, H, rng)
    closeup_ground(p, rng)
    for x0 in (110, 798):
        sh = p.layer()
        sh.rect(x0 - 10, 90, x0 + 550, 760, BLACK, None)
        p.put_soft(sh, 12, 0.3)
        p.rect(x0 - 20, 80, x0 + 560, 760, BRASS, INK, 3.2, 6)
        p.line([(x0 - 15, 755), (x0 - 15, 85), (x0 + 555, 85)], BRASS_HI, 2.4)
        p.line([(x0 - 14, 755), (x0 + 555, 755), (x0 + 555, 86)], BRASS_DK, 2.4)
        lay = p.layer()
        for _ in range(14):
            x = rng.uniform(x0, x0 + 540)
            lay.rect(x, rng.uniform(100, 600), x + rng.uniform(5, 10), 750, VERD, None, r=3)
        p.put_soft(lay, 3, 0.3, mask=poly_mask((W, H), [(x0 - 20, 80), (x0 + 560, 80), (x0 + 560, 760), (x0 - 20, 760)]))
        enamel_plate(p, x0, 100, x0 + 540, 460)
    # PREVIEW keys: round key on an oblong mount
    for (kx, ky) in ((260, 470), (948, 470)):
        p.rect(kx, ky, kx + 240, ky + 90, BRASS_LO, INK, 2.6, 44)
        cx, cy = kx + 120, ky + 45
        p.ell(cx, cy, 36, 36, BRASS, INK, 2.6)
        p.arc(cx, cy, 31, 31, 200, 290, BRASS_HI, 2.2)
        p.ell(cx, cy, 12, 12, BRASS_DK, None)
        for sx in (kx + 26, kx + 214):
            screw(p, sx, cy, 4.4)
    # card slots with brass lips
    for (sx, sy) in ((140, 590), (888, 590)):
        p.rect(sx, sy, sx + 420, sy + 150, BRASS_DK, INK, 2.6, 4)
        p.rect(sx + 16, sy + 20, sx + 404, sy + 130, mix(BULK_DK, BLACK, 0.5), INK, 2)
        p.rect(sx + 8, sy + 8, sx + 412, sy + 24, BRASS_HI, INK, 2, 4)
        p.line([(sx + 20, sy + 32), (sx + 400, sy + 32)], BLACK, 4)
        if closed:
            sh = p.layer()
            sh.rect(sx + 4, sy + 6, sx + 424, sy + 160, BLACK, None)
            p.put_soft(sh, 6, 0.4)
            p.rect(sx, sy, sx + 420, sy + 150, BRASS, INK, 3, 4)
            for y in range(sy + 18, sy + 140, 22):
                p.line([(sx + 10, y), (sx + 410, y)], BRASS_LO, 2)
                p.line([(sx + 10, y + 3), (sx + 410, y + 3)], BRASS_HI, 1.2)
            for hx in (sx + 60, sx + 360):
                p.rect(hx - 18, sy - 6, hx + 18, sy + 8, BRASS_LO, INK, 2, 3)
            p.rect(sx + 180, sy + 128, sx + 240, sy + 148, BRASS_DK, INK, 2, 3)
    # CONFIRM button: big enamel push with a brass ring
    bx, by = 604, 590
    p.rect(bx, by, bx + 240, by + 150, IRON, INK, 2.8, 8)
    p.rect(bx + 8, by + 8, bx + 232, by + 142, mix(IRON, BULK, 0.4), INK, 1.4, 6)
    cx, cy = bx + 120, by + 75
    p.ell(cx, cy, 62, 62, BRASS, INK, 3)
    p.arc(cx, cy, 57, 57, 200, 290, BRASS_HI, 2.4)
    p.ell(cx, cy, 48, 48, ENAMEL, INK, 2.4)
    p.arc(cx, cy, 40, 40, 200, 270, PAPER_HI, 3)
    p.arc(cx, cy, 44, 44, 20, 110, ENAMEL_LO, 3)
    # the felt tray with four wells
    p.rect(40, 780, 1408, 960, BRASS_LO, INK, 3, 6)
    p.line([(46, 784), (1402, 784)], BRASS_HI, 1.8)
    for wx in (64, 394, 724, 1054):
        p.rect(wx, 790, wx + 310, 950, FELT, INK, 2.4, 6)
        p.line([(wx + 6, 796), (wx + 304, 796)], BLACK, 3)
        lay = p.layer()
        for _ in range(140):
            x, y = rng.uniform(wx + 6, wx + 304), rng.uniform(800, 944)
            lay.line([(x, y), (x + rng.uniform(-3, 3), y + rng.uniform(-3, 3))], FELT_DK, 1)
        p.put(lay, 0.6)
    return p


def c_routing_final(closed=False):
    return grain(paint_c_routing(rng_for(400), closed).done(), rng_for(1400))


def paint_lamp(rng, on):
    p = Pen(36, 36, rng)
    if on:
        lay = p.layer()
        lay.ell(18, 18, 14, 14, AMBER_HI, None)
        p.put_soft(lay, 3.5, 0.75)
        p.ell(18, 18, 10, 10, AMBER, INK, 1.6)
        p.ell(16.5, 16.5, 6.5, 6.5, AMBER_HI, None)
        p.ell(15, 14.5, 2.4, 2.0, (250, 238, 206), None)
    else:
        p.ell(18, 18, 10, 10, GLASS_DEAD, INK, 1.6)
        p.ell(18, 18, 6, 6, mix(GLASS_DEAD, IRON, 0.5), None)
        p.arc(18, 18, 7, 7, 200, 260, mix(GLASS_DEAD, PAPER, 0.4), 1.4)
    return p


# ============================================================================ close-up P27: c_final
def paint_c_final(rng):
    p = Pen(W, H, rng)
    closeup_ground(p, rng)
    # contacts plate with two big studs
    p.rect(100, 140, 540, 400, SLATE, INK, 3, 6)
    p.line([(106, 146), (534, 146)], SLATE_HI, 1.8)
    for (cx, cy) in ((220, 280), (420, 280)):
        p.ell(cx, cy, 58, 58, mix(SLATE, BLACK, 0.3), None)
        p.ell(cx, cy, 50, 50, BRASS, INK, 3)
        p.ell(cx, cy, 36, 36, BRASS_LO, INK, 2)
        p.arc(cx, cy, 44, 44, 200, 300, BRASS_HI, 2.4)
        p.ell(cx, cy, 13, 13, BRASS_HI, INK, 1.6)
        enamel_plate(p, cx - 60, 348, cx + 60, 376)
    for (sx, sy) in ((116, 156), (524, 156), (116, 384), (524, 384)):
        screw(p, sx, sy, 4)
    # lamp panel with ten dead sockets
    p.rect(560, 140, 888, 400, IRON, INK, 3, 6)
    p.rect(568, 148, 880, 392, mix(IRON, BULK, 0.4), INK, 1.4, 4)
    for i in range(4):
        for y in (200, 270):
            lamp_socket(p, 600 + 64 * i, y, 16, dead=True)
    p.line([(576, 316), (872, 316)], INK, 1.6)
    for x in (620, 820):
        lamp_socket(p, x, 350, 16, dead=True)
    # Ada's terminal with the bridge recess
    p.rect(908, 140, 1348, 400, IRON, INK, 3, 6)
    p.rect(916, 148, 1340, 392, mix(IRON, BULK, 0.45), INK, 1.4, 4)
    rx0, ry0, rx1, ry1 = 1008, 250, 1248, 310
    p.rect(rx0 - 8, ry0 - 8, rx1 + 8, ry1 + 8, BRASS_LO, INK, 2.6, 4)
    p.rect(rx0, ry0, rx1, ry0 + 28, BLACK, INK, 2, 3)
    for px in (rx0 + 48, rx1 - 48):
        p.rect(px - 10, ry0 + 28, px + 10, ry1, BLACK, INK, 2, 2)
    enamel_plate(p, 1008, 176, 1248, 206)
    for (sx, sy) in ((924, 156), (1332, 156), (924, 384), (1332, 384)):
        screw(p, sx, sy, 4)
    # yoke well
    p.rect(100, 440, 540, 610, BRASS_LO, INK, 3, 6)
    p.rect(114, 454, 526, 596, FELT, INK, 2, 4)
    p.rect(150, 488, 490, 512, FELT_DK, None, r=8)
    for x in (170, 470):
        p.rect(x - 12, 496, x + 12, 584, FELT_DK, None, r=4)
    # PREVIEW key
    p.rect(604, 460, 844, 580, BRASS_LO, INK, 2.8, 20)
    p.ell(724, 520, 42, 42, BRASS, INK, 2.8)
    p.arc(724, 520, 36, 36, 200, 290, BRASS_HI, 2.2)
    p.ell(724, 520, 14, 14, BRASS_DK, None)
    # handle housing, horizontal, the lever seen end-on in its slot
    p.rect(908, 440, 1348, 610, IRON, INK, 3, 6)
    p.rect(916, 448, 1340, 602, mix(IRON, BULK, 0.4), INK, 1.4, 4)
    p.rect(940, 515, 1316, 537, BLACK, INK, 2, 8)
    p.ell(1128, 526, 22, 22, BRASS, INK, 2.4)
    p.ell(1128, 526, 8, 8, BRASS_DK, None)
    # two big enamel button plates with brass guard rails
    for x0 in (100, 748):
        p.rect(x0, 700, x0 + 600, 900, BRASS, INK, 3, 6)
        p.line([(x0 + 5, 895), (x0 + 5, 705), (x0 + 595, 705)], BRASS_HI, 2.2)
        p.rect(x0 + 30, 730, x0 + 570, 870, ENAMEL, INK, 2.4, 10)
        p.line([(x0 + 40, 862), (x0 + 560, 862)], ENAMEL_LO, 3)
        # guard rails: a brass hoop standing proud of each plate
        for gy in (716, 884):
            p.rect(x0 + 14, gy - 5, x0 + 586, gy + 5, BRASS_HI, INK, 2, 5)
        for gx in (x0 + 14, x0 + 586):
            p.rect(gx - 8, 708, gx + 8, 892, BRASS_LO, INK, 2.2, 4)
    return p


def paint_yoke(rng):
    p = Pen(420, 140, rng)
    yoke_shape(p, 60, 30, span=300, depth=94, bar=22)
    return p


def paint_bridge(rng):
    p = Pen(240, 110, rng)
    bridge_shape(p, 120, 2)
    return p


# ============================================================================ the ending frame
# Each instrument tableau is a flat front-elevation fragment of the room it names, on that
# room's own wall, in a brass record frame on a storm-navy paper field (no oval, no black).
# The fragments were drawn on a 900 x 640 sheet; they are shown 1.4x larger through a
# 1288 x 760 window at M_AT, so the sheet's (450, 330) lands at the window's centre.
M_AT = (80, 40)
M_SIZE = (1288, 760)
M_SCALE = 1.4
M_ORIGIN = (450 - M_SIZE[0] / 2 / M_SCALE, 330 - M_SIZE[1] / 2 / M_SCALE)
FIELD = (60, 76, 86)                      # storm-navy paper, ~72


def paint_end_card(rng):
    p = Pen(W, H, rng, FIELD)
    lay = p.layer()
    for _ in range(30):
        lay.ell(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(100, 300), rng.uniform(60, 160),
                mix(FIELD, BULK_HI, 0.6) if rng.random() < 0.5 else mix(FIELD, STORM, 0.5), None)
    p.put_soft(lay, 60, 0.45)
    x0, y0 = M_AT
    x1, y1 = x0 + M_SIZE[0], y0 + M_SIZE[1]
    sh = p.layer()
    sh.rect(x0 - 12, y0 - 6, x1 + 22, y1 + 26, BLACK, None, r=6)
    p.put_soft(sh, 12, 0.4)
    p.rect(x0 - 20, y0 - 20, x1 + 20, y1 + 20, BRASS, INK, 3.2, 5)
    p.rect(x0 - 9, y0 - 9, x1 + 9, y1 + 9, BRASS_LO, INK, 2.2, 2)
    p.line([(x0 - 15, y1 + 15), (x0 - 15, y0 - 15), (x1 + 15, y0 - 15)], BRASS_HI, 2.2)
    p.line([(x0 - 14, y1 + 15), (x1 + 15, y1 + 15), (x1 + 15, y0 - 14)], BRASS_DK, 2.2)
    p.rect(x0, y0, x1, y1, FIELD, INK, 2.6)
    for (sx, sy) in ((x0 - 12, y0 - 12), (x1 + 12, y0 - 12), (x0 - 12, y1 + 12), (x1 + 12, y1 + 12)):
        screw(p, sx, sy, 4.4, BRASS_LO)
    for lx in (620, 828):
        p.rect(lx - 3, y1 + 20, lx + 3, 834, BRASS_LO, INK, 1.4)
    brass_plate(p, 514, 830, 934, 878)
    return p


def sprite_pen(rng):
    return Pen(M_SIZE[0], M_SIZE[1], rng, None, M_SCALE, M_ORIGIN)


def panelled_wall(p, rng, upper, rail_y, lower=None, tiles=False, planks=False):
    """A room's wall behind its instrument: matte upper wall, a rail, panelled wainscot below."""
    x0, x1, y0, y1 = M_ORIGIN[0] - 4, M_ORIGIN[0] + M_SIZE[0] / M_SCALE + 4, M_ORIGIN[1] - 4, M_ORIGIN[1] + M_SIZE[1] / M_SCALE + 4
    p.rect(x0, y0, x1, y1, upper, None)
    lay = p.layer()
    for _ in range(14):
        lay.ell(rng.uniform(x0, x1), rng.uniform(y0, rail_y), rng.uniform(60, 180), rng.uniform(30, 90),
                mix(upper, PAPER_HI, 0.35) if rng.random() < 0.5 else mix(upper, INK, 0.2), None)
    p.put_soft(lay, 40, 0.35)
    if tiles:
        for x in range(int(x0) + 30, int(x1), 64):
            p.line([(x, y0), (x, rail_y)], mix(upper, INK, 0.3), 1.6)
        for y in range(int(y0) + 20, int(rail_y), 48):
            p.line([(x0, y), (x1, y)], mix(upper, INK, 0.3), 1.6)
    if planks:
        for y in range(int(y0) + 26, int(rail_y), 44):
            p.line([(x0, y), (x1, y)], mix(upper, INK, 0.45), 2.0)
            p.line([(x0, y + 2.5), (x1, y + 2.5)], mix(upper, PAPER, 0.15), 1.0)
    if lower is not None:
        p.rect(x0, rail_y, x1, y1, lower, None)
        for x in range(int(x0) + 50, int(x1), 120):
            p.rect(x + 10, rail_y + 26, x + 104, y1 + 30, None, mix(lower, INK, 0.5), 2.0, 3)
            p.line([(x + 13, rail_y + 29), (x + 101, rail_y + 29)], mix(lower, PAPER, 0.18), 1.2)
        p.rect(x0, rail_y - 8, x1, rail_y + 10, mix(lower, PAPER, 0.1), INK, 2.4)
        p.line([(x0, rail_y - 5), (x1, rail_y - 5)], mix(lower, PAPER, 0.3), 1.2)


SEA_WALL = mix(SEAGLASS, PAPER, 0.32)         # the station's sea-glass rooms, ~(135,150,139)
NAVY_WALL = mix(STORM, BULK_HI, 0.62)         # storm-navy panelled rooms, ~(58,75,86)
NAVY_PANEL = mix(STORM, SEAGLASS, 0.30)


def in_oval(fn):
    """A tableau sprite: the painter's room fragment, full bleed in the record frame's window."""
    def run(rng):
        im = fn(rng).done()
        # a soft inner shadow from the frame's lip along the top and left edges
        sh = Image.new("L", im.size, 0)
        ImageDraw.Draw(sh).rectangle((0, 0, im.size[0], 18), fill=150)
        ImageDraw.Draw(sh).rectangle((0, 0, 14, im.size[1]), fill=110)
        sh = sh.filter(ImageFilter.GaussianBlur(10))
        dark = Image.new("RGBA", im.size, rgba(BLACK))
        dark.putalpha(sh)
        im.alpha_composite(dark)
        return grain(im, rng_for(6000 + rng.randrange(1000)), amp=5, mottle=5, speck=8)
    return run


def funnel(p, mx, my, ang, L=200, mouth=60, tag=False):
    """A brass ear-trumpet funnel: the mouth at (mx,my) pressed to plaster, the tube trailing away."""
    def R(q):
        return rot(q, (mx, my), ang)
    bell = [R((mx, my - mouth / 2)), R((mx, my + mouth / 2)),
            R((mx + L * 0.45, my + 10)), R((mx + L * 0.45, my - 10))]
    tube = bezier([R((mx + L * 0.45, my)), R((mx + L * 0.8, my + 10)), R((mx + L, my + 70)), R((mx + L * 0.9, my + 150))], 30)
    strap(p, tube, 14, BRASS_LO, INK, 2.4, hi=BRASS_HI)
    p.poly(bell, BRASS, INK, 2.8)
    p.line([R((mx + 8, my - mouth / 2 + 6)), R((mx + L * 0.42, my - 7))], BRASS_HI, 2)
    p.line([R((mx + 8, my + mouth / 2 - 6)), R((mx + L * 0.42, my + 7))], BRASS_DK, 2)
    p.line([R((mx, my - mouth / 2 - 4)), R((mx, my + mouth / 2 + 4))], INK, 6)
    p.line([R((mx + 2, my - mouth / 2 - 2)), R((mx + 2, my + mouth / 2 + 2))], BRASS_HI, 2)
    if tag:
        tx, ty = R((mx + L * 0.3, my + 40))
        p.line([R((mx + L * 0.3, my + 8)), (tx, ty - 22)], INK, 1.6)
        p.rect(tx - 34, ty - 22, tx + 34, ty + 14, BRASS, INK, 2.2, 4)
        p.line([(tx - 30, ty - 18), (tx + 30, ty - 18)], BRASS_HI, 1.4)
        p.ell(tx, ty - 14, 3, 3, BLACK, None)


def plaster_wall(p, x0, y0, x1, y1):
    p.rect(x0, y0, x1, y1, mix(SEAGLASS, PAPER, 0.25), INK, 2.6, 3)
    for k in range(10):
        y = y0 + 30 + k * (y1 - y0 - 40) / 10
        p.line([(x0 + 8, y), (x0 + 30 + (k * 37) % 60, y + 3)], mix(SEAGLASS, INK, 0.25), 1.4)


def hiss(p, mx, my, ang, n=3):
    for k in range(n):
        a = ang + 180 + (k - 1) * 28
        r0 = 18
        x0 = mx + r0 * math.cos(math.radians(a)) * -1
        p0 = (mx - 46 * math.cos(math.radians(a - 180)), my - 46 * math.sin(math.radians(a - 180)))
        pts = []
        for i in range(7):
            t = i / 6
            r = 40 + 50 * t
            aa = math.radians(a + 8 * math.sin(t * 9 + k))
            pts.append((mx + r * math.cos(aa), my + r * math.sin(aa)))
        p.line(pts, PAPER_HI, 3)


def hiss_marks(p, mx, my, ang, mouth, scale=1.0):
    """Three short pale strokes escaping where the funnel's mouth meets the plaster."""
    for k, (side, off) in enumerate(((-1, 0), (1, 0), (-1, 16))):
        y0 = side * (mouth / 2 + 6 + off * 0.4)
        pts = [(mx + 6 + off, my + y0), (mx + 20 * scale + off, my + y0 + side * 10 * scale),
               (mx + 40 * scale + off, my + y0 + side * 14 * scale)]
        pts = [rot(q, (mx, my), ang) for q in pts]
        p.line(pts, INK, 5.6)
        p.line(pts, PAPER_HI, 3.2)


def paint_m_funnels(rng, on):
    """LISTENING ROOM. On: three funnels pressed to the plaster, hissing. Off: let go of the
    wall, hanging slack from their tubes, mouths turned down -- nothing left to listen to."""
    p = sprite_pen(rng)
    panelled_wall(p, rng, SEA_WALL, 540, NAVY_PANEL)
    plaster_wall(p, 90, 60, 230, 600)
    mouths = ((232, 170, -12), (232, 320, 4), (232, 470, 14))
    for (mx, my, a) in mouths:
        if on:
            funnel(p, mx, my, a, L=360, mouth=70)
            hiss_marks(p, mx, my, a, 70)
        else:
            funnel(p, mx + 46, my + 38, a + 34, L=360, mouth=70)
    return p


def paint_m_funnel_venn(rng, on):
    p = sprite_pen(rng)
    panelled_wall(p, rng, SEA_WALL, 540, NAVY_PANEL)
    plaster_wall(p, 140, 80, 300, 560)
    if on:
        funnel(p, 302, 300, 0, L=420, mouth=90, tag=True)
        hiss_marks(p, 302, 300, 0, 90, scale=1.25)
    else:
        funnel(p, 352, 350, 36, L=420, mouth=90, tag=True)
    return p


def paint_m_diaphragm(rng, mode):
    p = sprite_pen(rng)
    panelled_wall(p, rng, NAVY_WALL, 600, None, planks=True)
    for x in (150, 750):
        for y in range(90, 600, 60):
            rivet(p, x, y, 3.4, mix(NAVY_WALL, PAPER, 0.25))
    cx, cy, r = 450, 330, 220
    mem = (22, 30, 40)
    p.ell(cx, cy, r + 32, r + 32, IRON_HI, INK, 3)
    p.arc(cx, cy, r + 28, r + 28, 200, 300, mix(IRON_HI, PAPER, 0.3), 2.4)
    p.ell(cx, cy, r + 6, r + 6, IRON, INK, 2.4)
    p.ell(cx, cy, r, r, mem, INK, 2.6)
    lay = p.layer()
    if mode != "in":
        # slack: the skin hangs flat and pale, the boss sunk to its seat
        p.ell(cx, cy, r, r, mix(mem, SEAGLASS, 0.45), INK, 2.6)
    if mode == "in":
        # drawn in toward the boss: radial folds and the rim pulled off its seat between the bolts
        for k in range(24):
            a = math.radians(k * 15 + 4)
            p0 = (cx + (r - 6) * math.cos(a), cy + (r - 6) * math.sin(a))
            p1 = (cx + 30 * math.cos(a + 0.5), cy + 30 * math.sin(a + 0.5))
            mid = (lerp(p0[0], p1[0], 0.45) + 22 * math.cos(a + 1.57), lerp(p0[1], p1[1], 0.45) + 22 * math.sin(a + 1.57))
            pts = bezier([p0, mid, p1], 24)
            lay.line(pts, mix(mem, SEAGLASS, 0.55), 3.2)
            lay.line([(x + 3, y + 3) for x, y in pts], BLACK, 2.4)
        for rr in (60, 110, 160):
            lay.arc(cx, cy, rr, rr, 200, 290, mix(mem, SEAGLASS, 0.35), 2)
        p.put(lay, mask=p.mask_circle((cx, cy), r - 2))
        p.ell(cx, cy, 34, 34, BLACK, None)
    else:
        # slack: one long shallow sag, a single dull sheen low on the skin
        lay.arc(cx, cy - 40, r - 40, r - 70, 30, 150, mix(mem, SEAGLASS, 0.4), 4)
        lay.arc(cx, cy - 60, r - 20, r - 40, 40, 140, mix(mem, SEAGLASS, 0.25), 2.4)
        p.put_soft(lay, 1.5, 1.0, mask=p.mask_circle((cx, cy), r - 2))
    p.ell(cx, cy, 24, 24, BRASS, INK, 2.4)
    p.arc(cx, cy, 20, 20, 200, 290, BRASS_HI, 1.8)
    p.ell(cx, cy, 8, 8, BRASS_DK, None)
    for k in range(12):
        a = math.radians(k * 30)
        bx, by = cx + (r + 18) * math.cos(a), cy + (r + 18) * math.sin(a)
        p.ell(bx, by, 11, 11, BRASS, INK, 2.2)
        p.arc(bx, by, 8, 8, 200, 290, BRASS_HI, 1.4)
        p.line([(bx - 5, by), (bx + 5, by)], INK, 1.6)
    return p


def paint_m_jars(rng, level):
    """WET LABORATORY. Tilted: five specimen jars leaning on the shelf at five angles, the water
    in each lying along its tilted base, not level. Level: upright, the water flat."""
    p = sprite_pen(rng)
    panelled_wall(p, rng, SEA_WALL, 520, NAVY_PANEL, tiles=True)
    p.rect(30, 470, 870, 494, TIMBER, INK, 2.8, 2)
    p.line([(36, 474), (864, 474)], TIMBER_HI, 1.6)
    for x in (110, 790):
        p.poly([(x - 10, 494), (x + 10, 494), (x + 4, 560), (x - 4, 560)], TIMBER_DK, INK, 2)
    angs = (0, 0, 0, 0, 0) if level else (-14, -5, -12, -3, -10)
    glass = mix(SEAGLASS, PAPER, 0.35)
    water = mix(SEAGLASS, STORM, 0.25)
    for i, a in enumerate(angs):
        cx = 130 + i * 160
        piv = (cx, 470)

        def R(q):
            return rot(q, piv, a)
        x0, x1, y0, y1 = cx - 56, cx + 56, 210, 470
        jar = [R(q) for q in ((x0 + 10, y0), (x1 - 10, y0), (x1, y0 + 12), (x1, y1 - 10), (x1 - 10, y1),
                               (x0 + 10, y1), (x0, y1 - 10), (x0, y0 + 12))]
        sh = p.layer()
        sh.poly([(x + 8, y + 6) for x, y in jar], BLACK, None)
        p.put_soft(sh, 4, 0.3)
        p.poly(jar, glass, None)
        # water: in the jar's own frame, so a tilted jar holds tilted water
        wl = [R(q) for q in ((x0 - 20, 320), (x1 + 20, 320), (x1 + 20, y1 + 20), (x0 - 20, y1 + 20))]
        lay = p.layer()
        lay.poly(wl, water, None)
        lay.line([wl[0], wl[1]], SEAGLASS_HI, 4)
        p.put(lay, mask=p.mask_poly(jar))
        # something pale suspended in each: a flat, folded shape
        sc = R((cx, 390))
        p.ell(sc[0], sc[1], 20, 30, mix(PAPER, SEAGLASS, 0.3), INK, 2)
        p.line([R((cx - 8, 372)), R((cx + 6, 404))], mix(PAPER, INK, 0.4), 1.6)
        p.poly(jar, None, INK, 3.0)
        p.line([R((x0 + 12, y0 + 30)), R((x0 + 12, y1 - 30))], PAPER_HI, 2.4)
        lid = [R(q) for q in ((x0 - 6, y0 - 26), (x1 + 6, y0 - 26), (x1 + 6, y0 + 4), (x0 - 6, y0 + 4))]
        p.poly(lid, BRASS, INK, 2.6)
        p.line([R((x0, y0 - 18)), R((x1, y0 - 18))], BRASS_HI, 1.6)
    return p


def cloth(p, x0, y0, x1, y1):
    p.poly([(x0, y0), (x1, y0 + 6), (x1 + 10, y1), (x0 - 10, y1 - 4)], mix(PAPER, SEAGLASS, 0.18), INK, 2.6)
    for k in range(1, 6):
        y = lerp(y0, y1, k / 6)
        p.line([(x0 + 6, y), (x1 - 6, y + 4)], mix(PAPER, SEAGLASS, 0.35), 1.4)


def kitchen(p, rng):
    panelled_wall(p, rng, SEA_WALL, 300, None, tiles=True)
    p.rect(20, 300, 880, 640, mix(TIMBER, SOOT, 0.2), None)
    p.line([(20, 300), (880, 300)], INK, 2.6)


def paint_m_spoon(rng, up):
    """KITCHEN AND MESS. Up: his spoon stands off the cloth in the air, tilted, its shadow far
    below in its dent. Down: it has settled into the dent it left."""
    p = sprite_pen(rng)
    kitchen(p, rng)
    cloth(p, 70, 330, 830, 560)
    metal, metal_hi = (196, 194, 184), (238, 236, 228)
    dent = mix(PAPER, INK, 0.3)
    p.ell(620, 440, 96, 36, dent, None)
    p.rect(160, 432, 540, 452, dent, None, r=10)
    p.line([(170, 452), (530, 452)], mix(PAPER, PAPER_HI, 0.6), 1.6)
    p.arc(620, 444, 96, 36, 20, 160, mix(PAPER, PAPER_HI, 0.6), 1.8)
    ang = -14 if up else 0
    lift = 120 if up else 0
    piv = (450, 440)

    def R(q):
        return rot((q[0], q[1] - lift), (piv[0], piv[1] - lift), ang)
    if up:
        sh = p.layer()
        sh.ell(626, 446, 88, 28, BLACK, None)
        sh.rect(170, 438, 530, 452, BLACK, None, r=7)
        p.put_soft(sh, 6, 0.35)
    oy = 432
    handle = [R(q) for q in ((160, oy + 2), (530, oy), (548, oy + 9), (530, oy + 18), (160, oy + 16))]
    p.poly(handle, metal, INK, 2.6)
    bc = R((620, oy + 8))
    bowl = p.layer()
    bowl.ell(bc[0], bc[1], 94, 34, metal, INK, 2.8)
    bowl.ell(bc[0] - 10, bc[1] - 6, 62, 16, metal_hi, None)
    p.put(bowl)
    p.line([R((172, oy + 6)), R((520, oy + 5))], metal_hi, 2)
    return p


def paint_m_bed(rng, pressed):
    """BUNK ROOM. Pressed: the mattress holds a deep body-shaped hollow, blanket kicked to the
    foot. Risen: the hollow has come up and kept coming -- the mattress domes above its frame
    under a smooth wave-striped blanket, as if breathing in."""
    p = sprite_pen(rng)
    panelled_wall(p, rng, NAVY_WALL, 640, None, planks=True)
    p.rect(60, 420, 840, 450, TIMBER, INK, 2.8, 2)
    p.rect(60, 450, 80, 600, TIMBER_DK, INK, 2.4)
    p.rect(820, 450, 840, 600, TIMBER_DK, INK, 2.4)
    p.rect(40, 230, 70, 600, TIMBER, INK, 2.8, 3)
    p.rect(830, 300, 860, 600, TIMBER, INK, 2.8, 3)
    top = []
    for i in range(61):
        x = 80 + 740 * i / 60
        t = (x - 160) / 600
        y = 330
        if 0 < t < 1:
            if pressed:
                prof = 0.8 * math.exp(-((t - 0.12) / 0.07) ** 2) + 0.65 * math.exp(-((t - 0.45) / 0.12) ** 2) + 0.4 * math.exp(-((t - 0.78) / 0.14) ** 2)
                y += 74 * min(1.0, prof + 0.35 * math.sin(math.pi * t) ** 2)
            else:
                y -= 96 * math.sin(math.pi * t) ** 1.6
        top.append((x, y))
    mat = top + [(820, 420), (80, 420)]
    p.poly(mat, mix(PAPER, SEAGLASS, 0.12), None)
    if pressed:
        p.poly(top[6:56] + [(x, 330) for x, _ in top[55:5:-1]], mix(PAPER, INK, 0.28), None)
        p.line([(x, 330) for x, _ in top[6:56]], mix(PAPER, PAPER_HI, 0.6), 2.0)
        p.poly([(700, 300), (820, 290), (836, 360), (780, 380), (690, 350)], mix(SEAGLASS, INK, 0.25), INK, 2.6)
    else:
        # the wave blanket rides the dome
        blanket = [(x, y + 12) for x, y in top[22:]]
        p.poly(blanket + [(820, 420), (top[22][0], 420)], mix(SEAGLASS, INK, 0.2), INK, 2.6)
        for k, off in enumerate((30, 52, 74)):
            p.line([(x, y + off + 6 * math.sin(x / 26)) for x, y in top[24:59]], SEAGLASS if k % 2 == 0 else mix(SEAGLASS, INK, 0.4), 2.2)
    p.line(top, INK, 2.8)
    p.line([(80, 330), (80, 420), (820, 420), (820, 330)], INK, 2.6)
    p.rect(92, 296, 200, 334, PAPER_HI, INK, 2.4, 12)
    return p


def paint_m_pen(rng, down):
    p = sprite_pen(rng)
    panelled_wall(p, rng, SEA_WALL, 600, NAVY_PANEL)
    # drum, still: a paper cylinder seen front-on
    p.rect(120, 300, 620, 560, PAPER, INK, 2.8, 6)
    p.rect(110, 290, 130, 570, BRASS, INK, 2.4, 3)
    p.rect(610, 290, 630, 570, BRASS, INK, 2.4, 3)
    for y in (330, 380, 430, 480, 530):
        p.line([(132, y), (608, y)], mix(PAPER, SEAGLASS, 0.3), 1.2)
    # the last scratch, ending under the pen
    pen_x, pen_y = 520, 420
    scratch = [(132, 446), (200, 440), (260, 452), (320, 430), (380, 444), (440, 418), (480, 428), (pen_x, pen_y)]
    p.line(scratch, (60, 70, 96), 2.4)
    lift = 0 if down else 110
    # pen arm from the right pivot
    piv = (800, 300)
    tip = (pen_x, pen_y - lift)
    p.ell(piv[0], piv[1], 26, 26, BRASS, INK, 2.6)
    p.ell(piv[0], piv[1], 9, 9, BRASS_DK, None)
    strap(p, [piv, (660, (tip[1] + piv[1]) / 2 - 20), (tip[0] + 20, tip[1] - 14)], 12, BRASS, INK, 2.2, hi=BRASS_HI)
    p.poly([(tip[0] + 22, tip[1] - 20), (tip[0] + 26, tip[1] - 6), (tip[0], tip[1])], SOOT, INK, 2)
    if not down:
        # the line simply stops where the nib was; a small blot
        p.ell(pen_x, pen_y, 5, 4, (60, 70, 96), None)
    p.rect(760, 300, 840, 600, IRON, INK, 2.6, 3)
    return p


def paint_m_coat(rng, full):
    p = sprite_pen(rng)
    # the intake office: sea-glass plaster over its blue wainscot, the hook rail
    panelled_wall(p, rng, SEA_WALL, 470, mix(STORM, SEAGLASS, 0.18))
    p.rect(200, 90, 700, 118, TIMBER, INK, 2.6, 2)
    for hx2 in (260, 330, 570, 640):
        p.arc(hx2, 136, 12, 14, 0, 200, BRASS, 6)
        p.arc(hx2, 136, 12, 14, 0, 200, INK, 1.4)
    hx = 450
    p.arc(hx, 136, 12, 14, 0, 200, BRASS, 6)
    p.arc(hx, 136, 12, 14, 0, 200, INK, 1.4)
    coat = mix(STORM, SEAGLASS, 0.35)
    hi = mix(coat, SEAGLASS_HI, 0.5)
    if full:
        # shoulders held out by nobody; hood up and round
        p.poly([(450, 130), (360, 190), (320, 240), (300, 560), (600, 560), (580, 240), (540, 190)], coat, INK, 2.8)
        p.poly([(390, 120), (510, 120), (540, 170), (530, 230), (370, 230), (360, 170)], coat, INK, 2.8)
        p.ell(450, 186, 46, 40, BLACK, INK, 2)
        p.line([(450, 236), (450, 556)], INK, 2)
        for y in (290, 360, 430, 500):
            p.ell(462, y, 5, 5, BRASS_LO, INK, 1.2)
        p.line([(330, 250), (318, 540)], hi, 2)
        p.line([(560, 250), (588, 400)], hi, 1.6)
        p.line([(360, 300), (346, 470), (380, 520)], INK, 1.6)
        p.line([(540, 300), (556, 470), (520, 520)], INK, 1.6)
    else:
        p.poly([(450, 132), (424, 150), (404, 260), (396, 600), (504, 600), (496, 260), (476, 150)], coat, INK, 2.8)
        p.poly([(424, 150), (380, 210), (392, 300), (420, 280)], coat, INK, 2.4)
        p.line([(450, 150), (450, 596)], INK, 1.8)
        for x in (420, 436, 466, 484):
            p.line([(x, 280), (x - 2, 590)], mix(coat, INK, 0.5), 1.4)
        p.line([(412, 270), (402, 590)], hi, 1.8)
    return p


def paint_m_cup(rng, warm):
    p = sprite_pen(rng)
    kitchen(p, rng)
    cloth(p, 120, 400, 780, 580)
    # dry ring left of the cup
    rc = AMBER if warm else mix(PAPER, INK, 0.3)
    p.ell(270, 470, 70, 22, None, rc, 4 if warm else 2.6)
    if warm:
        lay = p.layer()
        lay.ell(270, 470, 70, 22, None, AMBER_HI, 8)
        p.put_soft(lay, 4, 0.6)
        p.ell(270, 470, 70, 22, None, AMBER, 3.4)
    cx = 520
    p.ell(cx, 488, 96, 22, mix(PAPER, INK, 0.2), None)
    body = [(cx - 90, 300), (cx + 90, 300), (cx + 78, 480), (cx - 78, 480)]
    p.poly(body, mix(SEAGLASS, PAPER, 0.4), INK, 2.8)
    p.ell(cx, 300, 90, 20, mix(SEAGLASS, INK, 0.35), INK, 2.6)
    p.ell(cx, 304, 78, 14, (40, 34, 26), None)
    # the repair: a crack in the handle, a brass staple across it
    p.arc(cx + 112, 380, 40, 56, 270, 90, mix(SEAGLASS, PAPER, 0.4), 16)
    p.arc(cx + 112, 380, 48, 64, 270, 90, INK, 2.4)
    p.arc(cx + 112, 380, 32, 48, 270, 90, INK, 2.4)
    p.line([(cx + 140, 360), (cx + 166, 372)], INK, 1.6)
    p.rect(cx + 140, 352, cx + 172, 362, BRASS, INK, 1.8, 2)
    p.rect(cx + 140, 352, cx + 146, 380, BRASS, INK, 1.6)
    p.rect(cx + 166, 352, cx + 172, 380, BRASS, INK, 1.6)
    p.line([(cx - 76, 320), (cx - 66, 470)], PAPER_HI, 2.2)
    if warm:
        for dx in (-30, 24):
            steam = bezier([(cx + dx, 290), (cx + dx - 40, 220), (cx + dx + 30, 170), (cx + dx - 10, 80)], 40)
            p.line(steam, INK, 7)
            p.line(steam, mix(PAPER_HI, AMBER_HI, 0.2), 4)
    return p


# ============================================================================ ending tableaux
def daylight_wall(p, rng, y1, col=None):
    col = col or (170, 182, 176)
    p.rect(-4, -4, W + 4, y1, col, None)
    lay = p.layer()
    for _ in range(20):
        lay.ell(rng.uniform(0, W), rng.uniform(0, y1), rng.uniform(80, 220), rng.uniform(40, 120),
                mix(col, PAPER_HI, 0.4) if rng.random() < 0.5 else mix(col, SEAGLASS, 0.3), None)
    p.put_soft(lay, 50, 0.4)


def hand_mask(size, arm_from, wrist, ang, k=1.0, arm_w=64, lift=0.0):
    """A relaxed hand, palm down, pointing along `ang` degrees, with its forearm back to `arm_from`."""
    m = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    d = ImageDraw.Draw(m)

    def cap(a, b, w):
        d.line([(a[0] * SS, a[1] * SS), (b[0] * SS, b[1] * SS)], fill=255, width=int(w * SS))
        for x, y in (a, b):
            d.ellipse(((x - w / 2) * SS, (y - w / 2) * SS, (x + w / 2) * SS, (y + w / 2) * SS), fill=255)

    def R(x, y):
        return rot((wrist[0] + x * k, wrist[1] + y * k), wrist, ang)

    cap(arm_from, wrist, arm_w * k)
    palm = [R(-6, -28), R(40, -34), R(80, -30), R(96, -14), R(98, 14), R(80, 30), R(30, 32), R(0, 26)]
    d.polygon([(x * SS, y * SS) for x, y in palm], fill=255)
    # four fingers close together, relaxed, curled a little at the tips
    for j, (dy, L) in enumerate(((-21, 46), (-7, 52), (7, 50), (20, 40))):
        a0 = R(86, dy)
        a1 = R(86 + L * 0.65, dy + (j - 1.5) * 1.5)
        a2 = R(86 + L, dy + (j - 1.5) * 2 + 9 * (1 - lift))
        cap(a0, a1, 17 * k)
        cap(a1, a2, 15 * k)
    # thumb, tucked under toward the fingers
    cap(R(30, -26), R(64, -42), 20 * k)
    cap(R(64, -42), R(90, -42 + 6 * lift), 17 * k)
    return m


def stamp(p, m, col=BLACK):
    sil = Image.new("RGBA", m.size, rgba(col))
    sil.putalpha(m)
    p.im.alpha_composite(sil)


def paint_end_a_record(rng):
    p = Pen(W, H, rng)
    wall = mix(SEAGLASS_HI, PAPER, 0.35)
    daylight_wall(p, rng, 640, wall)
    # dado and floor as in the office: storm-navy boarding, timber floor
    p.rect(-4, 640, W + 4, 900, mix(STORM, SEAGLASS, 0.45), INK, 2.6)
    for x in range(0, W, 46):
        p.line([(x, 646), (x, 896)], mix(STORM, SEAGLASS, 0.3), 2)
    p.rect(-4, 630, W + 4, 646, mix(STORM, SEAGLASS, 0.6), INK, 2.4)
    p.rect(-4, 900, W + 4, H + 4, mix(TIMBER, PAPER, 0.2), None)
    for y in (940, 1000, 1066):
        p.line([(-4, y), (W + 4, y)], mix(TIMBER, INK, 0.4), 1.6)
    p.line([(-4, 900), (W + 4, 900)], INK, 3)
    # the office window, grey daylight, an ordinary sea
    p.rect(300, 90, 760, 560, mix(STORM, SEAGLASS, 0.45), INK, 3, 2)
    p.rect(326, 116, 734, 534, SKY, INK, 2.4)
    p.rect(326, 380, 734, 534, SEA, None)
    p.line([(326, 380), (734, 380)], mix(SEA, INK, 0.5), 2)
    for (x, y, L) in ((360, 420, 60), (470, 452, 40), (600, 410, 70), (520, 500, 50), (650, 480, 40)):
        p.line([(x, y), (x + L / 2, y - 3), (x + L, y)], mix(SEA, INK, 0.4), 1.8)
    for x in (462, 598):
        p.rect(x - 5, 116, x + 5, 534, mix(STORM, SEAGLASS, 0.45), INK, 2)
    p.rect(326, 300, 734, 310, mix(STORM, SEAGLASS, 0.45), INK, 2)
    p.rect(280, 556, 780, 574, mix(STORM, SEAGLASS, 0.6), INK, 2.4, 2)
    # coat rail with eight hooks; Venn's coat on hook 7, wet, hanging ordinary
    rx0, rx1, ry = 860, 1300, 300
    p.rect(rx0, ry - 20, rx1, ry + 20, TIMBER, INK, 2.6, 2)
    hooks = [rx0 + 30 + i * ((rx1 - rx0 - 60) / 7) for i in range(8)]
    for hx in hooks:
        p.rect(hx - 5, ry - 10, hx + 5, ry + 6, BRASS, INK, 1.6, 2)
        p.arc(hx + 9, ry + 14, 10, 14, 90, 270, INK, 5)
        p.arc(hx + 9, ry + 14, 10, 14, 90, 270, BRASS, 2.6)
    h7 = hooks[6]
    coat = mix(SOOT, STORM, 0.55)
    hi = mix(coat, SEAGLASS_HI, 0.35)
    # hanging by its loop: collapsed shoulders, sleeves down the sides, an ordinary wet coat
    p.poly([(h7 + 9, ry + 26), (h7 - 30, ry + 54), (h7 - 52, ry + 120), (h7 - 60, ry + 420), (h7 - 20, ry + 440),
            (h7 + 30, ry + 436), (h7 + 66, ry + 420), (h7 + 62, ry + 120), (h7 + 46, ry + 54)], coat, INK, 2.8)
    p.poly([(h7 - 52, ry + 120), (h7 - 74, ry + 360), (h7 - 52, ry + 372), (h7 - 40, ry + 140)], mix(coat, INK, 0.2), INK, 2.2)
    p.poly([(h7 + 62, ry + 120), (h7 + 84, ry + 360), (h7 + 62, ry + 372), (h7 + 50, ry + 140)], mix(coat, INK, 0.2), INK, 2.2)
    p.poly([(h7 - 18, ry + 24), (h7 + 36, ry + 24), (h7 + 30, ry + 76), (h7 + 9, ry + 96), (h7 - 12, ry + 76)], mix(coat, INK, 0.3), INK, 2.2)
    p.line([(h7 + 9, ry + 96), (h7 + 6, ry + 430)], INK, 2)
    for k in (-34, 26, 46):
        p.line([(h7 + k, ry + 150), (h7 + k * 1.15, ry + 420)], mix(coat, INK, 0.5), 1.6)
    p.line([(h7 - 46, ry + 140), (h7 - 52, ry + 410)], hi, 2)
    for y in (ry + 160, ry + 240, ry + 320):
        p.ell(h7 + 20, y, 4, 4, BRASS_LO, INK, 1.1)
    # drips: ordinary water, falling
    for (dx, dy) in ((-40, 790), (6, 812), (40, 776)):
        p.ell(h7 + dx, dy, 3, 5, mix(SEAGLASS_HI, PAPER_HI, 0.4), INK, 1.2)
    p.ell(h7 + 4, 894, 70, 7, mix(STORM, SEAGLASS, 0.6), None)
    # the desk, front-on: top, two pedestals of drawers, a knee panel
    dx0, dx1, top = 200, 1040, 690
    sh = p.layer()
    sh.rect(dx0 + 10, 900, dx1 + 10, 912, BLACK, None)
    p.put_soft(sh, 8, 0.3)
    p.rect(dx0 - 16, top, dx1 + 16, top + 26, TIMBER_HI, INK, 3, 3)
    p.line([(dx0 - 12, top + 4), (dx1 + 12, top + 4)], mix(TIMBER_HI, PAPER, 0.3), 1.6)
    p.rect(dx0, top + 26, dx1, 900, TIMBER, INK, 3)
    for px0 in (dx0 + 16, dx1 - 196):
        for k in range(3):
            y0 = top + 42 + k * 58
            p.rect(px0, y0, px0 + 180, y0 + 50, TIMBER, INK, 2.2, 2)
            p.line([(px0 + 4, y0 + 4), (px0 + 176, y0 + 4)], TIMBER_HI, 1.2)
            p.rect(px0 + 74, y0 + 21, px0 + 106, y0 + 29, BRASS, INK, 1.4, 3)
    p.rect(dx0 + 214, top + 42, dx1 - 214, 880, TIMBER, INK, 2.2, 2)
    p.rect(dx0 + 232, top + 60, dx1 - 232, 862, None, mix(TIMBER, INK, 0.5), 1.6, 2)
    # on the blotter: the corrected record, its corner lifted by her hand
    p.rect(420, top - 8, 820, top + 2, mix(STORM, SEAGLASS, 0.4), INK, 2, 2)
    page = [(470, top - 8), (760, top - 8), (790, top - 40), (742, top - 52), (500, top - 16)]
    p.poly([(470, top - 10), (770, top - 10), (770, top - 6), (470, top - 6)], PAPER, INK, 1.6)
    p.poly([(700, top - 10), (770, top - 10), (812, top - 64), (760, top - 76)], PAPER_HI, INK, 2.2)
    p.line([(706, top - 14), (762, top - 70)], PAPER_LO, 1.2)
    # Ada's hand: flat black silhouette from the foreground, fingertips under the lifted corner
    stamp(p, hand_mask((W, H), (1010, 1120), (850, 760), -128, k=1.0, arm_w=70, lift=0.6))
    return p


def paint_end_a_jetty(rng):
    p = Pen(W, H, rng)
    p.rect(-4, -4, W + 4, 520, SKY, None)
    lay = p.layer()
    for _ in range(9):
        lay.ell(rng.uniform(0, W), rng.uniform(60, 420), rng.uniform(160, 360), rng.uniform(16, 36), mix(SKY, PAPER_HI, 0.5), None)
    p.put_soft(lay, 14, 0.55)
    p.rect(-4, 520, W + 4, H + 4, SEA, None)
    p.line([(-4, 520), (W + 4, 520)], mix(SEA, INK, 0.45), 2)
    for _ in range(70):
        x = rng.uniform(-20, W)
        y = rng.uniform(530, 1060)
        L = rng.uniform(20, 60) * (0.6 + (y - 520) / 600)
        p.line([(x, y), (x + L * 0.5, y - 3), (x + L, y)], mix(SEA, INK, 0.35), 1.8)
    # the real launch: R01's silhouette, scaled to x 760-1240
    s = (1240 - 760) / 430.0
    ox = 760 - 860 * s
    oy = 690 - 780 * s

    def T(x, y):
        return (ox + x * s, oy + y * s)

    hull = [T(1290, 780), T(1290, 870), T(912, 870), T(895, 850), T(878, 820), T(860, 780)]
    p.poly(hull, PAPER, INK, 2.8)
    p.poly([T(864, 784), T(1290, 784), T(1290, 792), T(868, 792)], STORM, None)
    p.rect(*T(858, 776), *T(1294, 781), fill=mix(TIMBER, PAPER, 0.2), ink=INK, w=1.8)
    p.rect(*T(880, 862), *T(1290, 870), fill=mix(TIMBER, SOOT, 0.4), ink=None)
    p.poly(hull, None, INK, 2.8)
    cabin = mix(PAPER, SEAGLASS, 0.12)
    p.rect(*T(960, 686), *T(1120, 776), fill=cabin, ink=INK, w=2.4)
    p.rect(*T(952, 678), *T(1128, 688), fill=mix(SEAGLASS, PAPER, 0.15), ink=INK, w=2.2)
    p.rect(*T(986, 696), *T(1094, 760), fill=BRASS, ink=INK, w=2.0)
    # its window shows its own empty cabin: a bench and an unlit lamp, nobody
    wx0, wy0 = T(990, 700)
    wx1, wy1 = T(1090, 756)
    p.rect(wx0, wy0, wx1, wy1, mix(cabin, TIMBER, 0.45), INK, 1.6)
    p.rect(wx0 + 4, wy1 - 22, wx1 - 4, wy1 - 12, TIMBER_DK, INK, 1.4)
    p.rect(wx0 + 8, wy1 - 12, wx0 + 14, wy1 - 1, TIMBER_DK, None)
    p.rect(wx1 - 14, wy1 - 12, wx1 - 8, wy1 - 1, TIMBER_DK, None)
    p.line([(wx0 + 70, wy0), (wx0 + 70, wy0 + 12)], INK, 1.4)
    p.ell(wx0 + 70, wy0 + 20, 7, 9, GLASS_DEAD, INK, 1.4)
    p.rect(*T(1100, 714), *T(1114, 772), fill=mix(cabin, INK, 0.25), ink=INK, w=1.6)
    p.rect(*T(1177, 520), *T(1183, 780), fill=mix(TIMBER, PAPER, 0.25), ink=INK, w=1.8)
    # pennant: storm navy with two paper stripes at offsets 26/62, 12 wide, swallowtail
    px0, py0 = T(1182, 524)
    w_, h_, n_ = 100 * s, 56 * s, 14 * s
    pen_pts = [(px0, py0), (px0 + w_, py0), (px0 + w_ - n_, py0 + h_ / 2), (px0 + w_, py0 + h_), (px0, py0 + h_)]
    p.poly(pen_pts, (26, 40, 56), None)
    lay = p.layer()
    for off in (26, 62):
        lay.rect(px0 + off * s, py0, px0 + (off + 12) * s, py0 + h_, PAPER, None)
    p.put(lay, mask=poly_mask((W, H), pen_pts))
    p.poly(pen_pts, None, INK, 2.2)
    # waterline reflection, broken
    for k in range(6):
        y = T(0, 870)[1] + 10 + k * 12
        p.line([(780 + k * 6, y), (1220 - k * 10, y)], mix(SEA, PAPER, 0.25), 2)
    # jetty planks y 760-820, from the left, pilings into the water
    p.rect(-4, 760, 700, 820, TIMBER, INK, 3)
    for x in range(10, 700, 54):
        p.line([(x, 762), (x, 818)], TIMBER_DK, 2)
    p.line([(-4, 766), (700, 766)], TIMBER_HI, 1.6)
    for x in (60, 300, 560):
        p.rect(x, 820, x + 28, 1000, TIMBER_DK, INK, 2.6)
        p.line([(x - 10, 1000), (x + 38, 1000)], mix(SEA, INK, 0.4), 2)
    p.rect(640, 720, 670, 760, TIMBER_DK, INK, 2.4, 3)   # bollard
    p.line([(670, 740), (770, T(0, 780)[1])], INK, 2)    # mooring line to the bow
    return p


def paint_end_a_inquiry(rng):
    p = Pen(W, H, rng)
    daylight_wall(p, rng, 140, (178, 186, 182))
    p.rect(-4, 120, W + 4, H + 4, mix(TIMBER, PAPER, 0.25), INK, 3)
    lay = p.layer()
    for _ in range(40):
        y = rng.uniform(130, H)
        lay.line([(-4, y), (W + 4, y + rng.uniform(-4, 4))], mix(TIMBER, INK, 0.25), rng.uniform(1, 2.4))
    p.put(lay, 0.5)
    p.line([(-4, 128), (W + 4, 128)], mix(TIMBER, PAPER, 0.5), 2)
    sh = p.layer()
    sh.rect(354, 194, 1114, 814, BLACK, None)
    p.put_soft(sh, 10, 0.3)
    x0, y0, x1, y1 = 344, 180, 1104, 800
    p.rect(x0, y0, x1, y1, PAPER_HI, INK, 2.6)
    p.rect(x0 + 30, y0 + 30, x1 - 30, y0 + 90, None, mix(PAPER, INK, 0.4), 1.6)
    for y in range(int(y0) + 130, int(y1) - 40, 40):
        p.line([(x0 + 40, y), (x1 - 40, y)], mix(PAPER, SEAGLASS, 0.45), 1.4)
    p.line([(x0 + 120, y0 + 110), (x0 + 120, y1 - 40)], mix(PAPER, VIOLET, 0.35), 1.4)
    p.rect(x0 + 40, y1 - 90, x0 + 360, y1 - 50, None, mix(PAPER, INK, 0.4), 1.4)
    # the pen on the right
    pts = [(1190, 300), (1230, 700)]
    strap(p, pts, 16, SOOT, INK, 2.4, hi=mix(SOOT, PAPER, 0.35))
    p.poly([(1222, 700), (1238, 698), (1232, 740)], BRASS, INK, 2)
    p.rect(1184, 360, 1204, 380, BRASS, INK, 1.6)
    return p


def paint_end_a_page(rng):
    p = Pen(W, H, rng)
    # wall and the window the sill belongs to
    daylight_wall(p, rng, 150, (182, 190, 186))
    p.rect(-4, 110, W + 4, 160, mix(TIMBER, PAPER, 0.3), INK, 3)
    p.line([(-4, 116), (W + 4, 116)], mix(TIMBER, PAPER, 0.55), 2)
    p.rect(-4, 160, W + 4, H + 4, TIMBER, INK, 3)
    lay = p.layer()
    for _ in range(36):
        y = rng.uniform(170, H)
        lay.line([(-4, y), (W + 4, y + rng.uniform(-3, 3))], TIMBER_DK, rng.uniform(1, 2.4))
    p.put(lay, 0.55)
    # daylight falls across the sill from the window
    lt = p.layer()
    lt.poly([(300, 160), (1300, 160), (1448, 1086), (120, 1086)], PAPER_HI, None)
    p.put_soft(lt, 40, 0.18)
    # the page
    sh = p.layer()
    sh.rect(474, 212, 994, 892, BLACK, None)
    p.put_soft(sh, 8, 0.3)
    x0, y0, x1, y1 = 464, 200, 984, 880
    p.rect(x0, y0, x1, y1, PAPER_HI, INK, 2.6)
    for y in range(int(y0) + 80, int(y1) - 30, 34):
        p.line([(x0 + 30, y), (x1 - 30, y)], mix(PAPER, SEAGLASS, 0.45), 1.4)
    p.line([(x0 + 80, y0 + 20), (x0 + 80, y1 - 20)], mix(PAPER, VIOLET, 0.35), 1.4)
    # the inkwell: its glossy top reflects the window as a bright square
    ix, iy = 1180, 640
    sh = p.layer()
    sh.ell(ix + 8, iy + 120, 90, 16, BLACK, None)
    p.put_soft(sh, 6, 0.35)
    p.rect(ix - 80, iy, ix + 80, iy + 116, BRASS, INK, 3, 10)
    p.rect(ix - 70, iy + 8, ix - 50, iy + 108, BRASS_HI, None, r=6)
    p.rect(ix + 46, iy + 8, ix + 72, iy + 108, BRASS_LO, None, r=6)
    p.rect(ix - 80, iy, ix + 80, iy + 116, None, INK, 3, 10)
    p.ell(ix, iy, 80, 20, BRASS_DK, INK, 2.6)
    p.ell(ix, iy, 66, 16, (10, 12, 16), INK, 2.4)
    # the window, mirrored in the ink: a bright square with its cross bar
    p.rect(ix - 30, iy - 10, ix + 4, iy + 8, (250, 248, 240), None)
    p.line([(ix - 13, iy - 10), (ix - 13, iy + 8)], (10, 12, 16), 2)
    p.line([(ix - 30, iy - 1), (ix + 4, iy - 1)], (10, 12, 16), 1.6)
    glint = p.layer()
    glint.rect(ix - 34, iy - 13, ix + 8, iy + 11, (250, 248, 240), None)
    p.put_soft(glint, 3, 0.35)
    # the water stain: a dark tide ring, and nothing in it
    sx, sy = 900, 800
    p.ell(sx, sy, 30, 20, mix(PAPER_HI, PAPER_LO, 0.55), None)
    p.ell(sx, sy, 30, 20, None, mix(PAPER_LO, TIMBER_DK, 0.55), 2.6)
    p.arc(sx, sy, 25, 16, 200, 330, mix(PAPER_LO, TIMBER_DK, 0.3), 1.2)
    return p


def silhouette_hand(p, pts_list):
    m = Image.new("L", (p.w * SS, p.h * SS), 0)
    d = ImageDraw.Draw(m)
    for pts in pts_list:
        d.polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    sil = Image.new("RGBA", m.size, rgba(BLACK))
    sil.putalpha(m)
    p.im.alpha_composite(sil)


def paint_end_b_terminal(rng):
    p = Pen(W, H, rng, IRON)
    lay = p.layer()
    for _ in range(30):
        lay.ell(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(100, 260), rng.uniform(60, 140), IRON_HI, None)
    p.put_soft(lay, 50, 0.35)
    p.rect(60, 120, 1388, 960, mix(IRON, BULK, 0.4), INK, 3, 10)
    p.line([(70, 130), (1378, 130)], IRON_HI, 2)
    for (sx, sy) in ((84, 144), (1364, 144), (84, 936), (1364, 936)):
        screw(p, sx, sy, 6)
    # the strip throat, the strip itself
    p.rect(176, 276, 1272, 300, BLACK, INK, 2.4, 3)
    p.rect(160, 262, 1288, 278, BRASS, INK, 2.4, 3)
    p.rect(200, 300, 1248, 520, PAPER_HI, INK, 2.6)
    for y in (350, 400, 450):
        p.line([(220, y), (1228, y)], mix(PAPER, SEAGLASS, 0.3), 1.2)
    sh = p.layer()
    sh.rect(200, 300, 1248, 318, BLACK, None)
    p.put_soft(sh, 6, 0.35, mask=poly_mask((W, H), [(200, 300), (1248, 300), (1248, 520), (200, 520)]))
    # the A.M. lamp, lit
    lamp_socket(p, 1180, 240, 16, lit=True)
    enamel_plate(p, 1220, 228, 1300, 252)
    # the pencil, left on the strip
    strap(p, [(380, 600), (760, 560)], 18, AMBER, INK, 2.2, hi=AMBER_HI)
    p.poly([(760, 551), (796, 556), (762, 569)], PAPER, INK, 1.8)
    p.poly([(786, 555), (796, 556), (788, 560)], SOOT, None)
    p.rect(362, 590, 384, 612, mix(PAPER, INK, 0.3), INK, 1.6)
    # her hand, silhouette, in from the right, resting near the pencil
    stamp(p, hand_mask((W, H), (1520, 760), (1150, 650), 186, k=1.25, arm_w=70, lift=0.3))
    return p


def paint_end_b_wide(rng):
    """CONTINUE, the wide shot: the whole station on its piles in a sea-glass dusk, and above the
    horizon the edgeless surface -- a vast flat curved lid, its iris turned on the one lit window."""
    p = Pen(W, H, rng)
    hor = 720
    p.vgrad(-4, -4, W + 4, hor, mix(SEAGLASS_HI, PAPER, 0.15), SEAGLASS)
    clouds = p.layer()
    for _ in range(9):
        clouds.ell(rng.uniform(0, W), rng.uniform(40, 220), rng.uniform(120, 300), rng.uniform(10, 24),
                   mix(SEAGLASS_HI, PAPER_HI, 0.4), None)
    p.put_soft(clouds, 8, 0.4)
    # the lid: a dome far wider than the frame, rising out of the horizon
    lid_c, lid_r = (724, 1500), 1250
    lid = mix(BULK_HI, SEAGLASS, 0.30)
    lay = p.layer()
    lay.ell(lid_c[0], lid_c[1], lid_r + 14, lid_r + 14, SURF_RIM, None)
    lay.ell(lid_c[0], lid_c[1], lid_r, lid_r, lid, None)
    lay.ell(lid_c[0], lid_c[1], lid_r - 70, lid_r - 70, mix(lid, SEAGLASS_HI, 0.18), None)
    lay.ell(lid_c[0], lid_c[1], lid_r - 92, lid_r - 92, lid, None)
    p.put(lay)
    for r, w in ((lid_r + 15, 3.4), (lid_r, 2.6), (lid_r - 70, 2.0), (lid_r - 92, 2.0)):
        p.arc(lid_c[0], lid_c[1], r, r, 200, 340, INK, w)
    # its iris, low on the dome, the pupil turned toward the lit window
    ic, ir = (560, 540), 150
    pc, pr = (620, 566), 46
    p.ell(ic[0], ic[1], ir + 12, ir + 12, SURF_RIM, INK, 3.4)
    p.ell(ic[0], ic[1], ir - 8, ir - 8, SURF_IRIS, INK, 2.8)
    for k in range(1, 5):
        t = k / 5
        rr = lerp(ir - 8, pr + 6, t)
        cc = (lerp(ic[0], pc[0], t), lerp(ic[1], pc[1], t))
        p.ell(cc[0], cc[1], rr, rr, None, mix(SURF_IRIS, SURF_IRIS_RING, 1 - 0.5 * t), 2.4)
    p.ell(pc[0], pc[1], pr, pr, SURF_PUPIL, INK, 3.0)
    # the sea: mid storm navy, flat chop
    p.vgrad(-4, hor, W + 4, H + 4, mix(STORM, SEAGLASS, 0.45), mix(STORM, BULK, 0.6))
    chop = p.layer()
    for _ in range(90):
        x, y = rng.uniform(-20, W), rng.uniform(hor + 12, H)
        L = rng.uniform(30, 90) * (0.5 + (y - hor) / 400)
        chop.line([(x, y), (x + L * 0.5, y - 4), (x + L, y)], mix(SEAGLASS, PAPER, 0.15), 2)
    p.put(chop, 0.5)
    p.line([(-4, hor), (W + 4, hor)], INK, 2.6)
    # the station: house, lantern tower, deck and piles; flat navy, ink contours
    st = mix(STORM, BULK, 0.55)
    st_hi = mix(st, SEAGLASS, 0.35)
    for x in range(780, 1000, 30):
        p.rect(x, 690, x + 9, 812, mix(st, INK, 0.3), INK, 2)
    p.line([(770, 740), (1000, 760)], INK, 2.4)
    p.line([(770, 760), (1000, 740)], INK, 2.4)
    p.rect(740, 680, 1030, 694, st, INK, 2.6)                       # deck
    for x in range(746, 1030, 22):
        p.line([(x, 662), (x, 680)], INK, 1.8)
    p.line([(740, 662), (1030, 662)], INK, 2.2)                     # rail
    p.rect(780, 560, 980, 680, st, INK, 2.8)                        # house
    p.poly([(766, 562), (880, 500), (994, 562)], st, INK, 2.8)       # roof
    p.line([(782, 560), (880, 506), (978, 560)], st_hi, 1.6)
    p.rect(940, 430, 980, 548, st, INK, 2.6)                        # tower
    p.rect(930, 400, 990, 432, mix(st, SEAGLASS, 0.2), INK, 2.4)    # lantern
    p.poly([(926, 402), (960, 380), (994, 402)], st, INK, 2.2)
    for wx, wy in ((800, 600), (830, 600), (920, 600), (950, 600), (800, 640), (950, 640)):
        p.rect(wx, wy, wx + 16, wy + 14, mix(st, BLACK, 0.35), INK, 1.6)
    # the chamber's window: the one light
    glow(p, 875, 614, 60, AMBER, 0.55)
    p.rect(866, 608, 884, 621, None, INK, 2)
    p.rect(868, 610, 882, 619, AMBER, None)
    p.rect(869, 611, 881, 613, AMBER_HI, None)
    return p


def paint_end_b_cover(rng):
    p = Pen(W, H, rng, mix(IRON, BLACK, 0.3))
    lay = p.layer()
    for _ in range(26):
        lay.ell(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(100, 260), rng.uniform(60, 140), IRON, None)
    p.put_soft(lay, 50, 0.45)
    p.rect(120, 220, 1328, 640, IRON, INK, 3, 8)
    p.line([(130, 230), (1318, 230)], IRON_HI, 2)
    # the strip runs left to right under the head
    p.rect(224, 360, 1224, 520, PAPER_HI, INK, 2.6)
    for y in (400, 440, 480):
        p.line([(240, y), (1208, y)], mix(PAPER, SEAGLASS, 0.3), 1.2)
    p.rect(200, 350, 224, 530, BRASS_LO, INK, 2.2, 4)
    p.rect(1224, 350, 1248, 530, BRASS_LO, INK, 2.2, 4)
    # the print head: a brass carriage on a rail, its stylus resting on the strip
    p.rect(160, 284, 1290, 300, BRASS_LO, INK, 2.4, 3)
    hx = 720
    sh = p.layer()
    sh.rect(hx - 70, 300, hx + 80, 380, BLACK, None)
    p.put_soft(sh, 8, 0.45)
    p.rect(hx - 80, 262, hx + 80, 340, BRASS, INK, 2.8, 6)
    p.line([(hx - 74, 268), (hx + 74, 268)], BRASS_HI, 1.8)
    p.rect(hx - 20, 340, hx + 20, 366, BRASS_DK, INK, 2.2, 2)
    p.poly([(hx - 8, 366), (hx + 8, 366), (hx, 378)], SOOT, INK, 1.6)
    for x in (hx - 56, hx + 56):
        screw(p, x, 300, 4.4)
    p.ell(hx, 300, 14, 14, BRASS_LO, INK, 2)
    for x in range(260, 1220, 120):
        p.rect(x, 560, x + 60, 600, mix(IRON, BLACK, 0.4), INK, 1.6, 3)
    return p


def paint_cover_sheet(rng):
    w, h = 700, 420
    p = Pen(w, h, rng)
    curl = 70
    sheet = [(6, 6), (w - 6, 6), (w - 6, h - 6 - curl), (w - 6 - curl, h - 6), (6, h - 6)]
    p.poly(sheet, PAPER_HI, INK, 2.6)
    for y in range(60, h - 20, 28):
        x1 = w - 30 if y < h - 6 - curl else w - 30 - (y - (h - 6 - curl)) - 10
        p.line([(30, y), (x1, y)], mix(PAPER, SEAGLASS, 0.45), 1.4)
    p.line([(70, 16), (70, h - 16)], mix(PAPER, VIOLET, 0.35), 1.4)
    p.rect(14, 14, w - 14, h - 14, None, None, 0)
    # the curl: the underside of the corner turned up toward us
    fold = [(w - 6, h - 6 - curl), (w - 6 - curl, h - 6), (w - 6 - curl * 0.9, h - 6 - curl * 0.9)]
    sh = p.layer()
    sh.poly([(w - 6, h - 6 - curl), (w - 6 - curl, h - 6), (w - 6 - curl * 1.1, h - 6 - curl * 0.6)], BLACK, None)
    p.put_soft(sh, 4, 0.3, mask=poly_mask((w, h), sheet))
    p.poly(fold, PAPER_LO, INK, 2.2)
    out = p.done()
    return grain(out, rng_for(5900), amp=4, mottle=4, speck=8)


# ============================================================================ wave 3: the wall of glass
# The surface fills the back wall: one wide pane between the side arches, from just under the deckhead
# pipe to just above the head cup of the armatures. The view draws it in place of a_surface at every
# stage (R12_view.gd GLASS); the lid band and the withdrawn margin are drawn by the view over it.
GLASS = (200, 86, 1248, 430)            # x0, y0, x1, y1: the pane, frame included
GLASS_FRAME = 12                        # the iron frame inside that rect
SURFW_TOP = mix(SEAGLASS, BULK, 0.35)   # flat sea-glass at the top ...
SURFW_BOT = mix(STORM, BULK, 0.25)      # ... to storm navy at the sill
WIDE_EYE_C, WIDE_EYE_R = (930, 290), 318    # off-centre right; cropped top and bottom by the pane
WIDE_PUPIL_C, WIDE_PUPIL_R = (792, 344), 78  # turned down and left, toward the chair


def foreground_mask():
    """What hangs in front of the glass in view_a (the conduit and the column, the caged lamp, the
    gauge): painted on a blank pen with the same calls, solid parts only, at 1x."""
    p = Pen(W, H, rng_for(0))
    column(p, rng_for(0))
    gauge(p)
    lamp = Pen(W, H, rng_for(0))
    caged_lamp(lamp, 250, 36)
    a = p.im.getchannel("A").point(lambda v: 255 if v > 24 else 0)
    b = lamp.im.getchannel("A").point(lambda v: 255 if v > 200 else 0)
    m = ImageChops.lighter(a, b).resize((W, H), Image.NEAREST)
    return m.filter(ImageFilter.MaxFilter(3))


def paint_surface_wide(rng):
    """The surface across the whole back wall: one flat sea-glass to storm-navy field, no horizon,
    no waves, nothing of the room in it; one huge ring eye in a few flat navy bands, off-centre and
    cropped by the pane so it is never seen whole. Transparent outside the glass."""
    x0, y0, x1, y1 = GLASS
    f = GLASS_FRAME
    p = Pen(W, H, rng)
    p.vgrad(x0, y0, x1, y1, SURFW_TOP, SURFW_BOT)
    inner = poly_mask((W, H), [(x0 + f, y0 + f), (x1 - f, y0 + f), (x1 - f, y1 - f), (x0 + f, y1 - f)])
    # the eye: four flat bands drawing in toward the pupil, each a step darker, each a little
    # further toward the chair; navy ink between them. Not a target: close values, eccentric.
    eye = p.layer()
    bands = (
        (1.00, mix(SURFW_TOP, STORM, 0.30)),
        (0.78, mix(SURFW_TOP, STORM, 0.52)),
        (0.56, mix(STORM, BULK, 0.35)),
    )
    for k, (s, col) in enumerate(bands):
        t = k / 3
        c = (lerp(WIDE_EYE_C[0], WIDE_PUPIL_C[0], t), lerp(WIDE_EYE_C[1], WIDE_PUPIL_C[1], t))
        r = WIDE_EYE_R * s
        eye.ell(c[0], c[1], r, r, col, INK, 3.2 if k == 0 else 2.6)
    eye.ell(WIDE_PUPIL_C[0], WIDE_PUPIL_C[1], WIDE_PUPIL_R, WIDE_PUPIL_R, mix(STORM, BLACK, 0.45), INK, 3.4)
    p.put(eye, mask=inner)
    # one thin pale rim on the outer band, upper left only: the light from the room catching it
    rim = p.layer()
    rim.arc(WIDE_EYE_C[0], WIDE_EYE_C[1], WIDE_EYE_R - 6, WIDE_EYE_R - 6, 196, 252,
            mix(SURFW_TOP, SEAGLASS_HI, 0.6), 2.4)
    p.put(rim, 0.8, mask=inner)
    # the frame: iron, inked, a brass bead inside, a deeper sill along the bottom
    fr = p.layer()
    fr.rect(x0, y0, x1, y1, IRON, INK, 3.0)
    p.put(fr, mask=ImageChops.subtract(poly_mask((W, H), [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]), inner))
    p.rect(x0 + f, y0 + f, x1 - f, y1 - f, None, INK, 2.6)
    p.rect(x0 + f - 3, y0 + f - 3, x1 - f + 3, y1 - f + 3, None, BRASS_LO, 1.6)
    p.line([(x0 + 2, y0 + 3), (x1 - 2, y0 + 3)], IRON_HI, 1.4)
    for x in range(int(x0) + 30, int(x1) - 10, 60):
        rivet(p, x, y0 + f / 2, 2.2, IRON_HI)
        rivet(p, x, y1 - f / 2, 2.2, IRON_HI)
    im = grain(p.done(), rng_for(2015), amp=4, mottle=4, speck=6)
    # transparent outside the glass, and wherever the room hangs in front of it
    a = im.getchannel("A")
    a = ImageChops.subtract(a, foreground_mask())
    im.putalpha(a)
    return im


# ============================================================================ wave 3: the field of stations
FIELD_SKY = (0x1D, 0x2A, 0x3A)
FIELD_SEA = (0x12, 0x1A, 0x22)
FIELD_SIL = (0x2A, 0x38, 0x46)
FIELD_WIN = (0x3A, 0x4A, 0x58)
FIELD_LIT = (0xE8, 0xC2, 0x7A)
FIELD_N = 450
FIELD_ROWS = 9
# The kitchen: one small station near the centre. Its window's centre (the view's glow) is
# FIELD_LIT_AT; R12_view.gd FIELD_GLOW matches it.
FIELD_HOME = (724, 600, 38)              # foot centre x, foot y (sea level), box width
FIELD_LIT_AT = (724, 573)


def station_shape(d, cx, base, w, body, win, lit=None):
    """A station in flat front elevation, at 1x: stilts into the sea, a box, a pitched roof, one
    window. `base` is where the stilts meet the water; `w` the box width in pixels."""
    w = max(3, int(round(w)))
    bh = max(2, int(round(w * 0.56)))           # box
    rh = max(1, int(round(w * 0.30)))           # roof
    sh = max(1, int(round(w * 0.42)))           # stilts
    x0 = int(round(cx - w / 2))
    x1 = x0 + w - 1
    by1 = int(round(base)) - sh
    by0 = by1 - bh + 1
    # stilts: three at w >= 9, two below
    legs = 3 if w >= 9 else 2
    lw = max(1, int(round(w * 0.07)))
    for i in range(legs):
        lx = int(round(lerp(x0 + 1, x1 - 1 - (lw - 1), i / (legs - 1))))
        d.rectangle((lx, by1 + 1, lx + lw - 1, int(round(base))), fill=body)
    if w >= 14:   # a cross-brace between the outer stilts
        d.line((x0 + 1, by1 + 2, x1 - 1, int(round(base)) - 1), fill=body, width=max(1, lw // 2))
        d.line((x0 + 1, int(round(base)) - 1, x1 - 1, by1 + 2), fill=body, width=max(1, lw // 2))
    d.rectangle((x0, by0, x1, by1), fill=body)
    over = max(1, int(round(w * 0.08)))
    d.polygon([(x0 - over, by0), ((x0 + x1) / 2, by0 - rh), (x1 + over, by0)], fill=body)
    # the window: a rectangle, at least 1x1, centred in the box, a little above the middle
    ww = max(1, int(round(w * 0.22)))
    wh = max(1, int(round(bh * 0.36)))
    wx = int(round((x0 + x1) / 2 - (ww - 1) / 2))
    wy = int(round(by0 + (bh - wh) * 0.4))
    d.rectangle((wx, wy, wx + ww - 1, wy + wh - 1), fill=lit if lit else win)
    return (wx, wy, wx + ww - 1, wy + wh - 1), (x0 - over - 1, by0 - rh - 1, x1 + over + 1, int(round(base)) + 1)


def field_layout(rng):
    """FIELD_N stations in FIELD_ROWS rough perspective rows: [(cx, base, w)], back rows first.
    Each row is smaller than the one in front of it, down to a few pixels at the back."""
    fronts = []
    # row 0 is the back. Sizes fall geometrically from the front (40 px) to the back (~3 px).
    sizes = [40.0 * (0.72 ** (FIELD_ROWS - 1 - i)) for i in range(FIELD_ROWS)]
    ys = [lerp(470, 1040, (i / (FIELD_ROWS - 1)) ** 1.35) for i in range(FIELD_ROWS)]
    weights = [1.0 / (s ** 0.55) for s in sizes]
    total = sum(weights)
    counts = [max(8, int(round(FIELD_N * wgt / total))) for wgt in weights]
    while sum(counts) > FIELD_N:
        counts[counts.index(max(counts))] -= 1
    while sum(counts) < FIELD_N:
        counts[counts.index(max(counts))] += 1
    hx, hy, hw = FIELD_HOME
    for i in range(FIELD_ROWS):
        n, s, y = counts[i], sizes[i], ys[i]
        span = W + 2 * s
        step = span / n
        ph, amp = rng.uniform(0, math.tau), rng.uniform(0.6, 1.4) * s
        for k in range(n):
            cx = -s + step * (k + 0.5) + rng.uniform(-0.38, 0.38) * step
            # a rough row: a slow swell along it, and each station a little off it
            base = y + amp * math.sin(cx / 260.0 + ph) + rng.uniform(-0.9, 0.9) * s * 0.7
            w = s * rng.uniform(0.9, 1.1)
            # keep a clear berth round the kitchen station so it reads alone
            if abs(cx - hx) < hw * 1.1 + w and abs(base - hy) < hw * 1.3 + w * 0.8:
                cx = hx + math.copysign(hw * 1.1 + w + rng.uniform(4, 30), cx - hx if cx != hx else 1)
            fronts.append((cx, base, w))
    return fronts


def paint_end_b_field(rng):
    """CONTINUE, the wide plate at night. Storm-navy sky darkening straight into the sea (no
    horizon line); the ring eye, enormous, cropped by the top edge, faint; and the kitchen --
    one small station near the centre with the only warm window in the frame -- among FIELD_N
    identical stations in rough rows going back, every window unlit."""
    p = Pen(W, H, rng)
    p.vgrad(-4, -4, W + 4, 640, FIELD_SKY, FIELD_SEA)
    p.rect(-4, 639, W + 4, H + 4, FIELD_SEA, None)
    # the eye behind everything: a few flat navy bands, centre above the frame, at 0.25
    eye = p.layer()
    ec, er = (690, -260), 1180
    pc = (650, 40)
    for k, (s, col) in enumerate(((1.00, (0x2E, 0x40, 0x52)), (0.80, (0x0E, 0x16, 0x1E)),
                                  (0.62, (0x26, 0x36, 0x46)), (0.46, (0x0A, 0x10, 0x16)))):
        t = k / 4
        c = (lerp(ec[0], pc[0], t), lerp(ec[1], pc[1], t))
        eye.ell(c[0], c[1], er * s, er * s, col, INK, 3.0)
    eye.ell(pc[0], pc[1] + 60, 300, 300, (0x06, 0x0A, 0x0E), INK, 3.0)
    p.put(eye, 0.25)
    im = grain(p.done(), rng_for(7080), amp=3, mottle=3, speck=4).convert("RGB")
    # the stations, crisp at 1x, back rows first
    d = ImageDraw.Draw(im)
    for cx, base, w in field_layout(random.Random(SEED + 7081)):
        station_shape(d, cx, base, w, FIELD_SIL, FIELD_WIN)
    hx, hy, hw = FIELD_HOME
    station_shape(d, hx, hy, hw, FIELD_SIL, FIELD_WIN, lit=FIELD_LIT)
    return im


# ============================================================================ fix p1: the eye, previews, ending pages
# Everything below writes NEW files only (assets/rooms/R12/a_surface_eye.png, c_routing_preview.png,
# a_prev_*.png and assets/stages/R12/*.png); the approved plates above are untouched.

GLASS_IN = (212, 98, 1024, 320)          # x, y, w, h: the water inside the pane (R12_view.gd GLASS_IN)
# The eye: centred over the wide plate's painted pupil, so the old one never shows past the new
# iris at any gaze offset (R12_view.gd moves this overlay by R12Sim.PUPIL_OFFSET, at most 40 px).
EYE_C = (792, 280)                       # canvas coordinates
EYE_IRIS_R = 156
EYE_PUPIL_R = 54
EYE_RIM = (0xA9, 0xC8, 0xB8)             # sea-glass rim, 4 px
EYE_PUPIL = (0x07, 0x0B, 0x0F)           # flat near-black
EYE_WIN = (0xD2, 0xAA, 0x66)             # a lit station window, 3 x 2 px
EYE_FIELD = mix(SEAGLASS, STORM, 0.52)   # the iris: flat, a step under the surface round it
EYE_RINGS = ((140, 40), (118, 32), (98, 25), (80, 19))   # (radius, stations): receding inward


def paint_surface_eye(rng):
    """The eye in the window, GLASS_IN-sized (1024 x 320): a flat iris with a 4 px sea-glass rim,
    four rings of tiny lit station windows drawing in toward a flat near-black pupil, one brass
    catchlight. Transparent outside the iris. Every station it holds is lit."""
    gx, gy, gw, gh = GLASS_IN
    cx, cy = EYE_C[0] - gx, EYE_C[1] - gy
    p = Pen(gw, gh, rng)
    p.ell(cx, cy, EYE_IRIS_R, EYE_IRIS_R, EYE_FIELD, None)
    # each ring a step darker toward the pupil, with a thin navy waterline under its stations
    for k, (r, n) in enumerate(EYE_RINGS):
        p.ell(cx, cy, r + 8, r + 8, mix(EYE_FIELD, STORM, 0.12 + 0.12 * k), None)
        p.arc(cx, cy, r, r, 0, 360, mix(INK, STORM, 0.3), 1.6)
    p.ell(cx, cy, EYE_PUPIL_R, EYE_PUPIL_R, EYE_PUPIL, None)
    p.ell(cx, cy, EYE_IRIS_R - 2, EYE_IRIS_R - 2, None, EYE_RIM, 4.0)
    im = p.done()
    # the stations, crisp at 1x: a small navy body on each ring's line, its window lit
    d = ImageDraw.Draw(im)
    for k, (r, n) in enumerate(EYE_RINGS):
        ph = rng.uniform(0, math.tau)
        body = 7 - k                          # 7, 6, 5, 4 px: further rings, smaller stations
        for i in range(n):
            a = ph + math.tau * (i + rng.uniform(-0.28, 0.28)) / n
            x = cx + r * math.cos(a)
            y = cy + r * math.sin(a)
            bx, by = int(round(x - body / 2)), int(round(y - body))
            d.rectangle((bx, by, bx + body - 1, by + body - 2), fill=rgba(mix(STORM, BLACK, 0.3)))
            wx, wy = int(round(x - 1.5)), int(round(y - body + 2))
            d.rectangle((wx, wy, wx + 2, wy + 1), fill=rgba(EYE_WIN))
    # one brass catchlight on the pupil's upper left
    q = Pen(gw, gh, rng)
    q.ell(cx - 24, cy - 26, 9, 6, BRASS_HI, None)
    im.alpha_composite(q.done())
    return im


# ----------------------------------------------------------------------------- P26 previews
def paint_c_routing_preview(rng):
    """c_routing for 'preview both routes': the two plates and their PREVIEW keys only. No card
    slots, no consequence tray, no CONFIRM button: the window shows what each route does."""
    p = Pen(W, H, rng)
    closeup_ground(p, rng)
    for x0 in (110, 798):
        sh = p.layer()
        sh.rect(x0 - 10, 90, x0 + 550, 604, BLACK, None)
        p.put_soft(sh, 12, 0.3)
        p.rect(x0 - 20, 80, x0 + 560, 600, BRASS, INK, 3.2, 6)
        p.line([(x0 - 15, 595), (x0 - 15, 85), (x0 + 555, 85)], BRASS_HI, 2.4)
        p.line([(x0 - 14, 595), (x0 + 555, 595), (x0 + 555, 86)], BRASS_DK, 2.4)
        lay = p.layer()
        for _ in range(14):
            x = rng.uniform(x0, x0 + 540)
            lay.rect(x, rng.uniform(100, 480), x + rng.uniform(5, 10), 590, VERD, None, r=3)
        p.put_soft(lay, 3, 0.3, mask=poly_mask((W, H), [(x0 - 20, 80), (x0 + 560, 80), (x0 + 560, 600), (x0 - 20, 600)]))
        enamel_plate(p, x0, 100, x0 + 540, 460)
        for (sx, sy) in ((x0 - 6, 94), (x0 + 546, 94), (x0 - 6, 586), (x0 + 546, 586)):
            screw(p, sx, sy, 4.4)
    for (kx, ky) in ((260, 470), (948, 470)):
        p.rect(kx, ky, kx + 240, ky + 90, BRASS_LO, INK, 2.6, 44)
        cx, cy = kx + 120, ky + 45
        p.ell(cx, cy, 36, 36, BRASS, INK, 2.6)
        p.arc(cx, cy, 31, 31, 200, 290, BRASS_HI, 2.2)
        p.ell(cx, cy, 12, 12, BRASS_DK, None)
        for sx in (kx + 26, kx + 214):
            screw(p, sx, cy, 4.4)
    # a riveted iron band under the plates where the tray was: bare, nothing to hand
    p.rect(40, 700, 1408, 740, IRON, INK, 2.6, 4)
    p.line([(46, 704), (1402, 704)], IRON_HI, 1.6)
    for x in range(70, 1400, 90):
        rivet(p, x, 720, 3.0, IRON_HI)
    return p


# The previews in the window, each GLASS_IN-sized (local coordinates, origin at GLASS_IN's corner).
# R12_view.gd draws the lamps' state over them, so the painted portraits and bowls stay registered.
PREV_FRAME_X = [112 + 88 * i for i in range(8)]   # portrait centres
PREV_FRAME_Y = (46, 118)                          # portrait top, bottom
PREV_LAMP_Y = 30
PREV_BOWL_X = [100 + 80 * i for i in range(9)]
PREV_SHELF_Y = 236


def _prev_pen(rng):
    return Pen(GLASS_IN[2], GLASS_IN[3], rng)


def paint_prev_sever(rng, lit):
    """SEVER, shown in the window: the eight portrait frames with their lamps, and a strip of the
    kitchen's bowls on their shelf. `lit`: lamps burning and the bowls in warm light; else dark."""
    p = _prev_pen(rng)
    sitter = mix(STORM, BLACK, 0.2)
    for i, x in enumerate(PREV_FRAME_X):
        y0, y1 = PREV_FRAME_Y
        p.rect(x - 28, y0, x + 28, y1, BRASS if lit else BRASS_DK, INK, 2.4, 2)
        p.rect(x - 21, y0 + 7, x + 21, y1 - 7, PAPER if lit else mix(PAPER_LO, STORM, 0.55), INK, 1.8)
        # a head-and-shoulders sitter, flat
        p.ell(x, y0 + 30, 9, 11, sitter, None)
        p.poly([(x - 17, y1 - 7), (x - 14, y0 + 50), (x, y0 + 43), (x + 14, y0 + 50), (x + 17, y1 - 7)], sitter, None)
        # its lamp above, on a short bracket
        p.line([(x, PREV_LAMP_Y + 8), (x, y0)], INK, 2)
        if lit:
            glow(p, x, PREV_LAMP_Y, 26, AMBER_HI, 0.5)
            p.ell(x, PREV_LAMP_Y, 7, 7, AMBER, INK, 1.6)
            p.ell(x - 1.5, PREV_LAMP_Y - 1.5, 3.5, 3.5, AMBER_HI, None)
        else:
            p.ell(x, PREV_LAMP_Y, 7, 7, GLASS_DEAD, INK, 1.6)
    # the shelf of bowls
    if lit:
        lay = p.layer()
        lay.rect(60, PREV_SHELF_Y - 46, 780, PREV_SHELF_Y + 4, AMBER_HI, None)
        p.put_soft(lay, 14, 0.28)
    p.rect(60, PREV_SHELF_Y, 780, PREV_SHELF_Y + 10, TIMBER if lit else TIMBER_DK, INK, 2.2, 2)
    for x in PREV_BOWL_X:
        body = ENAMEL if lit else mix(ENAMEL_LO, STORM, 0.6)
        p.poly([(x - 26, PREV_SHELF_Y - 26), (x + 26, PREV_SHELF_Y - 26), (x + 18, PREV_SHELF_Y - 6),
                (x + 10, PREV_SHELF_Y), (x - 10, PREV_SHELF_Y), (x - 18, PREV_SHELF_Y - 6)], body, INK, 2.0)
        p.line([(x - 24, PREV_SHELF_Y - 22), (x + 24, PREV_SHELF_Y - 22)], SEAGLASS if lit else STORM, 2.4)
        if lit:
            p.line([(x - 8, PREV_SHELF_Y - 34), (x - 4, PREV_SHELF_Y - 44), (x - 8, PREV_SHELF_Y - 54)], PAPER_HI, 1.6)
    return p


PREV_RAIL = (120, 640, 150)               # x0, x1, y: the witness feed's rail (E.V. left, A.M. right)
PREV_COAT_X = 900                         # the oilskin's centre line, right of the conduit


def paint_prev_feed(rng):
    """CONTINUE, shown in the window: the witness feed's rail between two lamp sockets, each with a
    blank enamel label (the view writes E.V. and A.M. and draws the lamps and the moving feed)."""
    p = _prev_pen(rng)
    x0, x1, y = PREV_RAIL
    p.rect(x0 - 40, y - 34, x1 + 40, y + 60, mix(STORM, BULK, 0.5), INK, 2.6, 4)
    p.rect(x0, y - 4, x1, y + 4, BRASS_LO, INK, 1.8, 2)
    for x in (x0, x1):
        p.ell(x, y, 18, 18, BRASS, INK, 2.2)
        p.ell(x, y, 12, 12, GLASS_DEAD, INK, 1.6)
        enamel_plate(p, x - 34, y + 26, x + 34, y + 50)
    return p


def paint_prev_oilskin(rng):
    """CONTINUE: Venn's oilskin on its hook in the window, empty. The hood open on nothing, the
    front hanging open on a dark inside, the sleeves flat."""
    p = _prev_pen(rng)
    cx = PREV_COAT_X
    coat = mix(SOOT, STORM, 0.45)
    hollow = mix(BLACK, STORM, 0.25)
    p.rect(cx - 6, 8, cx + 6, 22, BRASS, INK, 1.6, 2)                         # the hook
    p.poly([(cx, 20), (cx - 46, 44), (cx - 62, 110), (cx - 70, 300), (cx + 70, 300), (cx + 62, 110), (cx + 46, 44)],
           coat, INK, 2.6)
    p.poly([(cx - 62, 110), (cx - 84, 270), (cx - 64, 278), (cx - 50, 130)], mix(coat, INK, 0.2), INK, 2.0)
    p.poly([(cx + 62, 110), (cx + 84, 270), (cx + 64, 278), (cx + 50, 130)], mix(coat, INK, 0.2), INK, 2.0)
    # the hood, open toward us, nobody in it
    p.ell(cx, 46, 30, 30, coat, INK, 2.4)
    p.ell(cx, 50, 20, 22, hollow, INK, 1.8)
    # the open front: a long dark gap where a body would be
    p.poly([(cx - 10, 76), (cx + 10, 76), (cx + 26, 300), (cx - 26, 300)], hollow, INK, 2.0)
    for (dx, dy) in ((-40, 312), (14, 318)):
        p.ell(cx + dx, dy, 2.5, 4, mix(SEAGLASS_HI, PAPER_HI, 0.4), None)
    return p


# ----------------------------------------------------------------------------- ending pages
HAND_BROWN = (138, 112, 90)              # matte restrained brown, her hand
SLEEVE_BROWN = TIMBER                    # her sleeve, a step darker


def _crop_filter(m, size):
    bb = m.getbbox()
    if not bb:
        return m
    pad = size
    box = (max(0, bb[0] - pad), max(0, bb[1] - pad), min(m.size[0], bb[2] + pad), min(m.size[1], bb[3] + pad))
    out = Image.new("L", m.size, 0)
    out.paste(m.crop(box).filter(ImageFilter.MaxFilter(size)), box[:2])
    return out


def brown_hand(p, sleeve_from, wrist, ang, k=1.0, arm_w=64, lift=0.0, ink_w=3.0):
    """Her hand and sleeve in matte restrained brown with navy ink contours, the sleeve coming in
    from `sleeve_from` (below the bottom edge) to the wrist. Returns the 1x coverage mask."""
    hand = hand_mask((p.w, p.h), wrist, wrist, ang, k=k, arm_w=arm_w * 0.82, lift=lift)
    ring = _crop_filter(hand, 2 * int(ink_w * SS) + 1)
    stamp(p, ring, INK)
    stamp(p, hand, HAND_BROWN)
    # the sleeve: a tapering band from off the bottom edge to just past the wrist, cuff inked
    dx, dy = wrist[0] - sleeve_from[0], wrist[1] - sleeve_from[1]
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux
    end = (wrist[0] - ux * 6 * k, wrist[1] - uy * 6 * k)
    w0, w1 = arm_w * 0.62, arm_w * 0.5
    pts = [(sleeve_from[0] + nx * w0, sleeve_from[1] + ny * w0), (end[0] + nx * w1, end[1] + ny * w1),
           (end[0] - nx * w1, end[1] - ny * w1), (sleeve_from[0] - nx * w0, sleeve_from[1] - ny * w0)]
    p.poly(pts, SLEEVE_BROWN, INK, ink_w)
    cuff = (end[0] - ux * 22 * k, end[1] - uy * 22 * k)
    p.line([(cuff[0] + nx * w1 * 1.02, cuff[1] + ny * w1 * 1.02), (cuff[0] - nx * w1 * 1.02, cuff[1] - ny * w1 * 1.02)], INK, 2.2)
    m = Image.new("L", (p.w * SS, p.h * SS), 0)
    ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    return ImageChops.lighter(m, ring).resize((p.w, p.h), Image.NEAREST)


def grey_daylight(im):
    """The office in grey daylight: half its colour gone, lifted toward an overcast grey."""
    rgb = im.convert("RGB")
    grey = rgb.convert("L").convert("RGB")
    out = Image.blend(rgb, grey, 0.45)
    return Image.blend(out, Image.new("RGB", rgb.size, (196, 202, 200)), 0.14)


OFFICE_PLATE = os.path.join(ROOT, "assets", "backgrounds", "office_arrival.png")
DESK_TOP = 724                           # the office desk's top edge in the approved elevation


def paint_sever_office(rng):
    """SEVER, page 09: the approved R02 elevation (composited, not redrawn) in grey daylight, the
    wet coat drooping on the seventh hook where it always hung; on the desk the corrected record is
    lifted half off the blotter by her hand, and a pencil on it is already writing."""
    base = grey_daylight(Image.open(OFFICE_PLATE)).convert("RGBA")
    p = Pen(W, H, rng)
    # the record: a sheet rising from its corner on the desk, tilted back toward her hand
    bl = (330, DESK_TOP)
    ang = math.radians(25)
    wv = (200 * math.cos(ang), -200 * math.sin(ang))
    hv = (-150 * math.sin(ang), -150 * math.cos(ang))
    def at(u, v):
        return (bl[0] + wv[0] * u + hv[0] * v, bl[1] + wv[1] * u + hv[1] * v)
    sh = p.layer()
    sh.poly([at(0.02, -0.02), at(1.04, -0.02), at(1.04, 0.9), at(0.02, 0.9)], BLACK, None)
    p.put_soft(sh, 6, 0.25)
    p.poly([at(0, 0), at(1, 0), at(1, 1), at(0, 1)], PAPER_HI, INK, 2.4)
    for j in range(7):
        v = 0.82 - j * 0.1
        p.line([at(0.08, v), at(0.88 if j % 3 else 0.6, v)], mix(PAPER, INK, 0.45), 1.6)
    # the pencil, upright on the page, its fresh line trailing from the point
    tip = at(0.42, 0.14)
    line = [at(0.08, 0.14)]
    for s in range(1, 14):
        u = 0.08 + 0.34 * s / 13
        line.append(at(u, 0.14 + 0.025 * math.sin(s * 1.9)))
    p.line(line, PENCIL_GREY, 2.0)
    top = (tip[0] + 34, tip[1] - 118)
    strap(p, [(tip[0] + 6, tip[1] - 20), top], 14, AMBER, INK, 2.0, hi=AMBER_HI)
    p.poly([(tip[0] + 6 - 7, tip[1] - 20 + 2), (tip[0] + 6 + 7, tip[1] - 20 - 2), tip], PAPER, INK, 1.6)
    p.ell(tip[0] + 1, tip[1] - 4, 2.2, 2.2, SOOT, None)
    p.rect(top[0] - 6, top[1] - 14, top[0] + 10, top[1] + 2, mix(PAPER, INK, 0.3), INK, 1.4)
    # her hand under the lifted edge, from the bottom of the frame
    mask = brown_hand(p, (650, 1140), (566, 676), -124, k=0.9, arm_w=72, lift=0.55)
    base.alpha_composite(p.done())
    return base, mask


PENCIL_GREY = (85, 88, 94)


def paint_continue_terminal(rng):
    """CONTINUE, pages 04 and 06: end_b_terminal's strip and lamp exactly as before, without the
    black arm: her hand in from the bottom edge, holding the pencil to the strip."""
    p = Pen(W, H, rng, IRON)
    lay = p.layer()
    for _ in range(30):
        lay.ell(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(100, 260), rng.uniform(60, 140), IRON_HI, None)
    p.put_soft(lay, 50, 0.35)
    p.rect(60, 120, 1388, 960, mix(IRON, BULK, 0.4), INK, 3, 10)
    p.line([(70, 130), (1378, 130)], IRON_HI, 2)
    for (sx, sy) in ((84, 144), (1364, 144), (84, 936), (1364, 936)):
        screw(p, sx, sy, 6)
    p.rect(176, 276, 1272, 300, BLACK, INK, 2.4, 3)
    p.rect(160, 262, 1288, 278, BRASS, INK, 2.4, 3)
    p.rect(200, 300, 1248, 520, PAPER_HI, INK, 2.6)
    for y in (350, 400, 450):
        p.line([(220, y), (1228, y)], mix(PAPER, SEAGLASS, 0.3), 1.2)
    sh = p.layer()
    sh.rect(200, 300, 1248, 318, BLACK, None)
    p.put_soft(sh, 6, 0.35, mask=poly_mask((W, H), [(200, 300), (1248, 300), (1248, 520), (200, 520)]))
    lamp_socket(p, 1180, 240, 16, lit=True)
    enamel_plate(p, 1220, 228, 1300, 252)
    # her hand, in from the bottom edge, the pencil in it, its point at the strip's lower margin
    mask = brown_hand(p, (1230, 1140), (1112, 690), -128, k=0.95, arm_w=72, lift=0.7)
    tip = (1052, 512)
    back = (1136, 618)
    strap(p, [(tip[0] + 10, tip[1] + 14), back], 15, AMBER, INK, 2.0, hi=AMBER_HI)
    p.poly([(tip[0] + 10 - 7, tip[1] + 14 + 5), (tip[0] + 10 + 7, tip[1] + 14 - 5), tip], PAPER, INK, 1.6)
    p.ell(tip[0] + 2, tip[1] + 3, 2.4, 2.4, SOOT, None)
    p.rect(back[0] - 6, back[1] - 6, back[0] + 14, back[1] + 14, mix(PAPER, INK, 0.3), INK, 1.4)
    return p, mask


# ----------------------------------------------------------------------------- CONTINUE, the last wide
WIDE2_SKY_TOP = (0x5E, 0x72, 0x7C)
WIDE2_SKY_LOW = (0x7A, 0x8C, 0x90)
WIDE2_SEA_FAR = (0x4C, 0x5E, 0x68)
WIDE2_SEA_NEAR = (0x34, 0x44, 0x50)
WIDE2_SIL = (0x1E, 0x2A, 0x36)            # every unlit station: flat navy
WIDE2_WIN = (0x34, 0x42, 0x4E)            # its dead window
WIDE2_LIT = (0xF2, 0xD0, 0x8A)            # the kitchen: the brightest point in the frame
WIDE2_HOR = 430
WIDE2_ROWS = 7
WIDE2_HOME = (724, 690, 64)              # foot centre x, foot y, box width: the kitchen station


def wide2_layout(rng):
    """Stations in WIDE2_ROWS rows from the horizon to the foreground: [(cx, base, w)], back first.
    Fewer and larger than the old field, so each reads as a station at 1024x768."""
    out = []
    sizes = [16.0 * (1.42 ** i) for i in range(WIDE2_ROWS)]          # 16 .. ~131 px
    ys = [lerp(WIDE2_HOR + 14, 1060, (i / (WIDE2_ROWS - 1)) ** 1.25) for i in range(WIDE2_ROWS)]
    hx, hy, hw = WIDE2_HOME
    for i in range(WIDE2_ROWS):
        s, y = sizes[i], ys[i]
        step = s * rng.uniform(2.1, 2.5)
        x = -s + rng.uniform(0, step)
        while x < W + s:
            cx = x + rng.uniform(-0.2, 0.2) * step
            base = y + rng.uniform(-0.25, 0.25) * s
            w = s * rng.uniform(0.92, 1.08)
            clear = abs(cx - hx) > hw * 1.1 + w * 0.7 or abs(base - hy) > hw * 1.5 + w
            if clear:
                out.append((cx, base, w))
            x += step
    return out


def paint_end_b_wide_2(rng):
    """CONTINUE's last wide plate, lit for the eye: a pale overcast night sky and a mid-navy sea,
    the stations as stark flat navy silhouettes in rows back to the horizon, every window dead but
    one, the kitchen's, the brightest point in the frame. The ring eye stays in the sky, faint."""
    p = Pen(W, H, rng)
    p.vgrad(-4, -4, W + 4, WIDE2_HOR, WIDE2_SKY_TOP, WIDE2_SKY_LOW)
    p.vgrad(-4, WIDE2_HOR, W + 4, H + 4, WIDE2_SEA_FAR, WIDE2_SEA_NEAR)
    eye = p.layer()
    ec = (690, -120)
    for k, (s, col) in enumerate(((1.0, mix(WIDE2_SKY_TOP, STORM, 0.25)), (0.78, mix(WIDE2_SKY_TOP, STORM, 0.4)),
                                  (0.56, mix(WIDE2_SKY_TOP, STORM, 0.55)))):
        eye.ell(ec[0], ec[1] + 40 * k, 520 * s, 520 * s, col, INK, 2.6)
    eye.ell(ec[0], ec[1] + 150, 120, 120, mix(STORM, BLACK, 0.3), INK, 2.6)
    p.put(eye, 0.55, mask=poly_mask((W, H), [(0, 0), (W, 0), (W, WIDE2_HOR), (0, WIDE2_HOR)]))
    p.line([(-4, WIDE2_HOR), (W + 4, WIDE2_HOR)], INK, 2.2)
    chop = p.layer()
    for _ in range(70):
        x, y = rng.uniform(-20, W), rng.uniform(WIDE2_HOR + 10, H)
        L = rng.uniform(20, 70) * (0.4 + (y - WIDE2_HOR) / 500)
        chop.line([(x, y), (x + L * 0.5, y - 3), (x + L, y)], mix(WIDE2_SEA_FAR, SEAGLASS_HI, 0.3), 1.6)
    p.put(chop, 0.45)
    im = grain(p.done(), rng_for(12090), amp=3, mottle=3, speck=4).convert("RGB")
    d = ImageDraw.Draw(im)
    stations = wide2_layout(random.Random(SEED + 12091))
    hx, hy, hw = WIDE2_HOME
    home_drawn = False
    for cx, base, w in stations:
        if not home_drawn and base > hy:
            win, _ = station_shape(d, hx, hy, hw, WIDE2_SIL, WIDE2_WIN, lit=WIDE2_LIT)
            home_drawn = True
        station_shape(d, cx, base, w, WIDE2_SIL, WIDE2_WIN)
    if not home_drawn:
        station_shape(d, hx, hy, hw, WIDE2_SIL, WIDE2_WIN, lit=WIDE2_LIT)
    return im


def wide2_lit_at():
    """The kitchen window's centre in end_b_wide_2 (R12_view.gd WIDE2_GLOW matches it)."""
    d = ImageDraw.Draw(Image.new("RGB", (W, H)))
    hx, hy, hw = WIDE2_HOME
    win, _ = station_shape(d, hx, hy, hw, WIDE2_SIL, WIDE2_WIN, lit=WIDE2_LIT)
    return ((win[0] + win[2]) / 2, (win[1] + win[3]) / 2)


# ============================================================================ fix p2: the eye r3, the night field, the names
# New files only: assets/rooms/R12/a_surface_eye_r3.png, a_pupil_r3.png and
# assets/stages/R12/end_b_wide_3.png, r12_sever_office_r2.png. Nothing above changes.

# The eye r3: one flat surface field the size of the glass plus the room the gaze moves it
# through (R12Sim.PUPIL_OFFSET: x +-150, y up to 40, then x1.15 after P26), so the wide plate's
# painted rings never show past it; the iris fills the full GLASS_IN height.
EYE3_PAD = (190, 90)                                   # canvas margin round GLASS_IN, x and y
EYE3_SIZE = (GLASS_IN[2] + 2 * EYE3_PAD[0], GLASS_IN[3] + 2 * EYE3_PAD[1])   # 1404 x 500
EYE3_C = (EYE3_SIZE[0] / 2, EYE3_SIZE[1] / 2)          # the eye's centre: the canvas centre
EYE3_R = GLASS_IN[3] / 2                               # 160: the iris is as tall as the water
EYE3_IRIS = (0x5F, 0x8F, 0x86)                         # sea-glass
EYE3_LIMBUS = mix(STORM, INK, 0.4)                     # the dark ring at the iris edge
EYE3_RINGS = ((EYE3_R - 9, 13.0), (112, 3.2), (74, 2.4))   # (radius, width): solid, concentric
EYE3_VEIN = mix(INK, STORM, 0.35)
PUPIL3_SIZE = (260, 70)                                # the slit, plate px
PUPIL3_PAD = 6


def paint_surface_eye_r3(rng):
    """The eye in the window, r3: the surface field (flat sea-glass to storm navy, the wide plate's
    gradient registered to the glass) with two huge faint inked bands round a sea-glass iris that
    fills the water top to bottom. Navy radial veins, three solid concentric rings, no stations,
    no glint, no pupil (a_pupil_r3 is its own sprite, so it can move)."""
    w, h = EYE3_SIZE
    gx, gy = GLASS_IN[0] - EYE3_PAD[0], GLASS_IN[1] - EYE3_PAD[1]     # canvas origin in the room
    p = Pen(w, h, rng)
    # the field: SURFW_TOP at the pane's top (y 86) to SURFW_BOT at its sill (y 430), held past both
    top_t = (gy - GLASS[1]) / (GLASS[3] - GLASS[1])
    bot_t = (gy + h - GLASS[1]) / (GLASS[3] - GLASS[1])
    c_top = mix(SURFW_TOP, SURFW_BOT, max(0.0, min(1.0, top_t)))
    c_bot = mix(SURFW_TOP, SURFW_BOT, max(0.0, min(1.0, bot_t)))
    p.rect(-4, -4, w + 4, GLASS[1] - gy, c_top, None)
    p.vgrad(-4, GLASS[1] - gy, w + 4, GLASS[3] - gy, SURFW_TOP, SURFW_BOT)
    p.rect(-4, GLASS[3] - gy, w + 4, h + 4, c_bot, None)
    cx, cy = EYE3_C
    # two vast bands round it, a step darker each, inked: the eye is bigger than the window
    for rr, t in ((EYE3_R + 250, 0.16), (EYE3_R + 120, 0.30)):
        p.ell(cx, cy, rr, rr, mix(SURFW_TOP, STORM, t), INK, 2.6)
    p.ell(cx, cy, EYE3_R + 34, EYE3_R + 34, mix(SURFW_TOP, STORM, 0.42), INK, 2.6)
    # the iris
    p.ell(cx, cy, EYE3_R, EYE3_R, EYE3_IRIS, None)
    # radial veins: tapering navy strokes from near the pupil to the limbus, each a little bent
    veins = p.layer()
    n = 44
    for i in range(n):
        a = math.tau * (i + rng.uniform(-0.3, 0.3)) / n
        r0 = rng.uniform(40, 62)
        r1 = rng.uniform(EYE3_R - 30, EYE3_R - 12)
        bend = rng.uniform(-0.09, 0.09)
        pts = []
        for k in range(9):
            t = k / 8
            rr = lerp(r0, r1, t)
            aa = a + bend * math.sin(math.pi * t)
            pts.append((cx + rr * math.cos(aa), cy + rr * math.sin(aa)))
        for k in range(8):
            veins.line([pts[k], pts[k + 1]], EYE3_VEIN, lerp(2.6, 1.0, k / 7))
    p.put(veins, 0.7)
    # three solid concentric rings, the outer one the dark limbus
    for rr, wd in EYE3_RINGS:
        p.ell(cx, cy, rr, rr, None, EYE3_LIMBUS if wd > 6 else mix(EYE3_LIMBUS, EYE3_IRIS, 0.25), wd)
    p.ell(cx, cy, EYE3_R, EYE3_R, None, INK, 3.2)
    return grain(p.done(), rng_for(2420), amp=3, mottle=3, speck=4)


def paint_pupil_r3(rng):
    """The pupil, r3: a horizontal slit 260 x 70, flat near-black with a navy ink contour and a
    thin storm-navy inner rim. The view moves it, and puts the previews' lamps in it."""
    pw, ph = PUPIL3_SIZE
    w, h = pw + 2 * PUPIL3_PAD, ph + 2 * PUPIL3_PAD
    p = Pen(w, h, rng)
    cx, cy = w / 2, h / 2
    pts = []
    for i in range(73):
        a = math.tau * i / 72
        x, y = math.cos(a), math.sin(a)
        # a lens drawn to points at both ends: the half-height falls off toward the tips
        pts.append((cx + pw / 2 * x, cy + ph / 2 * y * (1 - 0.35 * abs(x) ** 3)))
    p.poly(pts, mix(STORM, BLACK, 0.2), INK, 3.0)
    inner = [(cx + (x - cx) * 0.9, cy + (y - cy) * 0.78) for x, y in pts]
    p.poly(inner, BLACK, None)
    return p


# CONTINUE's night field, r3: end_b_wide_2's composition (same layout, same kitchen) at night.
WIDE3_SKY_TOP = STORM                                   # #22303A
WIDE3_SKY_LOW = (0x2E, 0x40, 0x4C)
WIDE3_SEA_FAR = (0x1A, 0x26, 0x30)
WIDE3_SEA_NEAR = (0x12, 0x1A, 0x22)
WIDE3_SIL = (0x5D, 0x72, 0x80)                          # every station, lifted to read on the night
WIDE3_WIN = (0x1D, 0x2A, 0x3A)                          # every window dark ...
WIDE3_LIT = AMBER                                       # ... but the kitchen's, #C39959
WIDE3_EYE = ((1.00, (0x2A, 0x3A, 0x46)), (0.70, (0x33, 0x45, 0x52)), (0.42, (0x1A, 0x24, 0x2E)))


def paint_end_b_wide_3(rng, eye_y=-120):
    """CONTINUE's last page and end card, at night: a storm-navy sky with the concentric eye above
    (three solid bands, inked, a dark pupil), the stilt stations in rows to the horizon lifted to a
    pale slate so every one reads, every window dark but the kitchen's, lit amber with a small flat
    glow. The stations and the kitchen sit exactly where end_b_wide_2 has them (wide2_lit_at())."""
    p = Pen(W, H, rng)
    p.vgrad(-4, -4, W + 4, WIDE2_HOR, WIDE3_SKY_TOP, WIDE3_SKY_LOW)
    p.vgrad(-4, WIDE2_HOR, W + 4, H + 4, WIDE3_SEA_FAR, WIDE3_SEA_NEAR)
    eye = p.layer()
    ec = (690, eye_y)
    for k, (s, col) in enumerate(WIDE3_EYE):
        eye.ell(ec[0], ec[1] + 40 * k, 520 * s, 520 * s, col, INK, 3.0)
    eye.ell(ec[0], ec[1] + 150, 120, 120, mix(STORM, BLACK, 0.55), INK, 3.0)
    p.put(eye, mask=poly_mask((W, H), [(0, 0), (W, 0), (W, WIDE2_HOR), (0, WIDE2_HOR)]))
    p.line([(-4, WIDE2_HOR), (W + 4, WIDE2_HOR)], INK, 2.2)
    chop = p.layer()
    for _ in range(70):
        x, y = rng.uniform(-20, W), rng.uniform(WIDE2_HOR + 10, H)
        L = rng.uniform(20, 70) * (0.4 + (y - WIDE2_HOR) / 500)
        chop.line([(x, y), (x + L * 0.5, y - 3), (x + L, y)], mix(WIDE3_SEA_FAR, SEAGLASS, 0.35), 1.6)
    p.put(chop, 0.45)
    im = grain(p.done(), rng_for(12170), amp=3, mottle=3, speck=4).convert("RGB")
    d = ImageDraw.Draw(im)
    stations = wide2_layout(random.Random(SEED + 12091))   # end_b_wide_2's own layout
    hx, hy, hw = WIDE2_HOME
    home_drawn = False
    for cx, base, w in stations:
        if not home_drawn and base > hy:
            station_shape(d, hx, hy, hw, WIDE3_SIL, WIDE3_WIN, lit=WIDE3_LIT)
            home_drawn = True
        station_shape(d, cx, base, w, WIDE3_SIL, WIDE3_WIN)
    if not home_drawn:
        station_shape(d, hx, hy, hw, WIDE3_SIL, WIDE3_WIN, lit=WIDE3_LIT)
    # the kitchen's glow: a small flat disc of lamplight over its wall, then the window again on top
    gx, gy = wide2_lit_at()
    glow = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(((gx - 22) * SS, (gy - 22) * SS, (gx + 22) * SS, (gy + 22) * SS),
                                 fill=rgba(AMBER, 60))
    ImageDraw.Draw(glow).ellipse(((gx - 13) * SS, (gy - 13) * SS, (gx + 13) * SS, (gy + 13) * SS),
                                 fill=rgba(AMBER, 72))
    im = im.convert("RGBA")
    im.alpha_composite(glow.resize((W, H), Image.LANCZOS))
    im = im.convert("RGB")
    win, _ = station_shape(ImageDraw.Draw(Image.new("RGB", (W, H))), hx, hy, hw, WIDE3_SIL, WIDE3_WIN, lit=WIDE3_LIT)
    ImageDraw.Draw(im).rectangle(win, fill=WIDE3_LIT)
    return im


# SEVER's end still, r2: the drying page on the sill (end_a_page, same seeds, full colour) with
# the nine names in her hand down the ruled lines: eight, a gap, then Venn alone.
SEVER_NAMES = ["Bell", "Doane", "Hart", "Ives", "Lusk", "Pryce", "Rook", "Tull", None, "Venn"]
HAND_FONT = "/usr/share/fonts/truetype/noto/NotoSerif-Italic.ttf"   # Ink.hand(): Noto Serif italic
HAND_INK = (0x1F, 0x3F, 0x8A)                                       # Ink.BLUE_INK
HAND_SIZE = 30
HAND_SKEW = 0.18                                                    # Ink.HAND_SKEW


def hand_text(im, s, x, y, size, row, col=HAND_INK):
    """Her hand on `im` at 1x, baseline (x, y): glyph by glyph, each with Ink.handwriting's seeded
    jitter (dy +-2 px, a small turn) and its forward slant, rendered at 4x and set down smoothly."""
    from PIL import ImageFont
    k = 4
    font = ImageFont.truetype(HAND_FONT, size * k)
    asc, desc = font.getmetrics()
    g = random.Random(18 + row * 97)
    for ch in s:
        adv = font.getlength(ch) / k
        dy = g.uniform(-2.0, 2.0)
        turn = g.uniform(-3.4, 3.4)
        gw, gh = int(adv * k + size * k), asc + desc + size * k // 2
        m = Image.new("L", (gw, gh), 0)
        ImageDraw.Draw(m).text((size * k // 2, size * k // 4), ch, font=font, fill=255)
        # the slant: tops lean right about the baseline
        base = size * k // 4 + asc
        m = m.transform(m.size, Image.AFFINE, (1, HAND_SKEW, -HAND_SKEW * base, 0, 1, 0), resample=Image.BICUBIC)
        m = m.rotate(turn, resample=Image.BICUBIC, center=(size * k // 2, base))
        m = m.resize((gw // k, gh // k), Image.LANCZOS)
        ox = int(round(x - size / 2))
        oy = int(round(y + dy - base / k))
        solid = Image.new("RGB", m.size, col)
        im.paste(solid, (ox, oy), m)
        x += adv


def paint_sever_office_r2(rng):
    """SEVER's end still: the drying page in ordinary daylight (end_a_page, its own seeds, full
    colour), the names written down its ruled lines in her blue-black hand: eight in a column,
    one line left empty, then Venn alone."""
    im = grain(paint_end_a_page(rng).done(), rng_for(1000 + 703)).convert("RGB")
    # the page's ruled lines are at y = 280 + 34 k (paint_end_a_page); the margin rule at x 544
    for k, name in enumerate(SEVER_NAMES):
        if name:
            hand_text(im, name, 572, 280 + 34 * (k + 1) - 6, HAND_SIZE, k)
    return im


def checked_hand(painter, limit=1 / 6):
    """A page painted with brown_hand: asserts the sleeve and hand cover at most `limit` of the
    frame and enter from the bottom edge only (they touch no other edge)."""
    def run(rng):
        res, mask = painter(rng)
        im = res.done() if isinstance(res, Pen) else res
        cover = sum(1 for v in mask.getdata() if v > 127)
        assert cover <= W * H * limit, "hand covers %d px, over 1/%d of the frame" % (cover, round(1 / limit))
        bb = mask.getbbox()
        assert bb[3] >= H and bb[0] > 0 and bb[2] < W and bb[1] > 0, "the hand enters from the bottom edge only %s" % (bb,)
        return im
    return run


# ============================================================================ fix p3: new files only
# c_final, r2: the six panels hang FINAL_DY lower, in front of the sill of the eye's window (the
# view draws the eye in the strip above y 300; this plate is open there but for the panels), and
# the two cream buttons are brass knife-switch plates. The view stamps their lettering into the
# band at KNIFE_BAND (R12_view.gd knife_band()).
FINAL_DY = 120
FINAL_SILL = 296
FINAL_PANELS = ((100, 140, 540, 400), (560, 140, 888, 400), (908, 140, 1348, 400))
KNIFE_Y = 760
KNIFE_X = (100, 748)
TARNISH = mix(BRASS, VERD, 0.45)


def final_panels(p, dy):
    """paint_c_final's six panels (contacts, lamps, terminal, yoke well, PREVIEW key, handle
    housing), `dy` lower."""
    p.rect(100, 140 + dy, 540, 400 + dy, SLATE, INK, 3, 6)
    p.line([(106, 146 + dy), (534, 146 + dy)], SLATE_HI, 1.8)
    for (cx, cy) in ((220, 280 + dy), (420, 280 + dy)):
        p.ell(cx, cy, 58, 58, mix(SLATE, BLACK, 0.3), None)
        p.ell(cx, cy, 50, 50, BRASS, INK, 3)
        p.ell(cx, cy, 36, 36, BRASS_LO, INK, 2)
        p.arc(cx, cy, 44, 44, 200, 300, BRASS_HI, 2.4)
        p.ell(cx, cy, 13, 13, BRASS_HI, INK, 1.6)
        enamel_plate(p, cx - 60, 348 + dy, cx + 60, 376 + dy)
    for (sx, sy) in ((116, 156), (524, 156), (116, 384), (524, 384)):
        screw(p, sx, sy + dy, 4)
    p.rect(560, 140 + dy, 888, 400 + dy, IRON, INK, 3, 6)
    p.rect(568, 148 + dy, 880, 392 + dy, mix(IRON, BULK, 0.4), INK, 1.4, 4)
    for i in range(4):
        for y in (200, 270):
            lamp_socket(p, 600 + 64 * i, y + dy, 16, dead=True)
    p.line([(576, 316 + dy), (872, 316 + dy)], INK, 1.6)
    for x in (620, 820):
        lamp_socket(p, x, 350 + dy, 16, dead=True)
    p.rect(908, 140 + dy, 1348, 400 + dy, IRON, INK, 3, 6)
    p.rect(916, 148 + dy, 1340, 392 + dy, mix(IRON, BULK, 0.45), INK, 1.4, 4)
    rx0, ry0, rx1, ry1 = 1008, 250 + dy, 1248, 310 + dy
    p.rect(rx0 - 8, ry0 - 8, rx1 + 8, ry1 + 8, BRASS_LO, INK, 2.6, 4)
    p.rect(rx0, ry0, rx1, ry0 + 28, BLACK, INK, 2, 3)
    for px in (rx0 + 48, rx1 - 48):
        p.rect(px - 10, ry0 + 28, px + 10, ry1, BLACK, INK, 2, 2)
    enamel_plate(p, 1008, 176 + dy, 1248, 206 + dy)
    for (sx, sy) in ((924, 156), (1332, 156), (924, 384), (1332, 384)):
        screw(p, sx, sy + dy, 4)
    p.rect(100, 440 + dy, 540, 610 + dy, BRASS_LO, INK, 3, 6)
    p.rect(114, 454 + dy, 526, 596 + dy, FELT, INK, 2, 4)
    p.rect(150, 488 + dy, 490, 512 + dy, FELT_DK, None, r=8)
    for x in (170, 470):
        p.rect(x - 12, 496 + dy, x + 12, 584 + dy, FELT_DK, None, r=4)
    p.rect(604, 460 + dy, 844, 580 + dy, BRASS_LO, INK, 2.8, 20)
    p.ell(724, 520 + dy, 42, 42, BRASS, INK, 2.8)
    p.arc(724, 520 + dy, 36, 36, 200, 290, BRASS_HI, 2.2)
    p.ell(724, 520 + dy, 14, 14, BRASS_DK, None)
    p.rect(908, 440 + dy, 1348, 610 + dy, IRON, INK, 3, 6)
    p.rect(916, 448 + dy, 1340, 602 + dy, mix(IRON, BULK, 0.4), INK, 1.4, 4)
    p.rect(940, 515 + dy, 1316, 537 + dy, BLACK, INK, 2, 8)
    p.ell(1128, 526 + dy, 22, 22, BRASS, INK, 2.4)
    p.ell(1128, 526 + dy, 8, 8, BRASS_DK, None)


def knife_switch(p, x0, y0):
    """A knife-switch plate, 600 x 200: a tarnished brass frame round a dark iron face (no paper),
    a lettering band across the top (left blank: the view stamps the words), and below it the
    switch itself on its slate base: the hinge on the left, the blade lying shut in the jaw, its
    turned brown grip past the jaw."""
    sh = p.layer()
    sh.rect(x0 + 8, y0 + 10, x0 + 608, y0 + 210, BLACK, None, r=8)
    p.put_soft(sh, 8, 0.35)
    p.rect(x0, y0, x0 + 600, y0 + 200, TARNISH, INK, 3, 8)
    p.line([(x0 + 6, y0 + 194), (x0 + 6, y0 + 6), (x0 + 594, y0 + 6)], mix(TARNISH, BRASS_HI, 0.5), 2.0)
    p.line([(x0 + 7, y0 + 194), (x0 + 594, y0 + 194), (x0 + 594, y0 + 7)], mix(TARNISH, BRASS_DK, 0.5), 2.0)
    p.rect(x0 + 18, y0 + 18, x0 + 582, y0 + 182, mix(IRON, BULK_DK, 0.3), INK, 2.2, 5)
    # the lettering band
    p.rect(x0 + 40, y0 + 30, x0 + 560, y0 + 80, mix(BRASS_HI, VERD, 0.22), INK, 2.0, 3)
    p.line([(x0 + 44, y0 + 34), (x0 + 556, y0 + 34)], mix(BRASS_HI, PAPER_HI, 0.3), 1.2)
    p.line([(x0 + 44, y0 + 76), (x0 + 556, y0 + 76)], mix(TARNISH, BRASS_DK, 0.5), 1.2)
    # the slate base
    p.rect(x0 + 70, y0 + 108, x0 + 530, y0 + 160, SLATE, INK, 2.2, 4)
    p.line([(x0 + 74, y0 + 112), (x0 + 526, y0 + 112)], SLATE_HI, 1.4)
    # the jaw's back cheek, the blade, the jaw's front cheek
    p.rect(x0 + 452, y0 + 92, x0 + 466, y0 + 150, BRASS_LO, INK, 2.0, 2)
    p.rect(x0 + 108, y0 + 105, x0 + 472, y0 + 119, BRASS_HI, INK, 2.0, 3)
    p.line([(x0 + 116, y0 + 108), (x0 + 464, y0 + 108)], BARE, 1.4)
    p.rect(x0 + 430, y0 + 92, x0 + 444, y0 + 150, BRASS, INK, 2.0, 2)
    # the hinge: two cheeks and the pivot pin
    p.rect(x0 + 96, y0 + 92, x0 + 132, y0 + 150, BRASS, INK, 2.0, 3)
    p.ell(x0 + 114, y0 + 112, 9, 9, BRASS_HI, INK, 1.8)
    p.ell(x0 + 114, y0 + 112, 3, 3, BRASS_DK, None)
    # the grip
    p.rect(x0 + 476, y0 + 98, x0 + 552, y0 + 126, LEATHER, INK, 2.2, 12)
    p.line([(x0 + 486, y0 + 104), (x0 + 542, y0 + 104)], LEATHER_HI, 1.6)
    for (sx, sy) in ((x0 + 9, y0 + 9), (x0 + 591, y0 + 9), (x0 + 9, y0 + 191), (x0 + 591, y0 + 191)):
        screw(p, sx, sy, 3.6, BRASS_LO)


def paint_c_final_r2(rng):
    p = Pen(W, H, rng)
    closeup_ground(p, rng)
    # the sill of the eye's window
    p.rect(-4, FINAL_SILL, W + 4, FINAL_SILL + 18, IRON, INK, 2.6)
    p.line([(-4, FINAL_SILL + 4), (W + 4, FINAL_SILL + 4)], IRON_HI, 1.4)
    final_panels(p, FINAL_DY)
    for x0 in KNIFE_X:
        knife_switch(p, x0, KNIFE_Y)
    im = grain(p.done(), rng_for(2500))
    # open above the sill, but for the three panels that hang in front of it
    keep = Image.new("L", (W, H), 255)
    d = ImageDraw.Draw(keep)
    d.rectangle((0, 0, W, FINAL_SILL - 1), fill=0)
    for (x0, y0, x1, y1) in FINAL_PANELS:
        d.rectangle((x0 - 3, y0 + FINAL_DY - 3, x1 + 3, y1 + FINAL_DY + 3), fill=255)
    im.putalpha(ImageChops.multiply(im.getchannel("A"), keep))
    return im


# m_cup, r2: Nora's white china teacup on its saucer (R06's P22 sketch): a bowl narrowing to a
# foot, a sea-glass band under the rim, and at the handle's root a crack with two small navy
# staple marks across it. The squat green mug is gone.
CHINA = (236, 232, 220)
CHINA_DK = (204, 200, 188)
TEA = (104, 74, 50)


def paint_m_cup_r2(rng, warm):
    p = sprite_pen(rng)
    kitchen(p, rng)
    cloth(p, 120, 400, 780, 580)
    rc = AMBER if warm else mix(PAPER, INK, 0.3)
    p.ell(250, 476, 64, 20, None, rc, 4 if warm else 2.6)
    if warm:
        lay = p.layer()
        lay.ell(250, 476, 64, 20, None, AMBER_HI, 8)
        p.put_soft(lay, 4, 0.6)
        p.ell(250, 476, 64, 20, None, AMBER, 3.4)
    cx = 520
    # the saucer
    p.ell(cx + 4, 492, 176, 30, mix(PAPER, INK, 0.25), None)
    p.ell(cx, 482, 170, 28, CHINA, INK, 2.6)
    p.ell(cx, 478, 120, 16, CHINA_DK, None)
    p.arc(cx, 482, 150, 22, 200, 340, PAPER_HI, 2.0)
    # the handle, behind the bowl's right side: a loop from the rim down to the waist
    hx, hy = cx + 118, 382
    p.arc(hx, hy, 40, 44, 262, 458, INK, 18)
    p.arc(hx, hy, 40, 44, 262, 458, CHINA, 12)
    # the bowl
    left = bezier([(cx - 116, 326), (cx - 112, 418), (cx - 58, 452)], 30)
    right = bezier([(cx + 58, 452), (cx + 112, 418), (cx + 116, 326)], 30)
    p.poly(left + right, CHINA, INK, 2.8)
    shade = bezier([(cx + 60, 332), (cx + 92, 412), (cx + 46, 450)], 24)
    p.poly(shade + [(cx + 58, 450), (cx + 108, 414), (cx + 112, 332)], CHINA_DK, None)
    p.line([(cx - 112, 352), (cx + 112, 352)], SEAGLASS, 6)
    p.line([(cx - 112, 358), (cx + 112, 358)], INK, 1.2)
    p.line([(cx - 96, 372), (cx - 84, 432)], (250, 248, 240), 3.0)
    p.ell(cx, 326, 116, 18, CHINA, INK, 2.6)
    p.ell(cx, 329, 104, 12, TEA, None)
    # the foot ring
    p.rect(cx - 50, 450, cx + 50, 468, CHINA_DK, INK, 2.2, 3)
    # the crack at the handle's root (where it leaves the bowl under the rim) and the two staples
    root = (cx + 112, 348)
    p.line([(root[0] - 6, root[1] - 10), (root[0] + 2, root[1] - 2), (root[0] - 3, root[1] + 5),
            (root[0] + 6, root[1] + 13)], INK, 1.8)
    for sy in (-6, 6):
        p.line([(root[0] - 11, root[1] + sy - 2), (root[0] + 11, root[1] + sy + 2)], INK, 3.6)
    if warm:
        for dx in (-30, 24):
            steam = bezier([(cx + dx, 300), (cx + dx - 40, 230), (cx + dx + 30, 180), (cx + dx - 10, 90)], 40)
            p.line(steam, INK, 7)
            p.line(steam, mix(PAPER_HI, AMBER_HI, 0.2), 4)
    return p


# m_kettle: CONTINUE's lit window, close. The kitchen at night: the range, the kettle on its plate,
# the one window lit, and three flat sea-glass strokes of steam from the spout.
def paint_m_kettle(rng):
    p = sprite_pen(rng)
    panelled_wall(p, rng, mix(SEA_WALL, STORM, 0.35), 300, None, tiles=True)
    p.rect(20, 300, 880, 640, mix(TIMBER, SOOT, 0.35), None)
    p.line([(20, 300), (880, 300)], INK, 2.6)
    # the window, lit: four amber panes in a timber frame, a small flat glow round it
    gl = p.layer()
    gl.rect(66, 46, 270, 236, AMBER_HI, None, r=6)
    p.put_soft(gl, 26, 0.35)
    p.rect(80, 60, 256, 222, TIMBER, INK, 2.8, 3)
    p.rect(92, 72, 244, 210, AMBER_HI, INK, 2.0)
    p.rect(162, 72, 174, 210, TIMBER, INK, 1.6)
    p.rect(92, 136, 244, 146, TIMBER, INK, 1.6)
    p.rect(70, 222, 266, 236, mix(TIMBER, PAPER, 0.25), INK, 2.2)
    # the range: black iron, a rail, two oven doors, the hot plate
    p.rect(330, 330, 820, 640, SOOT, INK, 3, 4)
    p.rect(318, 316, 832, 336, mix(SOOT, IRON_HI, 0.4), INK, 2.6, 3)
    p.line([(340, 362), (810, 362)], BRASS_LO, 4)
    for (x0, x1) in ((350, 566), (584, 800)):
        p.rect(x0, 382, x1, 600, mix(SOOT, IRON, 0.5), INK, 2.4, 4)
        p.rect(x0 + 80, 470, x1 - 80, 482, BRASS, INK, 1.6, 4)
    p.ell(470, 316, 74, 9, mix(SOOT, IRON_HI, 0.2), INK, 2.0)
    # the kettle on the left plate
    kx = 470
    p.ell(kx, 312, 78, 12, mix(INK, SOOT, 0.5), None)
    body = bezier([(kx - 80, 308), (kx - 92, 230), (kx - 40, 196)], 24) + \
        bezier([(kx + 40, 196), (kx + 92, 230), (kx + 80, 308)], 24)
    spout = [(kx - 70, 262), (kx - 132, 214), (kx - 146, 196), (kx - 136, 190), (kx - 116, 204), (kx - 64, 236)]
    p.poly(spout, mix(BRASS_LO, SOOT, 0.25), INK, 2.4)
    p.poly(body, mix(BRASS_LO, SOOT, 0.2), INK, 2.8)
    p.line([(kx - 70, 290), (kx + 70, 290)], mix(BRASS_LO, SOOT, 0.5), 2.0)
    p.line(bezier([(kx - 74, 280), (kx - 80, 232), (kx - 38, 206)], 16), BRASS, 3.0)
    p.ell(kx, 196, 42, 8, mix(BRASS_LO, SOOT, 0.35), INK, 2.2)
    p.ell(kx, 186, 10, 8, BRASS, INK, 1.8)
    p.arc(kx, 196, 58, 66, 200, 340, INK, 9)
    p.arc(kx, 196, 58, 66, 200, 340, LEATHER, 5)
    # three flat sea-glass strokes of steam, rising from the spout
    for k, (dx, h) in enumerate(((0, 120), (-26, 96), (24, 84))):
        x, y = kx - 144 + dx, 180
        stroke = bezier([(x, y), (x - 22, y - h * 0.35), (x + 18, y - h * 0.7), (x - 6, y - h)], 30)
        p.line(stroke, SEAGLASS_HI, 9)
    return p


# The end stills, r3: each ending's subject kept above y 740 (the end card's paper panel starts
# at 760). SEVER: the corrected inquiry page (end_a_page's sill and daylight), the nine names in
# full in station order, a line left, the refusal and her name, the water stain at its corner.
CARD_PAGE = (464, 40, 984, 728)
CARD_RULE0 = 104
CARD_RULE = 44
INQUIRY_FULL = ["Silas Rook", "Nora Bell", "T. Ives", "M. Lusk", "O. Pryce", "C. Doane", "S. Hart",
                "A. Tull", "Elias Venn"]


def paint_end_a_card(rng):
    p = Pen(W, H, rng)
    daylight_wall(p, rng, 30, (182, 190, 186))
    p.rect(-4, 10, W + 4, 34, mix(TIMBER, PAPER, 0.3), INK, 3)
    p.rect(-4, 34, W + 4, H + 4, TIMBER, INK, 3)
    lay = p.layer()
    for _ in range(40):
        y = rng.uniform(40, H)
        lay.line([(-4, y), (W + 4, y + rng.uniform(-3, 3))], TIMBER_DK, rng.uniform(1, 2.4))
    p.put(lay, 0.55)
    lt = p.layer()
    lt.poly([(300, 34), (1300, 34), (1448, 1086), (120, 1086)], PAPER_HI, None)
    p.put_soft(lt, 40, 0.18)
    x0, y0, x1, y1 = CARD_PAGE
    sh = p.layer()
    sh.rect(x0 + 10, y0 + 12, x1 + 10, y1 + 12, BLACK, None)
    p.put_soft(sh, 8, 0.3)
    p.rect(x0, y0, x1, y1, PAPER_HI, INK, 2.6)
    for k in range(14):
        y = CARD_RULE0 + CARD_RULE * k
        p.line([(x0 + 30, y), (x1 - 30, y)], mix(PAPER, SEAGLASS, 0.45), 1.4)
    p.line([(x0 + 80, y0 + 20), (x0 + 80, y1 - 20)], mix(PAPER, VIOLET, 0.35), 1.4)
    # the inkwell, the window bright in its ink
    ix, iy = 1180, 560
    sh = p.layer()
    sh.ell(ix + 8, iy + 120, 90, 16, BLACK, None)
    p.put_soft(sh, 6, 0.35)
    p.rect(ix - 80, iy, ix + 80, iy + 116, BRASS, INK, 3, 10)
    p.rect(ix - 70, iy + 8, ix - 50, iy + 108, BRASS_HI, None, r=6)
    p.rect(ix + 46, iy + 8, ix + 72, iy + 108, BRASS_LO, None, r=6)
    p.rect(ix - 80, iy, ix + 80, iy + 116, None, INK, 3, 10)
    p.ell(ix, iy, 80, 20, BRASS_DK, INK, 2.6)
    p.ell(ix, iy, 66, 16, (10, 12, 16), INK, 2.4)
    p.rect(ix - 30, iy - 10, ix + 4, iy + 8, (250, 248, 240), None)
    p.line([(ix - 13, iy - 10), (ix - 13, iy + 8)], (10, 12, 16), 2)
    p.line([(ix - 30, iy - 1), (ix + 4, iy - 1)], (10, 12, 16), 1.6)
    # the water stain at the page's corner: a dark tide ring, and nothing in it
    sx, sy = x1 - 62, y1 - 26
    p.ell(sx, sy, 30, 20, mix(PAPER_HI, PAPER_LO, 0.55), None)
    p.ell(sx, sy, 30, 20, None, mix(PAPER_LO, TIMBER_DK, 0.55), 2.6)
    p.arc(sx, sy, 25, 16, 200, 330, mix(PAPER_LO, TIMBER_DK, 0.3), 1.2)
    im = grain(p.done(), rng_for(2700)).convert("RGB")
    # her hand, baked in: the nine names on rules 1-9, the refusal on 11, her name on 13
    tx = x0 + 100
    for k, name in enumerate(INQUIRY_FULL):
        hand_text(im, name, tx, CARD_RULE0 + CARD_RULE * (k + 1) - 6, HAND_SIZE, k)
    hand_text(im, "I cannot certify their absence.", tx, CARD_RULE0 + CARD_RULE * 11 - 6, HAND_SIZE, 20)
    hand_text(im, "A. Mercer", tx + 140, CARD_RULE0 + CARD_RULE * 13 - 6, HAND_SIZE, 21)
    return im


# ============================================================================ registry
def opaque_grain(k, painter):
    return lambda rng: grain(painter(rng).done(), rng_for(1000 + k))


ASSETS = [  # name, seed index, painter, opaque
    ("view_a", 0, paint_view_a_base, True),
    ("a_surface", 10, paint_surface, False),
    ("a_surface_withdrawn", 11, paint_surface_withdrawn, False),
    ("a_daylight", 12, paint_daylight, False),
    ("a_morning", 13, paint_morning, False),
    ("a_arm_rest", 14, lambda r: paint_arms(r, False), False),
    ("a_arm_low", 15, lambda r: paint_arms(r, True), False),
    ("a_cushion_dent", 16, paint_cushion_dent, False),
    ("a_arm_ready", 21, lambda r: paint_arms(r, "ready"), False),
    ("a_stain_1", 22, a_overlay(stain=1), False),
    ("a_stain_2", 23, a_overlay(stain=2), False),
    ("a_gauge_pinned", 24, a_overlay(pinned=True), False),
    ("a_ada_seated", 17, paint_ada, False),
    ("a_lid_line", 18, paint_lid_line, False),
    ("a_surface_lid", 20, paint_surface_lid, False),
    ("a_gauge_needle", 19, paint_needle, False),
    ("view_b", 100, lambda r: view_b_final(), True),
    ("b_terminal_lit", 101, b_overlay(("lit",)), False),
    ("b_shutters_turned", 102, b_overlay(("turned",)), False),
    ("b_copy_uncapped", 103, b_overlay(("uncapped",)), False),
    ("b_frames_filled", 104, b_overlay(("filled",)), False),
    ("b_indicators_dark", 105, lambda r: diff_overlay(view_b_final(), view_b_final(("dark",)), dark_extra()), False),
    ("view_c", 200, lambda r: view_c_final(), True),
    ("c_shutters_closed", 201, c_overlay(("shutters",)), False),
    ("c_lamps_ready", 202, c_overlay(("lamps",)), False),
    ("c_yoke_fitted", 203, c_overlay(("yoke",)), False),
    ("c_tray_empty", 204, c_overlay(("tray_empty",)), False),
    ("c_bridge_seated", 205, c_overlay(("bridge",)), False),
    ("c_handle_pulled", 206, c_overlay(("pulled",)), False),
    ("c_frames", 300, lambda r: c_frames_final(), True),
    ("c_frames_back", 301, lambda r: diff_overlay(c_frames_final(), c_frames_final(("back",))), False),
    ("c_frames_lit", 302, lambda r: diff_overlay(c_frames_final(), c_frames_final(("lit",))), False),
    ("card", 303, lambda r: paint_card(r), False),
    ("switch_witness", 304, lambda r: paint_switch(r, "left"), False),
    ("switch_copy", 305, lambda r: paint_switch(r, "right"), False),
    ("route_key", 306, lambda r: paint_route_key(r, False), False),
    ("route_key_turned", 307, lambda r: paint_route_key(r, True), False),
    ("c_routing", 400, lambda r: c_routing_final(), True),
    ("c_routing_closed", 401, lambda r: diff_overlay(c_routing_final(), c_routing_final(True)), False),
    ("cc_card", 402, lambda r: paint_card(r, 300, 150, hole=False), False),
    ("lamp_on", 403, lambda r: paint_lamp(r, True), False),
    ("lamp_off", 404, lambda r: paint_lamp(r, False), False),
    ("c_final", 500, opaque_grain(500, paint_c_final), True),
    ("yoke", 501, paint_yoke, False),
    ("bridge", 502, paint_bridge, False),
    ("end_card", 600, opaque_grain(600, paint_end_card), True),
    ("m_funnels_on", 610, in_oval(lambda r: paint_m_funnels(r, True)), False),
    ("m_funnels_off", 611, in_oval(lambda r: paint_m_funnels(r, False)), False),
    ("m_diaphragm_in", 612, in_oval(lambda r: paint_m_diaphragm(r, "in")), False),
    ("m_diaphragm_still", 613, in_oval(lambda r: paint_m_diaphragm(r, "still")), False),
    ("m_jars_tilted", 614, in_oval(lambda r: paint_m_jars(r, False)), False),
    ("m_jars_level", 615, in_oval(lambda r: paint_m_jars(r, True)), False),
    ("m_spoon_up", 616, in_oval(lambda r: paint_m_spoon(r, True)), False),
    ("m_spoon_down", 617, in_oval(lambda r: paint_m_spoon(r, False)), False),
    ("m_bed_pressed", 618, in_oval(lambda r: paint_m_bed(r, True)), False),
    ("m_bed_risen", 619, in_oval(lambda r: paint_m_bed(r, False)), False),
    ("m_pen_down", 620, in_oval(lambda r: paint_m_pen(r, True)), False),
    ("m_pen_up", 621, in_oval(lambda r: paint_m_pen(r, False)), False),
    ("m_funnel_venn_on", 622, in_oval(lambda r: paint_m_funnel_venn(r, True)), False),
    ("m_funnel_venn_off", 623, in_oval(lambda r: paint_m_funnel_venn(r, False)), False),
    ("m_coat_full", 624, in_oval(lambda r: paint_m_coat(r, True)), False),
    ("m_coat_slack", 625, in_oval(lambda r: paint_m_coat(r, False)), False),
    ("m_cup_cold", 626, in_oval(lambda r: paint_m_cup(r, False)), False),
    ("m_cup_warm", 627, in_oval(lambda r: paint_m_cup(r, True)), False),
    ("end_a_record", 700, opaque_grain(700, paint_end_a_record), True),
    ("end_a_jetty", 701, opaque_grain(701, paint_end_a_jetty), True),
    ("end_a_inquiry", 702, opaque_grain(702, paint_end_a_inquiry), True),
    ("end_a_page", 703, opaque_grain(703, paint_end_a_page), True),
    ("end_b_terminal", 704, opaque_grain(704, paint_end_b_terminal), True),
    ("end_b_wide", 705, opaque_grain(705, paint_end_b_wide), True),
    ("end_b_cover", 706, opaque_grain(706, paint_end_b_cover), True),
    ("cover_sheet", 707, paint_cover_sheet, False),
    ("a_surface_wide", 25, paint_surface_wide, False),
    ("end_b_field", 708, paint_end_b_field, True),
    # fix p1: new files only
    ("a_surface_eye", 1209, paint_surface_eye, False),
    ("c_routing_preview", 1210, lambda r: grain(paint_c_routing_preview(r).done(), rng_for(2410)), True),
    ("a_prev_sever_lit", 1211, lambda r: paint_prev_sever(r, True), False),
    ("a_prev_sever_dark", 1211, lambda r: paint_prev_sever(r, False), False),
    ("a_prev_feed", 1212, paint_prev_feed, False),
    ("a_prev_oilskin", 1213, paint_prev_oilskin, False),
    ("stages/r12_sever_office", 1214, checked_hand(paint_sever_office), True),
    ("stages/r12_continue_terminal", 1215,
     checked_hand(lambda r: (lambda res: (grain(res[0].done(), rng_for(2415)), res[1]))(paint_continue_terminal(r))), True),
    ("stages/end_b_wide_2", 1216, paint_end_b_wide_2, True),
    # fix p2: new files only
    ("a_surface_eye_r3", 1217, paint_surface_eye_r3, False),
    ("a_pupil_r3", 1218, paint_pupil_r3, False),
    ("stages/end_b_wide_3", 1219, paint_end_b_wide_3, True),
    ("stages/r12_sever_office_r2", 703, paint_sever_office_r2, True),
    # fix p3: new files only
    ("c_final_r2", 1220, paint_c_final_r2, False),
    ("m_cup_r2_cold", 626, in_oval(lambda r: paint_m_cup_r2(r, False)), False),
    ("m_cup_r2_warm", 627, in_oval(lambda r: paint_m_cup_r2(r, True)), False),
    ("m_kettle", 1221, in_oval(paint_m_kettle), False),
    ("stages/end_a_card", 1222, paint_end_a_card, True),
    # CONTINUE's end still: end_b_wide_3 (its seeds, its stations, its kitchen at y 643) with the
    # eye let down far enough that its whole pupil shows above the horizon
    ("stages/end_b_card", 1219, lambda r: paint_end_b_wide_3(r, eye_y=-40), True),
]


def main(argv):
    pats = argv or ["*"]
    for name, k, fn, opaque in ASSETS:
        if not any(fnmatch.fnmatch(name, pat) for pat in pats):
            continue
        res = fn(rng_for(k))
        im = res.done() if isinstance(res, Pen) else res
        save(im, name, opaque)


if __name__ == "__main__":
    main(sys.argv[1:])
