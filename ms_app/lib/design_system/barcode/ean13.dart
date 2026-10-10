/// EAN-13 for the checkout screen: digits → 95 modules, drawn by
/// [Ean13Painter]. Port of the prototype's `ean()`; the check digit comes
/// from `ms_core` (`ean13CheckDigit`).
library;

import 'package:flutter/rendering.dart';
import 'package:ms_core/ms_core.dart';

const List<String> _l = [
  '0001101', '0011001', '0010011', '0111101', '0100011',
  '0110001', '0101111', '0111011', '0110111', '0001011',
];
const List<String> _g = [
  '0100111', '0110011', '0011011', '0100001', '0011101',
  '0111001', '0000101', '0010001', '0001001', '0010111',
];
const List<String> _r = [
  '1110010', '1100110', '1101100', '1000010', '1011100',
  '1001110', '1010000', '1000100', '1001000', '1110100',
];
const List<String> _parity = [
  'LLLLLL', 'LLGLGG', 'LLGGLG', 'LLGGGL', 'LGLLGG',
  'LGGLLG', 'LGGGLL', 'LGLGLG', 'LGLGGL', 'LGGLGL',
];

/// 13 digits (12 are completed with the check digit), or null when the
/// value can't be an EAN-13.
String? ean13Digits(String value) {
  final v = value.replaceAll(' ', '');
  if (!RegExp(r'^\d{12,13}$').hasMatch(v)) return null;
  if (v.length == 12) return completeEan13(v);
  return isValidEan13(v) ? v : null;
}

/// The 95 modules (true = bar) of [digits13].
List<bool> ean13Modules(String digits13) {
  final d = digits13;
  final p = _parity[int.parse(d[0])];
  final bits = StringBuffer('101');
  for (var i = 1; i <= 6; i++) {
    bits.write((p[i - 1] == 'L' ? _l : _g)[int.parse(d[i])]);
  }
  bits.write('01010');
  for (var i = 7; i <= 12; i++) {
    bits.write(_r[int.parse(d[i])]);
  }
  bits.write('101');
  return [for (final c in bits.toString().split('')) c == '1'];
}

/// Guard modules (start, centre, end) run longer than the data bars.
bool ean13IsGuard(int module) =>
    module < 3 || (module >= 45 && module < 50) || module >= 92;

/// «4 601234 567893».
String ean13Pretty(String digits13) =>
    '${digits13[0]} ${digits13.substring(1, 7)} ${digits13.substring(7)}';

/// Draws the bars into [size] with [quiet] empty modules on each side.
class Ean13Painter extends CustomPainter {
  Ean13Painter({
    required this.modules,
    required this.ink,
    required this.barHeight,
    required this.guardHeight,
    this.quiet = 10,
  });

  final List<bool> modules;
  final Color ink;
  final double barHeight;
  final double guardHeight;
  final int quiet;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / (modules.length + quiet * 2);
    final paint = Paint()
      ..color = ink
      ..isAntiAlias = false;
    for (var i = 0; i < modules.length; i++) {
      if (!modules[i]) continue;
      final h = ean13IsGuard(i) ? guardHeight : barHeight;
      canvas.drawRect(Rect.fromLTWH((quiet + i) * w, 0, w, h), paint);
    }
  }

  @override
  bool shouldRepaint(Ean13Painter old) =>
      old.modules != modules || old.ink != ink;
}
