/// Контроллер блокировки приложения: биометрия/PIN + fake mode.
///
/// Биометрия — через `local_auth`. Настоящий PIN — 4–6 цифр, хранится как
/// Argon2id-хеш в secure storage; биометрия разблокирует без ввода. Fake mode
/// — тройное нажатие на монограмму открывает фейковый калькулятор (никаких
/// реальных данных). Настоящий доступ — только после биометрии/PIN.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ms_core/ms_core.dart';

import '../security/secure_vault.dart';

/// Decision #12 default: three taps on the framed monogram in the room
/// within this window switch to fake mode.
const Duration kFakeModeTapWindow = Duration(milliseconds: 800);

class AppLock extends ChangeNotifier {
  final LocalAuthentication _auth;
  final FakeMode _fake;
  bool _unlocked = false;
  bool _inFake = false;
  int _monogramTaps = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  AppLock({LocalAuthentication? auth, FakeMode? fake})
      : _auth = auth ?? LocalAuthentication(),
        _fake = fake ?? FakeMode('0000');

  bool get unlocked => _unlocked;
  bool get inFake => _inFake;

  /// Биометрия/PIN доступна на устройстве?
  Future<bool> canUnlock() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Попробовать разблокировать биометрией. Возвращает успех.
  Future<bool> tryUnlock({String reason = 'Открыть «МС»'}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (ok) {
        _unlocked = true;
        notifyListeners();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  static const _pinSalt = 'ms/applock/pin-salt';
  static const _pinHash = 'ms/applock/pin-hash';
  bool _pinSet = false;

  bool get pinSet => _pinSet;

  /// Загрузить флаг «PIN задан».
  Future<void> loadPin() async {
    final h = await SecureVault.read(_pinHash);
    _pinSet = h != null && h.isNotEmpty;
    notifyListeners();
  }

  /// Задать PIN (4–6 цифр). Хранится Argon2id-хеш + соль.
  Future<void> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 6) {
      throw ArgumentError('PIN: 4–6 цифр');
    }
    const salt = _pinSalt;
    final hash = await argon2id32(pin, salt);
    await SecureVault.write(_pinHash, bytesToHex(hash));
    _pinSet = true;
    notifyListeners();
  }

  /// Проверить PIN. Возвращает успех; при успехе — разблокировка.
  Future<bool> verifyPin(String pin) async {
    final h = await SecureVault.read(_pinHash);
    if (h == null || h.isEmpty) return false;
    const salt = _pinSalt;
    final expect = hexToBytes(h);
    final actual = await argon2id32(pin, salt);
    if (!_timingSafe(expect, actual)) return false;
    _unlocked = true;
    notifyListeners();
    return true;
  }

  /// Разблокировка без PIN (например, после biometrics или в тестах).
  void unlockManually() {
    _unlocked = true;
    notifyListeners();
  }

  static bool _timingSafe(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a[i] ^ b[i];
    }
    return r == 0;
  }

  void lock() {
    _unlocked = false;
    notifyListeners();
  }

  /// Тройное нажатие на монограмму → fake mode.
  void onMonogramTap() {
    final now = DateTime.now();
    if (now.difference(_lastTap) > kFakeModeTapWindow) {
      _monogramTaps = 0;
    }
    _monogramTaps += 1;
    _lastTap = now;
    if (_monogramTaps >= 3) {
      _monogramTaps = 0;
      _inFake = true;
      notifyListeners();
    }
  }

  /// Закрыть fake mode.
  void exitFake() {
    _inFake = false;
    notifyListeners();
  }

  bool tryFakePassword(String entered) => _fake.tryUnlock(entered);
}

/// Глобальный контроллер (доступен из любого виджета без провайдеров).
final AppLock appLock = AppLock();
