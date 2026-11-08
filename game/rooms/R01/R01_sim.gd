class_name R01Sim
extends RoomSim
## R01, the Jetty. Owns P06, "The Boat That Came Back" (docs/design/puzzle-cards/P06.md,
## rooms.md R01). Node-free and deterministic: every line depends only on this room's state,
## the shared flags and game.weather_band(); nothing is timed here.
##
## The jetty runs through ten states (jetty_state()): "arrival" (nothing moored), "boat"
## (P05 done, P06 not: the three-stripe boat waits at the jetty), "s1".."s7" (after P06,
## one per weather band) and "A" (ending A, the real launch). Every hotspot answers in
## every state. P06: look at the boat through the lens (launch_mismatch), then on the
## mooring panel set UNVERIFIED RETURN and ring the bell under the broken pennant (bell 2).
## The placard states neither: it says only compare and do not board what you have not
## verified; the broken outline drawn on the UNVERIFIED tally is the one painted over bell 2
## (BELL_PENNANTS), so the match is seen, not read or counted. Wrong commits never consume,
## take or lock anything. The reward is the capsule that rises up the mooring line: the
## kitchen service key and Venn's note.
##
## From Tide II until P09 (drained()) the sea is out: mud to the horizon, the pilings bare,
## one standing cylinder of water round the bell, and the boat level on nothing.

const ID := "R01"
const TITLE := "Jetty"
const REQUIRES := []
const LOCKED := ""
const RESUME := "Back on the jetty."
const ARRIVAL := "The jetty. The mooring line hangs into the water, and the water shows no line."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R02", "Office", []],
]
const HOTSPOTS := ["bell", "panel", "line", "launch", "gangway", "pilings", "stump", "station",
	"roof_light", "lighthouse", "causeway"]

const C_PANEL := "c_mooring_panel"
const C_WINDOW := "c_boat_window"
const C_CAPSULE := "c_capsule"
const PANEL_CONTROLS := ["tally_verified", "tally_unverified", "placard", "bell_1", "bell_2",
	"bell_3", "bell_4"]
const WINDOW_CONTROLS := ["peer"]
const CAPSULE_CONTROLS := ["cap", "key", "note"]

const TALLIES := ["", "verified", "unverified"]
const NOTICE_IDS := ["arrival", "boat", "s1", "s2", "s3", "s4", "s5", "s6", "s7", "A", "drained"]
const SAVED_BOOLS := ["p06_complete", "gangway_loop", "capsule_opened", "key_taken", "note_read"]

# --- what the view draws (tests read these) ---------------------------------------------
const PANEL_HEADER := "GREYWAKE SURVEY STATION  ·  MOORING PANEL"
const TALLY_LABELS := {"verified": "VERIFIED", "unverified": "UNVERIFIED RETURN"}
const PLACARD_LINES := [
	"MOORING PROCEDURE",
	"1. Compare the vessel's pennant with the contract.",
	"2. Do not board what you have not verified.",
	"By order of the Board, 1919.",
]
## The pennant painted over each bell, left to right (tools/art/rooms/R01.py BELL_PENNANTS):
## the contract's two stripes (as on the VERIFIED tally), the broken outline (as on the
## UNVERIFIED RETURN tally), the wave (weather), the cross (fire).
const BELL_PENNANTS := ["matching", "broken", "wave", "cross"]
const PLACARD_PENCIL := "It comes when called. Not only then.  E.V."
const PLACARD_ADA := "It came when called.  A.M."
const NOTE_TEXT := "If it brought you your own room, do not give it your address."
const NOTE_SIGN := "E.V."
const KEY_TAG := "SERVICE"
## After Tide I (tide_done(1)) until band 3 sees it sawn down to a stump.
const PILINGS_TEN := "Ten pilings now. I counted eight from the launch."
## While the sea is out (drained()).
const PILINGS_DRAINED := "Ten pilings, bare to the mud. They drip. Every drip stops at the same height, flat."

const OBSERVATIONS := {
	"bell": "The mooring bell's lip is under the water. The water round it doesn't move, and it makes no ripple.",
	"bell_note": "The mooring bell rang once, low. It never moved.",
	"line": "The mooring line runs straight down into the Sound. Something is tied to it, far below. The water shows no reflection of the line.",
	"pilings": "Nine pilings under the jetty. From the launch I counted eight.",
	"pilings_ten": "Ten pilings now: the tenth stands past the end of the jetty, holding nothing up. I counted eight from the launch.",
	"tenth_piling": "The tenth piling is dry, pale oak: no weed line, no barnacles, no reflection. Nothing has ever stood on it.",
	"sea_out": "The sea has gone out from the jetty: mud flats to the horizon. The water round the bell stayed, a standing cylinder, level with the bell's lip where the sea had been.",
	"drips": "The pilings stand bare to the mud. They drip, and every drip stops at the same height, flat, as if it met water that isn't there.",
	"line_mud": "The mooring line runs straight down into the mud and stays taut. Something is still tied to it, below.",
	"tenth_stump": "A tenth piling stump stands past the end of the jetty. Its reflection comes after the water moves, like all of them now.",
	"lighthouse": "The lighthouse on the headland. Nobody is posted there. At dusk its lamp was dark.",
	"launch_left": "The launch that brought me is just past the lighthouse. Every time I look, it is exactly there.",
	"lighthouse_gone": "The lighthouse has gone from the headland. The headland is still there.",
	"lighthouse_behind": "The lighthouse stands behind the station, above the roof, where there is no land.",
	"causeway": "The old service causeway, broken in three places. Nobody is walking out on that.",
	"causeway_ladder": "Through the lens: an iron ladder goes down into the causeway's middle gap, and on below the water.",
	"panel": "Mooring panel placard: 'Compare the vessel's pennant with the contract. Do not board what you have not verified.' Two tallies, VERIFIED and UNVERIFIED RETURN, each with a pennant drawn on it. Four bells, each hanging under a painted pennant. In pencil, Venn: 'It comes when called. Not only then.'",
	"placard_ada": "Under Venn's pencil line on the placard, a second line in my handwriting: 'It came when called. A.M.' I didn't write it.",
	"boat": "A boat at the jetty, and no water under it. It sits level on nothing.",
	"launch_mismatch": "The boat has a three-stripe pennant. The contract's launch has two. Through its window: the chart room, my chart on the table.",
	"window_figure": "A second look through the lens: someone is standing at my chart table in the boat's window, writing on my chart, right-handed.",
	"window_figure_turned": "A second look through the lens: someone is standing at my chart table in the boat's window. They had turned round. They were looking out at me.",
	"gangway_loop": "I stepped onto the boat's gangway and stepped out of the shed door, onto this jetty. Not a maze. It will not let me board.",
	"withdrew": "The boat withdrew stern first without turning, its bow toward the station the whole way. Then a capsule came up the mooring line by itself.",
	"venn_address_note": "In a capsule on the mooring line, the kitchen service key and Venn's note: 'If it brought you your own room, do not give it your address.'",
	"far_end": "Rain hides the far end of the jetty. The mooring line is still clear.",
	"late_water": "The pilings' reflections lag the waves, and the sound of the water comes a beat after the chop.",
	"horizon_tilt": "The horizon tilts up toward the station. The jetty and the causeway are level.",
	"silent_rain": "Rain is falling on the jetty. It makes no sound. Neither does the wind.",
	"surface": "Past the end of the jetty there is no sea. A dark surface stands upright a few hundred yards off. Something moves across it, slowly.",
	"office_window": "From the jetty, the office window: someone is sitting at the desk, writing left-handed. I am out here.",
	"real_launch": "Morning. The real launch, two stripes. Its window shows its own empty cabin.",
}

## The first-time arrival hold per jetty state (rooms.md "Notice"), and what it notes.
const NOTICE := {
	"arrival": "The bell's lip is under the water. The water doesn't move round it.",
	"boat": "A boat at the jetty, and no water under it. It sits level on nothing.",
	"s1": "The capsule's still on the line.",
	"s2": "I can't see the end of the jetty from here.",
	"s3": "The reflections are late. They move after the water does.",
	"s4": "The horizon's tilted. The jetty hasn't.",
	"s5": "It's raining. I can't hear it.",
	"s6": "The lighthouse is behind the station.",
	"s7": "There's no sea past the jetty. There's a surface, standing up.",
	"A": "Grey water. Gulls. A launch with two stripes.",
	## Not a jetty state: the first arrival in Tide II, when the sea is out (drained()).
	"drained": "The sea's gone out. All of it, to the horizon. Except round the bell.",
}
const NOTICE_OBS := {
	"boat": ["boat", "sea_out"], "drained": ["sea_out"], "s2": ["far_end"], "s3": ["late_water", "tenth_stump"],
	"s4": ["horizon_tilt"], "s5": ["silent_rain", "lighthouse_gone"],
	"s6": ["lighthouse_behind", "bell_note"], "s7": ["surface"], "A": ["real_launch"],
}

const OBJECTIVES := {
	"explore": "Look around the jetty. Nothing is moored here yet.",
	"inspect": "A boat has answered the signal. Identify it before boarding.",
	"signal": "Answer the boat at the mooring panel.",
	"capsule": "Something rose up the mooring line.",
	"after": "The service key fits the office's service door.",
	"done": "The jetty has nothing more for me.",
}
## P06's evidence tier: what the notebook and the placard already say, short of the answer.
const EVIDENCE_INSPECT := "The contract's launch flies two stripes; this one flies three. And I can't certify what I haven't looked into."
const EVIDENCE_SIGNAL := "My notebook: three stripes on its pennant, the contract's launch has two. The placard says not to board what I haven't verified, and the panel has a tally for that."
## The signal ladder's third tier: the tally's drawn pennant is the bell's painted one.
const HINT_PENNANT := "The tallies have a pennant drawn on them. One of the bells hangs under the same shape."
const HINTS := {
	"explore": [
		"Nothing out here needs me yet. Something may come in later.",
		"The contract says the collection launch answers the departure signal.",
		"Restore the departure signal in the chart room. Then come back to the jetty.",
	],
	# P06 has four tiers (hint_tiers()): a nudge, the relationship, the evidence, the answer.
	# Once the lens has shown the mismatch ("signal") the relationship is spent; its tiers are
	# the nudge, the evidence, the tally-to-bell pennant (HINT_PENNANT), the answer.
	"inspect": [
		"The boat at the jetty doesn't match something you've read.",
		"Compare its pennant with the launch on the contract. Its lit window wants a closer look.",
		EVIDENCE_INSPECT,
		"Use the inspection lens on the boat's window. Then set UNVERIFIED RETURN on the mooring panel and ring the bell under the broken pennant, second from the left.",
	],
	"signal": [
		"The boat at the jetty doesn't match something you've read.",
		EVIDENCE_SIGNAL,
		HINT_PENNANT,
		"Set UNVERIFIED RETURN on the mooring panel and ring the bell under the broken pennant, second from the left.",
	],
	"capsule": [
		"Something came up the mooring line.",
		"The capsule on the line has a screw cap.",
		"Open the capsule on the mooring line: turn the cap, take the key, read the note.",
	],
	"after": [
		"The key is for the office.",
		"The service door is on the office's entry wall, beside the outer door.",
		"Use the kitchen service key on the service door in the office.",
	],
	"done": [
		"Nothing on the jetty needs me now.",
		"The work is inside the station.",
		"Go back to the office; the notebook's objective says where next.",
	],
}
## Items this room hands out (docs/design/puzzle-cards/flags.md section 4).
const ITEMS := {
	"service_key": {"name": "Service key", "desc": "A key from the capsule on the mooring line. It fits the office's service door."},
}

const KEY_LINE := "That's for the office's service door, not anything out here."
const VERIFIED_MISS := "The pennant's wrong. The contract boat has two stripes. This one has three."
const BELL_MISS := "That's not the bell for a mismatched vessel. Each bell hangs under its own pennant."
const REFUSAL := "I haven't looked at it properly. 'Do not certify an observation you have not made.'"
const NO_TALLY := "A tally first. Then a bell."
const CAP_ON := "The cap's still on."
const CAUSEWAY_MUD := "The causeway stands on bare mud now. A ladder goes down into the middle gap, into the mud."
const SEA_OUT_BELL := "The sea's gone out to the horizon. The water round the bell hasn't. It stands there in a column, level with the lip, on its own."
const NOTE_QUOTE := "\"If it brought you your own room, do not give it your address.\""

func initial_state() -> Dictionary:
	return {
		"panel_tally": "", "lens_looks": 0, "launch_looks": 0, "lighthouse_looks": 0,
		"misses": 0, "gangway_loop": false, "p06_complete": false, "capsule_opened": false,
		"key_taken": false, "note_read": false, "noticed": [],
	}

# ---------------------------------------------------------------------------
# public helpers (the view reads these; all pure)
# ---------------------------------------------------------------------------
## "arrival", "boat", "s1".."s7" or "A" (rooms.md R01 state table).
func jetty_state() -> String:
	if game.value("ending_choice") == "sever":
		return "A"
	if not state.p06_complete:
		return "boat" if game.flag("P05") else "arrival"
	return "s%d" % maxi(1, game.weather_band())

## Tide II until P09: the sea is out from the jetty (assets/stages/R01/jetty_drained_r3.png).
## Weather from progress only: the tide and the P09 flag, never a clock.
func drained() -> bool:
	return game.tide() >= 2 and not game.flag("P09") and jetty_state() in ["arrival", "boat", "s1"]

func boat_present() -> bool:
	return jetty_state() == "boat"

func figure_seen() -> bool:
	return state.lens_looks >= 2

func tally() -> String:
	return state.panel_tally

## "none" before P06, then "closed" until the cap is turned, then "open".
func capsule_state() -> String:
	if not state.p06_complete:
		return "none"
	return "open" if state.capsule_opened else "closed"

## The state as a number for "before / from" comparisons: arrival and boat 0, sN N, A 8.
static func rank(s: String) -> int:
	if s == "A":
		return 8
	if s.begins_with("s") and s.length() == 2:
		return int(s.substr(1))
	return 0

func is_closeup(v := local_view) -> bool:
	return v != "room"

# ---------------------------------------------------------------------------
# arrival
# ---------------------------------------------------------------------------
func arrive(ev: Array, first: bool) -> void:
	if first:
		_say(ev, ARRIVAL)
	var s := jetty_state()
	if not s in state.noticed:
		state.noticed.append(s)
		for o in NOTICE_OBS.get(s, []):
			_observe(o)
		ev.append({"type": "fx", "id": "notice", "state": s})
		_say(ev, NOTICE[s], 1.5, true)
		if drained() and s == "boat":
			state.noticed.append("drained")   # the boat's notice says it: no water under it
	elif drained() and not "drained" in state.noticed:
		state.noticed.append("drained")
		for o in NOTICE_OBS["drained"]:
			_observe(o)
		ev.append({"type": "fx", "id": "notice", "state": "drained"})
		_say(ev, NOTICE["drained"], 1.5, true)
	if s == "s6":
		_sfx(ev, "bell_low", 0.8)

# ---------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------
func act(action: String, ev: Array) -> void:
	match local_view:
		C_PANEL:
			if action in PANEL_CONTROLS:
				_panel(action, ev)
				return
		C_WINDOW:
			if action in WINDOW_CONTROLS:
				_peer(ev)
				return
		C_CAPSULE:
			if action in CAPSULE_CONTROLS:
				_capsule(action, ev)
				return
	if action in HOTSPOTS:
		# A room hotspot from a close-up (drivers, the skeleton walk): step back to the room.
		local_view = "room"
		_room(action, ev)

func _room(action: String, ev: Array) -> void:
	var s := jetty_state()
	var n := rank(s)
	match action:
		"bell": _bell(s, ev)
		"panel":
			var first := not has_seen("panel")
			local_view = C_PANEL
			_observe("panel")
			if state.p06_complete:
				_say(ev, "UNVERIFIED RETURN, still set.")
			elif first:
				_say(ev, "The mooring panel. A placard, two tallies, four bells, a pennant over each.")
			else:
				_say(ev, "The mooring panel.")
			if game.weather_band() >= 5 and not has_seen("placard_ada"):
				_observe("placard_ada")
				_say(ev, "There's a second pencil line under Venn's. My handwriting.", 1.2, true)
		"line": _line(ev)
		"launch": _launch(s, ev)
		"gangway": _gangway(s, ev)
		"pilings":
			if drained():
				_observe("pilings_ten")
				_observe("drips")
				_say(ev, PILINGS_DRAINED)
			elif n < 3 and game.tide_done(1):
				_observe("pilings_ten")
				_say(ev, PILINGS_TEN)
			elif n < 3:
				_observe("pilings")
				_say(ev, "Nine pilings. From the launch I counted eight.")
			else:
				_say(ev, "Nine pilings. Past the end, the stump of a tenth.")
		"stump":
			if s == "A":
				_say(ev, "A tenth stump. Still there.")
			elif n < 3 and game.tide_done(1):
				_observe("tenth_piling")
				_say(ev, "The tenth piling. It holds nothing up. Every other one is weed and barnacles; this one's dry.")
			elif n < 3:
				_say(ev, "Nothing past the end of the jetty but water.")
			elif n < 7:
				_observe("tenth_stump")
				_say(ev, "A tenth piling, sawn off at the waterline. Its reflection comes late.")
			else:
				_say(ev, "The stump stands against the surface. It's the last thing before it.")
		"station": _station(s, ev)
		"roof_light":
			if s == "A":
				_say(ev, "Just the roof. Gulls on the ridge.")
			elif n < 6:
				_say(ev, "The station roof. Slates and a gutter, nothing above it.")
			elif n == 6:
				_observe("lighthouse_behind")
				_say(ev, "The lighthouse. Behind the station, where there's no land at all. It isn't turning.")
			else:
				_say(ev, "Only the roof now. Something stood behind it.")
		"lighthouse": _lighthouse(s, ev)
		"causeway": _causeway(s, ev)

func _bell(s: String, ev: Array) -> void:
	match s:
		"s1":
			_observe("bell")
			_observe("sea_out")
			_say(ev, SEA_OUT_BELL)
		"s2":
			_observe("bell")
			_say(ev, "The sea's back, higher than it was. Round the bell it keeps to the lip, exactly.")
		"arrival", "boat":
			if drained() and not has_seen("sea_out"):
				_observe("bell")
				_observe("sea_out")
				_say(ev, SEA_OUT_BELL)
			elif has_seen("bell"):
				_say(ev, "It doesn't swing. The water holds it.")
			else:
				_observe("bell")
				_say(ev, "The mooring bell hangs too low. Its lip is under the water, and there's no ripple round it.")
		"s3", "s4":
			_say(ev, "The waves go past the bell. Its reflection waits, then follows.")
		"s5":
			_say(ev, "Rain on the bell. The brass makes no sound under it.")
		"s6":
			_observe("bell_note")
			_say(ev, "It rang once, low, when I came out. It never moved.")
		"s7":
			_say(ev, "The bell's the brightest thing out here. Its lip is still under the water.")
		_:
			_say(ev, "The bell hangs clear of the water. It swings a little. It sounds like a bell.")

func _line(ev: Array) -> void:
	if not state.p06_complete:
		if drained():
			_observe("line_mud")
			_say(ev, "The line goes straight down into the mud, taut. Something down there is still holding it.")
			return
		_observe("line")
		_say(ev, "The line goes straight down into the Sound. Something's tied to it, far down. The water shows no line.")
		return
	local_view = C_CAPSULE
	if not state.capsule_opened:
		_say(ev, "The capsule. Warm brass, and dry.")
	elif state.key_taken and state.note_read:
		_say(ev, "Open. Empty.")
	else:
		_say(ev, "The capsule's open.")

func _launch(s: String, ev: Array) -> void:
	match s:
		"arrival":
			_say(ev, "Mud to the horizon. Nothing's moored here." if drained()
				else "Open water. Nothing's moored here.")
		"boat":
			if has_seen("launch_mismatch"):
				_say(ev, "It's waiting for an answer. The panel's on the shed wall.")
				return
			var look: int = state.launch_looks
			state.launch_looks = mini(look + 1, 9)
			if look == 0:
				_observe("boat")
				if game.has_seen("R02", "contract"):
					_say(ev, "Three stripes on its pennant. The contract's launch has two.")
				else:
					_say(ev, "Three stripes on its pennant. No water under it, and it sits level anyway.")
			elif look == 1:
				_say(ev, "Its keel's clear of the mud. Nothing under it. Not even a shadow.")
			else:
				_say(ev, "The cabin window's lit. Too far to make out without a lens.")
		"s1":
			_observe("sea_out")
			_say(ev, "Mud where it sat. Not a keel mark in it. It never touched the ground.")
		"s7":
			_say(ev, "Where it sat, the water stops. Then the surface.")
		"A":
			_observe("real_launch")
			_say(ev, "The real launch. Two stripes. Its window shows its own cabin, empty.")
		_:
			_say(ev, "Flat water where it sat. Flatter than the rest.")

func _gangway(s: String, ev: Array) -> void:
	match s:
		"arrival":
			_say(ev, "A gangway, drawn up. Nothing's moored here to board.")
		"boat":
			if state.gangway_loop:
				_say(ev, "Once was enough.")
				return
			state.gangway_loop = true
			_sfx(ev, "gangway_step", 0.0)
			_sfx(ev, "door_shed", 0.7)
			_fx(ev, "gangway_loop")
			_say(ev, "I've just walked onto the jetty I was standing on.", 1.2, true)
			_say(ev, "Not a maze. It just won't take me.", 3.8, true)
			_observe("gangway_loop")
		"A":
			_say(ev, "Drawn up. Dry.")
		_:
			_say(ev, "Drawn up again. I never touched it.")

func _station(s: String, ev: Array) -> void:
	if not game.flag("P01"):
		_say(ev, "The station. The office window's dark. The one beside it is lit.")
		return
	match s:
		"arrival", "boat":
			_say(ev, "The office window, lit. I left the lamp on. The one beside it is lit too.")
		"s5", "s6":
			_say(ev, "The office window's lit. The rest of the station is the colour of the sky.")
		"s7":
			_observe("office_window")
			_say(ev, "Someone's sitting at the desk in the office window. I'm out here.")
		"A":
			_say(ev, "The office window. Daylight in it. Empty.")
		_:
			_say(ev, "The office window, lit. I left the lamp on.")

func _lighthouse(s: String, ev: Array) -> void:
	match s:
		"arrival":
			var look: int = state.lighthouse_looks
			state.lighthouse_looks = mini(look + 1, 9)
			if look == 0:
				_observe("lighthouse")
				_say(ev, "The lighthouse. Dark; nobody's posted there. The launch that brought me is just past it.")
			else:
				_observe("launch_left")
				_say(ev, "The launch is exactly where it was. It hasn't got any further.")
		"boat":
			_observe("lighthouse")
			_say(ev, "The lighthouse. Dark. Its rock stands up out of the mud, weed round its waist.")
		"s1", "s2":
			_observe("lighthouse")
			_say(ev, "The lighthouse. Dark again. The storm's on it and nobody's posted there.")
		"s3":
			_observe("lighthouse")
			_say(ev, "The lighthouse. Lit now. Nobody's posted there.")
		"s4":
			_say(ev, "The headland and the lighthouse lean with the horizon. The jetty doesn't.")
		"s5":
			_observe("lighthouse_gone")
			_say(ev, "The headland's there. The lighthouse isn't.")
		"s6":
			_say(ev, "Nothing on the headland. The light is behind me, over the station roof.")
		"s7":
			_say(ev, "No headland. The surface comes right up to where it was.")
		_:
			_say(ev, "The lighthouse, where it should be. Its lamp is out for the morning.")

func _causeway(s: String, ev: Array) -> void:
	match s:
		"arrival", "boat":
			_observe("causeway")
			if drained():
				_say(ev, CAUSEWAY_MUD)
			else:
				_say(ev, "The old service causeway, broken in three places. Nobody's walking out on that.")
		"s1":
			_observe("causeway")
			_say(ev, CAUSEWAY_MUD)
		"s2", "s3":
			_say(ev, "Rain over the causeway. The gaps look wider.")
		"s4":
			_say(ev, "The causeway's level. The sea behind it isn't.")
		"s5", "s6":
			_say(ev, "I can't find the causeway. Sea and sky are one grey.")
		"s7":
			_say(ev, "No causeway. No sea. A surface, close.")
		_:
			_say(ev, "The causeway, broken in three places. Ordinary ruin.")

# ---------------------------------------------------------------------------
# P06: the mooring panel
# ---------------------------------------------------------------------------
func _panel(action: String, ev: Array) -> void:
	match action:
		"tally_verified", "tally_unverified":
			if state.p06_complete:
				_say(ev, "The tally's set. The boat's gone.")
				return
			var t := "verified" if action == "tally_verified" else "unverified"
			state.panel_tally = "" if state.panel_tally == t else t
			_sfx(ev, "tally_flip")
			match state.panel_tally:
				"verified": _say(ev, "VERIFIED.")
				"unverified": _say(ev, "UNVERIFIED RETURN.")
				_: _say(ev, "Tally cleared.")
		"placard":
			_observe("panel")
			_say(ev, "'Compare the vessel's pennant with the contract. Do not board what you have not verified.'")
		_:
			_ring(int(action.substr(5)), ev)

func _ring(n: int, ev: Array) -> void:
	var bell_sfx := "station_bell_%d" % n
	if state.p06_complete:
		if game.weather_band() < 7:
			_sfx(ev, "bell_pull")
			_say(ev, "The boat's gone. I'm not calling it back.")
		else:
			_say(ev, "Not now. Not with that out there.")
		return
	if not boat_present():
		_sfx(ev, "bell_pull")
		_sfx(ev, bell_sfx, 0.15)
		_say(ev, "The bell rings out along the jetty. Nothing's moored to hear it.")
		return
	match state.panel_tally:
		"":
			_say(ev, NO_TALLY)
		"verified":
			_sfx(ev, "bell_pull")
			_sfx(ev, bell_sfx, 0.15)
			_sfx(ev, "tally_reset", 0.6)
			state.panel_tally = ""
			_miss()
			_say(ev, VERIFIED_MISS)
		_:
			if n != 2:
				_sfx(ev, "bell_pull")
				_sfx(ev, bell_sfx, 0.15)
				_miss()
				_say(ev, BELL_MISS)
			elif not has_seen("launch_mismatch"):
				# She stops her hand: no sound, nothing changes.
				_say(ev, REFUSAL)
			else:
				_commit(ev)

func _miss() -> void:
	state.misses = mini(int(state.misses) + 1, 99)

## UNVERIFIED RETURN + the bell under the broken pennant, with the boat looked at through the lens.
func _commit(ev: Array) -> void:
	state.p06_complete = true
	if not "boat" in state.noticed:
		state.noticed.append("boat")
	if not "s1" in state.noticed:
		state.noticed.append("s1")
	if not "drained" in state.noticed:
		state.noticed.append("drained")
	local_view = "room"
	_sfx(ev, "bell_pull", 0.0)
	game.solve("P06", ev)
	_sfx(ev, "station_bell_2_dead", 0.15)
	_fx(ev, "withdraw")
	_say(ev, "The broken pennant's bell.", 0.4, true)
	_say(ev, "Nothing answers it. Not even the water.", 2.4, true)
	_say(ev, "It's going. Stern first. Its bow never leaves the station.", 5.2, true)
	_say(ev, "Someone's standing at the chart table in its window." if state.lens_looks < 2
		else "Whoever's at my chart doesn't look up. They've reached the part where I came in.", 8.6, true)
	_sfx(ev, "water_close", 11.2)
	_sfx(ev, "capsule_rise", 11.5)
	_say(ev, "The mooring line's moving. Something's coming up it on its own.", 12.0, true)
	_sfx(ev, "capsule_knock", 14.5)
	_say(ev, "A capsule. It's stopped at the cleat.", 15.0, true)
	_observe("withdrew")

# ---------------------------------------------------------------------------
# the lens and the boat's window
# ---------------------------------------------------------------------------
func _lens_launch(ev: Array) -> void:
	if not boat_present():
		if not state.p06_complete:
			_say(ev, "Through the lens, just water.")
		elif jetty_state() == "s1":
			_say(ev, "Through the lens: mud where it sat, smooth as a plate.")
		else:
			_say(ev, "The water where it sat is flat as a plate.")
		return
	local_view = C_WINDOW
	_sfx(ev, "lens_click")
	if state.lens_looks == 0:
		state.lens_looks = 1
		_observe("launch_mismatch")
		_say(ev, "Through the lens: its cabin window.", 0.0)
		_say(ev, "It's the chart room. My chart's on the table, my pencil marks on it.", 1.6, true)
		_say(ev, "The pennant has three stripes. The contract's launch has two.", 4.2, true)
	else:
		_peer(ev)

func _peer(ev: Array) -> void:
	var turned := game.flag("t1x_turned")
	match int(state.lens_looks):
		0:
			_say(ev, "Too far to make out without a lens.")
		1:
			state.lens_looks = 2
			_fx(ev, "figure")
			_sfx(ev, "pen_near", 0.6)
			_say(ev, "Someone's standing at my chart.", 0.0, true)
			if turned:
				_say(ev, "They've turned round. They're looking out through the glass. At me.", 2.2, true)
				_observe("window_figure_turned")
			else:
				_say(ev, "Writing on it. With the right hand, like me.", 2.2, true)
				_observe("window_figure")
		_:
			_say(ev, "Still looking at me." if turned else "Still there. Still writing.")

func use_item(item: String, target: String, ev: Array) -> bool:
	match item:
		"inspection_lens":
			return _use_lens(target, ev)
		"service_key":
			if target in HOTSPOTS or target in PANEL_CONTROLS or target in WINDOW_CONTROLS \
					or target in CAPSULE_CONTROLS:
				_say(ev, KEY_LINE)
				return true
		"pencil":
			if target == "placard":
				_say(ev, "I'm not writing on his placard.")
				return true
	return false

func _use_lens(target: String, ev: Array) -> bool:
	if target in PANEL_CONTROLS:
		_say(ev, "The lens won't choose for me. The pennants are painted plain enough.")
		return true
	if target in CAPSULE_CONTROLS:
		_say(ev, "Clean brass. Nothing grows on it. It came up from the bottom.")
		return true
	if target == "peer":
		_peer(ev)
		return true
	if not target in HOTSPOTS:
		return false
	var s := jetty_state()
	var n := rank(s)
	local_view = "room"
	match target:
		"launch":
			_lens_launch(ev)
		"bell":
			_say(ev, "Under the lens, the water round the lip is flat as glass, set in round it.")
		"line":
			if state.p06_complete:
				_line(ev)
			else:
				_say(ev, "Through the lens the line goes down further than the water is deep.")
		"pilings":
			_say(ev, "Nine. I make it nine every time now.")
		"stump":
			if n >= 3:
				_say(ev, "Sawn clean. Fresh wood. Nobody's sawn anything out here in years.")
			elif game.tide_done(1):
				_say(ev, "Through the lens: no saw marks, no rot, no tool marks at all. It was never put there.")
			else:
				_say(ev, "Water.")
		"lighthouse":
			if s == "A":
				_say(ev, "Through the lens, the gallery's empty and the lamp is out.")
			elif n == 0:
				_say(ev, "Through the lens, the gallery's empty and the lamp is dark.")
			elif n < 3:
				_say(ev, "Through the lens, the gallery's empty and the lamp is dark.")
			elif n < 5:
				_say(ev, "Through the lens, the gallery's empty and the lamp is lit.")
			elif n == 5:
				_say(ev, "The lens finds the headland. Nothing on it.")
			else:
				_say(ev, "Nothing. It's behind me.")
		"roof_light":
			_say(ev, "Through the lens the lighthouse door is open. Light comes out of it, onto nothing."
				if s == "s6" else "Slates.")
		"station":
			_say(ev, "Through the lens: they're writing. Left-handed." if s == "s7" else "The desk, the lamp. Nobody.")
		"causeway":
			_observe("causeway_ladder")
			_say(ev, "Through the lens: a ladder goes down into the middle gap. It goes on into the mud." if s == "s1"
				else "Through the lens: a ladder goes down into the middle gap. It goes on below the water.")
		"gangway":
			_say(ev, "Dry oak. Everything else out here is wet.")
		"panel":
			local_view = C_PANEL
			_observe("panel")
			_say(ev, "The placard's clear enough without it.")
	return true

# ---------------------------------------------------------------------------
# the capsule
# ---------------------------------------------------------------------------
func _capsule(action: String, ev: Array) -> void:
	match action:
		"cap":
			if state.capsule_opened:
				_say(ev, "It's off.")
				return
			state.capsule_opened = true
			_sfx(ev, "cap_unscrew")
			_fx(ev, "cap_off")
			# One feedback line, not a chain: a quick click on the key must not queue behind it.
			_say(ev, "The cap turns easily. It's warm. Inside: a key, and a rolled note.", 0.0)
		"key":
			if not state.capsule_opened:
				_say(ev, CAP_ON)
			elif state.key_taken:
				_say(ev, "I have it.")
			else:
				state.key_taken = true
				game.give("service_key", ev)
				_sfx(ev, "key_take")
				_say(ev, "The kitchen service key. The tag says SERVICE, in Venn's hand.")
		"note":
			if not state.capsule_opened:
				_say(ev, CAP_ON)
			elif state.note_read:
				_fx(ev, "note")
				_say(ev, NOTE_QUOTE)
			else:
				state.note_read = true
				_observe("venn_address_note")
				_fx(ev, "note")
				_sfx(ev, "note_unfold")
				_say(ev, NOTE_QUOTE, 0.3, true)
				_say(ev, "It came up out of the sea, and it's dry.", 3.8, true)

# ---------------------------------------------------------------------------
# objectives
# ---------------------------------------------------------------------------
func objective() -> String:
	if jetty_state() == "A":
		return "done"
	var p06: bool = state.p06_complete
	if not game.flag("P05") and not p06:
		return "explore"
	if not p06:
		return "signal" if has_seen("launch_mismatch") else "inspect"
	if not (state.key_taken and state.note_read):
		return "capsule"
	if game.has_item("service_key"):
		return "after"
	return "done"

func hint_frozen() -> bool:
	return false

## P06's ladders have four tiers (an evidence tier before the answer); the rest have three.
func hint_tiers() -> int:
	return 4 if HINTS.get(objective(), []).size() >= 4 else 3

# ---------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------
func load_state(d: Variant) -> void:
	state = initial_state()
	if not d is Dictionary:
		return
	for key in SAVED_BOOLS:
		if d.get(key) is bool:
			state[key] = d[key]
	var t = d.get("panel_tally")
	if t is String and t in TALLIES:
		state.panel_tally = t
	for spec in [["lens_looks", 2], ["launch_looks", 9], ["lighthouse_looks", 9], ["misses", 99]]:
		var v = d.get(spec[0])
		if v != null and _all_whole([v]):
			state[spec[0]] = clampi(int(v), 0, spec[1])
	if d.get("noticed") is Array:
		for s in d.noticed:
			if s is String and s in NOTICE_IDS and not s in state.noticed:
				state.noticed.append(s)
	# Derived fields must agree: progress implies its prerequisites.
	if state.p06_complete:
		state.panel_tally = "unverified"
		state.lens_looks = maxi(1, state.lens_looks)
	state.capsule_opened = state.capsule_opened and state.p06_complete
	state.key_taken = state.key_taken and state.capsule_opened
	state.note_read = state.note_read and state.capsule_opened

## P06 is R01's (flags.md): it follows the local state. Runs after the notebook loads.
## Never gives or takes items.
func reconcile() -> void:
	game.set_flag("P06", state.p06_complete)
	if state.p06_complete and not has_seen("launch_mismatch"):
		_observe("launch_mismatch")
	if state.note_read and not has_seen("venn_address_note"):
		_observe("venn_address_note")
	if not state.p06_complete and state.lens_looks >= 1 and not has_seen("launch_mismatch"):
		state.lens_looks = 0

# ---------------------------------------------------------------------------
# dev
# ---------------------------------------------------------------------------
## The state real play leaves at the start of tide t.
func debug_prepare(t: int) -> void:
	if t < 3:
		return
	state.p06_complete = true
	state.panel_tally = "unverified"
	state.lens_looks = 1
	state.capsule_opened = true
	state.key_taken = true
	state.note_read = true
	state.noticed = ["arrival", "boat", "s1", "drained"]
	for o in ["boat", "panel", "launch_mismatch", "withdrew", "venn_address_note"]:
		_observe(o)
	# From tide IV the key has been spent at the office's service door.
	if t == 3 and not game.has_item("service_key"):
		game.give("service_key")

## Dev-only room stages, standing on the jetty: 0 arrival, 1 boat, 2 one ring from solving,
## 3 P06 just solved (capsule closed), 4 capsule done (key in hand), 5-8 bands 3, 5, 6, 7,
## 9 the ending A preview.
func debug_jump(n: int) -> void:
	match n:
		0:
			game.reset()
			game.debug_enter(ID)
		1, 2:
			game.debug_tide(2, ID)
			game.set_flag("P04")
			game.set_flag("P05")
			if not game.has_item("inspection_lens"):
				game.give("inspection_lens")
			if n == 2:
				state.lens_looks = 1
				state.panel_tally = "unverified"
				_observe("launch_mismatch")
				_observe("panel")
		3:
			game.debug_tide(3, ID)
			state.capsule_opened = false
			state.key_taken = false
			state.note_read = false
			game.state.notebook.erase(ID + ".venn_address_note")
			game.take("service_key")
		4:
			game.debug_tide(3, ID)
		5:
			game.debug_tide(5, ID)
		6:
			game.debug_tide(7, ID)
		7:
			game.debug_tide(8, ID)
		8:
			game.debug_tide(9, ID)
		9:
			game.debug_tide(9, ID)
			game.state.ending = "sever"
	reconcile()
