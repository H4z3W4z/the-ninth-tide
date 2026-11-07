extends "res://tests/rooms/room_test_base.gd"
## R07, the Wet Laboratory: skeleton checks (registration, gates, hotspots, exits, view).
## The room team adds its puzzle tests here: see docs/dev/room-contract.md.
##   godot --headless --path . --script tests/rooms/R07_test.gd

const ROOM := "R07"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P09"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 4

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	await view_checks(ROOM)
