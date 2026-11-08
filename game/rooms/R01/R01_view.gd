extends RoomView
## R01, the Jetty: the painted room view. Plays R01Sim's state and events and stores no
## story state. Every frame the layer stack is rebuilt from sim.jetty_state() (which folds
## in the weather band and the ending), so weather is never stored here and a revisit or a
## load shows the latest state at once. Everything timed (the arrival hold, the withdrawal,
## the capsule rise, the gangway cut, the figure fade) is presentation and is never saved.
##
## Plates come from tools/art/rooms/R01.py (assets/rooms/R01/*.png, full-canvas, registered
## at the origin); loops and one-shots from tools/audio/rooms/R01.py (assets/audio/R01/).

## [id, rect, label]; first match wins. Every hotspot answers in every state and never moves.
const HOTSPOTS := [
	["gangway", Rect2(750, 600, 130, 200), "Gangway"],
	["line", Rect2(1290, 680, 64, 240), "Mooring line"],
	["bell", Rect2(620, 590, 130, 290), "Mooring bell"],
	["panel", Rect2(280, 580, 140, 190), "Mooring panel"],
	["launch", Rect2(880, 510, 410, 360), "Boat"],
	["stump", Rect2(1356, 790, 80, 120), "Past the jetty's end"],
	["station", Rect2(60, 300, 180, 150), "Office window"],
	["roof_light", Rect2(110, 150, 120, 140), "Over the roof"],
	["lighthouse", Rect2(1150, 300, 120, 150), "Lighthouse"],
	["causeway", Rect2(430, 440, 610, 70), "Causeway"],
	["pilings", Rect2(450, 860, 880, 64), "Pilings"],
]
## Under the painted outer door; no hotspot overlaps it.
const EXIT_RECTS := {
	"R02": Rect2(100, 922, 250, 64),
}

const SFX_DB := {"station_bell_1": -8.0, "station_bell_2": -8.0, "station_bell_2_dead": -6.0,
	"station_bell_3": -8.0, "station_bell_4": -8.0, "bell_low": -6.0, "pen_near": -14.0,
	"tally_flip": -8.0, "tally_reset": -8.0, "bell_pull": -9.0, "lens_click": -10.0,
	"gangway_step": -7.0, "door_shed": -7.0, "water_close": -8.0, "capsule_rise": -8.0,
	"capsule_knock": -6.0, "cap_unscrew": -9.0, "key_take": -9.0, "note_unfold": -10.0}
const SFX_SOFT := ["tally_reset", "door_shed", "capsule_knock", "bell_low", "station_bell_1",
	"station_bell_2", "station_bell_2_dead", "station_bell_3", "station_bell_4"]
const SFX_SOFT_CUT := {"station_bell_1": 6.0, "station_bell_2": 6.0, "station_bell_2_dead": 6.0,
	"station_bell_3": 6.0, "station_bell_4": 6.0}

const LOOPS := ["sea_jetty", "sea_slap", "sea_thin", "wind_jetty", "wind_whistle", "rain_planks",
	"pressure_hum", "gulls", "engine_idle"]
## Loop targets (linear) per jetty state.
const MIX := {
	"arrival": {"sea_jetty": 1.0, "wind_jetty": 0.6},
	"boat": {"sea_jetty": 1.0, "wind_jetty": 0.6},
	## The sea is out past the causeway: only its thin far edge, and the wind.
	"s1": {"sea_thin": 0.6, "wind_jetty": 0.7, "wind_whistle": 0.5},
	"s2": {"sea_jetty": 0.9, "wind_jetty": 0.7, "wind_whistle": 0.5, "rain_planks": 0.8},
	"s3": {"sea_slap": 1.0, "wind_jetty": 0.7, "wind_whistle": 0.45, "rain_planks": 0.92},
	"s4": {"sea_thin": 0.7, "wind_jetty": 0.5, "wind_whistle": 0.3, "rain_planks": 0.7},
	## s5 (Tide VII) thins out by instrument, not by level: from Tide IV no bed sits more than
	## 3 dB under the opening rooms' (core_test test_bed_loudness).
	## The hanging rain at 5 and 6 is silent ("silent_rain"): no rain_planks. Wind, and the
	## pressure hum coming up under it toward s7.
	"s5": {"sea_thin": 1.0, "wind_whistle": 0.6, "wind_jetty": 0.5, "pressure_hum": 0.15},
	"s6": {"sea_thin": 1.0, "wind_whistle": 0.6, "pressure_hum": 0.25},
	## The hum alone is all sub-bass: laptop speakers would play nothing. A thin sea under it.
	"s7": {"pressure_hum": 0.35, "sea_thin": 0.2},
	"A": {"sea_jetty": 1.0, "gulls": 0.7, "engine_idle": 0.6, "wind_jetty": 0.4},
}
## Arrival and boat while the sea is out (drained()): only its thin far edge, and the wind.
const MIX_DRAINED := {"sea_thin": 0.6, "wind_jetty": 0.6}
const CLOSEUP_MIX := 0.7

## The first visit is dusk (back_b0_dusk): a flat banded overcast, the lighthouse dark.
## Bands 1-2 are darker than that, not friendlier: storm-navy matte overcast, the lighthouse
## unlit. From Tide II until P09 (arrival in Tide II, the boat, band 1) the drained plate
## (DRAINED) replaces these; back_b1_mud is only band 1's fallback. Band 2 is the sea back,
## high and rain-pocked (with high_water).
const BACKDROP := {"arrival": "back_b0_dusk", "boat": "back_b0_dusk", "s1": "back_b1_mud", "s2": "back_b2_high",
	"s3": "back_b3", "s4": "back_b4", "s5": "back_b5", "s6": "back_b5", "s7": "back_b7",
	"A": "back_end_a"}
## Foreground modulate (fg_jetty, gangway, boat, line, capsule). Never below 0.85: every
## painted change must read at 1024x768, so there is no CanvasModulate and no vignette.
const FG_MOD := {"arrival": 0.9, "boat": 0.9, "s1": 0.96, "s2": 0.93, "s3": 0.90, "s4": 0.90,
	"s5": 0.88, "s6": 0.88, "s7": 1.0, "A": 1.0}
## Hotspot props laid as their own layers (line, gangway, boat, capsule) sit +10% in value
## over the dusk foreground so they still read; capped at 1.0.
const PROP_LIFT := 1.1
## Band 4: the sea (backdrop and wave frames) is turned this far about the jetty's end; the
## jetty, the causeway and the bell's calm (b4_level) stay level. The same in both motion modes.
const TILT_PIVOT := Vector2(1330, 870)
const TILT_DEG := 3.0
## Bands 5-6: the rain makes no sound, and it doesn't fall either. Static dashes hang in the
## air, seeded per band; thinned over the hotspots so every one stays legible.
const RAIN_HANG_COL := Color("c9d3da")
const RAIN_HANG_ALPHA := 0.7
const RAIN_HANG_N := 900
const RAIN_HANG_W := 1.5

# --- motion -------------------------------------------------------------------------
const WAVE_STEP := 0.5           # waves_0..2, one frame per half second
const RAIN_FAST := 0.25          # s1-s2
const RAIN_SLOW := 1.2           # s3-s6: the rain hangs slower than the waves move
const REFLECT_AMP := 6.0
const REFLECT_PERIOD := 1.6
const SOUND_LAG := 0.45          # the chop leads the slap; the reflections lag the chop
## Heavy rain is a veil, not a wall: the art under it must still read at 1024x768. At s4
## it thins further so the slanted horizon reads first.
const RAIN_HEAVY_ALPHA := 0.7
const RAIN_S4_ALPHA := 0.4
const DRIFT_CENTRE := 900.0
const DRIFT_SPAN := 300.0
const DRIFT_CYCLE := 40.0

# --- fx timings (seconds) -------------------------------------------------------------
const NOTICE_HOLD := 1.5
## What still plays during the arrival hold: everything else holds its still frame.
const NOTICE_PLAYS := {"arrival": ["waves"], "boat": ["waves"], "s3": ["waves", "reflections"],
	"s5": ["rain"], "s7": ["drift"]}
const HUSH_FROM := 0.15
const HUSH_TO := 2.6
const HUSH_RATE := 6.0
const RESTORE_RATE := 0.4
const BOAT_GO := 5.0
const BOAT_TRAVEL := 6.0
## The withdrawal: stern first, bow still toward the station, shrinking toward the horizon
## until it is the arrival launch's dot past the lighthouse. The stern's waterline corner is
## the anchor; it travels from the mooring to the dot while the boat scales down about it.
const BOAT_STERN := Vector2(1290, 870)
const BOAT_END := Vector2(1352, 470)
const BOAT_END_SCALE := 0.12
const BOAT_STILL_SCALE := 0.4
const BOAT_STILL_GONE := 8.0
## The TIDE III card waits for the capsule's knock instead of landing on "Bell two".
const TIDE_CARD_AT := 15.6
const RISE_AT := 11.5
const RISE_TIME := 3.0
const RISE_DY := 120.0
const WATERLINE := 870.0
const WITHDRAW_END := 15.0
const LOOP_CUT := 2.6
const FIGURE_FADE := 0.8
const PULL_TIME := 0.4
## Tide II until P09 (R01Sim.drained()): the sea is out. One plate stands in for the sea,
## its marks and the bell's calm: mud to the horizon, bare dripping pilings, the bell's
## standing cylinder of water. The boat (its own layer) rests level over untouched mud.
const DRAINED := "jetty_drained_r3"
## Plates that live outside assets/rooms/R01/.
const STAGE_PLATES := {"p06_flats": "res://assets/stages/R01/p06_flats.png",
	"jetty_drained_r3": "res://assets/stages/R01/jetty_drained_r3.png"}

# --- close-up controls ------------------------------------------------------------------
const PANEL_RECTS := {
	"tally_verified": Rect2(324, 240, 360, 250),
	"tally_unverified": Rect2(764, 240, 360, 250),
	"placard": Rect2(324, 520, 800, 210),
}
const PEER_RECT := Rect2(404, 280, 640, 400)
## First match wins. Closed, the screw cap is the drum on the capsule's mouth; once it is off
## it hangs on its chain at the right, so the cap's rect shrinks to that cup and the rolled
## note (standing where the drum was) is checked first.
const CAPSULE_RECTS := {
	"cap": Rect2(592, 230, 264, 100),
	"key": Rect2(586, 160, 134, 140),
	"note": Rect2(728, 160, 96, 140),
}
const CAPSULE_RECTS_OPEN := {
	"note": Rect2(728, 160, 96, 140),
	"key": Rect2(586, 160, 134, 140),
	"cap": Rect2(866, 400, 120, 140),
}
const HEADER_RECT := Rect2(300, 140, 848, 64)
const TALLY_LABEL_RECTS := {"verified": Rect2(344, 420, 320, 50), "unverified": Rect2(784, 420, 320, 50)}
const PLACARD_RECT := Rect2(344, 536, 760, 150)
## The placard sets 19 px on 20 px leading from 18 px down: seven printed rows (rule 3 wraps; see
## placard_rows()) above the pencil; the Board's line sits right, clear of the rising pencil.
const PLACARD_SIZE := 19
const PLACARD_LEADING := 20
const PLACARD_TOP := 18
const PENCIL_AT := Vector2(360, 694)
const ADA_AT := Vector2(380, 718)
const KEY_TAG_AT := Vector2(624, 250)   # the paper tag on the key (a little tilted)
const NOTE_PAPER := Rect2(424, 300, 600, 360)
const PENCIL_COL := Color("3d4148")
## Ada's line under Venn's: graphite too, a shade darker, a size heavier, more upright.
const ADA_PENCIL := Color("2e3238")
const VENN_SKEW := 0.08
const ADA_SKEW := -0.04

var jetty: R01Sim:
	get:
		return sim as R01Sim

var textures := {}
var narrow: SystemFont
var bold: SystemFont
var close: Node2D
var pencil_line: Node2D        # Venn's pencil, at -2 degrees
var ada_line: Node2D           # the second hand under it
var mixer: LoopMixer

var notice_t := INF            # seconds into the arrival hold
var notice_state := ""
var withdraw_t := INF          # seconds since the commit click
var loop_t := INF              # seconds into the gangway cut
var figure_k := 1.0            # 0..1 fade of the figure in the boat's window
var note_open := false
var pull_t := INF              # seconds since a bell pull
var pull_n := 1
var tide_defer := 0            # a tide card held back during the withdrawal
var rain_hang := {}            # band -> PackedVector2Array of dash end pairs (seeded)

func _ready() -> void:
	narrow = SystemFont.new()
	narrow.font_names = PackedStringArray(["Liberation Sans Narrow", "Nimbus Sans Narrow",
		"DejaVu Sans Condensed", "sans-serif"])
	narrow.font_weight = 700
	bold = SystemFont.new()
	bold.font_names = PackedStringArray(["Noto Serif", "DejaVu Serif", "Liberation Serif", "serif"])
	bold.font_weight = 700
	_build_nodes()
	_build_audio()
	apply_instantly()

func _build_nodes() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	close = Node2D.new()
	close.name = "Close"
	layer.add_child(close)
	close.draw.connect(_draw_close)
	pencil_line = Node2D.new()
	pencil_line.position = PENCIL_AT
	pencil_line.rotation = deg_to_rad(-2.0)
	close.add_child(pencil_line)
	pencil_line.draw.connect(_draw_pencil)
	ada_line = Node2D.new()
	ada_line.position = ADA_AT
	ada_line.rotation = deg_to_rad(-1.0)
	close.add_child(ada_line)
	ada_line.draw.connect(_draw_ada)

func _build_audio() -> void:
	mixer = LoopMixer.new()
	add_child(mixer)
	for id in LOOPS:
		mixer.add_loop(id, game.load_audio(id) if game else null)

func _tex(id: String) -> Texture2D:
	if not textures.has(id):
		var path: String = STAGE_PLATES.get(id, "res://assets/rooms/R01/%s.png" % id)
		textures[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return textures[id]

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func tick(dt: float) -> void:
	notice_t += dt
	withdraw_t += dt
	loop_t += dt
	pull_t += dt
	if figure_k < 1.0:
		figure_k = minf(1.0, figure_k + dt / FIGURE_FADE)
	if tide_defer > 0 and withdraw_t >= TIDE_CARD_AT:
		_release_tide_card()
	if holding() and game and notice_state in R01Sim.NOTICE and game.cur_text == R01Sim.NOTICE[notice_state]:
		notice_t = INF   # the noticed line went up (its time, or a click advanced it)
	_tick_audio(dt)
	queue_redraw()
	close.queue_redraw()
	pencil_line.queue_redraw()
	ada_line.queue_redraw()

func holding() -> bool:
	return notice_t < NOTICE_HOLD

func withdrawing() -> bool:
	return withdraw_t < WITHDRAW_END

func cutting() -> bool:
	return loop_t < LOOP_CUT

func _state() -> String:
	return jetty.jetty_state()

## The loop targets for the jetty's state now (tests read it).
func mix_for_state() -> Dictionary:
	var s := _state()
	if jetty.drained() and s in ["arrival", "boat"]:
		return MIX_DRAINED
	return MIX.get(s, {})

func _targets() -> Dictionary:
	var t: Dictionary = mix_for_state().duplicate()
	if jetty.is_closeup():
		for k in t:
			t[k] *= CLOSEUP_MIX
	return t

func _tick_audio(dt: float) -> void:
	var targets := _targets()
	var rates := {}
	if withdraw_t >= HUSH_FROM and withdraw_t < HUSH_TO:
		targets = {}
		for id in LOOPS:
			rates[id] = HUSH_RATE
	elif withdraw_t >= HUSH_TO and withdrawing():
		for id in LOOPS:
			rates[id] = RESTORE_RATE
	mixer.tick(targets, rates, dt)

## True when this kind of motion runs now (Motion & flicker on, and not held by the
## arrival hold unless it is the noticed thing).
func _plays(kind: String) -> bool:
	if not motion:
		return false
	if holding():
		return kind in NOTICE_PLAYS.get(notice_state, [])
	return true

## The wave clock: scene time, or at s3 the slap loop's position plus the lead, so the
## chop leads the sound.
func _wave_clock(s: String) -> float:
	if s == "s3" and mixer.players.has("sea_slap"):
		var p: AudioStreamPlayer = mixer.players["sea_slap"]
		if p.playing:
			return p.get_playback_position() + SOUND_LAG
	return time

func wave_frame(s: String) -> int:
	if not _plays("waves"):
		return 0
	return int(floor(_wave_clock(s) / WAVE_STEP)) % 3

func rain_frame(s: String) -> int:
	if not _plays("rain") or R01Sim.rank(s) >= 5:
		return 0   # still, or hanging: from band 5 the rain no longer falls
	var step := RAIN_FAST if R01Sim.rank(s) <= 2 else RAIN_SLOW
	return int(floor(time / step)) % 2

func reflection_dx(s: String) -> float:
	var r := R01Sim.rank(s)
	if s == "A" or r < 3 or r > 4:
		return 0.0
	if not _plays("reflections"):
		return REFLECT_AMP   # still: visibly displaced
	return REFLECT_AMP * sin(TAU * (_wave_clock(s) - SOUND_LAG) / REFLECT_PERIOD)

## The hanging rain's dashes for a band: deterministic, the same on every visit.
func rain_hang_dashes(band: int) -> PackedVector2Array:
	if rain_hang.has(band):
		return rain_hang[band]
	var g := RandomNumberGenerator.new()
	g.seed = 0x52A10 + band
	var pts := PackedVector2Array()
	for i in RAIN_HANG_N:
		var x := g.randf_range(0.0, SIZE.x)
		var y := g.randf_range(90.0, 980.0)
		var ln := g.randf_range(8.0, 14.0)
		var thin := g.randf() < 0.6
		var over := false
		for h in HOTSPOTS:
			if (h[1] as Rect2).has_point(Vector2(x, y)):
				over = true
				break
		if over and thin:
			continue
		pts.append(Vector2(x, y))
		pts.append(Vector2(x, y + ln))
	rain_hang[band] = pts
	return pts

func drift_dx() -> float:
	if not _plays("drift"):
		return 0.0
	var half := DRIFT_CYCLE / 2.0
	return -DRIFT_SPAN + 2.0 * DRIFT_SPAN * pingpong(time, half) / half

## The boat layers' placement: [offset, scale], or [] when they are not drawn. Moored it is
## [(0, 0), 1]; withdrawing it shrinks about the stern toward the horizon dot.
func boat_xform(s: String) -> Array:
	if withdrawing():
		if withdraw_t < BOAT_GO:
			return [Vector2.ZERO, 1.0]
		if not motion:
			return _boat_at(BOAT_STILL_SCALE) if withdraw_t < BOAT_STILL_GONE else []
		var k := (withdraw_t - BOAT_GO) / BOAT_TRAVEL
		if k >= 1.0:
			return []
		# Ease-in on distance, perspective on size: it backs off slowly, then goes.
		var e := k * k
		return _boat_at(1.0 / (1.0 + e * (1.0 / BOAT_END_SCALE - 1.0)))
	return [Vector2.ZERO, 1.0] if s == "boat" else []

func _boat_at(scale: float) -> Array:
	var u := clampf((1.0 - scale) / (1.0 - BOAT_END_SCALE), 0.0, 1.0)
	var anchor := BOAT_STERN.lerp(BOAT_END, u)
	return [anchor - BOAT_STERN * scale, scale]

## The boat's fade at the very end of its travel (it ends as the dot, then is gone).
func boat_alpha() -> float:
	if not withdrawing() or withdraw_t < BOAT_GO or not motion:
		return 1.0
	var k := (withdraw_t - BOAT_GO) / BOAT_TRAVEL
	return clampf((1.0 - k) / 0.12, 0.0, 1.0)

## The capsule close-up's control rects for the current state, in match order.
func capsule_rects() -> Dictionary:
	return CAPSULE_RECTS_OPEN if jetty.state.capsule_opened else CAPSULE_RECTS

## The capsule's y offset while it rises, 0 at rest, -1 hidden.
func capsule_dy() -> float:
	if jetty.capsule_state() == "none":
		return -1.0
	if not withdrawing():
		return 0.0
	if withdraw_t < RISE_AT:
		return -1.0
	if not motion:
		return 0.0
	var k := clampf((withdraw_t - RISE_AT) / RISE_TIME, 0.0, 1.0)
	return RISE_DY * (1.0 - (1.0 - (1.0 - k) * (1.0 - k)))   # ease-out into the cleat

## The ordered layer list for this frame: [[texture id, offset, modulate, clip_y], ...].
## Tests and the dev overlay read it; _draw draws it.
func layer_stack() -> Array:
	var s := _state()
	var r := R01Sim.rank(s)
	var early := s in ["arrival", "boat"]
	var mid := not early and s != "A"
	var m: float = FG_MOD.get(s, 1.0)
	var fg := Color(m, m, m)
	var pm := minf(1.0, m * PROP_LIFT) if early else m
	var prop := Color(pm, pm, pm)
	var out := []
	# Tide II until P09 the sea is out: the drained plate, and no sea marks over it.
	var dry := jetty.drained()
	out.append([DRAINED if dry else BACKDROP[s], Vector2.ZERO, Color.WHITE, -1.0])
	if dry or s == "s1":
		pass
	elif early:
		# Every piling has its reflection; the boat, laid over them, has none.
		out.append(["reflections_dusk", Vector2.ZERO, Color.WHITE, -1.0])
	elif s == "s2":
		# The storm sea's own dark-toned marks (the bright band-0 ones would lift it).
		out.append(["reflections_dusk", Vector2.ZERO, Color.WHITE, -1.0])
	elif mid and r <= 4:
		var rdx := Vector2(reflection_dx(s), 0)
		out.append(["reflections", rdx, Color.WHITE, -1.0])
		if r >= 3:
			# Laid twice when they lag: under the rain the faint plate alone doesn't read.
			out.append(["reflections", rdx, Color.WHITE, -1.0])
	if dry or s == "s1":
		pass
	elif early or s == "s2":
		out.append(["waves_dusk_%d" % wave_frame(s), Vector2.ZERO, Color.WHITE, -1.0])
	elif mid and r <= 6:
		var a := 1.0 if r <= 2 else (0.8 if r <= 4 else 0.5)
		if s == "s4":
			out.append(["waves_%d" % wave_frame(s), Vector2.ZERO, Color(1, 1, 1, a), -1.0, 1.0,
				deg_to_rad(TILT_DEG)])
			out.append(["b4_level", Vector2.ZERO, Color.WHITE, -1.0])
		else:
			out.append(["waves_%d" % wave_frame(s), Vector2.ZERO, Color(1, 1, 1, a), -1.0])
	if s != "s7" and s != "A" and not dry:
		out.append(["bell_calm", Vector2.ZERO, Color.WHITE, -1.0])
	if not gsim().flag("P05"):
		out.append(["launch_departing", Vector2.ZERO, Color.WHITE, -1.0])
	if s == "s6":
		out.append(["lighthouse_roof", Vector2.ZERO, Color.WHITE, -1.0])
	if s == "s7":
		out.append(["surface_drift", Vector2(drift_dx(), 0), Color.WHITE, -1.0])
	# Once it pulls away it is further off than the jetty: it goes behind the deck and pilings.
	var receding := withdrawing() and withdraw_t >= BOAT_GO
	if receding:
		_boat_layers(out, s, prop)
	out.append(["fg_jetty", Vector2.ZERO, fg, -1.0])
	# After Tide I a tenth piling stands past the end, whole and dry; from band 3 it's a stump.
	if r < 3 and gsim().tide_done(1):
		out.append(["tenth_piling", Vector2.ZERO, Color.WHITE, -1.0])
	if s == "s2":
		out.append(["high_water", Vector2.ZERO, Color.WHITE, -1.0])
	# The office window is painted in fg_jetty, so its lamp and figure sit just above it.
	if gsim().flag("P01") and s != "A":
		out.append(["station_lamp", Vector2.ZERO, Color.WHITE, -1.0])
	if early:
		out.append(["dusk_lamps", Vector2.ZERO, Color.WHITE, -1.0])
	if s == "s7":
		out.append(["station_window_figure", Vector2.ZERO, Color.WHITE, -1.0])
	if r >= 3:
		out.append(["stump", Vector2.ZERO, Color.WHITE, -1.0])
	var down := (s == "boat" and not cutting()) or (withdrawing() and withdraw_t < BOAT_GO)
	out.append(["gangway_down" if down else "gangway_up", Vector2.ZERO, prop, -1.0])
	if s == "A":
		out.append(["launch_real", Vector2.ZERO, fg, -1.0])
	elif not receding:
		_boat_layers(out, s, prop)
	if mid and r >= 2 and r <= 6:
		out.append(["mist_far", Vector2.ZERO, Color.WHITE, -1.0])
	out.append(["line", Vector2.ZERO, prop, -1.0])
	var dy := capsule_dy()
	if dy >= 0.0:
		var cap := "capsule_open" if jetty.capsule_state() == "open" else "capsule_closed"
		out.append([cap, Vector2(0, dy), prop, WATERLINE if dy > 0.0 else -1.0])
	if s == "s1":
		out.append(["rain_light_%d" % rain_frame(s), Vector2.ZERO, Color.WHITE, -1.0])
	elif mid and r >= 5 and r <= 6:
		out.append(["rain_hang_%d" % r, Vector2.ZERO, Color(1, 1, 1, RAIN_HANG_ALPHA), -1.0])
	elif mid and r >= 2 and r <= 4:
		var ra := RAIN_S4_ALPHA if s == "s4" else RAIN_HEAVY_ALPHA
		out.append(["rain_heavy_%d" % rain_frame(s), Vector2.ZERO, Color(1, 1, 1, ra), -1.0])
	if cutting():
		out.append(["ada_door", Vector2.ZERO, Color.WHITE, -1.0])
	return out

## The boat, its lit window and (once seen, or while it leaves) the figure: one placement.
## Entries carry a fifth field, the scale about the plate origin.
func _boat_layers(out: Array, s: String, fg: Color) -> void:
	var x := boat_xform(s)
	if x.is_empty():
		return
	var at: Vector2 = x[0]
	var sc: float = x[1]
	var a := boat_alpha()
	out.append(["boat", at, Color(fg.r, fg.g, fg.b, a), -1.0, sc])
	out.append(["boat_window_lit", at, Color(1, 1, 1, a), -1.0, sc])
	if jetty.figure_seen() or withdrawing():
		var fig := "figure_window_turned" if gsim().flag("t1x_turned") else "figure_window"
		out.append([fig, at, Color(1, 1, 1, a), -1.0, sc])

func _draw() -> void:
	for l in layer_stack():
		var id: String = l[0]
		if id.begins_with("rain_hang_"):
			var m: Color = l[2]
			draw_multiline(rain_hang_dashes(int(id.substr(10))), Color(RAIN_HANG_COL, m.a), RAIN_HANG_W, true)
			continue
		var tex := _tex(id)
		if tex == null:
			continue
		var at: Vector2 = l[1]
		var clip_y: float = l[3]
		var sc: float = l[4] if l.size() > 4 else 1.0
		var rot: float = l[5] if l.size() > 5 else 0.0
		if rot != 0.0:
			# Turned about the pivot: x -> pivot + R(x + at - pivot).
			draw_set_transform(TILT_PIVOT + (at - TILT_PIVOT).rotated(rot), rot, Vector2(sc, sc))
			draw_texture(tex, Vector2.ZERO, l[2])
			draw_set_transform(Vector2.ZERO)
		elif clip_y > 0.0:
			# Clipped at the waterline: it comes up out of the water, and the part that will
			# hang under the surface fades in as it arrives.
			var h := clip_y - at.y
			if h > 0.0:
				draw_texture_rect_region(tex, Rect2(at, Vector2(SIZE.x, h)), Rect2(0, 0, SIZE.x, h), l[2])
				var under := 1.0 - clampf(at.y / RISE_DY, 0.0, 1.0)
				var m: Color = l[2]
				draw_texture_rect_region(tex, Rect2(Vector2(at.x, clip_y), Vector2(SIZE.x, SIZE.y - h)),
					Rect2(0, h, SIZE.x, SIZE.y - h), Color(m.r, m.g, m.b, m.a * under * under))
		elif sc != 1.0:
			draw_set_transform(at, 0.0, Vector2(sc, sc))
			draw_texture(tex, Vector2.ZERO, l[2])
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture(tex, at, l[2])

# ---------------------------------------------------------------------------
# close-ups (layer 5, never modulated)
# ---------------------------------------------------------------------------
func _draw_close() -> void:
	var c := close
	match jetty.local_view:
		R01Sim.C_PANEL:
			_draw_panel(c)
		R01Sim.C_WINDOW:
			# Through the lens, the cabin is R03's chart room: recorder, plan, clipped chart.
			_blit(c, "c_boat_window_chart")
			if jetty.figure_seen():
				var fig := "c_boat_window_chart_figure_turned" if gsim().flag("t1x_turned") \
					else "c_boat_window_chart_figure"
				_blit(c, fig, Vector2.ZERO, Color(1, 1, 1, figure_k))
		R01Sim.C_CAPSULE:
			_draw_capsule(c)

func _blit(c: CanvasItem, id: String, at := Vector2.ZERO, mod := Color.WHITE) -> void:
	var tex := _tex(id)
	if tex:
		c.draw_texture(tex, at, mod)

func _centred(c: CanvasItem, s: String, r: Rect2, size: int, col: Color, font: Font) -> void:
	Ink.text(c, s, Vector2(r.position.x, r.position.y + r.size.y / 2.0 + size * 0.36), size, col, font, r.size.x)

func _draw_panel(c: CanvasItem) -> void:
	_blit(c, "c_mooring_panel")
	# Each bell hangs under its painted pennant (R01Sim.BELL_PENNANTS); no numbers.
	_blit(c, "c_panel_pennants")
	var t := jetty.tally()
	if t == "verified":
		_blit(c, "c_panel_tally_v")
	elif t == "unverified":
		_blit(c, "c_panel_tally_u")
	if pull_t < PULL_TIME:
		_blit(c, "c_panel_pull_down", Vector2(200 * (pull_n - 1), 0))
	_centred(c, R01Sim.PANEL_HEADER, HEADER_RECT, 30, Ink.INK, narrow)
	for k in TALLY_LABEL_RECTS:
		_centred(c, R01Sim.TALLY_LABELS[k], TALLY_LABEL_RECTS[k], 26, Ink.INK, narrow)
	if t != "":
		var plate: Rect2 = PANEL_RECTS["tally_" + t]
		_centred(c, "SET", Rect2(plate.position.x + 130, 476, 100, 30), 22, Ink.INK, narrow)
	var y := PLACARD_RECT.position.y + PLACARD_TOP
	for row in placard_rows():
		Ink.text(c, row[0], Vector2(PLACARD_RECT.position.x + row[1], y), PLACARD_SIZE, Ink.INK,
			bold if row[2] else Ink.serif(), PLACARD_RECT.size.x - row[1],
			HORIZONTAL_ALIGNMENT_RIGHT if row[3] else HORIZONTAL_ALIGNMENT_LEFT)
		y += PLACARD_LEADING

## The placard as set: [text, indent, bold, right-aligned] per printed row. A rule wider than
## the placard breaks at a word and carries on under its own text (a hanging indent past its
## number), so no rule is ever clipped; the Board's line sits right, clear of the pencil.
func placard_rows() -> Array:
	var out := []
	var lines: Array = R01Sim.PLACARD_LINES
	var font := Ink.serif()
	for i in lines.size():
		var s: String = lines[i]
		var last := i == lines.size() - 1
		if i == 0 or last or _placard_w(font, s) <= PLACARD_RECT.size.x:
			out.append([s, 0.0, i == 0, last])
			continue
		var words := s.split(" ")
		var hang := _placard_w(font, words[0] + " ")
		var line := ""
		var indent := 0.0
		for w in words:
			var trial := w if line == "" else line + " " + w
			if line != "" and _placard_w(font, trial) > PLACARD_RECT.size.x - indent:
				out.append([line, indent, false, false])
				line = w
				indent = hang
			else:
				line = trial
		out.append([line, indent, false, false])
	return out

func _placard_w(font: Font, s: String) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, PLACARD_SIZE).x

func _draw_pencil() -> void:
	if jetty == null or jetty.local_view != R01Sim.C_PANEL:
		return
	_hand(pencil_line, R01Sim.PLACARD_PENCIL, 22, 3, PENCIL_COL, VENN_SKEW, false)

func _draw_ada() -> void:
	if jetty == null or jetty.local_view != R01Sim.C_PANEL or not jetty.has_seen("placard_ada"):
		return
	_hand(ada_line, R01Sim.PLACARD_ADA, 23, 11, ADA_PENCIL, ADA_SKEW, true)

## Pencil handwriting with the font's own spacing (kerning-aware advances, so no letter
## drifts off its word), a little per-letter wobble, and `heavy` laying a second pass a
## hair to the right for a firmer hand.
func _hand(c: CanvasItem, s: String, size: int, row: int, col: Color, skew: float, heavy: bool) -> void:
	var font := Ink.hand()
	var g := RandomNumberGenerator.new()
	for i in s.length():
		if s[i] == " ":
			continue
		g.seed = 18 + row * 97 + i
		var dy := g.randf_range(-0.7, 0.7)
		var rot := g.randf_range(-0.015, 0.015)
		var x := font.get_string_size(s.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		for pass_dx in ([0.0, 0.35] if heavy else [0.0]):
			c.draw_set_transform_matrix(Transform2D(rot, Vector2.ONE, skew, Vector2(x + pass_dx, dy)))
			c.draw_char(font, Vector2.ZERO, s[i], size, col)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_capsule(c: CanvasItem) -> void:
	_blit(c, "c_capsule")
	var st: Dictionary = jetty.state
	if st.capsule_opened:
		_blit(c, "c_capsule_open")
		if not st.key_taken:
			_blit(c, "c_capsule_key")
			c.draw_set_transform(KEY_TAG_AT, deg_to_rad(-7.0))
			Ink.text(c, R01Sim.KEY_TAG, Vector2(-30, 6), 16, Ink.INK, narrow, 60)
			c.draw_set_transform(Vector2.ZERO)
		_blit(c, "c_capsule_note")
	if note_open:
		_draw_note(c)

func _draw_note(c: CanvasItem) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(Ink.INK, 0.55))
	c.draw_rect(NOTE_PAPER, Ink.PAPER)
	c.draw_rect(NOTE_PAPER, Ink.INK, false, 3.0)
	c.draw_rect(NOTE_PAPER.grow(-10), Color(Ink.INK, 0.25), false, 1.0)
	var font := Ink.hand()
	var lines := _wrap(R01Sim.NOTE_TEXT, 30, 540.0, font)
	var y := NOTE_PAPER.position.y + 110
	for i in lines.size():
		Ink.handwriting(c, lines[i], lines[i].length(), Vector2(NOTE_PAPER.position.x + 30, y), 30, 40 + i,
			false, PENCIL_COL)
		y += 46
	var sign := R01Sim.NOTE_SIGN
	var w := font.get_string_size(sign, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	Ink.handwriting(c, sign, sign.length(), NOTE_PAPER.end - Vector2(w + 50, 36), 30, 60, false, PENCIL_COL)

func _wrap(s: String, size: int, width: float, font: Font) -> Array:
	var out := []
	var line := ""
	for word in s.split(" "):
		var trial := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out

# ---------------------------------------------------------------------------
# hooks
# ---------------------------------------------------------------------------
func _release_tide_card() -> void:
	if game and is_instance_valid(game) and tide_defer > 0:
		game.tide_card_n = tide_defer
		game.tide_card_t = 0.0 if motion else 1.0
	tide_defer = 0

func _exit_tree() -> void:
	_release_tide_card()

func apply_instantly() -> void:
	_release_tide_card()
	notice_t = INF
	withdraw_t = INF
	loop_t = INF
	pull_t = INF
	figure_k = 1.0
	note_open = false
	if mixer:
		mixer.snap(_targets())
	queue_redraw()
	if close:
		close.queue_redraw()

func reset_presentation() -> void:
	apply_instantly()

func redraw() -> void:
	queue_redraw()
	if close:
		close.queue_redraw()

func play_fx(id: String, e: Dictionary) -> void:
	match id:
		"notice":
			notice_state = str(e.get("state", ""))
			notice_t = 0.0
		"withdraw":
			withdraw_t = 0.0
			loop_t = INF
			# The core has just put up the TIDE card for this commit; hold it until the knock.
			if game and game.tide_card_t < 0.5 and game.tide_card_n > 0:
				tide_defer = game.tide_card_n
				game.tide_card_t = 99.0
		"gangway_loop":
			loop_t = 0.0   # a hard cut, the same in both motion modes
		"figure":
			figure_k = 0.0 if motion else 1.0
		"note":
			note_open = true
		"cap_off":
			pass   # the capsule close-up draws c_capsule_open from the state
	redraw()

func on_sfx(id: String) -> void:
	if id != "bell_pull":
		return
	pull_t = 0.0
	# Which bell: the click's own events name it (station_bell_N or the dead bell 2).
	if game:
		for e in game.last_events:
			if e.type == "sfx" and str(e.id).begins_with("station_bell_"):
				pull_n = clampi(int(str(e.id).substr(13, 1)), 1, 4)
				return

func on_view_changed(_before: String) -> void:
	if jetty.local_view != R01Sim.C_CAPSULE:
		note_open = false

## The exits stay live through the arrival and notice holds, the withdrawal and the gangway
## cut: an exit click ends the hold and travels in the same press (the core's exits always
## act; a playing chain advances first).
func exits_active() -> bool:
	return jetty.local_view == "room"

## A click on an exit tab is never the room's: it ends the hold and goes to the core, which
## travels. Anything else is not taken here either: during the hold the noticed line is a
## queued story line, so the core's advance() brings it up and tick() ends the hold.
func consume_click(p: Vector2) -> bool:
	for r in live_exit_rects().values():
		if (r as Rect2).has_point(p):
			notice_t = INF
			return false
	return false

func hover_at(p: Vector2) -> String:
	if holding():
		return ""
	return super.hover_at(p)

func label_for(id: String) -> String:
	var s := _state()
	match id:
		"launch":
			if s == "arrival" and jetty.drained():
				return "Mud flats"
			return "Launch" if s == "A" else ("Boat" if s == "boat" else "Open water")
		"stump":
			if R01Sim.rank(s) >= 3 or gsim().tide_done(1):
				return "Tenth piling"
		"roof_light":
			if s == "s6":
				return "Lighthouse"
		"line":
			if jetty.state.p06_complete:
				return "Capsule"
	return super.label_for(id)

func action_at(p: Vector2) -> String:
	match jetty.local_view:
		"room":
			# During the arrival hold the noticed line is a queued story line, so the core
			# turns a click into advance(); tick() ends the hold when that line goes up.
			return super.action_at(p)
		R01Sim.C_PANEL:
			for k in PANEL_RECTS:
				if PANEL_RECTS[k].has_point(p):
					return k
			for n in range(1, 5):
				if _bell_rect(n).has_point(p):
					pull_n = n
					return "bell_%d" % n
		R01Sim.C_WINDOW:
			if PEER_RECT.has_point(p):
				return "peer"
		R01Sim.C_CAPSULE:
			if note_open:
				note_open = false
				return ""
			var rects := capsule_rects()
			for k in rects:
				if rects[k].has_point(p):
					return k
	return ""

func _bell_rect(n: int) -> Rect2:
	return Rect2(444 + 200 * (n - 1) - 80, 740, 160, 190)

func dev_rects() -> Array:
	match jetty.local_view:
		R01Sim.C_PANEL:
			var out: Array = PANEL_RECTS.values()
			for n in range(1, 5):
				out.append(_bell_rect(n))
			return out
		R01Sim.C_WINDOW:
			return [PEER_RECT]
		R01Sim.C_CAPSULE:
			return capsule_rects().values()
	return super.dev_rects()
