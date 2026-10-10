import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_app/core/pair/pair.dart';
import 'package:ms_app/core/providers.dart';
import 'package:ms_app/core/storage/app_paths.dart';
import 'package:ms_app/core/sync/sync_service.dart';
import 'package:ms_app/design_system/barcode/ean13.dart';
import 'package:ms_app/design_system/ms_format.dart';
import 'package:ms_app/design_system/ms_theme.dart';
import 'package:ms_app/features/cards/card_checkout_screen.dart';
import 'package:ms_app/features/together/banks_model.dart';
import 'package:ms_app/features/together/lists_segment.dart';
import 'package:ms_app/shell/ms_router.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

const nb = ' ';

class _FakeDisplay implements CheckoutDisplay {
  final calls = <String>[];
  @override
  Future<void> enter() async => calls.add('enter');
  @override
  Future<void> leave() async => calls.add('leave');
}

void main() {
  const pair = Pair(
      me: kMichael, partner: kSofia, myDeviceId: 'A', partnerDeviceId: 'B');
  final now = DateTime(2026, 10, 8, 21, 14);
  int ms(DateTime d) => d.millisecondsSinceEpoch;

  setUpAll(initMsFormat);

  group('piggy-bank words', () {
    final bank = PiggyBank(
        id: 'trip', goalName: 'На отпуск', icon: 'trip', targetAmount: 150000,
        createdAt: 1);
    final history = [
      BankEntry(id: '1', by: 'A', amount: 41500, at: ms(DateTime(2026, 9, 1))),
      BankEntry(id: '2', by: 'B', amount: 38000, at: ms(DateTime(2026, 9, 20))),
      BankEntry(id: '3', by: 'A', amount: 5000, at: ms(DateTime(2026, 10, 8, 9))),
      BankEntry(
          id: '4', by: 'A', amount: 500, at: ms(DateTime(2026, 10, 1)),
          isFine: true, note: 'не вынес мусор'),
    ];
    BankState st(PiggyBank b) => BankState(
        bank: b, current: 85000, byUser: const {}, done: false);

    test('shares by person, fines apart', () {
      final s = bankShares(history, pair);
      expect((s.mine, s.theirs, s.fines), (46500, 38000, 500));
    });

    test('«+5 000 сегодня» only for today\'s contributions', () {
      expect(todayBadge(history, now), '+5${nb}000 сегодня');
      expect(todayBadge(history, DateTime(2026, 10, 9)), isNull);
    });

    test('with a target date: «к 1 июня успеваем · нужно … ₽/мес»', () {
      final b = PiggyBank(
          id: 'trip', goalName: 'На отпуск', targetAmount: 150000,
          targetDate: ms(DateTime(2027, 6, 1)), createdAt: 1);
      final line = bankForecast(st(b), history, now);
      expect(line, startsWith('к 1 июня '));
      expect(line, contains('нужно 8${nb}200$nb₽/мес'));
    });

    test('without a date: pace and the month in the dative', () {
      final line = bankForecast(st(bank), history, now);
      expect(line, startsWith('темп 43${nb}000$nb₽/мес · цель к '));
      // 65 000 left at 43 000 a month → two months on: «к декабрю 2026».
      expect(line, endsWith('цель к декабрю 2026'));
    });

    test('nothing yet; done', () {
      expect(bankForecast(st(bank), const [], now),
          'первый взнос — и появится прогноз');
      expect(
          bankForecast(BankState(bank: bank, current: 150000, byUser: const {}, done: true),
              history, now),
          'цель собрана');
    });

    test('last fine: «+500 ₽ · Михаил: не вынес мусор»', () {
      expect(lastFineLine(history, pair), '+500$nb₽ · Михаил: не вынес мусор');
    });

    test('list summary', () {
      expect(listSummary(const []), 'пусто');
      expect(
          listSummary([
            for (var i = 0; i < 12; i++)
              ChecklistItem(id: '$i', text: 't', at: i, done: i < 4),
          ]),
          '12 пунктов · 4 отмечено');
    });
  });

  group('EAN-13', () {
    test('95 modules with guards in place', () {
      final m = ean13Modules('4601234567893');
      expect(m, hasLength(95));
      String bits(int from, int n) =>
          m.sublist(from, from + n).map((b) => b ? '1' : '0').join();
      expect(bits(0, 3), '101');
      expect(bits(45, 5), '01010');
      expect(bits(92, 3), '101');
      expect(ean13IsGuard(46), isTrue);
      expect(ean13IsGuard(10), isFalse);
    });

    test('12 digits are completed; invalid → null; pretty grouping', () {
      expect(ean13Digits('460123456789'), '4601234567893');
      expect(ean13Digits('4601234567890'), isNull);
      expect(ean13Digits('PYAT-123'), isNull);
      expect(ean13Pretty('4601234567893'), '4 601234 567893');
    });
  });

  group('screens', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('ms_together');
      AppPaths.overrideForTest(dir.path);
    });
    tearDown(() {
      AppPaths.reset();
      dir.deleteSync(recursive: true);
    });

    Future<(ProviderContainer, _FakeDisplay)> pumpAt(
        WidgetTester tester, String location) async {
      tester.view.physicalSize = const Size(390 * 3, 1300 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final display = _FakeDisplay();
      final c = ProviderContainer(overrides: [
        pairProvider.overrideWithValue(pair),
        syncServiceProvider.overrideWith((_) => SyncService()),
        checkoutDisplayProvider.overrideWithValue(display),
      ]);
      addTearDown(c.dispose);
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
      for (final p in [banksProvider, notesProvider, cardsProvider]) {
        c.read(p).persist();
      }
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          theme: MsTheme.evening(),
          routerConfig: buildMsRouter(initialLocation: location),
        ),
      ));
      await tester.pumpAndSettle();
      return (c, display);
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pump(MsMotion.toast);
      await tester.pumpAndSettle();
    }

    testWidgets('«+ 1 000 ₽» puts money in as me, with a toast', (tester) async {
      final (c, _) = await pumpAt(tester, '/together?seg=banks');
      expect(find.text('ПОЕЗДКА'), findsOneWidget);
      await tester.tap(find.text('+${nb}1${nb}000$nb₽'));
      await tester.pump();
      final h = BanksRepo(c.read(banksProvider).replica).history('trip');
      expect(h.single.amount, 1000);
      expect(h.single.by, 'A');
      expect(find.textContaining('София увидит: «Миша добавил 1'), findsOneWidget);
      expect(find.text('1${nb}000$nb₽'), findsWidgets);
      await finish(tester);
    });

    testWidgets('tick an item; add an item', (tester) async {
      final (c, _) = await pumpAt(tester, '/together?seg=lists');
      expect(find.text('На выходные'), findsOneWidget);
      await tester.tap(find.text('Молоко'));
      await tester.pumpAndSettle();
      final repo = NotesRepo(c.read(notesProvider).replica);
      expect(repo.items('n1').single.done, isTrue);
      expect(repo.items('n1').single.by, 'A');
      expect(find.text('1 из 1'), findsOneWidget);

      await tester.tap(find.text('+ Добавить пункт'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Хлеб');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repo.items('n1').map((i) => i.text), ['Молоко', 'Хлеб']);
    });

    testWidgets('card tile opens the checkout: white, barcode, screen kept on',
        (tester) async {
      final (_, display) = await pumpAt(tester, '/together?seg=cards');
      expect(find.text('добавила София'), findsOneWidget);
      await tester.tap(find.text('Пятёрочка'));
      await tester.pumpAndSettle();
      expect(find.byType(CardCheckoutScreen), findsOneWidget);
      expect(find.text('4 601234 567893'), findsOneWidget);
      expect(find.text('добавила София · EAN-13'), findsOneWidget);
      expect(display.calls, ['enter']);

      await tester.tap(find.text('Показать QR'));
      await tester.pumpAndSettle();
      expect(find.text('Показать штрихкод'), findsOneWidget);

      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(find.byType(CardCheckoutScreen), findsNothing);
      expect(display.calls, ['enter', 'leave']);
    });
  });
}
