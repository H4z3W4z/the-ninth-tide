# Validation record

Validated September 7, 2026.

- Godot 4.5.1 headless editor import completed successfully.
- Main scene ran headlessly for eight frames without script/runtime errors.
- The P01 smoke test passed: powered fitting rejected; C rejected; B fits only while off; ON after installation completes; weather selection does not solve the puzzle; saved completion/weather reload; solved note accessible; lamp hotspot routes to repair.
- Asset validation passed for 25 PNG entries: unique IDs, paths, SHA-256 hashes, dimensions, matching SVG source parse, all three weather plates at 1448 x 1086, RGBA lamp encoding, and touch-target bounds.
- Alpha inspection confirmed the lamp's outside background pixels are transparent; baked-checkerboard cleanup attempts were excluded.
- Composed asset review image was visually inspected. Lamp base and shade overlay align with the desk at room scale; the repair pieces and labels are legible in the review layout.

Limits: no rendered Godot-window inspection, actual iPad/browser interaction, native mobile export, or long-duration audio testing has occurred. Review-sheet rendering is not a substitute for in-engine/device visual validation. No audio is included. CI configuration is prepared; the upload step will separately verify whether it runs on GitHub.
