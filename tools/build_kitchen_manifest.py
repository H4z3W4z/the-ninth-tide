#!/usr/bin/env python3
"""Measure R05 art without rewriting source rasters and build its handoff.

Pillow is read-only here. Source-region crops are metadata, not edited images.
The room-layer specification is populated from the inspected production master.
Run after build_kitchen_vectors.py, then run the global asset manifest builder.
"""
from collections import Counter
from hashlib import sha256
from pathlib import Path
import json

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'assets/kitchen'
CANVAS = [1448, 1086]
FULL = [0, 0, *CANVAS]


def load_json(path, default):
    return json.loads(path.read_text()) if path.exists() else default


SPEC = load_json(PACK / 'authored-spec.json', {'assets': [], 'panels': {}})
GENERATED = load_json(ROOT / 'docs/kitchen-pack-generation.json', {'assets': []})
AUTHORED = {item['id']: item for item in SPEC.get('assets', [])}
PROVENANCE = {item['id']: item for item in GENERATED.get('assets', []) if item.get('kind') != 'draft'}


def rect_from_bbox(bbox):
    x1, y1, x2, y2 = bbox
    return [x1, y1, x2 - x1, y2 - y1]


def inspect(path):
    with Image.open(path) as im:
        im.load()
        w, h = im.size
        alpha = im.getchannel('A') if 'A' in im.getbands() else None
        exact = list(alpha.getbbox() or (0, 0, w, h)) if alpha else [0, 0, w, h]
        visible = list(alpha.point(lambda v: 255 if v >= 16 else 0).getbbox() or (0, 0, w, h)) if alpha else [0, 0, w, h]
        hist = alpha.histogram() if alpha else [0] * 255 + [w * h]
        out = {
            'path': str(path.relative_to(ROOT)), 'width': w, 'height': h,
            'mode': im.mode, 'sha256': sha256(path.read_bytes()).hexdigest(),
            'alpha_range': list(alpha.getextrema()) if alpha else [255, 255],
            'alpha_bbox_ltrb': exact, 'visible_bbox_ltrb': visible,
            'transparent_pixel_fraction': round(hist[0] / (w * h), 6),
            'low_alpha_pixel_fraction': round(sum(hist[1:16]) / (w * h), 6),
            'render_region_px': rect_from_bbox(visible),
            'integrity_status': 'file_and_alpha_measured',
            'runtime_integration_status': 'not_implemented',
        }
    source = path.with_suffix('.svg')
    if source.exists():
        out.update(source_svg=str(source.relative_to(ROOT)), source_svg_sha256=sha256(source.read_bytes()).hexdigest(),
                   render_region_px=[0, 0, w, h], **{'class': 'authored_graphic'},
                   role=AUTHORED.get(path.stem, {}).get('role', 'authored_graphic'),
                   visibility_note=AUTHORED.get(path.stem, {}).get('visible_when'))
    else:
        out.update(**{'class': 'generated_illustration'}, role=PROVENANCE.get(path.stem, {}).get('kind', 'generated_illustration'))
    if path.parent.name == 'backgrounds':
        out['render_region_px'] = [0, 0, w, h]
    out['runtime_use'] = 'layered_art_candidate'
    return out


def main():
    assets = {path.stem: inspect(path) for path in sorted(PACK.rglob('*.png'))}
    for suffix in ('02_rain', '03_storm', '04_suspended', '05_upright', '06_silent', '07_bearing', '08_surface'):
        path = ROOT / f'assets/listening/backgrounds/r04_weather_{suffix}.png'
        item = inspect(path)
        item.update(**{'class': 'shared_generated_illustration'}, runtime_use='shared_exterior_crop_only',
                    role='shared_coastal_weather', reuse_note='Only the frame-free lower glass source is sampled; never load the R04 room as R05 background.')
        assets[path.stem] = item
    manifest = build_manifest(assets)
    validate(manifest)
    PACK.mkdir(parents=True, exist_ok=True)
    (PACK / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    write_inventory(manifest)
    counts = Counter(item['class'] for item in assets.values())
    print(f"R05 inventory: {len(assets) - counts['shared_generated_illustration']} local PNGs, {counts['shared_generated_illustration']} shared PNGs, {counts['authored_graphic']} SVG pairs, {len(manifest['room_layers'])} layers; missing art: {manifest['missing_art']}")


def build_manifest(assets):
    layers, missing, coverage = [], [], []
    panes = [[930, 122, 113, 129], [1052, 122, 102, 129], [1162, 122, 102, 129], [1273, 122, 104, 129],
             [930, 260, 113, 87], [1052, 260, 102, 87], [1162, 260, 102, 87], [1273, 260, 104, 87],
             [930, 362, 447, 207]]
    def image_layer(ident, asset_id, z, target, when=None, **extra):
        if asset_id not in assets and not asset_id.startswith('@'):
            missing.append(asset_id)
            return
        region = assets[asset_id]['render_region_px'] if asset_id in assets else FULL
        layers.append(dict(id=ident, kind='image', asset_id=asset_id, z=z, target_rect=target,
                           source_region_px=region, fit='stretch', when=when or {}, **extra))
    def rect_layer(ident, z, target, fill, when=None, **extra):
        layers.append(dict(id=ident, kind='rect', z=z, target_rect=target, fill=fill, when=when or {}, **extra))
    def path_layer(ident, z, data, fill, when=None, **extra):
        layers.append(dict(id=ident, kind='path', z=z, svg_path=data, fill=fill,
                           stroke='none', stroke_width=0, when=when or {}, **extra))
    def cover(prop, ids, note):
        absent = [ident for ident in ids if ident not in assets]
        missing.extend(absent)
        coverage.append({'prop': prop, 'asset_ids': [ident for ident in ids if ident in assets], 'implementation': note})

    image_layer('fixed_room', 'r05_clean_base', 0, FULL)
    for i, pane in enumerate(panes):
        image_layer('window_exterior_' + str(i), '@weather', 10, pane, clip_rects=[pane])
        sx = [1114, 1208, 1303, 1208][i % 4]
        layers[-1]['source_region_px'] = [sx, 139 if i < 4 else 264, 78, 108 if i < 4 else 89] if i < 8 else [1115, 374, 265, 205]
    rect_layer('service_open_portal', 12, [49, 168, 173, 720], '#13232b', {'service_door_open': True})
    rect_layer('service_threshold', 13, [49, 870, 173, 18], '#3d4948', {'service_door_open': True})
    for stage, opacity in [(3, .05), (4, .09), (5, .14), (6, .20), (7, .26), (8, .33)]:
        rect_layer('interior_cool_' + str(stage), 16, FULL, '#102737', {'weather_stage': stage}, opacity=opacity)
    path_layer('window_inward_damp', 18, 'M886 607 L1377 607 L1377 617 Q1310 613 1288 620 Q1230 614 1191 621 Q1140 614 1108 620 Q1060 616 1027 623 Q973 615 938 620 Q907 614 886 617 Z',
               '#516b68', {'weather_min': 3}, opacity=.25)
    path_layer('window_inward_trace', 19, 'M949 610 C950 622 956 631 954 644 M1032 611 C1030 623 1038 638 1036 650 M1265 608 C1260 625 1263 637 1257 650',
               'none', {'weather_min': 5}, opacity=.18)
    layers[-1].update(stroke='#98aca0', stroke_width=2)

    image_layer('stove_copper_pot', 'r05_stockpot', 30, [330, 472, 145, 94])
    image_layer('table_towel', 'r05_towel', 30, [375, 673, 93, 136])
    image_layer('closed_serving_ledger', 'r05_ledger_closed', 32, [1283, 654, 139, 51])
    image_layer('service_rule_pinned', 'r05_amendment_rules', 32, [435, 299, 58, 83])
    image_layer('service_duplicate_pinned', 'r05_duplicate_board_reveal', 33, [435, 299, 58, 83], {'p09_complete': True})
    image_layer('service_board_condensation', 'r05_board_condensation', 34, [430, 291, 70, 100], {'p09_complete': True, 'duplicate_board_condensed': True})

    marks = ['NB', 'SR', 'TI', 'AL', 'CM', 'DH', 'EP', 'JW', 'unsigned']
    room_slots = []
    for i, mark in enumerate(marks):
        x = 510 + 84 * i
        slot = [x, 651, 70, 34]
        label = [x + 18, 661, 34, 15]
        rack = [1008 + 85 * (i // 3), 651 - 7 * (i % 3), 70, 34]
        skin = 'r05_bowl_plain'
        room_slots.append({'id': mark, 'slot_rect': slot, 'rack_rect': rack, 'label_rect': label, 'skin_asset_id': skin,
                           'label_asset_id': 'r05_initial_' + mark.lower() if mark != 'unsigned' else None,
                           'repair_asset_id': 'r05_square_patch' if mark == 'unsigned' else None,
                           'repair_relative_rect': [43, 16, 12, 12] if mark == 'unsigned' else None})
        image_layer('bowl_' + mark.lower() + '_placed', skin, 40, slot, {'bowls_arranged': True})
        image_layer('bowl_' + mark.lower() + '_rack', skin, 40 + i / 20, rack, {'bowls_arranged': False})
        if mark == 'unsigned':
            image_layer('unsigned_bowl_square_patch_placed', 'r05_square_patch', 43, [x + 43, 667, 12, 12], {'bowls_arranged': True})
            image_layer('unsigned_bowl_square_patch_rack', 'r05_square_patch', 43, [rack[0] + 43, rack[1] + 16, 12, 12], {'bowls_arranged': False})
        if mark != 'unsigned':
            aid = 'r05_initial_' + mark.lower()
            image_layer('bowl_' + mark.lower() + '_label', aid, 43, label, {'bowls_arranged': True})
            image_layer('cloth_' + mark.lower() + '_place', aid, 37, [x + 18, 691, 34, 17])
        else:
            image_layer('cloth_square_place', 'r05_square_place', 37, [x + 21, 687, 26, 26])
        spoon_rect = [x + 55, 670, 28, 45]
        if mark == 'unsigned':
            image_layer('unsigned_spoon_rest', 'r05_spoon_rest', 43, spoon_rect, {'spoon_lifted': False})
            image_layer('unsigned_spoon_raised', 'r05_spoon_raised', 43, spoon_rect, {'p07_complete': True, 'spoon_lifted': True})
        else:
            image_layer('spoon_' + mark.lower(), 'r05_spoon_rest', 43, spoon_rect)
    image_layer('bowl_inward_condensation', 'r05_bowl_condensation_2', 44, [1182, 646, 70, 40], {'p07_complete': True})
    image_layer('pantry_drawer_open', 'r05_drawer_open', 46, [461, 732, 180, 66], {'pantry_drawer_open': True})
    image_layer('pantry_token_reward', 'r05_token_pantry', 47, [535, 735, 20, 20], {'pantry_drawer_open': True, 'p07_complete': True, 'pantry_token_in_drawer': True})

    weather_rows = [
        (2, 'Tide II complete', ['P06'], 'rain', 'Rain lowers the familiar coast; the room opens with the same weather as the service landing.', 'cycle'),
        (3, 'Tide III complete', ['P09'], 'storm', 'Heavy rain and inward damp reach below the window. The corrected meal record remains readable.', 'cycle'),
        (4, 'Tide IV complete', ['P12'], 'suspended', 'Rain seems suspended; visible water and its sound disagree.', 'freeze_0'),
        (5, 'Tide V complete', ['P15'], 'upright', 'The horizon compresses into the upright sea; condensation tracks toward the table.', 'cycle'),
        (6, 'Tide VI complete', ['P17', 'P18'], 'silent', 'The sea loses distant detail; visible rain continues after exterior sound falls away.', 'cycle'),
        (7, 'Tide VII complete', ['P21'], 'bearing', 'The lighthouse appears at the wrong bearing while darkness presses close to the glass.', 'cycle'),
        (8, 'Tide VIII complete / Tide IX hold', ['P24'], 'surface', 'A near-featureless surface replaces sea and sky. The meal table remains legible.', 'off'),
    ]
    weather = [dict(stage=stage, name=name, all_completed=flags, asset_id=f'r04_weather_{stage:02d}_{suffix}',
                    description=description, rain_mode=rain, source_region_px=[1115, 374, 265, 205])
               for stage, name, flags, suffix, description, rain in weather_rows]
    inspections = {}
    evidence_rules = {}
    for name, gate in SPEC.get('evidence_gates', {}).items():
        requires = ['P09'] if name in ('r05_duplicate_board', 'r05_duplicate_board_reveal', 'r05_p09_record') else ['P07'] if name in ('r05_extra_diner_note', 'r05_p07_record') else ['P06']
        if name not in assets:
            missing.append(name)
            continue
        rule = {'requires_all': requires, 'grant_event': 'first_read' if requires == ['P06'] else 'successful_' + requires[0] + '_commit',
                'preserve_before_replacement': True, 'never_grant_on_art_preview': True}
        if name in ('r05_duplicate_board', 'r05_duplicate_board_reveal'):
            rule.update(grant_event='successful_P09_commit_before_condensation', preserve_before_animation=True)
        evidence_rules[name] = rule
        inspections[name.removeprefix('r05_')] = dict(asset_id=name, canvas=[assets[name]['width'], assets[name]['height']],
            evidence_id=name, allow_zoom=True, preserve_on_first_read=True, evidence_rule=rule)
    for puzzle, ident in [('P07', 'supper_table'), ('P09', 'service_board')]:
        if puzzle in SPEC.get('panels', {}):
            inspections[ident] = dict(canvas=CANVAS, panel_spec=SPEC['panels'][puzzle],
                authoritative_source='assets/kitchen/authored-spec.json#/panels/' + puzzle,
                requires_all=['P06'], interaction_requires_all=SPEC['panels'][puzzle]['requires'])
        else:
            missing.append(puzzle + '_panel_spec')
    inspections.update({
        'provisioning_book': {'entry_asset_id': 'r05_serving_ledger', 'allow_zoom': True,
            'page_inspection_ids': ['serving_ledger', 'table_instructions', 'menu_objection', 'provisioning_repair', 'kitchen_work_card'],
            'earned_page_inspection_ids': ['extra_diner_note', 'p07_record'],
            'description': 'The serving book opens separate readable pages and transcripts. Earned pages stay gated by their own evidence rules.'},
        'window': {'asset_id': '@weather', 'source_region_px': [1115, 374, 265, 205], 'allow_zoom': True, 'description': 'Observe and preserve the current exterior appearance. No numeric clue is hidden by enlargement.'},
        'range': {'description': 'An iron range, chimney and ordinary copper stock pot. No additional fire-lighting puzzle or required fuel.'},
        'shelf': {'description': 'Stacked plates, two canisters, a coffee pot and a mixing bowl. Static household storage; the nine P07 bowls are separately tracked.'},
        'apron': {'description': 'Nora’s apron and hanging ladle remain where she left them. No hidden key or new mandatory dependency.'},
        'lamp': {'description': 'The warm pendant is fixed room lighting. No extra P01 repair is required.'},
        'towel': {'asset_id': 'r05_towel', 'allow_zoom': True, 'description': 'A carefully folded towel. The repaired cup itself remains in the Bunk Room; the serving book contains its sketch.'},
        'drawer': {'open_asset_id': 'r05_drawer_open', 'requires_all': ['P07'], 'earned_evidence_inspection_ids': ['extra_diner_note', 'p07_record'],
            'description': 'The pantry token half becomes available once after P07. It cannot be simultaneously in the drawer, inventory and service board.'},
        'service_door': {'requires_all': ['P09'], 'description': 'Released service access leads to R07 and R08. Open portal uses fixed native geometry; unlocking persists.'},
        'spoon': {'asset_id': 'r05_spoon_rest', 'raised_asset_id': 'r05_spoon_raised', 'description': 'The unsigned setting’s spoon lifts and lowers once on P07 completion. Presentation never controls rewards.'},
    })
    def hotspot(ident, rect, label, inspection):
        return dict(id=ident, rect=rect, label=label, inspection_id=inspection, min_touch_target_css_px=44)
    hotspots = [
        hotspot('supper_table', [505, 626, 765, 114], 'Inspect the supper table', 'supper_table'),
        hotspot('service_board', [417, 276, 102, 176], 'Inspect the service board', 'service_board'),
        hotspot('serving_book', [1280, 648, 144, 64], 'Read Nora’s serving book', 'provisioning_book'),
        hotspot('table_instructions', [507, 688, 758, 35], 'Read the place-setting instructions', 'table_instructions'),
        hotspot('range', [274, 470, 284, 439], 'Inspect the range', 'range'),
        hotspot('shelf', [540, 169, 330, 248], 'Inspect the shelf', 'shelf'),
        hotspot('apron', [784, 329, 87, 315], 'Inspect Nora’s apron', 'apron'),
        hotspot('pendant', [375, 135, 124, 88], 'Inspect the pendant lamp', 'lamp'),
        hotspot('folded_towel', [372, 671, 100, 142], 'Inspect the folded towel', 'towel'),
        hotspot('pantry_drawer', [460, 730, 181, 86], 'Inspect the pantry drawer', 'drawer'),
        hotspot('window', [931, 123, 447, 446], 'Observe the sea', 'window'),
        hotspot('service_door', [47, 164, 176, 725], 'Use the service passage', 'service_door'),
        hotspot('unsigned_spoon', [1238, 665, 24, 46], 'Inspect the unsigned spoon', 'spoon'),
    ]
    cover('Room, sea-glass walls, floor, trim, table and closed pantry drawer', ['r05_clean_base'], 'Fixed room geometry, independent of weather and bowls.')
    cover('Iron range and chimney', ['r05_clean_base'], 'Static domestic equipment; readable inspection description, no new repair puzzle.')
    cover('Pendant, shelf plates, coffee pot, canisters, mixing bowl, apron and ladle', ['r05_clean_base'], 'Fixed ordinary household props with inspection descriptions; no added occult symbols or unlabeled clues.')
    cover('Copper stock pot, folded towel and closed provisioning book', ['r05_stockpot', 'r05_towel', 'r05_ledger_closed'], 'Separate generated props; the book opens readable authored documents.')
    cover('Sea window and seven reachable storm appearances', [row['asset_id'] for row in weather], 'Shared R04 frame-free coastal crops behind nine fixed R05 panes. No duplicate PNG copies.')
    cover('Local inward condensation and cooling daylight', ['r05_bowl_condensation_0', 'r05_bowl_condensation_1', 'r05_bowl_condensation_2', 'r05_board_condensation'], 'Native room damp/tint plus registered authored bowl and board effects; evidence always retained.')
    cover('Eight initialed bowls and unsigned square-repaired ninth bowl', ['r05_bowl_plain', 'r05_square_patch'] + ['r05_bowl_' + mark.lower() for mark in marks], 'One generated room skin, exact square-repair overlay, and nine exact plan-view inspection faces. Shared geometry keeps the unsigned bowl registered.')
    cover('Nine cloth places and eight initial labels', ['r05_place_cloth', 'r05_square_place', 'r05_square_patch'] + ['r05_initial_' + mark.lower() for mark in marks[:-1]], 'Exact shared labels and square mark in the room; authored nine-place inspection cloth.')
    cover('Nine spoons and the unsigned spoon lift', ['r05_spoon_rest', 'r05_spoon_raised'], 'Authored rest pose instanced nine times. The unsigned spoon uses the registered raised pose on the same source canvas; no generated transparency replacement needed.')
    cover('Pantry drawer and paired service token', ['r05_drawer_open', 'r05_token_pantry', 'r05_token_bunk'], 'Open drawer pose; pantry half from P07, bunk half from P08. Both consumed together only on P09 acceptance.')
    cover('Service board, original eight, correction fields and three-cut stamp', ['r05_p09_panel', 'r05_amendment_rules', 'r05_amendment_stamp', 'r05_duplicate_board', 'r05_duplicate_board_reveal'], 'Exact inspection geometry and retained original; physical bare-text reveal and notebook copy are earned only after P09.')
    cover('Serving evidence, repair sketch and menu objection', list(SPEC.get('evidence_gates', {})), 'All readable and separately gated. The physical repaired cup remains R06.')
    cover('Open service portal', [], 'Native straight-on dark opening and threshold inside the fixed door frame.')
    master = ROOT / 'art/concepts/kitchen-room-master-v1.png'
    return {
        'schema_version': 1, 'room_id': 'R05', 'title': 'Kitchen and Mess', 'canvas': CANVAS,
        'scope': 'R05 room art and exact P07/P09 graphics; not other rooms or implemented gameplay.',
        'generated_by': 'tools/build_kitchen_manifest.py',
        'coordinate_convention': 'All *_rect and *_region_px are [x,y,width,height]; bbox_ltrb is exclusive left/top/right/bottom.',
        'accepted_reference': {'path': str(master.relative_to(ROOT)), 'sha256': sha256(master.read_bytes()).hexdigest() if master.exists() else None,
                               'status': 'user_accepted_master', 'canvas': CANVAS, 'puzzle_pose': 'illustrative_eight_bowl_study_not_saved_P07_state'},
        'assets': assets, 'room_layers': sorted(layers, key=lambda x: x['z']), 'window_panes': panes,
        'weather_states': weather,
        'weather_rules': {'clock_driven': False, 'first_reachable_stage': 2, 'entry_requires_all': ['P06'], 'tide_ix_holds_stage': 8,
                          'p07_alone_advances_global_weather': False, 'never_dim_inspection_text': True},
        'state_defaults': {'weather_stage': 2, 'bowls_arranged': False, 'pantry_drawer_open': False, 'pantry_token_in_drawer': False,
                           'p07_complete': False, 'spoon_lifted': False, 'p09_complete': False, 'service_door_open': False,
                           'duplicate_board_condensed': False, 'spoon_reveal_played': False,
                           'note': 'Room starts after P06. Review bools are sample poses; actual bowl locations and tokens come from persisted puzzle state.'},
        'rendering_contract': [
            'Render layers in ascending z. Image source_region_px maps into target_rect; source rasters remain unchanged.',
            'Use the full canvas for authored overlays. For generated cutouts use measured alpha>=16 content bounds only for placement.',
            'All when predicates are AND conditions. weather_min/max compare global weather_stage; other predicates compare saved state.',
            '@weather resolves to the highest eligible weather_states asset. Upper eight panes use frame-free matching sky crops; the lower pane uses the R04 coastal crop. Never stretch a whole R04 room into R05.',
            'bowls_arranged is a static art-review empty/solved shortcut only. Runtime uses room_bowl_layout to render each actual persisted bowl location.',
            'P07 completion and reward persistence happen before the spoon animation; never replay the lift on ordinary re-entry.',
            'P09 duplicate-board evidence is stored before condensation. Notebook copies are never obscured.',
            'Inflate room hotspots to at least 44 logical pixels or supply explicit inspection buttons. Do not move objects to change hit targets.',
        ],
        'room_bowl_layout': {'instances': room_slots, 'source_of_truth': 'persisted_P07_slots_and_inventory',
                             'one_location_per_bowl': True, 'inspection_panel': 'assets/kitchen/authored-spec.json#/panels/P07',
                             'available_bowls_are_room_rack_instances': True, 'partial_arrangements_must_render_individually': True},
        'state_lifecycle': {
            'P07': {'requires_all': ['P06'], 'commit_action': 'compare',
                    'preserve_before_presentation': ['r05_extra_diner_note', 'r05_p07_record'],
                    'token_reward': 'pantry_half_once', 'drawer_unlatched': True,
                    'one_shot_event': 'unsigned_spoon_lift_and_lower', 'presentation_flag': 'spoon_reveal_played',
                    'completion_does_not_wait_for_animation': True},
            'P09': {'requires_all': ['P07', 'P08'], 'commit_action': 'stamp',
                    'consume_together_on_valid_commit': ['pantry_half', 'bunk_half'],
                    'preserve_before_presentation': ['r05_duplicate_board', 'r05_p09_record'],
                    'never_consume': ['venn_three_cut_seal_rubbing'], 'unlock_routes': ['R07', 'R08'],
                    'original_eight_remains_in_evidence': True, 'condensation_requires_saved_duplicate': True},
            'token_locations': {'pantry_half': ['locked_drawer', 'available_drawer', 'inventory', 'service_socket', 'consumed_by_P09'],
                                'bunk_half': ['R06_source', 'inventory', 'service_socket', 'consumed_by_P09'],
                                'one_location_per_token': True, 'wrong_attempt_consumes_nothing': True},
            'resume': 'Restore saved arrangement, token locations and earned evidence first. Render latest weather directly. Do not replay an already acknowledged spoon reveal.'},
        'hotspots': hotspots, 'inspections': inspections, 'evidence_rules': evidence_rules, 'master_prop_coverage': coverage,
        'aliases': {'weather_2_to_8': 'Existing R04 coastal plates, crop-only reuse', 'eight_initialed_room_bowls': 'r05_bowl_plain plus individual room labels',
                    'nine_spoons': 'r05_spoon_rest with r05_spoon_raised at the unsigned setting', 'unsigned_bowl': 'r05_bowl_plain plus r05_square_patch', 'tide_ix': {'weather_stage': 8, 'new_image_required': False}},
        'actual_map_props_in_room': [],
        'map_policy': 'No actual map is pictured in this kitchen master. The service record and cup repair sketch are documents, not maps. Any later added map requires readable inspectable art and observed-version persistence.',
        'missing_art': sorted(set(missing)),
        'remaining_integration': ['R05 scene and P07/P09 puzzle wiring', 'Per-bowl persistence and token lifecycle', 'Notebook evidence and reveal gating',
                                  'Spoon/condensation presentation and reduced motion', 'Room tone and sound assets', 'Rendered engine, iPad/browser and native device validation'],
        'verified': ['Measured PNG dimensions, mode and alpha', 'PNG and paired SVG SHA-256', 'File references and layer crop bounds', 'Canonical puzzle dependency and evidence bindings'],
    }


def validate(manifest):
    assets = manifest['assets']
    for layer in manifest['room_layers']:
        if layer['kind'] != 'image':
            continue
        ident = layer['asset_id']
        assert ident.startswith('@') or ident in assets, layer['id']
        x, y, w, h = layer['source_region_px']
        assert x >= 0 and y >= 0 and w > 0 and h > 0, layer['id']
        if ident in assets:
            assert x + w <= assets[ident]['width'] and y + h <= assets[ident]['height'], layer['id']
    for hotspot in manifest['hotspots']:
        assert hotspot['inspection_id'] in manifest['inspections'], hotspot['id']
    for covered in manifest['master_prop_coverage']:
        assert all(ident in assets for ident in covered['asset_ids']), covered['prop']
    assert [row['stage'] for row in manifest['weather_states']] == list(range(2, 9))
    assert manifest['state_defaults']['weather_stage'] == 2
    assert manifest['weather_rules']['tide_ix_holds_stage'] == 8


def write_inventory(manifest):
    assets = manifest['assets']
    counts = Counter(item['class'] for item in assets.values())
    lines = [
        '# Kitchen and Mess asset inventory', '',
        'This is the R05 graphics handoff. It supplies room art, reachable weather appearances, separate object states and exact P07/P09 clue graphics. Gameplay, audio, save behavior and device validation remain integration work.', '',
        f"**Measured inventory:** {len(assets) - counts['shared_generated_illustration']} local PNG files: {counts['generated_illustration']} generated illustrations and {counts['authored_graphic']} authored SVG/PNG pairs. In addition, {counts['shared_generated_illustration']} existing R04 weather sources are referenced without duplication. Concept references and review composites are excluded.", '',
        'The [manifest](../assets/kitchen/manifest.json) records hashes, measured alpha regions, placements, layer conditions, puzzle inspection bindings and preserved evidence. Rebuild with `python3 tools/build_kitchen_manifest.py` after exporting the authored graphics. Source PNGs are never rewritten by this builder.', '',
        '## Composition and persistence', '',
        'Use a fixed room plate, window-only exterior art, registered authored local effects and independent props. Generated cutouts use their measured alpha-at-least-16 content rectangle as a render crop. This avoids transparent padding shrinking the visible object; it does not edit or crop the source file. Authored SVG exports retain their full canvas for registration.', '',
        'All rectangles are x/y/width/height on a 1448 × 1086 canvas. Only explicitly named `bbox_ltrb` fields use exclusive left/top/right/bottom bounds. Scale the complete view uniformly and letterbox. Large inspection buttons supplement small room objects.', '',
        'R05 first opens after P06 and inherits stage 2. Tides III–VIII progress from P09, P12, P15, P17 plus P18, P21 and P24. Tide IX holds stage 8. Review buttons never award puzzle completion. Weather changes cannot move clues, reset bowls, spend tokens or erase observations.', '',
        '## Visible master coverage', '', '| Object or surface | Supplied representation |', '| --- | --- |',
    ]
    for item in manifest['master_prop_coverage']:
        lines.append(f"| {item['prop']} | {', '.join('`' + v + '`' for v in item['asset_ids']) or 'Native manifest primitive'}. {item['implementation']} |")
    lines += ['', '## Progression', '', '| Stage | Completion requirement | Returning-player observation |', '| --- | --- | --- |']
    for row in manifest['weather_states']:
        lines.append(f"| {row['stage']}: {row['name']} | {' + '.join(row['all_completed'])} | {row['description']} |")
    lines += ['', '## Canonical puzzle bindings', '',
        '- P07 requires P06. Match eight initialed bowls and the unsigned square-repaired ninth bowl to the cloth. Set serving tally 9 and compare against official 8. The pantry token half and Venn note are awarded once. The spoon lifts and lowers once; reduced motion uses held poses and a preserved description.',
        '- P09 requires both P07 and P08. Fit both service-token halves, retain the official eight, append +1 / VENN / present and use the three-cut seal. Tokens are consumed together only on a valid commit. The duplicate board reads “Eight retained. One witnessing.” Preserve this before condensation can obscure the room copy.',
        '- Nora’s physical repaired cup belongs in R06 for P08/P22. The kitchen supplies her provisioning repair sketch and readable evidence, not a second physical quest cup.',
        '- Atmospheric documents remain inspectable without becoming additional mandatory puzzles. Every actual visible map needs its own readable close-up; map inventory is explicit in the manifest.', '',
        '## Measured assets', '', '| Asset | Size | Alpha range | Render source x/y/w/h | Role |', '| --- | --- | --- | --- | --- |']
    for ident, art in assets.items():
        lines.append(f"| `{ident}` | {art['width']} × {art['height']} | {art['alpha_range'][0]}–{art['alpha_range'][1]} | {','.join(map(str, art['render_region_px']))} | {art['role']} |")
    lines += ['', '## Delivery limits', '',
        ('All bounded R05 art roles have measured files or deliberate reusable/native representations.' if not manifest['missing_art'] else 'Missing art: ' + ', '.join(manifest['missing_art'])), '',
        'File integrity and static composition are checked independently of engine behavior. The room scene, P07/P09 controls, evidence and inventory persistence, recorded sounds, reduced-motion behavior, iPad/browser operation and native exports still require implementation and testing.', '']
    (ROOT / 'docs/kitchen-inventory.md').write_text('\n'.join(lines))


if __name__ == '__main__':
    main()
