"""Rebuild every painted plate: the office stage painters, then every room's painter.

    python3 tools/build_art.py            # everything
    python3 tools/build_art.py R05        # one room's painter only

Order: tools/art/painter_*.py (painter_1 builds office_s2/s3 that later painters read),
then tools/art/rooms/<rid>.py in room order. A room painter writes only under
assets/rooms/<rid>/ and never overwrites an approved PNG elsewhere. Discovery is by file
name, so adding a room's painter never edits this file.
"""
from pathlib import Path
import subprocess, sys
root = Path(__file__).resolve().parents[1]
only = sys.argv[1:]
scripts = [] if only else sorted((root / 'tools' / 'art').glob('painter_*.py'))
scripts += [p for p in sorted((root / 'tools' / 'art' / 'rooms').glob('R[0-9][0-9].py'))
            if not only or p.stem in only]
for script in scripts:
    print(f'== {script.relative_to(root)}', flush=True)
    subprocess.run([sys.executable, str(script)], cwd=root, check=True)
