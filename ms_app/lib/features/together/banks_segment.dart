import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import 'banks_model.dart';

/// «Копилки»: open banks as cards, finished ones in «Архив · N».
class BanksSegment extends ConsumerStatefulWidget {
  const BanksSegment({super.key, this.clock});
  final DateTime Function()? clock;

  @override
  ConsumerState<BanksSegment> createState() => _BanksSegmentState();
}

class _BanksSegmentState extends ConsumerState<BanksSegment> {
  bool _archive = false;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final repo = BanksRepo(ref.watch(banksProvider).replica);
    final states = [for (final b in repo.allBanks()) repo.state(b.id)]
      ..sort((a, b) => b.bank.createdAt.compareTo(a.bank.createdAt));
    final open = states.where((s) => !s.done).toList();
    final done = states.where((s) => s.done).toList();
    if (states.isEmpty) {
      return MsRowCard(children: [
        Expanded(
          child: Text(
            'Ни одной копилки. Начни с «На отпуск» — дальше пойдёт само.',
            style: MsText.bodySm.copyWith(color: ms.inkMuted),
          ),
        ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MsSize.piggyListGap,
      children: [
        for (final s in open) BankCard(state: s, clock: widget.clock),
        if (done.isNotEmpty)
          MsRowCard(
            onTap: () => setState(() => _archive = !_archive),
            semanticLabel: 'Архив, целей собрано: ${done.length}',
            children: [
              Icon(Symbols.inventory_2_rounded,
                  size: MsSize.icon, color: ms.inkMuted),
              Expanded(
                child: Text('Архив · ${done.length}',
                    style: MsTextX.rowTitle.copyWith(color: ms.ink)),
              ),
              Icon(
                  _archive
                      ? Symbols.expand_less_rounded
                      : Symbols.expand_more_rounded,
                  size: MsSize.icon,
                  color: ms.inkFaint),
            ],
          ),
        if (_archive)
          for (final s in done) BankCard(state: s, clock: widget.clock),
      ],
    );
  }
}

/// One piggy bank (components/PiggyBank.md).
class BankCard extends ConsumerWidget {
  const BankCard({super.key, required this.state, this.clock});
  final BankState state;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final repo = BanksRepo(ref.watch(banksProvider).replica);
    final now = (clock ?? DateTime.now)();
    final b = state.bank;
    final history = repo.history(b.id);
    final shares = bankShares(history, pair);
    final badge = todayBadge(history, now);
    final fine = lastFineLine(history, pair);
    MsProgressTone tone(MsAuthor a) =>
        a == MsAuthor.sofia ? MsProgressTone.sofia : MsProgressTone.michael;

    return MsCard(
      onTap: () => showBankSheet(context, b.id),
      semanticLabel: '${b.goalName}: ${formatMoney(state.current)} из '
          '${formatMoney(b.targetAmount)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: MsEyebrow(bankCategory(b))),
            if (badge != null) MsBadge(badge, tone: MsBadgeTone.flame),
          ]),
          const SizedBox(height: MsSpace.space1),
          Row(spacing: MsSpace.space2, children: [
            Expanded(
              child: Text(b.goalName,
                  style: MsText.titleSm.copyWith(color: ms.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (!state.done)
              MsButton(
                label: formatMoneyDelta(kQuickAdd),
                size: MsButtonSize.small,
                onPressed: () => _quickAdd(context, ref, pair),
              ),
          ]),
          const SizedBox(height: MsSpace.space3),
          MsProgressSplit(
            target: b.targetAmount,
            semanticLabel: 'Собрано ${(state.progress * 100).round()} %',
            parts: [
              MsProgressPart(tone(pair.me.author), shares.mine),
              MsProgressPart(tone(pair.partner.author), shares.theirs),
              MsProgressPart(MsProgressTone.warn, shares.fines),
            ],
          ),
          const SizedBox(height: MsSpace.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(formatMoney(state.current),
                    style: MsText.numberMd.copyWith(color: ms.ink)),
              ),
              MsMeta('из ${formatMoney(b.targetAmount)}'),
            ],
          ),
          const SizedBox(height: MsSpace.space2),
          Wrap(
            spacing: MsSpace.space3,
            runSpacing: MsSpace.space1,
            children: [
              if (shares.mine > 0)
                MsMeta(formatMoney(shares.mine), author: pair.me.author),
              if (shares.theirs > 0)
                MsMeta(formatMoney(shares.theirs), author: pair.partner.author),
              // The fines bank tells its last fine instead of a forecast.
              if (b.icon != 'fines' || fine == null)
                MsMeta(bankForecast(state, history, now), maxLines: 2),
            ],
          ),
          if (fine != null) ...[
            const SizedBox(height: MsSpace.space3),
            Divider(color: ms.line, height: MsSize.hairline),
            const SizedBox(height: MsSpace.space3),
            Row(spacing: MsSpace.space2, children: [
              Icon(Symbols.gavel_rounded, size: MsSize.iconSm, color: ms.inkMuted),
              Expanded(child: MsMeta(fine, maxLines: 2)),
            ]),
          ],
        ],
      ),
    );
  }

  void _quickAdd(BuildContext context, WidgetRef ref, Pair pair) {
    final store = ref.read(banksProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    BanksRepo(store.replica).contribute(state.bank.id,
        BankEntry(id: 'c$now', by: pair.myDeviceId, amount: kQuickAdd, at: now));
    store.persist();
    HapticFeedback.lightImpact();
    MsToast.show(
        context,
        '${pair.partner.name} увидит: «${pair.me.addressName} '
        '${pair.me.verb('добавил')} ${formatMoney(kQuickAdd)} в „${state.bank.goalName}“»');
  }
}

/// History, a custom contribution or fine, and delete.
Future<void> showBankSheet(BuildContext context, String bankId) =>
    showMsSheet<void>(context, builder: (_) => _BankSheet(bankId: bankId));

class _BankSheet extends ConsumerStatefulWidget {
  const _BankSheet({required this.bankId});
  final String bankId;

  @override
  ConsumerState<_BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends ConsumerState<_BankSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _fine = false;
  bool _fineOnPartner = true;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), ''));

  void _save(Pair pair, PiggyBank bank) {
    final v = _value;
    if (v == null || v <= 0) return;
    final store = ref.read(banksProvider);
    final repo = BanksRepo(store.replica);
    final now = DateTime.now().millisecondsSinceEpoch;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    if (_fine) {
      final who = _fineOnPartner
          ? (pair.partnerDeviceId ?? 'partner')
          : pair.myDeviceId;
      repo.fine(bank.id,
          BankEntry(id: 'f$now', by: who, amount: v, at: now, note: note, isFine: true));
    } else {
      repo.contribute(bank.id,
          BankEntry(id: 'c$now', by: pair.myDeviceId, amount: v, at: now, note: note));
    }
    store.persist();
    Navigator.of(context).pop();
    MsToast.show(context,
        _fine ? 'Штраф записан' : 'Внесено ${formatMoney(v)} в «${bank.goalName}»');
  }

  Future<void> _delete(PiggyBank bank, Pair pair) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить копилку «${bank.goalName}»?'),
        content: Text(
            'История взносов исчезнет и у ${pair.partner.nameGenitive} после синка.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Удалить',
                  style: MsTextX.link.copyWith(color: ctx.ms.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final store = ref.read(banksProvider);
    BanksRepo(store.replica).removeBank(bank.id);
    store.persist();
    Navigator.of(context).pop();
    MsToast.show(context, 'Копилка удалена');
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final repo = BanksRepo(ref.watch(banksProvider).replica);
    final bank = repo.getBank(widget.bankId);
    if (bank == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final history = repo.history(bank.id).reversed.take(8).toList();
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(
              top: MsSize.formLabelTop, bottom: MsSize.formLabelGap),
          child: MsEyebrow(t),
        );
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MsEyebrow(bankCategory(bank)),
          const SizedBox(height: MsSpace.space1),
          Text(bank.goalName, style: MsText.title.copyWith(color: ms.ink)),
          label('История'),
          if (history.isEmpty)
            const MsMeta('пока ни одного взноса')
          else
            for (final e in history)
              Padding(
                padding: const EdgeInsets.only(bottom: MsSpace.space1),
                child: MsMeta(historyLine(e, pair, now),
                    author: e.isFine ? null : pair.memberOf(e.by).author,
                    maxLines: 2),
              ),
          label(_fine ? 'Штраф' : 'Взнос'),
          MsSegmented<bool>(
            segments: const [MsSegment(false, 'Взнос'), MsSegment(true, 'Штраф')],
            value: _fine,
            onChanged: (v) => setState(() => _fine = v),
          ),
          if (_fine) ...[
            const SizedBox(height: MsSpace.space2),
            Wrap(spacing: MsSpace.space2, children: [
              MsChip(
                label: 'на ${pair.partner.addressName}',
                person: pair.partner.author,
                selected: _fineOnPartner,
                onTap: () => setState(() => _fineOnPartner = true),
              ),
              MsChip(
                label: 'на себя',
                person: pair.me.author,
                selected: !_fineOnPartner,
                onTap: () => setState(() => _fineOnPartner = false),
              ),
            ]),
          ],
          const SizedBox(height: MsSpace.space2),
          Wrap(spacing: MsSpace.space2, children: [
            for (final p in kAmountPresets)
              MsChip(
                label: formatMoney(p),
                selected: _value == p,
                onTap: () => setState(() => _amount.text = '$p'),
              ),
          ]),
          const SizedBox(height: MsSpace.space2),
          SizedBox(
            height: MsSize.fieldH,
            child: TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: MsText.numberMd.copyWith(color: ms.ink),
              decoration: const InputDecoration(hintText: 'Сумма, ₽'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: MsSpace.space2),
          SizedBox(
            height: MsSize.fieldH,
            child: TextField(
              controller: _note,
              style: MsText.body.copyWith(color: ms.ink),
              decoration: InputDecoration(
                  hintText: _fine ? 'За что: не вынес мусор' : 'Комментарий'),
            ),
          ),
          const SizedBox(height: MsSpace.space4),
          MsButton(
            label: _fine ? 'Записать штраф' : 'Внести',
            expand: true,
            onPressed: (_value ?? 0) > 0 ? () => _save(pair, bank) : null,
          ),
          const SizedBox(height: MsSpace.space6),
          MsButton(
            label: 'Удалить копилку',
            variant: MsButtonVariant.danger,
            expand: true,
            onPressed: () => _delete(bank, pair),
          ),
        ],
      ),
    );
  }
}

/// «Новая копилка».
Future<void> showNewBankSheet(BuildContext context) => showMsSheet<void>(
    context, title: 'Новая копилка', builder: (_) => const _NewBankSheet());

class _NewBankSheet extends ConsumerStatefulWidget {
  const _NewBankSheet();
  @override
  ConsumerState<_NewBankSheet> createState() => _NewBankSheetState();
}

class _NewBankSheetState extends ConsumerState<_NewBankSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  String _cat = 'trip';
  DateTime? _due;
  bool _pick = false;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_target.text);

  void _create() {
    final name = _name.text.trim();
    final t = _amount;
    if (name.isEmpty || t == null || t <= 0) return;
    final store = ref.read(banksProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    BanksRepo(store.replica).createBank(PiggyBank(
      id: 'b$now',
      goalName: name,
      icon: _cat,
      targetAmount: t,
      targetDate: _due?.millisecondsSinceEpoch,
      createdAt: now,
    ));
    store.persist();
    Navigator.of(context).pop();
    MsToast.show(context, 'Копилка «$name» открыта');
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final now = DateTime.now();
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(
              top: MsSize.formLabelTop, bottom: MsSize.formLabelGap),
          child: MsEyebrow(t),
        );
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label('Цель'),
          SizedBox(
            height: MsSize.fieldH,
            child: TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: MsText.body.copyWith(color: ms.ink),
              decoration: const InputDecoration(hintText: 'Например: На отпуск'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          label('Сколько собрать'),
          SizedBox(
            height: MsSize.fieldH,
            child: TextField(
              controller: _target,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: MsText.numberMd.copyWith(color: ms.ink),
              decoration: const InputDecoration(hintText: '150 000 ₽'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          label('Что это'),
          Wrap(spacing: MsSpace.space2, runSpacing: MsSpace.space2, children: [
            for (final e in kBankCategories.entries)
              MsChip(
                label: e.value,
                selected: _cat == e.key,
                onTap: () => setState(() => _cat = e.key),
              ),
          ]),
          label('К дате'),
          Wrap(spacing: MsSpace.space2, children: [
            MsChip(
              label: 'без срока',
              selected: _due == null,
              onTap: () => setState(() {
                _due = null;
                _pick = false;
              }),
            ),
            MsChip(
              label: _due == null ? 'к…' : 'к ${formatFullDate(_due!)}',
              selected: _due != null,
              onTap: () => setState(() {
                _pick = !_pick;
                _due ??= DateTime(now.year, now.month + 6, 1);
              }),
            ),
          ]),
          if (_pick)
            MsDateWheel(
              initial: _due ?? DateTime(now.year, now.month + 6, 1),
              firstYear: now.year,
              onChanged: (d) => setState(() => _due = d),
            ),
          const SizedBox(height: MsSpace.space5),
          MsButton(
            label: 'Открыть копилку',
            expand: true,
            onPressed: _name.text.trim().isNotEmpty && (_amount ?? 0) > 0
                ? _create
                : null,
          ),
        ],
      ),
    );
  }
}
