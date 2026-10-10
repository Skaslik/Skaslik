import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../ms_sizes.dart';

/// Gives a small control (a 32 px segment, a 36 px pill, a text link) a
/// 48 × 48 touch area without moving a pixel: the layout size stays the
/// child's, while touches and the accessibility frame reach out to
/// [MsSize.tapMin] around its centre.
///
/// A touch in the margin counts as a touch at the nearest point of the
/// child, so the child's own InkWell or GestureDetector handles it. Where
/// a neighbour overlaps the margin, whichever is painted later wins — the
/// way Flutter resolves any overlap.
///
/// The wrapper is the semantics node of the control: put it outside the
/// control's `Semantics` and don't mark that one `container`.
class MsTapTarget extends SingleChildRenderObjectWidget {
  const MsTapTarget({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTapTarget();
}

class _RenderTapTarget extends RenderProxyBox {
  Rect get _area {
    final dx = math.max(0.0, (MsSize.tapMin - size.width) / 2);
    final dy = math.max(0.0, (MsSize.tapMin - size.height) / 2);
    return Rect.fromLTRB(-dx, -dy, size.width + dx, size.height + dy);
  }

  @override
  Rect get semanticBounds => _area;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null || !_area.contains(position)) return false;
    if (size.contains(position)) return super.hitTest(result, position: position);
    // In the margin: hand the touch to the nearest point inside the child.
    final p = Offset(
      position.dx.clamp(0.0, math.max(0.0, size.width - 1)),
      position.dy.clamp(0.0, math.max(0.0, size.height - 1)),
    );
    final hit = result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(p),
      position: p,
      hitTest: (r, q) => c.hitTest(r, position: q),
    );
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }
}
