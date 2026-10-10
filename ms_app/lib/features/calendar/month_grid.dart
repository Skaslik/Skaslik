import 'package:flutter/material.dart';

import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import 'calendar_model.dart';

/// Monday-first month grid (or one week of it): mono numbers, today in
/// `flame`, the selected day ringed in `inkMuted`, author dots, and
/// multi-day bars along the bottom of the cells.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.model,
    required this.selected,
    required this.today,
    required this.onSelect,
    this.weekOnly = false,
  });

  final MonthModel model;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  /// «Неделя»: only the row of the selected day.
  final bool weekOnly;

  static const List<String> weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final rows = [
      for (var w = 0; w < model.weeks; w++)
        if (!weekOnly ||
            model.days.sublist(w * 7, w * 7 + 7).contains(dayOf(selected)))
          w,
    ];
    return Column(
      children: [
        SizedBox(
          height: MsSize.calWeekdayH,
          child: Row(children: [
            for (final d in weekdays)
              Expanded(
                child: Text(d.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: MsTextX.dateSub.copyWith(color: ms.inkMuted)),
              ),
          ]),
        ),
        for (final w in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: MsSize.calRowGap),
            child: SizedBox(
              height: MsSize.calCellH,
              child: LayoutBuilder(builder: (context, c) {
                final col = c.maxWidth / 7;
                return Stack(children: [
                  Row(children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(child: _cell(context, model.days[w * 7 + i])),
                  ]),
                  for (final s in model.spans[w])
                    Positioned(
                      left: s.from * col + (s.startsHere ? MsSize.calSpanInset : 0),
                      width: (s.to - s.from + 1) * col -
                          (s.startsHere ? MsSize.calSpanInset : 0) -
                          (s.endsHere ? MsSize.calSpanInset : 0),
                      bottom: MsSize.calSpanBottom,
                      height: MsSize.calSpanH,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: s.author == MsAuthor.both
                                ? null
                                : s.author.color(ms),
                            gradient: s.author.halves(ms, axis: Axis.horizontal),
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(
                                  s.startsHere ? MsSize.authorBarRadius : 0),
                              right: Radius.circular(
                                  s.endsHere ? MsSize.authorBarRadius : 0),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]);
              }),
            ),
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, DateTime d) {
    final ms = context.ms;
    final out = !model.inMonth(d);
    final isToday = d == today;
    final isSel = !out && d == dayOf(selected) && !isToday;
    final dots = out ? const <MsAuthor>[] : (model.dots[d] ?? const []);
    final count = model.byDay[d]?.length ?? 0;
    return Semantics(
      button: !out,
      selected: d == dayOf(selected),
      label: out
          ? 'другой месяц'
          : '${formatDayMonth(d)}${count > 0 ? ', событий: $count' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: out ? null : () => onSelect(d),
        child: Stack(children: [
          Positioned(
            top: MsSize.calDayTop,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: MsSize.calDayD,
                height: MsSize.calDayD,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? ms.flame : null,
                  border: isSel
                      ? Border.all(color: ms.inkMuted, width: MsSize.calDayRing)
                      : null,
                ),
                child: Text(
                  '${d.day}',
                  style: MsTextX.calDay.copyWith(
                    color: out
                        ? ms.inkFaint
                        : isToday
                            ? ms.onFlame
                            : ms.ink,
                  ),
                ),
              ),
            ),
          ),
          if (dots.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: MsSize.calDotBottom,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: MsSize.calDotGap,
                children: [
                  for (final a in dots) MsAuthorDot(a, size: MsSize.calDot),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}

/// «● Михаил ● София ◐ вместе».
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key, required this.michael, required this.sofia});

  final String michael;
  final String sofia;

  @override
  Widget build(BuildContext context) {
    Widget item(MsAuthor a, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: MsSize.metaGap,
          children: [MsAuthorDot(a), MsMeta(label)],
        );
    return Wrap(
      spacing: MsSize.calLegendGap,
      runSpacing: MsSpace.space1,
      children: [
        item(MsAuthor.michael, michael),
        item(MsAuthor.sofia, sofia),
        item(MsAuthor.both, 'вместе'),
      ],
    );
  }
}
