"""Rebuild every painted stage plate: runs tools/art/painter_*.py in order (1 builds office_s2/s3 that later painters may read)."""
from pathlib import Path
import subprocess, sys
root = Path(__file__).resolve().parents[1]
for script in sorted((root / 'tools' / 'art').glob('painter_*.py')):
    print(f'== {script.relative_to(root)}', flush=True)
    subprocess.run([sys.executable, str(script)], cwd=root, check=True)
