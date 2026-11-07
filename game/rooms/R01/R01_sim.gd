class_name R01Sim
extends RoomSim
## R01, the Jetty: skeleton. Owns P06 (docs/design/game-design.md). The room team
## fills this file: state, actions, events and puzzle logic, following
## docs/dev/room-contract.md. Until then every hotspot says one line and notes it.

const ID := "R01"
const TITLE := "Jetty"
const REQUIRES := []
const LOCKED := ""
const RESUME := "Back in the jetty."
const ARRIVAL := "The jetty. The rope off the mooring bell hangs into the water, and the water shows no rope."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R02", "Office", []],
]
const HOTSPOTS := ["bell", "panel", "line", "lighthouse", "causeway", "gangway"]
const LOOKS := {
	"bell": "The mooring bell hangs too low. Its rope goes into the water without a reflection.",
	"panel": "A mooring panel: pennants paired with numbered stations. Two plates: VERIFIED and UNVERIFIED RETURN.",
	"line": "The line runs straight down into the Sound. Something is tied to it, far below.",
	"lighthouse": "The lighthouse across the Sound. Lit. Nobody is posted there.",
	"causeway": "The old service causeway, broken in three places. Nobody is walking out on that.",
	"gangway": "A gangway, drawn up. Nothing is moored here to board.",
}
const OBSERVATIONS := {
	"bell": "The mooring bell hangs too low. Its rope goes into the water without a reflection.",
	"panel": "A mooring panel: pennants paired with numbered stations. Two plates: VERIFIED and UNVERIFIED RETURN.",
	"line": "The line runs straight down into the Sound. Something is tied to it, far below.",
	"lighthouse": "The lighthouse across the Sound. Lit. Nobody is posted there.",
	"causeway": "The old service causeway, broken in three places. Nobody is walking out on that.",
	"gangway": "A gangway, drawn up. Nothing is moored here to board.",
}
const OBJECTIVES := {
	"explore": "Look around the jetty.",
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
	"service_key": {"name": "Kitchen service key", "desc": "A key from the capsule on the mooring line. It fits the office's service door."},
}

func initial_state() -> Dictionary:
	return {}

func objective() -> String:
	return "explore"
