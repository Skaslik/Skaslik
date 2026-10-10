/// NOAA sunrise/sunset (deterministic, I6): used for the «Авто» theme and the
/// sky in the room. Reference values for Moscow are from timeanddate.com.
library;

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  const moscowLat = 55.7558, moscowLng = 37.6173;

  // Minutes from UTC midnight, to compare without depending on the local TZ.
  int minutesUtc(DateTime d) => d.toUtc().hour * 60 + d.toUtc().minute;

  group('sunTimesUtc', () {
    test('Moscow, summer solstice: ~03:44 / ~21:18 MSK', () {
      final t = sunTimesUtc(DateTime.utc(2026, 6, 21), moscowLat, moscowLng)!;
      expect(minutesUtc(t.sunrise), closeTo(44, 5)); // 00:44 UTC
      expect(minutesUtc(t.sunset), closeTo(18 * 60 + 18, 5)); // 18:18 UTC
    });

    test('Moscow, winter solstice: ~08:59 / ~15:57 MSK', () {
      final t = sunTimesUtc(DateTime.utc(2026, 12, 21), moscowLat, moscowLng)!;
      expect(minutesUtc(t.sunrise), closeTo(5 * 60 + 59, 5)); // 05:59 UTC
      expect(minutesUtc(t.sunset), closeTo(12 * 60 + 57, 5)); // 12:57 UTC
    });

    test('sunrise is before sunset and both are on the asked UTC date', () {
      final t = sunTimesUtc(DateTime.utc(2026, 10, 10), moscowLat, moscowLng)!;
      expect(t.sunrise.isBefore(t.sunset), isTrue);
      expect(t.sunrise.toUtc().day, 10);
      expect(t.sunset.toUtc().day, 10);
    });

    test('polar day and polar night have no sunrise/sunset', () {
      expect(sunTimesUtc(DateTime.utc(2026, 6, 21), 78.22, 15.65), isNull);
      expect(sunTimesUtc(DateTime.utc(2026, 12, 21), 78.22, 15.65), isNull);
    });
  });

  group('isDaylight', () {
    test('Moscow noon is day, Moscow midnight is night', () {
      expect(isDaylight(DateTime.utc(2026, 10, 10, 9), moscowLat, moscowLng),
          isTrue); // 12:00 MSK
      expect(isDaylight(DateTime.utc(2026, 10, 10, 21), moscowLat, moscowLng),
          isFalse); // 00:00 MSK
    });

    test('just after sunset is night', () {
      final t = sunTimesUtc(DateTime.utc(2026, 10, 10), moscowLat, moscowLng)!;
      expect(isDaylight(t.sunset.add(const Duration(minutes: 1)), moscowLat,
          moscowLng), isFalse);
      expect(isDaylight(t.sunrise.add(const Duration(minutes: 1)), moscowLat,
          moscowLng), isTrue);
    });

    test('polar day is daylight, polar night is not', () {
      expect(isDaylight(DateTime.utc(2026, 6, 21, 0), 78.22, 15.65), isTrue);
      expect(isDaylight(DateTime.utc(2026, 12, 21, 12), 78.22, 15.65), isFalse);
    });

    test('far-east city: local morning that is the previous UTC day', () {
      // Vladivostok 43.12, 131.89 (UTC+10): 2026-06-21 09:00 local is
      // 2026-06-20 23:00 UTC — must still be day.
      expect(isDaylight(DateTime.utc(2026, 6, 20, 23), 43.12, 131.89), isTrue);
    });
  });

  group('nextSunEvent', () {
    test('returns the next sunrise or sunset strictly after now', () {
      final now = DateTime.utc(2026, 10, 10, 9); // day in Moscow
      final next = nextSunEvent(now, moscowLat, moscowLng)!;
      final today = sunTimesUtc(DateTime.utc(2026, 10, 10), moscowLat, moscowLng)!;
      expect(next, today.sunset);
    });

    test('after sunset the next event is tomorrow sunrise', () {
      final now = DateTime.utc(2026, 10, 10, 20);
      final next = nextSunEvent(now, moscowLat, moscowLng)!;
      final tomorrow =
          sunTimesUtc(DateTime.utc(2026, 10, 11), moscowLat, moscowLng)!;
      expect(next, tomorrow.sunrise);
    });
  });
}
