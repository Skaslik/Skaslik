import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';

/// Event row (components/EventRow.md): mono date block, the author's bar
/// (shared → two halves), title and meta, a chevron.
class EventRow extends StatelessWidget {
  const EventRow({
    super.key,
    required this.day,
    required this.sub,
    required this.author,
    required this.title,
    required this.meta,
    this.onTap,
  });

  /// «8».
  final String day;

  /// «сегодня», «пт».
  final String sub;
  final MsAuthor author;
  final String title;

  /// «19:30 · добавила София».
  final String meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return MsRowCard(
      stretch: true,
      onTap: onTap,
      semanticLabel: '$title, $day, $sub, $meta',
      children: [
        Center(child: MsDateBlock(day: day, sub: sub)),
        MsAuthorBar(author),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: MsTextX.rowTitle.copyWith(color: ms.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: MsSize.rowMetaGap),
              MsMeta(meta),
            ],
          ),
        ),
        Center(
          child: Icon(Symbols.chevron_right_rounded,
              size: MsSize.icon, color: ms.inkFaint),
        ),
      ],
    );
  }
}
