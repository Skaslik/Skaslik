"""Usage: python3 gen_dart.py  -> regenerates ../flutter/ms_tokens.dart from ../tokens.json"""
import json, re
import os
HERE = os.path.dirname(os.path.abspath(__file__))
tok = json.load(open(os.path.join(HERE, '..', 'tokens.json'), encoding='utf-8'))
themes = [t['id'] for t in tok['color']['themes']]
def camel(n):
    p = re.split(r'[-.]', n)
    return p[0] + ''.join(x[:1].upper() + x[1:] for x in p[1:])
def to_argb(v):
    v = v.strip()
    m = re.fullmatch(r'#([0-9a-fA-F]{6})', v)
    if m: return '0xFF' + m.group(1).upper()
    m = re.fullmatch(r'rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)', v)
    if m:
        r, g, b, a = int(m[1]), int(m[2]), int(m[3]), float(m[4])
        return '0x%02X%02X%02X%02X' % (round(a * 255), r, g, b)
    raise ValueError(v)
def val(t, th):
    v = t['value']
    return v if isinstance(v, str) else v.get(th, v[themes[0]])
colors = tok['color']['tokens']
L = []
L.append('// GENERATED from docs/design/tokens.json — do not edit by hand; regenerate or edit tokens.json.')
L.append('// Starting point for ms_app/lib/design_system/. Run `dart format` + `flutter analyze` after copying.')
L.append("import 'package:flutter/material.dart';")
L.append('')
L.append('/// Every colour token of the МС design system. Two instances: [MsPalette.evening] (default) and [MsPalette.day].')
L.append('@immutable')
L.append('class MsPalette {')
for t in colors:
    L.append(f"  /// {t['usage']}")
    L.append(f"  final Color {camel(t['name'])};")
L.append('')
L.append('  const MsPalette({')
for t in colors: L.append(f"    required this.{camel(t['name'])},")
L.append('  });')
for th in themes:
    L.append('')
    L.append(f'  static const MsPalette {th} = MsPalette(')
    for t in colors: L.append(f"    {camel(t['name'])}: Color({to_argb(val(t, th))}),")
    L.append('  );')
L.append('}')
L.append('')
L.append('/// Spacing, radius and size tokens (logical px).')
L.append('abstract final class MsSpace {')
for t in tok['spacing']['tokens']:
    L.append(f"  /// {t['usage']}")
    L.append(f"  static const double {camel(t['name'])} = {float(t['value'].replace('px',''))};")
L.append('}')
L.append('')
L.append('abstract final class MsRadius {')
for t in tok['radius']['tokens']:
    L.append(f"  /// {t['usage']}")
    L.append(f"  static const double {camel(t['name'])} = {float(t['value'].replace('px',''))};")
L.append('}')
L.append('')
L.append("/// Font families — bundled as assets (see pubspec snippet in docs/design/IMPLEMENTATION.md).")
L.append('abstract final class MsFonts {')
L.append("  static const String sans = 'Onest';")
L.append("  static const String mono = 'IBMPlexMono';")
L.append("  static const String serif = 'PTSerif';")
L.append('}')
L.append('')
L.append('/// Text styles from tokens.json `type.groups`. Colour is applied by the theme / widget, not here.')
L.append('abstract final class MsText {')
fam = {'sans': 'MsFonts.sans', 'mono': 'MsFonts.mono', 'serif': 'MsFonts.serif'}
for g in tok['type']['groups']:
    for s in g['styles']:
        f = s.get('family', g['family'])
        size = float(s['fontSize'].replace('px', ''))
        lh = float(s['lineHeight'].replace('px', '')) / size
        args = [f'fontFamily: {fam[f]}', f'fontSize: {size}', f'height: {lh:.4f}', f"fontWeight: FontWeight.w{int(s['fontWeight'])}"]
        if 'letterSpacing' in s:
            ls = s['letterSpacing']
            if ls.endswith('em'): args.append(f'letterSpacing: {float(ls[:-2]) * size:.3f}')
        if s.get('fontStyle') == 'italic': args.append('fontStyle: FontStyle.italic')
        if f == 'mono': args.append('fontFeatures: [FontFeature.tabularFigures()]')
        L.append(f"  /// {s['usage']}")
        L.append(f"  static const TextStyle {camel(s['name'])} = TextStyle({', '.join(args)});")
L.append('}')
L.append('')
def shadow_dart(v):
    out = []
    for m in re.finditer(r'(-?[\d.]+)(?:px)?\s+(-?[\d.]+)(?:px)?\s+([\d.]+)(?:px)?(?:\s+(-?[\d.]+)(?:px)?)?\s+(rgba?\([^)]*\)|#[0-9a-fA-F]{6})', v):
        x, y, blur, spread, col = float(m[1]), float(m[2]), float(m[3]), float(m[4] or 0), m[5]
        out.append(f'BoxShadow(color: Color({to_argb(col)}), offset: Offset({x}, {y}), blurRadius: {blur}, spreadRadius: {spread})')
    return '[' + ', '.join(out) + ']'
shadows = tok.get('shadow', {}).get('tokens', [])
if shadows:
    L.append('/// Shadow tokens. Only two exist: the sheet over the room and the candle glow.')
    L.append('@immutable')
    L.append('class MsShadows {')
    for t in shadows:
        L.append(f"  /// {t['usage']}")
        L.append(f"  final List<BoxShadow> {camel(t['name'])};")
    L.append('')
    L.append('  const MsShadows({')
    for t in shadows: L.append(f"    required this.{camel(t['name'])},")
    L.append('  });')
    for th in themes:
        L.append('')
        L.append(f'  static const MsShadows {th} = MsShadows(')
        for t in shadows: L.append(f"    {camel(t['name'])}: {shadow_dart(val(t, th))},")
        L.append('  );')
    L.append('')
    L.append('  /// Shadows for a palette instance.')
    L.append('  static MsShadows of(MsPalette p) =>')
    L.append('      ' + ' : '.join(f'identical(p, MsPalette.{th}) ? {th}' for th in themes[1:]) + f' : {themes[0]};')
    L.append('}')
    L.append('')
L.append('/// Theme extension so widgets read tokens via `context.ms`.')
L.append('@immutable')
L.append('class MsThemeExtension extends ThemeExtension<MsThemeExtension> {')
L.append('  final MsPalette c;')
L.append('  const MsThemeExtension(this.c);')
L.append('')
L.append('  @override')
L.append('  MsThemeExtension copyWith({MsPalette? c}) => MsThemeExtension(c ?? this.c);')
L.append('')
L.append('  @override')
L.append('  MsThemeExtension lerp(covariant ThemeExtension<MsThemeExtension>? other, double t) =>')
L.append('      (other is MsThemeExtension && t >= 0.5) ? other : this;')
L.append('}')
L.append('')
L.append('extension MsThemeContext on BuildContext {')
L.append('  MsPalette get ms => Theme.of(this).extension<MsThemeExtension>()!.c;')
if shadows:
    L.append('  MsShadows get msShadows => MsShadows.of(ms);')
L.append('}')
open(os.path.join(HERE, '..', 'flutter', 'ms_tokens.dart'), 'w', encoding='utf-8').write('\n'.join(L) + '\n')
print(len(L))
