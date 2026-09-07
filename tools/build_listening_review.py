"""Build a local R04 art review and SVG composition proofs.

This lays out existing assets. It never edits generated raster source files and
does not load, execute or validate Godot gameplay. Run after the R04 manifest and
authored vector assets have been built.
"""
from __future__ import annotations

import argparse
import html
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art/listening-review/composed"
WIDTH, HEIGHT = 1448, 1086
NS = 'xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"'


def esc(value):
    return html.escape(str(value), quote=True)


def svg_wrap(body, width=WIDTH, height=HEIGHT):
    return f'<svg {NS} width="{width}" height="{height}" viewBox="0 0 {width} {height}">{body}</svg>'


def rect_markup(rect, fill, **attrs):
    x, y, w, h = rect
    more = " ".join(f'{k.replace("_", "-")}="{esc(v)}"' for k, v in attrs.items())
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" {more}/>'


def text_markup(x, y, text, size=30, color="#e9dfc7", **attrs):
    more = " ".join(f'{k.replace("_", "-")}="{esc(v)}"' for k, v in attrs.items())
    return f'<text x="{x}" y="{y}" fill="{color}" font-family="DejaVu Sans" font-size="{size}" {more}>{esc(text)}</text>'


class Review:
    def __init__(self, manifest_path):
        self.manifest = json.loads(manifest_path.read_text())
        self.spec = json.loads((ROOT / "assets/listening/authored-spec.json").read_text())
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
            if key == "weather_min" and state["weather"] < value:
                return False
            if key == "weather_max" and state["weather"] > value:
                return False
            if key == "recorder_slot":
                if value >= len(state["bands"]):
                    return False
            elif key == "recorder_band":
                slot = when.get("recorder_slot", 0)
                if slot >= len(state["bands"]) or state["bands"][slot] != value:
                    return False
            elif key not in ("weather_min", "weather_max") and state.get(key) != value:
                return False
        return True

    def weather_id(self, stage):
        for asset_id in self.assets:
            if asset_id.startswith(f"r04_weather_{stage:02d}_"):
                return asset_id
        raise KeyError(f"Weather stage {stage}")

    def room(self, state, inline=False, all_layers=False):
        body = []
        for i, layer in enumerate(sorted(self.manifest["room_layers"], key=lambda x: x.get("z", 0))):
            if not all_layers and not self.active(layer.get("when"), state):
                continue
            kind = layer.get("kind", "image")
            attrs = f' data-when="{esc(json.dumps(layer.get("when", {})))}"' if all_layers else ""
            body.append(f'<g id="layer-{esc(layer["id"])}"{attrs}>')
            if layer.get("clip_rects"):
                body.append(f'<defs><clipPath id="clip-{i}">')
                body.extend(rect_markup(r, "white") for r in layer["clip_rects"])
                body.append(f'</clipPath></defs><g clip-path="url(#clip-{i})">')
            if kind == "rect":
                body.append(rect_markup(layer["target_rect"], layer["fill"], opacity=layer.get("opacity", 1)))
            elif kind == "path":
                body.append(f'<path d="{esc(layer["svg_path"])}" fill="{layer.get("fill", "none")}" '
                            f'stroke="{layer.get("stroke", "none")}" stroke-width="{layer.get("stroke_width", 1)}" '
                            f'opacity="{layer.get("opacity", 1)}"/>')
            elif kind == "image":
                asset_id = layer["asset_id"]
                if asset_id == "@rain":
                    asset_id = "r04_rain_0"
                if asset_id == "@weather":
                    asset_id = self.weather_id(state["weather"])
                    if all_layers:
                        body.append('<g id="weather-image">')
                body.append(self.image(asset_id, layer["target_rect"], layer.get("source_region_px"), inline))
                if layer["asset_id"] == "@weather" and all_layers:
                    body.append('</g>')
            else:
                raise ValueError(f"Unsupported room layer kind {kind}")
            if layer.get("clip_rects"):
                body.append('</g>')
            body.append('</g>')
        return svg_wrap("".join(body))

    def document(self, asset_id, inline=False):
        a = self.assets[asset_id]
        return svg_wrap(self.image(asset_id, inline=inline), a["width"], a["height"])

    def panel_background(self, inline=False):
        return self.image("r04_channel_panel_blank", [0, 0, WIDTH, HEIGHT], inline=inline)

    def inspections(self, inline=False):
        result = {}
        panels = self.spec.get("panels", {})
        if "P02" in panels:
            p = panels["P02"]
            for pose, bands in [("empty", []), ("partial", ["C"]), ("assembled", ["C", "A", "B"])]:
                body = self.panel_background(inline) + self.image(p["overlay"], inline=inline)
                ax, ay, aw, ah = p["assembly_rect"]
                scale = p["assembly_uniform_scale"]
                assembly = self.image(p["guides_asset"], p["guides_rect"], inline=inline)
                for slot, band in enumerate(bands):
                    bx, by = p["band_local_origins"][slot]
                    assembly += self.image(p["band_face_asset"], [bx, by, 180, 200], inline=inline)
                    assembly += self.image(f"r04_band_{band.lower()}_step_0", [bx, by, 180, 300], inline=inline)
                body += f'<g transform="translate({ax},{ay}) scale({scale})">{assembly}</g>'
                for ctl in p.get("band_selection_controls", []):
                    body += self.image(ctl["asset_id"], ctl["rect"], inline=inline)
                for ctl in p["rotate_controls"]:
                    body += self.image(ctl["asset_id"], ctl["rect"], inline=inline)
                ctl = p["needle_control"]
                body += self.image(ctl["states"]["lowered" if pose == "assembled" else "raised"], ctl["rect"], inline=inline)
                ctl = p["play_control"]
                body += self.image(ctl["asset_id"], ctl["rect"], inline=inline)
                result["p02_" + pose] = svg_wrap(body)
            readout = p.get("successful_playback")
            if readout:
                result["p02_playback"] = svg_wrap(self.panel_background(inline) + self.image(readout["asset_id"], readout["rect"], inline=inline))
        if "P17" in panels:
            p = panels["P17"]
            for pose, solved in [("unaligned", False), ("aligned", True)]:
                body = self.panel_background(inline) + self.image(p["overlay"], inline=inline)
                for name, wave in self.spec["waveforms"].items():
                    ox, oy = wave["initial_origin"]
                    ox += wave["solution_shift_x"] if solved else 0
                    body += f'<defs><clipPath id="trace-{name}">{rect_markup(wave["clip_rect"], "white")}</clipPath></defs>'
                    body += f'<g clip-path="url(#trace-{name})">' + self.image("r04_waveform_" + name, [ox, oy, wave["width"], wave["height"]], inline=inline) + '</g>'
                    for ctl in p["controls"][name].values():
                        aid = ctl.get("asset_id") or ctl["states"]["idle"]
                        body += self.image(aid, ctl["rect"], inline=inline)
                result["p17_" + pose] = svg_wrap(body)
        if "P19" in panels:
            p = panels["P19"]
            values = {"motor": "off", "A": "closed", "B": "closed", "C": "open", "witness": "pressed"}
            for pose, indicator in [("connected", "on"), ("indicator_dark", "off")]:
                body = self.panel_background(inline) + self.image(p["overlay"], inline=inline)
                for key, ctl in p["controls"].items():
                    body += self.image(ctl["states"][values[key]], ctl["rect"], inline=inline)
                ctl = p["indicator"]
                body += self.image(ctl["states"][indicator], ctl["rect"], inline=inline)
                result["p19_" + pose] = svg_wrap(body)
            body = self.panel_background(inline) + self.image(p["questions_overlay"], inline=inline)
            for question in p["questions"]:
                body += self.image(question["asset_id"], question["rect"], inline=inline)
            result["p19_questions"] = svg_wrap(body)
        for asset_id, a in self.assets.items():
            if a["path"].startswith("assets/listening/documents/") or asset_id == "r04_workers_photo":
                result[asset_id] = self.document(asset_id, inline)
        return result

    def write_html(self, inspections):
        state = {"weather": 1, "bands": [], "lamp_on": True, "door_open": False, "drawer_open": False, "case_open": True, "case_contains_band": True}
        template = self.room(state, inline=True, all_layers=True)
        for stage in range(1, 9):
            self.used.add(self.weather_id(stage))
        payload = {}
        for aid in sorted(self.used):
            p = ROOT / self.assets[aid]["path"]
            payload[aid] = os.path.relpath(p, OUT)
        data = json.dumps({"assets": payload, "room": template, "inspections": inspections,
                           "weather": [self.weather_id(x) for x in range(1, 9)]}, separators=(",", ":"))
        page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>The Ninth Tide / Listening Room art review</title><style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#10232c;color:#e6dcc4}body{margin:0;padding:24px;max-width:1500px;margin:auto}h1{font-size:24px;font-weight:600;margin:0 0 8px}p{line-height:1.5;color:#c8d2cd;margin:8px 0 16px}label{display:inline-flex;align-items:center;gap:8px;margin:0 14px 10px 0}select,button{font:inherit;padding:9px;background:#203943;color:#eee5d2;border:1px solid #63797a;border-radius:3px}input{width:20px;height:20px}#room svg{display:block;width:100%;height:auto}#room{max-width:1158px;margin:auto;border:1px solid #42616b;background:#0c1b22}#inspection{display:none;max-width:1158px;margin:auto}#inspection svg{display:block;max-width:100%;height:auto;max-height:85vh;margin:auto}#label{font-size:14px}details{margin-top:20px}a{color:#c3dcd7}.controls{padding:12px 0;border-block:1px solid #39525b;margin:18px 0}.muted{font-size:14px;color:#b5c3be}
</style><h1>The Ninth Tide / Listening Room</h1><p>Art composition review. These controls select illustrations only. They do not complete puzzles, save progress or run the game.</p>
<p class="muted">Open this HTML from the repository checkout. Images use relative local paths; no server or network requests are required.</p><div class="controls"><label>View <select id="view"><option value="room">Room composition</option></select></label><label>Weather <select id="weather"></select></label><label>P02 arrangement <select id="bands"><option value="empty">Empty spindle</option><option value="partial">One band fitted</option><option value="assembled">Three bands fitted</option></select></label><br>
<label><input id="lamp_on" type="checkbox" checked>Task lamp lit</label><label><input id="door_open" type="checkbox">Door open</label><label><input id="drawer_open" type="checkbox">Drawer open</label><label><input id="case_open" type="checkbox" checked>Recording case open</label></div>
<p id="label" aria-live="polite"></p><div id="room"></div><div id="inspection"></div><details><summary>What this preview establishes</summary><p>Fixed room geometry, clipped exterior plates, independently selected recorder bands, and layered inspection graphics. Generated pose references have small shape differences; this composition uses one fixed mechanism. Tide IX retains the eighth weather appearance.</p><p>No Listening Room gameplay, recorded audio, browser export, iPad input or native-device behavior has been validated here. Timing traces are authored visual evidence pending synchronized voice recordings.</p></details>
<script>const DATA=__DATA__;
const E=id=>document.getElementById(id);const names=['Overcast / arrival and Tide I','Rain / Tide II','Storm / Tide III','Suspended rain / Tide IV','Upright sea / Tide V','Silent weather / Tide VI','Wrong bearing / Tide VII','Dark surface / Tide VIII and IX'];
function materialize(text){return text.replace(/__ASSET_([a-z0-9_]+)__/g,(_,id)=>DATA.assets[id]);}
E('room').innerHTML=materialize(DATA.room);for(let i=0;i<8;i++)E('weather').add(new Option(names[i],i+1));
for(const key of Object.keys(DATA.inspections))E('view').add(new Option(key.replace(/^r04_/,'').replaceAll('_',' '),key));
function state(){return {weather:Number(E('weather').value),bands:{empty:[],partial:['C'],assembled:['C','A','B']}[E('bands').value],lamp_on:E('lamp_on').checked,door_open:E('door_open').checked,drawer_open:E('drawer_open').checked,case_open:E('case_open').checked,case_contains_band:E('bands').value!=='assembled'};}
function active(when,s){for(const [k,v] of Object.entries(when)){if(k==='weather_min'&&s.weather<v)return false;if(k==='weather_max'&&s.weather>v)return false;if(k==='recorder_slot'&&v>=s.bands.length)return false;if(k==='recorder_band'&&s.bands[when.recorder_slot||0]!==v)return false;if(!['weather_min','weather_max','recorder_slot','recorder_band'].includes(k)&&s[k]!==v)return false;}return true;}
function update(){const s=state(),v=E('view').value;E('room').style.display=v==='room'?'block':'none';E('inspection').style.display=v==='room'?'none':'block';if(v!=='room'){E('inspection').innerHTML=materialize(DATA.inspections[v]);E('label').textContent='Inspection artwork / review only. Exact graphics are separate from generated textures.';return;}for(const g of E('room').querySelectorAll('[data-when]'))g.style.display=active(JSON.parse(g.dataset.when),s)?'inline':'none';const img=E('weather-image').querySelector('image');img.setAttributeNS('http://www.w3.org/1999/xlink','href',DATA.assets[DATA.weather[s.weather-1]]);E('label').textContent=names[s.weather-1]+' · '+E('bands').selectedOptions[0].text+' · arrangement and weather are independent';}
for(const control of document.querySelectorAll('select,input'))control.addEventListener('change',update);update();
</script></html>'''.replace('__DATA__', data)
        (OUT / "index.html").write_text(page)
        old_entry = OUT / "review.html"
        if old_entry.exists():
            old_entry.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=ROOT / "assets/listening/manifest.json")
    parser.add_argument("--skip-render", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    review = Review(args.manifest)
    early = {"weather": 1, "bands": [], "lamp_on": True, "door_open": False, "drawer_open": False, "case_open": True, "case_contains_band": True}
    late = dict(early, weather=8, bands=["C", "A", "B"], case_contains_band=False)
    open_state = dict(early, weather=3, bands=["C"], door_open=True, drawer_open=True)
    proofs = {"room_early": review.room(early), "room_late": review.room(late), "room_open_states": review.room(open_state)}
    proofs.update({k: v for k, v in review.inspections().items() if k.startswith(("p02_", "p17_", "p19_"))})
    for name, source in proofs.items():
        path = OUT / (name + ".svg")
        path.write_text(source)
        if not args.skip_render:
            target = path.with_suffix(".png")
            temporary = path.with_name(f"{name}.{os.getpid()}.tmp.png")
            subprocess.run(["inkscape", str(path), "--export-type=png", "--export-filename=" + str(temporary)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            # Read-only integrity check before exposing a freshly rendered proof.
            from PIL import Image
            with Image.open(temporary) as im:
                im.verify()
            temporary.replace(target)
    review.write_html(review.inspections(inline=True))
    print(f"Built local index.html and {len(proofs)} SVG composition proofs in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
