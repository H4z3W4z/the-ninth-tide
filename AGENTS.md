# The Ninth Tide project instructions

Read README.md, docs/design/game-design.md, and docs/art-direction.md before changing content.

- Preserve the approved flat front elevation. No angled room perspective, receding tabletop planes, or cinematic photorealism.
- Puzzle progress drives increasingly ominous environments across every room. Weather is not a real-time timer.
- Never obscure clues or move hotspots merely to darken a scene. Preserve notebook evidence after state changes.
- Every actual map/chart prop shown in a playable room must support readable close-up inspection, including atmospheric maps. Preserve observed versions and partial map assemblies; use tap placement and step rotation as alternatives to dragging.
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
