/// Нулевой-знаний конверт синхронизации (L3: Яндекс.Диск и любой транспорт).
///
/// По диску ходит только [SyncBlob]: `nonce(24) || ct||tag`. Ключ —
/// `syncKey = HKDF(master, salt=rootInfo, info='ms/v1/sync')`. Оба устройства
/// пары знают `master` (pairing), поэтому расшифруют конверт друг друга;
/// Яндекс/взлом диска видит только шифртекст.
///
/// Свойство **domain-separation**: при подмене/битости AAD (в нём — домен)
/// [openSyncBlob] бросает исключение. Это значит: конверт календаря нельзя
/// применить как конверт банков, даже расшифровав его (tag не сойдётся).
library;

import 'dart:typed_data';

import '../crypto/primitives.dart';
import 'replica.dart';

/// AAD для sync-конверта (domain-separation).
const syncAadPrefix = 'ms/sync/';

/// Синхронизационный ключ семьи (общий у обоих устройств).
///
/// `syncKey = HKDF(master, salt=rootInfo, info='ms/v1/sync')`. Выделяем отдельным
/// info, чтобы скомпрометировать sync-канал, не скомпрометировав per-domain
/// ключи и наоборот.
Future<Uint8List> syncKeyFromMaster(Uint8List master) =>
    hkdf32(master, utf8Encode('ms/v1/root'), utf8Encode('ms/v1/sync'));

/// Детерминированный deviceId по публичному pairing-ключу (12 hex).
///
/// Используется как часть версии LWW-регистра и как «кто» в op. Один ключ →
/// один id, независимо от устройства/сессии.
String deviceIdForPub(List<int> pubBytes) {
  final hex = bytesToHex(pubBytes);
  return hex.substring(0, 12);
}

/// Шифровать [ops] под семейный [syncKey] для домена [domain].
Future<Uint8List> sealSyncBlob({
  required Uint8List syncKey,
  required String domain,
  required List<Op> ops,
}) async {
  final plain = OpCodec.encodeBatch(ops);
  final aad = utf8Encode('${syncAadPrefix}$domain');
  return xchachaSeal(syncKey, plain, aad: aad);
}

/// Расшифровать [sealed] под [syncKey] для домена [domain].
///
/// Бросает исключение при подмене/битости или при неверном домене (AAD).
Future<List<Op>> openSyncBlob({
  required Uint8List syncKey,
  required String domain,
  required Uint8List sealed,
}) async {
  final aad = utf8Encode('${syncAadPrefix}$domain');
  final plain = await xchachaOpen(syncKey, sealed, aad: aad);
  return OpCodec.decodeBatch(plain);
}
