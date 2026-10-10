import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/weather/weather.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/theme_controller.dart';
import '../../design_system/widgets/widgets.dart';

/// Opens the forecast for the window (tap on the window in the room).
Future<void> showWeatherSheet(BuildContext context) => showMsSheet<void>(
      context,
      builder: (_) => const WeatherSheet(),
    );

/// «МОСКВА · СЕЙЧАС», big temperature and condition, feels-like and wind,
/// six hourly tiles, and an honest source line.
class WeatherSheet extends ConsumerWidget {
  const WeatherSheet({super.key, this.now});

  /// For tests; defaults to the clock.
  final DateTime? now;

  static const double tempSize = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = context.ms;
    final w = ref.watch(weatherProvider).last;
    final city = kDefaultCity.name;
    final t = now ?? DateTime.now();
    if (w == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MsEyebrow('$city · сейчас'),
          const SizedBox(height: MsSpace.space3),
          Text(
            'Погоды пока нет — появится, когда будет сеть.',
            style: MsText.body.copyWith(color: ms.ink),
          ),
          const SizedBox(height: MsSpace.space4),
          const MsMeta('Open-Meteo · по городу, без геопозиции'),
        ],
      );
    }
    final tiles = sixTiles(w.hours, t);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MsEyebrow('$city · сейчас'),
        const SizedBox(height: MsSpace.space2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: MsSpace.space3,
          children: [
            Text(formatTemp(w.temp),
                style: MsText.weatherTemp
                    .copyWith(fontSize: tempSize, height: 1, color: ms.ink)),
            Expanded(
              child: Text(w.label,
                  style: MsText.titleSm.copyWith(color: ms.ink)),
            ),
          ],
        ),
        const SizedBox(height: MsSpace.space2),
        MsMeta(
            'ощущается как ${formatTemp(w.feels)} · ветер ${w.wind.round()} м/с'),
        if (tiles.isNotEmpty) ...[
          const SizedBox(height: MsSpace.space4),
          Row(
            spacing: MsSpace.space2,
            children: [
              for (final h in tiles) Expanded(child: _HourTile(h)),
            ],
          ),
        ],
        const SizedBox(height: MsSpace.space4),
        MsMeta(
          'Open-Meteo · по городу, без геопозиции · обновлено ${formatTime(w.fetchedAt)}',
          maxLines: 2,
        ),
      ],
    );
  }
}

class _HourTile extends StatelessWidget {
  const _HourTile(this.h);
  final WeatherHour h;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: MsSpace.space3),
      decoration: BoxDecoration(
        color: ms.surface,
        borderRadius: BorderRadius.circular(MsRadius.radiusMd),
      ),
      child: Column(
        spacing: MsSpace.space1,
        children: [
          Text(formatTime(h.time),
              style: MsText.meta.copyWith(color: ms.inkMuted)),
          Text(formatTemp(h.temp),
              style: MsText.numberMd.copyWith(color: ms.ink)),
          Text(
            weatherLabelFor(h.code),
            style: MsText.meta.copyWith(color: ms.inkMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
