/// L3-конверт: zero-knowledge blob. Проверки:
///  - два устройства пары расшифровывают конверт друг друга (операции сходятся);
///  - domain-separation: конверт другого домена не расшифровывается (AAD);
///  - подмена/битость отклоняется;
///  - deviceIdForPub детерминирован.
library;

import 'dart:typed_data';

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

Future<(DevicePairing, DevicePairing, Uint8List)> _pair() async {
  final pairA = await createDevicePairing();
  final pairB = await createDevicePairing();
  const s = 'alpha beta gamma delta';
  final res = await pairFromPeerBytes(pairA, pairB.pub.bytes, s);
  final syncKey = await syncKeyFromMaster(res.master);
  return (pairA, pairB, syncKey);
}

void main() {
  group('SyncBlob (L3 zero-knowledge)', () {
    test('A шифрует → B (та же семья) расшифровывает, ops сходятся', () async {
      final (pairA, pairB, syncKey) = await _pair();

      final replicaA = Replica(deviceIdForPub(pairA.pub.bytes));
      final op = replicaA.set('evt-1', 'title', 'Ужин');

      final blob =
          await sealSyncBlob(syncKey: syncKey, domain: 'calendar', ops: [op]);
      final decoded =
          await openSyncBlob(syncKey: syncKey, domain: 'calendar', sealed: blob);
      expect(decoded.length, 1);
      final d = decoded.single;
      expect(d.entityId, op.entityId);
      expect(d.field, op.field);
      expect(d.value, op.value);
      expect(d.kind, op.kind);
      expect(d.time, op.time);
      expect(d.seq, op.seq);
      expect(d.deviceId, op.deviceId);

      // Применили на B — состояние совпало.
      final replicaB = Replica(deviceIdForPub(pairB.pub.bytes));
      replicaB.mergeIn(decoded);
      expect(replicaB.entity('evt-1')?['title'], 'Ужин');
    });

    test('domain-separation: конверт другого домена не расшифровывается',
        () async {
      final (_, _, syncKey) = await _pair();

      final replica = Replica('dev-1');
      final op = replica.set('bank-1', 'name', 'На отпуск');
      final blob =
          await sealSyncBlob(syncKey: syncKey, domain: 'banks', ops: [op]);

      // Попытка открыть как календарь — AAD не совпадёт → исключение.
      await expectLater(
        openSyncBlob(syncKey: syncKey, domain: 'calendar', sealed: blob),
        throwsA(anything),
        reason: 'конверт банков нельзя применить как календарь',
      );
    });

    test('подмена/битость отклоняется (AEAD tag)', () async {
      final (_, _, syncKey) = await _pair();

      final replica = Replica('dev-1');
      final op = replica.set('note-1', 'body', 'hello');
      final blob =
          await sealSyncBlob(syncKey: syncKey, domain: 'notes', ops: [op]);
      // Повреждаем байт.
      final tampered = Uint8List.fromList(blob);
      tampered[10] ^= 0xFF;
      await expectLater(
        openSyncBlob(syncKey: syncKey, domain: 'notes', sealed: tampered),
        throwsA(anything),
        reason: 'AEAD должен отклонить подмену',
      );
    });

    test('deviceIdForPub детерминирован и различается по ключам', () async {
      final (pairA, pairB, _) = await _pair();
      final idA1 = deviceIdForPub(pairA.pub.bytes);
      final idA2 = deviceIdForPub(pairA.pub.bytes);
      final idB = deviceIdForPub(pairB.pub.bytes);
      expect(idA1, idA2, reason: 'один ключ → один id');
      expect(idA1 == idB, isFalse, reason: 'разные ключи → разные id');
      expect(idA1.length, 12);
    });
  });
}
