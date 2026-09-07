# Listening Room: resume the art pass

## Current state

The accepted visual reference is `art/concepts/listening-room-approved-master-v4.png`. Use headphones and the hornless wax recorder, a small lived-in noticeboard, specialized oak bench, worn stool, brass task lamp and prominent right-hand weather window. Earlier speaking-tube and horn concepts are superseded.

Generated room, weather, prop and inspection images are under `assets/listening/`. Failed cutouts are clearly separated under `art/listening-review/`. Eight weather appearances cover arrival through Tide VIII; Tide IX holds the eighth state. Clean base and door detail are separate. Complete weather images are mood references; clip only their window panes when composing the fixed room.

The repo contains 31 generated R04 asset images plus 38 authored SVG/PNG pairs at this checkpoint. These counts exclude the accepted master and failed attempts. Read `listening-pack-progress.md` for checked batches and `listening-pack-generation.json` for prompts. The pack is an integration candidate in progress, not an implemented room.

## Next bounded batch

1. Inspect the authored documents and control overlays at readable scale. Keep visual evidence clear on dark panel backgrounds.
2. Finish the lamp's lit-shade layer, then write the precise R04 placement/layer manifest. Keep all source PNG files unchanged. Use alpha-region coordinates in the engine to account for transparent sprite margins.
3. Document the weather/puzzle layer combinations. Recorder state comes from P02 arrangement/completion, independently of the tide. Use one fixed empty mechanism plus band layers for exact assembly; generated partial/assembled recorder sprites are pose references and have slight geometry drift.
4. Update `listening-room-assets.md`, `art-direction.md`, the README and the Codex handoff with v4 and current asset inventory. Replace obsolete funnel/trumpet visual descriptions in the GDD without changing dependencies, answers or channel behavior.
5. Rebuild the asset manifest, validate, and push the final bounded art checkpoint. Do not merge the draft PR or change runtime puzzle code here.

## Exact artwork and remaining integration

`tools/build_listening_vectors.py` authors the precise layers. `assets/listening/authored-spec.json` specifies C/A/B, the three discrete seam orientations and fixed end guides. The three canisters and recording bands share illustration templates with separate exact labels. No generated writing is authoritative evidence.

P17 timing traces are authored visual diagrams, not extracted audio. The eventual spoken recordings must use the same bell synchronization event. P19 requires motor OFF, A and B CLOSED, C OPEN and WITNESS. Its voice continuation follows a dark indicator; do not restore horns.

The v4 reference remains the approved composition. Shelf props, document close-ups and the later control panel are additions for implementation review. The noticeboard texture has alpha 200–250 and needs a matching opaque brown backing rectangle. Window mask and damp/light vectors use proposed room coordinates; inspect the actual composition before claiming registration.

Codex elsewhere owns code, state, saves, final placement, animation wiring and platform tests. No audio, Listening Room gameplay, iPad/Safari or native validation has been completed in this art pass.
