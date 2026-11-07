# Canonical ids: flags, items, evidence

Every id that crosses a room boundary is listed here, with the one writer and every reader. Code uses these spellings exactly (snake_case). A room may keep its own local flags (one-time reveals, arrangements, dial positions); those are listed on its cards and in `rooms.md`, never read by another room. If a new cross-room id is needed, add it here first. In code (`docs/dev/room-contract.md` section 2), `pNN_complete` is the core flag `"PNN"` (both spellings work); the transition and optional flags are core globals; the non-bool values are read with `game.value(id)`.

Five state categories (GDD 13): **completion** (`pNN_complete`, transition flags), **arrangement** (room-local), **inventory** (items below), **evidence** (notebook ids below), **presentation** (one-time reveal flags, room-local). Settings (`motion`, `soft_audio`, `text_scale`) are saved separately from story.

## 1. Derived values (never stored)

| Function | Definition | Readers |
| --- | --- | --- |
| `tide_done(n)` | 1: `p02_complete and p03_complete`. 2: `p06_complete`. 3: `p09_complete`. 4: `p12_complete`. 5: `p15_complete`. 6: `p17_complete and p18_complete`. 7: `p21_complete`. 8: `p24_complete`. 9: `p27_complete`. | everything |
| `tide()` | The lowest n in 1..9 with `not tide_done(n)`; holds at 9 after P27 (the ending reads `p27_complete` and `ending_choice`, not the tide). Tide II does not begin until `t1x_threshold_crossed` (the Tide I transition), so `tide()` returns 1 until then even if P02 and P03 are done. | objectives, hints, title cards |
| `weather_band()` | Count of `tide_done(n)` for n in 2..8, so 0..7 (GDD 5 table: 0 arrival through Tide I, 1 Tide II complete, ... 7 Tide VIII complete and Tide IX hold). Ending overrides with `ending_choice`. | every room's window, light, ambience |
| `plan_unlocked()` | `p05_complete`. Notebook station plan and fast travel. | notebook, travel |
| `room_open(id)` | See `rooms.md` exits and gates. Pure function of completion flags. | travel, exits |

## 2. Completion and transition flags (bool unless stated)

| Id | Writer | Readers |
| --- | --- | --- |
| `p01_complete` | R02 P01 (supply ON with B seated) | R02 stage, R03/R04 doors, R02 log, P03 drawer, T1X |
| `p02_complete` | R04 P02 | `tide_done(1)`, P04 |
| `p03_complete` | R03 P03 | `tide_done(1)`, P04 |
| `closure_report_filed` | R02 T1X report | R02 door, T1X threshold, R03 recorder seal (P04 gate) |
| `t1x_threshold_crossed` | R02 T1X threshold | `tide()`, P04 gate, Tide II title card, R02 corridor door returns to normal |
| `t1x_turned` | R02 T1X threshold ("turn round") | T1X card text, R02 photograph (`photo_turned` vs `photo_after`), P05 extra line, P25 BODY card wording |
| `p04_complete` | R03 P04 | P05, R03 hatch view, R11 threshold, weather (none) |
| `p05_complete` | R03 P05 | P06, `plan_unlocked()`, R01 boat |
| `p05_trace` | R03 P05 (Array of 3 movement event ids, frozen at RECORD) | R03 recorder strip, notebook, P25 BODY card |
| `movement_events` | Every room via `record_move(id)` (Array, capped at 8, consecutive duplicates collapsed) | P05 only |
| `p06_complete` | R01 P06 | R02 service door, R05, R06, P07, P08, `tide_done(2)` |
| `p07_complete` | R05 P07 | P09 |
| `p08_complete` | R06 P08 | P09, P22 (cup shelf) |
| `p09_complete` | R05 P09 | R07, R08 doors, P10, P11, `tide_done(3)` |
| `p10_complete` | R07 P10 | P12 |
| `p11_complete` | R08 P11 | P12, R08 belt state |
| `p12_complete` | R11 P12 | R11 descent, R09 upper branch, R07 return door, P13, `tide_done(4)` |
| `p13_complete` | R07 P13 | P14 |
| `p14_complete` | R07 P14 | P15 |
| `p15_complete` | R09 P15 | R10 latch (from R07), P16, `tide_done(5)` |
| `p16_complete` | R10 P16 | P17, P18 |
| `p17_complete` | R04 P17 | P19, P20, `tide_done(6)` |
| `p18_complete` | R10 P18 | P19, P20, `tide_done(6)`, R10 correspondence drawer |
| `p19_complete` | R04 P19 | P21 |
| `p20_complete` | R02 P20 | P21 |
| `p21_complete` | R03 P21 | P22, P23, R02 hook tags, `tide_done(7)` |
| `p22_complete` | R06 P22 | P24 |
| `p23_complete` | R10 P23 | P24 |
| `p24_complete` | R11 P24 | R12 door, P25, `tide_done(8)` |
| `p25_complete` | R12 P25 | P26 |
| `p26_complete` | R12 P26 | P27, pre-ending checkpoint save |
| `p27_complete` | R12 P27 | `tide_done(9)`, ending player |
| `ending_choice` | R12 P27 (String: `""`, `"sever"`, `"continue"`) | ending sequences, every room's final state |
| `endings_seen` | Ending player (Array of `"sever"`, `"continue"`; saved with settings, survives New game) | notebook, credits |

## 3. Movement event whitelist (P05 and P25)

`record_move(id)` is called by the sim when one of these actions succeeds. Nothing else is recorded. The text is what the recorder prints in Ada's tense.

| Event id | Recorded when | Printed text |
| --- | --- | --- |
| `lamp_mended` | P01 commit | Mended the lamp. |
| `log_read` | first R02 log read | Read his log. |
| `drawer_opened` | R02 drawer opens (P03 part) | Opened his drawer. |
| `recording_played` | P02 commit | Played tomorrow's recording. |
| `charts_aligned` | P03 commit | Aligned the charts. |
| `report_signed` | T1X report filed | Signed for two. |
| `held_still` | T1X threshold, continue | Held still. |
| `turned_round` | T1X threshold, turn | Turned round. |
| `zero_turned` | any P04 ZERO wheel change | Turned the zero wheel. |
| `interval_set` | any P04 INTERVAL change | Set the interval. |
| `hatch_opened` | P04 commit | Opened the hatch. |
| `stair_looked` | first click on the R03 hatch view's water | Looked down the stair. |

Golden path value of `p05_trace`: `["interval_set", "hatch_opened", "stair_looked"]` or `["zero_turned", "hatch_opened", "stair_looked"]`, depending on dial order; any recorded value is valid. P25 shows the stored value, never a recomputation.

## 4. Items (inventory)

Inventory has named slots and no capacity limit. "Durable" items are never removed.

| Id | Name in UI | Found | Used by | Consumed | Lifetime |
| --- | --- | --- | --- | --- | --- |
| `bridge_b` | Straight bridge B | R02 tray (start) | P01 | Installed on success | Notebook "installed" record |
| `spare_c` | Curved spare C | R02 tray (start) | P01 (rejected) | Never | Stays in tray |
| `pencil` | Pencil | Start | P09, P22 amendments (implicit) | Never | Durable |
| `venn_tide_sheet` | Venn's tide sheet, 17 Oct | R02 drawer (P03 part 1) | P03 | Into `composite_chart` | Notebook keeps composite |
| `inspection_lens` | Inspection lens | R02 drawer (P03 part 1) | P06, P15, any "look closer" | Never | Durable |
| `chart_clips` | Chart clips | R03 chart table (start) | P03, P16 | Never | Durable |
| `service_key` | Kitchen service key | P06 capsule | R02 service door | Retired after first use | Door stays open |
| `token_pantry_half` | Service token, pantry half | P07 | P09 | With `token_bunk_half`, only on the correct board commit | |
| `token_bunk_half` | Service token, bunk half | P08 | P09 | As above | |
| `nora_register_card` | Register card: Nora Bell | R07 specimen register (P13) | P14 (name tab copied), P18 NAME, P22 | Becomes `amended_nora_card` at P22 | Original text kept in notebook |
| `nora_frame` | Specimen frame: N. Bell | P14 | P15, P18 BODY, P24 BODY | Never | Returned after each use |
| `nora_spatial_strip` | Bearing strip: N. Bell | P15 | P18 PLACE, P24 PLACE | Never | Returned after each use |
| `contact_sheet` | Contact sheet, 18 Oct 1927 | P16 | P17, P18 | Never | Durable |
| `venn_correspondence` | Venn's correspondence | P18 (drawer opens; auto-collected) | P20 | Never | Durable |
| `amended_nora_card` | Register card: Nora Bell (amended) | P22 | P24 NAME | Never | Returned after P24 |
| `witness_bridge` | Witness bridge | P23 | P24 WITNESS, P27 CONTINUE | Never: P24 returns it to inventory automatically | Must exist for P27 |

Room-local apparatus that never enters inventory: recording bands (R04), record plates (R03), bowls (R05), lockers' belongings (R06), jars and samples (R07), toggles (R08), landing plates (R11), contact panels (R10), folders (R10), model leads (R10), Ada's three cards and the severance yoke (R12).

## 5. Evidence (notebook ids)

The notebook stores text and an image reference for each. Ids from the Intake Office slice are kept verbatim; the full list of R02 ids is in `rooms.md`. Cross-room evidence:

| Id | Written by | Read by (gate, hint or comparison) |
| --- | --- | --- |
| `duty` | R02 duty card (start) | T1X hints, P05 |
| `contract` | R02 papers (start): addressee "Miss Ada Mercer", launch silhouette, two-stripe pennant | P02, P06, P20, P25 |
| `note` | R02 note under the duty card (after P01) | P02, P03 hints |
| `handwriting` | R02 first log read | T1X, P20 |
| `watch`, `photo`, `behind` | R02 drawer | T1X, P20 board |
| `report` | T1X closure report | P20 board, P21 |
| `recording_tomorrow` | P02 | P04, P25 |
| `calibration_zero` | P02 ("Calibration zero: 4") | P04 |
| `calibration_interval` | P03 ("Interval: 3") | P04 |
| `composite_chart` | P03 | P04, P21 |
| `stair_threshold` | P04 | P12, R11 |
| `departure_record` | P05 (includes `p05_trace` text) | P06, P25 |
| `launch_mismatch` | P06 lens on window | P06 |
| `venn_address_note` | P06 capsule | Tide III objective |
| `nora_ledger` | R05 Nora's book | P07, P09, P22 |
| `nora_work_card` | R05 view B, card by the range (first look) | P14 |
| `headcount_nine` | P07 | P09 |
| `personal_cards` | P08 (Bell, Rook, Venn, Ives) | P22, ending B |
| `venn_seal` | P08 rubbing | P09, P19 |
| `amendment_rule` | R05 service board placard | P09, P22, P23 |
| `eight_retained` | P09 hidden board | P16, P18 |
| `datum_target` | P10 ("Pressure target: 2") | P12 |
| `reference_respiration` | P11 | P14, P21 |
| `nora_mass_trace` | P13 | P14, P18 |
| `nora_breath_trace` | P14 | P15, P18 |
| `nora_bearing` | P15 | P18, P24 |
| `contact_sheet_1927` | P16 | P17, P18 |
| `witness_procedure` | P17 | P19, P23 |
| `index_protocol` | P18 | P21, P23, P24 |
| `venn_answers` | P19 | P23, P26 |
| `why_ada` | P20 | P25 |
| `station_outline` | P21 | P22-P25 |
| `nora_amendment` | P22 | P24 |
| `witness_test` | P23 | P24, P25, P26 |
| `ninth_position` | P25 | P26 |
| `consequences` | P26 | P27 |

## 6. Optional discoveries (never gate anything)

| Id | Writer | Notes |
| --- | --- | --- |
| `o01_found` | R02 after P01 | Mug-mending receipt |
| `o02_found` | R05 after P06 | Nora's menu objections |
| `o03_found` | R06 after P08 | Ives's half-written letter |
| `o04_found` | R08 after P11 | Venn's dated repairs |
| `o05_found` | R09 after P15 | The ruler whose subdivisions continue |
| `o06_found` | R10 after P18 | Rook's wrapped photograph |

## 7. Intake Office slice keys and where they went

| Slice key (`OfficeSim.state`) | Full game |
| --- | --- |
| `p01_complete`, `supply_on`, `bridge_installed` | Same names. `p01_complete` is cross-room; the other two are R02-local. |
| `log_read`, `prints_seen`, `heard_silence`, `initialled`, `photo_looks` | R02-local, same names. |
| `drawer_open`, `drawer_dial` | R02-local, same names. Opening the drawer now also grants `venn_tide_sheet` and `inspection_lens` (P03 part 1). |
| `soundings_heard` | R02-local, same name, Tide I. |
| `log_rewritten`, `seat_wet`, `history`, `history_seen`, `foretold_door` | R02-local, T1X only. `log_rewritten` now needs `tide_done(1)`, not just the drawer. |
| `report_filed`, `report_fields`, `report_time`, `heard_unlatch` | `report_filed` is renamed `closure_report_filed` (cross-room). The others are R02-local. |
| `finished` | Renamed `t1x_threshold_crossed`. |
| `turned` | Renamed `t1x_turned`. |
| `contours_seen` | R02-local; contours now appear at weather band 4 (Tide V), not T1X. |
| `returns` | R02-local look-away counter; now indexed by tide, see `rooms.md` R02. |
