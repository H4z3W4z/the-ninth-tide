# Listening Room asset pack: generation checkpoints

**Status: in progress.** The accepted visual master is `art/concepts/listening-room-approved-master-v4.png`. This replaces the earlier Listening Room concepts as the current art direction: small used noticeboard, specialized recording bench, hornless recorder and headphones, task lamp, weather window, and subtle damp stool impression.

## Checkpoint 1

- Eight full-room weather review images cover arrival/Tide I through Tide VIII. Tide IX holds the eighth state.
- One clean static room plate provides the fixed room and furniture.
- Headphones and dry stool have RGBA transparency and are separate props.
- Two initial attempts are retained under `art/listening-review/` as **drafts needing correction**, not runtime sprites: the lamp has a baked checkerboard, and the recorder has a visible halo.
- The remaining object, puzzle-state and inspection assets are still being generated.

## Checkpoint 2

The lamp OFF, empty recorder with bare spindle, and damp stool have been regenerated from the room master and now have genuine RGBA transparency (alpha range 0–255). Failed intermediate cutouts remain clearly marked under `art/listening-review/`. Dry and damp stool silhouettes have minor generated differences; use the final state overlay guidance for registered transitions.

The full-room weather renders are review images with the master's partial cylinder assembly. They must not be used to infer puzzle completion. Runtime integration should clip their window panes over the clean static plate and apply local lighting separately. Small generated texture differences exist; these are not guaranteed pixel-registered animation frames.

Exact labels, coherent cylinder seams, instruction diagrams and P17/P19 channel controls remain authored graphics/integration work. No Listening Room gameplay, audio, Web or native-device validation is delivered by these images.

## Checkpoint 3

The closed storage canister and open empty wooden case are separate RGBA props with genuine transparency. Their blank labels are reserved for authored lettering. The first recording-sleeve attempt is preserved as a review draft because it has a broad amber halo; it is excluded from runtime assets and will be regenerated.

## Checkpoint 4

A clean wax-band template, open canister and closed case now complement the prior props. Reuse the band illustration for the three labeled P02 pieces; labels and seam positions remain deterministic authored overlays. The initial bare noticeboard has an unwanted aura and is retained as a review draft pending replacement.

## Checkpoint 5

Partial and assembled recorder sprites and the cleaning brush with wax shavings have genuine alpha and are saved as separate objects. The recorder variants preserve the overall mechanism but have small generated differences; use the empty recorder plus deterministic band layers for exact interactive assembly. Generated wax joins are visual references, not the final C/A/B clue seams. The second bare noticeboard attempt still has a broad aura and remains a review draft.

Still to finish: clean noticeboard; document and photograph inspection art; instruction-card stand; shelf contents; open drawer/door states; local lighting and damp overlays; later channel-panel art; precise placement manifest and final Codex integration notes. The current pack is not complete or integrated into gameplay.

## Checkpoint 6

The noticeboard now has a clean edge-to-edge rectangular texture. Its alpha ranges from 200 to 250, so place a solid matching brown rectangle behind it. Its pinned photograph has a dedicated readable close-up, and blank stationery and the instruction-card stand have separate alpha artwork. The two workers in the photo are unnamed: no new identity or puzzle dependency is implied. Papers will receive precise authored lettering. The prior noticeboard failures remain excluded from runtime assets.

## Checkpoint 7

Separate shelf ledgers, a reusable horizontal cylinder case, and an open shallow drawer complete the small bench contents. An open-door detail plate supplies the portal image; clip only the doorway over the fixed clean room base. Do not replace the full room with that detail plate. Generated open/closed prop states have small geometry differences and are swap poses, not registered animation frames.

## Checkpoint 8

The later listening calibration board now has a separate blank faceplate matching the recorder's materials. Exact channel labels, waveform strips and witness controls will sit above it. This is an inspection surface, not a new horn assembly or a change to the approved room composition.

Generation prompts, source paths, intended placements and draft status are recorded in `listening-pack-generation.json`. Checkpoint commits will continue as batches finish. The final delivery will include the full inventory and integration guide.
