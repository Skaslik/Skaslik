/// Calendar logic for the UI: authors, meta lines and the month grid.
/// Pure and tested; no widgets here.
library;

import 'package:ms_core/ms_core.dart';

import '../../core/pair/pair.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/widgets/ms_author.dart';

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whose mark an event carries: shared → both halves (decision #7), else
/// its creator. Events from before owners existed count as mine.
MsAuthor eventAuthor(CalEvent e, Pair pair) =>
    e.shared ? MsAuthor.both : pair.memberOf(e.ownerId).author;

/// Calendar days an event covers (1 for a one-day event).
int spanDays(CalEvent e) {
  final end = e.end;
  if (end == null) return 1;
  final d = dayOf(end).difference(dayOf(e.start)).inDays + 1;
  return d < 1 ? 1 : d;
}

String? repeatWord(Recurrence r) => switch (r) {
      Recurrence.none => null,
      Recurrence.daily => 'каждый день',
      Recurrence.weekly => 'каждую неделю',
      Recurrence.monthly => 'каждый месяц',
      Recurrence.yearly => 'каждый год',
    };

/// Meta under an event title, mono: «19:30 · добавила София»,
/// «10:00 · изменил Михаил 2 мин назад», «весь день · каждый год»,
/// «3 дня · вместе», «19:30 · добавил ты».
String eventMetaLine(CalEvent e, DateTime occ, Pair pair, DateTime now) {
  final days = spanDays(e);
  final when = days > 1
      ? daysWord(days)
      : e.allDay
          ? 'весь день'
          : formatTime(occ);
  String nameOf(String? id) =>
      pair.isMine(id) ? 'ты' : pair.memberOf(id).name;

  final String who;
  if (e.editedBy != null && e.editedAt != null) {
    final m = pair.memberOf(e.editedBy);
    who = '${m.verb('изменил')} ${nameOf(e.editedBy)} '
        '${ago(DateTime.fromMillisecondsSinceEpoch(e.editedAt!), now)}';
  } else if (repeatWord(e.recurrence) case final r?) {
    who = r;
  } else if (e.shared) {
    who = 'вместе';
  } else {
    final m = pair.memberOf(e.ownerId);
    who = '${m.verb('добавил')} ${nameOf(e.ownerId)}';
  }
  return '$when · $who';
}

/// «8 октября, четверг».
String dayHeading(DateTime d) => '${formatDayMonth(d)}, ${formatWeekday(d)}';

/// A multi-day bar inside one week row, columns 0..6.
class SpanBar {
  const SpanBar({
    required this.from,
    required this.to,
    required this.author,
    required this.startsHere,
    required this.endsHere,
  });

  final int from;
  final int to;
  final MsAuthor author;

  /// The event begins / ends in this week (bars are inset at real ends).
  final bool startsHere;
  final bool endsHere;
}

/// Everything the month grid draws.
class MonthModel {
  MonthModel._(this.month, this.days, this.byDay, this.dots, this.spans);

  /// First of the shown month.
  final DateTime month;

  /// Monday-first whole weeks covering the month (35 or 42 days).
  final List<DateTime> days;

  /// Events per day; a multi-day event appears on each day it covers.
  final Map<DateTime, List<(CalEvent, DateTime)>> byDay;

  /// Author dots under a day number: michael and/or sofia, in that order.
  /// Multi-day events are bars instead.
  final Map<DateTime, List<MsAuthor>> dots;

  /// Bars per week row.
  final List<List<SpanBar>> spans;

  int get weeks => days.length ~/ 7;

  bool inMonth(DateTime d) => d.month == month.month && d.year == month.year;

  /// Grid days for [month]: from the Monday on or before the 1st to the
  /// Sunday on or after the last day.
  static List<DateTime> gridDays(DateTime month) {
    final first = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month + 1, 0);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final end = last.add(Duration(days: 7 - last.weekday));
    final n = end.difference(start).inDays + 1;
    return [for (var i = 0; i < n; i++) DateTime(start.year, start.month, start.day + i)];
  }

  static MonthModel build(DateTime month, List<CalEvent> events, Pair pair) {
    final m = DateTime(month.year, month.month);
    final days = gridDays(m);
    final first = days.first, last = days.last;
    final lastEnd = DateTime(last.year, last.month, last.day, 23, 59, 59);
    // Look back far enough to catch multi-day events that began earlier.
    final occs = expand(events, first.subtract(const Duration(days: 62)), lastEnd);

    final byDay = <DateTime, List<(CalEvent, DateTime)>>{};
    final dotSets = <DateTime, Set<MsAuthor>>{};
    final weeks = days.length ~/ 7;
    final spans = List.generate(weeks, (_) => <SpanBar>[]);

    for (final (e, occ) in occs) {
      final n = spanDays(e);
      final startDay = dayOf(occ);
      final endDay = DateTime(startDay.year, startDay.month, startDay.day + n - 1);
      if (endDay.isBefore(first) || startDay.isAfter(last)) continue;
      final author = eventAuthor(e, pair);
      for (var i = 0; i < n; i++) {
        final d = DateTime(startDay.year, startDay.month, startDay.day + i);
        if (d.isBefore(first) || d.isAfter(last)) continue;
        byDay.putIfAbsent(d, () => []).add((e, occ));
        if (n == 1) {
          final s = dotSets.putIfAbsent(d, () => {});
          if (author == MsAuthor.both) {
            s.addAll(const [MsAuthor.michael, MsAuthor.sofia]);
          } else {
            s.add(author);
          }
        }
      }
      if (n > 1) {
        for (var w = 0; w < weeks; w++) {
          final ws = days[w * 7], we = days[w * 7 + 6];
          if (endDay.isBefore(ws) || startDay.isAfter(we)) continue;
          final from = startDay.isBefore(ws) ? 0 : startDay.difference(ws).inDays;
          final to = endDay.isAfter(we) ? 6 : endDay.difference(ws).inDays;
          spans[w].add(SpanBar(
            from: from,
            to: to,
            author: author,
            startsHere: !startDay.isBefore(ws),
            endsHere: !endDay.isAfter(we),
          ));
        }
      }
    }
    final dots = {
      for (final e in dotSets.entries)
        e.key: [
          if (e.value.contains(MsAuthor.michael)) MsAuthor.michael,
          if (e.value.contains(MsAuthor.sofia)) MsAuthor.sofia,
        ],
    };
    return MonthModel._(m, days, byDay, dots, spans);
  }
}

/// Upcoming events for the «Список» view, from [now], at most [limit].
List<(CalEvent, DateTime)> upcomingList(List<CalEvent> events, DateTime now,
        {int days = 365, int limit = 100}) =>
    expand(events, dayOf(now), dayOf(now).add(Duration(days: days)))
        .take(limit)
        .toList();
