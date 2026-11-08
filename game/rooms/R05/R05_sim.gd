class_name R05Sim
extends RoomSim
## R05, the Kitchen and Mess. Owns P07 (nine appetites) and P09 (the meal they removed):
## docs/design/puzzle-cards/P07.md, P09.md and rooms.md R05. Node-free and deterministic; the
## view reads the helpers at the bottom and the transient vars (held, last_compare, tape,
## ledger_spread), and plays the events.
##
## Two base views: "room" (A, the mess table) and "kitchen" (B, range, book, shift board; not a
## close-up). Close-ups: c_table (P07), c_ledger (Nora's book), c_service_board (P09),
## c_register (Rook's shift register at 2x, from c_table's register plate) and c_work_card (Nora's
## work card held up over the kitchen; the kitchen's other hotspots stay live beside it).

const ID := "R05"
const TITLE := "Kitchen and Mess"
const REQUIRES := ["P06"]
const LOCKED := "The service door is locked. A tag on it: KITCHEN · BUNKS. The key went out with the launch."
const RESUME := "Back in the kitchen and mess."
const ARRIVAL := "Eight places laid. Nine spoon marks pressed into the cloth, and one more place with none."
## The objective line for the way in, while R05 is shut or unvisited (the core reads it).
const WAY_IN_HINT := "The service door off the office is open. Through it: the kitchen."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R02", "Office", []],
	["R07", "Laboratory", []],
	["R08", "Machine room", []],
	["R06", "Bunk room", []],
]

## View A (the mess) and view B (the kitchen) hotspots, in hit order.
const HOTSPOTS := ["spoon", "unsigned_bowl", "tally", "towel", "window", "place_1", "place_2",
	"place_3", "place_4", "place_5", "place_6", "place_7", "place_8", "place_9", "place_10",
	"bowl_stack", "chair", "to_kitchen"]
const KITCHEN_HOTSPOTS := ["work_card", "menu_note", "kettle", "ledger", "service_drawer",
	"service_hatch", "shift_board", "range", "to_mess"]
const CLOSEUPS := ["c_table", "c_ledger", "c_service_board", "c_register", "c_work_card"]

## Close-up controls (the view's rects carry the same ids).
const TABLE_CONTROLS := ["place_1", "place_2", "place_3", "place_4", "place_5", "place_6",
	"place_7", "place_8", "place_9", "place_10", "slot_0", "slot_1", "slot_2", "slot_3", "slot_4", "slot_5",
	"slot_6", "slot_7", "slot_8", "tally_down", "tally_up", "compare", "look_register"]
const LEDGER_CONTROLS := ["page_prev", "page_next", "left_page", "right_page"]
const BOARD_CONTROLS := ["tile_0", "tile_1", "tile_2", "tile_3", "tile_4", "tile_5", "tile_6",
	"tile_7", "tile_8", "tile_9", "f_count", "f_name", "f_status", "count_down", "count_up",
	"look_count", "socket_pantry", "socket_bunk", "socket_turn", "seal_1", "seal_2", "seal_3",
	"stamp", "look_rule", "look_rubbing"]
## Only after P09: the copy of the second board.
const BOARD_CONTROLS_AFTER := ["look_duplicate"]

# --- P07: the table for nine -------------------------------------------------------------------
## The cloth's place marks, place_1 .. place_10. Two places carry no initials: place_9, the end
## place by the kitchen door (his, with the empty spoon dent), and place_10, at the rack end with
## no dent at all. Which blank is his is a deduction: Nora's margin (the night watch sits by the
## door) and R06's calendar (Venn had the 18th).
const PLACE_MARKS := ["S.R.", "A.T.", "S.H.", "M.L.", "C.D.", "T.I.", "O.P.", "N.B.", "", ""]
const PLACES := 10
const DOOR_PLACE := 9
const RACK_PLACE := 10
const BOWLS := ["b_sr", "b_at", "b_sh", "b_ml", "b_cd", "b_ti", "b_op", "b_nb", "b_sq"]
## place_k holds SOLUTION[k-1]; place_10 stays empty.
const SOLUTION := ["b_sr", "b_at", "b_sh", "b_ml", "b_cd", "b_ti", "b_op", "b_nb", "b_sq", ""]
const DOOR_NAME := "the blank place by the door"
const RACK_NAME := "the place by the rack"
const WRONG_BLANK := "Nora seated people by habit. Whose habit puts him here?"
const HOME_LINE := "Eight of them know where they go."
## The eight slide home one by one: bowl n lands (its bowl_set) at HOME_STAGGER * n s.
const HOME_STAGGER := 0.5
const BOWL_INITIALS := {"b_sr": "S.R.", "b_at": "A.T.", "b_sh": "S.H.", "b_ml": "M.L.",
	"b_cd": "C.D.", "b_ti": "T.I.", "b_op": "O.P.", "b_nb": "N.B.", "b_sq": ""}
## The rack's home slots, slot_0 .. slot_8 (deliberately not in place order).
const RACK_HOME := ["b_ti", "b_sh", "b_sq", "b_sr", "b_cd", "b_at", "b_nb", "b_op", "b_ml"]
const TALLY_MIN := 0
const TALLY_MAX := 12
const SOLUTION_TALLY := 9
const REGISTER := 8
const SET_LINE := "It's set for nine. I'll leave it set."

# --- c_ledger: Nora's provisioning book ---------------------------------------------------------
## She did not write the number: the count is every chair, plus the blank place by the door.
const PORTIONS_LINE := "Portions served: every chair, and the one by the door."
const NIGHT_WATCH := "Whoever has the night watch sits by the door, so he can leave first."
const LEDGER := [
	{
		"left": ["18 Oct 1927. Supper.", "Mutton and barley. Bread. Stewed pears.", "Signed chits: 8",
			PORTIONS_LINE, "Left over: none."],
		"margin": "Nine portions. Eight signatures. I feed the people who sit down.",
		"note": NIGHT_WATCH,
		"right": ["Mendings.", "Bowl, unsigned. Square patch, 9 Mar. He won't sign for a new one.",
			"Cup, mine, mended 3 Feb."],
	},
	{
		"left": ["Week of 10 Oct 1927. Portions.", "Mon 9   Tue 9   Wed 9   Thu 9", "Fri 9   Sat 9   Sun 9",
			"Ration correction (S.R.): issue for 8."],
		"margin": "Rook has discovered a ninth appetite. It belongs to Rook.",
		"note": "",
		"right": ["Stores.", "Tea, 2 lb. Sugar: none for me.", "Barley, 1 sack. Salt beef, 1 cask.",
			"Pears, 2 tins. Candles, 1 box."],
	},
	{"left": [], "margin": "", "note": "", "right": []},
]
## The 1931 page, written in as the bands climb (spread 2, left).
const LEDGER_1931 := ["17 Oct 1931. Supper.", "Signed chits: 1 (A.M.)", "Portions served: 2", "Left over: none."]
const LEDGER_1931_B6 := ["18 Oct 1931. Breakfast.", "Signed chits: 1 (A.M.)", "Portions served: 10"]
const LEDGER_LAST := 2

# --- P09: the shift board ------------------------------------------------------------------------
const NAME_TILES := ["BELL", "DOANE", "HART", "IVES", "LUSK", "MERCER", "PRYCE", "ROOK", "TULL", "VENN"]
const COUNT_OPTIONS := ["", "+1", "+2", "-1"]
const STATUS_OPTIONS := ["", "present", "absent", "retained"]
const SEAL_LABELS := {1: "KITCHEN · N.B.", 2: "DIRECTOR · S.R.", 3: "UNASSIGNED"}
const BOARD_HEADER := "SHIFT REGISTER · 18 OCT 1927 · S. ROOK, DIRECTOR"
const BOARD_NAMES := ["ROOK, S. — Director", "BELL, N. — Cook", "IVES, T. — Technician",
	"LUSK, M. — Draughtswoman", "PRYCE, O. — Boatman", "DOANE, C. — Recordist",
	"HART, S. — Engine-man", "TULL, A. — Lab. assistant"]
const RULE_TEXT := "Amendments must preserve the original entry and name the missing person. Stamp with the amending officer's seal."
## The placard's last line: whose correction it is (the missing person's own, so his seal).
const RULE_OWN_HAND := "The missing person may amend in his own hand."
## The rubbing pinned beside the placard (assets/stages/R05/p09_venn_rubbing.png): Venn's seal.
const RUBBING_LABEL := "E. VENN · seal, rubbed"
const RUBBING_LINE := "Pinned beside it, a rubbing of a seal. Three cuts. Pencilled under it: E. VENN."
## The work card's stamp, on the card, in her line and in the notebook (P13 reads the specimen).
const CARD_STAMP := "CALIBRATION 18 OCT 1927 · SPECIMEN 27-11"
## The specimen half of the stamp, verbatim: P13 (R07) matches it on the sample cards.
const CARD_SPECIMEN := "SPECIMEN 27-11"
## The register plate on the tally opens Rook's register (c_register).
const REGISTER_LINE := "REGISTER: 8. Rook's number."
const REGISTER_OPEN := "Under the plate, his register again, copied small for the tally. Eight names."
const DUPLICATE_LINE := "Eight retained. One witnessing."
const REJECT_TAPE := "REJECTED: UNVERIFIABLE CORRECTION. ORIGINAL ENTRY MUST STAND."
## The stamped strip under TULL on the front board after P09 (red-brown stamp ink).
const AMEND_INK := "+1  VENN  PRESENT  ///"
const ORIGINAL_STANDS := "The original stands. There's an empty amendment row under it."
const BOARD_COUNT := 8
const SOLUTION_AMEND := {"count": "+1", "name": "VENN", "status": "present"}
const SOLUTION_SEAL := 3
const STAMPED := "Stamped. It's done."
## Glance targets, in room-view coordinates: the door place (view A) and the hatch (view B).
const P07_SPOON_RECT := Rect2(1174, 500, 104, 196)
const P09_HATCH_RECT := Rect2(1316, 560, 120, 320)
const P07_DRAWER_AT := 3.0
const P07_SPOON_AT := 4.8
const P09_HATCH_LINE := "Below, bolts drew back. The service hatch is open."
const P07_SPOON_LINE := "The spoon at the door place lifted half an inch. It stayed up the length of a grace. Then it went down."
const TOKENS := {"token_pantry_half": "pantry", "token_bunk_half": "bunk"}
const HALF_ITEM := {"pantry": "token_pantry_half", "bunk": "token_bunk_half"}

# --- escalation ----------------------------------------------------------------------------------
## Arrival holds, two sides, oldest first. Seeing one retires every older one of its side.
const NOTICES_A := ["arrival", "inward", "soup", "chair", "towel"]
const NOTICES_B := ["card_breath", "fog_wiped", "warm_range"]
const NOTICE_LINES := {
	"inward": "The condensation on the bowls. It's running sideways. Toward his place.",
	"soup": "The end bowl. There's soup in it. A fresh line round the inside.",
	"chair": "His chair's pulled out. As if he's just got up. Or is about to sit down.",
	"towel": "Her towel's damp. Folded the other way.",
	"card_breath": "The work card's lifting on its nail. In her rhythm.",
	"fog_wiped": "Someone's wiped a line through the fog. From the inside.",
	"warm_range": "The range is lit.",
}
## Silent notices: on arrival only the change and its sound; Ada says the line the first time
## the player clicks the object afterwards (state.unsaid, saved).
const NOTICE_SILENT := {"chair": "chair_scrape", "towel": "towel_drip"}
const NOTICE_OBS := {
	"inward": "condensation_inward", "soup": "soup_line", "chair": "chair_out", "towel": "towel_refolded",
	"card_breath": "card_breath", "fog_wiped": "fog_wiped", "warm_range": "warm_range",
}

const SEVER_LINES := {
	"spoon": "It lies flat in its dent. It's only a spoon now.",
	"towel": "Dry. Folded in thirds, the way she folded it.",
	"range": "Cold. Ash.",
	"window": "Daylight. Ordinary rain.",
	"kettle": "Quiet. Cold.",
	"shift_board": "The fog has dried. The second board says what it said.",
	"service_hatch": "Open. No draught now.",
}
const CONTINUE_LINES := {
	"towel": "The ring where her cup stood is warm. A thread of steam off nothing.",
	"spoon": "Raised a hair off the cloth, as if someone's about to pick it up.",
	"range": "Lit. Low. Someone will want tea.",
	"window": "Morning on the glass. It isn't shore light.",
	"kettle": "Ticking. Warm, this time.",
}

const OBSERVATIONS := {
	"spoon_marks": "The mess table: eight places laid, nine spoon-shaped dents pressed into the cloth. The ninth dent, at the blank place by the door, has no spoon in it. One more place, by the rack, has no dent at all.",
	"cloth_places": "Ten places on the cloth. Eight stitched with initials: S.R., A.T., S.H., M.L., C.D., T.I., O.P., N.B. Two with none: the blank place by the door, at the kitchen end, and the place by the rack.",
	"bowl_stack": "Nine bowls in the rack at the end of the mess. Eight have initials under the rim: S.R., N.B., T.I., M.L., O.P., C.D., S.H., A.T. One has no name, only a square repair patch.",
	"unsigned_bowl": "The unsigned bowl: a square patch riveted over a crack, a spoon lying in it. The only bowl with a mark instead of a name.",
	"tally": "A brass serving tally on the end of the table, a wheel from 0 to 12. Beside it a COMPARE lever and a register plate stamped 8.",
	"towel": "Nora's towel, folded in thirds, beside a dry ring where a cup stood. The cup isn't in the kitchen.",
	"nora_ledger": "Nora Bell's provisioning book, 18 Oct 1927, supper: 'Signed chits: 8. Portions served: every chair, and the one by the door. Left over: none.' Margin: 'Nine portions. Eight signatures. I feed the people who sit down.' Under it: 'Whoever has the night watch sits by the door, so he can leave first.' Facing page, her mendings, sketched: a bowl with a square patch, 'unsigned, 9 Mar. He won't sign for a new one'; and a cup with a brass staple through the handle, 'Cup, mine, mended 3 Feb.'",
	"rook_ration": "Nora's book, week of 10 Oct 1927: nine portions every day. Rook's correction, 'issue for 8', and under it in her hand: 'Rook has discovered a ninth appetite. It belongs to Rook.'",
	"ledger_stores": "Nora's stores page: 'Tea, 2 lb. Sugar: none for me.'",
	"headcount_nine": "Nine at supper on 18 Oct 1927. Eight signed. The ninth bowl had no name; Nora mended it with a square patch. Her note: the ninth was Venn. He is not on Rook's register.",
	"drawer_rod": "The service drawer is latched from inside. A brass rod runs from its back through the wall toward the mess table.",
	"drawer_note": "In the service drawer, with the pantry half of a brass token, a note in Nora's hand: 'E.V. ate. Rook says he did not. I count bowls, not opinions. — N.B.'",
	"nora_work_card": "Nora Bell's kitchen work card, on a nail by the range, stamped CALIBRATION 18 OCT 1927 · SPECIMEN 27-11. A trace of her breathing, drawn as one pressed line.",
	"menu_objections": "Rook's typed menu, week 41: 'Nutritionally sufficient. Ration per head: 1 issue. — S.R.' Nora pencilled under it: 'Sufficient for what. Ives says the barley is like eating a map. Pryce has been at sea all day and you have given him a biscuit with an opinion. I will make soup. — N.B.'",
	"kettle_tick": "A kettle on the shelf above the range, not on it, ticking like metal cooling. Cold to the touch.",
	"shift_board": "The shift board: SHIFT REGISTER, 18 OCT 1927, S. ROOK, DIRECTOR. Eight names in his hand: Rook, Bell, Ives, Lusk, Pryce, Doane, Hart, Tull. PRESENT: 8.",
	"amendment_rule": "The shift board's placard: 'Amendments must preserve the original entry and name the missing person. Stamp with the amending officer's seal. The missing person may amend in his own hand.' Corrections append; they never overwrite. Name the missing person. Pinned beside it, a rubbing of Venn's seal: three cuts.",
	"name_tiles": "The amendment's name tiles: BELL, DOANE, HART, IVES, LUSK, MERCER, PRYCE, ROOK, TULL, VENN. The MERCER tile is newer brass than the rest.",
	"seal_selector": "The seal selector: one cut, KITCHEN, N.B.; two cuts, DIRECTOR, S.R.; three cuts, UNASSIGNED.",
	"eight_retained": "Behind the shift board, a second board in the same hand: 'Eight retained. One witnessing.'",
	"service_hatch": "A low service hatch by the dresser, bolted from both sides. Painted on it: LOWER PASSAGE · LABORATORY · MACHINE ROOM.",
	"hatch_open": "When the board was stamped, the service hatch unbolted itself. A steady draught comes up from the lower passage.",
	"condensation_inward": "The condensation on the bowls runs sideways, every bead toward the end place.",
	"soup_line": "A fresh tide line of soup inside the unsigned bowl at the blank place by the door. Barley. Nobody has cooked.",
	"chair_out": "The chair at the blank place by the door stands pulled out from the table. Nobody moved it.",
	"spoon_waits": "When I come back from looking closely at something, the spoon at the door place lifts, waits, and lowers. Once each visit.",
	"card_breath": "The work card lifts on its nail in the rhythm of its own trace. The hatch draught is steady. The card isn't.",
	"towel_refolded": "Nora's towel is damp, refolded the other way, in halves.",
	"kettle_again": "The kettle is ticking again, cooling from a heat it never had.",
	"fog_wiped": "A line has been wiped through the fog on the second board, from inside. One word shows: witnessing.",
	"ledger_1931": "A new entry in Nora's book, ink still glossy: '17 Oct 1931. Supper. Signed chits: 1 (A.M.). Portions served: 2. Left over: none.' I haven't eaten. I haven't signed anything.",
	"ledger_1931_b6": "Under it: '18 Oct 1931. Breakfast. Signed chits: 1 (A.M.). Portions served: 10.' Eight, him, and me.",
	"warm_range": "The range is lit. It is the only warm light in the station.",
	"lens_patch": "Under the lens the bowl's repair patch has four rivets, and N.B. scratched small in one corner.",
	"spoon_settled": "The spoon lies flat in its dent. It's only a spoon now.",
	"ring_warm": "The ring where her cup stood is warm. A thread of steam rises off nothing.",
}
const OBJECTIVES := {
	"p07": "Set the mess table the way Nora served supper, then COMPARE.",
	"p07_drawer": "Something unlatched in the kitchen when the table agreed.",
	"wait_p08": "The token is only half. The other half is with the staff's own things.",
	"p09_socket": "Seat both token halves in the shift board's socket and turn it.",
	"p09": "Correct the shift board: an amendment and a seal.",
	"done": "The board is amended. The hatch is open.",
}
const HINTS := {
	"p07": [
		"Nora counted meals, not employees.",
		"Two places have no initials. Nora's book says who sits by the door; the bunk room's calendar says who had the watch.",
		"Nora's margin: 'Whoever has the night watch sits by the door.' The bunk room calendar gives the 18th to Venn. His bowl is the unsigned one with the square patch.",
		"The eight named bowls set themselves. Put the unsigned patched bowl at the blank place by the door: the night watch sat there, and Venn had the 18th. Tally 9, COMPARE.",
	],
	"p07_drawer": [
		"Something let go in the kitchen when the table agreed.",
		"A brass rod runs from the service drawer back toward the mess table.",
		"Turn to the kitchen and open the service drawer under the shift board.",
	],
	"wait_p08": [
		"The token in the drawer is only half.",
		"The other half belongs to the bunk side of the service.",
		"The bunk room: put each belonging in its owner's locker.",
	],
	"p09_socket": [
		"Both halves are in hand. The socket on the shift board is cut for them.",
		"Pantry half on the left, bunk half on the right. Then the socket turns.",
		"Use each half on the shift board, then turn the socket. The stamp comes free.",
	],
	"p09": [
		"The stamp is free. The board wants a correction, not a new count.",
		"The rule says keep the original and add the missing person. Nora's book and Venn's seal say who.",
		"Nora served nine; eight signed. Her drawer note: 'E.V. ate.' The placard lets the missing person amend in his own hand, and the rubbing beside it is Venn's seal: three cuts.",
		"Leave 8 alone. Add +1 / VENN / present. Seal selector to three cuts, then stamp.",
	],
	"done": [
		"Nothing in the kitchen is waiting on me.",
		"The service hatch is open to the lower passage.",
		"Through the hatch: the laboratory and the machine room.",
	],
}
## Items this room hands out (docs/design/puzzle-cards/flags.md section 4).
const ITEMS := {
	"token_pantry_half": {"name": "Service token, pantry half",
		"desc": "Half of a split brass service token, cut PANTRY.", "short": "Pantry half"},
}

const SAVED_BOOLS := ["p07_complete", "drawer_open", "socket_turned", "p09_complete", "tiles_seen",
	"count_changed", "homed"]

## Transient, never saved: what the view shows in hand and highlights after the last action.
var held := ""                                        # a BOWLS id lifted off the rack or a place
var last_compare := {"places": "", "portions": ""}    # "" | "agree" | "disagree"
var tape := ""                                        # "" | REJECT_TAPE
var ledger_spread := 0
var _spoon_this_visit := false
var _sq_lift_said := false
var _mercer_said := false
var _register_said := false

func initial_state() -> Dictionary:
	return {
		"places": ["", "", "", "", "", "", "", "", "", ""], "tally": 0, "p07_complete": false, "homed": false,
		"drawer_open": false, "fitted": {"pantry": false, "bunk": false}, "socket_turned": false,
		"board_count": BOARD_COUNT, "amend": {"count": "", "name": "", "status": ""}, "seal": 1,
		"p09_complete": false, "notices": [], "misses": 0, "stamp_misses": 0, "tiles_seen": false,
		"count_changed": false, "unsaid": [],
	}

func is_closeup(v := local_view) -> bool:
	return v in CLOSEUPS

func objective() -> String:
	_sync()
	if not state.p07_complete:
		return "p07"
	if not state.drawer_open:
		return "p07_drawer"
	if state.p09_complete:
		return "done"
	if not game.flag("P08"):
		return "wait_p08"
	# P08 puts both halves in hand: the ladder moves straight to seating them, then to the
	# correction itself. It never again asks for the halves.
	if not state.socket_turned:
		return "p09_socket"
	return "p09"

## How many rungs the current objective's Hint ladder has: P07 and P09 carry an evidence tier
## (nudge, relationship, evidence, solution); the rest keep three.
func hint_tiers() -> int:
	return c("HINTS", {}).get(objective(), []).size()

func notebook_intrusion() -> String:
	if band() >= 6 and ending() == "":
		return "Portions served: 10. Signed: 1."
	return ""

# ---------------------------------------------------------------------------------------------
# view helpers (read-only)
# ---------------------------------------------------------------------------------------------
func band() -> int:
	return game.weather_band()

func ending() -> String:
	return str(game.value("ending_choice"))

## Spread `i` of Nora's book as the view draws it: {left, margin, right}. The 1931 page fills
## in as the bands climb.
func ledger_page(i: int) -> Dictionary:
	i = clampi(i, 0, LEDGER_LAST)
	var p: Dictionary = LEDGER[i].duplicate(true)
	if i == 2:
		var left := []
		if band() >= 3:
			left.append_array(LEDGER_1931)
		if band() >= 6:
			left.append_array(LEDGER_1931_B6)
		p.left = left
	return p

## The rack, slot by slot: the bowl id sitting in its home slot, or "".
func rack_contents() -> Array:
	var out := []
	for b in RACK_HOME:
		out.append(b if _in_rack(b) else "")
	return out

## The bowl on place k (1..10), or "".
func place_bowl(k: int) -> String:
	if k < 1 or k > PLACES:
		return ""
	return state.places[k - 1]

func spoon_in_dent() -> bool:
	return state.p07_complete

func spoon_raised_still() -> bool:
	return ending() == "continue"

func chair_out() -> bool:
	return band() >= 4 and ending() != "sever"

func soup_shown() -> bool:
	return state.p07_complete and band() >= 3 and ending() != "sever"

func condensation_shown() -> bool:
	return state.p07_complete and band() >= 2 and ending() == ""

func towel_pose() -> String:
	return "halves" if band() >= 6 and ending() != "sever" else "thirds"

func ring_pose() -> String:
	return "warm" if ending() == "continue" else "dry"

func board_swung() -> bool:
	return state.p09_complete

## The second board's fog: "none" (still hidden), "full", "wiped" (band 6+) or "dry" (sever).
func fog_pose() -> String:
	if not state.p09_complete:
		return "none"
	if ending() == "sever":
		return "dry"
	if band() >= 6:
		return "wiped"
	return "full"

func hatch_open() -> bool:
	return state.p09_complete

func drawer_open() -> bool:
	return state.drawer_open

func card_breathing() -> bool:
	return band() >= 5 and ending() == ""

## Lit at band 7 and in the continue ending; after the sever it is "Cold. Ash."
func range_lit() -> bool:
	return (band() == 7 and ending() != "sever") or ending() == "continue"

func kettle_ticking() -> bool:
	return ending() == "" and (band() <= 1 or band() >= 6)

func rain_audible() -> bool:
	return ending() == "sever" or (ending() == "" and band() <= 4)

## The painted plate set: "b0", "b2", "b4", "b6", "b7" or "sever" (continue shows b7).
func plate_stage() -> String:
	match ending():
		"sever":
			return "sever"
		"continue":
			return "b7"
	var b := band()
	if b <= 1:
		return "b0"
	if b <= 3:
		return "b2"
	if b <= 5:
		return "b4"
	return "b6" if b == 6 else "b7"

## The mess-side arrival hold due now (a NOTICES_A id), or "".
func current_notice_a() -> String:
	if ending() != "":
		return ""
	var b := band()
	if b >= 6:
		return "towel"
	if b >= 4:
		return "chair"
	if b == 3:
		return "soup"
	if b == 2 and state.p07_complete:
		return "inward"
	return ""

## The kitchen-side arrival hold due now (a NOTICES_B id), or "".
func current_notice_b() -> String:
	if ending() != "":
		return ""
	var b := band()
	if b == 7:
		return "warm_range"
	if b == 6 and state.p09_complete:
		return "fog_wiped"
	if b == 5:
		return "card_breath"
	return ""

# ---------------------------------------------------------------------------------------------
# entry points
# ---------------------------------------------------------------------------------------------
func arrive(ev: Array, _first: bool) -> void:
	_sync()
	_clear_transients()
	local_view = "room"
	match ending():
		"sever":
			if not has_seen("spoon_settled"):
				_say(ev, "Quiet. Just a kitchen.")
				_observe("spoon_settled")
			return
		"continue":
			if not has_seen("ring_warm"):
				_say(ev, "The ring where her cup stood is warm.")
				_observe("ring_warm")
			return
	if not "arrival" in state.notices:
		_say(ev, ARRIVAL)
		_sfx(ev, "kettle_tick", 1.8)
		_say(ev, "Somewhere in the kitchen a kettle is ticking. Cooling.", 2.6, true)
		_observe("spoon_marks")
		_mark_notice("arrival")
		return
	_try_notice(current_notice_a(), ev)

func back(ev: Array) -> void:
	_sync()
	var before := local_view
	match local_view:
		"c_table":
			_return_held(ev)
			local_view = "room"
		"c_ledger", "c_service_board", "c_work_card":
			local_view = "kitchen"
		"c_register":
			local_view = "c_table"
		_:
			local_view = "room"
	# the spoon waits for her to come back to the room, not from one close-up into another
	if is_closeup(before) and not is_closeup() and band() >= 5 and ending() == "" and not _spoon_this_visit:
		_spoon_this_visit = true
		_fx(ev, "spoon_lift")
		_sfx(ev, "spoon_china", 2.6)
		_say(ev, "Behind me, china. The spoon.", 2.8)
		_observe("spoon_waits")

func act(action: String, ev: Array) -> void:
	_sync()
	match local_view:
		"c_table":
			if action in TABLE_CONTROLS:
				_table(action, ev)
				return
		"c_ledger":
			if action in LEDGER_CONTROLS:
				_ledger(action, ev)
				return
		"c_service_board":
			if action in BOARD_CONTROLS or (state.p09_complete and action in BOARD_CONTROLS_AFTER):
				_service_board(action, ev)
				return
	if action in HOTSPOTS:
		_leave_table(ev)
		local_view = "room"
		_room(action, ev)
	elif action in KITCHEN_HOTSPOTS:
		_leave_table(ev)
		local_view = "kitchen"
		_kitchen(action, ev)

func use_item(item: String, target: String, ev: Array) -> bool:
	_sync()
	var on_board: bool = target in ["shift_board", "socket_pantry", "socket_bunk"] \
		or (local_view == "c_service_board" and (target in BOARD_CONTROLS or target in BOARD_CONTROLS_AFTER))
	var on_ledger: bool = target == "ledger" or (local_view == "c_ledger" and target in LEDGER_CONTROLS)
	if TOKENS.has(item):
		if on_board and not state.p09_complete:
			_fit_token(item, ev)
		else:
			_say(ev, "It's half a service token. The shift board has a socket for it.")
		return true
	match item:
		"inspection_lens":
			if target == "place_10":
				_say(ev, "Plain linen. No dent, no thread pulled. Nobody ever sat here.")
				return true
			if target in ["unsigned_bowl", "place_9"] or (local_view == "c_table" and target in TABLE_CONTROLS):
				_say(ev, "Four rivets. And N.B. scratched small in one corner of the patch.")
				_observe("lens_patch")
				return true
			if target == "work_card":
				_say(ev, "It isn't ink. It's a pressure line, pressed into the card.")
				return true
			if on_ledger:
				var line := "Her hand. One soft pencil all through."
				if band() >= 3:
					line += " The 1931 page too."
				_say(ev, line)
				return true
			if on_board and state.p09_complete:
				_say(ev, "The fog's on the inside. There's no glass to be inside of.")
				return true
		"pencil":
			if on_board:
				_say(ev, "The amendment takes tiles, not pencil.")
				return true
			if on_ledger:
				_say(ev, "Not in her book.")
				return true
		"nora_register_card":
			if on_ledger:
				_say(ev, "'No surviving personal effects.' Her book says otherwise: 'Cup, mine, mended 3 Feb.'")
				return true
	return false

# ---------------------------------------------------------------------------------------------
# view A: the mess table
# ---------------------------------------------------------------------------------------------
func _room(action: String, ev: Array) -> void:
	var b := band()
	var e := ending()
	if e == "sever" and SEVER_LINES.has(action):
		_say(ev, SEVER_LINES[action])
		if action == "towel":
			_observe("towel")
		return
	if e == "continue" and CONTINUE_LINES.has(action):
		_say(ev, CONTINUE_LINES[action])
		if action == "towel":
			_observe("towel")
		return
	if action.begins_with("place_"):
		local_view = "c_table"
		var first := not has_seen("cloth_places")
		_observe("cloth_places")
		_observe("spoon_marks")
		if first:
			_say(ev, "Eight places with initials. Two blank: one by the door, one by the rack.")
		elif state.p07_complete:
			_say(ev, "Set for nine. Someone has eaten by the door." if b >= 3 else "Set for nine.")
		else:
			_say(ev, "The table.")
		_home_bowls(ev)
		return
	match action:
		"spoon":
			if b >= 5:
				_say(ev, "It's down. It's waiting for me to look away.")
			elif state.p07_complete:
				_say(ev, "His spoon, in its dent. It lifted by itself, then put itself back.")
			else:
				_say(ev, "A dent in the cloth at the end place, spoon-shaped. No spoon in it.")
		"unsigned_bowl":
			local_view = "c_table"
			var first := not has_seen("unsigned_bowl")
			_observe("unsigned_bowl")
			if state.p07_complete:
				_say(ev, "Its ring on the rack is clean. It's at the blank place by the door.")
			elif first:
				_say(ev, "No name on this one. A square patch, riveted. A spoon lying in it.")
			else:
				_say(ev, "The patched one.")
			_home_bowls(ev)
		"tally":
			local_view = "c_table"
			if not has_seen("tally"):
				_observe("tally")
				_say(ev, "A serving tally, 0 to 12. A COMPARE lever. The register plate says 8.")
			else:
				_say(ev, "The tally.")
			_home_bowls(ev)
		"bowl_stack":
			local_view = "c_table"
			var first := not has_seen("bowl_stack")
			_observe("bowl_stack")
			if state.p07_complete:
				_say(ev, "The rack's empty. Every bowl's at the table.")
			elif first:
				_say(ev, "Nine bowls. Eight with initials under the rim.")
			else:
				_say(ev, "The bowls.")
			_home_bowls(ev)
		"chair":
			if _say_unsaid("chair", ev):
				pass
			elif chair_out():
				_say(ev, "Pulled out from his place. Nobody moved it.")
				_observe("chair_out")
			elif b >= 2:
				_say(ev, "His chair, tucked in at the door end. The seat's wet.")
			else:
				_say(ev, "The chair at the door end. Tucked in.")
		"towel":
			_observe("towel")
			if _say_unsaid("towel", ev):
				pass
			elif b >= 6:
				_say(ev, "Damp. Refolded the other way, in halves. Someone has dried their hands.")
				_observe("towel_refolded")
			else:
				var line := "Nora's towel, folded in thirds, beside a ring where a cup stood. The cup isn't here."
				if game.flag("P08"):
					line += " Her cup's in the bunk room, in her locker."
				_say(ev, line)
		"window":
			if b <= 1:
				_say(ev, "A high window. Rain on it. On the inside of the glass.")
			elif b == 2:
				_say(ev, "Heavier rain. The glass is running.")
			elif b == 3:
				_say(ev, "The rain runs down the glass slower than rain runs.")
			elif b == 4:
				_say(ev, "Rain on the glass. The horizon's pressed flat, too close.")
			elif b <= 6:
				_say(ev, "Rain on the glass, and no sound of it.")
			else:
				_say(ev, "Dark, right up against the pane. Not night. Something close.")
		"to_kitchen":
			local_view = "kitchen"
			_say(ev, "The kitchen.")
			_try_notice(current_notice_b(), ev)

# ---------------------------------------------------------------------------------------------
# view B: the kitchen
# ---------------------------------------------------------------------------------------------
func _kitchen(action: String, ev: Array) -> void:
	var b := band()
	var e := ending()
	var override := ""
	if e == "sever":
		override = SEVER_LINES.get(action, "")
	elif e == "continue":
		override = CONTINUE_LINES.get(action, "")
	if override != "" and not action in ["shift_board", "work_card"]:
		_say(ev, override)
		return
	match action:
		"work_card":
			local_view = "c_work_card"
			_observe("nora_work_card")
			if override != "":
				_say(ev, override)
				return
			_say(ev, "A work card, stamped %s. A trace of her breathing." % CARD_STAMP)
			if b >= 5 and e == "":
				_say(ev, "It's lifting on its nail in that rhythm. The draught is steady. The card isn't.", 2.0)
				_observe("card_breath")
		"menu_note":
			if not has_seen("menu_objections"):
				game.set_flag("o02_found")
				_observe("menu_objections")
				_say(ev, "Rook's menu. 'Nutritionally sufficient.' Nora's reply is longer than the menu.")
				_say(ev, "'You have given him a biscuit with an opinion.'", 2.4)
			else:
				_say(ev, "Rook's menu, and Nora's longer reply.")
		"kettle":
			if b <= 1:
				_say(ev, "A kettle on the shelf, nowhere near the range. Ticking, the way metal does as it cools. It's stone cold.")
				_observe("kettle_tick")
			elif b <= 5:
				_say(ev, "It's stopped ticking. Still cold.")
			else:
				_say(ev, "Ticking again. Cooling from a heat it never had.")
				_observe("kettle_again")
		"range":
			if b <= 1:
				_say(ev, "Cold. Swept out and blacked before they left.")
			elif b <= 6:
				_say(ev, "Cold. The hatch draught stirs the ash in the firebox.")
			else:
				_say(ev, "Lit. I didn't light it. It's the only warm light in the station.")
				_observe("warm_range")
		"ledger":
			_open_ledger(ev)
		"service_drawer":
			_drawer(ev)
		"service_hatch":
			if not state.p09_complete:
				_observe("service_hatch")
				_say(ev, "Bolted, both sides. LOWER PASSAGE. LABORATORY. MACHINE ROOM.")
			elif b >= 5:
				_say(ev, "The draught isn't steady any more. It comes and goes like the card.")
			else:
				_say(ev, "Open. The draught comes up out of it, steady as breath.")
		"shift_board":
			_open_board(ev, override)
		"to_mess":
			local_view = "room"
			_say(ev, "The mess table.")
			_try_notice(current_notice_a(), ev)

func _drawer(ev: Array) -> void:
	if not state.p07_complete:
		_say(ev, "Latched from inside. A brass rod runs out of the back of it, through the wall, toward the mess table.")
		_observe("drawer_rod")
		return
	if state.drawer_open:
		_say(ev, "Her note, and the bed the token lay in.")
		return
	state.drawer_open = true
	_sfx(ev, "drawer_slide")
	_fx(ev, "drawer_open")
	game.give("token_pantry_half", ev)
	_observe("drawer_note")
	_say(ev, "Half a brass token. And a note in her hand.", 0.6, true)
	_say(ev, "'E.V. ate. Rook says he did not. I count bowls, not opinions. — N.B.'", 2.2, true)

func _open_board(ev: Array, override: String) -> void:
	local_view = "c_service_board"
	var first := not has_seen("shift_board")
	_observe("shift_board")
	_observe("amendment_rule")
	if override != "":
		_say(ev, override)
	elif state.p09_complete:
		if band() >= 6:
			_fx(ev, "board_open")
			_say(ev, "A line wiped through the fog from inside. One word: witnessing.")
			_observe("fog_wiped")
		else:
			_say(ev, "Fogged from inside the wall. My copy's in the notebook.")
	elif first:
		_say(ev, "Rook's eight. And a placard about corrections.")
	else:
		_say(ev, "The shift board.")

# ---------------------------------------------------------------------------------------------
# P07: c_table
# ---------------------------------------------------------------------------------------------
func _in_rack(b: String) -> bool:
	return b != held and not b in state.places

func _return_held(ev: Array) -> void:
	if held != "":
		held = ""
		_sfx(ev, "bowl_rack")

## Leaving c_table for another hotspot puts a held bowl back in the rack first.
func _leave_table(ev: Array) -> void:
	if local_view == "c_table":
		_return_held(ev)

func _table(action: String, ev: Array) -> void:
	if action == "compare":
		_compare(ev)
		return
	if action == "look_register":
		_return_held(ev)
		local_view = "c_register"
		_say(ev, REGISTER_LINE)
		if not _register_said:
			_register_said = true
			_say(ev, REGISTER_OPEN, 1.6)
		return
	if action.begins_with("place_"):
		var k := int(action.substr(6))
		if state.p07_complete:
			if k == DOOR_PLACE:
				if band() >= 3 and ending() != "sever":
					_say(ev, "A fresh tide line of soup round the inside of his bowl. Barley. Nobody has cooked.")
					_observe("soup_line")
				else:
					_say(ev, "The blank place by the door. His bowl.")
			elif k == RACK_PLACE:
				_say(ev, "The place by the rack. Nobody sat there.")
			else:
				_say(ev, "%s's place. %s's bowl." % [PLACE_MARKS[k - 1], PLACE_MARKS[k - 1]])
			return
		_place(k, ev)
		return
	if state.p07_complete:
		_say(ev, SET_LINE)
		return
	if action.begins_with("slot_"):
		_slot(int(action.substr(5)), ev)
	elif action == "tally_down" or action == "tally_up":
		# A numbered wheel: it turns round, 12 on to 0 and 0 back to 12.
		var d := -1 if action == "tally_down" else 1
		state.tally = tally_step(int(state.tally), d)
		last_compare = {"places": "", "portions": ""}
		_sfx(ev, "tally_click")

func _slot(k: int, ev: Array) -> void:
	if held != "":
		held = ""
		_sfx(ev, "bowl_rack")
		return
	var b: String = RACK_HOME[k]
	if not _in_rack(b):
		_say(ev, "That one's at the table.")
		return
	held = b
	_sfx(ev, "bowl_lift")
	if b == "b_sq" and not _sq_lift_said:
		_sq_lift_said = true
		_say(ev, "The patched one. No name, only the patch.")

func _place(k: int, ev: Array) -> void:
	var i := k - 1
	var there: String = state.places[i]
	last_compare = {"places": "", "portions": ""}
	# Once they have set themselves, the eight named bowls stay on their own initials.
	if state.homed and there != "" and there == SOLUTION[i] and k <= 8:
		if held != "":
			_say(ev, "%s's bowl is on it. It knows where it goes." % PLACE_MARKS[i])
		else:
			_say(ev, "%s's place. %s's bowl." % [PLACE_MARKS[i], PLACE_MARKS[i]])
		return
	if held != "":
		state.places[i] = held
		held = there
		_sfx(ev, "bowl_set")
		if there != "":
			_sfx(ev, "bowl_lift", 0.15)
		return
	if there != "":
		held = there
		state.places[i] = ""
		_sfx(ev, "bowl_lift")
		return
	if k == DOOR_PLACE:
		_say(ev, "The blank place by the door. Empty, apart from the dent.")
	elif k == RACK_PLACE:
		_say(ev, "The place by the rack. Empty. No dent.")
	else:
		_say(ev, "%s's place. Empty." % PLACE_MARKS[i])

static func _mark_name(i: int) -> String:
	if i == DOOR_PLACE - 1:
		return "The blank place by the door"
	if i == RACK_PLACE - 1:
		return "The place by the rack"
	return "%s's place" % PLACE_MARKS[i]

## The tally wheel `n` turned one notch (`d` = +1 or -1), wrapping within TALLY_MIN..TALLY_MAX.
static func tally_step(n: int, d: int) -> int:
	var span := TALLY_MAX - TALLY_MIN + 1
	return TALLY_MIN + posmod(clampi(n, TALLY_MIN, TALLY_MAX) - TALLY_MIN + d, span)

static func _blank_name(i: int) -> String:
	return DOOR_NAME if i == DOOR_PLACE - 1 else RACK_NAME

## First open of c_table: every initialled bowl not on its own place drops onto it by itself (one
## state change). A patched bowl in the way goes back to the rack; place_9/place_10 keep theirs.
func _home_bowls(ev: Array) -> void:
	if state.homed or state.p07_complete or local_view != "c_table":
		return
	state.homed = true
	var moved := []
	for i in 8:
		var want: String = SOLUTION[i]
		if state.places[i] == want:
			continue
		var j: int = state.places.find(want)
		if j >= 0:
			state.places[j] = ""
		state.places[i] = want
		moved.append(want)
	if held != "" and held in moved:
		held = ""
	if moved.is_empty():
		return
	for n in moved.size():
		_sfx(ev, "bowl_set", HOME_STAGGER * n)
	ev.append({"type": "fx", "id": "bowls_home", "bowls": moved.duplicate()})
	_say(ev, HOME_LINE, HOME_STAGGER * moved.size(), true)

## The first disagreement between the table and Nora's supper, in Ada's words, or "".
static func places_line(places: Array) -> String:
	# The deduction first: the patched bowl on the wrong blank.
	if places[RACK_PLACE - 1] == "b_sq":
		return WRONG_BLANK
	for i in 8:
		var b: String = places[i]
		if b == SOLUTION[i]:
			continue
		if b == "":
			return "%s is empty." % _mark_name(i)
		if b == "b_sq":
			return "The unsigned bowl is at %s's place." % PLACE_MARKS[i]
		# An initialled bowl on another place: name the bowl that belongs here, and where it went,
		# so a swapped pair reads the way round the card prints it.
		var want: String = SOLUTION[i]
		var j := places.find(want)
		if j >= 8:
			return "%s's bowl is on %s." % [BOWL_INITIALS[want], _blank_name(j)]
		if j >= 0:
			return "%s's bowl is at %s's place." % [BOWL_INITIALS[want], PLACE_MARKS[j]]
		return "%s's bowl is at %s's place." % [BOWL_INITIALS[b], PLACE_MARKS[i]]
	for i in [DOOR_PLACE - 1, RACK_PLACE - 1]:
		var b: String = places[i]
		if b != "" and b != "b_sq":
			return "%s's bowl is on %s." % [BOWL_INITIALS[b], _blank_name(i)]
	if places[DOOR_PLACE - 1] == "":
		return "The unsigned bowl isn't at the table."
	return ""

func portions_line() -> String:
	var read := has_seen("nora_ledger")
	if int(state.tally) == REGISTER:
		if read:
			return "That's the register's number. Nora's book says nine."
		return "Eight is the register's number. The tally wants what was served, and I haven't read what she served."
	if read:
		return "Nora served nine."
	return "Portions disagree with what she served. Her book would know."

func _compare(ev: Array) -> void:
	_sfx(ev, "compare_pull", 0.0)
	if state.p07_complete:
		_say(ev, "Nine. It still says nine.")
		return
	_sfx(ev, "flag_flip", 0.3)
	var places_ok: bool = state.places == SOLUTION
	var portions_ok: bool = int(state.tally) == SOLUTION_TALLY
	last_compare = {"places": "agree" if places_ok else "disagree",
		"portions": "agree" if portions_ok else "disagree"}
	_fx(ev, "p07_compare")
	if not places_ok or not portions_ok:
		state.misses = int(state.misses) + 1
		if not places_ok and not portions_ok:
			_say(ev, places_line(state.places), 0.4)
			_say(ev, portions_line(), 2.2)
		elif not places_ok:
			_say(ev, places_line(state.places), 0.4)
		else:
			_say(ev, portions_line(), 0.4)
		return
	state.p07_complete = true
	state.homed = true
	game.solve("P07", ev)
	_observe("headcount_nine")
	_fx(ev, "p07_agree")
	_say(ev, "Nine. The register says eight. Nora's book says nine.", 0.8, true)
	_sfx(ev, "drawer_unlatch", 2.4)
	_say(ev, "Something unlatched. In the kitchen.", P07_DRAWER_AT, true)
	# The reward is seen: the view glances at the door place and lifts the spoon there when the
	# last line shows (the silent cue rides with it when the chain is clicked on).
	glance(ev, "p07_spoon", P07_SPOON_RECT, P07_SPOON_AT)
	_say(ev, P07_SPOON_LINE, P07_SPOON_AT, true)

# ---------------------------------------------------------------------------------------------
# c_ledger
# ---------------------------------------------------------------------------------------------
func _open_ledger(ev: Array) -> void:
	local_view = "c_ledger"
	_sfx(ev, "book_open")
	var b := band()
	if b >= 3 and not has_seen("ledger_1931"):
		ledger_spread = 2
		_observe("ledger_1931")
		_say(ev, "A new page. That's tonight. 'Signed: A.M.' I haven't signed anything. I haven't eaten.", 0.6, true)
	elif b >= 6 and not has_seen("ledger_1931_b6"):
		ledger_spread = 2
		_observe("ledger_1931_b6")
		_say(ev, "Breakfast. Tomorrow. Ten. Eight, him, and me.", 0.0, true)
	else:
		ledger_spread = 0
		if not has_seen("nora_ledger"):
			_observe("nora_ledger")
			_say(ev, "Nora's provisioning book. Open at the eighteenth of October, 1927.")
		else:
			_say(ev, "Nora's book.")

func _ledger(action: String, ev: Array) -> void:
	match action:
		"page_prev", "page_next":
			var to := clampi(ledger_spread + (-1 if action == "page_prev" else 1), 0, LEDGER_LAST)
			if to == ledger_spread:
				return
			ledger_spread = to
			_sfx(ev, "page_turn")
			if to == 1 and not has_seen("rook_ration"):
				_observe("rook_ration")
				_observe("ledger_stores")
				_say(ev, "'It belongs to Rook.' Somebody had to laugh at him.")
			elif to == 2 and band() < 3:
				_say(ev, "Blank. Ruled for days nobody's written yet.")
		"left_page", "right_page":
			var p := ledger_page(ledger_spread)
			var lines: Array = p.left if action == "left_page" else p.right
			if lines.is_empty():
				_say(ev, "Blank. Ruled for days nobody's written yet.")
				return
			_say(ev, " ".join(lines))
			if action == "left_page" and p.margin != "":
				_say(ev, "In the margin: '%s'" % p.margin, 2.0)
			if action == "left_page" and str(p.get("note", "")) != "":
				_say(ev, "Under it: '%s'" % p.note, 4.4)

# ---------------------------------------------------------------------------------------------
# P09: c_service_board
# ---------------------------------------------------------------------------------------------
func _service_board(action: String, ev: Array) -> void:
	if state.p09_complete:
		if action == "look_duplicate":
			_fx(ev, "board_toggle")
			_say(ev, "Rook's board swings on its hinges. Behind it, the other one. I have the copy.")
		else:
			_say(ev, STAMPED)
		return
	if action.begins_with("tile_"):
		var k := int(action.substr(5))
		state.amend.name = NAME_TILES[k]
		_sfx(ev, "tile_seat")
		if not state.tiles_seen:
			state.tiles_seen = true
			_observe("name_tiles")
		if NAME_TILES[k] == "MERCER" and not _mercer_said:
			_mercer_said = true
			_say(ev, "MERCER. The brass on this one is newer than the rest.")
		return
	match action:
		"f_name":
			if state.amend.name == "":
				_say(ev, "The name field. It takes a tile.")
			else:
				var lifted: String = state.amend.name
				state.amend.name = ""
				_sfx(ev, "tile_lift")
				_say(ev, "I take %s back off the board." % lifted)
		"f_count":
			state.amend.count = _cycle(COUNT_OPTIONS, state.amend.count)
			_sfx(ev, "tile_flip")
		"f_status":
			state.amend.status = _cycle(STATUS_OPTIONS, state.amend.status)
			_sfx(ev, "tile_flip")
		"count_down", "count_up":
			var to := clampi(int(state.board_count) + (-1 if action == "count_down" else 1), 0, 12)
			_sfx(ev, "tile_flip")
			if to != int(state.board_count):
				state.board_count = to
				tape = ""
				if not state.count_changed:
					state.count_changed = true
					_say(ev, "It turns. Rook's eight could be anything.")
		"look_count":
			var n := int(state.board_count)
			if n == BOARD_COUNT:
				_say(ev, "PRESENT: 8. In his hand.")
			else:
				_say(ev, "PRESENT: %d. That's not his number." % n)
		"socket_pantry", "socket_bunk":
			var half := "pantry" if action == "socket_pantry" else "bunk"
			if not state.fitted[half]:
				_say(ev, "The pantry half of the socket. Empty." if half == "pantry" else "The bunk half of the socket. Empty.")
			elif state.socket_turned:
				_say(ev, "Locked in while the socket's turned.")
			else:
				state.fitted[half] = false
				game.give(HALF_ITEM[half], ev)
				_sfx(ev, "token_pull")
				_say(ev, "Out it comes.")
		"socket_turn":
			if state.socket_turned:
				state.socket_turned = false
				_sfx(ev, "socket_turn")
				_say(ev, "Back. The halves come loose.")
			elif state.fitted.pantry and state.fitted.bunk:
				state.socket_turned = true
				_sfx(ev, "socket_turn")
				_say(ev, "It turns. Under the board, something lets go of the stamp.")
			elif state.fitted.pantry or state.fitted.bunk:
				_sfx(ev, "socket_jam")
				_say(ev, "The socket will not turn. It wants both halves.")
			else:
				_say(ev, "Nothing in it to turn.")
		"seal_1", "seal_2", "seal_3":
			state.seal = int(action.substr(5))
			_sfx(ev, "seal_click")
			_observe("seal_selector")
		"look_rule":
			_say(ev, RULE_TEXT + " " + RULE_OWN_HAND)
			_observe("amendment_rule")
		"look_rubbing":
			_say(ev, RUBBING_LINE)
			_observe("amendment_rule")
		"stamp":
			_stamp(ev)

static func _cycle(options: Array, cur: String) -> String:
	return options[(options.find(cur) + 1) % options.size()]

func _fit_token(item: String, ev: Array) -> void:
	var half: String = TOKENS[item]
	local_view = "c_service_board"
	_observe("shift_board")
	_observe("amendment_rule")
	game.take(item)
	state.fitted[half] = true
	_sfx(ev, "token_seat")
	_say(ev, "The pantry half drops into the left of the socket." if half == "pantry" else "The bunk half drops into the right.")

## The refusal for the composed amendment and seal, or "" when they are right.
func amendment_refusal() -> String:
	var a: Dictionary = state.amend
	if a.count == "" and a.name == "" and a.status == "":
		return "The amendment isn't finished. It wants a count, a name and a status."
	if a.count == "":
		return "It wants a count."
	if a.name == "":
		return "It wants a name."
	if a.status == "":
		return "It wants a status."
	if a.count == "+2":
		return "Nora served nine. Eight signed. That's one more, not two."
	if a.count == "-1":
		return "Taking one off is overwriting with extra steps."
	if a.name == "MERCER":
		return "I wasn't at that supper. The amendment has to name the person. Nora's note names him."
	if a.name != "VENN":
		return "The amendment has to name the person. Nora's note names him."
	if a.status == "absent":
		return "He ate. Nora counted his bowl. He was present."
	if a.status == "retained":
		return "'Retained' is a word for a sample, not a man at supper."
	if int(state.seal) != SOLUTION_SEAL:
		return "One cut is Bell's kitchen stamp. Two is the director's. Venn's has three."
	return ""

func _stamp(ev: Array) -> void:
	tape = ""
	if not (game.flag("P07") and game.flag("P08")):
		_say(ev, "I can't correct a count I haven't made.")
		return
	if not state.socket_turned:
		_sfx(ev, "stamp_locked")
		_say(ev, "The stamp won't come down. The token socket's holding it.")
		return
	if int(state.board_count) != BOARD_COUNT:
		_sfx(ev, "stamp_thud")
		_sfx(ev, "reject_tape", 0.3)
		tape = REJECT_TAPE
		_fx(ev, "reject")
		_say(ev, REJECT_TAPE, 0.3)
		state.board_count = BOARD_COUNT
		_sfx(ev, "count_reset", 1.0)
		_fx(ev, "count_reset")
		_say(ev, "The eight's put itself back.", 1.8)
		_say(ev, ORIGINAL_STANDS, 3.6)
		return
	var refusal := amendment_refusal()
	if refusal != "":
		_sfx(ev, "stamp_thud")
		state.stamp_misses = int(state.stamp_misses) + 1
		_say(ev, refusal)
		return
	state.p09_complete = true
	game.solve("P09", ev)
	_observe("eight_retained")
	_sfx(ev, "stamp_thud", 0.0)
	_fx(ev, "p09_reveal")
	_say(ev, "Stamped. Plus one. Venn. Present.", 0.6, true)
	_sfx(ev, "board_hinge", 2.6)
	_say(ev, "The board's on hinges. There's another one behind it. Same hand.", 3.4, true)
	_sfx(ev, "pencil_copy", 5.4)
	_say(ev, "'Eight retained. One witnessing.' I'm copying it down.", 5.6, true)
	_sfx(ev, "fog_creep", 8.0)
	_say(ev, "It's fogging. From inside the wall. Line by line.", 8.8, true)
	_sfx(ev, "hatch_unlatch", 12.4)
	_say(ev, P09_HATCH_LINE, 13.0, true)
	glance(ev, "p09_hatch", P09_HATCH_RECT, 13.0)
	_observe("hatch_open")

# ---------------------------------------------------------------------------------------------
# notices
# ---------------------------------------------------------------------------------------------
func _side(n: String) -> Array:
	return NOTICES_A if n in NOTICES_A else NOTICES_B

## Marks `n` and every older notice of its side as seen, so an obsolete one never plays later.
func _mark_notice(n: String) -> void:
	var side := _side(n)
	var k := side.find(n)
	for i in k + 1:
		if not side[i] in state.notices:
			state.notices.append(side[i])

func _try_notice(n: String, ev: Array) -> void:
	if n == "" or n in state.notices:
		return
	_mark_notice(n)
	_fx(ev, "notice_" + n)
	if NOTICE_SILENT.has(n):
		_sfx(ev, NOTICE_SILENT[n], 0.6)
		if not n in state.unsaid:
			state.unsaid.append(n)
		return
	_say(ev, NOTICE_LINES[n], 1.6)
	_observe(NOTICE_OBS[n])

## A silent notice's line, said on the first click on its object afterwards. True if said.
func _say_unsaid(n: String, ev: Array) -> bool:
	if not n in state.unsaid:
		return false
	state.unsaid.erase(n)
	_say(ev, NOTICE_LINES[n])
	_observe(NOTICE_OBS[n])
	return true

## A glance: the view looks at `rect` (room-view coordinates) for the reward `gid`. The fx
## carries the rect; the silent cue `cue_<gid>` lands with the chain line it belongs to.
func glance(ev: Array, gid: String, rect: Rect2, at := 0.0) -> void:
	ev.append({"type": "fx", "id": "glance", "glance": gid, "rect": rect})
	_sfx(ev, "cue_" + gid, at)

# ---------------------------------------------------------------------------------------------
# state
# ---------------------------------------------------------------------------------------------
func _clear_transients() -> void:
	held = ""
	last_compare = {"places": "", "portions": ""}
	tape = ""
	ledger_spread = 0
	_spoon_this_visit = false

func _set_p07_done() -> void:
	state.p07_complete = true
	state.homed = true
	state.places = SOLUTION.duplicate()
	state.tally = SOLUTION_TALLY

func _set_p09_done() -> void:
	_set_p07_done()
	state.p09_complete = true
	state.drawer_open = true
	state.fitted = {"pantry": true, "bunk": true}
	state.socket_turned = true
	state.amend = SOLUTION_AMEND.duplicate()
	state.seal = SOLUTION_SEAL
	state.board_count = BOARD_COUNT

## Flags set elsewhere (tests, debug) pull the local arrangement along. Never clears anything
## and never grants the token.
func _sync() -> void:
	if game.flag("P09") and not state.p09_complete:
		_set_p09_done()
	if game.flag("P07") and not state.p07_complete:
		_set_p07_done()

func load_state(d: Variant) -> void:
	state = initial_state()
	_clear_transients()
	if not d is Dictionary:
		return
	for key in SAVED_BOOLS:
		if d.get(key) is bool:
			state[key] = d[key]
	var pl = d.get("places")
	if pl is Array and pl.size() == 9:
		pl = pl.duplicate()
		pl.append("")   # saves from before place_10: the arrangement stays, the new blank is empty
	if pl is Array and pl.size() == PLACES:
		var ok := true
		var used := []
		for b in pl:
			if not (b is String and (b == "" or b in BOWLS)):
				ok = false
			elif b != "":
				ok = ok and not b in used
				used.append(b)
		if ok:
			state.places = pl.duplicate()
	for key in ["tally", "board_count"]:
		if _all_whole([d.get(key)]):
			state[key] = clampi(int(d[key]), TALLY_MIN, TALLY_MAX)
	if _all_whole([d.get("seal")]):
		state.seal = clampi(int(d.seal), 1, 3)
	for key in ["misses", "stamp_misses"]:
		if _all_whole([d.get(key)]):
			state[key] = maxi(int(d[key]), 0)
	var am = d.get("amend")
	if am is Dictionary:
		if am.get("count") is String and am.count in COUNT_OPTIONS:
			state.amend.count = am.count
		if am.get("status") is String and am.status in STATUS_OPTIONS:
			state.amend.status = am.status
		if am.get("name") is String and (am.name == "" or am.name in NAME_TILES):
			state.amend.name = am.name
	var ft = d.get("fitted")
	if ft is Dictionary:
		for h in ["pantry", "bunk"]:
			if ft.get(h) is bool:
				state.fitted[h] = ft[h]
	if d.get("unsaid") is Array:
		for n in d.unsaid:
			if n is String and NOTICE_SILENT.has(n) and not n in state.unsaid:
				state.unsaid.append(n)
	if d.get("notices") is Array:
		for n in d.notices:
			if n is String and (n in NOTICES_A or n in NOTICES_B) and not n in state.notices:
				state.notices.append(n)
	# Derived: later progress implies earlier progress and its arrangement.
	if state.p09_complete:
		_set_p09_done()
	elif state.p07_complete:
		_set_p07_done()
	if not state.p07_complete:
		state.drawer_open = false
	if not state.drawer_open:
		state.fitted.pantry = false
	if not (state.fitted.pantry and state.fitted.bunk):
		state.socket_turned = false

## P07 and P09 are R05's: a flag set elsewhere (tests, debug) is honoured, then the flags follow
## the state. A fitted half is never in the inventory too; a half with no source is unfitted.
func reconcile() -> void:
	_sync()
	if not state.p09_complete and state.fitted.bunk and not game.flag("P08"):
		state.fitted.bunk = false
		state.socket_turned = false
	for h in ["pantry", "bunk"]:
		if state.fitted[h] and game.has_item(HALF_ITEM[h]):
			game.take(HALF_ITEM[h])
	game.set_flag("P07", state.p07_complete)
	game.set_flag("P09", state.p09_complete)
	if has_seen("menu_objections"):
		game.set_flag("o02_found")

# ---------------------------------------------------------------------------------------------
# debug
# ---------------------------------------------------------------------------------------------
const END_OBS := ["spoon_marks", "cloth_places", "bowl_stack", "unsigned_bowl", "tally", "nora_ledger",
	"headcount_nine", "drawer_rod", "drawer_note", "nora_work_card", "shift_board", "amendment_rule",
	"name_tiles", "seal_selector", "eight_retained", "service_hatch", "hatch_open"]

## The local state real play leaves at the start of tide `t`.
func debug_prepare(t: int) -> void:
	if t <= 3:
		state = initial_state()
		game.state.rooms[ID] = state
		return
	_set_p09_done()
	state.tiles_seen = true
	for item in HALF_ITEM.values():
		game.take(item)
	for o in END_OBS:
		_observe(o)
	_prepare_notices()

## Every notice older than the one due now is behind her; the due one still plays.
func _prepare_notices() -> void:
	for pair in [[NOTICES_A, current_notice_a()], [NOTICES_B, current_notice_b()]]:
		var side: Array = pair[0]
		var n: String = pair[1]
		var k := side.find(n) if n != "" else 0
		for i in k:
			if not side[i] in state.notices:
				state.notices.append(side[i])
	if not "arrival" in state.notices:
		state.notices.append("arrival")

## Dev stages: 0 Tide III fresh, 1 P07 solved (drawer shut), 2 drawer open and P08 in hand,
## 3 ready to stamp, 4..9 the start of tides IV..IX (bands 2..7), 10 sever, 11 continue.
func debug_jump(n: int) -> void:
	if n <= 3:
		game.debug_tide(3, ID)
		if n >= 1:
			_set_p07_done()
			for o in ["spoon_marks", "cloth_places", "bowl_stack", "unsigned_bowl", "tally", "nora_ledger",
					"headcount_nine"]:
				_observe(o)
			_mark_notice("arrival")
		if n >= 2:
			state.drawer_open = true
			game.give("token_pantry_half", [])
			_observe("drawer_note")
			game.set_flag("P08")
			game.give("token_bunk_half", [])
		if n >= 3:
			for item in HALF_ITEM.values():
				game.take(item)
			state.fitted = {"pantry": true, "bunk": true}
			state.socket_turned = true
			state.amend = SOLUTION_AMEND.duplicate()
			state.seal = SOLUTION_SEAL
			state.tiles_seen = true
			for o in ["shift_board", "amendment_rule", "name_tiles", "seal_selector"]:
				_observe(o)
	elif n <= 9:
		game.debug_tide(n, ID)
	else:
		game.debug_tide(9, ID)
		game.state.ending = "sever" if n == 10 else "continue"
	reconcile()
	_clear_transients()
	_sq_lift_said = false
	_mercer_said = false
	_register_said = false
	local_view = "c_service_board" if n == 3 else "room"
