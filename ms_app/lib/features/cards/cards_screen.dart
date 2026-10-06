import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ms_core/ms_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/providers.dart';
import '../../core/sync/domain_store.dart';
import '../../design_system/ms_theme.dart';

/// Карты лояльности: список + добавление (ручной ввод / EAN-13).
class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(cardsProvider);
    final repo = CardsRepo(store.replica);
    final cards = repo.all();
    return Scaffold(
      appBar: AppBar(title: const Text('Карты лояльности')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCard(context, repo, store),
        icon: const Icon(Icons.add),
        label: const Text('Карта'),
      ),
      body: cards.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(MsTokens.spaceLg),
                child: Text(MsEmpty.cards,
                    textAlign: TextAlign.center, style: MsTypography.body),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(MsTokens.spaceMd),
              itemCount: cards.length,
              itemBuilder: (context, i) {
                final c = cards[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: MsTokens.spaceSm),
                  child: _CardTile(
                    merchant: c.merchantName,
                    value: c.barcodeValue,
                    type: c.barcodeType,
                    category: c.category,
                    favorite: c.favorite,
                    onToggle: () => _toggleFavorite(repo, store, c),
                    onDelete: () {
                      repo.remove(c.id);
                      store.persist();
                    },
                    onShow: () => _showBarcode(context, c),
                  ),
                );
              },
            ),
    );
  }

  void _showBarcode(BuildContext context, LoyaltyCard c) {
    final isQr = c.barcodeType == BarcodeType.qr;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Dialog(
        backgroundColor: MsColors.paper,
        child: Padding(
          padding: const EdgeInsets.all(MsTokens.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c.merchantName, style: MsTypography.title),
              const SizedBox(height: MsTokens.spaceMd),
              if (isQr)
                QrImageView(
                  data: c.barcodeValue,
                  version: QrVersions.auto,
                  size: 280,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                )
              else
                // EAN-13: показываем крупно цифры + QR-запасной вариант.
                Column(
                  children: [
                    Text(c.barcodeValue,
                        style: const TextStyle(
                            fontSize: 34,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: MsTokens.spaceMd),
                    QrImageView(
                      data: c.barcodeValue,
                      version: QrVersions.auto,
                      size: 200,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ],
                ),
              const SizedBox(height: MsTokens.spaceLg),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Закрыть')),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleFavorite(CardsRepo repo, MsStore store, LoyaltyCard c) {
    repo.upsert(LoyaltyCard(
      id: c.id,
      merchantName: c.merchantName,
      category: c.category,
      barcodeType: c.barcodeType,
      barcodeValue: c.barcodeValue,
      cardNumber: c.cardNumber,
      note: c.note,
      favorite: !c.favorite,
      lastUsed: c.lastUsed,
    ));
    store.persist();
  }

  Future<void> _addCard(BuildContext context, CardsRepo repo, MsStore store) async {
    final name = TextEditingController();
    final value = TextEditingController();
    var cat = CardCategory.supermarket;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Новая карта'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'Магазин')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: value,
                      decoration:
                          const InputDecoration(hintText: 'Штрихкод / номер')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CardCategory>(
                    initialValue: cat,
                    onChanged: (v) => setState(() => cat = v!),
                    decoration: const InputDecoration(labelText: 'Категория'),
                    items: [
                      for (final c in CardCategory.values)
                        DropdownMenuItem(value: c, child: Text(c.name)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена')),
                FilledButton(
                  onPressed: () {
                    final n = name.text.trim();
                    var v = value.text.trim();
                    if (n.isEmpty || v.isEmpty) return;
                    if (v.length == 12 &&
                        v.split('').every((ch) => ch.codeUnitAt(0) < 58)) {
                      v = completeEan13(v);
                    }
                    final id = 'card-${DateTime.now().millisecondsSinceEpoch}';
                    repo.upsert(LoyaltyCard(
                      id: id,
                      merchantName: n,
                      category: cat,
                      barcodeType:
                          v.length == 13 ? BarcodeType.ean13 : BarcodeType.qr,
                      barcodeValue: v,
                    ));
                    store.persist();
                    Navigator.pop(context);
                  },
                  child: const Text('Добавить'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile(
      {required this.merchant,
      required this.value,
      required this.type,
      required this.category,
      required this.favorite,
      required this.onToggle,
      required this.onDelete,
      required this.onShow});
  final String merchant;
  final String value;
  final BarcodeType type;
  final CardCategory category;
  final bool favorite;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          favorite ? Icons.star : Icons.star_border,
          color: favorite ? MsColors.accent : Colors.black38,
        ),
        title: Text(merchant,
            style: MsTypography.body.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text('$value · $type', style: MsTypography.caption),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.star_outline, color: Colors.black38),
                onPressed: onToggle),
            IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.black38),
                onPressed: onDelete),
          ],
        ),
        onTap: onShow,
      ),
    );
  }
}
