/// Pre-redesign theme names, kept only so the old screens compile and stay
/// readable in both themes while they are rebuilt (Phases 2–7).
///
/// The colours now follow the active palette ([LegacyPalette.current]), so a
/// light «paper» background no longer sits under light «Вечер» text.
/// **Phase 8 deletes this file.** New code uses `context.ms`, [MsText],
/// [MsSpace] and [MsRadius] instead.
library;

import 'package:flutter/material.dart';

import 'ms_tokens.dart';

/// The palette the legacy getters resolve to. Set by the root widget on
/// every theme change.
abstract final class LegacyPalette {
  static MsPalette current = MsPalette.evening;
}

/// Legacy partner colours → `context.ms.michael` / `context.ms.sofia`.
abstract final class PartnerColors {
  static Color get michael => LegacyPalette.current.michael;
  static Color get sofia => LegacyPalette.current.sofia;
}

/// Legacy colour names mapped onto the tokens.
abstract final class MsColors {
  static Color get ink => LegacyPalette.current.ink;
  static Color get muted => LegacyPalette.current.inkMuted;
  static Color get paper => LegacyPalette.current.ground;
  static Color get paperWarm => LegacyPalette.current.surface;
  static Color get accent => LegacyPalette.current.flame;
  static Color get onAccent => LegacyPalette.current.onFlame;
  static Color get accentSoft => LegacyPalette.current.flameSoft;
  static Color get success => LegacyPalette.current.success;
  static Color get warn => LegacyPalette.current.warn;
  static Color get danger => LegacyPalette.current.danger;

  /// Shared marker. The new UI draws two halves instead (decision #7).
  static LinearGradient get sharedGradient => LinearGradient(
        colors: [PartnerColors.michael, PartnerColors.sofia],
      );
}

/// Legacy text styles. No colour: they inherit `ink` from the theme.
abstract final class MsTypography {
  static const TextStyle display = MsText.screenTitle;
  static const TextStyle title = MsText.title;
  static const TextStyle body = MsText.body;
  static const TextStyle bodySm = MsText.bodySm;
  static const TextStyle caption = MsText.meta;
  static const TextStyle mono = MsText.meta;
}

/// Legacy spacing and radius names mapped onto the tokens.
abstract final class MsTokens {
  static const double radiusSm = MsRadius.radiusSm;
  static const double radiusMd = MsRadius.radiusMd;
  static const double radiusLg = MsRadius.radiusLg;
  static const double spaceXs = MsSpace.space1;
  static const double spaceSm = MsSpace.space2;
  static const double spaceMd = MsSpace.space4;
  static const double spaceLg = MsSpace.space6;
  static const double spaceXl = MsSpace.space8;
}

/// Empty states: one warm sentence, «ты», no emoji (brand-book).
abstract final class MsEmpty {
  static const String calendar =
      'Пока тишина. Добавь первое событие — и календарь оживёт.';
  static const String banks =
      'Ни одной копилки. Начни с «На отпуск» — дальше пойдёт само.';
  static const String docs = 'Папка пуста. Положи сюда первый документ.';
  static const String cards = 'Пока нет карт. Добавь первую — пригодится на кассе.';
  static const String messages = 'Тихо-тихо. Напиши первую записку.';
}
