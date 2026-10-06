/// Crypto-тесты: roundtrip, tamper, ECDH-симметрия, RFC7748 X25519.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  group('xchacha', () {
    test('seal/open roundtrip', () async {
      final key = List<int>.filled(32, 7);
      final plain = utf8Encode('привет, семья — секретное');
      final sealed = await xchachaSeal(Uint8List.fromList(key), Uint8List.fromList(plain),
          aad: utf8Encode('calendar|42'));
      expect(sealed.length, greaterThan(plain.length));
      final opened = await xchachaOpen(Uint8List.fromList(key), sealed,
          aad: utf8Encode('calendar|42'));
      expect(utf8Decode(opened), 'привет, семья — секретное');
    });

    test('tamper (1 бит) → исключение', () async {
      final key = List<int>.filled(32, 1);
      final sealed = await xchachaSeal(Uint8List.fromList(key), utf8Encode('x'));
      sealed[sealed.length - 1] ^= 1;
      expect(
        () async => await xchachaOpen(Uint8List.fromList(key), sealed),
        throwsA(anything),
      );
    });

    test('wrong AAD → исключение', () async {
      final key = List<int>.filled(32, 2);
      final sealed = await xchachaSeal(Uint8List.fromList(key), utf8Encode('x'),
          aad: utf8Encode('a'));
      expect(
        () async => await xchachaOpen(Uint8List.fromList(key), sealed,
            aad: utf8Encode('b')),
        throwsA(anything),
      );
    });

    test('wrong key → исключение', () async {
      final k1 = List<int>.filled(32, 3);
      final k2 = List<int>.filled(32, 4);
      final sealed = await xchachaSeal(Uint8List.fromList(k1), utf8Encode('x'));
      expect(() async => await xchachaOpen(Uint8List.fromList(k2), sealed),
          throwsA(anything));
    });

    test('неопределённость nonce (два разных ciphertext)', () async {
      final key = List<int>.filled(32, 5);
      final s1 = await xchachaSeal(Uint8List.fromList(key), utf8Encode('x'));
      final s2 = await xchachaSeal(Uint8List.fromList(key), utf8Encode('x'));
      expect(s1.toString(), isNot(s2.toString()));
    });
  });

  group('aesGcm', () {
    test('roundtrip', () async {
      final key = List<int>.filled(32, 9);
      final sealed = await aesGcmSeal(Uint8List.fromList(key), utf8Encode('doc.pdf-медиa'));
      final opened = await aesGcmOpen(Uint8List.fromList(key), sealed);
      expect(utf8Decode(opened), 'doc.pdf-медиa');
    });

    test('tamper → исключение', () async {
      final key = List<int>.filled(32, 10);
      final sealed = await aesGcmSeal(Uint8List.fromList(key), utf8Encode('y'));
      sealed[10] ^= 0x01;
      expect(() async => await aesGcmOpen(Uint8List.fromList(key), sealed),
          throwsA(anything));
    });
  });

  group('X25519 (RFC 7748, Appendix A.1)', () {
    test('known vector: private → public', () async {
      // RFC 7748 A.1
      final priv = _hex(
          '77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a');
      final pub = await x25519Public(_sk(priv));
      expect(
          bytesToHex(pub.bytes),
          '8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a');
    });

    test('ECDH симметрия: A×B == B×A', () async {
      final a = await generateX25519Secret();
      final b = await generateX25519Secret();
      final aPub = await x25519Public(a);
      final bPub = await x25519Public(b);
      final ab = await x25519Shared(a, bPub);
      final ba = await x25519Shared(b, aPub);
      expect(bytesToHex(ab), bytesToHex(ba));
    });
  });

  group('HKDF', () {
    test('deterministic + distinct per info', () async {
      final ikm = List<int>.filled(32, 1);
      final k1 = await hkdf32(ikm, utf8Encode('salt'), utf8Encode('calendar'));
      final k1b = await hkdf32(ikm, utf8Encode('salt'), utf8Encode('calendar'));
      final k2 = await hkdf32(ikm, utf8Encode('salt'), utf8Encode('banks'));
      expect(bytesToHex(k1), bytesToHex(k1b));
      expect(bytesToHex(k1), isNot(bytesToHex(k2)));
    });
  });

  group('Argon2id', () {
    test('deterministic, len 32, salt-dependent', () async {
      final a = await argon2id32('password', 'salt-1');
      final b = await argon2id32('password', 'salt-1');
      final c = await argon2id32('password', 'salt-2');
      expect(a.length, 32);
      expect(bytesToHex(a), bytesToHex(b));
      expect(bytesToHex(a), isNot(bytesToHex(c)));
    });
  });
}
SecretKey _sk(List<int> bytes) => SecretKey(bytes);
List<int> _hex(String h) =>
    List<int>.generate(h.length ~/ 2, (i) => int.parse(h.substring(i * 2, i * 2 + 2), radix: 16));
