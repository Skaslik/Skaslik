import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'design_system/ms_theme.dart';
import 'shell/ms_router.dart';

/// One router for the app's lifetime, so a theme change never resets
/// navigation.
final GoRouter _router = buildMsRouter();

/// Edge-to-edge system bars matching the current theme.
Widget msSystemBars(BuildContext context, Widget? child) =>
    AnnotatedRegion<SystemUiOverlayStyle>(
      value: MsTheme.overlay(Theme.of(context).brightness),
      child: child ?? const SizedBox.shrink(),
    );

class MsApp extends ConsumerWidget {
  const MsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      // The old screens read legacy colours that don't listen to the theme;
      // rebuild them on a theme flip. Remove with legacy_theme.dart (Phase 8).
      key: ValueKey(theme.isDay),
      title: 'МС',
      debugShowCheckedModeBanner: false,
      theme: MsTheme.day(),
      darkTheme: MsTheme.evening(),
      themeMode: theme.materialMode,
      builder: msSystemBars,
      routerConfig: _router,
    );
  }
}
