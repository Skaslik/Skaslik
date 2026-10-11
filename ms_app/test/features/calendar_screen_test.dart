import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_app/core/pair/pair.dart';
import 'package:ms_app/core/providers.dart';
import 'package:ms_app/core/storage/app_paths.dart';
import 'package:ms_app/design_system/ms_format.dart';
import 'package:ms_app/design_system/ms_theme.dart';
import 'package:ms_app/design_system/widgets/widgets.dart';
import 'package:ms_app/features/calendar/calendar_model.dart';
import 'package:ms_app/features/calendar/calendar_screen.dart';
import 'package:ms_app/features/calendar/event_row.dart';
import 'package:ms_app/features/calendar/month_grid.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

void main() {
  late Directory dir;
  const pair = Pair(
      me: kMichael, partner: kSofia, myDeviceId: 'A', partnerDeviceId: 'B');
  final now = DateTime(2026, 10, 8, 9, 0);

  setUpAll(initMsFormat);
  setUp(() {
    dir = Directory.systemTemp.createTempSync('ms_cal');
    AppPaths.overrideForTest(dir.path);
  });
  tearDown(() {
    AppPaths.reset();
    dir.deleteSync(recursive: true);
  });

  Future<ProviderContainer> pumpCal(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(overrides: [pairProvider.overrideWithValue(pair)]);
    addTearDown(c.dispose);
    final repo = CalendarRepo(c.read(calendarProvider).replica);
    repo.upsert(CalEvent(
        id: 'dinner', title: 'Ужин у мамы Софии',
        start: DateTime(2026, 10, 8, 19, 30), ownerId: 'B', createdAt: 1));
    repo.upsert(CalEvent(
        id: 'dentist', title: 'Стоматолог',
        start: DateTime(2026, 10, 9, 10), ownerId: 'A', createdAt: 1));
    c.read(calendarProvider).persist();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: MsTheme.evening(),
        home: Scaffold(body: CalendarScreen(clock: () => now)),
      ),
    ));
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(MsMotion.toast);
    await tester.pumpAndSettle();
  }

  testWidgets('month, today, the day\'s events with author meta',
      (tester) async {
    await pumpCal(tester);
    expect(find.text('Октябрь'), findsOneWidget);
    expect(find.text('ЧЕТВЕРГ, 8 ОКТЯБРЯ'), findsOneWidget);
    expect(find.text('8 ОКТЯБРЯ, ЧЕТВЕРГ'), findsOneWidget);
    expect(find.text('Ужин у мамы Софии'), findsOneWidget);
    expect(find.text('19:30 · добавила София'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^9 октября')));
    await tester.pumpAndSettle();
    expect(find.text('Стоматолог'), findsOneWidget);
    expect(find.text('10:00 · добавил ты'), findsOneWidget);
  });

  testWidgets('week shows one row; list shows «Ближайшие»', (tester) async {
    await pumpCal(tester);
    await tester.tap(find.text('Неделя'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^\d+ октября')), findsNWidgets(7));

    await tester.tap(find.text('Список'));
    await tester.pumpAndSettle();
    expect(find.byType(MonthGrid), findsNothing);
    expect(find.text('БЛИЖАЙШИЕ'), findsOneWidget);
    expect(find.byType(EventRow), findsNWidgets(2));
  });

  testWidgets('next month: «Ноябрь», the 1st selected', (tester) async {
    await pumpCal(tester);
    await tester.tap(find.bySemanticsLabel('Следующий месяц'));
    await tester.pumpAndSettle();
    expect(find.text('Ноябрь'), findsOneWidget);
    expect(find.text('1 НОЯБРЯ, ВОСКРЕСЕНЬЕ'), findsOneWidget);
  });

  testWidgets('add a shared event: stored with owner, toast', (tester) async {
    final c = await pumpCal(tester);
    await tester.tap(find.text('+ Добавить'));
    await tester.pumpAndSettle();
    expect(find.text('Новое событие'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Хэллоуин у Лёши');
    await tester.tap(find.text('Вместе'));
    await tester.pump();
    await tester.tap(find.text('Добавить событие'));
    await tester.pumpAndSettle();

    final added = CalendarRepo(c.read(calendarProvider).replica)
        .all()
        .singleWhere((e) => e.title == 'Хэллоуин у Лёши');
    expect(added.ownerId, 'A');
    expect(added.shared, isTrue);
    expect(added.reminders.offsetsMin, [1440]);
    expect(added.start, DateTime(2026, 10, 8, 10));
    expect(find.text('Добавлено. У Софии появится после синка'), findsOneWidget);
    expect(find.text('10:00 · вместе'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('edit: the form comes filled in; saving keeps the owner',
      (tester) async {
    final c = await pumpCal(tester);
    final repo = CalendarRepo(c.read(calendarProvider).replica);
    repo.upsert(repo.get('dinner')!.copyWith(note: 'взять торт'));
    c.read(calendarProvider).persist(); // saves and tells the screen
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ужин у мамы Софии'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить событие'));
    await tester.pumpAndSettle();
    expect(find.text('Изменить событие'), findsOneWidget); // sheet title
    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.first).controller!.text,
        'Ужин у мамы Софии');
    expect(tester.widget<TextField>(fields.last).controller!.text,
        'взять торт');
    await tester.enterText(fields.first, 'Ужин у мамы');
    await tester.enterText(fields.last, '');
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final e = repo.get('dinner')!;
    expect(e.title, 'Ужин у мамы');
    expect(e.note, isNull);
    expect(e.start, DateTime(2026, 10, 8, 19, 30));
    expect(e.ownerId, 'B'); // still Sofia's event
    expect(e.createdAt, 1);
    expect(e.editedBy, 'A');
    expect(e.editedAt, isNotNull); // the real clock: the sheet takes none
    expect(find.text('Сохранено'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a trip over several days: «до …» sets the last day',
      (tester) async {
    final c = await pumpCal(tester);
    await tester.tap(find.text('+ Добавить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Поездка на дачу');
    await tester.tap(find.text('несколько дней'));
    await tester.pumpAndSettle();
    expect(find.byType(MsDateWheel), findsOneWidget);
    // The wheel starts on the next day.
    expect(find.text('до 9 октября'), findsOneWidget);
    await tester.tap(find.text('Добавить событие'));
    await tester.pumpAndSettle();
    final trip = CalendarRepo(c.read(calendarProvider).replica)
        .all()
        .singleWhere((e) => e.title == 'Поездка на дачу');
    expect(trip.end, DateTime(2026, 10, 9));
    expect(spanDays(trip), 2);
    await finish(tester);
  });

  testWidgets('delete asks first, then removes', (tester) async {
    final c = await pumpCal(tester);
    await tester.tap(find.text('Ужин у мамы Софии'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить событие'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить «Ужин у мамы Софии»?'), findsOneWidget);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(CalendarRepo(c.read(calendarProvider).replica).get('dinner'), isNull);
    expect(find.text('Свободный день — можно просто побыть вместе.'),
        findsOneWidget);
    await finish(tester);
  });
}
