import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/sync/sync_all.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import 'home_texts.dart';

/// Opens «Синхронизация» (tap on the sync pill).
Future<void> showSyncSheet(BuildContext context) => showMsSheet<void>(
      context,
      title: 'Синхронизация',
      builder: (_) => const SyncSheet(),
    );

/// Status in words, the honest promise, and «Синхронизировать сейчас».
class SyncSheet extends ConsumerWidget {
  const SyncSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = context.ms;
    final sync = ref.watch(syncServiceProvider);
    final pill = syncPill(sync.state);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [MsSyncStatus(kind: pill.kind, label: pill.label)]),
        if (sync.detail != null) ...[
          const SizedBox(height: MsSpace.space2),
          MsMeta(sync.detail!, maxLines: 2),
        ],
        const SizedBox(height: MsSpace.space3),
        Text(
          'Почти мгновенно рядом, минутно на расстоянии. '
          'Без сети всё работает и дождётся связи.',
          style: MsText.bodySm.copyWith(color: ms.inkMuted),
        ),
        const SizedBox(height: MsSpace.space5),
        if (sync.connected) ...[
          MsButton(
            label: 'Синхронизировать сейчас',
            expand: true,
            onPressed: () async {
              await syncAllNow(ref);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              MsToast.show(context, 'Готово: ${syncPill(sync.state).label}');
            },
          ),
          const SizedBox(height: MsSpace.space2),
          MsButton(
            label: 'Отключить Яндекс.Диск',
            variant: MsButtonVariant.ghost,
            expand: true,
            onPressed: () => sync.logout(),
          ),
        ] else
          MsButton(
            label: 'Подключить Яндекс.Диск',
            variant: MsButtonVariant.secondary,
            expand: true,
            onPressed: () async {
              try {
                await sync.login();
              } catch (e) {
                if (context.mounted) {
                  MsToast.show(context, 'Не получилось подключить: $e');
                }
              }
            },
          ),
      ],
    );
  }
}
