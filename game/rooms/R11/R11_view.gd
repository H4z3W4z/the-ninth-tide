extends RoomView
## R11, the Dry Stair: renders R11Sim, plays its events, owns its light and loops.
##
## Layering (inside the game's world layer):
##   this node (under the CanvasModulate): the landing in view (the sim's `landing`), its
##     overlays, the view-drawn marks (gauge, plates, placard, stencils, records) and the
##     notice frame
##   CanvasLayer 5 "close": the two close-ups, and the P12 and P24 cuts, always at full brightness
## Both landings share local_view "room"; the sim's `landing` says which one is drawn.
## Everything timed here (holds, cuts, the port, flags, motes) is presentation, never saved.

## Landing 1 (the gate landing). First match wins, so small objects precede large ones.
const HOTSPOTS := [
	["gauge", Rect2(200, 200, 200, 440), "Gate gauge"],
	["plates", Rect2(956, 530, 200, 350), "Landing plates"],
	["placard", Rect2(1170, 180, 230, 320), "Gate placard"],
	["water_plane", Rect2(548, 486, 354, 80), "Water"],
	["steps", Rect2(548, 164, 354, 160), "Steps"],
	["gate", Rect2(540, 330, 370, 550), "Pressure gate"],
]
## Landing 2 (below the gate).
const L2_HOTSPOTS := [
	["shoes", Rect2(668, 226, 252, 84), "Shoes"],
	["bell_sound", Rect2(366, 334, 220, 170), "Bell"],
	["ceiling", Rect2(96, 96, 1256, 226), "Ceiling"],
	["return_door", Rect2(60, 420, 230, 460), "Laboratory door"],
	["upper_stair", Rect2(1140, 330, 250, 550), "Stair up"],
	["lower_door", Rect2(600, 450, 510, 430), "Lower door"],
]
const LANDING_HOTSPOTS := {1: HOTSPOTS, 2: L2_HOTSPOTS}
## Moving between the landings: plaques on the HUD layer, like R03's turns.
const NAV_RECTS := {"descend": Rect2(1360, 560, 72, 200), "ascend": Rect2(16, 130, 72, 220)}
const NAV_LABELS := {"descend": "Lower landing ▾", "ascend": "◂ Gate landing"}
const NAV_NAMES := {"descend": "Lower landing", "ascend": "Gate landing"}
const NAV_ARROWS := {"descend": "▾", "ascend": "◂"}
## Where each exit is clicked. The core draws these as tabs on the HUD layer; which ones show
## depends on the landing (live_exit_rects).
const EXIT_RECTS := {
	"R03": Rect2(20, 922, 250, 64),
	"R07": Rect2(40, 922, 250, 64),
	"R09": Rect2(1150, 922, 270, 64),
	"R12": Rect2(600, 922, 300, 64),
}
const EXIT_ARROWS := {"R03": "", "R07": "left", "R09": "right", "R12": "down"}

# --- c_gate ------------------------------------------------------------------------------
const GATE_CONTROLS := [
	["gauge_face", Rect2(130, 110, 400, 380), "Gauge"],
	["wheel_down", Rect2(140, 830, 170, 90), "LESS"],
	["wheel_up", Rect2(350, 830, 170, 90), "MORE"],
	["flags", Rect2(600, 110, 420, 120), "Indicator"],
	["slot_upper", Rect2(640, 270, 300, 150), "UPPER"],
	["slot_lower", Rect2(640, 470, 300, 150), "LOWER"],
	["port", Rect2(1000, 270, 200, 200), "Sight port"],
	["plate_o1", Rect2(560, 700, 180, 150), "[ 1"],
	["plate_c1", Rect2(760, 700, 180, 150), "] 1"],
	["plate_o2", Rect2(960, 700, 180, 150), "[ 2"],
	["plate_o3", Rect2(670, 852, 180, 120), "[ 3"],
	["plate_c3", Rect2(870, 852, 180, 120), "] 3"],
	["placard_read", Rect2(1170, 500, 250, 400), "Placard"],
	["lever_open", Rect2(1230, 100, 160, 360), "OPEN"],
]
const DIAL_C := Vector2(330, 300)
const DIAL_R := 190.0
const WHEEL_C := Vector2(330, 660)
const STATUS_WIN := Rect2(259, 386, 142, 28)
const FLAG_WINS := [Rect2(612, 118, 396, 48), Rect2(612, 176, 396, 48)]
const SLOT_RECTS := [Rect2(640, 270, 300, 150), Rect2(640, 470, 300, 150)]
const SLOT_WORDS := ["UPPER", "LOWER"]
const BOUNDARY_PLATE := Rect2(842, 426, 114, 36)
const PORT_C := Vector2(1100, 370)
const PORT_R := 96.0
## The rack's hooks (their bent tips), one per plate, in R11Sim.PLATES order.
const GATE_HOOKS := {"o1": Vector2(659, 716), "c1": Vector2(859, 716), "o2": Vector2(1059, 716),
	"o3": Vector2(759, 870), "c3": Vector2(959, 870)}
## The rack's second bar (view-drawn, under the painted one), for '[ 3' and '] 3'.
const GATE_RACK2 := Rect2(686, 838, 348, 12)
const GATE_LEVER_AT := Vector2(1230, 100)
const PLACARD_IN := Rect2(1192, 524, 206, 352)
const PLATE_SIZE := Vector2(240, 140)
const PLATE_HOLE := Vector2(120, 24)
## The unnumbered gauge faces (four ticks, no reference needle) laid over the painted dials.
const C_FACE_HALF := Vector2(200, 200)
const L1_FACE_HALF := Vector2(100, 100)

# --- c_chamber_door ----------------------------------------------------------------------
const DOOR_CONTROLS := [
	["frame_body", Rect2(110, 120, 320, 240), "BODY"],
	["frame_place", Rect2(110, 390, 320, 240), "PLACE"],
	["frame_name", Rect2(110, 660, 320, 240), "NAME"],
	["socket_witness", Rect2(520, 200, 240, 240), "WITNESS"],
	["port_copy", Rect2(520, 560, 240, 240), "COPY"],
	["preview", Rect2(840, 110, 520, 130), "Preview"],
	["door_plate", Rect2(840, 300, 300, 560), "Door plate"],
	["lever_access", Rect2(1190, 300, 180, 560), "OPEN ACCESS"],
]
const DOOR_FRAMES := {"BODY": Rect2(110, 120, 320, 240), "PLACE": Rect2(110, 390, 320, 240),
	"NAME": Rect2(110, 660, 320, 240)}
const SOCKET_C := Vector2(640, 320)
const COPY_AT := Vector2(520, 560)
const COPY_STAMP := Rect2(586, 552, 108, 34)
const PREVIEW_IN := Rect2(852, 122, 496, 106)
const DOOR_PLATE_IN := Rect2(866, 330, 248, 500)
const ACCESS_AT := Vector2(1190, 300)
const REC_TEX := {"nora_frame": "rec_frame", "nora_spatial_strip": "rec_strip",
	"amended_nora_card": "rec_card_amended", "nora_register_card": "rec_card", "witness_bridge": "rec_bridge"}

# --- landing 1, room scale ---------------------------------------------------------------
const L1_DIAL := Vector2(300, 300)
const L1_DIAL_R := 88.0
const L1_HUB := Vector2(300, 530)
const L1_SLOTS := [Rect2(1006, 556, 100, 58), Rect2(1006, 644, 100, 58)]
const L1_HOOKS := {"o1": Vector2(1062, 750), "c1": Vector2(1062, 800), "o2": Vector2(1062, 850),
	"o3": Vector2(988, 775), "c3": Vector2(988, 825)}
## The second strap for '[ 3' and '] 3', off the painted bar's left bracket.
const L1_STRAP2 := Rect2(979, 746, 6, 84)
const L1_LEVER := Rect2(1124, 560, 22, 140)
const L1_PLACARD := Rect2(1184, 194, 202, 292)
const STAIR_MARKS := {"bracket": Vector2(930, 260), "linked": Vector2(930, 400), "circle": Vector2(930, 600)}
const WATER_Y := 520.0
const WATER_X := [548.0, 902.0]
## The horizontal pane (pane_slab): its band, the water_plane hotspot's, and its bright top edge.
const SLAB_BAND := Rect2(540, 480, 370, 92)
const SLAB_Y := 486.0

# --- landing 2, room scale ---------------------------------------------------------------
const L2_FRAMES := {"BODY": Rect2(925, 450, 120, 96), "PLACE": Rect2(925, 560, 120, 96),
	"NAME": Rect2(925, 670, 120, 96)}
const L2_SOCKET := Vector2(955, 815)
const L2_COPY := Rect2(1015, 785, 60, 60)
const L2_COPY_STAMP := Rect2(1021, 770, 48, 11)
const L2_LEVER := Rect2(1084, 600, 20, 180)
const L2_DOOR_PLATE := Rect2(110, 470, 130, 40)
const LATCH := Rect2(840, 640, 30, 60)
const HINGE_X := 600.0
## The frozen bell: its bearing, and the centre of its body (tipped 30 degrees toward the office;
## mirrored about the bearing when it tips toward the lower door).
const BELL_PIVOT := Vector2(456, 374)
const BELL_BODY := Vector2(415, 446)
## One thin navy ring off the bell when it first sounds (the reveal, ahead of the glance), never
## on the loop's later tolls: radius from/to over RING_TIME, fading to nothing (Motion off: a
## still ring at RING_STILL_R that fades out over RING_TIME).
const RING_TIME := 1.5
const RING_R := [70.0, 240.0]
const RING_STILL_R := 120.0

## Ambient light per weather band, per landing: never below 0.78; the dread is in what is seen.
const MODULATE_L1 := [0.92, 0.91, 0.90, 0.88, 0.86, 0.84, 0.82, 0.80]
const MODULATE_L2 := [0.9, 0.9, 0.9, 0.88, 0.86, 0.84, 0.81, 0.78]

## Notice regions.
const NOTICE_RECTS := {
	"n_arrival": Rect2(548, 486, 354, 80), "n_tide1": Rect2(0, 440, 540, 60),
	"n_tide2": Rect2(0, 380, 540, 120), "n_more_steps": Rect2(540, 160, 370, 720),
	"n_shelves": Rect2(540, 520, 370, 360), "n_tide_top": Rect2(0, 90, 1448, 60),
	"n_shoes_wet": Rect2(650, 210, 340, 120), "n_shoes_facing": Rect2(650, 210, 600, 120),
	"n_bell": Rect2(366, 334, 220, 170),
}
const HOLD_TIME := 1.5

# --- timings -----------------------------------------------------------------------------
const CUT_GATE := 1.8        # P12: the gate, lever down
const CUT_GRILLE := 5.0      # then the gateway: the bolts draw (shake), the grille rises into the lintel
const CUT_GRILLE_RISE := [2.3, 4.3]
const CUT_HAND_AT := 5.8     # then the standing water: the hand goes through it
const CUT_HAND_FADE := 1.6   # cut_hand_a -> cut_hand_b
const CUT_FADE_AT := 9.0     # fade to landing 2
const CUT_END := 9.6
## The gateway beat's framing: the L1 plate at 1.25x about the gateway.
const CUT_ZOOM := 1.25
const CUT_ZOOM_AT := Vector2(-182, -105)
const DOOR_HOLD := 4.4       # P24: the door close-up held
const DOOR_SWING := 1.6
const DOOR_DISSOLVE := 0.6
const PORT_SHOW := 3.0
const IRIS := 0.3
const LEVER_DOWN := 0.6
const FLAG_DROP := 0.15
const BELL_LOOP := 16.0
const BELL_CUE := 0.5
const MOTE_TIME := 1.4
const LATCH_TIME := 0.4
const GLINT_PERIOD := 9.0
const BELL_GLANCE_SETTLE := 0.5
const BELL_GLANCE_TIME := 2.5
const FINGER_FADE := 2.0
## P12's standing water as a slab (assets/stages/R11/p12_water_slab.png): in the cut it is there
## from the line "The water's standing up in the gateway" (2.2 s), behind the rising grille.
const SLAB_AT := 2.2
const SLAB_FADE := 0.6
const WATER_SLAB := Rect2(556, 252, 338, 628)
## Motion only: one pale band sliding down the slab's face, once per SHIMMER_PERIOD.
const SHIMMER_PERIOD := 8.0
## P24: the iron shutter over the NAME frame's glass (c_name_shutter, 300x220), dropping in
## SHUTTER_DROP s and wound up in SHUTTER_LIFT s (Motion off: at once).
const NAME_GLASS := Rect2(120, 670, 300, 220)
const SHUTTER_DROP := 0.22
const SHUTTER_LIFT := 0.45

## Late wrongness on the landings.
const SPILL_BAND := 5        # gate landing: sea-glass light up out of the water onto the floor
const FAR_MARKS_BAND := 6    # gate landing: the jamb marks again beyond the water, at the wrong heights
const TILT_BAND := 7         # gate landing: the plane tilts in the standing water
const CAUSTIC_BAND := 5      # lower landing: a slow caustic band under the glass floor
const THRESHOLD_BAND := 6    # lower landing: cold light under the lower door
const GHOST_BAND := 5        # c_gate: a second faint needle resting on 2
## Band 6+, the late wash: the wall at the glass shelf soaked from sage to storm navy, a
## sea-glass waterline stain on the shelf line, dark drip ticks off it. Lower landing:
## b6_wash (the office floor's underside down to the dado); gate landing: b6_wash_L1 (above
## the horizontal pane's line). Each is its plate repainted under its objects, so every
## contour on it stays at full ink; drawn straight over the plate, under everything else.
const WASH_BAND := 6
## Where the far-side marks stand (beyond the water, inside the gateway), in the jamb's order reversed.
const FAR_MARKS := {"circle": Vector2(588, 610), "linked": Vector2(588, 712), "bracket": Vector2(588, 820)}

## Ambient loops.
const LOOPS := ["r11_air", "r11_line_pulse", "r11_glass", "r11_bell_above", "r11_bell_below", "r11_pressure"]
const SFX_DB := {
	"r11_wheel_click": -10.0, "r11_wheel_dead": -12.0, "r11_plate_pick": -12.0, "r11_plate_set": -10.0,
	"r11_lever_pull": -8.0, "r11_lever_refuse": -9.0, "r11_flags": -10.0,
	"r11_bolts_draw": -5.0, "r11_glass_flex": -7.0, "r11_glass_pass": -13.0, "r11_bell_up": -6.0,
	"r11_port_open": -11.0, "r11_false_water": -8.0, "r11_plane_touch": -10.0,
	"r11_salt_tick": -16.0, "r11_shelf_hush": -14.0, "r11_shoe_set": -9.0,
	"r11_frame_mount": -10.0, "r11_frame_unmount": -11.0, "r11_bridge_seat": -9.0, "r11_copy_snap": -7.0,
	"r11_preview_print": -10.0, "r11_access_lever": -8.0, "r11_door_bolts": -5.0, "r11_bridge_eject": -9.0,
	"r11_door_swing": -7.0, "r11_shutter_drop": -6.0, "r11_shutter_lift": -11.0, "r11_copy_out": -9.0,
}
const SFX_SOFT := ["r11_bolts_draw", "r11_bell_up", "r11_shoe_set", "r11_copy_snap", "r11_door_bolts",
	"r11_shutter_drop"]

const PALE := Color(0.93, 0.95, 0.97)
const ENAMEL := Color8(226, 218, 196)
const GRAPHITE := Color8(78, 82, 88)
const BRASS_HI := Color("ecd29a")
const CARVE := Color(0.08, 0.12, 0.18, 0.95)

## R11's own sim, typed.
var r11: R11Sim:
	get:
		return sim as R11Sim

var textures := {}
static var _narrow: SystemFont

# nodes
var shade: CanvasModulate
var close: Node2D
var mixer: LoopMixer

# presentation (never saved)
var hold_id := ""
var hold_t := -1.0
var cut := ""              # "", "p12" or "door"
var cut_t := 0.0
var port_t := -1.0         # seconds into the false-landing view; < 0 shut
var lever_t := 0.0         # seconds the gate lever stays down after a pull
var access_t := 0.0        # seconds the access lever stays down after a pull
var flag_t := 99.0         # seconds since the flags dropped
var flags_waiting := false # a pull's flags not yet dropped
var mote_t := -1.0
var latch_t := -1.0
var ring_t := -1.0         # seconds into the bell's ring; < 0 none
var bell_pos := -1.0       # the last bell playback position seen
var clock := 0.0           # the view's own 16 s clock, when no bell loop plays
var bell_glance_t := 99.0
var bell_glance_rect := Rect2()
var finger_k := 1.0
var finger_fading := false
var shutter_k := 0.0       # how far the NAME shutter is down, 0..1

func _ready() -> void:
	_load_textures()
	_build_nodes()
	mixer = LoopMixer.new()
	add_child(mixer)
	for id in LOOPS:
		mixer.add_loop(id, game.load_audio(id) if game else null)
	apply_instantly()

# ---------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------
func _load_textures() -> void:
	var names := ["L1_base", "L1_grille", "L1_grille_up", "L1_glass", "L1_glass_deep", "L1_shelves",
		"L2_base", "L2_bell_up", "L2_bell_down", "L2_shoes_dry", "L2_shoes_wet", "L2_shoes_facing",
		"L2_door_open", "L2_finger_marks", "plate_blank", "port_false", "port_true", "cut_glass",
		"cut_hand_a", "cut_hand_b", "c_gate", "c_wheel", "c_lever_up", "c_lever_down", "c_port_shutter",
		"c_door", "c_access_up", "c_access_down", "c_copy_shut", "rec_frame", "rec_strip", "rec_card",
		"rec_card_amended", "rec_bridge", "L1_glass_tilt", "L1_spill", "c_copy_smear",
		"pane_slab", "pane_files", "bell_frozen", "stairwell_fill", "c_gauge_face", "L1_gauge_face",
		"c_name_shutter"]
	for k in range(1, 6):
		names.append("L1_tide_%d" % k)
	for n in names:
		var path := "res://assets/rooms/R11/%s.png" % n
		if ResourceLoader.exists(path):
			var t := load(path) as Texture2D
			if t:
				textures[n] = t
	for n in ["p12_water_slab", "b6_wash", "b6_wash_L1"]:
		var st := load("res://assets/stages/R11/%s.png" % n) as Texture2D
		if st:
			textures[n] = st

func _tex(id: String) -> Texture2D:
	return textures.get(id)

func _build_nodes() -> void:
	shade = CanvasModulate.new()
	shade.color = _shade_color()
	add_child(shade)
	var close_layer := CanvasLayer.new()
	close_layer.layer = 5
	add_child(close_layer)
	close = Node2D.new()
	close_layer.add_child(close)
	close.draw.connect(_draw_close)

static func narrow() -> Font:
	if _narrow == null:
		_narrow = SystemFont.new()
		_narrow.font_names = PackedStringArray(["Liberation Sans Narrow", "Nimbus Sans Narrow",
			"DejaVu Sans Condensed", "Ubuntu Condensed", "sans-serif"])
	return _narrow

func _band() -> int:
	return clampi(gsim().weather_band(), 0, 7) if gsim() else 0

func _flag(f: String) -> bool:
	return gsim().flag(f) if gsim() else false

func landing() -> int:
	return r11.landing if r11 else 1

## The CanvasModulate for the landing in view (state only).
func shade_value() -> float:
	var b := _band()
	return MODULATE_L2[b] if landing() == 2 else MODULATE_L1[b]

func _shade_color() -> Color:
	var v := shade_value() if r11 else MODULATE_L1[0]
	return Color(v, v, v * 1.01)

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func tick(dt: float) -> void:
	if r11 == null:
		return
	shade.color = _shade_color()
	if paused():
		# The menu is over the room: the cut and the hold stand where they are until Resume.
		_tick_audio(dt)
		return
	_tick_hold(dt)
	clock = fmod(clock + dt, BELL_LOOP)
	if cut != "":
		cut_t += dt
		var end := CUT_END if cut == "p12" else DOOR_HOLD + DOOR_SWING
		if cut_t >= end:
			_end_cut()
	if port_t >= 0.0:
		port_t += dt
		if port_t >= PORT_SHOW:
			port_t = -1.0
	lever_t = maxf(0.0, lever_t - dt)
	access_t = maxf(0.0, access_t - dt)
	flag_t += dt
	bell_glance_t += dt
	if cut == "door" and cut_t >= DOOR_HOLD and finger_k < 1.0 and not finger_fading:
		_start_finger_fade()
	if finger_fading:
		finger_k = minf(1.0, finger_k + dt / FINGER_FADE)
		finger_fading = finger_k < 1.0
	_tick_shutter(dt)
	_tick_bell(dt)
	_tick_audio(dt)
	_apply_close_alpha()
	queue_redraw()
	close.queue_redraw()

## The toll's cue (0.5 s into the bell loop): dust from the slab above, or the lower door's
## latch, by band. Read from the loop's own playback position, else the view's clock.
func _tick_bell(dt: float) -> void:
	if mote_t >= 0.0:
		mote_t += dt
		if mote_t >= MOTE_TIME:
			mote_t = -1.0
	if latch_t >= 0.0:
		latch_t += dt
		if latch_t >= LATCH_TIME:
			latch_t = -1.0
	if ring_t >= 0.0:
		ring_t += dt
		if ring_t >= RING_TIME:
			ring_t = -1.0
	var dir := r11.bell_dir()
	var pos := bell_position(dir)
	if bell_pos >= 0.0 and pos >= 0.0 and landing() == 2 and r11.local_view == "room" and cut == "":
		var crossed := (bell_pos < BELL_CUE and pos >= BELL_CUE) or (pos < bell_pos and pos >= BELL_CUE)
		if crossed:
			if motion and dir == "above":
				mote_t = 0.0
			elif motion and dir == "below":
				latch_t = 0.0
	bell_pos = pos

## Where the bell's toll is (seconds into its 16 s loop), or -1 with no bell.
func bell_position(dir: String) -> float:
	if dir == "":
		return -1.0
	var p: AudioStreamPlayer = mixer.players.get("r11_bell_above" if dir == "above" else "r11_bell_below") if mixer else null
	if p and p.playing:
		return fmod(p.get_playback_position(), BELL_LOOP)
	return clock

func _apply_close_alpha() -> void:
	var a := 1.0
	if cut == "p12" and cut_t >= CUT_FADE_AT:
		a = clampf(1.0 - (cut_t - CUT_FADE_AT) / (CUT_END - CUT_FADE_AT), 0.0, 1.0)
	elif cut == "door" and cut_t >= DOOR_HOLD:
		a = clampf(1.0 - (cut_t - DOOR_HOLD) / DOOR_DISSOLVE, 0.0, 1.0) if motion else 0.0
	close.modulate = Color(1, 1, 1, a)

func _tick_hold(dt: float) -> void:
	if hold_id == "":
		return
	if hold_t < 0.0:
		# The core's tide card plays first.
		if game and game.tide_card_t < GameView.TIDE_CARD_TIME and game.tide_card_n > 0:
			return
		hold_t = 0.0
		return
	hold_t += dt
	if hold_t >= HOLD_TIME:
		hold_id = ""
		hold_t = -1.0

## The NAME shutter follows the sim's name_shut(): a quick drop, a slower wind up; still at once.
func _tick_shutter(dt: float) -> void:
	var want := 1.0 if r11.name_shut() else 0.0
	if not motion:
		shutter_k = want
	elif want > shutter_k:
		shutter_k = minf(want, shutter_k + dt / SHUTTER_DROP)
	else:
		shutter_k = maxf(want, shutter_k - dt / SHUTTER_LIFT)

## True while the menu stands over this room (the core holds the line chain the same way).
func paused() -> bool:
	return game != null and game.chain_paused()

func holding() -> bool:
	return hold_id != ""

func cut_playing() -> bool:
	return cut != ""

func _end_cut() -> void:
	cut = ""
	cut_t = 0.0
	close.modulate = Color.WHITE

func _tick_audio(dt: float) -> void:
	mixer.tick(audio_targets(), {}, dt)

## The ambient mix for the current state and landing (tests read this).
func audio_targets() -> Dictionary:
	var band := _band()
	var l := landing()
	var p12: bool = r11.state.p12_complete
	var t := {}
	t["r11_air"] = 0.55
	t["r11_line_pulse"] = 0.35 if l == 1 and _flag("P11") and not p12 else 0.0
	t["r11_glass"] = (0.3 if l == 1 else 0.1) if p12 else 0.0
	t["r11_bell_above"] = (0.55 if l == 2 else 0.25) if p12 and band >= 3 and band <= 5 else 0.0
	t["r11_bell_below"] = (0.6 if l == 2 else 0.3) if p12 and band >= 6 else 0.0
	t["r11_pressure"] = 0.4 if band >= 7 else 0.0
	if cut != "":
		for k in t:
			if k != "r11_glass":
				t[k] = 0.0
	return t

# ---------------------------------------------------------------------------
# hooks
# ---------------------------------------------------------------------------
func back_visible() -> bool:
	return r11.is_closeup() and cut == ""

## Esc always reaches the menu: during a hold or a cut it opens the menu (tick() stops the
## cut's and the hold's clocks while it is up, so Resume carries on from there), never Back.
func esc_action() -> String:
	if holding() or cut_playing():
		return "menu"
	return "back" if r11.is_closeup() else "menu"

func chain_gates() -> bool:
	return true

func exits_active() -> bool:
	return r11.local_view == "room" and not holding() and not cut_playing()

func exit_rects() -> Dictionary:
	return EXIT_RECTS

## The way back to the chart room on the gate landing; below it, the laboratory and the
## gallery when open, and the lower door's way only once it stands open (P24).
func live_exit_rects() -> Dictionary:
	if r11 == null:
		return {}
	if landing() == 1:
		return {"R03": EXIT_RECTS.R03}
	var out := {}
	for to in ["R07", "R09"]:
		if gsim() == null or gsim().exit_open("R11", to):
			out[to] = EXIT_RECTS[to]
	if _flag("P24"):
		out["R12"] = EXIT_RECTS.R12
	return out

func exit_arrow(to_rid: String) -> String:
	return EXIT_ARROWS.get(to_rid, "")

func apply_instantly() -> void:
	if r11 == null:
		return
	hold_id = ""
	hold_t = -1.0
	_end_cut()
	port_t = -1.0
	lever_t = 0.0
	access_t = 0.0
	flag_t = 99.0
	flags_waiting = false
	mote_t = -1.0
	latch_t = -1.0
	ring_t = -1.0
	bell_glance_t = 99.0
	finger_k = 1.0
	finger_fading = false
	shutter_k = 1.0 if r11.name_shut() else 0.0
	shade.color = _shade_color()
	mixer.snap(audio_targets())
	queue_redraw()
	close.queue_redraw()

func reset_presentation() -> void:
	hold_id = ""
	hold_t = -1.0
	if close:
		_end_cut()
	port_t = -1.0
	lever_t = 0.0
	access_t = 0.0
	flag_t = 99.0
	flags_waiting = false
	mote_t = -1.0
	latch_t = -1.0
	ring_t = -1.0
	bell_glance_t = 99.0
	finger_k = 1.0
	finger_fading = false
	shutter_k = 1.0 if r11 and r11.name_shut() else 0.0

func play_fx(id: String, e: Dictionary) -> void:
	match id:
		"notice":
			hold_id = String(e.get("notice", ""))
			hold_t = -1.0
			if hold_id != "" and not NOTICE_RECTS.has(hold_id):
				hold_id = ""
			if hold_id != "":
				_tick_hold(0.0)
		"false_landing":
			port_t = 0.0
		"gate_flags":
			_drop_flags()
		"p12_cut":
			cut = "p12"
			cut_t = 0.0
			lever_t = 0.0
			hold_id = ""
		"door_open":
			cut = "door"
			cut_t = 0.0
			access_t = 0.0
			finger_k = 0.0
			finger_fading = false
			hold_id = ""
	queue_redraw()
	close.queue_redraw()

## The finger marks come up on the open leaf (motion: over FINGER_FADE; still: at once).
func _start_finger_fade() -> void:
	finger_fading = motion
	if not motion:
		finger_k = 1.0

func _drop_flags() -> void:
	flags_waiting = false
	flag_t = 0.0 if motion else FLAG_DROP

func on_sfx(id: String) -> void:
	match id:
		"r11_lever_pull":
			lever_t = LEVER_DOWN
		"r11_access_lever":
			access_t = LEVER_DOWN
		"r11_flags":
			_drop_flags()
		"r11_bell_up":
			ring_t = 0.0

func on_sfx_pending(id: String, _left: float) -> void:
	if id == "r11_flags" and not flags_waiting and flag_t > FLAG_DROP:
		flags_waiting = true

## The core's glance after a reveal. The bell gets the core's brackets (false) and its own
## brass ones after a settle; the lower door shows its finger marks itself, fading in.
func start_glance(target: String, rect: Rect2) -> bool:
	match target:
		"bell_sound":
			bell_glance_rect = rect
			bell_glance_t = 0.0
			return false
		"lower_door":
			if finger_k < 1.0 and not finger_fading:
				_start_finger_fade()
			return true
	return false

# ---------------------------------------------------------------------------
# hit testing (pure)
# ---------------------------------------------------------------------------
func _landing_list() -> Array:
	return LANDING_HOTSPOTS.get(landing(), HOTSPOTS)

## The nav plaque live on this landing: descend on the gate landing once the gate is open,
## ascend below it. "" for none.
func live_nav() -> String:
	if r11 == null:
		return ""
	if landing() == 1:
		return "descend" if r11.state.p12_complete else ""
	return "ascend"

func closeup_controls(view: String) -> Array:
	match view:
		"c_gate":
			return GATE_CONTROLS
		"c_chamber_door":
			return DOOR_CONTROLS
	return []

## Core hook, before any hit test: a click during a notice hold skips the hold; during a cut,
## it skips the rest of the cut. Nothing more.
func consume_click(_p: Vector2) -> bool:
	if cut_playing():
		_end_cut()
		if r11 and r11.door_open() and finger_k < 1.0 and not finger_fading:
			_start_finger_fade()
		return true
	if holding():
		hold_id = ""
		hold_t = -1.0
		return true
	return false

func action_at(p: Vector2) -> String:
	if r11 == null or holding() or cut_playing():
		return ""
	match r11.local_view:
		"room":
			var nav := live_nav()
			if nav != "" and NAV_RECTS[nav].has_point(p):
				return nav
			for h in _landing_list():
				if h[1].has_point(p):
					return h[0]
		"c_gate", "c_chamber_door":
			for h in closeup_controls(r11.local_view):
				if h[1].has_point(p):
					return h[0]
	return ""

func hover_at(p: Vector2) -> String:
	return action_at(p)

func label_for(id: String) -> String:
	if NAV_LABELS.has(id):
		return NAV_LABELS[id]
	for list in [HOTSPOTS, L2_HOTSPOTS, GATE_CONTROLS, DOOR_CONTROLS]:
		for h in list:
			if h[0] == id:
				return h[2]
	return ""

func hotspot_rect(id: String) -> Rect2:
	if NAV_RECTS.has(id):
		return NAV_RECTS[id]
	for list in [HOTSPOTS, L2_HOTSPOTS]:
		for h in list:
			if h[0] == id:
				return h[1]
	return Rect2()

func control_rect(id: String) -> Rect2:
	for list in [GATE_CONTROLS, DOOR_CONTROLS]:
		for h in list:
			if h[0] == id:
				return h[1]
	return hotspot_rect(id)

func dev_rects() -> Array:
	var out := []
	if r11 == null:
		return out
	if r11.local_view == "room":
		for h in _landing_list():
			out.append(h[1])
		var nav := live_nav()
		if nav != "":
			out.append(NAV_RECTS[nav])
	else:
		for h in closeup_controls(r11.local_view):
			out.append(h[1])
	return out

# ---------------------------------------------------------------------------
# HUD: the nav plaque
# ---------------------------------------------------------------------------
func draw_hud(c0: Node2D) -> void:
	if r11 == null or r11.local_view != "room" or cut_playing():
		return
	var nav := live_nav()
	if nav == "":
		return
	var r: Rect2 = NAV_RECTS[nav]
	Ink.button(c0, r, "", false, 20, holding())
	var f := Ink.serif()
	var arrow: String = NAV_ARROWS[nav]
	var aw := f.get_string_size(arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	c0.draw_string(f, Vector2(r.get_center().x - aw / 2.0, r.position.y + 40), arrow,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Ink.PAPER)
	# The landing's name runs up the plaque, read with the head tilted.
	var name: String = NAV_NAMES[nav]
	var size := 19
	var nw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var cx := r.get_center().x
	var cy := r.position.y + 52 + (r.size.y - 52) / 2.0
	c0.draw_set_transform(Vector2(cx + 7, cy + nw / 2.0), -PI / 2.0, Vector2.ONE)
	c0.draw_string(f, Vector2.ZERO, name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Ink.PAPER)
	c0.draw_set_transform_matrix(Transform2D.IDENTITY)

# ---------------------------------------------------------------------------
# drawing: the landings
# ---------------------------------------------------------------------------
func _draw() -> void:
	if r11 == null or r11.is_closeup():
		return
	if landing() == 2:
		_draw_l2()
	else:
		_draw_l1()
	_draw_notice_frame()
	_draw_bell_glance()

func _plate(id: String, at := Vector2.ZERO) -> bool:
	var t := _tex(id)
	if t:
		draw_texture(t, at)
		return true
	return false

func _placeholder(list: Array) -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("b8c9b4"))
	for h in list:
		draw_rect(h[1], Color(Ink.PAPER, 0.92))
		draw_rect(h[1], Ink.INK, false, 3.0)
		Ink.wrapped(self, h[2], h[1].position + Vector2(12, 34), 22, Ink.INK, h[1].size.x - 24)

func _draw_l1() -> void:
	if not _plate("L1_base"):
		_placeholder(HOTSPOTS)
	if wash_shown():
		_plate("b6_wash_L1")
	var n := r11.tide_lines()
	if n > 0:
		_plate("L1_tide_%d" % n)
	var gm := r11.glass_mode()
	if gm != "":
		_plate(glass_plate(gm))
		_draw_caustics()
	if r11.water_slab():
		_draw_water_slab(self)
	# The shelves go over the glass: the pane is opaque inside the opening and would hide them.
	if r11.shelves_shown():
		_plate("L1_shelves")
	_draw_pane(gm != "")
	_draw_water_glint()
	if _band() >= SPILL_BAND:
		_plate("L1_spill")
	_plate("L1_grille_up" if r11.gate_up() else "L1_grille")
	_draw_stair_marks()
	if _band() >= FAR_MARKS_BAND and r11.state.p12_complete:
		_draw_far_marks()
	_draw_l1_gauge()
	_draw_wheel(self, L1_HUB, 0.57)
	_draw_l1_plates()
	_draw_l1_lever()
	_draw_l1_placard()

## The late wash on both landings' walls (state only: the weather band).
func wash_shown() -> bool:
	return _band() >= WASH_BAND

## The horizontal pane: before P12 the whole gateway (wet navy steps above it, bone-dry ones
## below, one hard sea-glass slab between); after it, the slab alone over the standing water,
## with the vault's files hanging upside down inside it.
func _draw_pane(open: bool) -> void:
	var t := _tex("pane_slab")
	if t == null:
		return
	if open:
		draw_texture_rect_region(t, SLAB_BAND, SLAB_BAND)
		_plate("pane_files")
	else:
		draw_texture(t, Vector2.ZERO)

## The water standing up in the gateway as one slab, under the horizontal pane and the raised
## grille. Static; with Motion on, one pale band slides slowly down its face.
func _draw_water_slab(cv: CanvasItem, alpha := 1.0) -> void:
	var t := _tex("p12_water_slab")
	if t == null:
		return
	cv.draw_texture(t, Vector2.ZERO, Color(1, 1, 1, alpha))
	var k := shimmer_k()
	if k < 0.0:
		return
	var r := WATER_SLAB.grow(-6.0)
	var y := r.position.y + 12.0 + (r.size.y - 40.0) * k
	cv.draw_rect(Rect2(r.position.x, y, r.size.x, 22.0), Color(PALE, 0.10 * alpha))
	cv.draw_rect(Rect2(r.position.x, y + 8.0, r.size.x, 4.0), Color(PALE, 0.16 * alpha))

## Where the shimmer band is down the slab, 0..1, or -1 with Motion off (no shimmer).
func shimmer_k() -> float:
	if not motion:
		return -1.0
	return fmod(time, SHIMMER_PERIOD) / SHIMMER_PERIOD

## The standing water's plate: shallow, deep (band 4+), or deep with its plane tilted (band 7).
func glass_plate(gm: String) -> String:
	if gm != "deep":
		return "L1_glass"
	return "L1_glass_tilt" if _band() >= TILT_BAND else "L1_glass_deep"

## Band 6+: the jamb's three marks again, faintly, beyond the water and in the wrong order.
func _draw_far_marks() -> void:
	var src := stair_strokes()
	var centres := [Vector2(512, 450), Vector2(512, 570), Vector2(512, 690)]
	var at := [FAR_MARKS.bracket, FAR_MARKS.linked, FAR_MARKS.circle]
	for i in mini(src.size(), 3):
		var pts := PackedVector2Array()
		for q in src[i]:
			pts.append(at[i] + (q - centres[i]) * 0.4)
		draw_polyline(pts, Color(PALE, 0.35), 5.0, true)
		draw_polyline(pts, Color(0.06, 0.16, 0.18, 0.62), 3.0, true)

## A glint slides along the water plane's bright edge every 9 s (still: one fixed glint).
func glint_x() -> float:
	if not motion:
		return 700.0
	var k := fmod(time, GLINT_PERIOD) / GLINT_PERIOD
	return lerpf(WATER_X[0], WATER_X[1] - 40.0, k)

func _draw_water_glint() -> void:
	var x := glint_x()
	var col := Color(PALE, 0.75)
	draw_line(Vector2(x, SLAB_Y + 1), Vector2(x + 40, SLAB_Y + 1), col, 2.0)
	draw_line(Vector2(x + 8, SLAB_Y + 5), Vector2(x + 30, SLAB_Y + 5), Color(PALE, 0.35), 2.0)

## Two pale vertical caustic lines in the standing glass, drifting a little (still: static).
func _draw_caustics() -> void:
	var d := 2.0 * sin(time * 0.9) if motion else 0.0
	var d2 := 2.0 * sin(time * 0.7 + 1.3) if motion else 0.0
	draw_line(Vector2(640 + d, 200), Vector2(640 + d, 860), Color(PALE, 0.22), 3.0)
	draw_line(Vector2(812 + d2, 220), Vector2(812 + d2, 850), Color(PALE, 0.16), 2.0)

## The three marks carved down the gateway's right jamb, R03's hatch marks at about 28 px.
func _draw_stair_marks() -> void:
	var src := stair_strokes()
	var centres := [Vector2(512, 450), Vector2(512, 570), Vector2(512, 690)]
	var at := [STAIR_MARKS.bracket, STAIR_MARKS.linked, STAIR_MARKS.circle]
	for i in mini(src.size(), 3):
		var pts := PackedVector2Array()
		for q in src[i]:
			pts.append(at[i] + (q - centres[i]) * 0.4)
		draw_polyline(pts, Color(PALE, 0.7), 5.0, true)
		draw_polyline(pts, CARVE, 3.0, true)

## R03's hatch marks (R03 view's scratch_strokes()), read once: the same three cuts.
static var _strokes: Array = []

static func stair_strokes() -> Array:
	if _strokes.is_empty():
		var s: Script = load("res://game/rooms/R03/R03_view.gd")
		if s:
			_strokes = s.call("scratch_strokes")
	return _strokes

static func _from_up(c0: Vector2, r: float, deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return c0 + Vector2(sin(a), -cos(a)) * r

static func tick_deg(n: float) -> float:
	return -120.0 + 48.0 * n

## The gauge's one needle: black, on the wheel. The face has four unnumbered ticks and no
## reference needle; the target is the laboratory's tag, never the gauge's.
func _needles(cv: CanvasItem, c0: Vector2, r: float, k: float) -> void:
	var pd := tick_deg(r11.needle_pressure())
	var ptip := _from_up(c0, r * 0.86, pd)
	var pn := (ptip - c0).normalized().orthogonal()
	var tail := c0 - (ptip - c0).normalized() * r * 0.16
	var pw := 11.0 * k
	cv.draw_colored_polygon(PackedVector2Array([tail + pn * pw * 0.6, c0 + pn * pw, ptip, c0 - pn * pw, tail - pn * pw * 0.6]), Ink.INK)
	cv.draw_circle(c0, 14.0 * k, Ink.INK)
	cv.draw_circle(c0, 6.0 * k, Ink.BRASS)

## The unnumbered face over a painted dial: `half` is the sprite's half size about its centre.
func _gauge_face(cv: CanvasItem, id: String, c0: Vector2, half: Vector2) -> void:
	var t := _tex(id)
	if t:
		cv.draw_texture(t, c0 - half)

## Band 5+, once the gate is open: a second, faint hairline needle resting on 2. Nothing moves
## it. (Never before P12: the face must not give the target.)
func _ghost_needle(cv: CanvasItem, c0: Vector2, r: float) -> void:
	var tip := _from_up(c0, r * 1.02, tick_deg(2))
	var tail := _from_up(c0, r * 0.34, tick_deg(2) + 180.0)
	var col := Color(Ink.INK, 0.45)
	cv.draw_line(tail, tip, col, 2.0, true)
	cv.draw_circle(tail, 7.0, col)

## The window under the hub: NO PRESSURE on a dead line, else blank. No reference reading.
func status_text() -> String:
	return "NO PRESSURE" if not r11.powered() else ""

func _draw_l1_gauge() -> void:
	_draw_l1_gauge_on(self)

func _draw_l1_gauge_on(cv: CanvasItem) -> void:
	_gauge_face(cv, "L1_gauge_face", L1_DIAL, L1_FACE_HALF)
	_needles(cv, L1_DIAL, L1_DIAL_R - 10.0, 0.5)
	var st := status_text()
	if st != "":
		_centered(cv, st, Rect2(264, 334, 72, 22), 11, Ink.INK)

## The handwheel, a sixth of a turn per step of pressure.
func _draw_wheel(cv: CanvasItem, at: Vector2, k: float) -> void:
	var t := _tex("c_wheel")
	if t == null:
		cv.draw_arc(at, 130 * k, 0, TAU, 40, Ink.INK, 4.0)
		return
	cv.draw_set_transform(at, deg_to_rad(60.0 * int(r11.state.pressure)), Vector2(k, k))
	cv.draw_texture(t, -t.get_size() / 2.0)
	cv.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_l1_plates() -> void:
	# The second strap and its two hooks, for '[ 3' and '] 3'.
	var sr := L1_STRAP2
	draw_rect(sr, Ink.BRASS)
	draw_rect(sr, Ink.INK, false, 1.4)
	for pid in ["o3", "c3"]:
		_hook(self, L1_HOOKS[pid], 1.0)
	var slots: Array = r11.state.slots
	for i in 2:
		var pid: String = slots[i]
		if pid != "":
			var r: Rect2 = L1_SLOTS[i]
			_draw_plate(self, pid, r.get_center() - PLATE_SIZE * 0.15, 0.3)
	for pid in R11Sim.PLATES:
		if not pid in slots:
			_draw_plate(self, pid, L1_HOOKS[pid] - PLATE_HOLE * 0.3, 0.3)

## A rack hook whose bent tip is `tip`, as the painted ones: `k` 1 at room scale.
func _hook(cv: CanvasItem, tip: Vector2, k: float) -> void:
	var pts := PackedVector2Array()
	if k > 1.0:
		for q in [Vector2(-9, -22), Vector2(-9, -4), Vector2(0, 6), Vector2(9, -4)]:
			pts.append(tip + q)
		cv.draw_polyline(pts, Ink.INK, 7.0, true)
		cv.draw_polyline(pts, BRASS_HI, 3.6, true)
	else:
		for q in [Vector2(-6, -10), Vector2(-6, -2), Vector2(0, 2), Vector2(6, -2)]:
			pts.append(tip + q)
		cv.draw_polyline(pts, Ink.INK, 4.2, true)
		cv.draw_polyline(pts, BRASS_HI, 2.0, true)

func _draw_l1_lever() -> void:
	var r := L1_LEVER
	var down := r11.gate_up()
	var y := r.end.y - 26.0 if down else r.position.y + 6.0
	var knob := Rect2(r.position.x - 10, y, r.size.x + 20, 20)
	draw_rect(Rect2(r.position.x + 7, minf(y + 10, r.get_center().y), 8, absf(r.get_center().y - y - 10)), Ink.BRASS)
	draw_rect(knob, Ink.BRASS)
	draw_rect(knob, Ink.INK, false, 2.0)
	draw_line(knob.position + Vector2(4, 4), Vector2(knob.end.x - 4, knob.position.y + 4), BRASS_HI, 1.5)

func _draw_l1_placard() -> void:
	var r := L1_PLACARD
	var nf := narrow()
	_centered(self, "PRESSURE GATE · DRY STAIR", Rect2(r.position.x, r.position.y + 6, r.size.x, 22), 15, Ink.INK)
	draw_line(Vector2(r.position.x + 14, r.position.y + 34), Vector2(r.end.x - 14, r.position.y + 34), Ink.STORM, 1.5)
	var y := r.position.y + 62.0
	for line in ["1. EQUALISE.", "2. SELECT A STABLE", "    LANDING.", "3. PULL OPEN."]:
		draw_string(nf, Vector2(r.position.x + 16, y), line, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 15, Ink.INK)
		y += 26.0
	# The worked example, small.
	var ex := Vector2(r.get_center().x, r.position.y + 210)
	_centered(self, "[ 7", Rect2(ex.x - 50, ex.y - 26, 100, 22), 18, Ink.INK)
	draw_line(ex + Vector2(-46, 0), ex + Vector2(46, 0), Ink.INK, 1.5)
	_centered(self, "] 7", Rect2(ex.x - 50, ex.y + 6, 100, 22), 18, Ink.INK)

func _draw_l2() -> void:
	if not _plate("L2_base"):
		_placeholder(L2_HOTSPOTS)
	if wash_shown():
		_plate("b6_wash")
	_plate("stairwell_fill")
	if _band() >= CAUSTIC_BAND:
		_draw_floor_caustics()
	_plate("L2_shoes_" + r11.shoes_state())
	_draw_bell()
	if r11.door_open():
		_draw_door_leaf()
	else:
		if _band() >= THRESHOLD_BAND:
			_draw_threshold_glow()
		if latch_t >= 0.0 and motion:
			_draw_latch_shake()
	_draw_l2_marks()
	_draw_motes()

## The frozen bell: tipped 30 degrees toward the office, or the same bell mirrored about its
## bearing once it tips toward the lower door (band 6+). It never moves.
func bell_mirrored() -> bool:
	return r11.bell_dir() == "below"

func bell_centre() -> Vector2:
	if bell_mirrored():
		return Vector2(2.0 * BELL_PIVOT.x - BELL_BODY.x, BELL_BODY.y)
	return BELL_BODY

func _draw_bell() -> void:
	var t := _tex("bell_frozen")
	if t == null:
		_plate("L2_bell_down" if bell_mirrored() else "L2_bell_up")
	elif bell_mirrored():
		draw_set_transform(Vector2(2.0 * BELL_PIVOT.x, 0), 0.0, Vector2(-1, 1))
		draw_texture(t, Vector2.ZERO)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		draw_texture(t, Vector2.ZERO)
	_draw_ring()

## The ring's radius and alpha now, or [] for none: one thin ring off the bell's first toll,
## expanding and fading over 1.5 s (Motion off: still, fading out over 1.5 s). The loop's later
## tolls leave the bell bare: no outline lingers round it once the glance has shown it.
func ring_now() -> Array:
	if ring_t < 0.0 or ring_t >= RING_TIME:
		return []
	var k := ring_t / RING_TIME
	if not motion:
		return [RING_STILL_R, 0.7 * (1.0 - k)]
	return [lerpf(RING_R[0], RING_R[1], k), 0.85 * (1.0 - k)]

func _draw_ring() -> void:
	var rn := ring_now()
	if rn.is_empty():
		return
	draw_arc(bell_centre(), rn[0], 0.0, TAU, 96, Color(Ink.INK, rn[1]), 3.0, true)

## The lower door's leaf, swung in from its hinge at x 600 while the P24 cut dissolves (still:
## open at once).
func _draw_door_leaf() -> void:
	var t := _tex("L2_door_open")
	if t == null:
		return
	var k := 1.0
	if cut == "door" and motion:
		k = clampf((cut_t - DOOR_HOLD) / DOOR_SWING, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
	# The doorway itself (right of the hinge) is open at once; the leaf (left of it) swings out.
	var way := Rect2(HINGE_X, 430, 300, 480)
	draw_texture_rect_region(t, way, way)
	if k <= 0.0:
		return
	var leaf := Rect2(290, 430, HINGE_X - 290, 480)
	var dest := Rect2(HINGE_X - leaf.size.x * k, leaf.position.y, leaf.size.x * k, leaf.size.y)
	draw_texture_rect_region(t, dest, leaf)
	# Its inner face's marks swing in with it, fading up from the swing.
	var fm := _tex("L2_finger_marks")
	if fm and finger_k > 0.0:
		draw_texture_rect_region(fm, dest, leaf, Color(1, 1, 1, finger_k))

## Band 5+: a slow flat sea-glass caustic band on the wall under the glass floor (still: fixed).
func _draw_floor_caustics() -> void:
	var ph := time * 0.22 if motion else 0.0
	for j in 3:
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		var y0 := 346.0 + 22.0 * j
		var x := 310.0
		while x <= 1132.0:
			var w := 4.0 * sin(x / 53.0 + ph * (1.0 + 0.3 * j) + j * 1.7) + 3.0 * sin(x / 21.0 - ph * 0.7 + j)
			top.append(Vector2(x, y0 + w))
			bot.append(Vector2(x, y0 + w + 5.0 + 3.0 * sin(x / 37.0 + ph + j * 2.3)))
			x += 12.0
		var poly := top.duplicate()
		bot.reverse()
		poly.append_array(bot)
		draw_colored_polygon(poly, Color(0.62, 0.78, 0.72, 0.30 - 0.06 * j))

## Band 6+, the door still shut: cold light under its foot, a hard bar, and a little on the flags.
func _draw_threshold_glow() -> void:
	draw_rect(Rect2(604, 872, 272, 7), Color(0.9, 0.97, 0.95, 0.9))
	draw_colored_polygon(PackedVector2Array([Vector2(604, 880), Vector2(876, 880), Vector2(910, 900), Vector2(570, 900)]),
		Color(0.75, 0.9, 0.86, 0.3))

func _draw_latch_shake() -> void:
	var t := _tex("L2_base")
	if t == null:
		return
	var dx := 2.0 * sin(latch_t * TAU * 18.0)
	draw_texture_rect_region(t, Rect2(LATCH.position + Vector2(dx, 0), LATCH.size), LATCH)

## Dust from the slab above as the toll lands (motion only).
func _draw_motes() -> void:
	if mote_t < 0.0 or not motion:
		return
	var k := mote_t / MOTE_TIME
	for i in 6:
		var x := 380.0 + 34.0 * i + 6.0 * sin(i * 2.1 + k * 3.0)
		var y := 336.0 + 60.0 * k * (0.7 + 0.08 * i)
		draw_circle(Vector2(x, y), 2.2, Color(PALE, 0.85 * (1.0 - k * 0.7)))

func _draw_l2_marks() -> void:
	_centered(self, "LABORATORY", L2_DOOR_PLATE, 22, Ink.INK)
	for f in R11Sim.FRAMES:
		var r: Rect2 = L2_FRAMES[f]
		var it := r11.frame_item(f)
		if it != "":
			_rec(self, it, Rect2(r.position.x + 15, r.position.y + 22, 90, 66), false)
		_centered(self, f, Rect2(r.position.x, r.position.y + 2, r.size.x, 16), 13, PALE)
	draw_arc(L2_SOCKET, 36.0, 0, TAU, 32, Ink.INK, 2.0)
	_centered(self, "COPY", Rect2(L2_COPY_STAMP.position.x, L2_COPY_STAMP.position.y - 2, L2_COPY_STAMP.size.x, 14), 11, Ink.INK)
	if not r11.door_open():
		if r11.witness_item() != "":
			_rec(self, R11Sim.BRIDGE, Rect2(L2_SOCKET - Vector2(30, 30), Vector2(60, 60)), false)
		if r11.copy_item() != "":
			var cs := _tex("c_copy_shut")
			if cs:
				draw_texture_rect(cs, Rect2(L2_COPY.position - Vector2(7, 7), Vector2(74, 74)), false)
		var down := access_t > 0.0
		var lr := L2_LEVER
		var y := lr.end.y - 22.0 if down else lr.position.y + 4.0
		draw_rect(Rect2(lr.position.x - 8, y, lr.size.x + 16, 18), Ink.BRASS)
		draw_rect(Rect2(lr.position.x - 8, y, lr.size.x + 16, 18), Ink.INK, false, 2.0)

## Brass brackets of the view's own round the bell, after a settle (the core adds its own).
func _draw_bell_glance() -> void:
	if bell_glance_t < BELL_GLANCE_SETTLE or bell_glance_t > BELL_GLANCE_SETTLE + BELL_GLANCE_TIME or landing() != 2:
		return
	var k := 1.0
	if motion:
		var t := bell_glance_t - BELL_GLANCE_SETTLE
		k = clampf(t / 0.4, 0.0, 1.0) * clampf((BELL_GLANCE_TIME - t) / 0.4, 0.0, 1.0)
	var r := bell_glance_rect.grow(-4.0)
	var arm := 22.0
	var col := Color(Ink.BRASS, k)
	for c in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var p: Vector2 = c[0]
		var d: Vector2 = c[1]
		draw_line(p, p + Vector2(d.x * arm, 0), col, 4.0)
		draw_line(p, p + Vector2(0, d.y * arm), col, 4.0)

## A slow pale ink frame drawn round the notice's region (static with Motion off).
func _draw_notice_frame() -> void:
	if not holding():
		return
	var r: Rect2 = NOTICE_RECTS[hold_id].grow(6)
	r = r.intersection(Rect2(4, 84, SIZE.x - 8, 906))
	var k := 1.0
	if motion:
		k = clampf(hold_t / HOLD_TIME, 0.0, 1.0) if hold_t >= 0.0 else 0.0
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	var per := 2.0 * (r.size.x + r.size.y)
	var left := per * k
	for i in 4:
		var p0: Vector2 = corners[i]
		var p1: Vector2 = corners[i + 1]
		var seg := p0.distance_to(p1)
		if left <= 0.0:
			break
		var q := p0.lerp(p1, minf(1.0, left / seg))
		draw_line(p0, q, Color(Ink.INK, 0.45 * 0.85), 7.0)
		draw_line(p0, q, Color(PALE, 0.85), 3.0)
		left -= seg

# ---------------------------------------------------------------------------
# shared marks
# ---------------------------------------------------------------------------
func _centered(cv: CanvasItem, s: String, r: Rect2, size: int, col: Color, font: Font = null) -> void:
	if font == null:
		font = narrow()
	var fs := size
	while fs > 9 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 4:
		fs -= 1
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	cv.draw_string(font, Vector2(r.get_center().x - w / 2.0, r.get_center().y + fs * 0.36), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## A landing plate: the blank enamel plate with its bracket and numeral in large narrow type
## and a small BOUNDARY under the bracket. `at` is its top-left, `k` its scale.
func _draw_plate(cv: CanvasItem, pid: String, at: Vector2, k: float) -> void:
	var t := _tex("plate_blank")
	var size := PLATE_SIZE * k
	if t:
		cv.draw_texture_rect(t, Rect2(at, size), false)
	else:
		cv.draw_rect(Rect2(at, size), ENAMEL)
		cv.draw_rect(Rect2(at, size), Ink.INK, false, 2.0)
	var txt: String = R11Sim.PLATE_TEXT.get(pid, "")
	if txt.length() < 3:
		return
	var nf := narrow()
	var big := int(round(78.0 * k))
	var brk := txt.substr(0, 1)
	var num := txt.substr(2)
	var bw := nf.get_string_size(brk, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	cv.draw_string(nf, at + Vector2(78.0 * k - bw / 2.0, 98.0 * k), brk, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Ink.INK)
	var nw := nf.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	cv.draw_string(nf, at + Vector2(158.0 * k - nw / 2.0, 98.0 * k), num, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Ink.INK)
	if k >= 1.0:
		var small := int(round(13.0 * k))
		var sw := nf.get_string_size("BOUNDARY", HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
		cv.draw_string(nf, at + Vector2(78.0 * k - sw / 2.0, 122.0 * k), "BOUNDARY", HORIZONTAL_ALIGNMENT_LEFT, -1, small, Ink.INK)

## Left-aligned text shrunk to fit `w`.
func _fit(cv: CanvasItem, font: Font, at: Vector2, s: String, size: int, w: float, col: Color) -> void:
	var fs := size
	while fs > 7 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 1
	cv.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## A record sprite in `r`; with `words`, its typed and pencilled lines (close-up scale).
func _rec(cv: CanvasItem, item: String, r: Rect2, words: bool) -> void:
	var t := _tex(REC_TEX.get(item, ""))
	if t:
		cv.draw_texture_rect(t, r, false)
	else:
		cv.draw_rect(r, Ink.PAPER)
	if not words:
		return
	var k := r.size.x / 300.0
	var nf := narrow()
	var o := r.position
	match item:
		"nora_frame":
			cv.draw_string(nf, o + Vector2(196, 35) * k, "N. BELL", HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * k), Ink.INK)
		"nora_spatial_strip":
			cv.draw_string(nf, o + Vector2(196, 140) * k, "N. BELL", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), Ink.INK)
		"amended_nora_card", "nora_register_card":
			cv.draw_string(nf, o + Vector2(64, 58) * k, "NORA BELL", HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * k), Ink.INK)
			if item == "amended_nora_card":
				var lines := ["PERSONAL EFFECT IDENTIFIED", "REPAIRED CUP", "NORA BELL"]
				for i in lines.size():
					_fit(cv, Ink.hand(), o + Vector2(62, 80 + 18 * i) * k, lines[i], int(15 * k), 210.0 * k, GRAPHITE)
			else:
				_fit(cv, nf, o + Vector2(62, 80) * k, "NO SURVIVING PERSONAL EFFECTS", int(14 * k), 210.0 * k, Ink.INK)

# ---------------------------------------------------------------------------
# close-ups and cuts (layer 5, unmodulated)
# ---------------------------------------------------------------------------
func _draw_close() -> void:
	if r11 == null:
		return
	if cut == "p12":
		_draw_p12_cut(close)
		return
	if cut == "door":
		_draw_door(close, true)
		return
	match r11.local_view:
		"c_gate":
			_draw_gate(close, false)
		"c_chamber_door":
			_draw_door(close, false)

func _bg(cv: CanvasItem, id: String, fallback: Color) -> void:
	var t := _tex(id)
	if t:
		cv.draw_texture(t, Vector2.ZERO)
	else:
		cv.draw_rect(Rect2(Vector2.ZERO, SIZE), fallback)

# --- c_gate ------------------------------------------------------------------------------
## The gate's close-up. `cut`: the P12 cut's first beat (lever down, shutter, the shake).
func _draw_gate(cv: CanvasItem, in_cut: bool) -> void:
	var shake := Vector2.ZERO
	if in_cut and motion and cut_t >= 0.6 and cut_t < 0.85:
		shake = Vector2(6.0 * sin(cut_t * 90.0), 0)
	cv.draw_set_transform(shake, 0.0, Vector2.ONE)
	_bg(cv, "c_gate", Color("54646a"))
	cv.draw_set_transform_matrix(Transform2D.IDENTITY)
	var nf := narrow()
	# The dial: the unnumbered face, the one needle, its status window.
	_gauge_face(cv, "c_gauge_face", DIAL_C, C_FACE_HALF)
	if _band() >= GHOST_BAND and r11.state.p12_complete:
		_ghost_needle(cv, DIAL_C, DIAL_R - 20.0)
	_needles(cv, DIAL_C, DIAL_R - 20.0, 1.0)
	var st := status_text()
	if st != "":
		_centered(cv, st, STATUS_WIN, 20, Ink.INK)
	# The handwheel and its two step plates.
	_draw_wheel(cv, WHEEL_C, 1.0)
	_centered(cv, "LESS", Rect2(150, 840, 150, 70), 34, Ink.INK)
	_centered(cv, "MORE", Rect2(360, 840, 150, 70), 34, Ink.INK)
	# The indicator flags.
	_draw_flags(cv)
	# The lock-box: its recesses, the boundary rule and the plates in it.
	_centered(cv, "BOUNDARY", BOUNDARY_PLATE, 18, Ink.INK)
	var slots: Array = r11.state.slots
	for i in 2:
		var r: Rect2 = SLOT_RECTS[i]
		if slots[i] != "":
			_draw_plate(cv, slots[i], r.get_center() - PLATE_SIZE / 2.0 + Vector2(14, 4), 1.0)
		# The recess's word runs up its left edge, clear of any plate.
		var word: String = SLOT_WORDS[i]
		var ww := nf.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		cv.draw_set_transform(Vector2(r.position.x + 26, r.get_center().y + ww / 2.0), -PI / 2.0, Vector2.ONE)
		cv.draw_string(nf, Vector2.ZERO, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, PALE)
		cv.draw_set_transform_matrix(Transform2D.IDENTITY)
	# The rack's second bar, under the painted one, and its two hooks.
	var rb := GATE_RACK2
	cv.draw_rect(rb, Ink.BRASS)
	cv.draw_rect(rb, Ink.INK, false, 2.4)
	cv.draw_line(rb.position + Vector2(4, 3), Vector2(rb.end.x - 4, rb.position.y + 3), BRASS_HI, 1.6)
	for x in [rb.position.x, rb.end.x]:
		cv.draw_rect(Rect2(x - 10, rb.position.y - 8, 20, 28), Color("424e58"))
		cv.draw_rect(Rect2(x - 10, rb.position.y - 8, 20, 28), Ink.INK, false, 2.2)
	for pid in ["o3", "c3"]:
		_hook(cv, GATE_HOOKS[pid], 2.0)
	# The rack: plates on their hooks, at 0.75.
	for pid in R11Sim.PLATES:
		if not pid in slots and pid != r11.held_plate:
			_draw_plate(cv, pid, GATE_HOOKS[pid] - PLATE_HOLE * 0.75, 0.75)
	# The sight port.
	_draw_port(cv, in_cut)
	# The placard.
	_draw_gate_placard(cv)
	# The OPEN lever.
	var down := in_cut or r11.gate_up() or lever_t > 0.0
	var lt := _tex("c_lever_down" if down else "c_lever_up")
	if lt:
		cv.draw_texture(lt, GATE_LEVER_AT)
	_centered(cv, "OPEN", Rect2(1240, 466, 140, 28), 22, Ink.PAPER)
	# A plate in her hand follows the pointer.
	if r11.held_plate != "" and not in_cut:
		var m := close.get_local_mouse_position()
		_draw_plate(cv, r11.held_plate, m - PLATE_HOLE, 1.0)

func _draw_flags(cv: CanvasItem) -> void:
	if flags_waiting:
		return
	var f := r11.flags_shown()
	var texts := [R11Sim.FLAG_P_TEXT.get(f.get("p", ""), ""), R11Sim.FLAG_L_TEXT.get(f.get("l", ""), "")]
	var drop := 0.0
	if flag_t < FLAG_DROP:
		drop = (1.0 - flag_t / FLAG_DROP) * -40.0
	for i in 2:
		var s: String = texts[i]
		if s == "":
			continue
		var r: Rect2 = FLAG_WINS[i]
		_centered(cv, s, Rect2(r.position + Vector2(0, drop), r.size), 30, Ink.INK)

## The sight port: shuttered; on a false landing the iris opens on port_false for 3 s
## (motion: a 0.3 s iris; still: at once), then closes; after P12, the real landing.
func _draw_port(cv: CanvasItem, in_cut: bool) -> void:
	var pr := Rect2(PORT_C - Vector2(PORT_R, PORT_R), Vector2(PORT_R, PORT_R) * 2.0)
	var shutter := _tex("c_port_shutter")
	if r11.port_view() == "true" and not in_cut:
		var pt := _tex("port_true")
		if pt:
			cv.draw_texture_rect(pt, pr, false)
		return
	var open_k := 0.0
	if port_t >= 0.0:
		var pf := _tex("port_false")
		if pf:
			cv.draw_texture_rect(pf, pr, false)
		if motion:
			open_k = clampf(port_t / IRIS, 0.0, 1.0) * clampf((PORT_SHOW - port_t) / IRIS, 0.0, 1.0)
		else:
			open_k = 1.0
	if shutter and open_k < 1.0:
		var s := 1.0 - open_k
		cv.draw_set_transform(PORT_C, open_k * 0.8, Vector2(s, s))
		cv.draw_texture(shutter, -shutter.get_size() / 2.0)
		cv.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_gate_placard(cv: CanvasItem) -> void:
	var r := PLACARD_IN
	var nf := narrow()
	var x := r.position.x
	var w := r.size.x
	_centered(cv, "PRESSURE GATE · DRY STAIR", Rect2(x, r.position.y, w, 26), 19, Ink.INK)
	cv.draw_line(Vector2(x + 6, r.position.y + 30), Vector2(r.end.x - 6, r.position.y + 30), Ink.STORM, 2.0)
	var y := r.position.y + 54.0
	y = Ink.wrapped(cv, "1. EQUALISE. Turn the wheel until the PRESSURE needle stands at the stair's target.",
		Vector2(x, y), 17, Ink.INK, w, true, nf)
	y = Ink.wrapped(cv, "2. SELECT A STABLE LANDING. Its marks must correspond across the boundary.",
		Vector2(x, y + 4), 17, Ink.INK, w, true, nf)
	# The worked example.
	var cx := r.get_center().x
	var ey := y + 30.0
	_centered(cv, "[ 7", Rect2(cx - 60, ey - 30, 120, 30), 30, Ink.INK)
	cv.draw_line(Vector2(x + 20, ey + 4), Vector2(r.end.x - 20, ey + 4), Ink.INK, 2.0)
	cv.draw_string(nf, Vector2(r.end.x - 66, ey - 1), "BOUNDARY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Ink.INK)
	_centered(cv, "] 7", Rect2(cx - 60, ey + 8, 120, 30), 30, Ink.INK)
	Ink.wrapped(cv, "3. PULL OPEN.", Vector2(x, ey + 72), 17, Ink.INK, w, true, nf)

## The P12 cut: the gate with its lever down, then the water standing in the gateway like
## glass and her hand going through it, then a fade to the lower landing.
func _draw_p12_cut(cv: CanvasItem) -> void:
	if cut_t < CUT_GATE:
		_draw_gate(cv, true)
		return
	if cut_t < CUT_GRILLE:
		_draw_grille_beat(cv)
		return
	_bg(cv, "cut_glass", Color("2b3d44"))
	var a := _tex("cut_hand_a")
	var b := _tex("cut_hand_b")
	var k := 1.0
	if motion:
		k = clampf((cut_t - CUT_HAND_AT) / CUT_HAND_FADE, 0.0, 1.0)
	if a and k < 1.0:
		cv.draw_texture(a, Vector2.ZERO, Color(1, 1, 1, 1.0 - k))
	if b and k > 0.0:
		cv.draw_texture(b, Vector2.ZERO, Color(1, 1, 1, k))

## How far the grille has gone up into the lintel in the cut's gateway beat, 0..1 (still: up).
func grille_rise() -> float:
	if not motion:
		return 1.0
	var k := clampf((cut_t - CUT_GRILLE_RISE[0]) / (CUT_GRILLE_RISE[1] - CUT_GRILLE_RISE[0]), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

## The P12 cut's second beat: the gateway itself, the bolts drawing (a shake) and the grille
## going up into the lintel, before the water stands up and her hand goes in.
func _draw_grille_beat(cv: CanvasItem) -> void:
	var shake := Vector2.ZERO
	if motion and cut_t >= CUT_GATE + 0.15 and cut_t < CUT_GATE + 0.45:
		shake = Vector2(0, 3.0 * sin(cut_t * 80.0))
	cv.draw_set_transform(CUT_ZOOM_AT + shake, 0.0, Vector2(CUT_ZOOM, CUT_ZOOM))
	_bg(cv, "L1_base", Color("54646a"))
	var n := r11.tide_lines()
	if n > 0 and _tex("L1_tide_%d" % n):
		cv.draw_texture(_tex("L1_tide_%d" % n), Vector2.ZERO)
	var pane := _tex("pane_slab")
	if pane:
		cv.draw_texture(pane, Vector2.ZERO)
	# From its line on, the water stands up behind the rising grille; the flat pane still
	# crosses it (Motion: eased in over SLAB_FADE; still: there at once).
	if cut_t >= SLAB_AT:
		var a := clampf((cut_t - SLAB_AT) / SLAB_FADE, 0.0, 1.0) if motion else 1.0
		_draw_water_slab(cv, a)
		if pane:
			cv.draw_texture_rect_region(pane, SLAB_BAND, SLAB_BAND)
	var g := _tex("L1_grille")
	var k := grille_rise()
	if g and k < 1.0:
		var d := k * 740.0
		var h := 896.0 - 160.0 - d
		if h > 0.0:
			cv.draw_texture_rect_region(g, Rect2(530, 160, 390, h), Rect2(530, 160 + d, 390, h))
	if k >= 1.0 and _tex("L1_grille_up"):
		cv.draw_texture(_tex("L1_grille_up"), Vector2.ZERO)
	# The gate's own marks at room scale, as on the landing.
	_draw_l1_gauge_on(cv)
	for i in 2:
		var pid: String = r11.state.slots[i]
		if pid != "":
			_draw_plate(cv, pid, L1_SLOTS[i].get_center() - PLATE_SIZE * 0.15, 0.3)
	var wt := _tex("c_wheel")
	if wt:
		cv.draw_set_transform(CUT_ZOOM_AT + shake + L1_HUB * CUT_ZOOM, deg_to_rad(60.0 * int(r11.state.pressure)),
			Vector2.ONE * 0.57 * CUT_ZOOM)
		cv.draw_texture(wt, -wt.get_size() / 2.0)
	cv.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- c_chamber_door ----------------------------------------------------------------------
## The lower door's close-up. `in_cut`: the P24 hold (lever down, the mounts empty).
func _draw_door(cv: CanvasItem, in_cut: bool) -> void:
	_bg(cv, "c_door", Color("54646a"))
	var nf := narrow()
	var hand := gsim() != null and gsim().selected_item != "" and not in_cut
	for f in R11Sim.FRAMES:
		var r: Rect2 = DOOR_FRAMES[f]
		var it := r11.frame_item(f)
		if it != "":
			_rec(cv, it, Rect2(r.position.x + 10, r.position.y + 14, 300, 220), true)
		if f == "NAME" and not in_cut:
			_draw_name_shutter(cv)
		# The frame's enamel label, over whatever is clipped in it.
		var lab := Rect2(205, r.position.y + 2, 130, 24)
		cv.draw_rect(lab, ENAMEL)
		cv.draw_rect(lab, Ink.INK, false, 2.0)
		_centered(cv, f, lab, 20, Ink.INK)
		var res: String = r11.frame_results.get(f, "")
		if res != "" and not r11.door_open():
			var tag := Rect2(r.position.x + 24, r.end.y - 50, 272, 30)
			cv.draw_rect(tag, ENAMEL)
			cv.draw_rect(tag, Ink.INK, false, 2.0)
			_centered(cv, res, tag, 19, Ink.INK)
		if hand:
			_highlight(cv, r)
	# The witness socket: its engraved hollow circle, the word, the bridge when seated.
	cv.draw_arc(SOCKET_C + Vector2(0, -66), 15.0, 0, TAU, 32, Ink.INK, 3.5)
	_centered(cv, "WITNESS", Rect2(SOCKET_C.x - 60, SOCKET_C.y + 46, 120, 26), 18, Ink.INK)
	if r11.witness_item() != "":
		_rec(cv, R11Sim.BRIDGE, Rect2(SOCKET_C - Vector2(90, 110), Vector2(180, 180)), false)
	if hand:
		_highlight(cv, Rect2(520, 200, 240, 240))
	# The COPY port: its stamp; the shutter snapped over anything in it, the thing peeking out.
	_centered(cv, "COPY · AUTOMATIC", COPY_STAMP, 16, Ink.INK)
	var cp := r11.copy_item()
	if cp == "" and not in_cut:
		var sm := _tex("c_copy_smear")
		if sm:
			cv.draw_texture(sm, Vector2(560, 590))
	if cp != "":
		var t := _tex(REC_TEX.get(cp, ""))
		if t:
			var sz := t.get_size()
			# It sticks out below the shutter's lower edge.
			cv.draw_texture_rect(t, Rect2(Vector2(568, 704), sz * 0.48), false)
		var cs := _tex("c_copy_shut")
		if cs:
			cv.draw_texture(cs, COPY_AT)
	if hand:
		_highlight(cv, Rect2(520, 560, 240, 240))
	# The preview strip and the door plate.
	var pv := r11.door_preview()
	if pv != "":
		Ink.wrapped(cv, pv, PREVIEW_IN.position + Vector2(10, 36), 26, Ink.INK, PREVIEW_IN.size.x - 20, true, nf)
	_draw_door_plate(cv)
	# The OPEN ACCESS lever.
	var down := in_cut or access_t > 0.0 or r11.door_open()
	var lt := _tex("c_access_down" if down else "c_access_up")
	if lt:
		cv.draw_texture(lt, ACCESS_AT)
	_centered(cv, "OPEN ACCESS", Rect2(1196, 868, 170, 30), 22, Ink.PAPER)

## The INDEX ACCESS plate: its title and the two ports' labels, nothing more. The door does not
## explain what a witness or a copy does; the plan's procedure and the witness test do.
func _draw_door_plate(cv: CanvasItem) -> void:
	var dp := DOOR_PLATE_IN
	_centered(cv, "INDEX ACCESS", Rect2(dp.position.x, dp.position.y, dp.size.x, 34), 30, Ink.INK)
	cv.draw_line(Vector2(dp.position.x + 8, dp.position.y + 44), Vector2(dp.end.x - 8, dp.position.y + 44), Ink.STORM, 2.0)
	var cx := dp.get_center().x
	# WITNESS, under its hollow circle (the socket's own mark).
	cv.draw_arc(Vector2(cx, dp.position.y + 120), 16.0, 0, TAU, 32, Ink.INK, 3.0)
	_centered(cv, "WITNESS", Rect2(dp.position.x, dp.position.y + 146, dp.size.x, 34), 28, Ink.INK)
	cv.draw_line(Vector2(dp.position.x + 40, dp.position.y + 214), Vector2(dp.end.x - 40, dp.position.y + 214), Color(Ink.STORM, 0.6), 1.5)
	_centered(cv, "COPY", Rect2(dp.position.x, dp.position.y + 244, dp.size.x, 34), 28, Ink.INK)

## The iron shutter over the NAME frame's glass, coming down from its top edge as shutter_k
## rises: its lower part shows first. Fully down it carries a stencilled CLOSED.
func _draw_name_shutter(cv: CanvasItem) -> void:
	if shutter_k <= 0.0:
		return
	var g := NAME_GLASS
	var h := g.size.y * shutter_k
	var t := _tex("c_name_shutter")
	if t:
		cv.draw_texture_rect_region(t, Rect2(g.position, Vector2(g.size.x, h)),
			Rect2(0, g.size.y - h, g.size.x, h))
	else:
		cv.draw_rect(Rect2(g.position, Vector2(g.size.x, h)), Ink.STORM)
		cv.draw_rect(Rect2(g.position, Vector2(g.size.x, h)), Ink.INK, false, 3.0)
	if shutter_k >= 1.0:
		var plate := Rect2(g.position.x + 70, g.position.y + 84, 160, 44)
		cv.draw_rect(plate, ENAMEL)
		cv.draw_rect(plate, Ink.INK, false, 2.0)
		_centered(cv, "CLOSED", plate, 30, Ink.INK)

func _highlight(cv: CanvasItem, r: Rect2) -> void:
	var pulse := 0.75 + 0.25 * sin(time * 3.0) if motion else 1.0
	cv.draw_rect(r.grow(8), Color(Ink.INK, 0.75), false, 9.0)
	cv.draw_rect(r.grow(8), Color(BRASS_HI, pulse), false, 4.5)
