import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ms_core/ms_core.dart';

import '../../core/providers.dart';
import '../../core/sync/domain_store.dart';
import '../../design_system/ms_theme.dart';

/// Заметки: общие, с тегами и закрепом.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(notesProvider);
    final repo = NotesRepo(store.replica);
    final notes = repo.all();
    return Scaffold(
      appBar: AppBar(title: const Text('Заметки')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNote(context, repo, store),
        icon: const Icon(Icons.add),
        label: const Text('Заметка'),
      ),
      body: notes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(MsTokens.spaceLg),
                child: Text('Пока пусто. Запишите первую мысль.',
                    textAlign: TextAlign.center, style: MsTypography.body),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(MsTokens.spaceMd),
              itemCount: notes.length,
              itemBuilder: (context, i) {
                final n = notes[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: MsTokens.spaceSm),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                          n.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                          color: n.pinned
                              ? MsColors.accent
                              : MsColors.muted),
                      title: Text(n.title,
                          style:
                              MsTypography.body.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: n.tags.isNotEmpty
                          ? Text(n.tags.join(' · '),
                              style: MsTypography.caption)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: Icon(Icons.push_pin_outlined,
                                  color: MsColors.muted),
                              onPressed: () {
                                repo.upsert(Note(
                                    id: n.id,
                                    title: n.title,
                                    tags: n.tags,
                                    pinned: !n.pinned,
                                    at: n.at));
                                store.persist();
                              }),
                          IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: MsColors.muted),
                              onPressed: () {
                                repo.remove(n.id);
                                store.persist();
                              }),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _addNote(BuildContext context, NotesRepo repo, MsStore store) async {
    final title = TextEditingController();
    final tags = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Новая заметка'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Текст')),
              const SizedBox(height: 12),
              TextField(
                  controller: tags,
                  decoration: const InputDecoration(
                      hintText: 'Теги (через запятую)')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                final t = title.text.trim();
                if (t.isEmpty) return;
                repo.upsert(Note(
                  id: 'note-${DateTime.now().millisecondsSinceEpoch}',
                  title: t,
                  tags: tags
                      .text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList(),
                  at: DateTime.now().millisecondsSinceEpoch,
                ));
                store.persist();
                Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }
}
