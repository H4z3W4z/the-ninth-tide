"""Lay out existing game layers as a review sheet; does not modify asset pixels."""
from pathlib import Path
import base64,subprocess
root=Path(__file__).resolve().parents[1]
def img(path,x,y,w,h):
 b=base64.b64encode((root/path).read_bytes()).decode()
 return f'<image x="{x}" y="{y}" width="{w}" height="{h}" xlink:href="data:image/png;base64,{b}"/>'
def room(bg,on):
 s=img('assets/backgrounds/'+bg+'.png',0,0,1448,1086)
 s+=img('assets/props/lamp_off.png',242,469,192,288)
 if on:s+=img('assets/props/lamp_light.png',242,469,192,288)
 s+=img('assets/props/spares_tray.png',341,666,128,64)
 return s
body='<rect width="1600" height="1530" fill="#142b34"/>'
def txt(x,y,t,size=24,color='#ded4ba'):
 return f'<text x="{x}" y="{y}" fill="{color}" font-size="{size}" font-family="DejaVu Sans">{t}</text>'
body+=txt(48,61,'THE NINTH TIDE',36)+txt(48,98,'INTAKE OFFICE  /  P01 ASSET ASSEMBLY',19,'#a7bab2')
body+=txt(48,141,'Arrival · lamp awaiting repair')+txt(816,141,'Tide VI · lamp repaired')
body+='<g transform="translate(48 166) scale(.50828)">'+room('office_arrival',False)+'</g>'
body+='<g transform="translate(816 166) scale(.50828)">'+room('office_ominous',True)+'</g>'
body+=txt(48,779,'Repair close-up · separated operational layers')
body+='<g transform="translate(48 807) scale(.655)">'+img('assets/puzzle/repair_panel.png',0,0,1448,1086)+img('assets/puzzle/switch_off.png',0,0,1448,1086)+img('assets/puzzle/bridge_b.png',106,868,240,120)+img('assets/puzzle/bridge_c.png',396,868,240,120)+'</g>'
body+=txt(1050,852,'25 PNG assets',28)+txt(1050,895,'21 editable SVG sources',23)
body+=txt(1050,963,'P01 solution',25)
for i,line in enumerate(['Supply OFF','Fit straight bridge B','Supply ON']):body+=txt(1050,1007+i*42,line,23)
body+=txt(1050,1190,'Weather follows progress.',23)+txt(1050,1230,'Clues remain readable.',23)+txt(1050,1300,'First-room scaffold',21,'#a7bab2')+txt(1050,1335,'Not the complete game',21,'#a7bab2')
p=root/'docs/asset-review.svg';p.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1600" height="1530">{body}</svg>')
subprocess.run(['inkscape',str(p),'--export-type=png','--export-filename='+str(p.with_suffix('.png'))],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
# The composed SVG embeds duplicates of all bitmaps; keep only the small reproducible script and PNG review.
p.unlink()
print('Rendered asset assembly review sheet.')
