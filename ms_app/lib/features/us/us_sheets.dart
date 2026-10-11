import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/family/family.dart';
import '../../core/lock/app_lock.dart';
import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import '../lock/lock_screen.dart';

Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(
          top: MsSize.formLabelTop, bottom: MsSize.formLabelGap),
      child: MsEyebrow(t),
    );

String _startOfDayId(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Пульс дня
// ---------------------------------------------------------------------------

/// Word for a pulse, agreed with the member.
String pulseWord(PulseValue v, PairMember m) => switch (v) {
      PulseValue.peak => m.feminine ? 'Полна сил' : 'Полон сил',
      PulseValue.tired => m.verb('Устал'),
      PulseValue.hug => 'Хочу обнимашек',
    };

/// Today's pulse of [deviceId], if any.
Pulse? todaysPulse(PulseRepo repo, String deviceId, DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  final mine = repo
      .byDay(from: day)
      .where((p) => p.by == deviceId && p.day == day.millisecondsSinceEpoch);
  return mine.isEmpty ? null : mine.last;
}

Future<void> showPulseSheet(BuildContext context) => showMsSheet<void>(
    context, title: 'Пульс дня', builder: (_) => const _PulseSheet());

class _PulseSheet extends ConsumerWidget {
  const _PulseSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final pulseStore = ref.watch(pulseProvider);
    final ritualStore = ref.watch(ritualProvider);
    final repo = PulseRepo(pulseStore.replica);
    final rituals = RitualsRepo(ritualStore.replica);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final mine = todaysPulse(repo, pair.myDeviceId, now);
    final theirs = pair.partnerDeviceId == null
        ? null
        : todaysPulse(repo, pair.partnerDeviceId!, now);
    final partnerDots = rituals
        .unread(pair.myDeviceId, now)
        .where((r) => !pair.isMine(r.from))
        .toList();
    final hints = {
      PulseValue.peak: 'день на подъёме',
      PulseValue.tired: '${pair.partner.name} поймёт без слов',
      PulseValue.hug: 'самое важное за день',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MsMeta('одно касание — ${pair.partner.name} увидит, как ты сегодня',
            maxLines: 2),
        if (theirs != null) ...[
          const SizedBox(height: MsSpace.space2),
          MsMeta('${pair.partner.name} сегодня: ${pulseWord(theirs.value, pair.partner).toLowerCase()}',
              author: pair.partner.author),
        ],
        if (partnerDots.isNotEmpty) ...[
          const SizedBox(height: MsSpace.space2),
          MsMeta(
              '${pair.partner.name} думает о тебе · ${formatTime(DateTime.fromMillisecondsSinceEpoch(partnerDots.last.at))}',
              author: pair.partner.author),
        ],
        const SizedBox(height: MsSpace.space3),
        for (final v in PulseValue.values) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MsRadius.radiusMd),
              border: mine?.value == v
                  ? Border.all(color: ms.flame, width: MsSize.hairline * 2)
                  : null,
            ),
            child: MsRowCard(
              onTap: () {
                repo.send(Pulse(
                  id: 'p-${pair.myDeviceId}-${_startOfDayId(day)}',
                  by: pair.myDeviceId,
                  value: v,
                  day: day.millisecondsSinceEpoch,
                ));
                pulseStore.persist();
                Navigator.of(context).pop();
                MsToast.show(context,
                    '${pair.partner.name} увидит: «${pulseWord(v, pair.me)}»');
              },
              children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pulseWord(v, pair.me),
                            style: MsTextX.rowTitle.copyWith(color: ms.ink)),
                        const SizedBox(height: MsSize.rowMetaGap),
                        MsMeta(hints[v]!),
                      ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: MsSpace.space2),
        ],
        const SizedBox(height: MsSpace.space2),
        MsButton(
          label: 'Сказать «думаю о тебе»',
          variant: MsButtonVariant.secondary,
          icon: Symbols.favorite_rounded,
          expand: true,
          onPressed: () {
            for (final r in partnerDots) {
              rituals.markRead(r.id, pair.myDeviceId);
            }
            rituals.send(Ritual(
                id: 'r${now.microsecondsSinceEpoch}',
                from: pair.myDeviceId,
                kind: RitualKind.dot,
                at: now.millisecondsSinceEpoch));
            ritualStore.persist();
            Navigator.of(context).pop();
            MsToast.show(context, '${pair.partner.name} увидит точку');
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Капсулы
// ---------------------------------------------------------------------------

Future<void> showCapsulesSheet(BuildContext context) => showMsSheet<void>(
    context, title: 'Капсулы', builder: (_) => const _CapsulesSheet());

class _CapsulesSheet extends ConsumerStatefulWidget {
  const _CapsulesSheet();
  @override
  ConsumerState<_CapsulesSheet> createState() => _CapsulesSheetState();
}

class _CapsulesSheetState extends ConsumerState<_CapsulesSheet> {
  bool _writing = false;
  final _title = TextEditingController();
  final _letter = TextEditingController();
  late DateTime _open = DateTime(DateTime.now().year + 1, 2, 14);

  @override
  void dispose() {
    _title.dispose();
    _letter.dispose();
    super.dispose();
  }

  void _seal(Pair pair) {
    final letter = _letter.text.trim();
    if (letter.isEmpty) return;
    final store = ref.read(capsuleProvider);
    final now = DateTime.now();
    CapsulesRepo(store.replica).seal(Capsule(
      id: 'cap${now.microsecondsSinceEpoch}',
      title: _title.text.trim().isEmpty ? 'Письмо' : _title.text.trim(),
      sealDate: _open.millisecondsSinceEpoch,
      letter: letter,
      from: pair.myDeviceId,
    ));
    store.persist();
    Navigator.of(context).pop();
    MsToast.show(context,
        'Запечатано. ${pair.partner.name} откроет ${formatDayMonth(_open)}');
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final store = ref.watch(capsuleProvider);
    final repo = CapsulesRepo(store.replica);
    final now = DateTime.now();
    final all = repo.all();
    if (_writing) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MsMeta('до срока его не откроет никто — даже случайно',
                maxLines: 2),
            _label('Название'),
            SizedBox(
              height: MsSize.fieldH,
              child: TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                style: MsText.body.copyWith(color: ms.ink),
                decoration: const InputDecoration(hintText: 'Письмо к годовщине'),
              ),
            ),
            _label('Письмо'),
            TextField(
              controller: _letter,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              style: MsText.body.copyWith(color: ms.ink),
              decoration: const InputDecoration(hintText: 'Дорогая…'),
              onChanged: (_) => setState(() {}),
            ),
            _label('Откроется'),
            MsDateWheel(
              initial: _open,
              firstYear: now.year,
              onChanged: (d) => _open = d,
            ),
            const SizedBox(height: MsSpace.space4),
            MsButton(
              label: 'Запечатать письмо',
              expand: true,
              onPressed: _letter.text.trim().isEmpty ? null : () => _seal(pair),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (all.isEmpty)
            Text('Пока ни одной. Напиши письмо, которое откроется в важный день.',
                style: MsText.bodySm.copyWith(color: ms.inkMuted))
          else
            for (final c in all) ...[
              _CapsuleRow(capsule: c, pair: pair, now: now, onOpen: () {
                repo.confirmOpen(c.id, pair.myDeviceId, now.millisecondsSinceEpoch);
                store.persist();
              }),
              const SizedBox(height: MsSpace.space2),
            ],
          const SizedBox(height: MsSpace.space3),
          MsButton(
            label: 'Написать письмо в капсулу',
            expand: true,
            onPressed: () => setState(() => _writing = true),
          ),
        ],
      ),
    );
  }
}

class _CapsuleRow extends StatelessWidget {
  const _CapsuleRow(
      {required this.capsule, required this.pair, required this.now, required this.onOpen});
  final Capsule capsule;
  final Pair pair;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final c = capsule;
    final from = pair.memberOf(c.from);
    final open = DateTime.fromMillisecondsSinceEpoch(c.sealDate);
    final days = daysUntil(c.sealDate, now);
    final who = pair.isMine(c.from) ? 'от тебя' : 'от ${from.nameGenitive}';
    return MsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MsSpace.space1,
        children: [
          Text('${c.title} $who', style: MsTextX.rowTitle.copyWith(color: ms.ink)),
          if (!c.sealed) ...[
            MsMeta('открыто · ${formatDayMonth(DateTime.fromMillisecondsSinceEpoch(c.openedAt!))}',
                author: from.author),
            const SizedBox(height: MsSpace.space1),
            Text(c.letter ?? '', style: MsText.body.copyWith(color: ms.ink)),
          ] else if (c.canOpen(now)) ...[
            MsMeta('срок настал · ${formatDayMonth(open)}', author: from.author),
            const SizedBox(height: MsSpace.space2),
            MsButton(
              label: 'Открыть',
              size: MsButtonSize.small,
              onPressed: onOpen,
            ),
          ] else
            MsMeta('откроется ${formatDayMonth(open)} · ${inDays(days)}',
                author: from.author),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Безопасность, лист восстановления, устройства, профиль
// ---------------------------------------------------------------------------

Future<void> showSecuritySheet(BuildContext context) => showMsSheet<void>(
    context, title: 'Безопасность', builder: (_) => const _SecuritySheet());

class _SecuritySheet extends StatelessWidget {
  const _SecuritySheet();

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MsMeta(appLock.pinSet ? 'вход: отпечаток или PIN' : 'вход: отпечаток · PIN не задан'),
        const SizedBox(height: MsSpace.space3),
        Text(
          'Фейк-режим: три быстрых касания по рамке с монограммой в комнате — '
          'и вместо «МС» откроется обычный калькулятор. Чтобы вернуться, '
          'набери на нём свой PIN и нажми «=».',
          style: MsText.bodySm.copyWith(color: ms.inkMuted),
        ),
        const SizedBox(height: MsSpace.space5),
        MsButton(
          label: 'Заблокировать сейчас',
          icon: Symbols.lock_rounded,
          expand: true,
          onPressed: () {
            Navigator.of(context).pop();
            appLock.lock();
          },
        ),
      ],
    );
  }
}

Future<void> showRecoverySheet(BuildContext context) => showMsSheet<void>(
    context, title: 'Лист восстановления', builder: (_) => const _RecoverySheet());

class _RecoverySheet extends StatefulWidget {
  const _RecoverySheet();
  @override
  State<_RecoverySheet> createState() => _RecoverySheetState();
}

class _RecoverySheetState extends State<_RecoverySheet> {
  String _pin = '';
  bool _open = !appLock.pinSet;
  String? _error;

  Future<void> _digit(String d) async {
    if (_pin.length >= kPinLength) return;
    setState(() => _pin += d);
    if (_pin.length < kPinLength) return;
    final ok = await appLock.verifyPin(_pin);
    if (!mounted) return;
    setState(() {
      _open = ok;
      _error = ok ? null : 'Неверный PIN';
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    if (!_open) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const MsMeta('12 слов и секрет семьи — сначала PIN'),
        const SizedBox(height: MsSpace.space4),
        MsPinDots(filled: _pin.length, length: kPinLength),
        SizedBox(
          height: MsSpace.space6,
          child: Center(
              child: _error == null ? null : MsMeta(_error!, color: ms.danger)),
        ),
        MsKeypad(
          onDigit: _digit,
          onBack: () => setState(() {
            if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
          }),
        ),
      ]);
    }
    final sheet = family.recoverySheet();
    final s = family.s?.join(' ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          sheet.isNotEmpty
              ? 'Перепиши на бумагу и храни дома. Никому не отправляй.'
              : 'Полный лист (12 слов) есть у того, кто создал семью. Здесь — только секрет семьи.',
          style: MsText.bodySm.copyWith(color: ms.inkMuted),
        ),
        const SizedBox(height: MsSpace.space3),
        MsCard(
          child: SelectableText(
            sheet.isNotEmpty ? sheet : 'S (секрет пары, 4 слова):\n${s ?? '—'}',
            style: MsText.meta.copyWith(color: ms.ink),
          ),
        ),
      ],
    );
  }
}

Future<void> showDevicesSheet(BuildContext context) => showMsSheet<void>(
    context, title: 'Устройства', builder: (_) => const _DevicesSheet());

class _DevicesSheet extends ConsumerStatefulWidget {
  const _DevicesSheet();
  @override
  ConsumerState<_DevicesSheet> createState() => _DevicesSheetState();
}

class _DevicesSheetState extends ConsumerState<_DevicesSheet> {
  final _peer = TextEditingController();

  @override
  void dispose() {
    _peer.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final key = _peer.text.trim();
    if (key.isEmpty) return;
    try {
      await family.pairWithPeer(key);
      if (!mounted) return;
      Navigator.of(context).pop();
      MsToast.show(context, 'Пара завершена');
    } catch (e) {
      if (mounted) MsToast.show(context, 'Не получилось: $e');
    }
  }

  Future<void> _wipe(Pair pair) async {
    final ok = await confirmDanger(context,
        title: 'Удалить все записи?',
        body: 'Календарь, копилки, файлы, карты, списки и записки исчезнут — '
            'и у ${pair.partner.nameGenitive} после синка. Отменить нельзя.',
        action: 'Удалить');
    if (!ok || !mounted) return;
    for (final p in [
      calendarProvider, banksProvider, cardsProvider, docsProvider,
      notesProvider, messagesProvider, clipsProvider,
    ]) {
      final store = ref.read(p);
      for (final id in store.view().keys.toList()) {
        store.remove(id);
      }
      store.persist();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    MsToast.show(context, 'Записи удалены');
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final fam = ref.watch(familyProvider);
    final key = fam.pubKeyB64;
    final counts = [
      ('календарь', ref.watch(calendarProvider).entityCount),
      ('копилки', ref.watch(banksProvider).entityCount),
      ('файлы', ref.watch(docsProvider).entityCount),
      ('карты', ref.watch(cardsProvider).entityCount),
      ('списки', ref.watch(notesProvider).entityCount),
      ('записки', ref.watch(messagesProvider).entityCount),
    ].map((e) => '${e.$1} ${e.$2}').join(' · ');
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MsMeta(pair.partnerDeviceId == null
              ? 'пара не завершена · один телефон'
              : 'два телефона · ${pair.me.name} и ${pair.partner.name}'),
          _label('Мой ключ'),
          if (key == null)
            const MsMeta('семья ещё не создана')
          else ...[
            MsCard(
              child: SelectableText(key,
                  style: MsText.meta.copyWith(color: ms.ink)),
            ),
            const SizedBox(height: MsSpace.space2),
            MsButton(
              label: 'Скопировать ключ',
              variant: MsButtonVariant.secondary,
              expand: true,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: key));
                MsToast.show(context, 'Скопировано');
              },
            ),
          ],
          _label('Завершить пару'),
          const MsMeta('вставь ключ, который прислал присоединившийся', maxLines: 2),
          const SizedBox(height: MsSpace.space2),
          TextField(
            controller: _peer,
            minLines: 1,
            maxLines: 2,
            style: MsText.meta.copyWith(color: ms.ink),
            decoration: const InputDecoration(hintText: '44 символа'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: MsSpace.space2),
          MsButton(
            label: 'Завершить пару',
            expand: true,
            onPressed: _peer.text.trim().isEmpty || !fam.isSet ? null : _complete,
          ),
          _label('Данные на телефоне'),
          MsMeta(counts, maxLines: 3),
          const SizedBox(height: MsSpace.space5),
          MsButton(
            label: 'Удалить все записи',
            variant: MsButtonVariant.danger,
            expand: true,
            onPressed: () => _wipe(pair),
          ),
        ],
      ),
    );
  }
}

Future<void> showProfileSheet(BuildContext context) => showMsSheet<void>(
    context, title: 'Мы двое', builder: (_) => const _ProfileSheet());

class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet();
  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  late final Pair _pair = ref.read(pairProvider);
  late final _name = TextEditingController(text: _pair.me.name);
  late final _address = TextEditingController(text: _pair.me.addressName);
  late bool _feminine = _pair.me.feminine;
  late String _color = _pair.me.author == MsAuthor.sofia ? 'sofia' : 'michael';
  DateTime? _since;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    final store = ref.read(profileProvider);
    final repo = ProfileRepo(store.replica);
    final name = _name.text.trim();
    if (name.isEmpty) return;
    repo.upsertMember(Member(
      deviceId: _pair.myDeviceId,
      name: name,
      addressName: _address.text.trim().isEmpty ? name : _address.text.trim(),
      gender: _feminine ? MemberGender.f : MemberGender.m,
      color: _color,
    ));
    if (_since != null) repo.setSince(_since!);
    store.persist();
    Navigator.of(context).pop();
    MsToast.show(context, 'Сохранено');
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final now = DateTime.now();
    final since = ProfileRepo(ref.watch(profileProvider).replica).since();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MsMeta('${_pair.partner.name} меняет своё у себя', maxLines: 2),
          _label('Как тебя зовут'),
          SizedBox(
            height: MsSize.fieldH,
            child: TextField(
                controller: _name,
                style: MsText.body.copyWith(color: ms.ink),
                textCapitalization: TextCapitalization.words),
          ),
          _label('Как к тебе обращаться'),
          SizedBox(
            height: MsSize.fieldH,
            child: TextField(
                controller: _address,
                style: MsText.body.copyWith(color: ms.ink),
                textCapitalization: TextCapitalization.words),
          ),
          _label('Ты'),
          Wrap(spacing: MsSpace.space2, children: [
            MsChip(
                label: 'он',
                selected: !_feminine,
                onTap: () => setState(() => _feminine = false)),
            MsChip(
                label: 'она',
                selected: _feminine,
                onTap: () => setState(() => _feminine = true)),
          ]),
          _label('Твой цвет'),
          Wrap(spacing: MsSpace.space2, children: [
            MsChip(
                label: 'синий',
                person: MsAuthor.michael,
                selected: _color == 'michael',
                onTap: () => setState(() => _color = 'michael')),
            MsChip(
                label: 'коралловый',
                person: MsAuthor.sofia,
                selected: _color == 'sofia',
                onTap: () => setState(() => _color = 'sofia')),
          ]),
          _label('Вместе с'),
          MsDateWheel(
            initial: since ?? DateTime(now.year - 1, now.month, now.day),
            firstYear: now.year - 40,
            years: 41,
            onChanged: (d) => _since = d,
          ),
          const SizedBox(height: MsSpace.space4),
          MsButton(label: 'Сохранить', expand: true, onPressed: _save),
        ],
      ),
    );
  }
}
