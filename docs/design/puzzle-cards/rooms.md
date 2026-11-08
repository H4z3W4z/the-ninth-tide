# Rooms: views, close-ups, hotspots, exits, escalation

Twelve locations, 24 base views, 34 puzzle close-ups (GDD budget 32; the two extra are slice close-ups that already exist, see `reconciliation.md`), plus two navigation strips that are not close-ups. Every view is a flat front elevation at 1448 x 1086. Hotspot positions never move between states. Every room's escalation is keyed to `weather_band()` (0 to 7) and to local completion flags from `flags.md`; nothing is keyed to time.

How to read the matrices: each row is a reachable state, entered on the first arrival after its trigger. "Notice" is the one change the returning player should see or hear first; the view gives it a short arrival hold (about 1.5 s, skippable by click) the first time only. All layers are additive overlays on the base plate unless a plate is named.

Weather bands (station-wide, GDD 5): **0** arrival through Tide I. **1** Tide II done (P06). **2** Tide III done (P09). **3** Tide IV done (P12). **4** Tide V done (P15). **5** Tide VI done (P17 and P18). **6** Tide VII done (P21). **7** Tide VIII done (P24), held through Tide IX. **A / B** ending states.

## Traversal summary

| From | Exit | To | Open when |
| --- | --- | --- | --- |
| R02 view B | Outer door | R01 | Always |
| R02 view A | Corridor door → upper passage strip | R03, R04 | `p01_complete` (before: "The corridor is pitch black. Light first.") |
| R02 view B | Service door → service passage strip | R05, R06 | `p06_complete` (uses `service_key` once; then always open) |
| R05 view B | Service hatch → lower passage strip | R07, R08 | `p09_complete` |
| R03 view C | Observation hatch | R11 view 1 (gate landing) | `p04_complete`. Descent past the gate needs `p12_complete`. |
| R11 view 2 | Return door | R07 | `p12_complete` (bidirectional from then) |
| R11 view 2 | Short stair up | R09 | `p12_complete` |
| R07 view A | Vault door | R10 | `p15_complete` |
| R11 view 2 | Lower door | R12 | `p24_complete` |

Every connection is bidirectional once open. The notebook plan (`plan_unlocked()`) allows direct travel to any visited room whose gate is open. A room with an unseen arrival change plays its arrival hold first, then travel resumes. During T1X (from the chair to the filed report) the two R02 doors are latched; see the R02 section.

Passage strips: `strip_upper` (two enamel-labelled doors, CHART ROOM and LISTENING ROOM) and `strip_service` (KITCHEN & MESS, BUNK ROOM), `strip_lower` (WET LABORATORY, MACHINE ROOM). One reusable component, three label sets. They inherit the current band's light and sound but have no puzzle content. During T1X the upper strip is replaced by the threshold view.

---

## R01 Jetty (exterior)

**Base view (1):** the station small at left, large weather, the jetty running out to the right, nine pilings plus the stump of a tenth only from band 3, a mooring bell on a post hanging too low (its lip touches the water and makes no ripple), the mooring panel on the shed wall, the lighthouse on its headland, the ruined causeway in the distance.

**Close-ups (2):** `c_mooring_panel` (P06: two pennant tallies VERIFIED / UNVERIFIED RETURN, station bells 1 to 4, printed procedure placard). `c_boat_window` (P06: the launch's cabin window seen through the lens; it shows the R03 chart table with Ada's composite chart on it).

**Hotspots:** mooring panel, mooring bell, mooring line (capsule after P06), launch (P05 to P06 only), gangway (P05 to P06 only), lighthouse, causeway, pilings, outer door (back to R02).

**Exits:** outer door to R02 view B.

**R01-local flags:** `gangway_loop` (the one-time loop at P06), `panel_tally`, `capsule_opened`.

| State | Trigger | Visual | Audio | Notice |
| --- | --- | --- | --- | --- |
| Arrival | start | Overcast but legible. The contractor's launch is already past the lighthouse (one silhouette, no animation). Ordinary wave motion (`motion`). | Sea, wind, a gull-less quiet; bell does not ring. | The bell's lip is under water and the water does not move around it. |
| Boat at the jetty | `p05_complete` and not `p06_complete` | The launch, three-stripe pennant, perfectly still while the water moves under it. Its cabin window is lit amber. | Sea continues; the launch makes no engine or hull sound at all. | The boat does not bob. |
| 1 | `p06_complete` | Boat gone (it withdrew without turning). Cloud ceiling lower, rain stipple. The capsule hangs open on the line. | Wind gains a whistle through the bell post. | The capsule on the line. |
| 2 | band 2 | Heavier rain, darker water; the far end of the jetty partly obscured. | Rain on planking. | The jetty's far end is hard to see. |
| 3 | band 3 | Rain hangs slower than the waves move. Reflections of the pilings lag their waves. A tenth piling stump past the end. | Water sound and visible chop disagree: the sound is a beat late. | The reflections are late. |
| 4 | band 4 | The horizon line is no longer level with the jetty: it tilts up toward the station. | Sea sound thins near the wall. | The tilted horizon. |
| 5 | band 5 | Sea and sky nearly one tone; the lighthouse is gone. | No wind sound, rain still visible. | Silence with rain. |
| 6 | band 6 | The lighthouse appears once, at an impossible bearing (behind the station, over the roof line). Static, not animated. | One low bell note with no visible ring. | The lighthouse is behind the station. |
| 7 | band 7 | A dark, near-featureless vertical surface stands a few hundred yards off the jetty end. Occasional slow movement across it (`motion`). The jetty, bell and panel stay clearly lit. | Pressure hum, no sea. | The surface where the sea was. |
| A | `ending_choice == "sever"` | Ordinary grey water; the real launch, two-stripe pennant, its cabin window showing its own empty cabin. | Engine, gulls, sea. | |
| B | `ending_choice == "continue"` | Not visited; the ending's final wide view stands in. | | |

---

## R02 Intake Office

The quality template. View A is the approved plate (desk, window, map, stove, hooks, coat, corridor door). View B is new: the entry wall.

**Base views (2):**
- **A, desk wall** (approved art): lamp (sprite), maintenance tray, Venn's tide log, papers (duty card over contract), green mug, chair, survey chart (map), stove, window, nine hooks, Venn's oilskin on hook 7, right-hand desk drawer, puddle below the coat, corridor door.
- **B, entry wall** (new art, same palette and registration rules): outer door to the jetty (its window shows R01's current state), service door with a brass lock (kitchen side), the comparison board (cork, three pins and a provenance stamp rail; empty until P20), a station barometer (decor that tracks the band), O01 receipt pinned by the door.

**Close-ups (8):** `c_repair` (P01, exists), `c_duty` (duty card and the contract beneath it), `c_note` (exists), `c_logbook` (exists), `c_drawer` (exists; P03 part 1), `c_report` (exists; T1X), `c_board` (P20), `c_photo` (the drawer photograph full-frame; later states swap the print).

**Hotspots (view A, from the slice, unchanged):** `lamp`, `tray`, `logbook`, `papers`, `mug`, `chair`, `map`, `stove`, `window`, `hooks`, `coat`, `drawer`, `puddle`, `door`. **View B:** `outer_door`, `service_door`, `board`, `barometer`, `receipt`.

**Exits:** view A `door` → `strip_upper` (R03, R04) once `p01_complete`; view B `outer_door` → R01; view B `service_door` → `strip_service` (R05, R06) once `p06_complete`. Left/right turn arrows between A and B.

**T1X latch:** from `seat_wet` until `closure_report_filed`, both `door` and `outer_door` are latched, announced the first time ("Latched. His rule's on the duty card: nobody leaves until the records reconcile."). The room holds every witness the report needs, the notebook and hints stay available, and nothing else is required. After filing and stepping back from the report, `door` opens itself onto the threshold. After `t1x_threshold_crossed`, both doors behave normally forever.

**R02-local flags:** the slice keys listed in `flags.md` section 7, plus `look_away_applied` (Array of change ids already applied), `board_pins` (P20 arrangement), `hook_tags_seen`.

**Evidence ids written in R02:** slice ids `duty`, `coat`, `hooks`, `map`, `chart`, `chart_tenth`, `soundings`, `contours`, `mug`, `stove`, `lamp`, `note`, `shadow`, `handwriting`, `silent`, `piling`, `prints`, `watch`, `photo`, `behind`, `rewritten`, `seat`, `knock`, `palms`, `horizon`, `eye`, `through`, `tag`, `away_mug`, `away_stove`, `away_coat`, `away_door`, `away_puddle`, `away_window`, `report`; new ids `contract`, `hook_measures`, `why_ada`, `coat_collapsed`.

**Look-away rule (from the slice, re-timed):** each change below applies on the first return to view A from any close-up or the notebook after its trigger, one per return, in this order. Once applied it stays. Each writes its evidence id.

| Change | Trigger | Evidence | What is seen |
| --- | --- | --- | --- |
| `mug` | band 2 | `away_mug` | Venn's mug full to the brim with seawater. |
| `door` | band 3 | `away_door` | Seawater seeps under the corridor door from the corridor side (the stair water). |
| `stove` | band 4 | `away_stove` | The stove full of seawater, up into the flue, door shut. |
| `window` | band 5 | `away_window` | A fourth wet hand high on the glass, as if the thing below the sill stood up. |
| `puddle` | band 6 | `away_puddle` | Wet footprints up the wall beside the door. None come down. |
| `coat` | band 7 | `away_coat` | The oilskin's hood is up and turned toward the desk; the coat has filled around shoulders that are not there. |

| State | Trigger | Plate and layers | Audio | Notice |
| --- | --- | --- | --- | --- |
| s0 Arrival | start | `office_arrival`; lamp off sprite; coat dripping (`motion`). | Sea, wind, clock, drip. | (opening) |
| s1 Lamp | `p01_complete` | Lamp light overlay, warm desk pool; window shows the lamp more than the sea. Chair shadow falls toward the lamp. | Hum; two far latches once. | The chair's shadow points the wrong way. |
| s2 Log read | `log_read` | Window: sea moves silently; the ninth piling nearer. Prints from the puddle to the drawer (after the first `puddle` look). | Sea bed drops out of the mix near the wall (`sea_fade`). | The sea has stopped making a sound. |
| s2 Drawer | `drawer_open` | Drawer open, watch and photograph; log row 7 un-stained; chart shows pencil soundings. | Short motif. | The photograph. |
| T1X | `seat_wet` (needs `tide_done(1)`) | `palms_glass` overlay (three palms below the sill); two trails (`prints_door`); hook 9 wet again; chart shows a tenth piling inked in. Doors latched. | Knock (three taps, `sudden`); breath under the room tone keyed to nothing (`motion`-free). | Palms on the outside of a second-floor window. |
| T1X filed | `closure_report_filed` | Signed report on the desk; corridor door ajar onto `threshold_corridor` + `threshold_figure` (large and legible). | Latch near; corridor breath. | The door opened itself. |
| 1 | band 1 | `office_rain`; rain frames on the panes. Coat heavier at the shoulders. Photograph in the drawer has become `photo_after` or `photo_turned` (by `t1x_turned`). | Rain on glass, wind whistle. | The photograph changed. |
| 2 | band 2 | Damp spreading under the window; look-away `mug`. | Room tone less comfortable (low drone layer). | The mug. |
| 3 | band 3 | `office_s2`. Rain slows on the glass; the horizon tips (`horizon`). Look-away `door`. | Waves visible, sound a beat late. | The horizon is not level; the room is. |
| 4 | band 4 | `office_s3` (rings, tide line). Window ring keeps its place against Ada (`eye`); chart contours close in rings on the ninth piling (`contours`, then `through`). Look-away `stove`. | Sea absent near the wall; deep note when the contours are seen. | The ring on the water follows her. |
| 5 | band 5 | Window nearly toneless. Look-away `window`. | External weather sound gone though rain is visible. | The fourth hand. |
| 6 | band 6 | Brass tags on hooks 1 to 8 stamped with Ada's settings (ZERO 4, INT 3, PRESS 2, BEARING 3, and her height and reach); the ninth tagged A.M. at her collar height (`tag`, `hook_measures`). Look-away `puddle`. P20 board pinned and stamped. | Clock stops (the tick drops out and stays out). | Her measurements on the hooks. |
| 7 | band 7 | `office_ominous` plate. Desk stays lit and fully usable (raised ambient per owner note). Look-away `coat`. | Pressure hum under everything. | The coat has shoulders. |
| A | sever | Office in grey daylight; coat an ordinary wet coat; Ada takes the corrected record from the desk. | Sea and gulls return. | |
| B | continue | Coat collapses into an ordinary garment (`coat_collapsed`). Window: the vast dark surface; desk lit. | Silence from Venn's funnel elsewhere; clock restarts. | |

---

## R03 Chart Room

**Base views (3):**
- **A, chart table:** bone-coloured registration table, sheet 1 (lighthouse cross, north arrow, 17 Oct), clipped worked example, `chart_clips` in a tin, empty clip marked "sheet 2 of 2: with E.V.", the station plan on the wall (P21 later), compass rose.
- **B, recorder wall:** the tide recorder (copper float, polished CALIBRATE lever, pen over a motionless bone-paper drum), ZERO and INTERVAL wheels under a paper closure seal (until `t1x_threshold_crossed`), three left-to-right RECORD slots and the plate rack (P05), a sea window.
- **C, hatch wall:** the observation hatch with three scratches on its frame, an outer window beside it showing solid seawater at the hatch's own level.

**Close-ups (3):** `c_registration` (P03), `c_recorder` (P04 dials, P05 slots, the printed trace strip), `c_plan` (P21).

**Hotspots:** A: `sheet_table`, `clip_tin`, `empty_clip`, `plan_wall`, `compass`. B: `recorder`, `pen_drum`, `seal`, `plate_rack`, `sea_window`. C: `hatch`, `hatch_scratches`, `outer_window`.

**Exits:** back to `strip_upper` (R02, R04). C `hatch` → R11 view 1 once `p04_complete`.

| State | Trigger | Visual | Audio | Notice |
| --- | --- | --- | --- | --- |
| Arrival | `p01_complete` | Overcast sea window. The pen scratches against a drum that does not turn (`motion`). | Scratch with no paper movement; sea. | The pen moves, the drum does not. |
| P03 done | `p03_complete` | Composite chart clipped; the curve crosses band 3 and echoes the hatch scratches. | Clip snap. | |
| Threshold arrival | `t1x_threshold_crossed` | Closure seal on the recorder is broken (Ada did not touch it); pen trace now reads her report figures. Title card "Tide II: The Boat at the Window" plays here. | Motif. | The seal is broken from the inside. |
| P04 done | `p04_complete` | Hatch open onto the dry stair; outer window beside it still full of seawater at the same level. Pressure gate visible below. | No water sound from the hatch at all. | Water in the window, air in the hatch. |
| P05 done | `p05_complete` | Recorder strip printed with her three moves and the extra line. | Signal relay clack, far bell. | The extra line. |
| 1-2 | bands 1-2 | Rain on the sea window, darker water. | Rain. | |
| 3 | band 3 | Pen reports "VIS 0.0 NM" while the window still shows the sea. | | The pen reports what cannot be seen. |
| 4 | band 4 | Compass lines on sheet 1 curve toward the standing position in front of the table. | | The compass lines bend toward her. |
| 5 | band 5 | Sea window toneless; pen writes "SEA STATE: ATTENDING". | Recorder scratch only. | |
| 6 | band 6 (P21 done) | The station plan has resolved into a seated human outline (permanent, from P21). | | The plan is a body. |
| 7 | band 7 | Sea window: the dark surface, close. Hatch seawater now stands vertical in the outer window with a slow line across it (`motion`). | Pressure hum. | |

---

## R04 Listening Room

**Base views (2):**
- **A, funnel wall:** brass ear trumpets whose pipes vanish into sealed plaster, a polished stool, the cylinder phonograph with its spindle and three loose bands (C, A, B) in a felt tray, the transcript printer.
- **B, channel board:** motor switch, live channels A and B, dead channel C (socket labels: one, two and three cuts), WITNESS key, a two-track mixer with waveform window, the speaker funnel above the board.

**Close-ups (3):** `c_spindle` (P02), `c_mixer` (P17), `c_channels` (P19).

**Hotspots:** A: `funnels`, `plaster`, `stool`, `spindle`, `band_tray`, `printer`. B: `motor`, `channel_a`, `channel_b`, `channel_c`, `witness_key`, `mixer`, `speaker`.

**Exits:** `strip_upper` (R02, R03).

| State | Trigger | Visual | Audio | Notice |
| --- | --- | --- | --- | --- |
| Arrival | `p01_complete` | Cork walls, wax dust, warm indicator lamps. | Room tone; a reassuring motor click; a human throat clearing from funnel 3 on first entry only. | The throat clearing. |
| P02 done | `p02_complete` | Recording on the spindle; transcript printed. | Venn's voice (recorded). | |
| 1 | band 1 | Indicator for channel C is dark; A and B lit. | Wind leaks through funnel 5, which points into plaster. | Weather through the wrong channel. |
| 2 | band 2 | Condensation inside the funnel bells. | Rain through funnel 2; none outside. | |
| 3 | band 3 | Wax dust lies in rings on the stool. | The weather leaks stop entirely. | Silence from every funnel. |
| 4 | band 4 | Funnels have all turned a few degrees toward the stool (static, not animated). | | The funnels point at the stool. |
| 5 | band 5 (P17 done) | Mixer shows two tracks aligned. | Dead channel C has room tone; a breath once. | Channel C has presence. |
| 6 | band 6 (P19 done) | Channel C indicator dark; the speaker funnel's mouth is wet. | Silence; Venn's last answer has ended. | |
| 7 | band 7 | Plaster bulges slightly around funnel pipes (flat overlay, no gore). | Pressure hum through the funnels. | The wall is breathing out. |
| B | continue | Venn's funnel silent; all indicators off. | | |

---

## R05 Kitchen and Mess

**Base views (2):**
- **A, mess table:** long cloth with nine place marks (eight with initials, one with a square mark), eight initialled bowls and one unsigned bowl with a square repair patch, spoons, Nora's towel folded by her repaired cup's empty ring (the cup itself is in R06), serving tally wheel (0 to 12) on the end of the table.
- **B, kitchen:** range, Nora's provisioning book on its lectern, the shift board (official register: eight names) with its amendment slot and seal selector, the service drawer, the service hatch to the lower passage (P09), Nora's 1927 work card with her calibration breathing trace on a nail by the range (`nora_work_card`), O02 menu objections on another.

**Close-ups (3):** `c_table` (P07), `c_ledger` (Nora's book; evidence for P07, P09, P22), `c_service_board` (P09).

**Hotspots:** A: `place_1` to `place_9`, `bowl_stack`, `unsigned_bowl`, `tally`, `spoon`, `towel`. B: `range`, `ledger`, `shift_board`, `service_drawer`, `service_hatch`, `work_card`, `menu_note`.

**Exits:** `strip_service` (R02, R06); B `service_hatch` → `strip_lower` (R07, R08) once `p09_complete`.

| State | Trigger | Visual | Audio | Notice |
| --- | --- | --- | --- | --- |
| Arrival | `p06_complete` (band 1) | Cool light, rain on the high window. Nine spoon depressions in the cloth, eight places set. | Rain; a kettle that is not on the range ticks as it cools. | Nine spoon marks, eight bowls. |
| P07 done | `p07_complete` | Table set for nine. The unsigned spoon lifts half an inch, waits, lowers (`motion`; still pose: the spoon raised in a single frame, then down). | Spoon on china, very small. | |
| P09 done (band 2) | `p09_complete` | Duplicate board visible behind the first; condensation fogging it after Ada copies it. Condensation on bowls travels inward toward the ninth place. | Rain heavier; the service hatch's draught. | Condensation moving inward. |
| 3 | band 3 | A meal trace: one bowl (the ninth) has a fresh tide line of soup. | | Someone has eaten. |
| 4 | band 4 | The ninth chair is pulled out. | | |
| 5 | band 5 | The spoon lifts again whenever Ada leaves a close-up here (once per visit). | | |
| 6 | band 6 | Nora's towel is damp and refolded the other way. | Kettle tick returns. | |
| 7 | band 7 | Warm light from the range is the only warm light in the station; the table remains fully readable. | | |
| B | continue | The repaired cup's ring on the cloth is warm (steam wisp, `motion`). | | |

---

## R06 Bunk Room

**Base views (2):**
- **A, bunks and lockers:** narrow beds, luggage without owners, four open lockers labelled BELL, ROOK, VENN, IVES with a shelf each, four other labelled and closed staff lockers (scenery), a shelf of four loose belongings (cup, calipers, pencil holder, glove), personal cards on each locker door.
- **B, curtain wall:** curtain partition, wall calendar (dates never change; names beneath them do), Doane's bunk with Venn's pencil shelf, a small comparison writing-slope (P22), the cup's marked shelf (after P08).

**Close-ups (2):** `c_lockers` (P08), `c_slope` (P22).

**Hotspots:** A: `locker_bell`, `locker_rook`, `locker_venn`, `locker_ives`, `belongings_shelf`, `venn_bunk`, `luggage`. B: `curtain`, `calendar`, `pencil_shelf`, `slope`, `cup_shelf`, `ives_letter` (O03 after P08).

**Exits:** `strip_service` (R02, R05).

| State | Trigger | Visual | Audio | Notice |
| --- | --- | --- | --- | --- |
| Arrival | `p06_complete` (band 1) | Indirect grey light; curtain still. | Rain on the roof; bed springs settle once. | |
| P08 done | `p08_complete` | Belongings in their lockers. After Ada turns toward the door (any exit click), Venn's pillow depresses as she looks back (one pose change, on her next return). | Spring creak. | Venn's pillow is dented. |
| 2 | band 2 | Calendar names beneath the dates now read the eight staff in index order. | | The names moved. |
| 3 | band 3 | A second indentation, on Doane's bunk. | | |
| 4 | band 4 | Curtain hangs as if someone stands behind it (flat shadow silhouette, legible). | Curtain rings settle. | The curtain's shape. |
| 5 | band 5 | Four indentations. | | |
| 6 | band 6 | Eight indentations; every bed occupied by nothing. | Eight springs settle, in sequence. | Every bed. |
| 7 | band 7 | The calendar's names are gone; one line beneath today: A. MERCER. | | Her name on the calendar. |
| A | sever | All indentations rise, slowly, one by one. | | |

---

## R07 Wet Laboratory

**Base views (2):**
- **A, tank wall:** flotation tank, the brass datum line on the wall, tilt rack with three sealed jars A, B, C, the reference socket for the stair circuit, the vault door (latched until P15), the return door to R11 (after P12), washbasin.
- **B, bench:** the balance with an empty control tray, three sample cards (N, T, H), the specimen register (card drawer), the frame stand, the sealed fogging jar with its inscription, sample rack.

**Close-ups (3):** `c_tilt_rack` (P10), `c_balance` (P13), `c_frame` (P14).

**Hotspots:** A: `tank`, `datum_line`, `tilt_rack`, `jar_a`, `jar_b`, `jar_c`, `reference_socket`, `vault_door`, `return_door`, `basin`. B: `balance`, `control_tray`, `sample_cards`, `register`, `frame_stand`, `sealed_jar`, `sample_rack`.

**Exits:** `strip_lower` (R05, R08); A `return_door` → R11 view 2 once `p12_complete`; A `vault_door` → R10 once `p15_complete`.

| State | Trigger | Visual | Audio | Notice |
| --- | --- | --- | --- | --- |
| Arrival | `p09_complete` (band 2) | Jars hold seawater at three different angles. Shells in the sample rack. | Drip, tank hum. | Water at different angles. |
| P10 done | `p10_complete` | Jar C installed; its water leans toward Ada's standing position when she lets go (one pose). | | The water leans to her. |
| 3 | band 3 | Tank reflection lags the room by one pose. View A: a hard, flat water surface across the whole room at the DATUM; below it everything is washed sea-glass and laid 6 px to the side, the jars, tank, doors and other hotspot art registered and crisp on top (`datum_water_r3`). View B (bands 3-4): the tide mark on the bench is a clear sea-glass water line. | | "The water's at the datum line. It stays there when I move. It isn't in the room. The room is in it." (once) |
| P13 done | `p13_complete` | Thumb impression in the empty control tray. | | A thumb in an empty tray. |
| P14 done | `p14_complete` | Sealed jar fogs on its inner surface; inscription legible: "Retention is not resuscitation." | Breath-like hiss, once (`sudden`). | |
| 4 | band 4 | The shells in the rack have aligned into a curve like a throat's rings. Vault door ajar. | | The shells line up. |
| 5 | band 5 | Every jar's surface tilts toward the vault door. | | |
| 6 | band 6 | Tank surface stands at an angle, flat and still, like a pane. | No tank hum. | |
| 7 | band 7 | Jars' surfaces all face Ada wherever she clicks (static pose per hotspot). | | |

---

## R08 Machine Room

**Base view (1):** belts and flywheel, the valve board (four labelled toggles SUPPLY, GATE, RETURN, INDEX and the PUMP lever, with the maintenance drawing above), the black diaphragm behind restraining bolts, dust on the floor, O04 repair tags.

**Close-up (1):** `c_valves` (P11, with the circuit preview overlay).

**Hotspots:** `valve_board`, `drawing`, `belt`, `diaphragm`, `bolts`, `dust`, `repair_tags`, `nameplate` (after P11).

**Exits:** `strip_lower` (R05, R07).

| State | Trigger | Visual | Audio | Notice |
| --- | --- | --- | --- | --- |
| Arrival | `p09_complete` (band 2) | Belts running (`motion`); diaphragm moves with them. | The mechanical cycle, long and even, heard on the strip before entering. | The cycle has a pause in it. |
| P11 done | `p11_complete` | One belt stopped. The diaphragm keeps inhaling. Nameplate exposed: "REFERENCE RESPIRATION." Next inhalation pulls dust horizontally across the floor (`motion`; still pose: dust streaks drawn). | Belt winds down; the breath continues alone. | It breathes without the belt. |
| 3 | band 3 | Dust lies in lines pointing to the diaphragm. | | |
| 4 | band 4 | The bolts' paint is cracked; the diaphragm has moved a finger's width further out. | | |
| 5 | band 5 | The breath's rhythm is two short, pause, one long (Nora's trace). | | It is breathing like her. |
| 6 | band 6 | All belts still. | Only breath. | |
| 7 | band 7 | Diaphragm surface reflects the room, slightly late. | | |

---

## R09 Lantern Gallery (exterior, roofed)

**Base views (2):**
- **A, lens:** the signal lens, three apertures with plates LAND 1, SEA 2, STATION 3, the scope with its frame mount, the reference diagram.
- **B, rail:** the gallery rail, glass panels, the horizon; O05 ruler on the sill (after P15).

**Close-up (1):** `c_scope` (P15).

**Hotspots:** A: `lens`, `aperture_1`, `aperture_2`, `aperture_3`, `scope`, `diagram`. B: `rail`, `glass`, `horizon`, `ruler`.

**Exits:** short stair down to R11 view 2.

| State | Trigger | Visual | Audio | Notice |
| --- | --- | --- | --- | --- |
| Arrival | `p12_complete` (band 3) | Conventional horizon; rain slow on the glass; weather does not touch the rail (it is dry). | Wind is heard but the rail's pennant hangs dead. | The rail is dry. |
| P15 done (band 4) | `p15_complete` | The sea stands upright outside the glass, carrying reflections of the rooms behind Ada (the office desk lamp visible as a warm point). One slow line passes across it like a lid (`motion`; still: the line drawn mid-pass). | One very low tone. | The horizon stands up. |
| 5 | band 5 | The surface fills the glass edge to edge. | | |
| 6 | band 6 | The lighthouse appears in the surface, wrong way up. | | |
| 7 | band 7 | Surface with no edge; the instrument housing occupies less than a tenth of it. | Pressure. | |

---

## R10 Records Vault

**Base views (2):**
- **A, shelves:** low shelves receding by repetition and occlusion (flat elevation, depth by stacking), hanging index cards, contact table with four panels B, D, A, C and the opaque registration cover, wall clock (stopped at the session time).
- **B, catalogue wall:** the drawer marked STAFF (opens onto a dry mouth-shaped aperture lined with index tabs, motionless) with a tray before it, the three-folder cabinet BODY / PLACE / NAME with its comparison tray and training release, the Index model (INPUT, COPY, WITNESS terminals, TEST AMENDMENT), Venn's correspondence drawer, O06 wrapped photograph.

**Close-ups (3):** `c_contact` (P16), `c_folders` (P18), `c_model` (P23).

**Hotspots:** A: `shelves`, `index_cards`, `contact_table`, `wall_clock`, `photographs`. B: `staff_drawer`, `tray`, `folders`, `model`, `correspondence_drawer`, `wrapped_photo`.

**Exits:** back to R07 view A.

| State | Trigger | Visual | Audio | Notice |
| --- | --- | --- | --- | --- |
| Arrival | `p15_complete` (band 4) | Shelves deeper than the plan. Photographs of chairs occupied by retouched blank areas. | Paper settling far off, further than the room. | The shelves continue. |
| P16 done | `p16_complete` | Contact sheet assembled; the last face looks away toward the witness position. | | |
| P18 done (with P17: band 5) | `p18_complete` | Model Index closed then released; correspondence drawer open. STAFF aperture tabs riffle once (`motion`). | Paper breath, once. | |
| 5 | band 5 | A ninth photograph on the wall: an empty chair, not retouched. | | |
| P23 done | `p23_complete` | Model stamped OPEN; witness bridge gone from it. | | |
| 6 | band 6 | Index card at the front of the hanging file: MERCER, A. Blank. | | Her card. |
| 7 | band 7 | The STAFF aperture is open slightly wider. Still motionless. | | |

---

## R11 Dry Stair

**Base views (2):**
- **1, gate landing:** limewashed steps going down through a plane of water that does not wet them; the pressure gate (gauge 0 to 5, landing plate pair slots, three landing plates of which two carry bracket marks), gate placard.
- **2, the landing:** return door to R07 (left), short stair up to R09 (right), the lower door to R12 with three evidence frames and a witness socket and an automatic COPY port; overhead, the underside of the office floor with an empty pair of shoes beneath the desk.

**Close-ups (2):** `c_gate` (P12), `c_chamber_door` (P24).

**Hotspots:** 1: `steps`, `water_plane`, `gate`, `gauge`, `plates`, `placard`. 2: `return_door`, `upper_stair`, `lower_door`, `ceiling`, `shoes`, `bell_sound`.

**Exits:** 1 → R03 view C (always once `p04_complete`); 1 → 2 once `p12_complete`; 2 → R07, R09 once `p12_complete`; 2 → R12 once `p24_complete`.

| State | Trigger | Visual | Audio | Notice |
| --- | --- | --- | --- | --- |
| Threshold | `p04_complete` (band 0-3) | Steps through water; gate closed. | No drip at all. | Dry steps through water. |
| P12 done (band 3) | `p12_complete` | Gate open; water rests vertically across the gate like thick glass. Landing view open. | A bell sounds upward through the stair; its clapper is missing (the bell hangs visibly empty). | The bell has no clapper. |
| 4 | band 4 | Shoes beneath the office desk are wet. | | |
| 5 | band 5 | The water plane carries reflections of the vault shelves. | | |
| 6 | band 6 | The shoes are side by side, facing the stair. | Bell from below now. | Sound from the wrong direction. |
| P24 done (band 7) | `p24_complete` | Lower door open; worn finger marks on its never-accessible side. | | Finger marks. |

---

## R12 Observation Chamber

**Base views (3):**
- **A, the chair:** the chair facing the instrument, armatures ending at the parts of a seated body, the window: the surface, so close it has no edge.
- **B, the record frames:** eight closed staff indicators, three frames BODY / PLACE / NAME, the open witness terminal, Ada's three cards in a rack, the COPY port.
- **C, the routing wall:** routing plates SEVER and CONTINUE with preview lamps and PREVIEW keys (P26 shows each route in the window; the card holder stands empty), the severance handle, the yoke tray (severance yoke), the witness bridge seat in Ada's terminal.

**Close-ups (3):** `c_frames` (P25), `c_routing` (P26), `c_final` (P27).

**Hotspots:** A: `chair`, `armatures`, `window`. B: `indicators`, `frame_body`, `frame_place`, `frame_name`, `terminal`, `card_rack`, `copy_port`. C: `plate_sever`, `plate_continue`, `cards`, `handle`, `yoke_tray`, `bridge_seat`.

**Exits:** back to R11 view 2 until the P27 confirmation.

| State | Trigger | Visual | Audio | Notice |
| --- | --- | --- | --- | --- |
| Arrival | `p24_complete` (band 7) | One blank frame already labelled ADA MERCER. The surface outside, edgeless. | Eight faint indicator hums; pressure. | Her name on a frame. |
| P25 done | `p25_complete` | Witness terminal lit; Counter output on the strip. | Venn's line through the terminal, last time. | |
| P26 done | `p26_complete` | The surface withdraws a fraction (visible margin of darker water at the window's edge). | Pressure eases a semitone. | It made room. |
| A / B | P27 | See ending sequences in `P27.md`. | | |
