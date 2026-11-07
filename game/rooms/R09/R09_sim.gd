class_name R09Sim
extends RoomSim
## R09, the Lantern Gallery. Owns P15, The Horizon Behind You (Tide V; card
## docs/design/puzzle-cards/P15.md) and the O05 ruler.
##
## Two base views (not close-ups): view A "room" (the lens, the three apertures, the scope,
## the reference diagram) and view B "rail" (the sill, the pennant, the rail, the horizon, the
## glass). Close-ups: c_scope (the frame clamp, the aperture selector, the scope view, RECORD
## BEARING) and c_ruler (the boxwood rule, after P15).
##
## P15: mount Nora's frame, aim at STATION 3 (a reflection of the rooms behind her), confirm
## the square-patched bowl with the inspection lens, RECORD BEARING. LAND and SEA print NO
## SUBJECT; STATION 3 unconfirmed is refused by the contract rule. The frame always comes
## back. The upright-sea reveal plays on leaving the scope (or on the next arrival or return
## from the notebook), once.
##
## Node-free and deterministic. The weather comes from game.weather_band(), never a clock.

const ID := "R09"
const TITLE := "Lantern Gallery"
const REQUIRES := ["P12"]
const LOCKED := "The gallery stair goes up from the dry stair's first landing. That way isn't open."
const RESUME := "Back in the lantern gallery."
const WAY_IN_HINT := "The short stair off the dry stair's landing goes up to the lantern gallery now."
const ARRIVAL := "The lantern gallery. The rain has stopped touching the rail."
const ARRIVAL_2 := "It falls a hand's width off it, all the way round. The pennant hangs dead, and the wind's loud."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R11", "Stair", []],
]
## View A ("room"), in hit order.
const HOTSPOTS := ["lens", "aperture_1", "aperture_2", "aperture_3", "scope", "diagram", "to_rail"]
## View B ("rail"): a base view, not a close-up.
const RAIL_HOTSPOTS := ["ruler", "pennant", "rail", "horizon", "glass", "to_lens"]
const CLOSEUPS := ["c_scope", "c_ruler"]
const SCOPE_CONTROLS := ["mount", "sel_1", "sel_2", "sel_3", "scope_view", "record", "strip_slot", "ref_plate"]
const RULER_CONTROLS := ["ruler_face", "zoom_in", "zoom_out"]

const APERTURES := {1: "LAND 1", 2: "SEA 2", 3: "STATION 3"}
const DIAGRAM_TEXT := "Bearing follows the recorded subject's location, not the water. Match the relation mark."
const STRIP_LINES := ["BEARING  STATION 3", "SUBJECT  BELL, N.", "RELATION  CONFIRMED"]
const NO_SUBJECT := "NO SUBJECT ON BEARING."
const CONTRACT_RULE := "Do not certify an observation you have not made."
const UNCONFIRMED := "It looks like the bowl. I'd want to see the patch before I record it."
const RECORD_REFUSED := "The key won't go down. The clamp is empty."
const FRAME_IN_CLAMP := "Her frame's still in the clamp."
## The view A glass, where the reward (the standing sea) is seen.
const GLANCE_P15 := [52, 162, 1344, 466]

## Band notices, keyed to bands 3..7: one plays on the first arrival in its band.
const NOTICES := ["dry_rail", "upright", "no_sky", "lighthouse_inverted", "no_edge"]
## notice -> {lines: [[text, delay], ...], observe: [ids]}
const NOTICE_LINES := {
	"dry_rail": {"lines": [["The rail's still dry.", 0.0]], "observe": ["rail"]},
	"upright": {"lines": [["The horizon's standing up.", 0.0]], "observe": ["upright"]},
	"no_sky": {"lines": [["It fills the glass now. There's no sky left at the top.", 0.8]], "observe": ["no_sky"]},
	"lighthouse_inverted": {"lines": [["There's a lighthouse in it. Upside down.", 0.8],
			["And the pennant's standing straight out. There's no wind.", 3.0]],
		"observe": ["lighthouse_inverted", "pennant_out"]},
	"no_edge": {"lines": [["It has no edge any more.", 0.8], ["And the lens has me in it. The right way up.", 3.2]],
		"observe": ["no_edge", "lens_ada"]},
}
## The reveal after P15 (story chain): [delay, text].
const REVEAL_LINES := [
	[0.6, "The horizon's standing up."],
	[6.8, "It's not the sea any more. It's a surface, on end, and the rooms behind me are in it."],
	[9.6, "The office lamp is in it. A warm point."],
	[13.4, "Something passed across the whole of it. Like a lid."],
	[16.0, "It hasn't closed again."],
]
## After the sever ending, these replace the normal lines.
const SEVER_LINES := {
	"lens": "The lens. The gallery's in it, upside down. Me too.",
	"pennant": "It flaps. Wind, at last.",
	"rail": "Wet. Rain beads along it and runs off.",
	"horizon": "A horizon. Level.",
	"glass": "Grey water, grey sky, and a line between them.",
}
const MISS_LINES := {
	1: ["The causeway. Nothing of hers on it.", "Land. The diagram wants the subject, not the coast."],
	2: ["Open water. The diagram says the bearing follows the subject, not the water.", "Sea again. Nothing of hers is out there."],
}
const FRAME_TARGETS := ["lens", "aperture_1", "aperture_2", "aperture_3", "diagram", "glass", "rail", "horizon",
	"pennant", "ruler", "sel_1", "sel_2", "sel_3", "scope_view", "record"]

const OBSERVATIONS := {
	"rail": "The gallery rail is dry. The rain falls a hand's width away from it, all the way round.",
	"pennant": "A pennant on the rail staff. The wind is loud up here, and the pennant hangs dead straight down.",
	"lens": "The signal lens, cold and taller than I am. The gallery is in it, upside down: everything except me.",
	"apertures": "Three apertures in the lantern housing, each with an iris and an enamel plate: LAND 1, SEA 2, STATION 3. The scope sights through whichever iris is open.",
	"scope": "A sighting scope on a brass arm: a clamp for a specimen frame, a three-position aperture selector, and a key, RECORD BEARING.",
	"diagram": "Reference plate by the scope: 'Bearing follows the recorded subject's location, not the water. Match the relation mark.' The drawing joins a FRAME to a SUBJECT by the relation mark, two linked strokes, printed RELATION. The water is bracketed off: BOUNDARY.",
	"view_land": "Through LAND 1: the headland, and the old causeway breaking off short of it. Nothing of anyone's on it.",
	"view_sea": "Through SEA 2: open water all the way to the horizon. Nothing on it.",
	"view_station": "Through STATION 3 the scope looks back through the glass at the rooms behind me, one behind another: the office lamp, the mess table, a bowl at the cross. The horizon runs behind my reflected shoulder.",
	"bowl_patch": "Under the lens, the bowl in the STATION 3 reflection has a square patch riveted over a crack: Nora's mending, the ninth bowl. There is soup in it, steaming.",
	"no_subject": "RECORD BEARING on LAND or SEA prints an empty diagram: NO SUBJECT ON BEARING.",
	"nora_bearing": "Nora Bell's bearing is not out at sea. It is inside the station: STATION 3, the bowl with the square patch.",
	"upright": "After the bearing printed, the sea outside the glass stood up: a flat surface on end, carrying the rooms behind me, the office lamp a warm point in it. A slow line passed across the whole of it, like a lid opening. It has not closed.",
	"glass": "Rain runs down outside the lantern glass, slower than rain should.",
	"glass_dead": "The lantern glass doesn't ring when I tap it.",
	"horizon": "A conventional horizon. For now.",
	"no_sky": "The surface fills the glass edge to edge. No sky left.",
	"lighthouse_inverted": "A lighthouse hangs in the surface, upside down, as if reflected from somewhere behind the station.",
	"pennant_out": "The pennant stands straight out toward the glass. There is no wind.",
	"no_edge": "The surface has no edge. The lantern would be lost in it: less than a tenth of what I can see.",
	"lens_ada": "The signal lens has me in it now, the right way up, and nearer than I'm standing.",
	"sill": "A bare sill in the lantern, salt in the grain.",
	"ruler": "A boxwood rule on the lantern sill, inches in eighths, every mark scratched deeper by hand.",
	"ruler_subdivisions": "Under the lens the rule's subdivisions keep going between the printed marks: tens inside tens, all scratched by hand. I stopped looking. They didn't stop.",
	"rail_wet": "Rain on the rail at last. It beads and runs off, like rain.",
}
const OBJECTIVES := {
	"wait_p14": "The scope's clamp is empty. Nora's frame is still being made on the laboratory bench.",
	"p15": "Find Nora's bearing: mount her frame on the scope and record where she is.",
	"done": "Her bearing is recorded: STATION 3. The records vault is open from the laboratory.",
}
const HINTS := {
	"p15": [
		"The lantern's scope takes the specimen frame.",
		"The diagram says aim where the subject is, not where the water is. Look for something of hers.",
		"Mount the frame, aim at STATION 3, check the square-patched bowl with the lens, then RECORD BEARING.",
	],
	"wait_p14": [
		"The scope's clamp takes a specimen frame. The laboratory makes them.",
		"Nora's frame is built on the laboratory bench.",
		"Finish Nora's frame in the wet laboratory, then bring it up the stair.",
	],
	"done": [
		"The gallery's bearing is recorded.",
		"The laboratory's RECORDS door let go of its latch.",
		"Go down to the wet laboratory and through the RECORDS door.",
	],
}
## Items this room hands out (docs/design/puzzle-cards/flags.md section 4).
const ITEMS := {
	"nora_spatial_strip": {"name": "Bearing strip: N. Bell", "short": "Bearing strip",
		"desc": "A bearing strip printed by the gallery scope: BEARING STATION 3, SUBJECT BELL, N."},
}

const SAVED_BOOLS := ["frame_mounted", "patch_confirmed", "p15_complete", "reveal_seen", "scope_seen", "rail_seen"]

## Transient (never saved): what the last RECORD printed, for the scope overlay
## ("" | "nosubject" | "recorded"), and the ruler loupe level 0..3.
var last_record := ""
var ruler_zoom := 0

func initial_state() -> Dictionary:
	return {"aperture": 2, "frame_mounted": false, "patch_confirmed": false, "seen_views": [],
		"p15_complete": false, "reveal_seen": false, "record_miss": 0, "notices": [],
		"scope_seen": false, "rail_seen": false}

func is_closeup(v := local_view) -> bool:
	return v in CLOSEUPS

# ---------------------------------------------------------------------------------------------
# read-only helpers for the view
# ---------------------------------------------------------------------------------------------
func band() -> int:
	return game.weather_band()

func ending() -> String:
	return str(game.value("ending_choice"))

func _sever() -> bool:
	return ending() == "sever"

func sea_stage() -> String:
	return "sever" if _sever() else "b%d" % clampi(band(), 3, 7)

func scope_scene() -> String:
	if state.p15_complete:
		return "surface"
	return {1: "land", 2: "sea", 3: "station"}.get(int(state.aperture), "sea")

func patch_shown() -> bool:
	return int(state.aperture) == 3 and state.patch_confirmed and not state.p15_complete

func pennant_mode() -> String:
	if _sever():
		return "flap"
	return "out" if band() >= 6 else "dead"

func lens_reflection() -> String:
	if _sever():
		return "ada_inv"
	return "ada" if band() >= 7 else "empty"

func rail_wet() -> bool:
	return _sever()

func ruler_shown() -> bool:
	return state.p15_complete

func iris_open(n: int) -> bool:
	return int(state.aperture) == n

func current_notice() -> String:
	if ending() != "":
		return ""
	return NOTICES[clampi(band(), 3, 7) - 3]

func reveal_due() -> bool:
	return state.p15_complete and not state.reveal_seen

# ---------------------------------------------------------------------------------------------
# arrival, notices, the reveal
# ---------------------------------------------------------------------------------------------
func arrive(ev: Array, first: bool) -> void:
	_sync()
	local_view = "room"
	if first:
		_say(ev, ARRIVAL, 0.0, true)
		_say(ev, ARRIVAL_2, 2.6, true)
		_observe("rail")
		_observe("pennant")
		_fx(ev, "notice_dry_rail")
		_mark_notice("dry_rail")
	if reveal_due():
		_reveal(ev)
		return
	var n := current_notice()
	if n != "" and not n in state.notices:
		_fx(ev, "notice_" + n)
		_mark_notice(n)
		var entry: Dictionary = NOTICE_LINES[n]
		for l in entry.lines:
			_say(ev, l[0], l[1])
		for o in entry.observe:
			_observe(o)

## Marks `n` and every older notice as seen.
func _mark_notice(n: String) -> void:
	var k := NOTICES.find(n)
	for i in k + 1:
		if not NOTICES[i] in state.notices:
			state.notices.append(NOTICES[i])

## The sea stands up. Once, after P15: from back() leaving the scope, arrive() or
## on_core_return(), whichever comes first.
func _reveal(ev: Array) -> void:
	state.reveal_seen = true
	_mark_notice("upright")
	_observe("upright")
	_fx(ev, "reveal_upright")
	_sfx(ev, "deep_tone", 0.4)
	_sfx(ev, "lid_pass", 7.0)
	for l in REVEAL_LINES:
		_say(ev, l[1], l[0], true)

# ---------------------------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------------------------
func act(action: String, ev: Array) -> void:
	_sync()
	if local_view == "c_scope" and action in SCOPE_CONTROLS:
		_scope(action, ev)
	elif local_view == "c_ruler" and action in RULER_CONTROLS:
		_ruler(action, ev)
	elif action in HOTSPOTS:
		if local_view == "c_scope" and state.frame_mounted:
			_unmount(ev)
		local_view = "room"
		_room(action, ev)
	elif action in RAIL_HOTSPOTS:
		if local_view == "c_scope" and state.frame_mounted:
			_unmount(ev)
		local_view = "rail"
		_rail(action, ev)

## Says the sever line for `action` and returns true, if the sever ending has one.
func _sever_line(action: String, ev: Array) -> bool:
	if _sever() and SEVER_LINES.has(action):
		_say(ev, SEVER_LINES[action])
		return true
	return false

func _aperture_of(action: String) -> int:
	return int(action.substr(action.length() - 1))

# --- view A ----------------------------------------------------------------------------------
func _room(action: String, ev: Array) -> void:
	match action:
		"lens":
			_sfx(ev, "lens_touch")
			if _sever_line(action, ev):
				_observe("lens")
			elif band() >= 7:
				_say(ev, "I'm in it now. The right way up. Nearer than I'm standing.")
				_observe("lens_ada")
			else:
				_say(ev, "The signal lens. Cold, and taller than I am.")
				_say(ev, "The gallery's in it, upside down. All of it except me.", 2.2)
				_observe("lens")
		"aperture_1", "aperture_2", "aperture_3":
			var n := _aperture_of(action)
			if n == 3 and state.p15_complete:
				_say(ev, "STATION 3. The bearing I recorded.")
			else:
				var iris := " The iris is open: the scope's sighting through it." if iris_open(n) else " The iris is shut."
				_say(ev, APERTURES[n] + ". A port in the lantern housing, with an iris." + iris)
			_observe("apertures")
		"scope":
			_open_scope(ev)
			if not state.scope_seen:
				state.scope_seen = true
				_say(ev, "A sighting scope on a brass arm. A clamp for a specimen frame, a selector, and a key: RECORD BEARING.")
				if int(state.aperture) == 2:
					_say(ev, "It's on SEA 2. Open water, all the way out.", 2.4)
			else:
				_say(ev, "The scope.")
		"diagram":
			_say(ev, "A reference plate: '" + DIAGRAM_TEXT + "' The mark is two linked strokes, printed RELATION.")
			_observe("diagram")
		"to_rail":
			local_view = "rail"
			if not state.rail_seen:
				state.rail_seen = true
				_say(ev, "The rail side. Glass all round, and the sea past it.")
			else:
				_say(ev, "The rail.")

## Into the scope close-up. The first look sees SEA 2 (the default aperture).
func _open_scope(ev: Array) -> void:
	local_view = "c_scope"
	_sfx(ev, "scope_creak")
	_observe("scope")
	if int(state.aperture) == 2 and not state.p15_complete:
		_add_seen_view(2)
		_observe("view_sea")

func _add_seen_view(n: int) -> void:
	if not n in state.seen_views:
		state.seen_views.append(n)

# --- view B ----------------------------------------------------------------------------------
func _rail(action: String, ev: Array) -> void:
	var b := band()
	match action:
		"ruler":
			if not state.p15_complete:
				_say(ev, "A bare sill. Salt in the grain.")
				_observe("sill")
			else:
				_open_ruler(ev)
				_say(ev, "A boxwood rule on the sill. It wasn't here before.")
				_observe("ruler")
		"pennant":
			if _sever_line(action, ev):
				pass
			elif b <= 5:
				_say(ev, "A pennant on the rail staff. The wind's loud up here, and it hangs straight down.")
				_observe("pennant")
			else:
				_say(ev, "It stands straight out toward the glass. There's no wind.")
				_observe("pennant_out")
		"rail":
			if _sever_line(action, ev):
				_observe("rail_wet")
			else:
				if b <= 3:
					_say(ev, "The rail is dry. The rain is falling a hand's width away from it.")
				elif b <= 6:
					_say(ev, "Still dry. The surface stands just past it.")
				else:
					_say(ev, "Dry. Past it there's only the surface.")
				_observe("rail")
		"horizon":
			if _sever_line(action, ev):
				pass
			elif b <= 3:
				_say(ev, "A conventional horizon. For now.")
				_observe("horizon")
			elif b == 4:
				_say(ev, "There's no horizon. The sea goes straight up to the roof.")
				_observe("upright")
			elif b == 5:
				_say(ev, "No horizon. No sky.")
				_observe("no_sky")
			elif b == 6:
				_say(ev, "The lighthouse hangs where the horizon was. Upside down.")
				_observe("lighthouse_inverted")
			else:
				_say(ev, "There's nothing to measure it against.")
				_observe("no_edge")
		"glass":
			_sfx(ev, "glass_tap" if b <= 4 or _sever() else "glass_tap_dead")
			if _sever_line(action, ev):
				pass
			elif b <= 3:
				_say(ev, "The rain's running down outside. Slowly. Slower than rain.")
				_observe("glass")
			elif b == 4:
				_say(ev, "Behind the glass the sea stands on end, and the rooms behind me are in it.")
				_observe("upright")
			else:
				_say(ev, "I tapped it. It didn't ring.")
				_observe("glass_dead")
		"to_lens":
			local_view = "room"
			_say(ev, "The lens.")

func _open_ruler(ev: Array) -> void:
	local_view = "c_ruler"
	ruler_zoom = 0
	_sfx(ev, "ruler_lift")

# --- c_scope: P15 ----------------------------------------------------------------------------
func _scope(action: String, ev: Array) -> void:
	match action:
		"mount":
			last_record = ""
			if state.frame_mounted:
				_unmount(ev)
			else:
				_sfx(ev, "mount_tap")
				if state.p15_complete:
					_say(ev, "Empty. Her frame's with me.")
				elif game.has_item("nora_frame"):
					_say(ev, "The clamp's open. Her frame would seat in it.")
				else:
					_say(ev, "The clamp takes a specimen frame. I haven't got one.")
		"sel_1", "sel_2", "sel_3":
			_select(_aperture_of(action), ev)
		"scope_view":
			_scope_view(ev)
		"record":
			_record(ev)
		"strip_slot":
			_say(ev, "The strip's with me." if state.p15_complete else "A slot for the strip. Empty.")
		"ref_plate":
			_say(ev, "'" + DIAGRAM_TEXT + "'")
			_observe("diagram")

## The frame off the clamp and back in her hands. Every path out of the scope goes through
## here, so the frame is never left behind.
func _unmount(ev: Array) -> void:
	state.frame_mounted = false
	last_record = ""
	game.give("nora_frame", ev)
	_sfx(ev, "clamp_release")
	_fx(ev, "frame_eject")
	_say(ev, "I take her frame off the clamp.")

func _select(n: int, ev: Array) -> void:
	if int(state.aperture) == n:
		_say(ev, APERTURES[n] + ". It's already there.")
		return
	state.aperture = n
	state.patch_confirmed = false
	last_record = ""
	_sfx(ev, "sel_click")
	_sfx(ev, "iris_turn", 0.25)
	_fx(ev, "aim", {"aperture": n})
	if state.p15_complete:
		_say(ev, APERTURES[n] + ". The surface. Every bearing finds it now.")
		return
	if not n in state.seen_views:
		state.seen_views.append(n)
		match n:
			1:
				_say(ev, "LAND 1. The headland, and the causeway breaking off short of it.")
				_observe("view_land")
			2:
				_say(ev, "SEA 2. Open water, all the way out. Nothing on it.")
				_observe("view_sea")
			3:
				_sfx(ev, "glass_hum", 0.6)
				_say(ev, "STATION 3. It isn't pointing out. It's looking back through the glass.", 0.4, true)
				_say(ev, "The rooms behind me, one behind another. The office lamp. The mess table. A bowl, at the cross.", 3.0, true)
				_say(ev, "And my own shoulder. The horizon runs behind it. Behind me, not behind the glass.", 6.4, true)
				_observe("view_station")
	else:
		_say(ev, ["", "LAND 1.", "SEA 2.", "STATION 3. The rooms behind me."][n])

func _scope_view(ev: Array) -> void:
	if state.p15_complete:
		_say(ev, "The surface. Under the glass it looks like skin.")
		return
	match int(state.aperture):
		1:
			_say(ev, "The headland, and the causeway breaking off short of it.")
			_observe("view_land")
		2:
			_say(ev, "Open water, all the way out.")
			_observe("view_sea")
		_:
			if state.patch_confirmed:
				_say(ev, "Her bowl. The square patch, riveted. Soup in it, steaming.")
			else:
				_say(ev, "The bowl's at the cross. It looks like hers. I can't see the patch from here.")
			_observe("view_station")

## RECORD BEARING: the commit.
func _record(ev: Array) -> void:
	if state.p15_complete:
		_sfx(ev, "record_key")
		_say(ev, "Recorded already. The strip's with me.")
		return
	if not state.frame_mounted or not game.flag("P14"):
		_sfx(ev, "key_refuse")
		_say(ev, RECORD_REFUSED)
		return
	var a := int(state.aperture)
	if a == 1 or a == 2:
		_sfx(ev, "record_key")
		_sfx(ev, "nosubject_print", 0.3)
		_fx(ev, "no_subject")
		last_record = "nosubject"
		_say(ev, NO_SUBJECT, 0.5)
		_say(ev, MISS_LINES[a][int(state.record_miss) % 2], 1.8)
		state.record_miss = mini(int(state.record_miss) + 1, 99)
		_observe("no_subject")
		return
	if not state.patch_confirmed:
		# The contract rule: the key is not pressed, so no key sound.
		_say(ev, UNCONFIRMED, 0.0)
		_say(ev, CONTRACT_RULE, 2.2)
		return
	state.p15_complete = true
	state.frame_mounted = false
	last_record = "recorded"
	_sfx(ev, "record_key", 0.0)
	_fx(ev, "record_key")
	game.solve("P15", ev)
	_sfx(ev, "strip_feed", 0.25)
	_fx(ev, "strip_feed")
	game.give("nora_spatial_strip", ev)
	_say(ev, "Recorded. The strip feeds out: BEARING, STATION 3. SUBJECT, BELL, N.", 0.5, true)
	_sfx(ev, "clamp_release", 1.8)
	_fx(ev, "frame_eject")
	game.give("nora_frame", ev)
	_observe("nora_bearing")
	_say(ev, "Her bearing isn't out at sea. It's in here, with the bowl.", 2.6, true)
	_fx(ev, "glance", {"rect": GLANCE_P15, "target": "lens"})

# --- c_ruler: O05 ----------------------------------------------------------------------------
func _ruler(action: String, ev: Array) -> void:
	match action:
		"ruler_face":
			_say(ev, "A boxwood rule. Inches, in eighths. Every mark scratched deeper by hand.")
			_observe("ruler")
		"zoom_in":
			_zoom_in(ev)
		"zoom_out":
			ruler_zoom = maxi(ruler_zoom - 1, 0)
			_say(ev, "That's the whole rule." if ruler_zoom == 0 else "Back out.")

func _zoom_in(ev: Array) -> void:
	if not game.has_item("inspection_lens"):
		_say(ev, "I'd want a lens for this.")
		return
	_sfx(ev, "loupe_step")
	if _sever():
		ruler_zoom = 1
		_say(ev, "Eighths. Under the lens, only eighths. And the grain of the wood.")
		return
	ruler_zoom = mini(ruler_zoom + 1, 3)
	match ruler_zoom:
		1:
			_say(ev, "Between two eighths: more marks. Finer. Ten of them.")
		2:
			_say(ev, "Between those, more. Still even. Still scratched in by hand.")
		_:
			if not game.flag("o05_found"):
				game.set_flag("o05_found")
				_observe("ruler_subdivisions")
				_say(ev, "They go on.", 0.0, true)
				_say(ev, "There's no bottom to it. Someone scratched every one.", 2.2, true)
			else:
				_say(ev, "Still going.")

# ---------------------------------------------------------------------------------------------
# back, exits, core returns
# ---------------------------------------------------------------------------------------------
func back(ev: Array) -> void:
	_sync()
	match local_view:
		"c_scope":
			if state.frame_mounted:
				_unmount(ev)
			last_record = ""
			local_view = "room"
			if reveal_due():
				_reveal(ev)
		"c_ruler":
			local_view = "rail"
		_:
			local_view = "room"

func exit_block(_to: String) -> String:
	return FRAME_IN_CLAMP if state.frame_mounted else ""

func on_core_return(_from: String, ev: Array) -> void:
	if reveal_due() and local_view == "room":
		_reveal(ev)

# ---------------------------------------------------------------------------------------------
# inventory
# ---------------------------------------------------------------------------------------------
func use_item(item: String, target: String, ev: Array) -> bool:
	_sync()
	match item:
		"nora_frame":
			return _use_frame(target, ev)
		"inspection_lens":
			return _use_lens(target, ev)
		"nora_spatial_strip":
			if local_view == "c_scope" and target in ["record", "strip_slot", "scope_view"]:
				_say(ev, "It's printed. It doesn't go back in.")
				return true
		"pencil":
			if target == "diagram" or (target == "ref_plate" and local_view == "c_scope"):
				_say(ev, "Not mine to amend.")
				return true
	return false

func _use_frame(target: String, ev: Array) -> bool:
	var mount_here := target == "mount" and local_view == "c_scope"
	var scope_here := target == "scope" and not is_closeup()
	if mount_here or scope_here:
		if scope_here:
			_open_scope(ev)
			state.scope_seen = true
		if state.p15_complete:
			_say(ev, "It's recorded. She doesn't need placing twice.")
			return true
		if state.frame_mounted:
			_say(ev, "It's in the clamp.")
			return true
		game.take("nora_frame")
		state.frame_mounted = true
		last_record = ""
		_sfx(ev, "mount_clamp")
		_fx(ev, "frame_mount")
		_say(ev, "It seats in the clamp. Her relation mark shows in the reticle.")
		return true
	if target in FRAME_TARGETS:
		_say(ev, "The frame goes on the scope's clamp.")
		return true
	return false

func _use_lens(target: String, ev: Array) -> bool:
	var b := band()
	match target:
		"scope_view":
			if local_view != "c_scope":
				return false
			_sfx(ev, "lens_slide")
			last_record = ""
			if state.p15_complete:
				_say(ev, "The surface has a grain under the lens. It isn't water.")
			elif int(state.aperture) == 1:
				_say(ev, "The causeway's end, under the lens. Nothing on it.")
			elif int(state.aperture) == 2:
				_say(ev, "Water. Under the lens it's still only water.")
			elif state.patch_confirmed:
				_say(ev, "The square patch. Four rivets. It's hers.")
			else:
				state.patch_confirmed = true
				_fx(ev, "lens_patch")
				_say(ev, "Under the lens: a square patch, riveted over a crack. Nora's mending. The ninth bowl.", 0.2, true)
				_say(ev, "There's soup in it. Still steaming.", 2.8, true)
				_observe("bowl_patch")
			return true
		"lens":
			_say(ev, "My face is in every ring." if b >= 7 and not _sever() else "The prisms are cut by hand, ring by ring.")
			return true
		"aperture_1", "aperture_2", "aperture_3":
			_say(ev, "Each iris has nine blades.")
			return true
		"diagram", "ref_plate":
			_say(ev, "Engraved, not printed. RELATION is cut deeper than the rest.")
			return true
		"scope":
			_say(ev, "The clamp's jaws are worn bright. It's held frames before.")
			return true
		"glass", "horizon":
			if _sever():
				_say(ev, "Rain. Ordinary rain." if target == "glass" else "Level. Only level.")
			elif b <= 3:
				_say(ev, "The drops are moving. Down, but slowly." if target == "glass" else "Level. Perfectly level. Too level.")
			else:
				_say(ev, "The surface has a grain under the lens. It isn't water.")
			return true
		"rail":
			_say(ev, "Wet through." if _sever() else "Not a drop. Not even salt.")
			return true
		"pennant":
			_say(ev, "Wool, salt-stiff. Not a thread moving.")
			return true
		"ruler":
			if state.p15_complete:
				_open_ruler(ev)
				_zoom_in(ev)
			else:
				_say(ev, "Salt crystals. Nothing else.")
			return true
		"ruler_face", "zoom_in":
			if local_view == "c_ruler":
				_zoom_in(ev)
				return true
	return false

# ---------------------------------------------------------------------------------------------
# objectives
# ---------------------------------------------------------------------------------------------
func objective() -> String:
	_sync()
	if state.p15_complete:
		return "done"
	if not game.flag("P14"):
		return "wait_p14"
	return "p15"

# ---------------------------------------------------------------------------------------------
# load, sync, reconcile
# ---------------------------------------------------------------------------------------------
func _clear_transient() -> void:
	last_record = ""
	ruler_zoom = 0

func load_state(d: Variant) -> void:
	state = initial_state()
	_clear_transient()
	if not d is Dictionary:
		return
	for k in SAVED_BOOLS:
		if d.get(k) is bool:
			state[k] = d[k]
	var a = d.get("aperture")
	if _all_whole([a]) and int(a) >= 1 and int(a) <= 3:
		state.aperture = int(a)
	var m = d.get("record_miss")
	if _all_whole([m]):
		state.record_miss = clampi(int(m), 0, 99)
	if d.get("seen_views") is Array:
		for v in d.seen_views:
			if _all_whole([v]) and int(v) in [1, 2, 3] and not int(v) in state.seen_views:
				state.seen_views.append(int(v))
	if d.get("notices") is Array:
		for n in d.notices:
			if n is String and n in NOTICES and not n in state.notices:
				state.notices.append(n)
	state.patch_confirmed = state.patch_confirmed and int(state.aperture) == 3
	if state.p15_complete:
		_set_done()
	else:
		state.reveal_seen = false

## The P15-done arrangement of the scope.
func _set_done() -> void:
	state.p15_complete = true
	state.aperture = 3
	state.patch_confirmed = true
	for v in [1, 2, 3]:
		_add_seen_view(v)
	state.frame_mounted = false

## A P15 flag set elsewhere (tests, debug) is honoured. Never gives items, never clears.
func _sync() -> void:
	if game.flag("P15") and not state.p15_complete:
		_set_done()

## P15 follows the state. A save made with the frame in the clamp (local_view is never saved)
## loads with the frame back in her inventory.
func reconcile() -> void:
	_sync()
	if state.frame_mounted:
		state.frame_mounted = false
		if game.flag("P14") and not game.has_item("nora_frame"):
			game.give("nora_frame")
	game.set_flag("P15", state.p15_complete)

# ---------------------------------------------------------------------------------------------
# debug
# ---------------------------------------------------------------------------------------------
const DONE_SEEN := ["rail", "pennant", "lens", "apertures", "scope", "diagram", "view_land", "view_sea",
	"view_station", "bowl_patch", "nora_bearing", "upright", "horizon", "glass"]

func debug_prepare(t: int) -> void:
	if t >= 6:
		_set_done()
		state.reveal_seen = true
		state.scope_seen = true
		for o in DONE_SEEN:
			_observe(o)
		if not game.has_item("nora_spatial_strip"):
			game.give("nora_spatial_strip")
	if t >= 5:
		var n := current_notice()
		var k := NOTICES.find(n) if n != "" else NOTICES.size()
		for i in k:
			if not NOTICES[i] in state.notices:
				state.notices.append(NOTICES[i])

## Dev stages: 1 Tide V fresh, 2 P14 done with the frame in hand, 3 the frame mounted on
## STATION 3, 4 the patch confirmed (RECORD wins), 5-8 the start of Tides VI-IX, 9 Tide IX on
## the rail side.
func debug_jump(n: int) -> void:
	if n <= 4:
		game.debug_tide(5, ID)
		if n >= 2:
			game.set_flag("P13")
			game.set_flag("P14")
			game.room("R07").reconcile()
			game.give("nora_frame")
			_mark_notice("dry_rail")
		_clear_transient()
		reconcile()
		if n >= 3:
			local_view = "c_scope"
			game.take("nora_frame")
			state.frame_mounted = true
			state.aperture = 3
			state.seen_views = [2, 3]
			state.scope_seen = true
			_observe("scope")
			_observe("view_sea")
			_observe("view_station")
		if n >= 4:
			state.patch_confirmed = true
			_observe("bowl_patch")
		return
	game.debug_tide(clampi(n + 1, 6, 9), ID)
	local_view = "rail" if n == 9 else "room"
	_clear_transient()
	reconcile()
