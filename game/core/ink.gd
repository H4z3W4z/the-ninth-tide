class_name Ink
extends RefCounted
## Shared palette, fonts and drawing helpers, lifted from the Intake Office slice so every
## room and the core HUD draw text, buttons and handwriting the same way.
## Read-only for room teams: call these, don't copy them.

const SIZE := Vector2(1448, 1086)
const PAPER := Color("ded4ba")
const INK := Color("172b36")
const GOLD := Color("d2aa66")
const AMBER := Color("c39959")
const BRUISE := Color("746577")
const BLUE_INK := Color("1f3f8a")
## Her ink as it reads on black: BLUE_INK fails contrast on the dark.
const NIGHT_INK := Color("8fa6e0")
const BRASS := Color("b08a4a")
const COPPER := Color("617d74")
const TIMBER := Color("675d51")
const SOOT := Color("292929")
const SEA_GLASS := Color("a9c8b8")
const STORM := Color("22303a")
const BLACK := Color("070b0f")

## Forward slant for her hand. A positive skew leans glyph tops to the right.
const HAND_SKEW := 0.18

## The bundled fonts (SIL OFL 1.1; licences beside them in assets/fonts/). A system font is
## only the fallback for a file that fails to load.
const SERIF_FILE := "res://assets/fonts/NotoSerif-Regular.ttf"
const SERIF_ITALIC_FILE := "res://assets/fonts/NotoSerif-Italic.ttf"
const LABEL_FILE := "res://assets/fonts/LiberationSansNarrow-Regular.ttf"
const LABEL_BOLD_FILE := "res://assets/fonts/LiberationSansNarrow-Bold.ttf"
const SERIF_NAMES := ["Noto Serif", "DejaVu Serif", "Liberation Serif", "serif"]
## DejaVu Sans: glyph fallback for the UI arrows and marks (▸ ◂ ▾ ▲ ▼ ▷ ◁ → ≡ −) that the
## other bundled fonts lack. On desktop the OS supplies them; a web build has no system fonts.
const SYMBOLS_FILE := "res://assets/fonts/DejaVuSans.ttf"

static var _serif: Font
static var _hand: Font
static var _label: Font

## A bundled font file, or null when it is missing or fails to load.
static func _font_file(path: String) -> FontFile:
	if not ResourceLoader.exists(path):
		return null
	var f := load(path) as FontFile
	if f != null and path != SYMBOLS_FILE and ResourceLoader.exists(SYMBOLS_FILE):
		var sym := load(SYMBOLS_FILE) as Font
		if sym != null and not f.fallbacks.has(sym):
			f.fallbacks = f.fallbacks + [sym]
	return f

## Web builds cannot see system fonts, so every SystemFont in the room views resolves to
## the engine fallback font. Point that at the bundled label face (with the symbol fallback)
## so web text matches the desktop look instead of the engine default.
static func install_web_fallback() -> void:
	if OS.has_feature("web"):
		ThemeDB.fallback_font = label_font()

static func _system(names: Array, italic := false) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_italic = italic
	return f

## Noto Serif Regular: titles, the notebook, subtitles, buttons.
static func serif() -> Font:
	if _serif == null:
		var f := _font_file(SERIF_FILE)
		_serif = f if f != null else _system(SERIF_NAMES)
	return _serif

## Her hand: Noto Serif Italic; without it, the regular cut slanted by HAND_SKEW.
static func hand() -> Font:
	if _hand == null:
		var f := _font_file(SERIF_ITALIC_FILE)
		if f != null:
			_hand = f
		else:
			var base := _font_file(SERIF_FILE)
			if base != null:
				var v := FontVariation.new()
				v.base_font = base
				v.variation_embolden = 0.0
				v.variation_transform = Transform2D(Vector2(1.0, HAND_SKEW), Vector2(0.0, 1.0), Vector2.ZERO)   # the docs' fake-italic slant
				_hand = v
			else:
				_hand = _system(SERIF_NAMES, true)
	return _hand

## Liberation Sans Narrow Regular: small printed labels (tags, plates, dials).
static func label_font() -> Font:
	if _label == null:
		var f := _font_file(LABEL_FILE)
		_label = f if f != null else _system(["Liberation Sans Narrow", "Liberation Sans", "DejaVu Sans", "sans-serif"])
	return _label

## A printed label's colour: navy ink at 0.85 on paper, brass on navy.
static func label_color(on_dark: bool) -> Color:
	return BRASS if on_dark else Color(INK, 0.85)

static func button(c: CanvasItem, rect: Rect2, label: String, active := false, size := 24, dim := false) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("786440") if active else Color(0.15, 0.25, 0.29, 0.92 if not dim else 0.6)
	style.border_color = GOLD if active else Color("8ba19a", 1.0 if not dim else 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	c.draw_style_box(style, rect)
	var f := serif()
	# Long labels (item names in a narrow inventory slot) shrink, then end in an ellipsis,
	# so they never spill into the next button.
	var room_x := rect.size.x - 12.0
	var ts := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	while ts.x > room_x and size > 16:
		size -= 1
		ts = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	if ts.x > room_x:
		while label.length() > 1 and f.get_string_size(label + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room_x:
			label = label.substr(0, label.length() - 1)
		label = label.strip_edges() + "…"
		ts = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	c.draw_string(f, rect.position + Vector2((rect.size.x - ts.x) / 2.0, rect.size.y / 2.0 + size * 0.36),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(PAPER, 1.0 if not dim else 0.6))

static func text(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, font: Font, width: float,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	c.draw_string(font, pos, s, align, width, size, col)

## Draws word-wrapped text; returns the y below the last line.
static func wrapped(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, width: float,
		draw := true, font: Font = null) -> float:
	if font == null:
		font = serif()
	var y := pos.y
	var line := ""
	for word in s.split(" "):
		var trial := word if line == "" else line + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			if draw:
				c.draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			y += size * 1.45
			line = word
		else:
			line = trial
	if line != "":
		if draw:
			c.draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		y += size * 1.45
	return y

## Her hand, glyph by glyph: seeded jitter, a forward slant, and wet ink at the nib.
static func handwriting(c: CanvasItem, s: String, count: int, pos: Vector2, size: int, row: int,
		wet: bool, ink := BLUE_INK, font: Font = null, skew := HAND_SKEW) -> void:
	if font == null:
		font = hand()
	var g := RandomNumberGenerator.new()
	var x := pos.x
	for i in count:
		g.seed = 18 + row * 97 + i
		var dy := g.randf_range(-2.0, 2.0)
		var rot := g.randf_range(-0.06, 0.06)
		var ch := s.unicode_at(i)
		var a := 0.6 if wet and i >= count - 6 else 1.0
		c.draw_set_transform_matrix(Transform2D(rot, Vector2.ONE, skew, Vector2(x, pos.y + dy)))
		c.draw_char(font, Vector2.ZERO, s[i], size, Color(ink, a))
		x += font.get_char_size(ch, size).x
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

static func ellipse(center: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var ang := TAU * k / n
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

static func vignette(c: CanvasItem, a: float) -> void:
	if a <= 0.0:
		return
	var w := SIZE.x
	var h := SIZE.y
	var i := 260.0
	var o := Color(0, 0, 0, a)
	var n := Color(0, 0, 0, 0)
	var cols := PackedColorArray([o, o, n, n])
	for quad in [
			[Vector2(0, 0), Vector2(w, 0), Vector2(w - i, i), Vector2(i, i)],
			[Vector2(w, 0), Vector2(w, h), Vector2(w - i, h - i), Vector2(w - i, i)],
			[Vector2(w, h), Vector2(0, h), Vector2(i, h - i), Vector2(w - i, h - i)],
			[Vector2(0, h), Vector2(0, 0), Vector2(i, i), Vector2(i, h - i)]]:
		c.draw_polygon(PackedVector2Array(quad), cols)
