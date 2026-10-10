import 'package:flutter/material.dart';

import '../ms_tokens.dart';

/// Large card: `surface`, radius 20, padding 16/20 (piggy bank, stats).
class MsCard extends StatelessWidget {
  const MsCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(
        vertical: MsSpace.space4, horizontal: MsSpace.space5),
    this.color,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Override the fill (e.g. the capsule card in the author's colour).
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MsRadius.radiusLg));
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, customBorder: shape, child: content);
    }
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: color ?? context.ms.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}
