import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/notify/notifications.dart';
import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import 'add_event_sheet.dart';
import 'calendar_model.dart';

/// Opens an event: when, whose, reminders, note — and «Удалить».
Future<void> showEventSheet(BuildContext context, CalEvent e, DateTime occ) =>
    showMsSheet<void>(
      context,
      title: e.title,
      builder: (_) => EventSheet(event: e, occ: occ),
    );

class EventSheet extends ConsumerWidget {
  const EventSheet({super.key, required this.event, required this.occ});

  final CalEvent event;
  final DateTime occ;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final e = event;
    final reminders = [
      for (final (min, label) in kReminderChoices)
        if (e.reminders.offsetsMin.contains(min)) label,
    ];
    Widget line(String eyebrow, String text) => Padding(
          padding: const EdgeInsets.only(top: MsSize.formLabelTop),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: MsSize.formLabelGap,
            children: [
              MsEyebrow(eyebrow),
              Text(text, style: MsText.body.copyWith(color: ms.ink)),
            ],
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(spacing: MsSize.metaGap, children: [
          MsAuthorBar(eventAuthor(e, pair), height: MsSpace.space4),
          Expanded(
            child: MsMeta(eventMetaLine(e, occ, pair, DateTime.now()),
                maxLines: 2),
          ),
        ]),
        line(
          'Когда',
          [
            dayHeading(occ),
            if (!e.allDay && spanDays(e) == 1) formatTime(occ),
            if (repeatWord(e.recurrence) case final r?) r,
          ].join(' · '),
        ),
        if (reminders.isNotEmpty) line('Напомнить', reminders.join(', ')),
        if (e.note != null) line('Заметка', e.note!),
        const SizedBox(height: MsSpace.space6),
        MsButton(
          label: 'Изменить событие',
          variant: MsButtonVariant.secondary,
          expand: true,
          onPressed: () {
            // The page under this sheet opens the edit sheet.
            final under = Navigator.of(context, rootNavigator: true).context;
            Navigator.of(context).pop();
            showEditEventSheet(under, e);
          },
        ),
        const SizedBox(height: MsSpace.space2),
        MsButton(
          label: 'Удалить событие',
          variant: MsButtonVariant.danger,
          expand: true,
          onPressed: () => _confirmDelete(context, ref, pair),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Pair pair) async {
    final ok = await confirmDanger(context,
        title: 'Удалить «${event.title}»?',
        body: 'У ${pair.partner.nameGenitive} оно тоже исчезнет после синка.'
            '${event.recurrence == Recurrence.none ? '' : ' Удалятся все повторы.'}',
        action: 'Удалить');
    if (!ok || !context.mounted) return;
    final store = ref.read(calendarProvider);
    CalendarRepo(store.replica).remove(event.id);
    store.persist();
    MsNotifications.cancelEvent(event.id).catchError((_) {});
    Navigator.of(context).pop();
    MsToast.show(context, 'Событие удалено');
  }
}
