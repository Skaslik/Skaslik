import 'package:flutter/material.dart';

import '../../design_system/ms_theme.dart';

/// Small candle for the status row (22 × 35, the prototype's `.crow` SVG):
/// wax, wick and — while lit — a flame with the `glowCandle` halo.
class CandleIcon extends StatelessWidget {
  const CandleIcon({super.key, required this.lit});

  final bool lit;

  static const Size size = Size(22, 35);

  /// Flame centre in icon coordinates, and the halo around it.
  static const Offset _flameCenter = Offset(11, 12);
  static const double _haloR = 14;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return SizedBox.fromSize(
      size: size,
      child: Stack(clipBehavior: Clip.none, children: [
        if (lit)
          Positioned(
            left: _flameCenter.dx - _haloR,
            top: _flameCenter.dy - _haloR,
            width: _haloR * 2,
            height: _haloR * 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // The glowCandle token's colour as a soft radial halo.
                gradient: RadialGradient(colors: [
                  context.msShadows.glowCandle.first.color,
                  context.msShadows.glowCandle.first.color.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
        Positioned.fill(
          child: CustomPaint(
            painter: _CandlePainter(
              lit: lit,
              wax: ms.candleWax,
              wick: ms.dogCoat,
              flame: ms.candleFlame,
            ),
          ),
        ),
      ]),
    );
  }
}

class _CandlePainter extends CustomPainter {
  const _CandlePainter({
    required this.lit,
    required this.wax,
    required this.wick,
    required this.flame,
  });

  final bool lit;
  final Color wax;
  final Color wick;
  final Color flame;

  // Prototype viewBox: -30 -78 60 96.
  static const Rect _view = Rect.fromLTWH(-30, -78, 60, 96);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _view.width, size.height / _view.height);
    canvas.translate(-_view.left, -_view.top);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-8, -32, 16, 32), const Radius.circular(3)),
      Paint()..color = wax,
    );
    canvas.drawLine(
      const Offset(0, -33),
      const Offset(0, -38),
      Paint()
        ..color = wick
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    if (lit) {
      final p = Path()
        ..moveTo(0, -64)
        ..cubicTo(7, -54, 9, -46, 6.5, -41)
        ..cubicTo(4.5, -37, -4.5, -37, -6.5, -41)
        ..cubicTo(-9, -46, -7, -54, 0, -64)
        ..close();
      canvas.drawPath(p, Paint()..color = flame);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.lit != lit || old.wax != wax || old.flame != flame || old.wick != wick;
}
