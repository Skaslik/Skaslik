import 'package:flutter/material.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';
import 'ms_eyebrow.dart';

/// Text action in `link`: «Календарь ›», «Все ›», «+ Добавить».
class MsLink extends StatelessWidget {
  const MsLink(this.label, {super.key, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(label, style: MsTextX.link.copyWith(color: context.ms.link)),
      ),
    );
  }
}

/// Section head: eyebrow on the left, an optional [MsLink] on the right,
/// baselines aligned (`.ms-sec-h`).
class MsSectionHeader extends StatelessWidget {
  const MsSectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.top = MsSpace.space6,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  /// Space above; the first section on a sheet uses less.
  final double top;

  @override
  Widget build(BuildContext context) {
    final a = action;
    final onA = onAction;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: MsSpace.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: MsEyebrow(title)),
          if (a != null && onA != null) MsLink(a, onTap: onA),
        ],
      ),
    );
  }
}
