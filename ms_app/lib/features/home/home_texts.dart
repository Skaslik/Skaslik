/// Words on the home screen, derived from state. Pure functions, tested.
library;

import 'package:ms_core/ms_core.dart';

import '../../core/pair/pair.dart';
import '../../core/sync/sync_service.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/widgets/ms_sync_status.dart';

/// «Доброе утро / Добрый день / Добрый вечер / Доброй ночи».
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Доброе утро';
  if (h >= 12 && h < 17) return 'Добрый день';
  if (h >= 17 && h < 23) return 'Добрый вечер';
  return 'Доброй ночи';
}

/// Title and meta of the candle status row (IMPLEMENTATION Phase 3 table).
({String title, String meta}) candleRowText(CandleInfo c, Pair pair) {
  final partner = pair.partner;
  String at(int? ms) =>
      ms == null ? '' : formatTime(DateTime.fromMillisecondsSinceEpoch(ms));
  switch (c.state) {
    case CandleState.partner:
      final by = pair.memberOf(c.litBy);
      return (
        title: 'Свеча горит · ${by.verb('зажёг')} ${by.name}',
        meta: '${at(c.litAt)} · погаснет в полночь',
      );
    case CandleState.pending:
      return (
        title: 'Горит у тебя',
        meta: '${MsSyncStatus.glyphOf(MsSyncKind.queue)} '
            'у ${partner.addressGenitive} загорится при связи',
      );
    case CandleState.both:
      return (
        title: 'Горит у обоих',
        meta: '${partner.addressName} ${partner.verb('увидел')} · ${at(c.seenAt)}',
      );
    case CandleState.off:
      return (
        title: 'Свеча не горит',
        meta: 'нажми на свечу — загорится и у ${partner.addressGenitive}',
      );
  }
}

/// Spoken candle state for the scene hotspot.
String candleSpoken(CandleInfo c, Pair pair) => switch (c.state) {
      CandleState.off => 'не горит',
      CandleState.pending => 'горит у тебя',
      CandleState.both => 'горит у обоих',
      CandleState.partner => () {
          final by = pair.memberOf(c.litBy);
          return 'горит, ${by.verb('зажёг')} ${by.name}';
        }(),
    };

/// Sync pill for the greeting row: glyph kind and word.
({MsSyncKind kind, String label}) syncPill(SyncState s) => switch (s) {
      SyncState.synced => (kind: MsSyncKind.ok, label: 'синхр.'),
      SyncState.syncing => (kind: MsSyncKind.queue, label: 'синхр…'),
      SyncState.error => (kind: MsSyncKind.error, label: 'ошибка'),
      SyncState.unpaired => (kind: MsSyncKind.offline, label: 'пара не готова'),
      SyncState.disconnected => (kind: MsSyncKind.offline, label: 'локально'),
    };

/// Date block sub-label: «сегодня», «завтра», else «пт».
String dateSub(DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'сегодня';
  if (diff == 1) return 'завтра';
  return formatWeekdayShort(day);
}
