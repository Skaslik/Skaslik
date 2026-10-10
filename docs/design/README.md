# docs/design — the agreed UI for «МС»

The source of truth for how the app looks and behaves. It was made in Claude as a design system plus a clickable prototype, modelled on You&Me (RuStore `keller.youandme`): dark cards, monospace facts, one colour per partner, five tabs. The identity is the couple's own: the icon's monogram, a cosy room with a candle and a Basenji, and a warm palette.

**Start with `IMPLEMENTATION.md`.** It is the build spec, phase by phase.

| Path | What it is |
|---|---|
| `IMPLEMENTATION.md` | Build spec for Flutter: packages, phases, geometry, data gaps in `core/`, acceptance |
| `brand-book.md` | Brand book (RU): principles, voice, colour, type, spacing, motion, icons, logo |
| `room.md` | The home scene: objects, meanings, candle behaviour, weather (RU) |
| `screens.md` | Tabs and what lives where; old routes → new (RU) |
| `decisions.md` | 17 open choices with the proposed defaults (RU) |
| `tokens.json` | **Design tokens, the source.** Colours for themes `evening` (default) and `day`, type, spacing, radius, shadow |
| `tokens.css` | The same tokens as CSS variables (used by the reference previews) |
| `flutter/ms_tokens.dart` | Generated Dart mirror: `MsPalette.evening/day`, `MsSpace`, `MsRadius`, `MsText`, `MsThemeExtension`, `context.ms` |
| `tools/gen_dart.py` | Regenerates `flutter/ms_tokens.dart` from `tokens.json` |
| `tools/room_layers.py` | Regenerates `assets/room/*.svg` from `tokens.json` |
| `components/*.md` | Per-component guidelines (RU) |
| `screenshots/*.png` | Rendered screens and components, `_evening` and `_day` |
| `reference-web/previews/*.html` | The same screens as HTML/CSS. Open them in a browser; they work offline. Exact paddings, radii and sizes |
| `reference-web/bundle.css`, `bundle.js` | Component CSS and the scene/barcode drawing code behind the previews |
| `reference-web/prototype/Main.dc.html` | The clickable prototype's source. Its `renderVals()` holds every interaction. It only runs inside Claude's canvas, so read it as a spec |
| `assets/fonts/` | Onest, IBM Plex Mono, PT Serif — static TTF with Cyrillic and ₽, plus the OFL licences |
| `assets/logo/` | `ms-icon.png` (full icon), `ms-monogram.png` (adaptive foreground) — from `mipmap-*` |
| `assets/room/` | Layered room scene SVGs (viewBox 390×440, colours resolved per theme, ready for flutter_svg) |

The screenshots show a phone frame and a fake status bar for presentation only. The app uses the real system status bar.
