/// Домен «Календарь»: recurrence, годовщины, напоминания, адаптер событий.
///
/// Все операции — чистые и детерминированные (без ML, I6).
library;
import '../sync/replica.dart';

enum Recurrence { none, daily, weekly, monthly, yearly }

Recurrence parseRecurrence(String? s) {
  switch (s) {
    case 'daily': return Recurrence.daily;
    case 'weekly': return Recurrence.weekly;
    case 'monthly': return Recurrence.monthly;
    case 'yearly': return Recurrence.yearly;
    default: return Recurrence.none;
  }
}

/// Количество дней в месяце (1-индексный месяц).
int daysInMonth(int year, int month) {
  const l = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (month == 2 && _isLeap(year)) return 29;
  return l[month - 1];
}

bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

/// Вхождения рекуррентного события с датой [first] в интервале [from, to]
/// (включительно). Детерминированно; лимит [limit] защищает от бесконечных серий.
///
/// Правила (классические, как в календарях):
///  - daily: +1 день;
///  - weekly: +7 дней;
///  - monthly: тот же день месяца; если в месяце меньше дней — последним днём
///    месяца (31 января → 28 февраля);
///  - yearly: та же дата; 29 февраля в невисокосный год → 28 февраля.
List<DateTime> occurrences({
  required Recurrence r,
  required DateTime first,
  required DateTime from,
  required DateTime to,
  int limit = 1000,
}) {
  final out = <DateTime>[];
  if (r == Recurrence.none) {
    if (first.isBefore(to.add(const Duration(seconds: 1))) &&
        first.isAfter(from.subtract(const Duration(seconds: 1)))) {
      out.add(first);
    }
    return out;
  }
  var cur = _normalize(first);
  if (cur.isBefore(from)) {
    // Быстрый перемот на первый >= from.
    while (cur.isBefore(from) && out.length + 1 < limit) {
      cur = _advance(cur, r);
    }
  }
  while (!cur.isAfter(to) && out.length < limit) {
    if (!cur.isBefore(from)) out.add(_normalize(cur));
    cur = _advance(cur, r);
  }
  return out;
}

DateTime _normalize(DateTime d) =>
    DateTime(d.year, d.month, d.day, d.hour, d.minute);

DateTime _advance(DateTime d, Recurrence r) {
  switch (r) {
    case Recurrence.none:
      return d;
    case Recurrence.daily:
      return d.add(const Duration(days: 1));
    case Recurrence.weekly:
      return d.add(const Duration(days: 7));
    case Recurrence.monthly:
      var m = d.month + 1;
      var y = d.year;
      if (m > 12) { m = 1; y += 1; }
      return DateTime(y, m, _clampDay(d.day, y, m), d.hour, d.minute);
    case Recurrence.yearly:
      final y = d.year + 1;
      if (d.month == 2 && d.day == 29 && !_isLeap(y)) {
        return DateTime(y, 2, 28, d.hour, d.minute);
      }
      return DateTime(y, d.month, _clampDay(d.day, y, d.month), d.hour, d.minute);
  }
}

int _clampDay(int day, int year, int month) {
  final max = daysInMonth(year, month);
  return day > max ? max : day;
}

/// Ближайшая годовщина (день-месяц) после [from].
DateTime nextAnniversary(int month, int day, DateTime from) {
  final cand = DateTime(from.year, month, _clampDay(day, from.year, month));
  if (cand.isBefore(DateTime(from.year, from.month, from.day))) {
    return DateTime(from.year + 1, month, _clampDay(day, from.year + 1, month));
  }
  return cand;
}

/// Сколько лет прошло с [since] до [now] (годовщина).
int yearsSince(DateTime since, DateTime now) =>
    now.year - since.year - (now.month < since.month ||
            (now.month == since.month && now.day < since.day)
        ? 1
        : 0);

/// Правила напоминаний: сдвиги в минутах до начала (все >= 0).
class ReminderRules {
  final List<int> offsetsMin;
  const ReminderRules(this.offsetsMin);

  static const List<int> defaults = [1440, 60, 15]; // за 1 день, 1 час, 15 мин

  static ReminderRules parse(String? csv) {
    if (csv == null || csv.trim().isEmpty) return const ReminderRules(defaults);
    final parts = csv.split(',').where((s) => s.trim().isNotEmpty);
    if (parts.isEmpty) return const ReminderRules(defaults);
    return ReminderRules([
      for (final p in parts)
        (int.tryParse(p.trim()) ?? 0),
    ].where((m) => m >= 0).toList());
  }

  /// Моменты срабатывания для события с началом [start].
  List<DateTime> fireTimes(DateTime start) =>
      [for (final m in offsetsMin) start.subtract(Duration(minutes: m))]
        ..sort((a, b) => a.compareTo(b));
}

/// Событие календаря (доменная модель поверх CRDT-полей).
class CalEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final String? locationName;
  final double? lat;
  final double? lng;
  final String? timezone;
  final Recurrence recurrence;
  final ReminderRules reminders;
  final String? inviteStatus; // created|accepted|declined
  final String? ownerColor;
  final String? note;

  /// Device that created the event (additive; older events have none).
  final String? ownerId;

  /// When it was created, ms.
  final int? createdAt;

  /// Device that changed it last, and when (ms). Unset until first edit.
  final String? editedBy;
  final int? editedAt;

  /// «Вместе»: belongs to both, drawn as two halves.
  final bool shared;

  CalEvent({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.allDay = false,
    this.locationName,
    this.lat,
    this.lng,
    this.timezone,
    this.recurrence = Recurrence.none,
    this.reminders = const ReminderRules(ReminderRules.defaults),
    this.inviteStatus,
    this.ownerColor,
    this.note,
    this.ownerId,
    this.createdAt,
    this.editedBy,
    this.editedAt,
    this.shared = false,
  });

  CalEvent copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    Recurrence? recurrence,
    ReminderRules? reminders,
    String? note,
    String? editedBy,
    int? editedAt,
    bool? shared,
  }) =>
      CalEvent(
        id: id,
        title: title ?? this.title,
        start: start ?? this.start,
        end: end ?? this.end,
        allDay: allDay ?? this.allDay,
        locationName: locationName,
        lat: lat,
        lng: lng,
        timezone: timezone,
        recurrence: recurrence ?? this.recurrence,
        reminders: reminders ?? this.reminders,
        inviteStatus: inviteStatus,
        ownerColor: ownerColor,
        note: note ?? this.note,
        ownerId: ownerId,
        createdAt: createdAt,
        editedBy: editedBy ?? this.editedBy,
        editedAt: editedAt ?? this.editedAt,
        shared: shared ?? this.shared,
      );

  /// Разобрать из полей CRDT-реплики. `null`, если обязательных полей нет.
  static CalEvent? fromFields(String id, Map<String, String> f) {
    final startMs = int.tryParse(f['startTs'] ?? '');
    if (startMs == null) return null;
    final endMs = int.tryParse(f['endTs'] ?? '');
    return CalEvent(
      id: id,
      title: f['title'] ?? id,
      start: DateTime.fromMillisecondsSinceEpoch(startMs),
      end: endMs == null ? null : DateTime.fromMillisecondsSinceEpoch(endMs),
      allDay: f['allDay'] == '1',
      locationName: f['locName'],
      lat: double.tryParse(f['lat'] ?? ''),
      lng: double.tryParse(f['lng'] ?? ''),
      timezone: f['tz'],
      recurrence: parseRecurrence(f['recur']),
      reminders: ReminderRules.parse(f['remind']),
      inviteStatus: f['invite'],
      ownerColor: f['color'],
      // An edit that removed the note writes '' (fields are never deleted).
      note: (f['note'] ?? '').isEmpty ? null : f['note'],
      ownerId: f['owner'],
      createdAt: int.tryParse(f['createdAt'] ?? ''),
      editedBy: f['editedBy'],
      editedAt: int.tryParse(f['editedAt'] ?? ''),
      shared: f['shared'] == '1',
    );
  }

  /// Поля для записи в CRDT-реплику.
  Map<String, String> toFields() => {
        'title': title,
        'startTs': '${start.millisecondsSinceEpoch}',
        if (end != null) 'endTs': '${end!.millisecondsSinceEpoch}',
        'allDay': allDay ? '1' : '0',
        if (locationName != null) 'locName': locationName!,
        if (lat != null) 'lat': lat!.toStringAsFixed(6),
        if (lng != null) 'lng': lng!.toStringAsFixed(6),
        if (timezone != null) 'tz': timezone!,
        'recur': recurrence.name,
        'remind': reminders.offsetsMin.join(','),
        if (inviteStatus != null) 'invite': inviteStatus!,
        if (ownerColor != null) 'color': ownerColor!,
        if (note != null) 'note': note!,
        if (ownerId != null) 'owner': ownerId!,
        if (createdAt != null) 'createdAt': '$createdAt',
        if (editedBy != null) 'editedBy': editedBy!,
        if (editedAt != null) 'editedAt': '$editedAt',
        'shared': shared ? '1' : '0',
      };
}

/// События календаря в пределах [from, to] с учётом recurrence.
List<(CalEvent, DateTime)> expand(
    List<CalEvent> events, DateTime from, DateTime to, {int limit = 500}) {
  final out = <(CalEvent, DateTime)>[];
  for (final e in events) {
    if (e.recurrence == Recurrence.none) {
      if (!e.start.isAfter(to) && !e.start.isBefore(from)) out.add((e, e.start));
    } else {
      for (final occ in occurrences(
          r: e.recurrence, first: e.start, from: from, to: to, limit: limit)) {
        out.add((e, occ));
      }
    }
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

/// «Сегодня»: события от [now] до [now + days].
List<(CalEvent, DateTime)> upcoming(List<CalEvent> events, DateTime now,
    {int days = 3, int limit = 50}) =>
    expand(events, now, now.add(Duration(days: days)), limit: limit);

/// Репозиторий календаря поверх [Replica] (local-first).
class CalendarRepo {
  final Replica replica;
  CalendarRepo(this.replica);

  static const String _p = 'evt:';

  void upsert(CalEvent e) {
    for (final entry in e.toFields().entries) {
      replica.set(_p + e.id, entry.key, entry.value);
    }
  }

  /// Saves an edited event. Unlike [upsert], a field the edit emptied (the
  /// note, the end date) is written as '' — fields are never deleted in the
  /// CRDT, so silence would keep the old value. Additive: '' reads as none.
  void edit(CalEvent e) {
    upsert(e);
    if (e.note == null) replica.set(_p + e.id, 'note', '');
    if (e.end == null) replica.set(_p + e.id, 'endTs', '');
  }

  void remove(String id) => replica.delete(_p + id);

  CalEvent? get(String id) {
    final f = replica.entity(_p + id);
    return f == null ? null : CalEvent.fromFields(id, f);
  }

  List<CalEvent> all() {
    final out = <CalEvent>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(_p)) continue;
      final ev = CalEvent.fromFields(e.key.substring(_p.length), e.value);
      if (ev != null) out.add(ev);
    }
    return out;
  }

  List<(CalEvent, DateTime)> upcoming(DateTime now, {int days = 3, int limit = 50}) =>
      expand(all(), now, now.add(Duration(days: days)), limit: limit);

  List<(CalEvent, DateTime)> range(DateTime from, DateTime to) =>
      expand(all(), from, to);
}
