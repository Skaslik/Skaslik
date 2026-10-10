import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import 'app.dart';
import 'core/lock/app_lock.dart';
import 'core/lock/fake_calculator.dart';
import 'core/notify/notifications.dart';
import 'core/providers.dart';
import 'core/storage/app_paths.dart';
import 'core/weather/weather.dart';
import 'design_system/ms_format.dart';
import 'design_system/ms_theme.dart';
import 'design_system/widgets/ms_monogram.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/pin_pad.dart';

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
      },
      onHide: () {
        if (ref.exists(weatherProvider)) ref.read(weatherProvider).pause();
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
    LegacyPalette.current = theme.palette;

    // Fake mode: калькулятор — реальных данных нет. Neutral look, no МС
    // theme (restyled in Phase 7).
    if (lock.inFake) {
      return MaterialApp(
        title: 'Калькулятор',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const FakeCalculator(),
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
        home: _UnlockGate(lock: lock, pinSet: lock.pinSet),
      );
    }
    return const MsApp();
  }
}

/// Гейт разблокировки: монограмма + биометрия / PIN.
class _UnlockGate extends ConsumerWidget {
  const _UnlockGate({required this.lock, required this.pinSet});
  final AppLock lock;
  final bool pinSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MsTokens.spaceLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: lock.onMonogramTap,
                  child: const MsMonogram(size: 80),
                ),
                const SizedBox(height: MsTokens.spaceMd),
                const Text('МС', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                const SizedBox(height: MsTokens.spaceLg),
                if (pinSet)
                  const _PinGate()
                else ...[
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await lock.tryUnlock();
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Биометрия не сработала.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Войти'),
                  ),
                  TextButton(
                    onPressed: lock.unlockManually,
                    child: const Text('Войти без блокировки'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PIN-гейт: биометрия в один тап, PIN-клавиатура как fallback.
class _PinGate extends StatefulWidget {
  const _PinGate();

  @override
  State<_PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<_PinGate> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: () async {
            final ok = await appLock.tryUnlock();
            if (!ok && context.mounted) {
              setState(() =>
                  _error = 'Биометрия не сработала. Введите PIN.');
            }
          },
          icon: const Icon(Icons.fingerprint),
          label: const Text('Открыть биометрией'),
        ),
        const SizedBox(height: MsTokens.spaceSm),
        const Text('или PIN', style: MsTypography.bodySm),
        const SizedBox(height: MsTokens.spaceSm),
        PinPad(
          length: 4,
          onComplete: (pin) async {
            final ok = await appLock.verifyPin(pin);
            if (!ok && context.mounted) {
              setState(() => _error = 'Неверный PIN');
            }
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: MsTokens.spaceSm),
          Text(_error!,
              style: MsTypography.bodySm.copyWith(color: MsColors.danger)),
        ],
      ],
    );
  }
}
