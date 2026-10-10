import 'package:flutter/widgets.dart';

import '../ms_tokens.dart';

/// Section eyebrow: mono 11, always upper-case, +0.08em, `inkMuted`.
/// «СЕГОДНЯ · ЧЕТВЕРГ, 8 ОКТЯБРЯ».
class MsEyebrow extends StatelessWidget {
  const MsEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: MsText.eyebrow.copyWith(color: color ?? context.ms.inkMuted),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
