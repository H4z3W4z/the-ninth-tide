#!/usr/bin/env python3
"""R02 Intake Office painter: view B (the entry wall), its door-glass insets, the new
view A overlays, and the P20 board close-ups.

Writes, and only writes, PNGs under assets/rooms/R02/. Python 3 + PIL only.
Deterministic: every asset has its own fixed seed (random.Random(1931_0200 + k)), no wall
clock and no filesystem ordering, so a rerun is byte-identical.

    python3 tools/art/rooms/R02.py

Style: flat front elevation, navy ink contours 2-3 px with a slight seeded wobble, matte
fills, paper grain. No perspective and no cast shadows (the lamp's floor spill excepted).
Every exact word is drawn by the game; papers, plates, tags and stamps are left blank.
The palette is sampled from assets/backgrounds/office_arrival.png so view B sits beside
view A without a seam.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/rooms/R02"
W, H = 1448, 1086
SEED = 1931_0200

# ---------------------------------------------------------------------------
# palette (sampled from office_arrival.png; paper, ink and red fixed by the brief)
# ---------------------------------------------------------------------------
INK = (23, 43, 54)            # 172b36
PAPER = (222, 212, 186)       # ded4ba
RED = (142, 59, 46)           # 8e3b2e, the only red in the room
WAX = (104, 38, 31)           # the red, pressed dark into wax
WALL = (164, 181, 162)        # sea-glass plaster (300,100)
TEAL = (45, 85, 102)          # trim, wainscot, doors (wainscot / casing samples)
TEAL_D = (35, 70, 86)
TEAL_L = (60, 102, 119)
CEIL = (42, 80, 96)
FLOOR = (94, 79, 66)          # (700,1000)
FLOOR_D = (78, 64, 53)
WOOD = (104, 79, 58)          # desk brown (600,900)
WOOD_D = (80, 63, 49)         # hook rail
WOOD_L = (126, 97, 71)
BRASS = (198, 143, 65)        # hook highlight (872,262)
BRASS_D = (150, 106, 46)
BRASS_L = (228, 186, 112)
GLASS_DARK = (17, 27, 39)
CORK = (163, 131, 96)
CORK_D = (136, 106, 76)
NEWS = (206, 199, 178)
CARD = (232, 226, 209)
SALT = (226, 226, 214)
AMBER = (232, 176, 92)
SEA_SKY = (176, 186, 196)     # the window's overcast (view A lower pane)
SLATE = (64, 76, 88)          # headland and jetty silhouettes in view A's window

# view A window glass (measured on the arrival plate; same as painter_1)
PANES = [(483, 144, 100, 108), (593, 144, 100, 108), (702, 144, 98, 108),
         (483, 262, 100, 93), (593, 262, 100, 93), (702, 262, 98, 93),
         (483, 368, 317, 177)]
HOOKS = [872, 907, 941, 976, 1011, 1045, 1080, 1115]   # re-measured from the plate (y 262)


# ---------------------------------------------------------------------------
# small maths
# ---------------------------------------------------------------------------
def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(int(round(lerp(a, b, t))) for a, b in zip(c1, c2))


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def rgba(c, a=255):
    return tuple(c[:3]) + (int(a),)


# ---------------------------------------------------------------------------
# texture
# ---------------------------------------------------------------------------
def noise(rng: random.Random, w: int, h: int, scale: int = 1, blur: float = 0.0) -> Image.Image:
    """Seeded value noise in L, stretched to full contrast."""
    sw, sh = max(2, w // scale), max(2, h // scale)
    im = Image.frombytes("L", (sw, sh), rng.randbytes(sw * sh))
    if scale > 1:
        im = im.resize((w, h), Image.BICUBIC)
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    return ImageOps.autocontrast(im, cutoff=1)


def apply_signed(img: Image.Image, tex: Image.Image, k: float) -> Image.Image:
    pos = tex.point(lambda v: int(max(0, v - 128) * k))
    neg = tex.point(lambda v: int(max(0, 128 - v) * k))
    bands = img.split()
    out = [ImageChops.subtract(ImageChops.add(b, pos), neg) for b in bands[:3]]
    if len(bands) == 4:
        out.append(bands[3])
    return Image.merge(img.mode, out)


def grain(img: Image.Image, rng: random.Random, k: float = 0.065) -> Image.Image:
    """Matte paper: fibre and mottle, plus sparse light/dark speckle at ~4% alpha."""
    w, h = img.size
    tex = Image.blend(noise(rng, w, h, 1, 0.6), noise(rng, w, h, 24, 1.0), 0.28)
    out = apply_signed(img, tex, k)
    sp = Image.frombytes("L", (w, h), rng.randbytes(w * h))
    light = sp.point(lambda v: 11 if v > 245 else 0)
    dark = sp.point(lambda v: 12 if v < 10 else 0)
    rgb = out.convert("RGB")
    rgb = Image.composite(Image.new("RGB", (w, h), (240, 236, 222)), rgb, light)
    rgb = Image.composite(Image.new("RGB", (w, h), INK), rgb, dark)
    if img.mode == "RGBA":
        rgb.putalpha(img.getchannel("A"))
    return rgb


def tint(img: Image.Image, color, mask: Image.Image, alpha: float = 1.0) -> Image.Image:
    """Lay a matte colour over img through an L mask (keeps img's alpha)."""
    if alpha != 1.0:
        mask = mask.point(lambda v: int(v * alpha))
    base = img.convert("RGBA")
    layer = Image.new("RGBA", img.size, rgba(color))
    out = Image.composite(layer, base, mask)
    out.putalpha(base.getchannel("A"))
    return out if img.mode == "RGBA" else out.convert("RGB")


def shade(img: Image.Image, color, mask: Image.Image) -> Image.Image:
    """Multiply img by color through mask (damp, wet)."""
    base = img.convert("RGBA")
    mul = ImageChops.multiply(base.convert("RGB"), Image.new("RGB", img.size, color))
    mul.putalpha(base.getchannel("A"))
    out = Image.composite(mul, base, mask)
    return out if img.mode == "RGBA" else out.convert("RGB")


def mask_rects(rects, size=(W, H)) -> Image.Image:
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    for x, y, w, h in rects:
        d.rectangle((x, y, x + w - 1, y + h - 1), fill=255)
    return m


def mmul(a: Image.Image, b: Image.Image) -> Image.Image:
    return ImageChops.multiply(a, b)


def scale_mask(m: Image.Image, k: float) -> Image.Image:
    return m.point(lambda v: int(clamp(v * k / 255.0) * 255))


# ---------------------------------------------------------------------------
# the drawing canvas: shapes at SS x, anti-aliased by reduce, ink with a hand wobble
# ---------------------------------------------------------------------------
class Canvas:
    def __init__(self, w: int, h: int, seed: int, ss: int = 2, bg=(0, 0, 0, 0)):
        self.w, self.h, self.ss = w, h, ss
        self.rng = random.Random(seed)
        self.im = Image.new("RGBA", (w * ss, h * ss), rgba(bg, bg[3] if len(bg) == 4 else 255))
        self.d = ImageDraw.Draw(self.im)

    # -- coordinates
    def S(self, pts):
        s = self.ss
        return [(x * s, y * s) for x, y in pts]

    def wob(self, pts, amp=0.55, step=5.0, closed=False):
        if closed:
            pts = list(pts) + [pts[0]]
        rng = self.rng
        ph1, ph2 = rng.uniform(0, 6.283), rng.uniform(0, 6.283)
        f1, f2 = rng.uniform(0.07, 0.11), rng.uniform(0.19, 0.27)
        out, dist = [], 0.0
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            seg = math.hypot(x1 - x0, y1 - y0)
            n = max(1, int(seg / step))
            nx, ny = ((-(y1 - y0) / seg, (x1 - x0) / seg) if seg else (0.0, 0.0))
            for i in range(n):
                t = i / n
                dd = dist + seg * t
                o = amp * (0.65 * math.sin(dd * f1 + ph1) + 0.35 * math.sin(dd * f2 + ph2))
                out.append((lerp(x0, x1, t) + nx * o, lerp(y0, y1, t) + ny * o))
            dist += seg
        out.append(pts[-1])
        return out

    # -- fills (exact) and ink (wobbly)
    def poly(self, pts, fill=None, ink=INK, lw=2.5, amp=0.55, im=None):
        d = ImageDraw.Draw(im) if im is not None else self.d
        if fill is not None:
            d.polygon(self.S(pts), fill=rgba(fill, fill[3] if len(fill) == 4 else 255))
        if ink is not None and lw > 0:
            self.line(pts, ink, lw, amp, closed=True, im=im)

    def line(self, pts, ink=INK, lw=2.5, amp=0.55, closed=False, im=None):
        d = ImageDraw.Draw(im) if im is not None else self.d
        lw = lw * self.rng.uniform(0.92, 1.08)
        p = self.wob(pts, amp, closed=closed) if amp > 0 else (list(pts) + ([pts[0]] if closed else []))
        col = rgba(ink, ink[3] if len(ink) == 4 else 255)
        wpx = max(1, int(round(lw * self.ss)))
        d.line(self.S(p), fill=col, width=wpx, joint="curve")
        r = lw * self.ss / 2.0
        if not closed and r > 1:
            for (x, y) in (p[0], p[-1]):
                d.ellipse((x * self.ss - r, y * self.ss - r, x * self.ss + r, y * self.ss + r), fill=col)

    def box(self, x, y, w, h, fill=None, ink=INK, lw=2.5, amp=0.55, im=None):
        self.poly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], fill, ink, lw, amp, im)

    def ring_pts(self, cx, cy, r, n=None, ry=None, a0=0.0, a1=360.0):
        ry = r if ry is None else ry
        n = n or max(24, int(r * 1.2))
        return [(cx + r * math.cos(math.radians(lerp(a0, a1, i / n))),
                 cy + ry * math.sin(math.radians(lerp(a0, a1, i / n)))) for i in range(n)]

    def circle(self, cx, cy, r, fill=None, ink=INK, lw=2.5, amp=0.4, ry=None, im=None):
        pts = self.ring_pts(cx, cy, r, ry=ry)
        self.poly(pts, fill, ink, lw, amp, im)

    def layer(self):
        return Image.new("RGBA", self.im.size, (0, 0, 0, 0))

    def comp(self, lay, alpha=1.0):
        if alpha < 1.0:
            a = lay.getchannel("A").point(lambda v: int(v * alpha))
            lay = lay.copy()
            lay.putalpha(a)
        self.im.alpha_composite(lay)

    def result(self) -> Image.Image:
        return self.im.reduce(self.ss) if self.ss > 1 else self.im.copy()


# ---------------------------------------------------------------------------
# shared furniture
# ---------------------------------------------------------------------------
def brass_head(c: Canvas, x, y, r, im=None):
    c.circle(x, y, r, BRASS, INK, 2.0 if r > 6 else 1.6, 0.2, im=im)
    c.circle(x - r * 0.3, y - r * 0.3, r * 0.38, BRASS_L, None, 0, 0, im=im)


def tack(c: Canvas, x, y, r=5):
    brass_head(c, x, y, r)


def ruled(c: Canvas, x, y, w, h, gap, col, lw=1.0, inset=10, start=None):
    yy = y + (start if start is not None else gap)
    while yy < y + h - inset * 0.6:
        c.line([(x + inset, yy), (x + w - inset, yy)], col, lw, 0.25)
        yy += gap


def paper_sheet(c: Canvas, x, y, w, h, tone=PAPER, lw=2.2, rules=None, rule_col=None):
    c.box(x, y, w, h, tone, INK, lw, 0.5)
    if rules:
        ruled(c, x, y, w, h, rules, rule_col or mix(tone, INK, 0.16), 1.0, 8)


def panel(c: Canvas, x, y, w, h, fill=TEAL_D, rim=TEAL_L, lw=2.2):
    """A raised door panel, flat: outer contour, a lighter rim, inner contour."""
    c.box(x, y, w, h, rim, INK, lw)
    c.box(x + 8, y + 8, w - 16, h - 16, fill, INK, 1.8)


def stamp_handle(c: Canvas, cx, top, hw, hh, bw, bh):
    """Turned-wood handle (hw x hh) on a block (bw x bh), centred on cx, flat elevation."""
    by = top + hh
    c.box(cx - bw / 2, by, bw, bh, WOOD, INK, 2.2)
    c.line([(cx - bw / 2 + 4, by + bh * 0.55), (cx + bw / 2 - 4, by + bh * 0.55)], WOOD_D, 1.4, 0.2)
    # neck flares into the block, ball on top
    r = hw / 2
    neck = [(cx - hw * 0.22, top + r * 1.6), (cx - hw * 0.18, by - hh * 0.18), (cx - hw * 0.42, by),
            (cx + hw * 0.42, by), (cx + hw * 0.18, by - hh * 0.18), (cx + hw * 0.22, top + r * 1.6)]
    c.poly(neck, WOOD_L, INK, 2.0, 0.25)
    c.circle(cx, top + r, r, WOOD_L, INK, 2.0, 0.25)
    c.circle(cx - r * 0.32, top + r * 0.68, r * 0.32, mix(WOOD_L, PAPER, 0.35), None, 0, 0)


# ---------------------------------------------------------------------------
# VIEW B: the entry wall
# ---------------------------------------------------------------------------
OUTER_CASING = (88, 120, 316, 790)
OUTER_SLAB = (116, 148, 260, 762)
OUTER_GLASS = (168, 216, 156, 196)
SERVICE_CASING = (1160, 120, 270, 790)
SERVICE_SLAB = (1186, 148, 218, 762)
BARO = (560, 452)
CLOCK = (560, 200)
BOARD_FRAME = (700, 150, 420, 330)
WAINSCOT_SPANS = [(0, 88), (404, 1160), (1430, 1448)]   # wainscot not covered by a door


def wall_colours(state):
    if state == "ominous":
        return dict(wall=(141, 160, 155), teal=(38, 74, 92), teal_d=(30, 61, 77), teal_l=(52, 92, 110),
                    ceil=(36, 70, 86), floor=(86, 75, 66), floor_d=(70, 60, 52))
    if state == "day":
        return dict(wall=(176, 190, 174), teal=(56, 96, 112), teal_d=(45, 82, 97), teal_l=(73, 114, 130),
                    ceil=(52, 90, 106), floor=(108, 96, 84), floor_d=(90, 79, 68))
    return dict(wall=WALL, teal=TEAL, teal_d=TEAL_D, teal_l=TEAL_L, ceil=CEIL, floor=FLOOR, floor_d=FLOOR_D)


def paint_entry_geometry(state: str, seed: int) -> Image.Image:
    pal = wall_colours(state)
    teal, teal_d, teal_l = pal["teal"], pal["teal_d"], pal["teal_l"]
    c = Canvas(W, H, seed, 2, pal["wall"] + (255,))
    # bands -----------------------------------------------------------------
    c.box(-4, -4, W + 8, 28, pal["ceil"], None, 0)
    c.line([(-4, 21), (W + 4, 21)], INK, 3.0, 0.3)
    c.line([(-4, 7), (W + 4, 7)], mix(pal["ceil"], INK, 0.45), 1.4, 0.3)
    # wainscot boards
    c.box(-4, 600, W + 8, 290, teal, None, 0)
    x = 0
    while x <= W:
        c.line([(x, 602), (x, 888)], INK, 2.0, 0.35)
        c.line([(x + 3, 604), (x + 3, 886)], teal_l, 1.4, 0.3)
        x += 48
    # dado rail
    c.box(-4, 585, W + 8, 15, teal_l, None, 0)
    c.line([(-4, 585), (W + 4, 585)], INK, 2.6, 0.35)
    c.line([(-4, 591), (W + 4, 591)], teal_d, 1.4, 0.2)
    c.line([(-4, 600), (W + 4, 600)], INK, 2.6, 0.35)
    # skirting
    c.box(-4, 890, W + 8, 15, teal_d, None, 0)
    c.line([(-4, 890), (W + 4, 890)], INK, 2.4, 0.3)
    c.line([(-4, 894), (W + 4, 894)], teal_l, 1.2, 0.2)
    # floor planks (front elevation: long horizontal boards, staggered butt joints)
    c.box(-4, 905, W + 8, 190, pal["floor"], None, 0)
    c.line([(-4, 905), (W + 4, 905)], INK, 2.8, 0.3)
    ys = [905, 931, 960, 993, 1030, 1070]
    rng = random.Random(seed + 7)
    for i, y in enumerate(ys[1:]):
        c.line([(-4, y), (W + 4, y)], mix(pal["floor_d"], INK, 0.45), 1.8, 0.5)
        off = rng.uniform(0, 300)
        xx = off
        while xx < W:
            c.line([(xx, ys[i] + 3), (xx, y - 2)], mix(pal["floor_d"], INK, 0.35), 1.4, 0.2)
            xx += rng.uniform(320, 520)

    # outer door --------------------------------------------------------------
    x, y, w, h = OUTER_CASING
    c.box(x, y, w, h, teal, INK, 2.8)
    c.box(x - 10, y - 14, w + 20, 18, teal_l, INK, 2.6)            # header cap
    c.box(x - 4, y + 4, w + 8, 8, teal_d, INK, 1.8)
    c.line([(x + 8, y + 14), (x + 8, y + h - 2)], teal_l, 1.4, 0.25)
    c.line([(x + w - 8, y + 14), (x + w - 8, y + h - 2)], teal_d, 1.4, 0.25)
    sx, sy, sw, sh = OUTER_SLAB
    c.box(sx, sy, sw, sh, teal, INK, 2.6)
    gx, gy, gw, gh = OUTER_GLASS
    c.box(gx - 10, gy - 10, gw + 20, gh + 20, teal_l, INK, 2.2)     # glazing bead
    c.box(gx, gy, gw, gh, GLASS_DARK, INK, 2.4)
    c.box(gx + gw / 2 - 3, gy, 6, gh, teal, None, 0)                 # cross muntin 6 px
    c.box(gx, gy + gh / 2 - 3, gw, 6, teal, None, 0)
    c.line([(gx + gw / 2 - 3, gy), (gx + gw / 2 - 3, gy + gh)], INK, 1.5, 0.2)
    c.line([(gx + gw / 2 + 3, gy), (gx + gw / 2 + 3, gy + gh)], INK, 1.5, 0.2)
    c.line([(gx, gy + gh / 2 - 3), (gx + gw, gy + gh / 2 - 3)], INK, 1.5, 0.2)
    c.line([(gx, gy + gh / 2 + 3), (gx + gw, gy + gh / 2 + 3)], INK, 1.5, 0.2)
    panel(c, 148, 470, 196, 170, teal_d, teal_l)
    panel(c, 148, 680, 196, 190, teal_d, teal_l)
    # hinges, latch side right
    for hy in (196, 520, 820):
        c.box(110, hy, 10, 40, BRASS_D, INK, 1.8)
    c.box(340, 520, 24, 80, BRASS, INK, 2.0)
    c.line([(344, 526), (344, 594)], BRASS_L, 1.4, 0.2)
    c.circle(352, 560, 10, BRASS, INK, 2.2, 0.2)
    c.circle(349, 557, 4, BRASS_L, None, 0, 0)
    c.poly([(349, 579), (355, 579), (356, 592), (348, 592)], INK, None, 0)   # keyhole
    c.circle(352, 580, 3.2, INK, None, 0, 0)
    # door mat
    c.box(116, 905, 260, 26, mix(WOOD, FLOOR, 0.35), INK, 2.4)
    c.box(122, 909, 248, 18, None, mix(WOOD_D, INK, 0.3), 1.2)
    for i in range(1, 26):
        xx = 116 + i * 10
        c.line([(xx, 911), (xx, 925)], mix(WOOD_D, INK, 0.25), 1.0, 0.1)

    # receipt -----------------------------------------------------------------
    paper_sheet(c, 418, 612, 80, 104, mix(PAPER, (240, 236, 222), 0.25), 2.0, 11, mix(PAPER, TEAL, 0.25))
    c.poly([(418, 716), (424, 720), (431, 714), (440, 721), (449, 715), (458, 721), (467, 714),
            (476, 720), (485, 714), (492, 720), (498, 716)], mix(PAPER, (240, 236, 222), 0.25), INK, 1.8, 0.15)
    tack(c, 458, 618, 5.5)

    # banjo barometer ---------------------------------------------------------
    bx, by = BARO
    cx, cy = CLOCK
    case = Image.new("L", c.im.size, 0)          # union of case silhouette (for an outer contour)
    dm = ImageDraw.Draw(case)
    s = c.ss
    dm.ellipse(((cx - 56) * s, (cy - 56) * s, (cx + 56) * s, (cy + 56) * s), fill=255)
    dm.ellipse(((bx - 112) * s, (by - 112) * s, (bx + 112) * s, (by + 112) * s), fill=255)
    dm.rectangle(((cx - 26) * s, (cy + 30) * s, (cx + 26) * s, (by - 80) * s), fill=255)
    c.im.paste(rgba(WOOD), (0, 0), case)
    edge = case.filter(ImageFilter.MaxFilter(5)).point(lambda v: 255 if v > 0 else 0)
    c.im.paste(rgba(INK), (0, 0), ImageChops.subtract(edge, case))
    # finial and drop
    c.poly([(cx - 9, cy - 56), (cx - 5, cy - 68), (cx - 9, cy - 76), (cx, cy - 86), (cx + 9, cy - 76),
            (cx + 5, cy - 68), (cx + 9, cy - 56)], WOOD_L, INK, 2.0, 0.2)
    c.poly([(bx - 10, by + 110), (bx + 10, by + 110), (bx + 6, by + 120), (bx, by + 130), (bx - 6, by + 120)],
           WOOD_L, INK, 2.0, 0.2)
    # wood inlay lines
    c.circle(cx, cy, 52, None, WOOD_L, 1.4, 0.3)
    c.circle(bx, by, 107, None, WOOD_L, 1.4, 0.3)
    c.box(540, 246, 40, 150, mix(WOOD, WOOD_D, 0.4), INK, 2.0)
    c.box(556, 262, 8, 118, mix(PAPER, (240, 240, 236), 0.4), INK, 1.6)
    c.circle(560, 386, 7, mix(PAPER, (240, 240, 236), 0.4), INK, 1.6, 0.1)
    for i in range(9):
        yy = 268 + i * 13
        c.line([(548, yy), (553, yy)], PAPER, 1.2, 0.1)
        c.line([(567, yy), (572, yy)], PAPER, 1.2, 0.1)
    # bezels and faces
    c.circle(cx, cy, 46, BRASS, INK, 2.4, 0.25)
    c.circle(cx, cy, 38, PAPER, INK, 2.0, 0.25)
    c.circle(cx, cy, 43, None, BRASS_L, 1.2, 0.2)
    for k in range(12):
        a = math.radians(k * 30 - 90)
        r0 = 30 if k % 3 == 0 else 33
        c.line([(cx + r0 * math.cos(a), cy + r0 * math.sin(a)), (cx + 36 * math.cos(a), cy + 36 * math.sin(a))],
               INK, 1.6 if k % 3 == 0 else 1.1, 0.0)
    c.circle(bx, by, 100, BRASS, INK, 2.6, 0.25)
    c.circle(bx, by, 95, None, BRASS_L, 1.4, 0.2)
    c.circle(bx, by, 86, PAPER, INK, 2.2, 0.25)
    c.circle(bx, by, 64, None, mix(PAPER, INK, 0.35), 1.2, 0.2)
    for g in (-120, -60, 0, 60, 120):
        for j in range(-2, 3):
            a = math.radians(g - 90 + j * 4)
            r0 = 66 if j == 0 else 72
            c.line([(bx + r0 * math.cos(a), by + r0 * math.sin(a)),
                    (bx + 82 * math.cos(a), by + 82 * math.sin(a))], INK, 2.0 if j == 0 else 1.2, 0.0)
    for k in range(60):                            # fine scale between the groups
        a = math.radians(-150 + k * 5 - 90)
        if -150 <= -150 + k * 5 <= 150:
            c.line([(bx + 79 * math.cos(a), by + 79 * math.sin(a)),
                    (bx + 82 * math.cos(a), by + 82 * math.sin(a))], mix(PAPER, INK, 0.5), 0.9, 0.0)

    # comparison board --------------------------------------------------------
    fx, fy, fw, fh = BOARD_FRAME
    c.box(fx, fy, fw, fh, WOOD, INK, 2.8)
    c.box(fx + 5, fy + 5, fw - 10, fh - 10, None, WOOD_L, 1.4, 0.3)
    c.box(716, 166, 388, 298, CORK, INK, 2.2)
    c.box(760, 396, 300, 30, mix(PAPER, (240, 236, 222), 0.2), INK, 2.0)
    for px in (812, 910, 1008):
        brass_head(c, px, 438, 7.5)
    # stamp rail
    c.box(712, 548, 396, 11, WOOD, INK, 2.2)                 # ledge
    c.box(716, 492, 388, 56, mix(WOOD_D, WOOD, 0.3), INK, 2.2)   # back rail
    c.line([(720, 498), (1100, 498)], WOOD_L, 1.2, 0.3)
    for bxk in (722, 1086):
        c.poly([(bxk, 559), (bxk + 14, 559), (bxk + 14, 572), (bxk + 4, 566)], WOOD_D, INK, 1.8, 0.1)
    for hx in (780, 910, 1040):
        stamp_handle(c, hx, 492, 30, 40, 80, 16)

    # service door ------------------------------------------------------------
    x, y, w, h = SERVICE_CASING
    c.box(x, y, w, h, teal, INK, 2.8)
    c.box(x - 10, y - 14, w + 20, 18, teal_l, INK, 2.6)
    c.box(x - 4, y + 4, w + 8, 8, teal_d, INK, 1.8)
    c.line([(x + 8, y + 14), (x + 8, y + h - 2)], teal_l, 1.4, 0.25)
    c.line([(x + w - 8, y + 14), (x + w - 8, y + h - 2)], teal_d, 1.4, 0.25)
    sx, sy, sw, sh = SERVICE_SLAB
    c.box(sx, sy, sw, sh, teal, INK, 2.6)
    panel(c, 1246, 262, 66, 236, teal_d, teal_l)
    panel(c, 1322, 262, 62, 236, teal_d, teal_l)
    panel(c, 1246, 650, 66, 220, teal_d, teal_l)
    panel(c, 1322, 650, 62, 220, teal_d, teal_l)
    for hy in (196, 520, 820):                              # hinges on the right
        c.box(1398, hy, 10, 40, BRASS_D, INK, 1.8)
    c.box(1235, 206, 120, 30, (226, 224, 212), INK, 2.2)  # blank enamel plate
    c.box(1239, 210, 112, 22, None, mix(INK, TEAL, 0.4), 1.2)
    c.circle(1243, 221, 2.2, BRASS_D, None, 0)
    c.circle(1347, 221, 2.2, BRASS_D, None, 0)
    c.box(1206, 520, 30, 96, BRASS, INK, 2.2)
    c.line([(1211, 527), (1211, 609)], BRASS_L, 1.4, 0.2)
    c.circle(1221, 548, 11, BRASS, INK, 2.2, 0.2)          # knob boss
    c.circle(1218, 545, 4.5, BRASS_L, None, 0, 0)
    c.circle(1221, 584, 5, INK, None, 0, 0)                 # keyhole
    c.poly([(1218, 586), (1224, 586), (1226, 600), (1216, 600)], INK, None, 0)
    return c.result().convert("RGB")


def floor_spill(img: Image.Image, strength=0.34, color=(204, 158, 102)) -> Image.Image:
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).ellipse((724 - 560, 1086 - 230, 724 + 560, 1086 + 230), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(80))
    m = mmul(m, mask_rects([(0, 907, W, H - 907)]))
    return tint(img, color, scale_mask(m, strength))


def wainscot_mask(y0, y1) -> Image.Image:
    return mask_rects([(a, y0, b - a, y1 - y0) for a, b in WAINSCOT_SPANS])


def tide_line(img: Image.Image, rng: random.Random, y0: float, dark=(196, 204, 208), bloom=0.75,
              amp=5.0) -> Image.Image:
    """A dried tide line on the wainscot: damp below, a broken salt crust on the edge,
    crystals blooming a hand's width above. The receipt stays dry and legible."""
    ph = [rng.uniform(0, 6.28) for _ in range(3)]
    edge_y = [y0 + amp * (0.5 * math.sin(x * 0.011 + ph[0]) + 0.3 * math.sin(x * 0.043 + ph[1])
                          + 0.2 * math.sin(x * 0.13 + ph[2])) for x in range(W)]
    below = Image.new("L", (W, H), 0)
    line = Image.new("L", (W, H), 0)
    fade = Image.new("L", (W, H), 0)
    bp, lp, fp = below.load(), line.load(), fade.load()
    for x in range(W):
        e = edge_y[x]
        for y in range(int(e), 890):
            bp[x, y] = 255
        for y in range(int(e) - 1, int(e) + 2):
            lp[x, y] = 255
        for y in range(int(e) - 34, int(e) - 1):
            fp[x, y] = int(255 * clamp(1 - (e - y) / 34.0) ** 1.8)
    span = ImageChops.subtract(wainscot_mask(600, 890), mask_rects([(412, 606, 92, 118)]))
    below = mmul(below, span).filter(ImageFilter.GaussianBlur(1.0))
    img = shade(img, dark, below)
    lowblot = mmul(noise(rng, W, H, 30, 4.0), mask_rects([(0, 790, W, 100)]).filter(ImageFilter.GaussianBlur(30)))
    img = shade(img, (206, 212, 214), mmul(lowblot, span))
    # crystals: fine pale grains in clumps, thinning upward
    crystals = noise(rng, W, H, 1, 0.0).point(lambda v: 255 if v > 214 else 0)
    clumps = noise(rng, W, H, 6, 1.2).point(lambda v: 255 if v > 120 else 0)
    salt = mmul(mmul(mmul(fade, crystals), clumps), span)
    img = tint(img, SALT, salt, bloom)
    # the crust: a pale broken line with an ink-dark wet edge just under it
    breaks = noise(rng, W, H, 4, 0.8).point(lambda v: 255 if v > 70 else 0)
    crust = mmul(mmul(line, span), breaks).filter(ImageFilter.GaussianBlur(0.5))
    img = tint(img, mix(SALT, (200, 194, 172), 0.35), crust, 0.85)
    under = mmul(line, span).transform(line.size, Image.AFFINE, (1, 0, 0, 0, 1, -2)).filter(ImageFilter.GaussianBlur(0.8))
    img = tint(img, INK, under, 0.4)
    return img


def baro_fog(img: Image.Image, rng: random.Random, alpha=0.82) -> Image.Image:
    """Condensation inside the barometer glass, crowding the rim and leaving the middle clear."""
    bx, by = BARO
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((bx - 86, by - 86, bx + 86, by + 86), fill=255)
    d.ellipse((bx - 56, by - 56, bx + 56, by + 56), fill=0)
    m = m.filter(ImageFilter.GaussianBlur(9))
    face = Image.new("L", (W, H), 0)
    ImageDraw.Draw(face).ellipse((bx - 85, by - 85, bx + 85, by + 85), fill=255)
    cloud = noise(rng, W, H, 7, 1.5).point(lambda v: int(60 + v * 0.76))
    m = mmul(mmul(m, face), cloud)
    img = tint(img, (196, 206, 210), m, alpha)
    beads = Image.new("L", (W, H), 0)
    glints = Image.new("L", (W, H), 0)
    bd, gd = ImageDraw.Draw(beads), ImageDraw.Draw(glints)
    for _ in range(26):
        a = math.radians(rng.uniform(20, 160))
        r = rng.uniform(70, 82)
        x, y, rr = bx + r * math.cos(a), by + r * math.sin(a), rng.uniform(1.6, 3.2)
        bd.ellipse((x - rr, y - rr, x + rr, y + rr), fill=255)
        gd.ellipse((x - rr * 0.6, y - rr * 0.7, x - rr * 0.1, y - rr * 0.2), fill=255)
    img = tint(img, (168, 176, 178), beads, 0.55)
    img = tint(img, (250, 250, 248), glints, 0.9)
    return img


def wall_stains(img: Image.Image, rng: random.Random, color, alpha) -> Image.Image:
    """Long drip stains down the plaster from the ceiling band, never over an object."""
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    xs = [30, 52, 438, 470, 650, 690, 1132, 1146, 1442]
    for x0 in xs:
        x = x0 + rng.uniform(-6, 6)
        L = rng.uniform(60, 190)
        wdt = rng.uniform(5, 13)
        for i in range(int(L)):
            t = i / L
            ww = wdt * (1 - t) ** 0.6
            d.ellipse((x - ww / 2, 22 + i - 2, x + ww / 2, 22 + i + 2), fill=int(255 * (1 - t * 0.6)))
            x += rng.uniform(-0.25, 0.25)
    for x0 in (20, 60, 430, 480, 640, 1130, 1150):          # wicking up from the dado
        x = x0 + rng.uniform(-8, 8)
        L = rng.uniform(30, 80)
        for i in range(int(L)):
            t = i / L
            ww = 14 * (1 - t) ** 0.7
            d.ellipse((x - ww / 2, 585 - i - 2, x + ww / 2, 585 - i + 2), fill=int(220 * (1 - t)))
    m = m.filter(ImageFilter.GaussianBlur(2.2))
    keep = Image.new("L", (W, H), 255)
    kd = ImageDraw.Draw(keep)
    for r in [(78, 104, 336, 820), (1150, 104, 290, 820), (488, 100, 146, 470), (690, 140, 440, 432),
              (410, 600, 96, 130)]:
        kd.rectangle((r[0], r[1], r[0] + r[2], r[1] + r[3]), fill=0)
    wall = mask_rects([(0, 24, W, 561)])
    return shade(img, color, scale_mask(mmul(mmul(m, keep), wall), alpha))


def wet_door_sheen(img: Image.Image, rng: random.Random) -> Image.Image:
    """Seawater running down the inside of the outer door, from its glass to the mat:
    five broad dark runs, each with a lit edge, pooling on the mat and the boards."""
    slab = ImageChops.subtract(mask_rects([OUTER_SLAB]), mask_rects([(336, 516, 32, 88)]))
    dark = Image.new("L", (W, H), 0)
    hi = Image.new("L", (W, H), 0)
    dd, hd = ImageDraw.Draw(dark), ImageDraw.Draw(hi)
    runs = [(182, 16), (212, 26), (248, 14), (282, 30), (318, 18)]
    for x0, wdt in runs:
        ph = rng.uniform(0, 6.28)
        left, right = [], []
        y = 418
        while y <= 908:
            grow = 1 + 0.35 * (y - 418) / 490
            ww = wdt * grow * (0.82 + 0.18 * math.sin(y * 0.027 + ph))
            xx = x0 + 3.0 * math.sin(y * 0.013 + ph) + 1.2 * math.sin(y * 0.061 + ph * 2)
            left.append((xx - ww / 2, y))
            right.append((xx + ww / 2, y))
            y += 4
        dd.polygon(left + right[::-1], fill=255)
        hd.line(left[2:], fill=255, width=3)
        hd.line([(x + wdt * 0.32, yy) for (x, yy) in left[10::]], fill=110, width=1)
    dd.rectangle((158, 410, 334, 428), fill=255)               # a film over the bottom bead
    dark = mmul(dark.filter(ImageFilter.GaussianBlur(1.6)), slab)
    hi = mmul(hi.filter(ImageFilter.GaussianBlur(0.7)), slab)
    sheet = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sheet).polygon([(160, 420), (334, 420), (336, 908), (150, 908)], fill=255)
    sheet = mmul(sheet.filter(ImageFilter.GaussianBlur(8)), slab)
    img = shade(img, (176, 190, 198), sheet)                   # the whole lower door is wet
    img = shade(img, (104, 128, 146), dark)                    # and darker where it runs
    img = tint(img, (176, 206, 218), hi, 0.32)
    # beads hanging under the glazing bead, each with a lamp glint
    beads = Image.new("L", (W, H), 0)
    glints = Image.new("L", (W, H), 0)
    bd, gd = ImageDraw.Draw(beads), ImageDraw.Draw(glints)
    for x0, wdt in runs:
        for _ in range(3):
            x, y, rr = x0 + rng.uniform(-wdt / 2, wdt / 2), rng.uniform(440, 880), rng.uniform(2.5, 4.0)
            bd.ellipse((x - rr, y - rr * 1.3, x + rr, y + rr * 1.3), fill=255)
            gd.ellipse((x - rr * 0.55, y - rr * 0.9, x - rr * 0.05, y - rr * 0.2), fill=255)
        x = x0 + rng.uniform(-3, 3)
        bd.ellipse((x - 4, 426, x + 4, 438), fill=255)
        gd.ellipse((x - 2.2, 428, x - 0.4, 432), fill=255)
    img = tint(img, (150, 184, 198), mmul(beads, slab), 0.55)
    img = tint(img, (240, 246, 244), glints, 0.85)
    # the mat soaked through, a sheet of water spreading on the boards
    pud = Image.new("L", (W, H), 0)
    pd = ImageDraw.Draw(pud)
    pd.rectangle((116, 905, 376, 931), fill=255)
    pts = []
    for i in range(72):
        a = i / 72 * 2 * math.pi
        rr = 1 + 0.10 * math.sin(3 * a + 0.4) + 0.07 * math.sin(7 * a + 2.0) + rng.uniform(-0.03, 0.03)
        pts.append((248 + 176 * rr * math.cos(a), 936 + 24 * rr * math.sin(a)))
    pd.polygon(pts, fill=255)
    pud = mmul(pud, mask_rects([(0, 907, W, H)])).filter(ImageFilter.GaussianBlur(1.5))
    img = shade(img, (150, 158, 168), pud)
    img = tint(img, TEAL, pud, 0.22)                             # it holds the door's colour
    rim = Image.new("L", (W, H), 0)
    ImageDraw.Draw(rim).line(pts[4:32], fill=255, width=2)
    sheen = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sheen).ellipse((150, 938, 330, 948), fill=255)
    img = tint(img, (206, 222, 226), rim.filter(ImageFilter.GaussianBlur(0.6)), 0.55)
    img = tint(img, (196, 214, 220), sheen.filter(ImageFilter.GaussianBlur(3)), 0.35)
    return img


def entry_wall(state: str, k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    img = paint_entry_geometry(state, SEED + 900)      # one geometry seed: every state shares its lines
    img = cork_grain(img, random.Random(SEED + 901))
    if state == "damp":
        img = tide_line(img, rng, 700)
        img = baro_fog(img, rng)
        img = wall_stains(img, rng, (210, 218, 206), 0.45)
    elif state == "ominous":
        img = tide_line(img, rng, 640, dark=(160, 172, 180), bloom=0.38, amp=7)
        img = baro_fog(img, rng, 0.72)
        img = wall_stains(img, rng, (176, 190, 184), 0.85)
        img = wet_door_sheen(img, rng)
    if state == "day":
        img = tint(img, (214, 216, 212), Image.new("L", (W, H), 255), 0.07)
        img = floor_spill(img, 0.10, (190, 182, 166))
    else:
        img = floor_spill(img)
    return grain(img, rng)


# ---------------------------------------------------------------------------
# VIEW B overlays
# ---------------------------------------------------------------------------
def b_damp_low(k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    ph = rng.uniform(0, 6.28)
    pts = [(40, 905)]
    for x in range(40, 470, 4):
        mid = 1 - abs(x - 246) / 230.0
        top = 905 - 60 * clamp(0.35 + 0.75 * mid) - 5 * math.sin(x * 0.045 + ph) - 2 * math.sin(x * 0.11)
        pts.append((x, top))
    pts.append((470, 905))
    d.polygon(pts, fill=255)
    d.ellipse((90, 900, 410, 940), fill=230)               # wet boards before the mat
    m = m.filter(ImageFilter.GaussianBlur(3.5))
    mott = noise(rng, W, H, 12, 2.0).point(lambda v: 150 + v * 105 // 255)
    m = mmul(m, mott)
    im.paste(rgba((20, 34, 44)), (0, 0), scale_mask(m, 0.55))
    # the tide-mark rim of the damp
    rim = Image.new("L", (W, H), 0)
    ImageDraw.Draw(rim).line(pts[1:-1], fill=255, width=2)
    rim = rim.filter(ImageFilter.GaussianBlur(1.0))
    lay = Image.new("RGBA", (W, H), rgba(SALT))
    lay.putalpha(scale_mask(mmul(rim, noise(rng, W, H, 5, 1.0).point(lambda v: 255 if v > 90 else 0)), 0.4))
    im.alpha_composite(lay)
    return grain(im, rng, 0.04)


def b_service_open(k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    c = Canvas(W, H, SEED + k, 2)
    c.box(1386, 150, 18, 758, (12, 18, 26), INK, 2.0, 0.3)
    c.box(1393, 168, 3.5, 724, (214, 160, 92), None, 0)    # lit kitchen corridor, far in
    c.box(1393, 168, 3.5, 60, (238, 196, 128), None, 0)
    c.line([(1386, 150), (1386, 908)], INK, 3.0, 0.3)      # the slab's latch edge, now proud
    im = c.result()
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).rectangle((1390, 170, 1399, 890), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(3))
    lay = Image.new("RGBA", (W, H), rgba((214, 160, 92)))
    lay.putalpha(scale_mask(mmul(glow, mask_rects([(1388, 152, 14, 754)])), 0.35))
    im.alpha_composite(lay)
    return grain(im, rng, 0.04)


BOARD_PAPERS = {"contract": (736, 186, 110, 150), "clipping": (858, 186, 110, 190), "letter": (980, 186, 110, 170)}


def b_board_papers(k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    c = Canvas(W, H, SEED + k, 2)
    x, y, w, h = BOARD_PAPERS["contract"]
    paper_sheet(c, x, y, w, h, PAPER, 2.0)
    c.line([(x + 8, y + 14), (x + w - 8, y + 14)], INK, 1.6, 0.2)
    c.line([(x + 8, y + 18), (x + w - 8, y + 18)], INK, 1.0, 0.2)
    ruled(c, x, y + 22, w, h - 50, 9, mix(PAPER, INK, 0.2), 1.0, 10)
    c.line([(x + 60, y + 132), (x + w - 10, y + 132)], INK, 1.2, 0.2)
    x, y, w, h = BOARD_PAPERS["clipping"]
    paper_sheet(c, x, y, w, h, NEWS, 2.0)
    c.line([(x + 8, y + 22), (x + w - 8, y + 22)], mix(NEWS, INK, 0.4), 1.2, 0.2)
    c.line([(x + w / 2, y + 30), (x + w / 2, y + h - 10)], mix(NEWS, INK, 0.22), 1.0, 0.2)
    for col in (0, 1):
        x0 = x + 8 + col * (w / 2)
        yy = y + 32
        while yy < y + h - 12:
            c.line([(x0, yy), (x0 + w / 2 - 16, yy)], mix(NEWS, INK, 0.1), 1.6, 0.15)
            yy += 7
    x, y, w, h = BOARD_PAPERS["letter"]
    paper_sheet(c, x, y, w, h, mix(PAPER, (236, 232, 218), 0.5), 2.0)
    c.line([(x + 8, y + 18), (x + w - 8, y + 18)], mix(TEAL, PAPER, 0.25), 1.4, 0.2)
    ruled(c, x, y + 22, w, h - 50, 10, mix(PAPER, TEAL, 0.22), 1.0, 10)
    for (px, py) in ((791, 192), (913, 192), (1035, 192)):
        brass_head(c, px, py, 5.5)
    im = c.result()
    im.alpha_composite(seal_sprite(False, SEED + 500).resize((30, 30), Image.LANCZOS), (1035 - 15, 330 - 15))
    return grain(im, rng, 0.05)


def b_board_solved(k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    c = Canvas(W, H, SEED + k, 2)
    stamp_block(c, 852, 400, 132, 22, rng)
    # the intact seal is papered over by the broken one (both overlays stack)
    note = mix(PAPER, (236, 232, 218), 0.5)
    c.circle(1035, 330, 15.5, note, None, 0, 0)
    for yy in (322, 332, 342):
        if 186 + 22 < yy < 186 + 170 - 28:
            c.line([(1019, yy), (1051, yy)], mix(PAPER, TEAL, 0.22), 1.0, 0)
    x, y, w, h = 1040, 300, 56, 66
    im0 = c.result()
    im0.alpha_composite(seal_sprite(True, SEED + 500).resize((32, 32), Image.LANCZOS), (1033 - 16, 330 - 16))
    c.im = im0.resize((W * 2, H * 2), Image.NEAREST)
    c.d = ImageDraw.Draw(c.im)
    # the night print, pinned over the letter's corner: the station dark, one lower pane lit
    c.box(x, y, w, h, CARD, INK, 2.0)
    c.box(x + 5, y + 5, w - 10, h - 15, (22, 30, 42), INK, 1.2)
    c.poly([(x + 5, y + 36), (x + 18, y + 26), (x + 34, y + 26), (x + 51, y + 34), (x + 51, y + 56), (x + 5, y + 56)],
           (12, 18, 26), None, 0)
    c.box(x + 22, y + 34, 12, 16, (36, 46, 60), None, 0)
    c.box(x + 23, y + 43, 10, 6, AMBER, None, 0)
    brass_head(c, x + w / 2, y + 5, 4)
    return grain(c.result(), rng, 0.05)


def stamp_block(c: Canvas, x, y, w, h, rng: random.Random):
    """Brick-red rubber-stamp impression: double border, uneven ink, blank inside."""
    lay = c.layer()
    c.box(x, y, w, h, None, RED, 2.6, 0.3, im=lay)
    c.box(x + 4, y + 4, w - 8, h - 8, None, RED, 1.3, 0.3, im=lay)
    tintl = c.layer()
    ImageDraw.Draw(tintl).rectangle(c.S([(x + 5, y + 5), (x + w - 5, y + h - 5)]), fill=rgba(RED, 46))
    lay.alpha_composite(tintl)
    nz = noise(rng, lay.size[0], lay.size[1], 3 * c.ss, 1.0).point(lambda v: 40 if v < 60 else 255)
    lay.putalpha(ImageChops.multiply(lay.getchannel("A"), nz))
    c.comp(lay, 0.95)


# ---------------------------------------------------------------------------
# outer door glass insets (156 x 196), R01 seen through the door
# ---------------------------------------------------------------------------
GW, GH = 156, 196


def outside(state: str, k: int) -> Image.Image:
    """R01 through the outer door's four lights. Flat elevation, view A's window language:
    pale flat cloud, slate headland, jetty to the right, wave strokes."""
    rng = random.Random(SEED + k)
    c = Canvas(GW, GH, SEED + k, 4, (0, 0, 0, 255))
    hz = 144.0
    skies = {
        "0": ((148, 158, 172), (196, 190, 186)), "boat": ((140, 150, 166), (188, 184, 182)),
        "1": ((104, 116, 132), (150, 158, 168)), "2": ((84, 96, 112), (120, 130, 142)),
        "3": ((80, 92, 108), (112, 122, 134)), "4": ((78, 90, 106), (108, 118, 130)),
        "5": ((114, 122, 130), (114, 122, 130)), "6": ((30, 38, 52), (52, 62, 78)),
        "7": ((40, 48, 62), (60, 68, 82)), "day": ((186, 192, 196), (212, 214, 210)),
    }
    seas = {"0": (98, 112, 126), "boat": (94, 108, 122), "1": (76, 90, 106), "2": (62, 76, 92),
            "3": (60, 74, 90), "4": (58, 72, 88), "5": (114, 122, 130), "6": (26, 34, 48),
            "7": (22, 28, 40), "day": (150, 162, 166)}
    top, low = skies[state]
    sea = seas[state]
    sil = {"day": (100, 110, 118), "6": (20, 28, 40)}.get(state, SLATE if state in ("0", "boat") else (46, 56, 68))
    for yy in range(GH):
        c.d.rectangle((0, yy * 4, GW * 4, yy * 4 + 4), fill=rgba(mix(top, low, clamp(yy / hz))))
    # cloud: pale flat lumps in fair states, a low lumpy ceiling hanging down in the rain
    if state in ("0", "boat", "day"):
        cc = mix(low, (238, 238, 234), 0.45)
        for (x0, yb, wdt) in ((-6, 46, 70), (60, 30, 56), (96, 70, 70), (10, 122, 44), (104, 128, 56)):
            pts = [(x0, yb)]
            n = 6
            for i in range(n + 1):
                x = x0 + wdt * i / n
                pts.append((x, yb - rng.uniform(4, 11) * math.sin(math.pi * i / n) - 2))
            pts.append((x0 + wdt, yb))
            c.poly(pts, cc, None, 0)
    elif state in ("1", "2", "3", "4"):
        ceil = {"1": 52, "2": 70, "3": 74, "4": 74}[state]
        for row, (yb, col) in enumerate(((ceil, mix(top, (18, 24, 34), 0.3)), (ceil - 20, mix(top, (18, 24, 34), 0.5)))):
            # a low ceiling hanging down in soft rounded lobes
            c.box(-4, -4, GW + 8, yb + 4, col, None, 0)
            x = -6 + rng.uniform(0, 8)
            while x < GW + 6:
                rr = rng.uniform(7, 13)
                c.circle(x + rr, yb + rng.uniform(-1, 3), rr, col, None, 0, 0, ry=rr * 0.6)
                x += rr * rng.uniform(1.4, 1.9)
    tilt = state == "4"

    def hz_at(x):
        return hz + 22 - 44 * x / GW if tilt else hz

    c.poly([(-1, hz_at(-1)), (GW + 1, hz_at(GW + 1)), (GW + 1, GH + 1), (-1, GH + 1)], sea, None, 0)
    if state == "7":
        # a near-black wall standing in the sea, its top out of sight
        c.box(-2, -2, GW + 4, hz + 8, (12, 15, 22), None, 0)
        for i in range(16):
            x = rng.uniform(0, GW)
            c.line([(x, -2), (x + rng.uniform(-1.5, 1.5), hz + 6)], (22, 27, 36), rng.uniform(0.6, 1.8), 0.5)
        c.line([(-2, hz + 7), (GW + 2, hz + 7)], (64, 74, 90), 0.9, 0.4)
    if state not in ("5", "7"):
        h0 = hz_at(0)
        land = [(-2, h0 + 0.5), (-2, h0 - 14), (8, h0 - 16), (22, h0 - 18), (34, h0 - 16), (46, h0 - 9),
                (58, h0 - 2), (66, h0 + 0.5)]
        c.poly(land, sil, INK, 1.1, 0.2)
        if state != "6":
            lx, ly = 22, h0 - 18
            tower = mix(sil, (232, 230, 222), 0.55 if state in ("0", "boat", "day") else 0.3)
            c.poly([(lx - 3.6, ly), (lx - 2.6, ly - 14), (lx + 2.6, ly - 14), (lx + 3.6, ly)], tower, INK, 0.9, 0.1)
            c.box(lx - 3.4, ly - 19, 6.8, 5, tower, INK, 0.9, 0.1)
            c.poly([(lx - 4.6, ly - 19), (lx, ly - 23), (lx + 4.6, ly - 19)], sil, INK, 0.9, 0.1)
            if state in ("1", "2", "3", "4"):
                c.box(lx - 2, ly - 18, 4, 3, AMBER, None, 0)
    if state == "0":
        lx, y = 60, hz
        col = (34, 44, 56)
        c.poly([(lx - 6, y - 1.5), (lx + 7, y - 1.5), (lx + 5, y + 1), (lx - 4, y + 1)], col, None, 0)
        c.box(lx - 2, y - 4.5, 5, 3, col, None, 0)
        c.line([(lx + 1, y - 4.5), (lx + 1, y - 10)], col, 0.6, 0)
    # waves
    if state != "5":
        wave_col = mix(sea, (236, 236, 230), 0.3 if state != "day" else 0.22)
        nwaves = {"7": 3, "day": 4}.get(state, 6)
        for i in range(nwaves):
            y = hz + 6 + i * (GH - hz - 6) / nwaves + rng.uniform(-1.5, 1.5)
            x = rng.uniform(-10, 14)
            while x < GW:
                L = rng.uniform(10, 24)
                amp = 0.5 if state == "day" else 1.0
                pts = [(x + j, y + amp * math.sin((x + j) * 0.55)) for j in range(0, int(L), 2)]
                if len(pts) > 1:
                    c.line(pts, wave_col, 0.8, 0)
                x += L + rng.uniform(6, 16)
    # the jetty: deck, nine pilings, bell post, shed
    deck_y = 156
    pil = [94 + i * 7.8 for i in range(9)]
    lit = state in ("6", "7")
    pcol = (206, 200, 184) if lit else ((108, 116, 122) if state == "day" else sil)
    dcol = (220, 212, 192) if lit else ((122, 128, 132) if state == "day" else mix(sil, (0, 0, 0), 0.1))
    if state == "6":
        # lit from behind the station: every piling throws its shadow out to sea
        # a lit sheet of water around the jetty, crossed by the pilings' shadows
        c.poly([(70, 192), (GW + 2, 192), (GW + 2, hz + 1), (100, hz + 1)], (98, 104, 112), None, 0)
        for px in pil:
            c.poly([(px - 1.8, 178), (px + 1.8, 178), (px + 24, hz + 1), (px + 19, hz + 1)], (16, 22, 32), None, 0)
    for px in pil:
        c.box(px - 1.8, deck_y - 3, 3.6, 23, pcol, INK, 0.9, 0.1)
        if state == "3":
            c.box(px - 1.4 + 5, 180, 2.8, 10, mix(sea, pcol, 0.6), None, 0)   # reflections, sideways
        elif state in ("0", "boat", "1", "2", "4", "day"):
            c.box(px - 1.2, 180, 2.4, 8, mix(sea, pcol, 0.4), None, 0)
    if state == "3":
        c.box(85, 166, 4.2, 10, pcol, INK, 0.9, 0.1)            # a tenth stump, past the end
        c.line([(86, 167), (86, 175)], mix(pcol, (230, 230, 220), 0.5), 0.6, 0)
        c.box(85.4 + 5, 180, 3, 6, mix(sea, pcol, 0.6), None, 0)
    c.box(88, deck_y, GW - 86, 4, dcol, INK, 0.9, 0.1)
    c.line([(88, deck_y + 10), (GW + 2, deck_y + 10)], pcol, 0.8, 0.1)
    c.box(100, 114, 3, 42, pcol, INK, 0.8, 0.1)                   # bell post
    c.line([(101.5, 116), (92, 116)], pcol, 1.2, 0.1)
    c.line([(92, 116), (92, 168)], INK, 0.5, 0)
    bell = (196, 150, 80) if lit else mix(BRASS_D, sil, 0.45)
    c.poly([(89.6, 168), (94.4, 168), (95.6, 175), (88.4, 175)], bell, INK, 0.7, 0)
    shc = (206, 200, 184) if lit else ((114, 122, 128) if state == "day" else mix(sil, (0, 0, 0), 0.05))
    c.poly([(132, 156), (132, 136), (144, 127), (157, 136), (157, 156)], shc, INK, 1.0, 0.1)
    c.box(137, 140, 6, 8, (36, 44, 56) if not lit else (92, 98, 106), None, 0)
    if state in ("boat", "day"):
        launch(c, 90, 188, state == "boat", 3 if state == "boat" else 2, sx=1.25, sy=1.05,
               col=(30, 40, 52) if state == "boat" else (58, 68, 80),
               window_col=AMBER if state == "boat" else (176, 178, 172), lw=0.8)
    if state == "1":
        # a mooring line from the deck to the water, the capsule hanging open on it
        c.line([(110, deck_y + 4), (102, 166), (96, 174), (86, 182)], (34, 42, 52), 0.8, 0)
        cx, cy = 101, 170
        c.line([(cx, 167), (cx, 170)], (34, 42, 52), 0.6, 0)
        c.poly([(cx - 4.5, 170), (cx + 0.5, 170), (cx + 0.5, 182), (cx - 4.5, 182)], (200, 172, 116), INK, 0.8, 0)
        c.poly([(cx + 0.5, 170), (cx + 7, 167), (cx + 8, 179), (cx + 0.5, 182)], (152, 124, 82), INK, 0.8, 0)
        c.box(cx - 3.5, 172, 3, 8, (40, 34, 30), None, 0)          # empty inside
    if state in ("1", "2", "3", "4", "5"):
        dens = {"1": 70, "2": 230, "3": 110, "4": 110, "5": 110}[state]
        lay = c.layer()
        for _ in range(dens):
            x, y = rng.uniform(-10, GW + 10), rng.uniform(-10, GH)
            L = rng.uniform(4, 9) if state != "2" else rng.uniform(7, 14)
            c.line([(x, y), (x - L * 0.25, y + L)], (214, 220, 226, 150), 0.5, 0, im=lay)
        c.comp(lay)
    if state == "2":
        lay = c.layer()
        g = Image.linear_gradient("L").rotate(90, expand=True).resize(lay.size)
        g = g.point(lambda v: int(clamp((v - 60) / 150.0) ** 1.1 * 235))
        veil = Image.new("RGBA", lay.size, rgba(mix(top, low, 0.6)))
        band = Image.new("L", lay.size, 0)
        ImageDraw.Draw(band).rectangle((0, 100 * 4, GW * 4, 192 * 4), fill=255)
        band = band.filter(ImageFilter.GaussianBlur(36))
        veil.putalpha(ImageChops.multiply(g, band))
        c.comp(veil)
    # the door's own muntin cross (6 px) and a seating border
    c.box(GW / 2 - 3, -2, 6, GH + 4, TEAL, None, 0)
    c.box(-2, GH / 2 - 3, GW + 4, 6, TEAL, None, 0)
    for a in (-3, 3):
        c.line([(GW / 2 + a, 0), (GW / 2 + a, GH)], INK, 1.2, 0.1)
        c.line([(0, GH / 2 + a), (GW, GH / 2 + a)], INK, 1.2, 0.1)
    c.box(0, 0, GW, GH, None, INK, 2.2, 0.1)
    img = c.result()
    sheen = Image.new("L", (GW, GH), 0)
    sd = ImageDraw.Draw(sheen)
    for (px, py) in ((4, 4), (82, 4), (4, 102), (82, 102)):
        sd.polygon([(px, py + 30), (px + 30, py), (px + 42, py), (px, py + 42)], fill=255)
    sheen = sheen.filter(ImageFilter.GaussianBlur(4))
    img = tint(img, (230, 236, 240), sheen, 0.07 if state not in ("6", "7") else 0.05)
    return grain(img, rng, 0.05)


def launch(c: Canvas, x, wl, lit_window: bool, stripes: int, sx=1.0, sy=1.0, col=(30, 40, 52),
           pennant_bg=PAPER, window_col=None, lw=0.8, pennant=1.0):
    """The collection launch in flat silhouette, bow to the left: x = bow, wl = waterline.
    Unit hull is 44 long and 38 high to the masthead; sx/sy stretch it, `pennant` sizes the flag."""
    def P(u, v):
        return (x + u * sx, wl - v * sy)
    hull = [P(0, 9), P(6, 6), P(40, 6), P(44, 10), P(44, 4), P(38, 0), P(8, 0)]
    c.poly(hull, col, INK, lw, 0.1)
    c.poly([P(16, 6), P(17, 17), P(34, 17), P(34, 6)], col, INK, lw, 0.1)
    wc = window_col or (AMBER if lit_window else (150, 156, 158))
    a, b = P(21, 14), P(29, 9)
    c.box(a[0], a[1], b[0] - a[0], b[1] - a[1], wc, None, 0)
    mx = x + 26 * sx
    c.line([P(26, 17), P(26, 38)], col, max(0.8, lw * 1.2), 0)
    s = min(sx, sy) * pennant
    pl, ph = 22 * s, 10 * s
    topy = wl - 38 * sy
    c.poly([(mx, topy), (mx + pl, topy + ph / 2), (mx, topy + ph)], pennant_bg, INK, max(0.6, lw * 0.8), 0)
    band = ph / (2 * stripes + 1)

    def xr(yy):
        return mx + pl * (1 - abs(yy - (topy + ph / 2)) / (ph / 2))
    for i in range(stripes):
        y0 = topy + band * (2 * i + 1)
        y1 = y0 + band
        c.poly([(mx, y0), (xr(y0), y0), (xr(y1), y1), (mx, y1)], INK, None, 0)


# ---------------------------------------------------------------------------
# VIEW A overlays (registered to office_arrival.png)
# ---------------------------------------------------------------------------
def hook_tags(k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    c = Canvas(W, H, SEED + k, 2)
    for x in HOOKS:
        tag = [(x - 16, 216), (x - 10, 212), (x + 10, 212), (x + 16, 216), (x + 16, 256), (x - 16, 256)]
        face = mix(mix(BRASS, BRASS_D, 0.45), (120, 124, 104), 0.22)      # tarnished, matte
        c.poly(tag, face, INK, 2.0, 0.3)
        c.poly([(x - 13, 219), (x - 8, 215), (x + 8, 215), (x + 13, 219), (x + 13, 253), (x - 13, 253)],
               None, mix(face, BRASS_L, 0.45), 1.0, 0.2)
        c.circle(x, 222, 3.4, (36, 30, 22), INK, 1.0, 0)   # punched hole
        c.circle(x, 216, 2.6, (70, 66, 60), INK, 1.2, 0)   # nail head through the hole... at the nail
        c.circle(x - 0.8, 215.2, 0.9, (150, 146, 136), None, 0, 0)
        c.line([(x, 218.5), (x, 222)], (52, 48, 42), 1.6, 0)
    im = c.result()
    return grain(im, rng, 0.05)


def damp_bloom(rng: random.Random, rect, drips=4) -> Image.Image:
    """A damp bloom under a sill end: a ragged head and long uneven tongues, clipped to rect."""
    x, y, w, h = rect
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    head = []
    for i in range(40):
        a = i / 40 * 2 * math.pi
        rr = 1 + 0.18 * math.sin(3 * a + rng.uniform(0, 6)) + rng.uniform(-0.08, 0.08)
        head.append((x + w / 2 + w * 0.48 * rr * math.cos(a), y + 26 + 26 * rr * math.sin(a)))
    d.polygon(head, fill=255)
    for i in range(drips):
        cx = x + w * (i + 0.5) / drips + rng.uniform(-3, 3)
        L = h * rng.uniform(0.45, 0.98)
        ww = rng.uniform(5, 11)
        for j in range(int(L)):
            t = j / L
            r = ww * (1 - t) ** 0.7 / 2 + 0.8
            d.ellipse((cx - r, y + 20 + j - 2, cx + r, y + 20 + j + 2), fill=255)
            cx += rng.uniform(-0.35, 0.35)
        d.ellipse((cx - 2.4, y + 20 + L - 3, cx + 2.4, y + 20 + L + 3), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(1.6))
    return mmul(m, mask_rects([rect]))


def damp_sill(k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    m = ImageChops.lighter(damp_bloom(rng, (392, 560, 40, 170), 3), damp_bloom(rng, (858, 560, 46, 100), 3))
    mott = noise(rng, W, H, 8, 1.5).point(lambda v: 160 + v * 95 // 255)
    im.paste(rgba((22, 38, 44)), (0, 0), scale_mask(mmul(m, mott), 0.42))
    hard = m.point(lambda v: 255 if v > 90 else 0)
    edge = ImageChops.subtract(hard, hard.filter(ImageFilter.MinFilter(3))).filter(ImageFilter.GaussianBlur(0.6))
    lay = Image.new("RGBA", (W, H), rgba((18, 30, 36)))
    lay.putalpha(scale_mask(edge, 0.55))
    im.alpha_composite(lay)
    return grain(im, rng, 0.04)


def drawer_gap(variant: str, k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    c = Canvas(W, H, SEED + k, 4)
    c.box(842, 756, 132, 10, (16, 14, 14), INK, 1.6, 0.15)
    if variant != "empty":
        # the print's corner, tipped up out of the gap
        quad = [(930, 761), (933, 744), (962, 741.5), (962, 761)]
        c.poly(quad, CARD, INK, 1.4, 0.05)
        img = [(934.5, 761), (936.8, 747.5), (962, 745.5), (962, 761)]
        c.poly(img, (24, 30, 42), None, 0)
        if variant == "after":
            c.box(949, 751, 4, 4, AMBER, None, 0)
        elif variant == "turned":
            c.circle(948, 753, 3.0, (214, 210, 196), None, 0, 0, ry=4.0)
        # the drawer front hides the rest
        c.box(842, 761, 132, 5, (16, 14, 14), None, 0)
    else:
        c.circle(905, 762, 6, BRASS_D, INK, 1.2, 0.05, ry=2.6)
        c.box(902, 760.5, 5, 1.6, BRASS_L, None, 0)
        c.circle(912, 762, 1.4, (250, 230, 180), None, 0, 0)
    c.line([(842, 766), (974, 766)], INK, 1.6, 0.1)
    return grain(c.result(), rng, 0.03)


def pane_mask() -> Image.Image:
    """The glass exactly (as painter_1 measures it): pane rects plus any rim pixel that is
    still glass. The sash catch is put back on top afterwards (restore_catch)."""
    plate = Image.open(ROOT / "assets/backgrounds/office_arrival.png").convert("RGB")
    px = plate.load()
    m = mask_rects(PANES)
    mp = m.load()

    def lum(p):
        return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
    for x, y, w, h in PANES:
        rim = [(x - 1, j) for j in range(y, y + h)] + [(x + w, j) for j in range(y, y + h)]
        rim += [(i, y - 1) for i in range(x, x + w)] + [(i, y + h) for i in range(x, x + w)]
        for i, j in rim:
            r, g, b = px[i, j]
            if lum((r, g, b)) > 60 and b - r < 35 and g - r < 22:
                mp[i, j] = 255
    return m


def restore_catch(im: Image.Image) -> Image.Image:
    """Put the plate's own sash catch back on top: it sits on the meeting rail over the glass."""
    plate = Image.open(ROOT / "assets/backgrounds/office_arrival.png").convert("RGBA")
    box = (612, 330, 672, 364)
    crop = plate.crop(box)
    l = crop.convert("L").point(lambda v: 255 if v < 120 else (0 if v > 170 else int((170 - v) * 255 / 50)))
    crop.putalpha(l)
    out = im.copy()
    out.alpha_composite(crop, (box[0], box[1]))
    return out


def window_day(k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    c = Canvas(W, H, SEED + k, 2)
    sky_t, sky_b = (196, 202, 204), (214, 216, 212)
    for yy in range(143, 546):
        t = clamp((yy - 143) / 330.0)
        c.d.rectangle((482 * 2, yy * 2, 801 * 2, yy * 2 + 2), fill=rgba(mix(sky_t, sky_b, t)))
    # high pale cloud in the upper sash
    for row, yb in enumerate((236, 330, 440)):
        pts = [(480, yb + 14)]
        x = 480
        while x < 806:
            pts.append((x, yb - rng.uniform(4, 16)))
            x += rng.uniform(18, 34)
        pts.append((806, yb + 14))
        c.poly(pts, mix(sky_b, (240, 240, 236), 0.6), None, 0)
    hz = 474.5
    sea = (152, 164, 168)
    c.box(480, hz, 324, 75, sea, None, 0)
    c.line([(480, hz), (806, hz)], mix(sea, INK, 0.25), 1.2, 0.1)
    for i in range(6):
        y = hz + 9 + i * 11 + rng.uniform(-2, 2)
        x = 484 + rng.uniform(0, 20)
        while x < 800:
            L = rng.uniform(18, 40)
            c.line([(x, y), (x + L, y)], mix(sea, (236, 236, 230), 0.3), 1.0, 0.3)
            x += L + rng.uniform(16, 36)
    land = (104, 114, 120)
    c.poly([(480, hz), (480, 432), (496, 430), (520, 428), (540, 430), (560, 436), (582, 450), (604, 466),
            (612, hz)], land, INK, 1.8, 0.3)
    lx = 540
    c.poly([(lx - 6, 430), (lx - 5, 413), (lx + 5, 413), (lx + 6, 430)], (214, 212, 202), INK, 1.4, 0.15)
    c.box(lx - 6, 405, 12, 8, (196, 196, 188), INK, 1.4, 0.15)
    c.poly([(lx - 8, 405), (lx, 397), (lx + 8, 405)], land, INK, 1.4, 0.1)
    # jetty, bell post with lamp, shed (as on the plate)
    pcol = (98, 106, 112)
    for i in range(8):
        px = 646 + i * 21
        c.box(px - 4, 456, 8, 54, pcol, INK, 1.6, 0.2)
        c.box(px - 3, 512, 6, 14, mix(sea, pcol, 0.35), None, 0)
    c.box(640, 474, 166, 8, (118, 124, 128), INK, 1.6, 0.2)
    c.box(714, 388, 7, 86, pcol, INK, 1.5, 0.2)
    c.line([(717, 392), (704, 392), (704, 400)], pcol, 2.0, 0.1)
    c.poly([(699, 401), (709, 401), (707, 410), (701, 410)], pcol, INK, 1.2, 0.1)
    c.poly([(750, 474), (750, 432), (771, 416), (794, 432), (794, 474)], (120, 128, 132), INK, 1.8, 0.2)
    c.box(760, 440, 10, 12, (70, 78, 86), INK, 1.0, 0.1)
    c.box(778, 440, 10, 12, (70, 78, 86), INK, 1.0, 0.1)
    # the real launch at the jetty end, two stripes, its cabin window showing its own empty cabin
    launch(c, 572, 494, False, 2, sx=1.6, sy=1.5, col=(54, 64, 76), window_col=(170, 172, 168), lw=1.4)
    im = c.result()
    clip = pane_mask()
    im.putalpha(ImageChops.multiply(im.getchannel("A"), clip))
    return restore_catch(grain(im, rng, 0.05))


def window_surface(k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    im = Image.new("RGBA", (W, H), rgba((14, 18, 26)))
    # very slow vertical striation, so it reads as a surface and not a void
    st = noise(rng, W, H, 1, 0.0).resize((W // 6, 1)).resize((W, H), Image.BICUBIC)
    st = ImageOps.autocontrast(st.filter(ImageFilter.GaussianBlur(1)))
    lifted = apply_signed(im, st, 0.05)
    mott = noise(rng, W, H, 40, 4.0)
    lifted = apply_signed(lifted, mott, 0.035)
    # a faint wet sheen where the room's lamp touches it, lower left
    sh = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sh).ellipse((420, 440, 640, 600), fill=255)
    sh = sh.filter(ImageFilter.GaussianBlur(50))
    lifted = tint(lifted, (52, 62, 74), sh, 0.5)
    c = Canvas(W, H, SEED + k, 4)
    c.im = lifted.resize((W * 4, H * 4), Image.NEAREST)
    c.d = ImageDraw.Draw(c.im)
    c.box(772, 500, 7, 4.5, (234, 178, 96), None, 0)        # one small warm rectangle, far off
    out = c.result()
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((764, 494, 786, 512), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(5))
    out = tint(out, (180, 126, 64), glow, 0.35)
    out = grain(out, rng, 0.03)
    out.putalpha(pane_mask())
    return restore_catch(out)


# ---------------------------------------------------------------------------
# CLOSE-UPS
# ---------------------------------------------------------------------------
def c_board(k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    c = Canvas(W, H, SEED + k, 2, WALL + (255,))
    c.box(80, 56, 1288, 960, WOOD, INK, 3.0)
    c.box(90, 66, 1268, 940, None, WOOD_L, 1.8, 0.4)
    c.box(110, 86, 1228, 900, None, WOOD_D, 1.8, 0.4)
    for (x, y) in ((96, 72), (1352, 72), (96, 1000), (1352, 1000)):
        c.circle(x, y, 4.5, BRASS_D, INK, 1.4, 0.1)
    c.box(120, 96, 1208, 880, CORK, INK, 2.8)
    img0 = c.result()
    # cork granules: matte, warm, dense
    cork = mask_rects([(122, 98, 1204, 876)])
    g1 = noise(rng, W, H, 1, 0.8).point(lambda v: 255 if v > 205 else 0)
    g2 = noise(rng, W, H, 2, 0.6).point(lambda v: 255 if v < 50 else 0)
    img0 = tint(img0, CORK_D, mmul(g1, cork), 0.55)
    img0 = tint(img0, mix(CORK, PAPER, 0.4), mmul(g2, cork), 0.45)
    c.im = img0.resize((W * 2, H * 2), Image.NEAREST)
    c.d = ImageDraw.Draw(c.im)
    # three blank papers
    x, y, w, h = 170, 130, 330, 420
    c.box(x, y, w, h, PAPER, INK, 2.6, 0.7)
    c.line([(x + 24, y + 40), (x + w - 24, y + 40)], INK, 3.0, 0.4)
    c.line([(x + 24, y + 48), (x + w - 24, y + 48)], INK, 1.4, 0.4)
    c.box(x + 24, y + 58, 130, 34, None, mix(PAPER, INK, 0.4), 1.4, 0.4)
    c.box(x + w - 154, y + 58, 130, 34, None, mix(PAPER, INK, 0.4), 1.4, 0.4)
    ruled(c, x, y + 100, w, 220, 22, mix(PAPER, INK, 0.2), 1.2, 26)
    c.line([(x + w - 170, y + 352), (x + w - 26, y + 352)], INK, 1.6, 0.4)
    c.line([(x + 26, y + 352), (x + 150, y + 352)], INK, 1.6, 0.4)
    x, y, w, h = 560, 130, 330, 500
    c.box(x, y, w, h, NEWS, INK, 2.6, 0.7)
    c.line([(x + 22, y + 74), (x + w - 22, y + 74)], mix(NEWS, INK, 0.45), 1.6, 0.4)
    c.line([(x + w / 2, y + 86), (x + w / 2, y + h - 22)], mix(NEWS, INK, 0.25), 1.2, 0.4)
    for col in (0, 1):
        x0 = x + 22 + col * (w / 2)
        yy = y + 92
        while yy < y + h - 24:
            c.line([(x0, yy), (x0 + w / 2 - 34, yy)], mix(NEWS, INK, 0.07), 3.0, 0.3)
            yy += 14
    x, y, w, h = 950, 130, 330, 470
    note = mix(PAPER, (238, 234, 222), 0.5)
    c.box(x, y, w, h, note, INK, 2.6, 0.7)
    c.line([(x + 26, y + 56), (x + w - 26, y + 56)], mix(TEAL, PAPER, 0.2), 2.2, 0.4)
    c.line([(x + 50, y + 70), (x + 50, y + h - 18)], mix(RED, PAPER, 0.75), 1.0, 0.4)
    ruled(c, x, y + 70, w, h - 90, 24, mix(note, TEAL, 0.22), 1.1, 20)
    for px in (335, 725, 1115):
        brass_head(c, px, 146, 9)
    # slot pins
    for (px, py) in ((370, 720), (724, 720), (1078, 720)):
        c.circle(px, py, 24, None, mix(CORK_D, INK, 0.25), 1.4, 0.4)
        c.circle(px, py + 1, 4, (40, 34, 30), None, 0, 0)
        brass_head(c, px, py, 15)
    # provenance box
    c.box(250, 820, 520, 100, mix(PAPER, (240, 236, 222), 0.3), INK, 2.8, 0.5)
    c.box(260, 830, 500, 80, None, mix(PAPER, INK, 0.45), 1.3, 0.4)
    for (px, py) in ((262, 832), (758, 832)):
        brass_head(c, px, py, 5)
    # stamp rack: back rail, three blocks, ledge
    c.box(812, 852, 494, 26, mix(WOOD_D, WOOD, 0.3), INK, 2.4)
    for bx in (820, 984, 1148):
        cx = bx + 75
        c.box(bx, 866, 150, 46, WOOD, INK, 2.6)
        c.line([(bx + 8, 876), (bx + 142, 876)], WOOD_L, 1.4, 0.3)
        c.box(bx + 6, 912, 138, 16, (52, 40, 34), INK, 2.2)   # rubber face, uninked
        neck = [(cx - 10, 846), (cx - 9, 856), (cx - 24, 866), (cx + 24, 866), (cx + 9, 856), (cx + 10, 846)]
        c.poly(neck, WOOD_L, INK, 2.2, 0.3)
        c.circle(cx, 830, 18, WOOD_L, INK, 2.4, 0.3)
        c.circle(cx - 6, 824, 6, mix(WOOD_L, PAPER, 0.35), None, 0, 0)
    c.box(806, 928, 506, 18, WOOD, INK, 2.4)
    c.line([(810, 933), (1308, 933)], WOOD_L, 1.4, 0.3)
    return grain(c.result().convert("RGB"), rng)


def c_duty_contract(k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    w, h = 500, 760
    c = Canvas(w, h, SEED + k, 2)
    c.box(4, 4, w - 8, h - 8, PAPER, INK, 2.8, 0.7)
    c.line([(36, 44), (w - 36, 44)], INK, 3.4, 0.4)
    c.line([(36, 53), (w - 36, 53)], INK, 1.4, 0.4)
    c.box(36, 66, 196, 40, None, mix(PAPER, INK, 0.45), 1.4, 0.4)
    c.box(w - 232, 66, 196, 40, None, mix(PAPER, INK, 0.45), 1.4, 0.4)
    c.line([(36, 120), (w - 36, 120)], INK, 2.0, 0.4)
    ruled(c, 0, 120, w, 310, 24, mix(PAPER, INK, 0.2), 1.2, 40)
    # countersignature: two rules, a flourish rising off the right one (no letters)
    c.line([(36, 470), (210, 470)], INK, 1.8, 0.4)
    c.line([(250, 470), (w - 36, 470)], INK, 1.8, 0.4)
    fl = []
    for i in range(90):
        t = i / 89
        fl.append((262 + 200 * t, 466 - 20 * math.sin(t * math.pi) * (1 - t * 0.5) - 8 * math.sin(t * 14) * (1 - t)))
    c.line(fl, INK, 2.2, 0.15)
    c.line([(274 + 14 * math.cos(a), 456 + 9 * math.sin(a)) for a in [i * 0.2 for i in range(33)]], INK, 1.8, 0.1)
    # the collection launch, flat ink, filling Rect2(40,520,420,200)
    launch(c, 44, 704, False, 2, sx=412 / 44, sy=176 / 38, col=INK, window_col=PAPER, lw=2.4, pennant=1.25)
    for i in range(3):
        y = 708 + i * 5
        c.line([(60 + i * 30, y), (440 - i * 40, y)], mix(PAPER, INK, 0.5), 1.4, 0.6)
    return grain(c.result(), rng, 0.06)


def photo_back(k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    w, h = 528, 620
    c = Canvas(w, h, SEED + k, 2)
    r = 10
    card = [(r, 2), (w - r, 2), (w - 2, r), (w - 2, h - r), (w - r, h - 2), (r, h - 2), (2, h - r), (2, r)]
    c.poly(card, CARD, INK, 2.2, 0.5)
    im = c.result()
    alpha = im.getchannel("A")
    # tide stain from the lower-left corner: three dried rings, each a little further in
    for i, (rad, a_fill, a_edge) in enumerate(((176, 0.22, 0.42), (140, 0.16, 0.38), (96, 0.14, 0.34))):
        m = Image.new("L", (w, h), 0)
        pts = []
        for j in range(72):
            a = j / 72 * 2 * math.pi
            rr = rad * (1 + 0.09 * math.sin(3 * a + 0.7 + i) + 0.06 * math.sin(7 * a + 1.9 * i) + rng.uniform(-0.02, 0.02))
            pts.append((-10 + rr * 1.15 * math.cos(a), h + 20 + rr * 0.92 * math.sin(a)))
        ImageDraw.Draw(m).polygon(pts, fill=255)
        m = mmul(m.filter(ImageFilter.GaussianBlur(2.5)), alpha)
        im = tint(im, (184, 150, 108), m, a_fill)
        hard = m.point(lambda v: 255 if v > 120 else 0)
        edge = ImageChops.subtract(hard, hard.filter(ImageFilter.MinFilter(5))).filter(ImageFilter.GaussianBlur(1.0))
        im = tint(im, (128, 92, 60), edge, a_edge)
    # faint printer's mark, lower right: an oval cartouche with two bars, no words
    c2 = Canvas(w, h, SEED + k + 99, 2)
    c2.im = im.resize((w * 2, h * 2), Image.NEAREST)
    lay = c2.layer()
    mk = (118, 116, 136, 96)
    c2.circle(430, 552, 46, None, mk, 1.6, 0.3, ry=22, im=lay)
    c2.circle(430, 552, 40, None, mk, 0.9, 0.3, ry=17, im=lay)
    c2.line([(404, 548), (456, 548)], mk, 1.8, 0.2, im=lay)
    c2.line([(412, 557), (448, 557)], mk, 1.2, 0.2, im=lay)
    c2.comp(lay)
    return grain(c2.result(), rng, 0.05)


def wax_seal(k: int, broken: bool) -> Image.Image:
    rng = random.Random(SEED + k)
    im = seal_sprite(broken, SEED + 500)
    im = apply_signed(im, noise(rng, 120, 120, 4, 1.0), 0.07)
    return grain(im, rng, 0.04)


def stamp_ink(k: int) -> Image.Image:
    rng = random.Random(SEED + k)
    w, h = 360, 72
    c = Canvas(w, h, SEED + k, 2)
    lay = c.layer()
    c.box(4, 4, w - 8, h - 8, None, RED, 4.6, 0.6, im=lay)
    c.box(12, 12, w - 24, h - 24, None, RED, 2.0, 0.5, im=lay)
    inner = c.layer()
    ImageDraw.Draw(inner).rectangle(c.S([(14, 14), (w - 14, h - 14)]), fill=rgba(RED, 70))
    lay.alpha_composite(inner)
    a = lay.getchannel("A")
    blot = noise(rng, w * 2, h * 2, 6, 1.0).point(lambda v: int(130 + v * 125 / 255))
    voids = noise(rng, w * 2, h * 2, 2, 0.6).point(lambda v: 0 if v < 26 else 255)
    ramp = Image.linear_gradient("L").rotate(90, expand=True).resize((w * 2, h * 2)).point(lambda v: 255 - v // 4)
    a = ImageChops.multiply(ImageChops.multiply(ImageChops.multiply(a, blot), voids), ramp)
    lay.putalpha(a)
    c.comp(lay)
    return grain(c.result(), rng, 0.04)


def cork_grain(img: Image.Image, rng: random.Random) -> Image.Image:
    """Room-scale cork: fine dark and pale granules, kept off the strip and the pins."""
    m = mask_rects([(718, 168, 384, 294)])
    d = ImageDraw.Draw(m)
    d.rectangle((757, 393, 1063, 429), fill=0)
    for px in (812, 910, 1008):
        d.ellipse((px - 10, 428, px + 10, 448), fill=0)
    dark = noise(rng, W, H, 1, 0.5).point(lambda v: 255 if v > 200 else 0)
    pale = noise(rng, W, H, 1, 0.5).point(lambda v: 255 if v < 46 else 0)
    img = tint(img, CORK_D, mmul(dark, m), 0.6)
    img = tint(img, mix(CORK, PAPER, 0.45), mmul(pale, m), 0.5)
    return img


def seal_sprite(broken: bool, seed: int) -> Image.Image:
    """Venn's seal at 120 px: a lumpy dark-red wax disc pressed with three parallel cuts.
    Broken: the same seal split along a jagged crack, halves pulled apart, a crumb lost."""
    rng = random.Random(seed)
    ss, n = 4, 120
    c = Canvas(n, n, seed, ss)
    cx = cy = 60
    r = 44
    pts = []
    for i in range(48):
        a = i / 48 * 2 * math.pi
        rr = r * (1 + 0.06 * math.sin(3 * a + 1.1) + 0.045 * math.sin(5 * a + 0.4) + rng.uniform(-0.015, 0.015))
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    c.poly(pts, WAX, INK, 2.6, 0.2)
    c.circle(cx, cy, 31, mix(WAX, INK, 0.22), None, 0, 0)
    c.circle(cx, cy, 31, None, mix(WAX, PAPER, 0.3), 1.6, 0.2)
    dx, dy = math.cos(math.radians(-62)), math.sin(math.radians(-62))
    nx, ny = -dy, dx
    for o in (-11, 0, 11):
        p0 = (cx + nx * o - dx * 22, cy + ny * o - dy * 22)
        p1 = (cx + nx * o + dx * 22, cy + ny * o + dy * 22)
        c.line([p0, p1], (34, 12, 10), 4.2, 0.0)
        c.line([(p0[0] + 2.2, p0[1] + 0.9), (p1[0] + 2.2, p1[1] + 0.9)], mix(WAX, PAPER, 0.38), 1.2, 0.0)
    c.circle(cx - 18, cy - 22, 6, mix(WAX, PAPER, 0.18), None, 0, 0)
    whole = c.result()
    if not broken:
        return whole
    crack = [(-4, 66), (20, 58), (34, 66), (48, 54), (62, 63), (78, 50), (92, 58), (124, 48)]
    up = Image.new("L", (n, n), 0)
    ImageDraw.Draw(up).polygon([(-4, -4), (124, -4)] + crack[::-1], fill=255)
    lo = ImageChops.invert(up)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    for m, shift, rot in ((up, (-3, -7), -6.0), (lo, (4, 6), 5.0)):
        piece = whole.copy()
        piece.putalpha(ImageChops.multiply(piece.getchannel("A"), m))
        edge = ImageChops.subtract(piece.getchannel("A").point(lambda v: 255 if v > 128 else 0),
                                   piece.getchannel("A").point(lambda v: 255 if v > 128 else 0).filter(ImageFilter.MinFilter(3)))
        inked = piece.copy()
        inked.paste(rgba(INK), (0, 0), edge)
        inked = inked.rotate(rot, resample=Image.BICUBIC, center=(60, 58), translate=shift)
        out.alpha_composite(inked)
    d = ImageDraw.Draw(out)
    for (x, y, rr) in ((104, 70, 3.2), (14, 50, 2.4), (98, 86, 2.0)):
        d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=rgba(WAX), outline=rgba(INK))
    return out


# ---------------------------------------------------------------------------
def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = [
        ("entry_wall", lambda k: entry_wall("base", k)),
        ("entry_wall_damp", lambda k: entry_wall("damp", k)),
        ("entry_wall_ominous", lambda k: entry_wall("ominous", k)),
        ("entry_wall_day", lambda k: entry_wall("day", k)),
        ("b_damp_low", b_damp_low),
        ("b_service_open", b_service_open),
        ("b_board_papers", b_board_papers),
        ("b_board_solved", b_board_solved),
        ("outer_glass_0", lambda k: outside("0", k)),
        ("outer_glass_boat", lambda k: outside("boat", k)),
        ("outer_glass_1", lambda k: outside("1", k)),
        ("outer_glass_2", lambda k: outside("2", k)),
        ("outer_glass_3", lambda k: outside("3", k)),
        ("outer_glass_4", lambda k: outside("4", k)),
        ("outer_glass_5", lambda k: outside("5", k)),
        ("outer_glass_6", lambda k: outside("6", k)),
        ("outer_glass_7", lambda k: outside("7", k)),
        ("outer_glass_day", lambda k: outside("day", k)),
        ("hook_tags", hook_tags),
        ("damp_sill", damp_sill),
        ("drawer_gap", lambda k: drawer_gap("night", k)),
        ("drawer_gap_after", lambda k: drawer_gap("after", k)),
        ("drawer_gap_turned", lambda k: drawer_gap("turned", k)),
        ("drawer_gap_empty", lambda k: drawer_gap("empty", k)),
        ("window_day", window_day),
        ("window_surface", window_surface),
        ("c_board", c_board),
        ("c_duty_contract", c_duty_contract),
        ("photo_back", photo_back),
        ("venn_seal", lambda k: wax_seal(k, False)),
        ("venn_seal_broken", lambda k: wax_seal(k, True)),
        ("stamp_ink", stamp_ink),
    ]
    for k, (name, fn) in enumerate(jobs):
        im = fn(k)
        path = OUT / f"{name}.png"
        im.save(path)
        print(f"  {path.relative_to(ROOT)}  {im.size[0]}x{im.size[1]} {im.mode}")


if __name__ == "__main__":
    main()
