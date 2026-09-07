# Kitchen and Mess: art and integration handoff

## Scope and reference

R05 is the station's domestic center: a supper prepared carefully for people whose names no longer agree with the official count. Its horror comes from evidence of ordinary care. The room opens after P06, when Tide II has completed. It does not need a playable arrival-through-Tide-I appearance.

**Status: R05 graphics pack complete; integration pending.** This pack covers Kitchen and Mess illustration, reachable weather states, independent objects, readable evidence and exact graphics for P07 and P09. Mike approved [kitchen-room-master-v1.png](../art/concepts/kitchen-room-master-v1.png) with “Looks good. Proceed.” Use this 1448 × 1086 reference: blue service door and stove at left, warm pendant lamp, compact service board, kitchen shelves, long supper table and prominent right-hand sea window. It does not implement R05, either puzzle, sound, animation, save behavior or navigation. The dated P01/P03 implementation baseline and rendered map-input failure remain in [CODEX-HANDOFF.md](CODEX-HANDOFF.md).

The eight signed staff bowls and unsigned square-patched bowl are supper evidence. **Nora's personal repaired cup belongs to R06's P08/P22 sequence.** The Kitchen provisioning page carries its repair sketch; do not add a second physical cup, relocate the Bunk Room item or require a new retrieval visit for P22. The square-patched supper bowl is also the identifying Kitchen object used by P15's later lantern reflection. Keep those two repairs visually distinct.

**Delivered files:** 84 local PNG assets, comprising the fixed clean base, five generated transparent props and 78 authored SVG/PNG pairs. Seven existing R04 exterior plates are referenced without duplication. These counts exclude the approved master, rejected drafts and composition proofs.

## Pack resources

| Resource | Use |
| --- | --- |
| [Approved master](../art/concepts/kitchen-room-master-v1.png) | Composition and material reference |
| [Asset inventory](kitchen-inventory.md) | Deliverables, measured content regions and reuse decisions |
| [R05 manifest](../assets/kitchen/manifest.json) | Placements, source regions, layer order, state predicates and inspection bindings |
| [Authored specification](../assets/kitchen/authored-spec.json) | Exact P07/P09 controls, document copy and deterministic correspondences |
| [Composed review](../art/kitchen-review/composed/index.html) | Offline art-layout and state comparison, separate from gameplay |
| `tools/build_kitchen_vectors.py` | Rebuild editable puzzle and evidence SVG/PNG sources |
| `tools/build_kitchen_manifest.py` | Rebuild the measured R05 inventory and placement data |
| `tools/build_kitchen_review.py` | Rebuild the offline gallery and composition proofs |

## Composition and state contract

Use one fixed, front-facing room base and the measured manifest's source regions and target rectangles. Reuse the R04 weather source plates through the Kitchen manifest's explicit source-to-pane mapping. Layer the chosen exterior only through its window glazing; do not use a generated full-room mood study as a replacement for the player's actual arrangement. Preserve the wall, furniture, window frame and hotspot coordinates across visits.

Generated illustration supplies materials and silhouettes. Exact initials, quantities, repair correspondences, seal cuts and printed amendments come from the editable SVG/PNG sources. Room-scale papers invite inspection; their readable close-ups and transcripts carry the clues. Preserve the same selected object and puzzle state when closing an inspection view or leaving the room.

The room begins with all nine bowls available in three nested stacks; the exact P07 inspection begins with nine empty place areas and serving tally 8. The gallery offers stacked and fully arranged room poses; implementation must derive actual bowl positions from saved puzzle state, including partial arrangements. A fully laid table alone does not complete P07 without the correct tally and comparison. The approved master's eight-bowl study is not the initial puzzle state.

Use `r05_bowl_plain` for each room-scale bowl and the native `r05_square_patch` for the repaired ninth bowl. The spoon uses the registered authored `r05_spoon_rest` and `r05_spoon_raised` poses. The other generated cutouts are `r05_stockpot`, `r05_towel`, `r05_ledger_closed` and `r05_drawer_open`. Rejected generated spoon/repair attempts are review history, not production sprites. Fixed shelving, range, apron, pendant and other static domestic equipment remain in the clean base.

Keep global weather, supper arrangement, drawer state, service tokens and amendment state independent. A late weather override cannot arrange bowls, award a token, amend a record or open service access. Art-review controls must not change completion flags. Late tints and dampness sit below evidence and interactive overlays so every clue remains legible.

## Reachable environmental states

| Appearance | Trigger | Returning player notices |
| --- | --- | --- |
| 02, rain | First entry after P06 | Lower cloud, rain against the glass and an interrupted domestic routine |
| 03, storm | P09 complete | Heavier rain, darker water and damp spreading beneath the window |
| 04, suspended | P12 complete | Rain appears held while reflected movement disagrees |
| 05, upright | P15 complete | Compressed horizon and a mismatched reflection; the square-patched bowl remains identifiable |
| 06, silent | P17 and P18 complete | Distant exterior detail disappears; future audio removes the weather sound despite visible rain |
| 07, wrong bearing | P21 complete | Darkness presses close to the window and familiar bearings cease to agree |
| 08, surface | P24 complete | A near-featureless dark surface fills the exterior |
| Hold 08 | Tide IX before commitment | Stillness holds until the ending decision |

Resolve the latest achieved milestone on load and re-entry. Never replay skipped earlier weather states. Local reveals use their own persisted event flags: P07's spoon motion is a one-time response to the supper reconstruction, while P09's duplicate board is copied before condensation crosses it. Static art provides poses and overlays; timing, sound, interpolation and accessible reduced-motion presentation require implementation.

## P07: Nine Appetites

**Requires P06.** P08 is a parallel Bunk Room investigation and is not a prerequisite for supper reconstruction.

Nora's ledger shows eight signed meal chits, nine portions served and no leftovers. Place the eight initialed bowls at matching cloth marks and the unsigned square-patched bowl at the ninth square mark. Set the serving tally to **9** and compare it with the official **8**. Exact identifiers and correspondence geometry come from `authored-spec.json` under `panels.P07`. NB, SR and TI represent established staff; AL, CM, DH, EP and JW are declared production initials for the other five signed settings, not newly named cast members. Do not ask the player to decipher generated initials or estimate how many servings fit in a painted bowl.

Provide generous snap regions, a selected-item indication and tap placement as an alternative to dragging. Wrong placements or tally values preserve the objects and explain whether places or portions disagree. Closing the inspection preserves the partial arrangement and current tally. The unchanged official eight is an observed record, not a control to increase.

On successful comparison, unlatch the service drawer and make the **pantry token half** available. Preserve Nora's identification of Venn as the extra diner and the discrepancy between nine served and eight officially recorded. The unsigned spoon lifts slightly, waits and lowers once. A reduced-motion equivalent should expose the same observation without requiring the player to perceive animation.

Keep the ledger, signed-chit count and repair correspondence inspectable from first entry. Gate the solved conclusion, released token and Nora's extra-diner identification to P07. Re-entering in later weather does not relock the drawer, replay the spoon or remove already copied evidence.

## P09: The Meal They Removed

**Requires both P07 and P08.** Kitchen completion alone cannot unlock the board's successful service release. P08 supplies the bunk token half and Venn's three-cut seal rubbing.

Fit the pantry and bunk token halves. Keep the original official **8** visibly intact and append **+1 / VENN / present**, then use the **three-cut** seal selector. The correction rule must be readable before committing: retain the original entry and identify the omitted person. Exact board controls, token fit and seal marks derive from `authored-spec.json` under `panels.P09`.

Wrong amendments and seal choices remain editable. Attempts to erase or overwrite the official entry explain the amendment rule. Token halves are consumed together only by the successful release, never by an incorrect placement or trial. The seal rubbing is reusable information and remains in the notebook for P19.

Successful release unlocks both R07 and R08 permanently and completes Tide III. The duplicate board reads **“Eight retained. One witnessing.”** Copy that text automatically before condensation obscures its physical surface. Use `r05_duplicate_board_reveal` for the physical bare-text board and `r05_duplicate_board` for the retained notebook copy. Allow the preserved version to be reopened afterward. The reveal must not depend on reading a disappearing frame, hearing a sound or revisiting the room before a timer expires.

## Evidence and cross-room continuity

| Evidence or state | Availability | Persistence and later use |
| --- | --- | --- |
| Serving ledger, eight chits and bowl-place correspondence | R05 access after P06 | Readable inspection; copied observations survive all weather changes |
| Pantry token half and Venn extra-diner conclusion | Successful P07 | Half retained until successful P09; conclusion remains in notebook |
| Bunk token half and three-cut seal rubbing | P08 in R06 | R05 consumes only the half on successful P09; rubbing remains for P19 |
| Original eight and printed correction rule | Board inspection after P06 | Original stays visible beside the successful amendment; teaches P22's additive correction |
| Duplicate “Eight retained. One witnessing.” board | Successful P09 | Automatically preserved before the condensation reveal |
| Nora's provisioning repair sketch | Kitchen page inspection | Corresponds to the personal cup retained on its marked R06 shelf; available as copied evidence for P22 |
| Nora's calibration work-card breathing trace | Kitchen work-card inspection | Two short rises, pause, one long rise; diagram and transcript remain available for P14 |
| Square-patched unsigned supper bowl | Supper inspection | Remains identifiable for the P15 STATION 3 reflection; it is not Nora's personal cup |
| Nora's menu objection, O02 | After P06 | Optional character evidence; no new prerequisite or ending requirement |

The approved Kitchen view contains no actual map/chart props. Every actual map/chart introduced later must have readable inspection art, including decorative maps. A service route diagram or room-scale paper does not authorize an illegible generated chart. Preserve observed versions, and do not introduce a map-only clue without a corresponding exact source and transcript.

The specification's `evidence_gates` maps every readable asset to its availability. In particular, `r05_provisioning_repair` and `r05_kitchen_work_card` are inspectable after P06 and preserve later P22/P14 clues without awarding those puzzles. The extra-diner note and P07 record require P07; the duplicate board and P09 record require P09.

## Integration and acceptance limits

The pack's composed gallery is an art-layout review, not a playable room. File integrity, dimensions, alpha bounds, authored correspondence checks and visual proof review do not establish input dispatch, puzzle persistence, timing, iPad readability, browser behavior or native export support.

Codex should integrate these sources into the existing game without changing P07/P08 parallel progression, P09's convergence, token lifetime or the distinction between supper bowl and personal cup. Report concrete missing crops or control states from an actual rendered implementation. Keep generated source art, editable SVG files and measured manifests together so corrections remain reproducible.
