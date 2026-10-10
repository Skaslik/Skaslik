import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';
import 'package:ms_core/ms_core.dart';

import '../../core/candle/candle_controller.dart';
import '../../core/lock/app_lock.dart';
import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_all.dart';
import '../../core/weather/weather.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/theme_controller.dart';
import '../../design_system/widgets/widgets.dart';
import 'home_texts.dart';
import 'room_scene.dart';
import 'today_sheet.dart';
import 'weather_sheet.dart';

/// «Дом»: the room on top, the «Сегодня» sheet below (decision #1).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _minute;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Greeting and sky follow the clock.
    _minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    unawaited(_maybeSyncOnStart());
  }

  @override
  void dispose() {
    _minute?.cancel();
    super.dispose();
  }

  /// Once after start: sync if Yandex.Disk is connected and paired. The
  /// service loads its token asynchronously; give it up to ~3 s.
  Future<void> _maybeSyncOnStart() async {
    for (var i = 0; i < 5; i++) {
      if (!mounted) return;
      if (ref.read(syncServiceProvider).connected) break;
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    if (!mounted) return;
    await syncAllNow(ref);
  }

  RoomNote? _wallNote(Pair pair) {
    final store = ref.watch(messagesProvider);
    final views = MessagesRepo(store.replica, deviceId: pair.myDeviceId)
        .render(_now)
        .where((v) =>
            v.m.kind == MsgKind.text &&
            v.revealed &&
            v.burnState == BurnState.live &&
            (v.m.text ?? '').trim().isNotEmpty &&
            !pair.isMine(v.m.from))
        .toList();
    if (views.isEmpty) return null;
    final m = views.last.m;
    final by = pair.memberOf(m.from);
    return RoomNote(text: m.text!.trim(), sign: by.initial, author: by.author);
  }

  void _onCandleTap(CandleController candle) {
    if (!candle.info.lit) {
      candle.light();
      unawaited(syncAllNow(ref));
    } else {
      MsToast.show(context, 'Свеча горит. Погасить — долгое нажатие');
    }
  }

  void _onCandleLongPress(CandleController candle) {
    if (!candle.info.lit) return;
    candle.putOut();
    MsToast.show(context, 'Свеча погасла у обоих');
    unawaited(syncAllNow(ref));
  }

  @override
  Widget build(BuildContext context) {
    final pair = ref.watch(pairProvider);
    final candle = ref.watch(candleProvider);
    final weather = ref.watch(weatherProvider).last;
    final day = Theme.of(context).brightness == Brightness.light;
    final view = RoomWeatherView.of(
      w: weather,
      daylight: isDaylight(_now, kDefaultCity.lat, kDefaultCity.lng),
      now: _now,
      city: kDefaultCity.name,
      time: formatTime,
    );

    return LayoutBuilder(builder: (context, c) {
      final scale = c.maxWidth / RoomGeo.w;
      final sheetTop = RoomGeo.sheetTop * scale;
      final h = c.maxHeight;
      final initial = ((h - sheetTop) / h).clamp(0.25, 1.0);
      final max =
          ((h - MediaQuery.paddingOf(context).top) / h).clamp(initial, 1.0);
      return Stack(children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: RoomScene(
            day: day,
            weather: view,
            candleLit: candle.info.lit,
            candleLabel: candleSpoken(candle.info, pair),
            note: _wallNote(pair),
            onWindow: () => showWeatherSheet(context),
            onCandleTap: () => _onCandleTap(candle),
            onCandleLongPress: () => _onCandleLongPress(candle),
            onDog: () => MsToast.show(
                context, 'Басенджи не лают — зато внимательно смотрят'),
            onFrameTap: appLock.onMonogramTap,
            onNote: () => context.go('/us/notes'),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: initial,
          minChildSize: initial,
          maxChildSize: max,
          snap: true,
          builder: (context, controller) =>
              TodaySheet(controller: controller, now: _now),
        ),
      ]);
    });
  }
}
