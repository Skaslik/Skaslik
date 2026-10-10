import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/barcode/ean13.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';

/// Screen on and brightness at 100 % while the card is open; restored on
/// close. Behind an interface so tests never touch the plugins.
abstract interface class CheckoutDisplay {
  Future<void> enter();
  Future<void> leave();
}

class DeviceCheckoutDisplay implements CheckoutDisplay {
  const DeviceCheckoutDisplay();

  @override
  Future<void> enter() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(1);
    } catch (_) {}
  }

  @override
  Future<void> leave() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }
}

final checkoutDisplayProvider =
    Provider<CheckoutDisplay>((ref) => const DeviceCheckoutDisplay());

/// The card at the checkout: a white sheet in any theme, a large EAN-13
/// (or QR), the number, «Показать QR» (components/ScreenLoyaltyCard.md).
class CardCheckoutScreen extends ConsumerStatefulWidget {
  const CardCheckoutScreen({super.key, required this.cardId});

  final String cardId;

  @override
  ConsumerState<CardCheckoutScreen> createState() => _CardCheckoutScreenState();
}

class _CardCheckoutScreenState extends ConsumerState<CardCheckoutScreen> {
  bool _qr = false;
  late final CheckoutDisplay _display = ref.read(checkoutDisplayProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_display.enter());
    // Remember when the card was last used (sorting, «под рукой»).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = ref.read(cardsProvider);
      if (store.contains('card:${widget.cardId}')) {
        CardsRepo(store.replica)
            .touch(widget.cardId, DateTime.now().millisecondsSinceEpoch);
        store.persist();
      }
    });
  }

  @override
  void dispose() {
    unawaited(_display.leave());
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/together?seg=cards');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final card = CardsRepo(ref.watch(cardsProvider).replica).get(widget.cardId);
    final pad = MediaQuery.paddingOf(context);
    final ink = ms.cardInk;

    if (card == null) {
      return Scaffold(
        backgroundColor: ms.cardPaper,
        body: Center(
          child: MsButton(label: 'Карта удалена — назад', onPressed: _close),
        ),
      );
    }

    final digits = ean13Digits(card.barcodeValue);
    final showQr = _qr || digits == null;
    final by = pair.memberOf(card.addedBy);
    final byLine =
        '${by.verb('добавил')} ${pair.isMine(card.addedBy) ? 'ты' : by.name}';
    final kind = digits != null ? 'EAN-13' : 'QR';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: MsTheme.overlay(Brightness.light),
      child: Scaffold(
        backgroundColor: ms.cardPaper,
        body: Padding(
          padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  MsSpace.space4, MsSpace.space1, MsSpace.space4, 0),
              child: Row(children: [
                Semantics(
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: SizedBox(
                      height: MsSpace.tapMin,
                      child: Center(
                        child: Text('Готово',
                            style: MsTextX.cardDone.copyWith(color: ink)),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: MsSize.cardChipPadH,
                      vertical: MsSize.cardChipPadV),
                  decoration: BoxDecoration(
                    color: ms.cardChip,
                    borderRadius: BorderRadius.circular(MsRadius.radiusPill),
                  ),
                  child: Text('ЯРКОСТЬ 100%',
                      style: MsTextX.dateSub.copyWith(color: ink)),
                ),
              ]),
            ),
            const SizedBox(height: MsSize.cardNameTop),
            Text(card.merchantName,
                textAlign: TextAlign.center,
                style: MsText.screenTitle.copyWith(color: ink)),
            const SizedBox(height: MsSpace.space1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: MsSize.metaGap,
              children: [
                MsAuthorDot(by.author),
                Text('$byLine · $kind',
                    style: MsText.meta.copyWith(color: ms.cardInkMuted)),
              ],
            ),
            const SizedBox(height: MsSize.cardBarcodeTop),
            if (showQr)
              Semantics(
                label: 'QR-код карты ${card.merchantName}',
                child: QrImageView(
                  data: card.barcodeValue,
                  size: MsSize.cardQr,
                  backgroundColor: ms.cardPaper,
                  eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: ink),
                  dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square, color: ink),
                ),
              )
            else
              Semantics(
                label: 'Штрихкод $digits',
                child: LayoutBuilder(builder: (context, c) {
                  // ≥ 75 % of the screen, quiet zone of 10 modules each side.
                  final w = c.maxWidth - MsSpace.space4 * 2;
                  return CustomPaint(
                    size: Size(w, MsSize.barcodeGuardH),
                    painter: Ean13Painter(
                      modules: ean13Modules(digits),
                      ink: ink,
                      barHeight: MsSize.barcodeBarH,
                      guardHeight: MsSize.barcodeGuardH,
                      quiet: MsSize.barcodeQuiet.toInt(),
                    ),
                  );
                }),
              ),
            const SizedBox(height: MsSize.cardBarcodeGap),
            Text(digits != null ? ean13Pretty(digits) : card.barcodeValue,
                textAlign: TextAlign.center,
                style: MsTextX.cardNumber.copyWith(color: ink)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(MsSpace.space4),
              child: Column(children: [
                if (digits != null)
                  SizedBox(
                    width: double.infinity,
                    height: MsSize.buttonH,
                    child: Material(
                      color: ms.cardChip,
                      borderRadius: BorderRadius.circular(MsRadius.radiusMd),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(MsRadius.radiusMd),
                        onTap: () => setState(() => _qr = !_qr),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: MsSize.buttonGap,
                          children: [
                            Icon(
                                _qr
                                    ? Symbols.barcode_rounded
                                    : Symbols.qr_code_2_rounded,
                                size: MsSize.buttonIcon,
                                color: ink),
                            Text(_qr ? 'Показать штрихкод' : 'Показать QR',
                                style: MsTextX.button.copyWith(color: ink)),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: MsSize.cardFootGap),
                Text('экран не гаснет, пока карта открыта',
                    style: MsText.meta.copyWith(color: ms.cardInkMuted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
