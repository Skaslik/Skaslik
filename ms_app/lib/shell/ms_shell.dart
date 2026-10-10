import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design_system/widgets/widgets.dart';

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

/// App frame: the active branch above the [MsTabBar].
///
/// [badges] marks tabs where something new from the partner waits. Sources
/// are wired as each tab gains author data (calendar owner in Phase 4,
/// notes in Phase 7).
class MsShell extends StatelessWidget {
  const MsShell({super.key, required this.shell, this.badges = const {}});

  final StatefulNavigationShell shell;
  final Map<MsTab, MsAuthor> badges;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: MsTabBar(
        items: [
          for (final t in MsTab.values)
            MsTabItem(icon: t.icon, label: t.label, badge: badges[t]),
        ],
        currentIndex: shell.currentIndex,
        // Tapping the active tab again returns to its first screen.
        onTap: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
