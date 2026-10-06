/// Pairing и derivation ключей семьи.
///
/// Модель «пары» (2 устройства, zero-knowledge):
///  - каждое устройство генерирует **static** X25519-ключ (pairing key);
///  - обмен публичными pairing-ключами — одноразово, по QR / BLE (out-of-band);
///  - пользователи вместе задают **S** (семейный секрет, 4 слова);
///  - общий корневой секрет: `root = X25519(staticA, staticB) ‖ S`;
///  - из `root` через Argon2id → **master key** → HKDF → **per-domain ключи**.
///
/// Seed-фраза (12 слов) — это восстановление *pairing keys* устройства:
/// с неё пересоздаётся static X25519, и, зная S, восстанавливаются все ключи.
library;

import 'dart:convert' as conv;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'primitives.dart';

/// Домены данных. Каждому — свой ключ (сегрегация компрометации).
enum Domain {
  calendar,
  documents,
  banks,
  cards,
  messages,
  notes,
  clips,
  box, // Private Box
}

/// Per-domain ключевые материалы.
class DomainKeys {
  const DomainKeys(this._keys);
  final Map<Domain, Uint8List> _keys;
  Uint8List keyFor(Domain d) => _keys[d]!;
  bool contains(Domain d) => _keys.containsKey(d);
}

/// Паринг-материал устройства (static X25519).
class DevicePairing {
  /// 32-байтный seed static X25519 (секретная часть, хранится в secure storage).
  final Uint8List seed;
  final SimplePublicKey pub;
  const DevicePairing(this.seed, this.pub);

  /// [SecretKey] из seed (для X25519-операций).
  SecretKey get secret => SecretKey(seed);
}

/// Результат pairing-сессии.
class PairingResult {
  const PairingResult({required this.master, required this.domains});
  final Uint8List master;
  final DomainKeys domains;
}

const _rootInfo = 'ms/v1/root';
const _domainPrefix = 'ms/v1/domain/';

/// Создать DevicePairing (генерация static X25519).
Future<DevicePairing> createDevicePairing() async {
  final secret = await generateX25519Secret();
  final seed = Uint8List.fromList(await secret.extractBytes());
  final pub = await x25519Public(secret);
  return DevicePairing(seed, pub);
}

/// Завершить pairing. Симметрично: `pair(me=A, peerPub=B, S)` и
/// `pair(me=B, peerPub=A, S)` дают идентичный `master` (X25519 симметричен).
Future<PairingResult> pair(
  DevicePairing me,
  SimplePublicKey peerPub,
  String familySecret,
) async {
  final ecdh = await x25519Shared(me.secret, peerPub);
  final root = BytesBuilder()
    ..add(ecdh)
    ..add(utf8Encode(familySecret.trim()));
  final rootBytes = root.toBytes();

  final master = await argon2id32(bytesToHex(rootBytes), _rootInfo);
  final domainKeys = <Domain, Uint8List>{};
  for (final d in Domain.values) {
    domainKeys[d] = await hkdf32(
      master,
      utf8Encode(_rootInfo),
      utf8Encode('$_domainPrefix${d.name}'),
    );
  }
  return PairingResult(master: master, domains: DomainKeys(domainKeys));
}

/// То же, что [pair], но публичный ключ партнёра передаётся сырыми 32 байтами
/// (приём по QR / вручную). Типы cryptography не утекают в вызывающий код.
Future<PairingResult> pairFromPeerBytes(
  DevicePairing me,
  List<int> peerPubBytes,
  String familySecret,
) async {
  if (peerPubBytes.length != 32) {
    throw const FormatException('pairing: peer pub key must be 32 bytes');
  }
  return pair(me, x25519PubFromBytes(peerPubBytes), familySecret);
}

/// Транспортный (P2P) сессионный ключ: forward secrecy.
///
/// Для каждого сеанса P2P оба устройства генерируют **ephemeral** X25519,
/// обмениваются публичными частями и выводят сессионный ключ
/// (X3DH-lite): `HKDF( ephMe×statPeer ‖ statMe×ephPeer, salt, info )`.
Future<Uint8List> deriveTransportSession({
  required SecretKey myEph,
  required SimplePublicKey peerEphPub,
  required SecretKey myStatic,
  required SimplePublicKey peerStaticPub,
  required List<int> salt,
  required List<int> info,
}) async {
  final ab = await x25519Shared(myEph, peerStaticPub);
  final ba = await x25519Shared(myStatic, peerEphPub);
  // Канонический порядок (сортировка), чтобы A и B получили идентичный IKM.
  final h1 = bytesToHex(ab);
  final h2 = bytesToHex(ba);
  final (first, second) = h1.compareTo(h2) <= 0 ? (ab, ba) : (ba, ab);
  final ikm = BytesBuilder()
    ..add(first)
    ..add(second);
  return hkdf32(ikm.toBytes(), salt, info);
}

/// Экспорт pairing в строки для secure storage.
class PairingExport {
  const PairingExport({
    required this.secretB64,
    required this.pubB64,
  });
  final String secretB64;
  final String pubB64;
}
PairingExport exportPairing(DevicePairing p) => PairingExport(
      secretB64: conv.base64Encode(p.seed),
      pubB64: conv.base64Encode(p.pub.bytes),
    );
/// Импорт pairing из [PairingExport]. Публичный ключ верифицируется
Future<DevicePairing> importPairing(PairingExport e) async {
  final seed = Uint8List.fromList(conv.base64Decode(e.secretB64));
  final secret = SecretKey(seed);
  final pub = await x25519Public(secret);
  final storedPub = conv.base64Decode(e.pubB64);
  if (!_bytesEqual(pub.bytes, storedPub)) {
    throw const FormatException('pairing: pub key mismatch (corrupted export)');
  }
  return DevicePairing(seed, pub);
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
