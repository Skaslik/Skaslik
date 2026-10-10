import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'design_system/ms_theme.dart';
import 'features/banks/banks_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/cards/cards_screen.dart';
import 'features/docs/docs_screen.dart';
import 'features/home/home_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/notes/notes_screen.dart';
import 'features/room/room_screen.dart';
import 'features/settings/settings_screen.dart';

/// One router for the app's lifetime, so a theme change never resets
/// navigation.
final GoRouter _router = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
    GoRoute(path: '/banks', builder: (_, __) => const BanksScreen()),
    GoRoute(path: '/docs', builder: (_, __) => const DocsScreen()),
    GoRoute(path: '/cards', builder: (_, __) => const CardsScreen()),
    GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
    GoRoute(path: '/room', builder: (_, __) => const RoomScreen()),
    GoRoute(path: '/notes', builder: (_, __) => const NotesScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);

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
