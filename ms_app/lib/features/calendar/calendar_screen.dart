import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notify/notifications.dart';
import '../../core/providers.dart';
import '../../core/sync/domain_store.dart';
import '../../design_system/ms_theme.dart';
import 'package:ms_core/ms_core.dart';

/// Календарь: список событий + добавление.
///
/// Local-first: событие пишется в CRDT-реплику [MsStore], персистится и
/// отображается через доменную модель [CalEvent] (с учётом recurrence).
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(calendarProvider);
    final repo = CalendarRepo(store.replica);
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final events = repo.range(weekStart, weekEnd);

    return Scaffold(
      appBar: AppBar(title: const Text('Календарь')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEvent(context, store),
        icon: const Icon(Icons.add),
        label: const Text('Событие'),
      ),
      body: events.isEmpty
          ? const _Empty(icon: Icons.event, text: MsEmpty.calendar)
          : ListView.builder(
              padding: const EdgeInsets.all(MsTokens.spaceMd),
              itemCount: events.length,
              itemBuilder: (context, i) {
                final (event, occ) = events[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: MsTokens.spaceSm),
                  child: _EventCard(
                    title: event.title,
                    when: occ,
                    note: event.note,
                    recur: event.recurrence,
                    onDelete: () {
                      repo.remove(event.id);
                      store.persist();
                      MsNotifications.cancelEvent(event.id);
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> _addEvent(BuildContext context, MsStore store) async {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return _EventEditor(
          titleCtrl: titleCtrl,
          noteCtrl: noteCtrl,
          onSave: (ev) {
            final repo = CalendarRepo(store.replica);
            repo.upsert(ev);
            store.persist();
            // Запланировать напоминания (best-effort, без блокировки UI).
            MsNotifications.scheduleEvent(
              id: ev.id,
              title: ev.title,
              start: ev.start,
              offsetsMin: ev.reminders.offsetsMin,
            );
            Navigator.pop(ctx);
          },
        );
      },
    );
  }
}

/// Редактор события: название, дата, время, recurrence, заметка.
class _EventEditor extends StatefulWidget {
  const _EventEditor({
    required this.titleCtrl,
    required this.noteCtrl,
    required this.onSave,
  });
  final TextEditingController titleCtrl;
  final TextEditingController noteCtrl;
  final void Function(CalEvent ev) onSave;

  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  late DateTime _start = DateTime.now().add(const Duration(hours: 1));
  Recurrence _recur = Recurrence.none;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute));
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (t != null) {
      setState(() => _start = _start.copyWith(hour: t.hour, minute: t.minute));
    }
  }

  void _save() {
    final t = widget.titleCtrl.text.trim();
    if (t.isEmpty) return;
    final note = widget.noteCtrl.text.trim();
    final id = 'evt-${DateTime.now().millisecondsSinceEpoch}';
    widget.onSave(CalEvent(
      id: id,
      title: t,
      start: _start,
      recurrence: _recur,
      note: note.isEmpty ? null : note,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новое событие'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Название'),
            ),
            const SizedBox(height: MsTokens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_fmt(_start).split(' ').first),
                  ),
                ),
                const SizedBox(width: MsTokens.spaceSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(_fmt(_start).split(' ').last),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MsTokens.spaceMd),
            SegmentedButton<Recurrence>(
              segments: const [
                ButtonSegment(value: Recurrence.none, label: Text('Разовое')),
                ButtonSegment(value: Recurrence.daily, label: Text('День')),
                ButtonSegment(value: Recurrence.weekly, label: Text('Нед')),
                ButtonSegment(value: Recurrence.monthly, label: Text('Мес')),
                ButtonSegment(value: Recurrence.yearly, label: Text('Год')),
              ],
              selected: {_recur},
              onSelectionChanged: (s) => setState(() => _recur = s.first),
            ),
            const SizedBox(height: MsTokens.spaceMd),
            TextField(
              controller: widget.noteCtrl,
              decoration: const InputDecoration(hintText: 'Заметка'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: _save,
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: MsColors.accentSoft),
          const SizedBox(height: MsTokens.spaceSm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MsTokens.spaceLg),
            child: Text(text, textAlign: TextAlign.center, style: MsTypography.body),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard(
      {required this.title,
      required this.when,
      this.note,
      required this.recur,
      required this.onDelete});
  final String title;
  final DateTime when;
  final String? note;
  final Recurrence recur;
  final VoidCallback onDelete;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String? _recurLabel() => switch (recur) {
        Recurrence.daily => 'каждый день',
        Recurrence.weekly => 'каждую неделю',
        Recurrence.monthly => 'каждый месяц',
        Recurrence.yearly => 'каждый год',
        Recurrence.none => null,
      };

  @override
  Widget build(BuildContext context) {
    final label = _recurLabel();
    return Card(
      child: ListTile(
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            gradient: MsColors.sharedGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(title,
            style: MsTypography.body.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_fmt(when), style: MsTypography.caption),
            if (label != null) Text(label, style: MsTypography.caption),
            if (note != null) Text(note!, style: MsTypography.caption),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.black38),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Удалить событие?'),
              content: Text(title),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена')),
                FilledButton(
                    onPressed: () {
                      onDelete();
                      Navigator.pop(context);
                    },
                    child: const Text('Удалить')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
