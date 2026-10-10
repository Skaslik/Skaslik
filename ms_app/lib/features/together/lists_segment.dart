import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';

/// «Списки»: the first (pinned) list open as a checklist card, the others
/// as rows. Each partner's ticks merge per item.
class ListsSegment extends ConsumerWidget {
  const ListsSegment({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = context.ms;
    final repo = NotesRepo(ref.watch(notesProvider).replica);
    final notes = repo.all();
    if (notes.isEmpty) {
      return MsRowCard(children: [
        Expanded(
          child: Text('Пока пусто. Заведи первый список — покупки, дела, «на дачу».',
              style: MsText.bodySm.copyWith(color: ms.inkMuted)),
        ),
      ]);
    }
    final first = notes.first;
    final rest = notes.skip(1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MsCard(
          padding: const EdgeInsets.all(MsSpace.space4),
          child: ChecklistCard(noteId: first.id),
        ),
        for (final n in rest) ...[
          const SizedBox(height: MsSpace.space2),
          MsRowCard(
            onTap: () => showListSheet(context, n.id),
            semanticLabel: '${n.title}, ${listSummary(repo.items(n.id))}',
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.title,
                      style: MsTextX.rowTitle.copyWith(color: ms.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: MsSize.rowMetaGap),
                  MsMeta(listSummary(repo.items(n.id))),
                ]),
              ),
              Icon(Symbols.chevron_right_rounded,
                  size: MsSize.icon, color: ms.inkFaint),
            ],
          ),
        ],
      ],
    );
  }
}

/// «12 пунктов · 4 отмечено», «пусто».
String listSummary(List<ChecklistItem> items) {
  if (items.isEmpty) return 'пусто';
  final done = items.where((i) => i.done).length;
  final n = items.length;
  return '$n ${ruPlural(n, 'пункт', 'пункта', 'пунктов')} · '
      '$done ${ruPlural(done, 'отмечен', 'отмечено', 'отмечено')}';
}

/// Title with «2 из 5», 44 px rows with a 22 px box, «+ Добавить пункт».
class ChecklistCard extends ConsumerStatefulWidget {
  const ChecklistCard({super.key, required this.noteId, this.showMore = true});
  final String noteId;

  /// The ⋯ that opens the list sheet (hidden inside that sheet).
  final bool showMore;

  @override
  ConsumerState<ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends ConsumerState<ChecklistCard> {
  bool _adding = false;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _add(Pair pair) {
    final t = _text.text.trim();
    if (t.isEmpty) {
      setState(() => _adding = false);
      return;
    }
    final store = ref.read(notesProvider);
    final now = DateTime.now().microsecondsSinceEpoch;
    NotesRepo(store.replica).addItem(widget.noteId,
        ChecklistItem(id: 'i$now', text: t, at: now ~/ 1000, by: pair.myDeviceId));
    store.persist();
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final store = ref.watch(notesProvider);
    final repo = NotesRepo(store.replica);
    final note = repo.get(widget.noteId);
    if (note == null) return const SizedBox.shrink();
    final items = repo.items(note.id);
    final done = items.where((i) => i.done).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(note.title,
                  style: MsText.titleSm.copyWith(color: ms.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (items.isNotEmpty) MsMeta('$done из ${items.length}'),
            if (widget.showMore)
              Padding(
                padding: const EdgeInsets.only(left: MsSpace.space2),
                child: Semantics(
                  button: true,
                  label: 'Список: закрепить или удалить',
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: () => showListSheet(context, note.id),
                    radius: MsSize.icon,
                    child: Icon(Symbols.more_horiz_rounded,
                        size: MsSize.icon, color: ms.inkFaint),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: MsSpace.space2),
        for (final it in items)
          _CheckRow(
            item: it,
            author: pair.memberOf(it.by).author,
            onToggle: () {
              repo.setDone(note.id, it.id,
                  done: !it.done,
                  by: pair.myDeviceId,
                  at: DateTime.now().millisecondsSinceEpoch);
              store.persist();
            },
            onRemove: () {
              repo.removeItem(note.id, it.id);
              store.persist();
              MsToast.show(context, '«${it.text}» убран из списка');
            },
          ),
        if (_adding)
          Padding(
            padding: const EdgeInsets.only(top: MsSpace.space1),
            child: SizedBox(
              height: MsSize.fieldH,
              child: TextField(
                controller: _text,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: MsText.body.copyWith(color: ms.ink),
                decoration: const InputDecoration(hintText: 'Что ещё?'),
                onSubmitted: (_) => _add(pair),
                onTapOutside: (_) => _add(pair),
              ),
            ),
          ),
        const SizedBox(height: MsSpace.space2),
        Align(
          alignment: Alignment.centerLeft,
          child: MsLink('+ Добавить пункт',
              onTap: () => setState(() => _adding = true)),
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.item,
    required this.author,
    required this.onToggle,
    required this.onRemove,
  });

  final ChecklistItem item;
  final MsAuthor author;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final done = item.done;
    return Semantics(
      checked: done,
      label: item.text,
      excludeSemantics: true,
      onLongPressHint: 'убрать из списка',
      child: InkWell(
        onTap: onToggle,
        onLongPress: onRemove,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MsSize.checkRowH),
          child: Row(spacing: MsSpace.space3, children: [
            Container(
              width: MsSize.checkBox,
              height: MsSize.checkBox,
              decoration: BoxDecoration(
                color: done ? ms.flame : null,
                border: Border.all(
                    color: done ? ms.flame : ms.inkMuted,
                    width: MsSize.checkBorder),
                borderRadius: BorderRadius.circular(MsSize.checkRadius),
              ),
              child: done
                  ? Icon(Symbols.check_rounded,
                      size: MsSize.checkIcon, color: ms.onFlame, weight: 700)
                  : null,
            ),
            Expanded(
              child: Text(
                item.text,
                style: MsText.body.copyWith(
                  color: done ? ms.inkMuted : ms.ink,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: ms.inkMuted,
                ),
              ),
            ),
            if (done) MsAuthorDot(author),
          ]),
        ),
      ),
    );
  }
}

/// A list in a sheet: its checklist, pin, delete.
Future<void> showListSheet(BuildContext context, String noteId) =>
    showMsSheet<void>(context, builder: (_) => _ListSheet(noteId: noteId));

class _ListSheet extends ConsumerWidget {
  const _ListSheet({required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(pairProvider);
    final store = ref.watch(notesProvider);
    final repo = NotesRepo(store.replica);
    final note = repo.get(noteId);
    if (note == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChecklistCard(noteId: noteId, showMore: false),
          const SizedBox(height: MsSpace.space5),
          MsButton(
            label: note.pinned ? 'Открепить' : 'Закрепить сверху',
            variant: MsButtonVariant.secondary,
            expand: true,
            onPressed: () {
              repo.upsert(Note(
                  id: note.id,
                  title: note.title,
                  tags: note.tags,
                  pinned: !note.pinned,
                  at: note.at));
              store.persist();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: MsSpace.space2),
          MsButton(
            label: 'Удалить список',
            variant: MsButtonVariant.danger,
            expand: true,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Удалить список «${note.title}»?'),
                  content: Text(
                      'У ${pair.partner.nameGenitive} он тоже исчезнет после синка.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Удалить',
                            style: MsTextX.link.copyWith(color: ctx.ms.danger))),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              repo.remove(note.id);
              store.persist();
              Navigator.of(context).pop();
              MsToast.show(context, 'Список удалён');
            },
          ),
        ],
      ),
    );
  }
}

/// «Новый список».
Future<void> showNewListSheet(BuildContext context) => showMsSheet<void>(
    context, title: 'Новый список', builder: (_) => const _NewListSheet());

class _NewListSheet extends ConsumerStatefulWidget {
  const _NewListSheet();
  @override
  ConsumerState<_NewListSheet> createState() => _NewListSheetState();
}

class _NewListSheetState extends ConsumerState<_NewListSheet> {
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _create() {
    final t = _title.text.trim();
    if (t.isEmpty) return;
    final store = ref.read(notesProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    NotesRepo(store.replica).upsert(Note(id: 'n$now', title: t, at: now));
    store.persist();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: MsSize.fieldH,
          child: TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: MsText.body.copyWith(color: ms.ink),
            decoration: const InputDecoration(hintText: 'Например: На выходные'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _create(),
          ),
        ),
        const SizedBox(height: MsSpace.space5),
        MsButton(
          label: 'Создать список',
          expand: true,
          onPressed: _title.text.trim().isEmpty ? null : _create,
        ),
      ],
    );
  }
}
