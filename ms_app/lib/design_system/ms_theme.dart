/// «МС» Material theme built from the design tokens.
///
/// Two themes: «Вечер» ([MsTheme.evening], dark, default) and «День»
/// ([MsTheme.day]). Widgets read colours through `context.ms` (the
/// [MsThemeExtension] registered here), text through [MsText] / [MsTextX],
/// spacing through [MsSpace], radii through [MsRadius].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ms_sizes.dart';
import 'ms_tokens.dart';

export 'legacy_theme.dart';
export 'ms_sizes.dart';
export 'ms_tokens.dart';

abstract final class MsTheme {
  static final ThemeData _evening = _build(MsPalette.evening, Brightness.dark);
  static final ThemeData _day = _build(MsPalette.day, Brightness.light);

  /// «Вечер» — the default, dark theme.
  static ThemeData evening() => _evening;

  /// «День» — paper from the icon.
  static ThemeData day() => _day;

  /// Edge-to-edge system bars: transparent, icons contrasting with `ground`.
  static SystemUiOverlayStyle overlay(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final icons = dark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: icons,
      statusBarBrightness: brightness, // iOS: the bar's background brightness
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: icons,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }

  static TextTheme _textTheme(MsPalette p) => const TextTheme(
        headlineMedium: MsText.screenTitle,
        titleLarge: MsText.title,
        titleMedium: MsText.titleSm,
        titleSmall: MsText.bodyStrong,
        bodyLarge: MsText.body,
        bodyMedium: MsText.body,
        bodySmall: MsText.bodySm,
        labelLarge: MsText.bodyStrong,
        labelMedium: MsText.tabLabel,
        labelSmall: MsText.meta,
      ).apply(bodyColor: p.ink, displayColor: p.ink);

  static ThemeData _build(MsPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.flame,
      onPrimary: p.onFlame,
      primaryContainer: p.flameSoft,
      onPrimaryContainer: p.ink,
      secondary: p.flame,
      onSecondary: p.onFlame,
      secondaryContainer: p.flameSoft,
      onSecondaryContainer: p.ink,
      tertiary: p.link,
      onTertiary: p.ground,
      error: p.danger,
      onError: p.onDanger,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.inkMuted,
      surfaceDim: p.ground,
      surfaceBright: p.surfaceRaised,
      surfaceContainerLowest: p.ground,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceRaised,
      surfaceContainerHighest: p.surfaceRaised,
      outline: p.line,
      outlineVariant: p.line,
      scrim: p.scrim,
      inverseSurface: p.ink,
      onInverseSurface: p.ground,
      inversePrimary: p.flame,
      surfaceTint: Colors.transparent,
    );
    final radiusMd = BorderRadius.circular(MsRadius.radiusMd);
    final radiusLg = BorderRadius.circular(MsRadius.radiusLg);
    final shapeMd = RoundedRectangleBorder(borderRadius: radiusMd);
    final fieldBorder = OutlineInputBorder(
      borderRadius: radiusMd,
      borderSide: BorderSide(color: p.line, width: MsSize.hairline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.ground,
      canvasColor: p.ground,
      dividerColor: p.line,
      fontFamily: MsFonts.sans,
      textTheme: _textTheme(p),
      extensions: [MsThemeExtension(p)],
      splashFactory: InkRipple.splashFactory,
      iconTheme: IconThemeData(color: p.ink, size: MsSize.icon),
      appBarTheme: AppBarTheme(
        backgroundColor: p.ground,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: MsText.title.copyWith(color: p.ink),
        systemOverlayStyle: overlay(brightness),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shapeMd,
      ),
      dividerTheme: DividerThemeData(
        color: p.line,
        thickness: MsSize.hairline,
        space: MsSize.hairline,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.flame,
          foregroundColor: p.onFlame,
          minimumSize: const Size(0, MsSize.buttonH),
          padding: const EdgeInsets.symmetric(horizontal: MsSize.buttonPadH),
          shape: shapeMd,
          textStyle: MsTextX.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: p.surfaceRaised,
          foregroundColor: p.ink,
          minimumSize: const Size(0, MsSize.buttonH),
          side: BorderSide(color: p.line, width: MsSize.hairline),
          shape: shapeMd,
          textStyle: MsTextX.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.link,
          textStyle: MsTextX.link,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.flame,
        foregroundColor: p.onFlame,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: MsTextX.button,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: MsText.body.copyWith(color: p.inkMuted),
        labelStyle: MsText.body.copyWith(color: p.inkMuted),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: MsSize.fieldPadH, vertical: MsSpace.space3),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: p.focusRing, width: MsSize.hairline * 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: p.danger, width: MsSize.hairline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radiusLg),
        titleTextStyle: MsText.title.copyWith(color: p.ink),
        contentTextStyle: MsText.body.copyWith(color: p.ink),
        barrierColor: p.scrim,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.ground,
        modalBackgroundColor: p.ground,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: p.scrim,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(MsRadius.radiusLg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: MsTextX.toast.copyWith(color: p.ground),
        actionTextColor: p.ground,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: shapeMd,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.inkMuted,
        textColor: p.ink,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.flame,
        linearTrackColor: p.surfaceRaised,
        circularTrackColor: Colors.transparent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.flame,
        selectionColor: p.flameSoft,
        selectionHandleColor: p.flame,
      ),
    );
  }
}
