/// Shared candle (room): lit on one phone, burns on both after sync.
library;

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  // 2026-10-08 21:14 local.
  final evening = DateTime(2026, 10, 8, 21, 14);
  int ms(DateTime d) => d.millisecondsSinceEpoch;

  late Replica a, b; // A = Михаил's phone, B = София's phone
  late CandleRepo ca, cb;

  setUp(() {
    a = Replica('A');
    b = Replica('B');
    ca = CandleRepo(a);
    cb = CandleRepo(b);
  });

  void syncAB() {
    b.mergeIn(a.allOps());
    a.mergeIn(b.allOps());
    b.mergeIn(a.snapshot().ops);
    a.mergeIn(b.snapshot().ops);
  }

  CandleState onA(DateTime now) =>
      ca.state(me: 'A', partner: 'B', now: now).state;
  CandleState onB(DateTime now) =>
      cb.state(me: 'B', partner: 'A', now: now).state;

  test('never lit → off', () {
    expect(onA(evening), CandleState.off);
  });

  test('lit by me, not yet seen → pending; partner sees it lit by partner',
      () {
    ca.light('A', ms(evening));
    expect(onA(evening), CandleState.pending);
    syncAB();
    final info = cb.state(me: 'B', partner: 'A', now: evening);
    expect(info.state, CandleState.partner);
    expect(info.litBy, 'A');
    expect(info.litAt, ms(evening));
  });

  test('partner marks seen → both on my side, with the seen time', () {
    ca.light('A', ms(evening));
    syncAB();
    final seen = evening.add(const Duration(minutes: 2));
    cb.markSeen('B', ms(seen));
    syncAB();
    final info = ca.state(me: 'A', partner: 'B', now: seen);
    expect(info.state, CandleState.both);
    expect(info.seenAt, ms(seen));
  });

  test('markSeen is a no-op for my own light and when already seen', () {
    ca.light('A', ms(evening));
    final before = a.allOps().length;
    ca.markSeen('A', ms(evening));
    expect(a.allOps().length, before);
    syncAB();
    cb.markSeen('B', ms(evening) + 1);
    final after = b.allOps().length;
    cb.markSeen('B', ms(evening) + 2);
    expect(b.allOps().length, after);
  });

  test('put out by either → off on both', () {
    ca.light('A', ms(evening));
    syncAB();
    cb.putOut('B', ms(evening) + 1000);
    syncAB();
    expect(onA(evening), CandleState.off);
    expect(onB(evening), CandleState.off);
  });

  test('goes out at local midnight', () {
    ca.light('A', ms(evening));
    expect(onA(DateTime(2026, 10, 8, 23, 59)), CandleState.pending);
    expect(onA(DateTime(2026, 10, 9, 0, 0)), CandleState.off);
  });

  test('relight after out → pending again; the old seen does not count', () {
    ca.light('A', ms(evening));
    syncAB();
    cb.markSeen('B', ms(evening) + 1);
    syncAB();
    ca.putOut('A', ms(evening) + 2000);
    ca.light('A', ms(evening) + 3000);
    syncAB();
    expect(onA(evening), CandleState.pending);
  });

  test('concurrent light and put-out converge to the same state', () {
    ca.light('A', ms(evening));
    syncAB();
    // Offline on both: A relights later, B puts out earlier.
    ca.light('A', ms(evening) + 5000);
    cb.putOut('B', ms(evening) + 4000);
    syncAB();
    expect(onA(evening), CandleState.pending);
    expect(onB(evening), CandleState.partner);
  });
}
