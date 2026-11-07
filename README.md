# The Ninth Tide

An illustrated point-and-click cosmic horror game set in a coastal survey station whose instruments are learning to locate their observer.

**Current milestone:** the full-game foundation. One game scene (`game/core/game.tscn`) hosts all twelve locations, R01–R12, on a small multi-room core: tides I–IX derived from puzzle flags, travel with the GDD's gates, inventory, a notebook with a page per room and the station plan, hints, saves with migration from the slice, a tide card and two ending cards. The Intake Office (R02) carries the whole slice (rounds 1–3) as Tide I content; the other eleven rooms are skeletons (a flat placeholder elevation, labelled hotspots, exits, an arrival line and a test each) for the room teams to fill, following `docs/dev/room-contract.md`.

## Included

- 43 runtime PNG assets: 25 approved plates and props with 21 editable SVG sources, plus 18 painted stage plates and overlays in `assets/stages/` built by the seeded `tools/build_art.py` (painters in `tools/art/`).
- Three office background plates: arrival, gathering rain, and ominous Tide VI.
- Transparent lamp sprite plus an aligned illuminated-shade overlay.
- Precise bridge B / spare C, socket, supply-switch states, and indicator.
- Maintenance instructions, closure duty card, and the solved pencil note.
- Three clipped window-rain frames, tray artwork, and UI elements.
- The full Tide I office beat chain: P01, the drawer, the self-writing log, the closure report, look-away changes, the threshold and two endings.
- Godot preview with click/tap repair interaction, hints, notebook, weather review, motion toggle, and local save/resume.
- Asset manifest containing dimensions, hashes, placement rectangles, hotspots, and state triggers.
- Full game design v1.1, original research brief, approved concept references, and production notes.

## Play

Validated with **Godot 4.6.2**, using the Compatibility renderer and GDScript. Import `project.godot` and run the project (F5). The game starts in the Intake Office.

Exits are tabs along the floor line (dimmed while locked). After P05 the notebook's Plan page travels straight to any visited room whose way is open. In debug builds F1 shows hotspots and exits, 1–9 jump the current room's stages, and Shift+1–9 jump to the start of tide I–IX.

### The Intake Office (R02), Tide I

The beat chain:

1. **Lamp (P01).** Supply OFF, straight bridge B, supply ON. Curved C is rejected without consuming anything. Two latches let go somewhere below.
2. **Tide log.** Venn has worked the tides out to tomorrow, and the last line is in Ada's hand. The log is strictly periodic: high water to high water is 12 h 21 m, written in his pencil margin. One time, the hour "she mends the lamp", is under a seawater stain. The sea goes silent once, after the first read.
3. **Footprints and the drawer.** Bare prints run from the puddle to a locked drawer. Its dials want the stained hour, which is worked out from the rhythm: 06:31 + 12 h 21 m = 18:52. Near misses get their own answers. Inside are his watch, stopped at 18:52, and a photograph of this window from the sea side. Looked at twice, it shows something pale and too tall behind her chair.
4. **Soundings.** With the drawer open, the survey chart shows Venn's re-soundings. Every depth is deeper by the same amount, and past the ninth piling there is no bottom at 400 fathoms.
5. **The log rewrites itself** in her hand: "She looks at the chair." HW 9.9 m.
6. **The chair.** The seat is wet and warm. Three taps on the glass, low down, below the sill, and palm marks appear on the outside of the window. The sea outside tips about its horizon inside a square frame. The chair's shadow leans toward the lamp, and at stage 3 someone sits in it.
7. **The closure report.** The door stays latched until Venn's closure report reconciles: pilings 10, observers 2, the evening's high water 19:34 (worked out from the log: 07:13 + 12 h 21 m), height 9.9 m. Every answer has a witness in the notebook. Until she files it, the log records the first three things she does, and her first three wrong filings, in her hand. When she steps back from the signed report, the door unlatches behind her.
8. **The threshold.** The corridor goes on further than the station does, and it breathes in time with the tide while the water rises in it. To go on she must hold still: keep the cursor within 4 px for 3 s after the third line, or wait for the 18 s fallback, then click the doorway. Or she can turn round to the chair.
9. **The end card.** The photograph from after, and the log's next two rows writing themselves. Which photograph, and whose hand the second row is in, depends on whether she turned round. In the full game this card is the Tide I transition: "Go on" returns her to the office, where the corridor is only a corridor now and the chart and listening rooms are open.

### Round 3

- **Click to advance.** Story chains are atomic and the player sets their speed. While one plays, a click anywhere in the scene (or Back, or Esc in a close-up) brings its next line up at once, with the sounds that belong to it; it never starts something new. A small ▸ at the right of the subtitle slab shows there is more. Notebook, Hint and the menu always answer; a hint asked mid-chain shows after it. The slab fades away when nothing is being said.
- **The evening tide.** The closure report's high water is set on four dials, not chosen: Venn's margin rule from the last time in the log. Near-miss times get their own answers. Wrong filings are written into the log in her hand ("She gets it wrong."), at most three.
- **Look-away.** At stage 3, each return from a close-up or the notebook lets the room change one more thing: the mug brims with seawater, the stove floods, the oilskin's hood turns to the desk, water seeps under the door, footprints walk up the wall, and a fourth hand appears high on the glass. The chart's contours close in rings on the ninth piling; the window then tells her what it looks through.
- **Two threshold outcomes.** At the threshold, step into the corridor or turn round to the chair. The end card's photograph and log rows differ.
- **Painted stage art.** `assets/stages/` holds new painted plates and overlays for stage 2 and later (room plates, the threshold corridor and figure, the photographs, palms, prints, contours and the look-away changes), built from the approved plates by the seeded painter `tools/build_art.py`. Every one is optional at runtime: if a file is missing, the procedural drawing is used instead. The window has its own sea-green light so the painted water reads through the dark room. The menu's Restart now asks twice.

The room, the window, the light and the sound change at each step. Every abrupt sound respects "Soften sudden sounds", and every flicker and animation respects "Motion & flicker".

Controls: click hotspots in the room. Drawer dials and the report's time dials turn up on their top half and down on their bottom half; the faint digits above and below show where each click goes. Each closure-report line cycles when clicked, and "Sign and file" submits. Notebook keeps every observation, with a count. Hint escalates in three steps; at the threshold it only says to hold still. Esc opens options (motion and flicker, softened sudden sounds, new game), including from the title. Headphones recommended. In R02, debug 1–6 jump to stages 0–3, 4 "report filed" and 5 "threshold passed".

The original P01 assembly preview (`intake_preview.tscn`) remains for asset review. Its weather buttons are **asset-review controls**: they change artwork without advancing story flags, and P01 alone must not summon Tide VI.

## Project structure

| Path | Purpose |
| --- | --- |
| `project.godot`, `game/core/` | The game scene and the multi-room core: `game_sim.gd` (deterministic global state, travel, saves), `room_sim.gd` / `room_view.gd` (room base classes), `game.gd` (scheduler, HUD, notebook, audio, input), `mixer.gd`, `ink.gd` |
| `game/rooms/<rid>/` | One folder per room: `<rid>_sim.gd` (node-free state and puzzles) and `<rid>_view.gd/.tscn` (rendering). R02 is the migrated Intake Office slice |
| `docs/dev/room-contract.md` | The file layout and API every room team follows |
| `intake_preview.*` | Original P01 assembly preview |
| `assets/backgrounds/` | Generated full-room state plates |
| `assets/props/` | Lamp, light overlay, parts tray, rain frames |
| `assets/puzzle/` | Precise P01 assets and readable documents |
| `assets/ui/` | Reusable buttons and inventory frames |
| `asset_manifest.json` | Runtime asset registry and placement specification |
| `art/concepts/` | Approved visual references; not loaded at runtime |
| `docs/design/` | Full game design and research |
| `docs/` | Art direction, production limits, validation and GitHub setup |
| `tools/` | Rebuild, manifest and asset-check scripts |
| `tests/` | `core_test.gd` (core), `chain_test.gd` (the whole chain on the sim), `click_chain_test.gd` (the whole chain as real clicks on the game scene), `rooms/<rid>_test.gd` (each room; R02 holds every slice test), `p01_smoke.gd` |
| `.github/workflows/` | Asset integrity check for pushes and pull requests |

## Rebuild and validate

PNG assets are already included. To edit and rebuild precision assets, install Python 3, Inkscape, and the DejaVu Sans font, then run:

```sh
python3 tools/build_vectors.py
python3 tools/build_manifest.py
python3 tools/validate_assets.py
godot --headless --path . --editor --import
godot --headless --path . --script tests/core_test.gd
godot --headless --path . --script tests/chain_test.gd
godot --headless --path . --script tests/click_chain_test.gd
for f in tests/rooms/R*_test.gd; do godot --headless --path . --script "$f"; done
godot --headless --path . --script tests/p01_smoke.gd
python3 tools/validate_assets.py
```

`tests/core_test.gd` covers room discovery, the GDD topology and the reachable rooms at every tide, tides and weather, travel, inventory and item use, the notebook, hints, saves (schema, tampering, the slice-save migration, settings kept apart, the fallback to the previous save), debug jumps, plan travel, both ending cards and the game scene hosting every room. Each `tests/rooms/<rid>_test.gd` checks its room's registration, gates, arrival, hotspots, exits and view rects. `tests/rooms/R02_test.gd` is the slice's suite, ported, and covers the whole office headless: the full playthrough and determinism, P01, the drawer, the tide rhythm and every near miss, the log rewrite and the history rows, the closure report gate (every field combination, the evening-tide dials and their near misses, misses written in her hand, the unlatch on Back), soundings and contours, look-away, every revisit line, the knock, the threshold (stillness, fallback, phase lock), both endings and the end card, saves and tamper handling, the notebook keeping every observation, the chain scheduler (click-to-advance, sounds before their lines, hints after the chain, no lost or interleaved story lines), a one-click-per-second driver from the title to the end card, the breath envelope, the knock's hush, the dial digits, the two-step restart and the voice cap. `tests/p01_smoke.gd` covers the original P01 preview.

Sound is synthesized from seeded, standard-library Python. Rebuild `assets/audio/*.wav` with `python3 tools/build_audio.py`, then re-import. To render review screenshots of any room (needs a display), run `godot --path . --fixed-fps 60 --disable-vsync --script tools/capture.gd -- <out_dir> [shots.json]`. The flags keep every frame exactly 1/60 s, so captures are deterministic, and they still run at full speed when the desktop session is locked and the compositor throttles windows.

The scene uses raster exports for identical lettering across platforms. SVGs remain editable source material. Generated background source prompts are recorded in `docs/generation-prompts.json`; no image-generation API credentials are required to run the project.

## Web and native path

The repository is structured around one Godot project. The next gate is a single-threaded Web export served on the local network and tested on the target iPad. Add export templates matching the chosen Godot version, create a Web preset with threads disabled, include `asset_manifest.json`, and exclude `art/`, `docs/`, `tools/`, and `tests/` from the export. Native Android and iOS exports are later validation gates. No exported build or native signing credentials are included.

## Current limits

The room plates are generated full images. Tiny texture/edge differences remain, so swap them on re-entry rather than slowly crossfading every pixel. Furniture, coat, and the late shadow are baked into each plate. The lamp, lighting state, rain effects, and puzzle pieces are separate. A later asset pass can extract more props when animation or new interactions require it.

Only the Intake Office is fully built: P01, the drawer puzzle, the closure report and the threshold. The other eleven rooms are reachable skeletons with placeholder elevations; P02–P27 and both ending scenes are documented in the GDD and the puzzle cards but not yet implemented (the ending cards are placeholders). Later Office puzzle P20 is not implemented. Desktop headless import, logic tests and desktop rendering have been checked; iPad, mobile export and browser builds have not been tested.

The project is not assigned an open-source license. This scaffold does not grant third-party reuse of the game or art.

The repository is [H4z3W4z/the-ninth-tide](https://github.com/H4z3W4z/the-ninth-tide), currently public by the owner's choice. See `docs/github-setup.md` for cloning and contribution notes.

## Reuse policy

Use suitable open-source components before writing equivalent infrastructure. Godot and Inkscape are already used. Popochiu v2.1.1 was trialled on Godot 4.6.2 and not adopted (shared generated registry files per room and a second copy of room state); see `docs/open-source-reuse.md` for the evidence.
