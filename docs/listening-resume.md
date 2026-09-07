# Listening Room: completed graphics handoff

## Current state

The R04 graphics pass is complete for the accepted `art/concepts/listening-room-approved-master-v4.png` composition. The hornless wax recorder, headphones, small lived-in noticeboard, specialized oak bench, worn stool, task lamp and weather window replace the earlier speaking-tube and horn concepts.

The pack contains **93 PNG assets: 32 generated illustrations and 61 authored SVG/PNG pairs**. Counts exclude the approved master, rejected drafts and composed review exports. The authored pairs comprise 12 documents, 42 puzzle graphics and seven environmental effects. Eight weather appearances cover arrival through Tide VIII; Tide IX holds VIII. Source images remain unchanged.

Open `art/listening-review/composed/index.html` for the offline art review, including independent weather, recorder and prop states plus readable inspection surfaces. Twelve composed SVG/PNG proofs accompany it. This review displays artwork and specified states; it is not a playable implementation.

## Source of truth

- `assets/listening/manifest.json`: measured source regions, 46 room layers, 16 hotspots, state triggers, inspection geometry, evidence gates and explicit reuse decisions.
- `assets/listening/authored-spec.json`: exact P02/P17/P19 controls, solutions, statements and fixed question/answer copy.
- `docs/listening-inventory.md`: exhaustive asset inventory and coverage decisions.
- `docs/listening-room-assets.md`: composition and integration instructions.
- `docs/listening-evidence-review.md`: readable-document and narrative review.
- `docs/CODEX-HANDOFF.md`: implementation baseline, known rendered map-input failure and integration gates.
- `docs/listening-pack-generation.json`: generation prompts, source references and rejected draft status.

Keep the fixed clean room base. Clip weather images only into the window panes so a changed tide never changes the player's recording arrangement. Use measured visible-content regions to place padded PNGs; the noticeboard requires an opaque brown backing. Use the dry stool plus damp mark for a stable silhouette. Lamp ON/OFF images are discrete poses with slight silhouette differences.

## Verified graphics

Five specialist passes covered inventory, exact puzzle graphics, documents, composed scenes and handoff consistency. Every visible v4 prop has a separate asset, reusable template or native vector representation. All 12 document exports and the P02 playback readout were inspected; all 120 checked text elements fit their canvases. The finished compositions include connected headphones, progressive interior darkness, a warm task lamp and preserved clue readability.

The graphic specification has exactly one solution among 162 P02 arrangements, one among 441 P17 trace alignments, and one among 32 P19 connection states. These checks validate authored relationships, not runtime puzzle behavior.

## Next work belongs to implementation

Codex can integrate this pack using the manifest and handoff. Preserve P02's C/A/B steps 0/0/0 and zero-4/tomorrow evidence; P17's separate Venn and Nora statements; P19's motor OFF, A/B CLOSED, C OPEN, WITNESS configuration and three retained exchanges. Never reveal earned evidence just because a late weather image is selected.

Recorded audio, interactive state, saves, animation wiring and device testing remain implementation work. P17 traces are authored diagrams and need matching recording cues. No Listening Room gameplay, iPad/Safari or native validation has been completed by this graphics pass. The other rooms remain separate production packs.
