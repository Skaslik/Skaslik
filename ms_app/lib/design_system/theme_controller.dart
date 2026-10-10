/// Theme mode: «Авто» (by sunrise/sunset), «Вечер», «День».
///
/// Decision #2 default: [kDefaultThemeMode] = auto. In auto, «День» runs
/// from sunrise to sunset for [kDefaultCity] (NOAA maths from `ms_core`),
/// falling back to 07:00–19:00 when the sun doesn't rise or set (polar).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ms_core/ms_core.dart';

import '../core/storage/local_file.dart';
import 'ms_tokens.dart';

/// What the user picked in «Мы → Тема».
enum MsThemeMode { auto, evening, day }

/// A city: name for the weather window, coordinates for sun and weather.
/// Only city coordinates are ever used, never GPS.
@immutable
class MsCity {
  final String name;
  final double lat;
  final double lng;
  const MsCity(this.name, this.lat, this.lng);
}

/// Decision #10 default: Москва for both partners.
const MsCity kDefaultCity = MsCity('Москва', 55.7558, 37.6173);

/// Decision #2 default.
const MsThemeMode kDefaultThemeMode = MsThemeMode.auto;

/// Fallback «День» window when the sun gives no answer.
const int kFallbackDayStartHour = 7;
const int kFallbackDayEndHour = 19;

/// Where the chosen mode is persisted.
abstract interface class ThemePrefs {
  MsThemeMode? read();
  void write(MsThemeMode mode);
}

/// Synchronous JSON file next to the domain stores — read before the first
/// frame, so a manual choice never flashes the other theme at start-up.
class FileThemePrefs implements ThemePrefs {
  FileThemePrefs({String? dataDir})
      : _file = LocalFile.forDomain('prefs_theme', dataDir: dataDir);
  final LocalFile _file;

  @override
  MsThemeMode? read() {
    try {
      final raw = _file.read();
      if (raw == null) return null;
      final name = (jsonDecode(raw) as Map<String, dynamic>)['mode'];
      return MsThemeMode.values.where((m) => m.name == name).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  @override
  void write(MsThemeMode mode) => _file.write(jsonEncode({'mode': mode.name}));
}

/// In-memory prefs for tests.
class MemoryThemePrefs implements ThemePrefs {
  MemoryThemePrefs([this.value]);
  MsThemeMode? value;

  @override
  MsThemeMode? read() => value;

  @override
  void write(MsThemeMode mode) => value = mode;
}

/// Resolves the theme mode to «День»/«Вечер» and flips it exactly at sunrise
/// and sunset while in auto. Call [refresh] when the app resumes.
class ThemeController extends ChangeNotifier {
  ThemeController({
    required ThemePrefs prefs,
    DateTime Function()? clock,
    this.city = kDefaultCity,
  })  : _prefs = prefs,
        _clock = clock ?? DateTime.now {
    _mode = prefs.read() ?? kDefaultThemeMode;
    _resolve();
  }

  final ThemePrefs _prefs;
  final DateTime Function() _clock;
  final MsCity city;

  late MsThemeMode _mode;
  late bool _isDay;
  Timer? _timer;

  MsThemeMode get mode => _mode;

  /// `true` → «День», `false` → «Вечер».
  bool get isDay => _isDay;

  /// For `MaterialApp.themeMode` with `theme: day`, `darkTheme: evening`.
  ThemeMode get materialMode => _isDay ? ThemeMode.light : ThemeMode.dark;

  MsPalette get palette => _isDay ? MsPalette.day : MsPalette.evening;

  void setMode(MsThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _prefs.write(mode);
    _resolve();
    notifyListeners();
  }

  /// Re-evaluate now (timers don't run while the app is suspended).
  void refresh() {
    final was = _isDay;
    _resolve();
    if (was != _isDay) notifyListeners();
  }

  /// Whether «День» applies at [now] in [city] in auto mode.
  static bool isDayAt(DateTime now, MsCity city) {
    if (_hasSunEvents(now, city)) return isDaylight(now, city.lat, city.lng);
    final h = now.toLocal().hour;
    return h >= kFallbackDayStartHour && h < kFallbackDayEndHour;
  }

  static bool _hasSunEvents(DateTime now, MsCity city) {
    final u = now.toUtc();
    return sunTimesUtc(DateTime.utc(u.year, u.month, u.day), city.lat, city.lng) !=
        null;
  }

  /// Next instant the auto theme may flip.
  static DateTime nextFlip(DateTime now, MsCity city) {
    final sun = _hasSunEvents(now, city)
        ? nextSunEvent(now, city.lat, city.lng)
        : null;
    if (sun != null) return sun;
    final l = now.toLocal();
    final start = DateTime(l.year, l.month, l.day, kFallbackDayStartHour);
    final end = DateTime(l.year, l.month, l.day, kFallbackDayEndHour);
    if (l.isBefore(start)) return start;
    if (l.isBefore(end)) return end;
    return start.add(const Duration(days: 1));
  }

  void _resolve() {
    _timer?.cancel();
    _timer = null;
    switch (_mode) {
      case MsThemeMode.evening:
        _isDay = false;
      case MsThemeMode.day:
        _isDay = true;
      case MsThemeMode.auto:
        final now = _clock();
        _isDay = isDayAt(now, city);
        final wait = nextFlip(now, city).difference(now) + const Duration(seconds: 1);
        _timer = Timer(wait.isNegative ? Duration.zero : wait, refresh);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
