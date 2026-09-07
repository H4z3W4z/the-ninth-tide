# Listening Room v4: art and integration handoff

## Scope and reference

The accepted production reference is [listening-room-approved-master-v4.png](../art/concepts/listening-room-approved-master-v4.png), a 1448 × 1086 front elevation. Use its hornless wax recorder and hooked headphones, small lived-in noticeboard, specialized oak bench, brass task lamp, worn stool, and prominent right-hand weather window. Earlier horn and speaking-tube studies are superseded. The pinned photograph shows two unnamed workers; it establishes atmosphere without assigning a new identity or dependency.

**Status: R04 graphics pack complete; integration pending.** This pack covers R04 illustration, inspection surfaces, exact puzzle graphics and visual state instructions. It does not implement the room, its three puzzles, audio, saves or animation. The existing P01/P03 code baseline and rendered map-input failure are documented separately in [CODEX-HANDOFF.md](CODEX-HANDOFF.md). The approved master is a partial recorder arrangement used for visual review, not a new-game state.

| Resource | Use |
| --- | --- |
| [Asset inventory](listening-inventory.md) | Current deliverable list, statuses and reuse decisions |
| [R04 manifest](../assets/listening/manifest.json) | Source regions, placements, layers, state mappings and inspection references |
| [Composed review](../art/listening-review/composed/index.html) | Artwork composition and state comparison; no gameplay validation |
| [Evidence review](listening-evidence-review.md) | Document readability, visibility gates and caption requirements |
| [Authored specification](../assets/listening/authored-spec.json) | Exact band faces/seams, panel controls, timing-diagram events and fixed dialogue copy |
| [Generation record](listening-pack-generation.json) | Exact prompts, sources, references and rejected draft notes |
| [Checkpoint history](listening-pack-progress.md) | Recorded batches and checks |
| `tools/build_listening_vectors.py` | Rebuild editable SVG and PNG puzzle/document/effect assets |

## Composition contract

Use the manifest's coordinates as the placement source; do not infer hotspots from transparent PNG canvas sizes. Scale the complete 4:3 view uniformly and account for that transform in input. Final engine placement and touch readability still require testing.

Build the room in this order:

1. Draw the fixed `r04_clean_base.png`. It owns wall, floor, bench, window frame and closed-door geometry.
2. Sample the chosen full-room weather image at the same room coordinates, clipped to the seven glazing regions. Keep its furniture, recorder and lamp outside the mask. Clip the open-door detail to the door portal when needed; retain the fixed surrounding architecture.
3. Draw window rain/reflection and local wall damp layers using the same room transform. Place the lamp's local light pool behind the props it illuminates. Preserve readable clue surfaces as weather darkens.
4. Place the noticeboard with its opaque backing, pinned papers/photo, shelf contents and separate bench props. Reuse storage/cylinder templates at the manifest's named placements rather than treating each instance as a new inventory item.
5. Draw the fixed empty recorder and the player's actual room-scale band layers. Select the lamp's ON/OFF pose, and draw the dry stool with the registered damp-seat mark. Generated lamp, recorder and stool alternatives are appearance references or discrete swap poses; their outlines can drift. Keep the authored light pool separate.
6. Add exact labels and state overlays, followed by focus/selection controls and inspection UI. Keep interactive text above local darkness effects. A room-sized image of a document is a hotspot cue; open its dedicated readable artwork and transcript for inspection.

Do not use a full-room weather render as an interactive state frame. Those images retain the reference's partial cylinder assembly. **Weather, P02 arrangement and P19 motor/channel settings are independent state inputs.** An ominous window must never install a missing band, award a clue or stop a motor.

## Environmental states

| Appearance | Trigger | Revisit change |
| --- | --- | --- |
| 01, overcast | Arrival through Tide I | Ordinary sea and visible lighthouse |
| 02, rain | P06 complete | Lower cloud and stippled glass |
| 03, storm | P09 complete | Heavier rain, darker sea and damp below the window |
| 04, suspended | P12 complete | Rain holds while other movement disagrees; use a held rain frame |
| 05, upright | P15 complete | Compressed horizon and mismatched reflection |
| 06, silent | P17 **and** P18 complete | Visible rain with almost no distant detail; future sound mix removes external weather |
| 07, wrong bearing | P21 complete | Darkness close to the glass and displaced lighthouse |
| 08, surface | P24 complete | Near-featureless dark surface outside |
| Hold 08 | Tide IX before commitment | Stillness; no automatic return to daylight |

Resolve the latest achieved milestone on load and re-entry, without replaying skipped states. Weather review controls are presentation overrides only. Rain stillness and reduced motion must not affect puzzle timers because no timed solution is required. Silence, lagging reflections and voice continuation need later runtime/audio work; a static illustration does not implement those events.

## Exact puzzle graphics

### P02: Tomorrow's Recording

Requires P01 and may be completed before or after P03. In the exact inspection view, build the three movable bands from the authored `r04_band_face` plus their label/seam overlays. Use `authored-spec.json` schema 2's `panels.P02` layout and discrete validation source: **C → A → B**, orientation steps **0/0/0**, with both fixed end guides at class 0. Preserve START/END notches and continuous seam relationships at inspection scale. Step buttons and tap placement must provide an alternative to dragging.

The empty mechanism is the stable room-scale base, with the generated wax band supplying small occupied-slot silhouettes. `r04_recorder_partial.png` and `r04_recorder_assembled.png` communicate appearance but are not a validator or a substitute for independent pieces. The exact P02 panel uses its authored band faces and fixed guides; do not stretch the angled generated wax skin beneath a precise seam overlay. Preserve selected band, arrangement and rotations when the player leaves or reloads. Wrong arrangements do not consume pieces.

Use the assembly card, recording log and correction note as readable inspection assets. Gate the playback readout and preserved transcript to successful playback: they give **calibration zero 4** and tomorrow's line, “Mercer will be standing at the chart table.” Both remain in the notebook. P03 still grants interval 3, and **P02 and P03 together complete Tide I**.

### P17: Two People in One Sentence

Requires P16; P18 is the parallel branch. The blank calibration faceplate is an inspection background for the authored P17 overlay and two movable timing traces, not a new object on the room wall. Align both bell events at one fixed guide, then let the player select Venn and Nora separately. Preserve speaker names and both statements: “Leave the witness line open” and “Tell them I was here.”

The supplied traces are authored timing diagrams, not waveforms extracted from recorded speech. Future recordings and their cue positions must agree with this visual evidence. A visual solution and transcript must remain usable with audio disabled. Completing both P17 and P18 advances Tide VI and opens P19/P20.

### P19: Speak to the Empty Channel

Requires **P17 and P18**. Use the P19 panel overlay and shared motor, channel, indicator and WITNESS-key states. The printed seal mapping is A/one cut, B/two cuts, C/three cuts. Required configuration is **motor OFF, A CLOSED, B CLOSED, C OPEN, then WITNESS**.

The witness procedure can be observed after P17, but P19 interaction remains gated by both prerequisites. Use `authored-spec.json` under `panels.P19` and its linked document assets for the exact three question/answer exchanges; their content fulfills the GDD's required disclosures. Retain all three answers as evidence. The final voice continues through the headphones after the channel indicator goes dark. Keep captions available and identify the speaker; a dark indicator never hides text or removes the recording from the notebook. Do not restore funnels or a horn assembly to stage the event.

## Inspection, source quality and handoff limits

All actual maps/charts in playable rooms remain inspectable, including atmospheric maps, with observed versions preserved. This room's photograph, notes and recording diagrams are not a license to add a decorative illegible map. Any map introduced in later art requires its own readable close-up and transcript.

The pack includes true-alpha object cutouts, opaque room/detail plates and a partly translucent noticeboard texture with an explicit backing requirement. Rejected halo/checkerboard attempts remain under `art/listening-review/`; never load them as runtime sprites. Retain generated source images and use crop/region placement rather than destructive raster cleanup. Exact SVG sources remain alongside their PNG exports.

Asset integrity and graphic-specification checks concern files and authored relationships. They do not establish Godot input, state persistence, voice timing, browser operation, iPad readability or native export behavior. Codex owns those implementation gates and should use this pack without changing the puzzle dependencies or the accepted room composition.
