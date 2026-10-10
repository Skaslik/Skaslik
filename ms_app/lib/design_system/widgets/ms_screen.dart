import 'package:flutter/material.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';
import 'ms_eyebrow.dart';

/// Scrolling tab screen: real status bar above, 4 px below it, 16 px side
/// margins, 24 px at the bottom (`.ms-screen`).
class MsScreen extends StatelessWidget {
  const MsScreen({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        MsSpace.space4,
        MediaQuery.paddingOf(context).top + MsSpace.space1,
        MsSpace.space4,
        MsSpace.space6,
      ),
      children: children,
    );
  }
}

/// Screen header: mono [eyebrow] over a `screenTitle` [title]; round
/// [actions] (usually one [MsIconButton]) on the right of the title.
class MsScreenHeader extends StatelessWidget {
  const MsScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.actions = const [],
  });

  final String eyebrow;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MsEyebrow(eyebrow),
        const SizedBox(height: MsSize.screenTitleGap),
        Row(
          spacing: MsSize.headerActionGap,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: MsText.screenTitle.copyWith(color: context.ms.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ],
    );
  }
}

/// 40 px round `surface` button with one icon: «+», search, ‹ ›.
class MsIconButton extends StatelessWidget {
  const MsIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;

  /// Spoken label: «Добавить», «Поиск», «Следующий месяц».
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: ms.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: MsSize.iconButton,
            child: Icon(icon, size: MsSize.icon, color: ms.ink),
          ),
        ),
      ),
    );
  }
}
