import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';

/// Sync state, always shown as a glyph plus a word — never colour alone.
enum MsSyncKind {
  /// `●` синхр. — `success`.
  ok,

  /// `◐` ждут синка · N — `warn`.
  queue,

  /// `○` офлайн — `inkMuted`.
  offline,

  /// `✕` ошибка с причиной — `danger`.
  error,
}

/// Sync status pill (28 px) in the home sheet and «Мы → Синхронизация».
/// Tap = «Синхронизировать сейчас».
class MsSyncStatus extends StatelessWidget {
  const MsSyncStatus({
    super.key,
    required this.kind,
    required this.label,
    this.onTap,
  });

  final MsSyncKind kind;

  /// The word: «синхр.», «ждут синка · 3», «офлайн», «ошибка: нет сети».
  final String label;
  final VoidCallback? onTap;

  /// The glyph as text, for inline use in meta lines («◐ у Сони загорится
  /// при связи»). The pill itself paints the glyph, so it looks the same
  /// on every device whatever the fallback font.
  static String glyphOf(MsSyncKind kind) => switch (kind) {
        MsSyncKind.ok => '●',
        MsSyncKind.queue => '◐',
        MsSyncKind.offline => '○',
        MsSyncKind.error => '✕',
      };

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final glyphColor = switch (kind) {
      MsSyncKind.ok => ms.success,
      MsSyncKind.queue => ms.warn,
      MsSyncKind.offline => ms.inkMuted,
      MsSyncKind.error => ms.danger,
    };
    const shape = StadiumBorder();
    return Semantics(
      button: onTap != null,
      label: 'Синхронизация: $label',
      excludeSemantics: true,
      child: Material(
        color: ms.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: MsSize.syncH,
            child: Padding(
              padding: const EdgeInsets.only(
                  left: MsSize.syncPadL, right: MsSize.syncPadR),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: MsSize.syncGap,
                children: [
                  CustomPaint(
                    size: const Size.square(MsSize.syncGlyph),
                    painter: MsSyncGlyphPainter(kind, glyphColor),
                  ),
                  Text(label, style: MsTextX.sync.copyWith(color: ms.ink)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints ● ◐ ○ ✕ as shapes.
class MsSyncGlyphPainter extends CustomPainter {
  const MsSyncGlyphPainter(this.kind, this.color);

  final MsSyncKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = MsSize.syncGlyphStroke;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    switch (kind) {
      case MsSyncKind.ok:
        canvas.drawCircle(c, r, fill);
      case MsSyncKind.queue:
        canvas.drawCircle(c, r - stroke / 2, line);
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi / 2,
            math.pi, true, fill);
      case MsSyncKind.offline:
        canvas.drawCircle(c, r - stroke / 2, line);
      case MsSyncKind.error:
        final d = r - stroke;
        canvas.drawLine(c.translate(-d, -d), c.translate(d, d), line);
        canvas.drawLine(c.translate(d, -d), c.translate(-d, d), line);
    }
  }

  @override
  bool shouldRepaint(MsSyncGlyphPainter old) =>
      old.kind != kind || old.color != color;
}
