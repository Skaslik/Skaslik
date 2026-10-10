import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ms_app/core/candle/candle_controller.dart';
import 'package:ms_app/core/pair/pair.dart';
import 'package:ms_app/core/providers.dart';
import 'package:ms_app/core/storage/app_paths.dart';
import 'package:ms_app/core/sync/sync_service.dart';
import 'package:ms_app/core/weather/weather.dart';
import 'package:ms_app/design_system/ms_format.dart';
import 'package:ms_app/design_system/ms_theme.dart';
import 'package:ms_app/design_system/theme_controller.dart';
import 'package:ms_app/features/home/home_screen.dart';
import 'package:ms_app/features/home/room_scene.dart';
import 'package:ms_app/features/home/weather_sheet.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

class _Offline implements WeatherRepository {
  @override
  Future<WeatherNow> fetch(MsCity city) async =>
      throw http.ClientException('offline');
}

void main() {
  late Directory dir;
  const pair = Pair(
      me: kMichael, partner: kSofia, myDeviceId: 'A', partnerDeviceId: 'B');

  setUpAll(initMsFormat);
  setUp(() {
    dir = Directory.systemTemp.createTempSync('ms_home');
    AppPaths.overrideForTest(dir.path);
  });
  tearDown(() {
    AppPaths.reset();
    dir.deleteSync(recursive: true);
  });

  Future<ProviderContainer> pumpHome(WidgetTester tester,
      {WeatherNow? weather}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      pairProvider.overrideWithValue(pair),
      // The app's provider wraps a global; tests need their own.
      syncServiceProvider.overrideWith((_) => SyncService()),
      weatherProvider.overrideWith((_) => WeatherController(
          repo: _Offline(), cache: MemoryWeatherCache(weather))),
      candleProvider.overrideWith((ref) => CandleController(
          store: ref.watch(ritualProvider.notifier),
          pair: pair,
          notified: MemoryCandleNotifiedStore())),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: MsTheme.evening(),
        // No flicker/perk, so the tree can settle.
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: const Scaffold(body: HomeScreen()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  Future<void> finish(WidgetTester tester) async {
    // Let the start-up sync probe and any toast run out.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  }

  Finder hit(String startsWith) => find.byWidgetPredicate((w) =>
      w is Semantics && (w.properties.label ?? '').startsWith(startsWith));

  testWidgets('room plus sheet: greeting, candle off, free day',
      (tester) async {
    await pumpHome(tester);
    expect(find.byType(RoomScene), findsOneWidget);
    expect(find.textContaining(', Миша'), findsOneWidget);
    expect(find.text('Свеча не горит'), findsOneWidget);
    expect(find.text('нажми на свечу — загорится и у Сони'), findsOneWidget);
    expect(find.text('Свободный день — можно просто побыть вместе.'),
        findsOneWidget);
    await finish(tester);
  });

  testWidgets('tap the candle lights it; long press puts it out',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(hit('Свеча:'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Горит у тебя'), findsOneWidget);

    // Hold past the 650 ms threshold (tester.longPress holds only 600 ms).
    final g = await tester.startGesture(tester.getCenter(hit('Свеча:')));
    await tester.pump(const Duration(milliseconds: 700));
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Свеча не горит'), findsOneWidget);
    expect(find.text('Свеча погасла у обоих'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('weather: text in the window, sheet on tap', (tester) async {
    final w = WeatherNow(
        temp: 7.2,
        feels: 4.4,
        wind: 5,
        code: 61,
        isDay: false,
        fetchedAt: DateTime.now());
    await pumpHome(tester, weather: w);
    expect(find.text('+7°'), findsOneWidget);
    expect(find.text('мелкий дождь'), findsOneWidget);
    expect(find.text('МОСКВА'), findsOneWidget);

    await tester.tap(hit('Окно:'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(WeatherSheet), findsOneWidget);
    expect(find.text('МОСКВА · СЕЙЧАС'), findsOneWidget);
    expect(find.text('ощущается как +4° · ветер 5 м/с'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the partner\'s latest note hangs on the wall', (tester) async {
    final c = await pumpHome(tester);
    MessagesRepo(c.read(messagesProvider).replica, deviceId: 'A').send(Message(
        id: 'm1',
        from: 'B',
        kind: MsgKind.text,
        text: 'Купи хлеб',
        at: DateTime.now().millisecondsSinceEpoch));
    c.read(messagesProvider).persist();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Купи хлеб'), findsOneWidget);
    expect(find.text('— С.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('dog: a toast', (tester) async {
    await pumpHome(tester);
    await tester.tap(hit('Басенджи'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Басенджи не лают — зато внимательно смотрят'),
        findsOneWidget);
    await finish(tester);
  });
}
