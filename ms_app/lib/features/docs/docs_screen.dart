import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/sync/domain_store.dart';
import '../../design_system/ms_theme.dart';

/// Документы: общий список файлов (метаданные). На S4 — загрузка в S3/Я.Диск,
/// сканер, теги, приватные папки. Сейчас — local-first реестр.
class DocsScreen extends ConsumerWidget {
  const DocsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(docsProvider);
    final files = store.view().entries
        .where((e) => e.key.startsWith('doc-'))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Документы')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDoc(context, store),
        icon: const Icon(Icons.add),
        label: const Text('Файл'),
      ),
      body: files.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(MsTokens.spaceLg),
                child: Text(MsEmpty.docs,
                    textAlign: TextAlign.center, style: MsTypography.body),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(MsTokens.spaceMd),
              itemCount: files.length,
              itemBuilder: (context, i) {
                final id = files[i].key.substring(4);
                final f = files[i].value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: MsTokens.spaceSm),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file,
                          color: MsColors.accent),
                      title: Text(f['name'] ?? id,
                          style:
                              MsTypography.body.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: f['tags'] != null
                          ? Text(f['tags']!, style: MsTypography.caption)
                          : null,
                      trailing: IconButton(
                          icon:
                              const Icon(Icons.delete_outline, color: Colors.black38),
                          onPressed: () => store.remove(id)),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _addDoc(BuildContext context, MsStore store) async {
    final name = TextEditingController();
    final tags = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Новый документ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Название')),
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
                final n = name.text.trim();
                if (n.isEmpty) return;
                final id = 'doc-${DateTime.now().millisecondsSinceEpoch}';
                store.set(id, 'name', n);
                if (tags.text.trim().isNotEmpty) {
                  store.set(id, 'tags', tags.text.trim());
                }
                store.persist();
                Navigator.pop(context);
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }
}
