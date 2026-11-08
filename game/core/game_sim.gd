class_name GameSim
extends RefCounted
## Deterministic state for the whole game: tides, flags, inventory, notebook, travel,
## saves. Node-free. No clocks, no randomness: every change is caused by an action.
##
## dispatch(action) mutates state and returns presentation events exactly like the
## Intake Office slice did: {type: "say", text, delay, story} | {type: "sfx", id, delay} |
## {type: "fx", id, ...}. Delays are seconds after the click that caused them.
##
## Rooms are discovered, not listed: every game/rooms/<rid>/<rid>_sim.gd is a room. Adding
## a room never edits this file. See docs/dev/room-contract.md.
##
## Core actions: begin, notebook, menu, hint, back, resume, toggle_motion, toggle_soft,
## restart, new_game, return_decision, "go:<rid>" (an exit), "plan:<rid>" (fast travel from
## the notebook plan, after P05), "item:<id>" (select / deselect an inventory item),
## "tab:<rid>|plan" (notebook page). Anything else goes to the current room.

## Full-game save schema. 5 was the Intake Office slice; its saves migrate (migrate_slice).
const SCHEMA := 6
const SLICE_SCHEMA := 5
const START_ROOM := "R02"
const ROOMS_DIR := "res://game/rooms"
## Cross-room facts that are not puzzle flags (docs/design/puzzle-cards/flags.md sections 2
## and 6). Puzzle flags are "P01".."P27"; the cards' "p01_complete" spelling means the same flag.
## Room-local facts that another room may read are "<rid>.<name>".
const GLOBAL_FLAGS := ["closure_report_filed", "t1x_threshold_crossed", "t1x_turned",
	"o01_found", "o02_found", "o03_found", "o04_found", "o05_found", "o06_found"]
## The movement-event whitelist (flags.md section 3): the only things Ada's trace records.
const MOVES := {
	"lamp_mended": "Mended the lamp.", "log_read": "Read his log.",
	"drawer_opened": "Opened his drawer.", "recording_played": "Played tomorrow's recording.",
	"charts_aligned": "Aligned the charts.", "report_signed": "Signed for two.",
	"held_still": "Held still.", "turned_round": "Turned round.",
	"zero_turned": "Turned the zero wheel.", "interval_set": "Set the interval.",
	"hatch_opened": "Opened the hatch.", "stair_looked": "Looked down the stair.",
}
const MOVES_MAX := 8
const P05_TRACE_LEN := 3

const TIDE_TITLES := ["The Last Shift", "The Boat at the Window", "Supper for the Absent",
	"The Room Beneath the Water", "A Body of Measurements", "The Other Side of the Glass",
	"The Man Who Left You a Letter", "An Incomplete Person", "The Ninth Tide"]
const NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]

## The two endings (GDD section 9). Ids are the cards' `ending_choice` values. The chamber
## room (R12) calls finish(); the core shows the end card. `still` is an optional painted
## plate drawn faintly under the card (a missing file draws nothing).
const ENDINGS := {
	"sever": {"title": "The Unrecorded Shore", "lines": [
		"I write eight names. Then his.",
		"\"I cannot certify their absence.\"",
	], "still": "res://assets/rooms/R12/end_a_page.png"},
	"continue": {"title": "The Last Observer", "lines": [
		"\"Subject Bell possesses no surviving personal effects.\"",
		"\"Nora Bell took her tea without sugar. Begin there.\"",
	], "still": "res://assets/rooms/R12/end_b_field.png"},
}

const GENERIC_WRONG_USE := "That isn't what it's for."

## Items whose last use is the puzzle named: when that flag is set and she holds the item, it
## leaves the bar and is filed in the notebook (state.retired), never to be handed back.
## Only items with no later use anywhere (puzzle cards and room sims, checked Wave 3):
## inspection_lens is still wanted after P15 (R10's photographs and frame glass give evidence
## under it), so it stays in her hands; contact_sheet waits for both P17 and P18.
## A list means all of them: the contact sheet serves P17 and P18, in either order.
const ITEM_RETIRES_AFTER := {"chart_clips": "P16", "contact_sheet": ["P17", "P18"],
	"venn_correspondence": "P20", "pencil": "P22"}
const FILED_LINE := "Filed in the notebook."

## Each puzzle's prerequisites (flags.md section 2; tests/chain_test.gd GRAPH): a puzzle is
## open when every one is set.
const PUZZLE_REQUIRES := {
	"P01": [], "P02": ["P01"], "P03": ["P01"],
	"P04": ["P02", "P03", "closure_report_filed", "t1x_threshold_crossed"], "P05": ["P04"],
	"P06": ["P05"], "P07": ["P06"], "P08": ["P06"], "P09": ["P07", "P08"], "P10": ["P09"],
	"P11": ["P09"], "P12": ["P10", "P11"], "P13": ["P12"], "P14": ["P13"], "P15": ["P14"],
	"P16": ["P15"], "P17": ["P16"], "P18": ["P16"], "P19": ["P17", "P18"], "P20": ["P17", "P18"],
	"P21": ["P19", "P20"], "P22": ["P21"], "P23": ["P21"], "P24": ["P22", "P23"], "P25": ["P24"],
	"P26": ["P25"], "P27": ["P26"],
}
## Room objective ids that name a puzzle without spelling it "pNN..." (see objective_puzzle()).
const OBJECTIVE_PUZZLES := {
	"R01": {"inspect": "P06", "signal": "P06"},
	"R02": {"lamp": "P01", "log": "P03", "changed": "P03", "drawer": "P03", "board": "P20"},
	"R03": {"sheet_missing": "P03", "register": "P03", "calibrate": "P04", "record": "P05", "plan": "P21"},
	"R12": {"frames": "P25", "routing": "P26", "decide": "P27", "finale": "P27"},
}

static var _room_scripts := {}   # dir -> {rid: Script}, discovered once per run

var rooms := {}        # rid -> RoomSim
var order: Array = []  # rids, sorted
var state := {}
## Saved apart from the story. endings_seen lives here so it survives New game (flags.md).
var settings := {"motion": true, "soft_audio": false, "endings_seen": []}
var view := "title"
var return_view := "room"   # where Back goes from the notebook / menu
var selected_item := ""     # transient: the inventory item in hand
var nb_tab := ""            # transient: the notebook page ("" = current room)
var start_room := START_ROOM

func _init(rooms_dir := ROOMS_DIR) -> void:
	for rid in discover(rooms_dir):
		var r: RoomSim = _room_scripts[rooms_dir][rid].new()
		r.game = self
		rooms[rid] = r
	order = rooms.keys()
	order.sort()
	start_room = START_ROOM if rooms.has(START_ROOM) else (order[0] if not order.is_empty() else "")
	reset()

## Every directory under `dir` that holds <name>/<name>_sim.gd is a room. Cached per run.
static func discover(dir := ROOMS_DIR) -> Array:
	if not _room_scripts.has(dir):
		var found := {}
		var names := DirAccess.get_directories_at(dir)
		for rid in names:
			var path := "%s/%s/%s_sim.gd" % [dir, rid, rid]
			if ResourceLoader.exists(path):
				var script = load(path)
				if script is Script:
					found[rid] = script
		_room_scripts[dir] = found
	var out: Array = _room_scripts[dir].keys()
	out.sort()
	return out

func reset(keep_settings := true) -> void:
	if not keep_settings:
		settings = {"motion": true, "soft_audio": false, "endings_seen": []}
	state = {
		"schema": SCHEMA, "started": false, "room": start_room, "visited": [],
		"flags": {}, "inventory": [], "notebook": [], "movement_events": [], "p05_trace": [],
		"hint": {"for": "", "level": 0}, "rooms": {}, "ending": "", "retired": [],
	}
	for rid in order:
		var r: RoomSim = rooms[rid]
		r.state = r.initial_state()
		r.local_view = "room"
		state.rooms[rid] = r.state
	view = "title"
	return_view = "room"
	selected_item = ""
	nb_tab = ""

# ---------------------------------------------------------------------------
# global state API (for rooms)
# ---------------------------------------------------------------------------
func room(rid := "") -> RoomSim:
	return rooms.get(state.room if rid == "" else rid)

## The canonical spelling of a flag: the cards' "p07_complete" is "P07". Anything else is
## returned unchanged.
static func canon_flag(name: String) -> String:
	if name.length() == 12 and name.begins_with("p") and name.ends_with("_complete") \
			and name.substr(1, 2).is_valid_int():
		return "P" + name.substr(1, 2)
	return name

func flag(name: String) -> bool:
	return bool(state.flags.get(canon_flag(name), false))

## Sets or clears a cross-room flag. Only valid ids (see _valid_flag) are kept, so a typo is
## an error at the call, not a flag that silently vanishes on the next load.
func set_flag(name: String, on := true) -> void:
	name = canon_flag(name)
	if not _valid_flag(name):
		push_error("GameSim.set_flag: unknown flag '%s' (see docs/design/puzzle-cards/flags.md)" % name)
		return
	if on:
		state.flags[name] = true
	else:
		state.flags.erase(name)

func solved(pid: String) -> bool:
	return flag(pid)

## Marks a puzzle (or a transition flag such as "t1x_threshold_crossed") complete.
## Idempotent: a repeated commit never re-rewards or re-advances. When the tide advances,
## a {fx: "tide", tide: n} event follows.
func solve(pid: String, ev: Array) -> void:
	if flag(pid):
		return
	var before := tide()
	set_flag(pid)
	var after := tide()
	if after != before:
		ev.append({"type": "fx", "id": "tide", "tide": after})

## True when every flag that ends `item`'s use (ITEM_RETIRES_AFTER) is set.
func _spent(item: String) -> bool:
	var after = ITEM_RETIRES_AFTER[item]
	for f in (after if after is Array else [after]):
		if not flag(f):
			return false
	return true

## Which retirable items are spent right now: {item: bool}, taken before an action.
func _spent_snapshot() -> Dictionary:
	var out := {}
	for item in ITEM_RETIRES_AFTER:
		out[item] = _spent(item)
	return out

## Files every held item whose use ended during this action (its flags became true since
## `before`, a _spent_snapshot()), after the room is done with it, and says so once, after
## the last line of the chain. A state that already had the flags (a debug jump, an old
## save) keeps what she holds.
func _file_spent(before: Dictionary, ev: Array) -> void:
	var any := false
	for item in ITEM_RETIRES_AFTER:
		if not before.get(item, true) and _spent(item) and has_item(item) and not item in state.retired:
			take(item)
			state.retired.append(item)
			any = true
	if not any:
		return
	var last := 0.0
	for e in ev:
		if e.type == "say":
			last = maxf(last, float(e.delay))
	ev.append({"type": "say", "text": FILED_LINE, "delay": last + 0.5 if last > 0.0 else 0.0, "story": false})

## Items filed in the notebook after their last use, in the order they went.
func retired() -> Array:
	return state.retired.duplicate()

## Puzzle ids of tide n (1..9): P(3n-2)..P(3n).
static func tide_puzzles(n: int) -> Array:
	return ["P%02d" % (3 * n - 2), "P%02d" % (3 * n - 1), "P%02d" % (3 * n)]

## The flags whose completion ends tide n (flags.md section 1). Earlier puzzles of a tide
## gate its last one, so these imply the rest in real play.
const TIDE_DONE := [["P02", "P03"], ["P06"], ["P09"], ["P12"], ["P15"], ["P17", "P18"],
	["P21"], ["P24"], ["P27"]]

func tide_done(n: int) -> bool:
	if n < 1 or n > 9:
		return false
	for p in TIDE_DONE[n - 1]:
		if not flag(p):
			return false
	return true

## The number of tides behind her: tide() - 1, or 9 once P27 is done.
func tides_completed() -> int:
	return 9 if tide_done(9) and tide() == 9 else tide() - 1

## The current tide, 1..9: the lowest tide not done. Tide II does not begin until the Tide I
## transition's threshold is crossed. Holds at 9 after P27 (the cards' "10"): the ending
## reads P27 and ending_choice, not the tide. Derived from flags, never a clock.
func tide() -> int:
	for n in range(1, 10):
		if not tide_done(n) or (n == 1 and not flag("t1x_threshold_crossed")):
			return n
	return 9

## Station-wide weather band 0..7 (GDD section 5 table, flags.md weather_band()): the count
## of tides II..VIII done. 0 arrival through Tide I, 1 after Tide II ... 7 after Tide VIII;
## Tide IX holds 7.
func weather_band() -> int:
	var k := 0
	for n in range(2, 9):
		if tide_done(n):
			k += 1
	return k

## The notebook station plan and fast travel (P05).
func plan_unlocked() -> bool:
	return flag("P05")

## True when the room's way in is open (its REQUIRES); exits may add their own flags.
func room_open(rid: String) -> bool:
	return rooms.has(rid) and rooms[rid].can_enter()

## Cross-room values that are not booleans (flags.md section 2): "p05_trace",
## "movement_events", "ending_choice" (the state's `ending`), "endings_seen". Copies.
func value(name: String) -> Variant:
	match name:
		"p05_trace", "movement_events":
			return state[name].duplicate()
		"ending_choice":
			return state.ending
		"endings_seen":
			return settings.endings_seen.duplicate()
	push_error("GameSim.value: unknown value '%s'" % name)
	return null

## Freezes P05's trace: the last three movement events, once (R03 calls it at RECORD). A
## second call keeps the first value; P25 shows the stored value, never a recomputation.
func freeze_p05_trace() -> Array:
	if state.p05_trace.is_empty():
		var m: Array = state.movement_events
		state.p05_trace = m.slice(maxi(m.size() - P05_TRACE_LEN, 0))
	return state.p05_trace.duplicate()

func tide_title(n := -1) -> String:
	if n < 0:
		n = tide()
	return "Tide %s  ·  %s" % [NUMERALS[n - 1], TIDE_TITLES[n - 1]]

func has_item(item: String) -> bool:
	return item in state.inventory

## All items any room declares: {id: {name, desc, room}}.
func item_defs() -> Dictionary:
	var out := {}
	for rid in order:
		var defs: Dictionary = rooms[rid].c("ITEMS", {})
		for k in defs:
			var d: Dictionary = defs[k].duplicate()
			d["room"] = rid
			out[k] = d
	return out

## Hands her `item`. A retired item (filed in the notebook after its last use) never comes back.
func give(item: String, ev: Array = []) -> void:
	if not has_item(item) and not item in state.retired:
		state.inventory.append(item)
		ev.append({"type": "fx", "id": "item_added", "item": item})

func take(item: String) -> void:
	state.inventory.erase(item)
	if selected_item == item:
		selected_item = ""

func observe(rid: String, obs: String) -> void:
	var key := rid + "." + obs
	if not key in state.notebook:
		state.notebook.append(key)

func has_seen(rid: String, obs: String) -> bool:
	return (rid + "." + obs) in state.notebook

func seen_in(rid: String) -> Array:
	var out := []
	var prefix := rid + "."
	for k in state.notebook:
		if k.begins_with(prefix):
			out.append(k.substr(prefix.length()))
	return out

## Records one whitelisted movement event (MOVES) for P05. Consecutive duplicates collapse;
## the oldest drop past MOVES_MAX. Unknown ids are an error and are not recorded.
func record_move(id: String) -> void:
	if not MOVES.has(id):
		push_error("GameSim.record_move: '%s' is not in the movement whitelist" % id)
		return
	var m: Array = state.movement_events
	if not m.is_empty() and m[-1] == id:
		return
	m.append(id)
	while m.size() > MOVES_MAX:
		m.pop_front()

## The recorder's printed line for a movement event id.
static func move_text(id: String) -> String:
	return MOVES.get(id, "")

# ---------------------------------------------------------------------------
# travel
# ---------------------------------------------------------------------------
## [to, label, extra flags] for each way out of `rid`.
func exits(rid := "") -> Array:
	var r := room(rid)
	return r.c("EXITS", []) if r else []

## True when `from` lists a way out to `to` (open or not).
func _is_exit(from: String, to: String) -> bool:
	for e in exits(from):
		if e[0] == to:
			return true
	return false

## True when the exit from `from` to `to` is unlocked right now (ignores exit_block).
func exit_open(from: String, to: String) -> bool:
	if not rooms.has(to):
		return false
	for e in exits(from):
		if e[0] == to:
			for f in e[2]:
				if not flag(f):
					return false
			return rooms[to].can_enter()
	return false

## Rooms reachable from `from` through unlocked exits.
func reachable(from := "") -> Array:
	if from == "":
		from = state.room
	var seen_rooms := [from]
	var queue := [from]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for e in exits(cur):
			if not e[0] in seen_rooms and exit_open(cur, e[0]):
				seen_rooms.append(e[0])
				queue.append(e[0])
	return seen_rooms

func _travel(to: String, ev: Array, fast := false) -> void:
	var from: String = state.room
	if to == from or not rooms.has(to):
		return
	if not fast and not _is_exit(from, to):
		return   # not a way out of this room at all: nothing to say, nowhere to go
	var block := room().exit_block(to)
	if block != "":
		ev.append({"type": "say", "text": block, "delay": 0.0, "story": false})
		return
	var ok: bool = exit_open(from, to) if not fast else (to in reachable(from) and to in state.visited)
	if not ok:
		ev.append({"type": "say", "text": rooms[to].locked_line(), "delay": 0.0, "story": false})
		return
	_enter(to, ev)

func _enter(to: String, ev: Array) -> void:
	var from: String = state.room
	room().local_view = "room"
	selected_item = ""
	state.room = to
	var first: bool = not to in state.visited
	if first:
		state.visited.append(to)
	ev.append({"type": "fx", "id": "travel", "from": from, "to": to})
	room().local_view = "room"
	room().arrive(ev, first)

# ---------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------
func dispatch(action: String) -> Array:
	var spent := _spent_snapshot()
	var ev := _dispatch(action)
	_file_spent(spent, ev)
	# The single exit point: a say with no text never reaches a view.
	return ev.filter(func(e): return e.type != "say" or str(e.get("text", "")) != "")

func _dispatch(action: String) -> Array:
	var ev: Array = []
	if view == "title":
		match action:
			"begin":
				_begin(ev)
			"menu":
				return_view = "title"
				view = "menu"
		return ev
	if view == "end":
		match action:
			"new_game":
				reset()
			"return_decision":
				_return_to_decision(ev)
		return ev
	# Settings reached from the title: nothing in the story is reachable from here.
	if view == "menu" and return_view == "title" and not action in [
			"resume", "back", "toggle_motion", "toggle_soft", "restart"]:
		return ev

	match action:
		"notebook":
			if view != "notebook":
				return_view = view if view != "menu" else return_view
				view = "notebook"
				nb_tab = ""
				ev.append({"type": "sfx", "id": "page", "delay": 0.0})
		"menu":
			if view != "menu":
				return_view = view if view != "notebook" else return_view
				view = "menu"
		"hint":
			_hint(ev)
		"back":
			_back(ev)
		"resume":
			if view == "menu":
				view = return_view
		"toggle_motion":
			settings.motion = not settings.motion
		"toggle_soft":
			settings.soft_audio = not settings.soft_audio
		"restart":
			reset()
		_:
			if action.begins_with("tab:") and view == "notebook":
				nb_tab = action.substr(4)
			elif action.begins_with("plan:") and view == "notebook" and flag("P05"):
				var to := action.substr(5)
				if to != state.room and rooms.has(to):
					var before: String = state.room
					# The plan travels from a close-up too: put the close-up down first.
					var tries := 0
					while room().local_view != "room" and tries < 4:
						room().back(ev)
						tries += 1
					if room().local_view == "room":
						_travel(to, ev, true)
					else:
						ev.append({"type": "say", "text": "Not from here.", "delay": 0.0, "story": false})
					if state.room != before:
						view = "room"
			elif view != "room":
				pass
			elif action.begins_with("item:"):
				var item := action.substr(5)
				if has_item(item):
					selected_item = "" if selected_item == item else item
			elif action.begins_with("go:"):
				# An item in hand on an exit tab: the room may take it (a key on its door);
				# otherwise she puts it away and goes.
				var handled := false
				if selected_item != "":
					var held := selected_item
					selected_item = ""
					handled = room().use_item(held, action, ev)
				# Exits leave from any base view (R09's rail, R10's catalogue wall), never a close-up.
				if not handled and not room().is_closeup():
					_travel(action.substr(3), ev)
			elif selected_item != "":
				var item := selected_item
				selected_item = ""
				if not room().use_item(item, action, ev):
					ev.append({"type": "say", "text": GENERIC_WRONG_USE, "delay": 0.0, "story": false})
			else:
				room().act(action, ev)
	return ev

func _begin(ev: Array) -> void:
	state.started = true
	view = "room"
	var first: bool = not state.room in state.visited
	if first:
		state.visited.append(state.room)
	room().local_view = "room"
	room().arrive(ev, first)

func _back(ev: Array) -> void:
	match view:
		"notebook", "menu":
			var from := view
			view = return_view
			if view == "room":
				room().on_core_return(from, ev)
		"room":
			selected_item = ""
			room().back(ev)

func _hint(ev: Array) -> void:
	if view != "room" and not (view in ["notebook", "menu"] and return_view == "room"):
		return
	var r := room()
	if r.hint_frozen():
		ev.append({"type": "say", "text": r.hint_line(0), "delay": 0.0, "story": false})
		return
	if build_end():
		ev.append({"type": "say", "text": BUILD_END_HINT, "delay": 0.0, "story": false})
		return
	var away := work_elsewhere()
	var key: String = state.room + (":" + r.objective() if away == "" else ":->" + away)
	if state.hint["for"] != key:
		state.hint["for"] = key
		state.hint["level"] = 0
	# The ladder as said, press by press: the room's own tiers (hint_tiers(), 3 or 4) or the
	# way there and that room's ladder, with a confirmation before the last tier. `level`
	# indexes this sequence and stops on the last line.
	var seq: Array = []
	if away == "":
		for i in maxi(1, r.hint_tiers()):
			seq.append(r.hint_line(i))
	else:
		seq = _elsewhere_ladder(away)
	seq = with_confirmation(seq)
	var level := clampi(int(state.hint["level"]), 0, seq.size() - 1)
	ev.append({"type": "say", "text": seq[level], "delay": 0.0, "story": false})
	state.hint["level"] = mini(level + 1, seq.size() - 1)

## Said before the last tier of any ladder: only the next Hint gives the answer away.
const HINT_CONFIRM := "Do you want me to just say it? Hint again."
## The highest saved step: three tiers, the confirmation and a fourth tier (index 4). A
## longer ladder (a way-there step before four tiers) stops on its confirmation after a load.
const HINT_LEVEL_MAX := 4

## `ladder` with HINT_CONFIRM before its last line, when that line says something new.
static func with_confirmation(ladder: Array) -> Array:
	var out := ladder.duplicate()
	if out.size() >= 2 and _hint_key(out[-1]) != _hint_key(out[-2]):
		out.insert(out.size() - 1, HINT_CONFIRM)
	return out

## The Hint's ladder toward room `away`, then that room's own ladder. For a room she hasn't
## been in, a where-step first: "The <room> is through the <neighbour>." when a room that
## leads there is one she knows, else its WAY_IN_HINT. For a room she has been in, no
## where-step (the Now: line already names it) and none of its own "Something in the ...
## has changed." tiers. No line is said twice.
func _elsewhere_ladder(away: String) -> Array:
	var there := room(away)
	var title := str(there.c("TITLE", away)).to_lower()
	var steps := []
	var visited: bool = away in state.visited
	if not visited:
		var first: String = there.c("WAY_IN_HINT", "The way into the %s is open now." % title)
		for rid in order:
			if rid != away and rid in state.visited and _is_exit(rid, away):
				first = "The %s is through the %s." % [title, str(rooms[rid].c("TITLE", rid)).to_lower()]
				break
		steps.append(first)
	for level in maxi(1, there.hint_tiers()):
		var line := there.hint_line(level)
		if not (visited and _changed_line(line)):
			steps.append(line)
	var ladder := []
	for line in steps:
		if line == "" or line == NOTHING_HERE:
			continue
		var dup := false
		for l in ladder:
			dup = dup or _hint_key(l) == _hint_key(line)
		if not dup:
			ladder.append(line)
	if ladder.is_empty():
		ladder.append(there.objective_text() if there.objective_text() != "" else NOTHING_HERE)
	return ladder

## A "Something in the <room> has changed." line (the where-step of a ladder).
static func _changed_line(line: String) -> bool:
	var l := line.to_lower()
	return l.begins_with("something in the ") and l.ends_with(" has changed.")

## Two hint lines carry the same information when they match ignoring case and punctuation.
static func _hint_key(line: String) -> String:
	var out := ""
	for ch in line.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out

## Objective ids that mean "nothing to do here": never offered as the work elsewhere.
const IDLE_OBJECTIVES := ["away", "done", "wait"]
## A room's opening survey (skeleton rooms): offered elsewhere only when nothing better is.
const SURVEY_OBJECTIVE := "explore"
const NOTHING_HERE := "Nothing here needs me yet."
## The end of what is built: "Now:" and the Hint when the only work left is in a room that
## is not built yet.
const BUILD_END_NOW := "The station ends here, for now. The rest is not yet built."
const BUILD_END_HINT := "This is as far as the station goes, for now."

## True for a room that is not built yet: its sim declares SKELETON := true (the R09-R12
## skeletons until their teams land). Its exits are marked and it is never offered as work.
func is_unbuilt(rid: String) -> bool:
	return rooms.has(rid) and bool(rooms[rid].c("SKELETON", false))

## The build ends here: nothing built has work for her (here or anywhere reachable), and an
## unbuilt room she can reach is where the story goes on.
func build_end() -> bool:
	var r := room()
	if r == null or tide_done(9):
		return false
	if not is_unbuilt(state.room) and _room_has_work(r) and not _idle(r.objective()):
		return false
	if elsewhere(true) != "":
		return false
	for rid in reachable():
		if is_unbuilt(rid) and room_open(rid):
			return true
	return false

## True when `r` shows a goal of its own and has a hint ladder for it.
func _room_has_work(r: RoomSim) -> bool:
	var o := r.objective()
	if o == "" or r.objective_text() == "":
		return false
	var ladder: Array = r.c("HINTS", {}).get(o, [])
	if not ladder.is_empty():
		return true
	return not r.hint_line(0) in ["", NOTHING_HERE]

static func _idle(objective_id: String) -> bool:
	for pre in IDLE_OBJECTIVES:
		if objective_id.begins_with(pre):
			return true
	return false

## Where the notebook and the Hint point instead of the current room, or "" to stay here:
## a room with nothing to do (no objective, or no ladder for it) points at any room with
## work, its opening survey included; an idle one ("away", "done", "wait...") only at real
## work elsewhere, else it keeps its own line.
func work_elsewhere() -> String:
	var r := room()
	if r == null:
		return ""
	if not _room_has_work(r) or is_unbuilt(state.room):
		return elsewhere(true)
	if _idle(r.objective()):
		var e := elsewhere(false)
		if e == "" and r.objective_text() == NOTHING_HERE:
			e = elsewhere(true)
		return e
	return ""

## The open, reachable room (not this one) where the work is: the office (the hub) first,
## then the rooms in order; a room's opening survey only if `survey` and nothing else is
## waiting. "" if there is nowhere.
func elsewhere(survey := true) -> String:
	var reach := reachable()
	# First: a room whose goal is a puzzle that is open now and not yet solved, in room order.
	for rid in order:
		if rid == state.room or not rid in reach or not room_open(rid) or is_unbuilt(rid):
			continue
		var r: RoomSim = rooms[rid]
		var o := r.objective()
		if o == "" or _idle(o) or r.objective_text() == "":
			continue
		if puzzle_open(objective_puzzle(rid)):
			return rid
	var ids: Array = [start_room]
	for rid in order:
		if not rid in ids:
			ids.append(rid)
	for pass_n in (2 if survey else 1):
		for rid in ids:
			if rid == state.room or not rid in reach or not room_open(rid) or is_unbuilt(rid):
				continue
			var r: RoomSim = rooms[rid]
			var o := r.objective()
			if o == "" or r.objective_text() == "":
				continue
			if _idle(o) or (pass_n == 0 and o.begins_with(SURVEY_OBJECTIVE)):
				continue
			return rid
	return ""

## The puzzle (P01..P27) room `rid`'s current objective works toward, or "": the room's
## own RoomSim.objective_puzzle() if it names one, else its id's "pNN" prefix, else
## OBJECTIVE_PUZZLES.
func objective_puzzle(rid: String) -> String:
	var r := room(rid)
	if r == null:
		return ""
	var own := r.objective_puzzle()
	if own != "":
		return own
	var o := r.objective()
	if o.length() >= 3 and o.begins_with("p") and o.substr(1, 2).is_valid_int() \
			and (o.length() == 3 or o[3] == "_"):
		return "P" + o.substr(1, 2)
	return OBJECTIVE_PUZZLES.get(rid, {}).get(o, "")

## True when puzzle `pid` is open (every prerequisite set) and not yet solved.
func puzzle_open(pid: String) -> bool:
	if not PUZZLE_REQUIRES.has(pid) or flag(pid):
		return false
	for f in PUZZLE_REQUIRES[pid]:
		if not flag(f):
			return false
	return true

## The notebook's "Now:" line. Never empty: when this room has nothing to do it names the
## room that has ("<TITLE>: <its objective>").
func objective_text() -> String:
	var r := room()
	if r == null:
		return ""
	if build_end():
		return BUILD_END_NOW
	var away := work_elsewhere()
	if away == "":
		var own := r.objective_text()
		return own if own != "" else NOTHING_HERE
	return "%s: %s" % [room(away).c("TITLE", away), room(away).objective_text()]

## The end card for `ending` ("sever" or "continue"): sets ending_choice. Called by R12.
func finish(ending: String) -> void:
	if not ENDINGS.has(ending):
		return
	state.ending = ending
	if not ending in settings.endings_seen:
		settings.endings_seen.append(ending)
	view = "end"

## Replay: back to the P26-complete decision with both endings available. The chamber
## room calls save_checkpoint() when P26 is solved; the game scene keeps it on disk.
var checkpoint := {}

func save_checkpoint() -> void:
	checkpoint = to_dict()

func _return_to_decision(ev: Array) -> void:
	if checkpoint.is_empty():
		return
	if from_dict(checkpoint):
		ev.append({"type": "fx", "id": "travel", "from": "", "to": state.room})

# ---------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------
func to_dict() -> Dictionary:
	var d: Dictionary = state.duplicate(true)
	for rid in order:
		d.rooms[rid] = rooms[rid].state.duplicate(true)
	return d

func settings_dict() -> Dictionary:
	return settings.duplicate(true)

func load_settings(d: Variant) -> void:
	if d is Dictionary:
		for k in ["motion", "soft_audio"]:
			if d.get(k) is bool:
				settings[k] = d[k]
		if d.get("endings_seen") is Array:
			for e in d.endings_seen:
				if e is String and ENDINGS.has(e) and not e in settings.endings_seen:
					settings.endings_seen.append(e)

## Restores a save (full game, or a slice save that migrates). Ignores anything malformed.
## Returns true if loaded.
func from_dict(d: Variant) -> bool:
	if not d is Dictionary:
		return false
	if int(d.get("schema", 0)) == SLICE_SCHEMA and not d.get("rooms") is Dictionary:
		var m := migrate_slice(d)
		load_settings(m.settings)
		d = m.progress
	if int(d.get("schema", 0)) != SCHEMA or not d.get("rooms") is Dictionary:
		return false
	reset()
	state.started = d.get("started") is bool and d.started
	var saved_room = d.get("room")
	state.room = saved_room if saved_room is String and rooms.has(saved_room) else start_room
	if d.get("flags") is Dictionary:
		for k in d.flags:
			if k is String and d.flags[k] is bool and d.flags[k] and _valid_flag(k):
				state.flags[k] = true
	var defs := item_defs()
	if d.get("retired") is Array:
		for it in d.retired:
			if it is String and ITEM_RETIRES_AFTER.has(it) and not it in state.retired:
				state.retired.append(it)
	if d.get("inventory") is Array:
		for it in d.inventory:
			if it is String and defs.has(it) and not it in state.inventory and not it in state.retired:
				state.inventory.append(it)
	if d.get("visited") is Array:
		for v in d.visited:
			if v is String and rooms.has(v) and not v in state.visited:
				state.visited.append(v)
	if d.get("movement_events") is Array:
		for t in d.movement_events:
			if t is String and MOVES.has(t):
				record_move(t)
	if d.get("p05_trace") is Array and d.p05_trace.size() <= P05_TRACE_LEN:
		var ok := true
		for t in d.p05_trace:
			ok = ok and t is String and MOVES.has(t)
		if ok:
			state.p05_trace = d.p05_trace.duplicate()
	if d.get("hint") is Dictionary and d.hint.get("for") is String and RoomSim._all_whole([d.hint.get("level")]):
		state.hint = {"for": d.hint["for"], "level": clampi(int(d.hint.level), 0, HINT_LEVEL_MAX)}
	for rid in order:
		var r: RoomSim = rooms[rid]
		r.load_state(d.rooms.get(rid))
		r.local_view = "room"
		state.rooms[rid] = r.state
	if d.get("notebook") is Array:
		for k in d.notebook:
			if k is String and _valid_observation(k) and not k in state.notebook:
				state.notebook.append(k)
	for rid in order:
		rooms[rid].reconcile()
	# A save can't leave her behind a gate she hasn't opened (a stale or tampered room).
	if state.room != start_room and not room().can_enter():
		state.room = start_room
	if not state.started:
		state.visited.clear()
	elif not state.room in state.visited:
		state.visited.append(state.room)
	view = "room" if state.started else "title"
	# Only the room she stands in may resume a view of its own; every other room is at "room".
	if state.started:
		var rv := room().resume_view()
		room().local_view = rv if rv != "" else "room"
	var ending = d.get("ending")
	if state.started and ending is String and ENDINGS.has(ending) and tide_done(8):
		state.ending = ending
		view = "end"
	return true

func _valid_flag(k: String) -> bool:
	if k in GLOBAL_FLAGS:
		return true
	if k.length() == 3 and k.begins_with("P") and k.substr(1).is_valid_int():
		var n := int(k.substr(1))
		return n >= 1 and n <= 27
	var dot := k.find(".")
	return dot > 0 and rooms.has(k.substr(0, dot))

func _valid_observation(k: String) -> bool:
	var dot := k.find(".")
	if dot <= 0 or not rooms.has(k.substr(0, dot)):
		return false
	return rooms[k.substr(0, dot)].c("OBSERVATIONS", {}).has(k.substr(dot + 1))

## The Intake Office slice save (flat, schema 5) as {progress, settings} in the full-game
## format. Validation happens in from_dict and R02's load_state, as for any save.
static func migrate_slice(d: Dictionary) -> Dictionary:
	var local := d.duplicate(true)
	for k in ["schema", "seen", "motion", "soft_audio", "hint_level", "hint_for", "started"]:
		local.erase(k)
	var notebook := []
	if d.get("seen") is Array:
		for s in d.seen:
			if s is String:
				notebook.append("R02." + s)
	var started: bool = d.get("started") is bool and d.started
	var flags := {}
	if d.get("p01_complete") is bool and d.p01_complete:
		flags["P01"] = true
	return {
		"progress": {
			"schema": SCHEMA, "started": started, "room": "R02", "visited": ["R02"] if started else [],
			"flags": flags, "inventory": [], "notebook": notebook, "movement_events": [], "p05_trace": [],
			"hint": {"for": "", "level": 0}, "rooms": {"R02": local}, "ending": "", "retired": [],
		},
		"settings": {"motion": d.get("motion", true), "soft_audio": d.get("soft_audio", false)},
	}

# ---------------------------------------------------------------------------
# dev
# ---------------------------------------------------------------------------
## Dev: the state real play would have at the start of tide `t` (1..9): every puzzle of
## every earlier tide solved, each room's local state prepared to match. Lands in `rid`.
func debug_tide(t: int, rid := "") -> void:
	reset()
	state.started = true
	t = clampi(t, 1, 9)
	for n in range(1, t):
		for p in tide_puzzles(n):
			set_flag(p)
	if t >= 2:
		# The Tide I transition is behind her too (R02's reconcile confirms it from its state).
		set_flag("closure_report_filed")
		set_flag("t1x_threshold_crossed")
	for r in order:
		rooms[r].debug_prepare(t)
	for r in order:
		rooms[r].reconcile()
	for r in reachable(start_room):
		if not r in state.visited:
			state.visited.append(r)
	debug_enter(rid if rid != "" else start_room)

## Dev: go straight to a room, ignoring gates. Marks it visited without the arrival beat.
func debug_enter(rid: String) -> void:
	if not rooms.has(rid):
		return
	state.started = true
	state.room = rid
	if not rid in state.visited:
		state.visited.append(rid)
	view = "room"
	room().local_view = "room"
