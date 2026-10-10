import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ms_app/core/weather/weather.dart';
import 'package:ms_app/design_system/theme_controller.dart';

Map<String, dynamic> sample() => {
      'utc_offset_seconds': 10800,
      'current': {
        'time': '2026-10-08T21:00',
        'temperature_2m': 7.2,
        'apparent_temperature': 4.4,
        'weather_code': 61,
        'is_day': 0,
        'wind_speed_10m': 5.1,
      },
      'hourly': {
        'time': [for (var h = 0; h < 18; h++) DateTime(2026, 10, 8, 21 + h).toIso8601String().substring(0, 16)],
        'temperature_2m': [for (var h = 0; h < 18; h++) 7.0 - h * 0.3],
        'weather_code': [for (var h = 0; h < 18; h++) h < 6 ? 61 : 3],
      },
    };

class _FakeRepo implements WeatherRepository {
  _FakeRepo(this.result);
  WeatherNow? result;
  int calls = 0;
  @override
  Future<WeatherNow> fetch(MsCity city) async {
    calls++;
    final r = result;
    if (r == null) throw http.ClientException('offline');
    return r;
  }
}

void main() {
  final fetched = DateTime(2026, 10, 8, 21, 0);

  test('WMO codes → kinds and words', () {
    expect(weatherKindFor(0), WeatherKind.clear);
    expect(weatherKindFor(1), WeatherKind.clear);
    expect(weatherKindFor(3), WeatherKind.cloudy);
    expect(weatherKindFor(45), WeatherKind.cloudy);
    expect(weatherKindFor(61), WeatherKind.rain);
    expect(weatherKindFor(81), WeatherKind.rain);
    expect(weatherKindFor(95), WeatherKind.rain);
    expect(weatherKindFor(73), WeatherKind.snow);
    expect(weatherKindFor(86), WeatherKind.snow);
    expect(weatherLabelFor(61), 'мелкий дождь');
    expect(weatherLabelFor(2), 'облачно');
  });

  test('temperature: «+7°», «−2°», «0°»', () {
    expect(formatTemp(7.2), '+7°');
    expect(formatTemp(-1.6), '−2°');
    expect(formatTemp(0.3), '0°');
  });

  test('request carries only the city coordinates', () async {
    late Uri seen;
    final client = MockClient((req) async {
      seen = req.url;
      return http.Response(jsonEncode(sample()), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final w = await OpenMeteoWeather(client: client, clock: () => fetched)
        .fetch(kDefaultCity);
    expect(seen.host, 'api.open-meteo.com');
    expect(seen.queryParameters['latitude'], '55.7558');
    expect(seen.queryParameters['longitude'], '37.6173');
    expect(seen.queryParameters['wind_speed_unit'], 'ms');
    expect(w.temp, 7.2);
    expect(w.feels, 4.4);
    expect(w.wind, 5.1);
    expect(w.label, 'мелкий дождь');
    expect(w.isDay, isFalse);
    expect(w.hours, hasLength(18));
  });

  test('non-200 is an error', () async {
    final client = MockClient((_) async => http.Response('nope', 503));
    expect(OpenMeteoWeather(client: client).fetch(kDefaultCity),
        throwsA(isA<http.ClientException>()));
  });

  test('six tiles: every third hour from the next one', () {
    final w = parseOpenMeteo(sample(), fetched);
    final tiles = sixTiles(w.hours, DateTime(2026, 10, 8, 21, 10));
    expect(tiles, hasLength(6));
    expect(tiles.first.time, DateTime(2026, 10, 8, 22));
    expect(tiles[1].time, DateTime(2026, 10, 9, 1));
  });

  test('JSON round-trip for the cache', () {
    final w = parseOpenMeteo(sample(), fetched);
    final back = WeatherNow.fromJson(
        jsonDecode(jsonEncode(w.toJson())) as Map<String, dynamic>);
    expect(back.temp, w.temp);
    expect(back.fetchedAt, w.fetchedAt);
    expect(back.hours.length, w.hours.length);
  });

  group('controller', () {
    test('fetches when empty and caches the result', () async {
      final repo = _FakeRepo(parseOpenMeteo(sample(), fetched));
      final cache = MemoryWeatherCache();
      final c = WeatherController(repo: repo, cache: cache, clock: () => fetched);
      addTearDown(c.dispose);
      await c.refresh();
      expect(repo.calls, 1);
      expect(c.last?.temp, 7.2);
      expect(cache.value, isNotNull);
    });

    test('a fresh cached result is not refetched', () async {
      final repo = _FakeRepo(parseOpenMeteo(sample(), fetched));
      final c = WeatherController(
          repo: repo,
          cache: MemoryWeatherCache(parseOpenMeteo(sample(), fetched)),
          clock: () => fetched.add(const Duration(minutes: 10)));
      addTearDown(c.dispose);
      await c.refresh();
      expect(repo.calls, 0);
    });

    test('offline keeps the last result; it turns stale after 90 min',
        () async {
      final repo = _FakeRepo(null);
      final c = WeatherController(
          repo: repo,
          cache: MemoryWeatherCache(parseOpenMeteo(sample(), fetched)),
          clock: () => fetched.add(const Duration(hours: 2)));
      addTearDown(c.dispose);
      await c.refresh();
      expect(repo.calls, 1);
      expect(c.last?.temp, 7.2);
      expect(c.last!.isStale(fetched.add(const Duration(hours: 2))), isTrue);
      expect(c.last!.isStale(fetched.add(const Duration(minutes: 30))), isFalse);
    });
  });
}
