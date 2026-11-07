extends RoomSim
## Fixture room for tests/core_test.gd: proves a room is discovered from its directory alone,
## and exercises items, puzzle flags, the tide event and local-state saves.

const ID := "Z01"
const TITLE := "Fixture Store"
const REQUIRES := []
const ARRIVAL := "A store room that exists only for the tests."
const EXITS := [["Z02", "Locked room", []]]
const HOTSPOTS := ["shelf", "box", "lever"]
const LOOKS := {"shelf": "A shelf with a key on it.", "lever": "A lever."}
const OBSERVATIONS := {"shelf": "There was a key on the shelf.", "box": "The box took the key."}
const OBJECTIVES := {"key": "Find the key.", "box": "Open the box.", "done": "Done."}
const HINTS := {"key": ["a", "b", "c"], "box": ["d", "e", "f"], "done": ["g", "h", "i"]}
const ITEMS := {"key": {"name": "Brass key", "desc": "A small brass key."}}

func initial_state() -> Dictionary:
	return {"box_open": false, "pulls": 0}

func objective() -> String:
	if state.box_open: return "done"
	return "box" if game.has_item("key") else "key"

func act(action: String, ev: Array) -> void:
	match action:
		"shelf":
			_say(ev, LOOKS.shelf)
			_observe("shelf")
			game.give("key", ev)
		"lever":
			state.pulls = int(state.pulls) + 1
			_say(ev, LOOKS.lever)
		"box":
			_say(ev, "Locked.")

func use_item(item: String, target: String, ev: Array) -> bool:
	if item == "key" and target == "box":
		state.box_open = true
		game.take("key")
		_observe("box")
		game.solve("P01", ev)
		game.solve("P02", ev)
		game.solve("P03", ev)
		game.solve("t1x_threshold_crossed", ev)
		_say(ev, "The box opens.")
		return true
	return false

func reconcile() -> void:
	if not state.box_open:
		for p in ["P01", "P02", "P03", "t1x_threshold_crossed"]:
			game.set_flag(p, false)
