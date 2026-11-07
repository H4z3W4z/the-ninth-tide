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

The beat chain: repair the desk lamp (supply OFF, straight bridge B, supply ON; curved C is rejected without consuming anything), read Venn's tide log, find what changed in the room, follow the footprints, read the log again, look at the chair, then leave by the door. The room, the window and the sound change at each step.

The locked desk drawer is the slice's second puzzle. Its four dials take an hour that the tide log already records.

Click hotspots in the room; Notebook keeps every observation, Hint escalates in three steps, and Esc opens options (motion and flicker, softened sudden sounds, restart), including from the title. Headphones recommended. In debug builds F1 shows hotspots and 1-4 jump to story stages.

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

Sound is synthesized from seeded, standard-library Python. Rebuild `assets/audio/*.wav` with `python3 tools/build_audio.py`, then re-import. To render review screenshots (needs a display), run `godot --path . --script tools/capture_office.gd -- <out_dir>`.

The scene uses raster exports for identical lettering across platforms. SVGs remain editable source material. Generated background source prompts are recorded in `docs/generation-prompts.json`; no image-generation API credentials are required to run the project.

## Web and native path

The repository is structured around one Godot project. The next gate is a single-threaded Web export served on the local network and tested on the target iPad. Add export templates matching the chosen Godot version, create a Web preset with threads disabled, include `asset_manifest.json`, and exclude `art/`, `docs/`, `tools/`, and `tests/` from the export. Native Android and iOS exports are later validation gates. No exported build or native signing credentials are included.

## Current limits

The room plates are generated full images. Tiny texture/edge differences remain, so swap them on re-entry rather than slowly crossfading every pixel. Furniture, coat, and the late shadow are baked into each plate. The lamp, lighting state, rain effects, and puzzle pieces are separate. A later asset pass can extract more props when animation or new interactions require it.

Only the Intake Office is playable: P01 and the drawer puzzle. Other room exits are descriptive, and the slice ends at the corridor door. Later Office puzzle P20 is documented but has no implementation here. Desktop headless import, logic tests and desktop rendering have been checked; iPad, mobile export and browser builds have not been tested.

The project is not assigned an open-source license. This scaffold does not grant third-party reuse of the game or art.

The repository is [H4z3W4z/the-ninth-tide](https://github.com/H4z3W4z/the-ninth-tide), currently public by the owner's choice. See `docs/github-setup.md` for cloning and contribution notes.

## Reuse policy

Use suitable open-source components before writing equivalent infrastructure. Godot and Inkscape are already used. Popochiu is the preferred candidate to trial for the multi-room adventure framework; it is not yet integrated. See `docs/open-source-reuse.md` for sources, version compatibility, and adoption gates.
