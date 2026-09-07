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

Generation prompts, source paths, intended placements and draft status are recorded in `listening-pack-generation.json`. Checkpoint commits will continue as batches finish. The final delivery will include the full inventory and integration guide.
