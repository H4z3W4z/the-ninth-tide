#!/usr/bin/env python3
"""R09 Lantern Gallery painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R09/*.png and assets/stages/R09/*.png:

  a_room, b_room                  the two gallery views (1448x1086 RGBA): copper soffit, brass-framed
                                  glazing with every pane rect fully transparent; view A also carries
                                  the opaque Fresnel signal lens, the aperture pedestal, the scope on
                                  its bracket and the blank diagram plate
  a_sea_*, b_sea_*                what stands behind the glass (opaque RGB): b3 storm, the upright
                                  surface at b4 (bare / shut / opened), b5, b6, b7 and ending A (sever)
  a_rail*, b_rail*                the outer rail beyond the glass, dry and wet (RGBA, full plate)
  a_lid_line, a_iris_*, a_lens_ada*, rain_tile, b_pennant_*, b_ruler
                                  sprites the view lays over the plates
  c_scope, c_ruler                close-up plates (opaque RGB)
  c_view_*                        aperture scenes (620x620, circle r 310, subject at the centre)
  c_eyepiece_ring, c_patch, c_steam, c_loupe_ring, c_frame_mounted, c_sel_knob, c_key_*, c_strip
                                  close-up sprites
  p15_surface_on_end*            fix p1 (ASSETS_P1), into assets/stages/R09/: the P15 stage overlay,
                                  the surface on end clipped to the gallery glass (seed 1509)
  surface_standing*, c_view_*_r3, c_rim_*
                                  fix pass w3 (see ASSETS_W3): the standing sea at a glance, and
                                  a bowl in every aperture with its rim under the lens

The upright sea is one flat matte plane: no waves and no creature, ever. What makes it wrong is
what it carries: pale reflections of the rooms behind Ada, the office lamp a warm point among them.

Flat front elevation, approved palette, navy ink contours, matte colour, a low seeded paper grain.
No text, numerals or diagrams: every enamel or brass label field is blank and the view writes
every word, the ruler numerals and the diagram. Registration follows the R09 art task; the
hotspots in R09_view.gd are fixed to it.

Python 3 + PIL only. Deterministic: each asset has its own random.Random(SEED + k), there is no
clock and no PIL noise effect, so a rerun is byte-identical.

    python3 tools/art/rooms/R09.py                 # paint everything
    python3 tools/art/rooms/R09.py a_sea* c_view*  # paint some (fnmatch patterns)
"""
import fnmatch
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "rooms", "R09")
W, H = 1448, 1086
SS = 2                      # supersampling for every painted shape
SEED = 1931_09_00

# ----------------------------------------------------------------------------- palette (R08's)
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
VIOLET = (116, 101, 119)    # #746577, only where duplicated by shape (unused here)

COPPER = (97, 125, 116)
COPPER_DK = tuple(int(round(c * 0.75)) for c in COPPER)   # the roof soffit, 25% darker
COPPER_LO = tuple(int(round(c * 0.60)) for c in COPPER)
COPPER_HI = tuple(int(round(c * 0.92)) for c in COPPER)

IRON = (40, 48, 56)
IRON_HI = (62, 74, 84)
IRON_LO = (28, 34, 41)
BOXWOOD = (196, 168, 116)   # the rule: pale warm boxwood
BOXWOOD_DK = (164, 136, 88)
SOUP = (122, 84, 52)        # restrained brown
SOUP_HI = (152, 110, 70)
GLASS_DK = (18, 30, 36)
SHADOW = (30, 48, 58)

# grey of ending A: ordinary daylight
GREY_SKY0 = (120, 126, 126)
GREY_SKY1 = (170, 171, 164)
GREY_SEA0 = (112, 119, 117)
GREY_SEA1 = (78, 86, 88)
GREY_LAND = (74, 80, 80)

# ----------------------------------------------------------------------------- registration (fixed)
A_PANES = [(52, 162, 368, 628), (392, 162, 712, 628), (736, 162, 1056, 628), (1080, 162, 1396, 628)]
A_BARS = (380, 724, 1068)
A_HOR = 400
A_SURF_TOP = 212
LENS_C, LENS_R, LENS_IN = (724, 392), 220, 200
PORTS = [(560, 708), (724, 708), (888, 708)]
PORT_R = 44
A_PLATES = [(500, 758, 620, 792), (664, 758, 784, 792), (828, 758, 948, 792)]
DIAGRAM = (1030, 652, 1370, 882)
A_CLEAR = (600, 836, 848, 900)
A_FLOOR = 900

B_PANES = [(60, 100, 489, 760), (517, 100, 931, 760), (959, 100, 1388, 760)]
B_BARS = (503, 945)
B_HOR = 380
B_SURF_TOP = 140
B_CLEAR = (600, 850, 848, 914)
STAFF = (1186, 260, 1194, 626)
ANCHOR = (1190, 270)

EYE_C, EYE_R = (940, 470), 310
VIEW_C = (310, 310)


# ----------------------------------------------------------------------------- helpers

def rng_for(k):
    return random.Random(SEED + k)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c0, c1, t):
    return tuple(int(round(lerp(a, b, t))) for a, b in zip(c0[:3], c1[:3]))


def shade(c, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in c[:3])


def rgba(c, a=255):
    return c if len(c) == 4 else (c[0], c[1], c[2], a)


def polar(c, r, deg):
    a = math.radians(deg)
    return (c[0] + r * math.cos(a), c[1] + r * math.sin(a))


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

    def ring(self, cx, cy, r0, r1, fill, ink=INK, w=2.0):
        """A filled annulus r0..r1 with inked edges."""
        rm = (r0 + r1) / 2
        box = ((cx - rm) * SS, (cy - rm) * SS, (cx + rm) * SS, (cy + rm) * SS)
        self.d.ellipse(box, outline=rgba(fill), width=int(round((r1 - r0) * SS)) + 1)
        self.ell(cx, cy, r1, r1, None, ink, w)
        self.ell(cx, cy, r0, r0, None, ink, w)

    def line(self, pts, col=INK, w=3.0):
        self.d.line(self._p(pts), fill=rgba(col), width=self.iw(w), joint="curve")

    def arc(self, cx, cy, rx, ry, a0, a1, col, w=3.0):
        box = ((cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS)
        self.d.arc(box, a0, a1, fill=rgba(col), width=self.iw(w))

    def vgrad(self, x0, y0, x1, y1, c0, c1, ya=None, yb=None):
        """Fill a rect with a vertical gradient c0 (at ya) -> c1 (at yb), clamped outside."""
        ya = y0 if ya is None else ya
        yb = y1 if yb is None else yb
        for sy in range(int(y0 * SS), int(y1 * SS)):
            y = (sy + 0.5) / SS
            t = min(1.0, max(0.0, (y - ya) / max(1e-6, yb - ya)))
            self.d.line([(x0 * SS, sy), (x1 * SS - 1, sy)], fill=rgba(mix(c0, c1, t)))

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

    def clip(self, mask):
        self.im.putalpha(ImageChops.multiply(self.im.getchannel("A"), mask))

    def cut(self, mask):
        """Make the masked area fully transparent."""
        self.im.putalpha(ImageChops.subtract(self.im.getchannel("A"), mask))

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
        d.rectangle((x0 * ss, y0 * ss, x1 * ss - 1, y1 * ss - 1), fill=255)
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


def save(im, name, opaque, out=None):
    out = out or OUT
    os.makedirs(out, exist_ok=True)
    if opaque:
        im = im.convert("RGB")
    else:
        im = im.convert("RGBA")
        a = im.getchannel("A")
        im.paste((0, 0, 0, 0), mask=a.point(lambda v: 255 if v == 0 else 0))
    path = os.path.join(out, name + ".png")
    im.save(path, optimize=False, compress_level=9)
    print("  wrote", os.path.relpath(path, ROOT), im.size, im.mode)


def screw(p, x, y, r=4.5, col=BRASS_HI):
    p.ell(x, y, r, r, col, INK, 1.6)
    p.line([(x - r * 0.6, y - r * 0.6), (x + r * 0.6, y + r * 0.6)], mix(col, INK, 0.5), 1.2)


def rivet(p, x, y, r=3.0, col=STORM_HI):
    p.ell(x, y, r, r, col, INK, 1.3)


def plate(p, x0, y0, x1, y1, fill=ENAMEL, rim=BRASS_LO, w=2.4):
    """A blank enamel label plate with a thin brass rim: the view writes on it."""
    p.rect(x0 - 3, y0 - 3, x1 + 3, y1 + 3, rim, INK, w, r=3)
    p.rect(x0, y0, x1, y1, fill, mix(INK, rim, 0.5), 1.4, r=2)


def clear_panes(im, panes, keep=None):
    """After the downsample: every pane pixel exactly transparent, except what stands in front."""
    m = Image.new("L", im.size, 0)
    d = ImageDraw.Draw(m)
    for x0, y0, x1, y1 in panes:
        d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=255)
    if keep is not None:
        m = ImageChops.subtract(m, keep)
    im.putalpha(ImageChops.subtract(im.getchannel("A"), m))
    return im


def soft_disc(p, cx, cy, r, col, opacity, blur):
    lay = p.layer()
    lay.ell(cx, cy, r, r, col, None)
    p.put_soft(lay, blur, opacity)


# ----------------------------------------------------------------------------- lighthouse
# The same silhouette language as R01's paint_lighthouse (tower x1196-1224 on base y432, banded,
# gallery at 343-348, lantern 318-343, conical cap to 302, finial ball at 293), scaled and, for
# the upright sea, hung upside down.

def lighthouse(p, cx, base_y, s, *, inv=False, white=PAPER, band=STORM, glass=None, ink=INK,
               lamp=None, lw=2.0):
    sg = -1 if inv else 1

    def L(x, y):
        return (cx + s * (x - 1210), base_y + sg * s * (y - 432))

    def R(x0, y0, x1, y1):
        return [L(x0, y0), L(x1, y0), L(x1, y1), L(x0, y1)]

    w = max(1.0, lw)
    glass = glass or mix(STORM, SEAGLASS, 0.35)
    p.poly([L(1196, 432), L(1199, 345), L(1221, 345), L(1224, 432)], white, ink, w)
    p.poly([L(1197.4, 392), L(1222.6, 392), L(1223.1, 405), L(1196.9, 405)], band, ink, w * 0.7)
    p.poly(R(1207, 412, 1213, 424), band, ink, w * 0.6)
    p.poly(R(1190, 318, 1230, 343), lamp or glass, ink, w)
    for mx in (1200, 1210, 1220):
        p.line([L(mx, 319), L(mx, 342)], ink, w * 0.6)
    p.poly(R(1186, 343, 1234, 348), band, ink, w * 0.8)
    p.poly([L(1188, 318), L(1210, 302), L(1232, 318)], band, ink, w)
    p.line([L(1210, 302), L(1210, 294)], ink, w * 0.8)
    bx, by = L(1210, 292)
    p.ell(bx, by, 2.2 * s, 2.2 * s, ink, None)


# ----------------------------------------------------------------------------- storm / sever sea

def clouds(p, rng, y0, y1, col, opacity, count, wmin=160, wmax=420):
    lay = p.layer()
    for _ in range(count):
        cx = rng.uniform(-80, p.w + 80)
        cy = rng.uniform(y0, y1)
        wd = rng.uniform(wmin, wmax)
        ht = wd * rng.uniform(0.12, 0.2)
        lay.ell(cx, cy, wd / 2, ht / 2, col, None)
        for k in range(rng.randint(2, 4)):
            ox = rng.uniform(-wd * 0.35, wd * 0.35)
            r = ht * rng.uniform(0.5, 0.9)
            lay.ell(cx + ox, cy - ht * 0.25, r * 1.4, r, col, None)
        # flat bottoms: cut a straight base under each bank
        lay.rect(cx - wd / 2 - 40, cy + ht * 0.32, cx + wd / 2 + 40, cy + ht * 1.6, (0, 0, 0, 0), None)
    p.put_soft(lay, 3, opacity)


def chop(p, rng, x0, x1, y0, y1, light, dark, count, opacity=1.0, scale=1.0):
    """Flat graphic chop: low crisp crests with a pale back and a dark trough line."""
    lt, dk = p.layer(), p.layer()
    for _ in range(count):
        y = y0 + 3 + (rng.random() ** 1.25) * (y1 - y0 - 3)
        t = (y - y0) / max(1, (y1 - y0))
        x = rng.uniform(x0 - 40, x1 + 40)
        wd = (16 + t * 110) * rng.uniform(0.7, 1.3) * scale
        ht = (1.2 + t * 5.0) * scale
        lt.poly([(x - wd / 2, y), (x - wd * 0.08, y - ht), (x + wd / 2, y)], light, None)
        dk.line([(x - wd * 0.45, y + 0.6 + t), (x + wd * 0.55, y + 0.6 + t)], dark, 0.8 + t * 1.6)
    p.put(dk, 0.55 * opacity)
    p.put(lt, 0.6 * opacity)


def headland(p, pts, fill, ink=INK, w=2.2):
    p.poly(pts, fill, ink, w)


def causeway(p, segs, y, h, fill, ink=INK, broken_at=None):
    for x0, x1 in segs:
        p.rect(x0, y, x1, y + h, fill, ink, 1.6)
        for jx in range(int(x0) + 14, int(x1) - 4, 16):
            p.line([(jx, y + 1.5), (jx, y + h - 1.5)], mix(fill, INK, 0.45), 1.1)
        p.line([(x0 + 1, y + 2), (x1 - 1, y + 2)], mix(fill, PAPER_HI, 0.35), 1.2)
    if broken_at:
        bx = broken_at
        p.poly([(bx - 2, y), (bx + 6, y + h * 0.3), (bx + 1, y + h * 0.55), (bx + 8, y + h), (bx - 2, y + h)],
               fill, ink, 1.6)


def sea_storm(rng, view, grey=False):
    """Band 3 (storm) or ending A (grey daylight): a crisp level horizon, headland, lighthouse."""
    hor = A_HOR if view == "a" else B_HOR
    if grey:
        sky0, sky1, sea0, sea1 = GREY_SKY0, GREY_SKY1, GREY_SEA0, GREY_SEA1
        land = GREY_LAND
        cloud = mix(GREY_SKY1, PAPER_HI, 0.35)
        light, dark = mix(GREY_SKY1, PAPER_HI, 0.45), mix(GREY_SEA1, INK, 0.4)
        white, band, glass = mix(PAPER, GREY_SKY1, 0.25), mix(STORM_HI, GREY_LAND, 0.4), mix(GREY_LAND, GREY_SKY1, 0.4)
        stone = mix(PAPER, GREY_LAND, 0.45)
    else:
        sky0, sky1 = STORM_DK, mix(STORM_HI, SEAGLASS, 0.55)
        sea0, sea1 = mix(SEAGLASS, STORM, 0.45), mix(STORM, STORM_DK, 0.5)
        land = mix(STORM_DK, SEAGLASS, 0.18)
        cloud = mix(STORM_HI, PAPER, 0.32)
        light, dark = mix(SEAGLASS_HI, PAPER, 0.25), mix(STORM_DK, INK, 0.5)
        white, band, glass = mix(PAPER, STORM_HI, 0.22), STORM, mix(STORM, SEAGLASS, 0.35)
        stone = mix(PAPER, STORM, 0.55)
    p = Pen(W, H, rng, sky0)
    p.vgrad(0, 0, W, hor, sky0, sky1, 0, hor)
    clouds(p, rng, 60, hor - 70, cloud, 0.58 if not grey else 0.5, 11)
    clouds(p, rng, hor - 120, hor - 30, mix(cloud, sky1, 0.4), 0.35, 7, 240, 520)
    p.vgrad(0, hor, W, H, sea0, sea1, hor, H)
    # a slightly paler skin just under the horizon, the way a far sea catches the overcast
    lay = p.layer()
    lay.rect(-4, hor, W + 4, hor + 26, mix(sea0, sky1, 0.5), None)
    p.put_soft(lay, 8, 0.45)
    chop(p, rng, 0, W, hor, H, light, dark, 520)
    if view == "a":
        headland(p, [(60, hor), (96, hor - 18), (140, hor - 32), (168, hor - 36), (252, hor - 36),
                     (280, hor - 24), (318, hor - 6), (336, hor)], land)
        p.line([(140, hor - 30), (252, hor - 33)], mix(land, PAPER, 0.18), 1.4)
        lighthouse(p, 200, hor - 35, 65 / 140, white=white, band=band, glass=glass, lw=1.6)
        causeway(p, [(306, 372), (384, 452), (464, 520)], hor + 5, 13, stone, broken_at=520)
    else:
        headland(p, [(1110, hor), (1150, hor - 14), (1200, hor - 24), (1300, hor - 26), (1336, hor - 14),
                     (1372, hor)], land)
        lighthouse(p, 1258, hor - 25, 55 / 140, white=white, band=band, glass=glass, lw=1.4)
        causeway(p, [(1030, 1076), (1088, 1112)], hor + 4, 7, stone, broken_at=1030 - 2)
    # the horizon: crisp and level
    p.line([(-4, hor), (W + 4, hor)], mix(INK, sea0, 0.25), 2.0)
    return p


# ----------------------------------------------------------------------------- the upright surface

def surf_cols(stage):
    """(top colour, bottom colour) of the standing plane at each stage."""
    top, bot = mix(STORM, STORM_HI, 0.15), mix(SEAGLASS, STORM, 0.3)
    if stage == "opened":
        top, bot = shade(top, 0.86), shade(bot, 0.86)
    elif stage == "b7":
        top, bot = mix(STORM_DK, STORM, 0.25), mix(STORM, SEAGLASS, 0.32)
    return top, bot


def surface(p, top_y, stage, sky_rng=None, view="a"):
    if top_y > 0:
        sky = sea_storm(sky_rng, view)
        p.im.paste(sky.im.crop((0, 0, W * SS, int(top_y * SS))), (0, 0))
    c0, c1 = surf_cols(stage)
    p.vgrad(0, top_y, W, H, c0, c1, top_y if top_y > 0 else 0, 640 if view == "a" else 770)
    if top_y > 0:
        # the edge: ruler straight, a cut, then a hairline of light along it
        p.line([(-4, top_y), (W + 4, top_y)], INK, 2.4)
        p.line([(-4, top_y + 2.5), (W + 4, top_y + 2.5)], mix(c0, PAPER_HI, 0.35), 1.2)
    if stage in ("opened", "b5", "b6"):
        sheen = p.layer()
        y0 = max(top_y, 0)
        cy = y0 + ((640 if view == "a" else 770) - y0) * 0.55
        sheen.rect(-40, cy - 70, W + 40, cy + 70, PAPER_HI, None)
        p.put_soft(sheen, 46, 0.11)
        thin = p.layer()
        thin.rect(-40, cy - 8, W + 40, cy + 8, PAPER_HI, None)
        p.put_soft(thin, 10, 0.07)


def reflections(p, spec, opacity, lamp=True):
    """Stacked pale outlines of the rooms behind Ada, and the office lamp as a warm point."""
    pale = mix(PAPER, STORM_HI, 0.25)
    fill_l, line_l = p.layer(), p.layer()
    # office window grid
    x0, y0, x1, y1 = spec["window"]
    fill_l.rect(x0, y0, x1, y1, STORM_HI, None)
    line_l.rect(x0 - 10, y0 - 10, x1 + 10, y1 + 12, None, pale, 3)
    line_l.rect(x0, y0, x1, y1, None, pale, 2.4)
    for i in (1, 2):
        xx = x0 + (x1 - x0) * i / 3
        line_l.line([(xx, y0), (xx, y1)], pale, 2.2)
    ym = y0 + (y1 - y0) * 0.45
    line_l.line([(x0 - 4, ym), (x1 + 4, ym)], pale, 3.4)
    for i in (1, 2):
        yy = y0 + (ym - y0) * i / 3 if i == 1 else ym + (y1 - ym) / 2
        line_l.line([(x0, yy), (x1, yy)], pale, 1.8)
    # door frames, one behind another
    for dx0, dy0, dx1, dy1 in spec["doors"]:
        fill_l.rect(dx0, dy0, dx1, dy1, STORM_HI, None)
        line_l.rect(dx0, dy0, dx1, dy1, None, pale, 2.6)
        k = 0
        while True:
            k += 1
            ix = (dx1 - dx0) * 0.17 * k
            iy0 = (dy1 - dy0) * 0.15 * k
            if dx1 - dx0 - 2 * ix < 14:
                break
            line_l.rect(dx0 + ix, dy0 + iy0, dx1 - ix, dy1 - (dy1 - dy0) * 0.04 * k, None, pale, max(1.2, 2.4 - 0.4 * k))
    # the mess table with nine bowls
    tx0, ty0, tx1, ty1 = spec["table"]
    fill_l.rect(tx0, ty0, tx1, ty1, STORM_HI, None)
    line_l.rect(tx0, ty0, tx1, ty1, None, pale, 2.4)
    line_l.line([(tx0, ty0 + 9), (tx1, ty0 + 9)], pale, 1.4)
    for lx in (tx0 + 16, tx1 - 16):
        line_l.line([(lx, ty1), (lx, ty1 + 58)], pale, 3)
    step = (tx1 - tx0) / 10
    br = min(15, step * 0.42)
    for i in range(9):
        bx = tx0 + step * (i + 1)
        fill_l.d.chord(((bx - br) * SS, (ty0 - br) * SS, (bx + br) * SS, (ty0 + br) * SS), 180, 360,
                       fill=rgba(mix(STORM_HI, PAPER, 0.25)))
        line_l.arc(bx, ty0, br, br, 180, 360, pale, 2.0)
    # a floor line, far off
    line_l.line([(spec["floor"][0], spec["floor"][2]), (spec["floor"][1], spec["floor"][2])], pale, 1.6)
    p.put(fill_l, 0.42 * opacity)
    p.put(line_l, 0.62 * opacity)
    if lamp:
        lx, ly = spec["lamp"]
        soft_disc(p, lx, ly, 28, AMBER, 0.35, 9)
        soft_disc(p, lx, ly, 15, mix(AMBER, PAPER_HI, 0.3), 0.4, 4)
        p.ell(lx, ly, 9, 9, mix(AMBER, PAPER_HI, 0.25), None)


# View A: the lens (504..944) is opaque, so the office window and its lamp hang in the clear
# left pane, where the lamp point reads at a glance; the second door stands left of the lens.
A_REFL = {
    "window": (110, 250, 330, 410),
    "lamp": (220, 320),
    "table": (230, 470, 560, 500),
    "doors": [(1092, 230, 1176, 600), (400, 236, 480, 460)],
    "floor": (52, 1396, 588),
}
# b7: the lantern housing's reflection, clear of the lens in view A
A_HOUSING = (1230, 300)
B_REFL = {
    "window": (1010, 230, 1230, 390),
    "lamp": (1120, 300),
    "table": (120, 470, 440, 500),
    "doors": [(626, 200, 822, 640), (1290, 260, 1370, 520)],
    "floor": (60, 1388, 690),
}


def immense_arc(p, centre, r, base):
    """The edge of something far larger than the window: one barely-there arc."""
    inner = p.layer()
    inner.ell(centre[0], centre[1], r, r, shade(base, 0.86), None)
    p.put_soft(inner, 30, 0.85)
    rim = p.layer()
    rim.arc(centre[0], centre[1], r, r, 180, 360, mix(base, SEAGLASS_HI, 0.55), 3.0)
    p.put_soft(rim, 1.5, 0.5)
    rim2 = p.layer()
    rim2.arc(centre[0], centre[1], r - 22, r - 22, 180, 360, mix(base, SEAGLASS_HI, 0.4), 1.6)
    p.put_soft(rim2, 3, 0.35)


def lantern_housing(p, cx, cy, h=56):
    """A tiny amber-lit reflection of the lantern room Ada stands in: glazed drum, cap, finial."""
    s = h / 56.0
    soft_disc(p, cx, cy + 6 * s, 30 * s, AMBER, 0.28, 10)
    top = cy - 28 * s
    p.line([(cx, top), (cx, top + 7 * s)], mix(AMBER, INK, 0.3), 1.4)
    p.ell(cx, top, 2 * s, 2 * s, AMBER, None)
    p.poly([(cx - 18 * s, top + 17 * s), (cx, top + 7 * s), (cx + 18 * s, top + 17 * s)],
           mix(STORM_HI, AMBER, 0.3), mix(AMBER, INK, 0.35), 1.4)
    p.rect(cx - 16 * s, top + 17 * s, cx + 16 * s, top + 41 * s, AMBER, mix(AMBER, INK, 0.45), 1.4)
    p.rect(cx - 8 * s, top + 21 * s, cx + 8 * s, top + 37 * s, mix(AMBER, PAPER_HI, 0.5), None)
    for k in (-8, 0, 8):
        p.line([(cx + k * s, top + 18 * s), (cx + k * s, top + 40 * s)], mix(AMBER, INK, 0.45), 1.0)
    p.rect(cx - 20 * s, top + 41 * s, cx + 20 * s, top + 45 * s, mix(STORM_HI, AMBER, 0.35), mix(AMBER, INK, 0.45), 1.2)
    p.rect(cx - 12 * s, top + 45 * s, cx + 12 * s, top + 56 * s, mix(STORM_HI, AMBER, 0.2), mix(AMBER, INK, 0.45), 1.2)


def inv_lighthouse(p, cx, base_y, s):
    pale = mix(STORM_HI, SEAGLASS_HI, 0.45)
    lay = p.layer()
    lighthouse(lay, cx, base_y, s, inv=True, white=pale, band=STORM_HI, glass=mix(STORM_HI, STORM, 0.4),
               ink=mix(PAPER, STORM_HI, 0.3), lw=2.2)
    p.put(lay, 0.85)
    # the lantern: lit, small, inside its glazing
    ly = base_y + s * (432 - 330.5)
    soft_disc(p, cx, ly, 9 * s, AMBER, 0.32, 7)
    p.rect(cx - 4.5 * s, ly - 5 * s, cx + 4.5 * s, ly + 5 * s, AMBER, None)
    p.rect(cx - 2 * s, ly - 3 * s, cx + 2 * s, ly + 3 * s, mix(AMBER, PAPER_HI, 0.5), None)


def paint_sea(rng, view, band):
    top = (A_SURF_TOP if view == "a" else B_SURF_TOP)
    spec = A_REFL if view == "a" else B_REFL
    if band == "b3":
        return sea_storm(rng, view)
    if band == "sever":
        return sea_storm(rng, view, grey=True)
    p = Pen(W, H, rng, STORM)
    if band in ("b4_bare", "b4_shut"):
        surface(p, top, "shut", rng_for(900 + (0 if view == "a" else 1)), view)
        if band == "b4_shut":
            reflections(p, spec, 1.0)
    elif band == "b4":
        surface(p, top, "opened", rng_for(900 + (0 if view == "a" else 1)), view)
        reflections(p, spec, 1.0)
    elif band in ("b5", "b6"):
        surface(p, 0, band, view=view)
        reflections(p, spec, 0.74)
        if band == "b6":
            if view == "a":
                inv_lighthouse(p, 1230, 176, 2.74)
            else:
                inv_lighthouse(p, 300, 104, 2.48)
    elif band == "b7":
        surface(p, 0, "b7", view=view)
        c0, c1 = surf_cols("b7")
        immense_arc(p, (724, 1900), 1500, mix(c0, c1, 0.5))
        if view == "a":
            lantern_housing(p, A_HOUSING[0], A_HOUSING[1], 56)
        else:
            lantern_housing(p, 724, 300, 56)
    return p


# ----------------------------------------------------------------------------- view A room

def soffit(p, y1, rng):
    """Copper roof soffit from y 0 to y1: standing seams, a fascia, a rolled drip edge."""
    p.rect(-4, -4, W + 4, y1, COPPER_DK, None)
    p.vgrad(-4, -4, W + 4, y1 - 34, COPPER_LO, COPPER_DK, 0, y1 - 34)
    for x in range(40, W, 112):
        p.line([(x, -4), (x, y1 - 36)], COPPER_LO, 4)
        p.line([(x + 3, -4), (x + 3, y1 - 36)], COPPER_HI, 1.4)
    # verdigris bloom, broad and matte
    lay = p.layer()
    for _ in range(14):
        lay.ell(rng.uniform(0, W), rng.uniform(0, y1 - 40), rng.uniform(50, 140), rng.uniform(10, 26), COPPER_HI, None)
    p.put_soft(lay, 12, 0.22)
    p.rect(-4, y1 - 36, W + 4, y1 - 6, COPPER, INK, 2.6)
    p.line([(-4, y1 - 30), (W + 4, y1 - 30)], mix(COPPER, PAPER, 0.25), 1.6)
    for x in range(26, W, 64):
        rivet(p, x, y1 - 20, 2.6, COPPER_HI)
    p.rect(-4, y1 - 8, W + 4, y1, COPPER_LO, INK, 2.2)


def brass_bar(p, x0, y0, x1, y1, vertical=True):
    p.rect(x0, y0, x1, y1, BRASS, INK, 2.6)
    if vertical:
        p.line([(x0 + 4, y0 + 2), (x0 + 4, y1 - 2)], BRASS_HI, 1.8)
        p.line([(x1 - 4, y0 + 2), (x1 - 4, y1 - 2)], BRASS_LO, 1.8)
    else:
        p.line([(x0 + 2, y0 + 3.5), (x1 - 2, y0 + 3.5)], BRASS_HI, 1.6)
        p.line([(x0 + 2, y1 - 3.5), (x1 - 2, y1 - 3.5)], BRASS_LO, 1.6)


def iron_post(p, x0, y0, x1, y1):
    p.rect(x0, y0, x1, y1, STORM, INK, 2.6)
    p.line([(x0 + 6, y0), (x0 + 6, y1)], STORM_HI, 1.6)
    for y in range(int(y0) + 20, int(y1) - 10, 44):
        rivet(p, (x0 + x1) / 2, y, 3.0)


def lens(p, rng):
    cx, cy = LENS_C
    # the interior: matte sea-glass carrying the gallery upside down
    inner = p.layer()
    inner.vgrad(cx - LENS_IN, cy - LENS_IN, cx + LENS_IN, cy + LENS_IN,
                mix(IRON, SEAGLASS, 0.35), mix(SEAGLASS, COPPER_DK, 0.4))
    k = 0.37

    def ly(y):
        return cy + (543 - y) * k

    def lx(x):
        return cx + (x - 724) * k

    # inverted floor grating (top), wall, panes, roof (bottom)
    inner.rect(cx - 220, ly(1086), cx + 220, ly(900), IRON, None)
    for i in range(10):
        yy = ly(900) - 6 - i * 7
        if yy > ly(1086):
            inner.line([(cx - 220, yy), (cx + 220, yy)], IRON_HI, 1.2)
    inner.rect(cx - 220, ly(900), cx + 220, ly(644), mix(STORM, SEAGLASS, 0.2), None)
    inner.rect(cx - 220, ly(644), cx + 220, ly(628), BRASS_LO, None)
    for (x0, y0, x1, y1) in A_PANES:
        inner.rect(lx(x0), ly(y1), lx(x1), ly(y0), mix(SEAGLASS_HI, STORM_HI, 0.45), None)
    for bx in A_BARS:
        inner.rect(lx(bx - 12), ly(628), lx(bx + 12), ly(162), BRASS_LO, None)
    inner.rect(cx - 220, ly(162), cx + 220, ly(150), BRASS_LO, None)
    inner.rect(cx - 220, ly(150), cx + 220, ly(0) + 40, COPPER_LO, None)
    # the pedestal hangs from the floor, upside down; the lens (in the lens) a dim disc on it
    inner.rect(lx(470), ly(830), lx(978), ly(650), IRON, None)
    inner.rect(lx(470), ly(800), lx(978), ly(650), BRASS_LO, None)
    for (px, py) in PORTS:
        inner.ell(lx(px), ly(py), PORT_R * k, PORT_R * k, IRON_LO, None)
    inner.ell(cx, ly(392), LENS_R * k, LENS_R * k, mix(SEAGLASS, IRON, 0.4), None)
    inner.im = inner.im.filter(ImageFilter.GaussianBlur(1.2 * SS))
    disc = circle_mask((W, H), (cx, cy), LENS_IN)
    lay = p.layer()
    lay.ell(cx, cy, LENS_IN, LENS_IN, mix(SEAGLASS, STORM, 0.35), None)
    p.put(lay)
    p.put(inner, 0.62, disc)
    # seven prisms: six annuli and a bullseye, each with a facet light at the top and a shadow below
    bounds = [200, 172, 144, 116, 88, 60, 32]
    facets = p.layer()
    for r in bounds:
        facets.arc(cx, cy, r - 7, r - 7, 200, 340, SEAGLASS_HI, 3.2)
        facets.arc(cx, cy, r - 5, r - 5, 30, 150, IRON_LO, 3.0)
    facets.ell(cx - 9, cy - 10, 10, 6, PAPER_HI, None)
    p.put(facets, 0.42, disc)
    for r in bounds[1:]:
        p.ell(cx, cy, r, r, None, BRASS_LO, 4.4)
        p.ell(cx, cy, r, r, None, INK, 1.2)
        p.arc(cx, cy, r + 1.4, r + 1.4, 200, 330, BRASS_HI, 1.2)
    # the bezel
    p.ring(cx, cy, LENS_IN, LENS_R, BRASS, INK, 3)
    p.ell(cx, cy, LENS_R - 6, LENS_R - 6, None, BRASS_HI, 1.6)
    p.ell(cx, cy, LENS_IN + 4, LENS_IN + 4, None, BRASS_LO, 2)
    for a in range(0, 360, 20):
        x, y = polar((cx, cy), 210, a + 10)
        rivet(p, x, y, 3.0, BRASS_HI)


def pedestal(p):
    cx = 724
    # neck from the lens to the drum
    p.rect(cx - 70, 606, cx + 70, 640, IRON, INK, 2.6)
    p.line([(cx - 64, 612), (cx + 64, 612)], IRON_HI, 1.6)
    p.rect(cx - 96, 628, cx + 96, 646, BRASS_LO, INK, 2.4)
    # the drum: iron cap, brass aperture band, iron foot
    p.rect(468, 638, 980, 652, IRON, INK, 2.6)
    p.rect(470, 650, 978, 800, BRASS, INK, 3)
    p.line([(474, 656), (974, 656)], BRASS_HI, 2)
    p.line([(474, 794), (974, 794)], BRASS_LO, 2)
    for x in (480, 966):
        for y in (664, 786):
            screw(p, x, y, 4)
    for i, (px, py) in enumerate(PORTS):
        p.ell(px, py, PORT_R + 8, PORT_R + 8, BRASS_LO, INK, 2.6)
        p.ell(px, py, PORT_R + 4, PORT_R + 4, None, BRASS_HI, 1.4)
        p.ell(px, py, PORT_R, PORT_R, GLASS_DK, INK, 2.4)
        p.arc(px, py, PORT_R - 6, PORT_R - 6, 30, 150, IRON_LO, 4)
        x0, y0, x1, y1 = A_PLATES[i]
        plate(p, x0, y0, x1, y1)
    p.rect(466, 800, 982, 832, IRON, INK, 2.6)
    p.line([(470, 806), (978, 806)], IRON_HI, 1.6)
    for x in range(486, 980, 40):
        rivet(p, x, 818, 2.6, IRON_HI)
    # feet stand outside the nav tab's floor
    for x0, x1 in ((478, 584), (864, 970)):
        p.poly([(x0, 832), (x1, 832), (x1 - 12, 904), (x0 + 12, 904)], IRON, INK, 2.6)
        p.line([(x0 + 8, 838), (x1 - 8, 838)], IRON_HI, 1.4)


def scope(p):
    # wall bracket
    p.rect(60, 560, 110, 700, IRON, INK, 2.6, r=4)
    p.line([(66, 566), (66, 694)], IRON_HI, 1.6)
    for y in (576, 684):
        screw(p, 85, y, 4.2, IRON_HI)
    p.poly([(96, 596), (132, 594), (132, 640), (96, 660)], IRON, INK, 2.4)
    # tube from (120,600) eyepiece to (470,650) objective
    a = math.atan2(50, 350)
    nx, ny = -math.sin(a), math.cos(a)

    def band(t0, t1, r0, r1, fill, w=2.4):
        x0, y0 = lerp(120, 470, t0), lerp(600, 650, t0)
        x1, y1 = lerp(120, 470, t1), lerp(600, 650, t1)
        p.poly([(x0 + nx * r0, y0 + ny * r0), (x1 + nx * r1, y1 + ny * r1),
                (x1 - nx * r1, y1 - ny * r1), (x0 - nx * r0, y0 - ny * r0)], fill, INK, w)

    band(0.08, 0.9, 19, 22, BRASS)
    x0, y0 = lerp(120, 470, 0.1), lerp(600, 650, 0.1)
    x1, y1 = lerp(120, 470, 0.88), lerp(600, 650, 0.88)
    p.line([(x0 - nx * 13, y0 - ny * 13), (x1 - nx * 15, y1 - ny * 15)], BRASS_HI, 2)
    for t in (0.3, 0.62):
        band(t, t + 0.04, 23, 23, BRASS_LO, 2)
    band(0.88, 1.0, 24, 30, BRASS_LO)                   # objective hood
    band(-0.02, 0.08, 15, 15, IRON)                      # eyepiece
    band(-0.06, -0.02, 18, 18, IRON_LO)
    # the clamp on top, jaws open, empty
    p.poly([(180, 578), (360, 578), (360, 610), (180, 588)], BRASS_LO, INK, 2.4)
    p.rect(176, 570, 364, 584, BRASS, INK, 2.4)
    p.line([(180, 574), (360, 574)], BRASS_HI, 1.4)
    for x0, x1, tip in ((184, 202, 1), (338, 356, -1)):
        p.rect(x0, 540, x1, 572, BRASS, INK, 2.4)
        tx = x1 if tip > 0 else x0
        p.poly([(tx, 540), (tx + 14 * tip, 540), (tx + 14 * tip, 548), (tx, 552)], BRASS_HI, INK, 2)
    p.rect(214, 560, 326, 568, BRASS_DK, INK, 1.8)       # the screw rod between the jaws
    screw(p, 270, 576, 4.4)


def wall_a(p, rng):
    p.rect(-4, 644, W + 4, A_FLOOR, STORM, None)
    for x in (236, 470, 980, 1218):
        p.line([(x, 650), (x, A_FLOOR - 2)], STORM_DK, 3)
        p.line([(x + 3, 650), (x + 3, A_FLOOR - 2)], STORM_HI, 1.2)
    for x in range(14, W, 30):
        if not (A_CLEAR[0] - 6 < x < A_CLEAR[2] + 6):
            rivet(p, x, 888, 2.4)
        rivet(p, x, 658, 2.4)
    lay = p.layer()
    for _ in range(12):
        lay.ell(rng.uniform(0, W), rng.uniform(680, 860), rng.uniform(60, 150), rng.uniform(20, 40), STORM_HI, None)
    p.put_soft(lay, 22, 0.2)


def grating(p, y0, y1):
    p.rect(-4, y0, W + 4, y1 + 4, IRON_LO, None)
    for y in range(int(y0) + 18, int(y1), 16):
        p.line([(-4, y), (W + 4, y)], IRON, 4)
        p.line([(-4, y - 2), (W + 4, y - 2)], IRON_HI, 1.0)
    for x in range(10, W, 46):
        p.line([(x, y0 + 12), (x, y1 + 4)], IRON, 3)
    p.rect(-4, y0, W + 4, y0 + 12, IRON, INK, 2.6)
    p.line([(-4, y0 + 4), (W + 4, y0 + 4)], IRON_HI, 1.4)


def paint_a_room(rng):
    p = Pen(W, H, rng)
    soffit(p, 150, rng)
    brass_bar(p, -4, 150, W + 4, 162, vertical=False)
    iron_post(p, -4, 150, 52, 644)
    iron_post(p, 1396, 150, W + 4, 644)
    p.line([(48, 162), (48, 628)], BRASS, 6)
    p.line([(1400, 162), (1400, 628)], BRASS, 6)
    for bx in A_BARS:
        brass_bar(p, bx - 12, 162, bx + 12, 628)
    brass_bar(p, -4, 628, W + 4, 644, vertical=False)
    wall_a(p, rng)
    grating(p, A_FLOOR, H)
    # blank diagram plate, four brass screws
    x0, y0, x1, y1 = DIAGRAM
    sh = p.layer()
    sh.rect(x0 + 6, y0 + 8, x1 + 6, y1 + 8, SHADOW, None)
    p.put_soft(sh, 6, 0.4)
    p.rect(x0 - 8, y0 - 8, x1 + 8, y1 + 8, BRASS_LO, INK, 2.6, r=4)
    p.rect(x0, y0, x1, y1, ENAMEL, mix(INK, BRASS_LO, 0.5), 1.6, r=2)
    for sx, sy in ((x0 + 12, y0 + 12), (x1 - 12, y0 + 12), (x0 + 12, y1 - 12), (x1 - 12, y1 - 12)):
        screw(p, sx, sy, 5)
    # the four panes, cut clean; then what stands in front of the glass
    p.cut(rect_mask((W, H), A_PANES))
    pedestal(p)
    lens(p, rng)
    scope(p)
    keep = Image.new("L", (W, H), 0)
    kd = ImageDraw.Draw(keep)
    kd.ellipse((LENS_C[0] - LENS_R - 2, LENS_C[1] - LENS_R - 2, LENS_C[0] + LENS_R + 2, LENS_C[1] + LENS_R + 2), fill=255)
    kd.rectangle((56, 530, 480, 720), fill=255)
    kd.rectangle((650, 600, 800, 630), fill=255)
    return clear_panes(p.done(), A_PANES, keep)


# ----------------------------------------------------------------------------- rails

def rail_a(rng, wet):
    p = Pen(W, H, rng)
    iron, edge = STORM_DK, INK
    for k in range(9):
        x = 80 + 168 * k
        p.rect(x - 5, 560, x + 5, 628, iron, edge, 2)
    p.rect(-4, 560, W + 4, 572, iron, edge, 2.2)
    p.rect(-4, 596, W + 4, 604, iron, edge, 2)
    if wet:
        wet_marks(p, rng, [(560, 572), (596, 604)], [80 + 168 * k for k in range(9)], 5, 628)
    return p


def wet_marks(p, rng, rails, posts, half, post_bot):
    hi = p.layer()
    for y0, y1 in rails:
        hi.line([(-4, y0 + 1.6), (W + 4, y0 + 1.6)], PAPER_HI, 1.6)
    for x in posts:
        hi.line([(x - half + 2, rails[0][1] + 2), (x - half + 2, post_bot - 2)], PAPER_HI, 1.4)
    p.put(hi, 0.75)
    beads = p.layer()
    for y0, y1 in rails:
        x = rng.uniform(4, 20)
        while x < W:
            r = rng.uniform(1.6, 3.2)
            beads.ell(x, y1 + r * 0.6, r, r * 1.15, mix(PAPER_HI, SEAGLASS_HI, 0.3), INK, 0.8)
            beads.ell(x - r * 0.3, y1 + r * 0.2, r * 0.35, r * 0.35, PAPER_HI, None)
            if rng.random() < 0.3:
                ln = rng.uniform(5, 15)
                beads.line([(x, y1 + r * 1.6), (x, y1 + r * 1.6 + ln)], PAPER_HI, 1.1)
                beads.ell(x, y1 + r * 1.6 + ln + 1.3, 1.4, 1.8, PAPER_HI, None)
            x += rng.uniform(34, 90)
    p.put(beads, 0.9)


def rail_b(rng, wet):
    p = Pen(W, H, rng)
    iron, edge = STORM_DK, INK
    posts = [100 + 190 * k for k in range(8)]
    # walkway deck edge
    p.rect(-4, 730, W + 4, 760, mix(STORM_DK, IRON, 0.5), edge, 2.4)
    p.line([(-4, 736), (W + 4, 736)], STORM, 1.6)
    for x in range(20, W, 48):
        rivet(p, x, 750, 2.2, STORM)
    for x in posts:
        p.rect(x - 6, 610, x + 6, 744, iron, edge, 2)
        p.rect(x - 10, 726, x + 10, 734, iron, edge, 1.8)
    p.rect(-4, 610, W + 4, 626, iron, edge, 2.4)
    p.rect(-4, 668, W + 4, 678, iron, edge, 2)
    # the pennant staff, clamped to the top rail, with a brass finial
    x0, y0, x1, y1 = STAFF
    p.rect(x0, y0, x1, y1, iron, edge, 1.8)
    p.rect(x0 - 4, 600, x1 + 4, 612, iron, edge, 1.8)
    p.rect(x0 - 2, y0 - 3, x1 + 2, y0 + 2, BRASS_LO, edge, 1.4)
    p.ell(1190, y0 - 10, 7, 7, BRASS, edge, 1.6)
    p.ell(1188, y0 - 12, 2.4, 2.4, BRASS_HI, None)
    p.poly([(1186, y0 - 16), (1190, y0 - 30), (1194, y0 - 16)], BRASS, edge, 1.4)
    p.rect(x0 - 3, ANCHOR[1] - 4, x1 + 3, ANCHOR[1] + 4, BRASS_LO, edge, 1.4)
    if wet:
        wet_marks(p, rng, [(610, 626), (668, 678)], posts, 6, 744)
        hi = p.layer()
        hi.line([(x0 + 2, y0 + 4), (x0 + 2, y1 - 2)], PAPER_HI, 1.2)
        p.put(hi, 0.7)
    return p


# ----------------------------------------------------------------------------- view B room

def paint_b_room(rng):
    p = Pen(W, H, rng)
    soffit(p, 88, rng)
    brass_bar(p, -4, 88, W + 4, 100, vertical=False)
    iron_post(p, -4, 88, 60, 760)
    iron_post(p, 1388, 88, W + 4, 760)
    p.line([(56, 100), (56, 760)], BRASS, 6)
    p.line([(1392, 100), (1392, 760)], BRASS, 6)
    for bx in B_BARS:
        brass_bar(p, bx - 14, 100, bx + 14, 760)
    # timber sill, empty
    p.rect(-4, 760, W + 4, 840, TIMBER, INK, 3)
    p.rect(-4, 756, W + 4, 772, TIMBER_HI, INK, 2.6)
    p.line([(-4, 760), (W + 4, 760)], mix(TIMBER_HI, PAPER, 0.4), 1.6)
    for y in (796, 818):
        p.line([(-4, y), (W + 4, y)], TIMBER_DK, 1.2)
    p.rect(-4, 834, W + 4, 844, TIMBER_DK, INK, 2.2)
    # sea-glass painted board panelling; the nav tab's rect left plain
    p.rect(-4, 844, W + 4, H + 4, SEAGLASS, None)
    lay = p.layer()
    for _ in range(10):
        lay.ell(rng.uniform(0, W), rng.uniform(880, 1080), rng.uniform(60, 160), rng.uniform(20, 40), mix(SEAGLASS, STORM, 0.3), None)
    p.put_soft(lay, 18, 0.25)
    for x in range(30, W, 58):
        if B_CLEAR[0] - 12 < x < B_CLEAR[2] + 12:
            continue
        p.line([(x, 846), (x, H + 4)], mix(SEAGLASS, INK, 0.45), 2.2)
        p.line([(x + 3, 846), (x + 3, H + 4)], SEAGLASS_HI, 1.0)
    px0, px1 = B_CLEAR[0] - 8, B_CLEAR[2] + 8
    p.line([(px0, 846), (px0, H + 4)], mix(SEAGLASS, INK, 0.45), 2.6)
    p.line([(px0 + 4, 846), (px0 + 4, H + 4)], SEAGLASS_HI, 1.2)
    p.line([(px1, 846), (px1, H + 4)], mix(SEAGLASS, INK, 0.45), 2.6)
    p.line([(px1 - 4, 846), (px1 - 4, H + 4)], mix(SEAGLASS, STORM, 0.3), 1.2)
    p.cut(rect_mask((W, H), B_PANES))
    return clear_panes(p.done(), B_PANES)


# ----------------------------------------------------------------------------- sprites

def paint_lid_line(rng):
    w, h = 1344, 28
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    col = Image.new("L", (1, h))
    for y in range(h):
        d = abs(y + 0.5 - h / 2)
        if d <= 1.0:
            a = 230
        else:
            a = 230 * max(0.0, 1 - (d - 1.0) / 13.0) ** 2.2
        col.putpixel((0, y), int(round(a)))
    alpha = col.resize((w, h))
    im.paste(PAPER_HI + (255,), (0, 0, w, h))
    im.putalpha(alpha)
    return im


def paint_iris(rng, open_):
    p = Pen(100, 100, rng)
    c, r = (50, 50), 44
    if not open_:
        p.ell(50, 50, r, r, BRASS, INK, 2.2)
        for i in range(9):
            a0 = i * 40
            pts = [polar(c, r - 1, a0 - 4), polar(c, r - 1, a0 + 36)]
            # blade edge: a curved line from the rim spiralling to the centre
            edge = [polar(c, r - 1 - t * (r - 3), a0 + 36 + t * 70) for t in [k / 10 for k in range(11)]]
            fill = BRASS_LO if i % 2 else BRASS
            p.poly([pts[0]] + [polar(c, r - 1, a0 + 16), pts[1]] + edge[1:] + [c], fill, None)
            p.line(edge, INK, 1.4)
            p.line([polar(c, r - 4, a0 + 6), polar(c, r * 0.55, a0 + 26)], BRASS_HI, 1.0)
        p.ell(50, 50, r, r, None, INK, 2.2)
        p.ell(50, 50, 2.2, 2.2, BRASS_DK, None)
    else:
        p.ell(50, 50, r, r, BRASS_LO, INK, 2.2)
        for i in range(9):
            a = i * 40 + 10
            p.line([polar(c, 34, a), polar(c, r - 2, a + 18)], INK, 1.2)
        p.ell(50, 50, r - 3, r - 3, None, BRASS_HI, 1.2)
        p.ell(50, 50, 34, 34, GLASS_DK, INK, 2.2)
        p.arc(50, 50, 28, 28, 20, 160, IRON_LO, 3)
        p.arc(50, 50, 26, 26, 210, 250, SEAGLASS_HI, 2.4)
        p.ell(40, 38, 2.4, 2.4, SEAGLASS_HI, None)
    return p


def ada_bust(p, cx, top, s, col, ink, inv=False, total_h=None):
    """Head and shoulders, no features: a bob of hair, a collar, broad shoulders. top = crown y."""
    sg = -1 if inv else 1

    def P(x, y):
        return (cx + s * x, top + sg * s * y)

    head = [P(70 * math.cos(t) * (1 + 0.04 * math.sin(3 * t)), 92 + 86 * math.sin(t))
            for t in [math.tau * k / 72 for k in range(72)]]
    body = [P(-180, 270), P(-150, 228), P(-96, 206), P(-46, 190), P(-38, 160), P(38, 160), P(46, 190),
            P(96, 206), P(150, 228), P(180, 270), P(196, 360), P(-196, 360)]
    p.poly(body, col, ink, 2.6)
    p.poly(head, col, ink, 2.6)
    # the hair's line, and a collar: shape only, never a face
    p.line([P(-62, 120), P(-68, 150), P(-52, 172)], mix(col, ink, 0.6), 2.0)
    p.line([P(62, 120), P(68, 150), P(52, 172)], mix(col, ink, 0.6), 2.0)
    p.line([P(-46, 190), P(0, 214), P(46, 190)], mix(col, ink, 0.6), 2.0)


def paint_lens_ada(rng, inv):
    p = Pen(440, 440, rng)
    if not inv:
        ada_bust(p, 220, 182, 1.05, STORM_DK, INK)
    else:
        lay = p.layer()
        ada_bust(lay, 220, 296, 0.38, STORM_DK, INK, inv=True)
        p.put(lay, 0.92)
    p.clip(circle_mask((440, 440), (220, 220), 200))
    return p


def paint_rain(rng):
    im = Image.new("RGBA", (512 * SS, 512 * SS), (0, 0, 0, 0))
    for _ in range(170):
        x = rng.uniform(0, 512)
        y = rng.uniform(0, 512)
        ln = rng.uniform(18, 60)
        dx = ln * 0.08
        a = rng.randint(60, 110)
        wd = rng.choice((1, 1, 1.5, 2))
        lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        for ox in (-512, 0, 512):
            for oy in (-512, 0, 512):
                d.line([((x + ox) * SS, (y + oy) * SS), ((x + ox + dx) * SS, (y + oy + ln) * SS)],
                       fill=PAPER_HI + (a,), width=max(1, int(wd * SS)))
        im.alpha_composite(lay)
    return im.resize((512, 512), Image.LANCZOS)


def pennant_shape(pts_top, pts_bot):
    """Polygon of a swallowtail pennant from its top edge and bottom edge polylines (hoist first)."""
    return pts_top + pts_bot[::-1]


def pennant(p, top, bot, stripe_top, stripe_bot, notch):
    wool = SEAGLASS
    p.poly(top + [notch] + bot[::-1], wool, None)
    p.poly(stripe_top + stripe_bot[::-1], STORM, None)
    # wool: a few faint lengthwise fibres
    for f in (0.2, 0.8):
        fib = [(lerp(a[0], b[0], f), lerp(a[1], b[1], f)) for a, b in zip(top, bot)]
        p.line(fib, mix(wool, SEAGLASS_HI, 0.5), 1.0)
    p.poly(top + [notch] + bot[::-1], None, INK, 2.0)


def pennant_out(p, phase=None, droop=0.0):
    """Straight out to the left from (226,4); phase None means perfectly rigid."""
    n = 24
    L = 220
    top, bot, st, sb = [], [], [], []
    for i in range(n + 1):
        t = i / n
        x = 226 - L * t
        if phase is None:
            off = 0.0
        else:
            off = (10 + 18 * t) * math.sin(phase + t * 7.0) * t + droop * t * t
        hw = lerp(30, 22, t)
        cy = 4 + 30 + off - (30 - hw) * 0  # hoist centre at y 34
        cy = 34 + off
        top.append((x, cy - hw))
        bot.append((x, cy + hw))
        st.append((x, cy - 4))
        sb.append((x, cy + 4))
    # swallowtail notch at the fly
    j = n - 4
    mid = ((top[j][0] + bot[j][0]) / 2, (top[j][1] + bot[j][1]) / 2)
    top[0] = (226, 4)
    bot[0] = (226, 64)
    st, sb = st[:20], sb[:20]
    pennant(p, top, bot, st, sb, mid)
    if phase is not None:
        fold = p.layer()
        for i in range(2, n - 2):
            t = i / n
            d = math.cos(phase + t * 7.0)
            if d < -0.4:
                fold.line([top[i], bot[i]], STORM_DK, 3)
        p.put_soft(fold, 2, 0.35)


def paint_pennant_dead(rng):
    p = Pen(80, 220, rng)
    n = 20
    top, bot, st, sb = [], [], [], []
    for i in range(n + 1):
        t = i / n
        y = 4 + 206 * t
        hw = lerp(30, 18, t)
        cx = 6 + 30 - (30 - hw) * 0.2
        top.append((cx - hw, y))
        bot.append((cx + hw, y))
        st.append((cx - 4, y))
        sb.append((cx + 4, y))
    top[0] = (6, 4)
    bot[0] = (66, 4)
    j = n - 3
    mid = ((top[j][0] + bot[j][0]) / 2, top[j][1])
    # hanging dead: hoist is the top edge, the cloth falls straight; left edge touches the staff
    pennant(p, top, bot, st[:17], sb[:17], mid)
    return p


def paint_pennant_out(rng):
    p = Pen(230, 70, rng)
    pennant_out(p)
    return p


def paint_pennant_flap(rng, k):
    p = Pen(230, 110, rng)
    pennant_out(p, phase=(0.0 if k == 1 else math.pi), droop=16)
    return p


def ruler_ticks(p, x0, x1, y_top, unit, inch_h, lw=1.0, deep=True):
    n = int((x1 - x0) / (unit / 8)) + 1
    for i in range(n):
        x = x0 + i * unit / 8
        if x > x1 + 0.1:
            break
        if i % 8 == 0:
            hh = inch_h
        elif i % 4 == 0:
            hh = inch_h * 0.72
        elif i % 2 == 0:
            hh = inch_h * 0.52
        else:
            hh = inch_h * 0.36
        p.line([(x, y_top), (x, y_top + hh)], INK, lw)
        if deep:
            p.line([(x + lw * 0.9, y_top + 1), (x + lw * 0.9, y_top + hh - 1)], mix(BOXWOOD, PAPER_HI, 0.6), lw * 0.6)


def paint_b_ruler(rng):
    p = Pen(400, 40, rng)
    p.rect(2, 8, 398, 34, BOXWOOD, INK, 1.8, r=2)
    p.line([(14, 11), (386, 11)], mix(BOXWOOD, PAPER_HI, 0.5), 1.2)
    p.line([(14, 31), (386, 31)], BOXWOOD_DK, 1.2)
    ruler_ticks(p, 18, 382, 9, 30.3, 12, 0.9)
    for x0, x1 in ((2, 14), (386, 398)):
        p.rect(x0, 7, x1, 35, BRASS, INK, 1.6, r=2)
        p.line([(x0 + 3, 10), (x0 + 3, 32)], BRASS_HI, 1.0)
    return p


def paint_eyepiece_ring(rng):
    p = Pen(680, 680, rng)
    c = (340, 340)
    p.ring(340, 340, 310, 340, BRASS, INK, 3)
    p.ell(340, 340, 334, 334, None, BRASS_HI, 1.6)
    p.ell(340, 340, 314, 314, None, BRASS_LO, 2.4)
    for a in range(0, 360, 2):
        long_ = a % 30 == 0
        mid = a % 10 == 0
        r0 = 312
        r1 = 330 if long_ else 324 if mid else 318
        p.line([polar(c, r0, a - 90), polar(c, r1, a - 90)], BRASS_DK, 1.8 if long_ else 1.1)
    p.arc(340, 340, 326, 326, 200, 250, BRASS_HI, 2.4)
    return p


def aperture_base(p, sky0, sky1, sea0, sea1, hor):
    p.vgrad(0, 0, 620, hor, sky0, sky1)
    p.vgrad(0, hor, 620, 620, sea0, sea1)


def paint_view_land(rng):
    p = Pen(620, 620, rng)
    hor = 232
    aperture_base(p, STORM_DK, mix(STORM_HI, SEAGLASS, 0.55), mix(SEAGLASS, STORM, 0.45), mix(STORM, STORM_DK, 0.5), hor)
    clouds(p, rng, 50, hor - 60, mix(STORM_HI, PAPER, 0.32), 0.55, 6, 140, 300)
    chop(p, rng, 0, 620, hor, 620, mix(SEAGLASS_HI, PAPER, 0.25), mix(STORM_DK, INK, 0.5), 170, scale=1.15)
    land = mix(STORM_DK, SEAGLASS, 0.18)
    # the headland: a flat-topped bluff on the left, its foot running out toward the causeway
    p.poly([(-10, 300), (-10, 196), (44, 172), (92, 160), (176, 160), (214, 182), (236, hor),
            (226, 272), (190, 300)], land, INK, 2.6)
    p.line([(60, 168), (176, 165)], mix(land, PAPER, 0.18), 1.6)
    lighthouse(p, 134, 162, 0.68, white=mix(PAPER, STORM_HI, 0.22), band=STORM, lw=2.2)
    p.line([(236, hor), (624, hor)], mix(INK, SEAGLASS, 0.25), 2.2)
    # the causeway: from the headland's foot out to a broken end exactly at the centre
    stone = mix(PAPER, STORM, 0.48)
    y0, y1 = 296, 324
    p.rect(150, y0, 300, y1, stone, INK, 2.4)
    for jx in range(176, 300, 26):
        p.line([(jx, y0 + 2), (jx, y1 - 2)], mix(stone, INK, 0.45), 1.6)
    p.line([(152, y0 + 3), (298, y0 + 3)], mix(stone, PAPER_HI, 0.4), 1.6)
    p.poly([(298, y0), (312, y0 + 5), (305, 310), (316, 316), (306, y1), (298, y1)], stone, INK, 2.4)
    # tumbled blocks in the water past the break
    p.poly([(336, 324), (360, 320), (364, 334), (340, 338)], mix(stone, INK, 0.25), INK, 1.8)
    p.poly([(392, 332), (410, 330), (412, 340), (394, 342)], mix(stone, INK, 0.3), INK, 1.6)
    p.line([(150, y1 + 4), (300, y1 + 4)], mix(STORM_DK, INK, 0.5), 2.4)
    p.clip(circle_mask((620, 620), VIEW_C, 310))
    return p


def paint_view_sea(rng):
    p = Pen(620, 620, rng)
    hor = 300
    aperture_base(p, STORM_DK, mix(STORM_HI, SEAGLASS, 0.55), mix(SEAGLASS, STORM, 0.45), mix(STORM, STORM_DK, 0.5), hor)
    clouds(p, rng, 50, hor - 70, mix(STORM_HI, PAPER, 0.32), 0.38, 6, 140, 300)
    p.line([(-4, hor), (624, hor)], mix(INK, SEAGLASS, 0.25), 2.2)
    # the single crest, flat, at the centre
    cx, cy = VIEW_C
    p.poly([(cx - 80, cy + 8), (cx - 6, cy - 6), (cx + 80, cy + 8)], mix(SEAGLASS_HI, PAPER, 0.3), INK, 2.2)
    p.line([(cx - 76, cy + 11), (cx + 80, cy + 11)], mix(STORM_DK, INK, 0.5), 2.4)
    p.clip(circle_mask((620, 620), VIEW_C, 310))
    return p


def bowl(p, cx, cy, wd, col, ink, patch=False):
    """A bowl in side elevation, centred at (cx, cy): rim at top, a foot ring below."""
    hw, hh = wd / 2, wd * 0.27
    top = cy - hh
    body = [(cx - hw, top)] + [(cx + hw * math.cos(t), top + hh * 1.7 * math.sin(t))
                               for t in [math.pi * k / 20 for k in range(1, 20)]] + [(cx + hw, top)]
    p.poly(body, col, ink, 2.0)
    p.rect(cx - hw * 0.34, top + hh * 1.62, cx + hw * 0.34, top + hh * 2.0, col, ink, 1.8)
    p.rect(cx - hw - 3, top - 4, cx + hw + 3, top + 2, col, ink, 1.8, r=2)
    if patch:
        s = wd * 0.26
        px, py = cx + hw * 0.1, top + hh * 0.75
        p.rect(px - s / 2, py - s / 2, px + s / 2, py + s / 2, mix(col, STORM_HI, 0.35), ink, 1.8)
        for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            p.ell(px + dx * s * 0.32, py + dy * s * 0.32, 1.6, 1.6, ink, None)


def station_reflection(p, rng, pale_op=1.0):
    pale = mix(PAPER, STORM_HI, 0.2)
    fill_l, line_l = p.layer(), p.layer()
    # office window grid, the lamp before it
    x0, y0, x1, y1 = 360, 150, 520, 280
    fill_l.rect(x0, y0, x1, y1, STORM_HI, None)
    line_l.rect(x0 - 8, y0 - 8, x1 + 8, y1 + 10, None, pale, 3)
    line_l.rect(x0, y0, x1, y1, None, pale, 2.4)
    for i in (1, 2):
        xx = x0 + (x1 - x0) * i / 3
        line_l.line([(xx, y0), (xx, y1)], pale, 2.2)
    line_l.line([(x0, y0 + 60), (x1, y0 + 60)], pale, 3)
    # door frames, stacked, further back
    for (dx0, dy0, dx1, dy1) in ((96, 120, 200, 300), (560, 130, 640, 300)):
        fill_l.rect(dx0, dy0, dx1, dy1, STORM_HI, None)
        line_l.rect(dx0, dy0, dx1, dy1, None, pale, 2.2)
        line_l.rect(dx0 + 16, dy0 + 26, dx1 - 16, dy1 - 6, None, pale, 1.6)
        line_l.rect(dx0 + 32, dy0 + 52, dx1 - 32, dy1 - 10, None, pale, 1.2)
    # the mess table band, y 300-340, x 200-560
    fill_l.rect(200, 316, 560, 340, mix(STORM_HI, PAPER, 0.2), None)
    line_l.rect(200, 316, 560, 340, None, pale, 2.4)
    line_l.line([(200, 324), (560, 324)], pale, 1.2)
    for lx in (214, 546):
        line_l.line([(lx, 340), (lx, 400)], pale, 3)
    p.put(fill_l, 0.5 * pale_op)
    p.put(line_l, 0.72 * pale_op)
    # the bowls; the patched one at the exact centre, plain, clear and paler than the rest
    other = p.layer()
    for bx in (232, 268, 352, 392, 432, 472, 512, 548):
        bowl(other, bx, 306, 30, mix(STORM_HI, PAPER, 0.4), mix(PAPER, STORM_HI, 0.3))
    p.put(other, 0.75 * pale_op)
    bowl(p, VIEW_C[0], VIEW_C[1], 70, mix(PAPER, STORM_HI, 0.25), INK, patch=True)
    # the lamp, warm, before the window
    soft_disc(p, 420, 220, 26, AMBER, 0.35, 8)
    soft_disc(p, 420, 220, 13, mix(AMBER, PAPER_HI, 0.3), 0.45, 3)
    p.ell(420, 220, 8, 8, mix(AMBER, PAPER_HI, 0.25), None)


def paint_view_station(rng):
    p = Pen(620, 620, rng)
    hor = 330
    aperture_base(p, mix(STORM_DK, STORM, 0.4), mix(STORM, SEAGLASS, 0.4), mix(SEAGLASS, STORM, 0.55), STORM_DK, hor)
    chop(p, rng, 0, 620, hor, 620, mix(SEAGLASS_HI, STORM, 0.35), mix(STORM_DK, INK, 0.5), 160, 0.6, 1.5)
    p.line([(-4, hor), (624, hor)], mix(SEAGLASS_HI, PAPER, 0.3), 2.4)
    station_reflection(p, rng)
    # Ada's reflected back of head and shoulder, lower left: stark, no features. The head's right
    # edge crosses y 330 at x 230, so the horizon emerges exactly there.
    # A head of hair seen from behind, pinned up: the bun is what meets the horizon at x 230.
    cx, cy, a, b = 120, 400, 100, 120

    def head_pt(t):
        c, sn = math.cos(t), math.sin(t)
        k = 1 - 0.32 * max(0.0, sn)          # the nape narrows
        return (cx + a * c * k, cy + b * sn)

    head = [head_pt(math.tau * k / 120) for k in range(120)]
    body = [(-10, 488), (150, 488), (160, 528), (196, 552), (236, 584), (256, 630), (-10, 630)]
    p.poly(body, STORM_DK, INK, 2.8)
    p.poly(head, STORM_DK, INK, 2.8)
    p.ell(204, 334, 27, 25, STORM_DK, INK, 2.8)
    p.poly([(176, 316), (196, 350), (214, 372), (196, 386), (160, 370)], STORM_DK, None)
    # a thin rim of window light along the right of the head and bun, so they read on the dark sea
    rim = p.layer()
    rim.arc(204, 334, 25, 23, 250, 400, mix(PAPER, SEAGLASS_HI, 0.4), 2.2)
    rim.line([head_pt(math.radians(d)) for d in range(-20, 62, 3)], mix(PAPER, SEAGLASS_HI, 0.4), 2.2)
    rim.line([(196, 552), (236, 584), (256, 630)], mix(PAPER, SEAGLASS_HI, 0.4), 2.0)
    p.put(rim, 0.42)
    # hair parting and a collar line: shape only
    p.line([(120, 282), (112, 340), (118, 400)], mix(STORM_DK, INK, 0.5), 2.2)
    p.arc(204, 334, 14, 13, 120, 300, mix(STORM_DK, INK, 0.5), 1.8)
    p.line([(150, 520), (164, 534), (200, 556)], mix(STORM_DK, INK, 0.5), 2.0)
    p.clip(circle_mask((620, 620), VIEW_C, 310))
    return p


def paint_view_surface(rng):
    p = Pen(620, 620, rng)
    p.vgrad(0, 0, 620, 620, shade(mix(STORM, STORM_HI, 0.15), 0.9), shade(mix(SEAGLASS, STORM, 0.3), 0.9))
    lay = p.layer()
    pale = mix(PAPER, STORM_HI, 0.3)
    lay.rect(380, 140, 540, 270, None, pale, 2.4)
    lay.line([(433, 140), (433, 270)], pale, 2)
    lay.line([(486, 140), (486, 270)], pale, 2)
    lay.line([(380, 200), (540, 200)], pale, 2.6)
    lay.rect(120, 340, 470, 366, None, pale, 2.2)
    for i in range(9):
        bx = 120 + 35 * (i + 1)
        lay.arc(bx, 340, 13, 13, 180, 360, pale, 1.8)
    lay.rect(90, 120, 190, 330, None, pale, 2)
    lay.rect(110, 160, 170, 320, None, pale, 1.4)
    p.put(lay, 0.36)
    soft_disc(p, 460, 230, 20, AMBER, 0.22, 7)
    p.ell(460, 230, 6, 6, mix(AMBER, PAPER_HI, 0.2), None)
    sheen = p.layer()
    sheen.rect(-10, 380, 630, 470, PAPER_HI, None)
    p.put_soft(sheen, 30, 0.08)
    p.clip(circle_mask((620, 620), VIEW_C, 310))
    return p


def paint_patch(rng):
    p = Pen(280, 280, rng)
    p.vgrad(0, 0, 280, 280, mix(STORM_HI, TIMBER, 0.4), mix(TIMBER_DK, STORM_DK, 0.4))
    # the bowl wall, close: rim across the upper third, soup inside, enamel body below
    rim_y = 104
    p.rect(-10, rim_y - 34, 290, rim_y, SOUP, None)
    p.line([(-10, rim_y - 22), (290, rim_y - 22)], SOUP_HI, 2)
    p.line([(30, rim_y - 12), (120, rim_y - 12)], SOUP_HI, 1.4)
    p.rect(-10, rim_y - 6, 290, rim_y + 8, PAPER_HI, INK, 2.6, r=4)
    p.rect(-10, rim_y + 8, 290, 290, ENAMEL, INK, 2.6)
    p.vgrad(-6, rim_y + 10, 286, 286, ENAMEL, mix(ENAMEL, STORM_HI, 0.35))
    p.line([(-10, rim_y + 8), (290, rim_y + 8)], INK, 2.6)
    # the crack, running out from under the patch
    p.line([(140, rim_y + 8), (134, 136), (146, 150)], INK, 2.2)
    p.line([(152, 222), (146, 240), (158, 262), (150, 290)], INK, 2.2)
    p.line([(118, 196), (96, 204), (84, 222)], INK, 1.6)
    # the square riveted patch
    sh = p.layer()
    sh.rect(104, 150, 196, 232, SHADOW, None)
    p.put_soft(sh, 3, 0.4)
    p.rect(100, 144, 188, 226, mix(STORM_HI, PAPER, 0.35), INK, 2.6)
    p.line([(104, 148), (184, 148)], PAPER_HI, 1.4)
    for x, y in ((112, 156), (176, 156), (112, 214), (176, 214)):
        p.ell(x, y, 5, 5, mix(STORM_HI, PAPER, 0.55), INK, 1.8)
        p.ell(x - 1.4, y - 1.4, 1.6, 1.6, PAPER_HI, None)
    p.clip(circle_mask((280, 280), (140, 140), 130))
    return p


def paint_steam(rng):
    p = Pen(120, 160, rng)
    pts = bezier([(60, 158), (40, 120), (82, 92), (60, 60), (42, 32), (70, 14)], 60)
    lay = p.layer()
    for i, (x, y) in enumerate(pts):
        t = i / (len(pts) - 1)
        r = lerp(9, 4, t)
        lay.ell(x, y, r, r, PAPER_HI, None)
    lay.im = lay.im.convert("RGBa").filter(ImageFilter.GaussianBlur(4 * SS)).convert("RGBA")
    a = lay.im.getchannel("A")
    fade = Image.new("L", (1, 160 * SS))
    for y in range(160 * SS):
        yy = y / SS
        fade.putpixel((0, y), int(255 * min(1.0, yy / 50.0) * min(1.0, (160 - yy) / 26.0)))
    fade = fade.resize(a.size)
    a = ImageChops.multiply(a, fade).point(lambda v: min(120, int(v * 0.6)))
    lay.im.putalpha(a)
    p.put(lay)
    return p


def paint_loupe_ring(rng):
    p = Pen(380, 380, rng)
    sh = p.layer()
    sh.arc(190, 190, 160, 160, 200, 320, PAPER_HI, 10)
    p.put_soft(sh, 4, 0.22)
    p.arc(190, 190, 150, 150, 210, 250, PAPER_HI, 2.4)
    p.ring(190, 190, 170, 186, BRASS, INK, 2.6)
    p.ell(190, 190, 182, 182, None, BRASS_HI, 1.4)
    p.ell(190, 190, 173, 173, None, BRASS_LO, 1.6)
    return p


def paint_frame_mounted(rng):
    """Nora's specimen frame, face-on, in R07's c_frame style, at 400x280."""
    felt_dk = mix(SEAGLASS_HI, SEAGLASS, 0.55)
    slot = mix(STORM, SOOT, 0.6)
    p = Pen(400, 280, rng)
    p.rect(2, 2, 398, 278, BRASS, INK, 3, r=6)
    p.rect(7, 7, 393, 273, None, BRASS_HI, 1.6, r=5)
    for i in range(3):
        sx = 16 + i * 125
        p.rect(sx, 18, sx + 118, 170, felt_dk, INK, 2.2, r=3)
        p.rect(sx + 2, 20, sx + 116, 26, slot, None)
    # name tab, the clip holding a strip, the label strip
    p.rect(16, 190, 136, 260, mix(BRASS_LO, slot, 0.35), INK, 2.2, r=3)
    p.rect(18, 192, 134, 198, slot, None)
    p.rect(150, 190, 260, 260, BRASS_LO, INK, 2.2, r=3)
    p.rect(158, 214, 252, 252, PAPER_HI, INK, 1.6)       # the strip under the clip
    for x in range(162, 252, 8):
        p.ell(x, 248, 1.4, 1.4, mix(PAPER, INK, 0.4), None)
    p.rect(150, 202, 260, 214, BRASS_HI, INK, 2.0, r=3)
    for x in (172, 238):
        p.rect(x - 7, 196, x + 7, 224, BRASS, INK, 1.8, r=3)
        p.ell(x, 198, 4.4, 4.4, BRASS_HI, INK, 1.4)
    plate(p, 276, 196, 382, 254)
    for x, y in ((10, 10), (390, 10), (10, 270), (390, 270)):
        screw(p, x, y, 3.4)
    return p


def paint_sel_knob(rng):
    p = Pen(90, 90, rng)
    c = (45, 45)
    sh = p.layer()
    sh.ell(48, 49, 38, 38, SHADOW, None)
    p.put_soft(sh, 2.5, 0.45)
    p.ell(45, 45, 38, 38, BRASS, INK, 2.4)
    for a in range(0, 360, 12):
        p.line([polar(c, 33, a), polar(c, 37, a)], BRASS_DK, 1.4)
    p.ell(45, 45, 28, 28, BRASS_LO, INK, 1.8)
    p.ell(45, 45, 22, 22, BRASS, INK, 1.4)
    p.arc(45, 45, 18, 18, 200, 290, BRASS_HI, 3)
    # the pointer
    p.rect(42, 10, 48, 32, BRASS_HI, INK, 1.6, r=2)
    return p


def paint_key(rng, down):
    p = Pen(280, 96, rng)
    if not down:
        p.rect(14, 46, 266, 90, BRASS_LO, INK, 2.4, r=6)
        p.rect(10, 6, 270, 66, BRASS, INK, 2.6, r=10)
        p.rect(20, 12, 260, 58, ENAMEL, mix(INK, BRASS, 0.5), 1.8, r=8)
        p.line([(28, 16), (252, 16)], PAPER_HI, 1.6)
        p.line([(14, 64), (266, 64)], BRASS_HI, 1.4)
    else:
        p.rect(14, 58, 266, 90, BRASS_DK, INK, 2.4, r=6)
        p.rect(10, 24, 270, 84, BRASS_LO, INK, 2.6, r=10)
        p.rect(20, 30, 260, 76, mix(ENAMEL, STORM_HI, 0.12), mix(INK, BRASS, 0.5), 1.8, r=8)
        sh = p.layer()
        sh.rect(16, 26, 264, 40, SHADOW, None)
        p.put_soft(sh, 3, 0.45, None)
        # the collar the key sank into
        p.rect(4, 14, 276, 28, BRASS, INK, 2.4, r=4)
        p.line([(8, 18), (272, 18)], BRASS_HI, 1.4)
    return p


def paint_strip(rng):
    p = Pen(300, 80, rng)
    pts = [(0, 6), (270, 6)]
    y = 6
    r = random.Random(SEED + 777)
    tear = []
    while y < 74:
        tear.append((270 + r.uniform(4, 22), y))
        y += r.uniform(5, 10)
    tear.append((272, 74))
    p.poly(pts + tear + [(0, 74)], PAPER_HI, INK, 1.8)
    for x in range(10, 268, 12):
        p.ell(x, 14, 2.2, 2.2, mix(PAPER, INK, 0.45), None)
    p.line([(4, 22), (264, 22)], mix(PAPER, SEAGLASS, 0.3), 1.0)
    return p


# ----------------------------------------------------------------------------- close-up plates

def backboard(p, rng):
    p.vgrad(0, 0, W, H, STORM, mix(STORM, STORM_DK, 0.6))
    lay = p.layer()
    for _ in range(18):
        lay.ell(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(80, 200), rng.uniform(40, 90), STORM_HI, None)
    p.put_soft(lay, 30, 0.18)
    p.rect(20, 20, W - 20, H - 20, None, STORM_HI, 3, r=8)
    p.rect(26, 26, W - 26, H - 26, None, INK, 1.6, r=6)
    for x in range(60, W - 40, 80):
        rivet(p, x, 40, 3)
        rivet(p, x, H - 40, 3)
    for y in range(120, H - 80, 80):
        rivet(p, 40, y, 3)
        rivet(p, W - 40, y, 3)


def paint_c_scope(rng):
    p = Pen(W, H, rng, STORM)
    backboard(p, rng)

    def shadow(x0, y0, x1, y1, r=0):
        sh = p.layer()
        sh.rect(x0 + 6, y0 + 8, x1 + 6, y1 + 8, SHADOW, None, r=r)
        p.put_soft(sh, 6, 0.45)

    # clamp mount, jaws open: a brass back plate, the recess, two jaws on a screw
    shadow(90, 150, 530, 480, 8)
    p.rect(90, 150, 530, 480, BRASS_LO, INK, 3, r=8)
    p.rect(98, 158, 522, 472, None, BRASS, 2, r=6)
    p.rect(110, 186, 510, 434, mix(STORM_DK, SOOT, 0.4), INK, 2.4, r=4)
    for x0, x1 in ((96, 524),):
        pass
    p.rect(104, 152, 516, 172, BRASS, INK, 2.4, r=3)       # top jaw, raised
    p.line([(108, 156), (512, 156)], BRASS_HI, 1.6)
    p.rect(104, 458, 516, 478, BRASS, INK, 2.4, r=3)       # bottom jaw
    p.line([(108, 462), (512, 462)], BRASS_HI, 1.6)
    for x in (130, 490):
        p.rect(x - 6, 172, x + 6, 458, BRASS_DK, INK, 1.8)  # screw rods: the jaws open on them
        for y in range(184, 452, 10):
            p.line([(x - 5, y), (x + 5, y + 4)], BRASS, 1.0)
    for x, y in ((98, 160), (522, 160), (98, 470), (522, 470)):
        screw(p, x, y, 4)
    # selector detent plate: a slot track with three detents
    shadow(90, 640, 530, 800, 6)
    p.rect(90, 640, 530, 800, BRASS, INK, 3, r=6)
    p.line([(96, 646), (524, 646)], BRASS_HI, 1.8)
    p.rect(150, 695, 470, 715, GLASS_DK, INK, 2.2, r=10)
    for x in (160, 310, 460):
        p.ell(x, 705, 22, 22, GLASS_DK, INK, 2.2)
        p.arc(x, 705, 18, 18, 20, 160, IRON_LO, 3)
        p.arc(x, 705, 25, 25, 200, 340, BRASS_HI, 1.4)
    for x0, x1 in ((100, 220), (250, 370), (400, 520)):
        plate(p, x0, 760, x1, 792)
    for x, y in ((100, 652), (520, 652)):
        screw(p, x, y, 4)
    # eyepiece housing: an iron collar with bolts, a black interior
    cx, cy = EYE_C
    sh = p.layer()
    sh.ell(cx + 8, cy + 10, 376, 376, SHADOW, None)
    p.put_soft(sh, 10, 0.5)
    p.ell(cx, cy, 374, 374, IRON, INK, 3)
    p.ell(cx, cy, 366, 366, None, IRON_HI, 1.6)
    for a in range(0, 360, 30):
        x, y = polar((cx, cy), 357, a + 15)
        screw(p, x, y, 5, IRON_HI)
    p.ell(cx, cy, 344, 344, BRASS_LO, INK, 2.4)
    p.ell(cx, cy, EYE_R, EYE_R, INK, INK, 2)
    # caption plate
    plate(p, 630, 104, 1250, 148)
    # record key well
    shadow(620, 820, 920, 930, 6)
    p.rect(620, 820, 920, 930, BRASS_LO, INK, 3, r=6)
    p.rect(632, 830, 908, 920, mix(SOOT, STORM_DK, 0.5), INK, 2.2, r=6)
    p.line([(636, 834), (904, 834)], IRON_LO, 3)
    # strip slot and its slit
    shadow(940, 820, 1260, 930, 6)
    p.rect(940, 820, 1260, 930, BRASS, INK, 3, r=6)
    p.line([(946, 826), (1254, 826)], BRASS_HI, 1.8)
    p.rect(956, 850, 1250, 910, BRASS_LO, INK, 2.0, r=4)
    p.rect(946, 858, 954, 902, GLASS_DK, INK, 1.8, r=2)
    p.line([(947, 860), (947, 900)], IRON_LO, 1.4)
    # reference plate
    shadow(90, 820, 530, 930, 4)
    p.rect(84, 814, 536, 936, BRASS_LO, INK, 2.6, r=4)
    p.rect(90, 820, 530, 930, ENAMEL, mix(INK, BRASS_LO, 0.5), 1.6, r=2)
    for x, y in ((98, 828), (522, 828), (98, 922), (522, 922)):
        screw(p, x, y, 3.6)
    return p


def paint_c_ruler(rng):
    p = Pen(W, H, rng, TIMBER)
    # sill timber, front elevation: long grain
    p.vgrad(0, 0, W, H, TIMBER_HI, TIMBER_DK)
    lay = p.layer()
    for _ in range(90):
        y = rng.uniform(0, H)
        x = rng.uniform(-200, W)
        ln = rng.uniform(200, 700)
        lay.line([(x, y), (x + ln * 0.5, y + rng.uniform(-3, 3)), (x + ln, y)], TIMBER_DK, rng.uniform(1, 2.4))
    p.put(lay, 0.45)
    p.line([(-4, 330), (W + 4, 330)], TIMBER_DK, 3)
    p.line([(-4, 334), (W + 4, 334)], mix(TIMBER_HI, PAPER, 0.3), 1.6)
    # the rule
    sh = p.layer()
    sh.rect(108, 430, 1356, 572, SHADOW, None, r=4)
    p.put_soft(sh, 8, 0.5)
    p.rect(100, 420, 1348, 560, BOXWOOD, INK, 3, r=4)
    p.vgrad(104, 424, 1344, 556, mix(BOXWOOD, PAPER_HI, 0.4), mix(BOXWOOD, BOXWOOD_DK, 0.5))
    for _ in range(14):
        y = rng.uniform(470, 552)
        p.line([(rng.uniform(130, 1200), y), (rng.uniform(1210, 1320), y + rng.uniform(-1, 1))],
               mix(BOXWOOD, BOXWOOD_DK, 0.7), 1.0)
    p.rect(100, 420, 1348, 560, None, INK, 3, r=4)
    ruler_ticks(p, 140, 1292, 422, 96, 64, 2.2)
    # scratch burrs: the eighths cut deeper than the print
    burr = p.layer()
    for i in range(12 * 8 + 1):
        x = 140 + i * 12
        if i % 8:
            burr.line([(x - 1.6, 424), (x - 1.6, 440)], mix(BOXWOOD_DK, INK, 0.5), 1.0)
    p.put(burr, 0.6)
    for x0, x1 in ((100, 130), (1318, 1348)):
        p.rect(x0, 416, x1, 564, BRASS, INK, 2.6, r=3)
        p.line([(x0 + 5, 422), (x0 + 5, 558)], BRASS_HI, 1.8)
        screw(p, (x0 + x1) / 2, 490, 4.4)
    # magnifier well
    cx, cy, r = 560, 760, 180
    sh = p.layer()
    sh.ell(cx + 6, cy + 8, r + 16, r + 16, SHADOW, None)
    p.put_soft(sh, 8, 0.5)
    p.ell(cx, cy, r + 14, r + 14, BRASS_LO, INK, 3)
    p.ell(cx, cy, r + 9, r + 9, None, BRASS_HI, 1.4)
    p.ell(cx, cy, r, r, PAPER_HI, INK, 2.6)
    p.arc(cx, cy, r - 10, r - 10, 200, 250, (255, 255, 255), 3)
    # two blank button plates
    for x0, x1 in ((1000, 1160), (1180, 1340)):
        sh = p.layer()
        sh.rect(x0 + 5, 707, x1 + 5, 827, SHADOW, None, r=10)
        p.put_soft(sh, 5, 0.45)
        p.rect(x0, 700, x1, 820, BRASS, INK, 2.8, r=10)
        p.rect(x0 + 12, 712, x1 - 12, 808, ENAMEL, mix(INK, BRASS, 0.5), 1.8, r=6)
        p.line([(x0 + 18, 716), (x1 - 18, 716)], PAPER_HI, 1.4)
    return p


# ============================================================================= repaint pass (r2)
# Art direction review of 61cf868. Every repainted asset is a NEW file (suffix _r2); the functions
# above are left exactly as they were, so a full rerun still writes the earlier files byte for byte.
#
# The upright sea is now built in layers the view composes, so the reveal can stand it up:
#   <v>_surf_<stage>_r2   the standing plane (opaque; b4 keeps the storm sky above its top edge)
#   vchop_tile_r2         the b3 whitecap dash turned 90 degrees: crests run top to bottom (tileable,
#                         the view drifts it sideways)
#   <v>_refl_<stage>_r2   the rooms behind Ada as filled flat silhouettes with a 6 px navy contour

CONTOUR = 6.0               # navy contour on the reflected silhouettes, as on the office props
REFL_PANE = mix(SEAGLASS_HI, SEAGLASS, 0.35)     # the office window: a sea-glass pane
REFL_SLAB = STORM_DK                             # doors: storm-navy slabs
REFL_JAMB = mix(STORM_HI, SEAGLASS, 0.45)
REFL_PALE = mix(PAPER, SEAGLASS_HI, 0.18)        # the bowl shelf: a paper-pale row
LAMP_WARM = mix(AMBER, PAPER_HI, 0.25)
LAMP_COOL = mix(PAPER_HI, AMBER, 0.18)           # band 6: the lamp cooling toward paper-white


def surf2_cols(stage):
    if stage == "b4o":
        return shade(mix(STORM, STORM_HI, 0.15), 0.9), shade(mix(SEAGLASS, STORM, 0.3), 0.9)
    if stage == "b6":
        return mix(STORM, STORM_DK, 0.3), mix(SEAGLASS, STORM, 0.42)
    if stage == "b7":
        return mix(STORM_DK, STORM, 0.2), mix(STORM, SEAGLASS, 0.3)
    return mix(STORM, STORM_HI, 0.15), mix(SEAGLASS, STORM, 0.3)


def paint_surf2(rng, view, stage):
    """The standing plane: matte storm teal, darker at the top, with broad vertical banding."""
    top = (A_SURF_TOP if view == "a" else B_SURF_TOP) if stage in ("b4", "b4o") else 0
    bot = 640 if view == "a" else 770
    p = Pen(W, H, rng, STORM)
    if top > 0:
        sky = sea_storm(rng_for(900 + (0 if view == "a" else 1)), view)
        p.im.paste(sky.im.crop((0, 0, W * SS, int(top * SS))), (0, 0))
    c0, c1 = surf2_cols(stage)
    p.vgrad(0, top, W, H, c0, c1, top, bot)
    # standing water: soft vertical columns, paler and darker, like a sea seen on end
    lay = p.layer()
    x = -40.0
    while x < W + 40:
        wd = rng.uniform(30, 90)
        col = PAPER_HI if rng.random() < 0.5 else STORM_DK
        lay.rect(x, top, x + wd, H, col, None)
        x += wd + rng.uniform(40, 140)
    p.put_soft(lay, 18, 0.07 if stage != "b7" else 0.04)
    if top > 0:
        # the edge: ruler straight, a cut, then a hairline of light along it
        p.line([(-4, top), (W + 4, top)], INK, 3.0)
        p.line([(-4, top + 3), (W + 4, top + 3)], mix(c0, PAPER_HI, 0.45), 1.6)
    return p


def vcrest(p, x, y, ln, ht, light, dark, lean=1):
    """One b3 whitecap dash turned 90 degrees: the pale back points sideways, the trough runs down."""
    p.poly([(x, y - ln / 2), (x + lean * ht, y - ln * 0.08), (x, y + ln / 2)], light, None)
    p.line([(x - lean * 0.9, y - ln * 0.45), (x - lean * 0.9, y + ln * 0.55)], dark, 1.4)


def paint_vchop_tile(rng):
    """Tileable 512x512: the b3 chop rotated so the crests run top to bottom. Each crest keeps the
    b3 shape (a pale back, a dark trough line) but stands on end; wide enough never to read as rain."""
    sz = 512
    lt, dk = Pen(sz, sz, rng), Pen(sz, sz, rng)
    light, dark = mix(SEAGLASS_HI, STORM_HI, 0.15), mix(STORM_DK, INK, 0.55)
    for _ in range(46):
        x, y = rng.uniform(0, sz), rng.uniform(0, sz)
        ln = rng.uniform(44, 118)
        ht = rng.uniform(5.5, 10.5)
        for ox in (-sz, 0, sz):
            for oy in (-sz, 0, sz):
                cx, cy = x + ox, y + oy
                lt.poly([(cx, cy - ln / 2), (cx + ht * 0.55, cy - ln * 0.2), (cx + ht, cy + ln * 0.05),
                         (cx + ht * 0.4, cy + ln * 0.32), (cx, cy + ln / 2)], light, None)
                dk.line([(cx - 1.6, cy - ln * 0.46), (cx - 1.6, cy + ln * 0.56)], dark, 2.6)
    out = Pen(sz, sz, rng)
    out.put(dk, 0.7)
    out.put(lt, 0.62)
    return out


# --- the reflections ------------------------------------------------------------------------------
# Specs in game space. "lamp" is (x, y, colour); "rail_inv" is the gallery rail hung upside down
# above the real one (band 6, the compressed horizon).
A_REFL2 = {
    "window": (110, 250, 330, 410), "lamp": (220, 322, LAMP_WARM),
    "shelf": (226, 470, 560, 500),
    "doors": [(1236, 236, 1320, 600), (404, 236, 484, 470)],
    "floor": (52, 1396, 600),
}
A_REFL2_B6 = {
    "window": (66, 196, 352, 404), "lamp": (209, 300, LAMP_COOL),
    "shelf": (78, 456, 500, 494),
    "doors": [(1300, 196, 1392, 640), (402, 222, 494, 484), (958, 210, 1048, 600)],
    "floor": (52, 1396, 616),
    "lighthouse": (1196, 176, 2.74),
    "rail_inv": {"top": 560, "posts": [80 + 168 * k for k in range(9)], "rails": [(548, 560), (516, 524)],
                 "post_top": 492},
}
B_REFL2 = {
    "window": (760, 230, 1000, 390), "lamp": (880, 304, LAMP_WARM),
    "shelf": (120, 470, 440, 500),
    "doors": [(560, 206, 700, 640), (1290, 260, 1370, 520)],
    "floor": (60, 1388, 690),
}
B_REFL2_B6 = {
    "window": (104, 186, 416, 394), "lamp": (260, 290, LAMP_COOL),
    "shelf": (96, 468, 472, 506),
    "doors": [(1236, 188, 1372, 660), (546, 250, 628, 560)],
    "floor": (60, 1388, 700),
    "lighthouse": (724, 104, 2.48),
    "rail_inv": {"top": 610, "posts": [100 + 190 * k for k in range(8)], "rails": [(594, 610), (542, 552)],
                 "post_top": 476},
}


def refl_window(p, x0, y0, x1, y1, lamp):
    ink = INK
    p.rect(x0 - 12, y0 - 12, x1 + 12, y1 + 14, REFL_JAMB, ink, CONTOUR)          # the frame
    p.rect(x0, y0, x1, y1, REFL_PANE, ink, CONTOUR * 0.8)
    # a faint paler upper sash, so the pane reads as glass, not a card
    p.rect(x0 + 4, y0 + 4, x1 - 4, y0 + (y1 - y0) * 0.42, mix(REFL_PANE, PAPER_HI, 0.18), None)
    for i in (1, 2):
        xx = x0 + (x1 - x0) * i / 3
        p.line([(xx, y0), (xx, y1)], ink, 5.0)
    ym = y0 + (y1 - y0) * 0.45
    p.line([(x0, ym), (x1, ym)], ink, 6.0)
    p.line([(x0, y0 + (ym - y0) / 2), (x1, y0 + (ym - y0) / 2)], ink, 3.2)
    p.line([(x0, ym + (y1 - ym) / 2), (x1, ym + (y1 - ym) / 2)], ink, 3.2)
    if lamp:
        lx, ly, col = lamp
        soft_disc(p, lx, ly, 34, col, 0.45, 10)
        soft_disc(p, lx, ly, 17, mix(col, PAPER_HI, 0.3), 0.6, 4)
        p.ell(lx, ly, 10, 10, mix(col, PAPER_HI, 0.35), ink, 2.0)


def refl_door(p, x0, y0, x1, y1):
    p.rect(x0 - 10, y0 - 10, x1 + 10, y1, REFL_JAMB, INK, CONTOUR)
    p.rect(x0, y0, x1, y1, REFL_SLAB, INK, CONTOUR * 0.8)
    # two sunk panels and a knob: still a slab at a glance
    w, h = x1 - x0, y1 - y0
    p.rect(x0 + w * 0.2, y0 + h * 0.08, x1 - w * 0.2, y0 + h * 0.44, mix(REFL_SLAB, STORM, 0.5), INK, 2.4)
    p.rect(x0 + w * 0.2, y0 + h * 0.54, x1 - w * 0.2, y1 - h * 0.06, mix(REFL_SLAB, STORM, 0.5), INK, 2.4)
    p.ell(x1 - w * 0.13, y0 + h * 0.5, max(3.0, w * 0.05), max(3.0, w * 0.05), BRASS, INK, 1.6)


def refl_shelf(p, x0, y0, x1, y1):
    p.rect(x0, y0, x1, y1, REFL_PALE, INK, CONTOUR * 0.8)
    p.line([(x0 + 4, y0 + 8), (x1 - 4, y0 + 8)], mix(REFL_PALE, INK, 0.3), 1.6)
    for lx in (x0 + 18, x1 - 18):
        p.rect(lx - 5, y1, lx + 5, y1 + 60, REFL_PALE, INK, 3.0)
    step = (x1 - x0) / 10
    br = min(17, step * 0.44)
    for i in range(9):
        bx = x0 + step * (i + 1)
        # a bowl seen side on sits on the shelf: rim up, so the arc is under the rim line
        pts = [(bx - br * 1.08, y0 - br * 0.82), (bx + br * 1.08, y0 - br * 0.82)] + \
              [(bx + br * math.cos(t), y0 - br * 0.82 + br * 0.82 * math.sin(t))
               for t in [math.pi * k / 14 for k in range(0, 15)]]
        p.poly(pts, REFL_PALE, INK, 3.0)


def refl_rail_inv(p, spec):
    lay = p.layer()
    col = mix(STORM_DK, STORM, 0.4)
    for y0, y1 in spec["rails"]:
        lay.rect(-4, y0, W + 4, y1, col, INK, 2.0)
    for x in spec["posts"]:
        lay.rect(x - 5, spec["post_top"], x + 5, spec["top"], col, INK, 2.0)
    p.put(lay, 0.62)


def paint_refl2(rng, spec, opacity=1.0):
    p = Pen(W, H, rng)
    lay = p.layer()
    fx0, fx1, fy = spec["floor"]
    lay.line([(fx0, fy), (fx1, fy)], INK, 3.0)
    for d in spec["doors"]:
        refl_door(lay, *d)
    refl_shelf(lay, *spec["shelf"])
    refl_window(lay, *spec["window"], spec["lamp"])
    if "rail_inv" in spec:
        refl_rail_inv(lay, spec["rail_inv"])
    if "lighthouse" in spec:
        cx, by, s = spec["lighthouse"]
        inv_lighthouse2(lay, cx, by, s)
    p.put(lay, opacity)
    return p


def inv_lighthouse2(p, cx, base_y, s):
    """The lighthouse hung upside down, filled flat, navy contour; its lantern lit."""
    lighthouse(p, cx, base_y, s, inv=True, white=mix(PAPER, SEAGLASS_HI, 0.3), band=STORM,
               glass=mix(STORM, SEAGLASS, 0.35), ink=INK, lw=4.5)
    ly = base_y + s * (432 - 330.5)
    soft_disc(p, cx, ly, 12 * s, AMBER, 0.4, 7)
    p.rect(cx - 5 * s, ly - 5.5 * s, cx + 5 * s, ly + 5.5 * s, AMBER, INK, 2.0)
    p.rect(cx - 2.2 * s, ly - 3.2 * s, cx + 2.2 * s, ly + 3.2 * s, mix(AMBER, PAPER_HI, 0.5), None)


# --- band 7: no edge --------------------------------------------------------------------------------

def paint_b7_2(rng, view):
    p = paint_surf2(rng, view, "b7")
    centre, r = (724, 1900), 1500
    c0, c1 = surf2_cols("b7")
    base = mix(c0, c1, 0.5)
    # under the curve: the body of the thing, a shade darker
    inner = p.layer()
    inner.ell(centre[0], centre[1], r, r, shade(base, 0.8), None)
    p.put_soft(inner, 24, 0.9)
    # concentric rings above: the curvature carries on past the window
    for k, (dr, a, w) in enumerate(((90, 0.34, 4.0), (200, 0.24, 3.4), (330, 0.16, 3.0))):
        ring = p.layer()
        ring.arc(centre[0], centre[1], r + dr, r + dr, 180, 360, mix(SEAGLASS_HI, PAPER, 0.25), w)
        p.put_soft(ring, 1.4, a)
    # the arc: a 16 px wet highlight, sea-glass below turning to paper-white along its crest
    glow = p.layer()
    glow.arc(centre[0], centre[1], r - 10, r - 10, 180, 360, SEAGLASS_HI, 26)
    p.put_soft(glow, 10, 0.35)
    band = p.layer()
    steps = 16
    for i in range(steps):
        t = i / (steps - 1)
        band.arc(centre[0], centre[1], r - 8 + i, r - 8 + i, 180, 360, mix(SEAGLASS_HI, PAPER_HI, t ** 1.3), 1.6)
    p.put_soft(band, 0.6, 0.95)
    p.arc(centre[0], centre[1], r + 8.5, r + 8.5, 180, 360, INK, 2.2)
    p.arc(centre[0], centre[1], r - 9.5, r - 9.5, 180, 360, mix(INK, SEAGLASS, 0.4), 1.4)
    if view == "a":
        lantern_housing(p, A_HOUSING[0], A_HOUSING[1], 56)
    else:
        lantern_housing(p, 724, 300, 56)
    return p


# --- view B, band 3: the headland moved clear of the pennant staff -----------------------------------

def paint_b_sea_b3_2(rng, grey=False):
    """sea_storm(rng, "b") (or its ending-A grey), with the headland moved clear of the staff."""
    hor = B_HOR
    if grey:
        sky0, sky1, sea0, sea1 = GREY_SKY0, GREY_SKY1, GREY_SEA0, GREY_SEA1
        land = GREY_LAND
        cloud = mix(GREY_SKY1, PAPER_HI, 0.35)
        light, dark = mix(GREY_SKY1, PAPER_HI, 0.45), mix(GREY_SEA1, INK, 0.4)
        white, band, glass = mix(PAPER, GREY_SKY1, 0.25), mix(STORM_HI, GREY_LAND, 0.4), mix(GREY_LAND, GREY_SKY1, 0.4)
        stone = mix(PAPER, GREY_LAND, 0.45)
    else:
        sky0, sky1 = STORM_DK, mix(STORM_HI, SEAGLASS, 0.55)
        sea0, sea1 = mix(SEAGLASS, STORM, 0.45), mix(STORM, STORM_DK, 0.5)
        land = mix(STORM_DK, SEAGLASS, 0.18)
        cloud = mix(STORM_HI, PAPER, 0.32)
        light, dark = mix(SEAGLASS_HI, PAPER, 0.25), mix(STORM_DK, INK, 0.5)
        white, band, glass = mix(PAPER, STORM_HI, 0.22), STORM, mix(STORM, SEAGLASS, 0.35)
        stone = mix(PAPER, STORM, 0.55)
    p = Pen(W, H, rng, sky0)
    p.vgrad(0, 0, W, hor, sky0, sky1, 0, hor)
    clouds(p, rng, 60, hor - 70, cloud, 0.58 if not grey else 0.5, 11)
    clouds(p, rng, hor - 120, hor - 30, mix(cloud, sky1, 0.4), 0.35, 7, 240, 520)
    p.vgrad(0, hor, W, H, sea0, sea1, hor, H)
    lay = p.layer()
    lay.rect(-4, hor, W + 4, hor + 26, mix(sea0, sky1, 0.5), None)
    p.put_soft(lay, 8, 0.45)
    chop(p, rng, 0, W, hor, H, light, dark, 520)
    dx = -340
    headland(p, [(1110 + dx, hor), (1150 + dx, hor - 14), (1200 + dx, hor - 24), (1300 + dx, hor - 26),
                 (1336 + dx, hor - 14), (1372 + dx, hor)], land)
    lighthouse(p, 1258 + dx, hor - 25, 55 / 140, white=white, band=band, glass=glass, lw=1.4)
    causeway(p, [(690, 736), (748, 772)], hor + 4, 7, stone, broken_at=690 - 2)
    p.line([(-4, hor), (W + 4, hor)], mix(INK, sea0, 0.25), 2.0)
    return p


# --- lid band, beads, sparse rain --------------------------------------------------------------------

def paint_lid_band(rng):
    """An eyelid edge: storm navy with a feathered top and a wet paper-white rim along the bottom.
    Rim (bottom edge) at y 92 of 100."""
    w, h = 1344, 100
    p = Pen(w, h, rng)
    # feather: the top 40 px fade in
    alpha = Image.new("L", (1, h * SS))
    for sy in range(h * SS):
        y = sy / SS
        a = 0.0
        if y < 44:
            a = max(0.0, (y - 4) / 40.0) ** 1.6
        elif y <= 92:
            a = 1.0
        alpha.putpixel((0, sy), int(255 * a))
    navy = Image.new("RGBA", (w * SS, h * SS), rgba(STORM_DK))
    navy.putalpha(alpha.resize((w * SS, h * SS)))
    p.im.alpha_composite(navy)
    # a slightly lighter lower half, so it reads as a curved lid, not a slot
    lid = p.layer()
    lid.rect(-10, 62, w + 10, 86, mix(STORM_DK, STORM_HI, 0.45), None)
    p.put_soft(lid, 6, 0.6)
    # the wet rim
    p.rect(-10, 85, w + 10, 92, mix(PAPER_HI, SEAGLASS_HI, 0.15), None, 0)
    p.line([(-10, 86.5), (w + 10, 86.5)], (246, 242, 230), 1.6)
    p.line([(-10, 92.5), (w + 10, 92.5)], INK, 2.0)
    # beads along the rim
    x = rng.uniform(6, 30)
    while x < w:
        r = rng.uniform(2.0, 3.4)
        p.ell(x, 93 + r * 0.7, r, r * 1.2, mix(PAPER_HI, SEAGLASS_HI, 0.2), INK, 1.0)
        x += rng.uniform(26, 70)
    return p


def paint_beads(rng):
    """The dry-rail clue: a hard row of hanging drops where the rain stops. Line at y 6 of 26."""
    w, h = 1344, 26
    p = Pen(w, h, rng)
    x = 9.0
    while x < w - 4:
        r = rng.uniform(2.2, 2.7)
        y = 6 + r * 0.9 + rng.uniform(-0.6, 0.6)
        p.ell(x, y, r, r * 1.18, PAPER_HI, INK, 1.1)
        p.ell(x - r * 0.35, y - r * 0.35, r * 0.4, r * 0.4, (250, 248, 240), None)
        if rng.random() < 0.18:
            ln = rng.uniform(4, 9)
            p.line([(x, y + r), (x, y + r + ln)], PAPER_HI, 1.2)
            p.ell(x, y + r + ln + 1.4, 1.5, 1.9, PAPER_HI, INK, 0.8)
        x += 18 + rng.uniform(-1.5, 1.5)
    return p


def paint_rain_sparse(rng):
    im = Image.new("RGBA", (512 * SS, 512 * SS), (0, 0, 0, 0))
    for _ in range(85):
        x = rng.uniform(0, 512)
        y = rng.uniform(0, 512)
        ln = rng.uniform(18, 60)
        dx = ln * 0.08
        a = rng.randint(60, 110)
        wd = rng.choice((1, 1, 1.5, 2))
        lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        for ox in (-512, 0, 512):
            for oy in (-512, 0, 512):
                d.line([((x + ox) * SS, (y + oy) * SS), ((x + ox + dx) * SS, (y + oy + ln) * SS)],
                       fill=PAPER_HI + (a,), width=max(1, int(wd * SS)))
        im.alpha_composite(lay)
    return im.resize((512, 512), Image.LANCZOS)


# --- the lens, band 5 on: the standing surface, inverted -------------------------------------------

def lens2(p, rng, stage):
    """lens() with the panes in its inverted gallery showing the standing surface."""
    cx, cy = LENS_C
    inner = p.layer()
    inner.vgrad(cx - LENS_IN, cy - LENS_IN, cx + LENS_IN, cy + LENS_IN,
                mix(IRON, SEAGLASS, 0.35), mix(SEAGLASS, COPPER_DK, 0.4))
    k = 0.37

    def ly(y):
        return cy + (543 - y) * k

    def lx(x):
        return cx + (x - 724) * k

    inner.rect(cx - 220, ly(1086), cx + 220, ly(900), IRON, None)
    for i in range(10):
        yy = ly(900) - 6 - i * 7
        if yy > ly(1086):
            inner.line([(cx - 220, yy), (cx + 220, yy)], IRON_HI, 1.2)
    inner.rect(cx - 220, ly(900), cx + 220, ly(644), mix(STORM, SEAGLASS, 0.2), None)
    inner.rect(cx - 220, ly(644), cx + 220, ly(628), BRASS_LO, None)
    # the panes: the standing surface, upside down, darker at the bottom now
    s0, s1 = surf2_cols(stage)
    inner.vgrad(cx - 220, ly(628), cx + 220, ly(162), s1, s0)
    # inverted reflections inside it: the shelf hangs from its line, the window under it, the lamp
    pale, ink = REFL_PALE, INK
    inner.rect(cx - 150, 404, cx + 70, 410, pale, ink, 1.6)
    for i in range(7):
        bx = cx - 135 + i * 30
        inner.d.chord(((bx - 10) * SS, (410 - 9) * SS, (bx + 10) * SS, (410 + 9) * SS), 0, 180, fill=rgba(pale))
    inner.rect(cx + 40, 440, cx + 118, 498, REFL_PANE, ink, 2.2)
    inner.line([(cx + 66, 440), (cx + 66, 498)], ink, 1.8)
    inner.line([(cx + 92, 440), (cx + 92, 498)], ink, 1.8)
    inner.line([(cx + 40, 472), (cx + 118, 472)], ink, 2.2)
    inner.rect(cx - 112, 430, cx - 78, 520, REFL_SLAB, ink, 2.0)
    for bx in A_BARS:
        inner.rect(lx(bx - 12), ly(628), lx(bx + 12), ly(162), BRASS_LO, None)
    inner.rect(cx - 220, ly(162), cx + 220, ly(150), BRASS_LO, None)
    inner.rect(cx - 220, ly(150), cx + 220, ly(0) + 40, COPPER_LO, None)
    inner.rect(lx(470), ly(830), lx(978), ly(650), IRON, None)
    inner.rect(lx(470), ly(800), lx(978), ly(650), BRASS_LO, None)
    for (px, py) in PORTS:
        inner.ell(lx(px), ly(py), PORT_R * k, PORT_R * k, IRON_LO, None)
    inner.ell(cx, ly(392), LENS_R * k, LENS_R * k, mix(SEAGLASS, IRON, 0.4), None)
    inner.im = inner.im.filter(ImageFilter.GaussianBlur(0.8 * SS))
    # the warm point, crisp, after the blur
    lamp = LAMP_COOL if stage == "b6" else LAMP_WARM
    soft_disc(inner, cx + 79, 486, 14, AMBER, 0.55, 5)
    inner.ell(cx + 79, 486, 5.5, 5.5, lamp, None)
    disc = circle_mask((W, H), (cx, cy), LENS_IN)
    lay = p.layer()
    lay.ell(cx, cy, LENS_IN, LENS_IN, mix(SEAGLASS, STORM, 0.35), None)
    p.put(lay)
    p.put(inner, 0.8, disc)
    bounds = [200, 172, 144, 116, 88, 60, 32]
    facets = p.layer()
    for r in bounds:
        facets.arc(cx, cy, r - 7, r - 7, 200, 340, SEAGLASS_HI, 3.2)
        facets.arc(cx, cy, r - 5, r - 5, 30, 150, IRON_LO, 3.0)
    facets.ell(cx - 9, cy - 10, 10, 6, PAPER_HI, None)
    p.put(facets, 0.36, disc)
    for r in bounds[1:]:
        p.ell(cx, cy, r, r, None, BRASS_LO, 4.4)
        p.ell(cx, cy, r, r, None, INK, 1.2)
        p.arc(cx, cy, r + 1.4, r + 1.4, 200, 330, BRASS_HI, 1.2)


def paint_lens_surf(rng, stage):
    full = Pen(W, H, rng)
    lens2(full, rng, stage)
    im = full.done().crop((504, 172, 944, 612))
    m = circle_mask((440, 440), (220, 220), 201, 1)
    im.putalpha(ImageChops.multiply(im.getchannel("A"), m))
    return im


def paint_lens_ada_inv2(rng):
    """The sever image: exactly the band-7 silhouette, flipped top to bottom."""
    return paint_lens_ada(rng_for(24), False).done().transpose(Image.FLIP_TOP_BOTTOM)


# --- view A room: side-elevation scope, painted incident on the dado and grating --------------------

def scope2(p):
    """The scope in side elevation on its arm: a level brass tube, eyepiece toward the left."""
    # wall bracket
    p.rect(60, 560, 110, 700, IRON, INK, 2.6, r=4)
    p.line([(66, 566), (66, 694)], IRON_HI, 1.6)
    for y in (576, 684):
        screw(p, 85, y, 4.2, IRON_HI)
    # the arm: a flat iron bar out from the bracket, a forked cradle under the tube
    p.rect(104, 652, 318, 666, IRON, INK, 2.4)
    p.line([(108, 656), (314, 656)], IRON_HI, 1.4)
    p.poly([(96, 640), (132, 652), (132, 676), (96, 690)], IRON, INK, 2.4)        # gusset
    p.rect(262, 640, 306, 654, IRON, INK, 2.2)
    for x in (266, 302):
        p.rect(x - 4, 628, x + 4, 642, IRON, INK, 1.8)
    screw(p, 284, 659, 3.6, IRON_HI)
    # the tube
    y0, y1 = 598, 642
    p.rect(150, y0, 440, y1, BRASS, INK, 2.8)
    p.line([(154, y0 + 6), (436, y0 + 6)], BRASS_HI, 2.2)
    p.line([(154, y1 - 6), (436, y1 - 6)], BRASS_LO, 2.6)
    for x in (226, 336):
        p.rect(x - 7, y0 - 4, x + 7, y1 + 4, BRASS_LO, INK, 2.2)
        p.line([(x - 3, y0 - 1), (x - 3, y1 + 1)], BRASS_HI, 1.2)
    # objective hood, right: wider, a dark ring at its mouth
    p.rect(440, 588, 484, 652, BRASS_LO, INK, 2.8)
    p.line([(444, 594), (480, 594)], BRASS, 2.0)
    p.rect(480, 592, 488, 648, IRON_LO, INK, 2.0)
    # eyepiece, left: a narrower draw tube and a rubber eye cup
    p.rect(118, 606, 152, 634, IRON, INK, 2.4)
    p.line([(120, 611), (150, 611)], IRON_HI, 1.4)
    p.rect(100, 602, 120, 638, IRON_LO, INK, 2.4, r=4)
    # the clamp on top, jaws open, empty; its saddle riveted to the tube
    p.rect(176, 584, 364, 598, BRASS, INK, 2.4)
    p.line([(180, 588), (360, 588)], BRASS_HI, 1.4)
    for x in (190, 350):
        rivet(p, x, 591, 2.8, BRASS_HI)
    for x0, x1, tip in ((184, 202, 1), (338, 356, -1)):
        p.rect(x0, 548, x1, 584, BRASS, INK, 2.4)
        tx = x1 if tip > 0 else x0
        p.poly([(tx, 548), (tx + 14 * tip, 548), (tx + 14 * tip, 556), (tx, 560)], BRASS_HI, INK, 2)
    p.rect(214, 568, 326, 576, BRASS_DK, INK, 1.8)
    screw(p, 270, 580, 4.4)


def dado_incident_a(p, rng):
    """Restrained painted incident below the glass, clear of every hotspot rect."""
    # a riveted seam across the dado
    p.line([(-4, 772), (W + 4, 772)], STORM_DK, 3.0)
    p.line([(-4, 775), (W + 4, 775)], STORM_HI, 1.2)
    for x in range(20, W, 34):
        rivet(p, x, 782, 2.3)
    # brass handrail on iron standoffs, left of the pedestal
    for x in (36, 176, 316, 444):
        p.rect(x - 6, 812, x + 6, 838, IRON, INK, 2.0)
        p.ell(x, 838, 8, 4, IRON, INK, 1.8)
    p.rect(-4, 800, 460, 814, BRASS, INK, 2.4, r=6)
    p.line([(0, 804), (456, 804)], BRASS_HI, 1.8)
    p.ell(460, 807, 7, 7, BRASS_LO, INK, 2.0)
    # a horn cleat with the halyard coiled and hung on it
    cx, cy = 384, 742
    p.rect(cx - 8, cy - 4, cx + 8, cy + 10, BRASS_LO, INK, 2.0)
    p.poly([(cx - 34, cy - 2), (cx - 24, cy - 8), (cx + 24, cy - 8), (cx + 34, cy - 2), (cx + 30, cy + 2),
            (cx - 30, cy + 2)], BRASS, INK, 2.2)
    rope, rope_dk = mix(PAPER, TIMBER, 0.35), mix(TIMBER, INK, 0.25)
    coil = p.layer()
    for k, (ox, rw, rh) in enumerate(((-6, 30, 66), (2, 34, 72), (8, 30, 68), (-2, 26, 62))):
        coil.ell(cx + ox, cy + 64, rw, rh, None, INK, 9.0)
        coil.ell(cx + ox, cy + 64, rw, rh, None, rope if k % 2 == 0 else mix(rope, rope_dk, 0.4), 5.6)
    # the tail hanging straight down past the coil, whipped at the end
    coil.line([(cx + 26, cy + 4), (cx + 30, cy + 70), (cx + 28, cy + 154)], INK, 8.0)
    coil.line([(cx + 26, cy + 4), (cx + 30, cy + 70), (cx + 28, cy + 154)], rope, 4.6)
    coil.rect(cx + 23, cy + 146, cx + 33, cy + 156, mix(STORM_DK, INK, 0.3), INK, 1.4)
    p.put(coil)
    # the turns around the cleat horn
    p.line([(cx - 22, cy - 6), (cx - 8, cy + 6)], INK, 7)
    p.line([(cx - 22, cy - 6), (cx - 8, cy + 6)], rope, 3.6)
    # a vertical seam with rivets right of the diagram plate
    p.line([(1404, 652), (1404, A_FLOOR - 2)], STORM_DK, 3)
    for y in range(668, A_FLOOR - 10, 28):
        rivet(p, 1418, y, 2.3)


def grating_incident_a(p):
    """A brass inspection plate let into the grating, and a drain scupper."""
    x0, y0, x1, y1 = 1050, 950, 1290, 1046
    sh = p.layer()
    sh.rect(x0 + 4, y0 + 6, x1 + 4, y1 + 6, SHADOW, None)
    p.put_soft(sh, 4, 0.4)
    p.rect(x0, y0, x1, y1, BRASS_LO, INK, 2.6, r=3)
    p.rect(x0 + 10, y0 + 10, x1 - 10, y1 - 10, IRON, INK, 2.0)
    for i in range(1, 6):
        xx = x0 + 10 + (x1 - x0 - 20) * i / 6
        p.line([(xx, y0 + 12), (xx, y1 - 12)], IRON_HI, 2.0)
    for sx, sy in ((x0 + 6, y0 + 6), (x1 - 6, y0 + 6), (x0 + 6, y1 - 6), (x1 - 6, y1 - 6)):
        screw(p, sx, sy, 3.6)
    p.rect(x0 + 96, y0 - 6, x0 + 144, y0 + 8, BRASS, INK, 2.0, r=3)              # lifting ring
    # scupper in the far right corner of the floor
    p.rect(1350, 1000, 1430, 1040, IRON_LO, INK, 2.4, r=6)
    for x in range(1360, 1424, 12):
        p.line([(x, 1006), (x, 1034)], IRON_HI, 2.0)


def paint_a_room2(rng):
    p = Pen(W, H, rng)
    soffit(p, 150, rng)
    brass_bar(p, -4, 150, W + 4, 162, vertical=False)
    iron_post(p, -4, 150, 52, 644)
    iron_post(p, 1396, 150, W + 4, 644)
    p.line([(48, 162), (48, 628)], BRASS, 6)
    p.line([(1400, 162), (1400, 628)], BRASS, 6)
    for bx in A_BARS:
        brass_bar(p, bx - 12, 162, bx + 12, 628)
    brass_bar(p, -4, 628, W + 4, 644, vertical=False)
    wall_a(p, rng)
    dado_incident_a(p, rng)
    grating(p, A_FLOOR, H)
    grating_incident_a(p)
    x0, y0, x1, y1 = DIAGRAM
    sh = p.layer()
    sh.rect(x0 + 6, y0 + 8, x1 + 6, y1 + 8, SHADOW, None)
    p.put_soft(sh, 6, 0.4)
    p.rect(x0 - 8, y0 - 8, x1 + 8, y1 + 8, BRASS_LO, INK, 2.6, r=4)
    p.rect(x0, y0, x1, y1, ENAMEL, mix(INK, BRASS_LO, 0.5), 1.6, r=2)
    for sx, sy in ((x0 + 12, y0 + 12), (x1 - 12, y0 + 12), (x0 + 12, y1 - 12), (x1 - 12, y1 - 12)):
        screw(p, sx, sy, 5)
    p.cut(rect_mask((W, H), A_PANES))
    pedestal(p)
    lens(p, rng)
    scope2(p)
    keep = Image.new("L", (W, H), 0)
    kd = ImageDraw.Draw(keep)
    kd.ellipse((LENS_C[0] - LENS_R - 2, LENS_C[1] - LENS_R - 2, LENS_C[0] + LENS_R + 2, LENS_C[1] + LENS_R + 2), fill=255)
    kd.rectangle((56, 530, 500, 720), fill=255)
    kd.rectangle((650, 600, 800, 630), fill=255)
    return clear_panes(p.done(), A_PANES, keep)


# --- view B room and rail -------------------------------------------------------------------------

def paint_b_room2(rng):
    p = Pen(W, H, rng)
    soffit(p, 88, rng)
    brass_bar(p, -4, 88, W + 4, 100, vertical=False)
    iron_post(p, -4, 88, 60, 760)
    iron_post(p, 1388, 88, W + 4, 760)
    p.line([(56, 100), (56, 760)], BRASS, 6)
    p.line([(1392, 100), (1392, 760)], BRASS, 6)
    for bx in B_BARS:
        brass_bar(p, bx - 14, 100, bx + 14, 760)
    p.rect(-4, 760, W + 4, 840, TIMBER, INK, 3)
    p.rect(-4, 756, W + 4, 772, TIMBER_HI, INK, 2.6)
    p.line([(-4, 760), (W + 4, 760)], mix(TIMBER_HI, PAPER, 0.4), 1.6)
    for y in (796, 818):
        p.line([(-4, y), (W + 4, y)], TIMBER_DK, 1.2)
    p.rect(-4, 834, W + 4, 844, TIMBER_DK, INK, 2.2)
    p.rect(-4, 844, W + 4, H + 4, SEAGLASS, None)
    lay = p.layer()
    for _ in range(10):
        lay.ell(rng.uniform(0, W), rng.uniform(880, 1080), rng.uniform(60, 160), rng.uniform(20, 40), mix(SEAGLASS, STORM, 0.3), None)
    p.put_soft(lay, 18, 0.25)
    for x in range(30, W, 58):
        if B_CLEAR[0] - 12 < x < B_CLEAR[2] + 12:
            continue
        p.line([(x, 846), (x, H + 4)], mix(SEAGLASS, INK, 0.45), 2.2)
        p.line([(x + 3, 846), (x + 3, H + 4)], SEAGLASS_HI, 1.0)
    px0, px1 = B_CLEAR[0] - 8, B_CLEAR[2] + 8
    p.line([(px0, 846), (px0, H + 4)], mix(SEAGLASS, INK, 0.45), 2.6)
    p.line([(px0 + 4, 846), (px0 + 4, H + 4)], SEAGLASS_HI, 1.2)
    p.line([(px1, 846), (px1, H + 4)], mix(SEAGLASS, INK, 0.45), 2.6)
    p.line([(px1 - 4, 846), (px1 - 4, H + 4)], mix(SEAGLASS, STORM, 0.3), 1.2)
    b_incident(p, rng)
    p.cut(rect_mask((W, H), B_PANES))
    return clear_panes(p.done(), B_PANES)


def b_incident(p, rng):
    """A wiper cloth over the sill, a tally slate on a nail, a halyard coiled on a cleat."""
    # wiper cloth, folded over the sill's front edge (x 150-330), clear of the ruler
    cloth, cloth_dk = mix(PAPER, SEAGLASS_HI, 0.25), mix(PAPER, STORM_HI, 0.45)
    sh = p.layer()
    sh.poly([(158, 772), (338, 772), (334, 862), (300, 878), (250, 868), (204, 884), (162, 866)], SHADOW, None)
    p.put_soft(sh, 5, 0.4)
    p.poly([(146, 752), (326, 750), (332, 760), (140, 762)], cloth, INK, 2.4)              # on the sill top
    p.poly([(140, 762), (332, 760), (328, 852), (296, 868), (252, 858), (206, 876), (160, 858), (150, 820)],
           cloth, INK, 2.6)
    for x0, x1 in ((190, 196), (236, 246), (286, 292)):
        p.line([(x0, 766), (x1, 852)], cloth_dk, 2.0)
    p.line([(146, 770), (330, 768)], cloth_dk, 1.6)
    p.line([(150, 840), (174, 846)], mix(cloth, STORM_HI, 0.5), 1.4)
    # a halyard coiled on a cleat on the panelling (x 100-260)
    cx, cy = 180, 896
    p.poly([(cx - 34, cy - 2), (cx - 24, cy - 8), (cx + 24, cy - 8), (cx + 34, cy - 2), (cx + 30, cy + 2),
            (cx - 30, cy + 2)], BRASS, INK, 2.2)
    p.rect(cx - 8, cy - 4, cx + 8, cy + 10, BRASS_LO, INK, 2.0)
    rope, rope_dk = mix(PAPER, TIMBER, 0.35), mix(TIMBER, INK, 0.25)
    coil = p.layer()
    for k, (ox, rw, rh) in enumerate(((-6, 32, 70), (2, 36, 76), (8, 32, 72), (-2, 28, 66))):
        coil.ell(cx + ox, cy + 68, rw, rh, None, INK, 9.0)
        coil.ell(cx + ox, cy + 68, rw, rh, None, rope if k % 2 == 0 else mix(rope, rope_dk, 0.4), 5.6)
    coil.line([(cx + 26, cy + 4), (cx + 30, cy + 74), (cx + 28, cy + 170)], INK, 8.0)
    coil.line([(cx + 26, cy + 4), (cx + 30, cy + 74), (cx + 28, cy + 170)], rope, 4.6)
    p.put(coil)
    p.line([(cx - 22, cy - 6), (cx - 8, cy + 6)], INK, 7)
    p.line([(cx - 22, cy - 6), (cx - 8, cy + 6)], rope, 3.6)
    # the tally slate on a nail (x 1160-1320): chalk strokes in fives, the last group unfinished
    x0, y0, x1, y1 = 1160, 900, 1320, 1010
    p.line([(1240, 868), (x0 + 20, y0 + 2)], INK, 2.2)
    p.line([(1240, 868), (x1 - 20, y0 + 2)], INK, 2.2)
    p.ell(1240, 866, 4, 4, BRASS_LO, INK, 1.6)
    sh = p.layer()
    sh.rect(x0 + 5, y0 + 7, x1 + 5, y1 + 7, SHADOW, None)
    p.put_soft(sh, 4, 0.45)
    p.rect(x0, y0, x1, y1, TIMBER, INK, 2.6, r=3)
    p.rect(x0 + 9, y0 + 9, x1 - 9, y1 - 9, mix(SOOT, STORM_DK, 0.5), INK, 1.8)
    chalk = mix(PAPER_HI, SEAGLASS_HI, 0.2)
    gx = x0 + 22
    for g, n in enumerate((5, 5, 4)):
        gy = y0 + 28 + (g // 2) * 40
        if g == 2:
            gx = x0 + 22
        for i in range(min(n, 4)):
            p.line([(gx + i * 11, gy), (gx + i * 11 + 2, gy + 26)], chalk, 2.4)
        if n == 5:
            p.line([(gx - 4, gy + 22), (gx + 40, gy + 4)], chalk, 2.4)
        gx += 64


def rail_b2(rng):
    """rail_b, dry, with a matte dry top on the rail: the rain has never touched it."""
    p = rail_b(rng, False)
    top = p.layer()
    top.rect(-4, 610, W + 4, 616, mix(STORM_HI, PAPER, 0.32), INK, 0)
    p.put(top, 0.85)
    p.line([(-4, 616.5), (W + 4, 616.5)], mix(STORM_DK, INK, 0.5), 1.4)
    return p


# --- the close-ups ---------------------------------------------------------------------------------

QUAD_PIVOT = (310, 515)
QUAD_R = 200


def paint_c_scope2(rng):
    p = Pen(W, H, rng, STORM)
    backboard(p, rng)

    def shadow(x0, y0, x1, y1, r=0):
        sh = p.layer()
        sh.rect(x0 + 6, y0 + 8, x1 + 6, y1 + 8, SHADOW, None, r=r)
        p.put_soft(sh, 6, 0.45)

    # the scope body in side elevation: a level brass tube running into the eyepiece housing
    ty0, ty1 = 470, 560
    shadow(20, ty0, 640, ty1)
    p.rect(40, ty0, 640, ty1, BRASS, INK, 3)
    p.line([(44, ty0 + 9), (636, ty0 + 9)], BRASS_HI, 3)
    p.line([(44, ty0 + 20), (636, ty0 + 20)], mix(BRASS, BRASS_HI, 0.5), 1.6)
    p.line([(44, ty1 - 12), (636, ty1 - 12)], BRASS_LO, 5)
    for x in (150, 470):
        p.rect(x - 12, ty0 - 8, x + 12, ty1 + 8, BRASS_LO, INK, 2.6)
        p.line([(x - 6, ty0 - 4), (x - 6, ty1 + 4)], BRASS_HI, 1.6)
        for y in (ty0 + 8, ty1 - 8):
            rivet(p, x, y, 3.2, BRASS_HI)
    # objective hood at the left end
    p.rect(14, ty0 - 22, 58, ty1 + 22, BRASS_LO, INK, 3)
    p.line([(20, ty0 - 16), (52, ty0 - 16)], BRASS, 2.4)
    p.rect(6, ty0 - 16, 16, ty1 + 16, IRON_LO, INK, 2.2)
    # the clamp, riveted to the tube: a cradle on two saddles, jaws on screw rods
    shadow(90, 150, 530, 480, 8)
    for x in (130, 490):
        p.rect(x - 20, 452, x + 20, ty0 + 14, BRASS, INK, 2.6)                 # saddle
        p.line([(x - 16, 456), (x + 16, 456)], BRASS_HI, 1.4)
        rivet(p, x - 10, ty0 + 6, 3.0, BRASS_HI)
        rivet(p, x + 10, ty0 + 6, 3.0, BRASS_HI)
    p.rect(98, 178, 522, 444, BRASS_LO, INK, 2.8, r=6)                          # cradle back
    p.rect(110, 186, 510, 434, mix(STORM_DK, SOOT, 0.4), INK, 2.4, r=4)
    for x, y in ((104, 184), (516, 184), (104, 438), (516, 438)):
        rivet(p, x, y, 3.0, BRASS_HI)
    p.rect(104, 152, 516, 172, BRASS, INK, 2.4, r=3)                            # top jaw, raised
    p.line([(108, 156), (512, 156)], BRASS_HI, 1.6)
    p.rect(104, 440, 516, 460, BRASS, INK, 2.4, r=3)                            # bottom jaw
    p.line([(108, 444), (512, 444)], BRASS_HI, 1.6)
    for x in (130, 490):
        p.rect(x - 6, 140, x + 6, 452, BRASS_DK, INK, 1.8)
        for y in range(150, 446, 10):
            p.line([(x - 5, y), (x + 5, y + 4)], BRASS, 1.0)
        p.ell(x, 136, 13, 9, BRASS, INK, 2.2)                                   # thumb nuts
        p.line([(x - 9, 134), (x + 9, 134)], BRASS_HI, 1.2)
    # the selector: a lever quadrant hung from the tube, a detent notch for each position
    cx, cy = QUAD_PIVOT
    a0, a1 = -60, 60          # degrees from straight down

    def qp(r, deg):
        a = math.radians(deg)
        return (cx + r * math.sin(a), cy + r * math.cos(a))

    for deg in (-52, 52):                                                       # hangers
        hx0, hy0 = qp(70, deg)
        hx1, hy1 = qp(160, deg)
        p.line([(hx0, hy0), (hx1, hy1)], INK, 14)
        p.line([(hx0, hy0), (hx1, hy1)], BRASS_LO, 9)
        rivet(p, hx1, hy1, 3.4, BRASS_HI)
    outer = [qp(236, a0 + (a1 - a0) * i / 48) for i in range(49)]
    inner = [qp(150, a1 - (a1 - a0) * i / 48) for i in range(49)]
    sh = p.layer()
    sh.poly([(x + 6, y + 8) for x, y in outer + inner], SHADOW, None)
    p.put_soft(sh, 6, 0.45)
    p.poly(outer + inner, BRASS, INK, 3)
    p.line([qp(230, a0 + (a1 - a0) * i / 48) for i in range(49)], BRASS_HI, 1.8)
    p.line([qp(158, a0 + (a1 - a0) * i / 48) for i in range(49)], BRASS_LO, 2.2)
    # the slot the lever runs in, and three detent notches cut into its outer edge
    slot_o = [qp(QUAD_R + 9, -50 + 100 * i / 48) for i in range(49)]
    slot_i = [qp(QUAD_R - 9, 50 - 100 * i / 48) for i in range(49)]
    p.poly(slot_o + slot_i, GLASS_DK, INK, 2.2)
    for deg in (-48.6, 0, 48.6):
        nx, ny = qp(QUAD_R + 12, deg)
        p.ell(nx, ny, 9, 9, GLASS_DK, INK, 2.0)
        p.arc(nx, ny, 12.5, 12.5, 0, 360, BRASS_HI, 1.0)
    # engraved index arcs between the notches
    for deg in range(-56, 57, 8):
        p.line([qp(218, deg), qp(228, deg)], BRASS_DK, 1.4)
    for x, y in (qp(196, -58), qp(196, 58), qp(170, -40), qp(170, 40)):
        screw(p, x, y, 3.8)
    # the pivot boss on the tube
    p.ell(cx, cy, 22, 22, BRASS_LO, INK, 2.6)
    p.ell(cx, cy, 12, 12, BRASS, INK, 2.0)
    p.line([(cx - 8, cy - 8), (cx + 8, cy + 8)], BRASS_DK, 2)
    for x0, x1 in ((100, 220), (250, 370), (400, 520)):
        plate(p, x0, 760, x1, 792)
    # eyepiece housing: an iron collar with bolts, a black interior; the tube runs into it
    ecx, ecy = EYE_C
    sh = p.layer()
    sh.ell(ecx + 8, ecy + 10, 376, 376, SHADOW, None)
    p.put_soft(sh, 10, 0.5)
    p.ell(ecx, ecy, 374, 374, IRON, INK, 3)
    p.ell(ecx, ecy, 366, 366, None, IRON_HI, 1.6)
    for a in range(0, 360, 30):
        x, y = polar((ecx, ecy), 357, a + 15)
        screw(p, x, y, 5, IRON_HI)
    p.ell(ecx, ecy, 344, 344, BRASS_LO, INK, 2.4)
    p.ell(ecx, ecy, EYE_R, EYE_R, INK, INK, 2)
    plate(p, 630, 104, 1250, 148)
    # a riveted base rail the key, slot and plate are bolted to
    p.rect(60, 942, W - 60, 962, IRON, INK, 2.6)
    p.line([(64, 947), (W - 64, 947)], IRON_HI, 1.4)
    for x in range(80, W - 60, 40):
        rivet(p, x, 954, 2.4, IRON_HI)
    shadow(620, 820, 920, 930, 6)
    p.rect(620, 820, 920, 930, BRASS_LO, INK, 3, r=6)
    p.rect(632, 830, 908, 920, mix(SOOT, STORM_DK, 0.5), INK, 2.2, r=6)
    p.line([(636, 834), (904, 834)], IRON_LO, 3)
    shadow(940, 820, 1260, 930, 6)
    p.rect(940, 820, 1260, 930, BRASS, INK, 3, r=6)
    p.line([(946, 826), (1254, 826)], BRASS_HI, 1.8)
    p.rect(956, 850, 1250, 910, BRASS_LO, INK, 2.0, r=4)
    p.rect(946, 858, 954, 902, GLASS_DK, INK, 1.8, r=2)
    p.line([(947, 860), (947, 900)], IRON_LO, 1.4)
    for x in (700, 840, 1020, 1180):
        p.rect(x - 8, 930, x + 8, 944, BRASS_LO, INK, 1.8)                     # feet onto the rail
    shadow(90, 820, 530, 930, 4)
    p.rect(84, 814, 536, 936, BRASS_LO, INK, 2.6, r=4)
    p.rect(90, 820, 530, 930, ENAMEL, mix(INK, BRASS_LO, 0.5), 1.6, r=2)
    for x, y in ((98, 828), (522, 828), (98, 922), (522, 922)):
        screw(p, x, y, 3.6)
    return p


def thumbscrew(p, cx, top):
    """A brass thumb-screw knob in side elevation: knurled head, neck, threaded boss."""
    sh = p.layer()
    sh.rect(cx - 50 + 5, top + 7, cx + 50 + 5, top + 66 + 7, SHADOW, None, r=12)
    p.put_soft(sh, 5, 0.45)
    p.rect(cx - 60, top + 74, cx + 60, top + 88, BRASS_LO, INK, 2.4, r=3)        # boss plate
    p.rect(cx - 16, top + 62, cx + 16, top + 76, BRASS_DK, INK, 2.2)              # neck
    for y in range(int(top) + 65, int(top) + 75, 4):
        p.line([(cx - 15, y), (cx + 15, y + 2)], BRASS, 1.0)
    p.rect(cx - 50, top, cx + 50, top + 64, BRASS, INK, 2.8, r=12)                # knurled head
    for k in range(-44, 45, 8):
        p.line([(cx + k, top + 5), (cx + k, top + 59)], BRASS_LO, 2.2)
        p.line([(cx + k + 2.4, top + 6), (cx + k + 2.4, top + 58)], BRASS_HI, 1.0)
    p.line([(cx - 44, top + 8), (cx + 44, top + 8)], BRASS_HI, 2.0)
    p.rect(cx - 50, top, cx + 50, top + 64, None, INK, 2.8, r=12)
    for x in (cx - 50, cx + 50):
        screw(p, x, top + 81, 3.4)


def paint_c_ruler2(rng):
    p = Pen(W, H, rng, TIMBER)
    p.vgrad(0, 0, W, H, TIMBER_HI, TIMBER_DK)
    lay = p.layer()
    for _ in range(90):
        y = rng.uniform(0, H)
        x = rng.uniform(-200, W)
        ln = rng.uniform(200, 700)
        lay.line([(x, y), (x + ln * 0.5, y + rng.uniform(-3, 3)), (x + ln, y)], TIMBER_DK, rng.uniform(1, 2.4))
    p.put(lay, 0.45)
    p.line([(-4, 330), (W + 4, 330)], TIMBER_DK, 3)
    p.line([(-4, 334), (W + 4, 334)], mix(TIMBER_HI, PAPER, 0.3), 1.6)
    sh = p.layer()
    sh.rect(108, 430, 1356, 572, SHADOW, None, r=4)
    p.put_soft(sh, 8, 0.5)
    p.rect(100, 420, 1348, 560, BOXWOOD, INK, 3, r=4)
    p.vgrad(104, 424, 1344, 556, mix(BOXWOOD, PAPER_HI, 0.4), mix(BOXWOOD, BOXWOOD_DK, 0.5))
    for _ in range(14):
        y = rng.uniform(470, 552)
        p.line([(rng.uniform(130, 1200), y), (rng.uniform(1210, 1320), y + rng.uniform(-1, 1))],
               mix(BOXWOOD, BOXWOOD_DK, 0.7), 1.0)
    p.rect(100, 420, 1348, 560, None, INK, 3, r=4)
    ruler_ticks(p, 140, 1292, 422, 96, 64, 2.2)
    burr = p.layer()
    for i in range(12 * 8 + 1):
        x = 140 + i * 12
        if i % 8:
            burr.line([(x - 1.6, 424), (x - 1.6, 440)], mix(BOXWOOD_DK, INK, 0.5), 1.0)
    p.put(burr, 0.6)
    for x0, x1 in ((100, 130), (1318, 1348)):
        p.rect(x0, 416, x1, 564, BRASS, INK, 2.6, r=3)
        p.line([(x0 + 5, 422), (x0 + 5, 558)], BRASS_HI, 1.8)
        screw(p, (x0 + x1) / 2, 490, 4.4)
    # magnifier well (the view paints the magnified rule inside it at every zoom)
    cx, cy, r = 560, 760, 180
    sh = p.layer()
    sh.ell(cx + 6, cy + 8, r + 16, r + 16, SHADOW, None)
    p.put_soft(sh, 8, 0.5)
    p.ell(cx, cy, r + 14, r + 14, BRASS_LO, INK, 3)
    p.ell(cx, cy, r + 9, r + 9, None, BRASS_HI, 1.4)
    p.ell(cx, cy, r, r, BOXWOOD, INK, 2.6)
    # the two thumb-screws, each with a blank enamel tag under it
    for kx in (1080, 1260):
        thumbscrew(p, kx, 704)
        plate(p, kx - 72, 796, kx + 72, 822, ENAMEL, BRASS_LO, 2.0)
    return p


# --- aperture scenes ------------------------------------------------------------------------------

def paint_view_station2(rng):
    p = Pen(620, 620, rng)
    hor = 330
    aperture_base(p, mix(STORM_DK, STORM, 0.4), mix(STORM, SEAGLASS, 0.4), mix(SEAGLASS, STORM, 0.55), STORM_DK, hor)
    chop(p, rng, 0, 620, hor, 620, mix(SEAGLASS_HI, STORM, 0.35), mix(STORM_DK, INK, 0.5), 160, 0.6, 1.5)
    p.line([(-4, hor), (624, hor)], mix(SEAGLASS_HI, PAPER, 0.3), 2.4)
    station_reflection(p, rng)
    # Ada's reflected head and shoulder, lower left: a stark angular back-of-head profile, a hard
    # hair line, a turned-up collar. The skull's right edge passes (230, 330), where the horizon
    # emerges.
    head = [(64, 296), (128, 262), (190, 268), (222, 300), (232, 330), (228, 384), (212, 420), (186, 440),
            (160, 446), (110, 448), (72, 432), (44, 392), (40, 344)]
    neck = [(112, 440), (164, 440), (168, 512), (106, 516)]
    body = [(-10, 566), (40, 534), (96, 514), (182, 508), (232, 540), (256, 600), (266, 640), (-10, 640)]
    # a stiff collar, turned up: two hard wedges either side of the nape
    collar_l = [(40, 540), (86, 470), (112, 492), (114, 528), (70, 548)]
    collar_r = [(164, 490), (196, 460), (226, 534), (186, 540), (168, 524)]
    dk = STORM_DK
    neck_c = mix(STORM, SEAGLASS, 0.5)
    collar_c = mix(PAPER, STORM_HI, 0.45)
    p.poly(body, dk, INK, 3.0)
    p.poly(neck, neck_c, INK, 2.8)
    p.line([(136, 450), (138, 508)], mix(neck_c, INK, 0.35), 2.0)
    p.poly(collar_l, collar_c, INK, 3.0)
    p.poly(collar_r, collar_c, INK, 3.0)
    p.poly(head, dk, INK, 3.0)
    # hard hair line where the hair stops at the nape (cut square), and the parting
    p.line([(72, 432), (110, 448), (160, 446), (186, 440)], INK, 3.4)
    p.line([(128, 262), (118, 330), (104, 410)], mix(dk, INK, 0.5), 2.4)
    p.line([(166, 272), (150, 340), (148, 420)], mix(dk, STORM_HI, 0.4), 1.6)
    # rim light from the window along the right planes
    rim = p.layer()
    rim.line([(190, 268), (222, 300), (232, 330), (228, 384), (210, 424)], mix(PAPER, SEAGLASS_HI, 0.4), 3.0)
    rim.line([(232, 540), (256, 600), (266, 640)], mix(PAPER, SEAGLASS_HI, 0.4), 2.4)
    p.put(rim, 0.7)
    p.clip(circle_mask((620, 620), VIEW_C, 310))
    return p


def paint_view_surface2(rng):
    """After the bearing: the dark standing surface, its reflections, and the lid crossing."""
    p = Pen(620, 620, rng)
    p.vgrad(0, 0, 620, 620, mix(STORM, SEAGLASS, 0.2), mix(STORM, SEAGLASS, 0.5))
    light, dark = mix(SEAGLASS_HI, PAPER, 0.3), mix(STORM_DK, INK, 0.5)
    lt, dk = p.layer(), p.layer()
    for _ in range(26):
        x, y = rng.uniform(0, 620), rng.uniform(0, 620)
        ln, ht = rng.uniform(30, 90), rng.uniform(3, 6)
        lt.poly([(x, y - ln / 2), (x + ht, y - ln * 0.08), (x, y + ln / 2)], light, None)
        dk.line([(x - 1.2, y - ln * 0.45), (x - 1.2, y + ln * 0.55)], dark, 1.8)
    p.put(dk, 0.5)
    p.put(lt, 0.45)
    refl = p.layer()
    refl_door(refl, 80, 120, 170, 330)
    refl_shelf(refl, 140, 352, 470, 372)
    refl_window(refl, 380, 130, 540, 262, (460, 200, LAMP_WARM))
    p.put(refl, 0.9)
    # the lid, crossing the eyepiece: storm navy, feathered above, a wet paper rim along its edge
    fea = p.layer()
    fea.rect(-10, 360, 630, 430, mix(STORM_DK, INK, 0.6), None)
    p.put_soft(fea, 14, 0.95)
    lid = p.layer()
    lid.rect(-10, 400, 630, 476, mix(STORM_DK, INK, 0.6), None)
    p.put_soft(lid, 2, 1.0)
    lo = p.layer()
    lo.rect(-10, 446, 630, 468, mix(STORM_DK, STORM_HI, 0.5), None)
    p.put_soft(lo, 5, 0.6)
    p.rect(-10, 470, 630, 477, mix(PAPER_HI, SEAGLASS_HI, 0.15), None)
    p.line([(-10, 471.5), (630, 471.5)], (246, 242, 230), 1.4)
    p.line([(-10, 478), (630, 478)], INK, 2.0)
    p.clip(circle_mask((620, 620), VIEW_C, 310))
    return p


# ============================================================================= fix pass (w3)
# Review: the sea standing up has to read at a glance, and P15's lens has to be the deduction.
# Every asset here is a NEW file; nothing above is touched, so a full rerun still writes the
# earlier files byte for byte.
#
#   surface_standing      view A, from the reveal on: one flat vertical sea-glass plane fills every
#                         pane edge to edge (#6f9a93 at the rail shading to storm navy at the top,
#                         no sky, no rain texture in it). The station hangs in it upside down as a
#                         stark cutaway: a row of bunk doors under the top floor slab, the office
#                         lamp standing on its cord, the mess table with its nine bowls. The
#                         pennant stands straight out on its staff. Rain streaks run down in front
#                         and stop dead on one line, 60 px above the rail.
#   surface_standing_b6   the same plate with the inverted lighthouse hung in the right-hand strip
#                         beside the lens (band 6's notice).
#   c_view_land_r3        LAND 1 with a tin bowl wedged in the causeway's break
#   c_view_sea_r3         SEA 2 with a bowl floating at the cross
#   c_rim_round           the lens on LAND 1's bowl: tin, a round soldered patch
#   c_rim_crack           the lens on SEA 2's bowl: enamel, a bare crack, sea water in it

STAND_TOP = (34, 56, 74)         # storm navy
STAND_LOW = (111, 154, 147)      # #6f9a93 sea glass
STAND_INK = INK
STAND_SLAB = (20, 34, 44)
STAND_PALE = mix(PAPER, STAND_LOW, 0.15)
A_RAIL_TOP = 560
RAIN_STOP = A_RAIL_TOP - 60      # the clean dry gap
SLAB1 = (222, 240)               # the top floor slab (the resting lid covers its upper part)
SLAB2 = (384, 400)
LENS_X = (504, 944)              # opaque in a_room_r2: nothing is put behind it


def inv_door(p, x0, y0, x1, y1):
    """A bunk door hung upside down from the slab above: the threshold strip at the top, the
    lintel at the bottom, the long panel above the short one, the knob high."""
    p.rect(x0 - 8, y0, x1 + 8, y1 + 8, STAND_PALE, INK, 5.0)            # the jamb
    p.rect(x0, y0, x1, y1, STORM_DK, INK, 4.0)
    w, h = x1 - x0, y1 - y0
    p.rect(x0 + w * 0.2, y0 + h * 0.08, x1 - w * 0.2, y0 + h * 0.52, mix(STORM_DK, STORM, 0.6), INK, 2.6)
    p.rect(x0 + w * 0.2, y0 + h * 0.62, x1 - w * 0.2, y1 - h * 0.08, mix(STORM_DK, STORM, 0.6), INK, 2.6)
    p.ell(x1 - w * 0.16, y0 + h * 0.42, 4.5, 4.5, BRASS_HI, INK, 1.8)
    p.rect(x0 - 8, y0, x1 + 8, y0 + 7, STAND_SLAB, None)                # the threshold, up top


def inv_lamp(p, cx, base_y, top_y):
    """The office lamp, standing on its cord from the ceiling at the bottom: shade open upward,
    the warm point above it."""
    p.rect(cx - 26, base_y - 10, cx + 26, base_y + 4, STAND_PALE, INK, 3.0)      # the ceiling rose
    p.rect(cx - 3.5, top_y + 64, cx + 3.5, base_y - 10, INK, None)               # the cord, rigid
    sh_y0, sh_y1 = top_y + 28, top_y + 74
    p.poly([(cx - 78, sh_y0), (cx + 78, sh_y0), (cx + 22, sh_y1), (cx - 22, sh_y1)],
           mix(SEAGLASS, STORM_DK, 0.35), INK, 4.0)
    p.rect(cx - 82, sh_y0 - 6, cx + 82, sh_y0 + 2, STAND_PALE, INK, 3.0)          # the shade's rim
    soft_disc(p, cx, top_y + 14, 56, AMBER, 0.55, 16)
    soft_disc(p, cx, top_y + 14, 28, LAMP_WARM, 0.8, 5)
    p.ell(cx, top_y + 14, 15, 15, mix(AMBER, PAPER_HI, 0.45), INK, 2.4)


def inv_table(p, x0, x1, slab_y, top_y):
    """The mess table hung from the floor slab: legs up, the top below them, nine bowls hanging
    under it, upside down."""
    for lx in (x0 + 16, x1 - 30):
        p.rect(lx, slab_y, lx + 14, top_y, STAND_PALE, INK, 3.0)
    p.rect(x0, top_y, x1, top_y + 16, STAND_PALE, INK, 4.0)
    p.line([(x0 + 4, top_y + 6), (x1 - 4, top_y + 6)], mix(STAND_PALE, INK, 0.3), 1.6)
    step = (x1 - x0) / 9.0
    br = step * 0.4
    for i in range(9):
        bx = x0 + step * (i + 0.5)
        y = top_y + 16
        # rim against the underside of the top, the bowl hanging below it
        pts = [(bx - br * 1.1, y), (bx + br * 1.1, y)] + \
              [(bx + br * math.cos(t), y + br * 0.95 * math.sin(t)) for t in [math.pi * k / 14 for k in range(15)]]
        p.poly(pts, STAND_PALE, INK, 2.6)
        p.rect(bx - br * 0.36, y + br * 0.9, bx + br * 0.36, y + br * 1.12, STAND_PALE, INK, 2.0)   # the foot


def stand_pennant(p, staff_x, top_y, rail_y, tip_x):
    """The pennant on its staff, flat navy, ruler straight and level: no wind holds it there."""
    p.rect(staff_x - 4, top_y, staff_x + 4, rail_y, STAND_SLAB, INK, 2.0)
    p.ell(staff_x, top_y - 4, 6, 6, BRASS, INK, 1.8)
    y0, y1 = top_y + 4, top_y + 48
    d = 1 if tip_x > staff_x else -1
    p.poly([(staff_x + d * 4, y0), (tip_x, (y0 + y1) / 2 - 2), (tip_x, (y0 + y1) / 2 + 2), (staff_x + d * 4, y1)],
           STAND_SLAB, INK, 2.4)


def paint_surface_standing(rng, lighthouse_too=False):
    p = Pen(W, H, rng, STAND_TOP)
    # one plane: storm navy at the top of the glass to sea glass at the rail, flat and matte
    p.vgrad(0, 0, W, H, STAND_TOP, STAND_LOW, 150, A_RAIL_TOP + 40)
    # the cutaway, upside down: floor slabs run the whole width
    for y0, y1 in (SLAB1, SLAB2):
        p.rect(-4, y0, W + 4, y1, STAND_SLAB, INK, 3.0)
    # storey 1 (hangs from SLAB1): a row of bunk doors, all the way across
    dy0, dy1 = SLAB1[1], SLAB2[0] - 12
    doors = [(76, 148), (172, 244), (268, 340), (416, 488), (1100, 1172), (1196, 1268), (1292, 1364)]
    if not lighthouse_too:
        doors.append((964, 1036))
    for x0, x1 in doors:
        inv_door(p, x0, dy0, x1, dy1)
    # storey 2 (hangs from SLAB2; its ceiling is down at the rail): the office lamp standing on
    # its cord, left; the mess table with nine bowls, right
    inv_lamp(p, 236, A_RAIL_TOP + 6, SLAB2[1] + 12)
    inv_table(p, 1092, 1388, SLAB2[1], SLAB2[1] + 74)
    if lighthouse_too:
        inv_lighthouse2(p, 1000, SLAB1[1], 2.0)
    # the pennant on its staff, straight out, level
    stand_pennant(p, 1372, RAIN_STOP + 6, A_RAIL_TOP + 4, 1372 - 156)
    # rain in front: long pale streaks that all stop on one line, 60 px above the rail
    lay = p.layer()
    for _ in range(170):
        x = rng.uniform(52, 1396)
        if LENS_X[0] - 4 < x < LENS_X[1] + 4:
            continue
        y0 = rng.uniform(150, RAIN_STOP - 30)
        ln = rng.uniform(40, 120)
        lay.line([(x, y0), (x - ln * 0.04, min(RAIN_STOP, y0 + ln))], mix(PAPER_HI, SEAGLASS_HI, 0.3), 2.2)
    # a set of streaks reaches the line exactly, so the stop reads as a cut
    for k in range(38):
        x = 64 + k * 36.5 + rng.uniform(-6, 6)
        if LENS_X[0] - 4 < x < LENS_X[1] + 4:
            continue
        ln = rng.uniform(50, 110)
        lay.line([(x + ln * 0.04, RAIN_STOP - ln), (x, RAIN_STOP)], mix(PAPER_HI, SEAGLASS_HI, 0.3), 2.2)
    lay.clip(rect_mask((W, H), [(0, 0, W, RAIN_STOP)]))
    p.put(lay, 0.75)
    return p


def paint_view_land3(rng):
    p = paint_view_land(rng)
    p.im.putalpha(255)
    # a tin bowl wedged in the causeway's break, tipped a little, at the cross
    tin = mix(PAPER, STORM_HI, 0.45)
    lay = p.layer()
    bowl(lay, 302, 302, 72, tin, INK)
    rot = lay.im.rotate(-9, resample=Image.BICUBIC, center=(302 * SS, 296 * SS))
    lay.im = rot
    p.put(lay)
    p.line([(258, 296), (346, 296)], mix(STORM_DK, INK, 0.4), 2.0)
    p.clip(circle_mask((620, 620), VIEW_C, 310))
    return p


def paint_view_sea3(rng):
    p = paint_view_sea(rng)
    p.im.putalpha(255)
    cx, cy = VIEW_C
    # the bowl rides low: everything under the waterline is cut away, so it sits in the sea
    lay = p.layer()
    wl = cy + 18
    bowl(lay, cx, cy + 4, 88, mix(PAPER, STORM_HI, 0.25), INK)
    lay.clip(rect_mask((620, 620), [(0, 0, 620, wl)]))
    p.put(lay)
    p.line([(cx - 96, wl), (cx - 52, wl - 3), (cx, wl), (cx + 52, wl - 3), (cx + 96, wl)],
           mix(SEAGLASS_HI, PAPER, 0.3), 2.4)
    p.line([(cx - 90, wl + 5), (cx + 90, wl + 5)], mix(STORM_DK, INK, 0.5), 2.2)
    p.clip(circle_mask((620, 620), VIEW_C, 310))
    return p


def rim_base(p, wall0, wall1, inside, inside_hi):
    rim_y = 104
    p.vgrad(0, 0, 280, 280, mix(STORM_HI, TIMBER, 0.4), mix(TIMBER_DK, STORM_DK, 0.4))
    p.rect(-10, rim_y - 34, 290, rim_y, inside, None)
    p.line([(-10, rim_y - 22), (290, rim_y - 22)], inside_hi, 2)
    p.rect(-10, rim_y - 6, 290, rim_y + 8, mix(wall0, PAPER_HI, 0.3), INK, 2.6, r=4)
    p.rect(-10, rim_y + 8, 290, 290, wall0, INK, 2.6)
    p.vgrad(-6, rim_y + 10, 286, 286, wall0, wall1)
    p.line([(-10, rim_y + 8), (290, rim_y + 8)], INK, 2.6)
    return rim_y


def paint_rim_round(rng):
    """LAND 1 under the lens: tin, salt-dry, and a ROUND patch soldered on. No rivets."""
    p = Pen(280, 280, rng)
    tin = mix(PAPER, STORM_HI, 0.45)
    rim_y = rim_base(p, tin, mix(tin, STORM_DK, 0.35), mix(STORM_DK, TIMBER_DK, 0.5), mix(PAPER, STORM_HI, 0.5))
    # salt grains in the empty bowl
    for _ in range(26):
        x, y = rng.uniform(0, 280), rng.uniform(rim_y - 32, rim_y - 8)
        p.ell(x, y, 1.6, 1.6, PAPER_HI, None)
    sh = p.layer()
    sh.ell(148, 192, 50, 50, SHADOW, None)
    p.put_soft(sh, 3, 0.35)
    # the solder bead round it, lumpy, then the disc
    for k in range(36):
        a = math.tau * k / 36
        p.ell(144 + 50 * math.cos(a), 186 + 50 * math.sin(a), 5.5 + rng.uniform(-1, 1.2), None,
              mix(PAPER_HI, STORM_HI, 0.35), INK, 1.2)
    p.ell(144, 186, 46, 46, mix(tin, PAPER_HI, 0.3), INK, 2.6)
    p.arc(144, 186, 38, 38, 200, 300, PAPER_HI, 1.6)
    p.clip(circle_mask((280, 280), (140, 140), 130))
    return p


def paint_rim_crack(rng):
    """SEA 2 under the lens: enamel, sea water standing in it, and a bare crack. No patch."""
    p = Pen(280, 280, rng)
    rim_y = rim_base(p, ENAMEL, mix(ENAMEL, STORM_HI, 0.35), mix(SEAGLASS, STORM, 0.45), mix(SEAGLASS_HI, PAPER, 0.3))
    p.line([(132, rim_y - 6), (138, rim_y + 8), (128, 140), (146, 168), (136, 200), (150, 232), (140, 290)], INK, 3.0)
    p.line([(146, 168), (172, 180), (184, 204)], INK, 1.8)
    p.line([(136, 200), (108, 214)], INK, 1.6)
    # a dark seep along the crack
    seep = p.layer()
    seep.line([(128, 140), (146, 168), (136, 200), (150, 232), (140, 290)], STORM_DK, 9.0)
    p.put_soft(seep, 4, 0.3)
    p.clip(circle_mask((280, 280), (140, 140), 130))
    return p


# ----------------------------------------------------------------------------- fix p1: the surface on end
# assets/stages/R09/p15_surface_on_end*.png: the P15 stage overlay for view A, clipped to the gallery
# glass (A_GLASS 52..1396 x 162..628, transparent everywhere else). One flat storm-navy plane edge to
# edge: no sky band, no horizon line, no gradient to sea glass. The station's rooms sit in it as small
# warm lit rectangles in R12 end_b_wide's grammar (the #d2aa66 family, matte, navy-ink contoured, a
# faint halo), a few unlit ones darker than the plane. The office lamp is the single brightest point.
# Nothing is put behind the lens (LENS_X), which is opaque in a_room_r2. _b6 also hangs the
# lighthouse in it, upside down and dim, inside the lighthouse notice's focus (944..1056 x 236..536).

STAGE_OUT = os.path.join(ROOT, "assets", "stages", "R09")
SURF_GLASS = (52, 162, 1396, 628)
SURF_PLANE = STORM                           # #22384a, flat
ROOM_LIT = (210, 170, 102)                   # #d2aa66
ROOM_LIT_LO = (176, 140, 84)                 # the same family, further in
ROOM_DARK = (24, 40, 53)                     # an unlit room: a shade under the plane
OFFICE_POINT = (250, 234, 190)               # the brightest pixel on the plate
OFFICE_AT = (236, 318)
# storeys of the station, as the surface carries them: [y of the window line, height]
SURF_ROWS = [(214, 14), (262, 18), (318, 16), (380, 20), (444, 14)]
SURF_SKIP = [(LENS_X[0] - 10, LENS_X[1] + 10), (368, 392), (1056, 1080)]   # lens, mullions


def paint_p15_surface_on_end(rng, lighthouse_too=False, with_rooms=True):
    p = Pen(W, H, rng)
    x0, y0, x1, y1 = SURF_GLASS
    p.rect(x0, y0, x1, y1, SURF_PLANE, None)
    halos = p.layer()
    rooms = []
    for ry, rh in (SURF_ROWS if with_rooms else []):
        x = x0 + rng.uniform(14, 40)
        while x < x1 - 30:
            w = rng.choice([18, 22, 26, 30, 34])
            h = rh + rng.choice([-2, 0, 0, 2])
            yy = ry + rng.uniform(-3, 3)
            blocked = any(a - w < x < b for a, b in SURF_SKIP)
            near_office = abs(x + w / 2 - OFFICE_AT[0]) < 54 and abs(yy + h / 2 - OFFICE_AT[1]) < 40
            near_light = lighthouse_too and 930 < x + w and x < 1070
            if not (blocked or near_office or near_light):
                lit = rng.random() < 0.62
                rooms.append((x, yy, w, h, lit))
            x += w + rng.uniform(22, 64)
    for x, yy, w, h, lit in rooms:
        if lit:
            halos.ell(x + w / 2, yy + h / 2, w * 0.9, h * 1.2, ROOM_LIT, None)
    p.put_soft(halos, 9, 0.16)
    for x, yy, w, h, lit in rooms:
        if lit:
            col = mix(ROOM_LIT, ROOM_LIT_LO, rng.random() * 0.7)
            p.rect(x, yy, x + w, yy + h, col, INK, 2.2)
            p.line([(x + 3, yy + h - 4), (x + w - 3, yy + h - 4)], shade(col, 0.86), 1.6)   # a sill
        else:
            p.rect(x, yy, x + w, yy + h, ROOM_DARK, INK, 2.0)
    # the office: one small room, its lamp the single brightest point on the plate
    ox, oy = OFFICE_AT
    if not with_rooms:
        ox = oy = None
    if ox is not None:
        soft_disc(p, ox, oy, 46, AMBER, 0.42, 16)
        soft_disc(p, ox, oy, 18, mix(AMBER, PAPER_HI, 0.5), 0.6, 6)
        p.rect(ox - 22, oy - 15, ox + 22, oy + 15, ROOM_LIT, INK, 2.6)
        p.ell(ox, oy - 2, 6.5, 6.5, OFFICE_POINT, None)
        p.ell(ox, oy - 2, 3.0, 3.0, (255, 246, 222), None)
    if lighthouse_too:
        lighthouse(p, 1000, 240, 2.0, inv=True, white=mix(STORM_HI, PAPER, 0.38), band=STORM_DK,
                   glass=mix(STORM, SEAGLASS, 0.3), ink=INK, lw=4.5)
        ly = 240 + 2.0 * (432 - 330.5)
        soft_disc(p, 1000, ly, 16, AMBER, 0.22, 6)
        p.rect(995, ly - 6, 1005, ly + 6, ROOM_LIT_LO, INK, 2.0)
    im = p.done()
    clip = Image.new("L", im.size, 0)
    ImageDraw.Draw(clip).rectangle((x0, y0, x1 - 1, y1 - 1), fill=255)
    im.putalpha(ImageChops.multiply(im.getchannel("A"), clip))
    return im


# ----------------------------------------------------------------------------- fix p2: the rooms in it
# assets/stages/R09/p15_plane_r3*.png: the same flat plane as p15_surface_on_end (seed 1509), with no
# rooms in it (the _b6 one keeps the hung lighthouse). assets/stages/R09/p15_rooms_r3*.png: the
# station's rooms laid over it as lit windows, placed as on R03's general plan (PLAN_ROOMS in
# R03_view.gd), the plan's spine (the lantern gallery, the chart room, the chamber) down the lens:
#   kitchen & mess / bunks far left, the listening room and the intake office left of the lens,
#   the lantern gallery just right of it (top), the chart room under it, the wet laboratory and the
#   machine room right, the records vault and the jetty bottom right. The chamber is behind the lens.
# The intake office is the brightest window (its lamp the brightest point). The lantern gallery is
# this gallery: a pale window with its rail, and a flat navy figure standing at the rail, its back
# to us, facing out. _b6 leaves the chart room out: the lighthouse hangs there instead.
# Window rects: name -> (x0, y0, x1, y1, kind) with kind lit | dim | dark | office | gallery.
P15_WINDOWS = {
    "kitchen": (150, 300, 300, 350, "lit"),
    "bunks": (150, 366, 300, 414, "dark"),
    "listening": (402, 300, 494, 352, "dim"),
    "office": (398, 428, 498, 494, "office"),
    "gallery": (956, 172, 1044, 236, "gallery"),
    "chart": (964, 248, 1036, 290, "lit"),
    "wetlab": (1100, 300, 1214, 352, "lit"),
    "machine": (1100, 366, 1214, 392, "dim"),
    "vault": (1104, 432, 1236, 490, "dark"),
    "jetty": (1268, 462, 1380, 478, "lit"),
}
# The beads hang at y 504..516 and the outer rail crosses y 556..584: no window reaches them.
GALLERY_GLOW = (214, 226, 212)               # the gallery window: pale sea-glass paper, cold


def p15_window(p, halos, x0, y0, x1, y1, kind, rng):
    fill = {"lit": mix(ROOM_LIT, ROOM_LIT_LO, rng.random() * 0.4), "dim": ROOM_LIT_LO,
            "dark": ROOM_DARK, "office": mix(ROOM_LIT, PAPER_HI, 0.35), "gallery": GALLERY_GLOW}[kind]
    if kind in ("lit", "office", "gallery"):
        halos.ell((x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) * 0.75, (y1 - y0) * 1.0,
                  AMBER if kind == "office" else (SEAGLASS_HI if kind == "gallery" else ROOM_LIT), None)
    p.rect(x0, y0, x1, y1, fill, INK, 2.6)
    if kind == "gallery":
        return
    # glazing bars: a cross, so each reads as a window, not a lit tile
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    bar = mix(fill, INK, 0.55)
    if x1 - x0 > 40:
        p.line([(mx, y0 + 2), (mx, y1 - 2)], bar, 1.8)
    if y1 - y0 > 24:
        p.line([(x0 + 2, my), (x1 - 2, my)], bar, 1.8)
    p.line([(x0 + 3, y1 - 3), (x1 - 3, y1 - 3)], shade(fill, 0.84), 1.6)   # a sill


def paint_p15_rooms(rng, lighthouse_too=False):
    base = Pen(W, H, rng)
    p = base.layer()
    halos = base.layer()
    wins = dict(P15_WINDOWS)
    if lighthouse_too:
        wins.pop("chart")
    for name, (x0, y0, x1, y1, kind) in wins.items():
        p15_window(p, halos, x0, y0, x1, y1, kind, rng)
    # the office lamp: the brightest point on the glass
    ox0, oy0, ox1, oy1, _ = P15_WINDOWS["office"]
    ox, oy = (ox0 + ox1) / 2 - 18, (oy0 + oy1) / 2 - 6
    soft_disc(base, ox, oy, 52, AMBER, 0.5, 16)
    soft_disc(p, ox, oy, 14, mix(AMBER, PAPER_HI, 0.5), 0.7, 5)
    p.ell(ox, oy, 6.5, 6.5, OFFICE_POINT, None)
    p.ell(ox, oy, 3.0, 3.0, (255, 246, 222), None)
    # the lantern gallery: its rail across the window, and someone standing at it, facing out
    gx0, gy0, gx1, gy1, _ = P15_WINDOWS["gallery"]
    rail_y = gy1 - 18
    fig = mix(INK, STORM_DK, 0.25)
    cx = gx0 + (gx1 - gx0) * 0.46
    # the back of a head, the shoulders and a long coat, cut square: a flat shape, no face
    p.ell(cx, gy0 + 17, 7.5, 8.5, fig, None)
    p.poly([(cx - 5, gy0 + 23), (cx + 5, gy0 + 23), (cx + 6, gy0 + 28), (cx - 6, gy0 + 28)], fig, None)
    p.poly([(cx - 16, gy0 + 34), (cx - 8, gy0 + 27), (cx + 8, gy0 + 27), (cx + 16, gy0 + 34),
            (cx + 15, gy1 - 1), (cx - 15, gy1 - 1)], fig, None)
    # the rail in front of her, and its posts
    p.line([(gx0 + 2, rail_y), (gx1 - 2, rail_y)], INK, 3.2)
    p.line([(gx0 + 2, rail_y + 9), (gx1 - 2, rail_y + 9)], INK, 1.8)
    for x in (gx0 + 12, gx1 - 12):
        p.line([(x, rail_y), (x, gy1 - 1)], INK, 2.2)
    p.rect(gx0, gy0, gx1, gy1, None, INK, 2.6)
    base.put_soft(halos, 9, 0.2)
    base.put(p)
    im = base.done()
    clip = Image.new("L", im.size, 0)
    ImageDraw.Draw(clip).rectangle((SURF_GLASS[0], SURF_GLASS[1], SURF_GLASS[2] - 1, SURF_GLASS[3] - 1), fill=255)
    im.putalpha(ImageChops.multiply(im.getchannel("A"), clip))
    return im


ASSETS_P1 = [  # name, seed (random.Random(seed), not SEED + k), painter, opaque, grain; into STAGE_OUT
    ("p15_surface_on_end", 1509, paint_p15_surface_on_end, False, True),
    ("p15_surface_on_end_b6", 1509, lambda r: paint_p15_surface_on_end(r, True), False, True),
    # fix p2: the plane without its scattered rooms, and the rooms as on the general plan
    ("p15_plane_r3", 1509, lambda r: paint_p15_surface_on_end(r, False, False), False, True),
    ("p15_plane_r3_b6", 1509, lambda r: paint_p15_surface_on_end(r, True, False), False, True),
    ("p15_rooms_r3", 1510, paint_p15_rooms, False, True),
    ("p15_rooms_r3_b6", 1510, lambda r: paint_p15_rooms(r, True), False, True),
]


ASSETS_W3 = [
    ("surface_standing", 140, paint_surface_standing, True, True),
    ("surface_standing_b6", 140, lambda r: paint_surface_standing(r, True), True, True),
    ("c_view_land_r3", 62, paint_view_land3, False, True),
    ("c_view_sea_r3", 63, paint_view_sea3, False, True),
    ("c_rim_round", 141, paint_rim_round, False, False),
    ("c_rim_crack", 142, paint_rim_crack, False, False),
]


ASSETS_R2 = [
    ("a_room_r2", 100, paint_a_room2, False, True),
    ("b_room_r2", 101, paint_b_room2, False, True),
    ("b_rail_r2", 50, rail_b2, False, False),
    ("a_surf_b4_r2", 110, lambda r: paint_surf2(r, "a", "b4"), True, True),
    ("a_surf_b4o_r2", 110, lambda r: paint_surf2(r, "a", "b4o"), True, True),
    ("a_surf_b5_r2", 111, lambda r: paint_surf2(r, "a", "b5"), True, True),
    ("a_surf_b6_r2", 112, lambda r: paint_surf2(r, "a", "b6"), True, True),
    ("a_sea_b7_r2", 113, lambda r: paint_b7_2(r, "a"), True, True),
    ("b_sea_b3_r2", 114, paint_b_sea_b3_2, True, True),
    ("b_sea_sever_r2", 134, lambda r: paint_b_sea_b3_2(r, grey=True), True, True),
    ("b_surf_b4_r2", 115, lambda r: paint_surf2(r, "b", "b4"), True, True),
    ("b_surf_b5_r2", 116, lambda r: paint_surf2(r, "b", "b5"), True, True),
    ("b_surf_b6_r2", 117, lambda r: paint_surf2(r, "b", "b6"), True, True),
    ("b_sea_b7_r2", 118, lambda r: paint_b7_2(r, "b"), True, True),
    ("vchop_tile_r2", 119, paint_vchop_tile, False, False),
    ("a_refl_b4_r2", 120, lambda r: paint_refl2(r, A_REFL2), False, False),
    ("a_refl_b6_r2", 121, lambda r: paint_refl2(r, A_REFL2_B6), False, False),
    ("b_refl_b4_r2", 122, lambda r: paint_refl2(r, B_REFL2), False, False),
    ("b_refl_b6_r2", 123, lambda r: paint_refl2(r, B_REFL2_B6), False, False),
    ("a_lid_band_r2", 124, paint_lid_band, False, False),
    ("beads_r2", 125, paint_beads, False, False),
    ("rain_sparse_r2", 126, paint_rain_sparse, False, False),
    ("a_lens_surf_b5_r2", 127, lambda r: paint_lens_surf(r, "b5"), False, False),
    ("a_lens_surf_b6_r2", 128, lambda r: paint_lens_surf(r, "b6"), False, False),
    ("a_lens_ada_inv_r2", 129, paint_lens_ada_inv2, False, False),
    ("c_scope_r2", 130, paint_c_scope2, True, True),
    ("c_ruler_r2", 131, paint_c_ruler2, True, True),
    ("c_view_station_r2", 132, paint_view_station2, False, True),
    ("c_view_surface_r2", 133, paint_view_surface2, False, True),
]


# ----------------------------------------------------------------------------- the table

ASSETS = [  # name, seed index, painter, opaque, grain
    ("a_room", 0, paint_a_room, False, True),
    ("a_sea_b3", 10, lambda r: paint_sea(r, "a", "b3"), True, True),
    ("a_sea_b4_bare", 11, lambda r: paint_sea(r, "a", "b4_bare"), True, True),
    ("a_sea_b4_shut", 11, lambda r: paint_sea(r, "a", "b4_shut"), True, True),
    ("a_sea_b4", 11, lambda r: paint_sea(r, "a", "b4"), True, True),
    ("a_sea_b5", 12, lambda r: paint_sea(r, "a", "b5"), True, True),
    ("a_sea_b6", 12, lambda r: paint_sea(r, "a", "b6"), True, True),
    ("a_sea_b7", 13, lambda r: paint_sea(r, "a", "b7"), True, True),
    ("a_sea_sever", 14, lambda r: paint_sea(r, "a", "sever"), True, True),
    ("a_rail", 20, lambda r: rail_a(r, False), False, False),
    ("a_rail_wet", 20, lambda r: rail_a(r, True), False, False),
    ("a_lid_line", 21, paint_lid_line, False, False),
    ("a_iris_shut", 22, lambda r: paint_iris(r, False), False, False),
    ("a_iris_open", 23, lambda r: paint_iris(r, True), False, False),
    ("a_lens_ada", 24, lambda r: paint_lens_ada(r, False), False, False),
    ("a_lens_ada_inv", 25, lambda r: paint_lens_ada(r, True), False, False),
    ("rain_tile", 26, paint_rain, False, False),
    ("b_room", 30, paint_b_room, False, True),
    ("b_sea_b3", 40, lambda r: paint_sea(r, "b", "b3"), True, True),
    ("b_sea_b4", 41, lambda r: paint_sea(r, "b", "b4"), True, True),
    ("b_sea_b5", 42, lambda r: paint_sea(r, "b", "b5"), True, True),
    ("b_sea_b6", 42, lambda r: paint_sea(r, "b", "b6"), True, True),
    ("b_sea_b7", 43, lambda r: paint_sea(r, "b", "b7"), True, True),
    ("b_sea_sever", 44, lambda r: paint_sea(r, "b", "sever"), True, True),
    ("b_rail", 50, lambda r: rail_b(r, False), False, False),
    ("b_rail_wet", 50, lambda r: rail_b(r, True), False, False),
    ("b_pennant_dead", 51, paint_pennant_dead, False, False),
    ("b_pennant_out", 52, paint_pennant_out, False, False),
    ("b_pennant_flap_1", 53, lambda r: paint_pennant_flap(r, 1), False, False),
    ("b_pennant_flap_2", 54, lambda r: paint_pennant_flap(r, 2), False, False),
    ("b_ruler", 55, paint_b_ruler, False, False),
    ("c_scope", 60, paint_c_scope, True, True),
    ("c_eyepiece_ring", 61, paint_eyepiece_ring, False, False),
    ("c_view_land", 62, paint_view_land, False, True),
    ("c_view_sea", 63, paint_view_sea, False, True),
    ("c_view_station", 64, paint_view_station, False, True),
    ("c_view_surface", 65, paint_view_surface, False, True),
    ("c_patch", 66, paint_patch, False, False),
    ("c_steam", 67, paint_steam, False, False),
    ("c_loupe_ring", 68, paint_loupe_ring, False, False),
    ("c_frame_mounted", 69, paint_frame_mounted, False, False),
    ("c_sel_knob", 70, paint_sel_knob, False, False),
    ("c_key_up", 71, lambda r: paint_key(r, False), False, False),
    ("c_key_down", 72, lambda r: paint_key(r, True), False, False),
    ("c_strip", 73, paint_strip, False, False),
    ("c_ruler", 74, paint_c_ruler, True, True),
]


def main(argv):
    pats = argv or ["*"]
    for name, k, fn, opaque, gr in ASSETS + ASSETS_R2 + ASSETS_W3:
        if not any(fnmatch.fnmatch(name, pat) for pat in pats):
            continue
        rng = rng_for(k)
        res = fn(rng)
        im = res.done() if isinstance(res, Pen) else res
        if gr:
            im = grain(im, rng_for(1000 + k))
        save(im, name, opaque)
    for name, sd, fn, opaque, gr in ASSETS_P1:
        if not any(fnmatch.fnmatch(name, pat) for pat in pats):
            continue
        res = fn(random.Random(sd))
        im = res.done() if isinstance(res, Pen) else res
        if gr:
            im = grain(im, random.Random(1000 + sd))
        save(im, name, opaque, STAGE_OUT)


if __name__ == "__main__":
    main(sys.argv[1:])
