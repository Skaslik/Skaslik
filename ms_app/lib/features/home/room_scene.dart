/// The room: layered SVGs plus Flutter overlays on a 390 × 440 canvas
/// (IMPLEMENTATION Phase 3). Rendered at the screen width and clipped to
/// 430/440 of its height, 5 units off the top and the bottom.
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/candle/candle_controller.dart';
import '../../core/weather/weather.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';

/// Scene geometry in canvas units — the numbers of the spec, in one place.
abstract final class RoomGeo {
  static const double w = 390;
  static const double h = 440;
  static const double visibleH = 430;
  static const double crop = (h - visibleH) / 2;

  /// The «Сегодня» sheet starts here (screen y / scale).
  static const double sheetTop = 392;

  static const Offset glowCenter = Offset(152, 216);
  static const double glowR = 78;
  static const Offset flameOrigin = Offset(152, 223);
  static const Offset dogOrigin = Offset(357, 306);
  static const Rect logo = Rect.fromLTWH(288, 76, 58, 58);
  static const Offset weatherText = Offset(58, 93);
  static const Rect note = Rect.fromLTWH(218, 140, 64, 48);
  static const double noteAngle = -5 * math.pi / 180;
  static const Offset notePin = Offset(29, 2);
  static const double notePinD = 6;
  static const double noteTextTop = 16;
  static const double noteSignPadR = 6;
  static const Offset noteShadow = Offset(1.5, 2);
  static const double noteRadius = 2;

  // Hit areas.
  static const Rect window = Rect.fromLTWH(48, 78, 136, 172);
  static const Rect candle = Rect.fromLTWH(124, 183, 56, 84);
  static const Rect dog = Rect.fromLTWH(236, 201, 142, 112);
  static const Rect frame = Rect.fromLTWH(280, 68, 74, 74);

  // Vignette: radial, centre (0.42 w, 0.55 h), 0.55 → transparent,
  // 1.0 → sceneShadow, in the canvas's own (elliptic) box.
  static const Alignment vignetteCenter = Alignment(-0.16, 0.10);
  static const double vignetteR = 0.75;
  static const double vignetteClear = 0.55;

  // Weather text (PT Serif 34; Onest 12/16 w500; mono 8.5 +0.08em).
  static const double weatherCitySize = 8.5;
  static const double weatherCityOpacity = 0.85;
  static const double weatherLabelSize = 12;
  static const double weatherLabelH = 16 / 12;
  static const double weatherLabelGap = 2;
  static const double weatherCityGap = 1;
  static const double noteTextSize = 10;
  static const double noteTextH = 12 / 10;
  static const double noteSignSize = 9;
  static const double noteSignGap = 4;

  static const Duration flicker = Duration(milliseconds: 2400);
  static const Duration perk = Duration(milliseconds: 1100);
}

/// Real sky in the window — follows time and weather, not the app theme.
enum RoomSky { night, day, overcast }

/// What the window shows: sky, marks and (if any result ever) text.
@immutable
class RoomWeatherView {
  const RoomWeatherView({
    required this.sky,
    this.marks,
    this.temp,
    this.label,
    this.cityLine,
  });

  final RoomSky sky;

  /// `weather_*.svg` to overlay, or none.
  final String? marks;
  final String? temp;
  final String? label;

  /// «МОСКВА» or, when stale, «МОСКВА · В 18:40».
  final String? cityLine;

  bool get hasText => temp != null;

  /// The window for [w] (may be null: never fetched) at [now].
  static RoomWeatherView of({
    required WeatherNow? w,
    required bool daylight,
    required DateTime now,
    required String city,
    required String Function(DateTime) time,
  }) {
    final night = !daylight;
    final kind = w?.kind;
    final sky = night
        ? RoomSky.night
        : (kind == null || kind == WeatherKind.clear)
            ? RoomSky.day
            : RoomSky.overcast;
    final marks = switch (kind) {
      null => null,
      WeatherKind.clear =>
        night ? 'weather_clear_night.svg' : 'weather_clear_day.svg',
      WeatherKind.cloudy => 'weather_clouds.svg',
      WeatherKind.rain => 'weather_rain.svg',
      WeatherKind.snow => 'weather_snow.svg',
    };
    if (w == null) return RoomWeatherView(sky: sky);
    final cityLine = w.isStale(now)
        ? '$city · в ${time(w.fetchedAt)}'
        : city;
    return RoomWeatherView(
      sky: sky,
      marks: marks,
      temp: formatTemp(w.temp),
      label: w.label,
      cityLine: cityLine.toUpperCase(),
    );
  }
}

/// The partner's latest note on the wall.
@immutable
class RoomNote {
  const RoomNote({required this.text, required this.sign, required this.author});
  final String text;

  /// «С.» / «М.».
  final String sign;
  final MsAuthor author;
}

class RoomScene extends StatefulWidget {
  const RoomScene({
    super.key,
    required this.day,
    required this.weather,
    required this.candleLit,
    required this.candleLabel,
    this.note,
    required this.onWindow,
    required this.onCandleTap,
    required this.onCandleLongPress,
    required this.onDog,
    required this.onFrameTap,
    required this.onNote,
  });

  /// «День» theme layers; otherwise «Вечер».
  final bool day;
  final RoomWeatherView weather;
  final bool candleLit;

  /// Spoken state of the candle, e.g. «горит, зажгла София».
  final String candleLabel;
  final RoomNote? note;
  final VoidCallback onWindow;
  final VoidCallback onCandleTap;
  final VoidCallback onCandleLongPress;
  final VoidCallback onDog;
  final VoidCallback onFrameTap;
  final VoidCallback onNote;

  @override
  State<RoomScene> createState() => _RoomSceneState();
}

class _RoomSceneState extends State<RoomScene> with TickerProviderStateMixin {
  late final AnimationController _flicker =
      AnimationController(vsync: this, duration: RoomGeo.flicker);
  late final AnimationController _perk =
      AnimationController(vsync: this, duration: RoomGeo.perk);
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) == true;
    _syncFlicker();
  }

  @override
  void didUpdateWidget(RoomScene old) {
    super.didUpdateWidget(old);
    if (old.candleLit != widget.candleLit) _syncFlicker();
  }

  void _syncFlicker() {
    if (widget.candleLit && !_reduceMotion) {
      if (!_flicker.isAnimating) _flicker.repeat();
    } else {
      _flicker.stop();
      _flicker.value = 0;
    }
  }

  void _onDog() {
    if (!_reduceMotion) _perk.forward(from: 0);
    widget.onDog();
  }

  @override
  void dispose() {
    _flicker.dispose();
    _perk.dispose();
    super.dispose();
  }

  String get _theme => widget.day ? 'day' : 'evening';

  Widget _svg(String file) => SvgPicture.asset(
        'assets/room/$file',
        width: RoomGeo.w,
        height: RoomGeo.h,
        fit: BoxFit.fill,
        excludeFromSemantics: true,
      );

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final sky = switch (widget.weather.sky) {
      RoomSky.night => 'sky_night.svg',
      RoomSky.day => 'sky_day.svg',
      RoomSky.overcast => 'sky_overcast.svg',
    };
    final marks = widget.weather.marks;
    final canvas = SizedBox(
      width: RoomGeo.w,
      height: RoomGeo.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1–4: static room, cached in its own layer.
          RepaintBoundary(
            child: Stack(children: [
              _svg('room_back_$_theme.svg'),
              _svg(sky),
              if (marks != null) _svg(marks),
              _svg('room_front_$_theme.svg'),
            ]),
          ),
          // 5: dog, perks on tap.
          AnimatedBuilder(
            animation: _perk,
            builder: (_, child) => Transform(
              transform: _about(RoomGeo.dogOrigin, _perkMatrix(_perk.value)),
              child: child,
            ),
            child: RepaintBoundary(child: _svg('dog_$_theme.svg')),
          ),
          // 6: glow.
          if (widget.candleLit)
            Positioned(
              left: RoomGeo.glowCenter.dx - RoomGeo.glowR,
              top: RoomGeo.glowCenter.dy - RoomGeo.glowR,
              width: RoomGeo.glowR * 2,
              height: RoomGeo.glowR * 2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      ms.flameGlow,
                      ms.flameGlow.withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
            ),
          // 7–8: candle body, flame or smoke.
          _svg('candle_body_$_theme.svg'),
          if (widget.candleLit)
            AnimatedBuilder(
              animation: _flicker,
              builder: (_, child) => Transform(
                transform:
                    _about(RoomGeo.flameOrigin, _flickerMatrix(_flicker.value)),
                child: child,
              ),
              child: _svg('candle_flame_$_theme.svg'),
            )
          else
            _svg('candle_smoke_$_theme.svg'),
          // 9: vignette.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: RoomGeo.vignetteCenter,
                    radius: RoomGeo.vignetteR,
                    colors: [
                      ms.sceneShadow.withValues(alpha: 0),
                      ms.sceneShadow.withValues(alpha: 0),
                      ms.sceneShadow,
                    ],
                    stops: const [0, RoomGeo.vignetteClear, 1],
                    transform: const _StretchY(RoomGeo.h / RoomGeo.w),
                  ),
                ),
              ),
            ),
          ),
          // 10: the family's mark in the frame.
          Positioned.fromRect(
            rect: RoomGeo.logo,
            child: Image.asset('assets/logo/ms-icon.png',
                fit: BoxFit.cover, excludeFromSemantics: true),
          ),
          // 11: overlays.
          if (widget.weather.hasText)
            Positioned(
              left: RoomGeo.weatherText.dx,
              top: RoomGeo.weatherText.dy,
              child: IgnorePointer(child: _WeatherText(widget.weather)),
            ),
          if (widget.note != null)
            Positioned.fromRect(
              rect: RoomGeo.note,
              child: _WallNote(note: widget.note!, onTap: widget.onNote),
            ),
          _Hit(
            rect: RoomGeo.window,
            label: widget.weather.hasText
                ? 'Окно: ${widget.weather.temp}, ${widget.weather.label}. Прогноз'
                : 'Окно. Прогноз погоды',
            onTap: widget.onWindow,
          ),
          _Hit(
            rect: RoomGeo.candle,
            label: 'Свеча: ${widget.candleLabel}. '
                '${widget.candleLit ? 'Долгое нажатие — погасить' : 'Нажми, чтобы зажечь'}',
            onTap: widget.onCandleTap,
            onLongPress: widget.onCandleLongPress,
          ),
          _Hit(rect: RoomGeo.dog, label: 'Басенджи на кресле', onTap: _onDog),
          _Hit(
              rect: RoomGeo.frame,
              label: 'Рамка с монограммой',
              onTap: widget.onFrameTap),
        ],
      ),
    );

    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final s = width / RoomGeo.w;
      return SizedBox(
        width: width,
        height: RoomGeo.visibleH * s,
        child: ClipRect(
          child: OverflowBox(
            minHeight: RoomGeo.h * s,
            maxHeight: RoomGeo.h * s,
            child: SizedBox(
              width: width,
              height: RoomGeo.h * s,
              child: FittedBox(fit: BoxFit.fill, child: canvas),
            ),
          ),
        ),
      );
    });
  }
}

/// [m] applied about [origin].
Matrix4 _about(Offset origin, Matrix4 m) =>
    Matrix4.translationValues(origin.dx, origin.dy, 0)
      ..multiply(m)
      ..multiply(Matrix4.translationValues(-origin.dx, -origin.dy, 0));

double _ease(double t) => Curves.easeInOut.transform(t.clamp(0, 1));

/// Piecewise keyframes with ease-in-out per segment, like CSS.
List<double> _keyframes(double t, List<double> at, List<List<double>> v) {
  for (var i = 0; i < at.length - 1; i++) {
    if (t <= at[i + 1]) {
      final k = _ease((t - at[i]) / (at[i + 1] - at[i]));
      return [
        for (var j = 0; j < v[i].length; j++) v[i][j] + (v[i + 1][j] - v[i][j]) * k
      ];
    }
  }
  return v.last;
}

const double _deg = math.pi / 180;

/// Flame: 0/100 % (1, 1, 0°); 30 % (0.94, 1.06, −2°); 55 % (1.04, 0.96,
/// +1.5°); 80 % (0.97, 1.03, −1°).
Matrix4 _flickerMatrix(double t) {
  final v = _keyframes(t, const [0, 0.30, 0.55, 0.80, 1], const [
    [1, 1, 0],
    [0.94, 1.06, -2],
    [1.04, 0.96, 1.5],
    [0.97, 1.03, -1],
    [1, 1, 0],
  ]);
  return Matrix4.diagonal3Values(v[0], v[1], 1)
    ..multiply(Matrix4.rotationZ(v[2] * _deg));
}

/// Dog: 35 % rotate −5°, up 4; 65 % rotate −2°, up 2; back to rest.
Matrix4 _perkMatrix(double t) {
  final v = _keyframes(t, const [0, 0.35, 0.65, 1], const [
    [0, 0],
    [-5, -4],
    [-2, -2],
    [0, 0],
  ]);
  return Matrix4.rotationZ(v[0] * _deg)
    ..multiply(Matrix4.translationValues(0, v[1], 0));
}

/// Stretches a radial gradient vertically about its centre, so it fills
/// the canvas's box like SVG `objectBoundingBox` units.
class _StretchY extends GradientTransform {
  const _StretchY(this.k);
  final double k;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final c = RoomGeo.vignetteCenter.alongSize(bounds.size) + bounds.topLeft;
    return Matrix4.translationValues(c.dx, c.dy, 0)
      ..multiply(Matrix4.diagonal3Values(1, k, 1))
      ..multiply(Matrix4.translationValues(-c.dx, -c.dy, 0));
  }
}

class _WeatherText extends StatelessWidget {
  const _WeatherText(this.w);
  final RoomWeatherView w;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final ink = w.sky == RoomSky.night ? ms.skyInkNight : ms.skyInkDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(w.temp!, style: MsText.weatherTemp.copyWith(color: ink)),
        const SizedBox(height: RoomGeo.weatherLabelGap),
        Text(
          w.label!,
          style: MsText.body.copyWith(
            fontSize: RoomGeo.weatherLabelSize,
            height: RoomGeo.weatherLabelH,
            fontWeight: FontWeight.w500,
            color: ink,
          ),
        ),
        const SizedBox(height: RoomGeo.weatherCityGap),
        Text(
          w.cityLine!,
          style: MsText.eyebrow.copyWith(
            fontSize: RoomGeo.weatherCitySize,
            letterSpacing: RoomGeo.weatherCitySize * 0.08,
            color: ink.withValues(alpha: RoomGeo.weatherCityOpacity),
          ),
        ),
      ],
    );
  }
}

class _WallNote extends StatelessWidget {
  const _WallNote({required this.note, required this.onTap});
  final RoomNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final style = MsText.noteHand.copyWith(color: ms.sceneNoteInk);
    return Semantics(
      button: true,
      label: 'Записка на стене: ${note.text}, ${note.sign}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Transform.rotate(
          angle: RoomGeo.noteAngle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ms.sceneNote,
              borderRadius: BorderRadius.circular(RoomGeo.noteRadius),
              boxShadow: [
                BoxShadow(color: ms.sceneShadow, offset: RoomGeo.noteShadow),
              ],
            ),
            child: Stack(children: [
              Positioned(
                left: RoomGeo.notePin.dx,
                top: RoomGeo.notePin.dy,
                child: MsAuthorDot(note.author, size: RoomGeo.notePinD),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: RoomGeo.noteTextTop,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      note.text,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(
                          fontSize: RoomGeo.noteTextSize,
                          height: RoomGeo.noteTextH),
                    ),
                    const SizedBox(height: RoomGeo.noteSignGap),
                    Padding(
                      padding:
                          const EdgeInsets.only(right: RoomGeo.noteSignPadR),
                      child: Text(
                        '— ${note.sign}',
                        textAlign: TextAlign.right,
                        style: style.copyWith(
                            fontSize: RoomGeo.noteSignSize, height: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Invisible hotspot with a spoken label and no splash.
class _Hit extends StatelessWidget {
  const _Hit({
    required this.rect,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  final Rect rect;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final lp = onLongPress;
    return Positioned.fromRect(
      rect: rect,
      child: Semantics(
        button: true,
        label: label,
        onLongPress: lp,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (r) => r.onTap = onTap,
            ),
            if (lp != null)
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(duration: kCandleLongPress),
                (r) => r.onLongPress = lp,
              ),
          },
        ),
      ),
    );
  }
}
