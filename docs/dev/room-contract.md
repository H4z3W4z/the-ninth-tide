# Room contract

How a room team builds one of R01–R12 on the multi-room core without touching anyone
else's files. Read `AGENTS.md` (owner directions are binding), `docs/design/game-design.md`
and your room's puzzle cards in `docs/design/puzzle-cards/` first. The Intake Office (R02)
is the quality template: `game/rooms/R02/` shows every pattern below at full strength.

## 1. Your files, and only yours

```
game/rooms/<rid>/<rid>_sim.gd      room sim: state, actions, events, puzzle logic (node-free)
game/rooms/<rid>/<rid>_view.gd     room renderer: plates, hotspots, close-ups, overlays, loops
game/rooms/<rid>/<rid>_view.tscn   a Node2D with <rid>_view.gd attached (nothing else needed)
tests/rooms/<rid>_test.gd          your tests (extends tests/rooms/room_test_base.gd)
tools/art/rooms/<rid>.py           seeded PIL painter  -> assets/rooms/<rid>/*.png
tools/audio/rooms/<rid>.py         seeded stdlib synth -> assets/audio/<rid>/*.wav
```

Everything else is shared and read-only for room teams: `game/core/*`, `tests/core_test.gd`,
`tests/rooms/room_test_base.gd`, `tools/build_*.py`, `tools/audio/common.py`,
`tools/capture.gd`, `asset_manifest.json` (regenerated, never hand-edited), `project.godot`.
If you need something from the core that isn't there, ask the lead; don't patch it.

**Discovery, not registration.** Nothing lists the rooms:

| What | Finds | How |
| --- | --- | --- |
| `GameSim` | your sim | every `game/rooms/<rid>/` holding `<rid>_sim.gd` (`GameSim.discover()`) |
| `GameView` | your view | loads `game/rooms/<rid>/<rid>_view.tscn` on entry; falls back to the placeholder |
| `tools/build_art.py` | your painter | `tools/art/rooms/R??.py`, after the office painters (`python3 tools/build_art.py R05` runs one) |
| `tools/build_audio.py` | your synth | `tools/audio/rooms/R??.py`, after the office set (`python3 tools/build_audio.py R05` runs one) |
| `tools/build_manifest.py` | your PNGs | every `assets/**/*.png`; yours get ids `"<rid>/<stem>"` |
| `tools/validate_assets.py` | your PNGs | checks every PNG is in the manifest, decodes, and matches its hash |
| `GameView.load_audio(id)` | your WAVs | `assets/audio/<rid>/<id>.wav` first, then shared `assets/audio/<id>.wav` |

After changing art: `python3 tools/build_art.py <rid> && python3 tools/build_manifest.py && python3 tools/validate_assets.py`.
The manifest is a generated file: if two teams regenerate it, either result is correct; re-run the script on merge.

## 2. The sim (`<rid>_sim.gd`)

`class_name <rid>Sim`, `extends RoomSim`. Node-free and deterministic: no `Time`, no
`randf`, no timers, no nodes. Weather and tide state come from puzzle progress, never a clock.

### Constants the core reads

| Constant | Meaning |
| --- | --- |
| `ID`, `TITLE` | `"R05"`, `"Kitchen and Mess"` |
| `REQUIRES` | flags that must all be set to enter, e.g. `["P06"]` (GDD §5 gates; already set in your skeleton) |
| `LOCKED` | what Ada says at the locked way in (override `locked_line()` for more) |
| `RESUME` | the line on loading a save in this room ("Back in the kitchen.") |
| `ARRIVAL` | one line on the first visit (override `arrive()` for more) |
| `EXITS` | `[[to_rid, label, extra_flags], ...]` — ways out; the target's `REQUIRES` also apply |
| `HOTSPOTS` | the room-view hotspot ids (actions) |
| `OBSERVATIONS` | `{id: notebook text}` — every observation this room can record |
| `OBJECTIVES` | `{objective_id: one-line goal}` shown in the notebook |
| `HINTS` | `{objective_id: [location nudge, relationship, explicit solution]}` |
| `ITEMS` | `{item_id: {"name": ..., "desc": ...}}` — items this room hands out |

Exits are already wired to the GDD topology and tested in `tests/core_test.gd`; changing a
room's exits is a design change for the lead, not a room-team edit.

### State

`state` is your room's dictionary. It *is* `game.state.rooms[ID]`, so it saves with the game.
Return the fresh state from `initial_state()`; keep it JSON-safe (bools, ints, strings, arrays,
dicts). Puzzle-local arrangements (dial positions, placed plates) live here. Override
`load_state(d)` to validate a saved dict field by field (R02's is the model: clamp numbers,
accept only known ids, then make derived flags agree), and `reconcile()` to set or clear the
global flags you own from your state (R02 sets `P01` from `p01_complete`).

`local_view` is where the room is looking: `"room"` or one of your close-up ids. It is never
saved: a load always lands in `"room"`. Override `is_closeup(v)` if a view is not a close-up.

### Actions and events

The core calls `act(action, ev)` for anything that isn't a core action. Append events, never
play anything yourself:

```gdscript
_say(ev, "The seat is wet. Still warm underneath.", 0.0, true)   # text, delay s, story
_sfx(ev, "knock_glass", 3.4)                                      # one-shot, delay s
_fx(ev, "lamp_on")                                                 # your view's play_fx()
```

Delays are seconds after the click. `story = true` marks a reveal chain line: the player
advances it by clicking, it is never dropped or interleaved, and nothing new starts while it
plays. Feedback lines (`story = false`) are short and replaceable.

Other hooks: `back(ev)` (Back from a close-up; default returns to `"room"`), `arrive(ev, first)`,
`exit_block(to)` (return a line to keep her in the room; R02 latches its doors during the
report), `on_core_return(from, ev)` (back from the notebook or menu), `hint_frozen()`.

### Global state (cross-room API)

| Call | Use |
| --- | --- |
| `game.flag(name)` / `game.set_flag(name, on)` | cross-room facts, spelled as in `flags.md`. Puzzle flags are `"P01"`..`"P27"` (the cards' `"p07_complete"` is the same flag; both spellings work). Core globals: `closure_report_filed`, `t1x_threshold_crossed`, `t1x_turned`, `o01_found`..`o06_found`. Room facts another room may read are `"<rid>.<name>"`. `set_flag` refuses (and reports) any other name; unknown names are dropped on load. |
| `game.solve("P07", ev)` | mark a puzzle (or a transition flag, e.g. `"t1x_threshold_crossed"`) complete. Idempotent; emits `{fx: "tide"}` when the tide advances (the core shows the tide card). Never set a P flag directly. |
| `game.tide()` / `game.tide_done(n)` | current tide 1..9 and the cards' `tide_done(n)` (`flags.md` §1: I = P02+P03, II = P06, III = P09, IV = P12, V = P15, VI = P17+P18, VII = P21, VIII = P24, IX = P27). Tide II begins only on `t1x_threshold_crossed`. `tide()` holds 9 after P27. |
| `game.weather_band()` | station-wide weather band 0..7: the count of tides II..VIII done (`rooms.md` header; IX holds 7) |
| `game.plan_unlocked()` / `game.room_open(rid)` | the notebook plan (P05); a room's way in (its `REQUIRES`) |
| `game.give(item, ev)` / `game.take(item)` / `game.has_item(item)` | inventory |
| `_observe(id)` / `has_seen(id)` / `seen()` | notebook (your room's page) |
| `game.has_seen("R03", "curve")` | read another room's notebook page |
| `game.record_move(id)` | record one of the twelve whitelisted movement events (`flags.md` §3, `GameSim.MOVES`) when its action succeeds. Consecutive duplicates collapse; the last 8 are kept. Anything else is refused. `GameSim.move_text(id)` is the recorder's printed line. |
| `game.freeze_p05_trace()` | R03 only, at P05's RECORD: stores the last three movement events as `p05_trace`, once; later calls return the stored value |
| `game.value(id)` | the cards' non-bool values: `"p05_trace"`, `"movement_events"`, `"ending_choice"` (`""`, `"sever"`, `"continue"`), `"endings_seen"` (saved with the settings; survives New game). Returns copies. |
| `game.finish("sever" \| "continue")`, `game.save_checkpoint()` | R12 only: sets `ending_choice`, shows the end card; the pre-ending checkpoint |

### Tide-state hooks

Every room must visibly and audibly respond to the shared progression (GDD §5). Read
`game.weather_band()` and your own state in the view each frame; never store weather. Revisits show
the latest state directly. Keep every clue, hotspot and document legible at the darkest stage:
dread comes from what is clearly seen being wrong, not from darkness.

### Inventory use

Select-item-then-target is handled by the core: the player clicks an inventory slot
(`"item:<id>"`), then a hotspot. The core then calls `use_item(item, target, ev)` instead of
`act()`. Return `true` if you handled it (say the consequence, `game.take()` consumed parts,
`_observe()` the installed record); return `false` and the core says the generic refusal and
keeps the item. Prefer a specific, relevant observation for wrong targets in your room (GDD §6):
handle them and return `true`. Nothing essential may be destroyed by a wrong use.

### Notebook entries

Every critical clue becomes an `OBSERVATIONS` entry the moment it is seen, worded so it can be
reopened and reasoned from later. Observations are never removed. The notebook shows a page per
visited room, the current objective (`objective()` → `OBJECTIVES`), and the station plan after P05.

### Hint ladder

`objective()` returns the current objective id. `HINTS[objective]` holds three levels: a location
nudge, the relationship to consider, the explicit solution. The core advances the ladder per
room+objective and restarts it when the objective changes. Override `hint_line(level)` /
`hint_frozen()` for scripted moments (R02's threshold).

### Debug

`debug_prepare(t)`: put local state where real play leaves it at the start of tide `t` (the core's
`debug_tide()` calls it on every room). Optionally `debug_jump(n)` for your own stages (R02: 0-5).
In a debug build, F1 shows hotspots and exits; 1-9 jump your room's stages; Shift+1-9 jump to the
start of tide I-IX.

## 3. The view (`<rid>_view.gd` + `.tscn`)

`extends RoomView`. The game scene sets `game`, `sim`, `rid`, adds the node to the world layer
(layer 0) and calls your hooks. Present only; never mutate story state.

### Hotspot rect conventions

- Logical canvas 1448×1086, origin top-left, flat front elevation, native plate size.
- `HOTSPOTS := [[id, Rect2, label], ...]`: first match wins, so list small objects before the
  larger ones they sit on. Labels are the hover names.
- At least 64×64 (touch). Keep clear of the HUD: `Rect2(940, 0, 508, 80)` (Back, Notebook, Hint,
  menu), the inventory strip `Rect2(0, 0, 940, 80)` and the subtitle slab `y >= 994`.
- `EXIT_RECTS := {to_rid: Rect2}`: the core draws exits as tabs on the HUD layer (legible in any
  light). The skeletons put them along `y = 922..986`; keep hotspots out of exit rects.
- Register rects to the art and never move a hotspot to darken a scene (AGENTS.md).
- `room_test_base.gd`'s `view_checks()` enforces all of this.

### Hooks

`tick(dt)` (every frame), `apply_instantly()` (snap to state on entry, load, jump),
`reset_presentation()`, `play_fx(id, e)`, `on_sfx(id)`, `on_sfx_pending(id, left)`,
`action_at(p)` (your close-ups' controls), `hover_at(p)`, `label_for(id)`, `back_visible()`,
`chain_gates()`, `hud_hidden()`, `esc_action()`, `exits_active()`, `draw_hud(c)`, `dev_rects()`.
Draw with `Ink` (`game/core/ink.gd`): palette, fonts, `button`, `text`, `wrapped`, `handwriting`.
Close-ups go on your own `CanvasLayer` at layer 5 (R02 does this); the core's notebook, menu and
title are on layer 8, the tide card 9, the HUD 10.

### Sound

One-shots come from sim `sfx` events; list levels in `SFX_DB`, the sudden ones in `SFX_SOFT`
("Soften sudden sounds" cuts them by 12 dB, or `SFX_SOFT_CUT[id]`). Ambient loops: a
`LoopMixer` child (`game/core/mixer.gd`), `add_loop(id, game.load_audio(id))`, and `tick(targets,
rates, dt)` each frame with targets computed from state. Respect `motion` (Motion & flicker) and
`soft_audio`; every flicker and animation needs a still alternative.

## 4. Tests (`tests/rooms/<rid>_test.gd`)

`extends "res://tests/rooms/room_test_base.gd"`; override `run_tests()`; keep calling
`skeleton_checks()` and `view_checks()`. Add a test per puzzle and beat: the solution, every
documented failure, idempotent re-commits, save/load mid-puzzle, both orders of a parallel pair.

**Cross-room prerequisites by setting flags, not by playing other rooms:**

```gdscript
var g := with_flags(["P06"], "R05")      # a started game in R05 with only P06 set
var g := game_at(3, "R05")               # the start of tide III, every earlier room prepared
g.dispatch("bowls")                      # then play your room's actions
check(g.flag("P07"), "the table for nine solves P07")
```

Run: `godot --headless --path . --script tests/rooms/<rid>_test.gd` after
`godot --headless --path . --editor --import`. The whole suite (every `tests/*.gd` and
`tests/rooms/*.gd`, plus `python3 tools/validate_assets.py`) must stay green.

## 5. Art and sound sources

- New files only, under `assets/rooms/<rid>/` (art) and `assets/audio/<rid>/` (sound). Never
  overwrite approved PNGs in `art/`, `assets/backgrounds/`, `assets/props/` or `assets/stages/`.
- Painters: Python 3 + PIL 10.2 only (no numpy, cairosvg or rsvg; Godot can rasterize SVG via
  `Image.load_svg_from_string`). One fixed seed per asset, no wall clock, byte-identical reruns.
- Flat front elevation at 1448×1086, approved palette (navy ink contours, matte colour, paper
  texture, sea-glass green, storm navy, tarnished brass, restrained brown), stark flat silhouettes
  over fussy rendering. Judge art in in-game captures, not as raw PNGs.
- Sound: seeded, standard-library synthesis with `tools/audio/common.py`.

## 6. Screenshots

```sh
DISPLAY=:0 godot --path . --fixed-fps 60 --disable-vsync --script tools/capture.gd -- .panel/<you>/caps shots.json
```

`shots.json`: `[{"name": "kitchen_t3", "room": "R05", "actions": ["@tide:3", "@enter:R05", "bowls"], "mouse": [700, 500], "settle": 1.5}]`.
`@N` is your room's `debug_jump(N)`; `@tide:N`, `@enter:RID`, `@seen`, `click:X,Y` are described in
the tool's header. Scratch files go under `.panel/<you>/` (git-ignored).

## 7. Traversal (GDD §5), as built

| Room | Enter when | Exits |
| --- | --- | --- |
| R01 Jetty | always | R02 |
| R02 Intake Office | always | R01, R03, R04, R05, R06 |
| R03 Chart Room | P01 | R02, R04, R11 |
| R04 Listening Room | P01 | R02, R03 |
| R05 Kitchen and Mess | P06 | R02, R06, R07, R08 |
| R06 Bunk Room | P06 | R02, R05 |
| R07 Wet Laboratory | P09 | R05, R08, R10, R11 (that door needs P12) |
| R08 Machine Room | P09 | R05, R07 |
| R09 Lantern Gallery | P12 | R11 |
| R10 Records Vault | P15 | R07 |
| R11 Dry Stair | P04 (the threshold; descent needs P12) | R03, R07 (P12), R09, R12 |
| R12 Observation Chamber | P24 | R11 |

The passage strips of `rooms.md` (`strip_upper`, `strip_service`, `strip_lower`) are the
lateral exits R03-R04, R05-R06 and R07-R08; until the lead builds the shared strip view, the
exit tabs stand in for them. Exits are tested against this table in `tests/core_test.gd`.

**Not yet as carded (R02 team):** the slice still runs the Tide I transition before P02/P03
and its `exit_block` keeps R03/R04 shut until the threshold. The cards re-time it (section 8).

## 8. From the puzzle cards to code

The cards in `docs/design/puzzle-cards/` are the design contract: the card wins on game design,
this file wins on file layout and API. Before writing a line, read `README.md` (conventions,
cast, golden path), `flags.md`, your room's section of `rooms.md`, every `Pnn.md` your room
owns, and `reconciliation.md`. `tests/core_test.gd` checks the cards against the core: every
flag in `flags.md` §2 and §6 is settable, the movement whitelist is `GameSim.MOVES`, every item
in §4 is declared by the room the card says it is found in.

| Room | Owns (card) | Also writes |
| --- | --- | --- |
| R01 | P06 | `service_key` |
| R02 | P01, P03 part 1 (the drawer), T1X, P20 | `closure_report_filed`, `t1x_threshold_crossed`, `t1x_turned`, `venn_tide_sheet`, `inspection_lens`, `pencil`, `o01_found` |
| R03 | P03 part 2, P04, P05, P21 | `p05_trace` (via `freeze_p05_trace()`), `chart_clips` |
| R04 | P02, P17, P19 | |
| R05 | P07, P09 | `token_pantry_half`, `o02_found` |
| R06 | P08, P22 | `token_bunk_half`, `amended_nora_card`, `o03_found` |
| R07 | P10, P13, P14 | `nora_register_card`, `nora_frame` |
| R08 | P11 | `o04_found` |
| R09 | P15 | `nora_spatial_strip`, `o05_found` |
| R10 | P16, P18, P23 | `contact_sheet`, `venn_correspondence`, `witness_bridge`, `o06_found` |
| R11 | P12, P24 | |
| R12 | P25, P26, P27 | `ending_choice` (via `finish()`), the checkpoint at P26 |

**Translating card vocabulary:**

- `pNN_complete` → `game.flag("PNN")`; a card's commit → `game.solve("PNN", ev)`, never `set_flag`.
- Card "Requires" lists → your `REQUIRES` (to enter) or a check in `act()` (to commit). A refused
  commit says the card's refusal line and changes nothing.
- Evidence ids (`flags.md` §5) are your `OBSERVATIONS` keys, spelled exactly. The writer room is the
  notebook page: another room reads `calibration_zero` as `game.has_seen("R04", "calibration_zero")`.
- Items (§4) are declared in the `ITEMS` of the room that hands them out (already done for every
  card item). "Durable" items are never `take()`n; "returned after each use" means `take` on the
  attempt and `give` back on any outcome except the consuming commit.
- Room-local flags in `rooms.md` (e.g. R01 `gangway_loop`) live in your `state`, not in `game.flag`.
- Base views A/B/C and the R11 views 1/2 are `local_view` values that are not close-ups
  (override `is_closeup`); close-up ids are the cards' `c_*` names. Hotspot ids are the cards'.
- Escalation matrices are keyed to `game.weather_band()` and completion flags, never time. The
  "Notice" column is a first-time arrival hold in the view (about 1.5 s, click skips, `motion`-
  free still), keyed on a room-local "seen" flag so it plays once.
- Every card's **Tests** list becomes tests in `tests/rooms/<rid>_test.gd`, using `with_flags` /
  `game_at` for the prerequisites.
- Card `sudden` sounds go in `SFX_SOFT`; card `motion` effects need a still alternative.

**R02 re-time (the cards' T1X, for the R02 team; nothing else depends on the old order):**

1. Drop R02's `exit_block` hold on R03/R04 after P01: the corridor opens on `p01_complete`.
2. Opening the drawer grants `venn_tide_sheet` and `inspection_lens` (P03 part 1).
3. `log_rewritten` (and so the chair, report and threshold) needs `game.tide_done(1)`, not only the
   drawer; the objectives and hint ladder between drawer and T1X point to the instrument rooms.
4. At the threshold, use `game.solve("t1x_threshold_crossed", ev)` (done) so the Tide II card plays;
   `t1x_turned` and `closure_report_filed` already follow R02's state.
5. View B (entry wall: `outer_door`, `service_door`, `board`, `barometer`, `receipt`), P20, the
   six look-away changes re-timed to bands 2-7, and the photograph swap at band 1 (`rooms.md` R02).
