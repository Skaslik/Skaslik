import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../design_system/ms_sizes.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/cards/card_checkout_screen.dart';
import '../features/files/files_screen.dart';
import '../features/home/home_screen.dart';
import '../features/together/together_screen.dart';
import '../features/us/notes_screen.dart';
import '../features/us/us_screen.dart';
import 'ms_shell.dart';

/// Old routes keep working (IMPLEMENTATION.md Phase 2).
const Map<String, String> kLegacyRedirects = {
  '/room': '/home',
  '/docs': '/files',
  '/banks': '/together?seg=banks',
  '/notes': '/together?seg=lists',
  '/cards': '/together?seg=cards',
  '/messages': '/us/notes',
  '/settings': '/us',
};

/// Five-branch shell. Each tab keeps its own navigation stack.
GoRouter buildMsRouter({String initialLocation = '/home'}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        for (final e in kLegacyRedirects.entries)
          GoRoute(path: e.key, redirect: (_, __) => e.value),
        // The card at the checkout: full screen, over the tab bar, fast.
        GoRoute(
          path: '/card/:id',
          pageBuilder: (_, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: MsMotion.fast,
            reverseTransitionDuration: MsMotion.fast,
            child: CardCheckoutScreen(cardId: state.pathParameters['id']!),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => MsShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: MsTab.home.path,
                  builder: (_, __) => const HomeScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: MsTab.calendar.path,
                  builder: (_, state) => CalendarScreen(
                      initialDay: CalendarScreen.parseDay(
                          state.uri.queryParameters['day']))),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: MsTab.files.path,
                  builder: (_, __) => const FilesScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: MsTab.together.path,
                builder: (_, state) => TogetherScreen(
                    seg: TogetherSeg.parse(state.uri.queryParameters['seg'])),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: MsTab.us.path,
                builder: (_, __) => const UsScreen(),
                routes: [
                  GoRoute(
                      path: 'notes', builder: (_, __) => const NotesScreen()),
                ],
              ),
            ]),
          ],
        ),
      ],
    );
