extends RoomView
## R11, the Dry Stair: skeleton view. A flat placeholder elevation (RoomView.draw_placeholder)
## with every hotspot as a labelled card. The room team replaces _draw() with the painted
## plates under assets/rooms/R11/, keeping the hotspot rects registered to the art.

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["gate", Rect2(96, 250, 328, 260), "Pressure gate"],
	["water", Rect2(560, 250, 328, 260), "Water"],
	["plates", Rect2(1024, 250, 328, 260), "Landing plates"],
	["steps", Rect2(96, 580, 328, 260), "Steps"],
	["bell", Rect2(560, 580, 328, 260), "Bell"],
]
## Where each exit is clicked. The core draws these as tabs on the HUD layer.
const EXIT_RECTS := {
	"R03": Rect2(20, 922, 250, 64),
	"R07": Rect2(282, 922, 250, 64),
	"R09": Rect2(544, 922, 250, 64),
	"R12": Rect2(806, 922, 250, 64),
}
const PALETTE := {"wall": Color("d6d2c4"), "trim": Color("5d6b6e"), "floor": Color("9a958a")}
const SFX_DB := {}
const SFX_SOFT := []
