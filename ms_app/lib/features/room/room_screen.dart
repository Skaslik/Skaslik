import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ms_core/ms_core.dart';

import '../../core/providers.dart';
import '../../design_system/ms_theme.dart';

/// «Комната» — общий живой фид пары в реальном времени.
///
/// Собирает в одну ленту: пульс дня (энергия/усталость/обнимашки), ритуалы
/// («думал о тебе» 💗), капсулы времени (таймер до открытия) и свежие события
/// (кто что добавил). Всё — local-first CRDT, синхронизируется между
/// устройствами.
class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key});

  static const _dev = 'local';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulse = ref.watch(pulseProvider);
    final ritual = ref.watch(ritualProvider);
    final capsule = ref.watch(capsuleProvider);
    final calendar = ref.watch(calendarProvider);
    final banks = ref.watch(banksProvider);
    final now = DateTime.now();

    final pulseRepo = PulseRepo(pulse.replica);
    final ritualRepo = RitualsRepo(ritual.replica);
    final capsuleRepo = CapsulesRepo(capsule.replica);

    // Сегодняшние волны пульса (последний).
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final todayPulses = pulseRepo
        .byDay(from: DateTime.fromMillisecondsSinceEpoch(today));

    // Ближайшая закрытая капсула.
    final nextCapsule = capsuleRepo.all().cast<Capsule?>().firstWhere(
        (c) => c!.sealed,
        orElse: () => null);
    final feed = <_FeedItem>[
      for (final p in todayPulses)
        _FeedItem(
            at: p.day,
            icon: p.value == PulseValue.peak
                ? Icons.bolt
                : p.value == PulseValue.tired
                    ? Icons.bedtime
                    : Icons.favorite,
            color: p.value == PulseValue.peak
                ? MsColors.warn
                : p.value == PulseValue.tired
                    ? PartnerColors.michael
                    : MsColors.accent,
            text: p.value == PulseValue.peak
                ? '⚡ энергия'
                : p.value == PulseValue.tired
                    ? '😴 усталость'
                    : '🤗 обнимашки'),
      for (final r in ritualRepo.unread(_dev, now))
        _FeedItem(
            at: r.at,
            icon: Icons.favorite,
            color: MsColors.accent,
            text: r.kind == RitualKind.beacon
                ? '🔆 маячок'
                : '💗 думал о тебе'),
    ];
    feed.sort((a, b) => b.at.compareTo(a.at));

    return Scaffold(
      appBar: AppBar(title: const Text('Комната')),
      floatingActionButton: _RoomFab(
        onPulse: (v) {
          pulseRepo.send(Pulse(
              id: 'p-${DateTime.now().millisecondsSinceEpoch}',
              by: _dev,
              value: v,
              day: today));
          pulse.persist();
        },
        onRitual: () {
          ritualRepo.send(Ritual(
              id: 'r-${DateTime.now().millisecondsSinceEpoch}',
              from: _dev,
              kind: RitualKind.dot,
              at: DateTime.now().millisecondsSinceEpoch));
          ritual.persist();
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(MsTokens.spaceMd),
        children: [
          const _SectionTitle('Пульс дня'),
          _PulseWave(pulses: todayPulses),
          const SizedBox(height: MsTokens.spaceMd),
          if (nextCapsule != null) ...[
            const _SectionTitle('Капсула'),
            _CapsuleCard(c: nextCapsule),
            const SizedBox(height: MsTokens.spaceMd),
          ],
          const _SectionTitle('Лента'),
          if (feed.isEmpty)
            const Padding(
              padding: EdgeInsets.all(MsTokens.spaceMd),
              child: Text('Пока тихо. Отправьте пульс или ритуал 💗',
                  style: MsTypography.body),
            )
          else
            for (final item in feed.take(20))
              _FeedTile(item: item),
          const SizedBox(height: MsTokens.spaceMd),
          const _SectionTitle('Общее'),
          _StatRow(icon: Icons.event, text: 'Событий: ${calendar.entityCount}'),
          _StatRow(icon: Icons.savings, text: 'Копилок: ${banks.entityCount}'),
        ],
      ),
    );
  }
}

class _FeedItem {
  final int at;
  final IconData icon;
  final Color color;
  final String text;
  const _FeedItem(
      {required this.at,
      required this.icon,
      required this.color,
      required this.text});
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: MsTokens.spaceMd, bottom: MsTokens.spaceXs),
      child: Text(text,
          style: MsTypography.caption.copyWith(
              color: MsColors.accent, fontWeight: FontWeight.w600)),
    );
  }
}

/// Волна пульса: цветные точки/полоски за день.
class _PulseWave extends StatelessWidget {
  const _PulseWave({required this.pulses});
  final List<Pulse> pulses;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MsTokens.spaceMd),
        child: pulses.isEmpty
            ? const Text('Сегодня пока тихо', style: MsTypography.bodySm)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final p in pulses.reversed.toList())
                    Padding(
                      padding: const EdgeInsets.only(bottom: MsTokens.spaceXs),
                      child: Row(
                        children: [
                          Icon(
                              p.value == PulseValue.peak
                                  ? Icons.bolt
                                  : p.value == PulseValue.tired
                                      ? Icons.bedtime
                                      : Icons.favorite,
                              size: 18,
                              color: p.value == PulseValue.peak
                                  ? MsColors.warn
                                  : p.value == PulseValue.tired
                                      ? PartnerColors.michael
                                      : MsColors.accent),
                          const SizedBox(width: MsTokens.spaceXs),
                          Text(
                              p.value == PulseValue.peak
                                  ? 'энергия'
                                  : p.value == PulseValue.tired
                                      ? 'усталость'
                                      : 'обнимашки',
                              style: MsTypography.bodySm),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CapsuleCard extends StatelessWidget {
  const _CapsuleCard({required this.c});
  final Capsule c;

  @override
  Widget build(BuildContext context) {
    final days =
        (c.sealDate - DateTime.now().millisecondsSinceEpoch) ~/ 86400000;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.hourglass_bottom, color: MsColors.accent),
        title: Text(c.title,
            style: MsTypography.body.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
            days > 0
                ? 'Откроется через $days дн.'
                : 'Можно открыть! 💌',
            style: MsTypography.caption),
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({required this.item});
  final _FeedItem item;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.fromMillisecondsSinceEpoch(item.at);
    final label =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: MsTokens.spaceXs),
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: item.color),
          const SizedBox(width: MsTokens.spaceSm),
          Expanded(child: Text(item.text, style: MsTypography.bodySm)),
          Text(label, style: MsTypography.caption),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MsTokens.spaceXs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: MsColors.accent),
          const SizedBox(width: MsTokens.spaceSm),
          Text(text, style: MsTypography.bodySm),
        ],
      ),
    );
  }
}

/// Плавающая панель действий комнаты: пульс (3 кнопки) + ритуал 💗.
class _RoomFab extends StatelessWidget {
  const _RoomFab({required this.onPulse, required this.onRitual});
  final void Function(PulseValue v) onPulse;
  final VoidCallback onRitual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MsTokens.spaceSm, vertical: MsTokens.spaceXs),
      decoration: BoxDecoration(
        color: MsColors.ink,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FabBtn(icon: Icons.bolt, color: MsColors.warn, onTap: () => onPulse(PulseValue.peak)),
          _FabBtn(icon: Icons.bedtime, color: PartnerColors.michael, onTap: () => onPulse(PulseValue.tired)),
          _FabBtn(icon: Icons.favorite, color: MsColors.accent, onTap: () => onPulse(PulseValue.hug)),
          const SizedBox(width: MsTokens.spaceXs),
          _FabBtn(icon: Icons.favorite, color: MsColors.accent, onTap: onRitual, label: '💗'),
        ],
      ),
    );
  }
}

class _FabBtn extends StatelessWidget {
  const _FabBtn({required this.icon, required this.color, required this.onTap, this.label});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? label;
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label ?? 'Пульс',
      onPressed: onTap,
      iconSize: 24,
      icon: label != null
          ? Text(label!, style: const TextStyle(fontSize: 22))
          : Icon(icon, color: color),
    );
  }
}
