/// Base widgets of the design system, in both themes. One file on purpose:
/// a single compile keeps `flutter test` light.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_app/design_system/ms_theme.dart';
import 'package:ms_app/design_system/widgets/widgets.dart';

const ev = MsPalette.evening;
const dy = MsPalette.day;

Future<void> pumpMs(WidgetTester tester, Widget child, {bool day = false}) =>
    tester.pumpWidget(MaterialApp(
      theme: day ? MsTheme.day() : MsTheme.evening(),
      home: Scaffold(body: Center(child: child)),
    ));

TextStyle styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

Material materialOf(WidgetTester tester, Finder within) => tester.widget<Material>(
    find.descendant(of: within, matching: find.byType(Material)).first);

void main() {
  group('MsTheme', () {
    test('evening: dark, tokens wired into ColorScheme and extension', () {
      final t = MsTheme.evening();
      expect(t.brightness, Brightness.dark);
      expect(t.scaffoldBackgroundColor, ev.ground);
      expect(t.colorScheme.primary, ev.flame);
      expect(t.colorScheme.onPrimary, ev.onFlame);
      expect(t.colorScheme.surface, ev.surface);
      expect(t.colorScheme.onSurface, ev.ink);
      expect(t.colorScheme.error, ev.danger);
      expect(t.colorScheme.outline, ev.line);
      expect(t.extension<MsThemeExtension>()!.c, same(ev));
      expect(t.textTheme.bodyMedium!.fontFamily, MsFonts.sans);
      expect(t.textTheme.bodyMedium!.color, ev.ink);
    });

    test('day: light with the day palette', () {
      final t = MsTheme.day();
      expect(t.brightness, Brightness.light);
      expect(t.scaffoldBackgroundColor, dy.ground);
      expect(t.colorScheme.primary, dy.flame);
      expect(t.extension<MsThemeExtension>()!.c, same(dy));
    });

    test('system bars: transparent, icons contrast with ground', () {
      expect(MsTheme.overlay(Brightness.dark).statusBarIconBrightness,
          Brightness.light);
      expect(MsTheme.overlay(Brightness.light).statusBarIconBrightness,
          Brightness.dark);
      expect(MsTheme.overlay(Brightness.dark).statusBarColor, Colors.transparent);
      expect(MsTheme.overlay(Brightness.dark), isA<SystemUiOverlayStyle>());
    });

    testWidgets('context.ms follows the theme', (tester) async {
      late MsPalette seen;
      await pumpMs(tester, Builder(builder: (c) {
        seen = c.ms;
        return const SizedBox();
      }), day: true);
      expect(seen, same(dy));
    });
  });

  group('MsEyebrow', () {
    testWidgets('upper-case mono 11 in inkMuted', (tester) async {
      await pumpMs(tester, const MsEyebrow('Сегодня · четверг'));
      final s = styleOf(tester, 'СЕГОДНЯ · ЧЕТВЕРГ');
      expect(s.fontFamily, MsFonts.mono);
      expect(s.fontSize, 11);
      expect(s.color, ev.inkMuted);
    });
  });

  group('MsMeta', () {
    testWidgets('mono meta, author dot first', (tester) async {
      await pumpMs(tester,
          const MsMeta('19:30 · добавила София', author: MsAuthor.sofia));
      expect(find.byType(MsAuthorDot), findsOneWidget);
      final s = styleOf(tester, '19:30 · добавила София');
      expect(s.fontFamily, MsFonts.mono);
      expect(s.color, ev.inkMuted);
    });

    testWidgets('without author: just the text', (tester) async {
      await pumpMs(tester, const MsMeta('2 мин'));
      expect(find.byType(MsAuthorDot), findsNothing);
    });
  });

  group('MsCard', () {
    testWidgets('surface, radius 20, tappable', (tester) async {
      var taps = 0;
      await pumpMs(tester, MsCard(onTap: () => taps++, child: const Text('Копилка')));
      final m = materialOf(tester, find.byType(MsCard));
      expect(m.color, ev.surface);
      expect((m.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(MsRadius.radiusLg));
      await tester.tap(find.text('Копилка'));
      expect(taps, 1);
    });
  });

  group('MsRowCard', () {
    testWidgets('one-line row is 80 high (56 + padding), radius 14', (tester) async {
      var taps = 0;
      await pumpMs(
        tester,
        SizedBox(
          width: 300,
          child: MsRowCard(onTap: () => taps++, children: const [Text('Йога')]),
        ),
      );
      expect(tester.getSize(find.byType(MsRowCard)).height,
          MsSize.rowMinH + 2 * MsSpace.space3);
      final m = materialOf(tester, find.byType(MsRowCard));
      expect(m.color, ev.surface);
      expect((m.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(MsRadius.radiusMd));
      await tester.tap(find.text('Йога'));
      expect(taps, 1);
    });

    testWidgets('stretch lets an author bar span the row', (tester) async {
      await pumpMs(
        tester,
        const SizedBox(
          width: 300,
          child: MsRowCard(stretch: true, children: [
            MsAuthorBar(MsAuthor.both),
            Center(child: Text('Казань')),
          ]),
        ),
      );
      expect(tester.getSize(find.byType(MsAuthorBar)).height, MsSize.rowMinH);
    });
  });

  group('MsDateBlock', () {
    testWidgets('48 wide, number over an upper-case label, no wrap',
        (tester) async {
      await pumpMs(tester, const MsDateBlock(day: '8', sub: 'сегодня'));
      expect(tester.getSize(find.byType(MsDateBlock)).width, MsSize.dateBlockW);
      expect(find.text('СЕГОДНЯ'), findsOneWidget);
      expect(styleOf(tester, '8').fontFamily, MsFonts.mono);
      expect(tester.takeException(), isNull);
    });
  });

  group('author marks', () {
    testWidgets('dot: 8 px; shared: 13 px of two halves', (tester) async {
      await pumpMs(tester, const MsAuthorDot(MsAuthor.michael));
      expect(tester.getSize(find.byType(MsAuthorDot)), const Size(8, 8));
      await pumpMs(tester, const MsAuthorDot(MsAuthor.both));
      expect(tester.getSize(find.byType(MsAuthorDot)), const Size(13, 8));
      final box = tester.widget<DecoratedBox>(find.descendant(
          of: find.byType(MsAuthorDot), matching: find.byType(DecoratedBox)));
      final g = (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(g.colors, [ev.michael, ev.michael, ev.sofia, ev.sofia]);
    });

    testWidgets('bar: 3 px wide in the author colour', (tester) async {
      await pumpMs(tester, const MsAuthorBar(MsAuthor.sofia, height: 40));
      expect(tester.getSize(find.byType(MsAuthorBar)), const Size(3, 40));
      final box = tester.widget<DecoratedBox>(find.descendant(
          of: find.byType(MsAuthorBar), matching: find.byType(DecoratedBox)));
      expect((box.decoration as BoxDecoration).color, ev.sofia);
    });
  });

  group('MsChip', () {
    testWidgets('idle: outline line, ink text; count in inkMuted',
        (tester) async {
      await pumpMs(tester, const MsChip(label: 'Дом', count: '3'));
      expect(tester.getSize(find.byType(MsChip)).height, MsSize.chipH);
      final m = materialOf(tester, find.byType(MsChip));
      expect((m.shape! as StadiumBorder).side.color, ev.line);
      expect(styleOf(tester, 'Дом').color, ev.ink);
      expect(styleOf(tester, '3').color, ev.inkMuted);
    });

    testWidgets('selected: ink fill, ground text (day theme)', (tester) async {
      var taps = 0;
      await pumpMs(
          tester, MsChip(label: 'Все', selected: true, onTap: () => taps++),
          day: true);
      expect(materialOf(tester, find.byType(MsChip)).color, dy.ink);
      expect(styleOf(tester, 'Все').color, dy.ground);
      await tester.tap(find.text('Все'));
      expect(taps, 1);
    });

    testWidgets('selected person chip: soft fill, coloured outline',
        (tester) async {
      await pumpMs(tester,
          const MsChip(label: 'София', selected: true, person: MsAuthor.sofia));
      final m = materialOf(tester, find.byType(MsChip));
      expect(m.color, ev.sofiaSoft);
      expect((m.shape! as StadiumBorder).side.color, ev.sofia);
      expect(styleOf(tester, 'София').color, ev.ink);
    });
  });

  group('MsSegmented', () {
    testWidgets('selected is ink/w600, others inkMuted; tap reports value',
        (tester) async {
      String? picked;
      await pumpMs(
        tester,
        SizedBox(
          width: 340,
          child: MsSegmented<String>(
            segments: const [
              MsSegment('month', 'Месяц'),
              MsSegment('week', 'Неделя'),
              MsSegment('list', 'Список'),
            ],
            value: 'month',
            onChanged: (v) => picked = v,
          ),
        ),
      );
      expect(styleOf(tester, 'Месяц').color, ev.ink);
      expect(styleOf(tester, 'Месяц').fontWeight, FontWeight.w600);
      expect(styleOf(tester, 'Неделя').color, ev.inkMuted);
      expect(materialOf(tester, find.byType(MsSegmented<String>)).color,
          ev.surface);
      await tester.tap(find.text('Неделя'));
      expect(picked, 'week');
    });
  });

  group('MsButton', () {
    testWidgets('primary: flame / onFlame, 48 high', (tester) async {
      var taps = 0;
      await pumpMs(tester,
          MsButton(label: 'Добавить событие', onPressed: () => taps++));
      expect(tester.getSize(find.byType(MsButton)).height, MsSize.buttonH);
      expect(materialOf(tester, find.byType(MsButton)).color, ev.flame);
      expect(styleOf(tester, 'Добавить событие').color, ev.onFlame);
      await tester.tap(find.text('Добавить событие'));
      expect(taps, 1);
    });

    testWidgets('small: 36 high pill', (tester) async {
      await pumpMs(
          tester,
          MsButton(
              label: '+ 1 000 ₽', size: MsButtonSize.small, onPressed: () {}));
      expect(tester.getSize(find.byType(MsButton)).height, MsSize.buttonSmH);
      expect(materialOf(tester, find.byType(MsButton)).shape, isA<StadiumBorder>());
    });

    testWidgets('secondary: surfaceRaised with a line outline', (tester) async {
      await pumpMs(
          tester,
          MsButton(
              label: 'Скан',
              variant: MsButtonVariant.secondary,
              icon: Icons.document_scanner_outlined,
              onPressed: () {}),
          day: true);
      final m = materialOf(tester, find.byType(MsButton));
      expect(m.color, dy.surfaceRaised);
      expect((m.shape! as RoundedRectangleBorder).side.color, dy.line);
      expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);
    });

    testWidgets('danger uses danger / onDanger', (tester) async {
      await pumpMs(
          tester,
          MsButton(
              label: 'Стереть всё',
              variant: MsButtonVariant.danger,
              onPressed: () {}));
      expect(materialOf(tester, find.byType(MsButton)).color, ev.danger);
      expect(styleOf(tester, 'Стереть всё').color, ev.onDanger);
    });

    testWidgets('disabled: faded and not tappable', (tester) async {
      await pumpMs(tester, const MsButton(label: 'Готово', onPressed: null));
      expect(tester.widget<Opacity>(find.descendant(
              of: find.byType(MsButton), matching: find.byType(Opacity)))
          .opacity, MsAlpha.disabled);
    });
  });

  group('MsSyncStatus', () {
    testWidgets('glyph + word; queue glyph in warn; tappable', (tester) async {
      var taps = 0;
      await pumpMs(
          tester,
          MsSyncStatus(
              kind: MsSyncKind.queue,
              label: 'ждут синка · 3',
              onTap: () => taps++));
      expect(tester.getSize(find.byType(MsSyncStatus)).height, MsSize.syncH);
      final glyph = tester.widget<CustomPaint>(find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MsSyncGlyphPainter));
      final painter = glyph.painter! as MsSyncGlyphPainter;
      expect(painter.kind, MsSyncKind.queue);
      expect(painter.color, ev.warn);
      expect(styleOf(tester, 'ждут синка · 3').fontFamily, MsFonts.mono);
      await tester.tap(find.byType(MsSyncStatus));
      expect(taps, 1);
    });

    test('glyphs: ● ◐ ○ ✕', () {
      expect(MsSyncKind.values.map(MsSyncStatus.glyphOf).join(), '●◐○✕');
    });
  });

  group('MsProgressSplit', () {
    test('parts are value/target of the width, separated by 2 px', () {
      expect(MsProgressSplit.layout(width: 200, target: 100, values: [25, 50]),
          [50, 100]);
      // Over target: clamped to the track, gap included.
      expect(MsProgressSplit.layout(width: 200, target: 100, values: [80, 80]),
          [160, 38]);
      expect(MsProgressSplit.layout(width: 200, target: 100, values: [0, 10]),
          [20]);
      expect(MsProgressSplit.layout(width: 200, target: 0, values: [10]), isEmpty);
    });

    testWidgets('draws michael / sofia / warn segments', (tester) async {
      await pumpMs(
        tester,
        const SizedBox(
          width: 200,
          child: MsProgressSplit(target: 100, parts: [
            MsProgressPart(MsProgressTone.michael, 25),
            MsProgressPart(MsProgressTone.sofia, 25),
            MsProgressPart(MsProgressTone.warn, 10),
          ]),
        ),
      );
      final segs = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();
      expect(segs, hasLength(3));
      expect(tester.getSize(find.byType(AnimatedContainer).first).width, 50);
      expect(tester.getSize(find.byType(MsProgressSplit)).height, MsSize.progressH);
    });
  });

  group('MsSheet', () {
    testWidgets('ground background, grab handle, title', (tester) async {
      await pumpMs(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showMsSheet<void>(context,
                title: 'Новое событие', builder: (_) => const Text('Форма')),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Новое событие'), findsOneWidget);
      expect(find.byType(MsGrabHandle), findsOneWidget);
      expect(tester.getSize(find.byType(MsGrabHandle)),
          const Size(MsSize.grabW, MsSize.grabH));
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, ev.ground);
    });
  });

  group('MsToast', () {
    testWidgets('ink box with ground text, gone after 2.6 s', (tester) async {
      await pumpMs(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => MsToast.show(
                context, 'Добавлено. У Софии появится после синка'),
            child: const Text('add'),
          ),
        ),
      );
      await tester.tap(find.text('add'));
      await tester.pumpAndSettle();
      const msg = 'Добавлено. У Софии появится после синка';
      expect(find.text(msg), findsOneWidget);
      expect(styleOf(tester, msg).color, ev.ground);
      await tester.pump(MsMotion.toast);
      await tester.pumpAndSettle();
      expect(find.text(msg), findsNothing);
    });
  });

  group('MsTabBar', () {
    const items = [
      MsTabItem(icon: Symbols.cottage_rounded, label: 'Дом'),
      MsTabItem(icon: Symbols.calendar_month_rounded, label: 'Календарь'),
      MsTabItem(
          icon: Symbols.favorite_rounded, label: 'Мы', badge: MsAuthor.sofia),
    ];

    testWidgets('64 high; active: flame pill, filled icon, ink w600 label',
        (tester) async {
      int? tapped;
      await pumpMs(
        tester,
        MsTabBar(items: items, currentIndex: 1, onTap: (i) => tapped = i),
      );
      expect(tester.getSize(find.byType(MsTabBar)).height, MsSpace.tabbarH);
      final active = tester.widget<Icon>(find.byIcon(Symbols.calendar_month_rounded));
      expect(active.fill, 1);
      expect(active.color, ev.onFlame);
      final idle = tester.widget<Icon>(find.byIcon(Symbols.cottage_rounded));
      expect(idle.fill, 0);
      expect(idle.color, ev.inkMuted);
      expect(styleOf(tester, 'Календарь').color, ev.ink);
      expect(styleOf(tester, 'Календарь').fontWeight, FontWeight.w600);
      expect(styleOf(tester, 'Дом').color, ev.inkMuted);
      final pills = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();
      expect(pills[1], ev.flame);
      expect(pills[0]!.a, 0);
      await tester.tap(find.text('Мы'));
      expect(tapped, 2);
    });

    testWidgets('badge: 8 px dot in the partner colour', (tester) async {
      await pumpMs(
          tester, MsTabBar(items: items, currentIndex: 0, onTap: (_) {}));
      final dot = tester.widgetList<Container>(find.byType(Container)).where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).shape == BoxShape.circle);
      expect(dot, hasLength(1));
      expect((dot.single.decoration! as BoxDecoration).color, ev.sofia);
    });
  });

  group('MsScreenHeader', () {
    testWidgets('eyebrow over screenTitle, round 40 px action', (tester) async {
      var taps = 0;
      await pumpMs(
        tester,
        SizedBox(
          width: 358,
          child: MsScreenHeader(
            eyebrow: 'общая папка',
            title: 'Файлы',
            actions: [
              MsIconButton(
                  icon: Symbols.search_rounded,
                  label: 'Поиск',
                  onPressed: () => taps++),
            ],
          ),
        ),
      );
      expect(find.text('ОБЩАЯ ПАПКА'), findsOneWidget);
      final title = styleOf(tester, 'Файлы');
      expect(title.fontSize, MsText.screenTitle.fontSize);
      expect(title.color, ev.ink);
      expect(tester.getSize(find.byType(MsIconButton)),
          const Size.square(MsSize.iconButton));
      await tester.tap(find.byType(MsIconButton));
      expect(taps, 1);
    });
  });
}
