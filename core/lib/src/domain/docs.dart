/// Домен «Файлы»: метаданные общей папки (PLAN 5.4 FileMeta).
///
/// Только метаданные — байты в CRDT запрещены; файлы лежат на Яндекс.Диске
/// (загрузка — S3). Сущность `doc-<id>`; поля additive: старые записи
/// реестра (`name`, `tags`) читаются как есть (I8).
library;

import '../sync/replica.dart';

class DocMeta {
  /// Entity id, `doc-…`.
  final String id;
  final String name;
  final List<String> tags;

  /// Device that added it.
  final String? uploadedBy;

  /// When it was added, ms.
  final int? at;

  /// Bytes.
  final int? size;

  /// Upper-case type label: PDF, JPG, DOCX… (else taken from the name).
  final String? kind;

  /// When the document (passport, insurance) stops being valid, ms.
  final int? expiresAt;

  const DocMeta({
    required this.id,
    required this.name,
    this.tags = const [],
    this.uploadedBy,
    this.at,
    this.size,
    this.kind,
    this.expiresAt,
  });

  static const Set<String> _images = {
    'JPG', 'JPEG', 'PNG', 'HEIC', 'WEBP', 'GIF',
  };

  /// PDF / JPG / … for the thumbnail; «ФАЙЛ» when unknown.
  String get kindLabel {
    final k = kind;
    if (k != null && k.isNotEmpty) return k.toUpperCase();
    final dot = name.lastIndexOf('.');
    if (dot > 0 && dot < name.length - 1) {
      return name.substring(dot + 1).toUpperCase();
    }
    return 'ФАЙЛ';
  }

  bool get isImage => _images.contains(kindLabel);

  static DocMeta? fromFields(String id, Map<String, String> f) {
    final name = f['name'];
    if (name == null || name.isEmpty) return null;
    final kind = f['kind'];
    return DocMeta(
      id: id,
      name: name,
      tags: (f['tags'] ?? '')
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      uploadedBy: f['uploadedBy'],
      at: int.tryParse(f['at'] ?? ''),
      size: int.tryParse(f['size'] ?? ''),
      kind: (kind == null || kind.isEmpty) ? null : kind,
      expiresAt: int.tryParse(f['expiresAt'] ?? ''),
    );
  }

  Map<String, String> toFields() => {
        'name': name,
        'tags': tags.join(','),
        if (uploadedBy != null) 'uploadedBy': uploadedBy!,
        if (at != null) 'at': '$at',
        if (size != null) 'size': '$size',
        if (kind != null) 'kind': kind!,
        if (expiresAt != null) 'expiresAt': '$expiresAt',
      };
}

/// Репозиторий метаданных общей папки поверх [Replica].
class DocsRepo {
  final Replica replica;
  DocsRepo(this.replica);

  static const String prefix = 'doc-';

  void upsert(DocMeta d) {
    for (final e in d.toFields().entries) {
      replica.set(d.id, e.key, e.value);
    }
  }

  void remove(String id) => replica.delete(id);

  DocMeta? get(String id) {
    final f = replica.entity(id);
    return f == null ? null : DocMeta.fromFields(id, f);
  }

  /// Newest first; entries without a time go last.
  List<DocMeta> all() {
    final out = <DocMeta>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(prefix)) continue;
      final d = DocMeta.fromFields(e.key, e.value);
      if (d != null) out.add(d);
    }
    out.sort((a, b) => (b.at ?? -1).compareTo(a.at ?? -1));
    return out;
  }

  /// How many files carry each tag.
  Map<String, int> tagCounts() {
    final out = <String, int>{};
    for (final d in all()) {
      for (final t in d.tags) {
        out[t] = (out[t] ?? 0) + 1;
      }
    }
    return out;
  }

  /// Set or clear (`null`) the validity date. Clearing writes an empty
  /// value, since an LWW field can't be removed.
  void setExpiry(String id, int? atMs) =>
      replica.set(id, 'expiresAt', atMs == null ? '' : '$atMs');
}

/// Whole calendar days from [now] to [expiresAtMs] (negative once past).
int daysUntil(int expiresAtMs, DateTime now) {
  final e = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(e.year, e.month, e.day);
  return (b.difference(a).inHours / 24).round();
}
