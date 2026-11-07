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
const TRACE_MAX := 12

const TIDE_TITLES := ["The Last Shift", "The Boat at the Window", "Supper for the Absent",
	"The Room Beneath the Water", "A Body of Measurements", "The Other Side of the Glass",
	"The Man Who Left You a Letter", "An Incomplete Person", "The Ninth Tide"]
const NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]

## The two endings (GDD section 9). The chamber room (R12) sets game.state.ending; the
## core shows the end card. Lines are placeholders until R12's team writes the scene.
const ENDINGS := {
	"sever": {"title": "The Unrecorded Shore", "lines": [
		"The instruments fall silent in sequence.",
		"\"I cannot certify their absence.\"",
	]},
	"witness": {"title": "The Last Observer", "lines": [
		"\"Subject Bell possesses no surviving personal effects.\"",
		"\"Nora Bell took her tea without sugar. Begin there.\"",
	]},
}

const GENERIC_WRONG_USE := "That isn't what it's for."

static var _room_scripts := {}   # dir -> {rid: Script}, discovered once per run

var rooms := {}        # rid -> RoomSim
var order: Array = []  # rids, sorted
var state := {}
var settings := {"motion": true, "soft_audio": false}
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
		settings = {"motion": true, "soft_audio": false}
	state = {
		"schema": SCHEMA, "started": false, "room": start_room, "visited": [],
		"flags": {}, "inventory": [], "notebook": [], "trace": [],
		"hint": {"for": "", "level": 0}, "rooms": {}, "ending": "", "endings_seen": [],
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

func flag(name: String) -> bool:
	return bool(state.flags.get(name, false))

func set_flag(name: String, on := true) -> void:
	if on:
		state.flags[name] = true
	else:
		state.flags.erase(name)

func solved(pid: String) -> bool:
	return flag(pid)

## Marks a puzzle solved. Idempotent: a repeated commit never re-rewards or re-advances.
## When the tide advances, a {fx: "tide", tide: n} event follows.
func solve(pid: String, ev: Array) -> void:
	if flag(pid):
		return
	var before := tide()
	set_flag(pid)
	var after := tide()
	if after != before:
		ev.append({"type": "fx", "id": "tide", "tide": after})

## Puzzle ids of tide n (1..9): P(3n-2)..P(3n).
static func tide_puzzles(n: int) -> Array:
	return ["P%02d" % (3 * n - 2), "P%02d" % (3 * n - 1), "P%02d" % (3 * n)]

func tide_complete(n: int) -> bool:
	for p in tide_puzzles(n):
		if not flag(p):
			return false
	return true

func tides_completed() -> int:
	var k := 0
	for n in range(1, 10):
		if tide_complete(n):
			k = n
		else:
			break
	return k

## The current tide, 1..9. Derived from puzzle flags, never a clock.
func tide() -> int:
	return mini(tides_completed() + 1, 9)

## Station-wide weather milestone 0..7 (GDD section 5 table): 0 arrival through Tide I,
## 1 after Tide II ... 7 after Tide VIII; Tide IX holds 7.
func weather() -> int:
	return clampi(tides_completed() - 1, 0, 7)

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

func give(item: String, ev: Array = []) -> void:
	if not has_item(item):
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

## Appends a recognized interaction to Ada's movement trace (P05 / P25 read it).
func record(text: String) -> void:
	state.trace.append(text)
	while state.trace.size() > TRACE_MAX:
		state.trace.pop_front()

# ---------------------------------------------------------------------------
# travel
# ---------------------------------------------------------------------------
## [to, label, extra flags] for each way out of `rid`.
func exits(rid := "") -> Array:
	var r := room(rid)
	return r.c("EXITS", []) if r else []

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
					if room().local_view == "room":
						_travel(to, ev, true)
					if state.room != before:
						view = "room"
			elif view != "room":
				pass
			elif action.begins_with("item:"):
				var item := action.substr(5)
				if has_item(item):
					selected_item = "" if selected_item == item else item
			elif action.begins_with("go:"):
				if room().local_view == "room":
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
	var key: String = state.room + ":" + r.objective()
	if state.hint["for"] != key:
		state.hint["for"] = key
		state.hint["level"] = 0
	var level: int = mini(int(state.hint["level"]), 2)
	ev.append({"type": "say", "text": r.hint_line(level), "delay": 0.0, "story": false})
	state.hint["level"] = level + 1

func objective_text() -> String:
	return room().objective_text() if room() else ""

## The end card for `ending` ("sever" or "witness"). Called by the chamber room.
func finish(ending: String) -> void:
	if not ENDINGS.has(ending):
		return
	state.ending = ending
	if not ending in state.endings_seen:
		state.endings_seen.append(ending)
	view = "end"

## Replay: back to the P26-complete decision with both endings available. The chamber
## room calls save_checkpoint() when P26 is solved; the game scene keeps it on disk.
var checkpoint := {}

func save_checkpoint() -> void:
	checkpoint = to_dict()

func _return_to_decision(ev: Array) -> void:
	if checkpoint.is_empty():
		return
	var seen_endings: Array = state.endings_seen.duplicate()
	if from_dict(checkpoint):
		for e in seen_endings:
			if not e in state.endings_seen:
				state.endings_seen.append(e)
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
	return settings.duplicate()

func load_settings(d: Variant) -> void:
	if d is Dictionary:
		for k in ["motion", "soft_audio"]:
			if d.get(k) is bool:
				settings[k] = d[k]

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
	if d.get("inventory") is Array:
		for it in d.inventory:
			if it is String and defs.has(it) and not it in state.inventory:
				state.inventory.append(it)
	if d.get("visited") is Array:
		for v in d.visited:
			if v is String and rooms.has(v) and not v in state.visited:
				state.visited.append(v)
	if d.get("trace") is Array:
		for t in d.trace:
			if t is String:
				record(t)
	if d.get("hint") is Dictionary and d.hint.get("for") is String and RoomSim._all_whole([d.hint.get("level")]):
		state.hint = {"for": d.hint["for"], "level": clampi(int(d.hint.level), 0, 3)}
	for rid in order:
		var r: RoomSim = rooms[rid]
		r.load_state(d.rooms.get(rid))
		r.local_view = "room"
		state.rooms[rid] = r.state
	if d.get("notebook") is Array:
		for k in d.notebook:
			if k is String and _valid_observation(k) and not k in state.notebook:
				state.notebook.append(k)
	if d.get("endings_seen") is Array:
		for e in d.endings_seen:
			if e is String and ENDINGS.has(e) and not e in state.endings_seen:
				state.endings_seen.append(e)
	for rid in order:
		rooms[rid].reconcile()
	if not state.started:
		state.visited.clear()
	elif not state.room in state.visited:
		state.visited.append(state.room)
	view = "room" if state.started else "title"
	var ending = d.get("ending")
	if state.started and ending is String and ENDINGS.has(ending) and tide_complete(8):
		state.ending = ending
		view = "end"
	return true

func _valid_flag(k: String) -> bool:
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
			"flags": flags, "inventory": [], "notebook": notebook, "trace": [],
			"hint": {"for": "", "level": 0}, "rooms": {"R02": local}, "ending": "", "endings_seen": [],
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
