/// L3 disk-sync: два устройства, один «диск», сходящиеся состояния.
library;

import 'dart:typed_data';

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

/// In-memory blob-хранилище (фейк Яндекс.Диска).
class _MemStore implements BlobStore {
  final Map<String, Uint8List> files = {};
  bool ok = true;

  @override
  Future<bool> ping() async => ok;
  @override
  Future<void> upload({required String path, required List<int> bytes}) async {
    if (!ok) throw StateError('unavailable');
    files[path] = Uint8List.fromList(bytes);
  }

  @override
  Future<List<int>> download(String path) async {
    final f = files[path];
    if (f == null) throw YandexDiskError(YandexDiskErrorCode.notFound, path);
    return f;
  }

  @override
  Future<void> ensureDir(String path) async {}
}

Future<(DevicePairing, DevicePairing, Uint8List, String)> _pair() async {
  final pairA = await createDevicePairing();
  final pairB = await createDevicePairing();
  const s = 'sun rise moon night';
  final res = await pairFromPeerBytes(pairA, pairB.pub.bytes, s);
  final syncKey = await syncKeyFromMaster(res.master);
  final familyId = familyIdFromMaster(res.master);
  return (pairA, pairB, syncKey, familyId);
}

void main() {
  group('DiskSync (L3, Я.Диск)', () {
    test('A публикует → B fetch: состояния совпали', () async {
      final store = _MemStore();
      final (pairA, pairB, syncKey, familyId) = await _pair();
      final devA = deviceIdForPub(pairA.pub.bytes);
      final devB = deviceIdForPub(pairB.pub.bytes);
      expect(devA, isNot(devB));

      final syncA = DiskSync(
          store: store, syncKey: syncKey, familyId: familyId,
          deviceId: devA, peerDeviceId: devB, domain: 'calendar');
      final syncB = DiskSync(
          store: store, syncKey: syncKey, familyId: familyId,
          deviceId: devB, peerDeviceId: devA, domain: 'calendar');

      final ra = Replica(devA);
      ra.set('e1', 'title', 'Ужин');
      ra.set('e1', 'where', 'дом');
      ra.set('e2', 'title', 'Врач');
      await syncA.publish(ra);

      final rb = Replica(devB);
      final n = await syncB.fetch(rb);
      expect(n, 3);
      expect(rb.view(), ra.view(), reason: 'B не совпало с A после fetch');
      expect(rb.entity('e1')?['title'], 'Ужин');
      expect(rb.entity('e2')?['title'], 'Врач');
    });

    test('итеративный: A пишет после fetch B → B догнал', () async {
      final store = _MemStore();
      final (pairA, pairB, syncKey, familyId) = await _pair();
      final devA = deviceIdForPub(pairA.pub.bytes);
      final devB = deviceIdForPub(pairB.pub.bytes);

      final syncA = DiskSync(
          store: store, syncKey: syncKey, familyId: familyId,
          deviceId: devA, peerDeviceId: devB, domain: 'banks');
      final syncB = DiskSync(
          store: store, syncKey: syncKey, familyId: familyId,
          deviceId: devB, peerDeviceId: devA, domain: 'banks');

      final ra = Replica(devA, clock: () => 2000, initialTime: 2000);
      final rb = Replica(devB, clock: () => 1000, initialTime: 1000);

      rb.set('b1', 'name', 'На отпуск');
      rb.set('b1', 'total', '1000');
      await syncB.publish(rb);
      await syncA.fetch(ra);

      ra.set('b1', 'total', '1500');
      await syncA.publish(ra);
      await syncB.fetch(rb);

      expect(ra.view(), rb.view());
      expect(ra.entity('b1')?['total'], '1500');
      expect(rb.entity('b1')?['total'], '1500');
      expect(ra.entity('b1')?['name'], 'На отпуск');
    });

    test('domain-separation: файл другого домена не применим', () async {
      final store = _MemStore();
      final (pairA, pairB, syncKey, familyId) = await _pair();
      final devA = deviceIdForPub(pairA.pub.bytes);
      final devB = deviceIdForPub(pairB.pub.bytes);

      final syncA = DiskSync(
          store: store, syncKey: syncKey, familyId: familyId,
          deviceId: devA, peerDeviceId: devB, domain: 'banks');
      final ra = Replica(devA);
      ra.set('b1', 'name', 'секрет');
      await syncA.publish(ra);

      final syncB = DiskSync(
          store: store, syncKey: syncKey, familyId: familyId,
          deviceId: devB, peerDeviceId: devA, domain: 'calendar');
      final rb = Replica(devB);
      await expectLater(syncB.fetch(rb), throwsA(anything),
          reason: 'конверт банков нельзя применить как календарь');
    });

    test('пути различны, семейный каталог общий', () async {
      final (pairA, pairB, syncKey, familyId) = await _pair();
      final devA = deviceIdForPub(pairA.pub.bytes);
      final devB = deviceIdForPub(pairB.pub.bytes);
      final syncA = DiskSync(
          store: _MemStore(), syncKey: syncKey, familyId: familyId,
          deviceId: devA, peerDeviceId: devB, domain: 'notes');
      final syncB = DiskSync(
          store: _MemStore(), syncKey: syncKey, familyId: familyId,
          deviceId: devB, peerDeviceId: devA, domain: 'notes');
      expect(familyId.length, 12);
      expect(syncA.ownPath, isNot(syncB.ownPath));
      expect(syncA.dir, syncB.dir);
    });
  });
}
