#!/usr/bin/env python3
"""R10 Records Vault painter (The Ninth Tide).

Writes, and only writes, assets/rooms/R10/*.png:

  view_a, view_a_s5, view_a_s7
                      the shelves wall (1448x1086 opaque): band 4 (the stripes ripple once, the sea
                      heard through the wall), bands 5-6 (sea-glass damp from the floor, the tide
                      line, stripes leaning toward the shelves), band 7 (a second tunnel mouth
                      breaks through the wall, index cards drift across the floor to it, and more
                      bays continue past the room's own corner)
  view_b, view_b_s5   the catalogue wall (1448x1086 opaque): band 4, and bands 5-7
  view_a_t6..t9, view_b_t6..t9
                      the tide plates the view draws (Tides VI-IX): the band features above for
                      that tide, the wallpaper one step darker toward storm navy per tide, and
                      view A's shelf bay deepening (6 nested frames at VI, 9 at VII, 14 from
                      VIII, the innermost then a lit doorway with the ninth photograph's chair)
  a_panels_loose, a_sheet_assembled, a_photos_turned, a_ninth_photo, a_mercer_card
                      view A overlays (full-plate RGBA, registered)
  b_staff_open, b_aperture_1, b_aperture_2, b_tabs_riffle, b_drawer_open, b_terminals,
  b_terminals_nobridge, b_string_loose, b_photo_unwrapped
                      view B overlays (full-plate RGBA, registered)
  c_contact, c_folders, c_model                   close-up plates (opaque)
  c_panel_{a,b,c,d}, c_blank_t{0,1,2}, c_cover, c_clamp, c_reflection, c_rec_frame, c_rec_strip,
  c_rec_card, c_leaf_closed, c_index_bar, c_lever_up, c_lever_down, c_key_down, c_shutter,
  c_bridge, c_plug, c_plug_parked, c_stamp_closed, c_stamp_open, c_mkey_down, c_rkey_down
                      close-up sprites (RGBA, exact sizes)

A dry paper archive in the office's shell: pale sea-glass striped paper over a storm-teal
wainscot, brown kept for the oak furniture, brass label plates, one small amber pendant per view. Light never drops; depth beyond the plan comes from
repetition and occlusion only. View A's shelves are a run of shelf-end flats, each later bay smaller
and set behind the nearer one's edge in storm navy, ending in a flat dark navy recess where the view
draws a lit amber dot and the passing occluder.

Flat front elevation: every shelf, drawer and table edge is horizontal in plate space. Approved
palette, navy ink contours, matte colour, low seeded paper grain. No text, numerals or glyphs:
every label is a blank enamel or paper plate the view writes on; clock faces have ticks, no hands.
The retouched blanks are pale, brush-soft head-and-shoulders shapes with no features at all; a
turned one is a stark dark back-of-head silhouette.

and, as new stage art, assets/stages/R10/*.png (full-plate RGBA overlays, registered):

  staff_slot, staff_slot_1, staff_slot_2
                      the STAFF drawer's mouth, redrawn: a dark lens-shaped slot cut in the shut
                      drawer front, no lip contour, lined top and bottom with rows of buff index
                      cards on end, each with a tiny typed tab. Each widen step is a wider slot
                      and one more row of cards further back in the dark.
  staff_slot_riffle   the narrow slot with every card leaning the same way (the P18 riffle)
  staff_shut          the slot slammed shut: a seam in the front with card tabs pinched in it
  vault_grade         view A from band 6: the back shelving graded toward storm navy, frame by
                      frame, so the run reads deeper than the floor plan; the lit doorway kept

Python 3 + PIL only. Deterministic: each asset has its own random.Random(SEED + k), there is no
clock and no PIL noise effect, so a rerun is byte-identical.

    python3 tools/art/rooms/R10.py              # paint everything
    python3 tools/art/rooms/R10.py view_a* c_*  # paint some (fnmatch patterns)
"""
import fnmatch
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "rooms", "R10")
STAGE_OUT = os.path.join(ROOT, "assets", "stages", "R10")   # the later-stage art (owner, Nov 6)
W, H = 1448, 1086
SS = 2                      # supersampling for every painted shape
SEED = 1931_10_00

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
VIOLET = (116, 101, 119)    # #746577  shape accent only


def mix(c0, c1, t):
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(c0, c1))


# derived tones (all mixes of the approved palette)
ENAMEL = mix(PAPER_HI, PAPER, 0.25)
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
FELT = mix(SEAGLASS, STORM, 0.25)
FELT_HI = mix(FELT, SEAGLASS_HI, 0.3)
SHADOW = mix(STORM, SOOT, 0.5)
SLOT = mix(STORM, SOOT, 0.6)
STONE = mix(SOOT, PAPER, 0.42)
GLASS_LIT = mix(PAPER_HI, (255, 255, 255), 0.35)   # the lightbox glass, lit from inside
# The vault's shell is the office's: a pale sea-glass wall (the office wall hue, a tenth greyer)
# over a storm-teal wainscot and trim. Brown is kept for the furniture.
OFFICE_WALL = (166, 182, 165)
OFFICE_TEAL = (45, 85, 101)
WALLPAPER = mix(OFFICE_WALL, (175, 175, 175), 0.10)
WALL_STRIPE = mix(WALLPAPER, SEAGLASS, 0.30)
WALL_SIDE = mix(WALLPAPER, SEAGLASS, 0.42)
WAINSCOT = OFFICE_TEAL
WAINSCOT_PANEL = mix(OFFICE_TEAL, INK, 0.18)
WAINSCOT_HI = mix(OFFICE_TEAL, SEAGLASS_HI, 0.35)
TRIM = mix(OFFICE_TEAL, INK, 0.35)
TRIM_HI = mix(OFFICE_TEAL, SEAGLASS_HI, 0.45)
CEIL = mix(STORM, INK, 0.4)
FLOOR = mix(TIMBER, STONE, 0.25)
FLOOR_HI = mix(FLOOR, PAPER, 0.18)
FLOOR_DK = mix(FLOOR, SOOT, 0.3)
DAMP = mix(SEAGLASS, SEAGLASS_HI, 0.35)            # the sea-glass soak, band 5 on
SEPIA = mix(PAPER, TIMBER, 0.42)                   # photograph ground
SEPIA_HI = mix(PAPER, TIMBER, 0.24)
SEPIA_DK = mix(TIMBER, INK, 0.30)
BLANK = mix(PAPER_HI, (255, 255, 255), 0.22)       # the retouched blanks: lighter than paper
KRAFT = mix(mix(TIMBER, BRASS, 0.5), PAPER, 0.38)  # parcel paper
KRAFT_DK = mix(KRAFT, TIMBER, 0.45)
STRING = mix(PAPER_HI, PAPER, 0.4)
DUST = mix(PAPER, STONE, 0.35)
EBONITE = mix(SOOT, STORM, 0.55)




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


def sprite(w, h, fn):
    def run(rng):
        p = Pen(w, h, rng)
        fn(p)
        return p
    return run


def soft_shadow(p, x0, y0, x1, y1, dx=5, dy=7, blur=5, op=0.30, r=0):
    sh = p.layer()
    sh.rect(x0 + dx, y0 + dy, x1 + dx, y1 + dy, SHADOW, None, r=r)
    p.put_soft(sh, blur, op)


# ----------------------------------------------------------------------------- the room shell

FLOOR_Y = 900
CEIL_Y = 46
DADO_Y = 620                # the office's dado height
SKIRT_Y = 880
TIDE_Y = 512                # the office's tide line height (painter_1.TIDE_Y)
RIPPLE_Y = 300              # band 4: where the stripes ripple once, the sea heard through the wall


# Tide plates (view_*_t6..t9): the wallpaper darkens one step per tide from VI toward storm
# navy. 0.0 (every older stem) leaves the colours exactly as they were.
WALL_DARK_STEP = 0.12
_wall_dark = 0.0


def wall(c):
    return mix(c, STORM, _wall_dark) if _wall_dark else c


def stripe_dx(y, lean=0.0, ripple=0.0):
    """x offset of a wallpaper stripe at height y. `lean` tips the stripe's top toward the left
    (px per 100 px of height above the dado); `ripple` is one damped wave about RIPPLE_Y."""
    dx = -lean * (DADO_Y - y) / 100.0
    if ripple:
        t = (y - RIPPLE_Y) / 110.0
        if abs(t) < 1.0:
            dx += ripple * math.sin(t * math.pi) * (1.0 - t * t) ** 2
    return dx


def wall_stripes(p, x_from=8, lean=0.0, ripple=0.0, top=CEIL_Y + 22, bot=DADO_Y):
    lay = p.layer()
    x = x_from
    ys = list(range(int(top), int(bot) + 1, 6)) + [bot]
    while x < W + 80:
        left = [(x + stripe_dx(y, lean, ripple), y) for y in ys]
        right = [(x + 12 + stripe_dx(y, lean, ripple), y) for y in ys]
        lay.poly(left + right[::-1], wall(WALL_STRIPE), None)
        lay.line([(x + 22 + stripe_dx(y, lean, ripple), y) for y in ys], wall(WALL_STRIPE), 1.4)
        x += 64
    p.put(lay, 0.75)


def shell(p, rng, lean=0.0, ripple=0.0):
    """Ceiling band, teal cornice, striped sea-glass wall, teal dado rail and wainscot, skirting,
    boards: the office's shell, so the vault reads as the same station."""
    p.rect(-4, -4, W + 4, CEIL_Y, CEIL, None)
    p.line([(-4, 30), (W + 4, 30)], STORM, 2)
    p.rect(-4, CEIL_Y - 4, W + 4, CEIL_Y + 14, TRIM, INK, 3.4)
    p.line([(-4, CEIL_Y + 2), (W + 4, CEIL_Y + 2)], TRIM_HI, 1.6)
    p.rect(-4, CEIL_Y + 14, W + 4, CEIL_Y + 22, mix(TRIM, INK, 0.4), INK, 2)
    p.rect(-4, CEIL_Y + 22, W + 4, DADO_Y, wall(WALLPAPER), None)
    wall_stripes(p, lean=lean, ripple=ripple)
    # a gentle seeded mottle so the paper is not flat
    mot = p.layer(PAPER_HI)
    for _ in range(26):
        cx, cy = rng.uniform(0, W), rng.uniform(80, DADO_Y - 40)
        mot.ell(cx, cy, rng.uniform(60, 160), rng.uniform(30, 80), PAPER_HI, None)
    p.put_soft(mot, 30, 0.10)
    # dado rail and wainscot: tongue-and-groove boards, as in the office
    p.rect(-4, DADO_Y + 10, W + 4, SKIRT_Y, WAINSCOT, None)
    x = 0
    while x < W:
        p.line([(x, DADO_Y + 12), (x, SKIRT_Y - 2)], WAINSCOT_PANEL, 2.6)
        p.line([(x + 3, DADO_Y + 12), (x + 3, SKIRT_Y - 2)], WAINSCOT_HI, 1.0)
        x += 34
    p.rect(-4, DADO_Y - 6, W + 4, DADO_Y + 10, TRIM, INK, 3.4)
    p.line([(-4, DADO_Y - 1), (W + 4, DADO_Y - 1)], TRIM_HI, 1.6)
    p.rect(-4, SKIRT_Y, W + 4, FLOOR_Y, mix(TRIM, INK, 0.3), INK, 3.4)
    p.line([(-4, SKIRT_Y + 4), (W + 4, SKIRT_Y + 4)], TRIM, 1.5)
    # boards: level courses, staggered butt joints
    p.rect(-4, FLOOR_Y, W + 4, H + 4, FLOOR, INK, 3.4)
    y, k = FLOOR_Y, 0
    while y < H:
        hgt = 32 + k * 7
        p.line([(-4, y + 2.5), (W + 4, y + 2.5)], FLOOR_HI, 1.4)
        p.line([(-4, y + hgt), (W + 4, y + hgt)], FLOOR_DK, 2.5)
        x = rng.uniform(0, 300)
        while x < W:
            p.line([(x, y + 3), (x, y + hgt - 3)], FLOOR_DK, 2)
            x += rng.uniform(300, 520)
        y += hgt
        k += 1


def lamp_pool(p, cx, cy, rx, ry, op):
    lay = p.layer(PAPER_HI)
    lay.ell(cx, cy, rx, ry, PAPER_HI, None)
    p.put_soft(lay, max(rx, ry) * 0.35, op)


def pendant(p, cx, cy, lit=True):
    """One small brass pendant with an amber bulb: the only warm light in each view."""
    p.line([(cx, CEIL_Y + 22), (cx, cy - 18)], INK, 3)
    p.rect(cx - 6, cy - 22, cx + 6, cy - 12, BRASS_LO, INK, 1.8)
    p.poly([(cx - 12, cy - 13), (cx + 12, cy - 13), (cx + 40, cy + 12), (cx - 40, cy + 12)], BRASS, INK, 3)
    p.line([(cx - 8, cy - 9), (cx - 30, cy + 8)], BRASS_HI, 2.4)
    p.rect(cx - 42, cy + 11, cx + 42, cy + 16, BRASS_LO, INK, 2)
    p.ell(cx, cy + 20, 9, 5, AMBER if lit else PAPER, INK, 1.6)
    if lit:
        p.ell(cx - 2, cy + 19, 3, 2, PAPER_HI, None)


def turn_plate(p, x0=600, y0=850, x1=848, y1=914):
    sh = p.layer()
    sh.rect(x0 + 4, y0 + 6, x1 + 4, y1 + 4, SHADOW, None)
    p.put_soft(sh, 4, 0.35)
    p.rect(x0 + 4, y0 + 4, x1 - 4, y1 - 4, BRASS, INK, 3, r=8)
    p.rect(x0 + 12, y0 + 11, x1 - 12, y1 - 11, None, BRASS_LO, 2, r=5)
    for x, y in ((x0 + 18, y0 + 18), (x1 - 18, y0 + 18), (x0 + 18, y1 - 18), (x1 - 18, y1 - 18)):
        screw(p, x, y, 3.4)


def oak_plate(p, x0, y0, x1, y1):
    """A blank brass label plate with an ink rim and two screws (the view writes on it)."""
    p.rect(x0, y0, x1, y1, BRASS_HI, INK, 1.8, r=2)
    p.rect(x0 + 2.5, y0 + 2.5, x1 - 2.5, y1 - 2.5, None, BRASS_LO, 1.0, r=1)


# ----------------------------------------------------------------------------- photographs
#
# Every photograph in the room is the same shot: a plain wooden chair against a wall, and on the
# chair a retouched blank, a pale brush-soft head-and-shoulders shape with no features, slightly
# lighter than the paper. The pose of the blank is the only thing that ever changes.

def blank_shape(lay, x, y, s, pose, col=BLANK):
    """Head-and-shoulders blank in a 40x60 box at (x, y), scaled by s. pose: 'front', 'three' (three
    quarter to the left), 'profile' (profile facing left), 'away' (turned away toward the left)."""
    def P(u, v):
        return (x + u * s, y + v * s)

    def E(u, v, rx, ry):
        lay.ell(x + u * s, y + v * s, rx * s, ry * s, col, None)

    if pose == "front":
        E(20, 15, 9, 11.5)
        lay.poly([P(16, 22), P(24, 22), P(25, 31), P(15, 31)], col, None)
        lay.poly([P(2, 60), P(4, 40), P(9, 33), P(16, 30), P(24, 30), P(31, 33), P(36, 40), P(38, 60)], col, None)
    elif pose == "three":
        E(17.5, 15, 8.8, 11.5)
        E(9.6, 17, 2.6, 3.2)       # the nose bump, left
        lay.poly([P(14, 22), P(22, 22), P(23, 31), P(13, 31)], col, None)
        lay.poly([P(4, 60), P(5, 41), P(10, 33), P(16, 30), P(24, 30.5), P(31, 34), P(35, 42), P(36, 60)], col, None)
    elif pose == "profile":
        E(19, 15, 9.5, 11.5)
        E(9.8, 17.5, 3.0, 3.0)     # nose
        E(12.4, 25, 3.5, 2.6)      # chin
        lay.poly([P(16, 22), P(24, 21), P(25, 32), P(15, 32)], col, None)
        lay.poly([P(8, 60), P(9, 40), P(13, 33), P(19, 30), P(26, 31), P(30, 36), P(32, 44), P(32, 60)], col, None)
    else:  # away: back of the head, turned toward the left
        E(18.5, 15.5, 9.8, 12)
        E(27.6, 17, 2.4, 3.6)      # an ear on the right: we see the back of the head
        lay.poly([P(14, 22), P(23, 22), P(24, 31), P(13, 31)], col, None)
        lay.poly([P(3, 60), P(4, 41), P(9, 33.5), P(15, 31), P(25, 31), P(32, 34), P(36, 42), P(37, 60)], col, None)


def blank_marks(p, x, y, s, pose, op=0.55):
    """Faint retoucher's seams that make the turn legible: the nape and back seam when away."""
    lay = p.layer()
    if pose == "away":
        lay.line([(x + 12 * s, y + 31 * s), (x + 25 * s, y + 31 * s)], SEPIA, max(1.0, 1.4 * s))
        lay.line([(x + 19 * s, y + 35 * s), (x + 19 * s, y + 58 * s)], SEPIA_HI, max(1.0, 1.2 * s))
    elif pose == "front":
        lay.line([(x + 15 * s, y + 31 * s), (x + 20 * s, y + 38 * s), (x + 25 * s, y + 31 * s)], SEPIA_HI,
                 max(1.0, 1.2 * s))
    if pose in ("profile", "three", "away"):
        p.put(lay, op)
    else:
        p.put(lay, op * 0.6)


HAIR = mix(INK, SOOT, 0.35)          # the turned sitter: one stark dark mass
COAT = mix(INK, STORM, 0.35)


def back_of_head(p, x, y, s, hair=HAIR, coat=COAT, rim=None):
    """The turned sitter in a 40x60 box at (x, y), scaled by s: a solid dark back-of-head, no
    collar, the shoulders squared away from us and the head set up and to the right, as if
    looking past the camera at something behind it. One joined flat silhouette."""
    def P(u, v):
        return (x + u * s, y + v * s)

    body = [P(0.5, 60), P(0.8, 39), P(3.5, 33.5), P(12, 30.6), P(19, 29.4), P(31, 29.4), P(36.6, 32.4),
            P(39.4, 38), P(39.6, 60)]
    neck = [P(19, 18), P(30, 18), P(30.5, 31), P(18.5, 31)]
    if rim is not None:
        p.poly([(q[0], q[1]) for q in body], None, rim, 2.2 * s)
        p.ell(x + 24 * s, y + 13 * s, 11.2 * s, 13.2 * s, None, rim, 2.2 * s)
    p.poly(body, coat, None)
    p.poly(neck, hair, None)
    p.ell(x + 24 * s, y + 13 * s, 10.6 * s, 12.6 * s, hair, None)
    # the hair's own weight: a lower lobe over the nape, so the head is a mass, not a ball
    p.ell(x + 23.5 * s, y + 20.5 * s, 8.6 * s, 6.4 * s, hair, None)


def sitter_blank(p, x, y, s, pose, soft=0.9, op=1.0):
    lay = p.layer(BLANK)
    blank_shape(lay, x, y, s, pose)
    p.put_soft(lay, soft * s, op)
    blank_marks(p, x, y, s, pose)


def chair(p, cx, seat_y, s, col=SEPIA_DK, back=True, bh=40):
    """A plain wooden chair, front view, as a flat silhouette: back rail, seat, four legs."""
    w = 32 * s
    if back:
        p.rect(cx - w / 2 + 2 * s, seat_y - bh * s, cx - w / 2 + 6 * s, seat_y, col, None)
        p.rect(cx + w / 2 - 6 * s, seat_y - bh * s, cx + w / 2 - 2 * s, seat_y, col, None)
        p.rect(cx - w / 2 + 2 * s, seat_y - bh * s, cx + w / 2 - 2 * s, seat_y - (bh - 6) * s, col, None)
    p.rect(cx - w / 2, seat_y, cx + w / 2, seat_y + 5 * s, col, None)
    for dx in (-w / 2 + 1.5 * s, w / 2 - 5.5 * s):
        p.rect(cx + dx, seat_y + 5 * s, cx + dx + 4 * s, seat_y + 30 * s, col, None)
    p.rect(cx - w / 2 + 3 * s, seat_y + 20 * s, cx + w / 2 - 3 * s, seat_y + 23 * s, col, None)


def photo_scene(p, x0, y0, x1, y1, pose, rng=None, seaglass=False):
    """The frieze photograph inside (x0..x1, y0..y1): wall, floor line, a chair, and the blank.
    pose None: the chair is empty and sharp, nothing retouched."""
    p.rect(x0, y0, x1, y1, mix(SEPIA, SEAGLASS_HI, 0.22) if seaglass else SEPIA, None)
    fy = y0 + (y1 - y0) * 0.86 + (rng.uniform(-1.5, 1.5) if rng else 0)
    p.rect(x0, fy, x1, y1, mix(SEPIA, SEPIA_DK, 0.25), None)
    p.line([(x0, fy), (x1, fy)], mix(SEPIA, SEPIA_DK, 0.6), 1.4)
    wy = y0 + (y1 - y0) * 0.30
    p.line([(x0, wy), (x1, wy)], SEPIA_HI, 1.2)
    w = x1 - x0
    sc = w / 40.0 * 0.62           # the chair
    sb = w / 40.0 * 0.46           # the sitter, smaller, so the chair shows round them
    cx = (x0 + x1) / 2
    seat = fy - 29 * sc
    lay = p.layer()
    chair(lay, cx, seat, sc, bh=40 if pose is None else 26,
          col=mix(SEPIA_DK, SEAGLASS, 0.45) if seaglass else SEPIA_DK)
    if pose == "back":
        back_of_head(lay, cx - 20 * sb, seat - 57 * sb, sb, rim=mix(SEPIA_HI, PAPER_HI, 0.5))
    elif pose:
        sitter_blank(lay, cx - 20 * sb, seat - 57 * sb, sb, pose, soft=0.7)
    p.put(lay, mask=rect_mask([(x0, y0, x1, y1)]))


def frame_photo(p, x0, y0, pose, rng, cord=True, nail=True, seaglass=False):
    """One frieze frame (84x112) at (x0, y0): cord to a nail, dark oak moulding, paper mat."""
    cx = x0 + 42
    if nail:
        if cord:
            p.line([(x0 + 12, y0 + 2), (cx, y0 - 14), (x0 + 72, y0 + 2)], INK, 1.6)
        p.ell(cx, y0 - 14, 3.2, 3.2, BRASS_HI, INK, 1.4)
    soft_shadow(p, x0, y0, x0 + 84, y0 + 112, 4, 5, 3, 0.30)
    p.rect(x0, y0, x0 + 84, y0 + 112, TIMBER_DK, INK, 3.6)
    p.line([(x0 + 3, y0 + 3), (x0 + 81, y0 + 3)], TIMBER, 1.4)
    p.rect(x0 + 6, y0 + 6, x0 + 78, y0 + 106, PAPER_HI, INK, 1.6)
    photo_scene(p, x0 + 12, y0 + 13, x0 + 72, y0 + 99, pose, rng, seaglass)
    p.rect(x0 + 12, y0 + 13, x0 + 72, y0 + 99, None, mix(INK, SEPIA, 0.4), 1.4)


FRIEZE_X = [572 + 94 * i for i in range(9)]
FRIEZE_Y = 336


def frieze(p):
    rng = rng_for(610)
    for i in range(8):
        frame_photo(p, FRIEZE_X[i], FRIEZE_Y, "front", rng)
    # position 8: an empty nail and the paler rectangle where a frame hung
    x0 = FRIEZE_X[8]
    pale = p.layer(PAPER_HI)
    pale.rect(x0 + 1, FRIEZE_Y + 1, x0 + 83, FRIEZE_Y + 111, mix(WALLPAPER, PAPER_HI, 0.62), None)
    p.put_soft(pale, 1.2, 1.0)
    edge = p.layer()
    edge.rect(x0, FRIEZE_Y, x0 + 84, FRIEZE_Y + 112, None, mix(WALLPAPER, TIMBER, 0.5), 1.4)
    p.put(edge, 0.55)
    p.ell(x0 + 42, FRIEZE_Y - 14, 3.2, 3.2, BRASS_HI, INK, 1.4)


# ----------------------------------------------------------------------------- view A parts

SHELF = (36, 120, 516, 830)
RECESS = (250, 330, 340, 480)
LAMP_FIT = (296, 372)
BAY_T = (0.0, 0.31, 0.52, 0.67, 0.79, 0.885, 0.95)
CORNER_X = 34


def lerp_rect(a, b, t):
    return tuple(lerp(a[i], b[i], t) for i in range(4))


def band_mask(outer, inner):
    m = rect_mask([outer])
    return ImageChops.subtract(m, rect_mask([inner]))


def shelf_flat(p, rng, R, Rin, depth, plates=True):
    """One shelf-end flat: the frame between R and the opening Rin, carrying oak uprights, a
    header with a blank brass plate and level shelves of archive boxes. `depth` tints toward
    storm navy."""
    x0, y0, x1, y1 = R
    s = (x1 - x0) / (SHELF[2] - SHELF[0])
    tint = min(0.78, depth * 0.15)

    def T(c, extra=0.0):
        return mix(c, STORM, min(0.9, tint + extra))

    if depth >= 2:
        flat_band(p, R, Rin, depth)
        return
    lay = p.layer()
    lay.rect(x0, y0, x1, y1, T(OAK_DK, 0.15), None)
    up = 18 * s + 4
    hdr = max(8, (Rin[1] - y0) * 0.55)
    pitch = 70 * s + 8
    board = max(2.5, 7 * s)
    y = y0 + hdr
    while y < y1 - 8:
        yb = min(y + pitch, y1 - 4)
        # boxes standing on the board at yb
        x = x0 + up
        while x < x1 - up:
            bw = rng.uniform(26, 44) * s + 4
            bh = (yb - y) * rng.uniform(0.66, 0.9)
            if x + bw > x1 - up:
                bw = x1 - up - x
            if bw > 4:
                col = rng.choice((PAPER, PAPER_HI, mix(PAPER, TIMBER, 0.25), mix(PAPER, TIMBER, 0.12)))
                lay.rect(x + 1, yb - bh, x + bw - 1, yb, T(col), T(INK), max(1.0, 2.2 * s))
                if plates and depth <= 2 and bw > 18:
                    pw = min(bw * 0.6, 24 * s + 6)
                    lay.rect(x + bw / 2 - pw / 2, yb - bh * 0.62, x + bw / 2 + pw / 2,
                             yb - bh * 0.62 + 9 * s + 3, T(BRASS_HI), T(INK), max(1.0, 1.4 * s))
            x += bw
        lay.rect(x0, yb - board / 2, x1, yb + board / 2, T(OAK), T(INK), max(1.0, 2.2 * s))
        lay.line([(x0, yb - board / 2 + 1.5), (x1, yb - board / 2 + 1.5)], T(OAK_HI), max(1.0, 1.4 * s))
        y = yb
    # uprights and header
    lay.rect(x0, y0, x0 + up, y1, T(OAK), T(INK), max(1.2, 2.6 * s))
    lay.rect(x1 - up, y0, x1, y1, T(OAK), T(INK), max(1.2, 2.6 * s))
    lay.line([(x0 + up * 0.3, y0), (x0 + up * 0.3, y1)], T(OAK_HI), max(1.0, 1.6 * s))
    lay.line([(x1 - up * 0.7, y0), (x1 - up * 0.7, y1)], T(OAK_HI), max(1.0, 1.6 * s))
    lay.rect(x0, y0, x1, y0 + hdr, T(OAK), T(INK), max(1.2, 2.6 * s))
    lay.line([(x0, y0 + hdr - 3 * s - 1), (x1, y0 + hdr - 3 * s - 1)], T(OAK_DK), max(1.0, 1.6 * s))
    cx = (x0 + x1) / 2
    pw, ph = 70 * s + 8, 18 * s + 4
    lay.rect(cx - pw / 2, y0 + hdr / 2 - ph / 2, cx + pw / 2, y0 + hdr / 2 + ph / 2, T(BRASS_HI), T(INK),
             max(1.0, 1.8 * s), r=2)
    p.put(lay, mask=band_mask(R, Rin))
    # the deeper bay sits behind this flat's edge: a storm-navy reveal inside the opening
    rv = max(3, 12 * s)
    rev = p.layer()
    rev.rect(Rin[0], Rin[1], Rin[2], Rin[1] + rv, STORM, None)
    rev.rect(Rin[0], Rin[1], Rin[0] + rv, Rin[3], STORM, None)
    rev.rect(Rin[2] - rv * 0.5, Rin[1], Rin[2], Rin[3], STORM, None)
    p.put(rev, 0.92)
    p.rect(*Rin, None, INK, max(1.4, 3.0 * s))
    p.rect(*R, None, INK, 6.0 if depth == 0 else max(1.4, 3.0 * s))


def flat_band(p, R, Rin, depth, mute=0.0):
    """An inner bay collapsed to one flat navy band: no boxes. Down its two sides, every other
    shelf row is picked out as one paper bar, a little dimmer and bluer each ring in; the header
    and the plinth stay plain navy. Big quiet shapes, so the tunnel reads as depth at 1024
    instead of shimmering."""
    x0, y0, x1, y1 = R
    s = (x1 - x0) / (SHELF[2] - SHELF[0])
    navy = mix(STORM, SOOT, min(0.6, 0.12 * (depth - 1) + mute))
    bay = mix(PAPER, STORM, min(0.82, 0.24 + 0.11 * (depth - 2) + mute))
    lay = p.layer()
    lay.rect(x0, y0, x1, y1, navy, None)
    top, bot = Rin[1], Rin[3]
    rows = max(3, int(round((bot - top) / (70 * s + 8))))
    rh = (bot - top) / rows
    gap = max(1.2, 0.18 * rh)
    for i in range(rows):
        if (i + depth) % 2:
            continue
        lay.rect(x0 + gap, top + i * rh + gap, x1 - gap, top + (i + 1) * rh - gap * 0.6, bay, None)
    p.put(lay, mask=band_mask(R, Rin))
    p.rect(*Rin, None, INK, max(1.4, 2.4 * s))
    p.rect(*R, None, INK, max(1.4, 2.4 * s))


def shelves(p):
    rng = rng_for(620)
    rects = [lerp_rect(SHELF, RECESS, t) for t in BAY_T] + [RECESS]
    # the recess: flat dark navy, a tiny unlit lamp fitting
    p.rect(*RECESS, mix(STORM, SOOT, 0.35), INK, 2.4)
    lx, ly = LAMP_FIT
    p.line([(lx, RECESS[1] + 2), (lx, ly - 6)], STORM_HI, 1.4)
    p.poly([(lx - 4, ly - 6), (lx + 4, ly - 6), (lx + 9, ly + 2), (lx - 9, ly + 2)], STORM_HI, None)
    p.ell(lx, ly + 3.5, 2.2, 1.6, STORM_HI, None)
    for k in range(len(BAY_T) - 1, -1, -1):
        shelf_flat(p, rng, rects[k], rects[k + 1], k)
    # floor under the run: the nearest flat's plinth meets the boards
    p.rect(SHELF[0] + 6, SHELF[3] + 10, SHELF[2] - 6, FLOOR_Y, TIMBER_DK, INK, 4.4)
    p.rect(SHELF[0] - 4, SHELF[3] - 2, SHELF[2] + 4, SHELF[3] + 10, OAK_DK, INK, 4.4)


def bay_t(n):
    """The nested frames' lerp positions for an n-frame bay: wide near frames, then each
    further one thinner, never thinner than a few pixels."""
    return tuple(1.0 - (1.0 - k / n) ** 1.5 for k in range(n))


DOOR_CASING = 8
DOOR_CHAIR = mix(SEPIA_DK, SEAGLASS, 0.45)     # the ninth photograph's chair


def shelves_deep(p, n, doorway=False):
    """The tide plates' shelf run: `n` nested frames from the near flat to the recess. With
    `doorway` the recess is the innermost frame made a doorway: a casing round a lit opening
    and in it, empty and sharp, the chair from the ninth photograph. The view's lamp dot and
    the passer stay registered to RECESS."""
    rng = rng_for(620)
    rects = [lerp_rect(SHELF, RECESS, t) for t in bay_t(n)] + [RECESS]
    x0, y0, x1, y1 = RECESS
    if doorway:
        c = DOOR_CASING
        p.rect(x0, y0, x1, y1, mix(OAK, STORM, 0.35), INK, 2.4)
        lit = (x0 + c, y0 + c, x1 - c, y1)
        p.rect(*lit, mix(GLASS_LIT, AMBER, 0.28), None)
        glow = p.layer(PAPER_HI)
        glow.ell((x0 + x1) / 2, y1 - 40, 30, 46, PAPER_HI, None)
        p.put_soft(glow, 10, 0.55)
        fy = y1 - 6
        p.rect(lit[0], fy, lit[2], y1, mix(GLASS_LIT, TIMBER, 0.35), None)
        p.line([(lit[0], fy), (lit[2], fy)], mix(TIMBER, INK, 0.3), 1.4)
        sc = 1.1
        chair(p, (x0 + x1) / 2, fy - 30 * sc + 1, sc, col=DOOR_CHAIR, bh=40)
        p.rect(*lit, None, INK, 2.2)
        p.rect(x0, y0, x1, y1, None, INK, 2.6)
    else:
        p.rect(*RECESS, mix(STORM, SOOT, 0.35), INK, 2.4)
    lx, ly = LAMP_FIT
    p.line([(lx, y0 + (DOOR_CASING if doorway else 0) + 2), (lx, ly - 6)], STORM_HI if not doorway else INK, 1.4)
    p.poly([(lx - 4, ly - 6), (lx + 4, ly - 6), (lx + 9, ly + 2), (lx - 9, ly + 2)],
           STORM_HI if not doorway else BRASS_LO, None)
    p.ell(lx, ly + 3.5, 2.2, 1.6, STORM_HI, None)
    for k in range(len(rects) - 2, -1, -1):
        shelf_flat(p, rng, rects[k], rects[k + 1], k)
    p.rect(SHELF[0] + 6, SHELF[3] + 10, SHELF[2] - 6, FLOOR_Y, TIMBER_DK, INK, 4.4)
    p.rect(SHELF[0] - 4, SHELF[3] - 2, SHELF[2] + 4, SHELF[3] + 10, OAK_DK, INK, 4.4)


S7_BAYS = ((-60, 206, 100, 622), (-60, 258, 74, 566), (-60, 302, 52, 520), (-60, 338, 32, 486),
           (-60, 366, 14, 458))


def shelves_beyond(p):
    """Band 7: more bays, each smaller, running on to the left past the room's own corner."""
    rng = rng_for(625)
    rects = list(S7_BAYS)
    deep = rects[-1]
    p.rect(*deep, mix(STORM, SOOT, 0.35), INK, 2.0)
    for k in range(len(rects) - 2, -1, -1):
        shelf_flat(p, rng, rects[k], rects[k + 1], 2 + k, plates=False)
    # the nearest flat's own upright and the wall's corner stay in front of them
    up = 22
    p.rect(SHELF[0], SHELF[1], SHELF[0] + up, SHELF[3], OAK, INK, 2.6)
    p.line([(SHELF[0] + up * 0.3, SHELF[1]), (SHELF[0] + up * 0.3, SHELF[3])], OAK_HI, 1.6)
    corner(p, over=True)


def corner(p, over=False):
    """The left wall corner: the side wall seen edge-on, a little darker, with its own rails."""
    if not over:
        p.rect(-4, CEIL_Y + 22, CORNER_X, SKIRT_Y, wall(WALL_SIDE), None)
        p.rect(-4, DADO_Y - 6, CORNER_X, DADO_Y + 10, mix(TRIM, INK, 0.3), INK, 2.4)
        p.rect(-4, DADO_Y + 10, CORNER_X, SKIRT_Y, mix(WAINSCOT, INK, 0.3), None)
    p.line([(CORNER_X, CEIL_Y + 18), (CORNER_X, FLOOR_Y)], INK, 3.2)
    p.line([(CORNER_X + 3, CEIL_Y + 22), (CORNER_X + 3, FLOOR_Y)], wall(mix(WALLPAPER, PAPER_HI, 0.4)), 1.4)


CLOCK = (934, 112, 1084, 262)
CLOCK_C = (1009, 187)


def wall_clock(p):
    x0, y0, x1, y1 = CLOCK
    cx, cy = CLOCK_C
    soft_shadow(p, x0, y0, x1, y1 + 54, 5, 7, 5, 0.28, r=10)
    # trunk with a glass door and a still pendulum
    p.rect(cx - 36, y1 - 8, cx + 36, y1 + 54, OAK, INK, 4.6, r=4)
    p.rect(cx - 26, y1 + 2, cx + 26, y1 + 46, mix(PAPER_HI, OAK_DK, 0.55), INK, 2.0)
    p.line([(cx, y1 + 2), (cx, y1 + 30)], BRASS_LO, 2.4)
    p.ell(cx, y1 + 33, 10, 10, BRASS, INK, 1.8)
    p.ell(cx - 3, y1 + 30, 3, 3, BRASS_HI, None)
    # case head
    p.rect(x0, y0, x1, y1, OAK, INK, 5, r=12)
    p.rect(x0 + 5, y0 + 5, x1 - 5, y1 - 5, None, OAK_HI, 1.4, r=9)
    p.ell(cx, cy, 65, 65, BRASS, INK, 3)
    p.ell(cx, cy, 58, 58, PAPER_HI, INK, 2)
    for k in range(60):
        a = math.radians(k * 6)
        r0 = 48 if k % 5 == 0 else 52
        wd = 3.0 if k % 5 == 0 else 1.3
        p.line([(cx + r0 * math.sin(a), cy - r0 * math.cos(a)), (cx + 55 * math.sin(a), cy - 55 * math.cos(a))],
               INK, wd)
    p.ell(cx, cy, 4, 4, BRASS_LO, INK, 1.4)       # the bare arbor: no hands


CAB = (548, 606, 762, 830)
MERCER_TAB = (572, 536, 740, 596)


def card_cabinet(p):
    """The open-topped oak card cabinet: eight cards, then a divider with nothing behind it."""
    x0, y0, x1, y1 = CAB
    soft_shadow(p, x0, y0, x1, y1, 6, 6, 5, 0.3)
    # the stand
    for lx in (x0 + 14, x1 - 30):
        p.rect(lx, y1, lx + 16, FLOOR_Y + 4, OAK_DK, INK, 2.2)
    p.rect(x0 + 14, 866, x1 - 14, 874, OAK_DK, INK, 1.8)
    # cards rising from the box: a common top edge and staggered tabs, front to back = left to right
    dx = x0 + 12 + 8 * 21
    # back to front: the eight cards' tabs stagger left to right, then the divider
    p.rect(dx + 14, 588, x1 - 8, y0 + 4, SLOT, INK, 1.6)          # nothing behind the divider
    for k in range(7, -1, -1):
        tx = x0 + 12 + k * 21
        col = PAPER_HI if k % 2 == 0 else mix(PAPER_HI, PAPER, 0.55)
        p.rect(tx, 572, tx + 19, 600, col, INK, 1.6, r=4)
    p.rect(x0 + 8, 588, dx + 14, y0 + 4, PAPER_HI, INK, 1.8)
    p.line([(x0 + 12, 594), (dx + 10, 594)], mix(PAPER, TIMBER, 0.3), 1.2)
    p.rect(dx, 566, dx + 14, y0 + 2, BRASS, INK, 1.8, r=3)
    p.line([(dx + 4, 570), (dx + 4, y0)], BRASS_HI, 1.4)
    # the box
    p.rect(x0, y0 + 6, x1, y1, OAK, INK, 6)
    p.rect(x0 - 4, y0 - 6, x1 + 4, y0 + 6, OAK_HI, INK, 4.4)
    p.rect(x0 + 16, y0 + 22, x1 - 16, y1 - 16, mix(OAK, OAK_DK, 0.35), INK, 2)
    p.line([(x0 + 20, y0 + 27), (x1 - 20, y0 + 27)], OAK_HI, 1.4)
    oak_plate(p, (x0 + x1) / 2 - 42, y0 + 40, (x0 + x1) / 2 + 42, y0 + 64)
    cx = (x0 + x1) / 2
    pull(p, cx, y0 + 98, 16, 12, 6, 2.6)
    if not _ring_pulls:
        screw(p, cx - 18, y0 + 96, 3)
        screw(p, cx + 18, y0 + 96, 3)
    p.rect(x0 + 16, y1 - 70, x1 - 16, y1 - 16, None, mix(INK, OAK, 0.5), 1.4)


DESK = (800, 700, 1200, 830)
LIGHTBOX = (820, 560, 1180, 710)
LB_GLASS = (834, 572, 1166, 694)
LB_SLOTS = [(840 + 82 * i, 580, 840 + 82 * i + 74, 686) for i in range(4)]


def desk(p):
    x0, y0, x1, y1 = DESK
    soft_shadow(p, x0, y0, x1, y1, 6, 6, 6, 0.28)
    for lx in (x0 + 14, x1 - 34):
        p.rect(lx, y0 + 16, lx + 20, FLOOR_Y + 4, OAK_DK, INK, 2.4)
    p.rect(x0 + 34, 856, x1 - 34, 866, OAK_DK, INK, 2)
    p.rect(x0 + 8, y0 + 16, x1 - 8, 790, OAK, INK, 5)
    for k in range(2):
        dx0 = x0 + 30 + k * 176 + (8 if k else 0)
        p.rect(dx0, y0 + 30, dx0 + 156, 778, mix(OAK, OAK_DK, 0.3), INK, 2.0)
        oak_plate(p, dx0 + 56, y0 + 40, dx0 + 100, y0 + 52)
        p.rect(dx0 + 62, y0 + 60, dx0 + 94, y0 + 66, BRASS, INK, 1.6, r=2)
    p.rect(x1 - 30 - 156 + 160, y0 + 30, x1 - 22, 778, mix(OAK, OAK_DK, 0.3), INK, 2.0)
    p.rect(x0 - 4, y0, x1 + 4, y0 + 16, OAK_HI, INK, 5)
    p.line([(x0, y0 + 4), (x1, y0 + 4)], mix(OAK_HI, PAPER, 0.35), 1.6)


def lightbox(p):
    x0, y0, x1, y1 = LIGHTBOX
    soft_shadow(p, x0, y0, x1, y1, 5, 6, 5, 0.25)
    lamp_pool(p, (x0 + x1) / 2, (y0 + y1) / 2, 210, 90, 0.30)
    p.rect(x0, y0, x1, y1 - 6, OAK_DK, INK, 5, r=4)
    p.rect(x0 + 4, y0 + 4, x1 - 4, y0 + 8, OAK, None)
    p.rect(*LB_GLASS, GLASS_LIT, INK, 2.2)
    gl = p.layer()
    for sx0, sy0, sx1, sy1 in LB_SLOTS:
        gl.rect(sx0, sy0, sx1, sy1, None, INK, 1.4)
    p.put(gl, 0.28)
    # feet on the desk top
    for fx in (x0 + 24, x1 - 52):
        p.rect(fx, y1 - 8, fx + 28, y1, BRASS_LO, INK, 1.8)


VAULT_LEAF = (1214, 500, 1420, 900)


def vault_door(p):
    """The inner face of the vault door, standing ajar: steel, a hub, three bolt bars."""
    x0, y0, x1, y1 = VAULT_LEAF
    # the doorway behind it: a dark reveal at the hinge-free edge
    p.rect(1188, 480, 1440, FLOOR_Y, STEEL_DK, INK, 5.5)
    p.rect(1196, 490, 1216, FLOOR_Y, mix(STORM, SOOT, 0.4), None)
    soft_shadow(p, x0, y0, x1, y1, -8, 0, 6, 0.35)
    p.rect(x0, y0, x1, y1, STEEL, INK, 6, r=6)
    p.rect(x0 + 14, y0 + 14, x1 - 14, y1 - 14, mix(STEEL, STEEL_DK, 0.3), INK, 2.2, r=4)
    p.line([(x0 + 18, y0 + 18), (x1 - 18, y0 + 18)], STEEL_HI, 1.6)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    for by in (y0 + 70, cy, y1 - 70):
        p.rect(x0 + 4, by - 9, x1 + 6, by + 9, BRASS, INK, 2.2, r=3)
        p.line([(x0 + 8, by - 4), (x1, by - 4)], BRASS_HI, 1.6)
        p.rect(x1 - 2, by - 12, x1 + 10, by + 12, BRASS_LO, INK, 2)
    p.rect(cx - 8, y0 + 70, cx + 8, y1 - 70, BRASS_LO, INK, 2.2)
    p.ell(cx, cy, 40, 40, BRASS, INK, 3)
    p.ell(cx, cy, 26, 26, BRASS_LO, INK, 2)
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        p.ell(cx + 33 * math.cos(a), cy + 33 * math.sin(a), 3, 3, BRASS_HI, INK, 1.2)
    p.ell(cx, cy, 9, 9, BRASS_HI, INK, 1.8)
    for x, y in ((x0 + 26, y0 + 26), (x1 - 26, y0 + 26), (x0 + 26, y1 - 26), (x1 - 26, y1 - 26)):
        rivet(p, x, y, 4)


# ----------------------------------------------------------------------------- escalation
#
# Band 4: the stripes ripple once where the sea is heard through the wall. Band 5 on: the stripes
# lean toward the shelves, sea-glass damp rises from the floor up the wainscot, and a dead-level
# tide line at the office's height crosses the wall and everything standing against it. Band 7:
# a second, smaller tunnel mouth breaks through the wall, and index cards drift across the floor
# toward it. Light never drops.

RIPPLE_AMP = 9.0
LEAN = {4: 0.0, 5: 3.0, 7: 6.0}


def damp(p, rng):
    """Sea-glass soak: a pale wash on the wall below the tide line, blooms rising from the
    skirting up the wainscot, and wet patches on the boards."""
    wash = p.layer(DAMP)
    wash.rect(-4, TIDE_Y, W + 4, DADO_Y - 6, DAMP, None)
    p.put(wash, 0.30)
    bl = p.layer(DAMP)
    x = rng.uniform(-40, 40)
    while x < W:
        w = rng.uniform(70, 190)
        top = rng.uniform(DADO_Y - 70, SKIRT_Y - 90)
        edge = ragged(rng, x, x + w, top, 26, step=10, waves=3)
        bl.poly([(x, SKIRT_Y + 2)] + edge + [(x + w, SKIRT_Y + 2)], mix(DAMP, SEAGLASS_HI, 0.45), None)
        x += w + rng.uniform(10, 90)
    p.put_soft(bl, 3, 0.62)
    # tide-mark crusts in the blooms: thin pale wandering lines
    cr = p.layer()
    for k in range(3):
        y = SKIRT_Y - 40 - k * 46 + rng.uniform(-8, 8)
        pts = ragged(rng, -4, W + 4, y, 6, step=14, waves=2)
        cr.line(pts, mix(PAPER_HI, DAMP, 0.3), 1.8)
    p.put(cr, 0.35)
    fl = p.layer(DAMP)
    for _ in range(9):
        cx, cy = rng.uniform(0, W), rng.uniform(FLOOR_Y + 30, H - 20)
        fl.ell(cx, cy, rng.uniform(70, 170), rng.uniform(9, 20), DAMP, None)
    p.put_soft(fl, 4, 0.40)


def tide_line(p, rng, keep_out=()):
    """The line the sea left, dead level, across the wall and whatever stands against it."""
    lay = p.layer()
    pts = ragged(rng, -4, W + 4, TIDE_Y, 2.4, step=8, waves=2)
    st = p.layer(SEAGLASS)
    st.poly(pts + [(W + 4, TIDE_Y + 16), (-4, TIDE_Y + 16)], mix(SEAGLASS, STORM, 0.3), None)
    m0 = rect_mask([(-4, 0, W + 4, H)])
    if keep_out:
        m0 = ImageChops.subtract(m0, rect_mask(list(keep_out)))
    st.im = st.im.filter(ImageFilter.GaussianBlur(3 * SS))
    p.put(st, 0.35, mask=m0)
    lay.line([(x, y + 2.5) for x, y in pts], mix(STORM, SEAGLASS, 0.5), 2.6)
    k = 0
    while k < len(pts) - 1:                         # the crust, broken where it flaked
        n = rng.randint(3, 9)
        lay.line(pts[k:k + n + 1], mix(PAPER_HI, DAMP, 0.25), 1.8)
        k += n + rng.randint(1, 4)
    x = 0.0
    while x < W:                                    # salt beads along the crust
        lay.ell(x, TIDE_Y - 1 + rng.uniform(-1.5, 1.5), rng.uniform(1.0, 2.2), rng.uniform(0.8, 1.5),
                PAPER_HI, None)
        x += rng.uniform(10, 40)
    m = rect_mask([(-4, 0, W + 4, H)])
    if keep_out:
        m = ImageChops.subtract(m, rect_mask(list(keep_out)))
    p.put(lay, 0.7, mask=m)


M_OUT = (522, 462, 712, 902)
M_IN = (574, 490, 606, 532)
M_T = (0.0, 0.30, 0.52, 0.68, 0.80, 0.90)


def breach(p, rng):
    """Band 7: a second, smaller mouth of the same tunnel broken through the wall between the
    shelves and the hanging file, cutting the stripes and the dado rail. Its vanishing bay sits
    just above the card cabinet, with the same small lamp at its heart."""
    x0, y0, x1, y1 = M_OUT
    torn = []
    for x, y in ragged(rng, x0 - 10, x1 + 10, y0 - 8, 7, step=9):
        torn.append((x, y))
    torn += [(x1 + 10 + rng.uniform(-4, 4), y) for y in range(int(y0), int(y1), 22)]
    torn += [(x, y + 12) for x, y in ragged(rng, x0 - 10, x1 + 10, y1, 6, step=9)][::-1]
    torn += [(x0 - 10 + rng.uniform(-4, 4), y) for y in range(int(y1), int(y0), -22)]
    sh = p.layer()
    sh.poly([(x + 6, y + 8) for x, y in torn], SHADOW, None)
    p.put_soft(sh, 6, 0.35)
    p.poly(torn, mix(PAPER, WALLPAPER, 0.4), INK, 3.0)       # the paper torn back round it
    p.rect(*M_OUT, mix(STORM, SOOT, 0.2), INK, 4.0)
    rects = [lerp_rect(M_OUT, M_IN, t) for t in M_T] + [M_IN]
    p.rect(*M_IN, mix(STORM, SOOT, 0.45), INK, 1.6)
    for k in range(len(M_T) - 1, -1, -1):
        flat_band(p, rects[k], rects[k + 1], 2 + k, mute=0.05)
    cx, cy = (M_IN[0] + M_IN[2]) / 2, M_IN[1] + 12
    glow = p.layer(AMBER)
    glow.ell(cx, cy, 9, 7, AMBER, None)
    p.put_soft(glow, 3, 0.6)
    p.ell(cx, cy, 2.6, 2.0, AMBER, None)
    p.rect(*M_OUT, None, INK, 5.0)


def card_trail(p, rng):
    """Band 7: index cards drift along the boards from the room toward the breach, smaller and
    closer together the nearer they get to it."""
    n = 36
    for k in range(n):
        t = k / (n - 1)
        x = lerp(1170, 536, t ** 0.85) + rng.uniform(-22, 22)
        y = lerp(1058, 912, t ** 0.7) + rng.uniform(-9, 9)
        s = lerp(1.0, 0.45, t)
        w, h = rng.uniform(34, 48) * s, rng.uniform(9, 14) * s
        if rng.random() < 0.18:
            w, h = h * 1.6, w * 0.8                    # one stood on its edge
        a = rng.uniform(-7, 7)
        c = (x, y)
        pts = [rot(q, c, a) for q in ((x - w / 2, y - h / 2), (x + w / 2, y - h / 2), (x + w / 2, y + h / 2),
                                      (x - w / 2, y + h / 2))]
        sh = p.layer()
        sh.poly([(q[0] + 2, q[1] + 3) for q in pts], SHADOW, None)
        p.put_soft(sh, 2, 0.3)
        p.poly(pts, rng.choice((PAPER_HI, PAPER_HI, ENAMEL, PAPER)), INK, max(1.2, 2.0 * s))
        if rng.random() < 0.4:
            tab = [rot(q, c, a) for q in ((x - w / 2 + 3 * s, y - h / 2), (x - w / 2 + 3 * s, y - h / 2 - 5 * s),
                                          (x - w / 2 + 13 * s, y - h / 2 - 5 * s), (x - w / 2 + 13 * s, y - h / 2))]
            p.poly(tab, rng.choice((SEAGLASS_HI, BRASS_HI, PAPER_HI)), INK, max(1.0, 1.4 * s))


def view_a_common(rng, stage=4):
    p = Pen(W, H, rng, PAPER)
    shell(p, rng_for(500), lean=LEAN[stage], ripple=RIPPLE_AMP if stage == 4 else 0.0)
    if stage >= 5:
        damp(p, rng_for(530))
    corner(p)
    lamp_pool(p, 770, 260, 260, 150, 0.34)
    if stage >= 7:
        breach(p, rng_for(532))
    return p


def paint_view_a(rng, stage=4, bays=None, doorway=False):
    p = view_a_common(rng, stage)
    if bays is None:
        shelves(p)
    else:
        shelves_deep(p, bays, doorway)
    wall_clock(p)
    frieze(p)
    card_cabinet(p)
    desk(p)
    lightbox(p)
    vault_door(p)
    pendant(p, 770, 168)
    turn_plate(p)
    if stage >= 5:
        tide_line(p, rng_for(531), keep_out=[(1250, 500, 1386, 562), M_OUT])
    if stage >= 7:
        card_trail(p, rng_for(533))
        q = Pen(W, H, rng_for(626))
        shelves_beyond(q)
        p.put(q)
    return p


# ----------------------------------------------------------------------------- view A overlays

def paint_a_panels_loose(rng):
    p = Pen(W, H, rng)
    # four loose panels leaning on the lightbox foot, at slightly different leans
    leans = (-5.0, 3.0, -2.0, 6.0)
    xs = (846, 922, 1004, 1082)
    for k, (x, a) in enumerate(zip(xs, leans)):
        lay = p.layer()
        w, h = 64, 82
        base = (x + w / 2, 712)
        pts = [(x, 712 - h), (x + w, 712 - h), (x + w, 712), (x, 712)]
        pts = [rot(q, base, a) for q in pts]
        sh = p.layer()
        sh.poly([(q[0] + 4, q[1] + 3) for q in pts], SHADOW, None)
        p.put_soft(sh, 3, 0.32)
        lay.poly(pts, mix(SOOT, STORM, 0.3), INK, 2)
        inner = [rot(q, base, a) for q in [(x + 5, 712 - h + 5), (x + w - 5, 712 - h + 5),
                                            (x + w - 5, 712 - 18), (x + 5, 712 - 18)]]
        lay.poly(inner, SEPIA, INK, 1.2)
        # tiny chair-row hint: a band of pale blanks
        for j in range(4):
            q = rot((x + 11 + j * 14, 712 - 44), base, a)
            lay.ell(q[0], q[1], 4, 5, BLANK, None)
        p.put(lay)
    # the registration cover pinned across the lightbox
    soft_shadow(p, 826, 602, 1174, 642, 3, 5, 3, 0.3)
    p.rect(826, 602, 1150, 642, STORM, INK, 2.6)
    p.line([(830, 607), (1146, 607)], STORM_HI, 1.4)
    p.rect(1150, 598, 1178, 646, PAPER, INK, 2.2, r=3)
    p.ell(1164, 622, 4, 4, None, INK, 1.6)
    for x in (840, 1000, 1136):
        p.ell(x, 612, 4.2, 4.2, BRASS_HI, INK, 1.4)
    return p


def mini_panel(p, x0, y0, x1, y1, lamps_lit, last_pose="front"):
    p.rect(x0, y0, x1, y1, SEPIA, INK, 1.8)
    w = x1 - x0
    # film edge
    p.rect(x0, y1 - 14, x1, y1, mix(SOOT, STORM, 0.3), None)
    for k in range(5):
        p.rect(x0 + 4 + k * (w - 8) / 5, y1 - 10, x0 + 10 + k * (w - 8) / 5, y1 - 5, PAPER, None)
    s = w / 280.0
    for k in range(8):
        cx = x0 + (28 + 32 * k) * s
        lit = k < lamps_lit
        p.ell(cx, y0 + 26 * (y1 - y0) / 106, 2.2, 2.2, AMBER if lit else SEPIA_DK, None)
    for k in range(8):
        cx = x0 + (28 + 32 * k) * s
        pose = last_pose if k == 7 else "front"
        if pose == "back":
            back_of_head(p, cx - 20 * s, y0 + 40 - 2, s * 1.05)
        else:
            lay = p.layer(BLANK)
            blank_shape(lay, cx - 20 * s * 1.0, y0 + 40, s * 1.0, pose)
            p.put_soft(lay, 0.4, 1.0)
        p.rect(cx - 5, y0 + 62, cx + 5, y0 + 64, SEPIA_DK, None)
        p.rect(cx - 5, y0 + 64, cx - 4, y0 + 76, SEPIA_DK, None)
        p.rect(cx + 4, y0 + 64, cx + 5, y0 + 76, SEPIA_DK, None)


def paint_a_sheet_assembled(rng):
    p = Pen(W, H, rng)
    lit = (8, 6, 3, 0)
    for k, (x0, y0, x1, y1) in enumerate(LB_SLOTS):
        mini_panel(p, x0, y0 + 2, x1, y1 - 4, lit[k], "back" if k == 3 else "front")
    # the clamp bar along the bottom edge
    p.rect(LB_GLASS[0] - 2, 680, LB_GLASS[2] + 2, 694, BRASS, INK, 2.4, r=3)
    p.line([(LB_GLASS[0] + 2, 684), (LB_GLASS[2] - 2, 684)], BRASS_HI, 1.6)
    for k in range(5):
        screw(p, LB_GLASS[0] + 8 + k * (LB_GLASS[2] - LB_GLASS[0] - 16) / 4, 687, 3.2)
    return p


def paint_a_photos_turned(rng):
    p = Pen(W, H, rng)
    r = rng_for(610)
    for i in range(8):
        x0 = FRIEZE_X[i]
        frame_photo(p, x0, FRIEZE_Y, "back", r, cord=False, nail=False)
    # keep only the frame interiors (the mats and photographs), registered to the frames
    m = rect_mask([(x + 6, FRIEZE_Y + 6, x + 78, FRIEZE_Y + 106) for x in FRIEZE_X[:8]])
    out = Pen(W, H, rng)
    out.put(p, mask=m)
    return out


def paint_a_ninth_photo(rng):
    p = Pen(W, H, rng)
    frame_photo(p, FRIEZE_X[8], FRIEZE_Y, None, rng_for(611), seaglass=True)
    return p


def paint_a_mercer_card(rng):
    p = Pen(W, H, rng)
    x0, y0, x1, y1 = MERCER_TAB
    pts = [(556, CAB[1] - 6), (556, 566), (x0, 566), (x0, y0), (x1, y0), (x1, 566), (754, 566),
           (754, CAB[1] - 6)]
    sh = p.layer()
    sh.poly([(x + 4, y + 4) for x, y in pts], SHADOW, None)
    p.put_soft(sh, 3, 0.3)
    # fresh and unwritten: whiter than every other card in the room, no rules, no stamp
    p.poly(pts, mix(PAPER_HI, (255, 255, 255), 0.55), INK, 2.4)
    # the box's top rail stays in front of the card
    p.rect(CAB[0] - 4, CAB[1] - 6, CAB[2] + 4, CAB[1] + 6, OAK_HI, INK, 4.4)
    return p


# ----------------------------------------------------------------------------- view B parts

# Round 3 (p2) stage art paints every drawer pull as a plain ring: a navy circle outline round a
# small brass boss, no upturned curve. False (every older stem) keeps the old arc pulls exactly.
_ring_pulls = False


def pull(p, cx, cy, rx, ry, w_lo, w_hi):
    """A drawer pull centred on (cx, cy): the old brass arc (rx, ry; strokes w_lo, w_hi), or,
    in ring mode, a plain ring of radius rx * 0.8 with a brass boss in its middle."""
    if _ring_pulls:
        r = rx * 0.8
        p.ell(cx, cy, r, r, None, INK, max(1.8, w_hi * 0.9))
        b = max(2.4, r * 0.34)
        p.ell(cx, cy, b, b, BRASS_HI, INK, 1.3)
        return
    p.arc(cx, cy, rx, ry, 0, 180, BRASS_LO, w_lo)
    p.arc(cx, cy, rx, ry, 0, 180, BRASS_HI, w_hi)


CHEST = (60, 140, 720, 840)
ROWS = [(156, 228), (228, 304), (304, 380), (380, 450), (450, 520), (520, 605), (605, 690), (690, 790)]
COLS = [108, 219, 330, 430, 530, 630, 704]
STAFF = (430, 380, 630, 520)
STAFF_PLATE = (480, 392, 580, 420)
STAFF_C = (530, 450)
TRAY = (420, 548, 640, 612)
VENN = (110, 690, 330, 790)
VENN_PLATE = (180, 706, 260, 732)


def small_drawer(p, x0, y0, x1, y1):
    p.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, OAK, INK, 2.2, r=2)
    p.line([(x0 + 6, y0 + 6), (x1 - 6, y0 + 6)], OAK_HI, 1.3)
    cx = (x0 + x1) / 2
    pw = min(48, (x1 - x0) * 0.5)
    oak_plate(p, cx - pw / 2, y0 + 11, cx + pw / 2, y0 + 25)
    py = y0 + 25 + (y1 - y0 - 25) * 0.5
    pull(p, cx, py - 1, 9, 6, 4.4, 1.8)


def chest(p):
    x0, y0, x1, y1 = CHEST
    soft_shadow(p, x0, y0, x1, y1, 8, 8, 7, 0.3)
    p.rect(x0, y0, x1, y1, OAK_DK, INK, 6)
    p.rect(x0 - 6, y0 - 8, x1 + 6, y0 + 14, OAK, INK, 4.6)
    p.line([(x0 - 2, y0 - 3), (x1 + 2, y0 - 3)], OAK_HI, 1.6)
    p.rect(x0 + 4, 794, x1 - 4, y1, OAK, INK, 2.6)
    p.rect(x0 + 12, y0 + 16, COLS[0], 790, OAK, INK, 2.4)
    p.line([(x0 + 18, y0 + 18), (x0 + 18, 788)], OAK_HI, 1.4)
    p.rect(COLS[-1], y0 + 16, x1 - 12, 790, OAK, INK, 2.4)
    for ry0, ry1 in ROWS:
        for k in range(len(COLS) - 1):
            cx0, cx1 = COLS[k], COLS[k + 1]
            if ry0 >= STAFF[1] and ry1 <= STAFF[3] and cx0 >= STAFF[0] and cx1 <= STAFF[2]:
                continue
            if ry0 == VENN[1] and cx1 <= COLS[2]:
                continue
            small_drawer(p, cx0, ry0, cx1, ry1)
    staff_face(p)
    venn_face(p)


def staff_face(p):
    x0, y0, x1, y1 = STAFF
    p.rect(x0 - 2, y0 - 2, x1 + 2, y1 + 2, OAK_DK, INK, 3)
    p.rect(x0 + 4, y0 + 4, x1 - 4, y1 - 4, OAK, INK, 2.6, r=2)
    p.rect(x0 + 14, y0 + 44, x1 - 14, y1 - 14, None, mix(INK, OAK, 0.4), 1.6, r=2)
    p.line([(x0 + 8, y0 + 8), (x1 - 8, y0 + 8)], OAK_HI, 1.6)
    plate(p, *STAFF_PLATE)
    cx = (x0 + x1) / 2
    pull(p, cx, 478, 22, 14, 8, 3.4)
    if not _ring_pulls:
        screw(p, cx - 26, 476, 3.6)
        screw(p, cx + 26, 476, 3.6)


def venn_face(p):
    x0, y0, x1, y1 = VENN
    p.rect(x0 - 2, y0 - 2, x1 + 2, y1 + 2, OAK_DK, INK, 3)
    p.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, OAK, INK, 2.6, r=2)
    p.line([(x0 + 7, y0 + 7), (x1 - 7, y0 + 7)], OAK_HI, 1.6)
    venn_plate(p)
    pull(p, (x0 + x1) / 2, 762, 14, 9, 6, 2.4)


def venn_plate(p):
    x0, y0, x1, y1 = VENN_PLATE
    p.rect(x0 - 2, y0 - 2, x1 + 2, y1 + 2, BRASS_LO, INK, 2, r=2)
    p.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, BRASS_HI, None, r=1)
    for k in range(3):
        bx = x0 + 22 + k * 18
        p.line([(bx - 6, y1 - 5), (bx + 6, y0 + 5)], INK, 3.0)
        p.line([(bx - 4.5, y1 - 5), (bx + 7.5, y0 + 5)], BRASS_LO, 1.0)


def tray(p):
    x0, y0, x1, y1 = TRAY
    soft_shadow(p, x0 + 4, y0, x1 - 4, y0 + 40, 4, 8, 4, 0.35)
    # bracket arms back to the drawer stile
    for bx in (x0 + 34, x1 - 50):
        p.poly([(bx, y0 + 40), (bx + 16, y0 + 40), (bx + 16, y1), (bx + 10, y1)], BRASS_LO, INK, 2)
    p.rect(x0 + 24, y1 - 8, x1 - 24, y1, BRASS_LO, INK, 2)
    p.poly([(x0, y0), (x1, y0), (x1 - 10, y0 + 40), (x0 + 10, y0 + 40)], BRASS, INK, 2.8)
    p.rect(x0 - 3, y0 - 3, x1 + 3, y0 + 8, BRASS_HI, INK, 2.4, r=3)
    p.line([(x0 + 14, y0 + 20), (x1 - 14, y0 + 20)], BRASS_LO, 1.4)


FCAB = (800, 470, 1180, 830)
SPINES = [(824, 486, 936, 704), (944, 486, 1056, 704), (1064, 486, 1176, 704)]
SPINE_COL = (STORM_HI, mix(TIMBER, PAPER, 0.1), SEAGLASS)


def folder_cabinet(p):
    x0, y0, x1, y1 = FCAB
    soft_shadow(p, x0, y0, x1, y1, 7, 7, 6, 0.3)
    for lx in (x0 + 12, x1 - 32):
        p.rect(lx, y1, lx + 20, FLOOR_Y + 4, OAK_DK, INK, 2.4)
    p.rect(x0, y0, x1, y1, OAK, INK, 6)
    p.rect(x0 - 8, y0 - 14, x1 + 8, y0 + 2, OAK_HI, INK, 4.6)
    p.rect(x0 + 12, y0 + 10, x1 - 12, 712, mix(OAK_DK, SOOT, 0.3), INK, 2.2)
    for (sx0, sy0, sx1, sy1), col in zip(SPINES, SPINE_COL):
        p.rect(sx0, sy0, sx1, sy1, col, INK, 2.6, r=3)
        p.line([(sx0 + 6, sy0 + 4), (sx0 + 6, sy1 - 4)], mix(col, PAPER_HI, 0.25), 1.6)
        for yy in (sy0 + 52, sy1 - 22):
            p.rect(sx0 + 3, yy, sx1 - 3, yy + 6, BRASS, INK, 1.4)
        p.poly([(sx0, sy1), (sx0 + 18, sy1), (sx0, sy1 - 18)], BRASS, INK, 1.4)
        p.poly([(sx1, sy1), (sx1 - 18, sy1), (sx1, sy1 - 18)], BRASS, INK, 1.4)
    for k in range(3):
        oak_plate(p, 830 + 120 * k, 500, 930 + 120 * k, 526)
    # lower doors
    p.rect(x0 + 12, 720, (x0 + x1) / 2 - 2, y1 - 12, mix(OAK, OAK_DK, 0.25), INK, 2.2)
    p.rect((x0 + x1) / 2 + 2, 720, x1 - 12, y1 - 12, mix(OAK, OAK_DK, 0.25), INK, 2.2)
    for kx in ((x0 + x1) / 2 - 18, (x0 + x1) / 2 + 18):
        p.ell(kx, 772, 6, 6, BRASS_HI, INK, 1.6)


MODEL = (820, 200, 1160, 450)
MB = (846, 380, 1134, 452)          # terminal block
MB_FACE = (858, 388, 1122, 444)     # the shutter face
M_STRIP = (870, 350, 1110, 366)
M_SOCK = [(896, 414), (990, 414), (1084, 414)]
M_HINGE = (990, 340)


def leaf(p, pivot, ang, w=118, h=132, col=BRASS, rule=20):
    cx, cy = pivot
    pts = [(cx - w / 2, cy - h), (cx + w / 2, cy - h), (cx + w / 2, cy), (cx - w / 2, cy)]
    pts = [rot(q, pivot, ang) for q in pts]
    p.poly(pts, col, INK, 2.8)
    k = 1
    while k * rule < h - 10:
        a = rot((cx - w / 2 + 12, cy - h + k * rule), pivot, ang)
        b = rot((cx + w / 2 - 12, cy - h + k * rule), pivot, ang)
        p.line([a, b], BRASS_DK if col == BRASS_LO else BRASS_LO, 1.4)
        k += 1
    a = rot((cx - w / 2 + 6, cy - h + 6), pivot, ang)
    b = rot((cx + w / 2 - 6, cy - h + 6), pivot, ang)
    p.line([a, b], BRASS_HI, 1.6)


def index_model(p):
    """Three brass leaves fanned open like a book over a terminal block under a brass shutter."""
    soft_shadow(p, MB[0], MB[1], MB[2], MB[3], 5, 5, 4, 0.3)
    leaf(p, M_HINGE, -30, col=BRASS_LO)
    leaf(p, M_HINGE, 30, col=BRASS_LO)
    leaf(p, M_HINGE, 0, col=BRASS)
    p.ell(M_HINGE[0], M_HINGE[1], 10, 10, BRASS_HI, INK, 2)
    # faceplate with a paper strip window
    p.rect(MB[0], 336, MB[2], MB[1], BRASS, INK, 2.8, r=3)
    p.rect(*M_STRIP, PAPER_HI, INK, 1.8)
    p.ell(MB[0] + 12, 358, 3.2, 3.2, BRASS_HI, INK, 1.2)
    p.ell(MB[2] - 12, 358, 3.2, 3.2, BRASS_HI, INK, 1.2)
    p.rect(*MB, OAK_DK, INK, 3, r=3)
    p.rect(MB[0] - 6, MB[3] - 4, MB[2] + 6, MB[3] + 6, OAK, INK, 2.4)
    shutter(p, *MB_FACE)


def shutter(p, x0, y0, x1, y1, s=1.0):
    """The brass shutter: horizontal ribs, a hollow circle and a blank plate. No keyhole."""
    p.rect(x0, y0, x1, y1, BRASS, INK, 2.6 * s, r=3 * s)
    hgt = y1 - y0
    k = 1
    while y0 + k * 12 * s < y1 - 4 * s:
        yy = y0 + k * 12 * s
        p.line([(x0 + 6 * s, yy), (x1 - 6 * s, yy)], BRASS_LO, 1.4 * s)
        p.line([(x0 + 6 * s, yy + 1.6 * s), (x1 - 6 * s, yy + 1.6 * s)], BRASS_HI, 0.9 * s)
        k += 1
    cy = (y0 + y1) / 2
    r = hgt * 0.30
    p.ell(x0 + hgt * 0.75, cy, r, r, None, INK, 4.2 * s)          # a hollow engraved ring
    p.ell(x0 + hgt * 0.75, cy, r - 4 * s, r - 4 * s, None, BRASS_HI, 1.6 * s)
    pw = (x1 - x0) * 0.42
    px0 = (x0 + x1) / 2 - pw / 2 + hgt * 0.2
    plate(p, px0, cy - hgt * 0.18, px0 + pw, cy + hgt * 0.18, w=2.2 * s)


SHELF_B = (1206, 450, 1414, 462)
PARCEL = (1236, 330, 1384, 450)


def high_shelf(p):
    x0, y0, x1, y1 = SHELF_B
    for bx in (x0 + 28, x1 - 44):
        p.poly([(bx, y1), (bx + 16, y1), (bx + 16, y1 + 52), (bx + 10, y1 + 52)], BRASS_LO, INK, 2)
        p.line([(bx + 16, y1 + 48), (bx - 18, y1 + 2)], BRASS_LO, 3.6)
    p.rect(x0, y0, x1, y1, OAK, INK, 4)
    p.line([(x0 + 3, y0 + 4), (x1 - 3, y0 + 4)], OAK_HI, 1.4)


def parcel_paper(p, string=True):
    x0, y0, x1, y1 = PARCEL
    soft_shadow(p, x0, y0, x1, y1, 5, 3, 4, 0.3)
    p.rect(x0, y0, x1, y1, KRAFT, INK, 2.8, r=2)
    p.line([(x0 + 4, y0 + 18), (x1 - 4, y0 + 18)], KRAFT_DK, 1.6)
    p.poly([(x0 + 2, y0 + 2), (x0 + 30, y0 + 18), (x0 + 2, y0 + 30)], mix(KRAFT, PAPER, 0.25), KRAFT_DK, 1.4)
    p.poly([(x1 - 2, y0 + 2), (x1 - 30, y0 + 18), (x1 - 2, y0 + 30)], mix(KRAFT, PAPER, 0.25), KRAFT_DK, 1.4)
    # blank paper label
    p.rect(x0 + 18, y1 - 44, x0 + 74, y1 - 14, PAPER_HI, INK, 1.8, r=2)
    if string:
        cx, cy = PARCEL_KNOT
        p.line([(cx, y0 - 1), (cx, y1 + 1)], INK, 4.2)
        p.line([(cx, y0 - 1), (cx, y1 + 1)], STRING, 2.2)
        p.line([(x0 - 1, cy), (x1 + 1, cy)], INK, 4.2)
        p.line([(x0 - 1, cy), (x1 + 1, cy)], STRING, 2.2)
        for sgn in (-1, 1):
            p.ell(cx + sgn * 10, cy - 6, 9, 6, None, INK, 4.0)
            p.ell(cx + sgn * 10, cy - 6, 9, 6, None, STRING, 2.0)
        p.ell(cx, cy, 5, 5, STRING, INK, 1.6)


PARCEL_KNOT = (1318, 384)


def archive_boxes(p):
    """A stack of three archive boxes on the floor: blank brass plates, level lids."""
    rng = rng_for(640)
    y = FLOOR_Y
    for k, (w, h) in enumerate(((176, 78), (164, 72), (170, 70))):
        x0 = 1226 + rng.uniform(-6, 6)
        soft_shadow(p, x0, y - h, x0 + w, y, 5, 4, 4, 0.25)
        p.rect(x0, y - h, x0 + w, y, mix(PAPER, TIMBER, 0.18 + 0.06 * k), INK, 4)
        p.rect(x0 - 3, y - h, x0 + w + 3, y - h + 12, mix(PAPER, TIMBER, 0.3), INK, 2.2)
        oak_plate(p, x0 + w / 2 - 30, y - h + 26, x0 + w / 2 + 30, y - h + 42)
        p.ell(x0 + w / 2, y - 16, 7, 4, None, INK, 1.6)
        y -= h


def paint_view_b(rng, stage=4):
    p = Pen(W, H, rng, PAPER)
    shell(p, rng_for(501), lean=LEAN[stage], ripple=RIPPLE_AMP if stage == 4 else 0.0)
    if stage >= 5:
        damp(p, rng_for(540))
    lamp_pool(p, 700, 230, 300, 170, 0.34)
    chest(p)
    tray(p)
    folder_cabinet(p)
    index_model(p)
    high_shelf(p)
    parcel_paper(p)
    archive_boxes(p)
    pendant(p, 700, 98)
    turn_plate(p)
    if stage >= 5:
        tide_line(p, rng_for(541), keep_out=[(820, 490, 1180, 534)])
    return p


# ----------------------------------------------------------------------------- view B overlays

def vesica(cx, cy, aw, ah, n=60):
    """A pointed lens (mouth shape) with half-width a and half-height b, as top and bottom arcs."""
    a, b = aw / 2.0, ah / 2.0
    R = (a * a + b * b) / (2 * b)
    d = R - b
    top, bot = [], []
    for i in range(n + 1):
        x = -a + 2 * a * i / n
        yy = math.sqrt(max(0.0, R * R - x * x)) - d
        top.append((cx + x, cy - yy))
        bot.append((cx + x, cy + yy))
    return top, bot


def staff_cavity(p):
    """The STAFF drawer withdrawn: the cavity lined with packed card ends, and the drawer front
    let down on its stays below."""
    x0, y0, x1, y1 = STAFF
    p.rect(x0 - 2, y0 - 2, x1 + 2, y1 + 2, OAK_DK, INK, 3)
    p.rect(x0 + 6, y0 + 6, x1 - 6, y1 - 4, mix(PAPER, TIMBER, 0.28), INK, 2.4)
    lay = p.layer()
    x = x0 + 9
    k = 0
    while x < x1 - 8:
        lay.line([(x, y0 + 8), (x, y1 - 6)], mix(PAPER, TIMBER, 0.45 if k % 2 else 0.12), 2.2)
        x += 5.5
        k += 1
    p.put(lay, 0.8)
    p.rect(x0 + 6, y0 + 6, x1 - 6, y0 + 16, STORM, None)
    p.rect(x0 + 6, y0 + 6, x0 + 14, y1 - 4, STORM, None)
    p.rect(x0 + 6, y0 + 6, x1 - 6, y1 - 4, None, INK, 2.4)
    # the let-down front: edge-on lip and its brass stays
    p.rect(x0 - 6, y1 - 2, x1 + 6, y1 + 10, OAK, INK, 2.6)
    p.line([(x0 - 2, y1 + 1), (x1 + 2, y1 + 1)], OAK_HI, 1.4)


def warp_peak(u, pk):
    """0..1 bump over u in -1..1 whose top sits at pk, not at the centre: a lopsided lip."""
    t = (u + 1.0) / 2.0
    tp = min(0.95, max(0.05, (pk + 1.0) / 2.0))
    e = math.log(0.5) / math.log(tp)
    return max(0.0, math.sin(math.pi * t ** e)) ** 0.8


def mouth_outline(cx, cy, aw, ht, hb, tilt, rng=None, n=48, scale=1.0, dy=0.0):
    """The STAFF opening: an asymmetric lip line. The left corner sits higher than the right
    (`tilt`), the upper lip peaks left of centre and the lower lip sags right of it. Returns a
    closed polygon (top left to right, then the bottom back), scaled about the throat."""
    a = aw / 2.0
    top, bot = [], []
    jit = [rng.uniform(-1.0, 1.0) if rng else 0.0 for _ in range(n + 1)]
    for i in range(n + 1):
        u = -1.0 + 2.0 * i / n
        base = cy + dy + tilt * u
        x = cx + u * a * scale
        top.append((x, base - ht * scale * warp_peak(u, -0.22) + jit[i] * 0.8 * scale))
        bot.append((x, base + hb * scale * warp_peak(u, 0.18) - jit[n - i] * 0.8 * scale))
    return top + bot[::-1][1:-1]


THROAT = [mix(STORM_HI, PAPER, 0.18), STORM_HI, STORM, mix(STORM, SOOT, 0.3), mix(STORM, SOOT, 0.55),
          mix(STORM, SOOT, 0.75)]


def aperture(p, aw, ah, riffle=False, lip=0.0, seed=903):
    """The STAFF opening: a dry paper rim, a throat graded ring by ring to deep navy like the
    shelf tunnel, and a ring of index tabs (not teeth) of uneven height, each leaning its own way.
    `lip` lets the lower lip hang that far down past the drawer, over the tray."""
    rng = rng_for(seed)
    cx, cy = STAFF_C
    ht, hb = ah * 0.46, ah * 0.54
    tilt = ah * 0.09
    outline = mouth_outline(cx, cy, aw, ht, hb, tilt, rng)
    rim = mouth_outline(cx, cy, aw + 16, ht + 7, hb + 8 + lip, tilt, None)
    if lip:
        sh = p.layer()
        sh.poly([(x + 3, y + 6) for x, y in rim], SHADOW, None)
        p.put_soft(sh, 4, 0.4)
    p.poly(rim, mix(PAPER, TIMBER, 0.16), INK, 2.4)
    if lip:
        # the overhanging lower lip: a few dry creases where it folds over the tray's edge
        for k in range(4):
            x = cx - aw * 0.3 + k * aw * 0.2
            p.line([(x, cy + hb + 6), (x + 3, cy + hb + lip * 0.8)], mix(PAPER, TIMBER, 0.38), 1.6)
    p.poly(outline, THROAT[0], None)
    # the throat: flat rings, each smaller, dropping toward the far end of the drawer
    for k in range(1, len(THROAT)):
        sc = 1.0 - k * 0.15
        p.poly(mouth_outline(cx, cy, aw, ht, hb, tilt, None, scale=sc, dy=k * ah * 0.025), THROAT[k],
               mix(INK, THROAT[k], 0.3), 1.2)
    # the tabs: index tabs set into the lip, pointing inward, each its own height and lean
    L = [0.0]
    for i in range(1, len(outline) + 1):
        a, b = outline[i - 1], outline[i % len(outline)]
        L.append(L[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    total = L[-1]
    n = 18
    cols = [PAPER_HI, PAPER_HI, ENAMEL, PAPER, PAPER_HI, mix(SEAGLASS_HI, PAPER_HI, 0.4), PAPER_HI, ENAMEL, KRAFT]
    tl_ = p.layer()
    for k in range(n):
        target = (k + 0.5 + rng.uniform(-0.18, 0.18)) * total / n
        i = next(j for j in range(1, len(L)) if L[j] >= target)
        a, b = outline[i - 1], outline[i % len(outline)]
        t = (target - L[i - 1]) / max(1e-6, L[i] - L[i - 1])
        px, py = lerp(a[0], b[0], t), lerp(a[1], b[1], t)
        corner = min(1.0, abs(px - cx) / (aw / 2))
        if corner > 0.9:
            continue
        nx, ny = 0.0, (1.0 if py < cy + tilt * (px - cx) / (aw / 2) else -1.0)
        ln = (ah * 0.17 + 6) * rng.uniform(0.6, 1.3) * (1.0 - 0.6 * corner ** 2)
        ang = math.atan2(ny, nx) + math.radians(rng.uniform(-13, 13))
        if riffle:
            ang += math.radians(-48 if ny > 0 else 48)
        ux, uy = math.cos(ang), math.sin(ang)
        vx, vy = -uy, ux
        hw = rng.uniform(3.6, 5.6)
        sh_ = hw * 0.55                      # the tab's cut shoulders
        pts = [(px - ux * 3 + vx * hw, py - uy * 3 + vy * hw),
               (px + ux * (ln - sh_) + vx * hw, py + uy * (ln - sh_) + vy * hw),
               (px + ux * ln + vx * (hw - sh_), py + uy * ln + vy * (hw - sh_)),
               (px + ux * ln - vx * (hw - sh_), py + uy * ln - vy * (hw - sh_)),
               (px + ux * (ln - sh_) - vx * hw, py + uy * (ln - sh_) - vy * hw),
               (px - ux * 3 - vx * hw, py - uy * 3 - vy * hw)]
        tl_.poly(pts, rng.choice(cols), INK, 1.6)
    p.put(tl_)
    p.line(outline + [outline[0]], INK, 4.0)


def paint_b_staff(rng, aw, ah, riffle=False, lip=0.0):
    p = Pen(W, H, rng)
    staff_cavity(p)
    aperture(p, aw, ah, riffle, lip)
    return p


# ----------------------------------------------------------------------------- stage art: the STAFF slot

BUFF = mix(mix(PAPER_HI, BRASS_HI, 0.30), PAPER, 0.25)    # index-card buff
BUFF_DK = mix(BUFF, TIMBER, 0.25)
SLOT_C = (530, 470)
# width step -> (lens width, lens height, card rows)
SLOT_STEPS = {0: (150, 60, 1), 1: (178, 76, 2), 2: (206, 94, 3)}
SLOT_DARK = [mix(STORM, SOOT, 0.45), mix(STORM, SOOT, 0.62), mix(STORM, SOOT, 0.78), mix(STORM, SOOT, 0.9)]


def staff_front(p):
    """The STAFF drawer front, shut, without its pull: the slot is cut where the pull was."""
    x0, y0, x1, y1 = STAFF
    p.rect(x0 - 2, y0 - 2, x1 + 2, y1 + 2, OAK_DK, INK, 3)
    p.rect(x0 + 4, y0 + 4, x1 - 4, y1 - 4, OAK, INK, 2.6, r=2)
    p.rect(x0 + 14, y0 + 44, x1 - 14, y1 - 14, None, mix(INK, OAK, 0.4), 1.6, r=2)
    p.line([(x0 + 8, y0 + 8), (x1 - 8, y0 + 8)], OAK_HI, 1.6)
    plate(p, *STAFF_PLATE)


def lens_pts(cx, cy, aw, ah, n=64):
    top, bot = vesica(cx, cy, aw, ah, n)
    return top + bot[::-1][1:-1]


def lens_edges(cx, aw, ah, x):
    """The lens's top and bottom y at x (about SLOT_C), or None outside it."""
    a, b = aw / 2.0, ah / 2.0
    R = (a * a + b * b) / (2 * b)
    d = R - b
    u = x - cx
    if abs(u) >= a:
        return None
    yy = math.sqrt(max(0.0, R * R - u * u)) - d
    return SLOT_C[1] - yy, SLOT_C[1] + yy


def card_on_end(p, x, root, tip, w, lean, col, rng, down):
    """One index card on end, front face: a buff slip from `root` (at the slot's edge) to `tip`,
    leaning `lean` px over its length, with a tiny tab at the tip carrying two or three typed
    ink ticks. `down`: the card hangs from the top edge."""
    sgn = 1 if down else -1
    hw = w / 2.0
    pts = [(x - hw, root), (x + hw, root), (x + hw + lean, tip), (x - hw + lean, tip)]
    p.poly(pts, col, INK, 1.4)
    # the tab: a third of the card's width, off-centre, standing proud of the tip
    tw = max(3.0, w * rng.uniform(0.34, 0.46))
    off = rng.choice([-1, 1]) * rng.uniform(0.0, hw - tw / 2.0 - 0.5)
    tx = x + lean + off
    th = rng.uniform(3.2, 4.6)
    tab = [(tx - tw / 2, tip), (tx + tw / 2, tip), (tx + tw / 2 - 0.6, tip + sgn * th),
           (tx - tw / 2 + 0.6, tip + sgn * th)]
    p.poly(tab, mix(col, PAPER_HI, 0.25), INK, 1.1)
    # typed: two or three tiny ticks on the tab, and a typed line across the card's face
    for k in range(rng.choice([2, 3])):
        ty = tip + sgn * (1.4 + k * 0.0)
        tx0 = tx - tw / 2 + 1.0 + k * (tw - 2.0) / 3.0
        p.line([(tx0, ty + sgn * 0.6), (tx0 + 0.9, ty + sgn * 0.6)], mix(INK, col, 0.25), 0.9)
    fy = lerp(root, tip, rng.uniform(0.55, 0.75))
    fl = lean * (fy - root) / max(1e-6, tip - root)
    p.line([(x - hw + 1.6 + fl, fy), (x - hw + 1.6 + fl + w * rng.uniform(0.35, 0.6), fy)],
           mix(INK, col, 0.45), 0.9)


def slot_cards(p, aw, ah, rows, rng, riffle=False):
    """The card rows round the lens, deepest first: each further row set further into the slot,
    smaller, closer-spaced and graded toward the dark."""
    cx = SLOT_C[0]
    for k in range(rows - 1, -1, -1):
        col = mix(BUFF, SLOT_DARK[1], min(0.8, 0.45 * k))
        w = 11.0 - 2.0 * k
        pitch = 12.5 - 2.2 * k
        inset = 9.0 * k + 1.0                   # how far the row's roots sit inside the edge
        length = (ah * 0.2 + 5.0) * (1.0 - 0.17 * k)
        x = cx - aw / 2.0 + pitch * (0.7 + 0.5 * (k % 2))
        while x < cx + aw / 2.0 - pitch * 0.5:
            e = lens_edges(cx, aw, ah, x)
            if e is not None:
                top, bot = e
                half = (bot - top) / 2.0
                if half > inset + length * 0.6:
                    for down in (True, False):
                        ln = length * rng.uniform(0.8, 1.15)
                        lean = rng.uniform(-2.2, 2.2)
                        if riffle:
                            lean += 6.5 if down else 6.5
                        edge = top if down else bot
                        sgn = 1 if down else -1
                        root = edge + sgn * (inset - 6.0)      # starts behind the oak edge
                        tip = edge + sgn * (inset + ln)
                        jit = rng.uniform(-1.6, 1.6)
                        card_on_end(p, x + jit, root, tip, w * rng.uniform(0.9, 1.1), lean, col, rng, down)
            x += pitch * rng.uniform(0.9, 1.12)


def paint_staff_slot(rng, step, riffle=False):
    aw, ah, rows = SLOT_STEPS[step]
    p = Pen(W, H, rng)
    staff_front(p)
    cx, cy = SLOT_C
    lens = lens_pts(cx, cy, aw, ah)
    inner = p.layer()
    # the dark: flat lenses, each smaller and darker, no contour anywhere
    inner.poly(lens, SLOT_DARK[0], None)
    for k in range(1, len(SLOT_DARK)):
        sc = 1.0 - 0.2 * k
        inner.poly(lens_pts(cx, cy, aw * sc, ah * sc), SLOT_DARK[k], None)
    slot_cards(inner, aw, ah, rows, rng_for(960 + step + (10 if riffle else 0)), riffle)
    # the front's cut thickness: a slim oak-dark band just inside the top edge, no outline
    th = inner.layer()
    th.poly(lens, None, mix(OAK_DK, SOOT, 0.35), 3.0)
    inner.put(th, 0.55)
    p.put(inner, mask=poly_mask(lens))
    return p


def paint_staff_shut(rng):
    """Slammed: the slot closed to a seam, a few card tabs pinched in it."""
    aw, ah, _ = SLOT_STEPS[0]
    p = Pen(W, H, rng)
    staff_front(p)
    cx, cy = SLOT_C
    seam = lens_pts(cx, cy, aw, 5.0)
    p.poly(seam, SLOT_DARK[2], None)
    p.line(vesica(cx, cy, aw, 5.0)[0], mix(INK, OAK, 0.2), 1.6)
    r = rng_for(975)
    for x in (cx - 46, cx - 19, cx + 8, cx + 37, cx + 58):
        x += r.uniform(-4, 4)
        w = r.uniform(5.0, 7.0)
        h = r.uniform(3.5, 6.0)
        y = cy + r.choice([-1, 1]) * 1.0
        p.poly([(x - w / 2, y - 1), (x + w / 2, y - 1), (x + w / 2 - 0.8, y + h), (x - w / 2 + 0.8, y + h)],
               BUFF, INK, 1.1)
    return p


def paint_vault_grade(rng):
    """Band 6 on (view A): the back shelving graded toward storm navy, frame by frame, from
    clear at the near flat to deep at the innermost frames, so the run reads deeper than the
    room. Stepped flat bands (the plate's own nested frames), no airbrush; the lit doorway in
    RECESS and the near flat's archive boxes are left untouched."""
    p = Pen(W, H, rng)
    n = 14
    ts = bay_t(n)
    rects = [lerp_rect(SHELF, RECESS, t) for t in ts] + [RECESS]
    for k in range(1, len(rects) - 1):
        a = min(0.78, 0.08 + 0.74 * ((k - 1) / (n - 2)) ** 1.1)
        lay = p.layer(STORM)
        lay.rect(*rects[k], STORM, None, 0)
        p.put(lay, a, mask=band_mask(rects[k], rects[k + 1]))
    # beyond the inner frame's sides the dark keeps going: two thin storm-navy rules either side
    # of the doorway, as if more frames were there than were drawn
    x0, y0, x1, y1 = RECESS
    for k in range(1, 4):
        g = 3 * k
        p.rect(x0 - g, y0 - g, x1 + g, y1 + g * 0.5, None, mix(STORM, SOOT, 0.3), 1.0)
    return p


def paint_b_drawer_open(rng):
    p = Pen(W, H, rng)
    x0, y0, x1, y1 = VENN
    # the cavity: back wall, side cheeks, the dusty floor of the drawer with a clean rectangle
    p.rect(x0 - 2, y0 - 2, x1 + 2, y1 + 2, mix(OAK_DK, SOOT, 0.45), INK, 3)
    p.rect(x0 + 8, y0 + 6, x1 - 8, y0 + 22, mix(OAK_DK, SOOT, 0.2), None)
    p.rect(x0 + 8, y0 + 22, x1 - 8, y0 + 56, DUST, INK, 1.8)
    p.rect(x0 + 52, y0 + 28, x1 - 52, y0 + 50, mix(OAK, OAK_DK, 0.3), mix(INK, OAK, 0.4), 1.2)
    p.rect(x0 + 2, y0 + 2, x0 + 10, y0 + 58, OAK, INK, 1.8)
    p.rect(x1 - 10, y0 + 2, x1 - 2, y0 + 58, OAK, INK, 1.8)
    # the drawer front, pulled out toward us: lower, over the plinth
    fy = y0 + 56
    soft_shadow(p, x0 - 4, fy, x1 + 4, fy + 100, 4, 8, 5, 0.35)
    p.rect(x0 - 4, fy, x1 + 4, fy + 100, OAK, INK, 2.8, r=2)
    p.line([(x0, fy + 4), (x1, fy + 4)], OAK_HI, 1.6)
    sh = p.at(0, fy - y0)
    venn_plate(p)
    pull(p, (x0 + x1) / 2, 762, 14, 9, 6, 2.4)
    p.restore(sh)
    return p


def socket_face(p, cx, cy, r=22, s=1.0):
    p.ell(cx, cy, r + 6 * s, r + 6 * s, BRASS, INK, 2.4 * s)
    p.ell(cx, cy, r, r, SOOT, INK, 2 * s)
    p.ell(cx, cy, r * 0.42, r * 0.42, mix(SOOT, STORM, 0.5), None)
    for a in (0, 120, 240):
        q = (cx + r * 0.65 * math.cos(math.radians(a - 90)), cy + r * 0.65 * math.sin(math.radians(a - 90)))
        p.ell(q[0], q[1], r * 0.12 + 0.6, r * 0.12 + 0.6, STORM, None)


def bridge(p, x0, y0, w, h):
    """The witness bridge: a brass bar with two prongs."""
    s = w / 240.0
    for px in (x0 + 34 * s, x0 + w - 34 * s - 16 * s):
        p.rect(px, y0 + h * 0.42, px + 16 * s, y0 + h - 2, BRASS_LO, INK, 2.0 * s, r=2 * s)
    p.rect(x0 + 2, y0 + 4, x0 + w - 2, y0 + h * 0.5, BRASS, INK, 2.8 * s, r=6 * s)
    p.line([(x0 + 10 * s, y0 + 9 * s), (x0 + w - 10 * s, y0 + 9 * s)], BRASS_HI, 2.4 * s)
    for sx in (x0 + 16 * s, x0 + w - 16 * s):
        screw(p, sx, y0 + h * 0.28, 4.4 * s)


def model_terminals(p, with_bridge=True, stamp=False):
    p.rect(*MB_FACE, EBONITE, INK, 2.6, r=3)
    for k in range(3):
        cx, cy = M_SOCK[k]
        socket_face(p, cx, cy + 9, 13)
    sx = M_SOCK[2][0]
    p.rect(sx - 36, 391, sx + 36, 405, BRASS_LO, INK, 1.8, r=3)
    p.rect(sx - 30, 395, sx + 30, 401, SLOT, None)
    if with_bridge:
        bridge(p, sx - 42, 384, 84, 28)
    if stamp:
        stamp_frame(p, M_STRIP[2] - 66, M_STRIP[1] - 4, M_STRIP[2] - 6, M_STRIP[3] + 4, SEAGLASS, rng_for(77), 2.0)


def paint_b_terminals(rng, with_bridge):
    p = Pen(W, H, rng)
    model_terminals(p, with_bridge, stamp=not with_bridge)
    return p


def paint_b_string_loose(rng):
    p = Pen(W, H, rng)
    parcel_paper(p, string=False)
    x0, y0, x1, y1 = PARCEL
    cx, cy = PARCEL_KNOT
    lay = p.layer()
    for pts in (bezier((cx - 2, y0 - 2), (cx - 30, cy - 10), (cx - 6, cy + 2)),
                bezier((cx - 6, cy + 2), (cx + 30, cy + 40), (cx + 8, y1 + 1)),
                bezier((x0 + 10, cy + 6), (cx - 20, cy + 26), (cx + 2, cy + 8)),
                bezier((cx + 2, cy + 8), (x1 - 4, cy - 14), (x1 + 6, cy + 30)),
                bezier((x1 + 6, cy + 30), (x1 + 20, y1 + 10), (x1 - 8, y1 + 54))):
        lay.line(pts, INK, 4.0)
        lay.line(pts, STRING, 2.0)
    p.put(lay)
    return p


def paint_b_photo_unwrapped(rng):
    p = Pen(W, H, rng)
    x0, y0, x1, y1 = PARCEL
    soft_shadow(p, x0, y0, x1, y1, 5, 3, 4, 0.3)
    # the paper folded back: flaps spread out to each side and below the photograph
    p.poly([(x0 + 4, y0 + 6), (x0 - 40, y0 + 22), (x0 - 34, y1 - 4), (x0 + 4, y1)], KRAFT, INK, 2.4)
    p.poly([(x1 - 4, y0 + 6), (x1 + 34, y0 + 30), (x1 + 26, y1 - 2), (x1 - 4, y1)], KRAFT_DK, INK, 2.4)
    p.rect(x0, y0, x1, y1, KRAFT, INK, 2.6)
    p.line([(x0 - 30, y0 + 60), (x0 + 2, y0 + 64)], KRAFT_DK, 1.4)
    # the photograph
    px0, py0, px1, py1 = x0 + 12, y0 + 10, x1 - 12, y1 - 8
    p.rect(px0, py0, px1, py1, PAPER_HI, INK, 2.2)
    ix0, iy0, ix1, iy1 = px0 + 7, py0 + 7, px1 - 7, py1 - 7
    # the only coloured memory in the room: a faint sea-glass cast
    p.rect(ix0, iy0, ix1, iy1, mix(mix(SEPIA, PAPER, 0.25), SEAGLASS_HI, 0.45), None)
    hy = iy0 + (iy1 - iy0) * 0.48
    p.rect(ix0, hy, ix1, iy1, mix(mix(SEPIA, SEPIA_DK, 0.2), SEAGLASS, 0.5), None)
    # the pale jetty running out level, with its posts
    jy = iy0 + (iy1 - iy0) * 0.70
    p.rect(ix0, jy, ix1, jy + 7, mix(PAPER_HI, SEPIA, 0.15), None)
    for x in range(int(ix0) + 8, int(ix1), 22):
        p.rect(x, jy + 7, x + 3, iy1, mix(PAPER_HI, SEPIA, 0.35), None)
    # a woman and a small boy, stark silhouettes, standing on the planks
    wx, by = ix0 + (ix1 - ix0) * 0.40, jy
    p.ell(wx, by - 42, 5, 6, SEPIA_DK, None)
    p.poly([(wx - 5, by - 36), (wx + 5, by - 36), (wx + 11, by), (wx - 11, by)], SEPIA_DK, None)
    bx = wx + 20
    p.ell(bx, by - 22, 3.6, 4, SEPIA_DK, None)
    p.poly([(bx - 3.5, by - 18), (bx + 3.5, by - 18), (bx + 4.5, by - 6), (bx - 4.5, by - 6)], SEPIA_DK, None)
    p.rect(bx - 3.5, by - 7, bx - 1, by, SEPIA_DK, None)
    p.rect(bx + 1, by - 7, bx + 3.5, by, SEPIA_DK, None)
    p.line([(wx + 6, by - 28), (bx - 3, by - 16)], SEPIA_DK, 2.2)
    p.rect(ix0, iy0, ix1, iy1, None, mix(INK, SEPIA, 0.4), 1.4)
    return p



# ----------------------------------------------------------------------------- shared mechanisms

def stamp_frame(p, x0, y0, x1, y1, col, rng, w=3.0, style="closed"):
    """A rubber-stamp impression frame, blank inside: slightly uneven ink edges."""
    lay = p.layer()

    def wob(a, b, n=9, amp=1.4):
        pts = []
        for i in range(n + 1):
            t = i / n
            pts.append((lerp(a[0], b[0], t) + rng.uniform(-amp, amp), lerp(a[1], b[1], t) + rng.uniform(-amp, amp)))
        return pts

    if style == "closed":
        for inset, wd in ((0, w * 1.4), (w * 3.2, w * 0.7)):
            a, b, c, d = (x0 + inset, y0 + inset), (x1 - inset, y0 + inset), (x1 - inset, y1 - inset), (x0 + inset, y1 - inset)
            lay.line(wob(a, b) + wob(b, c)[1:] + wob(c, d)[1:] + wob(d, a)[1:], col, wd)
    else:
        r = (y1 - y0) * 0.22
        lay.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, None, col, w * 1.9, r=r)
        # starved ink: a few bites out of the edge
        for _ in range(7):
            ex = rng.uniform(x0 + r, x1 - r)
            ey = rng.choice((y0 + 1, y1 - 1))
            lay.ell(ex, ey, rng.uniform(1.5, 3.5), rng.uniform(1.2, 2.4), (0, 0, 0, 0), None)
    p.put(lay, 0.92)
    if style != "closed":
        # bites are cut by redrawing the paper-less holes as transparent
        er = p.layer()
        for _ in range(6):
            ex = rng.uniform(x0 + 10, x1 - 10)
            ey = rng.choice((y0 + 1.5, y1 - 1.5))
            er.ell(ex, ey, rng.uniform(1.6, 3.2), rng.uniform(1.0, 1.8), (255, 255, 255), None)
        a = p.im.getchannel("A")
        p.im.putalpha(ImageChops.subtract(a, er.im.getchannel("A")))


def push_key(p, x0, y0, w, h, down=False, cap=BRASS):
    """A brass push key, front elevation: a bezel collar and a cap with a blank enamel plate.
    Pressed: the cap sits lower in the collar and the collar's shadow closes over it; the pressed
    sprite carries the oak key bed behind it so it covers the raised cap."""
    if down:
        p.rect(x0 + 10, y0 + 2, x0 + w - 10, y0 + h * 0.6, OAK, None)
    soft_shadow(p, x0 + 6, y0 + h * 0.5, x0 + w - 6, y0 + h - 2, 3, 5, 4, 0.35)
    p.rect(x0 + 2, y0 + h * 0.56, x0 + w - 2, y0 + h - 2, BRASS_LO, INK, 2.6, r=6)
    p.line([(x0 + 8, y0 + h * 0.56 + 5), (x0 + w - 8, y0 + h * 0.56 + 5)], BRASS, 1.6)
    dy = h * 0.17 if down else 0.0
    cx0, cx1 = x0 + 14, x0 + w - 14
    cy0, cy1 = y0 + 6 + dy, y0 + h * 0.70 + dy * 0.4
    p.rect(cx0, cy0, cx1, cy1, cap, INK, 2.8, r=8)
    if not down:
        p.line([(cx0 + 8, cy0 + 5), (cx1 - 8, cy0 + 5)], BRASS_HI, 2.2)
    else:
        sh = p.layer()
        sh.rect(cx0 + 2, cy0 + 2, cx1 - 2, cy0 + 12, SHADOW, None, r=6)
        p.put_soft(sh, 2, 0.35)
    plate(p, cx0 + 14, cy0 + 12, cx1 - 14, cy1 - 12, w=2.0)
    p.rect(x0 + 2, y0 + h * 0.70 + dy * 0.4 - 1, x0 + w - 2, y0 + h * 0.70 + dy * 0.4 + 7, BRASS, INK, 2.2, r=3)


def lever(p, x0, y0, down=False):
    """TRAINING RELEASE lever in a 120x170 box: pivot boss, arm and ball knob."""
    cx, cy = x0 + 60, y0 + 85
    ty = y0 + 150 if down else y0 + 20
    p.rect(cx - 9, min(cy, ty), cx + 9, max(cy, ty), BRASS, INK, 2.6, r=4)
    p.line([(cx - 4, min(cy, ty) + 6), (cx - 4, max(cy, ty) - 6)], BRASS_HI, 2)
    p.ell(cx, ty, 17, 17, EBONITE, INK, 2.6)
    p.ell(cx - 5, ty - 5, 5, 4, mix(EBONITE, PAPER_HI, 0.35), None)
    p.ell(cx, cy, 24, 24, BRASS_LO, INK, 2.6)
    p.ell(cx, cy, 13, 13, BRASS_HI, INK, 1.8)
    screw(p, cx, cy, 5)


def card_shape(p, x0, y0, x1, y1, ruled=10, name_line=True):
    p.rect(x0, y0, x1, y1, PAPER_HI, INK, 2.2, r=3)
    lay = p.layer()
    y = y0 + (y1 - y0) * 0.42
    while y < y1 - 8:
        lay.line([(x0 + 10, y), (x1 - 10, y)], SEAGLASS, 1.2)
        y += ruled
    p.put(lay, 0.6)
    if name_line:
        p.line([(x0 + 10, y0 + (y1 - y0) * 0.30), (x1 - 10, y0 + (y1 - y0) * 0.30)], INK, 1.8)
    p.rect(x1 - 26, y0 + 8, x1 - 10, y0 + 22, None, INK, 1.4)


def trace(p, x0, x1, y, amp, rng, col=INK, w=2.2, waves=4):
    ph = [rng.uniform(0, 6.283) for _ in range(waves)]
    fr = [rng.uniform(0.03, 0.09) * (k + 1) for k in range(waves)]
    pts = []
    x = x0
    while x <= x1:
        pts.append((x, y + sum(math.sin(x * fr[k] + ph[k]) / (k + 1) for k in range(waves)) * amp * 0.55))
        x += 2
    p.line(pts, col, w)


def bearing(p, cx, cy, r, s=1.0, col=INK):
    """A bearing diagram: hollow circle, radial bearing ticks, one long bearing line, a bracket."""
    p.ell(cx, cy, r, r, None, col, 2.6 * s)
    for k in range(12):
        a = math.radians(k * 30)
        r0, r1 = r + 4 * s, r + (14 if k % 3 == 0 else 8) * s
        p.line([(cx + r0 * math.cos(a), cy + r0 * math.sin(a)), (cx + r1 * math.cos(a), cy + r1 * math.sin(a))],
               col, 1.6 * s)
    a = math.radians(-38)
    p.line([(cx, cy), (cx + (r + 40 * s) * math.cos(a), cy + (r + 40 * s) * math.sin(a))], col, 2.2 * s)
    bx = cx + r + 30 * s
    p.line([(bx, cy - r), (bx + 10 * s, cy - r), (bx + 10 * s, cy + r), (bx, cy + r)], col, 2.2 * s)


# ----------------------------------------------------------------------------- close-up: contact table

C_SLOTS = [(104 + 320 * i, 190, 384 + 320 * i, 550) for i in range(4)]
C_RAIL = (104, 556, 1344, 620)
C_RESTS = [(230 + 260 * i, 700, 430 + 260 * i, 900) for i in range(4)]
C_GUIDE = (1344, 320, 1428, 450)


def paint_c_contact(rng):
    p = Pen(W, H, rng, WALLPAPER)
    lay = p.layer()
    x = 8
    while x < W:
        lay.rect(x, 0, x + 12, 90, WALL_STRIPE, None)
        x += 64
    p.put(lay, 0.55)
    # the lightbox case and its lit glass
    soft_shadow(p, 24, 70, 1440, 680, 8, 10, 8, 0.3, r=10)
    p.rect(24, 70, 1440, 680, OAK_DK, INK, 3.2, r=10)
    p.rect(34, 80, 1430, 92, OAK, None, r=4)
    p.rect(64, 116, 1340, 640, GLASS_LIT, INK, 2.6)
    glow = p.layer((255, 255, 255))
    glow.ell(702, 360, 560, 220, (255, 255, 255), None)
    p.put_soft(glow, 120, 0.22)
    for k, (x0, y0, x1, y1) in enumerate(C_SLOTS):
        cx = (x0 + x1) / 2
        plate(p, cx - 40, 148, cx + 40, 176)
        p.rect(x0 - 8, y0 - 8, x1 + 8, y1 + 8, mix(GLASS_LIT, PAPER, 0.6), INK, 2.2)
        p.rect(x0, y0, x1, y1, mix(GLASS_LIT, PAPER, 0.35), None)
        fr = p.layer()
        for j in range(-20, 30):
            fr.line([(x0 + j * 16, y1), (x0 + j * 16 + (y1 - y0) * 0.6, y0)], PAPER, 2)
        p.put(fr, 0.5, mask=rect_mask([(x0, y0, x1, y1)]))
        p.rect(x0, y0, x1, y0 + 8, mix(STORM, GLASS_LIT, 0.45), None)
        p.rect(x0, y0, x0 + 8, y1, mix(STORM, GLASS_LIT, 0.45), None)
        p.rect(x0, y0, x1, y1, None, INK, 2.4)
        # registration crosses at the outer corners (shapes, not glyphs)
        for rx, ry in ((x0 - 18, y1 + 2), (x1 + 18, y1 + 2)):
            p.line([(rx - 7, ry), (rx + 7, ry)], STORM, 1.6)
            p.line([(rx, ry - 7), (rx, ry + 7)], STORM, 1.6)
            p.ell(rx, ry, 4, 4, None, STORM, 1.2)
        for cxx, cyy in ((x0 - 1, y0 - 1), (x1 + 1, y0 - 1)):
            p.poly([(cxx - 10 if cxx > cx else cxx, cyy), (cxx + 10 if cxx < cx else cxx, cyy),
                    (cxx, cyy + 10)], BRASS_HI, INK, 1.4)
    # the clamp rail
    x0, y0, x1, y1 = C_RAIL
    p.rect(x0 - 8, y0, x1 + 8, y1, BRASS, INK, 3, r=4)
    p.line([(x0, y0 + 6), (x1, y0 + 6)], BRASS_HI, 2.2)
    p.rect(x0 + 6, y0 + 22, x1 - 6, y0 + 34, BRASS_LO, INK, 2.0, r=3)
    for k in range(9):
        screw(p, x0 + 12 + k * (x1 - x0 - 24) / 8, y1 - 14, 5)
    # the pull-tab guide on the right stile
    gx0, gy0, gx1, gy1 = C_GUIDE
    p.rect(gx0, gy0, gx1, gy1, BRASS, INK, 2.8, r=4)
    p.rect(gx0 + 10, gy0 + 16, gx1 - 10, gy1 - 16, SLOT, INK, 2.0, r=3)
    for y in (gy0 + 8, gy1 - 8):
        screw(p, gx0 + 14, y, 3.4)
        screw(p, gx1 - 14, y, 3.4)
    # the desk and the felt rest tray
    p.rect(-4, 680, W + 4, 712, OAK_HI, INK, 3)
    p.line([(-4, 686), (W + 4, 686)], mix(OAK_HI, PAPER, 0.35), 1.6)
    p.rect(-4, 712, W + 4, H + 4, OAK, INK, 2.4)
    p.rect(-4, 950, W + 4, H + 4, OAK_DK, INK, 2.6)
    soft_shadow(p, 200, 690, 1240, 924, 5, 7, 5, 0.32)
    p.rect(200, 690, 1240, 924, OAK_DK, INK, 3, r=4)
    p.rect(214, 696, 1226, 912, FELT, INK, 2.2)
    for x0, y0, x1, y1 in C_RESTS:
        p.rect(x0, y0, x1, y1, FELT_HI, INK, 2.2, r=4)
        p.rect(x0 + 10, y0 + 10, x1 - 10, y1 - 10, None, mix(FELT, INK, 0.4), 1.4, r=3)
        for cxx, cyy in ((x0 + 6, y0 + 6), (x1 - 6, y0 + 6), (x0 + 6, y1 - 6), (x1 - 6, y1 - 6)):
            p.ell(cxx, cyy, 4, 4, BRASS_HI, INK, 1.2)
    return p


def paint_c_panel(rng, lit, omit_last=False):
    p = Pen(280, 360, rng)
    p.rect(0, 0, 280, 300, SEPIA, None)
    p.rect(0, 0, 280, 92, SEPIA_HI, None)
    p.line([(0, 92), (280, 92)], mix(SEPIA, SEPIA_DK, 0.5), 1.4)
    p.rect(0, 262, 280, 300, mix(SEPIA, SEPIA_DK, 0.25), None)
    p.line([(0, 262), (280, 262)], mix(SEPIA, SEPIA_DK, 0.6), 1.6)
    # the wall clock behind the staff: ticks, no hands
    cx, cy = 56, 52
    p.ell(cx, cy, 32, 32, mix(PAPER_HI, SEPIA, 0.35), SEPIA_DK, 2.4)
    for k in range(12):
        a = math.radians(k * 30)
        p.line([(cx + 24 * math.sin(a), cy - 24 * math.cos(a)), (cx + 29 * math.sin(a), cy - 29 * math.cos(a))],
               SEPIA_DK, 2.2 if k % 3 == 0 else 1.2)
    p.ell(cx, cy, 2.2, 2.2, SEPIA_DK, None)
    # the blank letter plate
    p.rect(212, 18, 260, 50, mix(PAPER_HI, SEPIA, 0.2), SEPIA_DK, 2.0, r=2)
    # the chair lamps
    p.line([(8, 104), (272, 104)], SEPIA_DK, 1.6)
    for k in range(8):
        lx = 28 + 32 * k
        p.line([(lx, 104), (lx, 114)], SEPIA_DK, 1.2)
        p.poly([(lx - 5, 114), (lx + 5, 114), (lx + 10, 124), (lx - 10, 124)], SEPIA_DK, None)
        if k < lit:
            g = p.layer(AMBER)
            g.ell(lx, 130, 13, 11, AMBER, None)
            p.put_soft(g, 5, 0.55)
            p.ell(lx, 130, 6.5, 6.5, AMBER, mix(INK, SEPIA_DK, 0.4), 1.2)
            p.ell(lx - 1.5, 128.5, 2.4, 2.4, PAPER_HI, None)
        else:
            p.ell(lx, 130, 6.5, 6.5, mix(SEPIA_DK, SOOT, 0.25), mix(INK, SEPIA_DK, 0.4), 1.2)
    # chairs and the retouched blanks
    for k in range(8):
        cx = 28 + 32 * k
        chair(p, cx, 226, 0.9)
    for k in range(8):
        if omit_last and k == 7:
            continue
        sitter_blank(p, 28 + 32 * k - 20, 160, 1.0, "front", soft=0.8)
    # the film edge: sprockets and four blank number cells
    p.rect(0, 300, 280, 360, mix(SOOT, STORM, 0.3), None)
    for x in range(6, 280, 14):
        p.rect(x, 304, x + 8, 311, mix(PAPER, SEPIA, 0.3), None, r=1.5)
        p.rect(x, 349, x + 8, 356, mix(PAPER, SEPIA, 0.3), None, r=1.5)
    for x in (20, 85, 150, 215):
        p.rect(x, 318, x + 50, 342, mix(PAPER_HI, SEPIA, 0.1), None)
    p.rect(0, 0, 280, 360, None, INK, 2.0)
    return p


def paint_c_blank(rng, pose):
    """The last blank on panel C, at its painted size. t0 faces us like the other seven; t1 is half
    round, the dark of the back of the head already showing; t2 has turned away: the one dark
    figure among eight paper-white blanks, readable from across the room."""
    p = Pen(40, 60, rng)
    if pose == "away":
        back_of_head(p, 0, 0, 1.0)
        return p
    sitter_blank(p, 0, 0, 1.0, pose, soft=0.8)
    if pose == "three":
        lay = p.layer()
        lay.ell(23.5, 13.6, 9.0, 11.4, HAIR, None)
        lay.poly([(19, 20), (28, 20), (27.5, 31), (20, 31)], HAIR, None)
        lay.poly([(21, 31), (32, 31.5), (36, 38), (37, 60), (24, 60)], COAT, None)
        p.put(lay, 0.82)
    return p


def paint_c_cover(rng):
    p = Pen(1324, 130, rng)
    p.rect(0, 10, 1240, 120, STORM, INK, 3)
    p.line([(4, 16), (1236, 16)], STORM_HI, 2)
    p.line([(4, 112), (1236, 112)], STORM_DK, 2)
    for x in (24, 330, 650, 970, 1216):
        p.ell(x, 30, 6, 6, BRASS_HI, INK, 1.6)
        p.ell(x, 100, 6, 6, BRASS_HI, INK, 1.6)
    p.rect(1236, 0, 1324, 130, PAPER, INK, 2.6, r=6)
    p.line([(1240, 6), (1240, 124)], mix(PAPER, TIMBER, 0.3), 1.6)
    p.ell(1282, 65, 13, 13, mix(PAPER, TIMBER, 0.3), INK, 2.2)
    p.ell(1282, 65, 7, 7, (0, 0, 0, 0), None)
    return p


def paint_c_clamp(rng):
    p = Pen(1240, 48, rng)
    for k in range(4):
        for dx in (60, 220):
            x = k * 320 + dx
            p.rect(x - 24, 4, x + 24, 44, BRASS, INK, 2.4, r=4)
            p.line([(x - 18, 9), (x + 18, 9)], BRASS_HI, 1.8)
            p.rect(x - 14, 22, x + 14, 30, BRASS_LO, INK, 1.4, r=2)
            p.arc(x, 4, 14, 10, 180, 360, BRASS_LO, 3.6)
    return p


def paint_c_reflection(rng):
    p = Pen(W, H, rng)
    lay = p.layer(STORM)
    # Venn: a tall standing man in a long coat, apart from the chairs
    cx = 1190
    lay.ell(cx, 182, 19, 24, STORM, None)
    lay.rect(cx - 9, 200, cx + 9, 222, STORM, None)
    lay.poly([(cx - 46, 232), (cx - 18, 216), (cx + 18, 216), (cx + 46, 232), (cx + 54, 330), (cx + 66, 556),
              (cx - 66, 556), (cx - 54, 330)], STORM, None)
    # the empty witness station: an empty chair behind the camera, the OBSERVER plate on its
    # back rail: the same hollow circle as the model's shutter
    sx, seat = 660, 420
    lay.rect(sx - 78, 236, sx - 62, seat, STORM, None)           # back posts
    lay.rect(sx + 62, 236, sx + 78, seat, STORM, None)
    lay.rect(sx - 78, 236, sx + 78, 262, STORM, None)            # top rail
    lay.rect(sx - 78, 372, sx + 78, 384, STORM, None)            # lower rail
    lay.rect(sx - 86, seat, sx + 86, seat + 18, STORM, None)     # seat
    for lx in (sx - 84, sx + 70):
        lay.rect(lx, seat + 18, lx + 14, 556, STORM, None)
    lay.rect(sx - 76, 500, sx + 76, 510, STORM, None)            # stretcher
    lay.ell(sx, 318, 40, 40, None, STORM, 11)                    # the hollow-circle plate
    p.put_soft(lay, 1.4, 0.30)
    return p


def paint_c_rec_frame(rng):
    p = Pen(220, 160, rng)
    p.rect(2, 2, 218, 158, BRASS, INK, 2.8, r=5)
    p.line([(8, 8), (212, 8)], BRASS_HI, 1.8)
    r = rng_for(705)
    for k in range(3):
        y0 = 18 + k * 46
        p.rect(14, y0, 206, y0 + 36, PAPER_HI, INK, 1.8)
        trace(p, 20, 200, y0 + 18, 12, r, INK, 1.8)
    for x, y in ((8, 8), (212, 8), (8, 152), (212, 152)):
        screw(p, x, y, 3)
    return p


def paint_c_rec_strip(rng):
    p = Pen(260, 90, rng)
    p.rect(2, 6, 258, 84, PAPER_HI, INK, 2.2)
    for x in range(12, 252, 16):
        p.ell(x, 14, 2.6, 2.6, mix(PAPER, TIMBER, 0.35), None)
        p.ell(x, 76, 2.6, 2.6, mix(PAPER, TIMBER, 0.35), None)
    p.line([(18, 45), (242, 45)], SEAGLASS, 1.4)
    p.ell(96, 45, 16, 16, None, INK, 2.6)
    p.line([(96, 45), (210, 26)], INK, 2.2)
    p.line([(204, 22), (214, 22), (214, 30)], INK, 1.8)
    return p


def paint_c_rec_card(rng):
    p = Pen(200, 130, rng)
    card_shape(p, 2, 2, 198, 128)
    return p


def paint_c_leaf_closed(rng):
    p = Pen(360, 400, rng)
    col = OAK
    p.rect(2, 2, 358, 398, col, INK, 5, r=4)
    for x in (92, 180, 268):
        p.line([(x, 8), (x, 392)], mix(INK, OAK, 0.35), 1.8)
        p.line([(x + 3, 8), (x + 3, 392)], OAK_HI, 1.0)
    p.line([(10, 10), (10, 390)], mix(col, PAPER_HI, 0.25), 2)
    p.rect(14, 14, 346, 386, None, mix(INK, col, 0.4), 1.6, r=3)
    for cx, cy, a in ((2, 2, 0), (358, 2, 90), (358, 398, 180), (2, 398, 270)):
        pts = [rot(q, (cx, cy), a) for q in [(cx, cy), (cx + 30, cy), (cx, cy + 30)]]
        p.poly(pts, BRASS, INK, 1.6)
    plate(p, 110, 18, 250, 44)
    # the clasp
    p.rect(320, 176, 358, 224, BRASS, INK, 2.4, r=4)
    p.ell(338, 200, 7, 7, BRASS_LO, INK, 1.6)
    return p


def paint_c_index_bar(rng):
    p = Pen(1240, 60, rng)
    p.rect(14, 10, 1226, 50, BRASS, INK, 3, r=6)
    p.line([(22, 16), (1218, 16)], BRASS_HI, 2.4)
    p.line([(22, 44), (1218, 44)], BRASS_LO, 2)
    for x in (4, 1204):
        p.rect(x, 2, x + 32, 58, BRASS_LO, INK, 2.6, r=6)
        screw(p, x + 16, 30, 6)
    for k in range(1, 12):
        rivet(p, 14 + k * 101, 30, 4, BRASS_HI)
    return p


# ----------------------------------------------------------------------------- close-up: folders

C_POCKETS = [(110, 190, 470, 590), (544, 190, 904, 590), (978, 190, 1338, 590)]
C_LIDCARD = (380, 96, 1070, 176)
C_CMP = (110, 640, 670, 800)
C_RESULT = (110, 820, 670, 890)
C_DATEWIN = [(720, 694, 840, 790), (860, 694, 980, 790), (1000, 694, 1150, 790)]
C_COMPARE = (1180, 626, 1380, 736)
C_RELEASE = (1160, 760, 1420, 910)


def pocket(p, k, rng):
    x0, y0, x1, y1 = C_POCKETS[k]
    col = SPINE_COL[k]
    soft_shadow(p, x0, y0, x1, y1, 5, 6, 5, 0.3)
    p.rect(x0, y0, x1, y1, col, INK, 3, r=4)
    p.rect(x0 + 14, y0 + 46, x1 - 14, y1 - 12, PAPER, INK, 2.2)
    plate(p, x0 + 90, y0 + 10, x1 - 90, y0 + 36)
    cx = (x0 + x1) / 2
    ey = y0 + 120
    if k == 0:
        trace(p, x0 + 44, x1 - 44, ey, 34, rng, INK, 3.0, waves=3)
        p.line([(x0 + 40, ey + 40), (x1 - 40, ey + 40)], SEAGLASS, 1.4)
    elif k == 1:
        bearing(p, cx - 30, ey, 34)
    else:
        card_shape(p, cx - 80, ey - 52, cx + 80, ey + 52, ruled=12)
    # the sleeve: a deeper pocket mouth with a thumb cut
    sy = y0 + 210
    p.poly([(x0 + 14, sy)] + [(cx + 44 * math.cos(math.radians(a)), sy + 20 * math.sin(math.radians(a)))
                              for a in range(180, -1, -10)][::-1][::-1] + [(x1 - 14, sy), (x1 - 14, y1 - 12),
                                                                           (x0 + 14, y1 - 12)],
           mix(PAPER, TIMBER, 0.18), INK, 2.2)


def oak_boards(p, x0, y0, x1, y1, col, pitch=120, rng=None):
    """The cabinet's own wood: level oak boards with navy ink joints and a top highlight."""
    p.rect(x0, y0, x1, y1, col, INK, 3)
    x = x0 + pitch
    while x < x1 - 20:
        p.line([(x, y0 + 2), (x, y1 - 2)], INK, 2.4)
        p.line([(x + 3, y0 + 3), (x + 3, y1 - 3)], mix(col, PAPER, 0.18), 1.2)
        x += pitch + (rng.uniform(-14, 14) if rng else 0)


def paint_c_folders(rng):
    p = Pen(W, H, rng, OAK_DK)
    # the raised lid's inner face and the blank protocol card
    p.rect(40, -10, 1408, 182, OAK, INK, 3, r=6)
    p.rect(60, 10, 1388, 170, None, mix(INK, OAK, 0.4), 1.8, r=4)
    soft_shadow(p, *C_LIDCARD, 4, 6, 4, 0.3)
    p.rect(*C_LIDCARD, PAPER_HI, INK, 2.4, r=2)
    for x in (C_LIDCARD[0] + 14, C_LIDCARD[2] - 14):
        p.ell(x, C_LIDCARD[1] + 12, 5, 5, BRASS_HI, INK, 1.6)
    p.rect(40, 176, 1408, 188, BRASS, INK, 2.4)
    for x in range(70, 1400, 60):
        p.line([(x, 178), (x, 186)], BRASS_LO, 1.4)
    # the cabinet's interior: its own dark oak boards, joined in navy ink
    oak_boards(p, -4, 188, W + 4, 612, mix(OAK_DK, SOOT, 0.25), 136, rng_for(716))
    r = rng_for(715)
    for k in range(3):
        pocket(p, k, r)
    # the front shelf
    p.rect(-4, 624, W + 4, H + 4, OAK, INK, 3)
    for x0, x1 in ((24, 690), (690, 1440)):
        p.rect(x0, 640 if x0 > 30 else 632, x1 - 6, 1060, mix(OAK, OAK_DK, 0.22), INK, 2.6, r=3)
        p.line([(x0 + 6, 646), (x1 - 12, 646)], OAK_HI, 1.6)
    p.rect(-4, 1060, W + 4, H + 4, OAK_DK, INK, 3)
    p.rect(-4, 606, W + 4, 626, OAK_HI, INK, 4)
    p.line([(-4, 611), (W + 4, 611)], mix(OAK_HI, PAPER, 0.35), 1.6)
    # comparison tray and result window
    x0, y0, x1, y1 = C_CMP
    soft_shadow(p, x0, y0, x1, y1, 4, 6, 4, 0.3)
    p.rect(x0, y0, x1, y1, OAK_DK, INK, 3, r=4)
    p.rect(x0 + 12, y0 + 12, x1 - 12, y1 - 12, FELT, INK, 2)
    x0, y0, x1, y1 = C_RESULT
    p.rect(x0, y0, x1, y1, BRASS, INK, 3, r=4)
    p.rect(x0 + 10, y0 + 10, x1 - 10, y1 - 10, PAPER_HI, INK, 2)
    # the date dial housing: three windows, knurled buttons above and below
    soft_shadow(p, 704, 612, 1166, 874, 5, 6, 5, 0.3)
    p.rect(704, 612, 1166, 874, BRASS, INK, 3, r=8)
    p.rect(712, 620, 1158, 866, None, BRASS_LO, 1.6, r=6)
    for wx0, wy0, wx1, wy1 in C_DATEWIN:
        p.rect(wx0 - 5, wy0 - 5, wx1 + 5, wy1 + 5, BRASS_LO, INK, 2.2, r=3)
        p.rect(wx0, wy0, wx1, wy1, PAPER_HI, INK, 2)
        p.rect(wx0, wy0, wx1, wy0 + 10, mix(PAPER, TIMBER, 0.35), None)
        p.rect(wx0, wy1 - 10, wx1, wy1, mix(PAPER, TIMBER, 0.35), None)
        p.rect(wx0, wy0, wx1, wy1, None, INK, 2)
        cx = (wx0 + wx1) / 2
        for by, up in ((658, True), (828, False)):
            p.ell(cx, by, 30, 26, BRASS_LO, INK, 2.4)
            p.ell(cx, by - 3, 26, 21, BRASS_HI, INK, 2.0)
            for j in range(-3, 4):
                p.line([(cx + j * 6, by - 18), (cx + j * 6, by + 12)], BRASS_LO, 1.2)
            tip = by - 9 if up else by + 7
            base = by + 5 if up else by - 9
            p.poly([(cx - 8, base), (cx + 8, base), (cx, tip)], BRASS_LO, INK, 1.2)
    push_key(p, *C_COMPARE[:2], 200, 110)
    # the release lever housing: printed panel above, slot below (the view draws the lever)
    x0, y0, x1, y1 = C_RELEASE
    soft_shadow(p, x0, y0, x1, y1, 4, 6, 4, 0.3)
    p.rect(x0, y0, x1, y1, BRASS_LO, INK, 3, r=6)
    cx = (x0 + x1) / 2
    # two printed plates, one either side of the lever's throw, clear of the knob
    p.rect(x0 + 8, y0 + 8, cx - 30, y0 + 48, PAPER_HI, INK, 2)
    p.rect(cx + 30, y0 + 8, x1 - 8, y0 + 48, PAPER_HI, INK, 2)
    p.rect(cx - 12, y0 + 64, cx + 12, y1 - 12, SLOT, INK, 2, r=6)
    return p


# ----------------------------------------------------------------------------- close-up: the model

CM_FACE = (220, 96, 1230, 206)
CM_MIRROR = (270, 112, 466, 190)
CM_STRIP = (220, 222, 1230, 402)
CM_BLOCK = (200, 430, 1250, 730)
CM_SOCK = [(320, 620), (724, 620), (1128, 620)]
CM_SEAT = (1008, 448, 1248, 512)
CM_HOLSTER = (220, 770, 480, 890)
CM_TEST = (560, 770, 820, 890)
CM_RESET = (860, 770, 1040, 890)
CM_STAMP = (1080, 770, 1250, 890)


def paint_c_model(rng):
    p = Pen(W, H, rng, OAK_DK)
    # the fanned leaves, cropped by the top edge, behind the faceplate
    # the cabinet back: oak panels behind the instrument
    for x in range(-40, W, 240):
        p.rect(x + 10, 20, x + 230, 740, mix(OAK_DK, OAK, 0.25), mix(INK, OAK_DK, 0.4), 2)
    # the head of the cabinet: a plain dark lintel under the HUD (the leaves are behind it)
    p.rect(-4, -4, W + 4, 84, mix(OAK_DK, SOOT, 0.35), INK, 3)
    p.line([(-4, 78), (W + 4, 78)], mix(OAK_DK, PAPER, 0.15), 1.6)
    p.rect(200, 196, 1250, 420, OAK_DK, INK, 2.4, r=4)
    # faceplate
    soft_shadow(p, *CM_FACE, 4, 6, 4, 0.3)
    p.rect(*CM_FACE, BRASS, INK, 3, r=4)
    p.rect(CM_FACE[0] + 12, CM_FACE[1] + 12, CM_FACE[2] - 12, CM_FACE[3] - 12, None, BRASS_LO, 2, r=3)
    p.line([(CM_FACE[0] + 8, CM_FACE[1] + 6), (CM_FACE[2] - 8, CM_FACE[1] + 6)], BRASS_HI, 2)
    for x, y in ((CM_FACE[0] + 22, CM_FACE[1] + 22), (CM_FACE[2] - 22, CM_FACE[1] + 22),
                 (CM_FACE[0] + 22, CM_FACE[3] - 22), (CM_FACE[2] - 22, CM_FACE[3] - 22)):
        screw(p, x, y, 5)
    # the inspection glass: a narrow mirror in a brass bezel, angled to show what is behind
    # the operator (the view draws the reflection in it)
    mx0, my0, mx1, my1 = CM_MIRROR
    p.rect(mx0 - 8, my0 - 8, mx1 + 8, my1 + 8, BRASS_LO, INK, 3, r=6)
    p.rect(mx0, my0, mx1, my1, mix(STEEL, PAPER_HI, 0.25), INK, 2.4, r=3)
    for x, y in ((mx0 - 2, my0 - 2), (mx1 + 2, my0 - 2), (mx0 - 2, my1 + 2), (mx1 + 2, my1 + 2)):
        screw(p, x, y, 3.2)
    # the paper strip window
    x0, y0, x1, y1 = CM_STRIP
    p.rect(x0 - 2, y0 - 2, x1 + 2, y1 + 2, BRASS, INK, 3, r=4)
    p.rect(x0 + 12, y0 + 12, x1 - 12, y1 - 12, PAPER_HI, INK, 2.2)
    for x in range(int(x0) + 26, int(x1) - 16, 22):
        p.ell(x, y0 + 22, 3, 3, mix(PAPER, TIMBER, 0.35), None)
        p.ell(x, y1 - 22, 3, 3, mix(PAPER, TIMBER, 0.35), None)
    # the terminal block
    x0, y0, x1, y1 = CM_BLOCK
    soft_shadow(p, x0, y0, x1, y1, 5, 7, 5, 0.35)
    p.rect(x0, y0, x1, y1, BRASS_LO, INK, 3, r=6)
    p.rect(x0 + 12, y0 + 12, x1 - 12, y1 - 12, EBONITE, INK, 2.4, r=4)
    p.rect(x0 + 24, y0 + 24, x1 - 24, y1 - 24, None, mix(EBONITE, STORM_HI, 0.5), 1.6, r=3)
    # three brass terminal bays
    for cx, cy in CM_SOCK:
        p.rect(cx - 100, 548, cx + 100, 718, mix(STORM, STORM_HI, 0.3), mix(EBONITE, STORM_HI, 0.8), 1.6, r=6)
    sx0, sy0, sx1, sy1 = CM_SEAT
    p.rect(sx0, sy0, sx1, sy1, BRASS_LO, INK, 2.6, r=6)
    p.line([(sx0 + 8, sy0 + 6), (sx1 - 8, sy0 + 6)], BRASS, 1.8)
    p.rect(sx0 + 14, sy0 + 18, sx1 - 14, sy1 - 14, SLOT, INK, 1.8, r=4)
    for px in (sx0 + 42, sx1 - 42):
        p.ell(px, sy0 + 34, 10, 8, SOOT, INK, 2.0)
    p.line([(CM_SOCK[2][0], sy1), (CM_SOCK[2][0], 572)], BRASS_LO, 5)
    for cx, cy in CM_SOCK:
        socket_face(p, cx, cy, 40, 1.8)
        oak_plate(p, cx - 60, 690, cx + 60, 716)
    for x, y in ((x0 + 22, y0 + 22), (x1 - 22, y0 + 22), (x0 + 22, y1 - 22), (x1 - 22, y1 - 22)):
        screw(p, x, y, 5)
    # the key bed
    p.rect(-4, 744, W + 4, 908, OAK, INK, 3)
    p.line([(-4, 750), (W + 4, 750)], OAK_HI, 1.8)
    x0, y0, x1, y1 = CM_HOLSTER
    soft_shadow(p, x0, y0, x1, y1, 4, 6, 4, 0.3)
    p.rect(x0, y0, x1, y1, mix(TIMBER, SOOT, 0.2), INK, 3, r=10)
    p.rect(x0 + 8, y0 + 8, x1 - 8, y0 + 18, BRASS, INK, 1.8)
    for cx in (x0 + 66, x1 - 66):
        p.ell(cx, y0 + 64, 38, 38, mix(TIMBER, SOOT, 0.45), INK, 2.4)
        p.ell(cx, y0 + 64, 30, 30, SOOT, None)
    push_key(p, *CM_TEST[:2], 260, 120)
    push_key(p, *CM_RESET[:2], 180, 120)
    x0, y0, x1, y1 = CM_STAMP
    p.rect(x0 - 6, y0 - 6, x1 + 6, y1 + 6, BRASS, INK, 3, r=4)
    p.rect(x0, y0, x1, y1, PAPER_HI, INK, 2.2)
    p.rect(-4, 908, W + 4, H + 4, OAK_DK, INK, 2.6)
    return p


def paint_c_shutter(rng):
    p = Pen(1050, 300, rng)
    shutter(p, 2, 2, 1048, 298, s=2.4)
    for x, y in ((22, 22), (1028, 22), (22, 278), (1028, 278)):
        screw(p, x, y, 6)
    return p


def paint_c_plug(rng):
    p = Pen(80, 80, rng)
    p.ell(40, 40, 37, 37, BRASS, INK, 2.6)
    p.ell(40, 40, 29, 29, EBONITE, INK, 2.2)
    for k in range(16):
        a = math.radians(k * 22.5)
        p.line([(40 + 24 * math.cos(a), 40 + 24 * math.sin(a)), (40 + 28 * math.cos(a), 40 + 28 * math.sin(a))],
               mix(EBONITE, PAPER_HI, 0.3), 1.4)
    p.ell(40, 40, 11, 11, BRASS_HI, INK, 1.8)
    p.ell(40, 40, 5, 5, SOOT, None)
    p.ell(31, 30, 5, 3.5, mix(EBONITE, PAPER_HI, 0.45), None)
    return p


def paint_c_plug_parked(rng):
    p = Pen(80, 80, rng)
    p.ell(40, 34, 26, 26, EBONITE, INK, 2.4)
    p.ell(40, 34, 9, 9, BRASS_HI, INK, 1.6)
    p.ell(40, 34, 4, 4, SOOT, None)
    p.ell(32, 25, 5, 3.5, mix(EBONITE, PAPER_HI, 0.45), None)
    p.rect(6, 48, 74, 78, BRASS, INK, 2.6, r=6)
    p.line([(12, 53), (68, 53)], BRASS_HI, 1.8)
    return p


def paint_stamp(rng, style):
    p = Pen(170, 120, rng)
    col = STORM if style == "closed" else mix(SEAGLASS, STORM, 0.35)
    stamp_frame(p, 8, 10, 162, 110, col, rng_for(760 if style == "closed" else 761), 3.2, style)
    return p


# ----------------------------------------------------------------------------- the list

# The tide plates: tide -> (band stage painted, bay frames, doorway). Wall darkening is one
# WALL_DARK_STEP per tide from VI (VI one step ... IX four).
TIDE_PLATES = {6: (4, 6, False), 7: (5, 9, False), 8: (5, 14, True), 9: (7, 14, True)}


def tide_plate(side, tide):
    stage, bays, door = TIDE_PLATES[tide]

    def paint(rng):
        global _wall_dark
        _wall_dark = WALL_DARK_STEP * (tide - 5)
        try:
            if side == "a":
                return paint_view_a(rng, stage, bays, door).done()
            return paint_view_b(rng, stage).done()
        finally:
            _wall_dark = 0.0
    return paint


# ----------------------------------------------------------------------------- stage art, round 3
#
# The catalogue chest repainted with plain ring pulls and the STAFF drawer shut (no slot, no
# mouth). Out of its top seam a thin hard stripe of sea-glass runs straight UP the cabinet face and
# the wall to the ceiling: flat colour, navy edges, no gradient, as if gravity had been filed the
# wrong way round. It widens one step after P23 and another at band 7.

SEEP = (95, 143, 134)           # #5F8F86
SEEP_W = {0: 10.0, 1: 16.0, 2: 24.0}
CHEST_KEEP = (52, 128, 728, 842)       # the chest with its cap and plinth, nothing round it
CAB_PULL = (625, 686, 685, 722)        # view A: the hanging file's pull and its two screws


def paint_cabinet_r3(rng):
    """View B overlay: the whole chest (and the tray before STAFF) with ring pulls, STAFF shut."""
    global _ring_pulls
    p = Pen(W, H, rng)
    _ring_pulls = True
    try:
        chest(p)
        tray(p)
    finally:
        _ring_pulls = False
    a = p.im.getchannel("A")
    p.im.putalpha(ImageChops.multiply(a, rect_mask([CHEST_KEEP])))
    # the shut drawer's top seam, a hair darker: where the stripe comes out
    x0, y0, x1, _ = STAFF
    p.line([(x0 + 6, y0 + 3), (x1 - 6, y0 + 3)], mix(OAK_DK, SOOT, 0.4), 2.0)
    return p


def paint_staff_seep(rng, step):
    """View B overlay: the stripe from STAFF's top seam up to the ceiling."""
    p = Pen(W, H, rng)
    w = SEEP_W[step]
    cx = STAFF_C[0]
    x0, y0, x1, _ = STAFF
    top = CEIL_Y + 14                   # under the cornice: it spreads along it a little
    seam = y0 + 3
    # along the seam: a hairline of it leaking out under the drawer's top rail
    sx = 34.0 + 10.0 * step
    p.poly([(cx - sx, seam - 1.2), (cx + sx, seam - 1.2), (cx + sx, seam + 1.4), (cx - sx, seam + 1.4)], SEEP, None)
    # the stripe: dead straight, hard edged
    p.rect(cx - w / 2, top, cx + w / 2, seam, SEEP, None)
    for x in (cx - w / 2, cx + w / 2):
        p.line([(x, top + 2), (x, seam - 2)], INK, 1.6)
    # where it meets the cornice it runs along the underside, flat, both ways
    sp = 44.0 + 18.0 * step
    p.rect(cx - sp, top - 1, cx + sp, top + 3.5, SEEP, None)
    p.line([(cx - sp, top + 3.5), (cx - w / 2, top + 3.5)], INK, 1.4)
    p.line([(cx + w / 2, top + 3.5), (cx + sp, top + 3.5)], INK, 1.4)
    return p


def paint_drawer_open_r3(rng):
    """Venn's drawer open, as b_drawer_open, with the ring pull."""
    global _ring_pulls
    _ring_pulls = True
    try:
        return paint_b_drawer_open(rng)
    finally:
        _ring_pulls = False


def paint_a_cabinet_r3(rng):
    """View A overlay: the hanging file's arc pull and screws covered, a ring pull in their place."""
    global _ring_pulls
    p = Pen(W, H, rng)
    x0, y0, x1, y1 = CAB
    p.rect(*CAB_PULL, mix(OAK, OAK_DK, 0.35), None)
    _ring_pulls = True
    try:
        pull(p, (x0 + x1) / 2, y0 + 98, 16, 12, 6, 2.6)
    finally:
        _ring_pulls = False
    return p


ASSETS = [  # name, seed index, painter, opaque, grain
    ("view_a", 0, lambda r: paint_view_a(r, 4), True, True),
    ("view_a_s5", 0, lambda r: paint_view_a(r, 5), True, True),
    ("view_a_s7", 0, lambda r: paint_view_a(r, 7), True, True),
    ("view_b", 10, lambda r: paint_view_b(r, 4), True, True),
    ("view_b_s5", 10, lambda r: paint_view_b(r, 5), True, True),
    ("view_a_t6", 0, tide_plate("a", 6), True, True),
    ("view_a_t7", 0, tide_plate("a", 7), True, True),
    ("view_a_t8", 0, tide_plate("a", 8), True, True),
    ("view_a_t9", 0, tide_plate("a", 9), True, True),
    ("view_b_t6", 10, tide_plate("b", 6), True, True),
    ("view_b_t7", 10, tide_plate("b", 7), True, True),
    ("view_b_t8", 10, tide_plate("b", 8), True, True),
    ("view_b_t9", 10, tide_plate("b", 9), True, True),
    ("a_panels_loose", 20, paint_a_panels_loose, False, False),
    ("a_sheet_assembled", 21, paint_a_sheet_assembled, False, False),
    ("a_photos_turned", 22, paint_a_photos_turned, False, False),
    ("a_ninth_photo", 23, paint_a_ninth_photo, False, False),
    ("a_mercer_card", 24, paint_a_mercer_card, False, False),
    # each width step at least a quarter taller than the last; at width 2 the lower lip hangs
    # down over the tray, which now reads as its tongue
    ("b_staff_open", 30, lambda r: paint_b_staff(r, 150, 64), False, False),
    ("b_aperture_1", 31, lambda r: paint_b_staff(r, 178, 86), False, False),
    ("b_aperture_2", 32, lambda r: paint_b_staff(r, 208, 116, lip=28), False, False),
    ("b_tabs_riffle", 33, lambda r: paint_b_staff(r, 150, 64, riffle=True), False, False),
    ("b_drawer_open", 34, paint_b_drawer_open, False, False),
    ("b_terminals", 35, lambda r: paint_b_terminals(r, True), False, False),
    ("b_terminals_nobridge", 36, lambda r: paint_b_terminals(r, False), False, False),
    ("b_string_loose", 37, paint_b_string_loose, False, False),
    ("b_photo_unwrapped", 38, paint_b_photo_unwrapped, False, False),
    ("c_contact", 40, paint_c_contact, True, True),
    ("c_folders", 41, paint_c_folders, True, True),
    ("c_model", 42, paint_c_model, True, True),
    ("c_panel_a", 50, lambda r: paint_c_panel(r, 3), False, False),
    ("c_panel_b", 51, lambda r: paint_c_panel(r, 8), False, False),
    ("c_panel_c", 52, lambda r: paint_c_panel(r, 0, omit_last=True), False, False),
    ("c_panel_d", 53, lambda r: paint_c_panel(r, 6), False, False),
    ("c_blank_t0", 54, lambda r: paint_c_blank(r, "front"), False, False),
    ("c_blank_t1", 55, lambda r: paint_c_blank(r, "three"), False, False),
    ("c_blank_t2", 56, lambda r: paint_c_blank(r, "away"), False, False),
    ("c_cover", 57, paint_c_cover, False, False),
    ("c_clamp", 58, paint_c_clamp, False, False),
    ("c_reflection", 59, paint_c_reflection, False, False),
    ("c_rec_frame", 60, paint_c_rec_frame, False, False),
    ("c_rec_strip", 61, paint_c_rec_strip, False, False),
    ("c_rec_card", 62, paint_c_rec_card, False, False),
    ("c_leaf_closed", 63, paint_c_leaf_closed, False, False),
    ("c_index_bar", 64, paint_c_index_bar, False, False),
    ("c_lever_up", 65, sprite(120, 170, lambda p: lever(p, 0, 0, False)), False, False),
    ("c_lever_down", 66, sprite(120, 170, lambda p: lever(p, 0, 0, True)), False, False),
    ("c_key_down", 67, sprite(200, 110, lambda p: push_key(p, 0, 0, 200, 110, True)), False, False),
    ("c_shutter", 68, paint_c_shutter, False, False),
    ("c_bridge", 69, sprite(240, 70, lambda p: bridge(p, 0, 0, 240, 70)), False, False),
    ("c_plug", 70, paint_c_plug, False, False),
    ("c_plug_parked", 71, paint_c_plug_parked, False, False),
    ("c_stamp_closed", 72, lambda r: paint_stamp(r, "closed"), False, False),
    ("c_stamp_open", 73, lambda r: paint_stamp(r, "open"), False, False),
    ("c_mkey_down", 74, sprite(260, 120, lambda p: push_key(p, 0, 0, 260, 120, True)), False, False),
    ("c_rkey_down", 75, sprite(180, 120, lambda p: push_key(p, 0, 0, 180, 120, True)), False, False),
]


STAGE_ASSETS = [  # name, seed index, painter, opaque, grain -> assets/stages/R10/
    ("staff_slot", 90, lambda r: paint_staff_slot(r, 0), False, False),
    ("staff_slot_1", 91, lambda r: paint_staff_slot(r, 1), False, False),
    ("staff_slot_2", 92, lambda r: paint_staff_slot(r, 2), False, False),
    ("staff_slot_riffle", 93, lambda r: paint_staff_slot(r, 0, riffle=True), False, False),
    ("staff_shut", 94, paint_staff_shut, False, False),
    ("vault_grade", 95, paint_vault_grade, False, False),
    # round 3 (p2): ring pulls everywhere, STAFF shut, the stripe running up out of it
    ("cabinet_r3", 96, paint_cabinet_r3, False, True),
    ("staff_seep_r3", 97, lambda r: paint_staff_seep(r, 0), False, False),
    ("staff_seep_r3_1", 98, lambda r: paint_staff_seep(r, 1), False, False),
    ("staff_seep_r3_2", 99, lambda r: paint_staff_seep(r, 2), False, False),
    ("drawer_open_r3", 100, paint_drawer_open_r3, False, False),
    ("a_cabinet_r3", 101, paint_a_cabinet_r3, False, True),
]


def main(argv):
    pats = argv or ["*"]
    for table, out in ((ASSETS, OUT), (STAGE_ASSETS, STAGE_OUT)):
        for name, k, fn, opaque, gr in table:
            if not any(fnmatch.fnmatch(name, pat) for pat in pats):
                continue
            rng = rng_for(k)
            res = fn(rng)
            im = res.done() if isinstance(res, Pen) else res
            if gr is not False:
                im = grain(im, rng_for(1000 + (k if gr is True else gr)))
            save(im, name, opaque, out)


if __name__ == "__main__":
    main(sys.argv[1:])
