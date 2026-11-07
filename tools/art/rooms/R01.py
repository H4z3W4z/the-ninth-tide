#!/usr/bin/env python3
"""R01 Jetty painter: seeded, byte-identical PIL 10.2 plates (no numpy, no wall clock).

    python3 tools/art/rooms/R01.py            # every R01 asset
    python3 tools/art/rooms/R01.py boat line  # only the named stems

Writes ONLY under assets/rooms/R01/. Every output is 1448x1086 so overlays register by plain
alpha compositing at (0, 0): backdrops and close-up plates are opaque RGB, overlays are RGBA
with true alpha. Flat front elevation, approved palette, navy ink contours, matte fills,
low-amplitude paper grain (max +/-6/255). No text is baked: the view draws every label.

Each asset is one function painted at 2x and downsampled. Its random stream is seeded with
zlib.crc32 of its file name. Where several assets must share a layout (the cloud strata of the
storm bands, the wave strokes of the three wave frames), the shared layout has its own fixed
crc32 seed, so frames line up and reruns stay byte-identical.

Plate-space geometry (horizon, jetty, pilings, bell, boat, pennant, close-up rects) is fixed by
the R01 art contract; see the constants below. The R02 contract drawing uses the same SILHOUETTE
and PENNANT numbers: hull x860-1290 (raked bow left, square stern right), gunwale y780,
waterline y870, cabin x960-1120 y680-780, window x990-1090 y700-756, mast x1180 y520-780,
pennant 100x56 at x1182-1282 y524-580 with a 14 px swallowtail at the fly; paper stripes 12 px
wide at offsets 16/44/72 (false boat, three) or 26/62 (real launch and contract, two).
"""
from __future__ import annotations

import math
import random
import sys
import zlib
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "rooms" / "R01"
W, H = 1448, 1086
S = 2  # supersampling factor

# ---------------------------------------------------------------- palette
INK = (23, 43, 54)        # #172B36 ink navy
PAPER = (216, 206, 181)   # #D8CEB5 old paper
COPPER = (97, 125, 116)   # #617D74 oxidised copper
SEAGLASS = (143, 163, 166)  # #8FA3A6
STORM = (34, 48, 58)      # #22303A storm navy
BRASS = (176, 138, 74)    # #B08A4A tarnished brass
TIMBER = (103, 93, 81)    # #675D51 damp timber
SOOT = (41, 41, 41)       # #292929
AMBER = (195, 153, 89)    # #C39959 lamp amber
BRUISE = (116, 101, 119)  # #746577 band-7 drift only
GREEN = (78, 108, 101)    # dark sea-glass green (outer door)
ENAMEL_G = (112, 150, 136)  # sea-glass green enamel (SET edge)

HORIZON = 470
WATERLINE = 870
PILINGS = [470 + 105 * i for i in range(9)]
JETTY_END = 1330          # deck, rail and the last stanchion stop here
CLEAT_X = 1314            # the mooring cleat and its line (clear of the launch's stern at 1290)
STUMP_X = 1368            # the tenth piling (s3+), past the jetty's end, whole in frame
# The bell's still water: a hard, mirror-flat ellipse about three bell-widths across. No
# wave, ripple or sea stroke crosses it; the bell's reflection inside it is perfectly still.
CALM = (700, 906, 100, 50)   # cx, cy, rx, ry
BELL_PROF = [(808, 17), (816, 19), (826, 20), (838, 21), (848, 23), (856, 26), (862, 29), (867, 31), (872, 32)]


def hexc(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def seed_of(name: str) -> int:
    return zlib.crc32(name.encode("utf-8"))


def clamp(v, lo, hi):
    return lo if v < lo else hi if v > hi else v


# ---------------------------------------------------------------- canvas
class Cv:
    """A 2x-supersampled RGBA canvas addressed in plate (1x) coordinates."""

    def __init__(self, rng: random.Random, bg=None):
        self.r = rng
        self.wk = 1.0  # contour weight: heavier in the foreground, lighter far off
        self.im = Image.new("RGBA", (W * S, H * S), (bg + (255,)) if bg else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    # -- layers
    def layer(self):
        return Cv(self.r)

    def comp(self, other: "Cv", opacity=1.0, mask=None):
        src = other.im
        if opacity < 1.0:
            a = src.getchannel("A").point(lambda v: int(v * opacity + 0.5))
            src = src.copy()
            src.putalpha(a)
        if mask is not None:
            a = ImageChops.multiply(src.getchannel("A"), mask)
            src = src.copy()
            src.putalpha(a)
        self.im.alpha_composite(src)

    # -- primitives
    @staticmethod
    def P(pts):
        return [(x * S, y * S) for x, y in pts]

    def _blend(self, bbox, alpha, fn):
        """Draw fn(draw, ox, oy) opaque into a scratch tile, then composite it at `alpha`.
        ImageDraw on RGBA replaces pixels, so translucent marks must never be drawn direct."""
        if alpha >= 255:
            fn(self.d, 0, 0)
            return
        if alpha <= 0:
            return
        x0 = max(0, int(bbox[0] * S) - 4)
        y0 = max(0, int(bbox[1] * S) - 4)
        x1 = min(W * S, int(bbox[2] * S) + 5)
        y1 = min(H * S, int(bbox[3] * S) + 5)
        if x1 <= x0 or y1 <= y0:
            return
        tile = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        fn(ImageDraw.Draw(tile), -x0, -y0)
        tile.putalpha(tile.getchannel("A").point(lambda v: v * alpha // 255))
        self.im.alpha_composite(tile, dest=(x0, y0))

    @staticmethod
    def _bb(pts, pad=0.0):
        xs = [q[0] for q in pts]
        ys = [q[1] for q in pts]
        return (min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad)

    def fillpoly(self, pts, fill, alpha=255):
        pts = list(pts)
        self._blend(self._bb(pts), alpha, lambda d, ox, oy: d.polygon(
            [(x * S + ox, y * S + oy) for x, y in pts], fill=fill + (255,)))

    def stroke(self, pts, w=2.4, col=INK, closed=False, alpha=255, jitter=0.14):
        pts = list(pts)
        if closed:
            pts = pts + [pts[0]]
        if len(pts) < 2:
            return
        w = w * self.wk
        base = w * (1 + self.r.uniform(-jitter, jitter))
        segs = []
        cur = base
        for a, b in zip(pts, pts[1:]):
            seg = math.dist(a, b)
            cur = clamp(cur + self.r.uniform(-jitter, jitter) * w * min(1.0, seg / 12.0),
                        w * (1 - 2 * jitter), w * (1 + 2 * jitter))
            segs.append((a, b, max(1.0, cur * S)))
        c = col + (255,)

        def draw(d, ox, oy):
            for i, (a, b, ww) in enumerate(segs):
                d.line([(a[0] * S + ox, a[1] * S + oy), (b[0] * S + ox, b[1] * S + oy)], fill=c,
                       width=int(round(ww)))
                rr = ww / 2.0
                for q in ((a, b) if i == 0 else (b,)):
                    d.ellipse([q[0] * S + ox - rr, q[1] * S + oy - rr, q[0] * S + ox + rr, q[1] * S + oy + rr],
                              fill=c)
        self._blend(self._bb(pts, w * 2 + 2), alpha, draw)

    def poly(self, pts, fill=None, ink=INK, w=2.4, alpha=255):
        if fill is not None:
            self.fillpoly(pts, fill, alpha)
        if ink is not None and w > 0:
            self.stroke(pts, w, ink, closed=True)

    def rect(self, x0, y0, x1, y1, fill=None, ink=INK, w=2.4, alpha=255):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill, ink, w, alpha)

    def box(self, x0, y0, x1, y1, fill, alpha=255):
        """Plain filled rectangle, no contour."""
        self._blend((x0, y0, x1, y1), alpha, lambda d, ox, oy: d.rectangle(
            [x0 * S + ox, y0 * S + oy, x1 * S - 1 + ox, y1 * S - 1 + oy], fill=fill + (255,)))

    def ell(self, cx, cy, rx, ry, fill=None, ink=INK, w=2.4, alpha=255):
        bb = (cx - rx, cy - ry, cx + rx, cy + ry)
        if fill is not None:
            self._blend(bb, alpha, lambda d, ox, oy: d.ellipse(
                [bb[0] * S + ox, bb[1] * S + oy, bb[2] * S + ox, bb[3] * S + oy], fill=fill + (255,)))
        if ink is not None and w > 0:
            ww = max(1, int(round(w * self.wk * (1 + self.r.uniform(-0.1, 0.1)) * S)))
            self._blend(bb, alpha, lambda d, ox, oy: d.ellipse(
                [bb[0] * S + ox, bb[1] * S + oy, bb[2] * S + ox, bb[3] * S + oy], outline=ink + (255,), width=ww))

    def line(self, pts, col=INK, w=2.4, alpha=255):
        self.stroke(pts, w, col, alpha=alpha, jitter=0.08)

    def hrows(self, y0, y1, c0, c1, x0=0, x1=W, ya=None, yb=None):
        """Vertical gradient c0 at ya to c1 at yb, filling rows y0..y1 between x0..x1."""
        ya = y0 if ya is None else ya
        yb = y1 if yb is None else yb
        for row in range(int(y0 * S), int(y1 * S)):
            t = clamp((row / S - ya) / max(1e-6, (yb - ya)), 0.0, 1.0)
            self.d.line([(x0 * S, row), (x1 * S - 1, row)], fill=mix(c0, c1, t) + (255,))

    # -- output
    def finish(self, name, mode, rng=None, grain=True):
        img = self.im.resize((W, H), Image.LANCZOS)
        if grain:
            img = add_grain(img, rng or self.r)
        if mode == "RGB":
            base = Image.new("RGB", (W, H), (0, 0, 0))
            base.paste(img.convert("RGB"), (0, 0), img.getchannel("A"))
            out = base
        else:
            a = img.getchannel("A")
            rgb = img.convert("RGB")
            keep = a.point(lambda v: 255 if v else 0)
            rgb = Image.composite(rgb, Image.new("RGB", (W, H), (0, 0, 0)), keep)
            out = rgb.copy()
            out.putalpha(a)
        OUT.mkdir(parents=True, exist_ok=True)
        out.save(OUT / f"{name}.png", optimize=False)
        return out


def add_grain(img, rng, amp=6):
    """Paper grain: seeded fine noise plus a soft mottle, total within +/-amp."""
    fine = Image.frombytes("L", (W, H), rng.randbytes(W * H)).point(lambda v: v * (amp + 1) // 256)
    cw, ch = W // 9 + 1, H // 9 + 1
    coarse = Image.frombytes("L", (cw, ch), rng.randbytes(cw * ch)).resize((W, H), Image.BICUBIC)
    coarse = coarse.point(lambda v: v * (amp + 1) // 256)
    g = ImageChops.add(fine, coarse, 1.0, 0)  # 0 .. 2*amp
    g3 = Image.merge("RGB", (g, g, g))
    rgb = ImageChops.add(img.convert("RGB"), g3, 1.0, -amp)
    out = rgb.convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def blur_mask(size_pts_fn, radius):
    """An L mask (2x size) built by size_pts_fn(draw) and gaussian-blurred by radius (1x px)."""
    m = Image.new("L", (W * S, H * S), 0)
    size_pts_fn(ImageDraw.Draw(m))
    return m.filter(ImageFilter.GaussianBlur(radius * S)) if radius else m


def glow(cv, draw_fn, colour, radius, opacity):
    m = blur_mask(draw_fn, radius)
    lay = Image.new("RGBA", (W * S, H * S), colour + (0,))
    lay.putalpha(m.point(lambda v: int(v * opacity)))
    cv.im.alpha_composite(lay)


def smooth(pts, steps=6, closed=False):
    """Catmull-Rom through pts."""
    src = list(pts)
    if closed:
        ext = [src[-1]] + src + [src[0], src[1]]
        rng_i = range(1, len(src) + 1)
    else:
        ext = [src[0]] + src + [src[-1]]
        rng_i = range(1, len(src))
    out = []
    for i in rng_i:
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t
                                    + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3)
                             for k in (0, 1)))
    if not closed:
        out.append(src[-1])
    return out


# ---------------------------------------------------------------- painted finish
def poly_mask(pts, blur=0.0):
    """L mask (2x) of a polygon in plate coordinates, optionally softened."""
    m = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(m).polygon(Cv.P(pts), fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur * S)) if blur else m


def grad_mask(x0, y0, x1, y1, a0, a1, axis="y", ease=1.0):
    """L mask (2x): a linear ramp a0 -> a1 (0..1) across the box along `axis`, 0 outside."""
    m = Image.new("L", (W * S, H * S), 0)
    bx0, by0, bx1, by1 = (int(v * S) for v in (x0, y0, x1, y1))
    n = max(1, (by1 - by0) if axis == "y" else (bx1 - bx0))
    vals = bytes(int(255 * clamp(a0 + (a1 - a0) * (i / max(1, n - 1)) ** ease, 0, 1)) for i in range(n))
    strip = Image.frombytes("L", (1, n) if axis == "y" else (n, 1), vals)
    strip = strip.resize((max(1, bx1 - bx0), max(1, by1 - by0)), Image.NEAREST)
    m.paste(strip, (bx0, by0))
    return m


def tint(cv, mask, colour, opacity=1.0):
    """Lay `colour` through an L mask (a painted glaze: shading, light, stains)."""
    lay = Image.new("RGBA", (W * S, H * S), colour + (0,))
    lay.putalpha(mask.point(lambda v: int(v * opacity)) if opacity != 1.0 else mask)
    cv.im.alpha_composite(lay)


def mul_masks(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = ImageChops.multiply(out, m)
    return out


def wood_grain(cv, r, x0, y0, x1, y1, base, vertical=True, lines=6, knots=True, alpha=0.55):
    """Painted grain inside one board: long wavering strokes a shade either side of the
    board's colour, the odd knot with the grain swelling round it."""
    lay = cv.layer()
    dark = mix(base, INK, 0.32)
    light = mix(base, PAPER, 0.22)
    across0, across1 = (x0, x1) if vertical else (y0, y1)
    along0, along1 = (y0, y1) if vertical else (x0, x1)
    span = across1 - across0
    knot = None
    if knots and r.random() < 0.45 and span > 10:
        knot = (r.uniform(across0 + span * 0.3, across1 - span * 0.3), r.uniform(along0 + 20, max(along0 + 21, along1 - 20)))
    for g in range(lines):
        u = across0 + span * (g + r.uniform(0.2, 0.8)) / lines
        ph = r.uniform(0, 6.28)
        per = r.uniform(60, 160)
        amp = r.uniform(0.4, 1.4)
        pts = []
        t = along0 + r.uniform(0, 30)
        end = along1 - r.uniform(0, 40)
        while t <= end:
            off = amp * math.sin(t / per + ph)
            if knot:
                d = t - knot[1]
                if abs(d) < 26:
                    push = (1 - abs(d) / 26) * 6
                    off += push if u >= knot[0] else -push
            q = clamp(u + off, across0 + 0.8, across1 - 0.8)
            pts.append((q, t) if vertical else (t, q))
            t += 10
        if len(pts) > 1:
            lay.stroke(pts, r.uniform(0.6, 1.1), dark if g % 3 else light, jitter=0.2)
    if knot:
        kx, ky = (knot[0], knot[1]) if vertical else (knot[1], knot[0])
        rx, ry = (2.4, 5.0) if vertical else (5.0, 2.4)
        lay.ell(kx, ky, rx + 2.2, ry + 3, fill=None, ink=dark, w=0.8)
        lay.ell(kx, ky, rx, ry, fill=mix(base, INK, 0.45), ink=None)
    cv.comp(lay, alpha)


def weather_board(cv, r, x0, y0, x1, y1, base, vertical=True, top_dark=0.22, foot_dark=0.3, foot=40):
    """Weathering on a board: rain-darkened runs from the top, rot-dark at the foot, a worn
    light edge on the lit (left/top) side."""
    if vertical:
        tint(cv, grad_mask(x0, y0, x1, y0 + (y1 - y0) * 0.35, top_dark, 0.0), mix(base, INK, 0.5))
        tint(cv, grad_mask(x0, y1 - foot, x1, y1, 0.0, foot_dark), mix(base, (40, 52, 46), 0.6))
        tint(cv, grad_mask(x0, y0, x0 + max(2, (x1 - x0) * 0.22), y1, 0.28, 0.0, axis="x"), mix(base, PAPER, 0.5))
        for k in range(r.randint(0, 2)):
            sx = r.uniform(x0 + 2, x1 - 4)
            tint(cv, grad_mask(sx, y0, sx + r.uniform(2, 5), y0 + r.uniform(40, (y1 - y0) * 0.8), 0.3, 0.0),
                 mix(base, INK, 0.5))
    else:
        tint(cv, grad_mask(x0, y0, x1, y0 + max(2, (y1 - y0) * 0.3), 0.3, 0.0), mix(base, PAPER, 0.5))
        tint(cv, grad_mask(x0, y1 - (y1 - y0) * 0.4, x1, y1, 0.0, foot_dark), mix(base, INK, 0.5))


def soft_mass(cv, blobs, colour, light, shade, blur=3.0, lit_up=0.45, shade_a=0.5):
    """A painted soft mass (cloud, mist bank): the union of ellipses, edges softened, lit
    from above and a shade deeper toward its base. No contour, no cast strip."""
    xs = [b[0] - b[2] for b in blobs] + [b[0] + b[2] for b in blobs]
    ys = [b[1] - b[3] for b in blobs] + [b[1] + b[3] for b in blobs]
    x0, y0, x1, y1 = min(xs) - 12, min(ys) - 12, max(xs) + 12, max(ys) + 12
    tw, th = int((x1 - x0) * S) + 1, int((y1 - y0) * S) + 1
    if tw <= 2 or th <= 2:
        return
    m = Image.new("L", (tw, th), 0)
    md = ImageDraw.Draw(m)
    for cx, cy, rx, ry in blobs:
        md.ellipse([(cx - rx - x0) * S, (cy - ry - y0) * S, (cx + rx - x0) * S, (cy + ry - y0) * S], fill=255)
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur * S))
    # vertical value ramp: light on the crown, shade at the belly
    ramp = Image.frombytes("L", (1, th), bytes(int(255 * shade_a * clamp((i / th - 0.45) / 0.55, 0, 1) ** 1.3)
                                              for i in range(th)))
    ramp = ramp.resize((tw, th), Image.NEAREST)
    tile = Image.new("RGBA", (tw, th), colour + (255,))
    tile.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", (tw, th), shade).split(), ramp)))
    crown = Image.frombytes("L", (1, th), bytes(int(255 * lit_up * clamp(1 - i / (th * 0.55), 0, 1)) for i in range(th)))
    tile.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", (tw, th), light).split(),
                                              crown.resize((tw, th), Image.NEAREST))))
    tile.putalpha(m)
    cv.im.alpha_composite(tile, dest=(int(x0 * S), int(y0 * S)))


# =================================================================== backdrops
HEADLAND = [(1060, 470), (1078, 466), (1098, 459), (1118, 450), (1138, 441), (1156, 435),
            (1170, 432), (1260, 432), (1270, 436), (1280, 446), (1288, 458), (1296, 470)]
SKERRY = [(1384, 470), (1392, 464), (1406, 461), (1424, 459), (1448, 457), (1448, 470)]
CAUSEWAY_GAPS = [(560, 600), (740, 790), (900, 950)]


def calm_mask(grow=0.0, blur=0.0):
    cx, cy, rx, ry = CALM
    m = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(m).ellipse([(cx - rx - grow) * S, (cy - ry - grow) * S, (cx + rx + grow) * S,
                               (cy + ry + grow) * S], fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur * S)) if blur else m


def cut_calm(cv, grow=0.0):
    """Erase everything inside the calm ellipse (wave dashes stop exactly at its edge)."""
    keep = ImageChops.invert(calm_mask(grow))
    cv.im.putalpha(ImageChops.multiply(cv.im.getchannel("A"), keep))


def paint_calm(cv, sea, sky, haze=0.0):
    """The mirror under the bell: one flat glassy tone (it holds the sky, not the sea), a
    crisp, perfectly still upside-down bell, the still stubs of the two pilings inside it,
    and a hard rim."""
    cx, cy, rx, ry = CALM
    glass = mix(mix(sea, sky, 0.3), PAPER, 0.04)
    lay = cv.layer()
    lay.box(cx - rx - 4, cy - ry - 4, cx + rx + 4, cy + ry + 4, glass)
    # the two pilings it surrounds, mirrored and still
    for px in (680, 785):
        pc = mix(mix((112, 100, 85), glass, 0.35), INK, 0.08)
        lay.rect(px - 13, 872, px + 13, 960, fill=pc, ink=mix(INK, glass, 0.35), w=1.6)
        lay.box(px - 13, 872, px + 13, 888, mix((62, 74, 60), glass, 0.3))
    # the bell, upside down from the lip line, crisp
    lip = 872
    br = mix(BRASS, glass, 0.22)
    right = [(cx + w, 2 * lip - y) for y, w in BELL_PROF]
    left = [(cx - w, 2 * lip - y) for y, w in reversed(BELL_PROF)]
    body = smooth(right, 4) + smooth(left, 4)
    lay.fillpoly(body, br)
    # value modelling, mirrored: lit side left, shade right
    lay.fillpoly([(cx + 6, 2 * lip - 812), (cx + 24, 2 * lip - 812), (cx + 30, lip + 2), (cx + 10, lip + 2)],
                 mix(br, INK, 0.25))
    lay.fillpoly([(cx - 16, 2 * lip - 816), (cx - 11, 2 * lip - 812), (cx - 14, lip + 6), (cx - 20, lip + 8)],
                 mix(br, PAPER, 0.35))
    lay.stroke(body, 1.8, mix(INK, glass, 0.15), closed=True, jitter=0.0)
    lay.rect(cx - 8, 2 * lip - 808, cx + 8, 2 * lip - 798, fill=mix(br, INK, 0.25), ink=mix(INK, glass, 0.15), w=1.4)
    y = 2 * lip - 798
    k = 0
    while y < cy + ry + 6:
        if k % 2 == 0:
            lay.ell(cx, y + 5, 3.2, 5.2, fill=None, ink=mix(INK, glass, 0.3), w=1.6)
        else:
            lay.stroke([(cx, y), (cx, y + 10)], 1.8, mix(INK, glass, 0.3), jitter=0.0)
        y += 8
        k += 1
    # a pale line where the lip meets its reflection: dead level, edge to edge of the bell
    lay.stroke([(cx - 34, lip + 0.5), (cx + 34, lip + 0.5)], 1.2, mix(glass, PAPER, 0.6), jitter=0.0)
    cv.comp(lay, mask=calm_mask())
    # hard rim: a light far edge, a darker near edge
    top = [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a))) for a in range(180, 361, 4)]
    bot = [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a))) for a in range(0, 181, 4)]
    cv.stroke(top, 1.6, mix(glass, PAPER, 0.55), alpha=int(230 * (1 - 0.4 * haze)), jitter=0.0)
    cv.stroke(bot, 1.4, mix(sea, INK, 0.5), alpha=int(200 * (1 - 0.4 * haze)), jitter=0.0)


def h_tilt(x, tilt):
    return HORIZON + tilt * (x - 1205)


def paint_clouds(cv, sky, lay_seed, y_lo, y_hi, dark=0.22, light=0.22, ink_a=70, count=9):
    """Soft painted cloud masses: heaped crowns lit from above, a deeper belly, softened
    edges, no contour and no cast strip. The layout seed is shared by every band."""
    r = random.Random(lay_seed)
    for i in range(count):
        cy = r.uniform(y_lo, y_hi)
        cx = r.uniform(-60, W + 60)
        wid = r.uniform(200, 460) * (0.7 + 0.5 * (cy - y_lo) / max(1, y_hi - y_lo))
        n = r.randint(3, 6)
        x0 = cx - wid / 2
        blobs = []
        for k in range(n):
            t = (k + 0.5) / n
            rx = wid / n * r.uniform(0.62, 0.9)
            ry = rx * r.uniform(0.45, 0.7) * (0.6 + 0.6 * math.sin(t * math.pi))
            ex = x0 + t * wid
            blobs.append((ex, cy - ry, rx, ry))
        # the flattened belly: a long low lozenge under the heaps
        blobs.append((cx, cy - 7, wid / 2 + 30, 9))
        far = (cy - y_lo) / max(1, y_hi - y_lo)
        body = mix(sky, PAPER, light * (1.1 + 0.4 * far))
        soft_mass(cv, blobs, body, mix(body, PAPER, 0.4), mix(sky, STORM, dark),
                  blur=2.0 + 2.0 * (1 - far), lit_up=0.6)


def paint_ceiling(cv, sky, lay_seed, y_bottom):
    """The low storm deck. Full bleed: its edge runs past both sides of the canvas, so no
    sky wedge shows at either corner. A soft painted underside, no contour."""
    r = random.Random(lay_seed)
    tone = mix(sky, STORM, 0.32)
    pts = [(-40, -40), (W + 40, -40)]
    edge = []
    x = W + 40
    while x > -40:
        edge.append((x, y_bottom + r.uniform(-14, 10)))
        x -= r.uniform(50, 110)
    edge.append((-40, y_bottom + r.uniform(-14, 10)))
    sm = smooth(edge, 6)
    cv.fillpoly(pts + sm, tone)
    # painted value: darker at the top of the deck, a lighter wet sheen along its belly
    tint(cv, grad_mask(0, 0, W, y_bottom, 0.35, 0.0), mix(tone, INK, 0.5))
    blobs = []
    for (x0, y0), (x1, y1) in zip(edge, edge[1:]):
        blobs.append(((x0 + x1) / 2, (y0 + y1) / 2 - 6, abs(x0 - x1) / 2 + 10, 14))
    soft_mass(cv, blobs, mix(tone, SEAGLASS, 0.1), mix(tone, SEAGLASS, 0.18), mix(tone, STORM, 0.3), blur=4,
              lit_up=0.3)
    # rain veils hanging from the deck (static, faint, soft-edged)
    lay = cv.layer()
    for i in range(26):
        vx = r.uniform(-40, W + 40)
        vw = r.uniform(30, 90)
        lay.fillpoly([(vx, y_bottom - 4), (vx + vw, y_bottom - 4), (vx + vw - 18, HORIZON - 2),
                      (vx - 18, HORIZON - 2)], mix(tone, STORM, 0.2))
    a = lay.im.getchannel("A").filter(ImageFilter.GaussianBlur(5 * S)).point(lambda v: v * 30 // 255)
    lay.im.putalpha(a)
    cv.im.alpha_composite(lay.im)


def paint_causeway(cv, haze, sky_hor, r):
    # far stone fades toward a shade under the sky, so even in the toneless band it is a shape,
    # not a wireframe
    under = mix(sky_hor, INK, 0.14)
    stone = mix((132, 134, 124), under, haze)
    dark = mix((84, 90, 86), under, haze)
    ink_a = int(255 * (1 - haze) ** 0.8) if haze < 0.7 else 0
    segs = []
    x = 430
    for g0, g1 in CAUSEWAY_GAPS + [(1040, 1040)]:
        segs.append((x, g0))
        x = g1
    for s0, s1 in segs:
        x = s0
        tops = []
        while x < s1:
            wdt = min(s1 - x, r.uniform(16, 38))
            top = r.uniform(476, 481)
            if x == s0 or x + wdt >= s1:
                top = r.uniform(479, 484)  # broken, lower stones at each gap
            cv.rect(x, top, x + wdt, 492, fill=stone, ink=None)
            cv.box(x, 488, x + wdt, 492, dark)
            tops.append((x, top, x + wdt))
            x += wdt
        # contours: ragged top, flat base, stone joints
        outline = [(s0, 492)]
        for a, t, b in tops:
            outline += [(a, t), (b, t)]
        outline += [(s1, 492)]
        cv.stroke(outline, 2.0, INK, alpha=ink_a)
        for a, t, b in tops[1:]:
            cv.stroke([(a, t + 1), (a, 491)], 1.3, INK, alpha=int(ink_a * 0.7))


def paint_headland(cv, land, haze_ink, grass, r, tilt=0.0):
    base = 478 if tilt else 470
    pts = [(x, y) for x, y in HEADLAND]
    pts[0] = (1060, base)
    pts[-1] = (1296, base)
    sm = smooth(pts[1:-1], 6)
    body = [pts[0]] + sm + [pts[-1]]
    cv.fillpoly(body, land)
    sk = [(x, y) for x, y in SKERRY]
    sk[0] = (1384, base)
    sk[-1] = (1448, base)
    cv.fillpoly(sk, land)
    # rock strata (front elevation cliff faces)
    face = mix(land, STORM, 0.25)
    for k in range(7):
        y = 445 + k * 4 + r.uniform(-1, 1)
        xa = 1110 + k * 6 + r.uniform(0, 30)
        xb = 1285 - k * 3 - r.uniform(0, 30)
        cv.stroke([(xa, y), (xb, y + r.uniform(-1, 1))], 1.2, face, alpha=200)
    cv.stroke(sm[1:], 1.8, mix(grass, land, 0.2), alpha=220)
    if haze_ink:
        cv.stroke(body, 2.0, INK, alpha=haze_ink, closed=False)
        cv.stroke(sk[:-1], 1.8, INK, alpha=haze_ink)


def paint_lighthouse(cv, lamp: str, haze=0.0, sky=SEAGLASS):
    white = mix(PAPER, sky, haze)
    band = mix(STORM, sky, haze)
    a = int(255 * (1 - 0.6 * haze))
    if lamp == "lit":
        glow(cv, lambda d: d.ellipse([1196 * S, 312 * S, 1224 * S, 348 * S], fill=255), AMBER, 30, 0.75)
    # tower: tapers slightly; base x1196-1224 at y432
    tower = [(1196, 432), (1199, 345), (1221, 345), (1224, 432)]
    cv.poly(tower, white, INK, 2.2, alpha=255)
    cv.fillpoly([(1197.4, 392), (1222.6, 392), (1223.1, 405), (1196.9, 405)], band)
    cv.stroke([(1197.4, 392), (1222.6, 392)], 1.4, INK, alpha=a)
    cv.stroke([(1196.9, 405), (1223.1, 405)], 1.4, INK, alpha=a)
    cv.rect(1207, 412, 1213, 424, fill=band, ink=INK, w=1.2)  # door
    # gallery and lantern
    cv.rect(1186, 343, 1234, 348, fill=band, ink=INK, w=1.6)
    glass = AMBER if lamp == "lit" else mix(STORM, SEAGLASS, 0.35)
    cv.rect(1190, 318, 1230, 343, fill=glass, ink=INK, w=2.0)
    if lamp == "lit":
        cv.box(1202, 322, 1218, 340, mix(AMBER, PAPER, 0.55))
    for mx in (1200, 1210, 1220):
        cv.stroke([(mx, 319), (mx, 342)], 1.3, INK, alpha=220)
    cv.poly([(1188, 318), (1210, 302), (1232, 318)], band, INK, 2.0)
    cv.stroke([(1210, 302), (1210, 294)], 1.6, INK)
    cv.ell(1210, 293, 2, 2, fill=INK, ink=None)


def paint_sea_texture(cv, sea0, sea1, lay_seed, tilt=0.0, x_from=0, calm=True):
    """Static, quiet sea: long flat strokes, darker and lighter, larger toward the viewer."""
    r = random.Random(lay_seed)
    dark = cv.layer()
    light = cv.layer()
    for i in range(520):
        y = HORIZON + 6 + (r.random() ** 1.35) * (H - HORIZON - 6)
        x = r.uniform(-40, W)
        t = (y - HORIZON) / (H - HORIZON)
        ln = 20 + t * 110 * r.uniform(0.6, 1.3)
        yy = y + tilt * (x - 1205)
        if yy < h_tilt(x, tilt) + 4:
            continue
        tgt = dark if r.random() < 0.55 else light
        col = mix(sea1, INK, 0.35) if tgt is dark else mix(sea0, PAPER, 0.25)
        sag = 1 + t * 3
        tgt.stroke([(x, yy), (x + ln * 0.5, yy + sag * 0.6), (x + ln, yy)], 1.0 + t * 1.6, col, jitter=0.1)
    if calm:
        cut_calm(dark, 1.0)
        cut_calm(light, 1.0)
    cv.comp(dark, 0.45)
    cv.comp(light, 0.35)


def backdrop(name, sky0, sky1, sea0, sea1, *, haze=0.0, lighthouse="lit", causeway=True,
             headland=True, tilt=0.0, ceiling=None, cloud_band=(120, 400), cloud_count=9,
             cloud_ink=70, gulls=False, land=None, land_haze=None, hor_alpha=1.0, calm=True, hor_bold=False):
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r, bg=sky0)
    cv.hrows(0, H, sky0, sky1, ya=0, yb=HORIZON + 20)
    if cloud_count:
        paint_clouds(cv, mix(sky0, sky1, 0.5), seed_of("R01:clouds"), *cloud_band,
                     count=cloud_count, ink_a=cloud_ink)
    if ceiling:
        paint_ceiling(cv, sky0, seed_of("R01:ceiling"), ceiling)
    if gulls:
        for gx, gy, gs in ((520, 210, 9), (566, 188, 7), (612, 232, 8)):
            cv.stroke([(gx - gs, gy - gs * 0.35), (gx - gs * 0.35, gy - gs * 0.05), (gx, gy + gs * 0.2)], 2.0)
            cv.stroke([(gx, gy + gs * 0.2), (gx + gs * 0.35, gy - gs * 0.05), (gx + gs, gy - gs * 0.4)], 2.0)
    # sea below the (possibly tilted) horizon
    sea = cv.layer()
    sea.hrows(min(h_tilt(0, tilt), HORIZON) - 2, H, sea0, sea1, ya=HORIZON, yb=H)
    m = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(m).polygon(Cv.P([(0, h_tilt(0, tilt)), (W, h_tilt(W, tilt)), (W, H), (0, H)]), fill=255)
    cv.comp(sea, mask=m)
    paint_sea_texture(cv, sea0, sea1, seed_of("R01:seatex"), tilt)
    hor = [(0, h_tilt(0, tilt)), (W, h_tilt(W, tilt))]
    if hor_bold:
        # the slanted line has to read first: a hard pale sky edge over a dark sea edge
        band = poly_mask([(0, h_tilt(0, tilt)), (W, h_tilt(W, tilt)), (W, h_tilt(W, tilt) + 46),
                          (0, h_tilt(0, tilt) + 46)], 0)
        tint(cv, mul_masks(band, grad_mask(0, min(h_tilt(0, tilt), HORIZON) - 2, W, HORIZON + 50, 0.55, 0.0)),
             mix(sea1, INK, 0.5))
        cv.stroke([(x, y - 3) for x, y in hor], 4.0, mix(sky1, PAPER, 0.5), alpha=230, jitter=0.02)
        cv.stroke([(x, y + 1) for x, y in hor], 2.6, INK, alpha=220, jitter=0.02)
    else:
        cv.stroke(hor, 2.0, mix(sea0, PAPER, 0.35), alpha=int(150 * hor_alpha), jitter=0.05)
        cv.stroke([(x, y + 2) for x, y in hor], 1.4, INK, alpha=int(90 * hor_alpha), jitter=0.05)
    sky_hor = sky1
    if calm:
        sea_mid = mix(sea0, sea1, (CALM[1] - HORIZON) / (H - HORIZON))
        paint_calm(cv, sea_mid, mix(sky0, sky1, 0.6), haze)
    cv.wk = 0.6   # far off: the lightest contours in the room
    if causeway:
        paint_causeway(cv, haze, sky_hor, random.Random(seed_of("R01:causeway")))
    if headland:
        lh = haze if land_haze is None else land_haze
        land = land or mix(STORM, COPPER, 0.45)
        land = mix(land, sky_hor, lh)
        grass = mix(COPPER, sky_hor, lh)
        paint_headland(cv, land, int(255 * (1 - lh)) if lh < 0.6 else 0, grass,
                       random.Random(seed_of("R01:headland")), tilt)
    if lighthouse:
        cv.wk = 0.8
        paint_lighthouse(cv, lighthouse, haze * 0.6, sky_hor)
    cv.wk = 1.0
    return cv.finish(name, "RGB", r)


SURF_LEFT = 334      # the surface's left edge, standing up behind the station


def surf_top(x):
    """The surface's top edge: bowed, highest in the middle, as if it stands and curves away."""
    u = clamp((x - SURF_LEFT) / (W + 200 - SURF_LEFT), 0, 1)
    return 214 - 30 * math.sin(math.pi * u)


def back_b7():
    name = "back_b7"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r, bg=STORM)
    band = mix(STORM, INK, 0.35)
    dim = mix(STORM, SEAGLASS, 0.52)
    # the storm band, then a strip of dim sky, lighter toward the horizon it no longer has
    cv.hrows(0, 868, band, dim, ya=60, yb=170)
    paint_clouds(cv, mix(band, STORM, 0.5), seed_of("R01:clouds"), 20, 96, dark=0.3, light=0.1, count=5)
    # the surface: a flat, hard-edged silhouette standing in front of that sky
    surf = mix(band, SEAGLASS, 0.16)
    edge = [(x, surf_top(x)) for x in range(SURF_LEFT, W + 60, 24)]
    left = smooth([(SURF_LEFT, surf_top(SURF_LEFT)), (SURF_LEFT - 6, 360), (SURF_LEFT - 10, 560),
                   (SURF_LEFT - 12, 868)], 6)
    outline = list(reversed(left)) + edge + [(W + 60, 868)]
    cv.fillpoly(outline, surf)
    sm = poly_mask(outline)
    # it is lit faintly from above: a paler upper band, then it goes on down, unlit
    tint(cv, mul_masks(sm, grad_mask(0, 170, W, 420, 0.3, 0.0)), mix(surf, SEAGLASS, 0.3))
    tint(cv, mul_masks(sm, grad_mask(0, 600, W, 868, 0.0, 0.45)), mix(surf, INK, 0.5))
    # it is water, standing up: the band's own wave-line strokes, turned to run vertically,
    # longer and heavier toward the bottom the way the near sea's are toward the viewer. No
    # straight seams: every stroke sags sideways like a wave crest does downward.
    wl = cv.layer()
    lay_r = random.Random(seed_of("R01:b7_upright"))
    for i in range(300):
        x = lay_r.uniform(SURF_LEFT + 6, W + 20)
        top = surf_top(x) + 10
        y = top + (lay_r.random() ** 0.9) * (858 - top)
        t = (y - top) / max(1.0, 858 - top)
        ln = 16 + t * 70 * lay_r.uniform(0.6, 1.3)
        if y + ln > 862:
            continue
        sag = (0.8 + t * 2.6) * (1 if lay_r.random() < 0.5 else -1)
        pts = smooth([(x + sag * 0.3, y), (x - sag, y + ln * 0.3), (x - sag * 0.7, y + ln * 0.7),
                      (x + sag * 0.2, y + ln)], 4)
        light = lay_r.random() < 0.55
        wl.stroke(pts, 1.0 + t * 1.6, mix(surf, SEAGLASS, 0.55) if light else mix(surf, INK, 0.55), jitter=0.06)
    cv.comp(wl, 0.55, mask=sm)
    # beyond the surface, small and wrong way up: the lighthouse, lamp lit, hanging from its
    # own base line as if the headland were above it
    deep = cv.layer()
    lx, ly = 1246, 262          # the base line it hangs from
    white = mix(PAPER, surf, 0.35)
    bandc = mix(STORM, surf, 0.2)
    deep.fillpoly(smooth([(lx - 76, ly), (lx - 50, ly - 10), (lx - 18, ly - 22), (lx + 26, ly - 22),
                          (lx + 52, ly - 12), (lx + 80, ly)], 5), mix(mix(STORM, COPPER, 0.45), SEAGLASS, 0.3))
    deep.fillpoly([(lx - 10, ly), (lx + 10, ly), (lx + 8, ly + 62), (lx - 8, ly + 62)], white)
    deep.box(lx - 9.4, ly + 26, lx + 9.4, ly + 35, bandc)
    deep.box(lx - 17, ly + 62, lx + 17, ly + 66, bandc)
    deep.box(lx - 14, ly + 66, lx + 14, ly + 84, mix(AMBER, PAPER, 0.25))
    deep.fillpoly([(lx - 16, ly + 84), (lx + 16, ly + 84), (lx, ly + 96)], bandc)
    deep.box(lx - 0.8, ly + 96, lx + 0.8, ly + 102, bandc)
    cv.comp(deep, 0.55, mask=sm)
    # the station, faint and upside down in it (flat shapes), its office window lit, someone
    # at the desk, head down
    inv = cv.layer()
    ox, top = 860, 226           # the inverted walls' top edge (the station's foot)
    walls = mix(PAPER, SEAGLASS, 0.18)
    inv.box(ox + 30, top, ox + 300, top + 220, walls)                 # walls 220 tall
    inv.box(ox + 30, top + 93, ox + 300, top + 100, COPPER)           # floor band, inverted
    inv.fillpoly([(ox + 18, top + 220), (ox + 312, top + 220), (ox + 252, top + 270),
                  (ox + 78, top + 270)], mix(STORM, SEAGLASS, 0.55))  # roof, hanging below
    inv.box(ox + 234, top + 270, ox + 254, top + 310, mix(TIMBER, PAPER, 0.2))   # chimney
    inv.box(ox + 196, top, ox + 240, top + 80, STORM)                 # door
    inv.box(ox + 70, top + 30, ox + 110, top + 74, mix(STORM, SEAGLASS, 0.18))
    inv.box(ox + 190, top + 120, ox + 250, top + 180, mix(STORM, SEAGLASS, 0.18))
    wx, wy = ox + 110, top + 120                                      # the office window
    inv.box(wx - 6, wy - 6, wx + 66, wy + 66, COPPER)
    inv.box(wx, wy, wx + 60, wy + 60, AMBER)
    inv.box(wx + 6, wy + 6, wx + 54, wy + 54, mix(AMBER, PAPER, 0.3))
    body = (24, 30, 36)
    inv.fillpoly(smooth([(wx + 7, wy), (wx + 9, wy + 14), (wx + 16, wy + 22), (wx + 26, wy + 25),
                         (wx + 34, wy + 25), (wx + 44, wy + 22), (wx + 51, wy + 14), (wx + 53, wy)], 4), body)
    inv.ell(wx + 30, wy + 34, 7.5, 9, fill=body, ink=None)
    inv.box(wx + 28, wy, wx + 32, wy + 60, INK)
    inv.box(wx, wy + 28, wx + 60, wy + 32, INK)
    cv.comp(inv, 0.25, mask=sm)
    # its lit window again, a step stronger: the one thing in it that holds its colour
    lit = cv.layer()
    lit.box(wx + 6, wy + 6, wx + 54, wy + 54, mix(AMBER, PAPER, 0.3))
    lit.fillpoly(smooth([(wx + 7, wy + 6), (wx + 9, wy + 14), (wx + 16, wy + 22), (wx + 26, wy + 25),
                         (wx + 34, wy + 25), (wx + 44, wy + 22), (wx + 51, wy + 14), (wx + 53, wy + 6)], 4), body)
    lit.ell(wx + 30, wy + 34, 7.5, 9, fill=body, ink=None)
    lit.box(wx + 28, wy + 6, wx + 32, wy + 54, INK)
    lit.box(wx + 6, wy + 28, wx + 54, wy + 32, INK)
    cv.comp(lit, 0.2, mask=sm)
    # calm dark near-water strip: it reflects nothing at all
    near = hexc("#2A3A40")
    cv.box(0, 868, W, H, near)
    cv.stroke([(0, 868), (W, 868)], 2.0, mix(near, SEAGLASS, 0.3), alpha=160, jitter=0.03)
    gl = cv.layer()
    for i in range(30):
        y = 880 + r.random() ** 1.4 * 200
        x = r.uniform(0, W)
        ln = 60 + (y - 880) * 0.8
        gl.stroke([(x, y), (x + ln, y)], 1.6, mix(near, SEAGLASS, 0.4), jitter=0.04)
    cv.comp(gl, 0.4)
    return cv.finish(name, "RGB", r)


# =================================================================== foreground
def paint_station(cv, r):
    walls = mix(PAPER, SEAGLASS, 0.18)
    trim = COPPER
    # walls
    cv.rect(30, 300, 300, 520, fill=walls, ink=INK, w=2.6)
    # clapboard lines
    for y in range(312, 520, 12):
        cv.stroke([(32, y), (298, y)], 1.0, mix(walls, INK, 0.35), alpha=200, jitter=0.05)
        tint(cv, grad_mask(32, y + 1, 298, y + 6, 0.22, 0.0), mix(walls, INK, 0.5))   # each board's lap shadow
    tint(cv, grad_mask(30, 306, 300, 352, 0.45, 0.0, ease=0.8), mix(walls, INK, 0.6))  # under the eaves
    for sx in (120, 150, 200, 232, 84):
        tint(cv, grad_mask(sx, 410, sx + 5, 410 + r.uniform(30, 90), 0.25, 0.0), mix(walls, (96, 80, 60), 0.6))
    cv.rect(30, 300, 40, 520, fill=trim, ink=INK, w=1.8)
    cv.rect(290, 300, 300, 520, fill=trim, ink=INK, w=1.8)
    cv.rect(30, 420, 300, 427, fill=trim, ink=INK, w=1.6)  # floor band
    # chimney (behind the ridge, right of the lighthouse_roof column)
    cv.rect(234, 222, 254, 262, fill=mix(TIMBER, SOOT, 0.25), ink=INK, w=2.2)
    cv.rect(231, 216, 257, 224, fill=SOOT, ink=INK, w=2.0)
    # hipped roof
    roof = [(18, 300), (78, 250), (252, 250), (312, 300)]
    cv.poly(roof, STORM, INK, 2.6)
    for k in range(1, 5):
        y = 250 + k * 10
        x0 = 78 - (y - 250) * 1.2
        x1 = 252 + (y - 250) * 1.2
        cv.stroke([(x0 + 2, y), (x1 - 2, y)], 1.0, mix(STORM, SEAGLASS, 0.3), alpha=200, jitter=0.05)
    cv.stroke([(78, 250), (252, 250)], 3.0, INK)
    cv.rect(16, 300, 314, 306, fill=mix(STORM, SEAGLASS, 0.3), ink=INK, w=1.8)  # fascia
    # windows: office (x110-170, y340-400) and its twin
    for x0 in (110, 190):
        station_window(cv, x0, 340, lit=False)
    # ground floor: door and small window
    cv.rect(196, 440, 240, 520, fill=STORM, ink=INK, w=2.2)
    cv.rect(190, 434, 246, 440, fill=trim, ink=INK, w=1.6)
    cv.ell(232, 482, 2.2, 2.2, fill=BRASS, ink=None)
    station_window(cv, 70, 446, lit=False, w=40, h=44)


def station_window(cv, x0, y0, lit, w=60, h=60):
    cv.rect(x0 - 6, y0 - 6, x0 + w + 6, y0 + h + 6, fill=COPPER, ink=INK, w=2.0)
    glass = AMBER if lit else mix(STORM, SEAGLASS, 0.18)
    cv.rect(x0, y0, x0 + w, y0 + h, fill=glass, ink=INK, w=1.8)
    if not lit:
        cv.stroke([(x0 + 6, y0 + h - 8), (x0 + w * 0.55, y0 + 6)], 2.0, mix(glass, SEAGLASS, 0.5), alpha=150)
    cv.rect(x0 - 8, y0 + h + 4, x0 + w + 8, y0 + h + 10, fill=mix(COPPER, PAPER, 0.25), ink=INK, w=1.6)


def window_bars(cv, x0, y0, w=60, h=60):
    cv.stroke([(x0 + w / 2, y0), (x0 + w / 2, y0 + h)], 2.4, INK)
    cv.stroke([(x0, y0 + h / 2), (x0 + w, y0 + h / 2)], 2.4, INK)


def paint_land(cv, r):
    rock = (92, 89, 80)
    rock_d = mix(rock, INK, 0.3)
    top = [(0, 505), (40, 502), (140, 500), (260, 501), (320, 505), (380, 512), (430, 522), (446, 540)]
    shore = top + [(452, 600), (450, 700), (452, 780), (458, 860), (470, 880), (520, 930),
                   (560, 990), (600, 1086), (0, 1086)]
    cv.fillpoly(shore, rock)
    cv.stroke(top, 2.4, INK)
    cv.stroke([(446, 540), (452, 600), (450, 700), (452, 780), (458, 860), (470, 880), (520, 930),
               (560, 990), (600, 1086)], 2.4, INK)
    cv.stroke([(p[0], p[1] + 3) for p in top[:-1]], 2.0, mix(COPPER, PAPER, 0.15), alpha=220)
    # shingle in front of the shed and down to the water
    for i in range(46):
        y = r.uniform(934, 1080)
        xmax = 430 + (y - 922) * 1.0
        x = r.uniform(-10, min(xmax, 590))
        rx = r.uniform(8, 20) * (0.7 + (y - 922) / 300)
        ry = rx * r.uniform(0.4, 0.55)
        tone = mix(rock, PAPER if r.random() < 0.35 else INK, r.uniform(0.05, 0.13))
        cv.ell(x, y, rx, ry, fill=tone, ink=mix(INK, rock, 0.3), w=1.4)
    for i in range(14):  # rocks at the waterline under the jetty root
        y = r.uniform(860, 935)
        x = r.uniform(440, 470 + (y - 860) * 0.9)
        rx = r.uniform(12, 22)
        cv.ell(x, y, rx, rx * 0.55, fill=rock_d, ink=INK, w=1.8)
    cv.stroke([(452, 870), (470, 872), (500, 871)], 1.6, mix(SEAGLASS, PAPER, 0.4), alpha=200)


def paint_shed(cv, r):
    plank_a = (124, 114, 100)
    plank_b = (116, 106, 93)
    cv.rect(40, 560, 430, 922, fill=plank_a, ink=None)
    x = 40
    k = 0
    while x < 430:
        wdt = min(430 - x, 26 + r.uniform(-3, 4))
        tone = plank_a if k % 2 == 0 else plank_b
        tone = mix(tone, (r.choice([PAPER, INK, TIMBER])), r.uniform(0.0, 0.08))
        cv.box(x, 560, x + wdt, 922, tone)
        wood_grain(cv, r, x, 560, x + wdt, 922, tone, lines=5, alpha=0.55)
        weather_board(cv, r, x, 560, x + wdt, 922, tone, top_dark=0.3, foot_dark=0.4, foot=60)
        if x > 40:
            cv.stroke([(x, 566), (x + r.uniform(-0.5, 0.5), 920)], 1.6, INK, alpha=200, jitter=0.06)
            cv.box(x + 1, 566, x + 3, 920, mix(tone, INK, 0.35), alpha=140)   # the gap's shadow
        for ny in (578, 900):
            nx = x + wdt / 2 + r.uniform(-3, 3)
            cv.ell(nx, ny + r.uniform(-3, 3), 1.6, 1.6, fill=SOOT, ink=None)
            cv.box(nx - 0.8, ny + 2, nx + 0.8, ny + r.uniform(8, 22), (104, 72, 52), alpha=90)  # rust bleed
        x += wdt
        k += 1
    # painted light: the eaves throw a deep shade, the wall darkens toward the wet ground
    tint(cv, grad_mask(40, 566, 430, 640, 0.55, 0.0, ease=0.7), INK)
    tint(cv, grad_mask(40, 840, 430, 922, 0.0, 0.3), mix(INK, (62, 74, 60), 0.4))
    cv.rect(40, 560, 430, 922, fill=None, ink=INK, w=2.8)
    cv.rect(34, 912, 436, 922, fill=mix(TIMBER, SOOT, 0.3), ink=INK, w=2.0)  # sill
    # roof band and fascia
    cv.poly([(30, 560), (46, 520), (424, 520), (440, 560)], STORM, INK, 2.8)
    for y in (530, 540, 550):
        cv.stroke([(46 - (y - 520) * 0.4 + 6, y), (424 + (y - 520) * 0.4 - 6, y)], 1.0,
                  mix(STORM, SEAGLASS, 0.3), alpha=200, jitter=0.05)
    cv.rect(30, 558, 440, 566, fill=mix(TIMBER, PAPER, 0.25), ink=INK, w=2.0)
    # outer door x120-250, y660-922
    cv.rect(110, 650, 260, 922, fill=mix(TIMBER, PAPER, 0.18), ink=INK, w=2.4)
    cv.rect(120, 660, 250, 922, fill=GREEN, ink=INK, w=2.4)
    for bx in (152, 185, 218):
        cv.stroke([(bx, 664), (bx, 918)], 1.4, mix(GREEN, INK, 0.45), alpha=230)
    dg = mix(GREEN, SEAGLASS, 0.18)
    for ly in (690, 880):
        cv.rect(126, ly, 244, ly + 14, fill=dg, ink=INK, w=1.8)
    cv.poly([(130, 880), (148, 880), (240, 704), (222, 704)], dg, INK, 1.8)
    cv.rect(226, 772, 238, 812, fill=BRASS, ink=INK, w=1.6)
    cv.ell(232, 792, 6, 6, fill=mix(BRASS, PAPER, 0.25), ink=INK, w=1.6)
    cv.ell(232, 802, 1.6, 2.2, fill=INK, ink=None)
    for hy in (690, 880):  # strap hinges on the left
        cv.rect(120, hy + 2, 150, hy + 10, fill=SOOT, ink=INK, w=1.2)
    # lifebuoy and rope coil left of the door
    cv.ell(78, 640, 28, 28, fill=PAPER, ink=INK, w=2.4)
    for a0 in (0, 90, 180, 270):
        pts = [(78, 640)] + [(78 + 29 * math.cos(math.radians(a)), 640 + 29 * math.sin(math.radians(a)))
                             for a in range(a0 + 20, a0 + 71, 5)]
        cv.fillpoly(pts, STORM)
    cv.ell(78, 640, 14, 14, fill=plank_b, ink=INK, w=2.2)
    cv.ell(78, 640, 28, 28, fill=None, ink=INK, w=2.4)
    cv.rect(74, 606, 82, 614, fill=SOOT, ink=INK, w=1.2)
    rope = mix(TIMBER, PAPER, 0.4)
    for k in range(4):  # a hanging coil: four loops off one peg
        loop = smooth([(70 + k * 4, 744), (58 + k * 3, 780), (66 + k * 4, 812), (82 + k * 3, 818),
                       (96 + k * 2, 800), (92 + k * 2, 764), (86 + k * 2, 744)], 5)
        cv.stroke(loop, 6.0, INK, jitter=0.03)
        cv.stroke(loop, 3.4, rope, jitter=0.03)
    cv.rect(66, 740, 96, 750, fill=mix(TIMBER, SOOT, 0.3), ink=INK, w=1.6)
    cv.rect(76, 734, 84, 742, fill=SOOT, ink=INK, w=1.2)
    # crate under the panel
    cv.rect(300, 858, 392, 912, fill=mix(TIMBER, PAPER, 0.15), ink=INK, w=2.2)
    cv.stroke([(300, 885), (392, 885)], 1.6)
    cv.stroke([(304, 862), (388, 908)], 1.4, INK, alpha=200)
    paint_panel_box(cv)


def paint_panel_box(cv):
    cv.rect(290, 590, 410, 760, fill=BRASS, ink=INK, w=2.6)
    for (x, y) in ((295, 595), (405, 595), (295, 755), (405, 755)):
        cv.ell(x, y, 1.8, 1.8, fill=INK, ink=None)
    cv.rect(299, 599, 401, 751, fill=STORM, ink=INK, w=1.8)
    cv.rect(305, 605, 395, 614, fill=PAPER, ink=INK, w=1.2)
    # two tally plates
    cv.rect(306, 620, 346, 652, fill=PAPER, ink=INK, w=1.4)
    cv.rect(354, 620, 394, 652, fill=PAPER, ink=INK, w=1.4)
    cv.rect(316, 629, 336, 640, fill=STORM, ink=None)
    for ox in (320, 329):
        cv.box(ox, 629, ox + 3, 640, PAPER)
    for k in range(5):
        cv.stroke([(364 + k * 4, 629), (366 + k * 4, 629)], 1.0)
        cv.stroke([(364 + k * 4, 640), (366 + k * 4, 640)], 1.0)
    cv.stroke([(364, 629), (364, 640)], 1.0)
    # placard
    cv.rect(306, 660, 394, 694, fill=PAPER, ink=INK, w=1.4)
    for cx in (318, 382):
        cv.rect(cx - 4, 657, cx + 4, 663, fill=BRASS, ink=INK, w=1.0)
    # four bell pulls
    for i in range(4):
        cx = 312 + 25 * i
        cv.ell(cx, 708, 4.5, 4.5, fill=PAPER, ink=INK, w=1.2)
        cv.stroke([(cx, 713), (cx, 726)], 1.4, mix(SEAGLASS, PAPER, 0.4))
        cv.rect(cx - 8, 726, cx + 8, 732, fill=BRASS, ink=INK, w=1.2)


PILE = (112, 100, 85)


def paint_jetty(cv, r):
    deck = (138, 124, 104)
    deck_top = mix(deck, PAPER, 0.35)
    post = (118, 106, 90)
    end = JETTY_END
    # pilings (above water) and their submerged parts
    sub = cv.layer()
    for cx in PILINGS:
        x0, x1 = cx - 13, cx + 13
        cv.rect(x0, 780, x1, 870, fill=PILE, ink=None)
        wood_grain(cv, r, x0, 780, x1, 870, PILE, lines=4, alpha=0.6)
        weather_board(cv, r, x0, 780, x1, 870, PILE, top_dark=0.35, foot_dark=0.45, foot=34)
        cv.box(x1 - 6, 780, x1, 870, mix(PILE, INK, 0.3), alpha=170)
        # growth band at the waterline (the capsule later has none)
        gb = [(x0, 870), (x0, 852)]
        x = x0
        while x < x1:
            gb.append((x + 2, 846 + r.uniform(-3, 3)))
            x += 5
        gb += [(x1, 850), (x1, 870)]
        cv.fillpoly(gb, (62, 74, 60))
        for k in range(3):
            cv.ell(x0 + 5 + k * 8, 858 + r.uniform(-3, 3), 2.2, 1.6, fill=mix(PAPER, SEAGLASS, 0.3), ink=None)
        cv.rect(x0, 780, x1, 870, fill=None, ink=INK, w=2.4)
        # submerged: tinted toward the sea, fading out by y940 (not in the bell's calm: the
        # mirror there shows their still reflections instead)
        if cx not in (680, 785):
            sub.box(x0 + 1, 870, x1 - 1, 940, mix(PILE, (78, 106, 102), 0.55))
    m = Image.new("L", (W * S, H * S), 0)
    md = ImageDraw.Draw(m)
    for row in range(870 * S, 940 * S):
        md.line([(0, row), (W * S, row)], fill=int(150 * (1 - (row / S - 870) / 70) ** 1.3))
    cv.comp(sub, mask=m)
    # deck front band: three weathered boards end to end, grain running along them
    cv.rect(430, 752, end, 780, fill=deck, ink=None)
    joints = [430]
    x = 430
    while True:
        x += r.uniform(160, 260)
        if x >= end - 40:
            break
        joints.append(x)
    joints.append(end)
    for a, b in zip(joints, joints[1:]):
        wood_grain(cv, r, a, 757, b, 780, deck, vertical=False, lines=3, alpha=0.6)
        weather_board(cv, r, a, 752, b, 780, deck, vertical=False, foot_dark=0.35)
        if a > 430:
            cv.stroke([(a, 758), (a, 779)], 1.4, INK, alpha=200)
    cv.box(430, 752, end, 757, deck_top)
    for cx in PILINGS:
        cv.ell(cx, 768, 2.4, 2.4, fill=SOOT, ink=None)
        cv.ell(cx + 0.6, 772, 1.2, 4, fill=mix(deck, (96, 64, 44), 0.6), ink=None, alpha=150)  # rust run
    cv.rect(430, 752, end, 780, fill=None, ink=INK, w=2.6)
    cv.stroke([(432, 757), (end - 2, 757)], 1.2, INK, alpha=150)
    # shadow of the deck on the pilings' heads
    tint(cv, grad_mask(430, 780, end, 800, 0.45, 0.0), INK)
    # handrail and stanchions
    stanch = [434] + PILINGS + [end - 4]
    for sx in stanch:
        cv.rect(sx - 3, 702, sx + 3, 752, fill=post, ink=INK, w=1.8)
        cv.box(sx - 3, 702, sx - 1, 752, mix(post, PAPER, 0.25))
    cv.rect(430, 697, end, 703, fill=mix(post, PAPER, 0.25), ink=INK, w=1.8)
    cv.box(431, 701, end - 1, 703, mix(post, INK, 0.25))
    # the lamp-post at the jetty's root (the office window shows one): a plain iron
    # standard, a swan-neck arm reaching back toward the shore, an unlit lantern
    iron = mix(SOOT, STORM, 0.5)
    lpx = 548
    cv.rect(lpx - 4, 560, lpx + 4, 752, fill=iron, ink=INK, w=2.2)
    cv.box(lpx - 3, 562, lpx - 1, 750, mix(iron, SEAGLASS, 0.35))
    cv.rect(lpx - 8, 736, lpx + 8, 752, fill=iron, ink=INK, w=1.8)
    cv.rect(lpx - 6, 552, lpx + 6, 562, fill=iron, ink=INK, w=1.6)
    arm = smooth([(lpx, 566), (lpx - 10, 548), (lpx - 30, 546), (lpx - 40, 556)], 6)
    cv.stroke(arm, 5.0, INK, jitter=0.02)
    cv.stroke(arm, 2.6, iron, jitter=0.02)
    lx = lpx - 40
    cv.stroke([(lx, 556), (lx, 562)], 1.6)
    cv.poly([(lx - 9, 562), (lx + 9, 562), (lx + 6, 568), (lx - 6, 568)], iron, INK, 1.6)
    cv.poly([(lx - 6, 568), (lx + 6, 568), (lx + 7, 586), (lx - 7, 586)], mix(STORM, SEAGLASS, 0.45), INK, 1.6)
    cv.stroke([(lx, 569), (lx, 585)], 1.0, INK, alpha=180)
    cv.rect(lx - 8, 586, lx + 8, 590, fill=iron, ink=INK, w=1.4)
    # bell post, arm, brace
    cv.rect(633, 600, 647, 752, fill=post, ink=None)
    wood_grain(cv, r, 633, 600, 647, 752, post, lines=3, knots=False, alpha=0.6)
    weather_board(cv, r, 633, 600, 647, 752, post)
    cv.rect(633, 600, 647, 752, fill=None, ink=INK, w=2.2)
    cv.rect(630, 594, 650, 600, fill=SOOT, ink=INK, w=1.6)
    cv.rect(640, 596, 706, 606, fill=post, ink=INK, w=2.0)
    cv.poly([(647, 646), (647, 638), (684, 606), (694, 606)], post, INK, 1.8)
    cv.rect(626, 744, 654, 752, fill=SOOT, ink=INK, w=1.6)  # post foot plate
    cv.ell(700, 610, 3.5, 3.5, fill=SOOT, ink=INK, w=1.2)
    # chain y610..798
    y = 612
    k = 0
    while y < 796:
        if k % 2 == 0:
            cv.ell(700, y + 5, 3.2, 5.2, fill=None, ink=mix(INK, BRASS, 0.2), w=1.8)
        else:
            cv.stroke([(700, y), (700, y + 10)], 2.0, mix(INK, BRASS, 0.2))
        y += 8
        k += 1
    paint_bell(cv)
    # the mooring cleat
    c = CLEAT_X
    cv.poly([(c - 14, 746), (c - 10, 742), (c + 10, 742), (c + 14, 746), (c + 14, 748), (c - 14, 748)],
            mix(SOOT, STORM, 0.4), INK, 1.8)
    cv.rect(c - 6, 747, c + 6, 752, fill=mix(SOOT, STORM, 0.4), ink=INK, w=1.6)
    cv.stroke([(c - 10, 742.6), (c + 10, 742.6)], 1.2, mix(SEAGLASS, PAPER, 0.4))


def paint_bell(cv):
    cx = 700
    cv.rect(692, 798, 708, 808, fill=mix(BRASS, INK, 0.25), ink=INK, w=1.8)
    right = [(cx + w, y) for y, w in BELL_PROF]
    left = [(cx - w, y) for y, w in reversed(BELL_PROF)]
    body = smooth(right, 4) + smooth(left, 4)
    cv.fillpoly(body, BRASS)
    bm = poly_mask(body)
    # value modelling: lit from the left, the far side turning away into shade
    tint(cv, mul_masks(bm, grad_mask(668, 800, 733, 875, 0.0, 0.55, axis="x", ease=1.6)), mix(BRASS, INK, 0.6))
    tint(cv, mul_masks(bm, grad_mask(668, 800, 700, 875, 0.5, 0.0, axis="x")), mix(BRASS, PAPER, 0.55))
    tint(cv, mul_masks(bm, grad_mask(668, 806, 733, 830, 0.35, 0.0)), mix(BRASS, PAPER, 0.4))
    # patina streaks
    lay = cv.layer()
    for (x, w) in ((682, 4), (694, 3), (716, 5)):
        lay.fillpoly([(x, 812), (x + w, 812), (x + w + 2, 866), (x - 1, 866)], COPPER)
    cv.comp(lay, 0.55)
    cv.fillpoly([(684, 816), (689, 812), (686, 860), (680, 864)], mix(BRASS, PAPER, 0.5))
    cv.rect(668, 864, 732, 872, fill=mix(BRASS, INK, 0.2), ink=None)
    cv.stroke(body, 2.6, INK, closed=True)
    cv.stroke([(669, 864), (731, 864)], 1.6, INK)
    # the lip sits exactly on the water: a hard dead-level line, no ripple, no halo
    cv.stroke([(667, 872.5), (733, 872.5)], 1.6, INK, jitter=0.0)


def fg_jetty():
    name = "fg_jetty"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    cv.wk = 1.1
    paint_station(cv, r)
    window_bars(cv, 110, 340)
    window_bars(cv, 190, 340)
    window_bars(cv, 70, 446, 40, 44)
    cv.wk = 1.35
    paint_land(cv, r)
    cv.wk = 1.5     # the shed is the nearest thing: the heaviest contours in the room
    paint_shed(cv, r)
    cv.wk = 1.35
    paint_jetty(cv, r)
    cv.wk = 1.0
    return cv.finish(name, "RGBA", r)


# =================================================================== overlays part 1
def paint_rope(cv, x, y0, y1, w=7.0, col=None):
    """A laid rope hanging straight: dark core edges, a lit left flank, a twist every 9 px."""
    col = col or mix(TIMBER, PAPER, 0.3)
    cv.box(x - w / 2, y0, x + w / 2, y1, col)
    cv.box(x - w / 2 + 1, y0, x - w / 2 + 2.4, y1, mix(col, PAPER, 0.45))
    cv.box(x + w / 2 - 2, y0, x + w / 2, y1, mix(col, INK, 0.35))
    y = y0 + 2
    while y < y1 - 3:
        cv.stroke([(x - w / 2 + 0.6, y), (x + w / 2 - 0.6, y + 4.6)], 1.3, mix(col, INK, 0.6), jitter=0.02)
        y += 9
    cv.stroke([(x - w / 2, y0), (x - w / 2, y1)], 1.6, INK, jitter=0.02)
    cv.stroke([(x + w / 2, y0), (x + w / 2, y1)], 1.6, INK, jitter=0.02)


def ov_line():
    name = "line"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    x = CLEAT_X
    paint_rope(cv, x, 748, 870)
    # the turns on the cleat
    rope = mix(TIMBER, PAPER, 0.3)
    for k, dx in enumerate((-9, 0, 9)):
        cv.ell(x + dx, 745, 6, 3.4, fill=rope, ink=INK, w=1.4)
    sub = cv.layer()
    paint_rope(sub, x, 870, 1000, col=mix(mix(TIMBER, PAPER, 0.3), SEAGLASS, 0.5))
    m = Image.new("L", (W * S, H * S), 0)
    md = ImageDraw.Draw(m)
    for row in range(870 * S, 1000 * S):
        md.line([(0, row), (W * S, row)], fill=int(190 * (1 - (row / S - 870) / 130) ** 1.2))
    cv.comp(sub, mask=m)
    return cv.finish(name, "RGBA", r)


def ov_gangway_up():
    name = "gangway_up"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    plank = (146, 132, 110)
    cv.rect(770, 600, 800, 752, fill=plank, ink=INK, w=2.4)
    cv.box(771, 601, 776, 751, mix(plank, PAPER, 0.3))
    for y in range(614, 748, 16):
        cv.rect(772, y, 798, y + 4, fill=mix(plank, INK, 0.25), ink=None)
    cv.ell(785, 748, 5, 5, fill=SOOT, ink=INK, w=1.6)
    cv.stroke([(800, 606), (812, 640), (806, 698)], 2.0, mix(TIMBER, PAPER, 0.3))  # lashing to the rail
    return cv.finish(name, "RGBA", r)


def ov_gangway_down():
    name = "gangway_down"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    plank = (146, 132, 110)
    top = [(790, 756), (880, 786)]
    pts = [top[0], top[1], (880, 798), (790, 768)]
    cv.poly(pts, plank, INK, 2.4)
    for k in range(1, 6):
        x = 790 + k * 15
        y = 756 + (x - 790) / 3
        cv.stroke([(x, y + 1), (x, y + 11)], 1.4, mix(plank, INK, 0.5))
    cv.ell(792, 760, 3.5, 3.5, fill=SOOT, ink=INK, w=1.2)
    # rope rail: two stanchions and a sagging rope
    for (x, y) in ((796, 758), (874, 784)):
        cv.rect(x - 2, y - 34, x + 2, y, fill=mix(TIMBER, SOOT, 0.2), ink=INK, w=1.4)
    rope = smooth([(796, 726), (835, 752), (874, 752)], 6)
    cv.stroke(rope, 2.4, mix(TIMBER, PAPER, 0.3), jitter=0.05)
    cv.stroke([(x, y + 1.8) for x, y in rope], 1.0, INK, alpha=200, jitter=0.05)
    return cv.finish(name, "RGBA", r)


def ov_reflections():
    name = "reflections"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    ink_l = cv.layer()
    pap_l = cv.layer()
    for cx in PILINGS:
        if cx in (680, 785):
            continue   # they stand in the bell's calm: their reflections are the still ones
        y = 872
        k = 0
        while y < 930:
            t = (y - 870) / 60
            half = 13 + r.uniform(-2, 5) * (1 - t * 0.4)
            off = 5 * math.sin(k * 1.7 + cx * 0.01) + r.uniform(-2, 2)
            wid = 2.4 - t
            ink_l.stroke([(cx - half + off, y), (cx + half * 0.3 + off, y + 0.8), (cx + half + off, y)],
                         max(1.0, wid + 0.6), INK, jitter=0.1)
            pap_l.stroke([(cx - half * 0.6 - off * 0.5, y + 4), (cx + half * 0.4 - off * 0.5, y + 4.6)],
                         max(1.0, wid), PAPER, jitter=0.1)
            y += 8 + t * 4
            k += 1
    cut_calm(ink_l, 0.5)
    cut_calm(pap_l, 0.5)
    cv.comp(ink_l, 0.55)
    cv.comp(pap_l, 0.4)
    return cv.finish(name, "RGBA", r)


def ov_bell_calm():
    """The calm's hard rim, laid over the wave frames so the dashes stop dead at it. The
    mirror itself (flat glass, the still upside-down bell) is painted into each band's
    backdrop in that band's own tones. No halo: the wrongness is the edge."""
    name = "bell_calm"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    cx, cy, rx, ry = CALM
    top = [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a))) for a in range(180, 361, 3)]
    bot = [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a))) for a in range(0, 181, 3)]
    cv.stroke(top, 1.6, mix(SEAGLASS, PAPER, 0.6), alpha=200, jitter=0.0)
    cv.stroke(bot, 1.4, INK, alpha=150, jitter=0.0)
    return cv.finish(name, "RGBA", r)


def wave_frame(k, prefix="waves", col=PAPER, opacity=0.5, hull_gap=True):
    name = f"{prefix}_{k}"
    r = random.Random(seed_of(f"{name}.png"))
    lay_r = random.Random(seed_of("R01:waves"))
    cv = Cv(r)
    lay = cv.layer()
    for i in range(460):
        y = 482 + (lay_r.random() ** 1.25) * 505
        x = lay_r.uniform(-30, W)
        t = (y - 480) / 514
        ln = 10 + t * 64 * lay_r.uniform(0.6, 1.3)
        ph = lay_r.uniform(0, 2 * math.pi)
        amp = 4 + t * 12
        ox = amp * math.sin(ph + k * 2 * math.pi / 3)
        oy = (1 + t * 3) * math.cos(ph + k * 2 * math.pi / 3)
        x += ox
        y += oy
        if y > 994 or y < 480:
            continue
        x0, x1 = x, x + ln
        if y > 500 and x0 < 470:
            continue
        # keep the hull's waterline clean (the bell's calm is cut out below, exactly)
        if hull_gap and x1 > 856 and x0 < 1294 and 856 < y < 884:
            continue
        sag = 0.6 + t * 2.2
        pts = smooth([(x0, y + sag * 0.3), (x0 + ln * 0.3, y - sag), (x0 + ln * 0.7, y - sag * 0.7),
                      (x1, y + sag * 0.2)], 4)
        lay.stroke(pts, 1.0 + t * 1.8, col, jitter=0.06)
    cut_calm(lay, 0.5)
    cv.comp(lay, opacity)
    return cv.finish(name, "RGBA", r)


# =================================================================== overlays part 2: boats
STRIPES_FALSE = (16, 44, 72)
STRIPES_REAL = (26, 62)


def paint_pennant(cv, x0, y0, stripes, scale=1.0, dashed=False, mast=False):
    w, h, n = 100 * scale, 56 * scale, 14 * scale
    pts = [(x0, y0), (x0 + w, y0), (x0 + w - n, y0 + h / 2), (x0 + w, y0 + h), (x0, y0 + h)]
    if dashed:
        seq = pts + [pts[0]]
        for a, b in zip(seq, seq[1:]):
            L = math.dist(a, b)
            nseg = max(1, int(L / (10 * scale)))
            for j in range(0, nseg, 2):
                t0, t1 = j / nseg, min(1.0, (j + 1) / nseg)
                cv.stroke([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0),
                           (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)], 2.4 * max(1, scale * 0.8), INK)
        return
    cv.fillpoly(pts, STORM)
    for off in stripes:
        cv.box(x0 + off * scale, y0, x0 + (off + 12) * scale, y0 + h, PAPER)
    cv.stroke(pts, 2.0 * max(1.0, scale * 0.8), INK, closed=True)


def paint_launch(cv, real: bool):
    hull = PAPER if real else (38, 50, 60)
    strake = STORM if real else PAPER
    cabin = mix(PAPER, SEAGLASS, 0.12) if real else (52, 66, 76)
    trim = COPPER
    # hull: raked bow at the left, square stern at the right
    hp = [(860, 780), (1290, 780), (1290, 870), (912, 870)]
    bow = smooth([(860, 780), (878, 820), (895, 850), (912, 870)], 5)
    hull_pts = [(1290, 780), (1290, 870)] + list(reversed(bow))
    cv.wk = 1.3
    cv.fillpoly(hull_pts, hull)
    hm = poly_mask(hull_pts)
    # slight value modelling: the hull's flare catches light under the sheer, rounds into shade
    tint(cv, mul_masks(hm, grad_mask(860, 792, 1290, 870, 0.0, 0.5, ease=1.3)), mix(hull, INK, 0.6))
    tint(cv, mul_masks(hm, grad_mask(860, 792, 1290, 812, 0.4, 0.0)), mix(hull, PAPER, 0.4))
    tint(cv, mul_masks(hm, grad_mask(860, 780, 1000, 870, 0.3, 0.0, axis="x")), mix(hull, PAPER, 0.3))
    if real:
        cv.box(880, 862, 1290, 870, mix(TIMBER, SOOT, 0.4))  # boot top
    cv.fillpoly([(864, 784), (1290, 784), (1290, 792), (868, 792)], strake)  # sheer strake
    for y in (808, 828, 848):
        cv.stroke([(870 + (y - 780) * 0.5, y), (1288, y)], 1.2, mix(hull, INK, 0.45), alpha=200, jitter=0.04)
    cv.rect(858, 776, 1294, 781, fill=mix(TIMBER, PAPER, 0.2), ink=INK, w=1.8)  # gunwale rail
    cv.stroke(hull_pts, 2.6, INK, closed=True)
    if not real:
        # where it meets the water: one ruled navy edge, no wobble, nothing round it
        cv.box(908, 868, 1291, 870, INK)
    cv.stroke([(864, 784), (1290, 784)], 1.4, INK)
    cv.stroke([(868, 792), (1290, 792)], 1.4, INK)
    # cabin x960-1120 y680-780
    cv.rect(960, 686, 1120, 776, fill=cabin, ink=INK, w=2.4)
    tint(cv, grad_mask(962, 688, 1118, 702, 0.45, 0.0), INK)   # under the roof overhang
    tint(cv, grad_mask(1080, 688, 1118, 774, 0.0, 0.3, axis="x"), INK)
    cv.rect(952, 678, 1128, 688, fill=mix(trim, PAPER, 0.15), ink=INK, w=2.2)  # roof overhang
    cv.rect(1006, 672, 1026, 678, fill=SOOT, ink=INK, w=1.4)  # roof vent
    cv.rect(986, 696, 1094, 760, fill=BRASS, ink=INK, w=2.0)  # window frame
    glass = mix(STORM, INK, 0.4)
    cv.rect(990, 700, 1090, 756, fill=glass, ink=INK, w=1.6)
    if not real:
        cv.stroke([(996, 750), (1030, 704)], 2.2, mix(glass, SEAGLASS, 0.35), alpha=140)
    cv.rect(1100, 714, 1114, 772, fill=mix(cabin, INK, 0.25), ink=INK, w=1.6)  # cabin door
    # mast x1180, y520-780, with halyard and a masthead cap
    cv.rect(1177, 520, 1183, 780, fill=mix(TIMBER, PAPER, 0.25), ink=INK, w=1.8)
    cv.rect(1174, 514, 1186, 520, fill=SOOT, ink=INK, w=1.4)
    cv.stroke([(1183, 584), (1196, 700), (1200, 776)], 1.2, INK, alpha=200)
    # stern bitts
    cv.rect(1262, 766, 1272, 776, fill=SOOT, ink=INK, w=1.4)
    cv.wk = 1.0
    paint_pennant(cv, 1182, 524, STRIPES_REAL if real else STRIPES_FALSE)


def ov_boat():
    name = "boat"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    paint_launch(cv, real=False)
    return cv.finish(name, "RGBA", r)


def chart_table_tiny(cv, interior):
    cv.rect(990, 700, 1090, 756, fill=interior, ink=None)
    cv.rect(996, 736, 1084, 740, fill=mix(TIMBER, INK, 0.3), ink=None)       # table top line
    cv.box(1000, 740, 1004, 756, mix(TIMBER, INK, 0.45))
    cv.box(1076, 740, 1080, 756, mix(TIMBER, INK, 0.45))
    cv.rect(1012, 728, 1060, 737, fill=PAPER, ink=INK, w=1.2)               # pale chart
    cv.stroke([(1014, 733), (1024, 730), (1034, 734), (1046, 730), (1058, 733)], 1.0, INK, alpha=200)


def ov_boat_window_lit():
    name = "boat_window_lit"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    glow(cv, lambda d: d.rectangle([984 * S, 694 * S, 1096 * S, 762 * S], fill=255), AMBER, 8, 0.45)
    chart_table_tiny(cv, AMBER)
    cv.stroke([(1068, 700), (1068, 708)], 1.2, INK)
    cv.poly([(1062, 708), (1074, 708), (1071, 714), (1065, 714)], mix(AMBER, PAPER, 0.6), INK, 1.2)
    cv.rect(990, 700, 1090, 756, fill=None, ink=INK, w=1.6)
    return cv.finish(name, "RGBA", r)


def tiny_figure(cv, turned):
    body = (24, 30, 36)
    # head and shoulders filling ~40% of the 56 px window, at the chart table
    cv.poly(smooth([(1022, 756), (1024, 738), (1030, 731), (1040, 729), (1050, 731),
                    (1056, 738), (1058, 756)], 4), body, None)
    cv.ell(1035, 719, 3.2, 3.2, fill=body, ink=None)   # her pinned hair
    cv.ell(1040, 724, 6.5, 8, fill=mix(STORM, body, 0.35) if turned else body, ink=None)
    if turned:
        for ex in (1038, 1042.2):
            cv.ell(ex, 723, 0.9, 0.7, fill=mix(AMBER, PAPER, 0.35), ink=None)
    cv.box(1037, 730, 1043, 733, body)


def ov_figure_window(turned):
    name = "figure_window_turned" if turned else "figure_window"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    tiny_figure(cv, turned)
    return cv.finish(name, "RGBA", r)


def ov_launch_real():
    name = "launch_real"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    paint_launch(cv, real=True)
    # its own cabin, daylit and empty: a bench and a hanging lamp, nobody
    cv.rect(990, 700, 1090, 756, fill=mix(PAPER, SEAGLASS, 0.35), ink=None)
    cv.rect(990, 700, 1090, 708, fill=mix(PAPER, SEAGLASS, 0.55), ink=None)
    cv.rect(998, 738, 1082, 744, fill=mix(TIMBER, PAPER, 0.15), ink=INK, w=1.2)  # bench seat
    cv.rect(998, 744, 1082, 756, fill=mix(TIMBER, INK, 0.15), ink=None)
    cv.stroke([(1040, 700), (1040, 712)], 1.0, INK)
    cv.poly([(1035, 712), (1045, 712), (1043, 718), (1037, 718)], mix(BRASS, PAPER, 0.3), INK, 1.0)
    cv.stroke([(1060, 703), (1086, 738)], 2.0, PAPER, alpha=150)
    cv.rect(990, 700, 1090, 756, fill=None, ink=INK, w=1.6)
    return cv.finish(name, "RGBA", r)


def ov_launch_departing():
    name = "launch_departing"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    c = mix(INK, STORM, 0.3)
    cv.fillpoly([(1300, 464), (1352, 464), (1352, 470), (1304, 470)], c)
    cv.fillpoly([(1314, 459), (1332, 459), (1332, 464), (1314, 464)], c)
    cv.box(1341, 452, 1342.6, 464, c)
    cv.fillpoly([(1342.6, 452.4), (1352, 452.4), (1350, 454.6), (1352, 457), (1342.6, 457)], c)
    cv.box(1300, 464.6, 1352, 465.6, mix(PAPER, SEAGLASS, 0.3))
    return cv.finish(name, "RGBA", r)


# =================================================================== overlays part 3
def ov_station_lamp():
    name = "station_lamp"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    glow(cv, lambda d: d.rectangle([104 * S, 334 * S, 176 * S, 406 * S], fill=255), AMBER, 4, 0.7)
    cv.rect(110, 340, 170, 400, fill=AMBER, ink=None)
    cv.box(116, 346, 164, 394, mix(AMBER, PAPER, 0.3))
    window_bars(cv, 110, 340)
    cv.rect(110, 340, 170, 400, fill=None, ink=INK, w=1.8)
    return cv.finish(name, "RGBA", r)


def ov_station_window_figure():
    """s7: someone seated at the office desk, facing out at us. A stark head-and-shoulders
    silhouette, the head well clear of the sill, against glass a step brighter than the lamp."""
    name = "station_window_figure"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    glow(cv, lambda d: d.rectangle([100 * S, 330 * S, 180 * S, 410 * S], fill=255), AMBER, 6, 0.6)
    cv.rect(110, 340, 170, 400, fill=mix(AMBER, PAPER, 0.3), ink=None)
    cv.box(114, 344, 166, 396, mix(AMBER, PAPER, 0.5))
    body = (24, 30, 36)
    # shoulders square to the glass, filling the lower third
    cv.fillpoly(smooth([(117, 400), (119, 386), (126, 378), (136, 375), (144, 375), (154, 378),
                        (161, 386), (163, 400)], 4), body)
    cv.box(136, 368, 144, 378, body)                      # neck
    cv.ell(140, 360, 9.5, 11.5, fill=body, ink=None)       # head, facing out
    cv.ell(131, 355, 4.5, 4.5, fill=body, ink=None)        # pinned hair, as hers
    window_bars(cv, 110, 340)
    cv.rect(110, 340, 170, 400, fill=None, ink=INK, w=1.8)
    return cv.finish(name, "RGBA", r)


def ov_lighthouse_roof():
    name = "lighthouse_roof"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    glow(cv, lambda d: d.ellipse([158 * S, 166 * S, 182 * S, 200 * S], fill=255), AMBER, 30, 0.8)
    cv.poly([(156, 252), (158.5, 196), (181.5, 196), (184, 252)], PAPER, INK, 2.2)
    cv.fillpoly([(157.4, 222), (182.6, 222), (183, 232), (157, 232)], STORM)
    cv.stroke([(157.4, 222), (182.6, 222)], 1.4)
    cv.stroke([(157, 232), (183, 232)], 1.4)
    cv.rect(150, 194, 190, 199, fill=STORM, ink=INK, w=1.6)
    cv.rect(153, 172, 187, 195, fill=AMBER, ink=INK, w=2.0)
    cv.box(162, 176, 178, 191, mix(AMBER, PAPER, 0.55))
    for mx in (162, 170, 178):
        cv.stroke([(mx, 173), (mx, 194)], 1.2, INK, alpha=220)
    cv.poly([(151, 172), (170, 160), (189, 172)], STORM, INK, 2.0)
    cv.stroke([(170, 160), (170, 154)], 1.4)
    # its base is hidden behind the roof ridge: clip everything at y 249
    clip = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(clip).rectangle([0, 0, W * S, 249 * S - 1], fill=255)
    cv.im.putalpha(ImageChops.multiply(cv.im.getchannel("A"), clip))
    return cv.finish(name, "RGBA", r)


def ov_stump():
    name = "stump"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    cv.wk = 1.35
    x0, x1 = STUMP_X, STUMP_X + 26
    cv.rect(x0, 838, x1, 870, fill=PILE, ink=None)
    wood_grain(cv, r, x0, 838, x1, 870, PILE, lines=3, knots=False, alpha=0.6)
    cv.box(x0, 838, x0 + 5, 870, mix(PILE, PAPER, 0.28))
    cv.box(x1 - 6, 838, x1, 870, mix(PILE, INK, 0.3))
    cv.fillpoly([(x0, 870), (x0, 856), (x0 + 5, 851), (x0 + 10, 855), (x0 + 15, 850), (x0 + 20, 854),
                 (x1, 852), (x1, 870)], (62, 74, 60))
    cv.rect(x0 - 1, 835, x1 + 1, 841, fill=(226, 206, 160), ink=None)  # fresh-cut top, pale
    cv.stroke([(x0 + 4, 838), (x1 - 4, 838)], 0.9, mix(TIMBER, PAPER, 0.4))
    cv.rect(x0, 836, x1, 870, fill=None, ink=INK, w=2.4)
    lay = cv.layer()
    for k, y in enumerate((874, 884, 896, 908)):
        off = 4 * math.sin(k * 1.9)
        lay.stroke([(x0 + off, y), (x1 + off, y + 0.6)], 2.2 - k * 0.3, INK)
        lay.stroke([(x0 + 4 - off, y + 4), (x1 - 8 - off, y + 4.4)], 1.4, PAPER)
    cv.comp(lay, 0.5)
    return cv.finish(name, "RGBA", r)


def ov_mist_far():
    name = "mist_far"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    col = hexc("#64767C")
    cv.box(1180, 0, W, H, col)
    m = Image.new("L", (W * S, H * S), 0)
    md = ImageDraw.Draw(m)
    streak = [r.uniform(-0.05, 0.05) for _ in range(40)]
    for col_x in range(1180 * S, W * S):
        x = col_x / S
        a = 0.55 * clamp((x - 1180) / 120, 0, 1) ** 1.2
        a = clamp(a + streak[int((x - 1180) / 7) % 40] * min(1, (x - 1180) / 120), 0, 0.6)
        md.line([(col_x, 0), (col_x, H * S)], fill=int(255 * a))
    cv.im.putalpha(ImageChops.multiply(cv.im.getchannel("A"), m))
    return cv.finish(name, "RGBA", r)


HOTSPOT_RECTS = [(280, 580, 420, 770), (110, 650, 260, 930), (620, 590, 740, 880), (850, 500, 1300, 880),
                 (1300, 730, 1380, 1000), (1180, 290, 1240, 440), (420, 470, 1050, 500)]


def ov_rain(name, n, h, alpha):
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    lay = cv.layer()
    for i in range(n):
        x = r.uniform(0, W)
        y = r.uniform(-h, H)
        if any(a <= x <= c and b <= y <= d for a, b, c, d in HOTSPOT_RECTS) and r.random() < 0.6:
            continue
        lay.box(round(x), round(y), round(x) + 3, round(y) + h, PAPER)
    cv.comp(lay, alpha)
    return cv.finish(name, "RGBA", r, grain=False)


def ov_surface_drift():
    """Something moving down inside the surface: a broad sea-glass band with storm-navy edges,
    faint, kept below its top edge so the drift never crosses into the sky."""
    name = "surface_drift"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    x0, x1, y0, y1 = 790, 1010, 236, 868
    lay = cv.layer()
    lay.box(x0, y0, x1, y1, mix(SEAGLASS, STORM, 0.25))
    m = Image.new("L", (W * S, H * S), 0)
    md = ImageDraw.Draw(m)
    for row in range(y0 * S, y1 * S):
        y = row / S
        a = min(1.0, (y - y0) / 80, (y1 - y) / 40)
        md.line([(x0 * S, row), (x1 * S, row)], fill=int(255 * 0.28 * max(0, a)))
    # feathered sides, no edge line: a slow thickening in the water, not a panel
    side = Image.new("L", (W * S, H * S), 0)
    sd = ImageDraw.Draw(side)
    for col_x in range(x0 * S, x1 * S):
        u = (col_x / S - x0) / (x1 - x0)
        sd.line([(col_x, 0), (col_x, H * S)], fill=int(255 * math.sin(math.pi * u) ** 0.8))
    cv.comp(lay, mask=ImageChops.multiply(m, side))
    return cv.finish(name, "RGBA", r)


# =================================================================== overlays part 4
def ov_ada_door():
    name = "ada_door"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    # the doorway, lit from the station side, so her flat silhouette reads hard against it
    cv.rect(120, 660, 250, 922, fill=mix(AMBER, PAPER, 0.45), ink=INK, w=2.4)
    cv.box(122, 900, 248, 920, mix(AMBER, TIMBER, 0.5))
    # the door leaf, swung out toward us on its left hinges: a narrow edge-on strip
    cv.poly([(104, 652), (124, 660), (124, 922), (104, 930)], mix(GREEN, INK, 0.25), INK, 2.2)
    cv.stroke([(114, 700), (114, 890)], 1.2, mix(GREEN, PAPER, 0.25))
    coat = (30, 40, 48)
    # Ada: hatless, buttoned coat, satchel strap, mid-step out of the door
    cv.ell(188, 712, 15, 18, fill=coat, ink=None)
    cv.ell(176, 704, 7, 7, fill=coat, ink=None)  # pinned hair
    cv.box(183, 726, 194, 740, coat)
    torso = smooth([(160, 750), (170, 740), (206, 740), (218, 752), (222, 800), (226, 862),
                    (196, 870), (156, 866), (156, 804)], 4)
    cv.fillpoly(torso, coat)
    cv.fillpoly([(180, 862), (170, 905), (146, 916), (148, 922), (178, 918), (194, 866)], coat)  # forward leg
    cv.fillpoly([(204, 864), (214, 900), (226, 918), (232, 916), (222, 896), (218, 862)], coat)  # trailing leg
    cv.stroke([(214, 744), (172, 838)], 3.0, mix(TIMBER, PAPER, 0.25), jitter=0.04)  # satchel strap
    cv.rect(146, 828, 176, 860, fill=mix(TIMBER, SOOT, 0.2), ink=INK, w=1.8)
    cv.stroke([(147, 836), (175, 836)], 1.2)
    for by in (758, 778, 798, 818):
        cv.ell(192, by, 2.4, 2.4, fill=PAPER, ink=None)
    cv.stroke([(160, 752), (154, 806), (152, 836)], 2.6, coat, jitter=0.02)  # near arm
    cv.stroke([(218, 754), (230, 806), (226, 840)], 6.0, coat, jitter=0.02)  # far arm swing
    cv.stroke(torso, 1.6, mix(SEAGLASS, PAPER, 0.2), closed=True, alpha=160)
    return cv.finish(name, "RGBA", r)


CAP_TOP = 806     # the capsule's shoulder in the room view; its body breaks the waterline
CAP_BOT = 922


def paint_capsule_small(cv, open_):
    """The capsule on the line, 1.6x the first pass and hung low enough to break the water.
    Dull, dry brass: no droplets, a faint tide-line stain, nothing growing on it."""
    x = CLEAT_X
    hw = 19
    paint_rope(cv, x, 748, 784, w=7.0)
    bail = smooth([(x - 17, CAP_TOP + 4), (x - 10, 784), (x, 778), (x + 10, 784), (x + 17, CAP_TOP + 4)], 4)
    cv.stroke(bail, 4.2, INK, jitter=0.02)
    cv.stroke(bail, 2.2, mix(BRASS, INK, 0.25), jitter=0.02)
    body = [(x - hw, CAP_TOP), (x + hw, CAP_TOP), (x + hw, CAP_BOT - 6), (x + hw - 4, CAP_BOT),
            (x - hw + 4, CAP_BOT), (x - hw, CAP_BOT - 6)]
    dull = mix(BRASS, TIMBER, 0.18)
    cv.fillpoly(body, dull)
    bm = poly_mask(body)
    tint(cv, mul_masks(bm, grad_mask(x - hw, CAP_TOP, x + hw, CAP_BOT, 0.0, 0.6, axis="x", ease=1.5)), mix(dull, INK, 0.6))
    tint(cv, mul_masks(bm, grad_mask(x - hw, CAP_TOP, x, CAP_BOT, 0.45, 0.0, axis="x")), mix(dull, PAPER, 0.4))
    # dry tarnish: dull mottles, and the faint stain of a tide line it never had
    for i in range(7):
        tx, ty = x + random.Random(i * 7 + 3).uniform(-hw + 4, hw - 4), CAP_TOP + 10 + i * 12
        cv.ell(tx, ty, 3.4, 2.4, fill=mix(dull, (86, 76, 58), 0.5), ink=None, alpha=110)
    cv.box(x - hw, 846, x + hw, 850, mix(dull, (92, 84, 66), 0.6), alpha=130)
    for yb in (CAP_TOP + 22, CAP_BOT - 24):  # rolled bands
        cv.rect(x - hw - 1.5, yb, x + hw + 1.5, yb + 5, fill=mix(dull, INK, 0.12), ink=INK, w=1.2)
    cv.stroke(body, 2.0, INK, closed=True)
    # below the waterline: the sea over it, one hard level line where it goes in
    sub = cv.layer()
    sub.box(x - hw - 2, 870, x + hw + 2, CAP_BOT + 2, (64, 92, 90))
    sm = mul_masks(poly_mask([(x - hw - 2, 870), (x + hw + 2, 870), (x + hw + 2, CAP_BOT + 2),
                              (x - hw - 2, CAP_BOT + 2)]), grad_mask(0, 870, W, CAP_BOT + 2, 0.45, 0.8))
    cv.comp(sub, mask=sm)
    cv.stroke([(x - hw - 3, 870.5), (x + hw + 3, 870.5)], 1.4, mix(SEAGLASS, PAPER, 0.5), jitter=0.0)
    if open_:
        # the mouth: threaded neck and a dark round opening
        cv.rect(x - hw + 3, CAP_TOP - 6, x + hw - 3, CAP_TOP + 2, fill=mix(dull, INK, 0.15), ink=INK, w=1.2)
        cv.ell(x, CAP_TOP - 6, hw - 3, 3.6, fill=(14, 22, 28), ink=INK, w=1.4)
        # the cap, unscrewed, hanging lower on a short chain off the far side (clear of a
        # moored hull): a round brass cup seen half-face
        links = [(x + hw, CAP_TOP + 6), (x + hw + 3, CAP_TOP + 14), (x + hw + 6, CAP_TOP + 22),
                 (x + hw + 8, CAP_TOP + 30)]
        for (ax, ay), (bx, by) in zip(links, links[1:]):
            cv.ell((ax + bx) / 2, (ay + by) / 2, 2.4, 3.6, fill=None, ink=mix(INK, BRASS, 0.3), w=1.3)
        ccx, ccy = x + hw + 13, CAP_TOP + 44
        cv.ell(ccx, ccy, 11, 13, fill=mix(BRASS, PAPER, 0.08), ink=INK, w=1.8)
        cv.ell(ccx + 1.2, ccy + 1, 7.4, 9.4, fill=mix(BRASS, INK, 0.55), ink=INK, w=1.0)
        for k in range(3):
            cv.stroke(smooth([(ccx - 6, ccy - 4 + k * 4.5), (ccx + 1, ccy - 6 + k * 4.5), (ccx + 7, ccy - 4 + k * 4.5)], 3),
                      0.9, mix(BRASS, PAPER, 0.2), alpha=170)
        cv.stroke(smooth([(ccx - 10, ccy - 5), (ccx - 5, ccy - 11), (ccx + 3, ccy - 13)], 3), 1.4,
                  mix(BRASS, PAPER, 0.55), alpha=200)
    else:
        # the screw cap: a squat knurled drum with its round crown showing
        cv.rect(x - hw - 3, CAP_TOP - 16, x + hw + 3, CAP_TOP + 1, fill=mix(BRASS, PAPER, 0.08), ink=INK, w=1.6)
        for kx in range(int(x - hw), int(x + hw) + 1, 4):
            cv.stroke([(kx, CAP_TOP - 12), (kx, CAP_TOP - 2)], 0.8, INK, alpha=150)
        cv.ell(x, CAP_TOP - 16, hw + 3, 4, fill=mix(BRASS, PAPER, 0.3), ink=INK, w=1.4)


def ov_capsule(open_):
    name = "capsule_open" if open_ else "capsule_closed"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    paint_capsule_small(cv, open_)
    return cv.finish(name, "RGBA", r)


# =================================================================== close-ups
def plank_wall(cv, r, base=(124, 114, 100), alt=(116, 106, 93), w=92):
    """The shed wall behind a close-up: grained boards nailed in pairs to two battens."""
    x = 0
    k = 0
    batten_y = (64 + r.uniform(-4, 4), 1018 + r.uniform(-4, 4))
    while x < W:
        wd = w + r.uniform(-6, 8)
        tone = base if k % 2 == 0 else alt
        cv.box(x, 0, x + wd, H, tone)
        wood_grain(cv, r, x, 0, x + wd, H, tone, lines=9, alpha=0.5)
        weather_board(cv, r, x, 0, x + wd, H, tone, top_dark=0.2, foot_dark=0.25, foot=120)
        cv.stroke([(x, 0), (x + r.uniform(-1, 1), H)], 2.4, INK, alpha=200)
        for by in batten_y:
            nails = [x + wd * r.uniform(0.2, 0.36), x + wd * r.uniform(0.62, 0.8)]
            if r.random() < 0.3:
                nails = nails[:1] if r.random() < 0.5 else nails + [x + wd * r.uniform(0.45, 0.55)]
            for nx in nails:
                ny = by + r.uniform(-14, 14)
                cv.ell(nx, ny, 3.6, 3.6, fill=SOOT, ink=INK, w=1.0)
                tint(cv, grad_mask(nx - 1.6, ny + 3, nx + 1.6, ny + r.uniform(16, 40), 0.35, 0.0), (104, 70, 48))
        x += wd
        k += 1


def foxing(cv, r, x0, y0, x1, y1, n=40):
    """Age on paper: soft brown foxing spots, a few larger pale blooms."""
    m = Image.new("L", (W * S, H * S), 0)
    md = ImageDraw.Draw(m)
    for i in range(n):
        x, y = r.uniform(x0 + 4, x1 - 4), r.uniform(y0 + 4, y1 - 4)
        rr = r.uniform(1.0, 3.2) if r.random() < 0.85 else r.uniform(6, 14)
        md.ellipse([(x - rr) * S, (y - rr * r.uniform(0.7, 1.0)) * S, (x + rr) * S, (y + rr) * S],
                   fill=int(r.uniform(90, 200) if rr < 4 else r.uniform(40, 80)))
    # a damp tide-mark along the lower edge
    md.rectangle([x0 * S, (y1 - 10) * S, x1 * S, y1 * S], fill=50)
    m = m.filter(ImageFilter.GaussianBlur(1.2 * S))
    tint(cv, m, (150, 112, 74), 0.42)


def rust_bleed(cv, r, x, y, ln=None):
    ln = ln or r.uniform(22, 60)
    tint(cv, grad_mask(x - 2.2, y + 2, x + 2.2, y + ln, 0.55, 0.0, ease=0.7), (118, 72, 44))
    tint(cv, grad_mask(x - 4.5, y + 2, x + 4.5, y + ln * 0.4, 0.25, 0.0), (118, 72, 44))


PLATE_V = (324, 240, 360, 250)
PLATE_U = (764, 240, 360, 250)
PULLS = [444, 644, 844, 1044]
PANEL_FACE = (40, 55, 66)


def paint_plate(cv, rect, kind):
    x, y, w, h = rect
    cv.rect(x - 6, y - 6, x + w + 6, y + h + 6, fill=mix(BRASS, INK, 0.1), ink=INK, w=2.4)
    cv.rect(x, y, x + w, y + h, fill=PAPER, ink=INK, w=2.4)
    cv.stroke([(x + 6, y + 6), (x + w - 6, y + 6)], 1.4, mix(PAPER, INK, 0.25))
    cv.ell(x + w / 2, y + 14, 6, 6, fill=SOOT, ink=INK, w=1.6)  # pin hole
    cx, cy = (504, 330) if kind == "v" else (944, 330)
    s = 1.5
    px, py = cx - 50 * s, cy - 28 * s
    cv.rect(px - 8, py - 10, px - 2, py + 56 * s + 20, fill=mix(TIMBER, INK, 0.3), ink=INK, w=1.6)  # pictogram staff
    paint_pennant(cv, px, py, STRIPES_REAL if kind == "v" else (), s, dashed=(kind == "u"))
    cv.rect(x + 20, 420, x + 340, 470, fill=mix(PAPER, INK, 0.08), ink=INK, w=1.8)  # label band
    foxing(cv, cv.r, x, y, x + w, y + h, 26)
    for (sx, sy) in ((x + 10, y + 10), (x + w - 10, y + 10), (x + 10, y + h - 10), (x + w - 10, y + h - 10)):
        rust_bleed(cv, cv.r, sx, sy, cv.r.uniform(10, 26))
        cv.ell(sx, sy, 3.2, 3.2, fill=mix(BRASS, INK, 0.2), ink=INK, w=1.0)


def paint_pull(cv, cx, pulled=False):
    dy = 30 if pulled else 0
    # escutcheon with its recess: identical at every bell, so a pulled overlay can redraw it empty
    cv.rect(cx - 80, 812, cx + 80, 866, fill=BRASS, ink=INK, w=2.2)
    cv.rect(cx - 74, 818, cx + 74, 860, fill=mix(PANEL_FACE, INK, 0.5), ink=INK, w=1.6)
    cv.stroke([(cx, 786), (cx, 820 + dy)], 3.0, mix(SEAGLASS, PAPER, 0.35), jitter=0.03)
    cv.stroke([(cx + 1.6, 786), (cx + 1.6, 820 + dy)], 1.0, INK, jitter=0.03)
    y0 = 820 + dy
    cv.rect(cx - 70, y0, cx + 70, y0 + 36, fill=mix(BRASS, PAPER, 0.1), ink=INK, w=2.4)
    cv.box(cx - 66, y0 + 4, cx + 66, y0 + 10, mix(BRASS, PAPER, 0.45))
    cv.box(cx - 66, y0 + 28, cx + 66, y0 + 33, mix(BRASS, INK, 0.3))
    for ex in (cx - 70, cx + 70):
        cv.ell(ex, y0 + 18, 10, 18, fill=mix(BRASS, INK, 0.1), ink=INK, w=2.0)


def c_mooring_panel():
    name = "c_mooring_panel"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    plank_wall(cv, r)
    # shadow, then brass frame Rect2(244,110,960,860)
    sh = cv.layer()
    sh.box(256, 124, 1218, 984, INK)
    cv.comp(sh, 0.35)
    cv.rect(244, 110, 1204, 970, fill=BRASS, ink=INK, w=3.0)
    cv.box(250, 116, 1198, 124, mix(BRASS, PAPER, 0.4))
    cv.box(250, 956, 1198, 964, mix(BRASS, INK, 0.3))
    cv.rect(270, 128, 1178, 952, fill=PANEL_FACE, ink=INK, w=2.4)
    for (x, y) in ((256, 122), (1192, 122), (724, 122)):
        rust_bleed(cv, r, x, y, r.uniform(40, 90))
    for (x, y) in ((256, 122), (1192, 122), (256, 958), (1192, 958), (724, 122), (724, 958)):
        if y > 900:
            rust_bleed(cv, r, x, y, r.uniform(14, 30))
        cv.ell(x, y, 5, 5, fill=mix(BRASS, INK, 0.2), ink=INK, w=1.4)
    # blank enamel header strip
    cv.rect(300, 140, 1148, 204, fill=PAPER, ink=INK, w=2.4)
    cv.stroke([(306, 147), (1142, 147)], 1.2, mix(PAPER, INK, 0.2))
    foxing(cv, r, 300, 140, 1148, 204, 30)
    paint_plate(cv, PLATE_V, "v")
    paint_plate(cv, PLATE_U, "u")
    # the placard under two brass clips Rect2(324,520,800,210)
    sh = cv.layer()
    sh.box(330, 528, 1132, 738, INK)
    cv.comp(sh, 0.4)
    cv.rect(324, 520, 1124, 730, fill=mix(PAPER, (230, 222, 200), 0.4), ink=INK, w=2.2)
    foxing(cv, r, 324, 520, 1124, 730, 70)
    cv.stroke([(330, 726), (1118, 726)], 1.2, mix(PAPER, INK, 0.25))
    for cx in (440, 1008):
        cv.rect(cx - 34, 506, cx + 34, 540, fill=BRASS, ink=INK, w=2.2)
        cv.box(cx - 30, 510, cx + 30, 516, mix(BRASS, PAPER, 0.4))
        cv.ell(cx, 523, 4, 4, fill=INK, ink=None)
    # four T-handle pulls with blank number discs
    for cx in PULLS:
        cv.ell(cx, 760, 26, 26, fill=PAPER, ink=INK, w=2.4)
        cv.ell(cx, 760, 31, 31, fill=None, ink=BRASS, w=3.0)
        cv.ell(cx, 760, 33.5, 33.5, fill=None, ink=INK, w=1.4)
        paint_pull(cv, cx)
    # bell 2 has been pulled far more than the others: graphite grime from pencilled fingers
    g = Image.new("L", (W * S, H * S), 0)
    gd = ImageDraw.Draw(g)
    gr = random.Random(seed_of("R01:grime"))
    cx = PULLS[1]
    for i in range(26):
        a = gr.uniform(0, 2 * math.pi)
        rad = gr.uniform(28, 46)
        x, y = cx + rad * math.cos(a), 760 + rad * math.sin(a)
        gd.ellipse([(x - 6) * S, (y - 4) * S, (x + 6) * S, (y + 4) * S], fill=int(gr.uniform(80, 180)))
    for i in range(30):
        x, y = gr.uniform(cx - 84, cx + 84), gr.uniform(808, 872)
        gd.ellipse([(x - 9) * S, (y - 5) * S, (x + 9) * S, (y + 5) * S], fill=int(gr.uniform(60, 150)))
    for i in range(6):   # thumb wipes on the handle
        x = gr.uniform(cx - 50, cx + 50)
        gd.ellipse([(x - 14) * S, 826 * S, (x + 14) * S, 846 * S], fill=int(gr.uniform(70, 130)))
    tint(cv, g.filter(ImageFilter.GaussianBlur(2.4 * S)), mix(SOOT, (70, 74, 80), 0.3), 0.85)
    return cv.finish(name, "RGB", r)


def c_panel_tally(kind):
    name = f"c_panel_tally_{kind}"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    x, y, w, h = PLATE_V if kind == "v" else PLATE_U
    # pushed forward 6 px: a cast shadow and the sea-glass green enamel edge now showing
    sh = cv.layer()
    sh.box(x + w + 12, y + 8, x + w + 22, y + h + 22, INK)
    sh.box(x + 6, y + h + 12, x + w + 12, y + h + 22, INK)
    cv.comp(sh, 0.45)
    cv.poly([(x + w + 6, y - 6), (x + w + 12, y), (x + w + 12, y + h + 12), (x + w + 6, y + h + 6)],
            ENAMEL_G, INK, 2.0)
    cv.poly([(x - 6, y + h + 6), (x + w + 6, y + h + 6), (x + w + 12, y + h + 12), (x, y + h + 12)],
            mix(ENAMEL_G, INK, 0.15), INK, 2.0)
    # the SET tab, blank (the view writes SET)
    tx = x + 130
    cv.rect(tx, 476, tx + 100, 506, fill=ENAMEL_G, ink=INK, w=2.2)
    cv.box(tx + 4, 480, tx + 96, 484, mix(ENAMEL_G, PAPER, 0.4))
    # the tally's brass flag has dropped from behind the frame over the card's corner
    fx0, fx1 = x + w - 62, x + w - 14
    fy0, fy1 = y - 10, y + 128
    flag = [(fx0, fy0), (fx1, fy0), (fx1, fy1 - 20)] + \
        [((fx0 + fx1) / 2 + (fx1 - fx0) / 2 * math.cos(math.radians(a)), fy1 - 20 + 20 * math.sin(math.radians(a)))
         for a in range(0, 181, 15)] + [(fx0, fy1 - 20)]
    sh = cv.layer()
    sh.fillpoly([(px + 7, py + 7) for px, py in flag], INK)
    cv.comp(sh, 0.4)
    cv.fillpoly(flag, BRASS)
    fm = poly_mask(flag)
    tint(cv, mul_masks(fm, grad_mask(fx0, fy0, fx1, fy1, 0.0, 0.5, axis="x")), mix(BRASS, INK, 0.5))
    tint(cv, mul_masks(fm, poly_mask([(fx0, fy0 + 30), (fx0 + 16, fy0 + 10), (fx0 + 34, fy1 - 30),
                                      (fx0 + 18, fy1 - 10)])), mix(BRASS, PAPER, 0.5), 0.7)
    cv.stroke(flag, 2.4, INK, closed=True)
    cv.ell((fx0 + fx1) / 2, fy0 + 12, 6, 6, fill=mix(BRASS, INK, 0.25), ink=INK, w=1.6)
    cv.ell((fx0 + fx1) / 2, fy1 - 26, 9, 9, fill=mix(BRASS, INK, 0.15), ink=INK, w=1.6)
    # brass pin through the top
    cx = x + w / 2
    cv.rect(cx - 3, y - 8, cx + 3, y + 22, fill=mix(BRASS, INK, 0.2), ink=INK, w=1.4)
    cv.ell(cx, y + 14, 10, 10, fill=BRASS, ink=INK, w=2.0)
    cv.ell(cx - 3, y + 11, 3, 3, fill=mix(BRASS, PAPER, 0.6), ink=None)
    return cv.finish(name, "RGBA", r)


def c_panel_pull_down():
    name = "c_panel_pull_down"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    paint_pull(cv, PULLS[0], pulled=True)
    return cv.finish(name, "RGBA", r)


# ---------------------------------------------------------------- c_boat_window
def boat_window_base(cv, r):
    ring_c = (724, 540)
    # outside the lens: paper-textured ink navy
    cv.box(0, 0, W, H, INK)
    tex = cv.layer()
    for i in range(500):
        x, y = r.uniform(0, W), r.uniform(0, H)
        tex.stroke([(x, y), (x + r.uniform(20, 70), y + r.uniform(-2, 2))], 1.2,
                   mix(INK, SEAGLASS, 0.25), jitter=0.05)
    cv.comp(tex, 0.25)
    inside = cv.layer()
    # cabin planks (horizontal), storm navy
    for k, y in enumerate(range(80, 1010, 44)):
        inside.box(260, y, 1200, y + 44, (52, 66, 76) if k % 2 == 0 else (46, 60, 70))
        inside.stroke([(260, y), (1200, y)], 2.0, INK, alpha=220)
    # chart room seen through the glass
    room = (88, 92, 84)
    inside.rect(404, 280, 1044, 680, fill=room, ink=None)
    glow(inside, lambda d: d.ellipse([360 * S, 230 * S, 760 * S, 600 * S], fill=255), AMBER, 60, 0.35)
    # wall boards
    for x in range(420, 1044, 58):
        inside.stroke([(x, 284), (x, 556)], 1.4, mix(room, INK, 0.45), alpha=200)
    # shelf with rolled charts and books
    inside.rect(800, 404, 1030, 414, fill=mix(TIMBER, PAPER, 0.15), ink=INK, w=2.0)
    bx = 806
    for k in range(9):
        bw = r.uniform(12, 20)
        bh = r.uniform(44, 70)
        tone = [STORM, mix(TIMBER, INK, 0.2), COPPER, mix(PAPER, TIMBER, 0.3)][k % 4]
        inside.rect(bx, 404 - bh, bx + bw, 404, fill=tone, ink=INK, w=1.6)
        bx += bw + 2
        if bx > 990:
            break
    for k in range(3):
        inside.ell(1006 + k * 7, 392 - k * 10, 6, 6, fill=PAPER, ink=INK, w=1.4)
    # hanging amber lamp
    inside.stroke([(500, 280), (500, 330)], 2.0)
    inside.poly([(482, 330), (518, 330), (526, 356), (474, 356)], mix(BRASS, INK, 0.1), INK, 2.2)
    inside.ell(500, 362, 14, 10, fill=mix(AMBER, PAPER, 0.5), ink=INK, w=1.8)
    # the chart table: top at y560, front panel to y680
    inside.rect(404, 560, 1044, 680, fill=mix(TIMBER, PAPER, 0.08), ink=INK, w=2.6)
    inside.box(406, 562, 1042, 568, mix(TIMBER, PAPER, 0.35))
    for dx in (440, 760):
        inside.rect(dx, 600, dx + 240, 660, fill=None, ink=INK, w=1.8)
        inside.ell(dx + 120, 630, 6, 6, fill=BRASS, ink=INK, w=1.4)
    # Ada's composite chart Rect2(520,520,400,110)
    inside.rect(520, 520, 920, 630, fill=PAPER, ink=INK, w=2.2)
    for gx in range(540, 920, 40):
        inside.stroke([(gx, 524), (gx, 626)], 0.8, mix(PAPER, SEAGLASS, 0.6), jitter=0.02)
    for gy in (546, 575, 604):
        inside.stroke([(524, gy), (916, gy)], 0.8, mix(PAPER, SEAGLASS, 0.6), jitter=0.02)

    def curve(period, phase, amp, mid, n=80):
        return [(526 + i * 388 / n, mid + amp * math.sin(phase + 2 * math.pi * (i * 388 / n) / period))
                for i in range(n + 1)]
    inside.stroke(curve(150, 0.2, 22, 575), 2.4, INK, jitter=0.04)
    dashed = curve(205, 1.9, 18, 572)
    for i in range(0, len(dashed) - 2, 4):   # the second ink curve is dashed: two hands, one chart
        inside.stroke(dashed[i:i + 3], 2.0, INK, jitter=0.04)
    inside.stroke(curve(97, 2.6, 30, 578), 2.6, mix(BRASS, INK, 0.3), jitter=0.04)
    for k in range(14):
        tx = 540 + k * 27 + r.uniform(-4, 4)
        inside.stroke([(tx, 612), (tx + 1, 622)], 1.2, (96, 96, 96))
    # brass window frame Rect2(404,280,640,400)
    inside.rect(392, 268, 1056, 692, fill=None, ink=BRASS, w=12)
    inside.rect(386, 262, 1062, 698, fill=None, ink=INK, w=2.4)
    inside.rect(404, 280, 1044, 680, fill=None, ink=INK, w=2.4)
    for (x, y) in ((396, 272), (1052, 272), (396, 688), (1052, 688), (724, 272), (724, 688)):
        inside.ell(x, y, 3.4, 3.4, fill=mix(BRASS, INK, 0.3), ink=None)
    # the cabin sill under the window: weathered teak, its shadow on the planks below
    sill = mix(TIMBER, PAPER, 0.12)
    sh = inside.layer()
    sh.box(380, 716, 1068, 736, INK)
    inside.comp(sh, 0.35)
    inside.rect(372, 698, 1076, 718, fill=sill, ink=None)
    wood_grain(inside, r, 372, 700, 1076, 718, sill, vertical=False, lines=3, knots=False, alpha=0.6)
    inside.box(372, 698, 1076, 702, mix(sill, PAPER, 0.35))
    inside.rect(372, 698, 1076, 718, fill=None, ink=INK, w=2.4)
    # through the lens: clip to the inner circle
    m = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(m).ellipse([(724 - 400) * S, (540 - 400) * S, (724 + 400) * S, (540 + 400) * S], fill=255)
    cv.comp(inside, mask=m)
    return ring_c


def glass_sheen(cv):
    g = cv.layer()
    g.fillpoly([(860, 284), (900, 284), (720, 676), (680, 676)], PAPER)
    g.fillpoly([(930, 284), (946, 284), (766, 676), (750, 676)], PAPER)
    cv.comp(g, 0.07)


def lens_ring(cv, r):
    cx, cy = 724, 540
    cv.ell(cx, cy, 420, 420, fill=None, ink=BRASS, w=40)
    cv.ell(cx, cy, 440, 440, fill=None, ink=INK, w=3.0)
    cv.ell(cx, cy, 400, 400, fill=None, ink=INK, w=3.0)
    cv.ell(cx, cy, 424, 424, fill=None, ink=mix(BRASS, INK, 0.35), w=1.6)
    hl = cv.layer()
    pts = [(cx + 412 * math.cos(math.radians(a)), cy + 412 * math.sin(math.radians(a))) for a in range(200, 291, 3)]
    hl.stroke(pts, 8, mix(BRASS, PAPER, 0.5), jitter=0.05)
    cv.comp(hl, 0.7)
    for k in range(120):  # knurling on the outer band
        a = math.radians(k * 3)
        cv.stroke([(cx + 430 * math.cos(a), cy + 430 * math.sin(a)), (cx + 438 * math.cos(a), cy + 438 * math.sin(a))],
                  1.4, INK, alpha=200, jitter=0.02)


def c_boat_window():
    name = "c_boat_window"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    boat_window_base(cv, r)
    glass_sheen(cv)
    lens_ring(cv, r)
    return cv.finish(name, "RGB", r)


def c_boat_window_figure(turned, prefix="c_boat_window"):
    """The figure at the chart. Stark flat silhouette: Ada's own head and pinned hair (the
    door figure's shape at 1.8x), a featureless storm-navy face when it has turned to look out,
    two tiny amber glints for eyes, and hands as solid dark shapes, too long."""
    name = f"{prefix}_figure_turned" if turned else f"{prefix}_figure"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    coat = (26, 32, 38)
    rim = mix(AMBER, PAPER, 0.3)
    body = smooth([(648, 640), (650, 520), (656, 440), (672, 404), (700, 392), (748, 392),
                   (772, 404), (778, 440), (776, 520), (772, 640)], 5)
    cv.fillpoly(body, coat)
    cv.box(696, 372, 726, 400, coat)  # neck
    # Ada's head and pinned hair (ada_door: head 15x18, bun r7 at (-12, -8)), x1.8
    face = mix(STORM, coat, 0.35) if turned else coat
    cv.ell(711 - 21.6, 358 - 14.4, 12.6, 12.6, fill=coat, ink=None)
    cv.ell(711, 358, 27, 32.4, fill=face, ink=None)
    if turned:
        cv.ell(711 - 21.6, 358 - 14.4, 12.6, 12.6, fill=coat, ink=None)
        # two tiny amber glints: lamp-light caught where eyes would be, nothing drawn
        for ex in (702, 720):
            cv.ell(ex, 354, 2.0, 1.6, fill=mix(AMBER, PAPER, 0.35), ink=None)
        # arms hang, too long; solid hands with long fingers past the hem
        cv.stroke([(656, 420), (646, 520), (646, 600)], 14, coat, jitter=0.02)
        cv.stroke([(772, 420), (780, 520), (778, 600)], 14, coat, jitter=0.02)
        for hx in (646, 778):
            cv.poly(smooth([(hx - 8, 596), (hx + 8, 596), (hx + 9, 620), (hx - 9, 620)], 2), coat, None)
            for k, fx in enumerate((-6.5, -2.2, 2.2, 6.5)):
                ln = (44, 58, 56, 40)[k]
                tip = (hx + fx * 1.3, 618 + ln)
                cv.fillpoly([(hx + fx - 2.4, 616), (hx + fx + 2.4, 616), (tip[0] + 0.9, tip[1] - 4),
                             (tip[0], tip[1]), (tip[0] - 0.9, tip[1] - 4)], coat)
    else:
        cv.poly([(690, 380), (732, 380), (744, 404), (680, 404)], mix(coat, SEAGLASS, 0.12), None)  # collar
        cv.stroke([(772, 410), (780, 470), (778, 540), (770, 572)], 16, coat, jitter=0.02)  # right arm to chart
        cv.fillpoly(smooth([(756, 566), (778, 566), (780, 584), (760, 588)], 3), coat)
        cv.stroke([(700, 430), (708, 560)], 2.0, mix(coat, SEAGLASS, 0.3), alpha=180)  # coat seam
    # legs under the coat, to the table front
    cv.fillpoly([(670, 638), (698, 638), (696, 680), (672, 680)], coat)
    cv.fillpoly([(726, 638), (754, 638), (752, 680), (728, 680)], coat)
    cv.fillpoly([(648, 632), (772, 632), (776, 644), (644, 644)], coat)  # hem
    cv.stroke(body, 1.8, rim, closed=False, alpha=140)
    # clip to the window glass and keep the lens sheen on top
    clip = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(clip).rectangle([404 * S, 280 * S, 1044 * S - 1, 680 * S - 1], fill=255)
    cv.im.putalpha(ImageChops.multiply(cv.im.getchannel("A"), clip))
    return cv.finish(name, "RGBA", r)


# ---------------------------------------------------------------- c_capsule
SURFACE_Y = 780        # the sea's surface in the capsule close-up
MOUTH_Y = 284          # the open capsule's rim
MOUTH_RX, MOUTH_RY = 108, 14


def capsule_background(cv, r):
    """Under the jetty's edge: shaded air above a hard sea surface, the near piling going
    down through it. Composition dropped 40 px so the cleat clears the HUD."""
    air0, air1 = (52, 66, 70), (92, 112, 110)
    cv.hrows(0, SURFACE_Y, air0, air1, ya=170, yb=SURFACE_Y)
    water0, water1 = (78, 104, 102), (52, 76, 78)
    cv.hrows(SURFACE_Y, H, water0, water1, ya=SURFACE_Y, yb=H)
    # far pilings in the shade under the deck
    for fx in (470, 1010, 1260):
        cv.box(fx, 170, fx + 46, SURFACE_Y, mix(air0, INK, 0.35))
        cv.box(fx, SURFACE_Y, fx + 46, SURFACE_Y + 40, mix(water0, INK, 0.25), alpha=140)
    lay = cv.layer()
    for i in range(150):
        y = r.uniform(SURFACE_Y + 12, H)
        x = r.uniform(-60, W)
        ln = r.uniform(60, 200)
        lay.stroke([(x, y), (x + ln / 2, y - 3), (x + ln, y)], r.uniform(1.6, 3.2),
                   PAPER if r.random() < 0.4 else INK, jitter=0.08)
    cv.comp(lay, 0.22)
    # the surface: a hard pale line, a dark band under it
    cv.stroke([(-10, SURFACE_Y), (W + 10, SURFACE_Y)], 2.4, mix(PAPER, SEAGLASS, 0.4), jitter=0.0)
    tint(cv, grad_mask(0, SURFACE_Y + 2, W, SURFACE_Y + 30, 0.4, 0.0), INK)
    # a piling at the left: barnacled and weeded below the surface, ordinary
    pl = PILE
    cv.wk = 1.3
    cv.rect(150, 160, 330, H + 4, fill=pl, ink=None)
    wood_grain(cv, r, 150, 160, 330, H, pl, lines=12, alpha=0.5)
    weather_board(cv, r, 150, 160, 330, SURFACE_Y, pl, top_dark=0.45, foot_dark=0.3)
    cv.box(296, 162, 330, H, mix(pl, INK, 0.3), alpha=200)
    tint(cv, grad_mask(150, SURFACE_Y, 330, H, 0.25, 0.55), mix(pl, (60, 96, 96), 0.6))
    for i in range(60):
        x = r.uniform(158, 322)
        y = r.uniform(SURFACE_Y - 30, 1080)
        cv.ell(x, y, r.uniform(5, 10), r.uniform(4, 8), fill=mix(PAPER, SEAGLASS, 0.3), ink=INK, w=1.2)
    weed = (62, 74, 60)
    for i in range(18):
        x = r.uniform(156, 324)
        cv.stroke(smooth([(x, SURFACE_Y - 20 + r.uniform(0, 30)), (x + r.uniform(-14, 14), 880),
                          (x + r.uniform(-20, 20), 980), (x + r.uniform(-10, 10), 1086)], 5),
                  r.uniform(4, 8), weed, jitter=0.1)
    cv.rect(150, 160, 330, H + 4, fill=None, ink=INK, w=3.0)
    # deck edge and the cleat across the top
    deck = (138, 124, 104)
    cv.rect(-10, 80, W + 10, 170, fill=deck, ink=None)
    wood_grain(cv, r, -10, 82, W + 10, 170, deck, vertical=False, lines=6, alpha=0.5)
    cv.box(0, 82, W, 94, mix(deck, PAPER, 0.35))
    tint(cv, grad_mask(0, 120, W, 170, 0.0, 0.4), INK)
    cv.rect(-10, 80, W + 10, 170, fill=None, ink=INK, w=3.0)
    for x in (90, 420, 1010, 1330):
        cv.stroke([(x, 96), (x, 168)], 2.0, INK, alpha=180)
    tint(cv, grad_mask(0, 170, W, 230, 0.55, 0.0), INK)   # the deck's shadow
    cv.ell(240, 132, 9, 9, fill=SOOT, ink=INK, w=1.6)
    rust_bleed(cv, r, 240, 138, 40)
    cleat = mix(SOOT, STORM, 0.4)
    horn = smooth([(568, 70), (590, 54), (640, 46), (724, 44), (808, 46), (858, 54), (880, 70), (850, 70),
                   (800, 64), (764, 66), (764, 80), (684, 80), (684, 66), (648, 64), (598, 70)], 3)
    cv.poly(horn, cleat, INK, 3.0)
    cv.stroke([(600, 56), (720, 48), (848, 56)], 2.4, mix(SEAGLASS, PAPER, 0.4))
    # the line: wrapped on the cleat, down to the capsule's bail
    rope = mix(TIMBER, PAPER, 0.18)
    cv.rect(714, 40, 734, 226, fill=rope, ink=INK, w=2.6)
    cv.box(716, 42, 720, 224, mix(rope, PAPER, 0.4))
    for y in range(44, 226, 14):
        cv.stroke([(714, y), (734, y + 9)], 1.6, INK, alpha=200, jitter=0.03)
    cv.ell(724, 62, 46, 14, fill=None, ink=rope, w=10)
    cv.ell(724, 62, 46, 14, fill=None, ink=INK, w=1.6)
    cv.wk = 1.0


def capsule_body(cv, mouth_open):
    """Rect2(604,300,240,540): dull, dry brass. No droplets: it came up out of the sea dry.
    Tarnish, a faint tide-line it never had, and the sea over its foot."""
    dull = mix(BRASS, TIMBER, 0.12)
    cv.wk = 1.25
    # bail over the top
    cv.stroke(smooth([(606, 340), (614, 260), (724, 220), (834, 260), (842, 340)], 6), 10,
              mix(BRASS, INK, 0.3), jitter=0.03)
    cv.ell(606, 340, 10, 10, fill=dull, ink=INK, w=2.0)
    cv.ell(842, 340, 10, 10, fill=dull, ink=INK, w=2.0)
    outline = [(604, 300), (844, 300), (844, 840)] + smooth([(844, 840), (808, 856), (724, 860), (640, 856),
                                                              (604, 840)], 4) + [(604, 840)]
    cv.fillpoly(outline, dull)
    bm = poly_mask(outline)
    # cylinder modelling: a lit band on the left, turning into shade on the right
    tint(cv, mul_masks(bm, grad_mask(604, 300, 844, 860, 0.0, 0.62, axis="x", ease=1.4)), mix(dull, INK, 0.6))
    tint(cv, mul_masks(bm, grad_mask(604, 300, 690, 860, 0.0, 0.55, axis="x")), mix(dull, PAPER, 0.5))
    tint(cv, mul_masks(bm, grad_mask(604, 300, 650, 860, 0.5, 0.0, axis="x")), mix(dull, INK, 0.3))
    # dry tarnish: dull blotches and a few verdigris-grey freckles
    t = Image.new("L", (W * S, H * S), 0)
    td = ImageDraw.Draw(t)
    tr = random.Random(seed_of("R01:tarnish"))
    for i in range(46):
        x, y = tr.uniform(610, 838), tr.uniform(310, 840)
        rr = tr.uniform(3, 16)
        td.ellipse([(x - rr) * S, (y - rr * 0.7) * S, (x + rr) * S, (y + rr * 0.7) * S], fill=int(tr.uniform(60, 160)))
    tint(cv, mul_masks(bm, t.filter(ImageFilter.GaussianBlur(3 * S))), (96, 84, 60), 0.5)
    for i in range(18):
        x, y = tr.uniform(612, 836), tr.uniform(320, 830)
        cv.ell(x, y, tr.uniform(1.2, 2.6), tr.uniform(1.0, 2.0), fill=mix(COPPER, PAPER, 0.2), ink=None, alpha=120)
    # the faint tide-line: a ragged darker band, as if it had stood half in water for years
    tl = [(604, 588)] + [(604 + k * 12, 588 + tr.uniform(-4, 4)) for k in range(21)] + [(844, 588)]
    tint(cv, mul_masks(bm, poly_mask(tl + [(844, 604), (604, 604)], 2.0)), (86, 74, 52), 0.45)
    for y in (380, 720):  # rolled bands
        cv.rect(600, y, 848, y + 16, fill=mix(dull, INK, 0.12), ink=INK, w=2.2)
        cv.box(604, y + 3, 700, y + 6, mix(dull, PAPER, 0.4))
    cv.stroke(outline, 3.0, INK, closed=True)
    if mouth_open:
        # threaded neck, the rim ellipse, and the dark of the inside
        cv.rect(616, MOUTH_Y, 832, MOUTH_Y + 22, fill=mix(dull, INK, 0.1), ink=INK, w=2.0)
        for y in range(MOUTH_Y + 4, MOUTH_Y + 22, 5):
            cv.stroke([(618, y), (830, y + 2.5)], 1.4, INK, alpha=190)
        cv.ell(724, MOUTH_Y, MOUTH_RX, MOUTH_RY, fill=mix(dull, PAPER, 0.3), ink=INK, w=2.2)
        cv.ell(724, MOUTH_Y + 1.5, MOUTH_RX - 9, MOUTH_RY - 4.5, fill=(14, 22, 28), ink=INK, w=1.4)
    # the sea over its foot
    sub = cv.layer()
    sub.box(596, SURFACE_Y, 852, 866, (70, 98, 98))
    cv.comp(sub, mask=mul_masks(poly_mask(outline), grad_mask(0, SURFACE_Y, W, 866, 0.5, 0.75)))
    cv.stroke([(598, SURFACE_Y), (850, SURFACE_Y)], 2.4, mix(PAPER, SEAGLASS, 0.4), jitter=0.0)
    cv.wk = 1.0


def paint_cap(cv, x0, y0, w=264, h=72):
    """The screw cap on the capsule: a squat drum, fine knurling, its round crown on top."""
    cv.wk = 1.25
    cap = mix(BRASS, PAPER, 0.06)
    cv.rect(x0, y0, x0 + w, y0 + h, fill=cap, ink=None)
    cm = poly_mask([(x0, y0), (x0 + w, y0), (x0 + w, y0 + h), (x0, y0 + h)])
    tint(cv, mul_masks(cm, grad_mask(x0, y0, x0 + w, y0 + h, 0.0, 0.6, axis="x", ease=1.4)), mix(cap, INK, 0.6))
    tint(cv, mul_masks(cm, grad_mask(x0, y0, x0 + w * 0.35, y0 + h, 0.0, 0.45, axis="x")), mix(cap, PAPER, 0.5))
    for k in range(int(w / 6)):
        x = x0 + 3 + k * 6
        cv.stroke([(x, y0 + 12), (x, y0 + h - 6)], 1.0, mix(BRASS, INK, 0.5), jitter=0.02, alpha=200)
    cv.rect(x0, y0, x0 + w, y0 + h, fill=None, ink=INK, w=3.0)
    cv.ell(x0 + w / 2, y0, w / 2, 16, fill=mix(cap, PAPER, 0.25), ink=INK, w=2.6)
    cv.ell(x0 + w / 2, y0, w / 2 - 22, 9, fill=None, ink=mix(cap, INK, 0.45), w=1.6)
    cv.wk = 1.0


def c_capsule():
    name = "c_capsule"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    capsule_background(cv, r)
    capsule_body(cv, False)
    paint_cap(cv, 592, 258)
    return cv.finish(name, "RGB", r)


def c_capsule_open():
    name = "c_capsule_open"
    r = random.Random(seed_of(f"{name}.png"))
    # repaint the plate's background under the closed cap so this overlay hides it exactly
    bg = Cv(random.Random(seed_of("c_capsule.png")))
    capsule_background(bg, bg.r)
    cv = Cv(r)
    patch = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(patch).rectangle([580 * S, 228 * S, 868 * S, 300 * S], fill=255)
    cv.im.alpha_composite(Image.composite(bg.im, Image.new("RGBA", bg.im.size, (0, 0, 0, 0)), patch))
    capsule_body(cv, True)
    # the cap, unscrewed, hanging lower on a short chain to the right: a round cup, half-face
    pts = [(842, 340)]
    for k in range(1, 7):
        pts.append((842 + k * 8, 340 + k * 11))
    for (a, b) in zip(pts, pts[1:]):
        cv.ell((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 4, 5, fill=None, ink=mix(INK, BRASS, 0.3), w=1.8)
    ccx, ccy = 924, 470
    cv.wk = 1.25
    cv.ell(ccx, ccy, 58, 66, fill=mix(BRASS, PAPER, 0.08), ink=INK, w=3.0)
    cm = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(cm).ellipse([(ccx - 58) * S, (ccy - 66) * S, (ccx + 58) * S, (ccy + 66) * S], fill=255)
    tint(cv, mul_masks(cm, grad_mask(ccx - 58, ccy - 66, ccx + 58, ccy + 66, 0.0, 0.5, axis="x")), mix(BRASS, INK, 0.6))
    cv.ell(ccx + 6, ccy + 4, 42, 50, fill=mix(BRASS, INK, 0.55), ink=INK, w=2.0)
    for k in range(5):   # the threads inside the cup
        yy = ccy - 30 + k * 14
        half = 40 * math.sqrt(max(0.0, 1 - ((yy - ccy - 4) / 50) ** 2))
        cv.stroke(smooth([(ccx + 6 - half, yy + 3), (ccx + 6, yy - 3), (ccx + 6 + half, yy + 3)], 4), 1.6,
                  mix(BRASS, PAPER, 0.1), alpha=180)
    cv.stroke(smooth([(ccx - 52, ccy - 20), (ccx - 36, ccy - 52), (ccx - 6, ccy - 64)], 4), 4,
              mix(BRASS, PAPER, 0.5), alpha=200)
    cv.ell(ccx - 40, ccy - 50, 5, 5, fill=BRASS, ink=INK, w=1.6)   # the chain's eye
    cv.wk = 1.0
    return cv.finish(name, "RGBA", r)


def mouth_clip(cv):
    """Hide whatever stands in the capsule below the front lip of its rim."""
    m = Image.new("L", (W * S, H * S), 255)
    lip = [(724 + (MOUTH_RX - 9) * math.cos(math.radians(a)), MOUTH_Y + 1.5 + (MOUTH_RY - 4.5) * math.sin(math.radians(a)))
           for a in range(0, 181, 4)]
    ImageDraw.Draw(m).polygon(Cv.P(lip + [(724 - MOUTH_RX - 20, H), (724 + MOUTH_RX + 20, H)]), fill=0)
    cv.im.putalpha(ImageChops.multiply(cv.im.getchannel("A"), m))


def c_capsule_key():
    name = "c_capsule_key"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    cv.wk = 1.2
    iron = (92, 98, 98)
    # standing up out of the mouth: bow (ring) at the top, the shank down into the dark
    cv.ell(668, 196, 28, 26, fill=iron, ink=INK, w=2.4)
    cv.ell(668, 196, 13, 11, fill=(52, 66, 70), ink=INK, w=2.0)
    cv.ell(660, 186, 6, 4, fill=mix(iron, PAPER, 0.45), ink=None)
    cv.rect(661, 220, 675, 300, fill=iron, ink=INK, w=2.2)
    cv.box(663, 222, 666, 298, mix(iron, PAPER, 0.4))
    cv.rect(653, 230, 683, 236, fill=mix(iron, INK, 0.2), ink=INK, w=1.4)
    # blank paper tag on a string, hung off the bow (the view writes SERVICE)
    cv.stroke(smooth([(644, 204), (630, 216), (624, 230)], 4), 1.6, mix(PAPER, TIMBER, 0.4))
    cv.poly([(590, 232), (652, 224), (658, 264), (596, 272)], PAPER, INK, 2.0)
    foxing(cv, r, 594, 230, 654, 268, 8)
    cv.ell(622, 234, 3, 3, fill=(52, 66, 70), ink=INK, w=1.0)
    mouth_clip(cv)
    return cv.finish(name, "RGBA", r)


def c_capsule_note():
    name = "c_capsule_note"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    cv.wk = 1.2
    # a rolled paper note standing up out of the mouth
    cv.rect(744, 176, 804, 300, fill=PAPER, ink=INK, w=2.4)
    cv.ell(774, 176, 30, 9, fill=mix(PAPER, (230, 222, 200), 0.6), ink=INK, w=2.2)
    cv.ell(774, 176, 12, 3.6, fill=mix(PAPER, TIMBER, 0.45), ink=INK, w=1.4)
    cv.box(746, 184, 756, 298, mix(PAPER, (240, 234, 218), 0.6))
    cv.box(792, 184, 802, 298, mix(PAPER, INK, 0.15))
    foxing(cv, r, 746, 182, 802, 298, 10)
    cv.stroke([(748, 286), (784, 250), (802, 228)], 1.4, mix(PAPER, INK, 0.3))  # the roll's lapped edge
    cv.rect(742, 234, 806, 244, fill=mix(TIMBER, PAPER, 0.3), ink=INK, w=1.4)  # twine
    cv.stroke([(766, 244), (760, 266)], 1.6, mix(TIMBER, PAPER, 0.3))
    cv.stroke([(774, 244), (782, 264)], 1.6, mix(TIMBER, PAPER, 0.3))
    mouth_clip(cv)
    return cv.finish(name, "RGBA", r)



# =================================================================== dusk (first visit)
DUSK_TOP = hexc("#2f3b4a")
DUSK_HOR = hexc("#4a5866")
DUSK_SEA = hexc("#2c4448")
DUSK_WAVE = hexc("#6f8790")
LIFT = 1.10            # hotspot props: +10% value so they still read in the dusk


def lift(lay, k=LIFT):
    """Raise a layer's value by k (alpha untouched): the hotspot props' lift."""
    rr, gg, bb, aa = lay.im.split()
    up = [ch.point(lambda v: min(255, int(v * k + 0.5))) for ch in (rr, gg, bb)]
    lay.im = Image.merge("RGBA", (*up, aa))
    lay.d = ImageDraw.Draw(lay.im)


def back_b0_dusk():
    """The first visit: low flat overcast in hard bands, darkening upward; nothing lit from
    anywhere, so nothing casts a shadow. A dark flat sea with pale cold wave marks, the
    lighthouse dark on its headland. The bands are frozen; only the wave frames move."""
    name = "back_b0_dusk"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r, bg=DUSK_TOP)
    # the overcast: seven flat bands, thinner toward the horizon, each edge a slow, low swell
    n = 5
    edges = [HORIZON * (1 - (1 - k / n) ** 1.35) for k in range(n + 1)]
    for k in range(n):
        col = mix(DUSK_TOP, DUSK_HOR, k / (n - 1))
        y0 = edges[k]
        if k == 0:
            cv.box(0, 0, W, HORIZON, col)
            continue
        amp = 3 + 5 * (1 - k / n)
        ph = r.uniform(0, 6.28)
        per = r.uniform(380, 620)
        top = [(x, y0 + amp * math.sin(ph + 2 * math.pi * x / per)) for x in range(-20, W + 41, 20)]
        cv.fillpoly(top + [(W + 40, HORIZON + 2), (-20, HORIZON + 2)], col)
    # the sea: one flat tone, static wave marks in the cold pale grey
    cv.box(0, HORIZON, W, H, DUSK_SEA)
    marks = cv.layer()
    lay_r = random.Random(seed_of("R01:dusk_seatex"))
    for i in range(420):
        y = HORIZON + 8 + (lay_r.random() ** 1.35) * (H - HORIZON - 8)
        x = lay_r.uniform(-40, W)
        t = (y - HORIZON) / (H - HORIZON)
        ln = 18 + t * 100 * lay_r.uniform(0.6, 1.3)
        sag = 1 + t * 3
        marks.stroke([(x, y), (x + ln * 0.5, y + sag * 0.6), (x + ln, y)], 1.0 + t * 1.4, DUSK_WAVE, jitter=0.1)
    cut_calm(marks, 1.0)
    cv.comp(marks, 0.3)
    cv.stroke([(0, HORIZON), (W, HORIZON)], 2.0, mix(DUSK_HOR, DUSK_WAVE, 0.6), alpha=170, jitter=0.03)
    cv.stroke([(0, HORIZON + 2), (W, HORIZON + 2)], 1.4, INK, alpha=110, jitter=0.03)
    paint_calm(cv, DUSK_SEA, DUSK_HOR)
    # the hotspot props out here (causeway, headland, the dark lighthouse), lifted to read
    props = cv.layer()
    props.wk = 0.6
    paint_causeway(props, 0.35, DUSK_HOR, random.Random(seed_of("R01:causeway")))
    land = mix(mix(STORM, COPPER, 0.45), DUSK_HOR, 0.25)
    paint_headland(props, land, 200, mix(COPPER, DUSK_HOR, 0.35), random.Random(seed_of("R01:headland")))
    props.wk = 0.8
    paint_lighthouse(props, "off", 0.18, DUSK_HOR)
    lift(props)
    cv.comp(props)
    cv.wk = 1.0
    return cv.finish(name, "RGB", r)


def ov_reflections_dusk():
    """Every piling's reflection, all nine. The seven in open water break up with the chop;
    the two standing in the bell's calm are mirrored still and whole. The boat has none."""
    name = "reflections_dusk"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    ink_l = cv.layer()
    pale_l = cv.layer()
    still = cv.layer()
    for cx in PILINGS:
        if cx in (680, 785):
            pc = mix(mix(PILE, DUSK_SEA, 0.4), INK, 0.1)
            still.box(cx - 13, 872, cx + 13, 952, pc)
            still.box(cx - 13, 872, cx + 13, 890, mix((62, 74, 60), DUSK_SEA, 0.3))
            still.box(cx - 13, 872, cx - 11, 952, mix(INK, DUSK_SEA, 0.2))
            still.box(cx + 11, 872, cx + 13, 952, mix(INK, DUSK_SEA, 0.2))
            continue
        y = 872
        k = 0
        while y < 940:
            t = (y - 870) / 70
            half = 13 + r.uniform(-2, 5) * (1 - t * 0.4)
            off = 5 * math.sin(k * 1.7 + cx * 0.01) + r.uniform(-2, 2)
            wid = 2.6 - t
            ink_l.stroke([(cx - half + off, y), (cx + half * 0.3 + off, y + 0.8), (cx + half + off, y)],
                         max(1.0, wid + 0.8), INK, jitter=0.1)
            pale_l.stroke([(cx - half * 0.6 - off * 0.5, y + 4), (cx + half * 0.4 - off * 0.5, y + 4.6)],
                          max(1.0, wid), DUSK_WAVE, jitter=0.1)
            y += 7 + t * 4
            k += 1
    cut_calm(ink_l, 0.5)
    cut_calm(pale_l, 0.5)
    cv.comp(ink_l, 0.7)
    cv.comp(pale_l, 0.6)
    cv.comp(still, 0.55, mask=calm_mask(-2))
    return cv.finish(name, "RGBA", r)


def ov_dusk_lamps():
    """The dusk's two lights: the lamp-post lit over a pool on the deck, and the station's
    second upstairs window lit amber (the office window beside it is the P01 lamp's)."""
    name = "dusk_lamps"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    lx = 508
    # the pool: on the deck boards and the rail under the lantern, soft-edged, no beam
    glow(cv, lambda d: d.ellipse([(lx - 92) * S, 700 * S, (lx + 92) * S, 786 * S], fill=255), AMBER, 16, 0.42)
    glow(cv, lambda d: d.ellipse([(lx - 20) * S, 560 * S, (lx + 20) * S, 594 * S], fill=255), AMBER, 14, 0.75)
    cv.rect(lx - 6, 568, lx + 6, 586, fill=mix(AMBER, PAPER, 0.45), ink=None)
    cv.box(lx - 3, 571, lx + 3, 583, mix(AMBER, PAPER, 0.75))
    cv.poly([(lx - 6, 568), (lx + 6, 568), (lx + 7, 586), (lx - 7, 586)], None, INK, 1.6)
    cv.stroke([(lx, 569), (lx, 585)], 1.0, INK, alpha=180)
    # the second upstairs window, lit
    x0, y0 = 190, 340
    glow(cv, lambda d: d.rectangle([(x0 - 6) * S, (y0 - 6) * S, (x0 + 66) * S, (y0 + 66) * S], fill=255), AMBER, 5, 0.6)
    cv.rect(x0, y0, x0 + 60, y0 + 60, fill=AMBER, ink=None)
    cv.box(x0 + 6, y0 + 6, x0 + 54, y0 + 54, mix(AMBER, PAPER, 0.3))
    window_bars(cv, x0, y0)
    cv.rect(x0, y0, x0 + 60, y0 + 60, fill=None, ink=INK, w=1.8)
    return cv.finish(name, "RGBA", r)


# =================================================================== band 4: the tilted sea
TILT_PIVOT = (JETTY_END, WATERLINE)   # the jetty's end, at the waterline
TILT_DEG = 3.0                        # clockwise on screen: the sea rises toward the station
B4 = dict(sky0=hexc("#5A6B72"), sea0=hexc("#3A5052"), haze=0.45)


def b4_colours():
    sky0, sea0 = B4["sky0"], B4["sea0"]
    return sky0, mix(sky0, PAPER, 0.07), sea0, mix(sea0, INK, 0.25)


def b4_level(cv):
    """What stays level at band 4: the causeway and the bell's calm."""
    sky0, sky1, sea0, sea1 = b4_colours()
    paint_calm(cv, mix(sea0, sea1, (CALM[1] - HORIZON) / (H - HORIZON)), mix(sky0, sky1, 0.6), B4["haze"])
    cv.wk = 0.6
    paint_causeway(cv, B4["haze"], sky1, random.Random(seed_of("R01:causeway")))
    cv.wk = 1.0


def back_b4():
    """Band 4: the whole sea (its marks, the headland and the lit lighthouse) turned 3 degrees
    about the jetty's end, rising toward the station. The sky, the causeway and the bell's
    calm stay level, as does everything in the foreground. One plain horizon line."""
    name = "back_b4"
    r = random.Random(seed_of(f"{name}.png"))
    sky0, sky1, sea0, sea1 = b4_colours()
    cv = Cv(r, bg=sky0)
    cv.hrows(0, H, sky0, sky1, ya=0, yb=HORIZON + 20)
    cv.hrows(560, H, mix(sea0, sea1, 0.25), sea1, ya=560, yb=H)   # under the turned sea's corners
    paint_clouds(cv, mix(sky0, sky1, 0.5), seed_of("R01:clouds"), 250, 420, count=9, ink_a=50)
    paint_ceiling(cv, sky0, seed_of("R01:ceiling"), 220)
    sea = cv.layer()
    sea.hrows(HORIZON, H, sea0, sea1, ya=HORIZON, yb=H)
    paint_sea_texture(sea, sea0, sea1, seed_of("R01:seatex"), calm=False)
    hor = [(-200, HORIZON), (W + 200, HORIZON)]
    sea.stroke(hor, 2.0, mix(sea0, PAPER, 0.35), alpha=150, jitter=0.05)
    sea.stroke([(x, y + 2) for x, y in hor], 1.4, INK, alpha=90, jitter=0.05)
    land = mix(mix(STORM, COPPER, 0.45), sky1, B4["haze"])
    sea.wk = 0.6
    paint_headland(sea, land, 255 - int(255 * B4["haze"]), mix(COPPER, sky1, B4["haze"]),
                   random.Random(seed_of("R01:headland")))
    sea.wk = 0.8
    paint_lighthouse(sea, "lit", B4["haze"] * 0.6, sky1)
    turned = sea.im.rotate(-TILT_DEG, resample=Image.BICUBIC,
                           center=(TILT_PIVOT[0] * S, TILT_PIVOT[1] * S))
    cv.im.alpha_composite(turned)
    b4_level(cv)
    return cv.finish(name, "RGB", r)


def ov_b4_level():
    """Laid over the turned wave frames so the calm and the causeway stay level and clean."""
    name = "b4_level"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    b4_level(cv)
    return cv.finish(name, "RGBA", r)


# =================================================================== the chart room in the boat
R03_WALL = (163, 181, 161)
R03_TEAL = (44, 83, 99)
R03_BONE = (230, 223, 202)
R03_FELT = (72, 96, 90)


def boat_window_chart_base(cv, r):
    """The lens on the boat's lit window, and through it R03, the chart room: the station
    plan in its frame, the registration frame with the clipped composite chart, the brass
    recorder. Ada's chart room, in a boat that was never here."""
    cv.box(0, 0, W, H, INK)
    tex = cv.layer()
    for i in range(500):
        x, y = r.uniform(0, W), r.uniform(0, H)
        tex.stroke([(x, y), (x + r.uniform(20, 70), y + r.uniform(-2, 2))], 1.2,
                   mix(INK, SEAGLASS, 0.25), jitter=0.05)
    cv.comp(tex, 0.25)
    inside = cv.layer()
    for k, y in enumerate(range(80, 1010, 44)):
        inside.box(260, y, 1200, y + 44, (52, 66, 76) if k % 2 == 0 else (46, 60, 70))
        inside.stroke([(260, y), (1200, y)], 2.0, INK, alpha=220)
    # the room: sea-glass wall, teal wainscot, dado and picture rails
    wall = mix(R03_WALL, AMBER, 0.12)
    inside.box(404, 280, 1044, 566, wall)
    inside.box(404, 566, 1044, 680, R03_TEAL)
    for x in range(420, 1044, 34):
        inside.stroke([(x, 570), (x, 680)], 1.2, mix(R03_TEAL, INK, 0.45), alpha=200, jitter=0.03)
    inside.box(404, 560, 1044, 568, mix(R03_TEAL, INK, 0.35))
    inside.box(404, 300, 1044, 304, mix(R03_TEAL, INK, 0.25))
    glow(inside, lambda d: d.ellipse([560 * S, 270 * S, 880 * S, 470 * S], fill=255), AMBER, 50, 0.3)
    # the station plan, framed, at left
    inside.rect(418, 318, 536, 470, fill=(80, 71, 62), ink=INK, w=2.2)
    inside.rect(428, 328, 526, 460, fill=R03_BONE, ink=INK, w=1.4)
    for bx0, by0, bx1, by1 in ((440, 340, 466, 354), (488, 340, 514, 354), (462, 362, 488, 392),
                               (440, 398, 462, 420), (468, 398, 496, 420), (502, 398, 514, 420),
                               (454, 428, 500, 450)):
        inside.rect(bx0, by0, bx1, by1, fill=None, ink=mix(INK, R03_BONE, 0.25), w=1.2)
    inside.stroke([(475, 392), (475, 398)], 1.0, mix(INK, R03_BONE, 0.25))
    inside.stroke([(475, 420), (475, 428)], 1.0, mix(INK, R03_BONE, 0.25))
    # the registration frame on its table, the composite chart clipped in it
    inside.rect(548, 556, 896, 566, fill=(103, 93, 81), ink=INK, w=1.8)          # table top
    for lgx in (562, 876):
        inside.rect(lgx, 566, lgx + 10, 680, fill=(80, 71, 62), ink=INK, w=1.6)
    inside.rect(556, 322, 888, 552, fill=BRASS, ink=INK, w=2.2)                  # brass frame
    inside.rect(566, 332, 878, 542, fill=R03_BONE, ink=INK, w=1.4)               # table sheet
    inside.rect(584, 346, 870, 530, fill=mix(R03_BONE, SEAGLASS, 0.18), ink=mix(INK, R03_BONE, 0.4),
                w=1.0)                                                           # Venn's sheet over it
    inside.stroke([(722, 334), (722, 540)], 0.9, mix(INK, R03_BONE, 0.55), jitter=0.02)
    inside.stroke([(568, 437), (876, 437)], 0.9, mix(INK, R03_BONE, 0.55), jitter=0.02)
    for k, (per, ph, amp, mid) in enumerate(((150, 0.2, 10, 372), (180, 1.4, 9, 404),
                                             (140, 2.3, 11, 470), (170, 0.8, 10, 504))):
        pts = [(570 + i * 4, mid + amp * math.sin(ph + 2 * math.pi * (i * 4) / per)) for i in range(77)]
        inside.stroke(pts, 1.2, mix(SEAGLASS, INK, 0.3), alpha=200, jitter=0.03)
    # the curve on neither sheet alone, in ink, heavier
    pts = [(572 + i * 4, 448 + 34 * math.sin(0.6 + 2 * math.pi * (i * 4) / 230)) for i in range(76)]
    inside.stroke(pts, 2.6, INK, jitter=0.04)
    for (cx, cy) in ((576, 342), (868, 342), (576, 532), (868, 532)):
        inside.ell(cx, cy, 3.2, 3.2, fill=mix(BRASS, INK, 0.3), ink=None)
    # top rail and the spring clip, a paper tag hanging off it
    inside.rect(548, 308, 896, 314, fill=BRASS, ink=INK, w=1.6)
    inside.ell(548, 311, 5, 5, fill=BRASS, ink=INK, w=1.4)
    inside.ell(896, 311, 5, 5, fill=BRASS, ink=INK, w=1.4)
    inside.rect(800, 300, 840, 336, fill=mix(BRASS, PAPER, 0.15), ink=INK, w=1.8)
    inside.ell(820, 300, 9, 7, fill=None, ink=mix(INK, BRASS, 0.3), w=1.6)
    inside.poly([(846, 318), (866, 322), (862, 348), (842, 344)], R03_BONE, INK, 1.4)
    # the brass recorder at right: green cabinet, paper window, two dials, lever
    inside.rect(910, 330, 1052, 690, fill=R03_FELT, ink=INK, w=2.2)
    inside.rect(904, 324, 1058, 334, fill=mix(R03_FELT, SEAGLASS, 0.25), ink=INK, w=1.6)
    for rx in range(918, 1050, 16):
        inside.ell(rx, 329, 1.6, 1.6, fill=INK, ink=None)
    inside.rect(922, 346, 1040, 404, fill=(40, 50, 60), ink=INK, w=1.6)
    inside.rect(928, 350, 1036, 386, fill=R03_BONE, ink=BRASS, w=3.0)
    for gx in range(934, 1034, 10):
        inside.stroke([(gx, 352), (gx, 384)], 0.6, mix(R03_BONE, SEAGLASS, 0.5), jitter=0.0)
    inside.stroke([(932, 372), (950, 368), (968, 375), (986, 366), (1004, 371), (1022, 369), (1034, 370)],
                  1.6, INK, jitter=0.05)
    inside.rect(930, 390, 1032, 400, fill=R03_BONE, ink=INK, w=1.0)
    inside.rect(934, 418, 1028, 438, fill=BRASS, ink=INK, w=1.6)
    for dx in (946, 1012):
        inside.ell(dx, 474, 16, 16, fill=R03_BONE, ink=BRASS, w=3.0)
        inside.stroke([(dx, 474), (dx + 8, 466)], 1.4, INK, jitter=0.0)
    inside.rect(934, 512, 1028, 560, fill=mix(R03_FELT, INK, 0.25), ink=INK, w=1.6)
    for k in range(3):
        inside.rect(940 + k * 30, 518, 964 + k * 30, 554, fill=(20, 26, 34), ink=BRASS, w=1.6)
    inside.rect(1034, 440, 1042, 540, fill=BRASS, ink=INK, w=1.4)                 # lever
    inside.rect(1030, 432, 1046, 442, fill=mix(BRASS, PAPER, 0.4), ink=INK, w=1.4)
    # the hanging cone lamp over the frame
    inside.stroke([(722, 280), (722, 290)], 2.0)
    inside.poly([(702, 290), (742, 290), (756, 306), (688, 306)], BRASS, INK, 1.8)
    inside.ell(722, 308, 8, 3.5, fill=mix(AMBER, PAPER, 0.6), ink=None)
    # brass window frame, rivets, the teak sill and its shadow (as the plain window)
    inside.rect(392, 268, 1056, 692, fill=None, ink=BRASS, w=12)
    inside.rect(386, 262, 1062, 698, fill=None, ink=INK, w=2.4)
    inside.rect(404, 280, 1044, 680, fill=None, ink=INK, w=2.4)
    for (x, y) in ((396, 272), (1052, 272), (396, 688), (1052, 688), (724, 272), (724, 688)):
        inside.ell(x, y, 3.4, 3.4, fill=mix(BRASS, INK, 0.3), ink=None)
    sill = mix(TIMBER, PAPER, 0.12)
    sh = inside.layer()
    sh.box(380, 716, 1068, 736, INK)
    inside.comp(sh, 0.35)
    inside.rect(372, 698, 1076, 718, fill=sill, ink=None)
    wood_grain(inside, r, 372, 700, 1076, 718, sill, vertical=False, lines=3, knots=False, alpha=0.6)
    inside.box(372, 698, 1076, 702, mix(sill, PAPER, 0.35))
    inside.rect(372, 698, 1076, 718, fill=None, ink=INK, w=2.4)
    m = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(m).ellipse([(724 - 400) * S, (540 - 400) * S, (724 + 400) * S, (540 + 400) * S], fill=255)
    cv.comp(inside, mask=m)


def c_boat_window_chart():
    name = "c_boat_window_chart"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    boat_window_chart_base(cv, r)
    glass_sheen(cv)
    lens_ring(cv, r)
    return cv.finish(name, "RGB", r)

# =================================================================== registry
def _bd(name, *a, **k):
    return lambda: backdrop(name, *a, **k)


ASSETS = {
    "back_b0": _bd("back_b0", hexc("#8FA3A6"), hexc("#A9B5B0"), hexc("#617D74"), hexc("#4E6A66")),
    "back_b0_dusk": back_b0_dusk,
    "reflections_dusk": ov_reflections_dusk,
    "dusk_lamps": ov_dusk_lamps,
    "waves_dusk_0": lambda: wave_frame(0, "waves_dusk", DUSK_WAVE, 0.75, hull_gap=False),
    "waves_dusk_1": lambda: wave_frame(1, "waves_dusk", DUSK_WAVE, 0.75, hull_gap=False),
    "waves_dusk_2": lambda: wave_frame(2, "waves_dusk", DUSK_WAVE, 0.75, hull_gap=False),
    "back_b1": _bd("back_b1", hexc("#7D8E92"), mix(hexc("#7D8E92"), PAPER, 0.12), hexc("#557069"),
                   mix(hexc("#557069"), INK, 0.2), haze=0.3, ceiling=220, cloud_band=(250, 420)),
    "back_b2": _bd("back_b2", hexc("#64767C"), mix(hexc("#64767C"), PAPER, 0.08), hexc("#3F5759"),
                   mix(hexc("#3F5759"), INK, 0.25), haze=0.42, ceiling=220, cloud_band=(250, 420),
                   cloud_ink=50),
    "back_b3": _bd("back_b3", hexc("#5A6B72"), mix(hexc("#5A6B72"), PAPER, 0.07), hexc("#3A5052"),
                   mix(hexc("#3A5052"), INK, 0.25), haze=0.45, ceiling=220, cloud_band=(250, 420),
                   cloud_ink=50),
    "back_b4": back_b4,
    "b4_level": ov_b4_level,
    "back_b5": _bd("back_b5", hexc("#4A5A62"), hexc("#4E5E66"), hexc("#4E5E66"), hexc("#4A5A62"),
                   haze=0.85, land_haze=0.4, hor_alpha=0.25, lighthouse=None, cloud_count=0),
    "back_b7": back_b7,
    "back_end_a": _bd("back_end_a", hexc("#B9C2BE"), mix(hexc("#B9C2BE"), PAPER, 0.25), hexc("#6E8780"),
                      hexc("#57716B"), lighthouse="off", gulls=True, cloud_band=(110, 380), calm=False),
    "fg_jetty": fg_jetty,
    "line": ov_line,
    "gangway_up": ov_gangway_up,
    "gangway_down": ov_gangway_down,
    "reflections": ov_reflections,
    "bell_calm": ov_bell_calm,
    "waves_0": lambda: wave_frame(0),
    "waves_1": lambda: wave_frame(1),
    "waves_2": lambda: wave_frame(2),
    "launch_departing": ov_launch_departing,
    "boat": ov_boat,
    "boat_window_lit": ov_boat_window_lit,
    "figure_window": lambda: ov_figure_window(False),
    "figure_window_turned": lambda: ov_figure_window(True),
    "launch_real": ov_launch_real,
    "station_lamp": ov_station_lamp,
    "station_window_figure": ov_station_window_figure,
    "lighthouse_roof": ov_lighthouse_roof,
    "stump": ov_stump,
    "mist_far": ov_mist_far,
    "rain_light_0": lambda: ov_rain("rain_light_0", 700, 9, 0.35),
    "rain_light_1": lambda: ov_rain("rain_light_1", 700, 9, 0.35),
    "rain_heavy_0": lambda: ov_rain("rain_heavy_0", 2400, 14, 0.45),
    "rain_heavy_1": lambda: ov_rain("rain_heavy_1", 2400, 14, 0.45),
    "surface_drift": ov_surface_drift,
    "ada_door": ov_ada_door,
    "capsule_closed": lambda: ov_capsule(False),
    "capsule_open": lambda: ov_capsule(True),
    "c_mooring_panel": c_mooring_panel,
    "c_panel_tally_v": lambda: c_panel_tally("v"),
    "c_panel_tally_u": lambda: c_panel_tally("u"),
    "c_panel_pull_down": c_panel_pull_down,
    "c_boat_window": c_boat_window,
    "c_boat_window_figure": lambda: c_boat_window_figure(False),
    "c_boat_window_figure_turned": lambda: c_boat_window_figure(True),
    "c_boat_window_chart": c_boat_window_chart,
    "c_boat_window_chart_figure": lambda: c_boat_window_figure(False, "c_boat_window_chart"),
    "c_boat_window_chart_figure_turned": lambda: c_boat_window_figure(True, "c_boat_window_chart"),
    "c_capsule": c_capsule,
    "c_capsule_open": c_capsule_open,
    "c_capsule_key": c_capsule_key,
    "c_capsule_note": c_capsule_note,
}


def main(argv):
    names = argv or list(ASSETS)
    unknown = [n for n in names if n not in ASSETS]
    if unknown:
        raise SystemExit(f"unknown R01 assets: {unknown}")
    for n in names:
        ASSETS[n]()
        print(f"  R01/{n}.png")


if __name__ == "__main__":
    main(sys.argv[1:])
