import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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

  Future<void> pumpSheet(WidgetTester tester, {Pair who = pair}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        pairProvider.overrideWithValue(who),
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
    // The keyboard must not learn or suggest the password.
    for (final f in tester.widgetList<TextField>(fields)) {
      expect(f.obscureText, isTrue);
      expect(f.enableIMEPersonalizedLearning, isFalse);
      expect(f.enableSuggestions, isFalse);
      expect(f.autocorrect, isFalse);
    }
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

  testWidgets('a damaged file says so when opened', (tester) async {
    late BoxEntry e;
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
      final f = File(p.join(root.path, 'договор.pdf'))
        ..writeAsBytesSync(List.filled(100, 1));
      e = await box.add(f.path, 'Договор.pdf');
      final bin = File(p.join(root.path, 'box', 'files', '${e.id}.bin'));
      final bytes = bin.readAsBytesSync();
      bytes[bytes.length - 5] ^= 1;
      bin.writeAsBytesSync(bytes);
    });
    await pumpScreen(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Договор.pdf'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.textContaining('Файл повреждён'), findsOneWidget);
    await tester.pump(MsMotion.toast);
    await tester.pumpAndSettle();
  });

  testWidgets('a viewed photo leaves the image cache when the viewer closes',
      (tester) async {
    final cache = PaintingBinding.instance.imageCache..clear();
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
      final png = img.encodePng(img.Image(width: 2, height: 2));
      final f = File(p.join(root.path, 'фото.png'))..writeAsBytesSync(png);
      await box.add(f.path, 'фото.png');
    });
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        pairProvider.overrideWithValue(pair),
        privateBoxProvider.overrideWith((_) => box),
      ],
      child: MaterialApp(
        navigatorKey: nav,
        theme: MsTheme.evening(),
        home: const Scaffold(body: Text('база')),
      ),
    ));
    unawaited(nav.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const SafeScreen())));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('фото.png'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(cache.currentSize + cache.pendingImageCount + cache.liveImageCount,
        greaterThan(0));
    box.lock(); // the app was hidden: viewer and safe close
    await tester.pumpAndSettle();
    expect(find.text('база'), findsOneWidget);
    expect(cache.currentSize + cache.pendingImageCount + cache.liveImageCount,
        0);
  });

  testWidgets('while the safe is open, Android hides it from screenshots',
      (tester) async {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('ms/secure_screen'), (call) async {
      calls.add('${call.method}:${call.arguments}');
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('ms/secure_screen'), null));
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
    });
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
    expect(calls, ['set:true']);
    show.value = false;
    await tester.pump();
    expect(calls, ['set:true', 'set:false']);
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

  testWidgets('«Забыла пароль» for Sofia', (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
      box.lock();
    });
    await pumpSheet(tester,
        who: const Pair(
            me: kSofia,
            partner: kMichael,
            myDeviceId: 'B',
            partnerDeviceId: 'A'));
    expect(find.text('Забыла пароль'), findsOneWidget);
    expect(find.textContaining('Михаил не видит'), findsOneWidget);
  });

  testWidgets('a damaged safe says so instead of doing nothing',
      (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
      box.lock();
      File(p.join(root.path, 'box', 'index.bin')).writeAsBytesSync([1, 2, 3]);
    });
    await pumpSheet(tester);
    await tester.enterText(find.byType(TextField), 'секрет12');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Открыть сейф'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.textContaining('Сейф повреждён'), findsOneWidget);
  });

  testWidgets('when the safe locks, it closes with whatever is open over it',
      (tester) async {
    await tester.runAsync(() async {
      await box.init();
      await box.create('секрет12');
    });
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        pairProvider.overrideWithValue(pair),
        privateBoxProvider.overrideWith((_) => box),
      ],
      child: MaterialApp(
        navigatorKey: nav,
        theme: MsTheme.evening(),
        home: const Scaffold(body: Text('база')),
      ),
    ));
    unawaited(nav.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const SafeScreen())));
    await tester.pumpAndSettle();
    // A photo (or a dialog) open over the safe.
    unawaited(nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('фото')))));
    await tester.pumpAndSettle();
    box.lock(); // the app was hidden
    await tester.pumpAndSettle();
    expect(find.text('фото'), findsNothing);
    expect(find.byType(SafeScreen), findsNothing);
    expect(find.text('база'), findsOneWidget);
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
