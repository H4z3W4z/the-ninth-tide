"""Build the first R06 evidence/art checkpoint. No gameplay implementation."""
from pathlib import Path
from html import escape
import hashlib, json, os, re, subprocess
from PIL import Image, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/bunks'
REVIEW = ROOT / 'art/bunk-review/checkpoint-1'
INK, PAPER, SEA, BRASS, WOOD = '#182f38', '#e4dbc2', '#567271', '#bc975d', '#795f4a'
ASSETS, TEXT = [], []
PROPS = ['cup', 'calipers', 'pencil_holder', 'glove']
OWNERS = ['BELL', 'ROOK', 'VENN', 'IVES']
CARDS = {
    'BELL': ['Nora Bell takes her tea without sugar.', 'Her cup is marked NB.', 'The handle is mended at both joins.', 'She keeps using it because it holds.'],
    'ROOK': ['Rook checks a gap with the outside jaws.', 'His calipers have a nick near the', 'far end of the measuring beam.', 'He checks the instrument before the gap.'],
    'VENN': ['Venn keeps pencils down to their stubs.', 'His wooden holder has a pale crescent', 'worn into its front by his thumb.', 'He reaches for the same place each time.'],
    'IVES': ['Ives repairs a glove instead of replacing it.', 'A broad leather patch covers the palm.', 'Heavy pale stitches hold it in place.', 'The mend is rough. The glove still works.'],
}

def rect(x, y, w, h, fill, stroke=INK, sw=2):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'

def text(x, y, value, size=27, color=INK, anchor='start'):
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', size)
    width = font.getlength(value)
    left = x - width / 2 if anchor == 'middle' else x
    TEXT.append((left, y, width, size, value))
    return f'<text x="{x}" y="{y}" font-family="DejaVu Sans" font-size="{size}" fill="{color}" text-anchor="{anchor}">{escape(value)}</text>'

def path(d, color=INK, sw=3, fill='none'):
    return f'<path d="{d}" stroke="{color}" stroke-width="{sw}" fill="{fill}" stroke-linecap="round" stroke-linejoin="round"/>'

def source(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n'

def write_svg(rel, w, h, body, role, gate='P06 complete', runtime=True):
    for x, y, width, size, value in TEXT:
        assert x >= 12 and x + width <= w - 12 and size <= y <= h - 12, (rel, value, x, width, y)
    TEXT.clear()
    p = (OUT if runtime else REVIEW) / (rel + '.svg')
    p.parent.mkdir(parents=True, exist_ok=True)
    body = re.sub(r'repo:///([^"\s]+)', lambda match: os.path.relpath(ROOT / match.group(1), p.parent), body)
    svg = source(w, h, body)
    if not p.exists() or p.read_text() != svg or not p.with_suffix('.png').exists():
        p.write_text(svg)
        candidate = p.with_suffix('.exporting')
        subprocess.run(['inkscape', str(p), '--export-type=png', '--export-filename=' + str(candidate)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        with Image.open(candidate) as exported:
            exported.load()
        candidate.replace(p.with_suffix('.png'))
    if runtime:
        ASSETS.append({'id': p.stem, 'path': str(p.with_suffix('.png').relative_to(ROOT)), 'source_svg': str(p.relative_to(ROOT)), 'role': role, 'visible_when': gate})
    return p

def image_tag(p, x, y, w, h):
    href = 'repo:///' + str(p.relative_to(ROOT))
    return f'<image x="{x}" y="{y}" width="{w}" height="{h}" xlink:href="{href}"/>'

def markings(prop):
    if prop == 'cup':
        return text(546, 805, 'NB', 76, anchor='middle')
    if prop == 'calipers':
        return path('M969 625 L991 645 L1009 624', '#3a3930', 9)
    if prop == 'pencil_holder':
        return path('M561 864 C479 898 479 978 561 1008', '#d0ad73', 18)
    return ''

BOUNDS = {}
for prop in PROPS:
    p = OUT / 'props' / ('r06_' + prop + '.png')
    im = Image.open(p)
    assert im.mode == 'RGBA' and im.getchannel('A').getextrema() == (0, 255), p
    bounds = im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    BOUNDS[prop] = list(bounds)
    ASSETS.append({'id': p.stem, 'path': str(p.relative_to(ROOT)), 'role': 'generated_prop', 'visible_when': 'P06 complete; placement follows P08', 'source_size': list(im.size), 'alpha_range': [0, 255], 'content_bbox_ltrb': list(bounds), 'bbox_alpha_threshold': 8})
    mark = markings(prop)
    if mark:
        write_svg('puzzle/r06_' + prop + '_mark', *im.size, mark, 'exact_prop_mark')

def prop_image(prop, x, y, w, h):
    p = OUT / 'props' / ('r06_' + prop + '.png')
    left, top, right, bottom = BOUNDS[prop]
    # A nested viewport measures source geometry; original PNG bytes stay untouched.
    mark_start = len(TEXT)
    mark = markings(prop)
    del TEXT[mark_start:]  # Mark coordinates were verified on their own source canvas.
    return f'<svg x="{x}" y="{y}" width="{w}" height="{h}" viewBox="{left-3} {top-3} {right-left+6} {bottom-top+6}" preserveAspectRatio="xMidYMid meet">' + image_tag(p, 0, 0, 1207, 1303) + mark + '</svg>'

def document(aid, title, subtitle, lines, gate='P06 complete', extra=''):
    b = rect(1, 1, 898, 1098, PAPER) + rect(24, 24, 852, 1052, 'none', SEA, 1)
    b += text(56, 72, 'GREYWAKE SURVEY STATION', 23, SEA)
    b += text(56, 135, title, 34) + text(56, 182, subtitle, 23, SEA)
    b += path('M56 210 H844', SEA, 2)
    for i, value in enumerate(lines):
        b += text(56, 267 + i * 45, value, 26)
    write_svg('documents/' + aid, 900, 1100, b + extra, 'readable_evidence', gate)

for owner, prop in zip(OWNERS, PROPS):
    document('r06_card_' + owner.lower(), owner + ' / PERSONAL CARD', 'Bunk locker / distinguishing habit', CARDS[owner], extra=prop_image(prop, 170, 560, 560, 400))
    write_svg('puzzle/r06_label_' + owner.lower(), 280, 96, rect(2, 2, 276, 92, BRASS) + text(140, 63, owner, 36, anchor='middle'), 'exact_locker_label')

document('r06_assignment_rule', 'BELONGINGS / RETURN', 'Four loose objects. Four personal cards.', [
    'Read the card beside each locker.', 'Inspect the repair or wear on the object.', 'Match the belonging to its owner.', '',
    'A wrong match leaves the object on the shelf.', 'The other staff lockers are closed and labeled.', 'They need no work.', '',
    'Return all four belongings to release', 'the bunk-service compartment.',
])
document('r06_p08_record', 'OWNERSHIP ESTABLISHED', "Ada's retained evidence", [
    'Repaired cup / Bell', 'Measuring calipers / Rook', 'Pencil holder / Venn', 'Stitched glove / Ives', '',
    "Venn's compartment released the bunk half", 'of the service token and his seal rubbing.', '',
    "Bell's cup remains on her marked shelf.",
], 'P08 complete; retain in notebook')
seal = '<circle cx="450" cy="755" r="122" fill="#b4aa91" stroke="'+INK+'" stroke-width="4"/>'
for sx in [396, 450, 504]:
    seal += path(f'M{sx} 672 V822', INK, 12)
document('r06_venn_seal', 'VENN / PERSONAL SEAL', 'Pencil rubbing / exactly three cuts', [
    'The rubbing was inside the service compartment.', 'Its three cuts identify Venn.', 'This is an evidence copy; keep it after use.',
], 'P08 complete; preserve for P09 and P19', seal)
document('r06_index_original', 'NORA BELL / INDEX', 'Original entry / preserve without alteration', [
    'No surviving personal effects.', '', 'The statement above is the original record.', 'Keep it visible beside any correction.',
], 'P21 complete; P22 comparison input')
document('r06_amendment_rule', 'PERSONAL RECORD / ADDENDUM', 'Correction procedure', [
    'Keep the original Index entry legible.', 'Compare the named record with the evidence.', 'Append the identified effect and its owner.', '',
    "Bell's repaired cup remains on her shelf.", 'Her provisioning page records both repairs.', '',
    'A correction adds evidence.', 'It does not erase the first statement.',
], 'P21 complete; P22 available')
document('r06_p22_record', 'PERSONAL RECORD / OPEN', 'Original and witnessed amendment retained', [
    'ORIGINAL ENTRY', 'No surviving personal effects.', '', 'APPENDED CORRECTION', 'PERSONAL EFFECT IDENTIFIED', 'REPAIRED CUP', 'NORA BELL', '',
    'The cup has repairs at both handle joins.', 'The original statement remains visible.',
], 'P22 complete; retain in notebook')
document('r06_ives_letter', 'A LETTER NOT FINISHED', 'Ives / optional personal evidence', [
    'The weather has got into everything.', 'Nora says it cannot get into the soup', 'while she is standing over it.', '',
    'She may be right. The soup is good.', '', 'I mended the glove again.', 'It will last until I come home.', '',
    'Tell them I will write properly when',
], 'P08 complete; optional O03 production copy')

def panel(title, subtitle):
    return rect(1, 1, 1446, 1084, WOOD) + text(54, 72, title, 35, PAPER) + text(54, 119, subtitle, 25, PAPER)

for state in ['initial', 'partial', 'solved']:
    body = panel('THE BED THAT WAS USED', 'Match each object to the evidence beside its locker.')
    for i, (owner, prop) in enumerate(zip(OWNERS, PROPS)):
        x = 52 + i * 349
        body += rect(x, 160, 300, 470, PAPER) + text(x+150, 209, owner, 31, anchor='middle')
        filled = state == 'solved' or (state == 'partial' and i in [0, 3])
        if filled:
            body += prop_image(prop, x+28, 250, 244, 268)
        else:
            body += rect(x+26, 254, 248, 254, '#c6c9b4', SEA, 2)
            body += text(x+150, 390, 'PLACE OBJECT', 21, SEA, 'middle')
        body += text(x+150, 581, 'READ PERSONAL CARD', 18, SEA, 'middle')
    body += rect(52, 665, 1347, 290, '#bdc3af')
    for i, prop in enumerate(PROPS):
        if state == 'initial' or (state == 'partial' and i in [1, 2]):
            body += prop_image(prop, 75+i*332, 703, 270, 198)
    caption = 'Four loose belongings.' if state=='initial' else 'Two belongings returned.' if state=='partial' else 'Service compartment released. Evidence retained.'
    body += text(54, 1018, caption, 26, PAPER)
    write_svg('p08_' + state, 1448, 1086, body, 'review_composition', runtime=False)

for solved in [False, True]:
    body = panel('A PERSON IS MORE THAN A CARD', 'Preserve the original. Append the witnessed correction.')
    body += rect(54, 164, 650, 430, PAPER) + text(87, 222, 'NORA BELL / ORIGINAL', 28)
    body += text(87, 289, 'No surviving personal effects.', 27)
    body += rect(742, 164, 650, 430, PAPER) + text(775, 222, 'PROVISIONING EVIDENCE', 28)
    body += text(775, 278, 'NB / handle repaired at both joins.', 24)
    body += prop_image('cup', 875, 321, 345, 214)
    body += rect(54, 630, 1338, 320, '#bdc3af')
    body += text(90, 685, 'APPENDED CORRECTION', 26, SEA)
    if solved:
        for i, value in enumerate(['PERSONAL EFFECT IDENTIFIED', 'REPAIRED CUP', 'NORA BELL']):
            body += text(90, 752+i*65, value, 32)
    else:
        body += text(90, 773, 'Identify the effect and the person it belongs to.', 29)
    body += text(54, 1020, 'The first statement remains visible in both states.', 26, PAPER)
    write_svg('p22_' + ('amended' if solved else 'initial'), 1448, 1086, body, 'review_composition', runtime=False)

# Room proof: layout only. Labels and evidence cards have readable inspection counterparts.
base = OUT/'backgrounds/r06_clean_base.png'
body = image_tag(base, 0, 0, 1448, 1086)
room_rects = {'cup':[1022,676,79,51], 'calipers':[1113,690,110,42], 'pencil_holder':[1240,664,42,62], 'glove':[1300,675,66,54]}
for prop, (x,y,w,h) in room_rects.items():
    body += prop_image(prop,x,y,w,h)
for i, owner in enumerate(OWNERS):
    x = 1032+i*101
    body += image_tag(OUT/'puzzle'/('r06_label_'+owner.lower()+'.png'), x, 322, 54, 20)
    body += image_tag(OUT/'documents'/('r06_card_'+owner.lower()+'.png'), x, 362, 53, 65)
write_svg('room_initial',1448,1086,body,'room_review',runtime=False)

# Review controls only select artwork. They do not represent implemented puzzle logic.
items = [('Room / first entry','room_initial.png'), ('P08 / initial','p08_initial.png'), ('P08 / partial','p08_partial.png'), ('P08 / solved','p08_solved.png'), ('P22 / original','p22_initial.png'), ('P22 / amended','p22_amended.png')]
buttons = ''.join(f'<button type="button" data-src="{src}">{escape(label)}</button>' for label,src in items)
docs = ''.join(f'<figure><a href="../../../{a["path"]}"><img loading="lazy" src="../../../{a["path"]}" alt="{a["id"]}"></a><figcaption>{escape(a["id"])}<br>{escape(a["visible_when"])}</figcaption></figure>' for a in ASSETS if a['role']=='readable_evidence')
REVIEW.mkdir(parents=True,exist_ok=True)
html = '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>R06 Bunk Room / first asset checkpoint</title><style>body{margin:24px;background:#182f38;color:#e4dbc2;font:17px system-ui}main{max-width:1450px;margin:auto}button{padding:12px 18px;margin:5px;background:#e4dbc2;color:#182f38;border:0;border-radius:3px;font:inherit;cursor:pointer}button:focus-visible,a:focus-visible{outline:3px solid #f3c36a;outline-offset:3px}#stage{display:block;width:100%;height:auto;margin:18px 0}.docs{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:22px}figure{margin:0}figure img{width:100%;height:auto}figcaption{font-size:14px;padding:8px 0}a{color:#e4dbc2}</style><main><h1>Bunk Room / first asset checkpoint</h1><p>Working art from concept v1. These compositions review asset placement and evidence; gameplay, animation and physical-device validation remain pending.</p><nav>'+buttons+'</nav><img id="stage" src="room_initial.png" alt="Bunk Room first-entry composition"><h2>Readable evidence</h2><div class="docs">'+docs+'</div></main><script>document.querySelectorAll("button[data-src]").forEach(b=>b.addEventListener("click",()=>{const s=document.getElementById("stage");s.src=b.dataset.src;s.alt=b.textContent;}));</script></html>\n'
(REVIEW/'index.html').write_text(html)

for a in ASSETS:
    p=ROOT/a['path']; im=Image.open(p)
    a['size']=list(im.size);a['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
ASSETS.insert(0,{'id':'r06_clean_base','path':str(base.relative_to(ROOT)),'size':[1448,1086],'role':'working_fixed_room_plate','sha256':hashlib.sha256(base.read_bytes()).hexdigest(),'visible_when':'P06 complete'})
manifest={'schema':1,'room_id':'R06','status':'checkpoint_1_working_art_not_full_pack','user_approved_master':False,'reference':'art/concepts/bunk-room-concept-v1.png','canvas':[1448,1086],'generated_by':'tools/build_bunk_batch.py','assets':ASSETS,'room_prop_rects_xywh':room_rects,'room_hotspots':[{'id':'belongings','rect':[989,657,441,85],'action':'open_P08_inspection'},{'id':'locker_cards','rect':[1003,299,408,343],'action':'read_ownership_cards'},{'id':'calendar','rect':[872,207,106,197],'action':'inspect_calendar'},{'id':'door','rect':[34,165,199,722],'action':'return_to_corridor'}],'solution':dict(zip(OWNERS,PROPS)),'validation_scope':'Artwork geometry and evidence layout; no gameplay validation','clue_production_details':{'BELL':'NB; two brass bands at handle joins; matches existing R05 evidence','ROOK':'V nick near far end of beam','VENN':'pale thumb-worn crescent on holder front','IVES':'broad palm patch with pale stitching'},'state_contract':{'entry':'P06; P08 can precede or follow P07','P08_reward':'bunk token half and three-cut seal rubbing; preserve rubbing','cup_retention':'keep on Bell shelf after P08 and P22; do not consume','P22_entry':'P21','P22_solution':['PERSONAL EFFECT IDENTIFIED','REPAIRED CUP','NORA BELL'],'P22_original':'No surviving personal effects.','weather':'shared puzzle milestones only; never grants object placements or rewards'},'pending':['Room composition approval','Open locker and curtain poses','Token-half graphic matching R05 paired geometry','Pillow depression and later local environmental effects','Calendar date/name state overlays','Secondary view with five already-closed staff lockers','Room door state and pencil-shelf letter props','Full measured layers/state manifest and final scene review','Gameplay, recorded audio, persistence and device testing'],'limitations':['Generated props retain original PNGs with real alpha. Very faint alpha speckles outside content are omitted by inspection viewports using measured alpha>8 bounds.','Four new habit/mark descriptions are production copy proposals consistent with P08; they do not change owner mapping.','Do not use whole-room mood swaps to grant puzzle completion.','This checkpoint does not complete the R06 graphics pack.']}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Built {len(ASSETS)} R06 PNG assets; 6 review compositions; exact labels and evidence overlays.')
