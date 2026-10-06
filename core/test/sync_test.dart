/// CRDT-тесты: convergence, idempotency, no-data-loss, tombstones, codec.
library;

import 'dart:math';

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

/// Управляемые часы: время управляется вручную → тесты детерминированы.
class ManualClock {
  int t = 1000;
  void tick([int by = 1]) => t += by;
  int call() => t;
}

void expectConverged(Replica a, Replica b) {
  final va = a.view();
  final vb = b.view();
  expect(va.length, vb.length, reason: 'разное число сущностей');
  final ids = <String>{...va.keys, ...vb.keys};
  for (final id in ids) {
    final fa = va[id];
    final fb = vb[id];
    expect(fa, isNotNull, reason: '$id не на A');
    expect(fb, isNotNull, reason: '$id не на B');
    expect(fa, fb, reason: '$id расходится: A=$fa B=$fb');
  }
}

void main() {
  group('LWW-регистры / convergence', () {
    test('разные поля одновременно → оба значения сохраняются', () {
      final clock = ManualClock();
      final a = Replica('A', clock: clock);
      final b = Replica('B', clock: clock);
      a.set('e1', 'title', 'Ужин');
      clock.tick();
      b.set('e1', 'place', 'Клиника');
      a.set('e1', 'time', '19:00');
      clock.tick();
      b.set('e1', 'title', 'Ужин с Сергеем');
      a.restore(b.snapshot());
      b.restore(a.snapshot());
      expectConverged(a, b);
      final e = a.entity('e1')!;
      expect(e['place'], 'Клиника');
      expect(e['time'], '19:00');
      expect(e['title']!.isNotEmpty, true);
    });

    test('одно поле одновременно → детерминированный LWW-победитель', () {
      final clock = ManualClock();
      final a = Replica('A', clock: clock);
      final b = Replica('B', clock: clock);
      a.set('e1', 'title', 'от A');
      clock.tick();
      b.set('e1', 'title', 'от B');
      a.restore(b.snapshot());
      b.restore(a.snapshot());
      expectConverged(a, b);
      // B записал позже по времени → B победитель (детерминированно).
      expect(a.entity('e1')!['title'], 'от B');
      expect(b.entity('e1')!['title'], 'от B');
    });

    test('одинаковое время (гонка в 1 мс) → тай-брейк по seq', () {
      // Оба устройства пишут в один и тот же момент времени.
      final a = Replica('A', clock: () => 5000, initialTime: 5000);
      final b = Replica('B', clock: () => 5000, initialTime: 5000);
      a.set('e1', 'title', 'от A');
      b.set('e1', 'title', 'от B');
      a.restore(b.snapshot());
      b.restore(a.snapshot());
      expectConverged(a, b);
      // time равны, seq равны (оба 1) → deviceId: 'B' > 'A' → победитель B.
      expect(a.entity('e1')!['title'], 'от B');
    });

    test('идемпотентность: повторный merge не меняет состояние', () {
      final a = Replica('A');
      final b = Replica('B');
      a.set('e1', 'x', '1');
      b.set('e1', 'y', '2');
      final snapA = a.snapshot();
      final snapB = b.snapshot();
      a.restore(snapB);
      b.restore(snapA);
      final before = a.view();
      a.restore(snapB);
      b.restore(snapA);
      a.restore(a.snapshot());
      b.restore(b.snapshot());
      expect(a.view(), before);
      expectConverged(a, b);
    });

    test('3 устройства, перекрёстный синк → сходимость, ничего не потеряно', () {
      final devices = ['A', 'B', 'C'];
      final reps = {for (final d in devices) d: Replica(d)};
      for (final d in devices) {
        reps[d]!.set('evt-$d', 'title', 'from $d');
      }
      for (var round = 0; round < 3; round++) {
        final snaps = {for (final d in devices) d: reps[d]!.snapshot()};
        for (final d in devices) {
          for (final other in devices) {
            if (other != d) reps[d]!.restore(snaps[other]!);
          }
        }
      }
      for (final d in devices) {
        expect(reps[d]!.entityCount, 3);
        for (final other in devices) {
          expect(reps[d]!.contains('evt-$other'), true);
        }
      }
      expectConverged(reps['A']!, reps['B']!);
      expectConverged(reps['B']!, reps['C']!);
    });

    test('lost update: B офлайн, потом синк → 8 сущностей, без потерь', () {
      final a = Replica('A');
      final b = Replica('B');
      for (var i = 0; i < 5; i++) {
        a.set('e$i', 'v', 'a$i');
      }
      for (var i = 0; i < 3; i++) {
        b.set('e10$i', 'v', 'b$i');
      }
      a.restore(b.snapshot());
      b.restore(a.snapshot());
      expectConverged(a, b);
      expect(a.entityCount, 8);
    });
  });

  group('Tombstones', () {
    test('удаление скрывает сущность', () {
      final a = Replica('A');
      a.set('e1', 'title', 'x');
      a.delete('e1');
      expect(a.contains('e1'), false);
      expect(a.view().containsKey('e1'), false);
    });

    test('удаление сходится', () {
      final a = Replica('A');
      final b = Replica('B');
      a.set('e1', 'title', 'x');
      b.restore(a.snapshot());
      a.delete('e1');
      a.restore(b.snapshot());
      b.restore(a.snapshot());
      expectConverged(a, b);
      expect(a.contains('e1'), false);
      expect(b.contains('e1'), false);
    });

    test('пересоздание после удаления (живое поле > tombstone) → сущность живёт', () {
      final clock = ManualClock();
      final a = Replica('A', clock: clock);
      a.set('e1', 'title', 'v1');
      clock.tick();
      a.delete('e1');
      clock.tick();
      a.set('e1', 'title', 'v2-reborn');
      expect(a.contains('e1'), true);
      final b = Replica('B');
      b.restore(a.snapshot());
      expectConverged(a, b);
      expect(b.entity('e1')!['title'], 'v2-reborn');
    });

    test('удаление «выше» пересоздания → сущность скрыта', () {
      final clock = ManualClock();
      final a = Replica('A', clock: clock);
      a.set('e1', 'title', 'v1');
      clock.tick();
      a.set('e1', 'title', 'v2');
      clock.tick();
      a.delete('e1');
      expect(a.contains('e1'), false);
      final b = Replica('B');
      b.restore(a.snapshot());
      expect(b.contains('e1'), false);
    });
  });

  group('OpCodec', () {
    test('roundtrip (set) с кириллицей и эмодзи', () {
      final op = Op(seq: 1, time: 123, deviceId: 'A', entityId: 'evt-1',
          field: 'title', value: 'Ужин 🍽 с семьёй', kind: 'set');
      final back = OpCodec.decode(OpCodec.encode(op));
      expect(back.seq, op.seq);
      expect(back.time, op.time);
      expect(back.deviceId, op.deviceId);
      expect(back.entityId, op.entityId);
      expect(back.field, op.field);
      expect(back.value, op.value);
      expect(back.kind, op.kind);
      expect(back.opId, op.opId);
    });

    test('roundtrip (delete)', () {
      final op = Op(seq: 9, time: 999, deviceId: 'B',
          entityId: 'evt-9', kind: 'delete');
      final back = OpCodec.decode(OpCodec.encode(op));
      expect(back.kind, 'delete');
      expect(back.entityId, 'evt-9');
      expect(back.time, 999);
    });

    test('batch roundtrip', () {
      final ops = [
        Op(seq: 1, time: 1, deviceId: 'A', entityId: 'a',
            field: 'f', value: '1', kind: 'set'),
        Op(seq: 2, time: 2, deviceId: 'B', entityId: 'b',
            field: 'g', value: '2', kind: 'set'),
        Op(seq: 3, time: 3, deviceId: 'A', entityId: 'a', kind: 'delete'),
      ];
      final decoded = OpCodec.decodeBatch(OpCodec.encodeBatch(ops));
      expect(decoded.length, ops.length);
      for (var i = 0; i < ops.length; i++) {
        expect(decoded[i].opId, ops[i].opId);
      }
    });

    test('кодек через merge: A→bytes→B сходится', () {
      final a = Replica('A');
      final b = Replica('B');
      a.set('e1', 'title', 'hello');
      a.set('e1', 'time', '10:00');
      final bytes = OpCodec.encodeBatch(a.allOps());
      b.mergeIn(OpCodec.decodeBatch(bytes));
      expectConverged(a, b);
      expect(b.entity('e1')!['title'], 'hello');
    });
  });

  group('Property-based', () {
    test('5 устройств, 500 ops, случайные операции → сходимость', () {
      final rng = Random(12345);
      const devices = ['A', 'B', 'C', 'D', 'E'];
      const entityPool = 20;
      const fields = ['title', 'time', 'place', 'note'];
      // Общее время, но у каждого устройства свой «поток» записей.
      int globalTime = 1000;
      final reps = {
        for (final d in devices)
          d: Replica(d, clock: () => globalTime, initialTime: 1000)
      };
      for (var step = 0; step < 500; step++) {
        final d = devices[rng.nextInt(devices.length)];
        final r = reps[d]!;
        final eid = 'e${rng.nextInt(entityPool)}';
        if (rng.nextDouble() < 0.12) {
          r.delete(eid);
        } else {
          r.set(eid, fields[rng.nextInt(fields.length)], 'v$step');
        }
        // Время идёт вперёд, но не каждый шаг — бывают записи «в один мс».
        if (rng.nextDouble() < 0.8) globalTime += 1;
      }
      for (var round = 0; round < 4; round++) {
        final snaps = {for (final d in devices) d: reps[d]!.snapshot()};
        for (final d in devices) {
          for (final o in devices) {
            if (o != d) reps[d]!.restore(snaps[o]!);
          }
        }
      }
      final ref = reps['A']!.view();
      for (final d in devices) {
        expect(reps[d]!.view(), ref, reason: '$d расходится');
      }
    });

    test('идемпотентность под нагрузкой', () {
      final rng = Random(999);
      final a = Replica('A');
      final b = Replica('B');
      for (var i = 0; i < 50; i++) {
        a.set('e${i % 10}', 'f', '${rng.nextInt(1000)}');
      }
      for (var i = 0; i < 50; i++) {
        b.set('e${i % 10}', 'g', '${rng.nextInt(1000)}');
      }
      final sa = a.snapshot();
      final sb = b.snapshot();
      a.restore(sb);
      b.restore(sa);
      final after = a.view();
      for (var i = 0; i < 5; i++) {
        a.restore(sb);
        b.restore(sa);
        a.restore(a.snapshot());
        b.restore(b.snapshot());
      }
      expect(a.view(), after);
      expectConverged(a, b);
    });
  });

  group('deltaAfter', () {
    test('вернёт только операции с seq > afterSeq', () {
      final a = Replica('A');
      a.set('e1', 'x', '1');
      a.set('e2', 'y', '2');
      a.set('e3', 'z', '3');
      final delta = a.deltaAfter(2);
      expect(delta.length, 1);
      expect(delta.single.entityId, 'e3');
    });
  });
}
