import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ms_core/ms_core.dart';

import '../../core/family/family.dart';
import '../../core/providers.dart';
import '../../design_system/ms_theme.dart';

/// Сообщения: лента, текстовые/пинги, burn-режимы, scheduled.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(messagesProvider);
    final repo = MessagesRepo(store.replica, deviceId: 'local');
    final now = DateTime.now();
    final views = repo.render(now);
    // Автоматически сжигаем просроченные.
    for (final id in repo.dueToBurn(now)) {
      repo.burn(id, now.millisecondsSinceEpoch);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Сообщения')),
      body: Column(
        children: [
          Expanded(
            child: views.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(MsTokens.spaceLg),
                      child: Text(MsEmpty.messages,
                          textAlign: TextAlign.center, style: MsTypography.body),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(MsTokens.spaceMd),
                    itemCount: views.length,
                    itemBuilder: (context, i) {
                      final v = views[i];
                      return _Bubble(v: v);
                    },
                  ),
          ),
          _Composer(onSend: (text, kind, burn, sched) {
            repo.send(Message(
              id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
              from: family.deviceId ?? 'local',
              kind: kind,
              text: text,
              burn: burn,
              scheduledFor: sched,
              at: DateTime.now().millisecondsSinceEpoch,
            ));
            store.persist();
          }),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.v});
  final MessageView v;

  @override
  Widget build(BuildContext context) {
    final m = v.m;
    final isMine = m.from == 'local' || m.from == family.deviceId;
    final isBurned = v.burnState == BurnState.burned;
    final isScheduled =
        v.m.scheduledFor != null && !v.revealed;
    final content = isBurned
        ? 'сгорело'
        : isScheduled
            ? '⏰ будет видно позже'
            : (m.kind == MsgKind.ping ? '🔔 пинг' : (m.text ?? ''));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: MsTokens.spaceMd),
          padding: const EdgeInsets.symmetric(
              horizontal: MsTokens.spaceMd, vertical: MsTokens.spaceSm),
          decoration: BoxDecoration(
            color: isMine ? MsColors.accentSoft : MsColors.paperWarm,
            borderRadius: BorderRadius.circular(MsTokens.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(content,
                  style: MsTypography.body.copyWith(
                      fontStyle: isBurned ? FontStyle.italic : FontStyle.normal)),
              if (m.burn != BurnMode.none)
                Text('🔥 ${m.burn.name}', style: MsTypography.caption),
              Text(
                  '${(m.at ~/ 3600000).toString().padLeft(2, '0')}:${((m.at ~/ 60000) % 60).toString().padLeft(2, '0')}',
                  style: MsTypography.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.onSend});
  final void Function(String text, MsgKind kind, BurnMode burn, int? sched) onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _ctrl = TextEditingController();
  final MsgKind _kind = MsgKind.text;
  BurnMode _burn = BurnMode.none;
  bool _sched = false;

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _kind != MsgKind.ping) return;
    final schedMs = _sched
        ? DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch
        : null;
    widget.onSend(text, _kind, _burn, schedMs);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MsTokens.spaceSm),
      color: MsColors.paper,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Пинг.
          IconButton(
            tooltip: 'Пинг',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => widget.onSend('ping', MsgKind.ping, _burn, null),
          ),
          // Burn.
          IconButton(
            tooltip: 'Сгорание',
            icon: const Icon(Icons.local_fire_department),
            onPressed: () {
              setState(() => _burn = _burn == BurnMode.none
                  ? BurnMode.ttl24h
                  : _burn == BurnMode.ttl24h
                      ? BurnMode.onView
                      : BurnMode.none);
            },
          ),
          // Scheduled.
          IconButton(
            tooltip: 'Скрыть на 1 час',
            icon: Icon(_sched ? Icons.schedule : Icons.schedule_outlined),
            onPressed: () => setState(() => _sched = !_sched),
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onSubmitted: (_) => _send(),
              decoration:
                  const InputDecoration(hintText: 'Написать…'),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: _send),
        ],
      ),
    );
  }
}
