#!/usr/bin/env python3
"""R04 Listening Room painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R04/*.png:

  view_a, view_a_s2, view_a_turned, view_a_s3, view_a_s4, view_a_sever
                                         funnel wall stage plates (1448x1086 opaque): bands
                                         0-2, 3, 4, 5-6, 7 and the sever ending's released room
  a_condensation(_turned), a_seat_rings, a_bulge, a_mounted, a_transcript, a_printout_long
                                         view A overlays (RGBA)
  a_tag5.png                             funnel 5's paper tag sprite (pivot 6,24)
  view_b, view_b_s2, view_b_s3, view_b_s4   channel board stage plates (opaque)
  b_motor_off, b_spool, b_mixer_aligned, b_condensation, b_speaker_wet, b_bulge   overlays
  b_lamp_lit, b_needle, b_key_open, b_key_closed                       sprites
  {a,b}_{mul,add}_{s1,s2,s3,s4,sever}    quarter-size light maps the view lays over each plate
                                         (multiply: vignette, lamp falloff, the stage's cold;
                                         additive: the lamp's warm pool)
  c_spindle, c_mixer, c_channels         close-up plates (opaque)
  c_band, c_needle_arm, c_lever_up, c_lever_down, c_lamp_lit, c_witness_down   sprites

Flat front elevation, approved palette, navy ink contours, matte colour and a low seeded
paper grain. No text, numerals, glyphs or waveforms except the one plain graphic the
contract asks for (b_mixer_aligned) and the printout's grey type dashes: every label field is a
blank plate the view writes on.
Registration follows the R04 art task; the hotspots in R04_view.gd are fixed to it.

Python 3 + PIL only. Deterministic: each asset has its own random.Random(SEED + k), there is
no clock and no PIL noise effect, so a rerun is byte-identical.

    python3 tools/art/rooms/R04.py              # paint everything
    python3 tools/art/rooms/R04.py view_a b_*   # paint some (fnmatch patterns)
"""
import fnmatch
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "rooms", "R04")
W, H = 1448, 1086
SS = 2                      # supersampling for every painted shape
SEED = 1931_04_00

# ----------------------------------------------------------------------------- palette
INK = (23, 43, 54)          # #172B36 contours
PAPER = (216, 206, 181)     # #D8CEB5
PAPER_HI = (232, 225, 207)
ENAMEL = (226, 220, 202)    # blank label plates
SEAGLASS = (97, 125, 116)   # #617D74
SEAGLASS_HI = (150, 178, 166)
TIMBER = (103, 93, 81)      # #675D51 damp timber
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
VIOLET = (116, 101, 119)    # #746577
CORK = (164, 128, 90)
CORK_DK = (132, 100, 68)
CORK_HI = (184, 150, 110)
PLASTER = (214, 207, 188)
PLASTER_DK = (186, 177, 156)
PLASTER_HI = (232, 227, 212)
WAINSCOT = (40, 64, 82)
WAINSCOT_DK = (30, 50, 66)
POLISH = (168, 114, 74)     # the seat, polished by use
POLISH_HI = (204, 152, 106)
POLISH_DK = (138, 92, 58)
CABINET = (158, 120, 86)
CABINET_DK = (128, 96, 68)
CABINET_HI = (182, 146, 108)
PANEL = (44, 66, 84)        # enamelled instrument plates
PANEL_DK = (32, 50, 64)
IRON = (38, 46, 54)
GLASS_DK = (18, 30, 36)
THROAT = (14, 22, 28)
WAX = (204, 192, 166)
EBONY = (34, 32, 30)
FOG = (196, 220, 210)
BEAD = (236, 244, 240)
DUST = (238, 232, 216)

CHANNELS = (505, 675, 845)


# ----------------------------------------------------------------------------- helpers

def rng_for(k):
    return random.Random(SEED + k)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c0, c1, t):
    return tuple(int(round(lerp(a, b, t))) for a, b in zip(c0, c1))


def rgba(c, a=255):
    return c if len(c) == 4 else (c[0], c[1], c[2], a)


def capsule(p0, p1, r0, r1, n=12):
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ang = math.atan2(dy, dx)
    pts = []
    for k in range(n + 1):
        t = ang - math.pi / 2 + math.pi * k / n
        pts.append((p1[0] + r1 * math.cos(t), p1[1] + r1 * math.sin(t)))
    for k in range(n + 1):
        t = ang + math.pi / 2 + math.pi * k / n
        pts.append((p0[0] + r0 * math.cos(t), p0[1] + r0 * math.sin(t)))
    return pts


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
        return max(1, int(round((w + self.rng.uniform(-0.4, 0.4)) * SS)))

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

    def oval(self, cx, cy, rx, ry, ang=0.0, fill=None, ink=INK, w=3.0, n=96):
        if abs(rx - ry) < 0.01:
            return self.ell(cx, cy, rx, ry, fill, ink, w)
        ca, sa = math.cos(ang), math.sin(ang)
        pts = []
        for i in range(n):
            t = 2 * math.pi * i / n
            x, y = rx * math.cos(t), ry * math.sin(t)
            pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
        self.poly(pts, fill, ink, w)

    def line(self, pts, col=INK, w=3.0):
        self.d.line(self._p(pts), fill=rgba(col), width=self.iw(w), joint="curve")

    def arc(self, cx, cy, rx, ry, a0, a1, col, w=3.0):
        box = ((cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS)
        self.d.arc(box, a0, a1, fill=rgba(col), width=self.iw(w))

    def layer(self):
        return Pen(self.w, self.h, self.rng)

    def put(self, other, opacity=1.0, mask=None):
        src = other.im
        if opacity < 1.0:
            a = src.getchannel("A").point(lambda v: int(v * opacity))
            src = src.copy()
            src.putalpha(a)
        if mask is not None:
            src = src.copy()
            src.putalpha(ImageChops.multiply(src.getchannel("A"), mask))
        self.im.alpha_composite(src)

    def done(self):
        return self.im.resize((self.w, self.h), Image.LANCZOS)

    def put_soft(self, other, radius, opacity=1.0, mask=None):
        """Composite a layer blurred by `radius` logical px: shadows, blooms, halos."""
        other.im = other.im.filter(ImageFilter.GaussianBlur(radius * SS))
        self.put(other, opacity, mask)


def bezier(p0, p1, p2, n=28):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return out


def offset_line(pts, d):
    """The polyline moved `d` px along its left normal (screen space)."""
    out = []
    for i, (x, y) in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        m = math.hypot(tx, ty) or 1.0
        out.append((x + ty / m * d, y - tx / m * d))
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
        # Zero the colour of fully transparent pixels so files stay small and stable.
        a = im.getchannel("A")
        clear = a.point(lambda v: 255 if v == 0 else 0)
        im.paste((0, 0, 0, 0), mask=clear)
    path = os.path.join(OUT, name + ".png")
    im.save(path, optimize=False, compress_level=9)
    print("  wrote", os.path.relpath(path, ROOT), im.size, im.mode)


# ----------------------------------------------------------------------------- shared room parts

def room_shell(p, rng, plaster_ceiling=False):
    """Ceiling band, cork wall panels, dado rail, navy wainscot and floor."""
    if plaster_ceiling:
        # the navy ceiling continues from view A; a pale plaster cornice runs under it
        p.rect(-4, -4, W + 4, 84, STORM, None)
        p.line([(-4, 40), (W + 4, 40)], STORM_HI, 2)
        p.rect(-4, 76, W + 4, 88, STORM, INK, 3)
        p.rect(-4, 88, W + 4, 118, PLASTER_DK, None)
        lay = p.layer()
        for k in range(9):  # faint trowel sweeps on the cornice
            x = rng.uniform(0, W)
            lay.arc(x, 104, rng.uniform(80, 160), 10, 205, 335, PLASTER_HI, 3)
        p.put(lay, 0.5)
        p.line([(-4, 92), (W + 4, 92)], PLASTER_HI, 2)
        p.line([(-4, 108), (W + 4, 108)], mix(PLASTER_DK, INK, 0.25), 2)
        p.rect(-4, 112, W + 4, 130, STORM, INK, 3)
        p.line([(-4, 124), (W + 4, 124)], STORM_HI, 2)
        top = 130
    else:
        p.rect(-4, -4, W + 4, 66, STORM, None)
        p.line([(-4, 52), (W + 4, 52)], STORM_HI, 2)
        p.rect(-4, 60, W + 4, 74, STORM, INK, 3)
        top = 74
    # cork wall
    p.rect(-4, top, W + 4, 578, CORK, None)
    seams = [-4] + [int(i * 181 + rng.uniform(-4, 4)) for i in range(1, 8)] + [W + 4]
    for x in seams[1:-1]:
        p.line([(x, top), (x, 578)], CORK_DK, 2.5)
        p.line([(x + 2, top), (x + 2, 578)], CORK_HI, 1.2)
    for _ in range(2600):  # cork crumbs
        x, y = rng.uniform(0, W), rng.uniform(top + 2, 576)
        r = rng.choice((1.0, 1.2, 1.5, 2.0, 2.4))
        c = CORK_DK if rng.random() < 0.62 else CORK_HI
        p.ell(x, y, r, r * rng.uniform(0.6, 1.0), c, None)
    # dado rail
    p.rect(-4, 572, W + 4, 598, TIMBER, INK, 3)
    p.line([(-4, 580), (W + 4, 580)], TIMBER_HI, 2)
    # wainscot boards
    p.rect(-4, 598, W + 4, 912, WAINSCOT, None)
    for x in range(36, W, 52):
        p.line([(x, 600), (x, 908)], WAINSCOT_DK, 3)
        p.line([(x + 3, 600), (x + 3, 908)], STORM_HI, 1.2)
    p.rect(-4, 888, W + 4, 912, STORM, INK, 3)  # skirting
    # floor planks
    p.rect(-4, 910, W + 4, H + 4, TIMBER, INK, 3)
    y = 910
    k = 0
    while y < H:
        hgt = 40 + k * 6
        p.line([(-4, y + hgt), (W + 4, y + hgt)], TIMBER_DK, 2.5)
        off = rng.uniform(0, 300)
        x = off
        while x < W:
            p.line([(x, y + 3), (x, y + hgt - 3)], TIMBER_DK, 2)
            x += rng.uniform(320, 520)
        p.line([(-4, y + 3), (W + 4, y + 3)], TIMBER_HI, 1.2)
        y += hgt
        k += 1


def bolt(p, x, y, r=4):
    p.ell(x, y, r, r, BRASS_HI, INK, 1.5)


def bezel(p, x0, y0, x1, y1, r=8, m=6):
    """Brass frame round an instrument plate: separates it from the damp timber."""
    p.rect(x0 - m, y0 - m, x1 + m, y1 + m, BRASS_HI, INK, 3, r=r + m // 2)


# ----------------------------------------------------------------------------- view A parts
#
# The funnel wall. Six ear trumpets in profile: each pipe leaves a hand-trowelled plaster collar,
# runs 120-200 px of brass tube to a swivel knuckle N, and the horn flares from N along its axis.
# At rest every bell hangs down-right, parallel (funnel 5 alone faces the wall, seen from behind);
# turned, every axis aims at the seat. Stage 1-4 paints the room's own decay (damp bloom, tide
# line, glossy swollen plaster, the seat let down); light itself lives in the a_mul/a_add maps.

THROAT_DEEP = (6, 9, 12)     # the bells' throats: the darkest thing in the room at every stage
SHADOW = (38, 30, 22)
AIM = (266, 712)             # the seat: every turned bell axis passes through here
HORN_L, HORN_R, HORN_R0 = 92, 46, 9
STRAIGHT_ANG = 55.0          # at rest: down-right, all six parallel (5 faces the wall)
BACK_ANG = 235.0             # funnel 5 at rest: mouth into the plaster, up-left
HORNS = {                    # n: (collar on the plaster, tube control point, knuckle N)
    1: ((186, 124), (272, 92), (300, 150)),
    2: ((386, 124), (472, 92), (500, 150)),
    3: ((586, 124), (672, 92), (700, 150)),
    4: ((150, 296), (232, 376), (300, 340)),
    5: ((664, 474), (606, 452), (530, 400)),
    6: ((858, 296), (778, 388), (700, 340)),
}
# Number tabs (centre x, top y) the view draws on; R04_view.gd TABS / TABS_TURNED mirror these.
TABS = {1: (353, 262), 2: (553, 262), 3: (753, 262), 4: (353, 452), 5: (456, 364), 6: (753, 452)}
TABS_TURNED = {1: (294, 267), 2: (465, 266), 3: (644, 261), 4: (292, 457), 5: (471, 509), 6: (702, 394)}
TAG5 = (540, 392)            # funnel 5's paper tag hangs from its knuckle
LAMP = (990, 438)            # the hooded lamp's shade (centre of its mouth)
INDICATOR = (930, 500)       # amber jewel on the cabinet upstand: the last warm light
TIDE_Y = 505                 # the tide-line stain, level with the top of the let-down seat's arms


def horn_geo(n, turned):
    collar, ctrl, N = HORNS[n]
    if turned:
        ang = math.atan2(AIM[1] - N[1], AIM[0] - N[0])
    else:
        ang = math.radians(BACK_ANG if n == 5 else STRAIGHT_ANG)
    u = (math.cos(ang), math.sin(ang))
    v = (-u[1], u[0])
    M = (N[0] + u[0] * HORN_L, N[1] + u[1] * HORN_L)
    return {"n": n, "collar": collar, "ctrl": ctrl, "N": N, "M": M, "ang": ang, "u": u, "v": v,
            "back": n == 5 and not turned, "k": 0.56 if (n == 5 and not turned) else 0.42}


def horn_radius(s):
    return HORN_R0 + (HORN_R - HORN_R0) * s ** 2.4


def horn_body(g, steps=30, d=(0.0, 0.0)):
    N, u, v = g["N"], g["u"], g["v"]
    left, right = [], []
    for i in range(steps + 1):
        s = i / steps
        r = horn_radius(s)
        cx, cy = N[0] + u[0] * HORN_L * s + d[0], N[1] + u[1] * HORN_L * s + d[1]
        left.append((cx + v[0] * r, cy + v[1] * r))
        right.append((cx - v[0] * r, cy - v[1] * r))
    return left + right[::-1]


def mouth_oval(p, g, scale=1.0, back_shift=0.0, fill=None, ink=INK, w=3.0, d=(0.0, 0.0)):
    M, u = g["M"], g["u"]
    cx = M[0] - u[0] * back_shift + d[0]
    cy = M[1] - u[1] * back_shift + d[1]
    ang_v = g["ang"] + math.pi / 2
    p.oval(cx, cy, HORN_R * scale, HORN_R * scale * g["k"], ang_v, fill, ink, w)


def mouth_points(g, scale=1.0, n=48):
    M, ang_v = g["M"], g["ang"] + math.pi / 2
    ca, sa = math.cos(ang_v), math.sin(ang_v)
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = HORN_R * scale * math.cos(t), HORN_R * scale * g["k"] * math.sin(t)
        out.append((M[0] + x * ca - y * sa, M[1] + x * sa + y * ca))
    return out


def tube_points(g):
    return bezier(g["collar"], g["ctrl"], g["N"], 32)


def lit_sign(g):
    """+1 if the +v side of the horn faces the light (upper right), else -1."""
    return 1.0 if (g["v"][0] * 0.8 - g["v"][1] * 0.6) > 0 else -1.0


def horn_tube(p, g):
    pts = tube_points(g)
    p.line(pts, INK, 17)
    p.line(pts, BRASS, 11.5)
    p.line([(x + 1.5, y - 2.5) for x, y in pts[1:-2]], BRASS_HI, 2.6)
    p.line([(x - 1.5, y + 3.0) for x, y in pts[1:-2]], BRASS_LO, 2.4)
    # a soldered band a third of the way along
    i = len(pts) // 3
    (ax, ay), (bx, by) = pts[i - 1], pts[i + 1]
    m = math.hypot(bx - ax, by - ay) or 1.0
    nx, ny = -(by - ay) / m, (bx - ax) / m
    cx, cy = pts[i]
    p.line([(cx - nx * 9, cy - ny * 9), (cx + nx * 9, cy + ny * 9)], INK, 2.2)


def plaster_collar(p, rng, c, swollen=False):
    """A crude hand-trowelled collar where the pipe enters the wall; casts a short shadow left."""
    pts = []
    for i in range(22):
        a = 2 * math.pi * i / 22
        rr = 25 + rng.uniform(-4, 4.5)
        pts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr * 0.92))
    sh = p.layer()
    sh.poly([(x - 7, y + 6) for x, y in pts], SHADOW + (255,), None)
    p.put_soft(sh, 4, 0.45)
    p.poly(pts, PLASTER_HI, mix(INK, PLASTER_DK, 0.45), 2.2)
    inner = [(c[0] + (x - c[0]) * 0.58, c[1] + (y - c[1]) * 0.58) for x, y in pts]
    p.poly(inner, PLASTER, None)
    for k in range(3):  # trowel smears round the pipe, ridge lit from the right
        a0 = rng.uniform(0, 360)
        p.arc(c[0], c[1], 18 + k * 3, 17 + k * 3, a0, a0 + rng.uniform(60, 110), PLASTER_DK, 2)
        p.arc(c[0] + 1.5, c[1], 18 + k * 3, 17 + k * 3, a0, a0 + 50, (246, 243, 232), 1.4)
    p.ell(c[0], c[1], 9.5, 9, BRASS_DK, INK, 2.2)  # the pipe's last visible lip


def horn(p, g):
    lit = lit_sign(g)
    N, u, v = g["N"], g["u"], g["v"]
    if g["back"]:
        # seen from behind: the flare's outer back shows past the cone, the mouth hidden
        wet = p.layer()
        mouth_oval(wet, g, 1.12, fill=(52, 60, 56, 255), ink=None, d=(-4, 4))
        p.put_soft(wet, 5, 0.55)
        mouth_oval(p, g, 1.0, fill=BRASS_DK, ink=INK, w=3.5)
        mouth_oval(p, g, 0.9, fill=None, ink=BRASS_HI, w=2.4)
        p.poly(horn_body(g), BRASS, INK, 3.2)
    else:
        p.poly(horn_body(g), BRASS, INK, 3.2)
    # rolled-brass shading along the cone: lit flank and shadow flank
    hi, lo = [], []
    for i in range(4, 29):
        s = i / 30
        r = horn_radius(s)
        cx, cy = N[0] + u[0] * HORN_L * s, N[1] + u[1] * HORN_L * s
        hi.append((cx + v[0] * r * 0.55 * lit, cy + v[1] * r * 0.55 * lit))
        lo.append((cx - v[0] * r * 0.62 * lit, cy - v[1] * r * 0.62 * lit))
    p.line(lo, BRASS_LO, 5)
    p.line(hi, BRASS_HI, 3.4)
    if not g["back"]:
        # the open mouth at three-quarters: rim, then a throat that recedes toward the knuckle
        mouth_oval(p, g, 1.0, fill=BRASS_LO, ink=INK, w=3.2)
        steps = 11
        for i in range(steps):
            t = i / (steps - 1)
            mouth_oval(p, g, lerp(0.86, 0.2, t), back_shift=t * 14, fill=mix(BRASS_DK, THROAT_DEEP, t ** 0.55), ink=None)
        mouth_oval(p, g, 0.86, fill=None, ink=mix(INK, BRASS_LO, 0.3), w=1.8)
        # the far inner lip catches light
        pts = mouth_points(g, 0.93)
        n = len(pts)
        seg = [q for i, q in enumerate(pts) if (math.sin(2 * math.pi * i / n) * -lit) > 0.35]
        if len(seg) > 2:
            p.line(seg, BRASS_HI, 2.6)
    # swivel knuckle where the tube meets the horn
    p.ell(N[0], N[1], 11, 11, BRASS_LO, INK, 2.6)
    p.ell(N[0] + 2.5, N[1] - 2.5, 4, 4, BRASS_HI, None)


def horn_shadows(p, geo):
    sh = p.layer()
    d = (-13, 11)
    for g in geo.values():
        sh.line([(x + d[0], y + d[1]) for x, y in tube_points(g)], SHADOW + (255,), 15)
        sh.poly(horn_body(g, d=d), SHADOW + (255,), None)
        mouth_oval(sh, g, 1.0, fill=SHADOW + (255,), ink=None, d=d)
    p.put_soft(sh, 7, 0.32)


def funnels(p, rng, turned):
    geo = {n: horn_geo(n, turned) for n in HORNS}
    horn_shadows(p, geo)
    for n in (4, 6, 5, 1, 2, 3):
        horn_tube(p, geo[n])
    crng = rng_for(41)
    for n in (1, 2, 3, 4, 5, 6):
        plaster_collar(p, crng, geo[n]["collar"])
    for n in (4, 6, 5, 1, 2, 3):
        horn(p, geo[n])
    for n in HORNS:  # a wire hanger from each rim to the number tab the view writes on
        tx, ty = (TABS_TURNED if turned else TABS)[n]
        g = geo[n]
        near = min(mouth_points(g, 0.98) + horn_body(g), key=lambda q: math.hypot(q[0] - tx, q[1] - ty))
        p.line([near, (tx, ty + 2)], INK, 1.8)
        p.ell(tx, ty + 1, 3, 3, BRASS_HI, INK, 1.2)
    if not turned:
        p.ell(TAG5[0], TAG5[1], 4.5, 4.5, BRASS_HI, INK, 2)   # eyelet for funnel 5's tag string
    return geo


# --- plaster -----------------------------------------------------------------------------

def plaster_outline(rng):
    """An irregular patched field with ragged edges biting into the cork."""
    corners = [(66, 88), (500, 80), (936, 86), (944, 320), (934, 552), (520, 560), (72, 548), (60, 300)]
    pts = []
    for i in range(len(corners)):
        a, b = corners[i], corners[(i + 1) % len(corners)]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        steps = max(2, int(L / 13))
        nx, ny = (b[1] - a[1]) / L, -(b[0] - a[0]) / L
        bite = 0.0
        for s in range(steps):
            t = s / steps
            if rng.random() < 0.07:
                bite = rng.uniform(8, 22) * rng.choice((-1, 1))
            bite *= 0.72
            j = rng.uniform(-3.5, 3.5) + bite
            pts.append((lerp(a[0], b[0], t) + nx * j, lerp(a[1], b[1], t) + ny * j))
    return pts


def blob(rng, cx, cy, rx, ry, n=20, jit=0.22):
    pts = []
    ph = rng.uniform(0, 6.28)
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1 + jit * math.sin(3 * a + ph) * 0.6 + rng.uniform(-jit, jit) * 0.5
        pts.append((cx + math.cos(a) * rx * k, cy + math.sin(a) * ry * k))
    return pts


def plaster_mask(outline, size):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in outline], fill=255)
    return m


def plaster_field(p, rng, stage):
    outline = plaster_outline(rng)
    pm = plaster_mask(outline, p.im.size)
    sh = p.layer()
    sh.poly([(x - 5, y + 5) for x, y in outline], SHADOW + (255,), None)
    p.put_soft(sh, 3, 0.4)
    p.poly(outline, PLASTER, None)
    # overpaint layers: three off-whites, each patch with its own faint edge
    over = p.layer()
    tones = [PLASTER_HI, (222, 215, 197), (204, 196, 175), (228, 224, 210)]
    for k in range(11):
        cx, cy = rng.uniform(110, 890), rng.uniform(120, 520)
        rx, ry = rng.uniform(70, 190), rng.uniform(50, 120)
        pts = blob(rng, cx, cy, rx, ry, 26, 0.3)
        col = tones[k % len(tones)]
        over.poly(pts, col + (170,), mix(PLASTER_DK, INK, 0.1) + (70,), 1.4)
    p.put_soft(over, 0.8, 1.0, mask=pm)
    # trowel ridges raked by light from the right: shadowed left lip, lit right lip
    tr = p.layer()
    for _ in range(46):
        x, y = rng.uniform(100, 900), rng.uniform(110, 530)
        rx, ry = rng.uniform(30, 80), rng.uniform(8, 18)
        a0 = rng.uniform(195, 230)
        a1 = a0 + rng.uniform(70, 120)
        tr.arc(x, y, rx, ry, a0, a1, PLASTER_DK + (200,), 2.4)
        tr.arc(x + 2.5, y + 0.5, rx, ry, a0 + 10, a1 - 6, (247, 244, 234, 220), 1.6)
    p.put(tr, 0.75, mask=pm)
    for hx, hy, hw, hh in ((92, 380, 44, 30), (842, 470, 52, 28)):  # plaster fallen away: lath behind
        hole = blob(rng_for(49), hx, hy, hw / 2, hh / 2, 18, 0.25)
        p.poly(hole, (70, 56, 42), mix(INK, PLASTER_DK, 0.4), 2)
        lath = p.layer()
        for k in range(-2, 3):
            lath.rect(hx - hw, hy + k * 8 - 2.5, hx + hw, hy + k * 8 + 2.5, TIMBER_HI + (255,), None)
        hm = Image.new("L", p.im.size, 0)
        ImageDraw.Draw(hm).polygon([(x * SS, y * SS) for x, y in hole], fill=255)
        p.put(lath, 1.0, mask=hm)
        p.poly(hole, None, mix(INK, PLASTER_DK, 0.3), 2.2)
    for start in ((96, 470), (900, 128)):  # two old hairline cracks far from the collars
        x, y = start
        pts = [(x, y)]
        for _ in range(5):
            x += rng.uniform(10, 22) * (1 if start[0] < 400 else -1)
            y += rng.uniform(-10, 12)
            pts.append((x, y))
        p.line(pts, mix(INK, PLASTER, 0.5), 1.4)
    if stage >= 2:  # damp: grey-green mottling creeping up from the bottom edge and the collars
        dm = p.layer()
        drng = rng_for(42)
        for _ in range(9 + 4 * stage):
            cx = drng.uniform(80, 920)
            cy = drng.uniform(400, 560) if drng.random() < 0.6 else drng.uniform(110, 520)
            dm.poly(blob(drng, cx, cy, drng.uniform(40, 90) * (0.7 + 0.2 * stage), drng.uniform(24, 60)),
                    (120, 132, 116, 255), None)
        p.put_soft(dm, 14, 0.22 + 0.08 * stage, mask=pm)
    if stage >= 4:  # swollen and glossy: wet sheen streaks running down
        gl = p.layer()
        grng = rng_for(43)
        for _ in range(26):
            x, y = grng.uniform(90, 910), grng.uniform(100, 470)
            gl.line([(x, y), (x + grng.uniform(-6, 6), y + grng.uniform(30, 90))], (255, 255, 250, 255), grng.uniform(3, 6))
        p.put_soft(gl, 3, 0.35, mask=pm)
        dk = p.layer()
        for _ in range(10):
            cx, cy = grng.uniform(100, 900), grng.uniform(130, 520)
            dk.poly(blob(grng, cx, cy, grng.uniform(50, 110), grng.uniform(30, 70)), (96, 110, 100, 255), None)
        p.put_soft(dk, 18, 0.28, mask=pm)
    p.poly(outline, None, mix(INK, PLASTER_DK, 0.4), 2.2)
    return pm


def damp_bloom(p, stage):
    """Damp spreading on the cork from the plaster outward, with darker tide-mark rims."""
    rng = rng_for(44)
    lay = p.layer()
    rims = p.layer()
    grow = 1.0 + 0.45 * (stage - 2)
    for _ in range(18):
        side = rng.random()
        if side < 0.4:
            cx, cy = rng.uniform(60, 940), rng.uniform(70, 120)
        elif side < 0.75:
            cx, cy = rng.uniform(60, 940), rng.uniform(520, 580)
        else:
            cx, cy = rng.choice((rng.uniform(40, 80), rng.uniform(930, 990))), rng.uniform(100, 560)
        rx, ry = rng.uniform(50, 110) * grow, rng.uniform(40, 90) * grow
        pts = blob(rng, cx, cy, rx, ry, 24, 0.35)
        lay.poly(pts, (88, 70, 50, 255), None)
        rims.line(pts + [pts[0]], (78, 58, 40, 255), 3)
    cork = clip_mask(p.im.size, [(-4, 70, W + 4, 574)])
    p.put_soft(lay, 16, 0.42, mask=cork)
    p.put_soft(rims, 3, 0.16, mask=cork)


def tide_line(p, x1=1336, y=TIDE_Y):
    rng = rng_for(45)
    pts = [(x, y + 2.4 * math.sin(x / 37.0) + rng.uniform(-1.2, 1.2)) for x in range(-4, x1 + 8, 8)]
    below = p.layer()
    below.poly(pts + [(x1 + 4, y + 36), (-4, y + 36)], (70, 86, 70, 255), None)
    p.put_soft(below, 8, 0.32)
    p.line(pts, (62, 74, 60), 4.2)
    p.line([(x, yy - 4) for x, yy in pts], (236, 234, 220), 2.2)       # salt crust above the stain


# --- the seat ------------------------------------------------------------------------------

def seat(p, down):
    """A theatre tip-up seat between two cast-iron standards. Up, the face is vertical in
    elevation (the band-3 wax rings sit on it); let down, only its front edge shows."""
    sh = p.layer()
    sh.ell(270, 912, 132, 10, SHADOW + (255,), None)
    sh.rect(150, 640, 380, 905, SHADOW + (255,), None, r=20)
    p.put_soft(sh, 8, 0.3)
    for x0 in (164, 348):
        p.rect(x0, 640, x0 + 28, 906, IRON, INK, 3, r=6)
        p.line([(x0 + 7, 652), (x0 + 7, 896)], (70, 80, 88), 2)
        p.rect(x0 - 8, 630, x0 + 36, 648, TIMBER, INK, 3, r=6)       # arm cap
        p.line([(x0 - 4, 635), (x0 + 32, 635)], TIMBER_HI, 1.6)
        p.rect(x0 - 10, 894, x0 + 38, 912, IRON, INK, 3, r=3)        # foot
        bolt(p, x0 + 14, 772, 6)                                     # hinge boss
    p.line([(192, 772), (348, 772)], INK, 7)
    p.line([(192, 772), (348, 772)], BRASS_LO, 3.5)
    if not down:
        p.rect(196, 604, 344, 786, POLISH_DK, INK, 4, r=20)
        p.rect(206, 614, 334, 776, POLISH, INK, 2, r=14)
        gl = p.layer()
        rg = random.Random(SEED + 501)
        for k in range(-4, 5):
            x = 270 + k * 14 + rg.uniform(-3, 3)
            gl.line([(x + 3 * math.sin(i * 0.6 + k), 618 + i * 13) for i in range(13)], POLISH_DK + (255,), 1.5)
        face = Image.new("L", p.im.size, 0)
        ImageDraw.Draw(face).rounded_rectangle((208 * SS, 616 * SS, 332 * SS, 774 * SS), radius=14 * SS, fill=255)
        p.put(gl, 0.5, mask=face)
        wl = p.layer()
        wl.ell(270, 700, 48, 58, POLISH_HI + (110,), None)            # worn smooth where people sat
        p.put_soft(wl, 6)
        p.line([(214, 612), (326, 612)], POLISH_HI, 3)
        p.rect(206, 760, 334, 790, POLISH_DK, INK, 2.5, r=6)          # hinge rail
    else:
        p.rect(194, 742, 346, 752, POLISH, INK, 2, r=3)               # top surface, glimpsed
        p.rect(190, 750, 350, 786, POLISH_DK, INK, 4, r=8)            # front edge of the let-down seat
        p.line([(198, 756), (342, 756)], POLISH_HI, 3)
        sh2 = p.layer()
        sh2.rect(196, 788, 344, 830, SHADOW + (255,), None, r=10)
        p.put_soft(sh2, 9, 0.4)
        dust = p.layer()
        drng = rng_for(46)
        dust.ell(270, 910, 92, 7, DUST + (170,), None)
        for _ in range(50):
            dust.ell(drng.uniform(186, 354), drng.uniform(904, 916), drng.uniform(1, 2.4), None, DUST + (220,), None)
        p.put_soft(dust, 1.2)


# --- the room's furniture without puzzles -------------------------------------------------

def wainscot_props(p):
    rng = rng_for(47)
    # a numbered cable run along the dado: brass clips, enamel tags with 1..6 tally strokes
    clips = [418, 508, 598, 688, 778, 868]
    pts = [(392, 614)]
    for i, x in enumerate(clips):
        if i:
            pts.append(((clips[i - 1] + x) / 2, 621))
        pts.append((x, 612))
    pts.append((924, 614))
    curve = []
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        for s in range(6):
            t = s / 6
            curve.append((lerp(a[0], b[0], t), lerp(a[1], b[1], t)))
    curve.append(pts[-1])
    p.line(curve, INK, 9)
    p.line(curve, (74, 64, 52), 5)
    p.rect(378, 602, 404, 630, BRASS_LO, INK, 2.5, r=3)               # junction box
    bolt(p, 391, 616, 3)
    for i, x in enumerate(clips):
        p.rect(x - 5, 604, x + 5, 620, BRASS, INK, 2, r=2)
        p.line([(x, 620), (x, 628)], INK, 1.6)
        p.rect(x - 11, 628, x + 11, 650, ENAMEL, INK, 2, r=2)
        for k in range(i + 1):
            tx = x - 7 + k * 2.8
            p.line([(tx, 633), (tx, 645)], INK, 1.5)
    # headphones on a hook
    p.rect(628, 652, 644, 664, BRASS_LO, INK, 2, r=2)
    p.arc(636, 672, 8, 10, 0, 200, INK, 4)
    p.arc(636, 672, 8, 10, 0, 200, BRASS_HI, 2)
    p.arc(636, 714, 34, 40, 180, 360, INK, 8)
    p.arc(636, 714, 34, 40, 180, 360, TIMBER_HI, 4.5)
    for ex in (602, 670):
        p.line([(ex, 714), (ex, 736)], BRASS_LO, 3)
        p.ell(ex, 754, 21, 21, BRASS, INK, 3)
        p.ell(ex, 754, 15, 15, EBONY, INK, 2)
        p.ell(ex - 4, 749, 4, 3, (96, 92, 86), None)
    cord = bezier((602, 774), (620, 870), (700, 896), 20) + bezier((700, 896), (760, 904), (800, 880), 12)[1:]
    p.line(cord, INK, 5)
    p.line(cord, (66, 58, 50), 2.6)
    p.line(bezier((670, 774), (650, 820), (632, 846), 10), INK, 4)
    # the wax-shaving bin, with curls heaped over the rim and a few dropped
    sh = p.layer()
    sh.ell(494, 912, 70, 8, SHADOW + (255,), None)
    sh.ell(810, 912, 66, 7, SHADOW + (255,), None)
    p.put_soft(sh, 5, 0.45)
    tin = (112, 122, 122)
    p.poly([(444, 826), (544, 826), (536, 910), (452, 910)], tin, INK, 3)
    for x in (468, 494, 520):
        p.line([(x, 832), (x - 1, 904)], mix(tin, INK, 0.25), 1.6)
    p.line([(450, 836), (538, 836)], (150, 160, 158), 2)
    for _ in range(16):
        x, y = rng.uniform(452, 536), rng.uniform(806, 826)
        r = rng.uniform(5, 9)
        a0 = rng.uniform(0, 360)
        p.arc(x, y, r, r * 0.8, a0, a0 + 280, mix(WAX, INK, 0.25), 3.2)
        p.arc(x, y, r, r * 0.8, a0, a0 + 280, WAX, 1.8)
    p.rect(440, 820, 548, 832, (128, 138, 138), INK, 3, r=3)
    for x, y in ((420, 906), (566, 904), (590, 909)):
        p.arc(x, y, 6, 4, 10, 300, WAX, 2.2)
    # two cylinder boxes standing on the floor
    for x0, col in ((748, (150, 112, 72)), (800, (172, 132, 88))):
        p.rect(x0, 842, x0 + 46, 912, col, INK, 3, r=4)
        p.rect(x0 - 3, 836, x0 + 49, 856, mix(col, INK, 0.25), INK, 3, r=4)
        p.line([(x0 + 8, 862), (x0 + 8, 904)], mix(col, (255, 255, 255), 0.25), 2)
        p.rect(x0 + 10, 874, x0 + 36, 890, ENAMEL, INK, 1.6, r=2)


def lamp_hood(p, stage):
    """A hooded green-shaded lamp on a wall bracket, over the spindle."""
    p.ell(968, 290, 11, 11, BRASS_LO, INK, 2.5)
    bolt(p, 968, 290, 3.5)
    arm = bezier((968, 290), (1004, 330), (990, 420), 18)
    p.line(arm, INK, 8)
    p.line(arm, BRASS, 4.5)
    p.line([(x + 1, y - 1) for x, y in arm[2:-2]], BRASS_HI, 1.4)
    lx, ly = LAMP
    hood = [(lx - 40, ly + 12), (lx - 30, ly - 10), (lx - 14, ly - 20), (lx + 14, ly - 20), (lx + 30, ly - 10), (lx + 40, ly + 12)]
    green = (52, 92, 76)
    p.poly(hood, green, INK, 3.2)
    p.line([(lx - 26, ly - 8), (lx - 10, ly - 16), (lx + 10, ly - 16)], (110, 150, 132), 2.6)
    p.rect(lx - 6, ly - 28, lx + 6, ly - 18, BRASS, INK, 2)
    inside = {1: (255, 228, 160), 2: (226, 192, 128), 3: (196, 160, 104), 4: (120, 98, 70)}.get(stage, (150, 150, 140))
    p.oval(lx, ly + 12, 38, 6, 0, inside, INK, 2.2)
    if stage in (1, 2, 3):
        p.ell(lx, ly + 10, 9, 4, (255, 246, 214), None)
    # the indicator jewel on the cabinet upstand
    p.ell(INDICATOR[0], INDICATOR[1], 10, 10, BRASS, INK, 2.5)
    p.ell(INDICATOR[0], INDICATOR[1], 6, 6, (226, 150, 70), INK, 1.4)
    p.ell(INDICATOR[0] - 2, INDICATOR[1] - 2, 2, 2, (255, 230, 190), None)


def cabinet(p):
    sh = p.layer()
    sh.ell(1130, 914, 250, 14, SHADOW + (255,), None)
    sh.rect(890, 450, 924, 905, SHADOW + (255,), None)
    p.put_soft(sh, 9, 0.42)
    p.rect(906, 432, 1354, 446, TIMBER, INK, 3, r=2)                # gallery rail
    p.rect(914, 444, 1346, 600, STORM, INK, 3.5)                   # dark upstand behind the top
    p.line([(920, 452), (1340, 452)], STORM_HI, 2)
    p.rect(924, 618, 1336, 888, CABINET, INK, 4)
    for x0 in (944, 1136):
        p.rect(x0, 638, x0 + 180, 868, CABINET_DK, INK, 3)
        p.rect(x0 + 16, 654, x0 + 164, 852, CABINET, INK, 2.5)
        p.line([(x0 + 20, 658), (x0 + 160, 658)], CABINET_HI, 2)
    gr = p.layer()  # value falls off down the doors, away from the lamp
    for k in range(12):
        gr.rect(924, 700 + k * 16, 1336, 716 + k * 16, SHADOW + (14 + k * 6,), None)
    p.put(gr, 1.0, mask=clip_mask(p.im.size, [(926, 620, 1334, 886)]))
    p.ell(1114, 754, 8, 8, BRASS_HI, INK, 2.5)
    p.ell(1146, 754, 8, 8, BRASS_HI, INK, 2.5)
    p.rect(912, 598, 1348, 622, CABINET_HI, INK, 4)                # top slab
    p.line([(916, 604), (1344, 604)], (222, 182, 132), 2)
    p.rect(918, 886, 1342, 902, CABINET_DK, INK, 3)                # plinth
    p.rect(930, 900, 972, 912, CABINET_DK, INK, 3)
    p.rect(1288, 900, 1330, 912, CABINET_DK, INK, 3)


SPINDLE_PARTS = [  # solids of the bare spindle (used to mask the transcript strip)
    (946, 562, 1219, 584), (956, 582, 1210, 600), (956, 486, 1002, 566),
    (1188, 500, 1214, 566), (998, 516, 1192, 538),
]


def spindle(p):
    p.rect(956, 582, 1210, 600, TIMBER_DK, INK, 3)                 # plinth on the cabinet
    p.rect(946, 562, 1219, 584, BRASS_LO, INK, 3.5, r=3)           # bed
    p.line([(952, 568), (1213, 568)], BRASS_HI, 2)
    p.rect(998, 516, 1192, 538, BRASS, INK, 3, r=9)                # bare mandrel
    p.line([(1004, 522), (1186, 522)], BRASS_HI, 3)
    p.line([(1004, 533), (1186, 533)], BRASS_DK, 2)
    p.rect(956, 486, 1002, 566, BRASS, INK, 3.5, r=4)              # left standard
    p.rect(962, 496, 996, 542, BRASS_HI, INK, 2.5, r=2)            # blank arrow field
    p.rect(966, 500, 992, 538, None, BRASS_LO, 1.5, r=1)
    bolt(p, 979, 554, 4)
    p.rect(1188, 500, 1214, 566, BRASS, INK, 3.5, r=4)             # right standard
    p.ell(1201, 527, 7, 7, BRASS_HI, INK, 2)
    bolt(p, 1201, 554, 3.5)


TRAY = (1232, 522, 1338, 590)
TRAY_BANDS = [(1240, (150, 128, 98)), (1272, (190, 172, 140)), (1304, (224, 210, 182))]  # C, A, B


def tray(p, bands=True):
    x0, y0, x1, y1 = TRAY
    p.rect(1242, 588, 1252, 600, TIMBER_DK, INK, 2)
    p.rect(1318, 588, 1328, 600, TIMBER_DK, INK, 2)
    p.rect(x0, y0, x1, y1, TIMBER, INK, 3.5, r=3)
    p.rect(x0 + 6, y0 + 6, x1 - 6, y1 - 6, SEAGLASS, INK, 2)
    p.line([(x0 + 9, y0 + 10), (x1 - 9, y0 + 10)], mix(SEAGLASS, INK, 0.3), 2)
    if bands:
        for bx, col in TRAY_BANDS:
            p.rect(bx, 532, bx + 26, 578, col, INK, 2.5, r=7)
            p.line([(bx + 6, 538), (bx + 6, 572)], mix(col, (255, 255, 255), 0.35), 2.5)
            p.line([(bx + 2, 540), (bx + 24, 540)], mix(col, BRASS_LO, 0.5), 1.5)
            p.line([(bx + 2, 570), (bx + 24, 570)], mix(col, BRASS_LO, 0.5), 1.5)
    p.rect(x0, 566, x1, y1, TIMBER, INK, 3, r=2)                   # front lip
    p.line([(x0 + 4, 571), (x1 - 4, 571)], TIMBER_HI, 1.6)


PAPER_DK_LINE = (186, 175, 150)


def printer(p):
    """A cast-iron receiving teleprinter on a wall shelf: paper roll on a brass spindle above,
    an exposed typewheel and ribbon spools at the platen, an enamel maker's plate, no glass."""
    sh = p.layer()
    sh.rect(1010, 300, 1262, 430, SHADOW + (255,), None, r=10)
    p.put_soft(sh, 9, 0.35)
    # shelf and brackets
    for bx in (1040, 1250):
        p.poly([(bx - 8, 418), (bx + 8, 418), (bx + 8, 452), (bx - 8, 426)], TIMBER_DK, INK, 2.5)
    p.rect(1000, 404, 1282, 420, TIMBER, INK, 3, r=2)
    p.line([(1004, 408), (1278, 408)], TIMBER_HI, 1.6)
    # roll spindle brackets and the roll
    for bx in (1044, 1236):
        p.rect(bx - 6, 236, bx + 6, 300, BRASS_LO, INK, 2.5, r=3)
    p.line([(1036, 244), (1244, 244)], INK, 7)
    p.line([(1036, 244), (1244, 244)], BRASS_HI, 3.5)
    p.rect(1060, 222, 1220, 266, PAPER, INK, 3, r=8)
    p.line([(1066, 230), (1214, 230)], PAPER_HI, 3)
    p.line([(1066, 258), (1214, 258)], PAPER_DK_LINE, 2)
    for bx in (1044, 1236):
        p.ell(bx, 244, 8, 8, BRASS, INK, 2.2)
    # paper web from the roll down behind the works
    p.rect(1092, 264, 1188, 330, PAPER_HI, INK, 2)
    # cast-iron frame: two cheeks joined by an arched bridge
    for x0, x1 in ((1022, 1066), (1214, 1258)):
        p.poly([(x0, 404), (x0, 316), (x0 + 6, 296), (x1 - 6, 296), (x1, 316), (x1, 404)], IRON, INK, 3.2)
        p.line([(x0 + 8, 310), (x0 + 8, 396)], (66, 76, 86), 2)
    p.poly([(1060, 300), (1220, 300), (1220, 316), (1186, 316), (1176, 306), (1104, 306), (1094, 316), (1060, 316)],
           IRON, INK, 2.8)
    # selector magnets on the bridge
    for cx in (1118, 1162):
        p.rect(cx - 12, 278, cx + 12, 302, BRASS_LO, INK, 2.2, r=3)
        for yy in (284, 290, 296):
            p.line([(cx - 10, yy), (cx + 10, yy)], BRASS_DK, 1.2)
    # platen: black rubber roller with brass knobs
    p.rect(1062, 330, 1218, 354, EBONY, INK, 3, r=11)
    p.line([(1068, 336), (1212, 336)], (88, 86, 82), 2)
    for kx in (1052, 1228):
        p.ell(kx, 342, 13, 13, BRASS, INK, 2.6)
        p.ell(kx - 3, 338, 4, 4, BRASS_HI, None)
    # paper coming over the platen, out of the front
    p.rect(1100, 352, 1176, 400, PAPER, INK, 2)
    # ribbon spools and ribbon across the type line
    for cx in (1082, 1198):
        p.ell(cx, 370, 13, 13, BRASS_LO, INK, 2.5)
        p.ell(cx, 370, 8, 8, (40, 36, 34), INK, 1.4)
        p.ell(cx, 370, 2.5, 2.5, BRASS_HI, None)
    p.line([(1082, 358), (1198, 358)], (32, 30, 30), 4)
    # the exposed typewheel, slugs round its rim
    cx, cy = 1138, 374
    p.ell(cx, cy, 20, 20, BRASS, INK, 2.8)
    for k in range(16):
        a = 2 * math.pi * k / 16
        x, y = cx + math.cos(a) * 20, cy + math.sin(a) * 20
        p.ell(x, y, 3, 3, BRASS_HI, INK, 1.2)
    p.ell(cx, cy, 9, 9, BRASS_LO, INK, 2)
    p.ell(cx, cy, 3, 3, BRASS_HI, None)
    # base and the enamel maker's plate
    p.rect(1016, 392, 1264, 406, IRON, INK, 3, r=3)
    p.rect(1208, 380, 1250, 400, ENAMEL, INK, 2, r=3)
    p.line([(1213, 386), (1245, 386)], mix(ENAMEL, INK, 0.35), 1.2)
    p.line([(1213, 393), (1238, 393)], mix(ENAMEL, INK, 0.35), 1.2)
    for bx in (1030, 1250):
        bolt(p, bx, 399, 3)


def cable(p):
    pts = [(1238, 420), (1243, 450), (1246, 480), (1247, 530)]  # drops behind the tray
    p.line(pts, INK, 9)
    p.line(pts, (70, 62, 54), 5)
    for y in (452, 496):
        p.rect(1236, y - 4, 1256, y + 4, BRASS_LO, INK, 1.6, r=2)


def doorway(p, side):
    """A way through: moulded jamb, the door leaf standing open, a dim glimpse of the next wall."""
    if side == "right":
        jx0, jx1, ox0, ox1 = 1334, 1362, 1362, W + 6
        leaf = (1362, 1388)
    else:
        jx0, jx1, ox0, ox1 = 86, 114, -6, 86
        leaf = (60, 86)
    p.rect(ox0, 250, ox1, 914, (24, 34, 42), INK, 3)
    far = p.layer()
    for k in range(10):
        far.rect(ox0, 250 + k * 66, ox1, 316 + k * 66, (60, 78, 88, 6 + k * 3), None)
    p.put(far)
    if side == "right":   # the channel board's brass rail, a panel and one dim lamp
        p.rect(1394, 600, W + 6, 610, BRASS_LO, INK, 2)
        p.rect(1398, 610, W + 6, 880, (58, 52, 44), INK, 2.5)
        p.rect(1410, 640, W + 6, 760, (38, 54, 66), INK, 2)
        p.ell(1434, 664, 7, 7, (140, 104, 56), INK, 1.4)
        p.ell(1430, 300, 60, 60, None, (60, 64, 60), 3)                 # the speaker's baffle, far off
    else:                 # the funnel wall's plaster and a pipe, glimpsed
        p.rect(-6, 300, 58, 520, (96, 98, 92), INK, 2)
        p.line(bezier((-6, 380), (30, 360), (58, 420)), (84, 70, 44), 6)
        p.rect(-6, 572, 60, 590, (60, 54, 46), INK, 2)
    p.rect(ox0, 880, ox1, 914, (40, 46, 50), INK, 2)
    # the open leaf, seen nearly edge-on against the hinge jamb
    p.rect(leaf[0], 256, leaf[1], 908, TIMBER, INK, 3)
    p.line([(leaf[0] + 5, 262), (leaf[0] + 5, 902)], TIMBER_HI, 1.8)
    kx = leaf[1] - 4 if side == "right" else leaf[0] + 4
    p.ell(kx, 600, 6, 6, BRASS_HI, INK, 1.8)
    # architrave
    p.rect(jx0, 226, jx1, 912, TIMBER_DK, INK, 3)
    p.line([(jx0 + 6, 232), (jx0 + 6, 906)], TIMBER_HI, 1.6)
    hx0, hx1 = (jx0, W + 6) if side == "right" else (-6, jx1)
    p.rect(hx0, 226, hx1, 252, TIMBER_DK, INK, 3)
    p.line([(hx0 + 4, 232), (hx1 - 4, 232)], TIMBER_HI, 1.6)


def paint_view_a(rng, turned, stage, sever=False):
    p = Pen(W, H, rng, CORK)
    room_shell(p, rng)
    if stage >= 2:
        damp_bloom(p, stage)
    p.rng = rng_for(20)
    plaster_field(p, rng_for(40), stage)
    if stage >= 3:
        tide_line(p)
    p.rng = rng_for(21)
    funnels(p, rng_for(1), turned)
    p.rng = rng_for(9)
    seat(p, down=stage >= 3 and not sever)
    p.rng = rng_for(22)
    wainscot_props(p)
    p.rng = rng_for(23)
    cabinet(p)
    spindle(p)
    cable(p)
    tray(p)
    printer(p)
    lamp_hood(p, 0 if sever else stage)
    p.rng = rng_for(24)
    doorway(p, "right")
    return p


# ----------------------------------------------------------------------------- view B parts

def speaker(p, rng):
    cx, cy, r = 725, 215, 100
    p.ell(cx, cy, 124, 124, STORM, INK, 3.5)                      # dark mounting baffle
    p.ell(cx, cy, 118, 118, None, STORM_HI, 2)
    for k in range(6):
        a = math.radians(30 + k * 60)
        bolt(p, cx + math.cos(a) * 113, cy + math.sin(a) * 113, 3.5)
    p.rect(684, 98, 766, 114, BRASS_LO, INK, 3, r=3)              # ceiling flange
    bolt(p, 694, 106, 3)
    bolt(p, 756, 106, 3)
    p.rect(705, 108, 745, 150, BRASS, INK, 3)                     # pipe down from the ceiling
    p.line([(712, 112), (712, 148)], BRASS_HI, 3)
    p.ell(cx, cy, r + 4, r + 4, None, INK, 4)
    p.ell(cx, cy, r, r, BRASS, INK, 4)
    for i in range(14):
        t = i / 13
        rr = lerp(r - 12, 18, t)
        p.ell(cx, cy, rr, rr, mix(BRASS_LO, THROAT, t ** 1.1), None)
    p.ell(cx, cy, r - 12, r - 12, None, INK, 2.5)
    p.ell(cx, cy, 52, 52, None, mix(INK, BRASS_LO, 0.4), 1.6)
    p.ell(cx, cy, 18, 18, THROAT, INK, 3)
    p.arc(cx, cy, r - 6, r - 6, 195, 285, BRASS_HI, 5)
    p.arc(cx, cy, r - 6, r - 6, 20, 75, BRASS_DK, 3)


def motor(p, down):
    x0, y0, x1, y1 = 220, 400, 390, 630
    bezel(p, x0 + 6, y0 + 6, x1 - 6, y1 - 6, r=6)
    p.rect(x0 + 6, y0 + 6, x1 - 6, y1 - 6, PANEL, INK, 3.5, r=6)
    for bx, by in ((236, 444), (374, 444), (236, 612), (374, 612)):
        bolt(p, bx, by, 4)
    p.rect(246, 414, 364, 434, ENAMEL, INK, 2.5, r=3)              # blank label plate
    p.rect(294, 444, 316, 618, THROAT, INK, 2.5, r=6)              # lever slot
    px, py = 305, 530
    hy = 448 if not down else 612
    p.rect(px - 9, min(py, hy), px + 9, max(py, hy), BRASS, INK, 3)
    p.line([(px - 4, min(py, hy) + 4), (px - 4, max(py, hy) - 4)], BRASS_HI, 2.5)
    p.rect(px - 30, hy - 15, px + 30, hy + 15, EBONY, INK, 3, r=12)  # handle
    p.line([(px - 22, hy - 8), (px + 18, hy - 8)], (80, 76, 70), 2)
    p.rect(px - 32, hy + (16 if not down else -22), px + 32, hy + (22 if not down else -16), BRASS_HI, INK, 2)
    p.ell(px, py, 17, 17, BRASS_HI, INK, 3)
    p.ell(px, py, 6, 6, BRASS_DK, INK, 1.5)


def lamp_unlit(p, cx, cy, r=26):
    p.ell(cx, cy, r + 5, r + 5, BRASS, INK, 3)
    p.ell(cx, cy, r, r, (52, 76, 72), INK, 2.5)
    p.ell(cx, cy, r * 0.62, r * 0.62, (44, 64, 62), None)
    p.arc(cx, cy, r - 6, r - 6, 200, 260, (130, 160, 150), 3)


def channel(p, c):
    bezel(p, c - 72, 384, c + 72, 650, r=6, m=5)
    p.rect(c - 72, 384, c + 72, 650, PANEL, INK, 3.5, r=6)
    p.rect(c - 56, 394, c + 56, 420, ENAMEL, INK, 2.5, r=3)        # blank cut-label plate
    lamp_unlit(p, c, 440)
    p.rect(c - 66, 466, c + 66, 554, BRASS, INK, 3, r=6)           # gauge bezel
    p.rect(c - 60, 470, c + 60, 550, ENAMEL, INK, 2)               # blank gauge face
    p.arc(c, 548, 50, 50, 205, 335, mix(ENAMEL, INK, 0.25), 2)     # plain arc, no ticks
    p.line([(c - 56, 476), (c - 20, 476)], (244, 240, 230), 2)
    p.ell(c, 548, 6, 6, THROAT, INK, 1.5)                          # needle pivot socket
    p.rect(c - 36, 566, c + 36, 636, BRASS, INK, 3, r=6)           # key escutcheon
    p.rect(c - 8, 576, c + 8, 626, THROAT, INK, 2, r=4)            # empty key slot
    bolt(p, c - 26, 576, 3)
    bolt(p, c + 26, 626, 3)


def witness_key(p, ox, oy, sc, pressed, frame=False):
    """Large brass push-key. (ox, oy) is the top-left of its box; sc scales from the 180x170 base."""
    def X(v):
        return ox + v * sc

    def Y(v):
        return oy + v * sc
    if frame:
        bezel(p, X(4), Y(4), X(176), Y(166), r=10, m=5)
    p.rect(X(4), Y(4), X(176), Y(166), PANEL, INK, 3.5, r=10 * sc)
    for bx, by in ((16, 16), (164, 16), (16, 154), (164, 154)):
        bolt(p, X(bx), Y(by), 4)
    p.rect(X(30), Y(136), X(150), Y(160), BRASS_HI, INK, 2.5, r=3)  # blank engraving plate
    p.rect(X(36), Y(141), X(144), Y(155), None, BRASS_LO, 1.2, r=2)
    cx, cy = X(90), Y(68)
    p.ell(cx, cy, 60 * sc, 60 * sc, BRASS_LO, INK, 3.5)             # collar
    p.ell(cx, cy, 52 * sc, 52 * sc, BRASS_DK, None)
    dy = 18 if pressed else 0
    if pressed:
        p.ell(cx, cy + dy * 0.5, 54 * sc, 54 * sc, THROAT, None)    # the shadow ring
    else:
        p.ell(cx, cy + 8 * sc, 48 * sc, 48 * sc, BRASS_DK, None)    # cap's skirt
    rcap = (44 if pressed else 48) * sc
    p.ell(cx, cy + dy, rcap, rcap, BRASS if pressed else BRASS_HI, INK, 4)
    p.ell(cx - 10 * sc, cy + dy - 12 * sc, rcap * 0.55, rcap * 0.42, mix(BRASS_HI, (255, 240, 200), 0.3 if not pressed else 0.0), None)
    p.ell(cx, cy + dy, rcap * 0.78, rcap * 0.78, None, mix(INK, BRASS, 0.4), 1.6)


def hub(p, cx, cy):
    p.ell(cx, cy, 46, 46, PANEL_DK, INK, 3)
    p.ell(cx, cy, 24, 24, BRASS, INK, 3)
    for k in range(3):
        a = math.radians(90 + k * 120)
        p.ell(cx + math.cos(a) * 13, cy - math.sin(a) * 13, 5, 5, PANEL_DK, INK, 1.2)
    p.ell(cx, cy, 6, 6, BRASS_HI, INK, 2)


def mixer(p):
    bezel(p, 420, 670, 1040, 870, r=10, m=5)
    p.rect(420, 670, 1040, 870, IRON, INK, 4, r=10)
    p.rect(430, 680, 1030, 860, None, BRASS_LO, 2.5, r=8)
    p.rect(462, 684, 998, 776, BRASS, INK, 3, r=6)                 # window bezel
    chart_paper(p, 470, 690, 990, 770, lanes=((692, 736), (738, 768)))
    hub(p, 560, 820)
    hub(p, 900, 820)
    for bx in (660, 730, 800):  # fixed head block between the hubs
        pass
    p.rect(690, 798, 770, 842, PANEL, INK, 3, r=4)
    p.rect(708, 808, 752, 816, THROAT, None)


def chart_paper(p, x0, y0, x1, y1, lanes=()):
    """Oscillograph chart: a cream paper band behind glass, faint rules, a lane divider."""
    p.rect(x0, y0, x1, y1, PAPER_HI, INK, 2)
    grid = p.layer()
    x = x0 + 10
    while x < x1:
        grid.line([(x, y0 + 2), (x, y1 - 2)], (150, 178, 166, 255), 1)
        x += 20
    for a, b in lanes:
        for yy in (a + (b - a) * 0.25, a + (b - a) * 0.5, a + (b - a) * 0.75):
            grid.line([(x0 + 2, yy), (x1 - 2, yy)], (150, 178, 166, 255), 1)
    p.put(grid, 0.45)
    for a, b in lanes[1:]:
        p.line([(x0 + 2, a - 1), (x1 - 2, a - 1)], mix(INK, PAPER, 0.5), 1.6)
    sheen = p.layer()
    w = x1 - x0
    sheen.poly([(x0 + w * 0.06, y0 + 1), (x0 + w * 0.13, y0 + 1), (x0 + w * 0.08, y1 - 1), (x0 + w * 0.01, y1 - 1)],
               (255, 255, 255, 70), None)
    p.put(sheen)


def board(p):
    sh = p.layer()
    sh.rect(150, 900, 1300, 940, SHADOW + (255,), None, r=20)
    sh.rect(160, 360, 180, 900, SHADOW + (255,), None)
    p.put_soft(sh, 10, 0.5)
    p.rect(198, 878, 242, 912, TIMBER_DK, INK, 3)
    p.rect(1208, 878, 1252, 912, TIMBER_DK, INK, 3)
    p.rect(180, 340, 1270, 880, TIMBER, INK, 4.5)
    for y in range(392, 880, 58):  # planking
        p.line([(186, y), (1264, y)], TIMBER_DK, 2)
    gr = p.layer()  # the front falls off in value toward the floor
    for k in range(14):
        gr.rect(182, 560 + k * 22, 1268, 582 + k * 22, SHADOW + (8 + k * 5,), None)
    p.put(gr)
    p.rect(180, 842, 1270, 880, TIMBER_DK, INK, 4)                 # darker plinth
    p.line([(186, 848), (1264, 848)], TIMBER, 1.6)
    p.rect(176, 334, 1274, 352, BRASS, INK, 3.5, r=3)              # brass top rail
    p.line([(182, 339), (1268, 339)], BRASS_HI, 2)
    p.rect(190, 360, 1260, 870, None, BRASS_LO, 3)                 # brass trim
    for bx, by in ((200, 370), (1250, 370), (200, 860), (1250, 860)):
        bolt(p, bx, by, 4)


def paint_view_b(rng, stage=1):
    p = Pen(W, H, rng, CORK)
    room_shell(p, rng, plaster_ceiling=True)
    if stage >= 2:
        damp_bloom(p, stage)
    if stage >= 3:
        tide_line(p, W + 4)
    p.rng = rng_for(25)
    doorway(p, "left")
    sh = p.layer()  # the speaker baffle's shadow on the cork
    sh.ell(712, 228, 124, 124, SHADOW + (255,), None)
    p.put_soft(sh, 8, 0.35)
    speaker(p, rng)
    if stage >= 4:  # glossy, swollen cornice
        gl = p.layer()
        grng = rng_for(48)
        for _ in range(30):
            x = grng.uniform(0, W)
            gl.line([(x, 92), (x + grng.uniform(-4, 4), 92 + grng.uniform(8, 22))], (255, 255, 250, 255), 3)
        p.put_soft(gl, 2, 0.4)
    board(p)
    motor(p, down=False)
    for c in CHANNELS:
        channel(p, c)
    witness_key(p, 960, 430, 1.0, pressed=False, frame=True)
    mixer(p)
    return p


# ----------------------------------------------------------------------------- overlays: view A

def clip_mask(size, keep_rects=(), holes=()):
    m = Image.new("L", size, 0 if keep_rects else 255)
    d = ImageDraw.Draw(m)
    for x0, y0, x1, y1 in keep_rects:
        d.rectangle((x0 * SS, y0 * SS, x1 * SS, y1 * SS), fill=255)
    for cx, cy, r in holes:
        d.ellipse(((cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS), fill=0)
    return m


BEAD_TINT = (176, 206, 192)


def bead(p, x, y, rx, ry):
    p.ell(x + 0.8, y + 1.2, rx + 1, ry + 1, (40, 64, 58, 110), None)          # its little shadow
    p.ell(x, y, rx, ry, BEAD_TINT + (215,), mix(INK, SEAGLASS, 0.4) + (200,), 1.2)
    p.ell(x - rx * 0.35, y - ry * 0.4, rx * 0.35, ry * 0.28, (240, 250, 246, 230), None)


def condensation(p, rng, g):
    """Two or three elongated beads on the bell and one run sliding down from the lip."""
    N, u, v = g["N"], g["u"], g["v"]
    fog = p.layer()
    if not g["back"]:
        mouth_oval(fog, g, 0.84, fill=BEAD_TINT + (70,), ink=None)
    p.put_soft(fog, 2)
    for _ in range(rng.choice((2, 3))):
        s = rng.uniform(0.45, 0.9)
        r = horn_radius(s) * rng.uniform(-0.55, 0.55)
        x = N[0] + u[0] * HORN_L * s + v[0] * r
        y = N[1] + u[1] * HORN_L * s + v[1] * r
        bead(p, x, y, rng.uniform(2.2, 3.0), rng.uniform(4.6, 6.4))
    pts = mouth_points(g, 1.0)
    lx, ly = max(pts, key=lambda q: q[1])
    lx += rng.uniform(-8, 8)
    run = [(lx, ly)]
    y = ly
    length = rng.uniform(34, 56)
    while y < ly + length:
        y += 5
        run.append((lx + 1.6 * math.sin(y * 0.3), y))
    p.line(run, BEAD_TINT + (205,), 2.6)
    p.line([(x + 0.8, yy) for x, yy in run], (60, 90, 82, 120), 1)
    bead(p, run[-1][0], run[-1][1] + 3, 3.2, 5.4)


def paint_a_condensation(rng, turned=False):
    p = Pen(W, H, rng)
    for n in HORNS:
        condensation(p, rng, horn_geo(n, turned))
    return p


SEAT_FACE = (270, 696)


def paint_a_seat_rings(rng):
    """Wax dust on the folded-up seat in broken, uneven rings with a soft halo, ~70%."""
    p = Pen(W, H, rng)
    rings = p.layer()
    cx, cy = SEAT_FACE
    for k, r in enumerate((10, 22, 34, 46, 58)):
        a = rng.uniform(0, 360)
        end = a + 360 - rng.uniform(0, 40)
        while a < end:
            span = min(rng.uniform(40, 110), end - a)
            rings.arc(cx + rng.uniform(-1, 1), cy + rng.uniform(-1, 1), r + rng.uniform(-1.5, 1.5),
                      (r + rng.uniform(-1.5, 1.5)) * 1.04, a, a + span, DUST + (255,), rng.uniform(2.2, 4.0))
            a += span + rng.uniform(10, 34)
    halo = p.layer()
    halo.im = rings.im.copy()
    face = Image.new("L", p.im.size, 0)
    ImageDraw.Draw(face).rounded_rectangle((208 * SS, 616 * SS, 332 * SS, 774 * SS), radius=14 * SS, fill=255)
    p.put_soft(halo, 5, 0.55, mask=face)
    p.put(rings, 0.72, mask=face)
    # a faint drift of wax dust on the floor between the standards
    lay = p.layer()
    lay.poly([(196, 912), (218, 902), (322, 902), (344, 912)], DUST + (150,), None)
    for _ in range(40):
        lay.ell(rng.uniform(204, 336), rng.uniform(902, 914), rng.uniform(1, 2.4), None, DUST + (200,), None)
    p.put(lay, 0.8)
    return p


def swell(p, cx, cy, rx, ry):
    """A smooth, pale, slightly glossy plaster swelling: light top-left, shade bottom-right.
    Plaster-toned and soft-edged, so it reads as the wall itself pushing out."""
    base = p.layer()
    base.ell(cx, cy, rx, ry, (222, 218, 202, 255), None)
    p.put_soft(base, rx * 0.05)
    sh = p.layer()
    sh.ell(cx + rx * 0.28, cy + ry * 0.3, rx * 0.8, ry * 0.76, (112, 112, 98, 255), None)
    sh.ell(cx - rx * 0.1, cy - ry * 0.12, rx * 0.8, ry * 0.78, (0, 0, 0, 0), None)
    p.put_soft(sh, rx * 0.16, 0.62)
    rim = p.layer()  # where the swell leaves the wall, a soft contact shadow on its lower right
    rim.arc(cx + 2, cy + 2, rx * 0.98, ry * 0.98, -10, 170, (80, 84, 72, 255), 5)
    p.put_soft(rim, 2.2, 0.7)
    hi = p.layer()
    hi.ell(cx - rx * 0.28, cy - ry * 0.3, rx * 0.4, ry * 0.28, (250, 250, 244, 255), None)
    p.put_soft(hi, rx * 0.1, 0.8)
    gl = p.layer()
    gl.ell(cx - rx * 0.36, cy - ry * 0.4, rx * 0.11, ry * 0.06, (255, 255, 255, 255), None)
    p.put_soft(gl, 1.4, 0.9)


def paint_a_bulge(rng):
    """Band 7: the plaster breathing out round every collar; each pipe sinks into its swell."""
    p = Pen(W, H, rng)
    pm = plaster_mask(plaster_outline(rng_for(40)), p.im.size)
    sw = p.layer()
    for n in HORNS:
        c = HORNS[n][0]
        swell(sw, c[0], c[1], 62, 52)
    p.put(sw, mask=pm)
    c = HORNS[3][0]  # one hairline, no more
    p.line([(c[0] + 30, c[1] + 26), (c[0] + 40, c[1] + 33), (c[0] + 46, c[1] + 44)], mix(INK, PLASTER, 0.55), 1.2)
    return p


MOUNT_WAX = (190, 166, 124)
MOUNT_BANDS = [(1006, 1058), (1068, 1120), (1130, 1182)]


def paint_a_mounted(rng):
    p = Pen(W, H, rng)
    for x0, x1 in MOUNT_BANDS:
        p.rect(x0, 496, x1, 558, MOUNT_WAX, INK, 3, r=6)
        p.rect(x0 + 2, 498, x1 - 2, 506, mix(MOUNT_WAX, INK, 0.25), None)
        p.rect(x0 + 2, 544, x1 - 2, 556, mix(MOUNT_WAX, INK, 0.3), None)
        p.line([(x0 + 4, 512), (x1 - 4, 512)], (236, 222, 190), 3.5)
        p.rect(x0, 496, x1, 558, None, INK, 3, r=6)
        p.rect(x0 - 2, 494, x0 + 5, 560, BRASS, INK, 2, r=2)
        p.rect(x1 - 5, 494, x1 + 2, 560, BRASS, INK, 2, r=2)
    # needle arm resting up at the right end
    p.ell(1201, 494, 9, 9, BRASS_HI, INK, 2.5)
    p.poly(capsule((1201, 494), (1146, 484), 6, 4), BRASS, INK, 2.5)
    p.rect(1132, 478, 1152, 492, EBONY, INK, 2, r=3)
    p.line([(1140, 492), (1140, 500)], INK, 2)
    # emptied felt tray
    x0, y0, x1, y1 = TRAY
    p.rect(x0 + 6, y0 + 6, x1 - 6, 566, SEAGLASS, INK, 2)
    p.line([(x0 + 9, y0 + 10), (x1 - 9, y0 + 10)], mix(SEAGLASS, INK, 0.3), 2)
    for bx, _ in TRAY_BANDS:  # pressed felt where each band stood
        p.rect(bx + 2, 556, bx + 24, 566, mix(SEAGLASS, INK, 0.22), None)
    return p


def type_rows(p, rng, x0, x1, y0, y1, dy=11):
    y = y0
    while y < y1:
        x = x0 + 10
        while x < x1 - 12:
            wlen = min(rng.uniform(8, 22), x1 - 10 - x)
            p.line([(x, y), (x + wlen, y)], (120, 120, 116), 3)
            x += wlen + rng.uniform(4, 7)
        y += dy


def paint_a_transcript(rng):
    p = Pen(W, H, rng)
    x0, x1 = 1100, 1176
    pts_l = [(x0, 398), (x0 + 1, 470), (x0 - 2, 530), (x0 + 6, 552)]
    pts_r = [(x1, 398), (x1 + 2, 470), (x1 + 6, 528), (x1 + 2, 548)]
    poly = pts_l + list(reversed(pts_r))
    p.poly(poly, PAPER, INK, 2.5)
    p.poly([(x0 + 6, 552), (x1 + 2, 548), (x1 - 4, 560), (x0 + 12, 560)], PAPER_DK_LINE, INK, 2)  # curl
    type_rows(p, rng, x0, x1, 424, 540)
    # the strip hangs on the wall behind the spindle: mask out the mechanism and bands
    m = Image.new("L", p.im.size, 255)
    md = ImageDraw.Draw(m)
    for bx0, by0, bx1, by1 in SPINDLE_PARTS:
        md.rectangle((bx0 * SS, by0 * SS, bx1 * SS, by1 * SS), fill=0)
    for bx0, bx1 in MOUNT_BANDS:
        md.rectangle(((bx0 - 3) * SS, 492 * SS, (bx1 + 3) * SS, 562 * SS), fill=0)
    p.im.putalpha(ImageChops.multiply(p.im.getchannel("A"), m))
    return p


def paint_a_printout_long(rng):
    """Band 7: far more transcript than the recording ever held, over the cabinet edge and
    pooled in folds on the floor."""
    p = Pen(W, H, rng)
    sh = p.layer()
    sh.ell(1150, 960, 190, 30, SHADOW + (255,), None)
    p.put_soft(sh, 8, 0.4)
    # over the top slab and straight down the doors
    strip = [(1104, 598), (1180, 598), (1184, 624), (1188, 760), (1194, 900), (1112, 904), (1108, 760), (1102, 624)]
    p.poly(strip, PAPER, INK, 2.5)
    p.line([(1104, 622), (1184, 622)], PAPER_DK_LINE, 2)
    type_rows(p, rng, 1104, 1188, 636, 896)
    # folds on the floor
    folds = [(1116, 904, 1300, 930, 1), (1030, 926, 1250, 952, -1), (1080, 948, 1320, 976, 1), (996, 972, 1230, 1000, -1)]
    for k, (x0, y0, x1, y1, sk) in enumerate(folds):  # fanfold pleats, each skewed the other way
        s = 10 * sk
        p.poly([(x0 + s, y0), (x1 + s, y0), (x1 - s, y1), (x0 - s, y1)], PAPER if k % 2 == 0 else PAPER_HI, INK, 2.5)
        p.line([(x0 + s + 6, y0 + 4), (x1 + s - 6, y0 + 4)], PAPER_DK_LINE, 1.6)
        type_rows(p, rng, x0 + 8, x1 - 8, y0 + 11, y1 - 5, 8)
    return p


def paint_a_tag5(rng):
    p = Pen(96, 48, rng)
    p.line([(6, 24), (14, 22), (22, 24)], INK, 2)
    p.ell(6, 24, 3, 3, BRASS_HI, INK, 1.2)
    p.poly([(18, 14), (26, 8), (90, 8), (90, 40), (26, 40), (18, 34)], PAPER_HI, INK, 2.5)
    p.ell(26, 24, 3.5, 3.5, (0, 0, 0, 0), INK, 1.5)
    p.line([(32, 12), (86, 12)], (244, 240, 230), 1.5)
    return p


# ----------------------------------------------------------------------------- light maps
#
# Light is painted as two low-resolution maps per stage that the view lays over the plate and
# every overlay: `*_mul_*` (multiply: vignette, falloff away from the lamp, the stage's cold) and
# `*_add_*` (additive: the lamp's warm pool and the raking light on the plaster). Smooth fields,
# so they are stored at quarter size and stretched with linear filtering.

LW, LH = W // 4, H // 4


def _gauss(x, y, cx, cy, sx, sy):
    return math.exp(-(((x - cx) / sx) ** 2 + ((y - cy) / sy) ** 2) / 2)


STAGE_TINT = {1: (1.0, 1.0, 1.0), 2: (0.93, 0.945, 0.955), 3: (0.84, 0.895, 0.885), 4: (0.77, 0.835, 0.835),
              0: (0.9, 0.925, 0.96)}


def light_maps(view, stage):
    """(mul, add) RGB images at quarter size. stage 0 is the sever ending's grey daylight."""
    tint = STAGE_TINT[stage]
    mul = Image.new("RGB", (LW, LH))
    add = Image.new("RGB", (LW, LH))
    mp, ap = [], []
    lamp = {1: 1.0, 2: 0.5, 3: 0.3, 4: 0.0, 0: 0.0}[stage]
    for j in range(LH):
        for i in range(LW):
            x, y = (i + 0.5) * 4, (j + 0.5) * 4
            dx, dy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
            d = math.sqrt(dx * dx * 0.9 + dy * dy)
            vig = 1.0 - 0.17 * max(0.0, min(1.0, (d - 0.42) / 0.82)) ** 1.6
            f = vig
            ar = ag = ab = 0.0
            if view == "a":
                if stage != 0:
                    dl = math.hypot(x - LAMP[0], (y - 560) * 1.3) / 1100.0
                    f *= 1.0 - (0.16 if stage >= 2 else 0.12) * min(1.0, dl)
                pool = _gauss(x, y, 1060, 590, 300, 150) * 0.85 + _gauss(x, y, LAMP[0], 505, 80, 70) * 0.7
                rake = _gauss(x, y, 860, 300, 260, 220) * 0.35
                k = lamp * pool + lamp * rake
                ar, ag, ab = 78 * k, 52 * k, 22 * k
                if stage == 4:  # the lamp has gone; the indicator jewel keeps a small pool
                    kk = _gauss(x, y, INDICATOR[0] + 20, INDICATOR[1] + 40, 90, 60) * 0.9
                    ar, ag, ab = ar + 80 * kk, ag + 44 * kk, ab + 14 * kk
            else:
                if stage in (1, 2):  # the speaker's brass catches the room's own lamp
                    k = _gauss(x, y, 725, 300, 360, 220) * (0.4 if stage == 1 else 0.22)
                    ar, ag, ab = 40 * k, 28 * k, 12 * k
            if stage == 0:  # flat grey daylight lifts everything a little
                ar, ag, ab = ar + 10, ag + 12, ab + 15
            mp.append(tuple(int(max(0, min(255, round(255 * f * t)))) for t in tint))
            ap.append((int(min(255, ar)), int(min(255, ag)), int(min(255, ab))))
    mul.putdata(mp)
    add.putdata(ap)
    return mul, add


def _light(view, stage, which):
    def fn(_rng):
        mul, add = light_maps(view, stage)
        return mul if which == "mul" else add
    return fn


# ----------------------------------------------------------------------------- overlays: view B

def paint_b_motor_off(rng):
    p = Pen(W, H, rng)
    lay = p.layer()
    motor(lay, down=True)
    p.put(lay, mask=clip_mask(p.im.size, [(220, 400, 390, 630)]))
    return p


def paint_lamp_lit(rng, size, r):
    p = Pen(size, size, rng)
    c = size / 2
    lay = p.layer()
    lay.ell(c, c, r + 10 + (c - r - 10) * 0.45, r + 10 + (c - r - 10) * 0.45, (240, 190, 110, 255), None)
    p.put_soft(lay, max(4.0, (c - r) / 3.2), 0.6)
    p.ell(c, c, r + 5, r + 5, BRASS_HI, INK, 3)
    p.ell(c, c, r, r, AMBER, INK, 2.5)
    p.ell(c, c, r * 0.68, r * 0.68, (230, 196, 128), None)
    # filament: a bright zigzag between two posts, a shape the unlit glass never shows
    s = r / 26.0
    p.line([(c - 13 * s, c + 2 * s), (c - 13 * s, c + 16 * s)], INK, 2)   # support posts
    p.line([(c + 13 * s, c + 2 * s), (c + 13 * s, c + 16 * s)], INK, 2)
    lay = p.layer()
    lay.ell(c, c + 1 * s, 15 * s, 8 * s, (255, 250, 226, 150), None)       # hot core glow
    p.put(lay)
    for i in range(5):                                                     # coiled filament
        x = c - 10 * s + i * 5 * s
        p.ell(x, c + 1 * s, 3.4 * s, 5 * s, None, (255, 250, 230), 2.2 * s)
    p.line([(c - 13 * s, c + 2 * s), (c + 13 * s, c + 2 * s)], (255, 246, 214), 1.4)
    p.arc(c, c, r - 5, r - 5, 200, 260, (255, 236, 196), 3)
    return p


def paint_b_needle(rng):
    p = Pen(10, 76, rng)
    p.poly([(3.2, 70), (6.8, 70), (5.4, 2), (4.6, 2)], (16, 16, 18), INK, 0.8)
    p.ell(5, 72, 3.8, 3.8, BRASS_HI, INK, 1.2)
    return p


def paint_key(rng, up):
    p = Pen(110, 90, rng)
    p.rect(19, 11, 91, 81, BRASS, INK, 2.5, r=6)
    p.rect(47, 21, 63, 71, THROAT, INK, 1.5, r=4)
    if up:
        px, py, ky = 55, 52, 12
        p.rect(6, 66, 104, 87, ENAMEL, INK, 2.2, r=3)
    else:
        px, py, ky = 55, 38, 78
        p.rect(6, 3, 104, 24, ENAMEL, INK, 2.2, r=3)
    p.rect(px - 5, min(py, ky), px + 5, max(py, ky), BRASS_HI, INK, 2)
    p.rect(px - 16, ky - 8, px + 16, ky + 8, EBONY, INK, 2.2, r=7)
    p.line([(px - 10, ky - 3), (px + 8, ky - 3)], (86, 80, 72), 1.6)
    p.ell(px, py, 8, 8, BRASS_HI, INK, 2)
    return p


def paint_b_spool(rng):
    p = Pen(W, H, rng)
    for cx in (560, 900):
        p.ell(cx, 820, 44, 44, (30, 28, 30), INK, 3)
        for rr in (36, 30, 24):
            p.ell(cx, 820, rr, rr, None, (56, 52, 52), 1.4)
        p.arc(cx, 820, 40, 40, 200, 250, (92, 88, 86), 2.5)
        p.ell(cx, 820, 15, 15, BRASS, INK, 2.5)
        p.ell(cx, 820, 5, 5, BRASS_HI, INK, 1.5)
    # tape threaded under the head block between the reels
    p.line([(560, 864), (690, 846), (770, 846), (900, 864)], (30, 28, 30), 5)
    p.line([(560, 864), (690, 846), (770, 846), (900, 864)], INK, 1.2)
    p.rect(532, 780, 588, 798, PAPER_HI, INK, 2, r=2)              # blank paper label
    return p


def paint_b_mixer_aligned(rng):
    """The aligned session on the paper chart: two continuous ink pen traces, both bell
    marks inked as tall spikes on the brown guide."""
    p = Pen(W, H, rng)
    gx = 730
    guide = (128, 84, 52)
    for y in range(692, 770, 8):
        p.line([(gx, y), (gx, y + 4)], guide, 2)
    for base, top in ((718, 694), (756, 740)):
        pts = []
        x = 474
        while x <= 986:
            if abs(x - gx) < 12:
                pts += [(gx - 6, base), (gx, top), (gx + 6, base + 3)]
                x = gx + 12
                continue
            pts.append((x, base + rng.uniform(-3.0, 3.0)))
            x += 5
        p.line(pts, INK, 2.2)
    return p


def paint_b_condensation(rng):
    """Beads on the speaker's bell: a few elongated, sea-glass, with runs down from the lip."""
    p = Pen(W, H, rng)
    cx, cy, r = 725, 215, 100
    fog = p.layer()
    fog.ell(cx, cy, r - 12, r - 12, BEAD_TINT + (60,), None)
    p.put_soft(fog, 3)
    for _ in range(5):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(30, 80)
        bead(p, cx + math.cos(a) * d, cy + math.sin(a) * d, rng.uniform(2.6, 3.4), rng.uniform(5.2, 7.0))
    for x0 in (cx - 34, cx + 22, cx + 58):  # runs sliding off the lower rim
        y0 = cy + math.sqrt(max(0.0, r * r - (x0 - cx) ** 2)) - 6
        run = [(x0 + 1.5 * math.sin(k * 0.8), y0 + k * 5) for k in range(10)]
        p.line(run, BEAD_TINT + (210,), 2.8)
        bead(p, run[-1][0], run[-1][1] + 3, 3.4, 5.8)
    return p


WET = (30, 50, 46)


def paint_b_speaker_wet(rng):
    """After P19: the speaker's lip soaked dark, drips running off it, a puddle on the board."""
    p = Pen(W, H, rng)
    cx, cy, r = 725, 215, 100
    stain = p.layer()
    stain.arc(cx, cy, r - 4, r - 4, 10, 170, WET + (255,), 26)
    stain.arc(cx, cy, r - 4, r - 4, 0, 180, WET + (255,), 12)
    p.put_soft(stain, 3, 0.85)
    p.arc(cx, cy, r - 2, r - 2, 30, 150, (150, 186, 172), 2.5)          # wet sheen on the lip
    for dx in (-40, -6, 30, 60):
        x = cx + dx
        y0 = cy + math.sqrt(max(0.0, r * r - dx * dx)) + 4
        length = max(8.0, 326 - y0)
        run = [(x + 1.2 * math.sin(k), y0 + k * length / 8) for k in range(9)]
        p.line(run, INK, 7)
        p.line(run, (52, 84, 76), 4.5)
        tip = run[-1]
        p.ell(tip[0], tip[1] + 4, 6, 8, (52, 84, 76), INK, 2)
        p.ell(tip[0] - 2, tip[1] + 1, 1.8, 2.5, (210, 236, 226), None)
    # the puddle on the board's top rail, and its spill down the front
    sh = p.layer()
    sh.ell(724, 343, 112, 9, (20, 34, 32, 255), None)
    p.put_soft(sh, 3, 0.75)
    p.ell(724, 342, 96, 6.5, (40, 66, 60), INK, 2)
    p.ell(700, 340, 40, 2.2, (170, 204, 190), None)
    for x, length in ((664, 22), (760, 26), (792, 18)):
        p.line([(x, 352), (x + 1, 352 + length)], (40, 66, 60), 6)
        p.ell(x + 1, 354 + length, 4.5, 6, (40, 66, 60), INK, 1.6)
    return p


def paint_b_bulge(rng):
    """Band 7: the cornice breathes out round the speaker pipe, smooth and glossy, no cracks."""
    p = Pen(W, H, rng)
    sw = p.layer()
    swell(sw, 725, 106, 92, 24)
    p.put(sw, mask=clip_mask(p.im.size, [(0, 86, W, 120)]))
    # the flange and pipe sit in front of the swelling
    p.rect(684, 98, 766, 114, BRASS_LO, INK, 3, r=3)
    bolt(p, 694, 106, 3)
    bolt(p, 756, 106, 3)
    p.rect(705, 113, 745, 131, BRASS, INK, 3)
    p.line([(712, 116), (712, 131)], BRASS_HI, 3)
    return p


# ----------------------------------------------------------------------------- close-ups

def timber_board(p, rng, top=0):
    p.rect(-4, top - 4, W + 4, H + 4, TIMBER, None)
    y = top
    while y < H:
        y += rng.randint(64, 96)
        p.line([(-4, y), (W + 4, y)], TIMBER_DK, 2.5)
        p.line([(-4, y + 3), (W + 4, y + 3)], TIMBER_HI, 1.2)
    for _ in range(60):  # long grain streaks
        x, y = rng.uniform(0, W), rng.uniform(top, H)
        p.line([(x, y), (x + rng.uniform(80, 260), y + rng.uniform(-2, 2))], mix(TIMBER, TIMBER_DK, 0.6), 1.4)


def paint_c_spindle(rng):
    p = Pen(W, H, rng, CORK)
    p.rect(-4, -4, W + 4, 352, CORK, None)
    for _ in range(1500):
        x, y = rng.uniform(0, W), rng.uniform(0, 350)
        r = rng.choice((1.2, 1.6, 2.2, 2.8))
        p.ell(x, y, r, r * 0.8, CORK_DK if rng.random() < 0.62 else CORK_HI, None)
    timber_board(p, rng, top=700)
    p.rect(-4, 690, W + 4, 712, CABINET_HI, INK, 3.5)
    # transcript card, pinned
    lay = p.layer()
    lay.rect(268, 120, 1250, 350, (60, 40, 20, 70), None)
    p.put(lay)
    p.rect(260, 110, 1240, 340, PAPER_HI, INK, 3)
    p.line([(270, 122), (1230, 122)], (244, 240, 230), 2)
    for x in (290, 1210):
        p.ell(x, 128, 9, 9, BRASS_HI, INK, 2.5)
    # spindle bed
    p.rect(190, 352, 1250, 612, BRASS_LO, INK, 4.5, r=8)
    p.line([(198, 362), (1242, 362)], BRASS_HI, 3)
    p.rect(200, 395, 250, 445, BRASS_HI, INK, 3, r=3)              # blank arrow field
    p.rect(206, 401, 244, 439, None, BRASS_LO, 1.6, r=2)
    p.rect(204, 470, 1250, 494, BRASS, INK, 3, r=11)               # mandrel along the bed
    for x0 in (260, 590, 920):
        p.rect(x0, 370, x0 + 320, 590, (44, 44, 42), INK, 3.5, r=6)
        p.rect(x0 + 10, 380, x0 + 310, 580, (52, 54, 50), None, r=4)
        p.rect(x0 - 2, 470, x0 + 322, 494, BRASS, INK, 3, r=11)
        p.line([(x0 + 4, 476), (x0 + 316, 476)], BRASS_HI, 3)
        for sx in (x0 + 6, x0 + 296):  # seating saddles
            p.poly([(sx, 446), (sx + 18, 446), (sx + 18, 518), (sx, 518)], BRASS, INK, 2.5)
            p.line([(sx + 4, 452), (sx + 4, 512)], BRASS_HI, 2)
        cx = x0 + 160
        for bx in (cx - 58, cx + 58):  # blank turn buttons
            p.ell(bx, 645, 32, 32, BRASS, INK, 3.5)
            p.ell(bx, 645, 22, 22, BRASS_HI, INK, 1.6)
            p.ell(bx - 6, 637, 8, 6, (236, 214, 160), None)
    p.rect(196, 612, 1244, 690, TIMBER_DK, INK, 3.5)               # apron behind buttons
    for x0 in (260, 590, 920):
        cx = x0 + 160
        for bx in (cx - 58, cx + 58):
            p.ell(bx, 645, 32, 32, BRASS, INK, 3.5)
            p.ell(bx, 645, 22, 22, BRASS_HI, INK, 1.6)
            p.ell(bx - 6, 637, 8, 6, (236, 214, 160), None)
    # needle-arm lever
    p.rect(1340, 582, 1432, 606, BRASS_LO, INK, 3, r=3)
    p.rect(1384, 400, 1416, 590, BRASS, INK, 3.5, r=4)
    p.line([(1391, 410), (1391, 584)], BRASS_HI, 3)
    p.rect(1300, 520, 1388, 536, BRASS, INK, 3, r=4)
    p.rect(1262, 506, 1308, 550, EBONY, INK, 3, r=12)              # finger lift
    p.line([(1270, 516), (1300, 516)], (86, 80, 72), 2)
    p.ell(1400, 400, 22, 22, BRASS_HI, INK, 3.5)
    p.ell(1400, 400, 8, 8, BRASS_DK, INK, 2)
    # felt tray with three compartments
    p.rect(280, 724, 1170, 926, TIMBER, INK, 4, r=6)
    for x0, x1 in ((300, 550), (600, 850), (900, 1150)):
        felt_cradle(p, x0, 740, x1, 910)
    return p


def felt_cradle(p, x0, y0, x1, y1):
    """A felt-lined cradle shaped to hold a band: a hollow trough, shadowed at the back,
    lit along the front lip, with a stitched edge."""
    p.rect(x0, y0, x1, y1, mix(SEAGLASS, INK, 0.35), INK, 3, r=6)
    cx = (x0 + x1) / 2
    lay = p.layer()
    for k in range(14):  # the trough: darker at the back wall, lighter toward the lip
        t = k / 13
        rx = (x1 - x0) / 2 - 10 - t * 10
        yy = y0 + 24 + t * (y1 - y0 - 56)
        lay.ell(cx, yy + 22, rx, 26 + t * 8, mix(mix(SEAGLASS, INK, 0.45), SEAGLASS_HI, t ** 1.4) + (255,), None)
    p.put(lay, mask=clip_mask(p.im.size, [(x0 + 6, y0 + 6, x1 - 6, y1 - 6)]))
    p.arc(cx, y0 + 40, (x1 - x0) / 2 - 18, 22, 200, 340, mix(SEAGLASS, INK, 0.55), 3)
    p.line([(x0 + 10, y1 - 14), (x1 - 10, y1 - 14)], SEAGLASS_HI, 2.4)
    x = x0 + 12
    while x < x1 - 16:  # stitching
        p.line([(x, y0 + 9), (x + 6, y0 + 9)], (196, 214, 204), 1.4)
        p.line([(x, y1 - 9), (x + 6, y1 - 9)], (196, 214, 204), 1.4)
        x += 12


BAND_WAX = (206, 162, 96)


def paint_c_band(rng):
    """A wax band on its horizontal mandrel: wax-amber, rolling dark toward its top and bottom
    edges, one soft specular stripe along the axis, darker where it meets the brass rims."""
    p = Pen(320, 220, rng)
    p.rect(14, 10, 306, 210, BAND_WAX, INK, 3.5, r=10)
    lay = p.layer()
    for y in range(12, 209):
        c = (y - 110) / 98.0                       # -1 top .. 1 bottom
        shade = 1.0 - 0.42 * abs(c) ** 1.8 - (0.1 if c > 0 else 0.0) * c
        col = mix(BAND_WAX, (70, 44, 20), 1.0 - shade)
        lay.rect(16, y, 304, y + 1, col + (255,), None)
    p.put(lay)
    sp = p.layer()
    sp.rect(18, 58, 302, 70, (255, 238, 196, 255), None)
    p.put_soft(sp, 4, 0.55)
    ends = p.layer()
    ends.rect(16, 12, 42, 208, (60, 38, 16, 255), None)
    ends.rect(278, 12, 304, 208, (60, 38, 16, 255), None)
    p.put_soft(ends, 9, 0.38)
    g = p.layer()
    for y in range(20, 204, 7):  # fine groove sheen
        g.line([(30, y), (290, y)], (255, 230, 180, 40), 1)
    p.put(g)
    p.rect(14, 10, 306, 210, None, INK, 3.5, r=10)
    for x0, x1 in ((2, 30), (290, 318)):
        p.rect(x0, 4, x1, 216, BRASS, INK, 3, r=6)
        p.line([(x0 + 6, 12), (x0 + 6, 208)], BRASS_HI, 2.5)
        for ty in (50, 110, 170):  # three engraving ticks per edge, at snap heights 420/480/540 when seated at y370
            p.line([(x0 + 9, ty), (x1 - 9, ty)], BRASS_DK, 2.5)
    return p


def paint_c_needle_arm(rng):
    p = Pen(260, 120, rng)
    p.poly(capsule((240, 20), (56, 46), 12, 7), BRASS, INK, 3)
    p.line([(232, 13), (60, 39)], BRASS_HI, 3)
    p.rect(20, 34, 70, 66, BRASS_LO, INK, 3, r=6)                  # reproducer head
    p.ell(45, 50, 10, 10, BRASS_HI, INK, 2)
    p.poly([(38, 66), (52, 66), (46, 102)], (24, 24, 26), INK, 2)  # stylus
    p.ell(46, 104, 2.5, 2.5, (230, 230, 225), INK, 1)
    p.ell(240, 20, 17, 17, BRASS_HI, INK, 3)
    p.ell(240, 20, 6, 6, BRASS_DK, INK, 1.5)
    return p


def paint_c_mixer(rng):
    p = Pen(W, H, rng, TIMBER)
    timber_board(p, rng)
    p.rect(150, 100, 1300, 590, IRON, INK, 4, r=12)
    p.rect(186, 126, 1264, 574, BRASS, INK, 4, r=8)
    p.line([(194, 133), (1256, 133)], BRASS_HI, 3)
    chart_paper(p, 200, 140, 1250, 560, lanes=((180, 340), (370, 530)))
    for y0, y1 in ((180, 340), (370, 530)):
        p.line([(204, y0), (1246, y0)], mix(INK, PAPER, 0.45), 1.6)
        p.line([(204, y1), (1246, y1)], mix(INK, PAPER, 0.45), 1.6)
    p.line([(725, 144), (725, 556)], (128, 84, 52), 2.4)          # brown ink guide ruled on the glass
    # slider track with seven plain detent notches
    p.rect(380, 610, 1070, 700, BRASS, INK, 4, r=10)
    p.line([(390, 618), (1060, 618)], BRASS_HI, 3)
    p.rect(404, 648, 1046, 662, THROAT, INK, 2, r=6)
    for i in range(7):
        x = 412 + i * 104.5
        p.rect(x - 3, 626, x + 3, 642, BRASS_DK, INK, 1.2)
        p.rect(x - 3, 668, x + 3, 684, BRASS_DK, INK, 1.2)
    # step buttons
    for x0 in (240, 1090):
        p.rect(x0, 600, x0 + 120, 710, IRON, INK, 3.5, r=10)
        p.ell(x0 + 60, 655, 42, 42, BRASS, INK, 3.5)
        p.ell(x0 + 60, 655, 32, 32, BRASS_HI, INK, 1.6)
        p.ell(x0 + 50, 644, 12, 9, (236, 214, 160), None)
    # toggle keys with blank plates
    for x0 in (260, 540):
        p.rect(x0, 770, x0 + 240, 900, PANEL, INK, 3.5, r=8)
        p.rect(x0 + 20, 860, x0 + 220, 890, ENAMEL, INK, 2.5, r=3)
        cx = x0 + 120
        p.ell(cx, 812, 32, 32, BRASS_LO, INK, 3)
        p.ell(cx, 812, 12, 12, BRASS_DK, INK, 2)
    # PLAY key
    p.rect(1010, 770, 1250, 900, PANEL, INK, 3.5, r=8)
    p.rect(1030, 784, 1230, 842, BRASS_HI, INK, 3.5, r=8)
    p.line([(1040, 792), (1220, 792)], (236, 214, 160), 2.5)
    p.rect(1040, 856, 1220, 888, ENAMEL, INK, 2.5, r=3)
    # session-log card holder
    p.rect(1270, 140, 1430, 560, BRASS, INK, 4, r=6)
    p.rect(1282, 160, 1418, 548, PAPER_HI, INK, 2.5)
    p.rect(1300, 146, 1400, 166, BRASS_HI, INK, 2.5, r=4)
    # clip for the contact-sheet scrap
    p.rect(830, 790, 970, 896, TIMBER_DK, INK, 3, r=4)
    p.rect(860, 772, 940, 808, IRON, INK, 3, r=6)
    p.line([(866, 780), (934, 780)], (80, 90, 100), 2)
    p.arc(900, 772, 22, 12, 180, 360, BRASS_HI, 3)
    return p


def lever(p, cx, cy, up):
    """Knife lever, pivot at (cx, cy); handle 120 px above or below."""
    hy = cy - 120 if up else cy + 120
    y0, y1 = min(cy, hy), max(cy, hy)
    p.rect(cx - 9, y0, cx + 9, y1, BRASS, INK, 3)
    p.line([(cx - 4, y0 + 6), (cx - 4, y1 - 6)], BRASS_HI, 3)
    p.rect(cx - 44, hy - 18, cx + 44, hy + 18, EBONY, INK, 3.5, r=16)
    p.line([(cx - 34, hy - 9), (cx + 26, hy - 9)], (86, 80, 72), 2.5)
    fy = hy + 22 if up else hy - 22
    p.rect(cx - 46, fy - 4, cx + 46, fy + 4, BRASS_HI, INK, 2)
    p.ell(cx, cy, 24, 24, BRASS_HI, INK, 3.5)
    p.ell(cx, cy, 9, 9, BRASS_DK, INK, 2)


def paint_c_channels(rng):
    p = Pen(W, H, rng, TIMBER)
    timber_board(p, rng)
    p.rect(-4, -4, W + 4, 26, BRASS, INK, 3)
    # MOTOR housing
    p.rect(150, 250, 340, 630, PANEL, INK, 4, r=10)
    p.rect(165, 260, 325, 300, ENAMEL, INK, 2.5, r=4)
    p.rect(233, 372, 257, 628 - 2, THROAT, INK, 2.5, r=8)
    for cx in (515, 745, 975):
        p.rect(cx - 95, 250, cx + 95, 630, PANEL, INK, 4, r=10)
        p.rect(cx - 80, 260, cx + 80, 300, ENAMEL, INK, 2.5, r=4)
        p.rect(cx - 12, 372, cx + 12, 626, THROAT, INK, 2.5, r=8)
        lamp_unlit(p, cx, 330, 26)
    for x0, x1 in ((150, 340), (420, 610), (650, 840), (880, 1070)):
        bolt(p, x0 + 14, 616, 4)
        bolt(p, x1 - 14, 616, 4)
    witness_key(p, 1120, 300, 220 / 180.0, pressed=False)
    # status tape window
    p.rect(1120, 580, 1340, 670, BRASS, INK, 3.5, r=6)
    p.rect(1132, 594, 1328, 656, GLASS_DK, INK, 2)
    p.rect(1132, 608, 1328, 642, PAPER, INK, 1.6)
    # procedure placard
    p.rect(150, 660, 1090, 780, PAPER_HI, INK, 3.5, r=4)
    p.rect(160, 670, 1080, 770, None, mix(INK, PAPER, 0.55), 1.5, r=2)
    for bx in (166, 1074):
        bolt(p, bx, 676, 5)
        bolt(p, bx, 764, 5)
    # three empty question-card slots
    for x0, x1 in ((150, 520), (540, 910), (930, 1300)):
        p.rect(x0, 820, x1, 940, BRASS, INK, 4, r=6)
        p.rect(x0 + 14, 834, x1 - 14, 926, mix(ENAMEL, INK, 0.12), INK, 2.5, r=3)
        p.rect(x0 + 24, 840, x1 - 24, 920, PAPER_HI, mix(INK, PAPER, 0.5), 1.6, r=2)
        for yy in (866, 884, 902):  # blank ruled lines: a question not yet asked
            p.line([(x0 + 44, yy), (x1 - 44, yy)], mix(PAPER, INK, 0.18), 1.2)
        gl = p.layer()
        gl.poly([(x0 + 40, 836), (x0 + 90, 836), (x0 + 60, 924), (x0 + 10 + 14, 924)], (255, 255, 255, 80), None)
        p.put(gl, mask=clip_mask(p.im.size, [(x0 + 14, 834, x1 - 14, 926)]))
        p.line([(x0 + 6, 826), (x1 - 6, 826)], BRASS_HI, 2.5)
    return p


def paint_c_lever(rng, up):
    p = Pen(150, 300, rng)
    lever(p, 75, 150, up)
    return p


def paint_c_witness_down(rng):
    p = Pen(220, 260, rng)
    witness_key(p, 0, 0, 220 / 180.0, pressed=True)
    return p


# ----------------------------------------------------------------------------- registry

ASSETS = [  # name, seed index, painter, opaque, grain
    # view A plates: base (bands 0-2), s2 (band 3), turned (band 4), s3 (5-6), s4 (7), sever
    ("view_a", 0, lambda r: paint_view_a(r, False, 1), True, True),
    ("view_a_s2", 0, lambda r: paint_view_a(r, False, 2), True, True),
    ("view_a_turned", 0, lambda r: paint_view_a(r, True, 2), True, True),
    ("view_a_s3", 0, lambda r: paint_view_a(r, True, 3), True, True),
    ("view_a_s4", 0, lambda r: paint_view_a(r, True, 4), True, True),
    ("view_a_sever", 0, lambda r: paint_view_a(r, False, 1, sever=True), True, True),
    ("a_condensation", 2, paint_a_condensation, False, False),
    ("a_condensation_turned", 2, lambda r: paint_a_condensation(r, True), False, False),
    ("a_seat_rings", 3, paint_a_seat_rings, False, False),
    ("a_bulge", 4, paint_a_bulge, False, True),
    ("a_mounted", 5, paint_a_mounted, False, True),
    ("a_transcript", 6, paint_a_transcript, False, True),
    ("a_printout_long", 8, paint_a_printout_long, False, True),
    ("a_tag5", 7, paint_a_tag5, False, False),
    ("view_b", 10, paint_view_b, True, True),
    ("view_b_s2", 10, lambda r: paint_view_b(r, 2), True, True),
    ("view_b_s3", 10, lambda r: paint_view_b(r, 3), True, True),
    ("view_b_s4", 10, lambda r: paint_view_b(r, 4), True, True),
    ("b_motor_off", 11, paint_b_motor_off, False, True),
    ("b_lamp_lit", 12, lambda r: paint_lamp_lit(r, 128, 26), False, False),
    ("b_needle", 13, paint_b_needle, False, False),
    ("b_key_open", 14, lambda r: paint_key(r, True), False, False),
    ("b_key_closed", 15, lambda r: paint_key(r, False), False, False),
    ("b_spool", 16, paint_b_spool, False, True),
    ("b_mixer_aligned", 17, paint_b_mixer_aligned, False, False),
    ("b_condensation", 18, paint_b_condensation, False, False),
    ("b_speaker_wet", 19, paint_b_speaker_wet, False, False),
    ("b_bulge", 20, paint_b_bulge, False, True),
    ("c_spindle", 30, paint_c_spindle, True, True),
    ("c_band", 31, paint_c_band, False, True),
    ("c_needle_arm", 32, paint_c_needle_arm, False, False),
    ("c_mixer", 33, paint_c_mixer, True, True),
    ("c_channels", 34, paint_c_channels, True, True),
    ("c_lever_up", 35, lambda r: paint_c_lever(r, True), False, False),
    ("c_lever_down", 36, lambda r: paint_c_lever(r, False), False, False),
    ("c_lamp_lit", 37, lambda r: paint_lamp_lit(r, 96, 30), False, False),
    ("c_witness_down", 38, paint_c_witness_down, False, False),
] + [(f"{v}_{w}_{s}", 50, _light(v, n, w), True, False)
     for v in ("a", "b") for n, s in ((1, "s1"), (2, "s2"), (3, "s3"), (4, "s4"), (0, "sever"))
     for w in ("mul", "add")]


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
