/// Минимальное файловое хранилище (local-first).
///
/// Каталог — [AppPaths.dataDir] (app-scoped, path_provider); при отсутствии
/// (тесты/desktop) — [dataDir] или [Directory.current].
library;

import 'dart:io';

import 'app_paths.dart';

class LocalFile {
  final File _file;

  LocalFile(this._file);

  factory LocalFile.forDomain(Object domain, {String? dataDir}) {
    final dir = dataDir ?? AppPaths.dataDir ?? Directory.current.path;
    final dirObj = Directory('$dir/data');
    if (!dirObj.existsSync()) dirObj.createSync(recursive: true);
    return LocalFile(File('${dirObj.path}/$domain.json'));
  }

  String? read() => _file.existsSync() ? _file.readAsStringSync() : null;
  void write(String data) {
    if (!_file.existsSync()) _file.createSync(recursive: true);
    _file.writeAsStringSync(data);
  }

  void clear() {
    if (_file.existsSync()) _file.deleteSync();
  }

  void close() {
    // No-op (file-based).
  }
}
