/// «Личный сейф»: files only this person can open, only on this phone.
///
/// Not synced and not in the recovery sheet (PLAN.md §2 п.5: P_box is not
/// derived from S). Forgetting the password loses the files; the UI says so.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

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
    if (_disposed || _state != BoxState.unlocked) return;
    _forgetKey();
    if (wipe) _wipeLater();
    notifyListeners();
  }

  void _forgetKey() {
    final k = _key;
    if (k != null) k.fillRange(0, k.length, 0);
    _key = null;
    _entries = const [];
    _state = BoxState.locked;
  }

  bool _disposed = false;

  /// A deferred lock (a screen closing) may arrive after this; it's ignored.
  @override
  void dispose() {
    if (_state == BoxState.unlocked) _forgetKey();
    _disposed = true;
    super.dispose();
  }

  void onAppHidden() {
    if (_away > 0) return;
    lock(wipe: false);
  }

  void onAppResumed() {
    if (_state != BoxState.unlocked) _wipeLater();
  }

  /// A failed wipe (a viewer still holds the file) is retried on the next
  /// resume, lock or start.
  void _wipeLater() => unawaited(wipeTemp().catchError((Object _) {}));

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

  /// Deletes every plain copy made for other apps. Wipes run one at a time:
  /// two recursive deletes of one folder at once fail on Windows.
  Future<void> wipeTemp() {
    final next = _wiping.then((_) => _wipeNow(), onError: (_) => _wipeNow());
    _wiping = next;
    return next;
  }

  Future<void> _wiping = Future<void>.value();

  Future<void> _wipeNow() async {
    final d = Directory(p.join((await _tempDir()).path, 'ms_box'));
    try {
      await d.delete(recursive: true);
    } on PathNotFoundException {
      // Nothing to wipe.
    }
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
    dir: Directory(p.join(AppPaths.dataDir ?? Directory.current.path, 'box')),
    tempDir: getTemporaryDirectory,
  );
  unawaited(box.init());
  return box;
});
