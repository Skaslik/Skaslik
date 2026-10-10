import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_app/core/lock/app_lock.dart';
import 'package:ms_app/core/lock/fake_calculator.dart';
import 'package:ms_app/core/pair/pair.dart';
import 'package:ms_app/core/providers.dart';
import 'package:ms_app/core/storage/app_paths.dart';
import 'package:ms_app/core/sync/sync_service.dart';
import 'package:ms_app/design_system/ms_format.dart';
import 'package:ms_app/design_system/ms_theme.dart';
import 'package:ms_app/design_system/theme_controller.dart';
import 'package:ms_app/design_system/widgets/widgets.dart';
import 'package:ms_app/features/lock/lock_screen.dart';
import 'package:ms_app/features/us/notes_screen.dart';
import 'package:ms_app/features/us/us_screen.dart';
import 'package:ms_app/shell/ms_router.dart';
import 'package:ms_app/shell/ms_shell.dart';
import 'package:ms_app/shell/tab_badges.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

void main() {
  const pair = Pair(
      me: kMichael, partner: kSofia, myDeviceId: 'A', partnerDeviceId: 'B');

  setUpAll(initMsFormat);

  group('genitive of names', () {
    final cases = {
      ('Соня', true): 'Сони',
      ('Миша', false): 'Миши',
      ('София', true): 'Софии',
      ('Михаил', false): 'Михаила',
      ('Ольга', true): 'Ольги',
      ('Анна', true): 'Анны',
      ('Игорь', false): 'Игоря',
      ('Любовь', true): 'Любови',
      ('Андрей', false): 'Андрея',
      ('Мэри', true): 'Мэри',
    };
    for (final c in cases.entries) {
      test('${c.key.$1} → ${c.value}', () {
        expect(genitiveName(c.key.$1, feminine: c.key.$2), c.value);
      });
    }
  });

  test('PairMember.fromMember: words agree with the gender', () {
    const m = Member(
        deviceId: 'B', name: 'Соня', addressName: 'Сонечка',
        gender: MemberGender.f, color: 'sofia');
    final p = PairMember.fromMember(m, MsAuthor.sofia);
    expect(p.nameGenitive, 'Сони');
    expect(p.addressGenitive, 'Сонечки');
    expect(p.verb('добавил'), 'добавила');
  });

  group('fake calculator', () {
    Future<void> press(WidgetTester t, String k) async {
      await t.tap(find.text(k).last);
      await t.pump();
    }

    testWidgets('counts like a calculator, no МС anywhere', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FakeCalculator()));
      for (final k in ['1', '2', '+', '3', '=']) {
        await press(tester, k);
      }
      expect(find.text('15'), findsOneWidget);
      await press(tester, '÷');
      await press(tester, '0');
      await press(tester, '=');
      expect(find.text('Ошибка'), findsOneWidget);
      expect(find.textContaining('МС'), findsNothing);
    });

    test('without a PIN there is no way out through «=»', () async {
      final lock = AppLock();
      expect(await lock.exitFakeWithPin('1234'), isFalse);
    });

    test('triple tap enters fake mode and locks', () {
      final lock = AppLock()..unlockManually();
      for (var i = 0; i < 3; i++) {
        lock.onMonogramTap();
      }
      expect(lock.inFake, isTrue);
      expect(lock.unlocked, isFalse);
    });
  });

  testWidgets('lock screen: title, four dots, keypad; no PIN → plain entry',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lock = AppLock();
    await tester.pumpWidget(MaterialApp(
      theme: MsTheme.evening(),
      home: LockScreen(lock: lock, autoBiometric: false),
    ));
    await tester.pump();
    expect(find.text('С возвращением'), findsOneWidget);
    expect(find.byType(MsKeypad), findsNothing);
    await tester.tap(find.text('Войти без блокировки'));
    await tester.pump();
    expect(lock.unlocked, isTrue);
  });

  testWidgets('keypad: digits, erase; dots follow', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final typed = <String>[];
    var back = 0;
    await tester.pumpWidget(MaterialApp(
      theme: MsTheme.evening(),
      home: Scaffold(
        body: Column(children: [
          const MsPinDots(filled: 2, length: 4),
          MsKeypad(onDigit: typed.add, onBack: () => back++),
        ]),
      ),
    ));
    for (final d in ['1', '5', '0']) {
      await tester.tap(find.text(d));
    }
    await tester.tap(find.byIcon(Symbols.backspace_rounded));
    expect(typed, ['1', '5', '0']);
    expect(back, 1);
  });

  group('«Мы»', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('ms_us');
      AppPaths.overrideForTest(dir.path);
    });
    tearDown(() {
      AppPaths.reset();
      dir.deleteSync(recursive: true);
    });

    Future<ProviderContainer> pumpAt(WidgetTester tester, String location,
        {void Function(ProviderContainer c)? seed}) async {
      tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final seen = MemorySeenStore()
        ..value = {
          for (final t in MsTab.values) t.name: 0,
          notesSeenKey: 0,
        };
      final c = ProviderContainer(overrides: [
        pairProvider.overrideWithValue(pair),
        syncServiceProvider.overrideWith((_) => SyncService()),
        tabSeenProvider.overrideWith((_) => TabSeen(seen)),
        // «Вечер» fixed: auto mode keeps a sunset timer running.
        themeControllerProvider.overrideWith((_) =>
            ThemeController(prefs: MemoryThemePrefs())
              ..setMode(MsThemeMode.evening)),
      ]);
      addTearDown(c.dispose);
      seed?.call(c);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          theme: MsTheme.evening(),
          routerConfig: buildMsRouter(initialLocation: location),
        ),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    void seedAll(ProviderContainer c) {
      final now = DateTime.now();
      final profile = ProfileRepo(c.read(profileProvider).replica);
      profile.setSince(DateTime(now.year - 4, now.month, now.day));
      CapsulesRepo(c.read(capsuleProvider).replica).seal(Capsule(
        id: 'c1',
        title: 'К годовщине',
        sealDate: now.add(const Duration(days: 40)).millisecondsSinceEpoch,
        letter: 'секрет',
        from: 'B',
      ));
      MessagesRepo(c.read(messagesProvider).replica, deviceId: 'A').send(
          Message(
              id: 'm1', from: 'B', kind: MsgKind.text, text: 'Скучаю',
              at: now.millisecondsSinceEpoch));
    }

    testWidgets('numbers, the waiting letter, groups and badges',
        (tester) async {
      final c = await pumpAt(tester, '/us', seed: seedAll);
      final profile = ProfileRepo(c.read(profileProvider).replica);
      final days = profile.daysTogether(DateTime.now())!;
      expect(find.text('МИХАИЛ И СОФИЯ'), findsOneWidget);
      expect(find.text(formatNumber(days)), findsOneWidget);
      expect(find.text('Тебя ждёт письмо от Софии'), findsOneWidget);
      expect(find.textContaining('откроется '), findsOneWidget);
      // The letter's text stays sealed.
      expect(find.text('секрет'), findsNothing);
      for (final t in ['Авто', 'Вечер', 'День', 'Записки', 'Капсулы',
          'Пульс дня', 'Синхронизация', 'Безопасность',
          'Лист восстановления', 'Устройства']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      // One new note from Sofia: a count on the row, a dot on the tab.
      expect(
          find.descendant(
              of: find.widgetWithText(MsGroupRow, 'Записки'),
              matching: find.text('1')),
          findsOneWidget);
      expect(c.read(tabBadgesProvider)[MsTab.us], MsAuthor.sofia);
    });

    testWidgets('«Записки»: opens the notes, clears the count, sends as me',
        (tester) async {
      final c = await pumpAt(tester, '/us', seed: seedAll);
      await tester.tap(find.text('Записки'));
      await tester.pumpAndSettle();
      expect(find.byType(NotesScreen), findsOneWidget);
      expect(find.text('Скучаю'), findsOneWidget);
      expect(c.read(tabSeenProvider).seenAtKey(notesSeenKey), greaterThan(0));

      await tester.enterText(find.byType(TextField), 'Скоро буду');
      await tester.tap(find.byIcon(Symbols.send_rounded));
      await tester.pump();
      final mine = MessagesRepo(c.read(messagesProvider).replica,
              deviceId: 'A')
          .all()
          .where((m) => m.from == 'A');
      expect(mine.single.text, 'Скоро буду');
      expect(find.textContaining('повиснет у Софии на стене'), findsOneWidget);
      await tester.pump(MsMotion.toast);
      await tester.pumpAndSettle();
    });

    testWidgets('«Пульс дня»: one tap, Sofia sees it', (tester) async {
      final c = await pumpAt(tester, '/us');
      expect(find.text('не отмечен'), findsOneWidget);
      await tester.tap(find.text('Пульс дня'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Устал'));
      await tester.pump();
      final p = PulseRepo(c.read(pulseProvider).replica).byDay().single;
      expect((p.by, p.value), ('A', PulseValue.tired));
      expect(find.text('София увидит: «Устал»'), findsOneWidget);
      await tester.pump(MsMotion.toast);
      await tester.pumpAndSettle();
      expect(find.text('устал'), findsOneWidget);
    });

    testWidgets('theme switch writes the mode', (tester) async {
      final c = await pumpAt(tester, '/us');
      await tester.tap(find.text('День'));
      await tester.pumpAndSettle();
      expect(c.read(themeControllerProvider).mode, MsThemeMode.day);
    });
  });
}
