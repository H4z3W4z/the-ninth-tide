# Reuse before rebuilding

**User instruction:** Use suitable open-source work instead of recreating solved infrastructure.

## Already used

| Component | Reused capability | Status |
| --- | --- | --- |
| Godot | Renderer, scene/resource system, image importer, input dispatch, platform file access, timers | The game imports and runs under Godot 4.6.2; actual mobile exports pending |
| Inkscape | SVG rendering and raster export | Used for the precise puzzle graphics and review composition |
| Python standard library | Manifest generation, checksums, structural validation | Used; no custom image codec or build system |
| Git | Version history and repository packaging | Local scaffold; owner-created GitHub remote available |

## Preferred adventure-framework candidate: Popochiu

[Popochiu](https://github.com/carenalgas/popochiu) provides an adventure runtime and editor tools for rooms, props, hotspots, inventory, dialogue, save/load, transitions and audio management. Its [MIT license](https://github.com/carenalgas/popochiu/blob/v2.1.1/LICENSE) is recorded upstream. The [v2.1.1 release](https://github.com/carenalgas/popochiu/releases/tag/v2.1.1) was published May 23, 2026; its tagged README targets Godot 4.6. The README's prose still calls 2.1.0 latest, so use the actual release record for the patch version.

Status: **trialled November 7, 2026 on Godot 4.6.2. Decision: do not adopt.** Not vendored.

### The trial

v2.1.1 (`git clone --branch v2.1.1`, commit `784d147 Release 2.1.1`) was cloned outside the repository and enabled in a throwaway Godot 4.6.2 project (Compatibility renderer, headless). Rooms and an inventory item were created with Popochiu's own factories (`PopochiuRoomFactory`, `PopochiuInventoryItemFactory`), the bundled Simple Click GUI template was selected, and a driver autoload exercised the requirements at runtime.

| Requirement | Result |
| --- | --- |
| Fixed first-person rooms, no walking avatar | **Works.** `has_player = false` on a room; the room loads with no player character. |
| Hotspots | **Works.** A `PopochiuHotspot` with a rectangular interaction polygon over the lamp. |
| Inventory item used on a hotspot | **Works.** `I.BridgeB.add()`, then `hotspot.on_item_used(item)` reached `_on_item_used` with the item. |
| Our deterministic sim as the single source of truth | **Only by bypassing Popochiu's state.** Popochiu keeps its own per-room, per-character and per-item `State` resources, visit counters and inventory, and saves them all. Our tide/puzzle state could ride only in `Globals.on_save()` custom data, next to a second, independent copy of room and inventory state. |
| Save/load of custom tide state | **Works, with caveats.** `E.save_game(1)` / `E.load_game(1)` round-tripped `{tide, flags}` through `Globals.on_save/on_load`; numbers came back as floats (`tide: 2.0`). Saves go to fixed `user://save_%d.json` slots. In the playerless room, startup logged `Invalid access to property or key 'id'` in `i_room.gd:242` (`room_readied` reads `loaded_game.player.id`, which is only written when a player character exists). |
| Headless, script-driven setup (how this project's teams work) | **Fails.** The GUI and command scripts (`game/gui/gui.tscn`, `game/gui/gui_commands.gd`) are produced by the editor's setup wizard; without them `E._ready()` errors (`gui_commands.gd: File not found`). |
| Parallel teams, one room per team | **Fails the constraint.** Every room or item created rewrites shared files: `game/popochiu_data.cfg` (the room/item registry) and the generated autoload scripts `game/autoloads/r.gd`, `i.gd` (a typed property per room/item). Eleven room teams would conflict on every room and item. |
| Scale | 31,800 lines of addon GDScript and ten autoload singletons (`Globals, Cursor, E, R, C, I, D, A, G, T`), of which this game would use rooms, hotspots and the inventory list. Characters, walkable areas, dialogue trees, verb GUIs and the camera go unused. |

Not tested: touch usability and the Safari/iPad Web export (no reason to after the blockers above).

### Decision and what we reuse

**Do not adopt.** The two hard blockers are the shared generated registry files (the full game is built by parallel room teams, each confined to its own files) and the second source of truth for room and inventory state (our node-free deterministic sim must own every flag the tests exercise). The capabilities that do work (fixed rooms, hotspots, item-on-hotspot, a JSON save with custom data) are a small part of what we already had in the Intake Office slice.

Instead the foundation is a small core lifted from the slice (`game/core/`, about 2,100 lines including the room base classes and the game scene), documented in `docs/dev/room-contract.md`. Ideas taken from Popochiu's design: item-on-target routing through one `use_item` hook, rooms discovered by folder (its factories' folder-per-room layout, without the generated registry), and save slots with a custom-data section (our progress, settings and pre-ending checkpoint files). Revisit Popochiu only if the game later needs walking characters or branching dialogue trees.

[Escoria](https://github.com/godot-escoria) is an alternative point-and-click framework, but no compatibility claim or adoption decision has been made for it in this scaffold.

## Dependency policy

Pin versions and retain required licenses for incorporated code. Add dependencies only for a concrete capability. Record what is actually used separately from researched candidates. Do not pull in multiple adventure frameworks at once. Do not import third-party game artwork as production assets merely because code is open source.

Research checked September 7, 2026 using the upstream README, license, and release metadata; runtime trial November 7, 2026. Current vendored adventure-framework dependency count: zero.
