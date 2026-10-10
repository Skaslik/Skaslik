import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import '../home/home_texts.dart';
import 'add_event_sheet.dart';
import 'calendar_model.dart';
import 'event_row.dart';
import 'event_sheet.dart';
import 'month_grid.dart';

enum CalView { month, week, list }

/// «Календарь»: month / week / list, the selected day's events and
/// «+ Добавить» (components/ScreenCalendar.md).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.initialDay, this.clock});

  /// `/calendar?day=2026-10-08` — tapping an event on Home.
  final DateTime? initialDay;
  final DateTime Function()? clock;

  /// Parses `yyyy-mm-dd`, or null.
  static DateTime? parseDay(String? s) {
    if (s == null) return null;
    final d = DateTime.tryParse(s);
    return d == null ? null : dayOf(d);
  }

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month;
  late DateTime _selected;
  CalView _view = CalView.month;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _select(widget.initialDay ?? dayOf(_now));
  }

  @override
  void didUpdateWidget(CalendarScreen old) {
    super.didUpdateWidget(old);
    final d = widget.initialDay;
    if (d != null && d != old.initialDay) {
      _select(d);
      _view = CalView.month;
    }
  }

  void _select(DateTime d) {
    _selected = dayOf(d);
    _month = DateTime(d.year, d.month);
  }

  void _shift(int dir) => setState(() {
        if (_view == CalView.week) {
          _select(_selected.add(Duration(days: 7 * dir)));
        } else {
          final m = DateTime(_month.year, _month.month + dir);
          final today = dayOf(_now);
          _month = m;
          // Keep today selected in its month; otherwise the 1st.
          _selected = today.year == m.year && today.month == m.month ? today : m;
        }
      });

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final store = ref.watch(calendarProvider);
    final events = CalendarRepo(store.replica).all();
    final now = _now;
    final today = dayOf(now);
    final model = MonthModel.build(_month, events, pair);
    final rows = _view == CalView.list
        ? upcomingList(events, now)
        : (model.byDay[_selected] ?? const <(CalEvent, DateTime)>[]);
    final title = _month.year == today.year
        ? formatMonthTitle(_month)
        : '${formatMonthTitle(_month)} ${_month.year}';

    return MsScreen(children: [
      MsScreenHeader(
        eyebrow: formatWeekdayDayMonth(now),
        title: title,
        actions: _view == CalView.list
            ? const []
            : [
                MsIconButton(
                  icon: Symbols.chevron_left_rounded,
                  label: _view == CalView.week
                      ? 'Предыдущая неделя'
                      : 'Предыдущий месяц',
                  onPressed: () => _shift(-1),
                ),
                MsIconButton(
                  icon: Symbols.chevron_right_rounded,
                  label: _view == CalView.week
                      ? 'Следующая неделя'
                      : 'Следующий месяц',
                  onPressed: () => _shift(1),
                ),
              ],
      ),
      const SizedBox(height: MsSize.calSegTop),
      MsSegmented<CalView>(
        segments: const [
          MsSegment(CalView.month, 'Месяц'),
          MsSegment(CalView.week, 'Неделя'),
          MsSegment(CalView.list, 'Список'),
        ],
        value: _view,
        onChanged: (v) => setState(() => _view = v),
      ),
      const SizedBox(height: MsSize.calSegBottom),
      if (_view != CalView.list) ...[
        MonthGrid(
          model: model,
          selected: _selected,
          today: today,
          weekOnly: _view == CalView.week,
          onSelect: (d) => setState(() => _selected = d),
        ),
        const SizedBox(height: MsSize.calLegendTop),
        CalendarLegend(michael: kMichael.name, sofia: kSofia.name),
      ],
      MsSectionHeader(
        _view == CalView.list ? 'Ближайшие' : dayHeading(_selected),
        action: '+ Добавить',
        onAction: () => showAddEventSheet(
            context, _view == CalView.list ? today : _selected),
        top: MsSize.calListTop,
      ),
      if (rows.isEmpty)
        MsRowCard(children: [
          Expanded(
            child: Text(
              _view == CalView.list
                  ? 'Пока тишина. Добавь первое событие — и календарь оживёт.'
                  : 'Свободный день — можно просто побыть вместе.',
              style: MsText.bodySm.copyWith(color: ms.inkMuted),
            ),
          ),
        ])
      else
        for (final (i, (e, occ)) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: MsSpace.space2),
          EventRow(
            day: '${occ.day}',
            sub: dateSub(occ, now),
            author: eventAuthor(e, pair),
            title: e.title,
            meta: eventMetaLine(e, occ, pair, now),
            onTap: () => showEventSheet(context, e, occ),
          ),
        ],
    ]);
  }
}
