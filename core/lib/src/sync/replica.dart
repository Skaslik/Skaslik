/// Детерминированный CRDT-движок «МС»: LWW-регистры + гибридные часы + tombstones.
///
/// Инварианты (проверяются тестами):
///  - **Convergence**: любое множество изменений, применённое в любом порядке на
///    репликах, даёт идентичное состояние.
///  - **Idempotency**: повторное применение одного изменения ничего не меняет.
///  - **No data loss**: ни одно изменение пары не теряется при гонках/рассинхроне.
///  - **Deterministic winner**: при одновременной записи одно и то же поле с двух
///    устройств победитель определяется детерминированно (нет «бита в воздухе»).
///
/// Модель:
///  - *Сущность* (событие/копилка/карта/сообщение) — набор *полей*.
///  - Каждое поле — **LWW-регистр**: победитель — операция с большей **версией**.
///  - *Версия* — тройка `(time, seq, deviceId)`, сравниваемая лексикографически:
///      1. `time` (миллисекунды гибридных часов, доминирует) — «кто позже во времени»;
///      2. `seq` (монотонный счётчик устройства) — развязывает записи в один мс;
///      3. `deviceId` (уникален) — тотальный детерминированный тай-брейк.
///    Тройка глобально уникальна → версий без равенства нет.
///  - **Удаление** сущности — tombstone (операция delete). Сущность видима, только
///    если у неё есть живое поле с версией *больше* версии удаления (корректное
///    «пересоздание» после удаления).
library;

import 'dart:collection';
import 'dart:typed_data';

/// Тип времени гибридных часов (мс с 1970, 32-bit до ~2106).
typedef ClockFn = int Function();

/// Детерминированное сравнение версий: `> 0`, если (aTime,aSeq,aDev) позже.
int compareVersion(
    int aTime, int aSeq, String aDev, int bTime, int bSeq, String bDev) {
  if (aTime != bTime) return aTime > bTime ? 1 : -1;
  if (aSeq != bSeq) return aSeq > bSeq ? 1 : -1;
  return aDev.compareTo(bDev);
}

/// Одна операция изменения (атомарная единица синхронизации).
class Op {
  final int seq;
  final int time;
  final String deviceId;
  final String entityId;
  final String? field;
  final String? value;
  final String kind; // 'set' | 'delete'

  const Op({
    required this.seq,
    required this.time,
    required this.deviceId,
    required this.entityId,
    this.field,
    this.value,
    required this.kind,
  });

  bool newerThan(int oTime, int oSeq, String oDev) =>
      compareVersion(time, seq, deviceId, oTime, oSeq, oDev) > 0;

  /// Детерминированный id операции (для dedup на транспорте).
  String get opId =>
      '$deviceId|$entityId|${field ?? '*'}|$time|$seq|$kind';

  @override
  String toString() =>
      'Op($kind $entityId/${field ?? '*'}=$value @t$time#$seq/$deviceId)';
}

class _Reg {
  final int time;
  final int seq;
  final String deviceId;
  final String? value;
  const _Reg(this.time, this.seq, this.deviceId, this.value);
}

class _EntityState {
  final Map<String, _Reg> fields = HashMap();
  _Reg? deleted;
}

/// Реплика домена данных (например, календаря) на одном устройстве.
class Replica {
  final String deviceId;
  final ClockFn _clock;
  int _lastTime;
  int _seq;

  /// Latest time of any write from another device this replica has seen.
  /// The next local write is stamped after it (hybrid logical clock).
  int _maxRemoteTime = 0;
  final Map<String, _EntityState> _entities = HashMap();
  final List<Op> _opLog = [];
  final Set<String> _applied = HashSet();
  final Map<String, Op> _knownOps = HashMap();

  Replica(this.deviceId, {ClockFn? clock, int initialTime = 0})
      : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
        _lastTime = initialTime,
        _seq = 0;

  int get lamport => _lastTime;

  // ---------------------------------------------------------------------------
  // Локальные мутации
  // ---------------------------------------------------------------------------

  /// Записать/обновить поле сущности. Возвращает сгенерированный [Op].
  Op set(String entityId, String field, String value) {
    final op = _newOp(entityId, field, value, 'set');
    _apply(op);
    return op;
  }

  /// Удалить сущность (tombstone).
  Op delete(String entityId) {
    final op = _newOp(entityId, null, null, 'delete');
    _apply(op);
    return op;
  }

  Op _newOp(String entityId, String? field, String? value, String kind) {
    // Гибридные часы: monotonically non-decreasing; при совпадении времени
    // своя последующая запись всё равно «позже» благодаря растущему seq.
    // Чужие записи с тем же временем сравниваются по чужому seq, поэтому
    // запись, сделанная после увиденной чужой, ставится минимум на +1 мс —
    // иначе она могла бы проиграть (I8). Формат операций не меняется.
    final now = _clock();
    if (now > _lastTime) _lastTime = now;
    if (_lastTime <= _maxRemoteTime) _lastTime = _maxRemoteTime + 1;
    _seq += 1;
    final op = Op(
      seq: _seq,
      time: _lastTime,
      deviceId: deviceId,
      entityId: entityId,
      field: field,
      value: value,
      kind: kind,
    );
    _opLog.add(op);
    return op;
  }

  // ---------------------------------------------------------------------------
  // Применение (локальных и удалённых)
  // ---------------------------------------------------------------------------

  void _apply(Op op) {
    if (op.time > _lastTime) _lastTime = op.time;
    if (op.deviceId != deviceId && op.time > _maxRemoteTime) {
      _maxRemoteTime = op.time;
    }
    final e = _entities.putIfAbsent(op.entityId, () => _EntityState());
    if (op.kind == 'delete') {
      final cur = e.deleted;
      if (cur == null ||
          op.newerThan(cur.time, cur.seq, cur.deviceId)) {
        e.deleted = _Reg(op.time, op.seq, op.deviceId, null);
      }
    } else {
      final f = op.field!;
      final cur = e.fields[f];
      if (cur == null || op.newerThan(cur.time, cur.seq, cur.deviceId)) {
        e.fields[f] = _Reg(op.time, op.seq, op.deviceId, op.value);
      }
    }
    _applied.add(op.opId);
    _knownOps[op.opId] = op;
  }

  /// Применить пакет удалённых операций (идемпотентно).
  void mergeIn(Iterable<Op> remoteOps) {
    for (final op in remoteOps) {
      if (!_applied.contains(op.opId)) _apply(op);
    }
  }

  // ---------------------------------------------------------------------------
  // Вид
  // ---------------------------------------------------------------------------

  Map<String, Map<String, String>> view() {
    final out = <String, Map<String, String>>{};
    for (final entry in _entities.entries) {
      final e = entry.value;
      if (!_visible(e)) continue;
      out[entry.key] =
          {for (final f in e.fields.entries) f.key: f.value.value!};
    }
    return out;
  }

  bool _visible(_EntityState e) {
    if (e.fields.isEmpty) return false;
    final del = e.deleted;
    if (del == null) return true;
    for (final f in e.fields.values) {
      if (_regNewer(f, del)) return true;
    }
    return false;
  }

  bool _regNewer(_Reg f, _Reg del) =>
      compareVersion(f.time, f.seq, f.deviceId, del.time, del.seq, del.deviceId) > 0;

  bool contains(String entityId) {
    final e = _entities[entityId];
    return e != null && _visible(e);
  }

  Map<String, String>? entity(String entityId) {
    final e = _entities[entityId];
    if (e == null || !_visible(e)) return null;
    return {for (final f in e.fields.entries) f.key: f.value.value!};
  }

  int get entityCount => view().length;

  // ---------------------------------------------------------------------------
  // Синхронизация: дельта и снапшот
  // ---------------------------------------------------------------------------

  /// Операции с `seq > afterSeq` (инкрементальная синхронизация).
  List<Op> deltaAfter(int afterSeq) =>
      [for (final op in _opLog)
        if (op.seq > afterSeq) op];

  /// Все операции устройства (для полной отправки при первом контакте).
  List<Op> allOps() => List.unmodifiable(_opLog);

  /// Снапшот: несёт **все** известные операции (локальные и удалённые), чтобы
  /// новое/восстановленное устройство полностью воспроизвело состояние.
  Snapshot snapshot() {
    final ops = _knownOps.values.toList()
      ..sort((a, b) =>
          compareVersion(a.time, a.seq, a.deviceId, b.time, b.seq, b.deviceId));
    return Snapshot(clock: _lastTime, seq: _seq, ops: List.unmodifiable(ops));
  }

  /// Восстановить состояние из [Snapshot] (идемпотентно).
  void restore(Snapshot s) {
    for (final op in s.ops) {
      if (!_applied.contains(op.opId)) _apply(op);
    }
    if (s.clock > _lastTime) _lastTime = s.clock;
  }

  @override
  String toString() {
    final v = view();
    return 'Replica($deviceId, t=$_lastTime, seq=$_seq, entities=${v.length})';
  }
}

/// Снапшот реплики для передачи (baseline).
class Snapshot {
  final int clock;
  final int seq;
  final List<Op> ops;
  const Snapshot({required this.clock, required this.seq, required this.ops});
}

/// Бинаризация [Op] для транспорта.
///
/// Одна операция (big-endian):
///   kind(1: 1=set,2=delete) | entityId(u32 len + utf16) |
///   (set only: field u32 len + utf16, value u32 len + utf16) |
///   time(u64) | seq(u32) | deviceId(u32 len + utf16)
///
/// Пакет: u32 count, затем на каждую операцию: u32 len + байты операции.
class OpCodec {
  static Uint8List encode(Op op) {
    final b = BytesBuilder();
    b.addByte(op.kind == 'delete' ? 2 : 1);
    _putStr(b, op.entityId);
    if (op.kind == 'set') {
      _putStr(b, op.field!);
      _putStr(b, op.value ?? '');
    }
    _putU64(b, op.time);
    _putU32(b, op.seq);
    _putStr(b, op.deviceId);
    return b.toBytes();
  }

  static Uint8List encodeBatch(List<Op> ops) {
    final b = BytesBuilder();
    _putU32(b, ops.length);
    for (final op in ops) {
      final e = encode(op);
      _putU32(b, e.length);
      b.add(e);
    }
    return b.toBytes();
  }

  static Op decode(Uint8List data) {
    final d = _Data(data);
    final kind = d.u8() == 2 ? 'delete' : 'set';
    final entityId = d.str();
    String? field, value;
    if (kind == 'set') {
      field = d.str();
      value = d.str();
    }
    final time = d.u64();
    final seq = d.u32();
    final deviceId = d.str();
    return Op(
        seq: seq,
        time: time,
        deviceId: deviceId,
        entityId: entityId,
        field: field,
        value: value,
        kind: kind);
  }

  static List<Op> decodeBatch(Uint8List data) {
    final d = _Data(data);
    final n = d.u32();
    final ops = <Op>[];
    for (var i = 0; i < n; i++) {
      final len = d.u32();
      final start = d.pos;
      final bytes = data.sublist(start, start + len);
      d.pos = start + len;
      ops.add(decode(bytes));
    }
    return ops;
  }

  static void _putStr(BytesBuilder b, String s) {
    final e = s.codeUnits;
    _putU32(b, e.length);
    for (final c in e) {
      b.addByte((c >> 8) & 0xFF);
      b.addByte(c & 0xFF);
    }
  }

  static void _putU32(BytesBuilder b, int v) {
    b.addByte((v >> 24) & 0xFF);
    b.addByte((v >> 16) & 0xFF);
    b.addByte((v >> 8) & 0xFF);
    b.addByte(v & 0xFF);
  }

  static void _putU64(BytesBuilder b, int v) {
    b.addByte((v >> 56) & 0xFF);
    b.addByte((v >> 48) & 0xFF);
    b.addByte((v >> 40) & 0xFF);
    b.addByte((v >> 32) & 0xFF);
    b.addByte((v >> 24) & 0xFF);
    b.addByte((v >> 16) & 0xFF);
    b.addByte((v >> 8) & 0xFF);
    b.addByte(v & 0xFF);
  }
}

class _Data {
  final Uint8List d;
  int pos = 0;
  _Data(this.d);
  int u8() => d[pos++];
  int u32() {
    final v = (d[pos] << 24) |
        (d[pos + 1] << 16) |
        (d[pos + 2] << 8) |
        d[pos + 3];
    pos += 4;
    return v & 0xFFFFFFFF;
  }

  int u64() {
    final hi = u32();
    final lo = u32();
    return (hi << 32) | lo;
  }

  String str() {
    final n = u32();
    final bytes = d.sublist(pos, pos + n * 2);
    pos += n * 2;
    final units =
        List<int>.generate(n, (i) => (bytes[i * 2] << 8) | bytes[i * 2 + 1]);
    return String.fromCharCodes(units);
  }
}
