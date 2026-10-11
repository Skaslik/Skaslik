import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_app/core/sync/yandex_auth.dart';

void main() {
  testWidgets('the token request waits until МС is back on screen',
      (tester) async {
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    var done = false;
    final wait = waitForForeground().then((_) => done = true);
    await tester.pump(const Duration(seconds: 30));
    expect(done, isFalse); // still in the browser

    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await wait;
    expect(done, isTrue);
  });

  testWidgets('already on screen: no wait', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var done = false;
    final wait = waitForForeground().then((_) => done = true);
    await tester.pump();
    await wait;
    expect(done, isTrue);
  });

  test('network hiccups are retried, other errors are not', () async {
    var calls = 0;
    final out = await retryOnNetworkError(() async {
      calls++;
      if (calls < 3) throw const SocketException('Failed host lookup');
      return 'ok';
    }, delays: const [Duration.zero, Duration.zero]);
    expect((out, calls), ('ok', 3));

    calls = 0;
    await expectLater(
        retryOnNetworkError(() async {
          calls++;
          throw YandexAuthError('token: 400 invalid_grant');
        }, delays: const [Duration.zero, Duration.zero]),
        throwsA(isA<YandexAuthError>()));
    expect(calls, 1);
  });
}
