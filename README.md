# The Ninth Tide

An illustrated point-and-click cosmic horror game set in a coastal survey station whose instruments are learning to locate their observer.

**Current milestone:** Intake Office asset scaffold and a functional P01 assembly preview. This is the first room's production starting point, not the full game.

## Included

- 25 runtime PNG assets with 21 editable SVG sources.
- Three office background plates: arrival, gathering rain, and ominous Tide VI.
- Transparent lamp sprite plus an aligned illuminated-shade overlay.
- Precise bridge B / spare C, socket, supply-switch states, and indicator.
- Maintenance instructions, closure duty card, and the solved pencil note.
- Three clipped window-rain frames, tray artwork, and UI elements.
- Godot preview with click/tap repair interaction, hints, notebook, weather review, motion toggle, and local save/resume.
- Asset manifest containing dimensions, hashes, placement rectangles, hotspots, and state triggers.
- Full game design v1.2, original research brief, approved concept references, and production notes; map inspection and P03 fragment assembly are specified for implementation.
- Chart Room arrival concept master and [production asset plan](docs/chart-room-assets.md); this room is not yet playable.

## Open the preview

Validated with **Godot 4.5.1**, using the Compatibility renderer and GDScript. Import `project.godot` in Godot and press F6 on `intake_preview.tscn`, or F5 to run the project.

Select the lamp or nearby tray. Set supply OFF, select bridge B, tap the socket, then switch ON. Try C or attempt fitting with the supply on to review failure feedback. Return to the room to see the lamp lit and open Notebook for the preserved note.

The top weather buttons are **asset-review controls**. Arrival / Tide III / Tide VI change artwork without advancing story flags. In the full game, P09 triggers the intermediate plate and completion of both P17 and P18 triggers the ominous plate. P01 alone must not summon Tide VI.

Mouse and touch share the same tap targets. Escape returns to the room. This assembly sample does not yet provide full keyboard focus navigation, audio, or an iPad-tested browser build.

## Project structure

| Path | Purpose |
| --- | --- |
| `project.godot`, `intake_preview.*` | Runnable first-room assembly sample |
| `assets/backgrounds/` | Generated full-room state plates |
| `assets/props/` | Lamp, light overlay, parts tray, rain frames |
| `assets/puzzle/` | Precise P01 assets and readable documents |
| `assets/ui/` | Reusable buttons and inventory frames |
| `asset_manifest.json` | Runtime asset registry and placement specification |
| `art/concepts/` | Approved visual references; not loaded at runtime |
| `docs/design/` | Full game design and research |
| `docs/` | Art direction, production limits, validation and GitHub setup |
| `tools/` | Rebuild, manifest and asset-check scripts |
| `tests/` | Godot P01 progression smoke test |
| `.github/workflows/` | Asset integrity check for pushes and pull requests |

## Rebuild and validate

PNG assets are already included. To edit and rebuild precision assets, install Python 3, Inkscape, and the DejaVu Sans font, then run:

```sh
python3 tools/build_vectors.py
python3 tools/build_manifest.py
python3 tools/validate_assets.py
godot --headless --path . --editor --import
godot --headless --path . --script tests/p01_smoke.gd
```

The scene uses raster exports for identical lettering across platforms. SVGs remain editable source material. Generated background source prompts are recorded in `docs/generation-prompts.json`; no image-generation API credentials are required to run the project.

## Web and native path

The repository is structured around one Godot project. The next gate is a single-threaded Web export served on the local network and tested on the target iPad. Add export templates matching the chosen Godot version, create a Web preset with threads disabled, include `asset_manifest.json`, and exclude `art/`, `docs/`, `tools/`, and `tests/` from the export. Native Android and iOS exports are later validation gates. No exported build or native signing credentials are included.

## Current limits

The room plates are generated full images. Tiny texture/edge differences remain, so swap them on re-entry rather than slowly crossfading every pixel. Furniture, coat, and the late shadow are baked into each plate. The lamp, lighting state, rain effects, and puzzle pieces are separate. A later asset pass can extract more props when animation or new interactions require it.

Only P01 is playable. Other room exits are descriptive; the service door remains locked until P06 in the design. Later Office puzzle P20 is documented but has no implementation here. There is no audio yet. Desktop headless import/runtime and puzzle state checks have passed; actual iPad, mobile export, and rendered Godot UI testing remain pending.

The project is not assigned an open-source license. This scaffold does not grant third-party reuse of the game or art.

The repository is [H4z3W4z/the-ninth-tide](https://github.com/H4z3W4z/the-ninth-tide), currently public by the owner's choice. See `docs/github-setup.md` for cloning and contribution notes.

## Reuse policy

Use suitable open-source components before writing equivalent infrastructure. Godot and Inkscape are already used. Popochiu is the preferred candidate to trial for the multi-room adventure framework; it is not yet integrated. See `docs/open-source-reuse.md` for sources, version compatibility, and adoption gates.
