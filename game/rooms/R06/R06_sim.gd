class_name R06Sim
extends RoomSim
## R06, the Bunk Room: skeleton. Owns P08, P22 (docs/design/game-design.md). The room team
## fills this file: state, actions, events and puzzle logic, following
## docs/dev/room-contract.md. Until then every hotspot says one line and notes it.

const ID := "R06"
const TITLE := "Bunk Room"
const REQUIRES := ["P06"]
const LOCKED := "The service door is locked. A tag on it: KITCHEN · BUNKS. The key went out with the launch."
const RESUME := "Back in the bunk room."
const ARRIVAL := "The bunk room. A hollow settles into an empty mattress, slowly, the way a body would."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R02", "Office", []],
]
const HOTSPOTS := ["lockers", "belongings", "bunks", "calendar", "shelf", "curtain"]
const LOOKS := {
	"lockers": "Labelled lockers. Bell, Rook, Venn, Ives: four stand open and empty.",
	"belongings": "A repaired cup, measuring calipers, a pencil holder, a stitched glove.",
	"bunks": "Narrow beds. One mattress has a hollow in it and nobody on it.",
	"calendar": "The dates don't change. The names written under them do.",
	"shelf": "A little pencil shelf screwed to one bunk, for someone who wrote lying down.",
	"curtain": "A curtain partition, drawn. It moves when I breathe out.",
}
const OBSERVATIONS := {
	"lockers": "Labelled lockers. Bell, Rook, Venn, Ives: four stand open and empty.",
	"belongings": "A repaired cup, measuring calipers, a pencil holder, a stitched glove.",
	"bunks": "Narrow beds. One mattress has a hollow in it and nobody on it.",
	"calendar": "The dates don't change. The names written under them do.",
	"shelf": "A little pencil shelf screwed to one bunk, for someone who wrote lying down.",
	"curtain": "A curtain partition, drawn. It moves when I breathe out.",
}
const OBJECTIVES := {
	"explore": "Look around the bunk room.",
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
