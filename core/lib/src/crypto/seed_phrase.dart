/// 12-словная seed-фраза для восстановления pairing-ключа устройства.
///
/// Дизайн (модель BIP39-128, но компактный и свой):
///  - энтропия — 128 бит (16 байт); этого достаточно для полного уровня
///    безопасности X25519 (128 бит);
///  - 12 слов × 11 бит = 132 бит = 128 бит энтропии + 4 бита контрольной суммы;
///  - контрольная сумма — старшие 4 бита SHA256(энтропия);
///  - 32-байтный секрет X25519 = SHA256(энтропия) (вычисляется при восстановлении).
///
/// Лист хранится дома на бумаге. Опечатка в любом слове → либо «неизвестное
/// слово», либо сбой контрольной суммы (оба случая ловим явно).
library;

import 'dart:convert' as conv;

import 'primitives.dart';

const int _wordsCount = 12;
const int _bitsPerWord = 11;
const int _entropyBits = 128;

// 32 отдельных «головы» (индекс = i % 32).
const List<String> _head = [
  'ярок', 'тих', 'тепл', 'светл', 'волн', 'зарн', 'вечн', 'жив',
  'быстр', 'золот', 'серебр', 'мороз', 'огон', 'камен', 'лесн', 'горн',
  'север', 'южн', 'верхн', 'нижн', 'тайн', 'слад', 'нежн', 'смел',
  'весел', 'смолк', 'явн', 'скрыт', 'цел', 'дробн', 'благ', 'редк',
];

// 64 отдельных «хвоста» (индекс = i ~/ 32).
const List<String> _tail = [
  'ник', 'лет', 'зор', 'мир', 'град', 'цвет', 'звон', 'пень',
  'лад', 'сон', 'рай', 'свет', 'век', 'дух', 'край', 'пир',
  'мост', 'ток', 'звез', 'плес', 'бур', 'штиль', 'гром', 'тень',
  'луг', 'холм', 'берег', 'порт', 'путь', 'след', 'знак', 'ключ',
  'дом', 'двор', 'крыш', 'порог', 'ступ', 'угол', 'лин', 'ритм',
  'шаг', 'взгляд', 'шопот', 'румян', 'пульс', 'вдох', 'выдох', 'покой',
  'рассвет', 'закат', 'полночь', 'полдень', 'ветер', 'дождь', 'снег', 'заря',
  'искра', 'пламя', 'дым', 'пар', 'зерно', 'колос', 'лист', 'почка',
];

String _word(int i) => _head[i % _head.length] + _tail[(i ~/ _head.length) % _tail.length];

List<String>? _wordlist;
Map<String, int>? _index;

/// 2048 уникальных слов. При инициализации проверяем инъективность.
List<String> get wordlist {
  final wl = _wordlist;
  if (wl != null) return wl;
  final built = List<String>.generate(2048, _word);
  final seen = <String>{};
  for (final w in built) {
    if (!seen.add(w)) {
      throw StateError('seed: wordlist неинъективен (дубликат "$w") — баг генератора');
    }
  }
  _wordlist = built;
  return built;
}

int _indexOf(String w) {
  _index ??= {for (var i = 0; i < 2048; i++) wordlist[i]: i};
  final key = w.toLowerCase().trim();
  final v = _index![key];
  if (v == null) throw ArgumentError('seed: неизвестное слово "$w"');
  return v;
}

/// [entropy] (16 байт) → 12 слов.
Future<List<String>> encodeSeed(List<int> entropy) async {
  if (entropy.length != 16) {
    throw ArgumentError('seed: энтропия должна быть 16 байт, получено ${entropy.length}');
  }
  final sha = await _sha256(entropy);
  final checksum = (sha[0] >> 4) & 0x0F; // 4 бита
  // 17-байтовый буфер: 16 байт энтропии + 1 байт (нижние 4 бита = checksum).
  final buf = List<int>.from(entropy);
  buf.add(checksum & 0x0F);
  final words = <String>[];
  for (var j = 0; j < _wordsCount; j++) {
    var val = 0;
    for (var b = 0; b < _bitsPerWord; b++) {
      final p = j * _bitsPerWord + b;
      final bit = (buf[p ~/ 8] >> (p % 8)) & 1;
      val |= bit << b;
    }
    words.add(wordlist[val]);
  }
  return words;
}

/// 12 слов → [entropy] (16 байт). Бросает [FormatException] при ошибке.
Future<List<int>> decodeSeed(List<String> words) async {
  if (words.length != _wordsCount) {
    throw FormatException('seed: нужно $_wordsCount слов, получено ${words.length}');
  }
  final buf = List<int>.filled(_entropyBits ~/ 8 + 1, 0);
  for (var j = 0; j < _wordsCount; j++) {
    final val = _indexOf(words[j]);
    if (val >> _bitsPerWord != 0) {
      throw FormatException('seed: слово выходит за диапазон (val=$val)');
    }
    for (var b = 0; b < _bitsPerWord; b++) {
      final p = j * _bitsPerWord + b;
      if ((val >> b) & 1 == 1) buf[p ~/ 8] |= 1 << (p % 8);
    }
  }
  final entropy = buf.sublist(0, 16);
  final sha = await _sha256(entropy);
  final checksum = (sha[0] >> 4) & 0x0F;
  if (buf[16] & 0x0F != checksum) {
    throw const FormatException('seed: контрольная сумма неверна (опечатка в слове)');
  }
  return entropy;
}

/// Восстановить 32-байтный секрет X25519 из seed-фразы.
Future<List<int>> derivePairingSecret(List<String> words) async {
  final entropy = await decodeSeed(words);
  return _sha256(entropy); // 32 байта
}

/// Человек-читаемый лист (для печати).
String seedToHuman(List<String> words) {
  final b64 = conv.base64Encode(utf8Encode(words.join(' ')));
  final lines = [
    'МС · seed-фраза (12 слов)',
    'Скопируйте ровно в этом порядке. Храните дома, в недоступном месте.',
    '',
    ...words.asMap().entries.map((e) => '${e.key + 1}'.padLeft(2, ' ') + '. ' + e.value),
    '',
    'Проверка (b64): $b64',
  ];
  return lines.join('\n');
}

Future<List<int>> _sha256(List<int> data) async {
  final hex = await sha256Hex(data);
  return List<int>.generate(
      32, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
}
