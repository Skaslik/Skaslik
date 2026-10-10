import 'dart:async';

import 'package:flutter/material.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';

/// Short confirmation above the tab bar: `ink` background, `ground` text,
/// radius 14, gone after 2.6 s. One at a time; a new toast replaces the old.
///
/// «Добавлено. У Софии появится после синка».
abstract final class MsToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  /// Show [message]. [bottom] overrides the distance from the screen's
  /// bottom edge (default: just above the tab bar).
  static void show(BuildContext context, String message, {double? bottom}) {
    hide();
    final overlay = Overlay.of(context, rootOverlay: true);
    final ms = context.ms;
    final offset = bottom ??
        MediaQuery.viewPaddingOf(context).bottom +
            MsSpace.tabbarH +
            MsSize.toastAboveTabbar;
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: MsSpace.space4,
        right: MsSpace.space4,
        bottom: offset,
        child: _ToastView(message: message, palette: ms),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(MsMotion.toast, hide);
  }

  /// Remove the current toast, if any.
  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.message, required this.palette});

  final String message;
  final MsPalette palette;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: MsMotion.base);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c.duration = MsMotion.of(context, MsMotion.base);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = widget.palette;
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(curve),
        child: Semantics(
          liveRegion: true,
          child: Material(
            color: ms.ink,
            borderRadius: BorderRadius.circular(MsRadius.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: MsSpace.space4, vertical: MsSize.toastPadV),
              child: Text(
                widget.message,
                style: MsTextX.toast.copyWith(color: ms.ground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
