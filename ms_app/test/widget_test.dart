/// Smoke-тест: приложение запускается и показывает онбординг (свежее
/// устройство без семьи).
///
/// Минимальная гарантия, что [MsRoot] собирает дерево виджетов без
/// исключений: на чистом устройстве (семья не создана) открывается экран
/// приветствия с выбором «Создать семью» / «Присоединиться к семье».
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ms_app/core/lock/app_lock.dart';
import 'package:ms_app/core/providers.dart';
import 'package:ms_app/design_system/theme_controller.dart';
import 'package:ms_app/main.dart';

void main() {
  testWidgets('fresh device boots to onboarding welcome', (tester) async {
    // Разблокированный контроллер (без биометрии), чтобы гейт не мешал.
    final lock = AppLock();
    lock.unlockManually();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockProvider.overrideWith((_) => lock),
          themeControllerProvider.overrideWith(
              (_) => ThemeController(prefs: MemoryThemePrefs())),
        ],
        child: const MsRoot(),
      ),
    );

    // Семья грузится асинхронно из secure storage — даём отработать.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Приветствие: монограмма «МС» и оба пути входа.
    expect(find.text('МС'), findsWidgets);
    expect(find.text('Создать семью'), findsOneWidget);
    expect(find.text('Присоединиться к семье'), findsOneWidget);
  });
}
