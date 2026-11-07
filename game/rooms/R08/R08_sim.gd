class_name R08Sim
extends RoomSim
## R08, the Machine Room: skeleton. Owns P11 (docs/design/game-design.md). The room team
## fills this file: state, actions, events and puzzle logic, following
## docs/dev/room-contract.md. Until then every hotspot says one line and notes it.

const ID := "R08"
const TITLE := "Machine Room"
const REQUIRES := ["P09"]
const LOCKED := "The machine room is behind the kitchen's service access. It's sealed."
const RESUME := "Back in the machine room."
const ARRIVAL := "The machine room. A black diaphragm draws in against its restraining bolts."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R05", "Kitchen", []],
	["R07", "Laboratory", []],
]
const HOTSPOTS := ["diaphragm", "toggles", "drawing", "pump", "belts", "repairs"]
const LOOKS := {
	"diaphragm": "An enormous black diaphragm, bolted at the rim. It draws in. It lets go.",
	"toggles": "Four labelled toggles: SUPPLY, GATE, RETURN, INDEX.",
	"drawing": "A clean pipe diagram: a loop through gate and return, with Index isolated.",
	"pump": "The pump's engage lever, cold.",
	"belts": "Drive belts running over greased pulleys.",
	"repairs": "Repair tags, dated across four years, all in one hand.",
}
const OBSERVATIONS := {
	"diaphragm": "An enormous black diaphragm, bolted at the rim. It draws in. It lets go.",
	"toggles": "Four labelled toggles: SUPPLY, GATE, RETURN, INDEX.",
	"drawing": "A clean pipe diagram: a loop through gate and return, with Index isolated.",
	"pump": "The pump's engage lever, cold.",
	"belts": "Drive belts running over greased pulleys.",
	"repairs": "Repair tags, dated across four years, all in one hand.",
}
const OBJECTIVES := {
	"explore": "Look around the machine room.",
}
const HINTS := {
	"explore": [
		"Everything in this room can be looked at.",
		"Each thing I look at goes into the notebook.",
		"Look at each object in the room.",
	],
}
const ITEMS := {}

func initial_state() -> Dictionary:
	return {}

func objective() -> String:
	return "explore"
