import 'package:flutter/material.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';

/// Open a bottom sheet: `ground`, radius 20 at the top, 36×4 grab handle,
/// `scrim` behind. Forms and details open this way (screens.md).
///
/// Pass `dismissible: false` while a form holds input, so a stray swipe
/// doesn't lose it.
Future<T?> showMsSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool dismissible = true,
}) {
  final ms = context.ms;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ms.ground,
    barrierColor: ms.scrim,
    elevation: 0,
    isDismissible: dismissible,
    enableDrag: dismissible,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(MsRadius.radiusLg)),
    ),
    builder: (ctx) => MsSheetFrame(title: title, child: builder(ctx)),
  );
}

/// 36×4 grab handle in `line`.
class MsGrabHandle extends StatelessWidget {
  const MsGrabHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MsSize.grabW,
      height: MsSize.grabH,
      decoration: BoxDecoration(
        color: context.ms.line,
        borderRadius: BorderRadius.circular(MsSize.grabRadius),
      ),
    );
  }
}

/// Sheet body: grab handle, optional `title`, then [child]. Keeps clear of
/// the keyboard and the system navigation bar.
class MsSheetFrame extends StatelessWidget {
  const MsSheetFrame({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom;
    final t = title;
    return Padding(
      padding: EdgeInsets.fromLTRB(MsSize.sheetPadH, MsSize.sheetPadTop,
          MsSize.sheetPadH, MsSize.sheetPadBottom + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: MsGrabHandle()),
          const SizedBox(height: MsSize.grabGap),
          if (t != null) ...[
            Text(t, style: MsText.title.copyWith(color: context.ms.ink)),
            const SizedBox(height: MsSpace.space3),
          ],
          Flexible(child: child),
        ],
      ),
    );
  }
}
