/// One place that lists every domain store for a full L3 sync. Calls the
/// existing [SyncService.syncAll]; the sync logic itself is unchanged.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'domain_store.dart';
import 'sync_service.dart';

Map<MsDomain, MsStore> allDomainStores(WidgetRef ref) => {
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
    };

/// When this session last finished a full sync (shown in Files). Kept by
/// the app, not by the sync service.
final lastSyncProvider = StateProvider<DateTime?>((ref) => null);

/// Sync every domain now if Yandex.Disk is connected. Never throws; the
/// status lives in [SyncService.state].
Future<void> syncAllNow(WidgetRef ref) async {
  final sync = ref.read(syncServiceProvider);
  if (!sync.connected) return;
  try {
    await sync.syncAll(allDomainStores(ref));
    if (sync.state == SyncState.synced) {
      ref.read(lastSyncProvider.notifier).state = DateTime.now();
    }
  } catch (_) {
    // Shown through SyncService.state / detail.
  }
}
