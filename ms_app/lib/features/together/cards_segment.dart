import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';

/// Category → eyebrow word.
String cardCategoryWord(CardCategory c) => switch (c) {
      CardCategory.supermarket => 'супермаркет',
      CardCategory.pharmacy => 'аптека',
      CardCategory.fuel => 'заправка',
      CardCategory.cafe => 'кафе',
      CardCategory.other => 'другое',
    };

/// «Карты»: a 2-column grid; tap opens the card at the checkout, long
/// press offers favourite (top-3 on Home) and delete.
class CardsSegment extends ConsumerWidget {
  const CardsSegment({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final cards = CardsRepo(ref.watch(cardsProvider).replica).all();
    if (cards.isEmpty) {
      return MsRowCard(children: [
        Expanded(
          child: Text('Пока нет карт. Добавь первую — пригодится на кассе.',
              style: MsText.bodySm.copyWith(color: ms.inkMuted)),
        ),
      ]);
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: MsSize.cardGridGap,
      crossAxisSpacing: MsSize.cardGridGap,
      childAspectRatio: _ratio(context),
      children: [
        for (final c in cards)
          _CardTile(card: c, pair: pair),
      ],
    );
  }

  // Fixed 112 px tiles whatever the width.
  double _ratio(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width -
            MsSpace.space4 * 2 -
            MsSize.cardGridGap) /
        2;
    return w / MsSize.cardGridH;
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.pair});
  final LoyaltyCard card;
  final Pair pair;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final by = pair.memberOf(card.addedBy);
    final who = pair.isMine(card.addedBy) ? 'ты' : by.name;
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MsRadius.radiusLg));
    return Semantics(
      button: true,
      label: 'Карта ${card.merchantName}, ${by.verb('добавил')} $who'
          '${card.favorite ? ', в избранном' : ''}',
      excludeSemantics: true,
      child: Material(
        color: ms.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/card/${card.id}'),
          onLongPress: () => showCardActions(context, card),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: MsSpace.space4, vertical: MsSize.cardGridPadV),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Expanded(child: MsEyebrow(cardCategoryWord(card.category))),
                  if (card.favorite)
                    Icon(Symbols.star_rounded,
                        size: MsSize.iconSm, color: ms.flame, fill: 1),
                ]),
                Text(card.merchantName,
                    style: MsText.titleSm.copyWith(color: ms.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                MsMeta('${by.verb('добавил')} $who', author: by.author),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Long press: favourite or delete.
Future<void> showCardActions(BuildContext context, LoyaltyCard card) =>
    showMsSheet<void>(context,
        title: card.merchantName, builder: (_) => _CardActions(card: card));

class _CardActions extends ConsumerWidget {
  const _CardActions({required this.card});
  final LoyaltyCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(pairProvider);
    final store = ref.read(cardsProvider);
    final repo = CardsRepo(store.replica);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MsButton(
          label: card.favorite ? 'Убрать из «под рукой»' : 'Держать под рукой',
          variant: MsButtonVariant.secondary,
          icon: Symbols.star_rounded,
          expand: true,
          onPressed: () {
            repo.upsert(LoyaltyCard(
              id: card.id,
              merchantName: card.merchantName,
              category: card.category,
              barcodeType: card.barcodeType,
              barcodeValue: card.barcodeValue,
              cardNumber: card.cardNumber,
              note: card.note,
              favorite: !card.favorite,
              lastUsed: card.lastUsed,
              addedBy: card.addedBy,
            ));
            store.persist();
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: MsSpace.space2),
        MsButton(
          label: 'Удалить карту',
          variant: MsButtonVariant.danger,
          expand: true,
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Удалить «${card.merchantName}»?'),
                content: Text(
                    'У ${pair.partner.nameGenitive} карта тоже исчезнет после синка.'),
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
            repo.remove(card.id);
            store.persist();
            Navigator.of(context).pop();
            MsToast.show(context, 'Карта удалена');
          },
        ),
      ],
    );
  }
}

/// «Новая карта»: shop, number, category. 12 digits get their EAN-13
/// check digit; anything else is shown as QR.
Future<void> showNewCardSheet(BuildContext context) => showMsSheet<void>(
    context, title: 'Новая карта', builder: (_) => const _NewCardSheet());

class _NewCardSheet extends ConsumerStatefulWidget {
  const _NewCardSheet();
  @override
  ConsumerState<_NewCardSheet> createState() => _NewCardSheetState();
}

class _NewCardSheetState extends ConsumerState<_NewCardSheet> {
  final _name = TextEditingController();
  final _number = TextEditingController();
  CardCategory _cat = CardCategory.supermarket;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  void _add() {
    final name = _name.text.trim();
    var value = _number.text.replaceAll(' ', '').trim();
    if (name.isEmpty || value.isEmpty) return;
    final digits = RegExp(r'^\d+$').hasMatch(value);
    if (digits && value.length == 12) value = completeEan13(value);
    final ean = digits && value.length == 13 && isValidEan13(value);
    final pair = ref.read(pairProvider);
    final store = ref.read(cardsProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    CardsRepo(store.replica).upsert(LoyaltyCard(
      id: 'card-$now',
      merchantName: name,
      category: _cat,
      barcodeType: ean ? BarcodeType.ean13 : BarcodeType.qr,
      barcodeValue: value,
      addedBy: pair.myDeviceId,
    ));
    store.persist();
    Navigator.of(context).pop();
    MsToast.show(context,
        'Карта добавлена. У ${pair.partner.nameGenitive} появится после синка');
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(
              top: MsSize.formLabelTop, bottom: MsSize.formLabelGap),
          child: MsEyebrow(t),
        );
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label('Магазин'),
          SizedBox(
            height: MsSize.fieldH,
            child: TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: MsText.body.copyWith(color: ms.ink),
              decoration: const InputDecoration(hintText: 'Например: Пятёрочка'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          label('Номер под штрихкодом'),
          SizedBox(
            height: MsSize.fieldH,
            child: TextField(
              controller: _number,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z ]')),
              ],
              style: MsText.numberMd.copyWith(color: ms.ink),
              decoration: const InputDecoration(hintText: '4 601234 567893'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          label('Что это'),
          Wrap(spacing: MsSpace.space2, runSpacing: MsSpace.space2, children: [
            for (final c in CardCategory.values)
              MsChip(
                label: cardCategoryWord(c),
                selected: _cat == c,
                onTap: () => setState(() => _cat = c),
              ),
          ]),
          const SizedBox(height: MsSpace.space2),
          const MsMeta('сканер камеры появится позже — пока номер руками',
              maxLines: 2),
          const SizedBox(height: MsSpace.space5),
          MsButton(
            label: 'Добавить карту',
            expand: true,
            onPressed: _name.text.trim().isNotEmpty &&
                    _number.text.trim().isNotEmpty
                ? _add
                : null,
          ),
        ],
      ),
    );
  }
}
