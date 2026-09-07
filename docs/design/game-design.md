# THE NINTH TIDE
## Full Game Design Document

**Working project:** Lovecraft Lake  
**Prepared for:** Mike Pearson and Kristi  
**Version:** 1.4, September 7, 2026  
**Format:** Original, single-player, illustrated point-and-click cosmic horror mystery  
**Target:** Approximately three hours for a first playthrough  
**Status:** Complete creative design proposal; pacing and implementation remain to be validated through playtesting  
**Spoilers:** This document contains the entire story, all mandatory puzzle solutions, and both endings.

**Version 1.4 art continuity:** Kitchen staging uses Nora's provisioning-page repair sketch; her physical cup stays in the Bunk Room for P08/P22 and the continuing-witness ending. Mike approved the Kitchen master v1 with “Looks good. Proceed.” Puzzle solutions, dependencies and ending consequences are unchanged.

> You were hired to close the station. The station has been waiting for someone who knows how to finish a record.

## 1. The game in one page

A temporary cataloguer arrives at an abandoned coastal survey station to inventory its instruments, restore the departure signal, and leave with the evening collection boat. The previous observer has disappeared. His meticulously maintained logs describe tides that have not happened yet.

The station seems merely neglected until the cataloguer restores a tide recorder. A hatch opens onto a dry stair occupying the same space as the sea outside. The departure signal works. The boat arrives. Its windows show the room the cataloguer has just left.

Each completed observation changes which parts of the station can exist together. As the player repairs instruments, reconstructs recordings, and compares scientific records with domestic evidence, the station becomes an anatomical diagram of an observer. The instruments have never been measuring the sea. They have been teaching something beneath it how to locate a human being.

The absent observer has left a final record addressed to the protagonist by name. He chose her because she once refused to certify an official account that erased a missing person. He needs someone who can distinguish a record from the life it claims to contain.

At the ninth tide, the player must decide what to do with the completed connection: break it and abandon the people preserved inside, or stay as its human witness so that the station can never certify them as objects.

**Player promise:** A deeply unsettling evening of tactile, fair puzzles, intimate human evidence, and rooms that become progressively harder to explain. Discovery is the source of danger. The interface remains reliable.

| Design commitment | Proposed specification |
| --- | --- |
| First-run duration | 150–210 minutes; planning midpoint 180 minutes |
| Main structure | Nine story-driven tide states grouped into three acts |
| Playable locations | 12, comprising 10 interior spaces and two exterior spaces |
| Mandatory puzzles | 27, three per tide; compound tasks count as one puzzle |
| Optional discoveries | Six short character or atmosphere discoveries; no ending requires them |
| Endings | Two informed choices, both available on every completed run |
| Controls | Click or tap to inspect, select, use, compare, adjust, and commit |
| Pressure | Fictional urgency; no real-time countdown, pursuit, or death loop |
| Presentation | Illustrated fixed views, close-ups, restrained animation, sparse voiced recordings |
| Commercial shape | One complete premium game; no prerequisite episode or sequel purchase |
| Primary design audience | Adults who enjoy atmospheric deduction and discussing solutions together |

**Interpretation of the request:** “Closer to 3 houses” is treated as “closer to three hours.” The duration is an authored target, not an established playtest result. The design does not assume three separate houses.

## 2. Relationship to the original concept

The source concept in *Rusty Lake + Lovecraft: Research and design opportunities for an original puzzle game* proposed a temporary cataloguer, a remote survey station, a missing observer, future tide records, and instruments that begin describing the player. Its five-puzzle pilot restored a lamp, reconstructed a recording, reconciled charts, calibrated a recorder, and completed an observation.

All five actions survive as P01–P05. Their original compact room is expanded into an intake office, chart room, and listening room. Their result still activates the exit signal and exposes reciprocal observation. P06 makes the collection boat the first major reversal, carrying a complete opening sequence into the full mystery. The expanded introduction occupies roughly 35 minutes rather than trying to stretch a short pilot across the entire game.

Everything that follows about people, dates, station history, later rooms, puzzle mechanics, and endings is new proposed canon. This document is self-contained and does not require the earlier brief to understand or build the game.

### Design pillars

1. **Useful answers make the world worse.** A solved puzzle opens a route, clarifies a procedure, or gives an instrument a purpose. It also supplies evidence that the original explanation was inadequate.
2. **The ordinary carries the horror.** Shift rotas, soup portions, wet coats, and repaired cups establish people before anomalies threaten their meaning.
3. **Surreal consequences follow learnable rules.** A room may acquire impossible depth. Its controls never secretly change the correct answer.
4. **Human specificity resists classification.** A person is more than a name and a set of measurements. This is the emotional argument and the final mechanical problem.
5. **Escalate the relationship, not just the gore.** The progression is from abandoned place, to functioning apparatus, to occupied apparatus, to a machine addressing you.

### Explicit exclusions

No combat, maze navigation, tiny hidden keys, timed reflex sequences, arbitrary item combinations, external cipher knowledge, sanity meter, procedural puzzle generation, or repeated restart punishment. No borrowed characters, signature symbols, or plot continuity from Rusty Lake or the Cthulhu Mythos. Lovecraftian scale and epistemic dread support an original mythology.

## 3. World, characters, and author-only truth

### Place and period

**Greywake Survey Station**, an invented institution on the invented **Morrow Sound**, October 1931. The building stands on a tidal shelf reached by a narrow jetty. A ruined service causeway is visible but unusable. Nothing establishes a real town or coast.

The station combines a practical municipal workplace with an older foundation that its builders mistook for stone. Brass screws, stitched oilcloth, enamel labels, linen chart rolls, and wax recording cylinders make the interactions tangible. Technologies are deliberately fictionalized where required; this is not a historical instrument simulator.

The sea begins as a convincing physical environment: wind, chop, distances obscured by weather. Later it loses one property at a time. It stops sounding near the wall. Its reflection moves in a different direction. Finally it becomes a flat, vertical surface outside the lantern gallery, as though the whole building has been placed against an enormous closed eye.

### Principal characters

| Character | Human role | Dramatic function and voice |
| --- | --- | --- |
| **Ada Mercer**, 34 | Temporary cataloguer and former municipal records clerk | Playable protagonist. Precise, skeptical, capable of anger. Notices discrepancies before naming supernatural causes. |
| **Elias Venn**, 58 | Missing senior observer | Leaves instructions, confessions, and one deliberately incomplete closure record. Warmth survives in practical acts of care. |
| **Nora Bell**, 46 | Station cook and caretaker, missing since 1927 | Her provisioning book contradicts the official history. People trusted her account of who had eaten more than the station's attendance register. |
| **Dr. Silas Rook**, 63 at disappearance | Former station director | Pursued a perfect, permanent record of a human mind. His procedural language disguises decisions that harmed staff. |
| **The Counter** | Name Venn gave the other observer | An intelligence or process inferred from effects. Its origin, size, and whether it understands suffering remain unresolved. |

Ada is not a secret descendant, reincarnated deity, or predestined sacrifice. Her past matters because of a choice. In an earlier harbor inquiry, she refused to sign a report stating that a missing dockworker had never been employed. Venn read the published dissent and requested her by name for the closure contract. P20 establishes this connection using the marked inquiry clipping and his unsent letter.

### What really happened

| Date | Authoritative event |
| --- | --- |
| 1889 | Surveyors build over a material that returns measurements with impossible precision. |
| 1912 | The station learns to correlate two locations that should not be adjacent. Useful predictions conceal the danger. |
| 1926 | Rook begins the Index, a procedure for recording people as complete sets of relations. He calls it preservation. |
| October 1927 | Eight people are entered into a closed survey. Their physical presence disappears from ordinary access. Fragments of their actions persist inside the apparatus. |
| 1927–1931 | Venn, the ninth person present but not indexed, keeps the cycle incomplete. He alters records and repeats maintenance to prevent closure. |
| Three days before the game | Venn enters the apparatus as its temporary witness. He leaves a closure contract for Ada and preserves an incomplete path she can reconstruct. |
| Game day | Ada's repairs restore the nine-stage procedure. She learns enough to choose between destroying the connection and maintaining it as a witness. |

### What the Counter can do

These rules are binding for writing, puzzles, and implementation.

1. **It correlates registered things.** A location, object, or person becomes accessible to it when a station instrument records a relationship involving that subject.
2. **Completed observations alter adjacency.** They connect already established room states; they do not create arbitrary new solutions or conjure useful objects without setup.
3. **Every change leaves a stable witness.** A captured chart, notch, pencil entry, or notebook copy survives and permits comparison.
4. **The Index closes on matching records.** If its physical, spatial, and personal records agree, it can treat the subject as fully located and retain it.
5. **A living witness keeps a record open.** A person can continue correcting it. The machine's own countersign cannot replace that person. This is taught through a small demonstration before the ending.
6. **Severance ends access.** Destroying the connection stops new observations but also ends the recoverable traces held in it. Rescue is not promised.

The Counter does not read real device data, access a microphone, use the player's actual name, or perform unrestricted mind reading. Its apparent predictions concern authored actions and recorded in-game state. It may reproduce a sound it has captured; it cannot answer new personal questions with omniscience.

### What remains ambiguous

Whether the preserved people are continuous minds or extraordinarily faithful remains. Whether the Counter is curious, hungry, or simply completing an operation. Whether its scale is geological or cosmological. The player can understand the mechanisms and consequences without receiving a taxonomy of the entity.

## 4. Narrative and pacing architecture

“Tides” are nine phases in the instrument's correlation cycle, not nine ordinary ocean tides passing in one evening. They advance only through deliberate puzzle completion. The title first seems nautical; by the end it identifies the ninth position in a human survey.

| Tide | Title | Player goal | Puzzles | Budget, minutes | Cumulative |
| --- | --- | --- | --- | ---: | ---: |
| I | The Last Shift | Restore enough equipment to close the station | P01–P03 | 18 | 18 |
| II | The Boat at the Window | Signal departure and investigate the return | P04–P06 | 17 | 35 |
| III | Supper for the Absent | Establish who was actually here | P07–P09 | 22 | 57 |
| IV | The Room Beneath the Water | Open the lower service route | P10–P12 | 23 | 80 |
| V | A Body of Measurements | Learn what the apparatus records | P13–P15 | 22 | 102 |
| VI | The Other Side of the Glass | Reconstruct the disappearance | P16–P18 | 23 | 125 |
| VII | The Man Who Left You a Letter | Discover Venn's purpose and Ada's role | P19–P21 | 22 | 147 |
| VIII | An Incomplete Person | Build a record that cannot close itself | P22–P24 | 20 | 167 |
| IX | The Ninth Tide | Choose what the connection is allowed to retain | P25–P27 | 13 | 180 |

**Act I, Arrival, Tides I–III:** Competence gives way to personal unease. A functional station emerges behind the abandonment. The first large reversal happens around minute 30; human stakes are established by minute 57.

**Act II, Descent, Tides IV–VI:** The player acquires a vocabulary for the anomaly. The machine room reveals a pulse; the wet laboratory supplies a human referent; the archive reveals institutional intent. The apparent empty workplace becomes a populated instrument.

**Act III, Witness, Tides VII–IX:** Venn becomes a fallible ally. Ada is selected for a moral choice rather than a bloodline. The final puzzles are applications of known rules. The ending asks for a decision after the evidence is understood.

### How the three hours are earned

The 180-minute allocation includes approximately 125 minutes of inspecting, reasoning, and operating puzzles; 25 minutes of navigation and room changes; 20 minutes of essential narrative; and 10 minutes of transitions and ending. These are overlapping design activities assigned to one budget, not extra time added on top of the tide table. Optional material can add roughly 10–15 minutes beyond the core route.

Early puzzles target 2–5 minutes; the middle uses 5–8 minute compound deductions; late execution shortens as the player becomes fluent. Skilled players may finish well below the target. Slow exploration and limited hints may extend beyond 210 minutes. Never inflate duration through walking, unreadable clues, or repetitive combination testing.

Each tide has a local goal, two or three meaningful discoveries, and a visible state change. Only some tides open new rooms. Others make a previously understood room newly useful. After a demanding inference, provide a short tactile action or quiet scene before another demanding inference.

## 5. Location plan and scene direction

Twelve playable locations are the scope cap. R01 and R09 are exterior; the other ten are interior. A close-up is not another room. R11 begins as a visible but gated threshold; its full stair route opens at Tide IV. R02–R04 form the opening hub and stay readable throughout the game.

| ID | Location and initial access | Main dramatic image | Puzzle ownership |
| --- | --- | --- | --- |
| R01 | Jetty, opening | A boat rope hangs over the water with no reflection | P06 |
| R02 | Intake Office, opening | Eight empty coat hooks and a ninth still wet | P01, P20 |
| R03 | Chart Room, P01 | A tide pen scratches against a motionless drum | P03–P05, P21 |
| R04 | Listening Room, P01 | Headphones hang beside a recorder whose motor has stopped | P02, P17, P19 |
| R05 | Kitchen and Mess, P06 | Eight place settings; nine spoon depressions in the cloth | P07, P09 |
| R06 | Bunk Room, P06 | An occupied indentation settles into an empty mattress | P08, P22 |
| R07 | Wet Laboratory, P09 | Specimen jars hold seawater at different angles | P10, P13, P14 |
| R08 | Machine Room, P09 | A black diaphragm inhales against its restraining bolts | P11 |
| R09 | Lantern Gallery, P12 | The horizon passes behind the player’s reflected shoulder | P15 |
| R10 | Records Vault, P15 | Shelves curve into a depth the floor plan does not contain | P16, P18, P23 |
| R11 | Dry Stair, P04 glimpse; P12 full access | Water presses against an open doorway and does not spill | P12, P24 |
| R12 | Observation Chamber, P24 | A chair faces an instrument with a space where its observer should be | P25–P27 |

### Traversal topology

The office connects to the jetty, chart room, and listening room from the opening; only their active investigation views need power. P06 opens the office's service door to the kitchen and bunk room. P09 releases the kitchen service access to the laboratory and machine room. The chart-room hatch provides the dry-stair threshold after P04; its pressure gate blocks descent until P12.

From the stair's first landing, a return door reaches the laboratory and a short upper branch reaches the lantern gallery. P15 opens the records vault from the laboratory. P24 opens the final lower stair door into the chamber. Every ordinary connection is bidirectional after unlocking. Anomalous changes alter views and puzzle relationships without trapping the player or silently changing navigation buttons.

An illustrated plan becomes available in the notebook after P05. After visiting a location, its plan label supports direct travel while preserving progression gates. New critical environmental changes get a short arrival view before fast travel resumes.

### Room treatments

**R01, Jetty.** Begin with a wide composition: small station, large weather, a mooring bell hanging too low. A contractor's launch departs in the opening. No character animation beyond a silhouette is necessary. On the return visit, a collection boat rests perfectly still while the water moves. Through its window is the chart room, including the paper Ada has just marked. Clicking the gangway produces one deliberate visual loop back onto the same jetty. Ada records the loop and will not repeat it. This is evidence, not a maze.

**R02, Intake Office.** The closest thing to a safe room. A stove is cold; a chipped green mug contains a clean spoon. The lamp brings out fingerprints in dust and a maintenance sketch. Later, a wet coat slowly fills around invisible shoulders. It never lunges. Near the end, the hooks have measurement labels matching the dimensions Ada entered elsewhere. The desk remains stable, lit, and usable even then.

**R03, Chart Room.** The central instrument is an elegant object designed to invite handling: bone-colored paper, a copper float mechanism, a polished lever. During P05 the pen records a short list of Ada's actual completed interactions, not a generic boast. Later, compass lines curve toward the standing position in front of the desk. The final chart describes the station in the outline of a seated person. Do not animate the full transformation until the player has read enough conventional diagrams to recognize it.

**R04, Listening Room.** A small used noticeboard, wax dust, a stool polished by use. Headphones hang beside a hornless wax recorder on a specialized oak bench; a warm task lamp makes the abandoned work look recently interrupted. The large right-hand sea window carries the weather changes. The accepted v4 composition replaces the earlier horn and speaking-tube studies. Early playback has a reassuring click and a human throat clearing. At Tide VI, the player hears Venn begin a sentence, then Nora finishes it from another recording. Their voices remain distinct. At Tide VII the dead channel speaks once after the motor stops. The transcript labels the event accurately; accessibility presentation does not conceal the scare. The later channel controls appear in an inspection view of the recording installation, without adding a new horn assembly to the room.

**R05, Kitchen and Mess.** This is the emotional center. Nora's routine was careful rather than occult. A towel is folded beside Nora's provisioning page, which includes a sketch of her repaired cup. The actual cup remains on its marked Bunk Room shelf for P08 and P22. Condensation travels inward across a bowl when the player reconstructs the supper table. A spoon lifts half an inch, waits for someone who cannot take it, and lowers. The only joke is penciled beside a ration correction: “Rook has discovered a ninth appetite. It belongs to Rook.” Later evidence reveals why the headcount mattered.

**R06, Bunk Room.** Narrow beds, luggage without owners, a curtain partition. An indentation appears only after the player correctly assigns an object to its owner. A wall calendar's dates never change; the names written beneath them do. One bed has a little pencil shelf that Venn installed for a colleague who wrote lying down. The room provides individual habits that later resist the Index's generic portraits.

**R07, Wet Laboratory.** A washbasin, balance, sample rack, and flotation tank. Jars contain fragments that initially resemble shells and later align like structures in a throat. Do not require a gruesome dissection. The central reveal is a pressure trace matching a named person's breathing pauses. When a jar is held beside the tank, the water inside leans toward it. All relevant measurements are printed on cards, so the player is never asked to estimate invisible physics.

**R08, Machine Room.** Belts, valves, grease, an enormous diaphragm. The player hears a mechanical cycle long before seeing anything suggestive of anatomy. Solving the routing problem stops one belt. The diaphragm continues moving. Its next inhalation pulls fine dust horizontally through the room. Preserve the working scale of valves and the clear pipe diagram; dread belongs to what the machine implies.

**R09, Lantern Gallery.** A roofed exterior walkway around the signal lens. Weather has stopped touching the rail. At first the scene has a conventional horizon. After calibration, the sea becomes a plane standing vertically outside the glass, carrying the reflections of rooms behind the player. A slow line passes through it like a lid opening. Never show a creature portrait. The measuring apparatus occupies less than one tenth of the apparent surface.

**R10, Records Vault.** Low shelves and hanging index cards become a suggestion of impossible depth through repetition and occlusion. Photographs show chairs occupied by carefully retouched blank areas. Restoring a contact sheet reveals that the eight people did not vanish simultaneously: the last one turned toward someone behind the camera. The catalogue drawer marked “STAFF” opens onto a dry mouth-shaped aperture lined with index tabs, not teeth. It remains motionless. The player places records on a tray in front of it.

**R11, Dry Stair.** Limewashed steps go through a plane of water without becoming wet. The player travels through three authored landing views, not a walking simulation. At the final landing the upper office is visible through the underside of the floor, with an empty pair of shoes beneath its desk. A bell sounds upward through the stair. Its clapper is missing. The source is now understood to be elsewhere in the connection.

**R12, Observation Chamber.** A chair, three record frames, a witness terminal, and a severance handle. The construction resembles survey equipment until the player recognizes that every armature ends at a part of a seated body. One blank frame is already labeled ADA MERCER. Beyond the chamber window is the enormous, unblinking surface seen from the lantern gallery, now so close that it has no visible edge. The climax uses stillness and the decision to touch a control.

### Mandatory environmental progression across all rooms

**User-approved design rule:** The station visibly and audibly becomes darker and more ominous as puzzles are solved. Revisited rooms must reflect accumulated progress. The Intake Office window is a major storytelling surface, not background decoration. Apply this principle to every playable location, including rooms without windows.

Familiar architecture provides the comparison: the same window, door, desk, or instrument acquires a progressively more disturbing context. Keep composition and hotspot positions stable so the player can recognize what changed. Mood should progress from physical bad weather into impossible behavior, rather than simply reducing screen brightness.

#### Station-wide weather and daylight progression

| Progress milestone | Exterior and window state | Interior consequence |
| --- | --- | --- |
| Arrival through Tide I | Overcast but legible; lighthouse and jetty clearly visible; ordinary wave motion | Cool daylight, readable sea-glass walls, small warm lamp accent once repaired |
| Tide II complete, P06 | Cloud ceiling lowers; rain stipples the glass; distant land loses contrast | Window illumination cools; wind gains a faint whistle through fittings |
| Tide III complete, P09 | Heavier rain and darker water partially obscure the jetty | Damp edges spread beneath windows; room tone becomes less comfortable |
| Tide IV complete, P12 | Rain appears to slow against the glass while waves continue; visibility contracts | Water sounds and visible movement begin to disagree; reflections lag slightly |
| Tide V complete, P15 | Natural storm crosses into impossible geometry; the lantern reveals the upright sea | Other windows show increasingly compressed horizons and mismatched reflections, appropriate to their view |
| Tide VI complete, P17 and P18 | Almost no distant detail remains; sea and sky become difficult to separate | External weather sound falls away in selected rooms even while rain remains visible |
| Tide VII complete, P21 | Darkness feels close to the panes; the lighthouse briefly appears at an impossible bearing | Shadows suggest observation positions; local light keeps task surfaces readable |
| Tide VIII complete, P24 | Exterior becomes a dark, near-featureless surface with occasional slow movement | Small changes in pressure, reflected light, and instrument behavior imply something immediately outside |
| Tide IX, before commitment | Hold the late state; no automatic rescue or return to daylight | Stillness concentrates attention on the final choice |

These are proposed authored treatments beneath the approved principle. Transitions follow puzzle milestones, never elapsed real time. Important individual solves may add local changes between these global milestones. Not every solve must alter every room, but every room must respond to the shared progression. Endings alone may resolve or deliberately transform the established late state, as described in Section 9.

#### Required room-specific expressions

| Location | Recurring surface or object | Escalation on later visits |
| --- | --- | --- |
| R01 Jetty | Sky, water, mooring rope, distant lighthouse | Shrinking visibility, unnatural stillness, missing or contradictory reflections |
| R02 Intake Office | Large window, lamp contrast, wet coat | Darker weather outside; increasingly isolated warm desk; coat and shadow diverge |
| R03 Chart Room | Sea window, paper, recording pen | Exterior darkness grows while the pen continues reporting conditions that cannot be seen |
| R04 Listening Room | Headphones, channel indicators, weather window, reflected light, room tone | Weather leaks through the wrong channel, then stops; a dead channel carries presence |
| R05 Kitchen and Mess | Condensation, bowls, spoon, ambient light | Condensation moves inward, meal traces appear, spoon movement suggests an absent diner |
| R06 Bunk Room | Beds, curtain, calendar, indirect light | Indentations and shadows imply increasing occupancy without displaying people |
| R07 Wet Laboratory | Jar surfaces, tank reflections, pressure traces | Water angles and reflected light become less physical; samples increasingly respond to identity |
| R08 Machine Room | Diaphragm, dust, belts, sound | Breath separates from mechanical drive; dust responds to an impossible pressure source |
| R09 Lantern Gallery | Horizon, glass, rail, signal light | Storm becomes the upright sea, then a vast surface with no understandable edge |
| R10 Records Vault | Shelf depth, photographs, index aperture | Recorded absences become perceptible; darkness suggests depth beyond the plan |
| R11 Dry Stair | Water boundary, landing views, bell sound | Water behaves as a surface; views connect impossibly; sound arrives from the wrong direction |
| R12 Observation Chamber | Outside surface, subject indicators, witness terminal | Later finale steps bring the observing presence closer, then into deliberate stillness |

Late-unlocked rooms inherit the current global condition immediately and need only author states the player can actually reach. Their remaining puzzle steps still provide local escalation. Windowless rooms express the same progression through indirect light, sound, dampness, shadows, and established props; do not add windows solely to satisfy this rule.

#### Production, readability, and revisit rules

- Author each room's reachable environmental states alongside its puzzle content. Each state specifies visual layers, audio layers, triggering puzzle flags, and the detail the returning player should notice.
- Separate window scenery, rain, glass/reflection effects, interior color treatment, and local anomaly overlays from the fixed room illustration. Use flat graphic color changes and drawn overlays consistent with the approved style.
- Reuse station-wide weather treatments while preserving each window's established view. Do not independently regenerate room geometry for later tides.
- R04's generated weather plates are full-room visual studies. In the interactive scene, clip only their glazing over the fixed clean base and layer the actual recorder arrangement independently. Eight appearances cover arrival through Tide VIII; Tide IX holds the eighth. The partial cylinder visible in a mood plate never grants puzzle progress. Use the R04 placement/state manifest rather than moving hotspots to match generation drift.
- Keep clues, item silhouettes, controls, and document contrast readable at the darkest stage. Increasing dread is not permission to obscure a required hotspot or clue.
- On re-entry, render the latest state directly. Never replay an obsolete earlier state because a player skipped visits. A brief arrival hold can draw attention to a major change, but never forces repeat inspection or extra backtracking.
- Capture essential evidence before any state replaces its source. Atmospheric changes cannot silently change a solved answer, lock a route, or invalidate the notebook.
- Save presentation milestones and any one-time reveal flags. Resume must restore the same weather and room state without advancing time or replaying every intervening change.
- Verify that each location has at least one visible or audible progression after its first arrival, that global conditions agree across rooms, and that both endings apply their intended final state.

## 6. Interaction, evidence, and fairness

The core loop is **notice → inspect → preserve evidence → infer a relationship → act → read the consequence**. A solved lock is rarely the final reward. The reward is a new interpretation and a usable next lead.

### Controls and inventory

Click/tap selects a hotspot. A second click/tap performs its clearly named action. Inventory use is select-item then select-target, with optional drag as a convenience. Rotations also have step buttons; no precise dragging is required. Hover may enrich desktop feedback but never carry essential information.

Inventory has named slots and no capacity puzzle. Consumed repair parts leave a small “installed” record in the notebook. Durable tools are a pencil, inspection lens, and chart clips; these remain available. Combination recipes are contextual at work surfaces, with visible sockets and ingredient labels. A wrong target produces a relevant observation, never a random joke that obscures the rule.

The notebook automatically preserves essential clues in readable text and image form. Tabs hold the current objective, station plan, observations, people, and completed procedures. Comparison tables populate with evidence but do not silently solve an unfinished deduction. Captured evidence remains accessible after every tide change.

### Inspectable maps and assembled charts

**User-approved interaction rule:** Every visible map or nautical chart in a playable room opens an inspectable close-up when tapped or clicked, including maps whose purpose is atmosphere or local history. Maps visible only as part of a distant reflection need not become independent hotspots. Author a readable close-up for each actual map prop; enlarging a small crop of the room background is insufficient.

The close-up supports zoom and pan, a fit-to-page reset, and an obvious return control. On touch screens offer pinch/pan as well as visible zoom buttons and tap-operated pan controls; mouse and keyboard have equivalent controls. Zooming is for comfortable reading, never for finding a one-pixel clue. A map's title, significant annotations, and essential symbols have a text or diagram equivalent. Maps can be inspected from the opening; the notebook's fast-travel plan still becomes available after P05.

Some maps reward inspection with geography, crossed-out place names, or a worker's note. Others carry explicit operational evidence. A torn chart visibly advertises missing pieces; corresponding edges, shoreline continuity, and printed reference marks establish the assembly rule. The player selects a piece and taps a board position, with snap placement and step rotation controls; dragging is optional. Wrong placements remain reversible and identify a broken edge or line. Keep found pieces and partial arrangements when the close-up closes or the game resumes.

P03 is the opening's concrete map-assembly puzzle: reconstruct one torn tide sheet from three local pieces, then compare it with the intact reference sheet. This remains one compound puzzle in the 27-puzzle chain, with the same prerequisites and interval-3 reward. The reconstruction should take roughly one to two minutes of the existing P03 pacing allowance; validate the opening's 18-minute Tide I target through playtesting.

The Office's coastal survey map initially serves orientation and atmosphere. After P21, its lighthouse engraving can shift to the impossible bearing already expressed by the weather outside, while the notebook preserves the earlier survey as a separate observed version. This is an optional environmental discrepancy, not a new lock or required puzzle. Essential map evidence is captured before a changed state replaces it; changing weather or ink never invalidates a solved answer.

### Puzzle conventions

A hollow circle means **observer**, a square bracket means **boundary**, and two linked strokes mean **relation**. Each appears first on ordinary instrument labels with printed words beside it. There is no prerequisite occult alphabet. Pattern, shape, and text duplicate color information.

Every puzzle has an explicit commit action where evaluating an arrangement would otherwise be unclear. Wrong attempts are reversible. Feedback identifies the inconsistent relationship without immediately announcing the answer. No essential item can be destroyed or spent on the wrong operation. Narrative annotations never alter functional settings unnoticed.

### Hints

Each of the 27 puzzles has three player-requested hint levels: a location nudge, the relationship to consider, and an explicit solution. Hints do not cost currency, lock endings, or shame the player. A subtle offer may appear after several unsuccessful commits but never opens itself.

Example for P07: “Nora counted meals, not employees.” Then: “Compare portions served with the additional used bowl.” Finally: “Set the table for nine and place the unsigned bowl at the square-marked seat.” The later puzzle specifications supply the evidence, inference, and exact solution from which equivalent hints are authored.

## 7. Complete mandatory puzzle specification

The settings below are proposed shipped answers, not placeholders. Named documents are obtained at the specified location or automatically copied at the prerequisite event. Every dependency refers to a puzzle ID. Physical outputs persist until their intended use; information outputs enter the notebook. No branch relies on an uncollected object from a location that becomes inaccessible.

### Tide I: The Last Shift

**P01. A Little More Light: Intake Office**  
**Entry:** New game; the closure contract and maintenance tray are visible.  
**Goal and evidence:** Restore the desk lamp. A sketch shows two separated contacts joined by a straight bridge marked B. The tray holds clearly labeled straight B and curved C spares.  
**Solution:** Switch the lamp off, fit bridge B into the matching socket, and switch it on. The switch sequence is printed on the maintenance card; attempting insertion while on simply prompts Ada to switch off.  
**Feedback and reward:** Light reveals a penciled chart instruction and releases the electrically latched instrument doors to R03 and R04. The lamp's shadow points toward the window although the lamp is on the window side of the object casting it. Ada notices; the controls remain conventional.  
**Design purpose:** Teach inspection, item selection, installation, feedback, and automatic clue capture in 2–3 minutes.

**P02. Tomorrow's Recording: Listening Room**  
**Requires:** P01. Can run before or after P03.  
**Goal and evidence:** Reassemble three separated recording bands on a cylinder spindle. One band has a START notch, one continues its diagonal seam, and the third terminates at END. Labels identify bands C, A, and B.  
**Solution:** Place C → A → B from the spindle's marked start end, align the continuous seam using three snap positions, and play. A visual trace and transcript convey identical information.  
**Reward:** Calibration zero **4**. The final line is dated tomorrow: “Mercer will be standing at the chart table.” Ada's name is already on the visible contract, avoiding the suggestion of device surveillance.  
**Failure:** A broken seam remains highlighted; playback cannot be damaged. The optional full recording is replayable and the calibration value is always retained.

**P03. The Missing Curve: Chart Room**  
**Requires:** P01.  
**Goal and evidence:** Reconstruct one torn tide sheet and compare it with an intact reference sheet. All three fragments are available in this room after P01: an upper coastline piece clipped to the board, a middle shoal piece in its unlocked chart drawer, and a lower soundings piece visibly held beneath the chart weight. The board has a full-sheet outline. Distinct torn edges and continuing coastline/contour lines show how the pieces fit. Both complete sheets have a lighthouse registration cross, north arrow, and the same date. A clipped example shows how registration reveals a line crossing numbered interval bands.  
**Solution:** Seat the coastline, shoal, and soundings pieces in the upper, middle, and lower board positions, respectively, matching their edges and continuous lines. Use the intact reference sheet to align the lighthouse crosses, match north arrows, and clip the overlays. The resulting curve crosses band **3** and resembles three scratches on the observation hatch. Fragment placement and step rotations snap; the comparison stage snaps only at marked registration points and still permits several incorrect alignments.  
**Reward:** Interval **3**, preserved reconstructed sheet and composite chart, and a clear prompt to combine the chart with the recording's zero. The fragments remain recorded as assembled and leave active inventory together.  
**Failure:** A misplaced fragment highlights its broken edge or contour; the comparison identifies nonmatching north arrows or date marks separately. No fragment is consumed on a wrong placement. Partial reconstruction persists on close and save/resume. This is spatial reasoning and chart comparison, not pixel precision. Hints progress from checking the board/drawer/weight, to matching edges and then registration marks, to the complete arrangement and alignment. **Tide I completes when P02 and P03 are both solved.**

### Tide II: The Boat at the Window

**P04. Set the Sea to Zero: Chart Room**  
**Requires:** P02 and P03.  
**Goal and evidence:** Calibrate the recorder. Its plate labels two independent controls ZERO and INTERVAL, with a small worked example using unrelated values.  
**Solution:** Set ZERO to **4**, INTERVAL to **3**, then pull CALIBRATE.  
**Reward:** The observation hatch opens onto R11's dry-stair threshold. An outer window beside the hatch still shows solid seawater at the same level. The stair cannot yet be descended because of a visible pressure gate.  
**Failure:** Gauges separately report zero-reference mismatch or interval mismatch. No random adjustment advances the tide.

**P05. A Record of the Observer: Chart Room / Stair Threshold**  
**Requires:** P04.  
**Goal and evidence:** Complete the three-part departure observation. The station plan shows the landward mark as a bracket. Stair marks demonstrate recording from boundary, through relation, to observer; the duty card shows a worked miniature example.  
**Solution:** Place **boundary → relation → observer** plates into the recorder's left-to-right slots and press RECORD.  
**Reward:** Departure signal activates and the notebook plan becomes usable. The pen writes Ada's last three completed interaction events from a fixed whitelist, such as “Aligned chart. Turned zero wheel. Opened hatch.” It does not invent what the player did. A signal reply directs Ada to the jetty.  
**Horror:** One extra line reads, “Observer has not yet looked behind her.” Turning to the room shows nothing. This line is an authored provocation, not a solvable instruction.

**P06. The Boat That Came Back: Jetty**  
**Requires:** P05.  
**Goal and evidence:** Identify the collection launch before boarding. The contract contains the silhouette and two-stripe pennant of the real launch. A mooring panel pairs pennants with numbered stations. The arriving boat has three stripes and contains the chart room.  
**Solution:** Use the inspection lens on the window, then select **UNVERIFIED RETURN** on the mooring panel and ring station bell **2**, the printed procedure for a mismatched vessel. No memorized nautical code is needed.  
**Reward:** A shore-service capsule rises on the mooring line, containing the kitchen service key and Venn's note: “If it brought you your own room, do not give it your address.” The boat withdraws without turning.  
**Failure:** Selecting VERIFIED produces Ada's specific observation that the pennant differs. Trying the gangway once demonstrates the spatial loop, then returns control. No progress is lost. R05 and R06 open. **Tide II completes.**

### Tide III: Supper for the Absent

**P07. Nine Appetites: Kitchen and Mess**  
**Requires:** P06.  
**Goal and evidence:** Reconstruct the final supper headcount. Nora's book lists eight signed meal chits, nine portions served, and no leftovers. Eight bowls have initials; one unsigned bowl has a square repair patch matching a ninth place mark on the cloth.  
**Solution:** Lay the eight initialed bowls on their matching places and put the unsigned repaired bowl on the square-marked ninth place. Set the serving tally to **9**, then compare against the official **8**.  
**Reward:** A service drawer unlatches and supplies the pantry half of a two-part service release token. Nora's note identifies Venn as the extra diner, absent from Rook's official attendance register. The unsigned spoon lifts and lowers once.  
**Failure:** The tally identifies whether portions or places disagree. Objects snap to generous place areas. This establishes that the eight indexed staff exclude Venn.

**P08. The Bed That Was Used: Bunk Room**  
**Requires:** P06. Parallel with P07.  
**Goal and evidence:** Assign four loose belongings to four labeled bunk lockers. Adjacent personal cards identify Bell's repaired cup, Rook's measuring calipers, Venn's pencil holder, and technician Ives's stitched glove. Each card contains a distinguishing habit and a matching visible repair or wear mark.  
**Solution:** Place **cup → Bell; calipers → Rook; pencil holder → Venn; glove → Ives**. The other staff lockers are already labeled and closed; they are scenery, not missing puzzle work.  
**Reward:** Venn's locker opens with the bunk half of the service release token and a rubbing of his three-cut personal seal. The pillow on his bunk depresses after Ada turns toward the door.  
**Failure:** An incompatible placement stays on the shelf and Ada cites the distinguishing feature. The important output is ownership grounded in evidence, not an arbitrary sorting mini-game.

**P09. The Meal They Removed: Kitchen Service Board**  
**Requires:** P07 and P08.  
**Goal and evidence:** Release service access using the paired tokens and correct the shift board. Nora's serving ledger proves nine present; Venn's seal identifies the unsigned diner. A printed correction rule says amendments must preserve the original entry and name the missing person.  
**Solution:** Fit both token halves, leave the official eight untouched, and add an amendment: **+1 / VENN / present**. Stamp with the three-cut seal selector.  
**Reward:** R07 and R08 open. A duplicate board behind the first now reads “Eight retained. One witnessing.” Ada copies it before condensation obscures it.  
**Failure:** Overwriting eight is rejected as an unverifiable correction. This teaches the distinction between altering history and appending a living account, later essential to P22–P26. **Tide III completes.**

### Tide IV: The Room Beneath the Water

**P10. Water That Refuses Level: Wet Laboratory**  
**Requires:** P09.  
**Goal and evidence:** Identify the reference jar for the stair pressure circuit. Three sealed jars are labeled A, B, and C. A test rack lets the player tip each through a fixed quarter-turn. A reference card specifies a valid sample: “Surface follows the station datum, independent of vessel.” A marked brass line supplies that datum.  
**Solution:** Test the three jars. A follows gravity, B stays fixed relative to the jar, and **C stays parallel to the brass datum**. Place C in the reference socket.  
**Reward:** Stable datum reading and a printed pressure target **2**. The water leans toward Ada as she removes her hand, after the correct sample has been recorded.  
**Failure:** The test diagram shows exactly which reference a surface followed. Fictional behavior is consistent and visually explained.

**P11. Something Still Breathing: Machine Room**  
**Requires:** P09. Parallel with P10.  
**Goal and evidence:** Route pressure to the stair gate without feeding the sealed Index line. Pipes are labeled SUPPLY, GATE, RETURN, and INDEX. The maintenance drawing shows a valid loop through gate and return with Index isolated.  
**Solution:** Set **SUPPLY open, GATE open, RETURN open, INDEX closed**, then engage the pump. Four labeled toggles make this a topology deduction rather than valve arithmetic.  
**Reward:** Mechanical gate power. A belt stops, but the black diaphragm continues its slow inhalation. The exposed nameplate beneath the belt reads “REFERENCE RESPIRATION.”  
**Failure:** A preview overlay traces the active circuit and identifies a dead end or Index diversion. No burst pipe, resource loss, or lethal outcome occurs.

**P12. The Dry Descent: Stair Threshold**  
**Requires:** P10 and P11.  
**Goal and evidence:** Equalize the gate and select a safe route. P10 supplies target 2. The preserved station plan identifies stable landings by paired bracket marks; the gate placard demonstrates matching these across a boundary.  
**Solution:** Set pressure to **2**, align the two bracket-marked landing plates, and open the gate. The apparent third unpaired landing is a visible false route, never a random doorway.  
**Reward:** Full R11 access and R09 access via the upper landing. The laboratory return door is unlocked from this side. A brief cut shows water resting vertically across the gate as though it were thick glass.  
**Failure:** Mismatched plates produce “No corresponding landing.” The gate stays closed and adjustments remain available. **Tide IV completes.**

### Tide V: A Body of Measurements

**P13. The Weight of an Absence: Wet Laboratory**  
**Requires:** P12.  
**Goal and evidence:** Determine which sample belongs to a personal rather than environmental reference. Three sample cards list mass changes when compared against an empty control tray. The card for N reads 0 → 3 → 0 in three labeled states: unattended, addressed by name, released. A retained staff card for Nora bears the same sample stamp.  
**Solution:** Place sample **N** on the balance, select **NORA BELL** from the specimen register, then release the address. Record the repeated **0 / 3 / 0** sequence using the printed measurement units.  
**Reward:** Nora's physical trace. The empty control tray acquires the shallow impression of a thumb.  
**Failure:** A wrong name produces a flat trace and a clear “No correspondence” annotation. This is choosing and testing an evidence-backed hypothesis, not guessing names from a huge list.

**P14. A Breath with a Name: Wet Laboratory**  
**Requires:** P13.  
**Goal and evidence:** Reconstruct the trace by ordering three labeled pressure sections. Nora's recorded kitchen work card contains a visual breathing trace captured during calibration: two short rises, a pause, one long rise. Both transcript and graph are present.  
**Solution:** Assemble **two short rises → pause → long rise**, then attach Nora's name card and the P13 measurement strip to the same specimen frame.  
**Reward:** A combined identity/physical record usable at the lantern. A sealed jar softly fogs on its inner surface. An inscription becomes legible: “Retention is not resuscitation.”  
**Failure:** The reference and constructed graphs appear together. This task tests ordering and correspondence; it never requires breath control, hearing pitch, or holding a button.

**P15. The Horizon Behind You: Lantern Gallery**  
**Requires:** P14.  
**Goal and evidence:** Locate the source of Nora's trace. Three signal apertures carry labeled bearings **LAND 1, SEA 2, STATION 3**. Through each, the scope shows a recognizable scene. The specimen frame's relation symbol and a reference diagram specify matching the recorded subject's location, not choosing the apparent water direction.  
**Solution:** Mount Nora's frame and aim at **STATION 3**, where the kitchen's repaired bowl is visible in the reflection. Confirm the square patch with the lens.  
**Reward:** A spatial strip locates Nora inside the station connection. The records-vault latch releases in the laboratory. The horizon stands upright; the vast surface moves once.  
**Failure:** LAND and SEA return diagrams with no matching object. The complete lab sequence makes the correct choice evidential rather than a clever-sounding reversal. **Tide V completes.**

### Tide VI: The Other Side of the Glass

**P16. Eight Blank Faces: Records Vault**  
**Requires:** P15.  
**Goal and evidence:** Reconstruct the 1927 Index session from four contact-sheet panels. An unbroken numbered edge provides orientation; a wall clock and progressively extinguished chair lamps supply event order.  
**Solution:** Arrange panels **B → D → A → C**, corresponding to eight lamps, six, three, then none. Clip the aligned edge and slide away the opaque registration cover.  
**Reward:** Evidence of eight indexed staff and an unoccupied witness station behind the camera. Venn is visible in the glass, outside the indexed seating. P17 and P18 become available.  
**Failure:** Discontinuous edge marks remain obvious; lamps provide an independent confirmation. The final face does not jump at the player. It simply looks away from the camera toward the observer's position.

**P17. Two People in One Sentence: Listening Room**  
**Requires:** P16. Parallel with P18.  
**Goal and evidence:** Separate an overlapping session recording into two channels. The contact sheet labels the bell as the synchronization event; the waveform shows that event in both tracks.  
**Solution:** Align both bell peaks at the same guide, then toggle **Venn channel** and **Nora channel** separately. Venn says “Leave the witness line open.” Nora says “Tell them I was here.” The notebook records both.  
**Reward:** Witness procedure: an automatic countersign closes a record; an ongoing human correction keeps it open. A marginal note identifies the P19 dead channel as Venn's current station.  
**Failure:** Misaligned playback retains distinct peaks on the visual display. All spoken evidence has speaker-labeled text. Audio distortion is atmospheric, not required decoding.

**P18. The Director's Perfect Record: Records Vault**  
**Requires:** P16.  
**Goal and evidence:** Reconcile Rook's protocol with the disappearance. Three folder headings are BODY, PLACE, NAME. Their cover examples identify respectively a mass/breath trace, a bearing diagram, and a personal card.  
**Solution:** File Nora's P13–P14 physical trace under **BODY**, P15 spatial strip under **PLACE**, and Nora's register card under **NAME**, then compare all three against the session date from P16.  
**Reward:** The cabinet demonstration closes a model Index around Nora's record. Ada immediately opens its training release, which is printed on the panel. The explanatory card states that the real system retained all eight people through the same three correspondences. Venn's unsent correspondence drawer opens.  
**Failure:** Mismatched categories stay on the comparison tray. The training model does not alter Nora or ending eligibility. **Tide VI completes when P17 and P18 are both solved.**

### Tide VII: The Man Who Left You a Letter

**P19. Speak to the Empty Channel: Listening Room**  
**Requires:** P17 and P18. Parallel with P20.  
**Goal and evidence:** Contact the witness position. P17 identifies the dead channel. Venn's seal from P08 has three cuts; the channel board maps one, two, and three cuts to sockets A, B, and C. A printed procedure says to isolate live playback before addressing a witness.  
**Solution:** Stop the motor, close live channels A and B, open **C**, and press the labeled WITNESS key.  
**Reward:** A brief exchange with Venn using three fixed questions. He admits he kept the people accessible but could not free them; he cannot promise that they remain whole. He explains that severance will end the traces and that a successor must remain physically at the station. All three answers are required evidence and can be replayed.  
**Horror:** His final answer continues through the headphones after the channel indicator goes dark. The caption preserves his identity and the continuation; the dark indicator does not hide the text. No free-form dialogue system is required.

**P20. Why Ada Mercer: Office / Venn's Correspondence**  
**Requires:** P17 and P18.  
**Goal and evidence:** Establish why Venn selected Ada. The closure contract, harbor inquiry clipping, and unsent letter are automatically copied from P18's drawer. The clipping contains three signatures; the letter quotes the phrase “unverified does not mean absent,” also present in Ada's signed dissent.  
**Solution:** On the office comparison board, connect **contract addressee Ada Mercer → dissent signatory Ada Mercer → quoted sentence**, then stamp **REQUESTED BY VENN** on the provenance field.  
**Reward:** The sealed personal paragraph opens: “You have already refused to make a person disappear for the convenience of a form.” Ada's voice turns angry: “You could have asked.” This supplies a relationship without a chosen-one revelation.  
**Failure:** Wrong signatures do not share the quoted sentence; the UI lets the player inspect both without leaving the board.

**P21. The Station's Real Plan: Chart Room**  
**Requires:** P19 and P20.  
**Goal and evidence:** Reclassify the room diagram using the three-record model. The main apparatus labels already identify listening and breathing traces as BODY, surveyed bearings as PLACE, and registers as NAME. The chamber outline at the center is marked WITNESS.  
**Solution:** Place **BODY** over the laboratory/listening pair, **PLACE** over the chart/lantern pair, **NAME** over office/vault, and **WITNESS** at the center. Kitchen and bunks remain the personal evidence margin, not extra mandatory labels.  
**Reward:** The plan resolves into a seated human outline and exposes the three-frame procedure for P22–P24. The blank witness frame prints Ada's name.  
**Failure:** Labels show the instrument references they summarize. This is synthesis of demonstrated categories, not anatomy trivia. **Tide VII completes.**

### Tide VIII: An Incomplete Person

**P22. A Person Is More Than a Card: Bunk Room**  
**Requires:** P21. Parallel with P23.  
**Goal and evidence:** Prepare a corrected personal record without overwriting the Index's original. P09 taught additive corrections. Nora's card says “No surviving personal effects,” while her initialed, repaired cup from P08 remains on its marked shelf. Her provisioning page includes the same repair sketch.  
**Solution:** Place Nora's card and the cup sketch on the comparison surface; append **PERSONAL EFFECT IDENTIFIED / REPAIRED CUP / NORA BELL**, leaving the original statement visible.  
**Reward:** An open personal record with one witnessed correction. The cup warms and a dry ring appears beneath it. This offers recognition, not proof that Nora can return alive.  
**Failure:** Erasing the original is rejected using the established amendment rule. The essential effect is already captured in the notebook if the player did not revisit the physical cup.

**P23. The Signature That Must Not Arrive: Records Vault**  
**Requires:** P21.  
**Goal and evidence:** Demonstrate the difference between a closed Index and an open witness record. A model has INPUT, COPY, and WITNESS terminals. Its faceplate says a copied acknowledgement closes the cycle; a human witness may append another correction. P17 and P19 supplied the same rule narratively.  
**Solution:** Connect **INPUT → WITNESS**, leave **COPY disconnected**, and use the TEST AMENDMENT control. The mechanism accepts a new line and remains open. Connecting INPUT → COPY demonstrates closure and can be reset instantly.  
**Reward:** A removable witness bridge and verified evidence that the procedure works. Ada copies the result, including the requirement for a person to remain.  
**Failure:** The model visibly stamps CLOSED on copied acknowledgements. No ending is locked by experimentation; this is a safe test before a consequential choice.

**P24. Leave the Last Space Open: Dry Stair**  
**Requires:** P22 and P23.  
**Goal and evidence:** Open the chamber using an amended subject record and a witness connection. The door has three labeled evidence frames and a separate witness socket. P21's procedure illustrates all four. Nora's physical and spatial records remain in the notebook and instrument folio.  
**Solution:** Mount **Nora physical trace → BODY; Nora spatial strip → PLACE; amended Nora card → NAME**. Fit the P23 bridge to **WITNESS** and leave the automatic COPY port bare. Commit OPEN ACCESS.  
**Reward:** The door admits Ada because the record is valid but not finalized. The lower stairs lead to R12. All earlier locations remain accessible until the final confirmation.  
**Horror:** The new door has worn finger marks on the side that has never been accessible. **Tide VIII completes.**

### Tide IX: The Ninth Tide

**P25. The Ninth Position: Observation Chamber**  
**Requires:** P24.  
**Goal and evidence:** Identify the role Ada occupies. The chamber contains eight closed staff indicators and one open witness terminal. Her movement trace from P05, name from P20, and position from P21 are shown on three cards.  
**Solution:** Place Ada's **movement trace under BODY, chamber position under PLACE, contract identity under NAME**, then route those cards to **WITNESS**, as the open procedure from P23 requires.  
**Reward:** The Counter addresses “Ninth observer” and offers its automatic countersign. Venn's line becomes audible for the last time. The ending controls unlock.  
**Failure:** Routing to COPY produces a preview marked “Would finalize observer” and requires returning to the safe witness configuration. There is no surprise bad ending for a mistaken click.

**P26. What Can Be Kept: Observation Chamber**  
**Requires:** P25.  
**Goal and evidence:** Verify the consequences before choosing. Two routing plates show **SEVER** and **CONTINUE**. The severance plate disconnects all eight subject lines; the continuation plate moves the active witness supply from Venn to Ada. These are direct consequences already explained in P19 and tested in P23.  
**Solution:** Trace each route in preview and attach its correct consequence card: **SEVER → connection ends, retained traces become inaccessible, Ada can leave**; **CONTINUE → Ada remains as witness, traces stay accessible, Venn's duty ends**.  
**Reward:** Both final controls become available. Ada states the consequences in plain language. The vast outside surface withdraws a fraction, as if making room for the decision.  
**Failure:** An inconsistent card identifies the unmatched line. This final short deduction prevents the moral choice from being a mislabeled lever trick.

**P27. Sign, or Break the Line: Observation Chamber**  
**Requires:** P26.  
**Goal:** Execute the selected ending using familiar apparatus. This is the final practical puzzle and choice, not a new riddle.  
**SEVER solution:** Fit the severance yoke across the two clearly labeled feed contacts, preview the eight lines extinguishing, then confirm **BREAK CONNECTION AND LEAVE**. Ada pulls the handle.  
**CONTINUE solution:** Seat the witness bridge in Ada's terminal, preview the active line transferring from Venn, then confirm **REMAIN AS WITNESS**. Ada writes the first new amendment.  
**Safeguards:** The yoke and bridge are both present in the chamber or carried from P23. Until the explicit confirmation, configurations can be changed freely. A save is made before commitment.  
**Reward:** One of two complete endings. **Tide IX completes.**

## 8. Dependency and item audit

### Canonical completion graph

Braces indicate tasks that may be completed in either order. All other arrows indicate required progression.

| Segment | Required sequence |
| --- | --- |
| Opening | P01 → {P02, P03} → P04 → P05 → P06 |
| Human evidence | P06 → {P07, P08} → P09 |
| Descent | P09 → {P10, P11} → P12 |
| Measurement | P12 → P13 → P14 → P15 |
| History | P15 → P16 → {P17, P18} |
| Venn | Both P17 and P18 → {P19, P20} → P21 |
| Open record | P21 → {P22, P23} → P24 |
| Finale | P24 → P25 → P26 → P27 → chosen ending |

This structure deliberately alternates limited parallel investigation with strong convergence. There are never more than two active mandatory branches. A player stuck on one middle-stage puzzle can often try the other, while each tide still has an unmistakable conclusion.

### Critical persistent outputs

| Output | Source | Required use | Lifetime rule |
| --- | --- | --- | --- |
| Three torn tide-sheet fragments | R03 board, unlocked chart drawer, chart weight after P01 | P03 reconstruction | Acquisition and partial arrangement persist; all three become one preserved sheet on assembly |
| Zero 4 / interval 3 | P02 / P03 | P04 | Notebook retains both forever |
| Movement trace | P05 | P25 | Store ordered event IDs and readable text |
| Service key | P06 | R05 / R06 | Unlocks both permanently; then retired |
| Two service token halves | P07 / P08 | P09 | Consumed together only on correct board |
| Venn seal rubbing | P08 | P09, P19 | Information copy, never consumed |
| Datum / target 2 | P10 | P12 | Reference jar stays installed; reading persists |
| Nora physical frame | P13 / P14 | P15, P18, P24 | Portable reusable frame with notebook duplicate |
| Nora spatial strip | P15 | P18, P24 | Persistent instrument folio |
| Contact sheet | P16 | P17, P18 | Preserved composite |
| Venn correspondence | P18 | P20 | Automatically collected when drawer opens |
| Amended Nora card | P22 | P24 | Original and amendment both retained |
| Witness bridge | P23 | P24, P27 | Door releases bridge after opening; automatic return to inventory |
| Ada identity and position | P20 / P21 | P25 | Generated from fixed story records |
| Severance yoke | R12 equipment tray | P27 SEVER | Visible beside labeled feed contacts |

The bridge return is mandatory implementation behavior, not optional player retrieval. The room never closes behind a spent key. Paper evidence represents copied information; placing it in a comparison does not destroy other uses.

## 9. Endings and emotional resolution

Neither ending is a hidden reward for collecting every scrap. Both follow an explicit choice and resolve the immediate story. The unresolved cosmic questions are not an excuse to withhold what happened to Ada.

### Ending A: The Unrecorded Shore

Ada breaks the connection. The station's instruments fall silent in sequence, with pauses between them long enough to hear the people they had been carrying. Nora's spoon settles. The bunk-room indentation rises. Venn says, “All right,” once. No scream announces whether this was mercy or loss.

The black outside surface recedes into ordinary water. Ada walks through the office and takes the corrected record. On the jetty, the real collection launch arrives with the two-stripe pennant from the contract. Its window shows its own empty cabin. This is a clear visual confirmation that the route is physically real.

At a harbor inquiry, Ada is asked to certify that the station was empty. She writes eight names, Venn's name, and the line: “I cannot certify their absence.” She can leave the station; she cannot recover the retained traces or prove what they were.

The final image is the corrected page drying in daylight. A small water stain contains no reflection. Its meaning is left unresolved, but it does not reactivate the station or undo the severance.

**Emotional result:** Freedom with grief and an obligation to remember. Ada resists administrative erasure without claiming a rescue she could not accomplish.

### Ending B: The Last Observer

Ada transfers the witness line from Venn to herself. His listening channel is silent. In the office, the wet coat collapses into an ordinary garment. His duty has ended; the game does not claim he has physically returned.

Ada sits in the chamber. The Index offers the first automatic sentence: “Subject Bell possesses no surviving personal effects.” She adds a correction about the repaired cup. On its marked Bunk Room shelf, the cup's handle becomes warm. In the kitchen, a small patch of condensation gathers inside the supper bowl. Another line appears. She adds another correction.

Morning reaches the windows but the station does not return to the ordinary shore. Ada has freely accepted confinement and an ongoing task. The eight traces remain accessible as fragments of people, not restored bodies. She can interrupt the Counter's claim to finality, but she cannot promise that she can do so forever.

The final wide view places the lit kitchen far inside the enormous dark surface, one small warm rectangle among innumerable unlit ones. The recorder prints a new heading: “LOCAL SURVEY: ONE OF…” before Ada covers it with a sheet of her own paper.

Her final line: “Nora Bell took her tea without sugar. Begin there.”

**Emotional result:** Care as resistance, with a real personal cost. The ending is dark without declaring compassion foolish.

### Replay behavior

After credits, offer **Return to final decision** and **New game**. Returning loads the P26-complete checkpoint with both options available. It does not require replaying three hours to see the other ending. The notebook distinguishes endings viewed without suggesting one is the canonical good ending.

## 10. Optional discoveries and environmental writing

Six optional discoveries enrich people and place. None provides the only copy of a critical clue, changes an ending requirement, or adds a hidden morality score.

| ID | Location / availability | Discovery and purpose |
| --- | --- | --- |
| O01 | Office, after P01 | A contractor's receipt for mending the green mug costs more than replacing it. Establishes Venn's preference for repair. |
| O02 | Kitchen, after P06 | Nora's handwritten objections to Rook's “nutritionally sufficient” menu. Introduces ordinary resentment and dry humor. |
| O03 | Bunks, after P08 | A half-written letter from Ives describing the station's bad weather and good soup. A life beyond the apparatus. |
| O04 | Machine room, after P11 | Layers of repairs dated across four years, all in Venn's hand. Makes his long maintenance burden tangible. |
| O05 | Lantern, after P15 | A scratched ruler whose unit subdivisions continue between the printed marks. Pure scale dread, no secret code. |
| O06 | Vault, after P18 | Rook's personal photograph, carefully wrapped. He once meant preservation as love, but that does not absolve his experiments. |

Essential narrative text targets 3,000–4,000 words across documents, notebook summaries, and dialogue. Optional prose targets 600–900 words. This GDD's explanatory text is not in-game copy. Keep individual mandatory documents mostly under 120 words, split dense procedures into diagrams, and place the operational clue where it can be inspected immediately.

### Dialogue and prose samples

**Opening contract:** “Inventory instruments. Reconcile outstanding records. Restore departure signal. Do not certify an observation you have not made.”

**Ada, first impossible stair:** “There is water on the other side of that wall. There is not room for both.”

**Nora's ledger:** “Nine portions. Eight signatures. I feed the people who sit down.”

**Venn's early recording:** “The recorder is accurate. That is the difficulty.”

**Ada, after learning Venn selected her:** “You knew I would finish the work before I understood what it was.”

**Venn's answer:** “Yes.” A pause. “I was afraid you would be kinder than me. I was also counting on it.”

**Counter output:** “DISCREPANCY DETECTED: SUBJECT CONTINUES.”

Use procedural language for the Counter. It should not taunt like a theatrical villain or deliver a monologue explaining the universe. Human voices can be terse, irritable, tender, and occasionally funny.

## 11. Visual direction and animation budget

### Visual identity

**Approved visual direction:** Flat, straight-on room elevations with no angled room perspective or receding furniture planes. Use fine, slightly varied ink contours, broad matte colors, subtle paper texture, sea-glass green, storm navy, and tarnished brass. Preserve an original maritime illustration identity with clear interactive silhouettes. The approved Intake Office concept establishes the direction; illustration detail must remain subordinate to readable objects.

Scientific engraving meets salt-damaged domestic illustration. Fine, controlled linework gives objects enough specificity to support clues. Larger ink washes and restrained texture establish atmosphere. Avoid filling every surface with occult writing. A blank form in the wrong place can carry more menace than a wall of symbols.

| Element | Direction |
| --- | --- |
| Primary palette | Ink navy #172B36, old paper #D8CEB5, oxidized copper #617D74 |
| Secondary palette | Damp timber #675D51, soot #292929, warm lamp amber #C39959 |
| Anomalous accent | Desaturated bruise violet #746577, always duplicated with shape or motion |
| Typography | Readable serif for prose, clean narrow labels for apparatus; decorative handwriting only with transcript |
| Composition | Foreground tools clearly separated from quieter midground surfaces and large dark negative spaces |
| People | Primarily photographs, belongings, reflections, and silhouettes; few fully animated figures |
| Material horror | Damp paper behaving like skin; water retaining a shape; machinery continuing without its drive |

Color values are art starting points, not a claim that final UI contrast is already verified. In-game documents and controls need their own tested high-contrast treatment.

### Scene budget

Target **24 base room views**, **32 dedicated instrument/prop close-ups**, and an initial allowance of **18 significant bespoke anomaly overlays**, plus reusable weather, window, and interior-light layers. The overlay estimate must be checked against the mandatory all-room progression matrix; it is not a cap that permits rooms to remain static. Twelve locations do not each get four expensive panoramic walls. Allocate three base views to R03 and R12, one each to R01 and R08, and two to each of the remaining eight locations: 6 + 2 + 16 = 24.

Close-ups are reusable interfaces where practical: record frames, chart clips, notebook comparisons, and signal controls share interaction behavior but retain room-specific art. Tide changes selectively update these scenes. Do not commission nine versions of every background.

Map inspection uses one shared viewer with separate readable art and transcripts for every map prop actually shown in the room views. Include the P03 reconstruction board within its existing dedicated close-up allowance. Inventory all visible maps during each room's asset pass so incidental maps receive inspection artwork too. Preserve coherent coastline geometry across fragment exports and their completed sheet. Generated decorative map marks in room concepts are placeholders; shipped evidence comes from authored sources.

Target approximately 25 short animation events and 10 reusable ambient loops. Prioritize the impossible stair reveal, self-writing record, lifting spoon, moving diaphragm, vertical sea, and ending transitions. Secondary events can use a few strong poses and controlled sound rather than costly full animation.

### Horror intensity curve

Tides I–II use discrepancies and one impossible view. Tide III creates attachment and absence. Tides IV–V suggest anatomy and scale. Tide VI reveals human wrongdoing. Tides VII–VIII bring the observer's attention close to Ada. Tide IX becomes quieter, letting the player's hands and decision carry the tension.

Content includes implied death, drowning imagery, confinement, mild body horror, and disturbing human traces. There is no need for graphic mutilation, animal harm, or loud startle attacks. This is a creative intensity target, not an assigned age rating.

## 12. Audio, accessibility, and platform behavior

### Audio plan

Begin with four readable environmental layers: sea, wind, clockwork, and room tone. Change one at a time after observations. A successful puzzle has a modest mechanical confirmation followed, when appropriate, by a separate unsettling consequence. The player should distinguish “I solved it” from “something else happened.”

Use three sparse musical motifs: station routine, human presence, and reciprocal observation. The first is uneven but comprehensible; the second has a warmer acoustic source; the third reorganizes an already familiar pattern. Final music resolves the human motif differently for each ending without making either a victory jingle.

Plan for 45–60 short sound effects, roughly 10 ambient loops, and 6–8 minutes of selective recorded speech. Ada can remain mostly text to contain production scope. Venn and Nora benefit most from careful performance. All clue-bearing audio must ship with speaker labels, transcripts, and visible timing or waveform equivalents.

### Accessibility requirements

- All essential interactions work by touch, mouse, and keyboard focus; no hover-only clue.
- Use generous targets, aiming for at least 44 × 44 logical pixels at the reference layout, and validate on actual target screens.
- No essential color-only, pitch-only, stereo-position-only, or timing-only information.
- Adjustable text scale, persistent captions, document transcripts, and a high-contrast notebook.
- Reduced motion and separate control for abrupt audio events; no flashing sequences are necessary.
- Drag tasks have click/tap placement and rotation buttons. No hand steadiness challenge.
- Pause remains available during every authored sequence; skipping replayed transitions preserves their evidence.
- Hint use never changes ending access. Accessibility settings are available before the opening scene.

The game is one-player software but suits two people solving together on a shared screen. A “compare two clues” notebook view supports discussion without requiring network co-op.

### Platform intent

Design for desktop and landscape tablet first, with a browser-playable prototype as a validation goal. A native release path and phone layout should be decided after the first slice. Phone support is not implied by having tap controls: dense documents need separate responsive layouts or a deliberate minimum screen requirement.

This GDD is engine-independent. It defines state and presentation requirements rather than asserting current engine or browser compatibility. Evaluate the chosen engine's export, persistence, audio, and input behavior in the prototype before committing to release platforms.

## 13. Implementation architecture and persistence

### State model

Separate five categories: puzzle completion, puzzle-local arrangements, inventory, observed evidence, and narrative presentation. A tide is a derived milestone, not the sole record of progress. Room visibility and exits resolve from explicit prerequisite flags. Global weather resolves from the environmental milestone table in Section 5; each room combines that state with its local completed-puzzle flags. Derive presentation from persisted progression so load and re-entry cannot desynchronize the station.

Every puzzle has a stable ID P01–P27, required evidence IDs, input state, validation rule, outputs, hint levels, and one-time consequence events. World reactions listen to completion events. The puzzle validator must not depend on whether an animation has finished.

Each inspectable map has a stable prop ID, room placement, close-up asset, readable annotation/transcript, and authored presentation version. Persist observed versions in evidence separately from the current room presentation. P03 also stores acquired fragment IDs, their board positions/step rotations, the reconstructed-sheet flag, and the comparison alignment. Reconstruction alone does not complete P03, grant interval 3, or advance the tide.

P05's movement record stores a capped list of recognized in-game interaction events. P25 displays the same saved record. It does not query the device or improvise an inconsistent history.

### Save behavior

Save after solved puzzles, item acquisition, important arrangements, tide transitions, and before the final confirmation. Keep current progress, one previous valid save, and a named pre-ending checkpoint. Include a save schema version for future migrations. Save the player's chosen accessibility settings separately from story progression.

If the application closes during a reveal, load the solved state with its evidence present; either resume the reveal safely or offer it as a short replay. Never grant the clue only from an animation callback. If storage fails, show a clear in-game notice and preserve the active session; persistence behavior requires platform testing.

### Required implementation checks

| Risk | Acceptance evidence |
| --- | --- |
| Branch order changes output | Both orders tested for each of the six parallel pairs |
| Lost or consumed bridge | P24 always returns it; both P27 routes remain possible |
| Hidden essential evidence | Every critical clue can be reopened from notebook after collection |
| Inert or unreadable map prop | Every actual map shown in a playable room has a legible, operable close-up, including atmospheric maps |
| Lost map assembly | Close/reopen and save/resume retain P03 pieces and arrangements; reconstruction alone never awards the comparison result |
| Map changes erase evidence | An observed earlier map version remains available after its room art changes |
| Duplicate completion | Repeated commit does not duplicate rewards or advance a tide twice |
| Interrupted transition | Save/resume at each tide retains outputs and reachable exits |
| Prediction mismatch | P05 and P25 display the same persisted interaction history |
| Wrong ending by misclick | Preview and explicit confirmation precede both final mutations |
| Accessibility loses information | Each sound/color/drag clue has an equivalent operable route |
| Impossible navigation | Reachability audit confirms unlocked rooms and final route from every milestone |

## 14. Production plan and scope control

### Milestones and exit gates

| Milestone | Deliverable | Exit criterion |
| --- | --- | --- |
| 1. Paper game | All 27 puzzle cards, prop lists, room links, and printed clue materials | A facilitator can run a complete solution path without inventing missing evidence |
| 2. Opening vertical slice | P01–P06, R01–R04 and stair threshold; representative final art/audio | New players understand the initial job, see the reciprocal-observation reveal, and can save/resume |
| 3. Full rough game | All rooms, puzzles, transitions, and both endings with temporary assets | Every branch order and both endings completable without developer intervention |
| 4. Art and sound integration | Approved backgrounds, close-ups, text, recordings, settings | Clues remain legible and state changes stay consistent with the full rough game |
| 5. Content and accessibility pass | Final hints, evidence capture, keyboard/touch behavior, edited prose | No mandatory puzzle lacks an accessible solution path |
| 6. Release candidate | Tested builds for the selected platforms | Progression, save recovery, performance, and ending confirmation gates pass |

Do not estimate a confident delivery date before the vertical slice measures effort per background, close-up, puzzle, and audio event. This is a content-heavy game even with simple controls. A small team or an individual assisted by code tools still needs deliberate art direction, puzzle testing, and editorial review.

### Scope protection

Preserve the 27-puzzle narrative chain, all 12 locations' core functions, fair hints, and both endings. If production pressure appears, reduce secondary views, optional voiced lines, and decorative animation first. Do not remove clue redundancy or save behavior to preserve spectacle.

The highest-cost risks are unique close-up mechanisms, consistency across tide states, and custom animation. Reuse the record-frame interaction and comparison board. The highest design risk is repeated classification feeling like paperwork: vary physical action and consequence, and keep the middle-game water, pressure, recording, and spatial puzzles distinct.

No inventory crafting tree, simulated ocean, generative dialogue, online account system, or procedural narrative is needed to deliver this design.

## 15. Playtest plan and pacing acceptance

All duration claims remain targets until tested. Start with five to eight unfamiliar players, including puzzle enthusiasts and less experienced players; Kristi is an important audience reference, not a replacement for outside testing. First test the opening, then the full rough game. Do not show testers this document.

Record time per tide, time between meaningful discoveries, failed commits, hints requested, revisits, and the player's stated explanation of major solutions. Ask what they believe the station does after P06, P15, P18, and P24. Confusion about the entity's ultimate nature is acceptable; confusion about the next operable goal is actionable.

**Working acceptance goals:** Most target players reach a first ending in 150–210 minutes; can explain the core three-record mechanism; recognize why Ada was selected; and understand both final consequences before choosing. These are evaluation goals, not success statistics.

If playtime is short, deepen underdeveloped deductions with meaningful evidence comparison and stronger human scenes. If it is long, identify missed affordances, unclear feedback, excessive document text, and travel overhead first. Never add another locked cupboard solely to absorb minutes.

A puzzle needs revision if several testers solve it by exhaustive guesses but cannot explain the answer, or if they understand the intended inference but cannot operate the interface. A horror beat needs revision if it obscures whether the puzzle succeeded. A narrative beat needs revision if players believe the final decision has consequences different from the ones the game implements.

## 16. Decisions established and questions for the next build

This document establishes the creative baseline: three-hour target, 12 locations, nine tide states, 27 mandatory puzzles, original characters and mythology, and two explicit endings. All operational evidence and solutions needed for the main route are specified here.

Prototype work still needs to determine the final engine and platforms, visual production method, exact UI scale, tested puzzle durations, final copy, audio casting, and a production estimate. These decisions do not block reviewing the complete game concept. Title clearance and commercial positioning are separate future tasks; no availability claim is made here.

The next concrete deliverable should be the six-puzzle opening slice, built against this full-game state model. It ends when the boat takes the chart room back out to sea and the kitchen service key rises on the mooring line. By that point, the player has completed a real task, learned the controls, witnessed the impossible, and acquired a personal reason to go deeper.

## Appendix A. First-playthrough experience in brief

You arrive expecting clerical work. You make a lamp function. You hear your name in tomorrow's record. You piece a torn tide sheet together, align it with another chart, and discover a curve that belongs to neither. You activate the signal, and the sea sends back a boat containing your room.

Inside the station, you set a table for someone the attendance register omitted. You put a repaired cup beside the right bed. You restore a machine that does not need its motor to breathe. The water provides a name. The horizon turns to look through the building.

You discover that eight missing people have been retained as records, and that the ninth kept correcting the machine rather than let it finish them. He chose you because you once refused to sign a person out of existence. You are furious with him. You understand him anyway.

You learn how to keep a record open. Then the station asks you to complete your own.

## Appendix B. Provenance

Creative foundation: *Rusty Lake + Lovecraft: Research and design opportunities for an original puzzle game*, prepared September 6, 2026, especially its original concept, pilot, and world-rule sections. The earlier brief informed the interaction principles and thematic direction; its research is not reproduced as fresh verification here.

All Greywake characters, scenes, dialogue, puzzle settings, history, and endings in this document are original proposals for *The Ninth Tide*. No external research is required to solve the game. Numerical scope and duration figures are design budgets, not measured results.

## Revision history

- **1.3:** Adopted the accepted Listening Room v4 composition: hornless wax recorder, hooked headphones, small used noticeboard, specialized bench and prominent weather window. Replaced obsolete funnel/trumpet staging while preserving P02/P17/P19 solutions, voices, dependencies and ending consequences. Documented fixed room geometry, clipped weather and independent recorder state. This art revision adds no gameplay or platform-validation claim.
- **1.2:** Made every actual map prop inspectable, including atmospheric maps; specified zoom/pan alternatives, readable close-up assets, and preservation of changing map evidence. Expanded P03 with three-fragment reconstruction before its existing chart comparison. Prerequisites, interval-3 reward, 27-puzzle count, and ending choices remain intact. Added map asset and save-state requirements.
- **1.1:** Recorded the approved flat, front-facing art direction and made progress-driven environmental escalation mandatory in all 12 locations. Added the window/weather milestone table, room-specific treatments, reusable layer requirements, and save/revisit behavior. Puzzle count, solutions, and ending choices remain as specified.
