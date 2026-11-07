extends RoomView
## R06, the Bunk Room: skeleton view. A flat placeholder elevation (RoomView.draw_placeholder)
## with every hotspot as a labelled card. The room team replaces _draw() with the painted
## plates under assets/rooms/R06/, keeping the hotspot rects registered to the art.

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["lockers", Rect2(96, 250, 328, 260), "Bunk lockers"],
	["belongings", Rect2(560, 250, 328, 260), "Loose belongings"],
	["bunks", Rect2(1024, 250, 328, 260), "Bunks"],
	["calendar", Rect2(96, 580, 328, 260), "Wall calendar"],
	["shelf", Rect2(560, 580, 328, 260), "Pencil shelf"],
	["curtain", Rect2(1024, 580, 328, 260), "Curtain"],
]
## Where each exit is clicked. The core draws these as tabs on the HUD layer.
const EXIT_RECTS := {
	"R02": Rect2(20, 922, 250, 64),
}
const PALETTE := {"wall": Color("b3b8a8"), "trim": Color("3e4a52"), "floor": Color("675d51")}
const SFX_DB := {}
const SFX_SOFT := []
