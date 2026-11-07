extends "res://tests/rooms/room_test_base.gd"
## R10, the Records Vault: P16 (the 1927 contact sheet), P18 (Rook's folders), P23 (the Index
## model), the escalation matrix and notices, O06, saves, debug stages and the two base views.
##   godot --headless --path . --script tests/rooms/R10_test.gd

const ROOM := "R10"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P15"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 6
const VIEW_PATH := "res://game/rooms/R10/R10_view.gd"

## Reference tables written from the cards, independent of R10Sim's constants.
const REF_SOLUTION := ["B", "D", "A", "C"]
const REF_FIRST := {"B": 1, "D": 5, "A": 9, "C": 13}
const REF_LAMPS := {"B": 8, "D": 6, "A": 3, "C": 0}
const REF_WORD := {8: "Eight", 6: "Six", 3: "Three", 0: "None"}
const REF_WORD_LC := {8: "eight", 6: "six", 3: "three", 0: "none"}
const RECS := ["nora_frame", "nora_spatial_strip", "nora_register_card"]
const REF_HOME := {"nora_frame": "BODY", "nora_spatial_strip": "PLACE", "nora_register_card": "NAME"}
const FOLDER_IDS := {"BODY": "fold_body", "PLACE": "fold_place", "NAME": "fold_name"}
const REF_MISMATCH := {
	"nora_frame/PLACE": "A breath isn't a bearing.", "nora_frame/NAME": "A breath isn't a name.",
	"nora_spatial_strip/BODY": "A bearing isn't a body.", "nora_spatial_strip/NAME": "A bearing isn't a name.",
	"nora_register_card/BODY": "A name isn't a body.", "nora_register_card/PLACE": "A name isn't a place.",
}
const SHUTTER := "A brass shutter over the terminals. A hollow circle on it: OBSERVER. No keyhole this side. It opens from the other side."
const CLIP_NEEDS := "The edge needs clamping flat. My chart clips would hold it."
const CLIP_ONLY := "Only the chart clips will hold the edge."
const NOT_ALL_IN := "Four panels, four places. Not all of them are in."
const CLIP_DONE := "Clipped. Frames one to sixteen, unbroken."
const REGISTERED := "The cover's registered to the edge. It won't slide until the edge is clipped."
const HOLDS := "Clipped. It holds."
const RECORDS_BACK := "I take Nora's records back with me."

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	test_constants()
	test_arrival()
	test_p16_orders()
	test_p16_incomplete()
	test_p16_clip_items()
	test_p16_cover_gate()
	test_p16_success()
	test_p16_idempotent()
	test_p16_locked_after_clip()
	test_p16_panel_handling()
	test_p16_save_load()
	test_p18_needs_session()
	test_p18_exhaustive()
	test_p18_success()
	test_p18_returns()
	test_p18_wheels()
	test_p18_records_untouched()
	test_p17_p18_orders()
	test_p18_lines()
	test_p23_shutter()
	test_p23_combinations()
	test_p23_reset()
	test_p23_no_side_effects()
	test_p23_idempotent()
	test_p23_save_load()
	test_escalation()
	test_notices()
	test_hotspots_every_band()
	test_o06()
	test_catalogue_objects()
	test_room_objects()
	test_use_item()
	test_objectives_hints()
	test_debug_prepare()
	test_debug_jumps()
	test_flag_adoption()
	test_malformed_saves()
	test_chain_scripts()
	if _view_ready():
		await view_checks(ROOM)
	else:
		print("SKIP: R10 view_checks: the R10 view does not yet declare rects for every sim hotspot (view team)")

# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
func r10(g: GameSim) -> R10Sim:
	return g.room(ROOM) as R10Sim

## Standing in the vault, P15 set, with the clips and Nora's three records.
func fresh() -> GameSim:
	var g := with_flags(["P15"], ROOM)
	for it in ["chart_clips"] + RECS:
		g.give(it)
	return g

func snapshot(g: GameSim) -> String:
	return JSON.stringify([g.state.flags, g.state.inventory, g.value("ending_choice"), g.value("endings_seen")])

func count_ev(ev: Array, type: String, id: String) -> int:
	var n := 0
	for e in ev:
		if e.type == type and e.get("id", "") == id:
			n += 1
	return n

func play(g: GameSim, actions: Array) -> Array:
	var ev: Array = []
	for a in actions:
		ev = g.dispatch(a)
	return ev

func use(g: GameSim, item: String, target: String) -> Array:
	g.dispatch("item:" + item)
	return g.dispatch(target)

func roundtrip(g: GameSim) -> GameSim:
	var t := GameSim.new()
	check(t.from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))), "roundtrip loads")
	return t

func place(g: GameSim, order: Array) -> void:
	for k in order.size():
		if order[k] != "":
			g.dispatch("loose_" + order[k].to_lower())
			g.dispatch("slot_%d" % (k + 1))

func solve_p16(g: GameSim) -> Array:
	g.dispatch("contact_table")
	place(g, REF_SOLUTION)
	use(g, "chart_clips", "clip")
	return g.dispatch("cover")

## P16 solved by play, standing at the open folders.
func folders_game() -> GameSim:
	var g := fresh()
	solve_p16(g)
	play(g, ["back", "to_catalogue", "folders"])
	return g

## Turn the dial from 17 OCT 1931 to `d`.
func set_date(g: GameSim, d: String) -> void:
	match d:
		"18 OCT 1927":
			g.dispatch("day_up")
			for i in 4:
				g.dispatch("year_dn")
		"18 OCT 1931":
			g.dispatch("day_up")

func file_all_correct(g: GameSim) -> void:
	for rec in RECS:
		use(g, rec, FOLDER_IDS[REF_HOME[rec]])

func inv_count(g: GameSim, item: String) -> int:
	return g.state.inventory.count(item)

## A game at the start of tide VIII (P21 done), at the open model.
func model_game() -> GameSim:
	var g := game_at(8, ROOM)
	play(g, ["to_catalogue", "model"])
	return g

func _view_ready() -> bool:
	var m: Dictionary = load(VIEW_PATH).get_script_constant_map()
	var ids := []
	for h in m.get("HOTSPOTS", []):
		ids.append(h[0])
	for id in R10Sim.HOTSPOTS:
		if not id in ids:
			return false
	return true

# ---------------------------------------------------------------------------------------------
# constants and arrival
# ---------------------------------------------------------------------------------------------
func test_constants() -> void:
	check(not R10Sim.new().get_script().get_script_constant_map().has("SKELETON"), "R10 is built (no SKELETON)")
	check(R10Sim.TITLE == "Records Vault" and R10Sim.REQUIRES == ["P15"], "title and gate")
	check(R10Sim.WAY_IN_HINT == "The vault door in the laboratory has let go.", "way-in hint")
	check(JSON.stringify(R10Sim.EXITS) == JSON.stringify([["R07", "Laboratory", []]]), "exits")
	check(R10Sim.ITEMS.keys() == ["contact_sheet", "venn_correspondence", "witness_bridge"], "items")
	var r := R10Sim.new()
	for v in ["c_contact", "c_folders", "c_model"]:
		check(r.is_closeup(v), "%s is a close-up" % v)
	for v in ["room", "catalogue"]:
		check(not r.is_closeup(v), "%s is a base view" % v)
	var all := []
	for list in [R10Sim.HOTSPOTS, R10Sim.CATALOGUE_HOTSPOTS, R10Sim.CONTACT_CONTROLS, R10Sim.FOLDER_CONTROLS, R10Sim.MODEL_CONTROLS]:
		for id in list:
			check(not id in all or id in R10Sim.CONTACT_CONTROLS, "action %s is unique" % id)
			all.append(id)
	for k in R10Sim.NOTICE_LINES:
		check(R10Sim.OBSERVATIONS.has(k), "notice %s has an observation" % k)

func test_arrival() -> void:
	var g := with_flags(["P15"], "R07")
	var ev := g.dispatch("go:R10")
	var r := r10(g)
	check(g.state.room == ROOM, "walk into the vault")
	check(says(ev) == R10Sim.ARRIVAL + " | Somewhere a long way back, paper settles.", "arrival lines (got %s)" % says(ev))
	check(has_ev(ev, "sfx", "paper_settle") and has_ev(ev, "fx", "notice_shelves") and r.has_seen("shelves")
		and r.state.notices == ["shelves"], "arrival beat")
	g.dispatch("go:R07")
	ev = g.dispatch("go:R10")
	check(says(ev) == "", "arrival once (got %s)" % says(ev))

# ---------------------------------------------------------------------------------------------
# P16
# ---------------------------------------------------------------------------------------------
func _perms(items: Array) -> Array:
	if items.size() <= 1:
		return [items.duplicate()]
	var out := []
	for i in items.size():
		var rest := items.duplicate()
		var x = rest.pop_at(i)
		for p in _perms(rest):
			out.append([x] + p)
	return out

## The expected refusal for `order`, from the reference tables.
func expected_break(order: Array) -> Array:
	for k in 3:
		var x: String = order[k]
		var y: String = order[k + 1]
		if REF_FIRST[y] != REF_FIRST[x] + 4:
			var lx: int = REF_LAMPS[x]
			var ly: int = REF_LAMPS[y]
			var tail := "Lamps don't come back on." if ly > lx else "Some went out between them."
			return [k, "Frame %d, then frame %d. %s lit, then %s. %s" % [REF_FIRST[x] + 3, REF_FIRST[y],
				REF_WORD[lx], REF_WORD_LC[ly], tail]]
	return [-1, ""]

func test_p16_orders() -> void:
	var perms := _perms(["A", "B", "C", "D"])
	check(perms.size() == 24, "24 orders")
	var clipped := 0
	for order in perms:
		var g := fresh()
		var r := r10(g)
		g.dispatch("contact_table")
		place(g, order)
		check(r.state.slots == order, "%s placed" % [order])
		var ev := use(g, "chart_clips", "clip")
		var want := expected_break(order)
		if order == REF_SOLUTION:
			check(r.state.clipped and has_ev(ev, "sfx", "clip_snap") and has_ev(ev, "fx", "clamp")
				and says(ev) == CLIP_DONE + " | The cover's tab gives a little.", "BDAC clips (got %s)" % says(ev))
			clipped += 1
		else:
			check(not r.state.clipped and says(ev) == want[1] and r.edge_break == want[0]
				and has_ev(ev, "sfx", "edge_refuse"), "%s refused: %s (got %s, break %d)" % [order, want[1], says(ev), r.edge_break])
		check(not g.flag("P16"), "%s: no P16 from the clip" % [order])
		check(g.has_item("chart_clips"), "%s: clips kept" % [order])
	check(clipped == 1, "only one order clips")
	# Spot checks against the card's wording.
	check(expected_break(["B", "A", "D", "C"])[1] == "Frame 4, then frame 9. Eight lit, then three. Some went out between them.", "B then A")
	check(expected_break(["C", "B", "D", "A"])[1] == "Frame 16, then frame 1. None lit, then eight. Lamps don't come back on.", "C then B")

func test_p16_incomplete() -> void:
	for n in 4:
		var g := fresh()
		var r := r10(g)
		g.dispatch("contact_table")
		var order: Array = REF_SOLUTION.slice(0, n)
		place(g, order)
		var ev := use(g, "chart_clips", "clip")
		check(says(ev) == NOT_ALL_IN and has_ev(ev, "sfx", "edge_refuse") and not r.state.clipped, "%d placed: refused" % n)
	# Three placed and the fourth in hand.
	var g := fresh()
	g.dispatch("contact_table")
	place(g, ["B", "D", "A", ""])
	g.dispatch("loose_c")
	check(says(use(g, "chart_clips", "clip")) == NOT_ALL_IN, "a panel in hand isn't in")

func test_p16_clip_items() -> void:
	var g := fresh()
	var r := r10(g)
	g.dispatch("contact_table")
	place(g, REF_SOLUTION)
	var before := snapshot(g)
	var st := JSON.stringify(r.state)
	check(says(g.dispatch("clip")) == CLIP_NEEDS, "clip with no item says the clips line")
	check(snapshot(g) == before and JSON.stringify(r.state) == st, "and changes nothing")
	var ev := use(g, "nora_frame", "clip")
	check(says(ev) == CLIP_ONLY and snapshot(g) == before and JSON.stringify(r.state) == st, "a wrong item is refused, nothing taken")
	# The clips on a slot clip too; on contact_table from view A it opens the table first.
	g = fresh()
	r = r10(g)
	g.dispatch("contact_table")
	place(g, REF_SOLUTION)
	check(says(use(g, "chart_clips", "slot_2")).ends_with("The cover's tab gives a little.") and r.state.clipped, "clips on a slot")
	g = fresh()
	r = r10(g)
	g.dispatch("contact_table")
	place(g, REF_SOLUTION)
	g.dispatch("back")
	ev = use(g, "chart_clips", "contact_table")
	check(r.local_view == "c_contact" and r.state.clipped, "clips on the table open it and clip")

func test_p16_cover_gate() -> void:
	var g := fresh()
	var r := r10(g)
	g.dispatch("contact_table")
	check(says(g.dispatch("cover")) == REGISTERED and not g.flag("P16") and not r.state.cover_off, "cover before anything")
	place(g, REF_SOLUTION)
	check(says(g.dispatch("cover")) == REGISTERED and not g.flag("P16"), "cover before the clip")
	check(not g.has_item("contact_sheet"), "no sheet yet")

func test_p16_success() -> void:
	var g := fresh()
	var r := r10(g)
	var ev := solve_p16(g)
	check(g.flag("P16") and r.state.p16_complete and r.state.cover_off, "P16 set")
	check(inv_count(g, "contact_sheet") == 1 and count_ev(ev, "fx", "item_added") == 1, "contact sheet given once")
	check(g.has_item("chart_clips"), "chart clips still held")
	check(r.has_seen("contact_sheet_1927"), "contact_sheet_1927 noted")
	var obs: String = R10Sim.OBSERVATIONS.contact_sheet_1927
	check("18 October 1927" in obs and "Sync: bell." in obs, "the observation carries the date and the sync")
	check(has_ev(ev, "sfx", "cover_slide") and has_ev(ev, "fx", "cover_off") and has_ev(ev, "fx", "last_turn")
		and has_ev(ev, "fx", "reflection") and has_ev(ev, "sfx", "sheet_take"), "reveal events")
	var lines := says(ev).split(" | ")
	check(lines.size() == 5 and lines[-1] == "The film edge is dated 18 October 1927. I take the sheet.", "reveal chain")
	var glance := {}
	for e in ev:
		if e.type == "fx" and e.id == "glance":
			glance = e
	check(glance.get("target", "") == "contact_table" and glance.get("rect", []) == [800, 560, 400, 270], "glance at the table")
	check(r.photos_turned() and r.sheet_assembled() and r.last_turned(), "helpers follow")
	check(r.objective() == "p18", "next: p18")

func test_p16_idempotent() -> void:
	var g := fresh()
	solve_p16(g)
	var inv: int = g.state.inventory.size()
	for a in ["cover", "clip", "cover"]:
		var ev := g.dispatch(a)
		check(not has_ev(ev, "fx", "tide") and not has_ev(ev, "fx", "item_added"), "%s again: no events" % a)
	var ev := use(g, "chart_clips", "clip")
	check(says(ev) == "Clipped." and not has_ev(ev, "fx", "item_added"), "clips again")
	check(says(g.dispatch("cover")) == "The cover's off. They stay uncovered.", "cover again")
	check(g.state.inventory.size() == inv and inv_count(g, "contact_sheet") == 1, "inventory unchanged")

func test_p16_locked_after_clip() -> void:
	var g := fresh()
	var r := r10(g)
	g.dispatch("contact_table")
	place(g, REF_SOLUTION)
	use(g, "chart_clips", "clip")
	for a in ["slot_1", "slot_4", "loose_a", "loose_d"]:
		check(says(g.dispatch(a)) == HOLDS, "%s after the clip holds" % a)
	check(r.state.slots == REF_SOLUTION and r.held == "", "nothing moved")
	g.dispatch("cover")
	check(says(g.dispatch("slot_2")) == HOLDS, "after the cover too")

func test_p16_panel_handling() -> void:
	var g := fresh()
	var r := r10(g)
	var ev := g.dispatch("contact_table")
	check(says(ev) == "The contact table. Four panels of one night, and a cover pinned over the faces." and r.has_seen("contact_table"), "first table line")
	ev = g.dispatch("loose_a")
	check(r.held == "A" and has_ev(ev, "sfx", "panel_pick") and r.has_seen("panel_a"), "pick A")
	check(says(ev) == "Panel A. Frames 9 to 12. The clock behind the chairs says 21:40. Three lamps lit.", "panel A line (got %s)" % says(ev))
	check(says(g.dispatch("loose_b")) == "Panel B. Frames 1 to 4. The clock behind the chairs says 21:00. All eight lamps lit.", "swap to B")
	check(r.held == "B" and r.loose_letters() == ["A", "C", "D"], "A back with the loose ones")
	check(says(g.dispatch("loose_c")).ends_with("No lamps lit.") and says(g.dispatch("loose_d")).ends_with("Six lamps lit."), "C and D lines")
	g.dispatch("loose_d")
	check(r.held == "", "D put down")
	check(says(g.dispatch("slot_3")) == "Slot 3. Empty.", "empty slot")
	g.dispatch("loose_a")
	ev = g.dispatch("slot_1")
	check(r.state.slots == ["A", "", "", ""] and r.held == "" and has_ev(ev, "sfx", "panel_place"), "A in slot 1")
	g.dispatch("loose_b")
	g.dispatch("slot_1")
	check(r.state.slots == ["B", "", "", ""] and r.held == "A", "B displaces A into the hand")
	g.dispatch("slot_2")
	check(r.state.slots == ["B", "A", "", ""] and r.held == "", "A in slot 2")
	g.dispatch("slot_1")
	check(r.state.slots == ["", "A", "", ""] and r.held == "B", "lift B")
	check(r.loose_letters() == ["C", "D"], "loose excludes held and placed")
	g.dispatch("back")
	check(r.held == "" and r.loose_letters() == ["B", "C", "D"], "leaving drops the hand")
	check(says(g.dispatch("contact_table")) == "The contact table.", "later visit")
	check(r.edge_numbers("C") == [13, 14, 15, 16] and r.lamp_tally("D") == "6 lit" and r.panel_clock("A") == "21:40", "panel helpers")
	g = fresh()
	solve_p16(g)
	g.dispatch("back")
	check(says(g.dispatch("contact_table")) == "The last one's still turned away.", "after P16")
	# A failed clip marks the break; a placement clears it.
	g = fresh()
	r = r10(g)
	g.dispatch("contact_table")
	place(g, ["B", "A", "D", "C"])
	use(g, "chart_clips", "clip")
	check(r.edge_break == 0, "break at 0")
	g.dispatch("slot_2")
	check(r.edge_break == -1, "lifting clears the break")

func test_p16_save_load() -> void:
	var g := fresh()
	var r := r10(g)
	g.dispatch("contact_table")
	place(g, ["D", "", "B", ""])
	g.dispatch("loose_a")
	var t := roundtrip(g)
	check(r10(t).state.slots == ["D", "", "B", ""] and r10(t).held == "" and r10(t).local_view == "room", "mid-arrangement keeps slots, drops the hand")
	check(r10(t).loose_letters() == ["A", "C"], "the held panel is loose again")
	g = fresh()
	g.dispatch("contact_table")
	place(g, REF_SOLUTION)
	use(g, "chart_clips", "clip")
	t = roundtrip(g)
	check(r10(t).state.clipped and not r10(t).state.cover_off and not t.flag("P16"), "clipped survives a load")
	check(says(t.dispatch("contact_table")) != "" and r10(t).local_view == "c_contact", "reopen")
	t.dispatch("cover")
	check(t.flag("P16") and t.has_item("contact_sheet"), "cover after load solves")
	for bad in [["B", "B", "", ""], ["X", "", "", ""], ["B", "D", "A"], [1.0, "", "", ""], "BDAC", ["B", "D", "A", "C", ""]]:
		var d := fresh().to_dict()
		d.rooms[ROOM].slots = bad
		var h := GameSim.new()
		h.from_dict(JSON.parse_string(JSON.stringify(d)))
		check(r10(h).state.slots == ["", "", "", ""], "malformed slots %s load empty" % [bad])

# ---------------------------------------------------------------------------------------------
# P18
# ---------------------------------------------------------------------------------------------
func test_p18_needs_session() -> void:
	var g := fresh()
	var r := r10(g)
	play(g, ["to_catalogue", "folders"])
	file_all_correct(g)
	set_date(g, "18 OCT 1927")
	var ev := g.dispatch("compare")
	check(says(ev) == "It wants a session. I haven't found one yet." and r.strip_text == "NO SESSION ON RECORD"
		and has_ev(ev, "sfx", "compare_key"), "compare before P16 (got %s)" % says(ev))
	check(not g.flag("P18") and not r.state.p18_complete, "no P18")
	check(r.state.filed.BODY == "nora_frame", "records stay filed")

func _mappings() -> Array:
	var out := []
	var opts := ["", "BODY", "PLACE", "NAME"]
	for a in opts:
		for b in opts:
			for c in opts:
				var m := [a, b, c]
				var used := []
				var ok := true
				for f in m:
					if f != "":
						ok = ok and not f in used
						used.append(f)
				if ok:
					out.append(m)
	return out

func test_p18_exhaustive() -> void:
	var maps := _mappings()
	check(maps.size() == 34, "34 injective filings (got %d)" % maps.size())
	var solved := 0
	var base := folders_game()
	var base_d := base.to_dict()
	var base_view: String = r10(base).local_view
	for m in maps:
		for date in ["17 OCT 1931", "18 OCT 1927", "18 OCT 1931"]:
			var g := GameSim.new()
			g.from_dict(base_d.duplicate(true))
			var r := r10(g)
			r.local_view = base_view
			var tag := "%s @ %s" % [m, date]
			for i in 3:
				if m[i] != "":
					use(g, RECS[i], FOLDER_IDS[m[i]])
			set_date(g, date)
			check(r.date_text() == date, "%s: dial reads %s" % [tag, r.date_text()])
			var ev := g.dispatch("compare")
			check(has_ev(ev, "sfx", "compare_key") and ev[0].get("id", "") == "compare_key", "%s: compare key first" % tag)
			var full: bool = not "" in m
			var right: bool = m == ["BODY", "PLACE", "NAME"]
			if right and date == "18 OCT 1927":
				check(g.flag("P18") and r.state.p18_complete, "%s solves" % tag)
				solved += 1
			else:
				check(not g.flag("P18") and not r.state.p18_complete, "%s: no P18" % tag)
				check(not g.has_item("venn_correspondence"), "%s: no letters" % tag)
				if not full:
					check(says(ev) == "Three folders. One record each." and r.strip_text == "INCOMPLETE: THREE RECORDS REQUIRED", "%s: incomplete (got %s)" % [tag, says(ev)])
				elif not right:
					var first := ""
					var wrong := []
					for f in ["BODY", "PLACE", "NAME"]:
						var rec: String = RECS[m.find(f)]
						if REF_HOME[rec] != f:
							if first == "":
								first = REF_MISMATCH["%s/%s" % [rec, f]]
							wrong.append(rec)
					check(says(ev) == first + " | The tray has them." and r.strip_text == "CATEGORY DOES NOT CORRESPOND"
						and has_ev(ev, "sfx", "compare_refuse"), "%s: mismatch line (got %s)" % [tag, says(ev)])
					var tray: Array = r.state.tray.duplicate()
					tray.sort()
					wrong.sort()
					check(tray == wrong, "%s: the mismatched in the tray" % tag)
					for i in 3:
						var f: String = m[i]
						if REF_HOME[RECS[i]] == f:
							check(r.state.filed[f] == RECS[i], "%s: %s stays filed" % [tag, RECS[i]])
						else:
							check(not RECS[i] in r.state.filed.values(), "%s: %s left its folder" % [tag, RECS[i]])
				else:
					var want := "Not the session date." + (" | Not yet." if date == "18 OCT 1931" else "")
					var strip := "DATE DOES NOT CORRESPOND." + ("\nNOT YET." if date == "18 OCT 1931" else "")
					check(says(ev) == want and r.strip_text == strip, "%s: date line (got %s)" % [tag, says(ev)])
					check(r.has_seen("not_yet") == (date == "18 OCT 1931"), "%s: not_yet noted only for 1931" % tag)
					check(r.state.filed.values() == RECS, "%s: records stay filed" % tag)
			g.dispatch("cmp_tray")
			g.dispatch("back")
			for rec in RECS:
				check(inv_count(g, rec) == 1, "%s: %s back in the inventory once" % [tag, rec])
			check(r.state.filed.values() == ["", "", ""] and r.state.tray.is_empty(), "%s: folders empty" % tag)
	check(solved == 1, "exactly one filing solves")

func test_p18_success() -> void:
	var g := folders_game()
	var r := r10(g)
	file_all_correct(g)
	for rec in RECS:
		check(not g.has_item(rec), "%s taken into the folder" % rec)
	set_date(g, "18 OCT 1927")
	var ev := g.dispatch("compare")
	check(g.flag("P18") and r.state.p18_complete, "P18 set")
	for rec in RECS:
		check(inv_count(g, rec) == 1, "%s returned" % rec)
	check(inv_count(g, "venn_correspondence") == 1 and count_ev(ev, "fx", "item_added") == 4, "letters given once, records back")
	check(r.has_seen("index_protocol") and r.has_seen("venn_drawer_open"), "index_protocol noted")
	check(r.state.staff_open and r.state.drawer_open, "STAFF and Venn's drawer open")
	check(r.state.filed.values() == ["", "", ""] and r.state.tray.is_empty(), "folders empty")
	check(r.strip_text == "SUBJECT COMPLETE", "strip")
	var lines := says(ev).split(" | ")
	check(lines.size() == 7 and lines[0] == "The folders shut on her. All three."
		and lines[1] == "Behind me, the STAFF drawer slid open on its own. Every tab inside moved at once.", "chain (drawer was shut)")
	var glance := {}
	for e in ev:
		if e.type == "fx" and e.id == "glance":
			glance = e
	check(glance.get("target", "") == "correspondence_drawer", "glance at Venn's drawer")
	ev = g.dispatch("compare")
	check(says(ev) == "It's done its demonstration. I won't file her again." and r.strip_text == "SUBJECT COMPLETE"
		and not has_ev(ev, "fx", "item_added"), "compare again")
	check(says(use(g, "nora_frame", "fold_body")) == "It's done its demonstration. I won't file her again." and g.has_item("nora_frame"), "no refiling")
	check(says(g.dispatch("release")) == "Down. It stays down.", "release after")
	g.dispatch("back")
	check(says(g.dispatch("folders")) == "The folders. They've done their demonstration.", "folders after")
	# The STAFF drawer already open changes the line.
	g = folders_game()
	play(g, ["back", "staff_drawer", "folders"])
	file_all_correct(g)
	set_date(g, "18 OCT 1927")
	check("Behind me, every tab in the STAFF drawer moved at once. Like a breath." in says(g.dispatch("compare")), "chain (drawer was open)")

func test_p18_returns() -> void:
	var g := folders_game()
	var r := r10(g)
	use(g, "nora_frame", "fold_body")
	use(g, "nora_register_card", "fold_place")
	var ev := g.dispatch("release")
	check(says(ev) == "TRAINING RELEASE. 'Training model. Release returns all records.'" and r.has_seen("training_release"), "release line")
	for rec in RECS:
		check(inv_count(g, rec) == 1, "release returns %s" % rec)
	check(r.state.filed.values() == ["", "", ""], "release empties the folders")
	# Mismatched into the tray, then back: everything returns with the line.
	use(g, "nora_frame", "fold_place")
	use(g, "nora_spatial_strip", "fold_body")
	use(g, "nora_register_card", "fold_name")
	g.dispatch("compare")
	check(r.state.tray.size() == 2 and r.state.filed.NAME == "nora_register_card", "two in the tray")
	ev = g.dispatch("back")
	check(says(ev) == RECORDS_BACK and r.local_view == "catalogue", "back says the line")
	for rec in RECS:
		check(inv_count(g, rec) == 1, "back returns %s" % rec)
	ev = play(g, ["folders", "back"])
	check(not RECORDS_BACK in says(ev), "nothing out, no line")
	# Leaving by a hotspot returns them too.
	g.dispatch("folders")
	use(g, "nora_frame", "fold_body")
	g.dispatch("staff_drawer")
	check(g.has_item("nora_frame") and r.local_view == "catalogue", "a hotspot click returns them")
	# Save mid-filing.
	g.dispatch("folders")
	use(g, "nora_frame", "fold_place")
	use(g, "nora_spatial_strip", "fold_body")
	use(g, "nora_register_card", "fold_name")
	g.dispatch("compare")
	var t := roundtrip(g)
	for rec in RECS:
		check(inv_count(t, rec) == 1, "a load gives exactly one %s" % rec)
	check(r10(t).state.filed.values() == ["", "", ""] and r10(t).state.tray.is_empty(), "a load empties the folders and tray")
	# Folder clicks: return one, covers, occupied folder, tray.
	g = folders_game()
	r = r10(g)
	check(says(g.dispatch("fold_body")) == "BODY. The cover shows a breath trace.", "empty BODY")
	check(says(g.dispatch("fold_place")) == "PLACE. The cover shows a bearing diagram.", "empty PLACE")
	check(says(g.dispatch("fold_name")) == "NAME. The cover shows a personal card.", "empty NAME")
	ev = use(g, "nora_frame", "fold_body")
	check(says(ev) == "In BODY." and has_ev(ev, "sfx", "folder_file"), "filed")
	ev = use(g, "nora_register_card", "fold_body")
	check(says(ev) == "Body already has one in it." and g.has_item("nora_register_card"), "occupied folder keeps the item")
	ev = g.dispatch("fold_body")
	check(says(ev) == "I take her frame back out." and g.has_item("nora_frame") and has_ev(ev, "sfx", "folder_return"), "take one out")
	check(says(g.dispatch("cmp_tray")) == "The comparison tray. Empty.", "empty tray")

func test_p18_wheels() -> void:
	var g := folders_game()
	var r := r10(g)
	check(r.date_text() == "17 OCT 1931", "initial date")
	var ev := g.dispatch("day_up")
	check(has_ev(ev, "sfx", "wheel_click") and says(ev) == "", "wheel click, no line")
	r.state.day = 31
	g.dispatch("day_up")
	check(r.state.day == 1, "31 -> 1")
	g.dispatch("day_dn")
	check(r.state.day == 31, "1 -> 31")
	r.state.month = 12
	g.dispatch("mon_up")
	check(r.state.month == 1 and r.date_text() == "31 JAN 1931", "DEC -> JAN")
	g.dispatch("mon_dn")
	check(r.state.month == 12, "JAN -> DEC")
	g.dispatch("year_up")
	check(r.state.year == 1889, "1931 up -> 1889")
	g.dispatch("year_dn")
	check(r.state.year == 1931, "1889 down -> 1931")
	r.state.day = 5
	check(r.date_text() == "05 DEC 1931", "zero-padded day")

func test_p18_records_untouched() -> void:
	var g := folders_game()
	var defs_before := JSON.stringify(g.item_defs())
	var seen_before = g.value("endings_seen")
	file_all_correct(g)
	g.dispatch("compare")
	g.dispatch("release")
	file_all_correct(g)
	set_date(g, "18 OCT 1927")
	g.dispatch("compare")
	check(g.flag("P18"), "solved")
	check(JSON.stringify(g.item_defs()) == defs_before, "item definitions unchanged")
	check(g.value("ending_choice") == "" and g.value("endings_seen") == seen_before, "endings untouched")

func test_p17_p18_orders() -> void:
	# P17 first, then P18 by play.
	var g := game_at(6, ROOM)
	solve_p16(g)
	play(g, ["back", "to_catalogue", "folders"])
	for rec in RECS:
		g.give(rec)
	var ev: Array = []
	g.solve("P17", ev)
	check(g.tide() == 6, "P17 alone keeps tide VI")
	file_all_correct(g)
	set_date(g, "18 OCT 1927")
	ev = g.dispatch("compare")
	check(g.tide() == 7 and g.weather_band() == 5 and has_ev(ev, "fx", "tide"), "P17 then P18: tide VII, band 5")
	# P18 first, then P17.
	g = game_at(6, ROOM)
	solve_p16(g)
	play(g, ["back", "to_catalogue", "folders"])
	for rec in RECS:
		g.give(rec)
	file_all_correct(g)
	set_date(g, "18 OCT 1927")
	ev = g.dispatch("compare")
	check(g.flag("P18") and g.tide() == 6 and not has_ev(ev, "fx", "tide"), "P18 alone keeps tide VI")
	check(r10(g).objective() == "away_p17", "after P18 without P17: away_p17")
	ev = []
	g.solve("P17", ev)
	check(g.tide() == 7 and g.weather_band() == 5, "P18 then P17: tide VII, band 5")
	check(r10(g).objective() == "wait_p21", "then wait_p21")

func test_p18_lines() -> void:
	var g := folders_game()
	var r := r10(g)
	check(says(g.dispatch("lid_card")) == "'A subject is complete when BODY, PLACE and NAME correspond on one session date.' S.R."
		and r.has_seen("protocol_card"), "protocol card")
	check(says(use(g, "contact_sheet", "fold_name")) == "The sheet only gives the date. 18 October 1927.", "sheet on a folder")
	check(says(use(g, "contact_sheet", "day_up")) == "The sheet only gives the date. 18 October 1927.", "sheet on a wheel")
	check(says(use(g, "contact_sheet", "compare")) == "The sheet only gives the date. 18 October 1927.", "sheet on compare")
	g.give("amended_nora_card")
	check(says(use(g, "amended_nora_card", "fold_name")) == "Not into Rook's folders again.", "amended card")
	check(g.has_item("amended_nora_card"), "kept")
	# First open and later opens.
	g = fresh()
	g.dispatch("to_catalogue")
	var ev := g.dispatch("folders")
	check(says(ev) == "Rook's folders. BODY, PLACE, NAME. The date dial's set to today." and r10(g).has_seen("folders"), "first folders line")
	g.dispatch("back")
	check(says(g.dispatch("folders")) == "BODY, PLACE, NAME.", "later folders line")

# ---------------------------------------------------------------------------------------------
# P23
# ---------------------------------------------------------------------------------------------
func test_p23_shutter() -> void:
	var g := game_at(7, ROOM)
	var r := r10(g)
	check(not r.shutter_open(), "tide VII: shutter shut")
	var ev := play(g, ["to_catalogue", "model"])
	check(says(ev) == "The Index model. Three brass leaves over a terminal block." and r.has_seen("model"), "model opens")
	var st := JSON.stringify(r.state)
	var snap := snapshot(g)
	for a in R10Sim.MODEL_CONTROLS:
		check(says(g.dispatch(a)) == SHUTTER, "%s before P21: the shutter line" % a)
	check(r.has_seen("model_shutter"), "model_shutter noted")
	check(JSON.stringify(r.state) == st and snapshot(g) == snap and r.model_text == "", "nothing changes")
	g = model_game()
	r = r10(g)
	check(r.shutter_open() and r.has_seen("faceplate"), "after P21 the first open notes the faceplate")
	check(says(g.dispatch("faceplate")) == "'A copied acknowledgement closes the cycle. A human witness may append another correction.'", "faceplate line")

func test_p23_combinations() -> void:
	for i in [false, true]:
		for c in [false, true]:
			for w in [false, true]:
				var g := model_game()
				var r := r10(g)
				r.state.input = i
				r.state.copy = c
				r.state.witness = w
				var tag := "input %s copy %s witness %s" % [i, c, w]
				var ev := g.dispatch("test")
				check(ev[0].get("id", "") == "test_key", "%s: test key first" % tag)
				if not i or not (c or w):
					check(says(ev) == "No input." and r.model_text == "NO INPUT" and r.state.stamp == "", "%s: no input" % tag)
					check(not g.flag("P23"), "%s: no P23" % tag)
				elif c:
					check(r.state.stamp == "closed" and r.model_text == "COPY ACKNOWLEDGED. RECORD CLOSED."
						and says(ev) == "CLOSED. | The copy answered for her. That's what it did to them.", "%s: closed" % tag)
					check(has_ev(ev, "sfx", "stamp_closed") and has_ev(ev, "fx", "stamp_closed") and r.has_seen("model_closed_test"), "%s: closed events" % tag)
					check(not g.flag("P23") and not g.has_item("witness_bridge"), "%s: no P23" % tag)
				else:
					check(g.flag("P23") and r.state.p23_complete and r.state.stamp == "open", "%s: P23" % tag)
					check(inv_count(g, "witness_bridge") == 1 and count_ev(ev, "fx", "item_added") == 1, "%s: bridge once" % tag)
					check(r.has_seen("witness_test") and r.has_seen("aperture_wider") and r.aperture_width() == 1, "%s: noted, aperture 1" % tag)
					check(r.state.bridge_taken and not r.bridge_present() and r.state.strip2, "%s: bridge gone, second line" % tag)
					check(says(ev).split(" | ")[-1] == "It's printed another line. WITNESS: MERCER, A.", "%s: chain" % tag)
	# By play: the lead only goes in from INPUT.
	var g := model_game()
	var r := r10(g)
	check(says(g.dispatch("t_copy")) == "The lead starts at INPUT." and not r.state.copy, "copy needs input")
	check(says(g.dispatch("t_witness")) == "The lead starts at INPUT." and not r.state.witness, "witness needs input")
	g.dispatch("t_input")
	g.dispatch("t_copy")
	g.dispatch("t_witness")
	check(r.state.input and r.state.copy and r.state.witness, "all seated")
	g.dispatch("t_input")
	check(not r.state.input and not r.state.copy and not r.state.witness, "unseating input parks the plugs")
	play(g, ["t_input", "t_witness"])
	check(says(g.dispatch("lead")) == "I coil the lead." and not r.state.input and not r.state.witness, "lead parks all")
	check(says(g.dispatch("bridge")) == "A bridge seated across WITNESS. It doesn't come out.", "bridge before")
	check(says(g.dispatch("stamp")) == "Nothing stamped." and says(g.dispatch("strip")) == "Blank.", "reads")
	play(g, ["t_input", "t_witness"])
	g.dispatch("test")
	check(g.flag("P23"), "by play: solved")
	check(says(g.dispatch("stamp")) == "OPEN. In ink.", "stamp read")
	check(says(g.dispatch("strip")) == "AMENDMENT 1 APPENDED. RECORD OPEN. WITNESS: MERCER, A.", "strip read")
	var st := JSON.stringify(r.state)
	for a in ["t_input", "t_copy", "t_witness", "lead", "bridge"]:
		g.dispatch(a)
	check(JSON.stringify(r.state) == st, "nothing changes after OPEN")
	check(says(use(g, "witness_bridge", "t_witness")) == "It's done its test. It belongs to the chamber now.", "bridge back")
	check(g.has_item("witness_bridge"), "kept")

func test_p23_reset() -> void:
	var g := model_game()
	var r := r10(g)
	check(says(g.dispatch("reset")) == "Nothing to reset.", "nothing to reset")
	for round in 3:
		play(g, ["t_input", "t_copy", "test"])
		check(r.state.stamp == "closed", "round %d: closed" % round)
		var st := JSON.stringify(r.state)
		check(says(g.dispatch("test")) == "It's stamped CLOSED. RESET first." and JSON.stringify(r.state) == st, "round %d: reset first" % round)
		play(g, ["t_witness"])
		check(says(g.dispatch("test")) == "It's stamped CLOSED. RESET first." and not g.flag("P23"), "round %d: even with the witness" % round)
		var ev := g.dispatch("reset")
		check(says(ev) == "RESET. Open again. Just like that." and r.state.stamp == "" and r.model_text == ""
			and has_ev(ev, "sfx", "reset_key"), "round %d: reset reopens" % round)
		g.dispatch("lead")
	play(g, ["t_input", "t_witness", "test"])
	check(g.flag("P23"), "then solves")
	check(says(g.dispatch("reset")) == "It's stamped OPEN. In ink." and r.state.stamp == "open", "reset after solve keeps open")

func test_p23_no_side_effects() -> void:
	var g := model_game()
	var before := snapshot(g)
	var seqs := [["test"], ["t_input", "test"], ["t_input", "t_copy", "test"], ["reset"],
		["t_input", "t_copy", "t_witness", "test", "reset"], ["t_witness", "test"], ["lead", "test", "reset"],
		["faceplate", "stamp", "strip", "bridge", "shutter"]]
	for s in seqs:
		play(g, s)
		check(snapshot(g) == before, "%s: no flag, item or ending change" % [s])
		g.dispatch("reset")
		g.dispatch("lead")

func test_p23_idempotent() -> void:
	var g := model_game()
	var r := r10(g)
	play(g, ["t_input", "t_witness", "test"])
	var snap := snapshot(g)
	for i in 3:
		var ev := g.dispatch("test")
		check(says(ev) == "It took the line. It's still open." and r.model_text == "RECORD OPEN", "test again %d" % i)
		check(not has_ev(ev, "fx", "item_added") and not has_ev(ev, "fx", "tide") and snapshot(g) == snap, "no events %d" % i)
	g.take("witness_bridge")
	var ev := g.dispatch("test")
	check(not g.has_item("witness_bridge") and not has_ev(ev, "fx", "item_added"), "no regrant after the bridge is used")
	var t := roundtrip(g)
	check(not t.has_item("witness_bridge") and r10(t).state.p23_complete, "nor on a load")

func test_p23_save_load() -> void:
	var g := model_game()
	play(g, ["t_input", "t_copy", "test"])
	var t := roundtrip(g)
	var r := r10(t)
	check(r.state.stamp == "closed" and r.state.input and r.state.copy and not r.state.witness, "closed with leads survives")
	g = model_game()
	play(g, ["t_input", "t_witness"])
	t = roundtrip(g)
	r = r10(t)
	check(r.state.input and r.state.witness and r.state.stamp == "", "seated leads survive")
	play(t, ["to_catalogue", "model", "test"])
	check(t.flag("P23"), "test after load solves")

# ---------------------------------------------------------------------------------------------
# escalation
# ---------------------------------------------------------------------------------------------
func test_escalation() -> void:
	# tide: [band, ninth, mercer, more, aperture, sea, deep]
	var want := {6: [4, false, false, false, 0, true, false], 7: [5, true, false, false, 0, false, true],
		8: [6, true, true, false, 0, false, true], 9: [7, true, true, true, 2, false, true]}
	for t in want:
		var g := game_at(t, ROOM)
		var r := r10(g)
		var got := [r.band(), r.ninth_photo(), r.mercer_card(), r.shelves_more(), r.aperture_width(),
			r.sea_through_wall(), r.deep_lamp_passing()]
		check(JSON.stringify(got) == JSON.stringify(want[t]), "tide %d: %s (got %s)" % [t, want[t], got])
	var g := model_game()
	play(g, ["t_input", "t_witness", "test"])
	check(r10(g).aperture_width() == 1, "P23 at band 6: aperture 1")
	check(r10(game_at(8, ROOM)).shutter_open() and not r10(game_at(7, ROOM)).shutter_open(), "shutter follows P21")

func test_notices() -> void:
	var g := game_at(6, "R07")
	var r := r10(g)
	var ev := g.dispatch("go:R10")
	check(g.state.room == ROOM and r.current_notice() == "", "band 4: no notice")
	g.dispatch("go:R07")
	var steps := [[["P16", "P17", "P18"], "ninth_photo"], [["P19", "P20", "P21"], "mercer_card"],
		[["P22", "P23", "P24"], "shelves_more"]]
	for s in steps:
		for f in s[0]:
			g.set_flag(f)
		var n: String = s[1]
		ev = g.dispatch("go:R10")
		check(count_ev(ev, "fx", "notice_" + n) == 1 and r.has_seen(n), "notice %s plays (got %s)" % [n, says(ev)])
		check(says(ev) == R10Sim.NOTICE_LINES[n] and float(ev[-1].get("delay", 0)) == 1.6, "%s line at 1.6" % n)
		check(r.state.notices == R10Sim.NOTICES.slice(0, R10Sim.NOTICES.find(n) + 1), "%s retires the older ones" % n)
		check(not has_ev(ev, "fx", "notice_aperture_wide"), "%s: no catalogue notice on arrival" % n)
		g.dispatch("go:R07")
		ev = g.dispatch("go:R10")
		check(says(ev) == "", "%s only once" % n)
		g.dispatch("go:R07")
	g.dispatch("go:R10")
	ev = g.dispatch("to_catalogue")
	check(count_ev(ev, "fx", "notice_aperture_wide") == 1 and r.has_seen("aperture_wide")
		and r.state.catalogue_notices == ["aperture_wide"], "aperture_wide on entering the catalogue")
	g.dispatch("to_shelves")
	ev = g.dispatch("to_catalogue")
	check(not has_ev(ev, "fx", "notice_aperture_wide"), "aperture_wide once")
	# Arriving first at band 7: only the current notice, the older ones marked.
	g = game_at(9, "R07")
	r = r10(g)
	ev = g.dispatch("go:R10")
	var fxs := 0
	for e in ev:
		if e.type == "fx" and str(e.id).begins_with("notice_"):
			fxs += 1
	check(fxs == 1 and has_ev(ev, "fx", "notice_shelves_more"), "tide IX: just shelves_more")
	check(r.state.notices == R10Sim.NOTICES, "every older notice marked")
	check(says(g.dispatch("contact_table")) != "" and says(g.dispatch("back")) == "", "no replay on back")
	# A band change while in the room plays on the way back to the shelves.
	g = game_at(6, ROOM)
	r = r10(g)
	g.set_flag("P16")
	g.set_flag("P17")
	g.set_flag("P18")
	g.dispatch("to_catalogue")
	ev = g.dispatch("to_shelves")
	check(has_ev(ev, "fx", "notice_ninth_photo"), "to_shelves delivers the due notice")
	g = game_at(6, ROOM)
	g.set_flag("P16")
	g.set_flag("P17")
	g.set_flag("P18")
	g.dispatch("contact_table")
	check(has_ev(g.dispatch("back"), "fx", "notice_ninth_photo"), "back into the room delivers it")

func test_hotspots_every_band() -> void:
	for t in range(6, 10):
		var g := game_at(t, ROOM)
		for h in R10Sim.HOTSPOTS + R10Sim.CATALOGUE_HOTSPOTS:
			check(says(g.dispatch(h)) != "", "tide %d: %s answers" % [t, h])

func test_o06() -> void:
	var g := game_at(6, ROOM)
	var r := r10(g)
	g.dispatch("to_catalogue")
	for i in 3:
		var ev := g.dispatch("wrapped_photo")
		check(says(ev) == "A parcel in brown paper and string. A label: S.R. PERSONAL. The knot's pulled tight.", "parcel before P18")
	check(not g.flag("o06_found") and r.state.wrap == 0 and r.has_seen("parcel"), "no O06 before P18")
	g = game_at(7, ROOM)
	r = r10(g)
	var obj := r.objective()
	g.dispatch("to_catalogue")
	var ev := g.dispatch("wrapped_photo")
	check(says(ev) == "The knot's loose now. It wasn't, before." and r.state.wrap == 1 and not g.flag("o06_found"), "knot loose")
	ev = g.dispatch("wrapped_photo")
	check(g.flag("o06_found") and r.state.wrap == 2 and r.has_seen("o06_photo") and has_ev(ev, "sfx", "paper_unwrap"), "O06 found")
	check(says(ev).split(" | ").size() == 3, "three lines")
	check(says(g.dispatch("wrapped_photo")) == "Edith and Kit. I leave them unwrapped.", "after")
	check(r.objective() == obj, "nothing gates on it")
	check(roundtrip(g).flag("o06_found") and r10(roundtrip(g)).state.wrap == 2, "survives a load")

func test_catalogue_objects() -> void:
	var g := fresh()
	var r := r10(g)
	g.dispatch("to_catalogue")
	var ev := g.dispatch("staff_drawer")
	check(says(ev) == "STAFF. | It doesn't open onto a drawer. | A dry opening, shaped like a mouth. Lined with index tabs where the teeth would be. Nothing moves."
		and has_ev(ev, "sfx", "staff_open") and r.state.staff_open and r.has_seen("staff_aperture"), "STAFF first")
	check(says(g.dispatch("staff_drawer")) == "Still. The tabs don't move.", "STAFF still")
	check(says(g.dispatch("tray")) == "A brass tray in front of STAFF, the size of a record card. Worn bright in the middle." and r.has_seen("staff_tray"), "tray")
	ev = g.dispatch("correspondence_drawer")
	check(says(ev) == "Locked. The plate's cut three times. Venn's mark." and has_ev(ev, "sfx", "drawer_locked") and r.has_seen("venn_drawer"), "Venn's drawer locked")
	for it in RECS:
		check(says(use(g, it, "tray")) == "Not until I know what it's for." and g.has_item(it), "%s on the tray before P18" % it)
	check(says(use(g, "nora_frame", "staff_drawer")) == "Not until I know what it's for.", "on STAFF before P18")
	g = game_at(7, ROOM)
	r = r10(g)
	g.dispatch("to_catalogue")
	check(says(g.dispatch("correspondence_drawer")) == "Empty. A clean rectangle in the dust where the letters were.", "drawer after")
	check(says(use(g, "contact_sheet", "tray")) == "I know what the tray is for now. No." and r.has_seen("tray_for"), "tray after P18")
	g = game_at(9, ROOM)
	g.dispatch("to_catalogue")
	check(says(use(g, "witness_bridge", "tray")) == "I know what the tray is for now. No.", "bridge on the tray")
	check(says(g.dispatch("staff_drawer")) == "Wider again. Still nothing moves.", "STAFF at band 7")
	g = model_game()
	play(g, ["t_input", "t_witness", "test", "back"])
	check(says(g.dispatch("staff_drawer")) == "Wider than it was. I didn't see it move.", "STAFF after P23")

func test_room_objects() -> void:
	var g := fresh()
	var r := r10(g)
	var ev := g.dispatch("wall_clock")
	check(says(ev) == "Stopped at ten at night. 22:00. No dust on the glass." and has_ev(ev, "sfx", "clock_tap") and r.has_seen("vault_clock"), "clock")
	check(says(g.dispatch("photographs")) == "Eight photographs of chairs. Somebody sat in each, and somebody else painted them out. Carefully."
		and r.has_seen("photographs") and not r.has_seen("photos_turned"), "photographs before")
	ev = g.dispatch("index_cards")
	check(says(ev) == "The station Index. Eight cards, BELL to TULL, each stamped RETAINED 18.X.27. After TULL, a divider with nothing behind it."
		and has_ev(ev, "sfx", "card_flip") and r.has_seen("index_file"), "index cards")
	check(says(g.dispatch("shelves")) == "They go back past where the laboratory should be. Each bay a little smaller, labelled in the same hand.", "shelves")
	g = game_at(7, ROOM)
	r = r10(g)
	check(says(g.dispatch("photographs")) == "The blanks have turned. All of them, the same way as the last face on the sheet. And a ninth: an empty chair. Nobody painted anything out of it."
		and r.has_seen("photos_turned"), "photographs at band 5")
	g = game_at(8, ROOM)
	r = r10(g)
	check(says(g.dispatch("index_cards")).ends_with(" MERCER, A. At the front. There's nothing else on it.") and r.has_seen("mercer_card"), "Mercer card at band 6")
	g = game_at(9, ROOM)
	r = r10(g)
	check(says(g.dispatch("shelves")) == "There are more of them than there were. They go behind the corner of the room." and r.has_seen("shelves_more"), "shelves at band 7")
	check(says(g.dispatch("to_catalogue")) != "" and r.local_view == "catalogue", "to_catalogue")
	check(says(g.dispatch("to_shelves")) != "" and r.local_view == "room", "to_shelves")

func test_use_item() -> void:
	var g := fresh()
	var r := r10(g)
	g.give("inspection_lens")
	g.give("venn_correspondence")
	check(says(use(g, "inspection_lens", "photographs")) == "Under the lens the retouching is brushwork on the emulsion. Fine, patient. Someone took a long time."
		and r.has_seen("retouch"), "lens on the photographs")
	for target in ["wall_clock", "shelves", "contact_table"]:
		check(says(use(g, "venn_correspondence", target)) == "These belong on the office board.", "letters on %s" % target)
	ev_go(game_at(9, ROOM))
	g = fresh()
	g.give("inspection_lens")
	solve_p16(g)
	r = r10(g)
	check(says(use(g, "inspection_lens", "cover")) == "Venn. Younger. He's looking at the empty station, not the chairs." and r.has_seen("venn_glass"), "lens on the sheet")
	check(r.objective() == "p18", "the lens gates nothing")

func ev_go(g: GameSim) -> void:
	# The letters on the exit tab: she puts them away and goes.
	check(g.has_item("venn_correspondence"), "tide IX: letters in hand")
	g.dispatch("item:venn_correspondence")
	g.dispatch("go:R07")
	check(g.state.room == "R07", "letters on the exit tab: she goes")

# ---------------------------------------------------------------------------------------------
# objectives, hints, debug
# ---------------------------------------------------------------------------------------------
const REF_HINTS := {
	"p16": ["The vault's contact table holds four panels of the same night.",
		"The film edge numbers must run on, and the lamps go out in order.",
		"B, D, A, C: eight lamps, six, three, none. Clip the edge, then slide the cover off."],
	"p18": ["The vault's three folders want Nora's three records.",
		"Each cover shows what it holds: a trace, a bearing, a card. Then the date of the session.",
		"Frame to BODY, strip to PLACE, register card to NAME, date 18 Oct 1927, COMPARE."],
	"p23": ["The model in the vault can be tested safely.", "A copy closes a record. A witness keeps it open.",
		"Lead from INPUT to WITNESS, leave COPY empty, press TEST AMENDMENT. Take the bridge."],
	"away_p17": ["The vault's done its part of the session.",
		"The contact sheet says sync on the bell. The listening room has the session spool.",
		"Take the contact sheet to the listening room's mixer."],
	"wait_p21": ["The model's terminals are shut from the other side.",
		"Venn's letters belong on the office board. The chart room's plan comes after.",
		"Finish the office board and the chart room plan. The shutter opens after."],
	"done": ["The vault has given me what it had.", "The bridge belongs to the chamber door.",
		"Take the witness bridge to the dry stair's lower door."],
}
const REF_OBJ := {
	"p16": "Put the 1927 contact sheet back in order and uncover the faces.",
	"p18": "File Nora's three records in Rook's folders, set the session date and compare.",
	"away_p17": "The vault's folders are done. The session recording waits in the listening room.",
	"wait_p21": "The Index model's terminals are shuttered. Something else comes first.",
	"p23": "Test the Index model: a record that takes a correction and stays open.",
	"done": "The model is stamped OPEN. The bridge is mine to carry.",
}

func test_objectives_hints() -> void:
	var stages := [[1, "p16"], [3, "p16"], [4, "p18"], [5, "p18"], [6, "away_p17"], [7, "p23"], [8, "done"], [9, "done"]]
	for s in stages:
		var g := GameSim.new()
		var r := r10(g)
		r.debug_jump(s[0])
		var o := r.objective()
		check(o == s[1], "jump %d: objective %s (got %s)" % [s[0], s[1], o])
		check(r.objective_text() == REF_OBJ[s[1]], "jump %d: objective text" % s[0])
		check(r.c("HINTS", {})[o].size() == 3, "jump %d: three hint levels" % s[0])
		for lvl in 3:
			check(r.hint_line(lvl) == REF_HINTS[s[1]][lvl], "jump %d: hint %d" % [s[0], lvl])
	check(r10(game_at(7, ROOM)).objective() == "wait_p21", "tide VII: wait_p21")
	for k in REF_HINTS:
		check(JSON.stringify(R10Sim.HINTS[k]) == JSON.stringify(REF_HINTS[k]), "hint ladder %s verbatim" % k)
		check(R10Sim.OBJECTIVES[k] == REF_OBJ[k], "objective %s verbatim" % k)

func test_debug_prepare() -> void:
	for t in [7, 9]:
		var g := game_at(t, ROOM)
		var r := r10(g)
		check(r.state.p16_complete == g.flag("P16") and r.state.p18_complete == g.flag("P18")
			and r.state.p23_complete == g.flag("P23"), "tide %d: state agrees with the flags" % t)
		check(r.state.p16_complete and r.state.p18_complete and r.state.p23_complete == (t >= 9), "tide %d: progress" % t)
		check(inv_count(g, "contact_sheet") == 1 and inv_count(g, "venn_correspondence") == 1, "tide %d: sheet and letters once" % t)
		check(g.has_item("witness_bridge") == (t >= 9), "tide %d: bridge" % t)
		check(r.has_seen("contact_sheet_1927") and r.has_seen("index_protocol"), "tide %d: P16/P18 noted" % t)
		check(r.has_seen("witness_test") == (t >= 9), "tide %d: P23 noted" % t)
		var t2 := roundtrip(g)
		check(JSON.stringify(r10(t2).state) == JSON.stringify(r.state), "tide %d: R10 state byte-identical after a load" % t)
		check(JSON.stringify(t2.state.flags) == JSON.stringify(g.state.flags)
			and JSON.stringify(t2.state.inventory) == JSON.stringify(g.state.inventory), "tide %d: flags and inventory too" % t)
	for t in range(1, 10):
		var a := game_at(t, ROOM if t >= 6 else "R02")
		check(JSON.stringify(r10(roundtrip(a)).state) == JSON.stringify(r10(a).state), "tide %d: R10 state survives a load" % t)

func test_debug_jumps() -> void:
	var g := GameSim.new()
	var r := r10(g)
	var want := {1: [6, false, false, false], 2: [6, false, false, false], 3: [6, false, false, false],
		4: [6, true, false, false], 5: [6, true, false, false], 6: [6, true, true, false],
		7: [8, true, true, false], 8: [8, true, true, true], 9: [9, true, true, true]}
	for n in range(1, 10):
		r.held = "A"
		r.edge_break = 2
		r.strip_text = "x"
		r.model_text = "y"
		r.debug_jump(n)
		var got := [g.tide(), g.flag("P16"), g.flag("P18"), g.flag("P23")]
		check(JSON.stringify(got) == JSON.stringify(want[n]), "jump %d: %s (got %s)" % [n, want[n], got])
		check(g.state.room == ROOM and r.local_view == "room" and r.held == "" and r.edge_break == -1
			and r.strip_text == "" and r.model_text == "", "jump %d: clean" % n)
	r.debug_jump(1)
	check(r.state.slots == ["", "", "", ""] and not r.state.clipped and r.objective() == "p16", "jump 1: fresh")
	r.debug_jump(2)
	check(r.state.slots == REF_SOLUTION and not r.state.clipped, "jump 2: placed")
	play(g, ["contact_table"])
	g.give("chart_clips")
	use(g, "chart_clips", "clip")
	g.dispatch("cover")
	check(g.flag("P16"), "jump 2: clip and cover solve")
	r.debug_jump(3)
	check(r.state.clipped and not r.state.cover_off, "jump 3: clipped")
	play(g, ["contact_table", "cover"])
	check(g.flag("P16") and g.has_item("contact_sheet"), "jump 3: cover solves")
	r.debug_jump(4)
	check(g.has_item("contact_sheet") and r.objective() == "p18", "jump 4: P16 done")
	for rec in RECS:
		check(g.has_item(rec), "jump 4: %s in hand" % rec)
	r.debug_jump(5)
	check(r.state.filed.values() == RECS and r.date_text() == "17 OCT 1931", "jump 5: filed, today's date")
	for rec in RECS:
		check(not g.has_item(rec), "jump 5: %s in its folder" % rec)
	play(g, ["to_catalogue", "folders"])
	set_date(g, "18 OCT 1927")
	g.dispatch("compare")
	check(g.flag("P18"), "jump 5: date and compare solve")
	for rec in RECS:
		check(inv_count(g, rec) == 1, "jump 5: %s back once" % rec)
	r.debug_jump(5)
	var t := roundtrip(g)
	for rec in RECS:
		check(inv_count(t, rec) == 1, "jump 5 saved: %s back once" % rec)
	r.debug_jump(6)
	check(g.has_item("venn_correspondence") and not g.flag("P17") and r.objective() == "away_p17", "jump 6")
	r.debug_jump(7)
	check(r.shutter_open() and r.objective() == "p23", "jump 7: shutter open")
	r.debug_jump(8)
	check(g.has_item("witness_bridge") and r.state.stamp == "open", "jump 8: P23 done")
	r.debug_jump(9)
	check(g.weather_band() == 7 and r.aperture_width() == 2, "jump 9: band 7")

func test_flag_adoption() -> void:
	var g := with_flags(["P15", "P16"], ROOM)
	var t := roundtrip(g)
	var r := r10(t)
	check(t.flag("P16") and r.state.p16_complete and r.state.cover_off and r.state.slots == REF_SOLUTION, "P16 adopted on load")
	check(not t.has_item("contact_sheet"), "sync never gives the sheet")
	g = with_flags(["P15", "P16", "P18"], ROOM)
	t = roundtrip(g)
	check(t.flag("P18") and r10(t).state.drawer_open and not t.has_item("venn_correspondence"), "P18 adopted, no items")
	g = with_flags(["P15", "P16", "P17", "P18", "P21", "P23"], ROOM)
	r = r10(g)
	check(r.objective() == "done" and r.state.stamp == "open" and r.state.bridge_taken, "objective() syncs P23")
	check(not g.has_item("witness_bridge"), "no bridge from sync")
	g = fresh()
	r = r10(g)
	r.state.p16_complete = true
	r.state.cover_off = true
	r.reconcile()
	check(g.flag("P16"), "state sets the flag")

func load_with(patch: Dictionary, drop := []) -> R10Sim:
	var g := game_at(6, ROOM)
	for it in drop:
		g.take(it)
	var d := g.to_dict()
	for k in patch:
		d.rooms[ROOM][k] = patch[k]
	var t := GameSim.new()
	check(t.from_dict(JSON.parse_string(JSON.stringify(d))), "patched save loads %s" % [patch.keys()])
	return r10(t)

func test_malformed_saves() -> void:
	var init := R10Sim.new().initial_state()
	init.notices = r10(game_at(6, ROOM)).state.notices.duplicate()
	var r := load_with({"slots": 4, "clipped": "yes", "filed": [], "tray": "x", "day": "17", "month": true,
		"year": [], "stamp": 3, "wrap": "2", "notices": 5, "catalogue_notices": {}, "input": 1})
	var got := r.state.duplicate(true)
	got.notices = init.notices
	check(JSON.stringify(got) == JSON.stringify(init), "wrong types load as fresh (got %s)" % JSON.stringify(r.state))
	r = load_with({"day": 40, "month": 0, "year": 1700, "wrap": 9})
	check(r.state.day == 31 and r.state.month == 1 and r.state.year == 1889 and r.state.wrap == 0, "numbers clamped; wrap needs P18")
	r = load_with({"day": 12.5})
	check(r.state.day == 17, "fractional day refused")
	r = load_with({"stamp": "open", "bridge_taken": true, "strip2": true})
	check(r.state.stamp == "" and not r.state.bridge_taken and not r.state.strip2, "unearned OPEN cleared")
	r = load_with({"stamp": "closed", "input": true, "copy": true})
	check(r.state.stamp == "closed" and r.state.input and r.state.copy, "closed experiment kept")
	r = load_with({"copy": true, "witness": true})
	check(not r.state.copy and not r.state.witness, "plugs need input")
	r = load_with({"clipped": true, "slots": ["B", "A", "D", "C"]})
	check(not r.state.clipped and r.state.slots == ["B", "A", "D", "C"], "a clip needs the right order")
	r = load_with({"cover_off": true})
	check(r.state.p16_complete and r.state.clipped and r.state.slots == REF_SOLUTION and r.game.flag("P16"), "cover off implies P16")
	r = load_with({"notices": ["bogus", "ninth_photo", "ninth_photo"], "catalogue_notices": ["aperture_wide", "x"]})
	check(r.state.notices.count("ninth_photo") == 1 and not "bogus" in r.state.notices and r.state.catalogue_notices == ["aperture_wide"], "notices whitelisted")
	r = load_with({"filed": {"BODY": "nora_frame", "PLACE": "nora_frame", "NAME": "chart_clips", "X": "nora_spatial_strip"},
		"tray": ["nora_frame", "nora_register_card", "nora_register_card", "witness_bridge"]},
		["nora_spatial_strip"])  # R09 is built: tide VI starts with the strip in hand, so set it aside
	check(r.state.filed.values() == ["", "", ""] and r.state.tray.is_empty(), "a load always empties folders and tray")
	check(r.game.has_item("nora_frame") and r.game.has_item("nora_register_card") and not r.game.has_item("nora_spatial_strip"),
		"only the legal records come back")

## The lead's chain scripts: P16, P18, P23 on one game.
func test_chain_scripts() -> void:
	var g := game_at(6, ROOM)
	for rec in RECS:
		g.give(rec)
	play(g, ["contact_table", "loose_b", "slot_1", "loose_d", "slot_2", "loose_a", "slot_3", "loose_c", "slot_4",
		"item:chart_clips", "clip", "cover", "back"])
	check(g.flag("P16") and g.has_item("contact_sheet") and r10(g).local_view == "room", "chain P16")
	play(g, ["to_catalogue", "folders", "item:nora_frame", "fold_body", "item:nora_spatial_strip", "fold_place",
		"item:nora_register_card", "fold_name", "day_up", "year_dn", "year_dn", "year_dn", "year_dn", "compare", "back"])
	check(g.flag("P18") and g.has_item("venn_correspondence") and r10(g).local_view == "catalogue", "chain P18")
	for f in ["P17", "P19", "P20", "P21"]:
		g.set_flag(f)
	play(g, ["model", "t_input", "t_witness", "test", "back"])
	check(g.flag("P23") and g.has_item("witness_bridge"), "chain P23")
	for o in ["contact_sheet_1927", "index_protocol", "witness_test"]:
		check(g.has_seen(ROOM, o), "chain: %s noted" % o)
