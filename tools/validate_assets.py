"""Validate the manifest and source assets with Python's standard library."""
from pathlib import Path
import hashlib,json,struct,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'asset_manifest.json').read_text())
ids=set()
for a in m['assets']:
 assert a['id'] not in ids,a['id'];ids.add(a['id'])
 p=root/a['path'];data=p.read_bytes()
 assert data[:8]==b'\x89PNG\r\n\x1a\n',p
 assert list(struct.unpack('>II',data[16:24]))==[a['width'],a['height']],p
 assert hashlib.sha256(data).hexdigest()==a['sha256'],p
 if a['source_svg']: ET.parse(root/a['source_svg'])
for weather in m['weather_states']:
 a=next(a for a in m['assets'] if a['id']==weather['asset'])
 assert [a['width'],a['height']]==m['canvas']
for group in ['room_hotspots','puzzle_hotspots']:
 for h in m[group]:
  x,y,w,hh=h['rect'];assert x>=0 and y>=0 and w>=64 and hh>=64 and x+w<=1448 and y+hh<=1086,h
lamp=(root/'assets/props/lamp_off.png').read_bytes()
assert lamp[25]==6,'Lamp must have RGBA PNG encoding'
assert len(ids)==len(list((root/'assets').rglob('*.png'))),'Unlisted PNG asset'
print(f'PASS: {len(ids)} PNG assets, SVG sources, checksums, state dimensions, alpha encoding and touch target bounds')
