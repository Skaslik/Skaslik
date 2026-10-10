/// Badge dots on the tab bar: something new from the partner waits there.
///
/// «New» = the partner created or changed something after this phone last
/// opened the tab. «Last opened» is local to the phone (not synced).
/// Sources so far: calendar (Phase 4), files (Phase 5). Notes: Phase 7.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ms_core/ms_core.dart';

import '../core/pair/pair.dart';
import '../core/providers.dart';
import '../core/storage/local_file.dart';
import '../design_system/widgets/ms_author.dart';
import 'ms_shell.dart';

abstract interface class SeenStore {
  Map<String, int> read();
  void write(Map<String, int> seen);
}

class FileSeenStore implements SeenStore {
  FileSeenStore({String? dataDir})
      : _file = LocalFile.forDomain('prefs_seen', dataDir: dataDir);
  final LocalFile _file;

  @override
  Map<String, int> read() {
    try {
      final raw = _file.read();
      if (raw == null) return {};
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  @override
  void write(Map<String, int> seen) => _file.write(jsonEncode(seen));
}

class MemorySeenStore implements SeenStore {
  Map<String, int> value = {};
  @override
  Map<String, int> read() => Map.of(value);
  @override
  void write(Map<String, int> seen) => value = Map.of(seen);
}

/// When this phone last opened each tab.
class TabSeen extends ChangeNotifier {
  TabSeen(this._store, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _seen = _store.read();
    // First run: older history doesn't count as news.
    final now = _clock().millisecondsSinceEpoch;
    var changed = false;
    for (final t in MsTab.values) {
      if (!_seen.containsKey(t.name)) {
        _seen[t.name] = now;
        changed = true;
      }
    }
    if (changed) _store.write(_seen);
  }

  final SeenStore _store;
  final DateTime Function() _clock;
  late Map<String, int> _seen;

  int seenAt(MsTab tab) => _seen[tab.name] ?? 0;

  void markSeen(MsTab tab) {
    _seen[tab.name] = _clock().millisecondsSinceEpoch;
    _store.write(_seen);
    notifyListeners();
  }
}

final tabSeenProvider =
    ChangeNotifierProvider<TabSeen>((ref) => TabSeen(FileSeenStore()));

/// Latest time (ms) the partner created or changed a calendar event.
int? calendarPartnerActivity(Iterable<CalEvent> events, Pair pair) {
  int? latest;
  void see(int? t) {
    if (t != null && (latest == null || t > latest!)) latest = t;
  }

  for (final e in events) {
    if (e.ownerId != null && !pair.isMine(e.ownerId)) see(e.createdAt);
    if (e.editedBy != null && !pair.isMine(e.editedBy)) see(e.editedAt);
  }
  return latest;
}

/// Latest time (ms) the partner added a file to the shared folder.
int? filesPartnerActivity(Iterable<DocMeta> docs, Pair pair) {
  int? latest;
  for (final d in docs) {
    final at = d.at;
    if (at == null || d.uploadedBy == null || pair.isMine(d.uploadedBy)) continue;
    if (latest == null || at > latest) latest = at;
  }
  return latest;
}

/// Tabs with news from the partner, in the partner's colour.
final tabBadgesProvider = Provider<Map<MsTab, MsAuthor>>((ref) {
  final pair = ref.watch(pairProvider);
  final seen = ref.watch(tabSeenProvider);
  final calendar = CalendarRepo(ref.watch(calendarProvider).replica).all();
  final out = <MsTab, MsAuthor>{};
  final cal = calendarPartnerActivity(calendar, pair);
  if (cal != null && cal > seen.seenAt(MsTab.calendar)) {
    out[MsTab.calendar] = pair.partner.author;
  }
  final files =
      filesPartnerActivity(DocsRepo(ref.watch(docsProvider).replica).all(), pair);
  if (files != null && files > seen.seenAt(MsTab.files)) {
    out[MsTab.files] = pair.partner.author;
  }
  return out;
});
