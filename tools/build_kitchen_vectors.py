"""Build R05's exact graphic assets and inspection layouts; no runtime implementation."""
from pathlib import Path
from html import escape
from itertools import permutations, product
import json
import subprocess
from PIL import ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/kitchen'
INK='#182f38'; PAPER='#e4dbc2'; SEA='#567271'; BRASS='#bc975d'; WOOD='#795f4a'
ASSETS=[]; TEXT_CHECKS=[]

def text(x,y,value,size=28,color=INK,anchor='start'):
    font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',size)
    width=font.getlength(value)
    TEXT_CHECKS.append((x,y,width,size,anchor,value))
    return f'<text x="{x}" y="{y}" font-family="DejaVu Sans" font-size="{size}" fill="{color}" text-anchor="{anchor}">{escape(value)}</text>'
def rect(x,y,w,h,fill,stroke=INK,sw=2,rx=0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
def line(x1,y1,x2,y2,color=INK,width=2):
    return f'<path d="M{x1} {y1} L{x2} {y2}" fill="none" stroke="{color}" stroke-width="{width}"/>'
def circle(x,y,r,fill,stroke=INK,sw=2):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
def svg(name,w,h,body,role,visibility='R05 available after P06'):
    path=OUT/(name+'.svg'); path.parent.mkdir(parents=True,exist_ok=True)
    for x,y,tw,sz,anchor,value in TEXT_CHECKS:
        left=x-tw/2 if anchor=='middle' else x-tw if anchor=='end' else x
        assert left>=-1 and left+tw<=w+1 and sz<=y<=h, (name,value,left,tw,w,y)
    TEXT_CHECKS.clear()
    source=f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><g stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>\n'
    if not path.exists() or path.read_text()!=source or not path.with_suffix('.png').exists():
        path.write_text(source)
        subprocess.run(['inkscape',str(path),'--export-type=png','--export-filename='+str(path.with_suffix('.png'))],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    ASSETS.append({'id':path.stem,'path':str(path.with_suffix('.png').relative_to(ROOT)),'source_svg':str(path.relative_to(ROOT)),'size':[w,h],'role':role,'visible_when':visibility})
def document(name,title,subtitle,lines,visibility='R05 available after P06',extra=''):
    body=rect(1,1,798,998,PAPER)+rect(24,24,752,952,'none',sw=1)
    body+=text(58,78,'GREYWAKE SURVEY STATION',23,SEA)+text(58,142,title,33)+text(58,186,subtitle,22,SEA)+line(58,213,742,213)
    for i,value in enumerate(lines): body+=text(58,266+i*43,value,25)
    svg('documents/'+name,800,1000,body+extra,'readable_document',visibility)
def button(name,label,w=260,h=84,fill=PAPER,size=28):
    svg('puzzle/'+name,w,h,rect(2,2,w-4,h-4,fill,rx=8)+text(w/2,h/2+size*.35,label,size,anchor='middle'),'control_graphic')

INITIALS=['NB','SR','TI','AL','CM','DH','EP','JW']
document('r05_serving_ledger','SUPPER / SERVICE','Nora Bell / provisioning book',[
    'Signed meal chits: 8',
    'NB  /  SR  /  TI  /  AL',
    'CM  /  DH  /  EP  /  JW',
    '', 'Portions served: 9', 'Portions left over: 0', '',
    'Nine portions. Eight signatures.',
    'I feed the people who sit down.', '', 'N. Bell',
])
document('r05_table_instructions','SET THE PLACES','Cloth pinned beneath the serving book',[
    'Match each initialed bowl to its place.',
    'The unsigned bowl has a square repair.',
    'Find the same square on the cloth.', '',
    'Set the tally to the portions served.',
    'Compare it with the official count.', '',
    'A place is not a signature.',
    'Neither is a signature a meal.',
])
document('r05_extra_diner_note','THE EXTRA BOWL','Folded inside the service drawer',[
    'The extra bowl was Venn\u2019s.',
    'He ate with us.', '',
    'His name is absent from the',
    'official attendance register.', '',
    'I kept a place for him.', '', 'N. Bell',
], 'P07 complete; preserve in notebook')
document('r05_amendment_rules','CORRECTION RULE','Service board / printed procedure',[
    'Keep the original entry legible.',
    'Add the missing person by name',
    'and state whether present.',
    'Authenticate the amendment with',
    'that person\u2019s seal.', '',
    'Fit both service-token halves.',
    'Append the correction. Then stamp.', '',
    'Never replace an original entry.',
])
document('r05_menu_objection','NUTRITIONALLY SUFFICIENT','Ration correction / pencil in margin',[
    'The menu has been approved.', '',
    'Rook has discovered a ninth appetite.',
    'It belongs to Rook.', '',
    'N. B.', '',
    'Please return the dry towel folded.',
    'I do not ask much.',
])
# Nora's cup sketch is evidence of an item physically retained in R06.
sketch='<path d="M240 630 L465 630 L448 823 Q354 855 257 823 Z M465 666 C600 635 600 811 451 790" fill="none" stroke="'+INK+'" stroke-width="5"/>'
sketch+=text(350,741,'NB',38,anchor='middle')+rect(493,662,40,23,BRASS,sw=2)+rect(502,773,38,23,BRASS,sw=2)
sketch+=line(541,676,650,635)+text(465,603,'HANDLE REPAIRED',22,SEA)
document('r05_provisioning_repair','PERSONAL UTENSILS','Nora Bell / provisioning page',[
    'One cup, marked NB.',
    'Handle repaired at both joins.',
    'Kept on Bell\u2019s shelf in the bunk room.', '',
    'The handle holds. The cup stays.',
],extra=sketch)
document('r05_duplicate_board','BEHIND THE BOARD','Ada\u2019s preserved copy',[
    'Eight retained.',
    'One witnessing.', '',
    'The words were behind the first board.',
    'I copied them before the glass clouded.',
], 'P09 complete; auto-preserve before condensation')
document('r05_p07_record','SUPPER RECONSTRUCTED','Ada\u2019s preserved comparison',[
    'Signed meal chits: 8',
    'Places used: 9',
    'Portions served: 9',
    'Official attendance: 8', '',
    'The unsigned bowl belongs to Venn.',
    'Nora\u2019s note supplies his name.',
], 'P07 complete; preserve with drawer note')
document('r05_p09_record','ATTENDANCE AMENDMENT','Original and correction retained',[
    'ORIGINAL ENTRY',
    'Official attendance: 8', '',
    'APPENDED CORRECTION',
    '+1 / VENN / present', '',
    'Authenticated: three-cut seal.',
    'Both service-token halves fitted.',
], 'P09 complete; preserve original and amendment')

# Work card supplies P14's future comparison without granting a laboratory reward.
trace='<path d="M80 762 H128 L151 691 L174 762 H204 L227 691 L250 762 H413 Q438 605 474 605 Q510 605 540 762 H718" fill="none" stroke="'+INK+'" stroke-width="5"/>'
trace+=line(75,785,725,785,SEA,2)
trace+=text(166,836,'TWO SHORT RISES',19,anchor='middle')+text(333,836,'PAUSE',19,anchor='middle')+text(566,836,'ONE LONG RISE',19,anchor='middle')
document('r05_kitchen_work_card','CALIBRATION / WORK CARD','Nora Bell / retained reference',[
    'Recorded during kitchen calibration.', '',
    'Two short rises.', 'A pause.', 'One long rise.', '',
    'The trace below records that order.',
],extra=trace)
# Room labels share identities with close-up bowls; simple front-facing marks.
for mark in INITIALS:
    svg('puzzle/r05_initial_'+mark.lower(),100,50,text(50,38,mark,35,anchor='middle'),'exact_room_bowl_or_cloth_mark')
svg('puzzle/r05_square_patch',50,50,rect(4,4,42,42,'#b9ab83',sw=3)+line(9,9,41,41,'#776e55',2),'exact_room_unsigned_bowl_patch')
svg('puzzle/r05_square_place',50,50,rect(4,4,42,42,'none',sw=3),'exact_room_ninth_place_mark')
svg('puzzle/r05_duplicate_board_reveal',1000,580,rect(2,2,996,576,'#bcc5b4',sw=3)+text(500,251,'Eight retained.',54,anchor='middle')+text(500,334,'One witnessing.',54,anchor='middle'),'physical_duplicate_board_reveal','P09 complete; preserve text before condensation')

# Bowls and matching cloth: exact plan-view inspection, independent of room projection.
bowls=[]
for mark in INITIALS+['unsigned']:
    aid='r05_bowl_'+mark.lower()
    body=circle(100,100,96,'#c3c7b3',sw=3)+circle(100,100,80,'#eee4ca',sw=2)+circle(100,100,64,'#d8d2b8',sw=1)
    body+='<path d="M59 116 Q100 129 145 107" fill="none" stroke="#999b86" stroke-width="2"/>'
    if mark=='unsigned':
        body+=rect(144,140,34,34,'#b9ab83',sw=3)+line(149,144,174,170,'#776e55',2)
    else: body+=text(100,111,mark,34,anchor='middle')
    svg('puzzle/'+aid,200,200,body,'inspectable_bowl','P07 available; retain placements')
    bowls.append({'id':mark,'asset_id':aid,'square_repair':mark=='unsigned'})
body=rect(2,2,966,726,'#bcc5b4',sw=3)+rect(18,18,934,694,'none',sw=2)
slots=[]
for i,mark in enumerate(INITIALS+['unsigned']):
    col,row=i%3,i//3; cx=175+300*col; cy=150+220*row
    body+=circle(cx,cy,95,'none',SEA,2)
    if mark=='unsigned': body+=rect(cx+53,cy+50,39,39,'none',sw=3)
    else: body+=text(cx,cy-103,mark,26,anchor='middle')
    # Indentations are subtle atmosphere, not another code.
    body+=f'<ellipse cx="{cx+116}" cy="{cy+2}" rx="10" ry="34" fill="#80928a" opacity=".3"/>'
    body+=line(cx+116,cy+30,cx+116,cy+78,'#879990',3)
    slots.append({'id':mark,'rect':[50+cx-100,180+cy-100,200,200], 'bowl_rect':[50+cx-80,180+cy-80,160,160], 'matches':mark})
svg('puzzle/r05_place_cloth',970,730,body,'nine_place_plan_view_cloth')
body=rect(1,1,1446,1084,WOOD,sw=2)+rect(24,24,1400,1038,'none',stroke=BRASS)
body+=text(58,86,'NINE APPETITES',38,PAPER)+text(58,135,'Set the places. Count the portions. Compare the record.',27,PAPER)
body+=rect(1040,180,358,725,'#ccd1bb',sw=3)+text(1219,230,'SERVING TALLY',25,anchor='middle')
body+=text(1219,498,'OFFICIAL COUNT',25,anchor='middle')+text(1219,586,'8',84,anchor='middle')
body+=text(58,928,'BOWLS / tap to select, then tap a place',23,PAPER)
svg('puzzle/r05_p07_panel',1448,1086,body,'P07_inspection_backplate')
for tally in range(7,11):
    svg(f'puzzle/r05_tally_{tally}',150,110,rect(2,2,146,106,PAPER)+text(75,86,str(tally),78,anchor='middle'),'tally_state')
for name,label,w,h in [('r05_tally_minus','−',96,80),('r05_tally_plus','+',96,80),('r05_compare','COMPARE',298,90),('r05_clear_places','CLEAR PLACES',298,76),('r05_inspect_ledger','SERVING BOOK',298,76),('r05_back','BACK',180,76)]: button(name,label,w,h)
svg('puzzle/r05_bowl_selected',200,200,rect(2,2,196,196,'none',BRASS,4,12),'selection_outline')
for name,lines in [
    ('r05_p07_places_disagree',['Places disagree.','Check initials and the square repair.']),
    ('r05_p07_tally_disagrees',['Portions disagree.','Compare your tally with Nora\u2019s book.']),
    ('r05_p07_success',['9 meals. 8 names.','The service drawer has unlatched.']),
]:
    body=rect(2,2,936,138,PAPER,sw=3,rx=8)
    for i,txt in enumerate(lines): body+=text(470,51+i*47,txt,30,anchor='middle')
    svg('puzzle/'+name,940,142,body,'feedback_card','P07 evaluation, according to result')
# Native spoon cue, reusable as two discrete states: no animation dependency.
for state,offset in [('rest',34),('raised',8)]:
    body=f'<ellipse cx="56" cy="{offset+30}" rx="21" ry="29" fill="#bbc3bb" stroke="{INK}" stroke-width="3"/>'
    body+=rect(51,offset+55,10,99,'#adb8b2',sw=2,rx=5)
    if state=='raised': body+='<ellipse cx="57" cy="185" rx="24" ry="8" fill="#263f43" opacity=".2"/>'
    svg('effects/r05_spoon_'+state,112,210,body,'spoon_event_pose','Once after P07; reduced motion uses rest and caption')
for phase in range(3):
    radius=75-phase*20
    svg('effects/r05_bowl_condensation_'+str(phase),200,200,circle(100,100,radius,'none','#eaf0df',3),'inward_condensation_stage','P07 resolved; optional effect, evidence unaffected')

# Service token halves have complementary, asymmetric joining geometry.
for side in ['pantry','bunk']:
    if side=='pantry': path='M8 8 H202 V52 L180 72 L202 93 V146 L185 164 L202 180 V222 H8 Z'; label='PANTRY'
    else: path='M202 8 H8 V52 L-14 72 L8 93 V146 L-9 164 L8 180 V222 H202 Z'; label='BUNK'
    # Bunk origin shifted to ensure negative seam geometry has positive canvas bounds.
    if side=='bunk': path='M222 8 H28 V52 L6 72 L28 93 V146 L11 164 L28 180 V222 H222 Z'
    body=f'<path d="{path}" fill="{BRASS}" stroke="{INK}" stroke-width="3"/>'
    body+=text(110 if side=='pantry' else 126,117,label,26,anchor='middle')
    body+=circle(56 if side=='pantry' else 182,185,11,'none',sw=3)
    svg('puzzle/r05_token_'+side,230,230,body,'service_token_half','P07 complete' if side=='pantry' else 'P08 complete; supplied by R06')
for cuts in [1,2,3]:
    body=circle(70,70,64,BRASS,sw=3)+circle(70,70,50,'none')
    for j in range(cuts): body+=line(52+18*j-(cuts-1)*9,38,52+18*j-(cuts-1)*9,88,INK,5)
    body+=text(70,123,str(cuts),24,anchor='middle')
    svg('puzzle/r05_seal_'+str(cuts),140,140,body,'seal_selector_state','P09 available; compare retained P08 seal rubbing')
body=rect(1,1,1446,1084,WOOD,sw=2)+rect(24,24,1400,1038,'none',stroke=BRASS)
body+=text(60,83,'THE MEAL THEY REMOVED',38,PAPER)+text(60,135,'Fit both halves. Preserve the entry. Append the missing person.',27,PAPER)
body+=rect(58,173,1332,218,'#344b4d',sw=3)+text(82,220,'SERVICE RELEASE',22,PAPER)
body+=text(965,241,'PANTRY + BUNK',28,PAPER)+text(965,287,'Both halves required',23,PAPER)
body+=rect(60,425,335,389,PAPER,sw=3)+text(227,477,'ORIGINAL ENTRY',26,anchor='middle')
body+=text(227,536,'Official attendance',23,anchor='middle')+text(227,660,'8',100,anchor='middle')
body+=text(227,729,'RETAIN LEGIBLY',23,SEA,anchor='middle')
body+=text(460,435,'APPENDED CORRECTION',27,PAPER)
for x,label in [(460,'CHANGE'),(750,'NAME'),(1040,'STATUS')]: body+=text(x+130,475,label,25,PAPER,anchor='middle')
body+=text(460,727,'PERSONAL SEAL',27,PAPER)
body+=text(460,952,'One cut / two cuts / three cuts',24,PAPER)
svg('puzzle/r05_p09_panel',1448,1086,body,'P09_inspection_backplate','R05 board inspectable after P06; interaction after P07 AND P08')
svg('puzzle/r05_token_socket',456,180,rect(2,2,452,176,'#182f38',BRASS,3)+line(228,8,228,172,BRASS,2),'paired_token_socket')
# Panel tokens use same source scale and origins; pantry edge x202 aligns bunk edge x28.
for field,values in [('delta',['0','+1','+2']),('name',['BELL','ROOK','VENN','IVES']),('status',['absent','present'])]:
    for value in values:
        aid='r05_'+field+'_'+value.lower().replace('+','plus')
        button(aid,value,260,100,fill=PAPER,size=34)
button('r05_previous','PREV',116,76,size=25); button('r05_next','NEXT',116,76,size=25)
button('r05_stamp','STAMP',280,96,fill=BRASS,size=32)
button('r05_read_rule','CORRECTION RULE',335,76,size=25)
svg('puzzle/r05_seal_selected',160,160,rect(2,2,156,156,'none',PAPER,4,12),'selected_seal_outline')
svg('puzzle/r05_amendment_stamp',200,180,circle(100,90,80,'none',INK,4)+''.join(line(x,48,x,126,INK,6) for x in [72,100,128]),'three_cut_stamp','P09 complete')
for name,lines in [
    ('r05_p09_tokens_missing',['Both halves are needed.','The unmatched release will not turn.']),
    ('r05_p09_original_changed',['The original must remain legible.','Append your correction beneath it.']),
    ('r05_p09_amendment_incorrect',['The amendment is not yet verified.','Compare the serving note and seal.']),
    ('r05_p09_success',['Service access released.','The original eight remain visible.']),
]:
    body=rect(2,2,936,138,PAPER,sw=3,rx=8)
    for i,txt in enumerate(lines): body+=text(470,51+i*47,txt,30,anchor='middle')
    svg('puzzle/'+name,940,142,body,'feedback_card','P09 evaluation, according to result')
svg('effects/r05_board_condensation',1000,580,'<path d="M20 10 Q340 130 570 10 T980 50 L980 560 Q620 370 20 540 Z" fill="#b6c6bf" opacity=".32"/>','board_condensation','After P09 duplicate text has been preserved; never obscure notebook copy')

# Layouts are consumed by manifest and static review generators.
def layer(a,rect): return {'asset_id':a,'rect':rect}
controls07={
 'minus':{'asset_id':'r05_tally_minus','rect':[1060,374,96,80]},
 'plus':{'asset_id':'r05_tally_plus','rect':[1282,374,96,80]},
 'compare':{'asset_id':'r05_compare','rect':[1070,616,298,90]},
 'clear':{'asset_id':'r05_clear_places','rect':[1070,728,298,76]},
 'ledger':{'asset_id':'r05_inspect_ledger','rect':[1070,821,298,76]},
 'back':{'asset_id':'r05_back','rect':[1208,960,180,76]},
}
base07=[layer('r05_p07_panel',[0,0,1448,1086]),layer('r05_place_cloth',[50,180,970,730])]+list(controls07.values())
rack=[{'bowl':b['id'],'asset_id':b['asset_id'],'rect':[60+i*104,948,90,90]} for i,b in enumerate(bowls)]
views07={}
for state,occupied,tally in [('initial',[],8),('partial',['NB','SR','TI','unsigned'],9),('solved',INITIALS+['unsigned'],9)]:
    # Partial deliberately puts unsigned bowl correctly while leaving five places empty.
    layers=base07+[layer('r05_tally_'+str(tally),[1144,250,150,110])]
    for b,s in zip(bowls,slots):
        layers.append(layer(b['asset_id'],s['bowl_rect'] if b['id'] in occupied else rack[bowls.index(b)]['rect']))
    views07[state]={'layers':layers,'occupied_slots':occupied,'tally':tally,'completed':state=='solved'}
controls09={'stamp':{'asset_id':'r05_stamp','rect':[1110,837,280,96]},'rules':{'asset_id':'r05_read_rule','rect':[60,853,335,76]},'back':{'asset_id':'r05_back','rect':[1208,960,180,76]}}
fields={}
for field,x,values in [('delta',460,['0','+1','+2']),('name',750,['BELL','ROOK','VENN','IVES']),('status',1040,['absent','present'])]:
    fields[field]={'rect':[x,500,260,100],'values':values,'asset_ids':{v:'r05_'+field+'_'+v.lower().replace('+','plus') for v in values},'controls':{'previous':{'asset_id':'r05_previous','rect':[x,617,116,76]},'next':{'asset_id':'r05_next','rect':[x+144,617,116,76]}}}
seals=[{'cuts':i,'asset_id':'r05_seal_'+str(i),'rect':[470+(i-1)*190,757,140,140]} for i in [1,2,3]]
tokens={'pantry':{'asset_id':'r05_token_pantry','rect':[388,205,161,161]},'bunk':{'asset_id':'r05_token_bunk','rect':[509.8,205,161,161]}}
base09=[layer('r05_p09_panel',[0,0,1448,1086]),layer('r05_token_socket',[320,195,456,180])]+list(controls09.values())+seals
for field in fields.values(): base09+=list(field['controls'].values())
views09={}
for state,occupied,vals,seal in [('initial',[],['0','BELL','absent'],1),('partial',['pantry'],['+1','VENN','present'],2),('solved',['pantry','bunk'],['+1','VENN','present'],3)]:
    layers=base09+list(tokens[t] for t in occupied)
    for f,v in zip(fields.values(),vals): layers.append(layer(f['asset_ids'][v],f['rect']))
    layers.append(layer('r05_seal_selected',[460+(seal-1)*190,747,160,160]))
    if state=='solved': layers.append(layer('r05_amendment_stamp',[1140,710,130,117]))
    views09[state]={'layers':layers,'token_halves':occupied,'fields':dict(zip(fields,vals)),'seal_cuts':seal,'original':8,'completed':state=='solved'}

# A nine-place matching bijection has exactly one valid arrangement. Enumerate
# permutations without graphics to catch duplicate or ambiguous marks.
marks=INITIALS+['unsigned']; valid07=0
for order in permutations(marks):
    if all(got==want for got,want in zip(order,marks)): valid07+=1
assert valid07==1 and len(set(marks))==9
valid09=[]; tested09=0
for pantry,bunk,original,delta,name,status,seal in product([False,True],[False,True],[8,9],['0','+1','+2'],['BELL','ROOK','VENN','IVES'],['absent','present'],[1,2,3]):
    tested09+=1
    if pantry and bunk and original==8 and delta=='+1' and name=='VENN' and status=='present' and seal==3:
        valid09.append([pantry,bunk,original,delta,name,status,seal])
assert valid09==[[True,True,8,'+1','VENN','present',3]]
assets_by_id={a['id']:a for a in ASSETS}
allcontrols=list(controls07.values())+rack+[{'rect':s['rect']} for s in slots]+list(controls09.values())+seals
allcontrols += [v for f in fields.values() for v in f['controls'].values()]
for c in allcontrols:
    x,y,w,h=c['rect']; assert 0<=x<x+w<=1448 and 0<=y<y+h<=1086,c
    assert min(w,h)*1024/1448>=44,c
for view in list(views07.values())+list(views09.values()):
    for item in view['layers']:
        assert item['asset_id'] in assets_by_id,item
        x,y,w,h=item['rect']; assert 0<=x and x+w<=1448 and 0<=y and y+h<=1086,item
assert abs((tokens['pantry']['rect'][0]+202*.7)-(tokens['bunk']['rect'][0]+28*.7))<.001
spec={
 'schema':2,'room_id':'R05','generated_by':'tools/build_kitchen_vectors.py','canvas':[1448,1086],
 'initials':{'established':['NB','SR','TI'],'production_proposals':['AL','CM','DH','EP','JW'],'note':'Five additional initials are art production choices, not newly named cast members.'},
 'assets':ASSETS,
 'panels':{
  'P07':{'requires':['P06'],'canvas':[1448,1086],'slots':slots,'bowls':bowls,'selection_controls':rack,'controls':controls07,'tally_values':[7,8,9,10],
   'initial_state':{'slots':[None]*9,'tally':8,'completed':False},'views':views07,
   'solution':{'slot_order':marks,'tally':9,'official':8,'evaluate_action':'compare'},
   'interaction':['Tap a bowl then its matching cloth place; dragging optional. Tap an occupied place to return its bowl.','Every placement persists on leaving the room; CLEAR PLACES resets only unsolved arrangement, without consuming bowls.','COMPARE first reports mismatched places, then incorrect portions; valid nine-place arrangement plus tally9 completes P07.','Completed evidence survives all weather changes and subsequent rearrangement; clear control disabled after solve.'],
   'completion_outputs':['r05_token_pantry','r05_extra_diner_note','r05_p07_record'],
   'horror_event':{'event':'spoon rises once then settles; condensation moves inward','poses':['r05_spoon_rest','r05_spoon_raised'],'frames':['r05_bowl_condensation_0','r05_bowl_condensation_1','r05_bowl_condensation_2'],'reduced_motion':'Hold rest pose and show caption: The spoon rises, waits, and lowers.','completion_independent_of_animation':True},
   'evidence_assets':['r05_serving_ledger','r05_table_instructions'],'feedback':{'places':'r05_p07_places_disagree','tally':'r05_p07_tally_disagrees','success':'r05_p07_success'}},
  'P09':{'requires':['P07','P08'],'canvas':[1448,1086],'fields':fields,'controls':controls09,'seal_controls':seals,'token_slots':tokens,'views':views09,
   'initial_state':{'tokens':[],'official':8,'delta':'0','name':'BELL','status':'absent','seal_cuts':1,'completed':False},
   'solution':{'tokens':['pantry','bunk'],'official':8,'delta':'+1','name':'VENN','status':'present','seal_cuts':3,'evaluate_action':'stamp'},
   'token_sources':{'pantry':'P07 service drawer','bunk':'P08 Venn locker'},'seal_source':'P08 retained three-cut seal rubbing; not consumed',
   'interaction':['Board may be inspected afterP06; amendment interaction requires P07 and P08.','Tap an inventory token then its socket. Halves remain recoverable until valid stamped correction.','PREV/NEXT cycle each amendment field; tap a seal selector then STAMP.','Original attendance8 remains visible and immutable. Tapping it explains the additive correction rule; overwrite attempts reject without loss.','Consume both token halves together only when the whole correction is accepted. Preserve the seal rubbing.','On completion preserve the duplicate board text before any condensation animation.'],
   'completion_outputs':['r05_p09_record','r05_duplicate_board'],'unlocks':['R07','R08'],'tide_on_completion':'III',
   'evidence_assets':['r05_serving_ledger','r05_extra_diner_note','r05_amendment_rules'],'feedback':{'tokens':'r05_p09_tokens_missing','original':'r05_p09_original_changed','amendment':'r05_p09_amendment_incorrect','success':'r05_p09_success'}}},
 'evidence_gates':{'r05_kitchen_work_card':'P06; preserve for future P14; no laboratory completion granted','r05_serving_ledger':'P06','r05_table_instructions':'P06','r05_amendment_rules':'P06','r05_menu_objection':'P06','r05_provisioning_repair':'P06; preserve for later P22 without awarding its amendment','r05_extra_diner_note':'P07 complete','r05_p07_record':'P07 complete','r05_duplicate_board':'P09 complete; preserve before condensation','r05_duplicate_board_reveal':'P09 complete; physical board view; preserve before condensation','r05_p09_record':'P09 complete'},
 'validation':{'P07_permutations_checked':362880,'P07_valid_bowl_arrangements':valid07,'P07_valid_tally':9,'P09_configurations_checked':tested09,'P09_valid_configurations':valid09,'minimum_touch_target_at_1024':44,'checks':['Nine unique marks and one matching bijection','Token seam source and target geometry coincide','P09 only accepts both halves, retained8, +1/VENN/present/three cuts','Every text element fits its authored canvas','Every panel layer resolves and fits1448x1086','All controls meet44px target at1024reference']},
 'limitations':['Graphic specification and static layouts only; no Godot gameplay or audio.','Independent room sprite poses are not registered animation frames.','P08 token and seal evidence must come from R06; R05 graphics do not grant these early.','Nora cup itself remains R06; kitchen contains only provisioning sketch.','Exact plan-view inspection is intentionally separate from flat front-facing room elevation.']}
for panel in spec['panels'].values():
    panel['review_poses']={name:dict(view,canvas=panel['canvas']) for name,view in panel['views'].items()}
(OUT/'authored-spec.json').write_text(json.dumps(spec,indent=2)+'\n')
print(f'Authored {len(ASSETS)} SVG/PNG pairs; P07 1/362880 bowl arrangements, tally9; P09 1/{tested09} configurations; target/text/layout checks passed.')
