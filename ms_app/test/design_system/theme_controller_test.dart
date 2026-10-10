import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_app/design_system/ms_tokens.dart';
import 'package:ms_app/design_system/theme_controller.dart';
import 'package:ms_core/ms_core.dart';

void main() {
  // 12:00 and 00:00 in Moscow (UTC+3).
  final moscowNoon = DateTime.utc(2026, 10, 10, 9);
  final moscowMidnight = DateTime.utc(2026, 10, 10, 21);

  ThemeController make(DateTime now, [MsThemeMode? stored]) =>
      ThemeController(prefs: MemoryThemePrefs(stored), clock: () => now);

  test('default is «Авто» (decision #2)', () {
    final c = make(moscowNoon);
    addTearDown(c.dispose);
    expect(c.mode, MsThemeMode.auto);
    expect(kDefaultThemeMode, MsThemeMode.auto);
  });

  test('auto: «День» at Moscow noon, «Вечер» at midnight', () {
    final day = make(moscowNoon);
    final night = make(moscowMidnight);
    addTearDown(day.dispose);
    addTearDown(night.dispose);
    expect(day.isDay, isTrue);
    expect(day.materialMode, ThemeMode.light);
    expect(day.palette, same(MsPalette.day));
    expect(night.isDay, isFalse);
    expect(night.materialMode, ThemeMode.dark);
    expect(night.palette, same(MsPalette.evening));
  });

  test('manual modes override the sun, persist, and notify', () {
    final prefs = MemoryThemePrefs();
    final c = ThemeController(prefs: prefs, clock: () => moscowNoon);
    addTearDown(c.dispose);
    var notified = 0;
    c.addListener(() => notified++);

    c.setMode(MsThemeMode.evening);
    expect(c.isDay, isFalse);
    expect(prefs.value, MsThemeMode.evening);

    c.setMode(MsThemeMode.day);
    expect(c.isDay, isTrue);
    expect(prefs.value, MsThemeMode.day);

    c.setMode(MsThemeMode.day); // no change → no notification
    expect(notified, 2);
  });

  test('a stored mode is used at start', () {
    final c = make(moscowNoon, MsThemeMode.evening);
    addTearDown(c.dispose);
    expect(c.mode, MsThemeMode.evening);
    expect(c.isDay, isFalse);
  });

  test('polar night falls back to 07:00–19:00 local time', () {
    const svalbard = MsCity('Лонгйир', 78.22, 15.65);
    expect(ThemeController.isDayAt(DateTime(2026, 12, 21, 12), svalbard), isTrue);
    expect(ThemeController.isDayAt(DateTime(2026, 12, 21, 22), svalbard), isFalse);
  });

  test('next flip in the day is today\'s sunset', () {
    final sun = sunTimesUtc(
        DateTime.utc(2026, 10, 10), kDefaultCity.lat, kDefaultCity.lng)!;
    expect(ThemeController.nextFlip(moscowNoon, kDefaultCity), sun.sunset);
  });

  test('FileThemePrefs round-trips the mode', () {
    final dir = Directory.systemTemp.createTempSync('ms_theme_prefs');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(FileThemePrefs(dataDir: dir.path).read(), isNull);
    FileThemePrefs(dataDir: dir.path).write(MsThemeMode.day);
    expect(FileThemePrefs(dataDir: dir.path).read(), MsThemeMode.day);
  });
}
