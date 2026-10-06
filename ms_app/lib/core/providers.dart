/// Провайдеры доменных хранилищ (Riverpod).
///
/// Один [MsStore] на домен. Экземпляр живёт на время приложения и
/// автоматически персистит op-log в local-first JSON.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import 'family/family.dart';
import 'sync/domain_store.dart';
import 'sync/sync_service.dart';

/// Провайдер доменного хранилища для произвольного [MsDomain].
///
/// [ChangeNotifierProvider]: [MsStore] — ChangeNotifier, и только так
/// `notifyListeners()` при записи перестраивает наблюдающие виджеты.
ChangeNotifierProvider<MsStore> storeProvider(MsDomain domain) =>
    ChangeNotifierProvider<MsStore>(
        (ref) => MsStore(
            deviceId: family.deviceId ?? 'local', domain: domain));

final calendarProvider = storeProvider(MsDomain.calendar);
final banksProvider = storeProvider(MsDomain.banks);
final cardsProvider = storeProvider(MsDomain.cards);
final docsProvider = storeProvider(MsDomain.docs);
final messagesProvider = storeProvider(MsDomain.messages);
final notesProvider = storeProvider(MsDomain.notes);
final clipsProvider = storeProvider(MsDomain.clips);
final pulseProvider = storeProvider(MsDomain.pulse);

/// Провайдер семьи: грузит секреты из secure storage при создании.
final familyProvider = ChangeNotifierProvider<Family>((ref) {
  final f = family;
  f.load();
  return f;
});
final ritualProvider = storeProvider(MsDomain.ritual);
final capsuleProvider = storeProvider(MsDomain.capsule);

/// Провайдер L3-синхронизации (инициализируется на старте приложения).
final syncServiceProvider = ChangeNotifierProvider<SyncService>((ref) {
  final s = syncService;
  s.init();
  return s;
});
