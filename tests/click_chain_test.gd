extends SceneTree
## The canonical chain (tests/chain_test.gd), played on the real game scene with every
## action carried out as a click at a point where GameView.action_at() returns it, as a
## player would have to. Story chains and room holds are clicked through, the clock moving
## in 0.1 s steps (up to 15 s for an action to become clickable, or for its click to land).
##
## An action no click can reach fails the test, except the known sim conveniences, which
## are dispatched and counted:
##   - R03 and R06 turn to the wall that holds a hotspot (wall auto-switch);
##   - R02's "door" is the corridor exit (go:R03);
##   - the unbuilt rooms R09-R12 offer only the way back, so exits to or from them;
##   - "Back" with no close-up open (a sim no-op the chain script sends to be sure).
## Run after an import:
##   godot --headless --path . --script tests/click_chain_test.gd

const STEP := 0.1
const WAIT_MAX := 15.0
const GRID := 12
const SAVE := "user://click_chain_test.json"

var A: GameView
var failures: Array = []
var total := 0
var clicked := 0
var reading := 0
var conveniences := {}
var cur_pid := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	GameView.remove_saves(SAVE)
	A = load("res://game/core/game.tscn").instantiate()
	A.save_path = SAVE
	A.migrate_slice_save = false
	root.add_child(A)
	await process_frame
	var chain = load("res://tests/chain_test.gd").new()
	chain.external_game = A.sim
	chain.clicker = self
	chain.step_hook = func(pid: String, _rid: String, _phase: String) -> void: cur_pid = pid
	await chain.run_tests()
	for f in chain.failures:
		failures.append("chain: " + f)
	chain.free()
	check(clicked + _sum(conveniences) == total, "every action was clicked or is a listed convenience")
	GameView.remove_saves(SAVE)
	A.queue_free()
	await process_frame
	var summary := "%d actions, %d clicked, %d reading clicks, conveniences %s" % [total, clicked, reading, conveniences]
	if failures.is_empty():
		print("PASS: click_chain_test — " + summary)
	else:
		print("FAIL click_chain_test (%d): %s\n  %s" % [failures.size(), "; ".join(failures), summary])
	quit(0 if failures.is_empty() else 1)

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		push_error(msg)

static func _sum(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n

func ctx() -> String:
	return "%s/%s/%s" % [A.sim.view, A.sim.state.room, A.room_sim().local_view]

## Advances the scene's clock (presentation only: lines, holds, sounds, the card).
func wait(s: float) -> void:
	var t := 0.0
	while t < s - 0.0001:
		A._process(STEP)
		t += STEP

## A point where action_at(p) == action: the obvious rects first (the room's control rect,
## exits, the HUD, inventory, notebook rows), then a grid over the canvas.
func find(action: String) -> Vector2:
	var guesses: Array = []
	if A.room_view:
		guesses.append(A.room_view.control_rect(action))
		if action.begins_with("go:"):
			guesses.append(A.room_view.live_exit_rects().get(action.substr(3), Rect2()))
	for slot in A._inv_layout():
		if slot[1] == action:
			guesses.append(slot[0])
	for b in GameView.HUD_BUTTONS:
		if b[0] == action:
			guesses.append(b[1])
	if action == "back":
		guesses.append(GameView.BACK_RECT)
	for b in GameView.END_BUTTONS:
		if b[0] == action:
			guesses.append(b[1])
	for r in guesses:
		if r.size != Vector2.ZERO and A.action_at(r.get_center()) == action:
			return r.get_center()
	for y in range(GRID / 2, 1086, GRID):
		for x in range(GRID / 2, 1448, GRID):
			if A.action_at(Vector2(x, y)) == action:
				return Vector2(x, y)
	return Vector2(-1, -1)

## The known sim conveniences (see the header): the name it is counted under, or "".
func convenience(action: String) -> String:
	var rid: String = A.sim.state.room
	var r := A.room_sim()
	if action == "back" and A.sim.view == "room" and not r.is_closeup():
		return "no-op back"
	if rid in ["R03", "R06"] and A.sim.view == "room" and not r.is_closeup() and not action.contains(":"):
		return "%s wall auto-switch" % rid
	if rid == "R02" and action == "door":
		return "R02 door"
	if action.begins_with("go:") and (A.sim.is_unbuilt(rid) or A.sim.is_unbuilt(action.substr(3))):
		return "unbuilt-room exits"
	return ""

## One chain action, as a click (chain_test calls this through its clicker hook).
func qd(action: String) -> Array:
	total += 1
	var p := find(action)
	if p.x < 0 and action.begins_with("item:"):
		for i in 4:   # the item may be on another inventory page
			var pg := find("inv_page")
			if pg.x < 0:
				break
			A.click(pg)
			p = find(action)
			if p.x >= 0:
				break
	var waited := 0.0
	while p.x < 0 and waited < WAIT_MAX:
		wait(1.0)
		waited += 1.0
		p = find(action)
	if p.x < 0:
		var why := convenience(action)
		check(why != "", "[%s] '%s' cannot be clicked in %s" % [cur_pid, action, ctx()])
		conveniences[why if why != "" else "UNCLICKABLE"] = int(conveniences.get(why if why != "" else "UNCLICKABLE", 0)) + 1
		var ev := A.sim.dispatch(action)
		A.play_events(ev)
		A._mount_room()
		A.last_events = ev
		return ev
	# Click until the click lands (a playing chain or a room hold takes the clicks before it).
	var t := 0.0
	while t <= WAIT_MAX:
		var id0: int = A.click_id
		A.click(p)
		if A.click_id != id0:
			clicked += 1
			wait(STEP)
			return A.last_events
		reading += 1
		wait(STEP)
		t += STEP
		if A.action_at(p) != action:
			var q := find(action)
			if q.x >= 0:
				p = q
	check(false, "[%s] a click on '%s' never landed in %s" % [cur_pid, action, ctx()])
	return []
