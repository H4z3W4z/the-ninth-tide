#!/usr/bin/env python3
"""R11 Dry Stair painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R11/*.png (and the one stage overlay named below):

  L1_base                         gate landing plate (1448x1086 opaque): sage plaster over a navy
                                  dado, an amber bulkhead lamp, the iron
                                  ladder to the chart-room hatch, the gateway with 16 tread bands and
                                  the dry horizontal water plane at y 520, gauge, lock-box, plate
                                  rack, blank placard
  L1_grille, L1_grille_up         the pressure gate shut / raised (full-frame RGBA)
  L1_glass, L1_glass_deep         the vertical pane standing in the gateway (band 3 / band 4+)
  L1_shelves                      reflected archive shelves below the plane (band 5+)
  L1_tide_1..L1_tide_5            cumulative salt lines on the bare wall (bands 1..7); the newest
                                  heaviest, the last two across the gauge and the placard frame
  L1_glass_tilt                   the deep pane with its plane tilted (band 7)
  L1_spill                        sea-glass light up out of the water onto the floor (band 5+)
  L2_base                         the landing plate (1448x1086 opaque): the office cutaway above
                                  the floor slab, bell bracket, return door, leaf-fold wall, lower
                                  door, reader panel, the stair up through the slab
  L2_bell_up, L2_bell_down        the clapperless bell frozen tipped toward the office / the door
  L2_shoes_dry/_wet/_facing       the empty shoes under the office desk
  L2_door_open, L2_finger_marks   P24: the lower door folded back and its never-seen face
  cut_glass, cut_hand_a/_b        the P12 cut
  port_false, port_true           sight-port views (384x384, circular)
  c_gate (+ c_wheel, c_lever_up/down, c_port_shutter, plate_blank)
  c_door (+ c_access_up/down, c_copy_shut, c_copy_smear)
  rec_frame, rec_strip, rec_card, rec_card_amended, rec_bridge   record sprites
  c_name_shutter                  P24: the iron shutter that drops over the NAME frame's glass
                                  when the door refuses a finished record (300x220)

and, as a stage overlay, assets/stages/R11/p12_water_slab.png (OUT_DIRS): after P12, the water
standing up in the gateway as one vertical slab, flat sea-glass over storm navy inside a hard
navy contour, its flat top standing clear of the lintel; and, from band 6, the late wash:
assets/stages/R11/b6_wash.png (lower landing: the wall at the glass shelf, the office floor's
underside, down to the dado) and b6_wash_L1.png (gate landing: the wall above the horizontal
pane's line), sage soaked to storm navy with a sea-glass waterline stain on the shelf line and
dark drip ticks off it. Each is its plate repainted with the wash under every object, cut to
the band (transparent elsewhere), so every contour on it stays at full ink.

Flat front elevation, approved palette, navy ink contours, matte colour, a low seeded paper
grain. No text, numerals, symbols or diagrams: every placard, plate, flag window, gauge face
(ticks only), stencil and preview strip is blank, and the view writes every word, mark and
needle (the stair marks, the witness circle and the bracket glyphs included).

Python 3 + PIL only. Deterministic: each asset has its own random.Random(SEED + k), there is
no clock and no PIL noise effect, so a rerun is byte-identical.

    python3 tools/art/rooms/R11.py              # paint everything
    python3 tools/art/rooms/R11.py L1_* c_gate  # paint some (fnmatch patterns)
"""
import fnmatch
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "rooms", "R11")
## Assets written somewhere other than OUT: {name: directory}.
OUT_DIRS = {"p12_water_slab": os.path.join(ROOT, "assets", "stages", "R11"),
            "b6_wash": os.path.join(ROOT, "assets", "stages", "R11"),
            "b6_wash_L1": os.path.join(ROOT, "assets", "stages", "R11")}
W, H = 1448, 1086
SS = 2                      # supersampling for every painted shape
SEED = 1931_11_00

# ----------------------------------------------------------------------------- palette
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
VIOLET = (116, 101, 119)    # #746577

WALL = (120, 140, 131)      # riveted iron plates, a desaturated sea-glass a step below the office plaster
WALL_HI = (140, 160, 151)
WALL_DK = (97, 116, 108)
IRON = (40, 48, 56)         # machinery iron
IRON_HI = (66, 78, 88)
IRON_LO = (30, 36, 43)
CEIL = (28, 44, 58)
DECK = (96, 98, 96)         # iron deck under the dust
DUST = (138, 138, 130)      # the dust layer: grey
DUST_HI = (186, 184, 172)   # combed / dragged dust: pale
DUST_LO = (112, 112, 106)
LEATHER = (104, 76, 54)     # restrained brown belts
LEATHER_HI = (128, 98, 72)
LEATHER_DK = (78, 56, 40)
MEMBRANE = (16, 21, 29)     # black-navy
MEMBRANE_HI = (34, 42, 54)
PAINT = (236, 234, 222)     # bolt witness stripes
LEAD = (118, 122, 126)
LEAD_HI = (156, 160, 164)
SALT = (214, 212, 200)
GLASS_DK = (18, 30, 36)

# ----------------------------------------------------------------------------- helpers (as R08)


def rng_for(k):
    return random.Random(SEED + k)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c0, c1, t):
    return tuple(int(round(lerp(a, b, t))) for a, b in zip(c0, c1))


def rgba(c, a=255):
    return c if len(c) == 4 else (c[0], c[1], c[2], a)


def polar(c, r, deg):
    a = math.radians(deg)
    return (c[0] + r * math.cos(a), c[1] + r * math.sin(a))


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

    def line(self, pts, col=INK, w=3.0):
        self.d.line(self._p(pts), fill=rgba(col), width=self.iw(w), joint="curve")

    def arc(self, cx, cy, rx, ry, a0, a1, col, w=3.0):
        box = ((cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS)
        self.d.arc(box, a0, a1, fill=rgba(col), width=self.iw(w))

    def wob_ell(self, cx, cy, rx, ry=None, col=INK, w=5.0, amp=0.9, n=144):
        """A hand-inked ellipse contour: the office's ~3 px line with a slight, slow wobble."""
        ry = rx if ry is None else ry
        ph = [self.rng.uniform(0, math.tau) for _ in range(3)]
        pts = []
        for i in range(n + 1):
            t = math.tau * i / n
            k = amp * (0.55 * math.sin(3 * t + ph[0]) + 0.3 * math.sin(7 * t + ph[1]) + 0.15 * math.sin(13 * t + ph[2]))
            pts.append((cx + (rx + k) * math.cos(t), cy + (ry + k) * math.sin(t)))
        self.line(pts, col, w)

    def wob_poly(self, pts, col=INK, w=5.0, amp=0.8, step=14.0):
        """A closed hand-inked contour along `pts`: subdivided, nudged along the normal."""
        ring = list(pts) + [pts[0]]
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
        out.append(out[0])
        self.line(out, col, w)

    def wob_rect(self, x0, y0, x1, y1, col=INK, w=5.0, amp=0.8):
        self.wob_poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col, w, amp)

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
        d.rectangle((x0 * ss, y0 * ss, x1 * ss, y1 * ss), fill=255)
    return m


def bezier(pts, n=40):
    """Bezier of any degree through De Casteljau."""
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


def strap(p, pts, width, fill, ink=INK, w=2.5, hi=None, lo=None):
    """A flat band of `width` along a polyline: filled, inked edges, one highlight line."""
    a = offset_line(pts, width / 2)
    b = offset_line(pts, -width / 2)
    p.poly(a + b[::-1], fill, None)
    if hi:
        p.line(offset_line(pts, width / 2 - 3), hi, 1.6)
    if lo:
        p.line(offset_line(pts, -width / 2 + 3), lo, 1.6)
    if ink:
        p.line(a, ink, w)
        p.line(b, ink, w)


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
    out = OUT_DIRS.get(name, OUT)
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


def rivet(p, x, y, r=3.2, col=WALL_HI):
    p.ell(x, y, r, r, col, INK, 1.3)


def tangents(c1, r1, c2, r2):
    """External tangent points (on c1, on c2) for both strands, in screen coordinates."""
    dx, dy = c2[0] - c1[0], c2[1] - c1[1]
    d = math.hypot(dx, dy)
    th = math.atan2(dy, dx)
    al = math.acos((r1 - r2) / d)
    out = []
    for s in (1, -1):
        ph = th + s * al
        out.append(((c1[0] + r1 * math.cos(ph), c1[1] + r1 * math.sin(ph)),
                    (c2[0] + r2 * math.cos(ph), c2[1] + r2 * math.sin(ph)), ph))
    return out


def rotated_rect(cx, top, w, h, ang, r=0.0, n=6):
    """Corners of a (rounded) w x h rect hanging from (cx, top), rotated `ang` deg about that point."""
    pts = []
    x0, x1, y0, y1 = cx - w / 2, cx + w / 2, top, top + h
    if r <= 0:
        pts = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    else:
        for (ccx, ccy, a0) in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
            for k in range(n + 1):
                a = math.radians(a0 + 90 * k / n)
                pts.append((ccx + r * math.cos(a), ccy + r * math.sin(a)))
    return [rot(q, (cx, top), ang) for q in pts]


# ----------------------------------------------------------------------------- R11 additions
LIMEWASH = (222, 222, 210)      # steps, gateway dressings
LIMEWASH_DK = (190, 194, 184)
LIMEWASH_HI = (236, 236, 226)
WATER = (78, 120, 112)          # used translucent
SALT = (226, 224, 212)          # R11's salt crust (brighter than the machine room's)
STONE = (172, 184, 175)         # the limewashed wall: cool sea-glass grey
STONE_HI = (190, 200, 191)
STONE_DK = (150, 164, 155)
FLAGS = (146, 142, 130)         # floor flags, a little warm
FLAGS_HI = (164, 160, 147)
FLAGS_DK = (118, 114, 104)
CEIL_ST = (64, 82, 92)          # the stone ceiling / sections
STEEL = (92, 108, 116)          # the return door
STEEL_HI = (118, 134, 140)
STEEL_DK = (70, 84, 92)
RUST = (108, 84, 66)            # restrained brown: the raw reverse face of the lower door
RUST_HI = (132, 104, 82)
RUST_DK = (82, 62, 48)
BRONZE = (60, 62, 52)           # the bell: dark bronze gone to iron-grey
BRONZE_HI = (104, 102, 80)
BRONZE_DK = (36, 38, 32)
COLD = (232, 240, 238)          # the cold light from above
GRAPHITE = (92, 96, 100)
# repaint pass: the office's wall grammar carried down the stair
PLASTER = (152, 170, 155)       # upper wall: the office's sage plaster, a step down
PLASTER_HI = (168, 184, 168)
PLASTER_DK = (132, 150, 137)
WAINSCOT = (40, 70, 88)         # storm-navy dado (office wainscot proportion)
WAINSCOT_HI = (58, 90, 108)
WAINSCOT_DK = (30, 54, 70)
WELL = (88, 104, 106)           # the stairwell's own side walls
SEA_DEEP = (52, 112, 102)       # saturated sea-glass: the water's body
SEA_SAT = (80, 136, 121)
LAMP = (246, 214, 150)          # an amber bulkhead lamp's lit glass
# the Intake Office (assets/backgrounds/office_arrival.png), sampled
O_PLASTER = (163, 179, 162)
O_TEAL = (47, 86, 103)
O_TEAL_HI = (66, 108, 124)
O_TEAL_DK = (34, 64, 79)
O_WOOD = (106, 78, 56)
O_WOOD_HI = (128, 97, 70)
O_WOOD_DK = (82, 60, 43)
O_SKY = (161, 168, 177)
O_SEA = (133, 143, 154)
O_HILL = (76, 89, 101)
FACE = (84, 100, 104)           # close-up iron face
FACE_HI = (104, 120, 122)
FACE_DK = (66, 80, 86)

# ----------------------------------------------------------------------------- geometry (fixed)
OPEN = (540, 160, 910, 880)     # the gateway opening
SURR = (500, 120, 950, 880)
PLANE_Y = 520
N_TREADS = 16
FLOOR_Y = 880
GAUGE_PLATE = (200, 200, 400, 640)
DIAL = (300, 300, 88)
HUB = (300, 530, 80)
LOCKBOX = (960, 540, 1150, 720)
PLACARD = (1170, 180, 1400, 500)
HATCH = (40, 80, 190, 120)
LADDER = (70, 150)
PIVOT = (456, 374)
CUT = (310, 80, 1140, 300)      # L2 office cutaway (above the floor line)
SLAB = (300, 330)               # slab section y range
HOLE = (1262, 1424)             # ragged opening in the slab over the stair


def tick_angle(k, n=6, a0=-120.0, a1=120.0):
    return a0 + (a1 - a0) * k / (n - 1)


def from_up(c, r, deg):
    a = math.radians(deg)
    return (c[0] + r * math.sin(a), c[1] - r * math.cos(a))


def clip(pen, mask):
    pen.im.putalpha(ImageChops.multiply(pen.im.getchannel("A"), mask))


def full_mask(size, ss=SS):
    return Image.new("L", (size[0] * ss, size[1] * ss), 255)


def cut_out(mask, boxes, ss=SS):
    d = ImageDraw.Draw(mask)
    for x0, y0, x1, y1 in boxes:
        d.rectangle((x0 * ss, y0 * ss, x1 * ss, y1 * ss), fill=0)
    return mask


def screw(p, x, y, r=5.0):
    p.ell(x, y, r, r, BRASS, INK, 1.6)
    p.line([(x - r * 0.65, y + r * 0.35), (x + r * 0.65, y - r * 0.35)], BRASS_DK, 1.4)


def bolt(p, x, y, r=4.0, col=IRON_HI, ink=INK):
    p.ell(x + 0.8, y + 1.2, r, r, (14, 20, 26), None)
    p.ell(x, y, r, r, col, ink, 1.4)
    p.ell(x - r * 0.3, y - r * 0.3, r * 0.35, r * 0.35, mix(col, (255, 255, 255), 0.35), None)


def soft_shadow(p, box, off=(6, 8), radius=8, opacity=0.4, r=0):
    sh = p.layer()
    x0, y0, x1, y1 = box
    sh.rect(x0 + off[0], y0 + off[1], x1 + off[0], y1 + off[1], (10, 16, 22), None, 0, r)
    p.put_soft(sh, radius, opacity)


# ----------------------------------------------------------------------------- stone

def stone_wall(p, rng, box, base=STONE, course=92, y_start=None, skip=(), mottle=0.22, joints=0.55):
    """Limewashed stone: a flat matte fill, faint block joints, a broad soft mottle."""
    x0, y0, x1, y1 = box
    p.rect(x0, y0, x1, y1, base, None)
    lay = p.layer()
    for _ in range(int((x1 - x0) * (y1 - y0) / 9000) + 4):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        lay.ell(x, y, rng.uniform(40, 140), rng.uniform(20, 60), mix(base, INK, 0.12) if rng.random() < 0.55 else mix(base, (255, 255, 255), 0.14), None)
    m = rect_mask((W, H), [box])
    p.put_soft(lay, 26, mottle, m)
    jl = p.layer()
    jc = mix(base, SEAGLASS, joints)
    hc = mix(base, LIMEWASH_HI, 0.5)
    ys = y0 if y_start is None else y_start
    row = 0
    y = ys
    while y < y1:
        yy = min(y + course, y1)
        if y > y0 + 2:
            jl.line([(x0, y), (x1, y)], jc, 2.0)
            jl.line([(x0, y + 2.4), (x1, y + 2.4)], hc, 1.0)
        x = x0 - (rng.uniform(40, 160) if row % 2 else rng.uniform(0, 60))
        while x < x1:
            x += rng.uniform(150, 250)
            if x0 + 8 < x < x1 - 8:
                jl.line([(x, y + 2), (x, yy - 1)], jc, 2.0)
                jl.line([(x + 2.4, y + 3), (x + 2.4, yy - 1)], hc, 1.0)
        y += course
        row += 1
    jm = rect_mask((W, H), [box])
    cut_out(jm, skip)
    p.put(jl, 0.8, jm)


def floor_flags(p, rng, y0=FLOOR_Y, y1=H):
    p.rect(-4, y0, W + 4, y1 + 4, FLAGS, None)
    lay = p.layer()
    for _ in range(60):
        lay.ell(rng.uniform(0, W), rng.uniform(y0, y1), rng.uniform(40, 130), rng.uniform(8, 22),
                FLAGS_HI if rng.random() < 0.5 else FLAGS_DK, None)
    p.put_soft(lay, 12, 0.3)
    for y in (962, 1036):
        p.line([(-4, y), (W + 4, y)], FLAGS_DK, 2.4)
        p.line([(-4, y + 2.6), (W + 4, y + 2.6)], FLAGS_HI, 1.1)
    rows = [(y0, 962), (962, 1036), (1036, y1 + 4)]
    for j, (a, b) in enumerate(rows):
        x = rng.uniform(-80, 60) + j * 70
        while x < W:
            x += rng.uniform(220, 320)
            p.line([(x, a + 3), (x, b - 1)], FLAGS_DK, 2.2)
    toe = p.layer()
    toe.rect(-4, 1046, W + 4, y1 + 4, mix(FLAGS_DK, STORM, 0.4), None)
    p.put_soft(toe, 24, 0.4)
    p.line([(-4, y0), (W + 4, y0)], INK, 3)
    p.line([(-4, y0 + 3), (W + 4, y0 + 3)], FLAGS_HI, 1.2)


def ceiling_band(p, rng, x0, x1, y1=80):
    p.rect(x0, -4, x1, y1, CEIL_ST, None)
    for x in range(int(x0) + 60, int(x1), 180):
        p.line([(x, -4), (x, y1 - 4)], mix(CEIL_ST, INK, 0.4), 2)
    p.line([(x0, 30), (x1, 30)], mix(CEIL_ST, INK, 0.35), 2)
    p.line([(x0, y1 - 6), (x1, y1 - 6)], mix(CEIL_ST, STONE, 0.3), 1.6)
    p.line([(x0, y1), (x1, y1)], INK, 3)


# ----------------------------------------------------------------------------- the stair

def stair(p, n=N_TREADS, dx=0.0, dy=0.0, box=OPEN, plane=PLANE_Y, tint=0.62, extra=1, wear=True,
          inset=3.0, refr=5.0, dim=0.0):
    """Treads going down away from us in flat elevation. Each row is a bright nosing, a soft
    shadow under it and a riser a few values darker; the rows step inward a few px each and
    darken sharply with depth, so the flight reads as descending without any perspective.
    Rows below `plane` are tinted saturated sea-glass and shifted `refr` px sideways (the
    water's refraction), still crisp and dry. `dim` darkens everything (seen through a slab)."""
    x0, y0, x1, y1 = box
    pitch = (y1 - y0) / n
    nose = max(4.0, min(22.0, pitch * 0.27))
    top = y0 - pitch * extra + dy
    p.rect(x0 - 12 + dx, top, x1 + 12 + dx, y1 + pitch * extra + dy, mix(WELL, INK, 0.25 + 0.4 * dim), None)
    for i in range(-extra, n + extra):
        ty = y0 + i * pitch
        below = ty >= plane - 0.5
        depth = max(0.0, min(1.0, i / max(1, n - 1)))
        dk = depth ** 0.65
        ins = max(0, i) * inset
        sx = refr if below else 0.0
        a, b = ty + dy, ty + pitch + dy
        xa, xb = x0 - 12 + ins + dx + sx, x1 + 12 - ins + dx + sx
        well = mix(mix(WELL, STONE_DK, 0.3), STORM, 0.2 + 0.55 * dk)
        nc = mix(LIMEWASH_HI, mix(LIMEWASH_DK, STORM, 0.55), 0.06 + 0.94 * dk)
        rc = mix(nc, INK, 0.17)
        if below:
            well = mix(well, SEA_DEEP, tint * 0.8)
            nc = mix(nc, SEA_SAT, tint * 0.7)
            rc = mix(rc, SEA_DEEP, tint * 0.85)
        if dim:
            well, nc, rc = mix(well, INK, dim), mix(nc, INK, dim * 0.8), mix(rc, INK, dim)
        # the stairwell wall beside this row
        p.rect(x0 - 12 + dx, a, x1 + 12 + dx, b, well, None)
        # riser, then the shadow under the nosing, then the nosing
        p.rect(xa, a, xb, b, rc, None)
        for k in range(9):
            t = k / 9.0
            p.line([(xa, a + nose + k + 0.5), (xb, a + nose + k + 0.5)], mix(rc, INK, 0.42 * (1 - t) ** 1.6), 1.2)
        p.rect(xa, a, xb, a + nose, nc, None)
        p.line([(xa, a + 1.6), (xb, a + 1.6)], mix(nc, (255, 255, 255), 0.4), 1.4)
        if wear and pitch > 30:
            p.ell((xa + xb) / 2, a + nose * 0.55, 60, nose * 0.22, mix(nc, (255, 255, 255), 0.22), None)
        p.line([(xa, a + nose), (xb, a + nose)], mix(nc, INK, 0.5), 1.0)
        p.line([(xa, a), (xb, a)], mix(INK, nc, 0.2), 1.6 if pitch > 30 else 1.2)
        # the stepped silhouette against the wells
        p.line([(xa, a), (xa, b)], INK, 1.8)
        p.line([(xb, a), (xb, b)], INK, 1.8)


def motes(p, rng, box, n=4, col=None):
    """Motionless suspended specks in the water: pale, inked, absolutely still."""
    x0, y0, x1, y1 = box
    col = col or mix(SEAGLASS_HI, COLD, 0.6)
    for _ in range(n):
        x, y = rng.uniform(x0 + 30, x1 - 30), rng.uniform(y0 + 20, y1 - 30)
        r = rng.uniform(2.2, 3.6)
        p.ell(x, y, r, r, col, mix(INK, SEA_DEEP, 0.3), 1.0)


def water_plane(p, y=PLANE_Y, x0=OPEN[0], x1=OPEN[2], dx=0.0, opacity=1.0, tilt=0.0, y_end=OPEN[3]):
    """The dry horizontal plane: a hard bright 5 px meniscus and a 36 px band of saturated
    sea-glass under it, stopping flush at both jambs with a glassy 6 px bevel down each jamb
    face. `tilt` lifts the far (right) end that many px: a slanted surface that still does
    not spill."""
    yl, yr = y + tilt * 0.35, y - tilt * 0.65
    xa, xb = x0 + dx, x1 + dx
    Y = lambda x: lerp(yl, yr, (x - xa) / (xb - xa))
    lay = p.layer()
    lay.poly([(xa, yl), (xb, yr), (xb, y_end), (xa, y_end)], rgba(SEA_DEEP, 46), None)
    for k in range(6):
        t0, t1 = k / 6.0, (k + 1) / 6.0
        lay.poly([(xa, yl + 5 + 31 * t0), (xb, yr + 5 + 31 * t0), (xb, yr + 5 + 31 * t1), (xa, yl + 5 + 31 * t1)],
                 rgba(mix(SEA_SAT, SEA_DEEP, t0), int(225 - 120 * t0)), None)
    lay.poly([(xa, yl), (xb, yr), (xb, yr + 5), (xa, yl + 5)], (248, 253, 250, 255), None)
    lay.line([(xa, yl + 5.5), (xb, yr + 5.5)], rgba(mix(SEA_DEEP, INK, 0.5), 230), 1.2)
    lay.line([(xa + 30, Y(xa + 30) + 14), (xa + 140, Y(xa + 140) + 14)], rgba(mix(SEAGLASS_HI, COLD, 0.6), 190), 1.6)
    lay.line([(xb - 200, Y(xb - 200) + 22), (xb - 80, Y(xb - 80) + 22)], rgba(mix(SEAGLASS_HI, COLD, 0.6), 150), 1.4)
    # the water's edge against each jamb face: a cool bevel, brightest at the meniscus
    for xe, s, ye in ((xa, 1, yl), (xb, -1, yr)):
        for k in range(6):
            t = k / 6.0
            yb = ye + 5 + (y_end - ye - 5) * (1 - 0.0)
            col = mix(COLD, SEAGLASS_HI, 0.25 + 0.6 * t)
            lay.line([(xe + s * (k + 0.5), ye), (xe + s * (k + 0.5), ye + 60)], rgba(col, int(235 - 25 * k)), 1.2)
            lay.line([(xe + s * (k + 0.5), ye + 60), (xe + s * (k + 0.5), yb)], rgba(col, int(120 - 14 * k)), 1.2)
        lay.line([(xe + s * 6.5, ye + 5), (xe + s * 6.5, y_end)], rgba(mix(SEA_DEEP, INK, 0.45), 170), 1.2)
    p.put(lay, opacity)


# ----------------------------------------------------------------------------- L1 pieces

def ladder(p, rng):
    # the hatch: a bright hole in the ceiling with an iron coaming hanging to y 120
    x0, y0, x1, y1 = HATCH
    p.rect(x0 + 14, -4, x1 - 14, y1 - 8, COLD, None)
    glow = p.layer()
    glow.poly([(x0 + 10, y1 - 10), (x1 - 10, y1 - 10), (x1 + 40, 820), (x0 - 40, 820)], COLD, None)
    p.put_soft(glow, 40, 0.75)
    glow = p.layer()
    glow.rect(x0 + 30, y1 - 10, x1 - 30, 520, (255, 255, 255), None)
    p.put_soft(glow, 22, 0.4)
    # coaming
    for xa, xb in ((x0, x0 + 14), (x1 - 14, x1)):
        p.rect(xa, -4, xb, y1, IRON, INK, 2.6)
        p.line([(xa + 4, 2), (xa + 4, y1 - 4)], IRON_HI, 1.4)
    p.rect(x0 - 6, y1 - 12, x1 + 6, y1, IRON, INK, 2.6)
    p.line([(x0 - 4, y1 - 9), (x1 + 4, y1 - 9)], IRON_HI, 1.4)
    for x in range(x0 + 4, x1, 24):
        bolt(p, x, y1 - 6, 2.4)
    # the hatch lid hinged up into the light (a dark edge-on slab)
    p.rect(x1 - 30, -4, x1 - 18, y1 - 14, mix(IRON, INK, 0.3), INK, 2)
    # stiles and rungs
    la, lb = LADDER
    for xa in (la, lb - 12):
        p.rect(xa, y1 - 4, xa + 12, FLOOR_Y + 2, IRON, INK, 2.6)
        p.line([(xa + 3.5, y1), (xa + 3.5, FLOOR_Y - 2)], mix(IRON_HI, COLD, 0.35), 1.6)
    for y in range(156, FLOOR_Y - 10, 40):
        p.rect(la + 12, y, lb - 12, y + 7, IRON, INK, 2.0, 3)
        lit = max(0.0, 1.0 - (y - 120) / 640.0)
        p.line([(la + 13, y + 1.6), (lb - 13, y + 1.6)], mix(IRON_HI, COLD, 0.7 * lit), 1.6)
    for y in (300, 600, 830):
        for xa in (la - 10, lb - 2):
            p.rect(xa, y - 8, xa + 12, y + 8, IRON_HI, INK, 1.8)
            bolt(p, xa + 6, y, 2.2)
    for xa in (la - 4, lb - 16):
        p.rect(xa, FLOOR_Y - 6, xa + 20, FLOOR_Y + 2, IRON_HI, INK, 1.8)


def gateway(p, rng):
    x0, y0, x1, y1 = SURR
    ox0, oy0, ox1, oy1 = OPEN
    soft_shadow(p, (x0, y0, x1, y1), (6, 6), 10, 0.25)
    # jambs and lintel, dressed limewash blocks
    p.rect(x0, y0, x1, y1, LIMEWASH, None)
    for (a, b) in ((x0, ox0), (ox1, x1)):
        p.rect(a, oy0, b, y1, LIMEWASH, None)
        p.line([(a + 4, oy0), (a + 4, y1)], LIMEWASH_HI, 1.4)
        p.line([(b - 4, oy0), (b - 4, y1)], LIMEWASH_DK, 2.0)
        for y in (330, 500, 700):
            p.line([(a, y), (b, y)], mix(LIMEWASH_DK, SEAGLASS, 0.35), 2)
    p.rect(x0, y0, x1, oy0, LIMEWASH, None)
    p.line([(x0, y0 + 4), (x1, y0 + 4)], LIMEWASH_HI, 1.6)
    p.line([(x0, oy0 - 4), (x1, oy0 - 4)], LIMEWASH_DK, 2.2)
    for x in (620, 830):
        p.line([(x, y0 + 2), (x, oy0 - 2)], mix(LIMEWASH_DK, SEAGLASS, 0.35), 2)
    # matte wear on the dressings
    lay = p.layer()
    for _ in range(14):
        lay.ell(rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(10, 26), rng.uniform(16, 50), LIMEWASH_DK, None)
    m = rect_mask((W, H), [(x0, y0, ox0, y1), (ox1, y0, x1, y1), (x0, y0, x1, oy0)])
    p.put_soft(lay, 10, 0.35, m)
    # the stair inside
    st = p.layer()
    stair(st)
    clip(st, rect_mask((W, H), [OPEN]))
    p.put(st)
    # a cool shadow under the lintel and down the jambs' reveals
    sh = p.layer()
    sh.rect(ox0, oy0, ox1, oy0 + 26, STORM, None)
    sh.rect(ox0, oy0, ox0 + 14, PLANE_Y, STORM, None)
    sh.rect(ox1 - 14, oy0, ox1, PLANE_Y, STORM, None)
    p.put_soft(sh, 8, 0.32, rect_mask((W, H), [OPEN]))
    water_plane(p)
    mo = p.layer()
    motes(mo, rng_for(300), (ox0 + 40, PLANE_Y + 60, ox1 - 40, oy1 - 40), 4)
    p.put(mo)
    p.wob_rect(ox0, oy0, ox1, oy1, INK, 3.2, 0.5)
    p.wob_poly([(x0, oy1), (x0, y0), (x1, y0), (x1, oy1)], INK, 3.4, 0.6)
    p.line([(x0, oy0), (ox0, oy0)], INK, 2.4)
    p.line([(ox1, oy0), (x1, oy0)], INK, 2.4)
    # the sill: a worn threshold stone flush with the floor
    p.rect(x0 - 6, oy1 - 2, x1 + 6, oy1 + 14, LIMEWASH_DK, INK, 2.6)
    p.line([(x0, oy1 + 3), (x1, oy1 + 3)], LIMEWASH_HI, 1.4)


def gauge(p, rng):
    x0, y0, x1, y1 = GAUGE_PLATE
    soft_shadow(p, GAUGE_PLATE, (7, 9), 9, 0.45, 8)
    p.rect(x0, y0, x1, y1, IRON, None, 0, 8)
    p.rect(x0 + 7, y0 + 7, x1 - 7, y1 - 7, None, IRON_HI, 1.6, 5)
    p.line([(x0 + 10, y0 + 4), (x1 - 10, y0 + 4)], mix(IRON_HI, STONE, 0.3), 1.6)
    p.wob_rect(x0, y0, x1, y1, INK, 3.2, 0.5)
    for y in range(y0 + 16, y1 - 6, 34):
        bolt(p, x0 + 15, y, 3.2)
        bolt(p, x1 - 15, y, 3.2)
    for x in range(x0 + 49, x1 - 30, 34):
        bolt(p, x, y0 + 15, 3.2)
        bolt(p, x, y1 - 15, 3.2)
    # pressure line to the gateway jamb
    p.rect(x1 - 2, 584, 501, 598, IRON, INK, 2.2)
    p.line([(x1, 588), (500, 588)], IRON_HI, 1.4)
    for x in (430, 474):
        p.rect(x - 5, 579, x + 5, 603, IRON_HI, INK, 1.8)
    # dial: brass bezel, cream enamel, six ticks over 240 degrees, no numerals
    cx, cy, r = DIAL
    p.ell(cx + 4, cy + 6, r + 13, r + 13, (12, 18, 24), None)
    p.ell(cx, cy, r + 12, r + 12, BRASS, INK, 3)
    p.arc(cx, cy, r + 7, r + 7, 200, 290, BRASS_HI, 2.4)
    p.arc(cx, cy, r + 7, r + 7, 20, 110, BRASS_DK, 2.4)
    p.ell(cx, cy, r, r, ENAMEL, INK, 2.6)
    p.ell(cx, cy, r - 9, r - 9, None, mix(ENAMEL, INK, 0.25), 1.2)
    for k in range(6):
        a = tick_angle(k)
        p.line([from_up((cx, cy), r - 24, a), from_up((cx, cy), r - 8, a)], INK, 3.4)
    p.ell(cx, cy, 7, 7, IRON_HI, INK, 1.8)
    # the small blank window under the hub
    wx, wy = 300, 345
    p.rect(wx - 37, wy - 13, wx + 37, wy + 13, BRASS_LO, INK, 1.8, 2)
    p.rect(wx - 35, wy - 11, wx + 35, wy + 11, PAPER_HI, INK, 1.6, 1)
    p.line([(wx - 33, wy - 8), (wx + 33, wy - 8)], mix(PAPER_HI, INK, 0.2), 1.2)
    # glass sheen over the enamel
    sh = p.layer()
    sh.poly([(cx - r * 0.75, cy - r * 0.3), (cx - r * 0.35, cy - r * 0.8), (cx - r * 0.2, cy - r * 0.72), (cx - r * 0.66, cy - r * 0.15)], (255, 255, 255), None)
    p.put_soft(sh, 5, 0.35, circle_mask((W, H), (cx, cy), r - 2))
    # handwheel seat: a darker turned disc and the shaft boss (the view lays the wheel on it)
    hx, hy, hr = HUB
    p.ell(hx, hy, hr + 4, hr + 4, mix(IRON, INK, 0.35), INK, 2)
    p.ell(hx, hy, hr - 6, hr - 6, None, IRON_HI, 1.2)
    p.ell(hx + 2, hy + 3, 24, 24, (12, 18, 24), None)
    p.ell(hx, hy, 23, 23, IRON_HI, INK, 2.4)
    p.ell(hx, hy, 10, 10, BRASS, INK, 1.8)
    p.rect(hx - 4, hy - 4, hx + 4, hy + 4, BRASS_DK, None)


def lockbox(p, rng):
    x0, y0, x1, y1 = LOCKBOX
    soft_shadow(p, LOCKBOX, (7, 9), 9, 0.45, 6)
    p.rect(x0, y0, x1, y1, IRON, INK, 3.2, 6)
    p.rect(x0 + 6, y0 + 6, x1 - 6, y1 - 6, None, BRASS, 3.2, 4)
    p.rect(x0 + 9, y0 + 9, x1 - 9, y1 - 9, None, BRASS_DK, 1.2, 3)
    for (a, b) in ((556, 614), (644, 702)):
        p.rect(1002, a - 4, 1110, b + 4, BRASS_LO, INK, 2, 3)
        p.rect(1006, a, 1106, b, GLASS_DK, INK, 1.8, 2)
        p.line([(1008, b - 2), (1104, b - 2)], IRON_HI, 1.4)
        p.line([(1008, a + 3), (1104, a + 3)], (8, 14, 18), 3)
    p.rect(975, 626, 1135, 634, BRASS_HI, INK, 1.6)
    p.line([(977, 632), (1133, 632)], BRASS_LO, 1.2)
    p.rect(1124, 560, 1146, 700, (10, 16, 20), INK, 2, 10)
    p.line([(1128, 566), (1128, 694)], IRON, 1.6)
    for (x, y) in ((x0 + 22, y0 + 20), (x1 - 22, y0 + 20), (x0 + 22, y1 - 20), (x1 - 22, y1 - 20)):
        pass
    for (x, y) in ((x0 + 16, y0 + 16), (x0 + 16, y1 - 16), (x1 - 16, y1 - 16)):
        bolt(p, x, y, 3.2, BRASS_HI)
    # the plate rack below: a brass bar, a hanging strap, three hooks
    for x in (984, 1126):
        p.rect(x - 6, 726, x + 6, 746, IRON_HI, INK, 1.8)
        bolt(p, x, 736, 2.4)
    p.rect(980, 732, 1130, 740, BRASS, INK, 1.8, 2)
    p.line([(982, 734), (1128, 734)], BRASS_HI, 1.2)
    p.rect(1053, 740, 1059, 852, BRASS_LO, INK, 1.4)
    for y in (742, 792, 842):
        p.line([(1056, y - 2), (1056, y + 6), (1062, y + 10), (1068, y + 6)], INK, 4.2)
        p.line([(1056, y - 2), (1056, y + 6), (1062, y + 10), (1068, y + 6)], BRASS_HI, 2.0)


def placard(p, rng, box=PLACARD):
    x0, y0, x1, y1 = box
    soft_shadow(p, box, (6, 8), 8, 0.35, 8)
    p.rect(x0, y0, x1, y1, ENAMEL, INK, 3, 8)
    p.rect(x0 + 10, y0 + 10, x1 - 10, y1 - 10, None, STORM, 3, 4)
    p.line([(x0 + 14, y0 + 5), (x1 - 14, y0 + 5)], PAPER_HI, 1.4)
    lay = p.layer()
    lay.ell((x0 + x1) / 2, y1 - 30, (x1 - x0) * 0.5, 40, mix(ENAMEL, SEAGLASS, 0.4), None)
    p.put_soft(lay, 18, 0.25, rect_mask((W, H), [box]))
    for (x, y) in ((x0 + 22, y0 + 22), (x1 - 22, y0 + 22), (x0 + 22, y1 - 22), (x1 - 22, y1 - 22)):
        screw(p, x, y, 5.5)


DADO_Y = 620


def dado(p, rng, x0=-4, x1=W + 4, y0=DADO_Y, y1=FLOOR_Y):
    """The office's wainscot carried down here: a storm-navy boarded dado, a restrained brown
    timber cap rail and a dark skirting. Drawn before every object on the wall."""
    p.rect(x0, y0, x1, y1, WAINSCOT, None)
    lay = p.layer()
    for _ in range(26):
        lay.ell(rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(60, 160), rng.uniform(20, 60),
                WAINSCOT_DK if rng.random() < 0.6 else WAINSCOT_HI, None)
    p.put_soft(lay, 22, 0.35, rect_mask((W, H), [(x0, y0, x1, y1)]))
    x = x0 + 18
    while x < x1:
        p.line([(x, y0 + 14), (x, y1 - 20)], WAINSCOT_DK, 2.2)
        p.line([(x + 2.4, y0 + 14), (x + 2.4, y1 - 20)], WAINSCOT_HI, 1.0)
        x += 36
    p.rect(x0, y1 - 22, x1, y1, WAINSCOT_DK, None)
    p.line([(x0, y1 - 22), (x1, y1 - 22)], INK, 2.0)
    sh = p.layer()
    sh.rect(x0, y0 + 2, x1, y0 + 12, (10, 16, 22), None)
    p.put_soft(sh, 4, 0.4)
    p.rect(x0, y0 - 12, x1, y0 + 4, TIMBER, INK, 2.4)
    p.line([(x0, y0 - 9), (x1, y0 - 9)], TIMBER_HI, 1.6)
    p.line([(x0, y0 + 1), (x1, y0 + 1)], TIMBER_DK, 1.4)


def bulkhead_lamp(p, cx, cy, pool=True):
    """A small caged bulkhead lamp, lit amber: the landing's one warm note."""
    if pool:
        g = p.layer()
        g.ell(cx, cy + 30, 150, 120, AMBER, None)
        p.put_soft(g, 46, 0.32)
        g = p.layer()
        g.ell(cx, cy + 6, 46, 40, LAMP, None)
        p.put_soft(g, 16, 0.45)
    p.rect(cx - 26, cy - 34, cx + 26, cy - 22, BRASS, INK, 2.2, 3)
    p.line([(cx - 22, cy - 31), (cx + 22, cy - 31)], BRASS_HI, 1.4)
    bolt(p, cx - 18, cy - 28, 2.2, BRASS_HI)
    bolt(p, cx + 18, cy - 28, 2.2, BRASS_HI)
    p.ell(cx, cy, 22, 24, LAMP, INK, 2.4)
    p.ell(cx - 6, cy - 7, 7, 8, (255, 244, 214), None)
    for dx in (-11, 0, 11):
        p.line([(cx + dx, cy - 22), (cx + dx * 1.15, cy + 23)], BRASS_LO, 3.2)
        p.line([(cx + dx, cy - 22), (cx + dx * 1.15, cy + 23)], BRASS_HI, 1.2)
    p.arc(cx, cy, 22, 24, 0, 360, BRASS_LO, 3)
    p.line([(cx - 20, cy + 2), (cx + 20, cy + 2)], BRASS_LO, 3)
    p.ell(cx, cy + 25, 6, 4, BRASS, INK, 1.6)


def paint_L1_base(rng):
    p = Pen(W, H, rng, PLASTER)
    stone_wall(p, rng, (-4, 80, W + 4, DADO_Y), PLASTER, 96, 80, skip=[(1350, 550, 1442, 770), (906, 160, 954, 880)],
               mottle=0.18, joints=0.4)
    return _l1_after_wall(p, rng)


def _l1_after_wall(p, rng):
    """Everything on the gate landing after its wall (b6_wash_L1 lays its wash between)."""
    dado(p, rng)
    ceiling_band(p, rng, -4, W + 4)
    ladder(p, rng)
    gateway(p, rng)
    gauge(p, rng)
    lockbox(p, rng)
    placard(p, rng)
    bulkhead_lamp(p, 1060, 250)
    floor_flags(p, rng)
    return p


# ----------------------------------------------------------------------------- L1 overlays

def paint_grille(rng, raised=False):
    """The pressure gate: five light iron bars at 66 px (wide enough to see the stair and the
    plane through), three rails, spiked feet; raised, only its bottom rail shows in the lintel."""
    p = Pen(W, H, rng)
    x0, x1 = 548, 902
    bars = [593 + 66 * k for k in range(5)]
    bar, bar_hi = IRON_HI, mix(IRON_HI, COLD, 0.35)
    if raised:
        top, bot = 160, 176
        p.rect(x0, top, x1, bot, bar, INK, 2.6)
        p.line([(x0 + 3, top + 4), (x1 - 3, top + 4)], bar_hi, 1.6)
        for x in bars:
            p.poly([(x - 5, bot - 1), (x + 5, bot - 1), (x, 198)], bar, INK, 2.0)
            bolt(p, x, top + 8, 2.6)
        sh = p.layer()
        sh.rect(x0, bot, x1, bot + 10, (10, 16, 22), None)
        p.put_soft(sh, 5, 0.3)
        return p
    sh = p.layer()
    for x in bars:
        sh.rect(x - 4 + 6, 346 + 8, x + 4 + 6, 864 + 8, (10, 16, 22), None)
    for (a, b) in ((330, 346), (598, 610), (864, 880)):
        sh.rect(x0 + 6, a + 8, x1 + 6, b + 8, (10, 16, 22), None)
    p.put_soft(sh, 5, 0.28, rect_mask((W, H), [OPEN]))
    for x in (x0, x1 - 8):
        p.rect(x, 330, x + 8, 880, bar, INK, 2.2)
    for x in bars:
        p.rect(x - 4, 346, x + 4, 864, bar, INK, 2.0)
        p.line([(x - 1.5, 348), (x - 1.5, 862)], bar_hi, 1.4)
    for (a, b) in ((330, 346), (598, 610), (864, 880)):
        p.rect(x0, a, x1, b, bar, INK, 2.6)
        p.line([(x0 + 3, a + 4), (x1 - 3, a + 4)], bar_hi, 1.6)
        for x in bars:
            bolt(p, x, (a + b) / 2, 2.6)
    for x in bars:
        p.poly([(x - 5, 879), (x + 5, 879), (x, 896)], bar, INK, 2.0)
    return p


def glass_layer(rng, deep=False, tilt=0.0):
    """The water standing up in the open gateway like a pane: the stair seen through it, shifted
    6/12 px, the plane (tilted at band 7), the pane's own thickness at the jambs and top."""
    p = Pen(W, H, rng)
    st = p.layer()
    n = 22 if deep else N_TREADS
    stair(st, n=n, dx=6, dy=12, extra=2, wear=not deep, inset=2.4 if deep else 3.0)
    water_plane(st, PLANE_Y + 12, OPEN[0] - 6, OPEN[2] + 6, 0, tilt=tilt)
    motes(st, rng_for(310 + int(deep)), (OPEN[0] + 40, PLANE_Y + 70, OPEN[2] - 40, OPEN[3] - 30), 4)
    p.put(st)
    tint = p.layer()
    tint.rect(OPEN[0], OPEN[1], OPEN[2], OPEN[3], SEA_DEEP, None)
    p.put(tint, 0.16)
    if deep:
        # the treads keep going: a cooler deepening toward the sill, still crisp
        dk = p.layer()
        dk.rect(OPEN[0], 600, OPEN[2], OPEN[3], STORM, None)
        p.put_soft(dk, 60, 0.18)
    gl = p.layer()
    gl.rect(596, OPEN[1], 606, OPEN[3], (255, 255, 255), None)
    p.put_soft(gl, 6, 0.16)
    # the pane's thickness: a bright cool edge 10 px in at each jamb and along the top
    for x, s in ((OPEN[0], 1), (OPEN[2], -1)):
        th = p.layer()
        th.rect(min(x, x + s * 10), OPEN[1], max(x, x + s * 10), OPEN[3], mix(COLD, SEAGLASS_HI, 0.3), None)
        p.put(th, 0.7)
        p.line([(x + s * 10.5, OPEN[1]), (x + s * 10.5, OPEN[3])], rgba(mix(SEA_DEEP, INK, 0.45), 210), 1.6)
    th = p.layer()
    th.rect(OPEN[0], OPEN[1], OPEN[2], OPEN[1] + 10, mix(COLD, SEAGLASS_HI, 0.3), None)
    p.put(th, 0.7)
    p.line([(OPEN[0], OPEN[1] + 10.5), (OPEN[2], OPEN[1] + 10.5)], rgba(mix(SEA_DEEP, INK, 0.45), 210), 1.6)
    clip(p, rect_mask((W, H), [OPEN]))
    return p


def paint_shelves(rng):
    """The vault's archive shelving reflected upside down in the plane: brown boards with their
    brackets standing ABOVE them, file boxes hanging from the boards, each with a clear enamel
    label tab and finger hole at its (reflected) foot. Absolutely still."""
    p = Pen(W, H, rng)
    lay = p.layer()
    x0, x1 = OPEN[0], OPEN[2]
    for j, by in enumerate((576, 664, 752, 840)):
        x = x0 + rng.uniform(-10, 6)
        while x < x1:
            w = rng.uniform(24, 38)
            h = rng.uniform(56, 76)
            if rng.random() < 0.08:
                x += w * 0.7
                continue
            col = mix(PAPER, PAPER_HI, rng.uniform(0, 0.7))
            lay.rect(x, by + 10, x + w - 2, by + 10 + h, col, INK, 2.0)
            lay.rect(x + 4, by + 10 + h - 24, x + w - 6, by + 10 + h - 10, (246, 242, 230), INK, 1.4)
            lay.line([(x + 7, by + 10 + h - 17), (x + w - 9, by + 10 + h - 17)], mix(INK, PAPER, 0.3), 1.2)
            lay.ell(x + w / 2 - 1, by + 10 + h * 0.34, 3.6, 3.6, INK, None)
            x += w
        lay.rect(x0 - 4, by, x1 + 4, by + 10, TIMBER, INK, 2.0)
        lay.line([(x0, by + 7), (x1, by + 7)], TIMBER_HI, 1.2)
        for bx in (x0 + 40, x1 - 40):
            lay.poly([(bx - 7, by), (bx + 7, by), (bx, by - 18)], TIMBER_DK, INK, 1.6)
    p.put(lay, 0.72)
    clip(p, rect_mask((W, H), [(x0, PLANE_Y + 50, x1, OPEN[3])]))
    return p


TIDE_YS = (470, 410, 350, 290, 110)


def tide_breaks(y, cross=False):
    """Wall segments a salt line runs along at height y. `cross`: the late lines run straight
    over the gauge housing and the placard as well (salt_line keeps the dial face and the
    placard's text panel clear)."""
    br = [(-10, 0), (500, 950), (LADDER[0] - 8, LADDER[1] + 8)]
    if y < 125:
        br.append((HATCH[0] - 6, HATCH[2] + 6))
    if not cross and GAUGE_PLATE[1] - 6 <= y <= GAUGE_PLATE[3] + 6:
        br.append((GAUGE_PLATE[0] - 8, GAUGE_PLATE[2] + 8))
    if not cross and PLACARD[1] - 6 <= y <= PLACARD[3] + 6:
        br.append((PLACARD[0] - 8, PLACARD[2] + 8))
    if 530 <= y <= 880:
        br.append((950, 1162))
    br.sort()
    segs, x = [], 0.0
    for a, b in br:
        if a > x + 4:
            segs.append((x, a))
        x = max(x, b)
    if x < W:
        segs.append((x, W + 4))
    return segs


def _salt_clear(x, y):
    """Where crust may not sit: the gauge's enamel face and the placard's text panel."""
    if math.hypot(x - DIAL[0], y - DIAL[1]) < DIAL[2] + 4:
        return True
    if PLACARD[0] + 12 < x < PLACARD[2] - 12 and PLACARD[1] + 12 < y < PLACARD[3] - 12:
        return True
    return False


def salt_line(p, y, k, newest=False):
    """A tide mark: a soft storm-navy damp stain fading DOWN from the line, and on it a broken
    row of fine salt crystals (gaps, clusters, needles). The newest is heavier and darker."""
    rng = rng_for(200 + k)
    cross = k >= 3
    stain_h = 58 if newest else 44
    stain_a = 0.42 if newest else 0.3
    density = 0.92 if newest else 0.66
    crust = mix(SALT, (255, 255, 255), 0.25) if newest else mix(SALT, PLASTER, 0.22)
    segs = tide_breaks(y, cross)
    damp = p.layer()
    for (a, b) in segs:
        for j in range(14):
            t = j / 14.0
            damp.rect(a, y + 1 + stain_h * t, b, y + 1 + stain_h * (t + 1 / 14.0) + 0.6,
                      rgba(STORM, int(255 * (1 - t) ** 1.4)), None)
    p.put_soft(damp, 3, stain_a)
    ph = rng.uniform(0, math.tau)
    for (a, b) in segs:
        x = a + rng.uniform(0, 3)
        while x < b:
            g = math.sin(x / 29.0 + ph) + 0.6 * math.sin(x / 9.3 + 2 * ph) + rng.uniform(-0.7, 0.7)
            step = rng.uniform(1.6, 3.2)
            yy = y + 1.2 * math.sin(x / 61.0 + k) + rng.uniform(-1.2, 1.2)
            if g > (-0.45 if newest else -0.1) and rng.random() < density and not _salt_clear(x, yy):
                r = rng.uniform(1.0, 2.4 if newest else 1.9)
                p.ell(x, yy, r * 1.15, r, crust, None)
                if rng.random() < 0.3:
                    h = rng.uniform(2.5, 6.5 if newest else 4.5)
                    p.line([(x, yy), (x + rng.uniform(-1.6, 1.6), yy - h)], crust, 1.1)
                if rng.random() < 0.18:
                    p.ell(x + rng.uniform(-2, 2), yy + rng.uniform(2, 5), r * 0.6, r * 0.6, crust, None)
                if newest and rng.random() < 0.25:
                    p.ell(x + 0.6, yy + r * 0.7, r * 0.7, r * 0.35, mix(crust, STORM, 0.35), None)
            x += step


def paint_tide(rng, n):
    p = Pen(W, H, rng)
    for k in range(n):
        salt_line(p, TIDE_YS[k], k, newest=(k == n - 1))
    return p


def paint_spill(rng):
    """Band 5+: cold sea-glass light coming UP out of the water, laid on the floor flags in front
    of the gateway as a hard-edged trapezoid."""
    p = Pen(W, H, rng)
    lay = p.layer()
    lay.poly([(OPEN[0] + 4, FLOOR_Y + 14), (OPEN[2] - 4, FLOOR_Y + 14), (OPEN[2] + 120, H + 4), (OPEN[0] - 120, H + 4)],
             mix(SEAGLASS_HI, COLD, 0.25), None)
    p.put(lay, 0.36)
    lay = p.layer()
    lay.poly([(OPEN[0] + 60, FLOOR_Y + 14), (OPEN[2] - 60, FLOOR_Y + 14), (OPEN[2] + 30, H + 4), (OPEN[0] - 30, H + 4)],
             mix(SEAGLASS_HI, COLD, 0.5), None)
    p.put(lay, 0.28)
    p.line([(OPEN[0] - 6, FLOOR_Y + 12), (OPEN[2] + 6, FLOOR_Y + 12)], rgba(COLD, 230), 2.4)
    return p


# ----------------------------------------------------------------------------- L2

def office_cutaway(rng):
    """The Intake Office above, a dollhouse section seen through the clear underside of its
    floor: the approved office's own silhouettes and palette (sage plaster, teal wainscot, the
    window with the lighthouse, the brown 3x2-drawer desk, the brown spindle chair, the coat
    rail and the teal door), under one flat sea-glass wash. No shoes (sprites)."""
    p = Pen(W, H, rng)
    x0, y0, x1, y1 = CUT
    WT = 198
    p.rect(x0, y0, x1, y1, O_PLASTER, None)
    # teal wainscot, boarded, with its cap rail
    p.rect(x0, WT, x1, y1, O_TEAL, None)
    for x in range(int(x0) + 10, int(x1), 16):
        p.line([(x, WT + 6), (x, y1)], O_TEAL_DK, 1.6)
        p.line([(x + 1.8, WT + 6), (x + 1.8, y1)], O_TEAL_HI, 0.8)
    p.rect(x0, WT - 5, x1, WT + 3, O_TEAL_HI, INK, 1.8)
    # stove and its pipe
    p.rect(338, y0 - 4, 352, 226, (52, 60, 68), INK, 1.8)
    for yy in (120, 176):
        p.rect(335, yy, 355, yy + 6, (64, 72, 80), INK, 1.4)
    p.rect(320, 222, 370, 286, (46, 54, 62), INK, 2.2, 10)
    p.rect(332, 236, 358, 266, (36, 42, 50), INK, 1.4, 4)
    for lx in (326, 364):
        p.line([(lx, 284), (lx - (3 if lx < 345 else -3), 300)], INK, 3)
    # the window, lower sash: sky, the headland and its lighthouse, the jetty
    p.rect(392, y0 - 6, 566, 192, O_TEAL, INK, 2.4)
    p.rect(404, y0 - 6, 554, 178, O_SKY, INK, 1.8)
    p.rect(405, 140, 553, 177, O_SEA, None)
    p.poly([(405, 141), (418, 128), (434, 122), (452, 126), (470, 141)], O_HILL, None)
    p.rect(430, 104, 437, 126, (90, 100, 110), INK, 1.0)
    p.rect(428, 99, 439, 105, (60, 70, 80), INK, 1.0)
    p.ell(433.5, 97, 3, 2.4, (60, 70, 80), None)
    for x in range(496, 548, 8):
        p.rect(x, 134, x + 4, 152, O_HILL, None)
    p.rect(494, 134, 550, 138, O_HILL, None)
    p.rect(528, 118, 546, 134, O_HILL, None)
    p.poly([(526, 119), (537, 111), (548, 119)], O_HILL, None)
    p.rect(512, 112, 514, 134, O_HILL, None)
    for y in (150, 158, 166, 172):
        p.line([(410, y), (550, y)], mix(O_SEA, (255, 255, 255), 0.25), 1.0)
    p.rect(384, 186, 574, 196, O_TEAL_HI, INK, 1.8)
    # desk: brown, three drawers in each pedestal, the centre panel, the plinth
    DX0, DX1 = 596, 936
    p.rect(DX0 + 4, 216, DX1 - 4, 294, O_WOOD, INK, 2.2)
    for (a, b) in ((DX0 + 8, DX0 + 86), (DX1 - 86, DX1 - 8)):
        for (c, d) in ((221, 243), (247, 269), (273, 291)):
            p.rect(a, c, b, d, O_WOOD_HI, INK, 1.4)
            p.line([(a + 3, c + 2.5), (b - 3, c + 2.5)], mix(O_WOOD_HI, PAPER, 0.3), 0.9)
    p.rect(DX0 + 92, 221, DX1 - 92, 291, O_WOOD, INK, 1.6)
    p.rect(DX0 + 100, 228, DX1 - 100, 284, None, O_WOOD_DK, 1.4)
    p.rect(DX0, 207, DX1, 217, O_WOOD_HI, INK, 2.2)
    p.line([(DX0 + 3, 209.5), (DX1 - 3, 209.5)], mix(O_WOOD_HI, PAPER, 0.4), 1.0)
    p.rect(DX0 + 2, 292, DX1 - 2, 300, O_WOOD_DK, INK, 1.6)
    # the spindle chair behind it
    for x in (702, 786):
        p.rect(x, 162, x + 7, 207, O_WOOD_DK, INK, 1.4)
    p.rect(698, 156, 797, 168, O_WOOD, INK, 1.6, 4)
    for x in range(716, 784, 13):
        p.rect(x, 168, x + 4, 207, O_WOOD_DK, INK, 1.0)
    # on the desk: the ledger, the clipboards, the mug
    p.rect(640, 197, 700, 207, (38, 48, 60), INK, 1.4)
    for x in (640, 694):
        p.rect(x, 197, x + 6, 207, (140, 84, 50), INK, 1.0)
    p.rect(800, 185, 824, 207, (236, 228, 204), INK, 1.4)
    p.rect(826, 185, 850, 207, (236, 228, 204), INK, 1.4)
    for x in (812, 838):
        p.rect(x - 3, 181, x + 3, 188, BRASS_HI, INK, 1.0)
    p.rect(868, 194, 882, 207, (74, 98, 76), INK, 1.4)
    p.arc(884, 200, 4, 4, 270, 90, INK, 1.6)
    # coat rail with brass hooks, and the teal door with its brass knob
    p.rect(958, 132, 1052, 142, (92, 70, 54), INK, 1.6)
    for x in range(966, 1050, 12):
        p.line([(x, 136), (x, 148), (x + 3, 151)], BRASS_HI, 2.0)
    p.rect(1066, 104, 1150, 300, O_TEAL_HI, INK, 2.2)
    p.rect(1076, 114, 1150, 300, O_TEAL, INK, 1.8)
    p.rect(1090, 128, 1150, 196, None, O_TEAL_DK, 1.6)
    p.rect(1090, 214, 1150, 290, None, O_TEAL_DK, 1.6)
    p.rect(1083, 200, 1091, 222, BRASS, INK, 1.2)
    p.ell(1087, 206, 4, 4, BRASS_HI, INK, 1.0)
    # through water: one flat sea-glass wash
    wash = p.layer()
    wash.rect(x0, y0, x1, y1, SEAGLASS, None)
    p.put(wash, 0.22)
    clip(p, rect_mask((W, H), [CUT]))
    return p


CUT_WASH = (SEAGLASS, 0.22, SEAGLASS, 0.0)


def cut_tint(c, k=1.0):
    c = mix(c, CUT_WASH[0], CUT_WASH[1] * k)
    return mix(c, CUT_WASH[2], CUT_WASH[3] * k)


def slab(p, rng):
    """The office floor seen from below: clear as water, a glassy band with a bright upper
    meniscus, kept in its brass straps; the bell's stirrup bolted under it."""
    y0, y1 = SLAB
    segs = [(300, HOLE[0]), (HOLE[1], W + 4)]
    for a, b in segs:
        g = p.layer()
        g.rect(a, y0, b, y1, SEA_DEEP, None)
        p.put(g, 0.42)
        g = p.layer()
        g.rect(a, y0 + 3, b, y0 + 12, SEA_SAT, None)
        p.put(g, 0.45)
        p.rect(a, y0, b, y0 + 3, (246, 252, 249), None)
        p.line([(a, y1 - 3), (b, y1 - 3)], mix(SEAGLASS_HI, COLD, 0.5), 1.2)
        p.line([(a, y0 + 3.5), (b, y0 + 3.5)], mix(SEA_DEEP, INK, 0.4), 1.0)
        p.line([(a, y1), (b, y1)], INK, 2.6)
    for x in range(360, W, 120):
        if HOLE[0] - 30 < x < HOLE[1] + 10 or abs(x - PIVOT[0]) < 50:
            continue
        p.rect(x - 8, y0 - 3, x + 8, y1 + 3, BRASS, INK, 1.8)
        p.line([(x - 4, y0), (x - 4, y1)], BRASS_HI, 1.2)
        bolt(p, x, y0 + 4, 2.0, BRASS_HI)
        bolt(p, x, y1 - 4, 2.0, BRASS_HI)
    # the section's cut end on the left and the hole's clean edges
    p.line([(300, y0 - 220), (300, y1)], INK, 3.2)
    for xe in HOLE:
        p.line([(xe, y0), (xe, y1)], INK, 2.6)
        p.line([(xe + (3 if xe == HOLE[1] else -3), y0), (xe + (3 if xe == HOLE[1] else -3), y1)], rgba(COLD, 200), 1.4)
    # the bell's stirrup: a brass plate under the slab, two iron straps to the bearing
    px, py = PIVOT
    p.rect(px - 38, y1 - 2, px + 38, y1 + 8, BRASS, INK, 2)
    p.line([(px - 34, y1 + 1), (px + 34, y1 + 1)], BRASS_HI, 1.2)
    for s in (-1, 1):
        p.poly([(px + s * 22, y1 + 6), (px + s * 12, y1 + 6), (px + s * 12, py), (px + s * 22, py)], IRON, INK, 1.8)
        p.line([(px + s * 18, y1 + 8), (px + s * 18, py - 2)], IRON_HI, 1.2)
        bolt(p, px + s * 28, y1 + 3, 2.4, BRASS_HI)
    p.rect(px - 24, py - 9, px + 24, py + 9, IRON, INK, 2)


def return_door(p, rng):
    x0, y0, x1, y1 = 60, 420, 290, 880
    soft_shadow(p, (x0 - 10, y0 - 10, x1 + 10, y1), (6, 6), 8, 0.35)
    p.rect(x0 - 12, y0 - 12, x1 + 12, y1, STEEL_DK, INK, 2.8)
    p.rect(x0, y0, x1, y1, STEEL, INK, 3)
    p.rect(x0 + 14, y0 + 14, x1 - 14, y1 - 14, None, STEEL_HI, 1.6, 4)
    for x in range(x0 + 10, x1 - 4, 22):
        bolt(p, x, y0 + 8, 2.6, STEEL_HI)
        bolt(p, x, y1 - 8, 2.6, STEEL_HI)
    for y in range(y0 + 30, y1 - 20, 22):
        bolt(p, x0 + 8, y, 2.6, STEEL_HI)
        bolt(p, x1 - 8, y, 2.6, STEEL_HI)
    for y in (y0 + 70, y1 - 90):
        p.rect(x0 - 16, y - 10, x0 + 60, y + 10, IRON, INK, 2)
        bolt(p, x0 + 46, y, 2.6)
    # dog handle, right
    p.rect(x1 - 40, 640, x1 - 24, 700, IRON, INK, 2, 4)
    p.ell(x1 - 32, 652, 8, 8, IRON_HI, INK, 1.8)
    # the blank stencil plate (the view writes it)
    p.rect(110, 470, 240, 510, mix(LIMEWASH, STEEL_HI, 0.25), INK, 1.8, 2)
    p.line([(114, 474), (236, 474)], LIMEWASH_HI, 1.2)


def lower_door(p, rng):
    x0, y0, x1, y1 = 600, 450, 880, 880
    p.rect(x0 - 14, y0 - 14, x1 + 14, y1, mix(LIMEWASH_DK, STONE_DK, 0.4), INK, 3)
    p.rect(x0, y0, x1, y1, IRON, INK, 3)
    p.rect(x0 + 10, y0 + 10, x1 - 10, y1 - 10, None, IRON_HI, 1.4, 3)
    for y in (510, 665, 820):
        p.rect(x0 + 4, y - 14, x1 - 4, y + 14, IRON_HI, INK, 2)
        p.line([(x0 + 6, y - 10), (x1 - 6, y - 10)], mix(IRON_HI, STONE, 0.25), 1.2)
        for x in range(x0 + 18, x1 - 8, 26):
            bolt(p, x, y, 2.8, mix(IRON_HI, STONE, 0.2))
    p.rect(840, 640, 870, 700, IRON_HI, INK, 2)
    p.rect(848, 660, 862, 680, (12, 18, 22), INK, 1.4)
    bolt(p, 855, 648, 2.2)
    bolt(p, 855, 692, 2.2)
    # the hairline hinge on the doorway's left jamb: it must look ordinary
    for y in (500, 660, 820):
        p.line([(x0 - 1, y - 18), (x0 - 1, y + 18)], mix(INK, IRON_HI, 0.3), 1.0)
        p.line([(x0 - 4, y - 18), (x0 + 2, y - 18)], mix(INK, IRON_HI, 0.3), 1.0)
        p.line([(x0 - 4, y + 18), (x0 + 2, y + 18)], mix(INK, IRON_HI, 0.3), 1.0)


def reader_panel(p, rng):
    x0, y0, x1, y1 = 900, 440, 1110, 860
    soft_shadow(p, (x0, y0, x1, y1), (6, 8), 8, 0.4, 6)
    p.rect(x0, y0, x1, y1, IRON, INK, 3, 6)
    p.rect(x0 + 6, y0 + 6, x1 - 6, y1 - 6, None, BRASS_LO, 1.6, 4)
    for (a, b) in ((450, 546), (560, 656), (670, 766)):
        p.rect(921, a - 4, 1049, b + 4, BRASS, INK, 2, 2)
        p.rect(925, a, 1045, b, mix(GLASS_DK, SEAGLASS, 0.3), INK, 1.6)
        p.poly([(940, b - 6), (964, a + 6), (976, a + 6), (952, b - 6)], mix(SEAGLASS_HI, GLASS_DK, 0.45), None)
        for x in (950, 1020):
            p.rect(x - 5, a - 7, x + 5, a + 3, BRASS_HI, INK, 1.2)
            p.rect(x - 5, b - 3, x + 5, b + 7, BRASS_HI, INK, 1.2)
    # witness socket: a blank brass plate with a dark socket hole
    cx, cy = 955, 815
    p.ell(cx + 2, cy + 3, 30, 30, (10, 16, 20), None)
    p.ell(cx, cy, 30, 30, BRASS, INK, 2.2)
    p.ell(cx, cy, 25, 25, None, BRASS_HI, 1.2)
    p.ell(cx, cy, 8, 8, (8, 12, 16), INK, 1.6)
    # COPY port: a sprung slot with a blank stamp plate above it, the shutter hinged up
    qx, qy = 1015, 785
    p.rect(qx + 6, 770, qx + 54, 781, ENAMEL, INK, 1.4, 1)
    p.rect(qx - 3, qy - 3, qx + 63, qy + 63, BRASS_LO, INK, 2)
    p.rect(qx, qy, qx + 60, qy + 60, (8, 12, 16), INK, 1.8)
    p.line([(qx + 2, qy + 58), (qx + 58, qy + 58)], BRASS_HI, 1.6)
    p.line([(qx + 58, qy + 2), (qx + 58, qy + 58)], BRASS_HI, 1.2)
    p.line([(qx + 4, qy + 6), (qx + 56, qy + 6)], IRON_HI, 1.0)
    # OPEN ACCESS lever slot
    p.rect(1084, 600, 1104, 780, (10, 16, 20), INK, 2, 9)
    p.line([(1088, 606), (1088, 774)], IRON, 1.4)


def upper_stair(p, rng):
    """A short open flight rising to the right in side elevation, up through the hole in the
    office floor: limewash treads, darker risers, a navy stringer, a storm shadow under the
    flight, and the white light from the top laid on the wall as a hard flat trapezoid."""
    # the shaft above the hole: pale light-filled
    p.rect(HOLE[0] - 10, -4, HOLE[1] + 10, SLAB[0], mix(COLD, STONE_HI, 0.35), None)
    lit = p.layer()
    lit.rect(HOLE[0] + 20, -4, HOLE[1] - 10, SLAB[0], (255, 255, 255), None)
    p.put_soft(lit, 20, 0.6)
    p.line([(HOLE[0] - 10, -4), (HOLE[0] - 10, SLAB[0])], INK, 3)
    p.line([(HOLE[1] + 10, -4), (HOLE[1] + 10, SLAB[0])], INK, 3)
    n = 12
    xa, ya, xb, yb = 1140, FLOOR_Y, 1390, SLAB[1]
    run, rise = (xb - xa) / n, (ya - yb) / n
    # the light from the top, hard-edged on the wall
    lt = p.layer()
    lt.poly([(HOLE[0] + 4, SLAB[1]), (HOLE[1] - 4, SLAB[1]), (1350, 640), (1150, 560)], (250, 252, 248), None)
    p.put(lt, 0.62)
    # the shadow under the flight
    sh = p.layer()
    sh.poly([(xa + 30, ya), (xb + 10, yb + 70), (xb + 10, ya)], STORM, None)
    p.put(sh, 0.38)
    # the steps
    for i in range(n):
        tx, ty = xa + i * run, ya - (i + 1) * rise
        p.rect(tx, ty, tx + run + 1, ty + rise, LIMEWASH_DK, None)
        p.rect(tx, ty, tx + 5, ty + rise, mix(LIMEWASH_DK, INK, 0.18), None)
        p.rect(tx - 2, ty, tx + run + 1, ty + 9, LIMEWASH_HI, None)
        p.line([(tx - 2, ty), (tx + run + 1, ty)], INK, 2.0)
        p.line([(tx, ty), (tx, ty + rise)], INK, 1.6)
        p.line([(tx, ty + 9), (tx + run, ty + 9)], mix(LIMEWASH_DK, INK, 0.35), 1.0)
    # the stringer
    T = 46
    st = [(xa - 6, ya + 2), (xb + 10, yb + rise * 0.6), (xb + 10, yb + rise * 0.6 + T), (xa + 14, ya + 2)]
    p.poly(st, STORM, INK, 2.4)
    p.line([(xa, ya - 3), (xb + 8, yb + rise * 0.6 + 4)], STORM_HI, 1.6)
    p.line([(xb + 10, yb), (xb + 10, yb + rise * 0.6 + T)], INK, 2.4)
    p.line([(xb, yb), (xb + 10, yb)], INK, 2.4)


def paint_L2_base(rng):
    p = Pen(W, H, rng, PLASTER)
    stone_wall(p, rng, (-4, -4, W + 4, DADO_Y), PLASTER, 96, 0, skip=[(10, 120, 96, 360)], mottle=0.18, joints=0.4)
    return _l2_after_wall(p, rng)


def _l2_after_wall(p, rng):
    """Everything on the lower landing after its wall (b6_wash lays its wash between)."""
    dado(p, rng)
    # stone section above the cutaway
    p.rect(300, -4, W + 4, CUT[1], CEIL_ST, None)
    hl = p.layer()
    x = 260
    while x < W + 40:
        hl.line([(x, CUT[1]), (x + 60, -4)], INK, 1.4)
        x += 16
    p.put(hl, 0.4, rect_mask((W, H), [(300, -4, W + 4, CUT[1])]))
    p.line([(300, CUT[1]), (W + 4, CUT[1])], INK, 3)
    p.rect(CUT[2], CUT[1], W + 4, SLAB[0], mix(CEIL_ST, STONE, 0.25), None)
    hl = p.layer()
    x = CUT[2] - 60
    while x < W + 40:
        hl.line([(x, SLAB[0]), (x + 60, CUT[1])], INK, 1.4)
        x += 16
    p.put(hl, 0.35, rect_mask((W, H), [(CUT[2], CUT[1], W + 4, SLAB[0])]))
    p.put(office_cutaway(rng))
    p.line([(CUT[0], CUT[1]), (CUT[0], SLAB[0])], INK, 3)
    p.line([(CUT[2], CUT[1]), (CUT[2], SLAB[0])], INK, 3)
    upper_stair(p, rng)
    slab(p, rng)
    return_door(p, rng)
    lower_door(p, rng)
    reader_panel(p, rng)
    bulkhead_lamp(p, 1005, 392)
    floor_flags(p, rng)
    return p


# ----------------------------------------------------------------------------- L2 sprites

def bell_shape():
    """Bell profile in local coords: crown at (0,0), axis down +y, mouth at y 110."""
    right = [(0, -10), (10, -9), (18, -6), (24, -1), (28, 6), (29, 16), (28, 30), (28, 46), (30, 60), (34, 72),
             (40, 82), (48, 92), (56, 100), (60, 106), (60, 112)]
    left = [(-x, y) for x, y in right[::-1]]
    return right + left


def paint_bell(rng, ang):
    """The clapperless bell frozen mid-swing in its stirrup: crown up in an end-on timber yoke
    on the bearing, the body swung `ang` degrees. The mouth is a flat black ellipse with only
    an empty clapper staple and a broken stub in it."""
    p = Pen(W, H, rng)
    c = PIVOT
    T = lambda q: rot((q[0] + c[0], q[1] + c[1] + 14), c, ang)
    sh = p.layer()
    sh.poly([(q[0] + 6, q[1] + 8) for q in map(T, bell_shape())], (10, 16, 22), None)
    p.put_soft(sh, 7, 0.4)
    p.poly([T(q) for q in bell_shape()], BRONZE, None)
    # a hard flat highlight and a shadow side, matte
    p.poly([T(q) for q in ((-15, -6), (-8, -7), (-10, 60), (-18, 96), (-40, 98), (-28, 70), (-22, 30))], BRONZE_HI, None)
    p.poly([T(q) for q in ((18, -5), (26, 4), (24, 40), (30, 66), (50, 96), (36, 98), (20, 60))], BRONZE_DK, None)
    p.line([T((-28, 18)), T((28, 18))], BRONZE_DK, 2.4)
    p.line([T((-28, 23)), T((28, 23))], BRONZE_DK, 1.4)
    p.line([T((-54, 100)), T((54, 100))], BRONZE_DK, 2.8)
    p.line([T((-57, 104)), T((57, 104))], BRONZE_HI, 1.6)
    p.poly([T(q) for q in bell_shape()], None, INK, 3.2)
    # the mouth: a flat black ellipse, a bronze lip
    mouth = [T((60 * math.cos(t), 112 + 20 * math.sin(t))) for t in (math.tau * i / 56 for i in range(56))]
    p.poly(mouth, (6, 8, 10), INK, 3)
    lip = [T((60 * math.cos(t), 112 + 20 * math.sin(t))) for t in (math.pi * i / 28 for i in range(29))]
    p.line(lip, BRONZE_HI, 1.4)
    # far inside: the empty staple and the stub of the clapper's shank, broken short
    dark = (36, 40, 42)
    st = [T((-6, 113)), T((-6, 106)), T((0, 102)), T((6, 106)), T((6, 113))]
    p.line(st, dark, 2.6)
    stub = [T((-2.2, 106)), T((2.2, 106)), T((2.6, 113)), T((0.6, 111)), T((-0.6, 114)), T((-2.6, 111))]
    p.poly(stub, mix(dark, BRONZE, 0.3), None)
    # crown straps up into the yoke
    for s in (-1, 1):
        p.poly([T((s * 7, -4)), T((s * 14, -4)), T((s * 14, 14)), T((s * 7, 14))], IRON, INK, 1.6)
        bolt(p, *T((s * 10.5, 8)), 1.8)
    # the yoke, end-on: a timber block on the bearing, banded in iron
    yk = [T(q) for q in ((-18, -27), (18, -27), (18, -3), (-18, -3))]
    p.poly(yk, TIMBER, INK, 2.2)
    p.line([T((-15, -24)), T((15, -24))], TIMBER_HI, 1.4)
    p.line([T((-18, -9)), T((18, -9))], IRON, 3.0)
    p.ell(PIVOT[0], PIVOT[1], 8, 8, IRON_HI, INK, 1.8)
    p.ell(PIVOT[0], PIVOT[1], 3, 3, IRON_LO, None)
    return p


SHOE_K = 1.6


def shoe_profile(x, y, scale=1.0):
    """A black laced shoe in profile, toes left, sole on y. Returns (upper, sole, collar, laces)."""
    s = scale
    up = [(0, 0), (1, -7), (6, -12), (16, -15), (30, -19), (38, -26), (44, -27), (56, -26), (60, -20), (61, -8), (61, 0)]
    up = [(x + a * s, y + b * s) for a, b in up]
    sole = [(x - 1 * s, y), (x + 62 * s, y), (x + 62 * s, y + 4 * s), (x + 1 * s, y + 4 * s)]
    collar = [(x + 38 * s, y - 25 * s), (x + 55 * s, y - 25 * s)]
    laces = [((x + (20 + 5 * i) * s, y - (16 + 1.6 * i) * s), (x + (24 + 5 * i) * s, y - (13 + 1.6 * i) * s)) for i in range(3)]
    return up, sole, collar, laces


def draw_shoe(p, x, y, body, sheen=None, k=SHOE_K):
    up, sole, collar, laces = shoe_profile(x, y - 4 * k, k)
    p.poly(sole, mix(body, PAPER, 0.25), INK, 1.8)
    p.poly(up, body, INK, 2.6)
    p.line(collar, (6, 8, 10), 4.4)
    for a, b in laces:
        p.line([a, b], mix(body, PAPER, 0.45), 1.8)
    if sheen:
        p.line([up[2], up[3], up[4]], sheen, 2.2)
        p.line([(up[8][0] - 2, up[8][1] + 3), (up[9][0] - 2, up[9][1] + 2)], sheen, 1.8)


def fallen(p, x, y, body, sheen, k=SHOE_K):
    """The right shoe fallen on its side: a low shape, the sole edge turned up, the opening toward us."""
    Q = lambda pts: [(x + a * k, y + b * k) for a, b in pts]
    p.poly(Q([(0, 0), (2, -8), (10, -14), (30, -16), (46, -20), (58, -18), (62, -8), (62, 0)]), body, INK, 2.6)
    p.poly(Q([(4, -9), (12, -14), (46, -19), (58, -17), (58, -13), (44, -15), (12, -10)]), mix(body, PAPER, 0.3), INK, 1.6)
    p.ell(x + 40 * k, y - 6 * k, 12 * k, 5 * k, (6, 8, 10), INK, 1.6)
    p.line(Q([(30, -4), (22, 0.5), (14, 0.5)]), mix(body, PAPER, 0.45), 1.6)
    if sheen:
        p.line(Q([(10, -12), (30, -14)]), sheen, 2.0)


def front_shoe(p, cx, y, body, sheen, k=1.35 * SHOE_K):
    """A shoe toe-on: rounded toe cap, the tongue and laces above, the sole band."""
    w = 15 * k
    cap = []
    for i in range(25):
        t = math.pi * i / 24
        cap.append((cx - w * math.cos(t), y - 4 * k - 12 * k * math.sin(t)))
    p.poly([(cx - w - 1, y + 1), (cx + w + 1, y + 1), (cx + w + 1, y - 4 * k), (cx - w - 1, y - 4 * k)], mix(body, PAPER, 0.25), INK, 1.8)
    p.poly([(cx - 11 * k, y - 12 * k), (cx - 8 * k, y - 30 * k), (cx + 8 * k, y - 30 * k), (cx + 11 * k, y - 12 * k)], body, INK, 2.2)
    p.ell(cx, y - 30 * k, 8 * k, 3 * k, (6, 8, 10), INK, 1.4)
    p.poly(cap + [(cx + w, y - 4 * k)], body, INK, 2.4)
    for j in range(3):
        yy = y - (17 + j * 4) * k
        p.line([(cx - 6 * k, yy), (cx + 6 * k, yy)], mix(body, PAPER, 0.5), 1.8)
    if sheen:
        p.arc(cx, y - 4 * k, w - 6, 9 * k, 200, 260, sheen, 2.2)


def sole_print(p, x, y, L, col, a, front=False, w=0.0):
    """A sole pressed flat on the clear floor, seen from below through it (toes left)."""
    lay = p.layer()
    if front:
        lay.rect(x - w, y - 4, x + w, y + 4, col, None, 0, 4)
    else:
        lay.ell(x + L * 0.3, y, L * 0.3, 4.6, col, None)
        lay.ell(x + L * 0.82, y, L * 0.17, 4.0, col, None)
        lay.rect(x + L * 0.5, y - 2.2, x + L * 0.72, y + 2.2, col, None)
    p.put(lay, a)


def paint_shoes(rng, state):
    """Nora's empty shoes on the office floor in front of the desk, 1.6x, their soles pressed
    flat on the clear floor below them. Wet: a sea-glass puddle along the floor and drops that
    hang UPWARD from it. Facing: toe-on to us, and wet prints going off to the stair."""
    p = Pen(W, H, rng)
    fy = SLAB[0]
    dry = cut_tint(SOOT, 0.55)
    wet = mix(cut_tint(SOOT, 0.25), INK, 0.35)
    sheen = mix(SEAGLASS_HI, COLD, 0.6)
    sole_c = (12, 18, 24)
    if state in ("wet", "facing"):
        pud = p.layer()
        pud.poly([(664, fy), (690, fy - 4), (900, fy - 5), (972, fy - 2), (980, fy)], SEA_SAT, None)
        p.put(pud, 0.9)
        p.line([(690, fy - 4.5), (900, fy - 5.5)], rgba(COLD, 230), 1.6)
    def drops(xs):
        for i, x in enumerate(xs):
            h = 12 + 5 * (i % 2)
            p.poly([(x - 1.6, fy - 2), (x + 1.6, fy - 2), (x + 3.6, fy - h + 2), (x, fy - h - 5), (x - 3.6, fy - h + 2)],
                   SEA_SAT, INK, 1.1)
            p.ell(x, fy - h, 4.4, 4.4, SEA_SAT, INK, 1.1)
            p.ell(x - 1.4, fy - h - 1.4, 1.4, 1.4, COLD, None)
    if state == "dry":
        sole_print(p, 700, fy + 8, 62 * SHOE_K, sole_c, 0.85)
        sole_print(p, 806, fy + 8, 62 * SHOE_K, sole_c, 0.35, True, 46)
        draw_shoe(p, 700, fy, dry)
        fallen(p, 806, fy, dry, None)
    elif state == "wet":
        sole_print(p, 700, fy + 8, 62 * SHOE_K, sole_c, 0.9)
        sole_print(p, 806, fy + 8, 62 * SHOE_K, sole_c, 0.4, True, 46)
        draw_shoe(p, 700, fy, wet, sheen)
        fallen(p, 806, fy, wet, sheen)
        drops((676, 918, 944, 968))
    else:
        for cx in (736, 818):
            sole_print(p, cx, fy + 8, 0, sole_c, 0.9, True, 30)
        # two faint wet prints, then two more, going off toward the stair hole
        for j, x in enumerate((900, 980, 1062, 1146, 1222)):
            sole_print(p, x, fy + (6 if j % 2 else 12), 26, mix(SEA_DEEP, INK, 0.5), 0.55 - 0.06 * j)
        for cx in (736, 818):
            front_shoe(p, cx, fy, wet, sheen)
        drops((684, 777, 874, 944))
    return p


def paint_door_open(rng):
    """The lower door open: its doorway (the dark stair down, a cold glow at the foot) and the
    leaf folded back to the left on its hinge, showing its never-seen inner face: pale
    limewashed enamel, stiffeners, bolts; a dark hinge gap between leaf and frame."""
    p = Pen(W, H, rng)
    x0, y0, x1, y1 = 600, 450, 880, 880
    p.rect(x0, y0, x1, y1, (14, 20, 26), INK, 3)
    n = 9
    pitch = (y1 - y0) / n
    for i in range(n):
        a = y0 + i * pitch
        glow = max(0.0, 1.0 - abs(a + pitch - 845) / 160.0)
        base = mix((22, 30, 38), STORM_HI, min(1, 0.15 + 0.5 * glow + 0.35 * max(0, 1 - (a - y0) / 120)))
        p.rect(x0 + 4, a, x1 - 4, a + pitch, base, None)
        p.rect(x0 + 4, a, x1 - 4, a + pitch * 0.2, mix(base, LIMEWASH, 0.18 + 0.3 * glow), None)
        p.line([(x0 + 4, a), (x1 - 4, a)], INK, 2)
    gl = p.layer()
    gl.ell(740, 846, 120, 22, mix(PAPER_HI, COLD, 0.5), None)
    p.put_soft(gl, 16, 0.6)
    p.rect(x0, y0, x1, y1, None, INK, 3)
    # the hinge gap
    p.rect(594, y0, 600, y1, (8, 12, 16), None)
    # the leaf
    lx0, lx1 = 314, 594
    soft_shadow(p, (lx0, y0, lx1, y1), (-6, 6), 8, 0.4)
    face = mix(LIMEWASH, ENAMEL, 0.5)
    p.rect(lx0, y0, lx1, y1, face, INK, 3)
    lay = p.layer()
    for _ in range(30):
        lay.ell(rng.uniform(lx0, lx1), rng.uniform(y0, y1), rng.uniform(14, 44), rng.uniform(10, 30),
                LIMEWASH_DK if rng.random() < 0.6 else LIMEWASH_HI, None)
    p.put_soft(lay, 12, 0.3, rect_mask((W, H), [(lx0, y0, lx1, y1)]))
    for y in (510, 665, 820):
        p.rect(lx0 + 10, y - 10, lx1 - 8, y + 10, LIMEWASH_DK, INK, 2)
        p.line([(lx0 + 12, y - 7), (lx1 - 10, y - 7)], LIMEWASH_HI, 1.2)
        for x in range(lx0 + 22, lx1 - 10, 26):
            bolt(p, x, y, 3.0, mix(LIMEWASH_DK, IRON_HI, 0.35))
    for y in range(y0 + 16, y1 - 8, 30):
        bolt(p, lx0 + 14, y, 2.6, mix(LIMEWASH_DK, IRON_HI, 0.35))
    # the free edge: the door's thickness, its navy outer skin showing
    p.rect(lx0, y0, lx0 + 8, y1, IRON, INK, 2)
    return p


def paint_finger_marks(rng):
    """On the inner face: about 35 dark, greasy hands. Each is four rounded fingertip pads and
    their downward drags (some with a palm heel), ~44 px across, crowded in a band at seated
    reach in the lower third; a few higher and fainter; none at standing height."""
    p = Pen(W, H, rng)
    lx0, lx1, y0, y1 = 322, 590, 450, 880
    col = mix(INK, STORM, 0.45)
    hands = []
    for j in range(27):
        col_i, row_i = j % 9, j // 9
        hands.append((lx0 + 8 + (col_i + rng.uniform(0.0, 0.9)) * (lx1 - lx0 - 60) / 9.0,
                      736 + (row_i + rng.uniform(0.0, 0.9)) * 36, rng.uniform(0.55, 0.7)))
    for _ in range(6):
        hands.append((rng.uniform(lx0 + 8, lx1 - 52), rng.uniform(630, 735), rng.uniform(0.32, 0.48)))
    for _ in range(2):
        hands.append((rng.uniform(lx0 + 30, lx1 - 80), rng.uniform(520, 610), rng.uniform(0.14, 0.22)))
    for (x, y, a) in hands:
        lay = p.layer()
        left = rng.random() < 0.5
        tilt = rng.uniform(-0.22, 0.22)
        heights = (-3, -7, -6, 0) if left else (0, -6, -7, -3)
        c = (x + 17, y)
        for f in range(4):
            fx, fy = x + f * 11.5, y + heights[f]
            L = rng.uniform(30, 60)
            q = lambda px, py: rot((px, py), c, math.degrees(tilt))
            steps = 10
            for s in range(steps):
                t0, t1 = s / steps, (s + 1) / steps
                wd = lerp(8.4, 2.2, t1)
                pa, pb = q(fx, fy + L * t0), q(fx + 1.2 * t1, fy + L * t1)
                lay.line([pa, pb], rgba(col, int(255 * (1 - 0.72 * t1))), wd)
            px, py = q(fx, fy)
            lay.ell(px, py, 4.8, 5.8, rgba(col, 255), None)
        if rng.random() < 0.45:
            hx, hy = rot((x + 17 + (6 if left else -6), y + 40), c, math.degrees(tilt))
            lay.ell(hx, hy, 15, 9, rgba(col, 230), None)
            for s in range(6):
                t = (s + 1) / 6
                lay.line([(hx - 8, hy + 4 + 18 * (t - 1 / 6)), (hx + 8, hy + 4 + 18 * t)], rgba(col, int(160 * (1 - t))), 6)
        p.put(lay, a)
    clip(p, rect_mask((W, H), [(lx0, y0, lx1, y1)]))
    return p


# ----------------------------------------------------------------------------- the P12 cut

PANE = (300, 80, 1150, 1000)


def paint_cut_glass(rng):
    """The P12 cut: the water standing on end in the gateway, seen face on. A deep sea-glass
    slab with the stair continuing behind it, dimmer and offset; a bright thickness edge at
    both jambs and along the top and foot; still motes hanging in it."""
    p = Pen(W, H, rng, STONE_DK)
    stone_wall(p, rng, (-4, -4, W + 4, H + 4), STONE_DK, 140, 0)
    x0, y0, x1, y1 = PANE
    for a, b in ((160, x0), (x1, 1290)):
        p.rect(a, -4, b, H + 4, LIMEWASH, None)
        for y in (220, 480, 760):
            p.line([(a, y), (b, y)], mix(LIMEWASH_DK, SEAGLASS, 0.35), 2.4)
        p.line([(a + 5, -4), (a + 5, H + 4)], LIMEWASH_HI, 2)
        p.line([(b - 5, -4), (b - 5, H + 4)], LIMEWASH_DK, 2.6)
        p.line([(a, -4), (a, H + 4)], INK, 3.4)
        p.line([(b, -4), (b, H + 4)], INK, 3.4)
    p.rect(160, -4, 1290, y0, LIMEWASH, None)
    p.line([(160, y0 - 6), (1290, y0 - 6)], LIMEWASH_DK, 2.6)
    p.line([(160, y0), (1290, y0)], INK, 3.4)
    p.rect(160, y1, 1290, H + 4, LIMEWASH_DK, None)
    p.line([(160, y1 + 6), (1290, y1 + 6)], LIMEWASH_HI, 2)
    # behind the water: the stair going on down, dimmer and offset
    st = p.layer()
    stair(st, n=12, dx=22, dy=36, box=(x0, y0, x1, y1), plane=-1, tint=0.75, extra=2, inset=6.0, refr=0.0, dim=0.18)
    clip(st, rect_mask((W, H), [PANE]))
    p.put(st)
    # the slab itself: deep, saturated sea-glass, matte
    sl = p.layer()
    sl.rect(x0, y0, x1, y1, SEA_DEEP, None)
    p.put(sl, 0.5)
    dk = p.layer()
    dk.rect(x0, y0 + 420, x1, y1, STORM, None)
    p.put_soft(dk, 90, 0.28, rect_mask((W, H), [PANE]))
    mo = p.layer()
    motes(mo, rng_for(320), (x0 + 60, y0 + 60, x1 - 60, y1 - 60), 7)
    p.put(mo, 0.9)
    # its thickness: a bright edge at each jamb, the top and the foot, a darker side face inside
    for x, s in ((x0, 1), (x1, -1)):
        e = p.layer()
        e.rect(min(x, x + s * 16), y0, max(x, x + s * 16), y1, mix(COLD, SEAGLASS_HI, 0.2), None)
        p.put(e, 0.9)
        e = p.layer()
        e.rect(min(x + s * 16, x + s * 30), y0, max(x + s * 16, x + s * 30), y1, SEA_DEEP, None)
        p.put(e, 0.55)
        p.line([(x + s * 16.5, y0), (x + s * 16.5, y1)], rgba(mix(SEA_DEEP, INK, 0.5), 230), 1.8)
        p.line([(x + s * 4, y0), (x + s * 4, y1)], (255, 255, 255, 255), 2.4)
    for y, s in ((y0, 1), (y1, -1)):
        e = p.layer()
        e.rect(x0, min(y, y + s * 14), x1, max(y, y + s * 14), mix(COLD, SEAGLASS_HI, 0.2), None)
        p.put(e, 0.85)
        p.line([(x0, y + s * 14.5), (x1, y + s * 14.5)], rgba(mix(SEA_DEEP, INK, 0.5), 220), 1.6)
    p.rect(x0, y0, x1, y1, None, INK, 3.4)
    return p


def hand_polys(dx=0.0):
    """Ada's right hand and cuff in stark silhouette, reaching right; fingertips at x 640 + dx.
    The sleeve tapers from the shoulder to the cuff and has one fold notch underneath."""
    S = lambda pts: [(x + dx, y) for x, y in pts]
    sleeve = [(-60, 430)] + S([(120, 456), (220, 478), (300, 500), (304, 618), (236, 632), (192, 640), (182, 627),
                                (170, 648), (80, 668)]) + [(-60, 700)]
    cuff = S([(298, 500), (352, 509), (352, 609), (300, 620)])
    palm = S([(348, 516), (420, 506), (500, 500), (512, 540), (508, 586), (470, 600), (420, 606), (350, 606)])
    fingers = [
        S([(492, 500), (560, 506), (612, 516), (636, 524), (641, 531), (636, 538), (608, 536), (556, 530), (494, 528)]),
        S([(496, 528), (560, 532), (614, 540), (636, 547), (640, 553), (634, 559), (606, 557), (556, 552), (498, 552)]),
        S([(498, 552), (556, 556), (604, 563), (626, 570), (628, 577), (620, 581), (596, 579), (552, 575), (500, 574)]),
        S([(498, 573), (548, 578), (586, 586), (602, 592), (602, 599), (594, 602), (572, 600), (540, 596), (496, 592)]),
    ]
    thumb = S([(420, 520), (470, 494), (520, 478), (548, 476), (554, 484), (544, 492), (510, 506), (470, 528)])
    return sleeve, cuff, palm, fingers, thumb


def draw_hand(p, dx, col, rim):
    sleeve, cuff, palm, fingers, thumb = hand_polys(dx)
    p.poly(sleeve, col, None)
    p.poly(palm, col, None)
    p.poly(thumb, col, None)
    for f in fingers:
        p.poly(f, col, None)
    p.poly(cuff, mix(col, STORM_HI, 0.35), None)
    # rim light along the top: just enough to separate the silhouette's parts
    p.line(sleeve[:4], rim, 1.8)
    p.line([sleeve[7], (sleeve[7][0] - 46, sleeve[7][1] - 22)], mix(col, rim, 0.5), 1.6)
    p.line(cuff[:2], rim, 1.4)
    p.line(thumb[:4], rim, 1.4)
    for f in fingers:
        p.line(f[:5], rim, 1.2)
    for f in fingers:
        p.line(f[4:], INK, 1.2)


def paint_hand(rng, through):
    p = Pen(W, H, rng)
    if not through:
        draw_hand(p, 0.0, INK, mix(INK, COLD, 0.35))
        tip = (641, 531)
        for r, a in ((14, 230), (26, 150), (38, 80)):
            p.ell(tip[0], tip[1] + 14, r * 0.42, r, None, rgba(COLD, a), 2.0)
        return p
    dx = 290.0
    before = p.layer()
    draw_hand(before, dx, mix(INK, SEAGLASS, 0.5), mix(SEAGLASS, COLD, 0.4))
    clip(before, rect_mask((W, H), [(-10, 0, 640, H)]))
    beyond = p.layer()
    draw_hand(beyond, dx, INK, mix(INK, COLD, 0.45))
    clip(beyond, rect_mask((W, H), [(640, 0, W, H)]))
    p.put(before)
    p.put(beyond)
    for rx, ry, a, w in ((8, 60, 235, 2.4), (16, 74, 150, 1.8), (25, 88, 80, 1.4)):
        p.ell(640, 556, rx, ry, None, rgba(COLD, a), w)
    return p


# ----------------------------------------------------------------------------- sight-port views

def port_finish(p, size=384, r=190):
    im = p.done()
    vig = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse((size / 2 - r, size / 2 - r, size / 2 + r, size / 2 + r), fill=255)
    ring = Image.new("L", (size, size), 0)
    ImageDraw.Draw(ring).ellipse((size / 2 - r, size / 2 - r, size / 2 + r, size / 2 + r), outline=255, width=26)
    ring = ring.filter(ImageFilter.GaussianBlur(14))
    dark = Image.new("RGBA", (size, size), (10, 16, 22, 255))
    dark.putalpha(ring.point(lambda v: int(v * 0.7)))
    im.alpha_composite(dark)
    big = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(big).ellipse(((size / 2 - r) * 4, (size / 2 - r) * 4, (size / 2 + r) * 4, (size / 2 + r) * 4), fill=255)
    m = big.resize((size, size), Image.LANCZOS)
    im.putalpha(ImageChops.multiply(im.getchannel("A"), m))
    return im


def paint_port_false(rng):
    S = 384
    p = Pen(S, S, rng, (14, 20, 26))
    for a, b in ((0, 92), (292, S)):
        p.rect(a, 0, b, S, mix(LIMEWASH_DK, SEAGLASS, 0.35), None)
        p.line([(b if a == 0 else a, 0), (b if a == 0 else a, S)], INK, 3)
    st = p.layer()
    stair(st, n=6, box=(92, 0, 292, 186), plane=999, extra=0, wear=False)
    p.put(st)
    cool = p.layer()
    cool.rect(92, 0, 292, 186, SEAGLASS, None)
    p.put(cool, 0.18)
    # the short landing
    p.rect(92, 186, 292, 224, mix(LIMEWASH_DK, SEAGLASS, 0.3), None)
    p.line([(92, 186), (292, 186)], INK, 2.4)
    p.line([(92, 190), (292, 190)], LIMEWASH_HI, 1.2)
    # it ends in a vertical wall of dark standing water: still, edge-on surface lines
    p.rect(92, 224, 292, S, (16, 28, 36), None)
    p.line([(92, 224), (292, 224)], (226, 236, 232), 2.6)
    for k, y in enumerate(range(240, S, 18)):
        c = mix((16, 28, 36), SEAGLASS, max(0.06, 0.32 - 0.03 * k))
        p.line([(96, y), (288, y)], c, 1.2)
    p.line([(92, 226), (292, 226)], INK, 1.2)
    p.line([(92, 0), (92, S)], INK, 3)
    p.line([(292, 0), (292, S)], INK, 3)
    # 1.3x into the iris, about the landing's foot, so the wall of water reads at room scale
    big = p.im.resize((int(S * SS * 1.3), int(S * SS * 1.3)), Image.LANCZOS)
    cx, cy = big.size[0] // 2, int(236 * SS * 1.3)
    p.im = big.crop((cx - S * SS // 2, cy - S * SS // 2, cx + S * SS // 2, cy + S * SS // 2))
    p.d = ImageDraw.Draw(p.im)
    return port_finish(p)


def paint_port_true(rng):
    base = paint_L2_base(rng_for(20)).done()
    # a glimpse, not a survey: the bell is brought in over the doorway so both fit the port
    base.alpha_composite(paint_bell(rng_for(21), 35).done(), (250, 60))
    crop = base.crop((420, 230, 1140, 950)).resize((384, 384), Image.LANCZOS)
    cool = Image.new("RGBA", crop.size, rgba(STORM))
    crop = Image.blend(crop, cool, 0.18)
    p = Pen(384, 384, rng)
    p.im = crop.resize((384 * SS, 384 * SS), Image.LANCZOS)
    p.d = ImageDraw.Draw(p.im)
    return port_finish(p)


# ----------------------------------------------------------------------------- close-up c_gate

def iron_face(p, rng, seams_x=(), seam_y=None):
    p.rect(-4, -4, W + 4, H + 4, FACE, None)
    lay = p.layer()
    for _ in range(30):
        lay.ell(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(80, 200), rng.uniform(40, 120), FACE_DK if rng.random() < 0.6 else FACE_HI, None)
    p.put_soft(lay, 40, 0.3)
    for x in seams_x:
        p.line([(x, -4), (x, H + 4)], FACE_DK, 3)
        p.line([(x + 3, -4), (x + 3, H + 4)], FACE_HI, 1.4)
        for y in range(20, H, 44):
            bolt(p, x - 14, y, 4, FACE_HI)
            bolt(p, x + 17, y, 4, FACE_HI)
    if seam_y:
        p.line([(-4, seam_y), (W + 4, seam_y)], FACE_DK, 3)
        p.line([(-4, seam_y + 3), (W + 4, seam_y + 3)], FACE_HI, 1.4)
        for x in range(20, W, 44):
            bolt(p, x, seam_y - 14, 4, FACE_HI)
            bolt(p, x, seam_y + 17, 4, FACE_HI)


def brass_plate(p, box, r=6, fill=ENAMEL, rim=BRASS, w=6):
    x0, y0, x1, y1 = box
    soft_shadow(p, box, (5, 7), 6, 0.45, r)
    p.rect(x0, y0, x1, y1, rim, INK, 3, r)
    p.line([(x0 + r, y0 + 3), (x1 - r, y0 + 3)], BRASS_HI, 1.6)
    p.rect(x0 + w, y0 + w, x1 - w, y1 - w, fill, INK, 2, max(1, r - 3))


def paint_c_gate(rng):
    p = Pen(W, H, rng, FACE)
    iron_face(p, rng, seams_x=(560,), seam_y=990)
    # dial
    cx, cy, r = 330, 300, 190
    p.ell(cx + 8, cy + 12, r + 26, r + 26, (10, 16, 22), None)
    p.ell(cx, cy, r + 24, r + 24, BRASS, INK, 3.6)
    p.arc(cx, cy, r + 14, r + 14, 195, 290, BRASS_HI, 4)
    p.arc(cx, cy, r + 14, r + 14, 20, 110, BRASS_DK, 4)
    for k in range(8):
        screw(p, *polar((cx, cy), r + 13, 22.5 + 45 * k), 4.5)
    p.ell(cx, cy, r, r, ENAMEL, INK, 3)
    p.ell(cx, cy, r - 14, r - 14, None, mix(ENAMEL, INK, 0.3), 1.6)
    for k in range(6):
        a = tick_angle(k)
        p.line([from_up((cx, cy), r - 54, a), from_up((cx, cy), r - 18, a)], INK, 7)
    p.ell(cx, cy, 18, 18, BRASS, INK, 2.4)
    p.ell(cx, cy, 6, 6, BRASS_DK, None)
    p.rect(255, 382, 405, 418, BRASS_LO, INK, 2.4, 3)
    p.rect(259, 386, 401, 414, PAPER_HI, INK, 2, 2)
    p.line([(263, 390), (397, 390)], mix(PAPER_HI, INK, 0.2), 1.4)
    sh = p.layer()
    sh.poly([(cx - 150, cy - 40), (cx - 70, cy - 160), (cx - 40, cy - 150), (cx - 120, cy - 20)], (255, 255, 255), None)
    p.put_soft(sh, 10, 0.3, circle_mask((W, H), (cx, cy), r - 4))
    # handwheel seat and shaft boss
    hx, hy = 330, 660
    p.ell(hx, hy, 146, 146, mix(FACE, INK, 0.3), INK, 2.6)
    p.ell(hx, hy, 132, 132, None, FACE_HI, 1.6)
    p.ell(hx + 3, hy + 5, 38, 38, (10, 16, 22), None)
    p.ell(hx, hy, 36, 36, IRON_HI, INK, 3)
    p.ell(hx, hy, 18, 18, BRASS, INK, 2.2)
    p.rect(hx - 7, hy - 7, hx + 7, hy + 7, BRASS_DK, None)
    # step-button plates
    for (a, b) in ((140, 310), (350, 520)):
        brass_plate(p, (a, 830, b, 920), 10)
        p.line([(a + 12, 842), (b - 12, 842)], PAPER_HI, 1.4)
    # indicator strip with two blank flag windows
    p.rect(600, 110, 1020, 230, STORM, INK, 3.2, 6)
    p.rect(604, 114, 1016, 226, None, BRASS, 2.4, 4)
    for (a, b) in ((118, 166), (176, 224)):
        p.rect(612, a, 1008, b, ENAMEL, INK, 2.2, 2)
        p.line([(616, a + 4), (1004, a + 4)], mix(ENAMEL, INK, 0.2), 1.2)
    # lock-box: storm panel, brass rim, two recesses, the boundary rule and its blank word plate
    soft_shadow(p, (610, 255, 970, 640), (8, 10), 10, 0.45, 8)
    p.rect(610, 255, 970, 640, STORM, INK, 3.4, 8)
    p.rect(616, 261, 964, 634, None, BRASS, 3, 6)
    for (a, b) in ((270, 420), (470, 620)):
        p.rect(636, a - 4, 944, b + 4, BRASS_LO, INK, 2.4, 4)
        p.rect(640, a, 940, b, (12, 20, 26), INK, 2.4, 3)
        p.line([(644, a + 6), (936, a + 6)], (4, 8, 12), 6)
        p.line([(644, b - 3), (936, b - 3)], STORM_HI, 2)
    p.rect(620, 436, 960, 452, BRASS_HI, INK, 2.4, 2)
    p.line([(622, 448), (958, 448)], BRASS_LO, 1.6)
    p.rect(842, 426, 956, 462, ENAMEL, INK, 2.2, 3)
    for (x, y) in ((626, 270), (954, 270), (626, 624), (954, 624)):
        screw(p, x, y, 4)
    # sight port
    pcx, pcy = 1100, 370
    p.ell(pcx + 6, pcy + 9, 128, 128, (10, 16, 22), None)
    p.ell(pcx, pcy, 126, 126, BRASS, INK, 3.4)
    p.arc(pcx, pcy, 114, 114, 195, 290, BRASS_HI, 4)
    p.arc(pcx, pcy, 114, 114, 20, 110, BRASS_DK, 4)
    for k in range(8):
        bolt(p, *polar((pcx, pcy), 112, 22.5 + 45 * k), 5, BRASS_HI)
    p.ell(pcx, pcy, 96, 96, (8, 12, 16), INK, 3)
    p.ell(pcx, pcy, 100, 100, None, BRASS_DK, 2)
    # plate rack
    p.rect(586, 684, 1114, 696, BRASS, INK, 2.4, 3)
    p.line([(590, 687), (1110, 687)], BRASS_HI, 1.6)
    for x in (586, 1114):
        p.rect(x - 10, 676, x + 10, 704, IRON_HI, INK, 2.2)
        bolt(p, x, 690, 3.4)
    for x in (650, 850, 1050):
        p.line([(x, 694), (x, 712), (x + 9, 722), (x + 18, 712)], INK, 7)
        p.line([(x, 694), (x, 712), (x + 9, 722), (x + 18, 712)], BRASS_HI, 3.6)
    # placard
    soft_shadow(p, (1170, 500, 1420, 900), (6, 9), 8, 0.4, 8)
    p.rect(1170, 500, 1420, 900, ENAMEL, INK, 3, 8)
    p.rect(1182, 512, 1408, 888, None, STORM, 3.4, 4)
    for (x, y) in ((1192, 522), (1398, 522), (1192, 878), (1398, 878)):
        screw(p, x, y, 6)
    # OPEN lever slot
    p.rect(1268, 92, 1352, 468, IRON, INK, 3, 8)
    p.rect(1274, 98, 1346, 462, None, BRASS_LO, 1.6, 6)
    p.rect(1290, 110, 1330, 450, (8, 12, 16), INK, 2.4, 18)
    p.line([(1296, 122), (1296, 438)], IRON, 2)
    return p


def paint_wheel(rng):
    p = Pen(280, 280, rng)
    c = (140, 140)
    p.ell(144, 146, 134, 134, (10, 16, 22, 140), None)
    p.ell(140, 140, 134, 134, STEEL_DK, INK, 3)
    for k in range(72):
        a = k * 5
        p.line([polar(c, 126, a), polar(c, 134, a)], IRON, 2)
    p.ell(140, 140, 134, 134, None, INK, 3)
    p.ell(140, 140, 124, 124, None, STEEL, 1.6)
    p.arc(140, 140, 117, 117, 190, 300, mix(STEEL_HI, COLD, 0.4), 4)
    p.ell(140, 140, 108, 108, (0, 0, 0, 0), INK, 3)
    hole = p.layer()
    hole.ell(140, 140, 106, 106, (255, 255, 255, 255), None)
    p.im.putalpha(ImageChops.subtract(p.im.getchannel("A"), hole.im.getchannel("A")))
    for k in range(6):
        a = -90 + 60 * k
        pts = [polar(c, 30, a - 14), polar(c, 110, a - 4), polar(c, 110, a + 4), polar(c, 30, a + 14)]
        p.poly(pts, STEEL_DK, INK, 2.6)
        p.line([polar(c, 34, a - 8), polar(c, 108, a - 2.5)], STEEL_HI, 1.6)
    p.ell(140, 140, 112, 112, None, INK, 2.4)
    p.ell(140, 140, 36, 36, STEEL, INK, 3)
    p.ell(140, 140, 26, 26, None, STEEL_DK, 1.6)
    p.rect(130, 130, 150, 150, BRASS, INK, 2)
    # the grip knob at the top of the rim: the turn reads
    p.ell(140, 14, 16, 16, BRASS, INK, 2.6)
    p.ell(135, 9, 5, 5, BRASS_HI, None)
    return p


def paint_lever(rng, w, h, piv, pulled, knob_w=96, knob_h=60):
    p = Pen(w, h, rng)
    px, py = piv
    if pulled:
        ky, kw, kh = py - 82, knob_w * 1.12, knob_h * 1.25
        p.rect(px - 13, ky, px + 13, py, BRASS_LO, INK, 2.6, 6)
    else:
        ky, kw, kh = 70, knob_w, knob_h
        p.rect(px - 11, ky, px + 11, py, BRASS, INK, 2.6, 4)
        p.line([(px - 5, ky + 10), (px - 5, py - 10)], BRASS_HI, 2)
    p.ell(px + 3, py + 5, 34, 34, (10, 16, 22, 150), None)
    p.ell(px, py, 32, 32, IRON_HI, INK, 3)
    p.ell(px, py, 16, 16, BRASS, INK, 2.2)
    sh = p.layer()
    sh.rect(px - kw / 2 + 4, ky - kh / 2 + 6, px + kw / 2 + 4, ky + kh / 2 + 6, (10, 16, 22), None, 0, 12)
    p.put_soft(sh, 4, 0.45)
    p.rect(px - kw / 2, ky - kh / 2, px + kw / 2, ky + kh / 2, BRASS, INK, 3, 12)
    p.line([(px - kw / 2 + 12, ky - kh / 2 + 4), (px + kw / 2 - 12, ky - kh / 2 + 4)], BRASS_HI, 2)
    p.rect(px - kw / 2 + 10, ky - kh / 2 + 12, px + kw / 2 - 10, ky + kh / 2 - 12, ENAMEL, INK, 2, 3)
    if pulled:
        p.line([(px - kw / 2 + 6, ky + kh / 2 - 4), (px + kw / 2 - 6, ky + kh / 2 - 4)], BRASS_DK, 2.4)
    return p


def paint_shutter(rng):
    p = Pen(200, 200, rng)
    c = (100, 100)
    p.ell(103, 105, 99, 99, (10, 16, 22, 140), None)
    p.ell(100, 100, 98, 98, BRASS, INK, 3)
    p.ell(100, 100, 86, 86, IRON, INK, 2.4)
    for k in range(8):
        a = k * 45
        blade = [c] + [polar(c, 86, a + t) for t in range(0, 46, 5)]
        col = IRON if k % 2 else mix(IRON, IRON_HI, 0.5)
        p.poly(blade, col, None)
    for k in range(8):
        a = k * 45
        pts = [polar(c, rr, a + 40 * (1 - rr / 86.0) ** 1.5) for rr in range(4, 87, 6)]
        p.line(pts, INK, 2)
        p.line([(q[0] + 1.5, q[1] + 1.5) for q in pts[2:]], IRON_HI, 1)
    p.ell(100, 100, 6, 6, IRON_LO, INK, 1.6)
    p.ell(100, 100, 86, 86, None, INK, 2.6)
    for k in range(6):
        bolt(p, *polar(c, 92, 30 + 60 * k), 3, BRASS_HI)
    return p


def paint_plate_blank(rng):
    p = Pen(240, 140, rng)
    p.rect(3, 3, 237, 137, ENAMEL, INK, 3, 12)
    p.rect(12, 12, 228, 128, None, STORM, 3.4, 7)
    p.line([(18, 7), (222, 7)], PAPER_HI, 1.6)
    p.line([(18, 133), (222, 133)], mix(ENAMEL, INK, 0.25), 1.6)
    for x in (30, 210):
        p.ell(x, 112, 6, 6, BRASS, INK, 1.8)
        p.ell(x - 1.6, 110.4, 2, 2, BRASS_HI, None)
    p.ell(120, 24, 9, 9, (0, 0, 0, 0), INK, 2.6)
    hole = p.layer()
    hole.ell(120, 24, 8, 8, (255, 255, 255, 255), None)
    p.im.putalpha(ImageChops.subtract(p.im.getchannel("A"), hole.im.getchannel("A")))
    return p


# ----------------------------------------------------------------------------- close-up c_door

FRAMES = ((120, 360), (390, 630), (660, 900))


def paint_c_door(rng):
    p = Pen(W, H, rng, FACE)
    iron_face(p, rng, seams_x=(520, 790), seam_y=None)
    for (a, b) in FRAMES:
        x0, x1 = 110, 430
        soft_shadow(p, (x0, a, x1, b), (7, 9), 8, 0.45, 4)
        p.rect(x0, a, x1, b, BRASS, INK, 3, 4)
        p.line([(x0 + 6, a + 4), (x1 - 6, a + 4)], BRASS_HI, 1.8)
        p.rect(x0 + 10, a + 10, x1 - 10, b - 10, mix(GLASS_DK, SEAGLASS, 0.32), INK, 2.2)
        p.poly([(150, b - 14), (210, a + 14), (238, a + 14), (178, b - 14)], mix(SEAGLASS_HI, GLASS_DK, 0.55), None)
        p.poly([(250, b - 14), (290, a + 14), (300, a + 14), (260, b - 14)], mix(SEAGLASS_HI, GLASS_DK, 0.6), None)
        # spring clips
        for x in (160, 380):
            for y, s in ((a, 1), (b, -1)):
                p.rect(x - 9, min(y - s * 4, y + s * 16), x + 9, max(y - s * 4, y + s * 16), BRASS_HI, INK, 1.8, 2)
                p.line([(x - 5, y + s * 6), (x + 5, y + s * 6)], BRASS_DK, 1.4)
        # blank label plate under the top edge, blank result tag at the right edge
        p.rect(205, a + 2, 335, a + 26, ENAMEL, INK, 2, 2)
        m = (a + b) / 2
        p.line([(430, m - 10), (444, m - 10)], BRASS_DK, 2)
        p.rect(442, m - 24, 492, m + 4, ENAMEL, INK, 2, 3)
        p.ell(450, m - 10, 3, 3, (0, 0, 0, 0), INK, 1.4)
    # witness socket plate
    cx, cy = 640, 320
    p.ell(cx + 7, cy + 10, 112, 112, (10, 16, 22), None)
    p.ell(cx, cy, 110, 110, BRASS, INK, 3.4)
    p.arc(cx, cy, 102, 102, 195, 290, BRASS_HI, 3.4)
    p.arc(cx, cy, 102, 102, 20, 110, BRASS_DK, 3.4)
    for k in range(4):
        screw(p, *polar((cx, cy), 94, 45 + 90 * k), 5)
    p.ell(cx, cy, 30, 30, BRASS_LO, INK, 2.4)
    p.ell(cx, cy, 22, 22, (6, 10, 14), INK, 2.4)
    p.arc(cx, cy, 22, 22, 20, 160, IRON_HI, 1.6)
    # COPY port: dark slot, sprung shutter edge-on at its right, worn bright edges, stamp plate
    x0, y0, x1, y1 = 560, 600, 720, 760
    p.rect(586, 552, 694, 586, ENAMEL, INK, 2.2, 3)
    soft_shadow(p, (x0 - 14, y0 - 14, x1 + 14, y1 + 14), (6, 8), 6, 0.4, 6)
    p.rect(x0 - 14, y0 - 14, x1 + 14, y1 + 14, BRASS, INK, 3, 6)
    p.rect(x0, y0, x1, y1, (6, 10, 14), INK, 2.6)
    p.line([(x0 + 4, y0 + 8), (x1 - 4, y0 + 8)], (2, 4, 6), 8)
    for (a, b) in (((x0 - 10, y1 + 6), (x1 + 6, y1 + 6)), ((x1 + 6, y0 - 6), (x1 + 6, y1 + 6)), ((x0 - 6, y0 - 9), (x0 + 90, y0 - 9))):
        p.line([a, b], mix(BRASS_HI, (255, 248, 220), 0.45), 2.4)
    p.rect(x1 + 18, y0 - 10, x1 + 30, y1 + 10, IRON, INK, 2.2)
    p.line([(x1 + 21, y0 - 6), (x1 + 21, y1 + 6)], IRON_HI, 1.4)
    zz = [(x1 + 34 + (6 if i % 2 else 0), y0 + 4 + i * 8) for i in range(20)]
    p.line(zz, INK, 3)
    p.line(zz, BRASS_HI, 1.4)
    # preview window and the door plate
    brass_plate(p, (840, 110, 1360, 240), 6, ENAMEL, BRASS, 8)
    for y in (164, 196, 228):
        p.line([(862, y), (1338, y)], mix(ENAMEL, STORM, 0.28), 1.4)
    p.line([(1040, 124), (1040, 230)], mix(ENAMEL, STORM, 0.18), 1.2)
    soft_shadow(p, (840, 300, 1140, 860), (6, 9), 8, 0.4, 8)
    p.rect(840, 300, 1140, 860, ENAMEL, INK, 3, 8)
    p.rect(852, 312, 1128, 848, None, STORM, 3.4, 4)
    for (x, y) in ((862, 322), (1118, 322), (862, 838), (1118, 838)):
        screw(p, x, y, 6)
    # OPEN ACCESS lever slot
    p.rect(1238, 282, 1322, 878, IRON, INK, 3, 8)
    p.rect(1244, 288, 1316, 872, None, BRASS_LO, 1.6, 6)
    p.rect(1260, 300, 1300, 860, (8, 12, 16), INK, 2.4, 18)
    p.line([(1266, 312), (1266, 848)], IRON, 2)
    return p


def paint_copy_shut(rng):
    p = Pen(240, 240, rng)
    sh = p.layer()
    sh.rect(36, 38, 214, 216, (10, 16, 22), None, 0, 6)
    p.put_soft(sh, 5, 0.5)
    p.rect(30, 30, 210, 210, IRON, INK, 3, 5)
    p.rect(40, 40, 200, 200, None, IRON_HI, 1.6, 3)
    p.line([(36, 36), (204, 36)], mix(IRON_HI, COLD, 0.3), 2)
    for y in (90, 150):
        p.line([(42, y), (198, y)], IRON_LO, 2)
        p.line([(42, y + 3), (198, y + 3)], IRON_HI, 1.2)
    for (x, y) in ((46, 46), (194, 46), (46, 194), (194, 194)):
        bolt(p, x, y, 4, IRON_HI)
    p.rect(206, 24, 222, 216, BRASS_LO, INK, 2.2)
    for y in range(36, 210, 22):
        p.ell(214, y, 5, 5, BRASS_HI, INK, 1.4)
    p.rect(100, 112, 140, 128, BRASS, INK, 2, 6)
    return p


def paint_copy_smear(rng):
    """Inside the COPY port's black square, at eye height: a pale oval smear, as if a face had
    been pressed to it from the far side. Forehead, the bridge of a nose, two cheekbones."""
    p = Pen(160, 160, rng)
    lay = p.layer()
    lay.ell(80, 66, 34, 44, (200, 212, 208), None)
    p.put_soft(lay, 7, 0.13)
    lay = p.layer()
    lay.ell(80, 44, 22, 12, (226, 234, 230), None)
    lay.ell(63, 76, 9, 7, (226, 234, 230), None)
    lay.ell(97, 76, 9, 7, (226, 234, 230), None)
    lay.ell(80, 74, 4, 12, (226, 234, 230), None)
    p.put_soft(lay, 4, 0.16)
    return p


# ----------------------------------------------------------------------------- records

def paint_rec_frame(rng):
    p = Pen(300, 220, rng)
    p.rect(4, 4, 296, 216, TIMBER, INK, 3, 4)
    p.line([(10, 8), (290, 8)], TIMBER_HI, 1.6)
    p.rect(18, 18, 282, 202, PAPER_HI, INK, 2.2)
    for j, y in enumerate((38, 92, 146)):
        p.rect(28, y, 272, y + 40, PAPER, INK, 1.6)
        pts = []
        for i in range(0, 241, 2):
            x = 30 + i
            t = i / 240.0
            if j == 0:
                v = 12 * math.sin(t * 22)
            elif j == 1:
                v = 15 * math.exp(-3 * t) * math.sin(t * 40)
            else:
                v = (14 if (i // 6) % 9 == 0 else 2.5) * math.sin(i * 1.7)
            pts.append((x, y + 20 + v))
        p.line(pts, INK, 1.6)
    gl = p.layer()
    gl.poly([(40, 202), (110, 18), (140, 18), (70, 202)], (255, 255, 255), None)
    p.put(gl, 0.22)
    p.rect(18, 18, 282, 202, None, INK, 2)
    return p


def paint_rec_strip(rng):
    p = Pen(300, 220, rng)
    band = [(8, 78), (270, 74), (284, 70), (292, 80), (292, 138), (284, 146), (270, 144), (8, 140)]
    p.poly([(x + 4, y + 6) for x, y in band], (10, 16, 22, 90), None)
    p.poly(band, PAPER_HI, INK, 2.4)
    p.ell(281, 108, 10, 36, PAPER, INK, 2)
    p.ell(281, 108, 4, 26, mix(PAPER, INK, 0.25), None)
    for i in range(0, 260, 8):
        x = 14 + i
        L = 14 if i % 40 == 0 else 7
        p.line([(x, 80), (x, 80 + L)], INK, 1.6 if i % 40 == 0 else 1.1)
    p.line([(12, 100), (266, 100)], INK, 1.2)
    pts = [(14 + i, 120 + 6 * math.sin(i / 17.0) + 2 * math.sin(i / 5.0)) for i in range(0, 250, 3)]
    p.line(pts, GRAPHITE, 1.6)
    return p


def card(p, amended):
    p.rect(14, 40, 290, 212, (10, 16, 22, 80), None, 0, 4)
    p.poly([(10, 34), (110, 34), (118, 12), (196, 12), (204, 34), (286, 34), (286, 206), (10, 206)], PAPER_HI, INK, 2.4)
    p.rect(132, 18, 182, 30, ENAMEL, INK, 1.4, 2)
    for y in range(64, 200, 18):
        p.line([(20, y), (276, y)], mix(PAPER, SEAGLASS, 0.55), 1.2)
    p.line([(56, 40), (56, 200)], mix(PAPER, STORM, 0.45), 1.4)
    p.line([(20, 41), (276, 41)], STORM, 1.8)
    if amended:
        sm = p.layer()
        sm.rect(18, 160, 278, 202, GRAPHITE, None)
        p.put_soft(sm, 4, 0.18)
        rng = random.Random(SEED + 900)
        for row, y in enumerate((172, 190)):
            x = 26 + row * 6
            while x < 262:
                w = rng.uniform(14, 34)
                pts = []
                for i in range(int(w)):
                    pts.append((x + i, y + 3.2 * math.sin(i * 0.9 + rng.uniform(0, 0.4)) + (rng.uniform(-4, -1) if rng.random() < 0.07 else 0)))
                p.line(pts, GRAPHITE, 1.4)
                x += w + rng.uniform(5, 9)
        p.line([(22, 158), (274, 156)], GRAPHITE, 1.2)


def paint_rec_card(rng, amended=False):
    p = Pen(300, 220, rng)
    card(p, amended)
    return p


def paint_rec_bridge(rng):
    p = Pen(200, 200, rng)
    p.ell(104, 160, 60, 10, (10, 16, 22, 90), None)
    for x in (78, 122):
        p.rect(x - 7, 120, x + 7, 176, mix(BRASS_HI, (255, 248, 220), 0.25), INK, 2.2, 5)
        p.line([(x - 3, 124), (x - 3, 170)], (255, 248, 220), 1.4)
    p.rect(52, 84, 148, 128, BRASS, INK, 3, 10)
    p.line([(60, 90), (140, 90)], BRASS_HI, 2)
    p.line([(60, 122), (140, 122)], BRASS_DK, 2)
    p.rect(88, 64, 112, 86, BRASS_LO, INK, 2.4, 3)
    p.ell(100, 40, 30, 30, BRASS, INK, 3)
    p.ell(100, 40, 18, 18, (0, 0, 0, 0), INK, 2.6)
    hole = p.layer()
    hole.ell(100, 40, 17, 17, (255, 255, 255, 255), None)
    p.im.putalpha(ImageChops.subtract(p.im.getchannel("A"), hole.im.getchannel("A")))
    p.arc(100, 40, 24, 24, 200, 290, BRASS_HI, 2.4)
    return p


# ----------------------------------------------------------------------------- w3 overlays
# New files only (w3 fixes); no existing stem is repainted.

SLAB_Y = (486, 566)             # the horizontal pane: the water_plane hotspot's band


def _treads(p, y0, y1, pitch, riser, edge, wet=False, nose=12.0):
    """Flat stair rows inside OPEN between y0 and y1, each a riser, a nosing and a hard ink
    edge, stepping in a few px a row. One flat colour pair per zone: no depth gradient."""
    x0, _, x1, _ = OPEN
    i = 0
    y = y0
    while y < y1:
        b = min(y + pitch, y1)
        ins = i * 3.0
        xa, xb = x0 - 12 + ins, x1 + 12 - ins
        p.rect(xa, y, xb, b, riser, None)
        nb = min(b, y + nose)
        p.rect(xa, y, xb, nb, edge, None)
        if wet:
            # wet: a hard pale gloss line along each nosing and a short glint, nothing soft
            p.line([(xa + 8, y + 3.2), (xb - 8, y + 3.2)], rgba(mix(SEAGLASS_HI, COLD, 0.5), 200), 1.6)
            gx = lerp(xa + 40, xb - 120, (i * 0.37) % 1.0)
            p.line([(gx, y + nose + 5), (gx + 70, y + nose + 5)], rgba(mix(STORM_HI, COLD, 0.35), 170), 1.2)
        else:
            p.line([(xa, y + 1.6), (xb, y + 1.6)], LIMEWASH_HI, 1.4)
        p.line([(xa, y + nose), (xb, y + nose)], mix(riser, INK, 0.45), 1.2)
        p.line([(xa, y), (xb, y)], INK, 1.8)
        p.line([(xa, y), (xa, b)], INK, 1.8)
        p.line([(xb, y), (xb, b)], INK, 1.8)
        y += pitch
        i += 1


def paint_pane_slab(rng):
    """The gateway with the water as one sharp horizontal sea-glass slab, flat to the jambs, a
    2 px bright edge-on highlight on top. Above it the steps are wet-dark navy; below it they
    are bone-dry limewash. No gradient between the two: the hard border is the wrongness."""
    p = Pen(W, H, rng)
    x0, y0, x1, y1 = OPEN
    top, bot = SLAB_Y
    pitch = 45.0
    # above: wet navy (the well wall behind is the same navy, a step darker)
    p.rect(x0, y0, x1, top, STORM_DK, None)
    _treads(p, y0, top, pitch, STORM, mix(STORM, STORM_HI, 0.6), wet=True)
    # below: bone dry, chalk-flat
    p.rect(x0, bot, x1, y1, LIMEWASH_DK, None)
    _treads(p, bot - 14, y1, pitch, LIMEWASH, LIMEWASH_HI)
    # the slab itself: flat sea-glass, jamb to jamb
    p.rect(x0 - 2, top, x1 + 2, bot, SEA_SAT, None)
    p.rect(x0 - 2, top + 4, x1 + 2, top + 16, mix(SEA_SAT, SEAGLASS_HI, 0.35), None)
    p.rect(x0 - 2, bot - 10, x1 + 2, bot, mix(SEA_SAT, SEA_DEEP, 0.6), None)
    p.line([(x0 - 2, top - 1.0), (x1 + 2, top - 1.0)], INK, 2.0)
    p.rect(x0 - 2, top, x1 + 2, top + 2, (250, 254, 252), None)        # the 2 px edge-on highlight
    p.line([(x0 - 2, bot + 0.5), (x1 + 2, bot + 0.5)], INK, 2.2)
    # flat to the jambs: a hard cold bevel where it meets each jamb face, no meniscus, no spill
    for xe, s in ((x0, 1), (x1, -1)):
        p.rect(min(xe, xe + s * 5), top + 2, max(xe, xe + s * 5), bot, mix(COLD, SEAGLASS_HI, 0.3), None)
        p.line([(xe + s * 5.5, top + 2), (xe + s * 5.5, bot)], mix(SEA_DEEP, INK, 0.45), 1.2)
    clip(p, rect_mask((W, H), [(x0 + 1.5, y0 + 1.5, x1 - 1.5, y1 - 1.5)]))
    return p


def paint_pane_files(rng):
    """After P12: rows of filing shelves inside the slab, stark navy silhouettes, upside down:
    each board on top with its brackets pointing up, the files hanging from it."""
    p = Pen(W, H, rng)
    x0, _, x1, _ = OPEN
    top, bot = SLAB_Y
    sil = mix(INK, STORM_DK, 0.3)
    for by, h in ((top + 6, 30), (top + 44, 28)):
        p.rect(x0, by, x1, by + 5, sil, None)
        for bx in (x0 + 34, (x0 + x1) / 2, x1 - 34):
            p.poly([(bx - 5, by), (bx + 5, by), (bx, by - 4)], sil, None)
        x = x0 + rng.uniform(2, 10)
        while x < x1 - 6:
            w = rng.uniform(12, 20)
            hh = h * rng.uniform(0.72, 1.0)
            if rng.random() < 0.07:
                x += w
                continue
            p.rect(x, by + 5, x + w - 2.5, by + 5 + hh, sil, None)
            # a pale label slot at each file's (upside-down) foot
            p.rect(x + 3, by + 5 + hh - 7, x + w - 5.5, by + 5 + hh - 4, mix(SEA_SAT, COLD, 0.25), None)
            x += w
    p.put(p.layer())
    clip(p, rect_mask((W, H), [(x0 + 6, top + 3, x1 - 6, bot - 2)]))
    return p


BELL_FROZEN_K = 1.12


def paint_bell_frozen(rng):
    """The clapperless bell as a stark navy silhouette about 160 px tall, frozen at 30 degrees
    on its bearing: one hard cold rim line down its lit side, an empty mouth, nothing inside."""
    p = Pen(W, H, rng)
    c = PIVOT
    k = BELL_FROZEN_K
    ang = 30
    T = lambda q: rot((c[0] + q[0] * k, c[1] + (q[1] + 14) * k), c, ang)
    body = mix(INK, STORM_DK, 0.25)
    sh = p.layer()
    sh.poly([(q[0] + 7, q[1] + 9) for q in map(T, bell_shape())], (10, 16, 22), None)
    p.put_soft(sh, 6, 0.35)
    p.poly([T(q) for q in bell_shape()], body, INK, 3.0)
    # the lit side: one hard cold line, the lip a second
    right = bell_shape()[:15]
    p.line([T((x - 4, y)) for x, y in right[2:-1]], mix(COLD, SEAGLASS_HI, 0.3), 2.0)
    p.line([T((-56, 104)), T((56, 104))], mix(STORM_HI, COLD, 0.2), 1.6)
    # the mouth, tipped toward us: a flat ellipse, empty to the crown
    mouth = [T((60 * math.cos(t), 112 + 20 * math.sin(t))) for t in (math.tau * i / 56 for i in range(56))]
    p.poly(mouth, mix(STORM, INK, 0.2), INK, 2.6)
    inner = [T((44 * math.cos(t), 112 + 12 * math.sin(t))) for t in (math.tau * i / 48 for i in range(48))]
    p.poly(inner, (8, 12, 16), None)
    # the yoke on the bearing
    p.poly([T(q) for q in ((-18, -27), (18, -27), (18, -3), (-18, -3))], body, INK, 2.2)
    p.line([T((-18, -9)), T((18, -9))], STORM_HI, 2.0)
    p.ell(c[0], c[1], 8, 8, STORM_HI, INK, 1.8)
    return p


def _upper_stair_geom():
    n = 12
    xa, ya, xb, yb = 1140, FLOOR_Y, 1390, SLAB[1]
    return n, xa, ya, xb, yb, (xb - xa) / n, (ya - yb) / n


FILL_TOP = (185, 203, 196)      # #b9cbc4
FILL_BOT = (143, 168, 162)      # #8fa8a2
FILL_Y1 = DADO_Y - 12           # the cap rail's top
FILL_X0 = 1150


def paint_stairwell_fill(rng):
    """The lower landing's stairwell, no longer a white void: a paper-textured wall in a flat
    vertical gradient (#b9cbc4 to #8fa8a2) up the shaft and behind the flight, navy-contoured
    stringers of the stair going on up out of frame, and the old light wedge laid back over it
    at 0.25. The flight itself, the slab and the dado are left as painted."""
    p = Pen(W, H, rng)
    n, xa, ya, xb, yb, run, rise = _upper_stair_geom()
    # where the fill may go: the shaft, the hole, the wall behind the flight; never the flight
    m = rect_mask((W, H), [(HOLE[0] - 10, -4, HOLE[1] + 10, SLAB[0]), (HOLE[0], SLAB[0], HOLE[1], SLAB[1]),
                           (FILL_X0, SLAB[1] + 1.5, W + 4, FILL_Y1)])
    ex = Image.new("L", m.size, 0)
    d = ImageDraw.Draw(ex)
    for i in range(n):
        tx, ty = xa + i * run, ya - (i + 1) * rise
        d.rectangle(((tx - 3) * SS, (ty - 1.5) * SS, (tx + run + 2) * SS, ya * SS), fill=255)
    T = 46
    st = [(xa - 8, ya + 2), (xb + 12, yb + rise * 0.6 - 2), (xb + 12, yb + rise * 0.6 + T + 2), (xa + 14, ya + 2)]
    d.polygon([(x * SS, y * SS) for x, y in st], fill=255)
    d.rectangle(((xb - 2) * SS, (yb - 2) * SS, (xb + 13) * SS, (yb + rise * 0.6 + T) * SS), fill=255)
    m = ImageChops.subtract(m, ex)
    # the wall: a flat vertical gradient in bands of 2 px, then paper grain
    wall = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wall)
    for y in range(0, FILL_Y1 + 2, 2):
        wd.rectangle((0, y, W, y + 2), fill=rgba(mix(FILL_TOP, FILL_BOT, y / FILL_Y1)))
    wall = grain(wall, rng_for(1029), amp=6, mottle=7, speck=10).convert("RGBA")
    fill = Pen(W, H, rng)
    fill.im = wall.resize((W * SS, H * SS), Image.NEAREST)
    fill.d = ImageDraw.Draw(fill.im)
    # faint block courses, as the walls round it
    for y in range(SLAB[1] + 96, FILL_Y1, 96):
        fill.line([(FILL_X0, y), (W + 4, y)], mix(FILL_BOT, SEAGLASS, 0.35), 1.6)
    for y in range(SLAB[0] - 96, -4, -96):
        fill.line([(HOLE[0] - 10, y), (HOLE[1] + 10, y)], mix(FILL_TOP, SEAGLASS, 0.3), 1.4)
    # the stair goes on up the shaft, out of frame: two stringers and the treads between them
    fl = fill.layer()
    sx0, sy0, sx1, sy1 = HOLE[1] + 4, SLAB[0] + 10, HOLE[0] - 40, -60
    steps = 9
    for j in range(steps):
        t0 = j / steps
        x = lerp(sx0, sx1, t0)
        y = lerp(sy0, sy1, t0)
        sw, shh = (sx0 - sx1) / steps, (sy0 - sy1) / steps
        fl.rect(x - sw, y - shh, x, y - shh + 9, LIMEWASH_HI, INK, 1.8)
        fl.rect(x - sw + 2, y - shh + 9, x, y, mix(LIMEWASH_DK, STORM, 0.25), INK, 1.4)
    back = [(sx0 + 10, sy0 + 26), (sx1 + 10, sy1 + 26)]
    fl.line(back, mix(STORM, INK, 0.3), 5.0)
    front = [(sx0 + 30, sy0 + 40), (sx1 + 30, sy1 + 40), (sx1 + 30, sy1 + 84), (sx0 + 30, sy0 + 84)]
    fl.poly(front, STORM, INK, 2.6)
    fl.line([(sx0 + 30, sy0 + 44), (sx1 + 30, sy1 + 44)], STORM_HI, 1.6)
    clip(fl, rect_mask((W, H), [(HOLE[0] - 10, -4, HOLE[1] + 10, SLAB[0])]))
    fill.put(fl)
    # the old light wedge, laid back at 0.25
    lt = fill.layer()
    lt.poly([(HOLE[0] + 4, SLAB[1]), (HOLE[1] - 4, SLAB[1]), (1350, 640), (1150, 560)], (250, 252, 248), None)
    fill.put(lt, 0.25)
    sh = fill.layer()
    sh.rect(HOLE[0] + 20, -4, HOLE[1] - 10, SLAB[0], (250, 252, 248), None)
    fill.put_soft(sh, 20, 0.25)
    clip(fill, m)
    p.put(fill)
    # the wedge where it falls on the dado: the dado painted again under a 0.25 wedge
    dm = Image.new("L", m.size, 0)
    ImageDraw.Draw(dm).polygon([(x * SS, y * SS) for x, y in
                                ((HOLE[0] + 4, SLAB[1]), (HOLE[1] - 4, SLAB[1]), (1350, 640), (1150, 560))], fill=255)
    dm = ImageChops.multiply(dm, rect_mask((W, H), [(FILL_X0 - 10, FILL_Y1, W + 4, 660)]))
    dm = ImageChops.subtract(dm, ex)
    dd = p.layer()
    dado(dd, rng_for(1129))
    lt = dd.layer()
    lt.poly([(HOLE[0] + 4, SLAB[1]), (HOLE[1] - 4, SLAB[1]), (1350, 640), (1150, 560)], (250, 252, 248), None)
    dd.put(lt, 0.25)
    clip(dd, dm)
    p.put(dd)
    # contours: the stairwell's own wall plane, and the shaft's edges again
    p.line([(FILL_X0, SLAB[1]), (FILL_X0, FILL_Y1)], INK, 2.6)
    p.line([(HOLE[0] - 10, -4), (HOLE[0] - 10, SLAB[0])], INK, 3)
    p.line([(HOLE[1] + 10, -4), (HOLE[1] + 10, SLAB[0])], INK, 3)
    return p


def _gauge_face(size, r, tick_in, tick_out, tick_w, ring_r, ring_w, window, pin_r):
    """A gauge face overlay: enamel, an unnumbered ring with four ticks (1-4; the needle rests on
    a stop pin at 0 and the far stop is a second pin), no reference needle, no words."""
    p = Pen(size, size, random.Random(SEED + 900))
    c = (size / 2, size / 2)
    p.ell(c[0], c[1], r, r, ENAMEL, None)
    p.ell(c[0], c[1], r - r * 0.074, r - r * 0.074, None, mix(ENAMEL, INK, 0.3), max(1.2, r * 0.0085))
    p.arc(c[0], c[1], ring_r, ring_r, -90 - 120, -90 + 120, INK, ring_w)
    for k in range(1, 5):
        a = tick_angle(k)
        p.line([from_up(c, tick_in, a), from_up(c, tick_out, a)], INK, tick_w)
    for k in (0, 5):
        q = from_up(c, ring_r, tick_angle(k))
        p.ell(q[0], q[1], pin_r, pin_r, BRASS, INK, max(1.2, pin_r * 0.3))
    if window:
        wx0, wy0, wx1, wy1 = window
        p.rect(wx0, wy0, wx1, wy1, BRASS_LO, INK, max(1.6, r * 0.012), 3)
        p.rect(wx0 + 4, wy0 + 4, wx1 - 4, wy1 - 4, PAPER_HI, INK, max(1.4, r * 0.01), 2)
    sh = p.layer()
    sh.poly([(c[0] - r * 0.75, c[1] - r * 0.3), (c[0] - r * 0.35, c[1] - r * 0.8), (c[0] - r * 0.2, c[1] - r * 0.72),
             (c[0] - r * 0.66, c[1] - r * 0.15)], (255, 255, 255), None)
    p.put_soft(sh, max(4, r * 0.05), 0.3, circle_mask((size, size), c, r - 2))
    clip(p, circle_mask((size, size), c, r))
    return p


def paint_c_gauge_face(rng):
    # c_gate's dial at (330, 300) r 190; the sprite is 400 x 400 about that centre
    return _gauge_face(400, 187, 136, 172, 7, 154, 2.4, (125, 282, 275, 318), 7)


def paint_L1_gauge_face(rng):
    # L1's dial at (300, 300) r 88; the sprite is 200 x 200 about that centre
    return _gauge_face(200, 86, 64, 80, 3.4, 72, 1.4, (63, 132, 137, 158), 3.4)


# ----------------------------------------------------------------------------- p1 overlays
WATER_SLAB = (556, 252, 894, 880)   # the slab standing in OPEN: its top stands clear of the lintel


def paint_water_slab(rng):
    """After P12: the water in the gateway is standing up. One vertical slab, flat to the floor,
    its top a ruled flat line in mid-air well under the lintel. Matte sea-glass above, storm navy
    below (two flat zones and one hard step, no gradient), translucent enough that the stair
    reads faintly through it, inside a hard navy contour. A pale meniscus line under the top
    contour, two ruled light streaks, a few specks held perfectly still."""
    p = Pen(W, H, rng)
    x0, y0, x1, y1 = WATER_SLAB
    step = 600
    body = p.layer()
    body.rect(x0, y0, x1, step, SEA_SAT, None)
    body.rect(x0, step, x1, y1, mix(STORM, SEA_DEEP, 0.25), None)
    # the step between the zones: a thin darker band, ruled, as if the slab had strata
    body.rect(x0, step - 6, x1, step, mix(SEA_DEEP, STORM, 0.5), None)
    p.put(body, 0.8)
    # the stair behind, faintly, as ruled navy edges through the body
    st = p.layer()
    y = y0 + 34.0
    while y < y1 - 20:
        st.line([(x0 + 8, y), (x1 - 8, y)], mix(STORM_DK, INK, 0.4), 2.0)
        y += 45.0
    p.put(st, 0.28)
    # light in the glass: two ruled vertical streaks and a side sheen
    lt = p.layer()
    lt.rect(x0 + 62, y0 + 18, x0 + 70, y1 - 30, mix(SEAGLASS_HI, COLD, 0.55), None)
    lt.rect(x0 + 92, y0 + 40, x0 + 95, step - 30, mix(SEAGLASS_HI, COLD, 0.4), None)
    lt.rect(x1 - 40, y0 + 12, x1 - 34, y1 - 12, mix(SEAGLASS_HI, SEA_SAT, 0.4), None)
    p.put(lt, 0.7)
    motes(p, rng_for(330), (x0 + 20, y0 + 60, x1 - 20, y1 - 40), 6)
    # the flat top: a hard bright meniscus line in mid-air, under the contour
    p.rect(x0 + 2, y0 + 2, x1 - 2, y0 + 8, (244, 250, 247), None)
    p.line([(x0 + 2, y0 + 9.5), (x1 - 2, y0 + 9.5)], mix(SEA_DEEP, INK, 0.5), 1.4)
    # the contour: hard navy all the way round, heavier than any other line in the gateway
    p.rect(x0, y0, x1, y1, None, INK, 5.0)
    return p


# ----------------------------------------------------------------------------- p3 overlays
# Band 6+: the wall at the glass shelf soaked from sage to storm navy. Every plaster pixel
# (mottle and joints too) is multiplied by WASH_K and pulled WASH_TO_STORM toward storm navy;
# a flat sea-glass waterline stain WASH_STAIN px deep runs along the shelf line and 3 px drip
# ticks hang off it every DRIP_STEP px. Each overlay is its plate repainted with the wash laid
# between the wall and the first object (same seed, same draw order), so off the wash it is
# the plate pixel for pixel and every object on the wall keeps its own full-ink contour; it is
# then cut to the washed band (transparent elsewhere).
WASH_K = 0.45
WASH_TO_STORM = 0.4
WASH_STAIN = 6
DRIP_STEP = 90
DRIP_W = 3
# L2: the glass shelf is the office floor seen from below (SLAB, y 300-330); the wall from its
# underside down to the dado cap washes, the stain under the shelf line.
WASH_L2 = (SLAB[1], DADO_Y - 12)
# L1: the glass shelf is the horizontal pane (R11_view SLAB_BAND, top edge y 486); the wall
# above it, from the ceiling band's foot, washes, the stain on the shelf line.
WASH_L1 = (80, 486)


def wash_band(p, y0, y1):
    box = (0, y0 * SS, p.im.width, y1 * SS)
    r, g, b, a = p.im.crop(box).split()
    k, t = WASH_K, WASH_TO_STORM
    chans = [c.point(lambda v, n=n: int(round(v * k * (1 - t) + n * t))) for c, n in zip((r, g, b), STORM)]
    p.im.paste(Image.merge("RGBA", chans + [a]), box)


def waterline(p, rng, y_stain, y_drip):
    """The stain (y_stain .. +WASH_STAIN) and the drip ticks hanging from y_drip."""
    p.rect(-4, y_stain, W + 4, y_stain + WASH_STAIN, SEA_SAT, None)
    p.line([(-4, y_stain + 0.5), (W + 4, y_stain + 0.5)], SEAGLASS_HI, 1.0)
    x = DRIP_STEP / 2
    while x < W:
        L = rng.uniform(12, 34)
        p.rect(x - DRIP_W / 2, y_drip, x + DRIP_W / 2, y_drip + L, STORM_DK, None)
        p.ell(x, y_drip + L, DRIP_W * 0.75, DRIP_W * 0.9, STORM_DK, None)
        x += DRIP_STEP


def _cut_band(p, k, y0, y1):
    im = grain(p.done(), rng_for(1000 + k), amp=4, mottle=4, speck=8).convert("RGBA")
    a = Image.new("L", (W, H), 0)
    ImageDraw.Draw(a).rectangle((0, y0, W, y1), fill=255)
    im.putalpha(a)
    return im


def paint_b6_wash(rng):
    """The lower landing (paint_L2_base, seed 20) with the wall under the glass shelf washed."""
    p = Pen(W, H, rng, PLASTER)
    stone_wall(p, rng, (-4, -4, W + 4, DADO_Y), PLASTER, 96, 0, skip=[(10, 120, 96, 360)], mottle=0.18, joints=0.4)
    y0, y1 = WASH_L2
    wash_band(p, y0, y1)
    waterline(p, rng_for(18), y0, y0 + WASH_STAIN)
    _l2_after_wall(p, rng)
    return _cut_band(p, 20, y0 - 2, DADO_Y + 6)


def paint_b6_wash_L1(rng):
    """The gate landing (paint_L1_base, seed 0) with the wall above the glass shelf washed."""
    p = Pen(W, H, rng, PLASTER)
    stone_wall(p, rng, (-4, 80, W + 4, DADO_Y), PLASTER, 96, 80, skip=[(1350, 550, 1442, 770), (906, 160, 954, 880)],
               mottle=0.18, joints=0.4)
    y0, y1 = WASH_L1
    wash_band(p, y0, y1 - WASH_STAIN)
    waterline(p, rng_for(17), y1 - WASH_STAIN, y1)
    _l1_after_wall(p, rng)
    return _cut_band(p, 0, y0 - 4, y1 + 40)


def paint_name_shutter(rng):
    """The iron shutter over the NAME frame's glass: flat storm-navy slats in a riveted plate,
    a brass bottom lip. The view stencils its word."""
    w, h = 300, 220
    p = Pen(w, h, rng)
    p.rect(1, 1, w - 1, h - 1, STORM, INK, 3.4)
    y = 14.0
    while y < h - 30:
        p.rect(8, y, w - 8, y + 20, mix(STORM, STORM_HI, 0.35), INK, 1.6)
        p.line([(12, y + 3), (w - 12, y + 3)], STORM_HI, 1.2)
        y += 26.0
    p.rect(1, h - 24, w - 1, h - 1, BRASS, INK, 3.0)
    p.line([(6, h - 20), (w - 6, h - 20)], BRASS_HI, 1.6)
    for x in (14, w - 14):
        for yy in (10, h - 34):
            p.ell(x, yy, 3.4, 3.4, IRON_HI, INK, 1.3)
    return p


# ----------------------------------------------------------------------------- registry

ASSETS = [  # name, seed index, painter, opaque, grain
    ("L1_base", 0, paint_L1_base, True, True),
    ("L1_grille", 1, lambda r: paint_grille(r, False), False, False),
    ("L1_grille_up", 2, lambda r: paint_grille(r, True), False, False),
    ("L1_glass", 3, lambda r: glass_layer(r, False), False, False),
    ("L1_glass_deep", 4, lambda r: glass_layer(r, True), False, False),
    ("L1_shelves", 5, paint_shelves, False, False),
    ("L1_tide_1", 6, lambda r: paint_tide(r, 1), False, False),
    ("L1_tide_2", 7, lambda r: paint_tide(r, 2), False, False),
    ("L1_tide_3", 8, lambda r: paint_tide(r, 3), False, False),
    ("L1_tide_4", 9, lambda r: paint_tide(r, 4), False, False),
    ("L1_tide_5", 10, lambda r: paint_tide(r, 5), False, False),
    ("L1_glass_tilt", 11, lambda r: glass_layer(r, True, 14.0), False, False),
    ("L1_spill", 12, paint_spill, False, False),
    ("L2_base", 20, paint_L2_base, True, True),
    ("L2_bell_up", 21, lambda r: paint_bell(r, 35), False, False),
    ("L2_bell_down", 22, lambda r: paint_bell(r, -65), False, False),
    ("L2_shoes_dry", 23, lambda r: paint_shoes(r, "dry"), False, False),
    ("L2_shoes_wet", 24, lambda r: paint_shoes(r, "wet"), False, False),
    ("L2_shoes_facing", 25, lambda r: paint_shoes(r, "facing"), False, False),
    ("L2_door_open", 26, paint_door_open, False, False),
    ("L2_finger_marks", 27, paint_finger_marks, False, False),
    ("plate_blank", 30, paint_plate_blank, False, False),
    ("port_false", 31, paint_port_false, False, False),
    ("port_true", 32, paint_port_true, False, False),
    ("cut_glass", 40, paint_cut_glass, True, True),
    ("cut_hand_a", 41, lambda r: paint_hand(r, False), False, False),
    ("cut_hand_b", 42, lambda r: paint_hand(r, True), False, False),
    ("c_gate", 50, paint_c_gate, True, True),
    ("c_wheel", 51, paint_wheel, False, False),
    ("c_lever_up", 52, lambda r: paint_lever(r, 160, 360, (80, 300), False), False, False),
    ("c_lever_down", 53, lambda r: paint_lever(r, 160, 360, (80, 300), True), False, False),
    ("c_port_shutter", 54, paint_shutter, False, False),
    ("c_door", 60, paint_c_door, True, True),
    ("c_access_up", 61, lambda r: paint_lever(r, 180, 560, (90, 480), False, 110, 64), False, False),
    ("c_access_down", 62, lambda r: paint_lever(r, 180, 560, (90, 480), True, 110, 64), False, False),
    ("c_copy_shut", 63, paint_copy_shut, False, False),
    ("c_copy_smear", 64, paint_copy_smear, False, False),
    ("rec_frame", 70, paint_rec_frame, False, False),
    ("rec_strip", 71, paint_rec_strip, False, False),
    ("rec_card", 72, lambda r: paint_rec_card(r, False), False, False),
    ("rec_card_amended", 72, lambda r: paint_rec_card(r, True), False, False),
    ("rec_bridge", 73, paint_rec_bridge, False, False),
    # w3 overlays (new files)
    ("pane_slab", 13, paint_pane_slab, False, False),
    ("pane_files", 14, paint_pane_files, False, False),
    ("L1_gauge_face", 15, paint_L1_gauge_face, False, False),
    ("bell_frozen", 28, paint_bell_frozen, False, False),
    ("stairwell_fill", 29, paint_stairwell_fill, False, False),
    ("c_gauge_face", 55, paint_c_gauge_face, False, False),
    # p1 overlays (new files)
    ("p12_water_slab", 16, paint_water_slab, False, False),
    ("c_name_shutter", 65, paint_name_shutter, False, False),
    # p3 overlays (new files)
    ("b6_wash", 20, paint_b6_wash, False, False),
    ("b6_wash_L1", 0, paint_b6_wash_L1, False, False),
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
            im = grain(im, rng_for(1000 + k), amp=4, mottle=4, speck=8)
        save(im, name, opaque)


if __name__ == "__main__":
    main(sys.argv[1:])
