#!/usr/bin/env python3
"""R07 Wet Laboratory painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R07/*.png:

  view_a, view_a_s3, view_a_s5, view_a_s7, view_a_sever
                      the tank wall stage plates (1448x1086 opaque): bands 2, 3-4, 5-6, 7, sever
  view_b, view_b_s3, view_b_s5, view_b_s7, view_b_sever
                      the bench stage plates (same staging)
  a_tank_glass, a_reflect_three, a_reflect_two, a_vault_ajar, a_return_unbolted,
  a_socket_tag, a_rack_salt                       view A overlays (RGBA, registered)
  b_shells_loose, b_shells_rings, b_thumb, b_strip, b_stand_empty, b_register_open,
  b_lid_open, b_fog                               view B overlays (RGBA, registered)
  c_tilt_rack, c_balance, c_frame                 close-up plates (opaque)
  c_damp                                          close-up damp vignette (RGBA)
  jar_*, c_jar_*, c_cradle, plumb, c_plumb, c_tag, c_beam, c_pan, c_tray, c_thumb,
  c_sample_{n,w,f}, c_card, c_pin, c_needle, c_key_down, c_lever_down, c_section,
  c_name_tab, c_strip, c_seal_down, c_frame_glass sprites (RGBA, exact sizes and pivots)

The room is square to its brass DATUM: every tile course, shelf and the floor is level in plate
space. Gravity is the thing that is off (the view rotates the plumb and the water); the plates
only carry the basin's slanted pool as the one painted hint.

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
    """Draws in 1x logical coordinates on a supersampled RGBA canvas."""

    def __init__(self, w, h, rng, bg=None):
        self.w, self.h, self.rng = w, h, rng
        self.im = Image.new("RGBA", (w * SS, h * SS), rgba(bg) if bg else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def iw(self, w):
        return max(1, int(round((w + self.rng.uniform(-0.3, 0.3)) * SS)))

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

    def arc(self, cx, cy, rx, ry, a0, a1, col=INK, w=3.0):
        box = ((cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS)
        self.d.arc(box, a0, a1, fill=rgba(col), width=self.iw(w))

    def layer(self, tint=None):
        """A transparent layer; `tint` sets the colour under alpha 0 so blurred edges don't grey."""
        lay = Pen(self.w, self.h, self.rng)
        if tint is not None:
            lay.im = Image.new("RGBA", lay.im.size, tuple(tint[:3]) + (0,))
            lay.d = ImageDraw.Draw(lay.im)
        return lay

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


def save(im, name, opaque):
    os.makedirs(OUT, exist_ok=True)
    if opaque:
        im = im.convert("RGB")
    else:
        im = im.convert("RGBA")
        a = im.getchannel("A")
        clear = a.point(lambda v: 255 if v == 0 else 0)
        im.paste((0, 0, 0, 0), mask=clear)
    path = os.path.join(OUT, name + ".png")
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

def tile_field(p, rng, x0, y0, x1, y1, g, ox, oy, joint_a=0.35, base=TILE):
    """Pale glazed tiles on a g-px grid anchored at (ox, oy); ink joints at joint_a."""
    cols = range(int(math.floor((x0 - ox) / g)), int(math.ceil((x1 - ox) / g)) + 1)
    rows = range(int(math.floor((y0 - oy) / g)), int(math.ceil((y1 - oy) / g)) + 1)
    lay = p.layer()
    p.rect(x0, y0, x1, y1, base, None)
    for j in rows:
        for i in cols:
            tx, ty = ox + i * g, oy + j * g
            t = rng.uniform(-1, 1)
            c = mix(base, TILE_DK, t * 0.35) if t > 0 else mix(base, TILE_HI, -t * 0.3)
            ax0, ay0, ax1, ay1 = max(tx, x0), max(ty, y0), min(tx + g, x1), min(ty + g, y1)
            if ax1 <= ax0 or ay1 <= ay0:
                continue
            p.rect(ax0, ay0, ax1, ay1, c, None)
            if rng.random() < 0.55 and tx + g * 0.6 < x1 and ty + g * 0.3 < y1 and tx > x0 and ty > y0:
                # a glaze glint along the upper left of the tile
                p.line([(tx + g * 0.16, ty + g * 0.2), (tx + g * 0.16 + g * rng.uniform(0.2, 0.42), ty + g * 0.2)],
                       TILE_HI, max(1.5, g / 26))
    for i in cols:
        x = ox + i * g
        if x0 < x < x1:
            lay.line([(x, y0), (x, y1)], INK, max(2.0, g / 24))
    for j in rows:
        y = oy + j * g
        if y0 < y < y1:
            lay.line([(x0, y), (x1, y)], INK, max(2.0, g / 24))
    p.put(lay, joint_a)


def shell(p, stage, floor=True):
    """Ceiling band, limewash frieze, glazed tile wall on the 48 px grid, dado course at y=600,
    skirting and timber floor. Uses its own generator so overlays can rebuild patches of it."""
    rng = rng_for(500)
    ja = 0.35 if stage not in (7,) else 0.6
    p.rect(-4, -4, W + 4, 50, STORM, None)
    p.line([(-4, 36), (W + 4, 36)], STORM_HI, 2)
    p.rect(-4, 46, W + 4, 58, STORM, INK, 3)
    p.rect(-4, 58, W + 4, 100, LIME, None)
    lay = p.layer()
    for _ in range(12):
        x = rng.uniform(0, W)
        lay.arc(x, 80, rng.uniform(70, 150), 9, 200, 340, PAPER, 3)
    p.put(lay, 0.6)
    p.rect(-4, 98, W + 4, 112, SEAGLASS, INK, 2.5)
    p.line([(-4, 102), (W + 4, 102)], SEAGLASS_HI, 1.6)
    tile_field(p, rng, -4, 112, W + 4, 594, 48, 0, 600, ja)
    tile_field(p, rng, -4, 606, W + 4, 884, 48, 0, 600, ja, base=mix(TILE, SEAGLASS_HI, 0.25))
    # the dado course: a glazed bullnose at y=600
    p.rect(-4, 592, W + 4, 608, SEAGLASS, INK, 2.5)
    p.line([(-4, 596), (W + 4, 596)], SEAGLASS_HI, 2)
    # skirting and floor
    p.rect(-4, 882, W + 4, 900, STORM, INK, 2.5)
    p.line([(-4, 886), (W + 4, 886)], STORM_HI, 1.5)
    if floor:
        p.rect(-4, 900, W + 4, H + 4, TIMBER, INK, 3)
        y, k = 900, 0
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


def damp(p, rng, stage):
    """Damp rising up the tiles from the floor: a mottled wet band, a brown tide-mark rim with a
    salt fringe, a second fainter rim below and thin runs. Band 7 adds stark ringed blooms above."""
    if stage in (2,):
        return
    sever = stage == "sever"
    top = {3: 806, 5: 600, 7: 566, "sever": 600}[stage]
    edge = ragged(rng, -10, W + 10, top, 30 if stage != 3 else 20)
    band = [(-10, 892)] + edge + [(W + 10, 892)]
    lay = p.layer(DAMP)
    lay.poly(band, DAMP, None)
    mott = value_noise(rng, W * SS, H * SS, 46 * SS).point(lambda v: 110 + v * 145 // 255)
    lay.im.putalpha(ImageChops.multiply(lay.im.getchannel("A"), mott))
    p.put_soft(lay, 5, 0.16 if sever else {3: 0.42, 5: 0.46, 7: 0.5}[stage])
    runs = p.layer(DAMP)
    for x, y in edge[1:-1]:
        if rng.random() < 0.45:
            ln = rng.uniform(30, 120)
            runs.line([(x, y + 4), (x + rng.uniform(-2, 2), y + ln)], DAMP, rng.uniform(2.5, 5))
    p.put_soft(runs, 1.5, 0.12 if sever else 0.4)
    rim_col = mix(TIMBER, INK, 0.2)
    rim = p.layer(rim_col)
    rim.line(edge, rim_col, 4)
    rim.line([(x, y + 30 + rng.uniform(-3, 3)) for x, y in edge], rim_col, 2.4)
    p.put_soft(rim, 0.8, 0.22 if sever else 0.78)
    salt = p.layer()
    for x, y in edge:
        for _ in range(4):
            salt.ell(x + rng.uniform(-10, 10), y - rng.uniform(1, 7), rng.uniform(1.2, 2.8), None, SALT, None)
    salt.line([(x, y - 3) for x, y in edge], SALT, 2)
    p.put(salt, 0.5 if sever else 0.9)
    if stage in (7, "sever"):
        # ringed blooms climbing above the dado: each a dark heart inside two tide rims
        for cx, cy, r in ((150, 470, 70), (330, 360, 54), (880, 250, 48), (1240, 420, 66), (560, 230, 40),
                          (1010, 200, 36), (60, 230, 44), (1400, 250, 50)):
            rings = []
            for scale in (1.0, 0.72, 0.42):
                pts = []
                for i in range(28):
                    a = 2 * math.pi * i / 28
                    rr = r * scale * rng.uniform(0.86, 1.1)
                    pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.86))
                rings.append(pts)
            b = p.layer(DAMP)
            b.poly(rings[0], DAMP, None)
            b.poly(rings[2], mix(DAMP, STORM, 0.4), None)
            p.put_soft(b, 4, 0.1 if sever else 0.34)
            rr = p.layer(rim_col)
            rr.poly(rings[0], None, rim_col, 3)
            rr.poly(rings[1], None, rim_col, 1.8)
            p.put(rr, 0.15 if sever else 0.6)


def lamp_pool(p, cx, cy, rx, ry, op):
    lay = p.layer(PAPER_HI)
    lay.ell(cx, cy, rx, ry, PAPER_HI, None)
    p.put_soft(lay, max(rx, ry) * 0.35, op)


def grade(im, stage):
    """Stage colour: a few percent cooler per band, held bright; sever is grey daylight."""
    if stage == 2:
        return im
    if stage == "sever":
        rgb = im.convert("RGB")
        grey = rgb.convert("L").convert("RGB")
        rgb = Image.blend(rgb, grey, 0.42)
        cool = Image.new("RGB", rgb.size, mix(PAPER_HI, SEAGLASS_HI, 0.3))
        return Image.blend(rgb, cool, 0.08)
    mul = {3: (0.96, 0.985, 1.0), 5: (0.92, 0.965, 0.995), 7: (0.89, 0.95, 0.985)}[stage]
    r, g, b = im.convert("RGB").split()
    r = r.point(lambda v: int(v * mul[0]))
    g = g.point(lambda v: int(v * mul[1]))
    b = b.point(lambda v: min(255, int(v * mul[2] + 3)))
    return Image.merge("RGB", (r, g, b))


# ----------------------------------------------------------------------------- view A parts

DATUM_Y0, DATUM_Y1 = 296, 304


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


def return_door(p):
    # frame
    p.rect(12, 314, 224, 900, STORM_DK, INK, 3)
    p.rect(20, 322, 216, 900, STORM, INK, 2)
    # leaf: painted iron
    p.rect(28, 330, 208, 900, STORM_HI, INK, 3)
    p.rect(46, 410, 190, 590, mix(STORM_HI, STORM, 0.35), INK, 2.2, r=4)
    p.rect(46, 660, 190, 872, mix(STORM_HI, STORM, 0.35), INK, 2.2, r=4)
    p.line([(48, 413), (188, 413)], mix(STORM_HI, PAPER, 0.25), 1.6)
    p.line([(48, 663), (188, 663)], mix(STORM_HI, PAPER, 0.25), 1.6)
    for y in range(344, 896, 32):
        rivet(p, 36, y)
        rivet(p, 200, y)
    for x in range(68, 190, 32):
        rivet(p, x, 400)
        rivet(p, x, 602)
    # hinges on the left (hinge edge)
    for y in (380, 820):
        p.rect(14, y - 18, 52, y + 18, BRASS_LO, INK, 2.2, r=3)
        p.ell(18, y, 6, 16, BRASS, INK, 1.8)
    plate(p, 70, 360, 166, 390)


def bolt_housing(p, home):
    """The stair bolt: a tall brass housing with a knob riding a slot. Home, the knob sits at the
    right end and the bolt is shot into the jamb keeper; drawn back, the knob is left, keeper empty."""
    p.rect(204, 602, 222, 638, STORM_DK, INK, 2)          # keeper on the jamb
    p.rect(210, 613, 220, 627, SLOT, None)
    p.rect(146, 584, 204, 636, BRASS_LO, INK, 2.4, r=4)
    p.line([(150, 588), (200, 588)], BRASS, 1.6)
    p.rect(154, 592, 196, 600, SLOT, None)                # the knob's slot
    rod = (160, 614, 222, 626) if home else (150, 614, 202, 626)
    p.rect(*rod, BRASS_HI, INK, 2)
    kx = 188 if home else 160
    p.rect(kx - 4, 594, kx + 4, 616, BRASS, INK, 1.8, r=2)
    p.ell(kx, 594, 6, 6, BRASS_HI, INK, 2)
    for y in (606, 630):
        screw(p, 152, y, 2.4)
        screw(p, 198, y, 2.4)


def bolt_closed(p):
    bolt_housing(p, True)


def basin(p):
    # tap on the wall: flange, body, cross handle and a short downturned nozzle
    p.ell(300, 522, 14, 14, BRASS_LO, INK, 2.2)
    p.rect(290, 512, 310, 540, BRASS, INK, 2.4, r=4)
    p.line([(294, 516), (294, 536)], BRASS_HI, 1.8)
    p.rect(298, 498, 302, 512, BRASS, INK, 1.4)
    p.line([(282, 498), (318, 498)], INK, 7)
    p.line([(282, 498), (318, 498)], BRASS_HI, 3.4)
    p.poly([(295, 538), (305, 538), (306, 556), (308, 561), (292, 561), (294, 556)], BRASS, INK, 2.2)
    # pedestal
    p.poly([(276, 742), (324, 742), (330, 868), (344, 892), (256, 892), (270, 868)], ENAMEL, INK, 3)
    p.line([(316, 748), (320, 864)], PAPER_HI, 2.2)
    p.line([(282, 750), (278, 864)], ENAMEL_DK, 2.6)
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
    # the pool: level at y~700 by the bowl, but slanted 8 degrees rising to the right
    t = math.tan(math.radians(8))
    water = p.layer()
    surf = [(200, 700 + 100 * t), (400, 700 - 100 * t)]
    water.poly(surf + [(400, 760), (200, 760)], SEAGLASS, None)
    water.line([(200, 700 + 100 * t + 3), (400, 700 - 100 * t + 3)], SEAGLASS_HI, 3)
    water.line(surf, INK, 2.4)
    p.put(water, 1.0, poly_mask(inner))
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


TANK = (392, 410, 792, 840)
TANK_IN = (412, 440, 772, 800)


def tank_frame(p):
    x0, y0, x1, y1 = TANK
    ix0, iy0, ix1, iy1 = TANK_IN
    for r in ((x0, y0, x1, iy0), (x0, iy1, x1, y1), (x0, y0, ix0, y1), (ix1, y0, x1, y1)):
        p.rect(*r, STORM, None)
    p.rect(x0, y0, x1, y1, None, INK, 3)
    p.rect(ix0, iy0, ix1, iy1, None, INK, 3)
    # a tarnished brass lip on the rim and a skirt band
    p.rect(x0 - 6, y0 - 6, x1 + 6, y0 + 8, BRASS_LO, INK, 2.4, r=2)
    p.line([(x0 - 4, y0 - 2), (x1 + 4, y0 - 2)], BRASS_HI, 1.6)
    p.line([(x0 + 2, iy1 + 14), (x1 - 2, iy1 + 14)], STORM_HI, 2)
    p.line([(ix0 - 6, iy0), (ix0 - 6, iy1)], STORM_HI, 1.6)
    p.line([(ix1 + 6, iy0), (ix1 + 6, iy1)], STORM_DK, 1.6)
    for x in range(x0 + 12, x1 - 6, 30):
        rivet(p, x, y0 + 20, 2.8)
        rivet(p, x, y1 - 12, 2.8)
    for y in range(iy0 + 14, iy1, 30):
        rivet(p, x0 + 10, y, 2.8)
        rivet(p, x1 - 10, y, 2.8)


TANK_LEGS = (402, 512, 672, 782)


def tank(p):
    x0, y0, x1, y1 = TANK
    ix0, iy0, ix1, iy1 = TANK_IN
    sh = p.layer()
    sh.rect(x0 + 10, y0 + 10, x1 + 12, y1 + 8, SHADOW, None)
    p.put_soft(sh, 8, 0.3)
    for i, lx in enumerate(TANK_LEGS):
        back = i in (1, 2)
        col = STORM_DK if back else STORM
        p.rect(lx - 9, y1 - 4, lx + 9, 892, col, INK, 2.4)
        p.rect(lx - 14, 888, lx + 14, 898, col, INK, 2.2, r=2)
        if not back:
            p.line([(lx - 4, y1), (lx - 4, 886)], STORM_HI, 1.6)
    p.rect(x0 + 6, 868, x1 - 6, 878, STORM_DK, INK, 2)          # stretcher
    # interior: a flat pale glass field; the view draws the water over it
    p.rect(ix0, iy0, ix1, iy1, GLASS, None)
    tank_frame(p)
    # the hydrometer float on its wire from the rim
    p.line([(700, iy0 - 4), (700, 520)], INK, 1.6)
    p.ell(700, 404, 5, 5, BRASS_HI, INK, 1.6)
    p.line([(700, 409), (700, iy0)], INK, 1.6)
    p.rect(697, 520, 703, 534, GLASS_HI, INK, 1.6)
    p.ell(700, 552, 10, 20, GLASS_HI, INK, 2)
    p.ell(700, 566, 6, 6, BRASS, INK, 1.4)
    p.line([(696, 540), (696, 556)], PAPER_HI, 1.6)


def wall_lamp(p, cx, cy, lit=True):
    # bracket from the wall
    p.rect(cx - 9, cy - 88, cx + 9, cy - 62, BRASS_LO, INK, 2.2, r=3)
    arm = bezier((cx, cy - 70), (cx + 34, cy - 70), (cx, cy - 22), 14)
    p.line(arm, INK, 7)
    p.line(arm, BRASS, 3.5)
    p.ell(cx, cy - 22, 6, 6, BRASS_HI, INK, 1.8)
    # green glass shade, flat
    p.poly([(cx - 14, cy - 18), (cx + 14, cy - 18), (cx + 44, cy + 14), (cx - 44, cy + 14)], SEAGLASS, INK, 3)
    p.line([(cx - 8, cy - 13), (cx - 34, cy + 9)], SEAGLASS_HI, 2.4)
    p.rect(cx - 46, cy + 12, cx + 46, cy + 18, BRASS_LO, INK, 2)
    if lit:
        p.ell(cx, cy + 21, 9, 5, AMBER, INK, 1.6)
        p.ell(cx - 2, cy + 20, 3, 2, PAPER_HI, None)
    else:
        p.ell(cx, cy + 21, 9, 5, PAPER, INK, 1.6)


SOCKET_C = (874, 470)


def conduit(p):
    pts = [(874, 612), (874, 870), (214, 870), (214, 846)]
    p.line(pts, INK, 11)
    p.line(pts, STORM_HI, 6)
    p.line([(871, 616), (871, 866)], mix(STORM_HI, PAPER, 0.3), 1.4)
    for x in range(820, 240, -118):
        p.rect(x - 4, 862, x + 4, 878, BRASS_LO, INK, 1.6)
    p.rect(200, 830, 228, 852, STORM_DK, INK, 2.2, r=2)       # junction box on the stair jamb


def socket(p):
    x0, y0, x1, y1 = 808, 318, 932, 618
    sh = p.layer()
    sh.rect(x0 + 6, y0 + 8, x1 + 6, y1 + 6, SHADOW, None)
    p.put_soft(sh, 5, 0.3)
    p.rect(x0, y0, x1, y1, BRASS, INK, 3, r=10)
    p.line([(x0 + 6, y0 + 8), (x0 + 6, y1 - 10)], BRASS_HI, 2)
    p.rect(x0 + 8, 394, x1 - 8, y1 - 10, STORM, INK, 2.2, r=6)
    cx, cy = SOCKET_C
    p.ell(cx, cy, 60, 60, BRASS_LO, INK, 2.6)
    p.arc(cx, cy, 57, 57, 200, 330, BRASS_HI, 2.2)
    p.ell(cx, cy, 52, 52, SLOT, INK, 2.6)
    p.ell(cx, cy, 40, 40, None, mix(SLOT, STORM_HI, 0.5), 1.6)
    for a in (45, 135, 225, 315):
        screw(p, cx + 56 * math.cos(math.radians(a)), cy + 56 * math.sin(math.radians(a)), 2.6)
    # tag slot
    p.rect(838, 522, 910, 542, BRASS_LO, INK, 2.2, r=3)
    p.rect(846, 529, 902, 535, SOOT, None)
    for y in (566, 590):
        p.line([(824, y), (924, y)], STORM_HI, 2)
    card(p, 816, 326, 924, 386, PAPER_HI, ruled=0)


RACK_CUPS = ((1000, 668), (1120, 668), (1240, 668))
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
    # the TIP mechanism for show: a wall rail with a drive box and a crank
    p.rect(946, 552, 1288, 572, BRASS_LO, INK, 2.6, r=4)
    p.line([(950, 557), (1284, 557)], BRASS_HI, 1.6)
    for x in range(964, 1240, 46):
        screw(p, x, 566, 2.4)
    p.rect(1242, 534, 1286, 590, STORM, INK, 2.4, r=4)
    p.ell(1264, 562, 12, 12, BRASS_LO, INK, 2)
    p.line([(1264, 562), (1278, 540)], INK, 6)
    p.line([(1264, 562), (1278, 540)], BRASS, 3)
    p.ell(1279, 538, 4.5, 4.5, BRASS_HI, INK, 1.6)
    s = 0.55
    for cx, cy in RACK_CUPS:
        p.rect(cx - 5, cy, cx + 5, 756, STORM, INK, 2)      # pivot post to the shelf
    # shelf
    p.rect(938, 754, 1290, 768, TIMBER_HI, INK, 2.8)
    p.line([(940, 758), (1288, 758)], mix(TIMBER_HI, PAPER, 0.4), 1.6)
    p.rect(944, 768, 1284, 800, TIMBER, INK, 2.6)
    for bx in (968, 1260):
        p.poly([(bx - 8, 800), (bx + 8, 800), (bx + 8, 838), (bx - 8, 814)], STORM, INK, 2.2)
    for cx, cy in RACK_CUPS:
        cradle(p, cx, cy, CANT, s)
        plate(p, cx - 28, 772, cx + 28, 794)


def vault_door(p):
    p.rect(1294, 316, W + 6, 900, STEEL_DK, INK, 3)
    p.rect(1306, 330, 1434, 900, STEEL, INK, 3)
    p.line([(1312, 336), (1312, 894)], STEEL_HI, 2)
    for y in (470, 780):
        p.rect(1306, y - 10, 1434, y + 10, STEEL_DK, INK, 2.2)
        for x in range(1318, 1430, 24):
            rivet(p, x, y, 2.6, STEEL_HI)
    for y in range(346, 896, 28):
        rivet(p, 1424, y, 2.6, STEEL_HI)
    for y in (420, 820):
        p.rect(1294, y - 30, 1312, y + 30, STEEL_DK, INK, 2.2, r=4)
        p.line([(1300, y - 24), (1300, y + 24)], STEEL_HI, 1.6)
    plate(p, 1320, 360, 1420, 390)
    # the wheel latch
    cx, cy = 1370, 624
    p.ell(cx, cy, 46, 46, STEEL_DK, INK, 2.4)
    for k in range(6):
        a = math.radians(k * 60 + 15)
        p.line([(cx, cy), (cx + 40 * math.cos(a), cy + 40 * math.sin(a))], INK, 7)
        p.line([(cx, cy), (cx + 40 * math.cos(a), cy + 40 * math.sin(a))], BRASS, 3.5)
    p.ell(cx, cy, 40, 40, None, INK, 7)
    p.ell(cx, cy, 40, 40, None, BRASS, 3.5)
    p.arc(cx, cy, 40, 40, 200, 290, BRASS_HI, 2)
    p.ell(cx, cy, 11, 11, BRASS_HI, INK, 2.2)


def turn_plate(p, x0=600, y0=850, x1=848, y1=914):
    sh = p.layer()
    sh.rect(x0 + 4, y0 + 6, x1 + 4, y1 + 4, SHADOW, None)
    p.put_soft(sh, 4, 0.35)
    p.rect(x0 + 4, y0 + 4, x1 - 4, y1 - 4, BRASS, INK, 3, r=8)
    p.rect(x0 + 12, y0 + 11, x1 - 12, y1 - 11, None, BRASS_LO, 2, r=5)
    for x, y in ((x0 + 18, y0 + 18), (x1 - 18, y0 + 18), (x0 + 18, y1 - 18), (x1 - 18, y1 - 18)):
        screw(p, x, y, 3.4)
    # a U-turn arrow worn bright into the brass
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    pts = [(cx + 46, cy + 10), (cx + 46, cy - 4)] + \
        [(cx + 26 * math.cos(math.radians(a)), cy - 4 + 14 * math.sin(math.radians(a)) - 0) for a in range(0, -181, -15)] + \
        [(cx - 26, cy + 8)]
    pts = [(cx + 26, cy + 12)] + [(cx + 26 * math.cos(math.radians(a)), cy - 2 + 14 * math.sin(math.radians(a)))
                                  for a in range(0, -181, -15)] + [(cx - 26, cy + 8)]
    p.line(pts, BRASS_LO, 8)
    p.line(pts, BRASS_HI, 4)
    p.poly([(cx - 40, cy + 4), (cx - 12, cy + 4), (cx - 26, cy + 20)], BRASS_HI, BRASS_LO, 2.4)


def tank_salt(p, rng):
    lay = p.layer()
    for lx in TANK_LEGS:
        y = 866 + rng.uniform(-6, 4)
        lay.line([(lx - 9, y), (lx - 3, y - 3), (lx + 3, y + 1), (lx + 9, y - 2)], SALT, 3)
        for _ in range(14):
            lay.ell(lx + rng.uniform(-9, 9), y + rng.uniform(0, 24), rng.uniform(1, 2.2), None, SALT, None)
    p.put(lay, 0.9)


def vault_salt(p, rng, op=0.9):
    """A crust of salt round the vault door frame: blistered strips along the jambs and head."""
    lay = p.layer()

    def crust(pts, wd):
        lay.line(pts, SALT, wd)
        for x, y in pts:
            for _ in range(3):
                lay.ell(x + rng.uniform(-wd, wd), y + rng.uniform(-wd, wd), rng.uniform(1.6, 4), None, SALT, None)

    crust([(1294 + rng.uniform(-3, 4), y) for y in range(318, 902, 14)], 6)
    crust([(1302 + rng.uniform(-2, 2), y) for y in range(560, 902, 14)], 4)
    crust([(x, 318 + rng.uniform(-3, 3)) for x in range(1290, W + 6, 14)], 6)
    crust([(1440 + rng.uniform(-2, 3), y) for y in range(330, 902, 14)], 5)
    p.put(lay, op)
    ink = p.layer()
    ink.line([(1288 + rng.uniform(-1, 1), y) for y in range(330, 900, 20)], mix(TIMBER, INK, 0.2), 1.4)
    p.put(ink, op * 0.5)


def floor_rings(p, rng):
    cx, cy = 724, 1030
    wash = p.layer(VIOLET)
    wash.ell(cx, cy, 300, 50, VIOLET, None)
    p.put_soft(wash, 18, 0.22)
    lay = p.layer()
    for k, (rx, ry) in enumerate(((60, 10), (130, 22), (200, 34), (270, 46))):
        lay.ell(cx, cy, rx, ry, None, mix(VIOLET, PAPER, 0.4), 6 - k * 0.6)
        lay.ell(cx, cy + 3, rx, ry, None, VIOLET, 2.2)
    p.put(lay, 0.9)


def paint_view_a(rng, stage):
    p = Pen(W, H, rng, PAPER)
    srng = rng_for(700 + (0 if stage == "sever" else stage))
    shell(p, stage)
    damp(p, srng, stage)
    if stage != "sever":
        r = {2: (190, 120), 3: (180, 112), 5: (130, 82), 7: (124, 78)}[stage]
        lamp_pool(p, 592, 378, r[0], r[1], 0.42)
    else:
        lamp_pool(p, 724, 300, 700, 280, 0.18)       # flat grey daylight
    datum(p, DATUM_Y0, DATUM_Y1)
    plate(p, 964, 270, 1060, 296)
    plumb_bracket(p, 1090, 300)
    conduit(p)
    return_door(p)
    bolt_closed(p)
    basin(p)
    tank(p)
    wall_lamp(p, 592, 360, stage != "sever")
    socket(p)
    rack(p)
    vault_door(p)
    if stage in (3, 5, 7):
        tank_salt(p, srng)
    if stage in (5, 7):
        vault_salt(p, srng)
    if stage == "sever":
        tank_salt(p, srng)
        vault_salt(p, srng, 0.45)
    if stage == 7:
        floor_rings(p, srng)
    turn_plate(p)
    return grade(p.done(), stage)


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


def bench(p):
    sh = p.layer()
    sh.rect(26, 600, 1430, 640, SHADOW, None)
    p.put_soft(sh, 10, 0.25)
    p.rect(24, 620, 1424, 884, TIMBER, INK, 3)
    for x in (400, 700, 1000, 1180):
        p.line([(x, 624), (x, 878)], TIMBER_DK, 2.6)
        p.line([(x + 3, 624), (x + 3, 878)], TIMBER_HI, 1.2)
    for x0, x1 in ((420, 680), (720, 980), (1200, 1404)):
        p.rect(x0, 646, x1, 856, mix(TIMBER, TIMBER_DK, 0.3), INK, 2.2, r=3)
        p.line([(x0 + 4, 650), (x1 - 4, 650)], TIMBER_HI, 1.4)
    for x in (550, 850, 1302):
        p.rect(x - 16, 738, x + 16, 748, BRASS, INK, 1.8, r=3)
    p.rect(36, 884, 1412, 900, STORM_DK, INK, 2.4)
    p.rect(14, 598, 1434, 624, TIMBER_HI, INK, 3, r=3)
    p.line([(18, 602), (1430, 602)], mix(TIMBER_HI, PAPER, 0.45), 1.8)


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


def frame_tray(p, open_=False):
    x0, y0, x1, y1 = 748, 530, 952, 598
    sh = p.layer()
    sh.rect(x0 + 4, y0 + 4, x1 + 6, y1 + 3, SHADOW, None)
    p.put_soft(sh, 4, 0.3)
    p.rect(x0, y0, x1, y1, mix(GLASS, SEAGLASS_HI, 0.4), INK, 2.6, r=3)
    for k in range(3):
        rx = x0 + 10 + k * 66
        p.rect(rx, y0 + 14, rx + 52, y1 - 10, FELT, mix(INK, FELT, 0.4), 1.6, r=2)
    p.line([(x0 + 6, y0 + 8), (x0 + 6, y1 - 6)], GLASS_HI, 2)
    if not open_:
        p.rect(x0 - 4, y0 - 10, x1 + 4, y0 + 2, GLASS, INK, 2.4, r=2)
        p.line([(x0 + 10, y0 - 6), (x1 - 40, y0 - 6)], GLASS_HI, 2)
        p.rect(x1 - 30, y0 - 14, x1 - 14, y0 - 8, BRASS, INK, 1.6, r=2)
    else:
        p.rect(x0 - 2, y0 - 4, x1 + 2, y0 + 4, BRASS_LO, INK, 2, r=2)
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


JAR_B = (1010, 400, 1160, 600)


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
        p.rect(t - 9, TUBE_Y[0], t + 9, TUBE_Y[1], GLASS, INK, 2.2, r=8)
        p.line([(t - 4, TUBE_Y[0] + 20), (t - 4, TUBE_Y[1] - 14)], GLASS_HI, 1.6)
        p.rect(t - 8, TUBE_Y[0] - 16, t + 8, TUBE_Y[0] + 4, TIMBER_HI, INK, 2, r=3)   # cork stopper
    p.rect(x0, 448, x1, 466, OAK, INK, 2.6, r=2)        # the holding bar the tubes pass through
    p.line([(x0 + 4, 452), (x1 - 4, 452)], OAK_HI, 1.6)
    for t in TUBES:
        p.rect(t - 10, 450, t + 10, 464, SLOT, None)
        p.rect(t - 9, 448, t + 9, 466, GLASS, INK, 1.8)
        p.line([(t - 4, 450), (t - 4, 464)], GLASS_HI, 1.4)


def paint_view_b(rng, stage):
    p = Pen(W, H, rng, PAPER)
    srng = rng_for(720 + (0 if stage == "sever" else stage))
    shell(p, stage)
    damp(p, srng, stage)
    if stage != "sever":
        r = {2: (210, 150), 3: (200, 140), 5: (150, 100), 7: (140, 94)}[stage]
        lamp_pool(p, 490, 210, r[0], r[1], 0.42)
    else:
        lamp_pool(p, 724, 300, 700, 280, 0.18)
    pendant(p, 490, 120, stage != "sever")
    sample_cards(p)
    bench(p)
    register(p)
    easel(p)
    spec_frame(p)
    frame_tray(p)
    balance(p)
    bell_jar(p)
    tube_rack(p)
    if stage in (5, 7, "sever"):
        # salt crust along the bench top edge
        lay = p.layer()
        for _ in range(500):
            lay.ell(srng.uniform(20, 1430), srng.gauss(626, 3), srng.uniform(1, 2.6), None, SALT, None)
        p.put(lay, 0.45 if stage == "sever" else 0.85)
    if stage == 7:
        floor_rings(p, srng)
    turn_plate(p)
    return grade(p.done(), stage)


# ----------------------------------------------------------------------------- view A overlays

def paint_a_tank_glass(rng):
    p = Pen(W, H, rng)
    ix0, iy0, ix1, iy1 = TANK_IN
    hi = p.layer()
    hi.rect(436, iy0 + 8, 452, iy1 - 10, GLASS_HI, None)
    hi.rect(466, iy0 + 30, 472, iy1 - 60, GLASS_HI, None)
    hi.rect(ix1 - 30, iy0 + 60, ix1 - 24, iy0 + 220, GLASS_HI, None)
    p.put(hi, 0.42)
    ink = p.layer()
    ink.line([(436, iy0 + 8), (436, iy1 - 10)], INK, 1.6)
    ink.line([(472, iy0 + 30), (472, iy1 - 60)], INK, 1.4)
    p.put(ink, 0.55)
    tank_frame(p)
    return p


REFL = (420, 448, 764, 598)


def paint_a_reflect(rng, jars):
    """The rack seen mirrored in the upper tank glass: silhouettes only, solid; the view fades them."""
    p = Pen(W, H, rng)
    lay = p.layer()
    x0, y0, x1, y1 = REFL
    s = 0.36
    lay.rect(x0 - 4, y0 + 6, x1 + 4, y0 + 16, STORM, None)            # the TIP rail
    lay.rect(x0 - 4, y1 - 14, x1 + 4, y1 + 4, STORM, None)            # the shelf
    for k, (cx, cy) in enumerate(RACK_CUPS):
        mx = x1 - (cx - 936) * (x1 - x0) / 364.0
        my = y0 + 76
        lay.line([(mx, y0 + 14), rot((mx, my - 92 * s), (mx, my), -CANT)], STORM, 3)
        cradle(lay, mx, my, -CANT, s, empty_hub=False)
        if k < jars:
            body = [(-44, -66), (44, -66), (44, 66), (-44, 66)]
            pts = [rot((mx + x * 0.62, my + y * 0.62), (mx, my), -CANT) for x, y in body]
            lay.poly(pts, STORM, None)
            lid = [(-40, -74), (40, -74), (40, -62), (-40, -62)]
            lay.poly([rot((mx + x * 0.62, my + y * 0.62), (mx, my), -CANT) for x, y in lid], STORM_DK, None)
            hl = [rot((mx + x * 0.62, my + y * 0.62), (mx, my), -CANT) for x, y in ((-30, -50), (-30, 50))]
            lay.line(hl, SEAGLASS_HI, 2.4)
    p.put(lay, 0.85, rect_mask([REFL], feather=2))
    return p


def paint_a_vault_ajar(rng):
    p = Pen(W, H, rng)
    p.rect(1412, 332, 1430, 899, mix(STORM, SOOT, 0.55), INK, 2.4)
    lay = p.layer()
    lay.rect(1416, 336, 1426, 896, SOOT, None)
    p.put_soft(lay, 3, 0.8)
    p.rect(1402, 330, 1412, 900, STEEL_HI, INK, 2.4)                 # the leaf's edge, swung out
    p.line([(1407, 336), (1407, 894)], mix(STEEL_HI, PAPER_HI, 0.4), 1.4)
    return p


def paint_a_return_unbolted(rng):
    p = Pen(W, H, rng)
    bolt_housing(p, False)
    glow = p.layer(SEAGLASS_HI)
    glow.rect(26, 336, 34, 896, SEAGLASS_HI, None)
    p.put_soft(glow, 4, 0.55)
    p.line([(29.5, 336), (29.5, 896)], PAPER_HI, 1.8)
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


def paint_a_socket_tag(rng):
    p = Pen(W, H, rng)
    sh = p.layer()
    sh.rect(826, 556, 936, 614, SHADOW, None)
    p.put_soft(sh, 4, 0.3)
    hx, hy = 840, 578
    p.line([(874, 534), (858, 556), (hx, hy)], INK, 1.8)
    tag_shape(p, 820, 548, 930, 608)
    return p


def paint_a_rack_salt(rng):
    p = Pen(W, H, rng)
    cx, cy = RACK_CUPS[2]
    s = 0.55
    ghost = p.layer(SALT)
    body = [(-44, -66), (44, -66), (44, 72), (-44, 72)]
    pts = [rot((cx + x, cy + y), (cx, cy), CANT) for x, y in body]
    ghost.poly(pts, None, SALT, 3)
    p.put_soft(ghost, 0.8, 0.55)
    lay = p.layer()
    a, b = rot((cx - 86 * s, cy + 118 * s), (cx, cy), CANT), rot((cx + 86 * s, cy + 118 * s), (cx, cy), CANT)
    lay.line([a, b], SALT, 5)
    for _ in range(90):
        t = rng.random()
        x, y = lerp(a[0], b[0], t), lerp(a[1], b[1], t)
        lay.ell(x + rng.uniform(-2, 2), y + rng.uniform(-6, 2), rng.uniform(1, 2.6), None, SALT, None)
    for _ in range(40):
        t = rng.random()
        q = pts[int(t * 4) % 4]
        r = pts[(int(t * 4) + 1) % 4]
        f = (t * 4) % 1
        lay.ell(lerp(q[0], r[0], f) + rng.uniform(-3, 3), lerp(q[1], r[1], f) + rng.uniform(-3, 3),
                rng.uniform(1, 2.2), None, SALT, None)
    p.put(lay)
    ink = p.layer()
    ink.line([a, b], INK, 1.2)
    p.put(ink, 0.35)
    return p


# ----------------------------------------------------------------------------- view B overlays

def tube_mask():
    m = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(m)
    for t in TUBES:
        d.rounded_rectangle(((t - 7) * SS, (TUBE_Y[0] + 6) * SS, (t + 7) * SS, (TUBE_Y[1] - 3) * SS),
                            radius=7 * SS, fill=255)
        d.rectangle(((t - 10) * SS, 447 * SS, (t + 10) * SS, 467 * SS), fill=0)
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
    """The fragments aligned: one curved, ribbed column of pale rings, seen through all eight
    tubes as segments of a single throat-like body (a stark graphic, never gore)."""
    p = Pen(W, H, rng)
    lay = p.layer()
    path = bezier((1200, 404), (1300, 636), (1408, 404), 48)
    def off(d):
        out = []
        for i, (x, y) in enumerate(path):
            ax, ay = path[max(0, i - 1)]
            bx, by = path[min(len(path) - 1, i + 1)]
            tx, ty = bx - ax, by - ay
            m = math.hypot(tx, ty) or 1.0
            out.append((x - ty / m * d, y + tx / m * d))
        return out
    left, right = off(-22), off(22)
    lay.poly(left + right[::-1], PAPER_HI, None)
    lay.line(off(-12), PAPER, 6)                     # a shade along the lower flank
    lay.line(left, INK, 2.6)
    lay.line(right, INK, 2.6)
    for i in range(1, len(path) - 1, 2):             # the ring grooves, nested like cartilage
        lay.line([left[i], right[i]], mix(PAPER, TIMBER, 0.45), 3.4)
        lay.line([(left[i][0] + 1.5, left[i][1] + 1.5), (right[i][0] + 1.5, right[i][1] + 1.5)], SALT, 1.4)
    p.put(lay, 1.0, tube_mask())
    return p


def paint_b_thumb(rng):
    p = Pen(W, H, rng)
    cx, cy = 610, 522
    lay = p.layer(FELT_DK)
    lay.ell(cx, cy, 17, 11, FELT_DK, None)
    p.put_soft(lay, 1.5, 1.0)
    rim = p.layer()
    rim.arc(cx, cy, 17, 11, 190, 350, mix(FELT, PAPER_HI, 0.5), 1.6)
    for k in range(3):
        rim.arc(cx + 1, cy + 1, 12 - k * 4, 7 - k * 2.4, 200, 520 - k * 30, mix(FELT_DK, INK, 0.3), 1.1)
    p.put(rim, 0.8)
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


def view_b_wall(rng):
    p = Pen(W, H, rng, PAPER)
    shell(p, 2)
    lamp_pool(p, 490, 210, 210, 150, 0.42)
    return p


def paint_b_stand_empty(rng):
    wall = view_b_wall(rng)
    easel(wall)
    p = Pen(W, H, rng)
    x0, y0, x1, y1 = FRAME_B
    p.put(wall, 1.0, rect_mask([(x0 - 5, y0 - 5, x1 + 5, y1 + 1)]))
    # the tiles the frame shielded stay clean: a crisp ghost of it, edged by a thin tide rim
    rim = p.layer(TIMBER)
    rim.rect(x0 - 4, y0 - 4, x1 + 4, y1 + 1, None, mix(TIMBER, INK, 0.2), 2.2, r=3)
    p.put(rim, 0.45)
    salt = p.layer()
    for _ in range(70):
        t = rng.random()
        side = rng.randrange(3)
        if side == 0:
            x, y = lerp(x0 - 4, x1 + 4, t), y0 - 6 + rng.uniform(-2, 2)
        else:
            x, y = (x0 - 6 if side == 1 else x1 + 6) + rng.uniform(-2, 2), lerp(y0, y1, t)
        salt.ell(x, y, rng.uniform(1, 2.2), None, SALT, None)
    p.put(salt, 0.8)
    return p


def paint_b_register_open(rng):
    p = Pen(W, H, rng)
    register(p, open_=True)
    return p


def paint_b_lid_open(rng):
    wall = view_b_wall(rng)
    easel(wall)
    p = Pen(W, H, rng)
    p.put(wall, 1.0, rect_mask([(742, 512, 958, 528)]))
    frame_tray(p, open_=True)
    return p


def jar_body_pts(inset=0):
    x0, y0, x1, y1 = JAR_B
    cx = (x0 + x1) / 2
    a, b = x0 + 8 + inset, x1 - 8 - inset
    top = 418 + inset
    return [(a, 584 - inset), (a, 452)] + bezier((a, 452), (a + 2, top), (cx - 16, top), 10)[1:] + \
        [(cx + 16, top)] + bezier((cx + 16, top), (b - 2, top), (b, 452), 10)[1:] + [(b, 584 - inset)]


def paint_b_fog(rng):
    p = Pen(W, H, rng)
    body = jar_body_pts(6)
    fog = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(fog)
    d.polygon([(x * SS, y * SS) for x, y in body], fill=235)
    d.rectangle((1030 * SS, 480 * SS, 1140 * SS, 530 * SS), fill=70)
    fog = fog.filter(ImageFilter.GaussianBlur(4 * SS))
    fog = ImageChops.multiply(fog, poly_mask(body))
    mott = value_noise(rng, W * SS, H * SS, 22 * SS).point(lambda v: 150 + v * 105 // 255)
    fog = ImageChops.multiply(fog, mott)
    col = Image.new("RGBA", (W * SS, H * SS), rgba(SALT))
    col.putalpha(fog)
    p.im.alpha_composite(col)
    # the etched band: a faint frosted border, cleaner inside
    etch = p.layer()
    etch.rect(1030, 480, 1140, 530, None, GLASS_HI, 1.6, r=4)
    p.put(etch, 0.7)
    beads = p.layer()
    for _ in range(26):
        x, y = rng.uniform(1024, 1146), rng.uniform(440, 574)
        if 1028 < x < 1142 and 476 < y < 534:
            continue
        beads.ell(x, y, rng.uniform(1.4, 2.8), None, GLASS_HI, None)
    p.put(beads, 0.8)
    return p


# ----------------------------------------------------------------------------- close-up parts

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
        x0 = 90 + k * 88
        card(p, x0, 110, x0 + 74, 270, PAPER_HI, ruled=16)
        stamp_box(p, x0 + 16, 130, x0 + 58, 170)
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


def paint_c_damp(rng):
    """Salt and damp creeping in from the close-up's edges: patchy wet bloom, ragged brown tide
    rims and a salt crust along them; the centre stays fully clear."""
    p = Pen(W, H, rng)
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    d.rectangle((0, 0, W, H), fill=255)
    d.rounded_rectangle((90, 80, W - 90, H - 80), radius=140, fill=0)
    m = m.filter(ImageFilter.GaussianBlur(46))
    n = value_noise(rng, W, H, 52)
    m = ImageChops.multiply(m, n.point(lambda v: min(255, 60 + v)))
    m = m.point(lambda v: min(190, v * 3 // 2))
    m = m.resize((W * SS, H * SS), Image.BILINEAR)
    col = Image.new("RGBA", (W * SS, H * SS), rgba(DAMP))
    col.putalpha(m.point(lambda v: v * 7 // 10))
    p.im.alpha_composite(col)
    rim_col = mix(TIMBER, INK, 0.2)
    rims = p.layer(rim_col)
    salt = p.layer()
    loops = []
    for inset in (36,):
        top = ragged(rng, -40, W + 40, inset, 18, step=44)
        bot = ragged(rng, -40, W + 40, H - inset, 18, step=44)
        lft = [(y, x) for x, y in ragged(rng, -40, H + 40, inset, 18, step=44)]
        rgt = [(W - y, x) for x, y in ragged(rng, -40, H + 40, inset, 18, step=44)]
        loops += [top, bot, lft, rgt]
    for ln in loops:
        rims.line(ln, rim_col, 3.4)
        rims.line([(x * 0.985 + W * 0.0075, y * 0.98 + H * 0.01) for x, y in ln], rim_col, 1.6)
        for i in range(len(ln) - 1):
            (ax, ay), (bx, by) = ln[i], ln[i + 1]
            for _ in range(3):
                t = rng.random()
                salt.ell(lerp(ax, bx, t) + rng.uniform(-2, 2), lerp(ay, by, t) + rng.uniform(-2, 2),
                         rng.uniform(1.4, 2.6), None, SALT, None)
    p.put_soft(rims, 0.8, 0.6)
    p.put(salt, 0.85)
    keep = Image.new("L", (W * SS, H * SS), 255)
    ImageDraw.Draw(keep).rounded_rectangle((250 * SS, 220 * SS, (W - 250) * SS, (H - 220) * SS), radius=120 * SS, fill=0)
    keep = keep.filter(ImageFilter.GaussianBlur(26 * SS))
    p.im.putalpha(ImageChops.multiply(p.im.getchannel("A"), keep))
    return p

# ----------------------------------------------------------------------------- sprites

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
    p = Pen(90, 50, rng)
    lay = p.layer(FELT_DK)
    lay.ell(45, 25, 34, 19, FELT_DK, None)
    p.put_soft(lay, 3, 0.95)
    rim = p.layer()
    rim.arc(45, 25, 34, 19, 190, 350, mix(FELT, PAPER_HI, 0.5), 2)
    for k in range(4):
        rim.arc(47, 27, 26 - k * 6, 13 - k * 3.2, 200, 520 - k * 30, mix(FELT_DK, INK, 0.3), 1.4)
    p.put(rim, 0.8)
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


# ----------------------------------------------------------------------------- the list

ASSETS = [  # name, seed index, painter, opaque, grain
    ("view_a", 0, lambda r: paint_view_a(r, 2), True, True),
    ("view_a_s3", 0, lambda r: paint_view_a(r, 3), True, True),
    ("view_a_s5", 0, lambda r: paint_view_a(r, 5), True, True),
    ("view_a_s7", 0, lambda r: paint_view_a(r, 7), True, True),
    ("view_a_sever", 0, lambda r: paint_view_a(r, "sever"), True, True),
    ("view_b", 10, lambda r: paint_view_b(r, 2), True, True),
    ("view_b_s3", 10, lambda r: paint_view_b(r, 3), True, True),
    ("view_b_s5", 10, lambda r: paint_view_b(r, 5), True, True),
    ("view_b_s7", 10, lambda r: paint_view_b(r, 7), True, True),
    ("view_b_sever", 10, lambda r: paint_view_b(r, "sever"), True, True),
    ("a_tank_glass", 20, paint_a_tank_glass, False, False),
    ("a_reflect_three", 21, lambda r: paint_a_reflect(r, 3), False, False),
    ("a_reflect_two", 21, lambda r: paint_a_reflect(r, 2), False, False),
    ("a_vault_ajar", 22, paint_a_vault_ajar, False, False),
    ("a_return_unbolted", 23, paint_a_return_unbolted, False, False),
    ("a_socket_tag", 24, paint_a_socket_tag, False, False),
    ("a_rack_salt", 25, paint_a_rack_salt, False, False),
    ("b_shells_loose", 30, paint_b_shells_loose, False, False),
    ("b_shells_rings", 31, paint_b_shells_rings, False, False),
    ("b_thumb", 32, paint_b_thumb, False, False),
    ("b_strip", 33, paint_b_strip, False, False),
    ("b_stand_empty", 34, paint_b_stand_empty, False, 10),
    ("b_register_open", 35, paint_b_register_open, False, False),
    ("b_lid_open", 36, paint_b_lid_open, False, 10),
    ("b_fog", 37, paint_b_fog, False, False),
    ("c_tilt_rack", 40, paint_c_tilt_rack, True, True),
    ("c_balance", 41, paint_c_balance, True, True),
    ("c_frame", 42, paint_c_frame, True, True),
    ("c_damp", 43, paint_c_damp, False, False),
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


if __name__ == "__main__":
    main(sys.argv[1:])
