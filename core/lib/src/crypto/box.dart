/// Личный сейф (PLAN.md §2 п.5, §5.4): отдельный пароль P_box, не
/// связанный с секретом семьи S. Только на этом телефоне.
///
/// Ключи: Argon2id(P_box, salt) → KEK; случайный box key (32 B) хранится
/// завёрнутым в KEK (XChaCha20-Poly1305). Смена параметров KDF или пароля
/// не требует перешифровки файлов.
///
/// Формат файла: «MSB1» ‖ chunkSize (uint32 BE), затем куски
/// `xchachaSeal(key, plain, aad: "msbox-chunk-v1" ‖ fileId ‖ index(uint64 BE)
/// ‖ last)`. Все куски, кроме последнего, ровно chunkSize байт открытого
/// текста; последний — 0…chunkSize, с last = 1. AAD привязывает кусок к
/// файлу, месту и «последности»: перестановка, обрезка и подмена ловятся.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'primitives.dart';

/// 1 MiB of plaintext per chunk.
const int kBoxChunkSize = 1 << 20;

/// Shortest box password the UI accepts.
const int kBoxMinPassword = 6;

const List<int> _magic = [0x4D, 0x53, 0x42, 0x31]; // «MSB1»
const int _headerLength = 8;
const int _overhead = xchachaNonceLength + aeadTagLength;
const int _maxChunk = 64 << 20;
final Random _rng = Random.secure();

Uint8List _random(int n) =>
    Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

/// A fresh random id for a box file (also its file name on disk).
String newBoxId() => bytesToHex(_random(16));

/// Argon2id cost. The default matches the app PIN (128 MB, 3 passes).
class BoxKdf {
  const BoxKdf({this.memoryKib = 128 * 1024, this.iterations = 3});
  final int memoryKib;
  final int iterations;
}

/// The box data is damaged, cut or not a box file.
class BoxCorrupt implements Exception {
  const BoxCorrupt(this.reason);
  final String reason;
  @override
  String toString() => 'BoxCorrupt: $reason';
}

/// Password → box key. Stored as JSON next to the box; holds no secret.
class BoxKeyring {
  const BoxKeyring._(
      {required this.kdf, required this.salt, required this.wrapped});

  final BoxKdf kdf;

  /// Random 16 bytes as hex: Argon2id's salt.
  final String salt;

  /// The box key sealed with the password-derived key.
  final Uint8List wrapped;

  static final List<int> _aad = utf8Encode('msbox-key-v1');

  static Future<({BoxKeyring keyring, Uint8List key})> create(
    String password, {
    BoxKdf kdf = const BoxKdf(),
  }) async {
    final salt = bytesToHex(_random(16));
    final key = _random(keyLength);
    final kek = await argon2id32(password, salt,
        memoryKib: kdf.memoryKib, iterations: kdf.iterations);
    final wrapped = await xchachaSeal(kek, key, aad: _aad);
    return (
      keyring: BoxKeyring._(kdf: kdf, salt: salt, wrapped: wrapped),
      key: key,
    );
  }

  /// The box key, or null when [password] is wrong.
  Future<Uint8List?> tryUnlock(String password) async {
    final kek = await argon2id32(password, salt,
        memoryKib: kdf.memoryKib, iterations: kdf.iterations);
    try {
      return await xchachaOpen(kek, wrapped, aad: _aad);
    } catch (_) {
      return null;
    }
  }

  String toJson() => jsonEncode({
        'v': 1,
        'kdf': 'argon2id',
        'm': kdf.memoryKib,
        't': kdf.iterations,
        'salt': salt,
        'wrapped': bytesToHex(wrapped),
      });

  static BoxKeyring fromJson(String json) {
    try {
      final j = jsonDecode(json) as Map<String, dynamic>;
      if (j['v'] != 1 || j['kdf'] != 'argon2id') {
        throw const BoxCorrupt('неизвестная версия ключа');
      }
      return BoxKeyring._(
        kdf: BoxKdf(
            memoryKib: (j['m'] as num).toInt(),
            iterations: (j['t'] as num).toInt()),
        salt: j['salt'] as String,
        wrapped: Uint8List.fromList(hexToBytes(j['wrapped'] as String)),
      );
    } on BoxCorrupt {
      rethrow;
    } catch (_) {
      throw const BoxCorrupt('ключ сейфа повреждён');
    }
  }
}

/// A file in the box. Lives only inside the sealed index.
class BoxEntry {
  const BoxEntry({
    required this.id,
    required this.name,
    required this.size,
    required this.addedAt,
  });

  final String id;
  final String name;

  /// Plaintext size in bytes.
  final int size;

  /// When it was put in the box (ms since epoch).
  final int addedAt;

  static const Set<String> _images = {
    'JPG', 'JPEG', 'PNG', 'HEIC', 'WEBP', 'GIF',
  };

  /// PDF / JPG / … for the thumbnail; «ФАЙЛ» when unknown.
  String get kindLabel {
    final dot = name.lastIndexOf('.');
    if (dot > 0 && dot < name.length - 1) {
      return name.substring(dot + 1).toUpperCase();
    }
    return 'ФАЙЛ';
  }

  bool get isImage => _images.contains(kindLabel);

  Map<String, Object> toJson() =>
      {'id': id, 'name': name, 'size': size, 'at': addedAt};

  static BoxEntry fromJson(Map<String, dynamic> j) => BoxEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        size: (j['size'] as num).toInt(),
        addedAt: (j['at'] as num).toInt(),
      );
}

final List<int> _indexAad = utf8Encode('msbox-index-v1');

Future<Uint8List> sealBoxIndex(List<int> key, List<BoxEntry> entries) =>
    xchachaSeal(
      key,
      utf8Encode(jsonEncode({
        'v': 1,
        'files': [for (final e in entries) e.toJson()],
      })),
      aad: _indexAad,
    );

Future<List<BoxEntry>> openBoxIndex(List<int> key, List<int> sealed) async {
  final Uint8List plain;
  try {
    plain = await xchachaOpen(key, sealed, aad: _indexAad);
  } catch (_) {
    throw const BoxCorrupt('список файлов не открывается');
  }
  try {
    final j = jsonDecode(utf8Decode(plain)) as Map<String, dynamic>;
    return [
      for (final f in j['files'] as List<dynamic>)
        BoxEntry.fromJson(f as Map<String, dynamic>),
    ];
  } catch (_) {
    throw const BoxCorrupt('список файлов повреждён');
  }
}

List<int> _chunkAad(String fileId, int index, bool last) {
  final b = BytesBuilder();
  b.add(utf8Encode('msbox-chunk-v1'));
  b.add(utf8Encode(fileId));
  final n = ByteData(8)..setUint64(0, index);
  b.add(n.buffer.asUint8List());
  b.addByte(last ? 1 : 0);
  return b.takeBytes();
}

Future<Uint8List> _sealChunk(
        List<int> key, String id, int index, bool last, List<int> plain) =>
    xchachaSeal(key, plain, aad: _chunkAad(id, index, last));

Future<Uint8List> _openChunk(
    List<int> key, String id, int index, bool last, List<int> sealed) async {
  try {
    return await xchachaOpen(key, sealed, aad: _chunkAad(id, index, last));
  } catch (_) {
    throw const BoxCorrupt('файл повреждён или чужой');
  }
}

/// Encrypts a byte stream into the box format.
Stream<List<int>> sealBoxStream(
  Stream<List<int>> plain, {
  required List<int> key,
  required String fileId,
  int chunkSize = kBoxChunkSize,
}) async* {
  final header = ByteData(_headerLength);
  for (var i = 0; i < 4; i++) {
    header.setUint8(i, _magic[i]);
  }
  header.setUint32(4, chunkSize);
  yield header.buffer.asUint8List();

  var index = 0;
  final buf = BytesBuilder(copy: false);
  await for (final piece in plain) {
    buf.add(piece);
    // Keep at least one byte back: the last chunk is emitted at the end.
    if (buf.length <= chunkSize) continue;
    final all = buf.takeBytes();
    var off = 0;
    while (all.length - off > chunkSize) {
      yield await _sealChunk(key, fileId, index++, false,
          Uint8List.sublistView(all, off, off + chunkSize));
      off += chunkSize;
    }
    buf.add(Uint8List.sublistView(all, off));
  }
  yield await _sealChunk(key, fileId, index, true, buf.takeBytes());
}

/// Decrypts the box format. Errors with [BoxCorrupt] on any damage.
Stream<List<int>> openBoxStream(
  Stream<List<int>> sealed, {
  required List<int> key,
  required String fileId,
}) async* {
  final buf = BytesBuilder(copy: false);
  int? sealedChunk;
  var index = 0;
  await for (final piece in sealed) {
    buf.add(piece);
    if (sealedChunk == null) {
      if (buf.length < _headerLength) continue;
      final all = buf.takeBytes();
      sealedChunk = _readHeader(all) + _overhead;
      buf.add(Uint8List.sublistView(all, _headerLength));
    }
    if (buf.length <= sealedChunk) continue;
    final all = buf.takeBytes();
    var off = 0;
    while (all.length - off > sealedChunk) {
      yield await _openChunk(key, fileId, index++, false,
          Uint8List.sublistView(all, off, off + sealedChunk));
      off += sealedChunk;
    }
    buf.add(Uint8List.sublistView(all, off));
  }
  if (sealedChunk == null) throw const BoxCorrupt('не файл сейфа');
  final rest = buf.takeBytes();
  if (rest.length < _overhead) throw const BoxCorrupt('файл обрезан');
  yield await _openChunk(key, fileId, index, true, rest);
}

/// The plaintext size of a box file from its first 8 bytes and its length,
/// without decrypting. Null when [header] isn't a box header.
int? boxPlainSize(List<int> header, int sealedLength) {
  final int chunk;
  try {
    chunk = _readHeader(Uint8List.fromList(header.take(_headerLength).toList()));
  } catch (_) {
    return null;
  }
  final n = sealedLength - _headerLength;
  if (n < _overhead) return null;
  final full = chunk + _overhead;
  // Every chunk but the last is full; the last holds 0…chunk bytes.
  final chunks = n % full == 0 ? n ~/ full : n ~/ full + 1;
  final plain = n - chunks * _overhead;
  return plain < 0 ? null : plain;
}

int _readHeader(Uint8List h) {
  if (h.length < _headerLength) throw const BoxCorrupt('не файл сейфа');
  for (var i = 0; i < 4; i++) {
    if (h[i] != _magic[i]) throw const BoxCorrupt('не файл сейфа');
  }
  final size = ByteData.sublistView(h, 4, 8).getUint32(0);
  if (size < 1 || size > _maxChunk) throw const BoxCorrupt('не файл сейфа');
  return size;
}
