import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ms_app/core/lock/app_lock.dart';
import 'package:ms_app/core/pair/pair.dart';
import 'package:ms_app/core/security/secure_vault.dart';
import 'package:ms_app/design_system/ms_format.dart';
import 'package:ms_app/design_system/ms_theme.dart';
import 'package:ms_app/features/us/us_sheets.dart';

/// A fingerprint reader that answers [ok].
class FakeAuth extends LocalAuthentication {
  FakeAuth({this.ok = true});
  bool ok;
  int asked = 0;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object?> authMessages = const [],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    asked++;
    return ok;
  }
}

/// Argon2id at 64 KiB / 1 pass: the real code path, fast enough for tests.
AppLock cheapLock({LocalAuthentication? auth}) =>
    AppLock(auth: auth, pinKdfMemoryKib: 64, pinKdfIterations: 1);

void main() {
  setUpAll(initMsFormat);
  tearDown(() => SecureVault.delete('ms/applock/pin-hash'));

  test('PIN: the right one unlocks, a wrong one does not', () async {
    final lock = cheapLock();
    await lock.setPin('2580');
    expect(lock.pinSet, isTrue);
    expect(await lock.verifyPin('1111'), isFalse);
    expect(lock.unlocked, isFalse);
    expect(await lock.verifyPin('2580'), isTrue);
    expect(lock.unlocked, isTrue);
  });

  test('a PIN survives a restart (only its hash is stored)', () async {
    await cheapLock().setPin('2580');
    final again = cheapLock();
    await again.loadPin();
    expect(again.pinSet, isTrue);
    expect(await again.verifyPin('2580'), isTrue);
    final stored = await SecureVault.read('ms/applock/pin-hash');
    expect(stored, isNot(contains('2580')));
  });

  test('without a PIN, the triple tap does not open the calculator '
      '(there would be no way back)', () {
    final lock = cheapLock()..unlockManually();
    for (var i = 0; i < 3; i++) {
      lock.onMonogramTap();
    }
    expect(lock.inFake, isFalse);
    expect(lock.unlocked, isTrue);
  });

  test('with a PIN: triple tap → calculator; «PIN =» brings МС back',
      () async {
    final lock = cheapLock()..unlockManually();
    await lock.setPin('2580');
    for (var i = 0; i < 3; i++) {
      lock.onMonogramTap();
    }
    expect(lock.inFake, isTrue);
    expect(lock.unlocked, isFalse);
    expect(await lock.exitFakeWithPin('1111'), isFalse);
    expect(lock.inFake, isTrue);
    expect(await lock.exitFakeWithPin('2580'), isTrue);
    expect(lock.inFake, isFalse);
    expect(lock.unlocked, isTrue);
  });

  testWidgets('without a PIN, «Безопасность» says fake mode needs one',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: MsTheme.evening(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSecuritySheet(context),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Фейк-режим работает только с PIN'),
        findsOneWidget);
    expect(find.textContaining('набери на нём свой PIN'), findsNothing);
  });

  group('recovery sheet without a PIN', () {
    const pair = Pair(
        me: kMichael, partner: kSofia, myDeviceId: 'A', partnerDeviceId: 'B');

    Future<void> openSheet(WidgetTester tester, AppLock lock) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [pairProvider.overrideWithValue(pair)],
        child: MaterialApp(
          theme: MsTheme.evening(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRecoverySheet(context, lock: lock),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for the fingerprint before showing anything',
        (tester) async {
      final auth = FakeAuth(ok: false);
      await openSheet(tester, cheapLock(auth: auth));
      expect(auth.asked, 1);
      expect(find.byType(SelectableText), findsNothing); // nothing secret
      expect(find.text('Отпечаток не подошёл'), findsOneWidget);
      expect(find.text('Открыть по отпечатку'), findsOneWidget);

      auth.ok = true;
      await tester.tap(find.text('Открыть по отпечатку'));
      await tester.pumpAndSettle();
      expect(auth.asked, 2);
      expect(find.textContaining('Перепиши на бумагу'), findsNothing);
      expect(find.byType(SelectableText), findsOneWidget);
    });
  });
}
