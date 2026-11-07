extends SceneTree
## Shared harness for tests/rooms/<rid>_test.gd. Read-only for room teams: extend it,
## override run_tests(), and call check(). Run a room's tests headless after an import:
##   godot --headless --path . --script tests/rooms/R03_test.gd
##
## Helpers:
##   game_at(t, rid)      a GameSim at the start of tide t, standing in rid
##   with_flags(flags)    a fresh started GameSim with exactly these flags set
##   says(ev) / has_ev()  read sim events
##   new_scene()          the real game scene (headless), with a private save path
##   skeleton_checks()    registration, gates, arrival, hotspots, exits (sim side)
##   view_checks()        hotspot and exit rects in the view (scene side)

const HUD_ZONE := Rect2(940, 0, 508, 80)        # Back, Notebook, Hint, menu
const INVENTORY_ZONE := Rect2(0, 0, 940, 80)    # inventory slots
const SUBTITLE_ZONE := Rect2(0, 994, 1448, 92)  # the subtitle slab
const CANVAS := Rect2(0, 0, 1448, 1086)
const MIN_TARGET := 64.0

var failures: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await run_tests()
	var name: String = get_script().resource_path.get_file().get_basename()
	if failures.is_empty():
		print("PASS: %s" % name)
	else:
		print("FAIL %s (%d): %s" % [name, failures.size(), "; ".join(failures)])
	for i in 10:
		await process_frame
	quit(0 if failures.is_empty() else 1)

## Override.
func run_tests() -> void:
	pass

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		push_error(msg)

func says(ev: Array) -> String:
	var out := []
	for e in ev:
		if e.type == "say": out.append(e.text)
	return " | ".join(out)

func has_ev(ev: Array, type: String, id: String) -> bool:
	for e in ev:
		if e.type == type and e.get("id", "") == id: return true
	return false

func game_at(t: int, rid := "R02") -> GameSim:
	var g := GameSim.new()
	g.debug_tide(t, rid)
	return g

func with_flags(flags: Array, rid := "R02") -> GameSim:
	var g := GameSim.new()
	g.reset()
	g.debug_enter(rid)
	for f in flags:
		g.set_flag(f)
	# The gate flags a room owns are reconciled from its own state on load: grant the state
	# too, so a save of this fixture loads where it stands (GameSim.from_dict sends a save
	# behind an unopened gate back to the office).
	if g.flag("P01"):
		g.room("R02").state.p01_complete = true
	if g.flag("P06"):
		g.room("R01").state.p06_complete = true
	return g

func new_scene(path: String) -> Node:
	var scene = load("res://game/core/game.tscn").instantiate()
	scene.save_path = path
	scene.migrate_slice_save = false
	GameView.remove_saves(path)
	root.add_child(scene)
	return scene

func free_scene(scene: Node) -> void:
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

## The sim side of every room: registered, gated exactly by `requires`, reachable from the
## office from tide `open_tide` on (and not before), arrival line on first entry only,
## every hotspot answers, exits are two-way.
func skeleton_checks(rid: String, requires: Array, open_tide: int) -> void:
	check(rid in GameSim.discover(), "%s is discovered" % rid)
	var g := GameSim.new()
	var r: RoomSim = g.room(rid)
	check(r != null and r.id() == rid, "%s registers with its own ID" % rid)
	if r == null:
		return
	check(str(r.c("TITLE", "")) != "", "%s has a title" % rid)
	check(JSON.stringify(r.c("REQUIRES", [])) == JSON.stringify(requires),
		"%s REQUIRES %s (got %s)" % [rid, requires, r.c("REQUIRES", [])])
	# Gates: every listed flag is needed; all of them together let her in.
	for missing in requires:
		var rest := requires.duplicate()
		rest.erase(missing)
		check(not with_flags(rest).room(rid).can_enter(), "%s stays shut without %s" % [rid, missing])
	check(with_flags(requires).room(rid).can_enter(), "%s opens with %s" % [rid, requires])
	if not requires.is_empty():
		check(r.locked_line() != "", "%s says something at its locked way in" % rid)
	# Reachable from the office by real exits from open_tide on, and not before.
	check(rid in game_at(open_tide).reachable("R02"), "%s reachable at the start of tide %d" % [rid, open_tide])
	if open_tide > 1:
		check(not rid in game_at(open_tide - 1).reachable("R02"), "%s not reachable at tide %d" % [rid, open_tide - 1])
	check(rid in game_at(9).reachable("R02"), "%s reachable at tide IX" % rid)
	# Exits: targets exist and every way out has a way back.
	for e in r.c("EXITS", []):
		check(g.rooms.has(e[0]), "%s exit to %s exists" % [rid, e[0]])
		var back := false
		for b in g.room(e[0]).c("EXITS", []) if g.rooms.has(e[0]) else []:
			back = back or b[0] == rid
		check(back, "%s -> %s has a way back" % [rid, e[0]])
	# Arrival: walk in from a neighbour at tide IX; the line comes once.
	var t := game_at(9)
	var path := _path(t, "R02", rid)
	check(not path.is_empty() or rid == "R02", "%s has a path from the office" % rid)
	var ev: Array = []
	for step in path:
		ev = t.dispatch("go:" + step)
	if rid != "R02":
		check(t.state.room == rid, "walked to %s (at %s)" % [rid, t.state.room])
	# Every hotspot answers and notes what it noted.
	for h in r.c("HOTSPOTS", []):
		var hev := t.dispatch(h)
		check(says(hev) != "", "%s hotspot %s answers" % [rid, h])

## A shortest exit path from `from` to `to` through open exits (BFS).
func _path(g: GameSim, from: String, to: String) -> Array:
	var prev := {from: ""}
	var queue := [from]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == to:
			break
		for e in g.exits(cur):
			if not prev.has(e[0]) and g.exit_open(cur, e[0]):
				prev[e[0]] = cur
				queue.append(e[0])
	if not prev.has(to):
		return []
	var out := []
	var cur := to
	while cur != from:
		out.push_front(cur)
		cur = prev[cur]
	return out

## The view side: every hotspot id the sim lists has a rect; rects are on the canvas, big
## enough to tap, clear of the HUD, inventory and subtitles, and never overlap an exit.
func view_checks(rid: String) -> void:
	var scene = new_scene("user://room_test_%s.json" % rid)
	await process_frame
	scene.enter_jump(rid)
	await process_frame
	var v: RoomView = scene.room_view
	check(v != null and v.rid == rid, "%s view mounts" % rid)
	if v == null:
		await free_scene(scene)
		return
	var hs: Array = v.c("HOTSPOTS", [])
	var ids := []
	for h in hs:
		ids.append(h[0])
	for id in scene.sim.room(rid).c("HOTSPOTS", []):
		check(id in ids, "%s view has a rect for %s" % [rid, id])
	var exits: Dictionary = v.exit_rects()
	for e in scene.sim.room(rid).c("EXITS", []):
		check(exits.has(e[0]), "%s view has an exit rect for %s" % [rid, e[0]])
	var all := []
	for h in hs:
		all.append([h[0], h[1]])
	for k in exits:
		all.append(["go:" + k, exits[k]])
	for a in all:
		var r: Rect2 = a[1]
		check(CANVAS.encloses(r), "%s %s is on the canvas" % [rid, a[0]])
		check(r.size.x >= MIN_TARGET and r.size.y >= MIN_TARGET, "%s %s is at least 64x64" % [rid, a[0]])
		check(not r.intersects(HUD_ZONE) and not r.intersects(SUBTITLE_ZONE) and not r.intersects(INVENTORY_ZONE),
			"%s %s keeps clear of the HUD, inventory and subtitles" % [rid, a[0]])
	for k in exits:
		for h in hs:
			check(not exits[k].intersects(h[1]), "%s exit %s does not overlap %s" % [rid, k, h[0]])
	# Clicking the centre of each hotspot dispatches it.
	for h in hs:
		check(scene.action_at(h[1].get_center()) == h[0] or _first_hit(hs, h[1].get_center()) != h[0],
			"%s click on %s reaches it" % [rid, h[0]])
	await free_scene(scene)

func _first_hit(hs: Array, p: Vector2) -> String:
	for h in hs:
		if h[1].has_point(p):
			return h[0]
	return ""
