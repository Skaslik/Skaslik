import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ms_core/ms_core.dart';

import '../security/secure_vault.dart';

/// Семейный контроллер: идентичность пары + секреты (S, seed, pairing-ключ).
///
/// Zero-knowledge: S (4 слова) и seed-фраза (12 слов) + pairing-ключ
/// хранятся только в secure storage устройства. На L3 (Я.Диск) поедет только
/// шифртекст, выводимый из этих секретов.
///
/// Одноустройственное создание семьи (S1): устройство генерирует S, seed,
/// pairing-ключ и сохраняет всё локально. Подключение второго устройства
/// (join по QR/S) — отдельный поток.
class Family extends ChangeNotifier {
  Family._();

  static const _kName = 'ms/family/name';
  static const _kColor = 'ms/family/color';
  static const _kS = 'ms/family/s';
  static const _kPairing = 'ms/family/pairing';
  static const _kSeed = 'ms/family/seed';
  static const _kPeerPub = 'ms/family/peerPub';

  String? _name;
  Color? _color;
  List<String>? _s;
  List<String>? _seed;
  DevicePairing? _pairing;
  String? _peerPubB64;
  bool _loaded = false;

  bool get isSet => _name != null && _pairing != null;
  bool get loaded => _loaded;
  String? get name => _name;
  Color? get color => _color;
  List<String>? get s => _s;
  List<String>? get seed => _seed;
  DevicePairing? get pairing => _pairing;

  /// Б64 публичного pairing-ключа (для передачи партнёру при join).
  String? get pubKeyB64 => _pairing == null
      ? null
      : base64Encode(_pairing!.pub.bytes);

  /// Б64 публичного ключа партнёра (присоединившегося/создателя).
  String? get peerPubB64 => _peerPubB64;

  /// Сырые 32 байта публичного ключа партнёра (для pairing-derivation).
  List<int>? get peerPubBytes => _peerPubB64 == null
      ? null
      : base64Decode(_peerPubB64!);

  /// Детерминированный id этого устройства для CRDT (LWW-версии).
  ///
  /// Основан на собственном публичном pairing-ключе: один ключ → один id.
  String? get deviceId => _pairing == null
      ? null
      : deviceIdForPub(_pairing!.pub.bytes);

  /// Корневой master-ключ семьи (derivation из pairing + S).
  ///
  /// Требует, чтобы пара была завершена (есть [pairing], [peerPubBytes] и S).
  Future<Uint8List?> master() async {
    if (_pairing == null) return null;
    final peer = peerPubBytes;
    final s = _s?.join(' ').trim() ?? '';
    if (peer == null || s.isEmpty) return null;
    final res = await pairFromPeerBytes(_pairing!, peer, s);
    return res.master;
  }

  /// Загрузить сохранённую семью из secure storage. Идиомпотентно.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _name = await SecureVault.read(_kName);
    final colorHex = await SecureVault.read(_kColor);
    if (colorHex != null) {
      final hex = colorHex.replaceAll('#', '');
      final rgb = hex.length >= 8 ? hex.substring(hex.length - 6) : hex;
      _color = Color(0xFF000000 |
          (int.tryParse(rgb.padLeft(6, '0').substring(0, 6), radix: 16) ??
              0x000000));
    }
    final s = await SecureVault.read(_kS);
    if (s != null) _s = s.split(' ').where((w) => w.isNotEmpty).toList();
    final seed = await SecureVault.read(_kSeed);
    if (seed != null) _seed = seed.split(' ').where((w) => w.isNotEmpty).toList();
    final pairingB64 = await SecureVault.read(_kPairing);
    if (pairingB64 != null) {
      try {
        _pairing = await importPairing(
          PairingExport(
              secretB64: pairingB64.split('|').first,
              pubB64: pairingB64.split('|').last),
        );
      } catch (_) {
        _pairing = null;
      }
    }
    _peerPubB64 = await SecureVault.read(_kPeerPub);
    notifyListeners();
  }

  /// Создать семью на этом устройстве. Генерирует S (4 слова), seed (12 слов),
  /// pairing-ключ. Возвращает S и seed для показа пользователю один раз.
  Future<({List<String> s, List<String> seed})> createFamily({
    required String name,
    required Color color,
  }) async {
    final pairing = await createDevicePairing();

    // S: 4 случайных слова из 2048-словного списка.
    final rng = Random.secure();
    final sWords = List<String>.generate(
        4, (_) => wordlist[rng.nextInt(wordlist.length)]);
    final s = sWords.join(' ');

    // Seed: 16 байт энтропии → 12 слов.
    final entropy = Uint8List.fromList(
        List<int>.generate(16, (_) => rng.nextInt(256)));
    final seed = await encodeSeed(entropy);

    // Сохранить всё в secure storage.
    await SecureVault.write(_kName, name);
    await SecureVault.write(
        _kColor, color.toARGB32().toRadixString(16).replaceFirst('0x', ''));
    await SecureVault.write(_kS, s);
    await SecureVault.write(_kSeed, seed.join(' '));
    final exp = exportPairing(pairing);
    await SecureVault.write(_kPairing, '${exp.secretB64}|${exp.pubB64}');

    _name = name;
    _color = color;
    _s = sWords;
    _seed = seed;
    _pairing = pairing;
    _loaded = true;
    notifyListeners();
    return (s: sWords, seed: seed);
  }

  /// Присоединиться к семье со второго устройства.
  ///
  /// Устройство генерирует СОБСТВЕННЫЙ pairing-ключ, получает извне
  /// семейный секрет S (4 слова) и публичный ключ создателя (32 B, b64).
  /// Симметричный X25519 даёт тот же master, что и создатель.
  ///
  /// Возвращает собственный публичный ключ (b64) — создателю для
  /// завершающего [pairWithPeer].
  Future<({String ownPubB64, Uint8List master})> joinFamily({
    required String name,
    required Color color,
    required List<String> sWords,
    required String peerPubB64,
  }) async {
    final sPhrase = sWords.join(' ').trim();
    if (sPhrase.isEmpty) {
      throw const FormatException('join: S пуст');
    }
    final peerPub = base64Decode(peerPubB64.trim());
    if (peerPub.length != 32) {
      throw const FormatException('join: публичный ключ партнёра не 32 байта');
    }

    final pairing = await createDevicePairing();
    final result = await pairFromPeerBytes(pairing, peerPub, sPhrase);

    final exp = exportPairing(pairing);
    await SecureVault.write(_kName, name);
    await SecureVault.write(
        _kColor, color.toARGB32().toRadixString(16).replaceFirst('0x', ''));
    await SecureVault.write(_kS, sPhrase);
    // Seed у присоединившегося нет (он не восстанавливает pairing) — пусто.
    await SecureVault.write(_kPairing, '${exp.secretB64}|${exp.pubB64}');
    await SecureVault.write(_kPeerPub, peerPubB64.trim());

    _name = name;
    _color = color;
    _s = sPhrase.split(' ').where((w) => w.isNotEmpty).toList();
    _pairing = pairing;
    _peerPubB64 = peerPubB64.trim();
    _loaded = true;
    notifyListeners();
    return (ownPubB64: exp.pubB64, master: result.master);
  }

  /// Создатель завершает pairing, получив публичный ключ присоединившегося.
  /// Даёт тот же [master], что и [joinFamily] (X25519 симметричен).
  Future<Uint8List> pairWithPeer(String peerPubB64) async {
    if (_pairing == null) {
      throw StateError('pair: семья ещё не создана');
    }
    final sPhrase = _s?.join(' ').trim() ?? '';
    if (sPhrase.isEmpty) {
      throw StateError('pair: S не сохранён');
    }
    final peerPub = base64Decode(peerPubB64.trim());
    if (peerPub.length != 32) {
      throw const FormatException('pair: публичный ключ не 32 байта');
    }
    final result = await pairFromPeerBytes(_pairing!, peerPub, sPhrase);
    await SecureVault.write(_kPeerPub, peerPubB64.trim());
    _peerPubB64 = peerPubB64.trim();
    notifyListeners();
    return result.master;
  }

  /// The family lives for the whole process ([family] is a global). A
  /// provider container that wraps it must not kill it for everyone else,
  /// so disposing is a no-op.
  @override
  // ignore: must_call_super
  void dispose() {}

  /// Человек-читаемый лист для печати (seed + S).
  String recoverySheet() {
    if (_seed == null) return '';
    final b64 = _s != null ? utf8Encode(_s!.join(' ')) : Uint8List(0);
    return 'МС · лист восстановления\n\n'
        'S (секрет пары, 4 слова):\n'
        '${_s?.join(' ')}\n\n'
        '${seedToHuman(_seed!)}\n\n'
        'b64(S): ${base64Encode(b64)}';
  }

}

/// Глобальный семейный контроллер (singleton).
final Family family = Family._();
