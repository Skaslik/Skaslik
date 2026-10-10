/// Локальное хранилище домена: оборачивает CRDT-[Replica] + JSON-персистентность.
///
/// Local-first: состояние живёт на устройстве; [Replica] даёт сходящуюся
/// семантику. На S1 сюда подключаются транспорт (L1/L2/L3) и крипто-обёртка
/// (запись/чтение шифртекста). Сейчас — чистый local-слой, полностью работает
/// офлайн.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ms_core/ms_core.dart';
import '../storage/local_file.dart';
/// Домены данных.
enum MsDomain { calendar, banks, cards, docs, messages, notes, clips, pulse, ritual, capsule, profile }
class MsStore extends ChangeNotifier {
  final MsDomain domain;
  final String deviceId;
  late final Replica _replica;
  final LocalFile _file;

  MsStore({required this.deviceId, required this.domain, String? dataDir})
      : _file = LocalFile.forDomain(domain, dataDir: dataDir) {
    _replica = Replica(deviceId);
    _load();
  }

  int get entityCount => _replica.entityCount;
  Replica get replica => _replica;

  /// Записать/обновить поле сущности. Сохраняет и уведомляет наблюдателей.
  Op set(String entityId, String field, String value) {
    final op = _replica.set(entityId, field, value);
    _persist();
    notifyListeners();
    return op;
  }

  /// Удалить сущность (tombstone). Сохраняет и уведомляет.
  Op remove(String entityId) {
    final op = _replica.delete(entityId);
    _persist();
    notifyListeners();
    return op;
  }

  Map<String, String>? entity(String entityId) => _replica.entity(entityId);
  bool contains(String entityId) => _replica.contains(entityId);
  Map<String, Map<String, String>> view() => _replica.view();
  List<Op> allOps() => _replica.allOps();

  /// Применить удалённые операции (приходит со синхронизации).
  void mergeRemote(Iterable<Op> remote) {
    _replica.mergeIn(remote);
    _persist();
    notifyListeners();
  }

  /// Снапшот для передачи партнёру.
  Snapshot snapshot() => _replica.snapshot();

  /// Инкрементальная дельта.
  List<Op> deltaAfter(int afterSeq) => _replica.deltaAfter(afterSeq);

  /// Сохранить на диск (JSON op-log) и уведомить наблюдателей.
  void persist() {
    _persist();
    notifyListeners();
  }

  void _persist() {
    _file.write(jsonEncode(_encode()));
  }

  void _load() {
    final raw = _file.read();
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _replica.restore(_decode(data));
    } catch (_) {
      // Повреждённый файл — не роняем приложение; начинаем с чистого листа.
      _file.clear();
    }
  }
  @override
  void dispose() {
    _file.close();
    super.dispose();
  }

  // --- сериализация (Op ↔ Map) ---
  Map<String, dynamic> _encode() => {
        'deviceId': deviceId,
        'ops': [for (final op in _replica.snapshot().ops) _opToMap(op)],
      };

  Snapshot _decode(Map<String, dynamic> data) {
    final ops = [
      for (final e in (data['ops'] as List)) _mapToOp(e as Map<String, dynamic>)
    ];
    return Snapshot(clock: 0, seq: 0, ops: ops);
  }

  Map<String, dynamic> _opToMap(Op op) => {
        'seq': op.seq,
        'time': op.time,
        'deviceId': op.deviceId,
        'entityId': op.entityId,
        'field': op.field,
        'value': op.value,
        'kind': op.kind,
      };

  Op _mapToOp(Map<String, dynamic> m) => Op(
        seq: m['seq'] as int,
        time: m['time'] as int,
        deviceId: m['deviceId'] as String,
        entityId: m['entityId'] as String,
        field: m['field'] as String?,
        value: m['value'] as String?,
        kind: m['kind'] as String,
      );
}
