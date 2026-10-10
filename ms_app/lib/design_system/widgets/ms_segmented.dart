import 'package:flutter/material.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';
import 'ms_tap_target.dart';

/// One option of an [MsSegmented].
@immutable
class MsSegment<T> {
  const MsSegment(this.value, this.label);
  final T value;
  final String label;
}

/// Segmented control for views of one screen («Месяц / Неделя / Список»).
/// Track `surface`; the selected segment is `surfaceRaised` with a 1 px
/// `line` ring. Three segments at most (components/Chips.md).
class MsSegmented<T> extends StatelessWidget {
  const MsSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<MsSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.ms.surface,
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.all(MsSize.segmentPad),
        child: Row(
          spacing: MsSize.segmentPad,
          children: [
            for (final s in segments)
              Expanded(
                child: _SegmentButton(
                  label: s.label,
                  selected: s.value == value,
                  onTap: () => onChanged(s.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final radius = BorderRadius.circular(MsRadius.radiusPill);
    final ring = selected ? ms.line : ms.line.withValues(alpha: 0);
    return MsTapTarget(
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: MsMotion.of(context, MsMotion.fast),
            height: MsSize.segmentH,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? ms.surfaceRaised
                  : ms.surfaceRaised.withValues(alpha: 0),
              borderRadius: radius,
              boxShadow: [
                BoxShadow(color: ring, spreadRadius: MsSize.hairline)
              ],
            ),
            child: Text(
              label,
              style: (selected ? MsTextX.controlOn : MsTextX.control)
                  .copyWith(color: selected ? ms.ink : ms.inkMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
