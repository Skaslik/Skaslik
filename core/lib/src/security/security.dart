/// Безопасность «из коробки»: fake mode, двухфакторное удаление, аудит.
library;

/// Fake mode: заглушка «калькулятор» с decoy-паролем.
///
/// Триггер: тройное нажатие на монограмму. При вводе decoy-пароля открывается
/// фиктивный интерфейс (калькулятор), в котором нет ничего реального.
/// Настоящий интерфейс — только биометрией/настоящим паролем.
class FakeMode {
  final String _decoyPassword;
  FakeMode(this._decoyPassword);

  bool tryUnlock(String entered) => _timingSafe(_decoyPassword, entered);

  /// Сравнение с защитой от timing-атак.
  static bool _timingSafe(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// Двухфакторное удаление: согласие обоих (подпись-фраза) или аварийный код.
class TwoFactorErase {
  final String _phraseA;
  final String _phraseB;
  final String _emergencyCode;

  TwoFactorErase({
    required String phraseA,
    required String phraseB,
    required String emergencyCode,
  })  : _phraseA = phraseA,
        _phraseB = phraseB,
        _emergencyCode = emergencyCode;

  /// Подтверждение обоими (каждый вводит свою фразу).
  bool confirmBoth(String enteredA, String enteredB) =>
      _timingSafe(_phraseA, enteredA) && _timingSafe(_phraseB, enteredB);

  /// Аварийный код (жжёт мосты).
  bool confirmEmergency(String code) => _timingSafe(_emergencyCode, code);

  static bool _timingSafe(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// Запись аудита (append-only, шифруется при хранении).
class AuditEntry {
  final int at;
  final String deviceId;
  final String action;
  final String? detail;
  const AuditEntry({
    required this.at,
    required this.deviceId,
    required this.action,
    this.detail,
  });

  Map<String, String> toFields() => {
        'at': '$at',
        'by': deviceId,
        'action': action,
        if (detail != null) 'detail': detail!,
      };

  static AuditEntry? fromFields(String id, Map<String, String> f) {
    final at = int.tryParse(f['at'] ?? '');
    if (at == null) return null;
    return AuditEntry(
      at: at,
      deviceId: f['by'] ?? '',
      action: f['action'] ?? '',
      detail: f['detail'],
    );
  }
}

class AuditLog {
  final _entries = <AuditEntry>[];
  List<AuditEntry> get all => List.unmodifiable(_entries);

  void add(AuditEntry e) => _entries.add(e);

  void pair(String deviceId) => add(AuditEntry(
      at: DateTime.now().millisecondsSinceEpoch, deviceId: deviceId, action: 'pair'));

  void dissociate(String deviceId) => add(AuditEntry(
      at: DateTime.now().millisecondsSinceEpoch,
      deviceId: deviceId,
      action: 'dissociate'));

  void restore(String deviceId) => add(AuditEntry(
      at: DateTime.now().millisecondsSinceEpoch, deviceId: deviceId, action: 'restore'));

  void erase(String deviceId) => add(AuditEntry(
      at: DateTime.now().millisecondsSinceEpoch, deviceId: deviceId, action: 'erase'));
}
