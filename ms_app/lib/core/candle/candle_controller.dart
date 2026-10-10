/// The shared candle on this device: light, put out, notice the partner's
/// light after a merge, and go out at local midnight (decision #9).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ms_core/ms_core.dart';

import '../notify/notifications.dart';
import '../pair/pair.dart';
import '../providers.dart';
import '../storage/local_file.dart';
import '../sync/domain_store.dart';

/// Decision #9 default: out at local midnight or on a long press of this
/// length.
const Duration kCandleLongPress = Duration(milliseconds: 650);

/// Remembers which partner light was already announced, so a restart does
/// not repeat «София зажгла свечу».
abstract interface class CandleNotifiedStore {
  int? read();
  void write(int litAt);
}

class FileCandleNotifiedStore implements CandleNotifiedStore {
  FileCandleNotifiedStore({String? dataDir})
      : _file = LocalFile.forDomain('prefs_candle', dataDir: dataDir);
  final LocalFile _file;

  @override
  int? read() {
    try {
      final raw = _file.read();
      return raw == null
          ? null
          : (jsonDecode(raw) as Map<String, dynamic>)['notifiedLitAt'] as int?;
    } catch (_) {
      return null;
    }
  }

  @override
  void write(int litAt) => _file.write(jsonEncode({'notifiedLitAt': litAt}));
}

class MemoryCandleNotifiedStore implements CandleNotifiedStore {
  int? value;
  @override
  int? read() => value;
  @override
  void write(int litAt) => value = litAt;
}

class CandleController extends ChangeNotifier {
  CandleController({
    required MsStore store,
    required Pair pair,
    required CandleNotifiedStore notified,
    this.onPartnerLit,
    DateTime Function()? clock,
  })  : _store = store,
        _pair = pair,
        _notified = notified,
        _clock = clock ?? DateTime.now,
        _repo = CandleRepo(store.replica) {
    _store.addListener(_onStore);
    // Not inside the constructor: writing «seen» while a provider is being
    // built is not allowed, so look at the candle right after.
    scheduleMicrotask(_onStore);
  }

  final MsStore _store;
  final Pair _pair;
  final CandleNotifiedStore _notified;
  final DateTime Function() _clock;
  final CandleRepo _repo;

  /// Called once per partner light that reaches this device.
  final void Function(PairMember by)? onPartnerLit;

  Timer? _midnight;
  bool _inStore = false;

  CandleInfo get info => _repo.state(
      me: _pair.myDeviceId, partner: _pair.partnerDeviceId, now: _clock());

  Pair get pair => _pair;

  void light() {
    _repo.light(_pair.myDeviceId, _clock().millisecondsSinceEpoch);
    _store.persist();
  }

  void putOut() {
    _repo.putOut(_pair.myDeviceId, _clock().millisecondsSinceEpoch);
    _store.persist();
  }

  bool _disposed = false;

  void _onStore() {
    if (_inStore || _disposed) return;
    _inStore = true;
    try {
      final i = info;
      if (i.state == CandleState.partner && i.litAt != null) {
        // The light reached this device: tell the partner's phone.
        final wrote =
            _repo.markSeen(_pair.myDeviceId, _clock().millisecondsSinceEpoch);
        if (_notified.read() != i.litAt) {
          _notified.write(i.litAt!);
          onPartnerLit?.call(_pair.memberOf(i.litBy));
        }
        if (wrote) _store.persist();
      }
      _scheduleMidnight(i);
    } finally {
      _inStore = false;
    }
    if (!_disposed) notifyListeners();
  }

  void _scheduleMidnight(CandleInfo i) {
    _midnight?.cancel();
    _midnight = null;
    if (!i.lit) return;
    final now = _clock();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), () {
      _midnight = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _store.removeListener(_onStore);
    _midnight?.cancel();
    super.dispose();
  }
}

/// The candle on this phone. The partner's light raises «София зажгла
/// свечу» on the «Ритуалы» channel.
final candleProvider = ChangeNotifierProvider<CandleController>((ref) {
  // `.notifier`: hold the store, don't rebuild on each of its changes —
  // the controller listens to the store itself.
  return CandleController(
    store: ref.watch(ritualProvider.notifier),
    pair: ref.watch(pairProvider),
    notified: FileCandleNotifiedStore(),
    onPartnerLit: (by) =>
        MsNotifications.candleLit(text: '${by.name} ${by.verb('зажёг')} свечу'),
  );
});
