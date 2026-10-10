import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';

/// Colour of a progress segment.
enum MsProgressTone { michael, sofia, warn }

/// One segment: whose share and how much.
@immutable
class MsProgressPart {
  const MsProgressPart(this.tone, this.value);
  final MsProgressTone tone;
  final num value;
}

/// 8 px piggy-bank bar split by person (michael / sofia / fines in `warn`),
/// with 2 px gaps on a `surfaceRaised` track.
///
/// Like the CSS, each part is `value / target` of the full width; parts are
/// clamped so they never run past the end.
class MsProgressSplit extends StatelessWidget {
  const MsProgressSplit({
    super.key,
    required this.target,
    required this.parts,
    this.semanticLabel,
  });

  final num target;
  final List<MsProgressPart> parts;

  /// «Собрано 56 %» — the bar alone carries no words.
  final String? semanticLabel;

  /// Pixel widths of the non-empty parts, in order.
  static List<double> layout({
    required double width,
    required num target,
    required List<num> values,
    double gap = MsSize.progressGap,
  }) {
    final out = <double>[];
    if (target <= 0 || width <= 0) return out;
    var remaining = width;
    for (final v in values) {
      if (v <= 0) continue;
      final g = out.isEmpty ? 0.0 : gap;
      final room = math.max(0.0, remaining - g);
      final w = math.min(v / target * width, room).toDouble();
      out.add(w);
      remaining -= w + g;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final duration = MsMotion.of(context, MsMotion.slow);
    final visible = parts.where((p) => p.value > 0).toList();
    Color colorOf(MsProgressTone t) => switch (t) {
          MsProgressTone.michael => ms.michael,
          MsProgressTone.sofia => ms.sofia,
          MsProgressTone.warn => ms.warn,
        };
    return Semantics(
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MsRadius.radiusPill),
        child: ColoredBox(
          color: ms.surfaceRaised,
          child: SizedBox(
            height: MsSize.progressH,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final widths = layout(
                  width: constraints.maxWidth,
                  target: target,
                  values: [for (final p in visible) p.value],
                );
                return Row(
                  children: [
                    for (var i = 0; i < widths.length; i++) ...[
                      if (i > 0) const SizedBox(width: MsSize.progressGap),
                      AnimatedContainer(
                        duration: duration,
                        width: widths[i],
                        color: colorOf(visible[i].tone),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
