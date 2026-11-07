extends RoomView
## R04, the Listening Room: skeleton view. A flat placeholder elevation (RoomView.draw_placeholder)
## with every hotspot as a labelled card. The room team replaces _draw() with the painted
## plates under assets/rooms/R04/, keeping the hotspot rects registered to the art.

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["funnels", Rect2(96, 250, 328, 260), "Ear trumpets"],
	["spindle", Rect2(560, 250, 328, 260), "Cylinder spindle"],
	["bands", Rect2(1024, 250, 328, 260), "Recording bands"],
	["stool", Rect2(96, 580, 328, 260), "Stool"],
	["board", Rect2(560, 580, 328, 260), "Channel board"],
	["dial", Rect2(1024, 580, 328, 260), "Level indicators"],
]
## Where each exit is clicked. The core draws these as tabs on the HUD layer.
const EXIT_RECTS := {
	"R02": Rect2(20, 922, 250, 64),
	"R03": Rect2(282, 922, 250, 64),
}
const PALETTE := {"wall": Color("c2b49a"), "trim": Color("5a4632"), "floor": Color("675d51")}
const SFX_DB := {}
const SFX_SOFT := []
