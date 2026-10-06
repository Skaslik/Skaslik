/// Крипто-примитивы «МС» (zero-knowledge).
///
/// Всё, что ходит по каналам связи (Яндекс.Диск bus, ntfy) или хранится на
/// диске устройства, шифруется здесь. Ключи не покидают устройства пары.
library;

import 'dart:convert' as conv;
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

final _sha256 = Sha256();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: keyLength);
final _x25519 = X25519();
final _xchacha = Xchacha20.poly1305Aead();
final _aesGcm = AesGcm.with256bits();
final _rng = Random.secure();

/// Длина ключа X25519 (32 байта).
const int x25519KeyLength = 32;

/// Nonce XChaCha20-Poly1305 (24 байта).
const int xchachaNonceLength = 24;

/// Tag AEAD (16 байт).
const int aeadTagLength = 16;

/// Nonce AES-GCM (12 байта).
const int aesGcmNonceLength = 12;

/// Длина master/derived ключа (32 байта).
const int keyLength = 32;

// ---------------------------------------------------------------------------
// X25519 (транспорт / pairing)
// ---------------------------------------------------------------------------

/// Генерация секретного ключа X25519 (32 случайных байта — seed).
Future<SecretKey> generateX25519Secret() async {
  final seed = Uint8List.fromList(
    List<int>.generate(x25519KeyLength, (_) => _rng.nextInt(256)),
  );
  return SecretKey(seed);
}

/// Публичный ключ из секретного (seed → keypair → pub).
Future<SimplePublicKey> x25519Public(SecretKey secret) async {
  final bytes = await secret.extractBytes();
  final kp = await _x25519.newKeyPairFromSeed(bytes);
  return await kp.extractPublicKey();
}

/// Публичный ключ X25519 из 32 сырых байтов (для приёма публичного ключа
/// партнёра по QR / вручную).
SimplePublicKey x25519PubFromBytes(List<int> bytes) =>
    SimplePublicKey(bytes, type: KeyPairType.x25519);

/// ECDH X25519 → 32 байта общего секрета.
Future<Uint8List> x25519Shared(SecretKey secret, PublicKey peer) async {
  final bytes = await secret.extractBytes();
  final kp = await _x25519.newKeyPairFromSeed(bytes);
  final shared = await _x25519.sharedSecretKey(keyPair: kp, remotePublicKey: peer);
  return Uint8List.fromList(await shared.extractBytes());
}

// ---------------------------------------------------------------------------
// HKDF (per-domain и транспортные ключи)
// ---------------------------------------------------------------------------

/// HKDF-SHA256: 32-байтный ключ из IKM.
Future<Uint8List> hkdf32(List<int> ikm, List<int> salt, List<int> info) async {
  final derived = await _hkdf.deriveKey(
    secretKey: SecretKey(ikm),
    nonce: salt,
    info: info,
  );
  return Uint8List.fromList(await derived.extractBytes());
}

// ---------------------------------------------------------------------------
// AEAD: XChaCha20-Poly1305 (синхронизация, доменные ключи)
// ---------------------------------------------------------------------------

/// Шифрует [plaintext] ключом [key] (32 B). Возвращает `nonce(24) || ct||tag`.
Future<Uint8List> xchachaSeal(
  List<int> key,
  List<int> plaintext, {
  List<int> aad = const [],
}) async {
  final nonce = Uint8List.fromList(
    List<int>.generate(xchachaNonceLength, (_) => _rng.nextInt(256)),
  );
  final box = await _xchacha.encrypt(
    plaintext,
    secretKey: SecretKey(key),
    nonce: nonce,
    aad: aad,
  );
  final out = BytesBuilder();
  out.add(box.nonce);
  out.add(box.concatenation(nonce: false));
  return Uint8List.fromList(out.toBytes());
}

/// Обратное [xchachaSeal]. Бросает исключение при подмене/битости.
Future<Uint8List> xchachaOpen(
  List<int> key,
  List<int> sealed, {
  List<int> aad = const [],
}) async {
  if (sealed.length < xchachaNonceLength + aeadTagLength) {
    throw const FormatException('xchacha: ciphertext too short');
  }
  final box = SecretBox.fromConcatenation(
    sealed,
    nonceLength: xchachaNonceLength,
    macLength: aeadTagLength,
  );
  final plain = await _xchacha.decrypt(
    box,
    secretKey: SecretKey(key),
    aad: aad,
  );
  return Uint8List.fromList(plain);
}

// ---------------------------------------------------------------------------
// AEAD: AES-256-GCM (файлы / медиа)
// ---------------------------------------------------------------------------

/// Шифрует [plaintext] ключом [key] (32 B). Возвращает `nonce(12) || ct||tag`.
Future<Uint8List> aesGcmSeal(List<int> key, List<int> plaintext) async {
  final nonce = Uint8List.fromList(
    List<int>.generate(aesGcmNonceLength, (_) => _rng.nextInt(256)),
  );
  final box = await _aesGcm.encrypt(plaintext, secretKey: SecretKey(key), nonce: nonce);
  final out = BytesBuilder();
  out.add(box.nonce);
  out.add(box.concatenation(nonce: false));
  return Uint8List.fromList(out.toBytes());
}

/// Обратное [aesGcmSeal].
Future<Uint8List> aesGcmOpen(List<int> key, List<int> sealed) async {
  if (sealed.length < aesGcmNonceLength + aeadTagLength) {
    throw const FormatException('aesGcm: ciphertext too short');
  }
  final box = SecretBox.fromConcatenation(
    sealed,
    nonceLength: aesGcmNonceLength,
    macLength: aeadTagLength,
  );
  final plain = await _aesGcm.decrypt(box, secretKey: SecretKey(key));
  return Uint8List.fromList(plain);
}

// ---------------------------------------------------------------------------
// Argon2id (derivation секрета семьи / Private Box)
// ---------------------------------------------------------------------------

/// Argon2id → 32 байта. Параметры «одноразовой» derivation:
/// память 128 МБ, итерации 3, параллельность 1 (переносимо, быстро).
Future<Uint8List> argon2id32(
  String secret,
  String salt, {
  int memoryKib = 128 * 1024,
  int iterations = 3,
}) async {
  final argon2id = Argon2id(
    parallelism: 1,
    memory: memoryKib,
    iterations: iterations,
    hashLength: keyLength,
  );
  final hash = await argon2id.deriveKey(
    secretKey: SecretKey(utf8Encode(secret)),
    nonce: utf8Encode(salt),
  );
  return Uint8List.fromList(await hash.extractBytes());
}

// ---------------------------------------------------------------------------
// Утилиты

/// Байты → lowercase hex (детерминированный, для ключей в secure storage).
String bytesToHex(List<int> bytes) => bytes
    .map((b) => b.toRadixString(16).padLeft(2, '0'))
    .join();

/// Обратное [bytesToHex].
List<int> hexToBytes(String hex) {
  if (hex.length.isOdd || hex.isEmpty) {
    throw const FormatException('hex: нечётная длина');
  }
  return List<int>.generate(
    hex.length ~/ 2,
    (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
  );
}

/// SHA-256 → hex (для seed-phrase-проверок и логов, не для хранения ключей).
Future<String> sha256Hex(List<int> data) async {
  final digest = await _sha256.hash(data);
  return bytesToHex(digest.bytes);
}

/// Короткий hex для логов — НИКОГДА не для сравнения полных ключей.
String shortHex(List<int> data, [int chars = 16]) {
  final full = bytesToHex(data);
  return full.length <= chars ? full : '${full.substring(0, chars)}…';
}

List<int> utf8Encode(String s) => conv.utf8.encode(s);
String utf8Decode(List<int> bytes) => conv.utf8.decode(bytes);
