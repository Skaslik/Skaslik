import 'package:flutter_test/flutter_test.dart';
import 'package:ms_app/core/pair/pair.dart';
import 'package:ms_app/design_system/ms_format.dart';
import 'package:ms_app/design_system/widgets/ms_author.dart';
import 'package:ms_app/features/calendar/calendar_model.dart';
import 'package:ms_app/shell/ms_shell.dart';
import 'package:ms_app/shell/tab_badges.dart';
import 'package:ms_core/ms_core.dart';

void main() {
  setUpAll(initMsFormat);

  const misha = Pair(
      me: kMichael, partner: kSofia, myDeviceId: 'A', partnerDeviceId: 'B');
  const sonya = Pair(
      me: kSofia, partner: kMichael, myDeviceId: 'B', partnerDeviceId: 'A');
  final october = DateTime(2026, 10);
  final now = DateTime(2026, 10, 8, 21, 14);

  CalEvent ev(String id, DateTime start,
          {String? owner, bool shared = false, DateTime? end, bool allDay = false}) =>
      CalEvent(
          id: id,
          title: id,
          start: start,
          end: end,
          allDay: allDay,
          ownerId: owner,
          shared: shared);

  group('month grid', () {
    test('Monday-first whole weeks: October 2026 is 28 Sep … 1 Nov', () {
      final days = MonthModel.gridDays(october);
      expect(days.first, DateTime(2026, 9, 28));
      expect(days.last, DateTime(2026, 11, 1));
      expect(days.length, 35);
      expect(days.first.weekday, DateTime.monday);
    });

    test('a 6-week month: March 2026 starts on Sunday the 1st', () {
      expect(MonthModel.gridDays(DateTime(2026, 3)).length, 42);
    });

    test('dots: one per author; shared shows both', () {
      final m = MonthModel.build(october, [
        ev('dinner', DateTime(2026, 10, 8, 19, 30), owner: 'B'),
        ev('dentist', DateTime(2026, 10, 9, 10), owner: 'A'),
        ev('anniv', DateTime(2026, 10, 10), shared: true, allDay: true),
        ev('two', DateTime(2026, 10, 14, 9), owner: 'A'),
        ev('two-b', DateTime(2026, 10, 14, 18), owner: 'A'),
      ], misha);
      expect(m.dots[DateTime(2026, 10, 8)], [MsAuthor.sofia]);
      expect(m.dots[DateTime(2026, 10, 9)], [MsAuthor.michael]);
      expect(m.dots[DateTime(2026, 10, 10)], [MsAuthor.michael, MsAuthor.sofia]);
      expect(m.dots[DateTime(2026, 10, 14)], [MsAuthor.michael]);
      expect(m.byDay[DateTime(2026, 10, 14)], hasLength(2));
    });

    test('multi-day: a bar instead of dots, inset at real ends', () {
      final m = MonthModel.build(october, [
        ev('Казань', DateTime(2026, 10, 16), end: DateTime(2026, 10, 18),
            shared: true, allDay: true),
      ], misha);
      expect(m.dots[DateTime(2026, 10, 16)], isNull);
      for (final d in [16, 17, 18]) {
        expect(m.byDay[DateTime(2026, 10, d)], hasLength(1));
      }
      final week = m.days.indexOf(DateTime(2026, 10, 12)) ~/ 7;
      final bar = m.spans[week].single;
      expect((bar.from, bar.to), (4, 6)); // Fri … Sun
      expect(bar.startsHere && bar.endsHere, isTrue);
      expect(bar.author, MsAuthor.both);
    });

    test('a bar crossing a week boundary is split, open at the cut', () {
      final m = MonthModel.build(october, [
        ev('trip', DateTime(2026, 10, 24), end: DateTime(2026, 10, 27), owner: 'B'),
      ], misha);
      final w1 = m.days.indexOf(DateTime(2026, 10, 19)) ~/ 7;
      final a = m.spans[w1].single, b = m.spans[w1 + 1].single;
      expect((a.from, a.to, a.startsHere, a.endsHere), (5, 6, true, false));
      expect((b.from, b.to, b.startsHere, b.endsHere), (0, 1, false, true));
      expect(a.author, MsAuthor.sofia);
    });
  });

  group('meta line', () {
    test('partner added / I added, with gender', () {
      expect(eventMetaLine(ev('d', DateTime(2026, 10, 8, 19, 30), owner: 'B'),
              DateTime(2026, 10, 8, 19, 30), misha, now),
          '19:30 · добавила София');
      expect(eventMetaLine(ev('d', DateTime(2026, 10, 9, 10), owner: 'A'),
              DateTime(2026, 10, 9, 10), misha, now),
          '10:00 · добавил ты');
      expect(eventMetaLine(ev('d', DateTime(2026, 10, 9, 10), owner: 'B'),
              DateTime(2026, 10, 9, 10), sonya, now),
          '10:00 · добавила ты');
    });

    test('edited by the partner: «изменил Михаил 2 мин назад»', () {
      final e = ev('d', DateTime(2026, 10, 9, 10), owner: 'B').copyWith(
          editedBy: 'A',
          editedAt: now.subtract(const Duration(minutes: 2)).millisecondsSinceEpoch);
      expect(eventMetaLine(e, e.start, sonya, now),
          '10:00 · изменил Михаил 2 мин назад');
    });

    test('repeat, shared and multi-day', () {
      final anniv = CalEvent(
          id: 'a',
          title: 'Годовщина',
          start: DateTime(2026, 10, 10),
          allDay: true,
          recurrence: Recurrence.yearly,
          shared: true);
      expect(eventMetaLine(anniv, anniv.start, misha, now),
          'весь день · каждый год');
      expect(eventMetaLine(ev('h', DateTime(2026, 10, 31, 20), shared: true),
              DateTime(2026, 10, 31, 20), misha, now),
          '20:00 · вместе');
      expect(
          eventMetaLine(
              ev('k', DateTime(2026, 10, 16), end: DateTime(2026, 10, 18), owner: 'B'),
              DateTime(2026, 10, 16), misha, now),
          '3 дня · добавила София');
    });

    test('day heading «8 октября, четверг»', () {
      expect(dayHeading(DateTime(2026, 10, 8)), '8 октября, четверг');
    });
  });

  group('calendar badge', () {
    test('only the partner\'s creations and edits count', () {
      final events = [
        ev('mine', DateTime(2026, 10, 9), owner: 'A')
            .copyWith(editedBy: 'A', editedAt: 900),
        CalEvent(
            id: 'hers', title: 'h', start: DateTime(2026, 10, 9),
            ownerId: 'B', createdAt: 500),
        CalEvent(
            id: 'edited', title: 'e', start: DateTime(2026, 10, 9),
            ownerId: 'A', createdAt: 100, editedBy: 'B', editedAt: 700),
        CalEvent(id: 'legacy', title: 'l', start: DateTime(2026, 10, 9)),
      ];
      expect(calendarPartnerActivity(events, misha), 700);
      expect(calendarPartnerActivity(events.take(1), misha), isNull);
    });

    test('first run: history before install is not news', () {
      final store = MemorySeenStore();
      final seen = TabSeen(store, clock: () => DateTime(2026, 10, 8));
      expect(seen.seenAt(MsTab.calendar),
          DateTime(2026, 10, 8).millisecondsSinceEpoch);
      expect(store.value, isNotEmpty);
    });
  });
}
