import 'package:flutter/widgets.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';
import 'ms_author.dart';
import 'ms_author_dot.dart';

/// Mono meta line under a title: «19:30 · добавила София». With [author],
/// the author dot leads the line.
class MsMeta extends StatelessWidget {
  const MsMeta(
    this.text, {
    super.key,
    this.author,
    this.color,
    this.maxLines = 1,
  });

  final String text;
  final MsAuthor? author;
  final Color? color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: MsText.meta.copyWith(color: color ?? context.ms.inkMuted),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
    final a = author;
    if (a == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MsAuthorDot(a),
        const SizedBox(width: MsSize.metaGap),
        Flexible(child: label),
      ],
    );
  }
}
