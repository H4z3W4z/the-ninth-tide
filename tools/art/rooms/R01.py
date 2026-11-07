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
            ww = max(1, int(round(w * (1 + self.r.uniform(-0.1, 0.1)) * S)))
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


# =================================================================== backdrops
HEADLAND = [(1060, 470), (1078, 466), (1098, 459), (1118, 450), (1138, 441), (1156, 435),
            (1170, 432), (1260, 432), (1270, 436), (1280, 446), (1288, 458), (1296, 470)]
SKERRY = [(1384, 470), (1392, 464), (1406, 461), (1424, 459), (1448, 457), (1448, 470)]
CAUSEWAY_GAPS = [(560, 600), (740, 790), (900, 950)]


def h_tilt(x, tilt):
    return HORIZON + tilt * (x - 1205)


def paint_clouds(cv, sky, lay_seed, y_lo, y_hi, dark=0.22, light=0.22, ink_a=70, count=9):
    """Flat strata clouds as in the approved window: scalloped tops, flat bellies a shade darker,
    a fine ink contour round the whole bank."""
    r = random.Random(lay_seed)
    body = Image.new("L", (W * S, H * S), 0)
    belly = Image.new("L", (W * S, H * S), 0)
    bd, ld = ImageDraw.Draw(body), ImageDraw.Draw(belly)
    for i in range(count):
        cy = r.uniform(y_lo, y_hi)
        cx = r.uniform(-60, W + 60)
        wid = r.uniform(200, 460) * (0.7 + 0.5 * (cy - y_lo) / max(1, y_hi - y_lo))
        n = r.randint(3, 6)
        x0 = cx - wid / 2
        for k in range(n):
            t = (k + 0.5) / n
            rx = wid / n * r.uniform(0.62, 0.9)
            ry = rx * r.uniform(0.45, 0.7) * (0.6 + 0.6 * math.sin(t * math.pi))
            ex = x0 + t * wid
            bd.ellipse([(ex - rx) * S, (cy - 2 * ry) * S, (ex + rx) * S, cy * S], fill=255)
        bd.rectangle([(x0 + 6) * S, (cy - 12) * S, (x0 + wid - 6) * S, cy * S], fill=255)
        ld.rectangle([(x0 - 80) * S, (cy - 9) * S, (x0 + wid + 80) * S, cy * S], fill=255)
    belly = ImageChops.multiply(belly, body)
    ring = ImageChops.subtract(body.filter(ImageFilter.MaxFilter(5)), body)
    for mask, col, a in ((body, mix(sky, PAPER, light), 255), (belly, mix(sky, STORM, dark), 255),
                         (ring, INK, ink_a)):
        lay = Image.new("RGBA", (W * S, H * S), col + (0,))
        lay.putalpha(mask.point(lambda v, a=a: v * a // 255))
        cv.im.alpha_composite(lay)


def paint_ceiling(cv, sky, lay_seed, y_bottom):
    r = random.Random(lay_seed)
    tone = mix(sky, STORM, 0.32)
    pts = [(-10, -10), (W + 10, -10)]
    edge = []
    x = W + 10
    while x > -20:
        edge.append((x, y_bottom + r.uniform(-14, 10)))
        x -= r.uniform(50, 110)
    sm = smooth(edge, 6)
    cv.fillpoly(pts + sm, tone)
    # scalloped underside: a second, lighter rank of bellies
    for (x0, y0), (x1, y1) in zip(edge, edge[1:]):
        cx = (x0 + x1) / 2
        cy = (y0 + y1) / 2
        cv.ell(cx, cy - 4, abs(x0 - x1) / 2 + 6, 12, fill=mix(tone, STORM, 0.15), ink=None)
    cv.stroke(sm, 1.8, INK, alpha=110)
    # rain veils from the ceiling (static, faint)
    for i in range(26):
        vx = r.uniform(0, W)
        vw = r.uniform(30, 90)
        lay = cv.layer()
        lay.fillpoly([(vx, y_bottom - 4), (vx + vw, y_bottom - 4), (vx + vw - 18, HORIZON - 2),
                      (vx - 18, HORIZON - 2)], mix(tone, STORM, 0.2))
        cv.comp(lay, 0.12)


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
        glow(cv, lambda d: d.ellipse([1186 * S, 302 * S, 1234 * S, 360 * S], fill=255), AMBER, 22, 0.55)
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


def paint_sea_texture(cv, sea0, sea1, lay_seed, tilt=0.0, x_from=0):
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
    cv.comp(dark, 0.45)
    cv.comp(light, 0.35)


def backdrop(name, sky0, sky1, sea0, sea1, *, haze=0.0, lighthouse="lit", causeway=True,
             headland=True, tilt=0.0, ceiling=None, cloud_band=(120, 400), cloud_count=9,
             cloud_ink=70, gulls=False, land=None, land_haze=None, hor_alpha=1.0):
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
    cv.stroke(hor, 2.0, mix(sea0, PAPER, 0.35), alpha=int(150 * hor_alpha), jitter=0.05)
    cv.stroke([(x, y + 2) for x, y in hor], 1.4, INK, alpha=int(90 * hor_alpha), jitter=0.05)
    sky_hor = sky1
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
        paint_lighthouse(cv, lighthouse, haze * 0.6, sky_hor)
    return cv.finish(name, "RGB", r)


def back_b7():
    name = "back_b7"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r, bg=STORM)
    cv.hrows(0, 140, mix(STORM, INK, 0.3), STORM)
    paint_clouds(cv, STORM, seed_of("R01:clouds"), 30, 120, dark=0.3, light=0.08, ink_a=50, count=5)
    surf = hexc("#1E2A33")
    # the surface: top edge almost straight, very slightly bowed, as if too large to curve
    top = [(x, 140 + 3.0 * math.sin(math.pi * x / W)) for x in range(-10, W + 20, 40)]
    cv.fillpoly(top + [(W + 10, 868), (-10, 868)], surf)
    # faint vertical grain
    # light catching the top of something upright and immense
    lit = cv.layer()
    lit.hrows(142, 330, mix(surf, SEAGLASS, 0.16), surf)
    tm = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(tm).polygon(Cv.P(top + [(W + 10, 330), (-10, 330)]), fill=255)
    cv.comp(lit, mask=tm)
    g = cv.layer()
    for i in range(300):
        x = r.uniform(0, W)
        y0 = r.uniform(146, 500)
        ln = r.uniform(240, 720)
        col = mix(surf, SEAGLASS, 0.12) if r.random() < 0.25 else mix(surf, INK, 0.55)
        g.stroke([(x, y0), (x + r.uniform(-0.6, 0.6), min(866, y0 + ln))], r.uniform(0.8, 1.4), col, jitter=0.03)
    cv.comp(g, 0.35)
    # very large, very faint vertical pleats (it is not flat; it is too big to be anything else)
    p = cv.layer()
    for k in range(6):
        cx = 120 + k * 250 + r.uniform(-30, 30)
        p.fillpoly([(cx - 40, 150), (cx + 40, 150), (cx + 46, 866), (cx - 46, 866)], mix(surf, INK, 0.6))
    cv.comp(p, 0.18)
    cv.stroke(top, 2.4, mix(surf, SEAGLASS, 0.35), alpha=170, jitter=0.04)
    # calm dark near-water strip
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
        cv.box(x, 560, x + wdt, 922, plank_a if k % 2 == 0 else plank_b)
        if x > 40:
            cv.stroke([(x, 566), (x + r.uniform(-0.5, 0.5), 920)], 1.4, INK, alpha=180, jitter=0.06)
        for ny in (578, 900):
            cv.ell(x + wdt / 2, ny + r.uniform(-2, 2), 1.6, 1.6, fill=SOOT, ink=None)
        # weathering: a few long darker streaks under the eaves
        if r.random() < 0.5:
            cv.box(x + 4, 566, x + 7, 566 + r.uniform(30, 120), mix(plank_a, INK, 0.25), alpha=160)
        x += wdt
        k += 1
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


def paint_jetty(cv, r):
    deck = (138, 124, 104)
    deck_top = mix(deck, PAPER, 0.35)
    post = (118, 106, 90)
    # pilings (above water) and their submerged parts
    sub = cv.layer()
    for cx in PILINGS:
        x0, x1 = cx - 13, cx + 13
        cv.rect(x0, 780, x1, 870, fill=(112, 100, 85), ink=None)
        cv.box(x0, 780, x0 + 5, 870, mix((112, 100, 85), PAPER, 0.28))
        cv.box(x1 - 6, 780, x1, 870, mix((112, 100, 85), INK, 0.3))
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
        # submerged: tinted toward the sea, fading out by y940
        sub.box(x0 + 1, 870, x1 - 1, 940, mix((112, 100, 85), (78, 106, 102), 0.55))
    m = Image.new("L", (W * S, H * S), 0)
    md = ImageDraw.Draw(m)
    for row in range(870 * S, 940 * S):
        md.line([(0, row), (W * S, row)], fill=int(150 * (1 - (row / S - 870) / 70) ** 1.3))
    cv.comp(sub, mask=m)
    # deck front band
    cv.rect(430, 752, 1360, 780, fill=deck, ink=None)
    cv.box(430, 752, 1360, 757, deck_top)
    x = 430
    while x < 1360:
        x += r.uniform(60, 90)
        if x < 1356:
            cv.stroke([(x, 758), (x, 779)], 1.2, INK, alpha=170)
    for cx in PILINGS:
        cv.ell(cx, 768, 2.4, 2.4, fill=SOOT, ink=None)
    cv.rect(430, 752, 1360, 780, fill=None, ink=INK, w=2.6)
    cv.stroke([(432, 757), (1358, 757)], 1.2, INK, alpha=150)
    # handrail and stanchions
    stanch = [434] + PILINGS + [1356]
    for sx in stanch:
        cv.rect(sx - 3, 702, sx + 3, 752, fill=post, ink=INK, w=1.8)
    cv.rect(430, 697, 1360, 703, fill=mix(post, PAPER, 0.25), ink=INK, w=1.8)
    # bell post, arm, brace
    cv.rect(633, 600, 647, 752, fill=post, ink=INK, w=2.2)
    cv.box(634, 601, 638, 751, mix(post, PAPER, 0.25))
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
    # cleat x1316-1344, y740-752
    cv.poly([(1316, 746), (1320, 742), (1340, 742), (1344, 746), (1344, 748), (1316, 748)],
            mix(SOOT, STORM, 0.4), INK, 1.8)
    cv.rect(1324, 747, 1336, 752, fill=mix(SOOT, STORM, 0.4), ink=INK, w=1.6)
    cv.stroke([(1320, 742.6), (1340, 742.6)], 1.2, mix(SEAGLASS, PAPER, 0.4))


def paint_bell(cv):
    cx = 700
    cv.rect(692, 798, 708, 808, fill=mix(BRASS, INK, 0.25), ink=INK, w=1.8)
    prof = [(808, 17), (816, 19), (826, 20), (838, 21), (848, 23), (856, 26), (862, 29), (867, 31), (872, 32)]
    right = [(cx + w, y) for y, w in prof]
    left = [(cx - w, y) for y, w in reversed(prof)]
    body = smooth(right, 4) + smooth(left, 4)
    cv.fillpoly(body, BRASS)
    # patina streaks and a shoulder highlight
    lay = cv.layer()
    for (x, w) in ((682, 4), (694, 3), (716, 5)):
        lay.fillpoly([(x, 812), (x + w, 812), (x + w + 2, 866), (x - 1, 866)], COPPER)
    cv.comp(lay, 0.7)
    cv.fillpoly([(684, 816), (689, 812), (686, 860), (680, 864)], mix(BRASS, PAPER, 0.45))
    cv.rect(668, 864, 732, 872, fill=mix(BRASS, INK, 0.2), ink=None)
    cv.stroke(body, 2.4, INK, closed=True)
    cv.stroke([(669, 864), (731, 864)], 1.6, INK)
    # the 2 px of lip under the waterline: tinted, not rippled
    cv.box(668, 870, 733, 873, (84, 110, 104), alpha=200)


def fg_jetty():
    name = "fg_jetty"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    paint_station(cv, r)
    window_bars(cv, 110, 340)
    window_bars(cv, 190, 340)
    window_bars(cv, 70, 446, 40, 44)
    paint_land(cv, r)
    paint_shed(cv, r)
    paint_jetty(cv, r)
    return cv.finish(name, "RGBA", r)


# =================================================================== overlays part 1
def ov_line():
    name = "line"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    rope = mix(TIMBER, PAPER, 0.15)
    cv.box(1338, 748, 1342, 870, rope)
    for y in range(752, 870, 7):
        cv.stroke([(1338, y), (1342, y + 4)], 1.0, INK, alpha=210, jitter=0.02)
    cv.stroke([(1337.5, 748), (1337.5, 870)], 1.4, INK, jitter=0.03)
    cv.stroke([(1342.5, 748), (1342.5, 870)], 1.4, INK, jitter=0.03)
    cv.ell(1340, 748, 5, 3, fill=rope, ink=INK, w=1.4)  # the turn on the cleat
    sub = cv.layer()
    sub.box(1338, 870, 1342, 990, mix(PAPER, SEAGLASS, 0.5))
    m = Image.new("L", (W * S, H * S), 0)
    md = ImageDraw.Draw(m)
    for row in range(870 * S, 990 * S):
        md.line([(0, row), (W * S, row)], fill=int(170 * (1 - (row / S - 870) / 120)))
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
    cv.comp(ink_l, 0.55)
    cv.comp(pap_l, 0.4)
    return cv.finish(name, "RGBA", r)


def ov_bell_calm():
    """Still water round the bell: no strokes, a faint glassy darkening and two mirror-flat
    hairlines. Low alpha so it takes each band's own sea tone."""
    name = "bell_calm"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    m = blur_mask(lambda d: d.ellipse([650 * S, 822 * S, 750 * S, 922 * S], fill=255), 3)
    lay = Image.new("RGBA", (W * S, H * S), INK + (0,))
    lay.putalpha(m.point(lambda v: v * 60 // 255))
    cv.im.alpha_composite(lay)
    sheen = cv.layer()
    for dy, half in ((-22, 26), (12, 40), (30, 30)):
        sheen.stroke([(700 - half, 872 + dy), (700 + half, 872 + dy)], 1.4, PAPER, jitter=0.0)
    cv.comp(sheen, 0.3)
    return cv.finish(name, "RGBA", r)


def wave_frame(k):
    name = f"waves_{k}"
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
        # keep the bell disc and the hull's waterline clean
        nx = clamp(700, x0, x1)
        if math.hypot(nx - 700, y - 872) < 56:
            continue
        if x1 > 856 and x0 < 1294 and 856 < y < 884:
            continue
        sag = 0.6 + t * 2.2
        pts = smooth([(x0, y + sag * 0.3), (x0 + ln * 0.3, y - sag), (x0 + ln * 0.7, y - sag * 0.7),
                      (x1, y + sag * 0.2)], 4)
        lay.stroke(pts, 1.0 + t * 1.8, PAPER, jitter=0.06)
    cv.comp(lay, 0.5)
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
    cv.fillpoly(hull_pts, hull)
    cv.box(880, 862, 1290, 870, mix(TIMBER, SOOT, 0.4))  # boot top
    cv.fillpoly([(864, 784), (1290, 784), (1290, 792), (868, 792)], strake)  # sheer strake
    for y in (808, 828, 848):
        cv.stroke([(870 + (y - 780) * 0.5, y), (1288, y)], 1.2, mix(hull, INK, 0.45), alpha=200, jitter=0.04)
    cv.rect(858, 776, 1294, 781, fill=mix(TIMBER, PAPER, 0.2), ink=INK, w=1.8)  # gunwale rail
    cv.stroke(hull_pts, 2.6, INK, closed=True)
    cv.stroke([(864, 784), (1290, 784)], 1.4, INK)
    cv.stroke([(868, 792), (1290, 792)], 1.4, INK)
    # cabin x960-1120 y680-780
    cv.rect(960, 686, 1120, 776, fill=cabin, ink=INK, w=2.4)
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
    cv.ell(1040, 724, 6.5, 8, fill=PAPER if turned else body, ink=INK if turned else None, w=1.0)
    if turned:
        cv.ell(1037.6, 723, 0.9, 0.9, fill=INK, ink=None)
        cv.ell(1042.4, 723, 0.9, 0.9, fill=INK, ink=None)
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
    name = "station_window_figure"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    body = (30, 34, 38)
    cv.rect(112, 384, 168, 388, fill=mix(TIMBER, INK, 0.4), ink=None)  # desk edge
    # bowed seated figure facing us: back hunched, head down over the page
    cv.fillpoly(smooth([(124, 386), (124, 376), (130, 366), (140, 362), (150, 366), (156, 376), (156, 386)], 4), body)
    cv.ell(140, 361, 5.5, 5.0, fill=body, ink=None)
    # its left arm (our right) bent to the page, pen in hand
    cv.stroke([(153, 368), (160, 378), (152, 384)], 3.2, body, jitter=0.02)
    cv.stroke([(152, 384), (148, 378)], 1.2, PAPER)
    # the right arm (our left) lies still along the desk
    cv.stroke([(127, 372), (124, 383), (136, 384)], 3.0, body, jitter=0.02)
    cv.rect(132, 382, 150, 385, fill=PAPER, ink=None)
    window_bars(cv, 110, 340)
    return cv.finish(name, "RGBA", r)


def ov_lighthouse_roof():
    name = "lighthouse_roof"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    glow(cv, lambda d: d.ellipse([150 * S, 150 * S, 190 * S, 206 * S], fill=255), AMBER, 18, 0.55)
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
    cv.rect(1402, 838, 1428, 870, fill=(112, 100, 85), ink=None)
    cv.box(1402, 838, 1407, 870, mix((112, 100, 85), PAPER, 0.28))
    cv.box(1422, 838, 1428, 870, mix((112, 100, 85), INK, 0.3))
    cv.fillpoly([(1402, 870), (1402, 856), (1407, 851), (1412, 855), (1417, 850), (1422, 854), (1428, 852),
                 (1428, 870)], (62, 74, 60))
    cv.rect(1401, 835, 1429, 841, fill=(226, 206, 160), ink=None)  # fresh-cut top, pale
    cv.stroke([(1406, 838), (1424, 838)], 0.9, mix(TIMBER, PAPER, 0.4))
    cv.rect(1402, 836, 1428, 870, fill=None, ink=INK, w=2.4)
    lay = cv.layer()
    for k, y in enumerate((874, 884, 896, 908)):
        off = 4 * math.sin(k * 1.9)
        lay.stroke([(1402 + off, y), (1428 + off, y + 0.6)], 2.2 - k * 0.3, INK)
        lay.stroke([(1406 - off, y + 4), (1420 - off, y + 4.4)], 1.4, PAPER)
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
    name = "surface_drift"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    lay = cv.layer()
    lay.box(790, 140, 1010, 868, BRUISE)
    m = Image.new("L", (W * S, H * S), 0)
    md = ImageDraw.Draw(m)
    for row in range(140 * S, 868 * S):
        y = row / S
        a = min(1.0, (y - 140) / 60, (868 - y) / 40)
        md.line([(790 * S, row), (1010 * S, row)], fill=int(255 * 0.22 * max(0, a)))
    cv.comp(lay, mask=m)
    edge = cv.layer()
    edge.box(790, 160, 793, 852, mix(BRUISE, INK, 0.35))
    edge.box(1007, 160, 1010, 852, mix(BRUISE, INK, 0.35))
    cv.comp(edge, 0.5)
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


def paint_capsule_small(cv, open_):
    rope = mix(TIMBER, PAPER, 0.15)
    cv.box(1338, 752, 1342, 776, rope)
    cv.stroke([(1337.5, 752), (1337.5, 776)], 1.2)
    cv.stroke([(1342.5, 752), (1342.5, 776)], 1.2)
    cv.stroke(smooth([(1330, 786), (1340, 774), (1350, 786)], 4), 1.6, mix(BRASS, INK, 0.3))  # bail
    cv.rect(1328, 784, 1352, 856, fill=BRASS, ink=None)
    cv.box(1331, 788, 1335, 852, mix(BRASS, PAPER, 0.6))   # wet-bright highlight
    cv.box(1346, 788, 1349, 852, mix(BRASS, INK, 0.3))
    cv.rect(1328, 784, 1352, 856, fill=None, ink=INK, w=1.8)
    cv.ell(1340, 852, 12, 4, fill=mix(BRASS, INK, 0.2), ink=INK, w=1.4)
    if open_:
        cv.ell(1340, 784, 12, 4, fill=SOOT, ink=INK, w=1.6)
        cv.stroke([(1352, 784), (1360, 786), (1366, 788)], 1.2, mix(INK, BRASS, 0.3))
        cv.rect(1356, 786, 1378, 800, fill=BRASS, ink=INK, w=1.6)
        for kx in range(1360, 1376, 4):
            cv.stroke([(kx, 788), (kx, 798)], 0.9, INK, alpha=200)
    else:
        cv.rect(1326, 772, 1354, 786, fill=mix(BRASS, PAPER, 0.15), ink=INK, w=1.8)
        for kx in range(1330, 1352, 4):
            cv.stroke([(kx, 774), (kx, 784)], 0.9, INK, alpha=200)
    # droplets: wet but clean
    for (x, y) in ((1333, 830), (1344, 844), (1336, 860)):
        cv.ell(x, y, 1.2, 1.8, fill=mix(PAPER, SEAGLASS, 0.2), ink=None)


def ov_capsule(open_):
    name = "capsule_open" if open_ else "capsule_closed"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    paint_capsule_small(cv, open_)
    return cv.finish(name, "RGBA", r)


# =================================================================== close-ups
def plank_wall(cv, r, base=(124, 114, 100), alt=(116, 106, 93), w=92):
    x = 0
    k = 0
    while x < W:
        wd = w + r.uniform(-6, 8)
        cv.box(x, 0, x + wd, H, base if k % 2 == 0 else alt)
        cv.stroke([(x, 0), (x + r.uniform(-1, 1), H)], 2.4, INK, alpha=200)
        for ny in (60, 1020):
            cv.ell(x + wd / 2, ny + r.uniform(-6, 6), 4, 4, fill=SOOT, ink=INK, w=1.2)
        for g in range(3):
            gx = x + r.uniform(10, wd - 10)
            gy = r.uniform(0, H - 200)
            cv.stroke([(gx, gy), (gx + r.uniform(-2, 2), gy + r.uniform(80, 240))], 1.2,
                      mix(base, INK, 0.35), alpha=160)
        x += wd
        k += 1


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
    for (sx, sy) in ((x + 10, y + 10), (x + w - 10, y + 10), (x + 10, y + h - 10), (x + w - 10, y + h - 10)):
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
    for (x, y) in ((256, 122), (1192, 122), (256, 958), (1192, 958), (724, 122), (724, 958)):
        cv.ell(x, y, 5, 5, fill=mix(BRASS, INK, 0.2), ink=INK, w=1.4)
    # blank enamel header strip
    cv.rect(300, 140, 1148, 204, fill=PAPER, ink=INK, w=2.4)
    cv.stroke([(306, 147), (1142, 147)], 1.2, mix(PAPER, INK, 0.2))
    paint_plate(cv, PLATE_V, "v")
    paint_plate(cv, PLATE_U, "u")
    # the placard under two brass clips Rect2(324,520,800,210)
    sh = cv.layer()
    sh.box(330, 528, 1132, 738, INK)
    cv.comp(sh, 0.4)
    cv.rect(324, 520, 1124, 730, fill=mix(PAPER, (230, 222, 200), 0.4), ink=INK, w=2.2)
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
    inside.stroke(curve(205, 1.9, 18, 572), 2.0, INK, jitter=0.04)
    for i in range(0, 81, 2):  # the second ink curve is dashed: two hands, one chart
        pass
    inside.stroke(curve(97, 2.6, 30, 578), 2.6, BRUISE, jitter=0.04)
    for k in range(14):
        tx = 540 + k * 27 + r.uniform(-4, 4)
        inside.stroke([(tx, 612), (tx + 1, 622)], 1.2, (96, 96, 96))
    # brass window frame Rect2(404,280,640,400)
    inside.rect(392, 268, 1056, 692, fill=None, ink=BRASS, w=12)
    inside.rect(386, 262, 1062, 698, fill=None, ink=INK, w=2.4)
    inside.rect(404, 280, 1044, 680, fill=None, ink=INK, w=2.4)
    for (x, y) in ((396, 272), (1052, 272), (396, 688), (1052, 688), (724, 272), (724, 688)):
        inside.ell(x, y, 3.4, 3.4, fill=mix(BRASS, INK, 0.3), ink=None)
    # blank brass name board (the boat has no name)
    inside.rect(564, 726, 884, 786, fill=BRASS, ink=INK, w=2.6)
    inside.box(570, 732, 878, 738, mix(BRASS, PAPER, 0.4))
    for x in (578, 870):
        inside.ell(x, 756, 4, 4, fill=mix(BRASS, INK, 0.3), ink=INK, w=1.0)
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


def c_boat_window_figure(turned):
    name = "c_boat_window_figure_turned" if turned else "c_boat_window_figure"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    coat = (26, 32, 38)
    rim = mix(AMBER, PAPER, 0.3)
    body = smooth([(648, 640), (650, 520), (656, 440), (672, 404), (700, 392), (748, 392),
                   (772, 404), (778, 440), (776, 520), (772, 640)], 5)
    cv.fillpoly(body, coat)
    cv.box(696, 372, 726, 400, coat)  # neck
    cv.ell(711, 358, 27, 32, fill=PAPER if turned else coat, ink=INK if turned else None, w=2.0)
    if turned:
        cv.ell(702, 352, 2.6, 2.6, fill=INK, ink=None)
        cv.ell(720, 352, 2.6, 2.6, fill=INK, ink=None)
        for by in (430, 470, 510, 550, 590):
            cv.ell(712, by, 3.2, 3.2, fill=mix(coat, SEAGLASS, 0.35), ink=None)
        # arms hang, too long; pale hands with long fingers past the hem
        cv.stroke([(656, 420), (646, 520), (646, 600)], 14, coat, jitter=0.02)
        cv.stroke([(772, 420), (780, 520), (778, 600)], 14, coat, jitter=0.02)
        pale = mix(PAPER, SEAGLASS, 0.15)
        for hx in (646, 778):
            cv.poly(smooth([(hx - 7, 598), (hx + 7, 598), (hx + 7, 616), (hx - 7, 616)], 2), pale, INK, 1.2)
            for k, fx in enumerate((-5.5, -2, 1.5, 5)):
                ln = (40, 52, 50, 36)[k]
                cv.stroke([(hx + fx, 612), (hx + fx * 1.15, 612 + ln * 0.6), (hx + fx * 1.25, 612 + ln)], 3.0, INK,
                          jitter=0.02)
                cv.stroke([(hx + fx, 612), (hx + fx * 1.15, 612 + ln * 0.6), (hx + fx * 1.25, 612 + ln)], 1.8, pale,
                          jitter=0.02)
    else:
        cv.poly([(690, 380), (732, 380), (744, 404), (680, 404)], mix(coat, SEAGLASS, 0.12), None)  # collar
        cv.stroke([(772, 410), (780, 470), (778, 540), (770, 572)], 16, coat, jitter=0.02)  # right arm to chart
        cv.fillpoly(smooth([(756, 566), (778, 566), (780, 584), (760, 588)], 3), mix(PAPER, SEAGLASS, 0.15))
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
def capsule_background(cv, r):
    water0, water1 = (86, 112, 108), (58, 82, 82)
    cv.hrows(0, H, water0, water1, ya=120, yb=H)
    lay = cv.layer()
    for i in range(160):
        y = r.uniform(150, H)
        x = r.uniform(-60, W)
        ln = r.uniform(60, 200)
        lay.stroke([(x, y), (x + ln / 2, y - 3), (x + ln, y)], r.uniform(1.6, 3.2),
                   PAPER if r.random() < 0.4 else INK, jitter=0.08)
    cv.comp(lay, 0.25)
    # a piling at the left: barnacled, weeded, ordinary
    pl = (112, 100, 85)
    cv.rect(150, 120, 330, H + 4, fill=pl, ink=INK, w=3.0)
    cv.box(152, 122, 180, H, mix(pl, PAPER, 0.25))
    cv.box(296, 122, 328, H, mix(pl, INK, 0.3))
    for i in range(70):
        x = r.uniform(158, 322)
        y = r.uniform(620, 1080)
        cv.ell(x, y, r.uniform(5, 10), r.uniform(4, 8), fill=mix(PAPER, SEAGLASS, 0.3), ink=INK, w=1.4)
    weed = (62, 74, 60)
    for i in range(18):
        x = r.uniform(156, 324)
        cv.stroke(smooth([(x, 560 + r.uniform(0, 80)), (x + r.uniform(-14, 14), 760),
                          (x + r.uniform(-20, 20), 960), (x + r.uniform(-10, 10), 1086)], 5),
                  r.uniform(4, 8), weed, jitter=0.1)
    # deck edge and the cleat across the top
    deck = (138, 124, 104)
    cv.rect(-10, 40, W + 10, 130, fill=deck, ink=INK, w=3.0)
    cv.box(0, 42, W, 54, mix(deck, PAPER, 0.35))
    for x in (90, 420, 1010, 1330):
        cv.stroke([(x, 56), (x, 128)], 2.0, INK, alpha=180)
    cv.ell(240, 92, 9, 9, fill=SOOT, ink=INK, w=1.6)
    cleat = mix(SOOT, STORM, 0.4)
    horn = smooth([(568, 30), (590, 14), (640, 6), (724, 4), (808, 6), (858, 14), (880, 30), (850, 30),
                   (800, 24), (764, 26), (764, 40), (684, 40), (684, 26), (648, 24), (598, 30)], 3)
    cv.poly(horn, cleat, INK, 3.0)
    cv.stroke([(600, 16), (720, 8), (848, 16)], 2.4, mix(SEAGLASS, PAPER, 0.4))
    # the line: wrapped on the cleat, down to the capsule's bail
    rope = mix(TIMBER, PAPER, 0.18)
    cv.rect(714, 0, 734, 186, fill=rope, ink=INK, w=2.6)
    for y in range(4, 186, 14):
        cv.stroke([(714, y), (734, y + 9)], 1.6, INK, alpha=200, jitter=0.03)
    cv.ell(724, 22, 46, 14, fill=None, ink=rope, w=10)
    cv.ell(724, 22, 46, 14, fill=None, ink=INK, w=1.6)


def capsule_body(cv, mouth_open):
    brass_hi = mix(BRASS, PAPER, 0.62)
    # bail over the top
    cv.stroke(smooth([(606, 300), (614, 220), (724, 180), (834, 220), (842, 300)], 6), 10,
              mix(BRASS, INK, 0.25), jitter=0.03)
    cv.ell(606, 300, 10, 10, fill=BRASS, ink=INK, w=2.0)
    cv.ell(842, 300, 10, 10, fill=BRASS, ink=INK, w=2.0)
    # body Rect2(604,260,240,560)
    cv.rect(604, 260, 844, 800, fill=BRASS, ink=None)
    cv.poly(smooth([(604, 800), (640, 816), (724, 820), (808, 816), (844, 800)], 4) + [(844, 800)],
            BRASS, None)
    cv.box(624, 270, 646, 806, brass_hi)
    cv.box(630, 272, 636, 804, (238, 230, 208))
    cv.box(654, 270, 662, 806, mix(BRASS, PAPER, 0.35))
    cv.box(800, 270, 830, 806, mix(BRASS, INK, 0.28))
    for y in (360, 700):  # rolled bands
        cv.rect(600, y, 848, y + 16, fill=mix(BRASS, INK, 0.1), ink=INK, w=2.2)
        cv.box(604, y + 3, 844, y + 6, mix(BRASS, PAPER, 0.4))
    cv.stroke([(604, 260), (604, 800)], 3.0)
    cv.stroke([(844, 260), (844, 800)], 3.0)
    cv.stroke(smooth([(604, 800), (640, 816), (724, 820), (808, 816), (844, 800)], 4), 3.0)
    if mouth_open:
        # threaded neck and the dark interior seen through the open mouth
        cv.rect(612, 262, 836, 290, fill=mix(BRASS, INK, 0.15), ink=INK, w=2.0)
        for y in range(266, 290, 6):
            cv.stroke([(614, y), (834, y + 3)], 1.4, INK, alpha=200)
        cv.rect(626, 296, 822, 640, fill=(14, 22, 28), ink=INK, w=2.4)
        cv.stroke([(630, 300), (818, 300)], 2.0, mix(BRASS, PAPER, 0.3), alpha=200)
        cv.box(626, 600, 822, 640, (20, 30, 36))
    # droplets: wet-bright, perfectly clean, no growth
    rr = random.Random(seed_of("R01:droplets"))
    for i in range(16):
        x = rr.uniform(612, 836)
        y = rr.uniform(320, 800)
        if mouth_open and 620 < x < 828 and 290 < y < 646:
            continue
        cv.ell(x, y, 3.2, 4.8, fill=mix(PAPER, SEAGLASS, 0.15), ink=INK, w=1.0)
        cv.ell(x - 1, y - 1.6, 1.2, 1.4, fill=(240, 236, 224), ink=None)
    cv.ell(724, 818, 4, 7, fill=mix(PAPER, SEAGLASS, 0.2), ink=INK, w=1.0)


def paint_cap(cv, x0, y0, w=260, h=120):
    cv.rect(x0, y0, x0 + w, y0 + h, fill=mix(BRASS, PAPER, 0.08), ink=INK, w=3.0)
    for k in range(int(w / 10)):
        x = x0 + 6 + k * 10
        cv.stroke([(x, y0 + 14), (x, y0 + h - 14)], 2.0, mix(BRASS, INK, 0.45), jitter=0.03)
    cv.box(x0 + 4, y0 + 4, x0 + w - 4, y0 + 12, mix(BRASS, PAPER, 0.5))
    cv.box(x0 + 4, y0 + h - 12, x0 + w - 4, y0 + h - 4, mix(BRASS, INK, 0.3))
    cv.box(x0 + 20, y0 + 16, x0 + 34, y0 + h - 16, mix(BRASS, PAPER, 0.6))


def c_capsule():
    name = "c_capsule"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    capsule_background(cv, r)
    capsule_body(cv, False)
    paint_cap(cv, 594, 200)
    return cv.finish(name, "RGB", r)


def c_capsule_open():
    name = "c_capsule_open"
    r = random.Random(seed_of(f"{name}.png"))
    # repaint the plate's background under the closed cap so this overlay hides it exactly
    bg = Cv(random.Random(seed_of("c_capsule.png")))
    capsule_background(bg, bg.r)
    cv = Cv(r)
    patch = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(patch).rectangle([586 * S, 190 * S, 862 * S, 330 * S], fill=255)
    cv.im.alpha_composite(Image.composite(bg.im, Image.new("RGBA", bg.im.size, (0, 0, 0, 0)), patch))
    capsule_body(cv, True)
    # the cap, unscrewed, hanging on its chain to the right (x870-990, y260-380)
    y = 300
    pts = [(842, 300)]
    for k in range(1, 7):
        pts.append((842 + k * 6, 300 + k * 6 - (k * (6 - k)) * 0.4))
    for (a, b) in zip(pts, pts[1:]):
        cv.ell((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 4, 3, fill=None, ink=mix(INK, BRASS, 0.3), w=1.6)
    cv.stroke([(876, 336), (930, 262)], 2.2, mix(INK, BRASS, 0.3))
    del y
    cv.rect(870, 262, 990, 380, fill=mix(BRASS, PAPER, 0.08), ink=INK, w=3.0)
    for k in range(11):
        x = 876 + k * 10
        cv.stroke([(x, 276), (x, 366)], 2.0, mix(BRASS, INK, 0.45), jitter=0.03)
    cv.box(874, 266, 986, 274, mix(BRASS, PAPER, 0.5))
    cv.box(874, 368, 986, 376, mix(BRASS, INK, 0.3))
    cv.ell(930, 262, 5, 5, fill=BRASS, ink=INK, w=1.6)
    return cv.finish(name, "RGBA", r)


def c_capsule_key():
    name = "c_capsule_key"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    iron = (92, 98, 98)
    # bow (ring) at the top, shank down, bit at the foot: Rect2(640,330,70,250)
    cv.ell(675, 360, 30, 28, fill=iron, ink=INK, w=2.4)
    cv.ell(675, 360, 14, 12, fill=(14, 22, 28), ink=INK, w=2.0)
    cv.rect(668, 386, 682, 580, fill=iron, ink=INK, w=2.2)
    cv.box(670, 388, 673, 578, mix(iron, PAPER, 0.4))
    cv.rect(682, 536, 708, 552, fill=iron, ink=INK, w=2.0)
    cv.rect(682, 560, 702, 576, fill=iron, ink=INK, w=2.0)
    cv.rect(660, 396, 690, 402, fill=mix(iron, INK, 0.2), ink=INK, w=1.4)
    # blank paper tag on a string (the view writes SERVICE)
    cv.stroke([(690, 366), (700, 404)], 1.6, mix(PAPER, TIMBER, 0.4))
    cv.poly([(642, 414), (700, 404), (708, 446), (650, 456)], PAPER, INK, 2.0)
    cv.ell(697, 412, 3, 3, fill=(14, 22, 28), ink=INK, w=1.0)
    return cv.finish(name, "RGBA", r)


def c_capsule_note():
    name = "c_capsule_note"
    r = random.Random(seed_of(f"{name}.png"))
    cv = Cv(r)
    # a rolled paper note Rect2(730,330,80,250)
    cv.rect(734, 340, 806, 576, fill=PAPER, ink=INK, w=2.4)
    cv.ell(770, 340, 36, 10, fill=mix(PAPER, (230, 222, 200), 0.6), ink=INK, w=2.2)
    cv.ell(770, 340, 14, 4, fill=mix(PAPER, TIMBER, 0.45), ink=INK, w=1.4)
    cv.box(736, 346, 748, 574, mix(PAPER, (240, 234, 218), 0.6))
    cv.box(792, 346, 804, 574, mix(PAPER, INK, 0.15))
    cv.stroke([(740, 500), (780, 450), (804, 420)], 1.4, mix(PAPER, INK, 0.3))  # the roll's lapped edge
    cv.rect(732, 452, 808, 462, fill=mix(TIMBER, PAPER, 0.3), ink=INK, w=1.4)  # twine
    cv.stroke([(760, 462), (754, 486)], 1.6, mix(TIMBER, PAPER, 0.3))
    cv.stroke([(768, 462), (776, 484)], 1.6, mix(TIMBER, PAPER, 0.3))
    return cv.finish(name, "RGBA", r)


# =================================================================== registry
def _bd(name, *a, **k):
    return lambda: backdrop(name, *a, **k)


ASSETS = {
    "back_b0": _bd("back_b0", hexc("#8FA3A6"), hexc("#A9B5B0"), hexc("#617D74"), hexc("#4E6A66")),
    "back_b1": _bd("back_b1", hexc("#7D8E92"), mix(hexc("#7D8E92"), PAPER, 0.12), hexc("#557069"),
                   mix(hexc("#557069"), INK, 0.2), haze=0.3, ceiling=220, cloud_band=(250, 420)),
    "back_b2": _bd("back_b2", hexc("#64767C"), mix(hexc("#64767C"), PAPER, 0.08), hexc("#3F5759"),
                   mix(hexc("#3F5759"), INK, 0.25), haze=0.42, ceiling=220, cloud_band=(250, 420),
                   cloud_ink=50),
    "back_b3": _bd("back_b3", hexc("#5A6B72"), mix(hexc("#5A6B72"), PAPER, 0.07), hexc("#3A5052"),
                   mix(hexc("#3A5052"), INK, 0.25), haze=0.45, ceiling=220, cloud_band=(250, 420),
                   cloud_ink=50),
    "back_b4": _bd("back_b4", hexc("#5A6B72"), mix(hexc("#5A6B72"), PAPER, 0.07), hexc("#3A5052"),
                   mix(hexc("#3A5052"), INK, 0.25), haze=0.45, ceiling=220, cloud_band=(250, 420),
                   cloud_ink=50, tilt=0.07),
    "back_b5": _bd("back_b5", hexc("#4A5A62"), hexc("#4E5E66"), hexc("#4E5E66"), hexc("#4A5A62"),
                   haze=0.85, land_haze=0.4, hor_alpha=0.25, lighthouse=None, cloud_count=0),
    "back_b7": back_b7,
    "back_end_a": _bd("back_end_a", hexc("#B9C2BE"), mix(hexc("#B9C2BE"), PAPER, 0.25), hexc("#6E8780"),
                      hexc("#57716B"), lighthouse="off", gulls=True, cloud_band=(110, 380)),
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
