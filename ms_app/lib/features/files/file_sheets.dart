import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/box/private_box.dart';
import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import 'file_row.dart';

/// Tags offered by default (ScreenFiles annotation).
const List<String> kDefaultFileTags = ['Паспорта', 'Дом', 'Налоги', 'Поездки'];

/// Upload and scan into the shared folder need roadmap S3. Until then the
/// app says so instead of pretending.
const String kS3Toast =
    'Загрузка и скан появятся вместе с шифрованием файлов. Пока можно записать документ без файла';

/// «Добавить в общую папку».
Future<void> showAddFileSheet(BuildContext context) => showMsSheet<void>(
      context,
      title: 'Добавить в общую папку',
      builder: (_) => const AddFileSheet(),
    );

/// ⋮ on a file.
Future<void> showFileSheet(BuildContext context, DocMeta doc) =>
    showMsSheet<void>(
      context,
      title: doc.name,
      builder: (_) => FileSheet(doc: doc),
    );

/// «Личный сейф».
Future<void> showSafeSheet(BuildContext context) =>
    showMsSheet<void>(context, builder: (_) => const SafeSheet());

Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(
          top: MsSize.formLabelTop, bottom: MsSize.formLabelGap),
      child: MsEyebrow(text),
    );

class _DoorRow extends StatelessWidget {
  const _DoorRow(
      {required this.icon, required this.title, required this.meta, required this.onTap});
  final IconData icon;
  final String title;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    return MsRowCard(onTap: onTap, semanticLabel: '$title, $meta', children: [
      Icon(icon, size: MsSize.icon, color: ms.ink),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: MsTextX.rowTitle.copyWith(color: ms.ink)),
          const SizedBox(height: MsSize.rowMetaGap),
          MsMeta(meta),
        ]),
      ),
    ]);
  }
}

class AddFileSheet extends ConsumerStatefulWidget {
  const AddFileSheet({super.key});

  @override
  ConsumerState<AddFileSheet> createState() => _AddFileSheetState();
}

class _AddFileSheetState extends ConsumerState<AddFileSheet> {
  final _name = TextEditingController();
  String? _tag;
  DateTime? _expires;
  bool _pickDate = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final pair = ref.read(pairProvider);
    final store = ref.read(docsProvider);
    final now = DateTime.now();
    DocsRepo(store.replica).upsert(DocMeta(
      id: '${DocsRepo.prefix}${now.microsecondsSinceEpoch}',
      name: name,
      tags: [if (_tag != null) _tag!],
      uploadedBy: pair.myDeviceId,
      at: now.millisecondsSinceEpoch,
      expiresAt: _expires?.millisecondsSinceEpoch,
    ));
    store.persist();
    Navigator.of(context).pop();
    MsToast.show(
        context, 'Записано. У ${pair.partner.nameGenitive} появится после синка');
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final now = DateTime.now();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MsMeta('файлы на Яндекс.Диске появятся вместе с шифрованием',
              maxLines: 2),
          const SizedBox(height: MsSpace.space3),
          _DoorRow(
            icon: Symbols.document_scanner_rounded,
            title: 'Скан документа',
            meta: 'камера → выравнивание → PDF',
            onTap: () => MsToast.show(context, kS3Toast),
          ),
          const SizedBox(height: MsSpace.space2),
          _DoorRow(
            icon: Symbols.upload_rounded,
            title: 'Файл с телефона',
            meta: 'PDF, фото, DOCX, XLSX',
            onTap: () => MsToast.show(context, kS3Toast),
          ),
          const MsSectionHeader('Или запиши без файла'),
          SizedBox(
            height: MsSize.fieldH,
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              style: MsText.body.copyWith(color: ms.ink),
              decoration:
                  const InputDecoration(hintText: 'Например: Полис ОСАГО'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          _label('Тег'),
          Wrap(spacing: MsSpace.space2, runSpacing: MsSpace.space2, children: [
            for (final t in kDefaultFileTags)
              MsChip(
                label: t,
                selected: _tag == t,
                onTap: () => setState(() => _tag = _tag == t ? null : t),
              ),
          ]),
          _label('Срок действия'),
          Wrap(spacing: MsSpace.space2, runSpacing: MsSpace.space2, children: [
            MsChip(
              label: 'без срока',
              selected: _expires == null,
              onTap: () => setState(() {
                _expires = null;
                _pickDate = false;
              }),
            ),
            MsChip(
              label: _expires == null ? 'до…' : 'до ${formatFullDate(_expires!)}',
              selected: _expires != null,
              onTap: () => setState(() {
                _pickDate = !_pickDate;
                _expires ??= DateTime(now.year + 1, now.month, now.day);
              }),
            ),
          ]),
          if (_pickDate)
            MsDateWheel(
              initial: _expires ?? DateTime(now.year + 1, now.month, now.day),
              firstYear: now.year,
              onChanged: (d) => setState(() => _expires = d),
            ),
          const SizedBox(height: MsSpace.space5),
          MsButton(
            label: 'Записать документ',
            expand: true,
            onPressed: _name.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}

class FileSheet extends ConsumerStatefulWidget {
  const FileSheet({super.key, required this.doc});
  final DocMeta doc;

  @override
  ConsumerState<FileSheet> createState() => _FileSheetState();
}

class _FileSheetState extends ConsumerState<FileSheet> {
  bool _pickDate = false;
  late DateTime _date = widget.doc.expiresAt == null
      ? DateTime(DateTime.now().year + 1, DateTime.now().month, DateTime.now().day)
      : DateTime.fromMillisecondsSinceEpoch(widget.doc.expiresAt!);

  void _setExpiry(int? ms) {
    final store = ref.read(docsProvider);
    DocsRepo(store.replica).setExpiry(widget.doc.id, ms);
    store.persist();
    Navigator.of(context).pop();
    MsToast.show(context, ms == null ? 'Срок убран' : 'Срок сохранён');
  }

  Future<void> _delete(Pair pair) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Убрать «${widget.doc.name}» из папки?'),
        content: Text(
            'У ${pair.partner.nameGenitive} запись тоже исчезнет после синка.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Убрать',
                  style: MsTextX.link.copyWith(color: ctx.ms.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final store = ref.read(docsProvider);
    DocsRepo(store.replica).remove(widget.doc.id);
    store.persist();
    Navigator.of(context).pop();
    MsToast.show(context, 'Убрано из папки');
  }

  @override
  Widget build(BuildContext context) {
    final pair = ref.watch(pairProvider);
    final d = widget.doc;
    final now = DateTime.now();
    final by = pair.memberOf(d.uploadedBy);
    final who = pair.isMine(d.uploadedBy) ? 'ты' : by.name;
    final meta = [
      '${by.verb('добавил')} $who',
      if (fileMeta(d, now).isNotEmpty) fileMeta(d, now),
    ].join(' · ');
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MsMeta(meta, author: by.author, maxLines: 2),
          if (d.expiresAt != null) ...[
            const SizedBox(height: MsSpace.space2),
            MsMeta('действует до ${formatFullDate(DateTime.fromMillisecondsSinceEpoch(d.expiresAt!))}'),
          ],
          const SizedBox(height: MsSpace.space4),
          _DoorRow(
            icon: Symbols.open_in_new_rounded,
            title: 'Открыть',
            meta: 'в системном просмотрщике',
            onTap: () => MsToast.show(context, kS3Toast),
          ),
          const SizedBox(height: MsSpace.space2),
          _DoorRow(
            icon: Symbols.event_available_rounded,
            title: 'Срок действия',
            meta: d.expiresAt == null
                ? 'напомню за $kExpiryWarnDays дней до конца'
                : 'бейдж появится за $kExpiryWarnDays дней',
            onTap: () => setState(() => _pickDate = !_pickDate),
          ),
          if (_pickDate) ...[
            MsDateWheel(
              initial: _date,
              firstYear: now.year - 1,
              onChanged: (v) => _date = v,
            ),
            Row(spacing: MsSpace.space2, children: [
              if (d.expiresAt != null)
                Expanded(
                  child: MsButton(
                    label: 'Убрать срок',
                    variant: MsButtonVariant.secondary,
                    expand: true,
                    onPressed: () => _setExpiry(null),
                  ),
                ),
              Expanded(
                child: MsButton(
                  label: 'Сохранить срок',
                  expand: true,
                  onPressed: () => _setExpiry(_date.millisecondsSinceEpoch),
                ),
              ),
            ]),
          ],
          const SizedBox(height: MsSpace.space6),
          MsButton(
            label: 'Убрать из папки',
            variant: MsButtonVariant.danger,
            expand: true,
            onPressed: () => _delete(pair),
          ),
        ],
      ),
    );
  }
}

/// «Личный сейф»: create it (password twice), open it, or — password
/// forgotten — delete it and start over.
class SafeSheet extends ConsumerStatefulWidget {
  const SafeSheet({super.key});
  @override
  ConsumerState<SafeSheet> createState() => _SafeSheetState();
}

class _SafeSheetState extends ConsumerState<SafeSheet> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      _password.text.length >= kBoxMinPassword &&
      _password.text == _repeat.text;

  Future<void> _go(PrivateBox box) async {
    final pw = _password.text;
    final creating = box.state == BoxState.absent;
    try {
      if (creating) {
        await box.create(pw);
      } else if (!await box.unlock(pw)) {
        if (mounted) setState(() => _error = 'Не тот пароль');
        return;
      }
    } on BoxCorrupt {
      if (mounted) {
        setState(() => _error = 'Сейф повреждён — файлы не открыть');
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _error = creating
            ? 'Не получилось создать сейф'
            : 'Не получилось открыть сейф');
      }
      return;
    }
    // Opened while the app was in the background: it stays closed.
    if (!mounted || box.state != BoxState.unlocked) return;
    Navigator.of(context).pop();
    unawaited(context.push('/safe'));
  }

  Future<void> _forgot(PrivateBox box) async {
    final ms = context.ms;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сейф?'),
        content: const Text('Без пароля файлы внутри не открыть. Можно удалить '
            'сейф и завести новый — старые файлы пропадут навсегда.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Удалить сейф',
                  style: MsTextX.link.copyWith(color: ms.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await box.destroy();
    if (!mounted) return;
    _password.clear();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final pair = ref.watch(pairProvider);
    final partner = pair.partner;
    final box = ref.watch(privateBoxProvider);
    final creating = box.state == BoxState.absent;
    Widget field(TextEditingController c, String hint) => SizedBox(
          height: MsSize.fieldH,
          child: TextField(
            controller: c,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            style: MsText.body.copyWith(color: ms.ink),
            decoration: InputDecoration(hintText: hint),
            onChanged: (_) => setState(() => _error = null),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: MsSize.sheetIconBox,
            height: MsSize.sheetIconBox,
            decoration: BoxDecoration(
              color: ms.flameSoft,
              borderRadius: BorderRadius.circular(MsRadius.radiusMd),
            ),
            child:
                Icon(Symbols.lock_rounded, size: MsSize.icon, color: ms.ink),
          ),
        ),
        const SizedBox(height: MsSpace.space3),
        Text('Личный сейф', style: MsText.title.copyWith(color: ms.ink)),
        const SizedBox(height: MsSpace.space1),
        Text(
          'Отдельный пароль. ${partner.name} не видит ни файлов, ни их названий, '
          'а без пароля их не открыть даже с этого телефона.',
          style: MsText.bodySm.copyWith(color: ms.inkMuted),
        ),
        _label(creating ? 'Придумай пароль сейфа' : 'Пароль сейфа'),
        field(_password,
            creating ? 'не короче $kBoxMinPassword символов' : ''),
        if (creating) ...[
          const SizedBox(height: MsSpace.space2),
          field(_repeat, 'ещё раз'),
          const SizedBox(height: MsSpace.space2),
          MsMeta(
              'Забудешь пароль — файлы не вернуть: ни ${partner.name}, '
              'ни лист восстановления не помогут. Сейф живёт только '
              'на этом телефоне.',
              maxLines: 3),
        ],
        SizedBox(
          height: MsSpace.space6,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _error == null ? null : MsMeta(_error!, color: ms.danger),
          ),
        ),
        MsButton(
          label: box.busy
              ? (creating ? 'Создаю…' : 'Открываю…')
              : (creating ? 'Создать сейф' : 'Открыть сейф'),
          expand: true,
          onPressed:
              box.busy || (creating ? !_canCreate : _password.text.isEmpty)
                  ? null
                  : () => _go(box),
        ),
        if (!creating) ...[
          const SizedBox(height: MsSpace.space2),
          Center(
              child: MsLink('${pair.me.verb('Забыл')} пароль',
                  onTap: () => _forgot(box))),
        ],
      ],
    );
  }
}
