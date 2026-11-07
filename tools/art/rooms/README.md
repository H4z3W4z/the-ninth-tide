# Room painters

One seeded PIL script per room: `tools/art/rooms/<rid>.py` writes `assets/rooms/<rid>/*.png`
(native 1448x1086 plates, transparent overlays, close-ups). `python3 tools/build_art.py`
runs them all after the office painters; `python3 tools/build_art.py R05` runs one.
See `docs/dev/room-contract.md` for the rules (new files only, flat front elevation,
approved palette, deterministic seeds, judged in in-game captures).
