# Room sounds

One seeded, standard-library script per room: `tools/audio/rooms/<rid>.py` writes
`assets/audio/<rid>/*.wav` using the helpers in `tools/audio/common.py` (read-only).
`python3 tools/build_audio.py` runs the office set and then every room; `python3
tools/build_audio.py R05` runs one room only. The game loads `assets/audio/<rid>/<id>.wav`
first and falls back to the shared `assets/audio/<id>.wav`. See `docs/dev/room-contract.md`.
