import 'package:flutter/widgets.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';

enum MsBadgeTone {
  /// «истекает через 54 дня» — `warn` with `onWarn`.
  warn,

  /// «срок истёк» — `danger` with `onDanger`.
  danger,

  /// «+5 000 сегодня» — `flameSoft` with `ink`.
  flame,
}

/// 20 px mono pill that hugs its text (`.ms-badge`).
class MsBadge extends StatelessWidget {
  const MsBadge(this.text, {super.key, this.tone = MsBadgeTone.warn});

  final String text;
  final MsBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final (bg, fg) = switch (tone) {
      MsBadgeTone.warn => (ms.warn, ms.onWarn),
      MsBadgeTone.danger => (ms.danger, ms.onDanger),
      MsBadgeTone.flame => (ms.flameSoft, ms.ink),
    };
    return Container(
      height: MsSize.badgeH,
      padding: const EdgeInsets.symmetric(horizontal: MsSize.badgePadH),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MsRadius.radiusSm),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(text, style: MsTextX.badge.copyWith(color: fg)),
      ),
    );
  }
}
