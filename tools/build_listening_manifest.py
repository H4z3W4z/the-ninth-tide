#!/usr/bin/env python3
"""Inspect unchanged R04 art and emit deterministic composition/inventory data.

Pillow is used read-only for dimensions and alpha statistics. This program never
resizes, crops, composites, rewrites or otherwise edits source raster images.
Run after build_listening_vectors.py and before tools/build_manifest.py.
"""
from collections import Counter
from hashlib import sha256
from pathlib import Path
import json

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'assets/listening'
CANVAS = [1448, 1086]
FULL = [0, 0, *CANVAS]
GENERATED = json.loads((ROOT / 'docs/listening-pack-generation.json').read_text())
SPEC = json.loads((PACK / 'authored-spec.json').read_text())
PROVENANCE = {item['id']: item for item in GENERATED['assets'] if item['kind'] != 'draft'}
AUTHORED = {item['id']: item for item in SPEC['assets']}


def rect_from_bbox(bbox):
    if bbox is None:
        return None
    x1, y1, x2, y2 = bbox
    return [x1, y1, x2 - x1, y2 - y1]


def inspect(path):
    with Image.open(path) as im:
        im.load()
        w, h = im.size
        alpha = im.getchannel('A') if 'A' in im.getbands() else None
        exact = list(alpha.getbbox()) if alpha and alpha.getbbox() else [0, 0, w, h]
        visible = list(alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()) if alpha else [0, 0, w, h]
        alpha_range = list(alpha.getextrema()) if alpha else [255, 255]
        hist = alpha.histogram() if alpha else [0] * 255 + [w * h]
        item = {
            'path': str(path.relative_to(ROOT)), 'width': w, 'height': h,
            'mode': im.mode, 'sha256': sha256(path.read_bytes()).hexdigest(),
            'alpha_range': alpha_range, 'alpha_bbox_ltrb': exact,
            'visible_bbox_ltrb': visible,
            'transparent_pixel_fraction': round(hist[0] / (w * h), 6),
            'low_alpha_pixel_fraction': round(sum(hist[1:16]) / (w * h), 6),
            'render_region_px': rect_from_bbox(visible),
        }
    source = path.with_suffix('.svg')
    if source.exists():
        item['source_svg'] = str(source.relative_to(ROOT))
        item['source_svg_sha256'] = sha256(source.read_bytes()).hexdigest()
        item['render_region_px'] = [0, 0, w, h]
        item['class'] = 'authored_graphic'
        item['role'] = AUTHORED.get(path.stem, {}).get('role', 'authored_graphic')
        item['visibility_note'] = AUTHORED.get(path.stem, {}).get('visible_when')
    else:
        item['class'] = 'generated_illustration'
        item['role'] = PROVENANCE.get(path.stem, {}).get('kind', 'new_generated_illustration')
    if path.parent.name in ('backgrounds',) or path.stem in ('r04_channel_panel_blank', 'r04_workers_photo', 'r04_noticeboard_panel'):
        item['render_region_px'] = [0, 0, w, h]
    item['integrity_status'] = 'file_and_alpha_measured'
    item['runtime_integration_status'] = 'not_implemented'
    if path.stem in ('r04_recorder_partial', 'r04_recorder_assembled', 'r04_stool_damp'):
        item['runtime_use'] = 'pose_reference_only'
        item['notes'] = ['Generated silhouette drift. Use fixed empty recorder plus bands, or dry stool plus damp overlay, for persistent room state.']
    elif path.stem.startswith('r04_weather_'):
        item['runtime_use'] = 'window_source_and_full_room_review'
        item['notes'] = ['Clip the seven glazing panes only over the fixed clean base. Full image contains a partial recorder unrelated to current puzzle flags.']
    elif path.stem == 'r04_door_open_plate':
        item['runtime_use'] = 'portal_source_only'
    elif path.stem == 'r04_noticeboard_panel':
        item['runtime_use'] = 'layered_prop'
        item['notes'] = ['Alpha is 200-250 throughout. Use the opaque brown backing layer.']
    else:
        item['runtime_use'] = 'layered_art_candidate'
    return item


assets = {path.stem: inspect(path) for path in sorted(PACK.rglob('*.png'))}
# SVG and PNG exports use full authored canvases. Generated cutouts use the
# alpha>=16 rectangle as a placement crop, preserving original files unchanged.
layers = []


def image_layer(ident, asset_id, z, target, when=None, **extra):
    region = assets[asset_id]['render_region_px'] if asset_id in assets else FULL
    item = {'id': ident, 'kind': 'image', 'asset_id': asset_id, 'z': z,
            'source_region_px': region, 'target_rect': target, 'fit': 'stretch',
            'when': when or {}}
    item.update(extra)
    layers.append(item)
    return item


def rect_layer(ident, z, target, fill, when=None):
    layers.append({'id': ident, 'kind': 'rect', 'z': z, 'target_rect': target, 'fill': fill, 'when': when or {}})


def path_layer(ident, z, data, stroke, width=2, fill='none', when=None):
    layers.append({'id': ident, 'kind': 'path', 'z': z, 'svg_path': data,
                   'stroke': stroke, 'stroke_width': width, 'fill': fill,
                   'when': when or {}})


image_layer('fixed_room', 'r04_clean_base', 0, FULL)
image_layer('window_exterior', '@weather', 10, FULL, clip_rects=SPEC['window_panes'])
image_layer('door_portal', 'r04_door_open_plate', 12, FULL, {'door_open': True}, clip_rects=[[52, 160, 223, 733]])
image_layer('rain', '@rain', 13, FULL, {'weather_min': 2, 'weather_max': 7}, clip_rects=SPEC['window_panes'])
image_layer('wall_damp', 'r04_wall_damp', 15, FULL, {'weather_min': 3})
for stage, opacity in [(3, .08), (4, .12), (5, .18), (6, .23), (7, .29), (8, .34)]:
    rect_layer('room_tint_' + str(stage), 16, FULL, '#10232f', {'weather_min': stage, 'weather_max': stage})
    layers[-1]['opacity'] = opacity
image_layer('lamp_pool', 'r04_lamp_pool', 20, FULL, {'lamp_on': True})
rect_layer('noticeboard_backing', 30, [541, 173, 355, 237], '#785436')
image_layer('noticeboard', 'r04_noticeboard_panel', 31, [541, 173, 355, 237])
image_layer('recording_log_pinned', 'r04_recording_log', 32, [579, 211, 165, 156])
image_layer('correction_note_pinned', 'r04_correction_note', 33, [727, 217, 66, 83])
image_layer('workers_photo_pinned', 'r04_workers_photo', 34, [772, 302, 97, 73])
# Tiny unlettered prior-paper mark is an explicit native primitive, no extra clue.
rect_layer('old_paper_mark', 32, [812, 212, 48, 75], '#a9825c')
path_layer('headphone_hook', 35, 'M480 223 L480 212 C480 202 492 203 490 212 L485 218', '#172b36', 7)
path_layer('headphone_hook_brass', 36, 'M480 223 L480 212 C480 202 492 203 490 212 L485 218', '#b99254', 3)
image_layer('headphones', 'r04_headphones_hanging', 37, [437, 214, 143, 180])
path_layer('headphone_cord', 38, 'M579 393 C571 445 548 490 584 534', '#18272c', 3)
image_layer('lamp_off', 'r04_lamp_off', 41, [336, 414, 157, 220], {'lamp_on': False})
# Root may deliver either a new full pose or a registered shade overlay. Prefer
# exact shade overlay when present, without treating a missing file as complete.
lamp_on = next((ident for ident in ('r04_lamp_lit_overlay', 'r04_lamp_shade_on', 'r04_lamp_on') if ident in assets), None)
if lamp_on:
    if 'overlay' in lamp_on or 'shade' in lamp_on:
        image_layer('lamp_on_base', 'r04_lamp_off', 41, [336, 414, 157, 220], {'lamp_on': True})
        image_layer('lamp_illuminated_shade', lamp_on, 42, [336, 414, 157, 220], {'lamp_on': True}, placement_note='Shade artwork must share the off sprite source canvas; composition QA verifies registration.')
    else:
        image_layer('lamp_on', lamp_on, 41, [336, 414, 157, 220], {'lamp_on': True}, placement_note='Generated swap pose; no pixel registration claim.')
else:
    image_layer('lamp_on_pending', 'r04_lamp_off', 41, [336, 414, 157, 220], {'lamp_on': True}, placement_note='Temporary off silhouette with light pool. Lit shade asset still required.')

for name, x, y, w, h in [('A', 394, 561, 39, 59), ('B', 432, 552, 41, 66), ('C', 475, 558, 43, 63)]:
    image_layer('canister_' + name.lower(), 'r04_canister_closed', 42, [x, y, w, h])
    image_layer('canister_label_' + name.lower(), 'r04_case_label_' + name.lower(), 43, [x + 6, y + int(h * .60), w - 12, 15])
image_layer('brush_and_shavings', 'r04_brush_shavings', 44, [428, 607, 208, 36])
image_layer('recorder_mechanism', 'r04_recorder_empty', 45, [544, 465, 320, 164])
# Room-scale bands deliberately omit tiny inspection labels. The exact colored
# seam/labels in the 3-slot close-up are authoritative evidence.
room_slots = [[632, 522, 36, 26], [668, 522, 36, 26], [704, 522, 36, 26]]
for slot, target in enumerate(room_slots):
    image_layer('recorder_band_slot_' + str(slot), 'r04_wax_band', 46, target, {'recorder_slot': slot})
image_layer('case_closed', 'r04_case_closed', 47, [845, 597, 98, 33], {'case_open': False})
image_layer('case_open', 'r04_case_open', 47, [845, 537, 98, 93], {'case_open': True})
image_layer('loose_band_in_case', 'r04_wax_band', 48, [876, 581, 42, 29], {'case_open': True, 'case_contains_band': True})
image_layer('instruction_stand', 'r04_instruction_stand', 47, [941, 504, 97, 125])
image_layer('instruction_card', 'r04_assembly_card', 48, [952, 520, 73, 91])
image_layer('upper_shelf_case', 'r04_shelf_cylinder', 49, [863, 690, 158, 46])
image_layer('middle_shelf_case', 'r04_shelf_cylinder', 49, [864, 768, 158, 45])
image_layer('shelf_ledgers', 'r04_ledger_stack', 49, [864, 835, 154, 43])
image_layer('top_drawer_open', 'r04_drawer_open', 50, [345, 665, 197, 67], {'drawer_open': True})
image_layer('stool', 'r04_stool_dry', 60, [459, 737, 170, 249])
image_layer('stool_damp_mark', 'r04_stool_damp_mark', 61, FULL, {'weather_min': 3})

weather_rows = [
    (1, 'Arrival / Tide I', [], 'overcast', 'Ordinary sea and a visible lighthouse.', 'off'),
    (2, 'Tide II complete', ['P06'], 'rain', 'Low cloud and rain on glass.', 'cycle'),
    (3, 'Tide III complete', ['P09'], 'storm', 'Dark sea, heavy rain and local damp.', 'cycle'),
    (4, 'Tide IV complete', ['P12'], 'suspended', 'Freeze glass rain while wave timing disagrees.', 'freeze_0'),
    (5, 'Tide V complete', ['P15'], 'upright', 'Compressed horizon and upright sea.', 'cycle'),
    (6, 'Tide VI complete', ['P17', 'P18'], 'silent', 'Rain remains visible after exterior weather sound falls away.', 'cycle'),
    (7, 'Tide VII complete', ['P21'], 'bearing', 'Lighthouse at an impossible bearing; darkness close to glass.', 'cycle'),
    (8, 'Tide VIII complete / Tide IX', ['P24'], 'surface', 'Near-featureless dark surface at the window.', 'off'),
]
weather_states = []
for stage, tide, completed, suffix, description, motion in weather_rows:
    weather_states.append({'stage': stage, 'name': tide, 'all_completed': completed,
        'asset_id': f'r04_weather_{stage:02d}_{suffix}', 'description': description,
        'rain_mode': motion, 'reduced_motion_rain_mode': 'off' if motion == 'off' else 'freeze_0',
        'wall_damp': stage >= 3, 'stool_damp': stage >= 3,
        'exterior_audio': 'silence' if stage >= 6 else 'future_audio_required',
        'selection': 'Choose highest stage whose all_completed flags are true.'})


def hotspot(ident, rect, label, inspection, evidence=None, requires=None, **extra):
    return dict(id=ident, rect=rect, label=label, inspection_id=inspection,
                evidence_ids=evidence or [], requires_all=requires or ['P01'],
                minimum_touch_target_css_px=44, persist_observed_evidence=True, **extra)


hotspots = [
    hotspot('door', [44, 158, 236, 738], 'Return to Intake Office', None, action='navigate_R02'),
    hotspot('recording_log', [577, 209, 170, 160], 'Read recording log', 'recording_log', ['r04_recording_log']),
    hotspot('correction_note', [722, 212, 77, 94], 'Read pinned note', 'correction_note', ['r04_correction_note']),
    hotspot('workers_photo', [767, 296, 108, 85], 'Inspect photograph', 'workers_photo', ['r04_workers_photo']),
    hotspot('headphones', [430, 205, 109, 134], 'Inspect headphones and playback', 'recorder', ['r04_playback_transcript']),
    hotspot('lamp', [332, 411, 163, 223], 'Inspect task lamp', 'lamp', action='atmospheric_inspection'),
    hotspot('canisters', [386, 545, 139, 81], 'Inspect recording cases', 'recording_cases', action='inspect_each_case_with_tap_buttons'),
    hotspot('recorder', [540, 459, 329, 174], 'Inspect wax recorder', 'recorder', ['r04_assembly_card', 'r04_playback_transcript']),
    hotspot('brush', [427, 606, 126, 39], 'Inspect cleaning brush', 'brush', action='atmospheric_inspection'),
    hotspot('wooden_case', [840, 531, 107, 104], 'Open cylinder case', 'wooden_case', action='toggle_case_open'),
    hotspot('assembly_card', [939, 501, 102, 132], 'Read assembly instructions', 'assembly_card', ['r04_assembly_card']),
    hotspot('top_drawer', [343, 661, 201, 76], 'Inspect shallow drawer', 'drawer', action='toggle_drawer_open'),
    hotspot('shelf_cases', [857, 683, 171, 138], 'Inspect stored cylinders', 'shelf_cases', action='atmospheric_inspection'),
    hotspot('shelf_ledger', [860, 830, 164, 55], 'Read maintenance ledger', 'maintenance_ledger', ['r04_maintenance_ledger']),
    hotspot('stool', [455, 735, 177, 255], 'Inspect the worn stool', 'stool', action='preserve_observed_damp_state'),
    hotspot('weather_window', [1106, 132, 282, 453], 'Observe the sea', 'window', action='preserve_current_weather_observation'),
]
# Later controls live in the recorder inspection, not a newly invented wall prop.
inspections = {
    name: {'asset_id': 'r04_' + name, 'canvas': [800, 1000], 'evidence_id': 'r04_' + name,
           'preserve_on_first_read': True, 'allow_zoom': True,
           'requires_all': ['P02'] if name == 'playback_transcript' else ['P17'] if name == 'witness_procedure' else ['P01']}
    for name in ('recording_log', 'correction_note', 'assembly_card', 'playback_transcript', 'maintenance_ledger', 'witness_procedure')
}
inspections['workers_photo'] = {'asset_id': 'r04_workers_photo', 'canvas': [1448, 1086], 'allow_zoom': True,
    'evidence_id': 'r04_workers_photo', 'preserve_on_first_read': True, 'description': 'Two unnamed station workers by the coast. Atmospheric photograph, not a map or identity puzzle.'}
inspections['recorder'] = {
    'canvas': CANVAS, 'requires_all': ['P01'], 'base_asset_id': 'r04_channel_panel_blank',
    'panel_spec': SPEC['panels']['P02'], 'room_mechanism_asset_id': 'r04_recorder_empty',
    'authoritative_source': 'assets/listening/authored-spec.json#/panels/P02',
    'solution': SPEC['solution'], 'reward_evidence_ids': ['r04_playback_transcript'],
    'room_band_rects': room_slots,
    'notes': ['Room pose uses the fixed empty mechanism plus generated band skins.',
              'The close-up uses the authored band face and 600x300 assembly canvas, with full 180x300 overlays. Keep the uniform transform from the source specification.',
              'Do not stretch the angled generated wax skin beneath exact seam artwork.',
              'Needle and crank are baked into the room mechanism. Exact inspection controls provide raised/lowered needle and playback states.']}
inspections['listening_sessions'] = {
    'canvas': CANVAS, 'requires_all': ['P16'], 'base_asset_id': 'r04_channel_panel_blank',
    'panel_spec': SPEC['panels']['P17'], 'entry': 'recorder_inspection_session_tab',
    'authoritative_source': 'assets/listening/authored-spec.json#/panels/P17',
    'waveforms': SPEC['waveforms'],
    'audio_status': 'authored_timing_diagrams_only_recording_and_sync_required'}
inspections['witness_channel'] = {
    'canvas': CANVAS, 'requires_all': ['P17', 'P18'], 'entry': 'recorder_inspection_witness_tab',
    'base_asset_id': 'r04_channel_panel_blank', 'panel_spec': SPEC['panels']['P19'],
    'authoritative_source': 'assets/listening/authored-spec.json#/panels/P19',
    'audio_status': 'not_recorded', 'device_data_access': 'none'}
# Explicit earned-evidence rules prevent a static visibility note granting future
# answers. Runtime must persist each observed version without discarding it.
evidence_rules = {
    'r04_playback_transcript': {'requires_all': ['P02'], 'grant_event': 'successful_P02_playback_or_accessible_transcript', 'never_grant_on_room_visit': True},
    'r04_venn_statement': {'requires_all': ['P16'], 'grant_event': 'both_bell_peaks_aligned_AND_venn_listened_or_read'},
    'r04_nora_statement': {'requires_all': ['P16'], 'grant_event': 'both_bell_peaks_aligned_AND_nora_listened_or_read'},
    'r04_witness_procedure': {'requires_all': ['P17'], 'grant_event': 'both_P17_statements_preserved'},
    'r04_witness_margin': {'requires_all': ['P17'], 'grant_event': 'both_P17_statements_preserved'},
}
for answer in SPEC['panels']['P19']['questions']:
    evidence_rules[answer['evidence_asset']] = {'requires_all': ['P17', 'P18'],
        'grant_event': 'witness_connected_AND_answer_' + answer['id'] + '_heard_or_read',
        'replayable': True, 'never_grant_on_panel_open': True}
for ident, rule in evidence_rules.items():
    assert ident in assets, ident
    inspections[ident.removeprefix('r04_')] = {
        'asset_id': ident, 'canvas': [assets[ident]['width'], assets[ident]['height']],
        'evidence_id': ident, 'allow_zoom': True, 'persist_when_earned': True,
        'evidence_rule': rule}

inspections.update({
    'lamp': {'asset_id': lamp_on or 'r04_lamp_off', 'allow_zoom': True, 'description': 'Warm task lamp. Its switch is an art-review control, not another puzzle.'},
    'recording_cases': {'case_ids': ['A', 'B', 'C'], 'closed_asset_id': 'r04_canister_closed', 'open_asset_id': 'r04_canister_open',
        'label_assets': ['r04_case_label_a', 'r04_case_label_b', 'r04_case_label_c'], 'band_asset_id': 'r04_wax_band',
        'interaction': 'Select one case with a tap button, open it, recover that labeled band. A recovered band cannot appear simultaneously in its case and a spindle slot.'},
    'brush': {'asset_id': 'r04_brush_shavings', 'allow_zoom': True, 'description': 'Wax dust in the old bristles. No hidden code.'},
    'wooden_case': {'open_asset_id': 'r04_case_open', 'closed_asset_id': 'r04_case_closed', 'band_asset_id': 'r04_wax_band',
        'allow_zoom': True, 'description': 'An empty repair case by default. A band is shown only when explicitly placed here in saved object state.'},
    'drawer': {'open_asset_id': 'r04_drawer_open', 'allow_zoom': True, 'description': 'Shallow service drawer. No additional required item or puzzle dependency is introduced.'},
    'shelf_cases': {'asset_id': 'r04_shelf_cylinder', 'allow_zoom': True, 'description': 'Two retained cylinders. Atmospheric storage, no newly invented recordings or clue lettering.'},
    'stool': {'asset_id': 'r04_stool_dry', 'damp_overlay_asset_id': 'r04_stool_damp_mark', 'allow_zoom': True,
        'description': 'Preserve an observation of the dry or damp seat. The full damp sprite is a pose reference, not a changing silhouette.'},
    'window': {'asset_id': '@weather', 'source_region_px': [1112, 137, 268, 442], 'allow_zoom': True,
        'description': 'Observe the current sea state and retain that observed version. No magnification-derived numerical clue.'},
})

aliases = {
    'band_A': {'skin_asset_id': 'r04_wax_band', 'inspection_face_asset_id': 'r04_band_face', 'overlay_assets': ['r04_band_a_step_' + str(i) for i in range(3)]},
    'band_B': {'skin_asset_id': 'r04_wax_band', 'inspection_face_asset_id': 'r04_band_face', 'overlay_assets': ['r04_band_b_step_' + str(i) for i in range(3)]},
    'band_C': {'skin_asset_id': 'r04_wax_band', 'inspection_face_asset_id': 'r04_band_face', 'overlay_assets': ['r04_band_c_step_' + str(i) for i in range(3)]},
    'storage_cases_A_B_C': {'closed_asset_id': 'r04_canister_closed', 'open_asset_id': 'r04_canister_open', 'label_assets': ['r04_case_label_a', 'r04_case_label_b', 'r04_case_label_c']},
    'shelf_cylinders_upper_middle': {'asset_id': 'r04_shelf_cylinder', 'instances': 2, 'clue': False},
    'dry_to_damp_stool': {'base_asset_id': 'r04_stool_dry', 'overlay_asset_id': 'r04_stool_damp_mark', 'generated_pose_reference': 'r04_stool_damp'},
    'recording_skin_in_case_and_slots': {'asset_id': 'r04_wax_band', 'mutually_exclusive_locations': True},
    'tide_ix': {'weather_stage': 8, 'new_image_required': False},
}
coverage = [
    ('Room, door, trim, bench, shelf structure, four closed drawer fronts', ['r04_clean_base'], 'Fixed base; no duplicate prop layer.'),
    ('Open doorway', ['r04_door_open_plate'], 'Clip portal only; door leaf is out of view.'),
    ('Window, storm and impossible sea states', [row['asset_id'] for row in weather_states], 'Seven shared glazing panes; fixed frame.'),
    ('Window rain and local damp', ['r04_rain_0', 'r04_rain_1', 'r04_rain_2', 'r04_wall_damp'], 'Authored overlays; motion remains optional.'),
    ('Noticeboard and four corner pins', ['r04_noticeboard_panel'], 'Opaque backing primitive supplied; corner pins part of board texture.'),
    ('Pinned recording log, note and photograph', ['r04_recording_log', 'r04_correction_note', 'r04_workers_photo'], 'Readable close-ups; text generated in original master is superseded.'),
    ('Old paper rectangle at noticeboard upper right', [], 'Native brown rectangle, atmospheric stain with no code.'),
    ('Headphones, hook and connecting cord', ['r04_headphones_hanging'], 'Cutout plus native hook and cord continuation paths in room_layers.'),
    ('Task lamp off and light pool', ['r04_lamp_off', 'r04_lamp_pool'] + ([lamp_on] if lamp_on else []), 'Lit shade is included only when measured in current asset set.'),
    ('Three vertical recording canisters', ['r04_canister_closed', 'r04_canister_open', 'r04_case_label_a', 'r04_case_label_b', 'r04_case_label_c'], 'Reusable closed/open skin and three exact labels.'),
    ('Wax recorder, spindle, brass uprights, needle and crank', ['r04_recorder_empty', 'r04_recorder_partial', 'r04_recorder_assembled'], 'Fixed empty mechanism plus band layers is authoritative; whole poses are references.'),
    ('Three recording bands and loose band in wooden case', ['r04_wax_band', 'r04_band_face'] + [f'r04_band_{name}_step_{step}' for name in 'abc' for step in range(3)], 'One skin, nine exact overlays; no physical band can exist twice.'),
    ('Brush and wax shavings', ['r04_brush_shavings'], 'Single combined prop retains small debris.'),
    ('Small wooden case', ['r04_case_open', 'r04_case_closed'], 'Swap pose on inspection/re-entry; not registered hinge animation.'),
    ('Instruction card and stand', ['r04_instruction_stand', 'r04_assembly_card'], 'Readable authored sheet covers blank stand face.'),
    ('Two horizontal shelf cylinders and ledger stack', ['r04_shelf_cylinder', 'r04_ledger_stack', 'r04_maintenance_ledger'], 'Two repeated shelf cylinders; ledger inspection has authored text.'),
    ('Functional top drawer', ['r04_drawer_open'], 'One interactive drawer; remaining three fronts remain fixed furniture.'),
    ('Worn stool and damp impression', ['r04_stool_dry', 'r04_stool_damp_mark', 'r04_stool_damp'], 'Registered overlay over dry prop; alternate full damp pose retained as reference.'),
    ('Later P17/P19 listening controls', ['r04_channel_panel_blank', 'r04_p17_panel_overlay', 'r04_p19_panel_overlay'], 'Inspection-only panel; no extra room horns or wall machinery.'),
]

manifest = {
    'schema_version': 1, 'room_id': 'R04', 'title': 'Listening Room',
    'scope': 'Listening Room v4 static art, progression appearances, object poses and authored puzzle graphics; not all twelve game rooms.',
    'generated_by': 'tools/build_listening_manifest.py', 'canvas': CANVAS,
    'coordinate_convention': 'Every *_rect and *_region_px is [x,y,width,height]; bbox_ltrb is [left,top,right,bottom] with exclusive right/bottom.',
    'rendering_contract': [
        'Render room_layers in ascending z, stable original order for equal z. Coordinates stay fixed across puzzle/weather state.',
        'For image layers, fit the source_region_px crop into target_rect. No crop is written back to source PNG. Generated source regions ignore alpha below 16 for placement only.',
        'Use full canvas for authored graphics, especially seams, effect maps and control overlays. Their transparent margins encode registration.',
        'All when fields are AND conditions. Empty when means visible. recorder_slot means the named slot is occupied, not that P02 is complete.',
        '@weather resolves to the highest eligible weather_states asset. @rain resolves by weather rain_mode, with freeze_0 in reduced motion.',
        'Use clip_rects as target-space clips. The full weather and doorway image are never substituted for fixed_room.',
        'At viewport scale, letterbox 4:3 uniformly. Inflate hit targets to at least 44 CSS px or provide inspection buttons; do not move clue objects.',
    ],
    'accepted_reference': {'path': 'art/concepts/listening-room-approved-master-v4.png',
        'sha256': sha256((ROOT / 'art/concepts/listening-room-approved-master-v4.png').read_bytes()).hexdigest(),
        'canvas': CANVAS, 'status': 'accepted_visual_direction', 'puzzle_pose': 'partial_reference_not_new_game'},
    'assets': assets, 'room_layers': sorted(layers, key=lambda item: item['z']),
    'window_panes': SPEC['window_panes'], 'weather_states': weather_states,
    'weather_rules': {'clock_driven': False, 'tide_ix_holds_stage': 8, 'p01_alone_changes_weather': False,
                      'p02_and_p03_finish_tide_i_without_changing_stage': True, 'never_dim_inspection_text': True},
    'state_defaults': {'weather_stage': 1, 'lamp_on': True, 'door_open': False, 'drawer_open': False,
                       'case_open': False, 'case_contains_band': False, 'recorder_slots': [None, None, None],
                       'band_locations': {'A': 'canister_A', 'B': 'canister_B', 'C': 'canister_C'},
                       'note': 'P01 grants room access; task lamp is lit on arrival. OFF is an art-review option. Light/weather never marks a puzzle complete.'},
    'hotspots': hotspots, 'inspections': inspections, 'aliases': aliases, 'evidence_rules': evidence_rules,
    'master_prop_coverage': [{'prop': prop, 'asset_ids': ids, 'implementation': note} for prop, ids, note in coverage],
    'actual_map_props_in_room': [],
    'map_policy': 'The visible pinned image is a photograph, not a chart. If an actual map is later added, give it a readable close-up and preserve each observed version.',
    'excluded_review_directories': ['art/listening-review/'],
    'missing_art': [] if lamp_on else ['lit task-lamp shade or on pose'],
    'remaining_integration': ['P02/P17/P19 scene and save-state wiring', 'Final interactive placement and touch-size checks',
                              'Voice recording, room tone and synchronization with authored timing traces',
                              'Needle/crank motion if desired; static control states do not require new raster art',
                              'Godot rendered preview, browser/iPad, iOS and Android validation'],
    'verified': ['PNG dimensions and decoded mode', 'SHA-256 for every PNG and paired SVG', 'Actual and visible alpha bounds', 'Deterministic file references'],
}

# Catch broken references or impossible geometry without asserting gameplay.
for layer in layers:
    if layer['kind'] != 'image':
        continue
    assert layer['asset_id'].startswith('@') or layer['asset_id'] in assets, layer['id']
    x, y, w, h = layer['source_region_px']
    assert w > 0 and h > 0 and x >= 0 and y >= 0, layer['id']
    if layer['asset_id'] in assets:
        art = assets[layer['asset_id']]
        assert x + w <= art['width'] and y + h <= art['height'], layer['id']
for item in hotspots:
    assert item['inspection_id'] is None or item['inspection_id'] in inspections, item['id']
for row in coverage:
    assert all(ident in assets for ident in row[1]), row[0]
(PACK / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')

counts = Counter(item['class'] for item in assets.values())
lines = [
    '# Listening Room asset inventory', '',
    'This inventory covers the accepted R04 v4 room and its object, inspection and weather artwork. It does not claim that the other eleven rooms, audio or gameplay are complete.', '',
    f"**Current inventory:** {len(assets)} PNG files, including {counts['generated_illustration']} generated illustrations and {counts['authored_graphic']} authored SVG/PNG pairs. The accepted master and rejected attempts are excluded from this count.", '',
    'The machine-readable [manifest](../assets/listening/manifest.json) supplies measured hashes, dimensions, alpha bounds, room layers, crop rectangles, hotspots, reusable aliases and puzzle dependencies. Rebuild it with `python3 tools/build_listening_manifest.py`; source rasters remain unchanged.', '',
    '## Composition contract', '',
    'Use the clean room once. Clip only weather glazing panes and the open doorway. Put objects, local damp and light above the static plate. Full weather renders contain a partially assembled recorder and are never puzzle-state authority. Tide IX holds the eighth weather appearance.', '',
    'Coordinates are on a 1448 × 1086 canvas. Every rectangle is x/y/width/height; only fields explicitly named `bbox_ltrb` use exclusive left/top/right/bottom. For generated cutouts, fit `source_region_px` into `target_rect`; transparent padding otherwise shrinks or misplaces the visible prop. The crop is render metadata, not an edited file. Exact SVG exports always retain their complete canvas.', '',
    'Several generated cutouts contain faint alpha below 16 far from the visible object. Both exact and visible bounds are measured. The noticeboard has alpha 200–250 throughout and needs its specified opaque brown backing. Object pose differences are handled as swaps; no pixel-perfect animation is promised.', '',
    '## Visible master coverage', '',
    '| Master object | Supplied representation |', '| --- | --- |',
]
for prop, ids, note in coverage:
    lines.append(f"| {prop} | {', '.join('`' + ident + '`' for ident in ids) or 'Native manifest primitives'}. {note} |")
lines += ['', '## Progression mapping', '', '| Appearance | Required completed puzzles | Exterior |', '| --- | --- | --- |']
for row in weather_states:
    lines.append(f"| {row['stage']}: {row['name']} | {', '.join(row['all_completed']) or 'Arrival'} | {row['description']} |")
lines += ['', '## Puzzle and evidence bindings', '',
    '- P02 begins after P01, independently of P03. One fixed empty room recorder and shared band skins represent any partial room state. The close-up uses a separate authored band face, exact 180 × 300 overlays and 600 × 300 fixed guides from `authored-spec.json`. C/A/B at steps 0/0/0 yields calibration zero 4 and the tomorrow transcript. Keep both in the notebook.',
    '- P17 begins after P16. Use the inspection panel and two separately labeled timing traces. Align both bell marks, then listen to Venn and Nora separately. Preserve both statements and the witness procedure. Timing diagrams are authored art and still need recorded voices.',
    '- P19 begins after both P17 and P18. Motor OFF, A CLOSED, B CLOSED, C OPEN, then WITNESS. Shared state graphics give every switch and indicator a clear label. The final answer continues after the indicator darkens. No horns, microphone access or device history are involved.',
    '- Recording log, pinned note, photograph, assembly card, maintenance ledger and earned transcripts each have inspection/evidence bindings. The photograph is atmospheric and does not identify the workers. There is currently no actual map in this room; any later map must receive a readable close-up.', '',
    '## Measured asset register', '',
    '| Asset | Size | Alpha range | Visible source region x/y/w/h | Role |', '| --- | --- | --- | --- | --- |']
for ident, art in assets.items():
    lines.append(f"| `{ident}` | {art['width']} × {art['height']} | {art['alpha_range'][0]}–{art['alpha_range'][1]} | {','.join(map(str, art['render_region_px']))} | {art['runtime_use']} |")
lines += ['', '## Delivery limits', '',
          ('All bounded R04 illustration roles have a current file or deliberate reusable/native-vector representation.' if lamp_on else 'The lit task-lamp shade/on pose remains the only missing bounded illustration role at this scan.'), '',
          'This manifest verifies files and art structure. It does not validate runtime puzzle state, playback, saves, touch handling, audio, browser export or native device behavior. Codex integration must use the review composition and the defined evidence constraints. The generated empty/partial/assembled recorder and dry/damp stool poses are available for art comparison; fixed geometry plus overlays remains authoritative.', '']
(ROOT / 'docs/listening-inventory.md').write_text('\n'.join(lines))
print(f"R04 inventory: {len(assets)} PNGs, {counts['authored_graphic']} SVG pairs, {len(layers)} layers, {len(hotspots)} hotspots; missing art: {manifest['missing_art']}")
