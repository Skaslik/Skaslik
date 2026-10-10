import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_app/core/pair/pair.dart';
import 'package:ms_app/core/providers.dart';
import 'package:ms_app/core/storage/app_paths.dart';
import 'package:ms_app/core/sync/sync_service.dart';
import 'package:ms_app/design_system/ms_format.dart';
import 'package:ms_app/design_system/ms_theme.dart';
import 'package:ms_app/features/files/file_row.dart';
import 'package:ms_app/features/files/file_sheets.dart';
import 'package:ms_app/features/files/files_screen.dart';
import 'package:ms_app/shell/tab_badges.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

const nb = ' ';

void main() {
  late Directory dir;
  const pair = Pair(
      me: kMichael, partner: kSofia, myDeviceId: 'A', partnerDeviceId: 'B');
  final now = DateTime(2026, 10, 8, 21, 14);
  int ms(DateTime d) => d.millisecondsSinceEpoch;

  setUpAll(initMsFormat);

  group('words', () {
    test('sizes: «50 КБ», «0,6 МБ», «1,4 МБ», «2,3 ГБ»', () {
      expect(formatBytes(50 * 1024), '50$nbКБ');
      expect(formatBytes(614 * 1024), '0,6$nbМБ');
      expect(formatBytes((1.4 * 1024 * 1024).round()), '1,4$nbМБ');
      expect(formatBytes((2.3 * 1024 * 1024 * 1024).round()), '2,3$nbГБ');
    });

    test('disk usage: «2,3 из 10 ГБ»', () {
      const gb = 1024 * 1024 * 1024;
      expect(formatDiskUsage((2.3 * gb).round(), 10 * gb), '2,3 из 10$nbГБ');
    });

    test('when: «сегодня», «вчера», «2 окт», «март 2025»', () {
      expect(formatWhen(DateTime(2026, 10, 8, 9), now), 'сегодня');
      expect(formatWhen(DateTime(2026, 10, 7, 23), now), 'вчера');
      expect(formatWhen(DateTime(2026, 10, 2), now), '2 окт');
      expect(formatWhen(DateTime(2025, 3, 2), now), 'март 2025');
    });

    test('expiry badge from 60 days before', () {
      DocMeta exp(DateTime d) =>
          DocMeta(id: 'doc-1', name: 'Полис ОСАГО.pdf', expiresAt: ms(d));
      expect(expiryBadge(exp(DateTime(2026, 12, 8)), now), isNull); // 61
      expect(expiryBadge(exp(DateTime(2026, 12, 7)), now),
          'истекает через 60 дней');
      expect(expiryBadge(exp(DateTime(2026, 12, 1)), now),
          'истекает через 54 дня');
      expect(expiryBadge(exp(DateTime(2026, 10, 8)), now), 'истекает сегодня');
      expect(expiryBadge(exp(DateTime(2026, 9, 1)), now), 'срок истёк');
    });

    test('meta: size · tag · when', () {
      final d = DocMeta(
          id: 'doc-1',
          name: 'Договор аренды 2026.pdf',
          tags: const ['Дом'],
          size: (1.4 * 1024 * 1024).round(),
          at: ms(DateTime(2026, 10, 7, 12)));
      expect(fileMeta(d, now), '1,4$nbМБ · Дом · вчера');
    });

    test('files badge: only the partner\'s additions', () {
      final docs = [
        const DocMeta(id: 'doc-1', name: 'a', uploadedBy: 'A', at: 900),
        const DocMeta(id: 'doc-2', name: 'b', uploadedBy: 'B', at: 500),
        const DocMeta(id: 'doc-3', name: 'old'),
      ];
      expect(filesPartnerActivity(docs, pair), 500);
    });
  });

  group('screen', () {
    setUp(() {
      dir = Directory.systemTemp.createTempSync('ms_files');
      AppPaths.overrideForTest(dir.path);
    });
    tearDown(() {
      AppPaths.reset();
      dir.deleteSync(recursive: true);
    });

    Future<ProviderContainer> pumpFiles(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(overrides: [
        pairProvider.overrideWithValue(pair),
        syncServiceProvider.overrideWith((_) => SyncService()),
      ]);
      addTearDown(c.dispose);
      final repo = DocsRepo(c.read(docsProvider).replica);
      repo.upsert(DocMeta(
          id: 'doc-1', name: 'Договор аренды 2026.pdf', tags: const ['Дом'],
          uploadedBy: 'A', at: ms(DateTime(2026, 10, 7))));
      repo.upsert(DocMeta(
          id: 'doc-2', name: 'Паспорт Софии — скан.pdf', tags: const ['Паспорта'],
          uploadedBy: 'B', at: ms(DateTime(2026, 10, 2))));
      repo.upsert(DocMeta(
          id: 'doc-3', name: 'Полис ОСАГО.pdf', tags: const ['Дом'],
          uploadedBy: 'A', at: ms(DateTime(2026, 9, 1)),
          expiresAt: ms(DateTime(2026, 12, 1))));
      c.read(docsProvider).persist();
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: MsTheme.evening(),
          home: Scaffold(body: FilesScreen(clock: () => now)),
        ),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pump(MsMotion.toast);
      await tester.pumpAndSettle();
    }

    testWidgets('chips with counts filter; badge; safe row last',
        (tester) async {
      await pumpFiles(tester);
      expect(find.text('Файлы'), findsOneWidget);
      expect(find.text('Яндекс.Диск не подключён'), findsOneWidget);
      expect(find.text('истекает через 54 дня'), findsOneWidget);
      expect(find.text('Личный сейф'), findsOneWidget);
      expect(find.byType(FileRow), findsNWidgets(3));

      await tester.tap(find.text('Паспорта'));
      await tester.pumpAndSettle();
      expect(find.byType(FileRow), findsOneWidget);
      expect(find.text('Паспорт Софии — скан.pdf'), findsOneWidget);

      await tester.ensureVisible(find.text('Налоги'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Налоги'));
      await tester.pumpAndSettle();
      expect(find.text('С тегом «Налоги» пока ничего нет.'), findsOneWidget);
    });

    testWidgets('search by name', (tester) async {
      await pumpFiles(tester);
      await tester.tap(find.byIcon(Symbols.search_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'осаго');
      await tester.pumpAndSettle();
      expect(find.byType(FileRow), findsOneWidget);
      expect(find.text('Полис ОСАГО.pdf'), findsOneWidget);
    });

    testWidgets('upload is honest; record without a file is stored',
        (tester) async {
      final c = await pumpFiles(tester);
      await tester.tap(find.text('Файл'));
      await tester.pumpAndSettle();
      expect(find.text('Добавить в общую папку'), findsOneWidget);

      await tester.tap(find.text('Файл с телефона'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(kS3Toast), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Права Михаила');
      await tester.tap(find.text('Поездки').last);
      await tester.pump();
      await tester.tap(find.text('Записать документ'));
      await tester.pumpAndSettle();

      final added = DocsRepo(c.read(docsProvider).replica)
          .all()
          .singleWhere((d) => d.name == 'Права Михаила');
      expect(added.uploadedBy, 'A');
      expect(added.tags, ['Поездки']);
      expect(find.text('Записано. У Софии появится после синка'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('remove asks first', (tester) async {
      final c = await pumpFiles(tester);
      await tester.tap(find.text('Полис ОСАГО.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Убрать из папки'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Убрать'));
      await tester.pumpAndSettle();
      expect(DocsRepo(c.read(docsProvider).replica).get('doc-3'), isNull);
      await finish(tester);
    });
  });
}
