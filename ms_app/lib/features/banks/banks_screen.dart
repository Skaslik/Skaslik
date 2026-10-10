import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ms_core/ms_core.dart';

import '../../core/family/family.dart';
import '../../core/providers.dart';
import '../../core/sync/domain_store.dart';
import '../../design_system/ms_theme.dart';

/// Копилки: цели, вклады, прогресс, история.
class BanksScreen extends ConsumerWidget {
  const BanksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(banksProvider);
    final repo = BanksRepo(store.replica);
    final banks = repo.allBanks();
    return Scaffold(
      appBar: AppBar(title: const Text('Копилки')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addBank(context, repo, store),
        icon: const Icon(Icons.add),
        label: const Text('Копилка'),
      ),
      body: banks.isEmpty
          ? const Center(child: Text(MsEmpty.banks, style: MsTypography.body))
          : ListView.builder(
              padding: const EdgeInsets.all(MsTokens.spaceMd),
              itemCount: banks.length,
              itemBuilder: (context, i) {
                final b = banks[i];
                final st = repo.state(b.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: MsTokens.spaceSm),
                  child: _BankCard(
                    name: b.goalName,
                    current: st.current,
                    target: b.targetAmount,
                    progress: st.progress,
                    onDelete: () {
                      repo.removeBank(b.id);
                      store.persist();
                    },
                    onAdd: () => _contribute(context, repo, store, b.id),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _addBank(BuildContext context, BanksRepo repo, MsStore store) async {
    final name = TextEditingController();
    final target = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Новая копилка'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'На цель')),
              const SizedBox(height: 12),
              TextField(
                  controller: target,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Сумма, ₽')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                final n = name.text.trim();
                final t = int.tryParse(target.text.trim()) ?? 0;
                if (n.isEmpty || t <= 0) return;
                final id = 'bank-${DateTime.now().millisecondsSinceEpoch}';
                repo.createBank(PiggyBank(
                  id: id,
                  goalName: n,
                  targetAmount: t,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                ));
                store.persist();
                Navigator.pop(context);
              },
              child: const Text('Создать'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _contribute(BuildContext context, BanksRepo repo, MsStore store,
      String bankId) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Взнос'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Сумма, ₽')),
              const SizedBox(height: 12),
              TextField(
                  controller: note,
                  decoration: const InputDecoration(hintText: 'Комментарий')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                final a = int.tryParse(amount.text.trim()) ?? 0;
                if (a <= 0) return;
                repo.contribute(bankId, BankEntry(
                  id: 'c-${DateTime.now().millisecondsSinceEpoch}',
                  by: family.deviceId ?? 'local',
                  amount: a,
                  at: DateTime.now().millisecondsSinceEpoch,
                  note: note.text.trim().isEmpty ? null : note.text.trim(),
                ));
                store.persist();
                Navigator.pop(context);
              },
              child: const Text('Кинуть'),
            ),
          ],
        );
      },
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard(
      {required this.name,
      required this.current,
      required this.target,
      required this.progress,
      required this.onDelete,
      required this.onAdd});
  final String name;
  final int current;
  final int target;
  final double progress;
  final VoidCallback onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MsTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: MsTypography.title)),
                TextButton(onPressed: onAdd, child: const Text('Взнос')),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: MsColors.muted),
                  onPressed: onDelete,
                ),
            ]),
            const SizedBox(height: MsTokens.spaceXs),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: MsColors.accentSoft,
                valueColor: AlwaysStoppedAnimation(MsColors.accent),
              ),
            ),
            const SizedBox(height: MsTokens.spaceXs),
            Text(
              '$current / $target ₽',
              style: MsTypography.bodySm,
            ),
          ],
        ),
      ),
    );
  }
}
