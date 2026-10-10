import 'package:flutter/material.dart';

import '../../design_system/ms_theme.dart';

/// Кнопочная клавиатура для PIN (4–6 цифр).
///
/// Показывает точки-индикаторы введённых цифр и клавиши 1–9, ⌫, 0, OK.
/// Колбэк [onComplete] — когда набрано [length] цифр.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.length,
    required this.onComplete,
    this.title,
    this.subtitle,
    this.confirmEnabled = true,
  });

  final int length;
  final void Function(String pin) onComplete;
  final String? title;
  final String? subtitle;
  final bool confirmEnabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  late String _pin = '';

  void _tap(String d) {
    if (_pin.length >= widget.length) return;
    setState(() => _pin += d);
    if (_pin.length == widget.length) {
      final p = _pin;
      setState(() => _pin = '');
      widget.onComplete(p);
    }
  }

  void _del() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _key(String label, VoidCallback onTap,
          {bool primary = false}) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1.3,
        child: Material(
          color: primary ? MsColors.accent : MsColors.paperWarm,
          borderRadius: BorderRadius.circular(MsTokens.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(MsTokens.radiusMd),
            onTap: primary
                ? (widget.confirmEnabled ? onTap : null)
                : onTap,
            child: Center(
              child: Text(
                label,
                style: MsTypography.title.copyWith(
                  fontSize: 22,
                  color: primary ? MsColors.onAccent : MsColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.title != null) ...[
          Text(widget.title!,
              style: MsTypography.title, textAlign: TextAlign.center),
          const SizedBox(height: MsTokens.spaceXs),
        ],
        if (widget.subtitle != null) ...[
          Text(widget.subtitle!,
              style: MsTypography.bodySm, textAlign: TextAlign.center),
          const SizedBox(height: MsTokens.spaceMd),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.length; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? MsColors.accent : Colors.transparent,
                  border: Border.all(color: MsColors.accent, width: 1.5),
                ),
              ),
          ],
        ),
        const SizedBox(height: MsTokens.spaceLg),
        for (var row = 1; row <= 3; row++)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                for (var c = 0; c < 3; c++)
                  _key('${row * 3 + c + 1}', () => _tap('${row * 3 + c + 1}')),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              _key('⌫', _del),
              _key('0', () => _tap('0')),
              _key('OK', () {}, primary: true),
            ],
          ),
        ),
      ],
    );
  }
}
