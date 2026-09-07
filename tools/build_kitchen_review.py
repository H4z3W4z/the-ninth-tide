"""Build the portable R05 Kitchen and Mess art gallery and composition proofs.

This renders authored SVG layouts using existing PNG source assets unchanged.
It is an art review, not a gameplay implementation or device validation.
"""
from __future__ import annotations

import argparse
import html
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art/kitchen-review/composed"
WIDTH, HEIGHT = 1448, 1086
NS = 'xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"'


def esc(value):
    return html.escape(str(value), quote=True)


def svg_wrap(body, width=WIDTH, height=HEIGHT):
    return f'<svg {NS} width="{width}" height="{height}" viewBox="0 0 {width} {height}">{body}</svg>'


def rect_markup(rect, fill, **attrs):
    x, y, w, h = rect
    more = " ".join(f'{k.replace("_", "-")}="{esc(v)}"' for k, v in attrs.items())
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{esc(fill)}" {more}/>'


def atomic_text(path, content):
    temporary = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    temporary.write_text(content)
    temporary.replace(path)


class Review:
    def __init__(self, manifest_path):
        self.manifest = json.loads(manifest_path.read_text())
        self.spec = json.loads((ROOT / "assets/kitchen/authored-spec.json").read_text())
        self.assets = self.manifest["assets"]
        self.used = set()

    def image(self, asset_id, target=None, source=None, inline=False):
        a = self.assets[asset_id]
        self.used.add(asset_id)
        target = target or [0, 0, a["width"], a["height"]]
        source = source or [0, 0, a["width"], a["height"]]
        x, y, w, h = target
        sx, sy, sw, sh = source
        ref = f"__ASSET_{asset_id}__" if inline else os.path.relpath(ROOT / a["path"], OUT)
        return (f'<svg x="{x}" y="{y}" width="{w}" height="{h}" viewBox="{sx} {sy} {sw} {sh}" '
                f'preserveAspectRatio="none" overflow="hidden"><image x="0" y="0" width="{a["width"]}" '
                f'height="{a["height"]}" xlink:href="{esc(ref)}"/></svg>')

    @staticmethod
    def active(when, state):
        for key, value in (when or {}).items():
            if key == "weather_min":
                if state["weather_stage"] < value:
                    return False
            elif key == "weather_max":
                if state["weather_stage"] > value:
                    return False
            elif state.get(key) != value:
                return False
        return True

    def weather_id(self, stage):
        for entry in self.manifest.get("weather_states", []):
            if entry["stage"] == stage:
                return entry["asset_id"]
        for asset_id in self.assets:
            if asset_id.startswith(f"r05_weather_{stage:02d}_"):
                return asset_id
        raise KeyError(f"Missing weather stage {stage}")

    def layers(self, layers, state, inline=False, all_layers=False, prefix="layer"):
        body = []
        for i, layer in enumerate(sorted(layers, key=lambda x: x.get("z", 0))):
            if not all_layers and not self.active(layer.get("when"), state):
                continue
            attrs = f' data-when="{esc(json.dumps(layer.get("when", {})))}"' if all_layers else ""
            body.append(f'<g id="{prefix}-{esc(layer.get("id", i))}" opacity="{layer.get("opacity", 1)}"{attrs}>')
            clips = layer.get("clip_rects", [])
            if clips:
                body.append(f'<defs><clipPath id="{prefix}-clip-{i}">')
                body.extend(rect_markup(r, "white") for r in clips)
                body.append(f'</clipPath></defs><g clip-path="url(#{prefix}-clip-{i})">')
            kind = layer.get("kind", "image")
            if kind == "rect":
                body.append(rect_markup(layer["target_rect"], layer["fill"]))
            elif kind == "path":
                body.append(f'<path d="{esc(layer["svg_path"])}" fill="{esc(layer.get("fill", "none"))}" '
                            f'stroke="{esc(layer.get("stroke", "none"))}" stroke-width="{layer.get("stroke_width", 1)}"/>')
            elif kind == "image":
                asset_id = layer["asset_id"]
                if asset_id == "@weather":
                    asset_id = self.weather_id(state["weather_stage"])
                    if all_layers:
                        body.append('<g data-weather-image="true">')
                body.append(self.image(asset_id, layer.get("target_rect", layer.get("rect")), layer.get("source_region_px"), inline))
                if layer["asset_id"] == "@weather" and all_layers:
                    body.append('</g>')
            else:
                raise ValueError(f"Unsupported layer kind {kind}")
            if clips:
                body.append('</g>')
            body.append('</g>')
        return "".join(body)

    def room(self, state, inline=False, all_layers=False):
        return svg_wrap(self.layers(self.manifest["room_layers"], state, inline, all_layers))

    def inspections(self, inline=False):
        result = {}
        for puzzle, panel in self.spec.get("panels", {}).items():
            for name, pose in panel.get("review_poses", panel.get("views", {})).items():
                canvas = pose.get("canvas", panel.get("canvas", [WIDTH, HEIGHT]))
                body = self.layers(pose["layers"], pose.get("state", {}), inline, prefix=puzzle.lower()+name)
                result[puzzle.lower() + "_" + name] = svg_wrap(body, *canvas)
        for asset_id, a in self.assets.items():
            if any(f"/{folder}/" in a["path"] for folder in ("documents", "maps", "closeups")):
                result[asset_id] = svg_wrap(self.image(asset_id, inline=inline), a["width"], a["height"])
            elif a["path"].startswith("assets/kitchen/props/"):
                region = a.get("render_region_px", [0, 0, a["width"], a["height"]])
                _, _, w, h = region
                background = rect_markup([0, 0, w, h], "#71857f")
                result[asset_id] = svg_wrap(background + self.image(asset_id, [0, 0, w, h], region, inline), w, h)
        return result

    def write_html(self, inspections):
        template = self.room(base_state(), inline=True, all_layers=True)
        weather = {}
        for stage in range(2, 9):
            try:
                aid = self.weather_id(stage)
            except KeyError:
                continue
            self.used.add(aid)
            weather[str(stage)] = aid
        paths = {aid: os.path.relpath(ROOT / self.assets[aid]["path"], OUT) for aid in sorted(self.used)}
        data = json.dumps({"assets": paths, "room": template, "inspections": inspections, "weather": weather}, separators=(",", ":"))
        page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>The Ninth Tide / Kitchen and Mess art review</title><style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#10232c;color:#e6dcc4}body{margin:0;padding:24px;max-width:1500px;margin:auto}h1{font-size:24px;font-weight:600;margin:0 0 8px}p{line-height:1.5;color:#c8d2cd;margin:8px 0 16px}label{display:inline-flex;align-items:center;gap:8px;margin:0 14px 10px 0}select,button{font:inherit;padding:9px;background:#203943;color:#eee5d2;border:1px solid #63797a;border-radius:3px;min-height:44px}input{width:22px;height:22px}#room svg{display:block;width:100%;height:auto}#room{max-width:1158px;margin:auto;border:1px solid #42616b;background:#0c1b22}#inspection{display:none;max-width:1158px;margin:auto}#inspection svg{display:block;max-width:100%;height:auto;max-height:85vh;margin:auto}#label{font-size:14px}details{margin-top:20px}a{color:#c3dcd7}.controls{padding:12px 0;border-block:1px solid #39525b;margin:18px 0}.muted{font-size:14px;color:#b5c3be}
</style><h1>The Ninth Tide / Kitchen and Mess</h1><p>Art composition review. These controls select illustrations only. They do not solve puzzles, save progress or run the game.</p>
<p class="muted">Open this HTML from its repository checkout. Images use relative local paths; no server is required.</p><div class="controls"><label>View <select id="view"><option value="room">Room composition</option></select></label><label>Weather <select id="weather_stage"></select></label><br>
<label><input id="bowls_arranged" type="checkbox">P07 bowls arranged</label><label><input id="p07_complete" type="checkbox">P07 reveal</label><label><input id="pantry_drawer_open" type="checkbox">Pantry drawer open</label><label><input id="pantry_token_in_drawer" type="checkbox" checked>Pantry token present</label><label><input id="spoon_lifted" type="checkbox">Spoon lifted pose</label><br><label><input id="p09_complete" type="checkbox">P09 reveal</label><label><input id="service_door_open" type="checkbox">Service access open</label><label><input id="duplicate_board_condensed" type="checkbox">Duplicate condensation</label></div>
<p id="label" aria-live="polite"></p><div id="room"></div><div id="inspection"></div><details><summary>What this review establishes</summary><p>Fixed room geometry, independent puzzle arrangements, and readable inspection art. R05 first opens at Tide II. Weather follows milestones in the game; these manual choices are only review controls. Tide IX retains appearance eight.</p><p>The spoon pose represents a brief authored event after P07, with a reduced-motion still equivalent. It does not imply continuous idle movement. P09's duplicate-board evidence must be copied before condensation appears. All inspected evidence remains available in the notebook.</p><p>No R05 gameplay, recorded audio, Godot export, iPad input or native-device behavior has been validated here.</p></details>
<script>const DATA=__DATA__;
const E=id=>document.getElementById(id);const names={2:'Rain / Tide II',3:'Storm / Tide III',4:'Suspended rain / Tide IV',5:'Upright sea / Tide V',6:'Silent weather / Tide VI',7:'Wrong bearing / Tide VII',8:'Dark surface / Tide VIII and IX'};
function materialize(text){return text.replace(/__ASSET_([a-z0-9_]+)__/g,(_,id)=>DATA.assets[id]);}
E('room').innerHTML=materialize(DATA.room);for(let i=2;i<=8;i++)E('weather_stage').add(new Option(names[i],i));
for(const key of Object.keys(DATA.inspections))E('view').add(new Option(key.replace(/^r05_/,'').replaceAll('_',' '),key));
function state(){const s={weather_stage:Number(E('weather_stage').value)};s.weather=s.weather_stage;for(const el of document.querySelectorAll('input'))s[el.id]=el.checked;s.pantry_token_in_drawer=s.p07_complete&&!s.p09_complete&&s.pantry_token_in_drawer;s.spoon_lifted=s.p07_complete&&s.spoon_lifted;s.duplicate_board_condensed=s.p09_complete&&s.duplicate_board_condensed;return s;}
function active(when,s){for(const[k,v]of Object.entries(when)){if(k==='weather_min'){if(s.weather_stage<v)return false;}else if(k==='weather_max'){if(s.weather_stage>v)return false;}else if(s[k]!==v)return false;}return true;}
function update(){const s=state(),v=E('view').value;E('spoon_lifted').disabled=!s.p07_complete;E('duplicate_board_condensed').disabled=!s.p09_complete;E('room').style.display=v==='room'?'block':'none';E('inspection').style.display=v==='room'?'none':'block';if(v!=='room'){E('inspection').innerHTML=materialize(DATA.inspections[v]);E('label').textContent='Inspection artwork / review only. Exact text and diagrams are separate from generated textures.';return;}for(const g of E('room').querySelectorAll('[data-when]'))g.style.display=active(JSON.parse(g.dataset.when),s)?'inline':'none';for(const wi of E('room').querySelectorAll('[data-weather-image]'))if(DATA.weather[s.weather_stage])wi.querySelector('image').setAttributeNS('http://www.w3.org/1999/xlink','href',DATA.assets[DATA.weather[s.weather_stage]]);E('label').textContent=names[s.weather_stage]+' · puzzle arrangement and weather are independently selected art states';}
for(const control of document.querySelectorAll('select,input'))control.addEventListener('change',update);update();
</script></html>'''.replace('__DATA__', data)
        atomic_text(OUT / "index.html", page)


def base_state():
    return dict(weather_stage=2, weather=2, bowls_arranged=False, p07_complete=False,
                pantry_drawer_open=False, pantry_token_in_drawer=True, spoon_lifted=False, p09_complete=False,
                service_door_open=False, duplicate_board_condensed=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=ROOT / "assets/kitchen/manifest.json")
    parser.add_argument("--skip-render", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    review = Review(args.manifest)
    early = base_state()
    late = dict(early, weather_stage=8, weather=8, bowls_arranged=True, p07_complete=True, p09_complete=True, pantry_token_in_drawer=False)
    opened = dict(late, weather_stage=3, weather=3, pantry_drawer_open=True, service_door_open=True)
    anomaly = dict(early, bowls_arranged=True, p07_complete=True, pantry_drawer_open=True, spoon_lifted=True)
    proofs = {"room_early": review.room(early), "room_late": review.room(late),
              "room_open_states": review.room(opened), "room_local_anomaly": review.room(anomaly)}
    proofs.update({k: v for k, v in review.inspections().items() if k.startswith(("p07_", "p09_"))})
    for name, source in proofs.items():
        path = OUT / (name + ".svg")
        atomic_text(path, source)
        if not args.skip_render:
            temporary = path.with_name(f"{name}.{os.getpid()}.tmp.png")
            try:
                subprocess.run(["inkscape", str(path), "--export-type=png", "--export-filename=" + str(temporary)],
                               check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                from PIL import Image
                with Image.open(temporary) as im:
                    im.verify()
                temporary.replace(path.with_suffix(".png"))
            finally:
                temporary.unlink(missing_ok=True)
    review.write_html(review.inspections(inline=True))
    print(f"Built local index.html and {len(proofs)} SVG composition proofs in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
