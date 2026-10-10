import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ms_core/ms_core.dart' hide Clip;

import '../../core/pair/pair.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_all.dart';
import '../../core/sync/yandex_auth.dart';
import '../../design_system/ms_format.dart';
import '../../design_system/ms_theme.dart';
import '../../design_system/widgets/widgets.dart';
import '../home/sync_sheet.dart';
import 'file_row.dart';
import 'file_sheets.dart';

/// «Файлы»: the couple's shared folder — storage line, tag chips with
/// counts, search by name and tag (never content, I6), files, the private
/// box, and two doors: «Скан» and «Файл» (components/ScreenFiles.md).
///
/// Real upload, scanning and the private box are roadmap S3; this screen
/// works over the metadata registry and says so where it matters.
class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key, this.clock});
  final DateTime Function()? clock;

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  String? _tag; // null = Все
  bool _searching = false;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(DocMeta d) {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return d.name.toLowerCase().contains(q) ||
        d.tags.any((t) => t.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final ms = context.ms;
    final now = (widget.clock ?? DateTime.now)();
    final pair = ref.watch(pairProvider);
    final repo = DocsRepo(ref.watch(docsProvider).replica);
    final all = repo.all();
    final counts = repo.tagCounts();
    final tags = [
      ...kDefaultFileTags,
      ...counts.keys.where((t) => !kDefaultFileTags.contains(t)),
    ];
    final shown = all
        .where((d) => _tag == null || d.tags.contains(_tag))
        .where(_matches)
        .toList();

    return Stack(children: [
      MsScreen(children: [
        MsScreenHeader(
          eyebrow: 'общая папка',
          title: 'Файлы',
          actions: [
            MsIconButton(
              icon: _searching ? Symbols.close_rounded : Symbols.search_rounded,
              label: _searching ? 'Закрыть поиск' : 'Поиск',
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _query.clear();
              }),
            ),
          ],
        ),
        if (_searching) ...[
          const SizedBox(height: MsSpace.space3),
          SizedBox(
            height: MsSize.fieldH,
            child: TextField(
              controller: _query,
              autofocus: true,
              style: MsText.body.copyWith(color: ms.ink),
              decoration: const InputDecoration(
                  hintText: 'Название или тег — содержимое не читается'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
        const SizedBox(height: MsSpace.space3),
        const _StorageLine(),
        const SizedBox(height: MsSpace.space3 + MsSpace.space1 / 2),
        SizedBox(
          height: MsSize.chipH,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (i, t) in [null, ...tags].indexed) ...[
                if (i > 0) const SizedBox(width: MsSpace.space2),
                MsChip(
                  label: t ?? 'Все',
                  count: '${t == null ? all.length : counts[t] ?? 0}',
                  selected: _tag == t,
                  onTap: () => setState(() => _tag = t),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: MsSpace.space3 + MsSpace.space1 / 2),
        if (shown.isEmpty)
          MsRowCard(children: [
            Expanded(
              child: Text(
                all.isEmpty
                    ? 'Папка пуста. Положи сюда первый документ.'
                    : _tag != null
                        ? 'С тегом «$_tag» пока ничего нет.'
                        : 'Ничего не нашлось.',
                style: MsText.bodySm.copyWith(color: ms.inkMuted),
              ),
            ),
          ])
        else
          for (final (i, d) in shown.indexed) ...[
            if (i > 0) const SizedBox(height: MsSpace.space2),
            FileRow(
              doc: d,
              pair: pair,
              now: now,
              onTap: () => showFileSheet(context, d),
              onMenu: () => showFileSheet(context, d),
            ),
          ],
        const SizedBox(height: MsSpace.space2 + MsSpace.space2),
        SafeRow(onTap: () => showSafeSheet(context)),
        // Room for the floating «Скан» / «Файл».
        const SizedBox(height: MsSize.buttonH + MsSize.fabBottom * 2),
      ]),
      Positioned(
        right: MsSpace.space4,
        bottom: MsSize.fabBottom,
        child: Row(
          spacing: MsSpace.space2,
          children: [
            MsButton(
              label: 'Скан',
              icon: Symbols.document_scanner_rounded,
              variant: MsButtonVariant.secondary,
              pill: true,
              onPressed: () => showAddFileSheet(context),
            ),
            MsButton(
              label: 'Файл',
              icon: Symbols.add_rounded,
              pill: true,
              onPressed: () => showAddFileSheet(context),
            ),
          ],
        ),
      ),
    ]);
  }
}

/// Used/total space on the couple's Yandex.Disk (read-only GET), when
/// connected. Never touches the sync service.
final diskUsageProvider = FutureProvider<DiskUsage?>((ref) async {
  final connected = ref.watch(syncServiceProvider.select((s) => s.connected));
  final token = YandexAuth.instance.accessToken;
  if (!connected || token == null) return null;
  return YandexDiskClient(token).diskInfo();
});

/// «☁ Яндекс.Диск · 2,3 из 10 ГБ ▬▬ синк 2 мин назад» — where the files
/// live, how full it is, and when they last synced.
class _StorageLine extends ConsumerWidget {
  const _StorageLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = context.ms;
    final sync = ref.watch(syncServiceProvider);
    final last = ref.watch(lastSyncProvider);
    final usage = ref.watch(diskUsageProvider).valueOrNull;
    return Row(
      spacing: MsSpace.space2,
      children: [
        Icon(
          sync.connected ? Symbols.cloud_done_rounded : Symbols.cloud_off_rounded,
          size: MsSize.iconSm,
          color: ms.inkMuted,
        ),
        if (usage == null)
          Expanded(
            child: MsMeta(sync.connected
                ? 'Яндекс.Диск · подключён'
                : 'Яндекс.Диск не подключён'),
          )
        else ...[
          MsMeta('Яндекс.Диск · ${formatDiskUsage(usage.used, usage.total)}'),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MsRadius.radiusPill),
              child: LinearProgressIndicator(
                value: usage.fraction,
                minHeight: MsSize.diskBarH,
                backgroundColor: ms.surfaceRaised,
                color: ms.inkMuted,
              ),
            ),
          ),
        ],
        if (sync.connected && last != null)
          MsMeta('синк ${ago(last, DateTime.now())}')
        else if (!sync.connected)
          MsLink('Подключить', onTap: () => showSyncSheet(context)),
      ],
    );
  }
}
