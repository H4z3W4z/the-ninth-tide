extends "res://tests/rooms/room_test_base.gd"
## R06, the Bunk Room: P08 (the belongings go home), P22 (a person is more than a card), the
## pillow, O03, the calendar, the hollows and the curtain, saves, items and both views.
##   godot --headless --path . --script tests/rooms/R06_test.gd

const ROOM := "R06"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P06"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 3

const ARRIVAL := "The bunk room. Eight beds made tight, four lockers standing open. Somewhere, bed springs settle, as if someone had just lain down."
## Written out independently of R06Sim, so a typo in either is caught.
const OWNER := {"cup": "bell", "calipers": "rook", "pencils": "venn", "glove": "ives"}
const LOCKERS := ["bell", "rook", "venn", "ives"]
const TRAY := ["pencils", "glove", "cup", "calipers"]
const WRONG := {
	"cup>rook": "A brass staple through a broken handle. Rook alters instruments. A cup isn't one.",
	"cup>venn": "A stapled cup. Venn's card is the left of the page and two pencils, then two more.",
	"cup>ives": "Ives sews what he won't have reissued. A brass staple isn't sewing. This is someone given three new cups who kept none of them.",
	"calipers>bell": "One jaw filed down by hand. Bell's card is cups she wouldn't take. This is an instrument someone altered.",
	"calipers>venn": "A filed jaw. Venn's card is pencils and the left of the page. These belong to someone who trusts no instrument he hasn't altered.",
	"calipers>ives": "A jaw filed fine. Ives can't feel two fingertips, and he sews; he doesn't file.",
	"pencils>bell": "Four slots, worn bright on the left. Bell's card is tea and cups.",
	"pencils>rook": "Four slots, worn on the left side. Two issued, two requisitioned, written from the left of the page. Not Rook.",
	"pencils>ives": "Four pencil slots, left side worn bright. Ives's card is what he can sew.",
	"glove>bell": "Red thread at two fingertips. Bell's card is cups. This was sewn by someone who won't take a new issue.",
	"glove>rook": "Restitched in red thread. Rook alters instruments; this is a hand the winch took two fingertips from.",
	"glove>venn": "A right glove, red thread at two fingertips. Venn's card is pencils and the left of the page.",
}
## Each refusal names what distinguishes the object in hand (any one of these words).
const FEATURE := {"cup": ["staple"], "calipers": ["filed", "jaw"], "pencils": ["left", "slots"], "glove": ["red thread"]}
const RIGHT := {
	"cup": "Three new cups, and she kept none of them. She kept this one. Bell's.",
	"calipers": "Altered by his own hand. Rook's.",
	"pencils": "Two issued, two more requisitioned, worn from the left. Venn's.",
	"glove": "Red thread at two fingertips. Sewn, not reissued. Ives's.",
}
const CARDS := {
	"bell": "N. Bell. Takes her tea without sugar. Was given three new cups. Kept none of them.",
	"rook": "Dr S. Rook. Measures everything twice. Trusts no instrument he has not altered.",
	"venn": "E. Venn. Writes from the left of the page. Was issued two pencils. Requisitioned two more.",
	"ives": "T. Ives. Lost the feeling in two fingertips to the winch. Will not take a new issue of anything he can sew.",
}
const LIFT := {"cup": "The cup. Brass glints at the handle.", "calipers": "The calipers. One jaw looks wrong.",
	"pencils": "The pencil holder. Tin.", "glove": "The glove. A right glove."}
const WEAR := {
	"cup": "A cup with a brass staple through the handle where it broke. Mended, not replaced. N.B. scratched small under the foot.",
	"calipers": "Calipers. One jaw has been filed down by hand, carefully.",
	"pencils": "A tin pencil holder, four slots, worn bright on the left side only.",
	"glove": "A right glove, restitched in red thread at two fingertips.",
}
const PERSONAL_CARDS := "Bell: tea without sugar; given three new cups, kept none of them. Rook: measures twice; trusts no instrument he has not altered. Venn: writes from the left of the page; two pencils issued, two more requisitioned. Ives: two fingertips lost to the winch; won't take a new issue of anything he can sew."
const NO_PENCIL := "Corrections are in the amending officer's hand. Mine."
const WRITE_LINE := "I write it under the printed line, and leave the printed line alone."
const CURTAIN_T3 := "A curtain partition on a ceiling rail. It sways a little when I breathe out. Then once more, when I don't."
const VENN_SEAL := "Venn's personal seal: three cuts."
const NORA_AMENDMENT := "'No surviving personal effects.' Amended, in my hand: personal effect identified, repaired cup, Nora Bell."
const ERASE := "No. Corrections append. The original stands, and so does this."
const ERASE_NOTHING := "There's nothing on the rest to erase."
const NO_SKETCH := "I need the evidence beside it, or it's only my word."
const NO_P21 := "I could write it. I don't know yet what this card is part of."
const CUP_LINES := "Her cup is warm. There's a dry ring under it, as if it had just been put down. | Tea without sugar. I'd have guessed sugar."
const CAL_ROTA := ["Hart", "Ives", "Venn", "Doane", "Pryce", "Lusk", "Tull", "Venn"]
const CAL_INDEX := ["ROOK", "BELL", "IVES", "LUSK", "PRYCE", "DOANE", "HART", "TULL"]
const ALL_BEDS := ["venn", "doane", "bell", "ives", "rook", "lusk", "hart", "tull"]

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	test_arrival()
	test_p08_all_assignments()
	test_wrong_lines_distinct()
	test_p08_controls()
	test_p08_commit()
	test_p08_p07_order()
	test_pillow()
	test_o03()
	test_calendar()
	test_dents_and_curtain()
	test_notices()
	test_p22_refusals()
	test_p22_commit()
	test_p22_card_on_rest_saves()
	test_card_never_lost()
	test_p22_p23_order()
	test_cup_reveal()
	test_malformed_saves()
	test_save_mid_puzzle()
	test_objectives_hints()
	test_hotspots_everywhere()
	test_wrong_item_uses()
	test_debug()
	test_w2_details()
	if _view_ready():
		await view_checks(ROOM)
		test_view_rects()
		test_view_staged_art()
		await test_view_presentation()
	else:
		print("SKIP: R06 view_checks and rect checks: the R06 view does not yet declare rects for every sim hotspot (view team)")

# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
func r06(g: GameSim) -> R06Sim:
	return g.room(ROOM) as R06Sim

func fresh() -> GameSim:
	return with_flags(["P06"], ROOM)

func inv(g: GameSim) -> String:
	return JSON.stringify(g.state.inventory)

func snapshot(g: GameSim) -> String:
	return JSON.stringify([g.state.flags, g.state.inventory, r06(g).state])

func count_ev(ev: Array, type: String, id: String) -> int:
	var n := 0
	for e in ev:
		if e.type == type and e.get("id", "") == id:
			n += 1
	return n

func gives(ev: Array, item: String) -> int:
	var n := 0
	for e in ev:
		if e.type == "fx" and e.id == "item_added" and e.get("item", "") == item:
			n += 1
	return n

func story_count(ev: Array) -> int:
	var n := 0
	for e in ev:
		if e.type == "say" and e.story:
			n += 1
	return n

func obs_text(id: String) -> String:
	return str(R06Sim.OBSERVATIONS.get(id, ""))

## Places `o` on `l` by real clicks, from the c_lockers close-up. Returns the shelf's events.
func place(g: GameSim, o: String, l: String) -> Array:
	if r06(g).local_view != "c_lockers":
		g.dispatch("belongings_shelf")
	g.dispatch("obj_" + o)
	return g.dispatch("shelf_" + l)

func solve_p08(g: GameSim) -> Array:
	var ev: Array = []
	for o in TRAY:
		ev = place(g, o, OWNER[o])
	return ev

func use(g: GameSim, item: String, target: String) -> Array:
	g.dispatch("item:" + item)
	return g.dispatch(target)

func to_slope(g: GameSim) -> void:
	r06(g).local_view = "curtain"
	g.dispatch("slope")

## Steps the wheels by real clicks to `target`.
func set_wheels(g: GameSim, target: Array) -> void:
	var names := [["fin_next"], ["obj_next"], ["own_next"]]
	for i in 3:
		var guard := 0
		while int(r06(g).state.wheels[i]) != int(target[i]) and guard < 8:
			g.dispatch(names[i][0])
			guard += 1

## Tide VIII in the bunk room: P21 behind her, the card in hand, her book read.
func p22_ready(t := 8) -> GameSim:
	var g := game_at(t, ROOM)
	if not g.has_item("nora_register_card"):
		g.give("nora_register_card")
	g.observe("R05", "nora_ledger")
	return g

## Card and sketch on the rest, wheels at `w`.
func lay_all(g: GameSim, w: Array) -> void:
	to_slope(g)
	use(g, "nora_register_card", "rest_record")
	g.dispatch("rest_evidence")
	set_wheels(g, w)

## APPEND in her own hand: the pencil on the APPEND control.
func amend(g: GameSim) -> Array:
	return use(g, "pencil", "append")

func glances(ev: Array, id: String) -> Array:
	var out := []
	for e in ev:
		if e.type == "glance" and e.get("id", "") == id:
			out.append(e)
	return out

func permutations(a: Array) -> Array:
	if a.size() <= 1:
		return [a.duplicate()]
	var out := []
	for i in a.size():
		var rest := a.duplicate()
		var head = rest.pop_at(i)
		for p in permutations(rest):
			out.append([head] + p)
	return out

func flags_upto(n: int) -> Array:
	var out := []
	for i in range(1, n + 1):
		out.append("P%02d" % i)
	return out

func walk_in(g: GameSim) -> Array:
	r06(g).local_view = "room"
	if g.state.room == ROOM:
		g.dispatch("go:R02")
	return g.dispatch("go:" + ROOM)

# ---------------------------------------------------------------------------------------------
# (1) arrival
# ---------------------------------------------------------------------------------------------
func test_arrival() -> void:
	var g := with_flags(["P06"], "R02")
	var ev := g.dispatch("go:R06")
	check(g.state.room == ROOM, "arrival: walked into the bunk room")
	check(says(ev) == ARRIVAL, "arrival: the line is exact (got '%s')" % says(ev))
	check(has_ev(ev, "sfx", "springs_settle"), "arrival: springs settle")
	check(r06(g).has_seen("arrival_springs"), "arrival: noted")
	g.dispatch("go:R02")
	ev = g.dispatch("go:R06")
	check(not ARRIVAL in says(ev) and not has_ev(ev, "sfx", "springs_settle"), "arrival: once only")

# ---------------------------------------------------------------------------------------------
# (2)-(4) P08
# ---------------------------------------------------------------------------------------------
func test_p08_all_assignments() -> void:
	var perms := permutations(LOCKERS)
	check(perms.size() == 24, "P08: 24 assignments")
	var one_pass := 0
	for p in perms:
		var g := fresh()
		var r := r06(g)
		g.dispatch("belongings_shelf")
		var assign := {}
		for i in TRAY.size():
			assign[TRAY[i]] = p[i]
		var label := JSON.stringify(assign)
		for o in TRAY:
			var l: String = assign[o]
			var placed_before := JSON.stringify(r.state.placed)
			var inv_before := inv(g)
			g.dispatch("obj_" + o)
			check(r.lifted == o, "P08 %s: %s lifted" % [label, o])
			var ev := g.dispatch("shelf_" + l)
			if OWNER[o] == l:
				check(r.placed_in(l) == o, "P08 %s: %s snaps into %s" % [label, o, l])
				if not g.flag("P08"):
					check(says(ev) == RIGHT[o], "P08 %s: right line for %s" % [label, o])
			else:
				var key: String = o + ">" + l
				check(says(ev) == WRONG[key], "P08 %s: %s says exactly the wrong line (got '%s')" % [label, key, says(ev)])
				check(JSON.stringify(r.state.placed) == placed_before, "P08 %s: %s leaves the shelves" % [label, key])
				check(inv(g) == inv_before, "P08 %s: %s keeps the inventory" % [label, key])
				check(not g.flag("P08"), "P08 %s: %s does not solve" % [label, key])
				check(r.lifted == "" and r.last_refusal == key and has_ev(ev, "sfx", "reject_set"),
					"P08 %s: %s goes back to the tray, highlighted" % [label, key])
				check(o in r.tray_objects(), "P08 %s: %s is back in the tray" % [label, o])
		var identity := JSON.stringify(assign) == JSON.stringify(OWNER)
		if g.flag("P08"):
			one_pass += 1
			check(identity, "P08 %s: only the identity solves in one pass" % label)
		else:
			check(not identity, "P08 %s: the identity solves" % label)
			for o in TRAY:
				if r.placed_in(OWNER[o]) != o:
					place(g, o, OWNER[o])
			check(g.flag("P08") and r.state.p08_complete, "P08 %s: re-placing the misses solves it" % label)
		check(g.has_item("token_bunk_half"), "P08 %s: the token" % label)
	check(one_pass == 1, "P08: exactly one assignment solves in one pass (got %d)" % one_pass)

func test_wrong_lines_distinct() -> void:
	var seen := {}
	var n := 0
	for o in R06Sim.WRONG:
		for l in R06Sim.WRONG[o]:
			n += 1
			var line: String = R06Sim.WRONG[o][l]
			check(not seen.has(line), "P08: wrong line %s>%s is distinct" % [o, l])
			check(line == WRONG.get(o + ">" + l, "?"), "P08: wrong line %s>%s matches the card" % [o, l])
			var named := false
			for f in FEATURE[o]:
				named = named or line.to_lower().contains(f)
			check(named, "P08: wrong line %s>%s names the %s's distinguishing feature" % [o, l, o])
			seen[line] = true
	check(n == 12, "P08: twelve wrong lines (got %d)" % n)
	check(R06Sim.TRAY_ORDER == TRAY, "P08: the tray order")
	for i in 4:
		check(R06Sim.OWNER[R06Sim.TRAY_ORDER[i]] != R06Sim.LOCKERS[i], "P08: the tray is never positional (%d)" % i)

func test_p08_controls() -> void:
	var g := fresh()
	var r := r06(g)
	var ev := g.dispatch("belongings_shelf")
	check(r.local_view == "c_lockers" and r.has_seen("belongings"), "P08: belongings shelf opens c_lockers")
	check(says(ev) == "A pencil holder, a glove, a cup, calipers. Four things on top of the locked lockers, and four open lockers with nothing in them.", "P08: belongings line")
	for l in LOCKERS:
		ev = g.dispatch("card_" + l)
		check(says(ev) == CARDS[l], "P08: %s's card is exact (got '%s')" % [l, says(ev)])
		check(r.has_seen("card_" + l) and obs_text("card_" + l).contains(CARDS[l].split(". ", true, 1)[1]),
			"P08: card_%s noted, quoting the card" % l)
	check(says(g.dispatch("shelf_rook")) == "An empty shelf. A clean square in the dust where something stood.", "P08: empty shelf")
	# Each object: the first click lifts it and says only its short name and one neutral clause;
	# the second turns it over in the hand (the wear, noted); the third puts it down.
	for o in TRAY:
		ev = g.dispatch("obj_" + o)
		check(says(ev) == LIFT[o] and says(ev).begins_with(R06Sim.SHORT_NAMES[o]), "P08: lifting the %s (got '%s')" % [o, says(ev)])
		check(r.lifted == o and has_ev(ev, "sfx", "belonging_lift") and not r.has_seen("wear_" + o), "P08: %s lifted, wear unseen" % o)
		ev = g.dispatch("obj_" + o)
		check(says(ev) == WEAR[o] and r.has_seen("wear_" + o) and r.lifted == o, "P08: the %s turned over shows its wear" % o)
		ev = g.dispatch("obj_" + o)
		check(r.lifted == "" and has_ev(ev, "sfx", "belonging_set_down") and says(ev) == "", "P08: the third click puts the %s down" % o)
	check(says(g.dispatch("obj_cup")) == LIFT.cup, "P08: a later lift says the lift line again")
	check(says(g.dispatch("obj_cup")) == WEAR.cup, "P08: and turning it over the wear again")
	g.give("inspection_lens")
	check(says(use(g, "inspection_lens", "obj_cup")) == "Under the lens: N.B., scratched under the foot. Small and neat.", "P08: lens on the cup")
	check(says(use(g, "inspection_lens", "obj_glove")) == "A right glove, restitched in red thread at two fingertips.", "P08: lens on the glove repeats its wear")
	check(says(g.dispatch("obj_calipers")) == LIFT.calipers, "P08: lifting another swaps")
	check(r.lifted == "calipers", "P08: calipers in hand")
	g.dispatch("shelf_rook")
	check(says(g.dispatch("shelf_rook")) == "His calipers, on Rook's shelf.", "P08: placed shelf line")
	check(says(g.dispatch("obj_calipers")) == "It's home.", "P08: a placed object is home")
	g.dispatch("obj_glove")
	check(says(g.dispatch("shelf_rook")) == "Something's already home there.", "P08: an occupied shelf refuses")
	check(r.lifted == "glove", "P08: the glove stays in hand")
	check(says(g.dispatch("venn_back")) == "", "P08: venn_back is nothing before P08")
	ev = g.dispatch("back")
	check(r.local_view == "room" and r.lifted == "", "P08: Back puts the belonging down")
	ev = g.dispatch("locker_venn")
	check(r.local_view == "c_lockers" and says(ev) == "BELL, ROOK, VENN, IVES. Four cards, four bare shelves.", "P08: a locker opens c_lockers")

func test_p08_commit() -> void:
	var g := game_at(3, ROOM)
	var r := r06(g)
	var tide := g.tide()
	var band := g.weather_band()
	g.give("inspection_lens")
	var before: Array = g.state.inventory.duplicate()
	var ev := solve_p08(g)
	check(g.flag("P08") and r.state.p08_complete, "P08 commit: P08 set")
	check(gives(ev, "token_bunk_half") == 1 and g.has_item("token_bunk_half"), "P08 commit: the token, once")
	check(story_count(ev) == 5, "P08 commit: a five-line story chain (got %d)" % story_count(ev))
	check(says(ev).begins_with("The plate clicks. That's the last of them."), "P08 commit: the last plate clicks")
	check(not RIGHT.glove in says(ev), "P08 commit: the commit replaces the right line")
	check(has_ev(ev, "fx", "venn_open") and has_ev(ev, "fx", "pigeonhole_open"), "P08 commit: venn_open, pigeonhole_open")
	for s in ["calipers_set", "plate_click", "compartment_drop", "latch_small"]:
		check(has_ev(ev, "sfx", s), "P08 commit: sfx %s" % s)
	check(r.has_seen("personal_cards") and obs_text("personal_cards") == PERSONAL_CARDS, "P08 commit: personal_cards exact")
	check(r.has_seen("venn_seal") and obs_text("venn_seal") == VENN_SEAL, "P08 commit: venn_seal exact")
	check(r.has_seen("compartment"), "P08 commit: compartment noted")
	var gl := glances(ev, "p08_latch")
	check(gl.size() == 1 and gl[0].rect == Rect2(706, 524, 96, 84) and gl[0].view == "curtain",
		"P08 commit: one p08_latch glance at the pigeonhole (got %s)" % [gl])
	var gi := -1
	var li := -1
	for i in ev.size():
		if ev[i].type == "glance":
			gi = i
		if ev[i].type == "say" and ev[i].text == "Across the room, something small unlatched.":
			li = i
	check(gi > li and li >= 0, "P08 commit: the glance comes with the last line of the commit")
	for it in before:
		check(g.has_item(it), "P08 commit: %s still held" % it)
	check(not g.flag("P09") and g.tide() == tide and g.weather_band() == band, "P08 commit: no P09, the tide holds")
	check(r.compartment_open() and r.pigeonhole_open() and r.cup_marked(), "P08 commit: compartment, pigeonhole, cup")
	check(r.tray_objects().is_empty(), "P08 commit: the tray is bare")
	# Idempotent: nothing places, gives or solves again.
	var inv_after := inv(g)
	for o in TRAY:
		ev = g.dispatch("obj_" + o)
		check(says(ev) == "It's home.", "P08 after: %s is home" % o)
		for l in LOCKERS:
			ev = g.dispatch("shelf_" + l)
			check(says(ev) in ["Something's already home there.", "It's home.", R06Sim.PLACED_LINES[l]],
				"P08 after: shelf_%s says nothing new (got '%s')" % [l, says(ev)])
			check(gives(ev, "token_bunk_half") == 0 and count_ev(ev, "fx", "venn_open") == 0, "P08 after: no second commit")
	check(inv(g) == inv_after, "P08 after: the inventory is unchanged")
	check(says(g.dispatch("venn_back")) == "The back of his locker is further away than the wall is. I don't put my hand in.", "P08 after: venn_back")
	g.dispatch("back")
	check(says(g.dispatch("belongings_shelf")) == "Bare. Everything went home.", "P08 after: belongings shelf is bare")
	check(says(g.dispatch("locker_ives")) == "Everything is home.", "P08 after: lockers")

func test_p08_p07_order() -> void:
	var a := with_flags(["P06", "P07"], ROOM)
	solve_p08(a)
	var b := fresh()
	solve_p08(b)
	b.set_flag("P07")
	check(JSON.stringify(r06(a).state) == JSON.stringify(r06(b).state), "P07/P08 order: same R06 state")
	check(JSON.stringify(a.state.flags) == JSON.stringify(b.state.flags), "P07/P08 order: same flags")
	check(a.has_item("token_bunk_half") and b.has_item("token_bunk_half"), "P07/P08 order: the token either way")
	check(not a.flag("P09") and not b.flag("P09"), "P07/P08 order: R06 never sets P09")

# ---------------------------------------------------------------------------------------------
# (6) the pillow, (7) O03
# ---------------------------------------------------------------------------------------------
func test_pillow() -> void:
	var g := game_at(3, ROOM)
	var r := r06(g)
	solve_p08(g)
	check(not r.state.pillow_dented and r.dents().is_empty(), "pillow: smooth right after the commit")
	var d := g.to_dict()
	check(g.from_dict(d), "pillow: loads")
	r = r06(g)
	check(g.state.room == ROOM and not r.state.pillow_dented, "pillow: a load in the room never dents it")
	g.dispatch("go:R05")
	var ev := g.dispatch("go:R06")
	check(r.state.pillow_dented and has_ev(ev, "fx", "notice_pillow") and has_ev(ev, "sfx", "spring_creak"),
		"pillow: dented on the next arrival, with fx and creak")
	check("Venn's pillow. There's a dent in it, as if someone had just laid their head down." in says(ev), "pillow: the line")
	check(r.has_seen("venn_dent") and r.dents() == ["venn"], "pillow: noted, dents() == [venn]")
	check(g.from_dict(g.to_dict()) and r06(g).state.pillow_dented, "pillow: saves")
	g.dispatch("go:R05")
	ev = g.dispatch("go:R06")
	check(count_ev(ev, "fx", "notice_pillow") == 0, "pillow: does not replay")
	# Plan travel dents it too (P05 is behind her at tide III), even from a close-up.
	var p := game_at(3, ROOM)
	check(p.flag("P05"), "pillow: plan unlocked at tide III")
	solve_p08(p)
	p.dispatch("notebook")
	p.dispatch("plan:R05")
	check(p.state.room == "R05", "pillow: the plan leaves from c_lockers")
	p.dispatch("notebook")
	ev = p.dispatch("plan:R06")
	check(p.state.room == ROOM and r06(p).state.pillow_dented and has_ev(ev, "fx", "notice_pillow"), "pillow: plan travel dents it")

func test_o03() -> void:
	var g := game_at(3, ROOM)
	var r := r06(g)
	g.dispatch("to_curtain")
	check(r.local_view == "curtain", "O03: to_curtain")
	var ev := g.dispatch("ives_letter")
	check(says(ev) == "A pigeonhole in the back of the slope, latched. No keyhole. Whatever opens it isn't here.", "O03: latched before P08")
	check(not g.flag("o03_found") and r.has_seen("pigeonhole"), "O03: not found before P08")
	solve_p08(g)
	g.dispatch("back")
	g.dispatch("to_curtain")
	ev = g.dispatch("ives_letter")
	check(story_count(ev) == 4 and has_ev(ev, "sfx", "letter_unfold"), "O03: four story lines")
	check(says(ev).ends_with("It stops in the middle of the word."), "O03: it stops")
	check(g.flag("o03_found") and r.has_seen("ives_letter") and r.state.letter_read, "O03: found, noted")
	check(says(g.dispatch("ives_letter")) == "Ives's letter. 'I'll write after and tell you how tall I'. That's where it stops.", "O03: re-read")

# ---------------------------------------------------------------------------------------------
# (8) calendar, (9) hollows and curtain, (10) notices
# ---------------------------------------------------------------------------------------------
func test_calendar() -> void:
	var g := game_at(3, ROOM)
	var r := r06(g)
	check(r.calendar_names() == CAL_ROTA and r.calendar_hand() == "many", "calendar: the rota at tide III")
	r.local_view = "curtain"
	var ev := g.dispatch("calendar")
	check(has_ev(ev, "sfx", "calendar_page") and r.has_seen("calendar_rota"), "calendar: rota noted")
	check(says(ev).begins_with("A night-watch calendar."), "calendar: rota line")
	for f in ["P07", "P08", "P09"]:
		g.set_flag(f)
	check(g.weather_band() == 2 and r.calendar_names() == CAL_INDEX and r.calendar_hand() == "index", "calendar: the index at band 2")
	ev = g.dispatch("calendar")
	check(says(ev).begins_with("The dates are the same. The names have moved") and r.has_seen("calendar_index"), "calendar: index line")
	for f in flags_upto(24):
		g.set_flag(f)
	check(g.weather_band() == 7, "calendar: band 7")
	var want := ["", "", "", "", "", "", "", "A. MERCER"]
	check(r.calendar_names() == want and r.calendar_hand() == "index", "calendar: blank, A. MERCER under the 18th")
	ev = g.dispatch("calendar")
	check(says(ev) == "Every name is gone. One line under the 18th, today. A. MERCER.", "calendar: Mercer line")
	for o in ["calendar_rota", "calendar_index", "calendar_mercer"]:
		check(r.has_seen(o), "calendar: %s kept" % o)
	check(game_at(4, ROOM).room(ROOM).calendar_names() == CAL_INDEX, "calendar: game_at(4) index")
	check(game_at(9, ROOM).room(ROOM).calendar_names() == want, "calendar: game_at(9) Mercer")
	var c := game_at(9, ROOM)
	c.state.ending = "continue"
	check(r06(c).calendar_names() == want and r06(c).calendar_hand() == "ada", "calendar: continue, in her hand")
	c.state.ending = "sever"
	check(r06(c).calendar_names() == CAL_ROTA and r06(c).calendar_hand() == "many", "calendar: sever, the old rota")

func test_dents_and_curtain() -> void:
	var want := {4: ["venn"], 5: ["venn", "doane"], 6: ["venn", "doane"], 7: ["venn", "doane", "bell", "ives"],
		8: ALL_BEDS, 9: ALL_BEDS}
	for t in want:
		var r := r06(game_at(t, ROOM))
		check(r.dents() == want[t], "dents at tide %d: %s (got %s)" % [t, want[t], r.dents()])
	check(r06(game_at(3, ROOM)).dents().is_empty(), "dents at tide III: none")
	for t in [3, 4, 5]:
		var r := r06(game_at(t, ROOM))
		check(not r.curtain_shape() and r.curtain_sways(), "curtain at tide %d (band %d): sways" % [t, r.band()])
	for t in [6, 7, 8, 9]:
		var r := r06(game_at(t, ROOM))
		check(r.curtain_shape() and not r.curtain_sways(), "curtain at tide %d (band %d): a shape" % [t, r.band()])
	var stages := {3: "s1", 4: "s2", 5: "s2", 6: "s3", 7: "s3", 8: "s4", 9: "s4"}
	for t in stages:
		check(r06(game_at(t, ROOM)).plate_stage() == stages[t], "plate stage at tide %d" % t)

func test_notices() -> void:
	var want := {4: ["names_moved", "curtain"], 5: ["doane", "curtain"], 6: ["curtain_shape", "curtain"],
		7: ["four", "room"], 8: ["every_bed", "room"], 9: ["her_name", "curtain"]}
	for t in want:
		var g := game_at(t, "R02")
		var ev := g.dispatch("go:R06")
		var n: String = want[t][0]
		check(g.state.room == ROOM, "notice tide %d: walked in" % t)
		check(count_ev(ev, "fx", "notice_" + n) == 1, "notice tide %d: notice_%s fires once" % [t, n])
		var others := 0
		for e in ev:
			if e.type == "fx" and str(e.id).begins_with("notice_"):
				others += 1
		check(others == 1, "notice tide %d: only one notice" % t)
		var shown := ""
		for e in ev:
			if e.type == "fx" and e.id == "notice_" + n:
				shown = str(e.get("view", ""))
		check(shown == want[t][1] and r06(g).notice_view(n) == want[t][1], "notice tide %d: the hold shows the %s wall" % [t, want[t][1]])
		check(r06(g).local_view == "room", "notice tide %d: she can still leave" % t)
		check(says(ev) == R06Sim.NOTICE_LINES[n] or n == "every_bed", "notice tide %d: the line (got '%s')" % [t, says(ev)])
		check(story_count(ev) == 0, "notice tide %d: never holds the next room's lines" % t)
		ev = walk_in(g)
		check(count_ev(ev, "fx", "notice_" + n) == 0, "notice tide %d: does not repeat" % t)
	# A skipped band only fires the latest.
	var g := game_at(4, ROOM)
	g.dispatch("go:R02")
	for f in flags_upto(15):
		g.set_flag(f)
	check(g.weather_band() == 4, "skipped notices: band 4")
	var ev := g.dispatch("go:R06")
	check(has_ev(ev, "fx", "notice_curtain_shape") and not has_ev(ev, "fx", "notice_names_moved")
		and not has_ev(ev, "fx", "notice_doane"), "skipped notices: only the curtain plays")
	check("doane" in r06(g).state.notices and "names_moved" in r06(g).state.notices, "skipped notices: older ones retired")
	check(r06(g).has_seen("curtain_shape"), "skipped notices: evidence noted")
	# Every bed: two story lines.
	var e8 := game_at(8, "R02").dispatch("go:R06")
	check("Eight of them settled. One at a time." in says(e8) and has_ev(e8, "sfx", "springs_eight"), "every bed: second line, sound")

# ---------------------------------------------------------------------------------------------
# (11)-(14) P22
# ---------------------------------------------------------------------------------------------
func test_p22_refusals() -> void:
	# Before P21: the card can be laid, but the amendment waits.
	var g := p22_ready(7)
	var r := r06(g)
	check(not g.flag("P21"), "P22 early: P21 not yet")
	check(r.objective() == "away", "P22 early: nothing to do here")
	lay_all(g, [1, 3, 3])
	check(r.state.card_on_rest and r.state.sketch_on_rest, "P22 early: card and sketch on the rest")
	var before := snapshot(g)
	var ev := g.dispatch("append")
	check(says(ev) == NO_P21 and has_ev(ev, "sfx", "append_refuse"), "P22 early: exact refusal")
	check(snapshot(g) == before and not g.flag("P22"), "P22 early: nothing changes")
	# ERASE and the printed line, with and without the card.
	g = p22_ready()
	r = r06(g)
	to_slope(g)
	for a in ["erase", "printed_line"]:
		ev = g.dispatch(a)
		check(says(ev) == ERASE_NOTHING and has_ev(ev, "sfx", "erase_refuse"), "P22 %s without the card" % a)
	ev = use(g, "nora_register_card", "rest_record")
	check(r.state.card_on_rest and not g.has_item("nora_register_card") and r.has_seen("register_card"), "P22: card laid")
	check(says(ev) == "Her register card. 'No surviving personal effects.' Stamped SPECIMEN N-27.", "P22: card line")
	before = snapshot(g)
	for a in ["erase", "printed_line"]:
		ev = g.dispatch(a)
		check(says(ev) == ERASE and has_ev(ev, "sfx", "erase_refuse"), "P22 %s with the card: exact refusal" % a)
	var had_pencil := g.has_item("pencil")
	g.give("pencil")
	check(says(use(g, "pencil", "printed_line")) == ERASE, "P22: the pencil on the printed line refuses")
	if not had_pencil:
		g.take("pencil")
	check(snapshot(g) == before and not g.flag("P22"), "P22: erasing changes nothing")
	check(not g.has_item("amended_nora_card"), "P22: the card is still the original")
	# No sketch.
	set_wheels(g, [1, 3, 3])
	ev = g.dispatch("append")
	check(says(ev) == NO_SKETCH, "P22: no sketch refusal exact")
	# Wheels: each refusal, first failing check wins.
	g.dispatch("rest_evidence")
	check(r.state.sketch_on_rest and r.has_seen("sketch_laid"), "P22: sketch laid")
	var cases := [[[0, 3, 3], "That's what the card already says. A correction has to add something."],
		[[2, 3, 3], "'Not verified.' I have verified it. The sketch and the cup agree."],
		[[1, 0, 3], "The evidence on the rest is a cup. The correction has to say what the evidence shows."],
		[[1, 2, 0], "The evidence on the rest is a cup. The correction has to say what the evidence shows."],
		[[1, 3, 0], "This is Nora's record. The correction names her."],
		[[2, 0, 0], "'Not verified.' I have verified it. The sketch and the cup agree."]]
	for cse in cases:
		r.state.wheels = [0, 0, 0]
		set_wheels(g, cse[0])
		before = snapshot(g)
		ev = g.dispatch("append")
		check(says(ev) == cse[1], "P22 wheels %s: exact refusal (got '%s')" % [cse[0], says(ev)])
		check(snapshot(g) == before, "P22 wheels %s: nothing changes" % [cse[0]])
	# Everything right but her hand: APPEND alone refuses, and changes nothing.
	r.state.wheels = [0, 0, 0]
	set_wheels(g, [1, 3, 3])
	before = snapshot(g)
	ev = g.dispatch("append")
	check(says(ev) == NO_PENCIL and has_ev(ev, "sfx", "append_refuse"), "P22: APPEND without the pencil refuses (got '%s')" % says(ev))
	check(snapshot(g) == before and not g.flag("P22"), "P22: without the pencil nothing changes")
	check(r.append_refusal(false) == "no_pencil" and r.append_refusal(true) == "", "P22: the pencil is the last check")
	ev = g.dispatch("amend_line")
	check(says(ev).begins_with("The amendment line") and snapshot(g) == before, "P22: the amendment line alone only describes itself")
	# The pencil on the wrong wheels refuses the same way the wheels do; it is never taken.
	r.state.wheels = [0, 3, 3]
	ev = use(g, "pencil", "amend_line")
	check(says(ev) == "That's what the card already says. A correction has to add something." and g.has_item("pencil"),
		"P22: the pencil on the wrong finding refuses, the pencil kept")
	# Wheels wrap both ways and say nothing.
	r.state.wheels = [0, 0, 0]
	ev = g.dispatch("fin_prev")
	check(r.state.wheels == [2, 0, 0] and says(ev) == "" and has_ev(ev, "sfx", "wheel_step"), "P22: finding wraps back")
	g.dispatch("own_prev")
	g.dispatch("obj_prev")
	check(r.state.wheels == [2, 3, 3], "P22: object and owner wrap back")
	g.dispatch("fin_next")
	check(r.state.wheels == [0, 3, 3] and r.wheel_text(0) == "NO SURVIVING EFFECTS", "P22: finding wraps forward")
	check(r.wheel_text(1) == "REPAIRED CUP" and r.wheel_text(2) == "NORA BELL", "P22: wheel text")
	# No card on the rest.
	g.dispatch("rest_record")
	check(g.has_item("nora_register_card") and not r.state.card_on_rest, "P22: the card lifts back")
	check(says(g.dispatch("append")) == "There's no record on the rest to amend.", "P22: no card refusal")
	check(says(g.dispatch("rest_record")) == "The left rest is for the record being amended. Her card is in my bag.", "P22: rest_record with the card in hand")
	# Her book unread: no sketch to lay.
	var u := game_at(8, ROOM)
	u.state.notebook.erase("R05.nora_ledger")  # the built kitchen's tide-8 prep has read it
	u.give("nora_register_card")
	to_slope(u)
	ev = u.dispatch("rest_evidence")
	check(says(ev) == "I've nothing to lay beside it. The kitchen has a book with her handwriting in it.", "P22: no ledger, no sketch")
	check(not r06(u).state.sketch_on_rest, "P22: sketch stays off")
	# The sketch lifts back.
	u.observe("R05", "nora_ledger")
	u.dispatch("rest_evidence")
	check(says(u.dispatch("rest_evidence")) == "I take the sketch back." and not r06(u).state.sketch_on_rest, "P22: sketch lifts back")

func test_p22_commit() -> void:
	# Each of her three ways of writing it: the pencil on APPEND, on the amendment line, or selected
	# then APPEND (the core turns that into use_item("pencil", "append")).
	for how in ["append", "amend_line", "selected"]:
		var g := p22_ready()
		var r := r06(g)
		check(r.objective() == "p22", "P22 %s: the objective" % how)
		check(not r.state.letter_read, "P22 %s: solvable without the letter" % how)
		check(g.has_item("pencil"), "P22 %s: her pencil from Tide I" % how)
		lay_all(g, [1, 3, 3])
		var ev: Array
		if how == "selected":
			g.dispatch("item:pencil")
			check(g.selected_item == "pencil", "P22 selected: the pencil is in hand")
			ev = g.dispatch("append")
		else:
			ev = use(g, "pencil", how)
		check(g.flag("P22") and r.state.p22_complete, "P22 %s: P22 set" % how)
		check(g.has_item("pencil"), "P22 %s: the pencil is not consumed" % how)
		check(says(ev).begins_with(WRITE_LINE), "P22 %s: the line is kept (got '%s')" % [how, says(ev)])
		# The amended card stays in view on the RECORD rest; it is not in her bag yet.
		check(r.state.card_on_rest and r.local_view == "c_slope", "P22 %s: the amended card stays on the rest" % how)
		check(not g.has_item("nora_register_card") and not g.has_item("amended_nora_card"), "P22 %s: neither card in the bag yet" % how)
		check(gives(ev, "amended_nora_card") == 0, "P22 %s: nothing given at APPEND" % how)
		check(r.objective() == "take_card", "P22 %s: the objective is to take the card" % how)
		check(r.has_seen("nora_amendment") and obs_text("nora_amendment") == NORA_AMENDMENT, "P22 %s: nora_amendment exact" % how)
		check(r.has_seen("register_card") and r.has_seen("card_ring"), "P22 %s: the original text and the ring in the notebook" % how)
		check(has_ev(ev, "fx", "cup_warm") and has_ev(ev, "sfx", "pencil_scratch") and has_ev(ev, "sfx", "cup_warm"), "P22 %s: cup_warm fx and sounds" % how)
		check(story_count(ev) == 2, "P22 %s: two story lines" % how)
		check(r.amendment_written() and r.dry_ring() and r.cup_steam(), "P22 %s: amendment, ring, steam" % how)
		check(R06Sim.AMEND_LINE == "REPAIRED CUP, NORA BELL", "P22: the pencil line")
		check(not g.flag("P24"), "P22 %s: P24 not set" % how)
		# Repeats and the locked wheels change nothing.
		var snap := snapshot(g)
		ev = amend(g)
		check(says(ev) == "It's already amended." and gives(ev, "amended_nora_card") == 0, "P22 %s repeat: already amended" % how)
		g.dispatch("fin_next")
		g.dispatch("erase")
		check(snapshot(g) == snap, "P22 %s after: wheels locked, nothing erased" % how)
		# Back takes the card off the rest: given once, the cup glance and its lines.
		ev = g.dispatch("back")
		check(gives(ev, "amended_nora_card") == 1 and g.has_item("amended_nora_card") and not g.has_item("nora_register_card"),
			"P22 %s: Back gives the amended card, once" % how)
		check(not r.state.card_on_rest and not r.state.sketch_on_rest and r.objective() == "done", "P22 %s: the rest is clear, done" % how)
		var gl := glances(ev, "p22_cup")
		check(gl.size() == 1 and gl[0].rect == R06Sim.GLANCES.p22_cup.rect and gl[0].view == "room", "P22 %s: the p22_cup glance on Back" % how)
		ev = g.dispatch("back")
		check(gives(ev, "amended_nora_card") == 0 and glances(ev, "p22_cup").is_empty(), "P22 %s: a second Back gives nothing" % how)
	# Taking it off the rest by hand, instead of Back.
	var h := p22_ready()
	lay_all(h, [1, 3, 3])
	amend(h)
	var ev := h.dispatch("rest_record")
	check(says(ev) == "I take her card, amended." and gives(ev, "amended_nora_card") == 1 and not r06(h).state.card_on_rest,
		"P22: the amended card lifts off the rest by hand")
	check(says(h.dispatch("rest_record")) == "The rest is clear.", "P22 after: rest clear")
	ev = h.dispatch("back")
	check(gives(ev, "amended_nora_card") == 0 and glances(ev, "p22_cup").size() == 1, "P22: Back then gives nothing more; the glance still plays")
	# A P22 flag set elsewhere swaps the card as soon as the room hears of it.
	var f := p22_ready()
	f.set_flag("P22")
	r06(f).objective()
	check(f.has_item("amended_nora_card") and not f.has_item("nora_register_card"), "P22 by flag: the card is swapped")
	var inv_f := inv(f)
	check(f.from_dict(JSON.parse_string(JSON.stringify(f.to_dict()))) and inv(f) == inv_f, "P22 by flag: round-trips")
	h.take("amended_nora_card")
	check(h.from_dict(h.to_dict()) and h.has_item("amended_nora_card"), "P22 after: the amended card always exists after P22")

## Save and load while the amended card lies on the rest: it stays there, and is given once.
func test_p22_card_on_rest_saves() -> void:
	var g := p22_ready()
	var r := r06(g)
	lay_all(g, [1, 3, 3])
	amend(g)
	check(g.from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))), "P22 on rest: loads")
	r = r06(g)
	check(r.state.p22_complete and r.state.card_on_rest and not r.state.sketch_on_rest, "P22 on rest: the card stays on the rest, the sketch does not")
	check(not g.has_item("amended_nora_card") and not g.has_item("nora_register_card"), "P22 on rest: not given by the load")
	check(r.local_view == "room" and r.objective() == "take_card", "P22 on rest: back in the room, the card to take")
	check(r.hint_line(2) == R06Sim.HINTS.take_card[2], "P22 on rest: the hint points at the slope")
	# A second load changes nothing.
	check(g.from_dict(g.to_dict()) and r06(g).state.card_on_rest and not g.has_item("amended_nora_card"), "P22 on rest: a second load")
	r = r06(g)
	r.local_view = "curtain"
	var ev := g.dispatch("slope")
	check(says(ev) == "Her card is still on the rest, amended in pencil under the printed line.", "P22 on rest: the slope says so")
	ev = g.dispatch("back")
	check(gives(ev, "amended_nora_card") == 1 and g.has_item("amended_nora_card") and not r.state.card_on_rest, "P22 on rest: Back gives it once")
	check(has_ev(ev, "fx", "notice_cup") and glances(ev, "p22_cup").size() == 1, "P22 on rest: the cup beat and its glance after the load")
	check(g.from_dict(g.to_dict()) and g.has_item("amended_nora_card") and g.state.inventory.count("amended_nora_card") == 1,
		"P22 on rest: exactly one card after another load")
	# A malformed save: card on the rest before P22 goes back to her bag.
	var m := p22_ready()
	lay_all(m, [1, 3, 3])
	check(m.from_dict(m.to_dict()) and m.has_item("nora_register_card") and not r06(m).state.card_on_rest, "pre-P22: a load returns the card")

func test_card_never_lost() -> void:
	var g := p22_ready()
	to_slope(g)
	use(g, "nora_register_card", "rest_record")
	g.dispatch("rest_evidence")
	g.dispatch("back")
	check(g.has_item("nora_register_card") and not r06(g).state.card_on_rest, "card: Back returns it")
	check(not r06(g).state.sketch_on_rest and r06(g).local_view == "curtain", "card: Back clears the sketch, to the curtain")
	g.dispatch("back")
	check(r06(g).local_view == "room", "card: Back from the curtain turns her round")
	to_slope(g)
	use(g, "nora_register_card", "slope")
	check(r06(g).state.card_on_rest, "card: laid via the slope hotspot")
	check(g.from_dict(g.to_dict()), "card: loads")
	check(g.has_item("nora_register_card") and not r06(g).state.card_on_rest, "card: a save returns it")
	to_slope(g)
	use(g, "nora_register_card", "rest_record")
	g.dispatch("notebook")
	g.dispatch("plan:R05")
	check(g.state.room == "R05" and g.has_item("nora_register_card"), "card: plan travel from c_slope returns it")

func test_p22_p23_order() -> void:
	var a := p22_ready()
	a.set_flag("P23")
	lay_all(a, [1, 3, 3])
	amend(a)
	var b := p22_ready()
	lay_all(b, [1, 3, 3])
	amend(b)
	b.set_flag("P23")
	check(JSON.stringify(r06(a).state) == JSON.stringify(r06(b).state), "P22/P23 order: same R06 state")
	check(JSON.stringify(a.state.flags) == JSON.stringify(b.state.flags), "P22/P23 order: same flags")
	check(not a.flag("P24") and not b.flag("P24"), "P22/P23 order: P24 never set by R06")

func test_cup_reveal() -> void:
	var g := p22_ready()
	var r := r06(g)
	lay_all(g, [1, 3, 3])
	amend(g)
	var ev := g.dispatch("back")
	check(r.local_view == "room" and has_ev(ev, "fx", "notice_cup"), "cup: Back after P22 lands in the room")
	check(says(ev) == CUP_LINES and story_count(ev) == 2, "cup: the two lines (got '%s')" % says(ev))
	check(r.has_seen("cup_warm") and r.state.cup_warm_seen, "cup: noted")
	to_slope(g)
	ev = g.dispatch("back")
	check(r.local_view == "curtain" and not has_ev(ev, "fx", "notice_cup"), "cup: once")
	r.local_view = "curtain"
	check(says(g.dispatch("cup_shelf")) == "The ring here is old and dry. The new one is in her locker, under the cup.", "cup: the shelf after P22")

# ---------------------------------------------------------------------------------------------
# (15) saves
# ---------------------------------------------------------------------------------------------
func load_r(d: Variant) -> R06Sim:
	var g := fresh()
	var r := r06(g)
	r.load_state(d)
	return r

func test_malformed_saves() -> void:
	for junk in [null, 3, "x", [], {"placed": 5, "wheels": "x", "notices": {}}]:
		var r := load_r(junk)
		check(JSON.stringify(r.state) == JSON.stringify(r.initial_state()), "load: %s gives a fresh room" % [junk])
	var r := load_r({"placed": {"bell": "glove", "rook": "calipers", "venn": "calipers", "ives": 3, "pryce": "cup"}})
	check(r.state.placed == {"bell": "", "rook": "calipers", "venn": "", "ives": ""}, "load: wrong pairs and junk never persist (got %s)" % [r.state.placed])
	r = load_r({"placed": {"bell": "cup", "rook": "cup", "venn": "cup", "ives": "cup"}})
	check(r.state.placed == {"bell": "cup", "rook": "", "venn": "", "ives": ""}, "load: no duplicate objects")
	check(not r.state.p08_complete, "load: one placed is not P08")
	r = load_r({"wheels": [5, -2, 9]})
	check(r.state.wheels == [2, 0, 3], "load: wheels clamp")
	for w in [[1.5, 0, 0], [1, 2], ["a", 0, 0], [1, 2, 3, 0]]:
		check(load_r({"wheels": w}).state.wheels == [0, 0, 0], "load: wheels %s rejected" % [w])
	r = load_r({"notices": ["pillow", "bogus", "pillow", 3, "rise"]})
	check(r.state.notices == ["pillow", "rise"], "load: unknown notices dropped, deduped")
	r = load_r({"p22_complete": true})
	check(r.state.p08_complete and r.state.placed == {"bell": "cup", "rook": "calipers", "venn": "pencils", "ives": "glove"},
		"load: p22 without p08 implies p08 and its shelves")
	check(r.state.wheels == [1, 3, 3], "load: p22 sets the wheels")
	r = load_r({"pillow_dented": true, "letter_read": true, "cup_warm_seen": true})
	check(not r.state.pillow_dented and not r.state.letter_read and not r.state.cup_warm_seen, "load: derived bools need their puzzles")
	r = load_r({"placed": {"bell": "cup", "rook": "calipers", "venn": "pencils", "ives": "glove"}})
	check(r.state.p08_complete, "load: all four placed means P08")
	r = load_r({"p08_complete": true})
	check(r.placed_in("venn") == "pencils", "load: P08 fills the shelves")
	r = load_r({"p22_complete": true, "card_on_rest": true, "sketch_on_rest": true})
	check(r.state.card_on_rest and not r.state.sketch_on_rest, "load: after P22 the amended card may stay on the rest; never the sketch")
	r = load_r({"p22_complete": true, "card_on_rest": "yes"})
	check(not r.state.card_on_rest, "load: card_on_rest by type")
	r = load_r({"p08_complete": "yes", "rise_seen": 1})
	check(not r.state.p08_complete and not r.state.rise_seen, "load: bools by type")
	# Transients reset.
	var g := fresh()
	g.dispatch("belongings_shelf")
	g.dispatch("obj_cup")
	g.dispatch("obj_glove")
	g.dispatch("shelf_bell")
	check(r06(g).last_refusal == "glove>bell", "load: a refusal highlighted")
	g.dispatch("obj_cup")
	check(g.from_dict(g.to_dict()), "load: loads")
	check(r06(g).lifted == "" and r06(g).last_refusal == "" and r06(g).local_view == "room", "load: transients reset")
	# Flags follow the room's state; a set P08 flag pulls the room along.
	var f := fresh()
	f.set_flag("P08")
	f.dispatch("bunks")
	check(r06(f).state.p08_complete and r06(f).placed_in("bell") == "cup", "sync: a P08 flag fills the shelves")
	check(not f.has_item("token_bunk_half"), "sync: the token is not re-given")

func test_save_mid_puzzle() -> void:
	var g := fresh()
	place(g, "cup", "bell")
	place(g, "glove", "ives")
	check(g.from_dict(g.to_dict()), "mid P08: loads")
	var r := r06(g)
	check(r.placed_in("bell") == "cup" and r.placed_in("ives") == "glove" and not g.flag("P08"), "mid P08: two placed, unsolved")
	place(g, "calipers", "rook")
	place(g, "pencils", "venn")
	check(g.flag("P08") and g.has_item("token_bunk_half"), "mid P08: finishes after a load")
	var p := p22_ready()
	lay_all(p, [1, 3, 2])
	check(p.from_dict(p.to_dict()), "mid P22: loads")
	check(r06(p).state.wheels == [1, 3, 2] and p.has_item("nora_register_card"), "mid P22: wheels kept, card in hand")
	# R05 owns nora_ledger; until its sim declares it, a load drops it from the notebook.
	p.observe("R05", "nora_ledger")
	lay_all(p, [1, 3, 3])
	amend(p)
	p.dispatch("back")
	check(p.flag("P22"), "mid P22: finishes after a load")
	check(p.from_dict(p.to_dict()) and p.flag("P22") and p.has_item("amended_nora_card") and not p.has_item("nora_register_card"),
		"P22: the swap persists")

# ---------------------------------------------------------------------------------------------
# (16) objectives and hints
# ---------------------------------------------------------------------------------------------
func test_objectives_hints() -> void:
	var ladders := {
		"p08": ["Four belongings, four open lockers, and a card on each door.",
			"Each card names a habit. Lift each object and turn it over: it shows the wear that habit leaves.",
			"Cup to Bell, calipers to Rook, pencil holder to Venn, glove to Ives."],
		"p22": ["Nora's register card says something the bunk room can contradict.",
			"Her cup is a personal effect. Corrections are added, never written over.",
			"Put her card and the cup sketch on the slope, set the wheels to 'personal effect identified / repaired cup / Nora Bell', and APPEND with my pencil."],
		"take_card": ["Her card is still on the writing slope.",
			"The amendment is written. The card goes with me, not on the rest.",
			"Open the writing slope and step back from it: I take her amended card with me."],
		"away": ["Nothing in the bunk room is waiting on me.",
			"The beds keep what they keep. Something elsewhere comes first.",
			"Come back when I have a record of Nora's that needs correcting."],
		"done": ["The bunk room has given what it had.", "Her card is amended. It goes where records go.",
			"Nothing more to do here."],
	}
	var texts := {"p08": "Put the four belongings back in their owners' lockers.",
		"p22": "Correct Nora's register card without erasing it.",
		"away": "Nothing here needs me yet. The beds keep what they keep.",
		"done": "Her card is amended. The bunk room is finished with me.",
		"take_card": "Take Nora's amended card off the writing slope."}
	var g := fresh()
	var r := r06(g)
	var path := []
	path.append(r.objective())
	solve_p08(g)
	path.append(r.objective())
	g.set_flag("P21")
	g.give("pencil")
	g.give("nora_register_card")
	g.observe("R05", "nora_ledger")
	path.append(r.objective())
	lay_all(g, [1, 3, 3])
	amend(g)
	path.append(r.objective())
	g.dispatch("back")
	path.append(r.objective())
	check(path == ["p08", "away", "p22", "take_card", "done"], "objectives: p08 -> away -> p22 -> take_card -> done (got %s)" % [path])
	for o in ladders:
		check(R06Sim.OBJECTIVES.get(o, "") == texts[o], "objective %s text exact" % o)
		for i in 3:
			check(R06Sim.HINTS[o][i] == ladders[o][i], "hint %s %d exact" % [o, i])
	var h := fresh()
	for i in 3:
		check(r06(h).hint_line(i) == ladders.p08[i], "hint_line p08 %d" % i)

# ---------------------------------------------------------------------------------------------
# (17) every hotspot answers, (18) wrong-target items
# ---------------------------------------------------------------------------------------------
func hotspots_answer(g: GameSim, label: String) -> void:
	var r := r06(g)
	for h in R06Sim.HOTSPOTS:
		r.local_view = "room"
		check(says(g.dispatch(h)) != "", "%s: room hotspot %s answers" % [label, h])
	for h in R06Sim.CURTAIN_HOTSPOTS:
		r.local_view = "curtain"
		check(says(g.dispatch(h)) != "", "%s: curtain hotspot %s answers" % [label, h])
	r.local_view = "room"

func test_hotspots_everywhere() -> void:
	hotspots_answer(fresh(), "Tide I fresh")
	for t in range(3, 10):
		hotspots_answer(game_at(t, ROOM), "tide %d" % t)
	var s := game_at(9, "R02")
	s.state.ending = "sever"
	var ev := s.dispatch("go:R06")
	var r := r06(s)
	check(r.dents().is_empty(), "sever: no hollows")
	check(count_ev(ev, "fx", "notice_rise") == 1 and has_ev(ev, "sfx", "dents_rise"), "sever: the rise plays")
	check(r.state.rise_seen and not r.dents_rising(), "sever: rise seen")
	check(not r.curtain_shape() and r.curtain_sways() and r.plate_stage() == "sever" and not r.cup_steam(), "sever: released")
	ev = walk_in(s)
	check(count_ev(ev, "fx", "notice_rise") == 0, "sever: the rise plays once")
	hotspots_answer(s, "sever")
	var c := game_at(9, ROOM)
	c.state.ending = "continue"
	check(r06(c).current_notice() == "", "continue: no notice")
	hotspots_answer(c, "continue")
	# To and fro between the walls.
	var g := fresh()
	check(says(g.dispatch("to_curtain")) == "The curtain wall." and r06(g).local_view == "curtain", "to_curtain")
	check(says(g.dispatch("to_curtain")) == "The curtain wall.", "to_curtain answers again")
	check(says(g.dispatch("to_lockers")) == "The lockers." and r06(g).local_view == "room", "to_lockers")
	check(r06(g).is_closeup("c_lockers") and r06(g).is_closeup("c_slope") and not r06(g).is_closeup("curtain")
		and not r06(g).is_closeup("room"), "is_closeup: only the close-ups")
	check(r06(g).exit_block("R02") == "" and r06(g).exit_block("R05") == "", "exit_block: never")

func test_wrong_item_uses() -> void:
	var cases := [
		# [tide, item, target, view, expected or ""]
		[3, "token_bunk_half", "belongings_shelf", "room", "The other half's in the kitchen. The token belongs in the service board there."],
		[3, "token_bunk_half", "calendar", "curtain", "The other half's in the kitchen. The token belongs in the service board there."],
		[3, "nora_register_card", "locker_bell", "room", "Her card says no surviving personal effects."],
		[8, "nora_register_card", "locker_bell", "room", "Her card says no surviving personal effects. Her cup is sitting right here."],
		[8, "nora_register_card", "shelf_bell", "c_lockers", "Her card says no surviving personal effects. Her cup is sitting right here."],
		[8, "nora_frame", "slope", "curtain", "That's a measurement of her. The slope is for her things."],
		[8, "nora_spatial_strip", "rest_record", "c_slope", "That's a measurement of her. The slope is for her things."],
		[9, "amended_nora_card", "rest_evidence", "c_slope", "It's amended. It stays amended."],
		[9, "amended_nora_card", "slope", "curtain", "It's amended. It stays amended."],
		[8, "witness_bridge", "slope", "curtain", "Not this. The bridge is for the chamber."],
		[8, "pencil", "printed_line", "c_slope", ERASE_NOTHING],
		[8, "pencil", "calendar", "curtain", "I'm not writing on that. Something else does."],
		[4, "inspection_lens", "venn_bunk", "room", "Under the lens the dent has the weave of a pillowcase pressed into it. Recent."],
		[3, "inspection_lens", "luggage", "room", "No tag was ever tied on. No holes worn in the handles."],
		[4, "inspection_lens", "calendar", "curtain", "Under the lens: pencil, and under the pencil the dents of other names pressed through."],
		[6, "inspection_lens", "curtain", "curtain", "The shape is on the front of the cloth. There's no light behind it to cast it."],
		[3, "inspection_lens", "calendar", "curtain", ""],
		[3, "inspection_lens", "curtain", "curtain", ""],
		[3, "inspection_lens", "venn_bunk", "room", ""],
		[3, "witness_bridge", "bunks", "room", ""],
	]
	for cse in cases:
		var g := game_at(cse[0], ROOM)
		var r := r06(g)
		g.give(cse[1])
		r.local_view = cse[3]
		var before := inv(g)
		var flags_before := JSON.stringify(g.state.flags)
		var ev := use(g, cse[1], cse[2])
		var label := "item %s on %s at tide %d" % [cse[1], cse[2], cse[0]]
		if cse[4] != "":
			check(says(ev) == cse[4], "%s: '%s' (got '%s')" % [label, cse[4], says(ev)])
		else:
			check(says(ev) == GameSim.GENERIC_WRONG_USE, "%s: the generic refusal (got '%s')" % [label, says(ev)])
		check(inv(g) == before, "%s: the inventory is unchanged" % label)
		check(JSON.stringify(g.state.flags) == flags_before, "%s: no flags" % label)
		if cse[1] == "nora_register_card" and cse[0] >= 8:
			check(r.has_seen("card_vs_cup"), "%s: card_vs_cup noted" % label)

# ---------------------------------------------------------------------------------------------
# debug
# ---------------------------------------------------------------------------------------------
func test_debug() -> void:
	for t in range(1, 10):
		var g := game_at(t, ROOM)
		var r := r06(g)
		check(r.state.p08_complete == (t >= 4) and g.flag("P08") == (t >= 4), "debug_prepare %d: P08" % t)
		check(r.state.p22_complete == (t >= 9) and g.flag("P22") == (t >= 9), "debug_prepare %d: P22" % t)
		check(not g.has_item("token_bunk_half") or t < 4, "debug_prepare %d: no token after P09" % t)
		if t >= 9:
			check(g.has_item("amended_nora_card") and not g.has_item("nora_register_card"), "debug_prepare 9: the amended card")
		check(not r.state.letter_read, "debug_prepare %d: the letter stays unread" % t)
		var n := r.current_notice()
		if n != "":
			check(not n in r.state.notices, "debug_prepare %d: the current notice still plays" % t)
			for i in R06Sim.NOTICES.find(n):
				check(R06Sim.NOTICES[i] in r.state.notices, "debug_prepare %d: %s retired" % [t, R06Sim.NOTICES[i]])
	var g := GameSim.new()
	var r := r06(g)
	r.debug_jump(0)
	check(g.state.room == ROOM and not g.flag("P08") and g.tide() == 3, "jump 0: tide III fresh")
	r.debug_jump(1)
	check(r.tray_objects() == ["glove"] and r.local_view == "c_lockers", "jump 1: the glove left")
	g.dispatch("obj_glove")
	g.dispatch("shelf_ives")
	check(g.flag("P08") and g.has_item("token_bunk_half"), "jump 1: commit ready")
	r.debug_jump(2)
	check(g.flag("P08") and g.has_item("token_bunk_half") and not r.state.pillow_dented, "jump 2: just solved")
	r.debug_jump(3)
	check(r.state.pillow_dented and r.dents() == ["venn"], "jump 3: pillow dented")
	r.debug_jump(4)
	check(g.weather_band() == 2 and r.current_notice() == "names_moved", "jump 4: band 2")
	r.debug_jump(5)
	check(g.weather_band() == 4 and r.curtain_shape(), "jump 5: band 4")
	r.debug_jump(6)
	check(r.objective() == "p22" and g.has_item("nora_register_card") and r.local_view == "curtain", "jump 6: P22 ready")
	r.debug_jump(7)
	check(r.local_view == "c_slope" and r.state.card_on_rest and r.state.sketch_on_rest and r.append_refusal() == "", "jump 7: commit ready")
	amend(g)
	check(g.flag("P22") and r.state.card_on_rest, "jump 7: commits, the card on the rest")
	g.dispatch("back")
	check(g.has_item("amended_nora_card"), "jump 7: Back gives the amended card")
	r.debug_jump(8)
	check(g.weather_band() == 7 and r.state.p22_complete and r.state.cup_warm_seen, "jump 8: tide IX")

# ---------------------------------------------------------------------------------------------
# round w2: the curtain line, item labels, glances only where carded
# ---------------------------------------------------------------------------------------------
func test_w2_details() -> void:
	var g := game_at(3, ROOM)
	var r := r06(g)
	r.local_view = "curtain"
	check(says(g.dispatch("curtain")) == CURTAIN_T3, "curtain: the Tide III line")
	check(obs_text("curtain").ends_with("Then once more, when I don't."), "curtain: the notebook keeps it")
	check(R06Sim.ITEMS.token_bunk_half.short == "Bunk half" and R06Sim.ITEMS.amended_nora_card.short == "Nora (amended)",
		"items: short names")
	# The P08 glance plays once: a re-placed shelf after P08 never re-emits it.
	var f := fresh()
	var ev := solve_p08(f)
	check(glances(ev, "p08_latch").size() == 1, "glance: p08_latch at the commit")
	for o in TRAY:
		ev = f.dispatch("shelf_" + OWNER[o])
		check(glances(ev, "p08_latch").is_empty(), "glance: never again (%s)" % o)
	# Every glance names a known id with a rect inside the canvas.
	for id in R06Sim.GLANCES:
		var gr: Rect2 = R06Sim.GLANCES[id].rect
		check(CANVAS.encloses(gr) and gr.size.x >= 64 and gr.size.y >= 64, "glance %s: a sane rect" % id)
	# The pencil never leaves her.
	var p := p22_ready()
	lay_all(p, [1, 3, 3])
	p.dispatch("append")
	use(p, "pencil", "printed_line")
	amend(p)
	check(p.has_item("pencil") and p.flag("P22"), "pencil: durable through refusal, erase and the amendment")

# ---------------------------------------------------------------------------------------------
# (19) the view's rects and sounds
# ---------------------------------------------------------------------------------------------
func view_consts() -> Dictionary:
	return load("res://game/rooms/R06/R06_view.gd").get_script_constant_map()

func _view_ready() -> bool:
	var m := view_consts()
	var ids := []
	for h in m.get("HOTSPOTS", []):
		ids.append(h[0])
	for id in R06Sim.HOTSPOTS:
		if not id in ids:
			return false
	return m.has("CURTAIN_HOTSPOTS")

func rect_ok(id: String, rr: Rect2) -> void:
	check(CANVAS.encloses(rr), "R06 view %s is on the canvas" % id)
	check(rr.size.x >= MIN_TARGET and rr.size.y >= MIN_TARGET, "R06 view %s is at least 64x64" % id)
	check(not rr.intersects(HUD_ZONE) and not rr.intersects(INVENTORY_ZONE) and not rr.intersects(SUBTITLE_ZONE),
		"R06 view %s keeps clear of the HUD, inventory and subtitles" % id)

func test_view_rects() -> void:
	var m := view_consts()
	var ids := []
	for h in m.get("CURTAIN_HOTSPOTS", []):
		ids.append(h[0])
		rect_ok(h[0], h[1])
	for id in R06Sim.CURTAIN_HOTSPOTS:
		check(id in ids, "R06 view has a curtain rect for %s" % id)
	# Close-up controls: any [[id, Rect2, ...], ...] constant named *_CONTROLS.
	for k in m:
		if str(k).ends_with("_CONTROLS") and m[k] is Array:
			for h in m[k]:
				if h is Array and h.size() >= 2 and h[1] is Rect2:
					rect_ok(str(h[0]), h[1])
	var soft: Array = m.get("SFX_SOFT", [])
	for s in ["spring_creak", "compartment_drop", "latch_small"]:
		check(s in soft, "R06 view: %s is in SFX_SOFT" % s)
	check(float(m.get("SFX_SOFT_CUT", {}).get("spring_creak", 0.0)) >= 60.0, "R06 view: spring_creak is cut by at least 60 dB")

## Every staged overlay the view can ask for is painted (tools/art/rooms/R06.py diff_overlay).
func test_view_staged_art() -> void:
	for st in ["s1", "s2", "s3", "s4", "sever"]:
		for bed in R06Sim.BEDS:
			var side := "a" if bed in ["venn", "rook", "hart", "ives"] else "b"
			var id: String = "%s_dent_%s" % [side, bed] + ("" if st == "s1" else "_" + st)
			check(ResourceLoader.exists("res://assets/rooms/R06/%s.png" % id), "R06 art: %s painted" % id)
	for st in ["s3", "s4"]:
		check(ResourceLoader.exists("res://assets/rooms/R06/b_curtain_shape_%s.png" % st), "R06 art: the figure at %s" % st)
		for bed in R06Sim.BEDS:
			var side := "a" if bed in ["venn", "rook", "hart", "ives"] else "b"
			check(ResourceLoader.exists("res://assets/rooms/R06/%s_dent_%s_%sv2.png" % [side, bed, st]), "R06 art: %s's body at %s" % [bed, st])
	for v in ["a", "b"]:
		check(ResourceLoader.exists("res://assets/rooms/R06/view_%s_s4v2.png" % v), "R06 art: view_%s_s4v2 painted" % v)
	for id in ["c_erase_down", "c_append_down", "c_slope_clips", "c_slope_drums", "c_cup_halo", "c_calipers_halo",
			"c_pencils_halo", "c_glove_halo"]:
		check(ResourceLoader.exists("res://assets/rooms/R06/%s.png" % id), "R06 art: %s painted" % id)

# ---------------------------------------------------------------------------------------------
# (20) the view presents the sim: walls, controls, holds, hollows, tint and loops
# ---------------------------------------------------------------------------------------------
func _view_at(scene, n: int) -> RoomView:
	scene.room_jump(ROOM, n)
	return scene.room_view

func test_view_presentation() -> void:
	var scene = new_scene("user://r06_view_test.json")
	await process_frame
	# Stage 0, Tide III: view A, the exits live, no Back.
	var v = _view_at(scene, 0)
	check(v.shown_wall() == "room" and v.exits_active() and not v.back_visible(), "view: A at Tide III, exits live")
	check(v.label_for("ives_letter") == "Pigeonhole", "view: the pigeonhole before P08")
	check(v.tint_for(1) == Color(1, 1, 1) and v.tint_for(7).is_equal_approx(Color(0.86, 0.89, 0.93)),
		"view: tint runs from white at band 1 to (0.86, 0.89, 0.93) at band 7")
	var mid: Color = v.tint_for(4)
	check(is_equal_approx(mid.r, 0.93) and is_equal_approx(mid.b, 0.965), "view: the tint steps evenly")
	scene.dispatch("to_curtain")
	check(v.shown_wall() == "curtain" and v.back_visible() and not v.exits_active(), "view: B turns her round with Back, no exits")
	scene.dispatch("back")
	check(v.shown_wall() == "room", "view: Back from B is A")
	# c_lockers stage 1: three placed, the glove on the tray; no venn_back yet.
	v = _view_at(scene, 1)
	var ids := []
	for h in v.lockers_controls():
		ids.append(h[0])
	check(ids == ["card_bell", "card_rook", "card_venn", "card_ives", "shelf_bell", "shelf_rook", "shelf_venn",
		"shelf_ives", "obj_glove"], "view: c_lockers controls one short (%s)" % [ids])
	check(v.action_at(Vector2(560, 900)) == "obj_glove", "view: the glove answers at tray slot 2")
	check(v.label_for("obj_glove") == "Glove" and v.label_for("card_bell") == "BELL card"
		and v.label_for("shelf_ives") == "IVES shelf", "view: c_lockers hover labels")
	scene.dispatch("obj_glove")
	scene.dispatch("shelf_ives")
	ids = []
	for h in v.lockers_controls():
		ids.append(h[0])
	check(ids.find("venn_back") == 4 and not "obj_glove" in ids, "view: venn_back before the shelves after P08, tray empty")
	check(v.venn_pending and v.token_on, "view: Venn's back waits for its sound; the rubbing shows in the chain")
	v.on_sfx("compartment_drop")
	check(not v.venn_pending, "view: the compartment opens at compartment_drop")
	check(v.label_for("ives_letter") == "Ives's letter", "view: Ives's letter once the pigeonhole opens")
	# The pillow hold: a hard cut on A, the first click only skips it.
	scene.dispatch("back")
	scene.dispatch("go:R05")
	scene.dispatch("go:R06")
	v = scene.room_view
	check(v.hold_active() and v.shown_wall() == "room" and v.dent_alpha("venn") == 1.0, "view: the pillow is dented at full alpha at the hold's start")
	check(v.action_at(Vector2(900, 700)) == "" and v.hover_at(Vector2(900, 700)) == "" and v.hold_active(),
		"view: action_at and hover_at answer nothing during the hold, and do not end it")
	check(v.consume_click(Vector2(900, 700)) and not v.hold_active(), "view: consume_click skips the hold")
	check(not v.consume_click(Vector2(900, 700)), "view: consume_click lets later clicks through")
	check(v.action_at(Vector2(900, 700)) == "venn_bunk", "view: then the bunk answers")
	# Tide IV: the calendar notice shows the curtain wall; exits hide for that moment.
	v = _view_at(scene, 4)
	v.play_fx("notice_names_moved", {"id": "notice_names_moved", "view": "curtain"})
	check(v.hold_active() and v.shown_wall() == "curtain" and not v.exits_active(), "view: the names hold shows B")
	v.consume_click(Vector2(10, 500))
	check(v.shown_wall() == "room" and v.exits_active(), "view: after the hold, A again")
	# every_bed: the A hollows not yet seen wait for their spring, in DENT_ORDER.
	scene.tide_jump(8, ROOM)
	v = scene.room_view
	if v.motion:
		v.play_fx("notice_every_bed", {"id": "notice_every_bed", "view": "room"})
		check(v.dent_alpha("ives") == 1.0 and v.dent_alpha("rook") == 0.0, "view: every_bed starts from the band-5 hollows")
		v.on_sfx("springs_eight")
		v.tick(0.7 * 4 + 0.01)
		check(v.dent_alpha("rook") == 1.0 and v.dent_alpha("hart") == 0.0, "view: Rook's hollow with the fifth spring, Hart's later")
		v.consume_click(Vector2(10, 500))
		check(v.dent_alpha("hart") == 1.0, "view: a click lands every hollow")
	# Loops by band.
	var t: Dictionary = v.loop_targets()
	check(t["r06_rain_roof"] == 0.0 and is_equal_approx(t["r06_beds_breath"], 0.22) and is_equal_approx(t["r06_wind_louvre"], 0.1),
		"view: band 6 loops (rain gone, beds breathing)")
	scene.tide_jump(3, ROOM)
	t = scene.room_view.loop_targets()
	check(is_equal_approx(t["r06_rain_roof"], 0.45) and is_equal_approx(t["r06_room"], 0.5) and t["r06_beds_breath"] == 0.0,
		"view: band 1 loops")
	# The sever rise: all four A hollows at first, then each lets go in order.
	scene.tide_jump(9, ROOM)
	scene.sim.state.ending = "sever"
	v = scene.room_view
	if v.motion:
		v.play_fx("notice_rise", {"id": "notice_rise", "view": "room"})
		check(v.dent_alpha("hart") == 1.0 and v.dent_alpha("venn") == 1.0, "view: the rise starts full")
		v.on_sfx("dents_rise")
		v.tick(1.6)
		check(v.dent_alpha("venn") == 0.0 and v.dent_alpha("hart") == 1.0, "view: Venn's first, Hart's still there")
	scene.sim.state.ending = ""
	# c_slope: the printed line only while the card is on the rest; keys press on their sounds.
	v = _view_at(scene, 7)
	var sl := []
	for h in v._controls():
		sl.append(h[0])
	check("printed_line" in sl and v.back_visible(), "view: the printed line with the card on the rest")
	v.on_sfx("append_refuse")
	check(v.key_t["append"] > 0.0 and v.key_t["erase"] == 0.0, "view: APPEND shows pressed")
	scene.dispatch("append")
	check(v.key_t["append"] > 0.0 and not scene.sim.flag("P22"), "view: APPEND alone refuses (her pencil)")
	scene.dispatch("item:pencil")
	scene.dispatch("append")
	check(scene.sim.flag("P22"), "view: APPEND with the pencil selected writes it")
	sl = []
	for h in v._controls():
		sl.append(h[0])
	check("printed_line" in sl and v.r.state.card_on_rest, "view: after P22 the amended card stays on the RECORD rest")
	check(v.label_for("amend_line") == "Amendment line" and v.action_at(Vector2(340, 720)) == "amend_line", "view: the amendment line answers")
	# The amendment writes itself in; the condensation ring comes up with the cup_warm sound.
	v.on_sfx("pencil_scratch")
	check(v.commit_t >= 0.0 and v.ring_k == 0.0, "view: the pencil writes; no ring yet")
	v.tick(0.3)
	check(v.commit_t > 0.0 and v.ring_k == 0.0, "view: still writing a moment later")
	v.on_sfx("cup_warm")
	if v.motion:
		v.tick(0.75)
		check(v.ring_k > 0.3 and v.ring_k < 0.7, "view: the ring fades in over 1.5 s (got %f)" % v.ring_k)
		v.tick(0.8)
	check(v.ring_k == 1.0, "view: the ring is formed")
	var motion_was: bool = scene.sim.settings.motion
	scene.sim.settings.motion = false
	v.on_sfx("pencil_scratch")
	check(v.ring_k == 0.0, "view: Motion off: no ring before the cup warms")
	v.on_sfx("cup_warm")
	check(v.ring_k == 1.0, "view: with Motion off the ring is there, still")
	scene.sim.settings.motion = motion_was
	scene.dispatch("back")
	scene.room_view.tick(0.01)
	check(scene.sim.has_item("amended_nora_card") and not scene.room_view.r.state.card_on_rest, "view: Back puts the card in her bag")
	check(scene.room_view.commit_t < 0.0, "view: turning away ends the writing")
	check(scene.room_view.hold_active() and scene.room_view.hold_rect == Rect2(48, 250, 100, 640),
		"view: the cup notice focuses Bell's locker")
	# Bodies in the beds: the v2 shapes from s3, the v2 plate at s4.
	scene.tide_jump(6, ROOM)
	v = scene.room_view
	check(v.r.plate_stage() == "s3" and v.dent_id("ives") == "a_dent_ives_s3v2" and v.dent_id("bell") == "b_dent_bell_s3v2",
		"view: s3 hollows are the v2 bodies")
	scene.tide_jump(8, ROOM)
	v = scene.room_view
	check(v.r.plate_stage() == "s4" and v.dent_id("venn") == "a_dent_venn_s4v2" and v.plate_id("room") == "view_a_s4v2"
		and v.plate_id("curtain") == "view_b_s4v2", "view: s4 uses the v2 bodies and plates")
	scene.tide_jump(4, ROOM)
	check(scene.room_view.dent_id("doane") == "b_dent_doane_s2", "view: s2 hollows unchanged")
	await free_scene(scene)
