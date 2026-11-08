class_name GameView
extends Node2D
## The one game scene: hosts the current room's view and everything shared by every room.
##
## Layering:
##   world (layer 0): the current room view (game/rooms/<rid>/<rid>_view.tscn). A room may
##                    add its own CanvasModulate, lights and CanvasLayers (close-ups at 5).
##   CanvasLayer 8 "over":  title, menu, notebook, end card (always fully readable)
##   CanvasLayer 9 "card":  the tide card that marks a tide change
##   CanvasLayer 10 "hud":  subtitles, HUD buttons, inventory bar, Back, hover names
##
## All story state lives in `sim` (GameSim). This node only presents it: the subtitle /
## typewriter / chain scheduler, one-shot sounds, saves, input routing. Everything timed
## here is presentation and is never saved. Lifted from the Intake Office slice view.

const SIZE := Vector2(1448, 1086)
const DEFAULT_SAVE_PATH := "user://ninth_tide_progress.json"
const SETTINGS_SUFFIX := ".settings.json"
const PREV_SUFFIX := ".prev.json"
const CHECKPOINT_SUFFIX := ".pre_ending.json"
## The slice's save: migrated once if no full-game save exists. Never deleted.
const SLICE_SAVE_PATH := "user://intake_office_v2.json"

const HUD_BUTTONS := [
	["notebook", Rect2(1112, 22, 150, 50), "Notebook"],
	["hint", Rect2(1272, 22, 86, 50), "Hint"],
	["menu", Rect2(1368, 22, 58, 50), "≡"],
]
## The Plan button (after P05), in its own slot under the Notebook: the notebook opened on
## the station plan. It shows in the room view only (never over a close-up; the notebook has
## its own Plan tab), clear of Back, the exits, every room hotspot and the inventory.
## (Rect2(1112, 80, 150, 40) under the Notebook was the first choice; R11's ceiling hotspot
## from Tide V reaches under it, so the Plan sits under Hint and the menu. The ceiling still
## reaches this slot too: a room bug for R11, tracked in core_test's PLAN_OVERLAP_KNOWN.)
const PLAN_BUTTON := ["plan", Rect2(1272, 80, 154, 40), "Plan"]
const PLAN_LABEL_SIZE := 18
## A Plan press this soon after a Back is the second half of a double click: ignored.
const PLAN_AFTER_BACK := 0.4
const HUD_ACTIONS := ["notebook", "hint", "menu", "plan"]
const BACK_RECT := Rect2(952, 22, 150, 50)
## Inventory slots run left to right along the top-left of the HUD.
const INV_ORIGIN := Vector2(20, 22)
const INV_SLOT := Vector2(140, 50)
const INV_GAP := 10.0
const INV_MAX := 6
## More items than slots: five items a page and a pager in the sixth slot.
const INV_PER_PAGE := 5
## The end card's buttons. New game is small, dim and out of the way, and takes two clicks:
## the first arms it (END_NEW_GAME_ARMED: the warning, wider), the second within RESTART_ARM
## starts over. Only then is the checkpoint at the final decision given up.
const END_BUTTONS := [["return_decision", Rect2(364, 990, 340, 66), "Return to final decision"],
	["new_game", Rect2(1188, 1010, 220, 50), "New game"]]
const END_NEW_GAME_ARMED := ["new_game", Rect2(788, 1010, 620, 50),
	"Start over? Your place at the final decision will be lost."]
const END_BUTTON_SIZE := 20
const NOTEBOOK_PAGE := Rect2(164, 90, 1120, 900)

const REVEAL_CPS := 14.0      # characters per second handwriting writes itself
const TYPE_CPS := 48.0        # subtitle typewriter
const LINE_LINGER := 4.0      # a line with nothing after it clears this long after its hold
const ADVANCE_SWALLOW := 0.35 # a click this soon after a story line went up is swallowed
const VOICE_CAP := 2          # live copies of one one-shot at most
const RESTART_ARM := 3.0      # seconds the menu's restart stays armed after the first click
const FEEDBACK_HOLD := 1.2    # a click's line stays up at least this long before the next replaces it
const BACKLOG_SQUEEZE := 0.6  # read-time factor for older story lines when a new reveal arrives
## (and for a reveal rushed by an exit or a hotspot click: see _rush_chain)
## An exit clicked mid-reveal rushes it, but its last this-many story lines keep their full
## read time (she reads the end of a reveal where it was said).
const EXIT_FULL_LAST := 2
const TIDE_CARD_TIME := 2.2
const TIDE_CARD_FADE := 0.5
const TIDE_CARD_STILL := 2.2  # Motion off: the card is simply there this long
const TIDE_CARD_QUIET := 1.0  # the card waits this long after the last story line's hold
## The card sits in the lower-left third of the room; the upper band when that would cover
## an exit tab or the glance. It never starts over a close-up, so it never covers a control.
const TIDE_CARD_RECT := Rect2(40, 840, 560, 110)
const TIDE_CARD_UPPER_RECT := Rect2(40, 110, 560, 110)
const TRAVEL_DEBOUNCE := 0.4  # an exit or plan click this soon after arriving is ignored
## An exit clicked while a reveal still has lines to say: the rest of it plays this far
## apart, and she goes this long after its last line went up (a second exit click: at once).
const EXIT_LINE_STEP := 0.6
## The glance: corner brackets that show where a commit's reward is (when the room has no
## glance of its own). Storm navy, on the HUD layer.
const GLANCE_TIME := 2.5
const GLANCE_EASE := 0.3
const GLANCE_FADE := 0.4      # the brackets fade out over the last this-many seconds (Motion on)
const GLANCE_ARM := 48.0
const GLANCE_THICK := 4.0
const GLANCE_BACKS := 4       # at most this many Backs to put a close-up down for a glance
## A hovered target taller than this (or any close-up control) puts its label above it.
const HOVER_TALL := 120.0
const HOVER_H := 34.0
const HOVER_SIZE := 20
const HOVER_MARGIN := 8.0
const HOVER_BAR_Y := 980.0    # last resort: the label sits in the row above the subtitles
const HOVER_GAP := 6.0        # between a label and the rect it names
## The HUD band (Back, Notebook, Hint, menu, inventory): no hover label rises into it.
const HUD_BAND_Y := 80.0
## The Hint's reply: a small paper card under the Hint button, never the subtitle queue. It
## stays up max(min_read + HINT_CARD_EXTRA, HINT_CARD_MIN) s, or until the next click.
const HINT_CARD_RIGHT := 1358.0
const HINT_CARD_TOP := 82.0
const HINT_CARD_MAX_W := 520.0
const HINT_CARD_SIZE := 20
const HINT_CARD_PAD := 14.0
const HINT_CARD_EXTRA := 1.5
const HINT_CARD_MIN := 3.0
const CARD_PAPER := Color("e8e0cc")
## The item in hand: a banner in the HUD band, left, on paper (never under the pointer).
const ARM_BANNER_POS := Vector2(24, 78)
const ARM_BANNER_SIZE := 18
## Inventory clicks this soon after the bar changed are ignored (a slot that just moved).
const INV_GUARD := 0.3
## Room bed trims (dB) on top of every bed loop's own gain: the loudness ladder that keeps
## the later rooms from reading quieter than the opening ones. Never on one-shots; faded out
## while hold_breath ducks the beds (LoopMixer.apply_duck).
const ROOM_TRIM_DB := {"R01": -3.0, "R02": -3.0, "R03": -2.0, "R04": 2.0, "R07": 2.0, "R10": 3.0,
	"R11": 4.0, "R12": 6.0}
## The plan row pulsed from the "Now: ... (Plan)" link pulses this long.
const PLAN_PULSE_TIME := 4.0
const NOW_PLAN_SUFFIX := " (Plan)"
## Actions a click always carries out, even while a story chain plays (the chain advances
## first). Room hotspots and close-up controls only advance a playing chain.
const ALWAYS_ACT_PREFIXES := ["go:"]
const ALWAYS_ACT_NOTEBOOK := ["tab:", "plan:", "nbpage:"]
const TRAVEL_DIP := 0.25      # storm-navy dip between rooms (Motion on)
const TRAVEL_DIP_COLOR := Color("1b2a36")
const MIXER_FADE := 0.4       # the old room's loops fade out this long after she leaves
const MIXER_FADE_RATE := 2.5
## The notebook's layouts, roomiest first. Past the last, the entries go on more pages.
const NB_LAYOUTS := [[22, 960, 1], [20, 960, 1], [18, 960, 1], [18, 460, 2], [17, 460, 2]]
const NB_INTRUSION_ROOM := 40.0
## hold_breath: every room bed ducks over BREATH_DUCK, holds, and comes back over
## BREATH_RESTORE. "Soften sudden sounds" ducks to BREATH_SOFT_DB instead of silence.
const BREATH_DUCK := 0.15
const BREATH_RESTORE := 1.2
const BREATH_SOFT_DB := -18.0
## The title: the P03 photograph (the lit office window at night, the figure at the desk),
## darkened under the text, drifting slowly with Motion on; the thin sea under it.
const TITLE_PLATE := "res://assets/stages/photo_drawer.png"
const TITLE_DARKEN := 0.45
const TITLE_DRIFT_PERIOD := 40.0
const TITLE_DRIFT_SCALE := 0.01
const TITLE_DRIFT_PX := Vector2(5, 3)   # |offset| <= 5.9 px
const TITLE_LOOP := "res://assets/audio/R01/sea_thin.wav"
const TITLE_LOOP_DB := -24.0

## Base levels for one-shots (dB) the core plays for itself; rooms add their own SFX_DB.
const SFX_DB := {"page": -10.0}

## echo_trace: the room sim's {type: "fx", id: "echo_trace", moves: [up to 3 MOVES ids]}. The
## core plays her last movements back at her, off to one side: for event i, at i * ECHO_GAP,
## two soft heel strikes (echo_step), then the movement's own sound ECHO_STEP_LEAD later.
## Core-owned WAVs (assets/audio/<id>.wav), at ECHO_DB, panned ECHO_PAN away from the way she
## came in. Soften sudden sounds: ECHO_SOFT_CUT lower, with an ECHO_SOFT_FADE fade-in. No
## caption goes up until the last sound plus ECHO_TAIL. Presentation only, never saved.
const ECHO_SFX := {"lamp_mended": "switch", "log_read": "page", "drawer_opened": "drawer",
	"recording_played": "dial", "charts_aligned": "page", "report_signed": "pen",
	"held_still": "breath", "turned_round": "seat", "zero_turned": "dial", "interval_set": "clunk",
	"hatch_opened": "latch_far", "stair_looked": "door"}
const ECHO_GAP := 1.8
const ECHO_STEP_LEAD := 0.6
const ECHO_STEP := "echo_step"
const ECHO_MAX := 3
const ECHO_DB := -10.0
const ECHO_SOFT_CUT := 6.0
const ECHO_SOFT_FADE := 0.03
const ECHO_PAN := 0.7
const ECHO_TAIL := 0.8
const ECHO_BUSES := {"left": "EchoLeft", "right": "EchoRight"}

## The Plan HUD button pulses once when the Now: objective moves PLAN_HUD_FAR or more rooms
## away on foot: a PLAN_HUD_SWELL brass rim swell, or (Motion off) a steady rim for
## PLAN_HUD_STILL. No text, no sound.
const PLAN_HUD_FAR := 3
const PLAN_HUD_SWELL := 1.2
const PLAN_HUD_STILL := 3.0

var save_path := DEFAULT_SAVE_PATH
## Tests and capture runs set this false so they never pick up the slice's real save.
var migrate_slice_save := true
var sim := GameSim.new()
var room_view: RoomView
var serif: Font
var hand: Font

# nodes
var world: Node2D
var over: Node2D
var card: Node2D
var hud: Node2D
var subtitle: Label

# presentation state (never saved)
var lines: Array = []          # queued {text, due, story, beat, click, hold}, sorted by due
var cur_text := ""
var cur_story := false
var cur_since := 0.0
var cur_hold := 0.0
var cur_click := 0
var line_t := 0.0
var hover_id := ""
var time := 0.0
var pending_sfx: Array = []    # [id, time_left, beat]
var oneshots: Array = []
var dev := false
var click_id := 0
var restart_armed_at := -INF
var new_game_armed_at := -INF  # the end card's New game, armed by its first click
var slab_a := 0.0
var shown_log: Array = []      # every line that went up, in order (tests and drivers read it)
var played_log: Array = []     # [sfx id, shown_log.size() when it played]
var last_events: Array = []
var intrusion_written := false
var intrusion_t := 0.0
var tide_card_t := 99.0
var tide_card_n := 0
var tide_card_pending := 0     # a tide card waiting for the reveal before it to finish
var tide_card_at := TIDE_CARD_RECT   # where the card on show sits (chosen as it starts)
var story_end := -INF          # when the last story line's hold ended (or ends)
var arrived_at := -INF         # when she last arrived in a room (travel debounce)
var pending_glance := {}       # a glance fx waiting for its chain to finish
var glance_t := 99.0
var glance_rect := Rect2()
var end_t := 0.0
var last_checkpoint := ""
var inv_page := 0              # the inventory page on show (presentation only)
var nb_page := -1              # the notebook page on show; -1 = the page with the newest entry
var nb_cache := {}             # notebook pagination, keyed by what it depends on
var came_from := ""            # the room she last travelled from (the placeholder's way back)
var travel_dip_t := 99.0
var fading_mixers: Array = []  # [LoopMixer, seconds left] the rooms she just left
## What the hover label was read against: [local view, item in hand, game view, chain playing].
## When any of it changes, the label goes; the frame after, it is read again under the pointer.
var hover_ctx: Array = []
var hover_recheck := false
var seen_inv_size := 0
var shown_rooms: Array = []    # the room each shown_log line went up in (tests read it)
## An exit clicked during a reveal: the action, sent once the reveal's last line has been up
## EXIT_LINE_STEP (a second exit click goes at once). "" = none.
var pending_travel := ""
## A room hotspot clicked while a story chain still had lines queued: sent when the chain ends.
var pending_action := ""
var last_back_at := -INF
var pending_fx: Array = []     # [fx event, time_left, beat]: fx with a delay, timed like sfx
var arrival_click := -1        # the click_id of the last travel (its arrival lines carry it)
var breath_start := -INF       # hold_breath: when the duck began (presentation only)
var breath_end := -INF         # ... and when the hold ends and the beds come back
var title_mixer: LoopMixer
var _title_tex: Texture2D
var hint_card := ""            # the Hint's reply on show (hint_card_text())
var hint_card_at := -INF
var hint_card_hold := 0.0
var hint_log: Array = []       # every hint reply shown, in order (tests and drivers read it)
var inv_shown: Array = []      # the bar as drawn: item ids, "" for a ghost slot (close-up)
var inv_sig := ""              # the inventory as last seen, to notice the bar changing
var inv_changed_at := -INF
var plan_pulse := ""           # the plan row the Now: link pulses
var plan_pulse_t := 99.0
## echo_trace (presentation only): [sfx id, seconds left, pan] waiting to play, every sound as
## scheduled ({id, at, db, pan}: tests read it), and when captions may go up again.
var pending_echo: Array = []
var echo_log: Array = []
var echo_hold_until := -INF
## The Plan HUD pulse: the objective room it last answered (never saved; "?" = not read yet),
## what that was read against, when the pulse began, and how many pulses there have been.
var plan_hud_obj := "?"
var plan_hud_key: Array = []
var plan_hud_t := 99.0
var plan_hud_pulses := 0

func _ready() -> void:
	serif = Ink.serif()
	hand = Ink.hand()
	_build_nodes()
	_build_audio()
	_build_title_audio()
	_load_progress()
	_mount_room()
	_redraw()

func _exit_tree() -> void:
	for p in oneshots:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
			p.queue_free()
	oneshots.clear()

# ---------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------
func _build_nodes() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	var over_layer := CanvasLayer.new()
	over_layer.layer = 8
	add_child(over_layer)
	over = Node2D.new()
	over_layer.add_child(over)
	over.draw.connect(_draw_over)
	var card_layer := CanvasLayer.new()
	card_layer.layer = 9
	add_child(card_layer)
	card = Node2D.new()
	card_layer.add_child(card)
	card.draw.connect(_draw_card)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Node2D.new()
	hud_layer.add_child(hud)
	hud.draw.connect(_draw_hud)
	subtitle = Label.new()
	subtitle.position = Vector2(48, 996)
	subtitle.size = Vector2(1352, 76)
	subtitle.add_theme_font_override("font", serif)
	subtitle.add_theme_font_size_override("font_size", 27)
	subtitle.add_theme_color_override("font_color", Ink.PAPER)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.visible_ratio = 1.0
	hud_layer.add_child(subtitle)

func _build_audio() -> void:
	_build_echo_buses()
	# One limiter on Master, however many times the scene is instanced.
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)

## Two buses for echo_trace, each panned ECHO_PAN to its side (made once per process).
static func _build_echo_buses() -> void:
	for side in ECHO_BUSES:
		var bus: String = ECHO_BUSES[side]
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")
		var pan := AudioEffectPanner.new()
		pan.pan = -ECHO_PAN if side == "left" else ECHO_PAN
		AudioServer.add_bus_effect(i, pan)

## The title's loop: the thin sea, on the core's own mixer (no music).
func _build_title_audio() -> void:
	title_mixer = LoopMixer.new()
	title_mixer.name = "TitleMixer"
	add_child(title_mixer)
	if ResourceLoader.exists(TITLE_LOOP):
		title_mixer.add_loop("sea", load(TITLE_LOOP))

## The title loop's target (linear): TITLE_LOOP_DB on the title (and its options menu), 0
## once the game has begun.
func title_loop_target() -> float:
	var on_title: bool = sim.view == "title" or (sim.view == "menu" and sim.return_view == "title")
	return db_to_linear(TITLE_LOOP_DB) if on_title else 0.0

func _tick_title_audio(dt: float) -> void:
	if title_mixer == null:
		return
	var target := title_loop_target()
	var targets := {"sea": target} if target > 0.0 else {}
	# Up from silence or down to it over MIXER_FADE.
	title_mixer.tick(targets, {}, dt, db_to_linear(TITLE_LOOP_DB) / MIXER_FADE)

## Shows the current room's view, replacing any other. A room without a view of its own
## gets the placeholder.
func _mount_room(travel := false) -> void:
	var rid: String = sim.state.room
	if room_view and is_instance_valid(room_view) and room_view.rid == rid:
		return
	if room_view and is_instance_valid(room_view):
		if travel:
			# The room she leaves keeps sounding for a moment, fading out, instead of cutting.
			for m in _mixers_in(room_view):
				m.carry_to(self)
				fading_mixers.append([m, MIXER_FADE])
		world.remove_child(room_view)
		room_view.queue_free()
	var path := "res://game/rooms/%s/%s_view.tscn" % [rid, rid]
	var v: RoomView
	if ResourceLoader.exists(path):
		v = load(path).instantiate()
	else:
		v = RoomView.new()
	v.game = self
	v.rid = rid
	v.sim = sim.room(rid)
	v.name = "Room" + rid
	world.add_child(v)
	room_view = v
	v.apply_instantly()
	if travel:
		# Arriving, the room's loops start from silence; its own tick() brings them up.
		for m in _mixers_in(v):
			m.snap({})
		if sim.settings.motion:
			travel_dip_t = 0.0

## Every LoopMixer under `n`.
static func _mixers_in(n: Node) -> Array:
	var out := []
	for ch in n.get_children():
		if ch is LoopMixer:
			out.append(ch)
		out.append_array(_mixers_in(ch))
	return out

func _tick_fading_mixers(dt: float) -> void:
	for i in range(fading_mixers.size() - 1, -1, -1):
		var m: LoopMixer = fading_mixers[i][0]
		fading_mixers[i][1] -= dt
		if not is_instance_valid(m):
			fading_mixers.remove_at(i)
			continue
		m.tick({}, {}, dt, MIXER_FADE_RATE)
		if fading_mixers[i][1] <= 0.0:
			fading_mixers.remove_at(i)
			m.queue_free()

## The current room's sim.
func room_sim() -> RoomSim:
	return sim.room()

# ---------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------
func _settings_path() -> String:
	return save_path.get_basename() + SETTINGS_SUFFIX

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return null
	return j.data

func _load_progress() -> void:
	sim.load_settings(_read_json(_settings_path()))
	var d = _read_json(save_path)
	var loaded := false
	if d != null:
		loaded = sim.from_dict(d)
	if not loaded:
		# The previous valid save, then (once) the slice's.
		d = _read_json(save_path.get_basename() + PREV_SUFFIX)
		if d != null:
			loaded = sim.from_dict(d)
	if not loaded and migrate_slice_save and save_path == DEFAULT_SAVE_PATH:
		d = _read_json(SLICE_SAVE_PATH)
		if d != null:
			loaded = sim.from_dict(d)
	if not loaded:
		sim.reset()
	var cp = _read_json(save_path.get_basename() + CHECKPOINT_SUFFIX)
	if cp is Dictionary:
		sim.checkpoint = cp
	if loaded and sim.state.started and sim.view == "room":
		var r := sim.room()
		_queue_line(r.c("RESUME", "Back.") + " " + sim.objective_text(), 0.3)

func _save_progress() -> void:
	var text := JSON.stringify(sim.to_dict())
	var old := FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else ""
	if old != "" and old != text:
		var prev := FileAccess.open(save_path.get_basename() + PREV_SUFFIX, FileAccess.WRITE)
		if prev:
			prev.store_string(old)
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(text)
	var s := FileAccess.open(_settings_path(), FileAccess.WRITE)
	if s:
		s.store_string(JSON.stringify(sim.settings_dict()))
	if not sim.checkpoint.is_empty():
		var cp := JSON.stringify(sim.checkpoint)
		if cp != last_checkpoint:
			last_checkpoint = cp
			var c := FileAccess.open(save_path.get_basename() + CHECKPOINT_SUFFIX, FileAccess.WRITE)
			if c:
				c.store_string(cp)

## Removes every file this scene writes for `path` (tests and capture runs).
static func remove_saves(path: String) -> void:
	for p in [path, path.get_basename() + SETTINGS_SUFFIX, path.get_basename() + PREV_SUFFIX,
			path.get_basename() + CHECKPOINT_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func _process(dt: float) -> void:
	time += dt
	if chain_paused():
		_hold_chain(dt)
	else:
		_tick_lines(dt)
		if cur_story and cur_text != "":
			story_end = cur_since + cur_hold
		_tick_sfx(dt)
		_tick_echo(dt)
		_tick_fx(dt)
		_tick_glance()
		_tick_pending()
	if room_view:
		room_view.tick(dt)
	_apply_trim()
	_tick_breath()
	_tick_title_audio(dt)
	if sim.view == "notebook" and _intrusion_writing():
		intrusion_t += dt
	if sim.view == "end":
		end_t += dt
	tide_card_t += dt
	glance_t += dt
	plan_pulse_t += dt
	plan_hud_t += dt
	_tick_plan_hud()
	_tick_tide_card()
	_tick_fading_mixers(dt)
	_refresh_hover_on_view_change()
	_keep_inv_page()
	if not sim.view in ["room"] or travel_dip_t < TRAVEL_DIP + dt:
		over.queue_redraw()
	travel_dip_t += dt
	if tide_card_t < TIDE_CARD_TIME + dt:
		card.queue_redraw()
	hud.queue_redraw()

## The pause menu over a game, and the notebook opened from the room: the story chain
## (lines, timed sounds and fx, hold_breath, a glance, a deferred exit or hotspot) waits under
## them, so nothing is said or played while she reads or the subtitles are hidden. The
## notebook's own clock (the stranger's line writing itself) keeps running.
func chain_paused() -> bool:
	if sim.view == "menu" and sim.return_view != "title":
		return true
	# A plan row clicked mid-reveal: the rest of it plays out (rushed) and she goes.
	return sim.view == "notebook" and sim.return_view == "room" and not pending_travel.begins_with("plan:")

## Holds the chain still for `dt`: every queued line and the one on screen keep their place,
## and so does every core timer keyed to them (timed sounds and fx simply don't count down).
func _hold_chain(dt: float) -> void:
	for l in lines:
		l.due += dt
	if cur_text != "":
		cur_since += dt
		# The line on screen finishes typing (it is not replaced, and its hold waits).
		line_t += dt
		subtitle.visible_characters = int(line_t * TYPE_CPS)
	story_end += dt
	echo_hold_until += dt
	if breath_end > time:
		breath_end += dt   # a held breath holds with its chain (the beds stay where they are)
		breath_start += dt

## The current room's bed trim (ROOM_TRIM_DB), linear.
func room_trim(rid: String) -> float:
	return db_to_linear(float(ROOM_TRIM_DB.get(rid, 0.0)))

## Sets every bed of the room on show to its room's trim (fading mixers keep the trim of the
## room they came from).
func _apply_trim() -> void:
	if room_view == null:
		return
	var k := room_trim(room_view.rid)
	for m in _mixers_in(room_view):
		if m.trim != k:
			m.trim = k
			m.apply_duck()

## The bed of the room on show as configured right now: the power sum of every loop's RMS
## (from its source WAV) times its target gain times the room trim, in dB. Also returns how
## many loops have a target above silence. {db, loops, live}. Tests read it.
func bed_loudness() -> Dictionary:
	var power := 0.0
	var live := 0
	var loops := 0
	if room_view:
		var k := room_trim(room_view.rid)
		for m in _mixers_in(room_view):
			for id in m.players:
				loops += 1
				var g: float = float(m.last_targets.get(id, 0.0))
				if g <= 0.0001:
					continue
				live += 1
				var a: float = m.source_rms(id) * g * k
				power += a * a
	return {"db": linear_to_db(sqrt(power)) if power > 0.0 else -INF, "loops": loops, "live": live}

## The reveal finishes before the tide card: a pending card starts only in the room view,
## with no close-up open, no story line queued or held, the arrival chain over, and the
## last of them readable for TIDE_CARD_QUIET.
func _tick_tide_card() -> void:
	if tide_card_pending > 0 and tide_card_may_start():
		_start_tide_card()

func tide_card_may_start() -> bool:
	if sim.view != "room" or room_sim() == null or room_sim().is_closeup() or pending_travel != "":
		return false
	if chain_active() or _story_queued() or time < story_end + TIDE_CARD_QUIET:
		return false
	for l in lines:
		if l.click == arrival_click:
			return false
	return not (cur_text != "" and cur_click == arrival_click and time < cur_since + cur_hold + TIDE_CARD_QUIET)

func _start_tide_card() -> void:
	tide_card_n = tide_card_pending
	tide_card_pending = 0
	tide_card_t = 0.0
	tide_card_at = _card_rect_now()
	card.queue_redraw()

## TIDE_CARD_RECT, or the upper band when the low one would cover an exit tab or the glance.
func _card_rect_now() -> Rect2:
	var avoid := []
	if glance_rect.size != Vector2.ZERO and glance_t < GLANCE_TIME:
		avoid.append(glance_rect)
	if room_view:
		avoid.append_array(room_view.live_exit_rects().values())
	for a in avoid:
		if TIDE_CARD_RECT.intersects(a):
			return TIDE_CARD_UPPER_RECT
	return TIDE_CARD_RECT

## True while a tide card is waiting or on screen (rooms that hold their own beat for it).
func tide_card_busy() -> bool:
	return tide_card_pending > 0 or tide_card_alpha() > 0.0

## A glance waits for its chain; then the close-up is put down (by the sim's own Back) and
## the room shows where the reward is, or the core brackets it.
func _tick_glance() -> void:
	if pending_glance.is_empty() or chain_active() or sim.view != "room" or room_sim() == null:
		return
	var tries := 0
	while room_sim().is_closeup() and tries < GLANCE_BACKS:
		dispatch("back")
		tries += 1
	var e := pending_glance
	pending_glance = {}
	var rect := glance_rect_of(e.get("rect"))
	if room_view == null or not room_view.start_glance(str(e.get("target", "")), rect):
		glance_rect = rect
		glance_t = 0.0

## A glance fx's rect: [x, y, w, h] (the sim's JSON-safe form) or a Rect2.
static func glance_rect_of(v: Variant) -> Rect2:
	if v is Rect2:
		return v
	if v is Array and v.size() == 4:
		return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return Rect2()

## 0..1: the core's glance brackets. Motion on they ease in over GLANCE_EASE and fade out
## over the last GLANCE_FADE; off, they are simply there for GLANCE_TIME. Travel, the
## notebook and a close-up opening clear them (_clear_glance).
func glance_alpha() -> float:
	if glance_rect.size == Vector2.ZERO or glance_t >= GLANCE_TIME:
		return 0.0
	if not sim.settings.motion:
		return 1.0
	return smoothstep(0.0, GLANCE_EASE, glance_t) * clampf((GLANCE_TIME - glance_t) / GLANCE_FADE, 0.0, 1.0)

## The hover label never outlives what it was read against (hover_context()): when the
## room's view, the item in hand, the game's view or the chain changes, the label is cleared
## that frame, and on the next frame read again under the pointer (when there is one), so a
## label from the view she left never hangs over the new one.
func _refresh_hover_on_view_change() -> void:
	var now := hover_context()
	if hover_recheck:
		hover_recheck = false
		if now == hover_ctx and has_pointer():
			hover_id = _hover_at(pointer_position())
	if now != hover_ctx:
		hover_ctx = now
		hover_id = ""
		hover_recheck = true

func hover_context() -> Array:
	return [room_sim().local_view if room_sim() else "", sim.selected_item, sim.view, chain_active()]

func _tick_sfx(dt: float) -> void:
	for i in range(pending_sfx.size() - 1, -1, -1):
		pending_sfx[i][1] -= dt
		var id: String = pending_sfx[i][0]
		if room_view:
			room_view.on_sfx_pending(id, pending_sfx[i][1])
		if pending_sfx[i][1] <= 0.0:
			pending_sfx.remove_at(i)
			_play_sfx_now(id)

## Timed fx (a room's `_fx(ev, id, {"delay": s})`), honoured like timed sounds: e.delay
## plus the chain offset, re-timed with their beat. Sounds due in the same frame land first.
func _tick_fx(dt: float) -> void:
	var due: Array = []
	for i in range(pending_fx.size() - 1, -1, -1):
		pending_fx[i][1] -= dt
		if pending_fx[i][1] <= 0.000001:
			due.push_front(pending_fx[i])
			pending_fx.remove_at(i)
	due.sort_custom(func(a, b): return a[1] < b[1])
	for p in due:
		_play_fx(_fx_now(p[0]), p[1], true)

## A timed fx as it is delivered: its delay spent (a view that times its own reveal from
## e.delay sees 0, as for an fx that came untimed).
static func _fx_now(e: Dictionary) -> Dictionary:
	var out := e.duplicate()
	out["delay"] = 0.0
	return out

## A deferred exit or room action, once its moment has come.
func _tick_pending() -> void:
	if pending_travel != "":
		# She goes once the rushed reveal's last line has had its hold.
		if not _story_queued() and (cur_text == "" or not cur_story or time - cur_since >= cur_hold - 0.000001):
			var a := pending_travel
			pending_travel = ""
			dispatch(a)
		return
	# A glance waiting for the same chain goes first (it may put a close-up down with Back).
	if pending_action != "" and not chain_active() and pending_glance.is_empty():
		var a := pending_action
		pending_action = ""
		if sim.view == "room":
			dispatch(a)

# ---------------------------------------------------------------------------
# hold_breath: the room's beds drop out for a moment (a sim fx, or a view's call)
# ---------------------------------------------------------------------------
## Ducks every live room bed, and every mixer still fading from the last room, to silence
## (Soften sudden sounds: BREATH_SOFT_DB) over BREATH_DUCK; holds until `seconds` after
## `at`; then brings them back to their targets over BREATH_RESTORE. One-shots still play.
## Overlapping holds run to the later end. Presentation only: never saved; travel, the
## title and the end card clear it.
func hold_breath(seconds: float, at := INF) -> void:
	var start: float = time if at == INF else at
	var k := breath_gain(start)
	if start >= breath_end:
		# Not holding: duck from wherever the beds are (1.0, or partway back up).
		breath_start = start - (1.0 - k) / maxf(1.0 - _breath_floor(), 0.0001) * BREATH_DUCK
	breath_end = maxf(breath_end, start + maxf(seconds, 0.0))

## The bed gain hold_breath leaves at time `t` (default now): 1.0 when no hold is on.
func breath_gain(t := INF) -> float:
	if t == INF:
		t = time
	if breath_end == -INF or t < breath_start:
		return 1.0
	var floor_k := _breath_floor()
	var span := 1.0 - floor_k
	var down := func(at: float) -> float:
		return clampf(1.0 - (at - breath_start) / BREATH_DUCK * span, floor_k, 1.0)
	if t < breath_end:
		return down.call(t)
	return minf(1.0, down.call(breath_end) + (t - breath_end) / BREATH_RESTORE * span)

func _breath_floor() -> float:
	return db_to_linear(BREATH_SOFT_DB) if sim.settings.soft_audio else 0.0

func _clear_breath() -> void:
	breath_start = -INF
	breath_end = -INF
	_apply_breath(1.0)

## The mixers a hold ducks: the room's beds and the ones still fading from the last room.
func bed_mixers() -> Array:
	var out: Array = _mixers_in(room_view) if room_view else []
	for f in fading_mixers:
		if is_instance_valid(f[0]):
			out.append(f[0])
	return out

func _tick_breath() -> void:
	if breath_end == -INF:
		return
	var k := breath_gain()
	_apply_breath(k)
	if k >= 1.0 and time >= breath_end:
		breath_start = -INF
		breath_end = -INF

func _apply_breath(k: float) -> void:
	for m in bed_mixers():
		if m.duck != k:
			m.duck = k
			m.apply_duck()

# ---------------------------------------------------------------------------
# subtitles: a scheduler keyed to absolute time
# ---------------------------------------------------------------------------
static func min_read(text: String) -> float:
	return 0.7 + 0.028 * text.length()

## A story line on screen can't be replaced by a click until it has been readable.
func _cur_protected() -> bool:
	return cur_story and cur_text != "" and time - cur_since < cur_hold

## Queued lines never cut off any line before its hold. A non-story line yields early: to
## a newer click's line after FEEDBACK_HOLD, and to a waiting story line once it has had
## the squeezed read time, so chatter never starves a reveal.
func _cur_readable(next: Dictionary = {}) -> bool:
	if cur_text == "":
		return true
	var hold := cur_hold
	if not cur_story:
		if int(next.get("click", 0)) > cur_click:
			hold = minf(hold, FEEDBACK_HOLD)
		elif next.get("story", false):
			hold = minf(hold, maxf(FEEDBACK_HOLD, min_read(cur_text) * BACKLOG_SQUEEZE))
	return time - cur_since >= hold

## When the story lines already queued (and a story line on screen) will have been read.
func _story_backlog_end() -> float:
	var t := time
	if cur_story and cur_text != "":
		t = maxf(t, cur_since + cur_hold)
	for l in lines:
		if l.story:
			t = maxf(t, l.due) + l.hold
	return t

## A new scene's reveal is arriving: everything older still waiting is re-timed back to
## back from now at BACKLOG_SQUEEZE of its read time. Returns when the squeezed backlog ends.
func _squeeze_backlog() -> float:
	var t := time
	if cur_story and cur_text != "":
		cur_hold = minf(cur_hold, min_read(cur_text) * BACKLOG_SQUEEZE)
		t = maxf(t, cur_since + cur_hold)
	for l in lines:
		if l.story:
			l.hold = min_read(l.text) * BACKLOG_SQUEEZE
			l.due = t
			t += l.hold
	return t

func _tick_lines(dt: float) -> void:
	if not lines.is_empty() and lines[0].due <= time and time >= echo_hold_until and _cur_readable(lines[0]):
		var head: Dictionary = lines.pop_front()
		_show_line(head.text, head.story, head.hold, head.click)
	if cur_text != "":
		line_t += dt
		subtitle.visible_characters = int(line_t * TYPE_CPS)
		if lines.is_empty() and time - cur_since > cur_hold + LINE_LINGER:
			cur_text = ""
			cur_story = false
			subtitle.text = ""
	# The slab is up only while something is said (or about to be): an empty slab never waits
	# for a line that is seconds away.
	if cur_text == "" and not _line_due_within(0.2):
		slab_a = maxf(0.0, slab_a - dt / 0.4)
	else:
		slab_a = minf(1.0, slab_a + dt / 0.15)

func _line_due_within(s: float) -> bool:
	return not lines.is_empty() and lines[0].due - time <= s

## A story line is still waiting its turn (more of a chain than the line on screen).
func _story_queued() -> bool:
	for l in lines:
		if l.story:
			return true
	return false

## An exit clicked while a reveal still has lines queued: the rest of it plays now, rushed
## (_rush_chain), its last EXIT_FULL_LAST lines at their full read time; _tick_pending sends
## `action` once the last line has had its hold.
func _defer_travel(action: String) -> void:
	pending_travel = action
	_rush_chain(EXIT_FULL_LAST)

## A rushed line's hold: its squeezed read time (never under EXIT_LINE_STEP), or its full
## read time.
static func rush_hold(text: String, full := false) -> float:
	return min_read(text) if full else maxf(EXIT_LINE_STEP, min_read(text) * BACKLOG_SQUEEZE)

## The rest of a playing chain, back to back from the line on screen: each line held
## rush_hold(), the last `keep_full` story lines (the one on screen counted) at their full
## read time. Chatter waiting behind it stays behind. Its beat's timed sounds and fx move with
## their lines. Nothing is dropped and nothing is said out of order.
func _rush_chain(keep_full := 0) -> void:
	lines = lines.filter(func(l): return l.story)
	var on_screen: bool = cur_story and cur_text != ""
	var n: int = lines.size() + (1 if on_screen else 0)
	var i := 0
	var t := time
	if on_screen:
		cur_hold = minf(cur_hold, rush_hold(cur_text, n - 1 < keep_full))
		t = cur_since + cur_hold
		i = 1
	elif cur_text != "":
		# A feedback line yields to the chain after its squeezed read time (_cur_readable).
		t = cur_since + minf(cur_hold, maxf(FEEDBACK_HOLD, min_read(cur_text) * BACKLOG_SQUEEZE))
	var shifts: Array = []   # [old due, new due, beat] per line, in order
	for l in lines:
		l.hold = rush_hold(l.text, n - 1 - i < keep_full)
		var due := maxf(t, time)
		shifts.append([l.due, due, l.beat])
		l.due = due
		t = due + l.hold
		i += 1
	for queue in [pending_sfx, pending_fx]:
		for p in queue:
			var shift := _beat_shift(shifts, p[2], time + p[1])
			p[1] = maxf(0.0, p[1] + shift)

## How far the line a timed event leads into (its beat's first line due at or after `at`,
## else the beat's last line) moved. 0 when the beat has no re-timed line.
static func _beat_shift(shifts: Array, beat: int, at: float) -> float:
	var last := 0.0
	if beat == 0:
		return 0.0
	for s in shifts:
		if s[2] != beat:
			continue
		last = s[1] - s[0]
		if s[0] >= at - 0.05:
			return last
	return last

## A story chain is playing: a line of it is queued, or one is on screen and still held.
func chain_active() -> bool:
	for l in lines:
		if l.story:
			return true
	return cur_story and cur_text != "" and time - cur_since < cur_hold

## The player sets the chain's speed: bring its next line up now, with its own sounds.
func advance() -> void:
	if cur_story and cur_text != "" and time - cur_since < ADVANCE_SWALLOW:
		return   # a double click doesn't skip a line unread
	if time < echo_hold_until:
		return   # her own steps are still sounding: nothing is said over them
	var next: Dictionary = {}
	for l in lines:
		if l.story:
			next = l
			break
	if next.is_empty():
		# Only the last line is left on screen: release it, so the next click is a click.
		if cur_story and cur_text != "":
			cur_hold = minf(cur_hold, time - cur_since)
		return
	var delta := maxf(0.0, next.due - time)
	for l in lines:
		l.due -= delta
	for p in pending_fx:
		if next.beat != 0 and p[2] == next.beat:
			p[1] -= delta
	var due_now: Array = []
	for i in range(pending_sfx.size() - 1, -1, -1):
		var p: Array = pending_sfx[i]
		if next.beat != 0 and p[2] == next.beat:
			p[1] -= delta
		if room_view:
			room_view.on_sfx_pending(p[0], p[1])
		if p[1] <= 0.0:
			due_now.append(p)
			pending_sfx.remove_at(i)
	# The sounds a line waits for land before it does.
	due_now.sort_custom(func(a, b): return a[1] < b[1])
	for p in due_now:
		_play_sfx_now(p[0])
	lines.erase(next)
	_show_line(next.text, true, next.hold, next.click)

## A click (or tap) at `p`, exactly as the mouse handler does it. Drivers and tests use it.
## Clicks are never eaten: the HUD always answers, and Back, the inventory, every control of
## an open close-up, and the notebook's tabs and pages always act (a playing chain advances
## first, in the same press; anything the action says waits after the chain).
##   - An exit (or a plan row) while a reveal still has lines queued: the rest of the reveal
##     plays out quickly where it was said, then she goes (pending_travel); a second exit
##     click goes at once. With only the line on screen left, she goes at once.
##   - A room hotspot while a chain plays: with only the line on screen left, that line is
##     finished and the hotspot acts in the same press; with more queued, the chain advances
##     and the hotspot acts when the chain ends (pending_action).
##   - Empty space and the subtitle bar only advance a chain.
## The room sees its click first (consume_click: skipping its own hold, R02's photograph).
func click(p: Vector2) -> void:
	_dismiss_hint_card()   # the next click anywhere puts the Hint's card away
	var a := _core_action_at(p)
	if a == "" and _room_takes_click():
		if room_view.consume_click(p):
			return
		a = room_view.action_at(p)
	if a in HUD_ACTIONS:
		if not _cinematic():
			_hud_press(a)
		return
	if a.begins_with("item:") or a == "inv_page":
		# The bar acts on the press itself: a playing chain is neither advanced nor waited on.
		if time - inv_changed_at < INV_GUARD:
			return   # the slot under the pointer just moved
		if not _local_action(a):
			dispatch(a)
		return
	if is_exit_action(a):
		if time - arrived_at < TRAVEL_DEBOUNCE:
			return   # a double click on an exit moves one room, not two
		if pending_travel != "":
			pending_travel = ""
			dispatch(a)   # the second click: at once (travel drops what the old room had left)
			return
		if _chain_gates() and _story_queued():
			_defer_travel(a)
			return
		if _chain_gates() and chain_active():
			advance()
		dispatch(a)
		return
	if is_nav_action(a):
		# A step inside the room (to the kitchen, round to the other wall): like an exit, it
		# rushes a reveal still queued and goes when it ends; a second click goes at once.
		if a == pending_action:
			pending_action = ""
			dispatch(a)
			return
		if _chain_gates() and _story_queued():
			pending_action = a
			_rush_chain()
			return
		if _chain_gates() and chain_active():
			advance()
		pending_action = ""
		dispatch(a)
		return
	if always_acts(a) or _closeup_acts(a):
		if _chain_gates() and chain_active():
			advance()
		if not _local_action(a):
			dispatch(a)
		return
	if _local_action(a):
		return
	if _chain_gates() and chain_active():
		if a == "" or SUBTITLE_BAR.has_point(p):
			advance()
			return
		if a == pending_action:
			# The second click on a waiting hotspot: at once. What it says follows the rest of
			# the chain, which still plays out in full.
			pending_action = ""
			dispatch(a)
			return
		if _story_queued():
			# The rest of the chain is rushed where it was said; the hotspot shows pressed and
			# acts when it ends (a later hotspot click replaces it).
			pending_action = a
			_rush_chain()
			return
		advance()
		pending_action = ""
		dispatch(a)   # the line on screen is finished: the hotspot acts in the same press
		return
	if a != "":
		pending_action = ""
		dispatch(a)

## The subtitle slab: a click here only ever advances a chain.
const SUBTITLE_BAR := Rect2(20, 994, 1408, 80)

## An exit tab ("go:<rid>") or a notebook plan row ("plan:<rid>"): an action that travels.
static func is_exit_action(a: String) -> bool:
	return a.begins_with("go:") or a.begins_with("plan:")

## An in-room move between the room's own views: "to_<view>", a turn to another wall, and
## any id the room view lists in NAV_ACTIONS.
func is_nav_action(a: String) -> bool:
	if a == "":
		return false
	if a.begins_with("to_") or a in ["turn", "wall_left", "wall_right"]:
		return true
	return room_view != null and a in room_view.c("NAV_ACTIONS", [])

## True for the actions a click always carries out, even during a story chain: exits,
## Back, the inventory, and in the notebook its tabs, plan rows and page turners.
func always_acts(a: String) -> bool:
	if a == "back" or a == "inv_page":
		return true
	for pre in ALWAYS_ACT_PREFIXES:
		if a.begins_with(pre):
			return true
	if sim.view == "notebook":
		for pre in ALWAYS_ACT_NOTEBOOK:
			if a.begins_with(pre):
				return true
	return false

## A room action on an open close-up's control: it acts in the press that advances a chain.
func _closeup_acts(a: String) -> bool:
	return a != "" and not a in HUD_ACTIONS and sim.view == "room" and room_sim() != null \
		and room_sim().is_closeup()

## A HUD button: the Plan opens the notebook straight on the station plan.
func _hud_press(a: String) -> void:
	if a != "plan":
		dispatch(a)
		return
	if not plan_button_shown() or time - last_back_at < PLAN_AFTER_BACK:
		return
	if sim.view != "notebook":
		dispatch("notebook")
	dispatch("tab:plan")

## A full-screen room moment (an interlude card): no notebook, hint or menu from the HUD.
func _cinematic() -> bool:
	return sim.view == "room" and room_view != null and room_view.hud_hidden()

## Presentation-only controls (inventory and notebook pages): never sent to the sim.
func _local_action(a: String) -> bool:
	match a:
		"inv_page":
			var pages := _inv_pages()
			inv_page = (_inv_page_shown() + 1) % pages
		"nbpage:prev", "nbpage:next":
			var info := _nb_pagination(_nb_page())
			var n: int = info.pages.size()
			var cur: int = info.shown
			nb_page = clampi(cur + (1 if a == "nbpage:next" else -1), 0, n - 1)
		"nbnow:plan":
			# "Now: ... (Plan)": the plan, with the row that leads there pulsing.
			dispatch("tab:plan")
			plan_pulse = plan_pulse_target()
			plan_pulse_t = 0.0
		_:
			return false
	_redraw()
	return true

## Views where a playing chain holds clicks. The title, end card and menu show no
## subtitles; a room may exempt its own views (the threshold has its own clock).
func _chain_gates() -> bool:
	if sim.view in ["title", "end", "menu"]:
		return false
	return room_view == null or sim.view != "room" or room_view.chain_gates()

func _show_line(text: String, story: bool, hold := -1.0, from_click := -1) -> void:
	if cur_story and cur_text != "":
		story_end = cur_since + minf(cur_hold, time - cur_since)   # the story line it replaces
	cur_text = text
	cur_story = story
	cur_click = click_id if from_click < 0 else from_click
	cur_since = time
	cur_hold = min_read(text) if hold < 0.0 else hold
	line_t = 0.0
	if story:
		story_end = cur_since + cur_hold
	subtitle.text = text
	shown_log.append(text)
	shown_rooms.append(sim.state.room)
	subtitle.add_theme_font_size_override("font_size", 24 if text.length() > 90 else 27)
	subtitle.visible_characters = 0

## Inserts a line due at absolute time `due`, after any line due no later.
func _insert_line(text: String, due: float, story: bool, beat := 0) -> void:
	var i := lines.size()
	while i > 0 and lines[i - 1].due > due:
		i -= 1
	lines.insert(i, _line(text, due, story, beat))

func _line(text: String, due: float, story: bool, beat: int) -> Dictionary:
	return {"text": text, "due": due, "story": story, "beat": beat, "click": click_id,
		"hold": min_read(text)}

func _queue_line(text: String, delay := 0.0, story := false) -> void:
	_insert_line(text, time + delay, story)

## A click's immediate line. Drops older clicks' chatter (never a story line, never this
## click's own lines). If a story line is still being read, or the last click's line has
## been up for less than FEEDBACK_HOLD, the new line goes to the front of the queue.
func _say_now(text: String, story: bool) -> void:
	lines = lines.filter(func(l): return l.story or l.click == click_id)
	var due := -1.0
	if time < echo_hold_until:
		due = echo_hold_until
	elif _cur_protected():
		due = time
	elif not cur_story and cur_text != "" and time - cur_since < FEEDBACK_HOLD:
		due = cur_since + FEEDBACK_HOLD
	if due < 0.0:
		_show_line(text, story)
	elif story:
		_insert_line(text, due, story)
	else:
		lines.insert(0, _line(text, due, story, 0))

# ---------------------------------------------------------------------------
# events
# ---------------------------------------------------------------------------
func dispatch(action: String) -> void:
	if action == "restart_arm":
		# The menu's restart takes two clicks: the first only asks.
		restart_armed_at = time
		_redraw()
		return
	if action == "new_game_arm":
		# So does the end card's New game: the first click only warns.
		new_game_armed_at = time
		_redraw()
		return
	if action == "new_game":
		new_game_armed_at = -INF
	click_id += 1
	if action == "back":
		last_back_at = time
	var before_game := sim.view
	var before_rid: String = sim.state.room
	var before_room := room_sim().view if room_sim() else ""
	var before_local := room_sim().local_view if room_sim() else ""
	var chain_was := chain_active()
	var before_tab := sim.nb_tab
	var before_closeup: bool = room_sim() != null and room_sim().is_closeup()
	var ev := sim.dispatch(action)
	last_events = ev
	if action == "hint":
		ev = _hint_to_card(ev)
	if before_game != sim.view and "end" in [before_game, sim.view]:
		# Into or out of the end card: nothing still queued or on screen carries across it.
		lines.clear()
		cur_text = ""
		cur_story = false
		subtitle.text = ""
		chain_was = false
	play_events(ev, chain_was)
	_mount_room()
	var after_room := room_sim().view if room_sim() else ""
	if before_room != after_room or before_game != sim.view:
		hover_id = ""   # the label of what she was pointing at stays with the view she left
		_on_view_changed(before_game, before_room)
		var closeup_now: bool = room_sim() != null and room_sim().is_closeup()
		if (sim.view == "notebook" and before_game != "notebook") or (closeup_now and before_room != after_room):
			_clear_glance()   # no bracket outlives the room view it pointed into
	# The notebook or menu over the room (and Back from it) only pauses the chain: what
	# waits for it, waits on.
	var pause_hop: bool = before_rid == sim.state.room and room_sim() != null and before_local == room_sim().local_view and (
		(before_game == "room" and chain_paused()) or (sim.view == "room" and before_game in ["notebook", "menu"]))
	if not pause_hop and (before_room != after_room or before_game != sim.view or before_rid != sim.state.room):
		pending_action = ""   # a deferred hotspot belongs to the view it was clicked in
	if not pause_hop and before_game != sim.view and sim.view in ["notebook", "menu", "end", "title"]:
		pending_travel = ""
	if sim.nb_tab != before_tab:
		nb_page = -1
	if action.begins_with("item:") and sim.selected_item != "":
		_show_item_page(sim.selected_item)   # the page that holds what's in her hand
	_note_inv_change()
	if sim.view == "title":
		_reset_presentation()
	_save_progress()
	_redraw()

## The Hint's say events go to the hint card (hint_card_text()), never the subtitle queue;
## the rest of the events are returned to be played.
func _hint_to_card(ev: Array) -> Array:
	var said := []
	var rest := []
	for e in ev:
		if e.type == "say":
			said.append(str(e.text))
		else:
			rest.append(e)
	if not said.is_empty():
		show_hint_card(" ".join(said))
	return rest

## Puts `text` on the hint card at once, replacing any card on show.
func show_hint_card(text: String) -> void:
	hint_card = text
	hint_card_at = time
	hint_card_hold = maxf(min_read(text) + HINT_CARD_EXTRA, HINT_CARD_MIN)
	hint_log.append(text)

## The hint card's text while it is up, else "".
func hint_card_text() -> String:
	if hint_card == "" or time - hint_card_at >= hint_card_hold:
		return ""
	return hint_card

func _dismiss_hint_card() -> void:
	hint_card = ""

func _clear_glance() -> void:
	glance_t = 99.0
	glance_rect = Rect2()

## The inventory changed (a use, a gift, a filing): inventory clicks wait INV_GUARD.
func _note_inv_change() -> void:
	var sig := ",".join(sim.state.inventory)
	if sig != inv_sig:
		inv_sig = sig
		inv_changed_at = time

## Plays a list of sim events. Story chains are atomic: anything that arrives while one
## plays (a Hint, a key) waits after it, whole and in order, with its timed sounds.
func play_events(ev: Array, chain_was := false) -> void:
	if not ev.is_empty():
		# A new click's events: chatter an earlier click queued and never said is stale now
		# (story lines are never dropped; the line on screen is replaced as ever).
		lines = lines.filter(func(l): return l.story or l.click == click_id)
	var beat := false
	for e in ev:
		if e.type == "say" and e.get("story", false) and e.delay > 0.0:
			beat = true
		if e.type == "fx" and e.id == "travel":
			# A new room: nothing of the old one is said after she arrives. Its notes are
			# already in the notebook; its arrival line is the first thing on screen.
			_clear_for_travel()
			chain_was = false
	# An echo_trace first, so its caption hold covers every line in the same list.
	for e in ev:
		if e.type == "fx" and e.id == "echo_trace":
			_play_fx(e)
	var offset := 0.0
	if chain_was:
		offset = maxf(0.0, _story_backlog_end() - time)
	elif beat:
		lines = lines.filter(func(l): return l.story)   # older chatter gives way to a reveal
	var beat_id := click_id if beat else 0
	var spoke_now := false
	card_offered = false
	for e in ev:
		match e.type:
			"say":
				var story: bool = e.get("story", false)
				if e.delay <= 0.0 and not spoke_now and offset <= 0.0:
					spoke_now = true
					_say_now(e.text, story)
				else:
					_insert_line(e.text, time + offset + e.delay, story, beat_id)
			"sfx":
				if e.delay > 0.0:
					pending_sfx.append([e.id, e.delay + offset, beat_id])
				else:
					_play_sfx_now(e.id)
			"fx":
				if e.id == "echo_trace":
					continue   # started above
				var d := float(e.get("delay", 0.0))
				if d > 0.0 and fx_timed_by_core(str(e.id)):
					pending_fx.append([e, d + offset, beat_id])
					if str(e.id) in CORE_TIMED_FX and room_view:
						# The room still hears it as the sim said it (delay intact), for a view
						# whose own stillness keys off the same beat (R08, R09, R12).
						room_view.play_fx(e.id, e)
				else:
					_play_fx(e)
	_settle_card_offer()

## Fx ids the core itself times by their delay (beyond any the room view lists in TIMED_FX).
const CORE_TIMED_FX := ["hold_breath"]

## True when an fx with a delay waits for it in the core: the core's own timed fx, and the
## ids the room view lists in its TIMED_FX (["*"] for all). Any other fx is delivered at once
## with its delay intact, for a view that times its own reveal from e.delay (R10).
func fx_timed_by_core(id: String) -> bool:
	if id in CORE_TIMED_FX:
		return true
	var timed: Array = room_view.c("TIMED_FX", []) if room_view else []
	return id in timed or "*" in timed

## Leaving a room: every line, queued or on screen, every timed sound and fx, any deferred
## exit or hotspot and any held breath stay behind.
func _clear_for_travel() -> void:
	lines.clear()
	cur_text = ""
	cur_story = false
	cur_hold = 0.0
	subtitle.text = ""
	pending_sfx.clear()
	pending_fx.clear()
	pending_travel = ""
	pending_action = ""
	_clear_echo()
	_clear_breath()

## While one event list plays, a new tide card is offered to the room as "just started"
## (tide_card_t = 0): a room view that times the card to its own beat takes it over from its
## play_fx by setting tide_card_t to 99 and releasing it later (R01's withdrawal). After the
## list, a card no room took goes back to waiting for the reveal.
var card_offered := false

func _settle_card_offer() -> void:
	if not card_offered:
		return
	card_offered = false
	if tide_card_pending <= 0:
		return   # it started already (she travelled)
	if tide_card_t >= 99.0:
		tide_card_pending = 0   # the room holds it
	else:
		tide_card_t = 99.0
## `late` (<= 0): how far past its moment a timed fx is delivered (hold_breath backdates).
func _play_fx(e: Dictionary, late := 0.0, from_queue := false) -> void:
	match e.id:
		"travel":
			# A new room (play_events has already cleared the old room's lines and sounds).
			hover_id = ""
			arrived_at = time
			arrival_click = click_id
			pending_glance = {}
			_clear_glance()
			came_from = str(e.get("from", ""))
			_mount_room(e.get("from", "") != "")
			# A tide card still waiting keeps waiting: for the arrival chain to end.
		"hold_breath":
			hold_breath(float(e.get("seconds", 0.0)), time + minf(late, 0.0))
			if not from_queue and room_view:
				room_view.play_fx(e.id, e)   # untimed: the room hears it now, too
		"tide":
			# The card waits for the reveal that earned it (_tick_tide_card), after the room
			# has had the chance to take it over (_settle_card_offer).
			tide_card_pending = int(e.get("tide", sim.tide()))
			tide_card_n = tide_card_pending
			tide_card_t = 0.0
			card_offered = true
		"glance":
			pending_glance = e.duplicate()
		"echo_trace":
			start_echo(e.get("moves", []), maxf(0.0, float(e.get("delay", 0.0))) if not from_queue else 0.0)
		"item_added":
			_show_item_page(str(e.get("item", "")))
		_:
			if room_view:
				room_view.play_fx(e.id, e)

func _on_view_changed(before_game: String, before_room: String) -> void:
	var before := before_room
	if before_game != "room":
		before = before_game
	if before == "notebook" and room_sim() and room_sim().notebook_intrusion() != "":
		intrusion_written = true
	if sim.view == "notebook":
		intrusion_t = 0.0
		nb_page = -1
	if sim.view == "end":
		end_t = 0.0
	if sim.view in ["end", "title"]:
		_clear_breath()
	if room_view:
		room_view.on_view_changed(before)

## Dev/capture/tests: put the game at room `rid`'s local stage `n` (the room's own
## debug_jump), with clean presentation.
func room_jump(rid: String, n: int) -> void:
	var r: RoomSim = sim.room(rid)
	if r and r.has_method("debug_jump"):
		r.debug_jump(n)
	else:
		sim.reset()
		sim.debug_enter(rid)
	_mount_room()
	_reset_presentation()
	_save_progress()
	_redraw()

## Dev/capture/tests: the start of tide `t`, standing in `rid` (default the office).
func tide_jump(t: int, rid := "") -> void:
	sim.debug_tide(t, rid)
	_mount_room()
	_reset_presentation()
	_save_progress()
	_redraw()

## Dev/capture: go to `rid` ignoring gates, keeping progress.
func enter_jump(rid: String) -> void:
	sim.debug_enter(rid)
	_mount_room()
	_reset_presentation()
	_redraw()

## Clears everything timed so a restart or jump can't inherit old lines or sounds.
func _reset_presentation() -> void:
	lines.clear()
	cur_text = ""
	cur_story = false
	cur_hold = 0.0
	line_t = 0.0
	subtitle.text = ""
	shown_log.clear()
	played_log.clear()
	restart_armed_at = -INF
	new_game_armed_at = -INF
	pending_sfx.clear()
	pending_fx.clear()
	pending_travel = ""
	pending_action = ""
	shown_rooms.clear()
	_clear_echo()
	echo_log.clear()
	plan_hud_t = 99.0
	_clear_breath()
	for p in oneshots:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	oneshots.clear()
	intrusion_written = false
	intrusion_t = 0.0
	tide_card_t = 99.0
	tide_card_pending = 0
	tide_card_at = TIDE_CARD_RECT
	story_end = -INF
	arrived_at = -INF
	pending_glance = {}
	_clear_glance()
	end_t = 0.0
	travel_dip_t = 99.0
	inv_page = 0
	hint_card = ""
	hint_log.clear()
	inv_sig = ",".join(sim.state.inventory)
	inv_changed_at = -INF
	plan_pulse = ""
	plan_pulse_t = 99.0
	nb_page = -1
	_mount_room()
	if room_view:
		room_view.reset_presentation()
		room_view.apply_instantly()

## The level a one-shot plays at, after the "Soften sudden sounds" cut. Rooms list their
## own levels (SFX_DB) and which sounds are sudden (SFX_SOFT) in their view.
func sfx_db(id: String) -> float:
	var table: Dictionary = room_view.c("SFX_DB", {}) if room_view else {}
	var db: float = table.get(id, SFX_DB.get(id, -6.0))
	if sim.settings.soft_audio and room_view and id in room_view.c("SFX_SOFT", []):
		var cut: Dictionary = room_view.c("SFX_SOFT_CUT", {})
		db -= cut.get(id, 12.0)
	return db

func _play_sfx_now(id: String) -> void:
	played_log.append([id, shown_log.size()])
	if room_view:
		room_view.on_sfx(id)
	var stream := load_audio(id)
	if stream == null:
		return
	# Voice cap: rapid repeats (pages, dials) never pile up more than VOICE_CAP copies.
	var same: Array = oneshots.filter(func(o): return is_instance_valid(o) and o.get_meta("sfx_id", "") == id)
	if same.size() >= VOICE_CAP:
		var oldest: AudioStreamPlayer = same[0]
		oneshots.erase(oldest)
		oldest.stop()
		oldest.queue_free()
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.set_meta("sfx_id", id)
	p.volume_db = sfx_db(id)
	if room_view:
		p.bus = room_view.sfx_bus(id)
	add_child(p)
	oneshots.append(p)
	p.finished.connect(func():
		oneshots.erase(p)
		p.queue_free())
	p.play()

## A sound by id: the current room's own (assets/audio/<rid>/<id>.wav) first, then the
## shared set (assets/audio/<id>.wav). Missing files are skipped silently.
func load_audio(id: String) -> AudioStream:
	for path in ["res://assets/audio/%s/%s.wav" % [sim.state.room, id], "res://assets/audio/%s.wav" % id]:
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null

## True while a live one-shot is playing one of `ids`.
func oneshot_playing(ids: Array) -> bool:
	for p in oneshots:
		if is_instance_valid(p) and p.playing and p.get_meta("sfx_id", "") in ids:
			return true
	return false

func sfx_pending(id: String) -> bool:
	for p in pending_sfx:
		if p[0] == id:
			return true
	return false

# ---------------------------------------------------------------------------
# echo_trace: her last movements, played back at her from one side
# ---------------------------------------------------------------------------
## The sounds an echo_trace of `moves` plays, [sfx id, seconds from its start], in order:
## per known move i (unknown ids skipped, ECHO_MAX at most) echo_step at i * ECHO_GAP and its
## ECHO_SFX ECHO_STEP_LEAD later.
static func echo_schedule(moves: Variant) -> Array:
	var out := []
	var i := 0
	if not moves is Array:
		return out
	for m in moves:
		if i >= ECHO_MAX:
			break
		if not ECHO_SFX.has(str(m)):
			continue
		var t := i * ECHO_GAP
		out.append([ECHO_STEP, t])
		out.append([ECHO_SFX[str(m)], t + ECHO_STEP_LEAD])
		i += 1
	return out

## The side the trace sounds from: away from where she came in. Left when the room she came
## from sorts before this one, else right.
func echo_side() -> String:
	return "left" if came_from < str(sim.state.room) else "right"

func echo_db() -> float:
	return ECHO_DB - (ECHO_SOFT_CUT if sim.settings.soft_audio else 0.0)

## Schedules an echo_trace `delay` s from now and holds captions until its last sound plus
## ECHO_TAIL. A trace with no known move is nothing.
func start_echo(moves: Variant, delay := 0.0) -> void:
	var sched := echo_schedule(moves)
	if sched.is_empty():
		return
	var side := echo_side()
	for s in sched:
		pending_echo.append([s[0], delay + float(s[1]), side])
		echo_log.append({"id": s[0], "at": float(s[1]), "db": echo_db(), "pan": side})
	echo_hold_until = maxf(echo_hold_until, time + delay + float(sched[-1][1]) + ECHO_TAIL)

func _tick_echo(dt: float) -> void:
	var due := []
	for i in range(pending_echo.size() - 1, -1, -1):
		pending_echo[i][1] -= dt
		if pending_echo[i][1] <= 0.000001:
			due.push_front(pending_echo[i])
			pending_echo.remove_at(i)
	due.sort_custom(func(a, b): return a[1] < b[1])
	for p in due:
		_play_echo_now(p[0], p[2])

func _clear_echo() -> void:
	pending_echo.clear()
	echo_hold_until = -INF

## One echo sound, now: the shared WAV, on its side's bus, at echo_db() (soft: faded in).
func _play_echo_now(id: String, side: String) -> void:
	played_log.append([id, shown_log.size()])
	var path := "res://assets/audio/%s.wav" % id
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path) as AudioStream
	p.set_meta("sfx_id", id)
	p.bus = ECHO_BUSES.get(side, "Master") if AudioServer.get_bus_index(ECHO_BUSES.get(side, "")) != -1 else "Master"
	var db := echo_db()
	p.volume_db = -60.0 if sim.settings.soft_audio else db
	add_child(p)
	oneshots.append(p)
	p.finished.connect(func():
		oneshots.erase(p)
		p.queue_free())
	p.play()
	if sim.settings.soft_audio:
		var tw := p.create_tween()
		tw.tween_property(p, "volume_db", db, ECHO_SOFT_FADE)

# ---------------------------------------------------------------------------
# the Plan HUD pulse
# ---------------------------------------------------------------------------
## Re-reads the Now: objective's room when anything it depends on may have changed; when it
## moves to a room PLAN_HUD_FAR or more on foot from her (and the plan is hers), the Plan
## button pulses once. The first reading (a load, a jump) never pulses.
func _tick_plan_hud() -> void:
	if not sim.state.started or sim.view in ["title", "end"]:
		return
	var key := [click_id, sim.state.room, sim.state.flags.size(), sim.state.visited.size(), sim.view]
	if key == plan_hud_key:
		return
	plan_hud_key = key
	var to := sim.objective_room()
	if to == plan_hud_obj:
		return
	var first := plan_hud_obj == "?"
	plan_hud_obj = to
	if first or to == "" or not sim.plan_unlocked():
		return
	if sim.walk_distance(sim.state.room, to) >= PLAN_HUD_FAR:
		plan_hud_t = 0.0
		plan_hud_pulses += 1

## 0..1: the Plan button's brass rim. Motion on, one PLAN_HUD_SWELL swell; off, steady for
## PLAN_HUD_STILL.
func plan_hud_alpha() -> float:
	if not sim.settings.motion:
		return 1.0 if plan_hud_t < PLAN_HUD_STILL else 0.0
	if plan_hud_t >= PLAN_HUD_SWELL:
		return 0.0
	return sin(PI * plan_hud_t / PLAN_HUD_SWELL)

func _redraw() -> void:
	if room_view:
		room_view.redraw()
	over.queue_redraw()
	card.queue_redraw()
	hud.queue_redraw()

# ---------------------------------------------------------------------------
# input
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		disarm()
	elif event is InputEventMouseMotion:
		hover(get_global_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if disarm():
					pass   # Esc puts the item in hand away first; nothing else
				elif sim.view == "title":
					dispatch("menu")
				elif sim.view == "room":
					var esc := esc_room_action()
					if always_acts(esc) and _chain_gates() and chain_active():
						advance()   # Back is one press: the line finishes and she steps back
					dispatch(esc)
				elif sim.view in ["notebook", "menu"]:
					if _chain_gates() and chain_active():
						advance()
					dispatch("back")
			KEY_N:
				if not _cinematic():
					dispatch("notebook")
			KEY_H:
				if not _cinematic():
					dispatch("hint")
			KEY_F1:
				if OS.is_debug_build():
					dev = not dev
					_redraw()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				if dev and OS.is_debug_build():
					var n: int = event.keycode - KEY_1
					if event.shift_pressed:
						tide_jump(n + 1)          # Shift+1..9: start of tide I..IX
					else:
						room_jump(sim.state.room, n)   # 1..9: the room's own stages 0..8

## Views Esc never steps back out of: they open the menu (R12's ending, R02's threshold and
## end), whatever the room's own esc_action says.
const ESC_MENU_VIEWS := ["ending", "threshold", "end"]

## What Esc does in the room (after the item in hand is put away): Back wherever Back is on
## show, or in any view other than the room's own that has a way back; else the room's
## esc_action(), and the menu when that is "" (a hold or a cut: the menu holds the chain).
func esc_room_action() -> String:
	if room_view == null:
		return "menu"
	var lv: String = room_sim().local_view if room_sim() else "room"
	if room_view.back_visible():
		return "back"
	var esc := room_view.esc_action()
	if lv != "room" and esc == "menu" and not lv in ESC_MENU_VIEWS:
		return "back"
	return esc if esc != "" else "menu"

## Puts the item in hand away (Esc, the right button, in the room) through the sim's
## "disarm". Returns false, doing nothing, when nothing is in hand.
func disarm() -> bool:
	if sim.selected_item == "" or sim.view != "room":
		return false
	dispatch("disarm")
	return true

## A pointer a test or driver stands in for the mouse (tests/click_chain_test.gd's pointer
## mode). Views that gate on the pointer read has_pointer() and pointer_position(), so a
## headless run sees what a real pointer would.
var sim_pointer_on := false
var sim_pointer := Vector2.ZERO

func pointer_position() -> Vector2:
	return sim_pointer if sim_pointer_on else get_global_mouse_position()

## True when there is a hovering pointer: a real mouse, or a simulated one.
func has_pointer() -> bool:
	return sim_pointer_on or (DisplayServer.get_name() != "headless" and not DisplayServer.is_touchscreen_available())

## The pointer moved to `p`: what it names, and the cursor. The mouse-motion handler and
## the click-chain test's pointer mode both come through here.
func hover(p: Vector2) -> void:
	if sim_pointer_on:
		sim_pointer = p
	var id := _hover_at(p)
	if id != hover_id:
		hover_id = id
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if id != "" else Input.CURSOR_ARROW)

func _hover_at(p: Vector2) -> String:
	if sim.view != "room" or room_view == null:
		return ""
	if sim.state.started and _hud_shown():
		for slot in _inv_layout():
			if slot[0].has_point(p):
				return slot[1]
	var ex := _exit_at(p)
	if ex != "":
		return ex
	var id := room_view.hover_at(p)
	# In a close-up only its own controls name themselves: a room hotspot's label never
	# hangs over the close-up.
	if id != "" and room_sim().is_closeup() and room_view.action_at(p) != id:
		return ""
	return id

## The exit under `p` as "go:<rid>", when the room is showing itself.
func _exit_at(p: Vector2) -> String:
	if room_view == null or room_sim().is_closeup() or not room_view.exits_active():
		return ""
	var rects: Dictionary = room_view.live_exit_rects()
	for e in sim.exits():
		if rects.has(e[0]) and rects[e[0]].has_point(p):
			return "go:" + e[0]
	return ""

## Maps a screen point to an action for the current view. "" = nothing.
func action_at(p: Vector2) -> String:
	var a := _core_action_at(p)
	if a == "" and _room_takes_click():
		return room_view.action_at(p)
	return a

## A point the core resolved to nothing goes to the room (its hotspots and close-ups).
func _room_takes_click() -> bool:
	return sim.view == "room" and room_view != null

## Everything the core answers itself: the title, end card and menu, the HUD, the
## inventory, the notebook, Back and the exits. "" leaves the point to the room.
func _core_action_at(p: Vector2) -> String:
	match sim.view:
		"title":
			return "begin"
		"end":
			if end_t < 1.5:
				return ""
			for b in end_buttons():
				if b[1].has_point(p):
					if b[0] == "new_game" and not new_game_armed():
						return "new_game_arm"
					return b[0]
			return ""
		"menu":
			var items := ["resume", "toggle_motion", "toggle_soft", "restart" if _restart_armed() else "restart_arm"]
			for i in items.size():
				if _menu_rect(i).has_point(p):
					return items[i]
			return ""
	if sim.state.started and _hud_shown():
		for b in hud_buttons():
			if b[1].has_point(p):
				return b[0]
		if sim.view == "room":
			for slot in _inv_layout():
				if slot[0].has_point(p):
					return slot[1]
	if sim.view == "notebook":
		if BACK_RECT.has_point(p):
			return "back"
		for b in _nb_page_buttons():
			if b[0].has_point(p):
				return b[1]
		for t in _notebook_tabs():
			if t[1].has_point(p):
				return "tab:" + t[0]
		if now_plan_rect().has_point(p):
			return "nbnow:plan"
		if _nb_page() == "plan":
			for row in _plan_rows():
				if row[2] and row[1].has_point(p):
					return "plan:" + row[0]
		return ""
	if sim.view != "room" or room_view == null:
		return ""
	if room_view.back_visible() and BACK_RECT.has_point(p):
		return "back"
	return _exit_at(p)

## The HUD buttons on show: Notebook, Hint, menu, and the Plan once the plan is hers.
func hud_buttons() -> Array:
	var out: Array = HUD_BUTTONS.duplicate()
	if plan_button_shown():
		out.append(PLAN_BUTTON)
	return out

## The Plan button: after P05, in the room view (never in a cinematic, the title, the end
## card or the menu, and not over a close-up or the notebook, which has its own Plan tab).
func plan_button_shown() -> bool:
	return sim.plan_unlocked() and sim.state.started and sim.view == "room" and room_view != null \
		and not room_view.hud_hidden() and not room_view.back_visible() and not room_sim().is_closeup()

func _hud_shown() -> bool:
	return sim.view == "notebook" or (sim.view == "room" and (room_view == null or not room_view.hud_hidden()))

## Slot `i` of the bar: the layout's rect when it has one, else where slot i would be.
func _inv_rect(i: int) -> Rect2:
	var layout := _inv_layout()
	return layout[i][0] if i < layout.size() else _slot_rect(i)

static func _slot_rect(i: int) -> Rect2:
	return Rect2(INV_ORIGIN + Vector2(i * (INV_SLOT.x + INV_GAP), 0), INV_SLOT)

## The inventory bar, shared by hit-testing, hover and drawing: [rect, action] per
## slot. Up to INV_MAX items show as they are; more go five to a page with a pager in the
## sixth slot ("inv_page").
func _inv_layout() -> Array:
	var inv: Array = bar_items()
	var out := []
	if inv.size() <= INV_MAX:
		for i in inv.size():
			out.append([_slot_rect(i), _slot_action(inv[i])])
		return out
	var page := _inv_page_shown()
	for k in INV_PER_PAGE:
		var i := page * INV_PER_PAGE + k
		if i >= inv.size():
			break
		out.append([_slot_rect(k), _slot_action(inv[i])])
	out.append([_slot_rect(INV_PER_PAGE), "inv_page"])
	return out

## A slot's action: "item:<id>", or "" for a ghost (nothing to click).
static func _slot_action(item: String) -> String:
	return "item:" + item if item != "" else ""

## The bar as drawn, in slot order: her items, with "" for a ghost. While a close-up is open
## an item taken from her keeps its slot, empty, so the slots of the rest never move under
## the pointer; new items go on the end. Out of the close-up (Back, travel) the bar compacts.
func bar_items() -> Array:
	var inv: Array = sim.state.inventory
	var holding: bool = room_sim() != null and room_sim().is_closeup()
	if not holding:
		if inv_shown != inv:
			inv_shown = inv.duplicate()
		return inv_shown
	var out := []
	for it in inv_shown:
		out.append(it if it != "" and it in inv else "")
	for it in inv:
		if not it in out:
			out.append(it)
	inv_shown = out
	return out

func _inv_pages() -> int:
	var n: int = bar_items().size()
	return 1 if n <= INV_MAX else ceili(float(n) / INV_PER_PAGE)

## The page on show: inv_page, kept in range as items are used up.
func _inv_page_shown() -> int:
	return clampi(inv_page, 0, _inv_pages() - 1)

## The bar changed size (an item used up): stay in range, and on the item in her hand.
func _keep_inv_page() -> void:
	_note_inv_change()
	var n: int = bar_items().size()
	if n == seen_inv_size:
		return
	seen_inv_size = n
	inv_page = _inv_page_shown()
	if sim.selected_item != "":
		_show_item_page(sim.selected_item)

func _show_item_page(item: String) -> void:
	var i: int = bar_items().find(item)
	if i >= 0 and _inv_pages() > 1:
		inv_page = i / INV_PER_PAGE

func _restart_armed() -> bool:
	return time - restart_armed_at < RESTART_ARM

## The end card's New game: armed by its first click, for RESTART_ARM.
func new_game_armed() -> bool:
	return time - new_game_armed_at < RESTART_ARM

## The end card's buttons on show, [action, rect, label]: Return to final decision (when a
## checkpoint is kept) and New game (wider, with its warning, while armed).
func end_buttons() -> Array:
	var out := []
	for b in END_BUTTONS:
		if b[0] == "return_decision" and sim.checkpoint.is_empty():
			continue
		out.append(END_NEW_GAME_ARMED if b[0] == "new_game" and new_game_armed() else b)
	return out

func _menu_rect(i: int) -> Rect2:
	return Rect2(474, 330 + i * 100, 500, 76)

# ---------------------------------------------------------------------------
# drawing: title, menu, notebook, end (over layer)
# ---------------------------------------------------------------------------
func _draw_over() -> void:
	var c := over
	match sim.view:
		"title":
			_draw_title(c)
		"menu":
			_draw_menu(c)
		"notebook":
			_draw_notebook(c)
		"end":
			_draw_end(c)
	# Between rooms: a short dip through storm navy (Motion on only).
	if travel_dip_t < TRAVEL_DIP and sim.settings.motion:
		c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(TRAVEL_DIP_COLOR, 1.0 - travel_dip_t / TRAVEL_DIP))

func _draw_title(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Ink.BLACK)
	var tex := title_plate()
	if tex:
		c.draw_texture_rect(tex, title_plate_rect(), false)
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(Ink.INK, TITLE_DARKEN))
	var pulse := 0.8 + 0.2 * sin(time * 1.6) if sim.settings.motion else 1.0
	_title_text(c, "THE NINTH TIDE", 470, 78, Ink.PAPER, serif)
	_title_text(c, sim.tide_title(), 540, 30, Color(Ink.PAPER, 0.85), hand)
	_title_text(c, "Greywake Survey Station, Morrow Sound. October 1931.", 640, 24, Color(Ink.PAPER, 0.8), serif)
	_title_text(c, "click to begin", 820, 24, Color(Ink.GOLD, pulse), serif)
	_title_text(c, "Headphones recommended. Esc for options.", 1040, 18, Color(Ink.PAPER, 0.6), serif)

## A title line, centred, on a soft ink outline: it reads over the lit window of the plate
## without a band across the photograph.
func _title_text(c: Node2D, s: String, y: float, size: int, col: Color, font: Font) -> void:
	var halo := Color(Ink.INK, 0.75 * col.a)
	c.draw_string_outline(font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, size, maxi(6, size / 6), halo)
	Ink.text(c, s, Vector2(0, y), size, col, font, SIZE.x)

## The title's photograph (never modified: the same plate R02 shows in the drawer).
func title_plate() -> Texture2D:
	if _title_tex == null and ResourceLoader.exists(TITLE_PLATE):
		_title_tex = load(TITLE_PLATE) as Texture2D
	return _title_tex

## Where the plate is drawn: scaled to cover the screen, centred, and with Motion on drifting
## on one slow sine (TITLE_DRIFT_PERIOD): scale 1.00..1.01, at most ~6 px of travel.
func title_plate_rect() -> Rect2:
	var tex := title_plate()
	if tex == null:
		return Rect2(Vector2.ZERO, SIZE)
	var ts := Vector2(tex.get_size())
	# Covers the screen plus the drift's travel, so no edge ever shows.
	var k := maxf((SIZE.x + 2.0 * TITLE_DRIFT_PX.x) / ts.x, (SIZE.y + 2.0 * TITLE_DRIFT_PX.y) / ts.y)
	var off := Vector2.ZERO
	if sim.settings.motion:
		var w := sin(TAU * time / TITLE_DRIFT_PERIOD)
		k *= 1.0 + TITLE_DRIFT_SCALE * 0.5 * (1.0 + w)
		off = TITLE_DRIFT_PX * w
	var sz := ts * k
	return Rect2((SIZE - sz) * 0.5 + off, sz)

func _draw_menu(c: Node2D) -> void:
	if sim.return_view == "title":
		c.draw_rect(Rect2(Vector2.ZERO, SIZE), Ink.BLACK)   # nothing of the room before the opening
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(Ink.INK, 0.93))
	Ink.text(c, "Paused" if sim.return_view != "title" else "Options", Vector2(0, 260), 40, Ink.PAPER, serif, SIZE.x)
	var labels := ["Resume", "Motion & flicker: " + ("on" if sim.settings.motion else "off"),
		"Soften sudden sounds: " + ("on" if sim.settings.soft_audio else "off"),
		"Restart? Click again" if _restart_armed() else "New game"]
	for i in labels.size():
		Ink.button(c, _menu_rect(i), labels[i])

## The notebook's pages: the plan (after P05), then each visited room, current first.
func _notebook_tabs() -> Array:
	var ids: Array = [sim.state.room]
	for rid in sim.state.visited:
		if not rid in ids:
			ids.append(rid)
	if sim.flag("P05"):
		ids.append("plan")
	var out := []
	var x := NOTEBOOK_PAGE.position.x + 40.0
	for rid in ids:
		var label: String = "Plan" if rid == "plan" else rid
		var w := maxf(64.0, serif.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 24.0)
		out.append([rid, Rect2(x, NOTEBOOK_PAGE.position.y - 2, w, 64), label])
		x += w + 6.0
	return out

func _nb_page() -> String:
	if sim.nb_tab == "plan" and sim.flag("P05"):
		return "plan"
	if sim.nb_tab != "" and sim.rooms.has(sim.nb_tab) and (sim.nb_tab in sim.state.visited):
		return sim.nb_tab
	return sim.state.room

## [rid, rect, can_travel] for each visited room on the plan page.
func _plan_rows() -> Array:
	var out := []
	var reach := sim.reachable()
	var i := 0
	for rid in sim.order:
		if not rid in sim.state.visited:
			continue
		var ok: bool = rid != sim.state.room and rid in reach
		# Two columns of six, so all twelve rooms fit on the page.
		var x := NOTEBOOK_PAGE.position.x + 60.0 + (i / 6) * 520.0
		var y := NOTEBOOK_PAGE.position.y + 190.0 + (i % 6) * 76.0
		out.append([rid, Rect2(x, y, 480, 64), ok])
		i += 1
	return out

func _draw_notebook(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(Ink.INK, 0.97))
	var page := NOTEBOOK_PAGE
	c.draw_rect(page, Color("e4dcc4"))
	var cur := _nb_page()
	for t in _notebook_tabs():
		var on: bool = t[0] == cur
		c.draw_rect(Rect2(t[1].position, Vector2(t[1].size.x, 30)), Color("e4dcc4") if on else Color("b9b099"))
		Ink.text(c, t[2], t[1].position + Vector2(0, 22), 18, Color(Ink.INK, 1.0 if on else 0.6), serif, t[1].size.x)
	if cur == "plan":
		_draw_plan(c, page)
		return
	var r: RoomSim = sim.room(cur)
	var obs: Dictionary = r.c("OBSERVATIONS", {})
	var entries := nb_entries(cur)
	var nb := _nb_pagination(cur)
	var pager := _nb_page_buttons()
	var noted_right := page.size.x - 50.0
	if not pager.is_empty():
		var first: Rect2 = pager[0][0]
		noted_right = first.position.x - page.position.x - 14.0
		for b in pager:
			var off: bool = (b[1] == "nbpage:prev" and nb.shown == 0) or \
				(b[1] == "nbpage:next" and nb.shown == nb.pages.size() - 1)
			Ink.button(c, b[0], "◂" if b[1] == "nbpage:prev" else "▸", false, 20, off)
		var mid := Rect2(first.end.x, first.position.y, pager[1][0].position.x - first.end.x, first.size.y)
		Ink.text(c, "p %d/%d" % [nb.shown + 1, nb.pages.size()], Vector2(mid.position.x, mid.position.y + 27), 20,
			Color(Ink.INK, 0.75), serif, mid.size.x)
	Ink.text(c, "NOTEBOOK — A. MERCER  ·  " + str(r.c("TITLE", cur)).to_upper(), page.position + Vector2(50, 64), 26,
		Ink.INK, serif, 900, HORIZONTAL_ALIGNMENT_LEFT)
	Ink.text(c, "Noted %d of %d" % [r.seen().size(), obs.size()],
		page.position + Vector2(0, 64), 20, Color(Ink.INK, 0.5), serif, noted_right, HORIZONTAL_ALIGNMENT_RIGHT)
	if cur == sim.state.room:
		var ns := now_size()
		Ink.text(c, now_text(), page.position + Vector2(50, 112), ns,
			Color("5b3a2e"), hand, 1000, HORIZONTAL_ALIGNMENT_LEFT)
		var link := now_plan_rect()
		if link.size != Vector2.ZERO:
			# " (Plan)": the far work is quicker by the plan. A link in her blue ink.
			Ink.text(c, NOW_PLAN_SUFFIX.strip_edges(), Vector2(link.position.x, page.position.y + 112), ns,
				Ink.BLUE_INK, hand, link.size.x, HORIZONTAL_ALIGNMENT_LEFT)
			c.draw_line(Vector2(link.position.x, link.end.y - 6), Vector2(link.end.x, link.end.y - 6),
				Color(Ink.BLUE_INK, 0.7), 1.5)
	if nb.pages.is_empty():
		Ink.text(c, "Nothing recorded yet. Look around.", Vector2(page.position.x + 80, nb.top), 22,
			Color(Ink.INK, 0.6), hand, 900, HORIZONTAL_ALIGNMENT_LEFT)
		return
	var last: bool = nb.shown == nb.pages.size() - 1
	var flow := _notebook_flow(c, entries, nb.pages[nb.shown], nb.layout, nb.top,
		nb.bottom - (nb.room_for if last else 0.0), page.position.x, true)
	if nb.intrusion == "" or not last:
		return
	# A line she did not write, in her hand, straight after her last entry (its room is kept).
	var intrusion: String = nb.intrusion
	var n := intrusion.length()
	if _intrusion_writing():
		n = mini(n, int(intrusion_t * REVEAL_CPS * 0.45))
	var size: int = nb.layout[0]
	var pos: Vector2 = flow.next + Vector2(20, 8 - size * 0.45)
	var w := hand.get_string_size(intrusion, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	pos.x = minf(pos.x, page.end.x - 30 - w)
	Ink.handwriting(c, intrusion, n, pos, 22, 300, _intrusion_writing())

const FILED_PREFIX := "filed:"

## Room `rid`'s notebook entries: its observations, then every item it handed out that has
## been filed after its last use ("filed:<item>": the item's name and description).
func nb_entries(rid: String) -> Dictionary:
	var r: RoomSim = sim.room(rid)
	if r == null:
		return {}
	var out: Dictionary = r.c("OBSERVATIONS", {})
	var defs := sim.item_defs()
	var filed := {}
	for item in sim.retired():
		var d: Dictionary = defs.get(item, {})
		if d.get("room", "") == rid:
			filed[FILED_PREFIX + item] = "Filed: %s. %s" % [d.get("name", item), d.get("desc", "")]
	if filed.is_empty():
		return out
	out = out.duplicate()
	out.merge(filed)
	return out

## How room `rid`'s notebook page lays out: {layout, pages (arrays of observation ids), shown,
## top, bottom, room_for, intrusion}. The roomiest layout that holds every entry; past the
## smallest ([17, 460, 2]) the entries run onto more pages, the stranger's line keeping its
## room on the last. Cached: it measures text.
func _nb_pagination(rid: String) -> Dictionary:
	var r: RoomSim = sim.room(rid)
	var obs := nb_entries(rid)
	var ids := []
	for id in obs:
		if r.has_seen(id) or id.begins_with(FILED_PREFIX):
			ids.append(id)
	var intrusion := r.notebook_intrusion() if r and rid == sim.state.room else ""
	var key := [rid, ids, intrusion]
	var info: Dictionary
	if nb_cache.get("key") == key:
		info = nb_cache.info
	else:
		info = _nb_paginate(obs, ids, intrusion)
		nb_cache = {"key": key, "info": info}
	var pages: Array = info.pages
	var shown := 0
	if nb_page >= 0:
		shown = clampi(nb_page, 0, maxi(pages.size() - 1, 0))
	elif r and not r.seen().is_empty():
		# The page with the newest entry.
		var newest: String = r.seen()[-1]
		for i in pages.size():
			if newest in pages[i]:
				shown = i
	info = info.duplicate()
	info["shown"] = shown
	return info

func _nb_paginate(obs: Dictionary, ids: Array, intrusion: String) -> Dictionary:
	var page := NOTEBOOK_PAGE
	var top := page.position.y + 180
	var bottom := page.end.y - 24
	var room_for := NB_INTRUSION_ROOM if intrusion != "" else 0.0
	var out := {"top": top, "bottom": bottom, "room_for": room_for, "intrusion": intrusion,
		"layout": NB_LAYOUTS[0], "pages": []}
	if ids.is_empty():
		return out
	for opt in NB_LAYOUTS:
		out.layout = opt
		if _notebook_flow(over, obs, ids, opt, top, bottom - room_for, page.position.x, false).fits:
			out.pages = [ids.duplicate()]
			return out
	# Too many for one page: fill each page as far as it goes.
	var pages := []
	var cur := []
	for id in ids:
		var trial := cur.duplicate()
		trial.append(id)
		if cur.is_empty() or _notebook_flow(over, obs, trial, out.layout, top, bottom, page.position.x, false).fits:
			cur = trial
		else:
			pages.append(cur)
			cur = [id]
	pages.append(cur)
	# The last page keeps the stranger's line its room.
	var spill := []
	while pages[-1].size() > 1 and not _notebook_flow(over, obs, pages[-1], out.layout, top, bottom - room_for,
			page.position.x, false).fits:
		spill.push_front(pages[-1].pop_back())
	if not spill.is_empty():
		pages.append(spill)
	out.pages = pages
	return out

## The notebook's page turners, [rect, action], when a room's entries need more than one page.
func _nb_page_buttons() -> Array:
	if sim.view != "notebook":
		return []
	var cur := _nb_page()
	if cur == "plan" or _nb_pagination(cur).pages.size() < 2:
		return []
	var y := NOTEBOOK_PAGE.position.y + 38
	var right := NOTEBOOK_PAGE.end.x - 50
	return [[Rect2(right - 44 - 84 - 44, y, 44, 40), "nbpage:prev"], [Rect2(right - 44, y, 44, 40), "nbpage:next"]]

## "Now: <objective>" as the notebook writes it (the " (Plan)" link is drawn after it).
func now_text() -> String:
	return "Now: " + sim.objective_text()

## The " (Plan)" link after the Now: line (sim.now_via_plan()), on the current room's notebook
## page only. Rect2() when it is not offered.
func now_plan_rect() -> Rect2:
	if sim.view != "notebook" or _nb_page() != sim.state.room or not sim.now_via_plan():
		return Rect2()
	var ns := now_size()
	var x := NOTEBOOK_PAGE.position.x + 50.0 + hand.get_string_size(now_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x + 10.0
	var w := hand.get_string_size(NOW_PLAN_SUFFIX.strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x + 6.0
	x = minf(x, NOTEBOOK_PAGE.end.x - 30.0 - w)
	return Rect2(x, NOTEBOOK_PAGE.position.y + 112.0 - 26.0, w, 38.0)

## The Now: line's size: 24 px, smaller (to 17) when the line and its plan link would not
## fit across the page.
func now_size() -> int:
	var room := NOTEBOOK_PAGE.size.x - 80.0
	var size := 24
	while size > 17:
		var need := hand.get_string_size(now_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if sim.now_via_plan():
			need += hand.get_string_size(NOW_PLAN_SUFFIX, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 16.0
		if need <= room:
			break
		size -= 1
	return size

## The Now: line with the plan link spelled out (tests and drivers): "" suffix when not offered.
func now_line() -> String:
	return now_text() + (NOW_PLAN_SUFFIX if now_plan_rect().size != Vector2.ZERO else "")

## The plan row the Now: link points at: the objective's room if she has been there, else the
## visited room nearest to it by open exits.
func plan_pulse_target() -> String:
	var to := sim.objective_room()
	if to == "":
		return ""
	if to in sim.state.visited:
		return to
	var best := ""
	var best_d := 1 << 30
	for rid in sim.state.visited:
		var d := sim.hops(rid, to)
		if d >= 0 and d < best_d:
			best = rid
			best_d = d
	return best

func _draw_plan(c: Node2D, page: Rect2) -> void:
	Ink.text(c, "STATION PLAN", page.position + Vector2(50, 64), 26, Ink.INK, serif, 900, HORIZONTAL_ALIGNMENT_LEFT)
	Ink.text(c, "Rooms I have been in. Where the way is open, I can go straight there.",
		page.position + Vector2(50, 112), 22, Color("5b3a2e"), hand, 1000, HORIZONTAL_ALIGNMENT_LEFT)
	for row in _plan_rows():
		var r: RoomSim = sim.room(row[0])
		var here: bool = row[0] == sim.state.room
		var label: String = "%s  %s%s" % [row[0], r.c("TITLE", ""), "  (here)" if here else ""]
		Ink.button(c, row[1], label, here, 22, not row[2] and not here)
		if row[0] == plan_pulse and plan_pulse_t < PLAN_PULSE_TIME:
			# The pin the Now: link sent her to. Motion off: a steady ring.
			var k := 0.55 + 0.45 * sin(plan_pulse_t * 5.0) if sim.settings.motion else 1.0
			c.draw_rect(row[1].grow(5.0), Color(Ink.GOLD, k), false, 3.0)
		if row[2]:
			# A row she can travel by: a small mark at its right end.
			var rr: Rect2 = row[1]
			Ink.text(c, "→ go", Vector2(rr.end.x - 74, rr.position.y + rr.size.y * 0.5 + 7), 18,
				Color(Ink.GOLD, 0.95), hand, 64, HORIZONTAL_ALIGNMENT_RIGHT)

## The stranger line writes itself once, slowly, the first time the notebook opens after
## the room makes one. Motion off: it is simply there.
func _intrusion_writing() -> bool:
	var r := room_sim()
	if r == null or sim.view != "notebook" or not sim.settings.motion or intrusion_written:
		return false
	var s := r.notebook_intrusion()
	return s != "" and intrusion_t * REVEAL_CPS * 0.45 < s.length()

## Lays out notebook entries in columns. Returns {fits, next, rects}: rects is [id, Rect2]
## per entry (bullet to the end of its last line), for tests and drivers.
func _notebook_flow(c: CanvasItem, obs: Dictionary, ids: Array, layout: Array, top: float, bottom: float,
		left: float, draw: bool) -> Dictionary:
	var size: int = layout[0]
	var width: float = layout[1]
	var columns: int = layout[2]
	var col := 0
	var y := top
	var x := left + 60
	var rects := []
	for id in ids:
		var h := Ink.wrapped(c, obs[id], Vector2(0, 0), size, Ink.INK, width, false)
		if y + h - size > bottom and col + 1 < columns:
			col += 1
			y = top
		x = left + 60 + col * (width + 60)
		if draw:
			c.draw_circle(Vector2(x, y - size * 0.36), 4, Color(Ink.INK, 0.6))
			Ink.wrapped(c, obs[id], Vector2(x + 20, y), size, Ink.INK, width)
		rects.append([id, Rect2(x - 6, y - size, width + 26, h)])
		y += h + size * 0.45
	return {"fits": y - size * 1.9 <= bottom, "next": Vector2(x, y), "rects": rects}

func _draw_end(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Ink.BLACK)
	var e: Dictionary = GameSim.ENDINGS.get(sim.state.ending, {"title": "", "lines": []})
	var still := end_still(sim.state.ending)
	if still:
		c.draw_texture_rect(still, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, END_STILL_ALPHA))
	var a := clampf(end_t / END_TEXT_FADE, 0.0, 1.0) if sim.settings.motion else 1.0
	var lay := end_layout(sim.state.ending)
	# A panel in the lower band: the painted still stays the picture. CONTINUE writes navy ink
	# on paper; SEVER, the unrecorded shore, paper on storm-navy ink.
	var cols := end_panel_colors(sim.state.ending)
	c.draw_rect(lay.panel, Color(cols.fill, cols.fill.a * a))
	c.draw_rect(lay.panel, Color(Ink.BRASS, a), false, 2.0)
	var x: float = lay.panel.position.x
	var w: float = lay.panel.size.x
	var ink: Color = cols.text
	Ink.text(c, e.title, Vector2(x, lay.title_y), lay.title_size, Color(ink, a), serif, w)
	for i in e.lines.size():
		Ink.text(c, e.lines[i], Vector2(x, lay.line_ys[i]), END_LINE_SIZE, Color(ink, a), hand, w)
	Ink.text(c, end_seen_text(), Vector2(x, lay.seen_y), END_SEEN_SIZE, Color(ink, 0.8 * a), serif, w)
	if end_t >= 1.5:
		for b in end_buttons():
			if b[0] == "new_game":
				# Dim until armed; armed, the warning reads at full strength.
				Ink.button(c, b[1], b[2], false, END_BUTTON_SIZE, not new_game_armed())
			else:
				Ink.button(c, b[1], b[2])

const END_STILL_ALPHA := 1.0
const END_TEXT_FADE := 1.0
const END_PANEL_X := 274.0
const END_PANEL_W := 900.0
const END_PANEL_TOP := 760.0
const END_PANEL_ALPHA := 0.96
## SEVER's panel: storm-navy ink, paper text (CONTINUE keeps the paper panel).
const END_PANEL_INK_ALPHA := 0.94
const END_PANEL_PAD := 40.0       # the panel runs this far below the "Endings seen" line
const END_TITLE_Y := 812.0
const END_TITLE_MAX := 40
const END_TITLE_MIN := 34
const END_LINE_SIZE := 26
const END_LINE_Y := 868.0
const END_LINE_STEP := 40.0
const END_SEEN_SIZE := 20

## The end panel's colours for ending `id` at full fade-in: {fill (with its alpha), text}.
static func end_panel_colors(id: String) -> Dictionary:
	if id == "sever":
		return {"fill": Color(Ink.INK, END_PANEL_INK_ALPHA), "text": Ink.PAPER}
	return {"fill": Color(CARD_PAPER, END_PANEL_ALPHA), "text": Ink.INK}

func end_seen_text() -> String:
	return "Endings seen: %d of 2" % sim.settings.endings_seen.size()

## The end card's layout for ending `id` (pure: drawing and tests): {panel, title_size,
## title_y, line_ys, seen_y}. Text y values are baselines. The title shrinks from
## END_TITLE_MAX toward END_TITLE_MIN until it fits the panel less 80 px; "Endings seen" sits
## under the last quote line, and the panel ends END_PANEL_PAD below it.
func end_layout(id: String) -> Dictionary:
	var e: Dictionary = GameSim.ENDINGS.get(id, {"title": "", "lines": []})
	var size := END_TITLE_MAX
	while size > END_TITLE_MIN and serif.get_string_size(e.title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > END_PANEL_W - 80.0:
		size -= 1
	var ys: Array = []
	for i in e.lines.size():
		ys.append(END_LINE_Y + END_LINE_STEP * i)
	var seen_y: float = (ys[-1] if not ys.is_empty() else END_TITLE_Y) + END_LINE_STEP * 0.85
	var panel := Rect2(END_PANEL_X, END_PANEL_TOP, END_PANEL_W, seen_y + END_PANEL_PAD - END_PANEL_TOP)
	return {"panel": panel, "title_size": size, "title_y": END_TITLE_Y, "line_ys": ys, "seen_y": seen_y}

var _end_stills := {}   # path -> Texture2D, held: a drawn texture must outlive the draw call

## The ending's painted still: the first of ENDINGS[id].still (a path or a list, preferred
## first) whose file exists, or null when there is none (nothing is drawn, nothing raised).
func end_still(id: String) -> Texture2D:
	var path := end_still_path(id)
	if path == "":
		return null
	if not _end_stills.has(path):
		_end_stills[path] = load(path) as Texture2D
	return _end_stills[path]

static func end_still_path(id: String) -> String:
	var v = GameSim.ENDINGS.get(id, {}).get("still", [])
	for path in (v if v is Array else [v]):
		if str(path) != "" and ResourceLoader.exists(str(path)):
			return str(path)
	return ""

## The tide card, once its reveal has been read. Fades in and out
## over TIDE_CARD_TIME; Motion off, it is simply there for TIDE_CARD_STILL.
func tide_card_alpha() -> float:
	if tide_card_n <= 0:
		return 0.0
	if not sim.settings.motion:
		return 1.0 if tide_card_t < TIDE_CARD_STILL else 0.0
	if tide_card_t >= TIDE_CARD_TIME:
		return 0.0
	return clampf(minf(tide_card_t, TIDE_CARD_TIME - tide_card_t) / TIDE_CARD_FADE, 0.0, 1.0)

## Where the card on show sits: TIDE_CARD_RECT, low on the left of the room, or the upper
## band when that would cover an exit tab or the glance (chosen as the card starts).
func tide_card_rect() -> Rect2:
	return tide_card_at

func _draw_card() -> void:
	var a := tide_card_alpha()
	if a <= 0.0:
		return
	var r := tide_card_rect()
	card.draw_rect(r, Color(Ink.INK, 0.88 * a))
	card.draw_rect(r, Color(Ink.BRASS, 0.8 * a), false, 2)
	Ink.text(card, "TIDE " + GameSim.NUMERALS[tide_card_n - 1], r.position + Vector2(0, 48), 36,
		Color(Ink.PAPER, a), serif, r.size.x)
	Ink.text(card, GameSim.TIDE_TITLES[tide_card_n - 1], r.position + Vector2(0, 90), 26,
		Color(Ink.PAPER, 0.8 * a), hand, r.size.x)

# ---------------------------------------------------------------------------
# drawing: HUD
# ---------------------------------------------------------------------------
func _draw_hud() -> void:
	var c := hud
	if sim.view in ["title", "end", "menu"] or (sim.view == "room" and room_view and room_view.hud_hidden()):
		subtitle.visible = false
		return
	subtitle.visible = true
	if slab_a > 0.0:
		c.draw_rect(Rect2(20, 994, 1408, 80), Color(0.03, 0.06, 0.08, 0.9 * slab_a))
	if chain_active() and _chain_gates():
		# More to come: a click brings the next line up.
		var pulse := 0.75 + 0.25 * sin(time * 2.0) if sim.settings.motion else 1.0
		c.draw_string(serif, Vector2(1392, 1040), "▸", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Ink.PAPER, 0.55 * pulse))
	for b in hud_buttons():
		Ink.button(c, b[1], b[2], false, PLAN_LABEL_SIZE if b[0] == "plan" else 21)
		if b[0] == "plan":
			var k := plan_hud_alpha()
			if k > 0.0:
				var grow := 2.0 + (4.0 * k if sim.settings.motion else 2.0)
				c.draw_rect(b[1].grow(grow), Color(Ink.BRASS, 0.95 * k), false, 3.0)
	if sim.view == "notebook":
		Ink.button(c, BACK_RECT, "Back", false, 21)
		_draw_hint_card(c)
		return
	if room_view and room_view.back_visible():
		Ink.button(c, BACK_RECT, room_view.back_label(), false, 21)
	_draw_glance(c)
	_draw_pending_press(c)
	_draw_inventory(c)
	_draw_exits(c)
	if room_view:
		room_view.draw_hud(c)
	if hover_id != "" and sim.view == "room":
		var label := _hover_label(hover_id)
		var box := hover_label_rect(hover_id, pointer_position())
		if label != "" and box.size != Vector2.ZERO:
			c.draw_rect(box, Color(0.03, 0.06, 0.08, 0.8))
			c.draw_string(serif, box.position + Vector2(10, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, HOVER_SIZE, Ink.PAPER)
	_draw_arm_banner(c)
	_draw_hint_card(c)
	if dev:
		_draw_dev(c)

## The item in hand, as a banner in the HUD band (never a caption under the pointer).
func arm_banner_text() -> String:
	if sim.selected_item == "" or sim.view != "room":
		return ""
	var d: Dictionary = sim.item_defs().get(sim.selected_item, {})
	return "Using: %s   (Esc or right-click to put away)" % d.get("short", d.get("name", sim.selected_item))

func arm_banner_rect() -> Rect2:
	var t := arm_banner_text()
	if t == "":
		return Rect2()
	var w := serif.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, ARM_BANNER_SIZE).x + 28.0
	return Rect2(ARM_BANNER_POS, Vector2(w, 32))

func _draw_arm_banner(c: Node2D) -> void:
	var r := arm_banner_rect()
	if r.size == Vector2.ZERO:
		return
	c.draw_rect(r, Color(CARD_PAPER, 0.96))
	c.draw_rect(r, Color(Ink.BRASS, 0.9), false, 1.5)
	c.draw_string(serif, r.position + Vector2(14, 22), arm_banner_text(), HORIZONTAL_ALIGNMENT_LEFT, -1,
		ARM_BANNER_SIZE, Ink.INK)

## The hint card's box (pure: drawing and tests): right-aligned to HINT_CARD_RIGHT, its top
## at HINT_CARD_TOP, at most HINT_CARD_MAX_W wide. Rect2() when no card is up.
func hint_card_rect() -> Rect2:
	var t := hint_card_text()
	if t == "":
		return Rect2()
	var inner := HINT_CARD_MAX_W - 2.0 * HINT_CARD_PAD
	var one := hand.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_CARD_SIZE).x
	var w := minf(HINT_CARD_MAX_W, one + 2.0 * HINT_CARD_PAD + 4.0)
	var h := Ink.wrapped(hud, t, Vector2.ZERO, HINT_CARD_SIZE, Ink.INK, minf(inner, one + 4.0), false, hand)
	h += 2.0 * HINT_CARD_PAD - HINT_CARD_SIZE * 0.45
	return Rect2(HINT_CARD_RIGHT - w, HINT_CARD_TOP, w, h)

func _draw_hint_card(c: Node2D) -> void:
	var r := hint_card_rect()
	if r.size == Vector2.ZERO:
		return
	var left := hint_card_hold - (time - hint_card_at)
	var a := clampf(left / 0.3, 0.0, 1.0) if sim.settings.motion else 1.0
	c.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(Ink.INK, 0.25 * a))
	c.draw_rect(r, Color(CARD_PAPER, 0.98 * a))
	c.draw_rect(r, Color(Ink.INK, 0.7 * a), false, 1.5)
	var inner := r.size.x - 2.0 * HINT_CARD_PAD
	Ink.wrapped(c, hint_card_text(), r.position + Vector2(HINT_CARD_PAD, HINT_CARD_PAD + HINT_CARD_SIZE * 0.85),
		HINT_CARD_SIZE, Color(Ink.INK, a), inner, true, hand)

## A hotspot clicked mid-chain, waiting for the rushed chain to end: shown pressed.
func _draw_pending_press(c: Node2D) -> void:
	if pending_action == "" or sim.view != "room" or room_view == null:
		return
	var r := room_view.control_rect(pending_action)
	if r.size == Vector2.ZERO:
		return
	r = r.grow(4.0)
	c.draw_rect(r, Color(Ink.PAPER, 0.5), false, 6.0)
	c.draw_rect(r, Color(Ink.GOLD, 0.95), false, 3.0)
	c.draw_rect(r.grow(-6.0), Color(Ink.STORM, 0.6), false, 1.5)

## The hover label's box for `id` (pure: drawing and tests). Anchored to the target's rect,
## not the pointer: centred just above it, else just below it (when above would rise into
## the HUD band), else in the row above the subtitles, so the label never covers what it
## names. Never in the HUD band (y >= HUD_BAND_Y), clear of the tide card while it is up,
## always on screen. Only a target with no known rect sits by the pointer (`mouse`).
func hover_label_rect(id: String, mouse: Vector2) -> Rect2:
	var label := _hover_label(id)
	if label == "":
		return Rect2()
	var w := serif.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, HOVER_SIZE).x + 20.0
	var target := hover_target_rect(id)
	var box: Rect2
	if target.size == Vector2.ZERO:
		box = _hover_box(mouse + Vector2(22, 34), w)
	else:
		var x := target.get_center().x - w * 0.5
		box = Rect2(x, target.position.y - HOVER_GAP - HOVER_H, w, HOVER_H)
		if box.position.y < HUD_BAND_Y:
			box = Rect2(x, maxf(target.end.y + HOVER_GAP, HUD_BAND_Y), w, HOVER_H)
		if box.end.y > SUBTITLE_BAR.position.y or box.intersects(target):
			box = _hover_box(Vector2(x + 10.0, HOVER_BAR_Y), w)
	box = _hover_clamp(box)
	if tide_card_alpha() > 0.0 and box.intersects(tide_card_rect()):
		var card_r := tide_card_rect()
		for y in [card_r.position.y - HOVER_GAP - HOVER_H, card_r.end.y + HOVER_GAP]:
			var b := _hover_clamp(Rect2(box.position.x, y, w, HOVER_H))
			if not b.intersects(card_r) and not b.intersects(target):
				return b
		box.position.x = card_r.end.x + HOVER_GAP   # beside it, as a last resort
		box = _hover_clamp(box)
	return box

func _hover_clamp(box: Rect2) -> Rect2:
	box.position.x = clampf(box.position.x, HOVER_MARGIN, SIZE.x - box.size.x - HOVER_MARGIN)
	box.position.y = clampf(box.position.y, HUD_BAND_Y, SIZE.y - HOVER_H)
	return box

static func _hover_box(baseline: Vector2, w: float) -> Rect2:
	return Rect2(baseline - Vector2(10, 24), Vector2(w, HOVER_H))

## The rect of what `id` names: an exit tab, an inventory slot, or the room's hotspot or
## close-up control (RoomView.control_rect). Rect2() when unknown.
func hover_target_rect(id: String) -> Rect2:
	if room_view == null:
		return Rect2()
	if id.begins_with("go:"):
		return room_view.live_exit_rects().get(id.substr(3), Rect2())
	if id.begins_with("item:") or id == "inv_page":
		for slot in _inv_layout():
			if slot[1] == id:
				return slot[0]
		return Rect2()
	return room_view.control_rect(id)

func _hover_label(id: String) -> String:
	if id.begins_with("go:"):
		var to := id.substr(3)
		for e in sim.exits():
			if e[0] == to:
				if not sim.exit_open(sim.state.room, to):
					return "%s (locked)" % e[1]
				return "%s ▸" % _exit_text(to, e[1])
		return ""
	if id.begins_with("item:"):
		var item := id.substr(5)
		return sim.item_defs().get(item, {}).get("name", item)   # the full name; the slot shows the short one
	if id == "inv_page":
		return "More of what I'm carrying"
	return room_view.label_for(id) if room_view else ""

func _draw_inventory(c: Node2D) -> void:
	if sim.view != "room":
		return
	var defs := sim.item_defs()
	for slot in _inv_layout():
		var a: String = slot[1]
		if a == "inv_page":
			Ink.button(c, slot[0], "▸ %d/%d" % [_inv_page_shown() + 1, _inv_pages()], false, 18)
			continue
		if a == "":
			_draw_ghost_slot(c, slot[0])   # an item seated in the close-up: its place kept
			continue
		var id := a.substr(5)
		var d: Dictionary = defs.get(id, {})
		Ink.button(c, slot[0], d.get("short", d.get("name", id)), id == sim.selected_item, 18)

## A slot kept for an item used up in the open close-up: a 1 px storm-navy dashed outline.
func _draw_ghost_slot(c: Node2D, r: Rect2) -> void:
	var col := Color(Ink.STORM, 0.9)
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		c.draw_dashed_line(pts[i], pts[(i + 1) % 4], col, 1.0, 5.0)

## Exit tabs: a plaque per way out, arrowed toward the side it leaves by, dimmed while
## locked. On the HUD layer, so no room lighting can hide them.
func _draw_exits(c: Node2D) -> void:
	if sim.view != "room" or room_view == null or room_sim().is_closeup() or not room_view.exits_active():
		return
	var rects: Dictionary = room_view.live_exit_rects()
	for e in sim.exits():
		if not rects.has(e[0]):
			continue
		var r: Rect2 = rects[e[0]]
		var open := sim.exit_open(sim.state.room, e[0])
		# Locked, or a room not built yet: dimmed (an unbuilt room's tab still answers).
		# Pressed while a rushed reveal plays out before she goes (pending_travel).
		var pressed: bool = hover_id == "go:" + e[0] or pending_travel == "go:" + e[0]
		Ink.button(c, r, exit_tab_label(e[0]), pressed, 19, not open or sim.is_unbuilt(e[0]))

## The text on the tab of the exit to `to`: its name (marked when the room beyond is not
## built yet), arrowed the way the room says (RoomView.exit_arrow), else toward the side of
## the screen the tab sits on.
func exit_tab_label(to: String) -> String:
	var name := ""
	for e in sim.exits():
		if e[0] == to:
			name = e[1]
	var text := _exit_text(to, name)
	var side: String = room_view.exit_arrow(to) if room_view else ""
	if side == "":
		var r: Rect2 = room_view.live_exit_rects().get(to, room_view.exit_rects().get(to, Rect2())) if room_view else Rect2()
		side = "left" if r.get_center().x < SIZE.x / 2.0 else "right"
	match side:
		"left":
			return "◂ " + text
		"down":
			return "▾ " + text
	return text + " ▸"

## An exit's name, marked when the room beyond is not built yet.
func _exit_text(to: String, label: String) -> String:
	return label + " (not yet built)" if sim.is_unbuilt(to) else label

## Four storm-navy corner brackets round the glance rect (a room without its own glance).
func _draw_glance(c: Node2D) -> void:
	var a := glance_alpha()
	if a <= 0.0 or sim.view != "room":
		return
	var out := (1.0 - a) * 24.0 if sim.settings.motion else 0.0   # they close in as they ease in
	var r := glance_rect.grow(6.0 + out)
	var arm := minf(GLANCE_ARM, minf(r.size.x, r.size.y) * 0.5)
	var halo := Color(Ink.PAPER, 0.55 * a)
	var navy := Color(Ink.STORM, a)
	for k in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var p: Vector2 = k[0]
		var d: Vector2 = k[1]
		for pass_n in 2:
			var col := halo if pass_n == 0 else navy
			var wdt := GLANCE_THICK + 4.0 if pass_n == 0 else GLANCE_THICK
			var h := wdt * 0.5   # square corners: each arm runs half a stroke past the corner
			c.draw_line(p - Vector2(d.x * h, 0), p + Vector2(d.x * arm, 0), col, wdt)
			c.draw_line(p - Vector2(0, d.y * h), p + Vector2(0, d.y * arm), col, wdt)

func _draw_dev(c: Node2D) -> void:
	c.draw_rect(Rect2(20, 90, 620, 190), Color(0, 0, 0, 0.75))
	var y := 120
	for line in ["DEV (F1)  %s  view %s/%s  tide %d  weather %d" % [sim.state.room, sim.view,
				room_sim().local_view if room_sim() else "-", sim.tide(), sim.weather_band()],
			"1-9 room stage jumps, Shift+1-9 start of tide I-IX",
			"objective: " + (room_sim().objective() if room_sim() else ""),
			"flags: " + ", ".join(sim.state.flags.keys())]:
		c.draw_string(serif, Vector2(34, y), line, HORIZONTAL_ALIGNMENT_LEFT, 600, 18, Color.WHITE)
		y += 34
	if room_view:
		for r in room_view.dev_rects():
			c.draw_rect(r, Color(1, 0, 1, 0.6), false, 2)
		for r in room_view.live_exit_rects().values():
			c.draw_rect(r, Color(0, 1, 1, 0.6), false, 2)
