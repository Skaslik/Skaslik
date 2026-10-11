/// «Личный сейф»: files only this person can open, only on this phone.
///
/// Not synced and not in the recovery sheet (PLAN.md §2 п.5: P_box is not
/// derived from S). Forgetting the password loses the files; the UI says so.
///
/// Concurrency rules:
/// - every change to the list (create, unlock, add, remove) runs through one
///   queue, so two writes of the sealed index never overlap;
/// - each lock starts a new session; work that finishes in an old session is
///   dropped (and the file it wrote deleted) instead of touching the safe;
/// - each operation works on its own copy of the key, so zeroing the key on
///   lock can never seal anything with zeros.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ms_core/ms_core.dart' hide Clip;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../storage/app_paths.dart';
import 'box_io.dart';

/// `loading` until [PrivateBox.init] has looked at the disk.
enum BoxState { loading, absent, locked, unlocked }

/// Per file. The crypto is pure Dart; bigger files would take minutes.
const int kBoxMaxFileBytes = 200 * 1024 * 1024;

class BoxTooLarge implements Exception {
  const BoxTooLarge(this.bytes);
  final int bytes;
}

typedef BoxRunner = Future<R> Function<R>(FutureOr<R> Function() task);

/// A name every file system and viewer accepts for a plain copy: forbidden
/// characters become «_», never empty, «.» or «..», at most 255 UTF-8 bytes
/// with the extension kept.
String plainCopyName(String name) {
  const fallback = 'файл';
  final n = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
  if (n.isEmpty || RegExp(r'^\.+$').hasMatch(n)) return fallback;
  final dot = n.lastIndexOf('.');
  var ext = dot >= 0 ? n.substring(dot) : '';
  if (ext.length < 2 || utf8.encode(ext).length > 32) ext = '';
  var base = ext.isEmpty ? n : n.substring(0, dot);
  if (RegExp(r'^[\s.]*$').hasMatch(base)) base = fallback;
  final budget = 255 - utf8.encode(ext).length;
  final out = StringBuffer();
  var used = 0;
  for (final r in base.runes) {
    final ch = String.fromCharCode(r);
    final len = utf8.encode(ch).length;
    if (used + len > budget) break;
    out.write(ch);
    used += len;
  }
  return '$out$ext';
}

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

  BoxState _state = BoxState.loading;
  Uint8List? _key;

  /// Files being encrypted right now: not orphans, even if unlisted.
  final Set<String> _writing = {};
  List<BoxEntry> _entries = const [];
  int _busy = 0;
  int _away = 0;
  bool _hidden = false;
  bool _disposed = false;

  /// Bumped on every lock and unlock: work from an older session is stale.
  int _session = 0;

  BoxState get state => _state;
  bool get busy => _busy > 0;

  /// Newest first. Empty unless unlocked.
  List<BoxEntry> get entries => _state != BoxState.unlocked
      ? const []
      : ([..._entries]..sort((a, b) => b.addedAt.compareTo(a.addedAt)));

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

  /// Reads the state from disk, drops half-written files and old plain
  /// copies (ours and file_picker's).
  /// Runs first in the queue, so nothing (a create, above all) can act on
  /// the safe before its real state is known.
  Future<void> init() => _serial(() async {
        _state = await _keyring.exists() ? BoxState.locked : BoxState.absent;
        if (!_disposed) notifyListeners();
        final indexPart = File('${_index.path}.part');
        if (await indexPart.exists()) await indexPart.delete();
        if (await _files.exists()) {
          await for (final f in _files.list()) {
            if (f.path.endsWith('.part')) await f.delete();
          }
        }
        await wipeTemp();
      });

  Future<void> create(String password) async {
    if (password.length < kBoxMinPassword) {
      throw ArgumentError('пароль короче $kBoxMinPassword символов');
    }
    await _serial(() => _busyWhile(() async {
          if (_state != BoxState.absent) throw StateError('сейф уже есть');
          final made = await _run(_createTask(password, kdf));
          await _files.create(recursive: true);
          // Index first: a crash before the keyring leaves «no safe».
          await _writeIndex(made.key, const []);
          await _keyring.writeAsString(made.keyring.toJson(), flush: true);
          _state = BoxState.locked;
          _open(made.key, const []);
        }));
  }

  /// False when the password is wrong. Throws [BoxCorrupt] when the safe's
  /// key or list is damaged.
  Future<bool> unlock(String password) => _serial(() async {
        if (_state == BoxState.unlocked) return true;
        if (_state == BoxState.absent) return false;
        final keyring = BoxKeyring.fromJson(await _keyring.readAsString());
        return _busyWhile(() async {
          final key = await _run(_unlockTask(keyring, password));
          if (key == null) return false;
          final listed = await _readIndex(key);
          // A crash can leave the list and the files out of step either way.
          final present = [
            for (final e in listed)
              if (await File(_path(e.id)).exists()) e,
          ];
          final all = await _withOrphans(present);
          if (present.length != listed.length || all.length != present.length) {
            await _writeIndex(key, all);
          }
          _open(key, all);
          return true;
        });
      });

  /// A crash between writing a file and updating the list leaves a file
  /// nobody knows about. Nothing gets lost: it comes back as «Без имени».
  Future<List<BoxEntry>> _withOrphans(List<BoxEntry> listed) async {
    if (!await _files.exists()) return listed;
    final known = {for (final e in listed) e.id};
    final out = [...listed];
    await for (final f in _files.list()) {
      if (f is! File || p.extension(f.path) != '.bin') continue;
      final id = p.basenameWithoutExtension(f.path);
      if (known.contains(id) || _writing.contains(id)) continue;
      final raf = await f.open();
      final head = await raf.read(8);
      await raf.close();
      final size = boxPlainSize(head, await f.length());
      if (size == null) continue; // not a box file: leave it alone
      out.add(BoxEntry(
          id: id,
          name: 'Без имени',
          size: size,
          addedAt: (await f.lastModified()).millisecondsSinceEpoch));
    }
    return out;
  }

  /// Starts a session with [key] — unless the app went to the background
  /// meanwhile (Argon2id takes seconds): then the key is dropped at once.
  void _open(Uint8List key, List<BoxEntry> entries) {
    _session++;
    if (_disposed || (_hidden && _away == 0)) {
      key.fillRange(0, key.length, 0);
      return;
    }
    _key = key;
    _entries = entries;
    _state = BoxState.unlocked;
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
    _session++;
  }

  /// A deferred lock (a screen closing) may arrive after this; it's ignored.
  @override
  void dispose() {
    if (_state == BoxState.unlocked) _forgetKey();
    _disposed = true;
    super.dispose();
  }

  void onAppHidden() {
    _hidden = true;
    if (_away > 0) return;
    lock(wipe: false);
  }

  void onAppResumed() {
    _hidden = false;
    if (_state != BoxState.unlocked) _wipeLater();
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

  /// Encrypting runs outside the queue: a lock (and the next unlock) never
  /// waits for a big file. Only the list update is queued.
  Future<BoxEntry> add(String sourcePath, String name) {
    final session = _session;
    final key = _keyCopy();
    return _busyWhile(() async {
      final id = newBoxId();
      _writing.add(id);
      try {
        final size = await File(sourcePath).length();
        if (size > kBoxMaxFileBytes) throw BoxTooLarge(size);
        try {
          final written =
              await _run(_encryptTask(sourcePath, _path(id), key, id));
          return await _serial(() async {
            _check(session);
            final entry = BoxEntry(
                id: id,
                name: name,
                size: written,
                addedAt: _clock().millisecondsSinceEpoch);
            final next = [..._entries, entry];
            await _writeIndex(key, next);
            if (session == _session) _entries = next;
            return entry;
          });
        } catch (e, st) {
          final f = File(_path(id));
          if (await f.exists()) await f.delete();
          _rethrowAs(session, e, st);
        }
      } finally {
        _writing.remove(id);
        key.fillRange(0, key.length, 0);
      }
    });
  }

  /// After a lock, whatever broke an in-flight operation (its temp folder
  /// wiped under it, say) is just «сейф закрыт».
  Never _rethrowAs(int session, Object e, StackTrace st) {
    if (_disposed || session != _session) throw StateError('сейф закрыт');
    Error.throwWithStackTrace(e, st);
  }

  /// Queued with the list changes, so a remove never deletes a file that is
  /// being read.
  Future<Uint8List> readBytes(String id) {
    final session = _session;
    final key = _keyCopy();
    return _serial(() async {
      try {
        _check(session);
        final Uint8List bytes;
        try {
          bytes =
              await _busyWhile(() => _run(_bytesTask(_path(id), key, id)));
        } catch (e, st) {
          _rethrowAs(session, e, st);
        }
        _check(session);
        return bytes;
      } finally {
        key.fillRange(0, key.length, 0);
      }
    });
  }

  /// A plain copy for another app, under the file's own name. Queued like
  /// [readBytes].
  Future<File> exportTemp(String id) {
    final session = _session;
    final key = _keyCopy();
    return _serial(() => _exportTemp(id, session, key));
  }

  Future<File> _exportTemp(String id, int session, Uint8List key) async {
    try {
      _check(session);
      final entry = _entries.firstWhere((e) => e.id == id);
      final tmp = await _tempDir();
      final sub = Directory(p.join(tmp.path, 'ms_box', newBoxId()));
      await sub.create(recursive: true);
      final dst = p.join(sub.path, plainCopyName(entry.name));
      try {
        await _busyWhile(() => _run(_decryptTask(_path(id), dst, key, id)));
        _check(session);
      } catch (e, st) {
        try {
          await sub.delete(recursive: true);
        } on FileSystemException {
          // Already wiped by the lock.
        }
        _rethrowAs(session, e, st);
      }
      return File(dst);
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  Future<void> remove(String id) {
    final session = _session;
    final key = _keyCopy();
    return _serial(() => _busyWhile(() async {
          try {
            _check(session);
            // The data first: a crash in between leaves a listed entry
            // without a file (dropped on unlock), never a deleted file that
            // comes back as «Без имени».
            final f = File(_path(id));
            if (await f.exists()) await f.delete();
            final next = _entries.where((e) => e.id != id).toList();
            await _writeIndex(key, next);
            if (session == _session) _entries = next;
          } finally {
            key.fillRange(0, key.length, 0);
          }
        }));
  }

  /// «Забыл пароль»: the files can't be opened anyway; remove them.
  Future<void> destroy() => _serial(() async {
        lock();
        if (await dir.exists()) await dir.delete(recursive: true);
        await wipeTemp();
        _state = BoxState.absent;
        if (!_disposed) notifyListeners();
      });

  /// Deletes every plain copy: ours for other apps, and file_picker's
  /// (only the safe uses file_picker). Wipes run one at a time: two
  /// recursive deletes of one folder at once fail on Windows.
  Future<void> wipeTemp() => _wipes.run(_wipeNow);

  final _Chain _wipes = _Chain();

  Future<void> _wipeNow() async {
    final tmp = (await _tempDir()).path;
    for (final name in const ['ms_box', 'file_picker']) {
      try {
        await Directory(p.join(tmp, name)).delete(recursive: true);
      } on PathNotFoundException {
        // Nothing to wipe.
      }
    }
  }

  /// A failed wipe (a viewer still holds the file) is retried on the next
  /// resume, lock or start.
  void _wipeLater() => unawaited(wipeTemp().catchError((Object _) {}));

  /// The caller's own copy of the key; it zeroes it when done.
  Uint8List _keyCopy() {
    final k = _key;
    if (_state != BoxState.unlocked || k == null) {
      throw StateError('сейф закрыт');
    }
    return Uint8List.fromList(k);
  }

  void _check(int session) {
    if (_disposed || session != _session || _state != BoxState.unlocked) {
      throw StateError('сейф закрыт');
    }
  }

  final _Chain _ops = _Chain();

  Future<T> _serial<T>(Future<T> Function() f) => _ops.run(f);

  Future<T> _busyWhile<T>(Future<T> Function() f) async {
    _busy++;
    if (!_disposed) notifyListeners();
    try {
      return await f();
    } finally {
      _busy--;
      if (!_disposed) notifyListeners();
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

/// Runs tasks one after another; a failed task doesn't stop the next one,
/// and its error still reaches its own caller.
class _Chain {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() f) {
    final run = _tail.then((_) => f());
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }
}

final privateBoxProvider = ChangeNotifierProvider<PrivateBox>((ref) {
  final box = PrivateBox(
    dir: Directory(p.join(AppPaths.dataDir ?? Directory.current.path, 'box')),
    tempDir: getTemporaryDirectory,
  );
  unawaited(box.init().catchError((Object _) {}));
  return box;
});
