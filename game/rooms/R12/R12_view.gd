extends RoomView
## R12, the Observation Chamber: skeleton view. A flat placeholder elevation (RoomView.draw_placeholder)
## with every hotspot as a labelled card. The room team replaces _draw() with the painted
## plates under assets/rooms/R12/, keeping the hotspot rects registered to the art.

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["chair", Rect2(96, 250, 328, 260), "Chair"],
	["frames", Rect2(560, 250, 328, 260), "Record frames"],
	["terminal", Rect2(1024, 250, 328, 260), "Witness terminal"],
	["handle", Rect2(96, 580, 328, 260), "Severance handle"],
	["window", Rect2(560, 580, 328, 260), "Chamber window"],
	["tray", Rect2(1024, 580, 328, 260), "Equipment tray"],
]
## Where each exit is clicked. The core draws these as tabs on the HUD layer.
const EXIT_RECTS := {
	"R11": Rect2(20, 922, 250, 64),
}
const PALETTE := {"wall": Color("6f7378"), "trim": Color("292929"), "floor": Color("3e3f42")}
const SFX_DB := {}
const SFX_SOFT := []
