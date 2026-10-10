/// Weather in the room window (decision #10: Open-Meteo by city).
///
/// One GET per 30–60 min while the app is open, with the **city**
/// coordinates only — never GPS. The last result is cached with its time,
/// so offline the window shows it with «в 18:40»; with no result ever, the
/// sky follows the clock and there is no text.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../design_system/theme_controller.dart';
import '../storage/local_file.dart';

/// What the window draws.
enum WeatherKind { clear, cloudy, rain, snow }

/// WMO weather code → kind (IMPLEMENTATION Phase 3).
WeatherKind weatherKindFor(int code) {
  if (code <= 1) return WeatherKind.clear;
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return WeatherKind.snow;
  }
  if ((code >= 51 && code <= 67) ||
      (code >= 80 && code <= 82) ||
      code >= 95) {
    return WeatherKind.rain;
  }
  return WeatherKind.cloudy;
}

/// WMO weather code → the Russian word written in the window.
String weatherLabelFor(int code) => switch (code) {
      0 => 'ясно',
      1 => 'малооблачно',
      2 => 'облачно',
      3 => 'пасмурно',
      45 || 48 => 'туман',
      51 || 53 || 55 => 'морось',
      56 || 57 => 'ледяная морось',
      61 => 'мелкий дождь',
      63 => 'дождь',
      65 => 'сильный дождь',
      66 || 67 => 'ледяной дождь',
      71 => 'небольшой снег',
      73 => 'снег',
      75 => 'сильный снег',
      77 => 'снежная крупа',
      80 => 'небольшой ливень',
      81 => 'ливень',
      82 => 'сильный ливень',
      85 => 'снегопад',
      86 => 'сильный снегопад',
      95 => 'гроза',
      96 || 99 => 'гроза с градом',
      _ => 'облачно',
    };

/// «+7°», «−2°», «0°».
String formatTemp(double t) {
  final n = t.round();
  if (n > 0) return '+$n°';
  if (n < 0) return '−${-n}°';
  return '0°';
}

@immutable
class WeatherHour {
  const WeatherHour({required this.time, required this.temp, required this.code});
  final DateTime time;
  final double temp;
  final int code;

  Map<String, Object> toJson() =>
      {'t': time.toIso8601String(), 'v': temp, 'c': code};

  static WeatherHour fromJson(Map<String, dynamic> j) => WeatherHour(
        time: DateTime.parse(j['t'] as String),
        temp: (j['v'] as num).toDouble(),
        code: j['c'] as int,
      );
}

@immutable
class WeatherNow {
  const WeatherNow({
    required this.temp,
    required this.feels,
    required this.wind,
    required this.code,
    required this.isDay,
    required this.fetchedAt,
    this.hours = const [],
  });

  final double temp;
  final double feels;

  /// m/s.
  final double wind;
  final int code;
  final bool isDay;
  final DateTime fetchedAt;
  final List<WeatherHour> hours;

  WeatherKind get kind => weatherKindFor(code);
  String get label => weatherLabelFor(code);

  /// Older than this, the window adds «в 18:40».
  static const Duration staleAfter = Duration(minutes: 90);
  bool isStale(DateTime now) => now.difference(fetchedAt) > staleAfter;

  Map<String, Object> toJson() => {
        'temp': temp,
        'feels': feels,
        'wind': wind,
        'code': code,
        'isDay': isDay,
        'at': fetchedAt.toIso8601String(),
        'hours': [for (final h in hours) h.toJson()],
      };

  static WeatherNow fromJson(Map<String, dynamic> j) => WeatherNow(
        temp: (j['temp'] as num).toDouble(),
        feels: (j['feels'] as num).toDouble(),
        wind: (j['wind'] as num).toDouble(),
        code: j['code'] as int,
        isDay: j['isDay'] as bool,
        fetchedAt: DateTime.parse(j['at'] as String),
        hours: [
          for (final h in (j['hours'] as List? ?? const []))
            WeatherHour.fromJson(h as Map<String, dynamic>),
        ],
      );
}

/// Swappable source (decision #10).
abstract interface class WeatherRepository {
  Future<WeatherNow> fetch(MsCity city);
}

/// Open-Meteo: no key, no account. Only the city's coordinates are sent.
class OpenMeteoWeather implements WeatherRepository {
  OpenMeteoWeather({http.Client? client, DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;

  static Uri uriFor(MsCity city) =>
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': city.lat.toStringAsFixed(4),
        'longitude': city.lng.toStringAsFixed(4),
        'current':
            'temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m',
        'hourly': 'temperature_2m,weather_code',
        'forecast_hours': '18',
        'wind_speed_unit': 'ms',
        'timezone': 'auto',
      });

  @override
  Future<WeatherNow> fetch(MsCity city) async {
    final res = await _client
        .get(uriFor(city))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw http.ClientException('Open-Meteo ${res.statusCode}');
    }
    return parseOpenMeteo(
        jsonDecode(res.body) as Map<String, dynamic>, _clock());
  }
}

/// Parse an Open-Meteo `forecast` response (times are city-local).
WeatherNow parseOpenMeteo(Map<String, dynamic> j, DateTime fetchedAt) {
  final c = j['current'] as Map<String, dynamic>;
  final h = j['hourly'] as Map<String, dynamic>? ?? const {};
  final times = (h['time'] as List? ?? const []).cast<String>();
  final temps = (h['temperature_2m'] as List? ?? const []);
  final codes = (h['weather_code'] as List? ?? const []);
  return WeatherNow(
    temp: (c['temperature_2m'] as num).toDouble(),
    feels: (c['apparent_temperature'] as num).toDouble(),
    wind: (c['wind_speed_10m'] as num).toDouble(),
    code: (c['weather_code'] as num).toInt(),
    isDay: (c['is_day'] as num) == 1,
    fetchedAt: fetchedAt,
    hours: [
      for (var i = 0; i < times.length && i < temps.length && i < codes.length; i++)
        WeatherHour(
          time: DateTime.parse(times[i]),
          temp: (temps[i] as num).toDouble(),
          code: (codes[i] as num).toInt(),
        ),
    ],
  );
}

/// Six tiles for the weather sheet: every third hour from the next one.
List<WeatherHour> sixTiles(List<WeatherHour> hours, DateTime now) {
  final future = hours.where((h) => h.time.isAfter(now)).toList();
  return [for (var i = 0; i < future.length && i < 18; i += 3) future[i]]
      .take(6)
      .toList();
}

/// Where the last result is kept.
abstract interface class WeatherCache {
  WeatherNow? read();
  void write(WeatherNow w);
}

class FileWeatherCache implements WeatherCache {
  FileWeatherCache({String? dataDir})
      : _file = LocalFile.forDomain('weather_cache', dataDir: dataDir);
  final LocalFile _file;

  @override
  WeatherNow? read() {
    try {
      final raw = _file.read();
      return raw == null
          ? null
          : WeatherNow.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  void write(WeatherNow w) => _file.write(jsonEncode(w.toJson()));
}

class MemoryWeatherCache implements WeatherCache {
  MemoryWeatherCache([this.value]);
  WeatherNow? value;
  @override
  WeatherNow? read() => value;
  @override
  void write(WeatherNow w) => value = w;
}

/// Holds the last weather and refreshes it at most every [refreshEvery].
class WeatherController extends ChangeNotifier {
  WeatherController({
    required WeatherRepository repo,
    required WeatherCache cache,
    this.city = kDefaultCity,
    DateTime Function()? clock,
  })  : _repo = repo,
        _cache = cache,
        _clock = clock ?? DateTime.now {
    _last = cache.read();
  }

  /// Within the 30–60 min window of IMPLEMENTATION Phase 3.
  static const Duration refreshEvery = Duration(minutes: 45);

  final WeatherRepository _repo;
  final WeatherCache _cache;
  final DateTime Function() _clock;
  final MsCity city;

  WeatherNow? _last;
  Timer? _timer;
  bool _busy = false;
  bool _disposed = false;

  WeatherNow? get last => _last;

  /// Fetch when there is no result or it is older than [refreshEvery]
  /// ([force] ignores the age). Failures keep the last result.
  Future<void> refresh({bool force = false}) async {
    if (_busy || _disposed) return;
    final last = _last;
    if (!force &&
        last != null &&
        _clock().difference(last.fetchedAt) < refreshEvery) {
      _schedule(refreshEvery - _clock().difference(last.fetchedAt));
      return;
    }
    _busy = true;
    try {
      final w = await _repo.fetch(city);
      if (_disposed) return;
      _last = w;
      _cache.write(w);
      notifyListeners();
    } catch (_) {
      // Offline or blocked: keep the last result; the window says when.
    } finally {
      _busy = false;
      if (!_disposed) _schedule(refreshEvery);
    }
  }

  void _schedule(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, refresh);
  }

  /// Stop refreshing while the app is in the background.
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// Weather for the room window; fetches on first use, then every 45 min
/// while the app is in the foreground.
final weatherProvider = ChangeNotifierProvider<WeatherController>((ref) {
  final c = WeatherController(repo: OpenMeteoWeather(), cache: FileWeatherCache());
  unawaited(c.refresh());
  return c;
});
