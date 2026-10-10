// Accessibility sweep (IMPLEMENTATION.md Phase 8): every tab, both themes,
// against Flutter's guidelines — tap targets ≥ 48, every tap target has a
// label, text contrast ≥ 4.5:1.
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
import 'package:ms_app/design_system/widgets/widgets.dart';
import 'package:ms_app/shell/ms_router.dart';
import 'package:ms_app/shell/ms_shell.dart';
import 'package:ms_app/shell/tab_badges.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

class _Offline implements WeatherRepository {
  @override
  Future<WeatherNow> fetch(MsCity city) async =>
      throw http.ClientException('offline');
}

void main() {
  const pair = Pair(
      me: kMichael, partner: kSofia, myDeviceId: 'A', partnerDeviceId: 'B');
  late Directory dir;

  setUpAll(initMsFormat);
  setUp(() {
    dir = Directory.systemTemp.createTempSync('ms_a11y');
    AppPaths.overrideForTest(dir.path);
  });
  tearDown(() {
    AppPaths.reset();
    dir.deleteSync(recursive: true);
  });

  void seed(ProviderContainer c) {
    final now = DateTime.now();
    final ms = now.millisecondsSinceEpoch;
    CalendarRepo(c.read(calendarProvider).replica).upsert(CalEvent(
        id: 'e1', title: 'Ужин у мамы', ownerId: 'B', createdAt: ms,
        start: DateTime(now.year, now.month, now.day, 19),
        shared: true));
    DocsRepo(c.read(docsProvider).replica).upsert(DocMeta(
        id: 'd1', name: 'Договор аренды.pdf', uploadedBy: 'B', at: ms,
        size: 240000, kind: 'pdf'));
    BanksRepo(c.read(banksProvider).replica).createBank(PiggyBank(
        id: 'trip', goalName: 'На отпуск', icon: 'trip',
        targetAmount: 150000, createdAt: 1));
    final notes = NotesRepo(c.read(notesProvider).replica);
    notes.upsert(const Note(id: 'n1', title: 'На выходные', at: 2));
    notes.addItem('n1', const ChecklistItem(id: 'milk', text: 'Молоко', at: 1));
    CardsRepo(c.read(cardsProvider).replica).upsert(LoyaltyCard(
        id: 'p5', merchantName: 'Пятёрочка',
        category: CardCategory.supermarket, barcodeType: BarcodeType.ean13,
        barcodeValue: '4601234567893', addedBy: 'B'));
    MessagesRepo(c.read(messagesProvider).replica, deviceId: 'A').send(Message(
        id: 'm1', from: 'B', kind: MsgKind.text, text: 'Скучаю', at: ms));
  }

  testWidgets('MsTapTarget: a touch just outside a 36 px pill still counts',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: MsTheme.evening(),
      home: Scaffold(
        body: Center(
          child: MsButton(
              label: '+ 1 000 ₽',
              size: MsButtonSize.small,
              onPressed: () => taps++),
        ),
      ),
    ));
    final box = tester.getRect(find.byType(MsTapTarget));
    expect(box.height, MsSize.buttonSmH); // layout unchanged
    await tester.tapAt(box.topCenter - const Offset(0, 5));
    await tester.tapAt(box.bottomCenter + const Offset(0, 5));
    expect(taps, 2);
    await tester.tapAt(box.topCenter - const Offset(0, 10));
    expect(taps, 2);
  });

  const screens = [
    '/home',
    '/calendar',
    '/files',
    '/together?seg=banks',
    '/together?seg=lists',
    '/together?seg=cards',
    '/us',
    '/us/notes',
  ];

  for (final evening in [true, false]) {
    for (final path in screens) {
      testWidgets('$path · ${evening ? 'Вечер' : 'День'}', (tester) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final seen = MemorySeenStore()
          ..value = {for (final t in MsTab.values) t.name: 0, notesSeenKey: 0};
        final c = ProviderContainer(overrides: [
          pairProvider.overrideWithValue(pair),
          syncServiceProvider.overrideWith((_) => SyncService()),
          tabSeenProvider.overrideWith((_) => TabSeen(seen)),
          themeControllerProvider.overrideWith((_) =>
              ThemeController(prefs: MemoryThemePrefs())
                ..setMode(evening ? MsThemeMode.evening : MsThemeMode.day)),
          weatherProvider.overrideWith((_) => WeatherController(
              repo: _Offline(), cache: MemoryWeatherCache(null))),
          candleProvider.overrideWith((ref) => CandleController(
              store: ref.watch(ritualProvider.notifier),
              pair: pair,
              notified: MemoryCandleNotifiedStore())),
        ]);
        addTearDown(c.dispose);
        seed(c);
        await tester.pumpWidget(UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(
            theme: evening ? MsTheme.evening() : MsTheme.day(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!),
            routerConfig: buildMsRouter(initialLocation: path),
          ),
        ));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        semantics.dispose();
        // Let the start-up sync probe and any timers run out.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      });
    }
  }
}
