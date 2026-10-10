import 'package:flutter/material.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';

enum MsButtonVariant {
  /// `flame` / `onFlame` — one per screen.
  primary,

  /// `surfaceRaised` with a 1 px `line` outline.
  secondary,

  /// Text only, in `link`.
  ghost,

  /// `danger` / `onDanger`, always behind a confirmation.
  danger,
}

enum MsButtonSize {
  /// 48 high, radius 14 (or a pill with [MsButton.pill]).
  regular,

  /// 36 high pill for in-row actions: «+ 1 000 ₽», «Беру».
  small,
}

/// Button. Labels start with a verb: «Добавить событие», «Зажечь свечу».
class MsButton extends StatelessWidget {
  const MsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = MsButtonVariant.primary,
    this.size = MsButtonSize.regular,
    this.icon,
    this.pill = false,
    this.expand = false,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final MsButtonVariant variant;
  final MsButtonSize size;
  final IconData? icon;

  /// Fully rounded regular button (the floating «Скан» / «Файл»).
  final bool pill;

  /// Fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final (bg, fg) = switch (variant) {
      MsButtonVariant.primary => (ms.flame, ms.onFlame),
      MsButtonVariant.secondary => (ms.surfaceRaised, ms.ink),
      MsButtonVariant.ghost => (Colors.transparent, ms.link),
      MsButtonVariant.danger => (ms.danger, ms.onDanger),
    };
    final small = size == MsButtonSize.small;
    final side = variant == MsButtonVariant.secondary
        ? BorderSide(color: ms.line, width: MsSize.hairline)
        : BorderSide.none;
    final OutlinedBorder shape = small || pill
        ? StadiumBorder(side: side)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MsRadius.radiusMd),
            side: side);
    final enabled = onPressed != null;
    final i = icon;

    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : MsAlpha.disabled,
        child: Material(
          color: bg,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              height: small ? MsSize.buttonSmH : MsSize.buttonH,
              width: expand ? double.infinity : null,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal:
                        small ? MsSize.buttonSmPadH : MsSize.buttonPadH),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: MsSize.buttonGap,
                  children: [
                    if (i != null)
                      Icon(i,
                          size: small ? MsSize.iconSm : MsSize.buttonIcon,
                          color: fg),
                    Text(
                      label,
                      style: (small ? MsTextX.buttonSm : MsTextX.button)
                          .copyWith(color: fg),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
