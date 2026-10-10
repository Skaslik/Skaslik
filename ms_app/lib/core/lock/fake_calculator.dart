/// Фейковый калькулятор — декой для fake mode.
///
/// A real, working calculator that looks like a neutral system one: no МС
/// colours, fonts or mark (components/ScreenLock.md), and no real data.
/// The only way back: type the real PIN, then «=».
///
/// The colours here are deliberately literal system greys — the МС tokens
/// must not appear on this screen.
library;

import 'package:flutter/material.dart';

import 'app_lock.dart';

class FakeCalculator extends StatefulWidget {
  const FakeCalculator({super.key, this.lock});

  /// Null in previews and tests that only check the arithmetic.
  final AppLock? lock;

  @override
  State<FakeCalculator> createState() => _FakeCalculatorState();
}

class _FakeCalculatorState extends State<FakeCalculator> {
  static const _bg = Color(0xFF1C1C1E);
  static const _digitKey = Color(0xFF3A3A3C);
  static const _opKey = Color(0xFF5B6573);
  static const _fnKey = Color(0xFFA5A5A5);
  static const _white = Color(0xFFFFFFFF);

  String _display = '0';
  double? _acc;
  String _op = '';
  bool _fresh = true;

  double get _value => double.tryParse(_display.replaceAll(',', '.')) ?? 0;

  String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return 'Ошибка';
    final r = (v * 1e8).round() / 1e8;
    final s = r == r.roundToDouble() ? r.toInt().toString() : r.toString();
    return s.replaceAll('.', ',');
  }

  double _apply(double? a, double b, String op) => switch (op) {
        '+' => (a ?? 0) + b,
        '−' => (a ?? 0) - b,
        '×' => (a ?? 0) * b,
        '÷' => b == 0 ? double.nan : (a ?? 0) / b,
        _ => b,
      };

  Future<void> _press(String k) async {
    if (RegExp(r'^\d$').hasMatch(k)) {
      setState(() {
        final cur = (_fresh || _display == '0') ? k : _display + k;
        _display = cur.length > 11 ? cur.substring(0, 11) : cur;
        _fresh = false;
      });
      return;
    }
    switch (k) {
      case ',':
        if (!_display.contains(',')) {
          setState(() {
            _display = '${_fresh ? '0' : _display},';
            _fresh = false;
          });
        }
      case 'AC':
        setState(() {
          _display = '0';
          _acc = null;
          _op = '';
          _fresh = true;
        });
      case '±':
        setState(() => _display = _fmt(-_value));
      case '%':
        setState(() => _display = _fmt(_value / 100));
      case '=':
        // The way out: a bare 4–6 digit number that is the real PIN.
        final lock = widget.lock;
        if (lock != null &&
            _op.isEmpty &&
            RegExp(r'^\d{4,6}$').hasMatch(_display)) {
          final pin = _display;
          if (await lock.exitFakeWithPin(pin)) return;
        }
        if (!mounted) return;
        setState(() {
          _display = _fmt(_apply(_acc, _value, _op));
          _acc = null;
          _op = '';
          _fresh = true;
        });
      default: // + − × ÷
        setState(() {
          _acc = _acc == null
              ? _value
              : (_fresh ? _acc : _apply(_acc, _value, _op));
          _op = k;
          _fresh = true;
          _display = _fmt(_acc!);
        });
    }
  }

  static const _keys = [
    ['AC', 'fn'], ['±', 'fn'], ['%', 'fn'], ['÷', 'op'],
    ['7', ''], ['8', ''], ['9', ''], ['×', 'op'],
    ['4', ''], ['5', ''], ['6', ''], ['−', 'op'],
    ['1', ''], ['2', ''], ['3', ''], ['+', 'op'],
    ['0', 'wide'], [',', ''], ['=', 'op'],
  ];

  Widget _key(String label, String kind) {
    final bg = switch (kind) {
      'fn' => _fnKey,
      'op' => _opKey,
      _ => _digitKey,
    };
    final fg = kind == 'fn' ? _bg : _white;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => _press(label),
          child: SizedBox(
            height: 76,
            child: Center(
              child: Text(label,
                  style: TextStyle(fontSize: 28, color: fg, height: 1)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = <List<List<String>>>[];
    for (var i = 0; i < 16; i += 4) {
      rows.add(_keys.sublist(i, i + 4));
    }
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Semantics(
                liveRegion: true,
                child: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  child: Text(
                    _display,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 64, fontWeight: FontWeight.w300, color: _white),
                  ),
                ),
              ),
              for (final r in rows)
                Row(children: [
                  for (final k in r) Expanded(child: _key(k[0], k[1])),
                ]),
              Row(children: [
                Expanded(flex: 2, child: _key('0', 'wide')),
                Expanded(child: _key(',', '')),
                Expanded(child: _key('=', 'op')),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
