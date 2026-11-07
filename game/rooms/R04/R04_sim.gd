class_name R04Sim
extends RoomSim
## R04, the Listening Room: skeleton. Owns P02, P17, P19 (docs/design/game-design.md). The room team
## fills this file: state, actions, events and puzzle logic, following
## docs/dev/room-contract.md. Until then every hotspot says one line and notes it.

const ID := "R04"
const TITLE := "Listening Room"
const REQUIRES := ["P01"]
const LOCKED := "The listening room door is latched. Electrically, by the feel of it."
const RESUME := "Back in the listening room."
const ARRIVAL := "The listening room. Ear trumpets point into a sealed plaster wall."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R02", "Office", []],
	["R03", "Chart room", []],
]
const HOTSPOTS := ["funnels", "spindle", "bands", "stool", "board", "dial"]
const LOOKS := {
	"funnels": "Brass funnels. Their pipes go into the plaster and do not come out the other side.",
	"spindle": "A wax-cylinder spindle with a marked START end and three snap positions.",
	"bands": "Three loose recording bands, labelled C, A and B. One has a START notch.",
	"stool": "A stool polished by use. The polish is in the shape of one person.",
	"board": "A channel board: sockets A, B and C, and a key marked WITNESS.",
	"dial": "Three level indicators. One needle trembles with nothing playing.",
}
const OBSERVATIONS := {
	"funnels": "Brass funnels. Their pipes go into the plaster and do not come out the other side.",
	"spindle": "A wax-cylinder spindle with a marked START end and three snap positions.",
	"bands": "Three loose recording bands, labelled C, A and B. One has a START notch.",
	"stool": "A stool polished by use. The polish is in the shape of one person.",
	"board": "A channel board: sockets A, B and C, and a key marked WITNESS.",
	"dial": "Three level indicators. One needle trembles with nothing playing.",
}
const OBJECTIVES := {
	"explore": "Look around the listening room.",
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

## Before the lamp the instrument doors are latched; after it, she's free to come.
func locked_line() -> String:
	if not game.flag("P01"):
		return LOCKED
	return "The latch has gone. The office isn't finished with me yet."
