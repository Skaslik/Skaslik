/// Sunrise and sunset from the NOAA general solar position equations.
///
/// Deterministic arithmetic only (I6). Accuracy is about ±2 minutes at
/// mid-latitudes, which is plenty for switching the theme and the sky.
library;

import 'dart:math' as math;

/// Sunrise and sunset of one UTC day, both as UTC [DateTime]s.
class SunTimes {
  final DateTime sunrise;
  final DateTime sunset;
  const SunTimes(this.sunrise, this.sunset);

  @override
  String toString() => 'SunTimes($sunrise → $sunset)';
}

/// Zenith used for the official sunrise/sunset (refraction + solar disc).
const double _zenithDeg = 90.833;

double _rad(double d) => d * math.pi / 180.0;
double _deg(double r) => r * 180.0 / math.pi;

/// Day of year (1..366) of a UTC date.
int _dayOfYear(DateTime utc) =>
    utc.difference(DateTime.utc(utc.year, 1, 1)).inDays + 1;

bool _leap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

/// Equation of time (minutes) and solar declination (radians) at noon UTC.
({double eqTime, double decl}) _solar(DateTime dateUtc) {
  final daysInYear = _leap(dateUtc.year) ? 366 : 365;
  final g = 2 * math.pi / daysInYear * (_dayOfYear(dateUtc) - 1);
  final eqTime = 229.18 *
      (0.000075 +
          0.001868 * math.cos(g) -
          0.032077 * math.sin(g) -
          0.014615 * math.cos(2 * g) -
          0.040849 * math.sin(2 * g));
  final decl = 0.006918 -
      0.399912 * math.cos(g) +
      0.070257 * math.sin(g) -
      0.006758 * math.cos(2 * g) +
      0.000907 * math.sin(2 * g) -
      0.002697 * math.cos(3 * g) +
      0.00148 * math.sin(3 * g);
  return (eqTime: eqTime, decl: decl);
}

/// Cosine of the sunrise hour angle; outside [-1, 1] means polar day/night.
double _cosHourAngle(double latDeg, double decl) {
  final lat = _rad(latDeg);
  return math.cos(_rad(_zenithDeg)) / (math.cos(lat) * math.cos(decl)) -
      math.tan(lat) * math.tan(decl);
}

/// Sunrise and sunset for the UTC calendar day of [dateUtc] at ([lat], [lng]).
///
/// Returns `null` on polar day or polar night (the sun never crosses the
/// horizon that day).
SunTimes? sunTimesUtc(DateTime dateUtc, double lat, double lng) {
  final day = DateTime.utc(dateUtc.year, dateUtc.month, dateUtc.day);
  final s = _solar(day);
  final cosHa = _cosHourAngle(lat, s.decl);
  if (cosHa < -1 || cosHa > 1) return null;
  final haDeg = _deg(math.acos(cosHa));
  final riseMin = 720 - 4 * (lng + haDeg) - s.eqTime;
  final setMin = 720 - 4 * (lng - haDeg) - s.eqTime;
  Duration m(double minutes) =>
      Duration(milliseconds: (minutes * 60000).round());
  return SunTimes(day.add(m(riseMin)), day.add(m(setMin)));
}

/// `true` while the sun is up at ([lat], [lng]) at the instant [now].
///
/// Checks the neighbouring UTC days too, so cities far from Greenwich (whose
/// local day straddles two UTC dates) are handled. On polar day/night the
/// answer follows the sun's elevation at solar noon.
bool isDaylight(DateTime now, double lat, double lng) {
  final u = now.toUtc();
  var anyTimes = false;
  for (final offset in const [-1, 0, 1]) {
    final t = sunTimesUtc(
        DateTime.utc(u.year, u.month, u.day).add(Duration(days: offset)),
        lat,
        lng);
    if (t == null) continue;
    anyTimes = true;
    if (!u.isBefore(t.sunrise) && u.isBefore(t.sunset)) return true;
  }
  if (anyTimes) return false;
  // Polar: the sun is up all day iff it is above the horizon at noon.
  final s = _solar(DateTime.utc(u.year, u.month, u.day));
  return _cosHourAngle(lat, s.decl) < -1;
}

/// The first sunrise or sunset strictly after [now], looking up to 2 days
/// ahead. `null` during polar day/night.
DateTime? nextSunEvent(DateTime now, double lat, double lng) {
  final u = now.toUtc();
  DateTime? best;
  for (final offset in const [-1, 0, 1, 2]) {
    final t = sunTimesUtc(
        DateTime.utc(u.year, u.month, u.day).add(Duration(days: offset)),
        lat,
        lng);
    if (t == null) continue;
    for (final e in [t.sunrise, t.sunset]) {
      if (e.isAfter(u) && (best == null || e.isBefore(best))) best = e;
    }
  }
  return best;
}
