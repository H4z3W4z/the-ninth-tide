# T1X: The Closure Report (Tide I to Tide II transition)

Not one of the 27 numbered puzzles. It is the mandatory sequence that closes Tide I in R02 and opens Tide II. It is the Intake Office slice's chain from the log rewrite to its end card, kept almost verbatim and re-triggered by Tide I completion. Target 6 to 9 minutes.

## Room

R02 Intake Office, view A. Close-ups `c_logbook`, `c_report`. The threshold replaces `strip_upper` behind the corridor door once.

## Tide

End of Tide I. `tide()` stays 1 until `t1x_threshold_crossed`.

## Requires

`p02_complete` and `p03_complete` (that is, `tide_done(1)`). Within R02: `log_read`, `drawer_open` (always true by then, since P03 needs the drawer).

## Sequence and gates

1. **Call back.** On `tide_done(1)` the objective becomes "Something on the desk has changed. Go back to the office." Entering R02 view A, the first time: the sound of a pen on paper from the desk, no pen visible.
2. **The log rewrites itself.** Next `logbook`: sets `log_rewritten`, writes `rewritten`. New rows in Ada's hand: "She reads this line." / "She looks at the chair." / "HW 9.9 m. Observer located." (slice `LOG_LATER`, unchanged). Lines: "There are new lines. In my hand. The ink is still wet." "'She looks at the chair.' I haven't looked at it yet." "HW nine point nine. Nothing in forty years of this log has come above four and a half." "I check the date on it. Tomorrow."
3. **The chair.** `chair`: sets `seat_wet`, writes `shadow`, `seat`, `knock`. Seat wet and warm. Three taps on the glass (`sudden`), low down, below the sill, "where the wall goes straight down into the water". Both doors latch (announced on first try).
4. **The room keeps her.** From `seat_wet` until filing, the log writes the first three distinct things she does, in her hand (slice `HISTORY_TEXT`, `HISTORY_MAX` 3), plus up to three wrong filings. Re-reading the log once shows them ("It has written down what I did since the chair. In the order I did it." "It was writing while I did it.").
5. **The closure report.** `papers` opens `c_report`.
6. **Threshold.** Back from the filed report: the corridor door unlatches itself ("Behind me, the corridor door unlatched itself."). `door` opens the threshold.
7. **Hold still or turn round.** Then the Tide II title card.

## Evidence (all inside R02, all in the notebook)

| Field | Answer | Witness | Where |
| --- | --- | --- | --- |
| Pilings, Greywake jetty (8 / 9 / 10) | **10** | `chart_tenth`: after `seat_wet`, the survey chart shows a tenth piling inked in past the jetty's end. | `map` hotspot. |
| Observers on station (1 / 2 / 3) | **2** | `prints`: after `seat_wet`, two trails from the puddle: one to the drawer, one from the drawer to the door, Ada's size. | `puddle` hotspot. |
| High water, 18 Oct, evening (four dials) | **19:34** | `handwriting` and the log margin "HW to HW, 12 h 21 m. It never varies. — E.V."; last time in the log 18 Oct 07:13. 07:13 + 12:21 = 19:34. | `c_logbook`. |
| Height of that water (4.4 m / 9.9 m) | **9.9 m** | `rewritten`: "HW 9.9 m. Observer located." | `c_logbook`. |

## Solution

Set pilings 10, observers 2, time dials 1-9-3-4, height 9.9 m, press **Sign and file**. Sets `closure_report_filed`, writes `report`, records move `report_signed`. "I sign it. A. Mercer, observer." "The two is in my hand. I wrote it without counting."

## Wrong answers

Never says which line is wrong. Time near-misses answer specifically (slice `REPORT_TIME_MISSES`): 07:13 "That's the morning tide. His rule gives the next one." 18:52 "That was the lamp. His rule runs on from the last time in the log." 19:13 "Twelve hours on. His tides don't keep to twelve." 19:33 / 19:35 "One minute out. He never was." Anything else: "Something here doesn't reconcile." The first three misses are written into the log in her hand ("She gets it wrong." / "She gets it wrong again. The room is patient." / "She guesses."). First miss: "Somewhere on the desk, a pen is moving." Third: "It is writing down my mistakes. It wants the right numbers more than I do."

## Threshold

The corridor goes on further than the station does and breathes with the tide (slice `THRESHOLD_LINES`, unchanged). To go on she holds still: cursor within 4 px for 3 s after the third line, or the 18 s fallback, then "I hold my breath. So does the sea." and the doorway is clickable. Alternative: **Turn round** to the chair.

- **Continue:** records `held_still`. Sets `t1x_threshold_crossed`. The corridor resolves into the ordinary passage; Ada arrives in R03 view B. The R03 closure seal is broken from the inside.
- **Turn round:** records `turned_round`, sets `t1x_turned` and `t1x_threshold_crossed`. One held pose: someone sits in Venn's chair, pale and too tall, still (`threshold_figure` large and legible, no movement, `exhale_near` softened by "Soften sudden sounds"). Ada turns back; the doorway is the ordinary passage; she arrives in R03 view B. Not an ending and not a branch: both paths converge.

## Title card (the slice end card, repurposed)

Photograph: `photo_after` (continue) or `photo_turned` (turn). Two log rows write themselves (slice `end_rows()`): continue: "18 Oct — 19:34 — HW 9.9 m — Observer located." then, in Venn's hand, "19 Oct — 07:55 — HW 4.4 m — Observer: E. Venn." Turn: "18 Oct — 19:34 — She turns round." then, in her hand, "19 Oct — 07:55 — HW 4.4 m — Observer: A. Mercer." Then "Observers on station: 1." Then (only if every R02 observation reachable so far is in the notebook) "Nothing in the room went unrecorded." Then **"Tide II: The Boat at the Window"** replaces "Tide I continues." Click to dismiss.

## Hints

- Return to office: "Something in the office has changed." / "The duty card said reconcile the records. The log is a record, and it isn't finished." / "Go back to the Intake Office and open the tide log."
- Chair: "The log has told you what you do next." / "'She looks at the chair.'" / "Inspect the chair behind the desk."
- Report: "Each line has a witness. The evening's high water has to be worked out, not read." / "Pilings: the chart as it is now. Observers: count the trails from the puddle. The evening tide: Venn's margin rule, from the last time in the log. The height: what the log wrote for itself." / "Pilings 10. Observers 2. High water 19:34 (07:13 plus 12 h 21 m). Height 9.9 m. Then sign it."
- Filed: "Put the report down." / "Step back from the desk." / "Use Back."
- Leave: "The door has unlatched itself." / "The corridor door is on the right." / "Use the door."
- Threshold: the ladder steps aside; "Hold still. Listen to it."

## Notebook

`report`: "Closure report, filed in my hand: pilings 10; observers on station 2; high water 18 Oct 19:34, 9.9 m." Also `rewritten`, `seat`, `knock`, `palms`, `chart_tenth`, `prints` as in the slice.

## Reveal and dread

The record writes her before she acts, and wants the right numbers more than she does. She certifies two observers without counting. Palms on the outside of a second-floor window above the sea. The corridor is longer than the building and breathes.

## Room states after

R02 enters T1X then T1X filed (see `rooms.md`). After `t1x_threshold_crossed`: doors normal; history rows stay in the log; R03 seal broken, ZERO and INTERVAL wheels exposed; P04 available. The drawer photograph swaps on the next band.

## Tests

Full golden path into Tide II; every report field combination; each time near-miss; three logged misses max; latch on and off; nothing outside R02 required during the latch; threshold stillness, fallback and phase lock (slice tests carried over); both turn and continue converge on `t1x_threshold_crossed` with the same reachable rooms and flags apart from `t1x_turned`; save and resume at each step; P04 refuses until `t1x_threshold_crossed`.
