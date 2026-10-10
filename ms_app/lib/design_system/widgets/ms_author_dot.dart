import 'package:flutter/widgets.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';
import 'ms_author.dart';

/// 8 px author dot. Shared → a 13 px pill split into two halves.
class MsAuthorDot extends StatelessWidget {
  const MsAuthorDot(this.author, {super.key});

  final MsAuthor author;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final both = author == MsAuthor.both;
    return SizedBox(
      width: both ? MsSize.authorDotBothW : MsSize.authorDot,
      height: MsSize.authorDot,
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
