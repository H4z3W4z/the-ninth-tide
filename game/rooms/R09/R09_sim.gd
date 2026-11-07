class_name R09Sim
extends RoomSim
## R09, the Lantern Gallery: skeleton. Owns P15 (docs/design/game-design.md). The room team
## fills this file: state, actions, events and puzzle logic, following
## docs/dev/room-contract.md. Until then every hotspot says one line and notes it.

const ID := "R09"
const TITLE := "Lantern Gallery"
const REQUIRES := ["P12"]
const LOCKED := "The gallery stair goes up from the dry stair's first landing. That way isn't open."
const RESUME := "Back in the lantern gallery."
const ARRIVAL := "The lantern gallery. The rain has stopped touching the rail."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R11", "Stair", []],
]
const HOTSPOTS := ["lens", "apertures", "scope", "rail", "horizon"]
const LOOKS := {
	"lens": "The signal lens, cold and enormous.",
	"apertures": "Three apertures with bearings: LAND 1, SEA 2, STATION 3.",
	"scope": "A sighting scope on a brass arm.",
	"rail": "The rail is dry. The rain is falling a hand's width away from it.",
	"horizon": "A conventional horizon. For now.",
}
const OBSERVATIONS := {
	"lens": "The signal lens, cold and enormous.",
	"apertures": "Three apertures with bearings: LAND 1, SEA 2, STATION 3.",
	"scope": "A sighting scope on a brass arm.",
	"rail": "The rail is dry. The rain is falling a hand's width away from it.",
	"horizon": "A conventional horizon. For now.",
}
const OBJECTIVES := {
	"explore": "Look around the lantern gallery.",
}
const HINTS := {
	"explore": [
		"Everything in this room can be looked at.",
		"Each thing I look at goes into the notebook.",
		"Look at each object in the room.",
	],
}
## Items this room hands out (docs/design/puzzle-cards/flags.md section 4).
const ITEMS := {
	"nora_spatial_strip": {"name": "Bearing strip: N. Bell", "desc": "A bearing strip recorded through the gallery scope."},
}

func initial_state() -> Dictionary:
	return {}

func objective() -> String:
	return "explore"
