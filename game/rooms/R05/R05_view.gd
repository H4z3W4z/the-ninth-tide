extends RoomView
## R05, the Kitchen and Mess: skeleton view. A flat placeholder elevation (RoomView.draw_placeholder)
## with every hotspot as a labelled card. The room team replaces _draw() with the painted
## plates under assets/rooms/R05/, keeping the hotspot rects registered to the art.

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["table", Rect2(96, 250, 328, 260), "Supper table"],
	["bowls", Rect2(560, 250, 328, 260), "Bowls"],
	["ledger", Rect2(1024, 250, 328, 260), "Nora's ledger"],
	["cup", Rect2(96, 580, 328, 260), "Repaired cup"],
	["board", Rect2(560, 580, 328, 260), "Service board"],
	["drawer", Rect2(1024, 580, 328, 260), "Service drawer"],
]
## Where each exit is clicked. The core draws these as tabs on the HUD layer.
const EXIT_RECTS := {
	"R02": Rect2(20, 922, 250, 64),
	"R07": Rect2(282, 922, 250, 64),
	"R08": Rect2(544, 922, 250, 64),
	"R06": Rect2(806, 922, 250, 64),
}
const PALETTE := {"wall": Color("c9c2a3"), "trim": Color("6b5a3e"), "floor": Color("7d6e5c")}
const SFX_DB := {}
const SFX_SOFT := []
