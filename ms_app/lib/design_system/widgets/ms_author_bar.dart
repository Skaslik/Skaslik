import 'package:flutter/widgets.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';
import 'ms_author.dart';

/// 3 px author bar beside an event or note. Shared → two halves, top
/// michael, bottom sofia.
///
/// Without [height] it fills the height its parent gives it (use inside a
/// stretched row, e.g. `MsRowCard(stretch: true)`).
class MsAuthorBar extends StatelessWidget {
  const MsAuthorBar(this.author, {super.key, this.height});

  final MsAuthor author;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return SizedBox(
      width: MsSize.authorBar,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: author == MsAuthor.both ? null : author.color(ms),
          gradient: author.halves(ms),
          borderRadius: BorderRadius.circular(MsSize.authorBarRadius),
        ),
      ),
    );
  }
}
