/// Pairing: симметрия, per-domain ключи, forward secrecy, export/import.
library;

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  group('pair()', () {
    test('симметрия: A и B получают идентичный master и ключи', () async {
      final a = await createDevicePairing();
      final b = await createDevicePairing();
      final s = 'дом дождь книга';
      final ra = await pair(a, b.pub, s);
      final rb = await pair(b, a.pub, s);
      expect(bytesToHex(ra.master), bytesToHex(rb.master));
      for (final d in Domain.values) {
        expect(bytesToHex(ra.domains.keyFor(d)),
            bytesToHex(rb.domains.keyFor(d)),
            reason: 'ключ $d расходится');
      }
    });

    test('разные семейные секреты → разные master', () async {
      final a = await createDevicePairing();
      final b = await createDevicePairing();
      final r1 = await pair(a, b.pub, 'секрет-один');
      final r2 = await pair(a, b.pub, 'секрет-два');
      expect(bytesToHex(r1.master), isNot(bytesToHex(r2.master)));
    });

    test('разные устройства → разные master (хотя бы по pairing-ключам)', () async {
      final a = await createDevicePairing();
      final b = await createDevicePairing();
      final c = await createDevicePairing();
      final r1 = await pair(a, b.pub, 'секрет');
      final r2 = await pair(a, c.pub, 'секрет');
      expect(bytesToHex(r1.master), isNot(bytesToHex(r2.master)));
    });

    test('8 доменов → 8 разных ключей', () async {
      final a = await createDevicePairing();
      final b = await createDevicePairing();
      final r = await pair(a, b.pub, 'секрет');
      final keys = {for (final d in Domain.values) d: bytesToHex(r.domains.keyFor(d))};
      expect(keys.values.toSet().length, Domain.values.length,
          reason: 'каждый домен — уникальный ключ');
    });

    test('pairFromPeerBytes: симметрия с pair() (путь join)', () async {
      final a = await createDevicePairing(); // создатель
      final b = await createDevicePairing(); // присоединившееся
      final s = 'дом дождь книга';
      final ra = await pair(a, b.pub, s);
      final rb = await pairFromPeerBytes(b, a.pub.bytes, s);
      expect(bytesToHex(ra.master), bytesToHex(rb.master),
          reason: 'join по сырым байтам pub даёт тот же master');
    });

    test('pairFromPeerBytes: битная длина pub → исключение', () async {
      final a = await createDevicePairing();
      expect(
        () => pairFromPeerBytes(a, List<int>.filled(31, 1), 's'),
        throwsFormatException,
      );
    });
  });

  group('transport session (forward secrecy)', () {
    test('A и B выводят одинаковый сессионный ключ', () async {
      final aStatic = await generateX25519Secret();
      final bStatic = await generateX25519Secret();
      final aStaticPub = await x25519Public(aStatic);
      final bStaticPub = await x25519Public(bStatic);
      final aEph = await generateX25519Secret();
      final bEph = await generateX25519Secret();
      final aEphPub = await x25519Public(aEph);
      final bEphPub = await x25519Public(bEph);
      final salt = utf8Encode('ms/session');
      final info = utf8Encode('channel-1');
      final sa = await deriveTransportSession(
        myEph: aEph,
        peerEphPub: bEphPub,
        myStatic: aStatic,
        peerStaticPub: bStaticPub,
        salt: salt,
        info: info,
      );
      final sb = await deriveTransportSession(
        myEph: bEph,
        peerEphPub: aEphPub,
        myStatic: bStatic,
        peerStaticPub: aStaticPub,
        salt: salt,
        info: info,
      );
      expect(bytesToHex(sa), bytesToHex(sb));
    });
  });

  group('export/import pairing', () {
    test('roundtrip', () async {
      final p = await createDevicePairing();
      final e = exportPairing(p);
      final back = await importPairing(e);
      expect(bytesToHex(back.pub.bytes), bytesToHex(p.pub.bytes));
    });

    test('битый pub → исключение', () async {
      final p = await createDevicePairing();
      final e = exportPairing(p);
      final bad = PairingExport(
        secretB64: e.secretB64,
        pubB64: 'AAAA${e.pubB64.substring(4)}', // повреждаем
      );
      expect(() async => await importPairing(bad), throwsA(anything));
    });
  });
}
