import 'package:flutter/material.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';

/// List row: `surface`, radius 14, padding 12/16, 12 px gaps between
/// [children]. Content is at least 56 high, so a one-line row is 80 —
/// measured from the screen screenshots (reference CSS is content-box).
class MsRowCard extends StatelessWidget {
  const MsRowCard({
    super.key,
    required this.children,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.symmetric(
        vertical: MsSpace.space3, horizontal: MsSpace.space4),
    this.minHeight = MsSize.rowMinH,
    this.stretch = false,
    this.semanticLabel,
  });

  final List<Widget> children;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final double minHeight;

  /// Children fill the row height — lets an `MsAuthorBar` run along the
  /// whole row. Children then centre themselves vertically.
  final bool stretch;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MsRadius.radiusMd));
    Widget row = Row(
      crossAxisAlignment:
          stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
      spacing: MsSpace.space3,
      children: children,
    );
    if (stretch) row = IntrinsicHeight(child: row);
    Widget content = Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: row,
      ),
    );
    if (onTap != null || onLongPress != null) {
      content = InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: shape,
        child: content,
      );
    }
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: context.ms.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}
