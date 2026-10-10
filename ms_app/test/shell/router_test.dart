import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ms_app/core/providers.dart';
import 'package:ms_app/core/storage/app_paths.dart';
import 'package:ms_app/core/sync/sync_service.dart';
import 'package:ms_app/design_system/ms_format.dart';
import 'package:ms_app/design_system/ms_theme.dart';
import 'package:ms_app/design_system/widgets/widgets.dart';
import 'package:ms_app/features/calendar/calendar_screen.dart';
import 'package:ms_app/features/files/files_screen.dart';
import 'package:ms_app/features/home/home_screen.dart';
import 'package:ms_app/features/together/together_screen.dart';
import 'package:ms_app/features/us/notes_screen.dart';
import 'package:ms_app/features/us/us_screen.dart';
import 'package:ms_app/shell/ms_router.dart';
import 'package:ms_app/shell/ms_shell.dart';

void main() {
  late Directory dir;

  setUpAll(initMsFormat);

  setUp(() {
    // Domain stores write their JSON here, not into the project.
    dir = Directory.systemTemp.createTempSync('ms_router_test');
    AppPaths.overrideForTest(dir.path);
  });

  tearDown(() {
    AppPaths.reset();
    dir.deleteSync(recursive: true);
  });

  Future<GoRouter> pumpApp(WidgetTester tester, String location) async {
    final router = buildMsRouter(initialLocation: location);
    await tester.pumpWidget(ProviderScope(
      // The app's provider wraps a global; tests need their own.
      overrides: [syncServiceProvider.overrideWith((_) => SyncService())],
      child: MaterialApp.router(
          theme: MsTheme.evening(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return router;
  }

  int currentTab(WidgetTester tester) =>
      tester.widget<MsTabBar>(find.byType(MsTabBar)).currentIndex;

  Future<void> tapTab(WidgetTester tester, MsTab tab) async {
    await tester.tap(find.descendant(
        of: find.byType(MsTabBar), matching: find.text(tab.label)));
    await tester.pumpAndSettle();
  }

  testWidgets('five tabs; tapping one switches the branch', (tester) async {
    await pumpApp(tester, '/calendar');
    for (final t in MsTab.values) {
      expect(
          find.descendant(
              of: find.byType(MsTabBar), matching: find.text(t.label)),
          findsOneWidget);
    }
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(currentTab(tester), MsTab.calendar.index);

    await tapTab(tester, MsTab.files);
    expect(find.byType(FilesScreen), findsOneWidget);
    expect(currentTab(tester), MsTab.files.index);
  });

  testWidgets('each tab keeps its stack; re-tapping the tab resets it',
      (tester) async {
    final router = await pumpApp(tester, '/us');
    router.go('/us/notes');
    await tester.pumpAndSettle();
    expect(find.byType(NotesScreen), findsOneWidget);

    await tapTab(tester, MsTab.calendar);
    await tapTab(tester, MsTab.us);
    expect(find.byType(NotesScreen), findsOneWidget);

    await tapTab(tester, MsTab.us);
    expect(find.byType(UsScreen), findsOneWidget);
    expect(find.byType(NotesScreen), findsNothing);
  });

  testWidgets('«Вместе»: ?seg= picks the segment, tapping updates it',
      (tester) async {
    final router = await pumpApp(tester, '/together?seg=lists');
    expect(tester.widget<TogetherScreen>(find.byType(TogetherScreen)).seg,
        TogetherSeg.lists);

    await tester.tap(find.descendant(
        of: find.byType(MsSegmented<TogetherSeg>), matching: find.text('Карты')));
    await tester.pumpAndSettle();
    expect(tester.widget<TogetherScreen>(find.byType(TogetherScreen)).seg,
        TogetherSeg.cards);
    expect(router.routeInformationProvider.value.uri.toString(),
        '/together?seg=cards');
  });

  group('old routes redirect', () {
    final cases = <String, (MsTab, Type, TogetherSeg?)>{
      '/docs': (MsTab.files, FilesScreen, null),
      '/banks': (MsTab.together, TogetherScreen, TogetherSeg.banks),
      '/notes': (MsTab.together, TogetherScreen, TogetherSeg.lists),
      '/cards': (MsTab.together, TogetherScreen, TogetherSeg.cards),
      '/messages': (MsTab.us, NotesScreen, null),
      '/settings': (MsTab.us, UsScreen, null),
    };
    for (final c in cases.entries) {
      testWidgets('${c.key} → ${c.value.$2}', (tester) async {
        await pumpApp(tester, c.key);
        expect(find.byType(c.value.$2), findsOneWidget);
        expect(currentTab(tester), c.value.$1.index);
        final seg = c.value.$3;
        if (seg != null) {
          expect(tester.widget<TogetherScreen>(find.byType(TogetherScreen)).seg,
              seg);
        }
      });
    }

    testWidgets('/room → home', (tester) async {
      await pumpApp(tester, '/room');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(currentTab(tester), MsTab.home.index);
      // Let the home screen's start-up sync probe finish.
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
