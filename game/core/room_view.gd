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
## Without overrides, this base draws the skeleton placeholder: a flat front elevation in
## the approved palette with every hotspot as a labelled card. Exit tabs are drawn by the
## core on the HUD layer, so they stay legible however dark the room gets.

const SIZE := Vector2(1448, 1086)

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
	draw_placeholder(self)

## A flat front elevation: wall, dado rail, floor, the room's name, and each hotspot as a
## labelled card with an ink contour. Darkens a step per weather milestone, never so far
## that a label stops reading.
func draw_placeholder(cv: CanvasItem) -> void:
	var pal: Dictionary = c("PALETTE", {})
	var wall: Color = pal.get("wall", Color("a9c8b8"))
	var trim: Color = pal.get("trim", Color("2f5b6e"))
	var floor_col: Color = pal.get("floor", Color("7d6e5c"))
	var w := gsim().weather() if gsim() else 0
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
