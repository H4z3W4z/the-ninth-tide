from pathlib import Path
import subprocess, json, shutil
ROOT=Path(__file__).resolve().parents[1]
INK='#172b36'; PAPER='#ded4ba'; GOLD='#bc9047'; GREEN='#91a89c'

def svg(name,w,h,body):
 p=ROOT/'assets'/name;p.parent.mkdir(parents=True,exist_ok=True)
 p.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><g stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>')
 subprocess.run(['inkscape',str(p),'--export-type=png','--export-filename='+str(p.with_suffix('.png'))],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)

def text(x,y,t,size=28,color=INK,anchor='start'):
 return f'<text x="{x}" y="{y}" font-family="DejaVu Sans" font-size="{size}" fill="{color}" text-anchor="{anchor}">{t}</text>'
def rect(x,y,w,h,fill,stroke=INK,sw=3,rx=0):
 return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
def circle(x,y,r,fill,stroke=INK,sw=3):
 return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
# Precise bridge parts, same 240x120 bounds and 160-unit terminal spacing.
b=rect(24,42,192,36,GOLD,sw=4,rx=8)+circle(40,60,9,PAPER)+circle(200,60,9,PAPER)+text(120,70,'B',28,anchor='middle')
c='<path d="M24 78 Q120 -18 216 78 L198 105 Q120 28 42 105 Z" fill="'+GOLD+'" stroke="'+INK+'" stroke-width="4"/>'+circle(40,88,8,PAPER)+circle(200,88,8,PAPER)+text(120,53,'C',25,anchor='middle')
svg('puzzle/bridge_b.svg',240,120,b);svg('puzzle/bridge_c.svg',240,120,c)
# Installed B in room-size closeup coordinate system. This is a transparent overlay.
svg('puzzle/bridge_b_installed.svg',1448,1086,'<g transform="translate(276 434) scale(1.5)">'+b+'</g>')
# A clear socket with screw centres x336,576 / y524, exactly matched by installed B.
body=rect(0,0,1448,1086,'#213c46',sw=0)+rect(32,32,1384,1022,PAPER,sw=3)
body+=text(76,102,'GREYWAKE  /  INSTRUMENT MAINTENANCE',30)+text(76,151,'Desk lamp · contact bridge',25,'#51685f')
body+=f'<path d="M76 177H1372" stroke="{INK}" stroke-width="2"/>'
body+=rect(76,218,740,556,'#697b72',sw=4,rx=10)+rect(118,260,656,286,'#ad8b53',sw=3,rx=8)
for x in [142,750]:
 for y in [284,522]: body+=circle(x,y,7,'#d2b16d')+f'<path d="M{x-4} {y}h8" stroke="{INK}" stroke-width="2"/>'
body+=text(156,319,'BRIDGE B',28)+text(156,359,'Straight contact · isolate before fitting',23)
body+=rect(262,456,389,96,'#263c42',sw=3,rx=8)
body+=f'<path d="M294 524H336 M576 524H620" stroke="{GOLD}" stroke-width="14"/>'
body+=circle(336,524,16,'#c8a865')+circle(576,524,16,'#c8a865')
body+=f'<path d="M356 524H556" stroke="{PAPER}" stroke-width="3" stroke-dasharray="9 10"/>'
body+=text(456,422,'Contact terminals',25,anchor='middle')
body+=text(152,602,'SUPPLY',24)+rect(260,582,370,126,'#263c42',sw=3,rx=8)
body+=text(310,733,'OFF',23,anchor='middle')+text(577,733,'ON',23,anchor='middle')
body+=circle(722,646,24,'#293e42')
body+=rect(861,218,509,556,'#ece3cc',sw=2)
body+=text(896,265,'REPAIR CARD',28)
for i,line in enumerate(['1. Set supply to OFF.','2. Fit straight bridge B.','3. Set supply to ON.']): body+=text(896,317+i*50,line,24)
body+=text(896,495,'REFERENCE SHAPE',21)
body+='<g transform="translate(925 518)">'+b+'</g>'
body+=text(896,684,'Curved spare C will not seat.',22)
body+=text(896,726,'Keep the original record.',22)
body+=text(76,831,'SPARE PARTS',25)+rect(76,855,590,148,'#9a8060',sw=3,rx=6)
body+=rect(88,867,278,122,'#d5c9a9',sw=2)+rect(376,867,278,122,'#d5c9a9',sw=2)
body+=text(711,890,'Select a part, then the socket.',24)+text(711,932,'Match the sketch before fitting.',22,'#51685f')
svg('puzzle/repair_panel.svg',1448,1086,body)
for state,x in [('off',277),('on',469)]:
 svg('puzzle/switch_'+state+'.svg',1448,1086,rect(x,600,143,90,'#c9b98f',sw=4,rx=5)+rect(x+24,617,95,56,'#8d7b56',sw=2,rx=3))
svg('puzzle/indicator_on.svg',1448,1086,circle(722,646,19,'#e6c47b',sw=2))
# Lighting is a separate authored gameplay overlay sharing the lamp sprite's bounds.
svg('props/lamp_light.svg',1024,1536,'<path d="M566 595 Q764 536 958 593 Q768 663 566 595Z" fill="#f5dda3" stroke="#172b36" stroke-width="7"/>')
# Front elevation spare tray for room view; native vector geometry, no perspective.
tray=rect(4,62,232,48,'#655340',sw=4)+rect(12,53,216,18,'#273a3e',sw=3)
tray+='<g transform="translate(23 25) scale(.43)">'+b+'</g><g transform="translate(128 17) scale(.40)">'+c+'</g>'
svg('props/spares_tray.svg',240,120,tray)
# An opening duty card, solved clue card, and named inventory assets.
for name,title,lines in [
 ('duty_card','CLOSURE DUTY',['Inventory the station instruments.','Reconcile outstanding records.','Restore the departure signal.','','Begin with the desk lamp.','The spare bridge is in the tray.']),
 ('chart_note','PENCIL NOTE',['Lamp service completed.','','Chart Room: register both sheets','at the lighthouse cross.','','Listening Room: preserve the','recording before winding again.'])]:
 doc=rect(0,0,800,650,PAPER,sw=3)+rect(24,24,752,602,'none',sw=1)
 doc+=text(58,90,'GREYWAKE SURVEY STATION',24)+text(58,153,title,34)
 doc+=f'<path d="M58 180H742" stroke="{INK}" stroke-width="2"/>'
 for i,line in enumerate(lines): doc+=text(58,236+i*45,line,25)
 svg('puzzle/'+name+'.svg',800,650,doc)
# UI: comfortable targets, distinct selected/normal/complete states.
for name,fill in [('slot', '#354d54'),('slot_selected','#b8914e'),('slot_complete','#91a89c')]:
 svg('ui/'+name+'.svg',160,160,rect(4,4,152,152,fill,sw=4,rx=8)+rect(13,13,134,134,'none',stroke=PAPER,sw=1,rx=3))
for name,label in [('back','BACK'),('hint','HINT'),('notes','NOTES'),('close','CLOSE')]:
 svg('ui/'+name+'.svg',180,72,rect(2,2,176,68,'#263f49',stroke='#d8ceb5',sw=2,rx=5)+text(90,47,label,26,PAPER,'middle'))
# Window rain VFX with hard pane clipping, reusable frame loop.
for i in range(3):
 defs='<defs><clipPath id="panes">'
 for x,y,w,h in [(480,143,105,103),(594,143,97,103),(703,143,96,103),(480,260,105,93),(594,260,97,93),(703,260,96,93),(480,369,319,176)]: defs+=f'<rect x="{x}" y="{y}" width="{w}" height="{h}"/>'
 defs+='</clipPath></defs>'
 strokes=''
 for k in range(26):
  x=485+(k*73%308);y=125+((k*89+i*31)%432)
  strokes+=f'<path d="M{x} {y}l-8 27" stroke="#c2d3d8" stroke-opacity=".22" stroke-width="1.7"/>'
 svg(f'props/rain_{i}.svg',1448,1086,defs+'<g clip-path="url(#panes)">'+strokes+'</g>')
print('Authored and rendered vector assets.')
