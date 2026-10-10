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

/// Reminder choices (PLAN 5.3): за день / за час / за 15 мин.
const List<(int, String)> kReminderChoices = [
  (1440, 'за день'),
  (60, 'за час'),
  (15, 'за 15 мин'),
];

/// Default reminder, as preselected in the prototype.
const Set<int> kDefaultReminders = {1440};

class AddEventSheet extends ConsumerStatefulWidget {
  const AddEventSheet({super.key, required this.day, this.clock});

  final DateTime day;
  final DateTime Function()? clock;

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

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
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
    final now = _now;
    final d = dayOf(widget.day);
    final start = _allDay ? d : d.add(_time);
    final note = _note.text.trim();
    final e = CalEvent(
      id: 'evt-${now.microsecondsSinceEpoch}',
      title: title,
      start: start,
      allDay: _allDay,
      recurrence: _repeat,
      reminders: ReminderRules(
          kReminderChoices.map((c) => c.$1).where(_remind.contains).toList()),
      note: note.isEmpty ? null : note,
      ownerId: pair.myDeviceId,
      createdAt: now.millisecondsSinceEpoch,
      shared: _shared,
    );
    CalendarRepo(store.replica).upsert(e);
    store.persist();
    MsNotifications.scheduleEvent(
      id: e.id,
      title: e.title,
      start: e.start,
      offsetsMin: e.reminders.offsetsMin,
    ).catchError((_) {});
    Navigator.of(context).pop();
    MsToast.show(context,
        'Добавлено. У ${pair.partner.nameGenitive} появится после синка');
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
              decoration: const InputDecoration(
                  hintText: 'Например: ужин в «Пушкине»'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _add(),
            ),
          ),
          _label('Чьё'),
          MsSegmented<bool>(
            segments: const [MsSegment(false, 'Моё'), MsSegment(true, 'Вместе')],
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
            ],
          ),
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
                  onTap: () => setState(() =>
                      _remind.contains(min) ? _remind.remove(min) : _remind.add(min)),
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
          MsButton(
            label: 'Добавить событие',
            expand: true,
            onPressed: _title.text.trim().isEmpty ? null : _add,
          ),
        ],
      ),
    );
  }
}
