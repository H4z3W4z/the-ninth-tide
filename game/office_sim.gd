class_name OfficeSim
extends RefCounted
## Deterministic state for the Intake Office slice (Tide I).
##
## No nodes, no clocks, no randomness: every change is caused by a player
## action. dispatch() mutates state and returns presentation events
## ({type: "say"|"sfx"|"fx", ...}) for the view to play. The view never
## mutates state itself, so the whole slice is testable headless.
##
## P01 rule (AGENTS.md): supply OFF, straight bridge B installed, supply ON.
## Curved C is rejected without consuming anything.

const SCHEMA := 2

## Room hotspots, in the order they are hit-tested (first match wins).
const OBJECTIVES := {
	"lamp": "Get the desk lamp working.",
	"log": "Read what Venn left on the desk.",
	"changed": "Something in the room changed while I was reading.",
	"chair": "Find where the footprints lead.",
	"leave": "Leave the office. The instrument rooms are open.",
	"done": "Tide I continues in the Chart Room.",
}

const HINTS := {
	"lamp": [
		"The desk lamp is dead. The tray beside it holds spares.",
		"The plate inside the lamp says what kind of contact it takes, and what to do before fitting one.",
		"Open the lamp. Switch the supply OFF, select straight bridge B, tap the terminals, then switch ON.",
	],
	"log": [
		"With the lamp on, the desk is readable.",
		"Venn's tide log is the dark book on the desk.",
		"Open the tide log on the desk.",
	],
	"changed": [
		"Listen to the room. Then look at the floor.",
		"The coat has been dripping. Look beneath it.",
		"Inspect the puddle under the coat.",
	],
	"chair": [
		"The footprints end somewhere close.",
		"They stop at the desk. Who sits there?",
		"Inspect the chair behind the desk.",
	],
	"leave": [
		"There is nothing more for you in this room tonight.",
		"The corridor door is on the right.",
		"Use the door.",
	],
	"done": ["The slice is complete.", "The slice is complete.", "The slice is complete."],
}

## Notebook text for each observation, in the order they read best.
const OBSERVATIONS := {
	"duty": "Closure duty: inventory the instruments, reconcile the records, restore the departure signal.",
	"coat": "Venn's oilskin is soaked through. It has not rained today.",
	"hooks": "Nine coat hooks. Eight empty, and the ninth wet.",
	"map": "The 1889 survey shows nine jetty pilings. I counted eight from the launch.",
	"mug": "His mug is rinsed, a clean spoon laid across it.",
	"stove": "Stove cold. The ash raked smooth.",
	"lamp": "Desk lamp repaired: supply off, straight bridge B, supply on.",
	"note": "Pencil note under the duty card: register both chart sheets at the lighthouse cross; preserve the recording before winding again.",
	"shadow": "The chair's shadow leans toward the lamp.",
	"handwriting": "Venn's tide log is worked out to tomorrow, in advance. The last line is in my handwriting.",
	"silent": "The sea is still moving against the pilings. It no longer makes a sound.",
	"prints": "Bare, narrow footprints run from the puddle to the desk.",
	"seat": "The chair seat is wet and cold, as if someone has only just stood up.",
}

## Venn's tide log. [date, time, tide, note, in_adas_hand]
const LOG_ENTRIES := [
	["14 Oct", "04:12", "HW 3.8 m", "Wind SW, steady. Launch due 17th.", false],
	["14 Oct", "10:31", "LW 0.6 m", "Lamp bridge failing again.", false],
	["15 Oct", "04:58", "HW 3.9 m", "Spare B left in the tray for her.", false],
	["15 Oct", "11:17", "LW 0.5 m", "", false],
	["16 Oct", "05:44", "HW 4.1 m", "", false],
	["16 Oct", "12:03", "LW 0.4 m", "", false],
	["17 Oct", "06:31", "HW 4.3 m", "She arrives on the evening launch.", false],
	["17 Oct", "18:52", "HW 4.3 m", "She mends the lamp.", false],
	["18 Oct", "07:14", "HW 4.4 m", "Observer: A. Mercer", true],
]

const ROOM_IDS := ["lamp", "tray", "logbook", "papers", "mug", "chair", "map",
	"stove", "window", "hooks", "coat", "puddle", "door"]

var state := {}
var view := "title"
var return_view := "room"   # where Back goes from the notebook / menu
var selected := ""          # transient: spare selected in the repair close-up

func _init() -> void:
	reset()

func reset(keep_settings := false) -> void:
	var motion: bool = state.get("motion", true) if keep_settings else true
	var soft: bool = state.get("soft_audio", false) if keep_settings else false
	state = {
		"schema": SCHEMA, "started": false,
		"supply_on": true, "bridge_installed": false, "p01_complete": false,
		"log_read": false, "prints_seen": false, "seat_wet": false, "finished": false,
		"seen": [], "hint_level": 0, "hint_for": "",
		"motion": motion, "soft_audio": soft,
	}
	view = "title"
	return_view = "room"
	selected = ""

# ---------------------------------------------------------------------------
# derived
# ---------------------------------------------------------------------------
func objective() -> String:
	if state.finished: return "done"
	if not state.p01_complete: return "lamp"
	if not state.log_read: return "log"
	if not state.prints_seen: return "changed"
	if not state.seat_wet: return "chair"
	return "leave"

## 0 arrival, 1 lamp lit, 2 log read (sea silent, prints), 3 seat wet.
func stage() -> int:
	if state.seat_wet: return 3
	if state.log_read: return 2
	if state.p01_complete: return 1
	return 0

func has_seen(id: String) -> bool:
	return id in state.seen

func is_closeup(v := view) -> bool:
	return v in ["repair", "logbook", "duty", "note"]

# ---------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------
func dispatch(action: String) -> Array:
	var ev: Array = []
	if view == "title":
		if action == "begin":
			_begin(ev)
		return ev
	if view == "end":
		if action == "restart":
			reset(true)
		return ev

	match action:
		"notebook":
			if view != "notebook":
				return_view = view if view != "menu" else return_view
				view = "notebook"
				_sfx(ev, "page")
		"menu":
			if view != "menu":
				return_view = view if view != "notebook" else return_view
				view = "menu"
		"hint":
			_hint(ev)
		"back":
			_back(ev)
		"resume":
			view = return_view
		"toggle_motion":
			state.motion = not state.motion
		"toggle_soft":
			state.soft_audio = not state.soft_audio
		"restart":
			reset(true)
		_:
			if view == "room" and action in ROOM_IDS:
				_room(action, ev)
			elif view == "repair":
				_repair(action, ev)
	return ev

func _begin(ev: Array) -> void:
	state.started = true
	view = "room"
	_say(ev, "Greywake Survey Station. The launch won't be back for me until the morning tide.")
	_say(ev, "Power's out. The duty card says to start with the desk lamp.", 0.6)

func _back(ev: Array) -> void:
	match view:
		"notebook", "menu":
			view = return_view
		"logbook":
			view = "room"
			# The room changed while she was reading. Say nothing; let her hear it.
			if state.log_read and not has_seen("silent"):
				_fx(ev, "sea_fade")
				_say(ev, "...Listen.", 2.2)
		"repair", "duty", "note":
			view = "room"
			selected = ""
		_:
			view = "room"

func _room(id: String, ev: Array) -> void:
	var s := stage()
	match id:
		"lamp", "tray":
			view = "repair"
			if state.p01_complete:
				_say(ev, "The bridge is seated and the lamp is steady.")
			else:
				_say(ev, "A contact bridge has burnt through. There's a plate inside the shade.")
		"logbook":
			view = "logbook"
			_sfx(ev, "page")
			if not state.p01_complete:
				_say(ev, "Venn's tide log. The ink is too faint to read by torchlight.")
			else:
				var first: bool = not state.log_read
				state.log_read = true
				_observe("handwriting")
				if first:
					_say(ev, "He's worked out the tides to tomorrow. In advance.")
					_say(ev, "And the last line... that's my handwriting.", 1.4)
					_fx(ev, "dread")
				else:
					_say(ev, "Observer: A. Mercer. In my hand. I have never seen this book.")
		"papers":
			if state.p01_complete:
				view = "note"
				_observe("note")
				_say(ev, "In the lamplight there's pencil beneath the duty card.")
			else:
				view = "duty"
				_observe("duty")
				_say(ev, "Closure duty. Inventory, reconcile, restore the signal. Begin with the lamp.")
			_sfx(ev, "page")
		"mug":
			_observe("mug")
			_say(ev, "A chipped green mug, rinsed. A clean spoon laid across it. Someone tidied before they left.")
		"stove":
			_observe("stove")
			_say(ev, "Cold through. The ash has been raked smooth, like a page nobody wrote on.")
		"map":
			_observe("map")
			_say(ev, "Morrow Sound, surveyed 1889. The jetty has nine pilings. I counted eight from the launch.")
		"hooks":
			_observe("hooks")
			_say(ev, "Nine hooks. Eight empty, and the ninth still wet.")
		"window":
			if s >= 2:
				_observe("silent")
				_say(ev, "The water is still breaking on the pilings. I can't hear it any more.")
			elif s == 1:
				_say(ev, "Dark enough now that the glass shows the lamp more than the sea.")
			else:
				_say(ev, "The launch is already past the lighthouse. Nobody else is coming tonight.")
		"coat":
			_observe("coat")
			if s >= 3:
				_say(ev, "The shoulders have shape now. I am not going to touch it.")
			else:
				_say(ev, "Venn's oilskin, soaked through. It hasn't rained since I landed.")
		"puddle":
			if s >= 2:
				var first_prints: bool = not state.prints_seen
				state.prints_seen = true
				_observe("prints")
				if first_prints:
					_fx(ev, "prints")
				_say(ev, "Footprints. Bare, and narrow. From the puddle to the desk, and no further.")
			else:
				_say(ev, "Seawater, by the smell. It's run off the coat.")
		"chair":
			if state.prints_seen:
				var first_seat: bool = not state.seat_wet
				state.seat_wet = true
				_observe("seat")
				_say(ev, "The seat is wet. Cold. Like someone only just stood up.")
				if first_seat:
					_sfx(ev, "sting")
					_sfx(ev, "latch_near", 2.6)
					_say(ev, "Behind me, the corridor door unlatched itself.", 2.8)
			elif s >= 1:
				_observe("shadow")
				_say(ev, "Its shadow leans toward the lamp. Shadows don't do that.")
			else:
				_say(ev, "Venn's chair. The cushion keeps the shape of someone who sat very still.")
		"door":
			if state.seat_wet:
				state.finished = true
				view = "end"
				_sfx(ev, "door")
			elif state.p01_complete:
				_say(ev, "The instrument rooms are open now. Not yet. Something in here isn't finished.")
			else:
				_say(ev, "The corridor is pitch black. Light first.")

func _repair(action: String, ev: Array) -> void:
	match action:
		"toggle_supply":
			state.supply_on = not state.supply_on
			_sfx(ev, "switch")
			if state.supply_on and state.bridge_installed and not state.p01_complete:
				state.p01_complete = true
				_observe("lamp")
				view = "room"
				selected = ""
				_fx(ev, "lamp_on")
				_sfx(ev, "latch_far", 1.3)
				_say(ev, "Light.", 0.5)
				_say(ev, "And somewhere down the corridor, two latches let go.", 1.4)
			elif state.supply_on:
				_say(ev, "Supply on. Nothing. The circuit's still open.")
			else:
				_say(ev, "Supply off. Safe to work on it.")
		"select_b":
			if state.bridge_installed:
				_say(ev, "Bridge B is already seated.")
			else:
				selected = "B"
				_say(ev, "Bridge B. Straight, two contacts.")
		"select_c":
			selected = "C"
			_say(ev, "Spare C. Curved, two contacts.")
		"fit":
			if state.bridge_installed:
				_say(ev, "The bridge is seated. It wants power.")
			elif selected == "":
				_say(ev, "Pick a spare from the tray first.")
			elif state.supply_on:
				# A jolt, not a punishment: nothing is consumed or lost.
				_fx(ev, "spark")
				_sfx(ev, "spark")
				_say(ev, "Ah! It bit me. Supply off first, Mercer.")
			elif selected == "C":
				_sfx(ev, "clink")
				_say(ev, "The curve won't lie flat across both terminals.")
			else:
				state.bridge_installed = true
				selected = ""
				_sfx(ev, "seat")
				_say(ev, "Bridge B seats with a click. Now the supply.")

func _hint(ev: Array) -> void:
	var obj := objective()
	if state.hint_for != obj:
		state.hint_for = obj
		state.hint_level = 0
	var level: int = mini(int(state.hint_level), 2)
	_say(ev, HINTS[obj][level])
	state.hint_level = level + 1

# ---------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return state.duplicate(true)

## Restores a saved dict, ignoring anything malformed. Returns true if loaded.
func from_dict(d: Variant) -> bool:
	if not d is Dictionary or int(d.get("schema", 0)) != SCHEMA:
		return false
	reset()
	for key in ["started", "supply_on", "bridge_installed", "p01_complete", "log_read",
			"prints_seen", "seat_wet", "finished", "motion", "soft_audio"]:
		if d.get(key) is bool:
			state[key] = d[key]
	if d.get("seen") is Array:
		for id in d.seen:
			if id is String and OBSERVATIONS.has(id) and not id in state.seen:
				state.seen.append(id)
	# Derived flags must agree: progress implies its prerequisites.
	if state.p01_complete:
		state.bridge_installed = true
		state.supply_on = true
	state.log_read = state.log_read and state.p01_complete
	state.prints_seen = state.prints_seen and state.log_read
	state.seat_wet = state.seat_wet and state.prints_seen
	state.finished = state.finished and state.seat_wet
	view = "room" if state.started else "title"
	if state.finished:
		view = "end"
	return true

## Dev-only: jump to a story stage (0-3). Builds the state the real actions would.
func debug_jump(target: int) -> void:
	reset(true)
	state.started = true
	view = "room"
	if target >= 1:
		state.p01_complete = true; state.bridge_installed = true; state.supply_on = true
		_observe("lamp")
	if target >= 2:
		state.log_read = true; _observe("handwriting")
	if target >= 3:
		state.prints_seen = true; state.seat_wet = true
		_observe("prints"); _observe("seat")

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func _observe(id: String) -> void:
	if not id in state.seen:
		state.seen.append(id)

func _say(ev: Array, text: String, delay := 0.0) -> void:
	ev.append({"type": "say", "text": text, "delay": delay})

func _sfx(ev: Array, id: String, delay := 0.0) -> void:
	ev.append({"type": "sfx", "id": id, "delay": delay})

func _fx(ev: Array, id: String) -> void:
	ev.append({"type": "fx", "id": id})
