import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import 'file_row.dart';

/// Tags offered by default (ScreenFiles annotation).
const List<String> kDefaultFileTags = ['Паспорта', 'Дом', 'Налоги', 'Поездки'];

/// Upload, scan and the private box need roadmap S3. Until then the app
/// says so instead of pretending.
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

class SafeSheet extends ConsumerWidget {
  const SafeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = context.ms;
    final partner = ref.watch(pairProvider).partner;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: MsSize.sheetIconBox,
          height: MsSize.sheetIconBox,
          decoration: BoxDecoration(
            color: ms.flameSoft,
            borderRadius: BorderRadius.circular(MsRadius.radiusMd),
          ),
          child: Icon(Symbols.lock_rounded, size: MsSize.icon, color: ms.ink),
        ),
        const SizedBox(height: MsSpace.space3),
        Text('Личный сейф', style: MsText.title.copyWith(color: ms.ink)),
        const SizedBox(height: MsSpace.space1),
        Text(
          'Отдельный пароль. ${partner.name} не видит ни файлов, ни их названий, '
          'а без пароля их не открыть даже с этого телефона.',
          style: MsText.bodySm.copyWith(color: ms.inkMuted),
        ),
        const SizedBox(height: MsSpace.space3),
        const MsMeta('появится вместе с шифрованием файлов', maxLines: 2),
        const SizedBox(height: MsSpace.space4),
        const MsButton(label: 'Открыть сейф', expand: true, onPressed: null),
      ],
    );
  }
}
