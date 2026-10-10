import 'package:flutter/material.dart';

import '../ms_tokens.dart';

/// The family's mark — the icon file, never re-typed (brand-book «Знак»).
class MsMonogram extends StatelessWidget {
  const MsMonogram({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
          size >= 96 ? MsRadius.radiusLg : MsRadius.radiusSm),
      child: Image.asset(
        'assets/logo/ms-icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: 'МС',
      ),
    );
  }
}
