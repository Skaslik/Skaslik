import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_app/core/box/private_box.dart';
import 'package:ms_app/core/pair/pair.dart';
import 'package:ms_app/design_system/ms_format.dart';
import 'package:ms_app/design_system/ms_theme.dart';
import 'package:ms_app/design_system/widgets/widgets.dart';
import 'package:ms_app/features/files/file_sheets.dart';
import 'package:ms_app/features/files/safe_screen.dart';
import 'package:ms_core/ms_core.dart' hide Clip;
import 'package:path/path.dart' as p;

Future<R> inline<R>(FutureOr<R> Function() task) async => task();

void main() {
  const pair = Pair(
      me: kMichael, partner: kSofia, myDeviceId: 'A', partnerDeviceId: 'B');
  late Directory root;
  late PrivateBox box;

  setUpAll(initMsFormat);

  Future<void> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        pairProvider.overrideWithValue(pair),
        privateBoxProvider.overrideWith((_) => box),
      ],
      child: MaterialApp(
        theme: MsTheme.evening(),
        home: const Scaffold(body: SingleChildScrollView(child: SafeSheet())),
      ),
    ));
    await tester.pump();
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('ms_safe_ui');
    box = PrivateBox(
      dir: Directory(p.join(root.path, 'box')),
      tempDir: () async => Directory(p.join(root.path, 'cache')),
      kdf: const BoxKdf(memoryKib: 64, iterations: 1),
      runner: inline,
    );
  });
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets(
      'no safe yet: two password fields, create enabled only when '
      'they match and are long enough', (tester) async {
    await tester.runAsync(box.init);
    await pumpSheet(tester);
    expect(find.text('Создать сейф'), findsOneWidget);
    expect(find.textContaining('Забудешь пароль'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    MsButton create() => tester
        .widget<MsButton>(find.widgetWithText(MsButton, 'Создать сейф'));
    await tester.enterText(fields.at(0), '12345');
    await tester.enterText(fields.at(1), '12345');
    await tester.pump();
    expect(create().onPressed, isNull);
    await tester.enterText(fields.at(0), 'секрет12');
    await tester.enterText(fields.at(1), 'секрет13');
    await tester.pump();
    expect(create().onPressed, isNull);
    await tester.enterText(fields.at(1), 'секрет12');
    await tester.pump();
    expect(create().onPressed, isNotNull);
  });

  testWidgets('locked: one field, «Открыть сейф», «Забыл пароль»',
      (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
      box.lock();
    });
    await pumpSheet(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Открыть сейф'), findsOneWidget);
    expect(find.text('Забыл пароль'), findsOneWidget);
    expect(find.textContaining('София не видит'), findsOneWidget);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        pairProvider.overrideWithValue(pair),
        privateBoxProvider.overrideWith((_) => box),
      ],
      child: MaterialApp(
        theme: MsTheme.evening(),
        home: SafeScreen(clock: () => DateTime(2026, 10, 11, 12)),
      ),
    ));
    await tester.pump();
  }

  testWidgets('open safe, empty: a warm sentence and «Добавить файл»',
      (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
    });
    await pumpScreen(tester);
    expect(find.text('Личный сейф'), findsOneWidget);
    expect(find.textContaining('Пусто'), findsOneWidget);
    expect(find.text('Добавить файл'), findsOneWidget);
  });

  testWidgets('lists files with kind, size and when', (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
      final f = File(p.join(root.path, 'скан.pdf'))
        ..writeAsBytesSync(List.filled(2048, 1));
      await box.add(f.path, 'Паспорт.pdf');
    });
    await pumpScreen(tester);
    expect(find.text('Паспорт.pdf'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.textContaining('2$kThousandsSepКБ'), findsOneWidget);
  });

  testWidgets('the lock button closes the safe', (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
    });
    await pumpScreen(tester);
    await tester.tap(find.byIcon(Symbols.lock_rounded));
    await tester.pump();
    expect(box.state, BoxState.locked);
  });

  testWidgets('leaving the screen locks the safe', (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
    });
    // The provider (and the safe) stay alive; only the screen goes away.
    final show = ValueNotifier(true);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        pairProvider.overrideWithValue(pair),
        privateBoxProvider.overrideWith((_) => box),
      ],
      child: MaterialApp(
        theme: MsTheme.evening(),
        home: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, on, __) => on ? const SafeScreen() : const SizedBox(),
        ),
      ),
    ));
    await tester.pump();
    expect(box.state, BoxState.unlocked);
    show.value = false;
    await tester.pump();
    await tester.pump(); // the lock runs right after the screen is gone
    expect(box.state, BoxState.locked);
  });

  testWidgets('wrong password says so and keeps the sheet', (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
      box.lock();
    });
    await pumpSheet(tester);
    await tester.enterText(find.byType(TextField), 'не тот');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Открыть сейф'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Не тот пароль'), findsOneWidget);
    expect(box.state, BoxState.locked);
  });
}
