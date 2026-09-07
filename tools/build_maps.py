"""Author all map evidence from shared vector geometry; export using Inkscape."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps'
INK, PAPER = '#243c46', '#ded0ad'

def text(x, y, s, size=25):
    return f'<text x="{x}" y="{y}" font-family="DejaVu Sans" font-size="{size}" fill="{INK}">{s}</text>'

def save(name, body, width=1200, height=900):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{body}</svg>'
    p = OUT / f'{name}.svg'
    p.write_text(svg)
    subprocess.run(['inkscape', str(p), '--export-type=png', f'--export-filename={p.with_suffix(".png")}'], check=True, stdout=subprocess.DEVNULL)

def cross(x, y):
    return f'<path d="M{x-24} {y}h48 M{x} {y-24}v48" stroke="{INK}" stroke-width="3"/><circle cx="{x}" cy="{y}" r="11" fill="none" stroke="{INK}" stroke-width="2"/>'

def north():
    return f'<path d="M1080 160V85l-13 24m13-24 13 24" fill="none" stroke="{INK}" stroke-width="4"/>' + text(1070, 65, 'N', 30)

def coast():
    b = ''
    for offset in [0, 22, 47, 80]:
        b += f'<path transform="translate({offset},0)" d="M180 110C270 195 220 270 300 330S400 420 350 480S280 620 380 670S410 780 430 840" fill="none" stroke="{INK}" stroke-width="{3 if offset==0 else 1.5}"/>'
    for x,y,n in [(640,280,'12'),(760,375,'18'),(680,690,'9'),(1020,790,'24')]:
        b += text(x,y,n,23)
    return b

def paper():
    return f'<rect x="2" y="2" width="1196" height="896" rx="6" fill="{PAPER}" stroke="{INK}" stroke-width="4"/><rect x="24" y="24" width="1152" height="852" fill="none" stroke="{INK}"/>'

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    curve = '<path d="M500 200C590 190 640 300 680 340S760 350 810 420S880 510 960 550L1040 566" fill="none" stroke="#813f30" stroke-width="7"/>'
    sheet = paper() + text(55,65,'GREYWAKE / TIDE SURVEY',34) + text(660,65,'17 OCT 1924',28) + north() + coast() + cross(310,240) + text(240,200,'LIGHTHOUSE',22) + cross(540,650) + text(470,710,'SURVEY POST',22) + cross(795,235) + text(720,200,'SOUNDING BUOY',22) + curve + text(530,820,'Observed trace / keep registration marks aligned',23)
    save('tide_sheet', sheet)
    seams = ['0,0 1200,0 1200,300 1040,300 1000,280 950,325 800,300 650,318 580,280 490,300 310,300 250,320 190,280 100,300 0,300',
             '0,300 100,300 190,280 250,320 310,300 490,300 580,280 650,318 800,300 950,325 1000,280 1040,300 1200,300 1200,600 1080,600 1010,623 960,580 820,600 700,600 640,580 570,620 450,600 330,600 260,580 170,620 80,600 0,600',
             '0,600 80,600 170,620 260,580 330,600 450,600 570,620 640,580 700,600 820,600 960,580 1010,623 1080,600 1200,600 1200,900 0,900']
    for i, points in enumerate(seams):
        save(f'tide_fragment_{i}', f'<defs><clipPath id="piece"><polygon points="{points}"/></clipPath></defs><g clip-path="url(#piece)">{sheet}</g><polygon points="{points}" fill="none" stroke="{INK}" stroke-width="3"/>')
    for day in [16,17]:
        overlay = f'<rect x="10" y="10" width="1180" height="880" fill="#eff1de" fill-opacity="0.22" stroke="{INK}" stroke-width="3"/>'
        overlay += text(55,115,'REGISTRATION / INTERVAL REFERENCE',28) + text(660,65,f'{day} OCT 1924',28) + north() + cross(310,240)
        for i in range(4):
            y = 230+i*130
            overlay += f'<rect x="875" y="{y}" width="180" height="130" fill="none" stroke="{INK}" stroke-width="2"/>' + text(1080,y+80,str(i+1),38)
        overlay += f'<path d="M960 230V750" stroke="{INK}" stroke-width="3" stroke-dasharray="10 8"/>' + text(875,800,'TRANSECT',25)
        save(f'tide_reference_{day}',overlay)
    save('tide_example', paper()+text(80,110,'HOW TO READ A COMPOSITE',38)+text(80,180,'Match the cross, north arrow, and date.',30)+text(80,240,'The red trace crosses the marked transect.',30)+text(80,300,'Read the interval band at that crossing.',30)+'<rect x="230" y="410" width="640" height="320" fill="none" stroke="#243c46" stroke-width="4"/><path d="M230 570H870M640 410V730" stroke="#243c46" stroke-width="3" stroke-dasharray="12 10"/><path d="M300 650C450 650 590 510 780 485" fill="none" stroke="#813f30" stroke-width="8"/>'+text(905,510,'6',45)+text(905,680,'7',45)+text(80,825,'Example only: this crossing reads 6.',30))
    for late in [False, True]:
        body = paper()+text(60,90,'GREYWAKE SOUND',42)+text(60,145,'COASTAL SURVEY / 1924',27)+f'<path d="M210 200C350 310 170 400 320 510S440 680 330 790" fill="#b2bea4" stroke="{INK}" stroke-width="4"/>'+coast()
        lx,ly=(875,390) if late else (610,290)
        body += f'<path d="M{lx-12} {ly}l5-60h14l5 60z M{lx-18} {ly-60}h36" fill="{INK}" stroke="{INK}" stroke-width="4"/>'+text(lx-65,ly+38,'LIGHTHOUSE',20)
        body += text(650,560,'GREYWAKE STATION',24)+f'<rect x="650" y="580" width="130" height="50" fill="none" stroke="{INK}" stroke-width="4"/>'+text(520,735,'Shoals: keep west of the bell.',25)+text(520,790,'Venn: soundings checked twice.',25)+north()
        save('office_survey_shifted' if late else 'office_survey',body)
    print('Authored 9 map PNGs with matching SVG sources')

if __name__ == '__main__': main()
