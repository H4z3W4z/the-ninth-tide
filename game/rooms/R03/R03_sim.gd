class_name R03Sim
extends RoomSim
## R03, the Chart Room: skeleton. Owns P03-P05, P21 (docs/design/game-design.md). The room team
## fills this file: state, actions, events and puzzle logic, following
## docs/dev/room-contract.md. Until then every hotspot says one line and notes it.

const ID := "R03"
const TITLE := "Chart Room"
const REQUIRES := ["P01"]
const LOCKED := "The chart room door is latched. Electrically, by the feel of it."
const RESUME := "Back in the chart room."
const ARRIVAL := "The chart room. A tide pen scratches against a drum that isn't turning."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R02", "Office", []],
	["R11", "Observation hatch", []],
	["R04", "Listening room", []],
]
const HOTSPOTS := ["recorder", "sheets", "plate", "hatch", "window", "lever"]
const LOOKS := {
	"recorder": "Bone-coloured paper on a copper drum. The pen is moving. The drum is not.",
	"sheets": "Two tide sheets, same date, each with a lighthouse registration cross and a north arrow.",
	"plate": "A brass plate with two controls: ZERO and INTERVAL, and a worked example in small print.",
	"hatch": "The observation hatch in the floor. Three scratches across its lid.",
	"window": "The sea, ordinary and grey, at the height it should be.",
	"lever": "A polished lever marked CALIBRATE. Polished by a lot of hands.",
}
const OBSERVATIONS := {
	"recorder": "Bone-coloured paper on a copper drum. The pen is moving. The drum is not.",
	"sheets": "Two tide sheets, same date, each with a lighthouse registration cross and a north arrow.",
	"plate": "A brass plate with two controls: ZERO and INTERVAL, and a worked example in small print.",
	"hatch": "The observation hatch in the floor. Three scratches across its lid.",
	"window": "The sea, ordinary and grey, at the height it should be.",
	"lever": "A polished lever marked CALIBRATE. Polished by a lot of hands.",
}
const OBJECTIVES := {
	"explore": "Look around the chart room.",
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
	"chart_clips": {"name": "Chart clips", "desc": "Brass clips from the chart table, for holding sheets in register."},
}

func initial_state() -> Dictionary:
	return {}

func objective() -> String:
	return "explore"

## Before the lamp the instrument doors are latched; after it, she's free to come.
func locked_line() -> String:
	if not game.flag("P01"):
		return LOCKED
	return "The latch has gone. The office isn't finished with me yet."
