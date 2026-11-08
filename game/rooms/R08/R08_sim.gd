class_name R08Sim
extends RoomSim
## R08, the Machine Room. Owns P11 (something still breathing): docs/design/puzzle-cards/P11.md
## and rooms.md R08, plus O04 (Venn's repair tags). Node-free and deterministic; the view reads
## the helpers at the bottom and the transient trace vars, and plays the events.
##
## One base view ("room"). Close-ups: c_valves (the valve board, PREVIEW key, PUMP lever and
## the maintenance drawing above it) and c_tags (the ring of repair tags, after P11).

const ID := "R08"
const TITLE := "Machine Room"
const REQUIRES := ["P09"]
const LOCKED := "The machine room is behind the kitchen's service access. It's sealed."
const RESUME := "Back in the machine room."
## The way in, for the core's travel hints.
const WAY_IN_HINT := "The hatch in the kitchen floor is open: the laboratory and the machine room."
## The reveal's first line (s after the commit). The view re-times a late reveal against it.
const REVEAL_FIRST_SAY := 0.6
## The reveal's beats the view times its own presentation against (s after the commit).
const BELT_DROP_AT := 6.6
const BREATH_ALONE_AT := 8.2
const DUST_DRAG_AT := 8.5
const REVEAL_LAST_SAY := "There's a plate where the belt was. REFERENCE RESPIRATION."
## The last line's delay, and the silence it opens: the whole room holds its breath for
## HOLD_BREATH_SECONDS from that line ({fx hold_breath}, played by the view).
const REVEAL_LAST_AT := 12.8
const HOLD_BREATH_SECONDS := 1.8
const ARRIVAL := "The machine room. Belts, a flywheel, and a black diaphragm bolted into the wall. It draws in with the cycle."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R05", "Kitchen", []],
	["R07", "Laboratory", []],
]
const HOTSPOTS := ["repair_tags", "nameplate", "belt", "bolts", "diaphragm", "flywheel", "drawing",
	"valve_board", "dust"]
const CLOSEUPS := ["c_valves", "c_tags"]

# --- P11: the valve board ----------------------------------------------------------------------
## true = OPEN.
const VALVES := ["SUPPLY", "GATE", "RETURN", "INDEX"]
const SOLUTION := {"SUPPLY": true, "GATE": true, "RETURN": true, "INDEX": false}
## Neither the board nor the drawing names a line. The drawing (MAINT. DWG. 4) carries no
## words or numbers on its pipes: only topology and a coloured band per run (the loop out
## sea-glass, the gate run brass, the return brown, the capped stub hatched navy). Each toggle
## is stamped with Venn's tag number and its head painted with its run's band; his repair tags
## (c_tags) say which number is which line, and that No. 44 is 'Do not open.'
const VALVE_TAGS := {"SUPPLY": "07", "GATE": "12", "RETURN": "31", "INDEX": "44"}
## The band painted on each run of the drawing and on its valve's head.
const VALVE_BANDS := {"SUPPLY": "sea-glass", "GATE": "brass", "RETURN": "brown", "INDEX": "hatched navy"}
## The toggles left to right on the board: shuffled against the drawing (44, 07, 31, 12).
const BOARD_ORDER := ["INDEX", "SUPPLY", "RETURN", "GATE"]
## The circuit codes circuit() can return, in evaluation order.
const CIRCUITS := ["no_supply", "index", "gate_shut", "dead_gate", "loop"]
## Printed on the drawing's fault window (the view draws them).
const FAULT_NAMES := {
	"no_supply": "NO PRESSURE",
	"index": "DIVERTED TO SEALED STUB",
	"gate_shut": "DEAD END BEFORE GATE",
	"dead_gate": "DEAD END AT GATE",
	"loop": "LOOP COMPLETE",
}
## [first PREVIEW of that circuit, every later one].
const FAULT_LINES := {
	"no_supply": ["No pressure. The pump would turn over on nothing.", "Still no pressure."],
	"index": ["It runs straight up the sealed line.", "Into the sealed line again."],
	"gate_shut": ["It stops short of the gate.", "Dead before the gate."],
	"dead_gate": ["It reaches the gate and has no way back.", "Nothing coming back."],
	"loop": ["Out through the gate and back. The sealed line stays dry.", "The loop's clean."],
}
## What a refused PUMP says, and the sound the lever makes.
const PUMP_REFUSALS := {
	"index": ["pawl_lock", "It would feed the sealed line."],
	"no_supply": ["lever_spring", "Nothing to pump. It springs back."],
	"gate_shut": ["lever_spring", "Dead end before the gate. It springs back."],
	"dead_gate": ["lever_spring", "Dead end at the gate. It springs back."],
}
const DRAWING_LINE := "From the pump, a green-banded run out to the stair gate, a brass run on, a brown run back. A hatched stub hangs off the loop, capped."

# --- O04: Venn's repair tags -------------------------------------------------------------------
## Pages 0-11 are handwritten (backward slant), in the order they hang; the four valve tags
## ("No. NN: ...") carry the stamped number of their toggle. The last page is new brass,
## stamped (tag_stamp()).
const TAGS := [
	"No. 07: SUPPLY valve reseated, 11 Jan 1926. E.V.",
	"No. 12: GATE valve repacked, 3 Mar 1926. E.V.",
	"No. 31: RETURN line flushed, 9 Sep 1927. E.V.",
	"3 NOV 27. Fitted restraining bolts, twelve. Rim weeps oil. E.V.",
	"19 FEB 28. Middle belt relaced. Diaphragm kept time 4 sec. without load after stop. Noted. E.V.",
	"7 AUG 28. Index line capped and sealed per S.R. Lead seal mine. E.V.",
	"No. 44: INDEX resealed. Wire cut again. Do not open. E.V.",
	"30 JAN 29. Replaced bolt 5, sheared. Sheared outward. E.V.",
	"12 OCT 29. Dust swept. Swept again. E.V.",
	"4 JUN 30. Middle belt relaced. Kept time 40 sec. without load. Did not note this for S.R. E.V.",
	"21 MAR 31. Bolts repainted so I can see if they turn. E.V.",
	"14 OCT 31. Rim rebolted. It is not pushing. It is leaning. E.V.",
	"18 OCT 31",
]
const TAG_LAST := 12
## The pages whose reading records o04_keeps_time (4 JUN 30) and o04_leaning (14 OCT 31).
const TAG_KEEPS_TIME := 9
const TAG_LEANING := 11
const TAG_STAMP_DATE := "18 OCT 31"
const TAG_STAMP_AM := "A.M."

# --- escalation --------------------------------------------------------------------------------
## First-time arrival holds, oldest first. Seeing one retires every older one.
const NOTICES := ["cycle_pause", "breathes_alone", "dust_lines", "bolts_out", "breath_nora",
	"belts_still", "late_reflection", "far_horizon", "end_sever", "end_continue"]
const NOTICE_LINES := {
	"cycle_pause": "The cycle has a pause in it.",
	"breathes_alone": "It breathes without the belt.",
	"dust_lines": "The dust has combed itself into lines. Every line points at it.",
	"bolts_out": "The bolts. I can see their threads. It has come further out.",
	"breath_nora": "It is breathing like her.",
	"belts_still": "Every belt has stopped. It hasn't.",
	"late_reflection": "The room is in its surface. A moment late.",
	"far_horizon": "Further back than the wall goes. A long way further.",
	"end_sever": "It's stopped. All of it.",
	"end_continue": "Still breathing. Evenly now.",
}

const OBSERVATIONS := {
	"diaphragm": "An enormous black diaphragm, bolted into an iron ring in the wall. It draws in with the cycle and lets go with it.",
	"cycle_pause": "The machine's cycle is long and even, with a pause near the end of every turn. In the pause the diaphragm finishes breathing out on its own.",
	"belt": "Three drive belts. The middle one runs down to the diaphragm's crank. Its lacing is all one hand's work.",
	"flywheel": "A flywheel taller than I am, turning slow.",
	"bolts": "Twelve restraining bolts round the ring. A white paint stripe runs across each head onto the flange, so you'd see if one turned.",
	"dust": "Fine grey dust on the floor, swept and settled again. Nobody's walked through it but me.",
	"valve_board": "Valve board: four toggles with no names, only stamped numbers, left to right No. 44, No. 07, No. 31, No. 12, each OPEN or SHUT. Each head is painted with a band: hatched navy, green, brown, brass. A PUMP lever, and a PREVIEW key that lights the active circuit on the drawing.",
	"drawing": "Maintenance drawing, MAINT. DWG. 4. No names, no numbers, only the pipes, banded in colour: from the pump, a green-banded run out to the STAIR GATE, a brass run on, a brown run back. A hatched stub hangs off the loop, capped.",
	"index_seal_cut": "No. 44 was left OPEN. The lead seal wire on its toggle has been cut, cleanly.",
	"tag_07": "Repair tag No. 07: 'SUPPLY valve reseated, 11 Jan 1926.' The SUPPLY toggle is No. 07.",
	"tag_12": "Repair tag No. 12: 'GATE valve repacked, 3 Mar 1926.' The GATE toggle is No. 12.",
	"tag_31": "Repair tag No. 31: 'RETURN line flushed, 9 Sep 1927.' The RETURN toggle is No. 31.",
	"tag_44": "Repair tag No. 44: 'INDEX resealed. Wire cut again. Do not open.' The INDEX toggle is No. 44.",
	"index_hunger": "With 07 and 44 both open, the whole machine stopped and held, flywheel and all, like something listening. It let go when the line was shut.",
	"reference_respiration": "With the gate loop running, one belt stopped. The diaphragm kept breathing without it. Under the belt, a nameplate: REFERENCE RESPIRATION.",
	"o04_tags": "Venn's repair tags, on a ring behind the middle belt: years of valves, bolts, lacing and seals, all in his left-handed slope. The valve tags carry the toggles' numbers.",
	"o04_keeps_time": "Twice he relaced the middle belt. In 1928 the diaphragm kept time 4 seconds without it. In 1930, 40. He didn't tell Rook.",
	"o04_leaning": "His last tag, 14 OCT 31: 'Rim rebolted. It is not pushing. It is leaning.'",
	"o04_new_tag": "The ninth tag is new brass, stamped 18 OCT 31. Tomorrow. Nothing is written on it.",
	"o04_am": "The new tag has been stamped again: A.M. Nobody else is here.",
	"dust_lines": "The dust lies in straight lines now, every one pointing at the diaphragm.",
	"bolts_out": "The bolt paint has cracked. Each bolt shows a finger's width of bright thread under its head. The diaphragm has come further out of the wall.",
	"breath_nora": "Its breath has changed: two short rises, a pause, one long rise. Nora's breath, from her work card. The dust in front of it is raked in the same shape.",
	"belts_still": "All three belts have stopped, and the pump. Only the breath goes on.",
	"late_reflection": "The diaphragm's surface doesn't hold the room. It holds a horizon: one long curve with nine pale points along it, moving a moment after the breath.",
	"far_horizon": "The horizon in its surface is further back than the wall goes. A long way further.",
	"lens_pores": "Under the lens it isn't rubber. It has pores, and they close when it breathes in.",
	"lens_index_ink": "On the drawing, the capped stub and its valve are in a different ink. Added after the rest, then capped.",
	"end_sever": "It hangs slack in its ring. The dust lies where it fell.",
	"end_continue": "It breathes evenly now. The room in its surface has caught up.",
}
const OBJECTIVES := {
	"p11": "Route the pump to the stair gate without feeding the sealed line.",
	"done": "The gate line has pressure. The machine room runs on its own.",
}
const HINTS := {
	"p11": [
		"The drawing above the valve board is the circuit: a pump, four valves, the stair gate, and one capped stub.",
		"The capped stub on the drawing is the line that must never be fed. Find its valve.",
		"The drawing names nothing. The valve heads carry the same bands. And Venn tagged one of them 'Do not open.'",
		"07, 12 and 31 open, 44 shut. Then the pump.",
	],
	"done": [
		"Nothing in the machine room is waiting on me.",
		"The pressure is on the gate line now.",
		"The stair gate needs its own settings. The machine room is finished.",
	],
}
const ITEMS := {}

const SAVED_BOOLS := ["p11_complete", "index_offered", "released_once", "previewed", "tags_opened",
	"diaphragm_looked", "exhale_said"]

## Transient, never saved: the circuit last traced on the drawing and why ("preview" | "pump").
var trace := ""
var trace_kind := ""

func initial_state() -> Dictionary:
	return {
		"toggles": {"SUPPLY": false, "GATE": false, "RETURN": false, "INDEX": true},
		"p11_complete": false, "index_offered": false, "released_once": false, "previewed": false,
		"previewed_codes": [], "misses": 0, "tags_opened": false, "tag": 0, "tag_max": 0,
		"diaphragm_looked": false, "exhale_said": false, "notices": [],
	}

func is_closeup(v := local_view) -> bool:
	return v in CLOSEUPS

func objective() -> String:
	_sync()
	return "done" if state.p11_complete else "p11"

## How many rungs the current objective's Hint ladder has: P11 carries an evidence tier
## (nudge, relationship, evidence, solution); the done ladder keeps three.
func hint_tiers() -> int:
	return c("HINTS", {}).get(objective(), []).size()

# ---------------------------------------------------------------------------------------------
# the circuit
# ---------------------------------------------------------------------------------------------
## The circuit a toggle arrangement makes, checked in order: no supply, diverted into the
## sealed INDEX line, dead before the gate, dead at the gate (nothing returns), the loop.
static func circuit(t: Dictionary) -> String:
	if not t.get("SUPPLY", false):
		return "no_supply"
	if t.get("INDEX", false):
		return "index"
	if not t.get("GATE", false):
		return "gate_shut"
	if not t.get("RETURN", false):
		return "dead_gate"
	return "loop"

## SUPPLY routed into the sealed line: the whole machine stops and holds.
func held() -> bool:
	return not state.p11_complete and bool(state.toggles.SUPPLY) and bool(state.toggles.INDEX)

# ---------------------------------------------------------------------------------------------
# view helpers (read-only)
# ---------------------------------------------------------------------------------------------
func band() -> int:
	return game.weather_band()

func ending() -> String:
	return str(game.value("ending_choice"))

func _p11() -> bool:
	return state.p11_complete or game.flag("P11")

## belt1, belt2 (the diaphragm's), belt3. held() freezes the presentation, not this.
func belts_running() -> Array:
	if ending() != "" or band() >= 6:
		return [false, false, false]
	if _p11():
		return [true, false, true]
	return [true, true, true]

## "cycle" (driven), "alone" (after P11), "nora" (band 5+), "still" (sever), "even" (continue).
func breath_mode() -> String:
	match ending():
		"sever":
			return "still"
		"continue":
			return "even"
	if band() >= 5:
		return "nora"
	return "alone" if _p11() else "cycle"

## "even", "streaks" (after P11), "lines" (band 3-4), "raked" (band 5+), "flat" (sever).
func dust_mode() -> String:
	if ending() == "sever":
		return "flat"
	var b := band()
	if b >= 5:
		return "raked"
	if b >= 3:
		return "lines"
	return "streaks" if _p11() else "even"

func bolts_out_shown() -> bool:
	return band() >= 4 and ending() != "sever"

## "late" (band 6+: the far horizon in its surface), "now" (continue), "" otherwise.
func reflection_mode() -> String:
	if ending() == "continue":
		return "now"
	if ending() == "" and band() >= 6:
		return "late"
	return ""

func nameplate_shown() -> bool:
	return _p11()

func pump_on() -> bool:
	return _p11() and band() < 6 and ending() == ""

func gauge_powered() -> bool:
	return _p11()

func stage_plate() -> String:
	if ending() == "sever":
		return "room_sever"
	var b := band()
	if bulging():
		return BULGE_PLATE
	if b >= 4:
		return "room_s4"
	if b == 3:
		return "room_s3"
	return "room"

## Band 4+ after P11 (and on into the continue ending): the membrane bulges out of its ring into
## the room, a palm pressed into it from behind (the plate and the view's overlay).
func bulging() -> bool:
	return _p11() and band() >= 4 and ending() != "sever"

## The stamped lines on tag 8: the date, and "A.M." once the station is at band 7.
func tag_stamp() -> Array:
	var out := [TAG_STAMP_DATE]
	if band() >= 7 and ending() == "":
		out.append(TAG_STAMP_AM)
	return out

## The escalation notice due now (a NOTICES id).
func current_notice() -> String:
	match ending():
		"sever":
			return "end_sever"
		"continue":
			return "end_continue"
	var b := band()
	if b >= 7:
		return "far_horizon"
	if b == 6:
		return "late_reflection"
	if b == 5:
		return "breath_nora"
	if b == 4:
		return "bolts_out"
	if b == 3:
		return "dust_lines"
	if _p11():
		return "breathes_alone"
	return "cycle_pause"

## Which line a room hotspot speaks: the first matching stage of the escalation.
func _stage() -> String:
	match ending():
		"sever":
			return "sever"
		"continue":
			return "continue"
	var b := band()
	if b >= 7:
		return "b7"
	if b >= 3:
		return "b%d" % b
	if state.p11_complete:
		return "p11"
	if held():
		return "held"
	return "base"

# ---------------------------------------------------------------------------------------------
# entry points
# ---------------------------------------------------------------------------------------------
func arrive(ev: Array, first: bool) -> void:
	_sync()
	if first:
		_say(ev, ARRIVAL)
		_fx(ev, "notice_cycle_pause")
		_say(ev, NOTICE_LINES.cycle_pause, 3.2)
		_observe("diaphragm")
		_observe("cycle_pause")
		_mark_notice("cycle_pause")
	var n := current_notice()
	if n in state.notices:
		return
	_fx(ev, "notice_" + n)
	_mark_notice(n)
	_say(ev, NOTICE_LINES[n], 1.6 if not first else 5.4)
	if OBSERVATIONS.has(n) and not n in ["cycle_pause", "breathes_alone"]:
		_observe(n)

func back(_ev: Array) -> void:
	local_view = "room"
	trace = ""
	trace_kind = ""

func act(action: String, ev: Array) -> void:
	_sync()
	match local_view:
		"c_valves":
			if _valves(action, ev):
				return
		"c_tags":
			if _tags(action, ev):
				return
	if action in HOTSPOTS:
		if local_view != "room":
			back(ev)
		_room(action, ev)

func use_item(item: String, target: String, ev: Array) -> bool:
	_sync()
	var p11: bool = state.p11_complete
	if target == "diaphragm" and item != "inspection_lens":
		_say(ev, "I'm not feeding it anything.")
		return true
	match item:
		"inspection_lens":
			match target:
				"diaphragm":
					_say(ev, OBSERVATIONS.lens_pores)
					_observe("lens_pores")
					return true
				"dust":
					_say(ev, "Every grain lies with its long side toward the ring." if p11
						else "Grey grains, every one lying the same way. Toward it.")
					return true
				"nameplate":
					_say(ev, "The plate is older than the frame. The rivets were set round it." if p11
						else "Not through a running belt.")
					return true
				"drawing", "valve_board", "look_drawing":
					_say(ev, "The capped stub is drawn in a different ink. Added after, then capped.")
					_observe("lens_index_ink")
					return true
				"bolts":
					_say(ev, "Bright thread, no rust. That metal hasn't seen air in four years." if band() >= 4
						else "The paint stripe is unbroken on all twelve.")
					return true
				"repair_tags", "tag":
					_say(ev, "The writing slopes backwards. Left-handed. Venn.")
					return true
				"belt":
					_say(ev, "The lacing is all one hand.")
					return true
				"flywheel":
					_say(ev, "Oil and old paint. Nothing to see but it turning.")
					return true
		"pencil":
			if target in ["drawing", "look_drawing"]:
				_say(ev, "I won't add anything to his drawing.")
				return true
			if target == "tag" and local_view == "c_tags" and int(state.tag) == TAG_LAST:
				_say(ev, "Not yet. I don't know what was repaired.")
				return true
	return false

# ---------------------------------------------------------------------------------------------
# the room
# ---------------------------------------------------------------------------------------------
const DIAPHRAGM_LINES := {
	"held": "It's holding. Full.",
	"p11": "Nothing drives it now. It breathes anyway.",
	"b3": "Every grain of dust on the floor points at it.",
	"b4": "A finger's width further out than it was. I can see the bolts' threads.",
	"b5": "Two short. A pause. One long. I know that breath.",
	"b6": "Everything else has stopped. In its surface there's a horizon where the room should be.",
	"b7": "Nine pale points along that horizon. It goes back further than the wall does.",
	"sever": "Slack. It hangs in its ring like a wet sail.",
	"continue": "It breathes. Evenly. Not behind any more.",
}
## The first diaphragm look after P11 (state.exhale_said, once), after that stage's own line.
const EXHALE_LINE := "It's breathing out. It never used to."
const EXHALE_DELAY := 2.8
## Band 4+ after P11: assets/stages/R08/r08_room_s4_bulge.png (tools/art/rooms/R08.py).
const BULGE_PLATE := "r08_room_s4_bulge"
## The notebook entry a diaphragm look at each stage confirms.
const DIAPHRAGM_OBS := {"b4": "bolts_out", "b5": "breath_nora", "b6": "late_reflection",
	"b7": "far_horizon", "sever": "end_sever", "continue": "end_continue"}

func _room(action: String, ev: Array) -> void:
	var s := _stage()
	var late: bool = s in ["sever", "continue", "b6", "b7"]
	match action:
		"diaphragm":
			_observe("diaphragm")
			if s == "base":
				if state.diaphragm_looked:
					_say(ev, "In. And out. With the belt.")
				else:
					_say(ev, "It draws in when the belt pulls and lets go when it slacks. A pump. It's only a pump.")
			elif _p11() and ending() == "" and not state.exhale_said:
				# the first look since it was let go: its stage line, then the one thing it never did
				state.exhale_said = true
				_say(ev, DIAPHRAGM_LINES[s], 0.0, true)
				_say(ev, EXHALE_LINE, EXHALE_DELAY, true)
				if DIAPHRAGM_OBS.has(s):
					_observe(DIAPHRAGM_OBS[s])
			else:
				_say(ev, DIAPHRAGM_LINES[s])
				if DIAPHRAGM_OBS.has(s):
					_observe(DIAPHRAGM_OBS[s])
			state.diaphragm_looked = true
		"belt":
			_observe("belt")
			if late:
				_say(ev, "All three belts, still.")
				if s in ["b6", "b7"]:
					_observe("belts_still")
			elif state.p11_complete:
				_say(ev, "The middle belt's stopped. Slipped off its drum and hanging.")
			elif s == "held":
				_say(ev, "Stopped mid-stroke. All three.")
			else:
				_say(ev, "The middle belt runs down to the diaphragm's crank. Laced and relaced.")
		"flywheel":
			_observe("flywheel")
			if late:
				_say(ev, "Still.")
			elif state.p11_complete:
				_say(ev, "Still turning. It drives the pump now.")
			elif s == "held":
				_say(ev, "Stopped dead. A wheel that size shouldn't stop like that.")
			else:
				_say(ev, "A flywheel taller than I am. Slow and even, and then the hitch.")
		"bolts":
			_observe("bolts")
			_sfx(ev, "bolt_tap")
			if s == "sever":
				_say(ev, "Just bolts.")
			elif band() >= 4:
				_say(ev, "The paint's cracked on every one. They haven't turned. They've been pushed.")
				_observe("bolts_out")
			else:
				_say(ev, "Twelve bolts. A white paint stripe across every head, so you'd see if one turned. None has.")
		"dust":
			_observe("dust")
			if s == "sever":
				_say(ev, "Flat. Settled.")
			elif band() >= 5:
				_say(ev, "Raked: two short marks, a gap, one long.")
			elif band() >= 3:
				_say(ev, "Lines, all pointing at it.")
				_observe("dust_lines")
			elif state.p11_complete:
				_say(ev, "Dragged into streaks. Toward it.")
			elif s == "held":
				_say(ev, "The dust isn't moving. Nothing is.")
			else:
				_say(ev, "Swept, and settled again. Nobody's walked through it but me.")
		"nameplate":
			if state.p11_complete:
				_sfx(ev, "nameplate_tap")
				_say(ev, "REFERENCE RESPIRATION.")
			else:
				_say(ev, "Something's riveted to the frame behind the belt. I can't read it with the belt running over it.")
		"repair_tags":
			local_view = "c_tags"
			_sfx(ev, "tag_lift")
			_read_tag()
			if not state.tags_opened:
				state.tags_opened = true
				_observe("o04_tags")
				if state.p11_complete:
					_say(ev, "His repair tags. Years of them.")
				else:
					_say(ev, "A ring of brass tags behind the belt. I can reach it past the lacing. His repair tags.")
			if state.p11_complete and not game.flag("o04_found"):
				game.set_flag("o04_found")
		"valve_board", "drawing":
			local_view = "c_valves"
			trace = ""
			trace_kind = ""
			var first: bool = not has_seen("valve_board")
			if first:
				_observe("valve_board")
				_observe("drawing")
				_observe("index_seal_cut")
			if state.p11_complete:
				_say(ev, "The board's locked under pressure.")
			elif first:
				_say(ev, "No names on the toggles, only stamped numbers. Someone left 44 open. Its seal wire has been cut.")

# ---------------------------------------------------------------------------------------------
# P11: c_valves
# ---------------------------------------------------------------------------------------------
## Handles a c_valves control; false if `action` isn't one.
func _valves(action: String, ev: Array) -> bool:
	match action:
		"tog_supply", "tog_gate", "tog_return", "tog_index":
			_toggle(action.substr(4).to_upper(), ev)
		"preview":
			_preview(ev)
		"pump":
			_pump(ev)
		"look_drawing":
			_say(ev, DRAWING_LINE)
		_:
			return false
	return true

func _toggle(valve: String, ev: Array) -> void:
	if state.p11_complete:
		_sfx(ev, "board_locked")
		_say(ev, "It's under pressure. It won't move now.")
		return
	var was_held := held()
	state.toggles[valve] = not state.toggles[valve]
	trace = ""
	trace_kind = ""
	_sfx(ev, "toggle_open" if state.toggles[valve] else "toggle_shut")
	if held() and not was_held:
		_sfx(ev, "cycle_stop", 0.0)
		_fx(ev, "hold")
		if not state.index_offered:
			state.index_offered = true
			_observe("index_hunger")
			_say(ev, "Everything stopped. Behind me, the flywheel too.", 1.4, true)
			_say(ev, "It's holding its breath. Like it's listening.", 4.0, true)
		else:
			_say(ev, "It's holding again.", 0.8)
	elif was_held and not held():
		_sfx(ev, "cycle_resume")
		_fx(ev, "release")
		if not state.released_once:
			state.released_once = true
			_say(ev, "It let go when the line shut.", 1.2)

func _preview(ev: Array) -> void:
	var code := circuit(state.toggles)
	trace = code
	trace_kind = "preview"
	state.previewed = true
	_sfx(ev, "preview_key", 0.0)
	_sfx(ev, "trace_tick", 0.1)
	_fx(ev, "trace")
	if code != "loop":
		state.misses = mini(int(state.misses) + 1, 999)
		_sfx(ev, "fault_buzz", 1.3)
	var seen_before: bool = code in state.previewed_codes
	if not seen_before:
		state.previewed_codes.append(code)
	_say(ev, FAULT_LINES[code][1 if seen_before else 0])

func _pump(ev: Array) -> void:
	if state.p11_complete:
		_sfx(ev, "gauge_rise")
		_say(ev, "It's running. The gate line holds.")
		return
	var code := circuit(state.toggles)
	trace = code
	trace_kind = "pump"
	_fx(ev, "trace")
	_sfx(ev, "trace_tick")
	if code != "loop":
		state.misses = mini(int(state.misses) + 1, 999)
		_sfx(ev, PUMP_REFUSALS[code][0])
		_say(ev, PUMP_REFUSALS[code][1])
		return
	# The commit. The view holds the close-up on screen for 1.8 s, then plays the room.
	_set_p11_done()
	if state.tags_opened:
		game.set_flag("o04_found")   # she read his tags before the belt stopped: O04 is in hand
	_observe("reference_respiration")
	_mark_notice("breathes_alone")
	local_view = "room"
	_fx(ev, "p11_reveal")
	game.solve("P11", ev)
	_sfx(ev, "pump_engage", 0.0)
	_sfx(ev, "gauge_rise", 0.2)
	_say(ev, "It takes. The gate line's holding pressure.", REVEAL_FIRST_SAY, true)
	_sfx(ev, "pump_run_up", 1.2)
	_sfx(ev, "belt_wind_down", 3.4)
	_say(ev, "One of the belts is stopping.", 3.6, true)
	# The view ducks every loop at the drop and holds the room silent; the breath comes back alone.
	_sfx(ev, "belt_drop", BELT_DROP_AT)
	_sfx(ev, "breath_alone", BREATH_ALONE_AT)
	_say(ev, "The diaphragm didn't.", 8.4, true)
	_sfx(ev, "dust_drag", DUST_DRAG_AT)   # with the reveal's one inhalation (the view's RV_DUST)
	_say(ev, "It breathed in. The dust came to it. Sideways.", 10.8, true)
	_say(ev, REVEAL_LAST_SAY, REVEAL_LAST_AT, true)
	_fx(ev, "hold_breath", {"seconds": HOLD_BREATH_SECONDS, "delay": REVEAL_LAST_AT})

# ---------------------------------------------------------------------------------------------
# O04: c_tags
# ---------------------------------------------------------------------------------------------
func _tags(action: String, ev: Array) -> bool:
	match action:
		"tag_next", "tag":
			state.tag = mini(int(state.tag) + 1, TAG_LAST)
		"tag_prev":
			state.tag = maxi(int(state.tag) - 1, 0)
		_:
			return false
	_sfx(ev, "tag_flip")
	state.tag_max = maxi(int(state.tag_max), int(state.tag))
	var t: int = state.tag
	_read_tag()
	if t >= TAG_KEEPS_TIME:
		_observe("o04_keeps_time")
	if t >= TAG_LEANING:
		_observe("o04_leaning")
	if t == TAG_LAST:
		var am_delay := 0.6
		if not has_seen("o04_new_tag"):
			_observe("o04_new_tag")
			_sfx(ev, "tag_settle", 0.6)
			_say(ev, "New brass. Dated tomorrow. Nothing written on it.", 0.8)
			am_delay = 3.0
		if TAG_STAMP_AM in tag_stamp() and not has_seen("o04_am"):
			_observe("o04_am")
			_say(ev, "Someone has stamped it again. A.M.", am_delay)
	return true

## The valve number on tag page `i` ("07"), or "" for an ordinary repair tag.
static func tag_number(i: int) -> String:
	if i < 0 or i >= TAGS.size() or not str(TAGS[i]).begins_with("No. "):
		return ""
	return str(TAGS[i]).substr(4, 2)

## The valve whose toggle carries tag number `num`, or "".
static func valve_for_tag(num: String) -> String:
	for v in VALVE_TAGS:
		if VALVE_TAGS[v] == num:
			return v
	return ""

## A valve tag on show goes into the notebook (its number and its line).
func _read_tag() -> void:
	var num := tag_number(int(state.tag))
	if num != "":
		_observe("tag_" + num)

# ---------------------------------------------------------------------------------------------
# state
# ---------------------------------------------------------------------------------------------
## Marks `n` and every older notice as seen, so an obsolete one never plays later.
func _mark_notice(n: String) -> void:
	var k := NOTICES.find(n)
	for i in k + 1:
		if not NOTICES[i] in state.notices:
			state.notices.append(NOTICES[i])

## Every notice older than the current one is behind her; the current one still plays.
func _prepare_notices() -> void:
	var k := NOTICES.find(current_notice())
	for i in k:
		if not NOTICES[i] in state.notices:
			state.notices.append(NOTICES[i])

func _set_p11_done() -> void:
	state.p11_complete = true
	state.toggles = SOLUTION.duplicate()

## A flag set elsewhere (tests, debug) pulls the local arrangement along. Never clears anything.
func _sync() -> void:
	if game.flag("P11") and not state.p11_complete:
		_set_p11_done()
	# O04 is the tags read once the belt has stopped: found elsewhere means they were opened.
	if game.flag("o04_found") and state.p11_complete and not state.tags_opened:
		state.tags_opened = true

func load_state(d: Variant) -> void:
	state = initial_state()
	trace = ""
	trace_kind = ""
	if not d is Dictionary:
		return
	for key in SAVED_BOOLS:
		if d.get(key) is bool:
			state[key] = d[key]
	var t = d.get("toggles")
	if t is Dictionary and t.size() == VALVES.size():
		var ok := true
		for v in VALVES:
			ok = ok and t.get(v) is bool
		if ok:
			for v in VALVES:
				state.toggles[v] = t[v]
	if _all_whole([d.get("misses")]):
		state.misses = clampi(int(d.misses), 0, 999)
	if _all_whole([d.get("tag")]):
		state.tag = clampi(int(d.tag), 0, TAG_LAST)
	if _all_whole([d.get("tag_max")]):
		state.tag_max = clampi(int(d.tag_max), 0, TAG_LAST)
	state.tag_max = maxi(state.tag_max, state.tag)
	if d.get("previewed_codes") is Array:
		for code in d.previewed_codes:
			if code is String and code in CIRCUITS and not code in state.previewed_codes:
				state.previewed_codes.append(code)
	if d.get("notices") is Array:
		for n in d.notices:
			if n is String and n in NOTICES and not n in state.notices:
				state.notices.append(n)
	# Derived: the solved board is locked in the loop.
	if state.p11_complete:
		_set_p11_done()

## P11 and o04_found are R08's: a flag set elsewhere (tests, debug) is honoured, then the flags
## follow the state.
func reconcile() -> void:
	_sync()
	game.set_flag("P11", state.p11_complete)
	game.set_flag("o04_found", state.tags_opened and state.p11_complete)

# ---------------------------------------------------------------------------------------------
# debug
# ---------------------------------------------------------------------------------------------
const SOLVED_SEEN := ["diaphragm", "cycle_pause", "belt", "bolts", "dust", "valve_board", "drawing",
	"index_seal_cut", "reference_respiration"]

## The local state real play leaves at the start of tide `t`.
func debug_prepare(t: int) -> void:
	if t < 5:
		return
	_set_p11_done()
	for o in SOLVED_SEEN:
		_observe(o)
	_prepare_notices()

## Dev stages: 0 Tide IV fresh, 1 the machine holding (SUPPLY + INDEX open), 2 P11 solved,
## 3..7 weather bands 3..7 (tides V..IX), 8 the sever ending, 9 the continue ending.
func debug_jump(n: int) -> void:
	if n <= 2:
		game.debug_tide(4, ID)
		if n == 1:
			state.toggles.SUPPLY = true
			state.index_offered = true
			for o in ["diaphragm", "cycle_pause", "valve_board", "drawing", "index_seal_cut", "index_hunger"]:
				_observe(o)
			_mark_notice("cycle_pause")
		elif n == 2:
			_set_p11_done()
			game.set_flag("P11")
			for o in SOLVED_SEEN:
				_observe(o)
			_mark_notice("breathes_alone")
	elif n <= 7:
		game.debug_tide(n + 2, ID)
	else:
		game.debug_tide(9, ID)
		game.set_flag("P27")
		game.state.ending = "sever" if n == 8 else "continue"
	trace = ""
	trace_kind = ""
	reconcile()
	_prepare_notices()
