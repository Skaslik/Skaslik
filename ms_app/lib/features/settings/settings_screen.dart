import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../core/family/family.dart';
import '../../core/providers.dart';
import '../../core/sync/domain_store.dart';
import '../../core/sync/sync_service.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/theme_controller.dart';
import '../../design_system/widgets/widgets.dart';

/// Настройки: статус семьи/синхронизации, безопасность, данные, «о нас».
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch<Family>(familyProvider);
    final calendar = ref.watch(calendarProvider);
    final banks = ref.watch(banksProvider);
    final docs = ref.watch(docsProvider);
    final cards = ref.watch(cardsProvider);
    final notes = ref.watch(notesProvider);
    final messages = ref.watch(messagesProvider);
    final sync = ref.watch(syncServiceProvider);
    final theme = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(MsTokens.spaceMd),
        children: [
          // Temporary home of the theme switch until «Мы → Тема» (Phase 7).
          const _Section('Тема'),
          MsSegmented<MsThemeMode>(
            segments: const [
              MsSegment(MsThemeMode.auto, 'Авто'),
              MsSegment(MsThemeMode.evening, 'Вечер'),
              MsSegment(MsThemeMode.day, 'День'),
            ],
            value: theme.mode,
            onChanged: theme.setMode,
          ),
          const _Section('Семья'),
          const _Row(icon: Icons.people, title: 'Семья Афанасьевых', sub: 'Михаил & София · 2 устройства'),
          _Row(
            icon: Icons.cloud_outlined,
            title: 'Синхронизация (Я.Диск)',
            sub: sync.detail ?? _syncLabel(sync.state),
            color: _syncColor(sync.state),
            onTap: sync.connected ? () => _syncNow(context, ref) : null,
          ),
          if (!sync.connected)
            _Row(
              icon: Icons.login,
              title: 'Подключить Яндекс.Диск',
              sub: 'OAuth в браузере → токены в secure storage',
              onTap: () => _connectYandex(context),
            ),
          if (sync.connected)
            _Row(
              icon: Icons.logout,
              title: 'Отключить Яндекс.Диск',
              sub: 'удалить токены с устройства',
              color: MsColors.danger,
              onTap: () => _disconnectYandex(context),
            ),
          _Row(
            icon: Icons.qr_code_2,
            title: 'Мой публичный ключ',
            sub: family.pubKeyB64 == null
                ? 'семья не создана'
                : 'показать и передать партнёру',
            onTap: family.pubKeyB64 == null ? null : () => _showMyKey(context),
          ),
          _Row(
            icon: Icons.handshake,
            title: 'Завершить пару',
            sub: 'ввести ключ присоединившегося',
            onTap: family.isSet ? () => _completePair(context) : null,
          ),
          const _Section('Данные'),
          _Row(icon: Icons.event, title: 'Календарь', sub: '${calendar.entityCount} сущн.'),
          _Row(icon: Icons.savings, title: 'Копилки', sub: '${banks.entityCount} сущн.'),
          _Row(icon: Icons.insert_drive_file, title: 'Документы', sub: '${docs.entityCount} сущн.'),
          _Row(icon: Icons.credit_score, title: 'Карты', sub: '${cards.entityCount} сущн.'),
          _Row(icon: Icons.sticky_note_2_outlined, title: 'Заметки', sub: '${notes.entityCount} сущн.'),
          _Row(icon: Icons.chat_bubble_outline, title: 'Сообщения', sub: '${messages.entityCount} сущн.'),
          const _Section('Безопасность'),
          const _Row(icon: Icons.lock_outline, title: 'Биометрия / PIN', sub: 'Включить блокировку приложения (local_auth)'),
          const _Row(icon: Icons.calculate_outlined, title: 'Fake mode', sub: 'Тройное тап по монограмме → калькулятор'),
          const _Section('Опасная зона'),
          _Row(
            icon: Icons.delete_forever,
            title: 'Сбросить все данные',
            sub: 'Полное удаление local-first хранилища',
            color: MsColors.danger,
            onTap: () => _resetAll(context, ref),
          ),
          const SizedBox(height: MsTokens.spaceLg),
          const Center(
            child: Text('МС · v0.1.1 · сделано с любовью для пары',
                style: MsTypography.caption),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAll(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить все данные?'),
        content:
            const Text('Удалит календарь, копилки, документы, карты, заметки, сообщения. Отменить нельзя.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сбросить')),
        ],
      ),
    );
    if (confirm != true) return;
    for (final p in [
      calendarProvider,
      banksProvider,
      cardsProvider,
      docsProvider,
      notesProvider,
      messagesProvider,
      clipsProvider
    ]) {
      final store = ref.read(p);
      for (final id in store.view().keys.toList()) {
        store.remove(id);
      }
      store.persist();
    }
  }

  void _showMyKey(BuildContext context) {
    final key = family.pubKeyB64 ?? '';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Мой публичный ключ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Передать этот ключ тому, кто присоединяется к семье.'),
              const SizedBox(height: MsTokens.spaceMd),
              SelectableText(key),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: key));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Скопировано')));
            },
            child: const Text('Скопировать'),
          ),
        ],
      ),
    );
  }

  Future<void> _completePair(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Завершить пару'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Вставьте публичный ключ присоединившегося (b64).'),
            const SizedBox(height: MsTokens.spaceMd),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(hintText: 'b64, 44 символа'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Завершить')),
        ],
      ),
    );
    if (ok != true) return;
    final pub = ctrl.text.trim();
    if (pub.isEmpty) return;
    try {
      await family.pairWithPeer(pub);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пара завершена ✓')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  String _syncLabel(SyncState s) => switch (s) {
        SyncState.disconnected => 'не подключено',
        SyncState.unpaired => 'пара не завершена',
        SyncState.syncing => 'синхронизация…',
        SyncState.synced => 'синхронизировано',
        SyncState.error => 'ошибка',
      };

  Color _syncColor(SyncState s) => switch (s) {
        SyncState.syncing => MsColors.warn,
        SyncState.error => MsColors.danger,
        SyncState.synced => MsColors.success,
        _ => Colors.transparent,
      };

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    try {
      final applied = await syncService.syncAll({
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Синхронизировано · применено удалённых: $applied')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Синхронизация: $e')));
      }
    }
  }

  Future<void> _connectYandex(BuildContext context) async {
    try {
      await syncService.login();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Подключение: $e')));
      }
    }
  }

  Future<void> _disconnectYandex(BuildContext context) async {
    await syncService.logout();
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: MsTokens.spaceMd, bottom: MsTokens.spaceXs),
      child: Text(text, style: MsTypography.caption.copyWith(
          color: MsColors.accent, fontWeight: FontWeight.w600)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.icon,
      required this.title,
      required this.sub,
      this.color,
      this.onTap});
  final IconData icon;
  final String title;
  final String sub;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? MsColors.ink;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: c),
        title: Text(title,
            style: MsTypography.body.copyWith(
                fontWeight: FontWeight.w600, color: c)),
        subtitle: Text(sub, style: MsTypography.caption),
        onTap: onTap,
        trailing: onTap != null
            ? Icon(Icons.chevron_right, color: MsColors.muted)
            : null,
      ),
    );
  }
}
