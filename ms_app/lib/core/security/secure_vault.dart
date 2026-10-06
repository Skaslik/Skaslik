import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ключевое хранилище «МС»: секреты, которые не покидают устройство.
///
/// Обёртка над [FlutterSecureStorage] (Android Keystore / iOS Keychain).
/// В тестах/desktop, где platform-channel недоступен, прозрачный fallback на
/// in-memory map — чтобы UI-логика оставалась проверяемой.
class SecureVault {
  SecureVault._();

  static final FlutterSecureStorage _native = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
  );
  static final Map<String, String> _mem = {};
  static bool? _nativeOk;

  static Future<String?> read(String key) async {
    if (_nativeOk != false) {
      try {
        return await _native.read(key: key);
      } catch (_) {
        _nativeOk = false;
      }
    }
    return _mem[key];
  }

  static Future<void> write(String key, String value) async {
    if (_nativeOk != false) {
      try {
        await _native.write(key: key, value: value);
        return;
      } catch (_) {
        _nativeOk = false;
      }
    }
    _mem[key] = value;
  }

  static Future<bool> contains(String key) async {
    if (_nativeOk != false) {
      try {
        return await _native.containsKey(key: key);
      } catch (_) {
        _nativeOk = false;
      }
    }
    return _mem.containsKey(key);
  }

  static Future<void> delete(String key) async {
    if (_nativeOk != false) {
      try {
        await _native.delete(key: key);
      } catch (_) {
        _nativeOk = false;
      }
    }
    _mem.remove(key);
  }

  static Future<void> deleteAll() async {
    for (final k in _mem.keys.toList()) {
      await delete(k);
    }
  }

  /// Тест-сброс: очистить in-memory и сбросить флаг plugin.
  static void resetForTest() {
    _nativeOk = null;
    _mem.clear();
  }
}
