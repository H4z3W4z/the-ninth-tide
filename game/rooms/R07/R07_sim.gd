class_name R07Sim
extends RoomSim
## R07, the Wet Laboratory. Owns P10 (the jar that follows the datum), P13 (the mass that
## answers to a name) and P14 (Nora's breath in the specimen frame): docs/design/puzzle-cards/
## P10.md, P13.md, P14.md and rooms.md R07. Node-free and deterministic; the view reads the
## helpers below and the transient vars (last_test, balance_note, held, frame_miss) and plays
## the events.
##
## Two base views: "room" (A, the tank wall) and "bench" (B, the specimen bench; not a
## close-up). Close-ups: c_tilt_rack (P10), c_balance (P13), c_frame (P14).

const ID := "R07"
const TITLE := "Wet Laboratory"
const REQUIRES := ["P09"]
const LOCKED := "The laboratory door is behind the kitchen's service access. It's sealed."
const RESUME := "Back in the wet laboratory."
const ARRIVAL := "The wet laboratory. Three sealed jars of seawater on a canted rack, all half full."
## The first arrival once the weather has reached the lab (band >= 2, which is every real first
## visit: the hatch opens at P09).
const ARRIVAL_WET := "The wet laboratory. Three sealed jars of seawater on a canted rack. The water in all three leans toward the stair door."
## The way in, for the core's hint toward this room.
const WAY_IN_HINT := "The hatch in the kitchen floor is open: the laboratory and the machine room."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R05", "Kitchen", []],
	["R10", "Records vault", []],
	["R11", "Stair door", ["P12"]],
	["R08", "Machine room", []],
]

## View A (the tank wall) and view B (the bench) hotspots, in hit order.
const HOTSPOTS := ["jar_a", "jar_b", "jar_c", "reference_socket", "datum_line", "basin", "tilt_rack",
	"tank", "vault_door", "return_door", "to_bench"]
const BENCH_HOTSPOTS := ["control_tray", "balance", "sample_cards", "register", "frame_stand",
	"sealed_jar", "sample_rack", "to_tank"]
const CLOSEUPS := ["c_tilt_rack", "c_balance", "c_frame"]
## Close-up controls (never the same id as a hotspot).
const RACK_CONTROLS := ["rest_a", "rest_b", "rest_c", "cradle", "tip", "seat", "test_card", "ref_card",
	"socket"]
const BALANCE_CONTROLS := ["smp_n", "smp_w", "smp_f", "pan", "tray", "holder", "gauge", "cards",
	"key_address", "key_release", "key_record", "strip", "reg_bell", "reg_doane", "reg_hart",
	"reg_ives", "reg_lusk", "reg_pryce", "reg_rook", "reg_tull"]
const FRAME_CONTROLS := ["ref_card", "sec_short", "sec_pause", "sec_long", "slot_0", "slot_1", "slot_2",
	"name_tab", "strip_clip", "seal"]

# --- P10: three jars, three rules ------------------------------------------------------------
const JARS := ["A", "B", "C"]
## What each jar's surface follows: the plumb line, the jar itself, or the station datum.
const JAR_RULE := {"A": "gravity", "B": "jar", "C": "datum"}
## Angles in degrees against the room (the datum). Gravity is eight degrees off the walls.
const GRAVITY_DEG := -8.0
const DATUM_DEG := 0.0
const RACK_CANT_DEG := 12.0
const TIP_DEG := 90.0
const LEAN_DEG := 34.0
const PANE_DEG := -58.0
## Bands 4-6, room view only: every jar and the tank lean this far toward the STAIR door (their
## surfaces fall toward it, on the left), whatever the rack's cant or a jar's rule. The c_tilt_rack
## close-up and its test card keep their geometry: P10 is untouched.
const STAIR_LEAN_DEG := -12.0
## Appended to the P14 reveal chain (the fogged jar), and kept in the notebook.
const DOWN_LINE := "All of it leans the same way. Down."
const REF_CARD := "A valid sample keeps the station's own level: the brass, not the bob, not the glass."
const TAG_TEXT := "DATUM READING STABLE. STAIR PRESSURE TARGET: 2."
## At rest the three look alike: only a tip on the rack tells them apart.
const JAR_LINES := {
	"A": "Jar A. Half full. Sealed with wax.",
	"B": "Jar B. Half full. Sealed with wax.",
	"C": "Jar C. Half full. Sealed with wax.",
}
const TIP_SFX := {"A": "slosh_a", "B": "glass_creak_b", "C": "slosh_c"}
const TIP_LINES := {
	"A": "It stayed level with the plumb bob.",
	"B": "It turned with the jar.",
	"C": "It stayed square with the room, whatever the jar did.",
}
const UNTESTED := " The socket's tag says UNTESTED. Tip it on the rack first."

# --- P13: the balance ------------------------------------------------------------------------
## Internal sample ids (saved as state.pan; the controls are smp_n / smp_w / smp_f). Nothing the
## player sees carries these letters: each sample is shown only by its specimen number.
const SAMPLES := ["N", "W", "F"]
## Specimen numbers. Nora's is 27-11; her kitchen work card (R05) carries the same number.
const SPECIMEN := {"W": "27-03", "N": "27-11", "F": "27-19"}
## Left to right on the stands and the sample cards: by specimen number.
const SAMPLE_ORDER := ["W", "N", "F"]
## Drams across UNATTENDED / ADDRESSED / RELEASED. N answers only to BELL.
const READINGS := {"N": [0, 3, 0], "W": [0, 0, 0], "F": [2, 2, 2]}
const FLAT := [0, 0, 0]
const NAMES := ["BELL", "DOANE", "HART", "IVES", "LUSK", "PRYCE", "ROOK", "TULL"]
const REGISTER := {
	"BELL": "BELL, N. Cook and caretaker.",
	"DOANE": "DOANE, C. Recordist.",
	"HART": "HART, S. Engine-man.",
	"IVES": "IVES, T. Technician.",
	"LUSK": "LUSK, M. Draughtswoman.",
	"PRYCE": "PRYCE, O. Boatman.",
	"ROOK": "ROOK, S. Director.",
	"TULL": "TULL, A. Laboratory assistant.",
}
const NO_EFFECTS := "No surviving personal effects."
const STAMP_ALL := "INDEXED 18.X.27"
const STAMP_N := "SPECIMEN 27-11"
const SAMPLE_LINES := {
	"N": "Specimen 27-11. A stoppered tube. It looks empty.",
	"W": "Specimen 27-03. Seawater in a vial.",
	"F": "Specimen 27-19. A chip of the foundation stone.",
}
const SAMPLE_CARDS_LINE := "Three sample cards, in drams, by specimen number. 27-03, seawater. 27-11, a stoppered tube, contents not given. 27-19, foundation stone. The readings are left for the balance."
## What each sample card names as its contents ("" = left blank).
const CARD_CONTENTS := {"W": "SEAWATER", "N": "", "F": "STONE"}
const RECORDED_LINE := "Recorded. I'll leave it as it is."
const BEAM_LOCKED := "BEAM LOCKED."
const NO_CORRESPONDENCE := "NO CORRESPONDENCE"
const CONSTANT := "CONSTANT"
const RECORD_INCOMPLETE := "RECORD INCOMPLETE."
const ENVIRONMENTAL := "Environmental. It doesn't answer to a name."

# --- P14: the specimen frame -----------------------------------------------------------------
const SECTIONS := ["short", "pause", "long"]
const SOLUTION_SLOTS := ["short", "pause", "long"]
## The glass tray's positions t0..t2 (deliberately not the solution order).
const TRAY_ORDER := ["pause", "long", "short"]
const SECTION_LABELS := {"short": "SHORT RISES", "pause": "PAUSE", "long": "LONG RISE"}
const CATEGORY := "BODY"
const INSCRIPTION := "Retention is not resuscitation."
const KITCHEN_CARD := "Her work card isn't here. It hangs in the kitchen, by the range."
## SEAL before her work card has been seen.
const SEEN_GATE := "I need her trace to compare. It's on the nail by the range."
const SECTION_LINE := "A trace section."
const P14_TAIL := "CATEGORY: BODY. Printed, not written. The frame was waiting to be filled."

# --- escalation ------------------------------------------------------------------------------
## First-time arrival holds in view A, oldest first. Seeing one retires every older one.
const NOTICES := ["angles", "tank_lag", "vault_ajar", "jars_to_vault", "tank_pane", "jars_face"]
const BENCH_NOTICES := ["shells_rings"]
const NOTICE_LINES := {
	"tank_lag": "The tank's reflection is behind the room. It still has jar C in the rack.",
	"vault_ajar": "The vault door's open a hand's width.",
	"jars_to_vault": "Every jar's water has tilted toward the vault door.",
	"tank_pane": "The tank. Its surface is standing on edge. And the hum's stopped.",
	"jars_face": "The water in the jars has turned. It's facing me.",
	"shells_rings": "The shells have lined up.",
}
## Notices that arrive silently: only their visual change and sound play on arrival; the line
## waits for her first click on the thing itself (state.<id>_said).
const SILENT_NOTICES := ["vault_ajar"]
## Lines of the P10 lean and the P13 thumb.
const LEAN_LINES := ["...The water in C leaned toward me.", "Now it's level again. It took longer than water should."]
const THUMB_TAIL := "Pressed into the felt. The nap hasn't risen back yet."
## Rewards are seen: the glance at the end of each commit chain (view A / view B rects), and
## how long after the click it starts (once the chain's last line is up).
const GLANCE_SOCKET := Rect2(716, 318, 130, 362)
const GLANCE_FRAME := Rect2(720, 330, 250, 270)
const GLANCE_DELAY := {"p10": 1.6, "p14": 2.2}

## After the sever ending the room is released: everything lies level.
const SEVER_LINES := {
	"jar_a": "Level. All of them, with each other and with the line.",
	"jar_b": "Level. All of them, with each other and with the line.",
	"jar_c": "Level. All of them, with each other and with the line.",
	"tilt_rack": "Level. All of them, with each other and with the line.",
	"reference_socket": "Level. All of them, with each other and with the line.",
	"tank": "Water. It ripples when I tap the glass.",
	"datum_line": "The plumb bob hangs straight down the wall now.",
	"sealed_jar": "Clear glass. The words are still cut in it.",
	"sample_rack": "Shell fragments, sorted by size.",
}

const OBSERVATIONS := {
	"angles": "Three sealed jars on a canted rack, A, B and C, each half full of seawater. At rest they look alike: the tilt rack is the test.",
	"datum": "A brass line set into the wall, labelled DATUM. The room is built square to it: tiles, shelves, floor. Beside it a plumb bob labelled GRAVITY hangs eight degrees off the wall. The station was built on the datum, not on level ground.",
	"tank": "A flotation tank. Its water lies at the plumb bob's slant, eight degrees off the room. Ordinary water: it follows gravity.",
	"basin_drip": "The basin tap drips. Every drop falls at a slant, along the plumb line, not down the tiles.",
	"drip_hangs": "The drop at the basin tap doesn't fall. It hangs at the spout.",
	"reference_card": "Reference card above the socket: 'A valid sample keeps the station's own level: the brass, not the bob, not the glass.'",
	"rack": "A tilt rack. Its cradle tips one jar through a fixed quarter-turn, and a test card draws the jar's surface against three printed lines: GRAVITY (solid), JAR (dashed), DATUM (dot-dash).",
	"test_a": "Jar A, tipped a quarter-turn: its surface stayed on the solid line.",
	"test_b": "Jar B, tipped a quarter-turn: its surface turned with the jar, on the dashed line.",
	"test_c": "Jar C, tipped a quarter-turn: its surface stayed on the dot-dash line, square with the room, whatever the jar did.",
	"datum_target": "Jar C's water follows the station's datum, not gravity and not its jar. The reference socket gives a stair pressure target: 2.",
	"lean": "When I stepped back from the socket, the water in jar C leaned toward me, held there longer than water should, and settled level with the datum again. The reading was already on the tag.",
	"vault_door": "A steel door marked RECORDS. Latched from the far side.",
	"return_door": "A door marked STAIR. Dry, and cold to the touch. It opens from the stair side.",
	"tank_lag": "The tank's reflection runs behind the room. It still shows jar C standing in the rack, and its ripples run the other way.",
	"vault_ajar": "The vault door stands open a hand's width. Its latch let go from the far side.",
	"jars_to_vault": "Every jar's water has tilted toward the vault door. Jar C's too, in the socket.",
	"tank_pane": "The tank's surface stands at a steep angle, flat and still, like a pane of glass. The tank has stopped humming.",
	"jars_face": "The water in every jar turns to face me. Wherever I go in the room, the surfaces face where I am.",
	"balance": "A balance: a pan for the sample, an empty control tray lined in felt opposite. Keys: ADDRESS, RELEASE, RECORD. A strip printer with three cells: UNATTENDED, ADDRESSED, RELEASED.",
	"beam_locked": "The balance beam is pinned. The gauge on its foot reads 0. It runs off the stair circuit.",
	"control_tray": "An empty control tray lined with green felt. Everything on the balance is weighed against it.",
	"sample_cards": "Three sample cards, in drams, across UNATTENDED / ADDRESSED / RELEASED, the readings left blank for the balance. Each carries only a specimen number: 27-03 (seawater), 27-11 (a stoppered tube, contents not given), 27-19 (foundation stone).",
	"register": "Specimen register: eight staff cards, BELL, DOANE, HART, IVES, LUSK, PRYCE, ROOK, TULL. Every one is stamped INDEXED 18.X.27 and reads 'No surviving personal effects.' Only Nora Bell's also carries SPECIMEN 27-11.",
	"register_bell": "BELL, N. Cook and caretaker. No surviving personal effects.",
	"nora_mass_trace": "Specimen 27-11 weighs nothing unattended, three drams when addressed as Nora Bell, nothing when released.",
	"thumb": "A thumbprint appeared in the empty control tray, pressed into the felt. The nap hadn't risen back yet.",
	"thumb_flour": "Under the lens, there's a fleck of flour in the thumbprint.",
	"frame_stand": "A specimen frame on a stand: three trace slots, a name tab, a clip for a balance strip, a SEAL FRAME key. Three loose trace sections in a glass tray, unlabelled: only their shapes.",
	"nora_breath_trace": "Nora Bell's breath, rebuilt from her 1927 calibration card: two short rises, a pause, one long rise. Framed with her name and her weight.",
	"sealed_jar": "A sealed jar on its own on the bench, empty. Something is etched on the inside of the glass, too fine to read.",
	"inscription": "The sealed jar fogged from the inside, once, in her rhythm: two short, a pause, one long. In the fog, words etched on the inside of the glass: 'Retention is not resuscitation.'",
	"shells": "Stoppered tubes of shell fragments in the sample rack, sorted by size.",
	"shells_rings": "The shell fragments in the sample rack have lined up into a curve of rings, one inside the next, like the inside of a throat.",
	"down": "After the jar fogged: the jars, the tank, the drip and the plumb bob. All of it leans the same way. Down, toward the stair door.",
}
const OBJECTIVES := {
	"p10": "Find the jar whose water follows the station datum, and seat it in the reference socket.",
	"wait_p12": "The socket gave the stair its target: 2. The stair gate comes next.",
	"p13": "Weigh the samples against the empty tray. One of them answers to a name.",
	"p14": "Build Nora's breath into the specimen frame, with her name and her weight.",
	"done": "Nora's frame is made. The laboratory has nothing more for me.",
}
## Each puzzle's ladder has four tiers (hint_tiers()): location, relationship, the evidence to
## read, the explicit solution.
const HINTS := {
	"p10": [
		"The laboratory's three jars look alike at rest. The tilt rack tests them.",
		"The card wants the brass: a surface that keeps the datum's level, whatever the jar does. Tip each one.",
		"The reference card on the rack says which line to trust.",
		"Test all three. C stays parallel to the datum. Put C in the reference socket.",
	],
	"p13": [
		"The balance in the laboratory compares samples against an empty tray.",
		"Her work card from the kitchen carries a specimen number.",
		"The sample cards by the balance give each sample's specimen number. One is hers, and her register card carries it too.",
		"Put specimen 27-11 on the balance, address it as NORA BELL, release, then RECORD 0 / 3 / 0.",
	],
	"p14": [
		"The specimen frame wants a trace, a name and the measurement.",
		"Nora's work card shows the shape of her breath. Match the sections to it. The register card gives the name; the balance gave the strip.",
		"Her work card is in the notebook: read its trace left to right and lay the tray's sections in that order.",
		"Short rises, pause, long rise. Name tab from her card, clip the 0/3/0 strip, seal the frame.",
	],
	"wait_p12": [
		"The laboratory has given the stair what it needs.",
		"The stair gate wants the socket's target: 2.",
		"Take target 2 to the dry stair gate, through the chart room hatch.",
	],
	"done": [
		"The laboratory is finished with me.",
		"Nora's frame belongs at the lantern.",
		"Take the frame up the stair to the lantern gallery.",
	],
}
## Items this room hands out (docs/design/puzzle-cards/flags.md section 4).
const ITEMS := {
	"nora_register_card": {"name": "Register card: Nora Bell", "desc": "A specimen register card with Nora Bell's name on the tab.", "short": "Nora's card"},
	"nora_frame": {"name": "Specimen frame: N. Bell", "desc": "A specimen frame holding three traces.", "short": "Nora's frame"},
}

const SAVED_BOOLS := ["p10_complete", "lean_seen", "tap_on", "p13_complete", "thumb_seen",
	"p14_complete", "name_tab", "strip_clipped", "fog_seen", "frame_opened", "bench_seen", "vault_ajar_said"]

## Transient, never saved: what the view animates or highlights after the last action.
var last_test := ""      # the jar just tipped
var balance_note := ""   # "" | BEAM_LOCKED | NO_CORRESPONDENCE | CONSTANT | RECORD_INCOMPLETE
var held := ""           # the section picked up in c_frame
var frame_miss := []     # slot indices outlined after a failed SEAL

func initial_state() -> Dictionary:
	return {
		"p10_complete": false, "cradle": "", "tested": {"A": false, "B": false, "C": false},
		"socket": "", "lean_seen": false, "tap_on": false,
		"p13_complete": false, "pan": "", "holder": "", "step": 0, "thumb_seen": false,
		"p14_complete": false, "slots": ["", "", ""], "name_tab": false, "strip_clipped": false,
		"fog_seen": false, "frame_opened": false, "bench_seen": false, "vault_ajar_said": false,
		"notices": [], "bench_notices": [],
	}

func is_closeup(v := local_view) -> bool:
	return v in CLOSEUPS

## Hint tiers per puzzle ladder: location, relationship, evidence, solution.
func hint_tiers() -> int:
	return 4

func objective() -> String:
	_sync()
	if not state.p10_complete:
		return "p10"
	if not game.flag("P12"):
		return "wait_p12"
	if not state.p13_complete:
		return "p13"
	if not state.p14_complete:
		return "p14"
	return "done"

# ---------------------------------------------------------------------------------------------
# view helpers (read-only)
# ---------------------------------------------------------------------------------------------
func band() -> int:
	return game.weather_band()

func ending() -> String:
	return str(game.value("ending_choice"))

func _sever() -> bool:
	return ending() == "sever"

func beam_unlocked() -> bool:
	return game.flag("P12")

## A jar surface's angle against the room, by its rule and the jar's own rotation.
static func surface_deg(rule: String, jar_rot: float) -> float:
	match rule:
		"gravity":
			return GRAVITY_DEG
		"jar":
			return jar_rot
	return DATUM_DEG

## A rack jar's surface at rest (no tip): all three keep jar A's resting slant, so only a tip
## on the rack tells them apart. Jar C in the socket shows its own rule (see the view).
static func rack_rest_deg(_j: String) -> float:
	return surface_deg(JAR_RULE.A, RACK_CANT_DEG)

## A jar's rotation at rest: the rack is canted; the socket holds C square.
func jar_rest_rot(j: String) -> float:
	return 0.0 if j == "C" and state.socket == "C" else RACK_CANT_DEG

## What overrides every jar surface in view A: "" | "vault" | "ada" | "level".
func anomaly() -> String:
	if _sever():
		return "level"
	if band() >= 7:
		return "ada"
	if band() >= 5:
		return "vault"
	return ""

## Bands 4-6 (not after sever): the room view leans every jar and the tank STAIR_LEAN_DEG toward
## the STAIR door. Band 5-6's stronger pulls (the jars to the vault, the tank's pane) still win.
func stair_lean() -> bool:
	return band() >= 4 and band() <= 6 and not _sever()

## The tank's surface: "gravity", "pane" or "level".
func tank_mode() -> String:
	if _sever():
		return "level"
	if band() >= 6:
		return "pane"
	return "gravity"

func reflection_lag() -> bool:
	return band() >= 3 and not _sever()

## Jars the tank's reflection shows standing in the rack.
func reflection_jars() -> int:
	return 3 if (not state.p10_complete or reflection_lag()) else 2

func vault_ajar() -> bool:
	return game.flag("P15")

func return_unbolted() -> bool:
	return game.flag("P12")

func drip_hangs() -> bool:
	return band() >= 6 and not _sever()

func shells_aligned() -> bool:
	return band() >= 4 and not _sever()

func thumb_shown() -> bool:
	return state.p13_complete and not _sever()

func fog_shown() -> bool:
	return state.p14_complete

## The balance's readings for a sample addressed to a name.
static func reading(pan: String, holder: String) -> Array:
	if not READINGS.has(pan):
		return FLAT.duplicate()
	if pan == "N" and holder != "BELL":
		return FLAT.duplicate()
	return READINGS[pan].duplicate()

## The strip printer's three cells ("" = not printed).
func strip_cells() -> Array:
	if state.p13_complete:
		return ["0 dr", "3 dr", "0 dr"]
	var out := ["", "", ""]
	if not beam_unlocked() or state.pan == "":
		return out
	var r := reading(state.pan, state.holder)
	for k in 3:
		if k <= int(state.step):
			out[k] = "%d dr" % int(r[k])
	return out

func strip_note() -> String:
	return "RECORDED" if state.p13_complete else balance_note

## The beam's reading: the last printed cell, or 0.
func beam_reading() -> int:
	var r: Array = READINGS.N if state.p13_complete else reading(state.pan, state.holder)
	var cells := strip_cells()
	var v := 0
	for k in 3:
		if cells[k] != "":
			v = int(r[k])
	return v

func gauge_value() -> int:
	return 2 if game.flag("P12") else 0

func reference_seen() -> bool:
	return game.has_seen("R05", "nora_work_card")

## The glass tray: TRAY_ORDER with the sections now in slots left as "" gaps.
func tray_sections() -> Array:
	var out := []
	for s in TRAY_ORDER:
		out.append("" if s in state.slots else s)
	return out

## The view A notice due now (a NOTICES id), or "".
func current_notice() -> String:
	if ending() != "":
		return ""
	match band():
		7:
			return "jars_face"
		6:
			return "tank_pane"
		5:
			return "jars_to_vault"
		4:
			return "vault_ajar"
		3:
			return "tank_lag"
	return ""

func current_bench_notice() -> String:
	return "shells_rings" if shells_aligned() else ""

# ---------------------------------------------------------------------------------------------
# entry points
# ---------------------------------------------------------------------------------------------
func arrive(ev: Array, first: bool) -> void:
	_sync()
	if first:
		_say(ev, ARRIVAL_WET if band() >= 2 else ARRIVAL)
		_sfx(ev, "slosh_c", 0.4)
		_say(ev, "The tank isn't level either. Or the room isn't.", 2.6, true)
		_observe("angles")
		_mark_notice("angles")
		return
	var n := current_notice()
	if n != "" and not n in state.notices:
		_fx(ev, "notice_" + n)
		_mark_notice(n)
		if n == "vault_ajar":
			_sfx(ev, "vault_settle", 0.6)
		if not n in SILENT_NOTICES:
			_say(ev, NOTICE_LINES[n], 1.6)
		_observe(n)

func back(ev: Array) -> void:
	_sync()
	match local_view:
		"c_tilt_rack":
			local_view = "room"
			if state.p10_complete and not state.lean_seen:
				state.lean_seen = true
				_fx(ev, "notice_lean")
				_sfx(ev, "water_lean", 0.8)
				_say(ev, LEAN_LINES[0], 1.0, true)
				_say(ev, LEAN_LINES[1], 3.8, true)
				_observe("lean")
		"c_balance":
			local_view = "bench"
		"c_frame":
			local_view = "bench"
			held = ""
			if state.p14_complete and not state.fog_seen:
				state.fog_seen = true
				_fx(ev, "notice_fog")
				_sfx(ev, "breath_hiss", 0.8)
				_say(ev, "The jar on the bench fogged. From the inside.", 1.0, true)
				_say(ev, "Two short, a pause, one long.", 4.6, true)
				_say(ev, "There are words in the fog: '%s'" % INSCRIPTION, 6.8, true)
				_observe("inscription")
				_say(ev, DOWN_LINE, 9.4, true)
				_observe("down")
		_:
			local_view = "room"

func act(action: String, ev: Array) -> void:
	_sync()
	match local_view:
		"c_tilt_rack":
			if action in RACK_CONTROLS:
				_rack(action, ev)
				return
		"c_balance":
			if action in BALANCE_CONTROLS:
				_balance(action, ev)
				return
		"c_frame":
			if action in FRAME_CONTROLS:
				_frame(action, ev)
				return
	if action in HOTSPOTS:
		local_view = "room"
		_room(action, ev)
	elif action in BENCH_HOTSPOTS:
		local_view = "bench"
		_bench(action, ev)

# ---------------------------------------------------------------------------------------------
# view A: the tank wall
# ---------------------------------------------------------------------------------------------
## The sever line for `action`, or `line`.
func _line(action: String, line: String) -> String:
	return SEVER_LINES[action] if _sever() and SEVER_LINES.has(action) else line

func _room(action: String, ev: Array) -> void:
	var b := band()
	match action:
		"jar_a", "jar_b", "jar_c":
			var j := action.substr(4).to_upper()
			if j == "C" and state.p10_complete:
				_say(ev, _line(action, "Where jar C stood. A ring of salt in the cradle."))
				_observe("angles")
				return
			state.cradle = j
			local_view = "c_tilt_rack"
			_say(ev, _line(action, JAR_LINES[j]))
			_observe("angles")
			_observe("rack")
		"tilt_rack":
			local_view = "c_tilt_rack"
			_say(ev, _line(action, "The tilt rack. A cradle, a lever, and a test card."))
			_observe("rack")
		"reference_socket":
			if not state.p10_complete:
				local_view = "c_tilt_rack"
				_say(ev, _line(action, "The reference socket. There's a card pinned above it."))
				_observe("reference_card")
			elif b >= 5:
				_say(ev, _line(action, "Even C's water leans to the vault door now. The tag still says 2."))
			elif stair_lean():
				_say(ev, _line(action, "Even C's water leans toward the stair door now. The tag still says 2."))
			else:
				_say(ev, _line(action, "Jar C, in the socket. The stair circuit reads from it. The tag says 2."))
		"datum_line":
			_say(ev, _line(action, "A brass line set into the wall: DATUM. The room is square to it. The plumb bob beside it hangs eight degrees off, and it's marked GRAVITY."))
			_observe("datum")
		"tank":
			_sfx(ev, "glass_tap")
			if _sever():
				_say(ev, SEVER_LINES.tank)
				_observe("tank")
			elif tank_mode() == "pane":
				_say(ev, "The surface is standing on edge. Flat. Still. Like a pane.")
				_observe("tank_pane")
			elif reflection_lag():
				_say(ev, "The reflection in the tank is behind. It still shows jar C in the rack.")
				_observe("tank")
				_observe("tank_lag")
			else:
				_say(ev, "A flotation tank. Its water lies at the plumb bob's slant. Ordinary water.")
				_observe("tank")
		"basin":
			state.tap_on = not state.tap_on
			_sfx(ev, "tap_turn")
			if drip_hangs():
				_say(ev, "The drop at the tap doesn't fall. It hangs there.")
				_observe("drip_hangs")
			elif state.tap_on:
				_say(ev, "The tap runs. The water falls at a slant, along the plumb line.")
			else:
				_say(ev, "Off. It still drips, at the same slant.")
			_observe("basin_drip")
		"vault_door":
			if not game.flag("P15"):
				_sfx(ev, "door_rattle")
				_say(ev, "A steel door marked RECORDS. Latched from the far side.")
				_observe("vault_door")
			elif vault_ajar() and not state.vault_ajar_said:
				state.vault_ajar_said = true
				_say(ev, NOTICE_LINES.vault_ajar)
				_observe("vault_ajar")
			else:
				_say(ev, "The vault's through here.")
		"return_door":
			if not game.flag("P12"):
				_sfx(ev, "door_rattle")
				_say(ev, "A door marked STAIR. Dry, and cold. It opens from the other side.")
				_observe("return_door")
			else:
				_say(ev, "The stair's through here.")
		"to_bench":
			local_view = "bench"
			var n := current_bench_notice()
			var due: bool = n != "" and not n in state.bench_notices
			if not state.bench_seen:
				state.bench_seen = true
				_say(ev, "The bench. A balance, a register, a specimen frame. And a jar on its own, sealed, with nothing in it.")
				if due:
					_bench_notice(n, 2.2, ev)
			elif due:
				_bench_notice(n, 0.6, ev)
			else:
				_say(ev, "The bench.")

func _bench_notice(n: String, delay: float, ev: Array) -> void:
	_fx(ev, "notice_" + n)
	if not n in state.bench_notices:
		state.bench_notices.append(n)
	_say(ev, NOTICE_LINES[n], delay)
	_observe(n)

# ---------------------------------------------------------------------------------------------
# view B: the bench
# ---------------------------------------------------------------------------------------------
func _bench(action: String, ev: Array) -> void:
	match action:
		"balance":
			local_view = "c_balance"
			if not game.flag("P12"):
				_say(ev, "The beam's pinned. The gauge on its foot reads nought; it runs off the stair circuit.")
				_observe("balance")
				_observe("beam_locked")
			elif state.p13_complete:
				_say(ev, RECORDED_LINE)
			else:
				_say(ev, "The balance. A pan for the sample, the empty tray for the control.")
				_observe("balance")
		"control_tray":
			if state.p13_complete:
				_say(ev, "A thumbprint in the felt. Small. Pressed down hard.")
			else:
				_say(ev, "An empty control tray, lined with green felt. Everything is weighed against it.")
			_observe("control_tray")
		"sample_cards":
			_say(ev, SAMPLE_CARDS_LINE)
			_observe("sample_cards")
		"register":
			local_view = "c_balance"
			_say(ev, "The specimen register. Eight staff cards.")
			_observe("register")
		"frame_stand":
			if not state.p13_complete:
				_say(ev, "A specimen frame: three empty slots, a name tab, a clip. The loose sections are under a locked glass lid. A tag: OPENS ON A RECORDED MASS.")
				_observe("frame_stand")
			elif state.p14_complete:
				_say(ev, "The stand's empty. Her frame is with me.")
			else:
				local_view = "c_frame"
				if not state.frame_opened:
					state.frame_opened = true
					if reference_seen():
						_say(ev, "Her work card's in my notebook. I'll keep it open beside the frame.")
					else:
						_say(ev, "There's a space for a reference trace. Nora's work card. It hangs in the kitchen, by the range.")
				_observe("frame_stand")
		"sealed_jar":
			if _sever():
				_say(ev, SEVER_LINES.sealed_jar)
			elif state.p14_complete:
				_say(ev, "Fogged from the inside. The words read through it: '%s'" % INSCRIPTION)
			else:
				_say(ev, "A sealed jar, empty. Something is etched on the inside of the glass, too fine to read.")
			_observe("sealed_jar")
		"sample_rack":
			if _sever():
				_say(ev, SEVER_LINES.sample_rack)
				_observe("shells")
			elif shells_aligned():
				_say(ev, "The shells have lined up. A curve of rings, one inside the next. Like a throat.")
				_observe("shells_rings")
			else:
				_say(ev, "Stoppered tubes of shell fragments, sorted by size.")
				_observe("shells")
		"to_tank":
			local_view = "room"
			_say(ev, "The tank wall.")

# ---------------------------------------------------------------------------------------------
# P10: c_tilt_rack
# ---------------------------------------------------------------------------------------------
func _rack(action: String, ev: Array) -> void:
	match action:
		"rest_a", "rest_b", "rest_c":
			var j := action.substr(5).to_upper()
			if j == "C" and state.socket == "C":
				_say(ev, "Jar C is in the socket.")
			elif state.cradle == j:
				state.cradle = ""
				_sfx(ev, "jar_slide")
				_say(ev, "Back on the shelf.")
			else:
				state.cradle = j
				_sfx(ev, "jar_slide")
				_sfx(ev, "cradle_clamp", 0.25)
				_say(ev, "Jar %s in the cradle." % j)
		"cradle":
			if state.cradle == "":
				_say(ev, "The cradle's empty.")
			else:
				state.cradle = ""
				_sfx(ev, "jar_slide")
				_say(ev, "Back on the shelf.")
		"tip":
			_tip(ev)
		"seat":
			_seat(ev)
		"test_card":
			_say(ev, "The test card. Three printed lines: GRAVITY solid, JAR dashed, DATUM dot-dash. A tipped jar's surface is drawn over whichever one it followed.")
			_observe("rack")
		"ref_card":
			_say(ev, "'%s'" % REF_CARD)
			_observe("reference_card")
		"socket":
			if state.p10_complete:
				_say(ev, "Jar C. The stair circuit reads from it.")
			else:
				_say(ev, "The reference socket. Empty.")

func _tip(ev: Array) -> void:
	var j: String = state.cradle
	if j == "":
		_say(ev, "The cradle's empty.")
		return
	state.tested[j] = true
	last_test = j
	_fx(ev, "tip")
	_observe("rack")
	_observe("test_" + j.to_lower())
	_sfx(ev, "rack_tip", 0.0)
	_sfx(ev, TIP_SFX[j], 0.5)
	_sfx(ev, "test_pen", 1.3)
	_say(ev, TIP_LINES[j], 1.6)

func _seat(ev: Array) -> void:
	var j: String = state.cradle
	if j == "":
		_say(ev, "The cradle's empty. A jar goes in the cradle, then the socket.")
		return
	if state.p10_complete:
		_say(ev, "The socket's taken. Jar C stays.")
		return
	var tested: bool = state.tested[j]
	if j != "C" or not tested:
		_sfx(ev, "socket_refuse")
		match j:
			"A":
				_say(ev, "This one follows gravity. The card wants the datum." + ("" if tested else UNTESTED))
			"B":
				_say(ev, "This one follows the jar." + ("" if tested else UNTESTED))
			_:
				_say(ev, "It sits square with the brass line." + UNTESTED)
		return
	state.socket = "C"
	state.cradle = ""
	state.p10_complete = true
	game.solve("P10", ev)
	_observe("datum_target")
	_sfx(ev, "socket_click", 0.0)
	_fx(ev, "socket_seat")
	_say(ev, "It seats. The socket takes the reading.", 0.3, true)
	_sfx(ev, "tag_drop", 1.2)
	_fx(ev, "tag")
	_say(ev, "A tag drops out of the slot: %s" % TAG_TEXT, 1.4, true)
	_glance(ev, "p10", GLANCE_SOCKET)

# ---------------------------------------------------------------------------------------------
# P13: c_balance
# ---------------------------------------------------------------------------------------------
func _balance(action: String, ev: Array) -> void:
	var is_key: bool = action.begins_with("key_")
	if state.p13_complete and (is_key or action.begins_with("smp_") or action == "pan"
			or action.begins_with("reg_")):
		_say(ev, "Her card's with me." if action == "reg_bell" else RECORDED_LINE)
		return
	if is_key and not beam_unlocked():
		balance_note = BEAM_LOCKED
		_sfx(ev, "key_refuse")
		_say(ev, "The beam's pinned. It needs stair pressure.")
		_observe("beam_locked")
		return
	if action.begins_with("smp_"):
		_place_sample(action.substr(4).to_upper(), ev)
		return
	if action.begins_with("reg_"):
		_select_name(action.substr(4).to_upper(), ev)
		return
	match action:
		"pan":
			if state.pan == "":
				_say(ev, "The pan's empty.")
			else:
				state.pan = ""
				state.step = 0
				balance_note = ""
				_sfx(ev, "pan_place")
				_say(ev, "Back on its stand.")
		"holder":
			if state.holder == "":
				_say(ev, "The holder's empty. Names are in the register along the bottom.")
			else:
				var out_name: String = state.holder
				state.holder = ""
				state.step = 0
				balance_note = ""
				_sfx(ev, "card_flick")
				_say(ev, holder_out_line(out_name))
		"key_address":
			_address(ev)
		"key_release":
			_release(ev)
		"key_record":
			_record(ev)
		"tray":
			if state.p13_complete:
				_say(ev, "Her thumb. In felt nobody has touched.")
			else:
				_say(ev, "The control tray. Empty felt.")
		"gauge":
			_say(ev, "Stair pressure: %d." % gauge_value())
		"cards":
			_say(ev, SAMPLE_CARDS_LINE)
			_observe("sample_cards")
		"strip":
			var printed := []
			for cell in strip_cells():
				if cell != "":
					printed.append(cell)
			var line := "UNATTENDED, ADDRESSED, RELEASED."
			if not printed.is_empty():
				line += " " + ", ".join(printed)
			_say(ev, line)

## The line when she takes a card back out of the holder: it names whose card it was.
static func holder_out_line(n: String) -> String:
	return "I take %s's card back out." % n.capitalize()

func _place_sample(s: String, ev: Array) -> void:
	if state.pan == s:
		_say(ev, "It's on the pan.")
		return
	state.pan = s
	state.step = 0
	balance_note = ""
	_sfx(ev, "pan_place")
	if beam_unlocked():
		_sfx(ev, "strip_print", 0.3)
	_fx(ev, "strip")
	_say(ev, SAMPLE_LINES[s])

func _select_name(n: String, ev: Array) -> void:
	state.holder = n
	state.step = 0
	balance_note = ""
	_sfx(ev, "card_flick")
	_observe("register")
	var line: String = REGISTER[n] + " " + NO_EFFECTS + " Stamped " + STAMP_ALL
	if n == "BELL":
		line += " and " + STAMP_N
		_observe("register_bell")
	_say(ev, line + ".")

func _press(ev: Array) -> void:
	_sfx(ev, "key_press")
	_sfx(ev, "beam_swing", 0.3)
	_sfx(ev, "strip_print", 0.8)
	_fx(ev, "strip")

func _address(ev: Array) -> void:
	if state.pan == "":
		_sfx(ev, "key_refuse")
		_say(ev, "Nothing on the pan to address.")
		return
	if state.holder == "":
		_sfx(ev, "key_refuse")
		_say(ev, "ADDRESS wants a name in the holder. The register's along the bottom.")
		return
	state.step = 1
	_press(ev)
	if state.pan != "N":
		balance_note = CONSTANT
		_say(ev, ENVIRONMENTAL)
	elif state.holder == "BELL":
		balance_note = ""
		_say(ev, "Three drams. On an empty tube.")
	else:
		balance_note = NO_CORRESPONDENCE
		_say(ev, "Nothing. NO CORRESPONDENCE.")

func _release(ev: Array) -> void:
	if int(state.step) == 0:
		_sfx(ev, "key_refuse")
		_say(ev, "Nothing's addressed to release.")
		return
	if int(state.step) == 2:
		_say(ev, "Already released.")
		return
	state.step = 2
	_press(ev)
	if state.pan != "N":
		_say(ev, "No change.")
	elif state.holder == "BELL":
		_say(ev, "Back to nought.")
	else:
		_say(ev, "Still nothing.")

func _record(ev: Array) -> void:
	if int(state.step) < 2:
		balance_note = RECORD_INCOMPLETE
		_sfx(ev, "key_refuse")
		_say(ev, "RECORD INCOMPLETE. Address it, release it, then record.")
		return
	if state.pan != "N":
		balance_note = CONSTANT
		_sfx(ev, "key_refuse")
		_say(ev, ENVIRONMENTAL)
		return
	if state.holder != "BELL":
		balance_note = NO_CORRESPONDENCE
		_sfx(ev, "key_refuse")
		_say(ev, "A flat trace. That name doesn't answer to it.")
		return
	balance_note = ""
	state.p13_complete = true
	game.solve("P13", ev)
	_observe("nora_mass_trace")
	_observe("register_bell")
	state.holder = ""
	game.give("nora_register_card", ev)
	_sfx(ev, "key_press", 0.0)
	_sfx(ev, "strip_print", 0.2)
	_fx(ev, "strip_recorded")
	_say(ev, "Recorded. Nought, three, nought.", 0.6, true)
	_say(ev, "I take her card out of the holder. BELL, N. No surviving personal effects.", 1.8, true)
	_sfx(ev, "felt_press", 3.6)
	_fx(ev, "thumb")
	_say(ev, "...There's a thumbprint in the empty tray.", 4.0, true)
	_say(ev, THUMB_TAIL, 5.6, true)
	_observe("thumb")
	state.thumb_seen = true

# ---------------------------------------------------------------------------------------------
# P14: c_frame
# ---------------------------------------------------------------------------------------------
func _frame(action: String, ev: Array) -> void:
	if state.p14_complete:
		_say(ev, "It's sealed.")
		return
	if action.begins_with("sec_"):
		var s := action.substr(4)
		held = "" if held == s else s
		_sfx(ev, "section_slide")
		_say(ev, SECTION_LINE)
		return
	if action.begins_with("slot_"):
		_slot(int(action.substr(5)), ev)
		return
	match action:
		"name_tab":
			if state.name_tab:
				_say(ev, "BELL, N. Copied from her register card.")
			elif game.has_item("nora_register_card"):
				_say(ev, "The name tab's blank. Her register card has the name.")
			else:
				_say(ev, "The name tab's blank.")
		"strip_clip":
			if not state.strip_clipped:
				state.strip_clipped = true
				_sfx(ev, "strip_clip")
				_say(ev, "The balance strip, nought, three, nought, under the clip.")
			else:
				_say(ev, "Clipped.")
		"ref_card":
			if reference_seen():
				_say(ev, "Her work card's trace, copied beside the frame. The sections have to match it.")
			else:
				_say(ev, KITCHEN_CARD)
		"seal":
			_seal(ev)

func _slot(k: int, ev: Array) -> void:
	var slots: Array = state.slots
	if held != "":
		var from := slots.find(held)
		var occupant: String = slots[k]
		if from >= 0:
			slots[from] = occupant
		slots[k] = held
		held = ""
		frame_miss = []
		_sfx(ev, "section_slide")
	elif slots[k] != "":
		slots[k] = ""
		frame_miss = []
		_sfx(ev, "section_slide")
	else:
		_say(ev, "An empty slot.")

func _seal(ev: Array) -> void:
	held = ""
	var slots: Array = state.slots
	var empty := []
	for k in 3:
		if slots[k] == "":
			empty.append(k)
	if not empty.is_empty():
		frame_miss = empty
		_sfx(ev, "key_refuse")
		_say(ev, "There are three slots. All three want a section.")
		return
	if slots != SOLUTION_SLOTS:
		_sfx(ev, "key_refuse")
		if not reference_seen():
			frame_miss = []
			_say(ev, SEEN_GATE)
			return
		frame_miss = []
		for k in 3:
			if slots[k] != SOLUTION_SLOTS[k]:
				frame_miss.append(k)
		if slots[0] != "short":
			_say(ev, "Her breath starts with the short rises.")
		else:
			_say(ev, "The pause comes after the short rises.")
		return
	if not state.name_tab:
		frame_miss = []
		_sfx(ev, "key_refuse")
		_say(ev, "The name tab is blank. Her register card has the name.")
		return
	if not state.strip_clipped:
		frame_miss = []
		_sfx(ev, "key_refuse")
		_say(ev, "The clip's empty. The balance strip goes there.")
		return
	frame_miss = []
	state.p14_complete = true
	state.frame_opened = true
	game.solve("P14", ev)
	game.give("nora_frame", ev)
	_observe("nora_breath_trace")
	_sfx(ev, "frame_seal", 0.0)
	_fx(ev, "frame_sealed")
	_say(ev, "Sealed. Her breath, her name, her weight, in one frame.", 0.4, true)
	_say(ev, P14_TAIL, 2.0, true)
	_glance(ev, "p14", GLANCE_FRAME)

## The reward glance at the end of a commit chain: the view brackets (and, Motion on, zooms
## to) `rect`, `delay` s after the click, once the chain's last line is up. The fx's own id is
## "glance"; `glance` names which one.
func _glance(ev: Array, gid: String, rect: Rect2) -> void:
	ev.append({"type": "fx", "id": "glance", "glance": gid, "rect": rect, "delay": GLANCE_DELAY[gid]})

# ---------------------------------------------------------------------------------------------
# inventory
# ---------------------------------------------------------------------------------------------
func use_item(item: String, target: String, ev: Array) -> bool:
	_sync()
	match item:
		"inspection_lens":
			return _lens(target, ev)
		"pencil":
			if target == "name_tab":
				_say(ev, "I'd be writing from memory. Her register card has it exactly.")
				return true
			if target == "register" or target.begins_with("reg_"):
				_say(ev, "Not mine to amend. Not yet.")
				return true
		"nora_register_card":
			if target == "name_tab" and local_view == "c_frame":
				if state.p14_complete:
					_say(ev, "It's sealed.")
					return true
				state.name_tab = true
				_sfx(ev, "name_write")
				_say(ev, "I copy it from her register card: BELL, N. The card stays with me.")
				return true
			if target in ["holder", "balance", "pan"]:
				_say(ev, "She's been weighed already.")
				return true
			if target == "register":
				_say(ev, "I'll keep it. The register can stay one card short.")
				return true
		"nora_frame":
			if target == "frame_stand":
				_say(ev, "It stays sealed. The lantern is where it's used.")
				return true
		"chart_clips":
			if target == "strip_clip":
				_say(ev, "The frame has its own clip.")
				return true
	return false

func _lens(target: String, ev: Array) -> bool:
	if target == "datum_line":
		_say(ev, "Under the lens the plumb line is a single hair. It isn't swinging. It hangs eight degrees off, and stays.")
	elif target == "tank":
		var b := band()
		if b <= 2:
			_say(ev, "Through the lens the ripples go the way ripples go.")
		elif b <= 5:
			_say(ev, "In the lens the reflection's ripples run the other way to the water's.")
		else:
			_say(ev, "No ripples at all. It's a surface, not water.")
	elif target in ["jar_a", "jar_b", "jar_c", "tilt_rack", "cradle"] or target.begins_with("rest_"):
		_say(ev, "A hairline is etched round each jar at the half. They were filled exactly.")
	elif target in ["reference_socket", "socket"] and state.p10_complete:
		_say(ev, "Through the lens, C's surface is perfectly flat. Not a tremor.")
	elif target == "basin":
		_say(ev, "The drops leave the tap already slanted.")
	elif target == "sealed_jar":
		if state.p14_complete:
			_say(ev, "'%s' Cut from the inside." % INSCRIPTION)
		else:
			_say(ev, "Etched letters, on the inside of the glass. Too faint to read through clean glass.")
	elif target in ["control_tray", "tray"]:
		if state.p13_complete:
			_say(ev, "A fleck of flour in the print.")
			_observe("thumb_flour")
		else:
			_say(ev, "Clean felt.")
	elif target == "sample_rack":
		if shells_aligned():
			_say(ev, "Shell. Only shell. They grew into rings.")
		else:
			_say(ev, "Ordinary shell. Limpet, mussel.")
	elif target in ["sample_cards", "register", "cards"] or target.begins_with("reg_"):
		_say(ev, "The stamps were inked the same day, from the same pad.")
	elif target in ["pan", "smp_n"]:
		_say(ev, "The tube is empty. Nothing, even under the lens.")
	else:
		return false
	return true

# ---------------------------------------------------------------------------------------------
# state
# ---------------------------------------------------------------------------------------------
## Marks `n` and every older notice as seen, so an obsolete one never plays later.
func _mark_notice(n: String) -> void:
	var k := NOTICES.find(n)
	for i in k + 1:
		if not NOTICES[i] in state.notices:
			state.notices.append(NOTICES[i])

func _set_p10_done() -> void:
	state.p10_complete = true
	state.socket = "C"
	state.tested.C = true
	if state.cradle == "C":
		state.cradle = ""

func _set_p13_done() -> void:
	if not state.p10_complete:
		_set_p10_done()
	state.p13_complete = true
	state.holder = ""
	state.pan = "N"
	state.step = 2

func _set_p14_done() -> void:
	if not state.p13_complete:
		_set_p13_done()
	state.p14_complete = true
	state.slots = SOLUTION_SLOTS.duplicate()
	state.name_tab = true
	state.strip_clipped = true
	state.frame_opened = true

## Flags set elsewhere (tests, debug) pull the local arrangement along. Never clears anything
## and never gives items.
func _sync() -> void:
	if game.flag("P10") and not state.p10_complete:
		_set_p10_done()
	if game.flag("P13") and not state.p13_complete:
		_set_p13_done()
	if game.flag("P14") and not state.p14_complete:
		_set_p14_done()

func _clear_transient() -> void:
	last_test = ""
	balance_note = ""
	held = ""
	frame_miss = []

func load_state(d: Variant) -> void:
	state = initial_state()
	_clear_transient()
	if not d is Dictionary:
		return
	for key in SAVED_BOOLS:
		if d.get(key) is bool:
			state[key] = d[key]
	var cr = d.get("cradle")
	if cr is String and (cr == "" or cr in JARS):
		state.cradle = cr
	var te = d.get("tested")
	if te is Dictionary:
		for j in JARS:
			if te.get(j) is bool:
				state.tested[j] = te[j]
	var so = d.get("socket")
	if so is String and so in ["", "C"]:
		state.socket = so
	var pa = d.get("pan")
	if pa is String and (pa == "" or pa in SAMPLES):
		state.pan = pa
	var ho = d.get("holder")
	if ho is String and (ho == "" or ho in NAMES):
		state.holder = ho
	var st = d.get("step")
	if _all_whole([st]):
		state.step = clampi(int(st), 0, 2)
	var sl = d.get("slots")
	if sl is Array and sl.size() == 3:
		var ok := true
		var used := []
		for s in sl:
			if not (s is String and (s == "" or s in SECTIONS)):
				ok = false
			elif s != "":
				ok = ok and not s in used
				used.append(s)
		if ok:
			state.slots = sl.duplicate()
	for pair in [["notices", NOTICES], ["bench_notices", BENCH_NOTICES]]:
		var arr = d.get(pair[0])
		if arr is Array:
			for n in arr:
				if n is String and n in pair[1] and not n in state[pair[0]]:
					state[pair[0]].append(n)
	# Derived: later progress implies earlier progress and its arrangement.
	if state.p14_complete:
		state.p13_complete = true
	if state.p13_complete:
		state.p10_complete = true
	if state.p10_complete:
		_set_p10_done()
	else:
		state.socket = ""
		state.lean_seen = false
	if state.p13_complete:
		_set_p13_done()
	else:
		state.thumb_seen = false
		state.name_tab = false
		state.strip_clipped = false
		if int(state.step) > 0 and (state.pan == "" or state.holder == ""):
			state.step = 0
	if state.p14_complete:
		_set_p14_done()
	else:
		state.fog_seen = false

## P10, P13 and P14 are R07's: a flag set elsewhere (tests, debug) is honoured, then the flags
## follow the state.
func reconcile() -> void:
	_sync()
	game.set_flag("P10", state.p10_complete)
	game.set_flag("P13", state.p13_complete)
	game.set_flag("P14", state.p14_complete)

# ---------------------------------------------------------------------------------------------
# debug
# ---------------------------------------------------------------------------------------------
const P10_SEEN := ["angles", "datum", "rack", "reference_card", "test_a", "test_b", "test_c",
	"datum_target", "lean"]
const P13_SEEN := ["balance", "sample_cards", "register", "register_bell", "nora_mass_trace", "thumb"]
const P14_SEEN := ["frame_stand", "nora_breath_trace", "inscription", "down", "sealed_jar"]

func _observe_all(ids: Array) -> void:
	for o in ids:
		_observe(o)

func _prep_p10() -> void:
	_set_p10_done()
	for j in JARS:
		state.tested[j] = true
	state.lean_seen = true
	_observe_all(P10_SEEN)

func _prep_p13() -> void:
	_set_p13_done()
	state.thumb_seen = true
	state.bench_seen = true
	_observe_all(P13_SEEN)
	if not game.flag("P22") and not game.has_item("amended_nora_card"):
		game.give("nora_register_card", [])

## The local state real play leaves at the start of tide `t`.
func debug_prepare(t: int) -> void:
	if t >= 5:
		_prep_p10()
	if t >= 6:
		_prep_p13()
		_set_p14_done()
		state.fog_seen = true
		state.frame_opened = true
		_observe_all(P14_SEEN)
		if not game.has_item("nora_frame"):
			game.give("nora_frame", [])
	if t >= 5:
		_prepare_notices()

## Every notice older than the current one is behind her; the current one still plays.
func _prepare_notices() -> void:
	var n := current_notice()
	var k := NOTICES.find(n) if n != "" else 1
	for i in k:
		if not NOTICES[i] in state.notices:
			state.notices.append(NOTICES[i])
	var bn := current_bench_notice()
	for i in (BENCH_NOTICES.find(bn) if bn != "" else 0):
		if not BENCH_NOTICES[i] in state.bench_notices:
			state.bench_notices.append(BENCH_NOTICES[i])

## Dev stages: 1 Tide IV fresh, 2 jars tested with C in the cradle, 3 P10 solved, 4 Tide V
## fresh balance, 5 N on the pan addressed to BELL, 6 P13 solved, 7 the frame ready to seal,
## 8 P14 solved, 9 Tide IX.
func debug_jump(n: int) -> void:
	if n <= 3:
		game.debug_tide(4, ID)
		if n >= 2:
			for j in JARS:
				state.tested[j] = true
			_observe_all(["angles", "datum", "rack", "reference_card", "test_a", "test_b", "test_c"])
			state.cradle = "C"
			_mark_notice("angles")
		if n >= 3:
			_prep_p10()
	elif n <= 8:
		game.debug_tide(5, ID)
		if n == 5:
			state.bench_seen = true
			state.pan = "N"
			state.holder = "BELL"
			state.step = 1
			_observe_all(["balance", "sample_cards", "register", "register_bell"])
		if n >= 6:
			_prep_p13()
		if n == 7:
			state.slots = SOLUTION_SLOTS.duplicate()
			state.name_tab = true
			state.strip_clipped = true
			state.frame_opened = true
			_observe("frame_stand")
		if n >= 8:
			_set_p14_done()
			state.fog_seen = true
			_observe_all(P14_SEEN)
			if not game.has_item("nora_frame"):
				game.give("nora_frame", [])
	else:
		game.debug_tide(9, ID)
	local_view = "room"
	_clear_transient()
	reconcile()
