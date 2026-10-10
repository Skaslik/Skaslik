import 'package:flutter/painting.dart';

import '../ms_tokens.dart';

/// Who an item belongs to.
///
/// Partner colours are author marks only (dot, bar, progress segment, pin).
/// Shared items show two halves, never a third colour (decision #7).
enum MsAuthor { michael, sofia, both }

extension MsAuthorColors on MsAuthor {
  /// Flat mark colour. For [MsAuthor.both] draw [halves] instead.
  Color color(MsPalette p) => switch (this) {
        MsAuthor.michael => p.michael,
        MsAuthor.sofia => p.sofia,
        MsAuthor.both => p.michael,
      };

  /// Soft fill under the mark (selected person chip, own note bubble).
  Color soft(MsPalette p) => switch (this) {
        MsAuthor.michael => p.michaelSoft,
        MsAuthor.sofia => p.sofiaSoft,
        MsAuthor.both => p.surfaceRaised,
      };

  /// Two hard-stop halves (michael, then sofia) for [MsAuthor.both];
  /// `null` for a single author.
  Gradient? halves(MsPalette p, {Axis axis = Axis.vertical}) {
    if (this != MsAuthor.both) return null;
    final vertical = axis == Axis.vertical;
    return LinearGradient(
      begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
      end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
      colors: [p.michael, p.michael, p.sofia, p.sofia],
      stops: const [0, 0.5, 0.5, 1],
    );
  }
}
