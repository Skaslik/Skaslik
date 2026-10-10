/// Component geometry, motion and derived text styles from the design spec
/// (`docs/design/IMPLEMENTATION.md`, `docs/design/reference-web/bundle.css`)
/// that `tokens.json` does not name.
///
/// Hand-written, unlike `ms_tokens.dart`. Widgets read sizes from here and
/// from the generated tokens — never literals.
library;

import 'package:flutter/widgets.dart';

import 'ms_tokens.dart';

/// Fixed component dimensions (logical px).
abstract final class MsSize {
  // Author marks.
  static const double authorDot = 8;
  static const double authorDotBothW = 13;
  static const double authorBar = 3;
  static const double authorBarRadius = 2;

  // Rows, cards, date block.
  /// Minimum content height of a row. Like the reference CSS (content-box),
  /// padding comes on top: a one-line row is 56 + 2 × 12 = 80 high, as in
  /// the screen screenshots.
  static const double rowMinH = 56;
  /// Horizontal padding inside text fields (`.ms-input`, `.field`).
  static const double fieldPadH = 14;
  static const double dateBlockW = 48;
  static const double dateSubGap = 2;
  static const double dateSubH = 12;
  static const double metaGap = 6;
  /// Title ↔ meta inside a row (`.rmeta`).
  static const double rowMetaGap = 2;

  // Chips and segmented control.
  static const double chipH = 32;
  static const double chipPadH = 14;
  static const double chipGap = 6;
  static const double segmentH = 32;
  static const double segmentPad = 3;

  // Buttons and icons.
  static const double buttonH = 48;
  static const double buttonPadH = 20;
  static const double buttonSmH = 36;
  static const double buttonSmPadH = 14;
  static const double buttonIcon = 20;
  static const double buttonGap = 8;
  static const double iconButton = 40;
  static const double icon = 24;
  static const double iconSm = 18;

  // Sync status pill.
  static const double syncH = 28;
  static const double syncPadL = 8;
  static const double syncPadR = 10;
  static const double syncGap = 6;
  static const double syncGlyph = 7;
  static const double syncGlyphStroke = 1.2;

  // Split progress bar.
  static const double progressH = 8;
  static const double progressGap = 2;

  // Bottom sheet.
  static const double grabW = 36;
  static const double grabH = 4;
  static const double grabRadius = 2;
  static const double grabGap = 12;
  static const double sheetPadTop = 10;
  static const double sheetPadH = 20;
  static const double sheetPadBottom = 28;

  // Tab bar (`.ms-tabbar`): 64 + system inset, 1 px top line.
  static const double tabPadTop = 8;
  static const double tabPadH = 6;
  static const double tabPillW = 56;
  static const double tabPillH = 30;
  static const double tabGap = 3;
  static const double tabBadge = 8;
  static const double tabBadgeTop = 3;
  static const double tabBadgeRight = 12;
  static const double tabBadgeRing = 2;

  // Screen header (`.ms-screen`, `.ms-screen__title`).
  static const double screenTitleGap = 4;
  static const double headerActionGap = 4;

  // Home sheet (`.crow`, `.lcard`, piggy card).
  static const double candleRowPadL = 10;
  static const double cardTileW = 112;
  static const double cardTileH = 64;
  static const double cardTilePadV = 10;
  static const double cardTileBars = 14;
  static const double piggyGap = 10;

  // Calendar month grid — measured from screen-calendar_*.png
  // (reference CSS is content-box: cell 40 + 6 padding, 2 px row gap).
  static const double calWeekdayH = 22;
  static const double calCellH = 46;
  static const double calRowGap = 2;
  static const double calDayD = 28;
  static const double calDayTop = 1;
  static const double calDayRing = 1.5;
  static const double calDot = 5;
  static const double calDotGap = 3;
  static const double calDotBottom = 3;
  static const double calSpanH = 4;
  static const double calSpanBottom = 4;
  static const double calSpanInset = 6;
  static const double calLegendGap = 14;
  static const double calLegendTop = 10;
  static const double calSegTop = 14;
  static const double calSegBottom = 12;
  static const double calListTop = 18;

  // Sheet forms: eyebrow label above a field (`.eyebrow` 16/6).
  static const double formLabelTop = 16;
  static const double formLabelGap = 6;
  static const double fieldH = 44;
  /// Inline time wheel in the add-event sheet.
  static const double timePickerH = 150;

  // Files (`ScreenFiles.html`: row min 72, padding 10/14/10/10).
  static const double fileRowMinH = 72;
  static const double fileRowPadL = 10;
  static const double fileRowPadR = 14;
  static const double fileRowPadV = 10;
  static const double fileThumbW = 44;
  static const double fileThumbH = 52;
  static const double fileThumbLabelBottom = 4;
  static const double badgeH = 20;
  static const double badgePadH = 8;
  static const double diskBarH = 4;
  static const double fabBottom = 16;
  static const double sheetIconBox = 56;
  static const double wheelItemH = 34;
  static const double wheelH = 150;

  // Toast.
  static const double toastPadV = 12;
  static const double toastAboveTabbar = 14;

  /// 1 px hairlines: dividers, chip and field outlines, segment ring.
  static const double hairline = 1;
}

/// Opacities used by components.
abstract final class MsAlpha {
  static const double disabled = 0.45;
  static const double chipCountOn = 0.75;
  /// Barcode hint on the home card tiles.
  static const double cardStripes = 0.55;
}

/// Motion: fades and slides of 150–250 ms (brand-book «Движение»).
abstract final class MsMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 250);
  static const Duration toast = Duration(milliseconds: 2600);

  /// [d], or zero when the system asks to reduce motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;
}

/// Text styles derived from [MsText] for controls the token groups don't
/// name. Colour is applied by the widget.
abstract final class MsTextX {
  /// Row title: 15/20 w600 (`.ms-rowcard__title`).
  static final TextStyle rowTitle = MsText.bodyStrong.copyWith(height: 20 / 15);

  /// Chip and segment label: 13 w500.
  static final TextStyle control =
      MsText.bodySm.copyWith(fontWeight: FontWeight.w500, height: 1);

  /// Selected segment label: 13 w600.
  static final TextStyle controlOn =
      MsText.bodySm.copyWith(fontWeight: FontWeight.w600, height: 1);

  /// Text link «Календарь ›»: 13 w600 in `link`.
  static final TextStyle link =
      MsText.bodySm.copyWith(fontWeight: FontWeight.w600);

  /// Regular button label: 15 w600.
  static final TextStyle button = MsText.bodyStrong.copyWith(height: 1);

  /// Small pill button label: 13 w600.
  static final TextStyle buttonSm =
      MsText.bodySm.copyWith(fontWeight: FontWeight.w600, height: 1);

  /// Date block sub-label: mono 10/12, upper-case, +0.06em.
  static final TextStyle dateSub =
      MsText.meta.copyWith(fontSize: 10, height: 1.2, letterSpacing: 0.6);

  /// Count inside a chip: mono 11.
  static final TextStyle chipCount =
      MsText.meta.copyWith(fontSize: 11, height: 1);

  /// Sync status word: mono 11.
  static final TextStyle sync = MsText.meta.copyWith(fontSize: 11, height: 1);

  /// Sync status glyph ● ◐ ○ ✕: 12.
  static final TextStyle syncGlyph =
      MsText.meta.copyWith(fontSize: 12, height: 1);

  /// Day number in the month grid: mono 14 w500.
  static final TextStyle calDay =
      MsText.meta.copyWith(fontSize: 14, height: 1, fontWeight: FontWeight.w500);

  /// File type label in the thumbnail: mono 8 w600 +0.06em.
  static final TextStyle fileKind = MsText.meta.copyWith(
      fontSize: 8, height: 1, fontWeight: FontWeight.w600, letterSpacing: 0.48);

  /// Badge text: mono 10 w500 +0.04em («истекает через 54 дня»).
  static final TextStyle badge = MsText.meta.copyWith(
      fontSize: 10, height: 1, fontWeight: FontWeight.w500, letterSpacing: 0.4);

  /// Toast text: 14/19.
  static final TextStyle toast =
      MsText.body.copyWith(fontSize: 14, height: 19 / 14);
}
