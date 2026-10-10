import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/family/family.dart';
import '../../core/lock/app_lock.dart';
import '../../core/providers.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import '../lock/lock_screen.dart';

enum _Step { welcome, about, since, join, recovery, share, pin, pinAgain }

/// Онбординг «МС» (screens.md «Онбординг и пара»): приветствие → «Создать
/// семью» / «Присоединиться» → имя, обращение, род и цвет → дата начала
/// отношений → лист восстановления (создатель) или ключ для пары
/// (присоединившийся) → PIN.
///
/// Профиль (имя, обращение, род, цвет, дата) пишется в синхронизируемый
/// домен `profile`; секреты — как и раньше, только в SecureVault.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.welcome;
  bool _join = false;
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _s = TextEditingController();
  final _peerPub = TextEditingController();
  MemberGender _gender = MemberGender.m;
  String _color = 'michael';
  DateTime? _since;
  String _pin = '';
  String _firstPin = '';
  String? _error;
  String? _ownPub;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _s.dispose();
    _peerPub.dispose();
    super.dispose();
  }

  void _go(_Step s) => setState(() {
        _step = s;
        _error = null;
      });

  /// Write my profile once the family (and so my device id) exists.
  void _writeProfile() {
    final id = family.deviceId;
    if (id == null) return;
    // The store may have been created before the device id existed.
    ref.invalidate(profileProvider);
    final store = ref.read(profileProvider);
    final repo = ProfileRepo(store.replica);
    final name = _name.text.trim();
    final address = _address.text.trim();
    repo.upsertMember(Member(
      deviceId: id,
      name: name,
      addressName: address.isEmpty ? name : address,
      gender: _gender,
      color: _color,
    ));
    final since = _since;
    if (since != null) repo.setSince(since);
    store.persist();
  }

  Color get _familyColor =>
      _color == 'sofia' ? MsPalette.day.sofia : MsPalette.day.michael;

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      await family.createFamily(name: _name.text.trim(), color: _familyColor);
      _writeProfile();
      _go(_Step.recovery);
    } catch (e) {
      setState(() => _error = 'Не получилось: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinFamily() async {
    final words =
        _s.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2) {
      setState(() => _error = 'Нужен секрет семьи — 4 слова от создателя');
      return;
    }
    if (_peerPub.text.trim().isEmpty) {
      setState(() => _error = 'Нужен ключ создателя');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await family.joinFamily(
        name: _name.text.trim(),
        color: _familyColor,
        sWords: words,
        peerPubB64: _peerPub.text.trim(),
      );
      _ownPub = r.ownPubB64;
      _writeProfile();
      _go(_Step.share);
    } catch (e) {
      setState(() => _error = 'Не получилось: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _digit(String d) async {
    if (_pin.length >= kPinLength) return;
    setState(() => _pin += d);
    if (_pin.length < kPinLength) return;
    if (_step == _Step.pin) {
      _firstPin = _pin;
      setState(() => _pin = '');
      _go(_Step.pinAgain);
      return;
    }
    if (_pin != _firstPin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _firstPin = '';
        _step = _Step.pin;
        _error = 'PIN не совпал — придумай ещё раз';
      });
      return;
    }
    await appLock.setPin(_pin);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(MsSpace.space6, pad.top + MsSpace.space8,
            MsSpace.space6, pad.bottom + MsSpace.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...switch (_step) {
              _Step.welcome => _welcome(ms),
              _Step.about => _about(ms),
              _Step.since => _sinceStep(ms),
              _Step.join => _joinStep(ms),
              _Step.recovery => _recovery(ms),
              _Step.share => _share(ms),
              _Step.pin || _Step.pinAgain => _pinStep(ms),
            },
            if (_error != null) ...[
              const SizedBox(height: MsSpace.space3),
              MsMeta(_error!, color: ms.danger, maxLines: 3),
            ],
          ],
        ),
      ),
    );
  }

  Widget _title(MsPalette ms, String text) => Semantics(
        header: true,
        child: Text(text, style: MsTextX.lockTitle.copyWith(color: ms.ink)),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(
            top: MsSize.formLabelTop, bottom: MsSize.formLabelGap),
        child: MsEyebrow(t),
      );

  Widget _field(MsPalette ms, TextEditingController c, String hint,
          {int maxLines = 1, bool autofocus = false}) =>
      TextField(
        controller: c,
        autofocus: autofocus,
        maxLines: maxLines,
        minLines: 1,
        textCapitalization: TextCapitalization.words,
        style: MsText.body.copyWith(color: ms.ink),
        decoration: InputDecoration(hintText: hint),
        onChanged: (_) => setState(() {}),
      );

  List<Widget> _welcome(MsPalette ms) => [
        const Center(child: MsMonogram(size: MsSize.lockMark)),
        const SizedBox(height: MsSize.lockTitleGap),
        Center(child: _title(ms, 'Наш дом на двоих')),
        const SizedBox(height: MsSpace.space2),
        Text(
          'Календарь, файлы, копилки и свеча — только для вас двоих. '
          'Без серверов и аккаунтов: всё живёт на ваших телефонах.',
          textAlign: TextAlign.center,
          style: MsText.bodySm.copyWith(color: ms.inkMuted),
        ),
        const SizedBox(height: MsSpace.space8),
        MsButton(
          label: 'Создать семью',
          expand: true,
          onPressed: () {
            _join = false;
            _go(_Step.about);
          },
        ),
        const SizedBox(height: MsSpace.space2),
        MsButton(
          label: 'Присоединиться к семье',
          variant: MsButtonVariant.secondary,
          expand: true,
          onPressed: () {
            _join = true;
            _go(_Step.about);
          },
        ),
      ];

  List<Widget> _about(MsPalette ms) => [
        _title(ms, 'Расскажи о себе'),
        _label('Как тебя зовут'),
        _field(ms, _name, 'Михаил', autofocus: true),
        _label('Как к тебе обращаться'),
        _field(ms, _address, 'Миша'),
        _label('Ты'),
        Wrap(spacing: MsSpace.space2, children: [
          MsChip(
            label: 'он',
            selected: _gender == MemberGender.m,
            onTap: () => setState(() {
              _gender = MemberGender.m;
              _color = 'michael';
            }),
          ),
          MsChip(
            label: 'она',
            selected: _gender == MemberGender.f,
            onTap: () => setState(() {
              _gender = MemberGender.f;
              _color = 'sofia';
            }),
          ),
        ]),
        _label('Твой цвет'),
        Wrap(spacing: MsSpace.space2, children: [
          MsChip(
            label: 'синий',
            person: MsAuthor.michael,
            selected: _color == 'michael',
            onTap: () => setState(() => _color = 'michael'),
          ),
          MsChip(
            label: 'коралловый',
            person: MsAuthor.sofia,
            selected: _color == 'sofia',
            onTap: () => setState(() => _color = 'sofia'),
          ),
        ]),
        const SizedBox(height: MsSpace.space2),
        const MsMeta('этим цветом будут твои события и вклады', maxLines: 2),
        const SizedBox(height: MsSpace.space8),
        MsButton(
          label: 'Дальше',
          expand: true,
          onPressed:
              _name.text.trim().isEmpty ? null : () => _go(_Step.since),
        ),
        MsButton(
          label: 'Назад',
          variant: MsButtonVariant.ghost,
          expand: true,
          onPressed: () => _go(_Step.welcome),
        ),
      ];

  List<Widget> _sinceStep(MsPalette ms) {
    final now = DateTime.now();
    return [
      _title(ms, 'Когда вы вместе?'),
      const SizedBox(height: MsSpace.space2),
      Text(
          'Для «дней вместе» и годовщины. Можно пропустить и указать позже в «Мы».',
          style: MsText.bodySm.copyWith(color: ms.inkMuted)),
      const SizedBox(height: MsSpace.space4),
      MsDateWheel(
        initial: _since ?? DateTime(now.year - 1, now.month, now.day),
        firstYear: now.year - 40,
        years: 41,
        onChanged: (d) => _since = d,
      ),
      const SizedBox(height: MsSpace.space6),
      MsButton(
        label: _join ? 'Дальше' : 'Создать семью',
        expand: true,
        onPressed: _busy
            ? null
            : () {
                _since ??= DateTime(now.year - 1, now.month, now.day);
                _join ? _go(_Step.join) : _create();
              },
      ),
      MsButton(
        label: 'Пропустить',
        variant: MsButtonVariant.ghost,
        expand: true,
        onPressed: _busy
            ? null
            : () {
                _since = null;
                _join ? _go(_Step.join) : _create();
              },
      ),
    ];
  }

  List<Widget> _joinStep(MsPalette ms) => [
        _title(ms, 'Соединяемся'),
        const SizedBox(height: MsSpace.space2),
        Text('Попроси у создателя секрет семьи (4 слова) и ключ.',
            style: MsText.bodySm.copyWith(color: ms.inkMuted)),
        _label('Секрет семьи'),
        _field(ms, _s, 'дом дождь книга окно'),
        _label('Ключ создателя'),
        _field(ms, _peerPub, '44 символа', maxLines: 2),
        const SizedBox(height: MsSpace.space6),
        MsButton(
          label: 'Присоединиться',
          expand: true,
          onPressed: _busy ? null : _joinFamily,
        ),
      ];

  List<Widget> _recovery(MsPalette ms) {
    final sheet = family.recoverySheet();
    return [
      _title(ms, 'Семья создана'),
      const SizedBox(height: MsSpace.space2),
      Text(
        'Сохрани лист восстановления: перепиши на бумагу и храни дома. '
        'Без него данные не вернуть.',
        style: MsText.bodySm.copyWith(color: ms.inkMuted),
      ),
      const SizedBox(height: MsSpace.space4),
      MsCard(
        child:
            SelectableText(sheet, style: MsText.meta.copyWith(color: ms.ink)),
      ),
      const SizedBox(height: MsSpace.space3),
      MsButton(
        label: 'Скопировать',
        variant: MsButtonVariant.secondary,
        expand: true,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: sheet));
          MsToast.show(context, 'Скопировано', bottom: MsSpace.space8);
        },
      ),
      const SizedBox(height: MsSpace.space2),
      MsButton(
        label: 'Лист сохранён',
        expand: true,
        onPressed: () => _go(_Step.pin),
      ),
    ];
  }

  List<Widget> _share(MsPalette ms) => [
        _title(ms, 'Почти готово'),
        const SizedBox(height: MsSpace.space2),
        Text(
            'Передай этот ключ создателю — он завершит пару у себя в «Мы → Устройства».',
            style: MsText.bodySm.copyWith(color: ms.inkMuted)),
        const SizedBox(height: MsSpace.space4),
        MsCard(
          child: SelectableText(_ownPub ?? '',
              style: MsText.meta.copyWith(color: ms.ink)),
        ),
        const SizedBox(height: MsSpace.space3),
        MsButton(
          label: 'Скопировать ключ',
          variant: MsButtonVariant.secondary,
          expand: true,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _ownPub ?? ''));
            MsToast.show(context, 'Скопировано', bottom: MsSpace.space8);
          },
        ),
        const SizedBox(height: MsSpace.space2),
        MsButton(
          label: 'Дальше: PIN',
          expand: true,
          onPressed: () => _go(_Step.pin),
        ),
      ];

  List<Widget> _pinStep(MsPalette ms) => [
        const Center(child: MsMonogram(size: MsSize.lockMark)),
        const SizedBox(height: MsSize.lockTitleGap),
        Center(
          child:
              _title(ms, _step == _Step.pin ? 'Придумай PIN' : 'Повтори PIN'),
        ),
        const SizedBox(height: MsSpace.space1),
        const Center(
            child: MsMeta('4 цифры — на случай, если отпечаток не сработает')),
        const SizedBox(height: MsSize.pinDotsTop),
        Center(child: MsPinDots(filled: _pin.length, length: kPinLength)),
        const SizedBox(height: MsSize.keysTop),
        Center(
          child: MsKeypad(
            onDigit: _digit,
            onBack: () => setState(() {
              if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
            }),
          ),
        ),
      ];
}
