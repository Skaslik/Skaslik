import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/family/family.dart';
import '../../core/lock/app_lock.dart';
import '../../design_system/ms_theme.dart';
import '../home/home_screen.dart';
import 'pin_pad.dart';

/// Онбординг «МС»: Welcome → Create/Join → (S+seed) → PIN → готово.
///
/// Одноустройственное создание семьи (S1): генерация S (4 слова) и seed
/// (12 слов), показ листа восстановления, настройка PIN. Join — отдельный
/// поток (S + публичный ключ партнёра).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0 welcome, 1 name/color, 2 recovery, 3 pin, 4 confirm, 5 join-share
  bool _join = false; // режим: присоединиться (второе устройство)
  final _nameCtrl = TextEditingController();
  final _sCtrl = TextEditingController();
  final _peerPubCtrl = TextEditingController();
  Color _color = PartnerColors.michael;
  String _firstPin = '';
  String? _error;
  String? _ownPub; // b64 собственного pub для передачи создателю (join)

  static const _palette = [
    PartnerColors.michael,
    PartnerColors.sofia,
    Color(0xFF4A7C59),
    Color(0xFF6C4B72),
    Color(0xFF3E6B5C),
    Color(0xFF8A5A44),
  ];

  Future<void> _createFamily() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите имя');
      return;
    }
    try {
      await family.createFamily(name: name, color: _color);
      setState(() {
        _error = null;
        _step = 2;
      });
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    }
  }

  /// Присоединение: имя/цвет уже введён; читаем S + pub создателя.
  Future<void> _joinFamily() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите имя');
      return;
    }
    final sWords = _sCtrl.text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (sWords.length < 2) {
      setState(() => _error = 'Введите семейный секрет S (4 слова)');
      return;
    }
    final peerPub = _peerPubCtrl.text.trim();
    if (peerPub.isEmpty) {
      setState(() => _error = 'Введите публичный ключ создателя');
      return;
    }
    try {
      final r = await family.joinFamily(
        name: name,
        color: _color,
        sWords: sWords,
        peerPubB64: peerPub,
      );
      _ownPub = r.ownPubB64;
      setState(() {
        _error = null;
        _step = 5; // показать собственный ключ (передать создателю)
      });
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    }
  }

  Future<void> _setPin(String pin) async {
    if (_step == 3) {
      _firstPin = pin;
      setState(() {
        _step = 4;
        _error = null;
      });
    } else if (_step == 4) {
      if (pin != _firstPin) {
        setState(() {
          _step = 3;
          _firstPin = '';
          _error = 'PIN не совпадает, введите снова';
        });
        return;
      }
      await appLock.setPin(pin);
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MsColors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MsTokens.spaceLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step == 0) _welcome(),
              if (_step == 1) _nameColor(),
              if (_step == 2) _recovery(),
              if (_step == 3 || _step == 4) _pinStep(),
              if (_step == 5) _joinShare(),
            ],
          ),
        ),
      ),
    );
  }
  Widget _welcome() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: MsTokens.spaceXl),
        const Monogram(size: 96),
        const SizedBox(height: MsTokens.spaceLg),
        Text('МС', style: MsTypography.display.copyWith(fontSize: 40)),
        const SizedBox(height: MsTokens.spaceSm),
        Text('Семья Афанасьевых', style: MsTypography.bodySm),
        const SizedBox(height: MsTokens.spaceXl),
        FilledButton(
          onPressed: () => setState(() {
            _join = false;
            _step = 1;
          }),
          child: const Text('Создать семью'),
        ),
        const SizedBox(height: MsTokens.spaceSm),
        OutlinedButton(
          onPressed: () => setState(() {
            _join = true;
            _step = 1;
          }),
          child: const Text('Присоединиться к семье'),
        ),
        const SizedBox(height: MsTokens.spaceXl),
      ],
    );
  }

  Widget _nameColor() {
    return Column(
      children: [
        const SizedBox(height: MsTokens.spaceMd),
        Text('Как вас зовут?', style: MsTypography.title),
        const SizedBox(height: MsTokens.spaceMd),
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Имя'),
        ),
        const SizedBox(height: MsTokens.spaceLg),
        Text('Ваш цвет', style: MsTypography.bodySm),
        const SizedBox(height: MsTokens.spaceSm),
        Wrap(
          spacing: MsTokens.spaceSm,
          runSpacing: MsTokens.spaceSm,
          children: [
            for (final c in _palette)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _color == c ? MsColors.ink : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_join) ...[
          const SizedBox(height: MsTokens.spaceLg),
          Text('Секрет семьи S (4 слова, от создателя)',
              style: MsTypography.bodySm),
          const SizedBox(height: MsTokens.spaceSm),
          TextField(
            controller: _sCtrl,
            decoration:
                const InputDecoration(hintText: 'дом дождь книга окно'),
          ),
          const SizedBox(height: MsTokens.spaceMd),
          Text('Публичный ключ создателя (b64)', style: MsTypography.bodySm),
          const SizedBox(height: MsTokens.spaceSm),
          TextField(
            controller: _peerPubCtrl,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(hintText: '32 байта, base64'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: MsTokens.spaceSm),
          Text(_error!,
              style:
                  MsTypography.bodySm.copyWith(color: MsColors.danger)),
        ],
        const SizedBox(height: MsTokens.spaceXl),
        FilledButton(
          onPressed: _join ? _joinFamily : _createFamily,
          child: Text(_join ? 'Присоединиться' : 'Создать'),
        ),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: const Text('Назад'),
        ),
      ],
    );
  }

  Widget _recovery() {
    final sheet = family.recoverySheet();
    return Column(
      children: [
        const SizedBox(height: MsTokens.spaceMd),
        Icon(Icons.lock_outline, size: 40, color: MsColors.accent),
        const SizedBox(height: MsTokens.spaceMd),
        Text('Семья создана. Сохраните лист восстановления.',
            style: MsTypography.title, textAlign: TextAlign.center),
        const SizedBox(height: MsTokens.spaceSm),
        Text('Это единственный способ восстановить доступ. Скопируйте оба секрета на бумагу и храните дома.',
            style: MsTypography.bodySm, textAlign: TextAlign.center),
        const SizedBox(height: MsTokens.spaceMd),
        Container(
          padding: const EdgeInsets.all(MsTokens.spaceMd),
          decoration: BoxDecoration(
            color: MsColors.paperWarm,
            borderRadius: BorderRadius.circular(MsTokens.radiusMd),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              sheet,
              style: MsTypography.mono,
            ),
          ),
        ),
        const SizedBox(height: MsTokens.spaceMd),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: sheet));
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Скопировано в буфер')));
          },
          icon: const Icon(Icons.copy),
          label: const Text('Скопировать'),
        ),
        const SizedBox(height: MsTokens.spaceXl),
        FilledButton(
          onPressed: () => setState(() {
            _step = 3;
            _error = null;
          }),
          child: const Text('Я сохранил(а) лист'),
        ),
      ],
    );
  }

  /// Шаг присоединившегося: передать создателю свой публичный ключ.
  Widget _joinShare() {
    final pub = _ownPub ?? '';
    return Column(
      children: [
        const SizedBox(height: MsTokens.spaceMd),
        Icon(Icons.check_circle, size: 40, color: MsColors.accent),
        const SizedBox(height: MsTokens.spaceMd),
        Text('Вы присоединились к семье.',
            style: MsTypography.title, textAlign: TextAlign.center),
        const SizedBox(height: MsTokens.spaceSm),
        Text('Передать этот ключ создателю (он завершит пару), затем настройте PIN.',
            style: MsTypography.bodySm, textAlign: TextAlign.center),
        const SizedBox(height: MsTokens.spaceMd),
        Container(
          padding: const EdgeInsets.all(MsTokens.spaceMd),
          decoration: BoxDecoration(
            color: MsColors.paperWarm,
            borderRadius: BorderRadius.circular(MsTokens.radiusMd),
          ),
          child: SelectableText(pub, style: MsTypography.mono),
        ),
        const SizedBox(height: MsTokens.spaceMd),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: pub));
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Скопировано в буфер')));
          },
          icon: const Icon(Icons.copy),
          label: const Text('Скопировать'),
        ),
        const SizedBox(height: MsTokens.spaceXl),
        FilledButton(
          onPressed: () => setState(() {
            _step = 3;
            _error = null;
          }),
          child: const Text('Дальше: PIN'),
        ),
      ],
    );
  }

  Widget _pinStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Monogram(size: 56),
        const SizedBox(height: MsTokens.spaceLg),
        PinPad(
          length: 4,
          title: _step == 3 ? 'Придумайте PIN' : 'Подтвердите PIN',
          subtitle: '4 цифры для входа, если биометрия недоступна',
          onComplete: _setPin,
        ),
        if (_error != null) ...[
          const SizedBox(height: MsTokens.spaceSm),
          Text(_error!, style: MsTypography.bodySm.copyWith(color: MsColors.danger)),
        ],
      ],
    );
  }
}
