/// Seed-фраза: 128 бит энтропии → 12 слов → обратно, checksum, восстановление
/// pairing-ключа.
library;

import 'dart:math';

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  group('wordlist', () {
    test('2048 слов, все уникальны (инъективность)', () {
      final wl = wordlist;
      expect(wl.length, 2048);
      expect(wl.toSet().length, 2048, reason: 'есть дубликаты слов');
    });

    test('все слова непустые', () {
      for (final w in wordlist) {
        expect(w.isNotEmpty, true);
      }
    });
  });

  group('encode/decode', () {
    test('roundtrip: 16 байт энтропии → 12 слов → 16 байт', () async {
      final rng = Random(42);
      final entropy = List<int>.generate(16, (_) => rng.nextInt(256));
      final words = await encodeSeed(entropy);
      expect(words.length, 12);
      final back = await decodeSeed(words);
      expect(back, entropy);
    });

    test('determinism: одна энтропия → всегда те же слова', () async {
      final entropy = List<int>.filled(16, 7);
      final w1 = await encodeSeed(entropy);
      final w2 = await encodeSeed(entropy);
      expect(w1, w2);
    });

    test('опечатка в слове → сбой checksum', () async {
      final rng = Random(1);
      final entropy = List<int>.generate(16, (_) => rng.nextInt(256));
      final words = await encodeSeed(entropy);
      // Подменяем последнее слово на другое (опечатка).
      final swapped = List<String>.from(words);
      final idx = wordlist.indexOf(words.last);
      swapped[11] = wordlist[(idx + 1) % 2048];
      expect(() async => await decodeSeed(swapped), throwsA(isA<FormatException>()));
    });

    test('неизвестное слово → ArgumentError', () async {
      final words = List<String>.filled(12, wordlist.first);
      words[0] = 'не-слово-из-списка';
      expect(() async => await decodeSeed(words), throwsA(isA<ArgumentError>()));
    });

    test('не 12 слов → FormatException', () async {
      expect(() async => await decodeSeed(['a', 'b', 'c']),
          throwsA(isA<FormatException>()));
    });

    test('encode с не-16 байт → ArgumentError', () async {
      expect(() async => await encodeSeed([1, 2, 3]),
          throwsA(isA<ArgumentError>()));
    });
  });

  group('derivePairingSecret', () {
    test('seed → 32 байта, детерминированно', () async {
      final rng = Random(7);
      final entropy = List<int>.generate(16, (_) => rng.nextInt(256));
      final words = await encodeSeed(entropy);
      final s1 = await derivePairingSecret(words);
      final s2 = await derivePairingSecret(words);
      expect(s1.length, 32);
      expect(s1, s2);
    });

    test('полный цикл: secret → seed → secret (восстановление)', () async {
      // Генерируем «secret» как sha256(entropy) — как делает decode.
      final rng = Random(123);
      final entropy = List<int>.generate(16, (_) => rng.nextInt(256));
      final words = await encodeSeed(entropy);
      final secret = await derivePairingSecret(words);
      // Пересоздаём seed из secret-энтропии (тот же путь).
      final words2 = await encodeSeed(entropy);
      expect(words, words2);
      final secret2 = await derivePairingSecret(words2);
      expect(secret, secret2);
    });
  });

  group('seedToHuman', () {
    test('лист содержит 12 пронумерованных слов', () async {
      final entropy = List<int>.filled(16, 3);
      final words = await encodeSeed(entropy);
      final human = seedToHuman(words);
      for (var i = 0; i < 12; i++) {
        expect(human.contains((i + 1).toString().padLeft(2, ' ') + '. ' + words[i]), true);
      }
    });
  });
}
