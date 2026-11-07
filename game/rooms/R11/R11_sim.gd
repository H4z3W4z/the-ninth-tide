class_name R11Sim
extends RoomSim
## R11, the Dry Stair: skeleton. Owns P12, P24 (docs/design/game-design.md). The room team
## fills this file: state, actions, events and puzzle logic, following
## docs/dev/room-contract.md. Until then every hotspot says one line and notes it.

const ID := "R11"
## Not built yet: the core marks its exit tabs "(not yet built)" and never sends her here
## for work (GameSim.is_unbuilt). The room team deletes this line with its first real act().
const SKELETON := true
const TITLE := "Dry Stair"
const REQUIRES := ["P04"]
const LOCKED := "The observation hatch is shut."
const RESUME := "Back in the dry stair."
const ARRIVAL := "The pressure gate holds at 2. This is as far as the station goes, for now."
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
		"This is as far as the station goes, for now. The way back is behind me.",
		"This is as far as the station goes, for now. The way back is behind me.",
		"This is as far as the station goes, for now. The way back is behind me.",
	],
}
const ITEMS := {}

func initial_state() -> Dictionary:
	return {}

func objective() -> String:
	return "explore"
