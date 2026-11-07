extends RoomView
## R09, the Lantern Gallery: skeleton view. A flat placeholder elevation (RoomView.draw_placeholder)
## with every hotspot as a labelled card. The room team replaces _draw() with the painted
## plates under assets/rooms/R09/, keeping the hotspot rects registered to the art.

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["lens", Rect2(96, 250, 328, 260), "Signal lens"],
	["apertures", Rect2(560, 250, 328, 260), "Signal apertures"],
	["scope", Rect2(1024, 250, 328, 260), "Scope"],
	["rail", Rect2(96, 580, 328, 260), "Rail"],
	["horizon", Rect2(560, 580, 328, 260), "Horizon"],
]
## Where each exit is clicked. The core draws these as tabs on the HUD layer.
const EXIT_RECTS := {
	"R11": Rect2(20, 922, 250, 64),
}
const PALETTE := {"wall": Color("7f8f99"), "trim": Color("22303a"), "floor": Color("4f565a")}
const SFX_DB := {}
const SFX_SOFT := []
