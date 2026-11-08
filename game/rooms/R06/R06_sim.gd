class_name R06Sim
extends RoomSim
## R06, the Bunk Room. Owns P08 (four belongings back in their owners' lockers) and P22
## (amend Nora's register card without erasing it): docs/design/puzzle-cards/P08.md, P22.md
## and rooms.md R06. Node-free and deterministic; the view reads the helpers below and the
## transient vars (lifted, last_refusal), and plays the events.
##
## Two base views: "room" (A, the lockers and bunks) and "curtain" (B, the curtain wall; not a
## close-up). Close-ups: c_lockers (P08), c_slope (P22).

const ID := "R06"
const TITLE := "Bunk Room"
const REQUIRES := ["P06"]
const LOCKED := "The service door is locked. A tag on it: KITCHEN · BUNKS. The key went out with the launch."
const RESUME := "Back in the bunk room."
const ARRIVAL := "The bunk room. Eight beds made tight, four lockers standing open. Somewhere, bed springs settle, as if someone had just lain down."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R02", "Office", []],
	["R05", "Kitchen", []],
]

## View A (lockers and bunks) and view B (the curtain wall) hotspots.
const HOTSPOTS := ["belongings_shelf", "locker_bell", "locker_rook", "locker_venn", "locker_ives",
	"closed_lockers", "venn_bunk", "luggage", "to_curtain", "bunks"]
const CURTAIN_HOTSPOTS := ["ives_letter", "slope", "calendar", "pencil_shelf", "cup_shelf", "curtain",
	"bunks_b", "to_lockers"]
const CLOSEUPS := ["c_lockers", "c_slope"]

# --- P08: the belongings --------------------------------------------------------------------
const OBJECTS := ["cup", "calipers", "pencils", "glove"]
const LOCKERS := ["bell", "rook", "venn", "ives"]
const OWNER := {"cup": "bell", "calipers": "rook", "pencils": "venn", "glove": "ives"}
## The order on top of the locked lockers: a derangement of the locker order, never positional.
const TRAY_ORDER := ["pencils", "glove", "cup", "calipers"]
## The cards give habits; the objects must be handled (lifted, then turned over) to show the
## wear those habits leave. No card names its object.
const CARD_TEXT := {
	"bell": ["N. Bell.", "Takes her tea without sugar.", "Was given three new cups. Kept none of them."],
	"rook": ["Dr S. Rook.", "Measures everything twice.", "Trusts no instrument he has not altered."],
	"venn": ["E. Venn.", "Writes from the left of the page.", "Was issued two pencils. Requisitioned two more."],
	"ives": ["T. Ives.", "Lost the feeling in two fingertips to the winch.", "Will not take a new issue of anything he can sew."],
}
## The second click on a lifted belonging: turned over in the hand.
const WEAR_LINES := {
	"cup": "A cup with a brass staple through the handle where it broke. Mended, not replaced. N.B. scratched small under the foot.",
	"calipers": "Calipers. One jaw has been filed down by hand, carefully.",
	"pencils": "A tin pencil holder, four slots, worn bright on the left side only.",
	"glove": "A right glove, restitched in red thread at two fingertips.",
}
const SHORT_NAMES := {"cup": "The cup.", "calipers": "The calipers.", "pencils": "The pencil holder.",
	"glove": "The glove."}
## The first click: lifted, seen from one side. Only the short name and one neutral clause.
const LIFT_LINES := {"cup": "The cup. Brass glints at the handle.", "calipers": "The calipers. One jaw looks wrong.",
	"pencils": "The pencil holder. Tin.", "glove": "The glove. A right glove."}
const PLACED_LINES := {"bell": "Her cup, on Bell's shelf.", "rook": "His calipers, on Rook's shelf.",
	"venn": "His pencils, on Venn's shelf.", "ives": "His glove, on Ives's shelf."}
const RIGHT_LINES := {
	"cup": "Three new cups, and she kept none of them. She kept this one. Bell's.",
	"calipers": "Altered by his own hand. Rook's.",
	"pencils": "Two issued, two more requisitioned, worn from the left. Venn's.",
	"glove": "Red thread at two fingertips. Sewn, not reissued. Ives's.",
}
const WRONG := {
	"cup": {
		"rook": "A brass staple through a broken handle. Rook alters instruments. A cup isn't one.",
		"venn": "A stapled cup. Venn's card is the left of the page and two pencils, then two more.",
		"ives": "Ives sews what he won't have reissued. A brass staple isn't sewing. This is someone given three new cups who kept none of them.",
	},
	"calipers": {
		"bell": "One jaw filed down by hand. Bell's card is cups she wouldn't take. This is an instrument someone altered.",
		"venn": "A filed jaw. Venn's card is pencils and the left of the page. These belong to someone who trusts no instrument he hasn't altered.",
		"ives": "A jaw filed fine. Ives can't feel two fingertips, and he sews; he doesn't file.",
	},
	"pencils": {
		"bell": "Four slots, worn bright on the left. Bell's card is tea and cups.",
		"rook": "Four slots, worn on the left side. Two issued, two requisitioned, written from the left of the page. Not Rook.",
		"ives": "Four pencil slots, left side worn bright. Ives's card is what he can sew.",
	},
	"glove": {
		"bell": "Red thread at two fingertips. Bell's card is cups. This was sewn by someone who won't take a new issue.",
		"rook": "Restitched in red thread. Rook alters instruments; this is a hand the winch took two fingertips from.",
		"venn": "A right glove, red thread at two fingertips. Venn's card is pencils and the left of the page.",
	},
}
const ALREADY_HOME := "Something's already home there."
const ITS_HOME := "It's home."
const EMPTY_SHELF := "An empty shelf. A clean square in the dust where something stood."

# --- the beds -------------------------------------------------------------------------------
## A: venn, rook, hart, ives. B: doane, lusk, tull, bell.
const BEDS := ["venn", "rook", "hart", "ives", "doane", "lusk", "tull", "bell"]
## The order the hollows appear in.
const DENT_ORDER := ["venn", "doane", "bell", "ives", "rook", "lusk", "hart", "tull"]

# --- P22: the writing slope -----------------------------------------------------------------
const FINDINGS := ["NO SURVIVING EFFECTS", "PERSONAL EFFECT IDENTIFIED", "EFFECT NOT VERIFIED"]
const WHEEL_OBJECTS := ["CALIPERS", "PENCIL HOLDER", "GLOVE", "REPAIRED CUP"]
const OWNERS := ["S. ROOK", "E. VENN", "T. IVES", "NORA BELL"]
const WHEELS := [FINDINGS, WHEEL_OBJECTS, OWNERS]
## The engraved plate under each drum's window, in WHEELS order.
const WHEEL_LABELS := ["FINDING", "OBJECT", "OWNER"]
## A drum shows its word in the window, the previous word half above it and the next word half
## below it. ▷ (WHEEL_NEXT) turns the drum so the word below comes up into the window; ◁ brings
## the word above down. wheel_neighbour() is what the view draws, so motion and labels agree.
const WHEEL_NEXT := 1
const WHEEL_SOLUTION := [1, 3, 3]
const REGISTER_TEXT := ["BELL, N.", "Cook and caretaker.", "No surviving personal effects."]
const REGISTER_STAMP := "SPECIMEN 27-11"
const AMEND_TEXT := "PERSONAL EFFECT IDENTIFIED / REPAIRED CUP / NORA BELL"
const SKETCH_TEXT := "Cup, mine, mended 3 Feb."
const ERASE_REFUSAL := "No. Corrections append. The original stands, and so does this."
const ERASE_NOTHING := "There's nothing on the rest to erase."
const APPEND_REFUSALS := {
	"done": "It's already amended.",
	"no_card": "There's no record on the rest to amend.",
	"no_p21": "I could write it. I don't know yet what this card is part of.",
	"no_sketch": "I need the evidence beside it, or it's only my word.",
	"finding_same": "That's what the card already says. A correction has to add something.",
	"finding_unverified": "'Not verified.' I have verified it. The sketch and the cup agree.",
	"object": "The evidence on the rest is a cup. The correction has to say what the evidence shows.",
	"owner": "This is Nora's record. The correction names her.",
}
## Ada's pencil: corrections are written in the amending officer's own hand (flags.md section 4,
## a durable Tide I item from the office, never taken).
const PENCIL := "pencil"
const NO_PENCIL := "Corrections are in the amending officer's hand. Mine."
const AMEND_LINE := "REPAIRED CUP, NORA BELL"
## Glances: a look across the room at something that just changed, as {id, rect, view}. Rects are
## in the room view's native canvas; view is the wall they are on ("room" A, "curtain" B).
const GLANCES := {
	"p08_latch": {"rect": Rect2(706, 524, 96, 84), "view": "curtain"},   # the pigeonhole
	"p22_cup": {"rect": Rect2(52, 420, 92, 150), "view": "room"},        # Bell's cup, steaming
}
const WHEEL_CONTROLS := {"fin_prev": [0, -WHEEL_NEXT], "fin_next": [0, WHEEL_NEXT],
	"obj_prev": [1, -WHEEL_NEXT], "obj_next": [1, WHEEL_NEXT], "own_prev": [2, -WHEEL_NEXT],
	"own_next": [2, WHEEL_NEXT]}

# --- the calendar ---------------------------------------------------------------------------
const CALENDAR_DATES := ["11", "12", "13", "14", "15", "16", "17", "18"]
const CAL_ROTA := ["Hart", "Ives", "Venn", "Doane", "Pryce", "Lusk", "Tull", "Venn"]
const CAL_INDEX := ["ROOK", "BELL", "IVES", "LUSK", "PRYCE", "DOANE", "HART", "TULL"]
const CAL_HEADER := "NIGHT WATCH · OCTOBER"

# --- escalation -----------------------------------------------------------------------------
## First-time arrival holds, oldest first. Seeing one retires every older one.
const NOTICES := ["pillow", "names_moved", "doane", "curtain_shape", "four", "every_bed", "her_name", "rise"]
const NOTICE_VIEW := {"pillow": "room", "names_moved": "curtain", "doane": "curtain",
	"curtain_shape": "curtain", "four": "room", "every_bed": "room", "her_name": "curtain", "rise": "room"}
const NOTICE_LINES := {
	"names_moved": "The calendar. The names have moved.",
	"doane": "Doane's bunk. A hollow, under the pencil shelf.",
	"curtain_shape": "The curtain. Something is standing behind it.",
	"four": "Four now. Venn, Doane, Bell. Ives.",
	"every_bed": "Every bed.",
	"her_name": "My name is on the calendar.",
	"rise": "The hollows are filling. One by one, slowly, like breath let out.",
}
const NOTICE_EVIDENCE := {"names_moved": "calendar_index", "doane": "dent_doane",
	"curtain_shape": "curtain_shape", "four": "dents_four", "every_bed": "dents_eight",
	"her_name": "calendar_mercer"}
const NOTICE_SFX := {"curtain_shape": ["curtain_rings", 0.6], "every_bed": ["springs_eight", 0.4],
	"rise": ["dents_rise", 0.8]}
const PILLOW_LINE := "Venn's pillow. There's a dent in it, as if someone had just laid their head down."

const LETTER := [
	["A letter in the pigeonhole, half written. 'Greywake, 16th Oct. Dear Ma, the weather here you would not credit. The rain comes sideways and the sea comes up the jetty to see who's in.'", 0.0],
	["'My fingers are better, mostly. Don't fuss. The food is what I'll miss. Mrs Bell does a fish soup that would make you weep, and she counts us in at the door every night, whoever's sat down.'", 4.6],
	["'Dr Rook says on Tuesday we're all to be measured for the new survey. I'll write after and tell you how tall I'", 9.6],
	["It stops in the middle of the word.", 14.2],
]

const OBSERVATIONS := {
	"arrival_springs": "Bed springs settled in an empty room the first time I came in.",
	"lockers": "Four open lockers: BELL, ROOK, VENN, IVES. A personal card in a brass holder on each, and a bare shelf inside.",
	"closed_lockers": "Four more lockers, shut and labelled: LUSK, DOANE, HART, TULL. No locker or bed for Pryce.",
	"belongings": "Four things on top of the locked lockers, in this order: a pencil holder, a glove, a cup, a pair of calipers. No names on them.",
	"card_bell": "Card, BELL: 'N. Bell. Takes her tea without sugar. Was given three new cups. Kept none of them.'",
	"card_rook": "Card, ROOK: 'Dr S. Rook. Measures everything twice. Trusts no instrument he has not altered.'",
	"card_venn": "Card, VENN: 'E. Venn. Writes from the left of the page. Was issued two pencils. Requisitioned two more.'",
	"card_ives": "Card, IVES: 'T. Ives. Lost the feeling in two fingertips to the winch. Will not take a new issue of anything he can sew.'",
	"wear_cup": "The cup: a brass staple through the broken handle. N.B. under the foot.",
	"wear_calipers": "The calipers: one jaw filed down by hand.",
	"wear_pencils": "The pencil holder: four slots, worn bright on the left side.",
	"wear_glove": "The glove: a right glove, restitched in red thread at two fingertips.",
	"personal_cards": "Bell: tea without sugar; given three new cups, kept none of them. Rook: measures twice; trusts no instrument he has not altered. Venn: writes from the left of the page; two pencils issued, two more requisitioned. Ives: two fingertips lost to the winch; won't take a new issue of anything he can sew.",
	"venn_seal": "Venn's personal seal: three cuts.",
	"compartment": "The back of Venn's locker dropped away. Behind it, the locker goes on further than the wall it stands against.",
	"venn_bunk": "Venn's bunk, the lower one, ROOK above. The blanket folded square at the foot.",
	"venn_dent": "After the lockers, the next time I came back, Venn's pillow had a dent in it, as if a head had just been laid there. It stays.",
	"bunks_a": "This side: ROOK over VENN, HART over IVES.",
	"bunks_b": "Behind the curtain: LUSK over DOANE, TULL over BELL. Eight beds, eight lockers.",
	"luggage": "Suitcases under the bunks. No labels, no tags, no initials. Never collected.",
	"curtain": "A curtain partition on a ceiling rail. It sways when I breathe out. Then once more, when I don't.",
	"curtain_shape": "The curtain hangs as if someone stood behind it, close, taller than me. Pulled aside: nobody. It has stopped swaying.",
	"calendar_rota": "Night-watch calendar, October 11-18: Hart, Ives, Venn, Doane, Pryce, Lusk, Tull, Venn. Printed dates, names in different hands. Venn took the 18th.",
	"calendar_index": "The calendar's names changed. Same dates, one hand: Rook, Bell, Ives, Lusk, Pryce, Doane, Hart, Tull. The eight. Venn isn't on it.",
	"calendar_mercer": "The calendar's names are gone. One line under the 18th, today: A. MERCER.",
	"pencil_shelf": "Venn screwed a pencil shelf under the top bunk, over Doane's pillow. She wrote lying down.",
	"cup_shelf": "A bracket shelf over Bell's bunk: an old dry ring, N.B. in pencil.",
	"cup_ring_match": "The dry ring over Bell's bunk is the size of the cup's foot. She kept her cup by her bed.",
	"pigeonhole": "A latched pigeonhole in the back of the writing slope. No keyhole.",
	"ives_letter": "Ives, to his mother, 16 Oct: sideways rain, the sea coming up the jetty; his fingers better, mostly; Mrs Bell's fish soup, and how she counts them in every night, whoever's sat down. 'Dr Rook says on Tuesday we're all to be measured for the new survey. I'll write after and tell you how tall I' It stops in the middle of a word.",
	"slope": "A writing slope for comparing two documents: a RECORD rest, an EVIDENCE rest, and an amendment line with three wheels.",
	"register_card": "Nora's register card: 'BELL, N. Cook and caretaker. No surviving personal effects.' Stamped SPECIMEN 27-11.",
	"sketch_laid": "I laid my copy of Nora's sketch on the evidence rest: 'Cup, mine, mended 3 Feb.' The same staple.",
	"card_vs_cup": "Her card says no surviving personal effects. Her cup is in her locker.",
	"nora_amendment": "'No surviving personal effects.' Amended, in my hand: personal effect identified, repaired cup, Nora Bell.",
	"card_ring": "A ring of condensation came up on the corner of her amended card while it lay on the rest, the size of her cup's foot.",
	"cup_warm": "After the amendment Nora's cup was warm, a dry ring under it, as if it had just been put down. Tea without sugar.",
	"dent_doane": "A second hollow, in Doane's bunk, under the pencil shelf.",
	"dents_four": "Four hollows now: Venn, Doane, Bell, Ives.",
	"dents_eight": "Every bed has a hollow in it. Eight. Every bed occupied by nothing.",
}
const OBJECTIVES := {
	"p08": "Put the four belongings back in their owners' lockers.",
	"p22": "Correct Nora's register card without erasing it.",
	"away": "Nothing here needs me yet. The beds keep what they keep.",
	"done": "Her card is amended. The bunk room is finished with me.",
	"take_card": "Take Nora's amended card off the writing slope.",
	"card_on_slope": "Take Nora's register card back off the writing slope.",
}
const HINTS := {
	"p08": [
		"Four belongings, four open lockers, and a card on each door.",
		"Each card names a habit. Lift each object and turn it over: it shows the wear that habit leaves.",
		"Three new cups, kept none: mended, not replaced. An instrument he altered: a filed jaw. Writes from the left: worn on the left. Won't take a new issue: sewn.",
		"Cup to Bell, calipers to Rook, pencil holder to Venn, glove to Ives.",
	],
	"p22": [
		"Nora's register card says something the bunk room can contradict.",
		"Her cup is a personal effect. Corrections are added, never written over.",
		"Her book in the kitchen draws the same cup: 'Cup, mine, mended 3 Feb.' Her card on the RECORD rest, my copy of that sketch on the EVIDENCE rest.",
		"Put her card and the cup sketch on the slope, set the wheels to 'personal effect identified / repaired cup / Nora Bell', and APPEND with my pencil.",
	],
	"away": [
		"Nothing in the bunk room is waiting on me.",
		"The beds keep what they keep. Something elsewhere comes first.",
		"Come back when I have a record of Nora's that needs correcting.",
	],
	"card_on_slope": [
		"Nora's register card is still on the writing slope.",
		"I left it on the RECORD rest. Other records need it before it can be amended.",
		"Open the writing slope and step back from it: her card comes with me.",
	],
	"take_card": [
		"Her card is still on the writing slope.",
		"The amendment is written. The card goes with me, not on the rest.",
		"Open the writing slope and step back from it: I take her amended card with me.",
	],
	"done": [
		"The bunk room has given what it had.",
		"Her card is amended. It goes where records go.",
		"Nothing more to do here.",
	],
}
## Items this room hands out (docs/design/puzzle-cards/flags.md section 4).
const ITEMS := {
	"token_bunk_half": {"name": "Service token, bunk half", "desc": "Half of a split brass service token.",
		"short": "Bunk half"},
	"amended_nora_card": {"name": "Register card: Nora Bell (amended)", "desc": "Nora's register card, with the amendment in Ada's hand.",
		"short": "Nora (amended)"},
}

const SAVED_BOOLS := ["p08_complete", "pillow_dented", "letter_read", "card_on_rest", "sketch_on_rest",
	"p22_complete", "cup_warm_seen", "rise_seen"]

## Transient, never saved: the belonging held in c_lockers, and the last refused pairing
## ("cup>rook") for the view's highlight.
var lifted := ""
var last_refusal := ""
## Transient: the lifted belonging has been turned over in the hand (its wear seen).
var turned := ""

func initial_state() -> Dictionary:
	return {
		"placed": {"bell": "", "rook": "", "venn": "", "ives": ""},
		"p08_complete": false, "pillow_dented": false, "letter_read": false,
		"card_on_rest": false, "sketch_on_rest": false, "wheels": [0, 0, 0],
		"p22_complete": false, "cup_warm_seen": false, "rise_seen": false, "notices": [],
	}

func is_closeup(v := local_view) -> bool:
	return v in CLOSEUPS

func objective() -> String:
	_sync()
	if not state.p08_complete:
		return "p08"
	if state.p22_complete:
		return "take_card" if state.card_on_rest else "done"
	if game.flag("P21"):
		return "p22"
	if state.card_on_rest:
		# laid before P21 and kept there by a save: other records (P14, P18) still need it
		return "card_on_slope"
	return "away"

## The hint ladder's height for the current objective: P08 and P22 have an evidence tier
## (nudge, relationship, evidence, solution); the rest have three.
func hint_tiers() -> int:
	return (HINTS.get(objective(), []) as Array).size()

# ---------------------------------------------------------------------------------------------
# view helpers (read-only)
# ---------------------------------------------------------------------------------------------
func band() -> int:
	return game.weather_band()

func ending() -> String:
	return str(game.value("ending_choice"))

## The object on `locker`'s shelf, or "".
func placed_in(locker: String) -> String:
	return str(state.placed.get(locker, ""))

## The belongings still on top of the locked lockers, in their tray order.
func tray_objects() -> Array:
	var out := []
	for o in TRAY_ORDER:
		if _locker_of(o) == "":
			out.append(o)
	return out

func compartment_open() -> bool:
	return state.p08_complete

func pigeonhole_open() -> bool:
	return state.p08_complete

func cup_marked() -> bool:
	return state.p08_complete

func cup_steam() -> bool:
	return state.p22_complete and ending() != "sever"

func dry_ring() -> bool:
	return state.p22_complete

## The beds with a hollow in them (BEDS ids), in the order they appeared.
func dents() -> Array:
	if ending() == "sever":
		return []
	var b := band()
	if b >= 6:
		return DENT_ORDER.duplicate()
	var out := []
	if state.pillow_dented:
		out.append("venn")
	if b >= 3:
		out.append("doane")
	if b >= 5:
		out.append("bell")
		out.append("ives")
	return out

## After the sever ending, the first time back: the view animates every hollow filling.
func dents_rising() -> bool:
	return ending() == "sever" and not state.rise_seen

func curtain_shape() -> bool:
	return band() >= 4 and ending() != "sever"

## The curtain sways with her breath, until something stands behind it.
func curtain_sways() -> bool:
	return not curtain_shape()

## The eight names under CALENDAR_DATES.
func calendar_names() -> Array:
	var e := ending()
	if e == "sever":
		return CAL_ROTA.duplicate()
	var b := band()
	if b == 7 or e == "continue":
		var out := ["", "", "", "", "", "", "", ""]
		out[7] = "A. MERCER"
		return out
	if b >= 2 and b <= 6:
		return CAL_INDEX.duplicate()
	return CAL_ROTA.duplicate()

## Whose hand the names are in: "many" (the rota), "index" (one hand), "ada" (hers).
func calendar_hand() -> String:
	var e := ending()
	if e == "sever":
		return "many"
	if e == "continue":
		return "ada"
	var b := band()
	if b >= 2:
		return "index"
	return "many"

func wheel_text(i: int) -> String:
	return wheel_neighbour(i, 0)

## The word on drum `i` at `side`: 0 in the window, -1 half above it, +1 half below it. ▷ brings
## the +1 word into the window (WHEEL_NEXT).
func wheel_neighbour(i: int, side: int) -> String:
	if i < 0 or i >= WHEELS.size():
		return ""
	var w: Array = WHEELS[i]
	var at := clampi(int(state.wheels[i]), 0, w.size() - 1)
	return str(w[posmod(at + side * WHEEL_NEXT, w.size())])

func amendment_written() -> bool:
	return state.p22_complete

## The painted plate set: s1 (bands 0-1), s2 (2-3), s3 (4-5), s4 (6-7, and continue), sever.
func plate_stage() -> String:
	if ending() == "sever":
		return "sever"
	var b := band()
	if b <= 1:
		return "s1"
	if b <= 3:
		return "s2"
	if b <= 5:
		return "s3"
	return "s4"

## The wall a notice's arrival hold shows: "room" (A) or "curtain" (B).
func notice_view(n: String) -> String:
	return str(NOTICE_VIEW.get(n, "room"))

## The escalation notice due now (a NOTICES id), or "".
func current_notice() -> String:
	if dents_rising():
		return "rise"
	if ending() != "":
		return ""
	match band():
		7:
			return "her_name"
		6:
			return "every_bed"
		5:
			return "four"
		4:
			return "curtain_shape"
		3:
			return "doane"
		2:
			return "names_moved"
	return ""

# ---------------------------------------------------------------------------------------------
# entry points
# ---------------------------------------------------------------------------------------------
func arrive(ev: Array, first: bool) -> void:
	_sync()
	lifted = ""
	turned = ""
	last_refusal = ""
	if first:
		_say(ev, ARRIVAL)
		_sfx(ev, "springs_settle", 1.2)
		_observe("arrival_springs")
	if state.p08_complete and not state.pillow_dented:
		state.pillow_dented = true
		_fx(ev, "notice_pillow")
		_sfx(ev, "spring_creak", 0.4)
		_say(ev, PILLOW_LINE, 1.2, true)
		_observe("venn_dent")
		_mark_notice("pillow")
		return
	var n := current_notice()
	if n != "" and not n in state.notices:
		# The wall a notice is on is the view's arrival hold (NOTICE_VIEW, carried on the fx):
		# local_view stays "room" so the exits stay live (the core only travels from "room").
		ev.append({"type": "fx", "id": "notice_" + n, "view": NOTICE_VIEW[n]})
		_mark_notice(n)
		if NOTICE_EVIDENCE.has(n):
			_observe(NOTICE_EVIDENCE[n])
		if NOTICE_SFX.has(n):
			_sfx(ev, NOTICE_SFX[n][0], NOTICE_SFX[n][1])
		# Feedback lines, as in R04: a story chain here would hold the next room's lines and
		# the Hint behind it when she walks straight on (tests/core_test.gd walks every room).
		_say(ev, NOTICE_LINES[n], 1.6)
		if n == "every_bed":
			_say(ev, "Eight of them settled. One at a time.", 6.2)
		if n == "rise":
			state.rise_seen = true

func exit_block(_to: String) -> String:
	return ""

func back(ev: Array) -> void:
	_sync()
	match local_view:
		"c_lockers":
			lifted = ""
			turned = ""
			local_view = "room"
		"c_slope":
			_lift_card(ev)
			state.sketch_on_rest = false
			if state.p22_complete and not state.cup_warm_seen:
				state.cup_warm_seen = true
				local_view = "room"
				_fx(ev, "notice_cup")
				_glance(ev, "p22_cup")
				_say(ev, "Her cup is warm. There's a dry ring under it, as if it had just been put down.", 0.6, true)
				_say(ev, "Tea without sugar. I'd have guessed sugar.", 3.0, true)
				_observe("cup_warm")
			else:
				local_view = "curtain"
		_:
			local_view = "room"

func act(action: String, ev: Array) -> void:
	_sync()
	if local_view == "c_lockers" and _lockers(action, ev):
		return
	if local_view == "c_slope" and _slope(action, ev):
		return
	if action in HOTSPOTS:
		lifted = ""
		turned = ""
		local_view = "room"
		_room(action, ev)
	elif action in CURTAIN_HOTSPOTS:
		lifted = ""
		turned = ""
		local_view = "curtain"
		_curtain(action, ev)

func use_item(item: String, target: String, ev: Array) -> bool:
	_sync()
	var on_slope := target in ["slope", "rest_record", "rest_evidence"]
	match item:
		"token_bunk_half":
			_say(ev, "The other half's in the kitchen. The token belongs in the service board there.")
			return true
		"nora_register_card":
			if target in ["rest_record", "slope"] and not state.p22_complete and not state.card_on_rest:
				local_view = "c_slope"
				game.take("nora_register_card")
				state.card_on_rest = true
				_sfx(ev, "card_lay")
				_say(ev, "Her register card. 'No surviving personal effects.' Stamped " + REGISTER_STAMP + ".")
				_observe("register_card")
				return true
			if target in ["locker_bell", "shelf_bell"]:
				if state.p08_complete:
					_say(ev, "Her card says no surviving personal effects. Her cup is sitting right here.")
					_observe("card_vs_cup")
				else:
					_say(ev, "Her card says no surviving personal effects.")
				return true
		"nora_frame", "nora_spatial_strip":
			if on_slope:
				_say(ev, "That's a measurement of her. The slope is for her things.")
				return true
		"amended_nora_card":
			if on_slope:
				_say(ev, "It's amended. It stays amended.")
				return true
		"witness_bridge":
			if on_slope:
				_say(ev, "Not this. The bridge is for the chamber.")
				return true
		"pencil":
			if target == "printed_line":
				_erase(ev)
				return true
			if target in ["append", "amend_line"] and local_view == "c_slope":
				_append(ev, true)
				return true
			if target == "calendar":
				_say(ev, "I'm not writing on that. Something else does.")
				return true
		"inspection_lens":
			if target == "obj_cup":
				_say(ev, "Under the lens: N.B., scratched under the foot. Small and neat.")
				return true
			if target.begins_with("obj_") and target.substr(4) in OBJECTS:
				_say(ev, WEAR_LINES[target.substr(4)])
				_observe("wear_" + target.substr(4))
				return true
			if target == "venn_bunk" and "venn" in dents():
				_say(ev, "Under the lens the dent has the weave of a pillowcase pressed into it. Recent.")
				return true
			if target == "luggage":
				_say(ev, "No tag was ever tied on. No holes worn in the handles.")
				return true
			if target == "calendar" and band() >= 2:
				_say(ev, "Under the lens: pencil, and under the pencil the dents of other names pressed through.")
				return true
			if target == "curtain" and curtain_shape():
				_say(ev, "The shape is on the front of the cloth. There's no light behind it to cast it.")
				return true
	return false

# ---------------------------------------------------------------------------------------------
# view A: the lockers and bunks
# ---------------------------------------------------------------------------------------------
func _room(action: String, ev: Array) -> void:
	var e := ending()
	var b := band()
	match action:
		"belongings_shelf":
			local_view = "c_lockers"
			if state.p08_complete:
				_say(ev, "Bare. Everything went home.")
			else:
				_say(ev, "A pencil holder, a glove, a cup, calipers. Four things on top of the locked lockers, and four open lockers with nothing in them.")
				_observe("belongings")
		"locker_bell", "locker_rook", "locker_venn", "locker_ives":
			local_view = "c_lockers"
			_observe("lockers")
			if state.p08_complete:
				_say(ev, "Everything is home.")
			else:
				_say(ev, "BELL, ROOK, VENN, IVES. Four cards, four bare shelves.")
		"closed_lockers":
			_say(ev, "LUSK, DOANE, HART, TULL. Locked. Their keys hang inside on hooks; I can see them through the vents.")
			_observe("closed_lockers")
		"venn_bunk":
			if e == "sever":
				_say(ev, "The pillow is smooth again. Slowly, the way bread rises.")
			elif b >= 6:
				_say(ev, "His pillow, and every other pillow. All of them pressed.")
			elif state.pillow_dented:
				_say(ev, "The pillow has a dent in it, as if he'd just lain down. The pillowcase is cold.")
				_observe("venn_dent")
			else:
				_say(ev, "Venn's bunk, the lower one. The blanket folded square at the foot, the way he left everything. The pillow is smooth.")
				_observe("venn_bunk")
		"bunks":
			if e == "sever":
				_say(ev, "Flat. Every one.")
			elif b >= 6:
				_say(ev, "Rook, Hart, Ives, Venn. Every mattress has a hollow. The blankets haven't moved.")
				_observe("dents_eight")
			elif b == 5:
				_say(ev, "Ives's mattress has a hollow in it now. So does Venn's.")
				_observe("dents_four")
			else:
				var line := "ROOK over VENN, HART over IVES. Made tight. Dust on the blankets, undisturbed."
				if state.pillow_dented:
					line += " Only Venn's pillow has been touched."
				_say(ev, line)
				_observe("bunks_a")
		"luggage":
			if b >= 6:
				_say(ev, "The suitcases are where they were. Every bed above them is taken.")
			else:
				_say(ev, "Suitcases under the bunks. No labels, no tags, no initials. Packed, strapped, and never collected.")
			_observe("luggage")
		"to_curtain":
			local_view = "curtain"
			_sfx(ev, "turn_step")
			_say(ev, "The curtain wall.")

# ---------------------------------------------------------------------------------------------
# view B: the curtain wall
# ---------------------------------------------------------------------------------------------
func _curtain(action: String, ev: Array) -> void:
	var e := ending()
	var b := band()
	match action:
		"curtain":
			if e == "sever":
				_say(ev, "Just a curtain. It sways when I breathe out.")
			elif curtain_shape():
				_say(ev, "It hangs as if someone were standing behind it. Close. Taller than me. I pull it aside: nobody. I let it fall, and the shape is back.")
				_observe("curtain_shape")
			else:
				_say(ev, "A curtain partition on a ceiling rail. It sways a little when I breathe out. Then once more, when I don't.")
				_observe("curtain")
		"calendar":
			_sfx(ev, "calendar_page")
			if e == "sever":
				_say(ev, "The old rota, in their own hands again. Venn on the 18th.")
			elif e == "continue":
				_say(ev, "Under the 18th: A. Mercer. In my hand, now.")
			elif b == 7:
				_say(ev, "Every name is gone. One line under the 18th, today. A. MERCER.")
				_observe("calendar_mercer")
			elif b >= 2:
				_say(ev, "The dates are the same. The names have moved: Rook, Bell, Ives, Lusk, Pryce, Doane, Hart, Tull. One hand. Venn's gone off it.")
				_observe("calendar_index")
			else:
				_say(ev, "A night-watch calendar. October, the 11th to the 18th. Hart, Ives, Venn, Doane, Pryce, Lusk, Tull, and Venn again on the 18th. The names are in different hands.")
				_observe("calendar_rota")
		"pencil_shelf":
			var line := "A little shelf screwed under the top bunk, over Doane's pillow, with a groove for a pencil. Venn made it. She wrote lying down."
			if b >= 3 and e != "sever":
				line += " Under it, her pillow has a hollow in it now."
			_say(ev, line)
			_observe("pencil_shelf")
		"cup_shelf":
			if state.p22_complete:
				_say(ev, "The ring here is old and dry. The new one is in her locker, under the cup.")
			elif state.p08_complete:
				_say(ev, "The ring is the size of her cup's foot. She kept it by her bed, not in the kitchen.")
				_observe("cup_ring_match")
			else:
				_say(ev, "A bracket shelf over Bell's bunk. A dry ring on it, and N.B. in pencil beside it. Nothing stands there.")
				_observe("cup_shelf")
		"slope":
			local_view = "c_slope"
			_sfx(ev, "slope_lid")
			if state.p22_complete and state.card_on_rest:
				_say(ev, "Her card is still on the rest, amended in pencil under the printed line.")
			elif state.p22_complete:
				_say(ev, "The slope is clear. Her card, amended, is with me.")
			else:
				_say(ev, "A writing slope with two baize rests, RECORD and EVIDENCE, and a ruled amendment line beneath.")
			_observe("slope")
		"ives_letter":
			if not state.p08_complete:
				_say(ev, "A pigeonhole in the back of the slope, latched. No keyhole. Whatever opens it isn't here.")
				_observe("pigeonhole")
			elif not state.letter_read:
				_sfx(ev, "letter_unfold")
				for l in LETTER:
					_say(ev, l[0], l[1], true)
				state.letter_read = true
				game.set_flag("o03_found")
				_observe("ives_letter")
			else:
				_say(ev, "Ives's letter. 'I'll write after and tell you how tall I'. That's where it stops.")
		"bunks_b":
			if e == "sever":
				_say(ev, "Flat. Every one.")
			elif b >= 6:
				_say(ev, "Lusk, Doane, Tull, Bell. Every bed has someone in it, and nobody.")
				_observe("dents_eight")
			elif b == 5:
				_say(ev, "Doane's, and now Bell's. Hollows the size of a person lying still.")
				_observe("dents_four")
			elif b >= 3:
				_say(ev, "Doane's mattress has a hollow in it. Under the pencil shelf, where her head would be.")
				_observe("dent_doane")
			else:
				_say(ev, "LUSK over DOANE, TULL over BELL. Made tight, a little dust. The women's side of the curtain.")
			_observe("bunks_b")
		"to_lockers":
			local_view = "room"
			_sfx(ev, "turn_step")
			_say(ev, "The lockers.")

# ---------------------------------------------------------------------------------------------
# P08: c_lockers
# ---------------------------------------------------------------------------------------------
func _lockers(action: String, ev: Array) -> bool:
	if action == "venn_back":
		if not state.p08_complete:
			return false
		_say(ev, "The back of his locker is further away than the wall is. I don't put my hand in.")
		_observe("compartment")
		return true
	if action.begins_with("card_") and action.substr(5) in LOCKERS:
		var l := action.substr(5)
		_say(ev, " ".join(PackedStringArray(CARD_TEXT[l])))
		_observe(action)
		return true
	if action.begins_with("obj_") and action.substr(4) in OBJECTS:
		_lift(action.substr(4), ev)
		return true
	if action.begins_with("shelf_") and action.substr(6) in LOCKERS:
		_shelf(action.substr(6), ev)
		return true
	return false

func _lift(o: String, ev: Array) -> void:
	if _locker_of(o) != "":
		_say(ev, ITS_HOME)
		return
	if lifted == o and turned != o:
		# the second click: turned over in the hand
		turned = o
		_sfx(ev, "belonging_lift")
		_say(ev, WEAR_LINES[o])
		_observe("wear_" + o)
		return
	if lifted == o:
		lifted = ""
		turned = ""
		_sfx(ev, "belonging_set_down")
		return
	lifted = o
	turned = ""
	_sfx(ev, "belonging_lift")
	_say(ev, LIFT_LINES[o])

func _shelf(l: String, ev: Array) -> void:
	if lifted == "":
		var p := placed_in(l)
		_say(ev, PLACED_LINES[l] if p != "" else EMPTY_SHELF)
		return
	var o := lifted
	if placed_in(l) != "":
		_say(ev, ALREADY_HOME)
		return
	if OWNER[o] != l:
		lifted = ""
		turned = ""
		last_refusal = o + ">" + l
		_sfx(ev, "reject_set")
		_say(ev, WRONG[o][l])
		return
	if state.p08_complete:
		return
	state.placed[l] = o
	lifted = ""
	turned = ""
	last_refusal = ""
	_sfx(ev, o + "_set")
	_sfx(ev, "plate_click", 0.25)
	if _all_placed():
		_commit_p08(ev)
	else:
		_say(ev, RIGHT_LINES[o])

func _commit_p08(ev: Array) -> void:
	state.p08_complete = true
	game.solve("P08", ev)
	_say(ev, "The plate clicks. That's the last of them.", 0.3, true)
	_sfx(ev, "compartment_drop", 1.6)
	_fx(ev, "venn_open")
	_say(ev, "Something in Venn's locker dropped.", 1.8, true)
	_say(ev, "The back of it has fallen away. The locker goes on past where the wall should be.", 3.6, true)
	game.give("token_bunk_half", ev)
	_say(ev, "Half a brass token on a nail, and a rubbing pinned beside it. His seal: three cuts.", 6.0, true)
	_sfx(ev, "latch_small", 8.6)
	_fx(ev, "pigeonhole_open")
	_say(ev, "Across the room, something small unlatched.", 8.8, true)
	_glance(ev, "p08_latch")
	_observe("personal_cards")
	_observe("venn_seal")
	_observe("compartment")

# ---------------------------------------------------------------------------------------------
# P22: c_slope
# ---------------------------------------------------------------------------------------------
func _slope(action: String, ev: Array) -> bool:
	if WHEEL_CONTROLS.has(action):
		if state.p22_complete:
			return true
		var w: Array = WHEEL_CONTROLS[action]
		var i: int = w[0]
		var n: int = (WHEELS[i] as Array).size()
		state.wheels[i] = posmod(int(state.wheels[i]) + int(w[1]), n)
		_sfx(ev, "wheel_step")
		return true
	match action:
		"printed_line", "erase":
			_erase(ev)
		"rest_record":
			if state.card_on_rest:
				_lift_card(ev)
				_sfx(ev, "card_lay")
				_say(ev, "I take her card, amended." if state.p22_complete else "I take her card back.")
			elif state.p22_complete:
				_say(ev, "The rest is clear.")
			elif game.has_item("nora_register_card"):
				_say(ev, "The left rest is for the record being amended. Her card is in my bag.")
			else:
				_say(ev, "The left rest is for the record being amended.")
		"rest_evidence":
			if state.sketch_on_rest:
				state.sketch_on_rest = false
				_say(ev, "I take the sketch back.")
			elif state.p22_complete:
				_say(ev, "The rest is clear.")
			elif game.has_seen("R05", "nora_ledger"):
				state.sketch_on_rest = true
				_sfx(ev, "sketch_lay")
				_say(ev, "My copy of the sketch from her book. 'Cup, mine, mended 3 Feb.' The staple through the handle, drawn twice the size.")
				_observe("sketch_laid")
			else:
				_say(ev, "I've nothing to lay beside it. The kitchen has a book with her handwriting in it.")
		"append":
			_append(ev, false)
		"amend_line":
			if state.p22_complete:
				_say(ev, "Written. It reads under the printed line, in pencil.")
			else:
				_say(ev, "The amendment line: finding, object, owner. It writes under the printed line, not over it.")
		_:
			return false
	return true

func _erase(ev: Array) -> void:
	_sfx(ev, "erase_refuse")
	_say(ev, ERASE_REFUSAL if state.card_on_rest else ERASE_NOTHING)

## The first failing check for APPEND, or "" when the amendment can be written. The pencil is
## the last check: the wheels and the rests guide first; only then does her hand matter.
func append_refusal(with_pencil := true) -> String:
	if state.p22_complete:
		return "done"
	if not state.card_on_rest:
		return "no_card"
	if not game.flag("P21"):
		return "no_p21"
	if not state.sketch_on_rest:
		return "no_sketch"
	var w: Array = state.wheels
	if int(w[0]) == 0:
		return "finding_same"
	if int(w[0]) == 2:
		return "finding_unverified"
	if int(w[1]) != WHEEL_SOLUTION[1]:
		return "object"
	if int(w[2]) != WHEEL_SOLUTION[2]:
		return "owner"
	if not with_pencil or not game.has_item(PENCIL):
		return "no_pencil"
	return ""

## APPEND, with the pencil (item:pencil on the amendment line or APPEND, or the pencil selected)
## or without it. The card stays on the rest, amended, until she steps back from the slope.
func _append(ev: Array, with_pencil: bool) -> void:
	var why := append_refusal(with_pencil)
	if why != "":
		_sfx(ev, "append_refuse")
		_say(ev, NO_PENCIL if why == "no_pencil" else APPEND_REFUSALS[why])
		return
	state.p22_complete = true
	game.solve("P22", ev)
	_sfx(ev, "pencil_scratch", 0.0)
	_say(ev, "I write it under the printed line, and leave the printed line alone.", 0.2, true)
	_observe("nora_amendment")
	_sfx(ev, "cup_warm", 3.2)
	_fx(ev, "cup_warm")
	_say(ev, "Across the room, in Bell's locker, something ticks. China, warming.", 3.4, true)
	_observe("card_ring")

## The card comes off the RECORD rest into her bag: the original before P22, amended after.
func _lift_card(ev: Array) -> void:
	if not state.card_on_rest:
		return
	state.card_on_rest = false
	if state.p22_complete:
		_swap_card(ev)
	else:
		game.give("nora_register_card", ev)

func _glance(ev: Array, id: String) -> void:
	var g: Dictionary = GLANCES[id]
	ev.append({"type": "glance", "id": id, "rect": g.rect, "view": g.view})

# ---------------------------------------------------------------------------------------------
# state
# ---------------------------------------------------------------------------------------------
func _locker_of(o: String) -> String:
	for l in LOCKERS:
		if state.placed[l] == o:
			return l
	return ""

func _all_placed() -> bool:
	for l in LOCKERS:
		if state.placed[l] == "":
			return false
	return true

func _mark_notice(n: String) -> void:
	var k := NOTICES.find(n)
	for i in k + 1:
		if not NOTICES[i] in state.notices:
			state.notices.append(NOTICES[i])

func _set_p08_done() -> void:
	state.p08_complete = true
	for o in OWNER:
		state.placed[OWNER[o]] = o

func _set_p22_done() -> void:
	_set_p08_done()
	state.p22_complete = true
	state.wheels = WHEEL_SOLUTION.duplicate()
	state.card_on_rest = false
	state.sketch_on_rest = false

## Flags set elsewhere (tests, debug) pull the local arrangement along. Never clears anything.
func _sync() -> void:
	if game.flag("P08") and not state.p08_complete:
		_set_p08_done()
	if game.flag("P22") and not state.p22_complete:
		_set_p22_done()
		_swap_card()

## After P22 the register card is the amended card (the same physical card). While it lies on
## the rest it is in neither hand nor bag; it is given when she takes it off.
func _swap_card(ev: Array = []) -> void:
	if game.has_item("nora_register_card"):
		game.take("nora_register_card")
	if not state.card_on_rest and not game.has_item("amended_nora_card"):
		game.give("amended_nora_card", ev)

func load_state(d: Variant) -> void:
	state = initial_state()
	lifted = ""
	turned = ""
	last_refusal = ""
	if not d is Dictionary:
		return
	for key in SAVED_BOOLS:
		if d.get(key) is bool:
			state[key] = d[key]
	var pl = d.get("placed")
	if pl is Dictionary:
		for l in LOCKERS:
			var v = pl.get(l)
			if v is String and v != "" and OWNER.get(v, "") == l:
				state.placed[l] = v
	var w = d.get("wheels")
	if w is Array and w.size() == 3 and _all_whole(w):
		for i in 3:
			state.wheels[i] = clampi(int(w[i]), 0, (WHEELS[i] as Array).size() - 1)
	if d.get("notices") is Array:
		for n in d.notices:
			if n is String and n in NOTICES and not n in state.notices:
				state.notices.append(n)
	# Derived: later progress implies earlier progress and its arrangement.
	if state.p22_complete:
		state.p08_complete = true
	if _all_placed():
		state.p08_complete = true
	if state.p08_complete:
		_set_p08_done()
	else:
		state.pillow_dented = false
		state.letter_read = false
	if state.p22_complete:
		# the amended card may still be on the rest; the sketch went back with the amendment
		var on_rest: bool = state.card_on_rest
		_set_p22_done()
		state.card_on_rest = on_rest
	else:
		# Before P22 whatever lay on the rests stays there (reconcile checks it against the bag
		# and the notebook once both are loaded).
		state.cup_warm_seen = false

func reconcile() -> void:
	_sync()
	game.set_flag("P08", state.p08_complete)
	game.set_flag("P22", state.p22_complete)
	if not state.p22_complete:
		# The rests keep what she laid on them. A card can only lie there if P13 gave it and it
		# is not also in her bag; the sketch only if she has read the book it is copied from.
		if state.card_on_rest and (game.has_item("nora_register_card") or not game.flag("P13")):
			state.card_on_rest = false
		if state.sketch_on_rest and not game.has_seen("R05", "nora_ledger"):
			state.sketch_on_rest = false
	else:
		state.sketch_on_rest = false
		if state.card_on_rest and game.has_item("amended_nora_card"):
			state.card_on_rest = false
		_swap_card()

# ---------------------------------------------------------------------------------------------
# debug
# ---------------------------------------------------------------------------------------------
const P08_EVIDENCE := ["lockers", "belongings", "card_bell", "card_rook", "card_venn", "card_ives",
	"wear_cup", "wear_calipers", "wear_pencils", "wear_glove", "personal_cards", "venn_seal",
	"compartment"]

func debug_prepare(t: int) -> void:
	if t >= 4:
		_set_p08_done()
		state.pillow_dented = true
		for o in P08_EVIDENCE + ["venn_dent"]:
			_observe(o)
	if t >= 9:
		_set_p22_done()
		for o in ["register_card", "sketch_laid", "nora_amendment", "cup_warm"]:
			_observe(o)
		state.cup_warm_seen = true
	_prepare_notices()

## Every notice older than the current one is behind her; the current one still plays.
func _prepare_notices() -> void:
	if state.pillow_dented and not "pillow" in state.notices:
		state.notices.append("pillow")
	var n := current_notice()
	if n == "":
		return
	for i in NOTICES.find(n):
		if not NOTICES[i] in state.notices:
			state.notices.append(NOTICES[i])

## Dev stages: 0 Tide III fresh, 1 P08 one belonging short, 2 P08 just solved, 3 pillow dented,
## 4 Tide IV (names moved), 5 Tide VI (the curtain), 6 Tide VIII (P22 ready), 7 P22 commit
## ready, 8 Tide IX (P22 done).
func debug_jump(n: int) -> void:
	var dest := "room"
	if n <= 3:
		game.debug_tide(3, ID)
		if n == 1:
			for o in ["cup", "calipers", "pencils"]:
				state.placed[OWNER[o]] = o
			dest = "c_lockers"
		if n >= 2:
			_set_p08_done()
			game.set_flag("P08")
			game.give("token_bunk_half")
			for o in P08_EVIDENCE:
				_observe(o)
			dest = "c_lockers"
		if n == 3:
			state.pillow_dented = true
			_observe("venn_dent")
			_mark_notice("pillow")
			dest = "room"
	elif n == 4:
		game.debug_tide(4, ID)
	elif n == 5:
		game.debug_tide(6, ID)
	elif n <= 7:
		game.debug_tide(8, ID)
		game.give("nora_register_card")
		game.give(PENCIL)
		game.observe("R05", "nora_ledger")
		dest = "curtain"
	else:
		game.debug_tide(9, ID)
	lifted = ""
	turned = ""
	last_refusal = ""
	reconcile()
	if n == 7:
		# On the rest after reconcile, which would otherwise hand the card back.
		game.take("nora_register_card")
		state.card_on_rest = true
		state.sketch_on_rest = true
		state.wheels = WHEEL_SOLUTION.duplicate()
		_observe("register_card")
		_observe("sketch_laid")
		dest = "c_slope"
	local_view = dest
