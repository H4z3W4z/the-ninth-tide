class_name R11Sim
extends RoomSim
## R11, the Dry Stair: skeleton. Owns P12, P24 (docs/design/game-design.md). The room team
## fills this file: state, actions, events and puzzle logic, following
## docs/dev/room-contract.md. Until then every hotspot says one line and notes it.

const ID := "R11"
const TITLE := "Dry Stair"
const REQUIRES := ["P04"]
const LOCKED := "The observation hatch is shut."
const RESUME := "Back in the dry stair."
const ARRIVAL := "There is water on the other side of that wall. There is not room for both."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R03", "Chart room", []],
	["R07", "Laboratory", ["P12"]],
	["R09", "Lantern gallery", []],
	["R12", "Lower door", []],
]
const HOTSPOTS := ["gate", "water", "plates", "steps", "bell"]
const LOOKS := {
	"gate": "A pressure gate across the stair, its gauge at nought.",
	"water": "Water stands across the doorway like glass, and does not spill.",
	"plates": "Landing plates with bracket marks, and a third with no pair.",
	"steps": "Limewashed steps going down through the water, dry.",
	"bell": "A bell sounds up the stair. Its clapper is missing.",
}
const OBSERVATIONS := {
	"gate": "A pressure gate across the stair, its gauge at nought.",
	"water": "Water stands across the doorway like glass, and does not spill.",
	"plates": "Landing plates with bracket marks, and a third with no pair.",
	"steps": "Limewashed steps going down through the water, dry.",
	"bell": "A bell sounds up the stair. Its clapper is missing.",
}
const OBJECTIVES := {
	"explore": "Look around the dry stair.",
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
