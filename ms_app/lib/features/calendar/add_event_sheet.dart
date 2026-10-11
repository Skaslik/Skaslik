import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/notify/notifications.dart';
import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import 'calendar_model.dart';

/// Opens «Новое событие» for [day]. The sheet can't be swiped away by
/// accident once a title is typed.
Future<void> showAddEventSheet(BuildContext context, DateTime day) =>
    showMsSheet<void>(
      context,
      title: 'Новое событие',
      builder: (_) => AddEventSheet(day: day),
    );

/// «Изменить событие»: the same form, filled in.
Future<void> showEditEventSheet(BuildContext context, CalEvent e) =>
    showMsSheet<void>(
      context,
      title: 'Изменить событие',
      builder: (_) => AddEventSheet(day: dayOf(e.start), editing: e),
    );

/// Reminder choices (PLAN 5.3): за день / за час / за 15 мин.
const List<(int, String)> kReminderChoices = [
  (1440, 'за день'),
  (60, 'за час'),
  (15, 'за 15 мин'),
];

/// Default reminder, as preselected in the prototype.
const Set<int> kDefaultReminders = {1440};

class AddEventSheet extends ConsumerStatefulWidget {
  const AddEventSheet({super.key, required this.day, this.clock, this.editing});

  final DateTime day;
  final DateTime Function()? clock;

  /// Set when editing: the form starts from it and «Сохранить» keeps its
  /// id, author and creation time.
  final CalEvent? editing;

  @override
  ConsumerState<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<AddEventSheet> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  bool _shared = false;
  bool _allDay = false;
  bool _pickTime = false;
  late Duration _time;
  Recurrence _repeat = Recurrence.none;
  final Set<int> _remind = {...kDefaultReminders};

  /// Last day of a multi-day event; null for a one-day event.
  DateTime? _endDay;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _title.text = e.title;
      _note.text = e.note ?? '';
      _shared = e.shared;
      _allDay = e.allDay;
      _time = Duration(hours: e.start.hour, minutes: e.start.minute);
      _repeat = e.recurrence;
      _remind
        ..clear()
        ..addAll(e.reminders.offsetsMin);
      if (spanDays(e) > 1) _endDay = dayOf(e.end!);
      return;
    }
    final now = _now;
    final sameDay = dayOf(now) == dayOf(widget.day);
    // Today: the next full hour; another day: 10:00.
    _time = sameDay && now.hour < 23
        ? Duration(hours: now.hour + 1)
        : const Duration(hours: 10);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _add() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final pair = ref.read(pairProvider);
    final store = ref.read(calendarProvider);
    final repo = CalendarRepo(store.replica);
    final now = _now;
    final d = dayOf(widget.day);
    final start = _allDay ? d : d.add(_time);
    final note = _note.text.trim();
    final endDay = _endDay;
    final end =
        endDay != null && dayOf(endDay).isAfter(d) ? dayOf(endDay) : null;
    final reminders = ReminderRules(
        kReminderChoices.map((c) => c.$1).where(_remind.contains).toList());
    final was = widget.editing;
    final CalEvent e;
    if (was == null) {
      e = CalEvent(
        id: 'evt-${now.microsecondsSinceEpoch}',
        title: title,
        start: start,
        end: end,
        allDay: _allDay,
        recurrence: _repeat,
        reminders: reminders,
        note: note.isEmpty ? null : note,
        ownerId: pair.myDeviceId,
        createdAt: now.millisecondsSinceEpoch,
        shared: _shared,
      );
      repo.upsert(e);
    } else {
      // Keep what the form doesn't show: id, author, place, invite.
      e = CalEvent(
        id: was.id,
        title: title,
        start: start,
        end: end,
        allDay: _allDay,
        locationName: was.locationName,
        lat: was.lat,
        lng: was.lng,
        timezone: was.timezone,
        recurrence: _repeat,
        reminders: reminders,
        inviteStatus: was.inviteStatus,
        ownerColor: was.ownerColor,
        note: note.isEmpty ? null : note,
        ownerId: was.ownerId,
        createdAt: was.createdAt,
        editedBy: pair.myDeviceId,
        editedAt: now.millisecondsSinceEpoch,
        shared: _shared,
      );
      repo.edit(e);
      MsNotifications.cancelEvent(e.id).catchError((_) {});
    }
    store.persist();
    MsNotifications.scheduleEvent(
      id: e.id,
      title: e.title,
      start: e.start,
      offsetsMin: e.reminders.offsetsMin,
    ).catchError((_) {});
    Navigator.of(context).pop();
    MsToast.show(
        context,
        was == null
            ? 'Добавлено. У ${pair.partner.nameGenitive} появится после синка'
            : 'Сохранено');
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(
            top: MsSize.formLabelTop, bottom: MsSize.formLabelGap),
        child: MsEyebrow(text),
      );

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final h = _time.inHours, m = _time.inMinutes % 60;
    final timeLabel = formatTime(DateTime(2000, 1, 1, h, m));
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MsMeta(dayHeading(widget.day)),
          _label('Название'),
          SizedBox(
            height: MsSize.fieldH,
            child: TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: MsText.body.copyWith(color: ms.ink),
              decoration:
                  const InputDecoration(hintText: 'Например: ужин в «Пушкине»'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _add(),
            ),
          ),
          _label('Чьё'),
          MsSegmented<bool>(
            segments: const [
              MsSegment(false, 'Моё'),
              MsSegment(true, 'Вместе')
            ],
            value: _shared,
            onChanged: (v) => setState(() => _shared = v),
          ),
          _label('Когда'),
          Wrap(
            spacing: MsSpace.space2,
            runSpacing: MsSpace.space2,
            children: [
              MsChip(
                label: 'весь день',
                selected: _allDay,
                onTap: () => setState(() {
                  _allDay = !_allDay;
                  if (_allDay) _pickTime = false;
                }),
              ),
              if (!_allDay)
                MsChip(
                  label: timeLabel,
                  selected: _pickTime,
                  onTap: () => setState(() => _pickTime = !_pickTime),
                ),
              MsChip(
                label: _endDay == null
                    ? 'несколько дней'
                    : 'до ${formatDayMonth(_endDay!)}',
                selected: _endDay != null,
                onTap: () => setState(() => _endDay = _endDay == null
                    ? dayOf(widget.day).add(const Duration(days: 1))
                    : null),
              ),
            ],
          ),
          if (_endDay != null) ...[
            const SizedBox(height: MsSpace.space2),
            MsDateWheel(
              initial: _endDay!,
              firstYear: widget.day.year,
              years: 3,
              onChanged: (d) => setState(() => _endDay = d),
            ),
          ],
          if (_pickTime && !_allDay)
            SizedBox(
              height: MsSize.timePickerH,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle:
                        MsText.numberMd.copyWith(color: ms.ink),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  minuteInterval: 5,
                  initialDateTime: DateTime(2000, 1, 1, h, m - m % 5),
                  onDateTimeChanged: (t) => setState(
                      () => _time = Duration(hours: t.hour, minutes: t.minute)),
                ),
              ),
            ),
          _label('Повторять'),
          Wrap(
            spacing: MsSpace.space2,
            runSpacing: MsSpace.space2,
            children: [
              for (final (r, label) in const [
                (Recurrence.none, 'нет'),
                (Recurrence.weekly, 'каждую неделю'),
                (Recurrence.monthly, 'каждый месяц'),
                (Recurrence.yearly, 'каждый год'),
              ])
                MsChip(
                  label: label,
                  selected: _repeat == r,
                  onTap: () => setState(() => _repeat = r),
                ),
            ],
          ),
          _label('Напомнить'),
          Wrap(
            spacing: MsSpace.space2,
            runSpacing: MsSpace.space2,
            children: [
              for (final (min, label) in kReminderChoices)
                MsChip(
                  label: label,
                  selected: _remind.contains(min),
                  onTap: () => setState(() => _remind.contains(min)
                      ? _remind.remove(min)
                      : _remind.add(min)),
                ),
            ],
          ),
          _label('Заметка'),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            style: MsText.body.copyWith(color: ms.ink),
            decoration: const InputDecoration(hintText: 'Необязательно'),
          ),
          const SizedBox(height: MsSpace.space5),
          if (widget.editing != null &&
              widget.editing!.recurrence != Recurrence.none) ...[
            const MsMeta('изменения коснутся всех повторов'),
            const SizedBox(height: MsSpace.space2),
          ],
          MsButton(
            label: widget.editing == null ? 'Добавить событие' : 'Сохранить',
            expand: true,
            onPressed: _title.text.trim().isEmpty ? null : _add,
          ),
        ],
      ),
    );
  }
}
