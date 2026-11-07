extends RoomView
## R10, the Records Vault: skeleton view. A flat placeholder elevation (RoomView.draw_placeholder)
## with every hotspot as a labelled card. The room team replaces _draw() with the painted
## plates under assets/rooms/R10/, keeping the hotspot rects registered to the art.

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["shelves", Rect2(96, 250, 328, 260), "Shelves"],
	["photos", Rect2(560, 250, 328, 260), "Photographs"],
	["contact", Rect2(1024, 250, 328, 260), "Contact sheet"],
	["staff", Rect2(96, 580, 328, 260), "STAFF drawer"],
	["folders", Rect2(560, 580, 328, 260), "Folders"],
	["tray", Rect2(1024, 580, 328, 260), "Tray"],
]
## Where each exit is clicked. The core draws these as tabs on the HUD layer.
const EXIT_RECTS := {
	"R07": Rect2(20, 922, 250, 64),
}
const PALETTE := {"wall": Color("b5a98e"), "trim": Color("4a3b2c"), "floor": Color("5c5348")}
const SFX_DB := {}
const SFX_SOFT := []
