# The Ninth Tide: Codex implementation handoff

**Prepared:** September 7, 2026  
**Purpose:** Continue the game implementation in Codex while Mike and the graphics conversation continue creating and reviewing artwork.  
**Code baseline:** `85639ffee679f5737a57a72b2f2e08a2bb7a5e0a`. This handoff and accompanying documentation updates are newer; they do not fix the code issues described below.  
**Spoilers:** Includes opening puzzle solutions and later story mechanics.

**Art update, September 7:** The accepted Listening Room v4 reference and its generated/authored asset pack are now documented in [Listening Room assets](listening-room-assets.md), [inventory](listening-inventory.md), [placement/state manifest](../assets/listening/manifest.json), and [composed review](../art/listening-review/composed/index.html). These art additions do not change the code baseline or resolve the rendered map-input failure below. Use asset status and review notes when integrating; the gallery is not a running Godot room.

**Kitchen art update, September 7:** Mike approved [Kitchen master v1](../art/concepts/kitchen-room-master-v1.png). The complete [R05 graphics handoff](kitchen-room-assets.md) specifies P07/P09 evidence and visual states, with [84 local PNG assets](kitchen-inventory.md), 78 editable SVG sources, seven reused R04 weather plates, a [measured manifest](../assets/kitchen/manifest.json) and [offline art gallery](../art/kitchen-review/composed/index.html). Nora's physical repaired cup stays in R06; the Kitchen provisioning page supplies the corresponding repair sketch. These art additions do not implement R05 or change the dated code baseline below.

## 1. Start here

The project already contains a Godot prototype, approved Office references, a new Chart Room concept, and implemented P01/P03 puzzle logic. Continue from this work. The immediate task is to resolve the failing rendered map-input test, verify the actual interface, and produce the first local-network Web preview for an iPad.

| Item | Location or decision |
| --- | --- |
| Repository | [H4z3W4z/the-ninth-tide](https://github.com/H4z3W4z/the-ninth-tide) |
| Active development branch | `art/chart-room-master-v1` |
| Draft PR | [PR #1: map inspection and Chart Room assembly](https://github.com/H4z3W4z/the-ninth-tide/pull/1) |
| Main at handoff | `f99e50d0adf1f20ec39ea49162733c908fabc897`; does not yet contain this branch's map work |
| Runtime | Godot **4.5.1**, GDScript, Compatibility renderer |
| Entry point | `project.godot` → `intake_preview.tscn` → `intake_preview.gd` |
| First delivery target | Landscape iPad, browser build served over the local network |
| Subsequent targets | Native iOS and Android from the same game project, validated early |
| Current release status | Prototype only; no tested Web export or native device build |

Read `AGENTS.md`, this document, `README.md`, `docs/design/game-design.md`, and `docs/art-direction.md` before editing. The GDD is version 1.4 and contains the complete proposed game, including all 27 puzzles. Version 1.3 updated Listening Room art staging; version 1.4 keeps Nora's physical cup in the Bunk Room and uses its provisioning-page sketch in the Kitchen. These revisions do not change puzzle solutions, dependencies or ending consequences. This handoff describes what exists in code and where to resume. It does not replace the full design.

For a fresh checkout:

```sh
git clone https://github.com/H4z3W4z/the-ninth-tide.git
cd the-ninth-tide
git switch art/chart-room-master-v1
git status --short
```

For an existing checkout, inspect uncommitted work before switching or integrating changes. Fetch the current branch and review the current PR state; the hashes here are a dated baseline. Create follow-up implementation branches from the active map branch while it remains unmerged. Preserve both code and incoming artwork when integrating. Do not merge the draft merely because a handoff exists.

## 2. Division of work

**Codex owns implementation:** input, scenes, puzzle state, save/load, evidence, exact diagrams and text, asset placement, animation wiring, audio integration, tests, build tooling, Web serving, and native export preparation.

**The graphics conversation owns generated artwork and visual review:** room masters, prop illustrations, weather variants, anomaly concepts, and artistic revisions with Mike. Continue graphics there. Codex should prepare precise asset briefs when a missing illustration blocks final presentation and can use clearly documented temporary controls to keep logic work moving.

User-approved direction persists. Preserve the flat composition, distinctive palette, important windows, and progressive environmental horror. Do not start a fresh art style or independently regenerate approved rooms. Mike's latest instruction is specifically to move coding into Codex and keep generating graphics in the existing conversation.

## 3. Game context and fixed decisions

*The Ninth Tide* is an original illustrated point-and-click cosmic horror mystery. Ada Mercer arrives to close Greywake Survey Station on Morrow Sound in October 1931. Restoring instruments gradually reveals that something beneath the station is learning to locate its observer. Elias Venn's records, Nora Bell's domestic evidence, and Rook's classification machinery establish the human stakes.

The target is a **150–210 minute first playthrough**, planned around three hours, with **12 locations, 27 mandatory puzzles, nine story tides, and two informed ending choices**. Duration is a design target awaiting playtests. The earlier phrase “3 houses” was interpreted in the GDD as three hours. Do not restructure the game into three houses.

Core rules:

- Solving a puzzle gives a useful answer and a more disturbing understanding of the station.
- Tides advance through explicit puzzle milestones. They are not a real-time clock.
- All rooms respond to progress, including rooms without windows. Clues and controls remain legible.
- Puzzles are deterministic, with recoverable mistakes and stable evidence. No combat, timed reflexes, pixel hunting, arbitrary item combinations, or sanity meter.
- Previously observed evidence survives changes in the world. Never destroy a clue when an animation or weather state changes.
- Every actual map/chart prop in a playable view is inspectable, including atmosphere-only maps.
- Use generous touch targets, keyboard focus, transcripts, visible rotation/zoom controls, and alternatives to dragging. Hint use never changes endings.
- The station records authored in-game actions. It never reads the player's real name, microphone, device data, or other private information.

The full location list is Jetty, Intake Office, Chart Room, Listening Room, Kitchen and Mess, Bunk Room, Wet Laboratory, Machine Room, Lantern Gallery, Records Vault, Dry Stair, and Observation Chamber. Only the Office and Chart Room workbench currently have implemented interaction views.

## 4. What exists and what is still missing

| Area | Implemented at the baseline | Remaining work or limitation |
| --- | --- | --- |
| P01 Office lamp | OFF → bridge B → ON; rejection feedback; illuminated lamp; saved completion and note | Full keyboard focus for original canvas controls; rendered/device verification |
| Map inspection | Office map entry, zoom 1–4, Fit, pan, transcripts, native toolbar buttons, keyboard and gesture handlers | Native event dispatch is not yet verified; rendered test currently fails |
| P03 workbench | Three fragment pickups, step rotation, assembly, reference comparison, interval 3, notebook composite | Final drawer/weight art and interaction polish; three-tier hints; rendered QA |
| Persistence | Acquired/placed fragments, selected piece and rotation, comparison settings, evidence versions, solved state; old P01 saves accepted | Production save service, backups/checkpoints and browser persistence validation |
| World presentation | Office arrival, gathering-rain and ominous plates; independent review controls | Real tide progression across rooms; Chart Room currently has only arrival art |
| Later map change | Alternate Office map asset/state and historical version preservation | P21 trigger is absent; changing review weather must not activate it |
| Other puzzles | Complete design in GDD | P02 and P04–P27 are not implemented |
| Audio | Written design | No runtime audio assets or audio implementation |
| Export | Shared Godot project structure | No Web package, LAN iPad test, native iOS or Android build |
| Adventure framework | Small puzzle-specific harness; isolated Popochiu trial | No adopted inventory/dialogue/room framework or production save layer |

The code baseline contained **35 runtime PNGs and 30 editable SVG sources**, including nine authored map PNG/SVG pairs. Later art additions increase the repository inventory; consult the current manifests rather than treating these historical counts as the present total. The new R04 pack supplies illustrations and exact graphics while P02/P17/P19 remain unimplemented.

## 5. First task: repair and verify rendered input

Baseline CI evidence:

| Check | Result |
| --- | --- |
| Asset integrity, 35 PNGs | Passed locally and in CI |
| Godot 4.5.1 headless import | Passed |
| `tests/p01_smoke.gd` | Passed locally and in CI |
| `tests/maps_smoke.gd` | Passed locally and in CI |
| `tests/maps_render.gd` | **Failed on the first Office map click** |
| Five rendered review screenshots | Not produced; execution failed before the first capture |
| Physical iPad/Safari and native devices | Not tested |

Failure record: [Validate map interactions, run 34081911670](https://github.com/H4z3W4z/the-ninth-tide/actions/runs/34081911670), job `101618666086`, baseline head `85639ff`.

```text
SCRIPT ERROR: Assertion failed: Rendered wall-map hotspot opens viewer
at: run_capture (res://tests/maps_render.gd:34)
```

The CI renderer initialized successfully using Mesa llvmpipe under Xvfb. The script then failed at the first synthetic native mouse click. The assertion stopped its coroutine without terminating Godot, so the enclosing 90-second timeout exited with code 124. The missing screenshot artifact is a consequence. Audio-driver and VSync warnings were not the recorded assertion failure.

Investigation starting points, not confirmed causes:

1. `tests/maps_render.gd` sets the root to 1448 × 1086, loads a fresh scene/save, and injects a mouse button event at `(240, 300)` using `Input.parse_input_event()`.
2. The Office map hotspot is `Rect2(127, 179, 263, 290)` in the reference room coordinates.
3. `intake_preview.gd::_unhandled_input()` reads `get_global_mouse_position()` rather than the event position. Determine whether the synthetic event updates that position and whether viewport/window scaling changes the expected coordinates. Test a physical mouse too. The failure alone does not establish that a user's physical click is broken.
4. Trace native event routing and Control mouse filtering. After fixing the first click, test whether `InputEventScreenTouch` and `InputEventScreenDrag` reach `map_viewer.gd::_gui_input()` as expected. Unit calls to the handler do not prove real dispatch.
5. Check two-finger gesture cleanup when a touch ends outside the pane or focus is lost, and interaction with touch-to-mouse emulation. Avoid duplicate drag or zoom responses.

Make the render harness exit nonzero promptly on a failed requirement. Keep a meaningful real-input regression: do not replace the failing click with `scene.dispatch("office_map")`, directly emit a button signal, or remove the assertion merely to get green CI. Direct state setup remains useful for later screenshot fixtures, but it is not proof of a full player walkthrough. Adding `--audio-driver Dummy` to the CI command can remove irrelevant audio noise.

The headless map test exercises state transitions and calls buttons/handlers directly. Its passing result is useful but does not establish rendered hitboxes, native touch delivery, text layout, or browser usability.

Once input works, produce and inspect the intended captures: `office-map-zoom`, `chart-room`, `partial-assembly`, `completed-comparison`, and `notebook-composite`. Check map overlays against their room frames, text clipping, fragment seams, visible failure feedback, button sizing, and clue readability. The Office map overlay's aspect ratio particularly needs a visual check.

## 6. Code and save architecture

| File | Responsibility |
| --- | --- |
| `intake_preview.gd` | Node2D Office host, original drawn controls/hitboxes, P01, weather review, map overlay lifecycle, save/load |
| `scripts/maps/map_viewer.gd` | Clipped Control/TextureRect image viewer; zoom, pan, overlay transform, input handlers; independent of puzzle state |
| `scripts/maps/map_progress.gd` | RefCounted puzzle state; acquisition, placement, alignment, observation IDs, validation, `snapshot()` / `restore()` |
| `scripts/maps/map_workbench.gd` | Native Godot buttons and Office/Chart Room inspection modes; receives progress/unlocked state, emits `changed` / `closed` |
| `tools/build_maps.py` | One deterministic geometry source for tide sheet, fragments and reference artwork; Inkscape PNG export |
| `tools/build_vectors.py` | Existing precise P01/UI vector generation |
| `tools/build_manifest.py` | Runtime PNG registry, dimensions/hashes, placements, hotspots and map-inspection metadata |
| `tools/validate_assets.py` | Asset integrity checks |
| `tests/p01_smoke.gd`, `tests/maps_smoke.gd` | Puzzle/state and programmatic UI checks |
| `tests/maps_render.gd` | Real-renderer input checks and screenshot fixtures; failing at baseline |
| `.github/workflows/validate-maps.yml` | Godot import, smoke checks, Xvfb rendering and `map-review` artifact |

Default preview save: `user://intake_asset_preview_v1.json`. It retains the existing schema-1 P01 state and stores `map_progress.snapshot()` under `state["maps"]`. This is Godot's application data directory, not a repository file. Tests use separate saves; keep that isolation.

Map state includes acquired and placed arrays, selected fragment, rotation step, anchor, north step, reference day, completion, observed evidence IDs, and current Office map version. Restore validates bounds and consistency, rejects impossible completion, and handles older saves with no map data. Selecting a different fragment starts its authored orientation; selecting the same one preserves its rotation. Review-resetting P01 intentionally retains map progress.

Do not turn these three map scripts into a general adventure engine. Keep puzzle state portable to the selected framework's persistence hooks. Production state must distinguish completion flags, puzzle arrangements, inventory, observed evidence, and presentation. Derive tides from prerequisites; never use a displayed weather index as proof that a puzzle was solved.

## 7. Opening puzzle canon and walkthrough

This is enough context to continue the opening; use GDD sections 7 and 8 for complete evidence, dependencies, feedback and later puzzles.

| Puzzle | Required solution and output | Implementation |
| --- | --- | --- |
| P01, Intake Office | Supply OFF, fit straight B, supply ON. Curved C is rejected without consumption. Unlock Chart and Listening investigations. | Implemented lamp and Chart Room gate; Listening Room still absent |
| P02, Listening Room | Bands C → A → B from START, continuous seam, play. Preserve calibration zero **4** and tomorrow's recording. | Not implemented |
| P03, Chart Room | Recover and assemble three fragments; then match lighthouse registration, upward north and date **17 October**, clip charts. Preserve interval **3** and composite. | Logic/workbench implemented; rendered verification pending |
| P04, Chart Room | Requires P02 + P03. ZERO **4**, INTERVAL **3**, CALIBRATE. Open Dry Stair threshold; pressure gate still blocks descent. | Not implemented |
| P05, Chart Room/threshold | Boundary → relation → observer, RECORD. Preserve actual last three recognized completed interactions and activate departure signal. | Not implemented |
| P06, Jetty | Inspect boat window showing Chart Room; select UNVERIFIED RETURN and ring bell **2**. Service capsule brings key and Venn note; Kitchen/Bunks unlock. | Not implemented |

P03's source fragments are coastline on the board, shoal in the unlocked chart drawer, and soundings visibly beneath the chart weight. Place upper/middle/lower with north upward. Incorrect placement or rotation preserves the piece. Assembly unlocks comparison; **assembly alone must never grant interval 3, complete P03, or advance Tide I**. Tide I requires both P02 and P03, in either order.

Current preview shortcuts: M opens the Office map, C enters the Chart Room after P01, N opens map observations. The Maps toolbar and room hotspots provide pointer routes. Native map controls support Tab/Enter; viewer controls include arrows, +/-, Home and visible buttons. Escape returns to the Office. Verify behavior through the real input path.

P05's later record must use a fixed in-game whitelist and a persisted event history; P25 reuses that record. Never fabricate actions to make the horror line work.

## 8. Art direction that implementation must preserve

Approved references:

- `art/concepts/intake-approved-calm.png`
- `art/concepts/intake-approved-ominous.png`
- `art/concepts/listening-room-approved-master-v4.png`
- `art/concepts/kitchen-room-master-v1.png`

Use flat, straight-on elevations with **no angled walls, receding tabletops or perspective camera**. Fine navy contours, matte sea-glass/sage plaster, storm/petrol blue, tarnished copper/brass, restrained brown wood, and subtle paper texture establish the identity. Rusty Lake informed tactile puzzle design and flatness; its characters, signature imagery and exact visual identity are not production assets.

Master room canvas: **1448 × 1086**, 4:3. Review at **1024 × 768**. Scale the composition uniformly and letterbox other aspect ratios; account for the transform in hitboxes. Provide a deliberate phone layout later. Dense tablet documents are not automatically usable on a phone.

**Windows are a recurring story surface.** As puzzles are solved, weather darkens, visibility falls, sea behavior becomes wrong, and the interior feels increasingly occupied when revisited. Rooms without windows use dampness, sound, shadows, reflections and object behavior. Drive these changes from GDD section 5's milestone matrix. Do not apply darkness so broadly that evidence becomes unreadable.

The Office coat is empty. Its late shadow has a head and shoulders. Preserve the discrepancy and stillness; do not add a lunging monster. Current coat/shadow imagery is baked into the ominous plate.

Office arrival/rain/ominous backgrounds were generated as separate composed plates with minor edge/texture drift. Switch on room re-entry rather than claiming perfectly registered animation or slowly crossfading all pixels. Lamp, illumination, rain and repair pieces are separate assets; most furniture is baked.

Current Chart Room source: `art/concepts/chart-room-arrival-v1.png`; runtime copy: `assets/backgrounds/chart_arrival.png`. It uses the established direction but is a **v1 concept, not an explicitly approved final master**. It has a left window/lighthouse, two central charts, recorder cabinet, dials, sockets, lever and right hatch. Authored map overlays and temporary labeled buttons supply current P03 behavior. Drawer/weight states, moving pen, weather layers and final P04/P05 controls are missing. Generated ticks and marks must not become exact puzzle clues.

Listening Room v4 uses a hornless wax recorder, hooked headphones, a small used noticeboard, a specialized oak bench and the right-hand weather window. Earlier speaking-tube and horn studies are superseded. Keep `r04_clean_base.png` fixed and clip only the glazing from `r04_weather_*` plates. Their partially assembled recorder is part of the visual study; it must never override saved P02 arrangement. Use separate props and authored band layers, with local damp/light effects. Generated alternate poses are references or discrete state swaps, not registered animation frames.

R04 composition order is fixed room → clipped exterior/door details → local effects behind props → props/papers and puzzle pieces → exact control overlays → inspection/focus UI. The manifest records source regions and placement; transparent canvas margins are not hitboxes. Tide IX holds weather appearance eight. The P17/P19 calibration faceplate belongs to an inspection view, not a new wall apparatus. Keep Venn and Nora's channels separately selectable with transcripts, and preserve Venn's P19 continuation through the headphones after the indicator goes dark. See the R04 handoff for complete triggers, document gates and reuse rules.

Kitchen and Mess uses a fixed room base, with shared R04 weather sources mapped into its own window glazing. It opens after P06 at weather appearance two. Preserve the table's separate bowl arrangement and spoon, pantry drawer, paired-token state and correction board independently of weather. P07 compares nine portions against the unchanged official eight. P09 requires both P07 and P08, appends `+1 / VENN / present`, uses the three-cut seal and retains the duplicate board's text before condensation. The physical repaired cup remains on its R06 shelf; the square-patched Kitchen bowl is a different object. See the R05 handoff for exact asset and evidence contracts.

## 9. Graphics-to-code asset contract

Keep originals in `art/concepts/`, runtime content under `assets/`, and generation provenance/production notes under `docs/`. Keep revision history and preserve approved originals. `docs/generation-prompts.json` records the earlier set; `docs/chart-room-generation-v1.json` records the Chart Room master.

Generated illustrations provide the surfaces and atmosphere. Exact clue text, numbers, symbols, hotspots and geometry come from SVG or runtime text. Keep SVG sources beside PNG exports. The nine current map assets live in `assets/maps/`; fragment shapes and completed sheet must continue to derive from one geometry source. Current map canvas is 1200 × 900. Do not independently regenerate fragment coastlines or rely on magnifying tiny generated map marks. R04 already includes authored documents, band orientations, channel controls and timing diagrams from `tools/build_listening_vectors.py`; integrate these existing sources before creating replacements. Its `authored-spec.json` defines the sole correct C/A/B step-0 arrangement. Timing diagrams must be matched to future audio and are not extracted voice waveforms.

For each missing image, return a short brief to the graphics conversation using this template:

```text
Asset ID / proposed path:
Room and puzzle IDs:
Purpose and required states:
Reference image and revision:
Canvas size / crop / placement rectangle:
Transparency needed:
Parts that must remain fixed:
Movable parts / pivot / occlusion requirements:
Exact text or geometry Codex will add separately:
Acceptance view and readability requirement:
```

For room-aligned overlays, specify the full 1448 × 1086 canvas or an exact crop rectangle, so registration is reproducible. Transparent props need real alpha; checkerboard pixels are not transparency. State whether an export is a concept, approved illustration, or integrated runtime asset. A generated master alone does not imply animation-ready layers.

Remaining graphics briefs beyond the R04 pack, subject to Mike's review:

1. **Chart Room P03 integration:** visible chart drawer open/closed, weight and revealed paper, torn-chart board presentation. Keep the existing window, cabinet and hatch positions. Codex supplies the exact map faces.
2. **Chart Room P04/P05:** recorder close-up, separate control/lever positions, sockets, pen/paper and closed/open hatch. Codex supplies ZERO/INTERVAL values, symbols and recorded text.
3. **Chart Room environmental layers:** fixed-geometry window/exterior states, rain/reflections and restrained anomalies, using GDD milestones. Do not independently regenerate all room geometry for nine tides.
4. **Listening Room integration review:** use the v4 master and existing pack first. Report specific missing crops, states or readability defects from a rendered implementation rather than requesting a replacement master. Keep P02 arrangement independent of weather and honor document visibility gates.

When importing a batch: inspect dimensions/alpha and approval status; retain sources; integrate placement and state; rebuild the manifest; run asset validation; render the affected view at reference size. Report missing parts with the brief above. Do not wait for final art to investigate input or implement deterministic puzzle logic.

## 10. Reuse existing open-source infrastructure

Mike explicitly requested reuse. Godot, Inkscape, Python standard-library tooling, and Git are already used. Read `docs/open-source-reuse.md` before building inventory, dialogue, room transitions or production saves.

**Popochiu remains a candidate.** The prior isolated trial imported v2.1.1, commit `784d1474ef5fe79285a9da69d550504692a3f7e3`, with Godot 4.6. A second editor boot completed without script errors after initial resource warm-up errors. Save/load code was inspected: custom `Globals.on_save()` / `Globals.on_load()` hooks offer a potential adapter for map snapshots. No Popochiu code is integrated in this project.

Before adopting it, demonstrate fixed first-person room interaction without a walking avatar, touch inventory-on-hotspot use, custom tide/evidence persistence and Web behavior. Pin the compatible engine/framework versions and migrate deliberately if the trial succeeds. Do not silently switch the current project to Godot 4.6 or claim the isolated import validated a full game. Record the adoption decision and retain required licenses. The game's public repository currently has no project license; public visibility does not license its artwork for reuse.

## 11. Build and validation commands

Use Godot 4.5.1 first. Install Python 3 for validation; Inkscape and DejaVu Sans are needed only when rebuilding the authored assets. Committed PNGs are sufficient to import and run. Engine binaries and import caches stay outside Git.

From the repository root:

```sh
godot --version
python3 tools/validate_assets.py
godot --headless --path . --editor --import
godot --headless --path . --script tests/p01_smoke.gd
godot --headless --path . --script tests/maps_smoke.gd
godot --path .
```

For precision-art changes:

```sh
python3 tools/build_vectors.py
python3 tools/build_maps.py
python3 tools/build_listening_vectors.py
python3 tools/build_listening_manifest.py
python3 tools/build_listening_review.py
python3 tools/build_kitchen_vectors.py
python3 tools/build_kitchen_manifest.py
python3 tools/build_kitchen_review.py
python3 tools/build_manifest.py
python3 tools/validate_assets.py
```

For the rendered regression on Linux with Xvfb and a working display/socket environment:

```sh
LIBGL_ALWAYS_SOFTWARE=1 timeout 90 xvfb-run -a -s '-screen 0 1600x1200x24' godot --path . --script tests/maps_render.gd
```

This last command reproduces the failing baseline; it is not expected to pass until repaired. With a physical desktop display, run the script directly through Godot instead of Xvfb. Screenshots belong in ignored `build/map-review/`. The prior graphics workspace could run headless checks but could not create display sockets, so real rendering was attempted in GitHub Actions. Use a normal desktop or CI for that verification.

CI pins `chickensoft-games/setup-godot` to `c233594225991af5aec714e52457cc76d6df8fa2` and installs Godot 4.5.1 without export templates. Match export templates to the engine when creating builds. Never commit signing material, credentials, exported packages, engine binaries or `.godot` caches.

## 12. Delivery sequence and acceptance gates

### A. Make the existing prototype dependable

Fix native input and fail-fast rendered checks. Produce the five screenshots and review actual layout. Walk through P01 and P03 with physical pointer input, wrong choices, close/reopen, and restart during partial assembly. Verify historical evidence and that review weather never advances puzzles. Retain the passing state regressions. Report any remaining device limitations plainly.

### B. Deliver the first LAN iPad Web preview

Create a reproducible Web export preset with Compatibility rendering and threads disabled as the initial target. Include the runtime manifest and required resources; exclude development/reference folders. Document export and local serving commands and the LAN URL pattern. Verify the pinned Godot documentation for the actual browser, hosting and persistence requirements before configuring the server; do not assume a desktop import proves Web compatibility.

Test on the target iPad: first load, landscape layout, taps, zoom/pan, scrolling conflicts, partial puzzle save, reload, app switching, suspend/resume and reopened evidence. Record device/OS/browser and build commit. Audio unlock/resume needs a separate check once audio exists. If hardware is unavailable, deliver the build and exact test steps, and mark physical-device validation pending.

### C. Choose the adventure framework and complete the opening slice

Run the bounded Popochiu adoption trial before expanding shared infrastructure. Then implement P02 and P04–P06, navigation through R01–R04 and the stair threshold, production persistence, release HUD, accessible controls and initial audio. Confirm both P02/P03 completion orders. Integrate graphics batches without changing puzzle canon. The opening target is roughly 35 minutes, awaiting player observation.

### D. Validate native export early

After the initial Web path works, build early Android and iOS versions before producing all rooms. Record SDK/export/signing prerequisites and real-device results. Obtain required signing through the user's normal local setup; keep it out of Git. Maintain shared gameplay/state code and isolate platform-specific behavior. Avoid a separate browser implementation that would require recreating every puzzle for mobile.

### E. Expand against the full GDD

Proceed tide by tide with dependency checks, evidence persistence, all-room environmental reactions, representative art/audio and playtests. Do not call the full design implemented because the opening harness runs. Preserve 12-location/27-puzzle scope unless Mike approves a design change.

For each completed code milestone, report the branch/commit, concrete behavior, checks that passed, known failures, tested devices, and the next requested graphics batch. Update this handoff's status when its baseline becomes stale.

## 13. Prompt to start the next Codex session

> Continue The Ninth Tide from the current `art/chart-room-master-v1` branch or its merged successor. Read `AGENTS.md` and `docs/CODEX-HANDOFF.md`, then the linked design and art documents. First fix the rendered Office map input regression and verify the P01/P03 interface through real input. Next produce the local-network Web preview for an iPad, documenting actual device validation separately. Preserve the approved artwork, map evidence, deterministic puzzle solutions, and progress-driven room changes. We are continuing generated graphics in the existing conversation; provide precise missing-asset briefs and handle code/integration here. Evaluate the documented open-source adventure framework before building equivalent infrastructure. Keep changes reviewable and report tests and limitations accurately.
