class_name RoomView
extends Node2D
## Base for every room renderer (game/rooms/<rid>/<rid>_view.gd + .tscn).
##
## The GameView hosts one RoomView at a time on the world layer (layer 0), sets `game`,
## `sim` and `rid` before adding it, and calls the hooks below. A room view only presents
## its sim: it never mutates story state. Everything it times (fades, loops, reveals) is
## presentation and is never saved.
##
## Constants a view declares (see docs/dev/room-contract.md):
##   HOTSPOTS    [[id, Rect2, label], ...] room hotspots, first match wins (small first)
##   EXIT_RECTS  {to_rid: Rect2} where each exit is clicked; the core draws them as tabs
##   SFX_DB      {sfx id: dB} one-shot levels; SFX_SOFT [ids] the sudden ones
##   SFX_SOFT_CUT {sfx id: dB} cut under "Soften sudden sounds" (default 12)
##   PALETTE     {wall, trim, floor} placeholder colours (skeleton rooms only)
##
## A room not built yet (no <rid>_view.tscn, or a skeleton view that declares no functions
## of its own) shows the placeholder card instead: storm navy, the room's name, "The pressure
## gate holds. Not yet." and one exit tab, back the way she came. Its hotspots stay live and
## legible, as stencilled plates on the field.
## Exit tabs are drawn by the core on the HUD layer, so they stay legible however dark the
## room gets.

const SIZE := Vector2(1448, 1086)
const PLACEHOLDER_FIELD := Color("1b2a36")
const PLACEHOLDER_LINE := "The pressure gate holds. Not yet."
const PLACEHOLDER_EXIT := Rect2(20, 922, 250, 64)

static var _skeleton_scripts := {}   # script path -> bool

var game: GameView
var sim: RoomSim
var rid := ""

## "Motion & flicker" and "Soften sudden sounds", from the game's settings.
var motion: bool:
	get:
		return game.sim.settings.motion if game else true
var soft_audio: bool:
	get:
		return game.sim.settings.soft_audio if game else false
## Seconds since the game scene started (presentation clock).
var time: float:
	get:
		return game.time if game else 0.0

## Reads a script constant declared by the view (subclass), with a default.
func c(name: String, default: Variant = null) -> Variant:
	var m: Dictionary = get_script().get_script_constant_map()
	return m.get(name, default)

func gsim() -> GameSim:
	return game.sim if game else null

# ---------------------------------------------------------------------------
# hooks the core calls (override as needed)
# ---------------------------------------------------------------------------
func tick(_dt: float) -> void:
	if motion:
		queue_redraw()

func redraw() -> void:
	queue_redraw()

## Snap every light, loop and overlay to the current state (entry, load, jump).
func apply_instantly() -> void:
	pass

## Clear everything timed (restart, jump).
func reset_presentation() -> void:
	pass

## A sim fx event, e.g. {"type": "fx", "id": "lamp_on"}.
func play_fx(_id: String, _e: Dictionary) -> void:
	pass

## A one-shot is playing now.
func on_sfx(_id: String) -> void:
	pass

## A queued one-shot is `left` seconds away (the office hushes before the knock).
func on_sfx_pending(_id: String, _left: float) -> void:
	pass

func sfx_bus(_id: String) -> String:
	return "Master"

## False in views with their own clock, where a click must not advance a chain.
func chain_gates() -> bool:
	return true

## True in full-screen room views (an interlude card) that hide the HUD and subtitles.
func hud_hidden() -> bool:
	return false

func back_visible() -> bool:
	return sim.is_closeup()

## What Esc does in the room: "back" in a close-up, "menu" otherwise, "" for nothing.
func esc_action() -> String:
	return "back" if sim.is_closeup() else "menu"

## The combined view changed (`before` is the room-local or core view it left).
func on_view_changed(_before: String) -> void:
	pass

## False to hide exits (e.g. during a scripted moment).
func exits_active() -> bool:
	return sim.local_view == "room"

func exit_rects() -> Dictionary:
	return c("EXIT_RECTS", {})

## The exits the core draws and answers: all of exit_rects(), except in an unbuilt room,
## which offers only the way back (placeholder_exit()).
func live_exit_rects() -> Dictionary:
	if not is_skeleton():
		return exit_rects()
	var to := placeholder_exit()
	return {} if to == "" else {to: exit_rects().get(to, PLACEHOLDER_EXIT)}

## True for a room that isn't built yet: the bare RoomView (no view scene), or a skeleton
## view script that adds no functions to this one. A room team's first override ends it.
func is_skeleton() -> bool:
	var s: Script = get_script()
	if s == null:
		return true
	var path := s.resource_path
	if not _skeleton_scripts.has(path):
		var base: Script = load("res://game/core/room_view.gd")
		_skeleton_scripts[path] = s == base or \
			s.get_script_method_list().size() <= base.get_script_method_list().size()
	return _skeleton_scripts[path]

## The placeholder's one way out: back where she came from, else the first open exit.
func placeholder_exit() -> String:
	var exits: Array = sim.c("EXITS", [])
	var from: String = game.came_from if game else ""
	for e in exits:
		if e[0] == from:
			return from
	for e in exits:
		if gsim() and gsim().exit_open(rid, e[0]):
			return e[0]
	return exits[0][0] if not exits.is_empty() else ""

## The room action under `p` for the room's current local view. "" = nothing.
func action_at(p: Vector2) -> String:
	if sim.local_view == "room":
		for h in c("HOTSPOTS", []):
			if h[1].has_point(p):
				return h[0]
	return ""

func hover_at(p: Vector2) -> String:
	if sim.local_view != "room":
		return ""
	for h in c("HOTSPOTS", []):
		if h[1].has_point(p):
			return h[0]
	return ""

func label_for(id: String) -> String:
	for h in c("HOTSPOTS", []):
		if h[0] == id:
			return h[2]
	return ""

func hotspot_rect(id: String) -> Rect2:
	for h in c("HOTSPOTS", []):
		if h[0] == id:
			return h[1]
	return Rect2()

func dev_rects() -> Array:
	var out := []
	for h in c("HOTSPOTS", []):
		out.append(h[1])
	return out

## Draw room-specific HUD extras (on the HUD layer, above everything).
func draw_hud(_c: Node2D) -> void:
	pass

# ---------------------------------------------------------------------------
# the skeleton placeholder
# ---------------------------------------------------------------------------
func _draw() -> void:
	if is_skeleton():
		draw_unbuilt(self)
	else:
		draw_placeholder(self)

## The card an unbuilt room shows: an in-world notice, not a grey diagram. A storm-navy
## bulkhead, the room's name and Ada's line in her hand at the head, each hotspot as a
## brass-ruled stencilled plate (still live), and the exit tab (drawn by the core) back the
## way she came.
func draw_unbuilt(cv: CanvasItem) -> void:
	cv.draw_rect(Rect2(Vector2.ZERO, SIZE), PLACEHOLDER_FIELD)
	# Faint plate seams and rivets, so the field reads as a bulkhead rather than a blank.
	var seam := Color(Ink.SEA_GLASS, 0.07)
	for x in [362, 724, 1086]:
		cv.draw_line(Vector2(x, 0), Vector2(x, SIZE.y), seam, 2.0)
		for y in range(40, int(SIZE.y), 120):
			cv.draw_circle(Vector2(x - 12, y), 3.0, seam)
			cv.draw_circle(Vector2(x + 12, y), 3.0, seam)
	cv.draw_line(Vector2(0, 228), Vector2(SIZE.x, 228), seam, 2.0)
	cv.draw_line(Vector2(0, 880), Vector2(SIZE.x, 880), seam, 2.0)
	var title: String = sim.c("TITLE", rid)
	Ink.text(cv, title, Vector2(0, 120), 40, Ink.PAPER, Ink.serif(), SIZE.x)
	cv.draw_line(Vector2(SIZE.x / 2 - 140, 146), Vector2(SIZE.x / 2 + 140, 146), Color(Ink.BRASS, 0.7), 1.5)
	Ink.text(cv, PLACEHOLDER_LINE, Vector2(0, 192), 28, Ink.NIGHT_INK, Ink.hand(), SIZE.x)
	var serif := Ink.serif()
	for h in c("HOTSPOTS", []):
		var r: Rect2 = h[1]
		cv.draw_rect(r, Color(Ink.STORM, 0.95))
		cv.draw_rect(r, Color(Ink.BRASS, 0.8), false, 2.0)
		cv.draw_rect(r.grow(-8), Color(Ink.BRASS, 0.3), false, 1.0)
		for k in [r.position + Vector2(16, 16), Vector2(r.end.x - 16, r.position.y + 16),
				Vector2(r.position.x + 16, r.end.y - 16), r.end - Vector2(16, 16)]:
			cv.draw_circle(k, 4.0, Color(Ink.BRASS, 0.6))
		var size := 24 if r.size.x >= 180 else 18
		var lines := Ink.wrapped(cv, h[2], Vector2.ZERO, size, Ink.PAPER, r.size.x - 48, false, serif)
		Ink.wrapped(cv, h[2], Vector2(r.position.x + 24, r.get_center().y - lines / 2.0 + size), size,
			Ink.PAPER, r.size.x - 48, true, serif)

## A flat front elevation: wall, dado rail, floor, the room's name, and each hotspot as a
## labelled card with an ink contour. Darkens a step per weather milestone, never so far
## that a label stops reading.
func draw_placeholder(cv: CanvasItem) -> void:
	var pal: Dictionary = c("PALETTE", {})
	var wall: Color = pal.get("wall", Color("a9c8b8"))
	var trim: Color = pal.get("trim", Color("2f5b6e"))
	var floor_col: Color = pal.get("floor", Color("7d6e5c"))
	var w := gsim().weather_band() if gsim() else 0
	var dim := 1.0 - 0.06 * w
	cv.draw_rect(Rect2(Vector2.ZERO, SIZE), wall * Color(dim, dim, dim))
	cv.draw_rect(Rect2(0, 600, SIZE.x, 300), trim * Color(dim, dim, dim))
	cv.draw_rect(Rect2(0, 586, SIZE.x, 14), trim.darkened(0.3))
	cv.draw_rect(Rect2(0, 900, SIZE.x, 186), floor_col * Color(dim, dim, dim))
	for x in range(24, int(SIZE.x), 48):
		cv.draw_line(Vector2(x, 604), Vector2(x, 896), Color(trim.darkened(0.35), 0.5), 2.0)
	var serif := Ink.serif()
	var title: String = sim.c("TITLE", rid)
	# Ink on a light wall, paper on a dark one: the name always reads.
	var ink: Color = Ink.INK if (wall * Color(dim, dim, dim)).get_luminance() > 0.45 else Ink.PAPER
	Ink.text(cv, rid + "  ·  " + title.to_upper(), Vector2(0, 130), 34, Color(ink, 0.9), serif, SIZE.x)
	Ink.text(cv, "placeholder elevation  ·  " + gsim().tide_title() if gsim() else "", Vector2(0, 168), 18,
		Color(ink, 0.6), Ink.hand(), SIZE.x)
	for h in c("HOTSPOTS", []):
		var r: Rect2 = h[1]
		cv.draw_rect(r, Color(Ink.PAPER, 0.92))
		cv.draw_rect(r, Ink.INK, false, 3.0)
		cv.draw_rect(r.grow(-6), Color(Ink.INK, 0.35), false, 1.0)
		var size := 22 if r.size.x >= 180 else 18
		Ink.wrapped(cv, h[2], r.position + Vector2(12, 12 + size), size, Ink.INK, r.size.x - 24)
