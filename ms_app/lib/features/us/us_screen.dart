import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/lock/app_lock.dart';
import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/theme_controller.dart';
import '../../design_system/widgets/widgets.dart';
import '../../shell/tab_badges.dart';
import '../home/home_texts.dart';
import '../home/sync_sheet.dart';
import 'us_sheets.dart';

/// «Мы» (components/ScreenUs.md): the pair's numbers, the capsule waiting
/// for you, the theme, «Близко» — and below, calmly, «Устройство и
/// данные». Settings don't hide behind a gear.
class UsScreen extends ConsumerWidget {
  const UsScreen({super.key, this.clock});
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = context.ms;
    final now = (clock ?? DateTime.now)();
    final pair = ref.watch(pairProvider);
    final profile = ProfileRepo(ref.watch(profileProvider).replica);
    final theme = ref.watch(themeControllerProvider);
    final sync = ref.watch(syncServiceProvider);
    final capsules = CapsulesRepo(ref.watch(capsuleProvider).replica).all();
    final messages = MessagesRepo(ref.watch(messagesProvider).replica,
            deviceId: pair.myDeviceId)
        .all();
    final pulse = todaysPulse(
        PulseRepo(ref.watch(pulseProvider).replica), pair.myDeviceId, now);
    final seen = ref.watch(tabSeenProvider);
    final newNotes = messages
        .where((m) => !pair.isMine(m.from) && m.at > seen.seenAtKey(notesSeenKey))
        .length;
    final waiting = capsules
        .where((c) => c.sealed && !pair.isMine(c.from) && c.from != null)
        .toList()
      ..sort((a, b) => a.sealDate.compareTo(b.sealDate));
    final names = pair.me.author == MsAuthor.michael
        ? '${pair.me.name} и ${pair.partner.name}'
        : '${pair.partner.name} и ${pair.me.name}';
    final pill = syncPill(sync.state);

    return MsScreen(children: [
      MsScreenHeader(
        eyebrow: names,
        title: 'Мы',
        actions: const [_PairMark()],
      ),
      const SizedBox(height: MsSpace.space4),
      _PairStats(
        together: profile.daysTogether(now),
        toAnniversary: profile.daysToAnniversary(now),
        onTap: () => showProfileSheet(context),
      ),
      if (waiting.isNotEmpty) ...[
        const SizedBox(height: MsSize.capsuleGap),
        _CapsuleCard(capsule: waiting.first, pair: pair, now: now),
      ],
      const MsSectionHeader('Тема'),
      MsSegmented<MsThemeMode>(
        segments: const [
          MsSegment(MsThemeMode.auto, 'Авто'),
          MsSegment(MsThemeMode.evening, 'Вечер'),
          MsSegment(MsThemeMode.day, 'День'),
        ],
        value: theme.mode,
        onChanged: theme.setMode,
      ),
      const MsSectionHeader('Близко'),
      MsGroup(rows: [
        MsGroupRow(
          icon: Symbols.sticky_note_2_rounded,
          title: 'Записки',
          count: newNotes,
          onTap: () {
            ref.read(tabSeenProvider).markSeenKey(notesSeenKey);
            context.go('/us/notes');
          },
        ),
        MsGroupRow(
          icon: Symbols.hourglass_rounded,
          title: 'Капсулы',
          value: capsules.isEmpty ? null : '${capsules.length}',
          onTap: () => showCapsulesSheet(context),
        ),
        MsGroupRow(
          icon: Symbols.favorite_rounded,
          title: 'Пульс дня',
          value: pulse == null
              ? 'не отмечен'
              : pulseWord(pulse.value, pair.me).toLowerCase(),
          onTap: () => showPulseSheet(context),
        ),
      ]),
      const MsSectionHeader('Устройство и данные'),
      MsGroup(rows: [
        MsGroupRow(
          icon: Symbols.sync_rounded,
          title: 'Синхронизация',
          value: sync.connected ? 'Я.Диск · ${pill.label}' : pill.label,
          onTap: () => showSyncSheet(context),
        ),
        MsGroupRow(
          icon: Symbols.lock_rounded,
          title: 'Безопасность',
          value: appLock.pinSet ? 'PIN · отпечаток' : 'отпечаток',
          onTap: () => showSecuritySheet(context),
        ),
        MsGroupRow(
          icon: Symbols.key_rounded,
          title: 'Лист восстановления',
          onTap: () => showRecoverySheet(context),
        ),
        MsGroupRow(
          icon: Symbols.devices_rounded,
          title: 'Устройства',
          value: pair.partnerDeviceId == null ? 'один' : 'два',
          onTap: () => showDevicesSheet(context),
        ),
        MsGroupRow(
          icon: Symbols.badge_rounded,
          title: 'Мы двое',
          value: pair.me.addressName,
          onTap: () => showProfileSheet(context),
        ),
      ]),
      const SizedBox(height: MsSpace.space6),
      Center(
        child: Text('МС · сделано для вас двоих',
            style: MsText.meta.copyWith(color: ms.inkFaint)),
      ),
    ]);
  }
}

/// Two 30 px discs: michael, then sofia with a 2 px `ground` ring.
class _PairMark extends StatelessWidget {
  const _PairMark();

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    const d = MsSize.pairDisc;
    return ExcludeSemantics(
      child: SizedBox(
        width: d * 1.6,
        height: d,
        child: Stack(children: [
          Positioned(
            left: 0,
            child: Container(
                width: d,
                height: d,
                decoration:
                    BoxDecoration(color: ms.michael, shape: BoxShape.circle)),
          ),
          Positioned(
            right: 0,
            child: Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                color: ms.sofia,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: ms.ground,
                      offset: const Offset(-MsSize.pairRing, 0)),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// «1 461 дней вместе | 2 дня до годовщины» (components/PairStats.md).
class _PairStats extends StatelessWidget {
  const _PairStats(
      {required this.together, required this.toAnniversary, required this.onTap});
  final int? together;
  final int? toAnniversary;
  final VoidCallback onTap;

  /// The second number turns `link` when the anniversary is this close.
  static const int soonDays = 30;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final t = together, a = toAnniversary;
    Widget cell(String big, String label, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(big,
                style: MsText.numberXl
                    .copyWith(color: color, letterSpacing: -0.64)),
            MsMeta(label),
          ],
        );
    return MsCard(
      onTap: onTap,
      semanticLabel: t == null
          ? 'Дата начала отношений не указана'
          : '${formatNumber(t)} ${ruPlural(t, 'день', 'дня', 'дней')} вместе, '
              '${a == 0 ? 'годовщина сегодня' : 'до годовщины ${daysWord(a!)}'}',
      child: IntrinsicHeight(
        child: Row(children: [
          Expanded(
            child: t == null
                ? cell('—', 'укажи, с какого дня вы вместе', ms.ink)
                : cell(formatNumber(t),
                    '${ruPlural(t, 'день', 'дня', 'дней')} вместе', ms.ink),
          ),
          VerticalDivider(color: ms.line, width: MsSize.hairline),
          const SizedBox(width: MsSpace.space5),
          Expanded(
            child: a == null
                ? cell('—', 'до годовщины', ms.ink)
                : a == 0
                    ? cell('0', 'годовщина сегодня', ms.link)
                    : cell(
                        '$a',
                        '${ruPlural(a, 'день', 'дня', 'дней')} до годовщины',
                        a <= soonDays ? ms.link : ms.ink),
          ),
        ]),
      ),
    );
  }
}

/// The letter waiting for you, in its author's colour with `onPartner` text.
class _CapsuleCard extends StatelessWidget {
  const _CapsuleCard(
      {required this.capsule, required this.pair, required this.now});
  final Capsule capsule;
  final Pair pair;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final from = pair.memberOf(capsule.from);
    final open = DateTime.fromMillisecondsSinceEpoch(capsule.sealDate);
    final days = daysUntil(capsule.sealDate, now);
    final canOpen = capsule.canOpen(now);
    final title = 'Тебя ждёт письмо от ${from.nameGenitive}';
    final meta = canOpen
        ? 'можно открыть'
        : 'откроется ${formatDayMonth(open)} · ${inDays(days)}';
    return MsCard(
      color: from.author.color(ms),
      padding: const EdgeInsets.symmetric(
          horizontal: MsSpace.space4, vertical: MsSize.capsulePadV),
      onTap: () => showCapsulesSheet(context),
      semanticLabel: '$title, $meta',
      child: Row(spacing: MsSpace.space3, children: [
        Icon(Symbols.mail_rounded, size: MsSize.icon, color: ms.onPartner, fill: 1),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: MsTextX.bubble
                    .copyWith(fontWeight: FontWeight.w700, color: ms.onPartner)),
            Text(meta, style: MsText.meta.copyWith(color: ms.onPartner)),
          ]),
        ),
      ]),
    );
  }
}

/// A rounded group of rows separated by hairlines (`.grp`).
class MsGroup extends StatelessWidget {
  const MsGroup({super.key, required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return Material(
      color: ms.surface,
      borderRadius: BorderRadius.circular(MsRadius.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(color: ms.line, height: MsSize.hairline),
          rows[i],
        ],
      ]),
    );
  }
}

/// Row in an [MsGroup]: icon, title, a mono value or a count, chevron.
class MsGroupRow extends StatelessWidget {
  const MsGroupRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.count = 0,
  });

  final IconData icon;
  final String title;
  final String? value;

  /// New items: a flame pill instead of the value.
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final v = value;
    return Semantics(
      button: true,
      label: [
        title,
        if (count > 0) 'новых: $count' else if (v != null) v,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: MsSpace.space4, vertical: MsSpace.space3),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MsSize.groupRowMin),
            child: Row(spacing: MsSpace.space3, children: [
              Icon(icon, size: MsSize.icon, color: ms.inkMuted),
              Expanded(
                child: Text(title,
                    style: MsTextX.groupTitle.copyWith(color: ms.ink)),
              ),
              if (count > 0)
                Container(
                  constraints:
                      const BoxConstraints(minWidth: MsSize.countBadgeMin),
                  height: MsSize.countBadgeMin,
                  padding: const EdgeInsets.symmetric(
                      horizontal: MsSize.countBadgePadH),
                  decoration: BoxDecoration(
                    color: ms.flame,
                    borderRadius: BorderRadius.circular(MsRadius.radiusPill),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text('$count',
                        style: MsTextX.chipCount.copyWith(color: ms.onFlame)),
                  ),
                )
              else if (v != null)
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: MsSize.groupValueMax),
                  child: Text(v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MsText.meta.copyWith(color: ms.inkMuted)),
                ),
              Icon(Symbols.chevron_right_rounded,
                  size: MsSize.icon, color: ms.inkFaint),
            ]),
          ),
        ),
      ),
    );
  }
}
