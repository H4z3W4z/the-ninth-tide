class_name R11Sim
extends RoomSim
## R11, the Dry Stair. Owns P12 (the dry descent: the pressure gate) and P24 (leave the last
## space open: the lower door): docs/design/puzzle-cards/P12.md, P24.md and rooms.md R11.
## Node-free and deterministic; the view reads the helpers below and the transient vars
## (landing, held_plate, gate_note, door_note, frame_results) and plays the events.
##
## Two landings, both local_view "room" (not close-ups): 1, the gate landing (HOTSPOTS) and
## 2, the lower landing past the gate (L2_HOTSPOTS, after P12). `landing` says which one is
## on show. Close-ups: c_gate (P12) and c_chamber_door (P24).

const ID := "R11"
const TITLE := "Dry Stair"
const REQUIRES := ["P04"]
const LOCKED := "The observation hatch is shut."
const RESUME := "Back on the dry stair."
const ARRIVAL := "The steps go down through a sheet of water."
const ARRIVAL_STORY := "Below it they're dry. And there's no sound of water. None."
const WAY_IN_HINT := "The hatch in the chart room goes down to the dry stair."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R03", "Chart room", []],
	["R07", "Laboratory", ["P12"]],
	["R09", "Lantern gallery", []],
	["R12", "Lower door", []],
]

## Landing 1 (the gate landing) hotspots, in hit order.
const HOTSPOTS := ["gauge", "plates", "placard", "water_plane", "steps", "gate"]
## Landing 2 (below the gate) hotspots.
const L2_HOTSPOTS := ["shoes", "bell_sound", "ceiling", "return_door", "upper_stair", "lower_door"]
const CLOSEUPS := ["c_gate", "c_chamber_door"]
const GATE_CONTROLS := ["wheel_down", "wheel_up", "gauge_face", "flags", "slot_upper", "slot_lower", "port",
	"plate_o1", "plate_c1", "plate_o2", "placard_read", "lever_open"]
const DOOR_CONTROLS := ["frame_body", "frame_place", "frame_name", "socket_witness", "port_copy", "preview",
	"door_plate", "lever_access"]
## Moving between the landings.
const NAV := ["descend", "ascend"]

# --- P12: the pressure gate ------------------------------------------------------------------
const PLATES := ["o1", "c1", "o2"]
const PLATE_TEXT := {"o1": "[ 1", "c1": "] 1", "o2": "[ 2"}
const PRESSURE_MAX := 5
const PRESSURE_TARGET := 2
## Slot index 0 = UPPER, 1 = LOWER.
const GATE_SOLUTION := {"pressure": 2, "slots": ["o1", "c1"]}
const SLOT_ACTIONS := {"slot_upper": 0, "slot_lower": 1}
## The gate's printed flags after a pull: pressure (P) and landing (L).
const FLAG_P_TEXT := {"unpowered": "NO PRESSURE", "noref": "NO REFERENCE", "unequal": "PRESSURE NOT EQUAL",
	"equal": "PRESSURE EQUAL"}
const FLAG_L_TEXT := {"incomplete": "NO LANDING SELECTED", "none": "NO CORRESPONDING LANDING",
	"reversed": "WRONG WAY ACROSS BOUNDARY", "ok": "LANDING 1 CORRESPONDS"}
## Refusal lines: one reason, or both composed.
const REFUSE_P := {
	"unequal": "Pressure not equal. The black needle's off the brass one.",
	"noref": "No reference. The brass needle has nothing to read from.",
}
const REFUSE_L := {
	"none": "NO CORRESPONDING LANDING.",
	"reversed": "Brackets face the wrong way across the boundary.",
	"incomplete": "It wants a plate in each slot.",
}
const BOTH_P := {"unequal": "The pressure's not equal", "noref": "There's no reference"}
const BOTH_L := {"none": "there's no landing for those plates", "reversed": "the brackets face the wrong way",
	"incomplete": "one slot's empty"}
const UNPOWERED_LINE := "No pressure in the line."
const OPEN_LEAVE := "Open. I'm leaving it as it is."
const PORT_REAL := "The port shows the landing below. The real one."
const FALSE_LANDING_LINE := "Through the port: steps going down to a landing that ends in a wall of water. No door."
const GAUGE_DEAD := "The gauge is dead. No pressure in the line."
const GAUGE_POWERED := "Live now. The black needle follows the wheel. The brass one lies on NO REFERENCE."
const GAUGE_REFERENCED := "The brass needle's come up to 2. The laboratory jar's reading."
const PLACARD_LINE := "The gate placard. Equalise to the reference; choose a landing whose marks correspond across the boundary; pull OPEN. Its example: '[ 7' above the line, '] 7' below."
const GATE_SHUT := "The gate's down across the stair."
const BELOW_GATE := "That's below the gate. I can't get down there."
const GLANCE_BELL := [366, 334, 220, 170]

# --- P24: the lower door ---------------------------------------------------------------------
const FRAMES := ["BODY", "PLACE", "NAME"]
const FRAME_ACTIONS := {"frame_body": "BODY", "frame_place": "PLACE", "frame_name": "NAME"}
const RECORD_CATEGORY := {"nora_frame": "BODY", "nora_spatial_strip": "PLACE", "amended_nora_card": "NAME",
	"nora_register_card": "NAME"}
const BRIDGE := "witness_bridge"
const COMPLETE_CARD := "nora_register_card"
const DOOR_LOCKED := "The glass is locked down. Stencilled under it: AWAITING PREPARED RECORD."
const WANT_LINES := {
	"BODY": "The BODY frame wants a record of her body.",
	"PLACE": "The PLACE frame wants where she was.",
	"NAME": "The NAME frame wants her name.",
}
const NOTE_OPEN := "RECORD VALID. RECORD OPEN."
const GLANCE_DOOR := [320, 450, 280, 430]

# --- escalation ------------------------------------------------------------------------------
## [id, landing, trigger, evidence ids, lines]. Per landing only the newest met notice can be
## pending; older met ones are marked seen silently, their evidence kept. "(commit)" notices
## (n_glass, n_bell, n_finger) are marked seen by their commit.
const NOTICES := [
	["n_arrival", 1, "visited", [], []],
	["n_tide1", 1, "band1", ["tide_line"], ["A line of salt on the wall, above the water. Nothing below it is wet."]],
	["n_tide2", 1, "band2", ["tide_lines"], ["A second salt line, higher than the first. The steps are still dry."]],
	["n_glass", 1, "P12", ["gate_opened"], []],
	["n_more_steps", 1, "band4", ["more_steps"], ["Through the glass the stair goes further down than it does."]],
	["n_shelves", 1, "band5", ["plane_shelves"], ["Shelves in the water. Rows of files, upside down. There are no shelves down here."]],
	["n_tide_top", 1, "band7", ["tide_hatch"], ["The salt line's up at the hatch."]],
	["n_bell", 2, "P12", ["bell"], []],
	["n_shoes_wet", 2, "band4", ["shoes_wet"], ["The shoes under the office desk are wet. Up there, nothing is."]],
	["n_shoes_facing", 2, "band6", ["shoes_facing", "bell_below"], ["The shoes are side by side now, facing the stair.",
		"And the bell's coming from below. Through the lower door."]],
	["n_finger", 2, "P24", ["finger_marks"], []],
]
const NOTICE_DELAY := 1.6
## Each further line of a notice comes this much later.
const NOTICE_STEP := 1.0
const NOTICE_SFX := {
	"n_tide1": ["r11_salt_tick", 0.4], "n_tide2": ["r11_salt_tick", 0.4], "n_tide_top": ["r11_salt_tick", 0.4],
	"n_shelves": ["r11_shelf_hush", 0.4], "n_shoes_facing": ["r11_shoe_set", 0.5],
}
## The salt lines on the gate landing's wall, by weather band.
const TIDE_LINES := [0, 1, 2, 2, 3, 3, 4, 5]

const OBSERVATIONS := {
	"steps": "Limewashed steps go down through a sheet of water lying across the stairwell. Below it they are tinted green and perfectly dry.",
	"stair_marks": "Cut into the gateway's right jamb, top to bottom: a bracket, two linked strokes, a hollow circle. The same three marks as the hatch frame above.",
	"water_plane": "The water lies across the stairwell like a pane, flat to the jambs. It doesn't drip, doesn't spill, makes no sound. My hand stops at it.",
	"gate": "A pressure gate across the gateway: iron grille, a lock-box with two plate slots, UPPER and LOWER, a brass line between them marked BOUNDARY, and a lever marked OPEN.",
	"gauge": "The gate gauge reads 0 to 5: a black PRESSURE needle on the wheel, and a brass REFERENCE needle fed from somewhere else in the station.",
	"gauge_powered": "With the machine room's pump running, the PRESSURE needle follows the wheel. The brass REFERENCE needle lies at NO REFERENCE.",
	"gauge_reference": "The brass REFERENCE needle stands at 2: the laboratory's jar C, read through the stair circuit.",
	"plates": "Three landing plates in a rack: '[ 1', '] 1' and '[ 2', each bracket printed with the word BOUNDARY. There is no '] 2'.",
	"placard": "The gate placard: 'PRESSURE GATE, DRY STAIR. 1. EQUALISE: turn the wheel until the PRESSURE needle lies on the REFERENCE needle. 2. SELECT A STABLE LANDING: its marks must correspond across the boundary. Example: [ 7 above the line, ] 7 below it. 3. PULL OPEN.'",
	"false_landing": "Through the gate's sight port, with '[ 2' set: steps down to a landing that ends in a standing wall of water. No door. Nothing corresponds to it.",
	"gate_opened": "Gate opened at pressure 2, landing 1. The water across the gate stands up like glass.",
	"bell": "A bell on the lower landing, stopped halfway through a swing. No clapper. It rings anyway, and the sound comes up the stair.",
	"ceiling": "Overhead, the underside of the floor is clear as water, and through it is the office: the desk, the lamp, the chair.",
	"shoes": "Under the office desk, seen from the stair below: a pair of empty shoes. There are no shoes under that desk.",
	"shoes_wet": "The shoes under the office desk are wet through. Water has run out of them across the boards.",
	"shoes_facing": "The shoes under the desk stand side by side now, facing the stair.",
	"bell_below": "The bell sounds from below now, behind the lower door, and it hangs tipped toward it.",
	"tide_line": "A salt line on the gate landing's wall, above the water plane. The steps below it are dry.",
	"tide_lines": "Two salt lines now, the second higher. Whatever leaves them never wets the steps.",
	"more_steps": "Through the glass in the gateway the stair goes further down than the stair itself: more steps, thinner, going on.",
	"plane_shelves": "The water plane reflects shelves of files, upside down. The shelves are in the records vault, not here.",
	"tide_hatch": "The highest salt line is up at the hatch, at the top of the stair.",
	"return_door": "The laboratory's STAIR door, from the stair side: stencilled LABORATORY, and unbolted.",
	"upper_stair": "A short stair going up through the ceiling to cold white light: the lantern gallery.",
	"lower_door": "The lower door: three glazed frames BODY, PLACE and NAME, a socket under a hollow circle marked WITNESS, a port stamped COPY: AUTOMATIC, and a lever, OPEN ACCESS.",
	"copy_port": "The COPY port is sprung open. It is the only thing on the door that seems to want something.",
	"copy_refusal": "With anything in COPY the door prints WOULD FINALIZE SUBJECT and the lever locks.",
	"chamber_open": "The chamber door opened for a record that is valid but not finished.",
	"finger_marks": "The far side of the lower door, the side no one could reach: worn finger marks, many hands, at the height of someone seated, reaching up.",
}
const OBJECTIVES := {
	"explore": "Look around the dry stair.",
	"wait_power": "The stair gate needs pressure and a reference from the station.",
	"p12": "Open the pressure gate on the dry stair.",
	"wait_door": "The lower door wants a record I can't make yet.",
	"p24": "Open the lower door with a record that can't close.",
	"done": "The lower door is open. The chamber is below.",
}
const HINTS := {
	"explore": [
		"The gate landing: the steps, the water, the gate and its plates.",
		"The gate's gauge is dead. Something elsewhere in the station has to feed this line.",
		"Nothing opens here yet. Look at the gate, then go where the station's power is.",
	],
	"wait_power": [
		"The stair gate is waiting on the station.",
		"It needs pressure from the machine room and a reference from the laboratory.",
		"Route the pump to the gate in the machine room, and seat the right jar in the laboratory.",
	],
	"p12": [
		"The gate on the dry stair needs pressure and a landing.",
		"The laboratory gave a pressure target. The plan marks real landings with a matching pair of brackets.",
		"Pressure 2. Bracket-1 plate in UPPER, its closing bracket in LOWER. Pull OPEN.",
	],
	"wait_door": [
		"The lower door wants records.",
		"Three frames and a witness. The chart room plan shows the procedure.",
		"Nothing to mount yet. Her records aren't ready.",
	],
	"p24": [
		"The lower door has three frames and a socket.",
		"Mount Nora's three records, the amended card among them, and use the witness bridge. Leave the automatic port alone.",
		"Frame to BODY, strip to PLACE, amended card to NAME, bridge to WITNESS, COPY empty, OPEN ACCESS.",
	],
	"done": [
		"The chamber's below. The lower door is open.",
		"The chamber's below. The lower door is open.",
		"The chamber's below. The lower door is open.",
	],
}
## R11 hands out no items of its own.
const ITEMS := {}

const SAVED_BOOLS := ["p12_complete", "false_seen", "dead_wheel_said", "p24_complete", "plane_touched"]

## Transient, never saved: which landing is on show, and what the view highlights after the
## last action. _clear_transient() resets all but `landing`.
var landing := 1
var held_plate := ""
var gate_note := {"p": "", "l": ""}
var door_note := ""
var frame_results := {"BODY": "", "PLACE": "", "NAME": ""}

func initial_state() -> Dictionary:
	return {
		"p12_complete": false, "pressure": 0, "slots": ["", ""], "false_seen": false,
		"dead_wheel_said": false, "p24_complete": false,
		"frames": {"BODY": "", "PLACE": "", "NAME": ""}, "witness": "", "copy": "",
		"plane_touched": false, "notices": [],
	}

func is_closeup(v := local_view) -> bool:
	return v in CLOSEUPS

func objective() -> String:
	_sync()
	if state.p24_complete:
		return "done"
	if state.p12_complete and door_live():
		return "p24"
	if state.p12_complete:
		return "wait_door"
	if game.flag("P10") and game.flag("P11"):
		return "p12"
	if has_seen("gate") or has_seen("gauge"):
		return "wait_power"
	return "explore"

# ---------------------------------------------------------------------------------------------
# view helpers (read-only)
# ---------------------------------------------------------------------------------------------
func band() -> int:
	return game.weather_band()

func ending() -> String:
	return str(game.value("ending_choice"))

## The machine room's pump feeds the gate line (P11).
func powered() -> bool:
	return game.flag("P11")

## The laboratory's jar C gives the brass needle its reading (P10), on a live line.
func referenced() -> bool:
	return powered() and game.flag("P10")

## The black PRESSURE needle: the wheel, on a live line; 0 on a dead one.
func needle_pressure() -> int:
	return int(state.pressure) if powered() else 0

## The brass REFERENCE needle: 2, or -1 for NO REFERENCE.
func needle_reference() -> int:
	return PRESSURE_TARGET if referenced() else -1

func default_landing() -> int:
	return 2 if state.p12_complete else 1

func gate_up() -> bool:
	return state.p12_complete

## The water standing in the open gateway: "" (shut), "glass", or "deep" (more steps in it).
func glass_mode() -> String:
	if not state.p12_complete:
		return ""
	return "deep" if band() >= 4 else "glass"

## The water plane reflects the vault's shelves.
func shelves_shown() -> bool:
	return band() >= 5

## How many salt lines stand on the gate landing's wall.
func tide_lines() -> int:
	return TIDE_LINES[clampi(band(), 0, TIDE_LINES.size() - 1)]

## Where the clapperless bell rings from: "" (not heard), "above" or "below".
func bell_dir() -> String:
	if not state.p12_complete:
		return ""
	return "below" if band() >= 6 else "above"

## The shoes under the office desk, seen from below: "dry", "wet" or "facing".
func shoes_state() -> String:
	if band() >= 6:
		return "facing"
	if band() >= 4:
		return "wet"
	return "dry"

func door_open() -> bool:
	return state.p24_complete

## The door's frames accept a record: Nora's amended card (P22) and the witness test (P23).
func door_live() -> bool:
	return game.flag("P22") and game.flag("P23")

## Plates on the rack: not in a slot and not in her hand.
func rack_plates() -> Array:
	var out := []
	for p in PLATES:
		if not p in state.slots and p != held_plate:
			out.append(p)
	return out

## The gate's flag pair {p, l} ("" = blank).
func flags_shown() -> Dictionary:
	if gate_note.p != "":
		return gate_note.duplicate()
	if state.p12_complete:
		return {"p": "equal", "l": "ok"}
	return gate_note.duplicate()

## The sight port: "false" after a pull that showed the false landing (the view times it),
## "true" once the gate is open, else "" (shuttered).
func port_view() -> String:
	if state.p12_complete:
		return "true"
	if gate_note.l == "none":
		return "false"
	return ""

func door_preview() -> String:
	if door_note != "":
		return door_note
	return NOTE_OPEN if state.p24_complete else ""

func frame_item(f: String) -> String:
	return str(state.frames.get(f, ""))

func witness_item() -> String:
	return state.witness

func copy_item() -> String:
	return state.copy

static func flag_text(note: Dictionary) -> String:
	var parts := []
	if FLAG_P_TEXT.has(note.get("p", "")):
		parts.append(FLAG_P_TEXT[note.p])
	if FLAG_L_TEXT.has(note.get("l", "")):
		parts.append(FLAG_L_TEXT[note.l])
	return "" if parts.is_empty() else ". ".join(parts) + "."

# ---------------------------------------------------------------------------------------------
# arrival, landings, Back
# ---------------------------------------------------------------------------------------------
func arrive(ev: Array, first: bool) -> void:
	_sync()
	var from := ""
	for e in ev:
		if e.get("type", "") == "fx" and e.get("id", "") == "travel" and e.get("to", "") == ID:
			from = str(e.get("from", ""))
	if from == "R03":
		landing = 1
	elif from in ["R07", "R09", "R12"]:
		landing = 2
	else:
		landing = default_landing()
	local_view = "room"
	_clear_transient()
	if first:
		_say(ev, ARRIVAL, 0.0)
		_say(ev, ARRIVAL_STORY, 2.4, true)
		_fx(ev, "notice", {"notice": "n_arrival"})
		_mark_notice("n_arrival")
		_observe("steps")
		_observe("water_plane")
	else:
		_landing_entered(ev)

func back(ev: Array) -> void:
	_sync()
	if local_view in CLOSEUPS:
		local_view = "room"
		_clear_transient()

func _leave_closeup() -> void:
	if local_view != "room":
		local_view = "room"
		_clear_transient()

func _landing_entered(ev: Array) -> void:
	if ending() != "":
		return
	_settle(landing)
	var n := pending_notice(landing)
	if n != "":
		_play_notice(_notice(n), ev)

# ---------------------------------------------------------------------------------------------
# notices
# ---------------------------------------------------------------------------------------------
func _notice_met(trigger: String) -> bool:
	match trigger:
		"visited":
			return ID in game.state.visited
		"P12", "P24":
			return game.flag(trigger)
	if trigger.begins_with("band"):
		return band() >= int(trigger.substr(4))
	return false

func _notice(nid: String) -> Array:
	for n in NOTICES:
		if n[0] == nid:
			return n
	return []

## The newest met notice on landing `l`, if she hasn't seen it; "" otherwise.
func pending_notice(l := -1) -> String:
	if l < 0:
		l = landing
	var latest := ""
	for n in NOTICES:
		if n[1] == l and _notice_met(n[2]):
			latest = n[0]
	return "" if latest == "" or latest in state.notices else latest

## Older met notices on landing `l` are superseded: seen silently, their evidence kept.
func _settle(l: int) -> void:
	var met := []
	for n in NOTICES:
		if n[1] == l and _notice_met(n[2]):
			met.append(n[0])
	for i in range(0, met.size() - 1):
		_mark_notice(met[i])

## Marks a notice seen and records its evidence.
func _mark_notice(nid: String) -> void:
	if not nid in state.notices:
		state.notices.append(nid)
	var n := _notice(nid)
	if not n.is_empty():
		for o in n[3]:
			_observe(o)

func _play_notice(n: Array, ev: Array) -> void:
	_fx(ev, "notice", {"notice": n[0]})
	var lines: Array = n[4]
	for k in lines.size():
		_say(ev, lines[k], NOTICE_DELAY + NOTICE_STEP * k, true)
	if NOTICE_SFX.has(n[0]):
		_sfx(ev, NOTICE_SFX[n[0]][0], NOTICE_SFX[n[0]][1])
	_mark_notice(n[0])

# ---------------------------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------------------------
func act(action: String, ev: Array) -> void:
	_sync()
	if local_view == "c_gate" and action in GATE_CONTROLS:
		_gate(action, ev)
	elif local_view == "c_chamber_door" and action in DOOR_CONTROLS:
		_door(action, ev)
	elif action == "descend":
		_descend(ev)
	elif action == "ascend":
		_ascend(ev)
	elif action in HOTSPOTS:
		_leave_closeup()
		landing = 1
		_l1(action, ev)
	elif action in L2_HOTSPOTS:
		if not state.p12_complete:
			_say(ev, BELOW_GATE)
			return
		_leave_closeup()
		landing = 2
		_l2(action, ev)

func _descend(ev: Array) -> void:
	if not state.p12_complete:
		_say(ev, GATE_SHUT)
		return
	_leave_closeup()
	landing = 2
	_sfx(ev, "r11_glass_pass")
	_say(ev, "Down, through the glass.")
	_landing_entered(ev)

func _ascend(ev: Array) -> void:
	_leave_closeup()
	landing = 1
	_sfx(ev, "r11_glass_pass")
	_say(ev, "Back up to the gate.")
	_landing_entered(ev)

func _gauge_line() -> String:
	if not powered():
		return GAUGE_DEAD
	if not referenced():
		return GAUGE_POWERED
	return GAUGE_REFERENCED

## Landing 1: the gate landing.
func _l1(action: String, ev: Array) -> void:
	match action:
		"steps":
			if state.p12_complete:
				_descend(ev)
				return
			if not has_seen("stair_marks"):
				var marks := "Cut down the jamb beside them: a bracket, two linked strokes, a hollow circle. Top to bottom."
				if game.has_seen("R03", "scratches"):
					marks += " The same marks as the hatch frame."
				_say(ev, "Limewashed steps, going down through the water. Under it they're green, and dry.")
				_say(ev, marks, 2.2)
			else:
				_say(ev, "The marks again, down the jamb: bracket, linked strokes, circle.")
			_observe("steps")
			_observe("stair_marks")
		"water_plane":
			_sfx(ev, "r11_plane_touch")
			if shelves_shown():
				_say(ev, "Shelves in it. Rows of files going back, upside down. There are no shelves down here.")
				_observe("plane_shelves")
			elif not state.plane_touched:
				_say(ev, "I put my hand flat on it. It's not cold. It's not anything. It just stops me.")
			elif state.p12_complete:
				_say(ev, "The flat one still stops my hand. The one in the gateway doesn't.")
			else:
				_say(ev, "Flat to the jambs. Not a drop over the edge.")
			state.plane_touched = true
			_observe("water_plane")
		"gate":
			local_view = "c_gate"
			if state.p12_complete:
				_say(ev, "Up in the lintel. The water stands where the bars were.")
			else:
				var line := "A pressure gate. Grille, a lock-box with two plate slots, a lever marked OPEN."
				if not powered():
					line += " Nothing's feeding it."
				_say(ev, line)
			_observe("gate")
		"gauge":
			local_view = "c_gate"
			_say(ev, _gauge_line())
			_observe("gauge")
			if referenced():
				_observe("gauge_reference")
			elif powered():
				_observe("gauge_powered")
		"plates":
			local_view = "c_gate"
			var line := "Three landing plates. '[ 1', '] 1', '[ 2'. There's no '] 2'."
			if game.has_seen("R03", "plan"):
				line += " The chart room plan pairs its landings the same way."
			_say(ev, line)
			_observe("plates")
		"placard":
			local_view = "c_gate"
			_say(ev, PLACARD_LINE)
			_observe("placard")

## Landing 2: below the gate.
func _l2(action: String, ev: Array) -> void:
	match action:
		"shoes":
			if band() >= 6:
				_say(ev, "Side by side now. Toes to the stair.")
				_observe("shoes")
				_observe("shoes_facing")
			elif band() >= 4:
				_say(ev, "The shoes are wet through. Water's run out of them across the boards.")
				_observe("shoes")
				_observe("shoes_wet")
			else:
				if not has_seen("shoes"):
					_say(ev, "A pair of shoes under the office desk. Empty. There are no shoes under that desk; I sat at it.")
				else:
					_say(ev, "Empty shoes. One's fallen on its side.")
				_observe("shoes")
		"bell_sound":
			if band() >= 6:
				_say(ev, "Tipped the other way now, toward the lower door. The ringing comes from under it.")
				_observe("bell")
				_observe("bell_below")
			else:
				_say(ev, "Tipped up toward the office, halfway through a swing, and stopped there. No clapper. It still rings.")
				_observe("bell")
		"ceiling":
			_say(ev, "Overhead, the underside of the floor is clear as water. Through it, the office: the desk, the lamp, the chair. From underneath.")
			_observe("ceiling")
		"return_door":
			_say(ev, "The laboratory's STAIR door. From this side it's stencilled LABORATORY.")
			_observe("return_door")
		"upper_stair":
			_say(ev, "A short stair up through the ceiling. White light at the top. The lantern gallery.")
			_observe("upper_stair")
		"lower_door":
			if state.p24_complete:
				_say(ev, "Open. The finger marks go all the way up the inside of it. The chamber's below.")
			else:
				local_view = "c_chamber_door"
				if not game.flag("P21"):
					_say(ev, "Three glazed frames: BODY, PLACE, NAME. A socket marked WITNESS. A port stamped COPY, AUTOMATIC. A lever: OPEN ACCESS.")
				elif not door_live():
					_say(ev, "Three frames and a witness. The plan's procedure, in iron.")
				else:
					_say(ev, "Her three records. The bridge. And the port I leave alone.")
			_observe("lower_door")
			_observe("copy_port")

# ---------------------------------------------------------------------------------------------
# c_gate: P12
# ---------------------------------------------------------------------------------------------
func _gate(action: String, ev: Array) -> void:
	if state.p12_complete and not action in ["placard_read", "port", "gauge_face", "flags"]:
		_say(ev, OPEN_LEAVE)
		return
	match action:
		"wheel_up", "wheel_down":
			var d := 1 if action == "wheel_up" else -1
			var p := int(state.pressure) + d
			if p < 0 or p > PRESSURE_MAX:
				_say(ev, "It's at the stop.")
				return
			state.pressure = p
			if powered():
				_sfx(ev, "r11_wheel_click")
			else:
				_sfx(ev, "r11_wheel_dead")
				if not state.dead_wheel_said:
					state.dead_wheel_said = true
					_say(ev, "It turns. The needle doesn't.")
		"gauge_face":
			_say(ev, _gauge_line())
		"flags":
			var t := flag_text(flags_shown())
			_say(ev, t if t != "" else "Blank until I pull.")
		"plate_o1", "plate_c1", "plate_o2":
			_pick_plate(action.substr(6), ev)
		"slot_upper", "slot_lower":
			_use_slot(SLOT_ACTIONS[action], ev)
		"port":
			if state.p12_complete:
				_say(ev, PORT_REAL)
			elif state.false_seen:
				_say(ev, "Shuttered again. I know what's behind it.")
			else:
				_say(ev, "A sight port, shuttered from the inside.")
		"placard_read":
			_say(ev, PLACARD_LINE)
			_observe("placard")
		"lever_open":
			_pull(ev)

## R03's plate grammar: the same plate toggles in the hand; a plate in a slot comes out; a
## plate already in the hand goes back to the rack.
func _pick_plate(p: String, ev: Array) -> void:
	_observe("plates")
	if held_plate == p:
		held_plate = ""
	else:
		var i: int = state.slots.find(p)
		if i >= 0:
			state.slots[i] = ""
		held_plate = p
	_sfx(ev, "r11_plate_pick")

func _use_slot(i: int, ev: Array) -> void:
	_observe("plates")
	if held_plate != "":
		state.slots[i] = held_plate   # a plate already there goes back to the rack
		held_plate = ""
		_sfx(ev, "r11_plate_set")
	elif state.slots[i] != "":
		held_plate = state.slots[i]
		state.slots[i] = ""
		_sfx(ev, "r11_plate_pick")
	else:
		_say(ev, "An empty slot.")

## The pull's flags for the current arrangement (powered line assumed): {p, l}.
func gate_check() -> Dictionary:
	var p := "equal"
	if not game.flag("P10"):
		p = "noref"
	elif int(state.pressure) != PRESSURE_TARGET:
		p = "unequal"
	var l := "ok"
	if "o2" in state.slots:
		l = "none"
	elif "" in state.slots:
		l = "incomplete"
	elif state.slots == ["c1", "o1"]:
		l = "reversed"
	return {"p": p, "l": l}

## The refusal line for a pull's flags, or "" when it opens.
static func refusal_line(p: String, l: String) -> String:
	var p_bad := p != "equal"
	var l_bad := l != "ok"
	if p_bad and l_bad:
		return "%s, and %s." % [BOTH_P[p], BOTH_L[l]]
	if p_bad:
		return REFUSE_P[p]
	if l_bad:
		return REFUSE_L[l]
	return ""

func _pull(ev: Array) -> void:
	if not powered():
		_sfx(ev, "r11_lever_refuse")
		gate_note = {"p": "unpowered", "l": ""}
		_say(ev, UNPOWERED_LINE)
		return
	var note := gate_check()
	gate_note = note
	_sfx(ev, "r11_lever_pull")
	_sfx(ev, "r11_flags", 0.15)
	if note.p == "equal" and note.l == "ok":
		_open_gate(ev)
		return
	_sfx(ev, "r11_lever_refuse", 0.3)
	_say(ev, refusal_line(note.p, note.l))
	if note.l == "none":
		_fx(ev, "false_landing")
		_sfx(ev, "r11_port_open", 0.4)
		_sfx(ev, "r11_false_water", 0.9)
		if not state.false_seen:
			state.false_seen = true
			_say(ev, FALSE_LANDING_LINE, 1.2, true)
		_observe("false_landing")

func _open_gate(ev: Array) -> void:
	_say(ev, "PRESSURE EQUAL. LANDING 1 CORRESPONDS.", 0.2, true)
	_sfx(ev, "r11_bolts_draw", 0.6)
	_say(ev, "The bolts draw back. The grille goes up into the lintel.", 1.2, true)
	state.p12_complete = true
	game.solve("P12", ev)
	_observe("gate_opened")
	_fx(ev, "p12_cut")
	_sfx(ev, "r11_glass_flex", 2.0)
	_say(ev, "The water's standing up in the gateway. Thick as glass. My hand goes through it, and comes out dry.", 2.2, true)
	local_view = "room"
	landing = 2
	_clear_transient()
	_mark_notice("n_glass")
	_mark_notice("n_bell")
	_settle(1)
	_settle(2)
	_sfx(ev, "r11_bell_up", 9.4)
	_say(ev, "A bell. The sound is coming up the stair.", 9.6, true)
	_observe("bell")
	_say(ev, "There. It hangs stopped, halfway through a swing. It has no clapper.", 11.6, true)
	_fx(ev, "glance", {"rect": GLANCE_BELL.duplicate(), "target": "bell_sound"})

# ---------------------------------------------------------------------------------------------
# c_chamber_door: P24
# ---------------------------------------------------------------------------------------------
func _door(action: String, ev: Array) -> void:
	if state.p24_complete:
		_say(ev, "It's open.")
		return
	match action:
		"frame_body", "frame_place", "frame_name":
			var f: String = FRAME_ACTIONS[action]
			if state.frames[f] != "":
				_unmount(state.frames[f], ev)
				state.frames[f] = ""
			else:
				_say(ev, "An empty frame, labelled %s. Glass front, spring clips." % f)
		"socket_witness":
			if state.witness != "":
				_unmount(state.witness, ev)
				state.witness = ""
			else:
				_say(ev, "A socket under a hollow circle: WITNESS. It takes a plug.")
		"port_copy":
			if state.copy != "":
				_unmount(state.copy, ev)
				state.copy = ""
			else:
				_say(ev, "COPY. AUTOMATIC. Its shutter is sprung open.")
		"preview":
			_say(ev, door_note if door_note != "" else "Blank.")
		"door_plate":
			_say(ev, "INDEX ACCESS. A record is admitted when its frames agree. Witness: a person present. Copy: automatic acknowledgement.")
		"lever_access":
			_access(ev)

func _unmount(item: String, ev: Array) -> void:
	game.give(item, ev)
	_sfx(ev, "r11_frame_unmount")
	_say(ev, "Out.")

## Puts `item` in a mount; anything already there comes back to her.
func _mount(item: String, old: String, ev: Array) -> void:
	game.take(item)
	if old != "":
		game.give(old, ev)

func _access(ev: Array) -> void:
	if not door_live():
		_sfx(ev, "r11_lever_refuse")
		door_note = "AWAITING PREPARED RECORD"
		_say(ev, "The lever's locked. AWAITING PREPARED RECORD.")
		return
	_sfx(ev, "r11_access_lever")
	for f in FRAMES:
		var it: String = state.frames[f]
		if it == "":
			frame_results[f] = "EMPTY"
		elif RECORD_CATEGORY.get(it, "") == f:
			frame_results[f] = "ACCEPTED"
		else:
			frame_results[f] = "NOT A %s RECORD" % f
	if state.copy != "":
		door_note = "WOULD FINALIZE SUBJECT"
		_refuse_door(ev, "WOULD FINALIZE SUBJECT. The lever won't move while anything's in COPY.")
		_observe("copy_refusal")
		return
	var empty := []
	for f in FRAMES:
		if state.frames[f] == "":
			empty.append(f)
	if not empty.is_empty():
		door_note = "RECORD INCOMPLETE: " + ", ".join(empty)
		_refuse_door(ev, "Incomplete. Every frame wants a record.")
		return
	for f in FRAMES:
		if RECORD_CATEGORY.get(state.frames[f], "") != f:
			door_note = "%s FRAME: NOT A %s RECORD" % [f, f]
			_refuse_door(ev, WANT_LINES[f])
			return
	if state.witness == "":
		door_note = "NO WITNESS. RECORD WILL CLOSE."
		_refuse_door(ev, "Nothing in the witness socket. It would close on its own.")
		return
	if state.frames.NAME == COMPLETE_CARD:
		door_note = "RECORD COMPLETE. ACCESS DENIED TO COMPLETE RECORDS."
		_refuse_door(ev, "RECORD COMPLETE. ACCESS DENIED TO COMPLETE RECORDS. It won't open for a finished record.")
		return
	_open_door(ev)

func _refuse_door(ev: Array, line: String) -> void:
	_sfx(ev, "r11_preview_print", 0.2)
	_sfx(ev, "r11_lever_refuse", 0.5)
	_say(ev, line)

func _open_door(ev: Array) -> void:
	door_note = NOTE_OPEN
	_say(ev, "RECORD VALID. RECORD OPEN. ACCESS.", 0.3, true)
	_sfx(ev, "r11_door_bolts", 0.8)
	state.p24_complete = true
	game.solve("P24", ev)
	_observe("chamber_open")
	_sfx(ev, "r11_bridge_eject", 2.4)
	_return_mounts(ev)
	game.give(BRIDGE, ev)
	_say(ev, "The bridge springs out of the socket into my hand. Her three records come loose with it.", 2.6, true)
	_fx(ev, "door_open")
	local_view = "room"
	landing = 2
	_mark_notice("n_finger")
	_settle(2)
	_sfx(ev, "r11_door_swing", 4.6)
	_say(ev, "It opened because her record isn't finished.", 5.0, true)
	_say(ev, "The far side of the door. The side no one was ever meant to reach.", 7.6, true)
	_say(ev, "Finger marks. Hundreds, worn into the paint. At the height of someone sitting, reaching up.", 10.0, true)
	_observe("finger_marks")
	_fx(ev, "glance", {"rect": GLANCE_DOOR.duplicate(), "target": "lower_door"})

## Everything mounted on the door comes back to her, and the mounts are cleared.
func _return_mounts(ev: Array) -> void:
	for f in FRAMES:
		if state.frames[f] != "":
			game.give(state.frames[f], ev)
	if state.witness != "":
		game.give(state.witness, ev)
	if state.copy != "":
		game.give(state.copy, ev)
	_clear_mounts()

func _clear_mounts() -> void:
	state.frames = {"BODY": "", "PLACE": "", "NAME": ""}
	state.witness = ""
	state.copy = ""

# ---------------------------------------------------------------------------------------------
# items
# ---------------------------------------------------------------------------------------------
func use_item(item: String, target: String, ev: Array) -> bool:
	_sync()
	if target == "lower_door" or (local_view == "c_chamber_door" and target in DOOR_CONTROLS):
		return _door_item(item, target, ev)
	if target in L2_HOTSPOTS and not state.p12_complete:
		_say(ev, BELOW_GATE)
		return true
	if item != "inspection_lens":
		return false
	match target:
		"water_plane":
			_say(ev, "Through the lens there's no surface at all. Just the steps, and a line where the light changes.")
			return true
		"shoes":
			_say(ev, "The laces are still tied.")
			return true
		"bell_sound":
			_say(ev, "The staple's worn bright, as if something still strikes it.")
			return true
	return false

func _door_item(item: String, target: String, ev: Array) -> bool:
	if not state.p12_complete:
		_say(ev, BELOW_GATE)
		return true
	if state.p24_complete:
		_say(ev, "It's open.")
		return true
	if item == "inspection_lens":
		_say(ev, "Through the lens the COPY port's shutter is worn bright at the edges.")
		return true
	if not door_live():
		_say(ev, DOOR_LOCKED)
		return true
	var is_record := RECORD_CATEGORY.has(item)
	if not is_record and item != BRIDGE:
		_say(ev, "Not a record of her.")
		return true
	if target == "lower_door":
		local_view = "c_chamber_door"
		landing = 2
		_say(ev, "It goes in a frame, or the socket.")
		return true
	if FRAME_ACTIONS.has(target):
		var f: String = FRAME_ACTIONS[target]
		if not is_record:
			_say(ev, "It's a plug, not a record.")
			return true
		_mount(item, state.frames[f], ev)
		state.frames[f] = item
		_sfx(ev, "r11_frame_mount")
		_say(ev, "In the %s frame." % f)
		return true
	match target:
		"socket_witness":
			if item != BRIDGE:
				_say(ev, "The socket takes a plug, not a record.")
				return true
			_mount(item, state.witness, ev)
			state.witness = item
			_sfx(ev, "r11_bridge_seat")
			_say(ev, "The bridge seats in the witness socket.")
		"port_copy":
			_mount(item, state.copy, ev)
			state.copy = item
			_sfx(ev, "r11_copy_snap")
			_say(ev, "The shutter snaps shut over it.")
		_:
			_say(ev, "It goes in a frame, or the socket.")
	return true

# ---------------------------------------------------------------------------------------------
# state
# ---------------------------------------------------------------------------------------------
func _set_p12_done() -> void:
	state.p12_complete = true
	state.pressure = GATE_SOLUTION.pressure
	state.slots = GATE_SOLUTION.slots.duplicate()

## P24 done: the gate too, and the door's mounts empty. Whatever was mounted comes back to her
## (never lost), unless `give_back` is false (a save, where the inventory already holds them).
func _set_p24_done(give_back := true) -> void:
	_set_p12_done()
	state.p24_complete = true
	if give_back and game != null:
		_return_mounts([])
	else:
		_clear_mounts()

## P12 and P24 are R11's: a flag set elsewhere (tests, debug, the chain) is honoured.
func _sync() -> void:
	if game.flag("P12") and not state.p12_complete:
		_set_p12_done()
		# Real play opens the gate from the gate landing and leaves her below it.
		local_view = "room"
		landing = 2
		_clear_transient()
	if game.flag("P24") and not state.p24_complete:
		_set_p24_done()

func _clear_transient() -> void:
	held_plate = ""
	gate_note = {"p": "", "l": ""}
	door_note = ""
	frame_results = {"BODY": "", "PLACE": "", "NAME": ""}

func load_state(d: Variant) -> void:
	state = initial_state()
	_clear_transient()
	if d is Dictionary:
		for key in SAVED_BOOLS:
			if d.get(key) is bool:
				state[key] = d[key]
		var pr = d.get("pressure")
		if pr != null and _all_whole([pr]):
			state.pressure = int(clampi(int(pr), 0, PRESSURE_MAX))
		var sl = d.get("slots")
		if sl is Array and sl.size() == 2:
			var ok := true
			for s in sl:
				ok = ok and s is String and (s == "" or s in PLATES)
			if ok and not (sl[0] != "" and sl[0] == sl[1]):
				state.slots = [sl[0], sl[1]]
		_load_mounts(d)
		var notes = d.get("notices")
		if notes is Array:
			var known := []
			for n in NOTICES:
				known.append(n[0])
			for n in notes:
				if n is String and n in known and not n in state.notices:
					state.notices.append(n)
	# Derived: later progress implies earlier progress and its arrangement.
	if state.p24_complete:
		_set_p24_done(false)
	elif state.p12_complete:
		_set_p12_done()
	landing = default_landing()
	_clear_transient()

func _load_mounts(d: Dictionary) -> void:
	var frames := {"BODY": "", "PLACE": "", "NAME": ""}
	var fr = d.get("frames")
	if fr is Dictionary:
		for f in FRAMES:
			var v = fr.get(f)
			if v is String and (v == "" or RECORD_CATEGORY.has(v)):
				frames[f] = v
	var witness := ""
	var w = d.get("witness")
	if w is String and (w == "" or w == BRIDGE):
		witness = w
	var copy := ""
	var cp = d.get("copy")
	if cp is String and (cp == "" or RECORD_CATEGORY.has(cp) or cp == BRIDGE):
		copy = cp
	var used := []
	for it in [frames.BODY, frames.PLACE, frames.NAME, witness, copy]:
		if it == "":
			continue
		if it in used:
			return   # one item in two places: keep every mount at its default
		used.append(it)
	state.frames = frames
	state.witness = witness
	state.copy = copy

func reconcile() -> void:
	_sync()
	game.set_flag("P12", state.p12_complete)
	game.set_flag("P24", state.p24_complete)
	# An item on the door is not also in her hand. (R06's reconcile re-gives the amended card
	# whenever it is missing from the inventory; the rooms reconcile in order, so the door,
	# which holds it, settles that here.)
	for it in _mounted_items():
		if game.has_item(it):
			game.take(it)

func _mounted_items() -> Array:
	var out := []
	for f in FRAMES:
		if state.frames[f] != "":
			out.append(state.frames[f])
	for it in [state.witness, state.copy]:
		if it != "":
			out.append(it)
	return out

# ---------------------------------------------------------------------------------------------
# debug
# ---------------------------------------------------------------------------------------------
func _observe_all(ids: Array) -> void:
	for o in ids:
		_observe(o)

func debug_prepare(t: int) -> void:
	if t >= 4:
		_observe_all(["steps", "stair_marks", "water_plane", "gate", "gauge", "plates"])
		state.plane_touched = true
	if t >= 5:
		_set_p12_done()
		_observe_all(["gauge_powered", "gauge_reference", "placard", "gate_opened", "bell", "ceiling", "shoes"])
		_mark_notice("n_glass")
		_mark_notice("n_bell")
	if t >= 9:
		_set_p24_done()
		_observe_all(["lower_door", "copy_port", "chamber_open", "finger_marks"])
		_mark_notice("n_finger")
		if not game.has_item(BRIDGE):
			game.give(BRIDGE, [])
	# Every notice older than each landing's newest is behind her; the newest still plays.
	_settle(1)
	_settle(2)
	landing = default_landing()

## Sets another room's flag and lets that room bring its own state into line.
func _grant(rid: String, f: String) -> void:
	game.set_flag(f)
	var r: RoomSim = game.room(rid)
	if r != null:
		r.reconcile()

## Dev stages: 1 the threshold (tide III); 2 tide IV unpowered; 3 powered, no reference;
## 4 P10+P11, pressure 2, '[ 2' set (the false landing); 5 ready to OPEN; 6 tide V on landing
## 2; 7 tide VI (wet shoes); 8 tide VIII, the door ready for OPEN ACCESS; 9 tide IX, door open.
func debug_jump(n: int) -> void:
	match n:
		1:
			game.debug_tide(3, ID)
			landing = 1
		2, 3, 4, 5:
			game.debug_tide(4, ID)
			if n >= 3:
				_grant("R08", "P11")
			if n >= 4:
				_grant("R07", "P10")
				state.pressure = PRESSURE_TARGET
				state.slots = ["o2", "c1"] if n == 4 else ["o1", "c1"]
			landing = 1
		6:
			game.debug_tide(5, ID)
			landing = 2
		7:
			game.debug_tide(6, ID)
			landing = 2
		8:
			game.debug_tide(8, ID)
			_grant("R06", "P22")
			game.set_flag("P23")
			var mounts := {"BODY": "nora_frame", "PLACE": "nora_spatial_strip", "NAME": "amended_nora_card"}
			for f in FRAMES:
				game.take(mounts[f])
				state.frames[f] = mounts[f]
			game.take(BRIDGE)
			state.witness = BRIDGE
			state.copy = ""
			landing = 2
		9:
			game.debug_tide(9, ID)
			landing = 2
		_:
			return
	local_view = "room"
	_clear_transient()
	reconcile()
