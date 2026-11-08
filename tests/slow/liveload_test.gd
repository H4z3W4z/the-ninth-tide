extends SceneTree
## Slow, optional (not in the default suite): the canonical chain driven through a live game
## scene A (A.dispatch, the views playing every event). After every action A saves; a fresh
## scene B loads that save, presses Begin if it is on the title, runs 1.5 s of frames and
## draws, and must resume in the same room, its view matching its sim, a close-up there with
## a way out. Every seventh action B also takes notebook / back / hint / menu / back / back
## without throwing. Folded in from QA p2's liveload probe. Run after an import (minutes):
##   godot --headless --path . --script tests/slow/liveload_test.gd

const PA := "user://liveload_test_a.json"
const PB := "user://liveload_test_b.json"

var A: GameView
var n := 0
var failures: Array = []
var cur := ""

func _initialize() -> void:
	call_deferred("run")

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("[%s #%d] %s" % [cur, n, msg])
		push_error(msg)

func run() -> void:
	GameView.remove_saves(PA)
	A = load("res://game/core/game.tscn").instantiate()
	A.save_path = PA
	A.migrate_slice_save = false
	root.add_child(A)
	await process_frame
	var chain = load("res://tests/chain_test.gd").new()
	chain.external_game = A.sim
	chain.clicker = self
	chain.step_hook = func(pid: String, _rid: String, phase: String) -> void:
		cur = pid + "/" + phase
	await chain.run_tests()
	for f in chain.failures:
		failures.append("chain: " + f)
	chain.free()
	A.queue_free()
	GameView.remove_saves(PA)
	GameView.remove_saves(PB)
	for i in 5:
		await process_frame
	if failures.is_empty():
		print("PASS: liveload_test — %d actions, each save reloaded live" % n)
	else:
		print("FAIL liveload_test (%d): %s" % [failures.size(), "; ".join(failures)])
	quit(0 if failures.is_empty() else 1)

## One chain action on A, then A's save loaded live in a fresh scene B.
func qd(action: String) -> Array:
	n += 1
	A.dispatch(action)
	var ev: Array = A.last_events
	for i in 3:
		A._process(0.1)
	if A.sim.view == "title":
		return ev
	A._save_progress()
	var txt := FileAccess.get_file_as_string(PA)
	GameView.remove_saves(PB)
	var f := FileAccess.open(PB, FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	var B: GameView = load("res://game/core/game.tscn").instantiate()
	B.save_path = PB
	B.migrate_slice_save = false
	root.add_child(B)
	if B.sim.view == "title":
		B.dispatch("begin")
	for i in 15:
		B._process(0.1)
	B._redraw()
	var room_a: String = A.sim.state.room
	check(B.sim.state.room == room_a, "resumed in %s, saved in %s after '%s'" % [B.sim.state.room, room_a, action])
	if B.room_view == null or B.room_view.rid != B.sim.state.room:
		check(false, "view/sim room mismatch after load")
	else:
		check(B.room_view.sim == B.sim.room(), "the view's room sim is the loaded one")
	if B.sim.view == "room" and B.room_sim().is_closeup():
		check(B.room_view.back_visible() or B.room_view.esc_action() != "",
			"loaded into close-up %s with no way out" % B.room_sim().local_view)
	if n % 7 == 0:
		for a in ["notebook", "back", "hint", "menu", "back", "back"]:
			B.dispatch(a)
			B._process(0.2)
	B.queue_free()
	return ev
