/// Sync Engine: транспортная абстракция (L1/L2/L3) + статусы + конверт.
///
/// Архитектура zero-knowledge: по транспорту ходят только зашифрованные blob'ы.
/// Конкретные контуры (BLE, WebRTC, Yandex.Disk) реализуются в app-слое; здесь
/// — контракт и оркестрация.
library;

import 'dart:async';


/// Статус синхронизации (для UI-индикатора).
enum SyncStatus { synced, pending, offline }

/// Вид контура.
enum TransportKind { ble, webrtc, disk }

/// Контур передачи (реализуется в app-слое).
///
/// `send` — передать байты партнёру (идемпотентно, с дедупликацией на
/// принимающей стороне). `wake` — разбудить партнёра (ntfy-сигнал), если
/// поддерживается; может быть no-op.
abstract class Transport {
  Transport(this.id);
  final TransportKind id;

  /// Доступен ли контур прямо сейчас.
  Future<bool> isAvailable();

  /// Передать байты партнёру.
  Future<void> send(List<int> data);

  /// Подписаться на входящие от партнёра.
  Stream<List<int>> incoming();

  /// Разбудить партнёра (best-effort, опционально).
  Future<void> wake();

  Future<void> close();
}

/// Конверт данных (что передаём по L1/L2/L3).
///
/// Содержит только зашифрованный blob + служебные метки (домен, seq). Партнёр
/// расшифровывает своим per-domain ключом.
class SyncEnvelope {
  final String domain; // календарь/копилки/...
  final int fromSeq;
  final int toSeq;
  final List<int> ciphertext;
  const SyncEnvelope({
    required this.domain,
    required this.fromSeq,
    required this.toSeq,
    required this.ciphertext,
  });
}

/// Оркестратор синхронизации: управляет цепочкой контуров, очередью, статусом.
///
/// На S0 это контракт + тесты оркестрации (с фейковым транспортом). Реальные
/// BLE/WebRTC/Я.Диск — app-слой.
class SyncEngine {
  final List<Transport> transports; // в порядке приоритета
  final StreamController<SyncStatus> _status = StreamController.broadcast();
  SyncStatus _statusValue = SyncStatus.synced;
  final List<List<int>> _outbox = []; // ожидающие передачи (idempotent)
  int _pending = 0;

  SyncEngine({required this.transports});

  Stream<SyncStatus> get status => _status.stream;
  SyncStatus get current => _statusValue;
  int get pending => _pending;

  void _setStatus(SyncStatus s) {
    if (_statusValue == s) return;
    _statusValue = s;
    _status.add(s);
  }

  /// Поставить байты в очередь исходящих (идемпотентно по содержимому).
  void enqueue(List<int> data) {
    if (_outbox.contains(data)) return;
    _outbox.add(data);
    _pending = _outbox.length;
    _setStatus(_outbox.isEmpty ? SyncStatus.synced : SyncStatus.pending);
  }

  /// Попробовать доставить очередь по первому доступному контуру.
  /// Возвращает true, если всё доставлено.
  Future<bool> flush() async {
    if (_outbox.isEmpty) {
      _setStatus(SyncStatus.synced);
      return true;
    }
    for (final t in transports) {
      try {
        if (!await t.isAvailable()) continue;
        for (final chunk in _outbox) {
          await t.send(chunk);
        }
        _outbox.clear();
        _pending = 0;
        _setStatus(SyncStatus.synced);
        return true;
      } catch (_) {
        // Контур не сработал — пробовать следующий.
      }
    }
    // Ни один контур не доступен → офлайн-ожидание.
    _setStatus(SyncStatus.offline);
    return false;
  }

  Future<void> close() async {
    for (final t in transports) {
      await t.close();
    }
    await _status.close();
  }
}

/// Фейковый транспорт для тестов оркестрации.
class FakeTransport implements Transport {
  bool available;
  final List<List<int>> sent = [];
  final StreamController<List<int>> _incoming = StreamController.broadcast();

  FakeTransport({this.available = true});

  @override
  TransportKind get id => TransportKind.disk;

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<void> send(List<int> data) async {
    if (!available) throw StateError('unavailable');
    sent.add(data);
  }

  @override
  Stream<List<int>> incoming() => _incoming.stream;
  @override
  Future<void> wake() async {}
  @override
  Future<void> close() async => _incoming.close();
  void deliver(List<int> d) => _incoming.add(d);
}
