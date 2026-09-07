# Playable map inspection and P03 workbench

Open `project.godot` with Godot 4.5.1 and run the project. The Office now has a clickable coastal map. Its toolbar Maps button or the M key opens the same viewer. N opens preserved map observations. After completing P01, use Chart Room or the C key to enter the chart inspection workbench.

## Inspect maps

Every map shown in the two preview views has an inspection route. The Office survey is atmospheric and available before P01. Both Chart Room sheets open their associated inspection/assembly views. Map viewers have zoom buttons, Fit, directional pan buttons, mouse-wheel zoom, drag pan, two-finger pinch handling, and keyboard controls. Tab and Enter operate the native buttons. With the image focused, use arrows to pan, + / - to zoom, and Home to fit. Escape returns to the Office.

Each document has readable authored SVG/PNG artwork and a transcript. Maps are reauthored from deterministic geometry rather than enlarged crops of the generated room. The room views use matching map-face overlays. Observed versions are retained in the map notebook. The altered Office survey is implemented as an alternate evidence asset and state, but P21 is not implemented and the weather review buttons do not activate it.

## Complete the Chart Room puzzle

1. Repair the desk lamp (P01) to release access.
2. In the Chart Room, inspect the unlocked chart drawer and the paper beneath the weight. Open the torn chart to collect the clipped coastline fragment.
3. Select a recovered fragment, rotate in 90-degree steps, and tap its board position. The coastline belongs above the shoal, with soundings below; north is upward. Incorrect placements preserve the fragment.
4. After all three fit, inspect the restored sheet or compare charts. Assembly alone does not award an interval.
5. Match the lighthouse cross, upward north arrow, and 17 October date; clip the sheets. The red trace crosses the transect in interval band 3.
6. Reopen the preserved composite in the map notebook. P02's zero remains a separate future observation, and this preview does not advance to P04 or complete Tide I without it.

The host saves acquisitions, seated pieces, selected fragment and its rotation, comparison settings, completed evidence, and observed map versions inside its existing save file. Older P01 saves still load. Reset P01 is a lamp-only review control; it retains map progress. All three source fragments and the restored sheet derive from the same SVG geometry in `tools/build_maps.py`.

## Integration boundaries

- `scripts/maps/map_viewer.gd`: a clipped image surface using Godot Control and TextureRect, independent of puzzle state.
- `scripts/maps/map_progress.gd`: validated, serializable puzzle state; it owns no files, scenes, inventory framework, or global tides.
- `scripts/maps/map_workbench.gd`: native Godot buttons and the two preview inspection contexts. The host supplies progression state and saves its change signal.

This is an extension of the asset harness, not a production adventure framework. Popochiu's global custom-data hooks can carry `snapshot()` / `restore()` when the full adventure runtime is adopted. The workbench still needs final prop animation and drawer/weight art, and the Chart Room uses its arrival plate at every review weather setting. Later weather layering, audio, P02, P04-P05, native exports and actual iPad testing remain outstanding.

## Verification

Run `python3 tools/build_maps.py` to rebuild the nine map images from their SVG geometry using Inkscape, then rebuild and validate the manifest. Headless checks are `tests/p01_smoke.gd` and `tests/maps_smoke.gd`. The latter exercises UI buttons, gesture handling, recoverable failure paths, compound-puzzle completion, save/resume, legacy saves, and historical evidence.

`tests/maps_render.gd` requires a real renderer. The GitHub workflow uses Xvfb and software OpenGL and is intended to exercise native mouse/touch event dispatch and capture five review screens in a `map-review` artifact. At baseline commit `85639ff`, it failed on the first Office map click before any capture; rendered input and layout are not yet verified. See [CODEX-HANDOFF.md](CODEX-HANDOFF.md) for the failure record and next steps. Passing headless tests does not establish native event delivery or actual iPad/Safari behavior.
