import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import '../banks/banks_screen.dart';
import '../cards/cards_screen.dart';
import '../notes/notes_screen.dart';

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
/// control. Until Phase 6 each segment shows the old screen.
class TogetherScreen extends StatelessWidget {
  const TogetherScreen({super.key, required this.seg});

  final TogetherSeg seg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            MsSpace.space4,
            MediaQuery.paddingOf(context).top + MsSpace.space1,
            MsSpace.space4,
            MsSpace.space2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MsSpace.space4,
            children: [
              const MsScreenHeader(eyebrow: 'наше общее', title: 'Вместе'),
              MsSegmented<TogetherSeg>(
                segments: [
                  for (final s in TogetherSeg.values) MsSegment(s, s.label),
                ],
                value: seg,
                onChanged: (s) => context.go('/together?seg=${s.name}'),
              ),
            ],
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: switch (seg) {
              TogetherSeg.banks => const BanksScreen(),
              TogetherSeg.lists => const NotesScreen(),
              TogetherSeg.cards => const CardsScreen(),
            },
          ),
        ),
      ],
    );
  }
}
