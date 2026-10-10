/// Shared-folder file metadata (PLAN 5.4 FileMeta). Bytes never live here.
library;

import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  test('round-trip keeps every meta field', () {
    const d = DocMeta(
      id: 'doc-1',
      name: 'Полис ОСАГО.pdf',
      tags: ['Дом'],
      uploadedBy: 'A',
      at: 100,
      size: 614400,
      kind: 'PDF',
      expiresAt: 900,
    );
    final back = DocMeta.fromFields('doc-1', d.toFields())!;
    expect(back.name, d.name);
    expect(back.tags, ['Дом']);
    expect(back.uploadedBy, 'A');
    expect(back.at, 100);
    expect(back.size, 614400);
    expect(back.kind, 'PDF');
    expect(back.expiresAt, 900);
  });

  test('entries from the old registry (name + tags only) still parse', () {
    final d = DocMeta.fromFields(
        'doc-7', {'name': 'Договор.pdf', 'tags': 'Дом,Налоги'})!;
    expect(d.tags, ['Дом', 'Налоги']);
    expect(d.uploadedBy, isNull);
    expect(d.size, isNull);
    expect(d.kindLabel, 'PDF'); // from the extension
    expect(d.isImage, isFalse);
    expect(DocMeta.fromFields('doc-x', {'tags': 'Дом'}), isNull);
  });

  test('kind label and image detection', () {
    DocMeta n(String name) => DocMeta(id: 'doc-', name: name);
    expect(n('Чек — холодильник.jpg').kindLabel, 'JPG');
    expect(n('Чек — холодильник.jpg').isImage, isTrue);
    expect(n('Скан').kindLabel, 'ФАЙЛ');
  });

  test('repo: newest first, tag counts, expiry can be cleared', () {
    final repo = DocsRepo(Replica('A'));
    repo.upsert(
        const DocMeta(id: 'doc-1', name: 'a.pdf', tags: ['Дом'], at: 1));
    repo.upsert(const DocMeta(
        id: 'doc-2', name: 'b.pdf', tags: ['Дом', 'Налоги'], at: 3));
    repo.upsert(const DocMeta(id: 'doc-3', name: 'c.pdf', at: 2));
    expect(repo.all().map((d) => d.id), ['doc-2', 'doc-3', 'doc-1']);
    expect(repo.tagCounts(), {'Дом': 2, 'Налоги': 1});

    repo.setExpiry('doc-1', 500);
    expect(repo.get('doc-1')!.expiresAt, 500);
    repo.setExpiry('doc-1', null);
    expect(repo.get('doc-1')!.expiresAt, isNull);

    repo.remove('doc-2');
    expect(repo.all().map((d) => d.id), ['doc-3', 'doc-1']);
  });

  test('days until expiry, counted in calendar days', () {
    final now = DateTime(2026, 10, 8, 21);
    int at(int y, int m, int d) => DateTime(y, m, d).millisecondsSinceEpoch;
    expect(daysUntil(at(2026, 12, 1), now), 54);
    expect(daysUntil(at(2026, 10, 8), now), 0);
    expect(daysUntil(at(2026, 10, 1), now), -7);
  });

  test('two phones: an expiry set on one reaches the other (LWW)', () {
    final a = Replica('A'), b = Replica('B');
    DocsRepo(a).upsert(
        const DocMeta(id: 'doc-1', name: 'x.pdf', uploadedBy: 'A', at: 1));
    b.mergeIn(a.allOps());
    DocsRepo(b).setExpiry('doc-1', 77);
    a.mergeIn(b.allOps());
    expect(DocsRepo(a).get('doc-1')!.expiresAt, 77);
    expect(DocsRepo(a).get('doc-1')!.uploadedBy, 'A');
  });
}
