import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';

/// «Мы». Until Phase 7 it is a hub to the old screens: notes, the pulse and
/// ritual feed, and settings with sync.
class UsScreen extends StatelessWidget {
  const UsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MsScreen(
      children: [
        const MsScreenHeader(eyebrow: 'Михаил и София', title: 'Мы'),
        const SizedBox(height: MsSpace.space6),
        const MsEyebrow('Близко'),
        const SizedBox(height: MsSpace.space2),
        _LinkRow(title: 'Записки', onTap: () => context.go('/us/notes')),
        const SizedBox(height: MsSpace.space2),
        _LinkRow(
            title: 'Пульс дня и ритуалы',
            onTap: () => context.go('/us/pulse')),
        const SizedBox(height: MsSpace.space6),
        const MsEyebrow('Устройство и данные'),
        const SizedBox(height: MsSpace.space2),
        _LinkRow(
            title: 'Синхронизация, безопасность, тема',
            onTap: () => context.go('/us/settings')),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return MsRowCard(
      onTap: onTap,
      semanticLabel: title,
      children: [
        Expanded(
          child: Text(title, style: MsTextX.rowTitle.copyWith(color: ms.ink)),
        ),
        Icon(Symbols.chevron_right_rounded,
            size: MsSize.icon, color: ms.inkFaint),
      ],
    );
  }
}
