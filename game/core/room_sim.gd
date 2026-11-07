class_name RoomSim
extends RefCounted
## Base for every room's deterministic sim (game/rooms/<rid>/<rid>_sim.gd).
##
## No nodes, no clocks, no randomness. The GameSim owns global state (tide, flags,
## inventory, notebook, current room, settings) and calls into the current room for
## room actions. A room mutates only its own `state` dict (which is the same Dictionary
## as game.state.rooms[ID], so it saves with the game) and global state through the
## GameSim API: game.flag(), game.set_flag(), game.solve(), game.give(), game.take(),
## game.observe(), game.record_move(), game.value().
##
## Every room script declares constants the core reads (see docs/dev/room-contract.md):
##   ID            "R03"
##   TITLE         "Chart Room"
##   REQUIRES      flags needed to enter at all, e.g. ["P01"]
##   LOCKED        what Ada says at a locked way in (override locked_line() for more)
##   EXITS         [[to_rid, label, extra_flags], ...] the ways out of this room
##   ARRIVAL       one line on first arrival
##   HOTSPOTS      room hotspot ids in the order they are hit-tested (view owns rects)
##   OBSERVATIONS  {id: notebook text}
##   HINTS         {objective_id: [nudge, relationship, solution]}
##   OBJECTIVES    {objective_id: one-line goal for the notebook}
##   ITEMS         {item_id: {"name": ..., "desc": ...}} items this room can hand out

var game: GameSim
var state := {}
## Where the room is looking: "room", or a room-local close-up id. Never saved: a load
## lands in resume_view() ("room" unless the room overrides it).
var local_view := "room"

## The combined view, for tests and drivers: the room's own view while the game shows the
## room, otherwise the game's (title, notebook, menu, end).
var view: String:
	get:
		if game == null or game.view == "room":
			return local_view
		return game.view
	set(v):
		local_view = v

var return_view: String:
	get:
		return game.return_view if game else "room"

## Reads a script constant declared by the room (subclass), with a default.
func c(name: String, default: Variant = null) -> Variant:
	var m: Dictionary = get_script().get_script_constant_map()
	return m.get(name, default)

func id() -> String:
	return c("ID", "")

# ---------------------------------------------------------------------------
# virtuals a room overrides
# ---------------------------------------------------------------------------
## The room's fresh local state. Must be JSON-safe (bools, ints, strings, arrays, dicts).
func initial_state() -> Dictionary:
	return {}

## Restores local state from a saved dict, ignoring anything malformed. The default keeps
## keys present in initial_state() whose saved value has the same JSON type.
func load_state(d: Variant) -> void:
	state = initial_state()
	if not d is Dictionary:
		return
	for k in state:
		if d.has(k) and _same_json_type(state[k], d[k]):
			state[k] = d[k]

## After a load or debug jump: make global flags and local state agree (a room that owns a
## puzzle flag sets or clears it here from its own state).
func reconcile() -> void:
	pass

## The ways in. Default: every flag in REQUIRES.
func can_enter() -> bool:
	for f in c("REQUIRES", []):
		if not game.flag(f):
			return false
	return true

func locked_line() -> String:
	return c("LOCKED", "It won't open.")

## Called on entering the room (`first` = never visited before). Say the arrival line here.
func arrive(ev: Array, first: bool) -> void:
	if first:
		_say(ev, c("ARRIVAL", ""))

## A reason she won't leave by `to` right now, or "" to let her go.
func exit_block(_to: String) -> String:
	return ""

## A room action (a hotspot or close-up control id). Default: hotspots say a line and
## record the observation of the same id, if any.
func act(action: String, ev: Array) -> void:
	if local_view == "room" and action in c("HOTSPOTS", []):
		var lines: Dictionary = c("LOOKS", {})
		if lines.has(action):
			_say(ev, lines[action])
		if c("OBSERVATIONS", {}).has(action):
			_observe(action)

## The selected inventory item used on `target`. Return true if the room handled it;
## false lets the core say the generic refusal.
func use_item(_item: String, _target: String, _ev: Array) -> bool:
	return false

## Back from a close-up. Default: to the room.
func back(_ev: Array) -> void:
	local_view = "room"

## The game view came back to the room from a core view ("notebook" or "menu").
func on_core_return(_from: String, _ev: Array) -> void:
	pass

## The local view a load lands in; default room. Called on the current room only, after
## load_state() and reconcile(), so it may read its restored state (R12 resumes its ending).
func resume_view() -> String:
	return "room"

func is_closeup(v := local_view) -> bool:
	return v != "room"

## The current objective id (a key of OBJECTIVES and HINTS), or "" for none.
func objective() -> String:
	return ""

## The puzzle id ("P07") the current objective works toward, or "" (the core then reads a
## "pNN" objective id, or its own table). Optional: "Now:" uses it to point at open puzzles.
func objective_puzzle() -> String:
	return ""

func objective_text() -> String:
	return c("OBJECTIVES", {}).get(objective(), "")

## The hint for the current objective at `level` (0..2). Override for special cases.
func hint_line(level: int) -> String:
	var ladder: Array = c("HINTS", {}).get(objective(), [])
	if ladder.is_empty():
		return "Nothing here needs me yet."
	return ladder[mini(level, ladder.size() - 1)]

## True when the hint ladder should not advance (e.g. a scripted moment with one action).
func hint_frozen() -> bool:
	return false

## A line written in the notebook that she did not write, or "".
func notebook_intrusion() -> String:
	return ""

## Dev: put local state where it would be after reaching tide `t` by real play.
func debug_prepare(_t: int) -> void:
	pass

# ---------------------------------------------------------------------------
# helpers for rooms
# ---------------------------------------------------------------------------
func has_seen(obs: String) -> bool:
	return game.has_seen(id(), obs)

## This room's observations in the order she made them.
func seen() -> Array:
	return game.seen_in(id())

func _observe(obs: String) -> void:
	game.observe(id(), obs)

func _say(ev: Array, text: String, delay := 0.0, story := false) -> void:
	if text != "":
		ev.append({"type": "say", "text": text, "delay": delay, "story": story})

func _sfx(ev: Array, sid: String, delay := 0.0) -> void:
	ev.append({"type": "sfx", "id": sid, "delay": delay})

## A view effect. `extra` adds fields to the event (JSON-safe values), e.g. the glance:
## _fx(ev, "glance", {"rect": [x, y, w, h], "target": "drawer"}). "type" and "id" stay the
## event's own; an extra "id" (the thing the fx is about) is carried as "target".
func _fx(ev: Array, fid: String, extra := {}) -> void:
	var e := {"type": "fx", "id": fid}
	for k in extra:
		if k == "id":
			if not extra.has("target"):
				e["target"] = extra[k]
		elif k != "type":
			e[k] = extra[k]
	ev.append(e)

# Test and driver conveniences: the whole game, through this room.
func dispatch(action: String) -> Array:
	return game.dispatch(action)

func to_dict() -> Dictionary:
	return game.to_dict()

func from_dict(d: Variant) -> bool:
	return game.from_dict(d)

static func _same_json_type(a: Variant, b: Variant) -> bool:
	if a is bool or b is bool:
		return a is bool and b is bool
	if (a is int or a is float) and (b is int or b is float):
		return true
	return typeof(a) == typeof(b)

## JSON numbers come back as floats; accept only whole numbers.
static func _all_whole(values: Array) -> bool:
	for v in values:
		if not (v is int or v is float) or float(v) != floorf(float(v)):
			return false
	return true
