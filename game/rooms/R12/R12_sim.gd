class_name R12Sim
extends RoomSim
## R12, the Observation Chamber: skeleton. Owns P25-P27 (docs/design/game-design.md). The room team
## fills this file: state, actions, events and puzzle logic, following
## docs/dev/room-contract.md. Until then every hotspot says one line and notes it.

const ID := "R12"
const TITLE := "Observation Chamber"
const REQUIRES := ["P24"]
const LOCKED := "The lower door has three empty frames and a socket, and no handle."
const RESUME := "Back in the observation chamber."
const ARRIVAL := "A chair faces an instrument. There is a space in it where the observer should be."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R11", "Stair", []],
]
const HOTSPOTS := ["chair", "frames", "terminal", "handle", "window", "tray"]
const LOOKS := {
	"chair": "A chair. Every armature of the instrument ends at a part of whoever sits in it.",
	"frames": "Three record frames. One is blank and already labelled: ADA MERCER.",
	"terminal": "A witness terminal. Eight closed indicators and one open.",
	"handle": "A severance handle, its yoke resting beside two labelled feed contacts.",
	"window": "The surface outside is so close it has no edge.",
	"tray": "An equipment tray: a severance yoke.",
}
const OBSERVATIONS := {
	"chair": "A chair. Every armature of the instrument ends at a part of whoever sits in it.",
	"frames": "Three record frames. One is blank and already labelled: ADA MERCER.",
	"terminal": "A witness terminal. Eight closed indicators and one open.",
	"handle": "A severance handle, its yoke resting beside two labelled feed contacts.",
	"window": "The surface outside is so close it has no edge.",
	"tray": "An equipment tray: a severance yoke.",
}
const OBJECTIVES := {
	"explore": "Look around the observation chamber.",
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
