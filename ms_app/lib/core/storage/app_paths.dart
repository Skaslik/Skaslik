import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Единая точка выбора каталога данных приложения.
///
/// На Android/iOS — `getApplicationDocumentsDirectory()` (app-scoped,
/// гарантированно доступен). На desktop/в тестах — fallback на `Directory.current`.
///
/// Инициализируется один раз в `main()` до создания любого [MsStore].
class AppPaths {
  AppPaths._();

  static String? _dir;

  /// Каталог, в котором доменные сторы кладут свои JSON-файлы.
  static String? get dataDir => _dir;

  /// Инициализировать каталог. Идиомпотентно.
  static Future<void> init() async {
    if (_dir != null) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _dir = appDir.path;
    } catch (e) {
      // Desktop / тест / среда без platform channel.
      debugPrint('AppPaths: fallback to cwd ($e)');
      _dir = Directory.current.path;
    }
  }

  /// Принудительно задать каталог (для тестов).
  static void overrideForTest(String dir) => _dir = dir;

  /// Сбросить (для тестов).
  static void reset() => _dir = null;
}
