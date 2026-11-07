class_name R10Sim
extends RoomSim
## R10, the Records Vault: skeleton. Owns P16, P18, P23 (docs/design/game-design.md). The room team
## fills this file: state, actions, events and puzzle logic, following
## docs/dev/room-contract.md. Until then every hotspot says one line and notes it.

const ID := "R10"
const TITLE := "Records Vault"
const REQUIRES := ["P15"]
const LOCKED := "The vault latch is shut fast. Something in the station has to let it go."
const RESUME := "Back in the records vault."
const ARRIVAL := "The records vault. The shelves go back further than the floor plan does."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R07", "Laboratory", []],
]
const HOTSPOTS := ["shelves", "photos", "contact", "staff", "folders", "tray"]
const LOOKS := {
	"shelves": "Low shelves and hanging index cards, going back and back.",
	"photos": "Photographs of chairs with carefully retouched blank areas in them.",
	"contact": "Four contact-sheet panels with a numbered edge and a wall clock in each.",
	"staff": "A catalogue drawer marked STAFF. It does not open onto a drawer.",
	"folders": "Three folder headings: BODY, PLACE, NAME.",
	"tray": "An empty tray in front of the STAFF drawer.",
}
const OBSERVATIONS := {
	"shelves": "Low shelves and hanging index cards, going back and back.",
	"photos": "Photographs of chairs with carefully retouched blank areas in them.",
	"contact": "Four contact-sheet panels with a numbered edge and a wall clock in each.",
	"staff": "A catalogue drawer marked STAFF. It does not open onto a drawer.",
	"folders": "Three folder headings: BODY, PLACE, NAME.",
	"tray": "An empty tray in front of the STAFF drawer.",
}
const OBJECTIVES := {
	"explore": "Look around the records vault.",
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
	"contact_sheet": {"name": "Contact sheet, 18 Oct 1927", "desc": "A contact sheet from the Index session."},
	"venn_correspondence": {"name": "Venn's correspondence", "desc": "Letters from Venn's drawer in the vault."},
	"witness_bridge": {"name": "Witness bridge", "desc": "A bridge part from the Index model, marked WITNESS."},
}

func initial_state() -> Dictionary:
	return {}

func objective() -> String:
	return "explore"
