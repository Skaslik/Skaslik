/// Hybrid logical clock: a write made after seeing the partner's write must
/// win over it, even within the same millisecond (I8: nothing gets lost).
library;

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  test('a write after seeing the partner wins, even in the same ms', () {
    // Both phones' clocks read the same millisecond.
    int stuck() => 1000;
    // The later writer has the "smaller" device id and the lower counter —
    // exactly what used to make its newer write lose.
    final mikhail = Replica('z-mikhail', clock: stuck);
    final sofia = Replica('a-sofia', clock: stuck);

    mikhail.set('item:bread', 'done', '0');
    mikhail.set('item:bread', 'text', 'Хлеб');
    sofia.mergeIn(mikhail.allOps());
    sofia.set('item:bread', 'done', '1'); // she ticks it

    mikhail.mergeIn(sofia.allOps());
    expect(sofia.entity('item:bread')!['done'], '1');
    expect(mikhail.entity('item:bread')!['done'], '1');
  });

  test('a delete after seeing the partner wins, even in the same ms', () {
    int stuck() => 1000;
    final a = Replica('z', clock: stuck);
    final b = Replica('a', clock: stuck);
    a.set('note:1', 'text', 'x');
    a.set('note:1', 'text', 'y');
    b.mergeIn(a.allOps());
    b.delete('note:1');
    a.mergeIn(b.allOps());
    expect(a.contains('note:1'), isFalse);
    expect(b.contains('note:1'), isFalse);
  });

  test('restoring a snapshot also counts as having seen those writes', () {
    int stuck() => 1000;
    final a = Replica('z', clock: stuck);
    a.set('e', 'f', '1');
    a.set('e', 'f', '2');
    final b = Replica('a', clock: stuck)..restore(a.snapshot());
    b.set('e', 'f', '3');
    a.mergeIn(b.allOps());
    expect(a.entity('e')!['f'], '3');
  });

  test('own writes in one ms stay ordered and the clock follows real time',
      () {
    var now = 1000;
    final r = Replica('x', clock: () => now);
    final o1 = r.set('e', 'f', '1');
    final o2 = r.set('e', 'f', '2');
    expect(r.entity('e')!['f'], '2');
    expect(o2.newerThan(o1.time, o1.seq, o1.deviceId), isTrue);
    now = 5000;
    expect(r.set('e', 'f', '3').time, 5000);
  });

  test('concurrent writes (nobody saw the other) still converge', () {
    int stuck() => 1000;
    final a = Replica('z', clock: stuck);
    final b = Replica('a', clock: stuck);
    a.set('e', 'f', 'from-a');
    b.set('e', 'f', 'from-b');
    a.mergeIn(b.allOps());
    b.mergeIn(a.allOps());
    expect(a.entity('e')!['f'], b.entity('e')!['f']);
  });
}
