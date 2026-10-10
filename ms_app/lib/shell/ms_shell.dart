import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design_system/widgets/widgets.dart';
import 'tab_badges.dart';

/// The five tabs, in order (screens.md).
enum MsTab {
  home('Дом', Symbols.cottage_rounded, '/home'),
  calendar('Календарь', Symbols.calendar_month_rounded, '/calendar'),
  files('Файлы', Symbols.folder_open_rounded, '/files'),
  together('Вместе', Symbols.join_inner_rounded, '/together'),
  us('Мы', Symbols.favorite_rounded, '/us');

  const MsTab(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}

/// App frame: the active branch above the [MsTabBar]. Tabs with news from
/// the partner carry a dot in the partner's colour, except the open one.
class MsShell extends ConsumerWidget {
  const MsShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(tabBadgesProvider);
    final current = MsTab.values[shell.currentIndex];
    return Scaffold(
      body: shell,
      bottomNavigationBar: MsTabBar(
        items: [
          for (final t in MsTab.values)
            MsTabItem(
              icon: t.icon,
              label: t.label,
              badge: t == current ? null : badges[t],
            ),
        ],
        currentIndex: shell.currentIndex,
        onTap: (i) {
          final seen = ref.read(tabSeenProvider);
          // Leaving a tab and entering one both count as having seen it.
          seen.markSeen(current);
          seen.markSeen(MsTab.values[i]);
          // Tapping the active tab again returns to its first screen.
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
      ),
    );
  }
}
