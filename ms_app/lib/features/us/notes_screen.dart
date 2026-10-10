import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';

/// «Записки» (PLAN 5.7 «записка на холодильнике»): the partner's bubbles
/// on the left in `surface`, mine on the right in my soft colour, each with
/// the author dot and the time. The partner's latest hangs on the wall in
/// the room. Burning and «откроется через час» from the old screen stay.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key, this.clock});
  final DateTime Function()? clock;

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _text = TextEditingController();
  BurnMode _burn = BurnMode.none;
  bool _later = false;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seeAndBurn());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Opening the notes «views» the partner's burn-on-view notes; anything
  /// due burns, leaving only its trace.
  void _seeAndBurn() {
    if (!mounted) return;
    final pair = ref.read(pairProvider);
    final store = ref.read(messagesProvider);
    final repo = MessagesRepo(store.replica, deviceId: pair.myDeviceId);
    var changed = false;
    for (final v in repo.render(_now)) {
      final m = v.m;
      if (!pair.isMine(m.from) &&
          m.burn == BurnMode.onView &&
          v.revealed &&
          v.burnState == BurnState.live) {
        repo.markViewed(m.id);
        changed = true;
      }
    }
    for (final id in repo.dueToBurn(_now)) {
      repo.burn(id, _now.millisecondsSinceEpoch);
      changed = true;
    }
    if (changed) store.persist();
  }

  void _send(Pair pair, {bool ping = false}) {
    final text = _text.text.trim();
    if (!ping && text.isEmpty) return;
    final store = ref.read(messagesProvider);
    final now = _now;
    MessagesRepo(store.replica, deviceId: pair.myDeviceId).send(Message(
      id: 'm${now.microsecondsSinceEpoch}',
      from: pair.myDeviceId,
      kind: ping ? MsgKind.ping : MsgKind.text,
      text: ping ? null : text,
      burn: ping ? BurnMode.none : _burn,
      scheduledFor: _later
          ? now.add(const Duration(hours: 1)).millisecondsSinceEpoch
          : null,
      at: now.millisecondsSinceEpoch,
    ));
    store.persist();
    _text.clear();
    setState(() {
      _burn = BurnMode.none;
      _later = false;
    });
    MsToast.show(
        context,
        ping
            ? '${pair.partner.name} увидит, что ты думаешь '
                'о ${pair.partner.feminine ? 'ней' : 'нём'}'
            : 'Записка ушла — повиснет у ${pair.partner.nameGenitive} на стене');
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final store = ref.watch(messagesProvider);
    final views =
        MessagesRepo(store.replica, deviceId: pair.myDeviceId).render(_now);
    final pad = MediaQuery.paddingOf(context);
    return Column(children: [
      Expanded(
        child: ListView(
          reverse: true,
          padding: EdgeInsets.fromLTRB(
              MsSpace.space4, pad.top + MsSpace.space1, MsSpace.space4, MsSpace.space4),
          children: [
            // reverse: newest first in the list = bottom of the screen.
            for (final v in views.reversed) ...[
              _Bubble(view: v, pair: pair, now: _now),
              const SizedBox(height: MsSpace.space2),
            ],
            if (views.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: MsSpace.space8),
                child: Text('Тихо-тихо. Напиши первую записку.',
                    textAlign: TextAlign.center,
                    style: MsText.bodySm.copyWith(color: ms.inkMuted)),
              ),
            const SizedBox(height: MsSpace.space4),
            Row(children: [
              MsIconButton(
                icon: Symbols.arrow_back_rounded,
                label: 'Назад',
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/us'),
              ),
              const SizedBox(width: MsSpace.space3),
              Expanded(
                child: MsScreenHeader(
                  eyebrow: 'последняя от ${pair.partner.nameGenitive} — на стене',
                  title: 'Записки',
                ),
              ),
            ]),
          ],
        ),
      ),
      _Composer(
        controller: _text,
        burn: _burn,
        later: _later,
        onBurn: () => setState(() => _burn = switch (_burn) {
              BurnMode.none => BurnMode.ttl24h,
              BurnMode.ttl24h => BurnMode.onView,
              BurnMode.onView => BurnMode.none,
            }),
        onLater: () => setState(() => _later = !_later),
        onPing: () => _send(pair, ping: true),
        onSend: () => _send(pair),
      ),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.view, required this.pair, required this.now});
  final MessageView view;
  final Pair pair;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final m = view.m;
    final mine = pair.isMine(m.from);
    final who = pair.memberOf(m.from);
    final at = DateTime.fromMillisecondsSinceEpoch(m.at);
    final whenText = formatWhen(at, now) == 'сегодня'
        ? formatTime(at)
        : '${formatWhen(at, now)}, ${formatTime(at)}';
    final String text;
    var muted = false;
    if (view.burnState == BurnState.burned) {
      text = 'здесь было что-то тёплое';
      muted = true;
    } else if (!view.revealed) {
      text = mine
          ? '${m.text ?? ''} · откроется в ${formatTime(DateTime.fromMillisecondsSinceEpoch(m.scheduledFor!))}'
          : 'Записка откроется в ${formatTime(DateTime.fromMillisecondsSinceEpoch(m.scheduledFor!))}';
      muted = !mine;
    } else if (m.kind == MsgKind.ping) {
      text = mine
          ? 'ты думаешь о ${pair.partner.feminine ? 'ней' : 'нём'}'
          : '${who.name} думает о тебе';
      muted = true;
    } else {
      text = m.text ?? '';
    }
    final burnHint = switch (m.burn) {
      BurnMode.none => null,
      BurnMode.ttl24h => 'сгорит через сутки',
      BurnMode.onView => 'сгорит после прочтения',
    };
    final meta = [
      mine ? 'ты' : who.name,
      whenText,
      if (burnHint != null && view.burnState != BurnState.burned) burnHint,
    ].join(' · ');
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth:
                MediaQuery.sizeOf(context).width * MsSize.bubbleMaxFraction),
        child: Semantics(
          label: '${mine ? 'Ты' : who.name}: $text, $whenText',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: MsSize.bubblePadH, vertical: MsSize.bubblePadV),
            decoration: BoxDecoration(
              color: mine ? who.author.soft(ms) : ms.surface,
              borderRadius: BorderRadius.circular(MsSize.bubbleRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: MsSpace.space1,
              children: [
                Text(text,
                    style: MsTextX.bubble.copyWith(
                      color: muted ? ms.inkMuted : ms.ink,
                      fontStyle: muted ? FontStyle.italic : null,
                    )),
                MsMeta(meta, author: who.author, maxLines: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.burn,
    required this.later,
    required this.onBurn,
    required this.onLater,
    required this.onPing,
    required this.onSend,
  });

  final TextEditingController controller;
  final BurnMode burn;
  final bool later;
  final VoidCallback onBurn;
  final VoidCallback onLater;
  final VoidCallback onPing;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final burnLabel = switch (burn) {
      BurnMode.none => 'не сгорит',
      BurnMode.ttl24h => 'сгорит через сутки',
      BurnMode.onView => 'сгорит после прочтения',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ms.ground,
        border: Border(top: BorderSide(color: ms.line, width: MsSize.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            MsSpace.space4, MsSpace.space2, MsSpace.space4, MsSpace.space3),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: MsSize.chipH,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              MsChip(
                  label: burnLabel,
                  selected: burn != BurnMode.none,
                  onTap: onBurn),
              const SizedBox(width: MsSpace.space2),
              MsChip(
                  label: 'откроется через час',
                  selected: later,
                  onTap: onLater),
              const SizedBox(width: MsSpace.space2),
              MsChip(label: 'думаю о тебе', onTap: onPing),
            ]),
          ),
          const SizedBox(height: MsSpace.space2),
          Row(spacing: MsSpace.space2, children: [
            Expanded(
              child: SizedBox(
                height: MsSize.buttonH,
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  style: MsText.body.copyWith(color: ms.ink),
                  decoration:
                      const InputDecoration(hintText: 'Написать записку…'),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Отправить',
              excludeSemantics: true,
              child: SizedBox.square(
                dimension: MsSize.buttonH,
                child: Material(
                  color: ms.flame,
                  borderRadius: BorderRadius.circular(MsRadius.radiusMd),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(MsRadius.radiusMd),
                    onTap: onSend,
                    child: Icon(Symbols.send_rounded,
                        size: MsSize.icon, color: ms.onFlame),
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
