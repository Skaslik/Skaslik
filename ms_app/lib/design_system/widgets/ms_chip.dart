import 'package:flutter/material.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';
import 'ms_author.dart';

/// 32 px filter chip with an optional mono count.
///
/// Selected → `ink` fill with `ground` text. A person chip ([person]) is
/// selected in that person's colour: soft fill plus a coloured outline.
class MsChip extends StatelessWidget {
  const MsChip({
    super.key,
    required this.label,
    this.count,
    this.selected = false,
    this.person,
    this.onTap,
  });

  final String label;
  final String? count;
  final bool selected;
  final MsAuthor? person;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final p = person;
    final personOn = selected && p != null && p != MsAuthor.both;
    final Color bg;
    final Color fg;
    final Color border;
    final Color countColor;
    if (personOn) {
      bg = p.soft(ms);
      fg = ms.ink;
      border = p.color(ms);
      countColor = ms.ink;
    } else if (selected) {
      bg = ms.ink;
      fg = ms.ground;
      border = ms.ink;
      countColor = ms.ground.withValues(alpha: MsAlpha.chipCountOn);
    } else {
      bg = Colors.transparent;
      fg = ms.ink;
      border = ms.line;
      countColor = ms.inkMuted;
    }
    final shape =
        StadiumBorder(side: BorderSide(color: border, width: MsSize.hairline));
    final c = count;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: bg,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: MsSize.chipH,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MsSize.chipPadH),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: MsSize.chipGap,
                children: [
                  Text(label, style: MsTextX.control.copyWith(color: fg)),
                  if (c != null)
                    Text(c, style: MsTextX.chipCount.copyWith(color: countColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
