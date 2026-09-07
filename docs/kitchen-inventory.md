# Kitchen and Mess asset inventory

This is the R05 graphics handoff. It supplies room art, reachable weather appearances, separate object states and exact P07/P09 clue graphics. Gameplay, audio, save behavior and device validation remain integration work.

**Measured inventory:** 84 local PNG files: 6 generated illustrations and 78 authored SVG/PNG pairs. In addition, 7 existing R04 weather sources are referenced without duplication. Concept references and review composites are excluded.

The [manifest](../assets/kitchen/manifest.json) records hashes, measured alpha regions, placements, layer conditions, puzzle inspection bindings and preserved evidence. Rebuild with `python3 tools/build_kitchen_manifest.py` after exporting the authored graphics. Source PNGs are never rewritten by this builder.

## Composition and persistence

Use a fixed room plate, window-only exterior art, registered authored local effects and independent props. Generated cutouts use their measured alpha-at-least-16 content rectangle as a render crop. This avoids transparent padding shrinking the visible object; it does not edit or crop the source file. Authored SVG exports retain their full canvas for registration.

All rectangles are x/y/width/height on a 1448 × 1086 canvas. Only explicitly named `bbox_ltrb` fields use exclusive left/top/right/bottom bounds. Scale the complete view uniformly and letterbox. Large inspection buttons supplement small room objects.

R05 first opens after P06 and inherits stage 2. Tides III–VIII progress from P09, P12, P15, P17 plus P18, P21 and P24. Tide IX holds stage 8. Review buttons never award puzzle completion. Weather changes cannot move clues, reset bowls, spend tokens or erase observations.

## Visible master coverage

| Object or surface | Supplied representation |
| --- | --- |
| Room, sea-glass walls, floor, trim, table and closed pantry drawer | `r05_clean_base`. Fixed room geometry, independent of weather and bowls. |
| Iron range and chimney | `r05_clean_base`. Static domestic equipment; readable inspection description, no new repair puzzle. |
| Pendant, shelf plates, coffee pot, canisters, mixing bowl, apron and ladle | `r05_clean_base`. Fixed ordinary household props with inspection descriptions; no added occult symbols or unlabeled clues. |
| Copper stock pot, folded towel and closed provisioning book | `r05_stockpot`, `r05_towel`, `r05_ledger_closed`. Separate generated props; the book opens readable authored documents. |
| Sea window and seven reachable storm appearances | `r04_weather_02_rain`, `r04_weather_03_storm`, `r04_weather_04_suspended`, `r04_weather_05_upright`, `r04_weather_06_silent`, `r04_weather_07_bearing`, `r04_weather_08_surface`. Shared R04 frame-free coastal crops behind nine fixed R05 panes. No duplicate PNG copies. |
| Local inward condensation and cooling daylight | `r05_bowl_condensation_0`, `r05_bowl_condensation_1`, `r05_bowl_condensation_2`, `r05_board_condensation`. Native room damp/tint plus registered authored bowl and board effects; evidence always retained. |
| Eight initialed bowls and unsigned square-repaired ninth bowl | `r05_bowl_plain`, `r05_square_patch`, `r05_bowl_nb`, `r05_bowl_sr`, `r05_bowl_ti`, `r05_bowl_al`, `r05_bowl_cm`, `r05_bowl_dh`, `r05_bowl_ep`, `r05_bowl_jw`, `r05_bowl_unsigned`. One generated room skin, exact square-repair overlay, and nine exact plan-view inspection faces. Shared geometry keeps the unsigned bowl registered. |
| Nine cloth places and eight initial labels | `r05_place_cloth`, `r05_square_place`, `r05_square_patch`, `r05_initial_nb`, `r05_initial_sr`, `r05_initial_ti`, `r05_initial_al`, `r05_initial_cm`, `r05_initial_dh`, `r05_initial_ep`, `r05_initial_jw`. Exact shared labels and square mark in the room; authored nine-place inspection cloth. |
| Nine spoons and the unsigned spoon lift | `r05_spoon_rest`, `r05_spoon_raised`. Authored rest pose instanced nine times. The unsigned spoon uses the registered raised pose on the same source canvas; no generated transparency replacement needed. |
| Pantry drawer and paired service token | `r05_drawer_open`, `r05_token_pantry`, `r05_token_bunk`. Open drawer pose; pantry half from P07, bunk half from P08. Both consumed together only on P09 acceptance. |
| Service board, original eight, correction fields and three-cut stamp | `r05_p09_panel`, `r05_amendment_rules`, `r05_amendment_stamp`, `r05_duplicate_board`, `r05_duplicate_board_reveal`. Exact inspection geometry and retained original; physical bare-text reveal and notebook copy are earned only after P09. |
| Serving evidence, repair sketch and menu objection | `r05_kitchen_work_card`, `r05_serving_ledger`, `r05_table_instructions`, `r05_amendment_rules`, `r05_menu_objection`, `r05_provisioning_repair`, `r05_extra_diner_note`, `r05_p07_record`, `r05_duplicate_board`, `r05_duplicate_board_reveal`, `r05_p09_record`. All readable and separately gated. The physical repaired cup remains R06. |
| Open service portal | Native manifest primitive. Native straight-on dark opening and threshold inside the fixed door frame. |

## Progression

| Stage | Completion requirement | Returning-player observation |
| --- | --- | --- |
| 2: Tide II complete | P06 | Rain lowers the familiar coast; the room opens with the same weather as the service landing. |
| 3: Tide III complete | P09 | Heavy rain and inward damp reach below the window. The corrected meal record remains readable. |
| 4: Tide IV complete | P12 | Rain seems suspended; visible water and its sound disagree. |
| 5: Tide V complete | P15 | The horizon compresses into the upright sea; condensation tracks toward the table. |
| 6: Tide VI complete | P17 + P18 | The sea loses distant detail; visible rain continues after exterior sound falls away. |
| 7: Tide VII complete | P21 | The lighthouse appears at the wrong bearing while darkness presses close to the glass. |
| 8: Tide VIII complete / Tide IX hold | P24 | A near-featureless surface replaces sea and sky. The meal table remains legible. |

## Canonical puzzle bindings

- P07 requires P06. Match eight initialed bowls and the unsigned square-repaired ninth bowl to the cloth. Set serving tally 9 and compare against official 8. The pantry token half and Venn note are awarded once. The spoon lifts and lowers once; reduced motion uses held poses and a preserved description.
- P09 requires both P07 and P08. Fit both service-token halves, retain the official eight, append +1 / VENN / present and use the three-cut seal. Tokens are consumed together only on a valid commit. The duplicate board reads “Eight retained. One witnessing.” Preserve this before condensation can obscure the room copy.
- Nora’s physical repaired cup belongs in R06 for P08/P22. The kitchen supplies her provisioning repair sketch and readable evidence, not a second physical quest cup.
- Atmospheric documents remain inspectable without becoming additional mandatory puzzles. Every actual visible map needs its own readable close-up; map inventory is explicit in the manifest.

## Measured assets

| Asset | Size | Alpha range | Render source x/y/w/h | Role |
| --- | --- | --- | --- | --- |
| `r05_clean_base` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | fixed-background |
| `r05_amendment_rules` | 800 × 1000 | 195–255 | 0,0,800,1000 | readable_document |
| `r05_duplicate_board` | 800 × 1000 | 195–255 | 0,0,800,1000 | readable_document |
| `r05_extra_diner_note` | 800 × 1000 | 195–255 | 0,0,800,1000 | readable_document |
| `r05_kitchen_work_card` | 800 × 1000 | 195–255 | 0,0,800,1000 | readable_document |
| `r05_menu_objection` | 800 × 1000 | 195–255 | 0,0,800,1000 | readable_document |
| `r05_p07_record` | 800 × 1000 | 195–255 | 0,0,800,1000 | readable_document |
| `r05_p09_record` | 800 × 1000 | 195–255 | 0,0,800,1000 | readable_document |
| `r05_provisioning_repair` | 800 × 1000 | 195–255 | 0,0,800,1000 | readable_document |
| `r05_serving_ledger` | 800 × 1000 | 195–255 | 0,0,800,1000 | readable_document |
| `r05_table_instructions` | 800 × 1000 | 195–255 | 0,0,800,1000 | readable_document |
| `r05_board_condensation` | 1000 × 580 | 0–81 | 0,0,1000,580 | board_condensation |
| `r05_bowl_condensation_0` | 200 × 200 | 0–255 | 0,0,200,200 | inward_condensation_stage |
| `r05_bowl_condensation_1` | 200 × 200 | 0–255 | 0,0,200,200 | inward_condensation_stage |
| `r05_bowl_condensation_2` | 200 × 200 | 0–255 | 0,0,200,200 | inward_condensation_stage |
| `r05_spoon_raised` | 112 × 210 | 0–255 | 0,0,112,210 | spoon_event_pose |
| `r05_spoon_rest` | 112 × 210 | 0–255 | 0,0,112,210 | spoon_event_pose |
| `r05_bowl_plain` | 1207 × 1303 | 0–255 | 123,490,958,420 | transparent-prop |
| `r05_drawer_open` | 2172 × 724 | 0–255 | 187,140,1797,440 | transparent-prop |
| `r05_ledger_closed` | 1619 × 971 | 0–255 | 263,290,1097,492 | transparent-prop |
| `r05_stockpot` | 1448 × 1086 | 0–255 | 128,123,1192,808 | transparent-prop |
| `r05_towel` | 1207 × 1303 | 0–255 | 328,97,573,1092 | transparent-prop |
| `r05_amendment_stamp` | 200 × 180 | 0–255 | 0,0,200,180 | three_cut_stamp |
| `r05_back` | 180 × 76 | 0–255 | 0,0,180,76 | control_graphic |
| `r05_bowl_al` | 200 × 200 | 0–255 | 0,0,200,200 | inspectable_bowl |
| `r05_bowl_cm` | 200 × 200 | 0–255 | 0,0,200,200 | inspectable_bowl |
| `r05_bowl_dh` | 200 × 200 | 0–255 | 0,0,200,200 | inspectable_bowl |
| `r05_bowl_ep` | 200 × 200 | 0–255 | 0,0,200,200 | inspectable_bowl |
| `r05_bowl_jw` | 200 × 200 | 0–255 | 0,0,200,200 | inspectable_bowl |
| `r05_bowl_nb` | 200 × 200 | 0–255 | 0,0,200,200 | inspectable_bowl |
| `r05_bowl_selected` | 200 × 200 | 0–255 | 0,0,200,200 | selection_outline |
| `r05_bowl_sr` | 200 × 200 | 0–255 | 0,0,200,200 | inspectable_bowl |
| `r05_bowl_ti` | 200 × 200 | 0–255 | 0,0,200,200 | inspectable_bowl |
| `r05_bowl_unsigned` | 200 × 200 | 0–255 | 0,0,200,200 | inspectable_bowl |
| `r05_clear_places` | 298 × 76 | 0–255 | 0,0,298,76 | control_graphic |
| `r05_compare` | 298 × 90 | 0–255 | 0,0,298,90 | control_graphic |
| `r05_delta_0` | 260 × 100 | 0–255 | 0,0,260,100 | control_graphic |
| `r05_delta_plus1` | 260 × 100 | 0–255 | 0,0,260,100 | control_graphic |
| `r05_delta_plus2` | 260 × 100 | 0–255 | 0,0,260,100 | control_graphic |
| `r05_duplicate_board_reveal` | 1000 × 580 | 1–255 | 0,0,1000,580 | physical_duplicate_board_reveal |
| `r05_initial_al` | 100 × 50 | 0–255 | 0,0,100,50 | exact_room_bowl_or_cloth_mark |
| `r05_initial_cm` | 100 × 50 | 0–255 | 0,0,100,50 | exact_room_bowl_or_cloth_mark |
| `r05_initial_dh` | 100 × 50 | 0–255 | 0,0,100,50 | exact_room_bowl_or_cloth_mark |
| `r05_initial_ep` | 100 × 50 | 0–255 | 0,0,100,50 | exact_room_bowl_or_cloth_mark |
| `r05_initial_jw` | 100 × 50 | 0–255 | 0,0,100,50 | exact_room_bowl_or_cloth_mark |
| `r05_initial_nb` | 100 × 50 | 0–255 | 0,0,100,50 | exact_room_bowl_or_cloth_mark |
| `r05_initial_sr` | 100 × 50 | 0–255 | 0,0,100,50 | exact_room_bowl_or_cloth_mark |
| `r05_initial_ti` | 100 × 50 | 0–255 | 0,0,100,50 | exact_room_bowl_or_cloth_mark |
| `r05_inspect_ledger` | 298 × 76 | 0–255 | 0,0,298,76 | control_graphic |
| `r05_name_bell` | 260 × 100 | 0–255 | 0,0,260,100 | control_graphic |
| `r05_name_ives` | 260 × 100 | 0–255 | 0,0,260,100 | control_graphic |
| `r05_name_rook` | 260 × 100 | 0–255 | 0,0,260,100 | control_graphic |
| `r05_name_venn` | 260 × 100 | 0–255 | 0,0,260,100 | control_graphic |
| `r05_next` | 116 × 76 | 0–255 | 0,0,116,76 | control_graphic |
| `r05_p07_panel` | 1448 × 1086 | 195–255 | 0,0,1448,1086 | P07_inspection_backplate |
| `r05_p07_places_disagree` | 940 × 142 | 0–255 | 0,0,940,142 | feedback_card |
| `r05_p07_success` | 940 × 142 | 0–255 | 0,0,940,142 | feedback_card |
| `r05_p07_tally_disagrees` | 940 × 142 | 0–255 | 0,0,940,142 | feedback_card |
| `r05_p09_amendment_incorrect` | 940 × 142 | 0–255 | 0,0,940,142 | feedback_card |
| `r05_p09_original_changed` | 940 × 142 | 0–255 | 0,0,940,142 | feedback_card |
| `r05_p09_panel` | 1448 × 1086 | 195–255 | 0,0,1448,1086 | P09_inspection_backplate |
| `r05_p09_success` | 940 × 142 | 0–255 | 0,0,940,142 | feedback_card |
| `r05_p09_tokens_missing` | 940 × 142 | 0–255 | 0,0,940,142 | feedback_card |
| `r05_place_cloth` | 970 × 730 | 1–255 | 0,0,970,730 | nine_place_plan_view_cloth |
| `r05_previous` | 116 × 76 | 0–255 | 0,0,116,76 | control_graphic |
| `r05_read_rule` | 335 × 76 | 0–255 | 0,0,335,76 | control_graphic |
| `r05_seal_1` | 140 × 140 | 0–255 | 0,0,140,140 | seal_selector_state |
| `r05_seal_2` | 140 × 140 | 0–255 | 0,0,140,140 | seal_selector_state |
| `r05_seal_3` | 140 × 140 | 0–255 | 0,0,140,140 | seal_selector_state |
| `r05_seal_selected` | 160 × 160 | 0–255 | 0,0,160,160 | selected_seal_outline |
| `r05_square_patch` | 50 × 50 | 0–255 | 0,0,50,50 | exact_room_unsigned_bowl_patch |
| `r05_square_place` | 50 × 50 | 0–255 | 0,0,50,50 | exact_room_ninth_place_mark |
| `r05_stamp` | 280 × 96 | 0–255 | 0,0,280,96 | control_graphic |
| `r05_status_absent` | 260 × 100 | 0–255 | 0,0,260,100 | control_graphic |
| `r05_status_present` | 260 × 100 | 0–255 | 0,0,260,100 | control_graphic |
| `r05_tally_10` | 150 × 110 | 0–255 | 0,0,150,110 | tally_state |
| `r05_tally_7` | 150 × 110 | 0–255 | 0,0,150,110 | tally_state |
| `r05_tally_8` | 150 × 110 | 0–255 | 0,0,150,110 | tally_state |
| `r05_tally_9` | 150 × 110 | 0–255 | 0,0,150,110 | tally_state |
| `r05_tally_minus` | 96 × 80 | 0–255 | 0,0,96,80 | control_graphic |
| `r05_tally_plus` | 96 × 80 | 0–255 | 0,0,96,80 | control_graphic |
| `r05_token_bunk` | 230 × 230 | 0–255 | 0,0,230,230 | service_token_half |
| `r05_token_pantry` | 230 × 230 | 0–255 | 0,0,230,230 | service_token_half |
| `r05_token_socket` | 456 × 180 | 1–255 | 0,0,456,180 | paired_token_socket |
| `r04_weather_02_rain` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | shared_coastal_weather |
| `r04_weather_03_storm` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | shared_coastal_weather |
| `r04_weather_04_suspended` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | shared_coastal_weather |
| `r04_weather_05_upright` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | shared_coastal_weather |
| `r04_weather_06_silent` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | shared_coastal_weather |
| `r04_weather_07_bearing` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | shared_coastal_weather |
| `r04_weather_08_surface` | 1448 × 1086 | 255–255 | 0,0,1448,1086 | shared_coastal_weather |

## Delivery limits

All bounded R05 art roles have measured files or deliberate reusable/native representations.

File integrity and static composition are checked independently of engine behavior. The room scene, P07/P09 controls, evidence and inventory persistence, recorded sounds, reduced-motion behavior, iPad/browser operation and native exports still require implementation and testing.
