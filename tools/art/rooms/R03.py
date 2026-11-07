#!/usr/bin/env python3
"""R03 Chart Room painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R03/*.png:

  plates      A_base, B_base, C_base                  (1448x1086 RGB, three walls)
  overlays    A_composite, A_compass_bent, A_standing, A_plan_body, A_buckle, A_fog,
              B_window_0..7, B_rain_a/b/c, B_seal_intact, B_seal_broken, B_p05, B_strip,
              C_hatch_open, C_window_7, C_rope_0/1/2, C_beads (1448x1086 RGBA, registered to a base)
              {A,B,C}_damp_2..7                       (1448x308 RGBA, drawn at y 596: the rising tide-mark)
  close-ups   cu_registration, cu_recorder, cu_plan   (1448x1086 RGB)
              cu_recorder_shutter, cu_seal, cu_seal_broken, cu_plan_lid, cu_plan_body,
              cu_rec_fog, cu_rec_brown                (RGBA)
  sprites     B_pen 160x200, B_float 40x70, C_line 8x260, sheet_paper 600x560, sheet_tracing 600x560,
              plate_blank 130x130, tile_blank 170x84

Flat front elevation, approved palette, navy ink contours (tapered: heavy on the shadow side)
over matte two-tone colour, brass with a highlight stripe and a tarnish band, the office's
fine paper fibre, and light baked toward each wall's source (lamp, sea window, hatch).
No text anywhere: the view draws every label, digit, symbol, curve and diagram.

Python 3 + PIL only. Deterministic: one random.Random per asset, seeded from SEED and the
asset name; no wall clock. Ink is drawn at SS x scale and reduced. Reruns are byte-identical.

    python3 tools/art/rooms/R03.py              # paint everything
    python3 tools/art/rooms/R03.py A_base cu_plan   # paint some
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "rooms", "R03")
W, H = 1448, 1086
SEED = 19311017
SS = 4

# ---------------------------------------------------------------- palette (GDD 11 + plates)
INK = (23, 43, 54)            # #172B36 contour
PAPER = (216, 206, 181)       # #D8CEB5
PAPER2 = (222, 212, 186)      # #DED4BA
BONE = (230, 223, 202)
WALL = (163, 181, 161)        # #A3B5A1 sea-glass wall
WALL_D = (146, 165, 146)
TEAL = (44, 83, 99)           # #2C5363 wainscot
TEAL_D = (33, 66, 80)
TEAL_L = (62, 105, 121)
NAVY = (22, 32, 48)           # #162030 storm navy
NAVY2 = (34, 48, 58)          # #22303A
COPPER = (97, 125, 116)       # #617D74 oxidized copper
COPPER_D = (72, 96, 90)
COPPER_DD = (52, 72, 70)
COPPER_L = (126, 151, 140)
BRASS = (176, 138, 74)        # #B08A4A tarnished brass
BRASS_D = (134, 102, 52)
BRASS_L = (205, 172, 108)
BRASS_POL = (232, 204, 140)   # polished, worn lever
TIMBER = (103, 93, 81)        # #675D51 damp timber
TIMBER_D = (80, 71, 62)
TIMBER_L = (128, 117, 102)
FLOOR = (118, 107, 93)
SOOT = (41, 41, 41)           # #292929
AMBER = (195, 153, 89)        # #C39959, sparingly
BRUISE = (116, 101, 119)      # #746577
IRON = (40, 50, 60)
IRON_L = (60, 72, 82)
IRON_D = (28, 34, 42)
WAX = (122, 52, 40)
WAX_D = (88, 34, 28)
WAX_L = (156, 82, 64)
ROPE = (150, 134, 104)
ROPE_D = (112, 98, 76)
FELT = (64, 92, 78)
FELT_D = (46, 70, 60)
SHEEN = (214, 226, 220)
WETDARK = (15, 23, 31)
COPPER_WARM = (150, 104, 72)  # the float: restrained warm copper
COPPER_WARM_L = (184, 134, 94)


# ---------------------------------------------------------------- helpers
def rng_for(name):
    return random.Random(f"{SEED}:{name}")


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def mix(c0, c1, t):
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(c0, c1))


def rgba(c, a):
    return (c[0], c[1], c[2], int(a))


def noise(rng, w, h, cell, lo=0.0, hi=1.0):
    """Smooth value noise as an L image, feature size about `cell` px."""
    sw, sh = max(2, int(w / cell) + 2), max(2, int(h / cell) + 2)
    small = Image.frombytes("L", (sw, sh), rng.randbytes(sw * sh))
    big = small.resize((w, h), Image.BICUBIC)
    return big.point([int(round((lo + (hi - lo) * v / 255.0) * 255)) for v in range(256)])


def fibres(rng, w, h):
    """Paper fibre field centred on 128: speckle + horizontal and vertical streaks + mottle."""
    sp = noise(rng, w, h, 1.3)
    hf = Image.frombytes("L", (max(2, w // 16), h), rng.randbytes(max(2, w // 16) * h)).resize((w, h), Image.BICUBIC)
    vf = Image.frombytes("L", (w, max(2, h // 16)), rng.randbytes(w * max(2, h // 16))).resize((w, h), Image.BICUBIC)
    mo = noise(rng, w, h, 28)
    n = Image.blend(sp, hf, 0.45)
    n = Image.blend(n, vf, 0.3)
    return Image.blend(n, mo, 0.18)


def grain(img, rng, amt=9.0):
    """Seeded low-contrast paper texture over an RGB or RGBA image (alpha kept)."""
    w, h = img.size
    n = fibres(rng, w, h)
    lut_up = [int(clamp((v - 128) * amt / 40.0, 0, 255)) for v in range(256)]
    lut_dn = [int(clamp((128 - v) * amt / 40.0, 0, 255)) for v in range(256)]
    up, dn = n.point(lut_up), n.point(lut_dn)
    alpha = img.getchannel("A") if img.mode == "RGBA" else None
    chans = []
    for c in img.convert("RGB").split():
        chans.append(ImageChops.subtract(ImageChops.add(c, up), dn))
    out = Image.merge("RGB", chans)
    if alpha is not None:
        out.putalpha(alpha)
    return out


def vgrad(w, h, c0, c1, gamma=1.0):
    g = Image.linear_gradient("L").resize((w, h), Image.BICUBIC)
    if gamma != 1.0:
        g = g.point([int(255 * (v / 255.0) ** gamma) for v in range(256)])
    return Image.composite(Image.new("RGB", (w, h), c1), Image.new("RGB", (w, h), c0), g)


def ellipse_pts(cx, cy, rx, ry, n=72, a0=0.0, a1=2 * math.pi):
    return [(cx + rx * math.cos(a0 + (a1 - a0) * k / n), cy + ry * math.sin(a0 + (a1 - a0) * k / n))
            for k in range(n + 1)]


def bezier(p0, p1, p2, p3, n=48):
    out = []
    for k in range(n + 1):
        t = k / n
        u = 1 - t
        out.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                    u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))
    return out


def smooth_closed(pts, n=10):
    """Closed Catmull-Rom spline through pts."""
    out = []
    m = len(pts)
    for i in range(m):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % m], pts[(i + 2) % m]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    return out


def smooth_open(pts, n=10):
    out = []
    m = len(pts)
    for i in range(m - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, m - 1)]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    out.append(pts[-1])
    return out


def rot(pts, cx, cy, deg):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca) for x, y in pts]


LIGHT_DIR = (0.6, 0.8)          # shadow side: light falls from the upper left
BRASSES = {BRASS, BRASS_L, BRASS_D, BRASS_POL}


def _signed_area(pts):
    return sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
               for i in range(len(pts))) / 2.0


def rrect_pts(x0, y0, x1, y1, r, n=6):
    r = max(0.0, min(r, (x1 - x0) / 2.0, (y1 - y0) / 2.0))
    if r < 0.5:
        return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    out = []
    for (cx, cy, a0) in ((x1 - r, y0 + r, -math.pi / 2), (x1 - r, y1 - r, 0.0), (x0 + r, y1 - r, math.pi / 2),
                         (x0 + r, y0 + r, math.pi)):
        for k in range(n + 1):
            a = a0 + (math.pi / 2) * k / n
            out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


class Cv:
    """An RGBA drawing surface at SS x scale, addressed in 1x plate coordinates.

    Closed outlines are inked at variable width: thin on the lit (top/left) side, heavy on the
    shadow (bottom/right) side, the way the office plates taper their navy contours."""

    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w * SS, h * SS), bg)
        self.d = ImageDraw.Draw(self.im)

    @staticmethod
    def P(pts):
        return [(x * SS, y * SS) for x, y in pts]

    def vloop(self, pts, col=INK, w=3, taper=0.5):
        """A closed outline whose width follows the light: w*(1-taper) lit .. w*(1+taper) shadow."""
        pts = [tuple(p) for p in pts]
        if len(pts) > 2 and pts[0] == pts[-1]:
            pts = pts[:-1]
        if len(pts) < 2:
            return
        sgn = 1.0 if _signed_area(pts) >= 0 else -1.0
        n = len(pts)
        widths = []
        for i in range(n):
            (ax, ay), (bx, by) = pts[i], pts[(i + 1) % n]
            L = math.hypot(bx - ax, by - ay) or 1.0
            nx, ny = sgn * (by - ay) / L, sgn * -(bx - ax) / L
            k = nx * LIGHT_DIR[0] + ny * LIGHT_DIR[1]
            widths.append(max(0.6, w * (1.0 + taper * k)))
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            ww = max(1, int(round(widths[i] * SS)))
            self.d.line([(a[0] * SS, a[1] * SS), (b[0] * SS, b[1] * SS)], fill=col, width=ww)
            r = max(widths[i], widths[i - 1]) * SS / 2.0
            self.d.ellipse([a[0] * SS - r, a[1] * SS - r, a[0] * SS + r, a[1] * SS + r], fill=col)

    def _local(self, x0, y0, x1, y1):
        """A small SS layer over a 1x box: (layer, draw, P mapping 1x points into it, origin)."""
        ox, oy = int(math.floor(x0 * SS)) - 2, int(math.floor(y0 * SS)) - 2
        lw, lh = int(math.ceil(x1 * SS)) - ox + 4, int(math.ceil(y1 * SS)) - oy + 4
        lay = Image.new("RGBA", (max(1, lw), max(1, lh)), (0, 0, 0, 0))
        P = lambda pts: [(x * SS - ox, y * SS - oy) for x, y in pts]
        return lay, ImageDraw.Draw(lay), P, (ox, oy)

    def _put(self, lay, mask, origin):
        lay.putalpha(ImageChops.multiply(lay.getchannel("A"), mask))
        ox, oy = origin
        if ox < 0 or oy < 0:
            lay = lay.crop((max(0, -ox), max(0, -oy), lay.width, lay.height))
            ox, oy = max(0, ox), max(0, oy)
        self.im.alpha_composite(lay, (ox, oy))

    def _finish(self, pts, fill, x0, y0, x1, y1, shade):
        """Matte two-tone shade on the shadow side and a brass stripe/tarnish band, inside pts."""
        if fill is None or len(fill) == 4 and fill[3] < 255:
            return
        bw, bh = x1 - x0, y1 - y0
        is_brass = tuple(fill[:3]) in BRASSES
        if is_brass and min(bw, bh) > 90:
            is_brass = False        # big brass fields keep a plain matte; stripes are for parts
        if not (shade or is_brass) or bw < 10 or bh < 10:
            return
        lay, d, P, org = self._local(x0, y0, x1, y1)
        base = tuple(fill[:3])
        if shade:
            t = max(4.0, min(26.0, 0.11 * min(bw, bh) + 3))
            d.polygon(P([(x1 - t, y0 + t * 0.6), (x1, y0), (x1, y1), (x1 - t, y1 - t)]), fill=rgba(mix(base, NAVY, 0.22), 255))
            d.polygon(P([(x0 + t * 0.6, y1 - t), (x1 - t, y1 - t), (x1, y1), (x0, y1)]), fill=rgba(mix(base, NAVY, 0.30), 255))
            d.polygon(P([(x0, y0), (x1, y0), (x1 - t, y0 + t * 0.45), (x0 + t * 0.45, y0 + t * 0.45)]),
                      fill=rgba(mix(base, (236, 232, 214), 0.10), 255))
        if is_brass:
            hi, lo = rgba(mix(base, (250, 232, 180), 0.55), 255), rgba(mix(base, (92, 84, 52), 0.38), 255)
            if bw >= bh * 1.6 or bh < 26:      # horizontal piece: stripes run along it
                d.polygon(P([(x0, y0 + bh * 0.20), (x1, y0 + bh * 0.20), (x1, y0 + bh * 0.20 + max(1.5, bh * 0.10)),
                             (x0, y0 + bh * 0.20 + max(1.5, bh * 0.10))]), fill=hi)
                d.polygon(P([(x0, y0 + bh * 0.66), (x1, y0 + bh * 0.66), (x1, y0 + bh * 0.84), (x0, y0 + bh * 0.84)]), fill=lo)
            else:                              # upright piece: stripes run down it
                d.polygon(P([(x0 + bw * 0.18, y0), (x0 + bw * 0.18 + max(1.5, bw * 0.10), y0),
                             (x0 + bw * 0.18 + max(1.5, bw * 0.10), y1), (x0 + bw * 0.18, y1)]), fill=hi)
                d.polygon(P([(x0 + bw * 0.64, y0), (x0 + bw * 0.84, y0), (x0 + bw * 0.84, y1), (x0 + bw * 0.64, y1)]), fill=lo)
        m = Image.new("L", lay.size, 0)
        ImageDraw.Draw(m).polygon(P(pts), fill=255)
        self._put(lay, m, org)

    def rect(self, x0, y0, x1, y1, fill=None, ol=INK, w=3, shade=False):
        if x1 - x0 < 0.5 or y1 - y0 < 0.5:
            return
        pts = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
        if fill is not None:
            self.d.rectangle([x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1], fill=fill)
            self._finish(pts, fill, x0, y0, x1, y1, shade)
        if ol is not None and w:
            self.vloop(pts, ol, w)

    def rrect(self, x0, y0, x1, y1, r, fill=None, ol=INK, w=3, shade=False):
        pts = rrect_pts(x0, y0, x1, y1, r)
        if fill is not None:
            self.d.polygon(self.P(pts), fill=fill)
            self._finish(pts, fill, x0, y0, x1, y1, shade)
        if ol is not None and w:
            self.vloop(pts, ol, w)

    def ell(self, cx, cy, rx, ry, fill=None, ol=INK, w=3):
        box = [(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS]
        if fill is not None:
            self.d.ellipse(box, fill=fill)
            if tuple(fill[:3]) in BRASSES and len(fill) == 3 and min(rx, ry) >= 5:
                # a tarnish crescent lower-right, a highlight fleck upper-left
                lay, d, P, org = self._local(cx - rx, cy - ry, cx + rx, cy + ry)
                def eb(x0, y0, x1, y1):
                    (a, b), (c, e) = P([(x0, y0), (x1, y1)])
                    return [a, b, c, e]
                d.ellipse(eb(cx - rx, cy - ry, cx + rx, cy + ry), fill=rgba(mix(fill, (92, 84, 52), 0.35), 255))
                d.ellipse(eb(cx - rx * 1.22, cy - ry * 1.22, cx + rx * 0.78, cy + ry * 0.78), fill=rgba(fill, 255))
                d.ellipse(eb(cx - rx * 0.62, cy - ry * 0.70, cx - rx * 0.10, cy - ry * 0.38),
                          fill=rgba(mix(fill, (250, 232, 180), 0.55), 255))
                m = Image.new("L", lay.size, 0)
                ImageDraw.Draw(m).ellipse(eb(cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
                self._put(lay, m, org)
        if ol is not None and w:
            n = max(16, min(96, int((rx + ry) * 0.9)))
            self.vloop(ellipse_pts(cx, cy, rx, ry, n)[:-1], ol, w)

    def poly(self, pts, fill=None, ol=INK, w=3):
        if fill is not None:
            self.d.polygon(self.P(pts), fill=fill)
        if ol is not None and w:
            self.vloop(list(pts), ol, w)

    def line(self, pts, col=INK, w=3, caps=True):
        sp = self.P(pts)
        ww = max(1, int(round(w * SS)))
        self.d.line(sp, fill=col, width=ww, joint="curve")
        if caps and ww > 2:
            r = ww / 2.0
            for (x, y) in (sp[0], sp[-1]):
                self.d.ellipse([x - r, y - r, x + r, y + r], fill=col)

    def layer(self):
        return Cv(self.w, self.h)

    def comp(self, other, alpha=1.0):
        im = other.im
        if alpha < 1.0:
            a = im.getchannel("A").point([int(v * alpha) for v in range(256)])
            im = im.copy()
            im.putalpha(a)
        self.im.alpha_composite(im)

    def paste1x(self, img, x, y, mask=None):
        img = img.convert("RGBA")
        if mask is not None:
            img.putalpha(mask)
        up = img.resize((img.width * SS, img.height * SS), Image.BICUBIC)
        self.im.alpha_composite(up, (int(x * SS), int(y * SS)))

    def shadow(self, draw_fn, off=(5, 7), blur=6, alpha=70, col=INK):
        """Soft cast shadow: draw_fn(ImageDraw at 1x, offset) paints shapes into an L mask."""
        m = Image.new("L", (self.w, self.h), 0)
        draw_fn(ImageDraw.Draw(m), off)
        m = m.filter(ImageFilter.GaussianBlur(blur)).point([int(v * alpha / 255) for v in range(256)])
        sh = Image.new("RGBA", (self.w, self.h), rgba(col, 255))
        sh.putalpha(m)
        self.im.alpha_composite(sh.resize((self.w * SS, self.h * SS), Image.BICUBIC))

    def down(self):
        return self.im.convert("RGBa").resize((self.w, self.h), Image.LANCZOS).convert("RGBA")


def save(img, name, mode):
    os.makedirs(OUT, exist_ok=True)
    img = img.convert(mode)
    img.save(os.path.join(OUT, name + ".png"), optimize=False, compress_level=9)
    print("  wrote", name, img.size, mode)


def finish_rgb(cv, name, amt=6.0):
    return grain(cv.down().convert("RGB"), rng_for(name + ":grain"), amt)


def finish_rgba(cv, name, amt=7.0):
    return grain(cv.down(), rng_for(name + ":grain"), amt)


def clip_to(img, x0, y0, x1, y1):
    """Zero alpha outside a rect (overlays opaque only inside the glass)."""
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rectangle([x0, y0, x1 - 1, y1 - 1], fill=255)
    a = ImageChops.multiply(img.getchannel("A"), m)
    img = img.copy()
    img.putalpha(a)
    return img


# ---------------------------------------------------------------- shared furniture
def screw(cv, x, y, r=4, col=BRASS, w=1.5):
    cv.ell(x, y, r, r, fill=col, ol=INK, w=w)
    cv.line([(x - r * 0.6, y + r * 0.2), (x + r * 0.6, y - r * 0.2)], INK, max(1.0, w * 0.8), caps=False)


def rivet(cv, x, y, r=4, col=IRON_L):
    cv.ell(x, y, r, r, fill=col, ol=INK, w=1.5)
    cv.ell(x - r * 0.3, y - r * 0.35, r * 0.35, r * 0.3, fill=mix(col, SHEEN, 0.35), ol=None, w=0)


def brass_plate(cv, x0, y0, x1, y1, col=BRASS, screws=True, w=2.5, r=3):
    cv.rrect(x0, y0, x1, y1, r, fill=col, ol=INK, w=w)
    hi = mix(col, BRASS_L, 0.7)
    lo = mix(col, BRASS_D, 0.7)
    cv.line([(x0 + 4, y0 + 4), (x1 - 4, y0 + 4)], hi, 2, caps=False)
    cv.line([(x0 + 4, y1 - 4), (x1 - 4, y1 - 4)], lo, 2, caps=False)
    if screws and (x1 - x0) > 40 and (y1 - y0) > 26:
        for sx, sy in ((x0 + 9, y0 + 9), (x1 - 9, y0 + 9), (x0 + 9, y1 - 9), (x1 - 9, y1 - 9)):
            screw(cv, sx, sy, 3.2)


WALL_LIT = (185, 196, 166)     # #B9C4A6 the office's sage-cream, lit
WALL_SH = (159, 176, 163)      # #9FB0A3 in shadow
PIC_RAIL = 134                 # picture rail
BEAM_Y = 30                    # ceiling beam / cornice depth


def paper_fibre(img, rng, strength=0.05):
    """The office's matte paper: fine fibre plus a soft small mottle and sparse speckle (no clouds)."""
    w, h = img.size
    sw, sh = w, h
    fib = Image.frombytes("L", (sw, sh), rng.randbytes(sw * sh)).filter(ImageFilter.GaussianBlur(0.7))
    fib = ImageOps.autocontrast(fib, cutoff=1)
    mw, mh = max(2, w // 28), max(2, h // 28)
    mot = ImageOps.autocontrast(Image.frombytes("L", (mw, mh), rng.randbytes(mw * mh)).resize((w, h), Image.BICUBIC), cutoff=1)
    tex = Image.blend(fib, mot, 0.45)
    pos = tex.point([int(max(0, v - 128) * strength) for v in range(256)])
    neg = tex.point([int(max(0, 128 - v) * strength) for v in range(256)])
    bands = img.convert("RGB").split()
    out = Image.merge("RGB", [ImageChops.subtract(ImageChops.add(c, pos), neg) for c in bands])
    sp = Image.frombytes("L", (w, h), rng.randbytes(w * h))
    out = Image.composite(Image.new("RGB", (w, h), (236, 236, 226)), out, sp.point([8 if v > 251 else 0 for v in range(256)]))
    out = Image.composite(Image.new("RGB", (w, h), INK), out, sp.point([10 if v < 4 else 0 for v in range(256)]))
    return out


def wall_light(w, h, pool):
    """Plaster colour: shadow toward the corners and the dado, lit inside `pool` (cx, cy, rx, ry, warmth)."""
    cx, cy, rx, ry, warm = pool
    g = Image.new("L", (w // 8, h // 8), 0)
    px = g.load()
    for y in range(h // 8):
        for x in range(w // 8):
            X, Y = x * 8, y * 8
            d = ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2
            v = math.exp(-d * 1.1) * 0.85 + 0.15 * (1 - Y / h)
            px[x, y] = int(255 * clamp(v))
    g = g.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(10))
    lit = mix(WALL_LIT, (206, 196, 156), warm)
    return Image.composite(Image.new("RGB", (w, h), lit), Image.new("RGB", (w, h), WALL_SH), g)


POOLS = {"A": (800, 330, 620, 420, 0.35), "B": (300, 330, 520, 440, 0.0), "C": (740, 470, 560, 420, 0.0)}


def room_shell(name):
    """Shared geometry for all three walls (flat front elevation), lit per wall."""
    wall = name[0]
    rng = rng_for(name + ":shell")
    cv = Cv(W, H, rgba(WALL, 255))
    plaster = paper_fibre(wall_light(W, 586, POOLS[wall]), rng_for(name + ":fibre"), 0.05)
    cv.paste1x(plaster, 0, 0)
    # ceiling beam / cornice: a heavy moulding the HUD sits on
    cv.rect(0, 0, W, BEAM_Y, fill=TEAL_D, ol=None)
    cv.rect(0, BEAM_Y - 9, W, BEAM_Y, fill=TEAL, ol=None)
    cv.line([(0, BEAM_Y - 9), (W, BEAM_Y - 9)], TEAL_L, 1.4, caps=False)
    cv.line([(0, BEAM_Y), (W, BEAM_Y)], INK, 3, caps=False)
    sh = Image.new("L", (W, 30), 0)
    ImageDraw.Draw(sh).rectangle([0, 0, W, 6], fill=120)
    cv.paste1x(Image.new("RGB", (W, 30), NAVY), 0, BEAM_Y, sh.filter(ImageFilter.GaussianBlur(5)))
    # picture rail
    cv.shadow(lambda d, o: d.rectangle([0, PIC_RAIL + o[1], W, PIC_RAIL + 10 + o[1]], fill=255), (0, 6), 4, 70)
    cv.rect(0, PIC_RAIL, W, PIC_RAIL + 10, fill=TEAL, ol=None)
    cv.line([(0, PIC_RAIL), (W, PIC_RAIL)], INK, 1.6, caps=False)
    cv.line([(0, PIC_RAIL + 2.5), (W, PIC_RAIL + 2.5)], TEAL_L, 1.2, caps=False)
    cv.line([(0, PIC_RAIL + 10), (W, PIC_RAIL + 10)], INK, 2.6, caps=False)
    # wainscot
    cv.rect(0, 600, W, 900, fill=TEAL, ol=None)
    for x in range(24, W, 48):
        cv.line([(x, 602), (x, 872)], TEAL_D, 2.6, caps=False)
        cv.line([(x + 2.5, 602), (x + 2.5, 872)], TEAL_L, 1.0, caps=False)
    gr = noise(rng, W, 300, 3).resize((W // 6, 300)).resize((W, 300), Image.BICUBIC)
    grain_l = gr.point([int(clamp((v - 128) / 128.0, 0, 1) * 28) for v in range(256)])
    cv.paste1x(Image.new("RGB", (W, 300), TEAL_D), 0, 600, grain_l)
    # dado rail
    cv.rect(0, 584, W, 602, fill=TEAL_D, ol=None)
    cv.line([(0, 584), (W, 584)], INK, 2.0, caps=False)
    cv.line([(0, 588), (W, 588)], TEAL_L, 1.6, caps=False)
    cv.line([(0, 601), (W, 601)], INK, 3.2, caps=False)
    # skirting
    cv.rect(0, 872, W, 900, fill=TEAL_D, ol=None)
    cv.line([(0, 872), (W, 872)], INK, 2.0, caps=False)
    cv.line([(0, 875), (W, 875)], TEAL_L, 1.2, caps=False)
    # floor
    cv.rect(0, 900, W, H, fill=FLOOR, ol=None)
    fg = noise(rng, W // 10, 186, 2).resize((W, 186), Image.BICUBIC)
    cv.paste1x(Image.new("RGB", (W, 186), TIMBER), 0, 900,
               fg.point([int(clamp((v - 120) / 135.0, 0, 1) * 70) for v in range(256)]))
    cv.line([(0, 900), (W, 900)], INK, 3.4, caps=False)
    for y, off in ((942, 0), (996, 130), (1050, 60)):
        cv.line([(0, y), (W, y)], mix(FLOOR, INK, 0.38), 1.6, caps=False)
        for x in range(off + 90, W, 330):
            yb = y - (42 if y == 942 else 54)
            cv.line([(x, yb + 2), (x, y - 1)], mix(FLOOR, INK, 0.3), 1.3, caps=False)
    # the floor darkens away from the light
    fm = Image.linear_gradient("L").resize((W, 186)).point([int(v * 0.35) for v in range(256)])
    cv.paste1x(Image.new("RGB", (W, 186), NAVY), 0, 900, fm)
    return cv


def picture_wire(cv, x0, x1, y_hook):
    """Two hanging wires from the picture rail to a frame top."""
    for x in (x0, x1):
        cv.line([(x, PIC_RAIL + 10), (x + (12 if x == x0 else -12), y_hook)], INK, 1.3, caps=False)
        cv.rrect(x - 4, PIC_RAIL + 4, x + 4, PIC_RAIL + 16, 2, fill=BRASS_D, ol=INK, w=1.2)


def frame_shadow(cv, box, off=(6, 8), blur=7, alpha=80):
    x0, y0, x1, y1 = box

    def fn(d, o):
        d.rectangle([x0 + o[0], y0 + o[1], x1 + o[0], y1 + o[1]], fill=255)
    cv.shadow(fn, off, blur, alpha)


# ---------------------------------------------------------------- the seated outline
PLAN_PAPER = (220, 100, 1220, 900)      # close-up plan paper rect
PLAN_INSET = (130, 170, 430, 550)       # room-scale station plan inset


def body_parts():
    """The seated human in close-up plan coordinates. Returns (union_polys, front_polys, inner_lines)."""
    head = ellipse_pts(720, 230, 84, 92, 80)
    neck = [(684, 300), (756, 300), (762, 352), (678, 352)]
    torso = smooth_closed([(720, 338), (800, 344), (880, 356), (926, 384), (940, 430), (932, 500),
                           (900, 560), (872, 640), (868, 712), (720, 724), (572, 712), (568, 640),
                           (540, 560), (508, 500), (500, 430), (514, 384), (560, 356), (640, 344)], 8)
    lap = smooth_closed([(540, 700), (900, 700), (956, 726), (976, 790), (952, 834), (880, 846), (800, 842),
                         (720, 836), (640, 842), (560, 846), (488, 834), (464, 790), (484, 726)], 8)
    shin_l = [(556, 820), (652, 822), (644, 930), (566, 930)]
    shin_r = [(788, 822), (884, 820), (874, 930), (796, 930)]
    arm_l = smooth_closed([(512, 392), (548, 396), (560, 470), (566, 560), (600, 640), (650, 718),
                           (668, 752), (640, 772), (596, 768), (560, 716), (520, 640), (500, 560),
                           (494, 470)], 8)
    arm_r = [(1440 - x, y) for (x, y) in arm_l]
    union = [head, neck, torso, lap, shin_l, shin_r, arm_l, arm_r]
    front = [arm_l, arm_r]
    inner = [
        smooth_open([(690, 352), (720, 362), (750, 352)], 6),  # collar
    ]
    return union, front, inner


def paint_body(cv, T, scale_w, wash_alpha, clip_box, ink_w):
    """The seated outline drawn out of the plan's own drafting: yellowed plan paper inside, a
    navy contour that thickens on its shadow side, rooms and corridors bent into skull, ribs,
    spine and hips."""
    union, front, inner = body_parts()
    tw, th = cv.w * SS, cv.h * SS
    def mask_of(polys):
        m = Image.new("L", (tw, th), 0)
        d = ImageDraw.Draw(m)
        for p in polys:
            d.polygon([(x * SS, y * SS) for x, y in (T(q) for q in p)], fill=255)
        return m
    clip = Image.new("L", (tw, th), 0)
    ImageDraw.Draw(clip).rectangle([clip_box[0] * SS, clip_box[1] * SS, clip_box[2] * SS - 1, clip_box[3] * SS - 1],
                                   fill=255)
    um = ImageChops.multiply(mask_of(union), clip)
    # fill: the plan paper itself, yellowed where the body lies
    wash = Image.new("RGBA", (tw, th), rgba(mix(PAPER2, (206, 178, 120), 0.42), 255))
    wash.putalpha(um.point([int(v * wash_alpha) for v in range(256)]))
    cv.im.alpha_composite(wash)
    # drafting inside the body: corridor spine, rib walls with door gaps, skull and hip rooms
    lines = Image.new("L", (tw, th), 0)
    d = ImageDraw.Draw(lines)
    lw = max(1, int(round(ink_w * SS * 0.42)))
    def L(pts):
        d.line([(x * SS, y * SS) for x, y in (T(q) for q in pts)], fill=255, width=lw, joint="curve")
    L([(708, 352), (706, 520), (710, 712)])
    L([(732, 352), (734, 520), (730, 712)])
    for k, y in enumerate((410, 462, 514, 566)):
        sag = 10 + k * 4
        L([(560 + k * 6, y + sag), (620, y + 4), (690, y)])
        L([(750, y), (820, y + 4), (880 - k * 6, y + sag)])
    L(smooth_open([(668, 180), (720, 160), (772, 180), (784, 236), (760, 286), (680, 286), (656, 236), (668, 180)], 6))
    L([(700, 286), (700, 300)]); L([(740, 286), (740, 300)])
    L(smooth_open([(560, 652), (720, 640), (880, 652), (900, 700)], 6))
    L(smooth_open([(540, 652), (528, 700)], 4))
    L(smooth_open([(560, 380), (520, 396), (504, 440)], 6))
    L(smooth_open([(880, 380), (920, 396), (936, 440)], 6))
    lines = ImageChops.multiply(ImageChops.multiply(lines, um), clip)
    ink = Image.new("RGBA", (tw, th), rgba(NAVY, 255))
    ink.putalpha(lines.point([int(v * 0.8) for v in range(256)]))
    cv.im.alpha_composite(ink)
    # contour: thin on the lit side, heavy on the shadow side
    def edge(mask, wpx):
        r = wpx * SS / 2.0
        b = mask.filter(ImageFilter.GaussianBlur(r * 0.75))
        return ImageChops.subtract(b.point([255 if v > 18 else int(v * 255 / 18) for v in range(256)]),
                                   b.point([255 if v > 236 else 0 for v in range(256)]))
    fm = ImageChops.multiply(mask_of(front), clip)
    thin = ImageChops.lighter(edge(um, ink_w * 0.6), edge(fm, ink_w * 0.5))
    thick = ImageChops.lighter(edge(um, ink_w * 1.5), edge(fm, ink_w * 1.1))
    g = Image.linear_gradient("L").rotate(-35, expand=False).resize((tw, th))
    e = Image.composite(thick, thin, g)
    for ln in inner:
        ImageDraw.Draw(e).line([(x * SS, y * SS) for x, y in (T(q) for q in ln)], fill=255,
                               width=int(round(ink_w * SS * 0.6)), joint="curve")
    e = ImageChops.multiply(e, clip)
    ink = Image.new("RGBA", (tw, th), rgba(INK, 255))
    ink.putalpha(e)
    cv.im.alpha_composite(ink)


def T_room(p):
    x, y = p
    return (130 + (x - 220) * 0.3, 550 - (900 - y) * 0.42)


# ---------------------------------------------------------------- WALL A
def plan_blocks(cv):
    """Faint unlabelled room blocks on the station plan (they are the plan zones, unexplained)."""
    lay = cv.layer()
    col = rgba(NAVY, 255)
    zones = [(620, 140, 820, 320), (500, 340, 940, 550), (640, 560, 800, 690), (460, 710, 980, 840)]
    for (a, b, c, d) in zones:
        x0, y0 = T_room((a, b))
        x1, y1 = T_room((c, d))
        lay.rect(x0, y0, x1, y1, fill=None, ol=col, w=2.4)
    for box in [(150, 330, 200, 396), (360, 330, 410, 396), (150, 410, 196, 452), (364, 410, 410, 452),
                (176, 196, 236, 226), (324, 196, 384, 226)]:
        lay.rect(*box, fill=None, ol=col, w=2.0)
    lay.line([(280, 525), (280, 548)], col, 2.0)
    lay.line([(200, 470), (150, 470), (150, 400)], col, 1.8)
    lay.line([(358, 470), (410, 470), (410, 400)], col, 1.8)
    for (x, y) in ((280, 300), (280, 360)):
        lay.line([(x, y), (x, y + 40)], col, 1.6)
    for yy in range(182, 548, 12):
        lay.line([(136, yy), (424, yy)], rgba(TEAL, 140), 0.6, caps=False)
    cv.comp(lay, 0.60)


def station_plan(cv):
    picture_wire(cv, 170, 390, 150)
    frame_shadow(cv, (110, 150, 450, 570))
    cv.rect(110, 150, 450, 570, fill=TIMBER_D, ol=INK, w=3.4, shade=True)
    cv.rect(118, 158, 442, 562, fill=None, ol=TIMBER_L, w=1.5)
    cv.rect(130, 170, 430, 550, fill=PAPER2, ol=INK, w=2)
    plan_blocks(cv)


def compass_dial(cv, cx, cy, r):
    def fn(d, o):
        d.ellipse([cx - r + o[0], cy - r + o[1], cx + r + o[0], cy + r + o[1]], fill=255)
    picture_wire(cv, cx - 40, cx + 40, cy - r + 6)
    cv.shadow(fn, (7, 9), 7, 95)
    cv.ell(cx, cy, r, r, fill=BRASS, ol=INK, w=3.4)
    cv.ell(cx, cy, r - 6, r - 6, fill=None, ol=BRASS_L, w=2)
    cv.ell(cx, cy, r - 14, r - 14, fill=BONE, ol=INK, w=2.5)
    for k in range(64):
        a = 2 * math.pi * k / 64
        l = 8 if k % 4 == 0 else 4
        cv.line([(cx + (r - 14) * math.cos(a), cy + (r - 14) * math.sin(a)),
                 (cx + (r - 14 - l) * math.cos(a), cy + (r - 14 - l) * math.sin(a))], INK, 1.2, caps=False)
    cv.ell(cx, cy, r - 28, r - 28, fill=None, ol=mix(BONE, INK, 0.4), w=1)
    # sixteen-point star: navy main points, teal half, brass quarter
    for k in range(16):
        a = -math.pi / 2 + 2 * math.pi * k / 16
        L = (r - 22) if k % 4 == 0 else (r - 40) if k % 2 == 0 else (r - 52)
        wdt = 11 if k % 4 == 0 else 8 if k % 2 == 0 else 6
        tip = (cx + L * math.cos(a), cy + L * math.sin(a))
        lft = (cx + wdt * math.cos(a - math.pi / 2), cy + wdt * math.sin(a - math.pi / 2))
        rgt = (cx + wdt * math.cos(a + math.pi / 2), cy + wdt * math.sin(a + math.pi / 2))
        colA = NAVY if k % 4 == 0 else TEAL if k % 2 == 0 else BRASS
        colB = mix(colA, BONE, 0.55)
        cv.poly([(cx, cy), lft, tip], fill=colA, ol=INK, w=1.2)
        cv.poly([(cx, cy), tip, rgt], fill=colB, ol=INK, w=1.2)
    cv.ell(cx, cy, 7, 7, fill=BRASS, ol=INK, w=1.5)


def corridor_door(cv):
    frame_shadow(cv, (1136, 404, 1354, 900), (8, 6), 8, 90)
    cv.rect(1136, 404, 1354, 900, fill=TEAL_D, ol=INK, w=3.4, shade=True)
    cv.line([(1142, 410), (1348, 410)], TEAL_L, 1.4, caps=False)
    # the crack: the leaf stands a finger's width off the latch side
    cv.rect(1150, 420, 1340, 900, fill=NAVY, ol=None)
    cv.rect(1150, 420, 1334, 900, fill=TEAL, ol=INK, w=3, shade=True)
    cv.rect(1334, 420, 1341, 900, fill=(9, 13, 19), ol=None)
    cv.line([(1333, 422), (1333, 898)], TEAL_L, 1.2, caps=False)
    for (y0, y1) in ((446, 640), (680, 872)):
        cv.rect(1172, y0, 1312, y1, fill=TEAL_D, ol=INK, w=2.5)
        cv.rect(1182, y0 + 10, 1302, y1 - 10, fill=TEAL, ol=INK, w=1.5)
        cv.line([(1184, y0 + 12), (1300, y0 + 12)], TEAL_L, 1.2, caps=False)
    cv.rrect(1300, 646, 1318, 702, 4, fill=BRASS, ol=INK, w=2)
    cv.ell(1309, 664, 7, 7, fill=BRASS_L, ol=INK, w=1.5)
    cv.ell(1309, 690, 2.5, 4, fill=INK, ol=None, w=0)
    cv.rect(1336, 470, 1352, 500, fill=BRASS_D, ol=INK, w=1.5)
    cv.rect(1336, 800, 1352, 830, fill=BRASS_D, ol=INK, w=1.5)


def spring_clip(cv, cx, top, jaw_y, holding=False, scale=1.0):
    """A brass bulldog clip hanging from a wire loop; jaws at jaw_y."""
    s = scale
    cv.ell(cx, top + 10 * s, 15 * s, 12 * s, fill=None, ol=INK, w=4.5 * s)
    cv.ell(cx, top + 10 * s, 15 * s, 12 * s, fill=None, ol=BRASS_L, w=2 * s)
    body = [(cx - 36 * s, top + 22 * s), (cx + 36 * s, top + 22 * s), (cx + 30 * s, jaw_y - 6 * s),
            (cx - 30 * s, jaw_y - 6 * s)]
    cv.poly(body, fill=BRASS, ol=INK, w=2.5 * s)
    cv.line([(cx - 32 * s, top + 27 * s), (cx + 32 * s, top + 27 * s)], BRASS_L, 2 * s, caps=False)
    cv.ell(cx, top + 34 * s, 7 * s, 4 * s, fill=BRASS_D, ol=INK, w=1.5 * s)
    cv.rect(cx - 32 * s, jaw_y - 7 * s, cx + 32 * s, jaw_y, fill=BRASS_D, ol=INK, w=2 * s)
    if not holding:
        cv.line([(cx - 28 * s, jaw_y + 1), (cx + 28 * s, jaw_y + 1)], INK, 1.5 * s, caps=False)


def registration_board(cv):
    frame_shadow(cv, (520, 240, 1080, 744), (7, 9), 8, 90)
    cv.rect(520, 240, 1080, 744, fill=BRASS, ol=INK, w=3.6)
    cv.line([(526, 246), (1074, 246)], BRASS_L, 2, caps=False)
    cv.line([(526, 246), (526, 738)], BRASS_L, 2, caps=False)
    cv.line([(526, 738), (1074, 738)], BRASS_D, 2.5, caps=False)
    cv.rect(536, 256, 1064, 728, fill=BONE, ol=INK, w=2.5)
    for (x, y) in ((528, 248), (1072, 248), (528, 736), (1072, 736), (800, 248), (800, 736)):
        screw(cv, x, y, 3.0)
    # the table sheet
    sh = cv.layer()
    sh.rect(560, 266, 1040, 714, fill=PAPER, ol=INK, w=2)
    cv.comp(sh)
    cv.rect(562, 268, 1038, 712, fill=None, ol=mix(PAPER, INK, 0.12), w=1)
    # faint contour washes: unlabelled coast and depth curves
    rng = rng_for("A_base:washes")
    lay = cv.layer()
    for k in range(7):
        y0 = 330 + k * 52
        pts = []
        ph = rng.uniform(0, 6.28)
        for i in range(25):
            x = 572 + i * 19.5
            pts.append((x, y0 + 18 * math.sin(i * 0.38 + ph) + 9 * math.sin(i * 0.9 + ph * 2)))
        lay.line(pts, rgba(TEAL, 255), 2.2 if k % 3 == 0 else 1.3, caps=False)
    coast = smooth_open([(572, 300), (640, 312), (700, 290), (760, 318), (820, 300), (880, 326),
                         (940, 310), (1028, 330)], 8)
    lay.poly(coast + [(1028, 276), (572, 276)], fill=rgba(COPPER, 255), ol=None)
    cv.comp(lay, 0.22)
    for (x, y) in ((572, 278), (1028, 278), (572, 702), (1028, 702)):
        cv.ell(x, y, 5, 5, fill=BRASS, ol=INK, w=1.5)
        cv.ell(x - 1.5, y - 1.5, 1.6, 1.6, fill=BRASS_L, ol=None, w=0)


def top_rail(cv):
    for x in (556, 1044):
        cv.rect(x - 5, 204, x + 5, 241, fill=BRASS_D, ol=INK, w=2)
    cv.rrect(516, 194, 1084, 208, 5, fill=BRASS, ol=INK, w=2.5)
    cv.line([(522, 198), (1078, 198)], BRASS_L, 1.6, caps=False)
    for x in (516, 1084):
        cv.ell(x, 201, 8, 8, fill=BRASS, ol=INK, w=2)


def blank_tag(cv, x0, y0, ang=-6):
    pts = [(x0, y0 + 8), (x0 + 6, y0), (x0 + 22, y0), (x0 + 28, y0 + 8), (x0 + 28, y0 + 44), (x0, y0 + 44)]
    pts = rot(pts, x0 + 14, y0, ang)
    cv.poly(pts, fill=PAPER2, ol=INK, w=1.8)
    hx, hy = rot([(x0 + 14, y0 + 8)], x0 + 14, y0, ang)[0]
    cv.ell(hx, hy, 4, 4, fill=BRASS_L, ol=INK, w=1.2)
    cv.ell(hx, hy, 1.6, 1.6, fill=INK, ol=None, w=0)
    return hx, hy


def clip_tin(cv, open_lid=True):
    """Sits under the table: a stencilled brass tin, lid hinged back, a fan of clips standing up."""
    x0, y0, x1, y1 = 566, 792, 704, 858
    cv.shadow(lambda d, o: d.rectangle([x0 + o[0], y0 + o[1], x1 + o[0], y1 + o[1]], fill=255), (7, 5), 6, 95)
    # the lid, hinged at the back edge and leaning against the wainscot
    lid = [(x0 - 2, y0 - 4), (x1 + 2, y0 - 4), (x1 - 6, y0 - 46), (x0 + 6, y0 - 46)]
    cv.poly(lid, fill=BRASS_D, ol=INK, w=2.4)
    cv.line([(x0 + 10, y0 - 40), (x1 - 10, y0 - 40)], BRASS_L, 1.6, caps=False)
    cv.line([(x0 + 4, y0 - 12), (x1 - 4, y0 - 12)], mix(BRASS_D, NAVY, 0.35), 2.2, caps=False)
    # inside dark
    cv.rect(x0 + 3, y0 - 6, x1 - 3, y0 + 4, fill=(16, 20, 26), ol=None)
    # a fan of bulldog clips standing in the tin
    for k, ang in enumerate((-30, -15, 0, 14, 28)):
        cx = 600 + k * 17
        body = rot([(cx - 9, y0 - 30), (cx + 9, y0 - 30), (cx + 8, y0 + 2), (cx - 8, y0 + 2)], cx, y0 + 2, ang)
        cv.poly(body, fill=BRASS_L if k % 2 == 0 else BRASS, ol=INK, w=1.6)
        jaw = rot([(cx - 9, y0 - 30), (cx + 9, y0 - 30), (cx + 9, y0 - 25), (cx - 9, y0 - 25)], cx, y0 + 2, ang)
        cv.poly(jaw, fill=BRASS_D, ol=INK, w=1.2)
        lx, ly = rot([(cx, y0 - 36)], cx, y0 + 2, ang)[0]
        cv.ell(lx, ly, 6, 5, fill=None, ol=INK, w=2.2)
        cv.ell(lx, ly, 6, 5, fill=None, ol=BRASS_L, w=0.9)
    # the box
    cv.rect(x0, y0, x1, y1, fill=BRASS, ol=INK, w=2.8, shade=True)
    cv.line([(x0 + 2, y0 + 6), (x1 - 2, y0 + 6)], BRASS_D, 2.2, caps=False)
    # stencil: a broad arrow and three bars, sprayed through a card
    st = cv.layer()
    st.poly([(616, 816), (626, 838), (606, 838)], fill=rgba(NAVY, 255), ol=None)
    st.rect(613, 836, 619, 850, fill=rgba(NAVY, 255), ol=None)
    for k in range(3):
        st.rect(636 + k * 14, 818, 645 + k * 14, 850, fill=rgba(NAVY, 255), ol=None)
    st.rect(600, 812, 684, 854, fill=None, ol=rgba(NAVY, 255), w=1.4)
    cv.comp(st, 0.62)


def chart_lamp(cv):
    """A brass chart lamp hung from the beam on a rod, shade over the board."""
    cx = 760
    cv.rect(cx - 16, BEAM_Y, cx + 16, BEAM_Y + 10, fill=BRASS_D, ol=INK, w=1.8)
    cv.rect(cx - 3, BEAM_Y + 10, cx + 3, 104, fill=BRASS_D, ol=INK, w=1.4)
    cv.rrect(cx - 12, 98, cx + 12, 116, 4, fill=BRASS, ol=INK, w=2)
    cv.shadow(lambda d, o: d.polygon([(cx - 26 + o[0], 112 + o[1]), (cx + 26 + o[0], 112 + o[1]),
                                      (cx + 92 + o[0], 166 + o[1]), (cx - 92 + o[0], 166 + o[1])], fill=255), (6, 8), 6, 80)
    # the bulb glowing under the rim
    glow = cv.layer()
    glow.ell(cx, 168, 80, 13, fill=rgba((252, 228, 168), 255), ol=None, w=0)
    cv.comp(glow, 0.95)
    shade = [(cx - 26, 112), (cx + 26, 112), (cx + 94, 166), (cx - 94, 166)]
    cv.poly(shade, fill=BRASS, ol=None)
    lay = cv.layer()
    lay.poly([(cx + 4, 112), (cx + 26, 112), (cx + 94, 166), (cx + 40, 166)], fill=rgba(BRASS_D, 255), ol=None)
    lay.poly([(cx - 20, 113), (cx - 8, 113), (cx - 46, 165), (cx - 66, 165)], fill=rgba(BRASS_POL, 255), ol=None)
    lay.poly([(cx + 26, 112), (cx + 30, 112), (cx + 94, 162), (cx + 94, 166)], fill=rgba(mix(BRASS_D, NAVY, 0.4), 255), ol=None)
    cv.comp(lay)
    cv.poly(shade, fill=None, ol=INK, w=2.8)
    cv.rrect(cx - 96, 162, cx + 96, 172, 4, fill=BRASS_D, ol=INK, w=2.2)
    cv.ell(cx, 174, 16, 7, fill=(254, 240, 200), ol=INK, w=1.2)


def paint_A_base():
    name = "A_base"
    cv = room_shell(name)
    station_plan(cv)
    compass_dial(cv, 1240, 250, 95)
    corridor_door(cv)
    # legs and stretcher behind the ledge
    for x0 in (536, 1040):
        cv.shadow(lambda d, o, x0=x0: d.rectangle([x0 + o[0], 756 + o[1], x0 + 24 + o[0], 908 + o[1]], fill=255), (8, 3), 5, 90)
        cv.rect(x0, 756, x0 + 24, 908, fill=TIMBER, ol=INK, w=2.8, shade=True)
        cv.line([(x0 + 5, 760), (x0 + 5, 904)], TIMBER_L, 1.4, caps=False)
    cv.rect(560, 856, 1040, 868, fill=TIMBER_D, ol=INK, w=2.2, shade=True)
    registration_board(cv)
    top_rail(cv)
    spring_clip(cv, 935, 186, 246)
    # the blank tag on a short thread from the clip's wire
    cv.line([(946, 194), (978, 214)], INK, 1.2, caps=False)
    blank_tag(cv, 966, 210, -10)
    # ledge
    cv.shadow(lambda d, o: d.rectangle([498 + o[0], 744 + o[1], 1102 + o[0], 760 + o[1]], fill=255), (0, 6), 5, 80)
    cv.rect(498, 744, 1102, 760, fill=TIMBER, ol=INK, w=2.8)
    cv.line([(500, 757), (1100, 757)], TIMBER_D, 2.0, caps=False)
    cv.line([(500, 747), (1100, 747)], TIMBER_L, 1.6, caps=False)
    clip_tin(cv)
    chart_lamp(cv)
    save(finish_rgb(cv, name), name, "RGB")


def tracing_sheet_room(cv, alpha):
    lay = cv.layer()
    lay.rect(560, 266, 1040, 714, fill=rgba((236, 238, 230), 255), ol=None)
    lay.rect(892, 238, 978, 268, fill=rgba((236, 238, 230), 255), ol=None)  # tongue held in the clip
    cv.comp(lay, alpha / 255.0)
    edge = cv.layer()
    edge.line([(560, 266), (892, 266), (892, 238), (978, 238), (978, 266), (1040, 266), (1040, 714),
               (560, 714), (560, 266)], rgba(INK, 255), 1.8, caps=False)
    edge.line([(800, 268), (800, 712)], rgba(SHEEN, 255), 2.2, caps=False)
    edge.line([(562, 490), (1038, 490)], rgba(SHEEN, 255), 2.2, caps=False)
    edge.line([(801.5, 268), (801.5, 712)], rgba(INK, 255), 0.8, caps=False)
    edge.line([(562, 491.5), (1038, 491.5)], rgba(INK, 255), 0.8, caps=False)
    cv.comp(edge, 0.55)
    tide = cv.layer()
    pts = [(562 + i * 12, 700 - 6 * math.sin(i * 0.7) - 3 * math.sin(i * 1.9)) for i in range(40)]
    tide.poly(pts + [(1038, 712), (562, 712)], fill=rgba(COPPER, 255), ol=None)
    tide.line(pts, rgba(COPPER_DD, 255), 1.6, caps=False)
    cv.comp(tide, 0.4)


def paint_A_composite():
    name = "A_composite"
    cv = Cv(W, H)
    tracing_sheet_room(cv, 120)
    spring_clip(cv, 935, 186, 246, holding=True)
    cv.line([(946, 194), (978, 214)], INK, 1.2, caps=False)
    blank_tag(cv, 966, 210, -10)
    # second clip, bottom-left corner
    cv.poly(rot([(548, 690), (590, 690), (588, 716), (550, 716)], 569, 703, -45), fill=BRASS, ol=INK, w=2)
    cv.ell(552, 686, 7, 6, fill=None, ol=INK, w=3)
    cv.ell(552, 686, 7, 6, fill=None, ol=BRASS_L, w=1.2)
    cv.line(rot([(552, 700), (586, 700)], 569, 703, -45), BRASS_L, 1.5, caps=False)
    save(finish_rgba(cv, name, 4), name, "RGBA")


BEND_BOWS = (-300, -170, -62, 34, 150, 320)
LH_CROSS = (680, 386)          # the lighthouse cross on the board sheet (view: SHEET_RECT + 0.8 * (150,150))
STAND_AT = (800, 712)          # the sheet's bottom edge, over the standing spot
SHEET_BOX = (560, 266, 1040, 714)


def drip(cv, pts, w0, w1, col=INK, beads=()):
    """An ink run: a polyline that swells from w0 to w1, with beads at given fractions."""
    n = len(pts) - 1
    for i in range(n):
        t = i / max(1, n - 1)
        cv.line([pts[i], pts[i + 1]], col, w0 + (w1 - w0) * t, caps=True)
    for f in beads:
        x, y = pts[int(f * n)]
        cv.ell(x, y, w1 * 0.9, w1 * 1.2, fill=col, ol=None, w=0)


def paint_A_compass_bent():
    """Band 4+: six heavy rhumb lines bow out of the lighthouse cross and meet at the sheet's
    bottom edge over the place she stands; one bleeds off the paper and runs to the floor."""
    name = "A_compass_bent"
    cv = Cv(W, H)
    cx, cy = LH_CROSS
    tx, ty = STAND_AT
    x0, y0, x1, y1 = SHEET_BOX
    chord = (tx - cx, ty - cy)
    cl = math.hypot(*chord)
    nx, ny = -chord[1] / cl, chord[0] / cl
    mx, my = (cx + tx) / 2, (cy + ty) / 2
    for k, bow in enumerate(BEND_BOWS):
        c = (mx + nx * bow, my + ny * bow)
        c = (min(max(c[0], x0 + 16), x1 - 16), min(max(c[1], y0 + 16), y1 - 16))   # the bend stays ON THE SHEET
        pts = [((1 - t) ** 2 * cx + 2 * (1 - t) * t * c[0] + t * t * tx,
                (1 - t) ** 2 * cy + 2 * (1 - t) * t * c[1] + t * t * ty) for t in [i / 100 for i in range(101)]]
        pts = pts[6:]
        cv.line(pts, INK, 5.6 - 0.25 * k, caps=True)
        # a rhumb-line arrowhead part-way down: every line points at the one place
        i = int(len(pts) * 0.72)
        (ax, ay), (bx, by) = pts[i - 3], pts[i]
        L = math.hypot(bx - ax, by - ay) or 1.0
        ux, uy = (bx - ax) / L, (by - ay) / L
        cv.poly([(bx + ux * 13, by + uy * 13), (bx - uy * 7, by + ux * 7), (bx + uy * 7, by - ux * 7)], fill=INK, ol=None)
    # the rose they leave from
    cv.ell(cx, cy, 20, 20, fill=None, ol=INK, w=3)
    cv.ell(cx, cy, 4, 4, fill=INK, ol=None, w=0)
    # where they meet, the ink pools and leaves the paper
    cv.ell(tx, ty - 2, 9, 6, fill=INK, ol=None, w=0)
    run = [(tx + 0.6 * math.sin(y * 0.09) + (y - ty) * 0.01, y) for y in range(int(ty), 884, 3)]
    drip(cv, run, 3.4, 5.6, INK, beads=(0.42, 0.7))
    cv.ell(run[-1][0], 886, 12, 4, fill=INK, ol=None, w=0)
    save(finish_rgba(cv, name, 3), name, "RGBA")


def paint_A_standing():
    """Band 5+: a dark wet place on the floor where someone stood at the table, edged by a
    tide-line stain climbing the skirting. Kept clear of the exit tabs and the subtitle bar."""
    name = "A_standing"
    rng = rng_for(name)
    cv = Cv(W, H)
    x0, x1 = 726, 876
    # the stain on the wainscot: wet darkening rising in an arch, a dull salt line on its crown
    crown = [(x, 812 - 26 * math.sin(math.pi * (x - x0 + 40) / (x1 - x0 + 80)) + 2.5 * math.sin(x * 0.11))
             for x in range(x0 - 40, x1 + 41, 4)]
    wet = cv.layer()
    wet.poly(crown + [(x1 + 40, 904), (x0 - 40, 904)], fill=rgba(WETDARK, 255), ol=None)
    wm = wet.im.getchannel("A").filter(ImageFilter.GaussianBlur(4 * SS))
    wet.im.putalpha(wm)
    cv.comp(wet, 0.5)
    salt = cv.layer()
    salt.line(crown, rgba((190, 192, 176), 255), 3.0, caps=True)
    cv.comp(salt, 0.55)
    # the place itself: two flat, toeless wet soles side by side on the boards, a thin
    # sea-glass rim of water round each, a damp halo joining them
    halo = cv.layer()
    halo.ell(800, 922, 92, 22, fill=rgba(WETDARK, 255), ol=None, w=0)
    hm = halo.im.getchannel("A").filter(ImageFilter.GaussianBlur(6 * SS))
    halo.im.putalpha(hm)
    cv.comp(halo, 0.45)
    for cx, lean in ((768, -1), (834, 1)):
        sole = smooth_closed([(cx - 20, 922), (cx - 16, 907), (cx + 2 * lean, 902), (cx + 18, 906), (cx + 22, 920),
                              (cx + 14, 936), (cx, 940), (cx - 14, 936)], 8)
        cv.poly(sole, fill=rgba(NAVY, 180), ol=None)
        cv.vloop(sole, rgba((150, 196, 182), 220), 1.8, taper=0.3)
        sheen = cv.layer()
        sheen.line([(cx - 10, 910), (cx + 6, 908)], rgba(SHEEN, 255), 1.8)
        cv.comp(sheen, 0.45)
    save(cv.down(), name, "RGBA")


def paint_A_buckle():
    """Band 3+: the pinned sheet's bottom edge buckles with damp and lifts off the board."""
    name = "A_buckle"
    rng = rng_for(name)
    cv = Cv(W, H)
    x0, y0, x1, y1 = SHEET_BOX
    ph = rng.uniform(0, 6.28)
    def h(x):
        return 7.0 * abs(math.sin((x - x0) * 0.021 + ph)) + 2.0 * math.sin(x * 0.07)
    # cockle shading: soft light and dark vertical bands rising from the edge
    lay = cv.layer()
    for x in range(int(x0) + 2, int(x1) - 2, 2):
        v = math.cos((x - x0) * 0.042 + 2 * ph)
        col = (250, 244, 226) if v > 0 else (120, 110, 90)
        top = y1 - 70 - 30 * abs(v)
        lay.line([(x, y1 - 2), (x, top)], rgba(col, int(150 * abs(v))), 2.2, caps=False)
    m = lay.im.getchannel("A")
    fade = Image.linear_gradient("L").resize((W * SS, H * SS))
    lay.im.putalpha(ImageChops.multiply(m, fade).filter(ImageFilter.GaussianBlur(5 * SS)))
    cv.comp(lay, 0.55)
    # the lifted lip: paper standing off the mount, with its shadow below
    lip = [(x, y1 + h(x)) for x in range(int(x0), int(x1) + 1, 4)]
    cv.shadow(lambda d, o: d.polygon([(x + o[0], y + o[1]) for x, y in lip] + [(x1, y1), (x0, y1)], fill=255), (2, 5), 3, 110)
    cv.poly(lip + [(x1, y1 - 4), (x0, y1 - 4)], fill=rgba(mix(PAPER, (196, 176, 130), 0.3), 255), ol=None)
    cv.line(lip, INK, 2.0, caps=False)
    save(finish_rgba(cv, name, 3), name, "RGBA")


def paint_A_fog():
    """Band 5+: the compass glass fogged from the inside, beaded at the rim."""
    name = "A_fog"
    rng = rng_for(name)
    cv = Cv(W, H)
    cx, cy, r = 1240, 250, 81
    fog = Image.new("L", (2 * r, 2 * r), 0)
    n = noise(rng, 2 * r, 2 * r, 18)
    ImageDraw.Draw(fog).ellipse([0, 0, 2 * r - 1, 2 * r - 1], fill=255)
    fog = ImageChops.multiply(fog, n.point([int(150 + v * 0.35) for v in range(256)])).filter(ImageFilter.GaussianBlur(2))
    cv.paste1x(Image.new("RGB", (2 * r, 2 * r), (226, 232, 226)), cx - r, cy - r, fog.point([int(v * 0.86) for v in range(256)]))
    for k in range(46):
        a = rng.uniform(0, 2 * math.pi)
        rr = r * (0.70 + 0.27 * rng.random())
        x, y = cx + rr * math.cos(a), cy + rr * math.sin(a)
        d = rng.uniform(1.6, 3.6)
        cv.ell(x, y, d, d * 1.15, fill=rgba((150, 166, 160), 200), ol=None, w=0)
        cv.ell(x - d * 0.3, y - d * 0.35, d * 0.4, d * 0.4, fill=rgba((250, 252, 248), 230), ol=None, w=0)
    for k in range(3):   # runs from the top inside the glass
        x = cx + rng.uniform(-50, 50)
        ys = cy - math.sqrt(max(0, r * r - (x - cx) ** 2)) + 4
        cv.line([(x, ys), (x + rng.uniform(-2, 2), ys + rng.uniform(30, 70))], rgba((140, 156, 150), 180), 2.2)
    save(cv.down(), name, "RGBA")


def paint_A_plan_body():
    name = "A_plan_body"
    cv = Cv(W, H)
    paint_body(cv, T_room, 0.3, 0.80, PLAN_INSET, 3.6)
    save(cv.down(), name, "RGBA")


# ---------------------------------------------------------------- WALL B: window
GLASS = (134, 174, 386, 566)


def sash(cv, band7_reflection=False):
    x0, y0, x1, y1 = GLASS
    cv.rect(x0, 365, x1, 377, fill=TEAL, ol=INK, w=2.2)
    cv.rect(255, y0, 265, y1, fill=TEAL, ol=INK, w=2.2)
    cv.line([(x0 + 2, 367), (x1 - 2, 367)], TEAL_L, 1.2, caps=False)
    cv.line([(257, y0 + 2), (257, y1 - 2)], TEAL_L, 1.2, caps=False)
    cv.ell(260, 362, 9, 5, fill=BRASS, ol=INK, w=1.5)  # sash lock
    cv.rect(x0, y0, x1, y1, fill=None, ol=INK, w=2.5)


def overcast(cv, rng, top, bottom, c_top, c_bot, n=5):
    """Low flat cloud decks: long soft bands a step lighter or darker than the sky, no outline."""
    lay = cv.layer()
    for k in range(n):
        y = top + 10 + k * (bottom - top - 10) / max(1, n - 1) + rng.uniform(-5, 5)
        x = rng.uniform(100, 220)
        w = rng.uniform(160, 300)
        h = rng.uniform(5, 10)
        col = mix(c_top, c_bot, 0.3 + 0.6 * k / max(1, n - 1))
        col = mix(col, (172, 180, 176) if k % 2 == 0 else (70, 82, 88), 0.35)
        pts = smooth_closed([(x - w / 2, y + h * 0.5), (x - w * 0.2, y - h * 0.6), (x + w * 0.25, y - h * 0.4),
                             (x + w / 2, y + h * 0.5), (x, y + h * 0.9)], 6)
        lay.poly(pts, fill=rgba(col, 255), ol=None)
    m = lay.im.getchannel("A").filter(ImageFilter.GaussianBlur(2 * SS))
    lay.im.putalpha(m)
    cv.comp(lay, 0.9)


def sky_clouds(cv, rng, top, bottom, c_sky, c_cloud, n=5, ink_a=0.35):
    lay = cv.layer()
    for k in range(n):
        y = top + 18 + k * (bottom - top - 30) / max(1, n - 1) + rng.uniform(-6, 6)
        x = rng.uniform(110, 300)
        w = rng.uniform(80, 170)
        h = rng.uniform(9, 16)
        pts = smooth_closed([(x - w / 2, y + h * 0.4), (x - w * 0.3, y - h * 0.4), (x - w * 0.05, y - h),
                             (x + w * 0.2, y - h * 0.6), (x + w * 0.45, y - h * 0.2), (x + w / 2, y + h * 0.4)], 6)
        lay.poly(pts, fill=rgba(c_cloud, 255), ol=rgba(INK, int(255 * ink_a)), w=1.2)
    cv.comp(lay)


def lighthouse(cv, x, base_y, h=42, col=(222, 224, 214), alpha=1.0, ang=0.0, light=False):
    lay = cv.layer()
    w0, w1 = 9, 6
    body = [(x - w0, base_y), (x + w0, base_y), (x + w1, base_y - h), (x - w1, base_y - h)]
    gal = [(x - 9, base_y - h), (x + 9, base_y - h), (x + 9, base_y - h - 3), (x - 9, base_y - h - 3)]
    lan = [(x - 5, base_y - h - 3), (x + 5, base_y - h - 3), (x + 5, base_y - h - 12), (x - 5, base_y - h - 12)]
    cap = [(x - 7, base_y - h - 12), (x + 7, base_y - h - 12), (x, base_y - h - 19)]
    band = [(x - 8.2, base_y - h * 0.45), (x + 8.2, base_y - h * 0.45), (x + 7.6, base_y - h * 0.62),
            (x - 7.6, base_y - h * 0.62)]
    R = lambda p: rot(p, x, base_y, ang)
    lay.poly(R(body), fill=rgba(col, 255), ol=rgba(INK, 255), w=1.5)
    lay.poly(R(band), fill=rgba(NAVY2, 255), ol=None)
    lay.poly(R(gal), fill=rgba(INK, 255), ol=rgba(INK, 255), w=1)
    lay.poly(R(lan), fill=rgba(AMBER if light else (90, 104, 108), 255), ol=rgba(INK, 255), w=1.2)
    lay.poly(R(cap), fill=rgba(INK, 255), ol=rgba(INK, 255), w=1)
    cv.comp(lay, alpha)


def waves(cv, rng, top, bottom, col, ink_a, sharp_near=True, spread=1.0, seed_shift=0):
    """Rows of long wavy strokes: ink trough line plus a pale crest, larger and wider apart near the glass."""
    lay = cv.layer()
    y = top + 5
    while y < bottom - 3:
        t = (y - top) / max(1.0, bottom - top)
        wl = 10 + 26 * t * spread           # wavelength
        amp = 0.8 + 3.2 * t
        x = 134 - rng.uniform(0, 60)
        while x < 386:
            L = rng.uniform(40, 120) * (0.6 + t)
            if rng.random() < 0.8:
                ph = rng.uniform(0, 6.28)
                n = max(6, int(L / 3))
                pts = [(x + L * i / n, y + amp * math.sin(2 * math.pi * (L * i / n) / wl + ph)) for i in range(n + 1)]
                lay.line(pts, rgba(INK, int(255 * ink_a * (0.5 + 0.5 * t))), 0.8 + 1.1 * t, caps=False)
                crest = [(px, py - 1.6 - 1.4 * t) for px, py in pts[n // 4: 3 * n // 4]]
                if len(crest) > 1:
                    lay.line(crest, rgba(col, 255), 0.7 + 0.9 * t, caps=False)
            x += L + rng.uniform(6, 30)
        y += 4 + 13 * t * spread
    cv.comp(lay)


def window_scene(band):
    """A full-plate RGBA, opaque only inside the glass: weather band 0..7 plus the sash."""
    rng = rng_for(f"B_window_{band}")
    cv = Cv(W, H)
    gx0, gy0, gx1, gy1 = GLASS
    gw, gh = gx1 - gx0, gy1 - gy0
    hz = 360
    if band in (0, 1, 2, 3):
        sky_top = [(104, 118, 120), (96, 108, 112), (88, 100, 104), (150, 158, 156)][band]
        sky_bot = [(140, 152, 148), (128, 138, 136), (116, 126, 126), (168, 174, 170)][band]
        sea_top = [(98, 120, 122), (84, 104, 108), (62, 82, 90), (150, 158, 156)][band]
        sea_bot = [(66, 90, 98), (54, 76, 86), (36, 54, 66), (62, 84, 94)][band]
        cv.paste1x(vgrad(gw, hz - gy0, sky_top, sky_bot), gx0, gy0)
        cv.paste1x(vgrad(gw, gy1 - hz, sea_top, sea_bot, 0.8 if band != 3 else 0.55), gx0, hz)
        if band < 3:
            overcast(cv, rng, gy0, hz - 30, sky_top, sky_bot, 5 + band)
            land = [(118, 136, 138), (122, 136, 138), (122, 134, 136)][band]
            lay = cv.layer()
            pts = smooth_open([(gx0, 344), (160, 338), (196, 342), (226, 351), (246, 360)], 6)
            lay.poly(pts + [(246, 361), (gx0, 361)], fill=rgba(land, 255), ol=rgba(INK, 140 - 40 * band), w=1.2)
            isl = smooth_open([(274, 361), (284, 352), (296, 346), (314, 348), (326, 356), (334, 361)], 6)
            lay.poly(isl + [(334, 361), (274, 361)], fill=rgba(mix((70, 88, 92), sky_bot, 0.25 * band), 255),
                     ol=rgba(INK, 200 - 50 * band), w=1.3)
            cv.comp(lay)
            lighthouse(cv, 300, 350, 30, alpha=[1.0, 0.85, 0.38][band])
            cv.line([(gx0, hz), (gx1, hz)], rgba(INK, 150 - 40 * band), 1.3, caps=False)
            waves(cv, rng, hz + 2, gy1, mix(sea_top, (220, 228, 222), 0.4), 0.8 - 0.15 * band)
            if band == 2:  # damp bloom from the lower sash corners
                m = Image.new("L", (W, H), 0)
                dm = ImageDraw.Draw(m)
                for (cx, cy) in ((gx0, gy1), (gx1, gy1), (255, gy1), (265, gy1)):
                    dm.ellipse([cx - 70, cy - 60, cx + 70, cy + 60], fill=255)
                m = m.filter(ImageFilter.GaussianBlur(26)).point([int(v * 0.55) for v in range(256)])
                bloom = Image.new("RGBA", (W, H), rgba((206, 214, 210), 255))
                bloom.putalpha(m)
                cv.im.alpha_composite(bloom.resize((W * SS, H * SS), Image.BICUBIC))
        else:  # band 3: haze swallows the horizon, near waves stay sharp
            hm = Image.linear_gradient("L").resize((gw, gh)).point(
                [int(255 * clamp((v / 255.0 - 0.36) / 0.30)) for v in range(256)])
            cv.paste1x(vgrad(gw, gh, (162, 168, 164), (160, 166, 162)), gx0, gy0,
                       hm.point([255 - v for v in range(256)]))
            waves(cv, rng, 372, gy1, (200, 210, 206), 1.0, spread=1.1)
    elif band == 4:  # the horizon stands impossibly high: a wall of sea
        cv.paste1x(vgrad(gw, 210 - gy0, (120, 132, 132), (150, 160, 156)), gx0, gy0)
        cv.paste1x(vgrad(gw, gy1 - 210, (70, 92, 98), (34, 52, 64), 0.9), gx0, 210)
        cv.line([(gx0, 210), (gx1, 210)], rgba(INK, 200), 1.6, caps=False)
        waves(cv, rng, 212, gy1, (140, 160, 160), 0.85, spread=0.8)
    elif band == 5:  # toneless: sea and sky the same grey, a faint seam
        cv.rect(gx0, gy0, gx1, gy1, fill=rgba((134, 140, 139), 255), ol=None)
        cv.line([(gx0, hz), (gx1, hz)], rgba(INK, 50), 1.2, caps=False)
        lay = cv.layer()
        for k in range(14):
            y = hz + 12 + k * 14 + rng.uniform(-3, 3)
            x = rng.uniform(140, 330)
            lay.line([(x + i * 6, y - 2.0 * math.sin(math.pi * i / 6)) for i in range(7)], rgba(INK, 255), 1.2,
                     caps=False)
        lay.line(smooth_open([(150, 260), (190, 252), (240, 258), (300, 250), (370, 256)], 6), rgba(INK, 255), 1.2)
        cv.comp(lay, 0.16)
    elif band == 6:  # dark, close; the lighthouse stands on the sky
        cv.paste1x(vgrad(gw, 300 - gy0, (54, 66, 72), (42, 56, 64)), gx0, gy0)
        cv.paste1x(vgrad(gw, gy1 - 300, (34, 48, 58), (16, 24, 34), 0.8), gx0, 300)
        cv.line([(gx0, 300), (gx1, 300)], rgba(INK, 200), 1.5, caps=False)
        lay = cv.layer()
        for k in range(6):
            y = 316 + k * 44
            pts = [(gx0 - 20 + i * 18, y - 14 * math.sin(i * 0.55 + k)) for i in range(17)]
            lay.line(pts, rgba((90, 112, 116), 255), 3.0, caps=False)
            lay.line([(px, py - 3) for px, py in pts], rgba(INK, 255), 1.6, caps=False)
        cv.comp(lay, 0.8)
        lighthouse(cv, 196, 250, 46, col=(232, 232, 222), ang=30, light=True)
    elif band == 7:  # something enormous, close to the glass: one slow pale curve across two panes
        cv.rect(gx0, gy0, gx1, gy1, fill=rgba((12, 18, 26), 255), ol=None)
        deep = cv.layer()
        deep.ell(300, 470, 170, 140, fill=rgba((24, 36, 46), 255), ol=None, w=0)
        dm = deep.im.getchannel("A").filter(ImageFilter.GaussianBlur(40 * SS))
        deep.im.putalpha(dm)
        cv.comp(deep, 0.9)
        curve = smooth_open([(gx0 - 20, 520), (170, 430), (230, 330), (300, 262), (gx1 + 20, 236)], 12)
        glow = cv.layer()
        glow.line(curve, rgba((169, 200, 184), 255), 22)
        gm = glow.im.getchannel("A").filter(ImageFilter.GaussianBlur(9 * SS))
        glow.im.putalpha(gm)
        cv.comp(glow, 0.22)
        arc = cv.layer()
        arc.line(curve, rgba((169, 200, 184), 255), 10)
        cv.comp(arc, 0.42)
        fine = cv.layer()
        fine.line([(x + 3, y + 9) for x, y in curve], rgba((169, 200, 184), 255), 2)
        cv.comp(fine, 0.18)
    # glass sheen + sash
    sh = cv.layer()
    sh.poly([(150, gy0), (196, gy0), (gx0, 300), (gx0, 240)], fill=rgba(SHEEN, 255), ol=None)
    sh.poly([(300, 377), (330, 377), (270, gy1), (240, gy1)], fill=rgba(SHEEN, 255), ol=None)
    cv.comp(sh, 0.06 if band < 7 else 0.03)
    sash(cv)
    img = cv.down()
    if band != 5:
        img = grain(img, rng_for(f"B_window_{band}:grain"), 5)
    return clip_to(img, *GLASS)


def rain_frame(tag):
    """Rain on the pane: straight 1 px slant streaks, a few beaded drops (no heads, no tails)."""
    rng = rng_for("B_rain_" + tag)
    cv = Cv(W, H)
    gx0, gy0, gx1, gy1 = GLASS
    for k in range(64):
        x = rng.uniform(gx0, gx1 + 30)
        y = rng.uniform(gy0 - 20, gy1)
        L = rng.uniform(16, 38)
        cv.line([(x, y), (x - L * 0.32, y + L)], rgba((196, 210, 206), 150), 1.4, caps=False)
    for k in range(18):
        x, y = rng.uniform(gx0 + 4, gx1 - 4), rng.uniform(gy0 + 4, gy1 - 4)
        r = rng.uniform(1.6, 3.0)
        cv.ell(x, y + 0.6, r, r * 1.15, fill=rgba((30, 42, 50), 120), ol=None, w=0)
        cv.ell(x, y, r * 0.8, r * 0.9, fill=rgba((150, 170, 168), 170), ol=None, w=0)
        cv.ell(x - r * 0.25, y - r * 0.3, r * 0.3, r * 0.3, fill=rgba((236, 242, 238), 230), ol=None, w=0)
    return clip_to(cv.down(), *GLASS)


# ---------------------------------------------------------------- WALL B: recorder
def wheel_housing(cv, cx, cy):
    cv.rrect(cx - 60, cy - 48, cx + 60, cy + 48, 8, fill=COPPER_D, ol=INK, w=2.5)
    cv.rrect(cx - 26, cy - 22, cx + 26, cy + 22, 3, fill=BRASS, ol=INK, w=2)
    cv.rect(cx - 18, cy - 14, cx + 18, cy + 14, fill=(20, 26, 32), ol=INK, w=1.5)
    cv.rect(cx - 14, cy - 10, cx + 14, cy + 10, fill=BONE, ol=None)
    cv.line([(cx - 14, cy - 6), (cx + 14, cy - 6)], mix(BONE, INK, 0.25), 1, caps=False)
    cv.line([(cx - 14, cy + 6), (cx + 14, cy + 6)], mix(BONE, INK, 0.25), 1, caps=False)
    for dy in (-36, 36):
        cv.ell(cx, cy + dy, 7, 7, fill=BRASS, ol=INK, w=1.6)
        cv.ell(cx - 2, cy + dy - 2, 2.2, 2.2, fill=BRASS_L, ol=None, w=0)
    cv.ell(cx - 44, cy, 10, 30, fill=BRASS_D, ol=INK, w=1.8)  # the wheel's knurled edge
    for k in range(7):
        y = cy - 24 + k * 8
        cv.line([(cx - 52, y), (cx - 36, y)], INK, 1, caps=False)


def slot_recess(cv, x0, y0, x1, y1):
    cv.rect(x0 - 4, y0 - 4, x1 + 4, y1 + 4, fill=BRASS, ol=INK, w=2)
    cv.rect(x0, y0, x1, y1, fill=(14, 20, 26), ol=INK, w=1.5)
    cv.line([(x0 + 2, y0 + 3), (x1 - 2, y0 + 3)], (40, 52, 60), 1.5, caps=False)


def record_plate(cv, x0, y0, x1, y1, tab=True):
    if tab:
        cx = (x0 + x1) / 2
        cv.rrect(cx - 12, y0 - 10, cx + 12, y0 + 4, 4, fill=BRASS_D, ol=INK, w=1.6)
        cv.ell(cx, y0 - 4, 4, 2.5, fill=(20, 24, 28), ol=None, w=0)
    cv.rrect(x0, y0, x1, y1, 3, fill=BRASS, ol=INK, w=2)
    cv.line([(x0 + 3, y0 + 3), (x1 - 3, y0 + 3)], BRASS_L, 1.5, caps=False)
    cv.line([(x0 + 3, y1 - 3), (x1 - 3, y1 - 3)], BRASS_D, 1.5, caps=False)
    cv.rect(x0 + 7, y0 + 7, x1 - 7, y1 - 7, fill=None, ol=mix(BRASS, INK, 0.35), w=1)


RACK_PLATES = [(1133, 436, 1207, 506), (1133, 526, 1207, 596), (1133, 616, 1207, 686)]
SLOTS = [(606, 708, 682, 772), (692, 708, 768, 772), (778, 708, 854, 772)]


def plate_rack(cv, empty=False):
    frame_shadow(cv, (1060, 420, 1280, 700), (6, 8), 6, 80)
    cv.rect(1060, 420, 1280, 700, fill=TIMBER, ol=INK, w=3.2, shade=True)
    cv.rect(1072, 432, 1268, 688, fill=TIMBER_D, ol=INK, w=1.5)
    for k in range(9):
        cv.line([(1076, 446 + k * 28), (1264, 446 + k * 28 + 3)], mix(TIMBER_D, TIMBER, 0.5), 1, caps=False)
    for (x0, y0, x1, y1) in RACK_PLATES:
        if empty:  # pale dust silhouettes where the plates hung so long
            ghost = cv.layer()
            ghost.rrect(x0 - 4, y0 - 4, x1 + 4, y1 + 4, 6, fill=rgba((196, 188, 166), 255), ol=None)
            ghost.rrect((x0 + x1) / 2 - 16, y0 - 16, (x0 + x1) / 2 + 16, y0, 4, fill=rgba((196, 188, 166), 255), ol=None)
            gm = ghost.im.getchannel("A").filter(ImageFilter.GaussianBlur(3 * SS))
            ghost.im.putalpha(gm)
            cv.comp(ghost, 0.55)
            cv.rrect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, 3, fill=mix(TIMBER_D, TIMBER, 0.6), ol=None)
            cv.ell((x0 + x1) / 2, y0 - 8, 3, 3, fill=IRON, ol=None, w=0)
        else:
            record_plate(cv, x0, y0, x1, y1)
        cv.rect(x0 - 12, y1, x1 + 12, y1 + 8, fill=BRASS, ol=INK, w=1.8)
    for (x, y) in ((1066, 426), (1274, 426), (1066, 694), (1274, 694)):
        screw(cv, x, y, 3)


def tide_recorder(cv):
    frame_shadow(cv, (470, 200, 1044, 880), (10, 6), 10, 105)
    # body
    cv.rect(480, 222, 980, 870, fill=COPPER_D, ol=INK, w=3.4, shade=True)
    cv.rect(480, 222, 500, 870, fill=COPPER, ol=None)
    cv.rect(960, 222, 980, 870, fill=COPPER_DD, ol=None)
    cv.rect(480, 222, 980, 870, fill=None, ol=INK, w=3.4)
    cv.rrect(466, 200, 994, 226, 4, fill=COPPER, ol=INK, w=3)
    cv.line([(470, 205), (990, 205)], COPPER_L, 1.8, caps=False)
    cv.rect(470, 856, 990, 880, fill=COPPER, ol=INK, w=3)
    for x in range(498, 975, 32):
        rivet(cv, x, 213, 3, COPPER_L)
        rivet(cv, x, 868, 3, COPPER_L)
    # drum window
    cv.rect(516, 240, 944, 420, fill=COPPER_DD, ol=INK, w=2.5)
    # gantry
    cv.rect(532, 228, 928, 242, fill=BRASS, ol=INK, w=2)
    cv.line([(534, 231), (926, 231)], BRASS_L, 1.4, caps=False)
    cv.rect(718, 226, 742, 246, fill=BRASS_D, ol=INK, w=1.8)
    cv.ell(730, 236, 4, 4, fill=INK, ol=None, w=0)
    # drum: bone paper on a cylinder, faint ruling
    cv.paste1x(vgrad(380, 60, mix(BONE, COPPER_D, 0.28), BONE, 0.7), 540, 250)
    cv.paste1x(vgrad(380, 60, BONE, mix(BONE, COPPER_D, 0.32), 1.6), 540, 310)
    lay = cv.layer()
    for k in range(1, 8):
        lay.line([(540, 250 + k * 15), (920, 250 + k * 15)], rgba(TEAL, 255), 1, caps=False)
    for k in range(1, 10):
        lay.line([(540 + k * 38, 252), (540 + k * 38, 368)], rgba(TEAL, 255), 1, caps=False)
    cv.comp(lay, 0.18)
    cv.rect(540, 250, 920, 370, fill=None, ol=INK, w=2)
    for x0 in (522, 920):
        cv.rect(x0, 246, x0 + 18, 374, fill=BRASS, ol=INK, w=2)
        cv.line([(x0 + 4, 250), (x0 + 4, 370)], BRASS_L, 1.4, caps=False)
    # the strip slot along the drum's lower right
    cv.rect(856, 368, 954, 375, fill=(10, 14, 18), ol=INK, w=1.2)
    # paper web over the writing platen (the nib rests here)
    cv.rect(556, 374, 850, 414, fill=mix(BONE, PAPER, 0.5), ol=INK, w=1.8)
    cv.line([(556, 377), (850, 377)], mix(BONE, COPPER_D, 0.3), 1.2, caps=False)
    cv.rect(546, 414, 860, 420, fill=BRASS_D, ol=INK, w=1.5)
    # calibration plate (blank)
    brass_plate(cv, 600, 432, 860, 482)
    # gauges
    for gx in (640, 820):
        cv.ell(gx, 521, 24, 24, fill=BRASS, ol=INK, w=2.2)
        cv.ell(gx, 521, 18, 18, fill=BONE, ol=INK, w=1.6)
        lay = cv.layer()
        lay.poly([(gx, 521)] + ellipse_pts(gx, 521, 17, 17, 12, -0.6, 0.6), fill=rgba(INK, 255), ol=None)
        cv.comp(lay, 0.22)
        cv.ell(gx, 521, 2.5, 2.5, fill=INK, ol=None, w=0)
    # the wheels (under the seal until the threshold)
    cv.rect(560, 560, 900, 680, fill=COPPER_DD, ol=INK, w=2)
    wheel_housing(cv, 650, 620)
    wheel_housing(cv, 810, 620)
    # three RECORD slots
    cv.rect(594, 696, 866, 784, fill=COPPER, ol=INK, w=2)
    for s in SLOTS:
        slot_recess(cv, *s)
    # RECORD key housing (small, blank)
    brass_plate(cv, 690, 798, 770, 834, screws=False)
    cv.ell(730, 816, 9, 9, fill=BRASS_L, ol=INK, w=1.8)
    # CALIBRATE lever: slotted guide on the right, polished worn handle up
    cv.rect(936, 440, 966, 712, fill=COPPER, ol=INK, w=2)
    cv.rect(946, 452, 956, 700, fill=(12, 16, 20), ol=None)
    cv.rect(942, 680, 960, 700, fill=BRASS_D, ol=INK, w=1.6)
    cv.rect(947, 458, 955, 690, fill=BRASS, ol=INK, w=1.5)
    cv.rrect(926, 444, 1018, 466, 10, fill=BRASS_POL, ol=INK, w=2.5)
    cv.line([(934, 450), (1008, 450)], (248, 232, 190), 2.2, caps=False)
    cv.line([(990, 460), (1012, 460)], BRASS, 2, caps=False)
    stilling_well(cv)


FLOAT_WELL = (996, 520, 1042, 868)     # the stilling well's glass (view draws the float in it)


def stilling_well(cv):
    """A copper stilling well bolted to the cabinet's right side: a glass slot shows the float."""
    x0, y0, x1, y1 = FLOAT_WELL
    cv.rect(980, 540, x0, 560, fill=COPPER_D, ol=INK, w=1.8)
    cv.rect(980, 820, x0, 840, fill=COPPER_D, ol=INK, w=1.8)
    cv.rect(x0 - 6, y0 - 14, x1 + 6, y1 + 12, fill=COPPER, ol=INK, w=2.8, shade=True)
    cv.rect(x0 + 6, y0 + 18, x1 - 6, y1 - 14, fill=(20, 30, 38), ol=INK, w=2)
    lay = cv.layer()   # the water column inside, darker toward the foot
    lay.paste1x(vgrad(int(x1 - x0 - 12), int(y1 - y0 - 32), (58, 86, 92), (18, 28, 36)), x0 + 6, y0 + 18)
    cv.comp(lay, 0.8)
    cv.line([(x0 + 10, y0 + 24), (x0 + 10, y1 - 20)], rgba(SHEEN, 120), 1.6, caps=False)
    for y in range(y0 + 2, y1, 64):
        cv.rect(x0 - 8, y, x1 + 8, y + 9, fill=BRASS_D, ol=INK, w=1.4)
    for y in (y0 - 6, y1 + 4):
        rivet(cv, x0 + 2, y, 3, COPPER_L)
        rivet(cv, x1 - 2, y, 3, COPPER_L)


def paint_B_float():
    """The copper float on its rod, drawn by the view at the well's tide level."""
    name = "B_float"
    cv = Cv(40, 70)
    cv.rect(18, 0, 22, 34, fill=BRASS, ol=INK, w=1.2)
    cv.ell(20, 48, 15, 15, fill=COPPER_WARM, ol=INK, w=2.2)
    cv.ell(20, 48, 15, 4.5, fill=None, ol=mix(COPPER_WARM, INK, 0.45), w=1.2)
    cv.ell(14, 41, 5, 3.5, fill=COPPER_WARM_L, ol=None, w=0)
    save(cv.down(), name, "RGBA")


def ceiling_pipe(cv):
    """A pipe run along under the beam and down into the recorder's top: it feeds on the sea."""
    x = 904
    cv.shadow(lambda d, o: (d.rectangle([x - 9 + o[0], 96 + o[1], W + o[0], 114 + o[1]], fill=255),
                            d.rectangle([x - 9 + o[0], 96 + o[1], x + 9 + o[0], 200 + o[1]], fill=255)), (6, 6), 5, 80)
    cv.rect(x - 9, 96, W + 4, 114, fill=COPPER, ol=INK, w=2.4, shade=False)
    cv.line([(x, 100), (W, 100)], COPPER_L, 1.6, caps=False)
    cv.rect(x - 9, 96, x + 9, 200, fill=COPPER, ol=INK, w=2.4)
    cv.line([(x - 4, 112), (x - 4, 196)], COPPER_L, 1.6, caps=False)
    cv.rrect(x - 16, 92, x + 16, 118, 6, fill=COPPER_D, ol=INK, w=2.2)
    for xx in (1040, 1230, 1420):
        cv.rect(xx - 4, BEAM_Y, xx + 4, 98, fill=IRON, ol=INK, w=1.4)
        cv.rect(xx - 12, 92, xx + 12, 118, fill=IRON_L, ol=INK, w=1.6)
    for yy in (150, 186):
        cv.rect(x - 13, yy, x + 13, yy + 7, fill=BRASS_D, ol=INK, w=1.4)
    # a valve wheel on the down-run
    cv.ell(x + 26, 150, 15, 15, fill=None, ol=INK, w=5)
    cv.ell(x + 26, 150, 15, 15, fill=None, ol=(150, 60, 48), w=2.6)
    cv.line([(x + 9, 150), (x + 26, 150)], INK, 3)
    cv.line([(x + 11, 150), (x + 41, 150)], (150, 60, 48), 1.6)
    cv.line([(x + 26, 135), (x + 26, 165)], (150, 60, 48), 1.6)


def sea_window_frame(cv):
    frame_shadow(cv, (110, 150, 410, 590), (8, 8), 8, 95)
    cv.rect(110, 150, 410, 590, fill=TEAL, ol=INK, w=3.4, shade=True)
    cv.rect(98, 140, 422, 156, fill=TEAL, ol=INK, w=2.5)
    cv.rect(98, 584, 422, 604, fill=TEAL, ol=INK, w=2.5)
    cv.line([(100, 587), (420, 587)], TEAL_L, 1.4, caps=False)
    cv.line([(116, 160), (116, 580)], TEAL_L, 1.4, caps=False)
    cv.rect(124, 164, 396, 576, fill=TEAL_D, ol=INK, w=2)


def paint_B_base(win0):
    name = "B_base"
    cv = room_shell(name)
    sea_window_frame(cv)
    ceiling_pipe(cv)
    tide_recorder(cv)
    plate_rack(cv)
    img = finish_rgb(cv, name)
    img = img.convert("RGBA")
    img.alpha_composite(win0)
    save(img, name, "RGB")


def seal_strip_room(cv, broken):
    """The paper closure seal across Rect(560,560,340,120) at room scale."""
    rng = rng_for("B_seal_" + ("broken" if broken else "intact"))
    x0, y0, x1, y1 = 564, 574, 896, 666
    if not broken:
        cv.shadow(lambda d, o: d.rectangle([x0 + o[0], y0 + o[1], x1 + o[0], y1 + o[1]], fill=255), (2, 3), 2.5, 60)
        cv.rect(x0, y0, x1, y1, fill=PAPER2, ol=INK, w=2)
        lay = cv.layer()
        for k in range(3):
            y = 590 + k * 22
            xs = 584 if k != 1 else 598
            pts = []
            x = xs
            while x < 690 - k * 8:
                pts.append((x, y + rng.uniform(-3.5, 3.5)))
                x += rng.uniform(3, 6)
            lay.line(pts, rgba(INK, 255), 1.4, caps=False)
            pts = []
            x = 772 + k * 6
            while x < 880:
                pts.append((x, y + rng.uniform(-3.5, 3.5)))
                x += rng.uniform(3, 6)
            lay.line(pts, rgba(INK, 255), 1.4, caps=False)
        cv.comp(lay, 0.75)
        wax_seal(cv, 730, 620, 22, split=False)
        return
    # broken: torn through the middle, both halves pushed outward toward the viewer
    tear_l = [(700 + rng.uniform(-6, 6), y0 + k * 9.2) for k in range(11)]
    tear_r = [(760 + rng.uniform(-6, 6), y0 + k * 9.2) for k in range(11)]
    # cast shadows beneath the curls
    def shf(d, o):
        d.polygon([(x0 + o[0], y0 + o[1]), (690 + o[0], y0 - 12 + o[1]), (726 + o[0], 620 + o[1]),
                   (690 + o[0], y1 + 14 + o[1]), (x0 + o[0], y1 + o[1])], fill=255)
        d.polygon([(x1 + o[0], y0 + o[1]), (770 + o[0], y0 - 12 + o[1]), (734 + o[0], 620 + o[1]),
                   (770 + o[0], y1 + 14 + o[1]), (x1 + o[0], y1 + o[1])], fill=255)
    cv.shadow(shf, (4, 9), 6, 150)
    for side in (-1, 1):
        base_x = x0 if side < 0 else x1
        tear = tear_l if side < 0 else tear_r
        # half outline: flat pasted part, then bulging toward the tear
        bulge = 14
        flat_end = 650 if side < 0 else 810
        top = [(base_x, y0), (flat_end, y0), (flat_end + side * -1 * 0 + (690 - flat_end if side < 0 else 770 - flat_end), y0 - bulge)]
        bot = [(flat_end + (690 - flat_end if side < 0 else 770 - flat_end), y1 + bulge), (flat_end, y1), (base_x, y1)]
        rim = [(x + (-side) * 0 + (10 if side < 0 else -10) * math.sin(math.pi * k / 10.0) * 2.4, y)
               for k, (x, y) in enumerate(tear)]
        rim = [(x, y0 - bulge + (y - y0) * (y1 - y0 + 2 * bulge) / (y1 - y0)) for (x, y) in rim]
        poly = top + rim + bot
        if side > 0:
            poly = [(base_x, y0), (flat_end, y0), (770, y0 - bulge)] + rim + [(770, y1 + bulge), (flat_end, y1),
                                                                               (base_x, y1)]
        else:
            poly = [(base_x, y0), (flat_end, y0), (690, y0 - bulge)] + rim + [(690, y1 + bulge), (flat_end, y1),
                                                                               (base_x, y1)]
        cv.poly(poly, fill=PAPER2, ol=INK, w=2)
        # the bulge light: paper lifting off the metal catches light near the tear
        lay = cv.layer()
        hx = 690 if side < 0 else 770
        lay.poly([(flat_end, y0 + 4), (hx - side * 2, y0 - bulge + 6), (hx - side * 2, y1 + bulge - 6),
                  (flat_end, y1 - 4)], fill=rgba((246, 240, 224), 255), ol=None)
        cv.comp(lay, 0.6)
        # the curled lip: the torn edge rolls toward the viewer
        lip = [(x + (-side) * 9, y) for (x, y) in rim]
        cv.poly(rim + list(reversed(lip)), fill=mix(PAPER, INK, 0.25), ol=INK, w=1.8)
        cv.line([(x + (-side) * 3, y) for (x, y) in rim], (250, 246, 234), 1.6, caps=False)
        # handwriting fragments survive on each half
        lay = cv.layer()
        for k in range(3):
            y = 592 + k * 22
            xs, xe = (586, 664 - k * 6) if side < 0 else (790 + k * 4, 880)
            pts, x = [], xs
            while x < xe:
                pts.append((x, y + rng.uniform(-3.5, 3.5)))
                x += rng.uniform(3, 6)
            lay.line(pts, rgba(INK, 255), 1.4, caps=False)
        cv.comp(lay, 0.75)
    wax_seal(cv, 730, 620, 22, split=True)


def wax_seal(cv, cx, cy, r, split, s=1.0):
    blob = smooth_closed([(cx + r * 1.05 * math.cos(a), cy + r * (0.95 + 0.08 * math.sin(3 * a)) * math.sin(a))
                          for a in [2 * math.pi * k / 9 for k in range(9)]], 6)
    if not split:
        cv.poly(blob, fill=WAX, ol=INK, w=2 * s)
        cv.ell(cx, cy, r * 0.62, r * 0.62, fill=WAX_D, ol=None, w=0)
        cv.ell(cx - r * 0.35, cy - r * 0.4, r * 0.22, r * 0.15, fill=WAX_L, ol=None, w=0)
        for dx in (-0.3, 0.0, 0.3):  # Venn's three cuts
            cv.line([(cx + dx * r - r * 0.14, cy - r * 0.42), (cx + dx * r + r * 0.14, cy + r * 0.42)],
                    (236, 214, 190), 2.2 * s, caps=False)
        return
    for side in (-1, 1):
        half = [(x + side * r * 0.75, y + (-4 if side < 0 else 3) * s) for (x, y) in blob
                if (x - cx) * side >= -r * 0.08]
        crack = [(cx + side * r * 0.75 + side * 2 * s, cy + r * (k / 4.0 - 0.5) * 2.0) for k in range(5)]
        crack = [(x + ((k % 2) * 2 - 1) * 3 * s, y) for k, (x, y) in enumerate(crack)]
        poly = sorted(half, key=lambda p: math.atan2(p[1] - cy, (p[0] - cx - side * r * 0.75) * side))
        cv.poly(poly + (crack if side < 0 else list(reversed(crack))), fill=WAX, ol=INK, w=2 * s)
        cv.line([(cx + side * r * 0.75 + side * 6 * s, cy - r * 0.4), (cx + side * r * 0.75 + side * 9 * s, cy + r * 0.4)],
                (236, 214, 190), 2.2 * s, caps=False)


def paint_B_pen():
    name = "B_pen"
    cv = Cv(160, 200)
    cv.line([(80, 20), (80, 172)], INK, 7)
    cv.line([(80, 20), (80, 172)], BRASS, 4)
    cv.line([(78.5, 30), (78.5, 166)], BRASS_L, 1.2, caps=False)
    cv.rect(66, 26, 94, 40, fill=BRASS_D, ol=INK, w=1.8)  # counterweight collar
    cv.ell(80, 20, 15, 15, fill=BRASS, ol=INK, w=2.5)
    cv.ell(80, 20, 5, 5, fill=INK, ol=None, w=0)
    cv.ell(76, 15, 4, 3, fill=BRASS_L, ol=None, w=0)
    cv.poly([(72, 168), (88, 168), (84, 182), (80, 191), (76, 182)], fill=NAVY, ol=INK, w=1.6)
    cv.line([(80, 172), (80, 188)], (120, 140, 150), 1, caps=False)
    save(cv.down(), name, "RGBA")


def paint_B_p05():
    name = "B_p05"
    cv = Cv(W, H)
    for (x0, y0, x1, y1) in SLOTS:
        record_plate(cv, x0 + 3, y0 + 6, x1 - 3, y1 - 2)
    plate_rack(cv, empty=True)
    save(finish_rgba(cv, name, 6), name, "RGBA")


def paint_B_strip():
    name = "B_strip"
    cv = Cv(W, H)
    x0, x1 = 866, 944
    cv.shadow(lambda d, o: d.rectangle([x0 + o[0], 372 + o[1], x1 + o[0], 640 + o[1]], fill=255), (5, 5), 4, 70)
    cv.rect(x0, 371, x1, 646, fill=BONE, ol=INK, w=2)
    cv.line([(x0 + 4, 380), (x0 + 4, 636)], (246, 242, 230), 1.2, caps=False)
    # the end rolls up toward the viewer: a small paper cylinder with its spiral showing
    cv.rrect(x0 - 2, 636, x1 + 2, 664, 14, fill=mix(BONE, INK, 0.1), ol=INK, w=2)
    cv.line([(x0 + 8, 642), (x1 - 12, 642)], (252, 248, 238), 1.8, caps=False)
    cv.line([(x0 + 8, 658), (x1 - 12, 658)], mix(BONE, INK, 0.3), 1.4, caps=False)
    cv.ell(x1 - 12, 650, 12, 13, fill=mix(BONE, INK, 0.05), ol=INK, w=1.8)
    cv.line([(x1 - 12 + 7 * math.cos(t) * (1 - t / 14), 650 + 7 * math.sin(t) * (1 - t / 14))
             for t in [i * 0.25 for i in range(48)]], INK, 1.2, caps=False)
    save(finish_rgba(cv, name, 4), name, "RGBA")


# ---------------------------------------------------------------- WALL C
OUTER_GLASS = (1020, 400, 1280, 660)


def water_body(rng, x0, y0, x1, y1):
    """A full window of seawater: no surface, no air, suspended specks, one caustic band."""
    w, h = x1 - x0, y1 - y0
    base = vgrad(w, h, (64, 104, 104), (20, 34, 48), 0.9)
    m = noise(rng, w, h, 40).point([int(clamp((v - 110) / 145.0) * 50) for v in range(256)])
    base.paste(Image.new("RGB", (w, h), (84, 122, 118)), (0, 0), m)
    img = base.convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    # light shafts slanting down from a surface that is not there
    sm = Image.new("L", (w, h), 0)
    ds = ImageDraw.Draw(sm)
    for k in range(4):
        x = rng.uniform(10, w - 40)
        wd = rng.uniform(14, 30)
        ds.polygon([(x, 0), (x + wd, 0), (x + wd + 70, h), (x + 50, h)], fill=255)
    sm = sm.filter(ImageFilter.GaussianBlur(9))
    sm = ImageChops.multiply(sm, Image.linear_gradient("L").resize((w, h)).point([255 - v for v in range(256)]))
    img.paste(Image.new("RGBA", (w, h), (120, 168, 158, 255)), (0, 0), sm.point([int(v * 0.5) for v in range(256)]))
    # caustic band: a faint net of light high in the pane
    cm = Image.new("L", (w, h), 0)
    dc = ImageDraw.Draw(cm)
    for k in range(5):
        ph = rng.uniform(0, 6.28)
        y0c = 34 + k * 7
        pts = [(x, y0c + 6 * math.sin(x * 0.07 + ph) + 3 * math.sin(x * 0.19 + ph * 1.7)) for x in range(0, w + 4, 4)]
        dc.line(pts, fill=255, width=2)
    cm = cm.filter(ImageFilter.GaussianBlur(1.0)).point([int(v * 0.62) for v in range(256)])
    img.paste(Image.new("RGBA", (w, h), (160, 206, 194, 255)), (0, 0), cm)
    for k in range(18):
        x, y = rng.uniform(0, w), rng.uniform(30, h)
        r = rng.choice((0.7, 0.9, 1.1, 1.4, 1.9))
        a = int(rng.uniform(60, 150) * (1.0 - 0.5 * y / h))
        col = (176, 204, 192, a) if rng.random() < 0.9 else (10, 18, 24, int(a * 0.8))
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)
    for k in range(7):  # a few drifting fibres
        x, y = rng.uniform(10, w - 10), rng.uniform(60, h - 10)
        an = rng.uniform(0, math.pi)
        L = rng.uniform(5, 12)
        d.line([(x, y), (x + L * math.cos(an), y + L * math.sin(an))], fill=(170, 190, 170, 120), width=1)
    # the surface: a hair of air at the very top, a bright meniscus, its dark underside
    d.rectangle([0, 0, w, 8], fill=(14, 20, 28, 255))
    surf = [(x, 9 + 1.2 * math.sin(x * 0.08)) for x in range(0, w + 2, 2)]
    d.line(surf, fill=(214, 236, 226, 255), width=3)
    d.line([(x, y + 3) for x, y in surf], fill=(30, 52, 60, 200), width=2)
    return img.convert("RGB")


def bulkhead(cv):
    """A riveted iron bulkhead let into the ceiling over the hatch, knee brackets at each end."""
    x0, x1 = 500, 1000
    cv.shadow(lambda d, o: d.rectangle([x0 + o[0], BEAM_Y + o[1], x1 + o[0], 132 + o[1]], fill=255), (6, 8), 7, 100)
    cv.rect(x0, BEAM_Y, x1, 124, fill=IRON, ol=INK, w=3, shade=True)
    cv.rect(x0 - 10, 120, x1 + 10, 134, fill=IRON_D, ol=INK, w=2.6)
    cv.line([(x0 + 4, BEAM_Y + 6), (x1 - 4, BEAM_Y + 6)], IRON_L, 1.6, caps=False)
    for x in range(x0 + 16, x1 - 8, 26):
        rivet(cv, x, BEAM_Y + 16, 3.6)
        rivet(cv, x, 112, 3.6)
    for xb, sgn in ((x0 + 8, 1), (x1 - 8, -1)):
        knee = [(xb, 134), (xb + sgn * 44, 134), (xb, 210)]
        cv.poly(knee, fill=IRON_D, ol=INK, w=2.4)
        rivet(cv, xb + sgn * 12, 150, 3.2)
        rivet(cv, xb + sgn * 8, 180, 3.2)
    # a salt run down from a seam
    run = cv.layer()
    run.line([(752, 134), (751, 170), (753, 214)], rgba((200, 204, 190), 255), 3.0)
    cv.comp(run, 0.45)


def paint_C_base():
    name = "C_base"
    rng = rng_for(name)
    cv = room_shell(name)
    cv.ell(320, 398, 8, 8, fill=BRASS, ol=INK, w=2)   # the rope peg (the rope is an overlay)
    bulkhead(cv)
    # the hatch frame's left jamb: a broad iron flange, the scratches are cut into it (view)
    cv.shadow(lambda d, o: d.rectangle([466 + o[0], 352 + o[1], 572 + o[0], 888 + o[1]], fill=255), (7, 6), 7, 100)
    cv.rect(466, 352, 572, 888, fill=IRON_L, ol=INK, w=3, shade=True)
    cv.rect(478, 366, 560, 874, fill=mix(IRON_L, (96, 108, 116), 0.5), ol=INK, w=1.6)
    for y in range(380, 870, 34):
        rivet(cv, 472 + 0, y, 3.4)
    for k in range(5):   # old wear on the metal: faint scuffs
        y = 400 + k * 90 + rng.uniform(-10, 10)
        cv.line([(484, y), (554, y + rng.uniform(-4, 4))], mix(IRON_L, SHEEN, 0.25), 1.0, caps=False)
    # the hatch: heavy riveted iron, wheel latch, shut
    frame_shadow(cv, (570, 360, 930, 880), (9, 6), 8, 110)
    cv.rect(570, 360, 930, 880, fill=IRON, ol=INK, w=3.4, shade=True)
    cv.line([(576, 366), (924, 366)], IRON_L, 2, caps=False)
    cv.line([(576, 366), (576, 874)], IRON_L, 2, caps=False)
    for x in range(586, 920, 28):
        rivet(cv, x, 376, 4)
        rivet(cv, x, 866, 4)
    for y in range(404, 850, 28):
        rivet(cv, 584, y, 4)
        rivet(cv, 916, y, 4)
    hatch_leaf(cv)
    # outer window: heavy square frame, full of the sea
    frame_shadow(cv, (1000, 380, 1300, 680), (8, 8), 8, 100)
    cv.rect(1000, 380, 1300, 680, fill=TEAL_D, ol=INK, w=3.4, shade=True)
    cv.rect(1008, 388, 1292, 672, fill=None, ol=TEAL_L, w=1.5)
    cv.rect(990, 672, 1310, 690, fill=TEAL, ol=INK, w=2.6)
    for (x, y) in ((1010, 390), (1290, 390), (1010, 670), (1290, 670), (1150, 390), (1150, 670), (1010, 530),
                   (1290, 530)):
        rivet(cv, x, y, 4, BRASS)
    img = finish_rgb(cv, name)
    water = water_body(rng_for("C_base:water"), *OUTER_GLASS)
    img.paste(water, OUTER_GLASS[:2])
    top = Cv(W, H)
    top.rect(*OUTER_GLASS, fill=None, ol=INK, w=2.5)
    sh = top.layer()
    sh.poly([(1040, 412), (1090, 412), (1020, 490), (1020, 450)], fill=rgba(SHEEN, 255), ol=None)
    top.comp(sh, 0.10)
    img = img.convert("RGBA")
    img.alpha_composite(top.down())
    save(img, name, "RGB")


def rope_coil(cv, wet):
    lay = cv.layer()
    col = mix(ROPE, WETDARK, 0.45) if wet else ROPE
    hi = mix((186, 172, 140), WETDARK, 0.35) if wet else (186, 172, 140)
    for k in range(5):
        rx = 50 - k * 3
        cy = 470 + k * 4
        pts = ellipse_pts(320 + (k - 2) * 2.5, cy, rx, 76 - k * 2, 64)
        lay.line(pts, rgba(INK, 255), 9, caps=False)
        lay.line(pts, rgba(col, 255), 6, caps=False)
        lay.line(ellipse_pts(320 + (k - 2) * 2.5 - 1, cy - 1, rx, 76 - k * 2, 64, 3.6, 5.6), rgba(hi, 255), 1.5, caps=False)
    for tail in ([(306, 548), (300, 590), (306, 616)], [(330, 550), (338, 584)]):
        lay.line(tail, rgba(INK, 255), 9)
        lay.line(tail, rgba(col, 255), 6)
    cv.comp(lay)
    cv.rect(306, 394, 334, 410, fill=ROPE_D, ol=INK, w=1.8)


def paint_C_rope():
    """The rope on its peg: dry (bands 0-2), soaked and dripping (3-5), hanging straight down
    as if something heavy were on the end (6+)."""
    cv = Cv(W, H)
    rope_coil(cv, False)
    save(finish_rgba(cv, "C_rope_0", 4), "C_rope_0", "RGBA")
    cv = Cv(W, H)
    rope_coil(cv, True)
    wet = cv.layer()
    for x, y in ((302, 618), (338, 588), (318, 560)):
        wet.ell(x, y + 8, 3, 4.5, fill=rgba((180, 210, 204), 255), ol=None, w=0)
    cv.comp(wet, 0.8)
    save(finish_rgba(cv, "C_rope_1", 4), "C_rope_1", "RGBA")
    cv = Cv(W, H)
    col = mix(ROPE, WETDARK, 0.5)
    cv.rect(306, 394, 334, 410, fill=ROPE_D, ol=INK, w=1.8)
    taut = [(320, 404), (321, 600), (320, 760), (321, 896)]
    cv.line(taut, INK, 15, caps=False)
    cv.line(taut, col, 11, caps=False)
    for y in range(414, 892, 12):   # the lay of the strands
        cv.line([(314.5, y), (325.5, y + 8)], mix(col, INK, 0.5), 1.6, caps=False)
        cv.line([(316, y + 2), (322, y + 6)], mix(col, (200, 186, 150), 0.3), 1.0, caps=False)
    cv.ell(320, 898, 14, 4, fill=rgba(WETDARK, 170), ol=None, w=0)
    save(finish_rgba(cv, "C_rope_2", 4), "C_rope_2", "RGBA")


def paint_C_beads():
    """Band 7: water beading on the inside of the open hatch leaf's riveted face."""
    name = "C_beads"
    rng = rng_for(name)
    cv = Cv(W, H)
    for k in range(70):
        x = rng.uniform(946, 996)
        y = rng.uniform(396, 868)
        r = rng.choice((1.6, 2.0, 2.4, 3.0, 3.6))
        cv.ell(x, y + 0.8, r, r * 1.2, fill=rgba(WETDARK, 150), ol=None, w=0)
        cv.ell(x, y, r * 0.85, r, fill=rgba((150, 178, 176), 220), ol=None, w=0)
        cv.ell(x - r * 0.3, y - r * 0.35, r * 0.32, r * 0.32, fill=rgba((240, 246, 242), 240), ol=None, w=0)
    for k in range(5):
        x = rng.uniform(950, 994)
        y = rng.uniform(420, 700)
        L = rng.uniform(60, 160)
        cv.line([(x, y), (x + rng.uniform(-1.5, 1.5), y + L)], rgba((150, 178, 176), 200), 2.0)
        cv.ell(x, y + L, 2.6, 3.4, fill=rgba((170, 196, 192), 230), ol=None, w=0)
    save(cv.down(), name, "RGBA")


STAIN_BOX = (0, 596, W, 904)
STAIN_TOP = {2: 846, 3: 806, 4: 766, 5: 724, 6: 680, 7: 636}
STAIN_SKIP = {
    "A": [(516, 236, 1084, 768), (530, 750, 1070, 910), (552, 740, 718, 864), (1130, 398, 1360, 904)],
    "B": [(94, 136, 426, 608), (462, 196, 998, 886), (984, 500, 1050, 886), (1056, 416, 1284, 704)],
    "C": [(462, 348, 1004, 892), (986, 376, 1314, 694)],
}


def paint_damp():
    """Bands 2-7: a damp tide-mark rising up the wainscot, a few centimetres a band. One crop per
    wall and band (drawn at STAIN_BOX's corner), with every furniture mass left dry."""
    bx0, by0, bx1, by1 = STAIN_BOX
    for wall in "ABC":
        rng = rng_for("damp:" + wall)
        blot = noise(rng, W, by1 - by0, 26)
        for band, top in STAIN_TOP.items():
            cv = Cv(W, by1 - by0)
            ph = rng_for(f"damp:{wall}:{band}").uniform(0, 6.28)
            line = [(x, top - by0 + 5 * math.sin(x * 0.013 + ph) + 2.5 * math.sin(x * 0.051 + 2 * ph))
                    for x in range(0, W + 6, 6)]
            wet = cv.layer()
            wet.poly(line + [(W, by1 - by0), (0, by1 - by0)], fill=rgba(WETDARK, 255), ol=None)
            m = wet.im.getchannel("A").filter(ImageFilter.GaussianBlur(2 * SS))
            g = Image.linear_gradient("L").resize((W * SS, (by1 - by0) * SS)).point([int(150 + v * 0.4) for v in range(256)])
            b = blot.resize((W * SS, (by1 - by0) * SS)).point([int(170 + v * 0.33) for v in range(256)])
            m = ImageChops.multiply(ImageChops.multiply(m, g), b)
            wet.im.putalpha(m)
            cv.comp(wet, 0.42)
            for lvl in [t for b2, t in STAIN_TOP.items() if b2 < band]:   # the older, lower marks
                old = [(x, lvl - by0 + 4 * math.sin(x * 0.017 + lvl)) for x in range(0, W + 8, 8)]
                cv.line(old, rgba((176, 176, 160), 70), 1.6, caps=False)
            cv.line([(x, y + 3) for x, y in line], rgba(WETDARK, 150), 2.0, caps=False)
            cv.line(line, rgba((206, 204, 186), 190), 2.4, caps=False)
            for k in range(26):   # salt blooms on the crown
                x = rng.uniform(0, W)
                y = top - by0 + 5 * math.sin(x * 0.013 + ph) - rng.uniform(0, 6)
                cv.ell(x, y, rng.uniform(3, 9), rng.uniform(1.5, 3.5), fill=rgba((214, 212, 196), 120), ol=None, w=0)
            img = cv.down()
            keep = Image.new("L", img.size, 255)
            dk = ImageDraw.Draw(keep)
            for (x0, y0, x1, y1) in STAIN_SKIP[wall]:
                dk.rectangle([x0, y0 - by0, x1, y1 - by0], fill=0)
            img.putalpha(ImageChops.multiply(img.getchannel("A"), keep))
            save(img, f"{wall}_damp_{band}", "RGBA")


def hatch_leaf(cv):
    cv.rect(600, 390, 900, 870, fill=IRON_L, ol=INK, w=3.2, shade=True)
    cv.rect(612, 402, 888, 858, fill=IRON, ol=INK, w=1.8, shade=True)
    for y in (470, 770):
        cv.rect(600, y - 14, 900, y + 14, fill=IRON_D, ol=INK, w=2)
        for x in range(616, 890, 30):
            rivet(cv, x, y, 3.4)
    for y in (430, 828):  # strap hinges on the right: it swings right
        cv.rect(860, y - 14, 940, y + 14, fill=IRON_D, ol=INK, w=2)
        rivet(cv, 876, y, 3.4)
        rivet(cv, 900, y, 3.4)
        cv.ell(934, y, 8, 18, fill=IRON_L, ol=INK, w=2)
    # wheel latch
    cx, cy = 750, 620
    cv.ell(cx, cy, 22, 22, fill=IRON_D, ol=INK, w=2)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        cv.line([(cx + 12 * math.cos(a), cy + 12 * math.sin(a)), (cx + 52 * math.cos(a), cy + 52 * math.sin(a))],
                INK, 10)
        cv.line([(cx + 12 * math.cos(a), cy + 12 * math.sin(a)), (cx + 52 * math.cos(a), cy + 52 * math.sin(a))],
                (84, 98, 108), 6)
    cv.ell(cx, cy, 56, 56, fill=None, ol=INK, w=14)
    cv.ell(cx, cy, 56, 56, fill=None, ol=(84, 98, 108), w=9)
    cv.line(ellipse_pts(cx, cy, 55, 55, 24, 3.4, 4.9), mix(IRON_L, SHEEN, 0.6), 2.4, caps=False)
    cv.ell(cx, cy, 13, 13, fill=IRON_L, ol=INK, w=2)
    cv.ell(cx, cy, 4, 4, fill=INK, ol=None, w=0)
    cv.rect(600, 610, 640, 630, fill=IRON_D, ol=INK, w=2)  # the dog bolt into the frame


def b_ok(x0, x1, inset):
    return x1 - x0 - 2 * inset > 40


def paint_C_hatch_open():
    """P04: the hatch stands open on a stair that goes DOWN: the top tread at the sill, risers
    dropping and narrowing below it, darkening with depth to storm navy at the pressure gate."""
    name = "C_hatch_open"
    cv = Cv(W, H)
    x0, y0, x1, y1 = 600, 390, 900, 870
    # the far wall above the stair head: dressed stone in cold half-light
    cv.paste1x(vgrad(x1 - x0, 170, (30, 40, 48), (64, 78, 82), 1.0), x0, y0)
    lay = cv.layer()
    for k in range(4):
        y = y0 + 22 + k * 40
        lay.line([(x0, y), (x1, y)], rgba(INK, 255), 1.3, caps=False)
        for x in range(x0 + (k % 2) * 40, x1, 80):
            lay.line([(x, y), (x, y + 40)], rgba(INK, 255), 1.1, caps=False)
    cv.comp(lay, 0.4)
    # the shaft walls and the stair dropping into it
    cv.rect(x0, 560, x1, y1, fill=NAVY, ol=None)
    y = 560.0
    inset = 0.0
    h = 50.0
    k = 0
    tread = (176, 188, 182)
    riser = (120, 134, 132)
    while y < y1 - 6 and h > 4 and b_ok(x0, x1, inset):
        t = min(1.0, (y - 560) / 170.0)
        tcol = mix(tread, NAVY, t ** 0.8)
        rcol = mix(riser, NAVY, min(1.0, t ** 0.8 + 0.08))
        a, b = x0 + inset, x1 - inset
        th = min(h * 0.5, max(4.0, h * 0.22))
        cv.rect(a, y, b, min(y1, y + th), fill=tcol, ol=None)                       # tread (lit top)
        if y + th < y1:
            cv.rect(a, y + th, b, min(y1, y + h), fill=rcol, ol=None)               # riser facing her
        cv.line([(a, y), (b, y)], mix(INK, NAVY, t), 2.2 - t, caps=False)
        cv.line([(a, y + th), (b, y + th)], mix(INK, NAVY, t), 1.6 - 0.8 * t, caps=False)
        # the side walls close in as it goes down
        cv.rect(x0, y, a, y + h, fill=mix((40, 52, 58), NAVY, t), ol=None)
        cv.rect(b, y, x1, y + h, fill=mix((30, 40, 48), NAVY, t), ol=None)
        y += h
        inset += h * 0.12
        h *= 0.84
        k += 1
    # the top tread is the sill of the hatch: worn bright at its nosing
    cv.rect(x0, 554, x1, 562, fill=(208, 214, 204), ol=INK, w=1.6)
    # the pressure gate: high-contrast iron grille, pale-edged so it reads on the dark
    for x in range(x0 + 14, x1, 24):
        cv.rect(x - 3.5, 696, x + 3.5, 866, fill=(78, 88, 96), ol=INK, w=1.6)
        cv.line([(x - 1.5, 700), (x - 1.5, 862)], (150, 166, 168), 1.2, caps=False)
    for yy in (696, 780, 860):
        cv.rect(x0, yy - 6, x1, yy + 6, fill=(78, 88, 96), ol=INK, w=1.8)
        cv.line([(x0 + 2, yy - 3), (x1 - 2, yy - 3)], (150, 166, 168), 1.2, caps=False)
        for x in range(x0 + 12, x1, 48):
            rivet(cv, x, yy, 3, (120, 130, 136))
    cv.rect(x0 + 116, 752, x0 + 184, 806, fill=BRASS, ol=INK, w=2.6)        # gate lock plate
    cv.ell(x0 + 150, 774, 9, 9, fill=(16, 18, 22), ol=INK, w=1.8)
    cv.poly([(x0 + 146, 778), (x0 + 154, 778), (x0 + 156, 796), (x0 + 144, 796)], fill=(16, 18, 22), ol=None)
    cv.rect(x0, y0, x1, y1, fill=None, ol=INK, w=3.4)
    # the leaf, swung right flat against the wall (narrow, edge-on), its riveted inner face out
    cv.shadow(lambda d, o: d.rectangle([930 + o[0], 384 + o[1], 1000 + o[0], 878 + o[1]], fill=255), (8, 4), 7, 120)
    cv.rect(930, 384, 1000, 878, fill=IRON, ol=INK, w=3, shade=True)
    cv.rect(930, 384, 944, 878, fill=IRON_L, ol=INK, w=2)
    for yy in (470, 770):
        cv.rect(944, yy - 14, 1000, yy + 14, fill=IRON_D, ol=INK, w=2)
    for yy in range(400, 870, 30):
        rivet(cv, 937, yy, 3)
        rivet(cv, 990, yy + 15, 2.6)
    cv.ell(972, 620, 16, 56, fill=None, ol=INK, w=11)  # the wheel, edge-on
    cv.ell(972, 620, 16, 56, fill=None, ol=IRON_L, w=6)
    save(finish_rgba(cv, name, 4), name, "RGBA")


def paint_C_window_7():
    """Band 7: the water stands upright. A hard vertical waterline divides the window: dark air
    on the left, water on the right, its surface meniscus drawn top to bottom."""
    name = "C_window_7"
    x0, y0, x1, y1 = OUTER_GLASS
    mx = 1150
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    water = water_body(rng_for("C_base:water"), x0, y0, x1, y1)
    # rotate the light: the water's "down" is now to the right
    right = water.crop((0, 0, x1 - x0, y1 - y0)).rotate(90).resize((x1 - mx, y1 - y0))
    air = vgrad(mx - x0, y1 - y0, (16, 22, 30), (10, 14, 20))
    img.paste(air, (x0, y0))
    img.paste(right, (mx, y0))
    cv = Cv(W, H)
    # the meniscus: a bright lip, a dark underside, a curl at top and bottom where it meets the frame
    cv.rect(mx - 2, y0, mx + 3, y1, fill=rgba((222, 240, 232), 255), ol=None)
    cv.rect(mx + 3, y0, mx + 9, y1, fill=rgba((26, 48, 56), 220), ol=None)
    for yy, s_ in ((y0, 1), (y1, -1)):
        cv.line(smooth_open([(mx - 10, yy), (mx - 3, yy + s_ * 10), (mx, yy + s_ * 24)], 6), rgba((222, 240, 232), 230), 2.2)
    # faint reflection of the room in the dark air half
    ref = cv.layer()
    ref.poly([(1040, y0), (1080, y0), (1030, y0 + 120), (1020, y0 + 90)], fill=rgba(SHEEN, 255), ol=None)
    cv.comp(ref, 0.06)
    img.alpha_composite(cv.down())
    top = Cv(W, H)
    top.rect(x0, y0, x1, y1, fill=None, ol=INK, w=2.5)
    img.alpha_composite(top.down())
    save(clip_to(img, x0, y0, x1, y1), name, "RGBA")


def paint_C_line():
    name = "C_line"
    img = Image.new("RGBA", (8, 260), rgba((190, 222, 210), 0))
    px = img.load()
    for x in range(8):
        a = math.exp(-((x - 3.5) / 1.6) ** 2)
        for y in range(260):
            t = min(y, 259 - y) / 20.0
            px[x, y] = (190, 222, 210, int(235 * a * min(1.0, t)))
    save(img, name, "RGBA")


# ---------------------------------------------------------------- close-ups
def timber_bg(name, col=(58, 50, 43), col_d=(44, 38, 33)):
    """A bench top of long horizontal planks: straight grain, a few knots, dark seams."""
    rng = rng_for(name + ":timber")
    cv = Cv(W, H, rgba(col, 255))
    streak = Image.frombytes("L", (max(2, W // 40), H), rng.randbytes(max(2, W // 40) * H)).resize((W, H), Image.BICUBIC)
    streak = streak.filter(ImageFilter.GaussianBlur(0.8))
    cv.paste1x(Image.new("RGB", (W, H), col_d), 0, 0, streak.point([int(clamp((v - 100) / 155.0) * 170) for v in range(256)]))
    hi = Image.frombytes("L", (max(2, W // 60), H), rng.randbytes(max(2, W // 60) * H)).resize((W, H), Image.BICUBIC)
    cv.paste1x(Image.new("RGB", (W, H), mix(col, (120, 104, 84), 0.5)), 0, 0,
               hi.point([int(clamp((v - 200) / 55.0) * 90) for v in range(256)]))
    for y in range(0, H, 136):
        cv.line([(0, y), (W, y)], (24, 20, 18), 2.4, caps=False)
        cv.line([(0, y + 2.5), (W, y + 2.5)], mix(col, (150, 130, 104), 0.35), 1.0, caps=False)
    for k in range(5):
        x, y = rng.uniform(80, W - 80), rng.choice(range(40, H, 136)) + rng.uniform(20, 70)
        cv.ell(x, y, rng.uniform(10, 18), rng.uniform(4, 7), fill=None, ol=col_d, w=1.6)
    return cv


def paint_cu_registration():
    """The chart table as a contraption: a sheet rack and a tray on the left, the lit table, and
    on the right a brass panel with two turning knobs, three register pins and a clip cradle.
    The view draws the sheets, the pins' state and every engraved word."""
    name = "cu_registration"
    cv = timber_bg(name)
    # left: the sheet rack (two slots) and a shallow tray for his sheet
    cv.shadow(lambda d, o: d.rectangle([60 + o[0], 140 + o[1], 348 + o[0], 540 + o[1]], fill=255), (6, 8), 7, 130)
    cv.rect(60, 140, 348, 540, fill=TIMBER, ol=INK, w=3.4, shade=True)
    for (x0, y0, x1, y1) in ((84, 170, 324, 260), (84, 280, 324, 370)):
        cv.rect(x0, y0, x1, y1, fill=(26, 22, 20), ol=INK, w=2.4)
        cv.rect(x0, y1 - 14, x1, y1, fill=BRASS, ol=INK, w=2)          # the slot's brass lip
        cv.line([(x0 + 4, y0 + 4), (x1 - 4, y0 + 4)], (52, 44, 38), 2, caps=False)
    cv.rrect(78, 424, 330, 526, 6, fill=BRASS_D, ol=INK, w=2.8)          # his sheet's tray
    cv.rrect(90, 436, 318, 514, 4, fill=mix(BRASS_D, (40, 34, 28), 0.5), ol=INK, w=1.6)
    # worked-example frame, glazed
    cv.shadow(lambda d, o: d.rectangle([84 + o[0], 600 + o[1], 324 + o[0], 860 + o[1]], fill=255), (5, 7), 5, 120)
    cv.rect(84, 600, 324, 860, fill=BRASS, ol=INK, w=3)
    cv.rect(100, 616, 308, 844, fill=(214, 210, 196), ol=INK, w=2)
    sh = cv.layer()
    sh.poly([(110, 616), (170, 616), (100, 700), (100, 650)], fill=rgba((255, 255, 255), 255), ol=None)
    cv.comp(sh, 0.25)
    for (x, y) in ((92, 608), (316, 608), (92, 852), (316, 852)):
        screw(cv, x, y, 3.5)
    # the light table: bone glass in a brass frame, lit from beneath
    cv.shadow(lambda d, o: d.rectangle([374 + o[0], 130 + o[1], 1074 + o[0], 780 + o[1]], fill=255), (10, 12), 10, 150)
    cv.rect(374, 130, 1074, 780, fill=BRASS, ol=INK, w=4)
    gw, gh = 1052 - 396, 758 - 152
    glow = Image.radial_gradient("L").resize((gw, gh))
    lit = Image.composite(Image.new("RGB", (gw, gh), (206, 198, 176)), Image.new("RGB", (gw, gh), (242, 236, 218)),
                          glow.point([int(clamp((v - 60) / 195.0) * 255) for v in range(256)]))
    cv.paste1x(lit, 396, 152)
    cv.rect(396, 152, 1052, 758, fill=None, ol=INK, w=2.5)
    for (x, y) in ((386, 142), (1062, 142), (386, 768), (1062, 768), (724, 142), (724, 768)):
        screw(cv, x, y, 4.5)
    # right: the brass control panel
    cv.shadow(lambda d, o: d.rectangle([1110 + o[0], 230 + o[1], 1420 + o[0], 870 + o[1]], fill=255), (8, 10), 8, 140)
    cv.rect(1110, 230, 1420, 870, fill=BRASS_D, ol=INK, w=3.4, shade=True)
    cv.rect(1120, 240, 1410, 860, fill=BRASS, ol=INK, w=2)
    for (x, y) in ((1132, 252), (1398, 252), (1132, 848), (1398, 848)):
        screw(cv, x, y, 4)
    # two knurled knobs, set into bosses
    for cx in (1189, 1339):
        cv.ell(cx, 345, 50, 50, fill=BRASS_D, ol=INK, w=3)
        cv.ell(cx, 345, 40, 40, fill=(70, 60, 44), ol=INK, w=2)
        for j in range(28):
            a = 2 * math.pi * j / 28
            cv.line([(cx + 40 * math.cos(a), 345 + 40 * math.sin(a)), (cx + 33 * math.cos(a), 345 + 33 * math.sin(a))],
                    BRASS_L, 2.2, caps=False)
        cv.ell(cx, 345, 31, 31, fill=BRASS_L, ol=INK, w=2.4)
    # three pin plaques: a socket on the left for the pin
    for y in (440, 526, 612):
        cv.rrect(1124, y, 1404, y + 76, 6, fill=mix(BRASS, BRASS_L, 0.35), ol=INK, w=2.2)
        cv.ell(1164, y + 38, 20, 20, fill=(28, 24, 20), ol=INK, w=2)
        cv.ell(1164, y + 38, 26, 26, fill=None, ol=BRASS_D, w=3)
    # the clip cradle
    cv.rrect(1124, 740, 1404, 840, 10, fill=(40, 34, 28), ol=INK, w=2.6)
    cv.rrect(1134, 750, 1394, 830, 8, fill=(58, 50, 40), ol=INK, w=1.4)
    save(finish_rgb(cv, name, 6), name, "RGB")


def paint_cu_recorder():
    name = "cu_recorder"
    cv = Cv(W, H, rgba(COPPER_D, 255))
    rng = rng_for(name)
    m = noise(rng, W, H, 90).point([int(clamp((v - 100) / 155.0) * 90) for v in range(256)])
    cv.paste1x(Image.new("RGB", (W, H), COPPER), 0, 0, m)
    for (x0, y0, x1, y1) in ((200, 90, 1250, 360), (200, 350, 860, 960), (870, 350, 1400, 980)):
        cv.rect(x0, y0, x1, y1, fill=None, ol=INK, w=3)
        cv.rect(x0 + 6, y0 + 6, x1 - 6, y1 - 6, fill=None, ol=COPPER_L, w=1.5)
    for x in range(40, W, 60):
        rivet(cv, x, 1046, 6, COPPER_L)
    # drum face
    cv.rect(200, 100, 1248, 350, fill=COPPER_DD, ol=INK, w=3)
    cv.paste1x(vgrad(1000, 115, mix(BONE, COPPER_D, 0.3), BONE, 0.6), 224, 110)
    cv.paste1x(vgrad(1000, 115, BONE, mix(BONE, COPPER_D, 0.34), 1.7), 224, 225)
    lay = cv.layer()
    for k in range(1, 12):
        lay.line([(224, 110 + k * 19), (1224, 110 + k * 19)], rgba(TEAL, 255), 1.6, caps=False)
    for k in range(1, 20):
        lay.line([(224 + k * 50, 112), (224 + k * 50, 338)], rgba(TEAL, 255), 1.6 if k % 5 else 2.6, caps=False)
    cv.comp(lay, 0.17)
    cv.rect(224, 110, 1224, 340, fill=None, ol=INK, w=3)
    for x0 in (204, 1224):
        cv.rect(x0, 104, x0 + 20, 346, fill=BRASS, ol=INK, w=2.5)
    # calibration plate
    brass_plate(cv, 224, 360, 744, 436, w=3, r=5)
    # wheel windows with up/down button plates
    for wx in (254, 494):
        for (by0, by1) in ((470, 510), (680, 720)):
            brass_plate(cv, wx + 20, by0, wx + 130, by1, screws=False, w=2.5, r=6)
            cv.ell(wx + 75, (by0 + by1) / 2, 13, 13, fill=BRASS_L, ol=INK, w=2.5)
        cv.rect(wx - 10, 510, wx + 160, 680, fill=BRASS_D, ol=INK, w=3)
        cv.rect(wx, 520, wx + 150, 670, fill=(14, 20, 26), ol=INK, w=2.5)
        cv.paste1x(vgrad(110, 55, mix(BONE, INK, 0.55), BONE, 0.5), wx + 20, 540)
        cv.paste1x(vgrad(110, 55, BONE, mix(BONE, INK, 0.6), 1.8), wx + 20, 595)
        cv.line([(wx + 20, 568), (wx + 130, 568)], mix(BONE, INK, 0.3), 1.5, caps=False)
        cv.line([(wx + 20, 622), (wx + 130, 622)], mix(BONE, INK, 0.3), 1.5, caps=False)
        cv.rect(wx + 20, 540, wx + 130, 650, fill=None, ol=INK, w=2)
    # gauges with a hatched band on the right third
    for gx in (234, 474):
        cv.rrect(gx, 770, gx + 190, 920, 14, fill=BRASS, ol=INK, w=3)
        cv.rrect(gx + 12, 782, gx + 178, 908, 10, fill=BONE, ol=INK, w=2)
        hb = cv.layer()
        x_h = gx + 12 + 166 * 2 / 3
        for k in range(-10, 20):
            hb.line([(x_h + k * 9, 908), (x_h + k * 9 + 60, 782)], rgba(INK, 255), 1.6, caps=False)
        hb.im.paste((0, 0, 0, 0), (0, 0, int(x_h * SS), H * SS))
        hb.im.paste((0, 0, 0, 0), (int((gx + 176) * SS), 0, W * SS, H * SS))
        hb.im.paste((0, 0, 0, 0), (0, 0, W * SS, 784 * SS))
        hb.im.paste((0, 0, 0, 0), (0, 906 * SS, W * SS, H * SS))
        cv.comp(hb, 0.55)
        cv.line([(x_h, 782), (x_h, 908)], INK, 2, caps=False)
        for k in range(9):
            x = gx + 24 + k * 17
            cv.line([(x, 790), (x, 804 if k % 2 == 0 else 798)], INK, 1.6, caps=False)
        cv.ell(gx + 95, 892, 7, 7, fill=INK, ol=None, w=0)
    # CALIBRATE lever slot, handle up
    cv.rect(724, 470, 834, 870, fill=COPPER, ol=INK, w=3)
    cv.rect(766, 496, 792, 852, fill=(10, 14, 18), ol=INK, w=2)
    cv.rect(770, 520, 788, 840, fill=BRASS, ol=INK, w=2)
    cv.rect(748, 820, 810, 856, fill=BRASS_D, ol=INK, w=2.5)
    cv.rrect(716, 486, 842, 530, 20, fill=BRASS_POL, ol=INK, w=3.5)
    cv.line([(736, 496), (820, 496)], (250, 236, 196), 4, caps=False)
    cv.line([(780, 520), (826, 520)], BRASS, 3, caps=False)
    # right panel
    cv.rect(884, 360, 1384, 960, fill=COPPER, ol=INK, w=3)
    cv.rect(904, 370, 1364, 460, fill=BRASS_D, ol=INK, w=3)
    cv.rect(916, 382, 1352, 448, fill=BONE, ol=INK, w=2)
    for sx in (924, 1069, 1214):
        cv.rect(sx - 8, 482, sx + 138, 648, fill=BRASS, ol=INK, w=3)
        cv.rect(sx, 490, sx + 130, 640, fill=(12, 18, 24), ol=INK, w=2.5)
        cv.line([(sx + 4, 496), (sx + 126, 496)], (44, 56, 64), 3, caps=False)
        cv.rect(sx - 6, 674, sx + 136, 816, fill=TIMBER_D, ol=INK, w=3)
        cv.rect(sx, 680, sx + 130, 810, fill=mix(TIMBER_D, TIMBER, 0.4), ol=INK, w=2)
        cv.rect(sx - 10, 806, sx + 140, 818, fill=BRASS, ol=INK, w=2)
    brass_plate(cv, 1034, 840, 1274, 930, w=3, r=8)
    cv.rrect(1104, 856, 1204, 914, 12, fill=BRASS_L, ol=INK, w=3)
    cv.line([(1114, 866), (1194, 866)], (246, 230, 190), 3, caps=False)
    save(finish_rgb(cv, name, 8), name, "RGB")


def paint_cu_rec_fog():
    """Band 4+: condensation on the inside of both gauge glasses."""
    name = "cu_rec_fog"
    rng = rng_for(name)
    cv = Cv(W, H)
    for gx in (234, 474):
        x0, y0, x1, y1 = gx + 12, 782, gx + 178, 908
        m = Image.new("L", (x1 - x0, y1 - y0), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, x1 - x0 - 1, y1 - y0 - 1], 10, fill=255)
        n = noise(rng, x1 - x0, y1 - y0, 14).point([int(110 + v * 0.35) for v in range(256)])
        cv.paste1x(Image.new("RGB", (x1 - x0, y1 - y0), (232, 236, 230)), x0, y0, ImageChops.multiply(m, n))
        for k in range(40):
            x, y = rng.uniform(x0 + 6, x1 - 6), rng.uniform(y0 + 6, y1 - 6)
            r = rng.uniform(1.8, 4.2)
            cv.ell(x, y + 0.8, r, r * 1.15, fill=rgba((110, 120, 116), 150), ol=None, w=0)
            cv.ell(x - r * 0.3, y - r * 0.3, r * 0.35, r * 0.35, fill=rgba((252, 252, 248), 230), ol=None, w=0)
    save(cv.down(), name, "RGBA")


def paint_cu_rec_brown():
    """Band 6+: the drum's bone paper browning, foxed, darker at its edges."""
    name = "cu_rec_brown"
    rng = rng_for(name)
    x0, y0, x1, y1 = 224, 110, 1224, 340
    w, h = x1 - x0, y1 - y0
    n = noise(rng, w, h, 40)
    edge = Image.new("L", (w, h), 0)
    ImageDraw.Draw(edge).rectangle([18, 14, w - 18, h - 14], fill=255)
    edge = ImageOps.invert(edge.filter(ImageFilter.GaussianBlur(16)))
    a = ImageChops.add(n.point([int(60 + v * 0.25) for v in range(256)]), edge.point([int(v * 0.5) for v in range(256)]))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wash = Image.new("RGBA", (w, h), (150, 112, 62, 255))
    wash.putalpha(a)
    img.alpha_composite(wash, (x0, y0))
    d = ImageDraw.Draw(img, "RGBA")
    for k in range(30):
        x, y = rng.uniform(x0 + 10, x1 - 10), rng.uniform(y0 + 10, y1 - 10)
        r = rng.uniform(2, 8)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(122, 82, 40, int(rng.uniform(40, 90))))
    save(img, name, "RGBA")


def paint_cu_recorder_shutter():
    name = "cu_recorder_shutter"
    cv = Cv(W, H)
    x0, y0, x1, y1 = 884, 470, 1384, 940
    cv.shadow(lambda d, o: d.rectangle([x0 + o[0], y0 + o[1], x1 + o[0], y1 + o[1]], fill=255), (6, 8), 6, 130)
    cv.rect(x0, y0, x1, y1, fill=BRASS, ol=INK, w=3.5)
    for y in range(y0 + 26, y1, 26):
        cv.line([(x0 + 2, y), (x1 - 2, y)], INK, 2.2, caps=False)
        cv.line([(x0 + 2, y + 3), (x1 - 2, y + 3)], BRASS_L, 1.6, caps=False)
        cv.line([(x0 + 2, y - 4), (x1 - 2, y - 4)], BRASS_D, 1.6, caps=False)
    for y in range(y0 + 13, y1, 26):
        rivet(cv, x0 + 16, y, 4.5, BRASS_L)
        rivet(cv, x1 - 16, y, 4.5, BRASS_L)
    cv.rect(x0 - 10, y0 - 14, x1 + 10, y0 + 8, fill=BRASS_D, ol=INK, w=3)
    cv.rect(984, 668, 1284, 744, fill=(48, 46, 40), ol=INK, w=3)
    cv.rect(992, 676, 1276, 736, fill=(196, 186, 160), ol=INK, w=1.5)
    for (x, y) in ((990, 674), (1278, 674), (990, 738), (1278, 738)):
        screw(cv, x, y, 3.5)
    cv.rrect(1104, 900, 1164, 928, 6, fill=BRASS_D, ol=INK, w=2.5)
    save(finish_rgba(cv, name, 6), name, "RGBA")


def seal_cu(broken):
    name = "cu_seal_broken" if broken else "cu_seal"
    rng = rng_for(name)
    cv = Cv(W, H)
    x0, y0, x1, y1 = 234, 440, 664, 760
    if not broken:
        cv.shadow(lambda d, o: d.rectangle([x0 + o[0], y0 + o[1], x1 + o[0], y1 + o[1]], fill=255), (4, 6), 5, 110)
        edge_t = [(x0 + k * 10, y0 + rng.uniform(-2, 2)) for k in range(44)] + [(x1, y0)]
        edge_b = [(x1 - k * 10, y1 + rng.uniform(-2, 2)) for k in range(44)] + [(x0, y1)]
        cv.poly(edge_t + edge_b, fill=PAPER2, ol=INK, w=2.5)
        # paste stains around the edge
        st = cv.layer()
        for k in range(18):
            x = rng.choice((rng.uniform(x0 + 6, x0 + 40), rng.uniform(x1 - 40, x1 - 6)))
            y = rng.uniform(y0 + 10, y1 - 10)
            st.ell(x, y, rng.uniform(8, 20), rng.uniform(6, 16), fill=rgba((176, 160, 120), 255), ol=None, w=0)
        cv.comp(st, 0.18)
        wax_seal(cv, 450, 600, 62, split=False, s=2.4)
    else:
        def shf(d, o):
            d.polygon([(x0 + o[0], y0 + o[1]), (340 + o[0], y0 - 40 + o[1]), (400 + o[0], 600 + o[1]),
                       (340 + o[0], y1 + 44 + o[1]), (x0 + o[0], y1 + o[1])], fill=255)
            d.polygon([(x1 + o[0], y0 + o[1]), (560 + o[0], y0 - 40 + o[1]), (500 + o[0], 600 + o[1]),
                       (560 + o[0], y1 + 44 + o[1]), (x1 + o[0], y1 + o[1])], fill=255)
        cv.shadow(shf, (10, 22), 14, 160)
        for side in (-1, 1):
            base_x = x0 if side < 0 else x1
            hx = 340 if side < 0 else 560
            flat = 280 if side < 0 else 618
            n = 16
            rim = []
            for k in range(n + 1):
                t = k / n
                y = (y0 - 40) + t * (y1 - y0 + 84)
                bulge = math.sin(math.pi * t)
                x = hx - side * (36 * bulge) + rng.uniform(-9, 9) * (0.4 + bulge)
                rim.append((x, y))
            poly = [(base_x, y0), (flat, y0), (hx, y0 - 40)] + rim[1:-1] + [(hx, y1 + 44), (flat, y1), (base_x, y1)]
            cv.poly(poly, fill=PAPER2, ol=INK, w=3)
            lay = cv.layer()
            lay.poly([(flat, y0 + 6), (hx, y0 - 30), ] + [(x + side * 10, y) for x, y in rim[2:-2]] +
                     [(hx, y1 + 34), (flat, y1 - 6)], fill=rgba((248, 244, 230), 255), ol=None)
            cv.comp(lay, 0.65)
            # rolled lip
            lip = [(x - side * 22, y) for (x, y) in rim]
            cv.poly(rim + list(reversed(lip)), fill=mix(PAPER, INK, 0.28), ol=INK, w=2.5)
            cv.line([(x - side * 7, y) for (x, y) in rim], (252, 248, 236), 3, caps=False)
            cv.line([(x - side * 18, y) for (x, y) in rim], mix(PAPER, INK, 0.5), 1.5, caps=False)
            # creases radiating from the bulge
            cr = cv.layer()
            for k in range(4):
                y = y0 + 40 + k * 70
                cr.line([(flat + side * 6, y), (hx - side * 30, y + rng.uniform(-30, 30))], rgba(INK, 255), 1.6)
            cv.comp(cr, 0.3)
        # the wax, split, each half carried outward with its paper
        for side in (-1, 1):
            cx = 450 + side * 74
            r = 46
            half = [(cx + side * r * math.cos(a) * 0.9, 600 + r * math.sin(a))
                    for a in [-math.pi / 2 + math.pi * k / 16 for k in range(17)]]
            crack = [(cx + side * (-6 + (k % 2) * 10), 600 + r - k * (2 * r / 6)) for k in range(7)]
            cv.poly(half + crack, fill=WAX, ol=INK, w=3)
            cv.ell(cx + side * 16, 600, 18, 26, fill=WAX_D, ol=None, w=0)
            cv.line([(cx + side * 10, 570), (cx + side * 22, 630)], (236, 214, 190), 5, caps=False)
    save(finish_rgba(cv, name, 5), name, "RGBA")


def paint_cu_plan():
    name = "cu_plan"
    cv = timber_bg(name, (40, 46, 52), (30, 34, 40))
    cv.shadow(lambda d, o: d.rectangle([196 + o[0], 76 + o[1], 1226 + o[0], 924 + o[1]], fill=255), (8, 10), 9, 140)
    cv.rect(196, 76, 1226, 924, fill=TIMBER_D, ol=INK, w=4)
    cv.rect(206, 86, 1216, 914, fill=None, ol=TIMBER_L, w=2)
    sh = Image.new("RGB", (1000, 800), PAPER2)
    sh = grain(sh, rng_for(name + ":paper"), 10)
    cv.paste1x(sh, 220, 100)
    cv.rect(220, 100, 1220, 900, fill=None, ol=INK, w=2.5)
    for (x, y) in ((232, 112), (1208, 112), (232, 888), (1208, 888)):
        cv.ell(x, y, 6, 6, fill=BRASS, ol=INK, w=2)
    # felt tile tray
    cv.shadow(lambda d, o: d.rectangle([1236 + o[0], 186 + o[1], 1434 + o[0], 598 + o[1]], fill=255), (5, 8), 6, 140)
    cv.rect(1236, 186, 1434, 598, fill=BRASS_D, ol=INK, w=3)
    cv.rect(1242, 192, 1428, 592, fill=FELT, ol=INK, w=1.5)
    for y in (200, 300, 400, 500):
        cv.rect(1250, y, 1420, y + 84, fill=FELT_D, ol=INK, w=2)
        cv.line([(1252, y + 3), (1418, y + 3)], (30, 46, 40), 2.5, caps=False)
    brass_plate(cv, 1260, 760, 1410, 870, w=3, r=8)
    cv.ell(1335, 815, 26, 26, fill=BRASS_D, ol=INK, w=3)
    cv.ell(1335, 815, 14, 14, fill=BRASS_POL, ol=INK, w=2.5)
    save(finish_rgb(cv, name, 7), name, "RGB")


def paint_cu_plan_lid():
    name = "cu_plan_lid"
    cv = Cv(W, H)
    x0, y0, x1, y1 = 1236, 186, 1434, 598
    g = cv.layer()
    g.rect(x0, y0, x1, y1, fill=rgba((214, 232, 228), 255), ol=None)
    cv.comp(g, 0.16)
    sh = cv.layer()
    sh.poly([(x0 + 20, y0), (x0 + 80, y0), (x0, y0 + 120), (x0, y0 + 50)], fill=rgba((255, 255, 255), 255), ol=None)
    sh.poly([(x1, y0 + 230), (x1, y0 + 290), (x1 - 150, y1), (x1 - 196, y1)], fill=rgba((255, 255, 255), 255), ol=None)
    cv.comp(sh, 0.32)
    cv.rect(x0, y0, x1, y1, fill=None, ol=INK, w=3)
    cv.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, fill=None, ol=BRASS, w=3)
    for y in (196, 334, 452, 588):
        screw(cv, x0 + 7, y, 5)
        screw(cv, x1 - 7, y, 5)
    screw(cv, (x0 + x1) / 2, y0 + 7, 5)
    save(cv.down(), name, "RGBA")


def paint_cu_plan_body():
    name = "cu_plan_body"
    cv = Cv(W, H)
    paint_body(cv, lambda p: p, 1.0, 0.72, PLAN_PAPER, 6)
    save(cv.down(), name, "RGBA")


# ---------------------------------------------------------------- sprites
def paint_sheet_paper():
    name = "sheet_paper"
    rng = rng_for(name)
    img = Image.new("RGB", (600, 560), PAPER)
    d = ImageDraw.Draw(img, "RGBA")
    for k in range(14):  # foxing
        x, y = rng.uniform(0, 600), rng.uniform(0, 560)
        r = rng.uniform(2, 7)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(160, 128, 84, int(rng.uniform(25, 60))))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img = grain(img, rng_for(name + ":grain"), 10)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, 0, 599, 559], outline=(*INK, 120), width=2)
    save(img, name, "RGB")


def paint_sheet_tracing():
    name = "sheet_tracing"
    rng = rng_for(name)
    w, h = 600, 560
    img = Image.new("RGBA", (w, h), (236, 238, 230, 150))
    n = noise(rng, w, h, 30).point([int(138 + (v - 128) * 0.12) for v in range(256)])
    img.putalpha(n)
    img = grain(img, rng_for(name + ":grain"), 6)
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    d.line([(300, 0), (300, h)], fill=(255, 255, 255, 120), width=3)
    d.line([(302, 0), (302, h)], fill=(*INK, 60), width=1)
    d.line([(0, 280), (w, 280)], fill=(255, 255, 255, 120), width=3)
    d.line([(0, 282), (w, 282)], fill=(*INK, 60), width=1)
    pts = [(x, 532 - 8 * math.sin(x * 0.03) - 4 * math.sin(x * 0.11 + 1)) for x in range(0, w + 1, 6)]
    d.polygon(pts + [(w, h), (0, h)], fill=(*COPPER, 70))
    d.line(pts, fill=(*COPPER_DD, 150), width=2)
    d.rectangle([0, 0, w - 1, h - 1], outline=(*INK, 110), width=2)
    img.alpha_composite(lay)
    save(img, name, "RGBA")


def paint_plate_blank():
    name = "plate_blank"
    cv = Cv(130, 130)
    cv.rrect(51, 2, 79, 22, 6, fill=BRASS_D, ol=INK, w=2)
    cv.ell(65, 10, 6, 3.5, fill=(20, 24, 28), ol=None, w=0)
    cv.rrect(6, 16, 124, 126, 6, fill=BRASS, ol=INK, w=3)
    cv.line([(12, 22), (118, 22)], BRASS_L, 2.5, caps=False)
    cv.line([(12, 120), (118, 120)], BRASS_D, 2.5, caps=False)
    cv.rect(16, 30, 114, 112, fill=None, ol=mix(BRASS, INK, 0.35), w=1.5)
    for (x, y) in ((14, 24), (116, 24), (14, 118), (116, 118)):
        screw(cv, x, y, 3)
    save(finish_rgba(cv, name, 7), name, "RGBA")


def paint_tile_blank():
    name = "tile_blank"
    rng = rng_for(name)
    cv = Cv(170, 84)
    cv.rrect(2, 2, 168, 82, 7, fill=(232, 224, 200), ol=INK, w=2.5)
    cv.rrect(10, 10, 160, 74, 4, fill=None, ol=NAVY, w=3)
    for (x, y) in ((rng.uniform(20, 150), 3.5), (166.5, rng.uniform(20, 64)), (rng.uniform(20, 150), 80.5)):
        cv.ell(x, y, 4, 3, fill=(70, 74, 76), ol=None, w=0)
    cv.line([(14, 6), (90, 6)], (250, 248, 238), 1.5, caps=False)
    save(finish_rgba(cv, name, 6), name, "RGBA")


# ---------------------------------------------------------------- main
def paint_windows():
    for b in range(8):
        save(window_scene(b), f"B_window_{b}", "RGBA")


def paint_rain():
    for t in ("a", "b", "c"):
        save(rain_frame(t), "B_rain_" + t, "RGBA")


def paint_seals():
    for broken in (False, True):
        cv = Cv(W, H)
        seal_strip_room(cv, broken)
        name = "B_seal_broken" if broken else "B_seal_intact"
        save(finish_rgba(cv, name, 5), name, "RGBA")
    seal_cu(False)
    seal_cu(True)


JOBS = {
    "A_base": paint_A_base, "A_composite": paint_A_composite, "A_compass_bent": paint_A_compass_bent,
    "A_standing": paint_A_standing, "A_plan_body": paint_A_plan_body, "A_buckle": paint_A_buckle,
    "A_fog": paint_A_fog,
    "B_base": lambda: paint_B_base(window_scene(0)), "B_float": paint_B_float, "B_window": paint_windows, "B_rain": paint_rain,
    "seals": paint_seals, "B_pen": paint_B_pen, "B_p05": paint_B_p05, "B_strip": paint_B_strip,
    "C_base": paint_C_base, "C_hatch_open": paint_C_hatch_open, "C_window_7": paint_C_window_7,
    "C_line": paint_C_line, "C_rope": paint_C_rope, "C_beads": paint_C_beads, "damp": paint_damp,
    "cu_registration": paint_cu_registration, "cu_recorder": paint_cu_recorder,
    "cu_recorder_shutter": paint_cu_recorder_shutter, "cu_rec_fog": paint_cu_rec_fog,
    "cu_rec_brown": paint_cu_rec_brown, "cu_plan": paint_cu_plan, "cu_plan_lid": paint_cu_plan_lid,
    "cu_plan_body": paint_cu_plan_body,
    "sheet_paper": paint_sheet_paper, "sheet_tracing": paint_sheet_tracing, "plate_blank": paint_plate_blank,
    "tile_blank": paint_tile_blank,
}


def main(argv):
    names = argv or list(JOBS)
    for n in names:
        JOBS[n]()


if __name__ == "__main__":
    main(sys.argv[1:])
