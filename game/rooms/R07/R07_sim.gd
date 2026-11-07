class_name R07Sim
extends RoomSim
## R07, the Wet Laboratory: skeleton. Owns P10, P13, P14 (docs/design/game-design.md). The room team
## fills this file: state, actions, events and puzzle logic, following
## docs/dev/room-contract.md. Until then every hotspot says one line and notes it.

const ID := "R07"
const TITLE := "Wet Laboratory"
const REQUIRES := ["P09"]
const LOCKED := "The laboratory door is behind the kitchen's service access. It's sealed."
const RESUME := "Back in the wet laboratory."
const ARRIVAL := "The wet laboratory. The water stands in the jars at different angles."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R05", "Kitchen", []],
	["R10", "Records vault", []],
	["R11", "Stair door", ["P12"]],
]
const HOTSPOTS := ["jars", "rack", "balance", "tank", "datum", "cards"]
const LOOKS := {
	"jars": "Three sealed jars, A, B and C. The water in each lies at its own angle.",
	"rack": "A test rack that tips a jar through a fixed quarter-turn.",
	"balance": "A balance with an empty control tray.",
	"tank": "A flotation tank. Its surface is not quite level with the room.",
	"datum": "A brass line set into the wall: the station datum.",
	"cards": "Printed cards: every measurement is written down. Nothing here has to be guessed.",
}
const OBSERVATIONS := {
	"jars": "Three sealed jars, A, B and C. The water in each lies at its own angle.",
	"rack": "A test rack that tips a jar through a fixed quarter-turn.",
	"balance": "A balance with an empty control tray.",
	"tank": "A flotation tank. Its surface is not quite level with the room.",
	"datum": "A brass line set into the wall: the station datum.",
	"cards": "Printed cards: every measurement is written down. Nothing here has to be guessed.",
}
const OBJECTIVES := {
	"explore": "Look around the wet laboratory.",
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
