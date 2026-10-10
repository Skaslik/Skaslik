import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/lock/app_lock.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';

/// PIN length used everywhere (prototype: 4 digits).
const int kPinLength = 4;

/// «С возвращением»: the family's mark, PIN dots and the mono keypad.
/// Biometrics start by themselves; PIN is the fallback
/// (components/ScreenLock.md). Three taps on the mark → fake mode.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.lock, this.autoBiometric = true});

  final AppLock lock;

  /// Off in tests.
  final bool autoBiometric;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String? _error;
  bool _checking = false;
  bool _bio = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoBiometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startBiometric());
    }
  }

  Future<void> _startBiometric() async {
    final can = await widget.lock.canUnlock();
    if (!mounted) return;
    setState(() => _bio = can);
    if (can) await widget.lock.tryUnlock();
  }

  Future<void> _digit(String d) async {
    if (_checking || _pin.length >= kPinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length < kPinLength) return;
    _checking = true;
    final ok = await widget.lock.verifyPin(_pin);
    if (!mounted) return;
    _checking = false;
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _error = 'Неверный PIN';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final pinSet = widget.lock.pinSet;
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MsSpace.space6,
            MediaQuery.paddingOf(context).top + MsSize.lockTopGap,
            MsSpace.space6,
            MsSpace.space6,
          ),
          child: Center(
            child: Column(children: [
              GestureDetector(
                onTap: widget.lock.onMonogramTap,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MsRadius.radiusLg),
                    border: Border.all(color: ms.line, width: MsSize.hairline),
                  ),
                  child: const MsMonogram(size: MsSize.lockMark),
                ),
              ),
              const SizedBox(height: MsSize.lockTitleGap),
              Semantics(
                header: true,
                child: Text('С возвращением',
                    style: MsTextX.lockTitle.copyWith(color: ms.ink)),
              ),
              const SizedBox(height: MsSpace.space1),
              MsMeta(pinSet
                  ? 'приложи палец или введи PIN'
                  : 'приложи палец, чтобы войти'),
              if (pinSet) ...[
                const SizedBox(height: MsSize.pinDotsTop),
                MsPinDots(filled: _pin.length, length: kPinLength),
                SizedBox(
                  height: MsSize.keysTop,
                  child: Center(
                    child: _error == null
                        ? null
                        : MsMeta(_error!, color: ms.danger),
                  ),
                ),
                MsKeypad(
                  onDigit: _digit,
                  onBack: () => setState(() {
                    if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
                  }),
                  onBiometric: _bio ? () => widget.lock.tryUnlock() : null,
                ),
              ] else ...[
                const SizedBox(height: MsSpace.space8),
                MsButton(
                  label: 'Войти по отпечатку',
                  expand: true,
                  onPressed: () => widget.lock.tryUnlock(),
                ),
                const SizedBox(height: MsSpace.space2),
                MsButton(
                  label: 'Войти без блокировки',
                  variant: MsButtonVariant.ghost,
                  expand: true,
                  onPressed: widget.lock.unlockManually,
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
