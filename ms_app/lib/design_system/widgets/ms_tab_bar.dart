import 'package:flutter/material.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';
import 'ms_author.dart';

/// One tab: icon (Material Symbols Rounded), label, and an optional badge
/// in the colour of the partner whose news is waiting there.
@immutable
class MsTabItem {
  const MsTabItem({required this.icon, required this.label, this.badge});
  final IconData icon;
  final String label;
  final MsAuthor? badge;
}

/// Bottom navigation: 64 px plus the system inset, `surface` with a 1 px
/// `line` on top. The active tab has a `flame` pill 56×30 with a filled
/// `onFlame` icon and an `ink` w600 label; others are `inkMuted`.
class MsTabBar extends StatelessWidget {
  const MsTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<MsTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Semantics(
      container: true,
      label: 'Разделы',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ms.surface,
          border: Border(
              top: BorderSide(color: ms.line, width: MsSize.hairline)),
        ),
        child: SizedBox(
          height: MsSpace.tabbarH + bottom,
          child: Padding(
            padding: EdgeInsets.only(
              top: MsSize.tabPadTop,
              left: MsSize.tabPadH,
              right: MsSize.tabPadH,
              bottom: bottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _Tab(
                      item: items[i],
                      selected: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final MsTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final badge = item.badge;
    return Semantics(
      button: true,
      selected: selected,
      label: badge == null ? item.label : '${item.label}, есть новое',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: MsSize.tabGap,
          children: [
            SizedBox(
              width: MsSize.tabPillW,
              height: MsSize.tabPillH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: MsMotion.of(context, MsMotion.fast),
                      decoration: BoxDecoration(
                        color: selected
                            ? ms.flame
                            : ms.flame.withValues(alpha: 0),
                        borderRadius:
                            BorderRadius.circular(MsRadius.radiusPill),
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      item.icon,
                      size: MsSize.icon,
                      fill: selected ? 1 : 0,
                      color: selected ? ms.onFlame : ms.inkMuted,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: MsSize.tabBadgeTop,
                      right: MsSize.tabBadgeRight,
                      child: Container(
                        width: MsSize.tabBadge,
                        height: MsSize.tabBadge,
                        decoration: BoxDecoration(
                          color: badge.color(ms),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: ms.surface,
                                spreadRadius: MsSize.tabBadgeRing),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              item.label,
              style: MsText.tabLabel.copyWith(
                color: selected ? ms.ink : ms.inkMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
