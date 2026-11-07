extends RoomView
## R03, the Chart Room: skeleton view. A flat placeholder elevation (RoomView.draw_placeholder)
## with every hotspot as a labelled card. The room team replaces _draw() with the painted
## plates under assets/rooms/R03/, keeping the hotspot rects registered to the art.

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["recorder", Rect2(96, 250, 328, 260), "Tide recorder"],
	["sheets", Rect2(560, 250, 328, 260), "Tide sheets"],
	["plate", Rect2(1024, 250, 328, 260), "Calibration plate"],
	["hatch", Rect2(96, 580, 328, 260), "Observation hatch"],
	["window", Rect2(560, 580, 328, 260), "Sea window"],
	["lever", Rect2(1024, 580, 328, 260), "Calibrate lever"],
]
## Where each exit is clicked. The core draws these as tabs on the HUD layer.
const EXIT_RECTS := {
	"R02": Rect2(20, 922, 250, 64),
	"R11": Rect2(282, 922, 250, 64),
	"R04": Rect2(544, 922, 250, 64),
}
const PALETTE := {"wall": Color("b8c9b4"), "trim": Color("2f5b6e"), "floor": Color("7d6e5c")}
const SFX_DB := {}
const SFX_SOFT := []
