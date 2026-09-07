# Reuse before rebuilding

**User instruction:** Use suitable open-source work instead of recreating solved infrastructure.

## Already used

| Component | Reused capability | Status |
| --- | --- | --- |
| Godot | Renderer, scene/resource system, image importer, input dispatch, platform file access, timers | Preview imports and runs under Godot 4.5.1; actual mobile exports pending |
| Inkscape | SVG rendering and raster export | Used for the precise puzzle graphics and review composition |
| Python standard library | Manifest generation, checksums, structural validation | Used; no custom image codec or build system |
| Git | Version history and repository packaging | Local scaffold; owner-created GitHub remote available |

## Preferred adventure-framework candidate: Popochiu

[Popochiu](https://github.com/carenalgas/popochiu) provides an adventure runtime and editor tools for rooms, props, hotspots, inventory, dialogue, save/load, transitions and audio management. Its [MIT license](https://github.com/carenalgas/popochiu/blob/v2.1.1/LICENSE) is recorded upstream. The [v2.1.1 release](https://github.com/carenalgas/popochiu/releases/tag/v2.1.1) was published May 23, 2026; its tagged README targets Godot 4.6. The README's prose still calls 2.1.0 latest, so use the actual release record for the patch version.

Status: **evaluated from primary project documentation, not installed or integrated**. Do not claim the current P01 scene uses Popochiu. It is a small asset assembly harness, not the proposed full adventure engine.

Before extending the prototype into a multi-room custom framework, trial Popochiu on a compatible pinned Godot version. Verify first-person fixed-room interaction without a walking avatar, touch usability, inventory-on-hotspot behavior, preservation of custom tide state during save/load, and a working Safari/iPad Web export. Adopt its existing room/inventory/dialogue/save facilities wherever the trial meets those requirements. Keep exact puzzle logic, weather milestones, notebook semantics and artwork project-specific. Avoid building parallel versions of facilities the chosen framework already supplies.

[Escoria](https://github.com/godot-escoria) is an alternative point-and-click framework, but no compatibility claim or adoption decision has been made for it in this scaffold.

## Dependency policy

Pin versions and retain required licenses for incorporated code. Add dependencies only for a concrete capability. Record what is actually used separately from researched candidates. Do not pull in multiple adventure frameworks at once. Do not import third-party game artwork as production assets merely because code is open source.

Research checked September 7, 2026 using the upstream README, license, and release metadata. Current vendored adventure-framework dependency count: zero.
