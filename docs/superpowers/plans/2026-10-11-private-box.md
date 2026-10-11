# «Личный сейф» (Private Box) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the disabled «Открыть сейф» on the Files tab into a working private box: a separate password, files encrypted on this phone only, invisible to the partner and unreadable without the password.

**Architecture:** Crypto lives in `core/` as a new additive file (`crypto/box.dart`). It provides a password-wrapped random box key, a chunked streaming XChaCha20-Poly1305 file format, and an encrypted index of names. The app wraps it in a `PrivateBox` ChangeNotifier that owns `<data>/box/`. Heavy work (Argon2id, file encryption) runs in `Isolate.run`. The UI is the existing safe sheet, now with create/unlock/forgot states, plus a new full-screen `/safe` route (outside the tab shell) that lists, adds, opens and deletes files and locks on leave.

**Tech Stack:** Dart 3.13 / Flutter 3.47.6, Riverpod 2, go_router 14, `cryptography` + `argon2` (already in core). New, **needs approval**: `file_picker` and `open_filex`.

**Spec:** `PLAN.md` §2 item 5 (P_box, Argon2id, not derived from S), §5.4 «Private Box» UX and acceptance (zero access without P_box), §5.9 security, §9 QA-11. Design: `docs/design/components/ScreenFiles.md`, `components/FileRow.md`, prototype sheet in `docs/design/reference-web/prototype/Main.dc.html` (search «Личный сейф»). The inside of the safe has no design; Task 4 builds it from the Files screen's parts.

## Decisions to confirm before starting

1. **Packages.** `file_picker` (choose any file) and `open_filex` (open a PDF/DOCX in the phone's viewer). Neither is in IMPLEMENTATION.md §1, so CLAUDE.md requires the user's OK.
2. **Local only.** The safe is not synced, not on Yandex.Disk, and not covered by the recovery sheet or the partner. A lost phone or a forgotten password means the files are gone. The UI says so when creating the safe.
3. **Password every time.** No fingerprint shortcut: the copy promises «без пароля их не открыть даже с этого телефона».
4. **Auto-lock.** Leaving the safe screen, hiding the app, locking the app or entering fake mode locks the safe. Opening a PDF in another app therefore locks the safe; the temporary decrypted copy is deleted when you come back to МС.
5. **Size cap** 200 MB per file (`kBoxMaxFileBytes`): the crypto is pure Dart.

## Global Constraints

- UI copy Russian, addresses the user as «ты», buttons start with a verb, no emoji.
- Colours, sizes, radii and fonts only via `context.ms`, `MsSpace`, `MsRadius`, `MsText`, `MsTextX`, `MsSize`. Never literals. New sizes go into `ms_sizes.dart`.
- Icons: Material Symbols Rounded (`Symbols.*_rounded`), 24 px.
- Never log or print the password, the box key, file names or contents (CLAUDE.md).
- `core/` changes are additive: a new file plus one export line. No existing crypto or sync function changes.
- No server, offline-first (I1, I3). The safe needs no network.
- Branch `feature/7-private-box`; small commits, English messages ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; push to remote `fork`, PR to `Skaslik/Skaslik` main.
- Run tests one file or one suite at a time (`--concurrency=1`): the PC is under load.
- Edit existing files with the Edit tool, not scripts.

## Review Focus

1. **Plaintext left on disk.** After adding a file and locking, nothing under `<data>/box/` may contain the file's name or bytes; `file_picker`'s cached copy and the opened temp copy must be deleted. Pinned by Task 2 `forensic` test and Task 4 `clearTemporaryFiles` step.
2. **App goes to background while unlocked.** The key must be dropped (except during the system file picker). Pinned by Task 2 `onAppHidden` tests.
3. **Crash in the middle of adding.** A half-written file must not appear in the list or break the next unlock. Pinned by Task 2 `.part` test.
4. **Tampered or truncated file.** Opening must fail with a clear message, never return wrong bytes or crash. Pinned by Task 1 tamper tests and Task 4 «Файл повреждён» handling.
5. **Odd file names and sizes.** Cyrillic, slashes, emoji, duplicates, 0-byte files, sizes that are exact multiples of the chunk. Pinned by Task 1 size and index tests and Task 2 `exportTemp` name test.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `core/lib/src/crypto/box.dart` | create | Keyring (password → wrapped box key), chunked stream cipher, encrypted index, `BoxEntry` |
| `core/lib/ms_core.dart` | modify | one export line |
| `core/test/box_test.dart` | create | crypto tests |
| `ms_app/lib/core/box/box_io.dart` | create | isolate-safe top-level file encrypt/decrypt functions |
| `ms_app/lib/core/box/private_box.dart` | create | `PrivateBox` state, storage layout, auto-lock, `privateBoxProvider` |
| `ms_app/test/core/private_box_test.dart` | create | service tests incl. forensic |
| `ms_app/lib/main.dart` | modify | lifecycle + app-lock → box lock |
| `ms_app/lib/features/files/file_sheets.dart` | modify | `SafeSheet` create / unlock / forgot |
| `ms_app/lib/features/files/safe_screen.dart` | create | `/safe` screen: list, add, open, delete, lock |
| `ms_app/lib/features/files/file_row.dart` | modify | `FileThumb.kind` constructor |
| `ms_app/lib/shell/ms_router.dart` | modify | `/safe` route |
| `ms_app/lib/design_system/ms_sizes.dart` | modify | none expected; add here if a size is needed |
| `ms_app/test/features/safe_test.dart` | create | sheet and screen widget tests |
| `ms_app/pubspec.yaml` | modify | `file_picker`, `open_filex` |
| `docs/CONCERNS.md` | modify | entries for the safe |

---

### Task 1: Box crypto in core

**Files:**
- Create: `core/lib/src/crypto/box.dart`
- Modify: `core/lib/ms_core.dart` (add `export 'src/crypto/box.dart';` after the `seed_phrase` export)
- Test: `core/test/box_test.dart`

**Interfaces:**
- Consumes: `argon2id32`, `xchachaSeal`, `xchachaOpen`, `bytesToHex`, `hexToBytes`, `utf8Encode`, `utf8Decode`, `keyLength`, `xchachaNonceLength`, `aeadTagLength` from `primitives.dart`.
- Produces:
  - `const int kBoxChunkSize = 1 << 20;` `const int kBoxMinPassword = 6;`
  - `class BoxKdf { const BoxKdf({int memoryKib = 131072, int iterations = 3}); }`
  - `class BoxCorrupt implements Exception { const BoxCorrupt(String reason); final String reason; }`
  - `class BoxKeyring { BoxKdf kdf; String salt; Uint8List wrapped; static Future<({BoxKeyring keyring, Uint8List key})> create(String password, {BoxKdf kdf}); Future<Uint8List?> tryUnlock(String password); String toJson(); static BoxKeyring fromJson(String json); }`
  - `class BoxEntry { const BoxEntry({required String id, required String name, required int size, required int addedAt}); String get kindLabel; bool get isImage; }`
  - `Future<Uint8List> sealBoxIndex(List<int> key, List<BoxEntry> entries)`; `Future<List<BoxEntry>> openBoxIndex(List<int> key, List<int> sealed)` (throws `BoxCorrupt`)
  - `Stream<List<int>> sealBoxStream(Stream<List<int>> plain, {required List<int> key, required String fileId, int chunkSize = kBoxChunkSize})`
  - `Stream<List<int>> openBoxStream(Stream<List<int>> sealed, {required List<int> key, required String fileId})` (errors with `BoxCorrupt`)
  - `String newBoxId()` — 32 hex chars, random.

**File format** (write it in the file's doc comment): header `4D 53 42 31` («MSB1») + chunk size as uint32 big-endian. Then chunks: each is `xchachaSeal(key, plain, aad: "msbox-chunk-v1" ‖ fileId ‖ index(uint64 BE) ‖ last(1 byte))`. Every chunk but the last holds exactly `chunkSize` plain bytes; the last holds 0…`chunkSize` and has `last = 1`. The AAD binds each chunk to its file, position and finality, so swapping, reordering, cutting or moving chunks between files fails authentication.

- [ ] **Step 1: Write the failing tests**

`core/test/box_test.dart`:

```dart
/// Личный сейф: ключ из пароля, потоковое шифрование файлов, индекс имён.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

// Argon2id at 64 KiB / 1 pass: fast in tests, same code path.
const fast = BoxKdf(memoryKib: 64, iterations: 1);

Stream<List<int>> pieces(List<int> bytes, Random rng) async* {
  var i = 0;
  while (i < bytes.length) {
    final n = 1 + rng.nextInt(23);
    final end = min(i + n, bytes.length);
    yield bytes.sublist(i, end);
    i = end;
  }
}

Future<Uint8List> collect(Stream<List<int>> s) async {
  final b = BytesBuilder(copy: false);
  await for (final p in s) {
    b.add(p);
  }
  return b.takeBytes();
}

Future<Uint8List> seal(List<int> plain, List<int> key, String id,
        {int chunk = 16}) =>
    collect(sealBoxStream(pieces(plain, Random(1)),
        key: key, fileId: id, chunkSize: chunk));

Future<Uint8List> open(List<int> sealed, List<int> key, String id) =>
    collect(openBoxStream(pieces(sealed, Random(2)), key: key, fileId: id));

void main() {
  final key = Uint8List.fromList(List.generate(32, (i) => i));

  group('keyring', () {
    test('the right password gives the key back, a wrong one gives null',
        () async {
      final made = await BoxKeyring.create('сейф-пароль', kdf: fast);
      expect(made.key, hasLength(32));
      expect(await made.keyring.tryUnlock('сейф-пароль'), made.key);
      expect(await made.keyring.tryUnlock('сейф-пароль '), isNull);
    });

    test('survives JSON; the JSON holds no key and no password', () async {
      final made = await BoxKeyring.create('пароль123', kdf: fast);
      final json = made.keyring.toJson();
      expect(json, isNot(contains('пароль123')));
      expect(json, isNot(contains(bytesToHex(made.key))));
      final back = BoxKeyring.fromJson(json);
      expect(await back.tryUnlock('пароль123'), made.key);
      expect((back.kdf.memoryKib, back.kdf.iterations), (64, 1));
    });

    test('same password twice: different salt, different key', () async {
      final a = await BoxKeyring.create('одинаковый', kdf: fast);
      final b = await BoxKeyring.create('одинаковый', kdf: fast);
      expect(a.keyring.salt, isNot(b.keyring.salt));
      expect(a.key, isNot(b.key));
    });

    test('garbage JSON is BoxCorrupt', () {
      expect(() => BoxKeyring.fromJson('{"v":9}'), throwsA(isA<BoxCorrupt>()));
      expect(() => BoxKeyring.fromJson('нет'), throwsA(isA<BoxCorrupt>()));
    });
  });

  group('stream', () {
    for (final size in [0, 1, 15, 16, 17, 32, 53, 1000]) {
      test('round trip, $size bytes (chunk 16)', () async {
        final plain = List<int>.generate(size, (i) => (i * 7) % 256);
        final sealed = await seal(plain, key, 'f1');
        expect(await open(sealed, key, 'f1'), plain);
      });
    }

    test('ciphertext does not contain the plaintext', () async {
      final plain = utf8.encode('ПАСПОРТ-СЕРИЯ-4510 ' * 20);
      final sealed = await seal(plain, key, 'f1');
      expect(latin1.decode(sealed, allowInvalid: true),
          isNot(contains('4510')));
    });

    Future<void> expectCorrupt(Future<Object?> f) =>
        expectLater(f, throwsA(isA<BoxCorrupt>()));

    test('a flipped byte is detected', () async {
      final sealed = await seal(List.filled(40, 5), key, 'f1');
      sealed[sealed.length - 3] ^= 1;
      await expectCorrupt(open(sealed, key, 'f1'));
    });

    test('wrong key or wrong file id is detected', () async {
      final sealed = await seal(List.filled(40, 5), key, 'f1');
      final other = Uint8List.fromList(List.filled(32, 9));
      await expectCorrupt(open(sealed, other, 'f1'));
      await expectCorrupt(open(sealed, key, 'f2'));
    });

    test('cutting off the last chunk is detected', () async {
      // 32 bytes at chunk 16: two full chunks + an empty last one (40 B).
      final sealed = await seal(List.filled(32, 5), key, 'f1');
      await expectCorrupt(open(sealed.sublist(0, sealed.length - 40), key, 'f1'));
    });

    test('swapping two chunks is detected', () async {
      final sealed = await seal(List.generate(40, (i) => i), key, 'f1');
      const h = 8, c = 16 + 40;
      final swapped = Uint8List.fromList([
        ...sealed.sublist(0, h),
        ...sealed.sublist(h + c, h + 2 * c),
        ...sealed.sublist(h, h + c),
        ...sealed.sublist(h + 2 * c),
      ]);
      await expectCorrupt(open(swapped, key, 'f1'));
    });

    test('no header, or a cut header, is detected', () async {
      await expectCorrupt(open(const [], key, 'f1'));
      await expectCorrupt(open(const [0x4D, 0x53], key, 'f1'));
      await expectCorrupt(open(utf8.encode('просто текст, не сейф'), key, 'f1'));
    });
  });

  group('index and entries', () {
    test('names of any kind survive; the sealed index hides them', () async {
      final entries = [
        const BoxEntry(id: 'a', name: 'Паспорт/скан 1.pdf', size: 10, addedAt: 1),
        const BoxEntry(id: 'b', name: 'фото 🐕.jpg', size: 0, addedAt: 2),
        const BoxEntry(id: 'c', name: 'фото 🐕.jpg', size: 3, addedAt: 3),
      ];
      final sealed = await sealBoxIndex(key, entries);
      expect(latin1.decode(sealed, allowInvalid: true), isNot(contains('pdf')));
      final back = await openBoxIndex(key, sealed);
      expect(back.map((e) => (e.id, e.name, e.size, e.addedAt)).toList(),
          entries.map((e) => (e.id, e.name, e.size, e.addedAt)).toList());
    });

    test('a wrong key is BoxCorrupt', () async {
      final sealed = await sealBoxIndex(key, const []);
      await expectLater(openBoxIndex(List.filled(32, 1), sealed),
          throwsA(isA<BoxCorrupt>()));
    });

    test('kind label and images', () {
      BoxEntry e(String n) => BoxEntry(id: 'x', name: n, size: 1, addedAt: 1);
      expect(e('скан.PDF').kindLabel, 'PDF');
      expect(e('без точки').kindLabel, 'ФАЙЛ');
      expect(e('.hidden').kindLabel, 'ФАЙЛ');
      expect(e('a.jpeg').isImage, isTrue);
      expect(e('a.pdf').isImage, isFalse);
    });

    test('new ids are 32 hex chars and differ', () {
      final a = newBoxId(), b = newBoxId();
      expect(a, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(a, isNot(b));
    });
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `cd core && dart test test/box_test.dart`
Expected: compile errors, `BoxKdf` / `sealBoxStream` not defined.

- [ ] **Step 3: Implement `core/lib/src/crypto/box.dart`**

```dart
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

int _readHeader(Uint8List h) {
  for (var i = 0; i < 4; i++) {
    if (h[i] != _magic[i]) throw const BoxCorrupt('не файл сейфа');
  }
  final size = ByteData.sublistView(h, 4, 8).getUint32(0);
  if (size < 1 || size > _maxChunk) throw const BoxCorrupt('не файл сейфа');
  return size;
}
```

Add the export to `core/lib/ms_core.dart`:

```dart
export 'src/crypto/seed_phrase.dart';
export 'src/crypto/box.dart';
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `cd core && dart test test/box_test.dart` → all pass.
Then: `cd core && dart analyze && dart test --concurrency=1` → no errors or warnings, all pass.

- [ ] **Step 5: Commit**

```bash
git add core/lib/src/crypto/box.dart core/lib/ms_core.dart core/test/box_test.dart
git commit -m "core: private box crypto — password-wrapped key, chunked file format, sealed index"
```

---

### Task 2: `PrivateBox` service in the app

**Files:**
- Create: `ms_app/lib/core/box/box_io.dart`
- Create: `ms_app/lib/core/box/private_box.dart`
- Modify: `ms_app/lib/main.dart`
- Test: `ms_app/test/core/private_box_test.dart`

**Interfaces:**
- Consumes (Task 1): `BoxKdf`, `BoxKeyring.create/tryUnlock/toJson/fromJson`, `BoxEntry`, `sealBoxIndex`, `openBoxIndex`, `sealBoxStream`, `openBoxStream`, `newBoxId`, `BoxCorrupt`, `kBoxMinPassword`.
- Produces:
  - `enum BoxState { absent, locked, unlocked }`
  - `const int kBoxMaxFileBytes = 200 * 1024 * 1024;`
  - `class BoxTooLarge implements Exception { const BoxTooLarge(int bytes); final int bytes; }`
  - `typedef BoxRunner = Future<R> Function<R>(FutureOr<R> Function() task);`
  - `class PrivateBox extends ChangeNotifier` with: `PrivateBox({required Directory dir, required Future<Directory> Function() tempDir, BoxKdf kdf, BoxRunner? runner, DateTime Function()? clock})`; getters `BoxState state`, `bool busy`, `List<BoxEntry> entries` (newest first); methods `Future<void> init()`, `Future<void> create(String password)`, `Future<bool> unlock(String password)`, `void lock({bool wipe = true})`, `Future<BoxEntry> add(String sourcePath, String name)`, `Future<Uint8List> readBytes(String id)`, `Future<File> exportTemp(String id)`, `Future<void> remove(String id)`, `Future<void> destroy()`, `Future<void> wipeTemp()`, `void onAppHidden()`, `void onAppResumed()`, `Future<T> away<T>(Future<T> Function() f)`.
  - `final privateBoxProvider = ChangeNotifierProvider<PrivateBox>(...)`.
  - In `box_io.dart`: `Future<int> encryptFileTo({required String src, required String dst, required Uint8List key, required String fileId})`, `Future<void> decryptFileTo({required String src, required String dst, required Uint8List key, required String fileId})`, `Future<Uint8List> decryptFileToBytes({required String src, required Uint8List key, required String fileId})`.

**Storage layout** under `<AppPaths.dataDir>/box/`: `keyring.json`, `index.bin`, `files/<id>.bin` (plus `<id>.bin.part` while writing). Temp copies for other apps: `<temp>/ms_box/<random>/<name>`.

**Isolate gotcha:** a closure passed to `Isolate.run` carries its whole surrounding context. A closure created inside a `PrivateBox` method can drag `this` (and its widget listeners) along and fail with «object is unsendable». Build every isolate task in a **static** method that only sees its parameters (the `_…Task` helpers below).

- [ ] **Step 1: Write the failing tests**

`ms_app/test/core/private_box_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ms_app/core/box/private_box.dart';
import 'package:ms_core/ms_core.dart' hide Clip;
import 'package:path/path.dart' as p;

Future<R> inline<R>(FutureOr<R> Function() task) async => task();

void main() {
  late Directory root;
  late Directory temp;
  late PrivateBox box;
  var now = DateTime(2026, 10, 11, 12);

  PrivateBox make() => PrivateBox(
        dir: Directory(p.join(root.path, 'box')),
        tempDir: () async => temp,
        kdf: const BoxKdf(memoryKib: 64, iterations: 1),
        runner: inline,
        clock: () => now,
      );

  File source(String name, List<int> bytes) =>
      File(p.join(root.path, 'src', name))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ms_box');
    temp = Directory(p.join(root.path, 'cache'))..createSync();
    box = make();
    await box.init();
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('a new phone has no safe; creating one opens it', () async {
    expect(box.state, BoxState.absent);
    await box.create('секрет12');
    expect(box.state, BoxState.unlocked);
    expect(box.entries, isEmpty);
  });

  test('short passwords are refused', () async {
    expect(() => box.create('12345'), throwsArgumentError);
    expect(box.state, BoxState.absent);
  });

  test('lock, wrong password, right password', () async {
    await box.create('секрет12');
    await box.add(source('a.txt', [1, 2, 3]).path, 'a.txt');
    box.lock();
    expect(box.state, BoxState.locked);
    expect(box.entries, isEmpty);
    expect(await box.unlock('секрет13'), isFalse);
    expect(box.state, BoxState.locked);
    expect(await box.unlock('секрет12'), isTrue);
    expect(box.entries.single.name, 'a.txt');
  });

  test('a restart finds the safe locked', () async {
    await box.create('секрет12');
    final again = make();
    await again.init();
    expect(again.state, BoxState.locked);
  });

  test('files come back byte for byte; newest first', () async {
    await box.create('секрет12');
    final bytes = List<int>.generate(3 * 1024 * 1024 + 7, (i) => i % 251);
    await box.add(source('big.bin', bytes).path, 'big.bin');
    now = now.add(const Duration(minutes: 1));
    await box.add(source('empty.txt', const []).path, 'empty.txt');
    expect(box.entries.map((e) => e.name), ['empty.txt', 'big.bin']);
    final big = box.entries.last;
    expect(big.size, bytes.length);
    expect(await box.readBytes(big.id), bytes);
    expect(await box.readBytes(box.entries.first.id), isEmpty);
  });

  test('forensic: nothing on disk shows a name or the content', () async {
    await box.create('секрет12');
    const marker = 'ПАСПОРТ-4510-123456';
    await box.add(source('паспорт.txt', utf8.encode(marker * 50)).path,
        'Паспорт Миши.txt');
    box.lock();
    final all = Directory(p.join(root.path, 'box'))
        .listSync(recursive: true)
        .whereType<File>();
    expect(all, isNotEmpty);
    for (final f in all) {
      final text = latin1.decode(f.readAsBytesSync(), allowInvalid: true);
      final asUtf = utf8.decode(f.readAsBytesSync(), allowMalformed: true);
      expect(asUtf, isNot(contains('Паспорт')), reason: f.path);
      expect(asUtf, isNot(contains('4510')), reason: f.path);
      expect(text, isNot(contains('4510')), reason: f.path);
      expect(p.basename(f.path), isNot(contains('аспорт')));
    }
  });

  test('a half-written file from a crash is cleaned up and not listed',
      () async {
    await box.create('секрет12');
    box.lock();
    final part = File(p.join(root.path, 'box', 'files', 'dead.bin.part'))
      ..writeAsBytesSync([1, 2, 3]);
    final again = make();
    await again.init();
    expect(part.existsSync(), isFalse);
    expect(await again.unlock('секрет12'), isTrue);
    expect(again.entries, isEmpty);
  });

  test('too large files are refused before any work', () async {
    await box.create('секрет12');
    final f = File(p.join(root.path, 'src', 'huge.bin'))
      ..createSync(recursive: true);
    // A sparse file one byte over the cap: instant, takes no disk.
    f.openSync(mode: FileMode.write)
      ..setPositionSync(kBoxMaxFileBytes)
      ..writeByteSync(0)
      ..closeSync();
    await expectLater(box.add(f.path, 'huge.bin'), throwsA(isA<BoxTooLarge>()));
    expect(box.entries, isEmpty);
  });

  test('exportTemp keeps an odd name readable; lock wipes the copy',
      () async {
    await box.create('секрет12');
    final e = await box.add(source('x.pdf', [9, 9]).path, 'Договор/аренда 🐕.pdf');
    final out = await box.exportTemp(e.id);
    expect(out.readAsBytesSync(), [9, 9]);
    expect(p.basename(out.path), 'Договор_аренда 🐕.pdf');
    box.lock();
    await box.wipeTemp();
    expect(out.existsSync(), isFalse);
  });

  test('remove deletes the entry and its file', () async {
    await box.create('секрет12');
    final e = await box.add(source('a.txt', [1]).path, 'a.txt');
    await box.remove(e.id);
    expect(box.entries, isEmpty);
    expect(File(p.join(root.path, 'box', 'files', '${e.id}.bin')).existsSync(),
        isFalse);
  });

  test('hiding the app locks it; the copy for another app survives until back',
      () async {
    await box.create('секрет12');
    final e = await box.add(source('a.pdf', [1]).path, 'a.pdf');
    final out = await box.exportTemp(e.id);
    box.onAppHidden();
    expect(box.state, BoxState.locked);
    expect(out.existsSync(), isTrue); // the viewer may still read it
    box.onAppResumed();
    await Future<void>.delayed(Duration.zero);
    await box.wipeTemp(); // settle the unawaited wipe
    expect(out.existsSync(), isFalse);
  });

  test('the system file picker does not lock it', () async {
    await box.create('секрет12');
    await box.away(() async {
      box.onAppHidden();
      expect(box.state, BoxState.unlocked);
    });
    box.onAppHidden();
    expect(box.state, BoxState.locked);
  });

  test('forgot the password: destroy removes everything', () async {
    await box.create('секрет12');
    await box.add(source('a.txt', [1]).path, 'a.txt');
    box.lock();
    await box.destroy();
    expect(box.state, BoxState.absent);
    expect(Directory(p.join(root.path, 'box')).existsSync(), isFalse);
  });

  test('locked: reading or adding is refused', () async {
    await box.create('секрет12');
    box.lock();
    expect(() => box.readBytes('x'), throwsStateError);
    expect(() => box.add('x', 'x'), throwsStateError);
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `cd ms_app && flutter test test/core/private_box_test.dart`
Expected: compile error, `package:ms_app/core/box/private_box.dart` not found.

- [ ] **Step 3: Implement `ms_app/lib/core/box/box_io.dart`**

```dart
/// File ↔ box format, as plain top-level functions so they can run in
/// `Isolate.run` without dragging app state along.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ms_core/ms_core.dart' hide Clip;

/// Encrypts [src] into [dst] via `[dst].part` + rename, so a crash never
/// leaves a half file under the real name. Returns the plaintext size.
Future<int> encryptFileTo({
  required String src,
  required String dst,
  required Uint8List key,
  required String fileId,
}) async {
  final part = File('$dst.part');
  var size = 0;
  final plain = File(src).openRead().map((b) {
    size += b.length;
    return b;
  });
  final sink = part.openWrite();
  try {
    await sink.addStream(sealBoxStream(plain, key: key, fileId: fileId));
    await sink.flush();
    await sink.close();
  } catch (_) {
    await sink.close();
    if (await part.exists()) await part.delete();
    rethrow;
  }
  await part.rename(dst);
  return size;
}

/// Decrypts [src] into a plain file [dst]; removes [dst] on failure.
Future<void> decryptFileTo({
  required String src,
  required String dst,
  required Uint8List key,
  required String fileId,
}) async {
  final out = File(dst);
  final sink = out.openWrite();
  try {
    await sink.addStream(
        openBoxStream(File(src).openRead(), key: key, fileId: fileId));
    await sink.flush();
    await sink.close();
  } catch (_) {
    await sink.close();
    if (await out.exists()) await out.delete();
    rethrow;
  }
}

/// Decrypts [src] into memory (image preview).
Future<Uint8List> decryptFileToBytes({
  required String src,
  required Uint8List key,
  required String fileId,
}) async {
  final b = BytesBuilder(copy: false);
  await for (final piece
      in openBoxStream(File(src).openRead(), key: key, fileId: fileId)) {
    b.add(piece);
  }
  return b.takeBytes();
}
```

- [ ] **Step 4: Implement `ms_app/lib/core/box/private_box.dart`**

```dart
/// «Личный сейф»: files only this person can open, only on this phone.
///
/// Not synced and not in the recovery sheet (PLAN.md §2 п.5: P_box is not
/// derived from S). Forgetting the password loses the files; the UI says so.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ms_core/ms_core.dart' hide Clip;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../storage/app_paths.dart';
import 'box_io.dart';

enum BoxState { absent, locked, unlocked }

/// Per file. The crypto is pure Dart; bigger files would take minutes.
const int kBoxMaxFileBytes = 200 * 1024 * 1024;

class BoxTooLarge implements Exception {
  const BoxTooLarge(this.bytes);
  final int bytes;
}

typedef BoxRunner = Future<R> Function<R>(FutureOr<R> Function() task);

class PrivateBox extends ChangeNotifier {
  PrivateBox({
    required this.dir,
    required Future<Directory> Function() tempDir,
    this.kdf = const BoxKdf(),
    BoxRunner? runner,
    DateTime Function()? clock,
  })  : _tempDir = tempDir,
        _run = runner ?? Isolate.run,
        _clock = clock ?? DateTime.now;

  final Directory dir;
  final BoxKdf kdf;
  final Future<Directory> Function() _tempDir;
  final BoxRunner _run;
  final DateTime Function() _clock;

  BoxState _state = BoxState.absent;
  Uint8List? _key;
  List<BoxEntry> _entries = const [];
  bool _busy = false;
  int _away = 0;

  BoxState get state => _state;
  bool get busy => _busy;

  /// Newest first. Empty unless unlocked.
  List<BoxEntry> get entries =>
      [..._entries]..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  File get _keyring => File(p.join(dir.path, 'keyring.json'));
  File get _index => File(p.join(dir.path, 'index.bin'));
  Directory get _files => Directory(p.join(dir.path, 'files'));
  String _path(String id) => p.join(_files.path, '$id.bin');

  // --- isolate tasks: static, so they capture only their parameters ---
  static FutureOr<({BoxKeyring keyring, Uint8List key})> Function()
      _createTask(String password, BoxKdf kdf) =>
          () => BoxKeyring.create(password, kdf: kdf);
  static FutureOr<Uint8List?> Function() _unlockTask(
          BoxKeyring keyring, String password) =>
      () => keyring.tryUnlock(password);
  static FutureOr<int> Function() _encryptTask(
          String src, String dst, Uint8List key, String id) =>
      () => encryptFileTo(src: src, dst: dst, key: key, fileId: id);
  static FutureOr<void> Function() _decryptTask(
          String src, String dst, Uint8List key, String id) =>
      () => decryptFileTo(src: src, dst: dst, key: key, fileId: id);
  static FutureOr<Uint8List> Function() _bytesTask(
          String src, Uint8List key, String id) =>
      () => decryptFileToBytes(src: src, key: key, fileId: id);

  /// Reads the state from disk, drops half-written files and old temp copies.
  Future<void> init() async {
    _state = await _keyring.exists() ? BoxState.locked : BoxState.absent;
    final indexPart = File('${_index.path}.part');
    if (await indexPart.exists()) await indexPart.delete();
    if (await _files.exists()) {
      await for (final f in _files.list()) {
        if (f.path.endsWith('.part')) await f.delete();
      }
    }
    await wipeTemp();
    notifyListeners();
  }

  Future<void> create(String password) async {
    if (_state != BoxState.absent) throw StateError('сейф уже есть');
    if (password.length < kBoxMinPassword) {
      throw ArgumentError('пароль короче $kBoxMinPassword символов');
    }
    await _busyWhile(() async {
      final made = await _run(_createTask(password, kdf));
      await _files.create(recursive: true);
      // Index first: a crash before the keyring leaves «no safe».
      await _writeIndex(made.key, const []);
      await _keyring.writeAsString(made.keyring.toJson(), flush: true);
      _key = made.key;
      _entries = const [];
      _state = BoxState.unlocked;
    });
  }

  /// False when the password is wrong.
  Future<bool> unlock(String password) async {
    if (_state == BoxState.unlocked) return true;
    if (_state == BoxState.absent) return false;
    final keyring = BoxKeyring.fromJson(await _keyring.readAsString());
    return _busyWhile(() async {
      final key = await _run(_unlockTask(keyring, password));
      if (key == null) return false;
      _entries = await _readIndex(key);
      _key = key;
      _state = BoxState.unlocked;
      return true;
    });
  }

  /// Drops the key. [wipe] = false keeps a copy another app may be reading;
  /// it goes on the next resume.
  void lock({bool wipe = true}) {
    if (_state != BoxState.unlocked) return;
    final k = _key;
    if (k != null) k.fillRange(0, k.length, 0);
    _key = null;
    _entries = const [];
    _state = BoxState.locked;
    if (wipe) unawaited(wipeTemp());
    notifyListeners();
  }

  void onAppHidden() {
    if (_away > 0) return;
    lock(wipe: false);
  }

  void onAppResumed() {
    if (_state != BoxState.unlocked) unawaited(wipeTemp());
  }

  /// For the system file picker: hiding the app inside [f] doesn't lock.
  Future<T> away<T>(Future<T> Function() f) async {
    _away++;
    try {
      return await f();
    } finally {
      _away--;
    }
  }

  Future<BoxEntry> add(String sourcePath, String name) async {
    final key = _requireKey();
    final size = await File(sourcePath).length();
    if (size > kBoxMaxFileBytes) throw BoxTooLarge(size);
    final id = newBoxId();
    return _busyWhile(() async {
      await _run(_encryptTask(sourcePath, _path(id), key, id));
      final entry = BoxEntry(
          id: id,
          name: name,
          size: size,
          addedAt: _clock().millisecondsSinceEpoch);
      final next = [..._entries, entry];
      await _writeIndex(key, next);
      _entries = next;
      return entry;
    });
  }

  Future<Uint8List> readBytes(String id) {
    final key = _requireKey();
    return _busyWhile(() => _run(_bytesTask(_path(id), key, id)));
  }

  /// A plain copy for another app, under the file's own name.
  Future<File> exportTemp(String id) async {
    final key = _requireKey();
    final entry = _entries.firstWhere((e) => e.id == id);
    final tmp = await _tempDir();
    final sub = Directory(p.join(tmp.path, 'ms_box', newBoxId()));
    await sub.create(recursive: true);
    final dst = p.join(sub.path, entry.name.replaceAll(RegExp(r'[/\\]'), '_'));
    await _busyWhile(() => _run(_decryptTask(_path(id), dst, key, id)));
    return File(dst);
  }

  Future<void> remove(String id) async {
    final key = _requireKey();
    final next = _entries.where((e) => e.id != id).toList();
    await _writeIndex(key, next);
    _entries = next;
    final f = File(_path(id));
    if (await f.exists()) await f.delete();
    notifyListeners();
  }

  /// «Забыл пароль»: the files can't be opened anyway; remove them.
  Future<void> destroy() async {
    lock();
    if (await dir.exists()) await dir.delete(recursive: true);
    await wipeTemp();
    _state = BoxState.absent;
    notifyListeners();
  }

  Future<void> wipeTemp() async {
    final d = Directory(p.join((await _tempDir()).path, 'ms_box'));
    if (await d.exists()) await d.delete(recursive: true);
  }

  Uint8List _requireKey() {
    final k = _key;
    if (_state != BoxState.unlocked || k == null) {
      throw StateError('сейф закрыт');
    }
    return k;
  }

  Future<T> _busyWhile<T>(Future<T> Function() f) async {
    _busy = true;
    notifyListeners();
    try {
      return await f();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _writeIndex(Uint8List key, List<BoxEntry> entries) async {
    final part = File('${_index.path}.part');
    await part.writeAsBytes(await sealBoxIndex(key, entries), flush: true);
    await part.rename(_index.path);
  }

  Future<List<BoxEntry>> _readIndex(Uint8List key) async =>
      await _index.exists()
          ? openBoxIndex(key, await _index.readAsBytes())
          : const <BoxEntry>[];
}

final privateBoxProvider = ChangeNotifierProvider<PrivateBox>((ref) {
  final box = PrivateBox(
    dir: Directory(
        p.join(AppPaths.dataDir ?? Directory.current.path, 'box')),
    tempDir: getTemporaryDirectory,
  );
  unawaited(box.init());
  return box;
});
```

- [ ] **Step 5: Wire the lifecycle in `ms_app/lib/main.dart`**

Add the import `import 'core/box/private_box.dart';`. In `_MsRootState.initState`, extend the existing `AppLifecycleListener`:

```dart
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(themeControllerProvider).refresh();
        if (ref.exists(weatherProvider)) ref.read(weatherProvider).refresh();
        if (ref.exists(privateBoxProvider)) {
          ref.read(privateBoxProvider).onAppResumed();
        }
      },
      onHide: () {
        if (ref.exists(weatherProvider)) ref.read(weatherProvider).pause();
        if (ref.exists(privateBoxProvider)) {
          ref.read(privateBoxProvider).onAppHidden();
        }
      },
    );
```

At the top of `build`, right after `final lock = ref.watch(appLockProvider);`, add:

```dart
    // Locking the app or entering fake mode closes the safe as well.
    ref.listen<AppLock>(appLockProvider, (_, l) {
      if ((l.inFake || !l.unlocked) && ref.exists(privateBoxProvider)) {
        ref.read(privateBoxProvider).lock();
      }
    });
```

- [ ] **Step 6: Run the tests and confirm they pass**

Run: `cd ms_app && flutter test test/core/private_box_test.dart` → all pass.
Run: `cd ms_app && flutter analyze` → no issues.

- [ ] **Step 7: Commit**

```bash
git add ms_app/lib/core/box ms_app/lib/main.dart ms_app/test/core/private_box_test.dart
git commit -m "app: PrivateBox — local encrypted safe with auto-lock and crash-safe writes"
```

---

### Task 3: Packages and the safe sheet

**Files:**
- Modify: `ms_app/pubspec.yaml`, `ms_app/pubspec.lock`
- Modify: `ms_app/lib/features/files/file_sheets.dart` (replace `SafeSheet`)
- Test: `ms_app/test/features/safe_test.dart` (sheet part)

**Interfaces:**
- Consumes (Task 2): `privateBoxProvider`, `PrivateBox.state/busy/create/unlock/destroy`, `BoxState`, `kBoxMinPassword`.
- Produces: `SafeSheet` (same name, now a `ConsumerStatefulWidget`); after a successful create or unlock it pops the sheet and calls `context.push('/safe')` (route from Task 4).

- [ ] **Step 1: Add the packages (only after the user's OK)**

Run in the user's terminal (pub cache writes must be real):

```bash
cd ms_app && flutter pub add file_picker open_filex
```

If pub.dev is blocked, stop and tell the user. Then read the installed APIs instead of guessing: open `file_picker`'s `lib/src/file_picker.dart` and `open_filex`'s `lib/src/open_filex.dart` via the Dart MCP `read_package_uris` tool, and note in the commit message the versions resolved. Task 4 uses `FilePicker.platform.pickFiles(allowMultiple: true)`, `FilePicker.platform.clearTemporaryFiles()`, `PlatformFile.path/name/size`, `OpenFilex.open(path)` and `ResultType.done`; adjust if the installed version differs.

- [ ] **Step 2: Write the failing sheet tests**

`ms_app/test/features/safe_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_app/core/box/private_box.dart';
import 'package:ms_app/core/pair/pair.dart';
import 'package:ms_app/design_system/ms_format.dart';
import 'package:ms_app/design_system/ms_theme.dart';
import 'package:ms_app/features/files/file_sheets.dart';
import 'package:ms_core/ms_core.dart' hide Clip;
import 'package:path/path.dart' as p;

Future<R> inline<R>(FutureOr<R> Function() task) async => task();

void main() {
  const pair = Pair(
      me: kMichael, partner: kSofia, myDeviceId: 'A', partnerDeviceId: 'B');
  late Directory root;
  late PrivateBox box;

  setUpAll(initMsFormat);

  Future<void> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        pairProvider.overrideWithValue(pair),
        privateBoxProvider.overrideWith((_) => box),
      ],
      child: MaterialApp(
        theme: MsTheme.evening(),
        home: const Scaffold(body: SingleChildScrollView(child: SafeSheet())),
      ),
    ));
    await tester.pump();
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('ms_safe_ui');
    box = PrivateBox(
      dir: Directory(p.join(root.path, 'box')),
      tempDir: () async => Directory(p.join(root.path, 'cache')),
      kdf: const BoxKdf(memoryKib: 64, iterations: 1),
      runner: inline,
    );
  });
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('no safe yet: two password fields, create enabled only when '
      'they match and are long enough', (tester) async {
    await tester.runAsync(box.init);
    await pumpSheet(tester);
    expect(find.text('Создать сейф'), findsOneWidget);
    expect(find.textContaining('Забудешь пароль'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    MsButton create() => tester.widget<MsButton>(
        find.widgetWithText(MsButton, 'Создать сейф'));
    await tester.enterText(fields.at(0), '12345');
    await tester.enterText(fields.at(1), '12345');
    await tester.pump();
    expect(create().onPressed, isNull);
    await tester.enterText(fields.at(0), 'секрет12');
    await tester.enterText(fields.at(1), 'секрет13');
    await tester.pump();
    expect(create().onPressed, isNull);
    await tester.enterText(fields.at(1), 'секрет12');
    await tester.pump();
    expect(create().onPressed, isNotNull);
  });

  testWidgets('locked: one field, «Открыть сейф», «Забыл пароль»',
      (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
      box.lock();
    });
    await pumpSheet(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Открыть сейф'), findsOneWidget);
    expect(find.text('Забыл пароль'), findsOneWidget);
    expect(find.textContaining('София не видит'), findsOneWidget);
  });

  testWidgets('wrong password says so and keeps the sheet', (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
      box.lock();
    });
    await pumpSheet(tester);
    await tester.enterText(find.byType(TextField), 'не тот');
    await tester.runAsync(() async {
      await tester.tap(find.text('Открыть сейф'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Не тот пароль'), findsOneWidget);
    expect(box.state, BoxState.locked);
  });
}
```

- [ ] **Step 3: Run and confirm they fail**

Run: `cd ms_app && flutter test test/features/safe_test.dart`
Expected: failures, the current sheet shows no fields.

- [ ] **Step 4: Replace `SafeSheet` in `file_sheets.dart`**

Add imports at the top of `file_sheets.dart`:

```dart
import 'package:go_router/go_router.dart';
import '../../core/box/private_box.dart';
```

Replace the whole `class SafeSheet extends ConsumerWidget { … }` with:

```dart
class SafeSheet extends ConsumerStatefulWidget {
  const SafeSheet({super.key});
  @override
  ConsumerState<SafeSheet> createState() => _SafeSheetState();
}

class _SafeSheetState extends ConsumerState<SafeSheet> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      _password.text.length >= kBoxMinPassword &&
      _password.text == _repeat.text;

  Future<void> _go(PrivateBox box) async {
    final pw = _password.text;
    if (box.state == BoxState.absent) {
      await box.create(pw);
    } else if (!await box.unlock(pw)) {
      if (mounted) setState(() => _error = 'Не тот пароль');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    context.push('/safe');
  }

  Future<void> _forgot(PrivateBox box) async {
    final ms = context.ms;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сейф?'),
        content: const Text(
            'Без пароля файлы внутри не открыть. Можно удалить сейф '
            'и завести новый — старые файлы пропадут навсегда.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Удалить сейф',
                  style: MsTextX.link.copyWith(color: ms.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await box.destroy();
    if (mounted) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final partner = ref.watch(pairProvider).partner;
    final box = ref.watch(privateBoxProvider);
    final creating = box.state == BoxState.absent;
    Widget field(TextEditingController c, String hint) => SizedBox(
          height: MsSize.fieldH,
          child: TextField(
            controller: c,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            style: MsText.body.copyWith(color: ms.ink),
            decoration: InputDecoration(hintText: hint),
            onChanged: (_) => setState(() => _error = null),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: MsSize.sheetIconBox,
            height: MsSize.sheetIconBox,
            decoration: BoxDecoration(
              color: ms.flameSoft,
              borderRadius: BorderRadius.circular(MsRadius.radiusMd),
            ),
            child: Icon(Symbols.lock_rounded, size: MsSize.icon, color: ms.ink),
          ),
        ),
        const SizedBox(height: MsSpace.space3),
        Text('Личный сейф', style: MsText.title.copyWith(color: ms.ink)),
        const SizedBox(height: MsSpace.space1),
        Text(
          'Отдельный пароль. ${partner.name} не видит ни файлов, ни их названий, '
          'а без пароля их не открыть даже с этого телефона.',
          style: MsText.bodySm.copyWith(color: ms.inkMuted),
        ),
        Padding(
          padding: const EdgeInsets.only(
              top: MsSize.formLabelTop, bottom: MsSize.formLabelGap),
          child: MsEyebrow(creating ? 'Придумай пароль сейфа' : 'Пароль сейфа'),
        ),
        field(_password, creating ? 'не короче $kBoxMinPassword символов' : ''),
        if (creating) ...[
          const SizedBox(height: MsSpace.space2),
          field(_repeat, 'ещё раз'),
          const SizedBox(height: MsSpace.space2),
          MsMeta(
              'Забудешь пароль — файлы не вернуть: ни ${partner.name}, '
              'ни лист восстановления не помогут. Сейф живёт только '
              'на этом телефоне.',
              maxLines: 3),
        ],
        SizedBox(
          height: MsSpace.space6,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _error == null ? null : MsMeta(_error!, color: ms.danger),
          ),
        ),
        MsButton(
          label: box.busy
              ? (creating ? 'Создаю…' : 'Открываю…')
              : (creating ? 'Создать сейф' : 'Открыть сейф'),
          expand: true,
          onPressed: box.busy ||
                  (creating ? !_canCreate : _password.text.isEmpty)
              ? null
              : () => _go(box),
        ),
        if (!creating) ...[
          const SizedBox(height: MsSpace.space2),
          Center(child: MsLink('Забыл пароль', onTap: () => _forgot(box))),
        ],
      ],
    );
  }
}
```

If `MsMeta` has no `color` parameter, use the one the lock screen uses for «Неверный PIN» (check `lib/features/lock/lock_screen.dart`). If `showSafeSheet` passes no scroll view, keep it: the sheet scrolls via `showMsSheet`.

- [ ] **Step 5: Run and confirm they pass**

Run: `cd ms_app && flutter test test/features/safe_test.dart` → pass.
Run: `cd ms_app && flutter analyze` → no issues. (It will report `/safe` only at runtime; Task 4 adds the route.)

- [ ] **Step 6: Commit**

```bash
git add ms_app/pubspec.yaml ms_app/pubspec.lock ms_app/lib/features/files/file_sheets.dart ms_app/test/features/safe_test.dart
git commit -m "app: safe sheet — create, unlock and forgot-password; add file_picker and open_filex"
```

---

### Task 4: The safe screen

**Files:**
- Create: `ms_app/lib/features/files/safe_screen.dart`
- Modify: `ms_app/lib/features/files/file_row.dart` (`FileThumb.kind`)
- Modify: `ms_app/lib/shell/ms_router.dart` (`/safe`)
- Test: `ms_app/test/features/safe_test.dart` (screen part, appended)

**Interfaces:**
- Consumes: `privateBoxProvider`, `PrivateBox.entries/state/busy/add/readBytes/exportTemp/remove/lock/away`, `BoxTooLarge`, `BoxEntry.kindLabel/isImage`, `formatBytes`, `formatWhen`, `MsScreen`, `MsScreenHeader`, `MsIconButton`, `MsButton(pill: true)`, `MsToast.show`, `showMsSheet`.
- Produces: `class SafeScreen extends ConsumerStatefulWidget` (const ctor, optional `DateTime Function()? clock`); route `/safe` outside the shell; `const FileThumb.kind({required String label, required bool image})`.

- [ ] **Step 1: Write the failing screen tests (append to `safe_test.dart`)**

Add imports: `import 'package:ms_app/features/files/safe_screen.dart';`

```dart
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        pairProvider.overrideWithValue(pair),
        privateBoxProvider.overrideWith((_) => box),
      ],
      child: MaterialApp(
        theme: MsTheme.evening(),
        home: SafeScreen(clock: () => DateTime(2026, 10, 11, 12)),
      ),
    ));
    await tester.pump();
  }

  testWidgets('open safe, empty: a warm sentence and «Добавить файл»',
      (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
    });
    await pumpScreen(tester);
    expect(find.text('Личный сейф'), findsOneWidget);
    expect(find.textContaining('Пусто'), findsOneWidget);
    expect(find.text('Добавить файл'), findsOneWidget);
  });

  testWidgets('lists files with kind, size and when', (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
      final f = File(p.join(root.path, 'скан.pdf'))
        ..writeAsBytesSync(List.filled(2048, 1));
      await box.add(f.path, 'Паспорт.pdf');
    });
    await pumpScreen(tester);
    expect(find.text('Паспорт.pdf'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.textContaining('2${kThousandsSep}КБ'), findsOneWidget);
  });

  testWidgets('the lock button closes the safe', (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
    });
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Закрыть сейф'));
    await tester.pump();
    expect(box.state, BoxState.locked);
  });

  testWidgets('leaving the screen locks the safe', (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
    });
    await pumpScreen(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(); // the lock runs right after the screen is gone
    expect(box.state, BoxState.locked);
  });
```

If `MsIconButton` doesn't expose `label` as a tooltip, find the button by `find.byIcon(Symbols.lock_rounded)` instead and add the `material_symbols_icons` import.

- [ ] **Step 2: Run and confirm they fail**

Run: `cd ms_app && flutter test test/features/safe_test.dart`
Expected: compile error, `safe_screen.dart` not found.

- [ ] **Step 3: Add `FileThumb.kind` in `file_row.dart`**

Replace the `FileThumb` constructor and field:

```dart
class FileThumb extends StatelessWidget {
  FileThumb({super.key, required DocMeta doc})
      : label = doc.kindLabel,
        image = doc.isImage;

  /// For files that aren't in the shared folder (the private box).
  const FileThumb.kind({super.key, required this.label, required this.image});

  final String label;
  final bool image;
```

and in `build` use `image ? Symbols.image_rounded : Symbols.description_rounded` and `Text(label, …)`. Existing call sites `FileThumb(doc: d)` keep working; drop `const` where the analyzer flags it.

- [ ] **Step 4: Create `ms_app/lib/features/files/safe_screen.dart`**

```dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;
import 'package:open_filex/open_filex.dart';

import '../../core/box/private_box.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import 'file_row.dart';

/// Inside «Личный сейф». Full screen over the tab bar; leaving it locks.
class SafeScreen extends ConsumerStatefulWidget {
  const SafeScreen({super.key, this.clock});
  final DateTime Function()? clock;

  @override
  ConsumerState<SafeScreen> createState() => _SafeScreenState();
}

class _SafeScreenState extends ConsumerState<SafeScreen> {
  late final PrivateBox _box = ref.read(privateBoxProvider);

  @override
  void dispose() {
    // Not inside dispose itself: lock() notifies listeners, and the widget
    // tree is locked while it is being torn down.
    final box = _box;
    Future.microtask(box.lock);
    super.dispose();
  }

  void _close() {
    _box.lock();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/files');
    }
  }

  Future<void> _add() async {
    final picked = await _box.away(
        () => FilePicker.platform.pickFiles(allowMultiple: true));
    if (picked == null || !mounted) return;
    var added = 0;
    String? problem;
    for (final f in picked.files) {
      final path = f.path;
      if (path == null) continue;
      try {
        await _box.add(path, f.name);
        added++;
      } on BoxTooLarge {
        problem = '«${f.name}» больше ${formatBytes(kBoxMaxFileBytes)} — '
            'в сейф не влезет';
      } catch (_) {
        problem = 'Не получилось положить «${f.name}»';
      }
    }
    // file_picker keeps plain copies in the cache: remove them now.
    await FilePicker.platform.clearTemporaryFiles();
    if (!mounted) return;
    MsToast.show(
        context,
        problem ??
            'В сейфе: ${ruPlural(added, 'файл', 'файла', 'файлов')} — $added. '
                'Оригинал остался на телефоне, удали его, если нужно.');
  }

  Future<void> _open(BoxEntry e) async {
    try {
      if (e.isImage) {
        final bytes = await _box.readBytes(e.id);
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => _ImageView(name: e.name, bytes: bytes)));
        return;
      }
      final file = await _box.exportTemp(e.id);
      final r = await OpenFilex.open(file.path);
      if (r.type != ResultType.done && mounted) {
        MsToast.show(context, 'Нечем открыть такой файл на этом телефоне');
      }
    } on BoxCorrupt {
      if (mounted) MsToast.show(context, 'Файл повреждён — открыть не выйдет');
    } catch (_) {
      if (mounted) MsToast.show(context, 'Не получилось открыть «${e.name}»');
    }
  }

  Future<void> _menu(BoxEntry e) => showMsSheet<void>(
        context,
        title: e.name,
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MsSpace.space2,
          children: [
            MsButton(
              label: 'Открыть',
              variant: MsButtonVariant.secondary,
              expand: true,
              onPressed: () {
                Navigator.of(sheet).pop();
                _open(e);
              },
            ),
            MsButton(
              label: 'Удалить из сейфа',
              variant: MsButtonVariant.danger,
              expand: true,
              onPressed: () async {
                Navigator.of(sheet).pop();
                await _box.remove(e.id);
                if (mounted) MsToast.show(context, 'Удалено из сейфа');
              },
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final box = ref.watch(privateBoxProvider);
    final now = (widget.clock ?? DateTime.now)();
    if (box.state != BoxState.unlocked) {
      // Locked behind our back (app hidden, app lock): leave.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.canPop()) context.pop();
      });
      return Scaffold(backgroundColor: ms.ground);
    }
    final entries = box.entries;
    return Scaffold(
      backgroundColor: ms.ground,
      body: Stack(children: [
        MsScreen(children: [
          Row(children: [
            MsIconButton(
                icon: Symbols.arrow_back_rounded,
                label: 'Назад',
                onPressed: _close),
            const SizedBox(width: MsSpace.space3),
            Expanded(
              child: MsScreenHeader(
                eyebrow: 'только для тебя',
                title: 'Личный сейф',
                actions: [
                  MsIconButton(
                      icon: Symbols.lock_rounded,
                      label: 'Закрыть сейф',
                      onPressed: _close),
                ],
              ),
            ),
          ]),
          const SizedBox(height: MsSpace.space4),
          if (entries.isEmpty)
            MsCard(
              child: Text('Пусто. Положи сюда то, что только твоё.',
                  style: MsText.bodySm.copyWith(color: ms.inkMuted)),
            )
          else
            for (final e in entries) ...[
              MsRowCard(
                onTap: () => _open(e),
                children: [
                  FileThumb.kind(label: e.kindLabel, image: e.isImage),
                  const SizedBox(width: MsSpace.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MsTextX.rowTitle.copyWith(color: ms.ink)),
                        const SizedBox(height: MsSize.rowMetaGap),
                        MsMeta(
                            '${formatBytes(e.size)} · ${formatWhen(DateTime.fromMillisecondsSinceEpoch(e.addedAt), now)}'),
                      ],
                    ),
                  ),
                  MsIconButton(
                      icon: Symbols.more_vert_rounded,
                      label: 'Действия с файлом',
                      onPressed: () => _menu(e)),
                ],
              ),
              const SizedBox(height: MsSpace.space2),
            ],
          const SizedBox(height: MsSize.buttonH + MsSize.fabBottom * 2),
        ]),
        Positioned(
          right: MsSpace.space4,
          bottom: MsSize.fabBottom + MediaQuery.paddingOf(context).bottom,
          child: MsButton(
            label: box.busy ? 'Шифрую…' : 'Добавить файл',
            icon: Symbols.add_rounded,
            pill: true,
            onPressed: box.busy ? null : _add,
          ),
        ),
      ]),
    );
  }
}

/// A photo from the safe, decrypted into memory only.
class _ImageView extends StatelessWidget {
  const _ImageView({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return Scaffold(
      backgroundColor: ms.ground,
      appBar: AppBar(
        backgroundColor: ms.ground,
        foregroundColor: ms.ink,
        title: Text(name, style: MsTextX.rowTitle.copyWith(color: ms.ink)),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.memory(
            bytes,
            errorBuilder: (_, __, ___) => Text(
                'Этот снимок телефон не показывает. Открой его через «⋮».',
                textAlign: TextAlign.center,
                style: MsText.bodySm.copyWith(color: ms.inkMuted)),
          ),
        ),
      ),
    );
  }
}
```

Check while implementing: `MsRowCard`'s parameters (`children`, `onTap`) and `MsCard`'s `child` match `lib/design_system/widgets/ms_row_card.dart` / `ms_card.dart`. Note `_ImageView` copy contains «⋮», which is a text glyph, not an emoji; if the reviewer objects, use «через меню файла».

- [ ] **Step 5: Add the route in `ms_router.dart`**

Import `../features/files/safe_screen.dart` and add next to `/card/:id`, outside the shell:

```dart
        // The private box: full screen over the tab bar; leaving it locks.
        GoRoute(
          path: '/safe',
          builder: (_, __) => const SafeScreen(),
        ),
```

- [ ] **Step 6: Run and confirm everything passes**

Run: `cd ms_app && flutter test test/features/safe_test.dart` → pass.
Run: `cd ms_app && flutter analyze` → no issues.
Run: `cd ms_app && flutter test --concurrency=1` → all pass (the accessibility sweep in `test/a11y_test.dart` must still pass; `/safe` is not part of it).

- [ ] **Step 7: Commit**

```bash
git add ms_app/lib/features/files ms_app/lib/shell/ms_router.dart ms_app/test/features/safe_test.dart
git commit -m "app: safe screen — list, add, open, delete; locks when you leave"
```

---

### Task 5: Concerns, full check, pull request

**Files:**
- Modify: `docs/CONCERNS.md`

- [ ] **Step 1: Append to `docs/CONCERNS.md`**

```markdown
### 20. The private box lives on one phone only
- **What:** «Личный сейф» is not synced, not on Yandex.Disk and not in the recovery sheet; by design its password is not derived from the family secret (PLAN.md §2 п.5). A lost phone or a forgotten password loses the files. The create sheet says so.
- **Suggest:** an optional encrypted export to the Disk later, still behind the box password.

### 21. Opening a document briefly makes a plain copy
- **What:** PDFs and other non-images open in another app, which needs a readable file. МС writes it to its cache and deletes it when you come back to the app, when the safe locks, and on the next start. Photos open inside МС from memory only.
- **Also:** `file_picker` copies picked files to the cache; МС clears that right after encrypting. The original stays where it was — the toast says so.

### 22. Pure-Dart crypto speed
- **What:** files are encrypted in pure Dart in a background isolate. Fine for documents and photos; a 200 MB cap keeps it bearable. `cryptography_flutter` would make it native-fast if needed.
```

- [ ] **Step 2: Full verification**

Run, one at a time:

```bash
cd core && dart analyze && dart test --concurrency=1
cd ms_app && flutter analyze && flutter test --concurrency=1
```

Expected: no errors or warnings; all tests pass. Report the counts.

- [ ] **Step 3: Commit, push, open the pull request**

```bash
git add docs/CONCERNS.md
git commit -m "docs: concerns for the private box"
git push -u fork feature/7-private-box
gh pr create --repo Skaslik/Skaslik --base main --head r3bb1t:feature/7-private-box --title "Private box: «Личный сейф» with its own password"
```

PR body: what it does, the five decisions above, the device checklist below, ending with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

- [ ] **Step 4: Device checklist for the user (put in the PR and the final message)**

1. Files → «Личный сейф» → set a password twice → the safe opens.
2. «Добавить файл» → pick a photo and a PDF → both listed with size and «только что».
3. Tap the photo → it shows inside МС. Tap the PDF → it opens in the phone's viewer; come back → the safe asks for the password again.
4. Lock the phone or switch apps while the safe is open → back in МС the safe is closed.
5. Wrong password → «Не тот пароль». «Забыл пароль» → delete → the sheet offers a new safe.
6. On the partner's phone, Files shows the «Личный сейф» row but nothing of yours.
```

---

## Self-review notes

- **Spec coverage:** separate password not from S (Task 1 keyring), Argon2id (Task 1), zero access without P_box incl. forensic (Task 2 test), «внутри только шифртекст» (Task 1 index + stream), previews only after unlock (Task 4 in-memory image view), biometric gate on entering (PLAN §5.9) — replaced by the password every time (decision 3), partner can't see names (local only + sealed index), sheet copy from the prototype (Task 3).
- **Placeholder scan:** none; package API lines in Task 3 Step 1 name exact symbols to verify.
- **Type consistency:** `tryUnlock` (not `unlock`) on `BoxKeyring`; `PrivateBox.unlock` returns `bool`; `exportTemp` returns `File`; `BoxEntry.addedAt` is ms; `FileThumb.kind(label:, image:)` used in Task 4.
- **Review Focus:** each line has a named test or step.
