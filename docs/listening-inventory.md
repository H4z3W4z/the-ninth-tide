# Listening Room asset inventory

This inventory covers the accepted R04 v4 room and its object, inspection and weather artwork. It does not claim that the other eleven rooms, audio or gameplay are complete.

**Current inventory:** 93 PNG files, including 32 generated illustrations and 61 authored SVG/PNG pairs. The accepted master and rejected attempts are excluded from this count.

The machine-readable [manifest](../assets/listening/manifest.json) supplies measured hashes, dimensions, alpha bounds, room layers, crop rectangles, hotspots, reusable aliases and puzzle dependencies. Rebuild it with `python3 tools/build_listening_manifest.py`; source rasters remain unchanged.

## Composition contract

Use the clean room once. Clip only weather glazing panes and the open doorway. Put objects, local damp and light above the static plate. Full weather renders contain a partially assembled recorder and are never puzzle-state authority. Tide IX holds the eighth weather appearance.

Coordinates are on a 1448 × 1086 canvas. Every rectangle is x/y/width/height; only fields explicitly named `bbox_ltrb` use exclusive left/top/right/bottom. For generated cutouts, fit `source_region_px` into `target_rect`; transparent padding otherwise shrinks or misplaces the visible prop. The crop is render metadata, not an edited file. Exact SVG exports always retain their complete canvas.

Several generated cutouts contain faint alpha below 16 far from the visible object. Both exact and visible bounds are measured. The noticeboard has alpha 200–250 throughout and needs its specified opaque brown backing. Object pose differences are handled as swaps; no pixel-perfect animation is promised.

## Visible master coverage

| Master object | Supplied representation |
| --- | --- |
| Room, door, trim, bench, shelf structure, four closed drawer fronts | `r04_clean_base`. Fixed base; no duplicate prop layer. |
| Open doorway | `r04_door_open_plate`. Clip portal only; door leaf is out of view. |
| Window, storm and impossible sea states | `r04_weather_01_overcast`, `r04_weather_02_rain`, `r04_weather_03_storm`, `r04_weather_04_suspended`, `r04_weather_05_upright`, `r04_weather_06_silent`, `r04_weather_07_bearing`, `r04_weather_08_surface`. Seven shared glazing panes; fixed frame. |
| Window rain and local damp | `r04_rain_0`, `r04_rain_1`, `r04_rain_2`, `r04_wall_damp`. Authored overlays; motion remains optional. |
| Noticeboard and four corner pins | `r04_noticeboard_panel`. Opaque backing primitive supplied; corner pins part of board texture. |
| Pinned recording log, note and photograph | `r04_recording_log`, `r04_correction_note`, `r04_workers_photo`. Readable close-ups; text generated in original master is superseded. |
| Old paper rectangle at noticeboard upper right | Native manifest primitives. Native brown rectangle, atmospheric stain with no code. |
| Headphones, hook and connecting cord | `r04_headphones_hanging`. Cutout plus native hook and cord continuation paths in room_layers. |
| Task lamp off and light pool | `r04_lamp_off`, `r04_lamp_pool`, `r04_lamp_on`. Lit shade is included only when measured in current asset set. |
| Three vertical recording canisters | `r04_canister_closed`, `r04_canister_open`, `r04_case_label_a`, `r04_case_label_b`, `r04_case_label_c`. Reusable closed/open skin and three exact labels. |
| Wax recorder, spindle, brass uprights, needle and crank | `r04_recorder_empty`, `r04_recorder_partial`, `r04_recorder_assembled`. Fixed empty mechanism plus band layers is authoritative; whole poses are references. |
| Three recording bands and loose band in wooden case | `r04_wax_band`, `r04_band_face`, `r04_band_a_step_0`, `r04_band_a_step_1`, `r04_band_a_step_2`, `r04_band_b_step_0`, `r04_band_b_step_1`, `r04_band_b_step_2`, `r04_band_c_step_0`, `r04_band_c_step_1`, `r04_band_c_step_2`. One skin, nine exact overlays; no physical band can exist twice. |
| Brush and wax shavings | `r04_brush_shavings`. Single combined prop retains small debris. |
| Small wooden case | `r04_case_open`, `r04_case_closed`. Swap pose on inspection/re-entry; not registered hinge animation. |
| Instruction card and stand | `r04_instruction_stand`, `r04_assembly_card`. Readable authored sheet covers blank stand face. |
| Two horizontal shelf cylinders and ledger stack | `r04_shelf_cylinder`, `r04_ledger_stack`, `r04_maintenance_ledger`. Two repeated shelf cylinders; ledger inspection has authored text. |
| Functional top drawer | `r04_drawer_open`. One interactive drawer; remaining three fronts remain fixed furniture. |
| Worn stool and damp impression | `r04_stool_dry`, `r04_stool_damp_mark`, `r04_stool_damp`. Registered overlay over dry prop; alternate full damp pose retained as reference. |
| Later P17/P19 listening controls | `r04_channel_panel_blank`, `r04_p17_panel_overlay`, `r04_p19_panel_overlay`. Inspection-only panel; no extra room horns or wall machinery. |

## Progression mapping

| Appearance | Required completed puzzles | Exterior |
| --- | --- | --- |
| 1: Arrival / Tide I | Arrival | Ordinary sea and a visible lighthouse. |
| 2: Tide II complete | P06 | Low cloud and rain on glass. |
| 3: Tide III complete | P09 | Dark sea, heavy rain and local damp. |
| 4: Tide IV complete | P12 | Freeze glass rain while wave timing disagrees. |
| 5: Tide V complete | P15 | Compressed horizon and upright sea. |
| 6: Tide VI complete | P17, P18 | Rain remains visible after exterior weather sound falls away. |
| 7: Tide VII complete | P21 | Lighthouse at an impossible bearing; darkness close to glass. |
| 8: Tide VIII complete / Tide IX | P24 | Near-featureless dark surface at the window. |

## Puzzle and evidence bindings

- P02 begins after P01, independently of P03. One fixed empty room recorder and shared band skins represent any partial room state. The close-up uses a separate authored band face, exact 180 × 300 overlays and 600 × 300 fixed guides from `authored-spec.json`. C/A/B at steps 0/0/0 yields calibration zero 4 and the tomorrow transcript. Keep both in the notebook.
- P17 begins after P16. Use the inspection panel and two separately labeled timing traces. Align both bell marks, then listen to Venn and Nora separately. Preserve both statements and the witness procedure. Timing diagrams are authored art and still need recorded voices.
- P19 begins after both P17 and P18. Motor OFF, A CLOSED, B CLOSED, C OPEN, then WITNESS. Shared state graphics give every switch and indicator a clear label. The final answer continues after the indicator darkens. No horns, microphone access or device history are involved.
- Recording log, pinned note, photograph, assembly card, maintenance ledger and earned transcripts each have inspection/evidence bindings. The photograph is atmospheric and does not identify the workers. There is currently no actual map in this room; any later map must receive a readable close-up.

## Measured asset register

| Asset | Size | Alpha range | Visible source region x/y/w/h | Role |
| --- | --- | --- | --- | --- |
| `r04_clean_base` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | layered_art_candidate |
| `r04_door_open_plate` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | portal_source_only |
| `r04_weather_01_overcast` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | window_source_and_full_room_review |
| `r04_weather_02_rain` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | window_source_and_full_room_review |
| `r04_weather_03_storm` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | window_source_and_full_room_review |
| `r04_weather_04_suspended` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | window_source_and_full_room_review |
| `r04_weather_05_upright` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | window_source_and_full_room_review |
| `r04_weather_06_silent` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | window_source_and_full_room_review |
| `r04_weather_07_bearing` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | window_source_and_full_room_review |
| `r04_weather_08_surface` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | window_source_and_full_room_review |
| `r04_channel_panel_blank` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | layered_art_candidate |
| `r04_paper_blank` | 1086 × 1448 | 0–255 | 84,115,919,1225 | layered_art_candidate |
| `r04_workers_photo` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | layered_art_candidate |
| `r04_assembly_card` | 800 × 1000 | 195–255 | 0,0,800,1000 | layered_art_candidate |
| `r04_correction_note` | 800 × 1000 | 195–255 | 0,0,800,1000 | layered_art_candidate |
| `r04_maintenance_ledger` | 800 × 1000 | 195–255 | 0,0,800,1000 | layered_art_candidate |
| `r04_nora_statement` | 800 × 1000 | 195–255 | 0,0,800,1000 | layered_art_candidate |
| `r04_playback_transcript` | 800 × 1000 | 195–255 | 0,0,800,1000 | layered_art_candidate |
| `r04_recording_log` | 800 × 1000 | 195–255 | 0,0,800,1000 | layered_art_candidate |
| `r04_venn_statement` | 800 × 1000 | 195–255 | 0,0,800,1000 | layered_art_candidate |
| `r04_witness_answer_reach` | 800 × 1000 | 195–255 | 0,0,800,1000 | layered_art_candidate |
| `r04_witness_answer_remain` | 800 × 1000 | 195–255 | 0,0,800,1000 | layered_art_candidate |
| `r04_witness_answer_sever` | 800 × 1000 | 195–255 | 0,0,800,1000 | layered_art_candidate |
| `r04_witness_margin` | 800 × 1000 | 195–255 | 0,0,800,1000 | layered_art_candidate |
| `r04_witness_procedure` | 800 × 1000 | 195–255 | 0,0,800,1000 | layered_art_candidate |
| `r04_lamp_pool` | 1448 × 1086 | 0–48 | 0,0,1448,1086 | layered_art_candidate |
| `r04_rain_0` | 1448 × 1086 | 0–69 | 0,0,1448,1086 | layered_art_candidate |
| `r04_rain_1` | 1448 × 1086 | 0–69 | 0,0,1448,1086 | layered_art_candidate |
| `r04_rain_2` | 1448 × 1086 | 0–69 | 0,0,1448,1086 | layered_art_candidate |
| `r04_stool_damp_mark` | 1448 × 1086 | 0–74 | 0,0,1448,1086 | layered_art_candidate |
| `r04_wall_damp` | 1448 × 1086 | 0–56 | 0,0,1448,1086 | layered_art_candidate |
| `r04_window_mask` | 1448 × 1086 | 0–255 | 0,0,1448,1086 | layered_art_candidate |
| `r04_brush_shavings` | 1774 × 887 | 0–255 | 187,304,1392,322 | layered_art_candidate |
| `r04_canister_closed` | 1207 × 1303 | 0–255 | 263,156,676,1007 | layered_art_candidate |
| `r04_canister_open` | 1207 × 1303 | 0–255 | 266,153,675,1010 | layered_art_candidate |
| `r04_case_closed` | 1313 × 1198 | 0–255 | 144,429,1025,392 | layered_art_candidate |
| `r04_case_open` | 1314 × 1197 | 0–255 | 235,156,845,863 | layered_art_candidate |
| `r04_drawer_open` | 2172 × 724 | 0–255 | 129,203,1914,350 | layered_art_candidate |
| `r04_headphones_hanging` | 1254 × 1254 | 0–255 | 260,70,889,1117 | layered_art_candidate |
| `r04_instruction_stand` | 1351 × 1164 | 0–255 | 295,156,762,849 | layered_art_candidate |
| `r04_lamp_off` | 1322 × 1190 | 0–255 | 193,13,909,1143 | layered_art_candidate |
| `r04_lamp_on` | 1323 × 1189 | 0–255 | 193,11,912,1143 | layered_art_candidate |
| `r04_ledger_stack` | 1774 × 887 | 0–255 | 176,260,1423,446 | layered_art_candidate |
| `r04_noticeboard_panel` | 1536 × 1024 | 200–250 | 0,0,1536,1024 | layered_prop |
| `r04_recorder_assembled` | 1774 × 887 | 0–255 | 240,115,1447,682 | pose_reference_only |
| `r04_recorder_empty` | 1774 × 887 | 0–255 | 241,95,1442,701 | layered_art_candidate |
| `r04_recorder_partial` | 1774 × 887 | 0–255 | 122,65,1607,760 | pose_reference_only |
| `r04_shelf_cylinder` | 1774 × 887 | 0–255 | 87,248,1596,402 | layered_art_candidate |
| `r04_stool_damp` | 1214 × 1295 | 0–255 | 223,158,768,1019 | pose_reference_only |
| `r04_stool_dry` | 1223 × 1286 | 0–255 | 213,98,798,1105 | layered_art_candidate |
| `r04_wax_band` | 1448 × 1086 | 0–255 | 427,336,585,412 | layered_art_candidate |
| `r04_band_a_step_0` | 180 × 300 | 0–255 | 0,0,180,300 | layered_art_candidate |
| `r04_band_a_step_1` | 180 × 300 | 0–255 | 0,0,180,300 | layered_art_candidate |
| `r04_band_a_step_2` | 180 × 300 | 0–255 | 0,0,180,300 | layered_art_candidate |
| `r04_band_b_step_0` | 180 × 300 | 0–255 | 0,0,180,300 | layered_art_candidate |
| `r04_band_b_step_1` | 180 × 300 | 0–255 | 0,0,180,300 | layered_art_candidate |
| `r04_band_b_step_2` | 180 × 300 | 0–255 | 0,0,180,300 | layered_art_candidate |
| `r04_band_c_step_0` | 180 × 300 | 0–255 | 0,0,180,300 | layered_art_candidate |
| `r04_band_c_step_1` | 180 × 300 | 0–255 | 0,0,180,300 | layered_art_candidate |
| `r04_band_c_step_2` | 180 × 300 | 0–255 | 0,0,180,300 | layered_art_candidate |
| `r04_band_face` | 180 × 200 | 195–255 | 0,0,180,200 | layered_art_candidate |
| `r04_case_label_a` | 180 × 90 | 0–255 | 0,0,180,90 | layered_art_candidate |
| `r04_case_label_b` | 180 × 90 | 0–255 | 0,0,180,90 | layered_art_candidate |
| `r04_case_label_c` | 180 × 90 | 0–255 | 0,0,180,90 | layered_art_candidate |
| `r04_channel_closed` | 260 × 100 | 0–255 | 0,0,260,100 | layered_art_candidate |
| `r04_channel_open` | 260 × 100 | 0–255 | 0,0,260,100 | layered_art_candidate |
| `r04_indicator_off` | 64 × 64 | 0–255 | 0,0,64,64 | layered_art_candidate |
| `r04_indicator_on` | 64 × 64 | 0–255 | 0,0,64,64 | layered_art_candidate |
| `r04_listen_nora_idle` | 400 × 72 | 0–255 | 0,0,400,72 | layered_art_candidate |
| `r04_listen_nora_pressed` | 400 × 72 | 0–255 | 0,0,400,72 | layered_art_candidate |
| `r04_listen_venn_idle` | 400 × 72 | 0–255 | 0,0,400,72 | layered_art_candidate |
| `r04_listen_venn_pressed` | 400 × 72 | 0–255 | 0,0,400,72 | layered_art_candidate |
| `r04_motor_off` | 260 × 100 | 0–255 | 0,0,260,100 | layered_art_candidate |
| `r04_motor_on` | 260 × 100 | 0–255 | 0,0,260,100 | layered_art_candidate |
| `r04_needle_lowered` | 350 × 96 | 0–255 | 0,0,350,96 | layered_art_candidate |
| `r04_needle_raised` | 350 × 96 | 0–255 | 0,0,350,96 | layered_art_candidate |
| `r04_p02_panel_overlay` | 1448 × 1086 | 0–255 | 0,0,1448,1086 | layered_art_candidate |
| `r04_p02_playback_readout` | 1080 × 600 | 0–255 | 0,0,1080,600 | layered_art_candidate |
| `r04_p17_panel_overlay` | 1448 × 1086 | 0–255 | 0,0,1448,1086 | layered_art_candidate |
| `r04_p19_panel_overlay` | 1448 × 1086 | 0–255 | 0,0,1448,1086 | layered_art_candidate |
| `r04_p19_questions_overlay` | 1448 × 1086 | 0–255 | 0,0,1448,1086 | layered_art_candidate |
| `r04_play_key` | 350 × 96 | 0–255 | 0,0,350,96 | layered_art_candidate |
| `r04_question_reach` | 1208 × 140 | 0–255 | 0,0,1208,140 | layered_art_candidate |
| `r04_question_remain` | 1208 × 140 | 0–255 | 0,0,1208,140 | layered_art_candidate |
| `r04_question_sever` | 1208 × 140 | 0–255 | 0,0,1208,140 | layered_art_candidate |
| `r04_rotate_band` | 268 × 96 | 0–255 | 0,0,268,96 | layered_art_candidate |
| `r04_spindle_guides` | 600 × 300 | 0–255 | 0,0,600,300 | layered_art_candidate |
| `r04_trace_left` | 104 × 72 | 0–255 | 0,0,104,72 | layered_art_candidate |
| `r04_trace_right` | 104 × 72 | 0–255 | 0,0,104,72 | layered_art_candidate |
| `r04_waveform_nora` | 960 × 144 | 0–255 | 0,0,960,144 | layered_art_candidate |
| `r04_waveform_venn` | 960 × 144 | 0–255 | 0,0,960,144 | layered_art_candidate |
| `r04_witness_key_idle` | 404 × 110 | 0–255 | 0,0,404,110 | layered_art_candidate |
| `r04_witness_key_pressed` | 404 × 110 | 0–255 | 0,0,404,110 | layered_art_candidate |

## Delivery limits

All bounded R04 illustration roles have a current file or deliberate reusable/native-vector representation.

This manifest verifies files and art structure. It does not validate runtime puzzle state, playback, saves, touch handling, audio, browser export or native device behavior. Codex integration must use the review composition and the defined evidence constraints. The generated empty/partial/assembled recorder and dry/damp stool poses are available for art comparison; fixed geometry plus overlays remains authoritative.
