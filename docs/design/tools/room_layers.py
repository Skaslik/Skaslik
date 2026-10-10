"""Usage: python3 room_layers.py [out_dir]
Export the room scene as layered SVGs with resolved colors (flutter_svg-friendly: no CSS, no vars).
All layers share one coordinate space: viewBox 0 0 390 440. Stack them in this order:
back -> sky -> weather -> front -> dog -> candle body -> flame/smoke (+ glow & vignette drawn in Flutter)."""
import json, re, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
tok = json.load(open(os.path.join(HERE, '..', 'tokens.json'), encoding='utf-8'))
themes = [t['id'] for t in tok['color']['themes']]
def color(name, th):
    for t in tok['color']['tokens']:
        if t['name'] == name:
            v = t['value']
            return v if isinstance(v, str) else v.get(th, v[themes[0]])
    raise KeyError(name)

def rgba_split(c):
    m = re.match(r'rgba\(([^)]+)\)', c)
    if not m: return c, None
    r, g, b, a = [x.strip() for x in m.group(1).split(',')]
    return '#%02x%02x%02x' % (int(r), int(g), int(b)), a

CLS = {  # class -> (kind, token, extra)
 's-wall': ('fill','scene-wall'), 's-wall-low': ('fill','scene-wall-low'), 's-floor': ('fill','scene-floor'), 's-rug': ('fill','scene-rug'),
 's-wood': ('fill','scene-wood'), 's-wood-dark': ('fill','scene-wood-dark'), 's-curtain': ('fill','scene-curtain'),
 's-curtain-shade': ('stroke','scene-curtain-shade', ' stroke-width="2.5" stroke-linecap="round" fill="none"'),
 's-fabric': ('fill','scene-fabric'), 's-fabric-shade': ('fill','scene-fabric-shade'), 's-fabric-light': ('fill','scene-fabric-light'),
 's-fabric-line': ('stroke','scene-fabric-shade', ' stroke-width="3" stroke-linecap="round" fill="none"'),
 's-plant': ('fill','scene-plant'), 's-pot': ('fill','scene-pot'), 's-shadow': ('fill','scene-shadow'),
 'w-mark': ('fill','weather-mark'), 'w-cloud': ('fill','weather-mark', ' fill-opacity="0.55"'),
 'w-rain': ('stroke','weather-mark', ' stroke-width="1.2" stroke-linecap="round" stroke-opacity="0.7"'),
 'w-sun': ('fill','candle-flame'),
 'd-coat': ('fill','dog-coat'), 'd-shade': ('fill','dog-coat-shade'), 'd-white': ('fill','dog-white'), 'd-ear': ('fill','dog-ear'), 'd-eye': ('fill','dog-eye'),
 'd-coat-stroke': ('stroke','dog-coat', ' stroke-width="7" stroke-linecap="round" fill="none"'),
 'd-nose': ('fill','dog-coat', None, 'dog-coat-shade'),
 'd-line': ('stroke','dog-coat-shade', ' stroke-width="1.1" stroke-linecap="round" fill="none"'),
 'c-wax': ('fill','candle-wax'), 'c-flame': ('fill','candle-flame'), 'c-core': ('fill','flame-core'),
 'c-wick': ('stroke','dog-coat', ' stroke-width="1.4" stroke-linecap="round"'),
 'c-smoke': ('stroke','ink-faint', ' stroke-width="1.2" stroke-linecap="round" fill="none" stroke-opacity="0.6"'),
}
def resolve(markup, th):
    def rep(m):
        spec = CLS[m.group(1)]
        c, a = rgba_split(color(spec[1], th))
        if spec[0] == 'fill':
            s = f'fill="{c}"' + (f' fill-opacity="{a}"' if a else '')
        else:
            s = f'stroke="{c}"' + (f' stroke-opacity="{a}"' if a else '')
        if len(spec) > 2 and spec[2]: s += spec[2]
        if len(spec) > 3: s += f' stroke="{color(spec[3], th)}" stroke-width="0.6"'
        return s
    return re.sub(r'class="([a-z-]+)"', rep, markup)

def svg(body, extra_defs=''):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 390 440" width="390" height="440">'
            + (f'<defs>{extra_defs}</defs>' if extra_defs else '') + body + '</svg>\n')

BACK = '''<rect class="s-wall" x="0" y="0" width="390" height="440"/>
<rect class="s-wall-low" x="0" y="300" width="390" height="62"/>
<rect class="s-wood-dark" x="0" y="298" width="390" height="3"/>
<rect class="s-floor" x="0" y="362" width="390" height="78"/>
<rect class="s-wood-dark" x="0" y="360" width="390" height="4"/>
<ellipse class="s-rug" cx="292" cy="404" rx="118" ry="22"/>
<rect class="s-wood" x="282" y="70" width="70" height="70" rx="3"/>
<rect class="s-wood-dark" x="14" y="52" width="206" height="4" rx="2"/>
<circle class="s-wood" cx="14" cy="54" r="5"/>
<circle class="s-wood" cx="220" cy="54" r="5"/>
<rect class="s-wood" x="38" y="68" width="156" height="192" rx="5"/>'''

FRONT = '''<rect class="s-wood" x="48" y="180" width="136" height="6"/>
<rect class="s-wood" x="113" y="180" width="6" height="70"/>
<path class="s-curtain" d="M18 56 L50 56 C46 120 52 200 44 268 C38 300 30 300 22 304 C26 240 16 140 18 56 Z"/>
<path class="s-curtain-shade" d="M28 60 C27 130 30 220 27 300 M38 60 C38 140 42 220 37 296"/>
<path class="s-curtain" d="M184 56 L216 56 C218 140 208 240 212 304 C204 300 196 300 190 268 C182 200 188 120 184 56 Z"/>
<path class="s-curtain-shade" d="M206 60 C207 130 204 220 207 300 M196 60 C196 140 192 220 197 296"/>
<rect class="s-wood-dark" x="30" y="268" width="174" height="7" rx="2"/>
<rect class="s-wood" x="26" y="260" width="182" height="9" rx="2"/>
<path class="s-plant" d="M70 236 C60 226 56 214 60 204 C66 212 70 222 72 234 Z M74 234 C74 220 80 208 90 202 C90 214 84 226 76 236 Z M72 236 C66 228 54 226 46 230 C54 236 64 238 72 238 Z"/>
<path class="s-pot" d="M60 238 L84 238 L81 260 L63 260 Z"/>
<rect class="s-pot" x="58" y="235" width="28" height="5" rx="1.5"/>
<g transform="translate(206 212)">
<ellipse class="s-shadow" cx="89" cy="168" rx="96" ry="9"/>
<rect class="s-wood" x="16" y="150" width="9" height="18" rx="3"/>
<rect class="s-wood" x="153" y="150" width="9" height="18" rx="3"/>
<rect class="s-fabric" x="16" y="0" width="146" height="110" rx="34"/>
<path class="s-fabric-line" d="M30 18 C40 10 60 8 89 8 C118 8 138 10 148 18"/>
<rect class="s-fabric-shade" x="0" y="64" width="36" height="92" rx="17"/>
<rect class="s-fabric-shade" x="142" y="64" width="36" height="92" rx="17"/>
<rect class="s-fabric-light" x="26" y="92" width="126" height="40" rx="14"/>
<rect class="s-fabric-shade" x="10" y="126" width="158" height="28" rx="10"/>
</g>'''

DOG = '''<g transform="translate(230 221) scale(0.86)">
<path class="d-coat-stroke" d="M146 50 C136 40 140 26 152 26 C164 26 168 40 158 46 C152 50 146 46 148 40"/>
<circle class="d-white" cx="148.5" cy="40" r="3.6"/>
<path class="d-coat" d="M52 58 C50 46 52 36 58 30 C66 24 75 24 79 28 C86 35 96 38 110 38 C130 38 152 46 157 68 C160 86 150 104 124 104 L66 104 C50 104 42 94 42 80 C42 70 46 63 52 58 Z"/>
<path class="d-shade" d="M112 66 C130 60 150 68 152 84 C154 98 140 104 124 104 L104 104 C100 92 100 74 112 66 Z"/>
<path class="d-white" d="M92 98 C100 95 114 95 120 98 C124 100 124 105 119 106 L94 106 C89 106 88 100 92 98 Z"/>
<path class="d-shade" d="M50 88 L20 89 C13 89 12 96 18 97 L52 97 Z"/>
<path class="d-white" d="M49 42 C45 52 45 66 47 78 C49 90 55 99 65 102 C62 90 62 72 66 58 C61 54 57 49 56 42 Z"/>
<path class="d-white" d="M64 94 L22 95 C12 95 10 105 19 106 L66 106 C72 106 72 95 64 94 Z"/>
<path class="d-shade" d="M52 8 L56 -14 L64 6 Z"/>
<path class="d-coat" d="M78 24 C78 12 68 4 56 4 C46 4 38 9 33 15 C30 19 26 22 20 25 C14 28 9 31 9 35 C9 39 14 41 22 41 L40 42 C54 43 68 40 75 34 C78 31 79 28 78 24 Z"/>
<path class="d-coat" d="M60 10 L67 -17 C68 -20 71 -20 72 -17 L80 17 Z"/>
<path class="d-ear" d="M64.5 7 L68.5 -11 L75 13 Z"/>
<path class="d-white" d="M12.5 36.5 C13 40 18 41.6 26 42 C32 42.3 37 42 40 41 C36 39 30 37.6 24 36.2 C19 35.2 15 35 12.5 36.5 Z"/>
<path class="d-white" d="M15.5 30.2 C21 27.6 27 23.8 33 18.8 C34.2 17.8 35.6 18.6 34.8 19.8 C29.4 25.2 23 29.6 17.2 32.2 Z"/>
<ellipse class="d-nose" cx="10.5" cy="34" rx="3.4" ry="2.8"/>
<path class="d-eye" d="M39 23 C42 19.5 48 19 51 21.5 C48 24.6 42 25.2 39 23 Z"/>
<circle class="d-white" cx="47.4" cy="21.2" r="1"/>
<path class="d-line" d="M52 11 C55 9.4 58 9.6 60.5 11 M51 14.6 C54 13 57 13.2 59.6 14.4"/>
</g>'''

CANDLE_BODY = '''<g transform="translate(152 260)">
<ellipse class="s-shadow" cx="0" cy="0" rx="14" ry="2.5"/>
<rect class="c-wax" x="-8" y="-32" width="16" height="32" rx="3"/>
<ellipse class="c-wax" cx="0" cy="-32" rx="8" ry="2"/>
<line class="c-wick" x1="0" y1="-33" x2="0" y2="-38"/>
</g>'''
FLAME = '''<g transform="translate(152 260)">
<path class="c-flame" d="M0 -58 C5 -50 7 -44 5 -40 C3.5 -37 -3.5 -37 -5 -40 C-7 -44 -5 -50 0 -58 Z"/>
<path class="c-core" d="M0 -48 C2 -45 2.6 -42 1.6 -40.4 C1 -39.6 -1 -39.6 -1.6 -40.4 C-2.6 -42 -2 -45 0 -48 Z"/>
</g>'''
SMOKE = '''<g transform="translate(152 260)"><path class="c-smoke" d="M0 -40 C3 -45 -3 -49 0 -54 C3 -58 -1 -62 1 -66"/></g>'''

def sky(top, low):
    return svg('<rect x="48" y="78" width="136" height="172" rx="3" fill="url(#g)"/>',
               f'<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{low}"/></linearGradient>')

RAIN = ''.join(f'<line class="w-rain" x1="{a}" y1="{b}" x2="{a-4}" y2="{b+11}"/>' for a,b in
  [(62,168),(85,161),(122,214),(159,125),(70,198),(97,231),(134,142),(171,195),(109,159),(146,212),(178,123),(84,196),(121,229),(158,160),(59,223),(133,177),(170,230),(145,98)])
CLOUDS = '<ellipse class="w-cloud" cx="150" cy="98" rx="26" ry="9"/><ellipse class="w-cloud" cx="138" cy="92" rx="14" ry="9"/><ellipse class="w-cloud" cx="84" cy="236" rx="28" ry="8"/>'
CLOUDS_DAY = CLOUDS + '<ellipse class="w-cloud" cx="112" cy="128" rx="30" ry="9"/><ellipse class="w-cloud" cx="124" cy="121" rx="15" ry="9"/><ellipse class="w-cloud" cx="150" cy="214" rx="26" ry="8"/>'
STARS = ''.join(f'<circle class="w-mark" cx="{48+x*136:.1f}" cy="{78+y*172:.1f}" r="1.1"/>' for x,y in [(.12,.62),(.3,.8),(.55,.7),(.8,.6),(.66,.88),(.2,.92),(.9,.82)])
MOON = '<circle class="w-mark" cx="154" cy="104" r="11"/><circle fill="#18213b" cx="159" cy="100" r="10"/>'
SUN = '<circle class="w-sun" cx="154" cy="106" r="13"/>'
SNOW = ''.join(f'<circle class="w-mark" cx="{48+((i*41)%136)}" cy="{78+26+((i*29)%146)}" r="{1.2+(i%3)*0.5:.1f}"/>' for i in range(30))

out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'assets', 'room')
os.makedirs(out, exist_ok=True)
def w(name, s): open(os.path.join(out, name), 'w', encoding='utf-8').write(s)
for th in themes:
    w(f'room_back_{th}.svg', svg(resolve(BACK, th)))
    w(f'room_front_{th}.svg', svg(resolve(FRONT, th)))
    w(f'dog_{th}.svg', svg(resolve(DOG, th)))
    w(f'candle_body_{th}.svg', svg(resolve(CANDLE_BODY, th)))
    w(f'candle_flame_{th}.svg', svg(resolve(FLAME, th)))
    w(f'candle_smoke_{th}.svg', svg(resolve(SMOKE, th)))
w('sky_night.svg', sky(color('sky-night','evening'), color('sky-night-low','evening')))
w('sky_day.svg', sky(color('sky-day','evening'), color('sky-day-low','evening')))
w('sky_overcast.svg', sky(color('sky-overcast','evening'), color('sky-day-low','evening')))
w('weather_rain.svg', svg(resolve(CLOUDS + RAIN, 'evening')))
w('weather_clouds.svg', svg(resolve(CLOUDS_DAY, 'evening')))
w('weather_snow.svg', svg(resolve(CLOUDS + SNOW, 'evening')))
w('weather_clear_night.svg', svg(resolve(MOON + STARS, 'evening')))
w('weather_clear_day.svg', svg(resolve(SUN, 'evening')))
print(sorted(os.listdir(out)))
