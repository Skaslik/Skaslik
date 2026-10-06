/// Ядро «МС»: zero-knowledge crypto + pairing + seed-фраза + CRDT-синхронизация.
library ms_core;

export 'src/crypto/primitives.dart';
export 'src/crypto/pairing.dart';
export 'src/crypto/seed_phrase.dart';
export 'src/sync/replica.dart';
export 'src/sync/engine.dart';
export 'src/sync/sync_blob.dart';
export 'src/sync/disk_sync.dart';
export 'src/security/security.dart';
export 'src/domain/calendar.dart';
export 'src/domain/banks.dart';
export 'src/domain/cards.dart';
export 'src/domain/messages.dart';
export 'src/domain/delight.dart';
export 'src/integrations/yandex_disk.dart';
