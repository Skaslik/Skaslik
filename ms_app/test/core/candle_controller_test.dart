import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ms_app/core/candle/candle_controller.dart';
import 'package:ms_app/core/pair/pair.dart';
import 'package:ms_app/core/sync/domain_store.dart';
import 'package:ms_core/ms_core.dart';

void main() {
  late Directory dir;
  final now = DateTime(2026, 10, 8, 21, 14);
  const pairA = Pair(
      me: kMichael, partner: kSofia, myDeviceId: 'A', partnerDeviceId: 'B');

  setUp(() => dir = Directory.systemTemp.createTempSync('ms_candle'));
  tearDown(() => dir.deleteSync(recursive: true));

  MsStore store(String id) =>
      MsStore(deviceId: id, domain: MsDomain.ritual, dataDir: '${dir.path}/$id');

  test('light → pending; put out → off; changes are persisted', () async {
    final s = store('A');
    final c = CandleController(
        store: s,
        pair: pairA,
        notified: MemoryCandleNotifiedStore(),
        clock: () => now);
    addTearDown(c.dispose);
    expect(c.info.state, CandleState.off);
    c.light();
    expect(c.info.state, CandleState.pending);
    expect(store('A').entity(CandleRepo.entityId)?['litBy'], 'A');
    c.putOut();
    expect(c.info.state, CandleState.off);
  });

  test('partner light after a merge: seen is written, notified once',
      () async {
    // София's phone lights the candle.
    final b = Replica('B');
    CandleRepo(b).light('B', now.millisecondsSinceEpoch);

    final s = store('A');
    final notified = MemoryCandleNotifiedStore();
    final heard = <String>[];
    final c = CandleController(
      store: s,
      pair: pairA,
      notified: notified,
      clock: () => now,
      onPartnerLit: (by) => heard.add('${by.name} ${by.verb('зажёг')} свечу'),
    );
    addTearDown(c.dispose);

    s.mergeRemote(b.allOps());
    expect(c.info.state, CandleState.partner);
    expect(heard, ['София зажгла свечу']);
    expect(s.entity(CandleRepo.entityId)?['seen:A'], isNotNull);

    // Back on София's phone the candle now burns «у обоих».
    b.mergeIn(s.allOps());
    expect(CandleRepo(b).state(me: 'B', partner: 'A', now: now).state,
        CandleState.both);

    // Another merge or an app restart does not repeat the notification.
    s.mergeRemote(b.allOps());
    final again = CandleController(
        store: s,
        pair: pairA,
        notified: notified,
        clock: () => now,
        onPartnerLit: (by) => heard.add('again'));
    addTearDown(again.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(heard, ['София зажгла свечу']);
  });
}
