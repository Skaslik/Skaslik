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

    test('the plain size can be told from the header and the length',
        () async {
      for (final size in [0, 1, 15, 16, 17, 32, 53, 1000]) {
        final sealed = await seal(List.filled(size, 1), key, 'f1');
        expect(boxPlainSize(sealed.sublist(0, 8), sealed.length), size,
            reason: '$size');
      }
      expect(boxPlainSize(utf8.encode('не сейф!'), 100), isNull);
      expect(boxPlainSize(const [0x4D], 100), isNull);
    });

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
      // 32 bytes at chunk 16: two sealed chunks of 16 + 40 bytes; the
      // second is marked last. Dropping it leaves a file that looks whole.
      final sealed = await seal(List.filled(32, 5), key, 'f1');
      expect(sealed.length, 8 + 2 * 56);
      await expectCorrupt(
          open(sealed.sublist(0, sealed.length - 56), key, 'f1'));
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

    test('a file cut in the middle of a chunk is detected', () async {
      final sealed = await seal(List.generate(40, (i) => i), key, 'f1');
      for (final cut in [9, 30, 8 + 56 + 3, sealed.length - 1]) {
        await expectCorrupt(open(sealed.sublist(0, cut), key, 'f1'));
      }
    });

    test('bytes appended after the last chunk are detected', () async {
      final sealed = await seal(List.generate(40, (i) => i), key, 'f1');
      for (final extra in [1, 40, 56, 200]) {
        await expectCorrupt(
            open([...sealed, ...List.filled(extra, 7)], key, 'f1'));
      }
    });

    test('no header, or a cut header, is detected', () async {
      await expectCorrupt(open(const [], key, 'f1'));
      await expectCorrupt(open(const [0x4D, 0x53], key, 'f1'));
      await expectCorrupt(
          open(utf8.encode('просто текст, не сейф'), key, 'f1'));
    });
  });

  group('index and entries', () {
    test('names of any kind survive; the sealed index hides them', () async {
      final entries = [
        const BoxEntry(
            id: 'a', name: 'Паспорт/скан 1.pdf', size: 10, addedAt: 1),
        const BoxEntry(id: 'b', name: 'фото 🐕.jpg', size: 0, addedAt: 2),
        const BoxEntry(id: 'c', name: 'фото 🐕.jpg', size: 3, addedAt: 3),
      ];
      final sealed = await sealBoxIndex(key, entries);
      expect(
          latin1.decode(sealed, allowInvalid: true), isNot(contains('pdf')));
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
