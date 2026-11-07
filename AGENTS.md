# The Ninth Tide project instructions

Read README.md, docs/design/game-design.md, and docs/art-direction.md before changing content.

- Preserve the approved flat front elevation. No angled room perspective, receding tabletop planes, or cinematic photorealism.
- Puzzle progress drives increasingly ominous environments across every room. Weather is not a real-time timer.
- Never obscure clues or move hotspots merely to darken a scene. Preserve notebook evidence after state changes.
- Keep solutions deterministic. P01 requires supply OFF, straight bridge B installed, then supply ON. Curved C is rejected without consuming anything.
- Keep generated artwork separate from exact labels and diagrams. Preserve SVG sources alongside raster exports.
- Use assets/ for runtime content, art/ for approved references, docs/design/ for narrative, and tools/ for repeatable asset operations.
- Update asset_manifest.json after asset changes with python3 tools/build_manifest.py. Then run python3 tools/validate_assets.py.
- Run the Godot smoke test for puzzle/state changes: godot --headless --path . --script tests/p01_smoke.gd after an import.
- Do not put secrets, signing material, export credentials, engine binaries, or .godot caches in Git.
- The preview's weather buttons are review controls. They must never mark future puzzles complete.
- Preserve source assets when adding revisions. Do not overwrite approved references without a documented reason.
- Store no downloaded Rusty Lake screenshots in the repo. They are research references, not game assets.
- Do not claim iPad, browser, iOS, or Android validation until tested on those targets.
- User specifically wants open-source reuse. Before implementing inventory, dialogue, multi-room transitions or production saves, read docs/open-source-reuse.md and evaluate Popochiu on a compatible Godot version. Keep the current P01 harness small; do not grow a competing adventure framework by default.

## Slice direction from the owner (Nov 2026): Rusty Lake vibe + hard cosmic dread

The office slice should **feel like a Rusty Lake room escape** while staying original IP. Panel, planners, and builders judge and build against this:

- **One dense puzzle-box room.** Nearly every object hides a small mechanism, compartment, or reveal. Close-ups are tactile contraptions (dials, drawers, latches, specimen jars, clockwork), not static documents. The room gives more each time you look.
- **Chained, interlocking puzzles.** One solution yields an item, code, or observation that opens the next. A short inventory with contextual use (item on hotspot) is expected. Each puzzle stays fair and deterministic, with no pixel hunts. The GDD's ban on arbitrary combinations still holds: combinations must be visibly motivated.
- **Deadpan surreal, macabre, quiet.** Unsettling things happen calmly, with no fanfare. Small looping animations (something ticks, drips, breathes, turns its head) carry the weirdness. Ada's lines stay short and dry. The horror is in stillness and wrongness, not noise.
- **Surreal rewards.** Solving a puzzle opens something *impossible* (a drawer deeper than the desk, a tide recorded in a jar, a portrait that has changed), and the reward is both a clue and a new wrongness.
- **Cosmic dread on top.** The Rusty Lake surface (whimsical, eerie, puzzle-box) sits over a Lovecraftian depth: a vast indifferent intelligence beneath the sea, measurement turning on the measurer, the sea as an eye.
- **Hard IP line.** Use no Rusty Lake characters, names, symbols, or signature motifs: no animal-headed people, no crows or owls as characters, no black cubes, no "memories as cubes", no Laura or Mr. Crow, and no Rusty Lake title or branding. Take the *feel and structure*, never the content. No Cthulhu Mythos names or symbols either.

### Owner decision (Nov 6 2026): painted art for later stages
New painted plates and overlays for the later, ominous stages are approved. Add them as NEW files under assets/stages/ with repeatable sources (SVG and/or a seeded tools/build_art.py); never overwrite existing approved PNGs. Match the approved flat front elevation and palette, keep every hotspot registered and legible, and keep clue marks deterministic. Later stages should read as wrong at a glance in a screenshot.
