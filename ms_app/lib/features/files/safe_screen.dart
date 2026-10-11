import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;
import 'package:open_filex/open_filex.dart';

import '../../core/box/private_box.dart';
import '../../core/security/secure_screen.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import 'file_row.dart';

/// Inside «Личный сейф». Full screen over the tab bar; leaving it locks.
class SafeScreen extends ConsumerStatefulWidget {
  const SafeScreen({super.key, this.clock});
  final DateTime Function()? clock;

  @override
  ConsumerState<SafeScreen> createState() => _SafeScreenState();
}

class _SafeScreenState extends ConsumerState<SafeScreen> {
  late final PrivateBox _box;

  @override
  void initState() {
    super.initState();
    _box = ref.read(privateBoxProvider);
    unawaited(SecureScreen.set(true));
  }

  @override
  void dispose() {
    unawaited(SecureScreen.set(false));
    // Not inside dispose itself: lock() notifies listeners, and the widget
    // tree is locked while it is being torn down.
    final box = _box;
    Future.microtask(box.lock);
    super.dispose();
  }

  void _close() {
    _box.lock();
    _leave();
  }

  /// Closes the safe and anything opened over it (a photo, a dialog, the
  /// file menu) — nothing private stays on screen.
  void _leave() {
    final nav = Navigator.of(context);
    final me = ModalRoute.of(context);
    if (me != null && me.isActive) nav.popUntil((r) => r == me);
    if (nav.canPop()) {
      nav.pop();
    } else {
      GoRouter.maybeOf(context)?.go('/files');
    }
  }

  Future<void> _add() async {
    final picked =
        await _box.away(() => FilePicker.pickFiles(allowMultiple: true));
    if (picked == null || !mounted) return;
    var added = 0;
    var closed = false;
    String? problem;
    for (final f in picked.files) {
      final path = f.path;
      if (path == null) continue;
      try {
        await _box.add(path, f.name);
        added++;
      } on StateError {
        closed = true; // locked mid-way: the rest stays out
        break;
      } on BoxTooLarge {
        problem = '«${f.name}» больше ${formatBytes(kBoxMaxFileBytes)} — '
            'в сейф не влезет';
      } catch (_) {
        problem = 'Не получилось положить «${f.name}»';
      }
    }
    // file_picker keeps plain copies in the cache: remove them now.
    try {
      await FilePicker.clearTemporaryFiles();
    } catch (_) {
      // Desktop has nothing to clear.
    }
    if (closed || !mounted) return;
    MsToast.show(
        context,
        problem ??
            'В сейфе: $added ${ruPlural(added, 'файл', 'файла', 'файлов')}. '
                'Оригинал остался на телефоне — удали его, если нужно.');
  }

  /// Photos open inside МС from memory; the rest (or on request) in another
  /// app via a temporary plain copy.
  Future<void> _open(BoxEntry e, {bool external = false}) async {
    try {
      if (e.isImage && !external) {
        final bytes = await _box.readBytes(e.id);
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => _ImageView(name: e.name, bytes: bytes)));
        return;
      }
      final file = await _box.exportTemp(e.id);
      final r = await OpenFilex.open(file.path);
      if (r.type != ResultType.done && mounted) {
        MsToast.show(context, 'Нечем открыть такой файл на этом телефоне');
      }
    } on BoxCorrupt {
      if (mounted) MsToast.show(context, 'Файл повреждён — открыть не выйдет');
    } on StateError {
      // The safe locked meanwhile; the screen is closing.
    } catch (_) {
      if (mounted) MsToast.show(context, 'Не получилось открыть «${e.name}»');
    }
  }

  Future<void> _remove(BoxEntry e) async {
    final ms = context.ms;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить «${e.name}»?'),
        content: const Text('Из сейфа он пропадёт насовсем.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Удалить',
                  style: MsTextX.link.copyWith(color: ms.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await _box.remove(e.id);
    if (mounted) MsToast.show(context, 'Удалено из сейфа');
  }

  Future<void> _menu(BoxEntry e) => showMsSheet<void>(
        context,
        title: e.name,
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MsSpace.space2,
          children: [
            MsButton(
              label: 'Открыть в другом приложении',
              variant: MsButtonVariant.secondary,
              expand: true,
              onPressed: () {
                Navigator.of(sheet).pop();
                _open(e, external: true);
              },
            ),
            MsButton(
              label: 'Удалить из сейфа',
              variant: MsButtonVariant.danger,
              expand: true,
              onPressed: () {
                Navigator.of(sheet).pop();
                _remove(e);
              },
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final box = ref.watch(privateBoxProvider);
    final now = (widget.clock ?? DateTime.now)();
    if (box.state != BoxState.unlocked) {
      // Locked behind our back (app hidden, app lock): leave.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _leave();
      });
      return Scaffold(backgroundColor: ms.ground);
    }
    final entries = box.entries;
    return Scaffold(
      backgroundColor: ms.ground,
      body: Stack(children: [
        MsScreen(children: [
          Row(children: [
            MsIconButton(
                icon: Symbols.arrow_back_rounded,
                label: 'Назад',
                onPressed: _close),
            const SizedBox(width: MsSpace.space3),
            Expanded(
              child: MsScreenHeader(
                eyebrow: 'только для тебя',
                title: 'Личный сейф',
                actions: [
                  MsIconButton(
                      icon: Symbols.lock_rounded,
                      label: 'Закрыть сейф',
                      onPressed: _close),
                ],
              ),
            ),
          ]),
          const SizedBox(height: MsSpace.space4),
          if (entries.isEmpty)
            MsCard(
              child: Text('Пусто. Положи сюда то, что только твоё.',
                  style: MsText.bodySm.copyWith(color: ms.inkMuted)),
            )
          else
            for (final e in entries) ...[
              MsRowCard(
                onTap: () => _open(e),
                children: [
                  FileThumb.kind(label: e.kindLabel, image: e.isImage),
                  const SizedBox(width: MsSpace.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MsTextX.rowTitle.copyWith(color: ms.ink)),
                        const SizedBox(height: MsSize.rowMetaGap),
                        MsMeta('${formatBytes(e.size)} · '
                            '${formatWhen(DateTime.fromMillisecondsSinceEpoch(e.addedAt), now)}'),
                      ],
                    ),
                  ),
                  MsIconButton(
                      icon: Symbols.more_vert_rounded,
                      label: 'Действия с файлом',
                      onPressed: () => _menu(e)),
                ],
              ),
              const SizedBox(height: MsSpace.space2),
            ],
          const SizedBox(height: MsSize.buttonH + MsSize.fabBottom * 2),
        ]),
        Positioned(
          right: MsSpace.space4,
          bottom: MsSize.fabBottom + MediaQuery.paddingOf(context).bottom,
          child: MsButton(
            label: box.busy ? 'Шифрую…' : 'Добавить файл',
            icon: Symbols.add_rounded,
            pill: true,
            onPressed: box.busy ? null : _add,
          ),
        ),
      ]),
    );
  }
}

/// A photo from the safe, decrypted into memory only — and dropped from
/// Flutter's image cache when the viewer closes.
class _ImageView extends StatefulWidget {
  const _ImageView({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;

  @override
  State<_ImageView> createState() => _ImageViewState();
}

class _ImageViewState extends State<_ImageView> {
  late final MemoryImage _image = MemoryImage(widget.bytes);

  @override
  void dispose() {
    unawaited(_image.evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final name = widget.name;
    return Scaffold(
      backgroundColor: ms.ground,
      appBar: AppBar(
        backgroundColor: ms.ground,
        foregroundColor: ms.ink,
        title: Text(name, style: MsTextX.rowTitle.copyWith(color: ms.ink)),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image(
            image: _image,
            errorBuilder: (_, __, ___) => Padding(
              padding: const EdgeInsets.all(MsSpace.space5),
              child: Text(
                  'Этот снимок МС не показывает. Открой его в другом '
                  'приложении через меню файла.',
                  textAlign: TextAlign.center,
                  style: MsText.bodySm.copyWith(color: ms.inkMuted)),
            ),
          ),
        ),
      ),
    );
  }
}
