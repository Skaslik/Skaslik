import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/sync/domain_store.dart';
import '../../core/sync/sync_service.dart';
import '../../core/lock/app_lock.dart';
import '../../design_system/ms_theme.dart';
import 'package:ms_core/ms_core.dart';

/// Главный экран: монограмма, статус, «Сегодня», быстрые действия.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _syncedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Фон: один раз после старта попытаться синхронизироваться, если
    // подключён Яндекс.Диск и пара завершена.
    if (!_syncedOnce) {
      _syncedOnce = true;
      _maybeSyncOnStart();
    }
  }

  Future<void> _maybeSyncOnStart() async {
    // init() асинхронно грузит токен и подключается; даём ей до ~3 с.
    for (var i = 0; i < 5; i++) {
      final sync = ref.read(syncServiceProvider);
      if (sync.connected) break;
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    final sync = ref.read(syncServiceProvider);
    if (!sync.connected) return;
    await _doSync();
  }

  Future<void> _doSync() async {
    try {
      await syncService.syncAll({
        MsDomain.calendar: ref.read(calendarProvider),
        MsDomain.banks: ref.read(banksProvider),
        MsDomain.cards: ref.read(cardsProvider),
        MsDomain.docs: ref.read(docsProvider),
        MsDomain.messages: ref.read(messagesProvider),
        MsDomain.notes: ref.read(notesProvider),
        MsDomain.clips: ref.read(clipsProvider),
        MsDomain.pulse: ref.read(pulseProvider),
        MsDomain.ritual: ref.read(ritualProvider),
        MsDomain.capsule: ref.read(capsuleProvider),
      });
    } catch (_) {
      // Фоновая синхронизация не должна ломать UI.
    }
  }

  @override
  Widget build(BuildContext context) {
    final calStore = ref.watch(calendarProvider);
    final banksStore = ref.watch(banksProvider);

    final sync = ref.watch(syncServiceProvider);
    final calRepo = CalendarRepo(calStore.replica);
    final banksRepo = BanksRepo(banksStore.replica);
    final now = DateTime.now();
    final todays = calRepo.upcoming(now, days: 1).take(3).toList();
    final banks = banksRepo.allBanks();
    final topBank = banks.isNotEmpty ? banksRepo.state(banks.first.id) : null;

    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => appLock.onMonogramTap(),
          child: const Monogram(size: 30),
        ),
        actions: [
          // Индикатор синхронизации: статус Я.Диска / локально.
          GestureDetector(
            onTap: sync.connected ? _doSync : null,
            child: Container(
              margin: const EdgeInsets.only(right: MsTokens.spaceMd),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MsColors.paperWarm,
                borderRadius: BorderRadius.circular(MsTokens.radiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sync.state == SyncState.syncing)
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  else
                    Icon(
                      _syncIcon(sync.state),
                      size: 13,
                      color: _syncColor(sync.state),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    sync.connected
                        ? (sync.detail ?? _syncLabel(sync.state))
                        : 'локально',
                    style: MsTypography.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(MsTokens.spaceMd),
        children: [
          const _SectionTitle('Ближайшее'),
          if (todays.isEmpty)
            _EmptyTile(icon: Icons.event, text: MsEmpty.calendar,
                onTap: () => context.go('/calendar'))
          else
            for (final (ev, occ) in todays)
              Padding(
                padding: const EdgeInsets.only(bottom: MsTokens.spaceSm),
                child: _EventCard(ev: ev, when: occ),
              ),
          if (topBank != null) ...[
            const SizedBox(height: MsTokens.spaceSm),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(MsTokens.radiusMd),
                onTap: () => context.go('/banks'),
                child: Padding(
                  padding: const EdgeInsets.all(MsTokens.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.savings,
                              color: MsColors.accent),
                          const SizedBox(width: MsTokens.spaceSm),
                          Expanded(
                            child: Text(topBank.bank.goalName,
                                style: MsTypography.body
                                    .copyWith(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: MsTokens.spaceSm),
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(MsTokens.radiusSm),
                        child: LinearProgressIndicator(
                          value: topBank.progress,
                          minHeight: 8,
                          backgroundColor: MsColors.accentSoft,
                          valueColor:
                              AlwaysStoppedAnimation(MsColors.accent),
                        ),
                      ),
                      const SizedBox(height: MsTokens.spaceXs),
                      Text(
                        '${topBank.current} / ${topBank.bank.targetAmount} ₽ · '
                        '${(topBank.progress * 100).toInt()}%',
                        style: MsTypography.caption,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: MsTokens.spaceMd),
          const _NavRow(icon: Icons.event, label: 'Календарь', route: '/calendar'),
          const _NavRow(icon: Icons.holiday_village, label: 'Комната', route: '/room'),
          const _NavRow(icon: Icons.savings, label: 'Копилки', route: '/banks'),
          const _NavRow(icon: Icons.insert_drive_file, label: 'Документы', route: '/docs'),
          const _NavRow(icon: Icons.credit_score, label: 'Карты лояльности', route: '/cards'),
          const _NavRow(icon: Icons.chat_bubble_outline, label: 'Сообщения', route: '/messages'),
          const _NavRow(icon: Icons.sticky_note_2_outlined, label: 'Заметки', route: '/notes'),
          const _NavRow(icon: Icons.settings_outlined, label: 'Настройки', route: '/settings'),
        ],
      ),
    );
  }

  String _syncLabel(SyncState s) => switch (s) {
        SyncState.disconnected => 'локально',
        SyncState.unpaired => 'пара не готова',
        SyncState.syncing => 'синхр…',
        SyncState.synced => 'синхр.',
        SyncState.error => 'ошибка',
      };

  IconData _syncIcon(SyncState s) => switch (s) {
        SyncState.synced => Icons.cloud_done,
        SyncState.syncing => Icons.cloud_sync,
        SyncState.error => Icons.cloud_off,
        _ => Icons.cloud_queue,
      };

  Color _syncColor(SyncState s) => switch (s) {
        SyncState.syncing => MsColors.warn,
        SyncState.error => MsColors.danger,
        SyncState.synced => MsColors.success,
        _ => MsColors.muted,
      };
}

class Monogram extends StatelessWidget {
  const Monogram({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MsColors.ink,
        borderRadius: BorderRadius.circular(MsTokens.radiusSm),
      ),
      alignment: Alignment.center,
      child: Text('МС', style: TextStyle(
        color: MsColors.paper,
        fontSize: size * 0.4,
        fontWeight: FontWeight.w700,
        height: 1,
      )),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MsTokens.spaceSm, top: MsTokens.spaceSm),
      child: Text(text, style: MsTypography.bodySm.copyWith(
        color: MsColors.muted,
        fontWeight: FontWeight.w600,
      )),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.ev, required this.when});
  final CalEvent ev;
  final DateTime when;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(MsTokens.radiusMd),
        onTap: () => context.go('/calendar'),
        child: Padding(
          padding: const EdgeInsets.all(MsTokens.spaceMd),
          child: Row(
            children: [
              Container(
                width: 4, height: 36,
                decoration: BoxDecoration(
                  gradient: MsColors.sharedGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: MsTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ev.title,
                        style: MsTypography.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(_fmt(when), style: MsTypography.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(MsTokens.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MsTokens.spaceLg),
          child: Column(
            children: [
              Icon(icon, size: 32, color: MsColors.accent),
              const SizedBox(height: MsTokens.spaceSm),
              Text(text, textAlign: TextAlign.center, style: MsTypography.body),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label;
  final String route;
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: MsTokens.spaceSm),
      child: ListTile(
        leading: Icon(icon, color: MsColors.accent),
        title: Text(label, style: MsTypography.body),
        trailing: Icon(Icons.chevron_right, color: MsColors.muted),
        onTap: () => context.go(route),
      ),
    );
  }
}
