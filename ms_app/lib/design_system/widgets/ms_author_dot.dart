import 'package:flutter/widgets.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';
import 'ms_author.dart';

/// 8 px author dot. Shared → a 13 px pill split into two halves.
class MsAuthorDot extends StatelessWidget {
  const MsAuthorDot(this.author, {super.key, this.size = MsSize.authorDot});

  final MsAuthor author;

  /// Diameter; the shared pill keeps its 13 : 8 proportion.
  final double size;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final both = author == MsAuthor.both;
    return SizedBox(
      width: both ? size * MsSize.authorDotBothW / MsSize.authorDot : size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: both ? null : author.color(ms),
          gradient: author.halves(ms, axis: Axis.horizontal),
          borderRadius: BorderRadius.circular(MsRadius.radiusPill),
        ),
      ),
    );
  }
}
