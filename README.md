# The Ninth Tide

An illustrated point-and-click cosmic horror game set in a coastal survey station whose instruments are learning to locate their observer.

**Current milestone:** a playable one-room vertical slice of Tide I, the Intake Office (`game/intake_office.tscn`), with lighting, synthesized sound, subtitles, hints, a notebook, saves and an escalating beat chain. This is the first room's production slice, not the full game.

## Included

- 25 runtime PNG assets with 21 editable SVG sources.
- Three office background plates: arrival, gathering rain, and ominous Tide VI.
- Transparent lamp sprite plus an aligned illuminated-shade overlay.
- Precise bridge B / spare C, socket, supply-switch states, and indicator.
- Maintenance instructions, closure duty card, and the solved pencil note.
- Three clipped window-rain frames, tray artwork, and UI elements.
- Godot preview with click/tap repair interaction, hints, notebook, weather review, motion toggle, and local save/resume.
- Asset manifest containing dimensions, hashes, placement rectangles, hotspots, and state triggers.
- Full game design v1.1, original research brief, approved concept references, and production notes.

## Play the slice

Validated with **Godot 4.6.2**, using the Compatibility renderer and GDScript. Import `project.godot` and run the project (F5), or open `game/intake_office.tscn` and press F6.

The beat chain:

1. **Lamp (P01).** Supply OFF, straight bridge B, supply ON. Curved C is rejected without consuming anything. Two latches let go somewhere below.
2. **Tide log.** Venn has worked the tides out to tomorrow, and the last line is in Ada's hand. The log is strictly periodic: high water to high water is 12 h 21 m, written in his pencil margin. One time, the hour "she mends the lamp", is under a seawater stain. The sea goes silent once, after the first read.
3. **Footprints and the drawer.** Bare prints run from the puddle to a locked drawer. Its dials want the stained hour, which is worked out from the rhythm: 06:31 + 12 h 21 m = 18:52. Near misses get their own answers. Inside are his watch, stopped at 18:52, and a photograph of this window from the sea side. Looked at twice, it shows something pale and too tall behind her chair.
4. **Soundings.** With the drawer open, the survey chart shows Venn's re-soundings. Every depth is deeper by the same amount, and past the ninth piling there is no bottom at 400 fathoms.
5. **The log rewrites itself** in her hand: "She looks at the chair." HW 9.9 m.
6. **The chair.** The seat is wet and warm. Three taps on the glass, low down, below the sill, and palm marks appear on the outside of the window. The sea outside tips about its horizon inside a square frame. The chair's shadow leans toward the lamp, and at stage 3 someone sits in it.
7. **The closure report.** The door stays latched until Venn's closure report reconciles: pilings 10, observers 2, HW 9.9 m, last entry A. Mercer. Every answer has a witness in the notebook. Until she files it, the log records the first three things she does, in her hand. Filing it unlatches the door behind her.
8. **The threshold.** The corridor goes on further than the station does, and it breathes in time with the tide. The room has been breathing that same loop since stage 2, quietly. To go on she must hold still: keep the cursor within 4 px for 3 s after the third line, or wait for the 18 s fallback. Touch input passes naturally.
9. **The end card.** The photograph from after she has gone, with the chair empty. The log's last row writes itself. "It was never the sea we were measuring."

The room, the window, the light and the sound change at each step. Every abrupt sound respects "Soften sudden sounds", and every flicker and animation respects "Motion & flicker".

Controls: click hotspots in the room. Drawer dials turn up on their top half and down on their bottom half. Each closure-report line cycles when clicked, and "Sign and file" submits. Notebook keeps every observation, with a count. Hint escalates in three steps; at the threshold it only says to hold still. Esc opens options (motion and flicker, softened sudden sounds, restart), including from the title. Headphones recommended. In debug builds F1 shows hotspots, and 1-5 jump to stages 0-3, plus 4 for "report filed".

The original P01 assembly preview (`intake_preview.tscn`) remains for asset review. Its weather buttons are **asset-review controls**: they change artwork without advancing story flags, and P01 alone must not summon Tide VI.

## Project structure

| Path | Purpose |
| --- | --- |
| `project.godot`, `game/` | Intake Office slice: `office_sim.gd` (deterministic state), `intake_office.gd` (rendering, light, sound) |
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
| `tests/` | Slice logic and wiring tests, and the P01 smoke test |
| `.github/workflows/` | Asset integrity check for pushes and pull requests |

## Rebuild and validate

PNG assets are already included. To edit and rebuild precision assets, install Python 3, Inkscape, and the DejaVu Sans font, then run:

```sh
python3 tools/build_vectors.py
python3 tools/build_manifest.py
python3 tools/validate_assets.py
godot --headless --path . --editor --import
godot --headless --path . --script tests/office_sim_test.gd
godot --headless --path . --script tests/p01_smoke.gd
```

`tests/office_sim_test.gd` covers the whole slice headless: the full playthrough and determinism, P01, the drawer, the tide rhythm and every near miss, the log rewrite and the history rows, the closure report gate (all 36 field combinations), soundings, every revisit line, the knock, the threshold (stillness, fallback, phase lock), the end card, saves and tamper handling, the notebook keeping every observation, the subtitle scheduler (feedback within 1.5 s, a new reveal within 3 s, no lost or interleaved story lines), the breath envelope and the knock's hush. `tests/p01_smoke.gd` covers the original P01 preview.

Sound is synthesized from seeded, standard-library Python. Rebuild `assets/audio/*.wav` with `python3 tools/build_audio.py`, then re-import. To render review screenshots (needs a display), run `godot --path . --fixed-fps 60 --disable-vsync --script tools/capture_office.gd -- <out_dir> [shots.json]`. The flags keep every frame exactly 1/60 s, so captures are deterministic, and they still run at full speed when the desktop session is locked and the compositor throttles windows.

The scene uses raster exports for identical lettering across platforms. SVGs remain editable source material. Generated background source prompts are recorded in `docs/generation-prompts.json`; no image-generation API credentials are required to run the project.

## Web and native path

The repository is structured around one Godot project. The next gate is a single-threaded Web export served on the local network and tested on the target iPad. Add export templates matching the chosen Godot version, create a Web preset with threads disabled, include `asset_manifest.json`, and exclude `art/`, `docs/`, `tools/`, and `tests/` from the export. Native Android and iOS exports are later validation gates. No exported build or native signing credentials are included.

## Current limits

The room plates are generated full images. Tiny texture/edge differences remain, so swap them on re-entry rather than slowly crossfading every pixel. Furniture, coat, and the late shadow are baked into each plate. The lamp, lighting state, rain effects, and puzzle pieces are separate. A later asset pass can extract more props when animation or new interactions require it.

Only the Intake Office is playable: P01, the drawer puzzle and the closure report. Other room exits are descriptive, and the slice ends at the corridor door. Later Office puzzle P20 is documented but has no implementation here. Desktop headless import, logic tests and desktop rendering have been checked; iPad, mobile export and browser builds have not been tested.

The project is not assigned an open-source license. This scaffold does not grant third-party reuse of the game or art.

The repository is [H4z3W4z/the-ninth-tide](https://github.com/H4z3W4z/the-ninth-tide), currently public by the owner's choice. See `docs/github-setup.md` for cloning and contribution notes.

## Reuse policy

Use suitable open-source components before writing equivalent infrastructure. Godot and Inkscape are already used. Popochiu is the preferred candidate to trial for the multi-room adventure framework; it is not yet integrated. See `docs/open-source-reuse.md` for sources, version compatibility, and adoption gates.
