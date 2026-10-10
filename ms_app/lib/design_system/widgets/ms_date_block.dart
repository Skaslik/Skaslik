import 'package:flutter/widgets.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';

/// 48 px date block left of an event: mono number over an upper-case
/// sub-label («8» / «СЕГОДНЯ», «24» / «ПТ»).
class MsDateBlock extends StatelessWidget {
  const MsDateBlock({super.key, required this.day, required this.sub});

  final String day;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return SizedBox(
      width: MsSize.dateBlockW,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: MsText.dateNum.copyWith(color: ms.ink),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
          const SizedBox(height: MsSize.dateSubGap),
          // «СЕГОДНЯ» is a little wider than 48 px; like the CSS, let it
          // overflow centred instead of wrapping.
          SizedBox(
            height: MsSize.dateSubH,
            child: OverflowBox(
              maxWidth: double.infinity,
              child: Text(
                sub.toUpperCase(),
                style: MsTextX.dateSub.copyWith(color: ms.inkMuted),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
