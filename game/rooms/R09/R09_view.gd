extends RoomView
## R09, the Lantern Gallery: renderer. Presents R09Sim (game/rooms/R09/R09_sim.gd) and never
## mutates it. Everything timed here (rain, the pennant, the irises, the selector knob, the
## key, the strip, the frame lifting out, the steam, the reveal of the standing sea, notice
## holds, loop fades) is presentation and is never saved.
##
## Layering:
##   `room` (world layer 0, under a CanvasModulate held at 1.0: the painted art must show):
##          view A (the lens wall) or view B (the rail side). Back to front: the sea plate for
##          the stage, rain clipped to the glass, the outer rail, the gallery plate, overlays
##          (lens reflection, irises) and every label.
##   CanvasLayer 5 `close`: the close-ups c_scope (P15) and c_ruler (O05).
##
## Painted plates: assets/rooms/R09/*.png (tools/art/rooms/R09.py). They carry no text: every
## label, numeral, diagram and printed line is drawn here, so the clues stay exact.
##
## The dry rail is the room's first clue: in view A the rain stops at y 510 on a hard row of
## hanging beads, the rail sits at y 560, and the gap between is left empty on purpose (view B:
## beads at y 578, a dry matte top on the rail). Only the sever ending lets it reach.
##
## The upright sea (bands 4-6) is composed here from layers (repaint r2): the standing plane
## `<v>_surf_<band>_r2`, the b3 whitecaps turned on end (`vchop_tile_r2`, drifting sideways) and
## the rooms behind Ada as filled silhouettes (`<v>_refl_<band>_r2`). The reveal stands it up:
## the b3 horizon rises to the surface's top edge, the sea below it stretching upward in its
## wake, and the reflections wipe in behind it.

const DIR := "res://assets/rooms/R09/%s.png"

const PAPER := Color("ded4ba")
const PAPER_HI := Color("e8e1cf")
const ENAMEL := Color("e2dcca")
const INK := Color("172b36")
const VIOLET := Color("746577")
const STORM := Color("22384a")
const BOXWOOD := Color("c4a874")
const BOXWOOD_DK := Color("a48858")

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["lens", Rect2(514, 182, 420, 420), "Signal lens"],
	["aperture_1", Rect2(496, 652, 128, 146), "LAND 1"],
	["aperture_2", Rect2(660, 652, 128, 146), "SEA 2"],
	["aperture_3", Rect2(824, 652, 128, 146), "STATION 3"],
	["scope", Rect2(70, 520, 410, 200), "Scope"],
	["diagram", Rect2(1030, 652, 340, 230), "Reference plate"],
	["to_rail", Rect2(600, 836, 248, 64), "The rail"],
]
## View B, the rail side (a base view, not a close-up).
const RAIL_HOTSPOTS := [
	["ruler", Rect2(840, 762, 420, 76), "Sill"],
	["pennant", Rect2(1120, 250, 200, 340), "Pennant"],
	["rail", Rect2(60, 600, 1328, 140), "Rail"],
	["horizon", Rect2(60, 330, 1328, 100), "Horizon"],
	["glass", Rect2(60, 100, 1328, 500), "Glass"],
	["to_lens", Rect2(600, 850, 248, 64), "The lens"],
]
const EXIT_RECTS := {
	"R11": Rect2(20, 922, 250, 64),
}

## Close-up controls: [id, rect, hover label].
const SCOPE_CONTROLS := [
	["mount", Rect2(90, 150, 440, 330), "Frame clamp"],
	["sel_1", Rect2(90, 640, 140, 150), "LAND 1"],
	["sel_2", Rect2(240, 640, 140, 150), "SEA 2"],
	["sel_3", Rect2(390, 640, 140, 150), "STATION 3"],
	["scope_view", Rect2(620, 150, 640, 640), "Scope"],
	["record", Rect2(620, 820, 300, 110), "RECORD BEARING"],
	["strip_slot", Rect2(940, 820, 320, 110), "Strip slot"],
	["ref_plate", Rect2(90, 820, 440, 110), "Reference plate"],
]
const RULER_CONTROLS := [
	["ruler_face", Rect2(100, 400, 1248, 180), "Ruler"],
	["zoom_out", Rect2(1000, 700, 160, 120), "Back out"],
	["zoom_in", Rect2(1180, 700, 160, 120), "Closer"],
]

## One-shot levels (dB) and the sudden ones "Soften sudden sounds" turns down.
## lid_pass is written 18 dB under deep_tone in its file (tools/audio/rooms/R09.py), so it
## takes deep_tone's gain here; any further cut would lose it under the tone.
const SFX_DB := {
	"sel_click": -4.0, "iris_turn": -6.0, "scope_creak": -8.0, "mount_clamp": -3.0, "clamp_release": -4.0,
	"mount_tap": -6.0, "record_key": -2.0, "key_refuse": -4.0, "strip_feed": -5.0, "nosubject_print": -6.0,
	"lens_slide": -6.0, "glass_tap": -5.0, "glass_tap_dead": -5.0, "lens_touch": -6.0, "glass_hum": -10.0,
	"deep_tone": 0.0, "lid_pass": 0.0, "loupe_step": -6.0, "ruler_lift": -6.0,
}
const SFX_SOFT := ["key_refuse", "mount_tap", "glass_tap"]

const LOOPS := ["r09_room", "r09_clockwork", "r09_wind", "r09_sea_far", "r09_rain_glass", "r09_surface",
	"r09_pressure", "r09_flap"]
## Loop levels (dB) per sea stage; a loop not listed is silent.
const LOOP_DB := {
	"b3": {"r09_room": -14.0, "r09_clockwork": -20.0, "r09_wind": -10.0, "r09_sea_far": -16.0, "r09_rain_glass": -18.0},
	"b4": {"r09_room": -14.0, "r09_clockwork": -20.0, "r09_wind": -12.0, "r09_rain_glass": -20.0, "r09_surface": -24.0},
	"b5": {"r09_room": -14.0, "r09_clockwork": -22.0, "r09_surface": -21.0},
	"b6": {"r09_room": -14.0, "r09_surface": -18.0, "r09_pressure": -24.0},
	"b7": {"r09_room": -16.0, "r09_surface": -16.0, "r09_pressure": -14.0},
	"sever": {"r09_room": -14.0, "r09_clockwork": -20.0, "r09_wind": -8.0, "r09_sea_far": -12.0,
		"r09_rain_glass": -14.0, "r09_flap": -16.0},
}
## The deep sounds the loops duck under (6 dB).
const DUCK_IDS := ["deep_tone", "lid_pass", "glass_hum"]
const LOOP_RATE := 0.11        # linear units / s: about a 1.5 s fade at these levels

## Ambient per weather band: held at full (owner rule: the painted art must show).
const TINT := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

# --- view A geometry ----------------------------------------------------------------------
const A_GLASS := Rect2(52, 162, 1344, 466)         # the panes, y 162..628
const A_RAIN := Rect2(52, 162, 1344, 348)          # rain stops at y 510: the dry gap above the rail
const A_BEADS := Vector2(52, 504)                  # beads_r2: its bead line (y 6) on the stop line
const A_RAIN_SEVER := Rect2(52, 162, 1344, 466)    # sever: down to y 628, onto the rail
const PORTS := [Vector2(560, 708), Vector2(724, 708), Vector2(888, 708)]
const A_PLATES := [Rect2(500, 758, 120, 34), Rect2(664, 758, 120, 34), Rect2(828, 758, 120, 34)]
const DIAGRAM := Rect2(1030, 652, 340, 230)
const LENS_AT := Vector2(504, 172)
const RAIL_TAB := Rect2(600, 836, 248, 64)
const SURF_TOP := 212.0
const SURF_BOTTOM := 628.0
const IRIS_TIME := 0.3
## Rain speed (px/s) by band; band 7 hangs. Sever pours.
const RAIN_SPEED := {3: 40.0, 4: 30.0, 5: 20.0, 6: 12.0, 7: 0.0}
const RAIN_SEVER := 600.0

# --- view B geometry ----------------------------------------------------------------------
const B_RAIN := Rect2(60, 100, 1328, 480)
const B_RAIN_SEVER := Rect2(60, 100, 1328, 660)
const B_BEADS := Vector2(60, 572)
const B_GLASS := Rect2(60, 100, 1328, 660)
const B_SURF_TOP := 140.0
## The whitecaps on end drift sideways (px/s); still under Motion off.
const CREST_DRIFT := 7.0
const PENNANT_ANCHOR := Vector2(1190, 270)
const PENNANT_FLAP := 0.18
const B_RULER_AT := Vector2(850, 782)
const LENS_TAB := Rect2(600, 850, 248, 64)

# --- c_scope geometry ---------------------------------------------------------------------
const EYE_C := Vector2(940, 470)
const EYE_R := 300.0
const VIEW_AT := Vector2(630, 160)
const RING_AT := Vector2(600, 130)
const CAPTION := Rect2(630, 104, 620, 44)
## The selector is a lever quadrant: the lever hangs from a boss on the tube and its knob sits in a
## detent notch per position (degrees from straight down; knob x 160 / 310 / 460).
const QUAD_PIVOT := Vector2(310, 515)
const QUAD_R := 200.0
const KNOB_ANG := [-48.6, 0.0, 48.6]
const KNOB_TIME := 0.25
const SEL_PLATES := [Rect2(100, 760, 120, 32), Rect2(250, 760, 120, 32), Rect2(400, 760, 120, 32)]
const FRAME_AT := Vector2(110, 170)
const FRAME_EJECT := 0.35
const FRAME_EJECT_FALLBACK := 2.4
const KEY_AT := Vector2(630, 827)
const KEY_DOWN_TIME := 0.25
const STRIP_X0 := 950.0
const STRIP_X1 := 1250.0
const STRIP_Y := 828.0
const STRIP_H := 96.0
const STRIP_TIME := 1.4
const STRIP_FALLBACK := 0.4
const REF_TEXT := Rect2(100, 826, 420, 98)
const STEAM_LOOP := 3.0
const STEAM_RISE := 12.0
## Breath-trace shapes in section-local coordinates (R07's c_frame): x 0..1, y up from 0.2.
const SHAPES := {
	"short": [Vector2(0, 0.2), Vector2(0.10, 0.2), Vector2(0.22, 0.55), Vector2(0.32, 0.2),
		Vector2(0.45, 0.2), Vector2(0.57, 0.55), Vector2(0.67, 0.2), Vector2(1, 0.2)],
	"pause": [Vector2(0, 0.2), Vector2(1, 0.2)],
	"long": [Vector2(0, 0.2), Vector2(0.05, 0.2), Vector2(0.75, 0.85), Vector2(0.95, 0.2), Vector2(1, 0.2)],
}

# --- c_ruler geometry ---------------------------------------------------------------------
const MAG_C := Vector2(560, 760)
const MAG_R := 180.0
const ZOOM_PITCH := 32.0
const ZOOM_WORD := ["×1", "×10", "×100", "×1000"]

# --- the reveal (fx reveal_upright) -------------------------------------------------------
const RISE_END := 3.5
const B3_HORIZON := 400.0
const SHUT_END := 6.5
const LID_START := 7.0
const LID_END := 13.0
const STILL_TIME := 4.0
const STILL_LID_Y := 420.0

## Notice holds: focus rects in view A.
const HOLD_TIME := 1.5
const HOLD_ZOOM := 0.06
const NOTICE_FOCUS := {
	"dry_rail": Rect2(52, 520, 1344, 108),
	"upright": Rect2(52, 162, 1344, 466),
	"no_sky": Rect2(52, 162, 1344, 120),
	"lighthouse_inverted": Rect2(1090, 170, 280, 330),
	"no_edge": Rect2(504, 172, 440, 440),
}

var r: R09Sim:
	get:
		return sim as R09Sim

var textures := {}
var narrow: SystemFont
var narrow_reg: SystemFont
var room: Node2D
var close: Node2D
var shade: CanvasModulate
var mixer: LoopMixer

# presentation state (never saved)
var hold_t := 0.0
var hold_id := ""
var hold_rect := Rect2()
var zoom_k := 0.0
var tint := 1.0
var reveal_t := -1.0            # seconds into the standing-up of the sea, -1 = none
var iris_t := -1.0              # seconds into the iris tween, -1 = settled
var iris_prev := 0              # the port whose iris is closing
var knob_from := 0.0            # lever angle (degrees) the knob is leaving
var knob_to := 2                # the aperture the knob (and the open iris) is heading to
var knob_t := -1.0
var key_t := 0.0                # the RECORD key held down
var eject_t := -1.0             # seconds into the frame lifting out, -1 = none
var eject_wait := -1.0          # seconds waited for clamp_release, -1 = none
var strip_t := -1.0             # seconds into the strip feeding out, -1 = settled
var strip_wait := -1.0          # seconds waited for strip_feed, -1 = none

func _ready() -> void:
	narrow = SystemFont.new()
	narrow.font_names = PackedStringArray(["Liberation Sans Narrow", "Nimbus Sans Narrow", "DejaVu Sans Condensed", "sans-serif"])
	narrow.font_weight = 700
	narrow_reg = SystemFont.new()
	narrow_reg.font_names = narrow.font_names
	_build_nodes()
	_build_audio()
	apply_instantly()
	redraw()

func _tex(id: String) -> Texture2D:
	if not textures.has(id):
		var path := DIR % id
		textures[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return textures[id]

func _build_nodes() -> void:
	room = Node2D.new()
	room.name = "Room"
	add_child(room)
	room.draw.connect(_draw_room)
	shade = CanvasModulate.new()
	add_child(shade)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	close = Node2D.new()
	layer.add_child(close)
	close.draw.connect(_draw_close)

func _build_audio() -> void:
	mixer = LoopMixer.new()
	add_child(mixer)
	if game == null:
		return
	for id in LOOPS:
		mixer.add_loop(id, game.load_audio(id))

# ---------------------------------------------------------------------------
# state reads (presentation only)
# ---------------------------------------------------------------------------
func _view() -> String:
	return r.local_view

func _band() -> int:
	return clampi(r.band(), 0, 7)

func _sever() -> bool:
	return r.ending() == "sever"

## The sea stage the plates and loops follow: b3..b7 or sever.
func stage() -> String:
	return r.sea_stage()

func _stage_band() -> int:
	var s := stage()
	return 0 if s == "sever" else int(s.substr(1))

## The sea behind the glass for the stage, as layers: [plate, reflections, reflection alpha,
## whitecaps-on-end alpha, top of the standing plane]. b3, b7 and sever are single plates.
func sea_layers(side: String) -> Array:
	var s := stage()
	var top := SURF_TOP if side == "a" else B_SURF_TOP
	match s:
		"sever":
			return ["a_sea_sever" if side == "a" else "b_sea_sever_r2", "", 0.0, 0.0, 0.0]
		"b3":
			return ["a_sea_b3" if side == "a" else "b_sea_b3_r2", "", 0.0, 0.0, 0.0]
		"b4":
			return [side + ("_surf_b4o_r2" if side == "a" else "_surf_b4_r2"), side + "_refl_b4_r2", 1.0, 0.8, top]
		"b5":
			return [side + "_surf_b5_r2", side + "_refl_b4_r2", 0.85, 0.8, 0.0]
		"b6":
			return [side + "_surf_b6_r2", side + "_refl_b6_r2", 1.0, 0.75, 0.0]
	return [side + "_sea_b7_r2", "", 0.0, 0.3, 0.0]

## The main plate of the stage (for tests and review tools).
func sea_plate(side: String) -> String:
	return sea_layers(side)[0]

func rain_speed() -> float:
	if not motion:
		return 0.0
	if _sever():
		return RAIN_SEVER
	return RAIN_SPEED.get(clampi(_stage_band(), 3, 7), 0.0)

func reveal_running() -> bool:
	return reveal_t >= 0.0 and reveal_t < reveal_len()

func reveal_len() -> float:
	return LID_END if motion else STILL_TIME

## Where the lid line is now (view A y), or -1 when none is drawn.
func lid_y() -> float:
	if not reveal_running():
		return -1.0
	if not motion:
		return STILL_LID_Y
	if reveal_t < LID_START:
		return -1.0
	return lerpf(SURF_TOP, SURF_BOTTOM, clampf((reveal_t - LID_START) / (LID_END - LID_START), 0.0, 1.0))

func knob_angle() -> float:
	var target: float = KNOB_ANG[clampi(knob_to, 1, 3) - 1]
	if knob_t < 0.0 or not motion:
		return target
	return lerpf(knob_from, target, smoothstep(0.0, 1.0, knob_t / KNOB_TIME))

func knob_pos() -> Vector2:
	var a := deg_to_rad(knob_angle())
	return QUAD_PIVOT + Vector2(sin(a), cos(a)) * QUAD_R

## 0..1 of the strip shown (fed out), -1 when no strip is drawn.
func strip_k() -> float:
	if strip_t >= 0.0:
		return 1.0 if not motion else clampf(strip_t / STRIP_TIME, 0.0, 1.0)
	if strip_wait >= 0.0:
		return 0.0
	return 1.0 if r.state.p15_complete else -1.0

## The frame is drawn in the clamp while mounted, and while its eject waits for its sound.
func frame_in_clamp() -> bool:
	return bool(r.state.frame_mounted) or eject_wait >= 0.0

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func tick(dt: float) -> void:
	if hold_t > 0.0:
		hold_t = maxf(0.0, hold_t - dt)
	var zt := 1.0 if hold_t > 0.0 and motion and not r.is_closeup() else 0.0
	zoom_k = move_toward(zoom_k, zt, dt * 2.5)
	var s := 1.0 + HOLD_ZOOM * smoothstep(0.0, 1.0, zoom_k)
	var focus := hold_rect.get_center()
	room.scale = Vector2(s, s)
	room.position = focus * (1.0 - s)
	if reveal_t >= 0.0:
		var was := reveal_running()
		reveal_t += dt
		if was and not reveal_running():
			_on_reveal_end()
	if iris_t >= 0.0:
		iris_t += dt
		if iris_t >= IRIS_TIME or not motion:
			iris_t = -1.0
	if knob_t >= 0.0:
		knob_t += dt
		if knob_t >= KNOB_TIME or not motion:
			knob_t = -1.0
	if knob_t < 0.0 and iris_t < 0.0:
		knob_to = int(r.state.aperture)
	key_t = maxf(0.0, key_t - dt)
	if eject_wait >= 0.0:
		eject_wait += dt
		if eject_wait > FRAME_EJECT_FALLBACK:
			_start_eject()
	if eject_t >= 0.0:
		eject_t += dt
		if eject_t >= FRAME_EJECT or not motion:
			eject_t = -1.0
	if strip_wait >= 0.0:
		if game and game.sfx_pending("strip_feed"):
			strip_wait = 0.0
		else:
			strip_wait += dt
			if strip_wait > STRIP_FALLBACK:
				_start_strip()
	if strip_t >= 0.0:
		strip_t += dt
		if strip_t >= STRIP_TIME or not motion:
			strip_t = -1.0
	var tt: float = TINT[_band()]
	tint = move_toward(tint, tt, dt * 0.2)
	shade.color = Color(tint, tint, tint)
	_tick_audio(dt)
	redraw()

func _on_reveal_end() -> void:
	reveal_t = -1.0

func loop_targets() -> Dictionary:
	var key := stage()
	if r.ending() == "continue":
		key = "b7"
	var db: Dictionary = LOOP_DB.get(key, LOOP_DB["b3"])
	var in_close := r.is_closeup()
	var duck := game != null and game.oneshot_playing(DUCK_IDS)
	var out := {}
	for id in LOOPS:
		if not db.has(id):
			out[id] = 0.0
			continue
		var v: float = db[id]
		if in_close and id != "r09_room":
			v -= 4.0
		if duck:
			v -= 6.0
		out[id] = db_to_linear(v)
	return out

func _tick_audio(dt: float) -> void:
	var rates := {}
	for id in LOOPS:
		rates[id] = LOOP_RATE
	mixer.tick(loop_targets(), rates, dt)

# ---------------------------------------------------------------------------
# hooks
# ---------------------------------------------------------------------------
func play_fx(id: String, e: Dictionary) -> void:
	if id.begins_with("notice_"):
		_start_hold(id.substr(7))
		return
	match id:
		"reveal_upright":
			reveal_t = 0.0
			hold_t = 0.0   # the reveal is the notice; no zoom on top of it
		"aim":
			var n := clampi(int(e.get("aperture", r.state.aperture)), 1, 3)
			knob_from = knob_angle()
			iris_prev = knob_to if knob_to != n else 0
			knob_to = n
			iris_t = 0.0 if motion else -1.0
			knob_t = 0.0 if motion else -1.0
		"record_key":
			key_t = KEY_DOWN_TIME
		"strip_feed":
			strip_wait = 0.0
			strip_t = -1.0
		"frame_eject":
			eject_wait = 0.0
			eject_t = -1.0
	redraw()

func on_sfx(id: String) -> void:
	match id:
		"record_key":
			key_t = KEY_DOWN_TIME
		"strip_feed":
			_start_strip()
		"clamp_release":
			_start_eject()

func _start_strip() -> void:
	if strip_wait < 0.0:
		return
	strip_wait = -1.0
	strip_t = 0.0 if motion else -1.0

func _start_eject() -> void:
	if eject_wait < 0.0:
		return
	eject_wait = -1.0
	eject_t = 0.0 if motion else -1.0

func _start_hold(n: String) -> void:
	var rect: Rect2 = NOTICE_FOCUS.get(n, Rect2())
	if rect.size == Vector2.ZERO:
		return
	if n == "upright" and reveal_running():
		return
	hold_id = n
	hold_rect = rect
	hold_t = HOLD_TIME

## The P15 reward is the reveal itself: the core's brackets are not drawn while it runs.
func start_glance(_target: String, _rect: Rect2) -> bool:
	return reveal_running()

func exit_arrow(to: String) -> String:
	return "down" if to == "R11" else ""

func hold_active() -> bool:
	return hold_t > 0.0

func apply_instantly() -> void:
	reset_presentation()
	tint = TINT[_band()]
	shade.color = Color(tint, tint, tint)
	if mixer:
		mixer.snap(loop_targets())
	room.scale = Vector2.ONE
	room.position = Vector2.ZERO

func reset_presentation() -> void:
	hold_t = 0.0
	hold_id = ""
	hold_rect = Rect2()
	zoom_k = 0.0
	reveal_t = -1.0
	iris_t = -1.0
	iris_prev = 0
	knob_to = int(r.state.aperture)
	knob_t = -1.0
	key_t = 0.0
	eject_t = -1.0
	eject_wait = -1.0
	strip_t = -1.0
	strip_wait = -1.0

func redraw() -> void:
	room.queue_redraw()
	close.queue_redraw()

func back_visible() -> bool:
	return _view() != "room"

func esc_action() -> String:
	return "back" if _view() != "room" else "menu"

func exits_active() -> bool:
	return _view() in ["room", "rail"]

# ---------------------------------------------------------------------------
# input (action_at and hover_at are pure; a hold skip is consume_click's)
# ---------------------------------------------------------------------------
func closeup_controls(cid: String) -> Array:
	match cid:
		"c_scope":
			return SCOPE_CONTROLS
		"c_ruler":
			return RULER_CONTROLS
	return []

func _controls() -> Array:
	match _view():
		"room":
			return HOTSPOTS
		"rail":
			return RAIL_HOTSPOTS
	return closeup_controls(_view())

func consume_click(_p: Vector2) -> bool:
	if hold_t > 0.0:
		hold_t = 0.0
		return true
	return false

func action_at(p: Vector2) -> String:
	if hold_t > 0.0:
		return ""
	for h in _controls():
		if h[1].has_point(p):
			return h[0]
	return ""

func hover_at(p: Vector2) -> String:
	return action_at(p)

func label_for(id: String) -> String:
	if id == "ruler":
		return "Ruler" if r.state.p15_complete else "Sill"
	for table in [HOTSPOTS, RAIL_HOTSPOTS, SCOPE_CONTROLS, RULER_CONTROLS]:
		for h in table:
			if h[0] == id:
				return h[2]
	return ""

func hotspot_rect(id: String) -> Rect2:
	for table in [HOTSPOTS, RAIL_HOTSPOTS]:
		for h in table:
			if h[0] == id:
				return h[1]
	return Rect2()

func dev_rects() -> Array:
	var out := []
	for h in _controls():
		out.append(h[1])
	return out

# ---------------------------------------------------------------------------
# drawing helpers
# ---------------------------------------------------------------------------
func _full(c: CanvasItem, id: String, a := 1.0) -> void:
	var t := _tex(id)
	if t:
		c.draw_texture_rect(t, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, a))

## A band of a full-size plate: rows y0..y1 only.
func _band_of(c: CanvasItem, id: String, y0: float, y1: float, a := 1.0) -> void:
	var t := _tex(id)
	if t == null or y1 <= y0:
		return
	var rect := Rect2(0, y0, SIZE.x, y1 - y0)
	c.draw_texture_rect_region(t, rect, rect, Color(1, 1, 1, a))

func _sprite(c: CanvasItem, id: String, at: Vector2, a := 1.0) -> void:
	var t := _tex(id)
	if t:
		c.draw_texture(t, at, Color(1, 1, 1, a))

## A sprite centred on `centre`, scaled `k`.
func _sprite_c(c: CanvasItem, id: String, centre: Vector2, k := 1.0, a := 1.0) -> void:
	var t := _tex(id)
	if t:
		var sz := t.get_size() * k
		c.draw_texture_rect(t, Rect2(centre - sz / 2.0, sz), false, Color(1, 1, 1, a))

## Centred on x; `y` is the baseline.
func _ctext(c: CanvasItem, s: String, x: float, y: float, size: int, col: Color, font: Font = null) -> void:
	var f: Font = font if font else narrow
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(f, Vector2(x - w / 2.0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## Centred in `rect`.
func _rtext(c: CanvasItem, s: String, rect: Rect2, size: int, col: Color, font: Font = null) -> void:
	var f: Font = font if font else narrow
	_ctext(c, s, rect.get_center().x, rect.get_center().y + f.get_ascent(size) * 0.5 - f.get_descent(size) * 0.3,
		size, col, f)

func _wrap(s: String, font: Font, size: int, width: float) -> Array:
	var out := []
	var line := ""
	for word in s.split(" "):
		var trial: String = word if line == "" else line + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out

## Wrapped lines, left aligned from `pos` (first baseline); returns the next baseline.
func _para(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, width: float, font: Font = null,
		lead := 1.25) -> float:
	var f: Font = font if font else narrow_reg
	var y := pos.y
	for line in _wrap(s, f, size, width):
		c.draw_string(f, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		y += size * lead
	return y

## An enamel tab with an ink edge and centred narrow text (the nav tabs).
func _tab(c: CanvasItem, rect: Rect2, s: String) -> void:
	c.draw_rect(Rect2(rect.position + Vector2(4, 5), rect.size), Color(0.05, 0.08, 0.1, 0.35))
	c.draw_rect(rect, ENAMEL)
	c.draw_rect(rect, INK, false, 2.5)
	c.draw_rect(rect.grow(-5), Color(INK, 0.35), false, 1.0)
	_rtext(c, s, rect, 26, INK)

## Ink corner brackets round `rect` (the still alternative to the hold zoom).
func _brackets(c: CanvasItem, rect: Rect2) -> void:
	var g := rect.grow(14)
	var arm := minf(48.0, minf(g.size.x, g.size.y) * 0.3)
	for corner in [[g.position, Vector2(1, 1)], [Vector2(g.end.x, g.position.y), Vector2(-1, 1)],
			[g.end, Vector2(-1, -1)], [Vector2(g.position.x, g.end.y), Vector2(1, -1)]]:
		var p: Vector2 = corner[0]
		var s: Vector2 = corner[1]
		for pass_ in [[PAPER_HI, 9.0], [STORM, 5.0]]:
			c.draw_polyline(PackedVector2Array([p + Vector2(0, s.y * arm), p, p + Vector2(s.x * arm, 0)]),
				pass_[0], pass_[1])

## The relation mark: two upright strokes bound together by a loop, `s` px tall, centred on
## `at`. A shape, not a letter: it reads the same in any colour.
func _rel_mark(c: CanvasItem, at: Vector2, s: float, col: Color, w := 3.0) -> void:
	var h := s / 2.0
	var dx := 0.17 * s
	c.draw_line(at + Vector2(-dx, -h), at + Vector2(-dx, h), col, w, true)
	c.draw_line(at + Vector2(dx, -h), at + Vector2(dx, h), col, w, true)
	var ring := Ink.ellipse(at, 0.4 * s, 0.3 * s, 32)
	ring.append(ring[0])
	c.draw_polyline(ring, col, maxf(1.5, w * 0.7), true)

## The mark on a pale halo, for reading over a dark picture.
func _rel_mark_halo(c: CanvasItem, at: Vector2, s: float, col: Color, w := 3.0) -> void:
	_rel_mark(c, at, s, Color(PAPER_HI, 0.85), w + 3.0)
	_rel_mark(c, at, s, col, w)

func _arrow(c: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 2.5) -> void:
	c.draw_line(a, b, col, w, true)
	var d := (b - a).normalized()
	var n := d.orthogonal()
	c.draw_colored_polygon(PackedVector2Array([b + d * 2.0, b - d * 10.0 + n * 6.0, b - d * 10.0 - n * 6.0]), col)

func _wave(c: CanvasItem, x0: float, x1: float, y: float, col: Color, w := 2.0) -> void:
	var pts := PackedVector2Array()
	var n := 16
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		pts.append(Vector2(x, y + 3.0 * sin(float(i) / n * TAU * 2.0)))
	c.draw_polyline(pts, col, w, true)

## A tileable sprite repeated over `clip`, shifted by `off` (wrapped to the tile).
func _tile(c: CanvasItem, id: String, clip: Rect2, off: Vector2, a := 1.0) -> void:
	var t := _tex(id)
	if t == null or a <= 0.0 or clip.size.x <= 0.0 or clip.size.y <= 0.0:
		return
	var ts := t.get_size()
	var y := clip.position.y - ts.y + fposmod(off.y, ts.y)
	while y < clip.end.y:
		var x := clip.position.x - ts.x + fposmod(off.x, ts.x)
		while x < clip.end.x:
			var tile := Rect2(Vector2(x, y), ts)
			var dst := tile.intersection(clip)
			if dst.size.x > 0.0 and dst.size.y > 0.0:
				c.draw_texture_rect_region(t, dst, Rect2(dst.position - tile.position, dst.size), Color(1, 1, 1, a))
			x += ts.x
		y += ts.y

## Rain, scrolled down and clipped to `clip`. Bands 6-7 thin it by half so the surface shows.
func _rain(c: CanvasItem, clip: Rect2) -> void:
	var sparse := not _sever() and _stage_band() >= 6
	var off := time * rain_speed() if rain_speed() > 0.0 else 0.0
	_tile(c, "rain_sparse_r2" if sparse else "rain_tile", clip, Vector2(0, off))

## The standing plane's layers for rows y0..y1 of `glass`: plate, whitecaps on end, reflections.
func _surface_rows(c: CanvasItem, glass: Rect2, surf: String, refl: String, refl_a: float, crest_a: float,
		y0: float, y1: float) -> void:
	_band_of(c, surf, y0, y1)
	var drift := time * CREST_DRIFT if motion else 0.0
	var clip := Rect2(glass.position.x, maxf(y0, glass.position.y), glass.size.x, minf(y1, glass.end.y) - maxf(y0, glass.position.y))
	_tile(c, "vchop_tile_r2", clip, Vector2(drift, 0), crest_a)
	if refl != "":
		_band_of(c, refl, y0, y1, refl_a)

func _draw_sea(c: CanvasItem, side: String) -> void:
	var L := sea_layers(side)
	var glass := A_GLASS if side == "a" else B_GLASS
	var top: float = L[4]
	if top > 0.0:
		_band_of(c, L[0], 0.0, top)
	_surface_rows(c, glass, L[0], L[1], L[2], L[3], top, SIZE.y)

func _beads(c: CanvasItem, at: Vector2) -> void:
	if not _sever():
		_sprite(c, "beads_r2", at)

# ---------------------------------------------------------------------------
# drawing: view A and view B (world)
# ---------------------------------------------------------------------------
func _draw_room() -> void:
	if _view() in ["rail", "c_ruler"]:
		_draw_view_b(room)
	else:
		_draw_view_a(room)
	if hold_t > 0.0 and not r.is_closeup() and not motion:
		_brackets(room, hold_rect)

func _draw_view_a(c: CanvasItem) -> void:
	_draw_sea_a(c)
	_rain(c, A_RAIN_SEVER if _sever() else A_RAIN)
	_beads(c, A_BEADS)
	_full(c, "a_rail_wet" if r.rail_wet() else "a_rail")
	_full(c, "a_room_r2")
	match r.lens_reflection():
		"ada":
			_sprite(c, "a_lens_ada", LENS_AT)
		"ada_inv":
			_sprite(c, "a_lens_ada_inv_r2", LENS_AT)
		_:
			# from band 5 the lens carries the standing surface, upside down, its warm point
			if not reveal_running() and stage() in ["b5", "b6"]:
				_sprite(c, "a_lens_surf_%s_r2" % stage(), LENS_AT)
	_lens_lid(c)
	# irises: the open one on the aperture's port, the other two shut
	var ap := knob_to if iris_t >= 0.0 else int(r.state.aperture)
	for k in 3:
		var n := k + 1
		var port: Vector2 = PORTS[k]
		if n == ap:
			if iris_t >= 0.0:
				_sprite_c(c, "a_iris_shut", port)
				_sprite_c(c, "a_iris_open", port, lerpf(0.3, 1.0, smoothstep(0.0, 1.0, iris_t / IRIS_TIME)))
			else:
				_sprite_c(c, "a_iris_open", port)
		else:
			_sprite_c(c, "a_iris_shut", port)
			if iris_t >= 0.0 and n == iris_prev:
				_sprite_c(c, "a_iris_open", port, lerpf(1.0, 0.3, smoothstep(0.0, 1.0, iris_t / IRIS_TIME)),
					1.0 - iris_t / IRIS_TIME)
	for k in 3:
		_rtext(c, R09Sim.APERTURES[k + 1], A_PLATES[k], 22, INK)
	_draw_diagram(c)
	_tab(c, RAIL_TAB, "THE RAIL")

## The sea behind view A's glass, or the standing-up of it while the reveal runs.
func _draw_sea_a(c: CanvasItem) -> void:
	if not reveal_running():
		_draw_sea(c, "a")
		return
	var shut := ["a_surf_b4_r2", "a_refl_b4_r2", 1.0, 0.8]
	var opened := ["a_surf_b4o_r2", "a_refl_b4_r2", 1.0, 0.8]
	if not motion:
		# Motion off: cut straight to the standing surface; the lid holds still on it
		_band_of(c, "a_surf_b4_r2", 0.0, SURF_TOP)
		_surface_rows(c, A_GLASS, opened[0], opened[1], opened[2], opened[3], SURF_TOP, SIZE.y)
		_lid_band(c, STILL_LID_Y)
		return
	var t := reveal_t
	if t < RISE_END:
		_draw_rise(c, smoothstep(0.0, 1.0, t / RISE_END))
		return
	_band_of(c, "a_surf_b4_r2", 0.0, SURF_TOP)
	_surface_rows(c, A_GLASS, shut[0], shut[1], shut[2], shut[3], SURF_TOP, SIZE.y)
	var ly := lid_y()
	if ly < 0.0:
		return
	# behind the lid the surface has opened
	_surface_rows(c, A_GLASS, opened[0], opened[1], opened[2], opened[3], SURF_TOP, ly)
	_lid_band(c, ly)

## The standing-up, k 0..1: the b3 horizon rises to the surface's top edge; the sea under it
## stretches upward (the whitecaps slide up in its wake) and turns into the standing plane, and
## the reflections wipe in from the rail behind it.
func _draw_rise(c: CanvasItem, k: float) -> void:
	_full(c, "a_sea_b3")
	var hy := lerpf(B3_HORIZON, SURF_TOP, k)
	var t := _tex("a_sea_b3")
	if t:
		c.draw_texture_rect_region(t, Rect2(0, hy, SIZE.x, SURF_BOTTOM - hy),
			Rect2(0, B3_HORIZON, SIZE.x, SURF_BOTTOM - B3_HORIZON))
	var stand := smoothstep(0.25, 0.95, k)
	_band_of(c, "a_surf_b4_r2", hy, SURF_BOTTOM, stand)
	var drift := Vector2(0, -60.0 * (1.0 - k))
	_tile(c, "vchop_tile_r2", Rect2(A_GLASS.position.x, hy, A_GLASS.size.x, SURF_BOTTOM - hy), drift, 0.8 * stand)
	# the reflections, revealed by a front that climbs from the rail to the edge
	var fy := lerpf(SURF_BOTTOM, hy, smoothstep(0.1, 1.0, k))
	var feather := 24.0
	_band_of(c, "a_refl_b4_r2", fy + feather, SURF_BOTTOM)
	for i in 3:
		var y0 := fy + feather * i / 3.0
		_band_of(c, "a_refl_b4_r2", y0, y0 + feather / 3.0, (i + 1) / 4.0)
	# the horizon itself: crisp, level, rising
	c.draw_line(Vector2(A_GLASS.position.x, hy), Vector2(A_GLASS.end.x, hy), INK, 3.0)
	c.draw_line(Vector2(A_GLASS.position.x, hy + 3.0), Vector2(A_GLASS.end.x, hy + 3.0), Color(PAPER_HI, 0.55), 1.6)

## The lid: a storm-navy band, feathered above, its wet paper rim (the eyelid edge) at `y`.
func _lid_band(c: CanvasItem, y: float) -> void:
	var t := _tex("a_lid_band_r2")
	if t == null:
		return
	var sz := t.get_size()
	var top := y - 92.0
	var cut := maxf(0.0, SURF_TOP - top)       # never over the sky above the surface's edge
	if cut >= sz.y:
		return
	c.draw_texture_rect_region(t, Rect2(A_GLASS.position.x, top + cut, sz.x, sz.y - cut), Rect2(0, cut, sz.x, sz.y - cut))

## The lid, inverted, through the lens: it climbs while the real one falls, rim on top.
func _lens_lid(c: CanvasItem) -> void:
	var ly := lid_y()
	if ly < 0.0:
		return
	var k := clampf((ly - SURF_TOP) / (SURF_BOTTOM - SURF_TOP), 0.0, 1.0)
	var R := 198.0
	var y := lerpf(LENS_C.y + R + 20.0, LENS_C.y - R - 40.0, k)
	_chord(c, y + 4.0, y + 36.0, Color(STORM.darkened(0.25), 0.88))
	for i in 4:
		_chord(c, y + 36.0 + i * 6.0, y + 42.0 + i * 6.0, Color(STORM.darkened(0.25), 0.66 - i * 0.15))
	_chord(c, y - 1.0, y + 4.0, Color(PAPER_HI, 0.92))
	_chord(c, y - 3.0, y - 1.0, INK)

const LENS_C := Vector2(724, 392)

## Fill the slice y0..y1 of the lens disc.
func _chord(c: CanvasItem, y0: float, y1: float, col: Color) -> void:
	var R := 198.0
	var a := maxf(y0, LENS_C.y - R)
	var b := minf(y1, LENS_C.y + R)
	if b <= a:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := 6
	for i in n + 1:
		var yy := lerpf(a, b, float(i) / n)
		var dx := sqrt(maxf(0.0, R * R - pow(yy - LENS_C.y, 2)))
		left.append(Vector2(LENS_C.x - dx, yy))
		right.append(Vector2(LENS_C.x + dx, yy))
	right.reverse()
	left.append_array(right)
	c.draw_colored_polygon(left, col)

## The reference plate: its title, the rule and the schematic. Every symbol has its word.
func _draw_diagram(c: CanvasItem) -> void:
	var p := DIAGRAM
	_ctext(c, "REFERENCE · BEARING", p.get_center().x, p.position.y + 32, 20, INK)
	c.draw_line(Vector2(p.position.x + 24, p.position.y + 42), Vector2(p.end.x - 24, p.position.y + 42),
		Color(INK, 0.5), 1.5)
	var y := p.position.y + 64
	y = _para(c, "Bearing follows the recorded subject's location, not the water.", Vector2(p.position.x + 22, y), 17,
		INK, p.size.x - 44)
	_para(c, "Match the relation mark.", Vector2(p.position.x + 22, y), 17, INK, p.size.x - 44, narrow)
	# schematic: FRAME --BEARING--> SUBJECT    [ WATER ] BOUNDARY
	var sy := p.position.y + 136.0
	var frame := Rect2(p.position.x + 18, sy, 74, 50)
	c.draw_rect(frame, Color(PAPER_HI, 0.6))
	c.draw_rect(frame, INK, false, 2.0)
	_rel_mark(c, frame.position + Vector2(37, 18), 22, VIOLET, 3.0)
	_ctext(c, "RELATION", frame.get_center().x, frame.end.y - 6, 12, INK, narrow_reg)
	_ctext(c, "FRAME", frame.get_center().x, frame.end.y + 18, 14, INK)
	var subj := Rect2(p.position.x + 176, sy + 2, 46, 46)
	_arrow(c, Vector2(frame.end.x + 6, frame.get_center().y), Vector2(subj.position.x - 6, frame.get_center().y), INK)
	_ctext(c, "BEARING", (frame.end.x + subj.position.x) / 2.0, frame.get_center().y - 8, 13, INK)
	c.draw_rect(subj, Color(PAPER_HI, 0.6))
	c.draw_rect(subj, INK, false, 2.0)
	_rel_mark(c, subj.get_center(), 22, VIOLET, 3.0)
	_ctext(c, "SUBJECT", subj.get_center().x, frame.end.y + 18, 14, INK)
	# the water, bracketed off; the arrow never reaches it
	var wx0 := p.position.x + 244
	var wx1 := p.end.x - 16
	for k in 2:
		var bx := wx0 if k == 0 else wx1
		var d := 8.0 if k == 0 else -8.0
		c.draw_polyline(PackedVector2Array([Vector2(bx + d, sy), Vector2(bx, sy), Vector2(bx, sy + 50),
			Vector2(bx + d, sy + 50)]), INK, 2.5)
	for k in 3:
		_wave(c, wx0 + 10, wx1 - 10, sy + 12 + k * 13, Color(INK, 0.8), 2.0)
	_ctext(c, "WATER", (wx0 + wx1) / 2.0, frame.end.y + 18, 14, INK)
	_ctext(c, "BOUNDARY", (wx0 + wx1) / 2.0, frame.end.y + 34, 12, INK, narrow_reg)

func _draw_view_b(c: CanvasItem) -> void:
	_draw_sea(c, "b")
	_rain(c, B_RAIN_SEVER if _sever() else B_RAIN)
	_beads(c, B_BEADS)
	_full(c, "b_rail_wet" if r.rail_wet() else "b_rail_r2")
	match r.pennant_mode():
		"dead":
			_sprite(c, "b_pennant_dead", PENNANT_ANCHOR - Vector2(6, 4))
		"out":
			_sprite(c, "b_pennant_out", PENNANT_ANCHOR - Vector2(226, 4))
		_:
			var k := (int(time / PENNANT_FLAP) % 2) if motion else 0
			_sprite(c, "b_pennant_flap_%d" % (k + 1), PENNANT_ANCHOR - Vector2(226, 4))
	_full(c, "b_room_r2")
	if r.ruler_shown():
		_sprite(c, "b_ruler", B_RULER_AT)
	_tab(c, LENS_TAB, "THE LENS")

# ---------------------------------------------------------------------------
# drawing: close-ups (layer 5)
# ---------------------------------------------------------------------------
func _draw_close() -> void:
	match _view():
		"c_scope":
			_draw_scope(close)
		"c_ruler":
			_draw_ruler(close)

# --- c_scope ------------------------------------------------------------------------------
func _draw_scope(c: CanvasItem) -> void:
	var st: Dictionary = r.state
	_full(c, "c_scope_r2")
	var scene := r.scope_scene()
	_sprite(c, "c_view_" + scene + ("_r2" if scene in ["station", "surface"] else ""), VIEW_AT)
	if r.patch_shown():
		_sprite_c(c, "c_loupe_ring", EYE_C, 300.0 / 380.0)
		_sprite_c(c, "c_patch", EYE_C)
		_draw_steam(c)
	if r.last_record == "nosubject":
		_draw_no_subject(c)
	# the reticle, open at the centre
	var rc := Color(INK, 0.7)
	c.draw_line(EYE_C + Vector2(-EYE_R, 0), EYE_C + Vector2(-24, 0), rc, 2.0)
	c.draw_line(EYE_C + Vector2(24, 0), EYE_C + Vector2(EYE_R, 0), rc, 2.0)
	c.draw_line(EYE_C + Vector2(0, -EYE_R), EYE_C + Vector2(0, -24), rc, 2.0)
	c.draw_line(EYE_C + Vector2(0, 24), EYE_C + Vector2(0, EYE_R), rc, 2.0)
	if r.last_record == "nosubject":
		_no_subject_marks(c)
	if st.frame_mounted and r.last_record != "nosubject":
		# her mark in the reticle: the bearing has to carry it to a subject
		_rel_mark_halo(c, EYE_C, 26, VIOLET, 3.5)
		var chip := Rect2(EYE_C + Vector2(26, 8), Vector2(74, 22))
		c.draw_rect(chip, Color(PAPER_HI, 0.88))
		c.draw_string(narrow, chip.position + Vector2(5, 17), "RELATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, VIOLET)
	_sprite(c, "c_eyepiece_ring", RING_AT)
	# the caption plate sits over the ring's top edge
	c.draw_rect(CAPTION, ENAMEL)
	c.draw_rect(CAPTION, INK, false, 2.0)
	_rtext(c, "BEARING: " + R09Sim.APERTURES[clampi(int(st.aperture), 1, 3)], CAPTION, 26, INK)
	# the selector
	for k in 3:
		_rtext(c, R09Sim.APERTURES[k + 1], SEL_PLATES[k], 20, INK)
	_draw_lever(c)
	# the clamp and her frame
	if frame_in_clamp():
		_draw_frame(c, FRAME_AT, 1.0)
	elif eject_t >= 0.0 and motion:
		var k := smoothstep(0.0, 1.0, eject_t / FRAME_EJECT)
		_draw_frame(c, FRAME_AT - Vector2(0, 140.0 * k), 1.0 - k)
	# the key
	var down := key_t > 0.0
	_sprite(c, "c_key_down" if down else "c_key_up", KEY_AT)
	_ctext(c, "RECORD BEARING", KEY_AT.x + 140, KEY_AT.y + (60.0 if down else 42.0), 24, INK)
	_draw_strip(c)
	_para(c, R09Sim.DIAGRAM_TEXT, REF_TEXT.position + Vector2(14, 30), 20, INK, REF_TEXT.size.x - 28)

## The selector lever: from its boss on the tube down to the knob in the quadrant's slot.
func _draw_lever(c: CanvasItem) -> void:
	var kp := knob_pos()
	var d := (kp - QUAD_PIVOT).normalized()
	c.draw_line(QUAD_PIVOT, kp - d * 20.0, INK, 17.0)
	c.draw_line(QUAD_PIVOT, kp - d * 20.0, Color("9c7e46"), 11.0)
	c.draw_line(QUAD_PIVOT + d.orthogonal() * 3.0, kp - d * 22.0 + d.orthogonal() * 3.0, Color("c9a869"), 2.0)
	c.draw_circle(QUAD_PIVOT, 9.0, INK)
	c.draw_circle(QUAD_PIVOT, 6.5, Color("c9a869"))
	_sprite_c(c, "c_sel_knob", kp)

func _draw_steam(c: CanvasItem) -> void:
	var base := EYE_C + Vector2(-60, -140 - 120)
	if not motion:
		_sprite(c, "c_steam", base - Vector2(0, STEAM_RISE / 2.0))
		return
	var k := fmod(time, STEAM_LOOP) / STEAM_LOOP
	_sprite(c, "c_steam", base - Vector2(0, STEAM_RISE * k), sin(PI * k))

## The land stays in view (a light wash, about 60% through); the mark and arrow ride on halos.
func _draw_no_subject(c: CanvasItem) -> void:
	c.draw_circle(EYE_C, EYE_R, Color(PAPER_HI, 0.4))
	var y := EYE_C.y - 30
	_rel_mark_halo(c, Vector2(EYE_C.x - 210, y), 32, VIOLET, 4.0)
	var lab := Rect2(EYE_C.x - 256, y + 26, 92, 24)
	c.draw_rect(lab, Color(PAPER_HI, 0.88))
	_ctext(c, "RELATION", EYE_C.x - 210, y + 44, 18, INK)
	_arrow(c, Vector2(EYE_C.x - 170, y), Vector2(EYE_C.x - 60, y), Color(PAPER_HI, 0.9), 7.0)
	_arrow(c, Vector2(EYE_C.x - 170, y), Vector2(EYE_C.x - 60, y), INK, 3.0)

## Drawn over the reticle, so its lines never seem to sit inside the empty bracket.
func _no_subject_marks(c: CanvasItem) -> void:
	var y := EYE_C.y - 30
	c.draw_rect(Rect2(EYE_C.x - 46, y - 34, 132, 64), PAPER_HI)
	_ctext(c, "[      ]", EYE_C.x + 20, y + 14, 40, INK)
	# the ink stamp, struck a little askew over the land
	var cap := Rect2(-206, -30, 412, 60)
	c.draw_set_transform(EYE_C + Vector2(0, 92), deg_to_rad(-4.0))
	c.draw_rect(cap, Color(PAPER_HI, 0.82))
	c.draw_rect(cap, INK, false, 4.0)
	c.draw_rect(cap.grow(-7), INK, false, 1.6)
	_rtext(c, "NO SUBJECT ON BEARING", cap, 30, INK)
	c.draw_set_transform(Vector2.ZERO, 0.0)

## Nora's frame face-on: her breath trace, the name tab, the relation strip and the label.
func _draw_frame(c: CanvasItem, at: Vector2, a: float) -> void:
	var ink := Color(INK, a)
	_sprite(c, "c_frame_mounted", at, a)
	for k in 3:
		var x0 := at.x + 16 + k * 125 + 10
		var x1 := x0 + 98
		var y_base := at.y + 140
		var y_top := at.y + 50
		var pts := PackedVector2Array()
		for q in SHAPES[R07Sim.SOLUTION_SLOTS[k]]:
			pts.append(Vector2(lerpf(x0, x1, q.x), lerpf(y_base, y_top, q.y)))
		c.draw_polyline(pts, ink, 3.0, true)
	var name := "BELL, N."
	c.draw_rect(Rect2(at + Vector2(20, 200), Vector2(112, 54)), Color(PAPER_HI, a))
	c.draw_rect(Rect2(at + Vector2(20, 200), Vector2(112, 54)), Color(INK, 0.6 * a), false, 1.5)
	if a >= 1.0:
		Ink.handwriting(c, name, name.length(), at + Vector2(24, 238), 22, 7, false, Ink.BLUE_INK)
	else:
		c.draw_string(narrow, at + Vector2(24, 238), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Ink.BLUE_INK, a))
	_rel_mark(c, at + Vector2(176, 233), 16, Color(VIOLET, a), 3.0)
	c.draw_string(narrow, at + Vector2(190, 240), "RELATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	_ctext(c, "CATEGORY:", at.x + 329, at.y + 220, 15, ink)
	_ctext(c, "BODY", at.x + 329, at.y + 242, 18, ink)

func _draw_strip(c: CanvasItem) -> void:
	var k := strip_k()
	if k < 0.0:
		return
	var t := _tex("c_strip")
	if t == null:
		return
	var full := t.get_size()
	var w := minf(full.x, STRIP_X1 - STRIP_X0) * k   # the torn edge runs x 950 -> 1250
	if w < 1.0:
		return
	# the leading (torn) edge comes out of the slit first; drawn a little taller than its
	# sprite so the three printed lines fit
	var h := STRIP_H
	var src := Rect2(full.x - w, 0, w, full.y)
	c.draw_texture_rect_region(t, Rect2(Vector2(STRIP_X0, STRIP_Y), Vector2(w, h)), src)
	if k < 1.0:
		return
	var x := STRIP_X0 + 12
	c.draw_string(narrow, Vector2(x, STRIP_Y + 44), R09Sim.STRIP_LINES[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
	c.draw_string(narrow, Vector2(x, STRIP_Y + 64), R09Sim.STRIP_LINES[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
	_rel_mark(c, Vector2(x + 7, STRIP_Y + 78), 14, VIOLET, 2.2)
	c.draw_string(narrow, Vector2(x + 20, STRIP_Y + 84), R09Sim.STRIP_LINES[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)

# --- c_ruler ------------------------------------------------------------------------------
func _draw_ruler(c: CanvasItem) -> void:
	_full(c, "c_ruler_r2")
	for i in 13:
		_ctext(c, str(i), 140 + i * 96, 404, 24, INK, Ink.serif())
	# the thumb-screws' tags (painted blank)
	_rtext(c, "BACK OUT", Rect2(1008, 796, 144, 26), 21, INK)
	_rtext(c, "CLOSER", Rect2(1188, 796, 144, 26), 21, INK)
	_draw_magnifier(c)
	_sprite_c(c, "c_loupe_ring", MAG_C)

## A tiny deterministic wobble for tick `i` at zoom `z` (never randf: the same every frame).
static func _jit(z: int, i: int, salt: int) -> float:
	var h := absi(hash(Vector3i(z, i, salt)))
	return float(h % 1000) / 1000.0 - 0.5

func _draw_magnifier(c: CanvasItem) -> void:
	var z := r.ruler_zoom
	var sever := _sever()
	c.draw_circle(MAG_C, MAG_R, BOXWOOD)
	var edge := MAG_C.y - 70.0          # the rule's top edge, magnified
	var half := MAG_R - 8.0
	# wood grain
	for k in 9:
		var gy := edge + 18 + k * 24
		var dx := sqrt(maxf(0.0, MAG_R * MAG_R - pow(gy - MAG_C.y, 2))) - 6
		var pts := PackedVector2Array()
		for i in 13:
			var x := lerpf(MAG_C.x - dx, MAG_C.x + dx, i / 12.0)
			pts.append(Vector2(x, gy + 2.5 * sin(i * 0.9 + k * 1.7)))
		c.draw_polyline(pts, Color(BOXWOOD_DK, 0.8), 1.5, true)
	var tdx := sqrt(maxf(0.0, MAG_R * MAG_R - pow(edge - MAG_C.y, 2)))
	# above the rule's edge: the sill, darker
	var cap := PackedVector2Array()
	for k in 49:
		var q := MAG_C + Vector2.from_angle(PI + PI * k / 48.0) * MAG_R
		cap.append(Vector2(q.x, minf(q.y, edge)))
	c.draw_colored_polygon(cap, Color("675d51"))
	c.draw_line(Vector2(MAG_C.x - tdx, edge), Vector2(MAG_C.x + tdx, edge), INK, 3.0)
	if z <= 0:
		# x1: the rule as it lies, eighths 12 px apart, an inch mark at the centre
		var ticks := PackedVector2Array()
		for i in range(-14, 15):
			var x := MAG_C.x + i * 12.0
			if absf(x - MAG_C.x) > half:
				continue
			var hh := 64.0 if i % 8 == 0 else 46.0 if i % 4 == 0 else 33.0 if i % 2 == 0 else 23.0
			ticks.append(Vector2(x, edge))
			ticks.append(Vector2(x, edge + hh))
		c.draw_multiline(ticks, INK, 2.2)
		_zoom_tag(c, ZOOM_WORD[0])
		return
	if sever:
		# eighths only: three marks, ten times apart, and the grain
		for i in 3:
			var x := MAG_C.x + (i - 1) * 120.0
			c.draw_line(Vector2(x, edge), Vector2(x, edge + 130), INK, 3.0)
		_zoom_tag(c, ZOOM_WORD[1])
		return
	var lines := PackedVector2Array()
	var n := 11
	for i in n:
		var x := MAG_C.x + (i - (n - 1) / 2.0) * ZOOM_PITCH + _jit(z, i, 1) * 1.6
		if absf(x - MAG_C.x) > half:
			continue
		lines.append(Vector2(x, edge))
		lines.append(Vector2(x + _jit(z, i, 2) * 2.0, edge + 140 + _jit(z, i, 3) * 6.0))
	if z >= 2:
		for i in n - 1:
			for j in range(1, 10):
				var x := MAG_C.x + (i - (n - 1) / 2.0 + j / 10.0) * ZOOM_PITCH + _jit(z, i * 10 + j, 4) * 0.8
				lines.append(Vector2(x, edge))
				lines.append(Vector2(x, edge + 48 + _jit(z, i * 10 + j, 5) * 6.0))
	c.draw_multiline(lines, INK, 2.0 if z == 1 else 1.4)
	if z >= 3:
		var fine := PackedVector2Array()
		for i in (n - 1) * 10:
			for j in range(1, 5):
				var x := MAG_C.x + ((i + j / 5.0) / 10.0 - (n - 1) / 2.0) * ZOOM_PITCH + _jit(z, i * 5 + j, 6) * 0.4
				fine.append(Vector2(x, edge))
				fine.append(Vector2(x, edge + 20 + _jit(z, i * 5 + j, 7) * 4.0))
		c.draw_multiline(fine, Color(INK, 0.8), 1.0)
	_zoom_tag(c, ZOOM_WORD[clampi(z, 0, 3)])

func _zoom_tag(c: CanvasItem, s: String) -> void:
	var tag := Rect2(MAG_C.x + 150, MAG_C.y + 130, 110, 48)
	c.draw_rect(tag, ENAMEL)
	c.draw_rect(tag, INK, false, 2.0)
	_rtext(c, s, tag, 30, INK)
