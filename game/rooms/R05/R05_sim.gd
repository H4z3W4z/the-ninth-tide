class_name R05Sim
extends RoomSim
## R05, the Kitchen and Mess: skeleton. Owns P07, P09 (docs/design/game-design.md). The room team
## fills this file: state, actions, events and puzzle logic, following
## docs/dev/room-contract.md. Until then every hotspot says one line and notes it.

const ID := "R05"
const TITLE := "Kitchen and Mess"
const REQUIRES := ["P06"]
const LOCKED := "The service door is locked. A tag on it: KITCHEN · BUNKS. The key went out with the launch."
const RESUME := "Back in the kitchen and mess."
const ARRIVAL := "The mess. Eight places laid. Nine spoon marks pressed into the cloth."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R02", "Office", []],
	["R07", "Laboratory", []],
	["R08", "Machine room", []],
]
const HOTSPOTS := ["table", "bowls", "ledger", "cup", "board", "drawer"]
const LOOKS := {
	"table": "Eight place settings. Nine spoon marks in the cloth. A square mark at the ninth place.",
	"bowls": "Eight bowls with initials. One unsigned, with a square repair patch.",
	"ledger": "\"Nine portions. Eight signatures. I feed the people who sit down.\"",
	"cup": "A cup with a mended handle, a folded towel beside it.",
	"board": "The shift board. An official eight, in Rook's hand.",
	"drawer": "A service drawer, latched from inside the table.",
}
const OBSERVATIONS := {
	"table": "Eight place settings. Nine spoon marks in the cloth. A square mark at the ninth place.",
	"bowls": "Eight bowls with initials. One unsigned, with a square repair patch.",
	"ledger": "\"Nine portions. Eight signatures. I feed the people who sit down.\"",
	"cup": "A cup with a mended handle, a folded towel beside it.",
	"board": "The shift board. An official eight, in Rook's hand.",
	"drawer": "A service drawer, latched from inside the table.",
}
const OBJECTIVES := {
	"explore": "Look around the kitchen and mess.",
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
