import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/pair/pair.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';

/// Days before expiry when the badge appears (IMPLEMENTATION Phase 5).
const int kExpiryWarnDays = 60;

/// The expiry badge text, or null when it's too early to warn.
String? expiryBadge(DocMeta d, DateTime now) {
  final at = d.expiresAt;
  if (at == null) return null;
  final days = daysUntil(at, now);
  if (days > kExpiryWarnDays) return null;
  if (days < 0) return 'срок истёк';
  if (days == 0) return 'истекает сегодня';
  return 'истекает ${inDays(days)}';
}

/// Meta after the author dot: «1,4 МБ · Дом · вчера».
String fileMeta(DocMeta d, DateTime now) => [
      if (d.size != null) formatBytes(d.size!),
      if (d.tags.isNotEmpty) d.tags.first,
      if (d.at != null)
        formatWhen(DateTime.fromMillisecondsSinceEpoch(d.at!), now),
    ].join(' · ');

/// 44 × 52 type thumbnail with the type in mono 8 (components/FileRow.md).
class FileThumb extends StatelessWidget {
  const FileThumb({super.key, required this.doc});
  final DocMeta doc;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return Container(
      width: MsSize.fileThumbW,
      height: MsSize.fileThumbH,
      decoration: BoxDecoration(
        color: ms.surfaceRaised,
        border: Border.all(color: ms.line, width: MsSize.hairline),
        borderRadius: BorderRadius.circular(MsRadius.radiusSm),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(doc.isImage ? Symbols.image_rounded : Symbols.description_rounded,
            size: MsSize.icon, color: ms.inkMuted),
        Positioned(
          bottom: MsSize.fileThumbLabelBottom,
          child: Text(doc.kindLabel,
              style: MsTextX.fileKind.copyWith(color: ms.inkMuted)),
        ),
      ]),
    );
  }
}

/// `warn` / `danger` pill with mono text.
class MsBadge extends StatelessWidget {
  const MsBadge(this.text, {super.key, this.danger = false});
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return Container(
      height: MsSize.badgeH,
      padding: const EdgeInsets.symmetric(horizontal: MsSize.badgePadH),
      decoration: BoxDecoration(
        color: danger ? ms.danger : ms.warn,
        borderRadius: BorderRadius.circular(MsRadius.radiusSm),
      ),
      // Hug the text (`inline-flex`), centred vertically.
      child: Center(
        widthFactor: 1,
        child: Text(text,
            style:
                MsTextX.badge.copyWith(color: danger ? ms.onDanger : ms.onWarn)),
      ),
    );
  }
}

/// A file in the shared folder: thumbnail, name, author dot · size · tag ·
/// when, an expiry badge on its own line, and ⋮.
class FileRow extends StatelessWidget {
  const FileRow({
    super.key,
    required this.doc,
    required this.pair,
    required this.now,
    required this.onTap,
    required this.onMenu,
  });

  final DocMeta doc;
  final Pair pair;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final badge = expiryBadge(doc, now);
    final meta = fileMeta(doc, now);
    return MsRowCard(
      minHeight: MsSize.fileRowMinH,
      padding: const EdgeInsets.fromLTRB(MsSize.fileRowPadL, MsSize.fileRowPadV,
          MsSize.fileRowPadR, MsSize.fileRowPadV),
      onTap: onTap,
      semanticLabel: [doc.name, meta, if (badge != null) badge].join(', '),
      children: [
        FileThumb(doc: doc),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(doc.name,
                  style: MsTextX.rowTitle.copyWith(color: ms.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: MsSize.rowMetaGap),
              MsMeta(meta.isEmpty ? 'без подробностей' : meta,
                  author: pair.memberOf(doc.uploadedBy).author),
              if (badge != null) ...[
                const SizedBox(height: MsSpace.space1),
                MsBadge(badge, danger: badge == 'срок истёк'),
              ],
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Действия с файлом',
          excludeSemantics: true,
          child: InkResponse(
            onTap: onMenu,
            radius: MsSize.icon,
            child: Icon(Symbols.more_vert_rounded,
                size: MsSize.icon, color: ms.inkFaint),
          ),
        ),
      ],
    );
  }
}

/// «Личный сейф» — last row, `flameSoft` lock, no count.
class SafeRow extends StatelessWidget {
  const SafeRow({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return MsRowCard(
      minHeight: MsSize.fileRowMinH,
      padding: const EdgeInsets.fromLTRB(MsSize.fileRowPadL, MsSize.fileRowPadV,
          MsSize.fileRowPadR, MsSize.fileRowPadV),
      onTap: onTap,
      semanticLabel: 'Личный сейф, только для тебя, свой пароль',
      children: [
        Container(
          width: MsSize.fileThumbW,
          height: MsSize.fileThumbH,
          decoration: BoxDecoration(
            color: ms.flameSoft,
            borderRadius: BorderRadius.circular(MsRadius.radiusSm),
          ),
          child: Icon(Symbols.lock_rounded, size: MsSize.icon, color: ms.ink),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Личный сейф', style: MsTextX.rowTitle.copyWith(color: ms.ink)),
              const SizedBox(height: MsSize.rowMetaGap),
              const MsMeta('только для тебя · свой пароль'),
            ],
          ),
        ),
        Icon(Symbols.chevron_right_rounded, size: MsSize.icon, color: ms.inkFaint),
      ],
    );
  }
}
