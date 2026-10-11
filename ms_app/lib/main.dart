import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import 'app.dart';
import 'core/box/private_box.dart';
import 'core/lock/app_lock.dart';
import 'core/lock/fake_calculator.dart';
import 'core/notify/notifications.dart';
import 'core/providers.dart';
import 'core/storage/app_paths.dart';
import 'core/weather/weather.dart';
import 'design_system/ms_format.dart';
import 'design_system/ms_theme.dart';
import 'features/lock/lock_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.init();
  await initMsFormat();
  _registerFontLicenses();
  // Edge-to-edge: the real status bar over our `ground`, no fake bar.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  // Локальные уведомления (каналы + таймзона). Не блокирует старт.
  unawaited(MsNotifications.init()
      .then((_) => MsNotifications.requestPermission())
      .catchError((_) {}));
  runApp(const ProviderScope(child: MsRoot()));
}

/// Ship the OFL licences of the bundled fonts (shown in the licence page).
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Onest', 'OFL-Onest.txt'),
      ('IBM Plex Mono', 'OFL-IBMPlexMono.txt'),
      ('PT Serif', 'OFL-PTSerif.txt'),
    ]) {
      final text = await rootBundle.loadString('assets/fonts/$file');
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
}

/// Провайдер блокировки (глобальный singleton).
final appLockProvider = ChangeNotifierProvider<AppLock>((ref) => appLock);



/// Корневой виджет: onboarding → гейт → приложение (или фейк-калькулятор).
class MsRoot extends ConsumerStatefulWidget {
  const MsRoot({super.key});

  @override
  ConsumerState<MsRoot> createState() => _MsRootState();
}

class _MsRootState extends ConsumerState<MsRoot> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Загрузка PIN-флага и семьи (both async, не блокирующие старт).
    appLock.loadPin();
    // Timers don't run while suspended: re-check sunrise/sunset on resume.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(themeControllerProvider).refresh();
        if (ref.exists(weatherProvider)) ref.read(weatherProvider).refresh();
        if (ref.exists(privateBoxProvider)) {
          ref.read(privateBoxProvider).onAppResumed();
        }
      },
      onHide: () {
        if (ref.exists(weatherProvider)) ref.read(weatherProvider).pause();
        // The safe never stays open behind another app.
        if (ref.exists(privateBoxProvider)) {
          ref.read(privateBoxProvider).onAppHidden();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    final fam = ref.watch(familyProvider);
    final theme = ref.watch(themeControllerProvider);
    // Locking the app or entering fake mode closes the safe as well.
    ref.listen<AppLock>(appLockProvider, (_, l) {
      if ((l.inFake || !l.unlocked) && ref.exists(privateBoxProvider)) {
        ref.read(privateBoxProvider).lock();
      }
    });

    // Fake mode: калькулятор — реальных данных нет. A neutral system look:
    // no МС theme, fonts or mark (components/ScreenLock.md).
    if (lock.inFake) {
      return MaterialApp(
        title: 'Калькулятор',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: FakeCalculator(lock: lock),
      );
    }
    // Семья ещё не создана → онбординг.
    if (fam.loaded && !fam.isSet) {
      return MaterialApp(
        title: 'МС',
        debugShowCheckedModeBanner: false,
        theme: MsTheme.day(),
        darkTheme: MsTheme.evening(),
        themeMode: theme.materialMode,
        builder: msSystemBars,
        home: OnboardingScreen(onDone: () => lock.unlockManually()),
      );
    }
    // Не разблокировано → гейт (биометрия / PIN).
    if (!lock.unlocked) {
      return MaterialApp(
        title: 'МС',
        debugShowCheckedModeBanner: false,
        theme: MsTheme.day(),
        darkTheme: MsTheme.evening(),
        themeMode: theme.materialMode,
        builder: msSystemBars,
        home: LockScreen(lock: lock),
      );
    }
    return const MsApp();
  }
}

