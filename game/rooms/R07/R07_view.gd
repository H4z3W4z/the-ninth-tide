extends RoomView
## R07, the Wet Laboratory: skeleton view. A flat placeholder elevation (RoomView.draw_placeholder)
## with every hotspot as a labelled card. The room team replaces _draw() with the painted
## plates under assets/rooms/R07/, keeping the hotspot rects registered to the art.

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["jars", Rect2(96, 250, 328, 260), "Sealed jars"],
	["rack", Rect2(560, 250, 328, 260), "Test rack"],
	["balance", Rect2(1024, 250, 328, 260), "Balance"],
	["tank", Rect2(96, 580, 328, 260), "Flotation tank"],
	["datum", Rect2(560, 580, 328, 260), "Brass datum"],
	["cards", Rect2(1024, 580, 328, 260), "Reference cards"],
]
## Where each exit is clicked. The core draws these as tabs on the HUD layer.
const EXIT_RECTS := {
	"R05": Rect2(20, 922, 250, 64),
	"R10": Rect2(282, 922, 250, 64),
	"R11": Rect2(544, 922, 250, 64),
}
const PALETTE := {"wall": Color("a7bfb5"), "trim": Color("38575a"), "floor": Color("6a6a62")}
const SFX_DB := {}
const SFX_SOFT := []
