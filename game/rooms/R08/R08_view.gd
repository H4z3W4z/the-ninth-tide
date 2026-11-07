extends RoomView
## R08, the Machine Room: skeleton view. A flat placeholder elevation (RoomView.draw_placeholder)
## with every hotspot as a labelled card. The room team replaces _draw() with the painted
## plates under assets/rooms/R08/, keeping the hotspot rects registered to the art.

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["diaphragm", Rect2(96, 250, 328, 260), "Diaphragm"],
	["toggles", Rect2(560, 250, 328, 260), "Valve toggles"],
	["drawing", Rect2(1024, 250, 328, 260), "Maintenance drawing"],
	["pump", Rect2(96, 580, 328, 260), "Pump"],
	["belts", Rect2(560, 580, 328, 260), "Belts"],
	["repairs", Rect2(1024, 580, 328, 260), "Repair tags"],
]
## Where each exit is clicked. The core draws these as tabs on the HUD layer.
const EXIT_RECTS := {
	"R05": Rect2(20, 922, 250, 64),
}
const PALETTE := {"wall": Color("9da39a"), "trim": Color("292929"), "floor": Color("5a544c")}
const SFX_DB := {}
const SFX_SOFT := []
