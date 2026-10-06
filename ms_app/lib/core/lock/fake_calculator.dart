/// Фейковый калькулятор — декой для fake mode.
///
/// Настоящий работающий калькулятор: если кто-то увидит телефон, тройное
/// нажатие на монограмму показывает «только калькулятор» — никаких данных семьи.
library;

import 'package:flutter/material.dart';

class FakeCalculator extends StatefulWidget {
  const FakeCalculator({super.key});

  @override
  State<FakeCalculator> createState() => _FakeCalculatorState();
}

class _FakeCalculatorState extends State<FakeCalculator> {
  String _display = '0';
  double? _acc;
  String _op = '';
  bool _fresh = true;

  void _clear() {
    setState(() {
      _display = '0';
      _acc = null;
      _op = '';
      _fresh = true;
    });
  }

  void _inputDigit(String d) {
    setState(() {
      if (_fresh) {
        _display = d;
        _fresh = false;
      } else {
        _display = _display == '0' ? d : _display + d;
      }
    });
  }

  void _dot() {
    setState(() {
      if (_fresh) {
        _display = '0.';
        _fresh = false;
      } else if (!_display.contains('.')) {
        _display += '.';
      }
    });
  }

  void _equals() {
    final b = double.tryParse(_display) ?? 0;
    final a = _acc;
    if (_op.isEmpty || a == null) return;
    final r = switch (_op) {
      '+' => a + b,
      '−' => a - b,
      '×' => a * b,
      '÷' => b == 0 ? double.nan : a / b,
      _ => b,
    };
    setState(() {
      _display = r == r ? _trim(r) : 'Ошибка';
      _acc = null;
      _op = '';
      _fresh = true;
    });
  }

  void _setOp(String o) {
    final cur = double.tryParse(_display) ?? 0;
    final a = _acc;
    final base = (a != null && _op.isNotEmpty) ? _apply(a, cur) : cur;
    setState(() {
      _acc = base;
      _op = o;
      _fresh = true;
    });
  }

  double _apply(double a, double b) => switch (_op) {
        '+' => a + b,
        '−' => a - b,
        '×' => a * b,
        '÷' => b == 0 ? double.nan : a / b,
        _ => b,
      };

  String _trim(double r) {
    if (r == r.roundToDouble()) return r.toInt().toString();
    return r.toString();
  }

  Widget _key(String label, Color bg, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Center(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const numBg = Color(0xFFEFE9E1);
    const opBg = Color(0xFFC4622D);
    const dark = Color(0xFF1A1614);
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Text(
                  _display,
                  style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w300,
                      color: dark,
                      height: 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(children: [
                    _key('C', numBg, _clear),
                    _key('±', numBg, () => setState(() =>
                        _display =
                            _display.startsWith('-')
                                ? _display.substring(1)
                                : '-$_display')),
                    _key('%', numBg, () {}),
                    _key('÷', opBg, () => _setOp('÷')),
                  ]),
                  Row(children: [
                    _key('7', numBg, () => _inputDigit('7')),
                    _key('8', numBg, () => _inputDigit('8')),
                    _key('9', numBg, () => _inputDigit('9')),
                    _key('×', opBg, () => _setOp('×')),
                  ]),
                  Row(children: [
                    _key('4', numBg, () => _inputDigit('4')),
                    _key('5', numBg, () => _inputDigit('5')),
                    _key('6', numBg, () => _inputDigit('6')),
                    _key('−', opBg, () => _setOp('−')),
                  ]),
                  Row(children: [
                    _key('1', numBg, () => _inputDigit('1')),
                    _key('2', numBg, () => _inputDigit('2')),
                    _key('3', numBg, () => _inputDigit('3')),
                    _key('+', opBg, () => _setOp('+')),
                  ]),
                  Row(children: [
                    Expanded(
                      flex: 2,
                      child: _key('0', numBg, () => _inputDigit('0')),
                    ),
                    _key('.', numBg, _dot),
                    _key('=', opBg, _equals),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
