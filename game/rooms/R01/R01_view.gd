extends RoomView
## R01, the Jetty: skeleton view. A flat placeholder elevation (RoomView.draw_placeholder)
## with every hotspot as a labelled card. The room team replaces _draw() with the painted
## plates under assets/rooms/R01/, keeping the hotspot rects registered to the art.

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["bell", Rect2(96, 250, 328, 260), "Mooring bell"],
	["panel", Rect2(560, 250, 328, 260), "Mooring panel"],
	["line", Rect2(1024, 250, 328, 260), "Mooring line"],
	["lighthouse", Rect2(96, 580, 328, 260), "Lighthouse"],
	["causeway", Rect2(560, 580, 328, 260), "Causeway"],
	["gangway", Rect2(1024, 580, 328, 260), "Gangway"],
]
## Where each exit is clicked. The core draws these as tabs on the HUD layer.
const EXIT_RECTS := {
	"R02": Rect2(20, 922, 250, 64),
}
const PALETTE := {"wall": Color("8fa3a6"), "trim": Color("22303a"), "floor": Color("675d51")}
const SFX_DB := {}
const SFX_SOFT := []
