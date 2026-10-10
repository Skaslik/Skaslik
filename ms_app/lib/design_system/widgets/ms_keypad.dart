import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';

/// PIN dots: filled `ink` for entered digits, a 1.5 px `inkMuted` ring for
/// the rest.
class MsPinDots extends StatelessWidget {
  const MsPinDots({super.key, required this.filled, this.length = 4});

  final int filled;
  final int length;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return Semantics(
      label: 'Введено цифр: $filled из $length',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: MsSize.pinDotGap,
        children: [
          for (var i = 0; i < length; i++)
            Container(
              width: MsSize.pinDot,
              height: MsSize.pinDot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? ms.ink : null,
                border: i < filled
                    ? null
                    : Border.all(color: ms.inkMuted, width: MsSize.pinDotRing),
              ),
            ),
        ],
      ),
    );
  }
}

/// 3 × 4 keypad of 76 px `surface` circles with mono 30 digits. The bottom
/// row is biometrics (no fill), 0, and erase (no fill).
class MsKeypad extends StatelessWidget {
  const MsKeypad({
    super.key,
    required this.onDigit,
    required this.onBack,
    this.onBiometric,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBack;

  /// Shown only when biometrics can be used.
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    Widget key(Widget child,
            {required String label, VoidCallback? onTap, bool filled = true}) =>
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: SizedBox.square(
            dimension: MsSize.key,
            child: onTap == null
                ? null
                : Material(
                    color: filled ? ms.surface : Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap();
                      },
                      child: Center(child: child),
                    ),
                  ),
          ),
        );
    Widget digit(String d) => key(
          Text(d, style: MsTextX.keyDigit.copyWith(color: ms.ink)),
          label: d,
          onTap: () => onDigit(d),
        );
    Widget row(List<Widget> keys) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: MsSize.keyGapH,
          children: keys,
        );
    final bio = onBiometric;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: MsSize.keyGapV,
      children: [
        row([digit('1'), digit('2'), digit('3')]),
        row([digit('4'), digit('5'), digit('6')]),
        row([digit('7'), digit('8'), digit('9')]),
        row([
          key(
            Icon(Symbols.fingerprint_rounded,
                size: MsSize.keyBioIcon, color: ms.ink),
            label: 'Войти по отпечатку',
            onTap: bio,
            filled: false,
          ),
          digit('0'),
          key(
            Icon(Symbols.backspace_rounded,
                size: MsSize.keyBackIcon, color: ms.ink),
            label: 'Стереть',
            onTap: onBack,
            filled: false,
          ),
        ]),
      ],
    );
  }
}
