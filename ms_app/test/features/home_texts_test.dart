import 'package:flutter_test/flutter_test.dart';
import 'package:ms_app/core/pair/pair.dart';
import 'package:ms_app/core/sync/sync_service.dart';
import 'package:ms_app/design_system/ms_format.dart';
import 'package:ms_app/design_system/widgets/widgets.dart';
import 'package:ms_app/features/home/home_texts.dart';
import 'package:ms_core/ms_core.dart';

void main() {
  setUpAll(initMsFormat);

  const misha = Pair(
      me: kMichael, partner: kSofia, myDeviceId: 'A', partnerDeviceId: 'B');
  const sonya = Pair(
      me: kSofia, partner: kMichael, myDeviceId: 'B', partnerDeviceId: 'A');
  final at = DateTime(2026, 10, 8, 21, 14).millisecondsSinceEpoch;
  final seen = DateTime(2026, 10, 8, 21, 16).millisecondsSinceEpoch;

  test('greeting by hour', () {
    expect(greetingFor(DateTime(2026, 1, 1, 8)), 'Доброе утро');
    expect(greetingFor(DateTime(2026, 1, 1, 13)), 'Добрый день');
    expect(greetingFor(DateTime(2026, 1, 1, 21)), 'Добрый вечер');
    expect(greetingFor(DateTime(2026, 1, 1, 2)), 'Доброй ночи');
  });

  group('candle row (IMPLEMENTATION table)', () {
    test('partner', () {
      final t = candleRowText(
          CandleInfo(state: CandleState.partner, litBy: 'B', litAt: at), misha);
      expect(t.title, 'Свеча горит · зажгла София');
      expect(t.meta, '21:14 · погаснет в полночь');
      final m = candleRowText(
          CandleInfo(state: CandleState.partner, litBy: 'A', litAt: at), sonya);
      expect(m.title, 'Свеча горит · зажёг Михаил');
    });

    test('pending', () {
      final t = candleRowText(
          CandleInfo(state: CandleState.pending, litBy: 'A', litAt: at), misha);
      expect(t.title, 'Горит у тебя');
      expect(t.meta, '◐ у Сони загорится при связи');
    });

    test('both', () {
      final t = candleRowText(
          CandleInfo(
              state: CandleState.both, litBy: 'A', litAt: at, seenAt: seen),
          misha);
      expect(t.title, 'Горит у обоих');
      expect(t.meta, 'Соня увидела · 21:16');
    });

    test('off', () {
      final t = candleRowText(const CandleInfo(state: CandleState.off), misha);
      expect(t.title, 'Свеча не горит');
      expect(t.meta, 'нажми на свечу — загорится и у Сони');
    });
  });

  test('sync pill: glyph kind with a word', () {
    expect(syncPill(SyncState.synced), (kind: MsSyncKind.ok, label: 'синхр.'));
    expect(syncPill(SyncState.error).kind, MsSyncKind.error);
    expect(syncPill(SyncState.disconnected).kind, MsSyncKind.offline);
  });

  test('date sub-label and event meta', () {
    final now = DateTime(2026, 10, 8, 9);
    expect(dateSub(DateTime(2026, 10, 8, 19), now), 'сегодня');
    expect(dateSub(DateTime(2026, 10, 9), now), 'завтра');
    expect(dateSub(DateTime(2026, 10, 10), now), 'сб');
    final e = CalEvent(
        id: 'e',
        title: 'Годовщина',
        start: DateTime(2026, 10, 10),
        allDay: true,
        recurrence: Recurrence.yearly);
    expect(eventMeta(e, e.start), 'весь день · каждый год');
  });

  test('pair: legacy «local» entries count as mine', () {
    expect(misha.isMine('local'), isTrue);
    expect(misha.isMine('A'), isTrue);
    expect(misha.memberOf('B'), kSofia);
    expect(kSofia.initial, 'С.');
  });
}
