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
##   - an unbuilt room offers only the way back, so exits to or from one (none since Wave 3);
##   - "Back" with no close-up open (a sim no-op the chain script sends to be sure).
##
## Two modes, both run by default: clicks alone, and pointer mode, where before every probe
## and click the pointer is moved to the point first (GameView.hover(), the mouse-motion
## handler's own update, with a simulated pointer), so controls that only show or answer
## under a hovering pointer are tested as a real pointer sees them. One mode only:
##   godot --headless --path . --script tests/click_chain_test.gd -- --mode=click|pointer
## Also: close-up controls act in the press that advances a story chain, and the HUD's
## Plan button (after P05) opens the notebook on the plan.
## Run after an import:
##   godot --headless --path . --script tests/click_chain_test.gd

const STEP := 0.1
## R12's SEVER first page turns only after its last line (18.2 s, two seconds after the eighth
## indicator goes out) has been read: about 21 s.
const WAIT_MAX := 25.0
## A held click waits for the whole chain: R12's CONTINUE preview (blinks and held breaths)
## plays ~15.2 s of story after the click.
const HELD_MAX := 30.0
const GRID := 12
## Unique to this process: user:// is shared by every checkout of the project.
var SAVE := "user://click_chain_test_p%d.json" % OS.get_process_id()

var A: GameView
var failures: Array = []
var total := 0
var clicked := 0
var reading := 0
var deferred := 0   # clicks the core held until the chain ended (pending_action / pending_travel)
var conveniences := {}
var cur_pid := ""
var pointer_mode := false
var plan_checked := false

func _initialize() -> void:
	call_deferred("run")

## The modes to run: both, unless `-- --mode=click` or `-- --mode=pointer` names one.
static func modes() -> Array:
	for a in OS.get_cmdline_user_args():
		if a == "--mode=click":
			return [false]
		if a == "--mode=pointer":
			return [true]
	return [false, true]

func run() -> void:
	var summaries := []
	for mode in modes():
		summaries.append(await run_mode(mode))
	await test_closeup_click_acts()
	await test_nav_during_chain()
	var summary := "; ".join(summaries)
	if failures.is_empty():
		print("PASS: click_chain_test — " + summary)
	else:
		print("FAIL click_chain_test (%d): %s\n  %s" % [failures.size(), "; ".join(failures), summary])
	quit(0 if failures.is_empty() else 1)

func new_game_scene() -> GameView:
	GameView.remove_saves(SAVE)
	var scene: GameView = load("res://game/core/game.tscn").instantiate()
	scene.save_path = SAVE
	scene.migrate_slice_save = false
	root.add_child(scene)
	return scene

## The whole chain, by clicks, in one mode. Returns its summary.
func run_mode(pointer: bool) -> String:
	pointer_mode = pointer
	total = 0
	clicked = 0
	reading = 0
	deferred = 0
	conveniences = {}
	plan_checked = false
	var before := failures.size()
	A = new_game_scene()
	A.sim_pointer_on = pointer
	await process_frame
	var chain = load("res://tests/chain_test.gd").new()
	chain.external_game = A.sim
	chain.clicker = self
	chain.step_hook = func(pid: String, _rid: String, phase: String) -> void:
		cur_pid = pid
		plan_hook(pid, phase)
	await chain.run_tests()
	for f in chain.failures:
		failures.append("chain: " + f)
	chain.free()
	var tag := "pointer" if pointer else "click"
	check(clicked + _sum(conveniences) == total, "[%s] every action was clicked or is a listed convenience" % tag)
	check(plan_checked, "[%s] the Plan button was clicked after P05" % tag)
	for i in range(before, failures.size()):
		failures[i] = "[%s] %s" % [tag, failures[i]]
	GameView.remove_saves(SAVE)
	A.queue_free()
	await process_frame
	return "%s mode: %d actions, %d clicked (%d held to the chain's end), %d reading clicks, conveniences %s" % [tag, total, clicked, deferred, reading, conveniences]

## The HUD's Plan button: not there before P05; after it, one click opens the notebook on
## the plan, and Back returns to the room as it was.
func plan_hook(pid: String, phase: String) -> void:
	if phase != "at":
		return
	if pid == "P05":
		check(find("plan").x < 0, "no Plan button before P05")
	elif pid == "P06" and not plan_checked:
		var room_before: String = A.sim.state.room
		wait(GameView.PLAN_AFTER_BACK + STEP)   # a Plan press right after a Back is ignored
		var p := find("plan")
		check(p.x >= 0, "the Plan button is on the HUD after P05")
		if p.x < 0:
			return
		A.click(p)
		check(A.sim.view == "notebook" and A._nb_page() == "plan", "one click on Plan: the notebook on the plan")
		var b := find("back")
		check(b.x >= 0, "the notebook's Back is clickable")
		A.click(b)
		check(A.sim.view == "room" and A.sim.state.room == room_before, "Back from the plan: the room as it was")
		wait(STEP)
		plan_checked = true

## Moves the pointer to `p` in pointer mode (the mouse-motion handler's own update).
func point(p: Vector2) -> void:
	if pointer_mode:
		A.hover(p)

## Under the pointer (pointer mode: moved there first), the action at `p`.
func probe(p: Vector2) -> String:
	point(p)
	return A.action_at(p)

## Click at `p`, the pointer moved there first in pointer mode.
func press(p: Vector2) -> void:
	point(p)
	A.click(p)

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
	for b in A.hud_buttons():
		if b[0] == action:
			guesses.append(b[1])
	if action == "back":
		guesses.append(GameView.BACK_RECT)
	for b in GameView.END_BUTTONS:
		if b[0] == action:
			guesses.append(b[1])
	for r in guesses:
		if r.size != Vector2.ZERO and probe(r.get_center()) == action:
			return r.get_center()
	for y in range(GRID / 2, 1086, GRID):
		for x in range(GRID / 2, 1448, GRID):
			if probe(Vector2(x, y)) == action:
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
			press(pg)
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
	# A hotspot clicked while a chain still has lines queued, or an exit clicked mid-reveal,
	# is held by the core (pending_action / pending_travel) and lands on its own as the chain
	# ends: that counts as the click landing, and is never clicked a second time.
	var t := 0.0
	while t <= WAIT_MAX:
		var id0: int = A.click_id
		press(p)
		if A.click_id != id0:
			clicked += 1
			wait(STEP)
			return A.last_events
		if A.pending_action == action or A.pending_travel == action:
			var held := 0.0
			while A.click_id == id0 and held < HELD_MAX and (A.pending_action == action or A.pending_travel == action):
				wait(STEP)
				held += STEP
			if A.click_id != id0:
				clicked += 1
				deferred += 1
				wait(STEP)
				return A.last_events
		reading += 1
		wait(STEP)
		t += STEP
		if probe(p) != action:
			var q := find(action)
			if q.x >= 0:
				p = q
	check(false, "[%s] a click on '%s' never landed in %s" % [cur_pid, action, ctx()])
	return []

## A close-up control clicked while a story line is still typing acts in that press: R03's
## chart-sheet rotate turns the sheet once (the chain advances in the same press).
func test_closeup_click_acts() -> void:
	pointer_mode = false
	A = new_game_scene()
	await process_frame
	A.room_jump("R03", 1)
	var r: RoomSim = A.room_sim()
	A.dispatch("sheet_table")
	check(r.local_view == "c_registration", "R03: the registration close-up is open (%s)" % r.local_view)
	A.dispatch("item:venn_tide_sheet")
	A.dispatch("reg_table")
	check(bool(r.state.reg_laid), "R03: his sheet is laid on the table")
	wait(6.0)
	A._show_line("The sheet is a stranger's handwriting over a chart I know.", true)
	A._queue_line("And one more line after it.", 0.8, true)
	A.time += 0.5   # past the double-click swallow, the line still typing
	check(A.chain_active(), "a story line is typing over the close-up")
	var rot := int(r.state.reg_rot)
	var p := find("reg_rot_cw")
	check(p.x >= 0, "the rotate control is clickable during the line")
	A.click(p)
	check(int(r.state.reg_rot) == posmod(rot + 1, 4), "one click on rotate turns the sheet once (%d -> %d)" % [rot, int(r.state.reg_rot)])
	check(A.cur_text == "And one more line after it.", "and the chain advanced in the same press (%s)" % A.cur_text)
	# A click on empty space during a chain only advances it.
	A._show_line("Another story line.", true)
	A._queue_line("Its follow-up.", 0.8, true)
	A.time += 0.5
	var before := JSON.stringify(r.state)
	A.click(Vector2(724, 1040))   # the subtitle bar
	check(JSON.stringify(r.state) == before and A.cur_text == "Its follow-up.", "a subtitle-bar click only advances the chain")
	GameView.remove_saves(SAVE)
	A.queue_free()
	await process_frame

## Pointer mode: an in-room step (R05's to_kitchen) clicked during the P07 reveal rushes the
## rest of the reveal and lands as it ends, like an exit; no waiting out the full chain.
func test_nav_during_chain() -> void:
	pointer_mode = true
	A = new_game_scene()
	A.sim_pointer_on = true
	await process_frame
	A.tide_jump(3, "R05")
	var k: R05Sim = A.room_sim()
	A.dispatch("bowl_stack")
	for i in 9:
		A.dispatch("slot_%d" % R05Sim.RACK_HOME.find(R05Sim.SOLUTION[i]))
		A.dispatch("place_%d" % (i + 1))
	var guard := 0
	while int(k.state.tally) != R05Sim.SOLUTION_TALLY and guard < 30:
		A.dispatch("tally_up" if int(k.state.tally) < R05Sim.SOLUTION_TALLY else "tally_down")
		guard += 1
	A.dispatch("compare")
	check(A.sim.flag("P07"), "nav: P07 committed")
	wait(0.5)
	A.dispatch("back")
	wait(0.5)
	check(k.local_view == "room" and A._story_queued(), "nav: at the mess table with the P07 reveal still queued (%s)" % k.local_view)
	var unrushed: float = A._story_backlog_end()
	var p := find("to_kitchen")
	check(p.x >= 0, "nav: the kitchen door is clickable during the reveal")
	if p.x < 0:
		A.queue_free()
		await process_frame
		return
	var t0: float = A.time
	press(p)
	var rushed: float = A._story_backlog_end()
	check(A.pending_action == "to_kitchen" or k.local_view == "kitchen", "nav: the step waits for the rushed reveal (%s)" % A.pending_action)
	check(rushed < unrushed - 0.5, "nav: the rest of the reveal is rushed (%.2f s, was %.2f s)" % [rushed - t0, unrushed - t0])
	var landed := -1.0
	for i in 200:
		A._process(0.05)
		if k.local_view == "kitchen":
			landed = A.time
			break
	check(landed > 0.0 and landed <= rushed + 0.3, "nav: in the kitchen as the rushed reveal ends (%.2f s after the click, chain ended at %.2f s, unrushed %.2f s)" % [landed - t0, rushed - t0, unrushed - t0])
	# With nothing queued, a step goes at once.
	A.dispatch("to_mess")
	wait(12.0)
	var q := find("to_kitchen")
	press(q)
	check(k.local_view == "kitchen", "nav: with no reveal, the step goes in the same press")
	GameView.remove_saves(SAVE)
	A.queue_free()
	await process_frame
