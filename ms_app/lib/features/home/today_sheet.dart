import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/candle/candle_controller.dart';
import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import '../calendar/calendar_model.dart';
import '../calendar/event_row.dart';
import 'candle_icon.dart';
import 'home_texts.dart';
import 'sync_sheet.dart';

/// Content of the «Сегодня» sheet over the room, top to bottom: greeting
/// and sync, candle status, today's events, cards at hand, the leading
/// piggy bank.
class TodaySheet extends ConsumerWidget {
  const TodaySheet({super.key, required this.controller, required this.now});

  final ScrollController controller;
  final DateTime now;

  /// Greeting: room-greeting PT Serif at 26/30 (IMPLEMENTATION Phase 3).
  static final TextStyle greetingStyle =
      MsText.roomGreeting.copyWith(fontSize: 26, height: 30 / 26);

  /// Candle row title: 14/18 w600.
  static final TextStyle candleTitleStyle =
      MsText.bodyStrong.copyWith(fontSize: 14, height: 18 / 14);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final sync = ref.watch(syncServiceProvider);
    final candle = ref.watch(candleProvider);
    final pill = syncPill(sync.state);
    final c = candleRowText(candle.info, pair);
    final lit = candle.info.lit;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ms.ground,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(MsRadius.radiusLg)),
        boxShadow: context.msShadows.shadowSheet,
      ),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(MsSpace.space4, MsSize.sheetPadTop,
            MsSpace.space4, MsSpace.space5),
        children: [
          const Center(child: MsGrabHandle()),
          const SizedBox(height: MsSize.grabGap),
          Row(
            spacing: MsSpace.space2,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  // One line, like the design: shrink rather than cut the name.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${greetingFor(now)}, ${pair.me.addressName}',
                      style: greetingStyle.copyWith(color: ms.ink),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              MsSyncStatus(
                kind: pill.kind,
                label: pill.label,
                onTap: () => showSyncSheet(context),
              ),
            ],
          ),
          const SizedBox(height: MsSpace.space3),
          Semantics(
            container: true,
            label: '${c.title}. ${c.meta}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(MsSize.candleRowPadL,
                  MsSpace.space2, MsSpace.space4, MsSpace.space2),
              decoration: BoxDecoration(
                color: lit ? ms.flameSoft : ms.surface,
                borderRadius: BorderRadius.circular(MsRadius.radiusMd),
              ),
              child: Row(
                spacing: MsSpace.space3,
                children: [
                  CandleIcon(lit: lit),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title,
                            style: candleTitleStyle.copyWith(color: ms.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        MsMeta(c.meta),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ..._events(context, ref),
          ..._cards(context, ref),
          ..._piggy(context, ref, pair),
        ],
      ),
    );
  }

  List<Widget> _events(BuildContext context, WidgetRef ref) {
    final store = ref.watch(calendarProvider);
    final start = DateTime(now.year, now.month, now.day);
    final rows = CalendarRepo(store.replica)
        .range(start, start.add(const Duration(days: kHomeEventDays)))
        .take(kHomeEventRows)
        .toList();
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return [
      MsSectionHeader(
        'Сегодня · ${formatWeekdayDayMonth(now)}',
        action: 'Календарь ›',
        onAction: () => context.go('/calendar'),
        top: MsSpace.space5,
      ),
      if (rows.isEmpty)
        MsRowCard(children: [
          Expanded(
            child: Text(
              'Свободный день — можно просто побыть вместе.',
              style: MsText.bodySm.copyWith(color: context.ms.inkMuted),
            ),
          ),
        ])
      else
        for (final (i, (e, occ)) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: MsSpace.space2),
          EventRow(
            day: '${occ.day}',
            sub: dateSub(occ, now),
            author: eventAuthor(e, ref.read(pairProvider)),
            title: e.title,
            meta: eventMetaLine(e, occ, ref.read(pairProvider), now),
            onTap: () => context.go('/calendar?day=${iso(occ)}'),
          ),
        ],
    ];
  }

  List<Widget> _cards(BuildContext context, WidgetRef ref) {
    final repo = CardsRepo(ref.watch(cardsProvider).replica);
    final fav = repo.favorites();
    final cards = (fav.isNotEmpty ? fav : repo.all()).take(3).toList();
    if (cards.isEmpty) return const [];
    return [
      MsSectionHeader('Карты под рукой',
          action: 'Все ›', onAction: () => context.go('/together?seg=cards')),
      Row(
        spacing: MsSpace.space2,
        children: [
          for (final card in cards)
            _CardTile(
              name: card.merchantName,
              onTap: () => context.push('/card/${card.id}'),
            ),
        ],
      ),
    ];
  }

  List<Widget> _piggy(BuildContext context, WidgetRef ref, Pair pair) {
    final repo = BanksRepo(ref.watch(banksProvider).replica);
    final banks = repo.allBanks();
    if (banks.isEmpty) return const [];
    final states = [for (final b in banks) repo.state(b.id)];
    final open = states.where((s) => !s.done).toList();
    final lead = (open.isNotEmpty ? open : states)
        .reduce((a, b) => b.progress > a.progress ? b : a);
    var mine = 0, theirs = 0;
    lead.byUser.forEach((by, sum) => pair.isMine(by) ? mine += sum : theirs += sum);
    final fines = lead.current - mine - theirs;
    MsProgressTone tone(MsAuthor a) =>
        a == MsAuthor.sofia ? MsProgressTone.sofia : MsProgressTone.michael;
    final ms = context.ms;
    final pct = (lead.progress * 100).round();
    return [
      MsSectionHeader('Копилка',
          action: 'Все ›', onAction: () => context.go('/together?seg=banks')),
      MsCard(
        onTap: () => context.go('/together?seg=banks'),
        semanticLabel:
            '${lead.bank.goalName}: ${formatMoney(lead.current)} из ${formatMoney(lead.bank.targetAmount)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MsSize.piggyGap,
          children: [
            Row(children: [
              Expanded(
                child: Text(lead.bank.goalName,
                    style: MsText.bodyStrong.copyWith(color: ms.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              MsMeta('$pct %'),
            ]),
            MsProgressSplit(
              target: lead.bank.targetAmount,
              parts: [
                MsProgressPart(tone(pair.me.author), mine),
                MsProgressPart(tone(pair.partner.author), theirs),
                MsProgressPart(MsProgressTone.warn, fines),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(formatMoney(lead.current),
                      style: MsText.numberMd.copyWith(color: ms.ink)),
                ),
                MsMeta('из ${formatMoney(lead.bank.targetAmount)}'),
              ],
            ),
          ],
        ),
      ),
    ];
  }
}

/// How far ahead Home looks for events, and how many rows it shows.
const int kHomeEventDays = 30;
const int kHomeEventRows = 3;

/// 112 × 64 card tile with a stylised barcode (`.lcard`).
class _CardTile extends StatelessWidget {
  const _CardTile({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MsRadius.radiusMd));
    return Semantics(
      button: true,
      label: 'Открыть карту $name',
      excludeSemantics: true,
      child: Material(
        color: ms.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: MsSize.cardTileW,
            height: MsSize.cardTileH,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: MsSpace.space3, vertical: MsSize.cardTilePadV),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name,
                      style: MsTextX.control
                          .copyWith(fontWeight: FontWeight.w600, color: ms.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(
                    height: MsSize.cardTileBars,
                    child: CustomPaint(painter: _Stripes(ms.ink)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tile's barcode hint: 1 px bar, 2 gap, 2 bar, 1 gap — at 55 %.
class _Stripes extends CustomPainter {
  const _Stripes(this.ink);
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = ink.withValues(alpha: MsAlpha.cardStripes);
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
      canvas.drawRect(Rect.fromLTWH(x + 3, 0, 2, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_Stripes old) => old.ink != ink;
}
