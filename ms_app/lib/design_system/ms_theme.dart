/// Дизайн-система «МС»: палитра, типографика, токены.
///
/// Палитра наследует дух иконки: чернила на кремовой бумаге, тёплые акценты.
library;

import 'package:flutter/material.dart';

/// Цвета пары (для событий/вкладов).
class PartnerColors {
  static const Color michael = Color(0xFF3D5A6C); // приглушённый индиго
  static const Color sofia = Color(0xFFB0563B); // тёплый кирпич
}

/// Цветовые токены.
class MsColors {
  MsColors._();

  static const Color ink = Color(0xFF1A1614);
  static const Color paper = Color(0xFFFAF6F0);
  static const Color paperWarm = Color(0xFFF3EBDF);
  static const Color accent = Color(0xFFC4622D); // терракота
  static const Color accentSoft = Color(0xFFE8C4A8);
  static const Color success = Color(0xFF4A7C59);
  static const Color warn = Color(0xFFC99A2E);
  static const Color danger = Color(0xFFA94442);

  /// Общий градиент (для общих событий/объектов).
  static const LinearGradient sharedGradient = LinearGradient(
    colors: [PartnerColors.michael, PartnerColors.sofia],
    stops: [0.0, 1.0],
  );
}

/// Типографика.
class MsTypography {
  MsTypography._();

  static const String _ui = 'Inter';
  static const String _display = 'Inter'; // → позже: Tenor Sans/Playfair

  static const TextStyle display = TextStyle(
      fontFamily: _display, fontSize: 28, fontWeight: FontWeight.w600, color: MsColors.ink);
  static const TextStyle title = TextStyle(
      fontFamily: _ui, fontSize: 20, fontWeight: FontWeight.w600, color: MsColors.ink);
  static const TextStyle body = TextStyle(
      fontFamily: _ui, fontSize: 15, fontWeight: FontWeight.w400, color: MsColors.ink);
  static const TextStyle bodySm = TextStyle(
      fontFamily: _ui, fontSize: 13, fontWeight: FontWeight.w400, color: MsColors.ink);
  static const TextStyle caption = TextStyle(
      fontFamily: _ui, fontSize: 12, fontWeight: FontWeight.w400, color: Colors.black54);
  static const TextStyle mono = TextStyle(
      fontFamily: 'monospace', fontSize: 13, color: MsColors.ink);
}

/// Токены размеров и радиусов.
class MsTokens {
  MsTokens._();
  static const double radiusSm = 8;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
}

/// Тема Material 3 «МС».
class MsTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: MsColors.paper,
      colorScheme: const ColorScheme.light(
        primary: MsColors.accent,
        onPrimary: Colors.white,
        secondary: MsColors.accentSoft,
        surface: MsColors.paper,
        error: MsColors.danger,
      ),
      fontFamily: 'Inter',
      splashFactory: InkSparkle.splashFactory,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: MsColors.paper,
        foregroundColor: MsColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: MsTypography.title,
      ),
      cardTheme: CardThemeData(
        color: MsColors.paperWarm,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MsTokens.radiusMd)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MsColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MsTokens.radiusMd)),
          padding: const EdgeInsets.symmetric(
              horizontal: MsTokens.spaceLg, vertical: 14),
        ),
      ),
      textTheme: base.textTheme.apply(
          bodyColor: MsColors.ink, displayColor: MsColors.ink),
    );
  }
}

/// Пустые состояния — тёплые, с юмором.
class MsEmpty {
  MsEmpty._();
  static const String calendar = 'Пока тишина. Добавьте первое событие — и календарь оживёт.';
  static const String banks = 'Ни одной копилки. Начните с «На отпуск» 🏝';
  static const String docs = 'Папка пуста. Отсканируйте первый документ.';
  static const String cards = 'Пока нет карт. Отсканируйте штрихкод любой карты.';
  static const String messages = 'Тихо-тихо. Напишите первое сообщение.';
}
