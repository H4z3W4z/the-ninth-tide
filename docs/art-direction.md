# Approved visual and environmental direction

The user approved the flat front-facing Intake Office in art/concepts/intake-approved-calm.png and its ominous revisit in intake-approved-ominous.png.

Use straight-on room elevations with no angled walls or receding desktop planes. Keep fine navy ink contours, broad matte colors, subtle paper texture, sea-glass green, storm navy, tarnished brass, and restrained brown. Retain enough specificity for tactile objects; avoid photorealism and heavy uniform cartoon outlines.

The window is a central story surface. Clouds, visibility, rain, sea behavior, and daylight change as puzzles are solved. All rooms respond to progression; rooms without windows use sound, dampness, shadows, reflections, and object behavior. Changes must be noticeable on revisits while leaving controls and evidence legible.

The coat is empty. At the late state its shadow has a head and shoulders. This is an authored discrepancy. The shadow is currently baked into the ominous plate; it is not yet an animated separate sprite.

Keep all exact clue marks, numbers, labels, and instruction diagrams authored from deterministic sources. P01's bridge/socket geometry is specified in SVG, with screw centres aligned in the installed overlay.

Every actual map or nautical-chart prop shown in a playable room must have readable inspection artwork, including maps used only for atmosphere. Provide close-ups and transcripts alongside the room art; do not rely on enlarging small generated background details. P03's torn sheet, fragments, and completed chart share a coherent authored source. Map changes follow puzzle progress and preserve already observed evidence in the notebook.

Native master canvas: 1448 x 1086, 4:3. Reference review size: 1024 x 768. Scale the complete composition uniformly and letterbox other aspect ratios in a release layout; do not stretch room geometry. The desktop preview currently uses the configured 4:3 window.

## Asset revisions

Listening Room production reference: `art/concepts/listening-room-approved-master-v4.png`. Mike accepted this revision after rejecting the horns and the sparse earlier arrangement. Use the hornless wax recorder, hooked headphones, small used noticeboard, specialized oak recording bench, task lamp, worn stool and large right-hand sea window. Earlier horn and speaking-tube studies are historical references only. The later channel panel is a close-up inspection surface; it does not add a new wall apparatus to the room.

For R04, keep `r04_clean_base.png` as the stable room geometry. Clip the exterior from the eight `r04_weather_*` plates to the manifest's window panes, then apply rain, reflections and local interior effects separately. Tide IX holds appearance eight. Never swap the entire weather plate into an interactive room: its partial recorder assembly is part of the visual study and must not overwrite the player's arrangement. Keep the window frame, furniture and hotspots fixed. Use source alpha bounds and placement rectangles from the [R04 manifest](../assets/listening/manifest.json), with the [composed review](../art/listening-review/composed/index.html) as an art-layout reference.

The three Office weather plates remain full-room images with small texture/furniture drift; change these on re-entry. The R04 generated alternate recorder, lamp and stool sprites also have minor silhouette differences. Use a fixed room-scale mechanism with separate occupied-slot silhouettes, exact authored band faces/seams in the inspection panel, and a fixed dry stool plus the authored damp mark for a stable local transition. The lamp uses ON/OFF poses with a separate authored light pool. Do not describe independent generations as registered animation frames.

Generated illustrations supply material surfaces. Exact labels, seams, waveform timing diagrams and documents are authored SVG/PNG assets. Preserve their editable sources and visibility gates. R04's noticeboard texture is partly translucent and needs its specified opaque brown backing. Rejected cutouts with halos or baked checkerboards are retained under `art/listening-review/` for provenance and excluded from runtime use. See [Listening Room assets](listening-room-assets.md) and the [inventory](listening-inventory.md) for state and integration requirements.
