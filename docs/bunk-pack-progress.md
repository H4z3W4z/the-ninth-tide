# Bunk Room graphics checkpoints

## Checkpoint 1: working background, personal props and evidence

The graphics continuation recovered the shared branch at `5d5bf5322a2f69aa68e4684ed8a09ff9e4627cf1`. Both GitHub asset and rendered-map workflows passed at that commit. The room concept remains a working proposal; Mike has not explicitly approved it as a production master.

This checkpoint adds **23 runtime PNG assets**, including **18 editable SVG/PNG pairs**, and six composed review images. The first five illustrations are one fixed clean room plate and four separate transparent belongings: Bell's repaired cup, Rook's calipers, Venn's pencil holder, and Ives's glove. All four props have real RGBA transparency. Failed exports with painted checkerboard backgrounds are excluded from runtime content and recorded in `bunk-pack-generation.json`.

The exact graphic set supplies four locker nameplates, three prop-mark overlays and eleven readable evidence documents. The cup has NB initials and two handle repairs, consistent with the existing Kitchen provisioning sketch. New production copy ties Rook to a nick on the measuring beam, Venn to a crescent of thumb wear, and Ives to a broad stitched palm patch. These details elaborate the existing P08 owner mapping; they remain editorial proposals.

The offline [review gallery](../art/bunk-review/checkpoint-1/index.html) includes first-entry room placement, P08 initial/partial/solved compositions, and P22 original/amended comparisons. The originals remain legible beside amendments. The gallery selects artwork only; it does not implement the puzzles.

## Validation

- All 23 new runtime PNGs and six review PNGs fully decode. A truncated room-review export was regenerated and inspected before publication.
- All four prop images have alpha ranging from 0 to 255. Measured alpha-above-8 content bounds exclude nearly invisible exterior speckles without changing the source PNGs.
- Editable SVG sources parse, and their relative image links resolve. Every gallery image link resolves.
- The builder measures document text against canvas bounds. Room placement, Bell's evidence card, P08 partial assignment and P22 amendment were visually inspected.
- The rebuilt global manifest validates **235 runtime PNGs**, their checksums, editable sources and existing touch-target bounds.
- No gameplay/state code changed. This is artwork validation, not Godot gameplay, animation or physical-device validation.

## Next graphics batch

Continue from `assets/bunks/manifest.json` and `tools/build_bunk_batch.py`. Keep the same clean plate and source illustrations. Complete the open-locker and curtain poses, the bunk token half matching R05's paired-token geometry, pillow depression and later local effects, calendar date/name overlays, secondary staff-locker view, and small pencil-shelf letter props. Then complete the measured layer/state manifest and the final art review. Keep Nora's cup on Bell's marked shelf after P08 for P22 and the ending.

The R06 graphics pack is **in progress**. This checkpoint does not complete all room states, remaining locations, or the game.
