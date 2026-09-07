"""Author R04's exact graphic layers. Does not modify generated raster art."""
from pathlib import Path
from html import escape
import json
import subprocess

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
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><g stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>\n')
    subprocess.run(['inkscape', str(path), '--export-type=png', '--export-filename=' + str(path.with_suffix('.png'))], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ASSETS.append({'id': path.stem, 'path': str(path.with_suffix('.png').relative_to(ROOT)), 'source_svg': str(path.relative_to(ROOT)), 'role': role, 'visible_when': visibility})

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
document('r04_playback_transcript', 'PRESERVED PLAYBACK', 'Evidence copied after successful P02 playback', [
    'Calibration zero: 4.',
    '',
    'The final line is marked TOMORROW:',
    '',
    '"Mercer will be standing at the',
    'chart table."',
    '',
    'Ada Mercer is named on the closure',
    'contract already in the notebook.',
], visibility='P02 complete')
document('r04_maintenance_ledger', 'BENCH MAINTENANCE', 'Shelf ledger / atmospheric inspection', [
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
document('r04_witness_procedure', 'WITNESS LINE', 'Preserve live playback before addressing', [
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

# Three discrete seam orientations. Endpoint classes, not pixel tolerance,
# define equality. The first and last fixed guides both use class 0.
levels = [42, 100, 158]
band_data = {}
for name, start in [('C', 0), ('A', 1), ('B', 2)]:
    rotations = []
    for step in range(3):
        left, right = (start + step) % 3, (start + step + 1) % 3
        y1, y2 = levels[left], levels[right]
        body = line(0, y1, 180, y2, INK, 10) + line(0, y1, 180, y2, PAPER, 5)
        for x, y in [(0, y1), (180, y2)]:
            body += rect(max(0, x - 8), y - 7, 8, 14, GOLD, sw=1)
        body += rect(57, 209, 66, 44, PAPER, sw=2, rx=3) + text(90, 242, name, 30, anchor='middle')
        if name == 'C':
            body += text(13, 282, 'START', 19)
        if name == 'B':
            body += text(167, 282, 'END', 19, anchor='end')
        asset_id = f'r04_band_{name.lower()}_step_{step}'
        svg('puzzle/' + asset_id, 180, 300, body, 'exact_band_overlay', 'P02 sleeve visible')
        rotations.append({'step': step, 'left_class': left, 'right_class': right, 'asset_id': asset_id})
    band_data[name] = {'start_notch': name == 'C', 'end_notch': name == 'B', 'rotations': rotations}

guide = line(0, 42, 30, 42, PAPER, 6) + line(210, 42, 240, 42, PAPER, 6)
guide += text(30, 285, 'START', 18, PAPER, 'middle') + text(210, 285, 'END', 18, PAPER, 'middle')
svg('puzzle/r04_spindle_guides', 240, 300, guide, 'fixed_end_guides', 'P02 inspection')
for name in ['A', 'B', 'C']:
    svg('puzzle/r04_case_label_' + name.lower(), 180, 90, rect(2, 2, 176, 86, PAPER, sw=2) + text(90, 62, name, 48, anchor='middle'), 'case_label', 'R04')

# Panel overlays intentionally contain no generated text or clue geometry.
body = text(110, 142, 'SESSION SEPARATION', 38, PAPER)
body += text(110, 196, 'Align the two bell peaks with the same guide.', 28, PAPER)
for y, label in [(296, 'VENN'), (558, 'NORA')]:
    body += text(110, y, label, 27, PAPER) + rect(110, y + 29, 1228, 176, '#dfd7c2', sw=3)
    body += line(724, y + 29, 724, y + 205, '#8a6032', 4)
body += text(724, 845, 'BELL GUIDE', 24, PAPER, 'middle')
body += text(110, 947, 'Listen to each voice separately. Preserve both statements.', 27, PAPER)
svg('puzzle/r04_p17_panel_overlay', 1448, 1086, body, 'P17_inspection_overlay', 'P16 complete')

waveforms = {}
for name, peak in [('venn', 280), ('nora', 440)]:
    pts = [(20, 72)]
    for x in range(40, 942, 20):
        amp = 5 + (x * (7 if name == 'venn' else 11) % 19)
        if abs(x - peak) < 42:
            amp = 56 - abs(x - peak)
        pts.append((x, 72 + (-amp if (x // 20) % 2 == 0 else amp)))
    pts.append((940, 72))
    body = '<polyline points="' + ' '.join(f'{x},{y}' for x, y in pts) + '" fill="none" stroke="' + INK + '" stroke-width="3"/>'
    body += line(peak, 8, peak, 132, SEA, 2) + text(peak + 14, 25, 'BELL', 17)
    svg('puzzle/r04_waveform_' + name, 960, 144, body, 'authored_sync_trace', 'P17')
    waveforms[name] = {'bell_x': peak, 'width': 960, 'note': 'Authored timing diagram, not a waveform extracted from recorded voice. Match later audio to the marked event.'}

body = text(110, 140, 'LISTENING CHANNELS', 38, PAPER)
body += text(110, 194, 'Isolate live playback before addressing a witness.', 28, PAPER)
body += text(110, 280, 'MOTOR', 27, PAPER)
body += rect(600, 230, 630, 103, '#e0d5ba', sw=3)
body += text(915, 292, 'SEAL CUTS IDENTIFY THE SOCKET', 25, INK, 'middle')
for x, name, cuts in [(150, 'A', 1), (554, 'B', 2), (958, 'C', 3)]:
    body += rect(x, 398, 340, 338, '#d8c9a8', sw=3, rx=5)
    body += text(x + 170, 470, name, 48, anchor='middle')
    for i in range(cuts):
        xx = x + 170 + (i - (cuts - 1) / 2) * 25
        body += line(xx, 497, xx, 526, INK, 7)
    body += text(x + 170, 711, 'LIVE' if name != 'C' else 'WITNESS LINE', 22, INK, 'middle')
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
svg('effects/r04_lamp_pool', 1448, 1086, '<path d="M447 468 L356 630 L615 630 Z" fill="#e1b969" opacity=".16"/><ellipse cx="465" cy="570" rx="111" ry="71" fill="#ecc879" opacity=".10"/>', 'local_light_behind_props', 'task lamp lit')
svg('effects/r04_stool_damp_mark', 1448, 1086, '<path d="M496 755 C514 746 545 748 563 755 C580 756 581 764 566 769 C547 774 513 772 499 767 C488 765 489 759 496 755Z" fill="#352f2d" opacity=".29"/>', 'registered_seat_mark', 'weather >= 3; layer over dry stool; alignment requires integration review')

spec = {'schema': 1, 'generated_by': 'tools/build_listening_vectors.py', 'bands': band_data, 'solution': {'order': ['C', 'A', 'B'], 'steps': [0, 0, 0], 'start_class': 0, 'end_class': 0}, 'band_canvas': [180, 300], 'wax_skin_rect': [0, 0, 180, 200], 'seam_levels_y': levels, 'waveforms': waveforms, 'window_panes': panes, 'assets': ASSETS, 'limitations': ['Graphic specification only; no puzzle implementation or audio files.', 'Waveform diagrams must be synchronized with future voice recordings.', 'Inspect touch and overlay alignment in the engine before release.']}
(OUT / 'authored-spec.json').write_text(json.dumps(spec, indent=2) + '\n')
print(f'Authored {len(ASSETS)} SVG/PNG pairs and exact R04 graphic specification.')
