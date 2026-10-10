/// L3: синхронизация через blob-хранилище (Яндекс.Диск) — zero-knowledge.
///
/// Каждый участник пары хранит **свой** зашифрованный снапшот домена в своём
/// файле под общим семейным каталогом:
///
///   /МС/<familyId>/<deviceId>.json
///
///   * `familyId` — `shortHex(master, 12)`: оба устройства знают `master`
///     (pairing), поэтому попадают в один каталог.
///   * `deviceId` — `deviceIdForPub(публичный pairing-ключ)`: детерминированно
///     различается у каждого устройства.
///
/// Файл — [SyncBlob] (XChaCha20-Poly1305): Яндекс/взлом диска видит только
/// шифртекст. Получатель расшифровывает своим [syncKey] и [Replica.mergeIn]
/// (идемпотентный CRDT) → сходящиеся состояния без центрального сервера.
library;

import 'dart:typed_data';

import '../crypto/primitives.dart';
import '../integrations/yandex_disk.dart';
import 'replica.dart';
import 'sync_blob.dart';

/// Абстракция blob-хранилища (загрузка/скачивание файлов).
///
/// В проде — [YandexBlobStore] (Яндекс.Диск). В тестах — in-memory фейк.
abstract class BlobStore {
  /// Доступен ли хранилище прямо сейчас (есть токен/сеть).
  Future<bool> ping();

  /// Загрузить [bytes] по пути [path] (перезаписать).
  Future<void> upload({required String path, required List<int> bytes});

  /// Скачать файл по пути [path].
  Future<List<int>> download(String path);

  /// Убедиться, что каталог [path] существует (идемпотентно).
  /// По умолчанию — no-op (в in-memory фейках каталоги не нужны).
  Future<void> ensureDir(String path) async {}
}

/// [BlobStore] поверх Яндекс.Диска (bearer-токен, chunked upload).
class YandexBlobStore implements BlobStore {
  YandexBlobStore(this._client);
  final YandexDiskClient _client;

  @override
  Future<bool> ping() => _client.ping();
  @override
  Future<void> upload({required String path, required List<int> bytes}) =>
      _client.upload(path: path, bytes: bytes);
  @override
  Future<List<int>> download(String path) => _client.download(path);
  @override
  Future<void> ensureDir(String path) => _client.mkdir(path);
}


/// Синхронизация одного домена через [BlobStore].
class DiskSync {
  DiskSync({
    required this.store,
    required this.syncKey,
    required this.familyId,
    required this.deviceId,
    required this.peerDeviceId,
    required this.domain,
  });

  final BlobStore store;
  final Uint8List syncKey;
  final String familyId;
  final String deviceId;
  final String peerDeviceId;
  final String domain;

  /// Семейный каталог на диске (общий для обоих устройств).
  String get dir => '/МС/$familyId';

  /// Путь к собственному файлу снапшота.
  String get ownPath => '$dir/$deviceId.json';

  /// Путь к файлу партнёра.
  String get peerPath => '$dir/$peerDeviceId.json';

  /// Доступен ли транспорт (есть токен/сеть).
  Future<bool> isAvailable() => store.ping();

  /// Опубликовать снапшот [replica] в свой файл.
  Future<void> publish(Replica replica) async {
    final sealed = await sealSyncBlob(
        syncKey: syncKey, domain: domain, ops: replica.snapshot().ops);
    await store.upload(path: ownPath, bytes: sealed);
  }

  /// Скачать файл партнёра и расшифровать операции (без применения).
  ///
  /// Вызывающий сам решает, куда применить (например, [MsStore.mergeRemote],
  /// чтобы записать на диск и уведомить UI). Если файла ещё нет —
  /// [YandexDiskError] (notFound).
  Future<List<Op>> fetchOps() async {
    final bytes = Uint8List.fromList(await store.download(peerPath));
    return openSyncBlob(syncKey: syncKey, domain: domain, sealed: bytes);
  }

  /// Скачать файл партнёра и применить операции к [replica].
  ///
  /// Возвращает число применённых операций. Если файла ещё нет —
  /// [YandexDiskError] (notFound).
  Future<int> fetch(Replica replica) async {
    final ops = await fetchOps();
    replica.mergeIn(ops);
    return ops.length;
  }
}

/// `familyId = bytesToHex(master).substring(0, 12)` — общий для обоих устройств.
String familyIdFromMaster(Uint8List master) =>
    bytesToHex(master).substring(0, 12);
