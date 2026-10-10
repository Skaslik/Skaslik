import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import 'banks_segment.dart';
import 'cards_segment.dart';
import 'lists_segment.dart';

/// Segments of «Вместе»; `?seg=` selects one.
enum TogetherSeg {
  banks('Копилки'),
  lists('Списки'),
  cards('Карты');

  const TogetherSeg(this.label);
  final String label;

  static TogetherSeg parse(String? name) =>
      values.where((s) => s.name == name).firstOrNull ?? banks;
}

/// «Вместе»: piggy banks, lists and loyalty cards behind one segmented
/// control (decision #3: cards live here, top-3 on Home).
class TogetherScreen extends StatelessWidget {
  const TogetherScreen({super.key, required this.seg});

  final TogetherSeg seg;

  static const Map<TogetherSeg, String> _addLabel = {
    TogetherSeg.banks: 'Новая копилка',
    TogetherSeg.lists: 'Новый список',
    TogetherSeg.cards: 'Новая карта',
  };

  @override
  Widget build(BuildContext context) {
    return MsScreen(children: [
      MsScreenHeader(
        eyebrow: 'наше общее',
        title: 'Вместе',
        actions: [
          MsIconButton(
            icon: Symbols.add_rounded,
            label: _addLabel[seg]!,
            onPressed: () => switch (seg) {
              TogetherSeg.banks => showNewBankSheet(context),
              TogetherSeg.lists => showNewListSheet(context),
              TogetherSeg.cards => showNewCardSheet(context),
            },
          ),
        ],
      ),
      const SizedBox(height: MsSpace.space4),
      MsSegmented<TogetherSeg>(
        segments: [for (final s in TogetherSeg.values) MsSegment(s, s.label)],
        value: seg,
        onChanged: (s) => context.go('/together?seg=${s.name}'),
      ),
      const SizedBox(height: MsSpace.space4),
      switch (seg) {
        TogetherSeg.banks => const BanksSegment(),
        TogetherSeg.lists => const ListsSegment(),
        TogetherSeg.cards => const CardsSegment(),
      },
    ]);
  }
}
