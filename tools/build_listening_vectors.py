"""Author R04's exact graphic layers. Does not modify generated raster art."""
from pathlib import Path
from html import escape
import json
import subprocess
from itertools import permutations, product

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/listening'
INK = '#172b36'
PAPER = '#e6dcc4'
GOLD = '#be9657'
SEA = '#536f70'
ASSETS = []

def text(x, y, value, size=26, color=INK, anchor='start'):
    return f'<text x="{x}" y="{y}" font-family="DejaVu Sans" font-size="{size}" fill="{color}" text-anchor="{anchor}">{escape(value)}</text>'

def rect(x, y, w, h, fill, stroke=INK, sw=2, rx=0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'

def line(x1, y1, x2, y2, color=INK, width=2):
    return f'<path d="M{x1} {y1} L{x2} {y2}" fill="none" stroke="{color}" stroke-width="{width}"/>'

def circle(x, y, r, fill, stroke=INK, sw=2):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'

def svg(name, w, h, body, role, visibility=None):
    path = OUT / (name + '.svg')
    path.parent.mkdir(parents=True, exist_ok=True)
    source = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><g stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>\n'
    # Do not rewrite unchanged exports during a metadata-only revision.
    if not path.exists() or path.read_text() != source or not path.with_suffix('.png').exists():
        path.write_text(source)
        subprocess.run(['inkscape', str(path), '--export-type=png', '--export-filename=' + str(path.with_suffix('.png'))], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ASSETS.append({'id': path.stem, 'path': str(path.with_suffix('.png').relative_to(ROOT)), 'source_svg': str(path.relative_to(ROOT)), 'size': [w, h], 'role': role, 'visible_when': visibility})

def document(name, title, subtitle, lines, visibility='R04 visited', extra=''):
    body = rect(1, 1, 798, 998, PAPER) + rect(25, 25, 750, 950, 'none', sw=1)
    body += text(62, 83, 'GREYWAKE SURVEY STATION', 23, SEA)
    body += text(62, 146, title, 34) + text(62, 190, subtitle, 22, SEA)
    body += line(62, 220, 738, 220)
    for i, value in enumerate(lines):
        body += text(62, 275 + i * 44, value, 25)
    body += extra
    svg('documents/' + name, 800, 1000, body, 'readable_document', visibility)

document('r04_recording_log', 'RECORDING LOG', 'Bench inventory / retained material', [
    'Recovered wax bands: A / B / C.',
    'Assembly separated for cleaning.',
    '',
    'Keep every edge. Do not trim the wax.',
    'Raise the needle before handling.',
    'Return each sleeve to its own case.',
    '',
    'One recording. Three surviving bands.',
    '',
    'E. Venn',
])
document('r04_correction_note', 'A SMALL REQUEST', 'Pinned beside the recording log', [
    'After playback, return both earpieces',
    'to the hook.',
    '',
    'I have twice found one warm after',
    'the mechanism had been stopped',
    'for the night.',
    '',
    'The lamp does not reach that wall.',
    '',
    'E. V.',
])
example = text(62, 650, 'SEAM EXAMPLE / unrelated practice pieces', 22, SEA)
for x, label in [(100, 'X'), (400, 'Y')]:
    example += rect(x, 690, 300, 165, '#815f49', sw=3)
    example += text(x + 150, 902, label, 28, anchor='middle')
example += line(100, 745, 400, 782, PAPER, 6) + line(400, 782, 700, 819, PAPER, 6)
example += circle(400, 782, 11, GOLD)
document('r04_assembly_card', 'REASSEMBLY', 'Wax recording bands', [
    '1. Find the band marked START.',
    '2. Fit the remaining bands toward END.',
    '3. Turn each band one notch at a time.',
    '4. Match the seam across both joins',
    '    and the two fixed end guides.',
    '5. Lower the needle and PLAY.',
    '',
    'A broken seam can always be adjusted.',
], extra=example)
document('r04_playback_transcript', 'PRESERVED PLAYBACK', 'Listening Room / preserved cylinder', [
    'ELIAS VENN',
    'Calibration zero: 4.',
    '',
    'The final line is marked TOMORROW:',
    '',
    '"Mercer will be standing at the',
    'chart table."',
    '',
    'ADA: My name was already on the',
    'closure contract.',
], visibility='P02 complete')
document('r04_maintenance_ledger', 'BENCH MAINTENANCE', 'Shelf ledger / maintenance entries', [
    'Oil the spindle. Brush the wax dust.',
    'Dry the clips before replacing paper.',
    'Count the sleeves before winding.',
    '',
    'One new brush requested.',
    'One new brush received.',
    'The old brush is still here.',
    '',
    'I have left it where it was found.',
])
document('r04_witness_procedure', 'WITNESS LINE', 'Isolate live playback before addressing', [
    'A  /  one cut',
    'B  /  two cuts',
    'C  /  three cuts',
    '',
    'Isolate live playback first:',
    'stop the motor; close A and B.',
    '',
    'Open the socket matching the seal.',
    'Press WITNESS. Keep the record open.',
], visibility='P17 complete; P19 interaction requires P17 AND P18')
document('r04_venn_statement', 'VENN / SEPARATED', 'Session recording / preserved statement', [
    'ELIAS VENN',
    '"Leave the witness line open."',
], visibility='P17 bell peaks aligned AND Venn channel heard')
document('r04_nora_statement', 'NORA / SEPARATED', 'Session recording / preserved statement', [
    'NORA BELL',
    '"Tell them I was here."',
], visibility='P17 bell peaks aligned AND Nora channel heard')
document('r04_witness_margin', 'KEEP THE RECORD OPEN', 'Venn / note in the session margin', [
    'An automatic countersign closes',
    'a record.',
    '',
    'An ongoing human correction',
    'keeps it open.',
    '',
    'The dead channel is my station now.',
    'Its socket carries the cuts of my seal.',
    '',
    'E. Venn',
], visibility='P17 complete; retain in notebook')
questions = [
    {'id': 'reach', 'question': 'Did you save them?', 'answer': [
        'I kept them within reach. I could',
        'not bring them out. I cannot promise',
        'that what remains is whole.',
    ], 'exact_answer': 'I kept them within reach. I could not bring them out. I cannot promise that what remains is whole.'},
    {'id': 'sever', 'question': 'What happens if I sever the connection?', 'answer': [
        'Their traces will end. You will be',
        'able to leave. You will not be able',
        'to reach them again.',
    ], 'exact_answer': 'Their traces will end. You will be able to leave. You will not be able to reach them again.'},
    {'id': 'remain', 'question': 'What does taking your place mean?', 'answer': [
        'You keep the witness record open,',
        'and my duty ends. The traces remain',
        'accessible.',
        '',
        '[The indicator goes dark.',
        'Venn continues.]',
        '',
        'You must remain here, physically',
        'at the station.',
    ], 'exact_answer': 'You keep the witness record open, and my duty ends. The traces remain accessible. You must remain here, physically at the station.'},
]
for q in questions:
    question_lines = {
        'reach': ['ADA: Did you save them?'],
        'sever': ['ADA: What happens if I sever', 'the connection?'],
        'remain': ['ADA: What does taking your', 'place mean?'],
    }[q['id']]
    document('r04_witness_answer_' + q['id'], 'THE WITNESS ANSWERS', 'Listening Room / preserved exchange',
             question_lines + ['', 'ELIAS VENN'] + q['answer'],
             visibility='P19 witness connected AND question ' + q['id'] + ' asked; retain after indicator dark')

# Three discrete seam orientations. Endpoint classes, not pixel tolerance,
# define equality. START/END notches constrain which band can occupy each end.
levels = [42, 100, 158]
band_data = {}
face = rect(1, 1, 178, 198, '#815f49', sw=2)
for yy in range(12, 199, 12):
    face += line(3, yy, 177, yy, '#a77a54', 1)
svg('puzzle/r04_band_face', 180, 200, face, 'authored_front_elevation_wax_face', 'P02 inspection; use beneath exact seam overlay')
for name, start in [('C', 0), ('A', 1), ('B', 2)]:
    rotations = []
    for step in range(3):
        left, right = (start + step) % 3, (start + step + 1) % 3
        y1, y2 = levels[left], levels[right]
        body = line(0, y1, 180, y2, INK, 10) + line(0, y1, 180, y2, PAPER, 5)
        # The marks end exactly on the two joining edges, with no blank inset.
        body += rect(0, y1 - 7, 8, 14, GOLD, sw=1)
        body += rect(172, y2 - 7, 8, 14, GOLD, sw=1)
        body += rect(57, 209, 66, 44, PAPER, sw=2, rx=3) + text(90, 242, name, 30, anchor='middle')
        if name == 'C':
            body += text(12, 282, 'START', 19, PAPER)
            body += '<path d="M0 205 L14 213 L0 221 Z" fill="' + PAPER + '"/>'
        if name == 'B':
            body += text(168, 282, 'END', 19, PAPER, anchor='end')
            body += '<path d="M180 205 L166 213 L180 221 Z" fill="' + PAPER + '"/>'
        asset_id = f'r04_band_{name.lower()}_step_{step}'
        svg('puzzle/' + asset_id, 180, 300, body, 'exact_band_overlay', 'P02 sleeve visible')
        rotations.append({'step': step, 'left_class': left, 'right_class': right, 'asset_id': asset_id})
    band_data[name] = {'start_notch': name == 'C', 'end_notch': name == 'B', 'rotations': rotations}

# Guides surround ALL THREE bands, not a single band. Place bands at 30,210,390.
guide = line(0, 42, 30, 42, PAPER, 6) + line(570, 42, 600, 42, PAPER, 6)
guide += line(18, 24, 18, 62, GOLD, 4) + line(582, 24, 582, 62, GOLD, 4)
svg('puzzle/r04_spindle_guides', 600, 300, guide, 'fixed_end_guides', 'P02 inspection')
for name in ['A', 'B', 'C']:
    svg('puzzle/r04_case_label_' + name.lower(), 180, 90, rect(2, 2, 176, 86, PAPER, sw=2) + text(90, 62, name, 48, anchor='middle'), 'case_label', 'R04')

def button(name, label, width=260, height=100, state='idle', role='control', visibility=None):
    fill = GOLD if state == 'pressed' else PAPER
    body = rect(3, 3, width-6, height-6, fill, sw=3, rx=6)
    body += text(width/2, height/2+10, label, 28, anchor='middle')
    svg('puzzle/' + name, width, height, body, role, visibility)

body = text(110, 142, "TOMORROW\'S RECORDING", 38, PAPER)
body += text(110, 196, 'Fit START to END. Match the seam at both joins and guides.', 27, PAPER)
body += text(110, 242, 'Select a band, then a slot. Turn the fitted band one notch at a time.', 25, PAPER)
body += text(88, 322, 'BANDS', 22, PAPER)
for xx in [292, 580, 868]:
    body += rect(xx, 290, 288, 320, '#3a3630', PAPER, 2)
body += text(724, 266, 'CYLINDER SPINDLE', 23, PAPER, 'middle')
svg('puzzle/r04_p02_panel_overlay', 1448, 1086, body, 'P02_inspection_overlay', 'P01 complete')
button('r04_rotate_band', 'TURN BAND', 268, 96, role='discrete_rotation_control', visibility='P02')
for state in ['raised', 'lowered']:
    button('r04_needle_' + state, 'NEEDLE ' + ('UP' if state == 'raised' else 'DOWN'), 350, 96, role='needle_control', visibility='P02')
button('r04_play_key', 'PLAY', 350, 96, role='playback_control', visibility='P02')
body = rect(2, 2, 1076, 596, PAPER, sw=3, rx=6)
body += text(56, 76, 'PRESERVED CYLINDER / ELIAS VENN', 29)
body += text(56, 142, 'CALIBRATION ZERO', 27, SEA)
body += rect(836, 105, 174, 128, '#f1e8d3', sw=3)
body += text(923, 200, '4', 88, anchor='middle')
body += rect(56, 180, 720, 120, '#f1e8d3', sw=2)
trace_points = [(76, 240)]
for x in range(96, 755, 20):
    amplitude = 7 + ((x * 11) % 28)
    trace_points.append((x, 240 + amplitude * (-1 if (x // 20) % 2 else 1)))
body += '<polyline points="' + ' '.join(f'{x},{y}' for x,y in trace_points) + '" fill="none" stroke="' + INK + '" stroke-width="3"/>'
body += text(56, 362, 'TOMORROW', 31, SEA)
body += text(56, 424, '"Mercer will be standing at the chart table."', 34)
body += line(56, 474, 1010, 474)
body += text(56, 539, 'Playback and transcript remain in the notebook.', 26)
svg('puzzle/r04_p02_playback_readout', 1080, 600, body, 'P02_exact_playback_readout', 'P02 successful playback only')

# Panel overlays intentionally contain no generated text or clue geometry.
body = text(110, 142, 'SESSION SEPARATION', 38, PAPER)
body += text(110, 196, 'Align the two bell peaks with the same guide.', 28, PAPER)
for y, label in [(280, 'VENN'), (550, 'NORA')]:
    body += text(144, y + (15 if label == 'NORA' else 0), label, 27, PAPER) + rect(144, y + 32, 1160, 144, '#dfd7c2', sw=3)
    body += line(724, y + 32, 724, y + 176, '#8a6032', 4)
body += text(724, 852, 'BELL GUIDE', 24, PAPER, 'middle')
body += text(110, 925, 'Listen to each voice separately.', 28, PAPER)
body += text(110, 972, 'Both statements remain in the notebook.', 27, PAPER)
svg('puzzle/r04_p17_panel_overlay', 1448, 1086, body, 'P17_inspection_overlay', 'P16 complete')
for direction, label in [('left', '<'), ('right', '>')]:
    button('r04_trace_' + direction, label, 104, 72, role='discrete_trace_shift', visibility='P17')
for speaker in ['venn', 'nora']:
    for state in ['idle', 'pressed']:
        button('r04_listen_' + speaker + '_' + state, 'LISTEN: ' + speaker.upper(), 400, 72, state=state, role='single_voice_control', visibility='P17')

waveforms = {}
for name, peak in [('venn', 280), ('nora', 440)]:
    pts = [(20, 72)]
    for x in range(40, 941, 20):
        amp = 5 + (x * (7 if name == 'venn' else 11) % 19)
        if abs(x - peak) < 42:
            amp = 56 - abs(x - peak)
        pts.append((x, 72 + (-amp if (x // 20) % 2 == 0 else amp)))
    body = '<polyline points="' + ' '.join(f'{x},{y}' for x, y in pts) + '" fill="none" stroke="' + INK + '" stroke-width="3"/>'
    body += line(peak, 8, peak, 132, SEA, 2) + text(peak + 14, 25, 'BELL', 17)
    svg('puzzle/r04_waveform_' + name, 960, 144, body, 'authored_sync_trace', 'P17')
    waveforms[name] = {'bell_x': peak, 'width': 960, 'height': 144,
                      'initial_origin': [144, 312 if name == 'venn' else 582],
                      'clip_rect': [144, 312 if name == 'venn' else 582, 1160, 144],
                      'solution_shift_x': 724 - 144 - peak,
                      'polyline_points': pts,
                      'note': 'Authored timing diagram, not a waveform extracted from recorded voice. Match later audio to the marked event.'}

body = text(110, 140, 'LISTENING CHANNELS', 38, PAPER)
body += text(110, 194, 'Isolate live playback before addressing a witness.', 28, PAPER)
body += text(144, 230, 'MOTOR', 25, PAPER)
body += rect(600, 240, 700, 100, '#e0d5ba', sw=3)
body += text(950, 302, 'SEAL CUTS IDENTIFY THE SOCKET', 25, INK, 'middle')
for x, name, cuts in [(150, 'A', 1), (554, 'B', 2), (958, 'C', 3)]:
    body += rect(x, 398, 340, 338, '#d8c9a8', sw=3, rx=5)
    body += text(x + 170, 470, name, 48, anchor='middle')
    for i in range(cuts):
        xx = x + 170 + (i - (cuts - 1) / 2) * 25
        body += line(xx, 497, xx, 526, INK, 7)
    body += text(x + 170, 711, 'LIVE' if name != 'C' else 'WITNESS LINE', 22, INK, 'middle')
body += text(1012, 821, 'CIRCUIT', 22, PAPER, 'middle')
body += text(724, 1010, 'The indicator records the circuit, not the speaker.', 24, PAPER, 'middle')
svg('puzzle/r04_p19_panel_overlay', 1448, 1086, body, 'P19_inspection_overlay', 'P17 AND P18 complete')
for state, fill in [('open', '#9dab91'), ('closed', '#c4b597')]:
    b = rect(3, 3, 254, 94, fill, sw=3, rx=5) + text(130, 64, state.upper(), 28, anchor='middle')
    svg('puzzle/r04_channel_' + state, 260, 100, b, 'shared_channel_control', 'P19')
for state in ['off', 'on']:
    b = rect(3, 3, 254, 94, '#c4b597' if state == 'off' else '#9dab91', sw=3, rx=5) + text(130, 64, state.upper(), 28, anchor='middle')
    svg('puzzle/r04_motor_' + state, 260, 100, b, 'motor_control', 'P19')
for state, fill in [('idle', '#b48c50'), ('pressed', '#82663e')]:
    b = rect(3, 3, 398, 104, fill, stroke=PAPER, sw=3, rx=5) + text(202, 68, 'WITNESS', 32, PAPER, 'middle')
    svg('puzzle/r04_witness_key_' + state, 404, 110, b, 'witness_control', 'P19')
for state, fill in [('off', '#303f41'), ('on', '#e4c271')]:
    svg('puzzle/r04_indicator_' + state, 64, 64, circle(32, 32, 26, fill, PAPER, 3), 'circuit_indicator', 'P19')
body = text(110, 142, 'THE WITNESS LINE', 38, PAPER)
body += text(110, 196, 'Three questions. Keep every answer.', 28, PAPER)
body += text(110, 935, 'Completed answers can be replayed from the notebook.', 27, PAPER)
svg('puzzle/r04_p19_questions_overlay', 1448, 1086, body, 'P19_question_selection_overlay', 'P19 witness connected')
for q in questions:
    button('r04_question_' + q['id'], q['question'], 1208, 140, role='fixed_question', visibility='P19 witness connected')

# Native graphic atmosphere: fixed coordinates; no raster image processing.
panes = [(1112,137,81,112),(1205,137,83,112),(1302,137,78,112),(1112,261,81,94),(1205,261,83,94),(1302,261,78,94),(1112,372,268,207)]
defs = '<defs><clipPath id="panes">' + ''.join(rect(*r, '#fff', sw=0) for r in panes) + '</clipPath></defs>'
for frame in range(3):
    body = ''
    for k in range(43):
        x = 1110 + (k * 71 % 284)
        y = 127 + ((k * 83 + frame * 27) % 467)
        body += f'<path d="M{x} {y} l-7 23" stroke="#d2dfe0" stroke-opacity=".27" stroke-width="1.6"/>'
    svg('effects/r04_rain_' + str(frame), 1448, 1086, defs + '<g clip-path="url(#panes)">' + body + '</g>', 'window_rain_frame', 'weather 2–7; freeze frame 0 at weather 4; no motion in reduced-motion mode')
svg('effects/r04_window_mask', 1448, 1086, ''.join(rect(*r, '#ffffff', sw=0) for r in panes), 'window_alpha_mask')
svg('effects/r04_wall_damp', 1448, 1086, '<path d="M1115 641 C1162 637 1202 651 1265 642 L1251 728 L1239 696 L1228 801 L1213 706 L1192 757 L1176 687 L1152 731 L1142 675 L1115 679 Z" fill="#314e50" opacity=".22"/>', 'local_damp_layer', 'weather >= 3')
svg('effects/r04_lamp_pool', 1448, 1086, '<path d="M452 488 L356 634 L615 634 Z" fill="#e1b969" opacity=".10"/><ellipse cx="465" cy="570" rx="111" ry="71" fill="#ecc879" opacity=".10"/>', 'local_light_behind_props', 'task lamp lit')
svg('effects/r04_stool_damp_mark', 1448, 1086, '<path d="M496 755 C514 746 545 748 563 755 C580 756 581 764 566 769 C547 774 513 772 499 767 C488 765 489 759 496 755Z" fill="#352f2d" opacity=".29"/>', 'registered_seat_mark', 'weather >= 3; layer over dry stool; alignment requires integration review')

# Machine-readable composition and graphic contract. These rules describe
# required implementation behavior; this script does not implement gameplay.
p02 = {
    'canvas': [1448, 1086],
    'panel_background': 'r04_channel_panel_blank',
    'overlay': 'r04_p02_panel_overlay',
    'assembly_rect': [244, 290, 960, 480],
    'assembly_source_size': [600, 300],
    'assembly_uniform_scale': 1.6,
    'band_local_origins': [[30, 0], [210, 0], [390, 0]],
    'band_face_asset': 'r04_band_face',
    'band_face_rect': [0, 0, 180, 200],
    'band_overlay_rect': [0, 0, 180, 300],
    'band_selection_controls': [
        {'band': name, 'asset_id': 'r04_case_label_' + name.lower(), 'rect': [88, 346 + i*102, 144, 72],
         'accessible_label': 'Select recording band ' + name}
        for i,name in enumerate(['A','B','C'])
    ],
    'guides_asset': 'r04_spindle_guides',
    'guides_rect': [0, 0, 600, 300],
    'rotate_controls': [
        {'slot': i, 'asset_id': 'r04_rotate_band', 'rect': [302 + i*288, 795, 268, 96]}
        for i in range(3)
    ],
    'needle_control': {'rect': [150, 925, 350, 96], 'states': {'raised': 'r04_needle_raised', 'lowered': 'r04_needle_lowered'}},
    'play_control': {'rect': [948, 925, 350, 96], 'asset_id': 'r04_play_key'},
    'successful_playback': {
        'asset_id': 'r04_p02_playback_readout', 'rect': [184, 243, 1080, 600],
        'transcript_asset': 'r04_playback_transcript',
        'speaker': 'Elias Venn', 'calibration_zero': 4,
        'future_label': 'TOMORROW',
        'future_line': 'Mercer will be standing at the chart table.',
        'trace_note': 'Authored illustrative trace accompanying explicit numerical and text readouts. Not extracted from audio and not an amplitude decoding task.',
        'visibility': 'Only after valid assembly is successfully played; retained as evidence thereafter.',
    },
    'interaction': ['Tap a band then a slot; dragging is optional.',
                    'START notch belongs in first slot; END notch belongs in last slot.',
                    'TURN BAND advances selected slot one notch through steps 0,1,2.',
                    'The seam must match at both joins and both fixed guides.',
                    'Needle starts raised. Raise it before moving bands; a failed action consumes nothing.',
                    'Lower needle, then PLAY to evaluate complete assembly.',
                    'Failed seam checks mark each broken join and retain arrangement.',
                    'Successful playback awards zero 4 and preserves transcript, independently of animation.'],
    'initial_state': {'slots': [None, None, None], 'needle': 'raised', 'completed': False},
    'room_art_note': 'Generated recorder_assembled/partial and wax_band sprites are visual room props. Exact inspection uses the authored band face; do not stretch an angled generated cylinder under this seam geometry.',
}
p17 = {
    'canvas': [1448, 1086],
    'panel_background': 'r04_channel_panel_blank',
    'overlay': 'r04_p17_panel_overlay',
    'requires': ['P16'],
    'guide_x': 724,
    'shift_step_x': 20,
    'shift_range_x': [0, 400],
    'initial_shift_x': {'venn': 0, 'nora': 0},
    'controls': {
        speaker: {
            'left': {'asset_id': 'r04_trace_left', 'rect': [144, yy, 104, 72]},
            'right': {'asset_id': 'r04_trace_right', 'rect': [264, yy, 104, 72]},
            'listen': {'rect': [904, yy, 400, 72], 'states': {'idle': 'r04_listen_'+speaker+'_idle', 'pressed': 'r04_listen_'+speaker+'_pressed'}},
        } for speaker, yy in [('venn', 470), ('nora', 740)]
    },
    'voice_lines': {'venn': 'Leave the witness line open.', 'nora': 'Tell them I was here.'},
    'evidence_assets': {'venn': 'r04_venn_statement', 'nora': 'r04_nora_statement'},
    'completion': 'Both bell positions equal guide_x AND each separate voice has been heard or read through its accessible transcript action.',
    'persistent_outputs': ['r04_venn_statement', 'r04_nora_statement', 'r04_witness_procedure', 'r04_witness_margin'],
    'audio_contract': 'Separate authored speakers; exclusive channel playback. No audio file is delivered here. Caption/transcript access grants the same evidence as listening, with no hearing requirement.',
    'layer_order': ['panel_background', 'overlay', 'each clipped trace at initial_origin + shift_x', 'controls'],
}
p19 = {
    'canvas': [1448, 1086],
    'panel_background': 'r04_channel_panel_blank',
    'overlay': 'r04_p19_panel_overlay',
    'requires': ['P17', 'P18'],
    'seal_evidence_source': 'P08 retained seal rubbing; three cuts',
    'channel_cuts': {'A': 1, 'B': 2, 'C': 3},
    'controls': {
        'motor': {'rect': [144, 240, 260, 100], 'states': {'off': 'r04_motor_off', 'on': 'r04_motor_on'}},
        'A': {'rect': [190, 562, 260, 100], 'states': {'open': 'r04_channel_open', 'closed': 'r04_channel_closed'}},
        'B': {'rect': [594, 562, 260, 100], 'states': {'open': 'r04_channel_open', 'closed': 'r04_channel_closed'}},
        'C': {'rect': [998, 562, 260, 100], 'states': {'open': 'r04_channel_open', 'closed': 'r04_channel_closed'}},
        'witness': {'rect': [522, 827, 404, 110], 'states': {'idle': 'r04_witness_key_idle', 'pressed': 'r04_witness_key_pressed'}},
    },
    'indicator': {'rect': [980, 850, 64, 64], 'states': {'off': 'r04_indicator_off', 'on': 'r04_indicator_on'}},
    'initial_state': {'motor': 'on', 'A': 'open', 'B': 'open', 'C': 'closed', 'connected': False},
    'connection_rule': {'motor': 'off', 'A': 'closed', 'B': 'closed', 'C': 'open', 'witness_key': 'pressed'},
    'questions_overlay': 'r04_p19_questions_overlay',
    'questions': [dict(q, asset_id='r04_question_'+q['id'], rect=[120, 290 + j*190, 1208, 140],
                       evidence_asset='r04_witness_answer_'+q['id'],
                       first_play_requires_answer_ids=[earlier['id'] for earlier in questions[:j]]) for j,q in enumerate(questions)],
    'question_order': ['reach', 'sever', 'remain'],
    'question_availability': 'Reveal the next question after preserving the preceding answer. Completed answers are always replayable. This guarantees the indicator-dark cue accompanies the final answer.',
    'completion': 'All three fixed answers are preserved, not merely pressing WITNESS.',
    'indicator_dark_event': {
        'answer_id': 'remain',
        'cue_before_text': 'You must remain here, physically at the station.',
        'on_cue': 'Change circuit indicator to off; keep headphones voice and captions continuing.',
        'circuit_state_does_not_cancel_answer': True,
        'interruption_behavior': 'Preserve the whole answer as evidence and allow replay; no reward depends on an animation callback.',
    },
    'voice_delivery': 'Headphones and hornless recorder. Do not restore rejected funnels or use real device microphone data.',
    'copy_status': 'The three fixed exchanges are newly authored wording of established GDD consequences.',
}

# Bounded integrity checks catch incorrect art geometry and ambiguous clue rules.
valid_p02 = []
for order in permutations('ABC'):
    for steps in product(range(3), repeat=3):
        edges = [band_data[b]['rotations'][r] for b,r in zip(order,steps)]
        start_ok = band_data[order[0]]['start_notch']
        end_ok = band_data[order[-1]]['end_notch']
        joins_ok = all(edges[i]['right_class'] == edges[i+1]['left_class'] for i in range(2))
        guides_ok = edges[0]['left_class'] == 0 and edges[-1]['right_class'] == 0
        if start_ok and end_ok and joins_ok and guides_ok:
            valid_p02.append({'order': list(order), 'steps': list(steps)})
assert valid_p02 == [{'order': ['C', 'A', 'B'], 'steps': [0,0,0]}], valid_p02
assert p02['band_local_origins'][0][0] == 30
assert p02['band_local_origins'][-1][0] + 180 == 570
assert all(p02['band_local_origins'][i][0]+180 == p02['band_local_origins'][i+1][0] for i in range(2))
valid_p17 = [(a,b) for a,b in product(range(0,401,20), repeat=2)
             if 144+waveforms['venn']['bell_x']+a == 724 and 144+waveforms['nora']['bell_x']+b == 724]
assert valid_p17 == [(300,140)]
for trace in waveforms.values():
    extremal = max(trace['polyline_points'], key=lambda p: abs(p[1]-72))
    assert extremal[0] == trace['bell_x'] and abs(extremal[1]-72) == 56
assert waveforms['venn']['polyline_points'] != waveforms['nora']['polyline_points']
valid_p19 = [(motor,a,b,c,key) for motor,a,b,c,key in product([False,True],repeat=5)
             if not motor and not a and not b and c and key]
assert valid_p19 == [(False,False,False,True,True)]
asset_ids = {a['id'] for a in ASSETS}
for asset in ASSETS:
    assert (ROOT/asset['path']).is_file() and (ROOT/asset['source_svg']).is_file()
for control in [*p02['band_selection_controls'], *p02['rotate_controls'], p02['needle_control'], p02['play_control'],
                *[v for speaker in p17['controls'].values() for v in speaker.values()],
                *p19['controls'].values(), *p19['questions']]:
    x,y,w,h = control['rect']
    assert 0 <= x < x+w <= 1448 and 0 <= y < y+h <= 1086
    assert min(w,h)*1024/1448 >= 44, control
    for aid in ([control['asset_id']] if 'asset_id' in control else control['states'].values()):
        assert aid in asset_ids, aid

spec = {
    'schema': 2, 'generated_by': 'tools/build_listening_vectors.py',
    'bands': band_data,
    'solution': {'order': ['C','A','B'], 'steps': [0,0,0], 'start_class': 0, 'end_class': 0},
    'band_canvas': [180,300], 'wax_skin_rect': [0,0,180,200], 'seam_levels_y': levels,
    'waveforms': waveforms, 'window_panes': panes,
    'panels': {'P02': p02, 'P17': p17, 'P19': p19},
    'validation': {'P02_enumerated_arrangements': 162, 'P02_valid_arrangements': valid_p02,
                   'P17_enumerated_shift_pairs': 441, 'P17_valid_shift_pairs': valid_p17,
                   'P19_enumerated_control_states': 32, 'P19_valid_control_states': valid_p19,
                   'touch_target_reference_size': [1024,768], 'minimum_control_target': 44,
                   'checks': ['P02 three-band guide span and touching band joins', 'Unique solution includes START/END notch constraints',
                              'Both P17 bell peaks are uniquely largest and align on discrete steps',
                              'P17 traces and speaker statements remain distinct', 'P19 only OFF/closed/closed/open/WITNESS connects',
                              'Referenced controls exist and fit canvas with >=44px minimum at reference size']},
    'assets': ASSETS,
    'limitations': ['Graphic specification only; no puzzle implementation or audio files.',
                    'Waveform diagrams must be synchronized with future voice recordings.',
                    'Inspect touch and overlay alignment in the engine before release.',
                    'Graphic enumeration validates authored rules, not unimplemented game code.'],
}
(OUT / 'authored-spec.json').write_text(json.dumps(spec, indent=2) + '\n')
print(f'Authored {len(ASSETS)} SVG/PNG pairs. P02: 1/162; P17: 1/441; P19: 1/32 valid configurations.')
