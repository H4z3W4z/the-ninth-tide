class_name R10Sim
extends RoomSim
## R10, the Records Vault. Owns P16 (the contact sheet of the Index session), P18 (Rook's
## folders around Nora's three records) and P23 (the Index model that takes a witness):
## docs/design/puzzle-cards/P16.md, P18.md, P23.md and rooms.md R10. Node-free and
## deterministic; the view reads the helpers below and the transient vars (held, edge_break,
## strip_text, model_text) and plays the events.
##
## Two base views: "room" (A, the shelves) and "catalogue" (B, the catalogue wall; not a
## close-up). Close-ups: c_contact (P16), c_folders (P18), c_model (P23).

const ID := "R10"
const TITLE := "Records Vault"
const REQUIRES := ["P15"]
const LOCKED := "The vault latch is shut fast. Something in the station has to let it go."
const RESUME := "Back in the records vault."
const WAY_IN_HINT := "The vault door in the laboratory has let go."
const ARRIVAL := "The records vault. The shelves go back further than the floor plan does."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R07", "Laboratory", []],
]

## View A (the shelves) and view B (the catalogue wall) hotspots, in hit order.
const HOTSPOTS := ["wall_clock", "photographs", "index_cards", "contact_table", "shelves", "to_catalogue"]
const CATALOGUE_HOTSPOTS := ["staff_drawer", "tray", "correspondence_drawer", "wrapped_photo", "model",
	"folders", "to_shelves"]
const CLOSEUPS := ["c_contact", "c_folders", "c_model"]
## Close-up controls (never the same id as a hotspot).
const CONTACT_CONTROLS := ["slot_1", "slot_2", "slot_3", "slot_4", "loose_a", "loose_b", "loose_c",
	"loose_d", "clip", "cover"]
const FOLDER_CONTROLS := ["lid_card", "fold_body", "fold_place", "fold_name", "cmp_tray", "day_up",
	"day_dn", "mon_up", "mon_dn", "year_up", "year_dn", "compare", "release"]
const MODEL_CONTROLS := ["faceplate", "strip", "bridge", "shutter", "t_input", "t_copy", "t_witness",
	"lead", "test", "reset", "stamp"]

# --- P16: the contact sheet ------------------------------------------------------------------
const PANELS := ["A", "B", "C", "D"]
const SOLUTION := ["B", "D", "A", "C"]
## A panel carries film frames EDGE_FIRST .. EDGE_FIRST + 3.
const EDGE_FIRST := {"B": 1, "D": 5, "A": 9, "C": 13}
const LAMPS := {"B": 8, "D": 6, "A": 3, "C": 0}
const CLOCK := {"B": "21:00", "D": "21:20", "A": "21:40", "C": "22:00"}
const LAMP_WORD := {8: "eight", 6: "six", 3: "three", 0: "none"}
const COUNT_WORD := {1: "one", 2: "two", 3: "three", 4: "four", 5: "five", 6: "six", 7: "seven", 8: "eight"}
const CLIPPED_HOLDS := "Clipped. It holds."
const COVER_REGISTERED := "The cover's registered to the edge. It won't slide until the edge is clipped."
const COVER_OFF := "The cover's off. They stay uncovered."
const CLIP_NEEDS := "The edge needs clamping flat. My chart clips would hold it."
const CLIP_ONLY := "Only the chart clips will hold the edge."
const NOT_ALL_IN := "Four panels, four places. Not all of them are in."
const CLIP_DONE := "Clipped. Frames one to sixteen, unbroken."
const GLANCE_CONTACT := [800, 560, 400, 270]

# --- P18: Rook's folders ---------------------------------------------------------------------
const FOLDERS := {"fold_body": "BODY", "fold_place": "PLACE", "fold_name": "NAME"}
const FOLDER_ORDER := ["BODY", "PLACE", "NAME"]
const RECORD_FOLDER := {"nora_frame": "BODY", "nora_spatial_strip": "PLACE", "nora_register_card": "NAME"}
const RECORDS := ["nora_frame", "nora_spatial_strip", "nora_register_card"]
const WORDS := {"nora_frame": "her frame", "nora_spatial_strip": "the bearing strip",
	"nora_register_card": "her register card"}
const MISMATCH := {
	"nora_frame/PLACE": "A breath isn't a bearing.",
	"nora_frame/NAME": "A breath isn't a name.",
	"nora_spatial_strip/BODY": "A bearing isn't a body.",
	"nora_spatial_strip/NAME": "A bearing isn't a name.",
	"nora_register_card/BODY": "A name isn't a body.",
	"nora_register_card/PLACE": "A name isn't a place.",
}
const COVERS := {
	"BODY": "BODY. The cover shows a breath trace.",
	"PLACE": "PLACE. The cover shows a bearing diagram.",
	"NAME": "NAME. The cover shows a personal card.",
}
const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
const SESSION := [18, 10, 1927]
const NOT_YET := [18, 10, 1931]
const TODAY := [17, 10, 1931]
const DAY_RANGE := [1, 31]
const MONTH_RANGE := [1, 12]
const YEAR_RANGE := [1889, 1931]
const RECORDS_BACK := "I take Nora's records back with me."
const PROTOCOL := "'A subject is complete when BODY, PLACE and NAME correspond on one session date.' S.R."
const RELEASE_LINE := "TRAINING RELEASE. 'Training model. Release returns all records.'"
const STRIP_COMPLETE := "SUBJECT COMPLETE"
const STRIP_NO_SESSION := "NO SESSION ON RECORD"
const STRIP_INCOMPLETE := "INCOMPLETE: THREE RECORDS REQUIRED"
const STRIP_CATEGORY := "CATEGORY DOES NOT CORRESPOND"
const STRIP_DATE := "DATE DOES NOT CORRESPOND."
const STRIP_NOT_YET := "DATE DOES NOT CORRESPOND.\nNOT YET."
const FOLDERS_DONE := "It's done its demonstration. I won't file her again."
const SHEET_DATE := "The sheet only gives the date. 18 October 1927."
const GLANCE_DRAWER := [100, 680, 240, 120]
## P18's reveal chain, three lines (the folders' card and the records' return are shown).
const P18_SHUT := "The folders shut on her, all three."
const P18_STAFF := "Behind me, inside the shut STAFF drawer, every card moves at once."
const P18_RELEASE := "I pull the release. Venn's drawer opens."

# --- P23: the Index model --------------------------------------------------------------------
const SHUTTER_LINE := "A brass shutter over the terminals. A hollow circle on it: OBSERVER. No keyhole this side. It opens from the other side."
## The terminals carry marks, not words: the faceplate and the socket plates show only these.
## Two of them are the two marks in the margin of the session log (R04Sim.MARGIN_MARKS, P17),
## drawn there joined by a stroke beside "A human correction keeps it open." Nothing on the
## model pairs them; the rule is learned from that margin, by testing, and by the copy's failure.
const TERMINAL_GLYPHS := {"input": "triangle", "copy": "squares", "witness": "circle"}
const GLYPH_WORDS := {"triangle": "the triangle", "squares": "the two squares", "circle": "the circle"}
const FACEPLATE := "Three terminals. A solid triangle, two squares overlapping, a hollow circle. No words on the plate."
const MODEL_OPEN_LINE := "The Index model. Three brass leaves over a terminal block."
const STRIP_CLOSED := "AMENDMENT 1 APPENDED. RECORD CLOSED."
const STRIP_OPEN := "AMENDMENT 1 APPENDED. RECORD OPEN."
const STRIP_WITNESS := "WITNESS: MERCER, A."
const STRIP_RECORD_OPEN := "RECORD OPEN"
const STRIP_NO_INPUT := "NO INPUT"
const LEAD_START := "The lead starts at the triangle."
const STAMPED_OPEN := "It's stamped OPEN. In ink."
const GLANCE_STAFF := [420, 370, 220, 160]

# --- escalation ------------------------------------------------------------------------------
## First-time holds in view A, oldest first. Seeing one retires every older one.
const NOTICES := ["shelves", "ninth_photo", "mercer_card", "shelves_more"]
const CATALOGUE_NOTICES := ["aperture_wide"]
const NOTICE_LINES := {
	"ninth_photo": "There are nine photographs now. And I can't hear the sea through the wall any more.",
	"mercer_card": "A new card at the front of the file. MERCER, A.",
	"shelves_more": "The shelves go back further than they did.",
	"aperture_wide": "The stripe up from STAFF is wider again. The drawer's still shut.",
}
## Band 5 on: the vault stands flooded to a dead-level line, and below it the shelves are only
## their own reflection. Said once, the first time she faces the shelves at band 5 or later.
const FLOOD_BAND := 5
const FLOOD_LINE := "The lower shelves aren't lit. They're reflected."
## The STAFF drawer, shut: the first look and the second.
const STAFF_FIRST := "STAFF. The drawer's shut. What's coming out of it is running up."
const STAFF_SECOND := "It's warm. The label's in my handwriting."

const OBSERVATIONS := {
	"shelves": "The shelves go back further than the floor plan allows. Past where the laboratory wall should be they keep going, each bay a little smaller, all labelled in the same hand.",
	"shelves_more": "The shelves go further back than they did. The last bays pass behind the corner of the room.",
	"vault_clock": "The vault's wall clock is stopped at 22:00. The pendulum hangs still. No dust on the face.",
	"photographs": "Eight photographs of the same eight chairs, one chair each. In every chair a carefully retouched blank where a person sat. At the end of the row an empty hook, and the wall paler where a ninth frame hung.",
	"photos_turned": "The blanks in the wall photographs have turned the same way as the last face on the contact sheet: away from the camera.",
	"ninth_photo": "A ninth photograph on the empty hook: an empty chair, and nothing retouched. The chair is waiting, not emptied.",
	"retouch": "Under the lens the blanks are brushwork on the emulsion, fine and patient.",
	"index_file": "The vault's hanging file: eight cards, BELL to TULL, each stamped RETAINED 18.X.27. After TULL, an empty divider. No card for Venn. He was there and never indexed.",
	"mercer_card": "At the front of the hanging file, a new card: MERCER, A. Nothing else on it.",
	"contact_table": "A contact table: four panel slots on lit glass, a numbered film edge under them, a clamp rail for the edge and an opaque registration cover pinned across the faces. Four loose panels, A to D, each a photograph of the same eight chairs.",
	"panel_a": "Panel A: film frames 9 to 12. The wall clock behind the chairs reads 21:40. Three chair lamps lit.",
	"panel_b": "Panel B: frames 1 to 4. 21:00. All eight lamps lit.",
	"panel_c": "Panel C: frames 13 to 16. 22:00. No lamps lit.",
	"panel_d": "Panel D: frames 5 to 8. 21:20. Six lamps lit.",
	"contact_sheet_1927": "18 October 1927, the Index session. Eight staff seated, lamps going out one by one. Behind the camera, in the glass: an unoccupied witness station, and Venn standing outside the seating. Pencilled on the film edge: 'Sync: bell.'",
	"venn_glass": "In the glass of the contact sheet, Venn is younger, and looking at the empty witness station, not at the chairs.",
	"folders": "A cabinet of three folders, BODY, PLACE and NAME. Their covers show what each holds: BODY a breath trace, PLACE a bearing diagram, NAME a personal card. A comparison tray, a session-date dial set to today, a COMPARE key.",
	"protocol_card": "Inside the cabinet lid, Rook's protocol card: 'A subject is complete when BODY, PLACE and NAME correspond on one session date.'",
	"training_release": "A lever on the panel, printed: 'TRAINING RELEASE. Training model. Release returns all records.'",
	"not_yet": "Set to 18 October 1931, the folders printed DATE DOES NOT CORRESPOND, and under it: NOT YET.",
	"index_protocol": "Rook's Index: when body, place and name agree on one date, the subject is complete. The cabinet closed a model around Nora's records. The real system did this to all eight.",
	"staff_aperture": "A catalogue drawer marked STAFF, shut. Out of its top seam a thin hard stripe of sea-glass runs straight up the cabinet and the wall to the ceiling, and spreads along it.",
	"staff_label": "The STAFF drawer is warm to the touch. The label on it is in my handwriting.",
	"flood": "The vault stands flooded to a dead-level line at the office's tide height. Below it the lower shelves aren't lit: they are the shelves above, reflected.",
	"staff_tray": "A brass tray in front of the STAFF drawer, the size of a record card, worn bright in the middle.",
	"tray_for": "The tray in front of STAFF is where records are fed to it. I put nothing there.",
	"venn_drawer": "A small drawer with a brass plate cut three times: Venn's seal. Locked from inside.",
	"venn_drawer_open": "Venn's drawer opened by itself when the folders let Nora go. His unsent letters, a clipping of the 1929 harbour inquiry, the closure contract. All for me. Inside the lid, in pencil: 'For A.M.'",
	"parcel": "A parcel in brown paper and string, labelled S.R. PERSONAL.",
	"o06_photo": "Rook's own photograph, wrapped and tied: a woman and a small boy on the jetty in summer. On the back: 'Edith and Kit, 1911. To keep them exactly as they are.' He meant preservation as love, once.",
	"model": "An Index model on the cabinet: three brass leaves over a terminal block.",
	"model_shutter": "The model's terminals are behind a brass shutter marked with a hollow circle, OBSERVER. No keyhole on this side.",
	"faceplate": "The model's faceplate has no words: three marks over three terminals, a solid triangle, two overlapping squares and a hollow circle. A lead from the triangle with two plugs; TEST AMENDMENT and RESET. A bridge sits across the circle.",
	"model_closed_test": "On the model, the triangle to the two squares: the amendment was appended and the record printed CLOSED. Every drawer in the catalogue knocked at once, the stripe up from STAFF stopped, and for a moment the photographs on the wall held nothing. RESET opens it again at once.",
	"witness_test": "On the model: the triangle to the two squares closes the record. The triangle to the hollow circle takes an amendment and stays open. The circle is the witness. The witness has to be a person, and the person has to stay.",
	"aperture_wider": "After the test the stripe running up from STAFF is wider than it was. Nothing touched it.",
	"aperture_wide": "The stripe up from STAFF is wider again. The drawer is still shut.",
}
const OBJECTIVES := {
	"p16": "Put the 1927 contact sheet back in order and uncover the faces.",
	"p18": "File Nora's three records in Rook's folders, set the session date and compare.",
	"away_p17": "The vault's folders are done. The session recording waits in the listening room.",
	"wait_p21": "The Index model's terminals are shuttered. Something else comes first.",
	"p23": "Test the Index model: a record that takes a correction and stays open.",
	"done": "The model is stamped OPEN. The bridge is mine to carry.",
}
const HINTS := {
	"p16": [
		"The vault's contact table holds four panels of the same night.",
		"The film edge numbers must run on, and the lamps go out in order.",
		"Each panel's film edge is numbered, and its chair lamps can be counted.",
		"B, D, A, C: eight lamps, six, three, none. Clip the edge, then slide the cover off.",
	],
	"p18": [
		"The vault's three folders want Nora's three records.",
		"Each folder takes what that instrument measured.",
		"The film edge is dated. So is the spool.",
		"Frame to BODY, strip to PLACE, register card to NAME, date 18 Oct 1927, COMPARE.",
	],
	"p23": [
		"The model in the vault can be tested safely.",
		"A copy closes a record. A witness keeps it open.",
		"The session log's margin has two marks. The terminals carry the same two.",
		"Lead from the triangle to the hollow circle, leave the two squares empty, press TEST AMENDMENT. Take the bridge.",
	],
	"away_p17": [
		"The vault's done its part of the session.",
		"The contact sheet says sync on the bell. The listening room has the session spool.",
		"Take the contact sheet to the listening room's mixer.",
	],
	"wait_p21": [
		"The model's terminals are shut from the other side.",
		"Venn's letters belong on the office board. The chart room's plan comes after.",
		"Finish the office board and the chart room plan. The shutter opens after.",
	],
	"done": [
		"The vault has given me what it had.",
		"The bridge belongs to the chamber door.",
		"Take the witness bridge to the dry stair's lower door.",
	],
}
## Items this room hands out (docs/design/puzzle-cards/flags.md section 4).
const ITEMS := {
	"contact_sheet": {"name": "Contact sheet, 18 Oct 1927", "short": "Contact sheet", "desc": "A contact sheet from the Index session."},
	"venn_correspondence": {"name": "Venn's correspondence", "short": "Venn's letters", "desc": "Letters from Venn's drawer in the vault."},
	"witness_bridge": {"name": "Witness bridge", "desc": "A bridge part from the Index model, marked with a hollow circle."},
}

const SAVED_BOOLS := ["clipped", "cover_off", "p16_complete", "p18_complete", "staff_open", "drawer_open",
	"input", "copy", "witness", "p23_complete", "bridge_taken", "strip2", "not_yet_seen", "folders_seen",
	"flood_seen"]

## Transient, never saved: what the view shows after the last action.
var held := ""          # the panel letter in hand in c_contact
var edge_break := -1    # after a failed clip: the break is between slot k and k + 1
var strip_text := ""    # the c_folders result printer
var model_text := ""    # the c_model strip's current line

func initial_state() -> Dictionary:
	return {
		"slots": ["", "", "", ""], "clipped": false, "cover_off": false, "p16_complete": false,
		"filed": {"BODY": "", "PLACE": "", "NAME": ""}, "tray": [],
		"day": TODAY[0], "month": TODAY[1], "year": TODAY[2], "p18_complete": false,
		"staff_open": false, "drawer_open": false, "wrap": 0,
		"input": false, "copy": false, "witness": false, "stamp": "", "p23_complete": false,
		"bridge_taken": false, "strip2": false,
		"notices": [], "catalogue_notices": [], "not_yet_seen": false, "folders_seen": false,
		"flood_seen": false,
	}

func is_closeup(v := local_view) -> bool:
	return v in CLOSEUPS

## The puzzles' ladders carry an evidence rung before the solution (location, relationship,
## evidence, solution); the idle ones keep three.
func hint_tiers() -> int:
	return c("HINTS", {}).get(objective(), []).size()

func objective() -> String:
	_sync()
	if not state.p16_complete:
		return "p16"
	if not state.p18_complete:
		return "p18"
	if not game.flag("P17"):
		return "away_p17"
	if not game.flag("P21"):
		return "wait_p21"
	if not state.p23_complete:
		return "p23"
	return "done"

# ---------------------------------------------------------------------------------------------
# view helpers (read-only)
# ---------------------------------------------------------------------------------------------
func band() -> int:
	return game.weather_band()

## The current tide (VI on arrival). The vault's bay deepens and its paper darkens with it.
func tide() -> int:
	return game.tide()

func slot_letters() -> Array:
	return state.slots

## The panels in no slot and not in hand, always in A, B, C, D order.
func loose_letters() -> Array:
	var out := []
	for p in PANELS:
		if not p in state.slots and p != held:
			out.append(p)
	return out

static func edge_numbers(letter: String) -> Array:
	var n: int = EDGE_FIRST[letter]
	return [n, n + 1, n + 2, n + 3]

## How many of panel `letter`'s chair lamps are lit (the view draws them; nobody says it).
static func lamps_lit(letter: String) -> int:
	return LAMPS[letter]

static func panel_clock(letter: String) -> String:
	return CLOCK[letter]

func last_turned() -> bool:
	return state.cover_off

func photos_turned() -> bool:
	return state.p16_complete

func ninth_photo() -> bool:
	return band() >= 5

func mercer_card() -> bool:
	return band() >= 6

func shelves_more() -> bool:
	return band() >= 7

func shutter_open() -> bool:
	return game.flag("P21")

func aperture_width() -> int:
	if band() >= 7:
		return 2
	return 1 if state.p23_complete else 0

func staff_open() -> bool:
	return state.staff_open

## The copy test closed the record: every STAFF drawer is slammed shut until RESET. Derived from
## the stamp, so a load, RESET and the solve all agree with it.
func staff_shut() -> bool:
	return state.staff_open and str(state.stamp) == "closed"

func drawer_open() -> bool:
	return state.drawer_open

func wrap() -> int:
	return int(state.wrap)

## Band 5 on: the vault is flooded to a fixed line and the lower shelves are a reflection.
func flooded() -> bool:
	return band() >= FLOOD_BAND

func sea_through_wall() -> bool:
	return band() == 4

func sheet_assembled() -> bool:
	return state.p16_complete

func bridge_present() -> bool:
	return not state.bridge_taken

## The view's occluder loop: a lamp passing deep in the shelves.
func deep_lamp_passing() -> bool:
	return band() >= 5

func date_text() -> String:
	return "%02d %s %d" % [int(state.day), MONTHS[int(state.month) - 1], int(state.year)]

func date_is(d: Array) -> bool:
	return int(state.day) == d[0] and int(state.month) == d[1] and int(state.year) == d[2]

## The model's printed lines (the view's strip).
func model_lines() -> Array:
	if state.strip2:
		return [STRIP_OPEN, STRIP_WITNESS]
	return [model_text] if model_text != "" else []

## The view A notice due now (a NOTICES id), or "".
func current_notice() -> String:
	match band():
		7:
			return "shelves_more"
		6:
			return "mercer_card"
		5:
			return "ninth_photo"
	return ""

func current_catalogue_notice() -> String:
	return "aperture_wide" if band() >= 7 else ""

# ---------------------------------------------------------------------------------------------
# entry points
# ---------------------------------------------------------------------------------------------
func arrive(ev: Array, first: bool) -> void:
	_sync()
	_clear_transient()
	if first:
		_say(ev, ARRIVAL)
		_sfx(ev, "paper_settle", 1.4)
		_say(ev, "Somewhere a long way back, paper settles.", 2.6, true)
		_fx(ev, "notice_shelves")
		_observe("shelves")
		_mark_notice("shelves")
		# A first look has nothing earlier to compare with: the current state is simply how it is.
		var n := current_notice()
		if n != "":
			_mark_notice(n)
		_flood_notice(ev, 4.8)
		return
	_room_notice(ev)

func back(ev: Array) -> void:
	_sync()
	match local_view:
		"c_contact":
			_go("room", ev)
			_room_notice(ev)
		"c_folders", "c_model":
			_go("catalogue", ev)
			_catalogue_notice(ev)
		"catalogue":
			_go("room", ev)
			_room_notice(ev)
		_:
			_go("room", ev)

func act(action: String, ev: Array) -> void:
	_sync()
	match local_view:
		"c_contact":
			if action in CONTACT_CONTROLS:
				_contact(action, ev)
				return
		"c_folders":
			if action in FOLDER_CONTROLS:
				_folders(action, ev)
				return
		"c_model":
			if action in MODEL_CONTROLS:
				_model(action, ev)
				return
	if action in HOTSPOTS:
		_go("room", ev)
		_room(action, ev)
	elif action in CATALOGUE_HOTSPOTS:
		_go("catalogue", ev)
		_catalogue(action, ev)

## Every change of local_view goes through here: the transients belong to the view they were
## made in, and Nora's records never stay behind in the folders.
func _go(v: String, ev: Array) -> void:
	if v == local_view:
		return
	if local_view == "c_folders":
		if _return_records(ev):
			_say(ev, RECORDS_BACK)
	local_view = v
	_clear_transient()

## Facing the shelves: the flood line first (once, from band 5), then the band's notice.
func _room_notice(ev: Array) -> void:
	var flood := _flood_notice(ev, 0.0)
	var n := current_notice()
	if n != "" and not n in state.notices:
		_deliver(ev, n, 2.4 if flood else 1.6, flood)
		_mark_notice(n)

## The flood's line, story, the first time she faces the shelves at band 5 or later. True if said.
func _flood_notice(ev: Array, delay: float) -> bool:
	if not flooded() or state.flood_seen:
		return false
	state.flood_seen = true
	_say(ev, FLOOD_LINE, delay, true)
	_observe("flood")
	return true

func _catalogue_notice(ev: Array) -> void:
	var n := current_catalogue_notice()
	if n != "" and not n in state.catalogue_notices:
		_deliver(ev, n)
		state.catalogue_notices.append(n)

func _deliver(ev: Array, n: String, delay := 1.6, story := false) -> void:
	_fx(ev, "notice_" + n)
	_say(ev, NOTICE_LINES[n], delay, story)
	_observe(n)

# ---------------------------------------------------------------------------------------------
# view A: the shelves
# ---------------------------------------------------------------------------------------------
func _room(action: String, ev: Array) -> void:
	var b := band()
	match action:
		"wall_clock":
			_sfx(ev, "clock_tap")
			_say(ev, "Stopped at ten at night. 22:00. No dust on the glass.")
			_observe("vault_clock")
		"photographs":
			var line := "Eight photographs of chairs. Somebody sat in each, and somebody else painted them out. Carefully."
			if state.p16_complete:
				line = "The blanks have turned. All of them, the same way as the last face on the sheet."
				_observe("photos_turned")
			if ninth_photo():
				line += " And a ninth: an empty chair. Nobody painted anything out of it."
				_observe("ninth_photo")
			_say(ev, line)
			_observe("photographs")
		"index_cards":
			_sfx(ev, "card_flip")
			var line := "The station Index. Eight cards, BELL to TULL, each stamped RETAINED 18.X.27. After TULL, a divider with nothing behind it."
			_observe("index_file")
			if mercer_card():
				line += " MERCER, A. At the front. There's nothing else on it."
				_observe("mercer_card")
			_say(ev, line)
		"shelves":
			if b >= 7:
				_say(ev, "There are more of them than there were. They go behind the corner of the room.")
				_observe("shelves_more")
			else:
				_say(ev, "They go back past where the laboratory should be. Each bay a little smaller, labelled in the same hand.")
			_observe("shelves")
		"contact_table":
			_open_contact(ev)
		"to_catalogue":
			_say(ev, "The catalogue wall. STAFF, the folders, the model.")
			_catalogue_view(ev)

func _catalogue_view(ev: Array) -> void:
	_go("catalogue", ev)
	_catalogue_notice(ev)

func _open_contact(ev: Array) -> void:
	_go("c_contact", ev)
	if state.p16_complete:
		_say(ev, "The last one's still turned away.")
	elif not has_seen("contact_table"):
		_say(ev, "The contact table. Four panels of one night, and a cover pinned over the faces.")
	else:
		_say(ev, "The contact table.")
	_observe("contact_table")

# ---------------------------------------------------------------------------------------------
# view B: the catalogue wall
# ---------------------------------------------------------------------------------------------
func _catalogue(action: String, ev: Array) -> void:
	match action:
		"staff_drawer":
			if staff_shut():
				_say(ev, "Nothing's coming out of it now. The model says CLOSED.")
				return
			# The drawer is always shut: what she sees is the stripe running up out of its seam.
			state.staff_open = true
			if not has_seen("staff_aperture"):
				_say(ev, STAFF_FIRST)
				_observe("staff_aperture")
			elif not has_seen("staff_label"):
				_sfx(ev, "staff_settle")
				_say(ev, STAFF_SECOND)
				_observe("staff_label")
			else:
				match aperture_width():
					2:
						_say(ev, "Wider again. Still running up.")
						_observe("aperture_wide")
					1:
						_say(ev, "Wider than it was. I didn't see it change.")
					_:
						_say(ev, "Still running up. The drawer stays shut.")
		"tray":
			_say(ev, "A brass tray in front of STAFF, the size of a record card. Worn bright in the middle.")
			_observe("staff_tray")
		"correspondence_drawer":
			if not state.p18_complete:
				_sfx(ev, "drawer_locked")
				_say(ev, "Locked. The plate's cut three times. Venn's mark.")
				_observe("venn_drawer")
			else:
				_say(ev, "Empty. A clean rectangle in the dust where the letters were.")
		"wrapped_photo":
			_wrapped_photo(ev)
		"model":
			_go("c_model", ev)
			_say(ev, MODEL_OPEN_LINE)
			_observe("model")
			if shutter_open():
				_observe("faceplate")
			else:
				_observe("model_shutter")
		"folders":
			_go("c_folders", ev)
			if state.p18_complete:
				_say(ev, "The folders. They've done their demonstration.")
			elif not state.folders_seen:
				state.folders_seen = true
				_say(ev, "Rook's folders. BODY, PLACE, NAME. The date dial's set to today.")
			else:
				_say(ev, "BODY, PLACE, NAME.")
			_observe("folders")
		"to_shelves":
			_say(ev, "The shelves.")
			_go("room", ev)
			_room_notice(ev)

func _wrapped_photo(ev: Array) -> void:
	if not state.p18_complete:
		_say(ev, "A parcel in brown paper and string. A label: S.R. PERSONAL. The knot's pulled tight.")
		_observe("parcel")
		return
	match int(state.wrap):
		0:
			state.wrap = 1
			_sfx(ev, "string_untie")
			_say(ev, "The knot's loose now. It wasn't, before.")
			_observe("parcel")
		1:
			state.wrap = 2
			game.set_flag("o06_found")
			_observe("o06_photo")
			_sfx(ev, "paper_unwrap")
			_say(ev, "A photograph. A woman and a small boy on the jetty, in summer, squinting.")
			_say(ev, "On the back, in Rook's hand: 'Edith and Kit, 1911. To keep them exactly as they are.'", 2.4, true)
			_say(ev, "He meant it kindly, once. That doesn't help.", 5.6, true)
		_:
			_say(ev, "Edith and Kit. I leave them unwrapped.")

# ---------------------------------------------------------------------------------------------
# P16: c_contact
# ---------------------------------------------------------------------------------------------
func _contact(action: String, ev: Array) -> void:
	if action == "clip":
		_say(ev, "Clipped." if state.clipped else CLIP_NEEDS)
		return
	if action == "cover":
		_cover(ev)
		return
	if state.clipped:
		_say(ev, CLIPPED_HOLDS)
		return
	var slots: Array = state.slots
	if action.begins_with("loose_"):
		var x := action.substr(6).to_upper()
		if x in slots:
			_say(ev, "Panel %s is in slot %d." % [x, slots.find(x) + 1])
		elif held == x:
			held = ""
			_sfx(ev, "panel_place")
			_say(ev, "Back with the others.")
		else:
			# Picking x up; anything in hand goes back with the loose ones.
			held = x
			_sfx(ev, "panel_pick")
			_say(ev, _panel_line(x))
			_observe("panel_" + x.to_lower())
		return
	var k := int(action.substr(5)) - 1
	if held != "":
		var occupant: String = slots[k]
		slots[k] = held
		_sfx(ev, "panel_place")
		_say(ev, "Panel %s in slot %d." % [held, k + 1])
		held = occupant
		edge_break = -1
	elif slots[k] != "":
		held = slots[k]
		slots[k] = ""
		edge_break = -1
		_sfx(ev, "panel_pick")
		_say(ev, "Panel %s, lifted." % held)
	else:
		_say(ev, "Slot %d. Empty." % (k + 1))

## Picking a panel up names it and nothing else: the frame numbers, the clock and the lamps
## are hers to read off the panel.
static func _panel_line(x: String) -> String:
	return "Panel %s." % x

## The first break in `slots` (four distinct panels): the k whose pair k, k + 1 does not run
## on. -1 when the edge is continuous from frame 1.
static func first_break(slots: Array) -> int:
	for k in 3:
		if EDGE_FIRST[slots[k + 1]] != EDGE_FIRST[slots[k]] + 4:
			return k
	if slots[0] != "B":
		# Cannot happen with four distinct panels; reported where the numbering wraps.
		return 0
	return -1

## The clip's refusal for panel x followed by panel y: the break in the film edge, then the
## lamps as the independent check (the card: "Frame 8, then frame 13." and "Eight, three: two
## lamps went out between them that I haven't got."). A falling pair that breaks the edge
## always skips a panel; the lamps "I haven't got" are the ones that went out before it.
static func break_line(x: String, y: String) -> String:
	var lx: int = LAMPS[x]
	var ly: int = LAMPS[y]
	var word: String = LAMP_WORD[lx]
	var lamp := "%s, %s: " % [word.substr(0, 1).to_upper() + word.substr(1), LAMP_WORD[ly]]
	if ly > lx:
		lamp += "lamps don't come back on."
	else:
		var gone: int = lx - LAMPS[SOLUTION[SOLUTION.find(x) + 1]]
		lamp += "%s lamps went out between them that I haven't got." % COUNT_WORD[gone]
	return "Frame %d, then frame %d. %s" % [EDGE_FIRST[x] + 3, EDGE_FIRST[y], lamp]

func _clip(ev: Array) -> void:
	if state.clipped:
		_say(ev, "Clipped.")
		return
	var slots: Array = state.slots
	if "" in slots:
		edge_break = -1
		_sfx(ev, "edge_refuse")
		_say(ev, NOT_ALL_IN)
		return
	var k := first_break(slots)
	if k >= 0:
		edge_break = k
		_sfx(ev, "edge_refuse")
		_say(ev, break_line(slots[k], slots[k + 1]))
		return
	held = ""
	edge_break = -1
	state.clipped = true
	_sfx(ev, "clip_snap")
	_fx(ev, "clamp")
	_say(ev, CLIP_DONE)
	_say(ev, "The cover's tab gives a little.", 1.6)

func _cover(ev: Array) -> void:
	if state.cover_off:
		_say(ev, COVER_OFF)
		return
	if not state.clipped:
		_say(ev, COVER_REGISTERED)
		return
	state.cover_off = true
	state.p16_complete = true
	game.solve("P16", ev)
	game.give("contact_sheet", ev)
	_observe("contact_sheet_1927")
	_sfx(ev, "cover_slide", 0.0)
	_fx(ev, "cover_off", {"delay": 0.0})
	_say(ev, "Faces. The same blanks as the photographs on the wall. Eight of them, painted out.", 0.8, true)
	_fx(ev, "last_turn", {"delay": 3.8})
	_sfx(ev, "blank_turn", 3.8)
	_say(ev, "The last panel. 22:00, no lamps. That one's turned.", 4.0, true)
	_say(ev, "Not to the camera. To whatever stood behind it.", 7.0, true)
	_fx(ev, "reflection", {"delay": 10.0})
	_say(ev, "In the glass: an empty station behind the camera. And Venn, standing outside the chairs.", 10.0, true)
	_sfx(ev, "sheet_take", 13.6)
	_say(ev, "The film edge is dated 18 October 1927. I take the sheet.", 13.6, true)
	_fx(ev, "glance", {"rect": GLANCE_CONTACT.duplicate(), "target": "contact_table"})

# ---------------------------------------------------------------------------------------------
# P18: c_folders
# ---------------------------------------------------------------------------------------------
func _folders(action: String, ev: Array) -> void:
	if FOLDERS.has(action):
		var f: String = FOLDERS[action]
		var rec: String = state.filed[f]
		if rec != "":
			state.filed[f] = ""
			game.give(rec, ev)
			_sfx(ev, "folder_return")
			_say(ev, "I take %s back out." % WORDS[rec])
		else:
			_say(ev, COVERS[f])
		return
	match action:
		"day_up", "day_dn":
			state.day = _wheel(int(state.day), 1 if action == "day_up" else -1, DAY_RANGE)
			_sfx(ev, "wheel_click")
		"mon_up", "mon_dn":
			state.month = _wheel(int(state.month), 1 if action == "mon_up" else -1, MONTH_RANGE)
			_sfx(ev, "wheel_click")
		"year_up", "year_dn":
			state.year = _wheel(int(state.year), 1 if action == "year_up" else -1, YEAR_RANGE)
			_sfx(ev, "wheel_click")
		"cmp_tray":
			if state.tray.is_empty():
				_say(ev, "The comparison tray. Empty.")
			else:
				for rec in state.tray:
					game.give(rec, ev)
				state.tray = []
				_say(ev, "I take them back.")
		"lid_card":
			_say(ev, PROTOCOL)
			_observe("protocol_card")
		"release":
			if state.p18_complete:
				_say(ev, "Down. It stays down.")
			else:
				_return_records(ev)
				_say(ev, RELEASE_LINE)
				_observe("training_release")
		"compare":
			_compare(ev)

static func _wheel(v: int, step: int, r: Array) -> int:
	var lo: int = r[0]
	var n: int = r[1] - lo + 1
	return lo + posmod(v - lo + step, n)

## Every record in the folders or the comparison tray back to the inventory. True if any was out.
func _return_records(ev: Array) -> bool:
	var any := false
	for f in FOLDER_ORDER:
		var rec: String = state.filed[f]
		if rec != "":
			game.give(rec, ev)
			state.filed[f] = ""
			any = true
	for rec in state.tray:
		game.give(rec, ev)
		any = true
	state.tray = []
	return any

func _file(rec: String, fid: String, ev: Array) -> void:
	if state.p18_complete:
		_say(ev, FOLDERS_DONE)
		return
	var f: String = FOLDERS[fid]
	if state.filed[f] != "":
		_say(ev, "%s already has one in it." % f.capitalize())
		return
	game.take(rec)
	state.filed[f] = rec
	_sfx(ev, "folder_file")
	_say(ev, "In %s." % f)

func _compare(ev: Array) -> void:
	_sfx(ev, "compare_key")
	if state.p18_complete:
		strip_text = STRIP_COMPLETE
		_say(ev, FOLDERS_DONE)
		return
	if not game.flag("P16"):
		strip_text = STRIP_NO_SESSION
		_say(ev, "It wants a session. I haven't found one yet.")
		return
	for f in FOLDER_ORDER:
		if state.filed[f] == "":
			strip_text = STRIP_INCOMPLETE
			_say(ev, "Three folders. One record each.")
			return
	var first := ""
	for f in FOLDER_ORDER:
		var rec: String = state.filed[f]
		if RECORD_FOLDER[rec] != f:
			if first == "":
				first = MISMATCH["%s/%s" % [rec, f]]
			state.tray.append(rec)
			state.filed[f] = ""
	if first != "":
		strip_text = STRIP_CATEGORY
		_sfx(ev, "compare_refuse")
		_say(ev, first)
		_say(ev, "The tray has them.", 1.4)
		return
	if not date_is(SESSION):
		strip_text = STRIP_DATE
		_sfx(ev, "compare_refuse")
		_say(ev, "Not the session date.")
		if date_is(NOT_YET):
			strip_text = STRIP_NOT_YET
			_say(ev, "Not yet.", 1.6)
			if not state.not_yet_seen:
				state.not_yet_seen = true
				_observe("not_yet")
		return
	_solve_p18(ev)

func _solve_p18(ev: Array) -> void:
	state.p18_complete = true
	game.solve("P18", ev)
	for f in FOLDER_ORDER:
		state.filed[f] = ""
	for rec in RECORDS:
		game.give(rec, ev)
	state.staff_open = true
	state.drawer_open = true
	game.give("venn_correspondence", ev)
	_observe("index_protocol")
	_observe("venn_drawer_open")
	strip_text = STRIP_COMPLETE
	# Staged in c_folders: the flaps shut on her records, the STAFF drawer is heard, she pulls
	# the release and they come back; then the glance shows STAFF and Venn's drawer.
	_sfx(ev, "strip_print", 0.2)
	_fx(ev, "index_close", {"delay": 0.8})
	_sfx(ev, "index_close", 0.8)
	_say(ev, P18_SHUT, 1.0, true)
	_sfx(ev, "tabs_riffle", 4.2)
	_fx(ev, "riffle", {"delay": 4.2})
	_say(ev, P18_STAFF, 4.4, true)
	_fx(ev, "release", {"delay": 7.6})
	_sfx(ev, "release_lever", 7.6)
	_say(ev, P18_RELEASE, 7.6, true)
	_sfx(ev, "records_return", 8.4)
	_fx(ev, "records_back", {"delay": 8.4})
	_sfx(ev, "drawer_self", 9.4)
	_sfx(ev, "letters_take", 10.4)
	_fx(ev, "glance", {"rect": GLANCE_DRAWER.duplicate(), "target": "correspondence_drawer",
		"also": GLANCE_STAFF.duplicate()})

# ---------------------------------------------------------------------------------------------
# P23: c_model
# ---------------------------------------------------------------------------------------------
func _model(action: String, ev: Array) -> void:
	if not shutter_open():
		_say(ev, SHUTTER_LINE)
		_observe("model_shutter")
		return
	match action:
		"faceplate":
			_say(ev, FACEPLATE)
			_observe("faceplate")
			return
		"stamp":
			match str(state.stamp):
				"closed":
					_say(ev, "CLOSED.")
				"open":
					_say(ev, "OPEN. In ink.")
				_:
					_say(ev, "Nothing stamped.")
			return
		"strip":
			var lines := model_lines()
			_say(ev, " ".join(lines) if not lines.is_empty() else "Blank.")
			return
		"shutter":
			_say(ev, "The shutter's back. Someone opened it from the other side.")
			return
		"test":
			_test(ev)
			return
		"reset":
			_reset(ev)
			return
	if state.stamp == "open":
		if action == "bridge":
			_say(ev, "The bridge is with me. It's warm.")
		else:
			_say(ev, "It's stamped OPEN. I'll leave the leads as they are.")
		return
	match action:
		"bridge":
			_say(ev, "A bridge seated across the circle. It doesn't come out.")
		"t_input":
			state.input = not state.input
			if state.input:
				_sfx(ev, "lead_plug")
				_say(ev, "The lead in the triangle.")
			else:
				state.copy = false
				state.witness = false
				_sfx(ev, "lead_unplug")
				_say(ev, "Out of the triangle. The plugs come with it.")
		"t_copy", "t_witness":
			if not state.input:
				_say(ev, LEAD_START)
				return
			var key := "copy" if action == "t_copy" else "witness"
			state[key] = not state[key]
			_sfx(ev, "lead_plug" if state[key] else "lead_unplug")
			var word: String = GLYPH_WORDS[TERMINAL_GLYPHS[key]]
			_say(ev, ("A plug in %s." if state[key] else "Out of %s.") % word)
		"lead":
			state.input = false
			state.copy = false
			state.witness = false
			_sfx(ev, "lead_unplug")
			_say(ev, "I coil the lead.")

func _test(ev: Array) -> void:
	_sfx(ev, "test_key")
	if state.p23_complete:
		model_text = STRIP_RECORD_OPEN
		_say(ev, "It took the line. It's still open.")
		return
	if state.stamp == "closed":
		_say(ev, "It's stamped CLOSED. RESET first.")
		return
	if not state.input or not (state.copy or state.witness):
		model_text = STRIP_NO_INPUT
		_say(ev, "No input.")
		return
	if state.copy:
		# Teaching by failure: the copy appends the amendment and closes the record, and the
		# vault answers. Reversible with RESET; never P23.
		state.stamp = "closed"
		model_text = STRIP_CLOSED
		_fx(ev, "print_closed", {"text": STRIP_CLOSED, "delay": 0.0})
		_sfx(ev, "strip_print", 0.1)
		_sfx(ev, "stamp_closed", 0.3)
		_fx(ev, "stamp_closed", {"delay": 0.3})
		_say(ev, "CLOSED.")
		_sfx(ev, "staff_slam", 1.2)
		_fx(ev, "staff_slam", {"delay": 1.2})
		_fx(ev, "photos_blank", {"delay": 1.2})
		_say(ev, "Behind me every drawer in the catalogue knocks at once. The stripe has stopped.", 1.3, true)
		_say(ev, "The copy answered for her. That's what it did to them.", 3.0, true)
		_observe("model_closed_test")
		return
	state.stamp = "open"
	state.p23_complete = true
	game.solve("P23", ev)
	state.bridge_taken = true
	game.give("witness_bridge", ev)
	state.strip2 = true
	model_text = STRIP_OPEN
	_observe("witness_test")
	_observe("aperture_wider")
	_fx(ev, "print", {"text": STRIP_OPEN, "delay": 0.0})
	_sfx(ev, "strip_print", 0.3)
	_fx(ev, "stamp_open", {"delay": 1.0})
	_sfx(ev, "stamp_open", 1.0)
	_say(ev, "It took the line. It stays open.", 1.4, true)
	_fx(ev, "aperture_wider", {"delay": 3.6})
	_sfx(ev, "staff_settle", 3.6)
	_say(ev, "Behind the model, the stripe up from STAFF is wider than it was. Nothing touched it.", 3.8, true)
	_sfx(ev, "bridge_lift", 7.0)
	_fx(ev, "bridge_free", {"delay": 7.0})
	_say(ev, "The bridge has come free of the circle. I lift it out.", 7.0, true)
	_say(ev, "It's warm. My temperature, exactly.", 9.6, true)
	_fx(ev, "print2", {"text": STRIP_WITNESS, "delay": 12.0})
	_sfx(ev, "strip_print", 12.0)
	_say(ev, "It's printed another line. WITNESS: MERCER, A.", 12.2, true)
	_fx(ev, "glance", {"rect": GLANCE_STAFF.duplicate(), "target": "staff_drawer"})

func _reset(ev: Array) -> void:
	match str(state.stamp):
		"closed":
			state.stamp = ""
			model_text = ""
			_sfx(ev, "reset_key")
			_say(ev, "RESET. Open again. Just like that.")
		"open":
			_say(ev, STAMPED_OPEN)
		_:
			_say(ev, "Nothing to reset.")

# ---------------------------------------------------------------------------------------------
# inventory
# ---------------------------------------------------------------------------------------------
func use_item(item: String, target: String, ev: Array) -> bool:
	_sync()
	if target.begins_with("go:"):
		return false
	if item == "venn_correspondence":
		_say(ev, "These belong on the office board.")
		return true
	var in_contact: bool = local_view == "c_contact" and target in CONTACT_CONTROLS
	var in_folders: bool = local_view == "c_folders" and target in FOLDER_CONTROLS
	var in_model: bool = local_view == "c_model" and target in MODEL_CONTROLS
	if item == "chart_clips" and (target == "contact_table" or (in_contact and (target == "clip"
			or target.begins_with("slot_")))):
		if target == "contact_table":
			_open_contact(ev)
		_clip(ev)
		return true
	if in_contact and target == "clip":
		_say(ev, CLIP_ONLY)
		return true
	if target in ["tray", "staff_drawer"] and (item in RECORDS or item in ["contact_sheet", "witness_bridge"]):
		if state.p18_complete:
			_say(ev, "I know what the tray is for now. No.")
			_observe("tray_for")
		else:
			_say(ev, "Not until I know what it's for.")
		return true
	match item:
		"inspection_lens":
			if target == "photographs":
				_say(ev, "Under the lens the retouching is brushwork on the emulsion. Fine, patient. Someone took a long time.")
				_observe("retouch")
				return true
			if in_contact or target == "contact_table":
				if state.p16_complete:
					_say(ev, "Venn. Younger. He's looking at the empty station, not the chairs.")
					_observe("venn_glass")
				else:
					_say(ev, "The faces are under the cover. The lens can't see through it.")
				return true
		"nora_frame", "nora_spatial_strip", "nora_register_card":
			if in_folders:
				if FOLDERS.has(target):
					_file(item, target, ev)
				elif target == "cmp_tray":
					_say(ev, "The tray takes what doesn't correspond. Records go in the folders.")
				else:
					_say(ev, "Records go in the folders.")
				return true
		"contact_sheet":
			if in_folders and (FOLDERS.has(target) or target == "compare" or target.ends_with("_up")
					or target.ends_with("_dn")):
				_say(ev, SHEET_DATE)
				return true
			if in_contact:
				_say(ev, "The sheet's already made. It's this table's.")
				return true
		"amended_nora_card":
			if in_folders and FOLDERS.has(target):
				_say(ev, "Not into Rook's folders again.")
				return true
		"witness_bridge":
			if in_model and target in ["t_witness", "bridge"] and state.p23_complete:
				_say(ev, "It's done its test. It belongs to the chamber now.")
				return true
	return false

# ---------------------------------------------------------------------------------------------
# state
# ---------------------------------------------------------------------------------------------
## Marks `n` and every older notice as seen, so an obsolete one never plays later.
func _mark_notice(n: String) -> void:
	var k := NOTICES.find(n)
	for i in k + 1:
		if not NOTICES[i] in state.notices:
			state.notices.append(NOTICES[i])

func _set_p16_done() -> void:
	state.slots = SOLUTION.duplicate()
	state.clipped = true
	state.cover_off = true
	state.p16_complete = true

func _set_p18_done() -> void:
	state.p18_complete = true
	state.staff_open = true
	state.drawer_open = true

func _set_p23_done() -> void:
	state.p23_complete = true
	state.stamp = "open"
	state.input = true
	state.witness = true
	state.copy = false
	state.bridge_taken = true
	state.strip2 = true

## Flags set elsewhere (tests, debug) pull the local arrangement along. Never clears anything
## and never gives items.
func _sync() -> void:
	if game.flag("P16") and not state.p16_complete:
		_set_p16_done()
	if game.flag("P18") and not state.p18_complete:
		_set_p18_done()
	if game.flag("P23") and not state.p23_complete:
		_set_p23_done()

func _clear_transient() -> void:
	held = ""
	edge_break = -1
	strip_text = ""
	model_text = ""

static func _whole(v: Variant, r: Array, fallback: int) -> int:
	if not _all_whole([v]) or v is bool:
		return fallback
	return clampi(int(v), r[0], r[1])

func load_state(d: Variant) -> void:
	state = initial_state()
	_clear_transient()
	if not d is Dictionary:
		return
	for key in SAVED_BOOLS:
		if d.get(key) is bool:
			state[key] = d[key]
	var sl = d.get("slots")
	if sl is Array and sl.size() == 4:
		var ok := true
		var used := []
		for s in sl:
			if not (s is String and (s == "" or s in PANELS)):
				ok = false
			elif s != "":
				ok = ok and not s in used
				used.append(s)
		if ok:
			state.slots = sl.duplicate()
	state.day = _whole(d.get("day"), DAY_RANGE, TODAY[0])
	state.month = _whole(d.get("month"), MONTH_RANGE, TODAY[1])
	state.year = _whole(d.get("year"), YEAR_RANGE, TODAY[2])
	state.wrap = _whole(d.get("wrap"), [0, 2], 0)
	var used_recs := []
	var fi = d.get("filed")
	if fi is Dictionary:
		for f in FOLDER_ORDER:
			var rec = fi.get(f)
			if rec is String and rec != "" and RECORD_FOLDER.has(rec) and not rec in used_recs:
				state.filed[f] = rec
				used_recs.append(rec)
	var tr = d.get("tray")
	if tr is Array:
		for rec in tr:
			if rec is String and RECORD_FOLDER.has(rec) and not rec in used_recs:
				state.tray.append(rec)
				used_recs.append(rec)
	var st = d.get("stamp")
	if st is String and st in ["", "closed", "open"]:
		state.stamp = st
	for pair in [["notices", NOTICES], ["catalogue_notices", CATALOGUE_NOTICES]]:
		var arr = d.get(pair[0])
		if arr is Array:
			for n in arr:
				if n is String and n in pair[1] and not n in state[pair[0]]:
					state[pair[0]].append(n)
	# Derived: later progress implies earlier progress and its arrangement.
	if state.p23_complete:
		state.p18_complete = true
	if state.p18_complete:
		state.cover_off = true
	if state.cover_off and not state.p16_complete:
		state.p16_complete = true
	if state.p16_complete:
		state.cover_off = true
	if state.cover_off:
		_set_p16_done()
	elif state.clipped and state.slots != SOLUTION:
		state.clipped = false
	if state.p18_complete:
		_set_p18_done()
	else:
		state.drawer_open = false
		state.wrap = 0
	if state.p23_complete:
		_set_p23_done()
	else:
		if state.stamp == "open":
			state.stamp = ""
		state.bridge_taken = false
		state.strip2 = false
		if not state.input:
			state.copy = false
			state.witness = false
	if not state.input:
		state.copy = false
		state.witness = false

## P16, P18 and P23 are R10's: a flag set elsewhere (tests, debug) is honoured, then the flags
## follow the state. A load always lands in "room", so Nora's records come out of the folders.
func reconcile() -> void:
	_sync()
	for f in FOLDER_ORDER:
		var rec: String = state.filed[f]
		if rec != "" and not game.has_item(rec):
			game.give(rec, [])
	for rec in state.tray:
		if not game.has_item(rec):
			game.give(rec, [])
	state.filed = {"BODY": "", "PLACE": "", "NAME": ""}
	state.tray = []
	game.set_flag("P16", state.p16_complete)
	game.set_flag("P18", state.p18_complete)
	game.set_flag("P23", state.p23_complete)

# ---------------------------------------------------------------------------------------------
# debug
# ---------------------------------------------------------------------------------------------
const A_SEEN := ["shelves", "vault_clock", "photographs", "index_file"]
const B_SEEN := ["staff_aperture", "staff_label", "staff_tray", "venn_drawer", "parcel", "model", "model_shutter"]
const P16_SEEN := ["contact_table", "panel_a", "panel_b", "panel_c", "panel_d", "contact_sheet_1927",
	"photos_turned"]
const P18_SEEN := ["folders", "protocol_card", "index_protocol", "venn_drawer_open"]
const P23_SEEN := ["faceplate", "witness_test", "aperture_wider"]

func _observe_all(ids: Array) -> void:
	for o in ids:
		_observe(o)

func _prep_p16() -> void:
	_set_p16_done()
	_observe_all(A_SEEN)
	_observe_all(P16_SEEN)
	if not game.has_item("contact_sheet"):
		game.give("contact_sheet", [])

func _prep_p18() -> void:
	_prep_p16()
	_set_p18_done()
	state.folders_seen = true
	_observe_all(B_SEEN)
	_observe_all(P18_SEEN)
	if not game.has_item("venn_correspondence"):
		game.give("venn_correspondence", [])

## The local state real play leaves at the start of tide `t`.
func debug_prepare(t: int) -> void:
	if t >= 7:
		_prep_p18()
	if t >= 9:
		_set_p23_done()
		_observe_all(P23_SEEN)
		if not game.has_item("witness_bridge"):
			game.give("witness_bridge", [])
	_prepare_notices()

## Every notice older than the current one is behind her; the current one still plays.
func _prepare_notices() -> void:
	var n := current_notice()
	var k := NOTICES.find(n) if n != "" else 1
	for i in k:
		if not NOTICES[i] in state.notices:
			state.notices.append(NOTICES[i])

## Dev stages: 1 tide VI fresh at the door, 2 panels B, D, A, C placed, 3 clipped, 4 P16 done,
## 5 three records filed (date still 17 OCT 1931), 6 P18 done (P17 not), 7 tide VIII fresh
## (shutter open), 8 P23 done, 9 tide IX.
func debug_jump(n: int) -> void:
	if n <= 6:
		game.debug_tide(6, ID)
		_mark_notice("shelves")
		if n >= 2:
			state.slots = SOLUTION.duplicate()
			_observe_all(["contact_table", "panel_a", "panel_b", "panel_c", "panel_d"])
		if n >= 3:
			state.clipped = true
		if n >= 4:
			_prep_p16()
			for rec in RECORDS:
				if not game.has_item(rec):
					game.give(rec, [])
		if n == 5:
			state.folders_seen = true
			_observe("folders")
		if n >= 6:
			_prep_p18()
		reconcile()
		if n == 5:
			# After reconcile, which empties the folders as a load does.
			for rec in RECORDS:
				game.take(rec)
				state.filed[RECORD_FOLDER[rec]] = rec
	elif n <= 8:
		game.debug_tide(8, ID)
		if n >= 8:
			_set_p23_done()
			_observe_all(P23_SEEN)
			if not game.has_item("witness_bridge"):
				game.give("witness_bridge", [])
		reconcile()
	else:
		game.debug_tide(9, ID)
		reconcile()
	local_view = "room"
	_clear_transient()
