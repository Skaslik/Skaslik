/// Синхронизация данных «МС» (L3: Яндекс.Диск).
///
/// Оркестрирует [DiskSync] для каждого домена поверх [YandexBlobStore]:
///  - публикует свой (зашифрованный) снапшот в свой файл;
///  - скачивает файл партнёра, расшифровывает и применяет к [MsStore]
///    (CRDT merge → сходящиеся состояния, idempotent).
///
/// Zero-knowledge: на диск уходит только шифртекст (см. [DiskSync]).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ms_core/ms_core.dart';

import '../family/family.dart';
import 'domain_store.dart';
import 'yandex_auth.dart';

/// Статус синхронизации (для UI-индикатора).
enum SyncState {
  /// Нет подключённого Яндекс.Диска.
  disconnected,
  /// Подключено, но пара ещё не завершена (нет partner).
  unpaired,
  /// Идёт синхронизация.
  syncing,
  /// Синхронизировано.
  synced,
  /// Ошибка.
  error,
}

/// Оркестратор L3-синхронизации.
class SyncService extends ChangeNotifier {
  SyncService();

  /// One global for the app's lifetime (like [Family]): a provider scope
  /// going away must not kill it for everyone else.
  @override
  // ignore: must_call_super
  void dispose() {}

  final YandexAuth _auth = YandexAuth.instance;
  late Uint8List _syncKey;
  late String _familyId;
  String? _peerDeviceId;
  YandexBlobStore? _store;

  SyncState _state = SyncState.disconnected;
  String? _detail;

  SyncState get state => _state;
  String? get detail => _detail;

  bool get connected => _store != null;

  void _setState(SyncState s, [String? detail]) {
    _state = s;
    _detail = detail;
    notifyListeners();
  }

  /// Попробовать восстановить соединение из сохранённого токена.
  Future<void> init() async {
    await _auth.load();
    if (!_auth.hasToken) return;
    await _connect();
  }

  /// Подключиться (есть ли токен — проверяем).
  Future<void> connect() async {
    await _auth.load();
    if (!_auth.hasToken) {
      _setState(SyncState.disconnected, 'нет подключения');
      return;
    }
    await _connect();
  }

  Future<void> _connect() async {
    final token = _auth.accessToken;
    if (token == null) return;
    _store = YandexBlobStore(YandexDiskClient(token));
    final fam = family;
    final master = await fam.master();
    if (master == null) {
      _setState(SyncState.unpaired, 'пара не завершена');
      return;
    }
    _syncKey = await syncKeyFromMaster(master);
    _familyId = familyIdFromMaster(master);
    final peer = fam.peerPubBytes;
    _peerDeviceId = peer == null ? null : deviceIdForPub(peer);
    if (_peerDeviceId == null) {
      _setState(SyncState.unpaired, 'подключите второго устройства');
    } else {
      _setState(SyncState.synced, 'подключено');
    }
  }

  /// Запустить OAuth-авторизацию (браузер → loopback → токены).
  Future<void> login() async {
    try {
      await _auth.authorize();
      await _connect();
    } catch (e) {
      _setState(SyncState.disconnected, '$e');
      rethrow;
    }
  }

  /// Отключиться (удалить токены).
  Future<void> logout() async {
    await _auth.disconnect();
    _store = null;
    _peerDeviceId = null;
    _setState(SyncState.disconnected, 'отключено');
  }

  /// Полный цикл синхронизации доменов: publish свой снапшот, fetch партнёра.
  ///
  /// [stores] — живые экземпляры [MsStore] (из Riverpod-провайдеров), чтобы
  /// применённые удалённые операции попали в наблюдаемые виджеты.
  /// Возвращает общее число применённых удалённых операций.
  Future<int> syncAll(Map<MsDomain, MsStore> stores) async {
    final store = _store;
    if (store == null) {
      _setState(SyncState.disconnected, 'нет подключения');
      return 0;
    }
    if (_peerDeviceId == null) {
      _setState(SyncState.unpaired, 'пара не завершена');
      return 0;
    }
    _setState(SyncState.syncing, 'синхронизация…');
    var applied = 0;
    try {
      // Убедиться, что семейный каталог на диске существует.
      await store.ensureDir('/МС/$_familyId');
      for (final entry in stores.entries) {
        final domain = entry.key;
        final msStore = entry.value;
        final ds = _diskSync(domain, store);
        await ds.publish(msStore.replica);
        try {
          final ops = await ds.fetchOps();
          msStore.mergeRemote(ops);
          applied += ops.length;
        } on YandexDiskError catch (e) {
          // Файл партнёра ещё нет — нормально (он ещё не синхронизировался).
          if (e.code != YandexDiskErrorCode.notFound) rethrow;
        }
      }
      _setState(SyncState.synced, 'обновлено');
    } on YandexDiskError catch (e) {
      _setState(SyncState.error, 'Я.Диск: ${e.code.name}');
      rethrow;
    } catch (e) {
      _setState(SyncState.error, '$e');
      rethrow;
    }
    return applied;
  }

  DiskSync _diskSync(MsDomain domain, YandexBlobStore store) => DiskSync(
        store: store,
        syncKey: _syncKey,
        familyId: _familyId,
        deviceId: family.deviceId ?? 'local',
        peerDeviceId: _peerDeviceId!,
        domain: domain.name,
      );
}

/// Глобальный экземпляр (singleton).
final SyncService syncService = SyncService();
