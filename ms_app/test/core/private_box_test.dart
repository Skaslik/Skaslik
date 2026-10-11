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
    final e =
        await box.add(source('x.pdf', [9, 9]).path, 'Договор/аренда 🐕.pdf');
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

  test(
      'hiding the app locks it; the copy for another app survives until back',
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

  test('disposed: the key is dropped and later calls are harmless', () async {
    await box.create('секрет12');
    box.dispose();
    expect(box.state, BoxState.locked);
    box.lock(); // e.g. a screen's deferred lock arriving late
    box.onAppHidden();
    expect(() => box.readBytes('x'), throwsStateError);
    box = make(); // tearDown-safe
  });

  test('locked: reading or adding is refused', () async {
    await box.create('секрет12');
    box.lock();
    expect(() => box.readBytes('x'), throwsStateError);
    expect(() => box.add('x', 'x'), throwsStateError);
  });
}
