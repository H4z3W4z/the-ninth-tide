extends "res://tests/rooms/room_test_base.gd"
## R03, the Chart Room: skeleton checks (registration, gates, hotspots, exits, view).
## The room team adds its puzzle tests here: see docs/dev/room-contract.md.
##   godot --headless --path . --script tests/rooms/R03_test.gd

const ROOM := "R03"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P01", "R02.threshold"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 2

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	await view_checks(ROOM)
