extends RoomSim
## Fixture room: opens once tide I is complete.

const ID := "Z02"
const TITLE := "Fixture Hall"
const REQUIRES := ["P03"]
const LOCKED := "Shut."
const ARRIVAL := "The hall."
const EXITS := [["Z01", "Store", []]]
const HOTSPOTS := []
## A four-tier hint ladder (core_test: hint tiers and the confirmation).
const OBJECTIVES := {"hall": "Cross the hall."}
const HINTS := {"hall": ["tier1", "tier2", "tier3", "tier4"]}

func objective() -> String:
	return "hall"
