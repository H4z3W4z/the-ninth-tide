#!/usr/bin/env python3
"""Painter 1: the late-stage room plates and the threshold corridor.

Writes, and only writes:
    assets/stages/office_s2.png           stage-2 room (sea silent, damp rising)
    assets/stages/office_s3.png           stage-3 room (sea tipped, rings, tide line)
    assets/stages/threshold_corridor.png  the corridor behind the open door (unlit layer)

Every plate is painted over the approved arrival plate, so furniture and hotspots keep
exact registration. Python 3 + PIL only. Deterministic: one seeded random.Random per
asset, no wall clock, no filesystem ordering, so a second run is byte-identical.

    python3 tools/art/painter_1.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

SEED = 19310909
ROOT = Path(__file__).resolve().parents[2]
ARRIVAL = ROOT / "assets/backgrounds/office_arrival.png"
OUT = ROOT / "assets/stages"
W, H = 1448, 1086
SS = 4                                  # supersampling for anti-aliased ink and shapes

# Palette, sampled from the approved plates.
INK = (23, 43, 54)                      # fine navy contour
WALL = (163, 181, 161)                  # sea-glass green wall
TEAL = (44, 83, 99)                     # wainscot and door teal
NAVY = (22, 32, 48)                     # storm navy

# Window geometry (measured on the arrival plate).
PANES = [(483, 144, 100, 108), (593, 144, 100, 108), (702, 144, 98, 108),
         (483, 262, 100, 93), (593, 262, 100, 93), (702, 262, 98, 93),
         (483, 368, 317, 177)]
HORIZON = 474.5                         # painted horizon in the lower pane
PIVOT = (641, 472)                      # the game's tilt pivot
LOWER = PANES[6]


def rng_for(name: str) -> random.Random:
    return random.Random(f"{SEED}:{name}")


# ---------------------------------------------------------------------------
# shared helpers
# ---------------------------------------------------------------------------
def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(int(round(lerp(a, b, t))) for a, b in zip(c1, c2))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


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
    """img + (tex - 128) * k on every channel, clipped."""
    pos = tex.point(lambda v: int(max(0, v - 128) * k))
    neg = tex.point(lambda v: int(max(0, 128 - v) * k))
    bands = img.split()
    out = []
    for b in bands[:3]:
        out.append(ImageChops.subtract(ImageChops.add(b, pos), neg))
    if len(bands) == 4:
        out.append(bands[3])
    return Image.merge(img.mode, out)


def paper(img: Image.Image, rng: random.Random, mask: Image.Image | None = None,
          strength: float = 0.10) -> Image.Image:
    """Matte paper: soft fibre mottling plus sparse speckle at a few percent."""
    w, h = img.size
    fibre = noise(rng, w, h, 1, 0.7)
    mottle = noise(rng, w, h, 28, 0.0)
    tex = Image.blend(fibre, mottle, 0.45)
    grained = apply_signed(img, tex, strength)
    speck = noise(rng, w, h, 1, 0.0)
    light = speck.point(lambda v: 255 if v > 251 else 0)
    dark = speck.point(lambda v: 255 if v < 4 else 0)
    base = grained.convert("RGB")
    base = Image.composite(Image.new("RGB", (w, h), (236, 236, 226)), base, light.point(lambda v: v * 3 // 100))
    base = Image.composite(Image.new("RGB", (w, h), INK), base, dark.point(lambda v: v * 4 // 100))
    if img.mode == "RGBA":
        base.putalpha(img.getchannel("A"))
    if mask is None:
        return base
    return Image.composite(base, img, mask)


def wobble(pts, rng: random.Random, amp: float = 0.6, step: float = 5.0):
    """Subdivide a polyline and nudge it sideways with a slow, smooth hand tremor."""
    out = []
    ph1, ph2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    dist = 0.0
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        seg = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(seg / step))
        nx, ny = (-(y1 - y0) / seg, (x1 - x0) / seg) if seg else (0, 0)
        for i in range(n):
            t = i / n
            d = dist + seg * t
            o = amp * (0.65 * math.sin(d * 0.09 + ph1) + 0.35 * math.sin(d * 0.23 + ph2))
            out.append((lerp(x0, x1, t) + nx * o, lerp(y0, y1, t) + ny * o))
        dist += seg
    out.append(pts[-1])
    return out


def aa_mask(size, draw_fn) -> Image.Image:
    """Draw at SS x on an L canvas and box-reduce: clean anti-aliased coverage."""
    big = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    draw_fn(ImageDraw.Draw(big), SS)
    return big.reduce(SS)


def fill(img: Image.Image, color, mask: Image.Image, alpha: float = 1.0) -> Image.Image:
    if alpha < 1.0:
        mask = mask.point(lambda v: int(v * alpha))
    layer = Image.new(img.mode, img.size, color if img.mode == "RGB" else tuple(color)[:3] + (255,))
    return Image.composite(layer, img, mask)


def multiply(img: Image.Image, color, mask: Image.Image) -> Image.Image:
    shaded = ImageChops.multiply(img.convert("RGB"), Image.new("RGB", img.size, color))
    return Image.composite(shaded, img.convert("RGB"), mask)


def mask_mul(a: Image.Image, b: Image.Image) -> Image.Image:
    return ImageChops.multiply(a, b)


def rect_mask(rects, grow: int = 0) -> Image.Image:
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    for x, y, w, h in rects:
        d.rectangle((x - grow, y - grow, x + w - 1 + grow, y + h - 1 + grow), fill=255)
    return m


def pane_mask() -> Image.Image:
    """The glass, exactly: pane rects plus any 1 px rim pixel that is still glass, not frame."""
    m = rect_mask(PANES)
    plate = Image.open(ARRIVAL).convert("RGB")
    px, mp = plate.load(), m.load()
    for x, y, w, h in PANES:
        rim = [(x - 1, j) for j in range(y, y + h)] + [(x + w, j) for j in range(y, y + h)]
        rim += [(i, y - 1) for i in range(x, x + w)] + [(i, y + h) for i in range(x, x + w)]
        for i, j in rim:
            r, g, b = px[i, j]
            if lum((r, g, b)) > 60 and b - r < 35 and g - r < 22:
                mp[i, j] = 255
    # The sash catch sits on the meeting rail and overlaps the glass: keep it.
    catch = Image.new("L", (W, H), 0)
    cpx = catch.load()
    for j in range(336, 360):
        for i in range(618, 666):
            if lum(px[i, j]) < 110:
                cpx[i, j] = 255
    catch = catch.filter(ImageFilter.MaxFilter(3))
    return ImageChops.subtract(m, catch)


# ---------------------------------------------------------------------------
# masks of the room's surfaces (from the arrival plate's own colours)
# ---------------------------------------------------------------------------
def surface_masks(plate: Image.Image):
    """wall: the green plaster. teal: wainscot, cap, door, casings, sills. coat: the oilskin."""
    px = plate.load()
    wall = Image.new("L", (W, H), 0)
    teal = Image.new("L", (W, H), 0)
    coat = Image.new("L", (W, H), 0)
    wp, tp, cp = wall.load(), teal.load(), coat.load()
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            if 20 <= y <= 581 and abs(r - WALL[0]) < 34 and abs(g - WALL[1]) < 30 and abs(b - WALL[2]) < 30 \
                    and g > r and g > b - 6:
                wp[x, y] = 255
            if y <= 900 and g - r >= 12 and b >= g - 2 and lum((r, g, b)) < 130 and b - r > 20:
                tp[x, y] = 255
            if 290 <= y <= 860 and 1018 <= x <= 1152 and g - r < 12 and lum((r, g, b)) < 90:
                cp[x, y] = 255
    # Close the teal mask over plank grooves and ink, then keep it off objects.
    teal = teal.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    # Closing may only claim cool pixels (grooves, ink), never brown wood or brass between them.
    cool = Image.new("L", (W, H), 0)
    clp = cool.load()
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            if r <= g + 3 and b >= r:
                clp[x, y] = 255
    teal = mask_mul(teal, cool)
    coat = coat.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(5))
    # Objects are excluded by colour already; only the iron stove and pipe sit close enough
    # in hue to the teal to need an explicit fence.
    objects = Image.new("L", (W, H), 0)
    sp = objects.load()
    for y in range(0, 930):
        for x in range(0, 175):
            r, g, b = px[x, y]
            if g - r < 14 and lum((r, g, b)) < 95:
                sp[x, y] = 255
    no = ImageChops.lighter(objects, coat)
    inv = ImageOps.invert(no)
    wall = mask_mul(wall.filter(ImageFilter.MinFilter(3)), inv)
    not_glass = ImageOps.invert(pane_mask().filter(ImageFilter.MaxFilter(3)))
    wall = mask_mul(wall, not_glass)            # the sky is not plaster
    teal = mask_mul(mask_mul(teal, inv), not_glass)   # nor is the sea paint
    return wall, teal, no, objects, coat


# ---------------------------------------------------------------------------
# the world outside the window, painted level, in plate coordinates
# ---------------------------------------------------------------------------
def landmarks(plate: Image.Image, box):
    """Headland, lighthouse, lamp post, pier and hut lifted off the arrival pane as an RGBA
    layer in world space `box` (x0, y0, x1, y1), edge-extended past the glass."""
    x0, y0, x1, y1 = box
    lx, ly, lw, lh = LOWER
    src = plate.crop((lx, ly, lx + lw, ly + lh)).convert("RGB")
    sp = src.load()
    lay = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    lp = lay.load()
    for j in range(lh):
        y = ly + j
        for i in range(lw):
            x = lx + i
            r, g, b = sp[i, j]
            L = lum((r, g, b))
            a = 0.0
            if y <= HORIZON:
                a = 1.0 - smooth((L - 128) / 30)
            elif y <= 520 and x >= 634:
                a = 1.0 - smooth((L - 74) / 22)
            if r > b + 20 and r > 90:              # the pier lamp's glow: out
                r, g, b, a = 24, 30, 36, 1.0
            if a > 0.02:
                lp[i, j] = (r, g, b, int(a * 255))
    a = lay.getchannel("A").filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    lay = Image.composite(lay, Image.new("RGBA", lay.size, (34, 42, 48, 0)), lay.getchannel("A").point(lambda v: 255 if v else 0))
    filled = Image.new("RGBA", lay.size, (34, 42, 48, 255))
    filled.paste(lay, (0, 0), lay)
    filled.putalpha(a)
    lay = filled
    # Edge-extend: the headland runs on to the left, the pier on to the right.
    full = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    full.paste(lay, (lx - x0, ly - y0))
    left = lay.crop((0, 0, 1, lh)).resize((lx - x0, lh))
    right = lay.crop((lw - 1, 0, lw, lh)).resize((x1 - (lx + lw), lh))
    full.paste(left, (0, ly - y0))
    full.paste(right, (lx + lw - x0, ly - y0))
    return full


def tint_layer(layer: Image.Image, color, keep: float) -> Image.Image:
    """Pull a landmark layer toward one flat night colour, keeping `keep` of its drawing."""
    rgb = layer.convert("RGB")
    flat = Image.new("RGB", layer.size, color)
    out = Image.blend(flat, ImageChops.multiply(rgb, Image.new("RGB", layer.size, (200, 205, 210))), keep)
    out.putalpha(layer.getchannel("A"))
    return out


def vgrad(size, stops):
    """Vertical gradient through [(t, colour), ...] by row."""
    w, h = size
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                d.line((0, y, w, y), fill=mix(c0, c1, smooth((t - t0) / max(1e-6, t1 - t0))))
                break
    return im


def world_s2(plate: Image.Image, rng: random.Random):
    box = (420, 100, 860, 600)
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    hz = HORIZON - y0
    # Sky: low, heavy, featureless green-grey. Greyer and heavier high, a pale band at the
    # horizon, and a slow uneven weight across it so the panes read as sky, not frosted glass.
    # Upper sash (t 0.12-0.68) carries the weight: dark at the top, so it reads as a lid of
    # cloud seen through glass, never as frosted glass.
    sky = vgrad((w, int(hz) + 1), [(0, (40, 49, 52)), (0.14, (46, 56, 58)), (0.42, (64, 76, 74)),
                                   (0.70, (94, 106, 98)), (0.86, (122, 134, 120)),
                                   (0.95, (142, 152, 135)), (1, (150, 159, 141))])
    sky = apply_signed(sky, noise(rng, sky.width, sky.height, 90, 30), 0.09)
    world = Image.new("RGB", (w, h), NAVY)
    world.paste(sky, (0, 0))
    # Sea: dead flat. A thin bright skin at the horizon (the sky, mirrored), then storm navy.
    sea = vgrad((w, h - int(hz) - 1), [(0, (70, 84, 92)), (0.05, (40, 54, 68)), (0.30, (28, 40, 56)),
                                         (1, (18, 27, 41))])
    world.paste(sea, (0, int(hz) + 1))
    lay = tint_layer(landmarks(plate, box), (36, 45, 52), 0.22)
    # Mirror image on the glassy water, darker, a hair softened, fading as it nears.
    above = lay.crop((0, 0, w, int(hz) + 1))
    refl = above.transpose(Image.FLIP_TOP_BOTTOM)
    refl = tint_layer(refl, (11, 17, 26), 0.0).filter(ImageFilter.GaussianBlur(0.8))
    fade = Image.new("L", refl.size, 0)
    fd = ImageDraw.Draw(fade)
    for j in range(refl.size[1]):
        fd.line((0, j, w, j), fill=int(235 * (1 - 0.6 * smooth(j / 70))))
    refl.putalpha(mask_mul(refl.getchannel("A"), fade))
    world = world.convert("RGBA")
    world.alpha_composite(refl, (0, int(hz) + 1))
    world.alpha_composite(lay)
    world = world.convert("RGB")
    # Two dead-straight sheen lines: no wave, no crest, only glass.
    d = ImageDraw.Draw(world, "RGBA")
    for yy, a in [(hz + 19, 22), (hz + 41, 14)]:
        d.line((0, yy, w, yy), fill=(120, 134, 140, a), width=1)
    return world, box


def field(size, fn) -> Image.Image:
    """An L image from fn(x, y) -> 0..1, evaluated per pixel (small regions only)."""
    w, h = size
    im = Image.new("L", (w, h), 0)
    px = im.load()
    for y in range(h):
        for x in range(w):
            v = fn(x, y)
            if v > 0.002:
                px[x, y] = min(255, int(v * 255 + 0.5))
    return im


def ring_points(cx, cy, rx, ry_dn, ry_up, t0, t1, n=720):
    """A ring lying on the water: its far half crushed toward the horizon, its near half open.
    Angles in radians, t in [t0, t1]; y grows toward the viewer."""
    pts = []
    for i in range(n + 1):
        t = lerp(t0, t1, i / n)
        s = math.sin(t)
        pts.append((cx + rx * math.cos(t), cy + (ry_dn if s > 0 else ry_up) * s))
    return pts


def world_s3(plate: Image.Image, rng: random.Random):
    """The outside world for stage 3, painted level; the caller tips it about the pivot."""
    box = (190, 30, 1100, 920)
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    hz = HORIZON - y0
    hzi = int(hz)
    # Sky: dead, pale, sick grey-green. Greyer high, lighter low, and unevenly so, like a lid.
    # Level in world space, so once the world is tipped the gradient and its few soft strata
    # slope across the upper sash too: the tilt reads above the meeting rail.
    sky = vgrad((w, hzi + 1), [(0, (84, 92, 84)), (0.24, (100, 108, 96)), (0.45, (126, 134, 119)),
                               (0.66, (152, 159, 140)), (0.9, (184, 189, 166)), (1, (196, 199, 176))])
    strata = Image.new("L", (w, hzi + 1), 128)
    sd = ImageDraw.Draw(strata)
    for wy, amp, sig in [(150, -16, 9), (178, 9, 6), (226, -13, 12), (262, 8, 5), (300, -10, 10),
                         (352, -8, 7), (396, 6, 5)]:
        for j in range(int(wy - 3 * sig), int(wy + 3 * sig) + 1):
            if 0 <= j <= hzi:
                v = amp * math.exp(-((j - wy) / sig) ** 2)
                sd.line((0, j, w, j), fill=int(128 + v * 4))
    sky = apply_signed(sky, strata, 0.25)
    sky = apply_signed(sky, noise(rng, w, hzi + 1, 64, 22), 0.05)
    world = Image.new("RGB", (w, h), (8, 16, 20))
    world.paste(sky, (0, 0))

    # Water, lit from BELOW: a sea-glass luminance under the surface, brightest round the
    # centre, falling away to the sides and dying out toward the near shore (the viewer).
    cx, cy = 597 - x0, 486 - y0
    deep, mid, bright = (9, 18, 22), (34, 66, 60), (84, 128, 112)

    def glow(x, y):
        dy = y - cy
        dx = x - cx
        sy = 9.0 if dy < 0 else 58.0 + 0.10 * abs(dx)
        core = math.exp(-(dx / 250.0) ** 2 - (dy / sy) ** 2)
        broad = math.exp(-(dx / 520.0) ** 2 - (max(0.0, dy) / 150.0) ** 2) * 0.42
        return min(1.0, core * 0.92 + broad)

    gsize = (w, h - hzi - 1)
    g = field(gsize, lambda x, y: glow(x, y + hzi + 1)).filter(ImageFilter.GaussianBlur(1.5))
    water = Image.new("RGB", gsize, deep)
    water = Image.composite(Image.new("RGB", gsize, mid), water, g.point(lambda v: min(255, v * 2)))
    water = Image.composite(Image.new("RGB", gsize, bright), water, g.point(lambda v: max(0, v * 2 - 255)))
    water = apply_signed(water, noise(rng, gsize[0], gsize[1], 9, 2.0), 0.035)
    world.paste(water, (0, hzi + 1))
    glow_full = Image.new("L", (w, h), 0)
    glow_full.paste(g, (0, hzi + 1))

    # Seven rings lying flat on the water, spacing opening as they come nearer; the outer
    # three run off the glass on the left, right and bottom.
    radii = [22, 40, 66, 104, 160, 232, 322]
    ring_col = (150, 200, 178)

    def rings_draw(near: bool):
        def fn(d, s):
            for k, rx in enumerate(radii):
                ry_dn = rx * 0.23 + 2.0
                ry_up = min(ry_dn * 0.38, cy - hz - 1.5)
                t0, t1 = (0.0, math.pi) if near else (math.pi, 2 * math.pi)
                pts = ring_points(cx, cy, rx, ry_dn, ry_up, t0, t1)
                wd = (1.5 + 0.18 * k) if near else (1.1 + 0.05 * k)
                d.line([(px * s, py * s) for px, py in pts], fill=255, width=max(1, int(wd * s)), joint="curve")
        return fn

    near = aa_mask((w, h), rings_draw(True))
    far = aa_mask((w, h), rings_draw(False)).point(lambda v: v * 78 // 100)
    rings = ImageChops.lighter(near, far)
    # Between the rings the water sinks darker and glassier.
    zone = field((w, h), lambda x, y: 0.0 if y < hz else math.exp(-((x - cx) / 330.0) ** 2 - ((y - cy) / 90.0) ** 2))
    calm = ImageOps.invert(rings.filter(ImageFilter.GaussianBlur(5)).point(lambda v: min(255, v * 4)))
    world = multiply(world, (146, 160, 162), mask_mul(calm, zone))
    halo = rings.filter(ImageFilter.GaussianBlur(3.0))
    world = fill(world, (100, 154, 132), halo, 0.55)
    world = fill(world, ring_col, rings, 1.0)
    # The centre: a slightly darker calm disc, still water, not a hole.
    disc = aa_mask((w, h), lambda d, s: d.polygon([(px * s, py * s) for px, py in
                                                   ring_points(cx, cy, 13, 4.6, 2.6, 0, 2 * math.pi, 180)],
                                                  fill=255)).filter(ImageFilter.GaussianBlur(1.6))
    world = multiply(world, (150, 160, 162), disc)
    # Nothing on the water may sit above the horizon.
    world.paste(sky, (0, 0))
    # Landmarks: dark grey-green against the pale sky, softened by distance; the lighthouse dark.
    lay = tint_layer(landmarks(plate, box), (46, 56, 54), 0.30)
    wa = world.convert("RGBA")
    wa.alpha_composite(lay)
    # The near halves of the rings pass in front of the pier's drowned piles: the rings are
    # nearer than the pier, and two of them must read whole at a glance.
    water_only = Image.new("L", (w, h), 0)
    ImageDraw.Draw(water_only).rectangle((0, hzi + 3, w, h), fill=255)
    front = mask_mul(near, water_only)
    wa = Image.composite(Image.new("RGBA", (w, h), ring_col + (255,)), wa,
                         front.point(lambda v: v * 9 // 10))
    d = ImageDraw.Draw(wa, "RGBA")
    d.line((0, hz + 0.5, w, hz + 0.5), fill=(40, 58, 54, 110), width=1)
    return wa.convert("RGB"), box


def paste_world(base: Image.Image, world: Image.Image, box, angle: float, rng: random.Random,
                grain: float = 0.08) -> Image.Image:
    x0, y0, _, _ = box
    if angle:
        big = world.resize((world.width * 2, world.height * 2), Image.BICUBIC)
        big = big.rotate(angle, resample=Image.BICUBIC, center=((PIVOT[0] - x0) * 2, (PIVOT[1] - y0) * 2))
        world = big.reduce(2)
    canvas = base.copy()
    canvas.paste(world, (x0, y0))
    canvas = paper(canvas, rng, None, grain)
    m = pane_mask()
    return Image.composite(canvas, base, m)


# ---------------------------------------------------------------------------
# damp, puddle, tide
# ---------------------------------------------------------------------------
def bloom_spots(rng: random.Random):
    """Irregular rising-damp blooms along the cap: uneven gaps, mostly low, a few tall."""
    spots = []
    x = rng.uniform(-10, 30)
    while x < W + 20:
        hw = rng.uniform(16, 78)
        r = rng.random()
        if r < 0.45:
            h = rng.uniform(5, 16)             # barely there
        elif r < 0.85:
            h = rng.uniform(18, 46)
        else:
            h = rng.uniform(60, 118)           # a tall one, climbing a crack
        spots.append((x, hw, h, rng.uniform(0.5, 1.6), rng.uniform(0.45, 1.0)))
        x += hw * rng.uniform(0.5, 1.5) + rng.uniform(8, 110)
    return spots


def blooms(base: Image.Image, wall: Image.Image, rng: random.Random, spots, cap_y=580) -> Image.Image:
    """Rising damp from the wainscot cap: soft bodies, wettest at the bottom, each with a
    darker, broken tide edge on its top rim only."""
    body = Image.new("L", (W, H), 0)
    rim = Image.new("L", (W * 2, H * 2), 0)
    bp = body.load()
    rd = ImageDraw.Draw(rim)
    for cx, hw, height, sharp, wet in spots:
        fr = [rng.uniform(0.02, 0.06), rng.uniform(0.07, 0.15), rng.uniform(0.16, 0.32)]
        ph = [rng.uniform(0, 6.28) for _ in range(3)]
        lean = rng.uniform(-0.35, 0.35)
        prev = None
        for x in range(int(cx - hw), int(cx + hw) + 1):
            t = (x - cx) / hw
            env = max(0.0, 1 - abs(t) ** (1.4 + sharp)) ** (0.6 + 0.5 * sharp)
            env *= 1 + lean * t
            f = 0.62 * math.sin(x * fr[0] + ph[0]) + 0.30 * math.sin(x * fr[1] + ph[1]) + 0.07 * math.sin(x * fr[2] + ph[2])
            h = max(0.0, height * env * (0.78 + 0.30 * f))
            top = cap_y - h
            if 0 <= x < W and h > 0.5:
                for y in range(int(top), cap_y + 1):
                    u = min(1.0, (cap_y - y) / max(1.0, h))
                    v = int(255 * (0.35 + 0.65 * wet) * (0.30 + 0.70 * (1 - u) ** 1.3))
                    if v > bp[x, y]:
                        bp[x, y] = v
                if prev is not None and h > 3:
                    rd.line((prev[0] * 2, prev[1] * 2, x * 2, top * 2), fill=int(255 * min(1.0, 0.35 + wet * 0.7)), width=5)
            prev = (x, top) if h > 3 else None
    body = body.filter(ImageFilter.GaussianBlur(3.2))
    rim = rim.reduce(2).filter(ImageFilter.GaussianBlur(1.5))
    broken = noise(rng, W, H, 9, 1.5).point(lambda v: 0 if v < 70 else min(255, (v - 70) * 2))
    rim = mask_mul(rim, broken)
    streak = noise(rng, W // 3, H // 40, 1, 0).resize((W, H), Image.BICUBIC)   # vertical striation
    mott = noise(rng, W, H, 7, 1.0)
    tex = ImageChops.multiply(streak.point(lambda v: 175 + v * 80 // 255), mott.point(lambda v: 185 + v * 70 // 255))
    body = mask_mul(mask_mul(body, wall), tex)
    rim = mask_mul(rim, wall)
    out = multiply(base, (148, 161, 143), body)
    out = multiply(out, (158, 150, 126), rim)
    return out


def bigger_puddle(base: Image.Image, plate: Image.Image, rng: random.Random) -> Image.Image:
    bx0, by0, bx1, by1 = 1040, 893, 1200, 950
    crop = plate.crop((bx0, by0, bx1, by1))
    cp = crop.load()
    pm = Image.new("L", crop.size, 0)
    pp = pm.load()
    for j in range(crop.size[1]):
        for i in range(crop.size[0]):
            r, g, b = cp[i, j]
            if b > r + 6 and j > 3:
                pp[i, j] = 255
    pm = pm.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    bbox = pm.getbbox()
    cx = (bbox[0] + bbox[2]) / 2 + bx0
    cy = (bbox[1] + bbox[3]) / 2 + by0
    k = 1.25
    sw, sh = int(crop.size[0] * k), int(crop.size[1] * k)
    big = crop.resize((sw, sh), Image.LANCZOS)
    bigm = pm.resize((sw, sh), Image.BICUBIC).filter(ImageFilter.GaussianBlur(1.0))
    ox = int(round(cx - (cx - bx0) * k))
    oy = int(round(cy - (cy - by0) * k))
    floor_only = Image.new("L", (W, H), 0)
    ImageDraw.Draw(floor_only).rectangle((0, 896, W, H), fill=255)
    layer = base.copy()
    layer.paste(big, (ox, oy))
    full = Image.new("L", (W, H), 0)
    full.paste(bigm, (ox, oy))
    full = mask_mul(full, floor_only)
    out = Image.composite(layer, base, full)
    # A thin second ring a little way out, where the water has been and dried back: a faint,
    # soft, broken damp mark on the boards, not a drawn line.
    hard = full.point(lambda v: 255 if v > 110 else 0)
    spread = hard.filter(ImageFilter.GaussianBlur(7))
    ring = ImageChops.subtract(spread.point(lambda v: 255 if v > 24 else 0),
                               spread.point(lambda v: 255 if v > 40 else 0)).filter(ImageFilter.GaussianBlur(1.3))
    gaps = noise(rng, W, H, 6, 1.2).point(lambda v: 0 if v < 85 else min(255, (v - 85) * 3))
    ring = mask_mul(mask_mul(ring, gaps), floor_only)
    out = multiply(out, (176, 184, 188), ring)
    # The wet ground between: barely darker.
    halo = mask_mul(ImageChops.subtract(spread.point(lambda v: 255 if v > 30 else 0), hard).filter(ImageFilter.GaussianBlur(3)),
                    floor_only).point(lambda v: v * 45 // 100)
    out = multiply(out, (200, 206, 210), halo)
    return out


TIDE_Y = 512


def darken_wall(base: Image.Image, wall: Image.Image, objects: Image.Image) -> Image.Image:
    """Pull the plaster down toward the ominous plate's cold grey-green: the room is unlit."""
    soft = mask_mul(wall.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.7)),
                    ImageOps.invert(objects))
    return multiply(base, (212, 205, 210), soft)


def line_wander(rng: random.Random, amp: float = 1.6):
    """y offset per x: a slow, irregular wander of about +-amp px, never a regular wave."""
    terms = [(rng.uniform(0.003, 0.008), rng.uniform(0, 6.28), 0.45),
             (rng.uniform(0.011, 0.02), rng.uniform(0, 6.28), 0.30),
             (rng.uniform(0.03, 0.05), rng.uniform(0, 6.28), 0.17),
             (rng.uniform(0.07, 0.11), rng.uniform(0, 6.28), 0.08)]
    return lambda x: amp * sum(k * math.sin(x * f + p) for f, p, k in terms)


def salt_band(rng: random.Random, x0: float, x1: float, line_y: float, strength: float,
              wander=None) -> Image.Image:
    """A matte, broken, soft-edged crust 2-5 px thick along a wandering line, with drips of
    very different length and weight, clustered as water finds the low places."""
    wander = wander or line_wander(rng)
    band = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(band)
    ph = [rng.uniform(0, 6.28) for _ in range(4)]
    for xi in range(int(x0 * SS), int(x1 * SS)):
        x = xi / SS
        thick = 3.2 + 1.1 * math.sin(x * 0.021 + ph[0]) + 0.7 * math.sin(x * 0.067 + ph[1])
        cover = 0.5 + 0.5 * math.sin(x * 0.013 + ph[2]) * math.cos(x * 0.037 + ph[3])
        y = line_y - 2.0 + wander(x)
        d.line((xi, y * SS, xi, (y + thick) * SS), fill=int(255 * (0.5 + 0.5 * cover)))
    band = band.reduce(SS)
    soft = band.filter(ImageFilter.GaussianBlur(1.4))
    band = ImageChops.lighter(soft, band.filter(ImageFilter.GaussianBlur(0.6)).point(lambda v: v * 80 // 100))
    # Breaks of every length: long missing runs (slow noise) and small pits (fast noise).
    slow = noise(rng, W, H, 46, 8.0).point(lambda v: 0 if v < 70 else min(255, (v - 70) * 3))
    fast = noise(rng, W, H, 5, 1.0).point(lambda v: 0 if v < 40 else min(255, 120 + v))
    band = mask_mul(mask_mul(band, slow), fast)
    # Drips: clustered, lengths spread over 3-4x and more, widths and beads all different.
    drips = Image.new("L", (W * SS, H * SS), 0)
    dd = ImageDraw.Draw(drips)
    x = x0 + rng.uniform(5, 40)
    while x < x1:
        n = 1 if rng.random() < 0.6 else rng.randint(2, 4)
        for _ in range(n):
            xx = x + rng.uniform(-9, 9)
            ln = math.exp(rng.uniform(math.log(3.5), math.log(58)))
            wd = rng.uniform(0.8, 2.6) * (0.7 + 0.3 * min(1.0, ln / 20))
            top = line_y + 1 + wander(xx)
            pts = wobble([(xx, top), (xx + rng.uniform(-1.2, 1.2), top + ln)], rng, 0.35, 3)
            for i, (p0, p1) in enumerate(zip(pts, pts[1:])):
                t = i / max(1, len(pts) - 2)
                wv = wd * (1 - 0.55 * t)
                dd.line((p0[0] * SS, p0[1] * SS, p1[0] * SS, p1[1] * SS),
                        fill=int(190 * (1 - 0.45 * t)), width=max(1, int(wv * SS)))
            if rng.random() < 0.35:
                ex, ey = pts[-1]
                r = wd * rng.uniform(0.55, 0.9)
                dd.ellipse(((ex - r) * SS, (ey - r * 0.6) * SS, (ex + r) * SS, (ey + r * 1.3) * SS), fill=130)
        x += math.exp(rng.uniform(math.log(14), math.log(140)))
    drips = drips.reduce(SS).filter(ImageFilter.GaussianBlur(0.5))
    band = ImageChops.lighter(band, drips)
    return band.point(lambda v: int(v * strength))


def wet_gradient(line_y: float, rng: random.Random, ghosts) -> Image.Image:
    """Strength of the soak by height: wettest just under the line, drying toward the middle
    of the wall, wet again toward the floor; plus faint older tide lines, wandering and
    broken; plus a slow mottle so no band is ever a flat rectangle."""
    g = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(g)
    for y in range(int(line_y), 906):
        dy = y - line_y
        v = 0.36 + 0.52 * math.exp(-dy / 15.0) + 0.14 * math.exp(-dy / 60.0) + 0.30 * smooth((y - 700) / 200)
        gd.line((0, y, W, y), fill=int(255 * min(1.0, v)))
    for gy, k in ghosts:
        wv = line_wander(rng, 1.8)
        gh = Image.new("L", (W * 2, H * 2), 0)
        hd = ImageDraw.Draw(gh)
        pts = [(x * 2, (gy + wv(x)) * 2) for x in range(0, W + 1, 3)]
        hd.line(pts, fill=255, width=6)
        gh = gh.reduce(2).filter(ImageFilter.GaussianBlur(1.1))
        brk = noise(rng, W, H, 38, 6.0).point(lambda v: 0 if v < 90 else min(255, (v - 90) * 3))
        g = ImageChops.add(g, mask_mul(gh, brk).point(lambda v: min(255, int(v * k * 1.6))))
    mott = noise(rng, W, H, 34, 10.0).point(lambda v: 196 + v * 59 // 255)
    return mask_mul(g, mott)


def tide(base: Image.Image, plate: Image.Image, masks5, rng: random.Random, line_y=TIDE_Y) -> Image.Image:
    """The room has stood under water to this height. The line is dead level and crosses
    everything it should not: the plaster, the window casing and the GLASS, the coat, the
    door and its panels, the stove pipe."""
    wall, teal, no, stove, coat = masks5
    below = Image.new("L", (W, H), 0)
    ImageDraw.Draw(below).rectangle((0, line_y, W, 905), fill=255)
    glass = mask_mul(pane_mask(), below)
    # Surfaces the water soaked: plaster, panelling, door, casings; the coat and stove too.
    # Plaster, grown over the pale highlight and anti-aliased rim pixels at its edges so no
    # dry halo is left round the casings; only cool pixels, never wood or brass.
    px = plate.load()
    light = Image.new("L", (W, H), 0)
    lp = light.load()
    for y in range(line_y, 600):
        for x in range(W):
            r, g, b = px[x, y]
            if lum((r, g, b)) >= 72 and r <= b + 12:      # never the brass of the door knob
                lp[x, y] = 255
    rows = rect_mask([(0, line_y, W, 590 - line_y)])
    plaster = mask_mul(mask_mul(rows, light), ImageOps.invert(ImageChops.lighter(teal, no)))
    plaster = mask_mul(plaster, ImageOps.invert(pane_mask().filter(ImageFilter.MaxFilter(3))))
    plaster = ImageChops.lighter(plaster, mask_mul(wall, below))
    teal_only = ImageChops.subtract(teal, plaster)
    structure = ImageChops.lighter(plaster, teal)
    wet = mask_mul(structure, below)
    ghosts = [(line_y + 23, 0.55), (line_y + 47, 0.38)]
    soak = wet_gradient(line_y, rng, ghosts)
    wet_plaster = mask_mul(mask_mul(plaster, below), soak)
    out = multiply(base, (120, 130, 136), wet_plaster)               # soaked plaster: darker
    out = fill(out, (12, 32, 40), wet_plaster, 0.22)                 # and colder
    out = multiply(out, (140, 152, 160), mask_mul(mask_mul(teal_only, below), soak))  # wet paint
    out = multiply(out, (196, 200, 204), mask_mul(coat, below))      # the oilskin, wetter
    out = multiply(out, (200, 204, 208), mask_mul(stove, below))     # iron
    # The glass below the line: a dirty skin left on the inside of the pane, a shade darker.
    out = multiply(out, (196, 208, 206), glass)
    # Wet sheen: soft vertical gleams down the planks.
    sheen = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(sheen)
    x = 0
    while x < W:
        x += rng.randint(18, 46)
        a = rng.randint(30, 80)
        y0 = line_y + rng.randint(30, 90)
        sd.line((x, y0, x + rng.uniform(-1, 1), 890), fill=a, width=rng.randint(2, 4))
    sheen = sheen.filter(ImageFilter.GaussianBlur(3))
    gleam = mask_mul(sheen, ImageChops.lighter(wet, mask_mul(coat, below)))
    out = fill(out, (150, 182, 186), gleam, 0.45)
    # Fine runs from the line, as it drained.
    runs = Image.new("L", (W * SS, H * SS), 0)
    rd = ImageDraw.Draw(runs)
    for _ in range(56):
        x = rng.uniform(0, W)
        ln = rng.uniform(20, 140)
        pts = wobble([(x, line_y + 3), (x + rng.uniform(-1.5, 1.5), line_y + 3 + ln)], rng, 0.5, 6)
        rd.line([(p[0] * SS, p[1] * SS) for p in pts], fill=255, width=int(1.3 * SS))
    runs = mask_mul(runs.reduce(SS), ImageChops.lighter(wet, mask_mul(coat, below)))
    out = multiply(out, (120, 128, 132), runs.point(lambda v: v * 6 // 10))
    # The line itself: a soft dark stain just under the crust, across every surface.
    every = ImageChops.lighter(ImageChops.lighter(structure, pane_mask()), ImageChops.lighter(coat, stove))
    every = ImageChops.lighter(every, rect_mask([(0, line_y - 8, W, 18)]))
    hooks_free = ImageOps.invert(rect_mask([(1030, 270, 8, 8)]))
    wander = line_wander(rng, 1.6)
    band = Image.new("L", (W * 2, H * 2), 0)
    bd = ImageDraw.Draw(band)
    for x in range(0, W * 2):
        y = line_y + wander(x / 2)
        bd.line((x, (y + 1) * 2, x, (y + 5) * 2), fill=255)
    band = band.reduce(2)
    stain = mask_mul(band.filter(ImageFilter.GaussianBlur(1.6)), mask_mul(every, hooks_free))
    out = multiply(out, (150, 150, 140), stain)
    salt = salt_band(rng, 0, W, line_y, 1.0, wander)
    salt_wall = mask_mul(salt, ImageOps.invert(pane_mask()))
    salt_glass = mask_mul(salt, pane_mask()).point(lambda v: v * 62 // 100)
    out = fill(out, (196, 196, 182), salt_wall, 0.80)
    out = fill(out, (188, 194, 180), salt_glass, 0.85)
    # Older, lower tide lines: the same crust, thinner and mostly gone.
    for gy, k in ghosts:
        ghost = mask_mul(salt_band(rng, 0, W, gy, k), mask_mul(wet, ImageOps.invert(pane_mask())))
        out = fill(out, (176, 180, 166), ghost, 0.7)
    return out


def ceiling_runs(base: Image.Image, wall: Image.Image, rng: random.Random) -> Image.Image:
    """Long water runs down from the cornice, as in the approved ominous plate: a soft
    seep under the cornice, then narrow streaks that thin and fade as they fall."""
    m = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(m)
    seep = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(seep)
    groups = [(14, 2), (128, 3), (214, 1), (404, 2), (880, 3), (1000, 2), (1176, 1)]
    for gx, n in groups:
        sd.rectangle((gx - 22, 22, gx + 22 + 14 * n, 30 + rng.randint(4, 14)), fill=rng.randint(70, 120))
        for k in range(n):
            x = gx + k * rng.uniform(9, 18) + rng.uniform(-3, 3)
            length = rng.uniform(120, 480)
            width = rng.uniform(2.2, 5.0)
            pts = wobble([(x, 24), (x + rng.uniform(-2, 2), 24 + length)], rng, 0.8, 4)
            for i, (p0, p1) in enumerate(zip(pts, pts[1:])):
                t = i / max(1, len(pts) - 2)
                wv = width * (1 - 0.7 * t) * (0.85 + 0.15 * math.sin(i * 0.9))
                val = int(255 * (1 - t) ** 0.8)
                d.line((p0[0] * SS, p0[1] * SS, p1[0] * SS, p1[1] * SS), fill=val, width=max(1, int(wv * SS)))
    m = m.reduce(SS).filter(ImageFilter.GaussianBlur(0.9))
    seep = seep.filter(ImageFilter.GaussianBlur(7))
    m = mask_mul(ImageChops.lighter(m, seep), wall)
    tex = noise(rng, W // 2, H // 30, 1, 0).resize((W, H), Image.BICUBIC).point(lambda v: 150 + v * 105 // 255)
    m = mask_mul(m, tex)
    return multiply(base, (188, 196, 182), m)


# ---------------------------------------------------------------------------
# plates
# ---------------------------------------------------------------------------
_MASKS = {}


def masks(plate):
    if not _MASKS:
        _MASKS["m"] = surface_masks(plate)
    return _MASKS["m"]


def paint_office_s2() -> Image.Image:
    rng = rng_for("office_s2")
    plate = Image.open(ARRIVAL).convert("RGB")
    wall = masks(plate)[0]
    world, box = world_s2(plate, rng)
    img = paste_world(plate, world, box, 0.0, rng, grain=0.045)
    img = blooms(img, wall, rng, bloom_spots(rng))
    img = bigger_puddle(img, plate, rng)
    return img


def paint_office_s3(s2: Image.Image) -> Image.Image:
    rng = rng_for("office_s3")
    plate = Image.open(ARRIVAL).convert("RGB")
    m5 = masks(plate)
    wall, teal, no = m5[:3]
    world, box = world_s3(plate, rng)
    img = paste_world(s2, world, box, 7.0, rng)
    img = darken_wall(img, wall, no)
    img = ceiling_runs(img, wall, rng)
    img = tide(img, plate, m5, rng)
    return img


# ---------------------------------------------------------------------------
# the threshold corridor (unlit layer, RGBA, door slab only)
# ---------------------------------------------------------------------------
SLAB = (1228, 168, 206, 736)
VP = (1300.0, 440.0)        # painted vanishing point: up and left of the door's centre, wrongly
CLIMB = 1.06                # per-step overheight: each casing too tall, the lintels climb


def casing_rects(n=9):
    sx, sy, sw, sh = SLAB
    r0 = (sx + 4.0, sy + 6.0, sx + sw - 4.0, sy + sh)       # first casing hugs the door slab
    out = []
    for i in range(n):
        s = 0.86 ** i
        tall = CLIMB ** i
        x0 = VP[0] + (r0[0] - VP[0]) * s
        x1 = VP[0] + (r0[2] - VP[0]) * s
        y1 = VP[1] + (r0[3] - VP[1]) * s                      # floor line converges honestly
        y0 = max(sy + 2.0, y1 - (r0[3] - r0[1]) * s * tall)   # the lintel does not
        out.append((x0, y0, x1, y1, s))
    return out


def poly_mask(pts) -> Image.Image:
    return aa_mask((W, H), lambda d, s: d.polygon([(x * s, y * s) for x, y in pts], fill=255))


def box_mask(x0, y0, x1, y1) -> Image.Image:
    return aa_mask((W, H), lambda d, s: d.rectangle((x0 * s, y0 * s, x1 * s - 1, y1 * s - 1), fill=255))


def reflect(img: Image.Image, i: int, casing, tw: float, tealv, floor: Image.Image,
            rng: random.Random, squash: float = 0.42) -> Image.Image:
    """Casing i, upside down in the standing water at its own foot: a squashed mirror image
    in pale teal, a value or two above the black water, broken into ripple bands and
    swaying sideways a pixel or two, fading toward the viewer."""
    x0, y0, x1, y1, sc = casing
    trim = ImageChops.subtract(box_mask(x0, y0, x1, y1), box_mask(x0 + tw, y0 + tw, x1 - tw, y1 + 1))
    edge = aa_mask((W, H), lambda d, s: d.line([((x0 + tw) * s, y1 * s), ((x0 + tw) * s, (y0 + tw) * s),
                                               ((x1 - tw) * s, (y0 + tw) * s), ((x1 - tw) * s, y1 * s)],
                                              fill=255, width=max(1, int(1.6 * s))))
    lintel = box_mask(x0, y0, x1, y0 + tw + 1.5)
    src = ImageChops.lighter(ImageChops.lighter(trim.point(lambda v: v * 62 // 100), edge), lintel)
    bx0, bx1 = int(x0) - 4, int(math.ceil(x1)) + 4
    top = int(y0) - 6
    strip = src.crop((bx0, top, bx1, int(math.ceil(y1)))).transpose(Image.FLIP_TOP_BOTTOM)
    rh = max(2, int(strip.height * squash))
    strip = strip.resize((strip.width * 4, rh), Image.BICUBIC)
    # Ripple: each row slides sideways by a slow, uneven sway that grows toward the viewer.
    ph1, ph2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    rip = Image.new("L", strip.size, 0)
    for j in range(rh):
        t = j / max(1, rh - 1)
        off = (0.7 + 1.6 * t) * (0.65 * math.sin(j * 0.55 + ph1) + 0.35 * math.sin(j * 1.37 + ph2))
        row = strip.crop((0, j, strip.width, j + 1))
        rip.paste(row, (int(round(off * 4)), j))
    strip = rip.resize((bx1 - bx0, rh * 4), Image.BICUBIC)
    # And each column rides the swell up and down a little, so the reflected lintels are
    # wavering, broken lines, never a ruled dash.
    ph3, ph4 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    wav = Image.new("L", strip.size, 0)
    for i2 in range(strip.width):
        off = 1.1 * math.sin(i2 * 0.21 + ph3) + 0.6 * math.sin(i2 * 0.53 + ph4)
        wav.paste(strip.crop((i2, 0, i2 + 1, strip.height)), (i2, int(round(off * 4))))
    strip = wav.resize((bx1 - bx0, rh), Image.BOX)
    # Break it into bands: long thin horizontal gaps, as wind-skin on standing water.
    bw = bx1 - bx0
    blot = noise(rng, bw, rh, 1, 0).resize((bw * 3, rh), Image.BICUBIC)
    blot = blot.filter(ImageFilter.GaussianBlur((9, 1.2))).resize((bw, rh), Image.BOX)
    blot = ImageOps.autocontrast(blot, cutoff=2)
    swell = Image.new("L", (bw, rh), 0)
    swd = ImageDraw.Draw(swell)
    p3 = rng.uniform(0, 6.28)
    for j in range(rh):
        swd.line((0, j, bw, j), fill=int(255 * (0.5 + 0.5 * math.sin(j * (0.9 + 0.012 * j) + p3))))
    bands = Image.blend(blot, swell, 0.35).point(lambda v: int(255 * smooth((v - 70) / 110)))
    fade = Image.new("L", (bx1 - bx0, rh), 0)
    fdw = ImageDraw.Draw(fade)
    for j in range(rh):
        fdw.line((0, j, bx1 - bx0, j), fill=int(255 * (1 - 0.4 * (j / max(1, rh - 1)) ** 0.8)))
    strip = mask_mul(mask_mul(strip, bands), fade)
    m = Image.new("L", (W, H), 0)
    m.paste(strip, (bx0, int(round(y1)) + 1))
    m = mask_mul(m.filter(ImageFilter.GaussianBlur(0.45)), floor)
    col = tuple(int(c * 0.88 ** i) for c in (86, 138, 146))
    return fill(img, col, m, 0.85)


def paint_threshold_corridor() -> Image.Image:
    rng = rng_for("threshold_corridor")
    cas = casing_rects()
    TW = 10.0                                                  # casing trim width at the door

    def tealv(i, k=1.0):
        f = 0.78 ** i * k
        return tuple(min(255, int(c * f)) for c in (38, 72, 86))

    img = Image.new("RGB", (W, H), (0, 0, 0))
    a0, a1 = cas[0], cas[-1]
    near = (a0[0] + TW, a0[1] + TW, a0[2] - TW, a0[3])
    far = (a1[0], a1[1], a1[2], a1[3])
    planes = [
        ([(near[0], near[1]), (near[2], near[1]), (far[2], far[1]), (far[0], far[1])], (16, 22, 24)),   # ceiling
        ([(near[0], near[1]), (far[0], far[1]), (far[0], far[3]), (near[0], near[3])], (34, 54, 50)),   # left wall
        ([(near[2], near[1]), (far[2], far[1]), (far[2], far[3]), (near[2], near[3])], (27, 44, 42)),   # right wall
    ]
    for pts, col in planes:
        img = fill(img, col, poly_mask(pts))
    for side in (0, 2):
        ya = near[3] - (near[3] - near[1]) * 0.30
        yb = far[3] - (far[3] - far[1]) * 0.30
        img = fill(img, (22, 44, 52), poly_mask([(near[side], ya), (far[side], yb), (far[side], far[3]),
                                                 (near[side], near[3])]))
        cap = aa_mask((W, H), lambda d, s, side=side, ya=ya, yb=yb: d.line(
            (near[side] * s, ya * s, far[side] * s, yb * s), fill=255, width=int(2.0 * s)))
        img = fill(img, (40, 70, 80), cap, 0.7)
    # Light dies with depth, smoothly (no stepped bands).
    vx, vy = VP

    def falloff(x, y):
        sx0, sy0, sw, sh = SLAB
        if not (sx0 <= x < sx0 + sw and sy0 <= y < sy0 + sh):
            return 0.0
        # depth from how far toward the VP this point sits, by the casing it falls inside
        t = max(abs(x - vx) / ((sw / 2) + 6), abs(y - vy) / (sh * 0.6))
        return max(0.0, min(1.0, t)) ** 0.85

    light = field((W, H), falloff).filter(ImageFilter.GaussianBlur(4))
    img = ImageChops.multiply(img, Image.merge("RGB", [light] * 3))

    # Standing water over the whole floor: one dark, level, glassy sheet, sills drowned.
    # The water runs wall to wall, under every jamb, so each casing stands IN it.
    floor = poly_mask([(a0[0], a0[3]), (a0[2], a0[3]), (far[2], far[3]), (far[0], far[3])])
    water = vgrad((W, H), [(0, (6, 10, 13)), (far[3] / H, (6, 10, 13)), (near[3] / H, (12, 20, 24)), (1, (12, 20, 24))])
    img = Image.composite(water, img, floor)

    # The casings, back to front. Their feet stand IN the water: the last few pixels of each
    # jamb are drowned darker, and the surface touches each leg with a short pale meniscus.
    sx0, sy0, sw, sh = SLAB
    ph = rng.uniform(0, 6.28)
    for i in range(len(cas) - 1, -1, -1):
        x0, y0, x1, y1, sc = cas[i]
        tw = TW * sc
        outer = box_mask(x0, y0, x1, y1)
        inner = box_mask(x0 + tw, y0 + tw, x1 - tw, y1 + 1)
        img = fill(img, tealv(i), ImageChops.subtract(outer, inner))
        if i == len(cas) - 1:
            img = fill(img, (0, 0, 0), inner)                  # the ninth: pure black inside
        # A cold inner edge that dies more slowly than the paint, so every casing still reads.
        hl = aa_mask((W, H), lambda d, s: d.line([((x0 + tw) * s, y1 * s), ((x0 + tw) * s, (y0 + tw) * s),
                                                  ((x1 - tw) * s, (y0 + tw) * s), ((x1 - tw) * s, y1 * s)],
                                                 fill=255, width=int(1.3 * s)))
        img = fill(img, tealv(i, 1.9 * 1.12 ** i), hl, 0.75)
        cap = box_mask(x0 - 2 * sc, y0 - 4 * sc, x1 + 2 * sc, y0 + 1)
        img = fill(img, tealv(i, 0.9), cap)
        # Fine navy ink: dark on the near casings, a faint navy line on the deep ones.
        lw = 1.4 + 0.5 * sc
        ink_col = (4, 9, 13) if i < 4 else (20, 37, 49)
        ink_a = 0.92 if i < 4 else 0.62 - 0.05 * (i - 4)
        for rect in [(x0, y0, x1, y1), (x0 + tw, y0 + tw, x1 - tw, y1)]:
            pts = wobble([(rect[0], rect[3]), (rect[0], rect[1]), (rect[2], rect[1]), (rect[2], rect[3])],
                         rng, 0.3 * sc + 0.1, 5)
            ink = aa_mask((W, H), lambda d, s: d.line([(px * s, py * s) for px, py in pts], fill=255,
                                                      width=max(1, int(lw * s)), joint="curve"))
            img = fill(img, ink_col, ink, ink_a)
        # Drowned feet: the jamb darkens smoothly into the water over its last few pixels.
        depth = max(4.0, 14 * sc)
        ramp = Image.new("L", (W, H), 0)
        rdw = ImageDraw.Draw(ramp)
        for yy in range(int(y1 - depth) - 1, int(y1) + 2):
            rdw.line((0, yy, W, yy), fill=int(255 * smooth((yy - (y1 - depth)) / depth)))
        jambs = ImageChops.subtract(outer, box_mask(x0 + tw, y0, x1 - tw, y1 + 1))
        img = multiply(img, (110, 128, 136), mask_mul(jambs, ramp.filter(ImageFilter.GaussianBlur(0.8))))
        if i > 0:
            img = reflect(img, i, cas[i], tw, tealv, floor, rng)
            # The surface touching each jamb: a short, soft pale meniscus, nothing across.
            ml = aa_mask((W, H), lambda d, s: [d.line(((xa - 1.5) * s, (y1 + 0.4) * s, (xb + 1.5) * s, (y1 + 0.4) * s),
                                                      fill=255, width=max(1, int(1.1 * s)))
                                               for xa, xb in ((x0, x0 + tw), (x1 - tw, x1))])
            img = fill(img, tealv(i, 2.4 * 1.08 ** i), ml.filter(ImageFilter.GaussianBlur(0.5)), 0.7)

    slab = rect_mask([SLAB])
    img = paper(img, rng, slab, 0.05)
    out = img.convert("RGBA")
    out.putalpha(slab)
    return out


# ---------------------------------------------------------------------------
def save(img: Image.Image, name: str) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    p = OUT / name
    img.save(p, format="PNG", optimize=False, compress_level=9)
    return p


def main() -> None:
    s2 = paint_office_s2()
    print(save(s2, "office_s2.png").relative_to(ROOT))
    s3 = paint_office_s3(s2)
    print(save(s3, "office_s3.png").relative_to(ROOT))
    print(save(paint_threshold_corridor(), "threshold_corridor.png").relative_to(ROOT))


if __name__ == "__main__":
    main()
