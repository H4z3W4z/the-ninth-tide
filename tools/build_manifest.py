from pathlib import Path
import json,struct,hashlib
root=Path(__file__).resolve().parents[1]
assets=[]
for p in sorted((root/'assets').rglob('*.png')):
 data=p.read_bytes();w,h=struct.unpack('>II',data[16:24])
 assets.append({'id':p.stem,'path':str(p.relative_to(root)),'width':w,'height':h,'sha256':hashlib.sha256(data).hexdigest(),'kind':'background' if p.parent.name=='backgrounds' else 'overlay_or_sprite','source_svg':str(p.with_suffix('.svg').relative_to(root)) if p.with_suffix('.svg').exists() else None})
m={'schema':1,'room':'R02','puzzle':'P01','canvas':[1448,1086], 'origin':'top-left','coordinates':'logical pixels','assets':assets,
 'layers':[{'id':'background','rect':[0,0,1448,1086]},{'id':'lamp_off','rect':[242,469,192,288]},{'id':'lamp_light','rect':[242,469,192,288],'visible_when':'bridge_installed AND supply_on'},{'id':'spares_tray','rect':[341,666,128,64]},{'id':'rain_0..2','rect':[0,0,1448,1086],'visible_when':'weather > 0 AND motion_enabled'}],
 'weather_states':[{'id':0,'asset':'office_arrival','story_trigger':'arrival'}, {'id':1,'asset':'office_rain','story_trigger':'P09_complete'}, {'id':2,'asset':'office_ominous','story_trigger':'P17_complete AND P18_complete'}],
 'room_hotspots':[{'id':'lamp_and_parts','rect':[242,469,230,265],'action':'open_repair'},{'id':'duty_card','rect':[726,625,180,110],'action':'read_duty'},{'id':'window','rect':[420,80,440,526],'action':'inspect_weather'},{'id':'coat','rect':[1016,280,184,650],'action':'inspect_coat'},{'id':'service_door','rect':[1189,124,258,780],'action':'locked_until_P06'}],
 'puzzle_hotspots':[{'id':'switch','rect':[260,582,370,126]},{'id':'socket','rect':[250,435,415,132]},{'id':'part_b','rect':[88,855,278,139]},{'id':'part_c','rect':[376,855,278,139]}],
 'puzzle':{'initial':{'supply_on':True,'bridge_installed':False,'complete':False},'solution':['supply_off','select_B','fit_B','supply_on'],'wrong_part':'C','reward':'chart_note; instrument-room access flags in full game','no_loss_on_wrong_attempt':True},
 'limitations':['Weather plates are separately generated: small texture differences exist; switch on room re-entry rather than slow pixel crossfades.','Coat, its late shadow, documents and most furniture are baked into room plates in this first-room preview.','Lamp is a separate alpha sprite; on state uses a precise separate lamp_light overlay.','Window rain is a separate three-frame overlay; base weather is baked into each plate.','Contains initial P01 asset set, not later P20 puzzle art or the remaining game.']}
(root/'asset_manifest.json').write_text(json.dumps(m,indent=2)+'\n')
print(f'Manifest: {len(assets)} PNG assets')
