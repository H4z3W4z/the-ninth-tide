extends "res://tests/rooms/room_test_base.gd"
## R09, the Lantern Gallery: skeleton checks plus P15 (The Horizon Behind You), the
## upright-sea reveal, the band notices, the sever lines and O05 (the ruler).
##   godot --headless --path . --script tests/rooms/R09_test.gd

const ROOM := "R09"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P12"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 5

const P15_HINTS := [
	"The lantern's scope takes the specimen frame.",
	"The diagram says aim where the subject is, not where the water is. Look for something of hers.",
	"Every aperture has a bowl in it. The kitchen's ninth bowl was mended with a square riveted patch, and only the lens shows a rim from up here.",
	"Mount the frame, aim at STATION 3, check the square-patched bowl with the lens, then RECORD BEARING.",
]
const REVEAL := [
	"The horizon's standing up.",
	"It's not the sea any more. It's a surface, on end, and the rooms behind me are in it.",
	"The office lamp is in it. A warm point.",
	"Something passed across the whole of it. Like a lid.",
	"The rain has stopped where it was. It's waiting too.",
	"It hasn't closed again.",
	"One of the lit windows is this one. Someone in it is standing at the rail.",
]

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	await view_checks(ROOM)
	test_built()
	test_first_arrival()
	test_objectives()
	test_scope_open()
	test_record_empty()
	test_mount_unmount()
	test_apertures()
	test_lens_rims()
	test_no_answer_named()
	test_confirmation_resets()
	test_lens_before_mount()
	test_success_outputs()
	test_idempotent()
	test_selector_locked_roundtrip()
	test_reveal_on_back()
	test_deferred_reveal()
	test_frame_returned()
	test_mid_puzzle_save()
	test_malformed_save()
	test_vault_after_load()
	test_wrong_items()
	test_band_notices()
	test_sever()
	test_o05()
	test_glass_sfx()
	test_observation_ids()
	await test_hit_purity()
	await test_view_standing()
	test_unconfirmed_station()
	await test_refusal_flushed()
	test_canonical_chain()
	test_debug_jumps()
	test_invariant_over_play()

# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
func r9(g: GameSim) -> R09Sim:
	return g.room(ROOM)

func ids(ev: Array, type: String) -> Array:
	var out := []
	for e in ev:
		if e.type == type:
			out.append(e.get("id", ""))
	return out

func story_lines(ev: Array) -> Array:
	var out := []
	for e in ev:
		if e.type == "say" and e.story:
			out.append(e.text)
	return out

func index_of(ev: Array, type: String, id: String) -> int:
	for i in ev.size():
		if ev[i].type == type and ev[i].get("id", "") == id:
			return i
	return -1

func first_story_index(ev: Array) -> int:
	for i in ev.size():
		if ev[i].type == "say" and ev[i].story:
			return i
	return -1

func has_tide_fx(ev: Array) -> bool:
	return has_ev(ev, "fx", "tide")

## Tide V, standing in the gallery with P14 done and Nora's frame in hand.
func ready_p15() -> GameSim:
	var g := game_at(5, "R11")
	g.set_flag("P13")
	g.set_flag("P14")
	g.room("R07").reconcile()
	g.give("nora_frame")
	g.dispatch("go:R09")
	return g

## ready_p15 with the scope open and the frame mounted.
func mounted() -> GameSim:
	var g := ready_p15()
	g.dispatch("scope")
	g.dispatch("item:nora_frame")
	g.dispatch("mount")
	return g

func play_lens(g: GameSim, target := "scope_view") -> Array:
	g.dispatch("item:inspection_lens")
	return g.dispatch(target)

func solved() -> GameSim:
	var g := mounted()
	g.dispatch("sel_3")
	play_lens(g)
	g.dispatch("record")
	return g

func roundtrip(g: GameSim) -> GameSim:
	var g2 := GameSim.new()
	var ok := g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(ok, "save loads")
	return g2

func invariant(g: GameSim, where: String) -> void:
	var r := r9(g)
	if r.state.frame_mounted:
		check(r.local_view == "c_scope" and not g.has_item("nora_frame"),
			"frame_mounted implies c_scope and the frame out of the inventory (%s)" % where)

# ---------------------------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------------------------
func test_built() -> void:
	var g := GameSim.new()
	check(not g.is_unbuilt("R09"), "(a) R09 is built")
	check(not "SKELETON" in R09Sim.new().get_script().get_script_constant_map(), "(a) no SKELETON constant")
	var all: Array = R09Sim.HOTSPOTS + R09Sim.RAIL_HOTSPOTS
	for ctl in R09Sim.SCOPE_CONTROLS + R09Sim.RULER_CONTROLS:
		check(not ctl in all, "control %s is not a hotspot id" % ctl)
	var r := r9(g)
	check(r.is_closeup("c_scope") and r.is_closeup("c_ruler") and not r.is_closeup("rail") and not r.is_closeup("room"),
		"rail is a base view; c_scope and c_ruler are close-ups")

func test_first_arrival() -> void:
	var g := game_at(5, "R11")
	g.state.visited.erase("R09")
	var ev := g.dispatch("go:R09")
	check(g.state.room == "R09", "(b) walked into the gallery")
	var lines := story_lines(ev)
	check(lines.size() >= 2 and lines[0] == R09Sim.ARRIVAL and lines[0] == "The lantern gallery. The rain has stopped touching the rail.",
		"(b) arrival line exact: %s" % [lines])
	check(lines.size() >= 2 and lines[1] == "It falls a hand's width off it, all the way round. The pennant hangs dead, and the wind's loud.",
		"(b) second arrival line exact")
	check(has_ev(ev, "fx", "notice_dry_rail"), "(b) dry rail notice on first arrival")
	check(r9(g).has_seen("rail") and r9(g).has_seen("pennant"), "(b) rail and pennant observed")
	check(r9(g).local_view == "room", "(b) arrive leaves view room")
	g.dispatch("go:R11")
	ev = g.dispatch("go:R09")
	check(says(ev) == "", "(b) coming back plays no arrival line: %s" % says(ev))
	# Not first at tide V: the dry rail notice plays once.
	var g2 := game_at(5, "R11")
	ev = g2.dispatch("go:R09")
	check(has_ev(ev, "fx", "notice_dry_rail") and says(ev) == "The rail's still dry.", "(b) tide V notice: %s" % says(ev))
	ev = g2.dispatch("go:R11")
	ev = g2.dispatch("go:R09")
	check(says(ev) == "", "(b) notice once")
	# A debug first arrival late in the game still shows its band.
	var g3 := game_at(8, "R11")
	g3.state.visited.erase("R09")
	ev = g3.dispatch("go:R09")
	check(says(ev).begins_with(R09Sim.ARRIVAL) and has_ev(ev, "fx", "notice_lighthouse_inverted"),
		"(b) first arrival at band 6 also plays the band notice")

func test_objectives() -> void:
	var g := game_at(5, "R11")
	g.dispatch("go:R09")
	check(r9(g).objective() == "wait_p14", "(c) wait_p14 at tide V start")
	check(r9(g).objective_text() == "The scope's clamp is empty. Nora's frame is still being made on the laboratory bench.", "(c) wait_p14 text")
	var g2 := ready_p15()
	check(r9(g2).objective() == "p15", "(c) p15 once P14 is done")
	check(r9(g2).hint_tiers() == 4, "(c) R09 ladders have four tiers")
	for i in 4:
		check(r9(g2).hint_line(i) == P15_HINTS[i], "(c) p15 hint %d is the card's" % i)
	for o in R09Sim.HINTS:
		check(R09Sim.HINTS[o].size() == 4, "(c) %s has nudge, relationship, evidence, solution" % o)
	# the evidence tiers point at evidence, never the answer
	check(not "STATION 3" in P15_HINTS[2] and not "RECORD" in P15_HINTS[2], "(c) p15 evidence tier names no aperture or key")
	check(not "Short rises" in R09Sim.HINTS.wait_p14[2], "(c) wait_p14 evidence tier gives no order")
	var g3 := solved()
	check(r9(g3).objective() == "done", "(c) done after P15")
	for o in R09Sim.HINTS:
		for l in R09Sim.HINTS[o]:
			check(not "as far as the station goes" in l, "no skeleton hint lines")
	check(not "as far as" in R09Sim.ARRIVAL, "no skeleton arrival")

func test_scope_open() -> void:
	var g := ready_p15()
	var ev := g.dispatch("scope")
	var r := r9(g)
	check(r.local_view == "c_scope" and int(r.state.aperture) == 2, "(d) scope opens on SEA 2")
	check(r.has_seen("scope") and r.has_seen("view_sea"), "(d) scope and view_sea observed")
	check(2 in r.state.seen_views and r.state.scope_seen, "(d) seen_views has 2")
	check(has_ev(ev, "sfx", "scope_creak"), "(d) scope creak")
	check("It's on SEA 2. Open water, all the way out." in says(ev), "(d) first look line")
	g.dispatch("back")
	ev = g.dispatch("scope")
	check(says(ev) == "The scope.", "(d) later visit line")

func test_record_empty() -> void:
	var g := ready_p15()
	g.dispatch("scope")
	var inv: Array = g.state.inventory.duplicate()
	var ev := g.dispatch("record")
	check("clamp is empty" in says(ev), "(e) empty clamp refused: %s" % says(ev))
	check(has_ev(ev, "sfx", "key_refuse"), "(e) key refuse sfx")
	check(not g.flag("P15"), "(e) P15 unset")
	check(JSON.stringify(g.state.inventory) == JSON.stringify(inv), "(e) inventory unchanged")
	# Without P14 the key also stays up.
	var g2 := game_at(5, "R11")
	g2.dispatch("go:R09")
	g2.dispatch("scope")
	ev = g2.dispatch("record")
	check("clamp is empty" in says(ev) and not g2.flag("P15"), "(e) refused before P14")
	ev = g2.dispatch("mount")
	check(says(ev) == "The clamp takes a specimen frame. I haven't got one.", "(e) mount without a frame")

func test_mount_unmount() -> void:
	var g := ready_p15()
	g.dispatch("scope")
	var ev := g.dispatch("mount")
	check(says(ev) == "The clamp's open. Her frame would seat in it.", "(f) mount hint with the frame in hand")
	g.dispatch("item:nora_frame")
	ev = g.dispatch("mount")
	var r := r9(g)
	check(r.state.frame_mounted and not g.has_item("nora_frame"), "(f) frame taken onto the clamp")
	check(has_ev(ev, "sfx", "mount_clamp") and has_ev(ev, "fx", "frame_mount"), "(f) mount events")
	check(says(ev) == "It seats in the clamp. Her relation mark shows in the reticle.", "(f) mount line")
	invariant(g, "after mount")
	ev = g.dispatch("mount")
	check(not r.state.frame_mounted and g.has_item("nora_frame"), "(f) frame given back")
	check(has_ev(ev, "sfx", "clamp_release") and has_ev(ev, "fx", "frame_eject") and says(ev) == "I take her frame off the clamp.",
		"(f) unmount events")
	# Mount straight from the room view by using the frame on the scope.
	g.dispatch("back")
	g.dispatch("item:nora_frame")
	ev = g.dispatch("scope")
	check(r.local_view == "c_scope" and r.state.frame_mounted and not g.has_item("nora_frame"), "(f) frame on the scope mounts it")
	invariant(g, "frame on scope")
	# A view A hotspot while mounted unmounts first.
	ev = g.dispatch("diagram")
	check(not r.state.frame_mounted and g.has_item("nora_frame") and r.local_view == "room", "(f) leaving by a hotspot returns the frame")

func test_apertures() -> void:
	# LAND 1 and SEA 2, with or without the lens on their bowls: NO SUBJECT, mark dark.
	for a in [1, 2]:
		for with_lens in [false, true]:
			var g := mounted()
			if a != 2:
				g.dispatch("sel_%d" % a)
			if with_lens:
				play_lens(g)
			var ev := g.dispatch("record")
			var r := r9(g)
			check(R09Sim.NO_SUBJECT in says(ev), "(g) aperture %d lens %s: NO SUBJECT" % [a, with_lens])
			check(not g.flag("P15"), "(g) aperture %d lens %s: P15 false" % [a, with_lens])
			check(r.state.frame_mounted and not g.has_item("nora_frame"), "(g) aperture %d: frame still mounted" % a)
			check(not r.state.patch_confirmed and not r.relation_lit(), "(g) aperture %d: not confirmed, mark dark" % a)
			check(r.last_record == "nosubject" and has_ev(ev, "fx", "no_subject") and has_ev(ev, "sfx", "record_key"), "(g) no-subject events")
			check(r.has_seen("no_subject"), "(g) no_subject observed")
			# The miss line rotates.
			var ev2 := g.dispatch("record")
			check(says(ev2) != says(ev) and R09Sim.NO_SUBJECT in says(ev2), "(g) aperture %d: miss line rotates" % a)
			check(int(r.state.record_miss) == 2, "(g) record_miss counts")
	# STATION 3 without the lens: refused the same way, NO SUBJECT ON BEARING, the mark dark.
	var g := mounted()
	var ev := g.dispatch("sel_3")
	check(story_lines(ev).size() == 3 and has_ev(ev, "sfx", "glass_hum"), "(g) STATION 3 first look is a story chain")
	check(story_lines(ev)[0] == "Station, aperture three. The mess table.", "(g) STATION 3 names only what is in view: %s" % story_lines(ev)[0])
	check(r9(g).has_seen("view_station"), "(g) view_station observed")
	ev = g.dispatch("scope_view")
	check(says(ev) == "The mess table, in the glass. Bowls along it. I can't make out a rim from here.", "(g) unconfirmed scope view: %s" % says(ev))
	ev = g.dispatch("record")
	check(says(ev) == R09Sim.UNCONFIRMED + " | I can't tell from here which bowl it is."
		and not R09Sim.NO_SUBJECT in says(ev), "(g) STATION 3 unconfirmed: SUBJECT UNCONFIRMED: INSPECT, and which bowl: %s" % says(ev))
	check(R09Sim.UNCONFIRMED == "SUBJECT UNCONFIRMED: INSPECT", "(g) the unconfirmed stamp")
	check(r9(g).last_record == "nosubject" and has_ev(ev, "fx", "no_subject") and r9(g).has_seen("no_subject"),
		"(g) STATION 3 unconfirmed prints empty; no_subject observed")
	check(r9(g).state.frame_mounted and not g.has_item("nora_frame") and g.has_item("inspection_lens"),
		"(g) STATION 3 unconfirmed consumes nothing")
	var ev_again := g.dispatch("record")
	check(says(ev_again) == says(ev), "(g) STATION 3 unconfirmed says the same each time")
	check(not r9(g).relation_lit(), "(g) the relation mark stays dark")
	check(not g.flag("P15") and not g.has_item("nora_spatial_strip"), "(g) unconfirmed STATION 3 does not solve")
	# With the lens: the square patch, and the only line that confirms.
	ev = play_lens(g)
	var r := r9(g)
	check(r.state.patch_confirmed and r.has_seen("bowl_patch") and has_ev(ev, "fx", "lens_patch"), "(g) lens confirms the patch")
	check(story_lines(ev).size() >= 1 and story_lines(ev)[0] == "A square patch, riveted. A bowl, at the cross.", "(g) the confirming line: %s" % [story_lines(ev)])
	check(r.rim_shown() == "square" and r.relation_lit(), "(g) the square patch in the eyepiece; the mark lights")
	check(g.has_item("inspection_lens"), "(g) the lens is never consumed")
	ev = play_lens(g)
	check(says(ev) == "The square patch. Four rivets.", "(g) lens again")
	ev = g.dispatch("scope_view")
	check(says(ev) == "The square patch, riveted. Soup in it, steaming.", "(g) confirmed scope view")
	g.dispatch("record")
	check(g.flag("P15"), "(g) STATION 3 + lens + RECORD solves P15")

## The lens shows each aperture's bowl rim; only STATION 3's square riveted patch confirms.
func test_lens_rims() -> void:
	var expect := {1: ["round", "rim_land", "A round patch, soldered over the rim. Tin."],
		2: ["crack", "rim_sea", "A crack down the rim. No patch."]}
	for a in expect:
		var g := mounted()
		if a != 2:
			g.dispatch("sel_%d" % a)
		var r := r9(g)
		check(r.rim_shown() == "", "(g2) %d: no rim before the lens" % a)
		var ev := play_lens(g)
		check(says(ev) == expect[a][2], "(g2) %d: lens line %s" % [a, says(ev)])
		check(r.rim_shown() == expect[a][0] and r.has_seen(expect[a][1]), "(g2) %d: %s rim shown and observed" % [a, expect[a][0]])
		check(not r.state.patch_confirmed and not r.relation_lit(), "(g2) %d: no confirmation" % a)
		check(has_ev(ev, "fx", "lens_rim") and not has_ev(ev, "fx", "lens_patch"), "(g2) %d: lens_rim fx" % a)
		# re-aiming takes the lens off the rim
		g.dispatch("sel_%d" % (3 if a == 1 else 1))
		check(r.rim_shown() != expect[a][0], "(g2) %d: the rim goes with the aim" % a)
		var g2 := roundtrip(g)
		check(r9(g2).rim_shown() == "" and r9(g2).lens_rim == 0, "(g2) %d: the lens rim is never saved" % a)
	# Each aperture shows a bowl: the views say so.
	var g := mounted()
	var ev := g.dispatch("sel_1")
	check(says(ev) == R09Sim.SEL_LINES[1] and "bowl" in says(ev), "(g2) LAND 1 shows a tin bowl")
	ev = g.dispatch("sel_2")
	check(says(ev) == R09Sim.SEL_LINES[2] and "bowl" in says(ev), "(g2) SEA 2 shows a floating bowl")
	check("bowl" in R09Sim.OBSERVATIONS.view_land and "bowl" in R09Sim.OBSERVATIONS.view_sea and "bowls" in R09Sim.OBSERVATIONS.view_station,
		"(g2) the notebook has a bowl in every aperture")

## Aiming never names the answer: only the lens on STATION 3 says it.
func test_no_answer_named() -> void:
	var g := mounted()
	var all := []
	for a in ["sel_1", "scope_view", "sel_2", "scope_view", "sel_3", "scope_view", "sel_1", "sel_3", "record"]:
		all.append(says(g.dispatch(a)))
	for t in all:
		check(not "at the cross" in t and not "hers" in t and not "square" in t, "(g3) no answer named before the lens: %s" % t)
	for k in ["view_land", "view_sea", "view_station", "no_subject"]:
		check(not "at the cross" in R09Sim.OBSERVATIONS[k] and not "square" in R09Sim.OBSERVATIONS[k], "(g3) %s names no answer" % k)

func test_confirmation_resets() -> void:
	var g := mounted()
	g.dispatch("sel_3")
	play_lens(g)
	check(r9(g).state.patch_confirmed, "(h) confirmed")
	g.dispatch("sel_1")
	check(not r9(g).state.patch_confirmed, "(h) a selector clears the confirmation")
	var ev := g.dispatch("sel_3")
	check(says(ev) == "Station, aperture three. The mess table.", "(h) repeat STATION 3 line: %s" % says(ev))
	ev = g.dispatch("record")
	check(R09Sim.UNCONFIRMED in says(ev) and not g.flag("P15") and not r9(g).relation_lit(), "(h) RECORD refused after re-aiming")
	ev = g.dispatch("sel_3")
	check(says(ev) == "STATION 3. It's already there.", "(h) already there")

func test_lens_before_mount() -> void:
	var g := ready_p15()
	g.dispatch("scope")
	g.dispatch("sel_3")
	play_lens(g)
	check(r9(g).state.patch_confirmed and not r9(g).state.frame_mounted, "(i) confirmed before mounting")
	g.dispatch("item:nora_frame")
	g.dispatch("mount")
	g.dispatch("record")
	check(g.flag("P15"), "(i) lens before mount, then mount, then RECORD succeeds")

func test_success_outputs() -> void:
	var g := mounted()
	g.dispatch("sel_3")
	play_lens(g)
	var ev := g.dispatch("record")
	var r := r9(g)
	check(g.flag("P15") and r.state.p15_complete, "(j) P15 set")
	check(g.has_item("nora_spatial_strip") and g.has_item("nora_frame"), "(j) strip given and frame returned")
	check(not r.state.frame_mounted, "(j) frame unmounted")
	check(r.has_seen("nora_bearing"), "(j) nora_bearing seen")
	check(g.tide() == 6 and g.weather_band() == 4, "(j) tide VI, band 4 (got %d, %d)" % [g.tide(), g.weather_band()])
	check(has_tide_fx(ev), "(j) tide fx")
	var glance := {}
	for e in ev:
		if e.type == "fx" and e.id == "glance":
			glance = e
	check(not glance.is_empty() and JSON.stringify(glance.get("rect")) == JSON.stringify([52, 162, 1344, 466]) and glance.get("target") == "lens",
		"(j) glance at the view A glass")
	var k := index_of(ev, "sfx", "record_key")
	check(k >= 0 and k < first_story_index(ev), "(j) the key sounds before the first story line")
	check(index_of(ev, "sfx", "strip_feed") >= 0 and index_of(ev, "fx", "strip_feed") >= 0 and index_of(ev, "fx", "frame_eject") >= 0
		and index_of(ev, "sfx", "clamp_release") >= 0, "(j) strip feed and eject events")
	check(story_lines(ev) == ["Recorded. The strip feeds out: BEARING, STATION 3. SUBJECT, BELL, N.",
		"Her bearing isn't out at sea. It's in here, with the bowl."], "(j) record story lines exact")
	for l in REVEAL:
		check(not l in says(ev), "(j) no reveal text in RECORD: %s" % l)
	check(not has_ev(ev, "fx", "reveal_upright") and not r.state.reveal_seen, "(j) the reveal waits for back()")
	check(r.last_record == "recorded" and r.scope_scene() == "surface", "(j) last_record and scope scene")
	check(index_of(ev, "fx", "glance") == ev.size() - 1, "(j) the glance ends the commit")

func test_idempotent() -> void:
	var g := solved()
	var n: int = g.state.inventory.size()
	var ev := g.dispatch("record")
	check(g.state.inventory.size() == n, "(k) inventory size unchanged")
	check(not has_tide_fx(ev), "(k) no tide fx")
	check("Recorded already" in says(ev), "(k) recorded already")
	ev = g.dispatch("mount")
	check(says(ev) == "Empty. Her frame's with me.", "(k) mount after P15")
	g.dispatch("item:nora_frame")
	ev = g.dispatch("mount")
	check(says(ev) == "It's recorded. She doesn't need placing twice." and g.has_item("nora_frame"), "(k) frame not taken after P15")
	ev = g.dispatch("sel_1")
	check(says(ev) == "The bearing's recorded. I leave it where it is." and ids(ev, "sfx").is_empty() and not has_ev(ev, "fx", "aim"),
		"(k) the selector is locked after P15: %s" % says(ev))
	check(int(r9(g).state.aperture) == 3 and r9(g).state.patch_confirmed, "(k) aperture and confirmation untouched")
	ev = g.dispatch("scope_view")
	check(says(ev) == "The surface. Under the glass it looks like skin.", "(k) scope view after P15")
	ev = g.dispatch("strip_slot")
	check(says(ev) == "The strip's with me.", "(k) strip slot after P15")

## After P15 the selector is locked, so the live state is the loaded one: a save after a
## selector press round-trips byte-identical.
func test_selector_locked_roundtrip() -> void:
	var g := solved()
	g.dispatch("sel_2")
	var r := r9(g)
	check(int(r.state.aperture) == 3 and r.state.patch_confirmed, "(k2) sel_2 after P15 changes nothing")
	var before := JSON.stringify(g.to_dict())
	var g2 := roundtrip(g)
	check(JSON.stringify(g2.to_dict()) == before, "(k2) after P15 and sel_2, save and load are byte-identical")
	g2.dispatch("sel_1")
	check(JSON.stringify(roundtrip(g2).to_dict()) == JSON.stringify(g2.to_dict()), "(k2) and again after a load")

func test_reveal_on_back() -> void:
	var g := solved()
	var ev := g.dispatch("back")
	var r := r9(g)
	check(r.local_view == "room", "(l) back to the room")
	check(has_ev(ev, "fx", "reveal_upright") and has_ev(ev, "sfx", "deep_tone") and has_ev(ev, "sfx", "lid_pass"), "(l) reveal events")
	check(story_lines(ev) == REVEAL, "(l) the seven reveal lines exact: %s" % [story_lines(ev)])
	var delays := []
	for e in ev:
		if e.type == "say":
			delays.append(e.delay)
	check(delays == [0.6, 6.8, 9.6, 13.4, 15.4, 18.0, 21.0], "(l) reveal delays")
	check(story_lines(ev)[5] == "It hasn't closed again." and story_lines(ev)[6].begins_with("One of the lit windows is this one."),
		"(l) the window line comes after 'It hasn't closed again.'")
	var fx := {}
	var lid_sfx := -1.0
	for e in ev:
		if e.type == "fx":
			fx[e.id] = e
		elif e.type == "sfx" and e.id == "lid_pass":
			lid_sfx = e.delay
	check(fx.has("rain_freeze") and is_equal_approx(float(fx.rain_freeze.get("delay", -1)), 0.6),
		"(l) the rain freezes on the first line (fx rain_freeze, delay 0.6)")
	check(fx.has("lid_pass") and is_equal_approx(float(fx.lid_pass.get("delay", -1)), 13.4) and is_equal_approx(lid_sfx, 13.4),
		"(l) the lid passes on its line (fx lid_pass and its sfx at 13.4)")
	check(fx.has("hold_breath") and is_equal_approx(float(fx.hold_breath.get("delay", -1)), 21.0)
		and is_equal_approx(float(fx.hold_breath.get("seconds", -1)), 2.5), "(l) the core holds its breath for 2.5 s at 21.0, on the window line")
	check("someone is standing at its rail" in R09Sim.OBSERVATIONS.upright, "(l) the notebook keeps the window")
	check(index_of(ev, "fx", "reveal_upright") < index_of(ev, "fx", "rain_freeze"), "(l) the beat's fx follow reveal_upright")
	check("The rain has stopped where it was. It's waiting too." in R09Sim.OBSERVATIONS.upright, "(l) the notebook keeps the new line")
	check(r.rain_frozen(), "(l) from P15 on the rain is frozen")
	check(r.state.reveal_seen and r.has_seen("upright") and "upright" in r.state.notices, "(l) reveal seen, upright observed")
	ev = g.dispatch("back")
	check(not has_ev(ev, "fx", "reveal_upright") and says(ev) == "", "(l) a second back does not replay")
	g.dispatch("go:R11")
	ev = g.dispatch("go:R09")
	check(not has_ev(ev, "fx", "reveal_upright") and says(ev) == "", "(l) a band-4 arrival plays nothing after the reveal")
	# The reveal also comes from the notebook return, when she never pressed Back.
	var g2 := solved()
	g2.dispatch("back")
	var g3 := solved()
	r9(g3).local_view = "room"
	g3.dispatch("notebook")
	ev = g3.dispatch("back")
	check(story_lines(ev) == REVEAL, "(l) reveal on returning from the notebook")

func test_deferred_reveal() -> void:
	var g := solved()
	var g2 := roundtrip(g)
	check(g2.state.room == "R09" and g2.flag("P15") and not r9(g2).state.reveal_seen, "(m) loaded with the reveal still due")
	g2.dispatch("go:R11")
	var ev := g2.dispatch("go:R09")
	check(story_lines(ev) == REVEAL and has_ev(ev, "fx", "reveal_upright"), "(m) the reveal plays on arrival")
	g2.dispatch("go:R11")
	ev = g2.dispatch("go:R09")
	check(not has_ev(ev, "fx", "reveal_upright"), "(m) once")

func test_frame_returned() -> void:
	var g := mounted()
	g.dispatch("back")
	check(g.has_item("nora_frame") and not r9(g).state.frame_mounted, "(n) back with the frame mounted returns it")
	g = mounted()
	var ev := g.dispatch("go:R11")
	check(g.state.room == "R09", "(n) she does not leave with the frame in the clamp")
	check(r9(g).exit_block("R11") == "Her frame's still in the clamp.", "(n) exit block line")
	check(r9(g).state.frame_mounted, "(n) exit_block has no side effects")
	# Reach the exit from the room view with the clamp loaded (a tampered state): blocked.
	r9(g).local_view = "room"
	ev = g.dispatch("go:R11")
	check(g.state.room == "R09" and says(ev) == "Her frame's still in the clamp.", "(n) go:R11 while mounted is blocked")
	r9(g).local_view = "c_scope"
	# The plan's fast travel puts the close-up down first: the frame comes back.
	ev = g.dispatch("notebook")
	ev = g.dispatch("plan:R07")
	check(g.state.room == "R07" and g.has_item("nora_frame") and not r9(g).state.frame_mounted, "(n) plan travel returns the frame")
	# A save while mounted loads with the frame in the inventory.
	g = mounted()
	var g2 := roundtrip(g)
	check(g2.has_item("nora_frame") and not r9(g2).state.frame_mounted and r9(g2).local_view == "room",
		"(n) save while mounted loads with the frame in hand")

func test_mid_puzzle_save() -> void:
	var g := mounted()
	g.dispatch("sel_3")
	play_lens(g)
	var g2 := roundtrip(g)
	var r := r9(g2)
	check(int(r.state.aperture) == 3 and r.state.patch_confirmed, "(o) aperture 3 and the confirmation survive a save")
	check(g2.has_item("nora_frame") and not r.state.frame_mounted, "(o) frame back in hand")
	g2.dispatch("scope")
	g2.dispatch("item:nora_frame")
	g2.dispatch("mount")
	g2.dispatch("record")
	check(g2.flag("P15"), "(o) re-mount and RECORD succeeds")
	# A save that never reached the scope loads clean too.
	var g3 := roundtrip(ready_p15())
	check(not g3.flag("P15") and r9(g3).objective() == "p15", "(o) a P14 save loads on p15")

func _load_room_state(rs: Variant) -> GameSim:
	var g := ready_p15()
	var d := g.to_dict()
	d.rooms["R09"] = rs
	var g2 := GameSim.new()
	g2.from_dict(JSON.parse_string(JSON.stringify(d)))
	return g2

func test_malformed_save() -> void:
	var g := _load_room_state({"aperture": 7, "patch_confirmed": true, "seen_views": ["x", 9, 2, 2],
		"notices": ["bogus"], "frame_mounted": "yes", "record_miss": 500, "p15_complete": 1})
	var s: Dictionary = r9(g).state
	check(int(s.aperture) == 2, "(p) aperture 7 falls back to 2")
	check(not s.patch_confirmed, "(p) patch needs aperture 3")
	check(s.seen_views == [2], "(p) seen_views cleaned: %s" % [s.seen_views])
	check(s.notices == [], "(p) bogus notices dropped")
	check(not s.frame_mounted and not s.p15_complete and int(s.record_miss) == 99, "(p) types checked, miss clamped")
	check(not g.flag("P15"), "(p) no P15 from junk")
	g = _load_room_state({"aperture": 1, "patch_confirmed": true, "reveal_seen": true, "aperture_extra": 3})
	s = r9(g).state
	check(int(s.aperture) == 1 and not s.patch_confirmed and not s.reveal_seen, "(p) patch with aperture 1 cleared; reveal needs P15")
	g = _load_room_state({"aperture": 2.5, "record_miss": -3})
	s = r9(g).state
	check(int(s.aperture) == 2 and int(s.record_miss) == 0, "(p) fractional aperture rejected, miss clamped to 0")
	g = _load_room_state({"p15_complete": true, "aperture": 1, "frame_mounted": true})
	s = r9(g).state
	check(s.p15_complete and int(s.aperture) == 3 and s.patch_confirmed and 3 in s.seen_views and not s.frame_mounted,
		"(p) p15_complete derives the done arrangement")
	check(g.flag("P15"), "(p) reconcile sets P15 from the state")
	g = _load_room_state("garbage")
	check(JSON.stringify(r9(g).state) == JSON.stringify(r9(g).initial_state()), "(p) a non-dict loads fresh")

func test_vault_after_load() -> void:
	var g := solved()
	var g2 := roundtrip(g)
	check(g2.flag("P15"), "(q) P15 after load")
	check(g2.room("R07").vault_ajar(), "(q) R07 vault ajar after load")
	check(g2.exit_open("R07", "R10"), "(q) R07 -> R10 open")
	check("R10" in g2.reachable("R02"), "(q) R10 reachable from the office")

func test_wrong_items() -> void:
	var g := ready_p15()
	g.dispatch("item:nora_frame")
	var ev := g.dispatch("lens")
	check(says(ev) == "The frame goes on the scope's clamp." and g.has_item("nora_frame"), "(r) frame on the lens kept")
	var g2 := solved()
	g2.dispatch("item:nora_spatial_strip")
	ev = g2.dispatch("record")
	check(says(ev) == "It's printed. It doesn't go back in." and g2.has_item("nora_spatial_strip"), "(r) strip on record")
	g2.dispatch("back")
	g2.dispatch("item:pencil")
	ev = g2.dispatch("diagram")
	check(says(ev) == "Not mine to amend.", "(r) pencil on the diagram: %s" % says(ev))
	g2.dispatch("item:inspection_lens")
	ev = g2.dispatch("aperture_2")
	check(says(ev) == "Each iris has nine blades.", "(r) lens on an aperture")
	g2.dispatch("item:nora_spatial_strip")
	ev = g2.dispatch("lens")
	check(says(ev) == GameSim.GENERIC_WRONG_USE, "(r) an unhandled item gets the core refusal")

func test_band_notices() -> void:
	var expect := {6: ["upright", ["The horizon's standing up."]],
		7: ["no_sky", ["It fills the glass now. There's no sky left at the top."]],
		8: ["lighthouse_inverted", ["There's a lighthouse in it. Upside down.", "And the pennant's standing straight out. There's no wind."]],
		9: ["no_edge", ["It has no edge any more.", "And the lens has me in it. The right way up."]]}
	for t in expect:
		var g := game_at(t, "R11")
		var ev := g.dispatch("go:R09")
		var n: String = expect[t][0]
		var fx := []
		for f in ids(ev, "fx"):
			if f.begins_with("notice_"):
				fx.append(f)
		check(fx == ["notice_" + n], "(s) tide %d notice fx %s (got %s)" % [t, n, fx])
		check(says(ev) == " | ".join(expect[t][1]), "(s) tide %d notice lines: %s" % [t, says(ev)])
		check(not has_ev(ev, "fx", "reveal_upright"), "(s) tide %d: no reveal replay" % t)
		for e in ev:
			if e.type == "say":
				check(not e.story, "(s) notice lines are feedback")
		for i in R09Sim.NOTICES.find(n) + 1:
			check(R09Sim.NOTICES[i] in r9(g).state.notices, "(s) tide %d: %s marked" % [t, R09Sim.NOTICES[i]])
		g.dispatch("go:R11")
		ev = g.dispatch("go:R09")
		check(says(ev) == "", "(s) tide %d second entry silent" % t)
	var g := game_at(9, "R11")
	g.dispatch("go:R09")
	check(r9(g).has_seen("no_edge") and r9(g).has_seen("lens_ada"), "(s) no_edge observations")

func test_sever() -> void:
	var g := game_at(9, "R09")
	g.state.ending = "sever"
	var r := r9(g)
	check(r.sea_stage() == "sever" and r.pennant_mode() == "flap" and r.lens_reflection() == "ada_inv" and r.rail_wet(), "(t) sever helpers")
	check(r.current_notice() == "", "(t) no notices after an ending")
	g.dispatch("to_rail")
	var ev := g.dispatch("rail")
	check(says(ev) == "Wet. Rain beads along it and runs off." and r.has_seen("rail_wet"), "(t) the rail is wet")
	ev = g.dispatch("horizon")
	check(says(ev) == "A horizon. Level.", "(t) level horizon")
	ev = g.dispatch("pennant")
	check(says(ev) == "It flaps. Wind, at last.", "(t) pennant flaps")
	ev = g.dispatch("glass")
	check(has_ev(ev, "sfx", "glass_tap") and says(ev) == "Grey water, grey sky, and a line between them.", "(t) glass rings again")
	ev = g.dispatch("lens")
	check(says(ev) == "The lens. The gallery's in it, upside down. Me too.", "(t) lens with her in it")
	check(r.local_view == "room", "(t) lens hotspot goes to view A")

func test_o05() -> void:
	var g := ready_p15()
	g.dispatch("to_rail")
	var ev := g.dispatch("ruler")
	check(says(ev) == "A bare sill. Salt in the grain." and r9(g).has_seen("sill"), "(u) sill before P15")
	check(r9(g).local_view == "rail" and not g.flag("o05_found"), "(u) no ruler before P15")
	check(not r9(g).ruler_shown(), "(u) ruler hidden before P15")
	g = game_at(6, "R09")
	var r := r9(g)
	g.dispatch("to_rail")
	ev = g.dispatch("ruler")
	check(r.local_view == "c_ruler" and r.ruler_zoom == 0 and has_ev(ev, "sfx", "ruler_lift"), "(u) ruler opens c_ruler")
	check(says(ev) == "A boxwood rule on the sill. It wasn't here before.", "(u) ruler line")
	g.dispatch("zoom_in")
	g.dispatch("zoom_in")
	check(not g.flag("o05_found") and r.ruler_zoom == 2, "(u) not yet at 2")
	ev = g.dispatch("zoom_in")
	check(g.flag("o05_found") and r.has_seen("ruler_subdivisions"), "(u) three zooms find O05")
	check(story_lines(ev) == ["They go on.", "There's no bottom to it. Someone scratched every one."], "(u) O05 lines")
	ev = g.dispatch("zoom_in")
	check(says(ev) == "Still going." and r.ruler_zoom == 3, "(u) idempotent at 3")
	ev = g.dispatch("zoom_out")
	check(says(ev) == "Back out." and r.ruler_zoom == 2, "(u) zoom out")
	g.dispatch("zoom_out")
	ev = g.dispatch("zoom_out")
	check(says(ev) == "That's the whole rule." and r.ruler_zoom == 0, "(u) whole rule")
	g.dispatch("zoom_in"); g.dispatch("zoom_in")
	ev = g.dispatch("zoom_in")
	check(says(ev) == "Still going.", "(u) found once")
	g.dispatch("back")
	check(r.local_view == "rail", "(u) back from c_ruler to the rail")
	ev = g.dispatch("ruler")
	check(r.ruler_zoom == 0, "(u) zoom resets on entering")
	# The lens on the ruler opens it and zooms once.
	g.dispatch("back")
	g.dispatch("item:inspection_lens")
	ev = g.dispatch("ruler")
	check(r.local_view == "c_ruler" and r.ruler_zoom == 1, "(u) lens on the ruler zooms once")
	# Without the lens.
	g.take("inspection_lens")
	ev = g.dispatch("zoom_in")
	check(says(ev) == "I'd want a lens for this." and r.ruler_zoom == 1, "(u) no lens, no zoom")
	# Sever caps the zoom at 1.
	var g2 := game_at(9, "R09")
	g2.state.ending = "sever"
	g2.dispatch("to_rail")
	g2.dispatch("ruler")
	for i in 4:
		ev = g2.dispatch("zoom_in")
	check(r9(g2).ruler_zoom == 1 and not g2.flag("o05_found"), "(u) sever caps the zoom at 1")
	check(says(ev) == "Eighths. Under the lens, only eighths. And the grain of the wood.", "(u) sever ruler line")
	# reconcile never touches o05_found.
	g.set_flag("o05_found")
	var g3 := roundtrip(g)
	check(g3.flag("o05_found"), "(u) o05_found survives a load")
	r9(g3).reconcile()
	check(g3.flag("o05_found"), "(u) reconcile leaves o05_found alone")

func test_glass_sfx() -> void:
	for t in [5, 6, 7, 8, 9]:
		var g := game_at(t, "R09")
		g.dispatch("to_rail")
		var ev := g.dispatch("glass")
		var b := g.weather_band()
		var want := "glass_tap" if b <= 4 else "glass_tap_dead"
		check(ids(ev, "sfx") == [want], "(v) band %d glass %s (got %s)" % [b, want, ids(ev, "sfx")])
	var g := game_at(5, "R09")
	g.dispatch("to_rail")
	var ev := g.dispatch("glass")
	check(says(ev) == "The rain's running down outside. Slowly. Slower than rain." and r9(g).has_seen("glass"), "(v) band 3 glass line")
	g = game_at(7, "R09")
	g.dispatch("to_rail")
	ev = g.dispatch("glass")
	check(says(ev) == "I tapped it. It didn't ring." and r9(g).has_seen("glass_dead"), "(v) band 5 glass line")

## Every action in every view at every band, plus the full puzzle: all observations are known.
func _sweep(g: GameSim) -> void:
	for h in R09Sim.HOTSPOTS:
		g.dispatch(h)
		g.dispatch("back")
	g.dispatch("to_rail")
	for h in R09Sim.RAIL_HOTSPOTS:
		g.dispatch(h)
		if r9(g).local_view == "c_ruler":
			for ctl in R09Sim.RULER_CONTROLS + ["zoom_in", "zoom_in", "zoom_in"]:
				g.dispatch(ctl)
			g.dispatch("back")
		g.dispatch("to_rail")
	g.dispatch("to_lens")
	g.dispatch("scope")
	for ctl in R09Sim.SCOPE_CONTROLS:
		g.dispatch(ctl)
	for it in g.state.inventory.duplicate():
		for target in R09Sim.HOTSPOTS + R09Sim.RAIL_HOTSPOTS:
			g.dispatch("item:" + it)
			g.dispatch(target)
			invariant(g, "sweep %s on %s" % [it, target])
			g.dispatch("back")

func test_observation_ids() -> void:
	var games := [solved()]
	games[0].dispatch("back")
	for t in [5, 6, 7, 8, 9]:
		var g := game_at(t, "R11")
		g.dispatch("go:R09")
		_sweep(g)
		games.append(g)
	var sv := game_at(9, "R09")
	sv.state.ending = "sever"
	_sweep(sv)
	games.append(sv)
	var g := mounted()
	g.dispatch("sel_1"); g.dispatch("record"); g.dispatch("scope_view"); play_lens(g)
	g.dispatch("sel_2"); play_lens(g)
	g.dispatch("sel_3"); play_lens(g); g.dispatch("record"); g.dispatch("back")
	_sweep(g)
	games.append(g)
	var all := {}
	for gg in games:
		for o in r9(gg).seen():
			check(R09Sim.OBSERVATIONS.has(o), "(w) observation %s is declared" % o)
			all[o] = true
	for o in R09Sim.OBSERVATIONS:
		check(all.has(o), "(w) observation %s is reachable in play" % o)

func test_hit_purity() -> void:
	var scene = new_scene("user://room_test_R09_purity.json")
	await process_frame
	scene.enter_jump(ROOM)
	await process_frame
	var v: RoomView = scene.room_view
	var before := JSON.stringify(scene.sim.to_dict())
	var lv: String = scene.sim.room(ROOM).local_view
	var pts := []
	for x in range(40, 1448, 120):
		for y in range(100, 990, 110):
			pts.append(Vector2(x, y))
	for p in pts:
		var a1: String = scene.action_at(p)
		var a2: String = scene.action_at(p)
		var h1: String = v.hover_at(p)
		var h2: String = v.hover_at(p)
		check(a1 == a2 and h1 == h2, "(x) hit-tests are stable at %s" % p)
	check(JSON.stringify(scene.sim.to_dict()) == before and scene.sim.room(ROOM).local_view == lv, "(x) hit-tests change nothing")
	await free_scene(scene)

## View A after the reveal: the P15 stage overlay, frozen rain, the lid's sweep and its line,
## the lens overlay at 0.35; the hush after the hold; deep_tone's duck under lid_pass; the beds.
func test_view_standing() -> void:
	var scene = new_scene("user://room_test_R09_standing.json")
	await process_frame
	var motion_on: bool = scene.sim.settings.motion
	scene.tide_jump(5, ROOM)
	await process_frame
	var v = scene.room_view
	check(v.standing_plate() == "" and v.lens_alpha() == 1.0 and not v.rain_frozen(), "(vw) before P15: the old sea, the rain falling, lens at full")
	for t in [6, 7, 8, 9]:
		scene.tide_jump(t, ROOM)
		await process_frame
		v = scene.room_view
		var want: String = {6: "p15_plane_r3", 7: "p15_plane_r3", 8: "p15_plane_r3_b6", 9: ""}[t]
		check(v.standing_plate() == want, "(vw) tide %d plate %s (got %s)" % [t, want, v.standing_plate()])
		check(want == "" or ResourceLoader.exists("res://assets/stages/R09/%s.png" % want), "(vw) %s exists" % want)
		check(want == "" or v._tex(want) != null, "(vw) %s loads" % want)
		var rooms: String = v.rooms_plate()
		check(rooms == want.replace("plane", "rooms") and (rooms == "" or v._tex(rooms) != null), "(vw) tide %d: the rooms overlay %s loads" % [t, rooms])
		check(want == "" or (v.lid_line_k() == 1.0 and v.surface_rain_alpha() == 0.0),
			"(vw) tide %d: the lid line rests for good; no streaks over the surface" % t)
		check(v.lens_alpha() == 0.35 and v.lid_y() < 0.0, "(vw) tide %d: no lid band, lens 0.35" % t)
		check(v.plate_k() == (1.0 if want != "" else 0.0), "(vw) tide %d: plate settled" % t)
		for m in [true, false]:
			scene.sim.settings.motion = m
			check(v.rain_frozen() and v.rain_speed() == 0.0, "(vw) tide %d, Motion %s: the rain is drawn frozen" % [t, m])
			var o1: float = v.rain_offset()
			scene.time += 3.7
			check(v.rain_offset() == o1, "(vw) tide %d, Motion %s: a frozen streak never moves" % [t, m])
		scene.sim.settings.motion = motion_on
	for m in [true, false]:
		scene.sim.settings.motion = m
		await _beat_checks(scene, m)
	scene.sim.settings.motion = motion_on
	# deep_tone's duck under lid_pass: 0 dB, ramp from 2.0 s, -8 dB, ramp out after 8.0 s
	var V = load("res://game/rooms/R09/R09_view.gd")
	check(V.deep_duck_db(0.0) == 0.0 and V.deep_duck_db(1.99) == 0.0, "(vw) no duck before 2.0 s")
	check(is_equal_approx(V.deep_duck_db(2.15), -4.0), "(vw) a 0.3 s ramp in")
	check(is_equal_approx(V.deep_duck_db(2.3), -8.0) and V.deep_duck_db(5.0) == -8.0 and V.deep_duck_db(8.0) == -8.0, "(vw) -8 dB from 2.3 to 8.0 s")
	check(is_equal_approx(V.deep_duck_db(8.15), -4.0) and V.deep_duck_db(8.31) == 0.0, "(vw) a 0.3 s ramp out")
	check(V.LOOP_DB.b3.r09_wind == -3.0 and V.LOOP_DB.b3.r09_rain_glass == -13.0 and V.LOOP_DB.b4.r09_wind == -5.0
		and V.LOOP_DB.b5.r09_room == -10.0 and not V.LOOP_DB.b5.has("r09_wind"), "(vw) the wind bed levels")
	check(V.LOOP_DB.b5.r09_glass_air == -14.0 and V.LOOP_DB.b6.r09_glass_air == -12.0 and V.LOOP_DB.b7.r09_glass_air == -12.0
		and V.LOOP_DB.b5.r09_surface == -17.0 and V.LOOP_DB.b6.r09_surface == -14.0 and V.LOOP_DB.b7.r09_surface == -12.0,
		"(vw) glass air at b5-b7, the surface 4 dB up")
	check(ResourceLoader.exists("res://assets/audio/R09/r09_glass_air.wav"), "(vw) r09_glass_air is built")
	await free_scene(scene)

## The P15 beat played for real (the scene's own dispatch), with Motion `m`.
func _beat_checks(scene, m: bool) -> void:
	scene.room_jump(ROOM, 4)
	await process_frame
	scene.dispatch("record")
	scene.dispatch("back")
	var v = scene.room_view
	var tag := "Motion %s" % ("on" if m else "off")
	v.tick(0.0)
	# the beat follows its lines in the core's queue: here they wait behind RECORD's own lines
	var z: float = v.freeze_at - 0.6
	check(v.reveal_running() and z >= 0.0 and is_equal_approx(v.lid_at - z, 13.4)
		and is_equal_approx(v.hush_at - z, 23.5), "(vb) %s: the beat keeps the sim's spacing, on its lines (+%.2f s)" % [tag, z])
	var due0 := -1.0
	for l in scene.lines:
		if l.text == "The horizon's standing up.":
			due0 = l.due
	check(due0 >= 0.0 and is_equal_approx(v.beat_origin + v.freeze_at, due0), "(vb) %s: the rain stops as the first line comes up" % tag)
	v.reveal_t = z + 0.3
	check(v.plate_k() == 0.0 and not v.rain_frozen(), "(vb) %s: before the first line, the old sea and the rain falling" % tag)
	v.tick(0.4)   # across the first line: "The horizon's standing up."
	check(v.rain_frozen() and v.rain_speed() == 0.0, "(vb) %s: the rain stops on the line" % tag)
	var o1: float = v.rain_offset()
	scene.time += 2.0
	v.tick(0.5)
	check(v.rain_offset() == o1, "(vb) %s: and stays exactly where it stopped" % tag)
	check(v.standing_plate() == "p15_plane_r3" and v.rooms_plate() == "p15_rooms_r3", "(vb) %s: the surface on end from the line" % tag)
	if m:
		check(v.plate_k() > 0.0 and v.plate_k() < 1.0, "(vb) Motion on: it comes up the glass")
		check(v.surface_rain_alpha() > 0.0 and v.surface_rain_alpha() < 1.0, "(vb) Motion on: the streaks over it fading (%f)" % v.surface_rain_alpha())
		var o0: float = v.p15_chop_offset()
		scene.time += 1.0
		check(is_equal_approx(v.p15_chop_offset() - o0, 6.0), "(vb) Motion on: the whitecaps drift 6 px/s")
	else:
		check(v.plate_k() == 1.0, "(vb) Motion off: it is simply there")
		check(v.surface_rain_alpha() == 0.0, "(vb) Motion off: the streaks over it are gone at once")
		var o0: float = v.p15_chop_offset()
		scene.time += 1.0
		check(v.p15_chop_offset() == o0, "(vb) Motion off: the whitecaps stand still")
	check(is_equal_approx(v.P15_CHOP_A, 0.40), "(vb) the whitecaps at 0.40")
	v.reveal_t = z + 0.6 + 1.01
	check(v.surface_rain_alpha() == 0.0, "(vb) %s: after 1.0 s no streak shows over the surface" % tag)
	v.reveal_t = z + 13.3
	check(v.lid_y() < 0.0 and v.lid_line_k() == 0.0, "(vb) %s: no lid before 13.4" % tag)
	var ys := []
	for k in 5:
		v.reveal_t = z + 13.4 + 0.001 + k * (0.6 - 0.002) / 4.0
		ys.append(v.lid_y())
	var mid: float = v.A_GLASS.get_center().y
	if m:
		var mono := true
		for k in 4:
			mono = mono and ys[k + 1] > ys[k]
		check(mono and ys[0] <= v.A_GLASS.position.y - v.LID_H / 2.0 + 3.0 and ys[4] >= v.A_GLASS.end.y + v.LID_H / 2.0 - 3.0,
			"(vb) Motion on: the band sweeps the whole glass top to bottom in 0.6 s: %s" % [ys])
	else:
		check(ys.all(func(y): return is_equal_approx(y, mid)), "(vb) Motion off: the band covers the glass for 0.6 s")
	check(is_equal_approx(v.LID_H, v.A_GLASS.size.y) and v.LID_COL.b > v.LID_COL.r and v.LID_COL.v < 0.2,
		"(vb) a dark storm-navy band as tall as the glass")
	check(is_equal_approx(v.LID_REST_Y - v.A_GLASS.get_center().y, 60.0) and v.LINE_COL.v < v.LID_COL.v + 0.01,
		"(vb) the lid line rests a hand-width (60 px) under the old middle line, darker")
	v.reveal_t = z + 13.42
	check(v.lid_line_k() == 0.0, "(vb) %s: no lid line while the band is still above it" % tag)
	v.reveal_t = z + 14.01
	check(v.lid_y() < 0.0 and v.lid_line_k() == 1.0, "(vb) %s: after the band, the line" % tag)
	v.reveal_t = z + 23.4
	check(v.lid_line_k() == 1.0, "(vb) %s: the line stays through the hold" % tag)
	check(not v.hushed and v.loop_targets().get("r09_room", 0.0) > 0.0, "(vb) %s: the bed until the hold" % tag)
	v.tick(0.2)   # across 23.5: the hold is over
	check(v.hushed, "(vb) %s: hushed after the hold" % tag)
	var lt: Dictionary = v.loop_targets()
	var loud := []
	for id in lt:
		if lt[id] > 0.0:
			loud.append(id)
	loud.sort()
	check(loud == ["r09_glass_air", "r09_pressure"], "(vb) %s: after the hold only the pressure and the glass air: %s" % [tag, loud])
	check(is_equal_approx(linear_to_db(lt.r09_pressure), -20.0) or is_equal_approx(linear_to_db(lt.r09_pressure), -26.0)
		or is_equal_approx(linear_to_db(lt.r09_pressure), -24.0), "(vb) %s: the pressure 6 dB under its level" % tag)
	v.reveal_t = v.reveal_len() + 0.01
	v.tick(0.01)
	check(not v.reveal_running() and v.hushed and v.rain_frozen() and v.plate_k() == 1.0 and v.lid_line_k() == 1.0
		and v.surface_rain_alpha() == 0.0, "(vb) %s: after the beat, still frozen, still the overlay, the lid line resting, still hushed" % tag)
	# a save/load after P15 keeps the frozen rain and the overlay
	var g2 := GameSim.new()
	check(g2.from_dict(JSON.parse_string(JSON.stringify(scene.sim.to_dict()))), "(vb) %s: the save loads" % tag)
	scene.sim.from_dict(g2.to_dict())
	scene._mount_room()
	scene._reset_presentation()
	await process_frame
	v = scene.room_view
	check(r9(scene.sim).state.reveal_seen and v.standing_plate() == "p15_plane_r3" and v.plate_k() == 1.0
		and v.lid_line_k() == 1.0 and v.rain_frozen() and v.rain_speed() == 0.0, "(vb) %s: a load after P15 keeps the overlay and the frozen rain" % tag)

## P0: RECORD on STATION 3 before the lens: SUBJECT UNCONFIRMED: INSPECT, and which bowl; on
## LAND 1, NO SUBJECT ON BEARING. Nothing is consumed either way.
func test_unconfirmed_station() -> void:
	var g := mounted()
	g.dispatch("sel_3")
	var ev := g.dispatch("record")
	var lines := []
	for e in ev:
		if e.type == "say":
			lines.append(e.text)
	check(lines == [R09Sim.UNCONFIRMED, "I can't tell from here which bowl it is."], "(u) record at 3 without the lens: %s" % [lines])
	check(not g.flag("P15") and r9(g).state.frame_mounted and g.has_item("inspection_lens") and r9(g).has_seen("no_subject"),
		"(u) nothing consumed; no_subject observed")
	g.dispatch("sel_1")
	ev = g.dispatch("record")
	check(R09Sim.NO_SUBJECT in says(ev) and not R09Sim.UNCONFIRMED in says(ev), "(u) record at 1: NO SUBJECT ON BEARING")
	g.dispatch("sel_3")
	play_lens(g)
	g.dispatch("record")
	check(g.flag("P15"), "(u) then the lens and RECORD solve it")

## P2: RECORD before the lens, the lens, RECORD, Back, all at once, while STATION 3's first
## look is still being told (so the core queues the refusal behind it, after the lens's own
## confirmation): the commit drops the refusal still queued, so nothing refused comes after the
## confirmation or "Recorded.", and the reveal ends on "It hasn't closed again." and the window
## line. The stamp reads in the view.
func test_refusal_flushed() -> void:
	var scene = new_scene("user://room_test_R09_refusal.json")
	await process_frame
	scene.room_jump(ROOM, 2)
	await process_frame
	var v = scene.room_view
	for i in 80:
		scene._process(0.1)
	scene.shown_log.clear()
	for a in ["scope", "item:nora_frame", "mount", "sel_3", "record"]:
		scene.dispatch(a)
	check(v.no_subject_text() == R09Sim.UNCONFIRMED, "(rf) the STATION 3 stamp reads SUBJECT UNCONFIRMED: INSPECT")
	for a in ["item:inspection_lens", "scope_view", "record"]:
		scene.dispatch(a)
	await process_frame   # the deferred flush
	var queued := []
	for l in scene.lines:
		queued.append(l.text)
	var refusals: Array = v.refusal_lines()
	check(not queued.any(func(t): return t in refusals), "(rf) no refusal left queued after the commit: %s" % [queued])
	scene.dispatch("back")
	for i in 900:
		if scene.lines.is_empty() and scene.cur_text == "" and scene.pending_fx.is_empty():
			break
		scene._process(0.1)
	var log: Array = scene.shown_log
	var rec := -1
	var conf := -1
	for i in log.size():
		if str(log[i]).begins_with("Recorded."):
			rec = i
		if conf < 0 and log[i] == R09Sim.PATCH_LINE:
			conf = i
	check(rec >= 0 and conf >= 0 and conf < rec, "(rf) the confirmation, then 'Recorded.', were shown: %s" % [log])
	var after := log.slice(conf + 1) if conf >= 0 else []
	check(not after.any(func(t): return t in refusals), "(rf) no refusal after the confirmation or 'Recorded.': %s" % [log])
	check(log.size() >= 2 and log[log.size() - 2] == "It hasn't closed again."
		and log[log.size() - 1] == R09Sim.REVEAL_LINES[6][1], "(rf) the reveal ends on 'It hasn't closed again.' and the window: %s" % [log])
	await free_scene(scene)

func test_canonical_chain() -> void:
	var g := game_at(5, "R11")
	g.set_flag("P13")
	g.set_flag("P14")
	g.room("R07").reconcile()
	g.give("nora_frame")
	for a in ["go:R09", "scope", "item:nora_frame", "mount", "sel_3", "item:inspection_lens", "scope_view"]:
		g.dispatch(a)
		invariant(g, "chain " + a)
	check(not g.flag("P15"), "(y) not before RECORD")
	var ev := g.dispatch("record")
	check(g.flag("P15") and has_tide_fx(ev), "(y) the canonical chain solves P15")
	var g2 := roundtrip(g)
	check(JSON.stringify(g2.to_dict()) == JSON.stringify(roundtrip(g2).to_dict()), "(y) the save round-trips identically")

func test_debug_jumps() -> void:
	for n in range(1, 10):
		var g := GameSim.new()
		r9(g).debug_jump(n)
		var r := r9(g)
		check(g.state.room == "R09", "(z) jump %d lands in R09" % n)
		check(r.last_record == "" and r.ruler_zoom == 0, "(z) jump %d clears transients" % n)
		invariant(g, "jump %d" % n)
		match n:
			1:
				check(g.flag("P12") and not g.flag("P14") and g.weather_band() == 3 and r.local_view == "room", "(z) 1: tide V fresh")
				check(r.objective() == "wait_p14", "(z) 1: waiting on P14")
			2:
				check(g.flag("P14") and g.has_item("nora_frame") and r.objective() == "p15" and r.local_view == "room", "(z) 2: frame in hand")
				check("dry_rail" in r.state.notices, "(z) 2: dry rail marked")
			3, 4:
				check(r.local_view == "c_scope" and r.state.frame_mounted and not g.has_item("nora_frame") and int(r.state.aperture) == 3,
					"(z) %d: mounted on STATION 3" % n)
				check(r.state.patch_confirmed == (n == 4), "(z) %d: patch confirmation" % n)
				var ev := g.dispatch("record")
				check(g.flag("P15") == (n == 4), "(z) %d: RECORD %s" % [n, "wins" if n == 4 else "is refused"])
			_:
				var t := n + 1 if n < 9 else 9
				check(g.flag("P15") and g.tide() == mini(t, 9), "(z) %d: tide %d (got %d)" % [n, t, g.tide()])
				var want_band: int = [0, 0, 0, 0, 0, 4, 5, 6, 7, 7][n]
				check(g.weather_band() == want_band, "(z) %d: band %d (got %d)" % [n, want_band, g.weather_band()])
				check(r.state.reveal_seen and g.has_item("nora_spatial_strip") and g.has_item("nora_frame"), "(z) %d: P15 behind her" % n)
				check(r.local_view == ("rail" if n == 9 else "room"), "(z) %d: view" % n)
		# Every stage's save loads.
		var g2 := roundtrip(g)
		check(g2.state.room == "R09", "(z) jump %d save loads in R09" % n)
		invariant(g2, "jump %d load" % n)

## The invariant holds through a scripted play with frames, selectors and exits mixed in.
func test_invariant_over_play() -> void:
	var g := ready_p15()
	var acts := ["scope", "item:nora_frame", "mount", "sel_1", "record", "to_rail", "scope", "item:nora_frame",
		"scope", "sel_2", "back", "item:nora_frame", "scope", "glass", "to_lens", "scope", "mount", "mount",
		"item:nora_frame", "mount", "notebook", "back", "sel_3", "item:inspection_lens", "scope_view", "record", "back"]
	for a in acts:
		g.dispatch(a)
		invariant(g, a)
	check(g.flag("P15") and g.has_item("nora_frame") and r9(g).state.reveal_seen, "invariant play ends solved with the frame")
