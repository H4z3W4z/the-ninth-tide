#!/usr/bin/env python3
"""R07 Wet Laboratory painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R07/*.png and assets/stages/R07/*.png:

  view_a, view_a_s3 .. view_a_s7, view_a_sever
                      the tank wall stage plates (1448x1086 opaque): bands <=2, 3, 4, 5, 6, 7, sever
  view_b, view_b_s3 .. view_b_s7, view_b_sever
                      the bench stage plates (same staging)
  a_tank_glass, a_reflect_three, a_reflect_two, a_vault_ajar, a_return_unbolted,
  a_socket_tag, a_rack_salt, a_rack_salt_v2       view A overlays (RGBA, registered)
  waterline, ceiling_rings, wall_hand   view A, "the room beneath the water" (bands 4, 6, 7)
  a_sea_b2/b3/b4/b6/b7, a_sea_b6_slot, a_lamp, a_lamp_low, a_lamp_patch_s6/s7,
  b_sea_b2/b3/b4/b6/b7, b_lamp_low, b_lamp_patch_s6/s7
                      the lab taking on water by band (see "the sea comes in")
  b_shells_loose, b_shells_rings, b_thumb, b_strip, b_frame, b_stand_empty, b_register_open,
  b_lid_closed, b_lid_open, b_fog                 view B overlays (RGBA, registered)
  c_tilt_rack, c_balance, c_frame                 close-up plates (opaque)
  jar_*, c_jar_*, c_cradle, plumb, c_plumb, c_tag, c_beam, c_pan, c_tray, c_thumb,
  c_sample_{n,w,f}, c_card, c_pin, c_needle, c_key_down, c_lever_down, c_section,
  c_name_tab, c_strip, c_seal_down, c_frame_glass sprites (RGBA, exact sizes and pivots)
  b2_tidemark, b2_tidemark_bench, b4_lamp_pool, b4_water_lean, datum_water_r3,
  b4_lamp_pool_cold, datum_water_sub, r07_submerged_b3, r07_submerged_b5
                      assets/stages/R07: dread while the puzzles are played (see "stage overlays")
  view_b_s3_v2, view_b_s4_v2   the bench plates at bands 3 and 4 with the cabinet tide mark
                      painted as clear water, not a salt strip (replace view_b_s3 / view_b_s4)
  c_sample_tube       the one opaque stoppered tube every P13 stand holds (replaces c_sample_*)

The room is square to its brass DATUM: every tile course, shelf and the floor is level in plate
space. Gravity is the thing that is off (the view rotates the plumb and the water); the plates
only carry the basin's slanted pool as the one painted hint.

The bands are painted, not graded: the wall goes from clean pale sea-glass to a greyer, wetter
tone with storm-navy grout from band 5; one flat salt tide mark climbs a tile per band from band
3; wet runs come down from the datum from band 5; band 7 adds a few large damp blooms and a wet
handprint by the basin. Ambient light never drops.

Flat front elevation, approved palette, navy ink contours, matte colour and a low seeded paper
grain. No text, numerals or glyphs: every label is a blank enamel or paper plate the view writes
on. No water in the jars or the tank, and no jar in the rack or socket: the view draws them.

Python 3 + PIL only. Deterministic: each asset has its own random.Random(SEED + k), stage effects
draw from their own generators so every stage plate shares the base geometry exactly, there is
no clock and no PIL noise effect, so a rerun is byte-identical.

    python3 tools/art/rooms/R07.py              # paint everything
    python3 tools/art/rooms/R07.py view_a* c_*  # paint some (fnmatch patterns)
"""
import fnmatch
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "rooms", "R07")
W, H = 1448, 1086
SS = 2                      # supersampling for every painted shape
SEED = 1931_07_00

# ----------------------------------------------------------------------------- palette
INK = (23, 43, 54)          # #172B36 contours
PAPER = (216, 206, 181)     # #D8CEB5
PAPER_HI = (232, 225, 207)  # #E8E1CF
SEAGLASS = (97, 125, 116)   # #617D74
SEAGLASS_HI = (150, 178, 166)
TIMBER = (103, 93, 81)      # #675D51
SOOT = (41, 41, 41)         # #292929
BRASS = (156, 126, 70)      # #9C7E46
BRASS_HI = (201, 168, 105)  # #C9A869
BRASS_LO = (116, 92, 50)    # #745C32
STORM = (34, 56, 74)        # #22384A
AMBER = (195, 153, 89)      # #C39959  tiny lamp accents only
VIOLET = (116, 101, 119)    # #746577  band-7 accents only, always a shape


def mix(c0, c1, t):
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(c0, c1))


# derived tones (all mixes of the approved palette)
ENAMEL = mix(PAPER_HI, PAPER, 0.25)
ENAMEL_DK = mix(PAPER, SEAGLASS_HI, 0.35)
TILE = mix(SEAGLASS_HI, PAPER_HI, 0.42)
TILE_DK = mix(TILE, SEAGLASS, 0.22)
TILE_HI = mix(TILE, PAPER_HI, 0.55)
LIME = mix(PAPER_HI, SEAGLASS_HI, 0.12)
STORM_HI = mix(STORM, SEAGLASS, 0.35)
STORM_DK = mix(STORM, SOOT, 0.45)
STEEL = mix(STORM, SEAGLASS_HI, 0.42)
STEEL_HI = mix(STEEL, PAPER_HI, 0.28)
STEEL_DK = mix(STEEL, STORM, 0.55)
TIMBER_DK = mix(TIMBER, SOOT, 0.3)
TIMBER_HI = mix(TIMBER, PAPER, 0.22)
OAK = mix(TIMBER, BRASS, 0.32)
OAK_HI = mix(OAK, PAPER, 0.25)
OAK_DK = mix(OAK, SOOT, 0.25)
BRASS_DK = mix(BRASS_LO, SOOT, 0.3)
FELT = SEAGLASS_HI
FELT_DK = mix(SEAGLASS_HI, SEAGLASS, 0.55)
GLASS = mix(SEAGLASS_HI, PAPER_HI, 0.55)       # pale glass field
GLASS_HI = mix(PAPER_HI, (255, 255, 255), 0.3)
DAMP = mix(SEAGLASS, STORM, 0.4)
SALT = mix(PAPER_HI, (255, 255, 255), 0.45)
SHADOW = mix(STORM, SOOT, 0.5)
SLOT = mix(STORM, SOOT, 0.6)
STONE = mix(SOOT, PAPER, 0.42)
WATER_PAINT = (77, 110, 100)   # #4d6e64: water is a filled matte mass
VOID = (14, 26, 42)            # #0e1a2a: what is behind the vault door


# ----------------------------------------------------------------------------- helpers

def rng_for(k):
    return random.Random(SEED + k)


def lerp(a, b, t):
    return a + (b - a) * t


def rgba(c, a=255):
    return c if len(c) == 4 else (c[0], c[1], c[2], a)


def rot(p, c, deg):
    a = math.radians(deg)
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a))


class Pen:
    """Draws in 1x logical coordinates on a supersampled RGBA canvas. (ox, oy) shifts every
    shape, so a group of parts can be painted at a new position without retyping it."""

    def __init__(self, w, h, rng, bg=None):
        self.w, self.h, self.rng = w, h, rng
        self.ox, self.oy = 0.0, 0.0
        self.im = Image.new("RGBA", (w * SS, h * SS), rgba(bg) if bg else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def iw(self, w):
        return max(1, int(round((w + self.rng.uniform(-0.3, 0.3)) * SS)))

    def _p(self, pts):
        return [((x + self.ox) * SS, (y + self.oy) * SS) for x, y in pts]

    def _box(self, x0, y0, x1, y1):
        return ((x0 + self.ox) * SS, (y0 + self.oy) * SS, (x1 + self.ox) * SS, (y1 + self.oy) * SS)

    def poly(self, pts, fill=None, ink=INK, w=3.0):
        p = self._p(pts)
        if fill is not None:
            self.d.polygon(p, fill=rgba(fill))
        if ink is not None and w:
            self.d.line(p + [p[0]], fill=rgba(ink), width=self.iw(w), joint="curve")

    def rect(self, x0, y0, x1, y1, fill=None, ink=INK, w=3.0, r=0):
        width = self.iw(w) if (ink is not None and w) else 0
        self.d.rounded_rectangle(self._box(x0, y0, x1, y1), radius=r * SS,
                                 fill=rgba(fill) if fill is not None else None,
                                 outline=rgba(ink) if width else None, width=width)

    def ell(self, cx, cy, rx, ry=None, fill=None, ink=INK, w=3.0):
        ry = rx if ry is None else ry
        width = self.iw(w) if (ink is not None and w) else 0
        self.d.ellipse(self._box(cx - rx, cy - ry, cx + rx, cy + ry), fill=rgba(fill) if fill is not None else None,
                       outline=rgba(ink) if width else None, width=width)

    def line(self, pts, col=INK, w=3.0):
        self.d.line(self._p(pts), fill=rgba(col), width=self.iw(w), joint="curve")

    def arc(self, cx, cy, rx, ry, a0, a1, col=INK, w=3.0):
        self.d.arc(self._box(cx - rx, cy - ry, cx + rx, cy + ry), a0, a1, fill=rgba(col), width=self.iw(w))

    def layer(self, tint=None):
        """A transparent layer; `tint` sets the colour under alpha 0 so blurred edges don't grey."""
        lay = Pen(self.w, self.h, self.rng)
        lay.ox, lay.oy = self.ox, self.oy
        if tint is not None:
            lay.im = Image.new("RGBA", lay.im.size, tuple(tint[:3]) + (0,))
            lay.d = ImageDraw.Draw(lay.im)
        return lay

    def at(self, dx, dy=0.0):
        """Shift subsequent shapes by (dx, dy); returns the previous offset for restore()."""
        prev = (self.ox, self.oy)
        self.ox, self.oy = dx, dy
        return prev

    def restore(self, prev):
        self.ox, self.oy = prev

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

    def put_soft(self, other, radius, opacity=1.0, mask=None):
        other.im = other.im.filter(ImageFilter.GaussianBlur(radius * SS))
        self.put(other, opacity, mask)

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


def grain(im, rng, amp=4, mottle=5, speck=9):
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
        clear = a.point(lambda v: 255 if v == 0 else 0)
        im.paste((0, 0, 0, 0), mask=clear)
    path = os.path.join(out, name + ".png")
    im.save(path, optimize=False, compress_level=9)
    print("  wrote", os.path.relpath(path, ROOT), im.size, im.mode)


def rect_mask(rects, size=(W, H), feather=0):
    """An L mask (supersampled) that keeps the given logical rects."""
    m = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    d = ImageDraw.Draw(m)
    for x0, y0, x1, y1 in rects:
        d.rectangle((x0 * SS, y0 * SS, x1 * SS, y1 * SS), fill=255)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather * SS))
    return m


def poly_mask(pts, size=(W, H)):
    m = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    return m


def screw(p, x, y, r=4.5, col=BRASS_HI):
    p.ell(x, y, r, r, col, INK, 1.6)
    p.line([(x - r * 0.6, y - r * 0.6), (x + r * 0.6, y + r * 0.6)], mix(col, INK, 0.5), 1.2)


def rivet(p, x, y, r=3.2, col=STORM_HI):
    p.ell(x, y, r, r, col, INK, 1.4)
    p.ell(x - r * 0.3, y - r * 0.3, r * 0.35, r * 0.35, mix(col, PAPER_HI, 0.5), None)


def plate(p, x0, y0, x1, y1, fill=ENAMEL, rim=BRASS_LO, w=2.4):
    """A blank enamel label plate with a thin brass rim: the view writes on it."""
    p.rect(x0 - 3, y0 - 3, x1 + 3, y1 + 3, rim, INK, w, r=3)
    p.rect(x0, y0, x1, y1, fill, mix(INK, rim, 0.5), 1.4, r=2)


def card(p, x0, y0, x1, y1, fill=PAPER_HI, ruled=0, pins=True, rng=None):
    """A pinned paper card; optional faint rules. Casts a short soft shadow."""
    sh = p.layer()
    sh.rect(x0 + 5, y0 + 6, x1 + 5, y1 + 6, SHADOW, None)
    p.put_soft(sh, 4, 0.28)
    p.rect(x0, y0, x1, y1, fill, INK, 2.2, r=2)
    if ruled:
        lay = p.layer()
        y = y0 + ruled
        while y < y1 - 8:
            lay.line([(x0 + 8, y), (x1 - 8, y)], SEAGLASS, 1.2)
            y += ruled
        p.put(lay, 0.45)
    if pins:
        for x in (x0 + 12, x1 - 12):
            p.ell(x, y0 + 10, 4.5, 4.5, BRASS_HI, INK, 1.6)


def ragged(rng, x0, x1, y, amp, step=18, waves=3):
    """A seeded ragged horizontal edge: sum of slow waves plus jitter."""
    ph = [rng.uniform(0, 6.283) for _ in range(waves)]
    fr = [rng.uniform(0.004, 0.02) * (k + 1) for k in range(waves)]
    pts = []
    x = x0
    while x <= x1 + step:
        dy = sum(math.sin(x * fr[k] + ph[k]) / (k + 1) for k in range(waves)) * amp * 0.6
        dy += rng.uniform(-amp * 0.25, amp * 0.25)
        pts.append((x, y + dy))
        x += step
    return pts


# ----------------------------------------------------------------------------- the room shell

G = 96                      # tile pitch: 15 columns across the plate, as in the close-ups
DADO_Y = 600
WALL_TOP = 112

# The wall by weather band: clean pale sea-glass, going greyer and wetter from band 5. Ambient
# stays high; what changes is the wall itself, so every hotspot keeps its contrast.
WALL = {
    2: (207, 224, 216),     # #cfe0d8
    3: (201, 218, 211),
    4: (194, 211, 205),
    5: (181, 197, 192),
    6: (172, 188, 184),
    7: (163, 179, 176),
    "sever": (196, 203, 200),
}
# Grout: matte ink, then from band 5 storm navy at about 60% so the grid reads as a net.
GROUT = {2: (INK, 0.30), 3: (INK, 0.32), 4: (INK, 0.36), 5: (STORM, 0.58), 6: (STORM, 0.62), 7: (STORM, 0.64),
         "sever": (INK, 0.34)}
# The salt tide mark: one flat band on the wall, rising one tile per band.
TIDE_Y = {3: 744, 4: 648, 5: 552, 6: 456, 7: 360, "sever": 360}
TIDE_H = 15                 # about 10 px at 1024
SALT_BAND = (232, 228, 214)  # #e8e4d6
DATUM_Y0, DATUM_Y1 = 296, 304


def tile_field(p, rng, x0, y0, x1, y1, g, ox, oy, joint_a=0.35, base=TILE, joint=INK, glints=True):
    """Glazed tiles on a g-px grid anchored at (ox, oy): a matte tone per tile, matte joints."""
    cols = range(int(math.floor((x0 - ox) / g)), int(math.ceil((x1 - ox) / g)) + 1)
    rows = range(int(math.floor((y0 - oy) / g)), int(math.ceil((y1 - oy) / g)) + 1)
    lay = p.layer()
    p.rect(x0, y0, x1, y1, base, None)
    dk, hi = mix(base, SEAGLASS, 0.22), mix(base, PAPER_HI, 0.5)
    for j in rows:
        for i in cols:
            tx, ty = ox + i * g, oy + j * g
            t = rng.uniform(-1, 1)
            c = mix(base, dk, t * 0.3) if t > 0 else mix(base, hi, -t * 0.25)
            ax0, ay0, ax1, ay1 = max(tx, x0), max(ty, y0), min(tx + g, x1), min(ty + g, y1)
            if ax1 <= ax0 or ay1 <= ay0:
                continue
            p.rect(ax0, ay0, ax1, ay1, c, None)
            if glints and rng.random() < 0.55 and tx + g * 0.6 < x1 and ty + g * 0.3 < y1 and tx > x0 and ty > y0:
                p.line([(tx + g * 0.16, ty + g * 0.2), (tx + g * 0.16 + g * rng.uniform(0.2, 0.42), ty + g * 0.2)],
                       hi, max(1.5, g / 26))
    for i in cols:
        x = ox + i * g
        if x0 < x < x1:
            lay.line([(x, y0), (x, y1)], joint, max(2.0, g / 24))
    for j in rows:
        y = oy + j * g
        if y0 < y < y1:
            lay.line([(x0, y), (x1, y)], joint, max(2.0, g / 24))
    p.put(lay, joint_a)


def wall_base(stage):
    return WALL[stage]


def shell(p, stage, floor_y=900):
    """Ceiling band, limewash frieze, the glazed tile wall at the band's tone, dado course at
    y=600, the brass DATUM round the room, skirting and timber floor at `floor_y`."""
    rng = rng_for(500)
    base = wall_base(stage)
    joint, ja = GROUT[stage]
    p.rect(-4, -4, W + 4, 50, STORM, None)
    p.line([(-4, 36), (W + 4, 36)], STORM_HI, 2)
    p.rect(-4, 46, W + 4, 58, STORM, INK, 3)
    p.rect(-4, 58, W + 4, 100, mix(LIME, base, 0.25), None)
    lay = p.layer()
    for _ in range(12):
        x = rng.uniform(0, W)
        lay.arc(x, 80, rng.uniform(70, 150), 9, 200, 340, PAPER, 3)
    p.put(lay, 0.6)
    p.rect(-4, 98, W + 4, 112, SEAGLASS, INK, 2.5)
    p.line([(-4, 102), (W + 4, 102)], SEAGLASS_HI, 1.6)
    sk0 = floor_y - 18
    tile_field(p, rng, -4, WALL_TOP, W + 4, DADO_Y - 6, G, 0, DADO_Y, ja, base, joint)
    tile_field(p, rng, -4, DADO_Y + 6, W + 4, sk0 + 2, G, 0, DADO_Y, ja, mix(base, SEAGLASS_HI, 0.25), joint)
    p.rect(-4, DADO_Y - 8, W + 4, DADO_Y + 8, SEAGLASS, INK, 2.5)
    p.line([(-4, DADO_Y - 4), (W + 4, DADO_Y - 4)], SEAGLASS_HI, 2)
    p.rect(-4, sk0, W + 4, floor_y, STORM, INK, 2.5)
    p.line([(-4, sk0 + 4), (W + 4, sk0 + 4)], STORM_HI, 1.5)
    p.rect(-4, floor_y, W + 4, H + 4, TIMBER, INK, 3)
    y, k = floor_y, 0
    while y < H:
        hgt = 34 + k * 7
        p.line([(-4, y + 2.5), (W + 4, y + 2.5)], TIMBER_HI, 1.4)
        p.line([(-4, y + hgt), (W + 4, y + hgt)], TIMBER_DK, 2.5)
        x = rng.uniform(0, 300)
        while x < W:
            p.line([(x, y + 3), (x, y + hgt - 3)], TIMBER_DK, 2)
            x += rng.uniform(300, 520)
        y += hgt
        k += 1
    datum(p, DATUM_Y0, DATUM_Y1)


def wet_zone(p, stage, x0=-4, x1=W + 4, floor_y=900):
    """Below the tide mark the tiles stay wet: one flat darker tone, no mottle."""
    if stage not in TIDE_Y:
        return
    top = TIDE_Y[stage] + TIDE_H - 4
    lay = p.layer()
    lay.rect(x0, top, x1, floor_y - 18, mix(DAMP, STORM, 0.2), None)
    p.put(lay, 0.10 if stage == "sever" else {3: 0.14, 4: 0.17, 5: 0.2, 6: 0.22, 7: 0.24}[stage])


def streaks(p, stage, x0=-4, x1=W + 4, avoid=()):
    """Band 5+: wet runs down the tiles from the datum, flat and hard-edged. One seeded set,
    so each band keeps the last band's runs and adds longer, more numerous ones."""
    if stage not in (5, 6, 7):
        return
    rng = rng_for(560)
    n = {5: 9, 6: 15, 7: 22}[stage]
    grow = {5: 1.0, 6: 1.35, 7: 1.7}[stage]
    lay = p.layer()
    col = mix(DAMP, STORM, 0.25)
    for k in range(22):
        x = rng.uniform(x0 + 20, x1 - 20)
        wd = rng.uniform(7, 14)
        ln = rng.uniform(70, 190)
        if k >= n:
            continue
        if any(a <= x <= b for a, b in avoid):
            continue
        y0 = DATUM_Y1 + 2
        y1 = min(DADO_Y - 10, y0 + ln * grow)
        lay.rect(x - wd / 2, y0, x + wd / 2, y1, col, None, r=wd / 2)
        lay.ell(x, y1, wd * 0.75, wd * 0.9, col, None)
    p.put(lay, 0.5)


def tide_band(p, rng, stage, x0=-4, x1=W + 4):
    """The salt tide mark: one off-white matte band with a navy contour and a slightly irregular
    top edge, at one height round the room."""
    if stage not in TIDE_Y:
        return
    y = TIDE_Y[stage]
    pts = []
    x = x0
    while x <= x1 + 24:
        pts.append((x, y + rng.uniform(-3.2, 2.6) + 1.6 * math.sin(x * 0.013)))
        x += 24
    band = pts + [(x1 + 4, y + TIDE_H), (x0 - 4, y + TIDE_H)]
    p.poly(band, SALT_BAND, INK, 1.8)
    p.line([(x0, y + TIDE_H - 4), (x1, y + TIDE_H - 4)], mix(SALT_BAND, SEAGLASS, 0.25), 1.6)


def bloom(p, cx, cy, r, rng, op=1.0):
    """A damp bloom on the tiles: no outline, a darker centre stepping in flat tones, and three
    darker tide rims inside its edge."""
    def ring(scale):
        pts = []
        for i in range(30):
            a = 2 * math.pi * i / 30
            rr = r * scale * (1.0 + 0.07 * math.sin(a * 3 + cx) + rng.uniform(-0.03, 0.03))
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.9))
        return pts
    col = mix(DAMP, STORM, 0.15)
    rim = mix(DAMP, STORM, 0.4)
    fill = p.layer(col)
    for scale in (1.0, 0.66, 0.36):
        fill.poly(ring(scale), col, None)
    p.put_soft(fill, 2.0, 0.2 * op)
    rims = p.layer(rim)
    for scale, wd in ((0.84, 3.2), (0.56, 2.4), (0.3, 1.8)):
        rims.poly(ring(scale), None, rim, wd)
    p.put_soft(rims, 0.7, 0.32 * op)


def handprint(p, cx, cy, s=1.0, op=1.0):
    """A wet palm print, fingers up, in the bloom's flat tones (no outline)."""
    col = mix(DAMP, STORM, 0.3)
    lay = p.layer(col)
    lay.ell(cx, cy + 14 * s, 27 * s, 31 * s, col, None)
    for dx, top, wd in ((-21, -46, 9.5), (-7, -58, 10), (8, -56, 10), (22, -44, 9)):
        lay.rect(cx + (dx - wd / 2) * s, cy + top * s, cx + (dx + wd / 2) * s, cy, col, None, r=wd / 2 * s)
    lay.poly([(cx - 24 * s, cy + 10 * s), (cx - 50 * s, cy - 14 * s), (cx - 42 * s, cy - 22 * s),
              (cx - 16 * s, cy - 2 * s)], col, None)
    lay.ell(cx - 46 * s, cy - 18 * s, 6 * s, 6 * s, col, None)
    p.put_soft(lay, 0.8, 0.62 * op)


def lamp_pool(p, cx, cy, rx, ry, op):
    lay = p.layer(PAPER_HI)
    lay.ell(cx, cy, rx, ry, PAPER_HI, None)
    p.put_soft(lay, max(rx, ry) * 0.35, op)


def grade(im, stage):
    """Bands are painted, not graded. Sever is grey daylight."""
    if stage != "sever":
        return im
    rgb = im.convert("RGB")
    grey = rgb.convert("L").convert("RGB")
    rgb = Image.blend(rgb, grey, 0.42)
    cool = Image.new("RGB", rgb.size, mix(PAPER_HI, SEAGLASS_HI, 0.3))
    return Image.blend(rgb, cool, 0.08)


# ----------------------------------------------------------------------------- view A parts
#
# Left to right: stair door, basin, tank, reference socket, tilt rack, vault door (its far jamb
# 85 px inside the plate). The floor is raised to y=852 so a strip of it shows above the exits.

A_FLOOR = 852


def datum(p, y0, y1, x0=-4, x1=W + 4, tick=96, tick_len=7):
    p.rect(x0, y0, x1, y1, BRASS, INK, 2.2)
    p.line([(x0, y0 + 2), (x1, y0 + 2)], BRASS_HI, 1.4)
    x = 0
    while x <= x1:
        if x > x0:
            p.line([(x, y1 - 1), (x, y1 + tick_len)], INK, 1.8)
            p.line([(x, y0 + 1.5), (x, y1 - 1.5)], BRASS_LO, 1.4)
        x += tick


def plumb_bracket(p, cx, cy, s=1.0):
    p.rect(cx - 13 * s, cy - 22 * s, cx + 13 * s, cy + 12 * s, BRASS_LO, INK, 2.2, r=3 * s)
    screw(p, cx, cy - 14 * s, 3.4 * s)
    p.ell(cx, cy, 8 * s, 8 * s, BRASS_HI, INK, 2.2)
    p.ell(cx, cy, 3 * s, 3 * s, SLOT, None)


STAIR = (12, 314, 192, A_FLOOR)          # frame
STAIR_LEAF = (26, 330, 178, A_FLOOR)


def return_door(p):
    x0, y0, x1, y1 = STAIR
    lx0, ly0, lx1, ly1 = STAIR_LEAF
    p.rect(x0, y0, x1, y1, STORM_DK, INK, 3)
    p.rect(x0 + 8, y0 + 8, x1 - 8, y1, STORM, INK, 2)
    p.rect(lx0, ly0, lx1, ly1, STORM_HI, INK, 3)
    pan = mix(STORM_HI, STORM, 0.35)
    for py0, py1 in ((410, 570), (640, 820)):
        p.rect(lx0 + 16, py0, lx1 - 16, py1, pan, INK, 2.2, r=4)
        p.line([(lx0 + 18, py0 + 3), (lx1 - 18, py0 + 3)], mix(STORM_HI, PAPER, 0.25), 1.6)
    for y in range(344, int(ly1) - 4, 32):
        rivet(p, lx0 + 8, y)
        rivet(p, lx1 - 8, y)
    for x in range(lx0 + 36, lx1 - 10, 30):
        rivet(p, x, 398)
        rivet(p, x, 602)
    for y in (380, 790):
        p.rect(x0 + 2, y - 18, x0 + 34, y + 18, BRASS_LO, INK, 2.2, r=3)
        p.ell(x0 + 6, y, 6, 16, BRASS, INK, 1.8)
    plate(p, 58, 360, 146, 390)


def bolt_housing(p, home):
    """The stair bolt: a tall brass housing with a knob riding a slot. Home, the knob sits at the
    right end and the bolt is shot into the jamb keeper; drawn back, the knob is left, keeper empty."""
    p.rect(174, 602, 192, 638, STORM_DK, INK, 2)          # keeper on the jamb
    p.rect(180, 613, 190, 627, SLOT, None)
    p.rect(116, 584, 174, 636, BRASS_LO, INK, 2.4, r=4)
    p.line([(120, 588), (170, 588)], BRASS, 1.6)
    p.rect(124, 592, 166, 600, SLOT, None)                # the knob's slot
    rod = (130, 614, 192, 626) if home else (120, 614, 172, 626)
    p.rect(*rod, BRASS_HI, INK, 2)
    kx = 158 if home else 130
    p.rect(kx - 4, 594, kx + 4, 616, BRASS, INK, 1.8, r=2)
    p.ell(kx, 594, 6, 6, BRASS_HI, INK, 2)
    for y in (606, 630):
        screw(p, 122, y, 2.4)
        screw(p, 168, y, 2.4)


def bolt_closed(p):
    bolt_housing(p, True)


BASIN_DX = -26


def basin(p):
    prev = p.at(BASIN_DX)
    # tap on the wall: flange, body, cross handle and a short downturned nozzle
    p.ell(300, 522, 14, 14, BRASS_LO, INK, 2.2)
    p.rect(290, 512, 310, 540, BRASS, INK, 2.4, r=4)
    p.line([(294, 516), (294, 536)], BRASS_HI, 1.8)
    p.rect(298, 498, 302, 512, BRASS, INK, 1.4)
    p.line([(282, 498), (318, 498)], INK, 7)
    p.line([(282, 498), (318, 498)], BRASS_HI, 3.4)
    p.poly([(295, 538), (305, 538), (306, 556), (308, 561), (292, 561), (294, 556)], BRASS, INK, 2.2)
    # pedestal, down to the raised floor
    fy = A_FLOOR
    p.poly([(276, 742), (324, 742), (330, fy - 24), (344, fy), (256, fy), (270, fy - 24)], ENAMEL, INK, 3)
    p.line([(316, 748), (320, fy - 28)], PAPER_HI, 2.2)
    p.line([(282, 750), (278, fy - 28)], ENAMEL_DK, 2.6)
    # a deep rectangular laboratory basin, its front cut away so the pool shows
    outer = [(230, 606), (378, 606), (378, 718)] + bezier((378, 718), (378, 746), (350, 746), 8)[1:] + \
        [(258, 746)] + bezier((258, 746), (230, 746), (230, 718), 8)[1:]
    inner = [(243, 612), (365, 612), (365, 712)] + bezier((365, 712), (365, 732), (345, 732), 8)[1:] + \
        [(263, 732)] + bezier((263, 732), (243, 732), (243, 712), 8)[1:]
    sh = p.layer()
    sh.poly([(x + 6, y + 6) for x, y in outer], SHADOW, None)
    p.put_soft(sh, 5, 0.3)
    p.poly(outer, ENAMEL, INK, 3)
    p.poly(inner, ENAMEL_DK, INK, 2.2)
    p.line([(247, 620), (247, 708)], mix(ENAMEL_DK, SEAGLASS, 0.3), 2)
    # the pool: a filled matte mass, its surface slanted 8 degrees rising to the right
    t = math.tan(math.radians(8))
    water = p.layer()
    surf = [(200, 700 + 100 * t), (400, 700 - 100 * t)]
    water.poly(surf + [(400, 760), (200, 760)], WATER_PAINT, None)
    water.line(surf, INK, 2.6)
    p.put(water, 1.0, poly_mask([(x + BASIN_DX, y) for x, y in inner]))
    p.poly(inner, None, INK, 2.4)
    # rim slab and its glaze line
    p.rect(226, 594, 384, 612, ENAMEL, INK, 3, r=5)
    p.line([(232, 599), (378, 599)], PAPER_HI, 2)
    # drain chain from a rim ring down into the pool, and the plug on its seat
    p.ell(352, 608, 4, 4, None, BRASS_LO, 2)
    pts = bezier((352, 612), (338, 700), (304, 728), 15)
    for x, y in pts:
        p.ell(x, y, 2.6, 3.4, None, BRASS_LO if y < 690 else mix(BRASS_LO, SEAGLASS, 0.5), 1.4)
    p.ell(302, 729, 8, 4, SOOT, INK, 1.6)
    p.restore(prev)


TANK = (366, 400, 706, 800)
TANK_IN = (386, 430, 686, 780)
TANK_LEGS = (378, 462, 610, 694)
LAMP_A = (536, 360)


def tank_frame(p):
    x0, y0, x1, y1 = TANK
    ix0, iy0, ix1, iy1 = TANK_IN
    for r in ((x0, y0, x1, iy0), (x0, iy1, x1, y1), (x0, y0, ix0, y1), (ix1, y0, x1, y1)):
        p.rect(*r, STORM, None)
    p.rect(x0, y0, x1, y1, None, INK, 3)
    p.rect(ix0, iy0, ix1, iy1, None, INK, 3)
    p.rect(x0 - 6, y0 - 6, x1 + 6, y0 + 8, BRASS_LO, INK, 2.4, r=2)
    p.line([(x0 - 4, y0 - 2), (x1 + 4, y0 - 2)], BRASS_HI, 1.6)
    p.line([(ix0 - 6, iy0), (ix0 - 6, iy1)], STORM_HI, 1.6)
    p.line([(ix1 + 6, iy0), (ix1 + 6, iy1)], STORM_DK, 1.6)
    for x in range(x0 + 12, x1 - 6, 30):
        rivet(p, x, y0 + 18, 2.8)
        rivet(p, x, y1 - 10, 2.8)
    for y in range(iy0 + 14, iy1, 30):
        rivet(p, x0 + 10, y, 2.8)
        rivet(p, x1 - 10, y, 2.8)


def tank(p):
    x0, y0, x1, y1 = TANK
    ix0, iy0, ix1, iy1 = TANK_IN
    sh = p.layer()
    sh.rect(x0 + 10, y0 + 10, x1 + 12, y1 + 8, SHADOW, None)
    p.put_soft(sh, 8, 0.3)
    for i, lx in enumerate(TANK_LEGS):
        back = i in (1, 2)
        col = STORM_DK if back else STORM
        p.rect(lx - 9, y1 - 4, lx + 9, A_FLOOR - 6, col, INK, 2.4)
        p.rect(lx - 14, A_FLOOR - 10, lx + 14, A_FLOOR, col, INK, 2.2, r=2)
        if not back:
            p.line([(lx - 4, y1), (lx - 4, A_FLOOR - 12)], STORM_HI, 1.6)
    p.rect(x0 + 6, 818, x1 - 6, 828, STORM_DK, INK, 2)          # stretcher
    p.rect(ix0, iy0, ix1, iy1, GLASS, None)
    tank_frame(p)
    # the hydrometer float on its wire from the rim
    fx = ix1 - 36
    p.ell(fx, y0 + 4, 5, 5, BRASS_HI, INK, 1.6)
    p.line([(fx, y0 + 9), (fx, 520)], INK, 1.6)
    p.rect(fx - 3, 520, fx + 3, 534, GLASS_HI, INK, 1.6)
    p.ell(fx, 552, 10, 20, GLASS_HI, INK, 2)
    p.ell(fx, 566, 6, 6, BRASS, INK, 1.4)
    p.line([(fx - 4, 540), (fx - 4, 556)], PAPER_HI, 1.6)


def wall_lamp(p, cx, cy, lit=True):
    p.rect(cx - 9, cy - 88, cx + 9, cy - 62, BRASS_LO, INK, 2.2, r=3)
    arm = bezier((cx, cy - 70), (cx + 34, cy - 70), (cx, cy - 22), 14)
    p.line(arm, INK, 7)
    p.line(arm, BRASS, 3.5)
    p.ell(cx, cy - 22, 6, 6, BRASS_HI, INK, 1.8)
    p.poly([(cx - 14, cy - 18), (cx + 14, cy - 18), (cx + 44, cy + 14), (cx - 44, cy + 14)], SEAGLASS, INK, 3)
    p.line([(cx - 8, cy - 13), (cx - 34, cy + 9)], SEAGLASS_HI, 2.4)
    p.rect(cx - 46, cy + 12, cx + 46, cy + 18, BRASS_LO, INK, 2)
    if lit:
        p.ell(cx, cy + 21, 9, 5, AMBER, INK, 1.6)
        p.ell(cx - 2, cy + 21, 3, 2, PAPER_HI, None)
    else:
        p.ell(cx, cy + 21, 9, 5, PAPER, INK, 1.6)


SOCKET = (716, 318, 846, 680)
SOCKET_C = (781, 492)
SOCKET_CARD = (722, 326, 840, 380)


def conduit(p):
    sx = SOCKET_C[0]
    pts = [(sx, SOCKET[3] - 6), (sx, 820), (190, 820), (190, 800)]
    p.line(pts, INK, 11)
    p.line(pts, STORM_HI, 6)
    p.line([(sx - 3, SOCKET[3]), (sx - 3, 816)], mix(STORM_HI, PAPER, 0.3), 1.4)
    for x in range(sx - 60, 220, -118):
        p.rect(x - 4, 812, x + 4, 828, BRASS_LO, INK, 1.6)
    p.rect(178, 786, 204, 806, STORM_DK, INK, 2.2, r=2)       # junction box on the stair jamb


def socket(p):
    x0, y0, x1, y1 = SOCKET
    sh = p.layer()
    sh.rect(x0 + 6, y0 + 8, x1 + 6, y1 + 6, SHADOW, None)
    p.put_soft(sh, 5, 0.3)
    p.rect(x0, y0, x1, y1, BRASS, INK, 3, r=10)
    p.line([(x0 + 6, y0 + 8), (x0 + 6, y1 - 10)], BRASS_HI, 2)
    p.rect(x0 + 8, 390, x1 - 8, y1 - 10, STORM, INK, 2.2, r=6)
    cx, cy = SOCKET_C
    p.ell(cx, cy, 58, 58, BRASS_LO, INK, 2.6)
    p.arc(cx, cy, 55, 55, 200, 330, BRASS_HI, 2.2)
    p.ell(cx, cy, 50, 50, SLOT, INK, 2.6)
    p.ell(cx, cy, 38, 38, None, mix(SLOT, STORM_HI, 0.5), 1.6)
    for a in (45, 135, 225, 315):
        screw(p, cx + 54 * math.cos(math.radians(a)), cy + 54 * math.sin(math.radians(a)), 2.6)
    # tag slot
    p.rect(cx - 36, 592, cx + 36, 610, BRASS_LO, INK, 2.2, r=3)
    p.rect(cx - 28, 598, cx + 28, 604, SOOT, None)
    for y in (640, 662):
        p.line([(x0 + 14, y), (x1 - 14, y)], STORM_HI, 2)
    # the reference card: no pins, so the two words have the whole width
    c0, c1, c2, c3 = SOCKET_CARD
    card(p, c0, c1, c2, c3, PAPER_HI, ruled=0, pins=False)


RACK_CUPS = ((916, 668), (1028, 668), (1140, 668))
RACK_X = (848, 1200)
CANT = 12.0


def cradle(p, cx, cy, ang, s, empty_hub=True, full=False):
    """Clamp arms and a base cup for a jar whose interior centre sits at (cx, cy); built at
    close-up scale (jar 160x272, centre 152 from its top) then scaled by s and rotated.
    Stations carry short arms that grip the lower jar; the TIP cradle (full) grips it whole."""
    def T(pts):
        return [rot((cx + x * s, cy + y * s), (cx, cy), ang) for x, y in pts]

    w = max(1.6, 3.0 * min(1.0, s * 1.6))
    top = -92 if full else 18
    if empty_hub:
        p.ell(cx, cy, 16 * s, 16 * s, BRASS_LO, INK, w)
        p.ell(cx, cy, 6 * s, 6 * s, BRASS_HI, INK, w * 0.7)
    for sg in (-1, 1):
        arm = [(sg * 84, top), (sg * 97, top), (sg * 97, 134), (sg * 84, 134)]
        p.poly(T(arm), BRASS, INK, w)
        p.line(T([(sg * 90.5, top + 8), (sg * 90.5, 126)]), BRASS_HI if sg < 0 else BRASS_LO, w * 0.7)
        pad = [(sg * 84, top + 4), (sg * 76, top + 4), (sg * 76, top + 34), (sg * 84, top + 34)]
        p.poly(T(pad), BRASS_LO, INK, w * 0.8)
        kx, ky = T([(sg * 100, top + 16)])[0]
        p.ell(kx, ky, 8 * s, 8 * s, BRASS_HI, INK, w * 0.8)
    cup = [(-97, 120), (97, 120), (97, 134)] + bezier((97, 134), (90, 152), (60, 152), 6)[1:] + \
        [(-60, 152)] + bezier((-60, 152), (-90, 152), (-97, 134), 6)[1:]
    p.poly(T(cup), BRASS_LO, INK, w)
    p.line(T([(-90, 126), (90, 126)]), BRASS_HI, w * 0.7)


def rack(p):
    x0, x1 = RACK_X
    # the TIP mechanism for show: a wall rail with a drive box and a crank above its right end
    p.rect(x0 + 4, 552, x1 - 4, 572, BRASS_LO, INK, 2.6, r=4)
    p.line([(x0 + 8, 557), (x1 - 8, 557)], BRASS_HI, 1.6)
    for x in range(x0 + 20, x1 - 50, 46):
        screw(p, x, 566, 2.4)
    bx = x1 - 50
    p.rect(bx, 512, bx + 44, 556, STORM, INK, 2.4, r=4)
    p.ell(bx + 22, 534, 12, 12, BRASS_LO, INK, 2)
    p.line([(bx + 22, 534), (bx + 36, 514)], INK, 6)
    p.line([(bx + 22, 534), (bx + 36, 514)], BRASS, 3)
    p.ell(bx + 37, 512, 4.5, 4.5, BRASS_HI, INK, 1.6)
    s = 0.55
    for cx, cy in RACK_CUPS:
        p.rect(cx - 5, cy, cx + 5, 756, STORM, INK, 2)
    p.rect(x0, 754, x1, 768, TIMBER_HI, INK, 2.8)
    p.line([(x0 + 2, 758), (x1 - 2, 758)], mix(TIMBER_HI, PAPER, 0.4), 1.6)
    p.rect(x0 + 6, 768, x1 - 6, 800, TIMBER, INK, 2.6)
    for bx in (x0 + 26, x1 - 26):
        p.poly([(bx - 8, 800), (bx + 8, 800), (bx + 8, 838), (bx - 8, 814)], STORM, INK, 2.2)
    for cx, cy in RACK_CUPS:
        cradle(p, cx, cy, CANT, s)
        plate(p, cx - 28, 772, cx + 28, 794)


VAULT = (1208, 318, 1363, A_FLOOR)        # frame, far jamb 85 px inside the plate
VAULT_LEAF = (1222, 386, 1350, A_FLOOR)
VAULT_PLATE = (1236, 338, 1336, 366)      # on the transom, never on the leaf
VAULT_WHEEL = (1290, 620)
VAULT_GAP = 68                            # ajar: about 48 px at 1024


def vault_frame(p):
    x0, y0, x1, y1 = VAULT
    p.rect(x0, y0, x1, y1, STEEL_DK, INK, 3)
    p.rect(x0 + 10, y0 + 8, x1 - 10, VAULT_LEAF[1] - 6, STEEL, INK, 2.4)        # transom
    for x in (x0 + 18, x1 - 18):
        rivet(p, x, y0 + 34, 2.6, STEEL_HI)
    plate(p, *VAULT_PLATE)
    lx0, ly0, lx1, ly1 = VAULT_LEAF
    p.rect(lx0 - 4, ly0 - 4, lx1 + 4, ly1, mix(STEEL_DK, SOOT, 0.3), INK, 2)


def vault_leaf(p, width=None):
    """The steel leaf, hinged on its left. `width` < full paints it swung open, foreshortened."""
    lx0, ly0, lx1, ly1 = VAULT_LEAF
    full = lx1 - lx0
    wd = full if width is None else width
    k = wd / full
    x1 = lx0 + wd
    p.rect(lx0, ly0, x1, ly1, STEEL, INK, 3)
    p.line([(lx0 + 6, ly0 + 6), (lx0 + 6, ly1 - 6)], STEEL_HI, 2)
    for y in (480, 790):
        p.rect(lx0, y - 10, x1, y + 10, STEEL_DK, INK, 2.2)
        n = max(2, int(wd / 24))
        for i in range(n):
            rivet(p, lx0 + 12 + i * (wd - 24) / max(1, n - 1), y, 2.6, STEEL_HI)
    for y in range(ly0 + 16, int(ly1) - 6, 28):
        rivet(p, x1 - 10 * k - 2, y, 2.6, STEEL_HI)
    for y in (440, 800):
        p.rect(lx0 - 14, y - 30, lx0 + 4, y + 30, STEEL_DK, INK, 2.2, r=4)
        p.line([(lx0 - 8, y - 24), (lx0 - 8, y + 24)], STEEL_HI, 1.6)
    # the wheel latch, foreshortened with the leaf
    cx = lx0 + (VAULT_WHEEL[0] - lx0) * k
    cy = VAULT_WHEEL[1]
    rx, ry = 44 * k, 44
    p.ell(cx, cy, rx + 4 * k, ry + 4, STEEL_DK, INK, 2.4)
    for i in range(6):
        a = math.radians(i * 60 + 15)
        q = (cx + rx * 0.9 * math.cos(a), cy + ry * 0.9 * math.sin(a))
        p.line([(cx, cy), q], INK, 7)
        p.line([(cx, cy), q], BRASS, 3.5)
    p.ell(cx, cy, rx * 0.9, ry * 0.9, None, INK, 7)
    p.ell(cx, cy, rx * 0.9, ry * 0.9, None, BRASS, 3.5)
    p.ell(cx, cy, max(5, 11 * k), 11, BRASS_HI, INK, 2.2)
    if width is not None:
        # the leaf's thickness, seen edge-on at its free side
        p.rect(x1, ly0 + 2, x1 + 10, ly1, STEEL_HI, INK, 2.4)


def vault_door(p):
    vault_frame(p)
    vault_leaf(p)


def turn_plate(p, x0=600, y0=850, x1=848, y1=914):
    sh = p.layer()
    sh.rect(x0 + 4, y0 + 6, x1 + 4, y1 + 4, SHADOW, None)
    p.put_soft(sh, 4, 0.35)
    p.rect(x0 + 4, y0 + 4, x1 - 4, y1 - 4, BRASS, INK, 3, r=8)
    p.rect(x0 + 12, y0 + 11, x1 - 12, y1 - 11, None, BRASS_LO, 2, r=5)
    for x, y in ((x0 + 18, y0 + 18), (x1 - 18, y0 + 18), (x0 + 18, y1 - 18), (x1 - 18, y1 - 18)):
        screw(p, x, y, 3.4)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    pts = [(cx + 26, cy + 12)] + [(cx + 26 * math.cos(math.radians(a)), cy - 2 + 14 * math.sin(math.radians(a)))
                                  for a in range(0, -181, -15)] + [(cx - 26, cy + 8)]
    p.line(pts, BRASS_LO, 8)
    p.line(pts, BRASS_HI, 4)
    p.poly([(cx - 40, cy + 4), (cx - 12, cy + 4), (cx - 26, cy + 20)], BRASS_HI, BRASS_LO, 2.4)


def floor_rings(p, cx=1032, cy=888):
    """Band 7: three rings on the floor under the rack, storm navy, heavy to light, fully above
    the exit bar."""
    lay = p.layer()
    for rx, ry, wd in ((70, 9, 6.0), (124, 17, 4.0), (178, 25, 2.4)):
        lay.ell(cx, cy, rx, ry, None, STORM, wd)
    p.put(lay, 0.85)


A_BLOOMS = ((110, 210, 74), (650, 196, 84), (1110, 200, 78))
A_HAND = (318, 430)
A_STREAK_AVOID = ((STAIR[0], STAIR[2]), (TANK[0] - 6, TANK[2] + 6), (SOCKET[0], SOCKET[2]),
                  (VAULT[0], VAULT[2]))


def paint_view_a(rng, stage, lamp=True, objects=True, pool=True):
    """The tank wall plate. `lamp` False leaves the wall lamp out, `objects` False stops at the
    bare wall (the sea overlays' masks and lamp patch) and `pool` False leaves out the lamp's
    cream light (the submerged plates); the defaults paint the approved plate, stroke for
    stroke."""
    p = Pen(W, H, rng, PAPER)
    srng = rng_for(700 + (0 if stage == "sever" else stage))
    shell(p, stage, A_FLOOR)
    wet_zone(p, stage, floor_y=A_FLOOR)
    streaks(p, stage, avoid=A_STREAK_AVOID)
    tide_band(p, rng_for(590), stage)
    if stage in (7, "sever"):
        op = 0.35 if stage == "sever" else 1.0
        brng = rng_for(595)
        for cx, cy, r in A_BLOOMS:
            bloom(p, cx, cy, r, brng, op)
        handprint(p, *A_HAND, s=1.0, op=op)
    if not pool:
        pass
    elif stage != "sever":
        lamp_pool(p, LAMP_A[0], LAMP_A[1] + 18, 170, 100, 0.36)
    else:
        lamp_pool(p, 724, 300, 700, 280, 0.18)
    if not objects:
        return p.done()
    view_a_objects(p, stage, lamp)
    return grade(p.done(), stage)


def view_a_objects(p, stage, lamp=True):
    plate(p, 878, 270, 974, 296)
    plumb_bracket(p, PLUMB_A[0], PLUMB_A[1])
    conduit(p)
    return_door(p)
    bolt_closed(p)
    basin(p)
    tank(p)
    if lamp:
        wall_lamp(p, LAMP_A[0], LAMP_A[1], stage != "sever")
    socket(p)
    rack(p)
    vault_door(p)
    if stage in (7,):
        floor_rings(p)
    turn_plate(p)


PLUMB_A = (1004, 300)


# ----------------------------------------------------------------------------- view B parts

BALANCE_POST = 490
BEAM_Y = 360
PAN_L = 380
TRAY = (540, 470, 680, 580)


def pendant(p, cx, cy, lit=True):
    p.line([(cx, 50), (cx, cy - 20)], INK, 3)
    p.rect(cx - 6, cy - 26, cx + 6, cy - 14, BRASS_LO, INK, 1.8)
    p.poly([(cx - 16, cy - 16), (cx + 16, cy - 16), (cx + 52, cy + 16), (cx - 52, cy + 16)], SEAGLASS, INK, 3)
    p.line([(cx - 10, cy - 11), (cx - 40, cy + 11)], SEAGLASS_HI, 2.4)
    p.rect(cx - 54, cy + 14, cx + 54, cy + 20, BRASS_LO, INK, 2)
    p.ell(cx, cy + 23, 10, 5, AMBER if lit else PAPER, INK, 1.6)
    if lit:
        p.ell(cx - 2, cy + 22, 3, 2, PAPER_HI, None)



def bench(p, stage=2):
    sh = p.layer()
    sh.rect(26, 600, 1430, 640, SHADOW, None)
    p.put_soft(sh, 10, 0.25)
    p.rect(24, 620, 1424, 884, TIMBER, INK, 3)
    for x in (400, 700, 1000, 1180):
        p.line([(x, 624), (x, 878)], TIMBER_DK, 2.6)
        p.line([(x + 3, 624), (x + 3, 878)], TIMBER_HI, 1.2)
    p.rect(36, 884, 1412, 900, STORM_DK, INK, 2.4)
    p.rect(14, 598, 1434, 624, TIMBER_HI, INK, 3, r=3)
    p.line([(18, 602), (1430, 602)], mix(TIMBER_HI, PAPER, 0.45), 1.8)
    cabinet_gauge(p, stage)
    cabinet_trap(p, stage)
    cabinet_drawers(p, stage)


GAUGE_B = (550, 736)
# The bench gauge creeps round with the bands; nothing on the station feeds it.
GAUGE_DEG = {2: -118, 3: -96, 4: -70, 5: -40, 6: -8, 7: 34, "sever": -118}


def cabinet_gauge(p, stage):
    """Door 1: a brass-cased gauge with a blank enamel face, its needle a little further round
    at every band."""
    x0, x1 = 420, 680
    p.rect(x0, 646, x1, 856, mix(TIMBER, TIMBER_DK, 0.3), INK, 2.2, r=3)
    p.line([(x0 + 4, 650), (x1 - 4, 650)], TIMBER_HI, 1.4)
    cx, cy = GAUGE_B
    p.rect(cx - 8, cy + 54, cx + 8, 846, BRASS_LO, INK, 2)          # the feed pipe, down into the floor
    p.ell(cx, cy, 64, 64, BRASS_LO, INK, 3)
    p.arc(cx, cy, 60, 60, 200, 320, BRASS_HI, 2.4)
    p.ell(cx, cy, 52, 52, ENAMEL, INK, 2.4)
    for k in range(9):
        a = math.radians(-225 + k * 33.75)
        p.line([(cx + 40 * math.cos(a), cy + 40 * math.sin(a)), (cx + 48 * math.cos(a), cy + 48 * math.sin(a))],
               INK, 2.6 if k % 2 == 0 else 1.6)
    p.arc(cx, cy, 44, 44, 0, 45, VIOLET, 5)                          # the last sector, a flat band
    a = math.radians(GAUGE_DEG[stage] - 90)
    tip = (cx + 44 * math.cos(a), cy + 44 * math.sin(a))
    tail = (cx - 12 * math.cos(a), cy - 12 * math.sin(a))
    p.line([tail, tip], INK, 4)
    p.ell(cx, cy, 7, 7, BRASS_HI, INK, 2)
    for x in (cx - 50, cx + 50):
        screw(p, x, cy + 70, 3.2)
    p.rect(cx - 16, 818, cx + 16, 828, BRASS, INK, 1.8, r=3)


def cabinet_trap(p, stage):
    """Door 2 is missing: an open bay with the bench drain's trap, salt crusting at the bend."""
    x0, x1 = 720, 980
    p.rect(x0, 646, x1, 856, SLOT, INK, 2.4, r=3)
    p.rect(x0 + 6, 650, x1 - 6, 664, mix(SLOT, STORM, 0.5), None)
    cx = 850
    pipe = [(cx, 640), (cx, 770)] + bezier((cx, 770), (cx, 820), (cx + 50, 820), 10)[1:] + \
        bezier((cx + 50, 820), (cx + 100, 820), (cx + 100, 770), 10)[1:] + [(cx + 100, 730), (x1 - 4, 730)]
    p.line(pipe, INK, 22)
    p.line(pipe, STEEL, 15)
    p.line([(x + -4, y) for x, y in pipe[:2]], STEEL_HI, 3)
    for y in (700, 760):
        p.rect(cx - 14, y - 6, cx + 14, y + 6, BRASS_LO, INK, 2)
    p.rect(cx + 40, 828, cx + 60, 838, BRASS_LO, INK, 1.8)            # cleaning plug
    if stage in TIDE_Y:
        # salt at the bend: one flat crust riding the trap's lowest curve
        h = {3: 6, 4: 8, 5: 10, 6: 12, 7: 14, "sever": 10}[stage]
        crust = bezier((cx - 10, 806), (cx + 50, 852), (cx + 110, 806), 14)
        top = [(x, y - h) for x, y in crust]
        p.poly(top + crust[::-1], SALT_BAND, INK, 1.6)
    if stage == 7:
        p.ell(cx + 50, 852, 5, 7, SEAGLASS_HI, INK, 1.6)               # a drop, held under the bend


def cabinet_drawers(p, stage):
    """The end bay: two drawers. From band 5 salt seals the top drawer's seam; from band 6 it
    has come open from inside, a dark gap with salt spilling over its lip."""
    x0, x1 = 1200, 1404
    p.rect(x0, 646, x1, 856, mix(TIMBER, TIMBER_DK, 0.3), INK, 2.2, r=3)
    gap = {6: 18, 7: 34}.get(stage, 0)
    # bottom drawer
    p.rect(x0 + 10, 756, x1 - 10, 846, OAK, INK, 2.4, r=3)
    p.rect(1302 - 26, 796, 1302 + 26, 806, BRASS, INK, 1.8, r=3)
    # top drawer: closed, or pushed out from inside by `gap`
    if gap:
        p.rect(x0 + 10, 656, x1 - 10, 744, SLOT, INK, 2.2, r=3)
    ty0 = 656 - gap
    sh = p.layer()
    if gap:
        sh.rect(x0 + 12, ty0 + 90, x1 - 8, ty0 + 96, SHADOW, None)
        p.put_soft(sh, 3, 0.5)
    p.rect(x0 + 10, ty0 + gap, x1 - 10, ty0 + 88 + gap, OAK, INK, 2.4, r=3)
    p.line([(x0 + 14, ty0 + gap + 4), (x1 - 14, ty0 + gap + 4)], OAK_HI, 1.4)
    p.rect(1302 - 26, ty0 + gap + 40, 1302 + 26, ty0 + gap + 50, BRASS, INK, 1.8, r=3)
    if gap:
        # the drawer's top edge, standing proud, and the salt brimming over it
        p.rect(x0 + 10, ty0, x1 - 10, ty0 + gap, OAK_DK, INK, 2.2)
        mound = [(x0 + 14, ty0 + 2)] + [(x, ty0 - 4 - 10 * math.sin((x - x0 - 14) / (x1 - x0 - 28) * math.pi)
                                          - (3 if (x // 16) % 2 else 0)) for x in range(x0 + 20, x1 - 14, 16)] + \
            [(x1 - 14, ty0 + 2)]
        p.poly(mound, SALT_BAND, INK, 1.8)
        spill = [(x1 - 40, ty0 + 2), (x1 - 14, ty0 + 2), (x1 - 8, ty0 + gap + 60), (x1 - 22, ty0 + gap + 60)]
        p.poly(spill, SALT_BAND, INK, 1.6)
    if stage in (5, 6, 7, "sever"):
        # salt along the top drawer's seam: flat, hard-edged
        y = ty0 + gap + 88
        p.poly([(x0 + 10, y - 3), (x1 - 10, y - 4), (x1 - 10, y + 6), (x0 + 10, y + 6)], SALT_BAND, INK, 1.4)


def register(p, open_=False):
    x0, y0, x1, y1 = 80, 640, 380, 790
    p.rect(x0, y0, x1, y1, OAK_DK, INK, 3, r=3)
    if not open_:
        p.rect(x0 + 12, y0 + 12, x1 - 12, y1 - 12, OAK, INK, 2.6, r=3)
        p.line([(x0 + 16, y0 + 16), (x1 - 16, y0 + 16)], OAK_HI, 1.6)
        drawer_face(p, x0 + 12, y0 + 12, x1 - 12, y1 - 12)
    else:
        p.rect(x0 + 10, y0 + 10, x1 - 10, y0 + 54, SLOT, INK, 2)
        # the cards standing in the pulled drawer, one gap
        xs = list(range(x0 + 22, x1 - 26, 18))
        gap = xs[len(xs) // 2 + 2]
        for x in xs:
            if x == gap:
                continue
            p.rect(x, y0 + 22, x + 13, y0 + 56, PAPER_HI, INK, 1.4, r=1)
        sh = p.layer()
        sh.rect(x0 + 4, y0 + 56, x1 + 4, y1 + 46, SHADOW, None)
        p.put_soft(sh, 6, 0.4)
        p.rect(x0 + 4, y0 + 52, x1 - 4, y1 + 40, OAK, INK, 2.8, r=3)
        p.line([(x0 + 8, y0 + 56), (x1 - 8, y0 + 56)], OAK_HI, 1.6)
        drawer_face(p, x0 + 4, y0 + 52, x1 - 4, y1 + 40)


def drawer_face(p, x0, y0, x1, y1):
    cx = (x0 + x1) / 2
    plate(p, cx - 50, y0 + 20, cx + 50, y0 + 46, PAPER_HI, BRASS_LO)
    py = y0 + 76
    p.rect(cx - 34, py - 7, cx + 34, py + 9, BRASS, INK, 2.4, r=8)
    p.line([(cx - 28, py - 3), (cx + 28, py - 3)], BRASS_HI, 1.6)
    screw(p, cx - 42, py + 1, 2.6)
    screw(p, cx + 42, py + 1, 2.6)


def balance(p):
    x = BALANCE_POST
    # base plinth and key bank
    p.rect(318, 580, 664, 600, BRASS_LO, INK, 2.6, r=3)
    p.line([(322, 584), (660, 584)], BRASS_HI, 1.6)
    p.rect(432, 516, 548, 582, STORM, INK, 2.6, r=5)
    p.rect(438, 522, 542, 532, BRASS_LO, INK, 1.6)
    for k in range(3):
        kx = 452 + k * 38
        p.rect(kx - 12, 542, kx + 12, 568, BRASS_LO, INK, 2, r=3)
        p.rect(kx - 9, 538, kx + 9, 556, ENAMEL, INK, 1.8, r=3)
    # post with the pressure-pin collar
    p.rect(x - 8, 368, x + 8, 518, BRASS, INK, 2.6)
    p.line([(x - 3, 372), (x - 3, 514)], BRASS_HI, 2)
    p.rect(x - 16, 432, x + 16, 452, BRASS_LO, INK, 2.4, r=3)
    p.rect(x + 16, 438, x + 34, 446, BRASS_HI, INK, 1.8, r=2)
    p.ell(x + 36, 442, 5, 5, BRASS_HI, INK, 1.6)
    # pillar cap and beam
    p.poly([(x - 16, 372), (x + 16, 372), (x + 6, 350), (x - 6, 350)], BRASS_LO, INK, 2.4)
    bl, br = PAN_L - 12, 622
    p.poly([(bl, BEAM_Y - 4), (x - 10, BEAM_Y - 8), (x + 10, BEAM_Y - 8), (br, BEAM_Y - 4),
            (br, BEAM_Y + 4), (x + 10, BEAM_Y + 9), (x - 10, BEAM_Y + 9), (bl, BEAM_Y + 4)], BRASS, INK, 2.6)
    p.line([(bl + 6, BEAM_Y - 2), (br - 6, BEAM_Y - 2)], BRASS_HI, 1.6)
    p.poly([(x - 8, BEAM_Y - 22), (x + 8, BEAM_Y - 22), (x, BEAM_Y - 2)], BRASS_HI, INK, 2.2)
    p.ell(x, BEAM_Y, 6, 6, BRASS_HI, INK, 2)
    # left sample pan
    p.ell(PAN_L, BEAM_Y + 8, 5, 5, None, INK, 2)
    for dx in (-44, 44):
        p.line([(PAN_L, BEAM_Y + 12), (PAN_L + dx, 534)], INK, 2)
    p.poly([(PAN_L - 52, 532), (PAN_L + 52, 532), (PAN_L + 38, 550), (PAN_L - 38, 550)], BRASS, INK, 2.6)
    p.line([(PAN_L - 44, 536), (PAN_L + 44, 536)], BRASS_HI, 1.8)
    # right pan: the felt-lined control tray, a stitched felt cushion bedded in a brass dish
    tx0, ty0, tx1, ty1 = TRAY
    p.ell(br - 12, BEAM_Y + 8, 5, 5, None, INK, 2)
    for x in (tx0 + 10, tx1 - 10):
        p.line([(br - 12, BEAM_Y + 12), (x, 492)], INK, 2)
    p.rect(tx0 + 4, 490, tx1 - 4, 566, FELT, INK, 2.6, r=14)
    p.rect(tx0 + 12, 498, tx1 - 12, 558, None, mix(FELT, PAPER_HI, 0.45), 1.6, r=9)
    lay = p.layer()
    x = tx0 + 16
    while x < tx1 - 18:
        lay.line([(x, 498), (x + 5, 498)], FELT_DK, 1.4)
        lay.line([(x, 558), (x + 5, 558)], FELT_DK, 1.4)
        x += 10
    p.put(lay)
    p.line([(tx0 + 16, 495), (tx1 - 30, 495)], mix(FELT, PAPER_HI, 0.5), 2)
    dish = [(tx0, 550), (tx1, 550), (tx1 - 8, 572)] + bezier((tx1 - 8, 572), (tx1 - 20, 582), (tx1 - 36, 582), 6)[1:] + \
        [(tx0 + 36, 582)] + bezier((tx0 + 36, 582), (tx0 + 20, 582), (tx0 + 8, 572), 6)[1:]
    p.poly(dish, BRASS, INK, 2.8)
    p.line([(tx0 + 6, 555), (tx1 - 6, 555)], BRASS_HI, 1.8)


def sample_cards(p):
    for k in range(3):
        x0 = 60 + k * 76
        card(p, x0, 160, x0 + 68, 360, PAPER_HI, ruled=18)
        # the stamp-shaped blank box: a perforated edge
        sx0, sy0, sx1, sy1 = x0 + 14, 186, x0 + 54, 226
        p.rect(sx0, sy0, sx1, sy1, PAPER, mix(INK, PAPER, 0.4), 1.4)
        for t in range(6):
            for (ax, ay) in ((sx0 + t * 8, sy0), (sx0 + t * 8, sy1), (sx0, sy0 + t * 8), (sx1, sy0 + t * 8)):
                p.ell(ax, ay, 1.8, 1.8, PAPER_HI, None)


FRAME_B = (742, 352, 958, 472)


def easel(p):
    p.line([(850, 334), (758, 600)], INK, 12)
    p.line([(850, 334), (758, 600)], OAK, 7)
    p.line([(850, 334), (942, 600)], INK, 12)
    p.line([(850, 334), (942, 600)], OAK, 7)
    p.line([(850, 336), (850, 600)], INK, 10)
    p.line([(850, 336), (850, 600)], OAK_DK, 5)
    p.ell(850, 336, 7, 7, BRASS, INK, 2)
    p.rect(752, 472, 948, 484, OAK_HI, INK, 2.4, r=2)


def spec_frame(p):
    x0, y0, x1, y1 = FRAME_B
    p.rect(x0, y0, x1, y1, BRASS, INK, 3, r=4)
    p.line([(x0 + 5, y0 + 5), (x1 - 5, y0 + 5)], BRASS_HI, 1.8)
    for k in range(3):
        sx = x0 + 12 + k * 66
        p.rect(sx, y0 + 14, sx + 60, y0 + 74, FELT_DK, INK, 2, r=2)
        p.line([(sx + 3, y0 + 18), (sx + 57, y0 + 18)], SHADOW, 1.6)
    p.rect(x0 + 14, y0 + 84, x0 + 104, y0 + 106, mix(BRASS_LO, SLOT, 0.3), INK, 1.8, r=2)
    p.rect(x0 + 114, y0 + 88, x1 - 14, y0 + 102, BRASS_LO, INK, 1.8, r=2)



def frame_tray(p):
    x0, y0, x1, y1 = 748, 530, 952, 598
    sh = p.layer()
    sh.rect(x0 + 4, y0 + 4, x1 + 6, y1 + 3, SHADOW, None)
    p.put_soft(sh, 4, 0.3)
    p.rect(x0, y0, x1, y1, mix(GLASS, SEAGLASS_HI, 0.4), INK, 2.6, r=3)
    for k in range(3):
        rx = x0 + 10 + k * 66
        p.rect(rx, y0 + 14, rx + 52, y1 - 10, FELT, mix(INK, FELT, 0.4), 1.6, r=2)
    p.line([(x0 + 6, y0 + 8), (x0 + 6, y1 - 6)], GLASS_HI, 2)
    p.rect(x0 - 2, y0 - 4, x1 + 2, y0 + 4, BRASS_LO, INK, 2, r=2)


def frame_lid(p, open_):
    x0, y0, x1 = 748, 530, 952
    if not open_:
        p.rect(x0 - 4, y0 - 10, x1 + 4, y0 + 2, GLASS, INK, 2.4, r=2)
        p.line([(x0 + 10, y0 - 6), (x1 - 40, y0 - 6)], GLASS_HI, 2)
        p.rect(x1 - 30, y0 - 14, x1 - 14, y0 - 8, BRASS, INK, 1.6, r=2)
        return
    # the lid propped open on its hinges, standing up behind the tray, tipped slightly back
    lid = [(x0 + 6, y0 - 4), (x1 - 6, y0 - 4), (x1 - 2, y0 - 46), (x0 + 2, y0 - 46)]
    lay = p.layer()
    lay.poly(lid, GLASS + (255,), None)
    p.put(lay, 0.55)
    p.poly(lid, None, INK, 2.4)
    p.line([(x0 + 24, y0 - 10), (x0 + 36, y0 - 40)], GLASS_HI, 2.6)
    p.line([(x0 + 50, y0 - 10), (x0 + 56, y0 - 26)], GLASS_HI, 1.6)
    p.rect(x1 - 30, y0 - 42, x1 - 14, y0 - 36, BRASS, INK, 1.6, r=2)
    p.line([(x1 - 6, y0 - 4), (x1 + 8, y0 - 34)], INK, 2)   # stay


JAR_B = (974, 400, 1178, 600)


def bell_jar(p):
    x0, y0, x1, y1 = JAR_B
    cx = (x0 + x1) / 2
    # base plate
    p.rect(x0 - 2, 584, x1 + 2, 600, OAK, INK, 2.6, r=3)
    p.line([(x0 + 2, 588), (x1 - 2, 588)], OAK_HI, 1.6)
    # glass: a pale tint, ink contour, stopper
    body = [(x0 + 8, 584), (x0 + 8, 452)] + bezier((x0 + 8, 452), (x0 + 10, 418), (cx - 16, 418), 10)[1:] + \
        [(cx + 16, 418)] + bezier((cx + 16, 418), (x1 - 10, 418), (x1 - 8, 452), 10)[1:] + [(x1 - 8, 584)]
    tint = p.layer()
    tint.poly(body, GLASS + (255,), None)
    p.put(tint, 0.38)
    p.poly(body, None, INK, 2.8)
    p.rect(cx - 16, 404, cx + 16, 420, mix(GLASS, SEAGLASS, 0.35), INK, 2.4, r=3)
    p.ell(cx, 400, 12, 7, mix(GLASS, SEAGLASS, 0.35), INK, 2.2)
    # highlights kept clear of the inscription area (x 1030-1140, y 450-560)
    p.line([(x0 + 15, 456), (x0 + 15, 576)], GLASS_HI, 3)
    p.line([(x1 - 15, 470), (x1 - 15, 560)], GLASS_HI, 2)
    p.line([(x0 + 22, 436), (cx - 20, 424)], GLASS_HI, 2.4)
    p.line([(x0 + 12, 578), (x1 - 12, 578)], mix(GLASS, SEAGLASS, 0.3), 2)


RACK_B = (1190, 360, 1410, 600)
TUBES = [1214 + k * 25.5 for k in range(8)]
TUBE_HW = 11
TUBE_Y = (386, 572)


def tube_rack(p):
    x0, y0, x1, y1 = RACK_B
    sh = p.layer()
    sh.rect(x0 + 6, y0 + 8, x1 + 6, y1, SHADOW, None)
    p.put_soft(sh, 5, 0.3)
    p.rect(x0, 572, x1, 600, OAK, INK, 2.6, r=2)        # base
    for x in (x0 + 6, x1 - 6):
        p.rect(x - 7, y0 + 10, x + 7, 598, OAK_DK, INK, 2.2)
    for t in TUBES:
        p.rect(t - TUBE_HW, TUBE_Y[0], t + TUBE_HW, TUBE_Y[1], GLASS, INK, 2.2, r=9)
        p.line([(t - 6, TUBE_Y[0] + 20), (t - 6, TUBE_Y[1] - 14)], GLASS_HI, 1.6)
        p.rect(t - 10, TUBE_Y[0] - 16, t + 10, TUBE_Y[0] + 4, TIMBER_HI, INK, 2, r=3)   # cork stopper
    p.rect(x0, 448, x1, 466, OAK, INK, 2.6, r=2)        # the holding bar the tubes pass through
    p.line([(x0 + 4, 452), (x1 - 4, 452)], OAK_HI, 1.6)
    for t in TUBES:
        p.rect(t - TUBE_HW - 1, 450, t + TUBE_HW + 1, 464, SLOT, None)
        p.rect(t - TUBE_HW, 448, t + TUBE_HW, 466, GLASS, INK, 1.8)
        p.line([(t - 6, 450), (t - 6, 464)], GLASS_HI, 1.4)


B_BLOOMS = ((640, 200, 82), (1300, 214, 76), (980, 170, 60))
B_STREAK_AVOID = ((60, 290),)
# Where the tide mark crosses the cabinet front (it skips the gauge and the open bay).
B_CABINET_TIDE = ((24, 482), (618, 716), (984, 1424))


def paint_view_b(rng, stage, lamp=True, objects=True, clear_tide=False):
    """The bench plate; `lamp` and `objects` as paint_view_a. `clear_tide`: where the tide mark
    stands behind or across the bench (bands 3, 4), it is a clear sea-glass water line, not the
    off-white salt strip."""
    p = Pen(W, H, rng, PAPER)
    shell(p, stage)
    wet_zone(p, stage)
    streaks(p, stage, avoid=B_STREAK_AVOID)
    water = clear_tide and stage in TIDE_Y and TIDE_Y[stage] > 624
    # with `water` the salt strip goes to a discarded layer: it still draws its stroke widths
    # from the plate's generator, so every other stroke stays exactly as approved
    tide_band(p.layer() if water else p, rng_for(591), stage)
    if stage in (7, "sever"):
        op = 0.35 if stage == "sever" else 1.0
        brng = rng_for(596)
        for cx, cy, r in B_BLOOMS:
            bloom(p, cx, cy, r, brng, op)
    if stage != "sever":
        lamp_pool(p, 490, 210, 190, 130, 0.36)
    else:
        lamp_pool(p, 724, 300, 700, 280, 0.18)
    if not objects:
        return p.done()
    view_b_objects(p, stage, lamp, water)
    return grade(p.done(), stage)


def water_line(p, y, x0=-4, x1=W + 4):
    """Clear painted water where a salt tide mark would stand: one flat sea-glass line at 60%."""
    lay = p.layer()
    lay.rect(x0, y + TIDE_H / 2 - 2, x1, y + TIDE_H / 2 + 2, SEAGLASS, None)
    p.put(lay, 0.6)


PENDANT_B = (490, 120)


def view_b_objects(p, stage, lamp=True, water=False):
    if lamp:
        pendant(p, PENDANT_B[0], PENDANT_B[1], stage != "sever")
    sample_cards(p)
    bench(p, stage)
    if stage in TIDE_Y and TIDE_Y[stage] > 624:
        trng = rng_for(592)
        for x0, x1 in B_CABINET_TIDE:
            tide_band(p.layer() if water else p, trng, stage, x0, x1)
    if water:
        water_line(p, TIDE_Y[stage])
    register(p)
    easel(p)
    frame_tray(p)
    balance(p)
    bell_jar(p)
    tube_rack(p)
    turn_plate(p)


# ----------------------------------------------------------------------------- view A overlays

def paint_a_tank_glass(rng):
    p = Pen(W, H, rng)
    ix0, iy0, ix1, iy1 = TANK_IN
    hi = p.layer()
    hi.rect(ix0 + 24, iy0 + 8, ix0 + 40, iy1 - 10, GLASS_HI, None)
    hi.rect(ix0 + 54, iy0 + 30, ix0 + 60, iy1 - 60, GLASS_HI, None)
    hi.rect(ix1 - 30, iy0 + 60, ix1 - 24, iy0 + 220, GLASS_HI, None)
    p.put(hi, 0.42)
    ink = p.layer()
    ink.line([(ix0 + 24, iy0 + 8), (ix0 + 24, iy1 - 10)], INK, 1.6)
    ink.line([(ix0 + 60, iy0 + 30), (ix0 + 60, iy1 - 60)], INK, 1.4)
    p.put(ink, 0.55)
    tank_frame(p)
    return p


REFL = (TANK_IN[0] + 8, TANK_IN[1] + 8, TANK_IN[2] - 8, TANK_IN[1] + 158)
WARM_GLASS = mix(GLASS, PAPER, 0.45)


def paint_a_reflect(rng, jars):
    """The rack as the tank glass remembers it, mirrored: rail, shelf, cradles and, for each of
    `jars` stations, a whole jar silhouette (lid, body, water, label). Painted warm and solid; the
    view lays it on the glass at about 40%."""
    p = Pen(W, H, rng)
    lay = p.layer()
    x0, y0, x1, y1 = REFL
    rx0, rx1 = RACK_X
    s = 0.36
    lay.rect(x0 - 4, y0 + 4, x1 + 4, y0 + 14, BRASS_LO, INK, 1.6)          # the TIP rail
    lay.rect(x0 - 4, y1 - 14, x1 + 4, y1 + 4, TIMBER_HI, INK, 1.6)         # the shelf
    for k, (cx, cy) in enumerate(RACK_CUPS):
        mx = x1 - (cx - rx0) * (x1 - x0) / float(rx1 - rx0)
        my = y0 + 76
        cradle(lay, mx, my, -CANT, s, empty_hub=False)
        if k >= jars:
            continue
        def T(pts, sc=0.62):
            return [rot((mx + x * sc, my + y * sc), (mx, my), -CANT) for x, y in pts]
        body = T([(-44, -64), (44, -64), (44, 70), (-44, 70)])
        lay.poly(body, WARM_GLASS, INK, 1.8)
        lay.poly(T([(-40, 4), (40, 4), (40, 66), (-40, 66)]), mix(WATER_PAINT, TIMBER, 0.3), None)
        lay.line(T([(-40, 4), (40, 4)]), INK, 1.6)
        lay.poly(T([(-48, -80), (48, -80), (48, -62), (-48, -62)]), BRASS, INK, 1.8)
        lay.poly(T([(-20, 30), (20, 30), (20, 50), (-20, 50)]), PAPER_HI, INK, 1.2)
        lay.line(T([(-30, -50), (-30, 50)]), PAPER_HI, 2.0)
    p.put(lay, 1.0, rect_mask([REFL], feather=1))
    return p


def paint_a_vault_ajar(rng):
    """The vault leaf swung open toward the room: narrower (foreshortened on its hinge), and
    between its free edge and the jamb a flat inky void with one cold sea-glass sliver."""
    p = Pen(W, H, rng)
    lx0, ly0, lx1, ly1 = VAULT_LEAF
    p.rect(lx0 - 2, ly0 - 2, lx1 + 2, ly1, VOID, None)
    p.rect(lx1 - 6, ly0 + 8, lx1 - 2, ly1 - 4, SEAGLASS_HI, None)
    p.line([(lx1 - 6, ly0 + 8), (lx1 - 6, ly1 - 4)], mix(SEAGLASS_HI, PAPER_HI, 0.4), 1.2)
    p.rect(lx0 - 4, ly0 - 4, lx1 + 4, ly1, None, INK, 2)
    vault_leaf(p, (lx1 - lx0) - VAULT_GAP - 10)
    return p


def paint_a_return_unbolted(rng):
    p = Pen(W, H, rng)
    bolt_housing(p, False)
    lx0, ly0, _, ly1 = STAIR_LEAF
    glow = p.layer(SEAGLASS_HI)
    glow.rect(lx0, ly0 + 6, lx0 + 8, ly1 - 4, SEAGLASS_HI, None)
    p.put_soft(glow, 4, 0.55)
    p.line([(lx0 + 3.5, ly0 + 6), (lx0 + 3.5, ly1 - 4)], PAPER_HI, 1.8)
    return p


def tag_shape(p, x0, y0, x1, y1, hole=True):
    c = min(14, (y1 - y0) * 0.3)
    p.poly([(x0 + c, y0), (x1, y0), (x1, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)], PAPER_HI, INK, 2.2)
    if hole:
        hx, hy = x0 + c + 6, (y0 + y1) / 2
        p.ell(hx, hy, 7, 7, PAPER, mix(INK, PAPER, 0.4), 1.4)
        p.ell(hx, hy, 3, 3, SLOT, None)
        return hx, hy
    return None


SOCKET_TAG = (722, 614, 840, 672)


def paint_a_socket_tag(rng):
    p = Pen(W, H, rng)
    x0, y0, x1, y1 = SOCKET_TAG
    sh = p.layer()
    sh.rect(x0 + 6, y0 + 8, x1 + 6, y1 + 6, SHADOW, None)
    p.put_soft(sh, 4, 0.3)
    hx, hy = x0 + 20, (y0 + y1) / 2
    p.line([(SOCKET_C[0], 604), (x0 + 38, y0 + 6), (hx, hy)], INK, 1.8)
    tag_shape(p, x0, y0, x1, y1)
    return p


def paint_a_rack_salt(rng):
    """Where C stood: a flat, hard-edged ring of salt left in the cup, and a faint clean ghost of
    the jar on the tiles behind it."""
    p = Pen(W, H, rng)
    cx, cy = RACK_CUPS[2]
    s = 0.55
    ghost = p.layer()
    body = [(-44, -66), (44, -66), (44, 72), (-44, 72)]
    ghost.poly([rot((cx + x, cy + y), (cx, cy), CANT) for x, y in body], PAPER_HI, None)
    p.put(ghost, 0.22)
    a = rot((cx - 86 * s, cy + 118 * s), (cx, cy), CANT)
    b = rot((cx + 86 * s, cy + 118 * s), (cx, cy), CANT)
    nx, ny = math.sin(math.radians(CANT)), -math.cos(math.radians(CANT))
    top = []
    for i in range(9):
        t = i / 8
        h = 9 + 3 * math.sin(t * math.pi) + (1.5 if i % 2 else 0)
        top.append((lerp(a[0], b[0], t) + nx * h, lerp(a[1], b[1], t) + ny * h))
    p.poly(top + [b, a], SALT_BAND, INK, 1.6)
    return p


# ----------------------------------------------------------------------------- view B overlays

def tube_mask():
    m = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(m)
    for t in TUBES:
        d.rounded_rectangle(((t - TUBE_HW + 2) * SS, (TUBE_Y[0] + 6) * SS, (t + TUBE_HW - 2) * SS, (TUBE_Y[1] - 3) * SS),
                            radius=8 * SS, fill=255)
        d.rectangle(((t - TUBE_HW - 1) * SS, 447 * SS, (t + TUBE_HW + 1) * SS, 467 * SS), fill=0)
    return m


def shell_bit(p, x, y, r, ang, rng):
    pts = []
    for i in range(9):
        a = math.radians(ang + 180 * i / 8)
        pts.append((x + r * math.cos(a), y + r * 0.6 * math.sin(a)))
    pts.append((x + r * 0.3 * math.cos(math.radians(ang + 90)), y + r * 0.2 * math.sin(math.radians(ang + 90))))
    p.poly(pts, PAPER_HI if rng.random() < 0.6 else PAPER, INK, 1.3)


def paint_b_shells_loose(rng):
    p = Pen(W, H, rng)
    lay = p.layer()
    for t in TUBES:
        n = rng.randint(6, 10)
        for i in range(n):
            y = TUBE_Y[1] - 10 - (i // 2) * 7 - rng.uniform(0, 4)
            shell_bit(lay, t + rng.uniform(-3, 3), y, rng.uniform(4, 6.5), rng.uniform(0, 360), rng)
    p.put(lay, 1.0, tube_mask())
    return p


def paint_b_shells_rings(rng):
    """The fragments have closed into rings: one ring of cream cartilage in each tube, the tubes
    gone dark behind them, diminishing left to right and stepping down in a curve, each turned
    along it, like a throat seen in section. Stark graphic shapes, never gore."""
    p = Pen(W, H, rng)
    dark = p.layer()
    for t in TUBES:
        dark.rect(t - TUBE_HW + 2, TUBE_Y[0] + 6, t + TUBE_HW - 2, TUBE_Y[1] - 3, STORM_DK, None, r=8)
    p.put(dark, 0.92, tube_mask())
    cream = mix(PAPER_HI, PAPER, 0.35)
    shade = mix(PAPER, TIMBER, 0.45)
    lay = p.layer()
    n = len(TUBES)
    for k, t in enumerate(TUBES):
        f = k / (n - 1)
        cy = 486 + 72 * math.sin(f * math.pi * 0.5) + 6 * f
        tilt = 28 * math.cos(f * math.pi * 0.5)          # each ring turned along the curve
        rx = 11.0 - 2.6 * f
        ry = 16.5 - 4.5 * f
        th = 0.62 * rx
        gap = 26                                         # the cartilage's open back, small

        def P(a, rr_x, rr_y):
            x, y = rr_x * math.cos(math.radians(a)), rr_y * math.sin(math.radians(a))
            return rot((t + x, cy + y), (t, cy), tilt)
        outer = [P(a, rx, ry) for a in range(gap, 361 - gap, 8)]
        inner = [P(a, rx - th, ry - th) for a in range(360 - gap, gap - 1, -8)]
        lay.poly(outer + inner, cream, INK, 1.8)
        # the lower inner face in shade, so it reads as a thick ring, not a letter
        lay.line([P(a, rx - th * 0.55, ry - th * 0.55) for a in range(60, 200, 10)], shade, th * 0.5)
    p.put(lay)
    return p


THUMB_B = (610, 524)


def whorl(p, cx, cy, rx, ry, dent=True):
    """A thumbprint pressed into felt: a dent shadow, a flat navy-grey whorl with a hard edge and
    its ridges in a lighter tone."""
    if dent:
        sh = p.layer()
        sh.ell(cx + rx * 0.12, cy + ry * 0.2, rx * 1.12, ry * 1.12, FELT_DK, None)
        p.put(sh, 0.9)
        p.arc(cx, cy, rx * 1.12, ry * 1.12, 200, 340, mix(FELT, PAPER_HI, 0.5), max(1.4, rx / 14))
    base = mix(STORM, SEAGLASS, 0.3)
    p.ell(cx, cy, rx, ry, base, mix(STORM, SOOT, 0.3), max(1.4, rx / 16))
    ridge = mix(base, SEAGLASS_HI, 0.55)
    for k in range(1, 5):
        f = k / 5
        p.arc(cx + rx * 0.06, cy + ry * 0.05, rx * f, ry * f, 160 + k * 18, 520 - k * 22, ridge, max(1.2, rx / 18))


def paint_b_thumb(rng):
    p = Pen(W, H, rng)
    whorl(p, THUMB_B[0], THUMB_B[1], 26, 17)
    return p


def strip_cells(p, x0, y0, x1, y1, cells=3):
    p.rect(x0, y0, x1, y1, PAPER_HI, INK, 2, r=1)
    cw = (x1 - x0 - 12) / cells
    for k in range(cells):
        p.rect(x0 + 6 + k * cw + 2, y0 + 5, x0 + 6 + (k + 1) * cw - 2, y1 - 5, None, mix(INK, PAPER, 0.35), 1.4)


def paint_b_strip(rng):
    p = Pen(W, H, rng)
    sh = p.layer()
    sh.rect(744, 612, 924, 640, SHADOW, None)
    p.put_soft(sh, 3, 0.35)
    strip_cells(p, 740, 606, 920, 636)
    return p


def paint_b_frame(rng):
    p = Pen(W, H, rng)
    spec_frame(p)
    return p


def frame_clips(p):
    """The easel's two brass clips that held the frame's top corners."""
    x0, y0, x1, _ = FRAME_B
    for x in (x0 + 18, x1 - 18):
        p.rect(x - 9, y0 - 8, x + 9, y0 + 10, BRASS, INK, 2, r=3)
        p.line([(x - 5, y0 - 4), (x + 5, y0 - 4)], BRASS_HI, 1.4)


def paint_b_stand_empty(rng):
    """The frame gone: where it hung, a paler rectangle of clean tile (the wall around it has
    weathered, the patch it covered has not), and the clips holding nothing."""
    p = Pen(W, H, rng)
    x0, y0, x1, y1 = FRAME_B
    ghost = p.layer()
    ghost.rect(x0, y0, x1, y1, PAPER_HI, None)
    p.put(ghost, 0.42)
    easel(p)
    frame_clips(p)
    return p


def paint_b_register_open(rng):
    p = Pen(W, H, rng)
    register(p, open_=True)
    return p


def paint_b_lid_open(rng):
    p = Pen(W, H, rng)
    frame_lid(p, True)
    return p


def paint_b_lid_closed(rng):
    p = Pen(W, H, rng)
    frame_lid(p, False)
    return p


def jar_body_pts(inset=0):
    x0, y0, x1, y1 = JAR_B
    cx = (x0 + x1) / 2
    a, b = x0 + 8 + inset, x1 - 8 - inset
    top = 418 + inset
    return [(a, 584 - inset), (a, 452)] + bezier((a, 452), (a + 2, top), (cx - 16, top), 10)[1:] + \
        [(cx + 16, top)] + bezier((cx + 16, top), (b - 2, top), (b, 452), 10)[1:] + [(b, 584 - inset)]


def paint_b_fog(rng):
    """Dense milky condensation filling most of the dome, thinning only at the very top, and a
    row of beads gathered along the bottom. The view wipes the inscription through it."""
    p = Pen(W, H, rng)
    body = jar_body_pts(6)
    x0, y0, x1, y1 = JAR_B
    fog = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(fog)
    d.polygon([(x * SS, y * SS) for x, y in body], fill=225)
    # the top fifth stays thinner
    d.rectangle((x0 * SS, 410 * SS, x1 * SS, 446 * SS), fill=120)
    fog = fog.filter(ImageFilter.GaussianBlur(5 * SS))
    fog = ImageChops.multiply(fog, poly_mask(body))
    col = Image.new("RGBA", (W * SS, H * SS), rgba(SALT))
    col.putalpha(fog)
    p.im.alpha_composite(col)
    beads = p.layer()
    x = x0 + 22
    k = 0
    while x < x1 - 20:
        r = 3.2 + 1.6 * ((k * 7) % 3) / 2
        y = 570 - (k % 2) * 7
        beads.ell(x, y, r, r * 1.15, GLASS_HI, mix(GLASS, SEAGLASS, 0.5), 1.2)
        beads.ell(x - r * 0.3, y - r * 0.4, r * 0.3, r * 0.3, (255, 255, 255), None)
        x += 11 + (k % 3) * 3
        k += 1
    p.put(beads, 0.95)
    return p


def tip_lever(p, x0, y0, down):
    x1, y1 = x0 + 130, y0 + 120
    p.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, BRASS, INK, 3, r=8)
    p.rect(x0 + 12, y0 + 12, x1 - 12, y1 - 12, STORM, INK, 2.2, r=5)
    cx = (x0 + x1) / 2
    p.rect(cx - 6, y0 + 22, cx + 6, y1 - 22, SOOT, INK, 1.8, r=5)
    piv = (cx, y1 - 26)
    tip = (cx, y0 + 26) if not down else (cx, y1 - 18)
    if down:
        tip = (cx + 30, y1 - 14)
        p.line([piv, tip], INK, 11)
        p.line([piv, tip], BRASS_LO, 6)
        p.ell(tip[0], tip[1], 11, 11, ENAMEL, INK, 2.4)
    else:
        p.line([piv, tip], INK, 11)
        p.line([piv, tip], BRASS, 6)
        p.line([(piv[0] - 2, piv[1] - 6), (tip[0] - 2, tip[1] + 6)], BRASS_HI, 1.8)
        p.ell(tip[0], tip[1], 13, 13, ENAMEL, INK, 2.4)
        p.arc(tip[0], tip[1], 9, 9, 200, 300, PAPER_HI, 2)
    p.ell(piv[0], piv[1], 9, 9, BRASS_HI, INK, 2.2)


def push_button(p, x0, y0, w=170, h=120):
    x1, y1 = x0 + w, y0 + h
    p.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, BRASS, INK, 3, r=8)
    p.rect(x0 + 12, y0 + 12, x1 - 12, y1 - 12, STORM, INK, 2.2, r=5)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    p.ell(cx, cy + 4, 40, 40, BRASS_LO, INK, 2.4)
    p.ell(cx, cy, 34, 34, ENAMEL, INK, 2.4)
    p.arc(cx, cy, 28, 28, 200, 290, PAPER_HI, 2.4)


def key_housing(p, x0, y0, down):
    x1, y1 = x0 + 140, y0 + 100
    p.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, BRASS, INK, 3, r=8)
    p.rect(x0 + 12, y0 + 12, x1 - 12, y1 - 10, STORM_DK, INK, 2.2, r=5)
    if not down:
        p.rect(x0 + 24, y0 + 30, x1 - 24, y1 - 16, BRASS_LO, INK, 2.2, r=4)     # skirt
        p.rect(x0 + 22, y0 + 14, x1 - 22, y0 + 56, ENAMEL, INK, 2.6, r=5)
        p.line([(x0 + 28, y0 + 19), (x1 - 28, y0 + 19)], PAPER_HI, 2)
    else:
        p.rect(x0 + 24, y0 + 56, x1 - 24, y1 - 16, BRASS_LO, INK, 2.2, r=4)
        p.rect(x0 + 22, y0 + 34, x1 - 22, y0 + 74, mix(ENAMEL, PAPER, 0.5), INK, 2.6, r=5)


def seal_key(p, x0, y0, down):
    x1, y1 = x0 + 140, y0 + 140
    p.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, BRASS, INK, 3, r=10)
    p.rect(x0 + 14, y0 + 14, x1 - 14, y1 - 14, STORM, INK, 2.2, r=6)
    cx = (x0 + x1) / 2
    if not down:
        p.rect(cx - 30, y0 + 64, cx + 30, y1 - 22, BRASS_LO, INK, 2.2, r=4)
        p.ell(cx, y0 + 58, 42, 30, ENAMEL, INK, 2.8)
        p.arc(cx, y0 + 58, 34, 22, 200, 300, PAPER_HI, 2.2)
    else:
        p.rect(cx - 30, y0 + 92, cx + 30, y1 - 22, BRASS_LO, INK, 2.2, r=4)
        p.ell(cx, y0 + 86, 42, 26, mix(ENAMEL, PAPER, 0.5), INK, 2.8)


def socket_closeup(p):
    x0, y0, x1, y1 = 1110, 380, 1350, 780
    sh = p.layer()
    sh.rect(x0 + 10, y0 + 12, x1 + 10, y1 + 26, SHADOW, None)
    p.put_soft(sh, 8, 0.3)
    p.rect(x0, y0, x1, y1, BRASS, INK, 3, r=16)
    p.line([(x0 + 10, y0 + 14), (x0 + 10, y1 - 16)], BRASS_HI, 3)
    p.rect(x0 + 16, y0 + 70, x1 - 16, y1 - 16, STORM, INK, 2.4, r=10)
    for x in (x0 + 24, x1 - 24):
        screw(p, x, y0 + 30, 5)
    cx, cy = 1230, 590
    p.ell(cx, cy, 108, 108, BRASS_LO, INK, 3)
    p.arc(cx, cy, 103, 103, 200, 330, BRASS_HI, 3)
    p.ell(cx, cy, 95, 95, SLOT, INK, 3)
    p.ell(cx, cy, 74, 74, None, mix(SLOT, STORM_HI, 0.5), 2)
    for a in (45, 135, 225, 315):
        screw(p, cx + 101 * math.cos(math.radians(a)), cy + 101 * math.sin(math.radians(a)), 4)
    p.rect(1166, 772, 1294, 806, BRASS_LO, INK, 2.6, r=5)
    p.rect(1178, 786, 1282, 794, SOOT, None)


def test_card(p):
    x0, y0, x1, y1 = 560, 100, 1080, 400
    card(p, x0, y0, x1, y1, PAPER_HI, pins=False)
    p.rect(x0 + 8, 108, x1 - 8, 150, PAPER, mix(INK, PAPER, 0.4), 1.6)
    for bx in (580, 750, 920):
        p.rect(bx, 160, bx + 150, 360, PAPER_HI, INK, 2.2)
        lay = p.layer()
        for k in range(1, 8):
            lay.line([(bx + 2, 160 + k * 25), (bx + 148, 160 + k * 25)], SEAGLASS, 1.2)
        for k in range(1, 6):
            lay.line([(bx + k * 25, 162), (bx + k * 25, 358)], SEAGLASS, 1.2)
        p.put(lay, 0.3)
        p.rect(bx, 368, bx + 150, 396, PAPER, mix(INK, PAPER, 0.4), 1.4)
    for x in (x0 + 16, x1 - 16):
        p.ell(x, y0 + 12, 6, 6, BRASS_HI, INK, 1.8)


def closeup_base(rng, wall_to=900, g=96, oy=54):
    p = Pen(W, H, rng, PAPER)
    tile_field(p, rng, -4, -4, W + 4, wall_to, g, 0, oy, 0.35)
    return p


def paint_c_tilt_rack(rng):
    p = closeup_base(rng)
    datum(p, 146, 154, tick=192, tick_len=10)
    plate(p, 120, 124, 230, 150)
    plumb_bracket(p, 60, 150, 1.5)
    card(p, 1110, 120, 1350, 340, PAPER_HI, ruled=0)
    test_card(p)
    # bench below
    p.rect(-4, 900, W + 4, H + 4, TIMBER, INK, 3)
    for x0 in (40, 520, 1000):
        p.rect(x0, 930, x0 + 420, 1070, mix(TIMBER, TIMBER_DK, 0.3), INK, 2.4, r=4)
    # station shelf
    sh = p.layer()
    sh.rect(40, 830, 712, 920, SHADOW, None)
    p.put_soft(sh, 10, 0.3)
    for cx in (190, 390, 590):
        p.rect(cx - 9, 690, cx + 9, 840, STORM, INK, 2.4)
    p.rect(30, 836, 712, 858, TIMBER_HI, INK, 3)
    p.line([(34, 841), (708, 841)], mix(TIMBER_HI, PAPER, 0.4), 2)
    p.rect(36, 858, 706, 900, TIMBER, INK, 2.8)
    for cx in (190, 390, 590):
        cradle(p, cx, 690, CANT, 1.0)
        plate(p, cx - 56, 860, cx + 56, 884)
    # the TIP station: mounting post, the big hub, the control panel
    p.rect(700, 756, 1050, 904, STORM, INK, 3, r=6)
    p.line([(706, 762), (1044, 762)], STORM_HI, 2)
    p.rect(842, 600, 878, 760, STORM_DK, INK, 2.6)
    cx, cy = 860, 600
    p.ell(cx, cy, 58, 58, BRASS_LO, INK, 3)
    p.ell(cx, cy, 50, 50, BRASS, INK, 2.4)
    p.arc(cx, cy, 46, 46, 200, 300, BRASS_HI, 3)
    p.ell(cx, cy, 30, 30, None, BRASS_LO, 2.4)
    for k in range(6):
        a = math.radians(k * 60)
        screw(p, cx + 40 * math.cos(a), cy + 40 * math.sin(a), 4)
    p.ell(cx, cy, 15, 15, BRASS_HI, INK, 2.4)
    p.ell(cx, cy, 5, 5, SLOT, None)
    tip_lever(p, 720, 770, False)
    push_button(p, 860, 770)
    socket_closeup(p)
    return p


def stamp_box(p, sx0, sy0, sx1, sy1, step=8):
    p.rect(sx0, sy0, sx1, sy1, PAPER, mix(INK, PAPER, 0.4), 1.4)
    t = sx0
    while t <= sx1:
        p.ell(t, sy0, 1.8, 1.8, PAPER_HI, None)
        p.ell(t, sy1, 1.8, 1.8, PAPER_HI, None)
        t += step
    t = sy0
    while t <= sy1:
        p.ell(sx0, t, 1.8, 1.8, PAPER_HI, None)
        p.ell(sx1, t, 1.8, 1.8, PAPER_HI, None)
        t += step


def paint_c_balance(rng):
    p = closeup_base(rng, 620)
    for k in range(3):
        x0 = 90 + k * 96
        card(p, x0, 110, x0 + 84, 270, PAPER_HI, ruled=16)
        stamp_box(p, x0 + 4, 130, x0 + 80, 176)
    # bench top and console face
    sh = p.layer()
    sh.rect(-4, 600, W + 4, 660, SHADOW, None)
    p.put_soft(sh, 10, 0.3)
    p.rect(-4, 640, W + 4, H + 4, TIMBER, INK, 3)
    p.rect(-4, 610, W + 4, 640, TIMBER_HI, INK, 3)
    p.line([(-4, 615), (W + 4, 615)], mix(TIMBER_HI, PAPER, 0.45), 2)
    # sample stands
    for x0 in (120, 250, 380):
        p.rect(x0 - 6, 674, x0 + 116, 816, BRASS_LO, INK, 2.6, r=6)
        p.rect(x0, 680, x0 + 110, 790, STORM, INK, 2.2, r=4)
        p.rect(x0 + 8, 778, x0 + 102, 788, BRASS, INK, 1.8, r=2)
        plate(p, x0 + 14, 795, x0 + 96, 809)
    # keys
    p.rect(548, 668, 1032, 792, STORM, INK, 2.6, r=6)
    for x0 in (560, 720, 880):
        key_housing(p, x0, 680, False)
    # strip printer
    x0, y0, x1, y1 = 1080, 640, 1400, 820
    p.rect(x0, y0, x1, y1, STORM, INK, 3, r=8)
    p.rect(x0 + 6, y0 + 6, x1 - 6, y1 - 6, None, BRASS_LO, 2, r=6)
    p.rect(x0 + 10, 656, x1 - 10, 752, BRASS_LO, INK, 2.4, r=4)
    for k in range(3):
        cx0 = x0 + 16 + k * 98
        p.rect(cx0, 664, cx0 + 92, 744, PAPER_HI, INK, 2)
    p.rect(x0 + 14, 760, x1 - 14, 790, PAPER_HI, INK, 2)
    p.rect(x0 + 40, 800, x1 - 40, 808, SOOT, None)
    for x in (x0 + 16, x1 - 16):
        screw(p, x, y1 - 14, 3.6)
    # the register drawer front with eight tab recesses
    p.rect(100, 826, 1340, 930, OAK, INK, 3, r=5)
    p.line([(104, 831), (1336, 831)], OAK_HI, 2)
    for k in range(8):
        tx = 120 + 150 * k
        p.rect(tx, 836, tx + 140, 920, OAK_DK, INK, 2.4, r=3)
        p.line([(tx + 3, 840), (tx + 137, 840)], SHADOW, 2)
    p.rect(-4, 940, W + 4, H + 4, TIMBER_DK, INK, 3)
    # the balance: pedestal with the gauge, post, collar, knife-edge cap, holder bracket
    sh = p.layer()
    sh.rect(660, 548, 806, 660, SHADOW, None)
    p.put_soft(sh, 6, 0.3)
    p.rect(652, 540, 796, 656, BRASS, INK, 3, r=8)
    p.line([(658, 546), (790, 546)], BRASS_HI, 2)
    p.rect(670, 560, 780, 650, ENAMEL, INK, 2.4, r=4)
    gx, gy = 725, 646
    lay = p.layer()
    for k in range(6):
        a = math.radians(-55 + k * 22 - 90)
        lay.line([(gx + 50 * math.cos(a), gy + 50 * math.sin(a)), (gx + 64 * math.cos(a), gy + 64 * math.sin(a))], INK, 2.4)
    lay.arc(gx, gy, 50, 50, 215, 325, INK, 1.4)
    p.put(lay, 1.0, rect_mask([(672, 562, 778, 648)]))
    p.rect(716, 306, 732, 542, BRASS, INK, 2.6)
    p.line([(720, 312), (720, 538)], BRASS_HI, 2)
    p.rect(704, 330, 744, 354, BRASS_LO, INK, 2.4, r=4)
    p.ell(748, 342, 6, 6, SLOT, INK, 1.6)
    p.poly([(700, 322), (748, 322), (738, 306), (710, 306)], BRASS_LO, INK, 2.4)
    p.poly([(716, 306), (732, 306), (724, 296)], BRASS_HI, INK, 2)
    x0, y0, x1, y1 = 644, 400, 804, 490
    p.rect(x0, y0, x1, y1, BRASS, INK, 3, r=6)
    p.rect(x0 + 8, y0 + 8, x1 - 8, y1 - 8, mix(PAPER, TIMBER, 0.35), INK, 2, r=3)
    p.rect(x0 + 8, y0 + 8, x1 - 8, y0 + 14, SHADOW, None)
    for x in (x0 + 4, x1 - 4):
        p.rect(x - 4, y0 + 30, x + 4, y0 + 60, BRASS_HI, INK, 1.6, r=2)
    return p


def paint_c_frame(rng):
    p = closeup_base(rng, 910)
    # reference board and card
    sh = p.layer()
    sh.rect(150, 112, 1320, 332, SHADOW, None)
    p.put_soft(sh, 8, 0.3)
    p.rect(140, 100, 1310, 320, OAK, INK, 3, r=6)
    p.rect(160, 120, 1290, 304, PAPER_HI, INK, 2.4)
    for x in (300, 1150):
        p.rect(x - 34, 92, x + 34, 128, BRASS, INK, 2.6, r=6)
        p.line([(x - 26, 100), (x + 26, 100)], BRASS_HI, 2)
    # glass tray lid, propped open behind the frame's lower edge
    lay = p.layer()
    lay.poly([(150, 702), (1270, 702), (1262, 640), (158, 640)], GLASS + (255,), None)
    p.put(lay, 0.55)
    p.poly([(150, 702), (1270, 702), (1262, 640), (158, 640)], None, INK, 2.4)
    # frame posts and the frame
    for x in (200, 1250):
        p.rect(x - 10, 676, x + 10, 712, BRASS_LO, INK, 2.4)
    sh = p.layer()
    sh.rect(150, 352, 1322, 694, SHADOW, None)
    p.put_soft(sh, 8, 0.32)
    p.rect(140, 340, 1310, 680, BRASS, INK, 3.4, r=8)
    p.rect(150, 350, 1300, 670, None, BRASS_HI, 2, r=6)
    for sx in (170, 545, 920):
        p.rect(sx, 370, sx + 360, 570, FELT_DK, INK, 2.6, r=3)
        p.rect(sx + 3, 373, sx + 357, 381, SHADOW, None)
    p.rect(180, 594, 520, 664, mix(BRASS_LO, SLOT, 0.35), INK, 2.4, r=4)
    p.rect(183, 597, 517, 604, SHADOW, None)
    p.rect(560, 594, 900, 664, BRASS_LO, INK, 2.4, r=4)
    p.rect(560, 606, 900, 622, BRASS_HI, INK, 2.2, r=3)     # the spring clip bar
    for x in (610, 850):
        p.rect(x - 10, 600, x + 10, 640, BRASS, INK, 2, r=4)
        p.ell(x, 600, 6, 6, BRASS_HI, INK, 1.6)
    plate(p, 940, 596, 1280, 660)
    for x, y in ((156, 356), (1294, 356), (156, 664), (1294, 664)):
        screw(p, x, y, 4.2)
    # the open glass tray
    p.rect(140, 702, 1280, 906, mix(GLASS, SEAGLASS_HI, 0.35), INK, 3, r=6)
    p.rect(140, 696, 1280, 708, BRASS_LO, INK, 2.4, r=2)
    for sx in (170, 545, 920):
        p.rect(sx, 720, sx + 360, 890, FELT, INK, 2.4, r=4)
        p.rect(sx + 3, 723, sx + 357, 731, FELT_DK, None)
    p.line([(152, 716), (152, 896)], GLASS_HI, 3)
    seal_key(p, 1290, 740, False)
    # bench
    p.rect(-4, 906, W + 4, 934, TIMBER_HI, INK, 3)
    p.line([(-4, 911), (W + 4, 911)], mix(TIMBER_HI, PAPER, 0.45), 2)
    p.rect(-4, 934, W + 4, H + 4, TIMBER, INK, 3)
    for x0 in (40, 520, 1000):
        p.rect(x0, 956, x0 + 420, 1070, mix(TIMBER, TIMBER_DK, 0.3), INK, 2.4, r=4)
    return p


def jar(rng, w, h, inner, label, front):
    """A stoppered specimen jar. inner = interior rect; the back carries the inner glass and
    the rear rim, the front the lid, rim, wall contours, highlights and a blank label plate."""
    p = Pen(w, h, rng)
    ix0, iy0, ix1, iy1 = inner
    t = (ix0 + w - ix1) / 2 * 0.55          # wall thickness
    bx0, by0, bx1, by1 = ix0 - t, iy0 - t * 0.8, ix1 + t, min(h - 1.5, iy1 + t * 1.2)
    lw = 2.4 if w < 100 else 3.0
    rr = (ix1 - ix0) * 0.12
    if not front:
        lay = p.layer()
        lay.rect(bx0, by0, bx1, by1, GLASS, None, r=rr * 1.3)
        p.put(lay, 0.55)
        lay = p.layer()
        lay.rect(ix0, iy0, ix1, iy1, mix(GLASS, SEAGLASS_HI, 0.35), None, r=rr)
        p.put(lay, 0.6)
        p.arc((ix0 + ix1) / 2, iy0 + 2, (ix1 - ix0) / 2, (ix1 - ix0) * 0.09, 180, 360, mix(INK, SEAGLASS, 0.4), lw * 0.7)
        p.line([(ix1 - (ix1 - ix0) * 0.2, iy0 + 8), (ix1 - (ix1 - ix0) * 0.2, iy1 - 8)], mix(GLASS, SEAGLASS, 0.3), lw)
        return p
    # front: the walls' contours, a thick glass base, the rim and the lid
    p.rect(bx0, by0, bx1, by1, None, INK, lw, r=rr * 1.3)
    p.rect(ix0, iy0, ix1, iy1, None, mix(INK, SEAGLASS_HI, 0.55), lw * 0.55, r=rr)
    base = p.layer()
    base.rect(bx0 + 2, iy1, bx1 - 2, by1 - 1, GLASS, None, r=rr)
    p.put(base, 0.7)
    lid_h = iy0 - by0 + (iy0 * 0.5)
    lx0, lx1 = bx0 - t * 0.3, bx1 + t * 0.3
    p.rect(bx0 + 1, by0 - 1, bx1 - 1, by0 + t * 1.2, GLASS, INK, lw * 0.8, r=3)      # rim
    p.rect(lx0, 2, lx1, by0 + 1, BRASS, INK, lw, r=4)                              # lid
    p.line([(lx0 + 4, 2 + lw + 2), (lx1 - 4, 2 + lw + 2)], BRASS_HI, lw * 0.8)
    for k in range(1, 5):
        x = lerp(lx0, lx1, k / 5)
        p.line([(x, 6), (x, by0 - 3)], BRASS_LO, lw * 0.5)
    hi = p.layer()
    hx = ix0 + (ix1 - ix0) * 0.14
    hi.line([(hx, iy0 + 10), (hx, iy1 - 14)], GLASS_HI, max(3, w * 0.045))
    hi.line([(hx + w * 0.06, iy0 + 14), (hx + w * 0.06, iy0 + (iy1 - iy0) * 0.45)], GLASS_HI, max(1.6, w * 0.02))
    hi.line([(ix1 - 4, iy0 + 16), (ix1 - 4, iy0 + (iy1 - iy0) * 0.3)], GLASS_HI, max(1.6, w * 0.02))
    p.put(hi, 0.85)
    lx0, ly0, lx1, ly1 = label
    p.rect(lx0, ly0, lx1, ly1, PAPER_HI, INK, lw * 0.75, r=2)
    del lid_h
    return p


def paint_c_cradle(rng):
    p = Pen(220, 320, rng)
    cradle(p, 110, 160, 0.0, 1.0, empty_hub=False, full=True)
    return p


def plumb_sprite(rng, w, h, piv, bob, r, tag=None):
    p = Pen(w, h, rng)
    cx = piv[0]
    p.ell(cx, piv[1] + 1, 3.2, 3.2, None, BRASS_HI, 1.6)
    p.line([(cx, piv[1] + 3), (cx, bob[1] - r)], INK, 1.6)
    if tag:
        ty0, ty1 = tag
        p.rect(cx - 12, ty0, cx + 12, ty1, PAPER_HI, INK, 1.8, r=2)
        p.ell(cx, ty0 + 4, 2, 2, SLOT, None)
    by = bob[1]
    body = [(cx - r * 0.45, by - r - 2), (cx + r * 0.45, by - r - 2), (cx + r, by - r * 0.2),
            (cx + r * 0.8, by + r * 0.35), (cx, by + r + min(4, h - by - r - 1)), (cx - r * 0.8, by + r * 0.35), (cx - r, by - r * 0.2)]
    p.poly(body, BRASS, INK, 2.2)
    p.line([(cx - r * 0.5, by - r * 0.4), (cx - r * 0.3, by + r * 0.3)], BRASS_HI, 2)
    p.rect(cx - r * 0.45, by - r - 5, cx + r * 0.45, by - r + 1, BRASS_LO, INK, 1.6)
    return p


def paint_c_tag(rng):
    p = Pen(140, 80, rng)
    tag_shape(p, 6, 8, 134, 72)
    return p


def paint_c_beam(rng):
    p = Pen(700, 60, rng)
    p.poly([(22, 25), (320, 19), (380, 19), (678, 25), (678, 35), (380, 42), (320, 42), (22, 35)], BRASS, INK, 2.6)
    p.line([(28, 27), (672, 27)], BRASS_HI, 1.8)
    for x in range(80, 640, 60):
        if abs(x - 350) > 40:
            p.line([(x, 34), (x, 38)], BRASS_LO, 1.6)
    p.poly([(332, 12), (368, 12), (350, 34)], BRASS_HI, INK, 2.2)
    p.ell(350, 30, 7, 7, BRASS_HI, INK, 2.2)
    for x in (30, 670):
        p.ell(x, 30, 8, 8, None, INK, 4.2)
        p.ell(x, 30, 8, 8, None, BRASS_HI, 2)
    return p


def hanger(p, hook=(110, 6), y=258, half=94):
    p.ell(hook[0], hook[1] + 1, 5, 5, None, INK, 2)
    for dx in (-half, 0, half):
        p.line([(hook[0], hook[1] + 6), (hook[0] + dx, y)], INK, 1.8)


def paint_c_pan(rng):
    p = Pen(220, 300, rng)
    hanger(p, y=260, half=92)
    p.poly([(10, 258), (210, 258), (184, 292), (36, 292)], BRASS, INK, 2.8)
    p.line([(18, 263), (202, 263)], BRASS_HI, 2)
    return p


def paint_c_tray(rng):
    p = Pen(220, 300, rng)
    hanger(p, y=238, half=84)
    p.rect(18, 236, 202, 292, BRASS, INK, 3, r=7)
    p.rect(30, 245, 190, 281, FELT, INK, 2.2, r=4)
    p.line([(34, 250), (186, 250)], mix(FELT, PAPER_HI, 0.35), 1.8)
    p.line([(24, 288), (196, 288)], BRASS_HI, 1.6)
    return p


def paint_c_thumb(rng):
    p = Pen(120, 64, rng)
    whorl(p, 60, 32, 50, 27)
    return p


def paint_c_sample(rng, kind):
    p = Pen(90, 120, rng)
    if kind == "f":
        p.ell(45, 102, 38, 9, GLASS, INK, 2.2)
        p.arc(45, 98, 34, 6, 200, 340, GLASS_HI, 2)
        chip = [(26, 96), (34, 74), (50, 66), (64, 78), (66, 96)]
        p.poly(chip, STONE, INK, 2.4)
        p.poly([(34, 78), (48, 70), (54, 80), (40, 86)], mix(STONE, PAPER, 0.3), None)
        p.line([(46, 74), (58, 92)], mix(STONE, SOOT, 0.4), 1.4)
        return p
    x0, x1 = (30, 60) if kind == "n" else (26, 64)
    if kind == "w":
        lay = p.layer()
        lay.rect(x0 + 2, 52, x1 - 2, 112, SEAGLASS, None, r=10)
        p.put(lay)
        p.line([(x0 + 2, 52), (x1 - 2, 52)], SEAGLASS_HI, 2.4)
    tint = p.layer()
    tint.rect(x0, 16, x1, 114, GLASS, None, r=12)
    p.put(tint, 0.3)
    p.rect(x0, 16, x1, 114, None, INK, 2.4, r=12)
    p.line([(x0 + 6, 28), (x0 + 6, 104)], GLASS_HI, 3)
    p.rect(x0 - 3, 4, x1 + 3, 22, TIMBER_HI, INK, 2.2, r=3)
    if kind == "n":
        stamp_box(p, x0 - 6, 60, x1 + 6, 88, step=6)
    return p


def paint_c_sample_tube(rng):
    """The P13 sample: an opaque stoppered tube in brown stoneware glaze (it reads on the navy
    stands and the brass pan), a navy stopper, a brass collar and a blank paper tag. All three
    stands hold this one sprite: nothing on it says what it holds."""
    p = Pen(90, 120, rng)
    x0, x1 = 28, 62
    p.rect(x0, 16, x1, 114, TIMBER, INK, 2.4, r=12)
    p.line([(x0 + 6, 30), (x0 + 6, 102)], mix(TIMBER, PAPER, 0.4), 3)
    p.line([(x1 - 6, 30), (x1 - 6, 104)], TIMBER_DK, 2)
    p.rect(x0 - 1, 20, x1 + 1, 28, BRASS, INK, 1.8)
    p.rect(x0 - 3, 4, x1 + 3, 22, STORM, INK, 2.2, r=3)
    p.line([(x0 + 1, 10), (x1 - 1, 10)], STORM_HI, 1.4)
    stamp_box(p, x0 - 4, 60, x1 + 4, 86, step=6)
    return p


def paint_c_card(rng):
    p = Pen(140, 84, rng)
    p.rect(2, 2, 138, 82, PAPER_HI, INK, 2, r=2)
    p.line([(8, 20), (132, 20)], mix(INK, PAPER, 0.4), 1.6)
    lay = p.layer()
    for y in (36, 50, 64):
        lay.line([(8, y), (132, y)], SEAGLASS, 1.2)
    p.put(lay, 0.45)
    return p


def paint_c_pin(rng):
    p = Pen(60, 90, rng)
    p.poly([(26, 30), (34, 30), (34, 78), (30, 88), (26, 78)], BRASS, INK, 2.2)
    p.line([(28.5, 34), (28.5, 76)], BRASS_HI, 1.6)
    p.ell(30, 18, 14, 14, None, INK, 7)
    p.ell(30, 18, 14, 14, None, BRASS, 3.6)
    p.arc(30, 18, 14, 14, 200, 290, BRASS_HI, 1.6)
    p.rect(22, 28, 38, 34, BRASS_LO, INK, 1.6)
    return p


def paint_c_needle(rng):
    p = Pen(12, 120, rng)
    p.poly([(6, 3), (8.5, 108), (3.5, 108)], INK, None)
    p.ell(6, 114, 5, 5, BRASS_HI, INK, 1.6)
    return p


def paint_c_section(rng):
    p = Pen(340, 160, rng)
    p.rect(2, 2, 338, 158, PAPER_HI, INK, 2.2, r=2)
    lay = p.layer()
    for x in range(22, 338, 20):
        lay.line([(x, 4), (x, 156)], SEAGLASS, 1)
    for y in range(20, 158, 20):
        lay.line([(4, y), (336, y)], SEAGLASS, 1)
    p.put(lay, 0.28)
    return p


def paint_c_name_tab(rng):
    p = Pen(340, 70, rng)
    sh = p.layer()
    sh.rect(6, 8, 338, 68, SHADOW, None)
    p.put_soft(sh, 2, 0.4)
    p.rect(2, 2, 334, 64, BRASS_LO, INK, 2.4, r=5)
    p.rect(9, 9, 327, 57, ENAMEL, mix(INK, BRASS_LO, 0.5), 1.6, r=3)
    return p


def paint_c_strip(rng):
    p = Pen(340, 70, rng)
    strip_cells(p, 2, 6, 338, 64)
    for y in range(12, 60, 8):
        p.ell(6, y, 1.4, 1.4, PAPER, None)
        p.ell(334, y, 1.4, 1.4, PAPER, None)
    return p


def paint_c_frame_glass(rng):
    p = Pen(1170, 340, rng)
    tint = p.layer()
    tint.rect(4, 4, 1166, 336, GLASS, None, r=6)
    p.put(tint, 0.12)
    hi = p.layer()
    for x0, wd in ((40, 26), (84, 8), (620, 18), (652, 6)):
        hi.poly([(x0 + 60, 8), (x0 + 60 + wd, 8), (x0 + wd, 332), (x0, 332)], GLASS_HI, None)
    p.put(hi, 0.42)
    p.rect(3, 3, 1167, 337, None, GLASS_HI, 2.4, r=6)
    p.rect(1, 1, 1169, 339, None, INK, 1.6, r=7)
    return p


def sprite(w, h, fn):
    def run(rng):
        p = Pen(w, h, rng)
        fn(p)
        return p
    return run


# ----------------------------------------------------------------------------- the sea comes in
#
# Wall overlays the view lays over the stage plate as the weather band climbs (game.weather_band();
# R07 opens at band 2). Each is a full-plate RGBA layer, transparent except on the glazed tiles,
# so every door, the tank, socket, rack and basin keep their painted contrast. The tiles are
# found exactly: a plate painted without its objects against the objects painted alone.
#
#   a_sea_b2 / b_sea_b2   band >= 2: condensation beads on the tiles in the 140 px above DATUM_Y
#   a_sea_b3 / b_sea_b3   band >= 3: a hard sea-glass waterline flush under the datum rail, and
#                         the tiles below it a little deeper (12% sea-glass)
#   a_sea_b4 / b_sea_b4   band >= 4: storm-navy grout below the waterline; view A a porthole above
#                         the STAIR door, the sea standing high in it
#   a_sea_b6 / b_sea_b6   band >= 6: the tiles below the line wet (20% darker, specular runs)
#   a_sea_b6_slot         band >= 6, vault ajar: the RECORDS door's black slot 60% taller
#   a_sea_b7 / b_sea_b7   band 7: the wet handprint storm navy and 1.5x; navy contours on the blooms
#   a_lamp, a_lamp_low, b_lamp_low   the lamps over the overlays: in place, and from band 6 40 px lower
#   a_lamp_patch_s6/s7, b_lamp_patch_s6/s7   the plate's own wall where the painted lamp hung
#   a_rack_salt_v2        the salt crust where C stood (replaces a_rack_salt)

DATUM_Y = (DATUM_Y0 + DATUM_Y1) // 2       # 300: the datum rail's centre line (rail 296-304)
# The waterline stands at the datum: flush under the rail, so the brass and its ticks still read.
WATERLINE = (DATUM_Y1 + 1, DATUM_Y1 + 7)   # 6 px
BEADS = (DATUM_Y - 140, DATUM_Y0 - 2)      # the 140 px above DATUM_Y, off the brass
SEA_LINE = SEAGLASS                        # the palette's sea-glass green #617d74: reads on pale tile
SKIRT = {"a": A_FLOOR - 18, "b": 900 - 18}
LAMP_DROP = 40
LAMP_A_BOX = (484, 266, 590, 392)          # every pixel of wall_lamp at LAMP_A
PENDANT_B_BOX = (430, 46, 550, 154)        # every pixel of pendant at PENDANT_B
PORTHOLE = (102, 226, 60)                  # above the STAIR door (frame 12-192, top 314)
SLOT_X = (VAULT_LEAF[2] - VAULT_GAP, VAULT_LEAF[2] + 2)   # the ajar door's void, x
SLOT_TOP = VAULT_LEAF[1] - round((VAULT_LEAF[3] - VAULT_LEAF[1]) * 0.6)

_cache = {}


def _cached(key, fn):
    if key not in _cache:
        _cache[key] = fn()
    return _cache[key]


def _objects_alpha(side):
    """Where the plate's objects stand (L, 1x): painted alone, solid alpha only, so soft shadows
    and lamp pools count as wall. Lamps are left out: they are redrawn over the overlays."""
    def run():
        p = Pen(W, H, rng_for(0 if side == "a" else 10))
        (view_a_objects if side == "a" else view_b_objects)(p, 2, lamp=False)
        a = p.done().getchannel("A").point(lambda v: 255 if v > 150 else 0)
        return a.filter(ImageFilter.MaxFilter(5))
    return _cached(("obj", side), run)


def tile_mask(side, y0=WALL_TOP, y1=None):
    """L mask (1x) of the glazed tiles between y0 and y1 (default: down to the skirting)."""
    y1 = SKIRT[side] if y1 is None else y1
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rectangle((0, y0, W, y1 - 1), fill=255)
    return ImageChops.subtract(m, _objects_alpha(side))


def _apply_mask(im, mask):
    im = im.copy()
    im.putalpha(ImageChops.multiply(im.getchannel("A"), mask))
    return im


def _flat(col, alpha):
    return Image.new("RGBA", (W, H), tuple(col[:3]) + (int(round(alpha * 255)),))


def _below(side):
    return tile_mask(side, WATERLINE[1])


def paint_sea_b2(side):
    """Condensation: seeded beads, 2-5 px, paper white at half strength with a 1 px navy lower
    contour, thicker toward the datum."""
    rng = rng_for(800 if side == "a" else 810)
    fill = Pen(W, H, rng)
    rim = Pen(W, H, rng)
    glint = Pen(W, H, rng)
    n = 0
    while n < 700:
        x = rng.uniform(0, W)
        t = rng.random() ** 0.6                     # denser toward the rail
        y = lerp(BEADS[0], BEADS[1] - 3, t)
        d = rng.uniform(2.0, 5.0)
        r = d / 2.0
        fill.ell(x, y, r, r * 1.08, PAPER_HI, None)
        rim.arc(x, y, r, r * 1.08, 35, 145, INK, 1.0)
        if d >= 3.0:
            glint.ell(x - r * 0.35, y - r * 0.4, 0.6, 0.6, PAPER_HI, None)
        if rng.random() < 0.08:                      # a few have started to run
            ln = rng.uniform(5, 14)
            fill.rect(x - r * 0.45, y, x + r * 0.45, min(BEADS[1], y + ln), PAPER_HI, None, r=r * 0.45)
        n += 1
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    f = fill.done()
    f.putalpha(f.getchannel("A").point(lambda v: v // 2))
    im.alpha_composite(f)
    k = rim.done()
    k.putalpha(k.getchannel("A").point(lambda v: v * 11 // 20))
    im.alpha_composite(k)
    im.alpha_composite(glint.done())
    return _apply_mask(im, tile_mask(side, BEADS[0] - 4, BEADS[1]))


def _datum_ticks():
    m = Image.new("L", (W, H), 255)
    d = ImageDraw.Draw(m)
    x = 96
    while x < W:
        d.rectangle((x - 2, DATUM_Y1 - 1, x + 2, DATUM_Y1 + 8), fill=0)
        x += 96
    return m


def paint_sea_b3(side):
    """The waterline: hard, level, flush under the datum rail, with a navy contour under it;
    the tiles below take a 12% sea-glass multiply (an over of sea-glass at 13%)."""
    im = _apply_mask(_flat(SEAGLASS, 0.13), _below(side))
    p = Pen(W, H, rng_for(820))
    p.rect(-4, WATERLINE[0], W + 4, WATERLINE[1], SEA_LINE, None)
    p.line([(-4, WATERLINE[1] + 0.5), (W + 4, WATERLINE[1] + 0.5)], INK, 1.2)
    p.line([(-4, WATERLINE[0] + 1.0), (W + 4, WATERLINE[0] + 1.0)], SEAGLASS_HI, 1.2)   # the sheen on its surface
    line = p.done()
    line.putalpha(line.getchannel("A").point(lambda v: v * 9 // 10))
    m = ImageChops.multiply(tile_mask(side, WATERLINE[0] - 1, WATERLINE[1] + 2), _datum_ticks())
    im.alpha_composite(_apply_mask(line, m))
    return im


def porthole(p, cx, cy, r):
    """A brass porthole: inside, the sea stands flat and storm navy almost to the top of the
    glass, higher than its own sill, with a sea-glass surface line."""
    sh = p.layer()
    sh.ell(cx + 6, cy + 7, r + 2, r + 2, SHADOW, None)
    p.put_soft(sh, 4, 0.3)
    # the sill under it, which the sea outside stands well above
    p.rect(cx - r * 0.8, cy + r + 4, cx + r * 0.8, cy + r + 14, BRASS_LO, INK, 2.2, r=2)
    p.line([(cx - r * 0.8 + 3, cy + r + 7), (cx + r * 0.8 - 3, cy + r + 7)], BRASS_HI, 1.4)
    p.ell(cx, cy, r, r, BRASS, INK, 3)
    p.arc(cx, cy, r - 4, r - 4, 200, 320, BRASS_HI, 2.2)
    for k in range(8):
        a = math.radians(22.5 + k * 45)
        screw(p, cx + (r - 7) * math.cos(a), cy + (r - 7) * math.sin(a), 3.0)
    gr = r - 15
    p.ell(cx, cy, gr + 3, gr + 3, BRASS_LO, INK, 2.2)
    glass = p.layer()
    glass.ell(cx, cy, gr, gr, GLASS, None)
    surf = cy - gr * 0.68
    glass.rect(cx - gr - 2, surf, cx + gr + 2, cy + gr + 2, STORM, None)
    glass.rect(cx - gr - 2, surf - 1.5, cx + gr + 2, surf + 1.5, SEA_LINE, None)
    m = Image.new("L", (W * SS, H * SS), 0)
    ImageDraw.Draw(m).ellipse(((cx - gr) * SS, (cy - gr) * SS, (cx + gr) * SS, (cy + gr) * SS), fill=255)
    p.put(glass, 1.0, m)
    p.line([(cx - gr * 0.55, surf - 3), (cx - gr * 0.2, surf - gr * 0.25)], GLASS_HI, 2.0)
    p.ell(cx, cy, gr, gr, None, INK, 2.4)


def _grid_lines(side):
    p = Pen(W, H, rng_for(830))
    y = DADO_Y - G * math.floor((DADO_Y - WATERLINE[1]) / G)
    while y < SKIRT[side]:
        if abs(y - DADO_Y) > 10:
            p.line([(-4, y), (W + 4, y)], STORM, 2.0)
        y += G
    x = 0
    while x <= W:
        p.line([(x, WATERLINE[1]), (x, SKIRT[side])], STORM, 2.0)
        x += G
    im = p.done()
    dado = Image.new("L", (W, H), 255)
    ImageDraw.Draw(dado).rectangle((0, DADO_Y - 9, W, DADO_Y + 9), fill=0)
    return _apply_mask(im, ImageChops.multiply(_below(side), dado))


def paint_sea_b4(side):
    im = _grid_lines(side)
    if side == "a":
        p = Pen(W, H, rng_for(831))
        porthole(p, *PORTHOLE)
        im.alpha_composite(p.done())
    return im


def paint_sea_b6(side):
    """Wet tiles below the line: 20% darker (black at 20%), with thin vertical specular runs."""
    im = _apply_mask(_flat((0, 0, 0), 0.20), _below(side))
    rng = rng_for(840 if side == "a" else 841)
    p = Pen(W, H, rng)
    for _ in range(140):
        x = rng.uniform(0, W)
        y0 = rng.uniform(WATERLINE[1] + 4, SKIRT[side] - 30)
        ln = rng.uniform(18, 90)
        wd = rng.choice((1.0, 1.0, 1.5, 2.0))
        p.rect(x, y0, x + wd, min(SKIRT[side] - 4, y0 + ln), PAPER_HI, None)
    runs = p.done()
    runs.putalpha(runs.getchannel("A").point(lambda v: v * 35 // 100))
    im.alpha_composite(_apply_mask(runs, _below(side)))
    return im


def paint_sea_b6_slot():
    """The ajar RECORDS door's void climbs 60% higher than the door: flat, over the transom and
    the wall, round the RECORDS plate (which stays legible), its sea-glass sliver running up."""
    p = Pen(W, H, rng_for(850))
    x0, x1 = SLOT_X
    y1 = VAULT_LEAF[1] + 2
    p.rect(x0, SLOT_TOP, x1, y1, VOID, None)
    p.rect(x1 - 8, SLOT_TOP + 4, x1 - 4, y1, SEAGLASS_HI, None)
    p.line([(x0, SLOT_TOP), (x0, y1)], INK, 2)
    p.line([(x0, SLOT_TOP), (x1, SLOT_TOP)], INK, 2)
    im = p.done()
    keep = Image.new("L", (W, H), 255)
    px0, py0, px1, py1 = VAULT_PLATE
    ImageDraw.Draw(keep).rectangle((px0 - 4, py0 - 4, px1 + 4, py1 + 4), fill=0)
    return _apply_mask(im, keep)


def _bloom_rings(cx, cy, r, rng):
    """bloom()'s outer ring, drawing from `rng` exactly as bloom() does (six rings per bloom)."""
    out = None
    for scale in (1.0, 0.66, 0.36, 0.84, 0.56, 0.3):
        pts = []
        for i in range(30):
            a = 2 * math.pi * i / 30
            rr = r * scale * (1.0 + 0.07 * math.sin(a * 3 + cx) + rng.uniform(-0.03, 0.03))
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.9))
        if out is None:
            out = pts
    return out


def paint_sea_b7(side):
    """Band 7: navy contours on the plate's damp blooms; in view A the wet handprint by the
    basin again, storm navy at 55% and half as big again."""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    brng = rng_for(595 if side == "a" else 596)
    p = Pen(W, H, rng_for(860))
    for cx, cy, r in (A_BLOOMS if side == "a" else B_BLOOMS):
        ring = _bloom_rings(cx, cy, r, brng)
        p.poly(ring, None, INK, 1.5)
    keep = tile_mask(side)
    if side == "a":
        hole = Image.new("L", (W, H), 255)
        cx, cy, pr = PORTHOLE
        ImageDraw.Draw(hole).ellipse((cx - pr - 4, cy - pr - 4, cx + pr + 4, cy + pr + 18), fill=0)
        keep = ImageChops.multiply(keep, hole)
    im.alpha_composite(_apply_mask(p.done(), keep))
    if side == "a":
        hp = Pen(W, H, rng_for(861))
        hand_shape(hp, A_HAND[0], A_HAND[1], 1.5, STORM)
        h = hp.done()
        h.putalpha(h.getchannel("A").point(lambda v: v * 55 // 100))
        im.alpha_composite(_apply_mask(h, tile_mask("a")))
    return im


def hand_shape(p, cx, cy, s, col):
    """handprint()'s palm and fingers, flat, in `col`."""
    p.ell(cx, cy + 14 * s, 27 * s, 31 * s, col, None)
    for dx, top, wd in ((-21, -46, 9.5), (-7, -58, 10), (8, -56, 10), (22, -44, 9)):
        p.rect(cx + (dx - wd / 2) * s, cy + top * s, cx + (dx + wd / 2) * s, cy, col, None, r=wd / 2 * s)
    p.poly([(cx - 24 * s, cy + 10 * s), (cx - 50 * s, cy - 14 * s), (cx - 42 * s, cy - 22 * s),
            (cx - 16 * s, cy - 2 * s)], col, None)
    p.ell(cx - 46 * s, cy - 18 * s, 6 * s, 6 * s, col, None)


# ----------------------------------------------------------------------------- the room beneath the water
#
# w3 overlays for view A, laid over the sea tiers (the view draws them after _draw_sea):
#
#   waterline        band >= 4: the room's own water, flat and square to the DATUM at 60% of the
#                    tiled wall's height (measured down from the frieze to the skirting). Below it
#                    the tiles stand in storm navy and their grout breaks into refracted, offset
#                    segments; a few drips run from the porthole down the STAIR door. Masked to the
#                    tiles, so the tank, socket, rack, basin and doors keep their own paint, and
#                    the view draws the jars, the plumb and every label over it. The datum rail,
#                    its ticks and the plumb's bob all sit above the line.
#   ceiling_rings    band >= 6: tide rings spreading across the ceiling and the limewash frieze
#   wall_hand        band 7: the wet handprint by the basin (a_sea_b7's, same place and 1.5x),
#                    brought forward as a stark storm-navy silhouette with a navy contour

WATER_Y = int(round(WALL_TOP + 0.6 * (SKIRT["a"] - WALL_TOP)))   # 545
WATER_LINE_H = 8
SUBMERGED = mix(mix(WALL[5], SEAGLASS_HI, 0.25), STORM, 0.4)     # the tiles under the water
REFRACT_ROW = 22                          # one refraction strip: the grout shifts strip by strip
REFRACT_AMP = 12.0
STAIR_TAG_BOX = (54, 356, 150, 394)       # the view's STAIR plate: drips keep off it
# Drips from the porthole: (x, run end y). They come off the sill and run down the STAIR leaf.
PORT_DRIPS = ((40, 478), (162, 532), (70, 330), (128, 318))


def _refract_dx(rng, k):
    return REFRACT_AMP * math.sin(k * 2.3 + 0.6) + rng.uniform(-3.0, 3.0)


def paint_waterline():
    rng = rng_for(870)
    top = WATER_Y + WATER_LINE_H
    below = tile_mask("a", top)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # the submerged field: an over of storm-navy tile at 88% (the plate's straight grout drowns
    # under it), then each tile again in its own tone, shifted strip by strip
    field = Pen(W, H, rng)
    field.rect(-4, top, W + 4, SKIRT["a"] + 2, SUBMERGED, None)
    f = field.done()
    f.putalpha(f.getchannel("A").point(lambda v: v * 88 // 100))
    im.alpha_composite(_apply_mask(f, below))
    tones = {}
    grid = Pen(W, H, rng)
    rows = []
    y, k = top, 0
    while y < SKIRT["a"]:
        rows.append((y, min(SKIRT["a"], y + REFRACT_ROW), _refract_dx(rng, k)))
        y += REFRACT_ROW
        k += 1
    dk, hi = mix(SUBMERGED, STORM, 0.35), mix(SUBMERGED, SEAGLASS_HI, 0.35)
    for y0, y1, dx in rows:
        for i in range(-1, W // G + 2):
            ty = (y0 - DADO_Y) // G
            if (i, ty) not in tones:
                t = rng.uniform(-1, 1)
                tones[(i, ty)] = mix(SUBMERGED, dk, t * 0.45) if t > 0 else mix(SUBMERGED, hi, -t * 0.4)
            grid.rect(i * G + dx, y0, (i + 1) * G + dx, y1, tones[(i, ty)], None)
        # the dado rail, refracted with its strip
        if y0 < DADO_Y + 8 and y1 > DADO_Y - 8:
            grid.rect(-4 + dx, max(y0, DADO_Y - 8), W + 4 + dx, min(y1, DADO_Y + 8), mix(SEAGLASS, STORM, 0.4), None)
            for ry in (DADO_Y - 8, DADO_Y + 8):
                if y0 <= ry <= y1:
                    grid.line([(-4 + dx, ry), (W + 4 + dx, ry)], INK, 2.2)
        # vertical grout: the same joints, shifted with the strip
        for i in range(-1, W // G + 2):
            x = i * G + dx
            grid.line([(x, y0), (x, y1)], INK, 3.0)
        # horizontal grout falling in this strip: broken per tile, each piece a little off
        for gy in range(DADO_Y + G, SKIRT["a"], G):
            if y0 <= gy < y1:
                for i in range(-1, W // G + 2):
                    dy = rng.choice((-3, -2, 0, 2, 3))
                    grid.line([(i * G + dx + 5, gy + dy), ((i + 1) * G + dx - 5, gy + dy)], INK, 3.0)
    g = grid.done()
    g.putalpha(g.getchannel("A").point(lambda v: v * 9 // 10))
    im.alpha_composite(_apply_mask(g, below))
    # the line: flat, sea-glass, its sheen above and a navy contour under
    p = Pen(W, H, rng_for(871))
    p.rect(-4, WATER_Y, W + 4, WATER_Y + WATER_LINE_H, SEA_LINE, None)
    p.line([(-4, WATER_Y + 1.2), (W + 4, WATER_Y + 1.2)], PAPER_HI, 2.4)
    p.line([(-4, WATER_Y + WATER_LINE_H + 0.5), (W + 4, WATER_Y + WATER_LINE_H + 0.5)], INK, 2.4)
    im.alpha_composite(_apply_mask(p.done(), tile_mask("a", WATER_Y - 1, WATER_Y + WATER_LINE_H + 2)))
    # the porthole drips: runs down the STAIR leaf from the sill, a drop at each end
    cx, cy, r = PORTHOLE
    sill = cy + r + 14
    d = Pen(W, H, rng_for(872))
    run = mix(SEAGLASS, STORM, 0.3)
    for x, y1 in PORT_DRIPS:
        wd = 5.5 if y1 > 400 else 4.2
        d.rect(x - wd / 2, sill - 2, x + wd / 2, y1, run, None, r=wd / 2)
        d.line([(x + wd / 2, sill + 2), (x + wd / 2, y1 - 3)], INK, 1.2)
        d.line([(x - wd / 2 + 1.0, sill + 2), (x - wd / 2 + 1.0, y1 - 4)], PAPER_HI, 1.2)
        d.ell(x, y1 + 2, wd * 1.15, wd * 1.4, SEAGLASS_HI, INK, 1.3)
    for x in (88, 108):                       # beads hanging on the sill's lip
        d.ell(x, sill + 3, 2.6, 3.2, SEAGLASS_HI, INK, 1.2)
    dr = d.done()
    keep = Image.new("L", (W, H), 255)
    ImageDraw.Draw(keep).rectangle(STAIR_TAG_BOX, fill=0)
    im.alpha_composite(_apply_mask(dr, keep))
    return im


# (cx, cy, rx, ry): tide rings centred on the ceiling, spreading over the frieze
CEIL_RINGS = ((236, 52, 150, 52), (690, 44, 190, 58), (1060, 56, 130, 46), (1410, 48, 110, 50))


def paint_ceiling_rings():
    rng = rng_for(875)
    light = Pen(W, H, rng)                    # on the storm-navy ceiling: pale rims
    dark = Pen(W, H, rng)                     # on the limewash frieze: navy rims
    for cx, cy, rx, ry in CEIL_RINGS:
        for k, scale in enumerate((1.0, 0.74, 0.5, 0.28)):
            pts = []
            for i in range(40):
                a = 2 * math.pi * i / 40
                rr = scale * (1.0 + 0.05 * math.sin(a * 3 + cx) + rng.uniform(-0.02, 0.02))
                pts.append((cx + math.cos(a) * rx * rr, cy + math.sin(a) * ry * rr))
            wd = 3.2 - k * 0.5
            light.poly(pts, None, SEAGLASS_HI, wd)
            dark.poly(pts, None, STORM, wd)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ceil = Image.new("L", (W, H), 0)
    ImageDraw.Draw(ceil).rectangle((0, 0, W, 45), fill=255)
    frieze = Image.new("L", (W, H), 0)
    ImageDraw.Draw(frieze).rectangle((0, 59, W, 97), fill=255)
    lt = light.done()
    lt.putalpha(lt.getchannel("A").point(lambda v: v * 7 // 10))
    dk = dark.done()
    dk.putalpha(dk.getchannel("A").point(lambda v: v * 85 // 100))
    im.alpha_composite(_apply_mask(lt, ceil))
    im.alpha_composite(_apply_mask(dk, frieze))
    return im


def paint_wall_hand():
    p = Pen(W, H, rng_for(878))
    hand_shape(p, A_HAND[0], A_HAND[1], 1.5, STORM)
    h = p.done()
    h.putalpha(h.getchannel("A").point(lambda v: v * 82 // 100))
    rim = Pen(W, H, rng_for(879))
    hand_shape(rim, A_HAND[0], A_HAND[1], 1.5, INK)
    ra = rim.done().getchannel("A")
    edge = ImageChops.subtract(ra.filter(ImageFilter.MaxFilter(5)), ra)
    ink = Image.new("RGBA", (W, H), INK + (0,))
    ink.putalpha(edge.point(lambda v: v * 8 // 10))
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    im.alpha_composite(h)
    im.alpha_composite(ink)
    # the wet sheen down two fingers and the palm's heel
    s = Pen(W, H, rng_for(880))
    cx, cy = A_HAND
    for dx, top in ((-7, -54), (8, -52)):
        s.line([(cx + (dx - 2) * 1.5, cy + top * 1.5 + 8), (cx + (dx - 2) * 1.5, cy - 8)], SEAGLASS_HI, 1.6)
    s.arc(cx, cy + 21, 30, 36, 200, 250, SEAGLASS_HI, 1.8)
    sh = s.done()
    sh.putalpha(sh.getchannel("A").point(lambda v: v * 7 // 10))
    im.alpha_composite(sh)
    return _apply_mask(im, tile_mask("a"))


def wall_lamp_low(p, cx, cy, drop):
    """wall_lamp() on the same wall mount, its arm let out so the shade hangs `drop` px lower."""
    p.rect(cx - 9, cy - 88, cx + 9, cy - 62, BRASS_LO, INK, 2.2, r=3)
    arm = bezier((cx, cy - 70), (cx + 34 + drop * 0.4, cy - 70 + drop * 0.4), (cx, cy - 22 + drop), 18)
    p.line(arm, INK, 7)
    p.line(arm, BRASS, 3.5)
    y = cy + drop
    p.ell(cx, y - 22, 6, 6, BRASS_HI, INK, 1.8)
    p.poly([(cx - 14, y - 18), (cx + 14, y - 18), (cx + 44, y + 14), (cx - 44, y + 14)], SEAGLASS, INK, 3)
    p.line([(cx - 8, y - 13), (cx - 34, y + 9)], SEAGLASS_HI, 2.4)
    p.rect(cx - 46, y + 12, cx + 46, y + 18, BRASS_LO, INK, 2)
    p.ell(cx, y + 21, 9, 5, AMBER, INK, 1.6)
    p.ell(cx - 2, y + 21, 3, 2, PAPER_HI, None)


def paint_lamp(low):
    p = Pen(W, H, rng_for(870))
    if low:
        wall_lamp_low(p, LAMP_A[0], LAMP_A[1], LAMP_DROP)
    else:
        wall_lamp(p, LAMP_A[0], LAMP_A[1], True)
    return p


def paint_b_lamp_low(rng):
    p = Pen(W, H, rng)
    pendant(p, PENDANT_B[0], PENDANT_B[1] + LAMP_DROP, True)
    return p


def paint_lamp_patch(side, stage):
    """The stage plate's own wall where the painted lamp hung: the plate repainted without its
    lamp and grained exactly as the approved plate, cropped to the lamp's box. Nothing painted
    after the lamp reaches into the box, so the crop meets the plate seamlessly."""
    if side == "a":
        im = paint_view_a(rng_for(0), stage, lamp=False)
        im = grain(im, rng_for(1000))
        box = LAMP_A_BOX
    else:
        im = paint_view_b(rng_for(10), stage, lamp=False)
        im = grain(im, rng_for(1010))
        box = PENDANT_B_BOX
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(im.convert("RGB").crop(box), box[:2])
    return out


def paint_a_rack_salt_v2(rng):
    """Where C stood: an irregular salt crust (#c9d3cc) over a sea-glass grey stain (#8fa59d) in
    the cup, 18-28 px tall, with 6-10 runs dripping off it; a faint ghost of the jar behind.
    Never white."""
    crust, stain = (201, 211, 204), (143, 165, 157)
    p = Pen(W, H, rng)
    cx, cy = RACK_CUPS[2]
    s = 0.55
    ghost = p.layer()
    body = [(-44, -66), (44, -66), (44, 72), (-44, 72)]
    ghost.poly([rot((cx + x, cy + y), (cx, cy), CANT) for x, y in body], mix(PAPER_HI, SEAGLASS_HI, 0.3), None)
    p.put(ghost, 0.2)
    a = rot((cx - 92 * s, cy + 120 * s), (cx, cy), CANT)
    b = rot((cx + 92 * s, cy + 120 * s), (cx, cy), CANT)
    nx, ny = math.sin(math.radians(CANT)), -math.cos(math.radians(CANT))     # up the jar's axis
    dx, dy = -nx, -ny
    n = 14
    top, mid = [], []
    for i in range(n + 1):
        t = i / n
        h = rng.uniform(18, 28)
        bx, by = lerp(a[0], b[0], t), lerp(a[1], b[1], t)
        top.append((bx + nx * h, by + ny * h))
        mid.append((bx + nx * h * rng.uniform(0.45, 0.7), by + ny * h * rng.uniform(0.45, 0.7)))
    base = [b, a]
    p.poly(top + base, stain, INK, 1.6)
    p.poly(mid + base, crust, None)
    # crystals on the crust's edge
    for x, y in mid[1:-1]:
        if rng.random() < 0.6:
            r = rng.uniform(1.6, 3.0)
            p.poly([(x - r, y), (x, y - r * 1.4), (x + r, y), (x, y + r)], crust, mix(INK, stain, 0.5), 1.0)
    # runs off the lip, down the cup
    k = rng.randint(6, 10)
    for i in range(k):
        t = (i + 0.5) / k + rng.uniform(-0.03, 0.03)
        x, y = lerp(a[0], b[0], t), lerp(a[1], b[1], t)
        ln = rng.uniform(10, 30)
        wd = rng.uniform(2.2, 4.0)
        ex, ey = x + dx * ln, y + dy * ln
        p.line([(x, y - 2), (ex, ey)], stain, wd)
        p.ell(ex, ey, wd * 0.7, wd * 0.9, stain, None)
        p.line([(x - wd * 0.3, y), (ex - wd * 0.3, ey - 2)], crust, 1.0)
    p.line([a, b], INK, 1.4)
    return p


# ----------------------------------------------------------------------------- stage overlays
#
# Dread while the lab's puzzles are played (assets/stages/R07/, full-plate RGBA, registered to
# the stage plates). The view lays them over the sea tiers; every hotspot and label is drawn by
# the view above them, so they never hide a clue.
#
#   b2_tidemark / b2_tidemark_bench   band >= 2, from the first arrival (P10, P13, P14 are played
#       under it): a matte storm-navy stain on the walls at jar height, soft-topped, ending
#       on a hard 3 px navy line exactly where the jars are half full (view A) or half way up the
#       bench's glass (view B); three flat wavy sea-glass caustic bands across the upper tiles,
#       as if light came down through water; the floor 8% toward storm.
#   b4_lamp_pool       band >= 4, view B: the pendant only reaches the bench. The room round it
#       goes a shade toward navy, a single warm pool lies on the bench top, and the right third
#       (x > 965) is matte navy, its bell jar, tube rack and drawers left standing as shapes.
#   b4_water_lean      bands 4-6, view A: every free drop of water runs to the STAIR door. Runs
#       under the socket and the rack slant toward it, rivulets cross the floor to it, and a
#       flat pool lies against its sill and goes under the door.

STAGE_OUT = os.path.join(ROOT, "assets", "stages", "R07")
STAIN_ALPHA = 0.55
STAIN_LINE = {"a": 668, "b": 524}      # A: the jars' half-full surface; B: half way up the bench glass
STAIN_SOFT = 64                        # the stain's soft top rises about this far above its line
CAUSTIC = (169, 200, 184)              # #a9c8b8
CAUSTIC_ALPHA = 0.35
CAUSTIC_Y = (60, 260)
FLOOR_Y = {"a": A_FLOOR, "b": 900}
FLOOR_TINT = 0.08
POOL_EDGE_X = 965                      # view B: right of this the lamp no longer reaches
LAMP_WASH = 0.30
DARK_ALPHA = 0.80
DARK_OBJECT_ALPHA = 0.42
LEAN_SLOPE = math.tan(math.radians(12.0))   # wall runs drift 12 degrees toward the stair


def _alpha_layer(col, mask):
    """A flat `col` layer whose alpha is the L `mask`."""
    im = Image.new("RGBA", (W, H), tuple(col[:3]) + (0,))
    im.putalpha(mask)
    return im


def _scale_mask(m, k):
    return m.point(lambda v: int(round(v * k)))


def _stain_mask(side, rng):
    """L mask: 0 above the soft top, ramping to STAIN_ALPHA, held to the line, 0 below it."""
    line = STAIN_LINE[side]
    top = ragged(rng, -20, W + 20, line - STAIN_SOFT + 18, 10, step=24, waves=3)
    poly = Image.new("L", (W, H), 0)
    ImageDraw.Draw(poly).polygon(top + [(W + 20, line + 60), (-20, line + 60)], fill=255)
    soft = poly.filter(ImageFilter.GaussianBlur(14))
    cut = Image.new("L", (W, H), 0)
    ImageDraw.Draw(cut).rectangle((0, 0, W, line - 1), fill=255)
    return _scale_mask(ImageChops.multiply(soft, cut), STAIN_ALPHA)


def _caustics(rng):
    """Three flat wavy bands, thickness breathing along each, across CAUSTIC_Y."""
    p = Pen(W, H, rng)
    for cy in (100, 162, 226):
        amp = rng.uniform(7, 12)
        wl = rng.uniform(190, 300)
        ph = rng.uniform(0, 6.283)
        th0 = rng.uniform(9, 13)
        tph = rng.uniform(0, 6.283)
        upper, lower = [], []
        x = -20.0
        while x <= W + 20:
            y = cy + amp * math.sin(x / wl * 6.283 + ph) + 3 * math.sin(x / 77.0 + ph * 2)
            th = th0 + 4 * math.sin(x / 131.0 + tph)
            upper.append((x, y - th / 2))
            lower.append((x, y + th / 2))
            x += 8
        p.poly(upper + lower[::-1], CAUSTIC, None)
    im = p.done()
    im.putalpha(_scale_mask(im.getchannel("A"), CAUSTIC_ALPHA))
    band = Image.new("L", (W, H), 0)
    ImageDraw.Draw(band).rectangle((0, CAUSTIC_Y[0], W, CAUSTIC_Y[1]), fill=255)
    return im, band


def paint_tidemark(side):
    rng = rng_for(900 if side == "a" else 910)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # the floor, 8% toward storm
    floor = Image.new("L", (W, H), 0)
    ImageDraw.Draw(floor).rectangle((0, FLOOR_Y[side], W, H), fill=int(round(FLOOR_TINT * 255)))
    out.alpha_composite(_alpha_layer(STORM, ImageChops.subtract(floor, _objects_alpha(side))))
    # the stain and its hard line: in view A across the whole wall, doors, basin and socket
    # included (the water stood there); in view B on the tiles behind the bench's glassware
    line = STAIN_LINE[side]
    tiles = tile_mask(side) if side == "b" else Image.new("L", (W, H), 255)
    out.alpha_composite(_alpha_layer(STORM, ImageChops.multiply(_stain_mask(side, rng), tiles)))
    hard = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hard).rectangle((0, line, W, line + 2), fill=255)
    out.alpha_composite(_alpha_layer(INK, ImageChops.multiply(hard, tiles)))
    # caustics over the upper tiles and frieze, off every object and the lamp
    caus, band = _caustics(rng)
    keep = ImageChops.subtract(band, _objects_alpha(side))
    lamp = Image.new("L", (W, H), 0)
    ImageDraw.Draw(lamp).rectangle(LAMP_A_BOX if side == "a" else PENDANT_B_BOX, fill=255)
    keep = ImageChops.subtract(keep, lamp.filter(ImageFilter.MaxFilter(9)))
    out.alpha_composite(_apply_mask(caus, keep))
    return out


def paint_lamp_pool(warm=True):
    """View B from band 4: wash, the lit hole round the bench, the dark right third, the pool.
    `warm` False leaves out the cream pool on the bench top (b4_lamp_pool_cold)."""
    rng = rng_for(920)
    wash = Image.new("L", (W, H), int(round(LAMP_WASH * 255)))
    hole = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hole).ellipse((490 - 330, 470 - 230, 490 + 330, 470 + 230), fill=255)
    hole = hole.filter(ImageFilter.GaussianBlur(60))
    lamp = Image.new("L", (W, H), 0)
    ImageDraw.Draw(lamp).rectangle(PENDANT_B_BOX, fill=255)
    hole = ImageChops.lighter(hole, lamp.filter(ImageFilter.GaussianBlur(6)))
    a = ImageChops.multiply(wash, ImageChops.invert(hole))
    # the right third: flat matte navy, a hard edge; the objects there kept as shapes
    third = Image.new("L", (W, H), 0)
    ImageDraw.Draw(third).rectangle((POOL_EDGE_X, 0, W, H), fill=255)
    obj = _objects_alpha("b")
    dark = ImageChops.add(_scale_mask(ImageChops.subtract(third, obj), DARK_ALPHA),
                          _scale_mask(ImageChops.multiply(third, obj), DARK_OBJECT_ALPHA))
    out = _alpha_layer(STORM, ImageChops.lighter(a, dark))
    # the edge of the dark: one hard navy hairline, so it reads as meant, not as a shadow
    edge = Pen(W, H, rng)
    edge.line([(POOL_EDGE_X, 112), (POOL_EDGE_X, H)], STORM, 2.0)
    e = edge.done()
    out.alpha_composite(_apply_mask(e, ImageChops.invert(obj)))
    if not warm:
        return out
    # the single warm pool on the bench top, under the shade
    pool = Pen(W, H, rng)
    pool.ell(PENDANT_B[0], 612, 250, 18, AMBER, None)
    pool.ell(PENDANT_B[0], 612, 150, 11, mix(AMBER, PAPER_HI, 0.4), None)
    pl = pool.done().filter(ImageFilter.GaussianBlur(5))
    pl.putalpha(_scale_mask(pl.getchannel("A"), 0.42))
    out.alpha_composite(pl)
    return out


def paint_water_lean():
    """View A, bands 4-6: everything wet runs to the STAIR door."""
    rng = rng_for(930)
    water = mix(WATER_PAINT, STORM, 0.25)
    p = Pen(W, H, rng)
    # wall runs from under the socket and the rack shelf, drifting toward the stair
    runs = Pen(W, H, rng)
    for x0, y0, y1 in ((742, 684, 832), (776, 684, 832), (812, 684, 832), (1366, 640, 832),
                       (1396, 610, 832), (1428, 650, 832), (196, 600, 832), (712, 640, 832)):
        wd = rng.uniform(4.0, 6.5)
        pts = []
        n = 16
        for i in range(n + 1):
            t = i / n
            y = lerp(y0, y1, t)
            pts.append((x0 - (y - y0) * LEAN_SLOPE + math.sin(t * 7 + x0) * 1.2, y))
        runs.line(pts, water, wd)
        runs.ell(pts[0][0], pts[0][1], wd * 0.7, wd * 0.9, water, None)
        runs.line([(x + wd * 0.3, y) for x, y in pts[2:]], SEAGLASS_HI, 1.0)
    r = runs.done()
    r.putalpha(_scale_mask(r.getchannel("A"), 0.85))
    r = _apply_mask(r, tile_mask("a"))
    # the floor: rivulets from the rack legs, the tank's feet and the basin, all to the stair
    turn = Image.new("L", (W, H), 255)
    ImageDraw.Draw(turn).rectangle((596, 846, 852, 918), fill=0)
    fl = Pen(W, H, rng)
    sources = ((1188, 858), (1046, 864), (884, 860), (690, 870), (520, 862), (384, 866), (300, 858))
    for k, (sx, sy) in enumerate(sources):
        wd = rng.uniform(4.0, 7.0)
        pts = []
        x = sx
        ph = rng.uniform(0, 6.283)
        while x > 190:
            t = (sx - x) / max(1.0, sx - 190)
            y = sy + (880 - sy) * t + 2.2 * math.sin(x / 41.0 + ph)
            pts.append((x, y))
            x -= 10
        pts.append((190, 880))
        fl.line(pts, INK, wd + 3.0)
        fl.line(pts, SEAGLASS_HI, wd)
        fl.line([(x, y - wd * 0.2) for x, y in pts], mix(SEAGLASS_HI, PAPER_HI, 0.5), 1.2)
    # the pool against the STAIR sill, flat, dark and hard-edged, and its tongue under the door
    pool = mix(STORM, SEAGLASS, 0.3)
    fl.poly([(4, 853), (196, 853), (268, 863), (246, 876), (150, 890), (4, 894)], pool, INK, 2.4)
    fl.line([(8, 857), (200, 857), (256, 864)], SEAGLASS_HI, 2.0)
    fl.rect(STAIR_LEAF[0] + 4, A_FLOOR - 7, STAIR_LEAF[2] - 4, A_FLOOR, STORM_DK, None)
    f = fl.done()
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(r)
    out.alpha_composite(_apply_mask(f, turn))
    return out


# datum_water_r3   band >= 3, view A: the sea stands flat at the DATUM. A hard surface line
#     across the whole room flush under the brass rail (y 304-313: sea-glass, a paper sheen on
#     top, a navy contour under), and below it a flat #5f8f86 wash at 45% over everything except
#     the hotspot art (doors, basin, tank, socket, rack, plates, the turn plate), which the wash
#     leaves out so it stays crisp and registered. The view lays the room under the wash again
#     6 px to the right (R07_view DATUM_SHIFT) wherever this layer's alpha is not 0.
DATUM_SURF = (304, 313)
DATUM_WASH = (95, 143, 134)            # #5f8f86
DATUM_WASH_ALPHA = 0.45


def _hotspot_art_alpha():
    """L mask (1x) of view A's hotspot art, painted alone: no conduit, lamp or floor rings."""
    def run():
        p = Pen(W, H, rng_for(0))
        plate(p, 878, 270, 974, 296)
        plumb_bracket(p, PLUMB_A[0], PLUMB_A[1])
        return_door(p)
        bolt_closed(p)
        basin(p)
        tank(p)
        socket(p)
        rack(p)
        vault_door(p)
        turn_plate(p)
        return p.done().getchannel("A").point(lambda v: 255 if v > 128 else 0)
    return _cached(("hotspot_art", "a"), run)


def paint_datum_water(wash=DATUM_WASH, alpha=DATUM_WASH_ALPHA):
    below = Image.new("L", (W, H), 0)
    ImageDraw.Draw(below).rectangle((0, DATUM_SURF[1], W, H), fill=255)
    below = ImageChops.subtract(below, _hotspot_art_alpha())
    out = _alpha_layer(wash, _scale_mask(below, alpha))
    p = Pen(W, H, rng_for(930))
    y0, y1 = DATUM_SURF
    p.rect(-4, y0, W + 4, y1, SEA_LINE, None)
    p.line([(-4, y0 + 1.2), (W + 4, y0 + 1.2)], PAPER_HI, 2.4)
    p.line([(-4, y1 - 0.4), (W + 4, y1 - 0.4)], INK, 2.6)
    out.alpha_composite(p.done())
    return out


# r07_submerged_b3 / r07_submerged_b5   view A from band 3 / band 5, in place of the stage plate:
#     the room under a surface. The stage plate (view_a_s3 / view_a_s5, seeded and grained as in
#     ASSETS) painted without the wall lamp and its cream light (the view lays a_lamp / a_lamp_low
#     over every view-A plate from band 2 anyway, so no lamp patch is needed), with
#       - across the top SUB_BAND px the underside of a water surface: flat sea-glass, a ragged
#         2-3 px navy lower contour and SUB_STRIPES slow matte caustic stripes (no glow, no blend);
#       - below it everything but the hotspot art multiplied toward storm navy (SUB_WASH), so
#         every door, the basin, tank, socket, rack and plate keep their full-ink contours;
#       - one straight waterline across the whole room at the tank's lean (GRAVITY, -8 degrees:
#         rising to the right), through the STAIR door, the basin, the tank, the jars and the
#         RECORDS door: a 3 px navy meniscus, a 2 px pale sea-glass highlight over it, and the
#         water side under it SUB_UNDER darker again.
SUB_BAND = 152                          # the top 14% (y 0-152)
SUB_SURFACE = (169, 200, 184)           # #a9c8b8
SUB_CAUSTICS = ((143, 179, 166), (195, 216, 204))   # #8fb3a6, #c3d8cc
SUB_STRIPES = 6
# The card asked for 35% / 55%; measured in-game (1024x768, y 70-650) under the sea tiers, the
# tide stain and the datum water that only reached 120 / 108 mean luma against a target of
# 90-100 / 80-90, so the wash is 60% / 85% (it never touches the hotspot art).
SUB_WASH = {3: 0.60, 5: 0.85}
SUB_UNDER = 0.10
SUB_LEAN_DEG = -8.0                     # R07Sim.GRAVITY_DEG: the tank's lean
SUB_PIVOT = (724, 640)                  # the waterline passes here; at x 0 it is 101 px lower


# datum_water_sub: datum_water_r3 exactly, but its wash storm navy at 30%, not #5f8f86 at 45%:
#     over a submerged plate the pale wash would lift the room back out of the water. The view
#     uses it in place of datum_water_r3 (and as the mask of the 6 px shift) while submerged.


def sub_waterline_y(x):
    return SUB_PIVOT[1] + math.tan(math.radians(SUB_LEAN_DEG)) * (x - SUB_PIVOT[0])


def _multiply_toward(im, col, k, mask):
    """`im` (RGB) multiplied toward `col` by `k` where the L `mask` is set."""
    f = tuple(1.0 - k * (1.0 - c / 255.0) for c in col)
    r, g, b = im.split()
    dark = Image.merge("RGB", [ch.point(lambda v, m=m: int(round(v * m))) for ch, m in zip((r, g, b), f)])
    return Image.composite(dark, im, mask)


def paint_submerged(stage):
    rng = rng_for(940 + stage)
    base = grain(paint_view_a(rng_for(0), stage, lamp=False, pool=False), rng_for(1000))
    im = base.convert("RGB")
    # the wash below the surface band, off the hotspot art
    below = Image.new("L", (W, H), 0)
    ImageDraw.Draw(below).rectangle((0, SUB_BAND, W, H), fill=255)
    im = _multiply_toward(im, STORM, SUB_WASH[stage], ImageChops.subtract(below, _hotspot_art_alpha()))
    # the water side of the waterline, 10% darker again (everything: it is all under it)
    under = Image.new("L", (W, H), 0)
    ImageDraw.Draw(under).polygon([(-4, sub_waterline_y(-4)), (W + 4, sub_waterline_y(W + 4)),
                                   (W + 4, H + 4), (-4, H + 4)], fill=255)
    im = _multiply_toward(im, (0, 0, 0), SUB_UNDER, under)
    p = Pen(W, H, rng)
    # the meniscus: a pale highlight on the air side, then 3 px navy. The card asked for 1 px; at
    # 1024x768 that is lost on the washed tiles, so it is 2 px (1.4 px in game)
    xs = (-8, W + 8)
    p.line([(x, sub_waterline_y(x) - 2.5) for x in xs], SUB_CAUSTICS[1], 2.0)
    p.line([(x, sub_waterline_y(x)) for x in xs], INK, 3.0)
    # the underside of the surface: a flat band, a ragged navy lower edge
    edge = []
    x = -8.0
    while x <= W + 8:
        edge.append((x, SUB_BAND - 3 + rng.uniform(-2.2, 2.2) + 1.6 * math.sin(x / 53.0)))
        x += rng.uniform(9, 16)
    edge.append((W + 8, SUB_BAND - 3))
    p.poly([(-8, -8), (W + 8, -8)] + edge[::-1], SUB_SURFACE, None)
    # slow caustic stripes, matte: wide gentle waves, alternating the two tones
    for k in range(SUB_STRIPES):
        cy = 16 + k * (SUB_BAND - 34) / (SUB_STRIPES - 1)
        amp = rng.uniform(4, 8)
        wl = rng.uniform(320, 520)
        ph = rng.uniform(0, 6.283)
        th0 = rng.uniform(5, 9)
        tph = rng.uniform(0, 6.283)
        upper, lower = [], []
        x = -20.0
        while x <= W + 20:
            y = cy + amp * math.sin(x / wl * 6.283 + ph)
            th = th0 * (0.55 + 0.45 * math.sin(x / 173.0 + tph))
            upper.append((x, y - th / 2))
            lower.append((x, y + th / 2))
            x += 8
        p.poly(upper + lower[::-1], SUB_CAUSTICS[k % 2], None)
    p.line(edge, INK, 2.6)
    over = p.done()
    out = im.convert("RGBA")
    out.alpha_composite(over)
    return out.convert("RGB")


STAGE_ASSETS = [  # name, painter: assets/stages/R07/<name>.png, RGBA, no grain
    ("b2_tidemark", lambda: paint_tidemark("a")),
    ("b2_tidemark_bench", lambda: paint_tidemark("b")),
    ("b4_lamp_pool", paint_lamp_pool),
    ("b4_water_lean", paint_water_lean),
    ("datum_water_r3", paint_datum_water),
    ("b4_lamp_pool_cold", lambda: paint_lamp_pool(warm=False)),
    ("datum_water_sub", lambda: paint_datum_water(STORM, 0.30)),
    ("r07_submerged_b3", lambda: paint_submerged(3)),
    ("r07_submerged_b5", lambda: paint_submerged(5)),
]


# ----------------------------------------------------------------------------- the list

ASSETS = [  # name, seed index, painter, opaque, grain
    ("view_a", 0, lambda r: paint_view_a(r, 2), True, True),
    ("view_a_s3", 0, lambda r: paint_view_a(r, 3), True, True),
    ("view_a_s4", 0, lambda r: paint_view_a(r, 4), True, True),
    ("view_a_s5", 0, lambda r: paint_view_a(r, 5), True, True),
    ("view_a_s6", 0, lambda r: paint_view_a(r, 6), True, True),
    ("view_a_s7", 0, lambda r: paint_view_a(r, 7), True, True),
    ("view_a_sever", 0, lambda r: paint_view_a(r, "sever"), True, True),
    ("view_b", 10, lambda r: paint_view_b(r, 2), True, True),
    ("view_b_s3", 10, lambda r: paint_view_b(r, 3), True, True),
    ("view_b_s4", 10, lambda r: paint_view_b(r, 4), True, True),
    ("view_b_s5", 10, lambda r: paint_view_b(r, 5), True, True),
    ("view_b_s6", 10, lambda r: paint_view_b(r, 6), True, True),
    ("view_b_s7", 10, lambda r: paint_view_b(r, 7), True, True),
    ("view_b_sever", 10, lambda r: paint_view_b(r, "sever"), True, True),
    ("view_b_s3_v2", 10, lambda r: paint_view_b(r, 3, clear_tide=True), True, True),
    ("view_b_s4_v2", 10, lambda r: paint_view_b(r, 4, clear_tide=True), True, True),
    ("a_tank_glass", 20, paint_a_tank_glass, False, False),
    ("a_reflect_three", 21, lambda r: paint_a_reflect(r, 3), False, False),
    ("a_reflect_two", 21, lambda r: paint_a_reflect(r, 2), False, False),
    ("a_vault_ajar", 22, paint_a_vault_ajar, False, False),
    ("a_return_unbolted", 23, paint_a_return_unbolted, False, False),
    ("a_socket_tag", 24, paint_a_socket_tag, False, False),
    ("a_rack_salt", 25, paint_a_rack_salt, False, False),
    ("a_rack_salt_v2", 26, paint_a_rack_salt_v2, False, False),
    ("a_sea_b2", 80, lambda r: paint_sea_b2("a"), False, False),
    ("a_sea_b3", 81, lambda r: paint_sea_b3("a"), False, False),
    ("a_sea_b4", 82, lambda r: paint_sea_b4("a"), False, False),
    ("a_sea_b6", 83, lambda r: paint_sea_b6("a"), False, False),
    ("a_sea_b6_slot", 84, lambda r: paint_sea_b6_slot(), False, False),
    ("a_sea_b7", 85, lambda r: paint_sea_b7("a"), False, False),
    ("waterline", 100, lambda r: paint_waterline(), False, False),
    ("ceiling_rings", 101, lambda r: paint_ceiling_rings(), False, False),
    ("wall_hand", 102, lambda r: paint_wall_hand(), False, False),
    ("a_lamp", 86, lambda r: paint_lamp(False), False, False),
    ("a_lamp_low", 87, lambda r: paint_lamp(True), False, False),
    ("a_lamp_patch_s6", 88, lambda r: paint_lamp_patch("a", 6), False, False),
    ("a_lamp_patch_s7", 88, lambda r: paint_lamp_patch("a", 7), False, False),
    ("b_sea_b2", 90, lambda r: paint_sea_b2("b"), False, False),
    ("b_sea_b3", 91, lambda r: paint_sea_b3("b"), False, False),
    ("b_sea_b4", 92, lambda r: paint_sea_b4("b"), False, False),
    ("b_sea_b6", 93, lambda r: paint_sea_b6("b"), False, False),
    ("b_sea_b7", 95, lambda r: paint_sea_b7("b"), False, False),
    ("b_lamp_low", 96, paint_b_lamp_low, False, False),
    ("b_lamp_patch_s6", 98, lambda r: paint_lamp_patch("b", 6), False, False),
    ("b_lamp_patch_s7", 98, lambda r: paint_lamp_patch("b", 7), False, False),
    ("b_shells_loose", 30, paint_b_shells_loose, False, False),
    ("b_shells_rings", 31, paint_b_shells_rings, False, False),
    ("b_thumb", 32, paint_b_thumb, False, False),
    ("b_strip", 33, paint_b_strip, False, False),
    ("b_stand_empty", 34, paint_b_stand_empty, False, False),
    ("b_frame", 38, paint_b_frame, False, False),
    ("b_lid_closed", 39, paint_b_lid_closed, False, False),
    ("b_register_open", 35, paint_b_register_open, False, False),
    ("b_lid_open", 36, paint_b_lid_open, False, False),
    ("b_fog", 37, paint_b_fog, False, False),
    ("c_tilt_rack", 40, paint_c_tilt_rack, True, True),
    ("c_balance", 41, paint_c_balance, True, True),
    ("c_frame", 42, paint_c_frame, True, True),
    ("jar_back", 50, lambda r: jar(r, 88, 150, (10, 28, 78, 140), (24, 112, 64, 132), False), False, False),
    ("jar_front", 51, lambda r: jar(r, 88, 150, (10, 28, 78, 140), (24, 112, 64, 132), True), False, False),
    ("c_jar_back", 52, lambda r: jar(r, 160, 272, (18, 50, 142, 254), (50, 214, 110, 244), False), False, False),
    ("c_jar_front", 53, lambda r: jar(r, 160, 272, (18, 50, 142, 254), (50, 214, 110, 244), True), False, False),
    ("c_cradle", 54, paint_c_cradle, False, False),
    ("plumb", 55, lambda r: plumb_sprite(r, 40, 240, (20, 4), (20, 222), 14, (120, 144)), False, False),
    ("c_plumb", 56, lambda r: plumb_sprite(r, 48, 300, (24, 4), (24, 278), 16), False, False),
    ("c_tag", 57, paint_c_tag, False, False),
    ("c_beam", 58, paint_c_beam, False, False),
    ("c_pan", 59, paint_c_pan, False, False),
    ("c_tray", 60, paint_c_tray, False, False),
    ("c_thumb", 61, paint_c_thumb, False, False),
    ("c_sample_n", 62, lambda r: paint_c_sample(r, "n"), False, False),
    ("c_sample_w", 63, lambda r: paint_c_sample(r, "w"), False, False),
    ("c_sample_f", 64, lambda r: paint_c_sample(r, "f"), False, False),
    ("c_sample_tube", 75, paint_c_sample_tube, False, False),
    ("c_card", 65, paint_c_card, False, False),
    ("c_pin", 66, paint_c_pin, False, False),
    ("c_needle", 67, paint_c_needle, False, False),
    ("c_key_down", 68, sprite(140, 100, lambda p: key_housing(p, 0, 0, True)), False, False),
    ("c_lever_down", 69, sprite(130, 120, lambda p: tip_lever(p, 0, 0, True)), False, False),
    ("c_section", 70, paint_c_section, False, False),
    ("c_name_tab", 71, paint_c_name_tab, False, False),
    ("c_strip", 72, paint_c_strip, False, False),
    ("c_seal_down", 73, sprite(140, 140, lambda p: seal_key(p, 0, 0, True)), False, False),
    ("c_frame_glass", 74, paint_c_frame_glass, False, False),
]


def main(argv):
    pats = argv or ["*"]
    for name, k, fn, opaque, gr in ASSETS:
        if not any(fnmatch.fnmatch(name, pat) for pat in pats):
            continue
        rng = rng_for(k)
        res = fn(rng)
        im = res.done() if isinstance(res, Pen) else res
        if gr is not False:
            im = grain(im, rng_for(1000 + (k if gr is True else gr)))
        save(im, name, opaque)
    for name, fn in STAGE_ASSETS:
        if any(fnmatch.fnmatch(name, pat) for pat in pats):
            im = fn()
            save(im, name, im.mode == "RGB", STAGE_OUT)


if __name__ == "__main__":
    main(sys.argv[1:])
