extends "res://tests/rooms/room_test_base.gd"
## R09, the Lantern Gallery: skeleton checks (registration, gates, hotspots, exits, view).
## The room team adds its puzzle tests here: see docs/dev/room-contract.md.
##   godot --headless --path . --script tests/rooms/R09_test.gd

const ROOM := "R09"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P12"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 5

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	await view_checks(ROOM)
